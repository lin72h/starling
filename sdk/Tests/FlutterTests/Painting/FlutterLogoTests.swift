// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for FlutterLogoDecoration.
///
/// **Dart Test Source:** `packages/flutter/test/painting/flutter_logo_test.dart`
///
/// Note: Golden tests and widget tests are skipped. Only unit tests are ported.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal concrete Decoration implementation for cross-type lerp testing.
/// Stands in for BoxDecoration which is not yet migrated.
///
/// **Dart Test:** `flutter_logo_test.dart:58-63` uses `BoxDecoration()` which we
/// replace with this stub.
private final class StubDecoration: Decoration {
    func createBoxPainter(_ onChanged: VoidCallback?) -> BoxPainter {
        BoxPainter(onChanged: onChanged)
    }

    func toStringShort() -> String {
        objectRuntimeType(self, "StubDecoration")
    }

    func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {}

    func toDiagnosticsNode(name: String?, style: DiagnosticsTreeStyle?) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style ?? .singleLine)
    }
}

// MARK: - FlutterLogoTests

final class FlutterLogoTests: XCTestCase {

    // MARK: - Shared Test Fixtures

    /// Corresponds to the Dart `start` constant.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:15-19`
    private let start = FlutterLogoDecoration(
        textColor: Color(0xFFD4F144),
        style: .stacked,
        margin: EdgeInsets(all: 10.0)
    )

    /// Corresponds to the Dart `end` constant.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:21-25`
    private let end = FlutterLogoDecoration(
        textColor: Color(0xFF81D4FA),
        style: .stacked,
        margin: EdgeInsets(all: 10.0)
    )

    // MARK: - Lerp Tests

    /// FlutterLogoDecoration lerp from null to null is null.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:27-30`
    func testLerpFromNullToNullIsNull() {
        let logo = FlutterLogoDecoration.lerp(nil, nil, 0.5)
        XCTAssertNil(logo)
    }

    /// FlutterLogoDecoration.lerp identical a,b.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:32-36`
    func testLerpIdenticalAB() {
        XCTAssertNil(FlutterLogoDecoration.lerp(nil, nil, 0))
        let logo = FlutterLogoDecoration()
        XCTAssertTrue(FlutterLogoDecoration.lerp(logo, logo, 0.5) === logo)
    }

    /// FlutterLogoDecoration lerp from non-null to null lerps margin.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:38-43`
    func testLerpFromNonNullToNullLerpsMargin() {
        let logo = FlutterLogoDecoration.lerp(start, nil, 0.4)!
        XCTAssertEqual(logo.textColor, start.textColor)
        XCTAssertEqual(logo.style, start.style)
        XCTAssertEqual(logo.margin, start.margin * 0.4)
    }

    /// FlutterLogoDecoration lerp from null to non-null lerps margin.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:45-50`
    func testLerpFromNullToNonNullLerpsMargin() {
        let logo = FlutterLogoDecoration.lerp(nil, end, 0.6)!
        XCTAssertEqual(logo.textColor, end.textColor)
        XCTAssertEqual(logo.style, end.style)
        XCTAssertEqual(logo.margin, end.margin * 0.6)
    }

    /// FlutterLogoDecoration lerps colors and margins.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:52-56`
    func testLerpsColorsAndMargins() {
        let logo = FlutterLogoDecoration.lerp(start, end, 0.5)!
        XCTAssertEqual(logo.textColor, Color.lerp(start.textColor, end.textColor, 0.5))
        XCTAssertEqual(logo.margin, EdgeInsets.lerp(start.margin, end.margin, 0.5))
    }

    /// FlutterLogoDecoration.lerpFrom and FlutterLogoDecoration.lerpTo.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:58-63`
    ///
    /// Note: The Dart test uses BoxDecoration which is not yet migrated.
    /// We use StubDecoration as a stand-in. The test verifies that lerpFrom/lerpTo
    /// with unrelated decoration types falls back correctly through lerpDecoration().
    func testLerpFromAndLerpTo() {
        let stub = StubDecoration()

        // lerpDecoration(start, stub, 0.0) should return start (t==0.0 short circuit)
        let atT0FromStart = lerpDecoration(start, stub, 0.0)
        XCTAssertTrue(atT0FromStart === start)

        // lerpDecoration(start, stub, 1.0) should return stub (t==1.0 short circuit)
        let atT1FromStart = lerpDecoration(start, stub, 1.0)
        XCTAssertTrue(atT1FromStart === stub)

        // lerpDecoration(stub, end, 0.0) should return stub (t==0.0 short circuit)
        let atT0ToEnd = lerpDecoration(stub, end, 0.0)
        XCTAssertTrue(atT0ToEnd === stub)

        // lerpDecoration(stub, end, 1.0) should return end (t==1.0 short circuit)
        let atT1ToEnd = lerpDecoration(stub, end, 1.0)
        XCTAssertTrue(atT1ToEnd === end)
    }

