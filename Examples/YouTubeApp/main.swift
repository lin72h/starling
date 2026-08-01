// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// YouTube — search and watch, as a FlutterSwift app. yt-dlp finds videos and
// resolves their stream URLs, GStreamer decodes, and every frame is drawn as
// a Skia image by a CustomPaint — in-process software video, no platform
// texture. Needs yt-dlp plus the GStreamer good/libav plugin sets installed.
//
//   swift run -c release YouTubeApp

#if os(Linux)
import CGtk3
import CupertinoIcons
import ExampleHost
import Flutter
import FlutterSwiftBridge
import Foundation
import Observation

// File-scope so the C timeout callback below can reach it without a capture.
let youTubeBloc = YouTubeBloc()

// MARK: - Layout and palette

private enum Style {
    static let accent = Color(0xFF007AFF)
    static let body = Color(0xDD000000)
    static let dim = Color(0x8A000000)
    static let faint = Color(0x61000000)
    static let chrome = Color(0xFFF5F5F5)
    static let stripe = Color(0x05000000)
    static let error = Color(0xFFC62828)

    static let windowWidth = 960.0
    static let windowHeight = 640.0
    static let contentPadding = 16.0
    /// The seek bar spans the padded window; taps map dx to a fraction
    /// through this constant (the window is fixed-size in this demo).
    static let seekBarWidth = windowWidth - 2 * contentPadding
    static let thumbWidth = 128.0
    static let thumbHeight = 72.0
    static let resultRowHeight = 88.0
}

// MARK: - Painters

/// The video surface: black letterbox bars, frame scaled to fit.
private class FramePainter: CustomPainter {
    let image: Image?
    let imageWidth: Double
    let imageHeight: Double

    init(image: Image?, width: Int, height: Int) {
        self.image = image
        self.imageWidth = Double(width)
        self.imageHeight = Double(height)
        super.init()
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        paint.color = Color(0xFF000000)
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint)
        guard let image, imageWidth > 0, imageHeight > 0 else { return }
        let scale = Swift.min(size.width / imageWidth, size.height / imageHeight)
        let w = imageWidth * scale
        let h = imageHeight * scale
        canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, imageWidth, imageHeight),
            Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
            paint
        )
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return true  // a new frame arrives ~30× a second while playing
    }
}

/// A result thumbnail: gray placeholder until the fetch lands.
private class ThumbnailPainter: CustomPainter {
    let image: Image?

    init(image: Image?) {
        self.image = image
        super.init()
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        if let image {
            canvas.drawImageRect(
                image,
                Rect.fromLTWH(0, 0, Double(image.width), Double(image.height)),
                Rect.fromLTWH(0, 0, size.width, size.height),
                paint
            )
        } else {
            paint.color = Color(0x14000000)
            canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint)
        }
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? ThumbnailPainter else { return true }
        return old.image !== image
    }
}

/// The seek bar: track, elapsed fill, thumb dot.
private class SeekBarPainter: CustomPainter {
    let fraction: Double

    init(fraction: Double) {
        self.fraction = fraction
        super.init()
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        let trackY = size.height / 2 - 2
        paint.color = Color(0x1F000000)
        canvas.drawRect(Rect.fromLTWH(0, trackY, size.width, 4), paint)
        let fill = size.width * fraction.clamped(to: 0...1)
        paint.color = Style.accent
        canvas.drawRect(Rect.fromLTWH(0, trackY, fill, 4), paint)
        canvas.drawCircle(Offset(fill, size.height / 2), 6, paint)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? SeekBarPainter else { return true }
        return old.fraction != fraction
    }
}

// MARK: - Page

class YouTubePage: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _YouTubePageState()
    }
}

class _YouTubePageState: State<StatefulWidget> {
    private let _searchController = TextEditingController()

    override func build(_ context: any BuildContext) -> Widget {
        return withObservationTracking {
            _buildContent()
        } onChange: { [weak self] in
            guard let self, self.mounted else { return }
            self.setState {}
        }
    }

    private func _buildContent() -> Widget {
        let s = youTubeBloc.state
        switch s.screen {
        case .browse:
            return MacosScaffold(
                children: [_buildBrowse(s)],
                toolBar: MacosToolBar(title: Text("YouTube"))
            )
        case .watch:
            return MacosScaffold(
                children: [_buildWatch(s)],
                toolBar: MacosToolBar(
                    title: Text(s.nowPlaying?.title ?? "", style: TextStyle(
                        color: Style.body, fontSize: 13, fontWeight: .w600), maxLines: 1),
                    leading: MacosBackButton(onPressed: { youTubeBloc.add(.back) })
                )
            )
        }
    }

    // MARK: Browse

