// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// GStreamer playback, pull-model: playbin decodes (audio to the session's
// sink, video through videoconvert into an RGBA appsink with sync=true), and
// the UI's frame timer polls poll() — appsink releases each sample at its
// presentation time, so pulling with a zero timeout naturally paces display
// without a single GStreamer callback or extra thread touching Swift.

#if os(Linux)
import CGStreamer
import Foundation
import FlutterSwiftBridge

/// A decoded RGBA frame, straight out of the pipeline.
struct VideoFrame {
    let pixels: [UInt8]
    let width: Int
    let height: Int
}

final class VideoPlayer {

    enum Status: Equatable {
        case idle, loading, playing, paused, ended
        case failed(String)
    }

    private(set) var status: Status = .idle

    private var playbin: UnsafeMutablePointer<GstElement>? = nil
    private var appsink: UnsafeMutablePointer<GstAppSink>? = nil
    private var bus: UnsafeMutablePointer<GstBus>? = nil

    private static let initialized: Bool = {
        gst_init(nil, nil)
        return true
    }()

    // MARK: - Control

    func open(url: String) {
        stop()
        _ = Self.initialized

        guard let playbin = gst_element_factory_make("playbin", nil) else {
            status = .failed("GStreamer playbin unavailable")
            return
        }
        var error: UnsafeMutablePointer<GError>? = nil
        let description =
            "videoconvert ! videoscale ! appsink name=sink " +
            "caps=video/x-raw,format=RGBA max-buffers=4 drop=true sync=true"
        guard let sinkBin = gst_parse_bin_from_description(description, 1, &error) else {
            status = .failed(error.map { String(cString: $0.pointee.message) } ?? "bad sink bin")
            gst_object_unref(gpointer(playbin))
            return
        }
        cgst_set_object(playbin, "video-sink", sinkBin)
        cgst_set_string(playbin, "uri", url)

        self.playbin = playbin
        self.appsink = cgst_as_appsink(gst_bin_get_by_name(cgst_as_bin(sinkBin), "sink"))
        self.bus = gst_element_get_bus(playbin)

        gst_element_set_state(playbin, GST_STATE_PLAYING)
        status = .loading
    }

    func togglePause() {
        guard let playbin else { return }
        switch status {
        case .playing:
            gst_element_set_state(playbin, GST_STATE_PAUSED)
            status = .paused
        case .paused:
            gst_element_set_state(playbin, GST_STATE_PLAYING)
            status = .playing
        case .ended:
            seek(toFraction: 0)
            gst_element_set_state(playbin, GST_STATE_PLAYING)
            status = .playing
        default:
            break
        }
    }

    func stop() {
        if let playbin {
            gst_element_set_state(playbin, GST_STATE_NULL)
            gst_object_unref(gpointer(playbin))
        }
        if let appsink { gst_object_unref(gpointer(appsink)) }
        if let bus { gst_object_unref(gpointer(bus)) }
        playbin = nil
        appsink = nil
        bus = nil
        status = .idle
    }

    func seek(toFraction fraction: Double) {
        guard let playbin, duration > 0 else { return }
        let target = gint64(fraction.clamped(to: 0...1) * duration * 1_000_000_000)
        gst_element_seek_simple(playbin, GST_FORMAT_TIME, cgst_seek_flags(), target)
        if status == .ended { status = .paused }
    }

    // MARK: - Position

    var position: Double {
        guard let playbin else { return 0 }
        var nanoseconds: gint64 = 0
        guard gst_element_query_position(playbin, GST_FORMAT_TIME, &nanoseconds) != 0
        else { return 0 }
        return Double(nanoseconds) / 1_000_000_000
    }

    var duration: Double {
        guard let playbin else { return 0 }
        var nanoseconds: gint64 = 0
        guard gst_element_query_duration(playbin, GST_FORMAT_TIME, &nanoseconds) != 0
        else { return 0 }
        return Double(nanoseconds) / 1_000_000_000
    }

    // MARK: - Polling

    /// Drains bus messages and returns the frame that is due, if any.
    /// Call from the UI timer.
    func poll() -> VideoFrame? {
        _drainBus()
        guard let appsink,
              let sample = gst_app_sink_try_pull_sample(appsink, 0) else { return nil }
        defer { gst_sample_unref(sample) }

        // First frame means the pipeline is rolling.
        if status == .loading { status = .playing }

        guard let caps = gst_sample_get_caps(sample),
              let structure = gst_caps_get_structure(caps, 0),
              let buffer = gst_sample_get_buffer(sample) else { return nil }
        var width: gint = 0
        var height: gint = 0
        gst_structure_get_int(structure, "width", &width)
        gst_structure_get_int(structure, "height", &height)
        guard width > 0, height > 0 else { return nil }

        var map = GstMapInfo()
        guard gst_buffer_map(buffer, &map, GST_MAP_READ) != 0 else { return nil }
        defer { gst_buffer_unmap(buffer, &map) }
        let pixels = [UInt8](UnsafeBufferPointer(start: map.data, count: Int(map.size)))
        return VideoFrame(pixels: pixels, width: Int(width), height: Int(height))
    }

    private func _drainBus() {
        guard let bus else { return }
        let interesting = GstMessageType(
            rawValue: GST_MESSAGE_ERROR.rawValue | GST_MESSAGE_EOS.rawValue)
        while let message = gst_bus_pop_filtered(bus, interesting) {
            switch message.pointee.type {
            case GST_MESSAGE_EOS:
                status = .ended
            case GST_MESSAGE_ERROR:
                var gError: UnsafeMutablePointer<GError>? = nil
                var debug: UnsafeMutablePointer<gchar>? = nil
                gst_message_parse_error(message, &gError, &debug)
                let text = gError.map { String(cString: $0.pointee.message) } ?? "playback error"
                if let gError { g_error_free(gError) }
                if let debug { g_free(debug) }
                status = .failed(text)
            default:
                break
            }
            gst_message_unref(message)
        }
    }

    // MARK: - Frame → Skia

    /// Builds a Skia image from a raw RGBA frame. The caller owns the
    /// returned handle and must dispose() it when it leaves the screen.
    static func makeImage(_ frame: VideoFrame) async -> Image? {
        let buffer = ImmutableBuffer(fromUint8List: frame.pixels)
        let descriptor = ImageDescriptorFactory.raw(
            buffer, width: frame.width, height: frame.height, pixelFormat: .rgba8888)
        guard let codec = try? await descriptor.instantiateCodec(
            targetWidth: nil, targetHeight: nil) else { return nil }
        defer { codec.dispose() }
        return try? await codec.getNextFrame().image
    }

    /// Decodes an encoded image (JPEG/PNG thumbnail) into a Skia image.
    static func decodeImage(_ data: Data) async -> Image? {
        let buffer = ImmutableBuffer(fromUint8List: [UInt8](data))
        guard let descriptor = try? await ImageDescriptorFactory.encoded(buffer)
        else { return nil }
        guard let codec = try? await descriptor.instantiateCodec(
            targetWidth: nil, targetHeight: nil) else { return nil }
        defer { codec.dispose() }
        return try? await codec.getNextFrame().image
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
#endif
