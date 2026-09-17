# The 3D desktop — the wallpaper becomes a place, apps float in it

Goal: the desktop stays **2D by default**. Turning 3D on builds a **3D scene
out of the current wallpaper** and lifts every app window off the plane into
it, floating in front of the user the way windows float in visionOS: each one
a live texture on a pane of glass, facing the viewer, lit and shadowed by the
scene behind it. Turning 3D off folds the scene back into the flat wallpaper
and the windows settle back onto their 2D rectangles.

Branch: `desktop-3d`. **Phases 0 and 1 are built and verified on the dev
box (2026-09-16)** — see the results under each phase. This note records what the
tree already gives us, what has been tried before and why it failed, the
design that avoids those failures, and the spike that proves the primitive.

## Prior art, and why every one of them was an effect

| What | Year | Why it did not stick |
|---|---|---|
| Sun Project Looking Glass | 2003 | Windows as 3D objects (flip to write on the back). Every window was perspective-sampled, so text was blurry everywhere. Java3D over X was too slow to live in. |
| Compiz cube / Flip 3D / KWin cube | 2006–08 | 3D only *while switching*. The working state was flat, so the geometry meant nothing and remembered nothing. |
| BumpTop | 2007 | A physics desk for icons, not app windows. |
| Fuchsia Scenic (Mozart) | 2016 | A real 3D scene graph with lighting and shadows under every window. Flattened to 2D within a few years: the cost bought nothing a flat UI needed. |
| visionOS, SimulaVR, Stardust XR | 2019– | Windows as live glass panes in an environment. This is the target feel, and it exists only through a headset: the environment *is* the display. |

Three lessons carry:

1. **Perspective-sampled text is unusable.** The window in front of the user
   must be drawn at 1:1 device pixels, square to the camera. The scene is for
   everything else.
2. **A 3D that only appears during transitions is decoration.** The 3D
   placement must be persistent state the user arranged, and every view must
   be a camera pose over that state.
3. **The environment has to come from somewhere the user already chose.**
   visionOS ships hand-built environments; a desktop cannot. The wallpaper
   is the one image every user has already picked, so the scene is generated
   from it. That is the idea nobody has done on a monitor.

## What the tree already does

Check these before believing the rest:

- **Every window is already a texture in the shell's layer tree.**
  `DesktopWindow` draws its app as a `TextureWidget` (a DMA-BUF import on
  Linux) and already wraps it in a `Transform` — a Y flip today
  (`shell/…/Window/DesktopWindow.swift:22`). Mission Control scales the same
  live textures into cards through another `Transform`
  (`shell/…/Shell/MissionControl.swift:140`). A 3D pose is a different
  matrix in the same slot.
- **The whole 4x4 reaches the engine.** `SceneBuilder.pushTransform` takes
  16 doubles (`sdk/Sources/FlutterSwiftBridge/Compositing.swift:528`), the
  engine's `TransformLayer` carries a `DlMatrix`, and an external texture is
  painted with `DrawImageRect` under whatever canvas matrix is current
  (`engine/…/embedder/embedder_external_texture_gl.cc:69`). Skia rasterises
  a perspective quad from that. No engine change is needed to draw a window
  in 3D.
- **Hit-testing through perspective is ported, not approximated.**
  `RenderTransform.hitTestChildren` goes through `addWithPaintTransform`
  (`sdk/…/Rendering/ProxyBox.swift:4001`) and `MatrixUtils.transformPoint`
  does the homogeneous divide (`sdk/…/Painting/MatrixUtils.swift:147`). A
  `Listener` under a perspective `Transform` gets `localPosition` in the
  window's own space, which is exactly what `DesktopWindow` forwards to the
  client. A tilted browser is clickable at the right pixel with no new input
  code.
