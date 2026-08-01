// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The /proc data layer of the task manager. One SystemSampler that, on each
// sample() call, reads /proc and turns the counter deltas since the previous
// call into rates: system and per-process CPU percentages, disk throughput,
// network throughput. The first call establishes baselines, so its rates all
// read zero.

#if os(Linux)
import Foundation
import Glibc

// MARK: - Samples

/// One process, as the table shows it.
struct ProcessSample {
    let pid: Int32
    let name: String
    /// R (running), S (sleeping), D (disk wait), Z (zombie), T (stopped)…
    let state: Character
    let threads: Int
    /// Share of one core, top-style: a busy 4-thread process reads 400.
    let cpuPercent: Double
    /// Resident set size in bytes.
    let memoryBytes: UInt64
    /// True when /proc/pid/cmdline is empty — a kernel thread (kworker etc.).
    let isKernelThread: Bool
}

/// Everything the UI shows, from one pass over /proc.
struct SystemSnapshot {
    var cpuPercent: Double = 0            // all cores combined, 0–100
    var coreCount: Int = 1
    var memTotal: UInt64 = 0              // bytes
    var memUsed: UInt64 = 0               // MemTotal - MemAvailable
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
    var diskReadPerSec: Double = 0        // bytes/s across physical disks
    var diskWritePerSec: Double = 0
    var netRxPerSec: Double = 0           // bytes/s across non-loopback interfaces
    var netTxPerSec: Double = 0
    var loadAverage: [Double] = [0, 0, 0]
    var uptime: TimeInterval = 0
    var processes: [ProcessSample] = []
    var threadCount: Int = 0
}

// MARK: - Sampler

/// Reads /proc and computes rates from the deltas between consecutive calls.
final class SystemSampler {

    private let pageSize = UInt64(sysconf(Int32(_SC_PAGESIZE)))

    // Previous counters, for the deltas.
    private var prevCPU: (total: UInt64, idle: UInt64)?
    private var prevProcessJiffies: [Int32: UInt64] = [:]
    private var prevDisk: (read: UInt64, written: UInt64)?
    private var prevNet: (rx: UInt64, tx: UInt64)?
    private var prevInstant: Double?

    func sample() -> SystemSnapshot {
        var snapshot = SystemSnapshot()

        var timespec = timespec()
        clock_gettime(CLOCK_MONOTONIC, &timespec)
        let now = Double(timespec.tv_sec) + Double(timespec.tv_nsec) / 1e9
        let interval = prevInstant.map { max(now - $0, 0.001) } ?? 0
        prevInstant = now

        let totalJiffiesDelta = _sampleCPU(into: &snapshot)
        _sampleMemory(into: &snapshot)
        _sampleDisk(into: &snapshot, interval: interval)
        _sampleNetwork(into: &snapshot, interval: interval)
        _sampleLoadAndUptime(into: &snapshot)
        _sampleProcesses(into: &snapshot, totalJiffiesDelta: totalJiffiesDelta)
        return snapshot
    }

    // MARK: /proc/stat

    /// Fills the CPU percentages and returns the all-cores jiffies delta the
    /// per-process percentages are computed against.
    private func _sampleCPU(into snapshot: inout SystemSnapshot) -> UInt64 {
        guard let stat = _read("/proc/stat") else { return 0 }
        snapshot.coreCount = max(Int(sysconf(Int32(_SC_NPROCESSORS_ONLN))), 1)

        for line in stat.split(separator: "\n") {
            let fields = line.split(separator: " ")
            guard fields.count >= 8, fields[0] == "cpu" else { continue }
            // user nice system idle iowait irq softirq steal
            let values = fields.dropFirst().prefix(8).compactMap { UInt64($0) }
            guard values.count == 8 else { break }
            let total = values.reduce(0, +)
            let idle = values[3] + values[4]
            defer { prevCPU = (total, idle) }
            if let prev = prevCPU, total > prev.total {
                let totalDelta = total - prev.total
                let idleDelta = idle > prev.idle ? idle - prev.idle : 0
                snapshot.cpuPercent =
                    100.0 * Double(totalDelta - min(idleDelta, totalDelta)) / Double(totalDelta)
                return totalDelta
            }
            return 0
        }
        return 0
    }

