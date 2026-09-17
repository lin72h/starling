// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - The 3D desktop (docs/plans/desktop-3d.md)
//
// Two states, both persistent. 2D is today's desktop, pixel for pixel:
// every window slot is under an identity Transform (the plain-translation
// paint path, no layer, no resampling) and the wallpaper slot shows the
// wallpaper texture. 3D lifts every UNFOCUSED window onto an arc around
// the viewer — yawed to face the centre, pushed back so it reads as
// further away — while the focused window stays untransformed and
// pixel-exact (a 0.999 scale resamples text, identity does not), and the
// wallpaper's slot shows EnvironmentRenderer's room instead. Windows stay
// in the layer tree under a perspective Transform: the engine rasterises
// the external texture through the matrix, and RenderTransform's hit test
// runs the same matrix backwards with the homogeneous divide, so a click
// lands on the right client pixel with no new input code.
//
// `_desktop3DT` is the one number everything reads: 0 flat, 1 the room,
// tweened by a 600 ms controller on enter and leave. The poses scale
// with it, the environment unfolds with it, the camera's parallax fades
// with it — so the end of a leave is EXACTLY the flat desktop, not a
// near-identity that would resample every window for one frame.

/// What only 3D knows about a window. Kept beside `WindowInfo.rect`, never
/// derived from it and never written by 2D, so leaving 3D changes nothing
/// here and re-entering finds it again.
struct WindowPose3D: Equatable {
    /// How far back the window sits: 1 = the arc's own distance, more is
    /// further. A scroll on the title bar changes it.
    var depth: Double = 1.0
    static let range: ClosedRange<Double> = 0.6...2.5
}

/// The viewer, per output. Pointer parallax moves the eye a little; the
/// arc and the environment both read it, so they move together.
struct Camera3D: Equatable {
    /// Where the eye has moved, in [-1, 1] of its travel on each axis.
    var pan: Offset = Offset(0, 0)
}

extension _DesktopShellState {

    // MARK: Tuning

    /// The lens, in screen widths. Shorter is more dramatic and less
    /// readable; the environment renderer uses the same one.
    static let k3DFocalScreens = 1.5
    /// How far a window at the screen's edge turns toward the centre.
    static let k3DMaxYaw = 35.0 * Double.pi / 180
    /// The on-screen scale of an unfocused window's centre after the push
    /// back — visionOS neighbours read noticeably smaller than the focused
    /// pane, and the focused one is pixel-exact by rule.
    static let k3DNeighbourScale = 0.7
    /// The eye's full parallax travel, as a fraction of the screen width.
    static let k3DEyeTravel = 0.02
    /// Parallax steps across the screen, per axis. Quantised so a still
    /// pointer means a still camera — every step is a full recomposite.
    static let k3DParallaxSteps = 40
    static let k3DTransitionMs = 600

    var _desktop3DActive: Bool { _desktop3DT > 0 }

    // MARK: The pose

    /// The pose of an unfocused window whose on-screen rect is `rect`
    /// (global logical px), eased by `t`, seen from `camera`: a matrix over
    /// screen-centred coordinates plus the pivot those coordinates are
    /// centred on (in `rect`'s space — hand it to `Transform` as `origin`,
    /// made window-local). nil keeps the window flat: it is off the host,
    /// or its pose would cross the near plane — `Transform` does no
    /// near-plane clipping and Skia draws garbage past it.
    func _desktop3DPose(rect: Rect, t: Double, camera: Camera3D,
                        depth: Double) -> (matrix: Matrix4, pivot: Offset)? {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0, host.height > 0, rect.overlaps(host), t > 0 else { return nil }
        let pivot = host.center
        let wx = rect.center.dx - pivot.dx
        let wy = rect.center.dy - pivot.dy
        let focal = Self.k3DFocalScreens * host.width
        // Yaw grows with the distance from the centre column. rotationY(+θ)
        // maps +x toward -z, so a window on the right turns its right edge
        // AWAY from the viewer — it faces the centre.
        let yaw = max(-1.0, min(1.0, wx / (host.width / 2))) * Self.k3DMaxYaw * t
        // Pushed back until its centre projects at the neighbour scale
        // (w = 1 + push / focal, scale = 1 / w), times the window's depth.
        let push = focal * (1 / Self.k3DNeighbourScale - 1) * depth * t

        var m = Matrix4.identity()
        m.setEntry(3, 2, -1 / focal)   // perspective: w = 1 - z / focal
        // The eye moved: the world shifts the other way. Nearer things
        // shift more on screen than far ones, and the focused window (flat,
        // exempt) not at all — that difference is the parallax.
        let eye = Self.k3DEyeTravel * host.width * t
        m.translate(-camera.pan.dx * eye, -camera.pan.dy * eye, 0)
        m.translate(wx, wy, -push)     // the window's centre, pushed back...
        m.rotateY(yaw)                 // ...turned toward the viewer...
        m.translate(-wx, -wy, 0)       // ...about its own centre

        // Near-plane check on the four corners (screen-centred, z = 0).
        let l = rect.left - pivot.dx, r = rect.right - pivot.dx
        let tp = rect.top - pivot.dy, b = rect.bottom - pivot.dy
        let row3 = m.getRow(3)
        for (x, y) in [(l, tp), (r, tp), (l, b), (r, b)] {
            if row3.x * x + row3.y * y + row3.w <= 0.05 { return nil }
        }
        return (m, pivot)
    }

