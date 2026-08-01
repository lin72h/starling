// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StarlingPower

/// Owns the shell's battery picture. Reads land in `snapshot` on the main
/// thread and `onChange` fires there — but only when something actually
/// changed, so the 5s poll does not repaint an idle desktop (compare the
/// wifi timer, which ticks only while its popup is open; battery state has
/// to move the bar icon with every popup closed, so it polls all the time
/// and stays quiet instead).
final class BatteryService {

    /// Main-thread only, like all shell state.
    private(set) var snapshot = BatteryStatus()
    var onChange: (() -> Void)?

    private let queue = DispatchQueue(label: "starling.shell.battery",
                                      qos: .utility)
    private var timer: DispatchSourceTimer?

    func start() {
        refreshNow()
        let t = DispatchSource.makeTimerSource(queue: .main)
        // 5s covers the fastest thing worth showing promptly — the charging
        // bolt after plugging in. The read is a handful of sysfs files.
        t.schedule(deadline: .now() + .seconds(5), repeating: .seconds(5))
        t.setEventHandler { [weak self] in self?.refreshNow() }
        t.resume()
        timer = t
    }

    /// Re-read sysfs off the main thread — cheap, but a misbehaving driver
    /// can stall a sysfs read, and the compositor must not stall with it.
    func refreshNow() {
        let work: () -> Void = { [weak self] in
            let status = BatteryReader.read()
            let apply: () -> Void = { [weak self] in
                guard let self, self.snapshot != status else { return }
                self.snapshot = status
                self.onChange?()
            }
            DispatchQueue.main.async(
                execute: unsafeBitCast(apply, to: (@Sendable () -> Void).self))
        }
        queue.async(execute: unsafeBitCast(work, to: (@Sendable () -> Void).self))
    }
}