    /// FlutterLogoDecoration lerp changes styles at 0.5.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:65-71`
    func testLerpChangesStylesAt05() {
        var logo = FlutterLogoDecoration.lerp(start, end, 0.4)!
        XCTAssertEqual(logo.style, start.style)

        logo = FlutterLogoDecoration.lerp(start, end, 0.5)!
        XCTAssertEqual(logo.style, end.style)
    }

    /// FlutterLogoDecoration toString.
    ///
    /// **Dart Test:** `flutter_logo_test.dart:73-84`
    ///
    /// Note: The exact Color string representation differs between Dart and Swift.
    /// We verify the structural format rather than exact byte-level match.
    func testToString() {
        let startStr = start.toString()
        // Should contain the type name
        XCTAssertTrue(startStr.contains("FlutterLogoDecoration"), "toString should contain type name")
        // Should contain textColor property
        XCTAssertTrue(startStr.contains("textColor"), "toString should contain textColor")
        // Should contain style property value
        XCTAssertTrue(startStr.contains("stacked"), "toString should contain style value")
        // Should NOT contain transition info since it's not in transition
        XCTAssertFalse(startStr.contains("transition"), "Non-transition state should not contain 'transition'")

        // Test transition state toString
        let transitionLogo = FlutterLogoDecoration.lerp(nil, end, 0.5)
        let transitionStr = transitionLogo!.toString()
        // Should contain the type name
        XCTAssertTrue(transitionStr.contains("FlutterLogoDecoration"), "toString should contain type name")
        // Should contain textColor property
        XCTAssertTrue(transitionStr.contains("textColor"), "toString should contain textColor")
        // Should contain style property value
        XCTAssertTrue(transitionStr.contains("stacked"), "toString should contain style value")
        // Should contain transition info since opacity is 0.5 (not 1.0)
        XCTAssertTrue(transitionStr.contains("transition"), "Transition state should contain 'transition'")
        XCTAssertTrue(transitionStr.contains("-1.0"), "Transition should show position -1.0")
        XCTAssertTrue(transitionStr.contains("0.5"), "Transition should show opacity 0.5")
    }

    // MARK: - FlutterLogoStyle Tests

    /// Test FlutterLogoStyle enum values.
    ///
    /// **Dart Source:** `flutter_logo.dart:25-36`
    func testFlutterLogoStyleValues() {
        XCTAssertEqual(FlutterLogoStyle.allCases.count, 3)
        XCTAssertTrue(FlutterLogoStyle.allCases.contains(.markOnly))
        XCTAssertTrue(FlutterLogoStyle.allCases.contains(.horizontal))
        XCTAssertTrue(FlutterLogoStyle.allCases.contains(.stacked))
    }

    // MARK: - FlutterLogoDecoration Constructor Tests

    /// Test default initializer values.
    ///
    /// **Dart Source:** `flutter_logo.dart:44-53`
    func testDefaultInitializer() {
        let logo = FlutterLogoDecoration()
        XCTAssertEqual(logo.textColor, Color(0xFF757575))
        XCTAssertEqual(logo.style, .markOnly)
        XCTAssertEqual(logo.margin, EdgeInsets.zero)
    }

    /// Test that position is set correctly based on style.
    ///
    /// **Dart Source:** `flutter_logo.dart:48-52`
    func testPositionFromStyle() {
        let markOnly = FlutterLogoDecoration(style: .markOnly)
        XCTAssertEqual(markOnly._position, 0.0)

        let horizontal = FlutterLogoDecoration(style: .horizontal)
        XCTAssertEqual(horizontal._position, 1.0)

        let stacked = FlutterLogoDecoration(style: .stacked)
        XCTAssertEqual(stacked._position, -1.0)
    }

    /// Test that opacity defaults to 1.0.
    ///
    /// **Dart Source:** `flutter_logo.dart:53`
    func testOpacityDefault() {
        let logo = FlutterLogoDecoration()
        XCTAssertEqual(logo._opacity, 1.0)
    }

    // MARK: - Equality Tests

    /// Test equality of FlutterLogoDecoration instances.
    ///
    /// **Dart Source:** `flutter_logo.dart:183-193`
    func testEquality() {
        let a = FlutterLogoDecoration(textColor: Color(0xFFFF0000), style: .horizontal)
        let b = FlutterLogoDecoration(textColor: Color(0xFFFF0000), style: .horizontal)
        XCTAssertEqual(a, b)
    }

