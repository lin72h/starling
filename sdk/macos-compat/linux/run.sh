#!/bin/bash
# Run the UNMODIFIED macOS Mach-O probe on Linux/arm64 through machold.
#   MACHOLD_VERBOSE=1 ./run.sh   loader tracing (segment maps, binds, fixups)
#   MACHOLD_TAP=1 ./run.sh       (L1 stub only) simulate one button tap
# With the L2 Flutter host this opens a Wayland window; click "Increment" to bump
# the counter live (tap → the unmodified app's SwiftUI action → @State → re-render).
set -euo pipefail
cd "$(dirname "$0")"

TOOLCHAIN="$HOME/.local/share/swiftly/toolchains/6.2.4"
ENGINE_OUT="$(cd ../../../engine/src/out/host_debug && pwd)"
GLFW_LIB="$(cd ../../.deps/lib && pwd)"

export COMPAT_ENGINE_OUT="$ENGINE_OUT"
export LD_LIBRARY_PATH="$PWD/build:$TOOLCHAIN/usr/lib/swift/linux:$ENGINE_OUT:$GLFW_LIB:${LD_LIBRARY_PATH:-}"

# Render on the GNOME Wayland session, exactly like BlueScreenApp: WAYLAND_DISPLAY
# set + DISPLAY EMPTY (not just unset). With DISPLAY="" GLFW's X11 connect fails and
# auto-detect falls through to Wayland; merely leaving DISPLAY unset makes GLFW grab
# X11 :0 (an X server that may not be the desktop you see). Override as needed.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export DISPLAY="${DISPLAY-}"   # default to empty string (note: ${VAR-} not ${VAR:-})

BIN="${1:-../probe/Hello}"
exec build/machold "$BIN" "${@:2}"
