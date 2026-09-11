#!/usr/bin/env bash
# Regenerate the compositor's protocol bindings.
#
#   shell/protocols/regen.sh
#
# The generated <name>-protocol.{c,h} pairs under shell/Sources/WaylandServer
# are committed, so a checkout builds without wayland-scanner; this is how they
# are refreshed. Every protocol the compositor speaks is listed here with the
# XML it comes from: the system's wayland-protocols for the standard ones, and
# this directory for the ones Ubuntu ships no package for (wlroots' protocols,
# and xx-zones, which is still experimental).
#
# Adding a protocol: vendor or locate its XML, add a line, run this, write the
# wayland_<name>.c module and call its init from wayland_server_create.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../Sources/WaylandServer"
SYS=/usr/share/wayland-protocols

# name  xml
PROTOCOLS="
xdg-shell                                   $SYS/stable/xdg-shell/xdg-shell.xml
viewporter                                  $SYS/stable/viewporter/viewporter.xml
presentation-time                           $SYS/stable/presentation-time/presentation-time.xml
linux-dmabuf-unstable-v1                    $SYS/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml
xdg-decoration-unstable-v1                  $SYS/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml
xdg-output-unstable-v1                      $SYS/unstable/xdg-output/xdg-output-unstable-v1.xml
idle-inhibit-unstable-v1                    $SYS/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml
pointer-constraints-unstable-v1             $SYS/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml
relative-pointer-unstable-v1                $SYS/unstable/relative-pointer/relative-pointer-unstable-v1.xml
primary-selection-unstable-v1               $SYS/unstable/primary-selection/primary-selection-unstable-v1.xml
text-input-unstable-v3                      $SYS/unstable/text-input/text-input-unstable-v3.xml
keyboard-shortcuts-inhibit-unstable-v1      $SYS/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml
pointer-gestures-unstable-v1                $SYS/unstable/pointer-gestures/pointer-gestures-unstable-v1.xml
tablet-v2                                   $SYS/stable/tablet/tablet-v2.xml
xdg-activation-v1                           $SYS/staging/xdg-activation/xdg-activation-v1.xml
fractional-scale-v1                         $SYS/staging/fractional-scale/fractional-scale-v1.xml
cursor-shape-v1                             $SYS/staging/cursor-shape/cursor-shape-v1.xml
alpha-modifier-v1                           $SYS/staging/alpha-modifier/alpha-modifier-v1.xml
single-pixel-buffer-v1                      $SYS/staging/single-pixel-buffer/single-pixel-buffer-v1.xml
content-type-v1                             $SYS/staging/content-type/content-type-v1.xml
tearing-control-v1                          $SYS/staging/tearing-control/tearing-control-v1.xml
xdg-toplevel-tag-v1                         $SYS/staging/xdg-toplevel-tag/xdg-toplevel-tag-v1.xml
xdg-dialog-v1                               $SYS/staging/xdg-dialog/xdg-dialog-v1.xml
xdg-system-bell-v1                          $SYS/staging/xdg-system-bell/xdg-system-bell-v1.xml
xdg-toplevel-icon-v1                        $SYS/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml
ext-foreign-toplevel-list-v1                $SYS/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml
ext-data-control-v1                         $SYS/staging/ext-data-control/ext-data-control-v1.xml
ext-idle-notify-v1                          $SYS/staging/ext-idle-notify/ext-idle-notify-v1.xml
ext-image-capture-source-v1                 $SYS/staging/ext-image-capture-source/ext-image-capture-source-v1.xml
ext-image-copy-capture-v1                   $SYS/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml
ext-session-lock-v1                         $SYS/staging/ext-session-lock/ext-session-lock-v1.xml
xdg-foreign-unstable-v2                     $SYS/unstable/xdg-foreign/xdg-foreign-unstable-v2.xml
color-representation-v1                     $SYS/staging/color-representation/color-representation-v1.xml
security-context-v1                         $SYS/staging/security-context/security-context-v1.xml
wlr-output-management-unstable-v1           $HERE/wlr-output-management-unstable-v1.xml
wlr-data-control-unstable-v1                $HERE/wlr-data-control-unstable-v1.xml
wlr-layer-shell-unstable-v1                 $HERE/wlr-layer-shell-unstable-v1.xml
wlr-foreign-toplevel-management-unstable-v1 $HERE/wlr-foreign-toplevel-management-unstable-v1.xml
wlr-screencopy-unstable-v1                  $HERE/wlr-screencopy-unstable-v1.xml
xx-zones-v1                                 $HERE/xx-zones-v1.xml
"

n=0
while read -r name xml; do
    [ -n "$name" ] || continue
    [ -f "$xml" ] || { echo "missing: $xml" >&2; exit 1; }
    wayland-scanner server-header "$xml" "$OUT/$name-protocol.h"
    wayland-scanner private-code  "$xml" "$OUT/$name-protocol.c"
    n=$((n + 1))
done <<< "$PROTOCOLS"
echo "regenerated $n protocol bindings into $OUT"
