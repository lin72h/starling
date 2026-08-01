// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation
#if os(Linux)
import Glibc
#endif

// MARK: - FlutterDemoApp

/// A demo animated widget that proves real Flutter widget tree rendering.
/// Uses an AnimationController (vsync-driven) to display rotating,
/// color-cycling boxes — pure graphical primitives only (no Text widgets,
/// since Impeller DlText cannot be replayed to a Skia raster canvas).
/// Includes a frame-time graph at the bottom to visualize stalls.
class FlutterDemoApp: StatefulWidget {

    override func createState() -> State<StatefulWidget> {
        return _FlutterDemoAppState()
    }
}

class _FlutterDemoAppState: State<StatefulWidget>, TickerProvider {

    var controller: AnimationController?

    // Frame timing measurement
    private var lastFrameNanos: UInt64 = 0
    private var frameTimes: [Double] = []  // recent frame deltas in ms
    private let maxBars = 64

    // Last tap, in logical widget coordinates — renders a marker there, which
    // makes pointer input verifiable from a screenshot alone.
    private var tapPosition: Offset? = nil

    private func monoNanos() -> UInt64 {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return UInt64(ts.tv_sec) &* 1_000_000_000 &+ UInt64(ts.tv_nsec)
    }

    // MARK: - TickerProvider

    public func createTicker(_ onTick: @escaping (Duration) -> Void) -> Ticker {
        return Ticker(onTick)
    }

    override func initState() {
        super.initState()
        controller = AnimationController(
            duration: .seconds(10),
            vsync: self
        )
        controller!.addListener { [weak self] in
            self?.setState {}
        }
        controller!.repeat()
    }

    override func dispose() {
        controller?.dispose()
        controller = nil
        super.dispose()
    }

