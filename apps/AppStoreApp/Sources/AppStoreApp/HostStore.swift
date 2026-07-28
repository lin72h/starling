// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StarlingRegistry

// MARK: - Catalog model

/// Install lifecycle of a catalog entry.
enum InstallState: Sendable {
    case notInstalled
    case installing(progress: Double?, status: String)  // nil progress = indeterminate
    case installed
    /// `removal` says which operation failed, so Retry retries that one. Without
    /// it a failed *uninstall* offers a button that reinstalls the app you were
    /// trying to get rid of.
    case failed(String, removal: Bool)
}

/// How a catalog entry installs.
enum InstallBackend {
    /// Host install through `pkexec app-install <id>` — apt/dpkg only, no
    /// snap (user direction). `bins` are absolute path candidates whose
    /// existence means "installed" (vendor debs and archive packages land
    /// in different places).
    case host(bins: [String])
    /// Sealed-image model (Starling OS only): official .deb extracted into
    /// the installed-apps layer over the read-only runtime. `marker` is the
    /// launchable path relative to the install root.
    case deb(url: String, marker: String)
}

/// True on the sealed Starling image (ID=starling in /etc/os-release —
/// same check as app-run.sh). There the store uses the deb-extract layer;
/// on a stock distro everything installs onto the host via apt.
let kOnStarlingImage: Bool = {
    guard let s = try? String(contentsOfFile: "/etc/os-release") else {
        return false
    }
    return s.split(separator: "\n").contains { $0 == "ID=starling" }
}()

extension AppRecord {

    /// Everything the store shows comes from the app registry — the same
    /// records the shell's launcher and dock read, so the two cannot disagree
    /// about what exists or what is installed. See registry/catalog.d.
    static var storeCatalog: [AppRecord] {
        // What this store can actually install: first-party apps ship with
        // the desktop and WeChat is a host install, so neither belongs here.
        AppRegistry.shared.apps.filter {
            $0.installRecipe != nil || $0.debURL != nil
        }
    }

    /// How this app installs on this machine. On the sealed image there is no
    /// apt, so a catalog entry that names an official .deb is extracted into
    /// the installed-apps layer instead.
    var backend: InstallBackend {
        if kOnStarlingImage, let url = debURL, let marker = debMarker {
            return .deb(url: url, marker: marker)
        }
        return .host(bins: bins)
    }
}

// MARK: - HostStore

/// Installs apps onto the HOST through `app-install` (apt/dpkg recipes —
/// vendor repos, vendor debs, the Ubuntu archive; never snap). Elevation is
/// pkexec: the packaged polkit policy allows the active session's user to
/// run app-install without a prompt, so the store's Install button behaves
/// like a store, not like a sudo tutorial. apt's output lines stream into
/// the tile's status text.
final class HostStore: @unchecked Sendable {

    static let shared = HostStore()

    /// Serializes installs; process I/O runs on a background thread.
    private let queue = DispatchQueue(label: "hoststore")

    private var appInstall: String {
        ProcessInfo.processInfo.environment["STARLING_APP_INSTALL"]
            ?? "/usr/bin/app-install"
    }

    func isInstalled(bins: [String]) -> Bool {
        bins.contains { FileManager.default.fileExists(atPath: $0) }
    }

    func install(_ id: String, onUpdate: @escaping @Sendable (InstallState) -> Void) {
        run(["pkexec", appInstall, id],
            initial: "Installing…",
            failureNoun: "Install",
            removal: false,
            done: .installed,
            onUpdate: onUpdate)
    }

    func remove(_ id: String, onUpdate: @escaping @Sendable (InstallState) -> Void) {
        run(["pkexec", appInstall, "--remove", id],
            initial: "Removing…",
            failureNoun: "Remove",
            removal: true,
            done: .notInstalled,
            onUpdate: onUpdate)
    }

    /// The store's Open button: launch through the same registry the dock
    /// uses. Fire-and-forget — the shell composites the window when it maps.
    func launch(_ id: String) {
        let appRun = ProcessInfo.processInfo.environment["STARLING_APP_RUN"]
            ?? "/usr/bin/app-run"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: appRun)
        p.arguments = [id]
        try? p.run()
    }

    private func run(_ argv: [String], initial: String, failureNoun: String,
                     removal: Bool,
                     done: InstallState,
                     onUpdate: @escaping @Sendable (InstallState) -> Void) {
        queue.async {
            let post: @Sendable (InstallState) -> Void = { state in
                DispatchQueue.main.async { onUpdate(state) }
            }
            post(.installing(progress: nil, status: initial))

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = argv
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            var lastErr = ""

            // Stream stdout lines into the status text (apt's progress).
            out.fileHandleForReading.readabilityHandler = { h in
                let chunk = String(data: h.availableData, encoding: .utf8) ?? ""
                let line = chunk.split(separator: "\n").last.map(String.init)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if !line.isEmpty {
                    post(.installing(progress: nil, status: String(line.prefix(48))))
                }
            }
            do {
                try p.run()
            } catch {
                post(.failed("\(failureNoun) failed to start: \(error)", removal: removal))
                return
            }
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            out.fileHandleForReading.readabilityHandler = nil
            lastErr = String(data: errData, encoding: .utf8) ?? ""

            if p.terminationStatus == 0 {
                post(done)
            } else if p.terminationStatus == 126 || p.terminationStatus == 127 {
                // pkexec's own exits: 126 = dismissed/not authorized,
                // 127 = authorization failure.
                post(.failed("Not authorized (polkit)", removal: removal))
            } else {
                let msg = lastErr.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: "\n").last.map(String.init) ?? ""
                post(.failed(msg.isEmpty
                    ? "\(failureNoun) failed (exit \(p.terminationStatus))" : msg,
                    removal: removal))
            }
        }
    }
}
