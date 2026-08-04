// swift-tools-version: 6.0

import PackageDescription
import Foundation

// Context.environment, not ProcessInfo: it is the API SwiftPM sanctions for
// manifest-time environment reads, and the one where changing a variable
// actually re-evaluates the manifest. Same as sdk/Package.swift.
func env(_ key: String, default fallback: String) -> String {
    guard let v = Context.environment[key], !v.isEmpty else { return fallback }
    return v
}

// No toolchain include path here: <swift/bridging>, the only toolchain header
// the bridge headers needed, is vendored by the framework
// (sdk/tools/sync-vendored-headers.sh) and resolves through its own include
// directory. Nothing here may name a toolchain path: a build against a
// distribution's own Swift has no such directory to name.

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
let engineOutDir = env("STARLING_ENGINE_OUT",
                       default: appPackageDir + "/../../engine/src/out/host_debug")
#else
let engineOutDir = env("STARLING_ENGINE_OUT",
                       default: appPackageDir + "/../../engine/src/out/ci/host_debug_unopt_arm64")
#endif

// Ubuntu 26.04 (glibc 2.43 + libstdc++ 15) vs the ubuntu24.04-built 6.2.4
// toolchain: stops the C++-interop importer parsing <cmath> twice. Same as
// sdk/Package.swift; see docs/BUILDING.md.
#if os(Linux)
let glibcMathCompat = ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]
#else
let glibcMathCompat: [String] = []
#endif

#if os(macOS)
let platformConstraints: [SupportedPlatform] = [.macOS(.v14)]
#else
let platformConstraints: [SupportedPlatform] = []
#endif

var targets: [Target] = []

#if os(Linux)
targets += [
    // Hardware decode: our own MP4 demuxer and H.264 header parsing straight
    // into VA-API. libva is MIT and ships on every desktop, so it is linked
    // like any other system library — the dlopen dance existed for libav,
    // which is not here at all any more.
    .target(
        name: "CH264Decoder",
        linkerSettings: [.linkedLibrary("va"), .linkedLibrary("va-drm")]
    ),
    .executableTarget(
        name: "VideoPlayerApp",
        dependencies: [
            .product(name: "FlutterShared", package: "FlutterSwift"),
            "CH264Decoder",
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(glibcMathCompat),
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
