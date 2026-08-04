#!/usr/bin/env python3
"""Cost of GNOME's screencast, measured against a running load.

Three things this gets right that a naive run does not:

  - The D-Bus connection is held for the whole recording. The Screencast
    service stops the moment its caller disconnects ("Sender has vanished"),
    so a busctl-per-call script records nothing.
  - Processes are discovered, not listed. The encoder is a separate gjs
    service, and a fixed process list silently misses it; every process on
    the box is sampled and the ones that MOVED are reported.
  - The load's own throughput is sampled per window. The producer is
    unthrottled, so if recording steals capacity the load simply slows down
    instead of showing up as CPU — a drop here is the interference the CPU
    delta cannot see.

  usage: screencast-bench.py [seconds-per-window]
"""

import os
import sys
import time

import gi  # noqa: F401
from gi.repository import Gio, GLib

HZ = os.sysconf("SC_CLK_TCK")
OUT = os.path.expanduser("~/Videos/bench-gnome2")   # no extension (deprecation)


def snapshot():
    """(per-pid cpu ticks, system busy ticks, producer bytes written)."""
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
    t0 = time.monotonic()
    time.sleep(dur)
    t1 = time.monotonic()
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


def show(name, w):
    print(f"--- {name}  ({w['dt']:.1f}s) ---")
    print(f"    system busy {w['busy']:.2f} cores   load throughput {w['mbs']:.2f} MB/s")
    for comm, c in sorted(w["per"].items(), key=lambda x: -x[1])[:6]:
        print(f"      {c:6.2f}  {comm}")


def main():
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0
    for ext in (".webm", ".mp4"):
        if os.path.exists(OUT + ext):
            os.unlink(OUT + ext)

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)   # held for the run

    base1 = window(dur)
    show("baseline", base1)

    opts = {}
    if len(sys.argv) > 2:
        opts["framerate"] = GLib.Variant("i", int(sys.argv[2]))
        print(f"[framerate option: {sys.argv[2]}]")
    res = bus.call_sync("org.gnome.Shell.Screencast", "/org/gnome/Shell/Screencast",
                        "org.gnome.Shell.Screencast", "Screencast",
                        GLib.Variant("(sa{sv})", (OUT, opts)),
                        None, Gio.DBusCallFlags.NONE, -1, None)
    ok, fname = res.unpack()
    if not ok:
        sys.exit("Screencast refused to start")
    print(f"\n[recording -> {fname}]\n")
    time.sleep(4)          # let the pipeline settle before sampling

    rec = window(dur)
    show("RECORDING", rec)

    bus.call_sync("org.gnome.Shell.Screencast", "/org/gnome/Shell/Screencast",
                  "org.gnome.Shell.Screencast", "StopScreencast",
                  None, None, Gio.DBusCallFlags.NONE, -1, None)
    time.sleep(3)

    base2 = window(dur)
    show("baseline again", base2)

    # ---- attribution -------------------------------------------------
    print("\n=== what recording COST ===")
    names = set(base1["per"]) | set(rec["per"]) | set(base2["per"])
    rows = []
    for n in names:
        b = (base1["per"].get(n, 0.0) + base2["per"].get(n, 0.0)) / 2
        r = rec["per"].get(n, 0.0)
        if abs(r - b) > 0.02:
            rows.append((r - b, n, b, r))
    for d, n, b, r in sorted(rows, key=lambda x: -abs(x[0]))[:8]:
        print(f"  {d:+6.2f} cores  {n:<20} {b:.2f} -> {r:.2f}")

    bb = (base1["busy"] + base2["busy"]) / 2
    mb = (base1["mbs"] + base2["mbs"]) / 2
    print(f"\n  system busy   {bb:.2f} -> {rec['busy']:.2f} cores"
          f"   ({rec['busy'] - bb:+.2f})")
    print(f"  load throughput {mb:.2f} -> {rec['mbs']:.2f} MB/s"
          f"   ({100 * (rec['mbs'] - mb) / mb if mb else 0:+.1f}%)")
    print(f"  baseline drift  {abs(base1['busy'] - base2['busy']):.2f} cores")
    print(f"\n  file: {fname}")


if __name__ == "__main__":
    main()
