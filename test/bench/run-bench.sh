#!/usr/bin/env bash
# Terminal benchmark runner — runs INSIDE the terminal under test.
#
#   run-bench.sh <terminal-pid> <results-file>
#
# Runs inside so the timings and the terminal's own CPU counters are captured
# without reading numbers off a screenshot. Each workload is a pre-generated
# file, catted; the page cache is warmed first so no test pays for disk.
set -u
PID="$1"; OUT="$2"
DIR="$(cd "$(dirname "$0")" && pwd)"
HZ=$(getconf CLK_TCK)

cpu() { awk '{print $14+$15}' "/proc/$PID/stat" 2>/dev/null || echo 0; }

# Leave the terminal in a known state between tests: attributes off, scroll
# region full, primary screen, cleared. Without this the alt-screen and
# scroll-region workloads bleed into whatever runs next.
reset_term() { printf '\033[0m\033[r\033[?1049l\033[2J\033[H'; }

: > "$OUT"
echo "# test wall_s cpu_s" >> "$OUT"

for f in "$DIR"/[0-9]*.txt; do
    name=$(basename "$f" .txt)
    cat "$f" > /dev/null            # warm page cache — not timed
    reset_term
    sleep 0.7                       # let the terminal settle/idle first

    c0=$(cpu); t0=$EPOCHREALTIME
    cat "$f"
    t1=$EPOCHREALTIME; c1=$(cpu)

    reset_term
    awk -v n="$name" -v t0="$t0" -v t1="$t1" -v c0="$c0" -v c1="$c1" -v hz="$HZ" \
        'BEGIN{ printf "%s %.3f %.2f\n", n, t1-t0, (c1-c0)/hz }' >> "$OUT"
done

# Resident set after the whole run — how much the terminal is holding onto
# after 400 MB of output has gone through it.
awk '/VmRSS/{printf "rss_kb %s\n", $2}' "/proc/$PID/status" >> "$OUT"
reset_term
echo "BENCH-DONE"
