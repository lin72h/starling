# Starling 0.2.3-2 — the respin that lets Chrome and VS Code start

A packaging respin of 0.2.3. One shipped file changes, `/usr/bin/app-run`, and
it fixes something anyone evaluating the desktop would have hit within a
minute: **Chrome and VS Code did not launch.**

Nothing else is different. No Swift was rebuilt, the engine is the same, and
every binary in the package is byte-for-byte what 0.2.3 shipped. `apt` upgrades
0.2.3-1 → 0.2.3-2 in place.

## What was broken

On a real login, clicking Chrome or VS Code lit up the launcher tile, started a
process, and then nothing appeared. The process lived about 2.4 seconds and
never mapped a window.

GDM exports `GNOME_DESKTOP_SESSION_ID=this-is-deprecated` into the session. The
shell inherits it and passed it to every app it spawned. Chromium's
`base/nix/xdg_util.cc` reads that variable as proof of a GNOME session no matter
what `XDG_CURRENT_DESKTOP` says — ours says `Starling` — and the GNOME-only path
it then takes segfaults before a window exists. VS Code is Electron, so it died
the same way for the same reason.

`app-run` now scrubs the variable alongside the Starling-Mesa vars it was
already clearing.

## Why 0.2.3 shipped with it

Every way we had tested a browser missed it, and they all missed it for the
same reason: the variable only exists in a real GDM session.

- `app-run`'s root branch starts from `env -i`, so `sudo app-run chrome` on a
  dev box is clean.
- A developer's SSH session has no `GNOME_DESKTOP_SESSION_ID` either, so
  launching by hand over SSH is clean.
- The release gate never opened a browser at all.

Only the shell's own spawn, inside a session GDM started, carries it — and that
is the one path nobody launches a browser from by hand.

## The gate now opens both

Two checks join the functional tier. Each removes the app, installs it for real
through the same `app-install` the store's Install button runs, and then
launches it **through the Launchpad** — not through a helper in the test
process, because the test tier's environment is not the shell's and cannot
reproduce a bug that lives in what the shell passes its children. Each waits
for a **window**, not a process, since the failure above left a process alive
for seconds that mapped nothing.

Verified in both directions: with the scrub removed, the Chrome check fails
with `timed out after 90s waiting for chrome window`; with it in place both
pass.

One gate bug was fixed alongside them. The guest's own `apt-daily-upgrade`
timer fired mid-run, took 2m43s, and `systemctl poweroff` queued behind it, so
the gate failed at a stage where nothing was actually wrong. Ubuntu's apt
timers are now masked as soon as the snapshot boots — they also hold the dpkg
lock the store's install path needs — and a poweroff timeout prints the guest's
queued systemd jobs instead of failing blind.

## Verification

The full release gate passes against this exact `.deb`: install, a real GDM
login, seat-activeness, the polkit authorisation behind the App Store's Install
button, the functional checks both on a GPU and with 3D acceleration switched
off, and shutting the machine down through the desktop's own power menu.
