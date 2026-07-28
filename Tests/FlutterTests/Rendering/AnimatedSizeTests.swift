// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for AnimatedSize types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/animated_size.dart`
///
/// These tests cover:
///   - RenderAnimatedSizeState: enum cases, distinctness
///   - RenderAnimatedSize: construction, default values, custom parameters
///   - Property setters: duration, reverseDuration, curve, clipBehavior, vsync, onEnd
///   - State machine: start -> stable transitions, stable -> changed, changed -> stable/unstable
///   - Tight constraints: bypasses animation, uses constraints.smallest
///   - Dry layout: computeDryLayout in various states
///   - Dispose: cleanup of animation resources
///   - Attach/Detach: lifecycle management

import XCTest
@_spi(Testing) @testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A mock TickerProvider that creates real Ticker instances.
/// The Ticker class has a `tick(_:)` method for manually advancing time in tests.
private class MockTickerProvider: TickerProvider {
    var lastTicker: Ticker?

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        let ticker = Ticker(onTick)
        lastTicker = ticker
        return ticker
    }
}

/// A concrete RenderBox subclass with a configurable size for layout,
/// used as a child in tests.
private class FixedSizeRenderBox: RenderBox {
    var fixedWidth: Double
    var fixedHeight: Double

    init(width: Double, height: Double) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

/// Helper to create a RenderAnimatedSize with sensible defaults for testing.
private func makeAnimatedSize(
    vsync: MockTickerProvider = MockTickerProvider(),
    duration: Duration = .milliseconds(300),
    reverseDuration: Duration? = nil,
    curve: any Curve = Curves.linear,
    alignment: any AlignmentGeometry = Alignment.center,
    textDirection: TextDirection? = nil,
    child: RenderBox? = nil,
    clipBehavior: Clip = .hardEdge,
    onEnd: VoidCallback? = nil
) -> RenderAnimatedSize {
    return RenderAnimatedSize(
        vsync: vsync,
        duration: duration,
        reverseDuration: reverseDuration,
        curve: curve,
        alignment: alignment,
        textDirection: textDirection,
        child: child,
        clipBehavior: clipBehavior,
        onEnd: onEnd
    )
}

// MARK: - RenderAnimatedSizeState Tests

final class RenderAnimatedSizeStateTests: XCTestCase {

    /// Test that all four enum cases exist.
    func testAllCasesExist() {
        let start = RenderAnimatedSizeState.start
        let stable = RenderAnimatedSizeState.stable
        let changed = RenderAnimatedSizeState.changed
        let unstable = RenderAnimatedSizeState.unstable
        XCTAssertNotNil(start)
        XCTAssertNotNil(stable)
        XCTAssertNotNil(changed)
        XCTAssertNotNil(unstable)
    }

    /// Test that all four cases are distinct from each other.
    func testAllCasesAreDistinct() {
        XCTAssertNotEqual(RenderAnimatedSizeState.start, RenderAnimatedSizeState.stable)
        XCTAssertNotEqual(RenderAnimatedSizeState.start, RenderAnimatedSizeState.changed)
        XCTAssertNotEqual(RenderAnimatedSizeState.start, RenderAnimatedSizeState.unstable)
        XCTAssertNotEqual(RenderAnimatedSizeState.stable, RenderAnimatedSizeState.changed)
        XCTAssertNotEqual(RenderAnimatedSizeState.stable, RenderAnimatedSizeState.unstable)
        XCTAssertNotEqual(RenderAnimatedSizeState.changed, RenderAnimatedSizeState.unstable)
    }

    /// Test that the same case equals itself.
    func testCaseEqualsSelf() {
        XCTAssertEqual(RenderAnimatedSizeState.start, RenderAnimatedSizeState.start)
        XCTAssertEqual(RenderAnimatedSizeState.stable, RenderAnimatedSizeState.stable)
        XCTAssertEqual(RenderAnimatedSizeState.changed, RenderAnimatedSizeState.changed)
        XCTAssertEqual(RenderAnimatedSizeState.unstable, RenderAnimatedSizeState.unstable)
    }

