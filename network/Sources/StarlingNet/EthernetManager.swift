// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A wired interface as the UIs present it.
public struct WiredStatus: Equatable {
    public let device: String
    public let mac: String
    /// Active connection's name, empty when the device is not connected.
    public let connectionName: String
    public let connected: Bool
    /// Cable present. False here is the "plug it in" case, and is worth
    /// saying out loud — a wired row that just reads "Not connected" with a
    /// cable hanging out of the socket tells the user nothing.
    public let carrier: Bool
    public let speed: String
    public let ipAddress: String
    public let gateway: String
    public let dns: [String]

    /// One line for the row subtitle.
    public var summary: String {
        if connected {
            return speed.isEmpty ? "Connected" : "Connected \u{2022} \(speed)"
        }
        return carrier ? "Cable connected, not configured" : "Cable unplugged"
    }
}

/// Wired networking. Far smaller than the WiFi surface: there is nothing to
/// scan and nothing to authenticate, so the UI only shows what the link is
/// doing and offers connect/disconnect.
public struct EthernetManager {

    /// Managed wired devices, in nmcli's order. Bridges, bonds, tunnels and
    /// the loopback are excluded — only true `ethernet` devices, so a docker0
    /// or virbr0 bridge never shows up as "your network".
    public static func devices() -> [String] {
        let r = runTool(WifiManager.nmcli, ["-t", "-f", "DEVICE,TYPE,STATE",
                                            "device", "status"])
        guard r.ok else { return [] }
        return r.stdout.split(separator: "\n").compactMap { line in
            let parts = splitTerseLine(line)
            guard parts.count >= 3, parts[1] == "ethernet",
                  parts[2] != "unmanaged" else { return nil }
            return parts[0]
        }
    }

    /// Every managed wired interface. Settings lists them all; the shell's
    /// popup shows only `status()`.
    public static func statuses() -> [WiredStatus] {
        return devices().compactMap { linkDetails($0) }.map {
            WiredStatus(
                device: $0.device,
                mac: $0.mac,
                connectionName: $0.connectionName,
                connected: $0.connected,
                carrier: $0.carrier,
                speed: $0.speed,
                ipAddress: $0.ipAddress,
                gateway: $0.gateway,
                dns: $0.dns)
        }
    }

    /// The wired link worth showing in one row: the connected one if there is
    /// any, else the first with a cable, else simply the first. A desktop with
    /// two NICs should report the one carrying traffic, not whichever nmcli
    /// happens to list first.
    public static func status() -> WiredStatus? {
        let all = statuses()
        return all.first { $0.connected } ?? all.first { $0.carrier } ?? all.first
    }

    /// Bring the wired link up. With no profile for it NetworkManager creates
    /// and activates one (the usual DHCP default), which is what `device
    /// connect` means for ethernet.
    public static func connect(device: String) -> String? {
        let r = runTool(WifiManager.nmcli, ["-w", WifiManager.activateTimeout,
                                            "device", "connect", device])
        return r.ok ? nil : r.errorText
    }

    public static func disconnect(device: String) -> String? {
        let r = runTool(WifiManager.nmcli, ["-w", WifiManager.activateTimeout,
                                            "device", "disconnect", device])
        return r.ok ? nil : r.errorText
    }
}
