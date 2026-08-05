#!/usr/bin/env python3
"""Grab one framebuffer from a VNC server (RFB 3.8, raw encoding) -> PPM.

    rfb-grab.py HOST:PORT OUT.ppm [--wait SECONDS]

Minimal stdlib-only RFB client, written to see what a *console viewer* sees on
a QEMU VGA/bochs guest — QMP screendump forces a device-side surface refresh,
which can hide exactly the class of stale-surface bug a real, persistently
connected console would show. --wait keeps the connection open that long
before requesting the frame, mimicking a console that was already attached
while the guest changed modes.

No auth (QEMU -vnc without password). Raw + no encodings negotiated, so the
server must send unencoded rects (QEMU honours an empty SetEncodings as raw).
"""
import socket, struct, sys, time

hostport = sys.argv[1]
out = sys.argv[2]
wait = 0.0
if len(sys.argv) > 4 and sys.argv[3] == "--wait":
    wait = float(sys.argv[4])
host, port = hostport.rsplit(":", 1)

s = socket.create_connection((host, int(port)), timeout=20)
f = s.makefile("rwb")

def rd(n):
    b = f.read(n)
    if b is None or len(b) < n:
        sys.exit(f"short read ({0 if b is None else len(b)}/{n})")
    return b

# --- handshake ---------------------------------------------------------------
server_ver = rd(12)                      # b"RFB 003.008\n"
f.write(b"RFB 003.008\n"); f.flush()
nsec = rd(1)[0]
if nsec == 0:
    sys.exit("server refused: " + rd(4).decode(errors="replace"))
sects = rd(nsec)
if 1 not in sects:
    sys.exit(f"no None security type offered: {list(sects)}")
f.write(bytes([1])); f.flush()           # None
if struct.unpack(">I", rd(4))[0] != 0:   # SecurityResult
    sys.exit("security handshake failed")
f.write(bytes([1])); f.flush()           # ClientInit: shared
w, h = struct.unpack(">HH", rd(4))
pf = rd(16)                              # server pixel format
namelen = struct.unpack(">I", rd(4))[0]
rd(namelen)
bpp, depth, big_endian, true_colour = pf[0], pf[1], pf[2], pf[3]
rmax, gmax, bmax = struct.unpack(">HHH", pf[4:10])
rsh, gsh, bsh = pf[10], pf[11], pf[12]
print(f"server: {w}x{h} bpp={bpp} depth={depth} shifts=({rsh},{gsh},{bsh})")

# SetEncodings: raw + DesktopSize (-223), so a guest mode switch resizes our
# framebuffer instead of leaving us reading a stale geometry.
f.write(struct.pack(">BxH", 2, 2) + struct.pack(">ii", 0, -223)); f.flush()

fb = bytearray(w * h * 4)
got = 0

if wait:
    # Live like a console: sit connected for `wait` seconds sending
    # INCREMENTAL update requests and folding whatever rects arrive into the
    # framebuffer, then write what we hold — no final full-frame request,
    # because a full request forces the server to resend everything and hides
    # exactly the stale-dirty-region behaviour a persistent viewer would show.
    s.settimeout(1.0)
    deadline = time.time() + wait
    while time.time() < deadline:
        f.write(struct.pack(">BBHHHH", 3, 1, 0, 0, w, h)); f.flush()
        try:
            mtype = rd(1)[0]
        except Exception:
            continue
        if mtype == 0:
            rd(1)
            nrects = struct.unpack(">H", rd(2))[0]
            for _ in range(nrects):
                x, y, rw, rh, enc = struct.unpack(">HHHHi", rd(12))
                if enc == -224:            # LastRect pseudo-encoding
                    break
                if enc == -223:            # DesktopSize: guest mode switch
                    w, h = rw, rh
                    fb = bytearray(w * h * 4)
                    print(f"resize -> {w}x{h}")
                    break
                if enc != 0:
                    sys.exit(f"non-raw rect encoding {enc}")
                data = rd(rw * rh * (bpp // 8))
                px = bpp // 8
                for row in range(rh):
                    src = row * rw * px
                    dst = ((y + row) * w + x) * 4
                    fb[dst:dst + rw * 4] = data[src:src + rw * px]
                got += rw * rh
        elif mtype == 3:
            rd(3); ln = struct.unpack(">I", rd(4))[0]; rd(ln)
        time.sleep(0.1)
    got = w * h   # dump whatever state a console would be showing
    s.settimeout(20)

else:
    # FramebufferUpdateRequest, non-incremental: full frame
    f.write(struct.pack(">BBHHHH", 3, 0, 0, 0, w, h)); f.flush()

deadline = time.time() + 30
while got < w * h and time.time() < deadline:
    mtype = rd(1)[0]
    if mtype == 0:                        # FramebufferUpdate
        rd(1)
        nrects = struct.unpack(">H", rd(2))[0]
        for _ in range(nrects):
            x, y, rw, rh, enc = struct.unpack(">HHHHi", rd(12))
            if enc == -223:
                w, h = rw, rh
                fb = bytearray(w * h * 4)
                continue
            if enc != 0:
                sys.exit(f"non-raw rect encoding {enc}")
            data = rd(rw * rh * (bpp // 8))
            px = bpp // 8
            for row in range(rh):
                src = row * rw * px
                dst = ((y + row) * w + x) * 4
                fb[dst:dst + rw * 4] = data[src:src + rw * px] if px == 4 else b"".join(
                    data[i:i + px] + b"\0" for i in range(src, src + rw * px, px))
            got += rw * rh
    elif mtype == 2:                      # Bell
        pass
    elif mtype == 3:                      # ServerCutText
        rd(3); ln = struct.unpack(">I", rd(4))[0]; rd(ln)
    else:
        sys.exit(f"unexpected message type {mtype}")

# fb holds server-endian pixels; decode via shifts/max into RGB
with open(out, "wb") as o:
    o.write(f"P6\n{w} {h}\n255\n".encode())
    step = 4
    unpack = "<I" if not big_endian else ">I"
    for i in range(0, len(fb), step):
        v = struct.unpack(unpack, fb[i:i + 4])[0]
        r = (v >> rsh) & rmax
        g = (v >> gsh) & gmax
        b = (v >> bsh) & bmax
        o.write(bytes((r * 255 // rmax, g * 255 // gmax, b * 255 // bmax)))
print(f"wrote {out} ({w}x{h}, {got}/{w*h} px)")