- **The wallpaper is one GL texture, and the shell already knows how to
  render into a texture on the raster thread.** `_loadWallpaperTexture`
  decodes the JPEG and uploads RGBA to a registered texture id
  (`shell/…/Shell/DesktopShell.swift:1464`); `makeWallpaper` composites it
  as a `TextureWidget` (`:3790`). Separately, `GLRenderer.renderToTexture`
  is called from the external-texture callback on the raster thread with
  the engine's EGL context current
  (`shell/…/Compositor/LinuxTextureRegistry.swift:539`), and every imported
  window is an ordinary `GL_TEXTURE_2D` name in that same context (`:515`).
  An environment renderer is a `GLRenderer`-shaped class behind the
  wallpaper's texture id. Nothing new has to be wired.
- **Window state is one struct.** `WindowInfo.rect` + `zIndex` is the flat
  pose (`shell/…/Shell/WindowManager.swift:20`). The 3D pose is a few more
  numbers beside it, and both are kept.
- **The chrome already reads the wallpaper.** `shellMica` is the
  wallpaper's average colour and the theme is a function of it
  (`DesktopShell.swift:1513`). Per-window lighting from the scene is the same
  idea, sampled locally.

## The design

### Two states, both persistent

```
   2D (default)                          3D
   ┌──────────────────────────┐          ┌──────────────────────────────┐
   │  flat wallpaper          │          │   environment built from     │
   │  ┌──────┐ ┌────────┐     │  toggle  │   the wallpaper (depth,      │
   │  │      │ │        │     │ ───────▶ │   wrap, floor, light)        │
   │  │      │ └────────┘     │ ◀─────── │     ╱‾‾╲   ╔══════╗   ╱‾‾╲   │
   │  └──────┘  ┌────┐        │          │    │ app │  ║ app  ║  │ app │  │
   │            └────┘        │          │     ╲__╱   ╚══════╝   ╲__╱   │
   └──────────────────────────┘          └──────────────────────────────┘
   WindowInfo.rect is truth                WindowInfo.pose is truth
```

Each window carries both a 2D `rect` and a 3D `pose` (position on the arc,
distance, yaw). Switching modes animates between them and never overwrites
one with the other, so leaving 3D puts every window back exactly where it
was, and re-entering finds the arrangement the user made in the scene.

### The environment, generated from the wallpaper

Three tiers. Each is a strict improvement on the one below and each
degrades to it when its input is missing, so the feature ships at tier 0
and gets better without changing shape.

**Tier 0 — the alcove.** The wallpaper hangs on the far wall of a box,
filling about two thirds of the view; the floor, ceiling and two side
walls grow out of its four edges and come toward the viewer, carrying the
picture's own colours mirrored forward, blurred, and falling into the
dark as they arrive. The floor is the wallpaper's lower band reflected: a
wet floor the windows will stand over. Panning the eye produces parallax
between the near floor and the far wall. Works for any still, and is all
a video wallpaper (`AerialPlayer`) will ever get.

This started as a **wrap** — the wallpaper on a cylinder segment of about
120° around the camera — and that does not work on a monitor: a cylinder
centred on the eye is the same distance away everywhere, so it has no
depth to show, and the part that curves is off the edges of the screen
anyway. A headset gets away with it because the environment *is* the
display and you turn your head. See Phase 1.5.

**Tier 1 — depth.** A depth map turns the wall into a relief: a 256×135
grid displaced in the vertex shader by the depth texture, so a camera move
separates the bridge towers from the sky. Depth maps for the **bundled**
wallpapers are precomputed and checked in beside the JPEG
(`golden-gate-dark.depth.png`), so the shipped desktop needs no model at
all. For a user-supplied wallpaper, an optional helper
(`starling-wallpaper-depth`, monocular depth such as Depth Anything V2
small through ONNX Runtime on the CPU, seconds per image) writes the depth
map next to the cached crop *at wallpaper-set time*, never in the shell
process. No helper installed means tier 0 for that image.

