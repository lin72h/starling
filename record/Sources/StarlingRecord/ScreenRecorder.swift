// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if os(Linux)
import Glibc
#endif

// MARK: - Output naming

public enum RecordingPaths {

    /// Where recordings land: `<home>/Videos`. No xdg-user-dirs lookup —
    /// the desktop ships English-only today and the shell already treats
    /// `~/Videos` as the user's media directory.
    public static func videosDir(home: String) -> URL {
        URL(fileURLWithPath: home).appendingPathComponent("Videos")
    }

    /// "Screen Recording 2026-08-01 at 14.30.05.mp4" — the macOS shape,
    /// dots in the time because a colon in a filename confuses enough
    /// tools to matter. Collisions (two recordings inside one second)
    /// get " 2", " 3", … suffixes rather than overwriting.
    public static func outputURL(in dir: URL, now: Date,
                                 fileManager: FileManager = .default) -> URL {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let stamp = fmt.string(from: now)
        let base = "Screen Recording \(stamp)"
        var candidate = dir.appendingPathComponent(base + ".mp4")
        var n = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n).mp4")
            n += 1
        }
        return candidate
    }
}

// MARK: - Hardware encoding

/// A VAAPI H.264 encode path that has actually passed a test frame: the
/// render node plus the upload/convert filter chain that worked on it.
/// Detection is a real (tiny) encode, not a capability query — drivers
/// advertise entrypoints they then fail to open.
public struct HardwareEncoder: Equatable, Sendable {
    public let device: String       // /dev/dri/renderD128
    public let videoFilter: String  // upload/convert chain, worked on probe

    public init(device: String, videoFilter: String) {
        self.device = device
        self.videoFilter = videoFilter
    }
}

// MARK: - Encoder

/// One recording session: ffmpeg spawned at start, raw RGBA frames written
/// to its stdin at a constant rate, MP4 finalized on finish. The caller
/// owns pacing — this class encodes exactly the frames it is handed.
///
/// Frames must be top-down RGBA, width*height*4 bytes, at the dimensions
/// given at init. All methods are synchronous and none are main-thread
/// safe to call from the UI: appendFrame blocks on the pipe (that is the
/// backpressure), finish blocks on the encode tail. Use a dedicated queue.
public final class FfmpegEncoder {

    public let width: Int
    public let height: Int
    public let fps: Int
    public let outputURL: URL
    public private(set) var frameCount = 0

    private let process = Process()
    private let stdinPipe = Pipe()
    private let stderrPipe = Pipe()
    private var stdinClosed = false
    private var pipeDead = false

