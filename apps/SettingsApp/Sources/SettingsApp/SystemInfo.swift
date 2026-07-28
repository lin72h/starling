// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if os(Linux)
import Glibc
#endif

// MARK: - System Info

struct SystemInfo {

    static let starlingVersion = "0.2"

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
        if let result = runCommand("/usr/bin/dpkg-query", args: ["-W", "-f", "${Version}", "libgl1-mesa-dri"]) {
            let version = result.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Run a command and return stdout. Blocks the calling thread.
    static func runCommand(_ path: String, args: [String]) -> String? {
        #if os(Linux)
        var pipes: [Int32] = [0, 0]
        guard pipe(&pipes) == 0 else { return nil }

        var pid: pid_t = 0
        var fileActions = posix_spawn_file_actions_t()
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, pipes[1], STDOUT_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, pipes[0])
        posix_spawn_file_actions_addclose(&fileActions, pipes[1])

        let allArgs = [path] + args
        let cArgs = allArgs.map { strdup($0) } + [nil]
        defer { cArgs.forEach { if let p = $0 { free(p) } } }

        let env = environ
        let result = posix_spawn(&pid, path, &fileActions, nil, cArgs, env)
        posix_spawn_file_actions_destroy(&fileActions)
        close(pipes[1])

        guard result == 0 else {
            close(pipes[0])
            return nil
        }

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(pipes[0], &buffer, buffer.count)
            if n <= 0 { break }
            output.append(contentsOf: buffer[0..<n])
        }
        close(pipes[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        return String(data: output, encoding: .utf8)
        #else
        return nil
        #endif
    }
}

// MARK: - Wi-Fi Network Model

struct WifiNetwork {
    let ssid: String
    let signal: Int         // 0-100
    let security: String    // e.g. "WPA2", "WPA2 WPA3", ""
    let inUse: Bool         // currently connected
    let bssid: String

    var isOpen: Bool { security.isEmpty }

    var signalBars: String {
        if signal >= 75 { return "\u{2582}\u{2584}\u{2586}\u{2588}" }
        if signal >= 50 { return "\u{2582}\u{2584}\u{2586} " }
        if signal >= 25 { return "\u{2582}\u{2584}  " }
        return "\u{2582}   "
    }

    var securityLabel: String {
        if isOpen { return "Open" }
        return security
    }
}

/// Active connection details.
struct WifiConnectionInfo {
    let ssid: String
    let ipAddress: String
    let gateway: String
    let dns: [String]
    let signal: Int
    let security: String
}

// MARK: - Wi-Fi Manager (nmcli-based)

struct WifiManager {

    /// Check if Wi-Fi radio is enabled.
    static func isWifiEnabled() -> Bool {
        #if os(Linux)
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli", args: ["radio", "wifi"]) else {
            return false
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "enabled"
        #else
        return false
        #endif
    }

    /// Toggle Wi-Fi radio on/off.
    static func setWifiEnabled(_ enabled: Bool) {
        #if os(Linux)
        let _ = SystemInfo.runCommand("/usr/bin/nmcli", args: ["radio", "wifi", enabled ? "on" : "off"])
        #endif
    }

    /// List visible Wi-Fi networks from cached scan results (fast, no rescan).
    static func listNetworks() -> [WifiNetwork] {
        #if os(Linux)
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list", "--rescan", "no"]) else {
            return []
        }
        return _parseNetworkList(result)
        #else
        return []
        #endif
    }

