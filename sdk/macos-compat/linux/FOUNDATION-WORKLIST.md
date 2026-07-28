# Toward real apps — Foundation work-list

The Hello and Gallery probes import only SwiftUI + libswiftCore + `_memcpy` + a CGFloat
metadata symbol. Every *real* third-party macOS app additionally uses **Foundation**
(JSON, dates, data, URLs, formatting, collections), so Foundation is the first
non-SwiftUI dependency to bring up. `probe/FoundationProbe.swift` is a SwiftUI app that
exercises a realistic Foundation surface (JSON/Codable, Data, UUID, Date.formatted) as
the controlled first step.

## Build it (on a Mac — Linux can't produce a Darwin Mach-O)

```bash
cd macos-compat/probe
xcrun swiftc -parse-as-library -target arm64-apple-macos14.0 \
  -sdk "$(xcrun --show-sdk-path)" -O -o FoundationProbe FoundationProbe.swift
```
Then copy `FoundationProbe` back here and run it through the loader:
```bash
cd macos-compat/linux && ./build.sh && MACHOLD_VERBOSE=1 ./run.sh ../probe/FoundationProbe
```

## The Linux Foundation split (handled in the loader)

The macOS binary imports core Foundation types as `$s10Foundation…`, but the Linux
toolchain (swift-foundation) is **split**:

| Linux module | Mangled prefix | Holds |
|---|---|---|
| `FoundationEssentials` | `20FoundationEssentials` | `Date`, `Data`, `URL`, `UUID`, `JSONEncoder`/`Decoder`, `Codable` glue, … |
| `FoundationInternationalization` | `30FoundationInternationalization` | `Date.FormatStyle`, locale/number formatting, … |
| `Foundation` | `10Foundation` | `DateFormatter`, `NumberFormatter`, the ObjC-compat layer |

`machold`'s resolver tries, for any unresolved `$s10Foundation…` import: the name as-is
(Foundation), then with the module rewritten to `FoundationEssentials`, then
`FoundationInternationalization`. libSwiftUI pulls all three `.so`s into the process, so
they're in the global dlsym scope. Symbol binding reaches **0 unresolved** (module split
+ 3 SwiftUI reconstructions + `@_silgen_name` shims in `SwiftUIShim/.../FoundationShims.swift`
for the few API/ABI divergences: `JSONDecoder.decode` gained a defaulted `configuration:`,
`ContiguousBytes`→`Swift._HasContiguousBytes`, the `Date.FormatStyle` two-module split).

---

## 2026-06-08 (cont.): re-rooted AGAIN — not the Data value, not its storage ARC; the wall is the binary's *surrounding* inlined Foundation code corrupting the heap

This session instrumented the actual crash (machold's `MACHOLD_IMMORTAL_DATA` knob + gdb +
disasm of the binary and the Linux toolchain) and overturned the "it's the json `Data`'s
inlined ARC" framing below. New, each independently reproduced:

1. **Size-skew is impossible — disasm proof.** The binary builds its `__DataStorage` by
   reading size/align *from the Linux metadata at runtime*, then calling the imported
   *initializing* init (`cfc`, self in swiftself x20, bytes x0, length x1, returns x0):
   `bl __DataStorageCMa; ldr w1,[x0,#0x30]; ldrh w2,[x0,#0x34]; bl swift_allocObject; …; bl
   __DataStorageC…init(bytes:length:)cfc`. So the allocation is always correctly Linux-sized
   (`Data.InlineSlice.init`, `_Representation.init(count:)` both do this). The whole
   `Data`-from-`String.UTF8View` build (`…DataVyACxc…Tt0g5`) is an Apple specialization
   compiled INTO the binary.
2. **The binary's `Data` is BIT-IDENTICAL to a native Linux `Data`.** A native Linux program
   building the identical 122-B JSON `Data` gives `word0=0x7a00000000`, `word1=0x4000|storage`
   (**tag=1 = `.slice(InlineSlice)`**, range {0,122}) — and the shim prints the binary's value
   as exactly the same. Tag schemes match too (binary `_RepresentationOWOe` and Linux
   `_Representation.withUnsafeBytes` both use bits 63:62; 1→slice→`__DataStorage.withUnsafeBytes(in:apply:)`).
   At a gdb breakpoint the Linux read receives `x2=0x7a00000000, x3=0x4000…|storage` (tag 1) —
   correct. So there is **no layout / representation / tag-encoding difference** in the Data value.
3. **The Linux decoder + heap are HEALTHY in-process.** A shim that ignores the binary's `Data`
   and decodes a FRESH Linux `Data` of the same JSON **succeeds** (`COMPAT-DECODE-OK`, 3
   products). So decode itself works inside machold at the point of failure.