    /// $STARLING_FFMPEG override first (tests, odd installs), then the
    /// packaged dependency's fixed path, then a PATH walk for dev boxes.
    public static func findFfmpeg(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let override = environment["STARLING_FFMPEG"], !override.isEmpty {
            return FileManager.default.isExecutableFile(atPath: override)
                ? override : nil
        }
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/ffmpeg") {
            return "/usr/bin/ffmpeg"
        }
        for dir in (environment["PATH"] ?? "").split(separator: ":") {
            let p = "\(dir)/ffmpeg"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    /// Probe for a working VAAPI H.264 path: every render node, two filter
    /// chains each — GPU-side format conversion first (scale_vaapi, near
    /// zero CPU), CPU-side swscale as the fallback. A candidate passes by
    /// encoding a real test clip, so a pass means the whole pipeline
    /// (device, upload, convert, encoder) opens. ~200ms when the first
    /// candidate works; run it off the main thread and cache the result.
    public static func detectHardwareEncoder(
        ffmpegPath: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HardwareEncoder? {
        if environment["STARLING_NO_VAAPI"] == "1" { return nil }
        let devices: [String]
        if let dev = environment["STARLING_VAAPI_DEVICE"], !dev.isEmpty {
            devices = [dev]
        } else {
            devices = ((try? FileManager.default
                .contentsOfDirectory(atPath: "/dev/dri")) ?? [])
                .filter { $0.hasPrefix("renderD") }.sorted()
                .map { "/dev/dri/" + $0 }
        }
        for device in devices {
            for vf in ["hwupload,scale_vaapi=format=nv12",
                       "format=nv12,hwupload"] {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: ffmpegPath)
                p.arguments = [
                    "-hide_banner", "-loglevel", "error",
                    "-f", "lavfi",
                    "-i", "color=black:size=256x256:rate=30:duration=0.2",
                    "-init_hw_device", "vaapi=va:\(device)",
                    "-filter_hw_device", "va",
                    "-vf", vf,
                    "-c:v", "h264_vaapi", "-qp", "24",
                    "-f", "null", "-",
                ]
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                p.standardInput = FileHandle.nullDevice
                guard (try? p.run()) != nil else { return nil }
                p.waitUntilExit()
                if p.terminationStatus == 0 {
                    return HardwareEncoder(device: device, videoFilter: vf)
                }
            }
        }
        return nil
    }

    /// Capture downscale for a screen. Hardware encodes full resolution;
    /// software x264 above ~1080p worth of pixels is what froze a 4K
    /// desktop solid, so it captures at half size instead.
    public static func downscaleShift(width: Int, height: Int,
                                      hardware: Bool) -> Int {
        if hardware { return 0 }
        return width * height > 2_400_000 ? 1 : 0
    }

    /// The full ffmpeg invocation, exposed for the tests: raw RGBA on
    /// stdin at a declared constant rate, H.264 out — through VAAPI when a
    /// probed path is handed in, libx264 otherwise. The crop drops at most
    /// one row/column — 4:2:0 needs even dimensions and panels are not
    /// obliged to provide them.
    public static func arguments(width: Int, height: Int, fps: Int,
                                 outputPath: String,
                                 hardware: HardwareEncoder? = nil) -> [String] {
        var args = [
            "-hide_banner", "-loglevel", "error",
            "-f", "rawvideo",
            "-pixel_format", "rgba",
            "-video_size", "\(width)x\(height)",
            "-framerate", "\(fps)",
            "-i", "pipe:0",
        ]
        if let hw = hardware {
            args += [
                "-init_hw_device", "vaapi=va:\(hw.device)",
                "-filter_hw_device", "va",
                "-vf", "crop=trunc(iw/2)*2:trunc(ih/2)*2,\(hw.videoFilter)",
                "-c:v", "h264_vaapi",
                "-qp", "24",
            ]
        } else {
            args += [
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "23",
                "-vf", "crop=trunc(iw/2)*2:trunc(ih/2)*2",
                "-pix_fmt", "yuv420p",
            ]
        }
        args += ["-movflags", "+faststart", "-y", outputPath]
        return args
    }

    public init(width: Int, height: Int, fps: Int, outputURL: URL,
                ffmpegPath: String, hardware: HardwareEncoder? = nil) throws {
        self.width = width
        self.height = height
        self.fps = fps
        self.outputURL = outputURL

        // A dead ffmpeg must surface as EPIPE from write(), not as a
        // process-killing SIGPIPE. Process-wide, and deliberately so:
        // any process streaming into children wants this disposition.
        signal(SIGPIPE, SIG_IGN)

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = Self.arguments(width: width, height: height,
                                           fps: fps,
                                           outputPath: outputURL.path,
                                           hardware: hardware)
        process.standardInput = stdinPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe
        try process.run()
    }

    /// Write one frame. False when the frame is the wrong size or ffmpeg
    /// has died (EPIPE) — the caller should stop the session and report.
    @discardableResult
    public func appendFrame(_ frame: UnsafeRawBufferPointer) -> Bool {
        guard frame.count == width * height * 4, !pipeDead, !stdinClosed,
              let base = frame.baseAddress else { return false }
        let fd = stdinPipe.fileHandleForWriting.fileDescriptor
        var offset = 0
        while offset < frame.count {
            let n = write(fd, base + offset, frame.count - offset)
            if n > 0 {
                offset += n
            } else if errno == EINTR {
                continue
            } else {
                pipeDead = true
                return false
            }
        }
        frameCount += 1
        return true
    }

    /// Close the stream and let ffmpeg finalize the MP4 (faststart
    /// re-muxes at the end, so this can take a moment on long clips).
    /// Returns true when ffmpeg exited 0 and the file exists; on failure
    /// `errorOutput` carries ffmpeg's stderr.
    public private(set) var errorOutput = ""
    @discardableResult
    public func finish(timeout: TimeInterval = 30) -> Bool {
        closeStdin()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            process.terminate()
            usleep(500_000)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        errorOutput = String(data: err, encoding: .utf8) ?? ""
        return process.terminationStatus == 0 && frameCount > 0
            && FileManager.default.fileExists(atPath: outputURL.path)
    }

    /// Kill the session and delete the partial file (start-up failures,
    /// zero-frame recordings — nothing worth keeping).
    public func abort() {
        closeStdin()
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: outputURL)
    }

    private func closeStdin() {
        guard !stdinClosed else { return }
        stdinClosed = true
        try? stdinPipe.fileHandleForWriting.close()
    }
}