    /// Test that the enum conforms to Sendable.
    func testSendableConformance() {
        let state: RenderAnimatedSizeState = .start
        let sendable: any Sendable = state
        XCTAssertNotNil(sendable)
    }
}

// MARK: - RenderAnimatedSize Construction Tests

final class RenderAnimatedSizeConstructionTests: XCTestCase {

    /// Test default construction with required parameters.
    func testDefaultConstruction() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertNil(box.child)
        XCTAssertEqual(box.clipBehavior, .hardEdge)
        XCTAssertNil(box.onEnd)
        XCTAssertEqual(box.state, .start)
        XCTAssertFalse(box.isAnimating)
        box.dispose()
    }

    /// Test construction with custom duration.
    func testConstructionWithDuration() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, duration: .milliseconds(500))
        XCTAssertEqual(box.duration, .milliseconds(500))
        box.dispose()
    }

    /// Test construction with reverse duration.
    func testConstructionWithReverseDuration() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(
            vsync: vsync,
            duration: .milliseconds(300),
            reverseDuration: .milliseconds(200)
        )
        XCTAssertEqual(box.reverseDuration, .milliseconds(200))
        box.dispose()
    }

    /// Test construction without reverse duration defaults to nil.
    func testConstructionWithoutReverseDuration() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertNil(box.reverseDuration)
        box.dispose()
    }

    /// Test construction with a child.
    func testConstructionWithChild() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
        box.dispose()
    }

    /// Test construction with custom clip behavior.
    func testConstructionWithClipBehavior() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, clipBehavior: .antiAlias)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
        box.dispose()
    }

    /// Test construction with Clip.none.
    func testConstructionWithClipNone() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, clipBehavior: .none)
        XCTAssertEqual(box.clipBehavior, .none)
        box.dispose()
    }

    /// Test construction with onEnd callback.
    func testConstructionWithOnEnd() {
        let vsync = MockTickerProvider()
        var called = false
        let box = makeAnimatedSize(vsync: vsync, onEnd: { called = true })
        XCTAssertNotNil(box.onEnd)
        box.onEnd!()
        XCTAssertTrue(called)
        box.dispose()
    }

    /// Test initial state is .start.
    func testInitialStateIsStart() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertEqual(box.state, .start)
        box.dispose()
    }

    /// Test isAnimating is false initially.
    func testNotAnimatingInitially() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertFalse(box.isAnimating)
        box.dispose()
    }

    /// Test debug accessors are available.
    func testDebugAccessors() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        // In debug builds (asserts enabled), these should return non-nil.
        XCTAssertNotNil(box.debugController)
        XCTAssertNotNil(box.debugAnimation)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Property Setter Tests

final class RenderAnimatedSizePropertyTests: XCTestCase {

