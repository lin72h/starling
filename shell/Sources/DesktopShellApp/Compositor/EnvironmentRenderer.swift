// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

// MARK: - EnvironmentRenderer (the 3D desktop's tier-0 environment)
//
// The wallpaper becomes a place: a wall wrapped part-way around the viewer,
// its edges continued and darkened past the picture, and a wet floor
// reflecting its lower third. It renders into the texture the wallpaper's
// widget slot shows while 3D is on, on the raster thread inside the
// engine's external-texture callback (GLRenderer's contract), reading the
// wallpaper's own uploaded GL texture as its one source.
//
// The unfold is geometric: every vertex carries two positions — where it
// sits on a flat quad that exactly fills the view, and where it sits on
// the cylinder — and the vertex shader mixes them by `t`. At t = 0 the
// output is the flat wallpaper (so entering starts from what was on
// screen), at t = 1 it is the room. The floor collapses onto the wall's
// bottom edge at t = 0 and grows out of it.
//
// GL state: the engine calls resetContext(kAll_GrBackendState) after every
// external-texture callback, so nothing set here leaks into Skia's cache;
// the FBO binding and viewport are still restored out of courtesy.

private typealias GLGenBuffersFunc = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLBindBufferFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLBufferDataFunc = @convention(c) (UInt32, Int, UnsafeRawPointer?, UInt32) -> Void
private typealias GLCreateShaderFunc = @convention(c) (UInt32) -> UInt32
private typealias GLShaderSourceFunc = @convention(c) (UInt32, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafePointer<Int32>?) -> Void
private typealias GLCompileShaderFunc = @convention(c) (UInt32) -> Void
private typealias GLGetShaderivFunc = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<Int32>?) -> Void
private typealias GLGetShaderInfoLogFunc = @convention(c) (UInt32, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<CChar>?) -> Void
private typealias GLCreateProgramFunc = @convention(c) () -> UInt32
private typealias GLAttachShaderFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLLinkProgramFunc = @convention(c) (UInt32) -> Void
private typealias GLGetProgramivFunc = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<Int32>?) -> Void
private typealias GLGetProgramInfoLogFunc = @convention(c) (UInt32, Int32, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<CChar>?) -> Void
private typealias GLUseProgramFunc = @convention(c) (UInt32) -> Void
private typealias GLGetAttribLocationFunc = @convention(c) (UInt32, UnsafePointer<CChar>?) -> Int32
private typealias GLGetUniformLocationFunc = @convention(c) (UInt32, UnsafePointer<CChar>?) -> Int32
private typealias GLUniform1fFunc = @convention(c) (Int32, Float) -> Void
private typealias GLUniform1iFunc = @convention(c) (Int32, Int32) -> Void
private typealias GLUniformMatrix4fvFunc = @convention(c) (Int32, Int32, UInt8, UnsafePointer<Float>?) -> Void
private typealias GLVertexAttribPointerFunc = @convention(c) (UInt32, Int32, UInt32, UInt8, Int32, UnsafeRawPointer?) -> Void
private typealias GLEnableVertexAttribArrayFunc = @convention(c) (UInt32) -> Void
private typealias GLDrawArraysFunc = @convention(c) (UInt32, Int32, Int32) -> Void
private typealias GLActiveTextureFunc = @convention(c) (UInt32) -> Void
private typealias GLBindTextureFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLTexParameteriFunc = @convention(c) (UInt32, UInt32, Int32) -> Void
private typealias GLGenerateMipmapFunc = @convention(c) (UInt32) -> Void
private typealias GLGetErrorFunc = @convention(c) () -> UInt32
private typealias GLGenFramebuffersFunc = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLBindFramebufferFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLFramebufferTexture2DFunc = @convention(c) (UInt32, UInt32, UInt32, UInt32, Int32) -> Void
private typealias GLViewportFunc = @convention(c) (Int32, Int32, Int32, Int32) -> Void
private typealias GLClearColorFunc = @convention(c) (Float, Float, Float, Float) -> Void
private typealias GLClearFunc = @convention(c) (UInt32) -> Void
private typealias GLEnableFunc = @convention(c) (UInt32) -> Void
private typealias GLDisableFunc = @convention(c) (UInt32) -> Void
private typealias GLFlushFunc = @convention(c) () -> Void
private typealias GLGetIntegervFunc = @convention(c) (UInt32, UnsafeMutablePointer<Int32>?) -> Void
private typealias GLGenVertexArraysFunc = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLReadPixelsFunc = @convention(c) (Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeMutableRawPointer?) -> Void
private typealias GLBindVertexArrayFunc = @convention(c) (UInt32) -> Void

