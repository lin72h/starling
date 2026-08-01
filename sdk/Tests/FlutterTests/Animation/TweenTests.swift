// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for Tween types migrated from tween.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/tween_test.dart`
final class TweenTests: XCTestCase {

    // MARK: - DoubleTween Tests

    func testDoubleTweenLerp() {
        let tween = DoubleTween(begin: 0.0, end: 10.0)
        XCTAssertEqual(tween.lerp(0.0), 0.0)
        XCTAssertEqual(tween.lerp(0.5), 5.0)
        XCTAssertEqual(tween.lerp(1.0), 10.0)
    }

    func testDoubleTweenTransformAtBoundaries() {
        let tween = DoubleTween(begin: 0.3, end: 0.5)
        XCTAssertEqual(tween.transform(0.0), 0.3)
        XCTAssertEqual(tween.transform(1.0), 0.5)
    }

    func testDoubleTweenTransformMidpoint() {
        let tween = DoubleTween(begin: 0.3, end: 0.5)
        XCTAssertEqual(tween.transform(0.5), 0.4, accuracy: 1e-10)
    }

    func testDoubleTweenNegativeRange() {
        let tween = DoubleTween(begin: -10.0, end: 10.0)
        XCTAssertEqual(tween.lerp(0.0), -10.0)
        XCTAssertEqual(tween.lerp(0.5), 0.0)
        XCTAssertEqual(tween.lerp(1.0), 10.0)
    }

    // MARK: - IntTween Tests

    /// **Dart Test:** `tween_test.dart:156-160`
    func testIntTweenLerp() {
        let tween = IntTween(begin: 5, end: 9)
        XCTAssertEqual(tween.lerp(0.5), 7)
        XCTAssertEqual(tween.lerp(0.7), 8)
    }

    func testIntTweenTransformAtBoundaries() {
        let tween = IntTween(begin: 0, end: 100)
        XCTAssertEqual(tween.transform(0.0), 0)
        XCTAssertEqual(tween.transform(1.0), 100)
    }

    func testIntTweenRounding() {
        let tween = IntTween(begin: 0, end: 10)
        // 0.25 * 10 = 2.5 -> rounds to 3 (bankers rounding / .rounded())
        XCTAssertEqual(tween.lerp(0.25), 3)
        // 0.15 * 10 = 1.5 -> rounds to 2
        XCTAssertEqual(tween.lerp(0.15), 2)
    }

    // MARK: - StepTween Tests

    /// **Dart Test:** `tween_test.dart:219-223`
    func testStepTweenLerp() {
        let tween = StepTween(begin: 5, end: 9)
        XCTAssertEqual(tween.lerp(0.5), 7)
        XCTAssertEqual(tween.lerp(0.7), 7) // floor, not round
    }

    func testStepTweenFloors() {
        let tween = StepTween(begin: 0, end: 10)
        // 0.25 * 10 = 2.5 -> floor to 2
        XCTAssertEqual(tween.lerp(0.25), 2)
        // 0.99 * 10 = 9.9 -> floor to 9
        XCTAssertEqual(tween.lerp(0.99), 9)
    }

    func testStepTweenAtBoundaries() {
        let tween = StepTween(begin: 0, end: 10)
        XCTAssertEqual(tween.transform(0.0), 0)
        XCTAssertEqual(tween.transform(1.0), 10)
    }

    // MARK: - ConstantTween Tests

    /// **Dart Test:** `tween_test.dart:193-200`
    func testConstantTweenValue() {
        let tween = ConstantTween<Double>(100.0)
        XCTAssertEqual(tween.begin, 100.0)
        XCTAssertEqual(tween.end, 100.0)
        XCTAssertEqual(tween.lerp(0.0), 100.0)
        XCTAssertEqual(tween.lerp(0.5), 100.0)
        XCTAssertEqual(tween.lerp(1.0), 100.0)
    }

    func testConstantTweenTransform() {
        let tween = ConstantTween<Double>(42.0)
        XCTAssertEqual(tween.transform(0.0), 42.0)
        XCTAssertEqual(tween.transform(0.5), 42.0)
        XCTAssertEqual(tween.transform(1.0), 42.0)
    }

