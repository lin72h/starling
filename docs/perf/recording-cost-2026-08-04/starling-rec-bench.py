#!/usr/bin/env python3
"""Cost of Starling's screen recorder, measured the same way as GNOME's.

Same windows (baseline / recording / baseline), same per-process discovery,
same throughput sampling from the producer's wchar — so the two numbers are
comparable. The recorder is driven through the shell's own agent ops rather
than by reading pixels: control_center_state gives the tile to click and
recording_state says when it actually became real.

  usage: sudo starling-rec-bench.py [seconds-per-window]
"""

import json
import os
import socket
import subprocess
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")
SOCK = "/tmp/xdg-starling-1000/starling-agent.sock"
DRIVE = "build/shell-drive.py"


def ask(op):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(6)
    s.connect(SOCK)
    s.send(json.dumps({"op": op, "id": 1}).encode() + b"\n")
    buf = b""
    while b"\n" not in buf:
        buf += s.recv(65536)
    s.close()
    return json.loads(buf.split(b"\n", 1)[0])


def drive(*actions):
    subprocess.run([sys.executable, DRIVE, *actions],
                   capture_output=True, text=True)


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
    print(f"--- {name}  ({w['dt']:.1f}s) ---")
    print(f"    system busy {w['busy']:.2f} cores   load throughput {w['mbs']:.2f} MB/s")
    for comm, c in sorted(w["per"].items(), key=lambda x: -x[1])[:6]:
        print(f"      {c:6.2f}  {comm}")


def wait_state(want, timeout=25):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        st = ask("recording_state")
        if st.get("state") == want:
            return st
        time.sleep(0.5)
    return ask("recording_state")


def main():
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0

    base1 = window(dur)
    show("baseline", base1)

    # open the control center and hit the record tile
    cc = ask("control_center_state")
    drive(f"click {cc['icon']['x']} {cc['icon']['y']}", "sleep 2")
    cc = ask("control_center_state")
    tile = next(t for t in cc["tiles"] if t["id"] == "record")
    drive(f"click {tile['x']} {tile['y']}", "sleep 2")

    st = wait_state("recording")
    if st.get("state") != "recording":
        sys.exit(f"recorder never started: {st}")
    print(f"\n[recording] capture {st.get('capture_w')}x{st.get('capture_h')} "
          f"hardware={st.get('hardware')} zero_copy={st.get('zero_copy')}\n")
    time.sleep(4)

    rec = window(dur)
    show("RECORDING", rec)

    ind = ask("recording_state")["indicator"]
    drive(f"click {ind['x']} {ind['y']}", "sleep 2")
    st = wait_state("idle")
    time.sleep(3)

    base2 = window(dur)
    show("baseline again", base2)

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
    print(f"\n  system busy   {bb:.2f} -> {rec['busy']:.2f} cores  ({rec['busy']-bb:+.2f})")
    print(f"  load throughput {mb:.2f} -> {rec['mbs']:.2f} MB/s "
          f"({100*(rec['mbs']-mb)/mb if mb else 0:+.1f}%)")
    print(f"  baseline drift  {abs(base1['busy']-base2['busy']):.2f} cores")
    print(f"\n  file: {st.get('last_file')}")


if __name__ == "__main__":
    main()
