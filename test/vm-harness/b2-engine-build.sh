#!/usr/bin/env bash
# Guest step 2: generate GN files and build the two engine libraries,
# in both host_debug and host_release.
set -euxo pipefail
export PATH="$HOME/depot_tools:$PATH"
cd "$HOME/dev/starling-build/starling-engine/engine/src"

flutter/tools/gn --runtime-mode=debug   --no-lto --no-backtrace --no-rbe
flutter/tools/gn --runtime-mode=release --no-lto --no-backtrace --no-rbe

time ninja -C out/host_debug   libflutter_engine.so libflutter_linux_drm.so
time ninja -C out/host_release libflutter_engine.so libflutter_linux_drm.so

ls -la out/host_debug/libflutter_engine.so out/host_debug/libflutter_linux_drm.so \
       out/host_release/libflutter_engine.so out/host_release/libflutter_linux_drm.so
ls -la out/host_debug/icudtl.dat out/host_release/icudtl.dat || echo "NO ICUDTL"