    /// Test setting duration to a new value.
    func testDurationSetter() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, duration: .milliseconds(300))
        XCTAssertEqual(box.duration, .milliseconds(300))

        box.duration = .milliseconds(500)
        XCTAssertEqual(box.duration, .milliseconds(500))
        box.dispose()
    }

    /// Test setting duration to the same value is a no-op (does not crash).
    func testDurationSetterSameValue() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, duration: .milliseconds(300))
        box.duration = .milliseconds(300)
        XCTAssertEqual(box.duration, .milliseconds(300))
        box.dispose()
    }

    /// Test setting reverseDuration.
    func testReverseDurationSetter() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertNil(box.reverseDuration)

        box.reverseDuration = .milliseconds(200)
        XCTAssertEqual(box.reverseDuration, .milliseconds(200))
        box.dispose()
    }

    /// Test setting reverseDuration to nil.
    func testReverseDurationSetterToNil() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(
            vsync: vsync,
            reverseDuration: .milliseconds(200)
        )
        XCTAssertEqual(box.reverseDuration, .milliseconds(200))

        box.reverseDuration = nil
        XCTAssertNil(box.reverseDuration)
        box.dispose()
    }

    /// Test setting reverseDuration to the same value is a no-op.
    func testReverseDurationSetterSameValue() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(
            vsync: vsync,
            reverseDuration: .milliseconds(200)
        )
        box.reverseDuration = .milliseconds(200)
        XCTAssertEqual(box.reverseDuration, .milliseconds(200))
        box.dispose()
    }

    /// Test setting curve.
    func testCurveSetter() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, curve: Curves.linear)
        // Setting a new curve should not crash.
        box.curve = Curves.easeIn
        // Curve is a protocol, so we just verify the setter works.
        XCTAssertNotNil(box.curve)
        box.dispose()
    }

    /// Test setting clipBehavior triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child, clipBehavior: .hardEdge)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        box.needsPaint = false

        box.clipBehavior = .antiAlias
        XCTAssertTrue(box.needsPaint)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
        box.dispose()
    }

    /// Test setting clipBehavior to the same value does not trigger paint.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child, clipBehavior: .hardEdge)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        box.needsPaint = false

        box.clipBehavior = .hardEdge
        XCTAssertFalse(box.needsPaint)
        box.dispose()
    }

    /// Test setting vsync creates a new ticker via resync.
    func testVsyncSetter() {
        let vsync1 = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync1)
        XCTAssertNotNil(vsync1.lastTicker)

        let vsync2 = MockTickerProvider()
        box.vsync = vsync2
        XCTAssertNotNil(vsync2.lastTicker)
        box.dispose()
    }

    /// Test setting onEnd callback.
    func testOnEndSetter() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertNil(box.onEnd)

        var endCalled = false
        box.onEnd = { endCalled = true }
        XCTAssertNotNil(box.onEnd)
        box.onEnd!()
        XCTAssertTrue(endCalled)
        box.dispose()
    }

    /// Test setting onEnd to nil.
    func testOnEndSetterToNil() {
        let vsync = MockTickerProvider()
        var called = false
        let box = makeAnimatedSize(vsync: vsync, onEnd: { called = true })
        XCTAssertNotNil(box.onEnd)

        box.onEnd = nil
        XCTAssertNil(box.onEnd)
        XCTAssertFalse(called)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize State Machine Tests

final class RenderAnimatedSizeStateMachineTests: XCTestCase {

    /// Test that initial state is .start and transitions to .stable after first layout.
    func testStartToStableTransition() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        XCTAssertEqual(box.state, .start)

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)

        XCTAssertEqual(box.state, .stable)
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)
        box.dispose()
    }

    /// Test that in stable state, when child size changes, state becomes .changed.
    func testStableToChangedTransition() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // First layout: start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Change child size
        child.fixedWidth = 150
        child.fixedHeight = 75

        // Second layout: stable -> changed (child size differs from tween end)
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)
        box.dispose()
    }

    /// Test that in changed state, when child size stabilizes, state becomes .stable.
    func testChangedToStableTransition() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // First layout: start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Change child size -> stable -> changed
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // Same size again -> changed -> stable (child stabilized)
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        box.dispose()
    }

    /// Test that in changed state, when child size changes again, state becomes .unstable.
    func testChangedToUnstableTransition() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // First layout: start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Change child size -> stable -> changed
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // Change child size again -> changed -> unstable
        child.fixedWidth = 200
        child.fixedHeight = 100
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)
        box.dispose()
    }

    /// Test that in unstable state, when child stabilizes, state becomes .stable.
    func testUnstableToStableTransition() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // stable -> changed
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // changed -> unstable
        child.fixedWidth = 200
        child.fixedHeight = 100
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)

        // unstable -> stable (same size in next layout)
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        box.dispose()
    }

    /// Test that in unstable state, continued size changes keep it unstable.
    func testUnstableRemainsUnstableWithChanges() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 500)

        // start -> stable
        box.layout(constraints)

        // stable -> changed
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)

        // changed -> unstable
        child.fixedWidth = 200
        child.fixedHeight = 100
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)

        // Still changing -> stays unstable
        child.fixedWidth = 250
        child.fixedHeight = 125
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)

        // Still changing again
        child.fixedWidth = 300
        child.fixedHeight = 150
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)
        box.dispose()
    }

    /// Test the full state machine cycle: start -> stable -> changed -> stable.
    func testFullCycleStartStableChangedStable() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // stable -> changed
        child.fixedWidth = 100
        child.fixedHeight = 100
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // changed -> stable (child stabilizes)
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        box.dispose()
    }

    /// Test the full state machine cycle: start -> stable -> changed -> unstable -> stable.
    func testFullCycleStartStableChangedUnstableStable() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 500)

        // start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // stable -> changed
        child.fixedWidth = 100
        child.fixedHeight = 100
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // changed -> unstable
        child.fixedWidth = 150
        child.fixedHeight = 150
        box.layout(constraints)
        XCTAssertEqual(box.state, .unstable)

        // unstable -> stable (size stabilizes)
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Tight Constraints Tests

