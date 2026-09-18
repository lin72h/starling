// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation
import Glibc

// MARK: - FilamentRoomRenderer — the room, drawn by Filament
//
// The same slot as EnvironmentRenderer (the wallpaper's texture, rendered
// on the raster thread when the camera moves), but the picture comes from
// Filament through libstarling_room.so: a real PBR renderer lighting a
// glTF of the room from a captured sky, with shadows, ambient occlusion
// and tone mapping, instead of the hand-written GL and the offline bake.
//
// Filament runs on its own thread with its own EGL context, shared with
// the engine's, and draws straight into the texture the registry made for
// this slot. `sr_room_render` blocks until the GPU is done with it, so the
// engine samples a finished picture on the same frame.
//
// STARLING_ROOM=filament selects this renderer; STARLING_ROOM_DIR is the
// directory holding room.glb, room_ibl.ktx, room_skybox.ktx and room.json
// (build/tools/room-glb.py + cmgen), defaulting to the staged room/filament.
/// A window as the room renderer draws it: the window's centre and facing
/// in world metres, its size, and where inside it the client's picture
/// goes (below the title bar, which stays the shell's).
struct ScenePane: Equatable {
    var id: Int64
    var x = 0.0, y = 0.0, z = 0.0, yaw = 0.0
    var width = 0.0, height = 0.0
    var contentDy = 0.0, contentWidth = 0.0, contentHeight = 0.0
    var flipY = false
    var focused = false
}

final class FilamentRoomRenderer: EnvironmentRenderer {

    private typealias CreateFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> OpaquePointer?
    private typealias LoadFn = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
    private typealias SetLightFn = @convention(c) (OpaquePointer?, UnsafePointer<Float>?, UnsafePointer<Float>?, Float, Float) -> Void
    private typealias SetExposureFn = @convention(c) (OpaquePointer?, Float, Float, Float) -> Void
    private typealias SetOutputFn = @convention(c) (OpaquePointer?, UInt32, Int32, Int32) -> Int32
    private typealias SetCameraFn = @convention(c) (OpaquePointer?, UnsafePointer<Float>?, UnsafePointer<Float>?, Float, Float) -> Void
    private typealias RenderFn = @convention(c) (OpaquePointer?) -> Int32
    private typealias EGLGetCurrentFn = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias SetPaneFn = @convention(c) (OpaquePointer?, Int64, UnsafePointer<Float>?, Float, Float, Float, Float, Float, Float, UInt32, Int32, Int32, Int32, Int32) -> Int32
    private typealias RemovePaneFn = @convention(c) (OpaquePointer?, Int64) -> Void

    /// The client texture behind an engine texture id, on the raster
    /// thread (LinuxTextureRegistry.sceneTexture).
    var sceneTexture: ((Int64) -> (name: UInt32, width: Int, height: Int)?)?

    private let paneLock = NSLock()
    private var _panes: [ScenePane] = []
    private var knownPanes = Set<Int64>()
    private var fnSetPane: SetPaneFn!
    private var fnRemovePane: RemovePaneFn!

    /// Publish the windows that hang in the room; the next frame draws
    /// them. Returns whether anything changed.
    func setPanes(_ panes: [ScenePane]) -> Bool {
        paneLock.lock()
        defer { paneLock.unlock() }
        if panes == _panes { return false }
        _panes = panes
        dirty = true
        return true
    }

    /// Where the room's files are.
    let roomDir: String

    private var room: OpaquePointer?
    private var failed = false
    private var lib: UnsafeMutableRawPointer?
    private var fnLoad: LoadFn!
    private var fnSetLight: SetLightFn!
    private var fnSetExposure: SetExposureFn!
    private var fnSetOutput: SetOutputFn!
    private var fnSetCamera: SetCameraFn!
    private var fnRender: RenderFn!

    init(width: Int, height: Int, roomDir: String) {
        self.roomDir = roomDir
        super.init(width: width, height: height)
    }

    /// The scene clock drives the old renderer's water and clouds; this
    /// room is still, and only a camera move earns a frame.
    override func tick(_ seconds: Double) {}

    // MARK: Raster thread

    override func renderToTexture(_ textureName: UInt32) {
        dirty = false
        if failed { return }
        if room == nil {
            guard start() else {
                failed = true
                FileHandle.standardError.write(Data(
                    "[room] Filament renderer unavailable; the slot stays black\n".utf8))
                return
            }
        }
        let cam = camera
        guard fnSetOutput(room, textureName, Int32(width), Int32(height)) == 0 else { return }
        var proj = Self.projection(aspect: Double(width) / Double(height),
                                   tanHalfFovX: cam.tanHalfFovX)
        var view = Self.view(cam)
        fnSetCamera(room, &view, &proj, 0.08, 4000)
        syncPanes()
        _ = fnRender(room)
    }

