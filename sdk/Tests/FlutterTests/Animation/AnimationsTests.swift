// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for Animations types migrated from animations.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/animations_test.dart`
final class AnimationsTests: XCTestCase {

    // MARK: - kAlwaysCompleteAnimation Tests

    /// Test that kAlwaysCompleteAnimation has value 1.0 and status .completed.
    func testAlwaysCompleteAnimationValue() {
        XCTAssertEqual(kAlwaysCompleteAnimation.value, 1.0)
        XCTAssertEqual(kAlwaysCompleteAnimation.status, .completed)
    }

    func testAlwaysCompleteAnimationDescription() {
        XCTAssertEqual(kAlwaysCompleteAnimation.description, "kAlwaysCompleteAnimation")
    }

    func testAlwaysCompleteAnimationListenersAreNoOps() {
        // Should not crash
        kAlwaysCompleteAnimation.addListener({})
        kAlwaysCompleteAnimation.removeListener({})
        kAlwaysCompleteAnimation.addStatusListener({ _ in })
        kAlwaysCompleteAnimation.removeStatusListener({ _ in })
    }

    // MARK: - kAlwaysDismissedAnimation Tests

    func testAlwaysDismissedAnimationValue() {
        XCTAssertEqual(kAlwaysDismissedAnimation.value, 0.0)
        XCTAssertEqual(kAlwaysDismissedAnimation.status, .dismissed)
    }

    func testAlwaysDismissedAnimationDescription() {
        XCTAssertEqual(kAlwaysDismissedAnimation.description, "kAlwaysDismissedAnimation")
    }

    func testAlwaysDismissedAnimationListenersAreNoOps() {
        kAlwaysDismissedAnimation.addListener({})
        kAlwaysDismissedAnimation.removeListener({})
        kAlwaysDismissedAnimation.addStatusListener({ _ in })
        kAlwaysDismissedAnimation.removeStatusListener({ _ in })
    }

    // MARK: - AlwaysStoppedAnimation Tests

    func testAlwaysStoppedAnimationValue() {
        let animation = AlwaysStoppedAnimation(42.0)
        XCTAssertEqual(animation.value, 42.0)
        XCTAssertEqual(animation.status, .forward)
    }

    func testAlwaysStoppedAnimationString() {
        let animation = AlwaysStoppedAnimation("hello")
        XCTAssertEqual(animation.value, "hello")
        XCTAssertEqual(animation.status, .forward)
    }

    func testAlwaysStoppedAnimationListenersAreNoOps() {
        let animation = AlwaysStoppedAnimation(1.0)
        animation.addListener({})
        animation.removeListener({})
        animation.addStatusListener({ _ in })
        animation.removeStatusListener({ _ in })
    }

    func testAlwaysStoppedAnimationToStringDetails() {
        let animation = AlwaysStoppedAnimation(0.5)
        let details = animation.toStringDetails()
        XCTAssertTrue(details.contains("0.5"))
        XCTAssertTrue(details.contains("paused"))
    }

    // MARK: - ProxyAnimation Tests

    func testProxyAnimationDefaultNilParent() {
        let proxy = ProxyAnimation()
        XCTAssertEqual(proxy.value, 0.0)
        XCTAssertEqual(proxy.status, .dismissed)
        XCTAssertNil(proxy.parent)
    }

    func testProxyAnimationWithParent() {
        let mock = MockAnimation(value: 0.75, status: .forward)
        let proxy = ProxyAnimation(mock)
        XCTAssertEqual(proxy.value, 0.75)
        XCTAssertEqual(proxy.status, .forward)
    }

    func testProxyAnimationSetParent() {
        let proxy = ProxyAnimation()
        XCTAssertEqual(proxy.value, 0.0)
        XCTAssertEqual(proxy.status, .dismissed)

        let mock = MockAnimation(value: 0.5, status: .forward)
        proxy.parent = mock
        XCTAssertEqual(proxy.value, 0.5)
        XCTAssertEqual(proxy.status, .forward)
    }

    func testProxyAnimationSetParentToNilCachesValues() {
        let mock = MockAnimation(value: 0.8, status: .reverse)
        let proxy = ProxyAnimation(mock)
        XCTAssertEqual(proxy.value, 0.8)
        XCTAssertEqual(proxy.status, .reverse)

        proxy.parent = nil
        // Should cache the last known values from old parent
        XCTAssertEqual(proxy.value, 0.8)
        XCTAssertEqual(proxy.status, .reverse)
    }

