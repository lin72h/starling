// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if canImport(Glibc)
import Glibc
#endif

/// The store's link to the shell, over the broker socket at
/// `$XDG_RUNTIME_DIR/starling-agent.sock`.
///
/// The shell is the only process that sees every window and every launch, so
/// it is the one that maintains app status; the store subscribes rather than
/// working it out again from `/proc` and drifting from what the dock shows.
/// The subscription is push, not poll: the shell sends a line whenever
/// liveness actually changes, so Remove enables itself the moment you quit an
/// app.
///
/// If the socket is unreachable — the store run outside a session, or an
/// older shell — nothing arrives and the store treats every app as not
/// running. That is the honest degradation: the removal itself is still
/// refused by `app-install`, which does its own check at the point of action.
final class ShellLink: @unchecked Sendable {

    static let shared = ShellLink()

    /// App ids with a live process, whenever the shell reports a change.
    /// Delivered on the main queue.
    var onRunningChanged: (@Sendable (Set<String>) -> Void)?

    private var fd: Int32 = -1
    private let lock = NSLock()

    private init() {}

    private var socketPath: String {
        let dir = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
        return dir + "/starling-agent.sock"
    }

    /// Connect and subscribe. Safe to call once at startup; failure is silent
    /// and simply means no status ever arrives.
    func connect() {
        #if canImport(Glibc)
        lock.lock()
        defer { lock.unlock() }
        guard fd < 0 else { return }

        let sock = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        guard sock >= 0 else { return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
            pathPtr.withMemoryRebound(to: CChar.self, capacity: 108) { buf in
                socketPath.withCString { strncpy(buf, $0, 107) }
            }
        }
        let ok = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Glibc.connect(sock, sa, UInt32(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard ok == 0 else {
            close(sock)
            return
        }
        fd = sock

        let request = Data("{\"op\":\"subscribe_apps\",\"id\":1}\n".utf8)
        _ = request.withUnsafeBytes { Glibc.write(sock, $0.baseAddress, $0.count) }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readLoop(sock)
        }
        #endif
    }

    func disconnect() {
        #if canImport(Glibc)
        lock.lock()
        defer { lock.unlock() }
        if fd >= 0 {
            close(fd)
            fd = -1
        }
        #endif
    }

    #if canImport(Glibc)
    /// JSON-lines reader. Both the subscribe reply and every later push carry
    /// the same `apps` object, so one branch handles both.
    private func readLoop(_ sock: Int32) {
        var pending = Data()
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = read(sock, &buf, buf.count)
            if n <= 0 { break }
            pending.append(contentsOf: buf[0..<n])
            while let nl = pending.firstIndex(of: 0x0A) {
                let line = Data(pending[pending.startIndex..<nl])
                pending = Data(pending[pending.index(after: nl)...])
                if !line.isEmpty { handle(line) }
            }
        }
    }

    private func handle(_ line: Data) {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let apps = obj["apps"] as? [String: Any] else { return }
        // A live process is what blocks removal — an app whose windows are all
        // closed can still be holding its files open.
        var running: Set<String> = []
        for (id, value) in apps {
            guard let fields = value as? [String: Any] else { continue }
            if (fields["process"] as? Bool) == true
                || (fields["window"] as? Bool) == true {
                running.insert(id)
            }
        }
        let handler = onRunningChanged
        DispatchQueue.main.async { handler?(running) }
    }
    #endif
}
