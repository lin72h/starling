// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Everything `nmcli device show <dev>` reports that any of the UIs care
/// about, for a device of any type. One call answers identity, link state and
/// IP configuration, so neither the WiFi nor the wired path has to assemble
/// them from several queries.
public struct LinkDetails: Equatable {
    public let device: String
    public let kind: String          // "ethernet", "wifi", …
    public let mac: String
    /// The active connection's name, empty when the device is not connected.
    public let connectionName: String
    /// True once NetworkManager reports the device connected.
    public let connected: Bool
    /// Cable present. Meaningless for WiFi, where it reads true.
    public let carrier: Bool
    /// Negotiated link speed as nmcli phrases it ("1000 Mb/s"), or empty.
    public let speed: String
    public let ipAddress: String
    public let gateway: String
    public let dns: [String]
}

/// Parse `nmcli -t ... device show` output into key → values.
///
/// Values here are NOT terse-escaped the way `device wifi list` fields are —
/// a MAC arrives as a bare `C8:FF:BF:0D:D2:AD` — so this splits on the first
/// colon only and keeps the rest verbatim. Repeated keys are indexed
/// (`IP4.DNS[1]`, `IP4.DNS[2]`); the index is stripped and values accumulate
/// in order under the bare key.
func parseDeviceShow(_ output: String) -> [String: [String]] {
    var fields: [String: [String]] = [:]
    for line in output.split(separator: "\n") {
        guard let colon = line.firstIndex(of: ":") else { continue }
        var key = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])
        if let bracket = key.firstIndex(of: "[") {
            key = String(key[key.startIndex..<bracket])
        }
        fields[key, default: []].append(value)
    }
    return fields
}

/// Read one device's details, or nil if nmcli cannot describe it.
public func linkDetails(_ device: String) -> LinkDetails? {
    let r = runTool(WifiManager.nmcli, [
        "-t", "-f",
        "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.HWADDR,GENERAL.STATE," +
        "GENERAL.CONNECTION,CAPABILITIES.SPEED,WIRED-PROPERTIES.CARRIER," +
        "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS",
        "device", "show", device])
    guard r.ok else { return nil }
    return parseLinkDetails(r.stdout, fallbackDevice: device)
}

/// Visible for tests.
func parseLinkDetails(_ output: String, fallbackDevice: String) -> LinkDetails {
    let f = parseDeviceShow(output)
    func first(_ key: String) -> String { f[key]?.first ?? "" }

    // GENERAL.CONNECTION is the literal "--" when nothing is active.
    var connection = first("GENERAL.CONNECTION")
    if connection == "--" { connection = "" }

    return LinkDetails(
        device: first("GENERAL.DEVICE").isEmpty
            ? fallbackDevice : first("GENERAL.DEVICE"),
        kind: first("GENERAL.TYPE"),
        mac: first("GENERAL.HWADDR"),
        connectionName: connection,
        // "100 (connected)" — match the word, not the number, so a future
        // state code can't be read as connected by accident.
        connected: first("GENERAL.STATE").contains("(connected)"),
        // Absent for non-wired devices; treat that as "no cable question".
        carrier: f["WIRED-PROPERTIES.CARRIER"].map { $0.first == "on" } ?? true,
        speed: first("CAPABILITIES.SPEED"),
        ipAddress: first("IP4.ADDRESS"),
        gateway: first("IP4.GATEWAY"),
        dns: f["IP4.DNS"] ?? []
    )
}
