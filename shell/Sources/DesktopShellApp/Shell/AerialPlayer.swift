// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if os(Linux)
import Glibc

/// Plays a looping aerial clip for the screensaver: one spawned ffmpeg per
/// run, raw RGBA down a pipe, frames published to a mailbox the shell drains
/// on the main thread.
///
/// Nothing here links FFmpeg — the process boundary is deliberate, exactly as
/// in VideoPlayerApp's PipeDecoder (the linked decoder was dropped in ade2f64
/// for the GPL it dragged in; the .deb already Recommends the ffmpeg binary
/// for the screen recorder).
///
/// **This is the CPU path, and it is the cheap prototype, not the answer.**
/// A 4K RGBA frame is 33MB, so source-resolution playback needs ~800MB/s down
/// a pipe plus the same again into glTexImage2D — measured at ~11x slower than
/// realtime on the dev box. So frames are decoded at the size they are SHOWN
/// (`STARLING_AERIAL_RES`, default half the panel) and scaled up by the
/// compositor. Full-resolution aerials need VAAPI decode straight into a
/// dmabuf imported by LinuxTextureRegistry.importDmaBuf — no CPU copy at all.
///
/// Pacing is the READER's job: the pipe is forced to exact CFR, so holding the
/// reader to one frame per interval IS holding playback to real time.
final class AerialPlayer: @unchecked Sendable {

    let width: Int
    let height: Int
    let fps: Double

    private let process = Process()
    private let out = Pipe()
    private var thread: Thread?
    private var stopped = false

    // Mailbox: the reader fills it, the shell's screensaver ticker drains it
    // on the main thread. Same shape as RecordingService's frame mailbox —
    // it keeps the reader off the main queue entirely, so teardown can never
    // deadlock against an in-flight upload.
    private let lock = NSLock()
    private var mailbox: UnsafeMutableRawPointer?
    private var mailboxFilled = false

