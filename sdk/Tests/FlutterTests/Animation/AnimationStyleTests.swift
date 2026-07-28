// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for AnimationStyle migrated from animation_style.dart.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/animation_style.dart`
final class AnimationStyleTests: XCTestCase {

    // MARK: - Construction Tests

    func testDefaultConstruction() {
        let style = AnimationStyle()
        XCTAssertNil(style.curve)
        XCTAssertNil(style.duration)
        XCTAssertNil(style.reverseCurve)
        XCTAssertNil(style.reverseDuration)
    }

    func testConstructionWithDuration() {
        let style = AnimationStyle(duration: .milliseconds(300))
        XCTAssertNil(style.curve)
        XCTAssertEqual(style.duration, .milliseconds(300))
        XCTAssertNil(style.reverseCurve)
        XCTAssertNil(style.reverseDuration)
    }

    func testConstructionWithAllParameters() {
        let style = AnimationStyle(
            curve: Curves.easeIn,
            duration: .milliseconds(300),
            reverseCurve: Curves.easeOut,
            reverseDuration: .milliseconds(200)
        )
        XCTAssertNotNil(style.curve)
        XCTAssertEqual(style.duration, .milliseconds(300))
        XCTAssertNotNil(style.reverseCurve)
        XCTAssertEqual(style.reverseDuration, .milliseconds(200))
    }

    // MARK: - noAnimation Tests

    func testNoAnimationStaticProperty() {
        let noAnim = AnimationStyle.noAnimation
        XCTAssertNil(noAnim.curve)
        XCTAssertEqual(noAnim.duration, .zero)
        XCTAssertNil(noAnim.reverseCurve)
        XCTAssertEqual(noAnim.reverseDuration, .zero)
    }

    // MARK: - Equality Tests

    func testEqualityWithSameDurations() {
        let a = AnimationStyle(duration: .milliseconds(300), reverseDuration: .milliseconds(200))
        let b = AnimationStyle(duration: .milliseconds(300), reverseDuration: .milliseconds(200))
        XCTAssertEqual(a, b)
    }

    func testEqualityWithDifferentDurations() {
        let a = AnimationStyle(duration: .milliseconds(300))
        let b = AnimationStyle(duration: .milliseconds(400))
        XCTAssertNotEqual(a, b)
    }

    func testEqualityIgnoresCurves() {
        // Equality only compares durations (documented difference from Dart)
        let a = AnimationStyle(
            curve: Curves.easeIn,
            duration: .milliseconds(300)
        )
        let b = AnimationStyle(
            curve: Curves.easeOut,
            duration: .milliseconds(300)
        )
        XCTAssertEqual(a, b)
    }

    func testEqualityBothNilDurations() {
        let a = AnimationStyle()
        let b = AnimationStyle()
        XCTAssertEqual(a, b)
    }

    func testNoAnimationEquality() {
        let a = AnimationStyle.noAnimation
        let b = AnimationStyle(duration: .zero, reverseDuration: .zero)
        XCTAssertEqual(a, b)
    }

    // MARK: - copyWith Tests

    func testCopyWithDuration() {
        let original = AnimationStyle(duration: .milliseconds(300))
        let copy = original.copyWith(duration: .milliseconds(500))
        XCTAssertEqual(copy.duration, .milliseconds(500))
        // Original unchanged
        XCTAssertEqual(original.duration, .milliseconds(300))
    }

    func testCopyWithReverseDuration() {
        let original = AnimationStyle(
            duration: .milliseconds(300),
            reverseDuration: .milliseconds(200)
        )
        let copy = original.copyWith(reverseDuration: .milliseconds(400))
        XCTAssertEqual(copy.duration, .milliseconds(300))
        XCTAssertEqual(copy.reverseDuration, .milliseconds(400))
    }

    func testCopyWithNoChanges() {
        let original = AnimationStyle(
            duration: .milliseconds(300),
            reverseDuration: .milliseconds(200)
        )
        let copy = original.copyWith()
        XCTAssertEqual(copy, original)
    }

    // MARK: - lerp Tests

    func testLerpBothNil() {
        let result = AnimationStyle.lerp(nil, nil, 0.5)
        XCTAssertNil(result)
    }

    func testLerpFirstNil() {
        let b = AnimationStyle(duration: .milliseconds(300))
        let result = AnimationStyle.lerp(nil, b, 0.75)
        XCTAssertNotNil(result)
        // t >= 0.5, so b's values are used
        XCTAssertEqual(result?.duration, .milliseconds(300))
    }

    func testLerpSecondNil() {
        let a = AnimationStyle(duration: .milliseconds(300))
        let result = AnimationStyle.lerp(a, nil, 0.25)
        XCTAssertNotNil(result)
        // t < 0.5, so a's values are used
        XCTAssertEqual(result?.duration, .milliseconds(300))
    }

    func testLerpAtMidpoint() {
        let a = AnimationStyle(duration: .milliseconds(300))
        let b = AnimationStyle(duration: .milliseconds(500))
        // t < 0.5 -> use a's values
        let resultBefore = AnimationStyle.lerp(a, b, 0.49)
        XCTAssertEqual(resultBefore?.duration, .milliseconds(300))
        // t >= 0.5 -> use b's values
        let resultAfter = AnimationStyle.lerp(a, b, 0.5)
        XCTAssertEqual(resultAfter?.duration, .milliseconds(500))
    }

    func testLerpAtExtremes() {
        let a = AnimationStyle(
            duration: .milliseconds(300),
            reverseDuration: .milliseconds(200)
        )
        let b = AnimationStyle(
            duration: .milliseconds(500),
            reverseDuration: .milliseconds(400)
        )
        // t=0.0 -> use a's values
        let atZero = AnimationStyle.lerp(a, b, 0.0)
        XCTAssertEqual(atZero?.duration, .milliseconds(300))
        XCTAssertEqual(atZero?.reverseDuration, .milliseconds(200))
        // t=1.0 -> use b's values
        let atOne = AnimationStyle.lerp(a, b, 1.0)
        XCTAssertEqual(atOne?.duration, .milliseconds(500))
        XCTAssertEqual(atOne?.reverseDuration, .milliseconds(400))
    }
}
