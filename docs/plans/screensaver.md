# Screensaver

> **Status 2026-08-06: it is a real screensaver — it appears on its own,
> verified on live hardware.** Ten minutes idle by default (Settings →
> Appearance → Screensaver, or `~/.config/starling/screensaver`),
> Ctrl+Shift+S on demand, and any key, click or pointer travel wakes it.
> Video playback holds it off through `zwp_idle_inhibit_manager_v1`.
> `sudo test/functional.sh` is green — 19 passed, 10 skipped, including
> both screensaver checks. What remains is the aerial decode path and the
> deferred items at the end.

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
  down a pipe into a mailbox drained by the screensaver ticker. Frames
  decode at the size they are shown (`STARLING_AERIAL_RES` to step down).
  Nothing links FFmpeg — process boundary, as in VideoPlayerApp.
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

### 3. VAAPI zero-copy aerial decode

The CPU pipe is the prototype, and its own comment says so. Measured on
the dev box: decode to 2560x1600 runs 4.3x realtime — decode is never
the constraint, the `glTexImage2D` upload of a 16 MB frame is. The real
path is VAAPI decode straight into a dmabuf imported by
`LinuxTextureRegistry.importDmaBuf` — no CPU copy at all. The recording
side already stands up a VAAPI context (`[Recording] zero-copy VAAPI
encoder ready`), so the plumbing precedent exists in-tree. Keep the pipe
as the fallback (nouveau boxes: VAAPI init fails there today).

### Later, deliberately not now

- **Screen lock on wake** — needs a real auth story (PAM), and turns the
  saver into a security boundary, which changes how carefully the wake
  path must be audited. Do not bolt on casually.
- **DPMS off** after a longer idle period — the natural successor state
  to the saver; the DRM backend owns the connector and can do this.
- **Multi-output** — the overlay spans the implicit view (the primary
  output). Secondary outputs currently keep showing the bare desktop.