    func testConstantTweenDescription() {
        let tween = ConstantTween<Double>(42.0)
        let desc = tween.tweenDescription
        XCTAssertTrue(desc.contains("ConstantTween"))
        XCTAssertTrue(desc.contains("42.0"))
    }

    // MARK: - ReverseTween Tests

    /// **Dart Test:** `tween_test.dart:202-206`
    func testReverseTweenWithIntTween() {
        let parent = IntTween(begin: 5, end: 9)
        let tween = ReverseTween<Int>(parent: parent)
        XCTAssertEqual(tween.lerp(0.5), 7)
        XCTAssertEqual(tween.lerp(0.7), 6)
    }

    func testReverseTweenBeginEnd() {
        let parent = DoubleTween(begin: 0.0, end: 10.0)
        let tween = ReverseTween<Double>(parent: parent)
        // ReverseTween swaps begin and end
        XCTAssertEqual(tween.begin, 10.0)
        XCTAssertEqual(tween.end, 0.0)
    }

    func testReverseTweenTransformAtBoundaries() {
        let parent = DoubleTween(begin: 0.0, end: 10.0)
        let tween = ReverseTween<Double>(parent: parent)
        XCTAssertEqual(tween.transform(0.0), 10.0)
        XCTAssertEqual(tween.transform(1.0), 0.0)
    }

    func testReverseTweenLerpMidpoint() {
        let parent = DoubleTween(begin: 0.0, end: 10.0)
        let tween = ReverseTween<Double>(parent: parent)
        // lerp(0.5) -> parent.lerp(1.0 - 0.5) = parent.lerp(0.5) = 5.0
        XCTAssertEqual(tween.lerp(0.5), 5.0)
    }

    // MARK: - ColorTween Tests

    func testColorTweenLerp() {
        let tween = ColorTween(
            begin: Color(0xFF000000),
            end: Color(0xFFFFFFFF)
        )
        let result = tween.lerp(0.0)
        XCTAssertNotNil(result)
    }

    func testColorTweenAtBoundaries() {
        let begin = Color(0xFF000000)
        let end = Color(0xFFFFFFFF)
        let tween = ColorTween(begin: begin, end: end)
        // At t=0.0, transform returns begin
        XCTAssertEqual(tween.transform(0.0)?.toARGB32(), begin.toARGB32())
        // At t=1.0, transform returns end
        XCTAssertEqual(tween.transform(1.0)?.toARGB32(), end.toARGB32())
    }

    // MARK: - SizeTween Tests

    /// **Dart Test:** `tween_test.dart:150-153`
    func testSizeTweenLerp() {
        let tween = SizeTween(begin: Size.zero, end: Size(20.0, 30.0))
        let result = tween.lerp(0.5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.width, 10.0, accuracy: 1e-10)
        XCTAssertEqual(result!.height, 15.0, accuracy: 1e-10)
    }

    func testSizeTweenAtBoundaries() {
        let begin = Size.zero
        let end = Size(20.0, 30.0)
        let tween = SizeTween(begin: begin, end: end)
        let atZero = tween.transform(0.0)
        XCTAssertEqual(atZero?.width, 0.0)
        XCTAssertEqual(atZero?.height, 0.0)
        let atOne = tween.transform(1.0)
        XCTAssertEqual(atOne?.width, 20.0)
        XCTAssertEqual(atOne?.height, 30.0)
    }

    // MARK: - RectTween Tests

    /// **Dart Test:** `tween_test.dart:162-168`
    func testRectTweenLerp() {
        let a = Rect.fromLTWH(5.0, 3.0, 7.0, 11.0)
        let b = Rect.fromLTWH(8.0, 12.0, 14.0, 18.0)
        let tween = RectTween(begin: a, end: b)
        let result = tween.lerp(0.5)
        let expected = Rect.lerp(a, b, 0.5)
        XCTAssertNotNil(result)
        XCTAssertNotNil(expected)
        XCTAssertEqual(result!.left, expected!.left, accuracy: 1e-10)
        XCTAssertEqual(result!.top, expected!.top, accuracy: 1e-10)
        XCTAssertEqual(result!.right, expected!.right, accuracy: 1e-10)
        XCTAssertEqual(result!.bottom, expected!.bottom, accuracy: 1e-10)
    }

