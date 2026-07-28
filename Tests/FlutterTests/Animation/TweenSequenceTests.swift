// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for TweenSequence types migrated from tween_sequence.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/animations_test.dart`
/// (TweenSequence tests are in animations_test.dart, not a separate file)
final class TweenSequenceTests: XCTestCase {

    // MARK: - TweenSequenceInterval Tests

    func testTweenSequenceIntervalContains() {
        let interval = TweenSequenceInterval(start: 0.2, end: 0.8)
        XCTAssertFalse(interval.contains(0.1))
        XCTAssertTrue(interval.contains(0.2))
        XCTAssertTrue(interval.contains(0.5))
        XCTAssertTrue(interval.contains(0.7))
        // Half-open: end is excluded
        XCTAssertFalse(interval.contains(0.8))
        XCTAssertFalse(interval.contains(0.9))
    }

    func testTweenSequenceIntervalValue() {
        let interval = TweenSequenceInterval(start: 0.2, end: 0.8)
        // Maps [0.2, 0.8] to [0, 1]
        XCTAssertEqual(interval.value(0.2), 0.0, accuracy: 1e-10)
        XCTAssertEqual(interval.value(0.5), 0.5, accuracy: 1e-10)
        XCTAssertEqual(interval.value(0.8), 1.0, accuracy: 1e-10)
    }

    func testTweenSequenceIntervalDescription() {
        let interval = TweenSequenceInterval(start: 0.0, end: 1.0)
        let desc = interval.description
        XCTAssertTrue(desc.contains("0.0"))
        XCTAssertTrue(desc.contains("1.0"))
    }

    // MARK: - TweenSequenceItem Tests

    func testTweenSequenceItemProperties() {
        let tween = DoubleTween(begin: 0.0, end: 1.0)
        let item = TweenSequenceItem(tween: tween, weight: 2.0)
        XCTAssertEqual(item.weight, 2.0)
    }

    // MARK: - TweenSequence Tests

    /// **Dart Test:** `animations_test.dart:389-414`
    func testTweenSequenceBasic() {
        let sequence = TweenSequence<Double>([
            TweenSequenceItem(tween: DoubleTween(begin: 5.0, end: 10.0), weight: 4.0),
            TweenSequenceItem(tween: ConstantTween<Double>(10.0), weight: 2.0),
            TweenSequenceItem(tween: DoubleTween(begin: 10.0, end: 5.0), weight: 4.0),
        ])

        // t=0.0: first tween at local t=0.0 -> 5.0
        XCTAssertEqual(sequence.transform(0.0), 5.0)

        // t=0.2: first tween (weight 4/10 = 0.4 range [0, 0.4])
        // local t = 0.2/0.4 = 0.5 -> lerp(5.0, 10.0, 0.5) = 7.5
        XCTAssertEqual(sequence.transform(0.2), 7.5, accuracy: 1e-10)

        // t=0.4: end of first tween, start of second
        XCTAssertEqual(sequence.transform(0.4), 10.0, accuracy: 1e-10)

        // t=0.5: middle of constant tween -> 10.0
        XCTAssertEqual(sequence.transform(0.5), 10.0, accuracy: 1e-10)

        // t=0.6: end of second tween, start of third
        XCTAssertEqual(sequence.transform(0.6), 10.0, accuracy: 1e-10)

        // t=0.8: third tween (range [0.6, 1.0])
        // local t = (0.8-0.6)/(1.0-0.6) = 0.5 -> lerp(10.0, 5.0, 0.5) = 7.5
        XCTAssertEqual(sequence.transform(0.8), 7.5, accuracy: 1e-10)

        // t=1.0: last tween at local t=1.0 -> 5.0
        XCTAssertEqual(sequence.transform(1.0), 5.0, accuracy: 1e-10)
    }

    /// **Dart Test:** `animations_test.dart:460-474`
    func testTweenSequenceOneTween() {
        let sequence = TweenSequence<Double>([
            TweenSequenceItem(tween: DoubleTween(begin: 5.0, end: 10.0), weight: 1.0),
        ])

        XCTAssertEqual(sequence.transform(0.0), 5.0)
        XCTAssertEqual(sequence.transform(0.5), 7.5, accuracy: 1e-10)
        XCTAssertEqual(sequence.transform(1.0), 10.0, accuracy: 1e-10)
    }

    func testTweenSequenceEqualWeights() {
        let sequence = TweenSequence<Double>([
            TweenSequenceItem(tween: DoubleTween(begin: 0.0, end: 1.0), weight: 1.0),
            TweenSequenceItem(tween: DoubleTween(begin: 1.0, end: 0.0), weight: 1.0),
        ])

        XCTAssertEqual(sequence.transform(0.0), 0.0)
        // t=0.25: first tween, local t = 0.25/0.5 = 0.5 -> 0.5
        XCTAssertEqual(sequence.transform(0.25), 0.5, accuracy: 1e-10)
        // t=0.5: boundary of first/second
        XCTAssertEqual(sequence.transform(0.5), 1.0, accuracy: 1e-10)
        // t=0.75: second tween, local t = (0.75-0.5)/0.5 = 0.5 -> lerp(1.0, 0.0, 0.5) = 0.5
        XCTAssertEqual(sequence.transform(0.75), 0.5, accuracy: 1e-10)
        XCTAssertEqual(sequence.transform(1.0), 0.0, accuracy: 1e-10)
    }

