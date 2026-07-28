// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Utility functions for working with matrices.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/matrix_utils.dart`

import FlutterSwiftBridge
import Foundation

// MARK: - MatrixUtils

/// Utility functions for working with matrices.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/matrix_utils.dart`
/// **Lines:** 14-543
public enum MatrixUtils {

    // MARK: - getAsTranslation

    /// Returns the given `transform` matrix as an `Offset`, if the matrix is
    /// nothing but a 2D translation.
    ///
    /// Otherwise, returns nil.
    ///
    /// **Dart Source:** `matrix_utils.dart:19-43`
    public static func getAsTranslation(_ transform: Matrix4) -> Offset? {
        // Values are stored in column-major order.
        // matrix_utils.dart:22-41
        let s = transform.storage
        if s[0] == 1.0 &&
            s[1] == 0.0 &&
            s[2] == 0.0 &&
            s[3] == 0.0 &&
            s[4] == 0.0 &&
            s[5] == 1.0 &&
            s[6] == 0.0 &&
            s[7] == 0.0 &&
            s[8] == 0.0 &&
            s[9] == 0.0 &&
            s[10] == 1.0 &&
            s[11] == 0.0 &&
            // s[12] = dx (translation x)
            // s[13] = dy (translation y)
            s[14] == 0.0 &&
            s[15] == 1.0 {
            return Offset(s[12], s[13])
        }
        return nil
    }

    // MARK: - getAsScale

    /// Returns the given `transform` matrix as a `Double` describing a uniform
    /// scale, if the matrix is nothing but a symmetric 2D scale transform.
    ///
    /// Otherwise, returns nil.
    ///
    /// **Dart Source:** `matrix_utils.dart:49-73`
    public static func getAsScale(_ transform: Matrix4) -> Double? {
        // matrix_utils.dart:52-71
        let s = transform.storage
        if s[1] == 0.0 &&
            s[2] == 0.0 &&
            s[3] == 0.0 &&
            s[4] == 0.0 &&
            s[6] == 0.0 &&
            s[7] == 0.0 &&
            s[8] == 0.0 &&
            s[9] == 0.0 &&
            s[10] == 1.0 &&
            s[11] == 0.0 &&
            s[12] == 0.0 &&
            s[13] == 0.0 &&
            s[14] == 0.0 &&
            s[15] == 1.0 &&
            s[0] == s[5] {
            return s[0]
        }
        return nil
    }

    // MARK: - matrixEquals

    /// Returns true if the given matrices are exactly equal, and false
    /// otherwise. Null values are assumed to be the identity matrix.
    ///
    /// **Dart Source:** `matrix_utils.dart:77-104`
    public static func matrixEquals(_ a: Matrix4?, _ b: Matrix4?) -> Bool {
        // matrix_utils.dart:78-80
        if a == nil && b == nil {
            return true
        }
        if let a = a, let b = b, a.storage == b.storage {
            return true
        }
        assert(a != nil || b != nil)
        // matrix_utils.dart:82-87
        if a == nil {
            return isIdentity(b!)
        }
        if b == nil {
            return isIdentity(a!)
        }
        // matrix_utils.dart:88-103
        return a!.storage == b!.storage
    }

    // MARK: - isIdentity

    /// Whether the given matrix is the identity matrix.
    ///
    /// **Dart Source:** `matrix_utils.dart:107-132`
    public static func isIdentity(_ a: Matrix4) -> Bool {
        let s = a.storage
        return s[0] == 1.0 &&
            s[1] == 0.0 &&
            s[2] == 0.0 &&
            s[3] == 0.0 &&
            s[4] == 0.0 &&
            s[5] == 1.0 &&
            s[6] == 0.0 &&
            s[7] == 0.0 &&
            s[8] == 0.0 &&
            s[9] == 0.0 &&
            s[10] == 1.0 &&
            s[11] == 0.0 &&
            s[12] == 0.0 &&
            s[13] == 0.0 &&
            s[14] == 0.0 &&
            s[15] == 1.0
    }

    // MARK: - transformPoint