    override func build(_ context: any BuildContext) -> Widget {
        // Measure frame time
        let now = monoNanos()
        if lastFrameNanos > 0 {
            let deltaMs = Double(now &- lastFrameNanos) / 1_000_000.0
            frameTimes.append(deltaMs)
            if frameTimes.count > maxBars { frameTimes.removeFirst() }
        }
        lastFrameNanos = now

        // Detect if there was a recent stall (flash background red)
        let recentStall = frameTimes.last.map { $0 > 34 } ?? false

        // controller.value goes 0→1 over 10s, repeating.
        // Use 2π so rotation wraps seamlessly when the controller resets.
        let t = (controller?.value ?? 0.0)  // 0→1 over duration
        let angle = t * 2.0 * .pi  // exactly one full rotation per cycle
        let hue = (t * 360.0).truncatingRemainder(dividingBy: 360)

        // Convert hue to RGB (simplified HSV->RGB with S=0.8, V=0.9)
        let c = 0.9 * 0.8
        let x = c * (1.0 - Swift.abs((hue / 60.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = 0.9 - c
        let r1: Double
        let g1: Double
        let b1: Double
        switch Int(hue / 60.0) % 6 {
        case 0: r1 = c; g1 = x; b1 = 0
        case 1: r1 = x; g1 = c; b1 = 0
        case 2: r1 = 0; g1 = c; b1 = x
        case 3: r1 = 0; g1 = x; b1 = c
        case 4: r1 = x; g1 = 0; b1 = c
        case 5: r1 = c; g1 = 0; b1 = x
        default: r1 = 0; g1 = 0; b1 = 0
        }
        let r = Int((r1 + m) * 255)
        let g = Int((g1 + m) * 255)
        let b = Int((b1 + m) * 255)

        // Secondary color (offset hue)
        let hue2 = (hue + 120).truncatingRemainder(dividingBy: 360)
        let x2 = c * (1.0 - Swift.abs((hue2 / 60.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let r2v: Double
        let g2v: Double
        let b2v: Double
        switch Int(hue2 / 60.0) % 6 {
        case 0: r2v = c; g2v = x2; b2v = 0
        case 1: r2v = x2; g2v = c; b2v = 0
        case 2: r2v = 0; g2v = c; b2v = x2
        case 3: r2v = 0; g2v = x2; b2v = c
        case 4: r2v = x2; g2v = 0; b2v = c
        case 5: r2v = c; g2v = 0; b2v = x2
        default: r2v = 0; g2v = 0; b2v = 0
        }
        let r2 = Int((r2v + m) * 255)
        let g2 = Int((g2v + m) * 255)
        let b2 = Int((b2v + m) * 255)

        // Tertiary color
        let hue3 = (hue + 240).truncatingRemainder(dividingBy: 360)
        let x3 = c * (1.0 - Swift.abs((hue3 / 60.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let r3v: Double
        let g3v: Double
        let b3v: Double
        switch Int(hue3 / 60.0) % 6 {
        case 0: r3v = c; g3v = x3; b3v = 0
        case 1: r3v = x3; g3v = c; b3v = 0
        case 2: r3v = 0; g3v = c; b3v = x3
        case 3: r3v = 0; g3v = x3; b3v = c
        case 4: r3v = x3; g3v = 0; b3v = c
        case 5: r3v = c; g3v = 0; b3v = x3
        default: r3v = 0; g3v = 0; b3v = 0
        }
        let r3 = Int((r3v + m) * 255)
        let g3 = Int((g3v + m) * 255)
        let b3 = Int((b3v + m) * 255)

        // Background: flash dark red on stall, otherwise normal
        let bgColor = recentStall ? Color(0xFF3A1A1A) : Color(0xFF1A1A2E)

        // Sweeping bar position (wall-clock based, jumps reveal stalls)
        let sweepX = t * 640.0  // 0→640 over one cycle, wraps with controller

        // Frame time graph painter — draws all bars in a single paint call
        let graphPainter = FrameTimeGraphPainter(
            frameTimes: frameTimes,
            sweepX: sweepX
        )

        // Animated layout: rotating colored boxes + frame time graph
        var stackChildren: [Widget] = [
                    // Main animation area (centered)
                    Center(
                        child: SizedBox(
                            width: 300,
                            height: 300,
                            child: Stack(
                                children: [
                                    // Large rotating box (primary color)
                                    Positioned(
                                        left: 90,
                                        top: 90,
                                        child: Transform(
                                            transform: Matrix4.rotationZ(angle),
                                            alignment: Alignment.center,
                                            child: SizedBox(
                                                width: 120,
                                                height: 120,
                                                child: ColoredBox(
                                                    color: Color(argb: 255, r, g, b),
                                                    child: SizedBox(expand: ())
                                                )
                                            )
                                        )
                                    ),
                                    // Smaller orbiting box (secondary color)
                                    Positioned(
                                        left: 150 + cos(angle * 2.0) * 100 - 25,
                                        top: 150 + sin(angle * 2.0) * 100 - 25,
                                        child: SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: ColoredBox(
                                                color: Color(argb: 230, r2, g2, b2),
                                                child: SizedBox(expand: ())
                                            )
                                        )
                                    ),
                                    // Tiny orbiting box (tertiary color, opposite direction)
                                    Positioned(
                                        left: 150 + cos(-angle * 2.0) * 70 - 15,
                                        top: 150 + sin(-angle * 2.0) * 70 - 15,
                                        child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: ColoredBox(
                                                color: Color(argb: 200, r3, g3, b3),
                                                child: SizedBox(expand: ())
                                            )
                                        )
                                    ),
                                    // Pulsating center dot
                                    Positioned(
                                        left: 150 - 10 + sin(angle * 3) * 5,
                                        top: 150 - 10 + cos(angle * 3) * 5,
                                        child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: ClipRRect(
                                                borderRadius: BorderRadius.all(Radius(circular: 10)),
                                                child: ColoredBox(
                                                    color: Color(0xFFFFFFFF),
                                                    child: SizedBox(expand: ())
                                                )
                                            )
                                        )
                                    ),
                                ]
                            )
                        )
                    ),
                    // Frame time graph at bottom (single CustomPaint — no per-bar widgets)
                    Positioned(
                        left: 4,
                        right: 0,
                        bottom: 4,
                        child: CustomPaint(
                            painter: graphPainter,
                            size: Size(632, 40),
                            willChange: true
                        )
                    ),
        ]

        // Tap marker: an amber square centered on the last click.
        if let tap = tapPosition {
            stackChildren.append(Positioned(
                left: tap.dx - 12,
                top: tap.dy - 12,
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: ColoredBox(
                        color: Color(0xFFFFB300),
                        child: SizedBox(expand: ())
                    )
                )
            ))
        }

        return GestureDetector(
            onTapDown: { [weak self] details in
                print("[FlutterDemoApp] tapDown at \(details.globalPosition)")
                self?.setState {
                    self?.tapPosition = details.localPosition ?? details.globalPosition
                }
            },
            child: ColoredBox(
                color: bgColor,
                child: Stack(children: stackChildren)
            )
        )
    }
}

// MARK: - FrameTimeGraphPainter

/// Draws the frame-time bar graph and sweep indicator in a single paint call.
/// Green ≤17ms, yellow ≤34ms, orange ≤50ms, red >50ms.
class FrameTimeGraphPainter: CustomPainter {
    let frameTimes: [Double]
    let sweepX: Double

    private static let barWidth: Double = 8
    private static let barSpacing: Double = 2
    private static let maxFrameTimeMs: Double = 100

    init(frameTimes: [Double], sweepX: Double) {
        self.frameTimes = frameTimes
        self.sweepX = sweepX
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        let h = size.height

        // Draw frame time bars
        for (i, dt) in frameTimes.enumerated() {
            let barH = Swift.max(2, Swift.min(dt / Self.maxFrameTimeMs, 1.0) * h)
            let x = Double(i) * (Self.barWidth + Self.barSpacing)

            if dt <= 20 {
                paint.color = Color(argb: 220, 0, 200, 0)       // green — on time
            } else if dt <= 34 {
                paint.color = Color(argb: 220, 255, 255, 0)     // yellow — late
            } else if dt <= 50 {
                paint.color = Color(argb: 220, 255, 140, 0)     // orange — missed frame
            } else {
                paint.color = Color(argb: 240, 255, 0, 0)       // red — stall
            }
            canvas.drawRect(Rect.fromLTRB(x, h - barH, x + Self.barWidth, h), paint)
        }

        // 16.67ms reference line
        let refY = h - (16.67 / Self.maxFrameTimeMs) * h
        paint.color = Color(argb: 100, 0, 255, 0)
        canvas.drawRect(Rect.fromLTRB(0, refY, size.width, refY + 1), paint)

        // Sweeping position indicator
        paint.color = Color(argb: 200, 255, 255, 255)
        canvas.drawRect(Rect.fromLTRB(sweepX, 0, sweepX + 3, h), paint)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return true  // always repaint — frame times change every frame
    }
}

// Simple trig helpers
private func sin(_ x: Double) -> Double { Foundation.sin(x) }
private func cos(_ x: Double) -> Double { Foundation.cos(x) }
