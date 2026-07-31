# Issue: decoding a macOS-built `Data` crashes the Linux Foundation decoder under `machold`

> **RESOLVED 2026-06-09.** Root cause was NOT Foundation version/inlining skew. Two
> loader bugs in `machold` corrupted the heap; both are fixed and all four bisect probes
> (`{Json,Data}Probe_{O,Onone}`) now pass. See **Resolution** at the bottom. The rest of
> this file is the original investigation, kept for context.

Self-contained writeup + bisect probes. Deep history is in `FOUNDATION-WORKLIST.md`; the
options analysis is in `REAL-FOUNDATION-PLAN.md`. This file is the actionable summary.

## Setup

`machold` (this repo, `linux/loader/machold.c`) loads an **unmodified macOS arm64 Mach-O** on
**Linux/arm64**: maps the image, applies chained fixups, binds the imported symbols **by name**
to the host, registers the binary's Swift metadata, and jumps to `LC_MAIN`. No CPU emulation
(arm64→arm64); the GUI is replaced by a reconstructed `SwiftUI` module that renders via Flutter.

Symbol providers:
- **SwiftUI** → our reconstruction (`libSwiftUI.so`, module `SwiftUI`).
- **libswiftCore** → Linux toolchain `libswiftCore.so` (ABI-stable; binds straight through).
- **Foundation** → Linux toolchain swift-foundation (`libFoundationEssentials.so`, etc.).

Hello (SwiftUI only) and Gallery (SwiftUI only) **work** — they render and respond to input.

## Symptom

`probe/FoundationProbe` (SwiftUI **+ Foundation**: `Data` + `JSONDecoder`/`Codable`, `UUID`,
`Date`/`FormatStyle`) binds with **0 unresolved imports** but **crashes instead of rendering**.
The crash is in the Linux JSON decoder while it processes the app's `Data`:

```
JSONDecoder.decode<A>(_:from:)                         (libFoundationEssentials)
 └ withUTF8Representation → Data.withBufferView → Data.withUnsafeBytes
    └ JSONScanner.scanString → Array<Int>.append
       └ _ContiguousArrayBuffer._consumeAndCreateNew → __malloc_usable_size  → SIGSEGV
```

The crash **site is non-deterministic** (allocator-mode dependent): also seen as a
`Data.withBufferView` closure trap (`cbz x0; brk` — a null buffer base), and as an
`InlineData.withUnsafeBytes → swift_getTypeByMangledName → createProtocolCompositionType` segv.
Different victims, same trigger → **heap corruption**.

## Versions (pulled from the binary + toolchain)

| | macOS app (probe) | Linux backing |
|---|---|---|
| Compiler | Swift 6.2.x (**macOS 26.5 SDK**, `minos 14.0`) | Swift **6.2.4** |
| Foundation | framework **5026.5.4** | swift-foundation **`swift-6.2.4-RELEASE`** |
| `Data`/`UUID`/`Date` module | **`Foundation`** (`10Foundation`) | **`FoundationEssentials`** (`20FoundationEssentials`) |
| `Data._Representation` | empty/inline/slice/large — **no ObjC-bridged case** | identical enum + layout |

Both sides are Swift 6.2.x and share the same swift-foundation era — this is **not** an
old-vs-new version skew.

## What is CONFIRMED HEALTHY / RULED OUT (with evidence)

The app's `Data` and the Linux decoder are each fine *in isolation*; only their combination fails.

1. **Data value is bit-identical to native Linux.** Building the identical JSON `Data` natively
   on Linux gives `word0=0x7a00000000` (range `{0,122}`), `word1=0x4000|storage`
   (**tag=1 `.slice`**), `count=122`. The binary's `Data`, dumped at the decode-shim entry, is
   the same. No layout / representation / tag-encoding difference.
2. **Storage is Linux-built and healthy.** The binary allocates `__DataStorage` with
   `swift_allocObject` sized from the **Linux** metadata at runtime, then calls the imported
   Linux `__DataStorage.init(bytes:length:)`. A **hardware watchpoint** on the storage's `_bytes`
   field shows exactly two writes, both inside that init (`0x0` then the malloc'd copy
   `0xaaaa…5750`), and **never corrupted afterward**. `_length=122`, refcount healthy.
3. **The Linux decoder + heap are healthy in-process.** A shim that ignores the binary's `Data`
   and decodes a **fresh Linux `Data` of the same JSON succeeds** (3 products). So decode itself
   works at the point of failure.
4. **Not malloc-metadata corruption.** Under `MALLOC_CHECK_=3` / `MALLOC_PERTURB_` the failure is
   a *clean logical trap* (null buffer base), not a heap-metadata smash.
5. **Not module identity / runtime type lookup.** Interposing both
   `swift_getTypeByMangledNameInContext2` and `…InContextInMetadataState2` (rewriting
   `10Foundation`→split modules, `MACHOLD_TYPELOG`) shows the binary makes **zero `10Foundation`
   runtime lookups** — it gets Foundation types via direct metadata-symbol imports
   (already loader-bound), not by name.