    /// Hand every published pane to the scene with its client texture as
    /// it stands this frame, and take down the ones that have gone.
    private func syncPanes() {
        paneLock.lock()
        let panes = _panes
        paneLock.unlock()
        var live = Set<Int64>()
        for p in panes {
            guard let tex = sceneTexture?(p.id), tex.name != 0 else { continue }
            var c: [Float] = [Float(p.x), Float(p.y), Float(p.z)]
            let rc = fnSetPane(room, p.id, &c, Float(p.yaw), Float(p.width), Float(p.height),
                               Float(p.contentDy), Float(p.contentWidth), Float(p.contentHeight),
                               tex.name, Int32(tex.width), Int32(tex.height),
                               p.flipY ? 1 : 0, p.focused ? 1 : 0)
            if rc == 0 { live.insert(p.id) }
        }
        for id in knownPanes.subtracting(live) { fnRemovePane(room, id) }
        knownPanes = live
    }

    private func start() -> Bool {
        // The engine's context is current on this thread: that is the one
        // Filament's context shares with, on the same display.
        guard let resolver = glProcAddressResolver,
              let pDisplay = resolver("eglGetCurrentDisplay"),
              let pContext = resolver("eglGetCurrentContext") else {
            FileHandle.standardError.write(Data("[room] no EGL entry points\n".utf8))
            return false
        }
        let display = unsafeBitCast(pDisplay, to: EGLGetCurrentFn.self)()
        let context = unsafeBitCast(pContext, to: EGLGetCurrentFn.self)()
        guard display != nil, context != nil else {
            FileHandle.standardError.write(Data("[room] no current EGL context\n".utf8))
            return false
        }

        var candidates: [String] = []
        if let p = ProcessInfo.processInfo.environment["STARLING_ROOM_LIB"] { candidates.append(p) }
        if let real = realpath("/proc/self/exe", nil) {
            let selfDir = (String(cString: real) as NSString).deletingLastPathComponent
            free(real)
            candidates.append(selfDir + "/libstarling_room.so")
        }
        candidates.append("libstarling_room.so")
        for path in candidates {
            if let h = dlopen(path, RTLD_NOW | RTLD_LOCAL) { lib = h; break }
        }
        guard let lib else {
            FileHandle.standardError.write(Data(
                "[room] libstarling_room.so not found (build/build-room.sh): \(String(cString: dlerror()))\n".utf8))
            return false
        }
        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let p = dlsym(lib, name) else {
                FileHandle.standardError.write(Data("[room] missing \(name)\n".utf8))
                return nil
            }
            return unsafeBitCast(p, to: type)
        }
        guard let create = sym("sr_room_create", CreateFn.self),
              let load = sym("sr_room_load", LoadFn.self),
              let setLight = sym("sr_room_set_light", SetLightFn.self),
              let setExposure = sym("sr_room_set_exposure", SetExposureFn.self),
              let setOutput = sym("sr_room_set_output", SetOutputFn.self),
              let setCamera = sym("sr_room_set_camera", SetCameraFn.self),
              let render = sym("sr_room_render", RenderFn.self),
              let setPane = sym("sr_room_set_pane", SetPaneFn.self),
              let removePane = sym("sr_room_remove_pane", RemovePaneFn.self) else { return false }
        fnLoad = load; fnSetLight = setLight; fnSetExposure = setExposure
        fnSetOutput = setOutput; fnSetCamera = setCamera; fnRender = render
        fnSetPane = setPane; fnRemovePane = removePane

        guard let r = create(display, context) else { return false }
        room = r
        let rc = fnLoad(r, roomDir + "/room.glb", roomDir + "/room_ibl.ktx",
                        roomDir + "/room_skybox.ktx")
        guard rc == 0 else {
            FileHandle.standardError.write(Data("[room] load failed (\(rc)) from \(roomDir)\n".utf8))
            return false
        }

        // The sun, from the exporter's sidecar; strengths and exposure
        // from the environment while the look is being settled.
        let env = ProcessInfo.processInfo.environment
        var sunDir: [Float] = [-0.35, 0.45, -0.82]
        var sunCol: [Float] = [1, 0.95, 0.85]
        if let d = try? Data(contentsOf: URL(fileURLWithPath: roomDir + "/room.json")),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            if let s = j["sun_dir"] as? [Double], s.count == 3 { sunDir = s.map { Float($0) } }
            if let c = j["sun_colour"] as? [Double], c.count == 3 {
                let m = max(c.max() ?? 1, 1e-6)
                sunCol = c.map { Float($0 / m) }
            }
        }
        let sunLux = Float(env["STARLING_ROOM_SUN_LUX"] ?? "") ?? 100000
        let iblLux = Float(env["STARLING_ROOM_IBL_LUX"] ?? "") ?? 30000
        fnSetLight(r, sunDir, sunCol, sunLux, iblLux)
        if let e = env["STARLING_ROOM_EXPOSURE"] {
            let p = e.split(separator: ",").compactMap { Float($0) }
            if p.count == 3 { fnSetExposure(r, p[0], p[1], p[2]) }
        }
        return true
    }
}
#endif