    // MARK: - CurveTween Tests

    /// **Dart Test:** `tween_test.dart:225-230`
    func testCurveTweenTransform() {
        let tween = CurveTween(curve: Curves.easeIn)
        XCTAssertEqual(tween.transform(0.0), 0.0)
        XCTAssertEqual(tween.transform(0.5), 0.31640625, accuracy: 1e-6)
        XCTAssertEqual(tween.transform(1.0), 1.0)
    }

    func testCurveTweenWithLinearCurve() {
        let tween = CurveTween(curve: Curves.linear)
        XCTAssertEqual(tween.transform(0.0), 0.0)
        XCTAssertEqual(tween.transform(0.25), 0.25, accuracy: 1e-10)
        XCTAssertEqual(tween.transform(0.5), 0.5, accuracy: 1e-10)
        XCTAssertEqual(tween.transform(0.75), 0.75, accuracy: 1e-10)
        XCTAssertEqual(tween.transform(1.0), 1.0)
    }

    // MARK: - Tween Description Tests

    func testTweenDescription() {
        let tween = DoubleTween(begin: 0.0, end: 1.0)
        let desc = tween.tweenDescription
        XCTAssertTrue(desc.contains("0.0"))
        XCTAssertTrue(desc.contains("1.0"))
    }

    // MARK: - Animatable Tests

    func testAnimatableFromCallback() {
        let animatable = Animatable<Double>.fromCallback { t in t * 3.0 }
        XCTAssertEqual(animatable.transform(0.0), 0.0)
        XCTAssertEqual(animatable.transform(0.5), 1.5)
        XCTAssertEqual(animatable.transform(1.0), 3.0)
    }

    func testAnimatableChain() {
        // Chain: first evaluate parent, then evaluate self at that result
        let doubler = DoubleTween(begin: 0.0, end: 2.0)
        let halver = DoubleTween(begin: 0.0, end: 0.5)
        // chain(halver) means: first evaluate halver(t), then evaluate doubler at that result
        let chained = doubler.chain(halver)
        // At t=1.0: halver.transform(1.0) = 0.5, then doubler.transform(0.5) = 1.0
        XCTAssertEqual(chained.transform(1.0), 1.0, accuracy: 1e-10)
        // At t=0.0: halver.transform(0.0) = 0.0, then doubler.transform(0.0) = 0.0
        XCTAssertEqual(chained.transform(0.0), 0.0, accuracy: 1e-10)
    }

    /// **Dart Test:** `tween_test.dart:110-117` (Can chain tweens)
    func testTweenChain() {
        let tween = DoubleTween(begin: 0.30, end: 0.50)
        let parent = DoubleTween(begin: 0.50, end: 1.0)
        let chain = tween.chain(parent)
        // At t=0.0: parent.transform(0.0) = 0.5, then tween.transform(0.5) = 0.4
        XCTAssertEqual(chain.transform(0.0), 0.4, accuracy: 1e-10)
    }

    func testAnimatableEvaluate() {
        let animatable = DoubleTween(begin: 0.0, end: 10.0)
        let animation = SimpleTestAnimation(value: 0.5, status: .forward)
        XCTAssertEqual(animatable.evaluate(animation), 5.0, accuracy: 1e-10)
    }

    func testAnimatableAnimate() {
        let animatable = DoubleTween(begin: 0.0, end: 10.0)
        let parent = SimpleTestAnimation(value: 0.5, status: .forward)
        let driven = animatable.animate(parent)
        XCTAssertEqual(driven.value, 5.0, accuracy: 1e-10)
        XCTAssertEqual(driven.status, .forward)
    }
}

// MARK: - Test Helpers

/// A simple test animation for testing Animatable.evaluate and animate.
private class SimpleTestAnimation: Animation<Double> {
    var testValue: Double
    var testStatus: AnimationStatus

    init(value: Double, status: AnimationStatus) {
        self.testValue = value
        self.testStatus = status
    }

    override var value: Double { testValue }
    override var status: AnimationStatus { testStatus }
}