    func testProxyAnimationSetParentNotifiesListenersOnValueChange() {
        let proxy = ProxyAnimation()
        var notified = false
        proxy.addListener { notified = true }

        let mock = MockAnimation(value: 0.5, status: .forward)
        proxy.parent = mock
        XCTAssertTrue(notified, "Should notify listeners when new parent has different value")
    }

    func testProxyAnimationSetParentNotifiesStatusListenersOnStatusChange() {
        let proxy = ProxyAnimation()
        var notifiedStatus: AnimationStatus?
        proxy.addStatusListener { status in notifiedStatus = status }

        let mock = MockAnimation(value: 0.0, status: .forward)
        proxy.parent = mock
        XCTAssertEqual(notifiedStatus, .forward, "Should notify status listeners when new parent has different status")
    }

    func testProxyAnimationSetSameParentDoesNothing() {
        let mock = MockAnimation(value: 0.5, status: .forward)
        let proxy = ProxyAnimation(mock)
        var notified = false
        proxy.addListener { notified = true }

        proxy.parent = mock  // Same parent, should not notify
        XCTAssertFalse(notified)
    }

    func testProxyAnimationDescriptionWithNilParent() {
        let proxy = ProxyAnimation()
        let desc = proxy.description
        XCTAssertTrue(desc.contains("nil"))
        XCTAssertTrue(desc.contains("0.000"))
    }

    func testProxyAnimationDescriptionWithParent() {
        let mock = MockAnimation(value: 0.5, status: .forward)
        let proxy = ProxyAnimation(mock)
        let desc = proxy.description
        XCTAssertTrue(desc.contains("\u{27A9}"))
    }

    // MARK: - ReverseAnimation Tests

    func testReverseAnimationValueInversion() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let reverse = ReverseAnimation(mock)
        XCTAssertEqual(reverse.value, 1.0)

        mock.testValue = 0.3
        XCTAssertEqual(reverse.value, 0.7, accuracy: 0.001)

