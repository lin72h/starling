// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter   // realUserHomeDirectory()
import Foundation
#if os(Linux)
import Glibc
#endif

// The POSIX implementation. PtyWindows.swift provides the same type, with the
// same surface, over ConPTY — Windows has no forkpty and no SIGWINCH.
#if !os(Windows)

/// A pseudo-terminal running a shell process.
///
/// Opens the PTY master, forks, and execs the shell on the slave side with
/// TERM=xterm-256color. A dedicated reader thread delivers master output via
/// `onData`; `write` sends keyboard bytes; `resize` updates the kernel window
/// size (which delivers SIGWINCH to the foreground process group).
final class Pty: @unchecked Sendable {

    // ioctl request numbers (linux, generic): these are macros in C headers
    // that Swift's Glibc module does not export.
    private static let TIOCSCTTY: UInt = 0x540E
    private static let TIOCSWINSZ: UInt = 0x5414

    let masterFd: Int32
    let childPid: pid_t

    /// Called on the reader thread with each chunk read from the master.
    var onData: (([UInt8]) -> Void)?

    /// Called on the reader thread when the child exits / the PTY closes.
    var onExit: (() -> Void)?

    private var readerThread: Thread?

    init?(cols: Int, rows: Int) {
        // ── Master side ─────────────────────────────────────────────────
        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0 else { return nil }
        guard grantpt(master) == 0, unlockpt(master) == 0 else {
            close(master)
            return nil
        }
        var nameBuf = [CChar](repeating: 0, count: 256)
        guard ptsname_r(master, &nameBuf, nameBuf.count) == 0 else {
            close(master)
            return nil
        }
        let slavePath = String(cString: nameBuf)

        var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols),
                         ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master, Pty.TIOCSWINSZ, &ws)

        // ── Prepare exec arguments BEFORE fork (no allocation after) ────
        let shellPath = Pty._shellPath()
        let home = Pty._homeDir()
        var argv: [UnsafeMutablePointer<CChar>?] = [
            strdup((shellPath as NSString).lastPathComponent),
            nil,
        ]
        var envp: [UnsafeMutablePointer<CChar>?] = []
        for (key, value) in ProcessInfo.processInfo.environment {
            if key == "TERM" || key == "HOME" { continue }
            envp.append(strdup("\(key)=\(value)"))
        }
        envp.append(strdup("TERM=xterm-256color"))
        envp.append(strdup("COLORTERM=truecolor"))
        envp.append(strdup("HOME=\(home)"))
        envp.append(nil)
        let shellPathC = strdup(shellPath)
        let homeC = strdup(home)

        // ── Fork + exec ─────────────────────────────────────────────────
        let pid = fork()
        if pid < 0 {
            close(master)
            return nil
        }
        if pid == 0 {
            // Child: only async-signal-safe calls from here.
            setsid()
            let slave = slavePath.withCString { open($0, O_RDWR) }
            if slave < 0 { _exit(127) }
            _ = ioctl(slave, Pty.TIOCSCTTY, 0)
            dup2(slave, 0)
            dup2(slave, 1)
            dup2(slave, 2)
            if slave > 2 { close(slave) }
            close(master)
            if let homeC = homeC { _ = chdir(homeC) }
            if let path = shellPathC {
                execve(path, &argv, &envp)
            }
            _exit(127)
        }

        // Parent
        self.masterFd = master
        self.childPid = pid
        argv.forEach { free($0) }
        envp.forEach { free($0) }
        free(shellPathC)
        free(homeC)
    }

    /// The shell to run: the Starling devbox when configured (terminal
    /// sessions live in the developer toolbox — a persistent, mutable
    /// container over the sealed base; see starling-os tools/dev-shell.sh),
    /// else $SHELL, else bash/sh.
    private static func _shellPath() -> String {
        let fm = FileManager.default
        if let dev = ProcessInfo.processInfo.environment["STARLING_DEV_SHELL"],
           fm.isExecutableFile(atPath: dev) {
            return dev
        }
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           fm.isExecutableFile(atPath: shell) {
            return shell
        }
        for candidate in ["/bin/bash", "/usr/bin/bash", "/bin/sh"] {
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return "/bin/sh"
    }

    /// The home directory for the shell. In dev mode the shell runs under
    /// sudo, so HOME is /root — realUserHomeDirectory() resolves the invoking
    /// account instead.
    private static func _homeDir() -> String { realUserHomeDirectory() }

    /// Starts the reader loop on a background thread.
    func startReader() {
        let thread = Thread { [weak self] in
            // 64K rather than 8K: every read is an allocation for the chunk
            // and a trip through feed + a repaint request, and a terminal
            // being flooded gets a full buffer every time. Eight times fewer
            // of each, for 56 KB.
            var buf = [UInt8](repeating: 0, count: 65536)
            while true {
                guard let self = self else { return }
                let n = read(self.masterFd, &buf, buf.count)
                if n > 0 {
                    self.onData?(Array(buf[0..<n]))
                } else {
                    if n < 0 && (errno == EINTR || errno == EAGAIN) { continue }
                    self.onExit?()
                    return
                }
            }
        }
        thread.name = "pty-reader"
        thread.start()
        readerThread = thread
    }

    /// Writes bytes to the shell's input.
    func write(_ bytes: [UInt8]) {
        var remaining = bytes[...]
        while !remaining.isEmpty {
            let n = remaining.withUnsafeBytes { ptr -> Int in
                Glibc.write(masterFd, ptr.baseAddress, ptr.count)
            }
            if n <= 0 { return }
            remaining = remaining.dropFirst(n)
        }
    }

    func write(_ text: String) {
        write(Array(text.utf8))
    }

    /// Updates the kernel's window size (SIGWINCH is delivered to the child).
    func resize(cols: Int, rows: Int) {
        var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols),
                         ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFd, Pty.TIOCSWINSZ, &ws)
    }

    func terminate() {
        kill(childPid, SIGHUP)
        close(masterFd)
    }
}

#endif  // !os(Windows)
