// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// YouTube — search and watch, as a FlutterSwift app, styled after the real
// thing: the persistent white header with logo and search pill, the search
// results page (wide rounded thumbnails, view counts, duration badges), and
// the watch page (player with the red seek bar overlaid, channel row with a
// Subscribe chip, an Up-next column that plays on click). yt-dlp finds
// videos and resolves streams, GStreamer decodes, and every frame is drawn
// as a Skia image by a CustomPaint — in-process software video.
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

// MARK: - Palette and layout

private enum YT {
    // YouTube's palette.
    static let red = Color(0xFFFF0000)
    static let ink = Color(0xFF0F0F0F)          // primary text
    static let gray = Color(0xFF606060)         // secondary text
    static let border = Color(0xFFE5E5E5)
    static let chipInk = Color(0xFF0F0F0F)      // Subscribe pill
    static let white = Color(0xFFFFFFFF)

    static let windowWidth = 960.0
    static let windowHeight = 640.0
    static let headerHeight = 56.0

    // Search results page.
    static let resultThumbWidth = 240.0
    static let resultThumbHeight = 135.0
    static let resultRowHeight = 151.0          // thumb + vertical padding

    // Watch page.
    static let pagePadding = 16.0
    static let playerWidth = 620.0
    static let playerHeight = 349.0             // 16:9
    static let upNextThumbWidth = 112.0
    static let upNextThumbHeight = 63.0
    static let upNextRowHeight = 79.0
}

// MARK: - Painters

/// The YouTube mark: red rounded rect with a white play triangle.
private class LogoPainter: CustomPainter {
    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        paint.color = YT.red
        canvas.drawRRect(RRect(
            fromRectAndRadius: Rect.fromLTWH(0, 0, size.width, size.height),
            Radius(circular: size.height * 0.28)), paint)
        paint.color = YT.white
        let path = Path()
        path.moveTo(size.width * 0.40, size.height * 0.30)
        path.lineTo(size.width * 0.40, size.height * 0.70)
        path.lineTo(size.width * 0.72, size.height * 0.50)
        path.close()
        canvas.drawPath(path, paint)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool { false }
}

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

/// A rounded-corner thumbnail: gray placeholder until the fetch lands.
private class ThumbnailPainter: CustomPainter {
    let image: Image?
    let cornerRadius: Double

    init(image: Image?, cornerRadius: Double = 12) {
        self.image = image
        self.cornerRadius = cornerRadius
        super.init()
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        let bounds = Rect.fromLTWH(0, 0, size.width, size.height)
        canvas.save()
        canvas.clipRRect(RRect(fromRectAndRadius: bounds, Radius(circular: cornerRadius)))
        if let image {
            canvas.drawImageRect(
                image,
                Rect.fromLTWH(0, 0, Double(image.width), Double(image.height)),
                bounds, paint)
        } else {
            paint.color = Color(0xFFE5E5E5)
            canvas.drawRect(bounds, paint)
        }
        canvas.restore()
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? ThumbnailPainter else { return true }
        return old.image !== image
    }
}

/// The player's seek bar, YouTube-red on a translucent track.
private class SeekBarPainter: CustomPainter {
    let fraction: Double

    init(fraction: Double) {
        self.fraction = fraction
        super.init()
    }

    override func paint(_ canvas: Canvas, _ size: Size) {
        let paint = Paint()
        let trackY = size.height / 2 - 1.5
        paint.color = Color(0x59FFFFFF)
        canvas.drawRect(Rect.fromLTWH(0, trackY, size.width, 3), paint)
        let fill = size.width * fraction.clamped(to: 0...1)
        paint.color = YT.red
        canvas.drawRect(Rect.fromLTWH(0, trackY, fill, 3), paint)
        canvas.drawCircle(Offset(fill, size.height / 2), 5.5, paint)
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
        return ColoredBox(color: YT.white) {
            Column(crossAxisAlignment: .stretch) {
                _buildHeader(s)
                SizedBox(width: 1, height: 1) {
                    DecoratedBox(decoration: BoxDecoration(color: YT.border))
                }
                Expanded {
                    switch s.screen {
                    case .browse: _buildBrowse(s)
                    case .watch: _buildWatch(s)
                    }
                }
            }
        }
    }

