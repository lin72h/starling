// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// ScrollController, ScrollPosition, and related types for managing scroll state.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_controller.dart`
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_position.dart`
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_position_with_single_context.dart`

import FlutterSwiftBridge

// MARK: - ScrollPosition

/// Determines which portion of the content is visible in a scroll view.
///
/// The `pixels` value determines the scroll offset that the scroll view uses to
/// select which part of its content to display. As the user scrolls the viewport,
/// this value changes, which changes the content that is displayed.
///
/// `ScrollPosition` extends `ViewportOffset` and adds scroll-specific
/// semantics such as scroll extents and physics.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_position.dart`
///
/// DIFFERENCE FROM DART: This is a simplified version combining `ScrollPosition`
/// and `ScrollPositionWithSingleContext`. In Dart, `ScrollPosition` is abstract
/// and `ScrollPositionWithSingleContext` is the concrete implementation.
/// REASON: The full Dart implementation has complex activity-based state machines;
/// this simplified version provides functional scrolling.
public class ScrollPosition: ViewportOffset, ScrollMetrics {

    /// Creates a scroll position.
    ///
    /// **Dart Source:** `scroll_position.dart:75-93`
    public init(
        physics: ScrollPhysics = ScrollPhysics(),
        initialPixels: Double = 0.0,
        keepScrollOffset: Bool = true,
        debugLabel: String? = nil
    ) {
        self._physics = physics
        self._pixels = initialPixels
        self._hasPixels = true
        self.keepScrollOffset = keepScrollOffset
        self.debugLabel = debugLabel
        super.init()
    }

    /// The physics object to use for this scroll position.
    ///
    /// **Dart Source:** `scroll_position.dart:102`
    public var physics: ScrollPhysics { _physics }
    private let _physics: ScrollPhysics

    /// Whether to save and restore the scroll offset in the `PageStorage`.
    ///
    /// **Dart Source:** `scroll_position.dart:98`
    public let keepScrollOffset: Bool

    /// A label that is used in the `description` property to indicate the purpose
    /// of this scroll position.
    ///
    /// **Dart Source:** `scroll_position.dart:100`
    public let debugLabel: String?

    // MARK: - Scroll Extents

    /// The minimum in-range value for `pixels`.
    ///
    /// The actual `pixels` value might be `outOfRange`.
    ///
    /// **Dart Source:** `scroll_position.dart:120`
    public var minScrollExtent: Double {
        _minScrollExtent
    }
    private var _minScrollExtent: Double = 0.0

    /// The maximum in-range value for `pixels`.
    ///
    /// The actual `pixels` value might be `outOfRange`.
    ///
    /// **Dart Source:** `scroll_position.dart:126`
    public var maxScrollExtent: Double {
        _maxScrollExtent
    }
    private var _maxScrollExtent: Double = 0.0

    /// Whether the `minScrollExtent` and `maxScrollExtent` properties are available.
    ///
    /// **Dart Source:** `scroll_position.dart:135`
    public var hasContentDimensions: Bool { _hasContentDimensions }
    private var _hasContentDimensions: Bool = false

    // MARK: - Pixels

    /// The current scroll offset, in logical pixels along the `axisDirection`.
    ///
    /// **Dart Source:** `scroll_position.dart:142-143`
    public override var pixels: Double {
        _pixels
    }
    private var _pixels: Double

    /// **Dart Source:** `scroll_position.dart:146`
    public override var hasPixels: Bool { _hasPixels }
    private var _hasPixels: Bool

    // MARK: - Viewport Dimension

    /// The extent of the viewport along the `axisDirection`.
    ///
    /// **Dart Source:** `scroll_position.dart:155`
    public var viewportDimension: Double {
        _viewportDimension
    }
    private var _viewportDimension: Double = 0.0

    /// Whether the `viewportDimension` property is available.
    ///
    /// **Dart Source:** `scroll_position.dart:161`
    public var hasViewportDimension: Bool { _hasViewportDimension }
    private var _hasViewportDimension: Bool = false

    // MARK: - ScrollMetrics conformance

