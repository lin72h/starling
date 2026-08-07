# One clipboard for the whole desktop

Goal: copying in a first-party app pastes into Chrome, and copying in Chrome
pastes into the Text Editor.

This revision replaces an earlier draft whose central premise — "the
compositor's clipboard is complete, nothing joins it to our apps" — turned out
to be half wrong. The compositor's clipboard has a live defect that breaks
third-party paste today, and the transport the draft chose is the most fragile
code in the tree. Both findings are below, with the evidence.

## Where we actually are

Everything in this section was checked against a running session
(`/tmp/xdg-starling-1001`, shell pid from a real GDM login), not just read.

**The unified selection is real and it works — in one direction.**
`wayland_data_device.c` implements `wl_data_device_manager` v3 and
`wayland_data_control.c` implements `zwlr_data_control_manager_v1` v2, and they
genuinely share one protocol-agnostic selection (`server->clipboard`, set
through `wayland_clipboard_set()`, which broadcasts to both). Verified live:

- `wl-copy` → `wl-paste` round-trips. (data-control ↔ data-control)
- A GTK3 client (`wl_data_device`, the protocol Chrome uses) set the selection;
  `wl-paste` read it back. (wl_data_device → data-control) ✅

**But a `wl_data_device` client cannot read a selection that predates it.**
This is a live, shipping bug, and it is the reason to doubt "Chrome↔GIMP works
now". Proven with a mapped, activated GTK3 window (GDK reported
`WindowState.MAXIMIZED|FOCUSED` — which, as Stage 0 explains, is *not* evidence
of keyboard focus here, though it took a round of wrong implementation to
learn):

| order of events | what the GTK client reads |
| --- | --- |
| `wl-copy`, *then* client starts | `None` ❌ |
| client starts, *then* `wl-copy` | the text ✅ |

Root cause, and it is small: `manager_get_data_device`
(`wayland_data_device.c:340`) registers the new device and never sends it the
current selection, and nothing sends the selection on focus either. Only the
change-broadcast from `wayland_clipboard_set()` ever reaches a `wl_data_device`
client. So every client that starts after a copy — which is every browser you
launch after copying a URL — sees an empty clipboard until someone copies again.

**Fixed, and verified end to end** (see Stage 0): with the fix deployed on a real
GDM session, `wl-copy` before Chrome was launched, then Ctrl+V in Chrome's
address bar, pastes the text. Before the fix the same sequence pasted nothing.

The comment at `wayland_data_device.c:76` used to claim the helper was used "on
every set + when a device binds", while it was called from exactly one place,
the broadcast loop — an intention that was never wired. Corrected in Stage 0.

**Primary selection does not work at all.** The earlier draft said all three
protocols share the selection and primary needed only later wiring. In fact
`wayland_primary_selection.c` is an explicit stub — its own header says it
implements "just enough for clients" and does no cross-client transfer — and
data-control's `set_primary_selection` is a documented no-op
(`wayland_data_control.c:211`). Worse, that no-op is justified by a comment
(`:20-22`) claiming "the separate zwp_primary_selection protocol already serves
native primary selection", which is not true. Live check:

```
$ wl-paste --primary
The compositor does not seem to support primary selection
```

Middle-click paste is net-new work, not wiring.

**The first-party apps have their own clipboard, and it is a file.**
`TextEditorApp` (Ctrl+C/Ctrl+V) and `TerminalApp` (Ctrl+Shift+C/Ctrl+Shift+V)
both read and write `$XDG_RUNTIME_DIR/starling-clipboard`. Works between our
apps, nowhere else. Two defects go away when the file does:

- `environment["XDG_RUNTIME_DIR"] ?? "/tmp"` puts the clipboard in
  world-readable `/tmp` at default umask if that variable is ever unset.
  Clipboards carry passwords.
- Truncate-then-write with no locking, so two apps copying at once interleave.

**The framework has no clipboard API**, which is why each app invented one.

## The shape

### Decision: first-party apps talk data-control directly, not through the shell

The earlier draft routed clipboard through the shell's private dma-buf socket:
a new C API, a shell `ClipboardService`, three new messages, and payloads passed
as memfds over `SCM_RIGHTS`. Having read that socket carefully, that is the
wrong road.

**The private socket cannot carry this without surgery on its most dangerous
code.** It does not dispatch on a type header at all — the parent decides what a
message is from `(fd present?, byte count)`:

- `LinuxProcessAppManager.swift:572` treats *any* fd-bearing message of ≥16
  bytes as a resize and reinterprets it as `DmaBufMeta`. An fd-bearing 32-byte
  clipboard event would be fed straight into `reimportDmaBuf`. Adding
  child→parent clipboard fds requires tightening that to `n == 16` first.
