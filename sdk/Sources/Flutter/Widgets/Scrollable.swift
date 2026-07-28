// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Scrollable widget — the core widget connecting gestures to scroll position
/// to viewport.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scrollable.dart`

import FlutterSwiftBridge
import Foundation

// MARK: - ViewportBuilder

/// Signature used by `Scrollable` to build the viewport through which the
/// scrollable content is displayed.
///
/// **Dart Source:** `scrollable.dart:24`
public typealias ViewportBuilder = (any BuildContext, ViewportOffset) -> Widget

// MARK: - Scrollable

/// A widget that scrolls.
///
/// `Scrollable` implements the interaction model for a scrollable widget,
/// including gesture recognition, but does not have an opinion about how the
/// viewport, which actually displays the children, is constructed.
///
/// It's rare to construct a `Scrollable` directly. Instead, consider `ListView`
/// or `GridView`, which combine scrolling, viewporting, and a layout model.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scrollable.dart:85-282`
///
/// DIFFERENCE FROM DART: Simplified. Dart's `Scrollable` has a complex
/// `ScrollActivity` state machine, `ScrollContext` interface, and notification
/// dispatching. This version directly manages the drag offset and delegates
/// to `ScrollPosition`.
/// REASON: Focus on getting functional scrolling; activity system can be added later.
public class Scrollable: StatefulWidget {

    /// The axis along which the scroll view scrolls.
    ///
    /// **Dart Source:** `scrollable.dart:133`
    public let axisDirection: AxisDirection

    /// The controller for this scrollable widget.
    ///
    /// **Dart Source:** `scrollable.dart:129`
    public let controller: ScrollController?

    /// How the scroll view should respond to user input.
    ///
    /// **Dart Source:** `scrollable.dart:131`
    public let physics: ScrollPhysics?

    /// Builds the viewport through which the scrollable content is displayed.
    ///
    /// **Dart Source:** `scrollable.dart:135`
    public let viewportBuilder: ViewportBuilder

    /// Creates a widget that scrolls.
    ///
    /// **Dart Source:** `scrollable.dart:98-115`
    public init(
        key: (any Key)? = nil,
        axisDirection: AxisDirection = .down,
        controller: ScrollController? = nil,
        physics: ScrollPhysics? = nil,
        viewportBuilder: @escaping ViewportBuilder
    ) {
        self.axisDirection = axisDirection
        self.controller = controller
        self.physics = physics
        self.viewportBuilder = viewportBuilder
        super.init(key: key)
    }

    /// The axis along which scrolling occurs.
    public var axis: Axis {
        axisDirectionToAxis(axisDirection)
    }

    /// **Dart Source:** `scrollable.dart:138`
    public override func createState() -> State<StatefulWidget> {
        return ScrollableState()
    }
}

// MARK: - ScrollableState

/// State for a `Scrollable` widget.
///
/// Manages the `ScrollPosition`, sets up gesture recognition, and builds the
/// viewport with the scroll position as the `ViewportOffset`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scrollable.dart:354-835`
///
/// DIFFERENCE FROM DART: Simplified significantly. Dart's `ScrollableState`
/// implements `ScrollContext`, manages `ScrollActivity` state machines, and
/// handles restorable state. This version provides basic drag and scroll
/// wheel handling.
/// REASON: Focus on functional scrolling first.
public class ScrollableState: State<StatefulWidget>, TickerProvider {

    /// The scroll position for this scrollable.
    ///
    /// **Dart Source:** `scrollable.dart:404`
    public var position: ScrollPosition!

    /// The effective `ScrollPhysics` used by this scrollable.
    private var _physics: ScrollPhysics!

    /// The effective `ScrollController`.
    private var _controller: ScrollController?

    /// Whether the state has been initialized.
    private var _didInit = false

    // MARK: - TickerProvider

    /// Creates a ticker for animations.
    ///
    /// **Dart Source:** (via SingleTickerProviderStateMixin or similar)
    public func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    // MARK: - Lifecycle

    /// **Dart Source:** `scrollable.dart:375-400`
    public override func initState() {
        super.initState()
        let scrollable = widget as! Scrollable
        let resolvedPhysics = scrollable.physics ?? ClampingScrollPhysics()
        _physics = resolvedPhysics
        _controller = scrollable.controller ?? ScrollController(
            initialScrollOffset: 0.0
        )
        _createPosition()
        _didInit = true
    }

    /// Creates and attaches the scroll position.
    private func _createPosition() {
        let scrollable = widget as! Scrollable
        position = _controller!.createScrollPosition(
            physics: _physics
        )
        position._axisDirection = scrollable.axisDirection
        _controller!.attach(position)
    }

    /// **Dart Source:** `scrollable.dart:462-480`
    public override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let scrollable = widget as! Scrollable
        let oldScrollable = oldWidget as! Scrollable

