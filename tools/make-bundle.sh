#!/usr/bin/env bash
# Assemble a self-contained FlutterSwift distribution: the framework source plus
# the engine binaries it links against, in one tree.
#
#   tools/make-bundle.sh [--debug|--release] [outdir]
#
# Produces <outdir>/flutter-swift-<platform>-<arch>/ and a .tar.gz of it. A
# consumer unpacks that and depends on it by path:
#
#   .package(path: "/opt/flutter-swift")
#
# and needs no engine checkout, no ../engine symlink, and no configuration —
# Package.swift probes for engine/lib inside the bundle.
#
# WHY A PATH DEPENDENCY AND NOT A VERSIONED ONE. SwiftPM cannot carry a native
# *library* as a binaryTarget on Linux (XCFramework is Apple-only; artifactbundles
# hold executables), and locating the bundled engine needs -L/-rpath, which are
# .unsafeFlags — rejected for dependencies resolved by URL+version, allowed for a
# path dependency. Bundling therefore sidesteps that restriction rather than
# satisfying it. The cost is no `swift package update`: this is a download-and-point
# SDK, the same shape as the Flutter SDK itself.
set -euo pipefail

SDK="$(cd "$(dirname "$0")/.." && pwd)"

# This package is standalone, so the engine checkout is not at a fixed offset any
# more. Same candidates as tools/sync-vendored-headers.sh: an `engine` symlink
# beside the package, or a sibling clone of starling-engine.
ENGINE_ROOT="${ENGINE_ROOT:-}"
if [ -z "$ENGINE_ROOT" ]; then
    for candidate in "$SDK/../engine" "$SDK/../starling-engine/engine"; do
        if [ -d "$candidate/src" ]; then ENGINE_ROOT="$candidate"; break; fi
    done
fi

CONFIG=release
case "${1:-}" in
    --debug)   CONFIG=debug;   shift ;;
    --release) CONFIG=release; shift ;;
esac
OUT="${1:-/tmp/flutter-swift-bundle}"

case "$(uname -s)" in
    Linux)  PLATFORM=linux  ;;
    Darwin) PLATFORM=macos  ;;
    *) echo "error: unsupported platform $(uname -s)" >&2; exit 1 ;;
esac
ARCH="$(uname -m)"
NAME="flutter-swift-$PLATFORM-$ARCH"
DEST="$OUT/$NAME"

# The engine build to take binaries from. host_debug is what the desktop links
# against day to day; host_release is what a consumer should ship.
E="${FLUTTER_SWIFT_ENGINE_OUT:-$ENGINE_ROOT/src/out/host_$CONFIG}"
if [ ! -f "$E/libflutter_engine.so" ] && [ ! -f "$E/libswift_bridge.dylib" ]; then
    echo "error: no engine binaries in $E" >&2
    echo "       build the engine first (see docs/BUILDING.md), or set" >&2
    echo "       FLUTTER_SWIFT_ENGINE_OUT to a directory that has them" >&2
    exit 1
fi

# Refuse to ship headers that have drifted from the engine we are bundling: the
# vendored bridge headers describe that binary's ABI.
if ! "$SDK/tools/sync-vendored-headers.sh" --check >/dev/null 2>&1; then
    echo "error: vendored headers have drifted from the engine tree" >&2
    echo "       run tools/sync-vendored-headers.sh and rebuild before bundling" >&2
    exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST/engine/lib" "$DEST/engine/share"

# --- framework source -------------------------------------------------------
# Sources/, Tests/ and tools/ go as-is. .build is deliberately excluded — a
# consumer's toolchain differs from ours.
# README.md is not copied: the bundle gets its own, written below.
for item in Package.swift Sources Tests tools LICENSE; do
    [ -e "$SDK/$item" ] || { echo "error: missing $item" >&2; exit 1; }
    cp -r "$SDK/$item" "$DEST/"
done

# --- engine binaries --------------------------------------------------------
if [ "$PLATFORM" = linux ]; then
    install -m644 "$E/libflutter_engine.so" "$DEST/engine/lib/"
    # The DRM embedder is what FlutterDRMBridge binds; optional for consumers
    # that only use the framework, so do not fail without it.
    [ -f "$E/libflutter_linux_drm.so" ] && install -m644 "$E/libflutter_linux_drm.so" "$DEST/engine/lib/"
    # The GTK embedder is what FlutterGTK binds (desktop-session host); same
    # deal — optional.
    [ -f "$E/libflutter_linux_gtk.so" ] && install -m644 "$E/libflutter_linux_gtk.so" "$DEST/engine/lib/"
else
    cp -R "$E/FlutterMacOS.framework" "$DEST/engine/lib/"
    install -m644 "$E/libswift_bridge.dylib" "$DEST/engine/lib/"
fi

