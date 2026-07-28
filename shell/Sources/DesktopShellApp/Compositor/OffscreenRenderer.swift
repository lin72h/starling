// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import CoreGraphics
import CoreVideo
import Foundation

/// Simulates an "external app" by rendering animated CoreGraphics content
/// to a CVPixelBuffer at a configurable frame rate.
///
/// This is the PoC stand-in for a real external process's rendered output.
/// In a production compositor, this would be replaced by shared-memory
/// surfaces from actual client applications.
class OffscreenRenderer {

    let width: Int
    let height: Int
    let title: String

    /// Called on the render queue when a new frame is ready.
    var onFrameReady: (() -> Void)?

    private let lock = NSLock()
    private var _latestPixelBuffer: CVPixelBuffer?
    private var timer: DispatchSourceTimer?
    private let renderQueue = DispatchQueue(label: "offscreen-renderer", qos: .userInteractive)
    private var frameCount: Int = 0
    private var ballX: Double = 100
    private var ballY: Double = 100
    private var ballDX: Double = 3.0
    private var ballDY: Double = 2.0
    private let ballRadius: Double = 25.0

    init(width: Int, height: Int, title: String = "External App") {
        self.width = width
        self.height = height
        self.title = title
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
        frameCount += 1

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
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)

        guard let cgContext = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        // Flip coordinate system (CoreGraphics is bottom-up)
        cgContext.translateBy(x: 0, y: CGFloat(height))
        cgContext.scaleBy(x: 1.0, y: -1.0)

        let w = CGFloat(width)
        let h = CGFloat(height)

        // --- Background: animated gradient ---
        let phase = Double(frameCount) * 0.02
        let r = CGFloat((sin(phase) + 1.0) * 0.15 + 0.1)
        let g = CGFloat((sin(phase + 2.0) + 1.0) * 0.15 + 0.05)
        let b = CGFloat((sin(phase + 4.0) + 1.0) * 0.2 + 0.15)
        cgContext.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1.0))
        cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Subtle gradient overlay
        let gradR = CGFloat((sin(phase + 1.0) + 1.0) * 0.1 + 0.05)
        let gradG = CGFloat((sin(phase + 3.0) + 1.0) * 0.1 + 0.1)
        let gradB = CGFloat((sin(phase + 5.0) + 1.0) * 0.15 + 0.2)
        cgContext.setFillColor(CGColor(red: gradR, green: gradG, blue: gradB, alpha: 0.3))
        cgContext.fill(CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5))

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

        cgContext.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0))
        cgContext.fillEllipse(in: CGRect(
            x: CGFloat(ballX - ballRadius),
            y: CGFloat(ballY - ballRadius),
            width: CGFloat(ballRadius * 2),
            height: CGFloat(ballRadius * 2)
        ))

        // Ball highlight
        cgContext.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 0.7, alpha: 0.6))
        cgContext.fillEllipse(in: CGRect(
            x: CGFloat(ballX - ballRadius * 0.4),
            y: CGFloat(ballY - ballRadius * 0.6),
            width: CGFloat(ballRadius * 0.5),
            height: CGFloat(ballRadius * 0.5)
        ))

        // --- Title text ---
        let titleStr = title as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.white,
        ]
        titleStr.draw(at: CGPoint(x: 16, y: 16), withAttributes: titleAttrs)

        // --- Frame counter ---
        let counterStr = "Frame: \(frameCount)" as NSString
        let counterAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(white: 0.8, alpha: 1.0),
        ]
        counterStr.draw(at: CGPoint(x: 16, y: 44), withAttributes: counterAttrs)

        // --- "Rendered by CoreGraphics" label ---
        let labelStr = "Rendered by CoreGraphics (offscreen)" as NSString
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor(white: 0.6, alpha: 1.0),
        ]
        labelStr.draw(at: CGPoint(x: 16, y: h - 28), withAttributes: labelAttrs)

        // Store the pixel buffer
        lock.lock()
        _latestPixelBuffer = pb
        lock.unlock()

        onFrameReady?()
    }
}
#endif
