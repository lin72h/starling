// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import FlutterSwiftBridge

// MARK: - ScrollDecelerationRate

/// The rate at which scroll momentum will be decelerated.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:33-42`
public enum ScrollDecelerationRate {
    /// Standard deceleration, aligned with mobile software expectations.
    case normal

    /// Increased deceleration, aligned with desktop software expectations.
    ///
    /// Appropriate for use with input devices more precise than touch screens,
    /// such as trackpads or mouse wheels.
    case fast
}

// MARK: - ScrollPhysics

/// Determines the physics of a `Scrollable` widget.
///
/// For example, determines how the `Scrollable` will behave when the user
/// reaches the maximum scroll extent or when the user stops scrolling.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:88-509`
open class ScrollPhysics {
    /// If non-nil, determines the default behavior for each method.
    ///
    /// **Dart Source:** `scroll_physics.dart:107`
    public let parent: ScrollPhysics?

    /// Creates an object with the default scroll physics.
    ///
    /// **Dart Source:** `scroll_physics.dart:90`
    public init(parent: ScrollPhysics? = nil) {
        self.parent = parent
    }

    /// If `parent` is nil then return ancestor, otherwise recursively build a
    /// ScrollPhysics that has `ancestor` as its parent.
    ///
    /// **Dart Source:** `scroll_physics.dart:127`
    public func buildParent(_ ancestor: ScrollPhysics?) -> ScrollPhysics? {
        return parent?.applyTo(ancestor) ?? ancestor
    }

    /// Combines this `ScrollPhysics` instance with the given physics.
    ///
    /// **Dart Source:** `scroll_physics.dart:186-188`
    open func applyTo(_ ancestor: ScrollPhysics?) -> ScrollPhysics {
        return ScrollPhysics(parent: buildParent(ancestor))
    }

    /// Used by `DragScrollActivity` and other user-driven activities to convert
    /// an offset in logical pixels as provided by the `DragUpdateDetails` into a
    /// delta to apply using `ScrollActivityDelegate.setPixels`.
    ///
    /// **Dart Source:** `scroll_physics.dart:204-206`
    open func applyPhysicsToUserOffset(_ position: ScrollMetrics, _ offset: Double) -> Double {
        return parent?.applyPhysicsToUserOffset(position, offset) ?? offset
    }

    /// Whether the scrollable should let the user adjust the scroll offset.
    ///
    /// By default, the user can manipulate the scroll offset if, and only if,
    /// there is actually content outside the viewport to reveal.
    ///
    /// **Dart Source:** `scroll_physics.dart:218-227`
    open func shouldAcceptUserOffset(_ position: ScrollMetrics) -> Bool {
        if !allowUserScrolling {
            return false
        }
        if parent == nil {
            return position.pixels != 0.0 || position.minScrollExtent != position.maxScrollExtent
        }
        return parent!.shouldAcceptUserOffset(position)
    }

    /// Provides a heuristic to determine if expensive frame-bound tasks should be
    /// deferred.
    ///
    /// **Dart Source:** `scroll_physics.dart:266-272`
    open func recommendDeferredLoading(_ velocity: Double, _ metrics: ScrollMetrics, _ context: any BuildContext) -> Bool {
        if parent == nil {
            let maxPhysicalPixels = View.of(context).physicalSize.longestSide
            return velocity.magnitude > maxPhysicalPixels
        }
        return parent!.recommendDeferredLoading(velocity, metrics, context)
    }

    /// Determines the overscroll by applying the boundary conditions.
    ///
    /// **Dart Source:** `scroll_physics.dart:308-310`
    open func applyBoundaryConditions(_ position: ScrollMetrics, _ value: Double) -> Double {
        return parent?.applyBoundaryConditions(position, value) ?? 0.0
    }

    /// Describes what the scroll position should be given new viewport dimensions.
    ///
    /// **Dart Source:** `scroll_physics.dart:356-371`
    open func adjustPositionForNewDimensions(
        oldPosition: ScrollMetrics,
        newPosition: ScrollMetrics,
        isScrolling: Bool,
        velocity: Double
    ) -> Double {
        if parent == nil {
            return newPosition.pixels
        }
        return parent!.adjustPositionForNewDimensions(
            oldPosition: oldPosition,
            newPosition: newPosition,
            isScrolling: isScrolling,
            velocity: velocity
        )
    }

