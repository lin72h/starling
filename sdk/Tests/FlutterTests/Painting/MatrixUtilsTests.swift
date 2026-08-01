// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for MatrixUtils utilities.
///
/// **Dart Test Source:** `packages/flutter/test/painting/matrix_utils_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// Produces the same computation as `MatrixUtils.transformPoint` but it uses
/// the built-in perspective transform methods in the Matrix4 class as a
/// golden implementation of the optimized `MatrixUtils.transformPoint`
/// to make sure optimizations do not contain bugs.
///
/// **Dart Test Source:** `matrix_utils_test.dart:174-178`
private func goldenTransformPoint(_ transform: Matrix4, _ point: Offset) -> Offset {
    let position3 = Vector3(point.dx, point.dy, 0.0)
    let transformed3 = transform.perspectiveTransform(position3)
    return Offset(transformed3.x, transformed3.y)
}

/// Produces the same computation as `MatrixUtils.transformRect` but it does this
/// one point at a time. This function is used as the golden implementation of the
/// optimized `MatrixUtils.transformRect` to make sure optimizations do not contain
/// bugs.
///
/// **Dart Test Source:** `matrix_utils_test.dart:184-195`
private func goldenVectorWiseTransformRect(_ transform: Matrix4, _ rect: Rect) -> Rect {
    let point1 = goldenTransformPoint(transform, rect.topLeft)
    let point2 = goldenTransformPoint(transform, rect.topRight)
    let point3 = goldenTransformPoint(transform, rect.bottomLeft)
    let point4 = goldenTransformPoint(transform, rect.bottomRight)
    return Rect.fromLTRB(
        testMin4(point1.dx, point2.dx, point3.dx, point4.dx),
        testMin4(point1.dy, point2.dy, point3.dy, point4.dy),
        testMax4(point1.dx, point2.dx, point3.dx, point4.dx),
        testMax4(point1.dy, point2.dy, point3.dy, point4.dy)
    )
}

/// **Dart Test Source:** `matrix_utils_test.dart:197-199`
private func testMin4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
    return min(a, min(b, min(c, d)))
}

/// **Dart Test Source:** `matrix_utils_test.dart:201-203`
private func testMax4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
    return max(a, max(b, max(c, d)))
}

/// Asserts that all 16 elements of two Matrix4 values are approximately equal.
private func assertMatrixEquals(
    _ actual: Matrix4,
    _ expected: Matrix4,
    accuracy: Double = 1e-10,
    file: StaticString = #file,
    line: UInt = #line
) {
    for i in 0..<16 {
        XCTAssertEqual(
            actual.storage[i],
            expected.storage[i],
            accuracy: accuracy,
            "Element [\(i)] mismatch: \(actual.storage[i]) vs \(expected.storage[i])",
            file: file,
            line: line
        )
    }
}

/// Asserts that all edges of two `Rect` values are approximately equal.
private func assertRectEquals(
    _ actual: Rect,
    _ expected: Rect,
    accuracy: Double = 0.00001,
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertEqual(actual.left, expected.left, accuracy: accuracy, "left mismatch", file: file, line: line)
    XCTAssertEqual(actual.top, expected.top, accuracy: accuracy, "top mismatch", file: file, line: line)
    XCTAssertEqual(actual.right, expected.right, accuracy: accuracy, "right mismatch", file: file, line: line)
    XCTAssertEqual(actual.bottom, expected.bottom, accuracy: accuracy, "bottom mismatch", file: file, line: line)
}

// MARK: - MatrixUtilsTests

final class MatrixUtilsTests: XCTestCase {

    // MARK: - transformRect handles very large finite values

