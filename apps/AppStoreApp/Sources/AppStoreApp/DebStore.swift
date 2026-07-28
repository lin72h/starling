// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - Shared process runner

struct ToolResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

/// Run a tool from PATH, capturing output. Reads before waitUntilExit so a
/// full pipe can't deadlock the child.
func runTool(_ argv: [String]) -> ToolResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = argv
    let outPipe = Pipe(), errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe
    do {
        try process.run()
    } catch {
        return ToolResult(status: -1, stdout: "", stderr: "\(error)")
    }
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ToolResult(
        status: process.terminationStatus,
        stdout: String(data: outData, encoding: .utf8) ?? "",
        stderr: String(data: errData, encoding: .utf8) ?? "")
}

// MARK: - DebStore

/// Installs Google Chrome from Google's official .deb — the one browser the
/// snap store can't provide (Google publishes no Chrome snap). The package
/// is downloaded to /tmp, then extracted (dpkg-deb -x, no maintainer
/// scripts — Chrome's postinst only registers Google's apt repo and cron,
/// neither of which applies here) into the writable installed-apps layer.
/// app-run.sh bind-mounts the extracted /opt/google over the read-only app
/// runtime at launch, so the sealed runtime image never changes.
final class DebStore: @unchecked Sendable {

    static let shared = DebStore()

    /// Serializes installs; downloads/extraction run on a background thread.
    private let queue = DispatchQueue(label: "debstore")

    private func installRoot(_ id: String) -> String {
        (ProcessInfo.processInfo.environment["STARLING_APP_INSTALLED"]
            ?? "/var/lib/starling-apps/installed") + "/" + id
    }

    func isInstalled(_ id: String, marker: String) -> Bool {
        FileManager.default.fileExists(atPath: installRoot(id) + "/" + marker)
    }

    func install(_ id: String, url: String, marker: String,
                 onUpdate: @escaping @Sendable (InstallState) -> Void) {
        queue.async { [self] in
            let post = { (state: InstallState) in
                DispatchQueue.main.async { onUpdate(state) }
            }
            post(.installing(progress: nil, status: "Contacting Google…"))

            // Total size for the progress fraction (best-effort; the
            // download still works with an indeterminate bar without it).
            var total: Double = 0
            let head = runTool(["curl", "-sIL", url])
            if head.status == 0 {
                for line in head.stdout.components(separatedBy: "\n")
                where line.lowercased().hasPrefix("content-length:") {
                    let value = line.dropFirst("content-length:".count)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    total = Double(value) ?? total
                }
            }

            let tmp = "/tmp/appstore-\(id).deb"
            try? FileManager.default.removeItem(atPath: tmp)

            // Download without waiting; poll the file size for progress —
            // same shape as SnapStore's snapd change polling.
            let dl = Process()
            dl.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            dl.arguments = ["curl", "-sL", "--fail", "-o", tmp, url]
            do {
                try dl.run()
            } catch {
                post(.failed("curl failed to start: \(error)", removal: false))
                return
            }
            while dl.isRunning {
                Thread.sleep(forTimeInterval: 0.4)
                let attrs = try? FileManager.default.attributesOfItem(atPath: tmp)
                let done = Double(attrs?[.size] as? Int ?? 0)
                let fraction = total > 0 ? min(done / total, 1.0) : nil
                post(.installing(progress: fraction, status: "Downloading…"))
            }
            guard dl.terminationStatus == 0 else {
                try? FileManager.default.removeItem(atPath: tmp)
                post(.failed("Download failed (curl exit \(dl.terminationStatus))", removal: false))
                return
            }

            post(.installing(progress: 1.0, status: "Installing…"))
            let root = installRoot(id)
            try? FileManager.default.createDirectory(
                atPath: root, withIntermediateDirectories: true)
            let extract = runTool(["dpkg-deb", "-x", tmp, root])
            try? FileManager.default.removeItem(atPath: tmp)
            guard extract.status == 0 else {
                let msg = extract.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                post(.failed(msg.isEmpty ? "dpkg-deb extract failed" : msg, removal: false))
                return
            }
            guard isInstalled(id, marker: marker) else {
                post(.failed("Package layout unexpected — missing \(marker)", removal: false))
                return
            }
            post(.installed)
        }
    }

    func remove(_ id: String, onUpdate: @escaping @Sendable (InstallState) -> Void) {
        queue.async { [self] in
            DispatchQueue.main.async {
                onUpdate(.installing(progress: nil, status: "Removing…"))
            }
            try? FileManager.default.removeItem(atPath: installRoot(id))
            let gone = !FileManager.default.fileExists(atPath: installRoot(id))
            DispatchQueue.main.async {
                onUpdate(gone ? .notInstalled : .failed("Could not remove", removal: true))
            }
        }
    }
}
