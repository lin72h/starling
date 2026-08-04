#!/usr/bin/env python3
"""A/B mutter's RecordMonitor against RecordArea, everything else identical.

GNOME's own screencast service always calls RecordArea — even for a
whole-screen recording — and mutter MR !1711 (open since 2021) says the area
stream paints the stage a second time instead of reusing the monitor's
framebuffer. If RecordMonitor is the cheaper path, then GNOME is paying that
cost by choice and the fix is to call the other method.

The downstream pipeline here is copied verbatim from screencastService.js,
so the ONLY difference between the two runs is which D-Bus method asks for
the stream.

  usage: ab-capture.py monitor|area [seconds-per-window]
"""

import os
import sys
import threading
import time

import gi
gi.require_version("Gst", "1.0")
from gi.repository import Gio, GLib, Gst  # noqa: E402

HZ = os.sysconf("SC_CLK_TCK")
SD = os.path.dirname(os.path.abspath(__file__))
SC = "org.gnome.Mutter.ScreenCast"
CONNECTOR = "eDP-1"
LOGICAL_W, LOGICAL_H = 1536, 960          # 2560x1600 at scale 1.667

# verbatim from screencastService.js: hwenc-dmabuf-h264-vaapi
ENCODE = ("capsfilter caps=video/x-raw(memory:DMABuf),format=DMA_DRM,max-framerate=30/1 ! "
          "vapostproc ! vah264enc ! queue ! h264parse ! "
          "mp4mux fragment-duration=500 fragment-mode=first-moov-then-finalise")


def snapshot():
    procs = {}
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            with open(f"/proc/{p}/stat") as f:
                st = f.read()
            comm = st.split("(", 1)[1].rsplit(")", 1)[0]
            parts = st.rsplit(") ", 1)[1].split()
            procs[int(p)] = (comm, int(parts[11]) + int(parts[12]))
        except (OSError, IndexError):
            pass
    v = list(map(int, open("/proc/stat").readline().split()[1:9]))
    busy = sum(v) - v[3] - v[4]
    w = 0
    for pid, (comm, _) in procs.items():
        if comm == "xxd":
            try:
                for line in open(f"/proc/{pid}/io"):
                    if line.startswith("wchar:"):
                        w += int(line.split()[1])
            except OSError:
                pass
    return procs, busy, w


def window(dur):
    a, ba, wa = snapshot()
    t0 = time.monotonic(); time.sleep(dur); t1 = time.monotonic()
    b, bb, wb = snapshot()
    dt = t1 - t0
    per = {}
    for pid, (comm, end) in b.items():
        if pid in a:
            d = end - a[pid][1]
            if d > 0:
                per[comm] = per.get(comm, 0.0) + (d / HZ) / dt
    return {"per": per, "busy": (bb - ba) / HZ / dt,
            "mbs": (wb - wa) / 1e6 / dt, "dt": dt}


def main():
    mode = sys.argv[1]
    dur = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0
    out = f"{SD}/ab-{mode}.mp4"
    if os.path.exists(out):
        os.unlink(out)
    Gst.init(None)

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    loop = GLib.MainLoop()
    threading.Thread(target=loop.run, daemon=True).start()

    sess = bus.call_sync(SC, "/org/gnome/Mutter/ScreenCast", SC, "CreateSession",
                         GLib.Variant("(a{sv})", ({},)), None,
                         Gio.DBusCallFlags.NONE, -1, None).unpack()[0]

    got = {}
    bus.signal_subscribe(None, f"{SC}.Stream", "PipeWireStreamAdded", None, None,
                         Gio.DBusSignalFlags.NONE,
                         lambda *a: got.__setitem__("node", a[5].unpack()[0]))

    props = {"is-recording": GLib.Variant("b", True),
             "cursor-mode": GLib.Variant("u", 0)}
    if mode == "monitor":
        bus.call_sync(SC, sess, f"{SC}.Session", "RecordMonitor",
                      GLib.Variant("(sa{sv})", (CONNECTOR, props)), None,
                      Gio.DBusCallFlags.NONE, -1, None)
    else:
        bus.call_sync(SC, sess, f"{SC}.Session", "RecordArea",
                      GLib.Variant("(iiiia{sv})", (0, 0, LOGICAL_W, LOGICAL_H, props)),
                      None, Gio.DBusCallFlags.NONE, -1, None)

    b1 = window(dur)
    print(f"--- baseline ({b1['dt']:.0f}s) --- busy {b1['busy']:.2f} cores, "
          f"load {b1['mbs']:.2f} MB/s")

    bus.call_sync(SC, sess, f"{SC}.Session", "Start", None, None,
                  Gio.DBusCallFlags.NONE, -1, None)
    t0 = time.monotonic()
    while "node" not in got and time.monotonic() - t0 < 10:
        time.sleep(0.1)
    if "node" not in got:
        sys.exit("no PipeWireStreamAdded")
    node = got["node"]
    pipeline = Gst.parse_launch(
        f'pipewiresrc path={node} do-timestamp=true keepalive-time=1000 '
        f'resend-last=true ! {ENCODE} ! filesink location="{out}"')
    pipeline.set_state(Gst.State.PLAYING)
    print(f"[{mode}] node={node} -> {out}")
    time.sleep(4)

    r = window(dur)
    print(f"--- RECORDING ({r['dt']:.0f}s) --- busy {r['busy']:.2f} cores, "
          f"load {r['mbs']:.2f} MB/s")
    for comm, c in sorted(r["per"].items(), key=lambda x: -x[1])[:4]:
        print(f"      {c:6.2f}  {comm}")

    pipeline.send_event(Gst.Event.new_eos())
    time.sleep(2)
    pipeline.set_state(Gst.State.NULL)
    try:
        bus.call_sync(SC, sess, f"{SC}.Session", "Stop", None, None,
                      Gio.DBusCallFlags.NONE, -1, None)
    except GLib.GError:
        pass
    time.sleep(3)

    b2 = window(dur)
    print(f"--- baseline again ({b2['dt']:.0f}s) --- busy {b2['busy']:.2f} cores, "
          f"load {b2['mbs']:.2f} MB/s")

    base = (b1["mbs"] + b2["mbs"]) / 2
    bb = (b1["busy"] + b2["busy"]) / 2
    print(f"\n=== {mode.upper()} ===")
    print(f"  load throughput {base:.2f} -> {r['mbs']:.2f} MB/s   "
          f"{100*(r['mbs']-base)/base if base else 0:+.1f}%")
    print(f"  system busy     {bb:.2f} -> {r['busy']:.2f} cores")
    print(f"  baseline drift  {abs(b1['busy']-b2['busy']):.2f} cores")
    loop.quit()


if __name__ == "__main__":
    main()
