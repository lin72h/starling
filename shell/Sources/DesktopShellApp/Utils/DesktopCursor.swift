// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import FlutterDRMBridge
#endif

/// Cursor shapes the shell can ask the DRM hardware cursor to display.
/// Raw values match the engine's `FlDrmCursorShape` enum.
public enum CursorShape: Int32 {
    case `default` = 0
    case resizeNS = 1   // top / bottom edges
    case resizeEW = 2   // left / right edges
    case resizeNESW = 3 // top-right / bottom-left corners
    case resizeNWSE = 4 // top-left / bottom-right corners
    case text = 5       // I-beam over editable text
    case pointer = 6    // pointing hand over links
}

/// Global setter wired up at startup (after fl_drm_view_create).
/// On macOS this is a no-op; on Linux it forwards to the DRM cursor.
public enum DesktopCursor {

    /// Set by main.swift once the DRM view is alive.
    nonisolated(unsafe) public static var shapeSetter: ((CursorShape) -> Void)?

    /// Set by main.swift too: hides the hardware sprite (true) or lets a
    /// shape show again (false).
    nonisolated(unsafe) public static var hiddenSetter: ((Bool) -> Void)?

    /// Last shape we asked for — avoids redundant calls on every hover tick.
    nonisolated(unsafe) private static var lastShape: CursorShape = .default
    /// While hidden (a pointer lock), shape requests are remembered, not
    /// applied — every hover handler on the desktop asks for a shape, and
    /// any one of them would otherwise bring the sprite back.
    nonisolated(unsafe) private static var hidden = false

    public static func setShape(_ shape: CursorShape) {
        guard shape != lastShape else { return }
        lastShape = shape
        if hidden { return }
        shapeSetter?(shape)
    }

    public static func hide() {
        guard !hidden else { return }
        hidden = true
        hiddenSetter?(true)
    }

    public static func show() {
        guard hidden else { return }
        hidden = false
        hiddenSetter?(false)
        // Re-apply through a different shape: the engine skips a shape it
        // believes is current, and the sprite it hid must be re-uploaded.
        let wanted = lastShape
        shapeSetter?(wanted == .default ? .text : .default)
        shapeSetter?(wanted)
    }
}
