#!/usr/bin/env python3
import socket, json, sys, os

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shot.ppm"

# The QMP socket lives in the VM state dir, not beside this script.
# AF_UNIX paths cap at ~108 chars; chdir and connect via the short relative name
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

print("greeting:", f.readline().strip()[:80])
cmd({"execute": "qmp_capabilities"})
# try PNG first, fall back to PPM
r = cmd({"execute": "screendump", "arguments": {"filename": out, "format": "png"}})
if r and "error" in r:
    print("png unsupported, falling back to ppm:", r["error"].get("desc", "")[:60])
    out = out.rsplit(".", 1)[0] + ".ppm"
    r = cmd({"execute": "screendump", "arguments": {"filename": out}})
print("screendump:", r)
print("WROTE", out)