6. **Not the `Data` storage's ARC.** Making `__DataStorage` immortal (`MACHOLD_IMMORTAL_DATA`,
   extra retains) keeps it alive but does **not** stop the crash.

## The open question

> The app's `Data` is bit-identical to a native Linux `Data` (same bytes, same `.slice`
> representation, same valid Linux-built storage). A fresh Linux `Data` of those bytes decodes
> fine in-process. **Why does feeding the *binary's* `Data` to the same decoder corrupt the
> decoder's own internal `[Int]` array?**

Leading theory: the `-O` macOS binary **inlines Apple's `@inlinable` Foundation** (the
`Data`-from-`Sequence` builder, `UUID`, `Date`, `FormatStyle`, `String(format:)`) directly into
the app. Those baked-in bodies share a heap + ARC with the Linux runtime; a subtle skew there
corrupts. **Unconfirmed** — needs the bisect below.

## Bisect — how to confirm (build on a Mac, run under `machold` on Linux)

Two minimal probes, each built `-O` **and** `-Onone`. `-Onone` makes the app *call* Foundation
instead of inlining it; if that fixes it, inlined bodies are the cause.

### Probe A — `probe/JsonProbe.swift` (console, **no SwiftUI** — isolates Foundation from the render path)

```swift
import Foundation
struct Product: Codable { let id: Int; let name: String; let price: Double }
let json = Data(#"[{"id":1,"name":"Coffee","price":3.5},{"id":2,"name":"Bagel","price":2.25},{"id":3,"name":"Orange Juice","price":4.0}]"#.utf8)
let ps = (try? JSONDecoder().decode([Product].self, from: json)) ?? []
print("decoded \(ps.count): \(ps.map { $0.name })")
```

### Probe B — `probe/DataProbe.swift` (even narrower: `Data` construct + read, **no JSONDecoder**)

```swift
import Foundation
let d = Data(#"[{"id":1,"name":"Coffee"}]"#.utf8)
let n = d.withUnsafeBytes { $0.count }          // exercises Data.withUnsafeBytes / _Representation
let sum = d.reduce(0) { $0 + Int($1) }
print("count=\(d.count) ubcount=\(n) sum=\(sum)")
```

### Build (on the Mac that built `FoundationProbe`)

```bash
SDK="$(xcrun --show-sdk-path)"
for P in JsonProbe DataProbe; do
  xcrun swiftc -target arm64-apple-macos14.0 -sdk "$SDK" -O     -o "${P}_O"     "${P}.swift"
  xcrun swiftc -target arm64-apple-macos14.0 -sdk "$SDK" -Onone -o "${P}_Onone" "${P}.swift"
done
```
Copy the four binaries (`JsonProbe_O`, `JsonProbe_Onone`, `DataProbe_O`, `DataProbe_Onone`)
into `flutter_swift/macos-compat/probe/`.

### Run (on Linux)

```bash
cd flutter_swift/macos-compat/linux
./build.sh                       # builds machold + libSwiftUI + host
./run.sh ../probe/JsonProbe_O    # prints "decoded 3: [...]" on success, or crashes
./run.sh ../probe/JsonProbe_Onone
./run.sh ../probe/DataProbe_O
./run.sh ../probe/DataProbe_Onone
```
(These print to stdout; no window. Add `MACHOLD_VERBOSE=1` for loader tracing.)

## Decision matrix

| build | result under machold | conclusion → next step |
|---|---|---|
| `JsonProbe_O` | prints "decoded 3" | Foundation decode works in isolation → the `FoundationProbe` crash is the **SwiftUI × Foundation render-path interaction**, not Foundation. Refocus there. |
| `JsonProbe_O` | crashes | the wall is **inlined `-O` Foundation decode** — continue ↓ |
| `JsonProbe_Onone` | prints "decoded 3" (while `_O` crashed) | **inlining is the cause.** Fix = match the inlined source/version (build matching `swift-foundation`) or use real Apple Foundation. |
| `JsonProbe_Onone` | crashes too | problem is **deeper than inlining** — our loader / metadata registration / `@frozen` handling. A Foundation rebuild won't help; redirect to the loader. |
| `DataProbe_O` | crashes (while `JsonProbe`… ) | narrows the culprit to **`Data` construct/read inlining** itself (no JSON needed). |
| `DataProbe_O` | works, `JsonProbe_O` crashes | culprit is in the **decoder** path specifically, not bare `Data`. |

## Diagnostic knobs already in `machold` (Linux side)

- `MACHOLD_VERBOSE=1` — segment maps, binds, fixups, dependency classification.
- `MACHOLD_IMMORTAL_DATA=1` — interpose `__DataStorage.init(bytes:length:)`, add extra retains
  (tests storage over-release; does NOT fix the probe).
- `MACHOLD_TYPELOG=1` — log the binary's `10Foundation` runtime type lookups (shows none).

## What to report back

For each of the four binaries: the full stdout/stderr (success line, or the `*** Program
crashed ***` backtrace). That populates the matrix and pins which of the three remaining
theories is real.

---

## Resolution (2026-06-09)

