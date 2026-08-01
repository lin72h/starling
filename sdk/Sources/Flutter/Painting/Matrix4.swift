// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A 4x4 matrix (column-major) equivalent to `Matrix4` from the Dart
/// `vector_math` package.
///
/// Storage layout uses column-major order, matching the Dart `vector_math`
/// convention:
///
///     storage[ 0] = col0.x   storage[ 4] = col1.x   storage[ 8] = col2.x   storage[12] = col3.x
///     storage[ 1] = col0.y   storage[ 5] = col1.y   storage[ 9] = col2.y   storage[13] = col3.y
///     storage[ 2] = col0.z   storage[ 6] = col1.z   storage[10] = col2.z   storage[14] = col3.z
///     storage[ 3] = col0.w   storage[ 7] = col1.w   storage[11] = col2.w   storage[15] = col3.w
///
/// **Dart Equivalent:** `package:vector_math/vector_math_64.dart` `Matrix4`
///
/// This is a minimal implementation providing the subset of Matrix4 API needed
/// by `MatrixUtils` and related Flutter painting code.

import Foundation
import FlutterSwiftBridge

// MARK: - Vector3

/// A 3-dimensional vector, equivalent to `Vector3` from the Dart `vector_math` package.
///
/// **Dart Equivalent:** `package:vector_math/vector_math_64.dart` `Vector3`
public struct Vector3: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Dot product of two `Vector3` values.
    ///
    /// **Dart Equivalent:** `double dot(Vector3 other)`
    public func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    /// Subtracts two `Vector3` values component-wise.
    ///
    /// **Dart Equivalent:** `Vector3 operator -(Vector3 other)`
    public static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    /// Multiplies a `Vector3` by a scalar.
    ///
    /// **Dart Equivalent:** `Vector3 operator *(double scale)`
    public static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}

// MARK: - Vector4

/// A 4-dimensional vector, equivalent to `Vector4` from the Dart `vector_math` package.
///
/// **Dart Equivalent:** `package:vector_math/vector_math_64.dart` `Vector4`
public struct Vector4: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}

// MARK: - Matrix4

/// A 4x4 column-major matrix.
///
/// **Dart Equivalent:** `package:vector_math/vector_math_64.dart` `Matrix4`
public struct Matrix4: Equatable, Sendable, CustomStringConvertible {

    // MARK: - Storage

    /// The 16 elements stored in column-major order.
    public var storage: [Double]

    // MARK: - Initializers

    /// Creates a matrix from a 16-element column-major array.
    public init(storage: [Double]) {
        assert(storage.count == 16, "Matrix4 requires exactly 16 elements")
        self.storage = storage
    }

    /// Creates the identity matrix.
    ///
    /// **Dart Equivalent:** `Matrix4.identity()`
    public static func identity() -> Matrix4 {
        Matrix4(storage: [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ])
    }

    /// Creates a zero matrix.
    ///
    /// **Dart Equivalent:** `Matrix4.zero()`
    public static func zero() -> Matrix4 {
        Matrix4(storage: [Double](repeating: 0.0, count: 16))
    }

    /// Creates a copy of the given matrix.
    ///
    /// **Dart Equivalent:** `Matrix4.copy(other)`
    public static func copy(_ other: Matrix4) -> Matrix4 {
        Matrix4(storage: Array(other.storage))
    }

    /// Creates a rotation matrix around the X axis by `radians`.
    ///
    /// **Dart Equivalent:** `Matrix4.rotationX(radians)`
    public static func rotationX(_ radians: Double) -> Matrix4 {
        let c = cos(radians)
        let s = sin(radians)
        return Matrix4(storage: [
            1, 0,  0, 0,
            0, c,  s, 0,
            0, -s, c, 0,
            0, 0,  0, 1,
        ])
    }

    /// Creates a rotation matrix around the Y axis by `radians`.
    ///
    /// **Dart Equivalent:** `Matrix4.rotationY(radians)`
    public static func rotationY(_ radians: Double) -> Matrix4 {
        let c = cos(radians)
        let s = sin(radians)
        return Matrix4(storage: [
            c, 0, -s, 0,
            0, 1,  0, 0,
            s, 0,  c, 0,
            0, 0,  0, 1,
        ])
    }

    /// Creates a rotation matrix around the Z axis by `radians`.
    ///
    /// **Dart Equivalent:** `Matrix4.rotationZ(radians)`
    public static func rotationZ(_ radians: Double) -> Matrix4 {
        let c = cos(radians)
        let s = sin(radians)
        return Matrix4(storage: [
            c,  s, 0, 0,
            -s, c, 0, 0,
            0,  0, 1, 0,
            0,  0, 0, 1,
        ])
    }

