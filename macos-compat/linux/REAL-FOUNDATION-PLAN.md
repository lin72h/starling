# Foundation plan — re-grounded 2026-06-08 (cont.)

> ⚠️ **This doc's original premise (load Apple's real Foundation Mach-O, "the Darling
> approach") is demoted.** It is (a) legally problematic — copying Apple's closed framework
> off a Mac and running it on non-Apple hardware violates the macOS SLA + copyright; it can't
> be distributed; "the Darling approach" is actually *reimplementation*, not shipping Apple's
> binary — and (b) **technically unnecessary**, per the measurements below. The original
> phased plan is kept further down as **Path C (last resort)**.

## What the binary measurements actually say

Hard facts pulled from `probe/FoundationProbe` + the toolchain:

| | macOS app (probe) | Linux backing we provide |
|---|---|---|
| Compiler | Swift 6.2.x (macOS 26.5 SDK, minos 14.0) | Swift **6.2.4** |
| Foundation | framework **5026.5.4** | swift-foundation **swift-6.2.4-RELEASE** |
| `Data`/`UUID`/`Date` module | **`Foundation`** (mangled `10Foundation`, 28× in binary) | **`FoundationEssentials`** (`20FoundationEssentials`) |
| `Data._Representation` | empty/inline/slice/large — **no ObjC-bridged case** | identical enum, identical layout |

Consequences:

1. **Not a snapshot/version skew.** Both sides are Swift 6.2.x and we *already have* the
   matching-era swift-foundation on disk (`swift-6.2.4-RELEASE`). The `Data` value is
   byte-identical (verified: `word0=0x7a00000000`, `word1=0x4000|storage`, tag=1 `.slice`).
2. **Not ObjC bridging / not "needs CoreFoundation+objc."** The binary's `Data._Representation`
   has no bridged/`.custom` case; its inlined storage construction is pure Swift
   (`swift_allocObject` sized from *Linux* metadata + the imported initializing init).
3. **The real divergence is MODULE IDENTITY.** macOS declares `Data` in module `Foundation`
   (`10Foundation4DataV`); Linux declares it in `FoundationEssentials`
   (`20FoundationEssentials4DataV`). `machold` rewrites that for *symbol binding* (dlsym), but
   **not** for *runtime type lookup*.

## A hypothesis I tested and RULED OUT — "module identity breaks runtime type lookup"

The idea: the binary's inlined code resolves `10Foundation.Data` via `swift_getTypeByMangledName`,
and fails because the Linux runtime only registered `20FoundationEssentials.*`. Tested it directly:
interposed BOTH `swift_getTypeByMangledNameInContext2` and `…InContextInMetadataState2` in
`machold` to rewrite `10Foundation`→split modules (`MACHOLD_TYPELOG`). **Result: the probe makes
ZERO `10Foundation` runtime lookups** — it gets its Foundation types via *direct metadata-symbol
imports* (already loader-bound), not by mangled name. So module identity is **not** the cause, and
the SwiftUI analogy doesn't transfer (SwiftUI types ARE looked up by name; Foundation's here aren't).
The interposers are kept as harmless infra (the runtime analogue of the symbol rewrite) — a fuller
app may exercise them, but FoundationProbe doesn't.

## Where that leaves the diagnosis

For crash (B), now ruled out: the Data *value* (bit-identical to native), its *storage lifecycle*
(immortal `__DataStorage` didn't fix), *malloc-metadata* corruption (`MALLOC_CHECK_=3`/`PERTURB`
gives a clean logical trap), and *runtime type identity* (above). Under `MALLOC_PERTURB_` the trap is
deterministic: `Data.withBufferView`'s closure gets **base=0** from a Data whose storage tested
valid. The mechanism is not pinned from the Linux side.

## Paths, re-ranked

### Path B — `-Onone` rebuild (needs a Mac): the decisive next lever — DO THIS FIRST
Rebuild `FoundationProbe` `-Onone` so it *calls* Foundation instead of inlining it. If it renders
against the current Linux backing, the `-O` inlined bodies are conclusively the cause. If it does
NOT, the problem is deeper (loader metadata registration / `@frozen` interaction) and independent of
Foundation version — which would redirect the whole effort. Real apps ship `-O`, so this is a
diagnostic, but it's the cheapest way to bisect "inlined bodies vs. loader/runtime."

### Path A — build swift-foundation as a `Foundation`-named module for Linux/arm64 — only if `-Onone` implicates inlined bodies
Apache-2.0, legal, distributable; no objc/CoreFoundation/Apple binary. Build swift-foundation
(`swift-6.2.4-RELEASE`) for `aarch64-unknown-linux-gnu` under `-module-name Foundation` so types are
`10Foundation.*`, and bind straight through. **Note:** the module-identity disproof above means this
is no longer clearly *the* fix (the symbol/type plumbing already resolves); pursue only if `-Onone`
shows the inlined bodies are version/source-skewed from our backing.
Build sketch (if pursued): clone at `swift-6.2.4-RELEASE`; build `FoundationEssentials` +
`FoundationInternationalization` sources with `swiftc -module-name Foundation` (collapse the split —
the same way `build.sh` builds `libSwiftUI.so`); load GLOBAL in `machold`; drop the module rewrite;
diff against macOS 5026.5.4 for Darwin-only `#if canImport(Darwin)` paths the inlined code may take.