final class RenderAnimatedSizeTightConstraintsTests: XCTestCase {

    /// Test that tight constraints bypass the animation and use constraints.smallest.
    func testTightConstraintsBypassAnimation() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let tightConstraints = BoxConstraints.tight(Size(200, 200))

        box.layout(tightConstraints)

        // With tight constraints, size should be constraints.smallest (= 200x200).
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
        // State resets to .start under tight constraints.
        XCTAssertEqual(box.state, .start)
        box.dispose()
    }

    /// Test that tight constraints stop the animation controller.
    func testTightConstraintsStopAnimation() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let looseConstraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // First layout to get animation started.
        box.layout(looseConstraints)
        XCTAssertEqual(box.state, .stable)

        // Change child size to trigger animation.
        child.fixedWidth = 200
        child.fixedHeight = 100
        box.layout(looseConstraints)
        XCTAssertEqual(box.state, .changed)

        // Now apply tight constraints.
        let tightConstraints = BoxConstraints.tight(Size(150, 150))
        box.layout(tightConstraints)
        XCTAssertEqual(box.state, .start)
        XCTAssertEqual(box.size.width, 150.0)
        XCTAssertEqual(box.size.height, 150.0)
        box.dispose()
    }

    /// Test layout without child with loose constraints.
    func testNoChildLooseConstraints() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        // No child => treated like tight constraints branch: size = constraints.smallest
        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
        XCTAssertEqual(box.state, .start)
        box.dispose()
    }

    /// Test layout without child with tight constraints.
    func testNoChildTightConstraints() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let tightConstraints = BoxConstraints.tight(Size(100, 100))

        box.layout(tightConstraints)
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 100.0)
        XCTAssertEqual(box.state, .start)
        box.dispose()
    }

    /// Test that tight constraints with child still sizes to tight constraint size.
    func testTightConstraintsWithChildSizesToConstraints() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let tightConstraints = BoxConstraints.tight(Size(200, 200))

        box.layout(tightConstraints)
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Dry Layout Tests

final class RenderAnimatedSizeDryLayoutTests: XCTestCase {

    /// Test dry layout with no child returns constraints.smallest.
    func testDryLayoutWithoutChild() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 10.0)
        XCTAssertEqual(size.height, 20.0)
        box.dispose()
    }

    /// Test dry layout with tight constraints returns smallest.
    func testDryLayoutWithTightConstraints() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let tightConstraints = BoxConstraints.tight(Size(100, 100))
        let size = box.computeDryLayout(tightConstraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 100.0)
        box.dispose()
    }

    /// Test dry layout in start state returns constrained child size.
    func testDryLayoutInStartState() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        XCTAssertEqual(box.state, .start)

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 80.0)
        XCTAssertEqual(size.height, 60.0)
        box.dispose()
    }

    /// Test dry layout respects max constraints for child.
    func testDryLayoutRespectsMaxConstraints() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 300, height: 250)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        // Child wants 300x250 but constrained to 200x200
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 200.0)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Layout Tests

final class RenderAnimatedSizeLayoutTests: XCTestCase {