        mock.testValue = 1.0
        XCTAssertEqual(reverse.value, 0.0)
    }

    func testReverseAnimationStatusReversal() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let reverse = ReverseAnimation(mock)
        XCTAssertEqual(reverse.status, .reverse)

        mock.testStatus = .reverse
        XCTAssertEqual(reverse.status, .forward)

        mock.testStatus = .completed
        XCTAssertEqual(reverse.status, .dismissed)

        mock.testStatus = .dismissed
        XCTAssertEqual(reverse.status, .completed)
    }

    func testReverseAnimationForwardsValueListeners() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let reverse = ReverseAnimation(mock)
        var called = false
        reverse.addListener { called = true }

        mock.notifyAllListeners()
        XCTAssertTrue(called)
    }

    func testReverseAnimationNotifiesStatusListenersWithReversedStatus() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let reverse = ReverseAnimation(mock)
        var receivedStatus: AnimationStatus?
        reverse.addStatusListener { status in receivedStatus = status }

        // Trigger status change on parent
        mock.testStatus = .completed
        mock.notifyAllStatusListeners()
        // The ReverseAnimation subscribes to parent status on didStartListening,
        // which happens lazily. Since we added a status listener, the reverse
        // should get notified with reversed status.
        XCTAssertEqual(receivedStatus, .dismissed)
    }

    func testReverseAnimationDescription() {
        let mock = MockAnimation(value: 0.5, status: .forward)
        let reverse = ReverseAnimation(mock)
        let desc = reverse.description
        XCTAssertTrue(desc.contains("\u{27AA}"))
    }

    // MARK: - CurvedAnimation Tests

    func testCurvedAnimationForwardCurve() {
        let mock = MockAnimation(value: 0.5, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestSquareCurve())
        // Square curve: transform(0.5) = 0.25
        XCTAssertEqual(curved.value, 0.25, accuracy: 0.001)
    }

    func testCurvedAnimationBoundaryValues() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestSquareCurve())
        XCTAssertEqual(curved.value, 0.0)

        mock.testValue = 1.0
        XCTAssertEqual(curved.value, 1.0)
    }

    func testCurvedAnimationReverseCurve() {
        let reverseCurve = TestIdentityCurve()
        let mock = MockAnimation(value: 0.5, status: .reverse)
        let curved = CurvedAnimation(
            parent: mock,
            curve: TestSquareCurve(),
            reverseCurve: reverseCurve
        )
        // When going reverse with a reverse curve, should use identity
        // which returns 0.5
        XCTAssertEqual(curved.value, 0.5, accuracy: 0.001)
    }

    func testCurvedAnimationForwardsListenersToParent() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestIdentityCurve())
        var called = false
        curved.addListener { called = true }

        mock.notifyAllListeners()
        XCTAssertTrue(called)
    }

    func testCurvedAnimationStatusFromParent() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestIdentityCurve())
        XCTAssertEqual(curved.status, .forward)

        mock.testStatus = .completed
        XCTAssertEqual(curved.status, .completed)
    }

    func testCurvedAnimationDispose() {
        let mock = MockAnimation(value: 0.0, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestIdentityCurve())
        XCTAssertFalse(curved.isDisposed)

        curved.dispose()
        XCTAssertTrue(curved.isDisposed)
    }

    func testCurvedAnimationDescriptionNilReverseCurve() {
        let mock = MockAnimation(value: 0.5, status: .forward)
        let curved = CurvedAnimation(parent: mock, curve: TestSquareCurve())
        let desc = curved.description
        XCTAssertTrue(desc.contains("\u{27A9}"))
    }

    // MARK: - TrainHoppingAnimation Tests

    func testTrainHoppingAnimationBasicProxy() {
        let train = MockAnimation(value: 0.5, status: .forward)
        let hopping = TrainHoppingAnimation(train, nil)
        XCTAssertEqual(hopping.value, 0.5)
        XCTAssertEqual(hopping.status, .forward)
        hopping.dispose()
    }

    func testTrainHoppingAnimationHopsWhenValuesCross() {
        let current = MockAnimation(value: 0.8, status: .forward)
        let next = MockAnimation(value: 0.5, status: .forward)

        var switched = false
        let hopping = TrainHoppingAnimation(current, next, onSwitchedTrain: {
            switched = true
        })
        // current > next, so mode is .maximize
        XCTAssertEqual(hopping.value, 0.8)

        // Simulate next crossing current
        next.testValue = 0.9
        next.notifyAllListeners()
        // After hop, should switch to next train
        XCTAssertTrue(switched)

        hopping.dispose()
    }

    func testTrainHoppingAnimationEqualValuesUseNext() {
        let current = MockAnimation(value: 0.5, status: .forward)
        let next = MockAnimation(value: 0.5, status: .reverse)

        let hopping = TrainHoppingAnimation(current, next)
        // Equal values: should immediately use next
        XCTAssertEqual(hopping.status, .reverse)
        hopping.dispose()
    }

    func testTrainHoppingAnimationDispose() {
        let current = MockAnimation(value: 0.5, status: .forward)
        let hopping = TrainHoppingAnimation(current, nil)
        // Should not crash
        hopping.dispose()
    }

    func testTrainHoppingAnimationDescription() {
        let current = MockAnimation(value: 0.5, status: .forward)
        let hopping = TrainHoppingAnimation(current, nil)
        let desc = hopping.description
        XCTAssertTrue(desc.contains("no next"))
        hopping.dispose()
    }

    func testTrainHoppingAnimationDescriptionWithNext() {
        let current = MockAnimation(value: 0.8, status: .forward)
        let next = MockAnimation(value: 0.2, status: .forward)
        let hopping = TrainHoppingAnimation(current, next)
        let desc = hopping.description
        XCTAssertTrue(desc.contains("next:"))
        hopping.dispose()
    }

    // MARK: - CompoundAnimation Tests (via AnimationMean)

    func testAnimationMeanValue() {
        let left = MockAnimation(value: 0.2, status: .forward)
        let right = MockAnimation(value: 0.8, status: .forward)
        let mean = AnimationMean(left: left, right: right)
        XCTAssertEqual(mean.value, 0.5, accuracy: 0.001)
    }

    func testAnimationMeanValueUpdates() {
        let left = MockAnimation(value: 0.0, status: .forward)
        let right = MockAnimation(value: 1.0, status: .forward)
        let mean = AnimationMean(left: left, right: right)
        XCTAssertEqual(mean.value, 0.5, accuracy: 0.001)

        left.testValue = 0.4
        right.testValue = 0.6
        XCTAssertEqual(mean.value, 0.5, accuracy: 0.001)

        left.testValue = 1.0
        right.testValue = 1.0
        XCTAssertEqual(mean.value, 1.0, accuracy: 0.001)
    }

    func testCompoundAnimationStatusPriority() {
        let first = MockAnimation(value: 0.0, status: .dismissed)
        let next = MockAnimation(value: 0.0, status: .dismissed)
        let mean = AnimationMean(left: first, right: next)

        // Neither animating: use first's status
        XCTAssertEqual(mean.status, .dismissed)

        // Next is animating: use next's status
        next.testStatus = .forward
        XCTAssertEqual(mean.status, .forward)

        // First is animating too: next still takes priority
        first.testStatus = .reverse
        XCTAssertEqual(mean.status, .forward)

        // Next stops: use first's status
        next.testStatus = .completed
        XCTAssertEqual(mean.status, .reverse)
    }

    func testCompoundAnimationDeduplicatesNotifications() {
        let first = MockAnimation(value: 0.5, status: .forward)
        let next = MockAnimation(value: 0.5, status: .forward)
        let mean = AnimationMean(left: first, right: next)

        var notifyCount = 0
        mean.addListener { notifyCount += 1 }

        // Change value so deduplication allows notification
        first.testValue = 0.6
        first.notifyAllListeners()
        XCTAssertEqual(notifyCount, 1)

        // Same value again: should not re-notify (deduplication)
        first.notifyAllListeners()
        XCTAssertEqual(notifyCount, 1)

        // Different value: should notify
        first.testValue = 0.7
        first.notifyAllListeners()
        XCTAssertEqual(notifyCount, 2)
    }

    // MARK: - AnimationMax Tests

    func testAnimationMaxValue() {
        let a = MockAnimation(value: 0.3, status: .forward)
        let b = MockAnimation(value: 0.7, status: .forward)
        let animMax = AnimationMax(a, b)
        XCTAssertEqual(animMax.value, 0.7, accuracy: 0.001)
    }

    func testAnimationMaxValueChanges() {
        let a = MockAnimation(value: 0.3, status: .forward)
        let b = MockAnimation(value: 0.7, status: .forward)
        let animMax = AnimationMax(a, b)

        a.testValue = 0.9
        XCTAssertEqual(animMax.value, 0.9, accuracy: 0.001)

        a.testValue = 0.1
        XCTAssertEqual(animMax.value, 0.7, accuracy: 0.001)
    }

    func testAnimationMaxEqualValues() {
        let a = MockAnimation(value: 0.5, status: .forward)
        let b = MockAnimation(value: 0.5, status: .forward)
        let animMax = AnimationMax(a, b)
        XCTAssertEqual(animMax.value, 0.5, accuracy: 0.001)
    }

    // MARK: - AnimationMin Tests

    func testAnimationMinValue() {
        let a = MockAnimation(value: 0.3, status: .forward)
        let b = MockAnimation(value: 0.7, status: .forward)
        let animMin = AnimationMin(a, b)
        XCTAssertEqual(animMin.value, 0.3, accuracy: 0.001)
    }

    func testAnimationMinValueChanges() {
        let a = MockAnimation(value: 0.3, status: .forward)
        let b = MockAnimation(value: 0.7, status: .forward)
        let animMin = AnimationMin(a, b)

        b.testValue = 0.1
        XCTAssertEqual(animMin.value, 0.1, accuracy: 0.001)

        b.testValue = 0.5
        XCTAssertEqual(animMin.value, 0.3, accuracy: 0.001)
    }

    func testAnimationMinEqualValues() {
        let a = MockAnimation(value: 0.5, status: .forward)
        let b = MockAnimation(value: 0.5, status: .forward)
        let animMin = AnimationMin(a, b)
        XCTAssertEqual(animMin.value, 0.5, accuracy: 0.001)
    }
}

// MARK: - Test Helpers

/// A controllable mock Animation for testing.
/// Supports adding/removing listeners and manually triggering notifications.
private class MockAnimation: Animation<Double> {
    var testValue: Double
    var testStatus: AnimationStatus

    private var _listeners: [VoidCallback] = []
    private var _statusListeners: [AnimationStatusListener] = []

    init(value: Double, status: AnimationStatus) {
        self.testValue = value
        self.testStatus = status
    }

    override var value: Double { testValue }
    override var status: AnimationStatus { testStatus }

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

    func notifyAllListeners() {
        let local = _listeners
        for listener in local {
            listener()
        }
    }

    func notifyAllStatusListeners() {
        let local = _statusListeners
        for listener in local {
            listener(testStatus)
        }
    }
}

/// A curve that squares the input: transformInternal(t) = t * t.
/// Maps 0.0 -> 0.0 and 1.0 -> 1.0 correctly.
private struct TestSquareCurve: Curve {
    func transformInternal(_ t: Double) -> Double { t * t }
}

/// An identity curve: transformInternal(t) = t.
private struct TestIdentityCurve: Curve {
    func transformInternal(_ t: Double) -> Double { t }
}
