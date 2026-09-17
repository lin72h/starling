// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

// MARK: - EnvironmentRenderer (the 3D desktop's tier-0 environment)
//
// The wallpaper becomes a place: the picture recedes to the far wall of a
// box, and the floor, ceiling and side walls grow out of its four edges
// and come toward the viewer, carrying the picture's own colours, blurred
// and falling away into the dark. The room is made OUT of the picture
// rather than framing it. It renders into the texture the wallpaper's
// widget slot shows while 3D is on, on the raster thread inside the
// engine's external-texture callback (GLRenderer's contract), reading the
// wallpaper's own uploaded GL texture as its one source.
//
// The unfold is geometric: every vertex carries two positions — where it
// sits on a flat quad that exactly fills the view, and where it sits in
// the room — and the vertex shader mixes them by `t`. At t = 0 the output
// IS the flat wallpaper: the back wall fills the view undimmed and the
// other four surfaces have collapsed onto the quad's edges, where they
// are zero-area and rasterise nothing.
//
// Why a box and not the cylinder this started as: a cylinder centred on
// the eye is depth-flat by construction — every point on it is exactly R
// from the viewer, so it has no parallax and no perspective, and through
// a desktop lens it is indistinguishable from the flat picture it was
// made from. No amount of tuning fixes that. A box has surfaces at
// genuinely different distances, which is the only thing that reads as
// depth on a monitor.
//
// The room is defined against the frustum rather than in world units, so
// what reaches the screen does not depend on the lens or on the wall's
// distance: `kRoomCover` — how much of the view the picture still fills
// once the room is open — is the knob that changes the picture.
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
    /// How far away the picture hangs. Only sets the scale: the room is
    /// built against the frustum, so the same image reaches the screen at
    /// any distance. It fixes what "world units" mean for the eye travel,
    /// and where the windows' arc sits relative to the wall (an unfocused
    /// window at depth 1 lands at 1/kNeighbourScale ≈ 1.43, comfortably
    /// in front of it).
    static let kWallDistance = 2.4
    /// How much of the view the picture still fills once the room is
    /// open. 1.0 would be the flat wallpaper and no room at all; much
    /// below 0.55 and the wallpaper stops being the subject of its own
    /// desktop. This is THE art-direction knob.
    static let kRoomCover = 0.66
    /// The picture's centre above the eye line, as a fraction of its own
    /// half-height: the eye sits low in the picture, so there is more
    /// floor than ceiling — which is what standing in a room looks like.
    static let kRoomLift = 0.14
    /// Where the room stops short of the eye, as a fraction of the wall's
    /// distance. Everything this near is far off the edges of the screen.
    static let kRoomNear = 0.02
    /// The relief: how far the NEAREST part of the picture is pulled off
    /// the wall toward the eye, as a fraction of the wall's distance. The
    /// displacement runs ALONG THE VIEW RAY, so the picture is unchanged
    /// from the home eye position however deep the relief is — it shows
    /// up only as parallax when the eye moves, and as real distance when
    /// something has to pass in front of or behind it.
    ///
    /// It can be this large because of what a depth map of a landscape
    /// photograph actually contains: a ground plane, and nothing else.
    /// Everything past the foreground really is at infinity, so there are
    /// no silhouettes for a big displacement to rubber-band.
    static let kRelief = 0.42
    /// The relief fades out over this fraction of the picture at the top
    /// and side edges, so the wall still meets the ceiling and side walls
    /// exactly where they expect it. NOT at the bottom: that edge is the
    /// near ground, which is the whole of the relief on a landscape, and
    /// cutting it there would fold the picture right where the eye is
    /// looking. The floor follows the wall's bottom edge instead.
    static let kReliefEdgeFade = 0.06
    /// Quads across the picture. The relief's silhouettes are only as
    /// sharp as this: a bridge tower a hundred pixels wide spans about
    /// eight quads at 192, which is enough that its edge does not visibly
    /// rubber-band under the parallax this camera has.
    static let kWallQuads = (192, 108)

    // Each surface other than the picture is (lit, fade, blur base, blur
    // reach): its brightness where it meets the picture, how fast it
    // falls into the dark as it comes toward the viewer, and the mip bias
    // it samples the picture with at the wall and at the near end. `lit`
    // near 1 matters — a surface that meets the picture at half
    // brightness draws a hard frame around it, and the picture stops
    // opening into the room and starts hanging on a wall.
    static let kFloorShade = (0.92, 2.6, 1.5, 3.0)
    static let kCeilShade = (0.75, 3.6, 2.5, 3.0)
    static let kSideShade = (0.92, 3.2, 2.0, 3.0)
    /// Fraction of the picture each surface mirrors as it comes forward:
    /// the floor shows its bottom band, the ceiling its top, the side
    /// walls their own columns.
    static let kFloorReflect = 0.34
    static let kCeilReflect = 0.20
    static let kSideReflect = 0.22
    /// The eye's full parallax travel, in world units: 3% of the flat
    /// quad's width per unit of pan. The wall at 2.4 shifts by a hundredth
    /// of that; the floor a step in front of the viewer, by half as much
    /// again — and that difference is the whole point. Matches
    /// `k3DEyeTravel`, which moves the windows by the same eye: an
    /// unfocused window sits at 1.43, between the two.
    static let kEyeTravel = 0.03 * 2 * kTanHalfFovX

    /// Called on the raster thread with the GL context current: the
    /// wallpaper's texture name and size, or nil while it is not uploaded.
    var sourceTexture: (() -> (name: UInt32, width: Int, height: Int)?)?

    /// The picture's relief, white nearest, top-down — read on the CPU
    /// when the mesh is built, never by GL, so no vertex texture fetch is
    /// needed and the whole thing costs one rebuild. nil is a flat wall
    /// (tier 0), which is what a wallpaper with no depth map gets.
    ///
    /// Written on the platform thread and read on the raster thread, so
    /// it lives under the same lock the camera does and the mesh builder
    /// takes a snapshot of it rather than reading it as it draws.
    var depthGrid: (values: [Float], cols: Int, rows: Int)? {
        get { cameraLock.lock(); defer { cameraLock.unlock() }; return _depthGrid }
        set {
            cameraLock.lock()
            _depthGrid = newValue
            _meshStale = true
            cameraLock.unlock()
            dirty = true
        }
    }
    private var _depthGrid: (values: [Float], cols: Int, rows: Int)?
    private var _meshStale = false

    /// True once, after the relief has changed: the mesh has to be rebuilt.
    private func takeMeshStale() -> Bool {
        cameraLock.lock(); defer { cameraLock.unlock() }
        let was = _meshStale
        _meshStale = false
        return was
    }

    private let cameraLock = NSLock()
    private var _camera = EnvironmentCamera()
    /// Rebuild the room when the VIEW's aspect changes. The source's own
    /// aspect does not enter: the shell crops the wallpaper to the view,
    /// so the picture is the view's shape at t = 0 and must stay it.
    private var meshAspect: Double = 0

    // GL objects (raster thread only)
    private var glReady = false
    private var program: UInt32 = 0
    private var vbo: UInt32 = 0
    private var vao: UInt32 = 0
    private var fbo: UInt32 = 0
    private var vertexCount: Int32 = 0
    private var mipmapped: Set<UInt32> = []
    private var aPosFlat: Int32 = -1, aPosRoom: Int32 = -1, aUV: Int32 = -1
    private var aFar: Int32 = -1, aShade: Int32 = -1
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
            let aspect = Double(width) / Double(height)
            if aspect != meshAspect || takeMeshStale() {
                buildMesh(viewAspect: aspect)
                meshAspect = aspect
            }

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
            let stride = Int32(Self.kFloatsPerVertex * MemoryLayout<Float>.size)
            func attrib(_ loc: Int32, _ n: Int32, _ offsetFloats: Int) {
                guard loc >= 0 else { return }
                _glEnableVertexAttribArray(UInt32(loc))
                _glVertexAttribPointer(UInt32(loc), n, GL_FLOAT, 0, stride,
                                       UnsafeRawPointer(bitPattern: offsetFloats * MemoryLayout<Float>.size))
            }
            attrib(aPosFlat, 3, 0); attrib(aPosRoom, 3, 3); attrib(aUV, 2, 6)
            attrib(aFar, 1, 8); attrib(aShade, 4, 9)

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

    /// Vertices are posFlat(3) posRoom(3) uv(2) far(1) shade(4).
    static let kFloatsPerVertex = 13

    /// The room: a box whose back wall is the picture, with the floor,
    /// ceiling and two side walls growing out of its edges toward the
    /// viewer. Every vertex carries where it sits on the flat quad that
    /// fills the view AND where it sits in the room; the vertex shader
    /// mixes the two by `t`. At t = 0 the four side surfaces have
    /// collapsed onto the quad's own edges — zero area, so they rasterise
    /// nothing — and the back wall is the flat wallpaper exactly.
    ///
    /// `far` is 1 where a surface meets the picture and falls to 0 at the
    /// viewer; the fragment shader dims and blurs by it, so the room
    /// leaves the picture at full brightness and sinks into the dark as
    /// it arrives. `uv` mirrors the picture's own edge forward, which is
    /// what makes the floor read as wet and the walls as lit by it.
    private func buildMesh(viewAspect: Double) {
        let tx = Self.kTanHalfFovX
        let ty = tx / viewAspect
        let dist = Self.kWallDistance
        let pw = Self.kRoomCover * dist * tx      // the picture, on the wall
        let ph = Self.kRoomCover * dist * ty
        let cy = Self.kRoomLift * ph              // its centre, above the eye
        let nz = Self.kRoomNear
        /// z of a side surface at `s`: 0 at the wall, 1 at the near end.
        func zAt(_ s: Double) -> Double { -dist * (1 - s * (1 - nz)) }
        func farAt(_ s: Double) -> Double { 1 - s * (1 - nz) }

        typealias Vert = ((Double, Double, Double), (Double, Double, Double),
                          (Double, Double), Double, (Double, Double, Double, Double))
        var v: [Float] = []
        v.reserveCapacity(300_000)
        func push(_ q: Vert) {
            v += [Float(q.0.0), Float(q.0.1), Float(q.0.2),
                  Float(q.1.0), Float(q.1.1), Float(q.1.2),
                  Float(q.2.0), Float(q.2.1), Float(q.3),
                  Float(q.4.0), Float(q.4.1), Float(q.4.2), Float(q.4.3)]
        }
        /// A surface over (a, b) ∈ [0,1]², as two triangles per cell.
        func grid(_ cols: Int, _ rows: Int, _ f: (Double, Double) -> Vert) {
            for j in 0..<rows {
                let b0 = Double(j) / Double(rows), b1 = Double(j + 1) / Double(rows)
                for i in 0..<cols {
                    let a0 = Double(i) / Double(cols), a1 = Double(i + 1) / Double(cols)
                    let p00 = f(a0, b0), p10 = f(a1, b0), p01 = f(a0, b1), p11 = f(a1, b1)
                    push(p00); push(p10); push(p01)
                    push(p10); push(p11); push(p01)
                }
            }
        }

        // The picture, on the back wall, given its relief. `w` runs down
        // from its top. The displacement is ALONG THE VIEW RAY — the room
        // point is simply scaled toward the eye — so from the home eye
        // position the picture is pixel-identical to a flat wall however
        // deep the relief is, and the shape only shows as parallax and as
        // real distance. Faded out at the edges so the wall still meets
        // the floor, ceiling and side walls where they join it.
        let relief = depthGrid          // one snapshot, off the lock
        func reliefScale(_ u: Double, _ w: Double) -> Double {
            guard let r = relief, r.cols > 1, r.rows > 1 else { return 1 }
            // Sides and top only — the bottom edge keeps its relief.
            let fade = max(0, min(1, min(min(u, 1 - u) / Self.kReliefEdgeFade,
                                         w / Self.kReliefEdgeFade)))
            guard fade > 0 else { return 1 }
            // Bilinear, so the relief is smooth between cells.
            let gx = min(Double(r.cols - 1), max(0, u * Double(r.cols) - 0.5))
            let gy = min(Double(r.rows - 1), max(0, w * Double(r.rows) - 0.5))
            let x0 = Int(gx), y0 = Int(gy)
            let x1 = min(r.cols - 1, x0 + 1), y1 = min(r.rows - 1, y0 + 1)
            let ax = gx - Double(x0), ay = gy - Double(y0)
            let d = (Double(r.values[y0 * r.cols + x0]) * (1 - ax)
                     + Double(r.values[y0 * r.cols + x1]) * ax) * (1 - ay)
                  + (Double(r.values[y1 * r.cols + x0]) * (1 - ax)
                     + Double(r.values[y1 * r.cols + x1]) * ax) * ay
            return 1 - Self.kRelief * d * fade
        }
        let (wallCols, wallRows) = Self.kWallQuads
        var kMin = 1.0, kMax = 1.0
        grid(relief == nil ? 4 : wallCols, relief == nil ? 4 : wallRows) { u, w in
            let x = (u - 0.5) * 2 * pw, y = cy + (0.5 - w) * 2 * ph
            let k = reliefScale(u, w)
            kMin = min(kMin, k); kMax = max(kMax, k)
            return (((u - 0.5) * 2 * tx, (0.5 - w) * 2 * ty, -1.0),
                    (x * k, y * k, -dist * k),
                    (u, w), 1.0, (1.0, 0.0, 0.0, 0.0))
        }
        // The floor, out of the picture's bottom edge: its lower band
        // mirrored forward, dimming as it comes. Its back edge follows the
        // wall's relief exactly — on a landscape that edge is the near
        // ground, so the water in the picture runs into the room's floor
        // with no seam and no fold — and levels off to the room's own
        // floor as it arrives at the viewer.
        grid(relief == nil ? 24 : 96, 16) { u, s in
            let far = farAt(s)
            let kw = reliefScale(u, 1.0)
            let k = kw + (1 - kw) * s
            return (((u - 0.5) * 2 * tx, -ty, -1.0),
                    ((u - 0.5) * 2 * pw * k, (cy - ph) * k, zAt(s) * k),
                    (u, 1 - (1 - far) * Self.kFloorReflect), far, Self.kFloorShade)
        }
        // The ceiling, out of its top edge.
        grid(24, 16) { u, s in
            let far = farAt(s)
            return (((u - 0.5) * 2 * tx, ty, -1.0),
                    ((u - 0.5) * 2 * pw, cy + ph, zAt(s)),
                    (u, (1 - far) * Self.kCeilReflect), far, Self.kCeilShade)
        }
        // The side walls, out of its left and right edges.
        for sgn in [-1.0, 1.0] {
            grid(16, 16) { s, w in
                let far = farAt(s)
                let edge = (1 - far) * Self.kSideReflect
                return ((sgn * tx, (0.5 - w) * 2 * ty, -1.0),
                        (sgn * pw, cy + (0.5 - w) * 2 * ph, zAt(s)),
                        (sgn < 0 ? edge : 1 - edge, w), far, Self.kSideShade)
            }
        }

        vertexCount = Int32(v.count / Self.kFloatsPerVertex)
        FileHandle.standardError.write(Data(
            ("[EnvironmentRenderer] mesh \(vertexCount) verts, "
             + (relief == nil ? "flat wall (no depth map)"
                : "relief \(relief!.cols)x\(relief!.rows) at \(Self.kRelief), "
                  + "scale \(String(format: "%.3f", kMin))-\(String(format: "%.3f", kMax))")
             + "\n").utf8))
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
    attribute vec3 aPosRoom;
    attribute vec2 aUV;
    attribute float aFar;
    attribute vec4 aShade;
    uniform mat4 uProj;
    uniform mat4 uView;
    // Shared with the fragment stage, so the precision must match it
    // (GLSL ES 1.00 refuses to link otherwise, with no compile error).
    uniform mediump float uT;
    varying vec2 vUV;
    varying float vFar;
    varying vec4 vShade;
    void main() {
        vec3 p = mix(aPosFlat, aPosRoom, uT);
        gl_Position = uProj * uView * vec4(p, 1.0);
        vUV = aUV;
        vFar = aFar;
        vShade = aShade;
    }
    """

    private static let fragmentSource = """
    #version 100
    precision mediump float;
    uniform sampler2D uTex;
    uniform float uT;
    uniform float uMip;
    varying vec2 vUV;
    varying float vFar;
    varying vec4 vShade;
    void main() {
        // The wallpaper texture's row 0 is the picture's BOTTOM (the same
        // bottom-left convention the engine shows it with), so v runs up.
        vec2 uv = vec2(clamp(vUV.x, 0.0, 1.0), 1.0 - clamp(vUV.y, 0.0, 1.0));
        float far = clamp(vFar, 0.0, 1.0);
        // (lit, fade, blur base, blur reach). The picture itself is
        // (1, 0, 0, 0) at far = 1, so it comes through untouched.
        float lit = vShade.x * pow(max(far, 0.002), vShade.y);
        float bias = (vShade.z + (1.0 - far) * vShade.w) * uT * uMip;
        vec4 c = texture2D(uTex, uv, bias);
        gl_FragColor = vec4(c.rgb * mix(1.0, lit, uT), 1.0);
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
        aPosRoom = _glGetAttribLocation(prog, "aPosRoom")
        aUV = _glGetAttribLocation(prog, "aUV")
        aFar = _glGetAttribLocation(prog, "aFar")
        aShade = _glGetAttribLocation(prog, "aShade")
        uProj = _glGetUniformLocation(prog, "uProj")
        uView = _glGetUniformLocation(prog, "uView")
        uT = _glGetUniformLocation(prog, "uT")
        uTex = _glGetUniformLocation(prog, "uTex")
        uMip = _glGetUniformLocation(prog, "uMip")
        FileHandle.standardError.write(Data("[EnvironmentRenderer] ready \(width)x\(height)\n".utf8))
    }
}
#endif