    // MARK: /proc/meminfo

    private func _sampleMemory(into snapshot: inout SystemSnapshot) {
        guard let meminfo = _read("/proc/meminfo") else { return }
        var values: [Substring: UInt64] = [:]
        for line in meminfo.split(separator: "\n") {
            let fields = line.split(separator: " ")
            guard fields.count >= 2, fields[0].hasSuffix(":") else { continue }
            values[fields[0].dropLast()] = UInt64(fields[1]).map { $0 * 1024 }  // kB
        }
        snapshot.memTotal = values["MemTotal"] ?? 0
        let available = values["MemAvailable"] ?? 0
        snapshot.memUsed = snapshot.memTotal > available ? snapshot.memTotal - available : 0
        snapshot.swapTotal = values["SwapTotal"] ?? 0
        let swapFree = values["SwapFree"] ?? 0
        snapshot.swapUsed = snapshot.swapTotal > swapFree ? snapshot.swapTotal - swapFree : 0
    }

    // MARK: /proc/diskstats

    /// A whole physical disk, as opposed to a partition or virtual device:
    /// sda / vdb (trailing letters), nvme0n1 (no pN), mmcblk0 (no pN).
    private func _isWholeDisk(_ name: Substring) -> Bool {
        if name.hasPrefix("sd") || name.hasPrefix("vd") {
            return name.dropFirst(2).allSatisfy { $0.isLetter }
        }
        if name.hasPrefix("nvme") || name.hasPrefix("mmcblk") {
            return !name.dropFirst(4).contains("p")
        }
        return false
    }

    private func _sampleDisk(into snapshot: inout SystemSnapshot, interval: Double) {
        guard let diskstats = _read("/proc/diskstats") else { return }
        var sectorsRead: UInt64 = 0
        var sectorsWritten: UInt64 = 0
        for line in diskstats.split(separator: "\n") {
            let fields = line.split(separator: " ")
            // major minor name reads _ sectorsRead _ writes _ sectorsWritten …
            guard fields.count >= 10, _isWholeDisk(fields[2]) else { continue }
            sectorsRead += UInt64(fields[5]) ?? 0
            sectorsWritten += UInt64(fields[9]) ?? 0
        }
        defer { prevDisk = (sectorsRead, sectorsWritten) }
        guard let prev = prevDisk, interval > 0 else { return }
        // diskstats sectors are always 512 bytes, regardless of the device.
        if sectorsRead >= prev.read {
            snapshot.diskReadPerSec = Double(sectorsRead - prev.read) * 512.0 / interval
        }
        if sectorsWritten >= prev.written {
            snapshot.diskWritePerSec = Double(sectorsWritten - prev.written) * 512.0 / interval
        }
    }

    // MARK: /proc/net/dev

