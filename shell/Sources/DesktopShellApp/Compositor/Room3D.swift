// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

// MARK: - Room3D — the room the 3D desktop stands in
//
// The room is not built here. It is baked by `build/tools/room-import.py`
// into one file that is checked in: the shell's own geometry (floor,
// walls, ceiling, the wall of windows), the furniture — real meshes from
// Poly Haven's CC0 library, because hand-modelled boxes read as
// polystyrene however well they are lit — and the LIGHT, which is
// ambient occlusion and daylight traced against the real triangles and
// written into the vertices.
//
// So this file does nothing but read it. That split is the point: the
// room can be reworked and re-lit without rebuilding the shell, and the
// shell has nothing to get wrong at runtime.
//
// Vertex: pos(3) nrm(3) uv(2) ao(1) sun(1) mat(1) = 11 floats.

struct Room3D {

    /// The room's shape, which the camera's bounds need to know. Must
    /// match the constants at the top of `room-import.py`.
    static let width = 8.0
    static let height = 3.0
    static let depth = 10.0
    static var halfW: Double { width / 2 }

    /// What the shader does with each vertex. 0 means "look it up in the
    /// atlas"; the rest are procedural, because a floor and a wall want
    /// to tile and an atlas cannot.
    static let matAtlas: Float = 0

    struct Asset {
        var vertices: [Float]
        var indices: [UInt32]
        var floatsPerVertex: Int
        /// The sky's light: nine spherical-harmonic coefficients (RGB
        /// each) that reproduce how it lights a surface facing any
        /// direction, and the sun's direction and colour. Computed from
        /// the HDRI at bake time, so the room and the view out of its
        /// windows are lit by the same sky.
        var sh: [Float] = []
        var sunDir: (Float, Float, Float) = (0, 1, 0)
        var sunColour: (Float, Float, Float) = (1, 1, 1)
        /// What the packed sky texture's alpha channel multiplies by.
        var skyRange: Float = 12
    }

    /// Read the baked room. `STARROOM`, a version, counts, then the two
    /// arrays back to back.
    static func loadMesh(_ path: String) -> Asset? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              data.count > 24 else { return nil }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Asset? in
            guard let base = raw.baseAddress else { return nil }
            let magic = Data(bytes: base, count: 8)
            guard magic == Data("STARROOM".utf8) else { return nil }
            let version = base.loadUnaligned(fromByteOffset: 8, as: UInt32.self)
            let vCount = Int(base.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
            let iCount = Int(base.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
            let stride = Int(base.loadUnaligned(fromByteOffset: 20, as: UInt32.self))
            guard version == 2, vCount > 0, iCount > 0, stride == 11 else { return nil }
            // Version 2's header is followed by the sky's light: 9 SH
            // triples, the sun's direction and colour, and the sky
            // texture's range. 34 floats.
            let lightFloats = 9 * 3 + 3 + 3 + 1
            let lightBytes = lightFloats * 4
            let vBytes = vCount * stride * 4, iBytes = iCount * 4
            guard data.count >= 24 + lightBytes + vBytes + iBytes else { return nil }
            var light = [Float](repeating: 0, count: lightFloats)
            light.withUnsafeMutableBytes { memcpy($0.baseAddress!, base + 24, lightBytes) }
            let vOff = 24 + lightBytes
            let verts = [Float](unsafeUninitializedCapacity: vCount * stride) { buf, n in
                memcpy(buf.baseAddress!, base + vOff, vBytes); n = vCount * stride
            }
            let idx = [UInt32](unsafeUninitializedCapacity: iCount) { buf, n in
                memcpy(buf.baseAddress!, base + vOff + vBytes, iBytes); n = iCount
            }
            return Asset(vertices: verts, indices: idx, floatsPerVertex: stride,
                         sh: Array(light[0..<27]),
                         sunDir: (light[27], light[28], light[29]),
                         sunColour: (light[30], light[31], light[32]),
                         skyRange: light[33])
        }
    }
}
#endif
