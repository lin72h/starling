// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Wi-Fi Manager (nmcli-based)

/// All WiFi state and control, via nmcli. Every call blocks on a child
/// process — callers run these on a background queue and hop results back to
/// their own main thread.
///
/// Mutating operations return `nil` on success or a user-showable error
/// string on failure. Success is the child's exit status — never a string
/// match on output, which broke the first version of this code the moment a
/// message changed.
public struct WifiManager {

    public static let nmcli = "/usr/bin/nmcli"

    /// Activation timeout: nmcli's own -w flag, so a stuck association fails
    /// with a real error instead of hanging a UI spinner forever.
    public static let activateTimeout = "30"

    /// Whether NetworkManager tooling exists at all. When false every read
    /// returns empty and the UIs show "Wi-Fi unavailable" — the desktop must
    /// degrade, not crash, on a server install without network-manager.
    public static func available() -> Bool {
        FileManager.default.isExecutableFile(atPath: nmcli)
    }

    /// Names of WiFi devices NetworkManager manages (type "wifi" exactly —
    /// not "wifi-p2p", and not unmanaged radios, which on a wifi-sim box are
    /// the hostapd APs themselves). Empty means no usable radio.
    public static func wifiDevices() -> [String] {
        let r = runTool(nmcli, ["-t", "-f", "DEVICE,TYPE,STATE",
                                "device", "status"])
        guard r.ok else { return [] }
        return r.stdout.split(separator: "\n").compactMap { line in
            let parts = splitTerseLine(line)
            guard parts.count >= 3, parts[1] == "wifi",
                  parts[2] != "unmanaged" else { return nil }
            return parts[0]
        }
    }

    public static func isWifiEnabled() -> Bool {
        let r = runTool(nmcli, ["radio", "wifi"])
        guard r.ok else { return false }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "enabled"
    }

    public static func setWifiEnabled(_ enabled: Bool) -> String? {
        let r = runTool(nmcli, ["radio", "wifi", enabled ? "on" : "off"])
        return r.ok ? nil : r.errorText
    }

    /// Ask NetworkManager for a fresh scan. Returns immediately; results
    /// arrive in the background and show up in the next listNetworks().
    /// Errors are ignored — NM rejects a rescan that follows another too
    /// closely, and the cached results are the correct fallback.
    public static func requestScan() {
        _ = runTool(nmcli, ["device", "wifi", "rescan"])
    }

    /// Visible networks from cached scan results (fast, no rescan).
    public static func listNetworks() -> [WifiNetwork] {
        let r = runTool(nmcli, ["-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE,BSSID",
                                "device", "wifi", "list", "--rescan", "no"])
        guard r.ok else { return [] }
        return parseNetworkList(r.stdout)
    }

    /// Trigger a scan, wait for results, list. Blocks ~2s — background only.
    public static func scanAndListNetworks() -> [WifiNetwork] {
        requestScan()
        Thread.sleep(forTimeInterval: 2.0)
        return listNetworks()
    }

    /// Details of the active WiFi connection, or nil when not connected.
    /// The IP configuration and MAC come from the shared `linkDetails` read,
    /// the same one the wired path uses.
    public static func activeConnectionInfo() -> WifiConnectionInfo? {
        let active = runTool(nmcli, ["-t", "-f", "TYPE,NAME,DEVICE",
                                     "connection", "show", "--active"])
        guard active.ok else { return nil }
        var name: String? = nil
        var device = ""
        for line in active.stdout.split(separator: "\n") {
            let parts = splitTerseLine(line)
            if parts.count >= 3 && parts[0] == "802-11-wireless" {
                name = parts[1]
                device = parts[2]
                break
            }
        }
        guard let name else { return nil }

        let link = device.isEmpty ? nil : linkDetails(device)
        let connected = listNetworks().first { $0.inUse }
        return WifiConnectionInfo(
            ssid: name,
            device: device,
            mac: link?.mac ?? "",
            ipAddress: link?.ipAddress ?? "",
            gateway: link?.gateway ?? "",
            dns: link?.dns ?? [],
            signal: connected?.signal ?? 0,
            security: connected?.security ?? ""
        )
    }

