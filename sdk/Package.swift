// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import PackageDescription
import Foundation

// --- Platform-conditional paths -----------------------------------------------

// Absolute path to this package's directory. engineOutDir is derived from it so
// that -L / -rpath flags resolve correctly even when this package is consumed as
// a dependency: the executable link step runs in the *consumer's* directory (e.g.
// apps/FlutterDemoApp), where a relative "../engine/..." would point at the wrong
// place. Using #filePath makes the path independent of the build invocation's cwd.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

#if os(Linux)
let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
let engineOutDir = packageDir + "/../engine/src/out/host_debug"
// On Linux the Swift bridge is merged into libflutter_engine.so.
let engineLinkName = "flutter_engine"
#else
let swiftToolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let engineOutDir = packageDir + "/../engine/src/out/ci/host_debug_unopt_arm64"
// On macOS the Swift bridge is a separate libswift_bridge.dylib that sits
// alongside FlutterMacOS.framework (the engine itself) in engineOutDir.
let engineLinkName = "swift_bridge"
#endif

// The 6.2.4 toolchain is an ubuntu24.04 build, and Ubuntu 26.04 — the base
// platform — pairs glibc 2.43 with libstdc++ 15. That combination makes the
// C++-interop importer parse <cmath> textually *and* from the prebuilt `std`
// module, so Foundation's C shim dies with "cmath: redefinition of 'acos'".
// Predefining libstdc++'s <math.h> include guard stops the textual pull;
// force-including glibc's math.h keeps the C declarations every TU expects.
// Identical semantics on older glibc, so it is applied uniformly rather than
// version-gated. Remove once the toolchain ships a native 26.04 build.
// Full write-up: docs/BUILDING.md.
#if os(Linux)
let glibcMathCompat = ["-Xcc", "-D_GLIBCXX_MATH_H", "-Xcc", "-include", "-Xcc", "/usr/include/math.h"]
#else
let glibcMathCompat: [String] = []
#endif

// What every Swift target hands the clang importer: the toolchain's own C
// headers plus the compat flags above.
let toolchainSwiftCFlags: [String] = ["-Xcc", "-I\(swiftToolchainInclude)"] + glibcMathCompat

// Bridge headers come from the engine checkout, reached through the `engine`
// symlink at the repo root (see bootstrap.sh). Absolute so the flag stays
// correct when this package is built as a consumer's dependency.
let cxxBridgeInclude = packageDir + "/../engine/src/flutter/lib/ui/swift/include"

// --- Products ----------------------------------------------------------------

var products: [Product] = [
    .library(name: "FlutterSwiftBridge", targets: ["FlutterSwiftBridge"]),
    .library(name: "Flutter", targets: ["Flutter"]),
    .library(name: "SwiftRuntime", targets: ["SwiftRuntime"]),
    .library(name: "CupertinoIcons", targets: ["CupertinoIcons"]),
]

#if os(Linux)
products += [
    .library(name: "FlutterEmbedderBridge", targets: ["FlutterEmbedderBridge"]),
    .library(name: "FlutterDRMBridge", targets: ["FlutterDRMBridge"]),
    .library(name: "GLFWBridge", targets: ["GLFWBridge"]),
    .library(name: "DmaBufBridge", targets: ["DmaBufBridge"]),
    // The windowed host: a Swift Flutter app in an ordinary desktop window,
    // X11 or Wayland. Deliberately NOT part of FlutterShared — the desktop's
    // own apps composite through the shell and must not drag libglfw into
    // the shipped dylib.
    .library(name: "FlutterRunner", targets: ["FlutterRunner"]),
    // One shared dylib carrying the whole framework stack (plus the C shim
    // modules apps import directly). Apps that link this single product get
    // binaries with only their own code — the packaged desktop ships one
    // libFlutterShared.so instead of nine statically-duplicated frameworks.
    .library(name: "FlutterShared", type: .dynamic,
             targets: ["Flutter", "SwiftRuntime", "FlutterSwiftBridge",
                       "CupertinoIcons", "FlutterEmbedderBridge", "DmaBufBridge"]),
]
#endif

#if os(macOS)
products += [
    .library(name: "FlutterMacOSBridge", targets: ["FlutterMacOSBridge"]),
]
#endif

// --- Targets -----------------------------------------------------------------

// FlutterEmbedderBridge and DmaBufBridge are Linux-only targets (declared under
// #if os(Linux) below). Referencing them from the Flutter target on macOS — even
// with a .linux platform condition — makes SwiftPM require the targets to exist,
// so the dependency list itself must be gated by platform.
#if os(Linux)
let flutterDeps: [Target.Dependency] = [
    "FlutterSwiftBridge",
    .target(name: "SwiftRuntime"),
    .target(name: "FlutterEmbedderBridge"),
    .target(name: "DmaBufBridge"),
]
#else
let flutterDeps: [Target.Dependency] = [
    "FlutterSwiftBridge",
    .target(name: "SwiftRuntime"),
]
#endif

