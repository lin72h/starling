// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The zero-copy display path: a triple-buffered pool of GBM buffer objects
// (GPU memory, linear RGBA) that decoded frames are written into, presented
// through the GTK host's dma-buf external texture. The raster thread samples
// these buffers directly via EGLImage — after the first import of each
// buffer there is no per-frame GL work and no CPU copy on the display side.
// With a software decoder the one remaining CPU touch is the row copy into
// the buffer here; a hardware (VA-API) decoder producing dma-bufs could skip
// even that by handing its fds straight to `texture.update`.

#if os(Linux)
import DmaBufBridge
import ExampleHost
import FlutterGTK
import Foundation
import Glibc

final class VideoTextureOutput {

    /// GBM_FORMAT_ABGR8888 — RGBA byte order in memory, matching both what
    /// videoconvert produces and what the EGL import expects.
    private static let fourccABGR8888: UInt32 = 0x3432_4241
    /// DRM_FORMAT_MOD_INVALID — the buffers are linear; no explicit modifier.
    private static let modifierInvalid: UInt64 = (1 << 56) - 1

    private struct Buffer {
        let bo: OpaquePointer
        let fd: Int32
    }

    let texture: GTKDmaBufTexture
    private let renderFd: Int32
    private let gbmDevice: OpaquePointer
    private var buffers: [Buffer] = []
    private var cursor = 0
    private(set) var width: Int32 = 0
    private(set) var height: Int32 = 0

    /// Nil when the render node or the engine's texture registrar is
    /// unavailable — callers fall back to the Skia path.
    init?() {
        guard let texture = activeGTKHost?.makeDmaBufTexture() else { return nil }
        let fd = open("/dev/dri/renderD128", O_RDWR)
        guard fd >= 0 else {
            print("[VideoTexture] no render node: \(String(cString: strerror(errno)))")
            return nil
        }
        guard let device = gbm_create_device(fd) else {
            print("[VideoTexture] gbm_create_device failed")
            close(fd)
            return nil
        }
        self.texture = texture
        self.renderFd = fd
        self.gbmDevice = device
    }

    deinit {
        _dropBuffers()
        gbm_device_destroy(gbmDevice)
        close(renderFd)
    }

    private func _dropBuffers() {
        for buffer in buffers {
            close(buffer.fd)
            gbm_bo_destroy(buffer.bo)
        }
        buffers = []
        cursor = 0
    }

    private func _ensureBuffers(width: Int32, height: Int32) -> Bool {
        if width == self.width, height == self.height, !buffers.isEmpty {
            return true
        }
        _dropBuffers()
        // Triple buffering: the compositor may still sample frame N-1 while
        // frame N is being written.
        for _ in 0..<3 {
            let flags = GBM_BO_USE_LINEAR.rawValue | GBM_BO_USE_RENDERING.rawValue
            guard let bo = gbm_bo_create(gbmDevice, UInt32(width), UInt32(height),
                                         Self.fourccABGR8888, flags),
                  case let fd = gbm_bo_get_fd(bo), fd >= 0 else {
                print("[VideoTexture] buffer allocation failed at \(width)×\(height)")
                _dropBuffers()
                return false
            }
            buffers.append(Buffer(bo: bo, fd: fd))
        }
        self.width = width
        self.height = height
        return true
    }

    /// Writes the frame into the next pool buffer and presents it. Returns
    /// false when buffers cannot be allocated (caller should fall back).
    func present(_ frame: VideoFrame) -> Bool {
        guard _ensureBuffers(width: Int32(frame.width), height: Int32(frame.height))
        else { return false }

        let buffer = buffers[cursor]
        cursor = (cursor + 1) % buffers.count

        var mapStride: UInt32 = 0
        var mapData: UnsafeMutableRawPointer? = nil
        guard let mapped = gbm_bo_map(buffer.bo, 0, 0, UInt32(frame.width),
                                      UInt32(frame.height),
                                      GBM_BO_TRANSFER_WRITE.rawValue,
                                      &mapStride, &mapData) else {
            return false
        }
        let rowBytes = frame.width * 4
        frame.pixels.withUnsafeBytes { raw in
            guard let source = raw.baseAddress else { return }
            // Rows go in bottom-up: the engine samples external GL textures
            // with a bottom-left origin (kBottomLeft_GrSurfaceOrigin), so a
            // top-down write shows the video upside down.
            for y in 0..<frame.height {
                memcpy(mapped + (frame.height - 1 - y) * Int(mapStride),
                       source + y * rowBytes, rowBytes)
            }
        }
        gbm_bo_unmap(buffer.bo, mapData)

        let stride = gbm_bo_get_stride(buffer.bo)
        // update() takes ownership of the fd; the pool keeps its own.
        texture.update(
            fd: dup(buffer.fd),
            width: Int32(frame.width), height: Int32(frame.height),
            stride: Int32(stride),
            fourcc: Self.fourccABGR8888,
            modifier: Self.modifierInvalid
        )
        return true
    }
}
#endif