private let GL_ARRAY_BUFFER: UInt32 = 0x8892
private let GL_STATIC_DRAW: UInt32 = 0x88E4
private let GL_VERTEX_SHADER: UInt32 = 0x8B31
private let GL_FRAGMENT_SHADER: UInt32 = 0x8B30
private let GL_COMPILE_STATUS: UInt32 = 0x8B81
private let GL_LINK_STATUS: UInt32 = 0x8B82
private let GL_FLOAT: UInt32 = 0x1406
private let GL_TRIANGLES: UInt32 = 0x0004
private let GL_TEXTURE0: UInt32 = 0x84C0
private let GL_TEXTURE_2D: UInt32 = 0x0DE1
private let GL_TEXTURE_MIN_FILTER: UInt32 = 0x2801
private let GL_TEXTURE_MAG_FILTER: UInt32 = 0x2800
private let GL_TEXTURE_WRAP_S: UInt32 = 0x2802
private let GL_TEXTURE_WRAP_T: UInt32 = 0x2803
private let GL_CLAMP_TO_EDGE: Int32 = 0x812F
private let GL_LINEAR: Int32 = 0x2601
private let GL_LINEAR_MIPMAP_LINEAR: Int32 = 0x2703
private let GL_FRAMEBUFFER: UInt32 = 0x8D40
private let GL_COLOR_ATTACHMENT0: UInt32 = 0x8CE0
private let GL_FRAMEBUFFER_BINDING: UInt32 = 0x8CA6
private let GL_VIEWPORT: UInt32 = 0x0BA2
private let GL_COLOR_BUFFER_BIT: UInt32 = 0x4000
private let GL_SCISSOR_TEST: UInt32 = 0x0C11
private let GL_DEPTH_TEST: UInt32 = 0x0B71
private let GL_BLEND: UInt32 = 0x0BE2
private let GL_CULL_FACE: UInt32 = 0x0B44
private let GL_STENCIL_TEST: UInt32 = 0x0B90

/// What the platform thread last decided the camera should be. Read on the
/// raster thread under the renderer's lock.
struct EnvironmentCamera: Equatable {
    /// 0 = the flat wallpaper, 1 = the room. Follows the enter/leave tween.
    var t: Double = 0
    /// Pointer parallax: where the eye has moved, in [-1, 1] of its travel.
    /// A translation, not a rotation — a rotation shifts everything by the
    /// same angle and nothing slides against anything; moving the eye makes
    /// the near floor slide against the far wall.
    var panX: Double = 0
    var panY: Double = 0
}

final class EnvironmentRenderer: GLRenderer {

    // MARK: Tuning (world units: the flat quad sits 1.0 in front of the eye)

    /// The lens, shared with the windows' arc so the two agree on where
    /// "straight ahead" converges: tan(fovX/2) = 0.5 / k3DFocalScreens.
    static let kTanHalfFovX = 0.5 / 1.5
    /// How much wider than the view the wrapped wallpaper is: > 1 leaves
    /// wall for the parallax to reveal, < 2 keeps it from reading as a zoom.
    static let kWrapOverscan = 1.35
    /// Radius of the cylinder the wall wraps onto (the flat quad is at 1).
    static let kWallRadius = 1.0
    /// The wall's vertical centre, as a fraction of its own height above
    /// the eye line — leaves room under it for the floor.
    static let kWallLift = 0.18
    /// How far the floor comes toward the eye, as a fraction of the radius.
    static let kFloorReach = 0.85
    /// Fraction of the wallpaper's height the floor reflects.
    static let kFloorReflect = 0.34
    /// Past the picture, the wall carries on this far (in wallpaper widths)
    /// as the picture's own edge, blurred and darkened.
    static let kEdgeExtend = 0.35
    /// The eye's full parallax travel, in world units: 2% of the flat
    /// quad's width per unit of pan (the wall at distance 1 shifts by that;
    /// the floor's near edge, much closer, by several times more).
    static let kEyeTravel = 0.02 * 2 * kTanHalfFovX

    /// Called on the raster thread with the GL context current: the
    /// wallpaper's texture name and size, or nil while it is not uploaded.
    var sourceTexture: (() -> (name: UInt32, width: Int, height: Int)?)?

