// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - The 3D desktop (docs/plans/desktop-3d.md)
//
// A room you are standing in, with a real camera. 2D is today's desktop,
// pixel for pixel; 3D puts you inside a hall built out of your wallpaper,
// with the windows hanging in it as panes of glass at real places. You
// walk with the keyboard. Approach a window and it grows the way a thing
// in a room grows; stand at the right distance, square on, and it is
// pixel-exact again.
//
// WORLD UNITS ARE METRES. y is up, the picture hangs on the wall at
// z = 0, and the viewer starts back down the hall looking at it. One
// logical pixel of a window is `k3DMetresPerPx` across, so a window has a
// real size in the room and "1:1" is a real distance you can walk to.
//
// Windows stay in the Flutter layer tree under a `Transform` carrying the
// whole projection · view · model chain. That is what buys the two things
// a hand-rolled GL desktop would have to rebuild: the engine rasterises
// each window's external texture through the matrix, and
// RenderTransform's hit test runs the same matrix backwards with the
// homogeneous divide — so a click on a window across the room lands on
// the right client pixel with no new input code at all.
//
// `_desktop3DT` is still the one number the enter/leave tween moves, and
// t = 0 is still EXACTLY the flat desktop: at t = 0 no window gets a
// matrix at all (identity would resample), and the room's surfaces have
// collapsed onto the picture's edges. The camera's home position is the
// one place in the room where the picture fills the view precisely, so
// the flat desktop is simply "standing at the right spot", and entering
// 3D is the room unfolding around you from there.

/// Where a window stands in the room: the centre of its pane, in metres,
/// and which way it faces. Kept beside `WindowInfo.rect`, never derived
/// from it by 2D and never written by it, so leaving 3D changes nothing
/// here and re-entering finds the arrangement again.
struct WindowPose3D: Equatable {
    var x = 0.0
    var y = 0.0
    var z = 0.0
    /// Radians about the world's y axis. 0 faces +z, down the hall.
    var yaw = 0.0
    /// False until the window has been given a place in the room; the
    /// first entry into 3D lays every window out and sets it.
    var placed = false
}

/// The viewer: a real camera standing in the room.
struct Camera3D: Equatable {
    var x = 0.0
    var y = 0.0
    var z = 0.0
    /// Radians. 0 looks down -z, at the picture.
    var yaw = 0.0
    var pitch = 0.0
}

/// Where one window ends up on screen this frame.
enum Desktop3DPlacement {
    /// 2D, or t = 0: no matrix at all, the plain-translation paint path,
    /// pixel-exact.
    case flat
    /// In the room: the full transform, and the pivot its coordinates are
    /// centred on (handed to `Transform` as `origin`, made window-local).
    case posed(Matrix4, Offset)
    /// Behind the viewer, past the near plane, or turned away. `Transform`
    /// does no near-plane clipping and Skia draws garbage past it, so the
    /// window is not drawn at all.
    case hidden
}

/// The light one window sits in. Resolved per window from the wallpaper
/// itself: the room's back wall IS the picture, so "what is behind this
/// window" is the part of the picture the window stands in front of.
///
/// The two things this does NOT do were both measured out rather than
/// skipped — see `docs/plans/desktop-3d.md`, Phase 2a.
struct RoomLight: Equatable {
    /// The average colour of the picture behind the window.
    var color: Color
    /// How much of that colour veils the window. Aerial perspective: the
    /// depth cue that works on a flat screen, because it does not need
    /// two eyes or a moving head.
    var haze: Double
    /// How far off the room the window reads as floating, 0 to 1 with the
    /// enter/leave tween. Scales the drop shadow.
    var separation: Double
    /// What the pane's four edges catch of the room's light, lit by the
    /// same sky as the room itself. A pane with no edge is infinitely
    /// thin and reads as a decal stuck to the view; give it a few
    /// millimetres that take the light and it becomes an object. The
    /// side facing the windows comes up bright and the side facing away
    /// stays dark, which is the whole cue.
    var edgeTop: Color = Color(0x00000000)
    var edgeRight: Color = Color(0x00000000)
    var edgeBottom: Color = Color(0x00000000)
    var edgeLeft: Color = Color(0x00000000)
}

extension _DesktopShellState {

    // MARK: The room, in metres

    /// A game lens, not a desktop one. The flat desktop's implied lens is
    /// long and flattening; standing in a room wants something near what
    /// a person actually sees.
    static let k3DFovX = 70.0 * Double.pi / 180
    /// How big a window is in the room: one logical pixel across. A
    /// 1280-pixel window comes out 2.6 m wide and reads 1:1 from about
    /// 1.8 m — a step and a half away, which is where you would stand to
    /// read something on a wall.
    static let k3DMetresPerPx = 0.0019
    /// Where the viewer stands when the room opens: back in the room,
    /// looking at the windows, at eye height.
    static let k3DEyeHeight = 1.68
    static let k3DHomeZ = 9.3

    /// Where the windows are put when the room first lays them out, and
    /// how wide the fan is.
    static let k3DArcRadius = 3.7
    static let k3DArcSpread = 52.0 * Double.pi / 180

    /// Walking. One key press (or repeat) is one step.
    static let k3DStep = 0.22
    static let k3DTurn = 2.6 * Double.pi / 180
    static let k3DTransitionMs = 600

