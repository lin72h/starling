// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import CoreVideo
import Flutter
import FlutterSwiftBridge
import Foundation

/// Runs an independent Flutter widget tree offscreen, rasterizes its output,
/// and writes pixels to a CVPixelBuffer for compositing via FlutterTexture.
///
/// Usage:
/// ```swift
/// let app = OffscreenFlutterApp(width: 400, height: 300)
/// app.mountWidget { MyWidget() }
/// app.start(fps: 30)
/// ```
class OffscreenFlutterApp {

    let width: Int
    let height: Int

    /// Called on the render queue when a new frame is ready.
    var onFrameReady: (() -> Void)?

    private let buildOwner: BuildOwner
    private let pipelineOwner: PipelineOwner
    private let renderView: RenderView
    private var rootElement: RenderObjectToWidgetElement?

    private var timer: DispatchSourceTimer?
    private let renderQueue = DispatchQueue(
        label: "offscreen-flutter-app",
        qos: .userInteractive
    )

    private let lock = NSLock()
    private var _latestPixelBuffer: CVPixelBuffer?

    // MARK: - Init

    init(width: Int, height: Int, onFrameReady: (() -> Void)? = nil) {
        self.width = width
        self.height = height
        self.onFrameReady = onFrameReady

        // Build pipeline
        buildOwner = BuildOwner()
        pipelineOwner = PipelineOwner()

        let view = PlatformDispatcher.instance.implicitView!
        renderView = RenderView(view: view)

        let constraints = BoxConstraints.tight(Size(Double(width), Double(height)))
        let config = RenderViewConfiguration(
            physicalConstraints: constraints,
            logicalConstraints: constraints,
            devicePixelRatio: 1.0
        )
        renderView.configuration = config
        renderView.attach(pipelineOwner)
        renderView.prepareInitialFrame()

        // No-op: we drive frames ourselves via the timer.
        buildOwner.onBuildScheduled = {}
    }

    // MARK: - Widget Mounting

    func mountWidget(_ builder: () -> Widget) {
        let adapter = RenderObjectToWidgetAdapter(
            child: builder(),
            container: renderView
        )
        rootElement = adapter.attachToRenderTree(buildOwner)
    }

    // MARK: - Lifecycle

    func start(fps: Int = 30) {
        let interval = 1.0 / Double(fps)
        let t = DispatchSource.makeTimerSource(queue: renderQueue)
        t.schedule(deadline: .now(), repeating: interval)
        t.setEventHandler { [weak self] in
            self?.renderFrame()
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Pixel Buffer Access

    /// Called by the engine's raster thread via FlutterTexture.copyPixelBuffer().
    /// Returns the latest rendered frame and transfers ownership to the caller.
    func copyLatestPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        let buf = _latestPixelBuffer
        _latestPixelBuffer = nil
        lock.unlock()
        return buf
    }

    // MARK: - Rendering

    private func renderFrame() {
        guard let rootElement = rootElement else { return }

        // Build dirty elements
        buildOwner.buildScopeWithCallback(rootElement) {}

        // Layout
        renderView.performLayout()

        // Paint
        PaintingContext.repaintCompositedChild(renderView)

        // Extract PictureLayer from layer tree.
        // renderView.layer is a TransformLayer (ContainerLayer).
        // Walk children depth-first to find the first PictureLayer.
        guard let rootLayer = renderView.layer else { return }
        guard let pictureLayer = findPictureLayer(rootLayer) else { return }
        guard let picture = pictureLayer.picture as? NativePicture else { return }

        // Rasterize to Image
        let image = picture.toImageSync(width: width, height: height)

        // Get raw RGBA bytes
        guard let rgbaData = try? image.toByteData(format: .rawRgba) else {
            image.dispose()
            return
        }
        image.dispose()

        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else { return }

        // RGBA from Flutter -> BGRA for CVPixelBuffer
        let pixelCount = width * height
        rgbaData.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress else { return }
            let srcPtr = src.bindMemory(to: UInt8.self, capacity: pixelCount * 4)
            let dstPtr = baseAddress.bindMemory(to: UInt8.self, capacity: pixelCount * 4)
            for i in 0..<pixelCount {
                let si = i * 4
                dstPtr[si + 0] = srcPtr[si + 2]  // B <- R
                dstPtr[si + 1] = srcPtr[si + 1]  // G <- G
                dstPtr[si + 2] = srcPtr[si + 0]  // R <- B
                dstPtr[si + 3] = srcPtr[si + 3]  // A <- A
            }
        }

        // Store the pixel buffer
        lock.lock()
        _latestPixelBuffer = pb
        lock.unlock()

        onFrameReady?()
    }

    // MARK: - Layer Tree Traversal

    /// Depth-first search for the first PictureLayer in the layer tree.
    private func findPictureLayer(_ layer: Layer) -> PictureLayer? {
        if let pl = layer as? PictureLayer {
            return pl
        }
        if let container = layer as? ContainerLayer {
            var child = container.firstChild
            while let current = child {
                if let found = findPictureLayer(current) {
                    return found
                }
                child = current.nextSibling
            }
        }
        return nil
    }
}
#endif
