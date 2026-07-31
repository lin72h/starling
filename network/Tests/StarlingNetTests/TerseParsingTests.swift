// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Testing
@testable import StarlingNet

@Suite struct TerseParsing {

    @Test func plainFields() {
        #expect(splitTerseLine("a:b:c") == ["a", "b", "c"])
    }

    @Test func escapedColonInsideField() {
        // An SSID "cafe:5G" arrives as "cafe\:5G".
        #expect(splitTerseLine(#"cafe\:5G:87"#) == ["cafe:5G", "87"])
    }

    @Test func escapedBackslash() {
        #expect(splitTerseLine(#"a\\b:c"#) == [#"a\b"#, "c"])
    }

    @Test func emptyFields() {
        #expect(splitTerseLine("::x:") == ["", "", "x", ""])
    }

    @Test func bssidRoundTrips() {
        let line = #"Starling-Lab:100:WPA2:*:02\:00\:00\:00\:00\:00"#
        #expect(splitTerseLine(line) ==
                ["Starling-Lab", "100", "WPA2", "*", "02:00:00:00:00:00"])
    }
}

@Suite struct DeviceShowParsing {

    // Real `nmcli -t device show` output. Note the MAC's colons are NOT
    // escaped here, unlike every field in `device wifi list` — parsing this
    // with the terse splitter shears the address into octets.
    private let wired = """
        GENERAL.DEVICE:enp3s0
        GENERAL.TYPE:ethernet
        GENERAL.HWADDR:C8:FF:BF:0D:D2:AD
        GENERAL.STATE:100 (connected)
        GENERAL.CONNECTION:Wired connection 1
        CAPABILITIES.SPEED:1000 Mb/s
        WIRED-PROPERTIES.CARRIER:on
        IP4.ADDRESS[1]:192.168.68.60/22
        IP4.GATEWAY:192.168.68.1
        IP4.DNS[1]:75.75.75.75
        IP4.DNS[2]:75.75.76.76
        """

    @Test func macKeepsItsColons() {
        let d = parseLinkDetails(wired, fallbackDevice: "x")
        #expect(d.mac == "C8:FF:BF:0D:D2:AD")
    }

    @Test func readsLinkAndAddressing() {
        let d = parseLinkDetails(wired, fallbackDevice: "x")
        #expect(d.device == "enp3s0")
        #expect(d.kind == "ethernet")
        #expect(d.connected)
        #expect(d.carrier)
        #expect(d.connectionName == "Wired connection 1")
        #expect(d.speed == "1000 Mb/s")
        #expect(d.ipAddress == "192.168.68.60/22")
        #expect(d.gateway == "192.168.68.1")
        #expect(d.dns == ["75.75.75.75", "75.75.76.76"])
    }

    @Test func unpluggedCable() {
        let out = """
            GENERAL.DEVICE:enp3s0
            GENERAL.TYPE:ethernet
            GENERAL.STATE:20 (unavailable)
            GENERAL.CONNECTION:--
            WIRED-PROPERTIES.CARRIER:off
            """
        let d = parseLinkDetails(out, fallbackDevice: "x")
        #expect(!d.connected)
        #expect(!d.carrier)
        #expect(d.connectionName == "")  // "--" means none, not a name
    }

    @Test func wifiHasNoCarrierFieldAndIsNotTreatedAsUnplugged() {
        let out = """
            GENERAL.DEVICE:wlan2
            GENERAL.TYPE:wifi
            GENERAL.STATE:100 (connected)
            GENERAL.CONNECTION:Starling-Lab
            """
        let d = parseLinkDetails(out, fallbackDevice: "x")
        #expect(d.carrier)
        #expect(d.connected)
    }

    @Test func disconnectedStateIsNotConnected() {
        // "30 (disconnected)" contains "connected" as a substring — matching
        // the word alone would read this as connected.
        let out = """
            GENERAL.DEVICE:enp3s0
            GENERAL.STATE:30 (disconnected)
            GENERAL.CONNECTION:--
            """
        #expect(!parseLinkDetails(out, fallbackDevice: "x").connected)
    }
}

@Suite struct WiredSummary {

    @Test func connectedShowsSpeed() {
        let s = WiredStatus(device: "eth0", mac: "", connectionName: "Wired",
                            connected: true, carrier: true, speed: "1000 Mb/s",
                            ipAddress: "", gateway: "", dns: [])
        #expect(s.summary == "Connected \u{2022} 1000 Mb/s")
    }

    @Test func unpluggedSaysSo() {
        let s = WiredStatus(device: "eth0", mac: "", connectionName: "",
                            connected: false, carrier: false, speed: "",
                            ipAddress: "", gateway: "", dns: [])
        #expect(s.summary == "Cable unplugged")
    }

    @Test func pluggedButIdle() {
        let s = WiredStatus(device: "eth0", mac: "", connectionName: "",
                            connected: false, carrier: true, speed: "",
                            ipAddress: "", gateway: "", dns: [])
        #expect(s.summary == "Cable connected, not configured")
    }
}

@Suite struct NetworkListParsing {

    private let sample = """
        Starling-Lab:100:WPA2:*:02\\:00\\:00\\:00\\:00\\:00
        Starling-Guest:98:::02\\:00\\:00\\:00\\:01\\:00
        :55:WPA2::AA\\:AA\\:AA\\:AA\\:AA\\:AA
        Starling-Lab:40:WPA2::02\\:00\\:00\\:00\\:02\\:00
        """

    @Test func parsesFieldsAndSkipsHidden() {
        let nets = WifiManager.parseNetworkList(sample)
        #expect(nets.count == 2)  // hidden SSID dropped, duplicate collapsed
        #expect(nets[0].ssid == "Starling-Lab")
        #expect(nets[0].inUse)
        #expect(nets[0].signal == 100)
        #expect(nets[0].bssid == "02:00:00:00:00:00")
        #expect(nets[1].ssid == "Starling-Guest")
        #expect(nets[1].isOpen)
        #expect(!nets[1].inUse)
    }

    @Test func inUseDuplicateWinsOverStrongerFirst() {
        // The connected BSS is listed after a stronger sibling — the row for
        // that SSID must still show connected.
        let out = """
            Net:90:WPA2::AA\\:AA\\:AA\\:AA\\:AA\\:AA
            Net:60:WPA2:*:BB\\:BB\\:BB\\:BB\\:BB\\:BB
            """
        let nets = WifiManager.parseNetworkList(out)
        #expect(nets.count == 1)
        #expect(nets[0].inUse)
        #expect(nets[0].signal == 60)
    }

    @Test func multiBandSameSsidCollapsesToStrongest() {
        // nmcli lists 2.4 and 5 GHz BSSes of one network separately; the UI
        // shows one row, the strongest.
        let out = """
            Home:88:WPA2::AA\\:AA\\:AA\\:AA\\:AA\\:AA
            Home:42:WPA2::BB\\:BB\\:BB\\:BB\\:BB\\:BB
            """
        let nets = WifiManager.parseNetworkList(out)
        #expect(nets.count == 1)
        #expect(nets[0].signal == 88)
    }

    @Test func connectedSortsFirst() {
        let out = """
            A:99:WPA2::AA\\:AA\\:AA\\:AA\\:AA\\:AA
            B:10:WPA2:*:BB\\:BB\\:BB\\:BB\\:BB\\:BB
            """
        let nets = WifiManager.parseNetworkList(out)
        #expect(nets[0].ssid == "B")
    }
}
