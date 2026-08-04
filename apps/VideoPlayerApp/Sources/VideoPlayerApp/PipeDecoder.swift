// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if os(Linux)
import Glibc

// Video decoding through a SPAWNED ffmpeg — nothing here links libav (the
// linked decoder was removed in ade2f64 for the GPL it dragged in; the
// process boundary is the point). ffprobe answers the metadata, then one
// ffmpeg per playback run streams raw RGBA frames down a pipe as fast as
// the reader drains it — the reader paces (not -re; see init). The pipe is
// forced to exact CFR at info.fps so pacing frame counts IS pacing time.
// Pause and seek are "kill it, respawn at the position" — no codec state
// to manage, and a fresh -ss lands on a keyframe.

struct VideoInfo {
    var width = 0
    var height = 0
    var fps = 30.0
    var duration = 0.0
}

enum FfmpegPaths {
    static func find(_ tool: String) -> String? {
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
}

// @unchecked: the process handle is written only in init, readFrame runs on
// the single reader thread, and stop() is safe from anywhere (kill + close).
final class PipeDecoder: @unchecked Sendable {

    /// One ffprobe run: dimensions, frame rate, duration.
    static func probe(path: String) -> VideoInfo? {
        guard let ffprobe = FfmpegPaths.find("ffprobe") else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffprobe)
        p.arguments = [
            "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate:format=duration",
            "-of", "json", path,
        ]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let root = (try? JSONSerialization.jsonObject(with: data))
                  as? [String: Any],
              let streams = root["streams"] as? [[String: Any]],
              let v = streams.first,
              let w = v["width"] as? Int, let h = v["height"] as? Int
        else { return nil }

        var info = VideoInfo(width: w, height: h)
        // The PLAYBACK rate, and it must match what the decode pipe carries.
        // This was avg_frame_rate, and on the desktop's own screen
        // recordings — VFR files whose encoder skips unchanged frames, so
        // 54 real frames can span a 24s timeline — avg comes out at ~2fps
        // while ffmpeg's rawvideo output pads to CFR at r_frame_rate (60).
        // Pacing a 60fps pipe at 2fps played the file in 26x slow motion:
        // the position clock looked right while the picture sat on the
        // first frame — "the recording is frozen", except the file was
        // fine. r_frame_rate is the rate the pipe actually ticks at; the
        // spawn below forces exactly this rate with -vf fps= so the two
        // can never disagree again, and the cap keeps a 2560x1600 RGBA
        // pipe (8MB a frame) inside what a desktop player needs.
        if let rate = v["r_frame_rate"] as? String {
            let parts = rate.split(separator: "/").compactMap { Double($0) }
            if parts.count == 2, parts[1] > 0, parts[0] > 0 {
                info.fps = min(30, max(1, parts[0] / parts[1]))
            }
        }
        if let fmt = root["format"] as? [String: Any],
           let dur = fmt["duration"] as? String, let d = Double(dur) {
            info.duration = d
        }
        return info
    }

    /// The frame size ffmpeg is asked for: the source, shrunk to fit
    /// `maxWidth`×`maxHeight` with the aspect ratio kept, and never enlarged
    /// (upscaling here would cost bytes on the wire to add nothing).
    ///
    /// A player must not decode more pixels than it shows. The desktop's own
    /// screen recordings are the whole screen — 2560x1600 — and the player
    /// window is a fraction of that, so decoding at the source size pushed
    /// 16MB of RGBA per frame down the pipe and then into `glTexImage2D`, for
    /// a picture drawn into 1708x1020. That upload is what made the window
    /// FLICKER: it runs on the raster thread, and the shell composites the
    /// app's single shared buffer zero-copy, so every millisecond the buffer
    /// spends cleared-but-not-yet-drawn is a millisecond the shell may sample
    /// it as black. Measured on the dev box: 40% of the shell's presented
    /// frames showed the window fully black at the source size, 0.7% at the
    /// window size.
    static func outputSize(for info: VideoInfo, maxWidth: Int, maxHeight: Int)
        -> (width: Int, height: Int)
    {
        guard info.width > 0, info.height > 0, maxWidth > 0, maxHeight > 0 else {
            return (info.width, info.height)
        }
        let scale = min(Double(maxWidth) / Double(info.width),
                        Double(maxHeight) / Double(info.height))
        guard scale < 1 else { return (info.width, info.height) }
        // Even dimensions — swscale is happiest there, and half a pixel is
        // not visible at these sizes.
        let w = max(2, Int((Double(info.width) * scale).rounded()) & ~1)
        let h = max(2, Int((Double(info.height) * scale).rounded()) & ~1)
        return (w, h)
    }

