// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for AnimationController migrated from animation_controller.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/animation_controller_test.dart`
final class AnimationControllerTests: XCTestCase {

    // MARK: - MockTickerProvider

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

    /// Helper to create a bounded AnimationController.
    /// Explicitly passes `lowerBound` and `upperBound` to disambiguate from the
    /// unbounded initializer, which Swift may otherwise prefer.
    private func makeBoundedController(
        value: Double? = nil,
        duration: Duration? = nil,
        reverseDuration: Duration? = nil,
        debugLabel: String? = nil,
        lowerBound: Double = 0.0,
        upperBound: Double = 1.0,
        animationBehavior: AnimationBehavior = .normal,
        vsync: MockTickerProvider
    ) -> AnimationController {
        return AnimationController(
            value: value,
            duration: duration,
            reverseDuration: reverseDuration,
            debugLabel: debugLabel,
            lowerBound: lowerBound,
            upperBound: upperBound,
            animationBehavior: animationBehavior,
            vsync: vsync
        )
    }

    // MARK: - Default Initialization Tests

    /// Test that a default AnimationController initializes with value = lowerBound
    /// and status = dismissed.
    func testDefaultInitialization() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 0.0, "Default value should be lowerBound (0.0)")
        XCTAssertEqual(controller.status, .dismissed, "Default status should be .dismissed")
        XCTAssertEqual(controller.lowerBound, 0.0)
        XCTAssertEqual(controller.upperBound, 1.0)
        XCTAssertFalse(controller.isAnimating)

        controller.dispose()
    }

    /// Test initialization with a custom initial value.
    func testInitializationWithValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 0.5,
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 0.5)
        XCTAssertEqual(controller.status, .forward, "Mid-range value with forward direction should be .forward")

        controller.dispose()
    }

    /// Test initialization with value = upperBound sets status to completed.
    func testInitializationWithUpperBoundValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 1.0)
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    // MARK: - Unbounded Initialization Tests

    /// Test unbounded initialization with default value.
    func testUnboundedInitializationDefault() {
        let vsync = MockTickerProvider()
        let controller = AnimationController(
            unboundedValue: 0.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.lowerBound, -.infinity)
        XCTAssertEqual(controller.upperBound, .infinity)
        XCTAssertEqual(controller.animationBehavior, .preserve, "Unbounded should default to .preserve")

        controller.dispose()
    }

    /// Test unbounded initialization with a custom value.
    func testUnboundedInitializationCustomValue() {
        let vsync = MockTickerProvider()
        let controller = AnimationController(
            unboundedValue: 42.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 42.0)

        controller.dispose()
    }

    // MARK: - Custom Bounds Tests

    /// Test initialization with custom lowerBound and upperBound.
    func testCustomBounds() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            lowerBound: 10.0,
            upperBound: 20.0,
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 10.0, "Default value should be lowerBound")
        XCTAssertEqual(controller.lowerBound, 10.0)
        XCTAssertEqual(controller.upperBound, 20.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    /// Test initialization with custom bounds and a specific value.
    func testCustomBoundsWithValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 15.0,
            duration: .milliseconds(100),
            lowerBound: 10.0,
            upperBound: 20.0,
            vsync: vsync
        )

        XCTAssertEqual(controller.value, 15.0)

        controller.dispose()
    }

    // MARK: - Value Get/Set Tests

    /// Test setting value on a bounded controller clamps to bounds.
    func testValueSetClampedToBounds() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.value = 0.5
        XCTAssertEqual(controller.value, 0.5)

        // Should clamp to upperBound
        controller.value = 2.0
        XCTAssertEqual(controller.value, 1.0)

        // Should clamp to lowerBound
        controller.value = -1.0
        XCTAssertEqual(controller.value, 0.0)

        controller.dispose()
    }

    /// Test setting value updates status appropriately.
    func testValueSetUpdatesStatus() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.value = 0.0
        XCTAssertEqual(controller.status, .dismissed)

        controller.value = 1.0
        XCTAssertEqual(controller.status, .completed)

        controller.value = 0.5
        // After setting value, stop() is called which keeps _direction as forward
        XCTAssertEqual(controller.status, .forward)

        controller.dispose()
    }

    /// Test setting value on an unbounded controller does not clamp.
    func testUnboundedValueNotClamped() {
        let vsync = MockTickerProvider()
        let controller = AnimationController(
            unboundedValue: 0.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.value = 100.0
        XCTAssertEqual(controller.value, 100.0)

        controller.value = -100.0
        XCTAssertEqual(controller.value, -100.0)

        controller.dispose()
    }

    /// Test setting value stops a running animation.
    func testValueSetStopsAnimation() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        controller.value = 0.5
        XCTAssertFalse(controller.isAnimating)

        controller.dispose()
    }

    // MARK: - forward() Tests

    /// Test forward() starts animation and transitions through statuses.
    func testForwardStatusTransitions() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var statuses: [AnimationStatus] = []
        controller.addStatusListener { status in
            statuses.append(status)
        }

        controller.forward()
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .forward)

        // Tick partway through
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(50))
        XCTAssertTrue(controller.value > 0.0 && controller.value < 1.0,
            "Value should be mid-range at 50ms, got \(controller.value)")
        XCTAssertEqual(controller.status, .forward)

        // Tick past the end
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 1.0)
        XCTAssertEqual(controller.status, .completed)
        XCTAssertFalse(controller.isAnimating)

        XCTAssertTrue(statuses.contains(.forward))
        XCTAssertTrue(statuses.contains(.completed))

        controller.dispose()
    }

    /// Test forward(from:) starts from a specific value.
    func testForwardFromValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward(from: 0.5)
        XCTAssertTrue(controller.isAnimating)

        // Tick past the end
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 1.0)
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    // MARK: - reverse() Tests

    /// Test reverse() from completed status transitions to dismissed.
    func testReverseStatusTransitions() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        var statuses: [AnimationStatus] = []
        controller.addStatusListener { status in
            statuses.append(status)
        }

        controller.reverse()
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .reverse)

        // Tick partway
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(50))
        XCTAssertTrue(controller.value > 0.0 && controller.value < 1.0,
            "Value should be mid-range at 50ms, got \(controller.value)")
        XCTAssertEqual(controller.status, .reverse)

        // Tick past the end
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)
        XCTAssertFalse(controller.isAnimating)

        XCTAssertTrue(statuses.contains(.reverse))
        XCTAssertTrue(statuses.contains(.dismissed))

        controller.dispose()
    }

    /// Test reverse(from:) starts from a specific value.
    func testReverseFromValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.reverse(from: 0.5)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    /// Test reverse() with reverseDuration uses that duration.
    func testReverseWithReverseDuration() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(200),
            reverseDuration: .milliseconds(100),
            vsync: vsync
        )

        controller.reverse()
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        // At 50ms out of 100ms reverseDuration, should be about half way
        ticker.tick(.milliseconds(50))
        XCTAssertTrue(controller.value > 0.0 && controller.value < 1.0)

        // At 150ms past 100ms reverseDuration, should be done
        ticker.tick(.milliseconds(150))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    // MARK: - toggle() Tests

    /// Test toggle() when dismissed goes forward.
    func testToggleFromDismissed() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.status, .dismissed)
        controller.toggle()
        XCTAssertEqual(controller.status, .forward)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    /// Test toggle() when completed goes reverse.
    func testToggleFromCompleted() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.status, .completed)
        controller.toggle()
        XCTAssertEqual(controller.status, .reverse)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    // MARK: - animateTo() Tests

    /// Test animateTo() animates to a target value.
    func testAnimateToTarget() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.animateTo(0.5)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .forward)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 0.5, accuracy: 0.01)

        controller.dispose()
    }

    /// Test animateTo() with explicit duration.
    func testAnimateToWithDuration() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(200),
            vsync: vsync
        )

        controller.animateTo(1.0, duration: .milliseconds(100))
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        // With explicit 100ms duration, should be done after 100ms
        ticker.tick(.milliseconds(150))
        XCTAssertEqual(controller.value, 1.0)
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    /// Test animateTo() when already at target completes immediately.
    func testAnimateToAlreadyAtTarget() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.animateTo(1.0)
        // Should complete immediately since already at target
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    // MARK: - animateBack() Tests

    /// Test animateBack() animates backward to a target value.
    func testAnimateBack() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.animateBack(0.0)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .reverse)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    // MARK: - stop() Tests

    /// Test stop() halts a running animation.
    func testStop() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(30))
        let valueAtStop = controller.value

        controller.stop()
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(controller.value, valueAtStop, "Value should remain where it was stopped")

        controller.dispose()
    }

    /// Test stop() does not trigger status change notifications.
    func testStopDoesNotNotify() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(30))

        var statusChangedAfterStop = false
        controller.addStatusListener { _ in
            statusChangedAfterStop = true
        }

        controller.stop()
        XCTAssertFalse(statusChangedAfterStop)

        controller.dispose()
    }

    // MARK: - reset() Tests

    /// Test reset() sets value to lowerBound and status to dismissed.
    func testReset() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 0.5,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.reset()
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    /// Test reset() stops a running animation.
    func testResetStopsAnimation() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        controller.reset()
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(controller.value, 0.0)

        controller.dispose()
    }

    /// Test reset() with custom bounds resets to lowerBound.
    func testResetWithCustomBounds() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 15.0,
            duration: .milliseconds(100),
            lowerBound: 10.0,
            upperBound: 20.0,
            vsync: vsync
        )

        controller.reset()
        XCTAssertEqual(controller.value, 10.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    // MARK: - dispose() Tests

    /// Test dispose() cleans up the ticker.
    func testDispose() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.dispose()
        // After dispose, the ticker is nil internally
        // We verify by checking toStringDetails contains DISPOSED
        let details = controller.toStringDetails()
        XCTAssertTrue(details.contains("DISPOSED"))
    }

    /// Test dispose() clears listeners.
    func testDisposeClearsListeners() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var listenerCalled = false
        controller.addListener { listenerCalled = true }
        controller.addStatusListener { _ in listenerCalled = true }

        controller.dispose()
        // After dispose, listeners should be cleared - no crash when notified externally
        XCTAssertFalse(listenerCalled)
    }

    // MARK: - Listener Notification Tests

    /// Test addListener/removeListener and value change notifications.
    func testListenerNotifications() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var callCount = 0
        let listener: VoidCallback = { callCount += 1 }

        controller.addListener(listener)

        // Setting value should notify listeners
        controller.value = 0.5
        XCTAssertEqual(callCount, 1)

        controller.value = 0.7
        XCTAssertEqual(callCount, 2)

        // Remove listener
        controller.removeListener(listener)

        controller.value = 0.9
        XCTAssertEqual(callCount, 2, "Removed listener should not be called")

        controller.dispose()
    }

    /// Test that forward() ticks notify listeners.
    func testListenerNotifiedDuringForward() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var callCount = 0
        controller.addListener { callCount += 1 }

        controller.forward()
        let ticker = vsync.lastTicker!

        ticker.tick(.milliseconds(30))
        XCTAssertGreaterThan(callCount, 0, "Listener should be called on ticks")

        let countAfterFirstTick = callCount

        ticker.tick(.milliseconds(60))
        XCTAssertGreaterThan(callCount, countAfterFirstTick)

        controller.dispose()
    }

    /// Test multiple listeners are all notified.
    func testMultipleListeners() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var count1 = 0
        var count2 = 0
        controller.addListener { count1 += 1 }
        controller.addListener { count2 += 1 }

        controller.value = 0.5
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 1)

        controller.dispose()
    }

    // MARK: - Status Listener Notification Tests

    /// Test addStatusListener/removeStatusListener and status change notifications.
    func testStatusListenerNotifications() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var statuses: [AnimationStatus] = []
        let listener: AnimationStatusListener = { status in
            statuses.append(status)
        }

        controller.addStatusListener(listener)

        controller.forward()
        XCTAssertTrue(statuses.contains(.forward))

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertTrue(statuses.contains(.completed))

        controller.dispose()
    }

    /// Test removeStatusListener stops notifications.
    func testRemoveStatusListener() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var callCount = 0
        let listener: AnimationStatusListener = { _ in callCount += 1 }

        controller.addStatusListener(listener)

        controller.forward()
        let countAfterForward = callCount

        controller.stop()
        controller.removeStatusListener(listener)

        controller.value = 0.0
        controller.forward()
        XCTAssertEqual(callCount, countAfterForward, "Removed listener should not be called")

        controller.dispose()
    }

    /// Test full forward/reverse cycle status transitions.
    func testFullCycleStatusTransitions() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var statuses: [AnimationStatus] = []
        controller.addStatusListener { status in
            statuses.append(status)
        }

        // Forward: dismissed -> forward -> completed
        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(statuses, [.forward, .completed])

        // Reverse: completed -> reverse -> dismissed
        statuses.removeAll()
        controller.reverse()
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(statuses, [.reverse, .dismissed])

        controller.dispose()
    }

    // MARK: - repeat() Tests

    /// Test repeat() creates a repeating animation.
    func testRepeat() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.repeat()
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        // Tick partway through first cycle
        ticker.tick(.milliseconds(50))
        let midValue = controller.value
        XCTAssertTrue(midValue > 0.0 && midValue < 1.0,
            "Value should be mid-range at half period, got \(midValue)")

        controller.dispose()
    }

    /// Test repeat() with count finishes after specified cycles.
    func testRepeatWithCount() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.repeat(count: 2)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!

        // Tick past 2 cycles (200ms total)
        ticker.tick(.milliseconds(250))
        XCTAssertFalse(controller.isAnimating, "Should stop after 2 cycles")

        controller.dispose()
    }

    /// Test repeat(reverse:) oscillates between forward and reverse.
    func testRepeatWithReverse() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        var statuses: [AnimationStatus] = []
        controller.addStatusListener { status in
            statuses.append(status)
        }

        controller.repeat(reverse: true)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        // First half-cycle should be forward
        ticker.tick(.milliseconds(50))
        XCTAssertEqual(controller.status, .forward)

        // Second half-cycle should be reverse
        ticker.tick(.milliseconds(150))
        XCTAssertEqual(controller.status, .reverse)

        controller.dispose()
    }

    /// Test repeat() with custom min/max.
    func testRepeatWithCustomMinMax() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.repeat(min: 0.2, max: 0.8)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(50))
        let midValue = controller.value
        XCTAssertGreaterThanOrEqual(midValue, 0.2)
        XCTAssertLessThanOrEqual(midValue, 0.8)

        controller.dispose()
    }

    // MARK: - fling() Tests

    /// Test fling() with positive velocity completes the animation.
    func testFlingPositiveVelocity() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.fling()
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .forward)

        let ticker = vsync.lastTicker!
        // Fling with spring simulation - tick enough for it to settle
        ticker.tick(.milliseconds(500))
        // Spring should have settled near upperBound
        XCTAssertEqual(controller.value, 1.0)
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    /// Test fling() with negative velocity reverses the animation.
    func testFlingNegativeVelocity() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.fling(velocity: -1.0)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .reverse)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(500))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    /// Test fling() with custom spring description.
    func testFlingWithCustomSpring() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        let spring = SpringDescription(mass: 1.0, stiffness: 500.0, ratio: 1.0)
        controller.fling(velocity: 1.0, springDescription: spring)
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(500))
        XCTAssertEqual(controller.value, 1.0)

        controller.dispose()
    }

    // MARK: - Velocity Tests

    /// Test velocity is zero when not animating.
    func testVelocityWhenNotAnimating() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.velocity, 0.0)

        controller.dispose()
    }

    /// Test velocity is non-zero when animating.
    func testVelocityWhenAnimating() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(50))

        XCTAssertTrue(controller.isAnimating)
        XCTAssertGreaterThan(controller.velocity, 0.0, "Velocity should be positive during forward animation")

        controller.dispose()
    }

    // MARK: - lastElapsedDuration Tests

    /// Test lastElapsedDuration is nil when not animating.
    func testLastElapsedDurationNil() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertNil(controller.lastElapsedDuration)

        controller.dispose()
    }

    /// Test lastElapsedDuration updates during animation.
    func testLastElapsedDurationUpdates() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!

        ticker.tick(.milliseconds(50))
        XCTAssertNotNil(controller.lastElapsedDuration)

        controller.dispose()
    }

    /// Test lastElapsedDuration is nil after stop.
    func testLastElapsedDurationNilAfterStop() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(50))

        controller.stop()
        XCTAssertNil(controller.lastElapsedDuration)

        controller.dispose()
    }

    // MARK: - animateWith() Tests

    /// Test animateWith() drives animation with a custom simulation.
    func testAnimateWith() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        let spring = SpringSimulation(
            kFlingSpringDescription,
            0.0,
            1.0 + kFlingTolerance.distance,
            1.0
        )
        spring.tolerance = kFlingTolerance

        controller.animateWith(spring)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .forward, "animateWith always sets direction to forward")

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(500))

        controller.dispose()
    }

    /// Test animateBackWith() drives animation in reverse with a custom simulation.
    func testAnimateBackWith() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(100),
            vsync: vsync
        )

        let spring = SpringSimulation(
            kFlingSpringDescription,
            1.0,
            0.0 - kFlingTolerance.distance,
            -1.0
        )
        spring.tolerance = kFlingTolerance

        controller.animateBackWith(spring)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .reverse, "animateBackWith always sets direction to reverse")

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(500))

        controller.dispose()
    }

    // MARK: - debugLabel Tests

    /// Test debugLabel is included in string representation.
    func testDebugLabel() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            debugLabel: "testAnim",
            vsync: vsync
        )

        let details = controller.toStringDetails()
        XCTAssertTrue(details.contains("testAnim"), "Debug label should appear in toStringDetails()")

        controller.dispose()
    }

    /// Test toStringDetails when paused shows "paused" and when disposed shows "DISPOSED".
    func testToStringDetailsDisposed() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        // Get details before dispose
        let beforeDetails = controller.toStringDetails()
        XCTAssertTrue(beforeDetails.contains("paused"))

        controller.dispose()

        let afterDetails = controller.toStringDetails()
        XCTAssertTrue(afterDetails.contains("DISPOSED"))
    }

    // MARK: - AnimationBehavior Tests

    /// Test that bounded controllers default to AnimationBehavior.normal.
    func testBoundedDefaultBehavior() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertEqual(controller.animationBehavior, .normal)

        controller.dispose()
    }

    /// Test that unbounded controllers default to AnimationBehavior.preserve.
    func testUnboundedDefaultBehavior() {
        let vsync = MockTickerProvider()
        let controller = AnimationController(
            unboundedValue: 0.0,
            vsync: vsync
        )

        XCTAssertEqual(controller.animationBehavior, .preserve)

        controller.dispose()
    }

    /// Test custom AnimationBehavior.
    func testCustomAnimationBehavior() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            animationBehavior: .preserve,
            vsync: vsync
        )

        XCTAssertEqual(controller.animationBehavior, .preserve)

        controller.dispose()
    }

    // MARK: - view Property Tests

    /// Test view returns self as Animation<Double>.
    func testViewProperty() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        let view: Animation<Double> = controller.view
        XCTAssertEqual(view.value, controller.value)
        XCTAssertEqual(view.status, controller.status)

        controller.dispose()
    }

    // MARK: - Duration Property Tests

    /// Test setting duration property after construction.
    func testDurationPropertyMutable() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.duration = .milliseconds(200)

        controller.forward()
        let ticker = vsync.lastTicker!

        // At 100ms with a 200ms duration, should be ~halfway
        ticker.tick(.milliseconds(100))
        XCTAssertTrue(controller.value > 0.3 && controller.value < 0.7,
            "Value should be mid-range at 100ms with 200ms duration, got \(controller.value)")
        XCTAssertTrue(controller.isAnimating)

        controller.dispose()
    }

    /// Test setting reverseDuration after construction.
    func testReverseDurationPropertyMutable() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 1.0,
            duration: .milliseconds(200),
            vsync: vsync
        )

        controller.reverseDuration = .milliseconds(50)

        controller.reverse()
        let ticker = vsync.lastTicker!

        // With 50ms reverseDuration, should complete quickly
        ticker.tick(.milliseconds(100))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    // MARK: - resync() Tests

    /// Test resync() creates a new ticker from a new provider.
    func testResync() {
        let vsync1 = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync1
        )

        let vsync2 = MockTickerProvider()
        controller.resync(vsync2)

        // Should be able to start animation with new ticker
        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync2.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    // MARK: - Edge Case Tests

    /// Test forward then reverse without completing forward first.
    func testForwardThenReverseInterrupted() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(30))

        let midValue = controller.value
        XCTAssertTrue(midValue > 0.0 && midValue < 1.0,
            "Value should be mid-range at 30ms, got \(midValue)")

        // Reverse before forward completes
        controller.reverse()
        XCTAssertEqual(controller.status, .reverse)
        XCTAssertTrue(controller.isAnimating)

        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.value, 0.0)
        XCTAssertEqual(controller.status, .dismissed)

        controller.dispose()
    }

    /// Test animating to current value completes immediately with zero duration.
    func testAnimateToCurrentValue() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            value: 0.5,
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.animateTo(0.5)
        // Animating to the current value should result in zero-duration and
        // complete immediately
        XCTAssertFalse(controller.isAnimating)

        controller.dispose()
    }

    /// Test multiple forward calls - second forward restarts animation.
    func testMultipleForwardCalls() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        controller.forward()
        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.status, .completed)

        // Forward from 0 again
        controller.forward(from: 0.0)
        XCTAssertTrue(controller.isAnimating)
        XCTAssertEqual(controller.status, .forward)

        ticker.tick(.milliseconds(200))
        XCTAssertEqual(controller.status, .completed)

        controller.dispose()
    }

    /// Test isAnimating reflects ticker state correctly.
    func testIsAnimatingState() {
        let vsync = MockTickerProvider()
        let controller = makeBoundedController(
            duration: .milliseconds(100),
            vsync: vsync
        )

        XCTAssertFalse(controller.isAnimating)

        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        controller.stop()
        XCTAssertFalse(controller.isAnimating)

        controller.forward()
        XCTAssertTrue(controller.isAnimating)

        let ticker = vsync.lastTicker!
        ticker.tick(.milliseconds(200))
        XCTAssertFalse(controller.isAnimating, "Should not be animating after completing")

        controller.dispose()
    }

    // MARK: - InterpolationSimulation Tests

    /// Test InterpolationSimulation produces correct values at boundaries.
    func testInterpolationSimulationBoundaries() {
        let sim = InterpolationSimulation(
            0.0, 1.0, .milliseconds(100), Curves.linear, 1.0
        )

        XCTAssertEqual(sim.x(0.0), 0.0, "Should be at begin at t=0")
        XCTAssertEqual(sim.x(0.1), 1.0, "Should be at end at t=duration")
    }

    /// Test InterpolationSimulation isDone after duration.
    func testInterpolationSimulationIsDone() {
        let sim = InterpolationSimulation(
            0.0, 1.0, .milliseconds(100), Curves.linear, 1.0
        )

        XCTAssertFalse(sim.isDone(0.05))
        XCTAssertTrue(sim.isDone(0.2))
    }

    /// Test InterpolationSimulation mid-range interpolation.
    func testInterpolationSimulationMidRange() {
        let sim = InterpolationSimulation(
            0.0, 1.0, .milliseconds(100), Curves.linear, 1.0
        )

        // At 50ms (0.05s) with 100ms (0.1s) duration, t = 0.5
        let midValue = sim.x(0.05)
        XCTAssertEqual(midValue, 0.5, accuracy: 0.01)
    }

    // MARK: - RepeatingSimulation Tests

    /// Test RepeatingSimulation oscillates correctly with reverse.
    func testRepeatingSimulationOscillates() {
        var directions: [AnimationDirection] = []
        let sim = RepeatingSimulation(
            0.0,
            min: 0.0,
            max: 1.0,
            reverse: true,
            period: .milliseconds(100),
            directionSetter: { dir in directions.append(dir) },
            count: nil
        )

        // At t=0, should be at min (forward)
        let v0 = sim.x(0.0)
        XCTAssertEqual(v0, 0.0, accuracy: 0.01)

        // Should not be done when count is nil and time is finite
        XCTAssertFalse(sim.isDone(0.5))
    }

    /// Test RepeatingSimulation with count is done after count periods.
    func testRepeatingSimulationDoneWithCount() {
        let sim = RepeatingSimulation(
            0.0,
            min: 0.0,
            max: 1.0,
            reverse: false,
            period: .milliseconds(100),
            directionSetter: { _ in },
            count: 2
        )

        // After 2 periods (0.2s), should be done
        XCTAssertTrue(sim.isDone(0.2))
        XCTAssertFalse(sim.isDone(0.1))
    }

    // MARK: - AnimationDirection Tests

    /// Test AnimationDirection enum cases.
    func testAnimationDirectionCases() {
        let directions: [AnimationDirection] = [.forward, .reverse]
        XCTAssertEqual(directions.count, 2)
    }

    // MARK: - AnimationBehavior Enum Tests

    /// Test AnimationBehavior enum cases.
    func testAnimationBehaviorCases() {
        let behaviors: [AnimationBehavior] = [.normal, .preserve]
        XCTAssertEqual(behaviors.count, 2)
    }
}