4. **Only routing the BINARY's `Data` through decode corrupts, non-deterministically.** Crash
   site varies run-to-run: `withBufferView` closure `cbz x0`→`brk` (base==0), or
   `JSONScanner.scanString → Array<Int>.append → _consumeAndCreateNew → __malloc_usable_size`
   on a bit-63/48-tagged pointer (the decoder's OWN `[Int]` map array, while the json storage
   stays healthy: refcount `0x1000000003`, `_bytes` valid, `_length=122`), or `InlineData.withUnsafeBytes
   → __swift_instantiateConcreteTypeFromMangledName` → demangler segfault. Different victims,
   same corruptor ⇒ a **heap overflow/over-release whose source is NOT the json Data**.
5. **`MACHOLD_IMMORTAL_DATA` does NOT make it render.** Bumping the storage refcount keeps the
   json storage alive but the probe still crashes (it just moves the crash from the storage's
   own release into downstream code). The post-decode crash (A) — `_swift_release_dealloc` on a
   freed (isa==0) object during `WindowGroup.init(content:)`/view construction — reproduces
   **even with immortal storage and even when decode succeeds (fresh-data shim)**. So crash (A)
   is the over-release of a *different* object, not the json storage.

### Corrected conclusion (supersedes the section below)

The probe's `Data` *value* is fine (identical bits, Linux-built healthy storage) and the Linux
decoder is fine. The wall is the **binary's `-O` Apple-inlined Foundation code that runs around
the decode** corrupting the heap. **Reconstructing just the `Data` internals (old path 1) will
NOT fix it.**

**Version facts (from the binary):** macOS 26.5 SDK, Foundation **5026.5.4**, Swift 6.2.x; our
Linux toolchain is Swift **6.2.4** = `swift-6.2.4-RELEASE` swift-foundation — i.e. the SAME era,
NOT an old-vs-new skew. The `Data` enum/layout is identical (no ObjC-bridged case). One structural
difference: macOS declares Data/UUID/Date in module **`Foundation`** (`10Foundation`, 28× in the
binary), Linux in **`FoundationEssentials`** (`20FoundationEssentials`).

**Hypothesis TESTED AND RULED OUT — "module identity breaks runtime type lookup."** The idea was
that the binary's inlined code resolves `10Foundation.Data` via `swift_getTypeByMangledName…` and
fails because only `20FoundationEssentials.*` is registered. Built the runtime analogue of the
loader's symbol rewrite — interposed BOTH `swift_getTypeByMangledNameInContext2` and
`…InContextInMetadataState2` to rewrite `10Foundation`→split modules (machold.c, `MACHOLD_TYPELOG`).
Result: with both wrappers confirmed installed, the probe makes **ZERO `10Foundation` runtime
lookups** — it gets its Foundation types via **direct metadata-symbol imports** (already
loader-bound), not by name. So module identity is **not** the bug. (The earlier
`InlineData→…instantiateConcreteTypeFromMangledName→…createProtocolCompositionType` crash was
LINUX-internal — libFoundationEssentials instantiating its *own* type after the representation was
misread — not a `10Foundation` lookup.) The interposers are kept as harmless infrastructure.

**What's now ruled out for crash (B):** the Data *value* (bit-identical), its *storage lifecycle*
(immortal didn't fix), *malloc-metadata* corruption (glibc `MALLOC_CHECK_=3`/`PERTURB` gives a clean
logical trap, not a heap-metadata smash), and *runtime type identity* (above). The deterministic
trap under `MALLOC_PERTURB_` is `Data.withBufferView` closure `cbz x0`→`brk` — the decoder receives
**base=0** from a Data whose storage tested valid. Mechanism still unpinned from the Linux side.

**Decisive next lever = `-Onone` rebuild (needs a Mac).** Make the app *call* Foundation instead of
inlining it; if it then renders, the `-O` inlined bodies are conclusively the cause and the fix is to
match their exact source/version (Path A build, or real Foundation). If `-Onone` does NOT fix it, the
problem is deeper (loader metadata registration / `@frozen` interaction), independent of Foundation
version. Path A (build swift-foundation as a `Foundation` module) is now LESS certain to help, since
the disproof shows the symbol/type plumbing already resolves — revisit only if `-Onone` implicates
inlined bodies.

`MACHOLD_IMMORTAL_DATA=1` (in `machold.c`) is kept as a gated diagnostic: it interposes
`__DataStorage.init(bytes:length:)` with an asm trampoline that forwards to the real Linux init
then adds extra retains. Useful for isolating storage-lifecycle from other corruption; it is a
probe knob, not a fix.