    let startPosition: Double
    /// The size of the frames this run actually emits — `outputSize` applied
    /// to the caller's cap. The reader sizes its buffers from this, NOT from
    /// `info`, which still describes the file.
    let outWidth: Int
    let outHeight: Int
    private let process = Process()
    private let out = Pipe()
    private var stopped = false

    /// Spawn ffmpeg decoding `path` from `start` seconds, RGBA on stdout,
    /// scaled to fit `maxWidth`×`maxHeight`, as fast as the pipe drains — the
    /// READER paces playback. Not `-re`: -ss lands on the previous keyframe
    /// and decodes forward to the target, and -re throttles that pre-roll to
    /// realtime too, so a seek landing 7s past a keyframe showed its first
    /// frame 7 real seconds later — indistinguishable from seeking not
    /// working at all.
    init?(path: String, start: Double, info: VideoInfo,
          maxWidth: Int, maxHeight: Int) {
        guard let ffmpeg = FfmpegPaths.find("ffmpeg") else { return nil }
        startPosition = max(0, start)
        let size = Self.outputSize(for: info, maxWidth: maxWidth, maxHeight: maxHeight)
        outWidth = size.width
        outHeight = size.height

        // `scale` BEFORE `fps`: fps duplicates frames to reach CFR, and on a
        // sparse screen recording that is most of them (297 real frames
        // become 1219 at 30fps). Scaling first scales the frames the file
        // has; scaling after would scale the copies too.
        var filters: [String] = []
        if size.width != info.width || size.height != info.height {
            filters.append("scale=\(size.width):\(size.height)")
        }
        // Exact CFR at the rate the reader paces (info.fps — see probe).
        // Without this the rawvideo muxer picks its own CFR rate, and a
        // reader pacing at a different one plays fast or frozen-slow.
        filters.append(String(format: "fps=%.4f", info.fps))

        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-hide_banner", "-loglevel", "error",
            "-ss", String(format: "%.3f", startPosition),
            "-i", path,
            "-vf", filters.joined(separator: ","),
            "-f", "rawvideo", "-pix_fmt", "rgba", "-an",
            "pipe:1",
        ]
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        signal(SIGPIPE, SIG_IGN)
        guard (try? process.run()) != nil else { return nil }
    }

    /// Blocking read of one full frame into `buffer` (sized w*h*4 by the
    /// caller). False on EOF or after stop() — the playback loop's exit.
    func readFrame(into buffer: inout [UInt8]) -> Bool {
        let fd = out.fileHandleForReading.fileDescriptor
        let need = buffer.count
        var got = 0
        let ok: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return false }
            while got < need {
                let n = read(fd, base + got, need - got)
                if n > 0 {
                    got += n
                } else if n < 0 && errno == EINTR {
                    continue
                } else {
                    return false  // EOF or error — partial frames are dropped
                }
            }
            return true
        }
        return ok && !stopped
    }

    /// Kill the decode run. readFrame unblocks with false; safe to call
    /// from any thread, more than once.
    func stop() {
        stopped = true
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        // Closing the read end guarantees a blocked readFrame returns even
        // if the kill races the pipe's buffered tail.
        try? out.fileHandleForReading.close()
        process.waitUntilExit()
    }
}

#endif
