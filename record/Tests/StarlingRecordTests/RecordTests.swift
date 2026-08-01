// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import StarlingRecord

@Suite struct OutputNaming {

    // Built through DateComponents in the current calendar so the expected
    // string is timezone-independent (the formatter renders local time).
    private func date(_ y: Int, _ mo: Int, _ d: Int,
                      _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute, c.second) = (y, mo, d, h, mi, s)
        return Calendar.current.date(from: c)!
    }

    @Test func stampedName() {
        let dir = URL(fileURLWithPath: "/tmp/nowhere")
        let url = RecordingPaths.outputURL(in: dir,
                                           now: date(2026, 8, 1, 14, 30, 5))
        #expect(url.lastPathComponent
                == "Screen Recording 2026-08-01 at 14.30.05.mp4")
        #expect(url.deletingLastPathComponent().path == dir.path)
    }

    @Test func collisionGetsSuffix() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("record-test-\(getpid())")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = date(2026, 8, 1, 9, 0, 0)
        let first = RecordingPaths.outputURL(in: dir, now: now)
        FileManager.default.createFile(atPath: first.path, contents: Data())
        let second = RecordingPaths.outputURL(in: dir, now: now)
        #expect(second.lastPathComponent
                == "Screen Recording 2026-08-01 at 09.00.00 2.mp4")
        FileManager.default.createFile(atPath: second.path, contents: Data())
        let third = RecordingPaths.outputURL(in: dir, now: now)
        #expect(third.lastPathComponent
                == "Screen Recording 2026-08-01 at 09.00.00 3.mp4")
    }

    @Test func videosDir() {
        #expect(RecordingPaths.videosDir(home: "/home/u").path
                == "/home/u/Videos")
    }
}

@Suite struct EncoderArguments {

    @Test func rawInputAndDimensions() {
        let args = FfmpegEncoder.arguments(width: 1920, height: 1080,
                                           fps: 30, outputPath: "/tmp/o.mp4")
        #expect(args.contains("rawvideo"))
        #expect(args.contains("rgba"))
        #expect(args.contains("1920x1080"))
        #expect(args.contains("pipe:0"))
        #expect(args.last == "/tmp/o.mp4")
        // Even-dimension guard: a 1367-wide panel must not kill libx264.
        #expect(args.contains("crop=trunc(iw/2)*2:trunc(ih/2)*2"))
        #expect(args.contains("yuv420p"))
    }

    @Test func ffmpegOverrideIsAuthoritative() {
        // An explicit override that doesn't exist is a configuration error
        // to surface, not something to silently fall back from.
        #expect(FfmpegEncoder.findFfmpeg(
            environment: ["STARLING_FFMPEG": "/bin/true"]) == "/bin/true")
        #expect(FfmpegEncoder.findFfmpeg(
            environment: ["STARLING_FFMPEG": "/no/such/binary",
                          "PATH": "/usr/bin"]) == nil)
    }
}

@Suite struct Encoding {

    /// A real (tiny) encode through the real ffmpeg: 10 solid frames at
    /// 64×64. Skips quietly on a machine with no ffmpeg — the desktop
    /// packages it as a dependency, the test box may not have it.
    @Test func tinyClipEncodes() throws {
        guard let ffmpeg = FfmpegEncoder.findFfmpeg() else { return }
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("record-test-\(getpid()).mp4")
        defer { try? FileManager.default.removeItem(at: out) }

        let enc = try FfmpegEncoder(width: 64, height: 64, fps: 30,
                                    outputURL: out, ffmpegPath: ffmpeg)
        var frame = [UInt8](repeating: 0, count: 64 * 64 * 4)
        for n in 0..<10 {
            for i in stride(from: 0, to: frame.count, by: 4) {
                frame[i] = UInt8(n * 20)      // R ramps per frame
                frame[i + 1] = 0x40
                frame[i + 2] = 0x80
                frame[i + 3] = 0xFF
            }
            let ok = frame.withUnsafeBytes { enc.appendFrame($0) }
            #expect(ok)
        }
        #expect(enc.finish(), "ffmpeg failed: \(enc.errorOutput)")
        let size = (try? FileManager.default
            .attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
        #expect((size ?? 0) > 500)
    }

    @Test func wrongSizeFrameRejected() throws {
        guard let ffmpeg = FfmpegEncoder.findFfmpeg() else { return }
        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("record-badframe-\(getpid()).mp4")
        let enc = try FfmpegEncoder(width: 64, height: 64, fps: 30,
                                    outputURL: out, ffmpegPath: ffmpeg)
        defer { enc.abort() }
        let tooSmall = [UInt8](repeating: 0, count: 16)
        #expect(tooSmall.withUnsafeBytes { enc.appendFrame($0) } == false)
    }
}
