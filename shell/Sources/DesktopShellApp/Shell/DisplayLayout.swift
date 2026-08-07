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
///
/// **`isHost` and `isPrimary` are different things and the distinction is
/// load-bearing.** The host is the output the engine renders Flutter's
/// implicit view (id 0) to — a hardware binding we do not get to choose
/// (`FlDrmDisplay` picks the largest panel), and the one output whose logical
/// rect *is* the shell tree's own coordinate space, hence always at (0,0).
/// The primary is the user's pick in Settings › Displays: where the dock
/// lives and where new windows open. They coincide until the user says
/// otherwise.
struct DisplayOutput: Equatable {
    let id: Int
    var name: String
    var physicalWidth: Int
    var physicalHeight: Int
    var scale: Double
    var originX: Double
    var originY: Double
    /// The engine's implicit view renders here. Exactly one output has it.
    var isHost: Bool
    /// The user's primary display. Exactly one output has it.
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
        applyPreferredPrimary()
    }

    /// The output the shell's own widget tree renders to (Flutter's implicit
    /// view). Its logical rect is the shell tree's coordinate space, so
    /// `screenWidth`/`screenHeight` and anything positioned in that tree are
    /// measured against THIS output, never against `primary`.
    var host: DisplayOutput {
        outputs.first(where: { $0.isHost }) ?? outputs[0]
    }

    /// The primary output — where the dock homes and new windows open. The
    /// user's choice, which may not be the host.
    var primary: DisplayOutput {
        outputs.first(where: { $0.isPrimary }) ?? host
    }

    /// Whether the shell's own tree is the one that draws the dock. When it is
    /// false the dock belongs to a `SecondaryOutputScreen` instead.
    var primaryIsHost: Bool { primary.id == host.id }

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

    /// A window keeps its place across a layout change only when at least this
    /// much of it is still on the visible desktop. Necessarily above 0.5: a
    /// window split evenly across two outputs has to come home when one of them
    /// is unplugged, and that is the case bare intersection got wrong.
    static let minVisibleFractionToStay = 0.75

    /// The fraction of `rect`'s area that lands on the visible desktop, 0…1.
    ///
    /// Outputs never overlap — the layout arranges them side by side from the
    /// engine's enumeration — so per-output intersections sum without double
    /// counting. Clamped anyway, so an overlapping arrangement would degrade to
    /// "fully visible" rather than to a fraction above 1.
    func visibleFraction(ofRect rect: Rect) -> Double {
        let area = rect.width * rect.height
        guard area > 0 else { return 0 }
        var covered = 0.0
        for o in outputs {
            let w = max(0.0, min(o.logicalRight, rect.right) - max(o.logicalLeft, rect.left))
            let h = max(0.0, min(o.logicalBottom, rect.bottom) - max(o.logicalTop, rect.top))
            covered += w * h
        }
        return min(1.0, covered / area)
    }

    /// Keep the host output's scale in step with a runtime DPI change
    /// (Settings app). The host, not the primary: the DPI slider resizes the
    /// view the shell tree renders into, which is the host's. Per-output scale
    /// for real multi-monitor comes later.
    func updateHostScale(_ scale: Double) {
        guard let idx = outputs.firstIndex(where: { $0.isHost }) ?? (outputs.isEmpty ? nil : 0) else { return }
        outputs[idx].scale = scale
    }

    // MARK: Primary display (user choice)

    /// Move the primary to the output named `name`, remembering the choice.
    /// Returns false — and changes nothing — when no output carries that name.
    @discardableResult
    func setPrimary(name: String) -> Bool {
        guard outputs.contains(where: { $0.name == name }) else { return false }
        for i in outputs.indices { outputs[i].isPrimary = outputs[i].name == name }
        DisplayLayout.preferredPrimaryName = name
        return true
    }

    /// Same, by engine output id — what a child app has to send, since ids are
    /// what it is shown.
    @discardableResult
    func setPrimary(outputId: Int) -> Bool {
        guard let o = outputs.first(where: { $0.id == outputId }) else { return false }
        return setPrimary(name: o.name)
    }

    /// Point the primary at the remembered output, or at the host when the
    /// user never chose one (or chose a monitor that is not plugged in now).
    /// Every construction path ends here, so startup and hotplug agree.
    private func applyPreferredPrimary() {
        let wanted = DisplayLayout.preferredPrimaryName
        let target = outputs.first(where: { $0.name == wanted })?.name ?? host.name
        for i in outputs.indices { outputs[i].isPrimary = outputs[i].name == target }
    }

    /// Where the choice is remembered. One line, the connector name.
    private static var _preferredPrimaryFile: String {
        LoginUser.configDir + "/primary-display"
    }

    private nonisolated(unsafe) static var _preferredPrimary: String? = nil
    private nonisolated(unsafe) static var _preferredPrimaryLoaded = false

    /// The connector name the user picked, or nil for "wherever the engine
    /// hosts". Stored by NAME, not by index: indexes are the engine's
    /// enumeration order and a hotplug reshuffles them, so an index would
    /// silently promote a different monitor after replugging. `eDP-1` does not
    /// move.
    nonisolated(unsafe) static var preferredPrimaryName: String? {
        get {
            if !_preferredPrimaryLoaded {
                _preferredPrimaryLoaded = true
                let raw = (try? String(contentsOfFile: _preferredPrimaryFile,
                                       encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                _preferredPrimary = (raw?.isEmpty ?? true) ? nil : raw
            }
            return _preferredPrimary
        }
        set {
            _preferredPrimaryLoaded = true
            guard newValue != _preferredPrimary else { return }
            _preferredPrimary = newValue
            let path = _preferredPrimaryFile
            try? FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            if let name = newValue {
                try? name.write(toFile: path, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
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
            scale: scale, originX: 0, originY: 0,
            isHost: true, isPrimary: true, refreshMhz: refreshMhz)
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
                originX: cursorX, originY: 0,
                isHost: i == 0, isPrimary: i == 0, refreshMhz: 60000))
            cursorX += Double(w) / scale   // next output sits to the right in logical space
        }
        return outs.isEmpty ? nil : DisplayLayout(outputs: outs)
    }

    func describe() -> String {
        outputs.map {
            "\($0.name)[\($0.physicalWidth)x\($0.physicalHeight)@\($0.scale)x " +
            "logical \(Int($0.logicalWidth))x\(Int($0.logicalHeight)) " +
            "at (\(Int($0.originX)),\(Int($0.originY)))" +
            ($0.isHost ? " *host" : "") + ($0.isPrimary ? " *primary" : "") + "]"
        }.joined(separator: " | ")
    }
}
