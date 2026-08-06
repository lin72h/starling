# Linux/arm64 port — running the unmodified Mach-O on Linux

This is the "bottom layer" the macOS milestones deferred (see [../SUMMARY.md](../SUMMARY.md)):
the loader + runtime packaging needed to run the **same unmodified `probe/Hello`
Mach-O binary** on Linux/arm64 instead of macOS. No recompile of the binary; the
Swift sources of the reconstructed `SwiftUI` module are **byte-for-byte the same**
as the macOS build.

## Why this is tractable

Both sides are arm64, so there is **no CPU emulation**. The Swift standard library
and runtime are the *same source* on Darwin and Linux, so a Darwin-compiled binary's
calls into `libswiftCore` (metadata instantiation, `swift_allocObject`, witness
tables, `@State`'s reference-backed storage…) bind straight to the toolchain's
Linux `libswiftCore.so` and *just work* over AAPCS64 + the platform-independent
Swift calling convention. The GUI frameworks — the part nobody can emulate — are
already replaced by our Flutter-backed `SwiftUI` reconstruction. What remained was
purely **loading + symbol binding**, and the binary's import surface is tiny: 86
binds (1 libc, 57 SwiftUI, 27 runtime, 1 CGFloat metadata) + 13 rebases.

## What `machold` does (milestone L1)

`loader/machold.c` (~340 lines, C) is a minimal Mach-O runner:

1. **Maps** the four segments (`__TEXT`/`__DATA_CONST`/`__DATA`/`__LINKEDIT`) into a
   reserved contiguous span and computes the slide. (4 KB Linux pages map the
   16 KB-aligned Mach-O segments fine.)
2. **Applies `LC_DYLD_CHAINED_FIXUPS`** (`DYLD_CHAINED_PTR_64_OFFSET`): walks the
   per-page chains, doing rebases (`*loc = base + target`) and binds.
3. **Resolves binds by name.** dyld binds by symbol *name*, so each import is
   `dlsym`'d after stripping the Mach-O leading `_`. The only Darwin↔Linux name
   differences are two module-qualified types that are ABI-identical but mangle
   differently, handled by a textual rewrite in the resolver:
   - `12CoreGraphics7CGFloatV` → `10Foundation7CGFloatV` (CGFloat lives in
     CoreGraphics on Darwin, Foundation on Linux)
   - `So8NSBundleC` → `10Foundation6BundleC` (ObjC `NSBundle` vs `Foundation.Bundle`)

   This is why the Swift sources need **zero** `#if os(...)`: the platform delta
   lives entirely in the loader.
4. **Registers the image's Swift metadata** (`__swift5_types`, `__swift5_proto`)
   with `swift_registerTypeMetadataRecords` / `swift_registerProtocolConformances`,
   so the runtime can find the binary's own `HelloApp`/`ContentView` types (the
   Linux runtime's normal ELF image scan never sees our hand-mapped Mach-O).
5. **Jumps to `LC_MAIN`** as `main(argc, argv, envp, apple)`. The synthesized Swift
   `@main` calls the App-protocol-extension `main()` — which is an *import*, i.e.
   **our** `App.main()` in `libSwiftUI.so`.

The host the loader dlopens (`build/libcompat_host.so`) is built in one of two modes:
- **L2 (default)** — `host-swift/`, an SPM package building `libCompatHost.so`: it
  parses the JSON tree, translates it to this repo's Swift `Flutter` widgets, and
  renders through the Flutter engine in a GLFW/Wayland window (the Linux counterpart
  of the macOS FlutterHost's NSWindow path; input → `GestureDetector` → the app's
  SwiftUI action). Taps route back into the unmodified binary via
  `swiftui_compat_dispatch`.
- **L1** (`./build.sh --stub`) — `host/host_stub.c`, which just prints the JSON.

## Build & run

```bash
cd macos-compat/linux
./build.sh                  # L2: Swift Flutter host + libSwiftUI.so + machold
./run.sh                    # run UNMODIFIED ../probe/Hello → renders in a Wayland window
MACHOLD_AUTOTAP=1 ./run.sh   # synthesise a tap once the first frame is up (count 0→1)
MACHOLD_PIXPROOF=1 ./run.sh  # glReadPixels proof: report the rendered colors
MACHOLD_VERBOSE=1 ./run.sh   # loader tracing: segment maps, every bind, fixup count
./build.sh --stub && ./run.sh    # L1: print the JSON tree instead of rendering
MACHOLD_TAP=1 ./run.sh           # (L1 stub) simulate a tap → @State round-trip in text
```

## Status — L1 + L2 demonstrated

The unmodified macOS arm64 Mach-O loads on Linux/arm64, reaches our `App.main()`,
reflects its own SwiftUI view tree, and **renders through the Flutter engine in a
Wayland window**, with the `@State` interaction loop running end to end:

```
[CompatHost] enter; root=padding(16.0, column([text("Count: 0"), button(0, text("Increment"))]))
[CompatHost] engine running → present #1
[CompatHost] pixproof (640×420, center column): #F5F5F7×34 #0A84FF×3 #1D1D1F×2   # bg + blue button + dark text
… tap …
>>> button 0 tapped → re-walked tree: … "Count: 1" …        # @State 0 → 1
[CompatHost] update → present #2
```

The pixel-proof samples the rendered framebuffer and finds **exactly** the colors
`toWidget` assigns (`#F5F5F7` background, `#0A84FF` button, `#1D1D1F` text) — objective
evidence the engine rasterized the unmodified binary's tree (no screenshot tool on
this box). All 86 binds resolve, 99 fixups apply, stable across ASLR slides.

- [x] L1 — Mach-O loader: map + fixups + bind + metadata registration → `App.main()`
      → reflect tree → `@State` interaction, all on Linux/arm64 (no recompile).
- [x] L2 — `swiftui_compat_run/_update/_dispatch` wired to this repo's Linux Flutter
      engine (GLFW); the tree renders to real pixels and a **real mouse click** on the
      rendered button increments the counter live (confirmed on the desktop).
- [ ] DRM path; grow the widget/runtime surface to larger binaries (more imports, ObjC, …).

### Two gotchas worth knowing

- **Display backend.** This box's GLFW can't init its Wayland backend (a runtime lib
  is missing), so it falls back to **X11 on `:0`** — which is the session Xwayland, i.e.
  the visible GNOME desktop, so the window does appear. `run.sh` sets `DISPLAY=` empty +
  `WAYLAND_DISPLAY=wayland-0`; `COMPAT_GLFW_PLATFORM=
  wayland|x11|auto` overrides, falling back to auto if the forced backend won't init.
- **Tap threading.** A real tap's `GestureDetector.onTap` runs on the engine's UI
  thread, not the main/platform thread. Calling `setState` there (via
  `MainActor.assumeIsolated`) correctly traps (SIGTRAP). The fix: `swiftui_compat_update`
  only **enqueues** the new tree; the main event loop drains it and calls `apply()` at a
  safe point — the same point the synthetic-tap path already used.