    var _desktop3DActive: Bool { _desktop3DT > 0 }

    /// STARLING_3D_LOG=1: what the camera is doing, on stderr.
    func _desktop3DLog(_ m: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["STARLING_3D_LOG"] == "1" else { return }
        FileHandle.standardError.write(Data("[3D] \(m())\n".utf8))
    }

    /// The focal length in logical pixels that the room's lens implies on
    /// this output.
    func _desktop3DFocalPx(_ host: Rect) -> Double {
        (host.width / 2) / tan(Self.k3DFovX / 2)
    }

    /// Where the viewer stands when the room opens: back in the room with
    /// the windows ahead, at eye height.
    func _desktop3DHomeCamera(_ host: Rect) -> Camera3D {
        Camera3D(x: 0, y: Self.k3DEyeHeight, z: Self.k3DHomeZ, yaw: 0, pitch: 0)
    }

    /// Where a window hangs when it is simply showing its 2D rect: the
    /// plane in front of the home camera at which one logical pixel is
    /// one screen pixel.
    func _desktop3DFlatPose(rect: Rect, host: Rect) -> WindowPose3D {
        let home = _desktop3DHomeCamera(host)
        let d1 = _desktop3DFocalPx(host) * Self.k3DMetresPerPx
        return WindowPose3D(
            x: (rect.center.dx - host.center.dx) * Self.k3DMetresPerPx,
            y: home.y - (rect.center.dy - host.center.dy) * Self.k3DMetresPerPx,
            z: home.z - d1,
            yaw: 0, placed: true)
    }

    // MARK: Laying the windows out

    /// Give any window that has no place in the room one: a fan in front
    /// of wherever the viewer is standing, ordered left to right by where
    /// the windows already were on screen, so nothing teleports and the
    /// arrangement the user had is still legible.
    ///
    /// Called from the window-stack builder rather than only on entry,
    /// because windows appear at every moment — a fresh launch, a restore
    /// from minimise, and the case that caught this out, a session that
    /// came up with the room ALREADY open, where entering never happened
    /// at all. It only ever writes to a window that has no place, so it
    /// settles on the first build and does nothing on every later one.
    @discardableResult
    func _desktop3DPlaceWindows() -> Bool {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0 else { return false }
        let fresh = windowManager.visibleWindows
            .filter { !$0.pose3D.placed }
            .sorted { $0.rect.center.dx < $1.rect.center.dx }
        guard !fresh.isEmpty else { return false }
        // In front of the viewer, not in front of the door: a window that
        // opens while you are down the other end of the hall should be
        // where you are looking.
        let eye = _camera3D
        let taken = windowManager.visibleWindows.filter { $0.pose3D.placed }.count
        let n = fresh.count + taken
        for (i, win) in fresh.enumerated() {
            let slot = taken + i
            let f = n == 1 ? 0.0 : Double(slot) / Double(n - 1) - 0.5
            let a = f * Self.k3DArcSpread + eye.yaw
            win.pose3D = WindowPose3D(
                x: eye.x + Self.k3DArcRadius * sin(a),
                y: eye.y,
                z: eye.z - Self.k3DArcRadius * cos(a),
                // Turn to face the spot the viewer is standing in.
                yaw: -a,
                placed: true)
        }
        return true
    }

    // MARK: The camera

