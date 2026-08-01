// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for BoxShadow.
///
/// **Dart Test Source:** Tests based on `packages/flutter/test/painting/box_shadow_test.dart`
/// and `packages/flutter/test/widgets/shadow_test.dart` (unit test portions).

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class BoxShadowTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func tearDown() {
        // Reset debug flag after each test
        #if DEBUG
        debugDisableShadows = false
        #endif
        super.tearDown()
    }

    // MARK: - Constructor Tests

    /// Test that the default initializer creates a shadow with expected default values.
    ///
    /// **Dart Source:** `box_shadow.dart:37-43` - Default constructor values
    func testDefaultInitializer() {
        let shadow = BoxShadow()

        XCTAssertEqual(shadow.color, Color(0xFF000000), "Default color should be black")
        XCTAssertEqual(shadow.offset, .zero, "Default offset should be zero")
        XCTAssertEqual(shadow.blurRadius, 0.0, "Default blurRadius should be 0.0")
        XCTAssertEqual(shadow.spreadRadius, 0.0, "Default spreadRadius should be 0.0")
        XCTAssertEqual(shadow.blurStyle, .normal, "Default blurStyle should be .normal")
    }

    /// Test the custom initializer with all parameters.
    ///
    /// **Dart Source:** `box_shadow.dart:37-43` - Constructor with custom values
    func testCustomInitializer() {
        let color = Color(0xFFFF0000)  // Red
        let offset = Offset(10.0, 20.0)
        let shadow = BoxShadow(
            color: color,
            offset: offset,
            blurRadius: 5.0,
            spreadRadius: 2.0,
            blurStyle: .outer
        )

        XCTAssertEqual(shadow.color, color)
        XCTAssertEqual(shadow.offset, offset)
        XCTAssertEqual(shadow.blurRadius, 5.0)
        XCTAssertEqual(shadow.spreadRadius, 2.0)
        XCTAssertEqual(shadow.blurStyle, .outer)
    }

    /// Test initializer with partial parameters (using defaults for others).
    func testPartialInitializer() {
        let shadow = BoxShadow(blurRadius: 10.0)

        XCTAssertEqual(shadow.color, Color(0xFF000000))
        XCTAssertEqual(shadow.offset, .zero)
        XCTAssertEqual(shadow.blurRadius, 10.0)
        XCTAssertEqual(shadow.spreadRadius, 0.0)
        XCTAssertEqual(shadow.blurStyle, .normal)
    }

    // MARK: - Computed Property Tests

    /// Test the blurSigma computed property.
    ///
    /// **Dart Source:** `ui.Shadow` - blurSigma uses convertRadiusToSigma
    func testBlurSigma() {
        let shadow = BoxShadow(blurRadius: 10.0)

        // blurSigma should convert radius to sigma using the formula:
        // sigma = radius * 0.57735 + 0.5
        let expectedSigma = Shadow.convertRadiusToSigma(10.0)
        XCTAssertEqual(shadow.blurSigma, expectedSigma, accuracy: 0.0001)
    }

    /// Test blurSigma with zero blur radius.
    func testBlurSigmaZero() {
        let shadow = BoxShadow(blurRadius: 0.0)
        let expectedSigma = Shadow.convertRadiusToSigma(0.0)
        XCTAssertEqual(shadow.blurSigma, expectedSigma, accuracy: 0.0001)
    }

    // MARK: - asShadow Tests

    /// Test conversion to Shadow type.
    func testAsShadow() {
        let boxShadow = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,  // This should be lost
            blurStyle: .outer   // This should be lost
        )

        let shadow = boxShadow.asShadow

        XCTAssertEqual(shadow.color, boxShadow.color)
        XCTAssertEqual(shadow.offset, boxShadow.offset)
        XCTAssertEqual(shadow.blurRadius, boxShadow.blurRadius)
    }

    // MARK: - toPaint() Tests

    /// Test toPaint() creates a Paint with the correct properties.
    ///
    /// **Dart Source:** `box_shadow.dart:69-80` - toPaint() method
    func testToPaint() {
        let color = Color(0xFF00FF00)  // Green
        let shadow = BoxShadow(
            color: color,
            blurRadius: 10.0,
            blurStyle: .normal
        )

        let paint = shadow.toPaint()

        XCTAssertEqual(paint.color, color)
        XCTAssertNotNil(paint.maskFilter, "Paint should have a MaskFilter")
    }

    /// Test toPaint() with different blur styles.
    func testToPaintWithBlurStyles() {
        let blurStyles: [BlurStyle] = [.normal, .solid, .outer, .inner]

        for style in blurStyles {
            let shadow = BoxShadow(blurRadius: 5.0, blurStyle: style)
            let paint = shadow.toPaint()
            XCTAssertNotNil(paint.maskFilter, "Paint should have MaskFilter for style: \(style)")
        }
    }

    #if DEBUG
    /// Test toPaint() with debugDisableShadows = true.
    ///
    /// **Dart Source:** `box_shadow.dart:72-79` - debugDisableShadows handling
    func testToPaintWithDebugDisableShadows() {
        debugDisableShadows = true

        let shadow = BoxShadow(blurRadius: 10.0, blurStyle: .outer)
        let paint = shadow.toPaint()

        XCTAssertNil(paint.maskFilter, "MaskFilter should be nil when debugDisableShadows is true")
        XCTAssertEqual(paint.color, shadow.color, "Color should still be set")
    }
    #endif

    // MARK: - scale() Tests

    /// Test scale() method.
    ///
    /// **Dart Source:** `box_shadow.dart:85-93` - scale() method
    func testScale() {
        let shadow = BoxShadow(
            color: Color(0xFF0000FF),
            offset: Offset(10.0, 20.0),
            blurRadius: 8.0,
            spreadRadius: 4.0,
            blurStyle: .outer
        )

        let scaled = shadow.scale(2.0)

        XCTAssertEqual(scaled.color, shadow.color, "Color should not change")
        XCTAssertEqual(scaled.offset, Offset(20.0, 40.0), "Offset should be scaled")
        XCTAssertEqual(scaled.blurRadius, 16.0, "blurRadius should be scaled")
        XCTAssertEqual(scaled.spreadRadius, 8.0, "spreadRadius should be scaled")
        XCTAssertEqual(scaled.blurStyle, shadow.blurStyle, "blurStyle should not change")
    }

    /// Test scale() with zero factor.
    func testScaleByZero() {
        let shadow = BoxShadow(
            offset: Offset(10.0, 20.0),
            blurRadius: 8.0,
            spreadRadius: 4.0
        )

        let scaled = shadow.scale(0.0)

        XCTAssertEqual(scaled.offset, .zero)
        XCTAssertEqual(scaled.blurRadius, 0.0)
        XCTAssertEqual(scaled.spreadRadius, 0.0)
    }

    /// Test scale() with negative factor.
    func testScaleByNegative() {
        let shadow = BoxShadow(
            offset: Offset(10.0, 20.0),
            blurRadius: 8.0,
            spreadRadius: 4.0
        )

        let scaled = shadow.scale(-1.0)

        XCTAssertEqual(scaled.offset, Offset(-10.0, -20.0))
        XCTAssertEqual(scaled.blurRadius, -8.0)
        XCTAssertEqual(scaled.spreadRadius, -4.0)
    }

    // MARK: - copyWith() Tests

    /// Test copyWith() method with all parameters.
    ///
    /// **Dart Source:** `box_shadow.dart:97-111` - copyWith() method
    func testCopyWithAllParameters() {
        let original = BoxShadow(
            color: Color(0xFF000000),
            offset: .zero,
            blurRadius: 0.0,
            spreadRadius: 0.0,
            blurStyle: .normal
        )

        let copied = original.copyWith(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )

        XCTAssertEqual(copied.color, Color(0xFFFF0000))
        XCTAssertEqual(copied.offset, Offset(5.0, 10.0))
        XCTAssertEqual(copied.blurRadius, 15.0)
        XCTAssertEqual(copied.spreadRadius, 3.0)
        XCTAssertEqual(copied.blurStyle, .outer)

        // Original should be unchanged
        XCTAssertEqual(original.color, Color(0xFF000000))
        XCTAssertEqual(original.blurStyle, .normal)
    }

    /// Test copyWith() with no parameters (returns equivalent shadow).
    func testCopyWithNoParameters() {
        let original = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )

        let copied = original.copyWith()

        XCTAssertEqual(copied, original)
    }

    /// Test copyWith() with partial parameters.
    func testCopyWithPartialParameters() {
        let original = BoxShadow(
            color: Color(0xFF000000),
            offset: Offset(10.0, 20.0),
            blurRadius: 5.0,
            spreadRadius: 2.0,
            blurStyle: .normal
        )

        let copied = original.copyWith(color: Color(0xFF00FF00), blurRadius: 10.0)

        XCTAssertEqual(copied.color, Color(0xFF00FF00))
        XCTAssertEqual(copied.offset, original.offset)  // Unchanged
        XCTAssertEqual(copied.blurRadius, 10.0)
        XCTAssertEqual(copied.spreadRadius, original.spreadRadius)  // Unchanged
        XCTAssertEqual(copied.blurStyle, original.blurStyle)  // Unchanged
    }

    // MARK: - lerp() Tests

    /// Test lerp() with non-nil inputs at various t values.
    ///
    /// **Dart Source:** `box_shadow.dart:120-137` - lerp() method
    func testLerpBasic() {
        let a = BoxShadow(
            color: Color(0xFF000000),
            offset: Offset(0.0, 0.0),
            blurRadius: 0.0,
            spreadRadius: 0.0,
            blurStyle: .normal
        )
        let b = BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(10.0, 20.0),
            blurRadius: 10.0,
            spreadRadius: 4.0,
            blurStyle: .normal
        )

        // t = 0 should return a
        let at0 = BoxShadow.lerp(a, b, 0.0)!
        XCTAssertEqual(at0.offset.dx, 0.0, accuracy: 0.0001)
        XCTAssertEqual(at0.offset.dy, 0.0, accuracy: 0.0001)
        XCTAssertEqual(at0.blurRadius, 0.0, accuracy: 0.0001)
        XCTAssertEqual(at0.spreadRadius, 0.0, accuracy: 0.0001)

        // t = 1 should return b
        let at1 = BoxShadow.lerp(a, b, 1.0)!
        XCTAssertEqual(at1.offset.dx, 10.0, accuracy: 0.0001)
        XCTAssertEqual(at1.offset.dy, 20.0, accuracy: 0.0001)
        XCTAssertEqual(at1.blurRadius, 10.0, accuracy: 0.0001)
        XCTAssertEqual(at1.spreadRadius, 4.0, accuracy: 0.0001)

        // t = 0.5 should return midpoint
        let at05 = BoxShadow.lerp(a, b, 0.5)!
        XCTAssertEqual(at05.offset.dx, 5.0, accuracy: 0.0001)
        XCTAssertEqual(at05.offset.dy, 10.0, accuracy: 0.0001)
        XCTAssertEqual(at05.blurRadius, 5.0, accuracy: 0.0001)
        XCTAssertEqual(at05.spreadRadius, 2.0, accuracy: 0.0001)
    }

    /// Test lerp() with identical inputs returns the same value.
    func testLerpIdentical() {
        let shadow = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0
        )

        let result = BoxShadow.lerp(shadow, shadow, 0.5)

        XCTAssertEqual(result, shadow)
    }

    /// Test lerp() with nil inputs.
    func testLerpWithNilInputs() {
        let shadow = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(10.0, 20.0),
            blurRadius: 8.0,
            spreadRadius: 4.0
        )

        // Both nil
        XCTAssertNil(BoxShadow.lerp(nil, nil, 0.5))

        // a is nil - should scale b by t
        let fromNil = BoxShadow.lerp(nil, shadow, 0.5)!
        XCTAssertEqual(fromNil.offset.dx, 5.0, accuracy: 0.0001)
        XCTAssertEqual(fromNil.offset.dy, 10.0, accuracy: 0.0001)
        XCTAssertEqual(fromNil.blurRadius, 4.0, accuracy: 0.0001)
        XCTAssertEqual(fromNil.spreadRadius, 2.0, accuracy: 0.0001)

        // b is nil - should scale a by (1-t)
        let toNil = BoxShadow.lerp(shadow, nil, 0.5)!
        XCTAssertEqual(toNil.offset.dx, 5.0, accuracy: 0.0001)
        XCTAssertEqual(toNil.offset.dy, 10.0, accuracy: 0.0001)
        XCTAssertEqual(toNil.blurRadius, 4.0, accuracy: 0.0001)
        XCTAssertEqual(toNil.spreadRadius, 2.0, accuracy: 0.0001)
    }

    /// Test lerp() blurStyle interpolation logic.
    ///
    /// **Dart Source:** `box_shadow.dart:136` - blurStyle lerp logic
    func testLerpBlurStyle() {
        let normalStyle = BoxShadow(blurStyle: .normal)
        let outerStyle = BoxShadow(blurStyle: .outer)
        let innerStyle = BoxShadow(blurStyle: .inner)

        // When a has .normal, use b's style
        let result1 = BoxShadow.lerp(normalStyle, outerStyle, 0.5)!
        XCTAssertEqual(result1.blurStyle, .outer)

        // When a has non-.normal, use a's style
        let result2 = BoxShadow.lerp(outerStyle, innerStyle, 0.5)!
        XCTAssertEqual(result2.blurStyle, .outer)

        // When both have .normal, result is .normal
        let result3 = BoxShadow.lerp(normalStyle, normalStyle, 0.5)!
        XCTAssertEqual(result3.blurStyle, .normal)
    }

    /// Test lerp() with extrapolation (t < 0 or t > 1).
    func testLerpExtrapolation() {
        let a = BoxShadow(offset: Offset(0.0, 0.0), blurRadius: 0.0)
        let b = BoxShadow(offset: Offset(10.0, 10.0), blurRadius: 10.0)

        // t = -0.5 (extrapolate before a)
        let before = BoxShadow.lerp(a, b, -0.5)!
        XCTAssertEqual(before.offset.dx, -5.0, accuracy: 0.0001)
        XCTAssertEqual(before.blurRadius, -5.0, accuracy: 0.0001)

        // t = 1.5 (extrapolate after b)
        let after = BoxShadow.lerp(a, b, 1.5)!
        XCTAssertEqual(after.offset.dx, 15.0, accuracy: 0.0001)
        XCTAssertEqual(after.blurRadius, 15.0, accuracy: 0.0001)
    }

    // MARK: - lerpList() Tests

    /// Test lerpList() with same-length lists.
    ///
    /// **Dart Source:** `box_shadow.dart:144-156` - lerpList() method
    func testLerpListSameLength() {
        let a = [
            BoxShadow(blurRadius: 0.0),
            BoxShadow(blurRadius: 10.0)
        ]
        let b = [
            BoxShadow(blurRadius: 10.0),
            BoxShadow(blurRadius: 20.0)
        ]

        let result = BoxShadow.lerpList(a, b, 0.5)!

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].blurRadius, 5.0, accuracy: 0.0001)
        XCTAssertEqual(result[1].blurRadius, 15.0, accuracy: 0.0001)
    }

    /// Test lerpList() with different-length lists (a longer).
    func testLerpListALonger() {
        let a = [
            BoxShadow(blurRadius: 10.0),
            BoxShadow(blurRadius: 20.0),
            BoxShadow(blurRadius: 30.0)
        ]
        let b = [
            BoxShadow(blurRadius: 0.0)
        ]

        let result = BoxShadow.lerpList(a, b, 0.5)!

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].blurRadius, 5.0, accuracy: 0.0001)  // lerp(10, 0, 0.5)
        XCTAssertEqual(result[1].blurRadius, 10.0, accuracy: 0.0001) // scale(20, 0.5)
        XCTAssertEqual(result[2].blurRadius, 15.0, accuracy: 0.0001) // scale(30, 0.5)
    }

    /// Test lerpList() with different-length lists (b longer).
    func testLerpListBLonger() {
        let a = [
            BoxShadow(blurRadius: 0.0)
        ]
        let b = [
            BoxShadow(blurRadius: 10.0),
            BoxShadow(blurRadius: 20.0),
            BoxShadow(blurRadius: 30.0)
        ]

        let result = BoxShadow.lerpList(a, b, 0.5)!

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].blurRadius, 5.0, accuracy: 0.0001)  // lerp(0, 10, 0.5)
        XCTAssertEqual(result[1].blurRadius, 10.0, accuracy: 0.0001) // scale(20, 0.5)
        XCTAssertEqual(result[2].blurRadius, 15.0, accuracy: 0.0001) // scale(30, 0.5)
    }

    /// Test lerpList() with nil inputs.
    func testLerpListWithNilInputs() {
        let shadows = [BoxShadow(blurRadius: 10.0)]

        // Both nil
        XCTAssertNil(BoxShadow.lerpList(nil, nil, 0.5))

        // a is nil
        let fromNil = BoxShadow.lerpList(nil, shadows, 0.5)!
        XCTAssertEqual(fromNil.count, 1)
        XCTAssertEqual(fromNil[0].blurRadius, 5.0, accuracy: 0.0001)

        // b is nil
        let toNil = BoxShadow.lerpList(shadows, nil, 0.5)!
        XCTAssertEqual(toNil.count, 1)
        XCTAssertEqual(toNil[0].blurRadius, 5.0, accuracy: 0.0001)
    }

    /// Test lerpList() with empty lists.
    func testLerpListWithEmptyLists() {
        let empty: [BoxShadow] = []
        let shadows = [BoxShadow(blurRadius: 10.0)]

        // Empty with non-empty
        let result1 = BoxShadow.lerpList(empty, shadows, 0.5)!
        XCTAssertEqual(result1.count, 1)
        XCTAssertEqual(result1[0].blurRadius, 5.0, accuracy: 0.0001)

        // Both empty
        let result2 = BoxShadow.lerpList(empty, empty, 0.5)!
        XCTAssertEqual(result2.count, 0)
    }

    /// Test lerpList() with identical inputs returns same value.
    func testLerpListIdentical() {
        let shadows = [
            BoxShadow(blurRadius: 10.0),
            BoxShadow(blurRadius: 20.0)
        ]

        let result = BoxShadow.lerpList(shadows, shadows, 0.5)

        XCTAssertEqual(result, shadows)
    }

    // MARK: - Equality Tests

    /// Test equality of box shadows.
    ///
    /// **Dart Source:** `box_shadow.dart:158-172` - operator ==
    func testEquality() {
        let shadow1 = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )
        let shadow2 = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )
        let shadow3 = BoxShadow(
            color: Color(0xFF00FF00),  // Different color
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )

        XCTAssertEqual(shadow1, shadow2, "Shadows with same values should be equal")
        XCTAssertNotEqual(shadow1, shadow3, "Shadows with different values should not be equal")
    }

    /// Test inequality for each property.
    func testInequalityForEachProperty() {
        let base = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )

        // Different color
        XCTAssertNotEqual(base, base.copyWith(color: Color(0xFF00FF00)))

        // Different offset
        XCTAssertNotEqual(base, base.copyWith(offset: Offset(0.0, 0.0)))

        // Different blurRadius
        XCTAssertNotEqual(base, base.copyWith(blurRadius: 0.0))

        // Different spreadRadius
        XCTAssertNotEqual(base, base.copyWith(spreadRadius: 0.0))

        // Different blurStyle
        XCTAssertNotEqual(base, base.copyWith(blurStyle: .normal))
    }

    // MARK: - Hashable Tests

    /// Test hash code consistency.
    ///
    /// **Dart Source:** `box_shadow.dart:174-175` - hashCode
    func testHashCodeConsistency() {
        let shadow1 = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )
        let shadow2 = BoxShadow(
            color: Color(0xFFFF0000),
            offset: Offset(5.0, 10.0),
            blurRadius: 15.0,
            spreadRadius: 3.0,
            blurStyle: .outer
        )

        XCTAssertEqual(shadow1.hashValue, shadow2.hashValue, "Equal shadows should have equal hash values")
    }

    /// Test that shadows can be used as dictionary keys.
    func testAsSetElement() {
        let shadow1 = BoxShadow(blurRadius: 10.0)
        let shadow2 = BoxShadow(blurRadius: 10.0)
        let shadow3 = BoxShadow(blurRadius: 20.0)

        var set = Set<BoxShadow>()
        set.insert(shadow1)
        set.insert(shadow2)  // Should not increase count (equal to shadow1)
        set.insert(shadow3)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(shadow1))
        XCTAssertTrue(set.contains(shadow3))
    }

    // MARK: - CustomStringConvertible Tests

    /// Test toString output format.
    ///
    /// **Dart Source:** `box_shadow.dart:177-179` - toString()
    func testDescription() {
        let shadow = BoxShadow(
            color: Color(0xFF000000),
            offset: Offset(1.0, 2.0),
            blurRadius: 3.0,
            spreadRadius: 4.0,
            blurStyle: .normal
        )

        let description = shadow.description

        // Verify it contains key components
        XCTAssertTrue(description.hasPrefix("BoxShadow("))
        XCTAssertTrue(description.contains("3.0"))  // blurRadius
        XCTAssertTrue(description.contains("4.0"))  // spreadRadius
    }

    /// Test description uses debugFormatDouble for formatting.
    func testDescriptionWithDebugFormatDouble() {
        let shadow = BoxShadow(
            color: Color(0xFF000000),
            offset: .zero,
            blurRadius: 10.5,
            spreadRadius: 2.5
        )

        let description = shadow.description

        // debugFormatDouble should format to 1 decimal place
        XCTAssertTrue(description.contains("10.5"))
        XCTAssertTrue(description.contains("2.5"))
    }

    // MARK: - Edge Cases

    /// Test with negative blur radius (unusual but allowed).
    func testNegativeBlurRadius() {
        let shadow = BoxShadow(blurRadius: -5.0)
        XCTAssertEqual(shadow.blurRadius, -5.0)
    }

    /// Test with very large values.
    func testVeryLargeValues() {
        let shadow = BoxShadow(
            offset: Offset(1e10, 1e10),
            blurRadius: 1e10,
            spreadRadius: 1e10
        )

        XCTAssertEqual(shadow.offset.dx, 1e10)
        XCTAssertEqual(shadow.blurRadius, 1e10)
        XCTAssertEqual(shadow.spreadRadius, 1e10)
    }

    /// Test with very small values.
    func testVerySmallValues() {
        let shadow = BoxShadow(
            offset: Offset(1e-10, 1e-10),
            blurRadius: 1e-10,
            spreadRadius: 1e-10
        )

        XCTAssertEqual(shadow.offset.dx, 1e-10, accuracy: 1e-15)
        XCTAssertEqual(shadow.blurRadius, 1e-10, accuracy: 1e-15)
        XCTAssertEqual(shadow.spreadRadius, 1e-10, accuracy: 1e-15)
    }

    /// Test struct value semantics (modification creates copy).
    func testValueSemantics() {
        let original = BoxShadow(blurRadius: 10.0)
        var modified = original

        // Since BoxShadow uses let properties, we can't modify directly
        // but we can reassign
        modified = BoxShadow(blurRadius: 20.0)

        // Original should be unchanged
        XCTAssertEqual(original.blurRadius, 10.0)
        XCTAssertEqual(modified.blurRadius, 20.0)
    }
}
