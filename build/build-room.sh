#!/bin/bash
# Builds libstarling_room.so — the 3D desktop's room renderer, a C shim
# over Filament — into the shared scratch, where stage.sh picks it up.
#
#   build/build-room.sh [--test]     --test also builds the roomtest tool
#
# Filament is built from source with EGL and GLES 3 on (the prebuilt
# release is GLX-only and cannot share the engine's context); see
# docs/plans/desktop-3d.md. STARLING_FILAMENT points at its install
# prefix, default ~/dev/filament/gles.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FIL="${STARLING_FILAMENT:-$HOME/dev/filament/gles}"
OUT="${STARLING_SCRATCH:-$REPO/.build-shared}"
SRC="$REPO/shell/Sources/StarlingRoom"
# The system clang, not the Swift toolchain's (too old for this libc++).
CXX="${CXX:-/usr/bin/clang++}"
mkdir -p "$OUT"

[ -f "$FIL/lib/x86_64/libfilament.a" ] || {
    echo "error: no Filament at $FIL (set STARLING_FILAMENT)" >&2; exit 1; }

# The pane materials: compiled by Filament's matc for the GLES backend
# into byte arrays the shim includes.
MATC="$FIL/bin/matc"
mkdir -p "$OUT/room-mat"
for m in screen frame glow label; do
    "$MATC" -a opengl -p mobile -f header -o "$OUT/room-mat/$m.inc" "$SRC/materials/$m.mat"
done

LIBS="-lgltfio_core -luberarchive -lktxreader -limage -lfilament -lbackend \
      -lfilabridge -lfilaflat -lutils -lgeometry -libl -labseil -lzstd \
      -ldracodec -lmeshoptimizer -lstb -lmikktspace -lbasis_transcoder -lbluegl -luberzlib"
# -fno-rtti/-fno-exceptions to match Filament: with RTTI on, a class derived
# from one of its platforms needs typeinfo Filament never emitted.
"$CXX" -std=c++20 -stdlib=libc++ -O2 -fPIC -fvisibility=hidden -fno-rtti -fno-exceptions -shared \
    -o "$OUT/libstarling_room.so" "$SRC/starling_room.cpp" \
    -I"$FIL/include" -I"$OUT/room-mat" -L"$FIL/lib/x86_64" \
    -Wl,--start-group $LIBS -Wl,--end-group \
    -lGLESv2 -lEGL -lpthread -ldl \
    -Wl,--exclude-libs,ALL -Wl,-Bsymbolic -Wl,-soname,libstarling_room.so
echo "built $OUT/libstarling_room.so ($(du -h "$OUT/libstarling_room.so" | cut -f1))"

if [ "${1:-}" = "--test" ]; then
    "$CXX" -std=c++20 -O2 -o "$OUT/roomtest" "$SRC/roomtest.cpp" \
        -I"$SRC" -L"$OUT" -lstarling_room -lGLESv2 -lEGL -lgbm \
        -Wl,-rpath,"$OUT"
    echo "built $OUT/roomtest"
fi