    /// The direction in which the scroll view scrolls.
    ///
    /// **Dart Source:** `scroll_position.dart:108`
    public var axisDirection: AxisDirection { _axisDirection }
    internal var _axisDirection: AxisDirection = .down

    /// The device pixel ratio.
    ///
    /// **Dart Source:** `scroll_position.dart:112`
    public var devicePixelRatio: Double { _devicePixelRatio }
    internal var _devicePixelRatio: Double = 1.0

    // MARK: - User Scroll Direction

    /// The direction the user is scrolling.
    ///
    /// **Dart Source:** `scroll_position.dart:250-256`
    public override var userScrollDirection: ScrollDirection { _userScrollDirection }
    private var _userScrollDirection: ScrollDirection = .idle

    /// Updates the scroll direction the user is scrolling in.
    ///
    /// **Dart Source:** `scroll_position.dart:258-266`
    internal func updateUserScrollDirection(_ value: ScrollDirection) {
        if _userScrollDirection == value { return }
        _userScrollDirection = value
        // In Flutter this would dispatch a UserScrollNotification
    }

    // MARK: - Allow Implicit Scrolling

    /// **Dart Source:** `scroll_position.dart:270`
    public override var allowImplicitScrolling: Bool {
        _physics.allowImplicitScrolling
    }

    // MARK: - setPixels

    /// Update the scroll position. [jumpTo] and [animateTo] are the
    /// recommended ways to change the scroll position.
    ///
    /// Returns the overscroll, if any.
    ///
    /// **Dart Source:** `scroll_position_with_single_context.dart:160-180`
    @discardableResult
    public func setPixels(_ newPixels: Double) -> Double {
        assert(hasPixels)
        assert(newPixels.isFinite, "Attempted to set pixels to \(newPixels)")
        if newPixels != pixels {
            let overscroll = _physics.applyBoundaryConditions(self, newPixels)
            assert(overscroll.isFinite, "ScrollPhysics.applyBoundaryConditions returned \(overscroll)")
            let oldPixels = _pixels
            _pixels = newPixels - overscroll
            if _pixels != oldPixels {
                notifyListeners()
            }
            if overscroll != 0.0 {
                // In full Flutter this dispatches an OverscrollNotification
                return overscroll
            }
        }
        return 0.0
    }

    /// Updates pixels without bounds checking or notification.
    ///
    /// Used by `correctBy` during layout.
    ///
    /// **Dart Source:** `scroll_position.dart:168-176`
    internal func correctPixels(_ value: Double) {
        _pixels = value
    }

    // MARK: - ViewportOffset overrides

    /// Apply a layout-time correction to the scroll offset.
    ///
    /// **Dart Source:** `scroll_position.dart:178-183`
    public override func correctBy(_ correction: Double) {
        assert(hasPixels, "correctBy called before pixels was set")
        _pixels += correction
        // Do NOT call notifyListeners — this is called during layout.
    }

    /// **Dart Source:** `scroll_position.dart:207-220`
    public override func applyViewportDimension(_ viewportDimension: Double) -> Bool {
        if _viewportDimension != viewportDimension {
            _viewportDimension = viewportDimension
            _hasViewportDimension = true
            return false
        }
        _hasViewportDimension = true
        return true
    }

    /// **Dart Source:** `scroll_position.dart:223-247`
    public override func applyContentDimensions(
        _ minScrollExtent: Double,
        _ maxScrollExtent: Double
    ) -> Bool {
        assert(minScrollExtent <= maxScrollExtent || maxScrollExtent.isNaN || minScrollExtent.isNaN)
        let changed = _minScrollExtent != minScrollExtent || _maxScrollExtent != maxScrollExtent
        _minScrollExtent = minScrollExtent
        _maxScrollExtent = maxScrollExtent
        _hasContentDimensions = true

        if changed {
            // Clamp pixels into the valid range.
            let clampedPixels = clampDouble(_pixels, minScrollExtent, maxScrollExtent)
            if clampedPixels != _pixels {
                correctPixels(clampedPixels)
                return false
            }
        }
        return true
    }

    // MARK: - jumpTo

