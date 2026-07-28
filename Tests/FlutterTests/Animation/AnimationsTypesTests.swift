// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for animation types migrated from animations.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/animations_test.dart`
final class AnimationsTypesTests: XCTestCase {

    // MARK: - AlwaysCompleteAnimation Tests

    func testAlwaysCompleteAnimationValue() {
        XCTAssertEqual(kAlwaysCompleteAnimation.value, 1.0)
    }

    func testAlwaysCompleteAnimationStatus() {
        XCTAssertEqual(kAlwaysCompleteAnimation.status, .completed)
    }

    func testAlwaysCompleteAnimationDescription() {
        XCTAssertEqual(kAlwaysCompleteAnimation.description, "kAlwaysCompleteAnimation")
    }

    func testAlwaysCompleteAnimationListenersAreNoOps() {
        // These should not crash
        kAlwaysCompleteAnimation.addListener {}
        kAlwaysCompleteAnimation.removeListener {}
        kAlwaysCompleteAnimation.addStatusListener { _ in }
        kAlwaysCompleteAnimation.removeStatusListener { _ in }
    }

    // MARK: - AlwaysDismissedAnimation Tests

    func testAlwaysDismissedAnimationValue() {
        XCTAssertEqual(kAlwaysDismissedAnimation.value, 0.0)
    }

    func testAlwaysDismissedAnimationStatus() {
        XCTAssertEqual(kAlwaysDismissedAnimation.status, .dismissed)
    }

    func testAlwaysDismissedAnimationDescription() {
        XCTAssertEqual(kAlwaysDismissedAnimation.description, "kAlwaysDismissedAnimation")
    }

    // MARK: - AlwaysStoppedAnimation Tests

    func testAlwaysStoppedAnimationValue() {
        let animation = AlwaysStoppedAnimation<Double>(0.5)
        XCTAssertEqual(animation.value, 0.5)
    }

    func testAlwaysStoppedAnimationStatus() {
        let animation = AlwaysStoppedAnimation<Double>(0.5)
        XCTAssertEqual(animation.status, .forward)
    }

    func testAlwaysStoppedAnimationToStringDetails() {
        let animation = AlwaysStoppedAnimation<Double>(0.5)
        let details = animation.toStringDetails()
        XCTAssertTrue(details.contains("0.5"))
        XCTAssertTrue(details.contains("paused"))
    }

    func testAlwaysStoppedAnimationListenersAreNoOps() {
        let animation = AlwaysStoppedAnimation<Double>(0.5)
        animation.addListener {}
        animation.removeListener {}
        animation.addStatusListener { _ in }
        animation.removeStatusListener { _ in }
    }

    func testAlwaysStoppedAnimationWithString() {
        let animation = AlwaysStoppedAnimation<String>("hello")
        XCTAssertEqual(animation.value, "hello")
        XCTAssertEqual(animation.status, .forward)
    }

    // MARK: - ProxyAnimation Tests

    /// **Dart Test:** `animations_test.dart:54-61`
    func testProxyAnimationDefaultValues() {
        let animation = ProxyAnimation()
        XCTAssertEqual(animation.value, 0.0)
        XCTAssertEqual(animation.status, .dismissed)
    }

    func testProxyAnimationDescription() {
        let animation = ProxyAnimation()
        let desc = animation.description
        XCTAssertTrue(desc.contains("ProxyAnimation"))
        XCTAssertTrue(desc.contains("nil"))
    }

