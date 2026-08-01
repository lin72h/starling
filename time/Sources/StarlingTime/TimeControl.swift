// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Models

/// Point-in-time picture of the system clock configuration.
public struct TimeStatus: Equatable {
    /// timedated answered. False means no systemd-timedated (or no
    /// timedatectl): the pane says so instead of drawing dead controls.
    public var available = false
    /// IANA zone name, e.g. "America/Los_Angeles".
    public var timezone = ""
    /// The machine can do NTP at all (a timesync service is installed).
    public var canNTP = false
    public var ntpEnabled = false
    public var ntpSynchronized = false
    /// The wall-clock line as timedated formats it
    /// ("Sat 2026-08-01 03:16:05 PDT") — shown verbatim, never re-derived,
    /// so what the pane displays is what the system said.
    public var localTime = ""

    public init() {}
}

// MARK: - Control

/// Talks to systemd-timedated through `timedatectl` — the same tool a user
/// would type, so anything this reports can be checked by hand. Mutations go
/// through polkit: a seat-active session is authorised silently
/// (allow_active), anything else gets the "interactive authentication"
/// refusal — which is surfaced verbatim, because "works in the real session,
/// denied over SSH" is a property of the system, not a bug in this layer.
/// Synchronous process runs; call off the main thread.
public enum TimeControl {

    public static func status() -> TimeStatus {
        let r = run(["show"])
        guard r.status == 0 else { return TimeStatus() }
        return parseShow(r.stdout)
    }

    /// All IANA zone names timedated accepts, in its order (sorted).
    public static func listTimezones() -> [String] {
        let r = run(["list-timezones"])
        guard r.status == 0 else { return [] }
        return r.stdout.split(separator: "\n").map(String.init)
    }

    /// nil on success, the tool's error text on refusal — polkit's denial
    /// is the interesting one, and it is an explanation, not a failure of
    /// this call.
    @discardableResult
    public static func setTimezone(_ zone: String) -> String? {
        let r = run(["set-timezone", zone])
        return r.status == 0 ? nil : errorText(r)
    }

    @discardableResult
    public static func setNTP(_ enabled: Bool) -> String? {
        let r = run(["set-ntp", enabled ? "true" : "false"])
        return r.status == 0 ? nil : errorText(r)
    }

    // MARK: Parsing (internal for the tests)

    /// `timedatectl show` — key=value lines, one per property.
    static func parseShow(_ text: String) -> TimeStatus {
        var status = TimeStatus()
        status.available = true
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let value = String(parts[1])
            switch parts[0] {
            case "Timezone":        status.timezone = value
            case "CanNTP":          status.canNTP = value == "yes"
            case "NTP":             status.ntpEnabled = value == "yes"
            case "NTPSynchronized": status.ntpSynchronized = value == "yes"
            case "TimeUSec":        status.localTime = value
            default: break
            }
        }
        return status
    }

    /// Unique region prefixes ("Africa", "America", …) of the zone list, in
    /// list order. Zones with no slash ("UTC") group under themselves.
    public static func regions(of zones: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for zone in zones {
            let region = String(zone.split(separator: "/").first ?? "")
            guard !region.isEmpty, seen.insert(region).inserted else { continue }
            out.append(region)
        }
        return out
    }

    /// The zones under one region, full names kept — the picker shows the
    /// city part, but selection needs the whole zone name.
    public static func zones(_ zones: [String], inRegion region: String) -> [String] {
        zones.filter { $0 == region || $0.hasPrefix(region + "/") }
    }

    // MARK: Process

    private static func errorText(_ r: (status: Int32, stdout: String, stderr: String)) -> String {
        let err = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return err.isEmpty ? "exit status \(r.status)" : err
    }

    private static func run(_ args: [String])
        -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/timedatectl")
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "", "\(error)") }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(data: outData, encoding: .utf8) ?? "",
                String(data: errData, encoding: .utf8) ?? "")
    }
}
