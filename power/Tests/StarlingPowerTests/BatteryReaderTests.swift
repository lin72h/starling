// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import StarlingPower

/// A fake /sys/class/power_supply: each supply is a directory of one-line
/// files, exactly what the kernel exposes — so these fixtures double as
/// documentation of the layouts seen in the wild.
private func fakeRoot(_ supplies: [String: [String: String]]) throws -> String {
    let root = NSTemporaryDirectory() + "power-supply-" + UUID().uuidString
    for (name, files) in supplies {
        try FileManager.default.createDirectory(
            atPath: root + "/" + name, withIntermediateDirectories: true)
        for (file, value) in files {
            try (value + "\n").write(toFile: root + "/" + name + "/" + file,
                                     atomically: true, encoding: .utf8)
        }
    }
    // An empty fixture still needs the root itself.
    try FileManager.default.createDirectory(
        atPath: root, withIntermediateDirectories: true)
    return root
}

@Suite struct BatteryReading {

    @Test func missingRootIsAbsentNotAnError() {
        let s = BatteryReader.read(root: "/nonexistent/power_supply")
        #expect(!s.present)
    }

    @Test func desktopWithOnlyMains() throws {
        let s = BatteryReader.read(root: try fakeRoot([
            "AC": ["type": "Mains", "online": "1"],
        ]))
        #expect(!s.present)
        #expect(s.acOnline)
    }

    @Test func peripheralBatteryIsNotASystemBattery() throws {
        // A wireless mouse: type Battery, scope Device. hid drivers expose
        // these beside the real battery — and on a desktop, instead of one.
        let s = BatteryReader.read(root: try fakeRoot([
            "hidpp_battery_0": ["type": "Battery", "scope": "Device",
                                "capacity": "55", "status": "Discharging"],
        ]))
        #expect(!s.present)
    }

    @Test func dischargingWithEnergyCounters() throws {
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Discharging",
                     "capacity": "73",
                     "energy_now": "36500000", "energy_full": "50000000",
                     "power_now": "10000000"],
            "AC": ["type": "Mains", "online": "0"],
        ]))
        #expect(s.present)
        #expect(s.percent == 73)
        #expect(s.state == .discharging)
        #expect(!s.acOnline)
        // 36.5 Wh at 10 W → 3.65 h → 219 min.
        #expect(s.minutesToEmpty == 219)
        #expect(s.minutesToFull == nil)
    }

    @Test func chargingWithChargeCounters() throws {
        // charge_*/current_now (µAh/µA) is the other kernel layout; the
        // ratio is hours all the same. Current is negative on some drivers.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Charging",
                     "capacity": "50",
                     "charge_now": "2000000", "charge_full": "4000000",
                     "current_now": "-2000000"],
            "AC": ["type": "Mains", "online": "1"],
        ]))
        #expect(s.percent == 50)
        #expect(s.state == .charging)
        #expect(s.acOnline)
        // 2 Ah to go at 2 A → 60 min.
        #expect(s.minutesToFull == 60)
        #expect(s.minutesToEmpty == nil)
    }

    @Test func capacityOnlyBatteryStillReports() throws {
        // Some firmware exposes only `capacity` — no counters, no estimate.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Discharging",
                     "capacity": "42"],
        ]))
        #expect(s.present)
        #expect(s.percent == 42)
        #expect(s.minutesToEmpty == nil)
    }

    @Test func zeroRateMeansNoEstimate() throws {
        // power_now reads 0 for an instant at plug-in; "~∞ remaining" must
        // not be the popup's answer.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Discharging",
                     "capacity": "80",
                     "energy_now": "40000000", "energy_full": "50000000",
                     "power_now": "0"],
        ]))
        #expect(s.percent == 80)
        #expect(s.minutesToEmpty == nil)
    }

    @Test func twoBatteriesAggregateByCounters() throws {
        // A ThinkPad drains one battery at a time: BAT0 full and idle, BAT1
        // half and draining. The pair is one 75% battery to the user —
        // averaging `capacity` would say the same here, but only the summed
        // counters keep that true for unequal battery sizes.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Full",
                     "capacity": "100",
                     "energy_now": "50000000", "energy_full": "50000000",
                     "power_now": "0"],
            "BAT1": ["type": "Battery", "status": "Discharging",
                     "capacity": "50",
                     "energy_now": "25000000", "energy_full": "50000000",
                     "power_now": "15000000"],
        ]))
        #expect(s.percent == 75)
        #expect(s.state == .discharging)
        // The whole pool drains through the one active rate:
        // 75 Wh at 15 W → 300 min.
        #expect(s.minutesToEmpty == 300)
    }

    @Test func fullOnACPower() throws {
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Full", "capacity": "100",
                     "energy_now": "50000000", "energy_full": "50000000",
                     "power_now": "0"],
            "AC": ["type": "Mains", "online": "1"],
        ]))
        #expect(s.state == .full)
        #expect(s.percent == 100)
        #expect(s.acOnline)
        #expect(s.minutesToFull == nil)
    }

    @Test func notChargingAtFirmwareThreshold() throws {
        // Battery-care limit: on AC, holding at 80%, kernel says
        // "Not charging". Neither Full nor Charging is the honest label.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Not charging",
                     "capacity": "80",
                     "energy_now": "40000000", "energy_full": "50000000",
                     "power_now": "0"],
            "AC": ["type": "Mains", "online": "1"],
        ]))
        #expect(s.state == .notCharging)
        #expect(s.acOnline)
        #expect(s.minutesToFull == nil)
    }

    @Test func percentClampsFirmwareOverreport() throws {
        // energy_full degrades below design capacity and some firmware
        // briefly reports now > full; 103% on the popup reads as a bug.
        let s = BatteryReader.read(root: try fakeRoot([
            "BAT0": ["type": "Battery", "status": "Full", "capacity": "100",
                     "energy_now": "51500000", "energy_full": "50000000",
                     "power_now": "0"],
        ]))
        #expect(s.percent == 100)
    }
}
