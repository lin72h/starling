// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import PortalService
import Foundation

/// Manages the XDG Desktop Portal service (Settings + FileChooser).
/// Runs a D-Bus service on a background thread that claims
/// org.freedesktop.portal.Desktop, replacing xdg-desktop-portal.
///
/// Settings: handled directly (Read/ReadAll return shell preferences).
/// FileChooser: portal C code launches FileExplorerApp --picker as a
///   Wayland client, reads selected URIs from its stdout, sends D-Bus Response.
final class PortalIntegration {

    private var service: OpaquePointer?  // PortalService*

    init() {
        service = portal_service_create()
    }

    deinit {
        stop()
        if let s = service {
            portal_service_destroy(s)
        }
    }

    /// Start the portal service. Connects to the session bus and claims
    /// org.freedesktop.portal.Desktop.
    func start(busAddress: String? = nil, targetUid: UInt32 = 0) {
        guard let s = service else { return }

        let r: Int32
        if let addr = busAddress {
            r = portal_service_start(s, addr, UInt32(targetUid))
        } else {
            r = portal_service_start(s, nil, UInt32(targetUid))
        }

        if r < 0 {
            FileHandle.standardError.write(
                Data("[PortalIntegration] Failed to start: \(r)\n".utf8))
        }
    }

    func stop() {
        guard let s = service else { return }
        portal_service_stop(s)
    }

    // MARK: - ScreenCast

    /// Register the ScreenCast start/stop hooks (called on the portal
    /// thread; see ScreenCastService).
    func setScreenCastHooks(start: @escaping portal_screencast_start_fn,
                            stop: @escaping portal_screencast_stop_fn,
                            userdata: UnsafeMutableRawPointer?) {
        guard let s = service else { return }
        portal_service_set_screencast_hooks(s, start, stop, userdata)
    }

    /// Deliver an async ScreenCast start result. Emits the D-Bus Response
    /// (with the stream's PipeWire node on success) on the portal thread.
    /// `response`: 0 = success, 2 = failed. Thread-safe.
    func completeScreenCastStart(handle: String, node: UInt32,
                                 width: UInt32, height: UInt32,
                                 response: UInt32) {
        guard let s = service else { return }
        portal_service_complete_screencast_start(s, handle, node,
                                                 width, height, response)
    }

    // MARK: - Settings

    func setColorScheme(_ scheme: UInt32) {
        guard let s = service else { return }
        portal_service_set_color_scheme(s, scheme)
    }

    func setAccentColor(r: Double, g: Double, b: Double) {
        guard let s = service else { return }
        portal_service_set_accent_color(s, r, g, b)
    }

    func setContrast(_ contrast: UInt32) {
        guard let s = service else { return }
        portal_service_set_contrast(s, contrast)
    }

    // MARK: - FileChooser

    /// Set path to file chooser helper executable (FileExplorerApp).
    func setFileChooserCommand(_ path: String) {
        guard let s = service else { return }
        portal_service_set_file_chooser_command(s, path)
    }

    /// Set a custom launcher that uses LinuxProcessAppManager to launch the
    /// file chooser as a DMA-BUF composited child process.
    func setChooserLauncher(_ launcher: @escaping portal_launch_chooser_fn, userdata: UnsafeMutableRawPointer?) {
        guard let s = service else { return }
        portal_service_set_chooser_launcher(s, launcher, userdata)
    }

    /// Deliver an async file-chooser result (see setChooserLauncher). Emits the
    /// D-Bus Response on the portal thread. `response`: 0=success, 1=cancelled,
    /// 2=error. Thread-safe.
    func completeRequest(handle: String, uris: [String], response: UInt32) {
        guard let s = service else { return }
        if uris.isEmpty {
            portal_service_complete_request(s, handle, nil, 0, response)
            return
        }
        // Build an array of C string pointers (const char *const *).
        let cStrings: [UnsafePointer<CChar>?] = uris.map { UnsafePointer(strdup($0)) }
        defer { cStrings.forEach { free(UnsafeMutablePointer(mutating: $0)) } }
        cStrings.withUnsafeBufferPointer { buf in
            portal_service_complete_request(s, handle,
                                            buf.baseAddress, Int32(uris.count), response)
        }
    }
}
