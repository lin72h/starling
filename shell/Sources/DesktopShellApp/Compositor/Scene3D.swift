// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

// MARK: - Scene3D — the wallpaper, reconstructed as a place
//
// Not a picture on a wall and not a modelled room: the photograph itself,
// turned back into the three-dimensional scene it was taken of. Every
// point of the image is put back along the ray the camera saw it on, at
// the distance the depth map says it was — so the water is at your feet,
// the bridge is a long way off, and the sky is further still. Standing at
// the spot the photograph was taken from, the reconstruction is the
// photograph, pixel for pixel. Take one step and it is a place.
//
// Two things make that work rather than fall apart:
//
// 1. DEPTH, NOT DISPARITY. The model gives relative inverse depth, where
//    everything past the foreground is squashed into the bottom tenth of
//    the range. Inverted into actual distance it opens back out: the same
//    numbers that looked like "a ground plane and nothing else" put the
//    water at 3 m and the sky at 400.
//
// 2. CUT THE SHEET AT THE EDGES. A grid stretched over a depth
//    discontinuity spans from the bridge tower to the sky behind it and
//    smears across the gap as the viewer moves — the one artefact that
//    gives this technique away. Quads whose corners disagree about depth
//    are dropped, and a copy of the whole image sits far behind to show
//    through the holes they leave.
//
// Vertex: pos(3) uv(2) mat(1) disparity(1) = 7 floats. The disparity is
// carried through so the shader knows sky from water from structure, which
// is what lets the sky get clouds and the water get a moving moonlit
// surface without anyone hand-painting a mask.

struct Scene3D {

    /// Where the nearest and furthest of the picture end up, in metres.
    /// The spread between them is the whole feel of the place: too little
    /// and it is a flat photo again, too much and a step across the room
    /// tears the foreground off the background.
    static let near = 3.2
    static let far = 420.0
    /// A quad whose corners disagree by more than this ratio is a
    /// silhouette, not a surface, and is dropped.
    static let cutRatio = 1.7
    /// How far behind the furthest point the hole-filling copy sits.
    static let backdropScale = 1.35

    static let floatsPerVertex = 7

    /// Distance for a disparity value, 1 = nearest.
    static func distance(_ d: Double) -> Double {
        let a = 1 / near - 1 / far
        return 1 / (a * max(0, min(1, d)) + 1 / far)
    }

    /// Build the scene from the depth grid and the lens it is seen with.
    /// `grid` is the depth map, top-down, 1 = nearest.
    static func build(grid: (values: [Float], cols: Int, rows: Int)?,
                      tanHalfFovX: Double, aspect: Double) -> [Float] {
        var v: [Float] = []
        v.reserveCapacity(600_000)
        let tx = tanHalfFovX, ty = tanHalfFovX / aspect

        /// The point the pixel at (u, v) sits at, `z` metres away — put
        /// back on the ray the photograph saw it on, which is what makes
        /// the reconstruction exact from the origin.
        func point(_ u: Double, _ w: Double, _ z: Double) -> (Double, Double, Double) {
            ((u - 0.5) * 2 * tx * z, (0.5 - w) * 2 * ty * z, -z)
        }
        func push(_ p: (Double, Double, Double), _ u: Double, _ w: Double,
                  _ mat: Double, _ d: Double = 0) {
            v += [Float(p.0), Float(p.1), Float(p.2),
                  Float(u), Float(w), Float(mat), Float(d)]
        }

        // The backdrop: the whole image, far behind everything, so the
        // holes the cuts leave show sky and water rather than nothing.
        let bz = far * backdropScale
        let b00 = point(0, 0, bz), b10 = point(1, 0, bz)
        let b01 = point(0, 1, bz), b11 = point(1, 1, bz)
        push(b00, 0, 0, 1); push(b10, 1, 0, 1); push(b01, 0, 1, 1)
        push(b10, 1, 0, 1); push(b11, 1, 1, 1); push(b01, 0, 1, 1)

        guard let g = grid, g.cols > 1, g.rows > 1 else { return v }

        // The surface itself, one quad per depth cell.
        let cols = g.cols, rows = g.rows
        func depth(_ i: Int, _ j: Int) -> Double {
            Double(g.values[min(rows - 1, max(0, j)) * cols + min(cols - 1, max(0, i))])
        }
        for j in 0..<(rows - 1) {
            for i in 0..<(cols - 1) {
                let d00 = depth(i, j), d10 = depth(i + 1, j)
                let d01 = depth(i, j + 1), d11 = depth(i + 1, j + 1)
                let z00 = distance(d00), z10 = distance(d10)
                let z01 = distance(d01), z11 = distance(d11)
                let lo = min(min(z00, z10), min(z01, z11))
                let hi = max(max(z00, z10), max(z01, z11))
                // A silhouette, not a surface.
                if hi > lo * cutRatio { continue }
                let u0 = Double(i) / Double(cols - 1), u1 = Double(i + 1) / Double(cols - 1)
                let w0 = Double(j) / Double(rows - 1), w1 = Double(j + 1) / Double(rows - 1)
                let p00 = point(u0, w0, z00), p10 = point(u1, w0, z10)
                let p01 = point(u0, w1, z01), p11 = point(u1, w1, z11)
                push(p00, u0, w0, 0, d00); push(p10, u1, w0, 0, d10)
                push(p01, u0, w1, 0, d01)
                push(p10, u1, w0, 0, d10); push(p11, u1, w1, 0, d11)
                push(p01, u0, w1, 0, d01)
            }
        }
        return v
    }
}
#endif
