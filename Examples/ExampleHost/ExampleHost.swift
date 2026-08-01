// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Shared plumbing for the example apps ported from famous Flutter samples:
// the engine-data bootstrap and the window-host run sequence, so each port's
// main.swift stays as close as possible to its Dart original's
// `void main() => runApp(MyApp());`.

#if os(Linux)
import CupertinoIcons
import Flutter
import FlutterGTK
import FlutterSwiftBridge
import Foundation
import Glibc

/// Dev bootstrap, same as FlutterDemoApp's: when `<exe dir>/data` is missing
/// (a `swift run` from the repo rather than an installed bundle), assemble it
/// as symlinks — icudtl from the engine checkout ($FLUTTER_SWIFT_ENGINE_OUT /
/// $FLUTTER_ENGINE_OUT / sibling clone), flutter_assets from this package's
/// Resources.
public func ensureEngineData() {
    let fm = FileManager.default
    guard let exe = try? fm.destinationOfSymbolicLink(atPath: "/proc/self/exe") else { return }
    let dataDir = (exe as NSString).deletingLastPathComponent + "/data"
    if fm.fileExists(atPath: dataDir + "/icudtl.dat") { return }

    let env = ProcessInfo.processInfo.environment
    var icuCandidates: [String] = []
    for key in ["FLUTTER_SWIFT_ENGINE_OUT", "FLUTTER_ENGINE_OUT"] {
        if let v = env[key], !v.isEmpty { icuCandidates.append(v + "/icudtl.dat") }
    }
    let packageDir = URL(fileURLWithPath: #filePath)         // …/Examples/ExampleHost/ExampleHost.swift
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    icuCandidates += [
        packageDir + "/engine/share/icudtl.dat",
        packageDir + "/../starling-engine/engine/src/out/host_debug/icudtl.dat",
    ]
    guard let icu = icuCandidates.first(where: { fm.fileExists(atPath: $0) }) else {
        FileHandle.standardError.write(Data((
            "[ExampleHost] no data/ next to the executable and no engine " +
            "checkout to link from — tried " + icuCandidates.joined(separator: ", ") + "\n").utf8))
        return
    }
    try? fm.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
    try? fm.createSymbolicLink(atPath: dataDir + "/icudtl.dat", withDestinationPath: icu)
    let assets = packageDir + "/Resources/flutter_assets"
    if fm.fileExists(atPath: assets) {
        try? fm.createSymbolicLink(atPath: dataDir + "/flutter_assets", withDestinationPath: assets)
    }
    print("[ExampleHost] Linked engine data into \(dataDir)")
}

/// The host created by runExampleApp, for apps that need window control
/// beyond mounting a widget (e.g. the YouTube example's fullscreen toggle).
public private(set) var activeGTKHost: GTKHost? = nil

/// Opens a window on the desktop session (GTK embedder, engine in Swift
/// mode), mounts the app widget, and runs until the window closes.
public func runExampleApp(
    title: String, width: Int = 480, height: Int = 720, root: () -> Widget
) {
    setbuf(stdout, nil)
    print("[\(title)] Starting (GTK host)")
    ensureEngineData()
    guard let host = GTKHost(width: width, height: height, title: title) else {
        fatalError("""
        [\(title)] Could not create a window — run inside a Wayland or X11 \
        session (WAYLAND_DISPLAY/DISPLAY set).
        """)
    }
    activeGTKHost = host
    host.mountWidget(root)
    host.run()
}

// MARK: - Icon

/// The example ports' stand-in for Flutter's material `Icon` widget: a fixed
/// box drawing one glyph from an icon font (CupertinoIcons here — the same
/// approach MacosUI's MacosIcon takes). Registers the font with the engine on
/// first use; widgets first build on the first engine frame, so the engine is
/// live by then.
public class Icon: StatelessWidget {
    public let icon: IconData
    public let size: Double
    public let color: Color

    public init(
        _ icon: IconData, size: Double = 24, color: Color = Color(0xDD000000),
        key: (any Key)? = nil
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        CupertinoIcons.registerFont()
        guard let scalar = UnicodeScalar(icon.codePoint) else {
            return SizedBox(width: size, height: size)
        }
        return SizedBox(
            width: size,
            height: size,
            child: Center(
                child: Text(
                    String(scalar),
                    style: TextStyle(
                        color: color,
                        fontSize: size,
                        height: 1.0,
                        fontFamily: icon.fontFamily
                    )
                )
            )
        )
    }
}
#endif
