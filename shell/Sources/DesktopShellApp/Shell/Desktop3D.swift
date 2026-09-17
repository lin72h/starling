// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - The 3D desktop, Phase 0 (docs/plans/desktop-3d.md)
//
// The spike: every unfocused window is lifted onto an arc around the viewer,
// yawed to face the screen centre and pushed back so it reads as further
// away; the focused window is untouched and pixel-exact (a 0.999 scale
// resamples text, identity does not). Windows stay in the layer tree under
// a perspective `Transform`: the engine rasterises the external texture
// through the matrix, and `RenderTransform.hitTestChildren` runs the same
// matrix backwards with the homogeneous divide, so a click lands on the
// right client pixel with no new input code. The wallpaper stays flat —
// the environment is Phase 1.

extension _DesktopShellState {

    /// The lens. Shorter is more dramatic and less readable; the note's
    /// starting point is 1.5 × the screen width.
    static let k3DFocalScreens = 1.5
    /// How far a window at the screen's edge turns toward the centre.
    static let k3DMaxYaw = 35.0 * Double.pi / 180
    /// The on-screen scale of an unfocused window's centre after the push
    /// back — visionOS neighbours read noticeably smaller than the focused
    /// pane. The focused window is pixel-exact by rule, so this is the only
    /// size question.
    static let k3DNeighbourScale = 0.7

    /// The pose of an unfocused window whose on-screen rect is `rect`
    /// (global logical px): a matrix over screen-centred coordinates, plus
    /// the pivot those coordinates are centred on (in `rect`'s space — hand
    /// it to `Transform` as `origin`, made window-local). nil keeps the
    /// window flat: it is off the host, or its pose would cross the near
    /// plane — `Transform` does no near-plane clipping and Skia draws
    /// garbage past it rather than clipping.
    func _desktop3DPose(rect: Rect) -> (matrix: Matrix4, pivot: Offset)? {
        let host = displayLayout?.host.logicalRect
            ?? Rect.fromLTWH(0, 0, screenWidth, screenHeight)
        guard host.width > 0, host.height > 0, rect.overlaps(host) else { return nil }
        let pivot = host.center
        // The window's centre relative to the screen's.
        let wx = rect.center.dx - pivot.dx
        let wy = rect.center.dy - pivot.dy
        let focal = Self.k3DFocalScreens * host.width
        // Yaw grows with the distance from the centre column. rotationY(+θ)
        // maps +x toward -z, so a window on the right turns its right edge
        // AWAY from the viewer — it faces the centre.
        let yaw = max(-1.0, min(1.0, wx / (host.width / 2))) * Self.k3DMaxYaw
        // Pushed back until its centre projects at the neighbour scale:
        // w = 1 + push / focal, scale = 1 / w.
        let push = focal * (1 / Self.k3DNeighbourScale - 1)

        var m = Matrix4.identity()
        m.setEntry(3, 2, -1 / focal)   // perspective: w = 1 - z / focal
        m.translate(wx, wy, -push)     // the window's centre, pushed back...
        m.rotateY(yaw)                 // ...turned toward the viewer...
        m.translate(-wx, -wy, 0)       // ...about its own centre

        // Near-plane check on the four corners (screen-centred, z = 0).
        let l = rect.left - pivot.dx, r = rect.right - pivot.dx
        let t = rect.top - pivot.dy, b = rect.bottom - pivot.dy
        let row3 = m.getRow(3)
        for (x, y) in [(l, t), (r, t), (l, b), (r, b)] {
            if row3.x * x + row3.y * y + row3.w <= 0.05 { return nil }
        }
        return (m, pivot)
    }
}