    private func _buildBrowse(_ s: YouTubeAppState) -> Widget {
        return Padding(padding: EdgeInsets(all: Style.contentPadding)) {
            Column(crossAxisAlignment: .stretch) {
                Row {
                    Expanded {
                        MacosTextField(
                            controller: _searchController,
                            placeholder: "Search YouTube",
                            onSubmitted: { text in youTubeBloc.add(.search(text)) }
                        )
                    }
                    SizedBox(width: 8, height: 1)
                    PushButton(
                        child: Text(s.searching ? "Searching…" : "Search"),
                        onPressed: s.searching ? nil : { [weak self] in
                            guard let self else { return }
                            youTubeBloc.add(.search(self._searchController.text))
                        }
                    )
                }
                SizedBox(width: 1, height: 10)
                if let message = s.errorMessage {
                    Padding(padding: EdgeInsets(vertical: 4)) {
                        Text(message, style: TextStyle(color: Style.error, fontSize: 12))
                    }
                }
                if s.results.isEmpty && !s.searching && s.errorMessage == nil {
                    Padding(padding: EdgeInsets(vertical: 4)) {
                        Text("Type a search and press Enter.",
                             style: TextStyle(color: Style.faint, fontSize: 12))
                    }
                }
                Expanded {
                    ListView(
                        itemExtent: Style.resultRowHeight,
                        itemCount: s.results.count,
                        itemBuilder: { [weak self] _, index in self?._buildResultRow(s, index) }
                    )
                }
            }
        }
    }

    private func _buildResultRow(_ s: YouTubeAppState, _ index: Int) -> Widget? {
        guard index < s.results.count else { return nil }
        let video = s.results[index]
        return GestureDetector(
            onTap: { youTubeBloc.add(.open(video)) },
            behavior: .opaque,
            child: ColoredBox(color: index % 2 == 1 ? Style.stripe : Color(0x00000000)) {
                Padding(padding: EdgeInsets(vertical: 8)) {
                    Row(crossAxisAlignment: .center) {
                        SizedBox(width: Style.thumbWidth, height: Style.thumbHeight) {
                            CustomPaint(painter: ThumbnailPainter(image: s.thumbnails[video.id]))
                        }
                        SizedBox(width: 12, height: 1)
                        Expanded {
                            Column(mainAxisAlignment: .center, crossAxisAlignment: .start) {
                                Text(video.title, style: TextStyle(
                                    color: Style.body, fontSize: 13, fontWeight: .w600),
                                    maxLines: 2)
                                SizedBox(width: 1, height: 4)
                                Text("\(video.channel) · \(video.durationLabel)",
                                     style: TextStyle(color: Style.dim, fontSize: 11),
                                     maxLines: 1)
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: Watch

    private func _watchStatusLine(_ s: YouTubeAppState) -> Widget? {
        switch s.playerStatus {
        case .loading:
            return Text("Loading stream…", style: TextStyle(
                color: Color(0xFFFFFFFF), fontSize: 13))
        case .failed(let message):
            return Text(message, style: TextStyle(
                color: Color(0xFFFF8A80), fontSize: 13), maxLines: 3)
        case .ended:
            return Text("Playback finished", style: TextStyle(
                color: Color(0xFFFFFFFF), fontSize: 13))
        default:
            return nil
        }
    }

    private func _formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func _buildWatch(_ s: YouTubeAppState) -> Widget {
        let fraction = s.duration > 0 ? s.position / s.duration : 0
        let pauseLabel: String
        switch s.playerStatus {
        case .playing: pauseLabel = "Pause"
        case .ended: pauseLabel = "Replay"
        default: pauseLabel = "Play"
        }

        return Column(crossAxisAlignment: .stretch) {
            Expanded {
                // .expand: a bare CustomPaint prefers zero size under the
                // Stack's default loose fit, and the video vanishes.
                Stack(alignment: Alignment.center, fit: .expand) {
                    CustomPaint(painter: FramePainter(
                        image: s.frame, width: s.frameWidth, height: s.frameHeight))
                    if let status = _watchStatusLine(s) { Center(child: status) }
                }
            }
            ColoredBox(color: Style.chrome) {
                Padding(padding: EdgeInsets(
                    horizontal: Style.contentPadding, vertical: 8)) {
                    Column(crossAxisAlignment: .stretch) {
                        GestureDetector(
                            onTapUp: { details in
                                youTubeBloc.add(.seek(
                                    fraction: details.localPosition.dx / Style.seekBarWidth))
                            },
                            behavior: .opaque,
                            child: SizedBox(width: 1, height: 20) {
                                CustomPaint(painter: SeekBarPainter(fraction: fraction))
                            }
                        )
                        SizedBox(width: 1, height: 6)
                        Row {
                            PushButton(
                                child: Text(pauseLabel),
                                onPressed: { youTubeBloc.add(.togglePause) }
                            )
                            SizedBox(width: 12, height: 1)
                            Text("\(_formatTime(s.position)) / \(_formatTime(s.duration))",
                                 style: TextStyle(color: Style.dim, fontSize: 12))
                            Expanded { SizedBox(width: 1, height: 1) }
                            if let video = s.nowPlaying {
                                Text(video.channel, style: TextStyle(
                                    color: Style.faint, fontSize: 11), maxLines: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Run

// The 30 ms heartbeat: pumps decoded frames out of the appsink, drains the
// GStreamer bus, and refreshes position — all on the GTK main loop, the
// thread the framework runs the UI on.
_ = g_timeout_add(30, { _ in
    youTubeBloc.add(.tick)
    return 1  // G_SOURCE_CONTINUE
}, nil)

runExampleApp(
    title: "YouTube",
    width: Int(Style.windowWidth), height: Int(Style.windowHeight)
) {
    MacosApp(
        theme: MacosThemeData(brightness: .light),
        home: YouTubePage(),
        title: "YouTube"
    )
}

#else
fatalError("The example apps currently target Linux desktop sessions.")
#endif