    /// Returns a simulation for ballistic scrolling starting from the given
    /// position with the given velocity.
    ///
    /// **Dart Source:** `scroll_physics.dart:407-409`
    open func createBallisticSimulation(_ position: ScrollMetrics, _ velocity: Double) -> Simulation? {
        return parent?.createBallisticSimulation(position, velocity)
    }

    /// **Dart Source:** `scroll_physics.dart:411-415`
    private static let _kDefaultSpring = SpringDescription(
        mass: 0.5,
        stiffness: 100.0,
        ratio: 1.1
    )

    /// The spring to use for ballistic simulations.
    ///
    /// **Dart Source:** `scroll_physics.dart:418`
    open var spring: SpringDescription {
        return parent?.spring ?? ScrollPhysics._kDefaultSpring
    }

    /// The tolerance to use for ballistic simulations.
    ///
    /// **Dart Source:** `scroll_physics.dart:439-445`
    open func toleranceFor(_ metrics: ScrollMetrics) -> Tolerance {
        return parent?.toleranceFor(metrics) ??
            Tolerance(
                distance: 1.0 / metrics.devicePixelRatio,
                velocity: 1.0 / (0.050 * metrics.devicePixelRatio)
            )
    }

    /// The minimum distance an input pointer drag must have moved to be
    /// considered a scroll fling gesture.
    ///
    /// **Dart Source:** `scroll_physics.dart:457`
    open var minFlingDistance: Double {
        return parent?.minFlingDistance ?? kTouchSlop
    }

    /// The minimum velocity for an input pointer drag to be considered a
    /// scroll fling.
    ///
    /// **Dart Source:** `scroll_physics.dart:469`
    open var minFlingVelocity: Double {
        return parent?.minFlingVelocity ?? kMinFlingVelocity
    }

    /// Scroll fling velocity magnitudes will be clamped to this value.
    ///
    /// **Dart Source:** `scroll_physics.dart:472`
    open var maxFlingVelocity: Double {
        return parent?.maxFlingVelocity ?? kMaxFlingVelocity
    }

    /// Returns the velocity carried on repeated flings.
    ///
    /// By default, physics for platforms other than iOS doesn't carry momentum.
    ///
    /// **Dart Source:** `scroll_physics.dart:480-482`
    open func carriedMomentum(_ existingVelocity: Double) -> Double {
        return parent?.carriedMomentum(existingVelocity) ?? 0.0
    }

    /// The minimum amount of pixel distance drags must move by to start motion
    /// the first time or after each time the drag motion stopped.
    ///
    /// If nil, no minimum threshold is enforced.
    ///
    /// **Dart Source:** `scroll_physics.dart:488`
    open var dragStartDistanceMotionThreshold: Double? {
        return parent?.dragStartDistanceMotionThreshold
    }

    /// Whether a viewport is allowed to change its scroll position implicitly in
    /// response to a call to `RenderObject.showOnScreen`.
    ///
    /// **Dart Source:** `scroll_physics.dart:497`
    open var allowImplicitScrolling: Bool { true }

    /// Whether a viewport is allowed to change the scroll position as the result of user input.
    ///
    /// **Dart Source:** `scroll_physics.dart:500`
    open var allowUserScrolling: Bool { true }

    /// **Dart Source:** `scroll_physics.dart:503-508`
    open var description: String {
        if parent == nil {
            return objectRuntimeType(self, "ScrollPhysics")
        }
        return "\(objectRuntimeType(self, "ScrollPhysics")) -> \(parent!)"
    }
}

// MARK: - RangeMaintainingScrollPhysics

/// Scroll physics that attempt to keep the scroll position in range when the
/// contents change dimensions suddenly.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:567-651`
public class RangeMaintainingScrollPhysics: ScrollPhysics {
    /// Creates scroll physics that maintain the scroll position in range.
    ///
    /// **Dart Source:** `scroll_physics.dart:569`
    public override init(parent: ScrollPhysics? = nil) {
        super.init(parent: parent)
    }

