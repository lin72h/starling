#!/usr/bin/env python3
"""Cost of a wlr-screencopy recording on Hyprland, measured like the others.

Same three windows, same per-process discovery, same throughput sampling
from the producer's wchar, same 30fps hardware H.264 target — so the number
lands next to the GNOME and Starling ones.

  usage: hypr-rec-bench.py [seconds-per-window] [framerate]
"""

import os
import signal
import subprocess
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")
SD = os.path.dirname(os.path.abspath(__file__))
OUT = f"{SD}/hypr-rec.mp4"


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
    print(f"--- {name} ({w['dt']:.0f}s) --- busy {w['busy']:.2f} cores, "
          f"load {w['mbs']:.2f} MB/s")
    for comm, c in sorted(w["per"].items(), key=lambda x: -x[1])[:5]:
        print(f"      {c:6.2f}  {comm}")


def main():
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 25.0
    fps = sys.argv[2] if len(sys.argv) > 2 else "30"
    if os.path.exists(OUT):
        os.unlink(OUT)

    env = dict(os.environ)
    env.update({"XDG_RUNTIME_DIR": "/run/user/1000", "WAYLAND_DISPLAY": "wayland-1"})

    b1 = window(dur)
    show("baseline", b1)

    proc = subprocess.Popen(
        ["wf-recorder", "-c", "h264_vaapi", "-d", "/dev/dri/renderD129",
         "-r", fps, "-f", OUT, "--overwrite"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    time.sleep(4)
    if proc.poll() is not None:
        sys.exit("wf-recorder died immediately")
    print(f"\n[recording -> {OUT} @ {fps}fps]\n")

    r = window(dur)
    show("RECORDING", r)

    proc.send_signal(signal.SIGINT)
    try:
        proc.wait(timeout=20)
    except subprocess.TimeoutExpired:
        proc.kill()
    time.sleep(3)

    b2 = window(dur)
    show("baseline again", b2)

    print("\n=== what recording COST ===")
    names = set(b1["per"]) | set(r["per"]) | set(b2["per"])
    rows = []
    for n in names:
        b = (b1["per"].get(n, 0.0) + b2["per"].get(n, 0.0)) / 2
        rr = r["per"].get(n, 0.0)
        if abs(rr - b) > 0.02:
            rows.append((rr - b, n, b, rr))
    for d, n, b, rr in sorted(rows, key=lambda x: -abs(x[0]))[:8]:
        print(f"  {d:+6.2f} cores  {n:<20} {b:.2f} -> {rr:.2f}")
    bb = (b1["busy"] + b2["busy"]) / 2
    mb = (b1["mbs"] + b2["mbs"]) / 2
    print(f"\n  system busy   {bb:.2f} -> {r['busy']:.2f} cores  ({r['busy']-bb:+.2f})")
    print(f"  load throughput {mb:.2f} -> {r['mbs']:.2f} MB/s "
          f"({100*(r['mbs']-mb)/mb if mb else 0:+.1f}%)")
    print(f"  baseline drift  {abs(b1['busy']-b2['busy']):.2f} cores")


if __name__ == "__main__":
    main()
