// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for Animation types migrated from animation.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/animation_from_listener_test.dart`
/// **Dart Test Source:** `packages/flutter/test/animation/animations_test.dart`
final class AnimationTests: XCTestCase {

    // MARK: - AnimationStatus Enum Tests

    /// Test that AnimationStatus has all 4 expected cases.
    func testAnimationStatusCases() {
        let statuses: [AnimationStatus] = [.dismissed, .forward, .reverse, .completed]
        XCTAssertEqual(statuses.count, 4)
    }

    /// Test isDismissed returns true only for .dismissed.
    func testAnimationStatusIsDismissed() {
        XCTAssertTrue(AnimationStatus.dismissed.isDismissed)
        XCTAssertFalse(AnimationStatus.forward.isDismissed)
        XCTAssertFalse(AnimationStatus.reverse.isDismissed)
        XCTAssertFalse(AnimationStatus.completed.isDismissed)
    }

    /// Test isCompleted returns true only for .completed.
    func testAnimationStatusIsCompleted() {
        XCTAssertFalse(AnimationStatus.dismissed.isCompleted)
        XCTAssertFalse(AnimationStatus.forward.isCompleted)
        XCTAssertFalse(AnimationStatus.reverse.isCompleted)
        XCTAssertTrue(AnimationStatus.completed.isCompleted)
    }

    /// Test isAnimating returns true for .forward and .reverse.
    ///
    /// **Dart Source:** `animation.dart:42-45`
    func testAnimationStatusIsAnimating() {
        XCTAssertFalse(AnimationStatus.dismissed.isAnimating)
        XCTAssertTrue(AnimationStatus.forward.isAnimating)
        XCTAssertTrue(AnimationStatus.reverse.isAnimating)
        XCTAssertFalse(AnimationStatus.completed.isAnimating)
    }

    /// Test isForwardOrCompleted returns true for .forward and .completed.
    ///
    /// **Dart Source:** `animation.dart:54-57`
    func testAnimationStatusIsForwardOrCompleted() {
        XCTAssertFalse(AnimationStatus.dismissed.isForwardOrCompleted)
        XCTAssertTrue(AnimationStatus.forward.isForwardOrCompleted)
        XCTAssertFalse(AnimationStatus.reverse.isForwardOrCompleted)
        XCTAssertTrue(AnimationStatus.completed.isForwardOrCompleted)
    }

    // MARK: - Animation<T> Convenience Getters

    /// Test that Animation convenience getters delegate to status.
    func testAnimationConvenienceGetters() {
        let animation = TestAnimation(status: .dismissed, value: 0.0)
        XCTAssertTrue(animation.isDismissed)
        XCTAssertFalse(animation.isCompleted)
        XCTAssertFalse(animation.isAnimating)
        XCTAssertFalse(animation.isForwardOrCompleted)

        animation.testStatus = .completed
        XCTAssertFalse(animation.isDismissed)
        XCTAssertTrue(animation.isCompleted)
        XCTAssertFalse(animation.isAnimating)
        XCTAssertTrue(animation.isForwardOrCompleted)

        animation.testStatus = .forward
        XCTAssertFalse(animation.isDismissed)
        XCTAssertFalse(animation.isCompleted)
        XCTAssertTrue(animation.isAnimating)
        XCTAssertTrue(animation.isForwardOrCompleted)

        animation.testStatus = .reverse
        XCTAssertFalse(animation.isDismissed)
        XCTAssertFalse(animation.isCompleted)
        XCTAssertTrue(animation.isAnimating)
        XCTAssertFalse(animation.isForwardOrCompleted)
    }

    // MARK: - toStringDetails() Tests

    /// Test toStringDetails returns correct Unicode icons for each status.
    ///
    /// **Dart Source:** `animation.dart:369-376`
    func testToStringDetailsForwardIcon() {
        let animation = TestAnimation(status: .forward, value: 0.5)
        XCTAssertEqual(animation.toStringDetails(), "\u{25B6}")
    }

    func testToStringDetailsReverseIcon() {
        let animation = TestAnimation(status: .reverse, value: 0.5)
        XCTAssertEqual(animation.toStringDetails(), "\u{25C0}")
    }

    func testToStringDetailsCompletedIcon() {
        let animation = TestAnimation(status: .completed, value: 1.0)
        XCTAssertEqual(animation.toStringDetails(), "\u{23ED}")
    }

    func testToStringDetailsDismissedIcon() {
        let animation = TestAnimation(status: .dismissed, value: 0.0)
        XCTAssertEqual(animation.toStringDetails(), "\u{23EE}")
    }

    // MARK: - Animation description Tests

    /// Test that description includes the type name and status icon.
    func testAnimationDescription() {
        let animation = TestAnimation(status: .forward, value: 0.5)
        let desc = animation.description
        // Should contain the class name and the forward icon
        XCTAssertTrue(desc.contains("TestAnimation"))
        XCTAssertTrue(desc.contains("\u{25B6}"))
    }

    // MARK: - Animation.fromValueListenable Tests