# --- runtime data -----------------------------------------------------------
# icudtl.dat and flutter_assets are needed at *run* time, not link time, but a
# consumer with neither cannot start an engine, so they travel with the bundle.
[ -f "$E/icudtl.dat" ] && install -m644 "$E/icudtl.dat" "$DEST/engine/share/"

# flutter_assets: the vendored copy in Resources/ normally, overridable, with the
# desktop's copy as a fallback for anyone building from a starling checkout.
ASSETS="${FLUTTER_SWIFT_ASSETS:-}"
if [ -z "$ASSETS" ]; then
    for candidate in "$SDK/Resources/flutter_assets" "$SDK/../starling/build/flutter_assets"; do
        if [ -d "$candidate" ]; then ASSETS="$candidate"; break; fi
    done
fi
if [ -n "$ASSETS" ]; then
    cp -r "$ASSETS" "$DEST/engine/share/"
else
    echo "warning: no flutter_assets found; the bundle cannot start an engine" >&2
    echo "         set FLUTTER_SWIFT_ASSETS to an asset bundle" >&2
fi

cat > "$DEST/README.md" <<EOF
# FlutterSwift — $PLATFORM/$ARCH bundle ($CONFIG engine)

The Flutter framework ported to Swift, with the engine binaries it links against.
No engine checkout or toolchain configuration needed.

## Use it

\`\`\`swift
dependencies: [.package(path: "/opt/$NAME")],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            .product(name: "Flutter", package: "$NAME"),
            // The dart:ui types — Offset, Size, Rect, Paint, Canvas. Separate
            // from Flutter, which does not re-export them.
            .product(name: "FlutterSwiftBridge", package: "$NAME"),
        ],
        swiftSettings: [
            // Required. The framework is C++-interop; this is not inherited from
            // the dependency, and without it you get:
            //   module 'FlutterSwiftBridgeCxx' requires feature 'cplusplus'
            .interoperabilityMode(.Cxx),
            // Required on Ubuntu 26.04 (glibc 2.43 + libstdc++ 15), and harmless
            // elsewhere. SwiftPM does not propagate swiftSettings from a
            // dependency, so this package applying it internally does nothing for
            // you: your own C++-interop targets pull Foundation's C shim in their
            // own context and hit "cmath: redefinition of 'acos'" without it.
            // Drop it once swift.org ships a native 26.04 toolchain.
            .unsafeFlags(["-Xcc", "-D_GLIBCXX_MATH_H",
                          "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]),
        ]
    ),
]
\`\`\`

\`\`\`swift
import Flutter
import FlutterSwiftBridge

print(Offset(3, 4).distance)   // 5.0
\`\`\`

**You do not add the engine library to your package, and you do not set a library
path.** This package's own linker settings put \`-L\` on the link line and bake an
rpath into your executable, so \`swift build\` and \`swift run\` find
\`libflutter_engine\` with no configuration.

It is a path dependency rather than \`.package(url:from:)\` because locating the
bundled engine needs linker flags SwiftPM classes as unsafe, which it permits for
path dependencies only. Consequence: **moving this directory after building means
rebuilding**, as the engine location is in your binary's rpath.

## Ship your app

The rpath above points here, which is fine on your machine and useless on someone
else's. SwiftPM also puts \`\$ORIGIN\` in the rpath, so deployment is a copy:

\`\`\`bash
cp .build/release/App                 dist/
cp /opt/$NAME/engine/lib/*.so         dist/     # sits beside the binary
cp -r /opt/$NAME/engine/share         dist/     # icudtl.dat + flutter_assets
\`\`\`

\`dist/App\` then runs anywhere with no \`LD_LIBRARY_PATH\`. Skip the library copy and
you get \`libflutter_engine.so: cannot open shared object file\` at startup, not at
build time. Point your embedder at \`share/icudtl.dat\` and \`share/flutter_assets\`.

This bundle is built for **$PLATFORM/$ARCH**; other targets need their own.

## Layout

    Package.swift Sources/ Tests/   the framework
    engine/lib/                     engine binaries (linked, and loaded at runtime)
    engine/share/icudtl.dat         ICU data, needed to start an engine
    engine/share/flutter_assets/    default asset bundle

## Overrides

\`FLUTTER_SWIFT_ENGINE_OUT\` points at a different engine build.
\`FLUTTER_SWIFT_GLIBC_MATH_COMPAT=0/1\` forces the Ubuntu 26.04 <cmath> workaround
off or on; it is applied automatically when libstdc++ 15 or newer is present.
EOF

( cd "$OUT" && tar czf "$NAME.tar.gz" "$NAME" )

echo "bundle:  $DEST"
echo "tarball: $OUT/$NAME.tar.gz ($(du -h "$OUT/$NAME.tar.gz" | cut -f1))"
echo "engine:  $E ($CONFIG)"