    var _camera3D: Camera3D {
        get {
            let id = displayLayout?.host.id ?? 0
            if let c = _cameras3D[id] { return c }
            return _desktop3DHomeCamera(displayLayout?.host.logicalRect
                ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight))
        }
        set { _cameras3D[displayLayout?.host.id ?? 0] = newValue }
    }

    /// The camera as this frame should see it: folded back toward the
    /// home spot by the enter/leave tween. At t = 0 it IS the home spot —
    /// the one place where the picture fills the view — so leaving 3D
    /// walks the viewer back to their desk however far they had wandered,
    /// and the flat desktop it lands on is exact rather than approximate.
    func _desktop3DEffectiveCamera(_ t: Double) -> Camera3D {
        let home = _desktop3DHomeCamera(displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight))
        guard t > 0 else { return home }
        if t >= 1 { return _desktop3DLeaned(_camera3D, t) }
        let c = _camera3D
        return _desktop3DLeaned(
            Camera3D(x: home.x + (c.x - home.x) * t,
                     y: home.y + (c.y - home.y) * t,
                     z: home.z + (c.z - home.z) * t,
                     yaw: home.yaw + (c.yaw - home.yaw) * t,
                     pitch: home.pitch + (c.pitch - home.pitch) * t), t)
    }

    // MARK: The lean — parallax from the pointer

    /// A monitor shows one image to a still head, so the depth cues two
    /// eyes and a moving head would give are both gone. What is left is
    /// MOTION parallax, and the pointer is the only thing that moves.
    ///
    /// So the eye leans a few centimetres toward the pointer and keeps
    /// looking at the same spot. That last part is what makes it parallax
    /// rather than a pan: turning the camera slides everything together
    /// and reads as a wobble, while TRANSLATING it slides the near things
    /// against the far ones — the floor against the back wall, a near
    /// window against a far one — which is the whole cue.
    ///
    /// How far the eye leans at the edge of the screen, in metres. Head
    /// sway when someone leans to see around something is 5-15 cm; this is
    /// the quiet end of that, because the pointer reaches the edge far
    /// more often than a head does.
    static let k3DLeanX = 0.055
    static let k3DLeanY = 0.035
    /// What the eye keeps its gaze on while it leans: the FAR WALL, not
    /// the arc the windows sit on.
    ///
    /// This is the whole difference between parallax and a wobble, and it
    /// was measured the wrong way round first. Leaning by `s` slides a
    /// thing at distance `d` across the screen by `focal·s/d`, and turning
    /// back toward the pivot slides everything by a uniform `focal·s/pivot`
    /// the other way — so the net motion goes as `1/pivot − 1/d`, and
    /// anything NEARER than the pivot moves one way while anything beyond
    /// it moves the other. Pivot on the arc (3.7 m) and every piece of
    /// furniture in the room is beyond it, so the far wall swung 3.7× as
    /// far as the near sofa: the exact inverse of what leaning does, and
    /// it reads as the room sliding rather than the eye moving.
    ///
    /// Pivot on the wall instead and the wall holds still while the room
    /// swings across it, near things most — which is what a head actually
    /// sees. Measured at the end of Phase 5.
    static let k3DLeanPivotMin = 3.0
    /// Seconds for the lean to cover most of the distance to a new
    /// pointer position. Long enough that the scene glides rather than
    /// snapping to every jitter, short enough that it is not lag.
    static let k3DLeanTau = 0.11
    /// Below this, the lean has arrived: stop the ticker rather than
    /// rebuild the window stack forever for motion nobody can see.
    static let k3DLeanSettled = 0.002

    /// Apply the current lean to a camera. Scaled by the enter/leave
    /// tween, so the flat desktop never leans and entering 3D brings the
    /// parallax up with everything else.
    func _desktop3DLeaned(_ c: Camera3D, _ t: Double) -> Camera3D {
        let s = _lean3D.x * Self.k3DLeanX * t
        // Screen y runs down; leaning toward the pointer means the eye
        // drops when the pointer is low.
        let u = -_lean3D.y * Self.k3DLeanY * t
        guard s != 0 || u != 0 else { return c }
        var out = c
        // Right of the camera is (cos yaw, 0, sin yaw): forward is
        // (sin yaw, 0, -cos yaw), the same convention walking uses.
        out.x += cos(c.yaw) * s
        out.z += sin(c.yaw) * s
        out.y += u
        // Turn back toward the pivot by the small angle the step subtends,
        // so the spot being looked at stays put. Lean right, turn left.
        // The picture wall is at z = 0, so the eye's own z IS its distance
        // to what it is looking at, and walking toward the wall shortens
        // the lever exactly as it should.
        let pivot = max(Self.k3DLeanPivotMin, c.z)
        out.yaw -= s / pivot
        out.pitch -= u / pivot
        return out
    }

    /// Called from the root Listener on every pointer event. Cheap and
    /// silent unless the room is open: it only records where the lean is
    /// heading, and the ticker does the moving.
    func _desktop3DNotePointer() {
        guard _desktop3DActive else { return }
        // Frozen while a button is down. A window being dragged should
        // follow the pointer and nothing else; a scene that leans under
        // the drag makes the target move as you reach for it.
        guard _lastButtons == 0 else { return }
        let f = _pointerFraction
        let want = (x: max(-1, min(1, (f.x - 0.5) * 2)),
                    y: max(-1, min(1, (f.y - 0.5) * 2)))
        guard abs(want.x - _lean3DTarget.x) > 0.001
                || abs(want.y - _lean3DTarget.y) > 0.001 else { return }
        _lean3DTarget = want
        _desktop3DStartLean()
    }

    /// Ease the lean toward the pointer, one step per frame, and stop as
    /// soon as it has arrived. Every tick that moves rebuilds the window
    /// stack (the windows ride the same eye as the room), which is why
    /// this must stop rather than idle.
    func _desktop3DStartLean() {
        if _lean3DTicker == nil {
            _lean3DTicker = createTicker { [weak self] elapsed in
                guard let self else { return }
                let now = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) * 1e-18
                let dt = max(0, min(0.1, now - self._lean3DClock))
                self._lean3DClock = now
                guard self._desktop3DActive else {
                    self._lean3DTicker?.stop()
                    self._lean3D = (0, 0)
                    self._lean3DTarget = (0, 0)
                    return
                }
                let k = 1 - exp(-dt / Self.k3DLeanTau)
                var next = (x: self._lean3D.x + (self._lean3DTarget.x - self._lean3D.x) * k,
                            y: self._lean3D.y + (self._lean3DTarget.y - self._lean3D.y) * k)
                let done = abs(next.x - self._lean3DTarget.x) < Self.k3DLeanSettled
                    && abs(next.y - self._lean3DTarget.y) < Self.k3DLeanSettled
                if done { next = self._lean3DTarget; self._lean3DTicker?.stop() }
                self.setState { self._lean3D = next }
                self._desktop3DPublishCamera()
            }
        }
        if !(_lean3DTicker?.isActive ?? false) {
            _lean3DClock = 0
            _ = _lean3DTicker?.start()
        }
    }

    /// World -> view: undo the camera's place and heading.
    static func _view(_ c: Camera3D) -> Matrix4 {
        var m = Matrix4.rotationX(-c.pitch)
        m.multiply(Matrix4.rotationY(-c.yaw))
        m.multiply(Matrix4.translationValues(-c.x, -c.y, -c.z))
        return m
    }

    /// View -> what `Transform` wants: x and y scaled by the focal length,
    /// w carrying the distance, so the engine's own divide IS the
    /// perspective divide. Screen y runs down, world y runs up.
    ///
    /// The z row has to be a real projection row even though nothing reads
    /// the z: with a trivial one the matrix is SINGULAR (two rows differing
    /// by a sign), and `RenderTransform` neither paints nor hit-tests a
    /// matrix it cannot invert — every window simply vanishes, with no
    /// error anywhere.
    static func _screenFromView(focal: Double) -> Matrix4 {
        let near = 0.05, far = 200.0
        var p = Matrix4.zero()
        p.setEntry(0, 0, focal)
        p.setEntry(1, 1, -focal)
        p.setEntry(2, 2, -(far + near) / (far - near))
        p.setEntry(2, 3, -2 * far * near / (far - near))
        p.setEntry(3, 2, -1)
        return p
    }

    // MARK: The pose

    /// Where a window lands on screen: the full projection · view · model
    /// chain, over coordinates centred on the host's centre (the same
    /// convention `Transform`'s `origin` is given).
    ///
    /// The tween is in the WORLD, not on the matrix: at t the window is
    /// interpolated between the pose that reproduces its 2D rect exactly
    /// and the pose it has in the room, so entering 3D lifts each window
    /// off the flat desktop from precisely where it was.
    func _desktop3DPlacement(rect: Rect, t: Double, camera: Camera3D,
                             pose: WindowPose3D) -> Desktop3DPlacement {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0, host.height > 0, t > 0 else { return .flat }
        let p = _desktop3DLerpPose(rect: rect, host: host, t: t, pose: pose)

        // Turned away from the viewer: a pane has one side.
        let n = Vector3(sin(p.yaw), 0, cos(p.yaw))
        let toCam = Vector3(camera.x - p.x, camera.y - p.y, camera.z - p.z)
        if n.dot(toCam) <= 0.02 { return .hidden }

        let focal = _desktop3DFocalPx(host)
        let s = Self.k3DMetresPerPx
        // The window's own centre, in the coordinates the matrix is given.
        let wcx = rect.center.dx - host.center.dx
        let wcy = rect.center.dy - host.center.dy

        var m = Self._screenFromView(focal: focal)
        m.multiply(Self._view(camera))
        m.multiply(Matrix4.translationValues(p.x, p.y, p.z))
        m.multiply(Matrix4.rotationY(p.yaw))
        m.multiply(Matrix4.diagonal3Values(s, -s, s))
        m.multiply(Matrix4.translationValues(-wcx, -wcy, 0))

        // Near plane, on the four corners. Either the whole pane is in
        // front of the camera or it is not drawn.
        let l = rect.left - host.center.dx, r = rect.right - host.center.dx
        let tp = rect.top - host.center.dy, b = rect.bottom - host.center.dy
        let row3 = m.getRow(3)
        for (x, y) in [(l, tp), (r, tp), (l, b), (r, b)] {
            if row3.x * x + row3.y * y + row3.w <= 0.25 { return .hidden }
        }
        return .posed(m, host.center)
    }

    /// The window's place this frame: between the pose that reproduces
    /// its flat rect and the pose it has in the room.
    func _desktop3DLerpPose(rect: Rect, host: Rect, t: Double,
                            pose: WindowPose3D) -> WindowPose3D {
        let flat = _desktop3DFlatPose(rect: rect, host: host)
        let target = pose.placed ? pose : flat
        return WindowPose3D(
            x: flat.x + (target.x - flat.x) * t,
            y: flat.y + (target.y - flat.y) * t,
            z: flat.z + (target.z - flat.z) * t,
            yaw: flat.yaw + (target.yaw - flat.yaw) * t,
            placed: true)
    }

    /// How far the camera is from a window's pane — what the far-to-near
    /// draw order sorts on, since the layer tree has no z-buffer between
    /// its children.
    func _desktop3DDistance(rect: Rect, t: Double, camera: Camera3D,
                            pose: WindowPose3D) -> Double {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        let p = _desktop3DLerpPose(rect: rect, host: host, t: t, pose: pose)
        let dx = camera.x - p.x, dy = camera.y - p.y, dz = camera.z - p.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    // MARK: Walking

    /// True when the keyboard should drive the camera rather than a
    /// window: the room is open and nothing has the keyboard. Clicking a
    /// window takes the keys; clicking the room gives them back.
    var _desktop3DWalking: Bool {
        _desktop3DOn && _desktop3DT > 0 && windowManager.focusedWindowId == nil
    }

    /// One step of the camera, from a key. Returns true if the key was
    /// ours. HID usage codes, like the rest of the shortcut table.
    ///
    /// `forced` is Alt held: the camera answers even while a window has
    /// the keyboard, because otherwise the room is unreachable in
    /// practice — something is focused almost all of the time.
    func _desktop3DKey(_ usage: Int, fast: Bool, forced: Bool = false) -> Bool {
        guard _desktop3DOn, _desktop3DT > 0 else { return false }
        guard forced || _desktop3DWalking else { return false }
        var c = _camera3D
        let step = Self.k3DStep * (fast ? 2.5 : 1)
        let turn = Self.k3DTurn * (fast ? 2.5 : 1)
        // Forward is where the camera is looking, flattened: walking, not
        // flying, unless the rise/sink keys are used.
        let fx = sin(c.yaw), fz = -cos(c.yaw)
        switch usage {
        case 0x1A, 0x52: c.x += fx * step; c.z += fz * step     // W, Up
        case 0x16, 0x51: c.x -= fx * step; c.z -= fz * step     // S, Down
        case 0x04:       c.x += fz * step; c.z -= fx * step     // A, strafe
        case 0x07:       c.x -= fz * step; c.z += fx * step     // D, strafe
        case 0x50, 0x14: c.yaw -= turn                          // Left, Q
        case 0x4F, 0x08: c.yaw += turn                          // Right, E
        case 0x15:       c.y += step                            // R, rise
        case 0x09:       c.y -= step                            // F, sink
        case 0x4A:                                              // Home
            c = _desktop3DHomeCamera(displayLayout?.host.logicalRect
                ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight))
        case 0x2C:       return _desktop3DStepUp()               // Space
        default:         return false
        }
        _desktop3DLog("key \(usage) -> \(c.x),\(c.z) yaw \(c.yaw)")
        // Stay inside the room, and out of the walls.
        let m = 0.45
        c.x = min(Room3D.halfW - m, max(-Room3D.halfW + m, c.x))
        c.y = min(Room3D.height - 0.3, max(0.5, c.y))
        c.z = min(Room3D.depth - m, max(m, c.z))
        c.pitch = min(1.2, max(-1.2, c.pitch))
        setState { _camera3D = c }
        _desktop3DPublishCamera()
        return true
    }

    /// Walk up to the window most nearly in front of the viewer and stand
    /// square on at the distance where its pixels are its pixels. This is
    /// the answer to the oldest objection to a 3D desktop — that
    /// perspective-sampled text is unusable — and it is an answer a room
    /// can give and a flat desktop cannot: you step up to the thing.
    @discardableResult
    func _desktop3DStepUp() -> Bool {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        let c = _camera3D
        let fx = sin(c.yaw), fz = -cos(c.yaw)
        var best: (WindowInfo, Double)? = nil
        for win in windowManager.visibleWindows where win.pose3D.placed {
            let p = win.pose3D
            let dx = p.x - c.x, dz = p.z - c.z
            let len = (dx * dx + dz * dz).squareRoot()
            guard len > 0.01 else { continue }
            let facing = (dx * fx + dz * fz) / len       // 1 = dead ahead
            guard facing > 0.2 else { continue }
            let score = facing / (1 + len * 0.15)
            if best == nil || score > best!.1 { best = (win, score) }
        }
        _desktop3DLog("step up: \(windowManager.visibleWindows.count) windows, "
                      + "\(windowManager.visibleWindows.filter { $0.pose3D.placed }.count) placed, "
                      + "best \(best?.0.title ?? "none")")
        guard let winner = best?.0 else { return false }
        let p = winner.pose3D
        let d1 = _desktop3DFocalPx(host) * Self.k3DMetresPerPx
        setState {
            // Square on to the pane, at the 1:1 distance, eye on its centre.
            _camera3D = Camera3D(x: p.x + sin(p.yaw) * d1, y: p.y,
                                 z: p.z + cos(p.yaw) * d1,
                                 yaw: p.yaw, pitch: 0)
            windowManager.bringToFront(winner.id)
        }
        _desktop3DPublishCamera()
        return true
    }

    // MARK: The light

    /// How much of the room's colour a window at the back of the hall
    /// takes. Enough that distance reads; not so much that a window you
    /// might want to glance at stops being legible.
    static let k3DHazeMax = 0.30
    /// How far a window's glass leans from the theme's tint toward the
    /// light actually behind it.
    static let k3DGlassRoomMix = 0.55
    /// The distance at which haze reaches its maximum.
    static let k3DHazeFar = 9.0

    /// What the pane's edge is made of, as the fraction of the light
    /// falling on it that it returns. This is an albedo and it has to be
    /// one: with the edge treated as a perfect reflector, the sun (whose
    /// baked colour runs to 9.9) drove the two lit sides clean past white
    /// and the pane came out with a hard graphic border instead of a
    /// bevel. At 0.55 — anodised metal, near enough — the four sides land
    /// at 0.85, 0.79, 0.31 and 0.21, which is a lit edge and a dark one.
    static let k3DEdgeAlbedo = 0.55

    /// What the baked sky gives a surface facing `n`, in exactly the terms
    /// the room's own shader uses — the nine spherical-harmonic
    /// coefficients, the share of the sky a room can actually see, the
    /// bounce off the floor that no sky supplies, and the sun. Mirrored
    /// rather than shared because the room is drawn on the raster thread
    /// in GLSL and this is one number per window on the platform thread;
    /// if one is ever changed the other has to follow, or the panes will
    /// be lit by a different day than the room they hang in.
    func _desktop3DSkyLight(_ nx: Double, _ ny: Double, _ nz: Double) -> [Double] {
        #if os(Linux)
        guard let sh = _roomAsset?.mesh.sh, sh.count == 27,
              let sun = _roomAsset?.mesh.sunDir,
              let sunCol = _roomAsset?.mesh.sunColour else { return [0.3, 0.3, 0.3] }
        let c1 = 0.429043, c2 = 0.511664, c3 = 0.743125, c4 = 0.886227, c5 = 0.247708
        // How much of the sky this room can see facing that way: the walls
        // block most of it and the windows are where it gets in.
        let toWin = max(-nz, 0)
        let down = min(1, max(0, 0.5 - ny * 0.5))
        let ndl = max(0, nx * Double(sun.0) + ny * Double(sun.1) + nz * Double(sun.2))
        let sunRGB = [Double(sunCol.0), Double(sunCol.1), Double(sunCol.2)]
        let bounceRGB = [1.0, 0.90, 0.76]
        var out = [Double](repeating: 0, count: 3)
        for k in 0..<3 {
            func s(_ i: Int) -> Double { Double(sh[i * 3 + k]) }
            let irr = c1 * s(8) * (nx * nx - ny * ny)
                + c3 * s(6) * nz * nz
                + c4 * s(0) - c5 * s(6)
                + 2 * c1 * (s(4) * nx * ny + s(7) * nx * nz + s(5) * ny * nz)
                + 2 * c2 * (s(3) * nx + s(1) * ny + s(2) * nz)
            let sky = max(0, irr) * (0.17 + 0.62 * toWin) * 0.318
            let bounce = bounceRGB[k] * (0.10 + 0.26 * down) * (0.35 + 0.06 * sunRGB[1])
            out[k] = sky + bounce + sunRGB[k] * ndl * 0.318
        }
        return out
        #else
        return [0.3, 0.3, 0.3]
        #endif
    }

    /// The four edges of a pane at this heading, lit by the room's sky.
    /// The pane hangs in the open with nothing to shadow it, so the sun
    /// term is a plain N·L — the only thing that varies is which way each
    /// edge faces.
    ///
    /// Depends on the pane's YAW and nothing else, so it survives every
    /// step the viewer takes and only changes when the window is moved
    /// around the arc. That matters: this feeds `_windowChildCache`.
    func _desktop3DPaneEdges(yaw: Double)
        -> (top: Color, right: Color, bottom: Color, left: Color) {
        // The pane's normal is (sin yaw, 0, cos yaw), so its right-hand
        // edge faces (cos yaw, 0, -sin yaw) and its top faces straight up.
        let rx = cos(yaw), rz = -sin(yaw)
        func edge(_ nx: Double, _ ny: Double, _ nz: Double) -> Color {
            let l = _desktop3DSkyLight(nx, ny, nz)
            func ch(_ x: Double) -> Double {
                // The room's own filmic shoulder, so an edge in a sun
                // patch rolls off instead of clipping to white.
                let v = x * Self.k3DEdgeAlbedo
                return min(1, max(0, (v / (v + 0.78)) * 1.62))
            }
            // Quantised for the same reason the rest of the light is: an
            // unrounded colour would miss the widget cache forever.
            func q(_ x: Double) -> Double { (x * 32).rounded() / 32 }
            return Color(alpha: 1, red: q(ch(l[0])), green: q(ch(l[1])), blue: q(ch(l[2])))
        }
        return (top: edge(0, 1, 0), right: edge(rx, 0, rz),
                bottom: edge(0, -1, 0), left: edge(-rx, 0, -rz))
    }

    /// The light behind one window: the average colour of the part of the
    /// picture it stands in front of, plus the haze its distance earns.
    /// The sampling point is where the ray from the eye through the
    /// window's centre meets the picture's wall.
    ///
    /// Quantised, because this feeds `_windowChildCache`: an unrounded
    /// colour would miss the cache on every step and rebuild every
    /// window's subtree for a change nobody can see.
    func _desktop3DRoomLight(rect: Rect, t: Double, camera: Camera3D,
                             pose: WindowPose3D) -> RoomLight? {
        #if os(Linux)
        guard t > 0, let grid = _wallpaperLight, grid.cols > 0, grid.rows > 0 else { return nil }
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0, host.height > 0 else { return nil }
        let p = _desktop3DLerpPose(rect: rect, host: host, t: t, pose: pose)

        // The view outside is scenery at infinity, so where a pane sits
        // against it depends only on the DIRECTION from the eye — which is
        // its position on screen, in the frame the view exactly fills.
        let tanH = tan(Self.k3DFovX / 2)
        let fwd = (sin(camera.yaw), -cos(camera.yaw))
        let right = (cos(camera.yaw), sin(camera.yaw))
        let dx = p.x - camera.x, dy = p.y - camera.y, dz = p.z - camera.z
        let along = dx * fwd.0 + dz * fwd.1
        var u = 0.5, v = 0.5
        if along > 0.05 {
            let side = dx * right.0 + dz * right.1
            u = 0.5 + (side / along) / (2 * tanH)
            v = 0.5 - (dy / along) / (2 * tanH) * (host.width / host.height)
        }
        let halfU = (rect.width * Self.k3DMetresPerPx) / (2 * max(along, 0.1) * tanH) / 2
        let halfV = halfU
        func cell(_ a: Double, _ n: Int) -> Int { min(n - 1, max(0, Int(a * Double(n)))) }
        let x0 = cell(u - halfU, grid.cols), x1 = cell(u + halfU, grid.cols)
        let y0 = cell(v - halfV, grid.rows), y1 = cell(v + halfV, grid.rows)
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for gy in min(y0, y1)...max(y0, y1) {
            for gx in min(x0, x1)...max(x0, x1) {
                let c = grid.cells[gy * grid.cols + gx]
                r += c.r; g += c.g; b += c.b; n += 1
            }
        }
        guard n > 0 else { return nil }
        // Nothing hazes until it is further off than reading distance.
        let d1 = _desktop3DFocalPx(host) * Self.k3DMetresPerPx
        let dist = _desktop3DDistance(rect: rect, t: t, camera: camera, pose: pose)
        let haze = Self.k3DHazeMax
            * min(1, max(0, (dist - d1) / (Self.k3DHazeFar - d1)))
        func q(_ x: Double) -> Double { (x * 24).rounded() / 24 }
        let edges = _desktop3DPaneEdges(yaw: p.yaw)
        return RoomLight(
            color: Color(alpha: 1.0, red: q(r / n), green: q(g / n), blue: q(b / n)),
            haze: (haze * 40).rounded() / 40,
            separation: (t * 20).rounded() / 20,
            edgeTop: edges.top, edgeRight: edges.right,
            edgeBottom: edges.bottom, edgeLeft: edges.left)
        #else
        return nil
        #endif
    }

    // MARK: The mode

    /// Enter or leave, animated (600 ms) unless told otherwise. The choice
    /// persists like tiling and appearance.
    func _setDesktop3D(_ on: Bool, animated: Bool = true) {
        if on == _desktop3DOn, animated { return }
        _desktop3DOn = on
        _desktop3DPersist()
        if on {
            // Start from the one spot where the room looks like the flat
            // desktop, and give every window a place in the hall.
            _camera3D = _desktop3DHomeCamera(displayLayout?.host.logicalRect
                ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight))
            _desktop3DPlaceWindows()
        }
        if !animated {
            setState { _desktop3DT = on ? 1 : 0 }
            _desktop3DPublishCamera()
            if !on { _releaseEnvironment() }
            return
        }
        if _desktop3DController == nil {
            let c = AnimationController(
                duration: .milliseconds(Self.k3DTransitionMs), vsync: self)
            let curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic)
            curve.addListener { [weak self] in
                guard let self else { return }
                self.setState { self._desktop3DT = curve.value }
                self._desktop3DPublishCamera()
            }
            c.addStatusListener { [weak self] status in
                guard let self, status == .dismissed else { return }
                // Back in 2D: the wallpaper slot already shows the plain
                // texture (t = 0 built above). Let that frame land before
                // the environment's texture goes away under it.
                let work: () -> Void = { [weak self] in
                    guard let self, self._desktop3DT == 0 else { return }
                    self._releaseEnvironment()
                }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + .milliseconds(120),
                    execute: unsafeBitCast(work, to: (@Sendable () -> Void).self))
            }
            _desktop3DController = c
            _desktop3DCurve = curve
        }
        // Make sure the room exists before the first tween frame asks for
        // it — the wallpaper slot swaps to the environment at t > 0.
        if on { _ = _ensureEnvironment() }
        if on { _ = _desktop3DController!.forward() } else { _ = _desktop3DController!.reverse() }
    }

    private static var _desktop3DFile: String { LoginUser.configDir + "/desktop-3d" }

    func _desktop3DPersist() {
        let path = Self._desktop3DFile
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try? (_desktop3DOn ? "on" : "off").write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// At launch: come up in whichever mode was chosen, with no transition.
    func _loadDesktop3DPreference() {
        var on = (ProcessInfo.processInfo.environment["STARLING_3D_SPIKE"] ?? "") == "1"
        if let s = try? String(contentsOfFile: Self._desktop3DFile, encoding: .utf8) {
            on = s.trimmingCharacters(in: .whitespacesAndNewlines) == "on"
        }
        _desktop3DOn = on
        _desktop3DT = on ? 1 : 0
    }

    /// Hand the environment what the platform thread decided; it renders
    /// on the raster thread at the next engine frame.
    func _desktop3DPublishCamera() {
        #if os(Linux)
        guard let env = _environment, let registry = drmTextureRegistry,
              let wl = waylandIntegration, environmentTextureId >= 0 else { return }
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        let c = _desktop3DEffectiveCamera(_desktop3DT)
        _ = host
        let sky = shellMica ?? Color(alpha: 1, red: 0.55, green: 0.60, blue: 0.70)
        let changed = env.setCamera(EnvironmentCamera(
            t: _desktop3DT, x: c.x, y: c.y, z: c.z, yaw: c.yaw, pitch: c.pitch,
            tanHalfFovX: tan(Self.k3DFovX / 2),
            lightR: sky.r, lightG: sky.g, lightB: sky.b))
        if changed { registry.markGLTextureDirty(engine: wl.engine, id: environmentTextureId) }
        #endif
    }

    // MARK: The environment

    /// The room behind the windows: a texture in the wallpaper's slot,
    /// rendered from the wallpaper's own texture. Created on first use
    /// (the wallpaper decodes asynchronously, so `makeWallpaper` asks
    /// every build until it can), released when a leave finishes.
    @discardableResult
    func _ensureEnvironment() -> Bool {
        #if os(Linux)
        if environmentTextureId >= 0 { return true }
        guard let registry = drmTextureRegistry, let wl = waylandIntegration,
              wallpaperTextureId >= 0,
              let phys = PlatformDispatcher.instance.implicitView?.physicalSize,
              phys.width > 0, phys.height > 0 else { return false }
        let renderer = EnvironmentRenderer(width: Int(phys.width), height: Int(phys.height))
        renderer.glProcAddressResolver = registry.glProcAddressResolver
        let source = wallpaperTextureId
        renderer.sourceTexture = { [weak registry] in registry?.sourceTexture(id: source) }
        let id = registry.registerTexture(engine: wl.engine)
        registry.setGLRenderer(id: id, renderer: renderer)
        _environment = renderer
        environmentTextureId = id
        _startSceneClock()
        _loadRoomAsset()
        _applyRoomAsset()
        _desktop3DPublishCamera()
        registry.markGLTextureDirty(engine: wl.engine, id: id)
        return true
        #else
        return false
        #endif
    }

    /// The scene is weather, not a photograph: a ticker drives the cloud
    /// and the water. It lives with the ENVIRONMENT rather than with the
    /// mode, because a session that comes up with the scene already open
    /// never runs the enter path at all — the same thing that left every
    /// window without a place in the room.
    ///
    /// This is the one part of the 3D desktop that costs power while
    /// nothing else is happening: a full-screen pass per frame.
    func _startSceneClock() {
        #if os(Linux)
        if _sceneTicker == nil {
            _sceneTicker = createTicker { [weak self] elapsed in
                guard let self, let env = self._environment,
                      let registry = drmTextureRegistry,
                      let wl = waylandIntegration,
                      self.environmentTextureId >= 0 else { return }
                env.tick(Double(elapsed.components.seconds)
                         + Double(elapsed.components.attoseconds) * 1e-18)
                registry.markGLTextureDirty(engine: wl.engine,
                                            id: self.environmentTextureId)
            }
        }
        if !(_sceneTicker?.isActive ?? false) { _ = _sceneTicker?.start() }
        #endif
    }

    /// Read the baked room: the mesh, and the two atlases it is textured
    /// with. Decoded off the platform thread's critical path the same way
    /// the wallpaper is, then handed to the renderer, which uploads it at
    /// the next frame. Missing files leave the scene empty rather than
    /// failing — the room is an asset, not a dependency.
    func _loadRoomAsset() {
        #if os(Linux)
        guard !_roomLoadStarted else { return }
        _roomLoadStarted = true
        guard let meshPath = Self.dataFilePath("room/room.mesh")
                ?? ["Resources/Room/room.mesh"].first(where: {
                    FileManager.default.fileExists(atPath: $0) }),
              let mesh = Room3D.loadMesh(meshPath) else {
            FileHandle.standardError.write(Data(
                "[room] no baked room found — run build/tools/room-import.py\n".utf8))
            return
        }
        let dir = (meshPath as NSString).deletingLastPathComponent
        Task { @MainActor in
            func decode(_ name: String) async -> (data: [UInt8], w: Int, h: Int)? {
                guard let d = try? Data(contentsOf: URL(
                    fileURLWithPath: dir + "/" + name)) else { return nil }
                guard let codec = try? await FlutterSwiftBridge
                        .instantiateImageCodec([UInt8](d)),
                      let frame = try? await codec.getNextFrame() else { return nil }
                codec.dispose()
                let image = frame.image
                defer { image.dispose() }
                guard let bytes = try? image.toByteData(format: .rawRgba) else { return nil }
                return ([UInt8](bytes), image.width, image.height)
            }
            guard let diff = await decode("room-diffuse.png"),
                  let arm = await decode("room-arm.png"),
                  let sky = await decode("room-sky.png"),
                  let shell = _shellState else { return }
            shell._roomAsset = (mesh, diff, arm, sky)
            shell._applyRoomAsset()
        }
        #endif
    }

    /// Hand the room to the renderer, whenever both exist.
    func _applyRoomAsset() {
        #if os(Linux)
        guard let env = _environment, let asset = _roomAsset,
              let registry = drmTextureRegistry, let wl = waylandIntegration,
              environmentTextureId >= 0 else { return }
        env.roomAsset = asset
        registry.markGLTextureDirty(engine: wl.engine, id: environmentTextureId)
        #endif
    }

    func _releaseEnvironment() {
        #if os(Linux)
        guard environmentTextureId >= 0, let registry = drmTextureRegistry,
              let wl = waylandIntegration else { return }
        _sceneTicker?.stop()
        registry.unregisterTexture(engine: wl.engine, id: environmentTextureId)
        environmentTextureId = -1
        _environment = nil
        #endif
    }

    // MARK: Moving a window in the room

    /// A scroll on a title bar pushes the window away from the viewer or
    /// pulls it closer, along the line between them — the room's version
    /// of dragging a window around.
    func _desktop3DScroll(_ winId: String, delta: Double) {
        guard _desktop3DOn, delta != 0,
              let win = windowManager.windows.first(where: { $0.id == winId }),
              win.pose3D.placed else { return }
        let c = _camera3D
        var p = win.pose3D
        let dx = p.x - c.x, dy = p.y - c.y, dz = p.z - c.z
        let len = (dx * dx + dy * dy + dz * dz).squareRoot()
        guard len > 0.05 else { return }
        let next = min(12.0, max(0.9, len + (delta > 0 ? 0.25 : -0.25)))
        guard next != len else { return }
        let k = next / len
        p.x = c.x + dx * k; p.y = c.y + dy * k; p.z = c.z + dz * k
        setState { win.pose3D = p }
    }
}
