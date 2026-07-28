// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Build our reconstructed `SwiftUI` as a dynamic library that links the Flutter
// Swift framework + engine, so App.main() can render through Flutter. The target
// is named `SwiftUI` so the module (and thus all mangled symbols) match what an
// unmodified macOS SwiftUI binary imports. We force library evolution + Apple's
// install_name so the dylib can be interposed via DYLD_FRAMEWORK_PATH.

let pkgDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let engineOutDir = pkgDir + "/../../../engine/src/out/ci/host_debug_unopt_arm64"
let toolchainInclude = NSHomeDirectory() + "/Library/Developer/Toolchains/swift-6.2.1-RELEASE.xctoolchain/usr/include"
let appleSwiftUIInstallName = "/System/Library/Frameworks/SwiftUI.framework/Versions/A/SwiftUI"

let package = Package(
    name: "SwiftUIShim",
    platforms: [.macOS(.v14)],
    products: [
        // Both targets link into one dylib; SwiftUI references FlutterHost's
        // `swiftui_compat_run` as a C symbol (no Swift import → no SwiftUICore).
        .library(name: "SwiftUIShim", type: .dynamic, targets: ["SwiftUI", "FlutterHost"]),
    ],
    dependencies: [
        .package(name: "FlutterSwift", path: "../.."),
    ],
    targets: [
        // The Flutter/AppKit-facing half. NOT named SwiftUI, so importing AppKit here
        // is safe (no SwiftUICore collision). Exposes only the neutral RNode tree.
        .target(
            name: "FlutterHost",
            dependencies: [
                .product(name: "SwiftRuntime", package: "FlutterSwift"),
                .product(name: "FlutterMacOSBridge", package: "FlutterSwift"),
                .product(name: "Flutter", package: "FlutterSwift"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags([
                    "-Xcc", "-I\(toolchainInclude)",
                    "-Xcc", "-I\(engineOutDir)/FlutterMacOS.framework/Versions/A/Headers",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F\(engineOutDir)",
                    "-framework", "FlutterMacOS",
                    "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
                    // Product dylib must masquerade as Apple's SwiftUI for interposition.
                    "-Xlinker", "-install_name", "-Xlinker", appleSwiftUIInstallName,
                    // The /System install_name makes ld treat us as shared-cache-eligible
                    // (can't then link FlutterMacOS); opt out.
                    "-Xlinker", "-not_for_dyld_shared_cache",
                ]),
            ]
        ),
        // The reconstructed `SwiftUI` module — library-evolution, Foundation-ONLY
        // (exactly like the working standalone build, so Apple's SwiftUICore is never
        // loaded). Reaches FlutterHost via the `swiftui_compat_run` C symbol.
        .target(
            name: "SwiftUI",
            swiftSettings: [
                .unsafeFlags([
                    "-enable-library-evolution",
                ]),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