    /// Test creating animation from ValueListenable.
    ///
    /// **Dart Test:** `animation_from_listener_test.dart:9-36`
    func testAnimationFromValueListenable() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier)

        XCTAssertEqual(animation.status, .forward)
        XCTAssertEqual(animation.value, 0.0)

        notifier.value = 1.0
        XCTAssertEqual(animation.value, 1.0)
    }

    /// Test that fromValueListenable status is always .forward.
    func testAnimationFromValueListenableStatusAlwaysForward() {
        let notifier = TestValueNotifier(42.0)
        let animation = Animation<Double>.fromValueListenable(notifier)

        XCTAssertEqual(animation.status, .forward)
        XCTAssertTrue(animation.isForwardOrCompleted)
        XCTAssertTrue(animation.isAnimating)
        XCTAssertFalse(animation.isDismissed)
        XCTAssertFalse(animation.isCompleted)
    }

    /// Test that fromValueListenable forwards listener notifications.
    ///
    /// **Dart Test:** `animation_from_listener_test.dart:20-35`
    func testAnimationFromValueListenableListeners() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier)

        var listenerCalled = false
        let listener: VoidCallback = { listenerCalled = true }

        animation.addListener(listener)
        notifier.value = 0.5
        notifier.notifyListeners()
        XCTAssertTrue(listenerCalled)

        listenerCalled = false
        animation.removeListener(listener)
        notifier.value = 0.2
        notifier.notifyListeners()
        XCTAssertFalse(listenerCalled)
    }

    /// Test fromValueListenable with transformer.
    ///
    /// **Dart Test:** `animation_from_listener_test.dart:38-53`
    func testAnimationFromValueListenableWithTransformer() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier) { input in
            return input / 10.0
        }

        XCTAssertEqual(animation.status, .forward)
        XCTAssertEqual(animation.value, 0.0)

        notifier.value = 10.0
        XCTAssertEqual(animation.value, 1.0)
    }

    /// Test that addStatusListener on fromValueListenable is a no-op
    /// (status never changes).
    func testAnimationFromValueListenableStatusListenerNoOp() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier)

        var statusListenerCalled = false
        animation.addStatusListener { _ in statusListenerCalled = true }

        notifier.value = 1.0
        notifier.notifyListeners()
        // Status listener should never be called since status never changes
        XCTAssertFalse(statusListenerCalled)
    }

    // MARK: - drive() Tests

    /// Test drive() chains an Animatable to an Animation<Double>.
    ///
    /// **Dart Test:** `animation_from_listener_test.dart:55-87`
    func testAnimationDrive() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier)

        let doubled = animation.drive(TestDoublingAnimatable())

        XCTAssertEqual(doubled.value, 0.0)
        XCTAssertEqual(doubled.status, .forward)

        notifier.value = 5.0
        XCTAssertEqual(doubled.value, 10.0)
    }

    /// Test drive() forwards listeners through the chain.
    func testAnimationDriveListeners() {
        let notifier = TestValueNotifier(0.0)
        let animation = Animation<Double>.fromValueListenable(notifier)
        let doubled = animation.drive(TestDoublingAnimatable())

        var listenerCalled = false
        let listener: VoidCallback = { listenerCalled = true }

        doubled.addListener(listener)
        notifier.value = 3.0
        notifier.notifyListeners()
        XCTAssertTrue(listenerCalled)

        listenerCalled = false
        doubled.removeListener(listener)
        notifier.value = 4.0
        notifier.notifyListeners()
        XCTAssertFalse(listenerCalled)
    }

    // MARK: - Animatable Tests

    /// Test Animatable.evaluate delegates to transform via animation value.
    func testAnimatableEvaluate() {
        let animatable = TestDoublingAnimatable()
        let animation = TestAnimation(status: .forward, value: 3.0)
        XCTAssertEqual(animatable.evaluate(animation), 6.0)
    }

    /// Test Animatable.animate creates an AnimatedEvaluation.
    func testAnimatableAnimate() {
        let animatable = TestDoublingAnimatable()
        let parent = TestAnimation(status: .forward, value: 4.0)
        let driven = animatable.animate(parent)

        XCTAssertEqual(driven.value, 8.0)
        XCTAssertEqual(driven.status, .forward)

        parent.testValue = 5.0
        XCTAssertEqual(driven.value, 10.0)
    }
}

// MARK: - Test Helpers

/// A concrete Animation subclass for testing.
private class TestAnimation: Animation<Double> {
    var testStatus: AnimationStatus
    var testValue: Double

    init(status: AnimationStatus, value: Double) {
        self.testStatus = status
        self.testValue = value
    }

    override var status: AnimationStatus { testStatus }
    override var value: Double { testValue }
}

/// A simple ValueListenable implementation for testing (mimics Dart's ValueNotifier).
private class TestValueNotifier<T>: ValueListenable {
    typealias Value = T

    var value: T {
        didSet { notifyListeners() }
    }

    private var _listeners: [VoidCallback] = []

    init(_ value: T) {
        self.value = value
    }

    func addListener(_ listener: @escaping VoidCallback) {
        _listeners.append(listener)
    }

    func removeListener(_ listener: @escaping VoidCallback) {
        if !_listeners.isEmpty {
            _listeners.removeLast()
        }
    }

    func notifyListeners() {
        for listener in _listeners {
            listener()
        }
    }
}

/// An Animatable that doubles the input value (for testing drive()).
private class TestDoublingAnimatable: Animatable<Double> {
    override func transform(_ t: Double) -> Double {
        return t * 2.0
    }
}
