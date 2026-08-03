// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StarlingNet
#if os(Linux)
import Glibc
#endif

// WiFi models and control (WifiNetwork, WifiConnectionInfo, WifiManager) live
// in StarlingNet — the nmcli layer shared with the shell's status-bar popup —
// so the two UIs can never drift apart on parsing or connect mechanics.

// MARK: - System Info

struct SystemInfo {

    /// The installed package's version, stamped into the payload by
    /// package-desktop.sh. A source checkout has no stamp — that is a dev
    /// build, and saying so beats carrying a copy of the version here:
    /// this used to be a hardcoded string, and it shipped reading "0.2.1"
    /// on a 0.2.2 install.
    static func starlingVersion() -> String {
        // When STARLING_DATA_DIR is set it names the tree the shell actually
        // runs from, and it alone is the truth: falling through to the
        // system path made a staged checkout on a machine with the .deb
        // installed report the package's version instead of "dev build".
        let dir = ProcessInfo.processInfo.environment["STARLING_DATA_DIR"]
            ?? "/usr/share/starling"
        if let v = try? String(contentsOfFile: dir + "/VERSION",
                               encoding: .utf8) {
            let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "dev build"
    }

    static func osVersion() -> String {
        #if os(Linux)
        guard let contents = try? String(contentsOfFile: "/etc/os-release", encoding: .utf8) else {
            return "Linux (unknown)"
        }
        for line in contents.split(separator: "\n") {
            if line.hasPrefix("PRETTY_NAME=") {
                var value = String(line.dropFirst("PRETTY_NAME=".count))
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return value
            }
        }
        return "Linux"
        #elseif os(macOS)
        return "macOS"
        #endif
    }

    static func kernelVersion() -> String {
        var uts = utsname()
        uname(&uts)
        let release = withUnsafePointer(to: &uts.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
        return release
    }

    static func mesaVersion() -> String {
        #if os(Linux)
        let r = runTool("/usr/bin/dpkg-query",
                        ["-W", "-f", "${Version}", "libgl1-mesa-dri"])
        if r.ok {
            let version = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !version.isEmpty { return version }
        }
        return "Unknown"
        #else
        return "N/A"
        #endif
    }

    static func currentDPI() -> Double {
        if let dpiStr = ProcessInfo.processInfo.environment["FLUTTER_DRM_DPI"],
           let dpi = Double(dpiStr) {
            return dpi
        }
        return 2.0
    }

    /// Maximum DPI that keeps logical resolution >= 1080p.
    /// Reads FLUTTER_SCREEN_HEIGHT from environment (set by parent shell).
    static func maxDPI() -> Double {
        let screenHeight = Double(ProcessInfo.processInfo.environment["FLUTTER_SCREEN_HEIGHT"] ?? "") ?? 2160.0
        // Round down to nearest 0.25
        let raw = screenHeight / 1080.0
        return max(1.0, (raw * 4).rounded(.down) / 4)
    }
}
