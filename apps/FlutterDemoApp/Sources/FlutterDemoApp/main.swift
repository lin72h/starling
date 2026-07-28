// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Flutter
import FlutterSwiftBridge
import SwiftRuntime
import FlutterMacOSBridge

// MARK: - macOS Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon — headless producer

// Disable stdout buffering so parent sees lines immediately
setbuf(stdout, nil)

// Create FlutterEngine (headless — needed for Skia init).
let engine = FlutterEngine(name: "flutter-demo", project: nil, allowHeadlessExecution: true)

// Create the C callback table backed by SwiftRuntimeDelegate.
var callbacks = createRuntimeCallbacks()

// Start engine in Swift mode BEFORE creating the view controller.
let started = withUnsafePointer(to: &callbacks) { ptr in
   engine.runSwift(withRuntimeCallbacks: UnsafeRawPointer(ptr))
}
guard started else {
    fatalError("[FlutterDemoApp] Failed to start engine in Swift mode")
}

// Create FlutterViewController for implicit view creation.
let viewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)

// Create hidden 1x1 borderless NSWindow to satisfy NSView requirements.
let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 1, 1),
    styleMask: .borderless,
    backing: .buffered,
    defer: false
)
window.contentViewController = viewController
window.orderOut(nil)  // Keep hidden

// Do NOT call runApp() — IOSurfaceRenderer has its own render pipeline.
// Create the renderer and mount the widget tree.
let renderer = IOSurfaceRenderer(width: 640, height: 480)
renderer.mountWidget {
    Directionality(
        textDirection: TextDirection.ltr,
        child: FlutterDemoApp()
    )
}
renderer.start(fps: 30)

// Enter event loop.
app.run()

#elseif os(Linux)
import Flutter
import FlutterSwiftBridge
import FlutterEmbedderBridge
import DmaBufBridge
import SwiftRuntime
import Foundation
import Glibc

// MARK: - Linux Entry Point

print("[FlutterDemoApp] Starting on Linux")

guard let socketPath = ProcessInfo.processInfo.environment["FLUTTER_DMABUF_SOCKET"],
      !socketPath.isEmpty else {
    fatalError("[FlutterDemoApp] FLUTTER_DMABUF_SOCKET not set")
}
guard access("/dev/dri/renderD128", R_OK | W_OK) == 0 else {
    fatalError("[FlutterDemoApp] /dev/dri/renderD128 not accessible")
}

guard let gpu = GpuDmaBufRenderer(width: 640, height: 480, socketPath: socketPath) else {
    fatalError("[FlutterDemoApp] GpuDmaBufRenderer init failed")
}

print("[FlutterDemoApp] Using GPU embedder (zero-copy)")
gpu.mountWidget {
    Directionality(textDirection: .ltr, child: FlutterDemoApp())
}
gpu.run()

#endif
