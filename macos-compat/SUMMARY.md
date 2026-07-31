# macOS binary-compat via Flutter — work summary

Goal: run an **unmodified, precompiled** macOS app binary (Mach-O, arm64) with **no
recompile**, by reimplementing Apple's GUI frameworks (SwiftUI first) on top of this
repo's Flutter engine + Swift Flutter widgets.

The **cut line** is the GUI frameworks: below it we reuse the existing Swift runtime;
at SwiftUI we route into Flutter — sidestepping the un-emulatable parts (WindowServer,
CoreAnimation render server, Metal/GPU). Both sides are arm64, so **no CPU emulation**.

> **Status:** unmodified macOS SwiftUI binaries now run **on Linux/arm64** — loaded by
> a from-scratch Mach-O loader (`machold`), bound against the stock Linux Swift runtime
> + our reconstructed `SwiftUI`/`Combine`, and rendered through the Flutter engine in a
> real window. A large SwiftUI surface works (incl. `ObservableObject`/`@Published`
> reactivity). The per-feature work-list + status lives in **`NEXT-FEATURES.md`**.

## Two phases

**Phase 1 — proof on macOS (2026-06-04).** Reconstruct `SwiftUI` as a module literally
named `SwiftUI` (so symbols mangle `7SwiftUI…`, matching the binary — Apple's
`SwiftUICore` split is invisible at the ABI via `@_originallyDefinedIn("SwiftUI")`),
interpose it under the unmodified binary via `DYLD_FRAMEWORK_PATH`, and render through
FlutterMacOS. Reached `App.main()`, walked the view tree, round-tripped `@State`, and
showed a live, clickable counter — all from the unmodified binary, no recompile. This
validated the mechanism and forced the exact `@frozen` layout matching (below).

**Phase 2 — moved to Linux/arm64 + grew the framework (2026-06 →).** Built the
"bottom layer" the plan called for and crossed to Linux, where verification now happens:

- **`machold`** (`linux/loader/machold.c`) — a minimal Mach-O loader/runner: maps the
  image, applies `LC_DYLD_CHAINED_FIXUPS`, binds every imported symbol by **name** to the
  Linux-built `SwiftUI`/`Combine` + stock `libswiftCore`/Foundation (with a few
  Darwin↔Linux mangling rewrites), registers the image's Swift metadata sections, and
  jumps to `LC_MAIN`. **No dyld, no ObjC runtime, no Mach IPC** — a pure-SwiftUI app needs
  none (measured: `objc_msgSend` count = 0 across all probes).
- **Render via the real `_makeView` witness ABI** (not reflection): our views implement
  SwiftUI's `_makeView` and the walk dispatches through the View witness table, producing
  a neutral render-node tree → JSON → the host. (Reflection is used only to flatten
  `TupleView`/`ForEach`/`Group`.)
- **Two host modes** (`linux/`): **L2** (`libcompat_host.so`, a Swift `CompatHost`) boots
  the Flutter engine over GLFW/Wayland and draws a real window; **L1** (`--stub`) just
  prints the JSON tree (fast for bring-up). Interaction (button/stepper/tab/nav taps)
  routes back through `swiftui_compat_dispatch` → the SwiftUI action → re-walk → re-render.

## What works now (see `NEXT-FEATURES.md` for the full table)

Layout & views: `Text`, `VStack`/`HStack`/`ZStack` (+ cross-axis **alignment**),
`LazyVStack`/`LazyHStack`/`List`/`LazyVGrid`, `ScrollView`, `Spacer`/`Divider`,
`Image`, `Color`, `Label`, `ProgressView`, `Button`/`Toggle`/`TextField`/`Slider`/`Stepper`,
`Picker` (+`.tag`, tap-to-select).
Modifiers: `.padding`, `.frame`(+`maxWidth:`fill), `.background`/`.overlay` (Color /
gradient / shape, + overlay `alignment:`), `.clipShape`/`.cornerRadius`, `.foregroundColor`,
`.font`/`.bold`. Shapes: `Rectangle`/`RoundedRectangle`/`Circle`/`Capsule`/`Ellipse`.
Gradients: `Linear`/`Radial`/`Angular`. Control flow: `if`/`if let`/`if-else`, `ForEach`,
`AnyView`. Effects: `.opacity`/`.scaleEffect`/`.shadow`, `.disabled`, `.lineLimit`.
Navigation/containers: `TabView` (+`.tabItem`, tap-to-switch), `NavigationStack`/`NavigationLink`,
`GeometryReader`, `Grid`/`GridRow`, `Form`/`Section`, `Menu` (tap-to-expand), `.sheet` (modal
presentation + scrim dismiss), `.navigationTitle`; interaction: `.onTapGesture`, `.onChange`,
`.buttonStyle(.borderedProminent)`; environment: `@Environment(\.…)` (injected pre-`body`),
`@AppStorage`, `@SceneStorage`; async: **`.task {}`** — the binary's Darwin-compiled async
closure runs on Linux's Swift-concurrency runtime. Sweep 3 added the long tail: `.alert`,
`.toolbar`, `.contextMenu`, `SecureField`/`TextEditor`/`GroupBox`/`LazyHGrid`,
`Text.foregroundStyle`/`.italic`, `Font.system(size:)`, `.offset`/`.rotationEffect`/`.blur`/
`.fixedSize`/`.ignoresSafeArea`/`.id`, `Shape.fill`, `.onHover`/`.onSubmit`,
`.animation`/`withAnimation`/`.transition` (snap), `.tint`, `.toggleStyle`/`.textFieldStyle`.
Remaining walls: `DragGesture` (gesture system), `@FocusState`, `Shape.stroke`/`.border`
(assessed — see NEXT-FEATURES). State: `@State`/`Binding`, and **`ObservableObject`/`@StateObject`/
`@ObservedObject`/`@Published`/`@EnvironmentObject`** — including class realization of the
binary's ObjC-interop model class on Linux **with no ObjC runtime**, `@StateObject`
persistence, environment injection (`.environmentObject(_:)` → keypath write → raw-pointer
`_store` injection before `body`), and reactivity (button-driven, push-based
`@Published`/`objectWillChange`, `.onAppear`, and `.sink` subscribe-time delivery).

