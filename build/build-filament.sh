#!/bin/bash
# Builds Filament the way the 3D desktop's room renderer needs it, and
# installs it where build/build-room.sh looks (STARLING_FILAMENT, default
# ~/dev/filament/gles). One-off; takes ~20 minutes on 16 cores.
#
#   build/build-filament.sh [<src dir>]      default ~/dev/filament/src
#
# Why not the prebuilt release: its Linux OpenGL backend is GLX-only and
# desktop-GL-only, and a context that can share the engine's textures has
# to be an EGL context on the engine's GBM display. FILAMENT_SUPPORTS_EGL_ON_LINUX
# builds the GLES flavour of the backend over EGL instead (gl_headers.h),
# which is exactly the engine's own API.
#
# Do NOT add FILAMENT_USE_EXTERNAL_GLES3: despite its name it EXCLUDES the
# whole OpenGL backend from the build (filament/backend/CMakeLists.txt),
# and the link then fails on every OpenGLDriver symbol.
#
# Needs: clang, libc++-dev, libc++abi-dev, cmake, ninja, libegl-dev,
# libgles-dev (apt). Filament only builds with clang + libc++.
set -euo pipefail
TAG=v1.77.0
SRC="${1:-$HOME/dev/filament/src}"
PREFIX="${STARLING_FILAMENT:-$HOME/dev/filament/gles}"
NINJA="${NINJA:-$(command -v ninja || echo "$HOME/depot_tools/ninja")}"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 --branch "$TAG" https://github.com/google/filament.git "$SRC"
fi

# The one patch: EGL-on-Linux runs the GLES backend, which asks for the
# MOBILE shader model at runtime, but the tree compiles its materials
# (skybox, post-processing, the glTF ubershaders) for the DESKTOP model
# unless it thinks it is building for a phone. Without this every
# material fails to load and the room renders nothing.
python3 - "$SRC/CMakeLists.txt" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
marker = "if (FILAMENT_SUPPORTS_EGL_ON_LINUX)\n    set(MATC_TARGET mobile)\nendif()\n"
if marker not in s:
    old = "if (IS_MOBILE_TARGET)\n    set(MATC_TARGET mobile)\nelse()\n    set(MATC_TARGET desktop)\nendif()\n"
    assert old in s, "MATC_TARGET block not found; Filament moved it"
    open(p, "w").write(s.replace(old, old + marker, 1))
    print("patched MATC_TARGET for EGL on Linux")
PY

mkdir -p "$SRC/out/gles"
cd "$SRC/out/gles"
CC=/usr/bin/clang CXX=/usr/bin/clang++ CXXFLAGS=-stdlib=libc++ cmake -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DFILAMENT_SUPPORTS_EGL_ON_LINUX=ON \
    -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_SKIP_SDL2=ON \
    -DFILAMENT_SUPPORTS_VULKAN=OFF -DFILAMENT_ENABLE_MATDBG=OFF \
    -DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=ON \
    ../..
# Two of Filament's own test programs do not link in this configuration
# (they never add -lGLESv2); the libraries and tools all build. Keep going
# past them and install what was built.
"$NINJA" -k 0 all || true
"$NINJA" install > /dev/null
echo "installed to $PREFIX:"
ls "$PREFIX/lib/x86_64" | wc -l | xargs echo "  static libs:"
nm -C "$PREFIX/lib/x86_64/libbackend.a" | grep -c "OpenGLDriver::" | xargs echo "  OpenGLDriver symbols (0 = wrong flags):"
