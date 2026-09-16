// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0
import Flutter
import FlutterSwiftBridge
import Foundation
import StarlingRegistry

// MARK: - Flathub: the storefront's second source

/// One app as Flathub's search/collection service describes it. Turned into
/// an `AppRecord` (kind `.flatpak`) so the store's rows, install cluster and
/// install/remove plumbing work on it unchanged — the store never special-
/// cases Flathub apps in its UI, only in where they come from.
struct FlathubApp: Sendable {
    let appId: String
    let name: String
    let summary: String
    let developer: String
    let iconURL: String?
    let category: String
    let verified: Bool
    let installsLastMonth: Int

    /// Flathub's main-category slugs, as the store's category labels.
    static let categoryNames: [String: String] = [
        "audiovideo": "Audio & Video", "audio": "Audio", "video": "Video",
        "development": "Development", "education": "Education",
        "game": "Games", "graphics": "Graphics", "network": "Internet",
        "office": "Office", "science": "Science", "settings": "Settings",
        "system": "System", "utility": "Utilities",
    ]

    var installsLabel: String {
        if installsLastMonth >= 1000 { return "\(installsLastMonth / 1000)k installs/mo" }
        if installsLastMonth > 0 { return "\(installsLastMonth) installs/mo" }
        return "Flathub"
    }

    func record() -> AppRecord {
        AppRecord(
            id: "flatpak-\(appId)", name: name, kind: .flatpak, order: 0,
            glyph: "externalApp", color: 0x5E5E6B, dockOrder: nil,
            category: category, publisher: verified ? "\(developer) ✓" : developer,
            subtitle: summary, sizeLabel: installsLabel, details: "",
            exec: appId, windowRect: nil,
            installRecipe: nil, bins: [], desktopEntries: [appId],
            wmClasses: [appId], titleMatches: [], renameWindows: false,
            debURL: nil, debMarker: nil, desktopFile: nil, iconPath: nil,
            version: nil, installedAt: nil,
            installed: AppRegistry.isFlatpakInstalled(appId), appIds: [appId])
    }

    static func parse(_ any: Any) -> FlathubApp? {
        guard let h = any as? [String: Any],
              let appId = h["app_id"] as? String, !appId.isEmpty,
              let name = h["name"] as? String, !name.isEmpty else { return nil }
        let cat = (h["main_categories"] as? String)?.lowercased() ?? ""
        let verified: Bool = {
            if let b = h["verification_verified"] as? Bool { return b }
            if let s = h["verification_verified"] as? String { return s.lowercased() == "true" }
            return false
        }()
        let installs: Int = {
            if let i = h["installs_last_month"] as? Int { return i }
            if let s = h["installs_last_month"] as? String { return Int(s) ?? 0 }
            return 0
        }()
        return FlathubApp(
            appId: appId, name: name,
            summary: (h["summary"] as? String) ?? "",
            developer: (h["developer_name"] as? String) ?? "",
            iconURL: h["icon"] as? String,
            category: categoryNames[cat] ?? (cat.isEmpty ? "Apps" : cat.capitalized),
            verified: verified, installsLastMonth: installs)
    }
}

/// Talks to flathub.org's public service through curl — a shell-out rather
/// than a networking runtime library, so the staged tree needs nothing new —
/// and keeps a decoded icon per app for the tiles. Results arrive on the main
/// queue, the store's existing convention for install progress.
final class FlathubClient: @unchecked Sendable {
    static let shared = FlathubClient()
    private let queue = DispatchQueue(label: "flathub", qos: .userInitiated)
    private static let base = "https://flathub.org/api/v2"

    /// Decoded icons by app id, main-thread only. `onIconsChanged` fires
    /// after each arrival so the store repaints its tiles.
    private(set) var icons: [String: Image] = [:]
    private var iconRequested: Set<String> = []
    var onIconsChanged: (() -> Void)?

