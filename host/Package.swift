// swift-tools-version: 6.0

// Copyright the Starling authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The windowed host: run a Swift Flutter app in an ordinary desktop window
// instead of compositing it through the shell.
//
// This is deliberately NOT part of the FlutterSwift package (../sdk, a checkout
// of starling-build/flutter-swift). It drags libglfw — vendored here as a
// committed binary in .deps/ — and Assets.swift resolves asset roots under
// /usr/share/starling. Neither belongs in a general-purpose SDK, and the
// desktop's own apps never use this path: they composite through the shell.
//
// Consumers: apps/BlueScreenApp and Examples/HelloWindow, both demos.

import PackageDescription
import Foundation

// Same probe and the same override as sdk/Package.swift's glibcMathCompat; see
// the long comment there and docs/BUILDING.md. Keep the two in step.
func needsGlibcMathCompat() -> Bool {
    if let forced = ProcessInfo.processInfo.environment["FLUTTER_SWIFT_GLIBC_MATH_COMPAT"],
       !forced.isEmpty {
        return forced != "0"
    }
    let fm = FileManager.default
    guard fm.fileExists(atPath: "/usr/include/math.h") else { return false }
    let newest = ((try? fm.contentsOfDirectory(atPath: "/usr/include/c++")) ?? [])
        .compactMap { Int($0) }.max() ?? 0
    return newest >= 15
}

#if os(Linux)
let glibcMathCompat = needsGlibcMathCompat()
    ? ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]
    : []
#else
let glibcMathCompat: [String] = []
#endif

let cxxInteropSettings: [SwiftSetting] = glibcMathCompat.isEmpty
    ? [.interoperabilityMode(.Cxx)]
    : [.interoperabilityMode(.Cxx), .unsafeFlags(glibcMathCompat)]

let package = Package(
    name: "FlutterSwiftHost",
    products: [
        .library(name: "FlutterRunner", targets: ["FlutterRunner"]),
        .library(name: "GLFWBridge", targets: ["GLFWBridge"]),
    ],
    dependencies: [
        // ../sdk is a symlink to a flutter-swift checkout, created by
        // ./bootstrap.sh exactly as the engine symlink is.
        .package(name: "FlutterSwift", path: "../sdk"),
    ],
    targets: [
        // Clang module exposing GLFW3 to Swift. GLFWBridge.h reaches the vendored
        // headers in .deps/include by relative path, so no include flag is needed.
        .target(name: "GLFWBridge"),
        // GLFW window + EGL surface + the embedder API, so an app can call
        // runAppWindowed() instead of carrying its own ~600-line host.
        // `.linkedLibrary` rather than -L/-lglfw as an unsafe flag: unsafe flags
        // make a package unusable as a versioned dependency.
        .target(
            name: "FlutterRunner",
            dependencies: [
                .product(name: "Flutter", package: "FlutterSwift"),
                .product(name: "SwiftRuntime", package: "FlutterSwift"),
                .product(name: "FlutterSwiftBridge", package: "FlutterSwift"),
                .product(name: "FlutterEmbedderBridge", package: "FlutterSwift"),
                "GLFWBridge",
            ],
            path: "Sources/FlutterRunner",
            swiftSettings: cxxInteropSettings,
            linkerSettings: [
                // Resolves against the system libglfw (libglfw3-dev), as it always
                // has. .deps/ carries the GLFW *headers*, which GLFWBridge.h reaches
                // by relative path; its lib/ is not on the link line.
                .linkedLibrary("glfw"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
