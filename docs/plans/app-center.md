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

## Flatpak (2026-09-15)

The second sealed-package ecosystem, and the one that does not rot against new
hardware: a Flatpak bundles no graphics driver — Flathub delivers Mesa as a
separate runtime extension kept current on its own — so VLC from Flathub
renders on this laptop's GPU where VideoLAN's core18 snap falls back to
software (~240% CPU vs ~9% on the same clip).

- `Kind=flatpak`; `exec` is the app id. Discovered from Flatpak's exported
  desktop entries (system and per-user `exports/share/applications`, main
  entry `<id>.desktop` with `X-Flatpak=`), icons from the exported hicolor
  set. Discovery runs before snaps, so an app in both shows once, as the
  Flatpak. `$STARLING_FLATPAK_EXPORTS_DIR` / `$STARLING_SNAP_DESKTOP_DIR`
  override the directories; the registry tests point both at empty ones.
- Launch: `app-run --flatpak <id>` → `flatpak run` against the real per-user
  runtime dir (X11 via the shared /tmp/.X11-unix, Wayland via the socket the
  compositor exposes there, audio via PULSE_SERVER), GTK/Qt given both
  backends. No compositor change was needed.
- Install: `app-install --flatpak <id>` (and `--remove`) — Flathub remote
  added on first use. There is no Flathub storefront on the desktop yet;
  Ubuntu's App Center does not list Flathub.
- Packaging: `flatpak` in Recommends beside `snapd`.
- Storefront (2026-09-15): the App Store app has a **Flathub** page — search
  (debounced, via flathub.org's public service through curl), Popular and
  Trending, an Installed list, real icons (fetched once, cached under
  `$XDG_CACHE_HOME/starling/flathub`, decoded with the engine codec). Results
  become `AppRecord`s of kind `flatpak`, so the store's rows, install cluster
  and `pkexec app-install --flatpak` plumbing are reused unchanged; Open goes
  through `app-run --flatpak`. `curl` is now a package dependency.