Ran the matrix on Linux/arm64. Result: **`_Onone` passed, `_O` crashed** — which the matrix
reads as "inlining is the cause." That was a red herring: the real cause was the **kind of
code `-O` inlines into the app**, not a version mismatch in it. Apple's Foundation source
*is* the open-source `swiftlang/swift-foundation` (proven by `-package-name FoundationPreview`
in the SDK swiftinterface), and the inlined `Data.InlineSlice` bodies match `swift-6.2.4-RELEASE`
exactly outside `#if FOUNDATION_FRAMEWORK`. No Foundation rebuild was needed. Two **loader**
bugs in `machold` were the whole story; both are ABI-translation gaps, not Foundation skew.

**Bug 1 — Darwin class-metadata size offsets (the heap smasher).** With ObjC interop, Apple
class metadata is `{isa, superclass, cache, vtable, data, …}` so `instanceSize`/`instanceAlignMask`
sit at **+0x30 / +0x34**. Linux Swift class metadata has only the 16-byte `{kind, superclass}`
header → the same fields are at **+0x18 / +0x1c**. The `-O` app inlines resilient class allocation
(`metadata accessor → load size/align → swift_allocObject`) with the **Darwin** offsets baked in.
Run against `machold`-provided **Linux** `__DataStorage`/`RangeReference` metadata, it read size/align
from the wrong words → under-sized `swift_allocObject` → the class initializer wrote ivars past the
block → `malloc(): unaligned tcache chunk` / `free(): invalid size`, at non-deterministic sites.
Fix: after applying fixups, scan executable segments for the exact idiom
`LDR Wt,[Xn,#0x30]; LDRH Wt2,[Xn,#0x34]` (same base reg) and rewrite the displacements to `#0x18`/`#0x1c`
(`loader/machold.c`, "metafix"; 6 sites in JsonProbe). Per-segment `__builtin___clear_cache` over the
**mapped file range only** (the reserved span has PROT_NONE gaps — clearing the whole span segfaults).
Gate: `MACHOLD_NO_METAFIX=1` to disable.

**Bug 2 — `ContiguousBytes.withUnsafeBytes` dispatch thunk (`…P010withUnsafeC0…FTj`).** The `-O`
`Data(<Sequence>)` init inlines a cast to `ContiguousBytes` and calls the protocol **dispatch thunk**,
which uses the witness-method convention (`x4` = conformance witness table, indirect self in the self
register, type-metadata args). The Linux toolchain (built without library evolution) doesn't export
dispatch thunks, and **no Swift-source shim can stand in** — Swift lowers any substitute with the
type-metadata arguments in a different order, so a `Data`- or protocol-extension shim misreads the
registers and ARC-corrupts. Fix: bind the thunk to a tiny **naked asm trampoline** in `machold` that
does exactly what a thunk does — `ldr x9,[x4,#8]; br x9` (slot 1 of the witness table is the protocol's
sole requirement), leaving all argument registers untouched. Removed the old Swift shim in
`SwiftUIShim/Sources/SwiftUI/FoundationShims.swift` that had been mis-binding this symbol.

Also bound `malloc_size` → glibc `malloc_usable_size` (an unrelated missing import that surfaced once
the probes ran far enough to exercise `_ContiguousArrayBuffer` growth).

**Verified:** `P0_print`…`P6_small` micro-probes plus all four bisect binaries print correct output;
`-Onone` still passes (untouched paths). `FoundationProbe` itself no longer hits any Foundation crash.

### Follow-on (2026-06-10): the downstream `_jsonString` crash was a `_PaddingLayout` size mismatch

After the Foundation fix, `FoundationProbe` reached our reconstructed SwiftUI render path and crashed
*nondeterministically* in `_jsonString` (`String.Iterator.next → unsafelyUnwrapped of nil optional`) —
the first Text's string read back as two raw pointers (no `_StringObject` discriminator). Bisected with
pure-SwiftUI probes (zero Foundation): the trigger was `.padding()` on a VStack — the crash rate varied
with heap state, the hallmark of corruption, not a logic bug.

Root cause: our reconstructed `SwiftUI._PaddingLayout` declared `insets: CGFloat?` (16 B) where Apple's
is `insets: EdgeInsets?` (40 B) — a 24-byte `@frozen` size mismatch. The app inlines `@inlinable
padding(_:_:)` and builds Apple's 48-byte `_PaddingLayout`; the runtime then instantiates
`ModifiedContent<VStack<…>, _PaddingLayout>` metadata from our nominal type descriptor at our 24-byte
size. Two conflicting sizes for one nominal type → the by-value modifier copy overruns → heap smash that
lands on whatever Text string sat next in memory. Fix: add `SwiftUI.EdgeInsets` (4 × CGFloat, 32 B) and
make `_PaddingLayout.insets: EdgeInsets?`, matching Apple byte-for-byte. After it, the four padding
probes and `FoundationProbe` are 12/12 clean. This was a SwiftUI-reconstruction layout bug, fully
independent of Foundation — same `@frozen` layout-fidelity discipline as Text/VStack/LocalizedStringKey.