    /// Applies the given matrix as a perspective transform to the given point.
    ///
    /// This function assumes the given point has a z-coordinate of 0.0. The
    /// z-coordinate of the result is ignored.
    ///
    /// While not common, this method may return (NaN, NaN), iff the given `point`
    /// results in a "point at infinity" in homogeneous coordinates after applying
    /// the `transform`.
    ///
    /// **Dart Source:** `matrix_utils.dart:145-162`
    public static func transformPoint(_ transform: Matrix4, _ point: Offset) -> Offset {
        // matrix_utils.dart:146-161
        let storage = transform.storage
        let x = point.dx
        let y = point.dy

        // Directly simulate the transform of the vector (x, y, 0, 1),
        // dropping the resulting Z coordinate, and normalizing only
        // if needed.
        let rx = storage[0] * x + storage[4] * y + storage[12]
        let ry = storage[1] * x + storage[5] * y + storage[13]
        let rw = storage[3] * x + storage[7] * y + storage[15]
        if rw == 1.0 {
            return Offset(rx, ry)
        } else {
            return Offset(rx / rw, ry / rw)
        }
    }

    // MARK: - Private Helpers for transformRect

    /// Returns a rect that bounds the result of applying the given matrix as a
    /// perspective transform to the given rect.
    ///
    /// This version of the operation is slower than the regular transformRect
    /// method, but it avoids creating infinite values from large finite values
    /// if it can.
    ///
    /// **Dart Source:** `matrix_utils.dart:170-180`
    private static func safeTransformRect(_ transform: Matrix4, _ rect: Rect) -> Rect {
        let storage = transform.storage
        let isAffine = storage[3] == 0.0 && storage[7] == 0.0 && storage[15] == 1.0

        var minMax = [0.0, 0.0, 0.0, 0.0]
        accumulate(&minMax, storage, rect.left, rect.top, true, isAffine)
        accumulate(&minMax, storage, rect.right, rect.top, false, isAffine)
        accumulate(&minMax, storage, rect.left, rect.bottom, false, isAffine)
        accumulate(&minMax, storage, rect.right, rect.bottom, false, isAffine)

        return Rect.fromLTRB(minMax[0], minMax[1], minMax[2], minMax[3])
    }

    /// Accumulates min/max values for safe rect transformation.
    ///
    /// **Dart Source:** `matrix_utils.dart:183-204`
    private static func accumulate(
        _ minMax: inout [Double],
        _ m: [Double],
        _ x: Double,
        _ y: Double,
        _ first: Bool,
        _ isAffine: Bool
    ) {
        let w = isAffine ? 1.0 : 1.0 / (m[3] * x + m[7] * y + m[15])
        let tx = (m[0] * x + m[4] * y + m[12]) * w
        let ty = (m[1] * x + m[5] * y + m[13]) * w
        if first {
            minMax[0] = tx
            minMax[2] = tx
            minMax[1] = ty
            minMax[3] = ty
        } else {
            if tx < minMax[0] {
                minMax[0] = tx
            }
            if ty < minMax[1] {
                minMax[1] = ty
            }
            if tx > minMax[2] {
                minMax[2] = tx
            }
            if ty > minMax[3] {
                minMax[3] = ty
            }
        }
    }

    // MARK: - transformRect

    /// Returns a rect that bounds the result of applying the given matrix as a
    /// perspective transform to the given rect.
    ///
    /// This function assumes the given rect is in the plane with z equals 0.0.
    /// The transformed rect is then projected back into the plane with z equals
    /// 0.0 before computing its bounding rect.
    ///
    /// **Dart Source:** `matrix_utils.dart:212-428`
    public static func transformRect(_ transform: Matrix4, _ rect: Rect) -> Rect {
        // matrix_utils.dart:213-222
        let storage = transform.storage
        let x = rect.left
        let y = rect.top
        let w = rect.right - x
        let h = rect.bottom - y

        // We want to avoid turning a finite rect into an infinite one if we can.
        // matrix_utils.dart:220-222
        if !w.isFinite || !h.isFinite {
            return safeTransformRect(transform, rect)
        }

        // Optimized rectangle transformation.
        // See matrix_utils.dart:224-369 for the extensive explanation of
        // the optimization approach.
        //
        // matrix_utils.dart:371-427
        let wx = storage[0] * w
        let hx = storage[4] * h
        let rx = storage[0] * x + storage[4] * y + storage[12]

        let wy = storage[1] * w
        let hy = storage[5] * h
        let ry = storage[1] * x + storage[5] * y + storage[13]

        if storage[3] == 0.0 && storage[7] == 0.0 && storage[15] == 1.0 {
            // Affine case: matrix_utils.dart:380-406
            var left = rx
            var right = rx
            if wx < 0 {
                left += wx
            } else {
                right += wx
            }
            if hx < 0 {
                left += hx
            } else {
                right += hx
            }

            var top = ry
            var bottom = ry
            if wy < 0 {
                top += wy
            } else {
                bottom += wy
            }
            if hy < 0 {
                top += hy
            } else {
                bottom += hy
            }

            return Rect.fromLTRB(left, top, right, bottom)
        } else {
            // Perspective case: matrix_utils.dart:407-427
            let ww = storage[3] * w
            let hw = storage[7] * h
            let rw = storage[3] * x + storage[7] * y + storage[15]

            let ulx = rx / rw
            let uly = ry / rw
            let urx = (rx + wx) / (rw + ww)
            let ury = (ry + wy) / (rw + ww)
            let llx = (rx + hx) / (rw + hw)
            let lly = (ry + hy) / (rw + hw)
            let lrx = (rx + wx + hx) / (rw + ww + hw)
            let lry = (ry + wy + hy) / (rw + ww + hw)

            return Rect.fromLTRB(
                min4(ulx, urx, llx, lrx),
                min4(uly, ury, lly, lry),
                max4(ulx, urx, llx, lrx),
                max4(uly, ury, lly, lry)
            )
        }
    }