    func testTweenSequenceUnequalWeights() {
        let sequence = TweenSequence<Double>([
            TweenSequenceItem(tween: DoubleTween(begin: 0.0, end: 1.0), weight: 3.0),
            TweenSequenceItem(tween: DoubleTween(begin: 1.0, end: 0.0), weight: 1.0),
        ])

        // First tween covers [0, 0.75], second covers [0.75, 1.0]
        XCTAssertEqual(sequence.transform(0.0), 0.0)
        // t=0.375: first tween, local t = 0.375/0.75 = 0.5 -> 0.5
        XCTAssertEqual(sequence.transform(0.375), 0.5, accuracy: 1e-10)
        // t=0.75: boundary
        XCTAssertEqual(sequence.transform(0.75), 1.0, accuracy: 1e-10)
        XCTAssertEqual(sequence.transform(1.0), 0.0, accuracy: 1e-10)
    }

    // MARK: - TweenSequence with Chained Curves

    /// **Dart Test:** `animations_test.dart:416-458`
    func testTweenSequenceWithCurves() {
        let sequence = TweenSequence<Double>([
            TweenSequenceItem(
                tween: DoubleTween(begin: 5.0, end: 10.0)
                    .chain(CurveTween(curve: Interval(0.5, 1.0))),
                weight: 4.0
            ),
            TweenSequenceItem(
                tween: ConstantTween<Double>(10.0)
                    .chain(CurveTween(curve: Curves.linear)),
                weight: 2.0
            ),
            TweenSequenceItem(
                tween: DoubleTween(begin: 10.0, end: 5.0)
                    .chain(CurveTween(curve: Interval(0.0, 0.5))),
                weight: 4.0
            ),
        ])

        XCTAssertEqual(sequence.transform(0.0), 5.0)

        // t=0.2: first tween, local t = 0.5, Interval(0.5, 1.0).transform(0.5) = 0.0
        // So DoubleTween.transform(0.0) = 5.0
        XCTAssertEqual(sequence.transform(0.2), 5.0, accuracy: 1e-10)

        // t=0.4: first tween at end, local t = 1.0, Interval(0.5, 1.0).transform(1.0) = 1.0
        // DoubleTween.transform(1.0) = 10.0
        XCTAssertEqual(sequence.transform(0.4), 10.0, accuracy: 1e-10)

        // t=0.6: constant tween -> 10.0
        XCTAssertEqual(sequence.transform(0.6), 10.0, accuracy: 1e-10)

        // t=0.8: third tween, local t = (0.8-0.6)/(1.0-0.6) = 0.5
        // Interval(0.0, 0.5).transform(0.5) = 1.0
        // DoubleTween(10.0, 5.0).transform(1.0) = 5.0
        XCTAssertEqual(sequence.transform(0.8), 5.0, accuracy: 1e-10)

        // t=1.0: third tween at end
        XCTAssertEqual(sequence.transform(1.0), 5.0, accuracy: 1e-10)
    }

    // MARK: - FlippedTweenSequence Tests

    func testFlippedTweenSequence() {
        let sequence = FlippedTweenSequence([
            TweenSequenceItem(tween: DoubleTween(begin: 0.0, end: 1.0), weight: 1.0),
        ])

        // FlippedTweenSequence: transform(t) = 1 - super.transform(1 - t)
        // At t=0.0: 1 - super.transform(1.0) = 1 - 1.0 = 0.0
        XCTAssertEqual(sequence.transform(0.0), 0.0, accuracy: 1e-10)
        // At t=0.5: 1 - super.transform(0.5) = 1 - 0.5 = 0.5
        XCTAssertEqual(sequence.transform(0.5), 0.5, accuracy: 1e-10)
        // At t=1.0: 1 - super.transform(0.0) = 1 - 0.0 = 1.0
        XCTAssertEqual(sequence.transform(1.0), 1.0, accuracy: 1e-10)
    }

    func testFlippedTweenSequenceNonLinear() {
        // With a tween that goes 0->1, the flipped version also goes 0->1
        // but with reversed temporal behavior
        let sequence = FlippedTweenSequence([
            TweenSequenceItem(tween: DoubleTween(begin: 0.0, end: 0.5), weight: 1.0),
            TweenSequenceItem(tween: DoubleTween(begin: 0.5, end: 1.0), weight: 1.0),
        ])

        // At t=0.0: 1 - super.transform(1.0) = 1 - 1.0 = 0.0
        XCTAssertEqual(sequence.transform(0.0), 0.0, accuracy: 1e-10)
        // At t=1.0: 1 - super.transform(0.0) = 1 - 0.0 = 1.0
        XCTAssertEqual(sequence.transform(1.0), 1.0, accuracy: 1e-10)
    }
}