    /// Join a network. `security` is the scan result's SECURITY string, used
    /// to pick the key management for a new secured profile.
    ///
    /// Three paths, all deliberate:
    /// - A saved profile is activated as-is (`connection up`), so a stored
    ///   password keeps working and a changed AP password surfaces as an
    ///   activation error rather than silently re-prompting.
    /// - A new open network goes through `device wifi connect`.
    /// - A new secured network is created with `connection add` (no secret in
    ///   the command line) and activated with the password in a 0600 tmpfs
    ///   file (`passwd-file`), deleted immediately after. Never argv: /proc
    ///   exposes every process's arguments to every local user for the whole
    ///   association (seconds), and never stdin `--ask`: on a wrong password
    ///   nmcli re-prompts in an endless loop instead of failing.
    /// - A failed new-profile activation deletes the half-made profile, so a
    ///   wrong password doesn't leave a broken "saved" network behind that
    ///   would hijack every later attempt at the same SSID.
    public static func connect(ssid: String, password: String? = nil,
                               device: String = "", security: String = "") -> String? {
        if savedConnections().contains(ssid) {
            let r = runTool(nmcli, ["-w", activateTimeout, "connection", "up", ssid])
            return r.ok ? nil : r.errorText
        }

        // Always pin the radio. Left unpinned, NetworkManager binds the new
        // profile to whichever WiFi device it likes — on a box with more than
        // one (a laptop's built-in radio plus a simulated one, or a USB
        // dongle), that is regularly a device which cannot see this SSID, and
        // the join fails with "The Wi-Fi network could not be found" against
        // a network sitting right there in the list.
        let iface = device.isEmpty ? (deviceSeeing(ssid: ssid) ?? "") : device

        guard let pw = password, !pw.isEmpty else {
            var args = ["-w", activateTimeout, "device", "wifi", "connect", ssid]
            if !iface.isEmpty { args += ["ifname", iface] }
            let r = runTool(nmcli, args)
            return r.ok ? nil : r.errorText
        }

        // WPA3-only APs need SAE; anything advertising WPA2 (or older) takes
        // wpa-psk, which WPA2/WPA3 transition APs accept too.
        let keyMgmt = security.contains("WPA3") && !security.contains("WPA2")
            ? "sae" : "wpa-psk"

        var addArgs = ["connection", "add", "type", "wifi",
                       "con-name", ssid, "ssid", ssid]
        if !iface.isEmpty { addArgs += ["ifname", iface] }
        addArgs += ["--", "wifi-sec.key-mgmt", keyMgmt]
        let add = runTool(nmcli, addArgs)
        guard add.ok else { return add.errorText }

        let pwFile = passwdFilePath()
        guard FileManager.default.createFile(
            atPath: pwFile,
            contents: Data("802-11-wireless-security.psk:\(pw)\n".utf8),
            attributes: [.posixPermissions: 0o600]) else {
            _ = runTool(nmcli, ["connection", "delete", ssid])
            return "could not write password file"
        }
        defer { try? FileManager.default.removeItem(atPath: pwFile) }

        let up = runTool(nmcli, ["-w", activateTimeout,
                                 "connection", "up", ssid, "passwd-file", pwFile])
        if !up.ok {
            _ = runTool(nmcli, ["connection", "delete", ssid])
            return up.errorText
        }
        return nil
    }

    public static func disconnect(connectionName: String) -> String? {
        let r = runTool(nmcli, ["-w", activateTimeout,
                                "connection", "down", connectionName])
        return r.ok ? nil : r.errorText
    }

    public static func forget(connectionName: String) -> String? {
        let r = runTool(nmcli, ["connection", "delete", connectionName])
        return r.ok ? nil : r.errorText
    }

    /// Names of saved WiFi profiles.
    public static func savedConnections() -> [String] {
        let r = runTool(nmcli, ["-t", "-f", "TYPE,NAME", "connection", "show"])
        guard r.ok else { return [] }
        var names: [String] = []
        for line in r.stdout.split(separator: "\n") {
            let parts = splitTerseLine(line)
            if parts.count >= 2 && parts[0] == "802-11-wireless" {
                names.append(parts[1])
            }
        }
        return names
    }

    /// The managed radio whose latest scan contains `ssid`, or the first
    /// managed radio if none reports it (a stale cache shouldn't block a
    /// join outright). nil only when there is no WiFi device at all.
    static func deviceSeeing(ssid: String) -> String? {
        let r = runTool(nmcli, ["-t", "-f", "SSID,DEVICE",
                                "device", "wifi", "list", "--rescan", "no"])
        let managed = Set(wifiDevices())
        if r.ok {
            for line in r.stdout.split(separator: "\n") {
                let parts = splitTerseLine(line)
                guard parts.count >= 2, parts[0] == ssid else { continue }
                if managed.contains(parts[1]) { return parts[1] }
            }
        }
        return wifiDevices().first
    }

    /// Map a raw connect failure to what the user should read. Verified
    /// against the wifi-sim lab: a wrong password on a fresh profile burns
    /// the full activation timeout ("Timeout expired"), and on a saved
    /// profile fails with "Secrets were required" — both mean the same thing
    /// to a person. Anything unrecognized passes through verbatim.
    public static func friendlyConnectError(_ raw: String) -> String {
        if raw.contains("Timeout expired") || raw.contains("Secrets were required") {
            return "Could not join — check the password and try again."
        }
        return raw
    }

    // MARK: - Parsing

    /// Parse `-t -f SSID,SIGNAL,SECURITY,IN-USE,BSSID device wifi list`.
    /// Visible for tests.
    static func parseNetworkList(_ output: String) -> [WifiNetwork] {
        var networks: [WifiNetwork] = []
        var index: [String: Int] = [:]  // ssid → position in networks

        for line in output.split(separator: "\n") {
            let parts = splitTerseLine(line)
            guard parts.count >= 5 else { continue }

            let ssid = parts[0]
            guard !ssid.isEmpty else { continue }  // hidden networks
            let network = WifiNetwork(
                ssid: ssid,
                signal: Int(parts[1]) ?? 0,
                security: parts[2],
                inUse: parts[3].contains("*"),
                bssid: parts[4]
            )

            // One row per SSID. Multiple BSSes of one network collapse to the
            // first (strongest — nmcli sorts by signal), except the in-use BSS
            // always wins so the connected network never shows as not.
            if let i = index[ssid] {
                if network.inUse && !networks[i].inUse { networks[i] = network }
            } else {
                index[ssid] = networks.count
                networks.append(network)
            }
        }

        networks.sort { a, b in
            if a.inUse != b.inUse { return a.inUse }
            return a.signal > b.signal
        }
        return networks
    }

    private static func passwdFilePath() -> String {
        let dir = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"]
            ?? NSTemporaryDirectory()
        return dir + "/starling-wifi-\(UUID().uuidString)"
    }
}