**Tier 2 — layers.** Thresholding the depth map gives sky / ground /
subject layers. A window pushed far enough back slides *behind* the
subject: the browser goes behind the bridge tower. Speculative, and only
worth it once tiers 0–1 have shown people leave windows in the scene.

Whatever the tier, the environment renders as **one texture** in the
wallpaper's slot: the raster-thread callback draws the scene from the
camera the platform thread last published (the same mailbox pattern
`GLRenderer.advanceAnimation` uses today), into an FBO with a depth buffer.
Window *shadows* and floor *reflections* are drawn there too — the renderer
is handed each window's pose and its GL texture name, both already in that
context — so a window visibly rests in the scene rather than being pasted
over it.

### The windows, visionOS-style

Windows are **not** in the GL scene. They stay in the Flutter layer tree,
above the environment texture, each wrapped in `Transform(projection · view
· pose)`. That keeps input free (see above), keeps the chrome, dock and
menu bar crisp, and needs no depth test between windows because they never
intersect: they sit on an arc, facing the camera, at distinct positions.

- **The arc.** Poses live on a cylinder around the viewer at a comfortable
  distance; a window faces the camera wherever it is on the arc. Moving a
  window slides it along the arc and it re-orients on its own. Scrolling on
  its title bar pushes it away or pulls it closer. Minimise puts it on the
  floor, small, still live.
- **The crispness rule.** The focused window is drawn with its `Transform`
  *skipped* — not near-identity, skipped — at 1:1 device pixels, square to
  the camera, at the arc's front. A 0.999 scale resamples text; identity
  does not. Everything else is perspective-sampled with
  `FilterQuality.medium` (Mission Control's lesson: `.low` aliases when
  minifying). Imported textures have no mip chain, so `.medium` makes Skia
  copy into a mipmapped texture per frame per window; the spike measures
  that, and the fix if it costs is to build mips once per client commit in
  the texture callback.
- **Glass.** The window material's tint comes from the scene behind the
  window: the environment renderer writes a low-resolution "light" buffer
  the platform thread reads back once per pose change, and
  `windowGlassTint` is resolved per window instead of once from the
  wallpaper average. Fluent's Mica is the same idea already
  (`shellMica`), so the plumbing exists.
- **Parallax from the pointer.** With no headset there is no head tracking,
  so the camera borrows a degree or two of yaw and pitch from the pointer's
  position on screen (the Apple TV / iOS lock-screen trick). It is what
  makes depth *legible* on a monitor: as the pointer crosses the screen the
  floor slides against the wall and the far windows against the near ones.
  Off when a window is being dragged, so drags stay predictable.

### Entering and leaving

Entering: the flat wallpaper *becomes* the scene. The camera pulls back
into the picture as the wrap and floor unfold from it; the windows lift off
the plane and glide to their arc poses (first time: an arc layout derived
from their 2D rects, so nothing jumps). Leaving is the reverse. Both are
one camera path plus one pose tween per window, on the same
`AnimationController` pattern as `OpenAnimations.swift`, ~600 ms.

The toggle is a real mode beside Mission Control: the desktop context menu,
the control centre, and a chord. It is a per-desktop setting that persists
across sessions.

### Other views become camera moves

Once poses are state, the views the shell already has stop re-laying-out
and start moving the camera over unchanged poses:

- **Mission Control** dollies back. The overview is the user's own
  arrangement seen from further away, so spatial memory survives it.
- **Spaces** are regions along the panorama; a space switch pans the camera.
  The slide layers become a camera path.
- **Open / close** approach and recede along z instead of the scale zoom.

## Phases

### Phase 0 — the spike (prove the primitive)

A hidden chord in `DesktopShell` that lifts every *unfocused* window onto an
arc: in the window-stack builder (`DesktopShell.swift:3915` onward) wrap the
`Positioned` child in a `Transform` with `setEntry(3, 2, -1 / focal)`, a yaw
toward the centre and a push-back, aligned on the screen centre. The focused
window is untouched. The flat wallpaper stays. About 150 lines.

