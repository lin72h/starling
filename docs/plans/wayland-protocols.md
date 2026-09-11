# Wayland protocols — the compositor speaks the ecosystem's language

Branch `wayland-protocols`, cut from `main` 2026-09-10. Goal: every protocol a
Wayland desktop is measured on, starting with the set
[wmbench](https://github.com/fulalas/wmbench/) probes, and the ones the
wlroots ecosystem's tools (grim, taskbars, idle daemons, clipboard managers)
bind to.

## What wmbench asks for, and where we stand

wmbench's Wayland backend (`lib/win_wl.c`) opens every window through one of
these and reports a test "not done" where the protocol is missing:

| protocol | what it gives wmbench | status |
| --- | --- | --- |
| `zwlr_layer_shell_v1` v5 | a window at a screen coordinate; every placed and photographed window | **new** — `wayland_layer_shell.c`, drawn by `LayerSurfaces.swift` |
| `xx_zone_manager_v1` (experimental) | placing managed toplevels, positions reported back | **new** — `wayland_zones.c`; nobody else ships it yet |
| `xdg_activation_v1` | raising its own windows | was a no-op; now honours minted tokens and raises |
| `wp_alpha_modifier_v1` | whole-window opacity (`transbench`, the stress mix) | **new** — `wayland_alpha_modifier.c`, an `Opacity` around the content |
| `xdg_wm_base` maximize / minimize / fullscreen states | the `windows` test reads states back from configures | maximize/minimize were stubs and every configure said MAXIMIZED; the shell now owns the state bits (`wayland_server_set_toplevel_state`) and configures carry them |
| `zxdg_decoration_manager_v1` | a server-side frame | had it |
| `zwlr_foreign_toplevel_manager_v1` v3 | what a taskbar knows; unminimise | **new** — `wayland_foreign_toplevel.c`, with `ext_foreign_toplevel_list_v1` beside it |
| `zwlr_screencopy_manager_v1` v3 | not probed directly: `grim`, the screenshot tool `validate.sh` needs for every pixel check | **new** — `wayland_screencopy.c`; pixels come from the engine's presented-frame mirror |

## The state model

Window state — maximized, fullscreen, minimized, focused — is the SHELL's.
The compositor records the bits the shell pushes, puts them into every
`xdg_toplevel.configure`, and reports them through foreign-toplevel handles.
A client asking for a change (its own `set_maximized`, a taskbar's
`unset_minimized`, an activation) arrives as `on_toplevel_request`; the shell
applies its policy and pushes the outcome, and the next configure is the
answer — a refusal included, because a client reads the state from the
configure, as xdg-shell says to.

`ACTIVATED` is still sent unconditionally in configures, on purpose:
keyboard focus is lazy here (`wl_keyboard.enter` rides the first keystroke)
and agent-owned windows take injected input while a human's window has the
focus; Chromium drops keys for a window it believes inactive, so the honest
bit would break exactly those. Foreign-toplevel handles report the real one.

The shell pushes the bits right before every configure (`stateProvider` in
`WaylandIntegration`) and once per build for everything (focus, minimize),
diff-guarded; a steady desktop sends nothing.

## Layer shell placement

`wayland_layer_shell.c` validates, keeps the double-buffered state, and
answers the initial commit with a configure of the anchored size. Placement
is the shell's (`LayerSurfaces.swift`): position from anchor + margins and
the buffer the client ACTUALLY committed, drawn in one of four groups of
the desktop stack — background and bottom under the windows, top above the
windows and their menus, overlay above the bars and dock. Popups parented to
a layer surface are positioned from it and drawn with its group.

Exclusive zones feed `WindowManager.layerInsets`: a maximized window stops
at a third-party bar as it stops at the dock. Keyboard interactivity:
`exclusive` takes every key while mapped; `on_demand` takes it after a
click, and a click on a window takes it back.

Limits, as of this writing: layer surfaces are drawn on the host output
only (the secondary outputs' views have no layer pass); exclusive zones are
reported, not arranged (a second bar on the same edge overlaps the first).

## Screencopy

The engine keeps a CPU mirror of the presented desktop for the X server's
`GetImage`; `fl_drm_view_arm_capture` makes the next few presents refill
it. A screencopy request arms it, rides the shell's frame pump (so an idle
desktop still presents), waits for the arm's countdown to run out — the
mirror is then a frame made AFTER the request — and copies the region into
the client's `wl_shm` buffer on the event-loop thread. Host output only;
the cursor is a hardware plane and not in the frame. `grim` works with it,
so `validate.sh`'s pixel checks run.

## The rest of the batch

Small protocols that cost a few lines each and stop a toolkit from taking
its "no support" branch (`wayland_misc_protocols.c` and friends):
`wp_single_pixel_buffer_manager_v1`, `wp_content_type_manager_v1`,
`wp_tearing_control_manager_v1`, `xdg_toplevel_tag_manager_v1`,
`xdg_wm_dialog_v1`, `xdg_system_bell_v1`, `xdg_toplevel_icon_manager_v1`,
`zwp_keyboard_shortcuts_inhibit_manager_v1` (granted, and the shell routes
every key to an inhibited surface), `zwp_pointer_gestures_v1`,
`zwp_tablet_manager_v2`, `ext_data_control_manager_v1` (the standardised
wlr-data-control, sharing the one clipboard), `ext_idle_notifier_v1` v2.
Versions raised: `wl_compositor` 6, `wl_seat` 9, `wl_shm` 2,
`xdg_wm_base` 7 (with `wm_capabilities`).

Bindings are regenerated by `shell/protocols/regen.sh`; the XMLs Ubuntu
ships no package for are vendored beside it.

## The second batch

- `ext_image_copy_capture_v1` + `ext_output_image_capture_source_manager_v1`:
  the standardised screencopy (grim 1.5+, wf-recorder, OBS), sharing the
  wlr module's frame list and the same shell readback.
- `wp_security_context_manager_v1`: a sandbox's listening socket adopted;
  clients arriving through it are tagged and `wl_global_set_filter` hides
  the privileged globals (capture, clipboard managers, layer shell, the
  taskbar lists, output configuration, zones, idle, shortcuts inhibit,
  and the protocol itself) from them.
- `zwlr_output_manager_v1` v4, read-only: heads and modes for wlr-randr
  and kanshi; `apply`/`test` answer `failed` rather than pretending.
- `zxdg_exporter_v2` / `zxdg_importer_v2`: the handle handshake portals
  use to parent a dialog; `set_parent_of` is recorded nowhere yet.
- `wp_color_representation_manager_v1`: premultiplied RGB is the one
  encoding offered; anything else gets the protocol's error.
- `ext_session_lock_manager_v1`: swaylock, gtklock, hyprlock. A lock
  surface is lent to the layer machinery (overlay, anchored to every edge,
  exclusive keyboard, namespace "session-lock"), and while locked the shell
  draws black plus those surfaces and swallows every key. A locker that
  dies leaves the session locked — the protocol's rule — and the next lock
  request takes over; on the dev box that means restarting the shell.

Verified against real clients on this box: `grim` (screencopy),
`wlr-randr` (output management), `wl-copy`/`wl-paste` (data control),
`swaylock -c 336699` (session lock: the output is the lock colour edge to
edge, the desktop nowhere).

## What wmbench says now (2026-09-11, this box)

`benchmark.sh`: every test runs. `stress` is reported failed because its
popup load finished last by a wide margin — the compositor shows and hides
popups at ~7 cycles/s against the 20 the load asks for, and the other five
loads had finished. That is the shell rebuilding the whole desktop tree on
every popup appearance, not a protocol gap; `popups` alone runs at ~14.
The shm paths are the other cost worth a look: `video` (60 shm frames/s)
and `transparent window` (120 redraws/s) each burn about a core, in the
per-commit copy + swizzle + texture upload.

`validate.sh`: motion, stale, pop, resize, offscreen and iconify pass, and
the stability pass with them. suspend and iconify put their pattern window
fullscreen and expect it at the output's corner, which is what made
fullscreen cover the whole output (it used to leave the 28 px status strip
and a black bar); suspend then reports "not done", because Wayland has no
compositing suspension to prove. shape and leftovers cannot exist on
Wayland.

Seen once and not reproduced: on a shell started seconds before the run,
the checks passed for a minute and then every layer surface stopped being
drawn for the rest of that process — screenshots showed a live clock and
no windows. A fresh shell went through the whole suite twice without it.
The screencopy path now logs a capture that waited out its deadline, so
the next time it happens the log says whether the frame was old or the
window undrawn.

## Tests

`test/wayland/run.sh` links the C server, connects a client in the same
process and drives every protocol above end to end — no GPU, no display —
in the fast tier (`test/run.sh`). wmbench itself is the functional check:
`./benchmark.sh` and `./validate.sh` against a live desktop.

## Not done

- `zwlr_virtual_pointer_v1` / `zwp_virtual_keyboard_v1`,
  `ext_workspace_v1`, `xdg_toplevel_drag_v1`, `wp_pointer_warp_v1` — each
  needs a shell feature behind it (input injection at screen coordinates,
  spaces as workspaces, a tear-off drag, cursor warping).
- `wp_linux_drm_syncobj_v1` / explicit sync, `wp_color_management_v1`,
  `wp_fifo_v1` / `wp_commit_timing_v1` — real compositor work each.
- Applying an output configuration through wlr-output-management.
- Layer surfaces and screencopy on secondary outputs.
- Popup show/hide throughput (see above).