    /// Returns the minimum of four values.
    ///
    /// **Dart Source:** `matrix_utils.dart:430-434`
    private static func min4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let e = (a < b) ? a : b
        let f = (c < d) ? c : d
        return (e < f) ? e : f
    }

    /// Returns the maximum of four values.
    ///
    /// **Dart Source:** `matrix_utils.dart:436-440`
    private static func max4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let e = (a > b) ? a : b
        let f = (c > d) ? c : d
        return (e > f) ? e : f
    }

    // MARK: - inverseTransformRect

    /// Returns a rect that bounds the result of applying the inverse of the given
    /// matrix as a perspective transform to the given rect.
    ///
    /// This function assumes the given rect is in the plane with z equals 0.0.
    /// The transformed rect is then projected back into the plane with z equals
    /// 0.0 before computing its bounding rect.
    ///
    /// **Dart Source:** `matrix_utils.dart:448-458`
    public static func inverseTransformRect(_ transform: Matrix4, _ rect: Rect) -> Rect {
        // matrix_utils.dart:453-457
        if isIdentity(transform) {
            return rect
        }
        var inverted = Matrix4.copy(transform)
        inverted.invert()
        return transformRect(inverted, rect)
    }

    // MARK: - createCylindricalProjectionTransform

    /// Create a transformation matrix which mimics the effects of tangentially
    /// wrapping the plane on which this transform is applied around a cylinder
    /// and then looking at the cylinder from a point outside the cylinder.
    ///
    /// The `radius` simulates the radius of the cylinder the plane is being
    /// wrapped onto. If the transformation is applied to a 0-dimensional dot
    /// instead of a plane, the dot would translate by +/- `radius` pixels
    /// along the `orientation` `Axis` when rotating from 0 to +/-90 degrees.
    ///
    /// A positive radius means the object is closest at 0 `angle` and a negative
    /// radius means the object is closest at pi `angle` or 180 degrees.
    ///
    /// The `angle` argument is the difference in angle in radians between the
    /// object and the viewing point.
    ///
    /// The `perspective` argument is a number between 0 and 1 where 0 means
    /// looking at the object from infinitely far with an infinitely narrow field
    /// of view and 1 means looking at the object from infinitely close with an
    /// infinitely wide field of view. Defaults to a sane but arbitrary 0.001.
    ///
    /// The `orientation` is the direction of the rotation axis.
    ///
    /// **Dart Source:** `matrix_utils.dart:492-535`
    public static func createCylindricalProjectionTransform(
        radius: Double,
        angle: Double,
        perspective: Double = 0.001,
        orientation: Axis = .vertical
    ) -> Matrix4 {
        assert(perspective >= 0 && perspective <= 1.0)

        // Pre-multiplied matrix of a projection matrix and a view matrix.
        // matrix_utils.dart:500-520
        var result = Matrix4.identity()
        result.setEntry(3, 2, -perspective)
        result.setEntry(2, 3, -radius)
        result.setEntry(3, 3, perspective * radius + 1.0)

        // Model matrix by first translating the object from the origin of the world
        // by radius in the z axis and then rotating against the world.
        // matrix_utils.dart:524-531
        let rotationMatrix: Matrix4
        switch orientation {
        case .horizontal:
            rotationMatrix = Matrix4.rotationY(angle)
        case .vertical:
            rotationMatrix = Matrix4.rotationX(angle)
        }

        result = result * (rotationMatrix * Matrix4.translationValues(0.0, 0.0, radius))

        return result
    }

    // MARK: - forceToPoint

    /// Returns a matrix that transforms every point to `offset`.
    ///
    /// **Dart Source:** `matrix_utils.dart:538-542`
    public static func forceToPoint(_ offset: Offset) -> Matrix4 {
        var m = Matrix4.identity()
        m.setRow(0, Vector4(0, 0, 0, offset.dx))
        m.setRow(1, Vector4(0, 0, 0, offset.dy))
        return m
    }
}

