// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A least-squares polynomial solver and supporting types.
///
/// Uses QR decomposition to fit a polynomial to a set of weighted data points.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/lsq_solver.dart`

import Foundation

// MARK: - LSQVector

/// A vector backed by a contiguous region of a `Double` array.
///
/// This is an internal helper type for the least-squares solver. It supports
/// element access via an offset into a shared storage array, dot product, and
/// Euclidean norm.
///
/// **Dart Source:** `lsq_solver.dart:10-38` (class `_Vector`)
internal struct LSQVector {
    /// The underlying storage array.
    var elements: [Double]

    /// The offset into `elements` where this vector's data begins.
    let offset: Int

    /// The number of elements in this vector.
    let length: Int

    /// Creates a zero-initialized vector of the given size.
    ///
    /// **Dart Source:** `lsq_solver.dart:11`
    init(size: Int) {
        self.elements = [Double](repeating: 0.0, count: size)
        self.offset = 0
        self.length = size
    }

    /// Creates a vector that references a subrange of an existing array.
    ///
    /// - Parameters:
    ///   - values: The backing array.
    ///   - offset: The starting index within `values`.
    ///   - length: The number of elements in this vector.
    ///
    /// **Dart Source:** `lsq_solver.dart:13-16`
    init(values: [Double], offset: Int, length: Int) {
        self.elements = values
        self.offset = offset
        self.length = length
    }

    /// Accesses the element at the given logical index (offset-adjusted).
    subscript(i: Int) -> Double {
        get {
            return elements[i + offset]
        }
        set {
            elements[i + offset] = newValue
        }
    }

    /// Returns the dot product of this vector with another vector.
    ///
    /// **Dart Source:** `lsq_solver.dart:29-35`
    static func * (lhs: LSQVector, rhs: LSQVector) -> Double {
        var result = 0.0
        for i in 0..<lhs.length {
            result += lhs[i] * rhs[i]
        }
        return result
    }

    /// Returns the Euclidean norm (magnitude) of this vector.
    ///
    /// **Dart Source:** `lsq_solver.dart:37`
    func norm() -> Double {
        return (self * self).squareRoot()
    }
}

// MARK: - LSQMatrix

/// A row-major matrix of `Double` values.
///
/// This is an internal helper type for the least-squares solver. It stores
/// elements in a flat array with row-major ordering.
///
/// **Dart Source:** `lsq_solver.dart:41-53` (class `_Matrix`)
internal struct LSQMatrix {
    /// The flat storage array for matrix elements.
    var elements: [Double]

    /// The number of columns in this matrix.
    let columns: Int

    /// Creates a zero-initialized matrix with the given dimensions.
    ///
    /// **Dart Source:** `lsq_solver.dart:42`
    init(rows: Int, columns: Int) {
        self.columns = columns
        self.elements = [Double](repeating: 0.0, count: rows * columns)
    }

    /// Returns the element at the given row and column.
    ///
    /// **Dart Source:** `lsq_solver.dart:47`
    func get(_ row: Int, _ col: Int) -> Double {
        return elements[row * columns + col]
    }

    /// Sets the element at the given row and column.
    ///
    /// **Dart Source:** `lsq_solver.dart:48-50`
    mutating func set(_ row: Int, _ col: Int, _ value: Double) {
        elements[row * columns + col] = value
    }

    /// Returns a vector view of the given row.
    ///
    /// Because Swift arrays use copy-on-write, the returned vector shares
    /// storage with this matrix until either is mutated.
    ///
    /// **Dart Source:** `lsq_solver.dart:52`
    func getRow(_ row: Int) -> LSQVector {
        return LSQVector(values: elements, offset: row * columns, length: columns)
    }
}

// MARK: - PolynomialFit

/// An nth degree polynomial fit to a dataset.
///
/// **Dart Source:** `lsq_solver.dart:56-85` (class `PolynomialFit`)
public class PolynomialFit: CustomStringConvertible {
    /// Creates a polynomial fit of the given degree.
    ///
    /// There are n + 1 coefficients in a fit of degree n.
    ///
    /// **Dart Source:** `lsq_solver.dart:60`
    public init(degree: Int) {
        self.coefficients = [Double](repeating: 0.0, count: degree + 1)
    }

    /// The polynomial coefficients of the fit.
    ///
    /// For each `i`, the element `coefficients[i]` is the coefficient of
    /// the `i`-th power of the variable.
    ///
    /// **Dart Source:** `lsq_solver.dart:66`
    public var coefficients: [Double]

    /// An indicator of the quality of the fit.
    ///
    /// Larger values indicate greater quality. The value ranges from 0.0 to 1.0.
    ///
    /// The confidence is defined as the fraction of the dataset's variance
    /// that is captured by variance in the fit polynomial. In statistics
    /// textbooks this is often called "r-squared".
    ///
    /// **Dart Source:** `lsq_solver.dart:75`
    public var confidence: Double = 0.0