    /// Test inequality when textColor differs.
    func testInequalityTextColor() {
        let a = FlutterLogoDecoration(textColor: Color(0xFFFF0000))
        let b = FlutterLogoDecoration(textColor: Color(0xFF00FF00))
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality when style (and thus position) differs.
    func testInequalityStyle() {
        let a = FlutterLogoDecoration(style: .markOnly)
        let b = FlutterLogoDecoration(style: .horizontal)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable Tests

    /// Test hash code consistency.
    ///
    /// **Dart Source:** `flutter_logo.dart:195-199`
    func testHashCodeConsistency() {
        let a = FlutterLogoDecoration(textColor: Color(0xFFFF0000), style: .stacked)
        let b = FlutterLogoDecoration(textColor: Color(0xFFFF0000), style: .stacked)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test that equal decorations can be used in a Set.
    func testAsSetElement() {
        let a = FlutterLogoDecoration(textColor: Color(0xFFFF0000))
        let b = FlutterLogoDecoration(textColor: Color(0xFFFF0000))
        let c = FlutterLogoDecoration(textColor: Color(0xFF00FF00))

        var set = Set<FlutterLogoDecoration>()
        set.insert(a)
        set.insert(b)  // Should not increase count (equal to a)
        set.insert(c)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - isComplex Tests

    /// Test isComplex for non-transition state.
    ///
    /// **Dart Source:** `flutter_logo.dart:93-94`
    func testIsComplexNonTransition() {
        let logo = FlutterLogoDecoration()
        XCTAssertTrue(logo.isComplex)
    }

    /// Test isComplex for transition state.
    func testIsComplexTransition() {
        let logo = FlutterLogoDecoration.lerp(nil, end, 0.5)!
        // In transition because opacity is 0.5, not 1.0
        XCTAssertFalse(logo.isComplex)
    }

    // MARK: - debugAssertIsValid Tests

    /// Test debugAssertIsValid returns true for valid decorations.
    ///
    /// **Dart Source:** `flutter_logo.dart:87-91`
    func testDebugAssertIsValid() {
        let logo = FlutterLogoDecoration()
        XCTAssertTrue(logo.debugAssertIsValid())
    }

    // MARK: - hitTest Tests

    /// Test hitTest always returns true.
    ///
    /// **Dart Source:** `flutter_logo.dart:168-170`
    func testHitTest() {
        let logo = FlutterLogoDecoration()
        XCTAssertTrue(logo.hitTest(Size(100, 100), Offset(50, 50)))
    }

    // MARK: - createBoxPainter Tests

    /// Test createBoxPainter returns a BoxPainter.
    ///
    /// **Dart Source:** `flutter_logo.dart:172-176`
    func testCreateBoxPainter() {
        let logo = FlutterLogoDecoration()
        let painter = logo.createBoxPainter(nil)
        XCTAssertNotNil(painter)
    }

    // MARK: - getClipPath Tests

    /// Test getClipPath returns a path covering the rect.
    ///
    /// **Dart Source:** `flutter_logo.dart:178-181`
    func testGetClipPath() {
        let logo = FlutterLogoDecoration()
        let rect = Rect.fromLTWH(0, 0, 100, 100)
        let path = logo.getClipPath(rect, .ltr)
        // Path should contain the rect bounds
        let bounds = path.getBounds()
        XCTAssertEqual(bounds, rect)
    }

    // MARK: - Lerp Edge Cases

    /// Test lerp at t=0 returns a.
    func testLerpAtT0ReturnsA() {
        let result = FlutterLogoDecoration.lerp(start, end, 0.0)
        XCTAssertTrue(result === start)
    }

    /// Test lerp at t=1 returns b.
    func testLerpAtT1ReturnsB() {
        let result = FlutterLogoDecoration.lerp(start, end, 1.0)
        XCTAssertTrue(result === end)
    }

    /// Test lerp opacity is clamped between 0 and 1.
    func testLerpOpacityClamped() {
        // When lerping from non-null to nil at t=0.5, opacity = 1.0 * clamp(0.5, 0, 1) = 0.5
        let logo = FlutterLogoDecoration.lerp(start, nil, 0.5)!
        XCTAssertTrue(logo._opacity >= 0.0 && logo._opacity <= 1.0)
    }

    /// Test lerp between different styles (stacked and horizontal).
    func testLerpBetweenDifferentStyles() {
        let a = FlutterLogoDecoration(style: .stacked, margin: EdgeInsets(all: 10.0))
        let b = FlutterLogoDecoration(style: .horizontal, margin: EdgeInsets(all: 10.0))

        // At t=0.4, should keep a's style
        let at04 = FlutterLogoDecoration.lerp(a, b, 0.4)!
        XCTAssertEqual(at04.style, .stacked)

        // At t=0.5, should switch to b's style
        let at05 = FlutterLogoDecoration.lerp(a, b, 0.5)!
        XCTAssertEqual(at05.style, .horizontal)

        // Position should interpolate: -1.0 + (1.0 - (-1.0)) * 0.5 = 0.0
        XCTAssertEqual(at05._position, 0.0, accuracy: 0.0001)
    }
}
