// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

/// Simulates an "external app" by rendering animated content to an RGBA
/// pixel buffer at a configurable frame rate.
///
/// This is the Linux equivalent of `OffscreenRenderer` (macOS), using pure
/// pixel manipulation instead of CoreGraphics. Renders an animated gradient
/// background with a bouncing ball.
class SoftwareRenderer {

    let width: Int
    let height: Int

    /// Called on the main RunLoop when a new frame is ready.
    /// Parameters: (pixelDataPointer, width, height)
    var onFrameReady: ((UnsafeRawPointer, Int, Int) -> Void)?

    private var timer: Timer?
    private var frameCount: Int = 0
    private var ballX: Double = 100
    private var ballY: Double = 100
    private var ballDX: Double = 3.0
    private var ballDY: Double = 2.0
    private let ballRadius: Double = 25.0

    /// RGBA pixel buffer (width * height * 4 bytes)
    private var pixelBuffer: UnsafeMutablePointer<UInt8>

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixelBuffer = .allocate(capacity: width * height * 4)
    }

    deinit {
        pixelBuffer.deallocate()
    }

    // MARK: - Lifecycle

    func start(fps: Int = 30) {
        let interval = 1.0 / Double(fps)
        // On Linux, Timer closures are @Sendable. Use unsafeBitCast to bridge.
        let block: (Timer) -> Void = { [weak self] _ in
            self?.renderFrame()
        }
        let sendableBlock = unsafeBitCast(block, to: (@Sendable (Timer) -> Void).self)
        let t = Timer(timeInterval: interval, repeats: true, block: sendableBlock)
        Foundation.RunLoop.main.add(t, forMode: .default)
        Foundation.RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Vsync-driven rendering (DRM mode)

    private var lastRenderTime: UInt64 = 0
    private var renderIntervalNanos: UInt64 = 33_333_333  // ~30fps

    /// Called externally (e.g. from vsync) to render a frame.
    /// Throttled to renderIntervalNanos to avoid rendering at full vsync rate.
    func tickRender(currentTimeNanos: UInt64) {
        guard currentTimeNanos - lastRenderTime >= renderIntervalNanos else { return }
        lastRenderTime = currentTimeNanos
        renderFrame()
    }

    // MARK: - Rendering

    private func renderFrame() {
        frameCount += 1

        let w = width
        let h = height
        let phase = Double(frameCount) * 0.02

        // --- Background: animated gradient (per-pixel) ---
        for y in 0..<h {
            let yNorm = Double(y) / Double(h)
            for x in 0..<w {
                let xNorm = Double(x) / Double(w)
                let offset = (x + y) * 4

                let r = UInt8(clamping: Int(
                    (Foundation.sin(phase + xNorm * 3.0) + 1.0) * 0.15 * 255 + 25
                ))
                let g = UInt8(clamping: Int(
                    (Foundation.sin(phase + 2.0 + yNorm * 2.0) + 1.0) * 0.15 * 255 + 12
                ))
                let b = UInt8(clamping: Int(
                    (Foundation.sin(phase + 4.0 + (xNorm + yNorm) * 1.5) + 1.0) * 0.2 * 255 + 38
                ))

                pixelBuffer[offset + 0] = r
                pixelBuffer[offset + 1] = g
                pixelBuffer[offset + 2] = b
                pixelBuffer[offset + 3] = 255
            }
        }

        // --- Bouncing ball ---
        ballX += ballDX
        ballY += ballDY
        if ballX - ballRadius < 0 || ballX + ballRadius > Double(w) {
            ballDX = -ballDX
            ballX = max(ballRadius, min(Double(w) - ballRadius, ballX))
        }
        if ballY - ballRadius < 0 || ballY + ballRadius > Double(h) {
            ballDY = -ballDY
            ballY = max(ballRadius, min(Double(h) - ballRadius, ballY))
        }

        let br = ballRadius
        let bx = ballX
        let by = ballY
        let brSq = br * br

        // Draw ball as a filled circle
        let minY = max(0, Int(by - br) - 1)
        let maxY = min(h - 1, Int(by + br) + 1)
        let minX = max(0, Int(bx - br) - 1)
        let maxX = min(w - 1, Int(bx + br) + 1)

        for y in minY...maxY {
            let dy = Double(y) - by
            for x in minX...maxX {
                let dx = Double(x) - bx
                let distSq = dx * dx + dy * dy
                if distSq <= brSq {
                    let offset = (y * w + x) * 4
                    // Yellow ball: RGBA(255, 217, 0, 255)
                    pixelBuffer[offset + 0] = 255
                    pixelBuffer[offset + 1] = 217
                    pixelBuffer[offset + 2] = 0
                    pixelBuffer[offset + 3] = 255
                }
            }
        }

        // Ball highlight (smaller offset circle)
        let hlX = bx - br * 0.3
        let hlY = by - br * 0.3
        let hlR = br * 0.35
        let hlRSq = hlR * hlR
        let hlMinY = max(0, Int(hlY - hlR) - 1)
        let hlMaxY = min(h - 1, Int(hlY + hlR) + 1)
        let hlMinX = max(0, Int(hlX - hlR) - 1)
        let hlMaxX = min(w - 1, Int(hlX + hlR) + 1)

        for y in hlMinY...hlMaxY {
            let dy = Double(y) - hlY
            for x in hlMinX...hlMaxX {
                let dx = Double(x) - hlX
                let distSq = dx * dx + dy * dy
                if distSq <= hlRSq {
                    let offset = (y * w + x) * 4
                    // Light yellow highlight: RGBA(255, 255, 179, 255)
                    pixelBuffer[offset + 0] = 255
                    pixelBuffer[offset + 1] = 255
                    pixelBuffer[offset + 2] = 179
                    pixelBuffer[offset + 3] = 255
                }
            }
        }

        // Notify listener
        onFrameReady?(UnsafeRawPointer(pixelBuffer), w, h)
    }
}
#endif