    /// **Dart Source:** `scroll_physics.dart:572-574`
    public override func applyTo(_ ancestor: ScrollPhysics?) -> RangeMaintainingScrollPhysics {
        return RangeMaintainingScrollPhysics(parent: buildParent(ancestor))
    }

    /// **Dart Source:** `scroll_physics.dart:577-650`
    public override func adjustPositionForNewDimensions(
        oldPosition: ScrollMetrics,
        newPosition: ScrollMetrics,
        isScrolling: Bool,
        velocity: Double
    ) -> Double {
        var maintainOverscroll = true
        var enforceBoundary = true

        if velocity != 0.0 {
            maintainOverscroll = false
            enforceBoundary = false
        }
        if oldPosition.minScrollExtent == newPosition.minScrollExtent
            && oldPosition.maxScrollExtent == newPosition.maxScrollExtent {
            maintainOverscroll = false
        }
        if oldPosition.pixels != newPosition.pixels {
            maintainOverscroll = false
            if oldPosition.minScrollExtent.isFinite
                && oldPosition.maxScrollExtent.isFinite
                && newPosition.minScrollExtent.isFinite
                && newPosition.maxScrollExtent.isFinite {
                enforceBoundary = false
            }
        }
        if oldPosition.pixels < oldPosition.minScrollExtent
            || oldPosition.pixels > oldPosition.maxScrollExtent {
            enforceBoundary = false
        }

        if maintainOverscroll {
            if oldPosition.pixels < oldPosition.minScrollExtent
                && newPosition.minScrollExtent > oldPosition.minScrollExtent {
                let oldDelta = oldPosition.minScrollExtent - oldPosition.pixels
                return newPosition.minScrollExtent - oldDelta
            }
            if oldPosition.pixels > oldPosition.maxScrollExtent
                && newPosition.maxScrollExtent < oldPosition.maxScrollExtent {
                let oldDelta = oldPosition.pixels - oldPosition.maxScrollExtent
                return newPosition.maxScrollExtent + oldDelta
            }
        }

        var result = super.adjustPositionForNewDimensions(
            oldPosition: oldPosition,
            newPosition: newPosition,
            isScrolling: isScrolling,
            velocity: velocity
        )
        if enforceBoundary {
            result = clampDouble(result, newPosition.minScrollExtent, newPosition.maxScrollExtent)
        }
        return result
    }
}

// MARK: - BouncingScrollPhysics

/// Scroll physics for environments that allow the scroll offset to go beyond
/// the bounds of the content, but then bounce the content back to the edge of
/// those bounds.
///
/// This is the behavior typically seen on iOS.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:678-818`
public class BouncingScrollPhysics: ScrollPhysics {
    /// Used to determine parameters for friction simulations.
    ///
    /// **Dart Source:** `scroll_physics.dart:686`
    public let decelerationRate: ScrollDecelerationRate

    /// Creates scroll physics that bounce back from the edge.
    ///
    /// **Dart Source:** `scroll_physics.dart:680-683`
    public init(decelerationRate: ScrollDecelerationRate = .normal, parent: ScrollPhysics? = nil) {
        self.decelerationRate = decelerationRate
        super.init(parent: parent)
    }

    /// **Dart Source:** `scroll_physics.dart:689-691`
    public override func applyTo(_ ancestor: ScrollPhysics?) -> BouncingScrollPhysics {
        return BouncingScrollPhysics(decelerationRate: decelerationRate, parent: buildParent(ancestor))
    }

    /// The multiple applied to overscroll to make it appear that scrolling past
    /// the edge is harder than scrolling the list.
    ///
    /// **Dart Source:** `scroll_physics.dart:701-707`
    open func frictionFactor(_ overscrollFraction: Double) -> Double {
        let base = pow(1 - overscrollFraction, 2)
        switch decelerationRate {
        case .fast: return base * 0.26
        case .normal: return base * 0.52
        }
    }