- **Parent→child fd passing does not exist in either half.** The parent's
  `ChildSocket.write` is a plain `write(2)` with no `sendmsg`; the child's read
  loop is a plain `read(2)` with no `recvmsg`. The draft's
  `0x0d DMABUF_CLIPBOARD_DATA` is entirely new code on both sides.
- The framing is already unsound: the child discards short reads
  (`GpuDmaBufRenderer.swift:1498`) leaving the stream permanently offset, and the
  parent's 128-byte buffer coalesces a raster-thread frame byte with a
  main-thread event into one garbage struct. The child also writes to the socket
  from two threads with no lock.

**The compositor already implements exactly the protocol we need, and I proved
it works in both roles.** `wl-copy` and `wl-paste` are data-control clients doing
precisely what a first-party app needs: own the selection, and read whoever owns
it. `zwlr_data_control_manager_v1` is focus-free by design, which matters because
our apps are not `xdg_toplevel` clients of their own compositor.

So: **a first-party app opens its own Wayland connection purely for
data-control.** The clipboard code lives once, in the SDK's Starling path — not
in each app.

What this buys:

- **Zero new compositor code** for the app path, and zero new socket messages.
- **The deadlock moves out of the compositor.** This is the decisive argument.
  Wayland's clipboard is pull-based: the owner writes to a pipe when someone
  pastes. If the shell brokered that, a stopped owner (`kill -STOP` on Chrome)
  would block the compositor's event-loop thread and freeze *every window on the
  desktop*. With the app as its own data-control client, a stalled transfer hangs
  **one app**, which is recoverable and local. The draft named this hazard as the
  thing the design is shaped around; this shape removes it rather than managing
  it.
- **The existing fd discipline stays correct.** `wayland_data_device.c:172` and
  `wayland_data_control.c:125` close the compositor's copy of the fd immediately
  after handing it to the owner — right for a protocol source, and a trap for a
  shell-owned one, which would have to `dup()` and write asynchronously. Not our
  problem under this design.
- The child's poll loop already polls three fds
  (`GpuDmaBufRenderer.swift:1435`); the Wayland connection fd is a fourth.

Costs, both small and both real:

- The shell must tell children the socket name. Children inherit the shell's
  environment, which has `XDG_RUNTIME_DIR` but **no `WAYLAND_DISPLAY`** (the
  shell is the compositor). Pass it as a **distinct** variable —
  `STARLING_WAYLAND_DISPLAY` — so nothing else in the child switches backends on
  seeing `WAYLAND_DISPLAY`. The shell already knows the value
  (`WaylandIntegration.socketName`), and it matters that it is dynamic: after an
  unclean exit the next run listens on `wayland-1`.
- libwayland-client becomes a dependency of the Starling path, as the
  `WaylandClipboardBridge` target beside `DmaBufBridge`.

  This plan originally said that target must be kept out of the core `Flutter`
  target and reached through an installed hook, to spare public SDK consumers
  the dependency. That was written before checking `sdk/Package.swift`:
  `flutterDeps` **already** carries `DmaBufBridge`, which hangs gbm, EGL and
  GLESv2 off every Linux consumer. Against that, libwayland-client is noise, and
  the hook would have bought indirection rather than isolation. It is a direct
  dependency. `wlclip_connect()` returns NULL wherever data-control is absent,
  so off Starling it costs a `.so` reference and nothing else.

### Framework — a real `Clipboard`, callback-primitive

Mirror Dart's surface so Flutter documentation keeps applying:

```swift
Clipboard.setData(ClipboardData(text: "…"))
let data = await Clipboard.getData(Clipboard.kTextPlain)
```

**But the callback form is the primitive and `async` is a thin wrapper over
it**, because of a trap worth stating plainly: `DispatchQueue.main` is drained
under the dma-buf child and the Win32 host, but **not under `GTKHost`**, which
runs `gtk_main` and routes ticks through `g_timeout_add`
(`GTKWindowedHost.swift:44`). An `async` API that resumes its continuation on
GCD's main queue would silently never fire under GTK — no error, just a paste
that never returns. Make each host implement the callback correctly and let the
`async` wrapper inherit that.

There is no host abstraction to hang this on: hosts are three unrelated concrete
types plus two global closures in `StarlingAppHost.swift:15-24`. Follow that
existing idiom — a `clipboardProvider` global installed by the platform module —
rather than inventing an interface for three implementors.