It passes when, on the DRM desktop with a real Wayland client in a tilted
slot (Chrome is the honest test: hover effects, text, scroll):

1. the tilted window composites (Skia perspective on an external texture);
2. hover moves the client's own cursor feedback to the right element;
3. a click lands on the right pixel;
4. text in the tilted window reads at `.medium`, and frame time with four
   tilted windows is measured against the flat baseline;
5. a title-bar drag on a tilted window moves it sensibly. It will not:
   `onMove` deltas are screen-space and the tilt changes the ratio. Fix by
   unprojecting the delta through the pose's inverse in `DesktopWindow`;
   the spike decides whether Stage needs it or only free placement does.

Run it on the Linux dev box, not the Mac: the macOS shell has not been
built since 0.2 and its texture path is Metal/IOSurface. The layer and
hit-test code are shared, so a macOS run proves less than it costs.

#### Results (2026-09-16, dev box, eDP 2560x1600 @ scale 2)

What landed: `Shell/Desktop3D.swift` (the pose: focal 1.5 × screen width,
yaw up to 35° toward the centre, pushed back to 0.7×, near-plane guard on
the four corners), the window-stack builder wraps every window's slot in a
`Transform` (identity when flat — it takes RenderTransform's plain
translation paint path, so a flat window is not resampled; always present
so the slot's widget TYPE never changes on focus, which would remount the
subtree), `DesktopWindow` samples the client texture at `.medium` only when
tilted, and three ways in: Ctrl+Shift+3, the broker op
`{"op":"desktop_3d","on":true|false}` (unauthenticated, for tooling), and
`STARLING_3D_SPIKE=1` to start in it. The scene: Chrome ×2 (Wayland
dma-buf), weston-terminal (wl_shm), Calculator (first-party), tiled.

1. **Composites.** Skia draws the imported external texture through the
   perspective matrix; chrome, shadow and border tilt with it. Both buffer
   paths (dma-buf and wl_shm) and the first-party child app render.
2. **Hover reaches the right element.** Hovering one screen point over the
   tilted Chrome lit the cell under it and Chrome reported page coordinates
   inside that cell; the same point unprojected differently from the flat
   layout, exactly as the tilt predicts.
3. **A click lands on the right pixel.** Clicking that same point selected
   the same cell (Chrome painted it green after it came forward and
   flattened). `RenderTransform.hitTestChildren`'s homogeneous divide is
   correct as ported; no input code was touched.
4. **Text reads at `.medium`.** Cell labels in a tilted window minified to
   ~0.6× stay legible. Cost, same pointer sweep with 3 tilted windows
   (one a 2560x1460 texture) vs flat, `STARLING_FRAME_LOG=1`: UI thread
   per frame 0.34 → 0.39 ms median (noise); raster thread 5% → 9% of a
   core over the sweep (~0.4 → 0.7 ms per hover frame). No mip cache was
   built; at this cost it is not needed yet. GPU time was not measured.
5. **Drag: the premise does not arise.** A press on a tilted window brings
   it to front, which focuses it, which flattens it on the same frame — so
   no window is ever dragged while tilted. The local-space delta fix was
   tried and is WRONG for this design: the framework freezes the hit-test
   transform at pointer-down for the whole gesture, so with the window
   already flat the unprojected deltas overshoot by 1/scale (measured: the
   window moved 1.43× the pointer). Screen-space deltas (unchanged code)
   are right. A window that stays posed while dragged is Phase 1's arc
   drag, and it has to keep the pose through the press for either fix to
   apply.

Also learned, none of it 3D's fault:

- Chrome opens at the full work area on a 1280x800 logical screen (its own
  small-display default; `--window-size` is ignored on Wayland), and
  weston-terminal did the same, so every new window stacked at one pose.
  Tiling is the quick way to a spread-out scene for tests.
