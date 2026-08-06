# Screensaver

> **Status 2026-08-06: the visual layer is landed and verified; activation
> is manual.** Ctrl+Shift+S (or `STARLING_SCREENSAVER_TEST=<seconds>` for
> tooling) fades the live desktop into a breathing blur + liquid warp with
> a thin clock, then dissolves into looping aerial footage if a clip is
> installed. Everything below is what remains to make it a real
> screensaver rather than a demo you summon by hand.

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

## Next steps, in order

### 1. Idle detection (the headline gap)

Activation is manual precisely because this is missing. The shell
already sees every input event — `routeKey` and the pointer handlers
funnel through `_DesktopShellState` — so this is one last-activity
timestamp reset from both paths plus a periodic check. Traps already
known: `Foundation.Timer` never fires on the DRM embedder, so use
`DispatchQueue.main.asyncAfter` + a generation token (the pattern
`_armScreensaverTestTimer` already uses); and video playback / an active
screen recording should hold the saver off (an inhibit bit, checked at
fire time). Needs a Settings knob (timeout + off), persisted wherever
Settings keeps the DPI choice today.

### 2. An aerials asset story

Nothing ships a clip. `AerialPlayer.discoverClip()` already searches
`$STARLING_AERIAL`, the packaged `share/starling/aerials/`, and
`~/.local/share/starling/aerials/` — but `stage.sh` stages no `aerials/`
dir and the .deb carries none. Options, not mutually exclusive: bundle
one short public-domain clip (NASA earth footage worked well in
testing — but it is tens of MB, and the .deb is lean today); a
download-on-demand in Settings, macOS-style; or document the drop-in
directory and ship nothing. Decide before the .deb grows by accident.
The saver already falls back to the warp with no assets, so shipping
nothing is a legitimate v1.

### 3. VAAPI zero-copy aerial decode

The CPU pipe is the prototype, and its own comment says so. Measured on
the dev box: decode to 2560x1600 runs 4.3x realtime — decode is never
the constraint, the `glTexImage2D` upload of a 16 MB frame is. The real
path is VAAPI decode straight into a dmabuf imported by
`LinuxTextureRegistry.importDmaBuf` — no CPU copy at all. The recording
side already stands up a VAAPI context (`[Recording] zero-copy VAAPI
encoder ready`), so the plumbing precedent exists in-tree. Keep the pipe
as the fallback (nouveau boxes: VAAPI init fails there today).

### 4. A functional test

`STARLING_SCREENSAVER_TEST=<seconds>` exists for exactly this: activate
without holding a keyboard, screenshot, assert the scrim/clock, inject
pointer travel, assert the desktop is back. Slot it into
`test/run.sh --functional`. Mind the two-shells trap: with a packaged
session also running, shell-drive screenshots and keys go to the wrong
shell — one diagnostic run was already burned on that.

### 5. Docs

`docs/USER_GUIDE.md` says "No screen lock or screensaver." Half of that
is now stale; the security half ("do not rely on it to secure an
unattended machine") stays true and must stay said, since wake is
unauthenticated.

### Later, deliberately not now

- **Screen lock on wake** — needs a real auth story (PAM), and turns the
  saver into a security boundary, which changes how carefully the wake
  path must be audited. Do not bolt on casually.
- **DPMS off** after a longer idle period — the natural successor state
  to the saver; the DRM backend owns the connector and can do this.
- **Multi-output** — the overlay spans the implicit view (the primary
  output). Secondary outputs currently keep showing the bare desktop.
