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

let package = Package(
    name: "SettingsApp",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    dependencies: [
        .package(name: "FlutterSwift", path: "../../sdk"),
        // The nmcli layer, shared with the shell so the two cannot drift.
        .package(name: "StarlingNet", path: "../../network"),
        // The sysfs battery layer, shared with the shell's popup.
        .package(name: "StarlingPower", path: "../../power"),
        // The wpctl layer — PipeWire wrapped once.
        .package(name: "StarlingAudio", path: "../../audio"),
        // The timedatectl layer — systemd-timedated wrapped once.
        .package(name: "StarlingTime", path: "../../time"),
        // The app registry — Default Apps offers what the records declare.
        .package(name: "StarlingRegistry", path: "../../registry"),
    ],
    targets: [
        {
            #if os(macOS)
            return .executableTarget(
                name: "SettingsApp",
                dependencies: [
                    .product(name: "SwiftRuntime", package: "FlutterSwift"),
                    .product(name: "FlutterMacOSBridge", package: "FlutterSwift"),
                    .product(name: "Flutter", package: "FlutterSwift"),
                    .product(name: "CupertinoIcons", package: "FlutterSwift"),
                    .product(name: "StarlingNet", package: "StarlingNet"),
                    .product(name: "StarlingPower", package: "StarlingPower"),
                    .product(name: "StarlingAudio", package: "StarlingAudio"),
                    .product(name: "StarlingTime", package: "StarlingTime"),
                    .product(name: "StarlingRegistry", package: "StarlingRegistry"),
                ],
                swiftSettings: [
                    .interoperabilityMode(.Cxx),
                    .unsafeFlags([
                        "-Xcc", "-I\(engineOutDir)/FlutterMacOS.framework/Versions/A/Headers",
                    ]),
                ],
                linkerSettings: [
                    .unsafeFlags([
                        "-F\(engineOutDir)",
                        "-framework", "FlutterMacOS",
                        "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
                    ]),
                ]
            )
            #else
            return .executableTarget(
                name: "SettingsApp",
                dependencies: [
                    .product(name: "FlutterShared", package: "FlutterSwift"),
                    .product(name: "StarlingNet", package: "StarlingNet"),
                    .product(name: "StarlingPower", package: "StarlingPower"),
                    .product(name: "StarlingAudio", package: "StarlingAudio"),
                    .product(name: "StarlingTime", package: "StarlingTime"),
                    .product(name: "StarlingRegistry", package: "StarlingRegistry"),
                ],
                swiftSettings: [
                    .interoperabilityMode(.Cxx),
                    .unsafeFlags(glibcMathCompat),
                ],
                linkerSettings: [
                    .unsafeFlags([
                        "-L\(engineOutDir)",
                        "-lflutter_engine",
                        "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
                        "-Xlinker", "--allow-shlib-undefined",
                        "-Xlinker", "--export-dynamic",
                    ]),
                ]
            )
            #endif
        }()
    ],
    cxxLanguageStandard: .cxx20
)