    /// Jumps the scroll position from its current value to the given value,
    /// without animation, and without checking if the new value is in range.
    ///
    /// Any active animation is canceled. If the user is currently scrolling, that
    /// action is canceled.
    ///
    /// **Dart Source:** `scroll_position_with_single_context.dart:106-114`
    public override func jumpTo(_ value: Double) {
        if _pixels != value {
            let oldPixels = _pixels
            _pixels = value
            _ = oldPixels  // In full Flutter, this would be used for notification
            notifyListeners()
        }
    }

    // MARK: - animateTo

    /// Animates the position from its current value to the given value.
    ///
    /// **Dart Source:** `scroll_position_with_single_context.dart:85-104`
    public override func animateTo(
        _ to: Double,
        duration: Duration,
        curve: any Curve
    ) async {
        // For simplicity, jump immediately. A full implementation would use
        // AnimationController for smooth animation.
        jumpTo(to)
    }

    // MARK: - Drag handling

    /// Called when the user starts dragging.
    ///
    /// **Dart Source:** `scroll_position_with_single_context.dart:127-142`
    public func beginDrag() {
        // Cancel any active ballistic animation, etc.
    }

    /// Called when the user drags with the given delta.
    ///
    /// Returns the overscroll amount.
    ///
    /// **Dart Source:** (via DragScrollActivity)
    @discardableResult
    public func applyUserOffset(_ delta: Double) -> Double {
        updateUserScrollDirection(delta > 0 ? .forward : .reverse)
        let physicalDelta = _physics.applyPhysicsToUserOffset(self, delta)
        return setPixels(_pixels - physicalDelta)
    }

    /// Called when a pointer scroll (mouse wheel) event occurs.
    ///
    /// **Dart Source:** `scroll_position.dart:507-523`
    public func pointerScroll(_ delta: Double) {
        if delta == 0.0 { return }
        let targetPixels = _pixels + delta
        let overscroll = _physics.applyBoundaryConditions(self, targetPixels)
        let oldPixels = _pixels
        _pixels = targetPixels - overscroll
        if _pixels != oldPixels {
            notifyListeners()
        }
    }

    /// Called when the user stops dragging.
    ///
    /// Starts a ballistic simulation if needed.
    ///
    /// **Dart Source:** `scroll_position_with_single_context.dart:144-162`
    public func endDrag(_ velocity: Double) {
        updateUserScrollDirection(.idle)
        // In full Flutter, this would start a ballistic simulation.
        // For now, just clamp to valid range.
        let clampedPixels = clampDouble(_pixels, _minScrollExtent, _maxScrollExtent)
        if clampedPixels != _pixels {
            jumpTo(clampedPixels)
        }
    }

    // MARK: - Description

    /// **Dart Source:** `scroll_position.dart:661-678`
    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        description.append("range: \(String(format: "%.1f", _minScrollExtent))..\(String(format: "%.1f", _maxScrollExtent))")
        description.append("viewport: \(String(format: "%.1f", _viewportDimension))")
    }
}

// MARK: - ScrollController

/// Controls a scrollable widget.
///
/// Scroll controllers are typically stored as member variables in `State` objects
/// and are reused in each `State.build`. A single scroll controller can be used
/// to control multiple scrollable widgets, but some operations, such as reading
/// the scroll offset, require the controller to be used with a single scrollable
/// widget.
///
/// A scroll controller creates a `ScrollPosition` to manage the state specific
/// to an individual `Scrollable` widget. To use a custom `ScrollPosition`
/// subclass, override `createScrollPosition`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_controller.dart:31-214`
public class ScrollController: ChangeNotifier {

    /// Creates a controller for a scrollable widget.
    ///
    /// The `initialScrollOffset` defaults to 0.0.
    ///
    /// **Dart Source:** `scroll_controller.dart:46-50`
    public init(
        initialScrollOffset: Double = 0.0,
        keepScrollOffset: Bool = true,
        debugLabel: String? = nil
    ) {
        self.initialScrollOffset = initialScrollOffset
        self.keepScrollOffset = keepScrollOffset
        self.debugLabel = debugLabel
        super.init()
    }

