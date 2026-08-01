// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - VideoPlayerWidget

class VideoPlayerWidget: StatefulWidget {
    let path: String

    init(path: String) {
        self.path = path
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return _VideoPlayerState()
    }
}

// Playback is a reader thread per run: ffmpeg (spawned by PipeDecoder,
// realtime-paced) writes RGBA frames down a pipe, the reader blocks on
// whole frames and hands each to the main thread for texture upload. Pause,
// seek-to-start and file switches all work the same way — bump `generation`
// and kill the decoder; stale hops check the generation and evaporate. At
// most two frames are in flight (the semaphore), so a busy main thread
// backpressures ffmpeg through the pipe instead of ballooning memory.
class _VideoPlayerState: State<StatefulWidget> {
    private var textureId: Int64 = -1
    private var hasTexture = false
    private var info = VideoInfo()
    private var position: Double = 0
    private var isPlaying = false
    private var frameCount = 0
    private var currentPath = ""
    private var showOpenPanel = false
    private var decoder: PipeDecoder? = nil
    private var generation = 0

    private static let kVideoExtensions = [
        "mp4", "mkv", "avi", "mov", "webm", "m4v", "mpg", "mpeg", "ts",
        "wmv", "flv", "ogv"]

    private var w: VideoPlayerWidget {
        widget as! VideoPlayerWidget
    }

    override func initState() {
        super.initState()

        #if os(Linux)
        if let rendererState = gpuDmaBufRendererState {
            textureId = rendererState.registerExternalTexture()
            hasTexture = true
        }
        #endif

        if !w.path.isEmpty {
            _openVideo(w.path)
        }
    }

    override func dispose() {
        generation += 1
        let dec = decoder
        decoder = nil
        DispatchQueue.global(qos: .utility).async { dec?.stop() }
        #if os(Linux)
        if hasTexture, let rendererState = gpuDmaBufRendererState {
            rendererState.unregisterExternalTexture(textureId)
        }
        #endif
        super.dispose()
    }

    /// (Re)opens a video: tears down any current run, keeps the registered
    /// texture, probes the file, and starts playing from the beginning.
    private func _openVideo(_ path: String) {
        _stopRun()
        guard let probed = PipeDecoder.probe(path: path),
              probed.width > 0, probed.height > 0 else {
            setState {
                currentPath = ""
                info = VideoInfo()
                frameCount = 0
            }
            return
        }
        setState {
            currentPath = path
            info = probed
            position = 0
            frameCount = 0
        }
        _startPlayback(from: 0)
    }

    /// Kill the current decode run; stale reader hops die on `generation`.
    private func _stopRun() {
        generation += 1
        isPlaying = false
        let dec = decoder
        decoder = nil
        DispatchQueue.global(qos: .utility).async { dec?.stop() }
    }

    private func _startPlayback(from start: Double) {
        guard !currentPath.isEmpty, info.width > 0, hasTexture else { return }
        generation += 1
        let gen = generation
        guard let dec = PipeDecoder(path: currentPath, start: start,
                                    info: info) else { return }
        decoder = dec
        isPlaying = true

        let vw = info.width, vh = info.height
        let fps = info.fps
        let texId = textureId
        let inFlight = DispatchSemaphore(value: 2)

        // The state class is not Sendable; the reader reaches back through
        // main-queue hops that only touch it after the generation check —
        // the same unsafeBitCast coercion the shell uses for its timers.
        let readerBody: () -> Void = { [weak self] in
            var framesRead = 0
            while true {
                var frame = [UInt8](repeating: 0, count: vw * vh * 4)
                guard dec.readFrame(into: &frame) else { break }
                framesRead += 1
                let pos = dec.startPosition + Double(framesRead) / fps
                inFlight.wait()
                let deliver: () -> Void = { [weak self] in
                    defer { inFlight.signal() }
                    guard let self, self.generation == gen else { return }
                    #if os(Linux)
                    gpuDmaBufRendererState?.updateExternalTexturePixels(
                        texId, pixels: frame, width: Int32(vw), height: Int32(vh))
                    #endif
                    self.setState {
                        self.frameCount += 1
                        self.position = pos
                    }
                }
                DispatchQueue.main.async(
                    execute: unsafeBitCast(deliver, to: (@Sendable () -> Void).self))
            }
            // EOF (a stop bumps the generation first, so this really is the
            // end of the file): loop from the top, like the old player.
            let loop: () -> Void = { [weak self] in
                guard let self, self.generation == gen, self.isPlaying
                else { return }
                self._startPlayback(from: 0)
            }
            DispatchQueue.main.async(
                execute: unsafeBitCast(loop, to: (@Sendable () -> Void).self))
        }
        let reader = Thread(
            block: unsafeBitCast(readerBody, to: (@Sendable () -> Void).self))
        reader.name = "video-reader"
        reader.start()
    }

