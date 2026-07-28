# Handoff — dock app identity

Status: **the app-identity work is done.** Apps are described by the registry
(`registry/catalog.d` + the records `app-install` writes); the launcher, dock
and App Store all read it, and window→app identity comes from
`xdg_toplevel.set_app_id`. See "Apps are data, not code" in `CLAUDE.md`.

What was wrong and is now fixed:

- Running third-party apps got no transient dock icon. `_isAppRunning` fell
  back to a hardcoded table of window-title predicates, which had no entry for
  `intellij` or `gimp` — and could never have worked for IntelliJ, whose
  project window is titled `untitled – Main.java`.
- `wayland_server_on_app_id_changed` was declared in `wayland_server.h`,
  fired from `wayland_xdg_shell.c`, and never registered in
  `WaylandIntegration.swift`, so the one authoritative identity signal was
  discarded. It is registered now.
- Third-party icons came from a two-entry table (`chrome`, `vscode` only), so
  every other installed app showed the neutral glyph.

`build/shell-drive.py`'s stale dock geometry is **fixed** too. It no longer
mirrors the layout at all: `dock NAME` asks the shell over the broker socket
(`dock_rects`) for its real slot centers, so it follows the installed app set
and the transient icons of running apps automatically. `dock ?` prints the
live layout. Verified: the mirror put the launcher 31 logical px (62 physical)
from where it actually was, and every icon shifts by that much again the
moment an app starts.

## Still open

Nothing from this investigation. One loose end noted while testing: a single
dock click during heavy compositing (GIMP mapping two windows) did not
register — a repeat at identical coordinates worked, and glide-then-click
succeeded 4/4 in isolation afterwards, so it is a shell input/compositing
hiccup rather than a targeting problem. Not chased.