- `app-run chrome` on `main` still passes `--force-device-scale-factor`
  and draws Chrome at 2× (dpr 4); the fix lives on `computer-use`.
  `STARLING_APP_SCALE=1` neutralises it for a test.
- The broker has no read-back for the mode; the op without `on` toggles.

### Phase 1 — tier 0 environment, and the mode

- `WindowInfo` gains `pose`; `rect` stays. A `Camera` per output.
- `EnvironmentRenderer` beside `GLRenderer`, behind the wallpaper texture id
  when 3D is on: cylinder wrap, blurred extension, reflective floor, camera
  from the platform-thread mailbox, pointer parallax.
- Enter / leave transitions. The toggle in the context menu and control
  centre; persisted per desktop.
- In 2D the output must be **bit-identical** to today's: screenshot-diff it
  in the functional tier.

#### Results (2026-09-16, dev box)

All four items landed. `EnvironmentRenderer` (Compositor/) draws the room
into the wallpaper's texture slot on the raster thread; `Desktop3D.swift`
carries the mode, the camera, the poses and the persistence.

- **The unfold is geometric, not a cross-fade.** Every vertex holds both
  its flat position — a quad that exactly fills the view — and its
  wrapped one, and the vertex shader mixes them by `t`. So `t = 0` IS the
  flat wallpaper rather than something that merely resembles it, and
  entering grows the room out of what was already on screen.
- **`_desktop3DT` is the one number everything reads**, tweened 600 ms
  both ways by a single controller: the window poses scale with it, the
  room unfolds with it, the parallax fades with it. That is what makes
  the end of a leave *exactly* the flat desktop instead of a
  near-identity that resamples every window for a frame.
- **The 2D contract holds, measured.** `test/functional.py`'s "3D
  desktop" check drives the toggle and screenshot-diffs it: entering
  moves the picture by ~20, leaving restores the flat desktop at a diff
  of **0.00**. Four consecutive runs.
- **Reachable four ways**: the desktop context menu, a control centre
  tile, Ctrl+Shift+3, and the broker's `desktop_3d` op (which also
  answers `query`). The choice persists like tiling — globally, not yet
  per desktop.
- Per-window depth (`WindowPose3D`) sits beside `rect`, never derived
  from it; a scroll on a title bar pushes a window back or pulls it in.
  Pointer parallax moves the eye (a translation, not a rotation — a
  rotation shifts everything equally and nothing slides against
  anything), quantised to 40 steps per axis so a still pointer means a
  still camera, and only on hover so a drag stays predictable.

**What was not right, and why no knob could fix it.** As first built the
room read almost exactly like the flat wallpaper. The diagnosis in the
tuning knobs was wrong: **a cylinder centred on the eye is depth-flat by
construction.** Every point on it is the same distance R from the viewer,
so it has no parallax and no perspective — only a slight barrel remap of
the texture, and through a 37°-wide desktop lens that is invisible. No
value of `kWrapOverscan`, `kWallLift` or `kFloorReach` changes that, and
widening the arc only pushes the curved part off the edges of the screen.

### Phase 1.5 — the room becomes a box (2026-09-16)

The wrap is now an **alcove**: the picture recedes to the far wall of a
box, and the floor, ceiling and two side walls grow out of its four edges
and come toward the viewer, carrying the picture's own colours mirrored
forward, blurred and falling into the dark. Depth reads because the
surfaces are at genuinely different distances — the near floor is a third
as far as the wall — which is the only thing that reads as depth on a
monitor.

What this settled, and is worth not re-deriving:

- **The room is defined against the frustum, not in world units**, so
  what reaches the screen does not depend on the lens or on how far away
  the wall is. That was worth knowing: the first look-dev pass concluded
  the shared 1.5-screen lens had to be shortened, and it does not. The
  windows' arc is untouched.