    private func _togglePlay() {
        if isPlaying {
            setState { _stopRun() }
        } else {
            // Resume near the end restarts — matching the loop behaviour.
            let from = position >= info.duration - 0.3 ? 0 : position
            setState { _startPlayback(from: from) }
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        var children: [Widget] = []

        if hasTexture && frameCount > 0 {
            // Decoded frames are top-row-first; the engine samples external GL
            // textures as kBottomLeft, so counter with a Y-flip (same as the
            // shell's flipTextureY for Wayland surfaces).
            children.append(
                Positioned(
                    fill: (),
                    child: Transform(
                        transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
                        alignment: Alignment.center,
                        child: TextureWidget(textureId: Int(textureId))
                    )
                )
            )
        } else {
            children.append(
                Positioned(
                    fill: (),
                    child: ColoredBox(
                        color: Color(0xFF000000),
                        child: Center(
                            child: Text(
                                !currentPath.isEmpty ? "Loading..."
                                    : "No video \u{2014} click Open\u{2026}",
                                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18)
                            )
                        )
                    )
                )
            )
        }

        // Controls
        children.append(
            Positioned(
                left: 0, right: 0, bottom: 0,
                height: 36,
                child: ColoredBox(
                    color: Color(rgbo: 0, 0, 0, 0.5),
                    child: Padding(
                        padding: EdgeInsets(left: 12, right: 12),
                        child: Row(
                            crossAxisAlignment: .center,
                            children: [
                                GestureDetector(
                                    onTap: { [self] in _togglePlay() },
                                    behavior: .opaque,
                                    child: Text(
                                        isPlaying ? "  II  " : "  >  ",
                                        style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16)
                                    )
                                ),
                                SizedBox(width: 8),
                                Text(
                                    _formatTime(position) + " / " + _formatTime(info.duration),
                                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)
                                ),
                                Expanded(child: SizedBox(width: 1)),
                                GestureDetector(
                                    onTap: { [self] in
                                        setState { showOpenPanel = true }
                                    },
                                    behavior: .opaque,
                                    child: Text(
                                        "  Open\u{2026}  ",
                                        style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 13)
                                    )
                                ),
                            ]
                        )
                    )
                )
            )
        )

        // Shared system open dialog, filtered to video types.
        if showOpenPanel {
            var opts = MacosFilePanelOptions()
            opts.mode = .open
            opts.title = "Open Video"
            opts.appearanceDark = true   // the player chrome is always dark
            opts.allowedExtensions = Self.kVideoExtensions
            opts.initialDirectory = currentPath.isEmpty
                ? nil
                : (currentPath as NSString).deletingLastPathComponent
            children.append(Positioned(
                fill: (),
                child: MacosFilePanelOverlay(options: opts) { [self] paths in
                    setState { showOpenPanel = false }
                    if let path = paths.first {
                        _openVideo(path)
                    }
                }
            ))
        }

        return Stack(fit: .expand, children: children)
    }

    private func _formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
