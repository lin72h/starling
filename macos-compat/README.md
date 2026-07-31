# macOS binary compatibility layer (via Flutter)

Run **unmodified, precompiled** macOS app binaries (Mach-O, arm64) on Linux/arm64
without recompiling — by reimplementing Apple's GUI frameworks (starting with
SwiftUI) on top of this repo's Flutter engine + Swift Flutter widgets.

> **Status:** working end-to-end **on Linux/arm64**. A from-scratch Mach-O loader
> (`linux/machold`) maps an unmodified macOS SwiftUI binary, binds it against the
> stock Linux Swift runtime + our reconstructed `SwiftUI`/`Combine`, and renders it
> through the Flutter engine in a real window. A large SwiftUI surface works,
> including `ObservableObject`/`@Published` reactivity. The per-feature status +
> work-list is in **[NEXT-FEATURES.md](NEXT-FEATURES.md)**; the narrative is in
> **[SUMMARY.md](SUMMARY.md)**.

## Strategy

Develop on **macOS first**, where the loader/dyld/libSystem/objc/Swift-runtime
already exist and work. Replace Apple frameworks **one at a time**, interposing
our dylib under the unmodified binary via `DYLD_FRAMEWORK_PATH` (no recompile).
Once every Apple GUI dependency is replaced by a Flutter-backed implementation,
the remaining dependencies are the portable bottom layer (Swift runtime, objc,
libSystem) — and porting *that* to Linux is the well-understood "Darling" part.

The **cut line** is the GUI frameworks: below it we reuse existing runtimes;
at SwiftUI/AppKit we route into Flutter, which sidesteps the parts nobody can
emulate (WindowServer, CoreAnimation render server, Metal/GPU).

## Why SwiftUI first

A minimal SwiftUI app imports only **86 external symbols**: 57 SwiftUI, 27
Swift-runtime (free — stock open-source runtime), 1 libc (`_memcpy`), 1 CGFloat
metadata. It references **zero** Objective-C and **zero** Foundation symbols —
dramatically simpler than an AppKit/ObjC app (which pulls hundreds of
`objc_msgSend`-dispatched `NS*` symbols + nib loading + responder chain).

## How it works

All SwiftUI symbols mangle as module `7SwiftUI` (Apple uses
`@_originallyDefinedIn(module:"SwiftUI")` even though the code now lives in
`SwiftUICore`). So we reconstruct **one module literally named `SwiftUI`** and
the manglings match. SwiftUI is built with library evolution (it ships a
`.swiftinterface`), so its ABI is resilient and reconstructable: redeclare the
public API with matching signatures and the compiler re-emits the exact mangled
symbols and type descriptors the binary imports.

dyld binds by symbol **name**, not signature — so getting the binary to *load*
only needs the names exported (stub bodies fine). The `App`/`View`/`Scene`
protocol **member order** is ABI-critical and matches Apple's `.swiftinterface`.

Derive the work-list for any target binary with:
```bash
xcrun dyld_info -imports <binary> | awk '{print $2}' | xcrun swift-demangle
```

See **[SUMMARY.md](SUMMARY.md)** for the full narrative of what was built, the key
findings, and the Linux-port dependency analysis.

## Layout

- `SwiftUIShim/` — the SPM package that builds our `SwiftUI.framework` (two targets):
  - `Sources/SwiftUI/` — the reconstructed `SwiftUI` module (Foundation-only,
    library-evolution, Apple install_name). Reconstructed types + the real
    `View._makeView` render pass (reflection only flattens `TupleView`/`ForEach`).
    Also holds `Sources/Combine/` (reconstructed `Combine` for `ObservableObject`).
  - `Sources/FlutterHost/` — imports Flutter/AppKit; JSON tree → Flutter widgets,
    boots the engine + window. Reached from `SwiftUI` via the `swiftui_compat_*` C symbols.