    func testProxyAnimationWithParent() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let animation = ProxyAnimation(parent)
        XCTAssertEqual(animation.value, 0.5)
        XCTAssertEqual(animation.status, .forward)
    }

    func testProxyAnimationSetParentDescription() {
        let animation = ProxyAnimation()
        animation.parent = kAlwaysDismissedAnimation
        let desc = animation.description
        XCTAssertTrue(desc.contains("ProxyAnimation"))
    }

    /// **Dart Test:** `animations_test.dart:63-78`
    func testProxyAnimationSetParentGeneratesValueChanged() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        var didReceiveCallback = false
        let animation = ProxyAnimation()
        animation.addListener { didReceiveCallback = true }

        XCTAssertFalse(didReceiveCallback)

        // Setting parent with different value should notify
        animation.parent = parent
        XCTAssertTrue(didReceiveCallback)

        didReceiveCallback = false
        XCTAssertFalse(didReceiveCallback)

        // Changing parent's value should notify via forwarded listener
        parent.testValue = 0.6
        parent.fireListeners()
        XCTAssertTrue(didReceiveCallback)
    }

    func testProxyAnimationSetParentGeneratesStatusChanged() {
        let parent = MutableTestAnimation(status: .forward, value: 0.0)
        var receivedStatus: AnimationStatus?
        let animation = ProxyAnimation()
        animation.addStatusListener { status in receivedStatus = status }

        // Default status is .dismissed, setting parent with .forward should notify
        animation.parent = parent
        XCTAssertEqual(receivedStatus, .forward)
    }

    func testProxyAnimationChangeParent() {
        let parent1 = MutableTestAnimation(status: .forward, value: 0.3)
        let parent2 = MutableTestAnimation(status: .completed, value: 0.9)

        let animation = ProxyAnimation(parent1)
        XCTAssertEqual(animation.value, 0.3)

        animation.parent = parent2
        XCTAssertEqual(animation.value, 0.9)
        XCTAssertEqual(animation.status, .completed)
    }

    func testProxyAnimationSetSameParentIsNoOp() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let animation = ProxyAnimation(parent)
        var callCount = 0
        animation.addListener { callCount += 1 }

        // Setting the same parent should be a no-op (identity check)
        animation.parent = parent
        XCTAssertEqual(callCount, 0)
    }

    func testProxyAnimationSetParentToNilCachesValues() {
        let parent = MutableTestAnimation(status: .completed, value: 0.8)
        let animation = ProxyAnimation(parent)
        XCTAssertEqual(animation.value, 0.8)
        XCTAssertEqual(animation.status, .completed)

        animation.parent = nil
        // After setting parent to nil, cached values should be used
        XCTAssertEqual(animation.value, 0.8)
        XCTAssertEqual(animation.status, .completed)
    }

    // MARK: - ReverseAnimation Tests

    func testReverseAnimationValue() {
        let parent = MutableTestAnimation(status: .forward, value: 0.3)
        let reverse = ReverseAnimation(parent)
        XCTAssertEqual(reverse.value, 0.7, accuracy: 1e-10)
    }

    func testReverseAnimationValueAtExtremes() {
        let parent = MutableTestAnimation(status: .completed, value: 1.0)
        let reverse = ReverseAnimation(parent)
        XCTAssertEqual(reverse.value, 0.0)

        parent.testValue = 0.0
        parent.testStatus = .dismissed
        XCTAssertEqual(reverse.value, 1.0)
    }

    func testReverseAnimationStatusReversal() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let reverse = ReverseAnimation(parent)

        XCTAssertEqual(reverse.status, .reverse)

        parent.testStatus = .reverse
        XCTAssertEqual(reverse.status, .forward)

        parent.testStatus = .completed
        XCTAssertEqual(reverse.status, .dismissed)

        parent.testStatus = .dismissed
        XCTAssertEqual(reverse.status, .completed)
    }

    /// **Dart Test:** `animations_test.dart:80-98`
    func testReverseAnimationCallsListeners() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        var didReceiveCallback = false
        let listener: VoidCallback = { didReceiveCallback = true }

        let reverse = ReverseAnimation(parent)
        reverse.addListener(listener)

        XCTAssertFalse(didReceiveCallback)
        parent.testValue = 0.6
        parent.fireListeners()
        XCTAssertTrue(didReceiveCallback)

        didReceiveCallback = false
        reverse.removeListener(listener)
        parent.testValue = 0.7
        parent.fireListeners()
        XCTAssertFalse(didReceiveCallback)
    }

    func testReverseAnimationStatusListeners() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        var receivedStatuses: [AnimationStatus] = []

        let reverse = ReverseAnimation(parent)
        reverse.addStatusListener { status in receivedStatuses.append(status) }

        // Trigger a status change on parent
        parent.testStatus = .completed
        parent.fireStatusListeners(.completed)
        // ReverseAnimation should reverse: .completed -> .dismissed
        XCTAssertEqual(receivedStatuses, [.dismissed])

        parent.testStatus = .reverse
        parent.fireStatusListeners(.reverse)
        // .reverse -> .forward
        XCTAssertEqual(receivedStatuses, [.dismissed, .forward])
    }

    func testReverseAnimationDescription() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let reverse = ReverseAnimation(parent)
        let desc = reverse.description
        XCTAssertTrue(desc.contains("ReverseAnimation"))
    }

    // MARK: - CurvedAnimation Tests

    func testCurvedAnimationWithLinearCurve() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())
        XCTAssertEqual(curved.value, 0.5, accuracy: 1e-10)
    }

    func testCurvedAnimationAtExtremes() {
        let parent = MutableTestAnimation(status: .dismissed, value: 0.0)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())
        XCTAssertEqual(curved.value, 0.0)

        parent.testValue = 1.0
        parent.testStatus = .completed
        XCTAssertEqual(curved.value, 1.0)
    }

    func testCurvedAnimationForwardCurve() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        // Use a curve that doubles the value (clamped)
        let curved = CurvedAnimation(parent: parent, curve: DoublingCurve())
        // DoublingCurve.transform(0.5) = 1.0
        XCTAssertEqual(curved.value, 1.0, accuracy: 1e-10)
    }

    func testCurvedAnimationReverseCurve() {
        let parent = MutableTestAnimation(status: .reverse, value: 0.5)
        let curved = CurvedAnimation(
            parent: parent,
            curve: LinearCurve(),
            reverseCurve: DoublingCurve()
        )
        // In reverse, should use reverseCurve
        // After parent status goes to .reverse, _curveDirection should be set
        // The _useForwardCurve check: reverseCurve != nil && (_curveDirection ?? parent.status) == .reverse
        // So it should use the reverseCurve
        // But curveDirection is set only through status listener...
        // Let's update via status notification
        parent.fireStatusListeners(.reverse)
        // Now _curveDirection should be .reverse
        // DoublingCurve.transform(0.5) = 1.0
        XCTAssertEqual(curved.value, 1.0, accuracy: 1e-10)
    }

    func testCurvedAnimationNoReverseCurveUsesForwardCurve() {
        let parent = MutableTestAnimation(status: .reverse, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: DoublingCurve())
        // No reverseCurve, so forward curve is used even in reverse
        XCTAssertEqual(curved.value, 1.0, accuracy: 1e-10)
    }

    func testCurvedAnimationDispose() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())
        XCTAssertFalse(curved.isDisposed)
        curved.dispose()
        XCTAssertTrue(curved.isDisposed)
    }

    func testCurvedAnimationDelegatesListeners() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())

        var listenerCalled = false
        curved.addListener { listenerCalled = true }

        parent.fireListeners()
        XCTAssertTrue(listenerCalled)
    }

    func testCurvedAnimationDelegatesStatus() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())
        XCTAssertEqual(curved.status, .forward)

        parent.testStatus = .completed
        XCTAssertEqual(curved.status, .completed)
    }

    func testCurvedAnimationDescriptionWithoutReverseCurve() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(parent: parent, curve: LinearCurve())
        let desc = curved.description
        XCTAssertTrue(desc.contains("LinearCurve"))
    }

    func testCurvedAnimationDescriptionWithReverseCurve() {
        let parent = MutableTestAnimation(status: .forward, value: 0.5)
        let curved = CurvedAnimation(
            parent: parent,
            curve: LinearCurve(),
            reverseCurve: DoublingCurve()
        )
        let desc = curved.description
        XCTAssertTrue(desc.contains("LinearCurve"))
        XCTAssertTrue(desc.contains("DoublingCurve"))
    }

    // MARK: - TrainHoppingAnimation Tests

    /// **Dart Test:** `animations_test.dart:100-121`
    func testTrainHoppingAnimation() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let nextTrain = MutableTestAnimation(status: .forward, value: 0.75)

        var didSwitchTrains = false
        let animation = TrainHoppingAnimation(
            currentTrain, nextTrain,
            onSwitchedTrain: { didSwitchTrains = true }
        )

        XCTAssertFalse(didSwitchTrains)
        XCTAssertEqual(animation.value, 0.5)

        // The mode should be .minimize since current (0.5) < next (0.75)
        // When next's value drops below current, it should hop
        nextTrain.testValue = 0.25
        nextTrain.fireListeners()

        XCTAssertTrue(didSwitchTrains)
        XCTAssertEqual(animation.value, 0.25)
    }

    func testTrainHoppingAnimationDescription() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let nextTrain = MutableTestAnimation(status: .forward, value: 0.75)

        let animation = TrainHoppingAnimation(currentTrain, nextTrain)
        let desc = animation.description
        XCTAssertTrue(desc.contains("TrainHoppingAnimation"))
        XCTAssertTrue(desc.contains("next"))
    }

    func testTrainHoppingAnimationNoNext() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let animation = TrainHoppingAnimation(currentTrain, nil)

        XCTAssertEqual(animation.value, 0.5)
        let desc = animation.description
        XCTAssertTrue(desc.contains("no next"))
    }

    func testTrainHoppingAnimationSameValueImmediateHop() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let nextTrain = MutableTestAnimation(status: .forward, value: 0.5)

        let animation = TrainHoppingAnimation(currentTrain, nextTrain)
        // When both have same value, it immediately hops to next
        // currentTrain should now be nextTrain
        XCTAssertTrue(animation.currentTrain === nextTrain)
    }

    func testTrainHoppingAnimationMaximizeMode() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.75)
        let nextTrain = MutableTestAnimation(status: .forward, value: 0.5)

        var didSwitchTrains = false
        let animation = TrainHoppingAnimation(
            currentTrain, nextTrain,
            onSwitchedTrain: { didSwitchTrains = true }
        )

        // Mode should be .maximize since current (0.75) > next (0.5)
        XCTAssertFalse(didSwitchTrains)
        XCTAssertEqual(animation.value, 0.75)

        // When next rises above current, it should hop
        nextTrain.testValue = 0.8
        nextTrain.fireListeners()

        XCTAssertTrue(didSwitchTrains)
        XCTAssertEqual(animation.value, 0.8)
    }

    func testTrainHoppingAnimationDispose() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let animation = TrainHoppingAnimation(currentTrain, nil)

        // Should not crash
        animation.dispose()
    }

    func testTrainHoppingAnimationStatusForwarded() {
        let currentTrain = MutableTestAnimation(status: .forward, value: 0.5)
        let animation = TrainHoppingAnimation(currentTrain, nil)
        XCTAssertEqual(animation.status, .forward)

        currentTrain.testStatus = .completed
        XCTAssertEqual(animation.status, .completed)
    }

    // MARK: - CompoundAnimation Tests

    func testCompoundAnimationStatusWhenNextIsAnimating() {
        let first = MutableTestAnimation(status: .completed, value: 1.0)
        let next = MutableTestAnimation(status: .forward, value: 0.5)

        let compound = TestCompoundAnimation(first: first, next: next)
        // When next is animating, its status takes precedence
        XCTAssertEqual(compound.status, .forward)
    }

    func testCompoundAnimationStatusWhenNextIsNotAnimating() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let next = MutableTestAnimation(status: .completed, value: 1.0)

        let compound = TestCompoundAnimation(first: first, next: next)
        // When next is not animating, first's status is used
        XCTAssertEqual(compound.status, .forward)
    }

    func testCompoundAnimationStatusBothStopped() {
        let first = MutableTestAnimation(status: .dismissed, value: 0.0)
        let next = MutableTestAnimation(status: .completed, value: 1.0)

        let compound = TestCompoundAnimation(first: first, next: next)
        // Neither is animating, so first's status is used
        XCTAssertEqual(compound.status, .dismissed)
    }

    func testCompoundAnimationDescription() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let next = MutableTestAnimation(status: .forward, value: 0.5)

        let compound = TestCompoundAnimation(first: first, next: next)
        let desc = compound.description
        XCTAssertTrue(desc.contains("TestCompoundAnimation"))
    }

    // MARK: - AnimationMean Tests

    /// **Dart Test:** `animations_test.dart:136-164`
    func testAnimationMeanValue() {
        let left = MutableTestAnimation(status: .forward, value: 0.5)
        let right = MutableTestAnimation(status: .forward, value: 0.0)

        let mean = AnimationMean(left: left, right: right)
        XCTAssertEqual(mean.value, 0.25, accuracy: 1e-10)
    }

    func testAnimationMeanValueBothZero() {
        let left = MutableTestAnimation(status: .forward, value: 0.0)
        let right = MutableTestAnimation(status: .forward, value: 0.0)

        let mean = AnimationMean(left: left, right: right)
        XCTAssertEqual(mean.value, 0.0)
    }

    func testAnimationMeanValueBothOne() {
        let left = MutableTestAnimation(status: .forward, value: 1.0)
        let right = MutableTestAnimation(status: .forward, value: 1.0)

        let mean = AnimationMean(left: left, right: right)
        XCTAssertEqual(mean.value, 1.0)
    }

    func testAnimationMeanListeners() {
        let left = MutableTestAnimation(status: .forward, value: 0.5)
        let right = MutableTestAnimation(status: .forward, value: 0.0)

        let mean = AnimationMean(left: left, right: right)
        var log: [Double] = []
        mean.addListener { log.append(mean.value) }

        right.testValue = 1.0
        right.fireListeners()

        XCTAssertEqual(mean.value, 0.75, accuracy: 1e-10)
        XCTAssertEqual(log, [0.75])

        mean.removeListener {}
        log.removeAll()

        left.testValue = 0.0
        left.fireListeners()

        XCTAssertEqual(mean.value, 0.5, accuracy: 1e-10)
        // After removing listener, log should still be empty
        // Note: our removeListener removes the last listener added, not a specific one
        XCTAssertTrue(log.isEmpty)
    }

    // MARK: - AnimationMax Tests

    /// **Dart Test:** `animations_test.dart:166-194`
    func testAnimationMaxValue() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let second = MutableTestAnimation(status: .forward, value: 0.0)

        let maxAnim = AnimationMax<Double>(first, second)
        XCTAssertEqual(maxAnim.value, 0.5)
    }

    func testAnimationMaxValueWhenSecondIsGreater() {
        let first = MutableTestAnimation(status: .forward, value: 0.3)
        let second = MutableTestAnimation(status: .forward, value: 0.7)

        let maxAnim = AnimationMax<Double>(first, second)
        XCTAssertEqual(maxAnim.value, 0.7)
    }

    func testAnimationMaxListeners() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let second = MutableTestAnimation(status: .forward, value: 0.0)

        let maxAnim = AnimationMax<Double>(first, second)
        var log: [Double] = []
        maxAnim.addListener { log.append(maxAnim.value) }

        second.testValue = 1.0
        second.fireListeners()

        XCTAssertEqual(maxAnim.value, 1.0)
        XCTAssertEqual(log, [1.0])

        maxAnim.removeListener {}
        log.removeAll()

        first.testValue = 0.0
        first.fireListeners()

        XCTAssertEqual(maxAnim.value, 1.0)
        XCTAssertTrue(log.isEmpty)
    }

    // MARK: - AnimationMin Tests

    /// **Dart Test:** `animations_test.dart:196-224`
    func testAnimationMinValue() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let second = MutableTestAnimation(status: .forward, value: 0.0)

        let minAnim = AnimationMin<Double>(first, second)
        XCTAssertEqual(minAnim.value, 0.0)
    }

    func testAnimationMinValueWhenFirstIsSmaller() {
        let first = MutableTestAnimation(status: .forward, value: 0.3)
        let second = MutableTestAnimation(status: .forward, value: 0.7)

        let minAnim = AnimationMin<Double>(first, second)
        XCTAssertEqual(minAnim.value, 0.3)
    }

    func testAnimationMinListeners() {
        let first = MutableTestAnimation(status: .forward, value: 0.5)
        let second = MutableTestAnimation(status: .forward, value: 0.0)

        let minAnim = AnimationMin<Double>(first, second)
        var log: [Double] = []
        minAnim.addListener { log.append(minAnim.value) }

        second.testValue = 1.0
        second.fireListeners()

        XCTAssertEqual(minAnim.value, 0.5)
        XCTAssertEqual(log, [0.5])

        minAnim.removeListener {}
        log.removeAll()

        first.testValue = 0.25
        first.fireListeners()

        XCTAssertEqual(minAnim.value, 0.25)
        XCTAssertTrue(log.isEmpty)
    }
}