### Path C — real Apple Foundation (the original plan below): LAST RESORT
Only if A/B reveal genuine Darwin-overlay/objc dependencies. Legal caveats above; do not distribute.

---

# (Path C, retained) Option 2 — adopt Apple's *real* Foundation (the Darling-style bring-up)

This is the biggest path. The plan below is incremental and each phase is independently
testable. **Pursue only if Path A/B are blocked** (see top of file).

## Architecture

```
  unmodified probe (arm64 Mach-O)
        │  imports
        ├── SwiftUI            → our reconstruction (libSwiftUI.so)         [done]
        ├── libswiftCore       → Linux toolchain libswiftCore.so (ABI-stable) [done]
        ├── libSystem.B        → glibc + our Mach/BSD shims                  [bottom layer]
        └── Foundation         → REAL Apple Foundation.framework (Mach-O)    [option 2]
                                     │ which itself needs:
                                     ├── CoreFoundation   (real Mach-O)
                                     ├── libobjc.A        (real Mach-O / our objc)
                                     ├── libicucore, libnetwork, …
                                     └── libSystem        → Mach traps + BSD syscalls
                                                              + libmalloc/libdispatch/pthread
                                                              → Linux-backed shims (Darling core)
```

The win: a per-dependency **provider policy** — keep SwiftUI reconstructed and libswiftCore
Linux-backed, but load Foundation/CoreFoundation/libobjc as *real* Apple Mach-O, and back
their `libSystem` floor with Linux. We do NOT need all of macOS — only the surface real
Foundation actually pulls (much smaller than full Darling).

## Phases

- **0. Dependency map [done].** `machold` parses `LC_LOAD_DYLIB`/`LC_LOAD_WEAK_DYLIB`/
  `LC_REEXPORT_DYLIB` and classifies each dep (`[reconstructed]` / `[Linux-backed]` /
  `[needs real Mach-O → bottom layer]`). `MACHOLD_VERBOSE=1` prints the graph.
- **1. Get + analyze real Foundation.** Extract the arm64 `Foundation` dylib (and, once we
  read its load commands, its dep chain) from the Mac that built the probe. Analyze its
  `LC_LOAD_DYLIB` tree + undefined symbols → the precise bottom-layer work-list.
- **2. `machold` → real dyld.** Generalise the existing map+chained-fixups path to load a
  *dylib* (no `LC_MAIN`; register its export trie `LC_DYLD_EXPORTS_TRIE`), recurse over
  `LC_LOAD_DYLIB`, and do two-level binding (bind each import to the *named* dylib's
  exports). Provider policy decides real-Mach-O vs Linux-backed per dylib.
- **3. `libSystem` floor (the Darling core, scoped).** Implement only the Mach traps + BSD
  syscalls + `libmalloc`/`libdispatch`/`pthread`/`libplatform` symbols that *this*
  Foundation imports, backed by Linux (mmap/futex/pthread/io). This is the bulk of the work
  but bounded by phase 1's measured surface.
- **4. ObjC + CoreFoundation.** CoreFoundation needs the ObjC runtime. Load Apple's real
  `libobjc.A.dylib` (preferred — matches the class layouts) on the phase-3 floor, or a
  minimal objc. Bring up CoreFoundation on top.
- **5. Wire Foundation under the probe.** Resolve the probe's `$s10Foundation…` /
  CoreFoundation imports to the *real* Foundation's exports instead of Linux swift-foundation.
  Re-run `FoundationProbe`: the inlined `Data(…utf8)` / `JSONDecoder.decode` now match their
  real callee → JSON decodes, the list renders. Remove the `FoundationShims.swift` stopgaps.

## What I need from the Mac (phase 1 unblocker)

Extract from the **same Apple Silicon Mac that built `probe/FoundationProbe`** (so the
Foundation version matches the inlined code — the probe links Foundation **5026.5.4**),
from the arm64e dyld shared cache. Start with just Foundation; I'll read its load commands
to enumerate the rest.

```bash
# Easiest with ipsw (https://github.com/blacktop/ipsw):
ipsw dyld extract /System/Volumes/Preboot/.../dyld_shared_cache_arm64e \
  /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation -o /tmp/fwk
# or any dyld-shared-cache extractor. Then copy the extracted Foundation here:
#   macos-compat/probe/macos-fw/Foundation
```

Drop it in `probe/macos-fw/` and I'll analyze its dependency tree + import surface and start
phase 2. (If extraction is a pain, the cheap `-Onone` confirm from FOUNDATION-WORKLIST.md is
still a useful parallel signal.)

## Status

- [x] Phase 0 — dependency map in `machold` (`MACHOLD_VERBOSE=1`).
- [ ] Phase 1 — real arm64 `Foundation` extracted + analyzed.
- [ ] Phases 2–5 — dyld, libSystem floor, objc/CF, wire-up.
