// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StarlingRecord

#if os(Linux)
import Glibc
import FlutterDRMBridge

/// Owns a screen-recording session: engine frames in, a finished MP4 in
/// ~/Videos out, through StarlingRecord's ffmpeg pipe.
///
/// Threads. The engine delivers frames on ITS recorder writer thread —
/// `ingest` copies into the mailbox under the lock and returns. The pacer
/// queue turns the mailbox into a constant 30fps stream for ffmpeg: raw
/// video over a pipe carries no timestamps, so pacing IS the timeline —
/// the last frame repeats while the desktop idles, extras drop while it
/// presents at 60. `state`/`onChange` are main-thread only, like all shell
/// state.
///
/// Present pump. The engine consumes start/stop requests on its presenting
/// thread, and an idle desktop never presents — the shell's 33ms frame-tick
/// timer must force composites from the moment a session starts until the
/// engine confirms the stop (`needsFramePump`), or the session never starts
/// and never ends. See fl_drm_view.h's recording block.
final class RecordingService {

    enum State { case idle, starting, recording, stopping }

    /// Main-thread only.
    private(set) var state: State = .idle
    private(set) var startedAt: Date? = nil
    private(set) var lastSavedPath: String? = nil
    var onChange: (() -> Void)?
    /// Fires on main after a session ends: (saved file, or nil) + detail.
    var onFinished: ((String?, String) -> Void)?

    static let fps = 30

    /// The tile dims itself on machines that cannot record (no ffmpeg).
    /// Checked once — packages don't come and go under a live session.
    lazy var available: Bool = FfmpegEncoder.findFfmpeg() != nil

    // VAAPI probe result — a real test encode, run once. Warmed in the
    // background at init so the first Record tap doesn't pay the ~200ms;
    // the lock makes a too-early tap wait for it instead of racing it.
    private let hwLock = NSLock()
    private var hwProbed = false
    private var hwEncoder: HardwareEncoder?

    init() {
        let warm: () -> Void = { [weak self] in
            _ = self?.resolveHardwareEncoder()
        }
        queue.async(execute: unsafeBitCast(warm, to: (@Sendable () -> Void).self))
    }

    private func resolveHardwareEncoder() -> HardwareEncoder? {
        hwLock.lock()
        defer { hwLock.unlock() }
        if !hwProbed {
            if let ffmpeg = FfmpegEncoder.findFfmpeg() {
                hwEncoder = FfmpegEncoder.detectHardwareEncoder(ffmpegPath: ffmpeg)
            }
            hwProbed = true
            if hwEncoder == nil {
                let msg = "[Recording] no VAAPI encoder — software x264, "
                    + "large screens capture at half size\n"
                _ = msg.withCString { write(2, $0, strlen($0)) }
            }
        }
        return hwEncoder
    }

    /// What the last (or current) session captures at, and through which
    /// encoder — the broker reports these so tests assert the file against
    /// the shell's own claim rather than re-deriving the policy.
    private(set) var captureWidth = 0
    private(set) var captureHeight = 0
    private(set) var usingHardware = false

    var isRecording: Bool { state == .starting || state == .recording }
    /// The frame-tick pump must run while this holds (see class comment).
    var needsFramePump: Bool { state != .idle }

