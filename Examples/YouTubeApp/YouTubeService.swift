// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The YouTube data layer: searches and stream-URL resolution shell out to
// yt-dlp (which owns the ever-shifting extraction problem), thumbnails come
// straight off i.ytimg.com. Every call here blocks — callers run them on a
// background queue and marshal results back to the UI thread.

#if os(Linux)
import Foundation
import FoundationNetworking

/// What went wrong, in words the UI can show directly.
struct ServiceFailure: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

/// One search hit, as the results list shows it.
struct VideoResult {
    let id: String
    let title: String
    let channel: String
    let duration: Double        // seconds; 0 when unknown (e.g. live)
    let viewCount: Int?

    /// 320×180 thumbnail — mqdefault exists for effectively every video.
    var thumbnailURL: String { "https://i.ytimg.com/vi/\(id)/mqdefault.jpg" }

    var durationLabel: String {
        guard duration > 0 else { return "LIVE" }
        let total = Int(duration)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// "1.2M views", the way YouTube compresses counts.
    var viewsLabel: String? {
        guard let views = viewCount else { return nil }
        let compact: String
        switch views {
        case ..<1_000: compact = "\(views)"
        case ..<1_000_000: compact = String(format: "%.1fK", Double(views) / 1_000)
        case ..<1_000_000_000: compact = String(format: "%.1fM", Double(views) / 1_000_000)
        default: compact = String(format: "%.1fB", Double(views) / 1_000_000_000)
        }
        return "\(compact.replacingOccurrences(of: ".0", with: "")) views"
    }
}

enum YouTubeService {

    /// `ytsearchN:` — one JSON object per line in flat-playlist mode.
    static func search(_ query: String, limit: Int = 12) -> Result<[VideoResult], ServiceFailure> {
        let output = _runYtDlp([
            "ytsearch\(limit):\(query)",
            "--flat-playlist", "--dump-json",
            "--no-warnings", "--socket-timeout", "15",
        ])
        switch output {
        case .failure(let failure):
            return .failure(failure)
        case .success(let text):
            var results: [VideoResult] = []
            for line in text.split(separator: "\n") {
                guard let object = try? JSONSerialization.jsonObject(
                          with: Data(line.utf8)) as? [String: Any],
                      let id = object["id"] as? String else { continue }
                results.append(VideoResult(
                    id: id,
                    title: object["title"] as? String ?? "(untitled)",
                    channel: object["channel"] as? String
                        ?? object["uploader"] as? String ?? "",
                    duration: object["duration"] as? Double ?? 0,
                    viewCount: (object["view_count"] as? NSNumber)?.intValue
                ))
            }
            return results.isEmpty
                ? .failure(ServiceFailure("no results for “\(query)”"))
                : .success(results)
        }
    }

    /// Resolves a watch URL to a directly playable stream URL. Prefers
    /// format 18 (muxed 360p H.264+AAC): one URI carrying both audio and
    /// video keeps the pipeline a single playbin with nothing to sync.
    static func streamURL(videoId: String) -> Result<String, ServiceFailure> {
        let output = _runYtDlp([
            "--no-warnings", "--socket-timeout", "15",
            "-f", "18/best[acodec!=none][vcodec!=none][height<=480]/best[acodec!=none][vcodec!=none]/best",
            "--get-url",
            "https://www.youtube.com/watch?v=\(videoId)",
        ])
        switch output {
        case .failure(let failure):
            return .failure(failure)
        case .success(let text):
            guard let url = text.split(separator: "\n").first, url.hasPrefix("http") else {
                return .failure(ServiceFailure("yt-dlp returned no stream URL"))
            }
            return .success(String(url))
        }
    }

    /// Blocking GET, for thumbnails.
    static func fetch(_ urlString: String) -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var result: Data? = nil
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                result = data
            }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 20)
        return result
    }

    // MARK: - yt-dlp

    private static func _runYtDlp(_ arguments: [String]) -> Result<String, ServiceFailure> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["yt-dlp"] + arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return .failure(ServiceFailure("could not run yt-dlp: \(error)"))
        }
        // Drain before waiting — yt-dlp's output can exceed the pipe buffer.
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errData, as: UTF8.self)
                .split(separator: "\n").last.map(String.init) ?? "yt-dlp failed"
            return .failure(ServiceFailure(message))
        }
        return .success(String(decoding: outData, as: UTF8.self))
    }
}
#endif
