// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

#if os(Linux)
import CH264Decoder
import Flutter
import Glibc

// The zero-copy playback path: the GPU decodes into a DMA-BUF and the
// compositor samples that buffer directly. Nothing crosses a pipe, nothing is
// uploaded, and the CPU never touches a pixel — and no libav is involved at
// any point, in the process or in the link graph.
//
// It is deliberately narrow (see h264_decoder.h): progressive MP4, H.264, one
// reference, no B-frames — the shape the desktop's own recorder produces.
// Anything else is refused and PipeDecoder plays it by spawning ffmpeg, which
// is also what happens for every other container and codec. The narrow path
// exists to make the common case — reviewing your own screen recording —
// zero-copy, not to be a general decoder.

/// Which render node to decode on. Must be the node the app's EGL display was
/// created on, or the compositor is handed a buffer allocated on a device it
/// cannot import from — the same pairing rule GpuDmaBufRenderer.drmCandidates
/// applies, reused here rather than re-derived.
enum VaapiDevice {
    static func node() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let forced = env["STARLING_VIDEO_VAAPI_DEVICE"] {
            return forced.isEmpty ? nil : forced
        }
        // Render nodes only: decode needs no KMS, and the primary node is
        // what the shell holds.
        return GpuDmaBufRenderer.drmCandidates().first {
            ($0 as NSString).lastPathComponent.hasPrefix("renderD")
        }
    }
}

/// One hardware-decoded frame, valid until `release`.
struct HwFrame {
    var fd: Int32
    var width: Int32
    var height: Int32
    var modifier: UInt64
    var offset0: UInt32, pitch0: UInt32
    var offset1: UInt32, pitch1: UInt32
    var position: Double
    /// Opaque handle back to the decoder's surface slot. Carried as a bit
    /// pattern, not a pointer, so the release closure that hands it back can
    /// cross to the raster thread as @Sendable.
    var token: UInt
}

/// @unchecked: the handle is written only in init; `next` runs on the single
/// reader thread; `stop` and `release` take the lock.
final class H264Source: @unchecked Sendable {

    /// Metadata straight from the MP4 index — no process spawn, no libav.
    /// Nil for anything this demuxer does not read, and the caller then falls
    /// back to ffprobe.
    static func probe(path: String) -> VideoInfo? {
        var info = H264Info()
        guard h264_decoder_probe_info(path, &info) == 0,
              info.width > 0, info.height > 0 else { return nil }
        return VideoInfo(width: Int(info.width), height: Int(info.height),
                         fps: info.fps, duration: info.duration)
    }

    /// Whether the narrow path will take this file. Reads the index and the
    /// parameter sets only — no decoding, no device open.
    static func canDecode(path: String) -> Bool {
        guard VaapiDevice.node() != nil else { return false }
        return h264_decoder_supported(path) == 1
    }

    let startPosition: Double
    private let handle: OpaquePointer

    // Teardown is refcounted explicitly rather than left to deinit:
    // `Thread(block:)` keeps its block alive after the thread has exited, so
    // the reader's captured source is never released and deinit never runs.
    // Left that way, every finished playback run kept its VA-API context —
    // measured at 16 open fds on the render node and 21 live Mesa driver
    // threads after a few minutes of looping, climbing steadily.
    private let lock = NSLock()
    private var outstanding = 0
    private var stopped = false
    private var closed = false

    init?(path: String, start: Double) {
        guard let node = VaapiDevice.node() else { return nil }
        startPosition = max(0, start)
        guard let h = h264_decoder_open(path, node, startPosition) else {
            return nil
        }
        handle = h
    }

    /// Blocks until the next frame is decoded. Nil at end of stream or after
    /// stop(). The caller MUST hand the token back through `release` once the
    /// GPU is done with it — that is also what lets the decoder close.
    func next() -> HwFrame? {
        var f = H264Frame()
        guard h264_decoder_next(handle, &f) == 1, let token = f.token else {
            return nil
        }
        lock.lock()
        outstanding += 1
        lock.unlock()
        return HwFrame(
            fd: f.fd, width: Int32(f.width), height: Int32(f.height),
            modifier: f.modifier,
            offset0: f.offset0, pitch0: f.pitch0,
            offset1: f.offset1, pitch1: f.pitch1,
            position: f.position, token: UInt(bitPattern: token))
    }

    func release(_ token: UInt) {
        lock.lock()
        if !closed {
            h264_decoder_release(handle, UnsafeMutableRawPointer(bitPattern: token))
            outstanding -= 1
        }
        let finish = stopped && outstanding == 0 && !closed
        if finish { closed = true }
        lock.unlock()
        if finish { h264_decoder_close(handle) }
    }

    /// Unblocks a reader parked in `next` and closes as soon as the last
    /// handed-out frame comes back. Closing right here would free surfaces the
    /// compositor still has bound — which is the whole reason the count
    /// exists. A paused run legitimately keeps one frame on screen, and with
    /// it one decoder, until playback moves on.
    func stop() {
        h264_decoder_abort(handle)
        lock.lock()
        stopped = true
        let finish = outstanding == 0 && !closed
        if finish { closed = true }
        lock.unlock()
        if finish { h264_decoder_close(handle) }
    }
}

#endif