    /// A textual representation of this polynomial fit.
    ///
    /// **Dart Source:** `lsq_solver.dart:78-84`
    public var description: String {
        let coefficientString = coefficients
            .map { String(format: "%.3g", $0) }
            .description
        return "PolynomialFit(\(coefficientString), confidence: \(String(format: "%.3f", confidence)))"
    }
}

// MARK: - LeastSquaresSolver

/// Uses the least-squares algorithm to fit a polynomial to a set of data.
///
/// **Dart Source:** `lsq_solver.dart:88-204` (class `LeastSquaresSolver`)
public struct LeastSquaresSolver {
    /// Creates a least-squares solver.
    ///
    /// The three arrays must all have the same length.
    ///
    /// **Dart Source:** `lsq_solver.dart:90-92`
    public init(x: [Double], y: [Double], w: [Double]) {
        assert(x.count == y.count)
        assert(y.count == w.count)
        self.x = x
        self.y = y
        self.w = w
    }

    /// The x-coordinates of each data point.
    ///
    /// **Dart Source:** `lsq_solver.dart:95`
    public let x: [Double]

    /// The y-coordinates of each data point.
    ///
    /// **Dart Source:** `lsq_solver.dart:98`
    public let y: [Double]

    /// The weight to use for each data point.
    ///
    /// **Dart Source:** `lsq_solver.dart:101`
    public let w: [Double]

    /// Fits a polynomial of the given degree to the data points.
    ///
    /// When there is not enough data to fit a curve, `nil` is returned.
    ///
    /// **Dart Source:** `lsq_solver.dart:106-203`
    public func solve(degree: Int) -> PolynomialFit? {
        if degree > x.count {
            // Not enough data to fit a curve.
            return nil
        }

        let result = PolynomialFit(degree: degree)

        // Shorthands for the purpose of notation equivalence to original C++ code.
        let m = x.count
        let n = degree + 1

        // Expand the X vector to a matrix A, pre-multiplied by the weights.
        var a = LSQMatrix(rows: n, columns: m)
        for h in 0..<m {
            a.set(0, h, w[h])
            for i in 1..<n {
                a.set(i, h, a.get(i - 1, h) * x[h])
            }
        }

        // Apply the Gram-Schmidt process to A to obtain its QR decomposition.

        // Orthonormal basis, column-major order.
        var q = LSQMatrix(rows: n, columns: m)
        // Upper triangular matrix, row-major order.
        var r = LSQMatrix(rows: n, columns: n)
        for j in 0..<n {
            for h in 0..<m {
                q.set(j, h, a.get(j, h))
            }
            for i in 0..<j {
                let dot = q.getRow(j) * q.getRow(i)
                for h in 0..<m {
                    q.set(j, h, q.get(j, h) - dot * q.get(i, h))
                }
            }

            let norm = q.getRow(j).norm()
            if norm < precisionErrorTolerance {
                // Vectors are linearly dependent or zero so no solution.
                return nil
            }

            let inverseNorm = 1.0 / norm
            for h in 0..<m {
                q.set(j, h, q.get(j, h) * inverseNorm)
            }
            for i in 0..<n {
                r.set(j, i, i < j ? 0.0 : q.getRow(j) * a.getRow(i))
            }
        }

        // Solve R B = Qt W Y to find B. This is easy because R is upper triangular.
        // We just work from bottom-right to top-left calculating B's coefficients.
        var wy = LSQVector(size: m)
        for h in 0..<m {
            wy[h] = y[h] * w[h]
        }
        for i in stride(from: n - 1, through: 0, by: -1) {
            result.coefficients[i] = q.getRow(i) * wy
            for j in stride(from: n - 1, through: i + 1, by: -1) {
                result.coefficients[i] -= r.get(i, j) * result.coefficients[j]
            }
            result.coefficients[i] /= r.get(i, i)
        }

        // Calculate the coefficient of determination (confidence) as:
        //   1 - (sumSquaredError / sumSquaredTotal)
        // ...where sumSquaredError is the residual sum of squares (variance of the
        // error), and sumSquaredTotal is the total sum of squares (variance of the
        // data) where each has been weighted.
        var yMean = 0.0
        for h in 0..<m {
            yMean += y[h]
        }
        yMean /= Double(m)

        var sumSquaredError = 0.0
        var sumSquaredTotal = 0.0
        for h in 0..<m {
            var term = 1.0
            var err = y[h] - result.coefficients[0]
            for i in 1..<n {
                term *= x[h]
                err -= term * result.coefficients[i]
            }
            sumSquaredError += w[h] * w[h] * err * err
            let v = y[h] - yMean
            sumSquaredTotal += w[h] * w[h] * v * v
        }

        result.confidence = sumSquaredTotal <= precisionErrorTolerance
            ? 1.0
            : 1.0 - (sumSquaredError / sumSquaredTotal)

        return result
    }
}
