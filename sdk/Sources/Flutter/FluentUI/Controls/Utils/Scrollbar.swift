// Ported from: fluent_ui/lib/src/controls/utils/scrollbar.dart (simplified)
//
// A Fluent UI styled scrollbar that indicates scroll position.
// Wraps a scrollable child and paints a scrollbar thumb overlay.

import FlutterSwiftBridge

// MARK: - FluentScrollbar

/// A Fluent UI styled scrollbar widget.
///
/// Wraps a scrollable child and overlays a scrollbar thumb that indicates
/// the current scroll position. The scrollbar appears on hover and fades
/// out after scrolling stops.
///
/// Usage:
/// ```swift
/// FluentScrollbar(
///     controller: scrollController,
///     child: ListView(
///         controller: scrollController,
///         children: [...]
///     )
/// )
/// ```
public class FluentScrollbar: StatefulWidget {
    /// The scroll controller associated with the scrollable child.
    public let controller: ScrollController?

    /// The child widget (typically a scrollable).
    public let child: Widget

    /// The axis along which the scrollbar operates.
    public let scrollDirection: Axis

    /// The thickness of the scrollbar thumb.
    public let thickness: Double

    /// The radius of the scrollbar thumb corners.
    public let radius: Double

    /// Whether the scrollbar is always visible.
    public let isAlwaysShown: Bool

    /// Creates a Fluent UI scrollbar.
    public init(
        key: (any Key)? = nil,
        controller: ScrollController? = nil,
        child: Widget,
        scrollDirection: Axis = .vertical,
        thickness: Double = 6.0,
        radius: Double = 3.0,
        isAlwaysShown: Bool = false
    ) {
        self.controller = controller
        self.child = child
        self.scrollDirection = scrollDirection
        self.thickness = thickness
        self.radius = radius
        self.isAlwaysShown = isAlwaysShown
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _FluentScrollbarState()
    }
}

// MARK: - _FluentScrollbarState

class _FluentScrollbarState: State<StatefulWidget> {
    private var scrollbar: FluentScrollbar {
        return widget as! FluentScrollbar
    }

    /// Tracks whether the mouse is hovering over the scrollbar area.
    private var _isHovered: Bool = false

    /// The current scroll metrics for painting the thumb.
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
        let oldScrollbar = oldWidget as! FluentScrollbar
        if scrollbar.controller !== oldScrollbar.controller {
            _detachListener(oldScrollbar.controller)
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
        // Initialize from current position
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
        let theme = FluentTheme.of(context)

        let showScrollbar = scrollbar.isAlwaysShown || _isHovered || _scrollExtent > 0

        // Only show if there's content to scroll
        guard _scrollExtent > 0 && showScrollbar else {
            return scrollbar.child
        }

        let thumbPainter = _ScrollbarPainter(
            scrollOffset: _scrollOffset,
            scrollExtent: _scrollExtent,
            viewportDimension: _viewportDimension,
            scrollDirection: scrollbar.scrollDirection,
            thickness: _isHovered ? scrollbar.thickness * 1.5 : scrollbar.thickness,
            radius: scrollbar.radius,
            thumbColor: _isHovered
                ? theme.resources.controlStrongFillColorDefault
                : theme.resources.controlStrokeColorDefault
        )

        let scrollbarOverlay: Widget = CustomPaint(
            foregroundPainter: thumbPainter,
            child: scrollbar.child
        )

        return Listener(
            onPointerHover: { [weak self] _ in
                guard let self = self, !self._isHovered else { return }
                self.setState {
                    self._isHovered = true
                }
            },
            child: MouseRegion(
                onExit: { [weak self] _ in
                    guard let self = self, self._isHovered else { return }
                    self.setState {
                        self._isHovered = false
                    }
                },
                child: scrollbarOverlay
            )
        )
    }
}

// MARK: - _ScrollbarPainter

/// Custom painter that draws the scrollbar thumb.
class _ScrollbarPainter: CustomPainter {
    let scrollOffset: Double
    let scrollExtent: Double
    let viewportDimension: Double
    let scrollDirection: Axis
    let thickness: Double
    let radius: Double
    let thumbColor: Color

    init(
        scrollOffset: Double,
        scrollExtent: Double,
        viewportDimension: Double,
        scrollDirection: Axis,
        thickness: Double,
        radius: Double,
        thumbColor: Color
    ) {
        self.scrollOffset = scrollOffset
        self.scrollExtent = scrollExtent
        self.viewportDimension = viewportDimension
        self.scrollDirection = scrollDirection
        self.thickness = thickness
        self.radius = radius
        self.thumbColor = thumbColor
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let totalExtent = scrollExtent + viewportDimension
        guard totalExtent > 0 else { return }

        let trackLength: Double
        let crossAxisSize: Double

        if scrollDirection == .vertical {
            trackLength = size.height
            crossAxisSize = size.width
        } else {
            trackLength = size.width
            crossAxisSize = size.height
        }

        // Calculate thumb size (proportional to viewport/total ratio)
        let thumbFraction = viewportDimension / totalExtent
        let thumbLength = Swift.max(thumbFraction * trackLength, 30.0) // minimum 30px

        // Calculate thumb position
        let scrollFraction = scrollExtent > 0 ? scrollOffset / scrollExtent : 0.0
        let maxThumbOffset = trackLength - thumbLength
        let thumbOffset = scrollFraction * maxThumbOffset

        // Compute the thumb rect
        let thumbRect: Rect
        let margin: Double = 2.0

        if scrollDirection == .vertical {
            thumbRect = Rect.fromLTWH(
                crossAxisSize - thickness - margin,
                thumbOffset,
                thickness,
                thumbLength
            )
        } else {
            thumbRect = Rect.fromLTWH(
                thumbOffset,
                crossAxisSize - thickness - margin,
                thumbLength,
                thickness
            )
        }

        // Draw the thumb with rounded corners
        let paint = Paint()
        paint.color = thumbColor
        let rrect = RRect(
            left: thumbRect.left,
            top: thumbRect.top,
            right: thumbRect.right,
            bottom: thumbRect.bottom,
            tlRadiusX: radius, tlRadiusY: radius,
            trRadiusX: radius, trRadiusY: radius,
            brRadiusX: radius, brRadiusY: radius,
            blRadiusX: radius, blRadiusY: radius
        )
        canvas.drawRRect(rrect, paint)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _ScrollbarPainter else { return true }
        return scrollOffset != old.scrollOffset
            || scrollExtent != old.scrollExtent
            || viewportDimension != old.viewportDimension
            || thickness != old.thickness
            || thumbColor != old.thumbColor
    }
}
