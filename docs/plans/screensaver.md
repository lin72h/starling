# Screensaver

> **Status 2026-08-06: it is a real screensaver — it appears on its own,
> verified on live hardware.** Ten minutes idle by default (Settings →
> Appearance → Screensaver, or `~/.config/starling/screensaver`),
> Ctrl+Shift+S on demand, and any key, click or pointer travel wakes it.
> Video playback holds it off through `zwp_idle_inhibit_manager_v1`.
> Aerial footage decodes, scales and colour-converts on the GPU, which cut
> the whole feature's CPU cost by 28%. `sudo test/functional.sh` is green
> — 20 passed, 10 skipped, including both screensaver checks. What remains
> is the zero-copy question below, which is a licensing/architecture
> decision rather than an optimisation, and the deferred items at the end.

## What exists

- `Shell/ScreenSaverOverlay.swift` — the surface. The live desktop seen
  through a `BackdropFilter` (no capture step): breathing blur composed
  with the warp shader, dark scrim, clock, and an aerial texture that
  cross-fades in on top. The fade is parametric (`fadeT` scales sigma,
  warp strength, scrim alpha) because an ancestor `Opacity` cannot
  attenuate what a BackdropFilter does to its backdrop.
- `Shaders/screensaver.frag` (+ committed `.iplr`) — the warp: two
  incommensurate sine pairs plus a cheap domain warp, edge-damped and
  clamped so it never samples off-screen. `Shaders/compile.sh` rebuilds
  the `.iplr`s with the engine checkout's `impellerc`.
- `Shell/AerialPlayer.swift` — a spawned ffmpeg per run, exact-CFR RGBA
  down a pipe into a mailbox drained by the screensaver ticker. Decode,
  cover-scale and colour conversion happen on the GPU where VAAPI can do
  them, with the all-CPU chain as the fallback; frames arrive at the size
  they are shown (`STARLING_AERIAL_RES` to step down). Nothing links
  FFmpeg — process boundary, as in VideoPlayerApp.
- `DesktopShell.swift` — activation/dismiss/fade, the monotonic uTime
  ticker, modal key swallow with a 350 ms grace window, pointer-drift
  wake (24 logical px — a resting trackpad hand emits hovers a pixel at
  a time, and waking on the first one dismissed the saver instantly).

## Done since

### 1. Idle detection ✓

`_noteUserActivity()` stamps a Date from the shell's topmost global
pointer Listener and from the raw `pd.onKeyData` hook — between them
every event, including ones forwarded to Wayland and X11 clients, since
client windows are textures in this same tree. Synthesized key repeats
are excluded: a stuck key is not a person. `_armIdleTimer` re-arms
itself for whatever time is left rather than polling, so a busy desktop
costs one wakeup per idle period; `DispatchQueue.main.asyncAfter` + a
generation token, never `Foundation.Timer`.

**The inhibit came free, and was already half-built.** The compositor
has implemented `zwp_idle_inhibit_manager_v1` all along — accepting
inhibitors and dropping them on the floor, under a comment explaining
that idle tracking didn't exist. It does now, so
`wayland_idle_inhibit.c` counts live inhibitors and publishes the count.
The count is maintained by a resource *destructor*, not by the destroy
request, because a client that crashes mid-video never sends one and a
leaked inhibitor would suppress the screensaver for the rest of the
session. A live inhibitor counts as activity rather than merely
deferring the check, so the user gets a full idle period after the film
ends instead of a screensaver the instant the inhibitor drops.