    /// **Dart Source:** `scroll_physics.dart:710-734`
    public override func applyPhysicsToUserOffset(_ position: ScrollMetrics, _ offset: Double) -> Double {
        assert(offset != 0.0)
        assert(position.minScrollExtent <= position.maxScrollExtent)

        if !position.outOfRange {
            return offset
        }

        let overscrollPastStart = max(position.minScrollExtent - position.pixels, 0.0)
        let overscrollPastEnd = max(position.pixels - position.maxScrollExtent, 0.0)
        let overscrollPast = max(overscrollPastStart, overscrollPastEnd)
        let easing = (overscrollPastStart > 0.0 && offset < 0.0)
            || (overscrollPastEnd > 0.0 && offset > 0.0)

        let friction = easing
            ? frictionFactor((overscrollPast - offset.magnitude) / position.viewportDimension)
            : frictionFactor(overscrollPast / position.viewportDimension)
        let direction = offset >= 0 ? 1.0 : -1.0

        if easing && decelerationRate == .fast {
            return direction * offset.magnitude
        }
        return direction * BouncingScrollPhysics._applyFriction(overscrollPast, offset.magnitude, friction)
    }

    /// **Dart Source:** `scroll_physics.dart:736-748`
    private static func _applyFriction(_ extentOutside: Double, _ absDelta: Double, _ gamma: Double) -> Double {
        assert(absDelta > 0)
        var absDelta = absDelta
        var total = 0.0
        if extentOutside > 0 {
            let deltaToLimit = extentOutside / gamma
            if absDelta < deltaToLimit {
                return absDelta * gamma
            }
            total += extentOutside
            absDelta -= deltaToLimit
        }
        return total + absDelta
    }

    /// **Dart Source:** `scroll_physics.dart:751`
    public override func applyBoundaryConditions(_ position: ScrollMetrics, _ value: Double) -> Double {
        return 0.0
    }

    /// **Dart Source:** `scroll_physics.dart:754-771`
    public override func createBallisticSimulation(_ position: ScrollMetrics, _ velocity: Double) -> Simulation? {
        let tolerance = toleranceFor(position)
        if velocity.magnitude >= tolerance.velocity || position.outOfRange {
            let constantDeceleration: Double
            switch decelerationRate {
            case .fast: constantDeceleration = 1400
            case .normal: constantDeceleration = 0
            }
            return BouncingScrollSimulation(
                position: position.pixels,
                velocity: velocity,
                leadingExtent: position.minScrollExtent,
                trailingExtent: position.maxScrollExtent,
                spring: spring,
                constantDeceleration: constantDeceleration,
                tolerance: tolerance
            )
        }
        return nil
    }

    /// **Dart Source:** `scroll_physics.dart:777`
    public override var minFlingVelocity: Double {
        return kMinFlingVelocity * 2.0
    }

    /// Momentum build-up function that mimics iOS's scroll speed increase with repeated flings.
    ///
    /// **Dart Source:** `scroll_physics.dart:793-796`
    public override func carriedMomentum(_ existingVelocity: Double) -> Double {
        let sign = existingVelocity >= 0 ? 1.0 : -1.0
        return sign * Swift.min(0.000816 * pow(existingVelocity.magnitude, 1.967), 40000.0)
    }

    /// **Dart Source:** `scroll_physics.dart:801`
    public override var dragStartDistanceMotionThreshold: Double? {
        return 3.5
    }

    /// **Dart Source:** `scroll_physics.dart:804-807`
    public override var maxFlingVelocity: Double {
        switch decelerationRate {
        case .fast: return kMaxFlingVelocity * 8.0
        case .normal: return super.maxFlingVelocity
        }
    }

    /// **Dart Source:** `scroll_physics.dart:810-817`
    public override var spring: SpringDescription {
        switch decelerationRate {
        case .fast:
            return SpringDescription(mass: 0.3, stiffness: 75.0, ratio: 1.3)
        case .normal:
            return super.spring
        }
    }
}

// MARK: - ClampingScrollPhysics

/// Scroll physics for environments that prevent the scroll offset from reaching
/// beyond the bounds of the content.
///
/// This is the behavior typically seen on Android.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:836-926`
public class ClampingScrollPhysics: ScrollPhysics {
    /// Creates scroll physics that prevent the scroll offset from exceeding the
    /// bounds of the content.
    ///
    /// **Dart Source:** `scroll_physics.dart:839`
    public override init(parent: ScrollPhysics? = nil) {
        super.init(parent: parent)
    }

