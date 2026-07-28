// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - FlutterDemoApp

/// A demo animated widget that proves real Flutter widget tree rendering.
/// Uses a Foundation Timer to drive animation and displays rotating,
/// color-cycling boxes — pure graphical primitives only (no Text widgets,
/// since Impeller DlText cannot be replayed to a Skia raster canvas).
class FlutterDemoApp: StatefulWidget {

    override func createState() -> State<StatefulWidget> {
        return _FlutterDemoAppState()
    }
}

class _FlutterDemoAppState: State<StatefulWidget> {

    var frameCount: Int = 0
    var timer: Timer?

    override func initState() {
        super.initState()
        let block: (Timer) -> Void = { [weak self] _ in
            guard let self = self else { return }
            self.setState {
                self.frameCount += 1
            }
        }
        // On Linux, Timer closures are @Sendable. Use unsafeBitCast to bridge.
        let sendableBlock = unsafeBitCast(block, to: (@Sendable (Timer) -> Void).self)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true, block: sendableBlock)
    }

    override func dispose() {
        timer?.invalidate()
        timer = nil
        super.dispose()
    }

    override func build(_ context: any BuildContext) -> Widget {
        let angle = Double(frameCount) * 0.03
        let hue = (Double(frameCount) * 2).truncatingRemainder(dividingBy: 360)

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

        // Animated layout: rotating colored boxes in a Stack
        return ColoredBox(
            color: Color(0xFF1A1A2E),
            child: Center(
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
                                left: 150 + cos(angle * 1.5) * 100 - 25,
                                top: 150 + sin(angle * 1.5) * 100 - 25,
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
            )
        )
    }
}

// Simple trig helpers
private func sin(_ x: Double) -> Double { Foundation.sin(x) }
private func cos(_ x: Double) -> Double { Foundation.cos(x) }