- `build.sh` — `swift build` + assemble `build/SwiftUI.framework` (install_name +
  `@rpath` patch) + symbol-coverage check.
- `probe/Hello.swift` / `probe/Hello` — a minimal SwiftUI app + its compiled binary.
- `SwiftUI/Sources/` — the original standalone (Foundation-only) reconstruction used
  for milestones 1–2a; superseded by `SwiftUIShim/` but kept for reference.

## Build & run

Linux/arm64 (the current path — verification happens here; see [linux/README.md](linux/README.md)):

```bash
cd macos-compat/linux
./build.sh                                # L2: libCombine.so + libSwiftUI.so + libcompat_host.so (Flutter) + machold
./build.sh --stub                         # L1: C host that just prints the JSON tree (fast bring-up)
./run.sh ../probe/<Probe>                 # run an unmodified probe under machold
MACHOLD_DUMP=/tmp/x.ppm ./run.sh ../probe/<Probe>   # dump an L2 frame (MACHOLD_TAP=N synthesises taps)
```

macOS (Phase-1 proof; only `SwiftUI`-bound probes like `Hello` — newer probes bind
`SwiftUICore`, which we don't replace, so they must run on Linux):

```bash
cd macos-compat
./build.sh                                       # SPM build + assemble framework + symbol-coverage check
DYLD_FRAMEWORK_PATH="$PWD/build" ./probe/Hello   # run the unmodified binary on our Flutter-backed SwiftUI
```

## Status

- [x] Measure a minimal SwiftUI binary's exact dependency surface.
- [x] Reconstruct a `SwiftUI` module exporting all 54 needed symbols (lib-evolution, matching install_name).
- [x] **Interpose under the unmodified binary; control reaches our `App.main()`** (no recompile).
- [x] **Introspect the unmodified app's full view tree via reflection** (padding/VStack/Text/Button) and prove `@State` round-trips (button click: count 0→1). Required matching every `@frozen` type's exact layout (see below).
- [x] **Render the tree through the Flutter engine in a real macOS window** — the unmodified binary shows `Text("Count: 0")` + a blue `Increment` button, drawn by Flutter (no recompile). Built as an SPM package (`SwiftUIShim/`).
- [x] **Button interaction**: clicking the rendered button invokes the unmodified app's SwiftUI `action`, mutates `@State`, re-walks the tree, and the counter increments **live on screen**. (Tap → `GestureDetector` → C `swiftui_compat_dispatch(id)` → SwiftUI action → `@State` → re-walk → `swiftui_compat_update` → `setState`.)
  - macOS Swift-mode quirk: `scheduleFrame()` doesn't make the engine deliver a vsync frame on demand (a window resize does, via the metrics path). Workaround in `HostRootState.apply()`: nudge the window content size ±1pt to force a frame. This is a shared engine/macOS-embedder gap, not the compat layer; likely a non-issue on Linux DRM.
- [x] **Switch from reflection to the faithful `View._makeView` render ABI.** Rendering
  now flows through SwiftUI's real `View._makeView` recursion, dispatched via the View
  witness tables — the unmodified binary's own `ContentView` binds its `_makeView` slot
  to our default (composite) impl, which evaluates `body` and recurses; primitives /
  modifiers / controls override `_makeView` to emit render nodes; environment
  (`.foregroundColor`) propagates via `_ViewInputs`. Mirror is now used only to flatten
  `TupleView`/`ForEach`/`Group` (no Apple variadic `_makeViewList` to reuse). Hello and
  Gallery render + interact identically via this path (`linux/SwiftUIShim`'s
  `MakeView.swift`).
- [x] **Port the bottom layer to Linux/arm64.** A minimal Mach-O loader (`linux/machold`)
  maps the **same unmodified `probe/Hello` binary** on Linux, applies its chained
  fixups, binds its 86 imports to a Linux build of this exact `SwiftUI` module +
  the toolchain `libswiftCore.so` (two textual name-rewrites cover the only
  Darwin↔Linux mangling differences), registers its Swift metadata, and jumps to
  `LC_MAIN`. Reaches our `App.main()` and reflects the tree — all on **Linux/arm64,
  no recompile**.
- [x] **Render the unmodified binary through Flutter on Linux/arm64.** The Linux host
  (`linux/host-swift`) translates the tree to this repo's Swift `Flutter` widgets and
  renders it through the Flutter engine in a GLFW/Wayland window; the `@State`
  interaction loop (count 0→1) drives a live re-render. A framebuffer pixel-sniff
  confirms the engine rasterized exactly our colors. See **[linux/README.md](linux/README.md)**.
- [x] **Run a second, comprehensive probe (`probe/Gallery`) on Linux/arm64.** 127
  imports — `ScrollView`/`HStack`/`ZStack`/`Group`/`Spacer`/`Divider`/`ForEach`,
  `Image`/`Color`/`RoundedRectangle`, `Toggle`/`TextField`/`Slider`, `.frame`/
  `.cornerRadius`/`.foregroundColor`/`.font` — all reconstructed and **rendered** by
  Flutter, with the `@State` controls live and `Increment` bumping the counter on
  click. The ABI lessons (`@frozen` provider layout, `Binding`/`ForEach` sret-return
  vs Swift-6.2.4 register-return, `___chkstk_darwin`) are in
  **[linux/GALLERY-WORKLIST.md](linux/GALLERY-WORKLIST.md)**.
- [x] **Grew the SwiftUI surface via one-probe-per-feature discovery** (`probe/D_*`;
  `MACHOLD_VERBOSE=1` `UNRESOLVED` lines = the per-feature work-list). Added, each
  rendered + verified on Linux: `.frame(maxWidth:)`, `if`/`if let`/`if-else`;
  `.background`/`.overlay` (Color / gradient / shape) + overlay `alignment:`; all
  gradients (`Linear`/`Radial`/`Angular`); all shapes + `.clipShape`/`.cornerRadius`;
  `LazyVStack`/`LazyHStack`/`List`/`LazyVGrid`; `TabView`+`.tabItem` (tap-to-switch);
  `GeometryReader`; `NavigationStack`/`NavigationLink`; `VStack`/`HStack` cross-axis
  **alignment**; `Label`, `ProgressView`, `Stepper`; `Picker`+`.tag` (tap-to-select);
  `AnyView`, `Grid`/`GridRow`, `Menu` (tap-to-expand), `.sheet` (modal + dismiss),
  `.onTapGesture`, `.onChange`, `.navigationTitle`, `.opacity`/`.scaleEffect`/`.shadow`,
  `.disabled`, `.lineLimit`; `@Environment(\.…)` (injected pre-`body`), `@AppStorage`,
  `Form`/`Section`, `.buttonStyle(.borderedProminent)`, and **`.task {}`** — the
  binary's Darwin-compiled async closure runs on Linux's concurrency runtime.
  Sweep 3 (28 more): `.alert` (modal + self-dismissing buttons), `.toolbar`,
  `.contextMenu`, `SecureField`/`TextEditor`/`GroupBox`/`LazyHGrid`, `@SceneStorage`,
  `Text.foregroundStyle`/`.italic`, `Font.system(size:)`, `.offset`/`.rotationEffect`/
  `.blur`/`.fixedSize`/`.ignoresSafeArea`/`.id`, `Shape.fill`, `.onHover`/`.onSubmit`,
  `.animation`/`withAnimation`/`.transition` (snap — no animation system),
  `.tint`/`.multilineTextAlignment`, `.toggleStyle`/`.textFieldStyle`.
  Full table: **[NEXT-FEATURES.md](NEXT-FEATURES.md)**.
- [x] **`ObservableObject`/`@StateObject`/`@ObservedObject`/`@Published` + reactivity.**
  Realizes the binary's ObjC-interop model `class` on Linux **with no ObjC runtime**
  (`objc_msgSend`=0): machold synthesizes the root/metaclass, runs the metadata
  completion, converts the class metadata Darwin→Linux (header-only), populates the
  ObjC ivar-offset globals, and clears the singleton-init flag. `@StateObject`
  persists across re-walks; a `@Published` mutation (button, `.onAppear`, or
  `objectWillChange.send()`) re-renders; `.sink` delivers on subscribe.
- [x] **ObjC tier-2 + AppKit GUI** — a from-scratch `objc_msgSend` (no libobjc/Darling)
  runs unmodified pure-ObjC binaries (messaging, super, categories, `objc_getClass`,
  blocks, ~15 hand-written Foundation classes: NSString/NSArray/NSDictionary/NSSet/
  NSData/NSNumber/NSDate + literals + fast/block enumeration + NSLog/printf). **AppKit
  apps render through the Flutter host**: `NSApplication`/`NSWindow`/`NSView`/`NSTextField`/
  `NSButton` → RNode JSON → the same renderer; `-run` → `swiftui_compat_run`; button
  target/action fires via `swiftui_compat_dispatch` → live UI update (G3 counter). See
  `probe/O0-O12` (console) and `probe/G0-G3` (GUI).
- [x] **`@EnvironmentObject`** — DynamicProperty injection: the walk writes each
  wrapper's `_store` (raw-pointer field write via `@_spi(Reflection) _forEachField`)
  from the environment threaded through `_ViewInputs`; `.environmentObject(_:)` flows
  through a generalized `_EnvironmentKeyWritingModifier` keypath apply.
- [ ] **Remaining — deep mechanisms** (see NEXT-FEATURES.md): a core-Flutter
  `LayoutBuilder` (→ true `GeometryReader` geometry + `RadialGradient` radii).

### Build & run (milestone 2c)

The shim is an SPM package, `SwiftUIShim/`, with two targets:
- `Sources/SwiftUI/` — the reconstructed `SwiftUI` module. Imports **only Foundation**
  (importing AppKit/Flutter pulls Apple's `SwiftUICore`, whose
  `@_originallyDefinedIn("SwiftUI")` symbols collide with ours → compiler crash).
  Library-evolution; install_name = Apple's SwiftUI path.
- `Sources/FlutterHost/` — imports Flutter/AppKit, translates the tree → Flutter
  widgets, boots the engine + window. Reached from `SwiftUI` via the C symbol
  `swiftui_compat_run` (tree passed as JSON), so no Swift import crosses the line.

```bash
cd macos-compat
./build.sh                                       # SPM build + assemble framework + symbol check
DYLD_FRAMEWORK_PATH="$PWD/build" ./probe/Hello   # unmodified binary renders via Flutter
```

### The hard part: `@frozen` layout fidelity

`@frozen` SwiftUI types are passed by value and the app **inlines** their copy/retain/release using Apple's exact layout — so our reconstructions must match byte-for-byte (resilient types like `Button`/`WindowGroup` are safe via the value-witness table). Lessons that took several crashes to find:
- Mark every Apple-`@frozen` type `@frozen` (else our resilient calling convention mismatches the app's by-value ABI).
- Match exact **sizes** (`Text`=32 not 16, `LocalizedStringKey`=32, `_VStackLayout`=24); measure with `MemoryLayout<T>.size` linking the real SwiftUI.
- Match the **value representation**: Apple stores `Text(localizedKey)` as `.anyTextStorage(class)`, never `.verbatim(String)` — using verbatim made the app's inlined enum-destroy misread the tag and `release()` the inline characters.
- Reproduce **generic constraints**: `_VariadicView.Tree<Root, Content> where Root: _VariadicView_Root` — the constraint adds a witness-table pointer to the metadata's generic args, which is where the app reads `VStack.content`'s field offset. Omitting it shifts the offset → reads child views from garbage.