Settings → Appearance → Screensaver is a `MacosSegmentedControl` (new,
in `sdk/` — AppKit's NSSegmentedControl, which the port lacked) over
Never / 1 / 5 / 10 / 30 min / 1 hr, on the same push-and-echo channel as
the wallpaper picker. The choice persists to
`~/.config/starling/screensaver`; `STARLING_SCREENSAVER_IDLE` overrides
it without touching the user's config.

### 2. Aerials: ship the directory, not the footage ✓

Decided. `stage.sh` now stages `share/aerials/` with a README naming the
three search paths, and the .deb carries it. No clip ships: the warp is
a complete screensaver on its own, and the clips worth watching run to
tens of megabytes — a poor thing to put on every install for a
decoration. Download-on-demand in Settings stays available as a later
option; the drop-in directory is the v1.

### 3. Aerial decode on the GPU ✓

The old note here guessed that decode was cheap and the `glTexImage2D`
upload was the constraint. Measured on the dev box, both were wrong about
the balance. Playing a 2560x1600 clip full-screen, CPU-seconds per 60s of
wall clock:

|                          | shell  | decoder | total  |
|--------------------------|--------|---------|--------|
| before                   | 36.65s | 54.83s  | 91.48s |
| after                    | 34.28s | 31.19s  | 65.47s |

**The decoder was the bigger half, and it was mostly swscale.** ffmpeg was
converting YUV to RGBA and scaling on the CPU. `scale_vaapi` does both on
the GPU, and `hwdownload` brings back exactly the same packed RGBA the
pipe already carried — so this is a change of ffmpeg *arguments*, not of
the protocol, and it needs no new IPC and no linked library. In isolation
(240 frames, flat out) it is 11.8s of CPU versus 3.8s.

The `glTexImage2D`-per-frame did cost something, but far less than
claimed: switching to `glTexSubImage2D` when the size is unchanged is
worth ~6% of the shell's CPU (34.1 vs 36.1 CPU-s/60s, repeatable). Note
that `pidstat` could not resolve that difference at all — it took exact
utime+stime deltas from `/proc`. The win applies to every wl_shm client,
not just the screensaver.

Also fixed here: `AerialPlayer.init` used to run the ~0.4s cropdetect
probe **and** spawn ffmpeg synchronously, from `_activateScreensaver` on
the main thread — stalling more than half of the screensaver's own 700ms
fade. All of it now happens on the decode thread; measured, the saver
paints at t+0 and the decoder joins at t+0.47s.

Fallbacks, all three verified live: no VAAPI or a wrong render node → the
decoder delivers no frames and the CPU chain is spawned instead (that
non-answer *is* the probe — no startup roundtrip is paid on machines
where it works); `STARLING_AERIAL_VAAPI=0` → CPU; and a clip with real
letterbox bars → CPU, because `scale_vaapi` cannot crop and cropping
after the scale would be the wrong geometry. The render node is matched
through the sysfs device links like `find_render_node_devid()` in
wayland_dmabuf.c, not guessed by number — this box's renderD128 is the
nouveau device whose VAAPI fails to initialise, and the compositor is on
renderD129.

### 4. Functional checks ✓ — and they found a real bug

Two, both green on live hardware. `check_screensaver_idle` waits out a
real idle period with no input, asserts the saver arrived, wakes it with
pointer travel, then waits out a *second* period — the re-arm after a
wake is the bug you only find on the second cycle.
`check_screensaver_inhibit` builds a tiny `zwp_idle_inhibit_manager_v1`
client from `test/fixtures/idle-inhibit-client.c` (wayland-scanner + cc
at run time; no checked-in binary to rot), holds an inhibitor across
twice the idle period asserting the saver never appears, then **SIGKILLs
it** — a client that dies never sends `destroy`, so the count is only
right if a wl_resource destructor maintains it. Both assert through a
new unscoped broker op (`screensaver` → active / idle_seconds /
inhibited), never pixels, for the reason the suite's header gives: a
screenshot baseline over a compositor gets re-blessed until it tests
nothing. `functional.sh` starts the shell with
`STARLING_SCREENSAVER_IDLE=15`.

**What the live run caught.** The first version treated a live inhibitor
as activity and re-armed a full period, which sounds right and isn't:
the stamp is taken at the *check*, so if the client dies late in that
period the remaining time is near zero. Measured on the dev box, the
screensaver came up **13 seconds** after the inhibiting client died, on
a 20-second timeout — scaled to the shipped 600s default that is the
credits rolling and the desktop vanishing seconds later, half the time.
`_checkIdle` now polls at `min(period, 30)` while inhibited so the
release is noticed promptly, and starts a *fresh* full period on the
check that finds the inhibitor gone. Re-measured: 25s, where 20s is the
floor. No unit test would have found this; it needed a real client
holding a real inhibitor and a clock.

### 5. Docs ✓

`USER_GUIDE.md` has a Screensaver section, the shortcut table has
Ctrl+Shift+S, and the "no screen lock or screensaver" limitation is now
"no screen lock" — with the security warning kept, since wake is
unauthenticated.

## Next

### Zero-copy aerials — a decision, not an optimisation

What remains of the aerial's cost is the `hwdownload` and the texture
upload, about 0.4 GB/s each way, and removing them needs the decoder to
hand the compositor a dma-buf. There are only two ways there, and both
are choices someone has to make rather than work to schedule:

- **Link libav\*** and use `vaExportSurfaceHandle`. Ubuntu builds ffmpeg
  with `--enable-gpl`, so this reverses the deliberate decision in
  ade2f64 and changes what the desktop's licence can be. Not a
  performance call — ask first.
- **Present it as a Wayland client.** A player (mpv with `--hwdec=vaapi`)
  decodes and commits dma-bufs through the compositor's existing, already
  battle-tested import path, and the screensaver composites that surface
  instead of its own texture. No new decode code and no licensing
  question, but it makes the aerial layer a client whose lifecycle the
  shell has to own, and adds a Recommends.

Worth weighing against what it buys: with the GPU decode in place the
whole screensaver costs about 1.1 cores while it is up, and a machine
with no aerial installed — the shipped default — pays 0.29.

### Later, deliberately not now

- **Screen lock on wake** — needs a real auth story (PAM), and turns the
  saver into a security boundary, which changes how carefully the wake
  path must be audited. Do not bolt on casually.
- **DPMS off** after a longer idle period — the natural successor state
  to the saver; the DRM backend owns the connector and can do this.
- **Multi-output** — the overlay spans the implicit view (the primary
  output). Secondary outputs currently keep showing the bare desktop.
