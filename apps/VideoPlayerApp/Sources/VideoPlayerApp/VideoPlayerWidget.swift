// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import CupertinoIcons
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
    /// Non-nil while the scrubber is being dragged: the position the thumb
    /// shows, distinct from playback position until the drag commits.
    private var scrubPosition: Double? = nil
    /// The scrubber's laid-out width, from MeasureSize — drag x → seconds.
    private var scrubberW: Double = 0

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

    /// Jump to `target`. Playing: restart the stream there. Paused: decode
    /// exactly one frame there so the scrubber shows where it landed, then
    /// stop again.
    private func _seek(to target: Double) {
        let t = min(max(0, target), max(0, info.duration - 0.5))
        let wasPlaying = isPlaying
        _stopRun()
        setState { position = t }
        _startPlayback(from: t, pauseOnFirstFrame: !wasPlaying)
    }

    private func _startPlayback(from start: Double,
                                pauseOnFirstFrame: Bool = false) {
        guard !currentPath.isEmpty, info.width > 0, hasTexture else { return }
        generation += 1
        let gen = generation
        guard let dec = PipeDecoder(path: currentPath, start: start,
                                    info: info) else { return }
        decoder = dec
        isPlaying = !pauseOnFirstFrame

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
                let thisFrame = framesRead  // by value — deliver runs later
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
                    // A paused seek wants exactly this one frame on screen;
                    // stopping bumps the generation, so the reader's later
                    // hops (and its EOF loop) all evaporate.
                    if pauseOnFirstFrame && thisFrame == 1 {
                        self._stopRun()
                        self.setState { self.position = pos }
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

        // Controls — the QuickTime shape: dark translucent bar, filled
        // play/pause glyph, monospace-ish times flanking the scrubber.
        children.append(
            Positioned(
                left: 0, right: 0, bottom: 0,
                height: 44,
                child: ColoredBox(
                    color: Color(rgbo: 22, 22, 24, 0.72),
                    child: Padding(
                        padding: EdgeInsets(left: 14, right: 14),
                        child: Row(
                            crossAxisAlignment: .center,
                            children: [
                                GestureDetector(
                                    onTap: { [self] in _togglePlay() },
                                    behavior: .opaque,
                                    child: Padding(
                                        padding: EdgeInsets(left: 2, top: 8, right: 10, bottom: 8),
                                        child: MacosIcon(
                                            icon: isPlaying
                                                ? CupertinoIcons.pause_fill
                                                : CupertinoIcons.play_fill,
                                            color: Color(0xFFFFFFFF),
                                            size: 16
                                        )
                                    )
                                ),
                                Text(
                                    _formatTime(scrubPosition ?? position),
                                    style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 12)
                                ),
                                SizedBox(width: 10),
                                Expanded(child: _scrubber()),
                                SizedBox(width: 10),
                                Text(
                                    _formatTime(info.duration),
                                    style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 12)
                                ),
                                SizedBox(width: 6),
                                GestureDetector(
                                    onTap: { [self] in
                                        setState { showOpenPanel = true }
                                    },
                                    behavior: .opaque,
                                    child: Padding(
                                        padding: EdgeInsets(all: 6),
                                        child: Text(
                                            "Open\u{2026}",
                                            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 12)
                                        )
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

    // MARK: - Scrubber

    /// macOS-style scrubber: thin rounded track, filled to the playhead, a
    /// round thumb. Click jumps; drag shows the target (scrubPosition) and
    /// seeks on release — one decoder respawn per gesture, not per pixel.
    /// MacosSlider in the framework is display-only, so this is hand-built
    /// on the drag callbacks; the width comes from MeasureSize.
    private func _scrubber() -> Widget {
        let dur = max(info.duration, 0.001)
        let fraction = min(max((scrubPosition ?? position) / dur, 0), 1)
        let thumbD = 12.0
        let trackH = 4.0
        let rowH = 44.0
        let usable = max(scrubberW - thumbD, 1)
        let thumbX = usable * fraction

        func target(_ x: Double) -> Double {
            guard scrubberW > thumbD else { return position }
            return min(max((x - thumbD / 2) / usable, 0), 1) * dur
        }

        return GestureDetector(
            onTapUp: { [self] d in
                guard info.duration > 0 else { return }
                _seek(to: target(d.localPosition.dx))
            },
            onHorizontalDragStart: { [self] d in
                guard info.duration > 0 else { return }
                setState { scrubPosition = target(d.localPosition.dx) }
            },
            onHorizontalDragUpdate: { [self] d in
                guard scrubPosition != nil else { return }
                setState { scrubPosition = target(d.localPosition.dx) }
            },
            onHorizontalDragEnd: { [self] _ in
                guard let t = scrubPosition else { return }
                setState { scrubPosition = nil }
                _seek(to: t)
            },
            behavior: .opaque,
            child: MeasureSize(
                onSize: { [weak self] size in
                    self?._recordScrubberWidth(size.width)
                },
                child: SizedBox(
                    height: rowH,
                    child: Stack(children: [
                        Positioned(
                            left: 0, top: (rowH - trackH) / 2, right: 0,
                            height: trackH,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Color(rgbo: 255, 255, 255, 0.25),
                                    borderRadius: BorderRadius.circular(trackH / 2)
                                )
                            )
                        ),
                        Positioned(
                            left: 0, top: (rowH - trackH) / 2,
                            width: max(thumbX + thumbD / 2, trackH),
                            height: trackH,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Color(rgbo: 255, 255, 255, 0.9),
                                    borderRadius: BorderRadius.circular(trackH / 2)
                                )
                            )
                        ),
                        Positioned(
                            left: thumbX, top: (rowH - thumbD) / 2,
                            width: thumbD, height: thumbD,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Color(0xFFFFFFFF),
                                    borderRadius: BorderRadius.circular(thumbD / 2),
                                    boxShadow: [BoxShadow(
                                        color: Color(rgbo: 0, 0, 0, 0.35),
                                        offset: Offset(0, 1),
                                        blurRadius: 2
                                    )]
                                )
                            )
                        ),
                    ])
                )
            )
        )
    }

    /// Fires from MeasureSize during layout — bounce to the main queue
    /// before touching state (the codebase-wide MeasureSize rule).
    private func _recordScrubberWidth(_ w: Double) {
        if abs(w - scrubberW) < 0.5 { return }
        let update: () -> Void = { [weak self] in
            guard let self else { return }
            self.setState { self.scrubberW = w }
        }
        DispatchQueue.main.async(
            execute: unsafeBitCast(update, to: (@Sendable () -> Void).self))
    }
}
