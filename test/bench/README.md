# test/bench — terminal throughput benchmark

Compares TerminalApp against another terminal (Ghostty, xterm, …) on the same
screen, in the same session, with the same workloads.

Not part of `test/run.sh`: it needs a live desktop, takes a few minutes, and
its numbers are only comparable within one sitting on one machine.

## Why it works the way it does

**Workloads are files, not generators.** Each is written to disk once and
`cat`-ed. Timing `seq 1 20000000` instead measures the producer as much as the
terminal, and a Python generator would measure Python. The runner warms the
page cache before each timed run so nothing pays for disk.

**The runner runs *inside* the terminal under test.** It records the wall time
of each `cat` and the terminal's own `utime+stime` out of `/proc`, and writes
them to a file. Reading numbers off a screenshot is slow and imprecise, and the
terminal cannot report its own CPU from the outside without knowing its pid.

**One `seq` dump is not a benchmark.** It exercises only the plain-text path.
The first comparison run this way concluded "at parity with Ghostty" while
escape-sequence handling was still 3-5x slower — that gap is invisible until
`03_sgr_fg`, `04_sgr_truecolor` and `06_cursor_motion` are in the mix.

## Running it

    test/bench/gen-bench.py /home/<user>/bench      # ~420 MB, ~7 s

Then, in each terminal under test (the runner needs its pid):

    bash ~/bench/run-bench.sh <terminal-pid> ~/bench/results-<name>.txt

Output is `test wall_s cpu_s` per workload, plus `rss_kb` at the end. Compare
the two files. Note each terminal's grid (`stty size`) alongside the numbers —
window sizes differ, and cell count drives the cell-filling workloads.

Worth measuring separately, because the suite does not: idle CPU with static
content (a terminal that spins when nothing happens), and startup time.

## The workloads

| file | what it stresses |
|---|---|
| `01_light_cells` | line feed + scrollback churn, short lines |
| `02_dense_cells` | cell writes — every row filled |
| `03_sgr_fg` | an SGR colour change per cell: the CSI parser |
| `04_sgr_truecolor` | 24-bit colour, five parameters per escape |
| `05_unicode` | the UTF-8 decode path (2, 3 and 4 byte sequences) |
| `06_cursor_motion` | CSI cursor addressing, no scrolling |
| `07_alt_screen` | alt-screen enter/leave with full repaints, as TUIs do |
| `08_scroll_region` | DECSTBM region scrolling |
| `09_long_lines` | autowrap, lines far wider than the window |
| `10_binary` | random bytes with stray escapes — parser worst case |
