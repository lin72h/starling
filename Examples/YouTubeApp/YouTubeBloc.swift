// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The app's BLoC, in the house shape (see CLAUDE.md): one value-type state
// struct, one event enum, an @Observable bloc whose add(_:) is the only way
// the UI mutates anything. Blocking work (yt-dlp, thumbnail fetches) runs on
// background queues and re-enters through MainThread.run + add(_:); the
// 30 ms UI timer dispatches .tick, which pumps the player.

#if os(Linux)
import Dispatch
import Foundation
import FlutterSwiftBridge
import Observation

enum YouTubeScreen {
    case browse, watch
}

/// The single source of truth for the UI.
struct YouTubeAppState {
    // Browse
    var searching = false
    var results: [VideoResult] = []
    /// Decoded thumbnails by video id, filled in as fetches land.
    var thumbnails: [String: Image] = [:]
    var errorMessage: String? = nil

    // Watch
    var screen: YouTubeScreen = .browse
    var nowPlaying: VideoResult? = nil
    var playerStatus: VideoPlayer.Status = .idle
    var frame: Image? = nil
    var frameWidth = 0
    var frameHeight = 0
    var position: Double = 0
    var duration: Double = 0
}

@Observable
final class YouTubeBloc: @unchecked Sendable {

    /// The events the UI dispatches.
    enum Event {
        case search(String)
        case searchCompleted(Result<[VideoResult], ServiceFailure>)
        case thumbnailLoaded(id: String, image: Image)
        case open(VideoResult)
        case streamResolved(id: String, Result<String, ServiceFailure>)
        case togglePause
        case seek(fraction: Double)
        case back
        /// The 30 ms heartbeat: pump frames, bus messages, position.
        case tick
    }

    private(set) var state = YouTubeAppState()

    @ObservationIgnored private let player = VideoPlayer()
    /// One frame conversion in flight at a time — the pipeline drops what
    /// the display can't keep up with (appsink drop=true).
    @ObservationIgnored private var convertingFrame = false
    /// The frame most recently replaced. Kept alive one generation so the
    /// engine is done rastering it, then disposed.
    @ObservationIgnored private var retiredFrame: Image? = nil
    /// Thumbnails of the previous search, disposed when the next completes.
    @ObservationIgnored private var retiredThumbnails: [Image] = []

    /// The only way the UI talks to the BLoC.
    func add(_ event: Event) {
        switch event {
        case .search(let query):
            _search(query)
        case .searchCompleted(let result):
            _searchCompleted(result)
        case .thumbnailLoaded(let id, let image):
            // Ignore stragglers from an outdated search.
            if state.results.contains(where: { $0.id == id }) {
                state.thumbnails[id] = image
            } else {
                image.dispose()
            }
        case .open(let video):
            _open(video)
        case .streamResolved(let id, let result):
            _streamResolved(id: id, result)
        case .togglePause:
            player.togglePause()
            state.playerStatus = player.status
        case .seek(let fraction):
            player.seek(toFraction: fraction)
            if state.duration > 0 { state.position = fraction * state.duration }
        case .back:
            player.stop()
            _disposeFrames()
            state.screen = .browse
            state.nowPlaying = nil
            state.playerStatus = .idle
            state.position = 0
            state.duration = 0
        case .tick:
            _tick()
        }
    }

    // MARK: - Search

    private func _search(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, !state.searching else { return }
        state.searching = true
        state.errorMessage = nil
        DispatchQueue.global().async {
            let result = YouTubeService.search(query)
            MainThread.run { [weak self] in self?.add(.searchCompleted(result)) }
        }
    }

    private func _searchCompleted(_ result: Result<[VideoResult], ServiceFailure>) {
        state.searching = false
        for image in retiredThumbnails { image.dispose() }
        retiredThumbnails = []
        switch result {
        case .failure(let failure):
            state.errorMessage = failure.message
        case .success(let results):
            retiredThumbnails = Array(state.thumbnails.values)
            state.thumbnails = [:]
            state.results = results
            for video in results {
                DispatchQueue.global().async {
                    guard let data = YouTubeService.fetch(video.thumbnailURL) else { return }
                    Task {
                        guard let image = await VideoPlayer.decodeImage(data) else { return }
                        MainThread.run { [weak self] in
                            self?.add(.thumbnailLoaded(id: video.id, image: image))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playback

    private func _open(_ video: VideoResult) {
        player.stop()
        _disposeFrames()
        state.screen = .watch
        state.nowPlaying = video
        state.playerStatus = .loading
        state.position = 0
        state.duration = 0
        DispatchQueue.global().async {
            let result = YouTubeService.streamURL(videoId: video.id)
            MainThread.run { [weak self] in
                self?.add(.streamResolved(id: video.id, result))
            }
        }
    }

    private func _streamResolved(id: String, _ result: Result<String, ServiceFailure>) {
        // The user may have backed out or opened something else meanwhile.
        guard state.screen == .watch, state.nowPlaying?.id == id else { return }
        switch result {
        case .failure(let failure):
            state.playerStatus = .failed(failure.message)
        case .success(let url):
            player.open(url: url)
            state.playerStatus = player.status
        }
    }

    private func _tick() {
        guard state.screen == .watch else { return }

        if player.status != state.playerStatus {
            state.playerStatus = player.status
        }

        if !convertingFrame, let frame = player.poll() {
            convertingFrame = true
            Task {
                let image = await VideoPlayer.makeImage(frame)
                MainThread.run { [weak self] in
                    guard let self else { return }
                    self.convertingFrame = false
                    guard let image else { return }
                    if self.state.screen == .watch {
                        self.retiredFrame?.dispose()
                        self.retiredFrame = self.state.frame
                        self.state.frame = image
                        self.state.frameWidth = frame.width
                        self.state.frameHeight = frame.height
                    } else {
                        image.dispose()
                    }
                }
            }
        }

        // Position updates are visible at whole-second granularity; a
        // quarter-second threshold keeps rebuilds off the frame path.
        let duration = player.duration
        if abs(duration - state.duration) > 0.25 { state.duration = duration }
        let position = player.position
        if abs(position - state.position) > 0.25 { state.position = position }
    }

    private func _disposeFrames() {
        retiredFrame?.dispose()
        retiredFrame = nil
        state.frame?.dispose()
        state.frame = nil
        state.frameWidth = 0
        state.frameHeight = 0
    }
}
#endif
