// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - WindowResizeHandles

/// Overlay of 8 invisible hit regions (4 edges + 4 corners) that enable
/// drag-to-resize on a desktop window.
class WindowResizeHandles: StatefulWidget {

    let windowWidth: Double
    let windowHeight: Double
    let onResize: ((ResizeEdge, Offset) -> Void)?
    let onResizeDragStart: (() -> Void)?
    let onResizeDragEnd: (() -> Void)?

    init(
        windowWidth: Double,
        windowHeight: Double,
        onResize: ((ResizeEdge, Offset) -> Void)? = nil,
        onResizeDragStart: (() -> Void)? = nil,
        onResizeDragEnd: (() -> Void)? = nil
    ) {
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.onResize = onResize
        self.onResizeDragStart = onResizeDragStart
        self.onResizeDragEnd = onResizeDragEnd
    }

    override func createState() -> State<StatefulWidget> {
        return _WindowResizeHandlesState()
    }
}

// MARK: - _WindowResizeHandlesState

class _WindowResizeHandlesState: State<StatefulWidget> {

    /// Last pointer position during an active resize drag.
    private var lastPointerPos: Offset? = nil

    private var w: WindowResizeHandles { widget as! WindowResizeHandles }

    override func build(_ context: any BuildContext) -> Widget {
        let edgeThickness: Double = 6.0
        let cornerSize: Double = 12.0
        let ww = w.windowWidth
        let wh = w.windowHeight

        return Stack(
            children: [
                // Top edge
                _edgeHandle(
                    edge: .top,
                    left: cornerSize, top: 0,
                    width: ww - 2 * cornerSize, height: edgeThickness
                ),
                // Bottom edge
                _edgeHandle(
                    edge: .bottom,
                    left: cornerSize, top: wh - edgeThickness,
                    width: ww - 2 * cornerSize, height: edgeThickness
                ),
                // Left edge
                _edgeHandle(
                    edge: .left,
                    left: 0, top: cornerSize,
                    width: edgeThickness, height: wh - 2 * cornerSize
                ),
                // Right edge
                _edgeHandle(
                    edge: .right,
                    left: ww - edgeThickness, top: cornerSize,
                    width: edgeThickness, height: wh - 2 * cornerSize
                ),
                // Top-left corner
                _edgeHandle(
                    edge: .topLeft,
                    left: 0, top: 0,
                    width: cornerSize, height: cornerSize
                ),
                // Top-right corner
                _edgeHandle(
                    edge: .topRight,
                    left: ww - cornerSize, top: 0,
                    width: cornerSize, height: cornerSize
                ),
                // Bottom-left corner
                _edgeHandle(
                    edge: .bottomLeft,
                    left: 0, top: wh - cornerSize,
                    width: cornerSize, height: cornerSize
                ),
                // Bottom-right corner
                _edgeHandle(
                    edge: .bottomRight,
                    left: ww - cornerSize, top: wh - cornerSize,
                    width: cornerSize, height: cornerSize
                ),
            ]
        )
    }

    private func _edgeHandle(
        edge: ResizeEdge,
        left: Double,
        top: Double,
        width: Double,
        height: Double
    ) -> Widget {
        let cursorShape: CursorShape
        switch edge {
        case .top, .bottom:
            cursorShape = .resizeNS
        case .left, .right:
            cursorShape = .resizeEW
        case .topLeft, .bottomRight:
            cursorShape = .resizeNWSE
        case .topRight, .bottomLeft:
            cursorShape = .resizeNESW
        }

        return Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: Listener(
                onPointerDown: { [self] event in
                    lastPointerPos = event.position
                    w.onResizeDragStart?()
                },
                onPointerMove: { [self] event in
                    guard let last = lastPointerPos else { return }
                    let delta = Offset(
                        event.position.dx - last.dx,
                        event.position.dy - last.dy
                    )
                    lastPointerPos = event.position
                    w.onResize?(edge, delta)
                },
                onPointerUp: { [self] _ in
                    lastPointerPos = nil
                    w.onResizeDragEnd?()
                },
                onPointerHover: { _ in
                    DesktopCursor.setShape(cursorShape)
                },
                behavior: .opaque,
                child: ColoredBox(
                    color: Color(0x00000000),
                    child: SizedBox(expand: ())
                )
            )
        )
    }
}