    // MARK: Header

    private func _buildHeader(_ s: YouTubeAppState) -> Widget {
        return SizedBox(width: 1, height: YT.headerHeight) {
            Padding(padding: EdgeInsets(horizontal: 16)) {
                Row {
                    // Logo — click to go home.
                    GestureDetector(
                        onTap: { youTubeBloc.add(.back) },
                        behavior: .opaque,
                        child: Row(mainAxisSize: .min, children: [
                            SizedBox(width: 30, height: 21,
                                     child: CustomPaint(painter: LogoPainter())),
                            SizedBox(width: 5, height: 1),
                            Text("YouTube", style: TextStyle(
                                color: YT.ink, fontSize: 17, fontWeight: .w700)),
                        ])
                    )
                    Expanded { SizedBox(width: 1, height: 1) }
                    // Search pill.
                    SizedBox(width: 380, height: 30) {
                        MacosTextField(
                            controller: _searchController,
                            placeholder: "Search",
                            onSubmitted: { text in youTubeBloc.add(.search(text)) }
                        )
                    }
                    GestureDetector(
                        onTap: { [weak self] in
                            guard let self else { return }
                            youTubeBloc.add(.search(self._searchController.text))
                        },
                        behavior: .opaque,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Color(0xFFF2F2F2),
                                border: Border.all(color: YT.border),
                                borderRadius: BorderRadius.all(Radius(circular: 4))
                            )
                        ) {
                            SizedBox(width: 54, height: 30) {
                                Center(child: Icon(
                                    CupertinoIcons.search, size: 15, color: YT.gray))
                            }
                        }
                    )
                    Expanded { SizedBox(width: 1, height: 1) }
                    // Avatar.
                    SizedBox(width: 30, height: 30) {
                        DecoratedBox(
                            decoration: BoxDecoration(
                                color: Color(0xFF7C4DFF), shape: .circle)
                        ) {
                            Center(child: Text("S", style: TextStyle(
                                color: YT.white, fontSize: 14, fontWeight: .w600)))
                        }
                    }
                }
            }
        }
    }

    // MARK: Thumbnails

    private func _thumbnail(
        _ s: YouTubeAppState, _ video: VideoResult,
        width: Double, height: Double, cornerRadius: Double
    ) -> Widget {
        return SizedBox(width: width, height: height) {
            Stack(fit: .expand) {
                CustomPaint(painter: ThumbnailPainter(
                    image: s.thumbnails[video.id], cornerRadius: cornerRadius))
                Positioned(
                    right: 6, bottom: 6,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Color(0xE6000000),
                            borderRadius: BorderRadius.all(Radius(circular: 4))
                        ),
                        child: Padding(
                            padding: EdgeInsets(horizontal: 5, vertical: 2),
                            child: Text(video.durationLabel, style: TextStyle(
                                color: YT.white, fontSize: 11, fontWeight: .w600))
                        )
                    )
                )
            }
        }
    }

    // MARK: Search results

    private func _buildBrowse(_ s: YouTubeAppState) -> Widget {
        if s.searching {
            return Center(child: Text("Searching…", style: TextStyle(
                color: YT.gray, fontSize: 14)))
        }
        if let message = s.errorMessage {
            return Center(child: Text(message, style: TextStyle(
                color: YT.red, fontSize: 13), maxLines: 3))
        }
        if s.results.isEmpty {
            return Center(child: Text("Search YouTube to get started",
                                      style: TextStyle(color: YT.gray, fontSize: 14)))
        }
        return ListView(
            padding: EdgeInsets(horizontal: 24, vertical: 8),
            itemExtent: YT.resultRowHeight,
            itemCount: s.results.count,
            itemBuilder: { [weak self] _, index in self?._buildResultRow(s, index) }
        )
    }

    private func _buildResultRow(_ s: YouTubeAppState, _ index: Int) -> Widget? {
        guard index < s.results.count else { return nil }
        let video = s.results[index]
        return GestureDetector(
            onTap: { youTubeBloc.add(.open(video)) },
            behavior: .opaque,
            child: Padding(padding: EdgeInsets(vertical: 8)) {
                Row(crossAxisAlignment: .start) {
                    _thumbnail(s, video,
                               width: YT.resultThumbWidth,
                               height: YT.resultThumbHeight,
                               cornerRadius: 12)
                    SizedBox(width: 16, height: 1)
                    Expanded {
                        Column(crossAxisAlignment: .start) {
                            SizedBox(width: 1, height: 2)
                            Text(video.title, style: TextStyle(
                                color: YT.ink, fontSize: 15, fontWeight: .w600),
                                maxLines: 2)
                            SizedBox(width: 1, height: 6)
                            if let views = video.viewsLabel {
                                Text(views, style: TextStyle(
                                    color: YT.gray, fontSize: 12), maxLines: 1)
                            }
                            SizedBox(width: 1, height: 14)
                            Row(mainAxisSize: .min) {
                                SizedBox(width: 22, height: 22) {
                                    DecoratedBox(decoration: BoxDecoration(
                                        color: Color(0xFFBDBDBD), shape: .circle)) {
                                        Center(child: Text(
                                            String(video.channel.prefix(1)),
                                            style: TextStyle(
                                                color: YT.white, fontSize: 11)))
                                    }
                                }
                                SizedBox(width: 8, height: 1)
                                Text(video.channel, style: TextStyle(
                                    color: YT.gray, fontSize: 12), maxLines: 1)
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
                color: YT.white, fontSize: 13))
        case .failed(let message):
            return Text(message, style: TextStyle(
                color: Color(0xFFFF8A80), fontSize: 13), maxLines: 3)
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

    private func _buildPlayer(_ s: YouTubeAppState) -> Widget {
        let fraction = s.duration > 0 ? s.position / s.duration : 0
        let playGlyph = s.playerStatus == .playing
            ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill

        return SizedBox(width: YT.playerWidth, height: YT.playerHeight) {
            Stack(fit: .expand) {
                GestureDetector(
                    onTap: { youTubeBloc.add(.togglePause) },
                    behavior: .opaque,
                    child: CustomPaint(painter: FramePainter(
                        image: s.frame, width: s.frameWidth, height: s.frameHeight))
                )
                if let status = _watchStatusLine(s) { Center(child: status) }
                Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x66000000)),
                        child: Column(mainAxisSize: .min, children: [
                            GestureDetector(
                                onTapUp: { details in
                                    youTubeBloc.add(.seek(
                                        fraction: details.localPosition.dx / YT.playerWidth))
                                },
                                behavior: .opaque,
                                child: SizedBox(
                                    width: YT.playerWidth, height: 14,
                                    child: CustomPaint(
                                        painter: SeekBarPainter(fraction: fraction)))
                            ),
                            Padding(
                                padding: EdgeInsets(
                                    left: 10, top: 2, right: 10, bottom: 6),
                                child: Row(children: [
                                    GestureDetector(
                                        onTap: { youTubeBloc.add(.togglePause) },
                                        behavior: .opaque,
                                        child: Icon(playGlyph, size: 17, color: YT.white)
                                    ),
                                    SizedBox(width: 12, height: 1),
                                    Text(
                                        "\(_formatTime(s.position)) / \(_formatTime(s.duration))",
                                        style: TextStyle(color: YT.white, fontSize: 12)),
                                    Expanded(child: SizedBox(width: 1, height: 1)),
                                ])
                            ),
                        ])
                    )
                )
            }
        }
    }

    private func _buildWatch(_ s: YouTubeAppState) -> Widget {
        guard let video = s.nowPlaying else {
            return Center(child: Text("Nothing playing", style: TextStyle(
                color: YT.gray, fontSize: 13)))
        }
        return Padding(padding: EdgeInsets(all: YT.pagePadding)) {
            Row(crossAxisAlignment: .start) {
                // Width-only: a stray height constraint here would squash the
                // subtree's hit-test bounds while the paint overflows — the
                // player looks fine but takes no clicks.
                SizedBox(width: YT.playerWidth) {
                    Column(crossAxisAlignment: .start) {
                        _buildPlayer(s)
                        SizedBox(width: 1, height: 12)
                        Text(video.title, style: TextStyle(
                            color: YT.ink, fontSize: 16, fontWeight: .w600), maxLines: 2)
                        SizedBox(width: 1, height: 6)
                        if let views = video.viewsLabel {
                            Text(views, style: TextStyle(color: YT.gray, fontSize: 13))
                        }
                        SizedBox(width: 1, height: 14)
                        Row {
                            SizedBox(width: 36, height: 36) {
                                DecoratedBox(decoration: BoxDecoration(
                                    color: Color(0xFF00897B), shape: .circle)) {
                                    Center(child: Text(
                                        String(video.channel.prefix(1)),
                                        style: TextStyle(color: YT.white,
                                                         fontSize: 16, fontWeight: .w600)))
                                }
                            }
                            SizedBox(width: 10, height: 1)
                            Expanded {
                                Text(video.channel, style: TextStyle(
                                    color: YT.ink, fontSize: 13, fontWeight: .w600),
                                    maxLines: 1)
                            }
                            DecoratedBox(
                                decoration: BoxDecoration(
                                    color: YT.chipInk,
                                    borderRadius: BorderRadius.all(Radius(circular: 16))
                                )
                            ) {
                                Padding(padding: EdgeInsets(horizontal: 14, vertical: 7)) {
                                    Text("Subscribe", style: TextStyle(
                                        color: YT.white, fontSize: 12, fontWeight: .w600))
                                }
                            }
                        }
                    }
                }
                SizedBox(width: 16, height: 1)
                Expanded {
                    Column(crossAxisAlignment: .stretch) {
                        Text("Up next", style: TextStyle(
                            color: YT.ink, fontSize: 14, fontWeight: .w600))
                        SizedBox(width: 1, height: 8)
                        Expanded {
                            ListView(
                                itemExtent: YT.upNextRowHeight,
                                itemCount: s.results.count,
                                itemBuilder: { [weak self] _, index in
                                    self?._buildUpNextRow(s, index)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func _buildUpNextRow(_ s: YouTubeAppState, _ index: Int) -> Widget? {
        guard index < s.results.count else { return nil }
        let video = s.results[index]
        return GestureDetector(
            onTap: { youTubeBloc.add(.open(video)) },
            behavior: .opaque,
            child: Padding(padding: EdgeInsets(vertical: 8)) {
                Row(crossAxisAlignment: .start) {
                    _thumbnail(s, video,
                               width: YT.upNextThumbWidth,
                               height: YT.upNextThumbHeight,
                               cornerRadius: 8)
                    SizedBox(width: 8, height: 1)
                    Expanded {
                        Column(crossAxisAlignment: .start) {
                            Text(video.title, style: TextStyle(
                                color: YT.ink, fontSize: 12, fontWeight: .w600),
                                maxLines: 2)
                            SizedBox(width: 1, height: 4)
                            Text(video.channel, style: TextStyle(
                                color: YT.gray, fontSize: 11), maxLines: 1)
                        }
                    }
                }
            }
        )
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
    width: Int(YT.windowWidth), height: Int(YT.windowHeight)
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