    private func _sampleNetwork(into snapshot: inout SystemSnapshot, interval: Double) {
        guard let netdev = _read("/proc/net/dev") else { return }
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        for line in netdev.split(separator: "\n").dropFirst(2) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let iface = parts[0].trimmingCharacters(in: .whitespaces)
            guard iface != "lo" else { continue }
            let fields = parts[1].split(separator: " ")
            guard fields.count >= 9 else { continue }
            rx += UInt64(fields[0]) ?? 0
            tx += UInt64(fields[8]) ?? 0
        }
        defer { prevNet = (rx, tx) }
        guard let prev = prevNet, interval > 0 else { return }
        if rx >= prev.rx { snapshot.netRxPerSec = Double(rx - prev.rx) / interval }
        if tx >= prev.tx { snapshot.netTxPerSec = Double(tx - prev.tx) / interval }
    }

    // MARK: /proc/loadavg, /proc/uptime

    private func _sampleLoadAndUptime(into snapshot: inout SystemSnapshot) {
        if let loadavg = _read("/proc/loadavg") {
            let fields = loadavg.split(separator: " ").prefix(3).compactMap { Double($0) }
            if fields.count == 3 { snapshot.loadAverage = fields }
        }
        if let uptime = _read("/proc/uptime"),
           let seconds = uptime.split(separator: " ").first.flatMap({ Double($0) }) {
            snapshot.uptime = seconds
        }
    }

    // MARK: /proc/[pid]/…

    private func _sampleProcesses(into snapshot: inout SystemSnapshot, totalJiffiesDelta: UInt64) {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: "/proc") else {
            return
        }
        var processes: [ProcessSample] = []
        var jiffies: [Int32: UInt64] = [:]
        var threadCount = 0

        for entry in entries {
            guard let pid = Int32(entry), let process = _sampleProcess(pid) else { continue }
            jiffies[pid] = process.jiffies

            var cpuPercent = 0.0
            if let prev = prevProcessJiffies[pid], process.jiffies >= prev,
               totalJiffiesDelta > 0 {
                // top-style: 100% is one core saturated.
                cpuPercent = 100.0 * Double(process.jiffies - prev) / Double(totalJiffiesDelta)
                    * Double(snapshot.coreCount)
            }
            threadCount += process.threads
            processes.append(ProcessSample(
                pid: pid,
                name: process.name,
                state: process.state,
                threads: process.threads,
                cpuPercent: cpuPercent,
                memoryBytes: process.rssPages * pageSize,
                isKernelThread: process.isKernelThread
            ))
        }
        prevProcessJiffies = jiffies
        snapshot.processes = processes
        snapshot.threadCount = threadCount
    }

    private func _sampleProcess(_ pid: Int32) -> (
        name: String, state: Character, threads: Int, jiffies: UInt64,
        rssPages: UInt64, isKernelThread: Bool
    )? {
        guard let stat = _read("/proc/\(pid)/stat"),
              // comm may itself contain spaces and parens; it ends at the
              // *last* ")" of the line.
              let open = stat.firstIndex(of: "("),
              let close = stat.lastIndex(of: ")") else { return nil }
        let comm = String(stat[stat.index(after: open)..<close])
        // Fields from 3 (state) on, 1-based proc(5) numbering: field n is
        // rest[n - 3]. utime 14, stime 15, num_threads 20, rss 24.
        let rest = stat[stat.index(after: close)...].split(separator: " ")
        guard rest.count >= 22 else { return nil }
        let utime = UInt64(rest[11]) ?? 0
        let stime = UInt64(rest[12]) ?? 0

        // Prefer the executable name from cmdline: comm is truncated to 15
        // chars, and an empty cmdline marks a kernel thread.
        var name = comm
        var isKernelThread = false
        if let cmdline = _read("/proc/\(pid)/cmdline"), !cmdline.isEmpty {
            let argv0 = cmdline.split(separator: "\0").first.map(String.init) ?? ""
            if let executable = argv0.split(separator: "/").last, !executable.isEmpty {
                // An interpreter running a script shows the script's name.
                name = executable.hasPrefix(comm) || comm.count < 15 ? String(executable) : comm
            }
        } else {
            isKernelThread = true
        }

        return (
            name: name,
            state: rest[0].first ?? "?",
            threads: Int(rest[17]) ?? 1,
            jiffies: utime + stime,
            rssPages: UInt64(rest[21]) ?? 0,
            isKernelThread: isKernelThread
        )
    }

    // MARK: Reading /proc

    /// Plain read(2) loop: /proc files report size 0, which trips readers
    /// that trust the stat size.
    private func _read(_ path: String) -> String? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var contents = [UInt8]()
        var buffer = [UInt8](repeating: 0, count: 1 << 16)
        while true {
            let n = read(fd, &buffer, buffer.count)
            guard n > 0 else { break }
            contents.append(contentsOf: buffer[0..<n])
        }
        return contents.isEmpty ? "" : String(decoding: contents, as: UTF8.self)
    }
}

// MARK: - Formatting

/// 1536 → "1.5 KB"; binary units, one decimal above KB.
func formatBytes(_ bytes: UInt64) -> String {
    formatBytes(Double(bytes))
}

func formatBytes(_ bytes: Double) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = bytes
    var unit = 0
    while value >= 1024, unit < units.count - 1 {
        value /= 1024
        unit += 1
    }
    return unit == 0
        ? "\(Int(value)) B"
        : String(format: "%.1f %@", value, units[unit])
}

/// Bytes/s with the same scaling: "1.5 MB/s".
func formatRate(_ bytesPerSecond: Double) -> String {
    formatBytes(bytesPerSecond) + "/s"
}
#endif