    /// **Dart Test:** `matrix_utils_test.dart:12-22`
    /// "MatrixUtils.transformRect handles very large finite values"
    func testTransformRectHandlesVeryLargeFiniteValues() {
        // matrix_utils_test.dart:13-18
        let evilRect = Rect.fromLTRB(
            0.0,
            -1.7976931348623157e+308,
            800.0,
            1.7976931348623157e+308
        )
        // matrix_utils_test.dart:19
        var transform = Matrix4.identity()
        transform.translate(10.0)
        // matrix_utils_test.dart:20-21
        let transformedRect = MatrixUtils.transformRect(transform, evilRect)
        XCTAssertTrue(transformedRect.isFinite)
    }

    // MARK: - getAsTranslation

    /// **Dart Test:** `matrix_utils_test.dart:24-55`
    /// "MatrixUtils.getAsTranslation()"
    func testGetAsTranslation() {
        // Identity -> Offset.zero
        // matrix_utils_test.dart:26-27
        var test = Matrix4.identity()
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset.zero)

        // Zero matrix -> nil
        // matrix_utils_test.dart:28-29
        test = Matrix4.zero()
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Rotation around X -> nil
        // matrix_utils_test.dart:30-31
        test = Matrix4.rotationX(1.0)
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Rotation around Z -> nil
        // matrix_utils_test.dart:32-33
        test = Matrix4.rotationZ(1.0)
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Pure translation (z=0) -> Offset(1,2)
        // matrix_utils_test.dart:34-35
        test = Matrix4.translationValues(1.0, 2.0, 0.0)
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset(1.0, 2.0))

        // Translation with non-zero z -> nil
        // matrix_utils_test.dart:36-37
        test = Matrix4.translationValues(1.0, 2.0, 3.0)
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Identity, then rotateX -> nil
        // matrix_utils_test.dart:39-42
        test = Matrix4.identity()
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset.zero)
        test.rotateX(2.0)
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Identity, then scale -> nil
        // matrix_utils_test.dart:44-47
        test = Matrix4.identity()
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset.zero)
        test.scale(2.0)
        XCTAssertNil(MatrixUtils.getAsTranslation(test))

        // Identity, then translate twice
        // matrix_utils_test.dart:49-54
        test = Matrix4.identity()
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset.zero)
        test.translate(2.0, -2.0)
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset(2.0, -2.0))
        test.translate(4.0, 8.0)
        XCTAssertEqual(MatrixUtils.getAsTranslation(test), Offset(6.0, 6.0))
    }

    // MARK: - Cylindrical Projection Transform

    /// **Dart Test:** `matrix_utils_test.dart:57-65`
    /// "cylindricalProjectionTransform identity"
    func testCylindricalProjectionTransformIdentity() {
        let initialState = MatrixUtils.createCylindricalProjectionTransform(
            radius: 0.0,
            angle: 0.0,
            perspective: 0.0
        )
        assertMatrixEquals(initialState, Matrix4.identity())
    }

    /// **Dart Test:** `matrix_utils_test.dart:67-75`
    /// "cylindricalProjectionTransform rotate with no radius"
    func testCylindricalProjectionTransformRotateNoRadius() {
        let simpleRotate = MatrixUtils.createCylindricalProjectionTransform(
            radius: 0.0,
            angle: .pi / 2.0,
            perspective: 0.0
        )
        assertMatrixEquals(simpleRotate, Matrix4.rotationX(.pi / 2.0))
    }

    /// **Dart Test:** `matrix_utils_test.dart:77-85`
    /// "cylindricalProjectionTransform radius does not change scale"
    func testCylindricalProjectionTransformRadiusDoesNotChangeScale() {
        let noRotation = MatrixUtils.createCylindricalProjectionTransform(
            radius: 1000000.0,
            angle: 0.0,
            perspective: 0.0
        )
        assertMatrixEquals(noRotation, Matrix4.identity())
    }

    /// **Dart Test:** `matrix_utils_test.dart:87-111`
    /// "cylindricalProjectionTransform calculation spot check"
    func testCylindricalProjectionTransformCalculationSpotCheck() {
        let actual = MatrixUtils.createCylindricalProjectionTransform(
            radius: 100.0,
            angle: .pi / 3.0
        )

        // matrix_utils_test.dart:93-110
        let s = actual.storage
        XCTAssertEqual(s[0], 1.0)
        XCTAssertEqual(s[1], 0.0)
        XCTAssertEqual(s[2], 0.0)
        XCTAssertEqual(s[3], 0.0)
        XCTAssertEqual(s[4], 0.0)
        XCTAssertEqual(s[5], 0.5, accuracy: 1e-10)
        XCTAssertEqual(s[6], 0.8660254037844386, accuracy: 1e-10)
        XCTAssertEqual(s[7], -0.0008660254037844386, accuracy: 1e-10)
        XCTAssertEqual(s[8], 0.0)
        XCTAssertEqual(s[9], -0.8660254037844386, accuracy: 1e-10)
        XCTAssertEqual(s[10], 0.5, accuracy: 1e-10)
        XCTAssertEqual(s[11], -0.0005, accuracy: 1e-10)
        XCTAssertEqual(s[12], 0.0)
        XCTAssertEqual(s[13], -86.60254037844386, accuracy: 1e-10)
        XCTAssertEqual(s[14], -50.0, accuracy: 1e-10)
        XCTAssertEqual(s[15], 1.05, accuracy: 1e-10)
    }

    // MARK: - forceToPoint

    /// **Dart Test:** `matrix_utils_test.dart:113-131`
    /// "forceToPoint"
    func testForceToPoint() {
        let forcedOffset = Offset(20, -30)
        let forcedTransform = MatrixUtils.forceToPoint(forcedOffset)

        // matrix_utils_test.dart:117
        XCTAssertEqual(MatrixUtils.transformPoint(forcedTransform, forcedOffset), forcedOffset)

        // matrix_utils_test.dart:119
        XCTAssertEqual(MatrixUtils.transformPoint(forcedTransform, Offset.zero), forcedOffset)

        // matrix_utils_test.dart:121
        XCTAssertEqual(MatrixUtils.transformPoint(forcedTransform, Offset(1, 1)), forcedOffset)

        // matrix_utils_test.dart:123
        XCTAssertEqual(MatrixUtils.transformPoint(forcedTransform, Offset(-1, -1)), forcedOffset)

        // matrix_utils_test.dart:125
        XCTAssertEqual(MatrixUtils.transformPoint(forcedTransform, Offset(-20, 30)), forcedOffset)

        // matrix_utils_test.dart:127-130
        XCTAssertEqual(
            MatrixUtils.transformPoint(forcedTransform, Offset(-1.2344, 1422434.23)),
            forcedOffset
        )
    }

    // MARK: - transformRect with no perspective

    /// **Dart Test:** `matrix_utils_test.dart:133-150`
    /// "transformRect with no perspective (w = 1)"
    func testTransformRectNoPerspective() {
        let rectangle20x20 = Rect.fromLTRB(10, 20, 30, 40)

        // Identity
        // matrix_utils_test.dart:137
        XCTAssertEqual(
            MatrixUtils.transformRect(Matrix4.identity(), rectangle20x20),
            rectangle20x20
        )

        // 2D Scaling
        // matrix_utils_test.dart:140-143
        XCTAssertEqual(
            MatrixUtils.transformRect(Matrix4.diagonal3Values(2, 2, 2), rectangle20x20),
            Rect.fromLTRB(20, 40, 60, 80)
        )

        // Rotation
        // matrix_utils_test.dart:146-149
        let rotated = MatrixUtils.transformRect(Matrix4.rotationZ(.pi / 2.0), rectangle20x20)
        assertRectEquals(rotated, Rect.fromLTRB(-40.0, 10.0, -20.0, 30.0))
    }

    // MARK: - transformRect with perspective

    /// **Dart Test:** `matrix_utils_test.dart:152-167`
    /// "transformRect with perspective (w != 1)"
    func testTransformRectWithPerspective() {
        let transform = MatrixUtils.createCylindricalProjectionTransform(
            radius: 10.0,
            angle: .pi / 8.0,
            perspective: 0.3
        )

        // matrix_utils_test.dart:159-166
        for i in 1..<10000 {
            let d = Double(i)
            let rect = Rect.fromLTRB(11.0 * d, 12.0 * d, 15.0 * d, 18.0 * d)
            let golden = goldenVectorWiseTransformRect(transform, rect)
            assertRectEquals(
                MatrixUtils.transformRect(transform, rect),
                golden
            )
        }
    }

    // MARK: - Additional MatrixUtils Tests

    /// Test getAsScale with various matrices.
    func testGetAsScale() {
        // Identity has scale 1.0
        XCTAssertEqual(MatrixUtils.getAsScale(Matrix4.identity()), 1.0)

        // Uniform scale of 2.0
        let scaled = Matrix4.diagonal3Values(2.0, 2.0, 1.0)
        XCTAssertEqual(MatrixUtils.getAsScale(scaled), 2.0)

        // Non-uniform scale returns nil
        let nonUniform = Matrix4.diagonal3Values(2.0, 3.0, 1.0)
        XCTAssertNil(MatrixUtils.getAsScale(nonUniform))

        // Translation returns nil
        XCTAssertNil(MatrixUtils.getAsScale(Matrix4.translationValues(1.0, 2.0, 0.0)))
    }

    /// Test matrixEquals with various cases.
    func testMatrixEquals() {
        XCTAssertTrue(MatrixUtils.matrixEquals(nil, nil))
        XCTAssertTrue(MatrixUtils.matrixEquals(Matrix4.identity(), nil))
        XCTAssertTrue(MatrixUtils.matrixEquals(nil, Matrix4.identity()))
        XCTAssertTrue(MatrixUtils.matrixEquals(Matrix4.identity(), Matrix4.identity()))

        let translated = Matrix4.translationValues(1.0, 2.0, 0.0)
        XCTAssertFalse(MatrixUtils.matrixEquals(translated, nil))
        XCTAssertFalse(MatrixUtils.matrixEquals(nil, translated))
        XCTAssertTrue(MatrixUtils.matrixEquals(translated, Matrix4.translationValues(1.0, 2.0, 0.0)))
    }

    /// Test isIdentity.
    func testIsIdentity() {
        XCTAssertTrue(MatrixUtils.isIdentity(Matrix4.identity()))
        XCTAssertFalse(MatrixUtils.isIdentity(Matrix4.translationValues(1.0, 0.0, 0.0)))
        XCTAssertFalse(MatrixUtils.isIdentity(Matrix4.zero()))
    }

    /// Test inverseTransformRect with identity returns the same rect.
    func testInverseTransformRectIdentity() {
        let rect = Rect.fromLTRB(10, 20, 30, 40)
        XCTAssertEqual(MatrixUtils.inverseTransformRect(Matrix4.identity(), rect), rect)
    }

    /// Test debugDescribeTransform with nil.
    func testDebugDescribeTransformNil() {
        XCTAssertEqual(debugDescribeTransform(nil), ["null"])
    }

    /// Test debugDescribeTransform with identity.
    func testDebugDescribeTransformIdentity() {
        let lines = debugDescribeTransform(Matrix4.identity())
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0], "[0] 1.0,0.0,0.0,0.0")
        XCTAssertEqual(lines[1], "[1] 0.0,1.0,0.0,0.0")
        XCTAssertEqual(lines[2], "[2] 0.0,0.0,1.0,0.0")
        XCTAssertEqual(lines[3], "[3] 0.0,0.0,0.0,1.0")
    }

    /// Test TransformProperty valueToString.
    func testTransformPropertyValueToString() {
        let prop = TransformProperty("transform", Matrix4.identity())
        let result = prop.valueToString()
        // Should contain the debug-formatted identity matrix
        XCTAssertTrue(result.contains("[0]"))
        XCTAssertTrue(result.contains("1.0"))
    }
}