- **One knob decides the art direction: `kRoomCover`**, how much of the
  view the picture still fills once the room is open. 1.0 is the flat
  wallpaper; below about 0.55 the wallpaper stops being the subject of
  its own desktop. It ships at **0.66**.
- **The surfaces must meet the picture at nearly full brightness**
  (`lit` ≈ 0.9, falling off steeply with distance). A surface that meets
  it at half brightness draws a hard frame around the picture, and the
  effect stops being a room and becomes a poster hung on a dark wall.
  That one number is the difference between the two readings.
- The picture itself is never dimmed or blurred at any `t`, so the 2D
  contract is now structural rather than tuned: at t = 0 the back wall
  fills the view untouched and the other four surfaces have collapsed
  onto the quad's own edges, where they are zero-area and rasterise
  nothing. The functional check still measures it — leave restores the
  flat desktop at a diff of 0.00.
- Pointer parallax went from 2% to 3% of the screen width
  (`kEyeTravel` and `k3DEyeTravel`, which are the same eye and must move
  together). The wall shifts ~42 px across a full pointer sweep at 2560
  wide and the floor under the viewer ~68 px; that difference is what
  the cylinder could not produce at all.
- **Look-dev was done offline.** `~/tmp/room/room.py` (not in the tree)
  ray-traces the same geometry from the same wallpaper, so the art
  direction was settled by looking at pictures in seconds instead of
  rebuilding the shell. The live renderer then matched it to within a
  few percent per row, which is also how the shading was confirmed to be
  arriving — a screenshot alone is a bad judge of whether a fade is
  applied.

### Phase 2a — the windows take the room's light (2026-09-16)

Three cues, all on the window and all only while it is tilted, so the
flat desktop and the focused window's pixel-exactness are untouched:

- **Aerial haze.** A window further into the room is veiled toward the
  colour of the room behind it — 12% at the front of the arc, up to 30%
  at the back of its depth range. It is the one depth cue that works on
  a flat screen with one eye and a still head, which is why painters
  have used it for six centuries and visionOS recedes its background
  windows the same way.
- **Glass that takes the local light.** `windowGlassTint` was one colour
  for the whole desktop (the wallpaper's average, Mica's ingredient).
  For a tilted window it now leans 55% toward the part of the picture
  that window actually floats in front of.
- **A drop shadow**, in screen space, spilling outside the window onto
  the room and onto the windows below.

**The sampling point needs no world-space maths.** A window and the wall
point behind it lie on the same ray from the eye, and the picture covers
`kRoomCover` of the view — so the wall behind a window is just its
on-screen position divided by the cover, less the picture's lift. The
wallpaper is kept as a 48×30 grid of average colours when it decodes
(`_lightGrid`, a few kilobytes, built from the same pixels Mica already
uses), so a lookup is free and nothing is read back from the GPU. The
light is quantised before it reaches `_windowChildCache`, or a pointer
move would rebuild every window's subtree for a change nobody can see.

**Two things in the phase list were measured out rather than built, and
both should stay unbuilt at this geometry:**

- **A floor reflection lands off the bottom of the screen.** Mirror a
  window in the floor plane and the reflection appears at
  `(2·floorY − y)/(d·ty)` — for a window at the front of the arc that is
  −1.40 in NDC, well past the screen's edge, and it only crosses −1.0
  when the window is pushed nearly to the back wall. Windows float about
  a third of the way from the eye to the wall and sit well above the
  floor, so there is almost no floor between them and the viewer to
  reflect in. Correct, and invisible.
- **A shadow cast onto the wall behind is hidden by the window casting
  it.** The wall is further from the eye than the window, so the shadow
  projects SMALLER: 60% of the window's on-screen width at the front of
  the arc, 77% at the back. It lands entirely behind the window. Only a
  wildly oblique light would bring it out, and that draws a detached
  dark rectangle, not a shadow. This is why UI drop shadows are screen
  space, and why the one added here is too.

Both are worth revisiting only if windows ever sit ON the floor or right
against the wall, which no arrangement here does.

