// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import Foundation
@testable import Flutter
import FlutterSwiftBridge

// MARK: - TestScrollPhysics Helper

/// A scroll physics subclass used to test applyTo/buildParent chains.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/scroll_physics_test.dart:9-28`
private class TestScrollPhysics: ScrollPhysics {
    let name: String

    init(name: String, parent: ScrollPhysics? = nil) {
        self.name = name
        super.init(parent: parent)
    }

    override func applyTo(_ ancestor: ScrollPhysics?) -> ScrollPhysics {
        return TestScrollPhysics(
            name: name,
            parent: parent?.applyTo(ancestor) ?? ancestor
        )
    }

    var namedParent: TestScrollPhysics { parent! as! TestScrollPhysics }

    var names: String {
        parent == nil ? name : "\(name) \(namedParent.names)"
    }
}

/// Tests for ScrollPhysics and all subclasses.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/scroll_physics_test.dart`
final class ScrollPhysicsTests: XCTestCase {

    // MARK: - Test Helpers

    private func assertMoreOrLessEquals(
        _ actual: Double,
        _ expected: Double,
        epsilon: Double = 1e-10,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            Swift.abs(actual - expected) <= epsilon,
            "Expected \(actual) to be within \(epsilon) of \(expected). \(message)",
            file: file,
            line: line
        )
    }

    private func makeMetrics(
        min: Double = 0,
        max: Double = 1000,
        pixels: Double = 500,
        viewport: Double = 100,
        axisDirection: AxisDirection = .down,
        devicePixelRatio: Double = 3.0
    ) -> FixedScrollMetrics {
        FixedScrollMetrics(
            minScrollExtent: min,
            maxScrollExtent: max,
            pixels: pixels,
            viewportDimension: viewport,
            axisDirection: axisDirection,
            devicePixelRatio: devicePixelRatio
        )
    }

    // MARK: - ScrollDecelerationRate

    func testScrollDecelerationRateCases() {
        let normal: ScrollDecelerationRate = .normal
        let fast: ScrollDecelerationRate = .fast
        XCTAssertNotEqual("\(normal)", "\(fast)")
    }

    // MARK: - ScrollPhysics applyTo() chain

    /// **Dart Test:** `scroll_physics_test.dart:31-53`
    func testScrollPhysicsApplyTo() {
        let a = TestScrollPhysics(name: "a")
        let b = TestScrollPhysics(name: "b")
        let c = TestScrollPhysics(name: "c")
        let d = TestScrollPhysics(name: "d")
        let e = TestScrollPhysics(name: "e")

        XCTAssertNil(a.parent)
        XCTAssertNil(b.parent)
        XCTAssertNil(c.parent)

        let ab = a.applyTo(b) as! TestScrollPhysics
        XCTAssertEqual(ab.names, "a b")

        let abc = ab.applyTo(c) as! TestScrollPhysics
        XCTAssertEqual(abc.names, "a b c")

        let de = d.applyTo(e) as! TestScrollPhysics
        XCTAssertEqual(de.names, "d e")

        let abcde = abc.applyTo(de) as! TestScrollPhysics
        XCTAssertEqual(abcde.names, "a b c d e")
    }

    // MARK: - ScrollPhysics subclasses applyTo()

    /// **Dart Test:** `scroll_physics_test.dart:55-98`
    func testScrollPhysicsSubclassesApplyTo() {
        let bounce = BouncingScrollPhysics()
        let clamp = ClampingScrollPhysics()
        let never = NeverScrollableScrollPhysics()
        let always = AlwaysScrollableScrollPhysics()
        let bounceDesktop = BouncingScrollPhysics(decelerationRate: .fast)

        func types(_ value: ScrollPhysics?) -> String {
            guard let value = value else { return "" }
            if value.parent == nil {
                return "\(type(of: value))"
            }
            return "\(type(of: value)) \(types(value.parent))"
        }

        // bounce -> clamp -> never -> always
        let chain1 = bounce.applyTo(clamp.applyTo(never.applyTo(always)))
        XCTAssertEqual(
            types(chain1),
            "BouncingScrollPhysics ClampingScrollPhysics NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics"
        )

        // clamp -> never -> always -> bounce
        let chain2 = clamp.applyTo(never.applyTo(always.applyTo(bounce)))
        XCTAssertEqual(
            types(chain2),
            "ClampingScrollPhysics NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics BouncingScrollPhysics"
        )

        // never -> always -> bounce -> clamp
        let chain3 = never.applyTo(always.applyTo(bounce.applyTo(clamp)))
        XCTAssertEqual(
            types(chain3),
            "NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics BouncingScrollPhysics ClampingScrollPhysics"
        )

        // always -> bounce -> clamp -> never
        let chain4 = always.applyTo(bounce.applyTo(clamp.applyTo(never)))
        XCTAssertEqual(
            types(chain4),
            "AlwaysScrollableScrollPhysics BouncingScrollPhysics ClampingScrollPhysics NeverScrollableScrollPhysics"
        )

        // bounceDesktop preserves deceleration rate through applyTo
        let desktopChain = bounceDesktop.applyTo(always) as! BouncingScrollPhysics
        XCTAssertEqual(desktopChain.decelerationRate, .fast)
    }

    // MARK: - ScrollPhysics base class defaults

    func testScrollPhysicsDefaultParentIsNil() {
        let physics = ScrollPhysics()
        XCTAssertNil(physics.parent)
    }

    func testScrollPhysicsBuildParentNoParent() {
        let physics = ScrollPhysics()
        let ancestor = ClampingScrollPhysics()
        let result = physics.buildParent(ancestor)
        XCTAssertTrue(result === ancestor)
    }

    func testScrollPhysicsBuildParentNilAncestor() {
        let physics = ScrollPhysics()
        let result = physics.buildParent(nil)
        XCTAssertNil(result)
    }

    func testScrollPhysicsDefaultApplyPhysicsToUserOffset() {
        let physics = ScrollPhysics()
        let position = makeMetrics()
        XCTAssertEqual(physics.applyPhysicsToUserOffset(position, 25.0), 25.0)
    }

    func testScrollPhysicsDefaultShouldAcceptUserOffset() {
        // When pixels != 0 or minScrollExtent != maxScrollExtent, should accept
        let scrollable = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let physics = ScrollPhysics()
        XCTAssertTrue(physics.shouldAcceptUserOffset(scrollable))

        // When pixels == 0 and min == max, should not accept
        let notScrollable = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 200)
        XCTAssertFalse(physics.shouldAcceptUserOffset(notScrollable))
    }

    func testScrollPhysicsShouldAcceptUserOffsetWhenPixelsNonZero() {
        let physics = ScrollPhysics()
        let position = makeMetrics(min: 0, max: 0, pixels: 10, viewport: 200)
        XCTAssertTrue(physics.shouldAcceptUserOffset(position))
    }

    func testScrollPhysicsDefaultApplyBoundaryConditions() {
        let physics = ScrollPhysics()
        let position = makeMetrics()
        // Base ScrollPhysics returns 0.0 (no boundary restriction)
        XCTAssertEqual(physics.applyBoundaryConditions(position, 600.0), 0.0)
    }

    func testScrollPhysicsDefaultAdjustPositionForNewDimensions() {
        let physics = ScrollPhysics()
        let oldPosition = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let newPosition = makeMetrics(min: 0, max: 200, pixels: 50, viewport: 200)
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: oldPosition,
            newPosition: newPosition,
            isScrolling: false,
            velocity: 0
        )
        XCTAssertEqual(result, 50.0)
    }

    func testScrollPhysicsDefaultCreateBallisticSimulation() {
        let physics = ScrollPhysics()
        let position = makeMetrics()
        XCTAssertNil(physics.createBallisticSimulation(position, 100.0))
    }

    func testScrollPhysicsDefaultSpring() {
        let physics = ScrollPhysics()
        let spring = physics.spring
        XCTAssertEqual(spring.mass, 0.5)
        XCTAssertEqual(spring.stiffness, 100.0)
    }

    func testScrollPhysicsDefaultToleranceFor() {
        let position = makeMetrics(devicePixelRatio: 3.0)
        let physics = ScrollPhysics()
        let tolerance = physics.toleranceFor(position)
        assertMoreOrLessEquals(tolerance.distance, 1.0 / 3.0, epsilon: 1e-10)
        assertMoreOrLessEquals(tolerance.velocity, 1.0 / (0.050 * 3.0), epsilon: 1e-10)
    }

    func testScrollPhysicsDefaultMinFlingDistance() {
        let physics = ScrollPhysics()
        XCTAssertEqual(physics.minFlingDistance, kTouchSlop)
    }

    func testScrollPhysicsDefaultMinFlingVelocity() {
        let physics = ScrollPhysics()
        XCTAssertEqual(physics.minFlingVelocity, kMinFlingVelocity)
    }

    func testScrollPhysicsDefaultMaxFlingVelocity() {
        let physics = ScrollPhysics()
        XCTAssertEqual(physics.maxFlingVelocity, kMaxFlingVelocity)
    }

    func testScrollPhysicsDefaultCarriedMomentum() {
        let physics = ScrollPhysics()
        XCTAssertEqual(physics.carriedMomentum(100.0), 0.0)
    }

    func testScrollPhysicsDefaultDragStartDistanceMotionThreshold() {
        let physics = ScrollPhysics()
        XCTAssertNil(physics.dragStartDistanceMotionThreshold)
    }

    func testScrollPhysicsDefaultAllowImplicitScrolling() {
        let physics = ScrollPhysics()
        XCTAssertTrue(physics.allowImplicitScrolling)
    }

    func testScrollPhysicsDefaultAllowUserScrolling() {
        let physics = ScrollPhysics()
        XCTAssertTrue(physics.allowUserScrolling)
    }

    // MARK: - ScrollPhysics parent delegation

    func testScrollPhysicsDelegatesToParent() {
        let parent = BouncingScrollPhysics()
        let child = ScrollPhysics(parent: parent)
        let position = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)
        // applyBoundaryConditions delegates to parent (bouncing returns 0)
        XCTAssertEqual(child.applyBoundaryConditions(position, 100.0), 0.0)
        // Spring delegates to parent
        XCTAssertEqual(child.spring.mass, parent.spring.mass)
    }

    // MARK: - ScrollPhysics description

    func testScrollPhysicsDescriptionNoParent() {
        let physics = ScrollPhysics()
        let desc = physics.description
        XCTAssertTrue(desc.contains("ScrollPhysics"))
        XCTAssertFalse(desc.contains("->"))
    }

    func testScrollPhysicsDescriptionWithParent() {
        let parent = ClampingScrollPhysics()
        let child = ScrollPhysics(parent: parent)
        let desc = child.description
        XCTAssertTrue(desc.contains("->"))
    }

    // MARK: - ScrollPhysics simulation velocity at time 0

    /// **Dart Test:** `scroll_physics_test.dart:100-122`
    func testBallisticSimulationDoesNotAlterVelocityAtTime0() {
        let position = makeMetrics(min: 0, max: 100, pixels: 20, viewport: 500)

        let bounce = BouncingScrollPhysics()
        let clamp = ClampingScrollPhysics()

        let bounceSim = bounce.createBallisticSimulation(position, 1000)!
        assertMoreOrLessEquals(bounceSim.dx(0), 1000, epsilon: 1.0)

        let clampSim = clamp.createBallisticSimulation(position, 1000)!
        assertMoreOrLessEquals(clampSim.dx(0), 1000, epsilon: 1.0)
    }

    // MARK: - RangeMaintainingScrollPhysics

    func testRangeMaintainingApplyTo() {
        let physics = RangeMaintainingScrollPhysics()
        let result = physics.applyTo(ClampingScrollPhysics())
        XCTAssertTrue(result is RangeMaintainingScrollPhysics)
        XCTAssertNotNil(result.parent)
    }

    func testRangeMaintainingAdjustPositionNoChange() {
        let physics = RangeMaintainingScrollPhysics()
        let old = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let new_ = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: old, newPosition: new_, isScrolling: false, velocity: 0
        )
        // Should return newPosition.pixels
        XCTAssertEqual(result, 50.0)
    }

    func testRangeMaintainingAdjustPositionClampsToNewBounds() {
        let physics = RangeMaintainingScrollPhysics()
        let old = makeMetrics(min: 0, max: 500, pixels: 400, viewport: 200)
        let new_ = makeMetrics(min: 0, max: 300, pixels: 400, viewport: 200)
        // enforceBoundary should clamp to new maxScrollExtent
        // oldPosition was in range (400 <= 500), pixels changed (400 != 400? no, both are 400)
        // Wait - pixels are the same (400), but maxScrollExtent changed (500 -> 300)
        // maintainOverscroll starts true. velocity is 0 so no change.
        // extents changed (500 != 300) so maintainOverscroll stays true.
        // pixels same so no change to maintainOverscroll from that block.
        // old pixels (400) <= old max (500) so enforceBoundary stays true.
        // maintainOverscroll: old pixels (400) > old max (500)? no. old pixels < old min? no.
        // So maintainOverscroll path doesn't trigger.
        // super returns newPosition.pixels = 400
        // enforceBoundary clamps to [0, 300] => 300
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: old, newPosition: new_, isScrolling: false, velocity: 0
        )
        XCTAssertEqual(result, 300.0)
    }

    func testRangeMaintainingAdjustPositionWithVelocity() {
        let physics = RangeMaintainingScrollPhysics()
        let old = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let new_ = makeMetrics(min: 0, max: 200, pixels: 50, viewport: 200)
        // velocity != 0 disables maintainOverscroll and enforceBoundary
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: old, newPosition: new_, isScrolling: true, velocity: 100.0
        )
        XCTAssertEqual(result, 50.0) // Just returns newPosition.pixels via super
    }

    func testRangeMaintainingMaintainsOverscrollAtMin() {
        let physics = RangeMaintainingScrollPhysics()
        // Old: overscrolled before min (pixels < minScrollExtent)
        // New: minScrollExtent increased
        let old = makeMetrics(min: 0, max: 100, pixels: -20, viewport: 200)
        let new_ = makeMetrics(min: 10, max: 100, pixels: -20, viewport: 200)
        // maintainOverscroll: starts true. velocity=0 so stays.
        // extents changed (min: 0->10) so maintains true.
        // pixels same (-20 == -20) so no change.
        // old pixels (-20) < old min (0) => enforceBoundary = false
        // maintainOverscroll check: old pixels (-20) < old min (0) AND new min (10) > old min (0)
        // => yes! oldDelta = 0 - (-20) = 20, result = 10 - 20 = -10
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: old, newPosition: new_, isScrolling: false, velocity: 0
        )
        XCTAssertEqual(result, -10.0)
    }

    func testRangeMaintainingMaintainsOverscrollAtMax() {
        let physics = RangeMaintainingScrollPhysics()
        // Old: overscrolled past max (pixels > maxScrollExtent)
        // New: maxScrollExtent decreased
        let old = makeMetrics(min: 0, max: 100, pixels: 120, viewport: 200)
        let new_ = makeMetrics(min: 0, max: 80, pixels: 120, viewport: 200)
        // maintainOverscroll: starts true. velocity=0. extents changed (100->80).
        // pixels same (120==120) so no change.
        // old pixels (120) > old max (100) => enforceBoundary = false
        // maintainOverscroll check: old pixels (120) > old max (100) AND new max (80) < old max (100)
        // => yes! oldDelta = 120 - 100 = 20, result = 80 + 20 = 100
        let result = physics.adjustPositionForNewDimensions(
            oldPosition: old, newPosition: new_, isScrolling: false, velocity: 0
        )
        XCTAssertEqual(result, 100.0)
    }

    // MARK: - BouncingScrollPhysics

    func testBouncingScrollPhysicsApplyTo() {
        let physics = BouncingScrollPhysics()
        let result = physics.applyTo(ClampingScrollPhysics()) as! BouncingScrollPhysics
        XCTAssertNotNil(result.parent)
        XCTAssertEqual(result.decelerationRate, .normal)
    }

    func testBouncingScrollPhysicsApplyToPreservesDecelerationRate() {
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        let result = desktop.applyTo(AlwaysScrollableScrollPhysics()) as! BouncingScrollPhysics
        XCTAssertEqual(result.decelerationRate, .fast)
    }

    /// **Dart Test:** `scroll_physics_test.dart:280-294`
    func testBouncingScrollPhysicsFrictionFactor() {
        let mobile = BouncingScrollPhysics()
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)

        XCTAssertEqual(desktop.frictionFactor(0), 0.26)
        XCTAssertEqual(mobile.frictionFactor(0), 0.52)

        assertMoreOrLessEquals(desktop.frictionFactor(0.4), 0.0936, epsilon: 1e-4)
        assertMoreOrLessEquals(mobile.frictionFactor(0.4), 0.1872, epsilon: 1e-4)

        assertMoreOrLessEquals(desktop.frictionFactor(0.8), 0.0104, epsilon: 1e-4)
        assertMoreOrLessEquals(mobile.frictionFactor(0.8), 0.0208, epsilon: 1e-4)
    }

    func testBouncingScrollPhysicsFrictionFactorAtOne() {
        let mobile = BouncingScrollPhysics()
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        // At overscrollFraction == 1.0, (1 - 1)^2 == 0
        XCTAssertEqual(mobile.frictionFactor(1.0), 0.0)
        XCTAssertEqual(desktop.frictionFactor(1.0), 0.0)
    }

    /// **Dart Test:** `scroll_physics_test.dart:131-168`
    func testBouncingOverscrollIsProgressivelyHarder() {
        let physics = BouncingScrollPhysics()

        let lessOverscrolled = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)
        let moreOverscrolled = makeMetrics(min: 0, max: 1000, pixels: -40, viewport: 100)

        let lessApplied = physics.applyPhysicsToUserOffset(lessOverscrolled, 10.0)
        let moreApplied = physics.applyPhysicsToUserOffset(moreOverscrolled, 10.0)

        XCTAssertGreaterThan(lessApplied, 1.0)
        XCTAssertLessThan(lessApplied, 20.0)

        XCTAssertGreaterThan(moreApplied, 1.0)
        XCTAssertLessThan(moreApplied, 20.0)

        // Scrolling from a more overscrolled position meets more resistance.
        XCTAssertGreaterThan(lessApplied.magnitude, moreApplied.magnitude)
    }

    /// **Dart Test:** `scroll_physics_test.dart:170-187`
    func testBouncingEasingOverscrollStillHasResistance() {
        let physics = BouncingScrollPhysics()
        let overscrolled = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)

        let easingApplied = physics.applyPhysicsToUserOffset(overscrolled, -10.0)

        XCTAssertLessThan(easingApplied, -1.0)
        XCTAssertGreaterThan(easingApplied, -10.0)
    }

    /// **Dart Test:** `scroll_physics_test.dart:189-201`
    func testBouncingNoResistanceWhenNotOverscrolled() {
        let physics = BouncingScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 300, viewport: 100)

        XCTAssertEqual(physics.applyPhysicsToUserOffset(position, 10.0), 10.0)
        XCTAssertEqual(physics.applyPhysicsToUserOffset(position, -10.0), -10.0)
    }

    /// **Dart Test:** `scroll_physics_test.dart:203-223`
    func testBouncingEasingMeetsLessResistanceThanTensioning() {
        let physics = BouncingScrollPhysics()
        let overscrolled = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)

        let easingApplied = physics.applyPhysicsToUserOffset(overscrolled, -10.0)
        let tensioningApplied = physics.applyPhysicsToUserOffset(overscrolled, 10.0)

        XCTAssertGreaterThan(easingApplied.magnitude, tensioningApplied.magnitude)
    }

    /// **Dart Test:** `scroll_physics_test.dart:225-243`
    func testBouncingNoEasingResistanceForFastDeceleration() {
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        let overscrolled = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)

        let easingApplied = desktop.applyPhysicsToUserOffset(overscrolled, -10.0)
        let tensioningApplied = desktop.applyPhysicsToUserOffset(overscrolled, 10.0)

        XCTAssertLessThan(tensioningApplied.magnitude, easingApplied.magnitude)
        XCTAssertEqual(easingApplied, -10.0)
    }

    /// **Dart Test:** `scroll_physics_test.dart:245-278`
    func testBouncingOverscrollSmallAndBigListWorksSame() {
        let physics = BouncingScrollPhysics()

        let smallList = makeMetrics(min: 0, max: 10, pixels: -20, viewport: 100)
        let bigList = makeMetrics(min: 0, max: 1000, pixels: -20, viewport: 100)

        let smallApplied = physics.applyPhysicsToUserOffset(smallList, 10.0)
        let bigApplied = physics.applyPhysicsToUserOffset(bigList, 10.0)

        XCTAssertEqual(smallApplied, bigApplied)
        XCTAssertGreaterThan(smallApplied, 1.0)
        XCTAssertLessThan(smallApplied, 20.0)
    }

    func testBouncingApplyBoundaryConditionsAlwaysZero() {
        let physics = BouncingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        // Bouncing physics never applies boundary conditions (allows overscroll)
        XCTAssertEqual(physics.applyBoundaryConditions(position, 200.0), 0.0)
        XCTAssertEqual(physics.applyBoundaryConditions(position, -50.0), 0.0)
    }

    func testBouncingCreateBallisticSimulationWithVelocity() {
        let physics = BouncingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 1000)
        XCTAssertNotNil(sim)
    }

    func testBouncingCreateBallisticSimulationNilWhenBelowTolerance() {
        let physics = BouncingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        // Very small velocity and not out of range => nil
        let sim = physics.createBallisticSimulation(position, 0.001)
        XCTAssertNil(sim)
    }

    func testBouncingCreateBallisticSimulationWhenOutOfRange() {
        let physics = BouncingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: -10, viewport: 200)
        // Out of range => simulation even with zero velocity
        let sim = physics.createBallisticSimulation(position, 0.0)
        XCTAssertNotNil(sim)
    }

    func testBouncingCreateBallisticSimulationFastDeceleration() {
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        let position = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 200)
        let sim = desktop.createBallisticSimulation(position, 1000)
        XCTAssertNotNil(sim)
    }

    func testBouncingMinFlingVelocity() {
        let physics = BouncingScrollPhysics()
        XCTAssertEqual(physics.minFlingVelocity, kMinFlingVelocity * 2.0)
    }

    func testBouncingCarriedMomentum() {
        let physics = BouncingScrollPhysics()

        // Positive velocity
        let positive = physics.carriedMomentum(1000.0)
        XCTAssertGreaterThan(positive, 0.0)

        // Negative velocity
        let negative = physics.carriedMomentum(-1000.0)
        XCTAssertLessThan(negative, 0.0)

        // Magnitude should be the same
        assertMoreOrLessEquals(positive.magnitude, negative.magnitude, epsilon: 1e-6)

        // Zero velocity
        XCTAssertEqual(physics.carriedMomentum(0.0), 0.0)
    }

    func testBouncingCarriedMomentumIsCapped() {
        let physics = BouncingScrollPhysics()
        // Very large velocity should still be capped at 40000
        let result = physics.carriedMomentum(1_000_000.0)
        XCTAssertLessThanOrEqual(result, 40000.0)
    }

    func testBouncingDragStartDistanceMotionThreshold() {
        let physics = BouncingScrollPhysics()
        XCTAssertEqual(physics.dragStartDistanceMotionThreshold, 3.5)
    }

    func testBouncingMaxFlingVelocityNormal() {
        let physics = BouncingScrollPhysics()
        XCTAssertEqual(physics.maxFlingVelocity, kMaxFlingVelocity)
    }

    func testBouncingMaxFlingVelocityFast() {
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        XCTAssertEqual(desktop.maxFlingVelocity, kMaxFlingVelocity * 8.0)
    }

    func testBouncingSpringNormal() {
        let physics = BouncingScrollPhysics()
        // Normal uses the default spring
        let spring = physics.spring
        XCTAssertEqual(spring.mass, 0.5)
        XCTAssertEqual(spring.stiffness, 100.0)
    }

    func testBouncingSpringFast() {
        let desktop = BouncingScrollPhysics(decelerationRate: .fast)
        let spring = desktop.spring
        XCTAssertEqual(spring.mass, 0.3)
        XCTAssertEqual(spring.stiffness, 75.0)
    }

    // MARK: - ClampingScrollPhysics

    func testClampingApplyTo() {
        let physics = ClampingScrollPhysics()
        let result = physics.applyTo(BouncingScrollPhysics())
        XCTAssertTrue(result is ClampingScrollPhysics)
        XCTAssertNotNil(result.parent)
    }

    func testClampingApplyBoundaryConditionsUnderscroll() {
        let physics = ClampingScrollPhysics()
        // At min edge, trying to go further below
        let position = makeMetrics(min: 0, max: 1000, pixels: 0, viewport: 200)
        let result = physics.applyBoundaryConditions(position, -10.0)
        // value < pixels && pixels <= minScrollExtent => value - pixels
        XCTAssertEqual(result, -10.0)
    }

    func testClampingApplyBoundaryConditionsOverscroll() {
        let physics = ClampingScrollPhysics()
        // At max edge, trying to go further above
        let position = makeMetrics(min: 0, max: 1000, pixels: 1000, viewport: 200)
        let result = physics.applyBoundaryConditions(position, 1010.0)
        // maxScrollExtent <= pixels && pixels < value => value - pixels
        XCTAssertEqual(result, 10.0)
    }

    func testClampingApplyBoundaryConditionsHitTopEdge() {
        let physics = ClampingScrollPhysics()
        // Scrolling up past the top
        let position = makeMetrics(min: 0, max: 1000, pixels: 10, viewport: 200)
        let result = physics.applyBoundaryConditions(position, -5.0)
        // value < minScrollExtent && minScrollExtent < pixels => value - minScrollExtent
        XCTAssertEqual(result, -5.0)
    }

    func testClampingApplyBoundaryConditionsHitBottomEdge() {
        let physics = ClampingScrollPhysics()
        // Scrolling down past the bottom
        let position = makeMetrics(min: 0, max: 1000, pixels: 990, viewport: 200)
        let result = physics.applyBoundaryConditions(position, 1005.0)
        // pixels < maxScrollExtent && maxScrollExtent < value => value - maxScrollExtent
        XCTAssertEqual(result, 5.0)
    }

    func testClampingApplyBoundaryConditionsNoRestriction() {
        let physics = ClampingScrollPhysics()
        // Normal scroll within bounds
        let position = makeMetrics(min: 0, max: 1000, pixels: 500, viewport: 200)
        let result = physics.applyBoundaryConditions(position, 510.0)
        XCTAssertEqual(result, 0.0)
    }

    func testClampingCreateBallisticSimulationOutOfRangeAboveMax() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: 110, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 0.0)
        // Out of range => ScrollSpringSimulation to snap back
        XCTAssertNotNil(sim)
    }

    func testClampingCreateBallisticSimulationOutOfRangeBelowMin() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 100, pixels: -10, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 0.0)
        XCTAssertNotNil(sim)
    }

    func testClampingCreateBallisticSimulationWithVelocity() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 500, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 1000.0)
        XCTAssertNotNil(sim)
    }

    func testClampingCreateBallisticSimulationNilWhenBelowTolerance() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 500, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 0.001)
        XCTAssertNil(sim)
    }

    func testClampingCreateBallisticSimulationNilWhenAtMaxWithPositiveVelocity() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 1000, viewport: 200)
        let sim = physics.createBallisticSimulation(position, 100.0)
        XCTAssertNil(sim)
    }

    func testClampingCreateBallisticSimulationNilWhenAtMinWithNegativeVelocity() {
        let physics = ClampingScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 0, viewport: 200)
        let sim = physics.createBallisticSimulation(position, -100.0)
        XCTAssertNil(sim)
    }

    // MARK: - AlwaysScrollableScrollPhysics

    func testAlwaysScrollableApplyTo() {
        let physics = AlwaysScrollableScrollPhysics()
        let result = physics.applyTo(ClampingScrollPhysics())
        XCTAssertTrue(result is AlwaysScrollableScrollPhysics)
        XCTAssertNotNil(result.parent)
    }

    func testAlwaysScrollableAlwaysAcceptsUserOffset() {
        let physics = AlwaysScrollableScrollPhysics()
        // Even when there's nothing to scroll (min == max, pixels == 0)
        let position = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 200)
        XCTAssertTrue(physics.shouldAcceptUserOffset(position))
    }

    func testAlwaysScrollableAcceptsEvenEmptyContent() {
        let physics = AlwaysScrollableScrollPhysics()
        let position = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 500)
        XCTAssertTrue(physics.shouldAcceptUserOffset(position))
    }

    // MARK: - NeverScrollableScrollPhysics

    func testNeverScrollableApplyTo() {
        let physics = NeverScrollableScrollPhysics()
        let result = physics.applyTo(BouncingScrollPhysics())
        XCTAssertTrue(result is NeverScrollableScrollPhysics)
        XCTAssertNotNil(result.parent)
    }

    func testNeverScrollableDoesNotAllowUserScrolling() {
        let physics = NeverScrollableScrollPhysics()
        XCTAssertFalse(physics.allowUserScrolling)
    }

    func testNeverScrollableDoesNotAllowImplicitScrolling() {
        let physics = NeverScrollableScrollPhysics()
        XCTAssertFalse(physics.allowImplicitScrolling)
    }

    func testNeverScrollableRejectsUserOffset() {
        let physics = NeverScrollableScrollPhysics()
        let position = makeMetrics(min: 0, max: 1000, pixels: 500, viewport: 200)
        // shouldAcceptUserOffset checks allowUserScrolling first, returns false
        XCTAssertFalse(physics.shouldAcceptUserOffset(position))
    }

    func testNeverScrollableRejectsEvenWithContent() {
        let physics = NeverScrollableScrollPhysics()
        let position = makeMetrics(min: 0, max: 10000, pixels: 5000, viewport: 100)
        XCTAssertFalse(physics.shouldAcceptUserOffset(position))
    }

    // MARK: - Combined physics chains

    func testNeverScrollableOverridesAlwaysScrollable() {
        // NeverScrollable applied with AlwaysScrollable parent
        let physics = NeverScrollableScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()
        )
        let position = makeMetrics(min: 0, max: 1000, pixels: 500, viewport: 200)
        // NeverScrollable's shouldAcceptUserOffset checks allowUserScrolling first -> false
        XCTAssertFalse(physics.shouldAcceptUserOffset(position))
    }

    func testAlwaysScrollableWithClampingParent() {
        let physics = AlwaysScrollableScrollPhysics()
            .applyTo(ClampingScrollPhysics()) as! AlwaysScrollableScrollPhysics
        let position = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 200)
        XCTAssertTrue(physics.shouldAcceptUserOffset(position))
    }
}