    /// Creates a translation matrix.
    ///
    /// **Dart Equivalent:** `Matrix4.translationValues(x, y, z)`
    public static func translationValues(_ x: Double, _ y: Double, _ z: Double) -> Matrix4 {
        Matrix4(storage: [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1,
        ])
    }

    /// Creates a diagonal matrix with the given values.
    ///
    /// **Dart Equivalent:** `Matrix4.diagonal3Values(x, y, z)`
    public static func diagonal3Values(_ x: Double, _ y: Double, _ z: Double) -> Matrix4 {
        Matrix4(storage: [
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        ])
    }

    // MARK: - Entry Access

    /// Returns the matrix entry at `row`, `col`.
    ///
    /// **Dart Equivalent:** `entry(row, col)`
    public func entry(_ row: Int, _ col: Int) -> Double {
        storage[col * 4 + row]
    }

    /// Sets the matrix entry at `row`, `col`.
    ///
    /// **Dart Equivalent:** `setEntry(row, col, v)`
    public mutating func setEntry(_ row: Int, _ col: Int, _ v: Double) {
        storage[col * 4 + row] = v
    }

    // MARK: - Row/Column Access

    /// Sets the specified `row` from a `Vector4`.
    ///
    /// **Dart Equivalent:** `setRow(row, v)`
    public mutating func setRow(_ row: Int, _ v: Vector4) {
        storage[row] = v.x
        storage[4 + row] = v.y
        storage[8 + row] = v.z
        storage[12 + row] = v.w
    }

    /// Returns the row at `index` as a `Vector4`.
    ///
    /// **Dart Equivalent:** `getRow(index)`
    public func getRow(_ index: Int) -> Vector4 {
        Vector4(storage[index], storage[4 + index], storage[8 + index], storage[12 + index])
    }

    /// Returns the column at `index` as a `Vector4`.
    ///
    /// **Dart Equivalent:** `getColumn(index)`
    public func getColumn(_ index: Int) -> Vector4 {
        let base = index * 4
        return Vector4(storage[base], storage[base + 1], storage[base + 2], storage[base + 3])
    }

    /// Sets the specified `column` from a `Vector4`.
    ///
    /// **Dart Equivalent:** `setColumn(column, v)`
    public mutating func setColumn(_ column: Int, _ v: Vector4) {
        let base = column * 4
        storage[base] = v.x
        storage[base + 1] = v.y
        storage[base + 2] = v.z
        storage[base + 3] = v.w
    }

    // MARK: - Mutation Methods

    /// Post-multiplies this matrix by a translation.
    ///
    /// **Dart Equivalent:** `translate(x, [y, z])`
    public mutating func translate(_ x: Double, _ y: Double = 0.0, _ z: Double = 0.0) {
        // M = M * T where T is translation matrix
        // This effectively adds x*col0 + y*col1 + z*col2 to col3
        let t1 = storage[0] * x + storage[4] * y + storage[8]  * z + storage[12]
        let t2 = storage[1] * x + storage[5] * y + storage[9]  * z + storage[13]
        let t3 = storage[2] * x + storage[6] * y + storage[10] * z + storage[14]
        let t4 = storage[3] * x + storage[7] * y + storage[11] * z + storage[15]
        storage[12] = t1
        storage[13] = t2
        storage[14] = t3
        storage[15] = t4
    }

    /// Post-multiplies this matrix by a uniform scale.
    ///
    /// **Dart Equivalent:** `scale(sx, [sy, sz])`
    public mutating func scale(_ sx: Double, _ sy: Double? = nil, _ sz: Double? = nil) {
        let effectiveSy = sy ?? sx
        let effectiveSz = sz ?? sx
        storage[0] *= sx;          storage[1] *= sx;          storage[2] *= sx;          storage[3] *= sx
        storage[4] *= effectiveSy; storage[5] *= effectiveSy; storage[6] *= effectiveSy; storage[7] *= effectiveSy
        storage[8] *= effectiveSz; storage[9] *= effectiveSz; storage[10] *= effectiveSz; storage[11] *= effectiveSz
    }