What is still not right: nothing reflects, nothing occludes. A window is
still in front of every part of the room, however deep it claims to be.
Tier 1's depth relief would give the room something to occlude with.

Three traps paid for:

- **An eye-centred cylinder cannot show depth.** See above. If a surface
  is meant to read as far away or near, check that its distance from the
  eye actually varies across the screen before tuning anything.
- **GL's row 0 is the BOTTOM of an engine external texture.** The first
  build flipped y in the projection "so row 0 is the top" and drew the
  room upside down. The engine wraps these bottom-left up; measure,
  don't assume.
- **A varying's precision must match across stages** in GLSL ES 1.00, or
  the program fails to link with no compile error — `uniform float uT`
  in the vertex stage against `precision mediump float` in the fragment
  stage was enough. Always read the program info log; the shader logs
  are silent on this.

### Phase 2 — depth, light, and windows that rest in the scene

- ~~Window shadows and floor reflections in the environment texture~~ —
  done as far as the geometry allows, which is a screen-space shadow and
  no reflection at all. See Phase 2a's results for why the physical
  versions of both are invisible here.
- ~~Per-window glass tint from the scene's light buffer~~ — done, and
  with no light buffer: the wallpaper's own pixels answer it on the CPU.
- Precomputed depth map for the bundled wallpaper; the relief mesh.
- The optional depth helper for user wallpapers, run at set time.

### Phase 3 — camera moves and layers

- Mission Control as dolly-back, spaces as pans, open/close along z.
- Tier 2 occlusion layers, if tiers 0–1 earned them.

## Traps to expect

- **`Transform` does no near-plane clipping.** Reject any pose whose corners
  project with `w <= 0`; Skia draws garbage rather than clipping.
- **Drag deltas are in screen space, and must stay so while a press
  flattens the window.** The hit-test transform is frozen at pointer-down
  for the whole gesture; unprojecting deltas through it after the window
  has gone flat overshoots by 1/scale (Phase 0 item 5). Unproject only if
  the pose is kept through the drag.
- **Partial repaint dies during camera motion.** Pointer parallax means the
  camera moves whenever the pointer does, which dirties every window every
  frame: a full-frame composite at 4K. One quad per window should be cheap
  on the 680M, but the engine's damage tracking
  (`docs/plans/engine-partial-repaint.md`) buys nothing there. Measure; and
  quantise the parallax so a still pointer means a still camera.
- **Client geometry is untouched.** Never resize a client because it
  receded. A 4K buffer sampled into 300px is wasteful but correct; a client
  re-laid-out at 300px is wrong and flashes on the way back.
- **Depth generation never runs in the shell.** A model in the shell
  process is a stall on the platform thread and a dependency in the .deb.
  It is a helper, at set time, and optional.
- **Multi-output.** One scene, one camera per output; a window straddling
  outputs is seen from two cameras. `hostSlideWindows` is the code that has
  to become camera-aware.
- **Root-mode artefacts** (repo `CLAUDE.md`): a third-party client's input
  behaviour under a tilt must be confirmed in the VM as `tester` before it
  is called a compositor bug.
- **macOS keeps 2D.** The environment renderer is GL; the macOS shell would
  need a Metal one, and the macOS shell is not currently built at all.

## Open questions

- Focal length: a short lens makes side windows dramatic and unreadable; a
  long one looks like a flat scale. Start at focal = 1.5 × screen width and
  tune against a real chat window on the arc.
- Arc distance versus window size: visionOS puts windows about 1.5 m away
  and scales them so a "point" stays a fixed visual angle. On a monitor the
  focused window is pixel-exact by rule, so the question is only how much
  smaller the neighbours get. Start at 0.7×.
- Whether a depth map from a photograph reads as a *place* or as a
  pop-up book. Tier 0's wrap is safe; tier 1 is the bet, and the bundled
  wallpaper is the one image it must look right on.
