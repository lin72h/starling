// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The task manager's BLoC, in the shape of the desktop's FileExplorerBloc
// (see CLAUDE.md): one value-type state struct, one event enum, and an
// @Observable bloc whose add(_:) is the only way the UI mutates anything.
// The GTK timeout in main.swift dispatches .tick once a second; everything
// else is user interaction.

#if os(Linux)
import Foundation
import Glibc
import Observation

// MARK: - State

/// The process-table columns the UI can sort by.
enum SortColumn {
    case name, pid, cpu, threads, memory

    /// The direction a fresh sort on this column starts with: usage columns
    /// descending (biggest consumer first), identity columns ascending.
    var startsDescending: Bool {
        switch self {
        case .name, .pid: return false
        case .cpu, .threads, .memory: return true
        }
    }
}

/// The single source of truth for the task manager UI.
struct TaskManagerState {
    /// The latest /proc pass.
    var snapshot = SystemSnapshot()
    /// The table's view of snapshot.processes: filtered and sorted.
    var processes: [ProcessSample] = []

    /// Sliding windows of the last `TaskManagerBloc.historyLength` samples,
    /// oldest first, for the overview sparklines.
    var cpuHistory: [Double] = []          // 0–100
    var memoryHistory: [Double] = []       // 0–1 of MemTotal
    var diskReadHistory: [Double] = []     // bytes/s
    var diskWriteHistory: [Double] = []
    var netRxHistory: [Double] = []
    var netTxHistory: [Double] = []

    var sortColumn: SortColumn = .cpu
    var sortDescending = true
    /// Whether kernel threads (kworker and friends) appear in the table.
    var showKernelThreads = false
    /// The pid of the row selected by tap, if it is still alive.
    var selectedPid: Int32? = nil

    var selectedProcess: ProcessSample? {
        guard let pid = selectedPid else { return nil }
        return processes.first { $0.pid == pid }
    }
}

// MARK: - BLoC

@Observable
final class TaskManagerBloc: @unchecked Sendable {

    /// The events the UI dispatches.
    enum Event {
        /// A new sample is due — the once-a-second heartbeat.
        case tick
        /// A tap on a column header: sort by it, or flip the direction when
        /// it is already the sort column.
        case sortBy(SortColumn)
        case setShowKernelThreads(Bool)
        case select(pid: Int32)
        /// SIGTERM to the selected process — the "End Process" button.
        case terminateSelected
    }

    static let historyLength = 60

    /// The single source of truth for the UI.
    private(set) var state = TaskManagerState()

    @ObservationIgnored private let sampler = SystemSampler()

    init() {
        // Baseline pass so the first frame has a populated table; rates all
        // read zero until the second sample lands.
        add(.tick)
    }

    /// The only way the UI talks to the BLoC.
    func add(_ event: Event) {
        switch event {
        case .tick:
            _tick()
        case .sortBy(let column):
            var s = state
            if s.sortColumn == column {
                s.sortDescending.toggle()
            } else {
                s.sortColumn = column
                s.sortDescending = column.startsDescending
            }
            s.processes = _tableRows(for: s)
            state = s
        case .setShowKernelThreads(let show):
            var s = state
            s.showKernelThreads = show
            s.processes = _tableRows(for: s)
            state = s
        case .select(let pid):
            state.selectedPid = pid
        case .terminateSelected:
            guard let pid = state.selectedPid else { return }
            if kill(pid, SIGTERM) == 0 {
                print("[TaskManager] sent SIGTERM to pid \(pid)")
            } else {
                perror("[TaskManager] kill(\(pid), SIGTERM)")
            }
        }
    }

    // MARK: - Event handlers

    private func _tick() {
        var s = state
        s.snapshot = sampler.sample()

        func push(_ history: inout [Double], _ value: Double) {
            history.append(value)
            if history.count > Self.historyLength { history.removeFirst() }
        }
        push(&s.cpuHistory, s.snapshot.cpuPercent)
        push(&s.memoryHistory,
             s.snapshot.memTotal > 0
                 ? Double(s.snapshot.memUsed) / Double(s.snapshot.memTotal) : 0)
        push(&s.diskReadHistory, s.snapshot.diskReadPerSec)
        push(&s.diskWriteHistory, s.snapshot.diskWritePerSec)
        push(&s.netRxHistory, s.snapshot.netRxPerSec)
        push(&s.netTxHistory, s.snapshot.netTxPerSec)

        s.processes = _tableRows(for: s)
        if let pid = s.selectedPid, !s.processes.contains(where: { $0.pid == pid }) {
            s.selectedPid = nil
        }
        state = s
    }

    private func _tableRows(for s: TaskManagerState) -> [ProcessSample] {
        var rows = s.snapshot.processes
        if !s.showKernelThreads {
            rows.removeAll { $0.isKernelThread }
        }
        rows.sort { a, b in
            let ordered: Bool
            switch s.sortColumn {
            case .name:
                let byName = a.name.lowercased().compare(b.name.lowercased())
                if byName == .orderedSame { return a.pid < b.pid }
                ordered = byName == .orderedAscending
            case .pid:
                ordered = a.pid < b.pid
            case .cpu:
                if a.cpuPercent == b.cpuPercent { return a.pid < b.pid }
                ordered = a.cpuPercent < b.cpuPercent
            case .threads:
                if a.threads == b.threads { return a.pid < b.pid }
                ordered = a.threads < b.threads
            case .memory:
                if a.memoryBytes == b.memoryBytes { return a.pid < b.pid }
                ordered = a.memoryBytes < b.memoryBytes
            }
            return s.sortDescending ? !ordered : ordered
        }
        return rows
    }
}
#endif