    /// The initial value to use for `pixels` when this controller is first
    /// attached to a `Scrollable`.
    ///
    /// **Dart Source:** `scroll_controller.dart:62`
    public let initialScrollOffset: Double

    /// Whether to save and restore the scroll offset.
    ///
    /// **Dart Source:** `scroll_controller.dart:65`
    public let keepScrollOffset: Bool

    /// A label for debugging purposes.
    ///
    /// **Dart Source:** `scroll_controller.dart:68`
    public let debugLabel: String?

    /// The currently attached positions.
    ///
    /// This should not be mutated directly. `ScrollPosition` objects should be
    /// added and removed using `attach` and `detach`.
    ///
    /// **Dart Source:** `scroll_controller.dart:78`
    public private(set) var positions: [ScrollPosition] = []

    /// Whether this controller is currently attached to a `Scrollable`.
    ///
    /// **Dart Source:** `scroll_controller.dart:87`
    public var hasClients: Bool { !positions.isEmpty }

    /// Returns the attached `ScrollPosition`, which must be unique.
    ///
    /// **Dart Source:** `scroll_controller.dart:95`
    public var position: ScrollPosition {
        assert(positions.count == 1, "ScrollController not attached to exactly one Scrollable. \(positions.count) attached.")
        return positions.first!
    }

    /// The current scroll offset of the scrollable widget.
    ///
    /// Requires the controller to be controlling exactly one scrollable widget.
    ///
    /// **Dart Source:** `scroll_controller.dart:104`
    public var offset: Double {
        position.pixels
    }

    // MARK: - Position Lifecycle

    /// Creates a `ScrollPosition` for use by a `Scrollable` widget.
    ///
    /// **Dart Source:** `scroll_controller.dart:118-127`
    public func createScrollPosition(
        physics: ScrollPhysics,
        oldPosition: ScrollPosition? = nil
    ) -> ScrollPosition {
        return ScrollPosition(
            physics: physics,
            initialPixels: initialScrollOffset,
            keepScrollOffset: keepScrollOffset,
            debugLabel: debugLabel
        )
    }

    /// Register the given position with this controller.
    ///
    /// **Dart Source:** `scroll_controller.dart:140-143`
    public func attach(_ position: ScrollPosition) {
        assert(!positions.contains(where: { $0 === position }),
            "ScrollPosition was already attached to this controller")
        positions.append(position)
        position.addListener(notifyListeners)
    }

    /// Unregister the given position with this controller.
    ///
    /// **Dart Source:** `scroll_controller.dart:150-154`
    public func detach(_ position: ScrollPosition) {
        assert(positions.contains(where: { $0 === position }),
            "ScrollPosition was not attached to this controller")
        position.removeListener(notifyListeners)
        positions.removeAll(where: { $0 === position })
    }

    // MARK: - Scroll Control

    /// Animates the position from its current value to the given value.
    ///
    /// **Dart Source:** `scroll_controller.dart:160-171`
    public func animateTo(
        _ offset: Double,
        duration: Duration,
        curve: any Curve
    ) {
        for position in positions {
            position.jumpTo(offset)
        }
    }

    /// Jumps the scroll position from its current value to the given value,
    /// without animation.
    ///
    /// **Dart Source:** `scroll_controller.dart:182-187`
    public func jumpTo(_ value: Double) {
        for position in positions {
            position.jumpTo(value)
        }
    }

    // MARK: - Dispose

    /// **Dart Source:** `scroll_controller.dart:198-201`
    public override func dispose() {
        for position in positions {
            position.removeListener(notifyListeners)
        }
        super.dispose()
    }

    // MARK: - Description

    /// **Dart Source:** `scroll_controller.dart:204-213`
    public var description: String {
        var desc: [String] = []
        if let debugLabel = debugLabel {
            desc.append(debugLabel)
        }
        desc.append("initialOffset: \(String(format: "%.1f", initialScrollOffset))")
        desc.append("\(positions.count) clients")
        return "\(objectRuntimeType(self, "ScrollController"))(\(desc.joined(separator: ", ")))"
    }
}