    /// **Dart Source:** `scroll_physics.dart:842-844`
    public override func applyTo(_ ancestor: ScrollPhysics?) -> ClampingScrollPhysics {
        return ClampingScrollPhysics(parent: buildParent(ancestor))
    }

    /// **Dart Source:** `scroll_physics.dart:847-889`
    public override func applyBoundaryConditions(_ position: ScrollMetrics, _ value: Double) -> Double {
        assert(value != position.pixels,
            "\(objectRuntimeType(self, "ClampingScrollPhysics")).applyBoundaryConditions() was called redundantly.")

        if value < position.pixels && position.pixels <= position.minScrollExtent {
            // Underscroll.
            return value - position.pixels
        }
        if position.maxScrollExtent <= position.pixels && position.pixels < value {
            // Overscroll.
            return value - position.pixels
        }
        if value < position.minScrollExtent && position.minScrollExtent < position.pixels {
            // Hit top edge.
            return value - position.minScrollExtent
        }
        if position.pixels < position.maxScrollExtent && position.maxScrollExtent < value {
            // Hit bottom edge.
            return value - position.maxScrollExtent
        }
        return 0.0
    }

    /// **Dart Source:** `scroll_physics.dart:892-925`
    public override func createBallisticSimulation(_ position: ScrollMetrics, _ velocity: Double) -> Simulation? {
        let tolerance = toleranceFor(position)
        if position.outOfRange {
            var end: Double?
            if position.pixels > position.maxScrollExtent {
                end = position.maxScrollExtent
            }
            if position.pixels < position.minScrollExtent {
                end = position.minScrollExtent
            }
            assert(end != nil)
            return ScrollSpringSimulation(
                spring,
                position.pixels,
                end!,
                min(0.0, velocity),
                tolerance: tolerance
            )
        }
        if velocity.magnitude < tolerance.velocity {
            return nil
        }
        if velocity > 0.0 && position.pixels >= position.maxScrollExtent {
            return nil
        }
        if velocity < 0.0 && position.pixels <= position.minScrollExtent {
            return nil
        }
        return ClampingScrollSimulation(
            position: position.pixels,
            velocity: velocity,
            tolerance: tolerance
        )
    }
}

// MARK: - AlwaysScrollableScrollPhysics

/// Scroll physics that always lets the user scroll.
///
/// This overrides the default behavior which is to disable scrolling
/// when there is no content to scroll. It does not override the
/// handling of overscrolling.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:946-957`
public class AlwaysScrollableScrollPhysics: ScrollPhysics {
    /// Creates scroll physics that always lets the user scroll.
    ///
    /// **Dart Source:** `scroll_physics.dart:948`
    public override init(parent: ScrollPhysics? = nil) {
        super.init(parent: parent)
    }

    /// **Dart Source:** `scroll_physics.dart:951-953`
    public override func applyTo(_ ancestor: ScrollPhysics?) -> AlwaysScrollableScrollPhysics {
        return AlwaysScrollableScrollPhysics(parent: buildParent(ancestor))
    }

    /// **Dart Source:** `scroll_physics.dart:956`
    public override func shouldAcceptUserOffset(_ position: ScrollMetrics) -> Bool {
        return true
    }
}

// MARK: - NeverScrollableScrollPhysics

/// Scroll physics that does not allow the user to scroll.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_physics.dart:969-983`
public class NeverScrollableScrollPhysics: ScrollPhysics {
    /// Creates scroll physics that does not let the user scroll.
    ///
    /// **Dart Source:** `scroll_physics.dart:971`
    public override init(parent: ScrollPhysics? = nil) {
        super.init(parent: parent)
    }

    /// **Dart Source:** `scroll_physics.dart:974-976`
    public override func applyTo(_ ancestor: ScrollPhysics?) -> NeverScrollableScrollPhysics {
        return NeverScrollableScrollPhysics(parent: buildParent(ancestor))
    }

    /// **Dart Source:** `scroll_physics.dart:979`
    public override var allowUserScrolling: Bool { false }

    /// **Dart Source:** `scroll_physics.dart:982`
    public override var allowImplicitScrolling: Bool { false }
}
