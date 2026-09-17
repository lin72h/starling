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
private typealias GLUniform3fvFunc = @convention(c) (Int32, Int32, UnsafePointer<Float>?) -> Void
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
private typealias GLGenRenderbuffersFunc = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLBindRenderbufferFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLRenderbufferStorageFunc = @convention(c) (UInt32, UInt32, Int32, Int32) -> Void
private typealias GLFramebufferRenderbufferFunc = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Void
private typealias GLDepthFuncFunc = @convention(c) (UInt32) -> Void
private typealias GLDepthMaskFunc = @convention(c) (UInt8) -> Void
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
private let GL_RENDERBUFFER: UInt32 = 0x8D41
private let GL_DEPTH_ATTACHMENT: UInt32 = 0x8D00
private let GL_DEPTH_COMPONENT24: UInt32 = 0x81A6
private let GL_DEPTH_BUFFER_BIT: UInt32 = 0x0100
private let GL_LEQUAL: UInt32 = 0x0203
private let GL_CCW: UInt32 = 0x0901

/// What the platform thread last decided the camera should be, and the
/// hall it is standing in. Read on the raster thread under the renderer's
/// lock. Everything here is in METRES — the shell owns the room's shape,
/// the renderer just draws it from where the viewer is.
struct EnvironmentCamera: Equatable {
    /// 0 = the flat wallpaper, 1 = the room. Follows the enter/leave tween.
    var t: Double = 0
    /// Where the viewer is standing, and where they are looking.
    var x: Double = 0
    var y: Double = 2
    var z: Double = 4.6
    var yaw: Double = 0
    var pitch: Double = 0
    /// The picture on the far wall, at z = 0, its bottom on the floor.
    var pictureWidth: Double = 6.4
    var pictureHeight: Double = 4.0
    /// The hall: x is centred on 0, y runs up from the floor, z runs back
    /// from the picture toward the viewer.
    var roomWidth: Double = 11
    var roomHeight: Double = 4.6
    var roomDepth: Double = 16
    /// The lens, shared with the windows so the two agree exactly.
    var tanHalfFovX: Double = 0.7002
    /// The daylight's colour, taken from the wallpaper: the room is lit by
    /// what is outside its window, so a dusk view gives a dim warm room
    /// and a noon view a bright one. This is the wallpaper's average —
    /// Mica's ingredient, doing a second job.
    var lightR: Double = 0.55
    var lightG: Double = 0.60
    var lightB: Double = 0.70
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

    /// Seconds since the scene opened. The sky and the water move with
    /// it, so the place is weather rather than a photograph.
    private var _clock: Double = 0
    var sceneClock: Double {
        get { cameraLock.lock(); defer { cameraLock.unlock() }; return _clock }
    }
    /// Advance the clock. Called from a ticker on the platform thread; the
    /// renderer is marked dirty by the caller.
    func tick(_ seconds: Double) {
        cameraLock.lock()
        _clock = seconds
        cameraLock.unlock()
        dirty = true
    }

    private let cameraLock = NSLock()
    private var _camera = EnvironmentCamera()
    /// Rebuild the room when the hall's shape changes.
    private var meshKey: Double = 0