    /// Trigger a fresh scan then list networks. Blocks while scanning (~2-3s).
    static func scanAndListNetworks() -> [WifiNetwork] {
        #if os(Linux)
        // Trigger rescan
        let _ = SystemInfo.runCommand("/usr/bin/nmcli", args: ["device", "wifi", "rescan"])
        // Brief pause for scan results to populate
        usleep(500_000)
        // Read results
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list", "--rescan", "no"]) else {
            return []
        }
        return _parseNetworkList(result)
        #else
        return []
        #endif
    }

    /// Get details of the active Wi-Fi connection.
    static func activeConnectionInfo() -> WifiConnectionInfo? {
        #if os(Linux)
        // Get active connection name
        guard let activeResult = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["-t", "-f", "TYPE,NAME", "connection", "show", "--active"]) else {
            return nil
        }
        var connName: String? = nil
        for line in activeResult.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 && parts[0] == "802-11-wireless" {
                connName = String(parts[1])
                break
            }
        }
        guard let name = connName else { return nil }

        // Get connection details
        guard let detailResult = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "connection", "show", name]) else {
            return nil
        }

        var ip = ""
        var gw = ""
        var dns: [String] = []
        for line in detailResult.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("IP4.ADDRESS") {
                // Format: IP4.ADDRESS[1]:10.0.0.214/24
                if let colonIdx = str.firstIndex(of: ":") {
                    ip = String(str[str.index(after: colonIdx)...])
                }
            } else if str.hasPrefix("IP4.GATEWAY") {
                if let colonIdx = str.firstIndex(of: ":") {
                    gw = String(str[str.index(after: colonIdx)...])
                }
            } else if str.hasPrefix("IP4.DNS") {
                if let colonIdx = str.firstIndex(of: ":") {
                    dns.append(String(str[str.index(after: colonIdx)...]))
                }
            }
        }

        // Get signal from wifi list
        let networks = listNetworks()
        let connected = networks.first { $0.inUse }

        return WifiConnectionInfo(
            ssid: name,
            ipAddress: ip,
            gateway: gw,
            dns: dns,
            signal: connected?.signal ?? 0,
            security: connected?.security ?? ""
        )
        #else
        return nil
        #endif
    }

    /// Connect to a Wi-Fi network. Returns nil on success, error message on failure.
    static func connect(ssid: String, password: String? = nil) -> String? {
        #if os(Linux)
        var args = ["device", "wifi", "connect", ssid]
        if let pw = password, !pw.isEmpty {
            args += ["password", pw]
        }
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli", args: args) else {
            return "Failed to run nmcli"
        }
        let output = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // nmcli prints "Device '...' successfully activated..." on success
        if output.contains("successfully") {
            return nil
        }
        // Return the error message
        return output.isEmpty ? "Connection failed" : output
        #else
        return "Not supported on this platform"
        #endif
    }

    /// Disconnect from the current Wi-Fi network.
    static func disconnect(connectionName: String) -> String? {
        #if os(Linux)
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["connection", "down", connectionName]) else {
            return "Failed to run nmcli"
        }
        let output = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.contains("successfully") { return nil }
        return output.isEmpty ? "Disconnect failed" : output
        #else
        return "Not supported on this platform"
        #endif
    }

    /// Forget a saved Wi-Fi network.
    static func forget(connectionName: String) -> String? {
        #if os(Linux)
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["connection", "delete", connectionName]) else {
            return "Failed to run nmcli"
        }
        let output = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.contains("successfully") { return nil }
        return output.isEmpty ? "Delete failed" : output
        #else
        return "Not supported on this platform"
        #endif
    }

    /// List saved Wi-Fi connection names.
    static func savedConnections() -> [String] {
        #if os(Linux)
        guard let result = SystemInfo.runCommand("/usr/bin/nmcli",
            args: ["-t", "-f", "TYPE,NAME", "connection", "show"]) else {
            return []
        }
        var names: [String] = []
        for line in result.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 && parts[0] == "802-11-wireless" {
                names.append(String(parts[1]))
            }
        }
        return names
        #else
        return []
        #endif
    }

    // MARK: - Parsing

    private static func _parseNetworkList(_ output: String) -> [WifiNetwork] {
        var networks: [WifiNetwork] = []
        var seen = Set<String>()

        for line in output.split(separator: "\n") {
            // Format: SSID:SIGNAL:SECURITY:IN-USE
            // Split carefully — SSID and SECURITY can contain colons
            let str = String(line)
            let parts = str.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
            guard parts.count >= 4 else { continue }

            let ssid = String(parts[0])
            guard !ssid.isEmpty else { continue }
            guard !seen.contains(ssid) else { continue }
            seen.insert(ssid)

            let signal = Int(parts[1]) ?? 0
            let security = String(parts[2])
            let inUse = parts[3].contains("*")

            networks.append(WifiNetwork(
                ssid: ssid,
                signal: signal,
                security: security,
                inUse: inUse,
                bssid: ""
            ))
        }

        // Sort: connected first, then by signal strength descending
        networks.sort { a, b in
            if a.inUse != b.inUse { return a.inUse }
            return a.signal > b.signal
        }

        return networks
    }
}