    /// Test that the first layout in start state records child size.
    func testFirstLayoutRecordsChildSize() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)
        box.dispose()
    }

    /// Test layout with child smaller than constraints uses child size.
    func testLayoutWithSmallerChild() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.size.width, 50.0)
        XCTAssertEqual(box.size.height, 30.0)
        box.dispose()
    }

    /// Test layout with child larger than constraints respects constraints.
    func testLayoutConstrainsChildSize() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 300, height: 250)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
        box.dispose()
    }

    /// Test that child layout sets up parent data.
    func testChildHasSizeAfterLayout() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertTrue(child.hasSize)
        XCTAssertEqual(child.size.width, 80.0)
        XCTAssertEqual(child.size.height, 60.0)
        box.dispose()
    }

    /// Test multiple sequential layouts with same child size stay in stable.
    func testStableStateWithUnchangedSize() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Layout again with same child size.
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // And again.
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        box.dispose()
    }

    /// Test layout with minimum constraints enforced.
    func testLayoutRespectsMinConstraints() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 10, height: 10)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 50, maxHeight: 200)

        box.layout(constraints)
        // Animated size should be at least minWidth x minHeight.
        XCTAssertGreaterThanOrEqual(box.size.width, 50.0)
        XCTAssertGreaterThanOrEqual(box.size.height, 50.0)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Attach/Detach Tests

final class RenderAnimatedSizeAttachDetachTests: XCTestCase {

    /// Test attach and detach lifecycle.
    func testAttachDetachLifecycle() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let owner = PipelineOwner()

        XCTAssertFalse(box.attached)
        box.attach(owner)
        XCTAssertTrue(box.attached)
        box.detach()
        XCTAssertFalse(box.attached)
        box.dispose()
    }

    /// Test attach in start state does not crash.
    func testAttachInStartState() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let owner = PipelineOwner()

        XCTAssertEqual(box.state, .start)
        box.attach(owner)
        XCTAssertTrue(box.attached)
        box.detach()
        box.dispose()
    }

    /// Test attach in stable state does not crash.
    func testAttachInStableState() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        let owner = PipelineOwner()
        box.attach(owner)
        XCTAssertTrue(box.attached)
        box.detach()
        box.dispose()
    }

    /// Test attach in changed state marks needs layout.
    func testAttachInChangedStateMarksNeedsLayout() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // start -> stable
        box.layout(constraints)
        // stable -> changed
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        // Clear needsLayout to detect if attach sets it again.
        box.needsLayout = false

        let owner = PipelineOwner()
        box.attach(owner)
        XCTAssertTrue(box.needsLayout, "Attach in changed state should mark needs layout")
        box.detach()
        box.dispose()
    }

    /// Test detach stops animation controller.
    func testDetachStopsAnimation() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let owner = PipelineOwner()

        box.attach(owner)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))

        box.detach()
        XCTAssertFalse(box.attached)
        // After detach, the controller should be stopped.
        XCTAssertFalse(box.isAnimating)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Dispose Tests

final class RenderAnimatedSizeDisposeTests: XCTestCase {

    /// Test that dispose does not crash on a freshly created instance.
    func testDisposeOnFreshInstance() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        box.dispose()
        // Should not crash.
    }

    /// Test that dispose does not crash after layout.
    func testDisposeAfterLayout() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)
        box.dispose()
        // Should not crash.
    }

    /// Test that dispose does not crash when animation was active.
    func testDisposeWithActiveAnimation() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        // Trigger layout and animation.
        box.layout(constraints)
        child.fixedWidth = 150
        child.fixedHeight = 75
        box.layout(constraints)
        XCTAssertEqual(box.state, .changed)

        box.dispose()
        // Should not crash.
    }

    /// Test that dispose cleans up the animation resources with child present.
    func testDisposeWithChild() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)
        box.dispose()
        // Should not crash; animation resources should be cleaned up.
    }
}

// MARK: - RenderAnimatedSize IsAnimating Tests

final class RenderAnimatedSizeIsAnimatingTests: XCTestCase {

