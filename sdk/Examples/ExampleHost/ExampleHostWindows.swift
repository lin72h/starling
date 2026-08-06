// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The Windows half of the example-app plumbing: the engine-data bootstrap and
// the window-host run sequence. Mirrors ExampleHost.swift, which does the same
// for the GTK host on Linux.

#if os(Windows)
import CupertinoIcons
import Flutter
import FlutterSwiftBridge
import FlutterWin32
import Foundation

/// Dev bootstrap, the counterpart of the Linux one: when `<exe dir>/data` is
/// missing (a `swift build` from the repo rather than an installed bundle),
/// assemble it — icudtl.dat from the engine checkout
/// ($FLUTTER_SWIFT_ENGINE_OUT / $FLUTTER_ENGINE_OUT / sibling clone),
/// flutter_assets from this package's Resources.
///
/// Copies rather than symlinks. Creating a symlink on Windows needs either
/// Developer Mode or SeCreateSymbolicLinkPrivilege, so the Linux spelling of
/// this would fail on an ordinary account — and silently, since the failure
/// only shows up later as the engine not finding its data.
public func ensureEngineData() {
    let fm = FileManager.default
    let exe = ProcessInfo.processInfo.arguments.first.flatMap {
        URL(fileURLWithPath: $0).deletingLastPathComponent().path
    } ?? Bundle.main.bundlePath
    let dataDir = exe + "\\data"
    if fm.fileExists(atPath: dataDir + "\\icudtl.dat") { return }

    let env = ProcessInfo.processInfo.environment
    var icuCandidates: [String] = []
    for key in ["FLUTTER_SWIFT_ENGINE_OUT", "FLUTTER_ENGINE_OUT"] {
        if let v = env[key], !v.isEmpty { icuCandidates.append(v + "/icudtl.dat") }
    }
    let packageDir = URL(fileURLWithPath: #filePath)  // …/Examples/ExampleHost/ExampleHostWindows.swift
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().path
    icuCandidates += [
        packageDir + "/engine/share/icudtl.dat",
        packageDir + "/../starling-engine/engine/src/out/host_debug/icudtl.dat",
    ]
    guard let icu = icuCandidates.first(where: { fm.fileExists(atPath: $0) }) else {
        FileHandle.standardError.write(Data((
            "[ExampleHost] no data/ next to the executable and no engine " +
            "checkout to copy from — tried " +
            icuCandidates.joined(separator: ", ") + "\n").utf8))
        return
    }
    try? fm.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
    try? fm.copyItem(atPath: icu, toPath: dataDir + "\\icudtl.dat")
    let assets = packageDir + "/Resources/flutter_assets"
    if fm.fileExists(atPath: assets) {
        try? fm.copyItem(atPath: assets, toPath: dataDir + "\\flutter_assets")
    }
    print("[ExampleHost] Copied engine data into \(dataDir)")
}

/// The host created by runExampleApp, for apps that need window control
/// beyond mounting a widget.
public private(set) var activeWin32Host: Win32Host? = nil

/// Opens a window (Win32 embedder, engine in Swift mode), mounts the app
/// widget, and runs until the window closes.
public func runExampleApp(
    title: String, width: Int = 480, height: Int = 720, root: () -> Widget
) {
    setbuf(stdout, nil)
    print("[\(title)] Starting (Win32 host)")
    ensureEngineData()
    guard let host = Win32Host(width: width, height: height, title: title) else {
        fatalError("[\(title)] Could not create a window or start the engine.")
    }
    activeWin32Host = host
    host.mountWidget(root)
    host.run()
}
#endif