        // Update physics if changed
        let resolvedPhysics = scrollable.physics ?? ClampingScrollPhysics()
        _physics = resolvedPhysics

        // Update controller if changed
        if scrollable.controller !== oldScrollable.controller {
            let oldController = _controller
            _controller = scrollable.controller ?? ScrollController()
            // Detach from old, attach to new
            if let old = oldController {
                old.detach(position)
            }
            _controller!.attach(position)
        }

        // Update axis direction
        position._axisDirection = scrollable.axisDirection
    }

    /// **Dart Source:** `scrollable.dart:498-510`
    public override func dispose() {
        _controller?.detach(position)
        super.dispose()
    }

    // MARK: - Drag State

    /// Whether a drag is currently in progress.
    private var _isDragging = false

    /// The last drag update offset, used for velocity estimation.
    private var _lastDragOffset: Double = 0.0

    /// The timestamp of the last drag update.
    private var _lastDragTime: Date?

    /// Estimated velocity from the drag.
    private var _estimatedVelocity: Double = 0.0

    // MARK: - Gesture Handling

    /// Handles pointer down events (begins potential drag).
    ///
    /// **Dart Source:** `scrollable.dart:615-640` (via _handleDragDown)
    private func _handleDragStart(_ details: DragStartDetails) {
        let scrollable = widget as! Scrollable
        _isDragging = true
        _lastDragOffset = scrollable.axis == .vertical
            ? details.globalPosition.dy
            : details.globalPosition.dx
        _lastDragTime = Date()
        _estimatedVelocity = 0.0
        position.beginDrag()
    }

    /// Handles drag update events.
    ///
    /// **Dart Source:** `scrollable.dart:648-668` (via _handleDragUpdate)
    private func _handleDragUpdate(_ details: DragUpdateDetails) {
        guard _isDragging else { return }
        let scrollable = widget as! Scrollable
        let currentOffset: Double
        if scrollable.axis == .vertical {
            currentOffset = details.globalPosition.dy
        } else {
            currentOffset = details.globalPosition.dx
        }
        let delta = currentOffset - _lastDragOffset

        // Estimate velocity
        let now = Date()
        if let lastTime = _lastDragTime {
            let dt = now.timeIntervalSince(lastTime)
            if dt > 0 {
                _estimatedVelocity = delta / dt
            }
        }
        _lastDragOffset = currentOffset
        _lastDragTime = now

        // Apply the delta to scroll position
        // Delta is positive when moving down, but scroll offset increases when
        // content moves up. So we negate for the default axis direction.
        let isReversed = scrollable.axisDirection == .up || scrollable.axisDirection == .left
        let scrollDelta = isReversed ? delta : -delta
        position.applyUserOffset(scrollDelta)
    }

    /// Handles drag end events.
    ///
    /// **Dart Source:** `scrollable.dart:683-705` (via _handleDragEnd)
    private func _handleDragEnd(_ details: DragEndDetails) {
        guard _isDragging else { return }
        _isDragging = false
        let scrollable = widget as! Scrollable
        let velocity: Double
        if scrollable.axis == .vertical {
            velocity = details.velocity.pixelsPerSecond.dy
        } else {
            velocity = details.velocity.pixelsPerSecond.dx
        }
        let isReversed = scrollable.axisDirection == .up || scrollable.axisDirection == .left
        position.endDrag(isReversed ? velocity : -velocity)
    }

    /// Handles pointer signal events (e.g., mouse scroll wheel).
    ///
    /// **Dart Source:** `scrollable.dart:738-790`
    private func _handlePointerSignal(_ event: PointerSignalEvent) {
        guard let scrollEvent = event as? PointerScrollEvent else { return }
        let scrollable = widget as! Scrollable
        let delta: Double
        if scrollable.axis == .vertical {
            delta = scrollEvent.scrollDelta.dy
        } else {
            delta = scrollEvent.scrollDelta.dx
        }
        if delta == 0.0 { return }
        position.pointerScroll(delta)
    }

    // MARK: - Build

    /// **Dart Source:** `scrollable.dart:800-835`
    public override func build(_ context: any BuildContext) -> Widget {
        let scrollable = widget as! Scrollable
        let viewport = scrollable.viewportBuilder(context, position)

        // Wrap the viewport in a Listener to handle pointer signal events
        // (e.g., mouse scroll wheel), and set up drag gesture handling via
        // appropriate drag gesture recognizer callbacks.
        if scrollable.axis == .vertical {
            return _VerticalScrollListener(
                onDragStart: _handleDragStart,
                onDragUpdate: _handleDragUpdate,
                onDragEnd: _handleDragEnd,
                onPointerSignal: _handlePointerSignal,
                child: viewport
            )
        } else {
            return _HorizontalScrollListener(
                onDragStart: _handleDragStart,
                onDragUpdate: _handleDragUpdate,
                onDragEnd: _handleDragEnd,
                onPointerSignal: _handlePointerSignal,
                child: viewport
            )
        }
    }
}

