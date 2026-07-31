// swift-tools-version: 6.0
// The Linux/arm64 FlutterHost for the macOS-binary-compat shim: builds
// libCompatHost.so, a dynamic library the Mach-O loader (machold) dlopens to
// satisfy the `swiftui_compat_run/_update` C symbols the reconstructed `SwiftUI`
// module crosses into. It parses the JSON view tree, translates it to this repo's
// Swift `Flutter` widgets, and boots the Flutter engine in a GLFW/Wayland window
// (the Linux counterpart of the macOS FlutterHost's NSWindow path).
import PackageDescription
import Foundation

let swiftToolchainInclude = NSHomeDirectory() + "/.local/share/swiftly/toolchains/6.2.4/usr/include"
let engineOutDir = "../../../engine/src/out/host_debug"
let glfwLib = "../../../host/.deps/lib"

let package = Package(
    name: "CompatHost",
    products: [
        .library(name: "CompatHost", type: .dynamic, targets: ["CompatHost"]),
    ],
    dependencies: [
        .package(name: "FlutterSwift", path: "../../../sdk"),
        // GLFWBridge stayed with the desktop when the framework was extracted.
        .package(name: "FlutterSwiftHost", path: "../../../host"),
    ],
    targets: [
        .target(
            name: "CompatHost",
            dependencies: [
                .product(name: "SwiftRuntime", package: "FlutterSwift"),
                .product(name: "FlutterSwiftBridge", package: "FlutterSwift"),
                .product(name: "FlutterEmbedderBridge", package: "FlutterSwift"),
                .product(name: "GLFWBridge", package: "FlutterSwiftHost"),
                .product(name: "Flutter", package: "FlutterSwift"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags([
                    "-Xcc", "-I\(swiftToolchainInclude)",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(engineOutDir)",
                    "-lflutter_engine",
                    "-L\(glfwLib)",
                    "-lglfw",
                    "-Xlinker", "-rpath", "-Xlinker", "\(engineOutDir)",
                    "-Xlinker", "-rpath", "-Xlinker", glfwLib,
                    "-Xlinker", "--allow-shlib-undefined",
                    "-Xlinker", "--export-dynamic",
                ]),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