Backends: the Starling path gets data-control, `GTKHost` gets `GtkClipboard`,
`Win32Host` gets `OpenClipboard`/`GetClipboardData`. The SDK ships publicly on
Linux and Windows, so a `Clipboard` that only worked inside the Starling shell
would be a stub for every outside consumer.

Then `TextEditorApp` and `TerminalApp` drop their file I/O and call it.

## What is *not* in scope, and why you should know now

The draft's open question — "other apps should follow the editor" — cannot be
answered yet, because there is nothing to follow with. The SDK has **no
`EditableText`, `TextField`, `SelectableText`, or `SelectionArea`**. The only
editable widget is `FluentTextBox` (which `MacosTextField` simply delegates to),
and it has *no selection support at all*: no shift+arrow, no Ctrl+A, no mouse
drag-select, no clipboard keys — its `_handleKey` is a hand-rolled keysym switch.
`RenderEditable` exists at 2592 lines and is dead code; nothing constructs it.
`SelectionRegistrar` has zero conforming types.

So `TextEditorApp` and `TerminalApp` can be wired now — they carry their own
buffers and their own selection. Every *other* surface, including any shell text
field, has no selection to copy from. Giving the desktop a general
"select text anywhere and copy it" is a separate and much larger workstream
(conform a `SelectionRegistrar`, build a real text field on `RenderEditable`).
Name it now so it is not discovered halfway through.

## Staging

**Stage 0 — fix the offer-on-focus bug. DONE.** Independent of everything else,
no SDK work, and it fixes third-party paste for real users today.

`wayland_data_device_offer_on_interaction()` hands a client the current
selection when it starts interacting with a surface, called from **both** the
`WL_PTR_ENTER` and `WL_KB_ENTER` cases in `wayland_server.c`.

Two things about this were not obvious, and cost a full round of wrong
implementation:

- **Keyboard focus here is lazy.** `wl_keyboard.enter` is sent from the *first
  keystroke* (`sendKeyEvent` in `WaylandIntegration.swift`), not when a window is
  focused. Hooking `WL_KB_ENTER` alone therefore does nothing for a mouse-driven
  paste — right-click → Paste would still find an empty clipboard. Pointer enter
  is the trigger that actually fires. (Watch for this generally: a client can be
  focused, decorated and drawing, with xdg_toplevel ACTIVATED set, and still have
  no keyboard focus. `wayland_server_configure_toplevel` sends ACTIVATED
  unconditionally, so GDK reports `FOCUSED` for windows that have never received
  a key — do not infer keyboard focus from it, as an earlier diagnosis here did.)
- **It must not be sent from `get_data_device`.** `wayland_primary_selection.c:119`
  documents that a selection event at device-creation time "crashed every Qt6
  Wayland client", because Qt's handler runs before `QGuiApplication` has built
  its clipboard. Any interaction is comfortably after init.

A per-device `sent_serial` guard keeps it cheap: after the broadcast every device
is already current, so crossing windows with the mouse mints nothing. It fires
once per client per selection — exactly for the client that missed the broadcast.

Also fixed here: the two comments that asserted things the code did not do
(`wayland_data_device.c:76` claimed a bind-time send that never existed;
`wayland_data_control.c:20` claimed zwp_primary_selection served primary).

**Stage 1 — the user-visible goal. DONE.** Framework `Clipboard` (callback
primitive + `async` wrapper) in `sdk/Sources/Flutter/Platform/Clipboard.swift`,
the data-control backend in `sdk/Sources/WaylandClipboardBridge`, the
`STARLING_WAYLAND_DISPLAY` hand-off from the shell, both apps switched off the
file. `text/plain` only, but mime-typed from the start.

The bridge owns a private thread and Wayland connection, so no clipboard
transfer ever touches the app's UI thread, and every transfer is bounded by
`WLCLIP_TIMEOUT_MS`. Two traps handled in it that are easy to miss:

- **Reading our own selection would self-deadlock.** If we own it, the
  compositor answers a paste by asking *us* to write — on the very thread that
  is blocked reading. `wlclip_owns_selection` short-circuits to the local copy.
- **Replacing our own selection races its `cancelled`.** Destroying the old
  source proxy first stops libwayland delivering a `cancelled` that would
  otherwise arrive after we re-took ownership and clear the flag we just set.

Verified on a real GDM session with real Chrome, all four directions plus the
failure mode:

| case | result |
| --- | --- |
| Text Editor copy → `wl-paste` | ✅ |
| `wl-copy` → Text Editor paste | ✅ |
| Text Editor copy → Chrome paste (Chrome started *after* the copy) | ✅ |
| Chrome copy → Text Editor paste | ✅ |
| paste while the owner is `kill -STOP`ped | desktop keeps compositing, editor stays alive, paste degrades to empty, and recovers on `kill -CONT` ✅ |

