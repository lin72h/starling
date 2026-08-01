// swift-tools-version: 6.0

import PackageDescription
import Foundation

#if os(Linux)
let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
let engineOutDir = "../engine/src/out/host_debug"
let engineFlutterRoot = "../engine/src/flutter"
// Starling deployment: set STARLING_DEPLOY to a staging dir providing
// lib/libbasu.so (sd-bus without systemd) and include/systemd -> basu
// headers. Links basu instead of libsystemd.
let starlingDeploy = ProcessInfo.processInfo.environment["STARLING_DEPLOY"]
let sdbusLib = starlingDeploy != nil ? "basu" : "systemd"
#else
let swiftToolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let engineOutDir = "../engine/src/out/ci/host_debug_unopt_arm64"
let engineFlutterRoot = "../engine/src/flutter"
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

#if os(macOS)
targets += [
    .executableTarget(
        name: "DesktopShellApp",
        dependencies: [
            .product(name: "SwiftRuntime", package: "FlutterSwift"),
            .product(name: "FlutterMacOSBridge", package: "FlutterSwift"),
            .product(name: "Flutter", package: "FlutterSwift"),
            .product(name: "CupertinoIcons", package: "FlutterSwift"),
        ],
        exclude: ["Shaders"],
        swiftSettings: [
            .interoperabilityMode(.Cxx),
            .unsafeFlags([
                "-Xcc", "-I\(swiftToolchainInclude)",
                "-Xcc", "-I\(engineOutDir)/FlutterMacOS.framework/Versions/A/Headers",
            ]),
        ],
        linkerSettings: [
            .unsafeFlags([
                "-F\(engineOutDir)",
                "-framework", "FlutterMacOS",
                "-framework", "IOSurface",
                "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
            ]),
        ]
    ),
]
#endif

#if os(Linux)
// Hoisted + explicitly typed so the big `targets` literal type-checks quickly
// (an untyped [] inside the literal blows up inference). The shell is
// DRM-only — the windowed GLFW dev path was removed.
let shellDeps: [Target.Dependency] = [
    // The framework stack (Flutter, SwiftRuntime, bridges, CupertinoIcons)
    // comes from the single shared dylib; only the DRM shim stays
    // app-linked (a header shim over the engine's C library).
    .product(name: "FlutterShared", package: "FlutterSwift"),
    .product(name: "FlutterDRMBridge", package: "FlutterSwift"),
    "WaylandServerBridge",
    "X11Server",
    "PortalService",
    "NotificationService",
    "ImeBridge",
    .product(name: "StarlingRegistry", package: "StarlingRegistry"),
    .product(name: "StarlingNet", package: "StarlingNet"),
    .product(name: "StarlingPower", package: "StarlingPower"),
]

let shellSwiftSettings: [SwiftSetting] = [
    .interoperabilityMode(.Cxx),
    .unsafeFlags(toolchainSwiftCFlags),
]

// Shared by the sd-bus-based C targets (PortalService, ImeBridge). Hoisted
// and explicitly typed to keep the targets literal type-checkable.
let sdbusCSettings: [CSetting] = [
    .define("_GNU_SOURCE"),
] + (starlingDeploy.map { [.unsafeFlags(["-I\($0)/include"])] } ?? [])
let sdbusLinkerSettings: [LinkerSetting] = [
    .linkedLibrary(sdbusLib),
] + (starlingDeploy.map { [.unsafeFlags(["-L\($0)/lib"])] } ?? [])

let shellLinkerFlags: [String] = [
    "-L\(engineOutDir)",
    "-lflutter_engine",
    "-lrt", "-lgbm", "-lEGL", "-lwayland-server", "-lxkbcommon",
    "-l\(sdbusLib)",
] + (starlingDeploy.map { ["-L\($0)/lib"] } ?? []) + [
    "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
    "-Xlinker", "--allow-shlib-undefined",
    "-Xlinker", "--export-dynamic",
]

targets += [
    // C library implementing a Wayland compositor server
    .target(
        name: "WaylandServer",
        path: "Sources/WaylandServer",
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("."),
            .unsafeFlags(["-I/usr/include/libdrm"]),
            .define("_GNU_SOURCE"),
        ],
        linkerSettings: [
            .linkedLibrary("wayland-server"),
            .linkedLibrary("xkbcommon"),
        ]
    ),
    // Clang module exposing WaylandServer C API to Swift
    .target(
        name: "WaylandServerBridge",
        dependencies: ["WaylandServer"],
        path: "Sources/WaylandServerBridge"
    ),
    // Portal service -- D-Bus portal backend using sd-bus
    .target(
        name: "PortalService",
        path: "Sources/PortalService",
        publicHeadersPath: "include",
        cSettings: [
            .define("_GNU_SOURCE"),
        ] + (starlingDeploy.map { [.unsafeFlags(["-I\($0)/include"])] } ?? []),
        linkerSettings: [
            .linkedLibrary(sdbusLib),
        ] + (starlingDeploy.map { [.unsafeFlags(["-L\($0)/lib"])] } ?? [])
    ),
    // Notification daemon (org.freedesktop.Notifications) using sd-bus
    .target(
        name: "NotificationService",
        path: "Sources/NotificationService",
        publicHeadersPath: "include",
        cSettings: sdbusCSettings,
        linkerSettings: sdbusLinkerSettings
    ),
    // fcitx5 DBus input-method bridge (IME: preedit, commits, candidates)
    .target(
        name: "ImeBridge",
        path: "Sources/ImeBridge",
        publicHeadersPath: "include",
        cSettings: sdbusCSettings,
        linkerSettings: sdbusLinkerSettings
    ),
    // Minimal X11 server for GPU-accelerated clients (DRI3/Present)
    .target(
        name: "X11Server",
        path: "Sources/X11Server",
        publicHeadersPath: "include",
        cSettings: [
            .define("_GNU_SOURCE"),
        ],
        cxxSettings: [
            .define("_GNU_SOURCE"),
        ],
        linkerSettings: [
            .linkedLibrary("xshmfence"),
        ]
    ),
    .executableTarget(
        name: "DesktopShellApp",
        dependencies: shellDeps,
        exclude: ["Shaders"],
        swiftSettings: shellSwiftSettings,
        linkerSettings: [.unsafeFlags(shellLinkerFlags)]
    ),
]
#endif

let package = Package(
    name: "DesktopShellApp",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    dependencies: [
        .package(name: "FlutterSwift", path: "../sdk"),
        // The app registry, shared with the App Store so the two cannot drift.
        .package(name: "StarlingRegistry", path: "../registry"),
        // The nmcli layer, shared with Settings so the two cannot drift.
        .package(name: "StarlingNet", path: "../network"),
        // The sysfs battery layer.
        .package(name: "StarlingPower", path: "../power"),
    ],
    targets: targets,
    cxxLanguageStandard: .cxx20
)