## Hard-won findings

- **Name mangling is deterministic** from module name + signature → a module named `SwiftUI`
  reproducing the public API re-emits the exact symbols; the loader binds by **name**.
  Protocol **member order** (`App`/`View`/`Scene`) is ABI-critical. Watch the declaration
  FORM (a constraint on an extension vs on the method changes the mangling — cost debug
  rounds on `NavigationStack`, `ProgressView`; always diff `nm -D … | swift demangle`
  against the machold `UNRESOLVED` symbol).
- **`@frozen` layout fidelity is the core difficulty.** `@frozen` types are passed by value
  and the app *inlines* copy/destroy at Apple's exact layout, so ours must match byte-for-byte
  (resilient types are safe via the value-witness table). Match sizes, value representation
  (`Text` stores `.anyTextStorage(class)`), and **generic constraints** (they shift the
  metadata's field-offset vector). A too-small `@frozen` field silently smashes the heap.
- **`-O` macOS binaries inline resilient-class allocation & protocol dispatch thunks with
  Darwin ABI assumptions baked in** — machold patches those at the instruction level
  (`metafix`: rewrite class-metadata `instanceSize` reads `0x30/0x34`→`0x18/0x1c`) and via
  naked-asm trampolines (the `ContiguousBytes.withUnsafeBytes` witness thunk), since by-name
  binding can't fix a wrong struct offset or calling convention. This cracked the Foundation
  `Data`/JSON decode wall.
- **`#available` must answer FALSE coherently, everywhere.** Every macOS binary statically
  links compiler-rt's `os_version_check.c`, which (with `__availability_version_check` a NULL
  weak import) probes CoreFoundation via `dlsym(RTLD_DEFAULT, …)` — with **Darwin's**
  `RTLD_DEFAULT = −2`, which glibc dereferences → SIGSEGV (the `Picker`/`.tag` wall). machold
  interposes the app's `dlsym` (pseudo-handles −1/−2/−3/−5 → Linux `RTLD_DEFAULT`) and pins
  all THREE `#available` mechanisms to FALSE (its stdlib-variant stub, Linux libswiftCore's
  own `false`, compiler-rt's plist-less 0.0.0): an opaque type's kind-9 accessor picks the
  TYPE metadata with compiler-rt while the inlined body picks the VALUE representation with
  the stdlib entry — if the verdicts differ, value layout and metadata silently diverge.
- **ObjC-interop class realization without an ObjC runtime.** The binary's `class M:
  ObservableObject` is an ObjC-interop Swift class; machold synthesizes the root/metaclass +
  empty cache, runs the metadata completion itself, converts the class metadata Darwin→Linux
  (header-only — leave the trailing vtable/field-offset vector at Darwin offsets, which the
  binary hardcodes), populates the ObjC ivar-offset (`Wvd`) globals the field access reads,
  and clears the singleton-init flag so keypath construction fast-paths. No `objc_msgSend`.
- **The `SwiftUI` module must import only Foundation** (importing Flutter/AppKit pulls Apple's
  `SwiftUICore`, whose `@_originallyDefinedIn("SwiftUI")` symbols collide → SIL crash). So the
  Flutter host is a separate module reached via C symbols, passing the tree as JSON.

## Current state & what's left

Running end-to-end on Linux for the whole feature set above (each verified by a probe under
`machold` — JSON tree and/or an L2 frame). The remaining `NEXT-FEATURES.md` items are all
**deep mechanisms**, not more type reconstruction:

1. **`LayoutBuilder`** (a core-Flutter build-during-layout widget) → true per-region
   `GeometryReader` geometry + `RadialGradient` fractional radii.

## Build & run

Linux (the current path — see [`linux-dev-box`] notes / `linux/README.md`):

```bash
cd macos-compat/linux
./build.sh            # L2: libCombine.so, libSwiftUI.so, libcompat_host.so (Flutter), machold
./build.sh --stub     # L1: C host that prints the JSON tree (fast bring-up)
./run.sh ../probe/<Probe>          # run an unmodified probe binary through machold
MACHOLD_DUMP=/tmp/x.ppm ./run.sh ../probe/<Probe>   # dump an L2 frame; MACHOLD_TAP=N taps button 0
```

macOS (Phase-1 proof; only `SwiftUI`-bound probes like `Hello` — newer probes bind
`SwiftUICore` and must be verified on Linux):

```bash
cd macos-compat && ./build.sh
DYLD_FRAMEWORK_PATH="$PWD/build" ./probe/Hello
```

New feature bring-up: write `probe/D_x.swift`, build with
`xcrun swiftc -parse-as-library -O -o D_x D_x.swift`, run under machold; the
`MACHOLD_VERBOSE=1` `UNRESOLVED` lines are the per-feature work-list.