// MARK: - Test Helpers

/// A mutable test animation that can fire listeners manually.
/// Used to simulate AnimationController behavior in tests without
/// depending on the actual AnimationController class.
private class MutableTestAnimation: Animation<Double> {
    var testStatus: AnimationStatus
    var testValue: Double

    private var _listeners: [VoidCallback] = []
    private var _statusListeners: [AnimationStatusListener] = []

    init(status: AnimationStatus, value: Double) {
        self.testStatus = status
        self.testValue = value
    }

    override var status: AnimationStatus { testStatus }
    override var value: Double { testValue }

    override func addListener(_ listener: @escaping VoidCallback) {
        _listeners.append(listener)
    }

    override func removeListener(_ listener: @escaping VoidCallback) {
        if !_listeners.isEmpty {
            _listeners.removeLast()
        }
    }

    override func addStatusListener(_ listener: @escaping AnimationStatusListener) {
        _statusListeners.append(listener)
    }

    override func removeStatusListener(_ listener: @escaping AnimationStatusListener) {
        if !_statusListeners.isEmpty {
            _statusListeners.removeLast()
        }
    }

    func fireListeners() {
        let local = _listeners
        for listener in local {
            listener()
        }
    }

    func fireStatusListeners(_ status: AnimationStatus) {
        let local = _statusListeners
        for listener in local {
            listener(status)
        }
    }
}

/// A concrete CompoundAnimation subclass for testing.
/// Returns the sum of first and next values.
private class TestCompoundAnimation: CompoundAnimation<Double> {
    override var value: Double {
        return first.value + next.value
    }
}

/// A simple linear curve for testing (transform returns t unchanged).
private struct LinearCurve: Curve {
    func transformInternal(_ t: Double) -> Double { t }
    var flipped: any Curve { self }
}

/// A curve that doubles the input value for testing.
/// Note: Only valid for internal values (not 0.0 or 1.0 which are short-circuited).
private struct DoublingCurve: Curve {
    func transformInternal(_ t: Double) -> Double { t * 2.0 }
    var flipped: any Curve { self }
}