    private let cameraLock = NSLock()
    private var _camera = EnvironmentCamera()
    /// Rebuild the meshes when the source's aspect changes.
    private var meshAspect: Double = 0

    // GL objects (raster thread only)
    private var glReady = false
    private var program: UInt32 = 0
    private var vbo: UInt32 = 0
    private var vao: UInt32 = 0
    private var fbo: UInt32 = 0
    private var vertexCount: Int32 = 0
    private var mipmapped: Set<UInt32> = []
    private var aPosFlat: Int32 = -1, aPosWrap: Int32 = -1, aUV: Int32 = -1, aKind: Int32 = -1
    private var uProj: Int32 = -1, uView: Int32 = -1, uT: Int32 = -1, uTex: Int32 = -1
    private var uMip: Int32 = -1

    private var _glGenBuffers: GLGenBuffersFunc!
    private var _glBindBuffer: GLBindBufferFunc!
    private var _glBufferData: GLBufferDataFunc!
    private var _glCreateShader: GLCreateShaderFunc!
    private var _glShaderSource: GLShaderSourceFunc!
    private var _glCompileShader: GLCompileShaderFunc!
    private var _glGetShaderiv: GLGetShaderivFunc!
    private var _glGetShaderInfoLog: GLGetShaderInfoLogFunc!
    private var _glCreateProgram: GLCreateProgramFunc!
    private var _glAttachShader: GLAttachShaderFunc!
    private var _glLinkProgram: GLLinkProgramFunc!
    private var _glGetProgramiv: GLGetProgramivFunc!
    private var _glGetProgramInfoLog: GLGetProgramInfoLogFunc!
    private var _glUseProgram: GLUseProgramFunc!
    private var _glGetAttribLocation: GLGetAttribLocationFunc!
    private var _glGetUniformLocation: GLGetUniformLocationFunc!
    private var _glUniform1f: GLUniform1fFunc!
    private var _glUniform1i: GLUniform1iFunc!
    private var _glUniformMatrix4fv: GLUniformMatrix4fvFunc!
    private var _glVertexAttribPointer: GLVertexAttribPointerFunc!
    private var _glEnableVertexAttribArray: GLEnableVertexAttribArrayFunc!
    private var _glDrawArrays: GLDrawArraysFunc!
    private var _glActiveTexture: GLActiveTextureFunc!
    private var _glBindTexture: GLBindTextureFunc!
    private var _glTexParameteri: GLTexParameteriFunc!
    private var _glGenerateMipmap: GLGenerateMipmapFunc!
    private var _glGetError: GLGetErrorFunc!
    private var _glGenFramebuffers: GLGenFramebuffersFunc!
    private var _glBindFramebuffer: GLBindFramebufferFunc!
    private var _glFramebufferTexture2D: GLFramebufferTexture2DFunc!
    private var _glViewport: GLViewportFunc!
    private var _glClearColor: GLClearColorFunc!
    private var _glClear: GLClearFunc!
    private var _glEnable: GLEnableFunc!
    private var _glDisable: GLDisableFunc!
    private var _glFlush: GLFlushFunc!
    private var _glGetIntegerv: GLGetIntegervFunc!
    private var _glGenVertexArrays: GLGenVertexArraysFunc?
    private var _glReadPixels: GLReadPixelsFunc!
    /// STARLING_3D_DUMP=<path>: write the rendered environment as a PPM
    /// after each render, for looking at the room without the desktop
    /// drawn over it.
    private let dumpPath = ProcessInfo.processInfo.environment["STARLING_3D_DUMP"]
    private var _glBindVertexArray: GLBindVertexArrayFunc?

    // MARK: Platform thread

    /// Publish a camera; the next engine frame re-renders with it.
    func setCamera(_ cam: EnvironmentCamera) -> Bool {
        cameraLock.lock()
        defer { cameraLock.unlock() }
        if cam == _camera { return false }
        _camera = cam
        dirty = true
        return true
    }

    var camera: EnvironmentCamera {
        cameraLock.lock(); defer { cameraLock.unlock() }
        return _camera
    }

    // MARK: Raster thread

    override func renderToTexture(_ textureName: UInt32) {
        dirty = false
        if !glReady { loadGL(); glReady = true }
        guard program != 0 else { return }
        let cam = camera

        var prevFbo: Int32 = 0
        _glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFbo)
        var prevViewport = [Int32](repeating: 0, count: 4)
        _glGetIntegerv(GL_VIEWPORT, &prevViewport)

