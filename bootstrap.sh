#!/usr/bin/env bash
# Prepare a checkout for building:
#   1. the `engine` symlink at the repo root -> a starling-engine checkout's
#      engine/ directory. Everything here reaches the engine through this link:
#      bridge headers, libflutter_engine.so / libflutter_linux_drm.so, icudtl.dat.
#   2. the `sdk` symlink at the repo root -> a flutter-swift checkout. The
#      Flutter->Swift framework lives in its own repo now; the shell and every
#      app depend on it as `path: "../../sdk"`, so the link is what makes those
#      manifests resolve without hardcoding a layout.
#   3. the Swift toolchain's libxml2 compat symlink, needed on Ubuntu 26.04.
#
#   ./bootstrap.sh [path-to-starling-engine-checkout] [path-to-flutter-swift-checkout]
#
# Defaults: $STARLING_ENGINE else ../starling-engine, and $STARLING_SDK else
# ../flutter-swift.
set -euo pipefail
cd "$(dirname "$0")"
ENG="${1:-${STARLING_ENGINE:-../starling-engine}}"
[ -d "$ENG/engine/src/flutter" ] || {
    echo "error: no engine checkout at '$ENG' (expected <path>/engine/src/flutter)" >&2
    exit 1
}
ln -sfn "$ENG/engine" engine
echo "engine -> $(readlink engine)"

SDK="${2:-${STARLING_SDK:-../flutter-swift}}"
[ -f "$SDK/Package.swift" ] || {
    echo "error: no flutter-swift checkout at '$SDK' (expected <path>/Package.swift)" >&2
    echo "       git clone https://github.com/starling-build/flutter-swift" >&2
    exit 1
}
ln -sfn "$SDK" sdk
echo "sdk -> $(readlink sdk)"

# Ubuntu 26.04 ships libxml2.so.16 only, but the Swift 6.2.4 toolchain is an
# ubuntu24.04 build and links libxml2.so.2 — without it swift-build cannot even
# start. libFoundationXML.so's RUNPATH is $ORIGIN, so a symlink beside it fixes
# it with nothing system-wide changed. No-op on releases that still ship .so.2,
# and once the toolchain has a native 26.04 build. See docs/BUILDING.md.
SWIFT_LIB="${STARLING_SWIFT_TOOLCHAIN:-$HOME/.local/share/swiftly/toolchains/6.2.4}/usr/lib/swift/linux"
SYS_LIB=/usr/lib/x86_64-linux-gnu
if [ -d "$SWIFT_LIB" ] && [ ! -e "$SWIFT_LIB/libxml2.so.2" ] &&
   [ ! -e "$SYS_LIB/libxml2.so.2" ] && [ -e "$SYS_LIB/libxml2.so.16" ]; then
    ln -s "$SYS_LIB/libxml2.so.16" "$SWIFT_LIB/libxml2.so.2"
    echo "libxml2.so.2 -> libxml2.so.16   (in $SWIFT_LIB)"
fi
