// swift-tools-version: 6.0

import PackageDescription
import Foundation

// Task Manager — the Activity-Monitor-style system monitor, moved here from
// sdk/Examples. The code is host-neutral (runStarlingApp): spawned by the
// shell it composites as a DMA-BUF child; a GTK-linked build of the same
// sources can run it windowed. This target is the desktop one — FlutterShared
// only, no GTK in the link set.

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
        name: "TaskManagerApp",
        dependencies: [
            .product(name: "FlutterShared", package: "FlutterSwift"),
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
            .unsafeFlags(["-strict-concurrency=minimal"]),
            .swiftLanguageMode(.v5),
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
    name: "TaskManagerApp",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    dependencies: [
        .package(name: "FlutterSwift", path: "../../sdk"),
    ],
    targets: targets,
    cxxLanguageStandard: .cxx20
)
