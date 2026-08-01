// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Model

/// Point-in-time picture of the display backlight (laptops; absent means
/// no slider, exactly like the battery icon).
public struct BacklightStatus: Equatable {
    public var present = false
    /// Kernel device name, e.g. "intel_backlight" — SetBrightness needs it.
    public var device = ""
    public var brightness = 0
    public var maxBrightness = 1

    public var percent: Int {
        guard maxBrightness > 0 else { return 0 }
        return Int((Double(brightness) / Double(maxBrightness) * 100).rounded())
    }

    public init() {}
}

// MARK: - Control

/// Reads `/sys/class/backlight` and writes through logind's
/// `Session.SetBrightness` — the session owner may set the brightness of
/// its own seat's devices with no polkit prompt, which is how every
/// desktop's brightness key works. Synchronous; call off the main thread.
public enum BacklightControl {

    /// Overridable for tests and simulation, mirroring
    /// `STARLING_POWER_SUPPLY_DIR`: point `STARLING_BACKLIGHT_DIR` at a
    /// fake device directory and the whole stack runs against it — writes
    /// included, which go straight to the file (there is no logind session
    /// that owns a fake directory).
    public static var defaultRoot: String {
        ProcessInfo.processInfo.environment["STARLING_BACKLIGHT_DIR"]
            ?? "/sys/class/backlight"
    }

    public static func read(root: String = BacklightControl.defaultRoot)
        -> BacklightStatus {
        var status = BacklightStatus()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root),
              let device = entries.sorted().first else { return status }
        let dir = root + "/" + device
        guard let max = intFile(dir, "max_brightness"), max > 0 else {
            return status
        }
        status.present = true
        status.device = device
        status.maxBrightness = max
        status.brightness = intFile(dir, "brightness") ?? 0
        return status
    }

    /// Set the backlight to a percentage, floored at 1% — a slider must not
    /// be able to turn the screen fully off; that is what the power button
    /// is for. nil on success, error text on refusal.
    @discardableResult
    public static func setPercent(_ percent: Int,
                                  status: BacklightStatus,
                                  root: String = BacklightControl.defaultRoot)
        -> String? {
        guard status.present else { return "no backlight device" }
        let pct = min(max(percent, 1), 100)
        let raw = max(1, Int((Double(pct) / 100
                              * Double(status.maxBrightness)).rounded()))
        if ProcessInfo.processInfo.environment["STARLING_BACKLIGHT_DIR"] != nil {
            // Simulated device: a plain file, written directly.
            do {
                try "\(raw)\n".write(
                    toFile: root + "/" + status.device + "/brightness",
                    atomically: true, encoding: .utf8)
                return nil
            } catch {
                return "\(error)"
            }
        }
        let r = run(["--system", "call", "org.freedesktop.login1",
                     "/org/freedesktop/login1/session/auto",
                     "org.freedesktop.login1.Session", "SetBrightness",
                     "ssu", "backlight", status.device, String(raw)])
        guard r.status == 0 else {
            let err = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return err.isEmpty ? "exit status \(r.status)" : err
        }
        return nil
    }

    // MARK: Helpers

    private static func intFile(_ dir: String, _ name: String) -> Int? {
        guard let s = try? String(contentsOfFile: dir + "/" + name,
                                  encoding: .utf8) else { return nil }
        return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func run(_ args: [String])
        -> (status: Int32, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/busctl")
        process.arguments = args
        let err = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "\(error)") }
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(data: errData, encoding: .utf8) ?? "")
    }
}