// MARK: - debugDescribeTransform

/// Returns a list of strings representing the given transform in a format
/// useful for `TransformProperty`.
///
/// If the argument is nil, returns a list with the single string "null".
///
/// **Dart Source:** `matrix_utils.dart:549-559`
public func debugDescribeTransform(_ transform: Matrix4?) -> [String] {
    guard let transform = transform else {
        return ["null"]
    }
    return [
        "[0] \(debugFormatDouble(transform.entry(0, 0))),\(debugFormatDouble(transform.entry(0, 1))),\(debugFormatDouble(transform.entry(0, 2))),\(debugFormatDouble(transform.entry(0, 3)))",
        "[1] \(debugFormatDouble(transform.entry(1, 0))),\(debugFormatDouble(transform.entry(1, 1))),\(debugFormatDouble(transform.entry(1, 2))),\(debugFormatDouble(transform.entry(1, 3)))",
        "[2] \(debugFormatDouble(transform.entry(2, 0))),\(debugFormatDouble(transform.entry(2, 1))),\(debugFormatDouble(transform.entry(2, 2))),\(debugFormatDouble(transform.entry(2, 3)))",
        "[3] \(debugFormatDouble(transform.entry(3, 0))),\(debugFormatDouble(transform.entry(3, 1))),\(debugFormatDouble(transform.entry(3, 2))),\(debugFormatDouble(transform.entry(3, 3)))",
    ]
}

// MARK: - TransformProperty

/// Property which handles `Matrix4` that represent transforms.
///
/// **Dart Source:** `matrix_utils.dart:562-587`
public class TransformProperty: DiagnosticsProperty<Matrix4> {
    /// Create a diagnostics property for `Matrix4` objects.
    ///
    /// **Dart Source:** `matrix_utils.dart:564-570`
    public init(
        _ name: String,
        _ value: Matrix4?,
        showName: Bool = true,
        defaultValue: Any? = nil,
        level: DiagnosticLevel = .info
    ) {
        super.init(
            name,
            value,
            showName: showName,
            defaultValue: defaultValue ?? kNoDefaultValue,
            level: level
        )
    }

    /// **Dart Source:** `matrix_utils.dart:573-586`
    public override func valueToString(parentConfiguration: TextTreeConfiguration? = nil) -> String {
        if let config = parentConfiguration, !config.lineBreakProperties {
            // Format the value on a single line to be compatible with the parent's
            // style.
            // matrix_utils.dart:577-583
            guard let value = typedValue else { return "null" }
            let values = [
                "\(debugFormatDouble(value.entry(0, 0))),\(debugFormatDouble(value.entry(0, 1))),\(debugFormatDouble(value.entry(0, 2))),\(debugFormatDouble(value.entry(0, 3)))",
                "\(debugFormatDouble(value.entry(1, 0))),\(debugFormatDouble(value.entry(1, 1))),\(debugFormatDouble(value.entry(1, 2))),\(debugFormatDouble(value.entry(1, 3)))",
                "\(debugFormatDouble(value.entry(2, 0))),\(debugFormatDouble(value.entry(2, 1))),\(debugFormatDouble(value.entry(2, 2))),\(debugFormatDouble(value.entry(2, 3)))",
                "\(debugFormatDouble(value.entry(3, 0))),\(debugFormatDouble(value.entry(3, 1))),\(debugFormatDouble(value.entry(3, 2))),\(debugFormatDouble(value.entry(3, 3)))",
            ]
            return "[\(values.joined(separator: "; "))]"
        }
        // matrix_utils.dart:585
        return debugDescribeTransform(typedValue).joined(separator: "\n")
    }
}
