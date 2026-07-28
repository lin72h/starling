// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import CoreVideo
import Flutter
import FlutterMacOSBridge
import Foundation
import IOSurface

/// Sendable wrapper for FlutterEngine reference (engine is always used on main thread).
private struct SendableEngine: @unchecked Sendable {
    let engine: FlutterEngine
}

/// Sendable wrapper for closures that are always dispatched to main thread.
private struct SendableClosure: @unchecked Sendable {
    let closure: () -> Void
}

/// Sendable wrapper for closures with one argument.
private struct SendableClosure1<T>: @unchecked Sendable {
    let closure: (T) -> Void
}

/// Sendable wrapper for ProcessAppManager (always used on main thread).
private struct SendableManager: @unchecked Sendable {
    weak var manager: ProcessAppManager?
}

/// Thread-safe mutable box for sharing state across closures.
private final class SendableBox<T: Sendable>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

/// Manages child processes that render to IOSurfaces for cross-process
/// compositing into the desktop shell via Flutter's texture registry.
///
/// Each child process:
/// - Renders its widget tree to an IOSurface (shared GPU memory)
/// - Sends the surface ID via stdout (`SURFACE:<id>:<w>:<h>`)
/// - Signals new frames via stdout (`F`)
///
/// This manager looks up the IOSurface by ID, wraps it as a FlutterTexture
/// (zero-copy via CVPixelBufferCreateWithIOSurface), and notifies the engine
/// when new frames are available.
class ProcessAppManager {

    private let engine: FlutterEngine

    /// Active process apps keyed by their texture ID.
    private var apps: [Int64: ProcessAppEntry] = [:]

    init(engine: FlutterEngine) {
        self.engine = engine
    }

    /// Launches a child process and bridges its IOSurface output to a FlutterTexture.
    ///
    /// - Parameters:
    ///   - executableName: Name of the executable to find next to the current binary.
    ///   - onReady: Called on the main thread with the texture ID once the surface is established.
    ///   - onTerminated: Called on the main thread when the child process exits.
    func launchApp(
        executableName: String,
        onReady: @escaping (Int64) -> Void,
        onTerminated: @escaping () -> Void
    ) {
        // Find the executable next to the current binary
        let currentExe = Bundle.main.executableURL!
        let siblingExe = currentExe.deletingLastPathComponent()
            .appendingPathComponent(executableName)

        guard FileManager.default.fileExists(atPath: siblingExe.path) else {
            NSLog("[ProcessAppManager] Cannot find \(executableName) at \(siblingExe.path)")
            return
        }

        let process = Process()
        process.executableURL = siblingExe

        let pipe = Pipe()
        process.standardOutput = pipe

        let sendableEngine = SendableEngine(engine: engine)
        let sendableOnTerminated = SendableClosure(closure: onTerminated)
        let sendableOnReady = SendableClosure1(closure: onReady)
        let sendableSelf = SendableManager(manager: self)

        // Shared mutable state for stdout parsing across closures
        let textureIdBox = SendableBox<Int64>(0)
        nonisolated(unsafe) var lineBuffer = ""

        // Read stdout asynchronously
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // EOF — process has exited
                handle.readabilityHandler = nil
                return
            }

            guard let str = String(data: data, encoding: .utf8) else { return }

            // Buffer partial lines
            lineBuffer += str
            while let newlineRange = lineBuffer.range(of: "\n") {
                let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
                lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                if line.hasPrefix("SURFACE:") {
                    // Parse SURFACE:<id>:<w>:<h>
                    let parts = line.split(separator: ":")
                    guard parts.count == 4,
                          let surfaceIdVal = UInt32(parts[1]),
                          let _ = Int(parts[2]),
                          let _ = Int(parts[3])
                    else {
                        NSLog("[ProcessAppManager] Malformed SURFACE line: \(line)")
                        continue
                    }

                    // Look up the IOSurface by its global ID (returns IOSurfaceRef)
                    guard let surfaceRef = IOSurfaceLookup(surfaceIdVal) else {
                        NSLog("[ProcessAppManager] IOSurfaceLookup failed for ID \(surfaceIdVal)")
                        continue
                    }

                    // Create texture and register with engine
                    let texture = IOSurfaceTexture(surfaceRef: surfaceRef)

                    DispatchQueue.main.async {
                        guard let mgr = sendableSelf.manager else { return }
                        let texId = sendableEngine.engine.register(texture)
                        textureIdBox.value = texId

                        let entry = ProcessAppEntry(
                            process: process,
                            texture: texture,
                            textureId: texId,
                            pipe: pipe
                        )
                        mgr.apps[texId] = entry

                        sendableOnReady.closure(texId)
                    }
                } else if line == "F" {
                    // New frame available
                    DispatchQueue.main.async {
                        let texId = textureIdBox.value
                        guard texId != 0 else { return }
                        sendableEngine.engine.textureFrameAvailable(texId)
                    }
                }
            }
        }

        // Handle process termination
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                let texId = textureIdBox.value
                if texId != 0 {
                    sendableSelf.manager?.apps.removeValue(forKey: texId)
                    sendableEngine.engine.unregisterTexture(texId)
                }
                sendableOnTerminated.closure()
            }
        }

        do {
            try process.run()
        } catch {
            NSLog("[ProcessAppManager] Failed to launch \(executableName): \(error)")
        }
    }

    /// Terminates the child process and unregisters its texture.
    func destroyApp(textureId: Int64) {
        guard let entry = apps.removeValue(forKey: textureId) else { return }
        entry.pipe.fileHandleForReading.readabilityHandler = nil
        if entry.process.isRunning {
            entry.process.terminate()
        }
        engine.unregisterTexture(textureId)
    }
}

/// Internal bookkeeping for a single process app instance.
private struct ProcessAppEntry {
    let process: Process
    let texture: IOSurfaceTexture
    let textureId: Int64
    let pipe: Pipe
}

// MARK: - IOSurfaceTexture

/// Bridges a cross-process IOSurface to Flutter's texture system.
///
/// Creates a CVPixelBuffer backed by the IOSurface (zero-copy) and returns
/// it from `copyPixelBuffer()` for the engine's raster thread.
class IOSurfaceTexture: NSObject, FlutterTexture {

    private let pixelBuffer: CVPixelBuffer

    init(surfaceRef: IOSurfaceRef) {
        // CVPixelBufferCreateWithIOSurface in C++ interop mode uses
        // Unmanaged<CVPixelBuffer>? for the output parameter.
        var unmanagedPB: Unmanaged<CVPixelBuffer>?
        let status = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            surfaceRef,
            nil,
            &unmanagedPB
        )
        guard status == kCVReturnSuccess, let retained = unmanagedPB else {
            fatalError("[IOSurfaceTexture] CVPixelBufferCreateWithIOSurface failed: \(status)")
        }
        self.pixelBuffer = retained.takeRetainedValue()
        super.init()
    }

    /// Called by the engine's raster thread to obtain the current frame.
    /// The CVPixelBuffer is backed by the shared IOSurface, so it always
    /// reflects the latest pixels written by the child process.
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        return Unmanaged.passRetained(pixelBuffer)
    }
}
#endif
