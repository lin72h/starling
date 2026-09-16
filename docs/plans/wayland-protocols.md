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
- `zwlr_output_manager_v1` v4: heads and modes for wlr-randr and kanshi;
  `apply`/`test` answered `failed` until the third batch (below) taught
  them the host scale.
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

## The third batch — the ones that needed a shell feature

Each of these was a protocol the compositor could not answer honestly
until the shell grew something behind it. The shell's side lives in
`shell/Sources/DesktopShellApp/Shell/WaylandFeatures.swift`.

- `ext_workspace_manager_v1`: the shell's user spaces, one group across
  every output, pushed with `wayland_server_set_workspaces` (diffed per
  manager: name, coordinates, state, `removed`, then `done`). A panel's
  activate/remove/create waits for `commit` and reaches the shell as
  `on_workspace_request`; activate is a space switch, create adds a space,
  remove drops one. Fullscreen and agent spaces are the shell's own and
  are not advertised.
- `ext_background_effect_manager_v1` (blur): `wl_region` now keeps the
  rects a client adds (it was a no-op); a blur region is double-buffered
  and reaches the shell on commit as rects, and `DesktopWindow` draws a
  `BackdropFilter` under the content there. A surface with a blur region
  keeps its alpha — shm through `keep_alpha`, dma-buf through a
  `keepsAlpha` flag on the texture that stops the opaque-fourcc import —
  since the effect is only visible through a translucent window.
- `ext_transient_seat_manager_v1`: a `create` makes a fresh `wl_seat`
  global that ALIASES the human seat (own name `seat-transient-N`, same
  input stream); it goes with the object. `wl_seat.name` now comes from
  the seat descriptor rather than its index.
- `zwlr_virtual_pointer_v1` / `zwp_virtual_keyboard_v1`: a pointer frame
  (absolute as fractions of the output, or relative; buttons; wheel) is
  accumulated and handed to the shell, which turns it into host physical
  pixels and calls `fl_drm_view_inject_pointer_abs`, so chrome, chords
  and clients see the mouse. A virtual keyboard brings its own xkb keymap
  and every key is decoded here (evdev code, keysym, text); the shell
  builds a `KeyData` from it and runs it through the same key router as a
  physical key. Verified live: `wtype` typed into the Terminal, a
  virtual click on the dock opened it (`wlrctl`/`wayvnc`-class clients).
- `wp_pointer_warp_v1`: the shell moves the real cursor to the point of
  the surface, only when the pointer is over that surface.
- Drag-and-drop (`wl_data_device.start_drag`) and `xdg_toplevel_drag_v1`:
  a drag owns the pointer; the shell's root listener (the one Listener
  that sees every move, since Flutter keeps a held button on the window it
  went down on) hit-tests the surface under the pointer and steers
  enter/motion/leave/button to the compositor, which turns them into
  data_device events with a minted offer per entered surface, negotiates
  the action (target preference within the source's set), and delivers
  drop → `dnd_drop_performed` → `receive`/`send` → `finish` →
  `dnd_finished`, or `cancelled` when released over nothing or unaccepted.
  The icon surface is a role of its own drawn at the pointer by the popup
  layer; an attached toplevel follows the pointer minus its offset
  (Chrome's tab tear-off). Verified live with gtk4-demo's Drag-and-Drop
  page. **Trap:** GTK binds every `wl_seat` and makes a data device for
  each; the drag's events must go to the device of the seat that is
  dragging (seat 0) — sent to the agent seat's device they are refused
  with `accept(nil)`, which reads as "released, no target".
- wlr-output-management `apply`: a configuration that keeps every head's
  mode, position and transform and changes at most the host's scale is
  accepted; the scale goes to the shell (`on_output_config`), which runs
  the DPI slider's path and answers through
  `wayland_server_output_config_result`. Anything else, or a head left
  unconfigured, fails. `wlr-randr --output primary --scale 1.5` re-renders
  the desktop at 1.5; `wl_output`'s advertised scale is deliberately not
  rebroadcast (the DPI path's contract for Chrome's buffers), so
  `wlr-randr` keeps reporting the startup scale and every requested scale
  is forwarded, equal or not.

## What wmbench says now (2026-09-11, this box)

`benchmark.sh`: every test runs, `stress` included. It did not at first:
the popup load ran at half the rate it asked for and finished last by a
wide margin. The guess was the desktop rebuilding per popup; the log said
otherwise (`STARLING_BUILD_LOG=1`: not one slow rebuild in a run). The
cause was buffer release — a committed buffer came back only when the next
commit replaced it and never when the surface died, so a popup made,
shown once and destroyed per menu cost the client's pool a buffer each
time until every buffer looked busy and it spun on round-trips. shm
buffers now go back the moment their pixels are copied and a dying surface
returns whatever it holds; the popup load holds 20 cycles/s (36 when asked
for 40).

Popups and layer surfaces then got layers of their own (OverlayLayers.swift):
a menu appearing or a bar stepping across the screen rebuilds a widget with
its own State, not the desktop. Under the stress mix the shell's full
rebuilds went from ~60 a second at 3.4 ms each to a few dozen for the whole
run; `move` and `resize` each cost a quarter less CPU, `stress` a third.

The software-client path was then made one pass: the loop thread packs
B,G,R,A rows into R,G,B,A with alpha forced where the role wants it, in one
vectorised C loop, and the texture entry adopts that buffer — it used to be
a memcpy, a per-byte Swift swizzle on the UI thread and a second memcpy.
`video` went from 40 to its 60 fps and a third less CPU; `transparent
window` from 50 to 76 fps at half the CPU. What remains is the GL upload
itself (glTexSubImage2D of every frame); the next step there is a
GBM-backed linear buffer the loop thread writes into, so shm clients take
the same zero-copy import as dma-buf ones.

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

- `wp_linux_drm_syncobj_v1` / explicit sync, `wp_color_management_v1`,
  `wp_fifo_v1` / `wp_commit_timing_v1` — real compositor work each.
- Output configuration beyond the host's scale (modes, positions,
  transforms, disabling an output) — the display layout is the
  hardware's and the shell's settings', not a client's.
- Blur on popups and layer surfaces (windows only today); `wl_region`
  subtraction (no client this desktop runs blurs a subtracted region).
- Drop targets among popups (menus) — windows and layer surfaces only.
- Layer surfaces and screencopy on secondary outputs.
- shm frames still go through glTexSubImage2D; a GBM-backed linear buffer
  would make them zero-copy like dma-buf (see above).