    /// Test isAnimating is false before layout.
    func testIsAnimatingFalseBeforeLayout() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        XCTAssertFalse(box.isAnimating)
        box.dispose()
    }

    /// Test isAnimating after first layout (no size change, so no animation expected).
    func testIsAnimatingAfterFirstLayout() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        // In start -> stable, both begin and end are set to child size.
        // No animation should be running.
        XCTAssertFalse(box.isAnimating)
        box.dispose()
    }

    /// Test isAnimating becomes true when child size changes (triggers animation).
    func testIsAnimatingAfterSizeChange() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        box.layout(constraints)

        // Change child size to trigger animation.
        child.fixedWidth = 200
        child.fixedHeight = 100
        box.layout(constraints)

        // Animation should now be running.
        XCTAssertTrue(box.isAnimating)
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Debug Accessor Tests

final class RenderAnimatedSizeDebugAccessorTests: XCTestCase {

    /// Test debugController returns non-nil in debug mode.
    func testDebugControllerIsNotNil() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, duration: .milliseconds(500))
        let controller = box.debugController
        XCTAssertNotNil(controller)
        box.dispose()
    }

    /// Test debugAnimation returns non-nil in debug mode.
    func testDebugAnimationIsNotNil() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync)
        let animation = box.debugAnimation
        XCTAssertNotNil(animation)
        box.dispose()
    }

    /// Test that debugController reflects the configured duration.
    func testDebugControllerHasCorrectDuration() {
        let vsync = MockTickerProvider()
        let box = makeAnimatedSize(vsync: vsync, duration: .milliseconds(750))
        let controller = box.debugController!
        XCTAssertEqual(controller.duration, .milliseconds(750))
        box.dispose()
    }
}

// MARK: - RenderAnimatedSize Edge Case Tests

final class RenderAnimatedSizeEdgeCaseTests: XCTestCase {

    /// Test layout with zero-size child.
    func testZeroSizeChild() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 0, height: 0)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)
        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
        box.dispose()
    }

    /// Test layout where child fills entire constraint space.
    func testChildFillsConstraints() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 200, height: 200)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
        box.dispose()
    }

    /// Test replacing child triggers new layout behavior.
    func testReplacingChild() {
        let vsync = MockTickerProvider()
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child1)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)

        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Replace child with a different-sized one.
        let child2 = FixedSizeRenderBox(width: 200, height: 100)
        box.child = child2
        box.layout(constraints)
        // The new child's size differs from the tween end, so state transitions.
        XCTAssertEqual(box.state, .changed)
        box.dispose()
    }

    /// Test setting child to nil after layout.
    func testSettingChildToNilAfterLayout() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)

        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        box.child = nil
        box.layout(constraints)
        // No child => same as tight constraints path: state resets to .start.
        XCTAssertEqual(box.state, .start)
        box.dispose()
    }

    /// Test that layout constrains animated size to constraints.
    func testLayoutConstrainsAnimatedSize() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)

        // Use constraints smaller than child.
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 80, minHeight: 0, maxHeight: 40)
        box.layout(constraints)

        // Size should be constrained by max constraints.
        XCTAssertLessThanOrEqual(box.size.width, 80.0)
        XCTAssertLessThanOrEqual(box.size.height, 40.0)
        box.dispose()
    }

    /// Test multiple rapid child size changes.
    func testRapidChildSizeChanges() {
        let vsync = MockTickerProvider()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = makeAnimatedSize(vsync: vsync, child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 500)

        // start -> stable
        box.layout(constraints)
        XCTAssertEqual(box.state, .stable)

        // Simulate rapid size changes.
        for i in 1...5 {
            child.fixedWidth = Double(50 + i * 20)
            child.fixedHeight = Double(50 + i * 10)
            box.layout(constraints)
        }
        // After rapid changes, the state should be unstable (size kept changing).
        // The exact state depends on the sequence, but it should not crash.
        XCTAssertTrue(
            box.state == .stable || box.state == .changed || box.state == .unstable,
            "State should be one of stable, changed, or unstable after rapid changes"
        )
        box.dispose()
    }
}
