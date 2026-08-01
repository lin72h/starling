// swift-tools-version: 6.0

import PackageDescription
import Foundation

// The video player, back from ade2f64 — but decoding through a SPAWNED
// ffmpeg this time, not a linked one. The original linked libavcodec, and
// Ubuntu's FFmpeg build enables GPL parts, which pulled a GPL obligation
// into the tree (and pinned the build host's soname series, which kept the
// app out of the .deb). A process boundary does neither: nothing here
// links FFmpeg, and the .deb already Recommends the ffmpeg binary for the
// screen recorder.

// Absolute so the -rpath baked into this app resolves regardless of the cwd the
// shell spawns it from: child processes get LD_LIBRARY_PATH scrubbed and fall
// back to their own RUNPATH.
let appPackageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

#if os(Linux)
let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
let engineOutDir = appPackageDir + "/../../engine/src/out/host_debug"
#else
let swiftToolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let engineOutDir = appPackageDir + "/../../engine/src/out/ci/host_debug_unopt_arm64"
#endif

// Ubuntu 26.04 (glibc 2.43 + libstdc++ 15) vs the ubuntu24.04-built 6.2.4
// toolchain: stops the C++-interop importer parsing <cmath> twice. Same as
// sdk/Package.swift; see docs/BUILDING.md.
#if os(Linux)
let glibcMathCompat = ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]
#else
let glibcMathCompat: [String] = []
#endif

let toolchainSwiftCFlags: [String] = ["-Xcc", "-I\(swiftToolchainInclude)"] + glibcMathCompat

#if os(macOS)
let platformConstraints: [SupportedPlatform] = [.macOS(.v14)]
#else
let platformConstraints: [SupportedPlatform] = []
#endif

var targets: [Target] = []

#if os(Linux)
targets += [
    .executableTarget(
        name: "VideoPlayerApp",
        dependencies: [
            .product(name: "FlutterShared", package: "FlutterSwift"),
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-L\(engineOutDir)",
                "-lflutter_engine",
                "-lrt",
                "-lgbm",
                "-lEGL",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
                "-Xlinker", "--allow-shlib-undefined",
                "-Xlinker", "--export-dynamic",
            ]),
        ]
    ),
]
#endif

let package = Package(
    name: "VideoPlayerApp",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    dependencies: [
        .package(name: "FlutterSwift", path: "../../sdk"),
    ],
    targets: targets,
    cxxLanguageStandard: .cxx20
)
