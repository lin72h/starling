// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - DisplayOutput

/// One display output in the virtual desktop.
///
/// `physical*` are device pixels (the DRM mode). `scale` is this output's
/// device-pixel-ratio. `origin*` place the output's top-left in the GLOBAL
/// logical ("virtual desktop") coordinate space. Its logical size is the
/// physical size divided by its own scale, so mixed-DPI outputs occupy
/// correctly-sized logical rects side by side.
struct DisplayOutput: Equatable {
    let id: Int
    var name: String
    var physicalWidth: Int
    var physicalHeight: Int
    var scale: Double
    var originX: Double
    var originY: Double
    var isPrimary: Bool
    var refreshMhz: Int

    var logicalWidth: Double { Double(physicalWidth) / scale }
    var logicalHeight: Double { Double(physicalHeight) / scale }

    var logicalLeft: Double { originX }
    var logicalTop: Double { originY }
    var logicalRight: Double { originX + logicalWidth }
    var logicalBottom: Double { originY + logicalHeight }

    /// This output's rectangle in the global logical space.
    var logicalRect: Rect {
        Rect.fromLTWH(originX, originY, logicalWidth, logicalHeight)
    }

    func containsLogical(_ x: Double, _ y: Double) -> Bool {
        x >= logicalLeft && x < logicalRight && y >= logicalTop && y < logicalBottom
    }
}

// MARK: - DisplayLayout

/// The set of outputs and their arrangement in one global logical coordinate
/// space (the "virtual desktop"). At N=1 the virtual desktop is exactly the
/// single output's rect at (0,0), so every existing single-screen code path
/// behaves identically.
final class DisplayLayout {
    private(set) var outputs: [DisplayOutput]

    init(outputs: [DisplayOutput]) {
        precondition(!outputs.isEmpty, "DisplayLayout needs at least one output")
        self.outputs = outputs
    }

    /// The primary output — where the dock homes and new windows open.
    var primary: DisplayOutput {
        outputs.first(where: { $0.isPrimary }) ?? outputs[0]
    }

    /// Union of every output's logical rect — the bounds of the virtual desktop.
    var virtualBounds: Rect {
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for o in outputs {
            minX = min(minX, o.logicalLeft)
            minY = min(minY, o.logicalTop)
            maxX = max(maxX, o.logicalRight)
            maxY = max(maxY, o.logicalBottom)
        }
        return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY)
    }

    /// The output whose logical rect contains `(x, y)` (virtual-desktop coords),
    /// or the primary if the point is off every output.
    func output(atLogical x: Double, _ y: Double) -> DisplayOutput {
        outputs.first(where: { $0.containsLogical(x, y) }) ?? primary
    }

    /// The output a window "belongs to": the one containing its centre, else the
    /// one it overlaps most, else the primary.
    func owningOutput(ofRect rect: Rect) -> DisplayOutput {
        let cx = rect.left + rect.width / 2.0
        let cy = rect.top + rect.height / 2.0
        if let o = outputs.first(where: { $0.containsLogical(cx, cy) }) { return o }
        var best: DisplayOutput? = nil
        var bestArea = 0.0
        for o in outputs {
            let w = max(0.0, min(o.logicalRight, rect.right) - max(o.logicalLeft, rect.left))
            let h = max(0.0, min(o.logicalBottom, rect.bottom) - max(o.logicalTop, rect.top))
            let area = w * h
            if area > bestArea { bestArea = area; best = o }
        }
        return best ?? primary
    }

    /// Outputs whose logical rect intersects `rect` — the set a window is
    /// visible on (drives wl_surface.enter/leave once wired through).
    func outputs(intersectingRect rect: Rect) -> [DisplayOutput] {
        outputs.filter { o in
            o.logicalLeft < rect.right && rect.left < o.logicalRight &&
            o.logicalTop < rect.bottom && rect.top < o.logicalBottom
        }
    }

    /// Keep the primary output's scale in step with a runtime DPI change
    /// (Settings app). Per-output scale for real multi-monitor comes later.
    func updatePrimaryScale(_ scale: Double) {
        guard let idx = outputs.firstIndex(where: { $0.isPrimary }) ?? (outputs.isEmpty ? nil : 0) else { return }
        outputs[idx].scale = scale
    }

    // MARK: Construction

    /// Build the startup layout. `STARLING_SIM_OUTPUTS` fabricates a
    /// hardware-free multi-output virtual desktop for development; otherwise a
    /// single output from the real display.
    static func build(physicalWidth: Int, physicalHeight: Int,
                      scale: Double, refreshMhz: Int,
                      name: String = "primary") -> DisplayLayout {
        if let spec = ProcessInfo.processInfo.environment["STARLING_SIM_OUTPUTS"],
           !spec.isEmpty {
            if let sim = parseSim(spec) {
                FileHandle.standardError.write(Data(
                    "[DisplayLayout] STARLING_SIM_OUTPUTS active: \(sim.describe())\n".utf8))
                return sim
            }
            FileHandle.standardError.write(Data(
                "[DisplayLayout] ignoring malformed STARLING_SIM_OUTPUTS=\"\(spec)\"; using real display\n".utf8))
        }
        let o = DisplayOutput(
            id: 0, name: name,
            physicalWidth: physicalWidth, physicalHeight: physicalHeight,
            scale: scale, originX: 0, originY: 0, isPrimary: true, refreshMhz: refreshMhz)
        return DisplayLayout(outputs: [o])
    }

    /// Format: `WxH@scale` per output, comma-separated, laid out left-to-right;
    /// the first is primary. Example (2× laptop + 1× external):
    /// `STARLING_SIM_OUTPUTS=3024x1964@2,2560x1440@1`
    private static func parseSim(_ spec: String) -> DisplayLayout? {
        var outs: [DisplayOutput] = []
        var cursorX: Double = 0
        for (i, raw) in spec.split(separator: ",").enumerated() {
            let atParts = raw.split(separator: "@", maxSplits: 1)
            let dims = atParts[0].split(separator: "x")
            guard dims.count == 2,
                  let w = Int(dims[0].trimmingCharacters(in: .whitespaces)),
                  let h = Int(dims[1].trimmingCharacters(in: .whitespaces)),
                  w > 0, h > 0 else { return nil }
            let scale = atParts.count > 1 ? (Double(atParts[1]) ?? 1.0) : 1.0
            guard scale > 0 else { return nil }
            outs.append(DisplayOutput(
                id: i, name: "sim-\(i)",
                physicalWidth: w, physicalHeight: h, scale: scale,
                originX: cursorX, originY: 0, isPrimary: i == 0, refreshMhz: 60000))
            cursorX += Double(w) / scale   // next output sits to the right in logical space
        }
        return outs.isEmpty ? nil : DisplayLayout(outputs: outs)
    }

    func describe() -> String {
        outputs.map {
            "\($0.name)[\($0.physicalWidth)x\($0.physicalHeight)@\($0.scale)x " +
            "logical \(Int($0.logicalWidth))x\(Int($0.logicalHeight)) " +
            "at (\(Int($0.originX)),\(Int($0.originY)))\($0.isPrimary ? " *primary" : "")]"
        }.joined(separator: " | ")
    }
}
