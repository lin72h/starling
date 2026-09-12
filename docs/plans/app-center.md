# Ubuntu's App Center on Starling

Starling ships a small curated catalog installed through apt (see
`build/app-install.sh`). Ubuntu's App Center brings the rest of the Linux
ecosystem — thousands of snaps — into the desktop as a first-class app.
This reverses the earlier "apt only, no snap" direction, on the user's
request (2026-09-12).

## The pieces

- **Reaching the compositor.** A snap is AppArmor-confined and may open the
  Wayland socket only at the standard `@{run}/user/<uid>/` path, never
  Starling's private session runtime dir. So the compositor listens on a
  *second* socket in the real per-user runtime dir
  (`wayland_server_add_socket_at`, called from `main.swift` after start),
  in addition to its private one. Unprivileged and restart-safe — no bind
  mounts, no root. The socket is made world-connectable for the dev case
  where the shell runs as root and snaps as the user.

- **Launching.** `Kind=snap` records launch through `app-run --snap
  <target>`, which runs `snap run` against the real runtime dir and the
  real user session bus (confinement can reach neither of the private
  ones), with `GDK_BACKEND=wayland`. Under a root dev shell it drops to the
  login user first, since `snap run` refuses root.

- **App Center.** `registry/catalog.d/appcenter.app` (`Kind=snap`,
  `Exec=snap-store`) puts it in the dock and launcher; its real icon
  resolves from the snap's `.desktop`. `app-install appcenter` installs the
  snap-store snap if a machine lacks it.

- **Discovery.** Snaps installed through the App Center have no catalog
  file. `AppRegistry.discoverSnaps` scans the snapd desktop directory and
  synthesizes a launcher entry per installed GUI snap, skipping any an
  installed catalog app already covers. The registry watches that directory
  (inotify) alongside `installed.d`, so an install appears without a
  relogin.

- **In-app install.** The App Center installs snaps through snapd, which
  needs a polkit prompt (`io.snapcraft.snapd.manage`). The session
  launchers start `lxpolkit` once the compositor socket exists; `snapd` and
  `lxpolkit` are packaging Recommends.

## Verified (2026-09-12, dev box)

- App Center launches from the dock and renders.
- gnome-calculator (GTK4 snap) launches, takes pointer input (7 × 8), and
  is reachable both from `app-run --snap` and the shell's snap path.
- foliate (GTK4 snap, no catalog counterpart) launches and is discovered
  into the launcher (found via search).

## Known limits

- Icons: snaps whose `.desktop` names a theme icon or an SVG show the
  neutral glyph, not their real mark (the engine decodes raster only).
- File dialogs: a snap uses the real user session bus, so its portal is
  whatever answers there, not Starling's own portal on the private bus.
  App Center itself needs no file dialog; browsers and editors as snaps may.
- gnome-2048 (an old GTK snap) is X11-only in its build and does not draw
  on Wayland — an app quirk, not a Starling limit.
- In-app install via polkit is exercised in the shipped/VM login; a root
  dev shell's session semantics make it unreliable to test on the dev box.
