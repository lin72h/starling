# Multi-output — one virtual desktop, N panels

Goal: a second monitor that is a full member of the desktop, not a wallpaper
with windows on it. Today it is most of the way there for *windows* and almost
nowhere for *chrome and spaces*, and this doc is about closing that second gap.

The arrangement is already settled and is not in question here: outputs are
placed in one global logical coordinate space (`DisplayLayout`), each with its
own scale, and a window's rect is virtual-desktop coordinates. Everything below
assumes that.

## Where we are

**Built and working.** The engine enumerates outputs, gives each a Flutter view
(the primary is the implicit view 0), and rebuilds pointer regions on hotplug so
clicks route to the right view in view-local coordinates. `DisplayLayout` owns
the arrangement; `SecondaryOutputScreen` renders each non-primary output's
wallpaper, menu bar and the windows intersecting it; `wl_output` enter/leave
tracks which outputs a surface straddles; unplugging brings stranded windows
home.

**Window geometry is already per-output**, which is easy to miss because the
call sites still take `screenWidth`/`screenHeight` parameters. They are a
fallback for the non-DRM dev paths only: `_outputFillRect` resolves the *owning*
output from the window's own rect (`WindowManager.swift:639`), so maximize and
fullscreen fill the monitor the window is on, and `retile` groups windows by
owning output and tiles each independently (`WindowManager.swift:766`).

**Window chrome is per-output as of `1ee803b`.** The traffic lights, the
title-bar double-click, and the fullscreen title-bar reveal all work on a
secondary monitor. Before that the secondary passed three callbacks out of
seven and every button on it was inert. `test/lint.py`'s `window-chrome` check
now compares the two trees so this cannot drift again.

**Deliberately primary-only.** The dock. macOS has one dock and so do we; this
is not a gap. (The menu bar is per-display in macOS, and ours already is.)

**Workspace mode and the launcher follow the pointer** as of staging step 1
below: both open on the monitor they were invoked from.

**Not migrated, and the subject of this doc.** The space model, Mission
Control, the desktop context menu, and the screensaver overlay (see `screensaver.md`, which already flags its own). Concretely, on a
second monitor today you cannot right-click the desktop — the primary wraps its
wallpaper in a `Listener` that opens the context menu, and
`SecondaryOutputScreen._wallpaper()` returns a bare `TextureWidget` with no
listener at all. And an animated wallpaper preset plays on the primary while
the secondary falls back to `.slate`, because the secondary reads only
`sharedWallpaperTextureId`, which is the still-image path.

## The one that blocks the rest: a space is global

`activeSpaceIndex` is a single `Int` on `WindowManager` (`WindowManager.swift:256`).
`SpaceInfo` is `id` plus `kind` and nothing else (`:158`). `WindowInfo.spaceId`
is a flat tag. Nothing anywhere associates a space, or a window's membership in
one, with an output.

So every output renders the same active space, because
`SecondaryOutputScreen._windows()` draws `wm.visibleWindows`, which is
`visibleWindows(inSpaceId: activeSpace.id)`. Verified live on a two-output
layout: a window sitting on the second monitor **disappears from it** when you
switch spaces on the first, and comes back when you switch back. Same for
entering workspace mode, which is just another space.

This is exactly macOS with *"Displays have separate Spaces"* switched **off**.
The behaviour is self-consistent and not a bug; it is simply the option we
never implemented, and it is the reason workspace mode cannot appear on a
second monitor.

There is a second, smaller consequence hiding behind it. The space-switch slide
(`slideLayers`, `DesktopShell.swift:2660`) offsets layers by multiples of
`screenWidth` and is rendered only in the primary tree. A secondary output has
no `dx` term at all, so it should snap to the new space instantly while the
primary animates for 380ms. Read from the code, not observed — worth confirming
with a mid-slide capture before fixing.

## Design: per-output active space

The model change is small and the fan-out is not.

```
   WindowManager
-  var activeSpaceIndex: Int
+  var activeSpaceByOutput: [Int: Int]      // outputId -> spaceId
+  var activeSpace(onOutput:) -> SpaceInfo
+  var activeSpace: SpaceInfo               // primary's, as the N=1 default
```

Keeping a primary-flavoured `activeSpace` is what makes this stageable: at N=1
it is the only entry and every existing caller keeps working unchanged.

What has to become output-scoped, and why each is not mechanical:

- **`visibleWindows`** — the secondary already asks for a space's windows, it
  just asks for the wrong one. Cheapest part.
- **`focusTopmostInActiveSpace`** — focus is global (one `focusedWindowId`) but
  the candidate set is now per-output. Which output's topmost wins when the
  active space changes on one of them? Proposal: focus follows the output that
  changed.