    // GL objects (raster thread only)
    private var glReady = false
    private var loggedDraw = false
    private var program: UInt32 = 0
    private var vbo: UInt32 = 0
    private var vao: UInt32 = 0
    private var fbo: UInt32 = 0
    private var vertexCount: Int32 = 0
    private var mipmapped: Set<UInt32> = []
    private var aPos: Int32 = -1, aUV: Int32 = -1, aMat: Int32 = -1
    private var aDisp: Int32 = -1, uTime: Int32 = -1
    private var uEye: Int32 = -1, uEyeV: Int32 = -1, uFade: Int32 = -1
    private var uLight: Int32 = -1
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
    private var _glUniform3fv: GLUniform3fvFunc?
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
    private var _glGenRenderbuffers: GLGenRenderbuffersFunc!
    private var _glBindRenderbuffer: GLBindRenderbufferFunc!
    private var _glRenderbufferStorage: GLRenderbufferStorageFunc!
    private var _glFramebufferRenderbuffer: GLFramebufferRenderbufferFunc!
    private var _glDepthFunc: GLDepthFuncFunc!
    private var _glDepthMask: GLDepthMaskFunc!
    private var depthRb: UInt32 = 0
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
        _glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                   GL_RENDERBUFFER, depthRb)
        _glViewport(0, 0, Int32(width), Int32(height))
        _glDisable(GL_SCISSOR_TEST)
        _glEnable(GL_DEPTH_TEST)
        _glDepthFunc(GL_LEQUAL)
        // Skia leaves depth WRITES off, and a depth clear is a no-op while
        // they are: the buffer keeps whatever was in it, every fragment
        // fails LEQUAL, and the room draws nothing at all while the colour
        // clear still works — which looks exactly like a geometry bug.
        _glDepthMask(1)
        _glDisable(GL_BLEND)
        _glDisable(GL_CULL_FACE)
        _glDisable(GL_STENCIL_TEST)
        _glClearColor(0.02, 0.02, 0.03, 1.0)
        _glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        if let src = sourceTexture?(), src.width > 0, src.height > 0 {
            // The hall's shape comes from the shell with the camera, so a
            // change of output (or of wallpaper aspect) rebuilds the mesh.
            let key = cam.pictureWidth + cam.pictureHeight * 7 + cam.roomDepth * 31
            if key != meshKey || takeMeshStale() {
                buildMesh(cam)
                meshKey = key
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
            attrib(aPos, 3, 0); attrib(aUV, 2, 3); attrib(aMat, 1, 5)
            attrib(aDisp, 1, 6)

            var proj = Self.projection(aspect: Double(width) / Double(height),
                                       tanHalfFovX: cam.tanHalfFovX)
            var view = Self.view(cam)
            _glUniformMatrix4fv(uProj, 1, 0, &proj)
            _glUniformMatrix4fv(uView, 1, 0, &view)
            _glUniform1f(uT, Float(cam.t))
            _glUniform1f(uTime, Float(sceneClock))
            _glUniform1f(uMip, canMip ? 1.0 : 0.0)
            // The room fades up out of the view as the viewer pulls back
            // off the glass; at t = 0 there is nothing but the view, which
            // is the flat wallpaper.
            _glUniform1f(uFade, Float(min(1, max(0, (cam.t - 0.12) / 0.55))))
            var eye = [Float(cam.x), Float(cam.y), Float(cam.z)]
            if uEye >= 0 { _glUniform3fv?(uEye, 1, &eye) }
            if uEyeV >= 0 { _glUniform3fv?(uEyeV, 1, &eye) }
            var light = [Float(cam.lightR), Float(cam.lightG), Float(cam.lightB)]
            if uLight >= 0 { _glUniform3fv?(uLight, 1, &light) }
            _glUniform1i(uTex, 0)
            _glDrawArrays(GL_TRIANGLES, 0, vertexCount)
            if !loggedDraw {
                loggedDraw = true
                let err = _glGetError()
                let msg = "[EnvironmentRenderer] draw \(vertexCount) verts, glError \(err), "
                    + "attribs \(aPos) \(aUV) \(aMat)\n"
                FileHandle.standardError.write(Data(msg.utf8))
            }
            _glBindBuffer(GL_ARRAY_BUFFER, 0)
            _glBindVertexArray?(0)
            _glUseProgram(0)
            _glBindTexture(GL_TEXTURE_2D, 0)
        }
        _glFlush()
        if let path = dumpPath { dump(to: path) }
        _glDisable(GL_DEPTH_TEST)
        _glDepthMask(0)
        _glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, 0)
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

    /// Column-major perspective with the lens the windows use. No y flip:
    /// the engine wraps an external GL texture bottom-left up, so GL's
    /// row 0 (clip y = -1) IS the bottom of the screen — measured, not
    /// assumed (the first build flipped it and drew the floor on top).
    static func projection(aspect: Double, tanHalfFovX: Double) -> [Float] {
        let tx = tanHalfFovX, ty = tanHalfFovX / aspect
        // Far enough for the sky: the reconstruction puts it hundreds of
        // metres out, and an 80 m far plane simply clipped it away — a
        // black sky that looked like a shader bug and was a frustum.
        let n = 0.08, f = 4000.0
        var m = [Float](repeating: 0, count: 16)
        m[0] = Float(1 / tx)
        m[5] = Float(1 / ty)
        m[10] = Float(-(f + n) / (f - n))
        m[11] = -1
        m[14] = Float(-2 * f * n / (f - n))
        return m
    }

    /// World -> view, column-major: undo the viewer's place and heading.
    /// The viewer really walks now, so this is a look-at and not the
    /// hand's-breadth translation the parallax version used.
    static func view(_ c: EnvironmentCamera) -> [Float] {
        let cy = cos(-c.yaw), sy = sin(-c.yaw)
        let cp = cos(-c.pitch), sp = sin(-c.pitch)
        // R = Rx(-pitch) * Ry(-yaw), then translate by -eye.
        let r = [
            cy, 0.0, -sy,
            sp * sy, cp, sp * cy,
            cp * sy, -sp, cp * cy,
        ]
        func rowDotEye(_ i: Int) -> Double {
            -(r[i * 3] * c.x + r[i * 3 + 1] * c.y + r[i * 3 + 2] * c.z)
        }
        var m = [Float](repeating: 0, count: 16)
        for col in 0..<3 {
            for row in 0..<3 { m[col * 4 + row] = Float(r[row * 3 + col]) }
        }
        m[12] = Float(rowDotEye(0))
        m[13] = Float(rowDotEye(1))
        m[14] = Float(rowDotEye(2))
        m[15] = 1
        return m
    }

    /// Vertices are pos(3) uv(2) mat(1).
    static let kFloatsPerVertex = Scene3D.floatsPerVertex

    /// Build the scene once: the wallpaper put back into three dimensions
    /// by its own depth map. `Scene3D` owns the geometry.
    private func buildMesh(_ cam: EnvironmentCamera) {
        let v = Scene3D.build(grid: depthGrid, tanHalfFovX: cam.tanHalfFovX,
                              aspect: Double(width) / Double(height))
        vertexCount = Int32(v.count / Self.kFloatsPerVertex)
        let what = depthGrid == nil ? "flat (no depth map)"
            : "depth \(Int(Scene3D.near))m to \(Int(Scene3D.far))m"
        FileHandle.standardError.write(Data(
            "[EnvironmentRenderer] scene \(vertexCount) verts, \(what)\n".utf8))
        _glBindBuffer(GL_ARRAY_BUFFER, vbo)
        v.withUnsafeBytes { buf in
            _glBufferData(GL_ARRAY_BUFFER, buf.count, buf.baseAddress, GL_STATIC_DRAW)
        }
        _glBindBuffer(GL_ARRAY_BUFFER, 0)
    }

    // MARK: GL setup

    private static let vertexSource = """
    #version 100
    attribute vec3 aPos;
    attribute vec2 aUV;
    attribute float aMat;
    attribute float aDisp;
    uniform mat4 uProj;
    uniform mat4 uView;
    uniform vec3 uEyeV;
    varying vec2 vUV;
    varying float vMat;
    varying float vDisp;
    varying vec3 vDir;
    void main() {
        // The hole-filling copy of the image rides with the viewer, so it
        // behaves like scenery at infinity and never shows an edge.
        vec3 p = aPos + (aMat > 0.5 ? uEyeV : vec3(0.0));
        gl_Position = uProj * uView * vec4(p, 1.0);
        vUV = aUV;
        vMat = aMat;
        vDisp = aDisp;
        vDir = normalize(p - uEyeV);
    }
    """

    private static let fragmentSource = """
    #version 100
    precision highp float;
    uniform sampler2D uTex;
    uniform float uMip;
    uniform float uTime;
    uniform vec3 uLight;
    varying vec2 vUV;
    varying float vMat;
    varying float vDisp;
    varying vec3 vDir;

    float hash(vec2 p) {
        p = mod(p, 256.0);
        return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    }
    float noise(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
    }
    float fbm(vec2 p) {
        float a = 0.5, s = 0.0;
        for (int i = 0; i < 5; i++) {
            s += a * noise(p);
            p *= 2.03;
            a *= 0.5;
        }
        return s;
    }

    void main() {
        // The wallpaper texture's row 0 is the picture's BOTTOM (the
        // engine's bottom-left convention), so v runs up.
        vec2 uv = vec2(clamp(vUV.x, 0.0, 1.0), 1.0 - clamp(vUV.y, 0.0, 1.0));

        // The water: near, and low in the frame. A long exposure froze it;
        // this puts it back in motion — a slow swell that drags the
        // reflections with it, because a reflection is the surface, not
        // the thing reflected.
        float water = smoothstep(0.16, 0.34, vDisp) * smoothstep(0.52, 0.40, uv.y);
        vec2 wuv = uv;
        if (water > 0.001) {
            float t = uTime;
            float swell = fbm(vec2(uv.x * 7.0, uv.y * 26.0 - t * 0.09)) - 0.5;
            float ripple = sin(uv.y * 190.0 - t * 1.1 + swell * 5.0) * 0.5
                         + sin(uv.x * 61.0 + uv.y * 130.0 - t * 0.8) * 0.5;
            // The further off, the less a wave moves on screen.
            float amp = 0.0018 + 0.0065 * smoothstep(0.30, 1.0, vDisp);
            wuv.y += (swell * 1.7 + ripple * 0.30) * amp * water;
            wuv.x += swell * amp * 0.5 * water;
        }
        float bias = vMat > 0.5 ? 2.5 * uMip : 0.0;
        vec3 c = texture2D(uTex, wuv, bias).rgb;
        // What shows through the cuts is the same picture, softened and a
        // little darker — a gap that reads as distance behind the thing in
        // front of it. Lightening it instead drew a halo round every
        // silhouette in the scene.
        if (vMat > 0.5) c = mix(c * 0.82, uLight * 0.5, 0.12);

        // The sky: far, and high in the frame. Cloud comes over it, lit by
        // the moon, drifting the way weather does — slowly, and faster
        // near the top of the frame than at the horizon.
        float sky = smoothstep(0.075, 0.015, vDisp) * smoothstep(0.30, 0.55, uv.y)
                  * (vMat > 0.5 ? 0.25 : 1.0);
        if (sky > 0.001) {
            // Direction-based coordinates, so the cloud belongs to the sky
            // and not to the screen: it stays put when the viewer moves.
            vec2 sc = vec2(atan(vDir.x, -vDir.z), vDir.y / max(0.12, length(vDir.xz)));
            float drift = uTime * 0.0065;
            float f = fbm(vec2(sc.x * 2.6 + drift, sc.y * 1.7 - drift * 0.22));
            float g = fbm(vec2(sc.x * 6.1 - drift * 1.9, sc.y * 3.9 + drift * 0.5));
            float cloud = smoothstep(0.46, 0.86, f * 0.72 + g * 0.28);
            // The moon, low in the west, and the light it throws.
            vec3 moonDir = normalize(vec3(-0.52, 0.42, -0.74));
            float md = dot(normalize(vDir), moonDir);
            float disc = smoothstep(0.99955, 0.99985, md);
            float halo = pow(max(md, 0.0), 220.0) * 0.55 + pow(max(md, 0.0), 22.0) * 0.10;
            vec3 moonCol = vec3(0.86, 0.90, 1.0);
            // Cloud takes the moon's light on the side facing it and stays
            // blue-grey away from it.
            vec3 cloudCol = mix(vec3(0.10, 0.13, 0.20),
                                moonCol * 0.85, pow(max(md, 0.0), 3.0));
            c = mix(c, cloudCol, cloud * sky * 0.72);
            c += (disc * 1.5 + halo) * moonCol * sky * (1.0 - cloud * 0.85);
        }

        // Waves. Dragging the reflection is only half of it — a sea reads
        // as a sea because its faces catch the light and its troughs do
        // not. Two crossing swells, rolling toward the viewer, with the
        // wavelength growing as the water comes nearer.
        if (water > 0.001) {
            float t = uTime;
            float near = smoothstep(0.18, 0.95, vDisp);
            float scale = mix(150.0, 34.0, near);
            float drift = fbm(vec2(uv.x * 3.0, uv.y * 9.0 - t * 0.05)) - 0.5;
            float s1 = sin(uv.y * scale - t * 1.35 + drift * 7.0 + uv.x * 5.0);
            float s2 = sin(uv.y * scale * 0.61 + uv.x * 13.0 - t * 0.95);
            float s3 = sin(uv.y * scale * 2.3 - t * 2.2 + drift * 11.0);
            float crest = s1 * 0.5 + s2 * 0.33 + s3 * 0.17;
            // Faces toward the sky brighten, troughs fall into shadow.
            float face = smoothstep(-0.25, 0.85, crest);
            c += (vec3(0.16, 0.19, 0.26) * (face - 0.42)) * water * mix(0.5, 1.5, near);
            // Foam on the steepest crests, only close in.
            float foam = smoothstep(0.86, 0.99, crest) * near * water;
            c += vec3(0.30, 0.34, 0.40) * foam * 0.35;
            // And the moon's path across them: the one thing that ties the
            // sky to the surface.
            float band = exp(-pow((uv.x - 0.30) * 4.2, 2.0));
            float sparkle = fbm(vec2(uv.x * 120.0, uv.y * 300.0 - t * 1.4));
            float g = smoothstep(0.55, 0.78, sparkle * 0.7 + face * 0.3) * band * water;
            c += vec3(0.62, 0.68, 0.86) * g * 0.40;
        }
        gl_FragColor = vec4(c, 1.0);
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
        _glUniform3fv = tryLoad("glUniform3fv")
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
        _glGenRenderbuffers = load("glGenRenderbuffers")
        _glBindRenderbuffer = load("glBindRenderbuffer")
        _glRenderbufferStorage = load("glRenderbufferStorage")
        _glFramebufferRenderbuffer = load("glFramebufferRenderbuffer")
        _glDepthFunc = load("glDepthFunc")
        _glDepthMask = load("glDepthMask")
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
        // A real room needs a real depth buffer: the sofa has to be in
        // front of the wall behind it from wherever the viewer stands.
        _glGenRenderbuffers(1, &depthRb)
        _glBindRenderbuffer(GL_RENDERBUFFER, depthRb)
        _glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24,
                               Int32(width), Int32(height))
        _glBindRenderbuffer(GL_RENDERBUFFER, 0)
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
        aPos = _glGetAttribLocation(prog, "aPos")
        aUV = _glGetAttribLocation(prog, "aUV")
        aMat = _glGetAttribLocation(prog, "aMat")
        aDisp = _glGetAttribLocation(prog, "aDisp")
        uTime = _glGetUniformLocation(prog, "uTime")
        uEye = _glGetUniformLocation(prog, "uEye")
        uEyeV = _glGetUniformLocation(prog, "uEyeV")
        uLight = _glGetUniformLocation(prog, "uLight")
        uFade = _glGetUniformLocation(prog, "uFade")
        uProj = _glGetUniformLocation(prog, "uProj")
        uView = _glGetUniformLocation(prog, "uView")
        uT = _glGetUniformLocation(prog, "uT")
        uTex = _glGetUniformLocation(prog, "uTex")
        uMip = _glGetUniformLocation(prog, "uMip")
        FileHandle.standardError.write(Data("[EnvironmentRenderer] ready \(width)x\(height)\n".utf8))
    }
}
#endif
