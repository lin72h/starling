#!/usr/bin/env bash
# wechat-run.sh — launch the official WeChat Linux client (X11-only Qt app)
# on the Starling desktop through rootful Xwayland.
#
# The desktop's Wayland compositor has no X window manager, so Xwayland runs
# ROOTFUL: the whole X screen is one ordinary xdg-toplevel that the shell
# manages like any Wayland client. -hidpi makes Xwayland allocate
# buffer_scale-2 buffers on our scale-2 output, so X pixels map 1:1 to panel
# pixels (crisp text) and the shell's pointer mapping lines up exactly;
# QT_SCALE_FACTOR then makes WeChat draw its UI at 2x inside that screen.
# "-terminate 5" reaps the X server 5s after its last client exits — the
# delay also covers the gap between the readiness probe disconnecting and
# WeChat connecting (a bare -terminate would exit right there).
#
# Environment (set by the shell, mirroring app-run.sh):
#   STARLING_WAYLAND     compositor socket name        (default wayland-0)
#   STARLING_XDG_DIR     XDG_RUNTIME_DIR of the socket (default /tmp/xdg-starling-<uid>)
#   STARLING_APP_SCALE   shell DPI                     (default 2.0)
set -eu

XDG_DIR="${STARLING_XDG_DIR:-/tmp/xdg-starling-$(id -u)}"
WL_SOCKET="${STARLING_WAYLAND:-wayland-0}"
XDISPLAY="${STARLING_WECHAT_DISPLAY:-:9}"
SCALE="${STARLING_APP_SCALE:-2.0}"
WECHAT_BIN="${STARLING_WECHAT_BIN:-/opt/wechat/wechat}"

[ -x "$WECHAT_BIN" ] || { echo "wechat-run: $WECHAT_BIN not installed (apt install wechat)" >&2; exit 1; }
command -v Xwayland >/dev/null || { echo "wechat-run: Xwayland not installed" >&2; exit 1; }
command -v xdpyinfo >/dev/null || { echo "wechat-run: xdpyinfo (x11-utils) not installed" >&2; exit 1; }

# The shell runs as root (DRM master); apps run as the login user.
LOGIN_USER="${SUDO_USER:-$(stat -c %U "$XDG_DIR" 2>/dev/null || true)}"
[ -n "${LOGIN_USER:-}" ] || LOGIN_USER="$(id -un 1000 2>/dev/null || echo user)"
AS_USER=(env)
[ "$(id -un)" = "$LOGIN_USER" ] || AS_USER=(runuser -u "$LOGIN_USER" -- env)

# QT_SCALE_FACTOR wants a plain number; round the shell DPI to the nearest
# integer (fractional X11 scale is blurry anyway — the desktop runs 2.0).
QT_SCALE="$(awk -v s="$SCALE" 'BEGIN { printf "%d", (s < 1 ? 1 : s + 0.5) }')"

# Bring up rootful Xwayland on $XDISPLAY if it isn't already serving. The
# shell's LD_LIBRARY_PATH points at the staged Flutter engine tree — strip it
# so host binaries resolve their own libraries.
if ! "${AS_USER[@]}" DISPLAY="$XDISPLAY" xdpyinfo >/dev/null 2>&1; then
    "${AS_USER[@]}" -u LD_LIBRARY_PATH -u LD_PRELOAD \
        XDG_RUNTIME_DIR="$XDG_DIR" WAYLAND_DISPLAY="$WL_SOCKET" \
        Xwayland "$XDISPLAY" -hidpi -terminate 5 \
        >/tmp/xwayland-wechat.log 2>&1 &
    for _ in $(seq 1 100); do
        "${AS_USER[@]}" DISPLAY="$XDISPLAY" xdpyinfo >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

exec "${AS_USER[@]}" -u LD_LIBRARY_PATH -u LD_PRELOAD \
    DISPLAY="$XDISPLAY" QT_SCALE_FACTOR="$QT_SCALE" \
    "$WECHAT_BIN"
