// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - WindowTitleBar

/// Title bar for a desktop window. Supports drag-to-move and window controls
/// (minimize, maximize, close). macOS-style colored circle buttons on the left.
class WindowTitleBar: StatefulWidget {

    let title: String
    let isFocused: Bool
    let isMaximized: Bool
    let isFullscreen: Bool
    let onMove: ((Offset) -> Void)?
    let onMinimize: (() -> Void)?
    let onMaximize: (() -> Void)?
    let onClose: (() -> Void)?
    /// macOS-style double-click to toggle maximized state.
    let onDoubleTap: (() -> Void)?

    init(
        title: String,
        isFocused: Bool,
        isMaximized: Bool,
        isFullscreen: Bool = false,
        onMove: ((Offset) -> Void)? = nil,
        onMinimize: (() -> Void)? = nil,
        onMaximize: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.isFocused = isFocused
        self.isMaximized = isMaximized
        self.isFullscreen = isFullscreen
        self.onMove = onMove
        self.onMinimize = onMinimize
        self.onMaximize = onMaximize
        self.onClose = onClose
        self.onDoubleTap = onDoubleTap
    }

    override func createState() -> State<StatefulWidget> {
        return _WindowTitleBarState()
    }
}

// MARK: - _WindowTitleBarState

class _WindowTitleBarState: State<StatefulWidget> {

    /// Last pointer position during an active drag (nil when not dragging).
    private var lastPointerPos: Offset? = nil

    /// Time of the last pointer-down on the title bar — used to detect a
    /// double-click (two clicks within `kDoubleTapThreshold` seconds).
    private var lastDownTime: TimeInterval = 0
    private static let kDoubleTapThreshold: TimeInterval = 0.4

    private var w: WindowTitleBar { widget as! WindowTitleBar }

    // macOS traffic light colors (brand colors — not themed)
    private static let closeColor = Color(0xFFFF5F57)       // red
    private static let closeHover = Color(0xFFFF3B30)
    private static let minimizeColor = Color(0xFFFFBD2E)    // yellow
    private static let minimizeHover = Color(0xFFFFA500)
    private static let maximizeColor = Color(0xFF28C840)    // green
    private static let maximizeHover = Color(0xFF00B300)
    /// Dimmed when unfocused — themed (dark chrome dims to white, light
    /// chrome dims to black).
    private static var inactiveColor: Color { shellTheme.trafficLightInactive }

    override func build(_ context: any BuildContext) -> Widget {
        let bgColor = w.isFocused
            ? shellTheme.titleBarActive
            : shellTheme.titleBarInactive

        return Listener(
            onPointerDown: { [self] event in
                lastPointerPos = event.position
                let now = Date.timeIntervalSinceReferenceDate
                if now - lastDownTime < _WindowTitleBarState.kDoubleTapThreshold {
                    w.onDoubleTap?()
                    lastDownTime = 0  // Reset so a triple-click doesn't fire again.
                } else {
                    lastDownTime = now
                }
            },
            onPointerMove: { [self] event in
                guard let last = lastPointerPos else { return }
                let delta = Offset(
                    event.position.dx - last.dx,
                    event.position.dy - last.dy
                )
                lastPointerPos = event.position
                w.onMove?(delta)
            },
            onPointerUp: { [self] _ in
                lastPointerPos = nil
            },
            onPointerHover: { _ in
                DesktopCursor.setShape(.default)
            },
            behavior: .opaque,
            child: SizedBox(
                height: DesktopTheme.kTitleBarHeight,
                child: ColoredBox(
                    color: bgColor,
                    child: Row(
                        children: [
                            // Traffic light buttons (left side)
                            SizedBox(width: 14),
                            _trafficLightButton(
                                color: w.isFocused ? _WindowTitleBarState.closeColor : _WindowTitleBarState.inactiveColor,
                                hoverColor: _WindowTitleBarState.closeHover,
                                onTap: w.onClose
                            ),
                            SizedBox(width: 8),
                            _trafficLightButton(
                                color: w.isFocused ? _WindowTitleBarState.minimizeColor : _WindowTitleBarState.inactiveColor,
                                hoverColor: _WindowTitleBarState.minimizeHover,
                                onTap: w.onMinimize
                            ),
                            SizedBox(width: 8),
                            _trafficLightButton(
                                color: w.isFocused ? _WindowTitleBarState.maximizeColor : _WindowTitleBarState.inactiveColor,
                                hoverColor: _WindowTitleBarState.maximizeHover,
                                onTap: w.onMaximize
                            ),

                            // Centered title
                            Expanded(
                                child: Center(
                                    child: Text(
                                        w.title,
                                        style: TextStyle(
                                            color: w.isFocused
                                                ? shellTheme.titleTextActive
                                                : shellTheme.titleTextInactive,
                                            fontSize: 13,
                                            fontWeight: .w500
                                        )
                                    )
                                )
                            ),

                            // Balance the left buttons so title is truly centered
                            SizedBox(width: 14 + 12 * 3 + 8 * 2),
                        ]
                    )
                )
            )
        )
    }

    /// macOS-style colored circle button.
    private func _trafficLightButton(
        color: Color,
        hoverColor: Color,
        onTap: (() -> Void)?
    ) -> Widget {
        return SizedBox(
            width: 12,
            height: 12,
            child: HoverButton(
                builder: { context, states in
                    let c: Color
                    if states.isPressed {
                        c = hoverColor
                    } else if states.isHovered {
                        c = hoverColor
                    } else {
                        c = color
                    }
                    return ClipOval(
                        child: ColoredBox(
                            color: c,
                            child: SizedBox(width: 12, height: 12)
                        )
                    )
                },
                onPressed: onTap
            )
        )
    }
}
