// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Flutter
import FlutterMacOSBridge
import FlutterSwiftBridge
import CoreVideo
import Foundation

/// Sendable wrapper for FlutterEngine reference (engine is always used on main thread).
private struct SendableEngine: @unchecked Sendable {
    let engine: FlutterEngine
}

/// Manages offscreen-rendered "external apps" that are composited into the
/// desktop shell via Flutter's texture registry.
///
/// Each external app consists of:
/// - An `OffscreenRenderer` that draws animated content to a CVPixelBuffer
/// - A `PixelBufferTexture` that bridges it to `FlutterTexture`
/// - A registered texture ID from the engine
class ExternalAppManager {

    private let engine: FlutterEngine

    /// Active external apps keyed by their texture ID.
    private var apps: [Int64: ExternalAppEntry] = [:]

    /// Active Flutter apps keyed by their texture ID.
    private var flutterApps: [Int64: FlutterAppEntry] = [:]

    init(engine: FlutterEngine) {
        self.engine = engine
    }

    /// Creates a new offscreen-rendered external app and registers it with the
    /// engine's texture system.
    ///
    /// Returns the texture ID that can be passed to `TextureWidget`.
    func createExternalApp(width: Int = 640, height: Int = 480) -> Int64 {
        let renderer = OffscreenRenderer(width: width, height: height, title: "External App")
        let texture = PixelBufferTexture(renderer: renderer)

        let textureId = engine.register(texture)

        let sendableEngine = SendableEngine(engine: engine)
        renderer.onFrameReady = {
            DispatchQueue.main.async {
                sendableEngine.engine.textureFrameAvailable(textureId)
            }
        }

        let entry = ExternalAppEntry(
            renderer: renderer,
            texture: texture,
            textureId: textureId
        )
        apps[textureId] = entry

        renderer.start(fps: 30)

        return textureId
    }

    /// Stops the renderer and unregisters the texture for the given ID.
    func destroyExternalApp(textureId: Int64) {
        guard let entry = apps.removeValue(forKey: textureId) else { return }
        entry.renderer.stop()
        engine.unregisterTexture(textureId)
    }

    // MARK: - Flutter App Management

    /// Creates a new offscreen Flutter app that renders a real widget tree
    /// and registers it with the engine's texture system.
    ///
    /// Returns the texture ID that can be passed to `TextureWidget`.
    func createFlutterApp(width: Int = 640, height: Int = 480) -> Int64 {
        let offscreenApp = OffscreenFlutterApp(width: width, height: height)
        let texture = FlutterAppTexture(offscreenApp: offscreenApp)

        let textureId = engine.register(texture)

        let sendableEngine = SendableEngine(engine: engine)
        offscreenApp.onFrameReady = {
            DispatchQueue.main.async {
                sendableEngine.engine.textureFrameAvailable(textureId)
            }
        }

        let entry = FlutterAppEntry(
            offscreenApp: offscreenApp,
            texture: texture,
            textureId: textureId
        )
        flutterApps[textureId] = entry

        // Mount the demo widget and start rendering.
        // Wrap in Directionality since this is a standalone widget tree
        // (no FluentApp / MaterialApp ancestor to provide TextDirection).
        offscreenApp.mountWidget {
            Directionality(
                textDirection: TextDirection.ltr,
                child: FlutterDemoApp()
            )
        }
        offscreenApp.start(fps: 30)

        return textureId
    }

    /// Stops the Flutter app and unregisters the texture for the given ID.
    func destroyFlutterApp(textureId: Int64) {
        guard let entry = flutterApps.removeValue(forKey: textureId) else { return }
        entry.offscreenApp.stop()
        engine.unregisterTexture(textureId)
    }
}

/// Internal bookkeeping for a single external app instance.
private struct ExternalAppEntry {
    let renderer: OffscreenRenderer
    let texture: PixelBufferTexture
    let textureId: Int64
}

/// Internal bookkeeping for a single Flutter app instance.
private struct FlutterAppEntry {
    let offscreenApp: OffscreenFlutterApp
    let texture: FlutterAppTexture
    let textureId: Int64
}

// MARK: - FlutterAppTexture

/// Bridges an OffscreenFlutterApp to Flutter's texture system.
///
/// Conforms to `FlutterTexture` so the engine's raster thread can call
/// `copyPixelBuffer()` to fetch the latest rendered frame from the
/// offscreen Flutter widget tree.
class FlutterAppTexture: NSObject, FlutterTexture {

    let offscreenApp: OffscreenFlutterApp

    init(offscreenApp: OffscreenFlutterApp) {
        self.offscreenApp = offscreenApp
        super.init()
    }

    /// Called by the engine's raster thread to obtain the current frame.
    /// Ownership of the returned CVPixelBuffer is transferred to the caller.
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pb = offscreenApp.copyLatestPixelBuffer() else { return nil }
        return Unmanaged.passRetained(pb)
    }
}
#endif