---

## ⚠️ 2026-06-08: the earlier "Data layout skew" diagnosis was WRONG — re-rooted

Prior sessions concluded the probe crashed because the `-O` binary inlined Apple's
version-skewed `@inlinable` `Data` and the **layout** (`Data._Representation` byte-packing)
didn't match the Linux toolchain → heap corruption. **This session disproved that by direct
measurement.** The layout matches; the wall is elsewhere (the binary's Apple-compiled ARC
of `Data`). Evidence, each independently reproduced:

1. **The Data layout is IDENTICAL, not skewed.** A native Linux program
   (`/tmp/datalayout.swift`) building the *same* `Data(jsonString.utf8)` (122 bytes) yields
   `word0 = 0x7a00000000` (`{start:0, end:122}`) and `word1 = 0x4000<storage48>` (tag `0x4000`
   in the high bits). The **binary's** `Data`, dumped at the decode-shim entry, is
   structurally identical: `word0 = 0x7a00000000`, `word1 = 0x4000…`, storage `isa` valid,
   `_bytes` a real heap ptr, `_length = 122`, refcount word `0x3` (= a healthy fresh object,
   strong refcount 1). The toolchain's swift-foundation is `release/6.2`, which still uses the
   classic `enum _Representation { empty/inline/slice/large }` (`main` has since refactored it
   to a struct — irrelevant here). 122 bytes → `.slice(InlineSlice{slice: Range<Int32>, storage}`.
2. **The Data CONTENT is correct.** Dumping the 122 bytes at the binary-Data's `_bytes`
   shows exactly the JSON `[{"id":1,"name":"Coffee",...}]`.
3. **Native Linux decodes the identical Data fine** (`/tmp/natdecode.swift` → 3 products).
4. **The Linux JSONDecoder works INSIDE machold** for Linux types & string scanning:
   a shim that decodes `[Int]` from `[10,20,30,40,50]` prints `OK-intdecode-150`; one that
   decodes `[String]` from `["Coffee","Bagel","Orange Juice"]` (exercises `scanString`)
   prints `OK-strdecode-23`. Both from fresh Linux-built `Data`. So `scanString`, the map
   array, and the decoder are NOT broken in machold.
5. **General Linux heap works in machold**: a shim churning 50 000 `[Int]` appends + 10 000
   `String`s completes cleanly; constructing AND releasing a Linux-built `Data` inside the
   shim prints `after-linux-data-release`.

### Where it actually breaks — the binary's Apple-compiled `Data` ARC/lifecycle

The probe crashes in two linked ways, **both rooted in the binary's own Apple-inlined
Foundation code operating its `json` Data**, NOT in layout/content/the decoder:

- **(A) Scope-exit release crash.** With an *empty* decode shim (does nothing, just
  `throw`), the probe still crashes in `_swift_release_dealloc(0xfffffffffffffff0)` when
  `load()` returns — i.e. the binary releasing its own `json` Data (built before it called
  decode). Independent of the shim, the decoder, the error path (reproduces returning a value
  too). Under gdb (different timing) the same corruption surfaces as `malloc(): unaligned
  tcache` inside `State.init(wrappedValue:)`→`_StateLocation` metadata instantiation right
  after `load()`. So by the time `load()` returns the heap is already damaged.
- **(B) Decode-of-binary-Data corruption.** Forwarding the binary's `json` to the real Linux
  decoder crashes in `JSONScanner.scanString → mapData.append → __malloc_usable_size` on a
  **tagged** pointer (`0x8001…`/`0x0001…` = high bits 63/48 OR'd onto a valid heap address).
  Yet decoding the *same string JSON from a fresh Linux Data* works (test 4). So the trigger
  is the **binary's Apple-constructed Data specifically** — most likely a heap-layout- and
  ARC-dependent overflow/over-release, since reading it goes through
  `Data.withBufferView → _Representation.withUnsafeBytes → __DataStorage.withUnsafeBytes`
  which retains/releases the storage around the closure.

The storage object itself is **Linux's** (`__DataStorage.init(bytes:length:)` is an import,
bound to FoundationEssentials; verified it does a clean `malloc(122)` + copy). What's
Apple's is the **inlined `@inlinable`/`@frozen` `Data`/`_Representation`/`InlineSlice` ARC
code baked into the `-O` binary** — its retain/release/destroy of the representation. That
inlined ARC is version-skewed from the Linux runtime's, so the *lifecycle* (not the layout)
disagrees → the storage / adjacent heap is corrupted across construction → borrow → release.

### The corrected key finding

