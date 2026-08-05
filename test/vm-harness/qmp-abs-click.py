#!/usr/bin/env python3
"""Click at an absolute screen position in the VM through a usb-tablet.

    qmp-abs-click.py X Y [SCREEN_W SCREEN_H]

Companion to qmp-click.py, for VMs launched with STARLING_VM_TABLET=1.
The relative-motion trick in qmp-click.py was proven against GNOME; under
Starling's own libinput path the injected PS/2 deltas never move the pointer
at all (verified: every click landed at the untouched screen-centre position).
A tablet's absolute events carry the target coordinate in the event itself,
so there is nothing to accumulate and nothing for pointer acceleration to
rescale. QEMU expects abs axes on a 0..32767 scale regardless of screen size.
"""
import socket, json, sys, os, time

x, y = int(sys.argv[1]), int(sys.argv[2])
w = int(sys.argv[3]) if len(sys.argv) > 3 else 1280
h = int(sys.argv[4]) if len(sys.argv) > 4 else 800

# The QMP socket is in the VM state dir, not beside this script (AF_UNIX
# paths cap at ~108 chars, so chdir and connect via the short relative name).
VM = os.environ.get("STARLING_VM") or os.path.expanduser("~/starling-vm")
os.chdir(VM)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("qmp.sock")
f = s.makefile("rw")


def cmd(obj):
    f.write(json.dumps(obj) + "\r\n"); f.flush()
    while True:
        line = f.readline()
        if not line:
            return None
        msg = json.loads(line)
        if "return" in msg or "error" in msg:
            return msg


cmd({"execute": "qmp_capabilities"})
ax = int(x * 32767 / w)
ay = int(y * 32767 / h)
print("move:", cmd({"execute": "input-send-event", "arguments": {"events": [
    {"type": "abs", "data": {"axis": "x", "value": ax}},
    {"type": "abs", "data": {"axis": "y", "value": ay}},
]}}))
time.sleep(0.15)
print("down:", cmd({"execute": "input-send-event", "arguments": {"events": [
    {"type": "btn", "data": {"button": "left", "down": True}}]}}))
time.sleep(0.08)
print("up:  ", cmd({"execute": "input-send-event", "arguments": {"events": [
    {"type": "btn", "data": {"button": "left", "down": False}}]}}))
