#!/usr/bin/env bash
# Build and run the compositor protocol test (see protocols-test.c).
#
#   test/wayland/run.sh [build-dir]    build + run; prints the checks' verdict
#
# The server is compiled from the tree's own sources; the client headers are
# generated from the same XML the server's bindings were (the system's
# wayland-protocols, plus shell/protocols/ for the wlroots ones and xx-zones).
# The client side needs no code of its own: wayland-scanner's private-code is
# the same for both halves, so the server's *-protocol.c files carry every
# interface the client references. No GPU, no display: a socket in a private
# runtime dir, two threads, one process.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SRV="$REPO/shell/Sources/WaylandServer"
SYS=/usr/share/wayland-protocols
OUT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/starling-wltest.XXXXXX")}"

command -v wayland-scanner >/dev/null || { echo "SKIPPED: no wayland-scanner"; exit 0; }
pkg-config --exists wayland-server wayland-client xkbcommon || { echo "SKIPPED: no wayland dev libraries"; exit 0; }

gen() {  # gen <name> <xml>
    wayland-scanner client-header "$2" "$OUT/$1-client-protocol.h"
}
gen xdg-shell                                   "$SYS/stable/xdg-shell/xdg-shell.xml"
gen wlr-layer-shell-unstable-v1                 "$REPO/shell/protocols/wlr-layer-shell-unstable-v1.xml"
gen wlr-foreign-toplevel-management-unstable-v1 "$REPO/shell/protocols/wlr-foreign-toplevel-management-unstable-v1.xml"
gen ext-foreign-toplevel-list-v1                "$SYS/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml"
gen wlr-screencopy-unstable-v1                  "$REPO/shell/protocols/wlr-screencopy-unstable-v1.xml"
gen alpha-modifier-v1                           "$SYS/staging/alpha-modifier/alpha-modifier-v1.xml"
gen xx-zones-v1                                 "$REPO/shell/protocols/xx-zones-v1.xml"
gen xdg-activation-v1                           "$SYS/staging/xdg-activation/xdg-activation-v1.xml"
gen single-pixel-buffer-v1                      "$SYS/staging/single-pixel-buffer/single-pixel-buffer-v1.xml"
gen ext-idle-notify-v1                          "$SYS/staging/ext-idle-notify/ext-idle-notify-v1.xml"
gen keyboard-shortcuts-inhibit-unstable-v1      "$SYS/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml"
gen ext-data-control-v1                         "$SYS/staging/ext-data-control/ext-data-control-v1.xml"
gen xdg-foreign-unstable-v2                     "$SYS/unstable/xdg-foreign/xdg-foreign-unstable-v2.xml"
gen ext-image-capture-source-v1                 "$SYS/staging/ext-image-capture-source/ext-image-capture-source-v1.xml"
gen ext-image-copy-capture-v1                   "$SYS/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml"
gen security-context-v1                         "$SYS/staging/security-context/security-context-v1.xml"
gen wlr-output-management-unstable-v1           "$REPO/shell/protocols/wlr-output-management-unstable-v1.xml"
gen ext-session-lock-v1                         "$SYS/staging/ext-session-lock/ext-session-lock-v1.xml"

cc -O1 -std=gnu11 -Wall -Wno-unused-function -Wno-unused-parameter \
    -I"$SRV/include" -I"$SRV" -I"$OUT" -I/usr/include/libdrm -D_GNU_SOURCE \
    $(pkg-config --cflags wayland-server wayland-client) \
    -o "$OUT/protocols-test" \
    "$REPO/test/wayland/protocols-test.c" \
    "$SRV"/wayland_*.c "$SRV"/*-protocol.c \
    $(pkg-config --libs wayland-server wayland-client) -lxkbcommon -lpthread
"$OUT/protocols-test"
