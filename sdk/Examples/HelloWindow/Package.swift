// swift-tools-version: 6.0

import PackageDescription
import Foundation

// Absolute, derived from this file: the executable's -rpath must resolve no
// matter what directory it is launched from. See sdk/Package.swift for why the
// toolchain include and the glibc <cmath> workaround are needed on 26.04.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
let engineOutDir = packageDir + "/../../../engine/src/out/host_debug"

let glibcMathCompat = ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]
let toolchainSwiftCFlags: [String] = ["-Xcc", "-I\(swiftToolchainInclude)"] + glibcMathCompat

let package = Package(
    name: "HelloWindow",
    dependencies: [
        .package(name: "FlutterSwift", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "HelloWindow",
            dependencies: [
                .product(name: "Flutter", package: "FlutterSwift"),
                .product(name: "FlutterRunner", package: "FlutterSwift"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags(toolchainSwiftCFlags),
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