    private var cacheDir: String {
        let env = ProcessInfo.processInfo.environment
        let base = env["XDG_CACHE_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (NSHomeDirectory() + "/.cache")
        let dir = base + "/starling/flathub"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Queries

    func search(_ query: String,
                completion: @escaping @Sendable ([FlathubApp]?, String?) -> Void) {
        let body: [String: Any] = ["query": query, "filters": [] as [Any]]
        guard let json = try? JSONSerialization.data(withJSONObject: body),
              let jsonText = String(data: json, encoding: .utf8) else {
            completion(nil, "bad query"); return
        }
        fetchHits(args: ["-X", "POST", "-H", "Content-Type: application/json",
                         "-d", jsonText, Self.base + "/search"],
                  completion: completion)
    }

    /// "popular", "trending", "recently-added", "recently-updated".
    func collection(_ name: String,
                    completion: @escaping @Sendable ([FlathubApp]?, String?) -> Void) {
        fetchHits(args: [Self.base + "/collection/" + name], completion: completion)
    }

    private func fetchHits(args: [String],
                           completion: @escaping @Sendable ([FlathubApp]?, String?) -> Void) {
        queue.async {
            let (data, status) = Self.curl(args)
            let post: @Sendable ([FlathubApp]?, String?) -> Void = { a, e in
                DispatchQueue.main.async { completion(a, e) }
            }
            guard status == 0, let data else {
                post(nil, "Flathub is unreachable"); return
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data),
                  let dict = obj as? [String: Any],
                  let hits = dict["hits"] as? [Any] else {
                post(nil, "Flathub sent an unexpected answer"); return
            }
            post(hits.compactMap(FlathubApp.parse), nil)
        }
    }

    // MARK: Icons

    /// Fetch and decode an app's icon once: from a local file (an installed
    /// Flatpak's exported icon) or from Flathub's media host, cached on disk.
    func loadIcon(appId: String, url: String?, localPath: String?) {
        guard icons[appId] == nil, !iconRequested.contains(appId) else { return }
        guard url != nil || localPath != nil else { return }
        iconRequested.insert(appId)
        let cacheFile = cacheDir + "/" + appId + ".png"
        queue.async {
            var data: Data? = nil
            if let p = localPath, let d = try? Data(contentsOf: URL(fileURLWithPath: p)) {
                data = d
            } else if let d = try? Data(contentsOf: URL(fileURLWithPath: cacheFile)), !d.isEmpty {
                data = d
            } else if let url {
                let (_, status) = Self.curl(["-o", cacheFile, url])
                if status == 0, let d = try? Data(contentsOf: URL(fileURLWithPath: cacheFile)),
                   !d.isEmpty {
                    data = d
                }
            }
            guard let bytes = data else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let codec = try await FlutterSwiftBridge.instantiateImageCodec([UInt8](bytes))
                    let frame = try await codec.getNextFrame()
                    codec.dispose()
                    self.icons[appId] = frame.image
                    self.onIconsChanged?()
                } catch {
                    // An undecodable icon (SVG behind a .png name) just keeps
                    // the glyph tile.
                }
            }
        }
    }

    // MARK: curl

    /// Runs curl synchronously (call on `queue`). Returns stdout and the exit
    /// status; a non-zero status means no answer, not a bad one.
    private static func curl(_ args: [String]) -> (Data?, Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        p.arguments = ["-sSL", "--max-time", "20", "-A", "starling-app-store"] + args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (nil, 127) }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (data, p.terminationStatus)
    }
}

/// Paints a decoded icon into a tile.
final class FlathubIconPainter: CustomPainter {
    let image: Image
    init(_ image: Image) { self.image = image }
    override func paint(_ canvas: any Canvas, _ size: Size) {
        let paint = Paint()
        paint.filterQuality = .medium
        canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, Double(image.width), Double(image.height)),
            Rect.fromLTWH(0, 0, size.width, size.height),
            paint)
    }
    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        (oldDelegate as? FlathubIconPainter)?.image !== image
    }
}