- **Window placement.** A new window picks a space today by implication —
  there is only one. With per-output spaces it must choose, and the honest
  answer is "the active space of the output the window is opening on", which
  `WindowManager.swift:461` already gestures at by offsetting new windows from
  `displayLayout.primary.origin`.
- **`_switchToSpace`** — takes an output, and only that output slides.
- **Edge-drag carry** (`_checkEdgeCarry`) — currently arms when the pointer hits
  `0` or `screenWidth`. Those are the *primary's* edges; on a multi-output
  desktop the meaningful edges are the virtual desktop's outer boundary, since
  an inner edge is a seam the pointer crosses onto the next monitor.
- **Mission Control** — one strip of spaces today. Per-output spaces means
  either a strip per display, or an overview that shows the strip for the
  display it was invoked from. The latter is less work and probably righter.

## Workspace mode on the invoking output

Workspace mode is a space, so it inherits all of the above. But it has one
problem of its own that the space work does not solve, and it is worth stating
because it rules out the obvious answer.

`_applyWorkspaceWindowGeometry` (`WorkspaceSpace.swift:360`) does not lay out a
picture. It sets each owned window's `rect` and calls `onContentResize`, which
configures the real Wayland/DMA-BUF client to the pane's size. A client has one
buffer size. Two outputs of different sizes want two different pane sizes, so
**the same workspace cannot be shown on both monitors** — not as a rendering
limitation but because the windows in it would have to be two sizes at once.

That leaves two coherent options, and only one is cheap:

- **Move it** — workspace mode opens on the output you invoked it from; the
  others keep their desktops. Needs only that `_buildWorkspaceSpace` and
  `_applyWorkspaceWindowGeometry` take an output instead of reading
  `screenWidth`/`screenHeight`, which are hardwired to `dl.primary`
  (`DesktopShell.swift:214`). One workspace, one output, one client size. This
  is buildable today, ahead of the space work, and is the recommendation.
- **A workspace per output** — each monitor runs its own workspace with its own
  driver and tabs. Coherent, genuinely useful with two large displays, and
  needs the full per-output space model first.

Mirroring the same workspace onto both is not on the list. A letterboxed copy
would be the only honest version and nobody wants it.

## Staging

1. ~~**Workspace mode on the invoking output.**~~ **Done.**
   `_buildWorkspaceSpace(output:)` and `_applyWorkspaceWindowGeometry(output:)`
   take an output; `_workspaceOutputId` records which monitor the pointer was
   over at toggle time, and whichever screen owns it draws it. The launcher
   came along for the ride — the workspace's `+` opens it, and an app picker
   that lands on a different monitor from the thing that asked for it is worse
   than no support at all, so it has a `_launcherOutputId` and the same
   treatment. Every call site now goes through `openLauncher()`.

   Two things fell out worth remembering. The shared divider position had to be
   clamped per output (`_workspaceDriverWidth(forOutputWidth:)`), or a narrow
   monitor collapses the tab column. And the secondary's signature gate is
   bypassed while it hosts an overlay, because the workspace has far more state
   than a signature can summarise — but the bypass is edge-blind on the way
   out, so `ovl:` is in the signature too. Without it a closed launcher stayed
   painted on the secondary, which is exactly how it was found.
2. **The rest of the secondary's desktop chrome**: right-click context menu on
   the wallpaper, and the animated wallpaper preset rather than the `.slate`
   fallback. Small, independent, removes the "it's just a picture" feel.
3. **`activeSpaceByOutput`**, with the primary entry as the compatibility
   default and every existing caller reading through it. Behaviour identical at
   N=1; at N>1 the secondary starts rendering its own space.
4. **Per-output `_switchToSpace` and slide**, including a `dx` term in
   `SecondaryOutputScreen`. Confirm the snap-vs-slide asymmetry first so there
   is a before to compare against.
5. **Mission Control per display**, invoked-output-scoped.
6. **A workspace per output**, if (1) proves it earns the depth.

## Decisions still open

- **Does the active space follow the pointer or the focused window?** macOS
  uses the pointer for "which display am I acting on". Ours has no such notion
  yet and would need one for steps 1, 4 and 5 to feel consistent with each
  other.
- **Where does a launcher launch land** when the launcher is invoked on a
  monitor whose active space differs from the primary's? Almost certainly the
  invoking output's space, but it interacts with the workspace carve-out in
  `_launchFromLauncher`, which already has a "we are in a workspace" branch.
- **Should the space *set* be shared or per-output?** Sharing the list and
  making only the active index per-output (proposed above) is far less
  disruptive, and matches macOS, where a space belongs to a display but the
  numbering is global. The alternative — a genuinely independent list per
  display — makes hotplug ugly: unplugging has to rehome not just windows but
  whole spaces.
- **Hotplug.** When an output appears, which space does it show? The primary's
  is the safe answer, and the layout code already has the "windows come home"
  precedent to follow when one disappears.