        _glBindFramebuffer(GL_FRAMEBUFFER, fbo)
        _glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureName, 0)
        _glViewport(0, 0, Int32(width), Int32(height))
        _glDisable(GL_SCISSOR_TEST)
        _glDisable(GL_DEPTH_TEST)
        _glDisable(GL_BLEND)
        _glDisable(GL_CULL_FACE)
        _glDisable(GL_STENCIL_TEST)
        _glClearColor(0.02, 0.02, 0.03, 1.0)
        _glClear(GL_COLOR_BUFFER_BIT)

        if let src = sourceTexture?(), src.width > 0, src.height > 0 {
            let aspect = Double(src.width) / Double(src.height)
            if aspect != meshAspect { buildMesh(sourceAspect: aspect); meshAspect = aspect }

            _glActiveTexture(GL_TEXTURE0)
            _glBindTexture(GL_TEXTURE_2D, src.name)
            // Mip chain once per source: the floor and the edge extension
            // sample it with an LOD bias, which is the cheapest blur there is.
            var canMip = mipmapped.contains(src.name)
            if !canMip {
                _ = _glGetError()
                _glGenerateMipmap(GL_TEXTURE_2D)
                canMip = _glGetError() == 0
                if canMip { mipmapped.insert(src.name) }
            }
            _glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
                             canMip ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR)
            _glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
            _glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            _glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

            _glUseProgram(program)
            _glBindVertexArray?(vao)
            _glBindBuffer(GL_ARRAY_BUFFER, vbo)
            let stride = Int32(9 * MemoryLayout<Float>.size)
            func attrib(_ loc: Int32, _ n: Int32, _ offsetFloats: Int) {
                guard loc >= 0 else { return }
                _glEnableVertexAttribArray(UInt32(loc))
                _glVertexAttribPointer(UInt32(loc), n, GL_FLOAT, 0, stride,
                                       UnsafeRawPointer(bitPattern: offsetFloats * MemoryLayout<Float>.size))
            }
            attrib(aPosFlat, 3, 0); attrib(aPosWrap, 3, 3); attrib(aUV, 2, 6); attrib(aKind, 1, 8)

            var proj = Self.projection(aspect: Double(width) / Double(height))
            var view = Self.view(panX: cam.panX * cam.t, panY: cam.panY * cam.t)
            _glUniformMatrix4fv(uProj, 1, 0, &proj)
            _glUniformMatrix4fv(uView, 1, 0, &view)
            _glUniform1f(uT, Float(cam.t))
            _glUniform1f(uMip, canMip ? 1.0 : 0.0)
            _glUniform1i(uTex, 0)
            _glDrawArrays(GL_TRIANGLES, 0, vertexCount)
            _glBindBuffer(GL_ARRAY_BUFFER, 0)
            _glBindVertexArray?(0)
            _glUseProgram(0)
            _glBindTexture(GL_TEXTURE_2D, 0)
        }
        _glFlush()
        if let path = dumpPath { dump(to: path) }
        _glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0)
        _glBindFramebuffer(GL_FRAMEBUFFER, UInt32(prevFbo))
        _glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3])
    }

    private func dump(to path: String) {
        let w = width, h = height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        rgba.withUnsafeMutableBytes { buf in
            _glReadPixels(0, 0, Int32(w), Int32(h), 0x1908 /* GL_RGBA */, 0x1401 /* GL_UNSIGNED_BYTE */, buf.baseAddress)
        }
        var ppm = Data("P6\n\(w) \(h)\n255\n".utf8)
        var rgb = [UInt8](repeating: 0, count: w * h * 3)
        // As the engine shows it: GL's last row is the top of the screen.
        for y in 0..<h {
            for x in 0..<w {
                let s = ((h - 1 - y) * w + x) * 4, d = (y * w + x) * 3
                rgb[d] = rgba[s]; rgb[d + 1] = rgba[s + 1]; rgb[d + 2] = rgba[s + 2]
            }
        }
        ppm.append(contentsOf: rgb)
        try? ppm.write(to: URL(fileURLWithPath: path))
    }

    // MARK: Geometry

    /// Column-major perspective with the shared lens. No y flip: the engine
    /// wraps an external GL texture bottom-left up, so GL's row 0 (clip
    /// y = -1) IS the bottom of the screen — measured, not assumed (the
    /// first build flipped it and drew the floor across the top).
    static func projection(aspect: Double) -> [Float] {
        let tx = kTanHalfFovX, ty = kTanHalfFovX / aspect
        let n = 0.05, f = 50.0
        var m = [Float](repeating: 0, count: 16)
        m[0] = Float(1 / tx)
        m[5] = Float(1 / ty)
        m[10] = Float(-(f + n) / (f - n))
        m[11] = -1
        m[14] = Float(-2 * f * n / (f - n))
        return m
    }

    /// The eye moved by (panX, panY) of its travel: the world shifts the
    /// other way. Pointer down the screen = eye down = the room rises.
    static func view(panX: Double, panY: Double) -> [Float] {
        var m = [Float](repeating: 0, count: 16)
        m[0] = 1; m[5] = 1; m[10] = 1; m[15] = 1
        m[12] = Float(-panX * kEyeTravel)
        m[13] = Float(panY * kEyeTravel)
        return m
    }

    /// The wall (flat → cylinder) and the floor (a line → a plane), as
    /// interleaved triangles: posFlat(3) posWrap(3) uv(2) kind(1).
    private func buildMesh(sourceAspect: Double) {
        let tx = Self.kTanHalfFovX
        let viewAspect = Double(width) / Double(height)
        let ty = tx / viewAspect
        // The wallpaper is cropped to the view's aspect by the shell, so the
        // flat quad IS the view: x ∈ [-tx, tx], y ∈ [-ty, ty] at z = -1.
        let R = Self.kWallRadius
        let arc = 2 * tx * Self.kWrapOverscan          // radians of wall the picture covers
        let wallH = arc * R / sourceAspect            // keeps the picture's aspect on the arc
        let wallC = wallH * Self.kWallLift            // vertical centre of the wall
        let ext = Self.kEdgeExtend
        var v: [Float] = []
        v.reserveCapacity(20000)
        func push(_ pf: (Double, Double, Double), _ pw: (Double, Double, Double), _ uv: (Double, Double), _ kind: Double) {
            v += [Float(pf.0), Float(pf.1), Float(pf.2), Float(pw.0), Float(pw.1), Float(pw.2),
                  Float(uv.0), Float(uv.1), Float(kind)]
        }
        // Wall: u from -ext to 1+ext (past the picture on both sides),
        // 96 columns, 24 rows.
        let cols = 96, rows = 24
        func wallVertex(_ i: Int, _ j: Int) -> ((Double, Double, Double), (Double, Double, Double), (Double, Double)) {
            let u = -ext + (1 + 2 * ext) * Double(i) / Double(cols)
            let vv = Double(j) / Double(rows)                       // 0 = top
            // Flat: the picture fills the view; the extension continues past it.
            let fx = (u - 0.5) * 2 * tx
            let fy = (0.5 - vv) * 2 * ty
            // Wrapped: angle across the arc, height on the cylinder.
            let ang = (u - 0.5) * arc
            let wx = R * sin(ang), wz = -R * cos(ang)
            let wy = wallC + (0.5 - vv) * wallH
            return ((fx, fy, -1.0), (wx, wy, wz), (u, vv))
        }
        for j in 0..<rows {
            for i in 0..<cols {
                let a = wallVertex(i, j), b = wallVertex(i + 1, j)
                let c = wallVertex(i, j + 1), d = wallVertex(i + 1, j + 1)
                push(a.0, a.1, a.2, 0); push(b.0, b.1, b.2, 0); push(c.0, c.1, c.2, 0)
                push(b.0, b.1, b.2, 0); push(d.0, d.1, d.2, 0); push(c.0, c.1, c.2, 0)
            }
        }
        // Floor: from the wall's bottom edge toward the eye. kind = 1 + reach
        // (0 at the wall, 1 nearest the eye) so the fragment shader can fade.
        let floorY = wallC - wallH / 2
        let frows = 16
        func floorVertex(_ i: Int, _ j: Int) -> ((Double, Double, Double), (Double, Double, Double), (Double, Double), Double) {
            let u = -ext + (1 + 2 * ext) * Double(i) / Double(cols)
            let reach = Double(j) / Double(frows)                  // 0 = at the wall
            let ang = (u - 0.5) * arc
            let radius = R * (1 - reach * Self.kFloorReach)
            let wx = radius * sin(ang), wz = -radius * cos(ang)
            // Flat: collapsed onto the quad's bottom edge.
            let fx = (u - 0.5) * 2 * tx
            // Reflection: the wall's lower part, mirrored.
            let vv = 1.0 - reach * Self.kFloorReflect
            return ((fx, -ty, -1.0), (wx, floorY, wz), (u, vv), 1 + reach)
        }
        for j in 0..<frows {
            for i in 0..<cols {
                let a = floorVertex(i, j), b = floorVertex(i + 1, j)
                let c = floorVertex(i, j + 1), d = floorVertex(i + 1, j + 1)
                push(a.0, a.1, a.2, a.3); push(b.0, b.1, b.2, b.3); push(c.0, c.1, c.2, c.3)
                push(b.0, b.1, b.2, b.3); push(d.0, d.1, d.2, d.3); push(c.0, c.1, c.2, c.3)
            }
        }
        vertexCount = Int32(v.count / 9)
        _glBindBuffer(GL_ARRAY_BUFFER, vbo)
        v.withUnsafeBytes { buf in
            _glBufferData(GL_ARRAY_BUFFER, buf.count, buf.baseAddress, GL_STATIC_DRAW)
        }
        _glBindBuffer(GL_ARRAY_BUFFER, 0)
    }

    // MARK: GL setup

    private static let vertexSource = """
    #version 100
    attribute vec3 aPosFlat;
    attribute vec3 aPosWrap;
    attribute vec2 aUV;
    attribute float aKind;
    uniform mat4 uProj;
    uniform mat4 uView;
    // Shared with the fragment stage, so the precision must match it
    // (GLSL ES 1.00 refuses to link otherwise).
    uniform mediump float uT;
    varying vec2 vUV;
    varying float vKind;
    void main() {
        vec3 p = mix(aPosFlat, aPosWrap, uT);
        gl_Position = uProj * uView * vec4(p, 1.0);
        vUV = aUV;
        vKind = aKind;
    }
    """

    private static let fragmentSource = """
    #version 100
    precision mediump float;
    uniform sampler2D uTex;
    uniform float uT;
    uniform float uMip;
    varying vec2 vUV;
    varying float vKind;
    void main() {
        // Past the picture's sides: its own edge, blurred and darkened.
        float beyond = max(0.0, max(-vUV.x, vUV.x - 1.0));
        // The wallpaper texture's row 0 is the picture's BOTTOM (the same
        // bottom-left convention the engine shows it with), so v runs up.
        vec2 uv = vec2(clamp(vUV.x, 0.0, 1.0), 1.0 - clamp(vUV.y, 0.0, 1.0));
        float isFloor = step(1.0, vKind);
        float reach = clamp(vKind - 1.0, 0.0, 1.0);
        float bias = uMip * (beyond * 14.0 + isFloor * (2.5 + reach * 3.0)) * uT;
        vec4 c = texture2D(uTex, uv, bias);
        float sideDark = 1.0 - smoothstep(0.0, 0.3, beyond) * 0.85 * uT;
        // The wet floor: dim, and fading to dark toward the viewer.
        float floorShade = mix(1.0, 0.55 * (1.0 - reach * 0.9), isFloor * uT);
        gl_FragColor = vec4(c.rgb * sideDark * floorShade, 1.0);
    }
    """

    private func loadGL() {
        func load<T>(_ name: String) -> T {
            guard let resolver = glProcAddressResolver else {
                fatalError("[EnvironmentRenderer] no GL proc address resolver")
            }
            guard let fn = name.withCString({ resolver($0) }) else {
                fatalError("[EnvironmentRenderer] missing GL function \(name)")
            }
            return unsafeBitCast(fn, to: T.self)
        }
        func tryLoad<T>(_ name: String) -> T? {
            guard let resolver = glProcAddressResolver,
                  let fn = name.withCString({ resolver($0) }) else { return nil }
            return unsafeBitCast(fn, to: T.self)
        }
        _glGenBuffers = load("glGenBuffers")
        _glBindBuffer = load("glBindBuffer")
        _glBufferData = load("glBufferData")
        _glCreateShader = load("glCreateShader")
        _glShaderSource = load("glShaderSource")
        _glCompileShader = load("glCompileShader")
        _glGetShaderiv = load("glGetShaderiv")
        _glGetShaderInfoLog = load("glGetShaderInfoLog")
        _glCreateProgram = load("glCreateProgram")
        _glAttachShader = load("glAttachShader")
        _glLinkProgram = load("glLinkProgram")
        _glGetProgramiv = load("glGetProgramiv")
        _glGetProgramInfoLog = load("glGetProgramInfoLog")
        _glUseProgram = load("glUseProgram")
        _glGetAttribLocation = load("glGetAttribLocation")
        _glGetUniformLocation = load("glGetUniformLocation")
        _glUniform1f = load("glUniform1f")
        _glUniform1i = load("glUniform1i")
        _glUniformMatrix4fv = load("glUniformMatrix4fv")
        _glVertexAttribPointer = load("glVertexAttribPointer")
        _glEnableVertexAttribArray = load("glEnableVertexAttribArray")
        _glDrawArrays = load("glDrawArrays")
        _glActiveTexture = load("glActiveTexture")
        _glBindTexture = load("glBindTexture")
        _glTexParameteri = load("glTexParameteri")
        _glGenerateMipmap = load("glGenerateMipmap")
        _glGetError = load("glGetError")
        _glGenFramebuffers = load("glGenFramebuffers")
        _glBindFramebuffer = load("glBindFramebuffer")
        _glFramebufferTexture2D = load("glFramebufferTexture2D")
        _glViewport = load("glViewport")
        _glClearColor = load("glClearColor")
        _glClear = load("glClear")
        _glEnable = load("glEnable")
        _glDisable = load("glDisable")
        _glFlush = load("glFlush")
        _glGetIntegerv = load("glGetIntegerv")
        _glGenVertexArrays = tryLoad("glGenVertexArrays")
        _glReadPixels = load("glReadPixels")
        _glBindVertexArray = tryLoad("glBindVertexArray")

        var prevFbo: Int32 = 0
        _glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFbo)
        _glGenFramebuffers(1, &fbo)
        _glBindFramebuffer(GL_FRAMEBUFFER, UInt32(prevFbo))
        _glGenBuffers(1, &vbo)
        if let gen = _glGenVertexArrays { gen(1, &vao) }

        func compile(_ kind: UInt32, _ src: String) -> UInt32 {
            let sh = _glCreateShader(kind)
            src.withCString { cstr in
                var p: UnsafePointer<CChar>? = cstr
                withUnsafePointer(to: &p) { pp in _glShaderSource(sh, 1, pp, nil) }
            }
            _glCompileShader(sh)
            var ok: Int32 = 0
            _glGetShaderiv(sh, GL_COMPILE_STATUS, &ok)
            if ok == 0 {
                var log = [CChar](repeating: 0, count: 2048)
                var n: Int32 = 0
                _glGetShaderInfoLog(sh, 2048, &n, &log)
                let msg = "[EnvironmentRenderer] shader compile failed: \(String(cString: log))\n"
                FileHandle.standardError.write(Data(msg.utf8))
                return 0
            }
            return sh
        }
        let vs = compile(GL_VERTEX_SHADER, Self.vertexSource)
        let fs = compile(GL_FRAGMENT_SHADER, Self.fragmentSource)
        guard vs != 0, fs != 0 else { return }
        let prog = _glCreateProgram()
        _glAttachShader(prog, vs)
        _glAttachShader(prog, fs)
        _glLinkProgram(prog)
        var linked: Int32 = 0
        _glGetProgramiv(prog, GL_LINK_STATUS, &linked)
        guard linked != 0 else {
            var log = [CChar](repeating: 0, count: 2048)
            var n: Int32 = 0
            _glGetProgramInfoLog(prog, 2048, &n, &log)
            FileHandle.standardError.write(Data(
                "[EnvironmentRenderer] program link failed: \(String(cString: log))\n".utf8))
            return
        }
        program = prog
        aPosFlat = _glGetAttribLocation(prog, "aPosFlat")
        aPosWrap = _glGetAttribLocation(prog, "aPosWrap")
        aUV = _glGetAttribLocation(prog, "aUV")
        aKind = _glGetAttribLocation(prog, "aKind")
        uProj = _glGetUniformLocation(prog, "uProj")
        uView = _glGetUniformLocation(prog, "uView")
        uT = _glGetUniformLocation(prog, "uT")
        uTex = _glGetUniformLocation(prog, "uTex")
        uMip = _glGetUniformLocation(prog, "uMip")
        FileHandle.standardError.write(Data("[EnvironmentRenderer] ready \(width)x\(height)\n".utf8))
    }
}
#endif