**Foundation's wall for `-O` Darwin binaries is the inlined `@inlinable` ARC/lifecycle of
value types that wrap a class (here `Data`→`__DataStorage`), NOT their `@frozen` layout.**
`libswiftCore` is ABI-stable so its calls bind straight through; `Data`'s *layout* also
happens to match `release/6.2`; but the binary's *baked-in retain/release/destroy logic*
for the `Data` representation is from Apple's exact swift-foundation version and is skewed
from the Linux toolchain's. Symbol names bind, layout matches, **the inlined ARC corrupts.**

## Paths forward (revised by this diagnosis)

> ⚠️ **Superseded by the 2026-06-08 (cont.) section at the top.** Path 1 below is now RULED
> OUT (the corruption is not in `Data` — its value/storage are bit-identical to a working
> native Linux `Data`, and `MACHOLD_IMMORTAL_DATA` confirmed making the storage immortal does
> not fix it). The immortal-`__DataStorage` "cheap validation" was DONE: it does not render.
> Pursue path 2 (real Foundation) or path 3 (`-Onone`). Kept below for history.

1. **Reconstruct just the `Data` internals the binary imports** (`__DataStorage`,
   `Data._Representation` ops, `InlineSlice`/`LargeSlice`/`RangeReference`) with
   Apple-matching `@frozen` layout **and our own bodies**, so the binary's inlined ARC binds
   to internals whose retain/release semantics it agrees with. Scope is much smaller than
   "all of Foundation" — and the layout is already reverse-engineered. JSONDecoder/Date/UUID
   can stay Linux (they work). This is the most promising next step.
   - Cheap validation first: confirm the **double-release/over-release** hypothesis (B/A) by
     making the `__DataStorage` *immortal* (extra retains so the binary's buggy release is a
     no-op; leaks ~122 B/load — fine for a probe). If the probe then renders, it proves the
     wall is the storage ARC and that reconstruction will fix it. (Blocked on cleanly
     forwarding the imported initializer's `swiftself` ABI from a shim — solvable.)
2. **Use Apple's real Foundation** (Darling-style, `REAL-FOUNDATION-PLAN.md`) — the inlined
   ARC then matches its real callee byte-for-byte, but pulls in CoreFoundation/objc/libSystem.
3. **Cheap signal: rebuild `FoundationProbe` with `-Onone`** (needs a Mac) → the binary then
   *calls* `Data.init`/release instead of inlining them, so all ARC runs in the consistent
   Linux Foundation. If it renders, it confirms inlined-ARC is the sole culprit. Real shipped
   apps are `-O`, so this is a diagnostic, not a solution.

## Status

- [x] Loader: Foundation module-split fallbacks + `__stack_chk_*`. Hello + Gallery unaffected.
- [x] Built + ran `FoundationProbe`; bound every import (0 unresolved).
- [x] **Re-rooted the crash (2026-06-08): NOT a Data layout skew.** Layout + content +
      storage all verified correct & identical to native; native decode works; the Linux
      decoder + heap work in machold (`[Int]`/`[String]` decode, 50k-array churn, Linux-Data
      release all succeed). The wall is the **binary's Apple-inlined `Data` ARC/lifecycle**
      (scope-exit `_swift_release_dealloc` crash + decode-of-binary-Data heap corruption),
      reproducible with an empty shim. `FoundationShims.swift` simplified to a thin forward.
- [x] **Re-rooted AGAIN (2026-06-08 cont.) — see the top section.** Disasm proved size-skew
      impossible (runtime metadata-sized alloc). The binary's `Data` is bit-identical to native
      Linux's (tag=1 `.slice`, valid Linux storage) and a fresh Linux `Data` decodes fine
      in-process — so it's NOT the Data value/representation/storage. The wall is the binary's
      surrounding `-O` Apple-inlined Foundation code corrupting the heap (non-deterministic
      crash sites) + a post-decode over-release of a non-storage object. Added
      `MACHOLD_IMMORTAL_DATA` (gated asm trampoline interposing `__DataStorage.init(bytes:length:)`)
      as a diagnostic; it does NOT make the probe render. **Path 1 (reconstruct Data internals)
      ruled out** — corruption isn't in `Data`.
- [ ] **Next:** path 2 (real Apple Foundation, `REAL-FOUNDATION-PLAN.md`) or path 3 (`-Onone`
      rebuild on a Mac — decisive cheap confirm that inlined bodies are the culprit). To pin the
      first-corrupting inlined site without a Mac: a malloc-hardened / watchpoint run (the read
      path is too hot for naive gdb breakpoints).
- [ ] Attempt a real third-party SwiftUI app binary; triage AppKit/ObjC.
