# FlutterSwift

The Flutter framework, ported to Swift. No Dart VM: widgets, rendering, painting,
gestures and semantics are Swift, driven directly by the Flutter engine's C core
through a C++ bridge.

This package was extracted from the [Starling desktop][starling], which is its
largest consumer but not its only intended one. It carries the framework and the
thin platform bindings needed to host an engine — nothing desktop-specific.

[starling]: https://github.com/starling-build/starling

## What is here

| Target | |
|---|---|
| `Flutter` | the framework port — Widgets, Rendering, Painting, Gestures, Animation, Semantics, plus the FluentUI and MacosUI widget sets |
| `FlutterSwiftBridge` | Swift side of the C++ bridge to the engine's `dart:ui` implementation |
| `FlutterSwiftBridgeCxx` | the vendored bridge headers it compiles against |
| `SwiftRuntime` | the delegate the engine calls instead of a Dart isolate |
| `CupertinoIcons` | 1,322 SF-Symbols-style icons and their font |
| `FlutterEmbedderBridge` | clang module over the engine's `embedder.h` |
| `FlutterDRMBridge` | clang module over the DRM/KMS embedder (`fl_drm_view.h`) |
| `DmaBufBridge` | GBM + `SCM_RIGHTS` + EGL dma-buf import helpers |
| `FlutterMacOSBridge` | macOS embedder bindings (unverified — see *Status*) |

`FlutterShared` is a dynamic product bundling the whole stack into one
`libFlutterShared.so`, so a fleet of apps ships one copy rather than a static
duplicate each.

## Building

The engine is a **link-time dependency only** — its headers are vendored under
each target's `include/engine/`, so nothing here needs an engine checkout to
compile. Linking does. `Package.swift` looks for engine binaries in this order:

1. `$FLUTTER_SWIFT_ENGINE_OUT` — explicit, always wins
2. `engine/lib/` inside this package — a distribution bundle (see below)
3. a sibling engine checkout — an `engine` symlink beside this package, or a
   sibling clone of [starling-engine][engine]

[engine]: https://github.com/starling-build/starling-engine

```bash
swift build -c release
tools/run-tests.sh          # not `swift test` — see below
```

`tools/run-tests.sh` exists because a plain `swift test` cannot work on Ubuntu
26.04: swift-testing ships as a textual `.swiftinterface`, which gets recompiled
in the importing target's C++-interop context and hits the `<cmath>` clash
described below. The script prebuilds those modules outside interop and passes
the compat flags to every frontend invocation. On any other platform it is a
passthrough.

### Ubuntu 26.04

The 6.2.4 toolchain is an ubuntu24.04 build, and 26.04 pairs glibc 2.43 with
libstdc++ 15. Under C++ interop that makes Foundation's `_CStdlib.h` pull
`<cmath>` textually *and* from the prebuilt `std` module, so every target dies
with `cmath: redefinition of 'acos'`. `Package.swift` works around it with
`-D_GLIBCXX_MATH_H` plus a force-included glibc `math.h`, applied only where the
bad pairing is detected (libstdc++ 15 or newer). Override the probe with
`FLUTTER_SWIFT_GLIBC_MATH_COMPAT=0` or `=1`.

These are the package's only remaining unsafe flags outside `-L`/`-rpath`, and
they disappear on their own once swift.org ships a native 26.04 toolchain.

**Consumers on 26.04 need the same two flags on their own C++-interop targets.**
SwiftPM does not propagate `swiftSettings` from a dependency, so this package
applying them internally does nothing for a dependent: your target pulls
Foundation's C shim in *your* compilation context and hits the clash there. This
is easy to miss, because a machine with a locally patched
`/usr/include/c++/15/math.h` never sees it — that artifact produced one wrong
conclusion here already.

## Consuming it

`tools/make-bundle.sh` produces a self-contained tree carrying the framework and
the engine binaries together:

    flutter-swift-linux-aarch64/
      Package.swift Sources/ Tests/ tools/ LICENSE
      engine/lib/     libflutter_engine.so, libflutter_linux_drm.so
      engine/share/   icudtl.dat, flutter_assets/

Unpack it and depend on it by path:

```swift
dependencies: [.package(path: "/opt/flutter-swift-linux-aarch64")],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            .product(name: "Flutter", package: "flutter-swift-linux-aarch64"),
            // The dart:ui types — Offset, Size, Rect, Paint, Canvas. A separate
            // product; Flutter does not re-export them.
            .product(name: "FlutterSwiftBridge", package: "flutter-swift-linux-aarch64"),
        ],
        swiftSettings: [
            // Required — C++ interop is not inherited from the dependency.
            .interoperabilityMode(.Cxx),
            // Required on Ubuntu 26.04, harmless elsewhere; see below.
            .unsafeFlags(["-Xcc", "-D_GLIBCXX_MATH_H",
                          "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]),
        ]
    ),
]
```

**A path dependency, not `.package(url:from:)`, and that is inherent.** SwiftPM
cannot carry a native *library* as a `binaryTarget` on Linux — XCFramework is
Apple-only and Linux artifactbundles hold executables — and pointing at the
bundled engine needs `-L`/`-rpath`, which SwiftPM classes as unsafe and rejects
for version-resolved dependencies while permitting for path dependencies. So the
bundle sidesteps that restriction rather than satisfying it. This is a
download-and-point SDK, the same shape as the Flutter SDK itself.

Two consequences: there is no `swift package update`, and the engine path is
baked into your binary's RUNPATH, so moving an unpacked bundle means rebuilding.

A static-engine route that would allow true versioned consumption has been
prototyped and works (`tools/make-static-engine.sh`); it was shelved because it
needs 13 `-dev` packages on every consumer and a ~109 MB artifact per platform
per version. The write-up lives in the Starling repo at
`sdk/plans/standalone-sdk.md`.

## Vendored headers

`tools/sync-vendored-headers.sh` copies the engine's public headers (36 of them)
and `<swift/bridging>` into the package. They describe the ABI of the
`libflutter_engine` being linked, so they and the engine binary must ship
together — `make-bundle.sh` refuses to build if `--check` reports drift.

```bash
tools/sync-vendored-headers.sh --check     # report drift
tools/sync-vendored-headers.sh             # re-sync
```

## Status

Linux is the tested platform. `Package.swift` has a macOS branch and a
`FlutterMacOSBridge` target, but nothing here verifies them — they need a machine
and CI. Two environment knobs read by `Sources/Flutter/Platform/` still carry
Starling names (`STARLING_AGENT_ENDPOINT`, `STARLING_APP_DRM_DEVICE`); both are
inert when unset.

## License

BSD-3-Clause, inherited from Flutter. See `LICENSE`.
