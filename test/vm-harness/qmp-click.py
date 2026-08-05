#!/usr/bin/env python3
"""Click at an absolute screen position in the VM, through QEMU.

    qmp-click.py X Y [SCREEN_W SCREEN_H]

GNOME on Wayland has no XTEST, so synthetic input cannot come from inside the
guest — it has to be injected below it. QEMU's `input-send-event` does that at
the device level, which is also a more honest test: the events arrive the same
way a real mouse's would.

The default pointer is a PS/2 mouse, so motion is RELATIVE. Slamming the
pointer to the origin with one large negative move, then stepping to the
target, gives an absolute position without needing a tablet device.
"""
import socket, json, sys, os, time

x, y = int(sys.argv[1]), int(sys.argv[2])

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
        m = json.loads(line)
        if "return" in m or "error" in m:
            return m


def rel(axis, value):
    return {"type": "rel", "data": {"axis": axis, "value": value}}


f.readline()
cmd({"execute": "qmp_capabilities"})

# Pin to the top-left, then step to the target.
print("home:", cmd({"execute": "input-send-event",
                    "arguments": {"events": [rel("x", -4000), rel("y", -4000)]}}))
time.sleep(0.5)
print("move:", cmd({"execute": "input-send-event",
                    "arguments": {"events": [rel("x", x), rel("y", y)]}}))
time.sleep(0.8)
for down in (True, False):
    print("btn:", cmd({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": down, "button": "left"}}]}}))
    time.sleep(0.2)