    /// Post-multiplies this matrix by a rotation around the X axis.
    ///
    /// **Dart Equivalent:** `rotateX(angle)`
    public mutating func rotateX(_ angle: Double) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        for i in 0..<4 {
            let old1 = storage[4 + i]
            let old2 = storage[8 + i]
            storage[4 + i] = old1 * cosAngle + old2 * sinAngle
            storage[8 + i] = old2 * cosAngle - old1 * sinAngle
        }
    }

    /// Post-multiplies this matrix by a rotation around the Y axis.
    ///
    /// **Dart Equivalent:** `rotateY(angle)`
    public mutating func rotateY(_ angle: Double) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        for i in 0..<4 {
            let old0 = storage[i]
            let old2 = storage[8 + i]
            storage[i] = old0 * cosAngle - old2 * sinAngle
            storage[8 + i] = old0 * sinAngle + old2 * cosAngle
        }
    }

    /// Post-multiplies this matrix by a rotation around the Z axis.
    ///
    /// **Dart Equivalent:** `rotateZ(angle)`
    public mutating func rotateZ(_ angle: Double) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        for i in 0..<4 {
            let old0 = storage[i]
            let old1 = storage[4 + i]
            storage[i] = old0 * cosAngle + old1 * sinAngle
            storage[4 + i] = old1 * cosAngle - old0 * sinAngle
        }
    }

    /// Sets this matrix to the identity matrix.
    ///
    /// **Dart Equivalent:** `setIdentity()`
    public mutating func setIdentity() {
        storage = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]
    }

    /// Sets all entries of this matrix to zero.
    ///
    /// **Dart Equivalent:** `setZero()`
    public mutating func setZero() {
        storage = [Double](repeating: 0.0, count: 16)
    }

    /// Multiplies this matrix by `other` in place: `self = self * other`.
    ///
    /// **Dart Equivalent:** `multiply(Matrix4 arg)`
    public mutating func multiply(_ other: Matrix4) {
        let a = storage
        let b = other.storage
        var result = [Double](repeating: 0, count: 16)
        for col in 0..<4 {
            for row in 0..<4 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += a[k * 4 + row] * b[col * 4 + k]
                }
                result[col * 4 + row] = sum
            }
        }
        storage = result
    }

    // MARK: - Inversion

    /// The determinant of this matrix.
    ///
    /// **Dart Equivalent:** `determinant()`
    public func determinant() -> Double {
        let a0 = storage[0]
        let a1 = storage[1]
        let a2 = storage[2]
        let a3 = storage[3]
        let b0 = storage[4]
        let b1 = storage[5]
        let b2 = storage[6]
        let b3 = storage[7]
        let c0 = storage[8]
        let c1 = storage[9]
        let c2 = storage[10]
        let c3 = storage[11]
        let d0 = storage[12]
        let d1 = storage[13]
        let d2 = storage[14]
        let d3 = storage[15]

        let s0 = a0 * b1 - a1 * b0
        let s1 = a0 * b2 - a2 * b0
        let s2 = a0 * b3 - a3 * b0
        let s3 = a1 * b2 - a2 * b1
        let s4 = a1 * b3 - a3 * b1
        let s5 = a2 * b3 - a3 * b2

        let c5_val = c2 * d3 - c3 * d2
        let c4_val = c1 * d3 - c3 * d1
        let c3_val = c1 * d2 - c2 * d1
        let c2_val = c0 * d3 - c3 * d0
        let c1_val = c0 * d2 - c2 * d0
        let c0_val = c0 * d1 - c1 * d0

        return s0 * c5_val - s1 * c4_val + s2 * c3_val + s3 * c2_val - s4 * c1_val + s5 * c0_val
    }

    /// Inverts this matrix in place.
    ///
    /// **Dart Equivalent:** `invert()`
    @discardableResult
    public mutating func invert() -> Double {
        let det = invertInternal()
        return det
    }

    /// Returns the inverse of `arg`, or `nil` if the matrix is singular
    /// (determinant is zero).
    ///
    /// **Dart Equivalent:** `static Matrix4? tryInvert(Matrix4 arg)`
    public static func tryInvert(_ arg: Matrix4) -> Matrix4? {
        var result = arg
        let det = result.invert()
        if det == 0.0 {
            return nil
        }
        return result
    }

    /// Internal inversion implementation. Returns determinant.
    private mutating func invertInternal() -> Double {
        let a00 = storage[0]
        let a01 = storage[1]
        let a02 = storage[2]
        let a03 = storage[3]
        let a10 = storage[4]
        let a11 = storage[5]
        let a12 = storage[6]
        let a13 = storage[7]
        let a20 = storage[8]
        let a21 = storage[9]
        let a22 = storage[10]
        let a23 = storage[11]
        let a30 = storage[12]
        let a31 = storage[13]
        let a32 = storage[14]
        let a33 = storage[15]

        let b00 = a00 * a11 - a01 * a10
        let b01 = a00 * a12 - a02 * a10
        let b02 = a00 * a13 - a03 * a10
        let b03 = a01 * a12 - a02 * a11
        let b04 = a01 * a13 - a03 * a11
        let b05 = a02 * a13 - a03 * a12
        let b06 = a20 * a31 - a21 * a30
        let b07 = a20 * a32 - a22 * a30
        let b08 = a20 * a33 - a23 * a30
        let b09 = a21 * a32 - a22 * a31
        let b10 = a21 * a33 - a23 * a31
        let b11 = a22 * a33 - a23 * a32

        let det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06
        if det == 0.0 {
            // Singular matrix, set to zero
            storage = [Double](repeating: 0, count: 16)
            return 0.0
        }

        let invDet = 1.0 / det

        storage[0]  = ( a11 * b11 - a12 * b10 + a13 * b09) * invDet
        storage[1]  = (-a01 * b11 + a02 * b10 - a03 * b09) * invDet
        storage[2]  = ( a31 * b05 - a32 * b04 + a33 * b03) * invDet
        storage[3]  = (-a21 * b05 + a22 * b04 - a23 * b03) * invDet
        storage[4]  = (-a10 * b11 + a12 * b08 - a13 * b07) * invDet
        storage[5]  = ( a00 * b11 - a02 * b08 + a03 * b07) * invDet
        storage[6]  = (-a30 * b05 + a32 * b02 - a33 * b01) * invDet
        storage[7]  = ( a20 * b05 - a22 * b02 + a23 * b01) * invDet
        storage[8]  = ( a10 * b10 - a11 * b08 + a13 * b06) * invDet
        storage[9]  = (-a00 * b10 + a01 * b08 - a03 * b06) * invDet
        storage[10] = ( a30 * b04 - a31 * b02 + a33 * b00) * invDet
        storage[11] = (-a20 * b04 + a21 * b02 - a23 * b00) * invDet
        storage[12] = (-a10 * b09 + a11 * b07 - a12 * b06) * invDet
        storage[13] = ( a00 * b09 - a01 * b07 + a02 * b06) * invDet
        storage[14] = (-a30 * b03 + a31 * b01 - a32 * b00) * invDet
        storage[15] = ( a20 * b03 - a21 * b01 + a22 * b00) * invDet

        return det
    }

    // MARK: - Perspective Transform

    /// Transforms the given `Vector3` by this matrix using perspective division.
    ///
    /// **Dart Equivalent:** `perspectiveTransform(arg)`
    public func perspectiveTransform(_ arg: Vector3) -> Vector3 {
        let x = arg.x
        let y = arg.y
        let z = arg.z

        let rw = 1.0 / (storage[3] * x + storage[7] * y + storage[11] * z + storage[15])
        let rx = (storage[0] * x + storage[4] * y + storage[8]  * z + storage[12]) * rw
        let ry = (storage[1] * x + storage[5] * y + storage[9]  * z + storage[13]) * rw
        let rz = (storage[2] * x + storage[6] * y + storage[10] * z + storage[14]) * rw

        return Vector3(rx, ry, rz)
    }

    // MARK: - Multiplication

    /// Matrix multiplication.
    ///
    /// **Dart Equivalent:** `operator *(Matrix4 arg)`
    public static func * (lhs: Matrix4, rhs: Matrix4) -> Matrix4 {
        let a = lhs.storage
        let b = rhs.storage
        var result = [Double](repeating: 0, count: 16)
        for col in 0..<4 {
            for row in 0..<4 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += a[k * 4 + row] * b[col * 4 + k]
                }
                result[col * 4 + row] = sum
            }
        }
        return Matrix4(storage: result)
    }

    // MARK: - Zero Check

    /// Returns `true` if all entries in this matrix are zero.
    ///
    /// **Dart Equivalent:** `isZero()` from `package:vector_math/vector_math_64.dart`
    public func isZero() -> Bool {
        storage.allSatisfy { $0 == 0.0 }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        var lines = [String]()
        for row in 0..<4 {
            let vals = (0..<4).map { col in
                String(format: "%.6f", storage[col * 4 + row])
            }
            lines.append("[\(row)] \(vals.joined(separator: ",")),")
        }
        return lines.joined(separator: "\n")
    }
}
