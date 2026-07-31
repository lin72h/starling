// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Models

public struct WifiNetwork: Equatable {
    public let ssid: String
    public let signal: Int         // 0-100
    public let security: String    // e.g. "WPA2", "WPA2 WPA3", "" for open
    public let inUse: Bool         // currently connected
    public let bssid: String

    public init(ssid: String, signal: Int, security: String, inUse: Bool,
                bssid: String) {
        self.ssid = ssid
        self.signal = signal
        self.security = security
        self.inUse = inUse
        self.bssid = bssid
    }

    public var isOpen: Bool { security.isEmpty }

    public var signalBars: String {
        if signal >= 75 { return "\u{2582}\u{2584}\u{2586}\u{2588}" }
        if signal >= 50 { return "\u{2582}\u{2584}\u{2586} " }
        if signal >= 25 { return "\u{2582}\u{2584}  " }
        return "\u{2582}   "
    }

    public var securityLabel: String {
        if isOpen { return "Open" }
        return security
    }
}

/// Active connection details.
public struct WifiConnectionInfo: Equatable {
    public let ssid: String
    public let device: String      // e.g. "wlan2"
    public let mac: String         // the device's hardware address
    public let ipAddress: String
    public let gateway: String
    public let dns: [String]
    public let signal: Int
    public let security: String

    public init(ssid: String, device: String, mac: String, ipAddress: String,
                gateway: String, dns: [String], signal: Int, security: String) {
        self.ssid = ssid
        self.device = device
        self.mac = mac
        self.ipAddress = ipAddress
        self.gateway = gateway
        self.dns = dns
        self.signal = signal
        self.security = security
    }
}

// MARK: - Terse-output parsing

/// Split one line of `nmcli -t` output into fields. Terse mode separates
/// fields with `:` and escapes literal `:` and `\` inside a value with a
/// backslash — an SSID like "cafe:5G" arrives as "cafe\:5G", and every BSSID
/// arrives as "AA\:BB\:…". A plain split-on-colon silently shears both, which
/// is why this helper exists and is the only splitter WifiManager uses.
func splitTerseLine(_ line: some StringProtocol) -> [String] {
    var fields: [String] = []
    var current = ""
    var escaped = false
    for ch in line {
        if escaped {
            current.append(ch)
            escaped = false
        } else if ch == "\\" {
            escaped = true
        } else if ch == ":" {
            fields.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    fields.append(current)
    return fields
}
