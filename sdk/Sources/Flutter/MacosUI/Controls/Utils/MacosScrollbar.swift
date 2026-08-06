// MacosScrollbar — the macOS overlay scrollbar.
//
// AppKit's default is the *overlay* scrollbar: no track, a thin dark (or
// light) capsule floating over the content, inset from the edge, widening
// while the pointer is over it. The Fluent scrollbar this replaces drew a
// thicker square-ended thumb against the theme's control stroke colour, which
// reads as Windows next to a macOS list.

import FlutterSwiftBridge

// MARK: - Metrics

/// Resting thumb thickness.
public let kMacosScrollbarThickness: Double = 7

/// Thumb thickness while hovered — AppKit fattens the capsule rather than
/// revealing a track.
public let kMacosScrollbarThicknessHovered: Double = 11

/// Gap between the thumb and the viewport edge.
public let kMacosScrollbarMargin: Double = 2

/// Shortest the thumb is allowed to get on a very long list.
public let kMacosScrollbarMinLength: Double = 24

// MARK: - MacosScrollbar

/// Wraps a scrollable and paints a macOS overlay scrollbar over it.
///
/// The thumb is painted, not laid out, so it never steals width from the
/// content — which is the point of an overlay scrollbar.
public class MacosScrollbar: StatefulWidget {
    public let controller: ScrollController?
    public let child: Widget
    public let scrollDirection: Axis
    /// Keep the thumb visible even when the content is not being scrolled.
    public let isAlwaysShown: Bool

    public init(
        key: (any Key)? = nil,
        controller: ScrollController? = nil,
        scrollDirection: Axis = .vertical,
        isAlwaysShown: Bool = false,
        child: Widget
    ) {
        self.controller = controller
        self.child = child
        self.scrollDirection = scrollDirection
        self.isAlwaysShown = isAlwaysShown
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosScrollbarState()
    }
}

// MARK: - _MacosScrollbarState

class _MacosScrollbarState: State<StatefulWidget> {
    private var scrollbar: MacosScrollbar {
        return widget as! MacosScrollbar
    }

    private var _isHovered: Bool = false
    private var _scrollOffset: Double = 0.0
    private var _scrollExtent: Double = 0.0
    private var _viewportDimension: Double = 0.0
    private var _listener: VoidCallback?

    override func initState() {
        super.initState()
        _attachListener()
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let old = oldWidget as! MacosScrollbar
        if scrollbar.controller !== old.controller {
            _detachListener(old.controller)
            _attachListener()
        }
    }

    override func dispose() {
        _detachListener(scrollbar.controller)
        super.dispose()
    }

    private func _attachListener() {
        guard let controller = scrollbar.controller else { return }
        _listener = { [weak self] in
            self?._onScrollChanged()
        }
        controller.addListener(_listener!)
        if controller.hasClients {
            let pos = controller.position
            _scrollOffset = pos.pixels
            _scrollExtent = pos.maxScrollExtent
            _viewportDimension = pos.viewportDimension
        }
    }

    private func _detachListener(_ controller: ScrollController?) {
        if let listener = _listener, let controller = controller {
            controller.removeListener(listener)
        }
        _listener = nil
    }