    // MARK: The mode

    /// Enter or leave, animated (600 ms) unless told otherwise. The choice
    /// persists like tiling and appearance.
    func _setDesktop3D(_ on: Bool, animated: Bool = true) {
        if on == _desktop3DOn, animated { return }
        _desktop3DOn = on
        _desktop3DPersist()
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

    // MARK: The camera

    /// Pointer parallax: the eye follows the pointer a little, in steps.
    /// Hover only — a drag delivers move events, not hover, so the camera
    /// holds still while a window is being dragged.
    func _desktop3DPointerHover(_ pos: Offset) {
        guard _desktop3DOn || _desktop3DT > 0 else { return }
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0, host.height > 0 else { return }
        let half = Double(Self.k3DParallaxSteps) / 2
        let nx = max(-1.0, min(1.0, ((pos.dx - host.left) / host.width - 0.5) * 2))
        let ny = max(-1.0, min(1.0, ((pos.dy - host.top) / host.height - 0.5) * 2))
        let q = (Int((nx * half).rounded()), Int((ny * half).rounded()))
        if q == _cameraQuantum3D { return }
        _cameraQuantum3D = q
        let cam = Camera3D(pan: Offset(Double(q.0) / half, Double(q.1) / half))
        let hostId = displayLayout?.host.id ?? 0
        setState { _cameras3D[hostId] = cam }
        _desktop3DPublishCamera()
    }

    /// Hand the environment what the platform thread decided; it renders
    /// on the raster thread at the next engine frame.
    func _desktop3DPublishCamera() {
        #if os(Linux)
        guard let env = _environment, let registry = drmTextureRegistry,
              let wl = waylandIntegration, environmentTextureId >= 0 else { return }
        let cam = _cameras3D[displayLayout?.host.id ?? 0] ?? Camera3D()
        let changed = env.setCamera(EnvironmentCamera(
            t: _desktop3DT, panX: cam.pan.dx, panY: cam.pan.dy))
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
        _desktop3DPublishCamera()
        registry.markGLTextureDirty(engine: wl.engine, id: id)
        return true
        #else
        return false
        #endif
    }

    func _releaseEnvironment() {
        #if os(Linux)
        guard environmentTextureId >= 0, let registry = drmTextureRegistry,
              let wl = waylandIntegration else { return }
        registry.unregisterTexture(engine: wl.engine, id: environmentTextureId)
        environmentTextureId = -1
        _environment = nil
        #endif
    }

    // MARK: Window depth

    /// A scroll on a title bar pushes the window away or pulls it closer.
    /// Only the 3D desktop has a notion of depth; in 2D it is a no-op.
    func _desktop3DScroll(_ winId: String, delta: Double) {
        guard _desktop3DOn, delta != 0,
              let win = windowManager.windows.first(where: { $0.id == winId }) else { return }
        let factor = delta > 0 ? 1.08 : 1 / 1.08
        let next = min(WindowPose3D.range.upperBound,
                       max(WindowPose3D.range.lowerBound, win.pose3D.depth * factor))
        guard next != win.pose3D.depth else { return }
        setState { win.pose3D.depth = next }
    }
}