    private static func findTool(_ tool: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/\(tool)") {
            return "/usr/bin/\(tool)"
        }
        for dir in (env["PATH"] ?? "").split(separator: ":") {
            let p = "\(dir)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    /// The first playable clip: `STARLING_AERIAL` (a file or a directory),
    /// else an `aerials/` directory beside the wallpapers, else
    /// ~/.local/share/starling/aerials. Nil means "no aerials installed" —
    /// the screensaver falls back to the liquid warp, which needs no assets.
    static func discoverClip() -> String? {
        let fm = FileManager.default
        var dirs: [String] = []
        if let env = ProcessInfo.processInfo.environment["STARLING_AERIAL"],
           !env.isEmpty {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: env, isDirectory: &isDir) {
                if !isDir.boolValue { return env }
                dirs.append(env)
            }
        }
        if let packaged = _DesktopShellState.dataFilePath("aerials") {
            dirs.append(packaged)
        }
        dirs.append(LoginUser.home + "/.local/share/starling/aerials")

        let exts = ["mp4", "mov", "m4v", "webm", "mkv"]
        for dir in dirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            let clips = names
                .filter { exts.contains(($0 as NSString).pathExtension.lowercased()) }
                .sorted()
            if let first = clips.first { return dir + "/" + first }
        }
        return nil
    }

    /// Letterbox bars are real content in the file, and a cover-crop to the
    /// panel aspect crops width — so bars would survive it. cropdetect finds
    /// the active rectangle first. Returns nil if it can't tell (then the
    /// filter chain just cover-crops the whole frame).
    private static func detectActiveRect(clip: String, ffmpeg: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = [
            "-hide_banner", "-ss", "5", "-i", clip,
            "-vf", "cropdetect=24:2:0", "-frames:v", "40", "-f", "null", "-",
        ]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let data = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        // Last "crop=W:H:X:Y" wins — cropdetect converges as it sees frames.
        var found: String?
        for line in text.split(separator: "\n") {
            guard let r = line.range(of: "crop=") else { continue }
            let tail = line[r.upperBound...]
            let spec = tail.prefix { $0.isNumber || $0 == ":" }
            if spec.split(separator: ":").count == 4 { found = String(spec) }
        }
        return found
    }

    /// Spawn a looping decode of `clip` at exactly `width`x`height`, cropped
    /// to cover that aspect (never pillarboxed — a screensaver fills the
    /// screen). Returns nil if ffmpeg is missing or won't start.
    init?(clip: String, width: Int, height: Int, fps: Double = 24.0) {
        guard let ffmpeg = Self.findTool("ffmpeg") else { return nil }
        self.width = max(2, width & ~1)
        self.height = max(2, height & ~1)
        self.fps = min(60, max(1, fps))

        var filters: [String] = []
        if let active = Self.detectActiveRect(clip: clip, ffmpeg: ffmpeg) {
            filters.append("crop=\(active)")
        }
        // Cover-scale then crop: fills the panel aspect with no bars.
        filters.append(
            "scale=\(self.width):\(self.height):force_original_aspect_ratio=increase")
        filters.append("crop=\(self.width):\(self.height)")
        // Exact CFR at the rate the reader paces — without it the rawvideo
        // muxer picks its own and playback runs fast or frozen-slow.
        filters.append(String(format: "fps=%.4f", self.fps))

        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-hide_banner", "-loglevel", "error",
            "-stream_loop", "-1",          // loop forever; the saver may run for hours
            "-i", clip,
            "-vf", filters.joined(separator: ","),
            "-f", "rawvideo", "-pix_fmt", "rgba", "-an",
            "pipe:1",
        ]
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        signal(SIGPIPE, SIG_IGN)
        guard (try? process.run()) != nil else { return nil }

        mailbox = UnsafeMutableRawPointer.allocate(
            byteCount: self.width * self.height * 4,
            alignment: MemoryLayout<UInt8>.alignment)
    }

    func start() {
        let t = Thread { [weak self] in self?.readLoop() }
        t.name = "aerial decode"
        t.stackSize = 512 * 1024
        thread = t
        t.start()
    }

    private func readLoop() {
        let frameBytes = width * height * 4
        var buffer = [UInt8](repeating: 0, count: frameBytes)
        let fd = out.fileHandleForReading.fileDescriptor
        let interval = 1.0 / fps
        var next = Date().timeIntervalSinceReferenceDate

        while !stopped {
            var got = 0
            let ok: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
                guard let base = raw.baseAddress else { return false }
                while got < frameBytes {
                    let n = read(fd, base + got, frameBytes - got)
                    if n > 0 {
                        got += n
                    } else if n < 0 && errno == EINTR {
                        continue
                    } else {
                        return false  // EOF or the pipe closed under stop()
                    }
                }
                return true
            }
            guard ok, !stopped else { break }

            lock.lock()
            if let box = mailbox {
                buffer.withUnsafeBytes { raw in
                    if let base = raw.baseAddress {
                        box.copyMemory(from: base, byteCount: frameBytes)
                    }
                }
                mailboxFilled = true
            }
            lock.unlock()

            next += interval
            let now = Date().timeIntervalSinceReferenceDate
            if next > now {
                usleep(UInt32((next - now) * 1_000_000))
            } else {
                next = now  // fell behind (a slow upload); don't sprint to catch up
            }
        }
    }

    /// Hand the newest decoded frame to `body`, or do nothing if none has
    /// arrived since the last drain. Main thread only.
    func withNewFrame(_ body: (UnsafeRawPointer, Int, Int) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard mailboxFilled, let box = mailbox else { return }
        mailboxFilled = false
        body(box, width, height)
    }

    /// Kill the decode run. Safe from the main thread and more than once —
    /// the reader never blocks on the main queue, so this cannot deadlock.
    func stop() {
        stopped = true
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        try? out.fileHandleForReading.close()
        process.waitUntilExit()
        lock.lock()
        mailbox?.deallocate()
        mailbox = nil
        mailboxFilled = false
        lock.unlock()
    }
}

#endif
