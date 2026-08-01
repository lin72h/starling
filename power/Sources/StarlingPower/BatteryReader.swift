// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Models

public enum BatteryChargeState: Equatable {
    case charging
    case discharging
    /// Charged and on external power.
    case full
    /// On external power but deliberately not charging (firmware charge
    /// thresholds, battery-care limits). Distinct from `full`: the kernel
    /// reports "Not charging" at, say, 80% on a ThinkPad with a stop
    /// threshold, and calling that "Full" would contradict the percentage
    /// shown right next to it.
    case notCharging
    case unknown

    public var label: String {
        switch self {
        case .charging: return "Charging"
        case .discharging: return "Discharging"
        case .full: return "Full"
        case .notCharging: return "Not Charging"
        case .unknown: return "Unknown"
        }
    }
}

/// Point-in-time battery picture, aggregated over every system battery
/// (dual-battery laptops report BAT0 and BAT1; treating them as one is what
/// every desktop does, because the firmware drains and fills them as one).
public struct BatteryStatus: Equatable {
    /// A system battery exists. False is a desktop — no icon, no popup —
    /// not an error.
    public var present = false
    /// 0–100 across all batteries, capacity-weighted when the kernel exposes
    /// the underlying charge/energy counters.
    public var percent = 0
    public var state: BatteryChargeState = .unknown
    /// An external supply (Mains/USB) reports online. Independent of `state`:
    /// "Not charging" at a firmware threshold is still on AC power.
    public var acOnline = false
    /// Whole minutes until full (charging) or empty (discharging), when the
    /// kernel exposes a usable rate. Nil means "don't show an estimate", not
    /// zero — rates read 0 at plug-in and on batteries that don't report one.
    public var minutesToFull: Int? = nil
    public var minutesToEmpty: Int? = nil

    public init() {}
}

// MARK: - Reader

/// Reads `/sys/class/power_supply` — the same files every Linux desktop's
/// power daemon reads, without needing the daemon. Synchronous smallfile
/// reads; call off the main thread anyway (a misbehaving driver can stall
/// a sysfs read).
public enum BatteryReader {

    /// Overridable for tests and simulation: point
    /// `STARLING_POWER_SUPPLY_DIR` at a directory of fake supplies and the
    /// whole stack — reader, shell icon, popup, broker — runs against it.
    public static var defaultRoot: String {
        ProcessInfo.processInfo.environment["STARLING_POWER_SUPPLY_DIR"]
            ?? "/sys/class/power_supply"
    }

    public static func read(root: String = BatteryReader.defaultRoot) -> BatteryStatus {
        var status = BatteryStatus()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else {
            return status
        }

        var batteries: [SupplyReading] = []
        for entry in entries.sorted() {
            let dir = root + "/" + entry
            switch file(dir, "type") {
            case "Battery":
                // A "Device"-scope battery is a peripheral — a wireless
                // mouse, earbuds. Counting one turns a desktop into a
                // laptop with a mystery battery that drains overnight.
                if file(dir, "scope") == "Device" { continue }
                batteries.append(SupplyReading(dir: dir))
            case "Mains", "USB":
                if intFile(dir, "online") == 1 { status.acOnline = true }
            default:
                break
            }
        }

        guard !batteries.isEmpty else { return status }
        status.present = true
        status.percent = aggregatePercent(batteries)
        status.state = aggregateState(batteries)

        // Estimates only when every battery has both a level pair and a
        // rate, all in the same unit family (µWh/µW or µAh/µA — the ratio is
        // hours either way, but mixing families is nonsense). Multi-battery
        // machines share one driver, so in practice this only rules out the
        // batteries that report nothing.
        if let (now, full, rate) = aggregateCounters(batteries), rate > 0 {
            switch status.state {
            case .charging:
                status.minutesToFull = Int((Double(full - now) / Double(rate) * 60)
                                           .rounded())
            case .discharging:
                status.minutesToEmpty = Int((Double(now) / Double(rate) * 60)
                                            .rounded())
            default:
                break
            }
        }
        return status
    }

    // MARK: One battery's files

    /// The kernel exposes levels either as energy_* (µWh, with power_now in
    /// µW) or charge_* (µAh, with current_now in µA), rarely both.
    private struct SupplyReading {
        let status: String
        let capacity: Int?
        let now: Int?
        let full: Int?
        let rate: Int?
        /// True for energy_* (µWh) counters, false for charge_* (µAh).
        let energyUnits: Bool

        init(dir: String) {
            status = file(dir, "status")
            capacity = intFile(dir, "capacity")
            if let e = intFile(dir, "energy_now") {
                now = e
                full = intFile(dir, "energy_full")
                rate = intFile(dir, "power_now").map { abs($0) }
                energyUnits = true
            } else {
                now = intFile(dir, "charge_now")
                full = intFile(dir, "charge_full")
                // Sign convention varies by driver: some report discharge
                // as a negative current.
                rate = intFile(dir, "current_now").map { abs($0) }
                energyUnits = false
            }
        }
    }

    private static func aggregatePercent(_ batteries: [SupplyReading]) -> Int {
        // Prefer the raw counters — summing them weights a big and a small
        // battery correctly where averaging `capacity` would not.
        if let (now, full, _) = sumCounters(batteries, needRate: false), full > 0 {
            return min(100, max(0, Int((Double(now) / Double(full) * 100).rounded())))
        }
        let caps = batteries.compactMap { $0.capacity }
        guard !caps.isEmpty else { return 0 }
        return min(100, max(0, caps.reduce(0, +) / caps.count))
    }

    private static func aggregateState(_ batteries: [SupplyReading]) -> BatteryChargeState {
        // Firmware fills/drains one battery at a time, so the interesting
        // state is whatever any battery is doing; "Full" only when none is
        // doing anything and all report it.
        let states = batteries.map { $0.status }
        if states.contains("Charging") { return .charging }
        if states.contains("Discharging") { return .discharging }
        if states.contains("Not charging") { return .notCharging }
        if !states.isEmpty && states.allSatisfy({ $0 == "Full" }) { return .full }
        return .unknown
    }

    private static func aggregateCounters(_ batteries: [SupplyReading])
        -> (now: Int, full: Int, rate: Int)? {
        return sumCounters(batteries, needRate: true)
    }

    private static func sumCounters(_ batteries: [SupplyReading], needRate: Bool)
        -> (now: Int, full: Int, rate: Int)? {
        guard let units = batteries.first?.energyUnits,
              batteries.allSatisfy({ $0.energyUnits == units }) else { return nil }
        var now = 0, full = 0, rate = 0
        for b in batteries {
            guard let n = b.now, let f = b.full else { return nil }
            if needRate {
                guard let r = b.rate else { return nil }
                rate += r
            }
            now += n
            full += f
        }
        return (now, full, rate)
    }

    // MARK: sysfs primitives

    private static func file(_ dir: String, _ name: String) -> String {
        guard let raw = try? String(contentsOfFile: dir + "/" + name,
                                    encoding: .utf8) else { return "" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func intFile(_ dir: String, _ name: String) -> Int? {
        let s = file(dir, name)
        return s.isEmpty ? nil : Int(s)
    }
}
