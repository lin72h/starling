#!/usr/bin/env bash
# STEP 3 — after the graphical boot, confirm the Starling session actually came
# up through the normal login path, and that it is GPU (virgl) accelerated.
set -u
line(){ echo; echo "===== $* ====="; }

line "who is logged in / graphical session (logind)"
loginctl list-sessions 2>/dev/null
echo "seat0 active session type: $(loginctl show-seat seat0 -p ActiveSession --value 2>/dev/null)"

line "is the Starling shell running (started by the DM, not by hand)?"
pgrep -a -f 'DesktopShellApp|starling-session' || echo "  (DesktopShellApp not found)"
echo "parent chain of DesktopShellApp:"; \
  pid=$(pgrep -x DesktopShellApp | head -1); \
  while [ -n "${pid:-}" ] && [ "$pid" != 1 ]; do \
    echo "   $(cat /proc/$pid/comm 2>/dev/null) [$pid]"; \
    pid=$(awk '/^PPid:/{print $2}' /proc/$pid/status 2>/dev/null); \
  done

line "Starling session log (the shipped launcher's log)"
sudo tail -40 /tmp/starling-session-*.log 2>/dev/null || echo "  (no session log)"

line "GPU acceleration proof"
echo "-- guest kernel virgl:"; sudo dmesg 2>/dev/null | grep -iE 'virgl|virtio_gpu|\[drm\]' | head -8
echo "-- Mesa renderer (eglinfo, GBM/surfaceless):"
sudo apt-get install -y -qq mesa-utils >/dev/null 2>&1
(eglinfo -B 2>/dev/null || eglinfo 2>/dev/null) | grep -iE 'renderer|device|platform' | head -12 || echo "  (eglinfo unavailable)"
line "DONE-STEP3"