    private func _onScrollChanged() {
        guard let controller = scrollbar.controller, controller.hasClients else { return }
        let pos = controller.position
        setState {
            self._scrollOffset = pos.pixels
            self._scrollExtent = pos.maxScrollExtent
            self._viewportDimension = pos.viewportDimension
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        // Nothing to scroll — an overlay scrollbar shows nothing at all, it
        // does not draw an empty track.
        guard _scrollExtent > 0 || scrollbar.isAlwaysShown else {
            return scrollbar.child
        }

        let brightness = MacosTheme.maybeOf(context)?.brightness ?? .light
        // AppKit's overlay thumb is a translucent neutral, darker on light
        // content and lighter on dark, and gains contrast while hovered.
        let thumbColor: Color
        if brightness == .dark {
            thumbColor = _isHovered ? Color(0xB3FFFFFF) : Color(0x80FFFFFF)
        } else {
            thumbColor = _isHovered ? Color(0xB3000000) : Color(0x80000000)
        }

        let thickness = _isHovered
            ? kMacosScrollbarThicknessHovered
            : kMacosScrollbarThickness

        let painter = _MacosScrollbarPainter(
            scrollOffset: _scrollOffset,
            scrollExtent: _scrollExtent,
            viewportDimension: _viewportDimension,
            scrollDirection: scrollbar.scrollDirection,
            thickness: thickness,
            thumbColor: thumbColor
        )

        // Hover via Listener.onPointerHover — MouseRegion's enter/exit do not
        // fire under the DRM embedder (see MacosMenu for the same note).
        return Listener(
            onPointerHover: { [weak self] _ in
                guard let self = self, !self._isHovered else { return }
                self.setState { self._isHovered = true }
            },
            behavior: .translucent,
            child: CustomPaint(
                foregroundPainter: painter,
                child: scrollbar.child
            )
        )
    }
}

// MARK: - _MacosScrollbarPainter

/// Paints the capsule thumb. Fully rounded ends — the radius is half the
/// thickness, which is what makes it a capsule rather than a rounded bar.
class _MacosScrollbarPainter: CustomPainter {
    let scrollOffset: Double
    let scrollExtent: Double
    let viewportDimension: Double
    let scrollDirection: Axis
    let thickness: Double
    let thumbColor: Color

    init(
        scrollOffset: Double,
        scrollExtent: Double,
        viewportDimension: Double,
        scrollDirection: Axis,
        thickness: Double,
        thumbColor: Color
    ) {
        self.scrollOffset = scrollOffset
        self.scrollExtent = scrollExtent
        self.viewportDimension = viewportDimension
        self.scrollDirection = scrollDirection
        self.thickness = thickness
        self.thumbColor = thumbColor
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let totalExtent = scrollExtent + viewportDimension
        guard totalExtent > 0, scrollExtent > 0 else { return }

        let trackLength = scrollDirection == .vertical ? size.height : size.width
        let crossAxisSize = scrollDirection == .vertical ? size.width : size.height

        let thumbFraction = viewportDimension / totalExtent
        let thumbLength = Swift.max(thumbFraction * trackLength,
                                    kMacosScrollbarMinLength)

        let scrollFraction = Swift.min(Swift.max(scrollOffset / scrollExtent, 0.0), 1.0)
        let maxThumbOffset = Swift.max(trackLength - thumbLength
                                        - kMacosScrollbarMargin * 2, 0.0)
        let thumbOffset = kMacosScrollbarMargin + scrollFraction * maxThumbOffset

        let thumbRect: Rect
        if scrollDirection == .vertical {
            thumbRect = Rect.fromLTWH(
                crossAxisSize - thickness - kMacosScrollbarMargin,
                thumbOffset,
                thickness,
                thumbLength
            )
        } else {
            thumbRect = Rect.fromLTWH(
                thumbOffset,
                crossAxisSize - thickness - kMacosScrollbarMargin,
                thumbLength,
                thickness
            )
        }

        let radius = thickness / 2
        let paint = Paint()
        paint.color = thumbColor
        canvas.drawRRect(
            RRect(
                left: thumbRect.left,
                top: thumbRect.top,
                right: thumbRect.right,
                bottom: thumbRect.bottom,
                tlRadiusX: radius, tlRadiusY: radius,
                trRadiusX: radius, trRadiusY: radius,
                brRadiusX: radius, brRadiusY: radius,
                blRadiusX: radius, blRadiusY: radius
            ),
            paint
        )
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _MacosScrollbarPainter else { return true }
        return scrollOffset != old.scrollOffset
            || scrollExtent != old.scrollExtent
            || viewportDimension != old.viewportDimension
            || thickness != old.thickness
            || thumbColor != old.thumbColor
    }
}