// MARK: - Scroll Listener Widgets

/// A widget that wraps its child with vertical drag detection and pointer signal
/// handling for scrolling.
///
/// DIFFERENCE FROM DART: In Dart, `Scrollable` uses `RawGestureDetector` with
/// gesture recognizers. Since `GestureDetector` may not be fully ported, this
/// uses a `Listener` widget to capture pointer events and implements simplified
/// drag tracking inline.
/// REASON: Avoids dependency on GestureDetector widget infrastructure.
private class _VerticalScrollListener: StatefulWidget {
    let onDragStart: (DragStartDetails) -> Void
    let onDragUpdate: (DragUpdateDetails) -> Void
    let onDragEnd: (DragEndDetails) -> Void
    let onPointerSignal: (PointerSignalEvent) -> Void
    let child: Widget

    init(
        key: (any Key)? = nil,
        onDragStart: @escaping (DragStartDetails) -> Void,
        onDragUpdate: @escaping (DragUpdateDetails) -> Void,
        onDragEnd: @escaping (DragEndDetails) -> Void,
        onPointerSignal: @escaping (PointerSignalEvent) -> Void,
        child: Widget
    ) {
        self.onDragStart = onDragStart
        self.onDragUpdate = onDragUpdate
        self.onDragEnd = onDragEnd
        self.onPointerSignal = onPointerSignal
        self.child = child
        super.init(key: key)
    }

    override func createState() -> State<StatefulWidget> {
        return _VerticalScrollListenerState()
    }
}

private class _VerticalScrollListenerState: State<StatefulWidget> {
    private var _isDown = false
    private var _startPosition: Offset = .zero

    override func build(_ context: any BuildContext) -> Widget {
        let w = widget as! _VerticalScrollListener
        return Listener(
            onPointerDown: { [weak self] event in
                guard let self = self else { return }
                self._isDown = true
                self._startPosition = event.position
                w.onDragStart(DragStartDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition
                ))
            },
            onPointerMove: { [weak self] event in
                guard let self = self, self._isDown else { return }
                w.onDragUpdate(DragUpdateDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                    delta: event.delta
                ))
            },
            onPointerUp: { [weak self] event in
                guard let self = self, self._isDown else { return }
                self._isDown = false
                w.onDragEnd(DragEndDetails(
                    velocity: .zero
                ))
            },
            onPointerCancel: { [weak self] _ in
                guard let self = self else { return }
                self._isDown = false
            },
            onPointerSignal: { event in
                w.onPointerSignal(event)
            },
            behavior: .translucent,
            child: w.child
        )
    }
}

/// A widget that wraps its child with horizontal drag detection and pointer signal
/// handling for scrolling.
private class _HorizontalScrollListener: StatefulWidget {
    let onDragStart: (DragStartDetails) -> Void
    let onDragUpdate: (DragUpdateDetails) -> Void
    let onDragEnd: (DragEndDetails) -> Void
    let onPointerSignal: (PointerSignalEvent) -> Void
    let child: Widget

    init(
        key: (any Key)? = nil,
        onDragStart: @escaping (DragStartDetails) -> Void,
        onDragUpdate: @escaping (DragUpdateDetails) -> Void,
        onDragEnd: @escaping (DragEndDetails) -> Void,
        onPointerSignal: @escaping (PointerSignalEvent) -> Void,
        child: Widget
    ) {
        self.onDragStart = onDragStart
        self.onDragUpdate = onDragUpdate
        self.onDragEnd = onDragEnd
        self.onPointerSignal = onPointerSignal
        self.child = child
        super.init(key: key)
    }

    override func createState() -> State<StatefulWidget> {
        return _HorizontalScrollListenerState()
    }
}

private class _HorizontalScrollListenerState: State<StatefulWidget> {
    private var _isDown = false
    private var _startPosition: Offset = .zero

    override func build(_ context: any BuildContext) -> Widget {
        let w = widget as! _HorizontalScrollListener
        return Listener(
            onPointerDown: { [weak self] event in
                guard let self = self else { return }
                self._isDown = true
                self._startPosition = event.position
                w.onDragStart(DragStartDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition
                ))
            },
            onPointerMove: { [weak self] event in
                guard let self = self, self._isDown else { return }
                w.onDragUpdate(DragUpdateDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                    delta: event.delta
                ))
            },
            onPointerUp: { [weak self] event in
                guard let self = self, self._isDown else { return }
                self._isDown = false
                w.onDragEnd(DragEndDetails(
                    velocity: .zero
                ))
            },
            onPointerCancel: { [weak self] _ in
                guard let self = self else { return }
                self._isDown = false
            },
            onPointerSignal: { event in
                w.onPointerSignal(event)
            },
            behavior: .translucent,
            child: w.child
        )
    }
}
