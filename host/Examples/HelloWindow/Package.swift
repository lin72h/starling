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

// Absolute, derived from this file: the executable's -rpath must resolve no
// matter what directory it is launched from. See sdk/Package.swift for why the
// glibc <cmath> workaround is needed on 26.04.
//
// host/Examples/HelloWindow -> ../../../ is the repo root, so this is the
// `engine` symlink ./bootstrap.sh makes. Unchanged by the move out of sdk/:
// that was sdk/Examples/HelloWindow, the same depth.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let engineOutDir = env("STARLING_ENGINE_OUT",
                       default: packageDir + "/../../../engine/src/out/host_debug")

let glibcMathCompat = ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]

let package = Package(
    name: "HelloWindow",
    dependencies: [
        // The windowed host, which is this package's whole point...
        .package(name: "FlutterSwiftHost", path: "../.."),
        // ...and the framework, now its own repo, reached through the repo-root
        // `sdk` symlink that ./bootstrap.sh makes.
        .package(name: "FlutterSwift", path: "../../../sdk"),
    ],
    targets: [
        .executableTarget(
            name: "HelloWindow",
            dependencies: [
                .product(name: "Flutter", package: "FlutterSwift"),
                .product(name: "FlutterRunner", package: "FlutterSwiftHost"),
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
        ),
    ],
    cxxLanguageStandard: .cxx20
)
