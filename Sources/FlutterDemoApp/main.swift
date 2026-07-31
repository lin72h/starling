// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The FlutterSwift demo, hosted the way a real Flutter Linux app is hosted:
// the engine's GTK embedder (FlView in a GtkWindow) with the engine running
// in Swift mode. Works on an ordinary desktop session — GNOME Wayland, KDE,
// X11 — with the embedder providing window management, input, and IME.
//
//   swift run -c release FlutterDemoApp
//
// Engine data resolves the standard Flutter bundle way: <executable dir>/
// data/{icudtl.dat,flutter_assets}. Running from a build tree, the bootstrap
// below links that up from the sibling engine checkout on first run.

#if os(Linux)
import Flutter
import FlutterGTK
import Foundation
import Glibc

setbuf(stdout, nil)

/// Dev bootstrap: when `<exe dir>/data` is missing (a `swift run` from the
/// repo rather than an installed bundle), assemble it as symlinks — icudtl
/// from the engine checkout ($FLUTTER_SWIFT_ENGINE_OUT / $FLUTTER_ENGINE_OUT
/// / sibling clone), flutter_assets from this package's Resources.
func ensureEngineData() {
    let fm = FileManager.default
    guard let exe = try? fm.destinationOfSymbolicLink(atPath: "/proc/self/exe") else { return }
    let dataDir = (exe as NSString).deletingLastPathComponent + "/data"
    if fm.fileExists(atPath: dataDir + "/icudtl.dat") { return }

    let env = ProcessInfo.processInfo.environment
    var icuCandidates: [String] = []
    for key in ["FLUTTER_SWIFT_ENGINE_OUT", "FLUTTER_ENGINE_OUT"] {
        if let v = env[key], !v.isEmpty { icuCandidates.append(v + "/icudtl.dat") }
    }
    let packageDir = URL(fileURLWithPath: #filePath)         // …/Sources/FlutterDemoApp/main.swift
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    icuCandidates += [
        packageDir + "/engine/share/icudtl.dat",
        packageDir + "/../starling-engine/engine/src/out/host_debug/icudtl.dat",
    ]
    guard let icu = icuCandidates.first(where: { fm.fileExists(atPath: $0) }) else {
        FileHandle.standardError.write(Data((
            "[FlutterDemoApp] no data/ next to the executable and no engine " +
            "checkout to link from — tried " + icuCandidates.joined(separator: ", ") + "\n").utf8))
        return
    }
    try? fm.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
    try? fm.createSymbolicLink(atPath: dataDir + "/icudtl.dat", withDestinationPath: icu)
    let assets = packageDir + "/Resources/flutter_assets"
    if fm.fileExists(atPath: assets) {
        try? fm.createSymbolicLink(atPath: dataDir + "/flutter_assets", withDestinationPath: assets)
    }
    print("[FlutterDemoApp] Linked engine data into \(dataDir)")
}

print("[FlutterDemoApp] Starting (GTK host)")
ensureEngineData()

guard let host = GTKHost(width: 800, height: 600, title: "FlutterSwift Demo") else {
    fatalError("""
    [FlutterDemoApp] Could not create a window — run inside a Wayland or X11 \
    session (WAYLAND_DISPLAY/DISPLAY set).
    """)
}

host.mountWidget {
    Directionality(textDirection: .ltr, child: FlutterDemoApp())
}
host.run()

#else
fatalError("This demo currently targets Linux; see the Starling desktop for the macOS host.")
#endif