    var elapsedSeconds: Int {
        guard let t = startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(t)))
    }

    // Mailbox: the newest engine frame. Written by the engine's writer
    // thread, drained by the pacer queue; the lock covers only the copy.
    private let mailboxLock = NSLock()
    private var mailbox: [UInt8] = []
    private var mailboxW = 0
    private var mailboxH = 0
    private var mailboxFresh = false

    private let queue = DispatchQueue(label: "starling.shell.record",
                                      qos: .userInitiated)
    private var pacer: DispatchSourceTimer?
    private var encoder: FfmpegEncoder?
    private var scratch: [UInt8] = []

    // MARK: Frame ingest (engine writer thread)

    func ingest(_ rgba: UnsafePointer<UInt8>?, width: Int, height: Int) {
        guard let rgba, width > 0, height > 0 else { return }
        let bytes = width * height * 4
        mailboxLock.lock()
        if mailboxW != width || mailboxH != height {
            mailbox = [UInt8](repeating: 0, count: bytes)
            mailboxW = width
            mailboxH = height
        }
        mailbox.withUnsafeMutableBytes { buf in
            memcpy(buf.baseAddress!, rgba, bytes)
        }
        mailboxFresh = true
        mailboxLock.unlock()
    }

    // MARK: Session control (main thread)

    /// Window recording: returns the tracked window's rect in PHYSICAL px,
    /// or nil once the window is gone. Read on main by refreshWindowCrop.
    private var windowRect: (() -> (x: Int, y: Int, w: Int, h: Int)?)? = nil
    /// The recorded window's display name (nil = whole screen).
    private(set) var windowLabel: String? = nil

    /// Record the whole screen, or — with a rect provider — one window:
    /// the engine crops the composited frame to the rect, which the pump
    /// re-reads every tick so the recording follows moves. Output size
    /// freezes at the rect's start size.
    func start(windowRect: (() -> (x: Int, y: Int, w: Int, h: Int)?)? = nil,
               windowLabel label: String? = nil) {
        guard state == .idle else { return }
        guard let ffmpeg = FfmpegEncoder.findFfmpeg(),
              let view = drmViewHandle else {
            onFinished?(nil, "ffmpeg is not installed")
            return
        }
        let crop = windowRect?()
        if windowRect != nil && crop == nil {
            onFinished?(nil, "the window is gone")
            return
        }
        let w = crop?.w ?? Int(fl_drm_view_get_width(view))
        let h = crop?.h ?? Int(fl_drm_view_get_height(view))
        guard w > 0, h > 0 else { return }

        // Hardware encodes the full screen for free; software x264 at 4K
        // starved a real desktop into unresponsiveness, so it captures at
        // half size (the engine downscales on the GPU, not us).
        let hw = resolveHardwareEncoder()
        let shift = FfmpegEncoder.downscaleShift(width: w, height: h,
                                                 hardware: hw != nil)
        let cw = max(1, w >> shift)
        let ch = max(1, h >> shift)

        let dir = RecordingPaths.videosDir(home: LoginUser.home)
        Self.ensureOwnedDir(dir)
        let url = RecordingPaths.outputURL(in: dir, now: Date(), label: label)
        guard let enc = try? FfmpegEncoder(width: cw, height: ch,
                                           fps: Self.fps, outputURL: url,
                                           ffmpegPath: ffmpeg,
                                           hardware: hw) else {
            onFinished?(nil, "could not start ffmpeg")
            return
        }

        mailboxLock.lock()
        mailboxFresh = false
        mailboxLock.unlock()

        encoder = enc
        captureWidth = cw
        captureHeight = ch
        usingHardware = hw != nil
        self.windowRect = windowRect
        self.windowLabel = label
        state = .starting
        startedAt = Date()
        fl_drm_view_recording_start_cropped(
            view, Int32(shift),
            Int32(crop?.x ?? 0), Int32(crop?.y ?? 0),
            Int32(crop?.w ?? 0), Int32(crop?.h ?? 0))
        startPacer(deadline: Date().addingTimeInterval(3))
        onChange?()
    }

    /// Called from the shell's frame-tick pump while recording: keep the
    /// engine's crop on the window as it moves, and end the session (the
    /// footage so far is saved) when the window goes away.
    func refreshWindowCrop() {
        guard state == .starting || state == .recording,
              let provider = windowRect else { return }
        if let r = provider() {
            fl_drm_view_recording_set_crop(Int32(r.x), Int32(r.y),
                                           Int32(r.w), Int32(r.h))
        } else {
            stop()
        }
    }

    func stop() { endSession(reason: nil) }

    /// Stop with a failure `reason` (nil = normal stop, keep the file).
    private func endSession(reason: String?) {
        guard state == .starting || state == .recording else { return }
        state = .stopping
        onChange?()
        fl_drm_view_recording_stop(drmViewHandle)
        pacer?.cancel()
        pacer = nil

        let enc = encoder
        encoder = nil
        let failure = reason
        let work: () -> Void = { [weak self] in
            // The engine joins its writer thread when it consumes the stop
            // (recording_active drops); after that no ingest can be running.
            // The pump keeps presents flowing while we wait. Cap the wait —
            // a VT switch mid-stop could park presents indefinitely.
            var waitedMs = 0
            while fl_drm_view_recording_active() != 0 && waitedMs < 3000 {
                usleep(50_000)
                waitedMs += 50
            }
            var saved: String? = nil
            var detail = failure ?? ""
            if let enc {
                if failure == nil, enc.finish() {
                    saved = enc.outputURL.path
                    Self.chownToLoginUser(enc.outputURL.path)
                } else {
                    if failure == nil {
                        detail = enc.frameCount == 0
                            ? "no frames were captured"
                            : "ffmpeg failed: \(enc.errorOutput)"
                    }
                    enc.abort()
                }
            }
            let finish: () -> Void = { [weak self] in
                guard let self else { return }
                self.state = .idle
                self.startedAt = nil
                self.windowRect = nil
                self.windowLabel = nil
                if saved != nil { self.lastSavedPath = saved }
                self.onChange?()
                self.onFinished?(saved, detail)
            }
            DispatchQueue.main.async(
                execute: unsafeBitCast(finish, to: (@Sendable () -> Void).self))
        }
        queue.async(execute: unsafeBitCast(work, to: (@Sendable () -> Void).self))
    }

    // MARK: Pacing (pacer queue)

    private func startPacer(deadline: Date) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(33),
                       repeating: .nanoseconds(1_000_000_000 / Self.fps))
        timer.setEventHandler { [weak self] in
            self?.pacerTick(startDeadline: deadline)
        }
        timer.resume()
        pacer = timer
    }

    private func pacerTick(startDeadline: Date) {
        guard let enc = encoder else { return }

        mailboxLock.lock()
        let have = mailboxFresh
        if have {
            if scratch.count != mailbox.count { scratch = mailbox }
            else {
                scratch.withUnsafeMutableBytes { dst in
                    mailbox.withUnsafeBytes { src in
                        memcpy(dst.baseAddress!, src.baseAddress!, src.count)
                    }
                }
            }
        }
        let mw = mailboxW, mh = mailboxH
        mailboxLock.unlock()

        guard have else {
            // Engine never delivered a first frame (callback unset, ES3
            // missing) — fail rather than sit in .starting forever.
            if Date() > startDeadline {
                hopToMain { $0.endSession(reason: "the engine delivered no frames") }
            }
            return
        }
        // A display mode switch mid-recording changes the frame size; the
        // encoder is fixed-size, so hold the last good frame (the pacer
        // repeats it) rather than feed ffmpeg garbage.
        guard mw == enc.width, mh == enc.height else { return }

        let ok = scratch.withUnsafeBytes { enc.appendFrame($0) }
        if !ok {
            hopToMain { $0.endSession(reason: "ffmpeg exited mid-recording") }
            return
        }
        if enc.frameCount == 1 {
            hopToMain {
                guard $0.state == .starting else { return }
                $0.state = .recording
                $0.onChange?()
            }
        }
    }

    private func hopToMain(_ body: @escaping (RecordingService) -> Void) {
        let run: () -> Void = { [weak self] in
            guard let self else { return }
            body(self)
        }
        DispatchQueue.main.async(
            execute: unsafeBitCast(run, to: (@Sendable () -> Void).self))
    }

    // MARK: Root-mode ownership

    /// Dev mode runs the shell as root; a recording the login user cannot
    /// open or delete is a bug. No-ops unprivileged.
    private static func chownToLoginUser(_ path: String) {
        guard getuid() == 0 else { return }
        if let pw = getpwuid(LoginUser.uid) {
            chown(path, pw.pointee.pw_uid, pw.pointee.pw_gid)
        }
    }

    private static func ensureOwnedDir(_ dir: URL) {
        let existed = FileManager.default.fileExists(atPath: dir.path)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        if !existed { chownToLoginUser(dir.path) }
    }
}

#endif