Note a deliberate regression on Windows: `TerminalApp` used to share a clipboard
file between its own instances there, and now falls back to a process-local
clipboard until Stage 2 lands `Win32Host`'s provider.

**Stage 2 — off-desktop backends. GTK done and verified; Win32 written but never compiled.** So the public
SDK's `Clipboard` is not a stub outside Starling.

`GtkClipboardProvider` (`sdk/Sources/FlutterGTK`) over `flgtk_clipboard.c`,
installed by `GTKWindowedHost.install()`. It calls its completion **directly
from the GtkClipboard callback** — no `DispatchQueue.main` hop, because nothing
drains GCD's main queue under `gtk_main`. This is the case the callback-first
API shape exists for; an `async`-only design would have been silently broken
here.

Verified cross-process under Xvfb with a two-process harness (one owns the
selection, another reads it). Note it could *not* be verified through a
first-party app: `STARLING_APP_GTK=1`, the opt-in GTK build of `TerminalApp`,
has been removed, so nothing shipped links the GTK host any more.

`Win32ClipboardProvider` over `flwin32_clipboard.c` is written and installed by
`Win32WindowedHost.install()`, but **has never been compiled** — the toolchain
lives on the win11 VM and SSH to it refuses the keys on this box. SwiftPM globs
target directories, so that C file *will* be picked up by a Windows build; if it
does not compile, it breaks that build. Verify with
`sdk/tools/build-windows.ps1 -PackagePath sdk`, expecting the documented cold
module-cache failures first.

**Stage 3 — later.** Primary selection (net-new on both protocols, per above),
`image/png`, and the text-field/selection workstream.

Clipboard **persistence after the owner exits** also belongs here, and this is
where the draft's `wayland_server_clipboard_set_bytes` idea comes back — it was
the right primitive attached to the wrong problem. Wayland says the selection
dies with its owner; every desktop cheats by caching. Caching means the
compositor takes over as owner with a built-in source serving a copied buffer,
which is exactly that API. Because the shell would then be a real selection
owner, its `send` must `dup()` the fd (the compositor closes its copy at
`wayland_data_device.c:172`) and write **without blocking the event-loop
thread** — register the fd with the compositor's own loop via
`wl_event_loop_add_fd`, the mechanism already used for deferred input at
`wayland_server.c:142`. Do not reintroduce this before stage 3; it is the one
place the desktop-wide freeze risk comes back.

## Verification

The probes used to diagnose this are the regression tests — all scriptable, no
browser needed.

- **Stage 0 regression, the exact failing case:** set the selection with
  `wl-copy`, *then* start a `wl_data_device` client, and assert it reads the
  text. A ~20-line GTK3 Python client (`Gtk.Clipboard.request_text`) is enough;
  `python3-gi` is present on the box. Assert the ordering both ways — the
  "client first" case already passes and must keep passing.
- **Cross-protocol, both directions:** GTK owner → `wl-paste`, and `wl-copy` →
  GTK reader.
- **Primary selection:** currently must fail with "does not seem to support
  primary selection"; flip the assertion when stage 3 lands.
- **Unit (`test/run.sh`):** serial invalidation, mime negotiation, empty and
  oversized payloads.
- **Functional (`sudo test/run.sh --functional`):** copy in Terminal → paste in
  Text Editor and the reverse, driven through the semantics-tree agent the
  harness already has.
- **Hang regression:** `kill -STOP` the selection owner, then paste. Assert the
  desktop keeps compositing *and* that only the pasting app stalls. This is the
  failure the architecture is chosen for, so it needs the test that would catch a
  regression back to shell-brokered transfer.
- **VM gate** before release: this changes the shipped shell, and stage 1 adds an
  env hand-off on the app-launch path — exactly the kind of privilege/session
  difference `CLAUDE.md` says the dev box hides.

One caution on testing this on the dev box: **the session runs unprivileged as
uid 1001**, and the clipboard socket is chowned to the runtime dir's owner by a
`getuid() == 0`-gated block (`WaylandIntegration.swift:245`). That is a
dev-vs-shipping privilege split of the kind that has burned this project before;
exercise the unprivileged path.

## Open question

**Shortcuts.** Ctrl+C in the editor, Ctrl+Shift+C in the terminal. The split is
correct — the terminal needs Ctrl+C for SIGINT — but it should be a decision
rather than an accident, and it needs an owner once there is a general text field
to apply it to.