var targets: [Target] = [
    // Main Swift target containing the dart:ui Swift implementation
    .target(
        name: "FlutterSwiftBridge",
        dependencies: ["FlutterSwiftBridgeCxx"],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-L\(engineOutDir)", "-l\(engineLinkName)",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
            ]),
        ]
    ),
    // C++ bridge module with modulemap pointing to engine headers
    .target(
        name: "FlutterSwiftBridgeCxx",
        cxxSettings: [
            .unsafeFlags(["-isystem", swiftToolchainInclude]),
            .unsafeFlags(["-I", cxxBridgeInclude]),
        ]
    ),
    // Flutter Framework target (Swift port of Flutter framework)
    .target(
        name: "Flutter",
        dependencies: flutterDeps,
        path: "Sources/Flutter",
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    ),
    // SwiftRuntime target -- Swift delegate that receives Shell->Framework calls
    .target(
        name: "SwiftRuntime",
        dependencies: ["FlutterSwiftBridge"],
        path: "Sources/SwiftRuntime",
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ]
    ),
    // CupertinoIcons -- Apple SF Symbols-style icon set (1,322 icons + TTF font)
    .target(
        name: "CupertinoIcons",
        dependencies: ["Flutter", "FlutterSwiftBridge"],
        path: "Sources/CupertinoIcons",
        resources: [
            .copy("Resources/CupertinoIcons.ttf"),
        ],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ]
    ),
    // Test targets
    .testTarget(
        name: "FlutterSwiftBridgeTests",
        dependencies: ["FlutterSwiftBridge"],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-L\(engineOutDir)", "-l\(engineLinkName)",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
            ]),
        ]
    ),
    .testTarget(
        name: "FlutterTests",
        dependencies: ["Flutter"],
        path: "Tests/FlutterTests",
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-L\(engineOutDir)", "-l\(engineLinkName)",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
            ]),
        ]
    ),
    .testTarget(
        name: "SwiftRuntimeTests",
        dependencies: ["SwiftRuntime", "FlutterSwiftBridge"],
        path: "Tests/SwiftRuntimeTests",
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-L\(engineOutDir)", "-l\(engineLinkName)",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
            ]),
        ]
    ),
]

// --- macOS-only targets ------------------------------------------------------

#if os(macOS)
targets += [
    .target(
        name: "FlutterMacOSBridge",
        cSettings: [
            .unsafeFlags([
                "-I", "\(engineOutDir)/FlutterMacOS.framework/Versions/A/Headers",
            ]),
        ]
    ),
]
#endif

// --- Linux-only targets ------------------------------------------------------

#if os(Linux)
let glfwInclude = ".deps/include"
let glfwLib = ".deps/lib"

targets += [
    // Clang module exposing Flutter embedder API to Swift
    .target(
        name: "FlutterEmbedderBridge"
    ),
    // Clang module exposing GLFW3 to Swift
    .target(
        name: "GLFWBridge"
    ),
    // Clang module exposing DRM shell public API (fl_drm_view.h) to Swift
    .target(
        name: "FlutterDRMBridge"
    ),
    // The windowed host — GLFW window + EGL surface + the embedder API, so an
    // app can call runAppWindowed() instead of carrying its own ~600-line
    // host. `.linkedLibrary` rather than an -L/-lglfw unsafeFlag on purpose:
    // a product with unsafe flags cannot be depended on by version, which
    // this one has to be if the SDK is ever consumed from outside this tree.
    .target(
        name: "FlutterRunner",
        dependencies: ["Flutter", "SwiftRuntime", "FlutterSwiftBridge",
                       "FlutterEmbedderBridge", "GLFWBridge"],
        path: "Sources/FlutterRunner",
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags(toolchainSwiftCFlags),
        ],
        linkerSettings: [
            .linkedLibrary("glfw"),
        ]
    ),
    // Clang module wrapping GBM + SCM_RIGHTS + EGL DMA-BUF import helpers
    .target(
        name: "DmaBufBridge",
        cSettings: [
            .unsafeFlags(["-I/usr/include/libdrm"]),
        ],
        linkerSettings: [
            .unsafeFlags(["-lgbm", "-lEGL", "-lGLESv2"]),
        ]
    ),
]
#endif

// --- Package declaration -----------------------------------------------------

#if os(macOS)
let platformConstraints: [SupportedPlatform] = [.macOS(.v14)]
#else
let platformConstraints: [SupportedPlatform] = []
#endif

let package = Package(
    name: "FlutterSwift",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    products: products,
    targets: targets,
    cxxLanguageStandard: .cxx20
)
