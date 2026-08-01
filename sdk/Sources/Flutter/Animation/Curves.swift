// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import FlutterSwiftBridge

// MARK: - ParametricCurve

/// An interface for evaluating a parametric curve.
///
/// A parametric curve transforms a parameter (hence the name) `t` along a curve
/// to the value of the curve at that value of `t`. The curve can be of
/// arbitrary dimension, but is typically a 1D, 2D, or 3D curve.
///
/// See also:
///
///  * ``Curve``, a 1D animation easing curve that starts at 0.0 and ends at 1.0.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `ParametricCurve<T>`
/// **Lines:** 26-55
public protocol ParametricCurve: CustomStringConvertible {
    associatedtype Output

    /// Returns the value of the curve at point `t`.
    ///
    /// This method asserts that t is between 0 and 1 before delegating to
    /// ``transformInternal(_:)``.
    ///
    /// It is recommended that conforming types override ``transformInternal(_:)`` instead of
    /// this method, as the above case is already handled in the default
    /// implementation of ``transform(_:)``, which delegates the remaining logic to
    /// ``transformInternal(_:)``.
    ///
    /// **Dart Source:** `curves.dart:40-43`
    func transform(_ t: Double) -> Output

    /// Returns the value of the curve at point `t`.
    ///
    /// The given parametric value `t` will be between 0.0 and 1.0, inclusive.
    ///
    /// **Dart Source:** `curves.dart:48-51`
    func transformInternal(_ t: Double) -> Output
}

extension ParametricCurve {
    /// Default transform with bounds checking.
    ///
    /// **Dart Source:** `curves.dart:40-43`
    public func transform(_ t: Double) -> Output {
        assert(t >= 0.0 && t <= 1.0, "parametric value \(t) is outside of [0, 1] range.")
        return transformInternal(t)
    }

    /// **Dart Source:** `curves.dart:53-54`
    public var description: String {
        objectRuntimeType(self, "ParametricCurve")
    }
}

// MARK: - Curve

/// A parametric animation easing curve, i.e. a mapping of the unit interval to
/// the unit interval.
///
/// Easing curves are used to adjust the rate of change of an animation over
/// time, allowing them to speed up and slow down, rather than moving at a
/// constant rate.
///
/// A ``Curve`` must map t=0.0 to 0.0 and t=1.0 to 1.0.
///
/// See also:
///
///  * ``Curves``, a collection of common animation easing curves.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Curve`
/// **Lines:** 75-112
public protocol Curve: ParametricCurve where Output == Double {
    /// Returns a new curve that is the reversed inversion of this one.
    ///
    /// This is often useful with reversed animations.
    ///
    /// See also:
    ///
    ///  * ``FlippedCurve``, the class that is used to implement this getter.
    ///
    /// **Dart Source:** `curves.dart:111`
    var flipped: any Curve { get }
}

extension Curve {
    /// Returns the value of the curve at point `t`.
    ///
    /// This function ensures the following:
    /// - The value of `t` must be between 0.0 and 1.0
    /// - Values of `t`=0.0 and `t`=1.0 are mapped to 0.0 and 1.0,
    ///   respectively.
    ///
    /// It is recommended that conforming types override ``transformInternal(_:)`` instead of
    /// this method, as the above cases are already handled in the default
    /// implementation of ``transform(_:)``, which delegates the remaining logic to
    /// ``transformInternal(_:)``.
    ///
    /// **Dart Source:** `curves.dart:92-97`
    public func transform(_ t: Double) -> Double {
        if t == 0.0 || t == 1.0 {
            return t
        }
        assert(t >= 0.0 && t <= 1.0, "parametric value \(t) is outside of [0, 1] range.")
        return transformInternal(t)
    }

    /// Returns a new curve that is the reversed inversion of this one.
    ///
    /// **Dart Source:** `curves.dart:111`
    public var flipped: any Curve {
        FlippedCurve(self)
    }
}

// MARK: - LinearCurve

/// The identity map over the unit interval.
///
/// See ``Curves/linear`` for an instance of this type.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `_Linear`
/// **Lines:** 117-122
struct LinearCurve: Curve {
    /// **Dart Source:** `curves.dart:121`
    func transformInternal(_ t: Double) -> Double { t }
}

// MARK: - SawTooth

/// A sawtooth curve that repeats a given number of times over the unit interval.
///
/// The curve rises linearly from 0.0 to 1.0 and then falls discontinuously back
/// to 0.0 each iteration.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `SawTooth`
/// **Lines:** 130-147
public struct SawTooth: Curve {
    /// Creates a sawtooth curve.
    ///
    /// **Dart Source:** `curves.dart:132`
    public init(_ count: Int) {
        self.count = count
    }

    /// The number of repetitions of the sawtooth pattern in the unit interval.
    ///
    /// **Dart Source:** `curves.dart:135`
    public let count: Int

    /// **Dart Source:** `curves.dart:138-141`
    public func transformInternal(_ t: Double) -> Double {
        let t = t * Double(count)
        return t - Double(Int(t))
    }

    /// **Dart Source:** `curves.dart:144-146`
    public var description: String {
        "\(objectRuntimeType(self, "SawTooth"))(\(count))"
    }
}

// MARK: - Interval

/// A curve that is 0.0 until ``begin``, then curved (according to ``curve``) from
/// 0.0 at ``begin`` to 1.0 at ``end``, then remains 1.0 past ``end``.
///
/// An ``Interval`` can be used to delay an animation. For example, a six second
/// animation that uses an ``Interval`` with its ``begin`` set to 0.5 and its ``end``
/// set to 1.0 will essentially become a three-second animation that starts
/// three seconds later.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Interval`
/// **Lines:** 158-196
public struct Interval: Curve {
    /// Creates an interval curve.
    ///
    /// **Dart Source:** `curves.dart:160`
    public init(_ begin: Double, _ end: Double, curve: any Curve) {
        self.begin = begin
        self.end = end
        self.curve = curve
    }

    /// Creates an interval curve with a linear curve (the default).
    ///
    /// **Dart Source:** `curves.dart:160`
    public init(_ begin: Double, _ end: Double) {
        self.begin = begin
        self.end = end
        self.curve = LinearCurve()
    }

    /// The largest value for which this interval is 0.0.
    ///
    /// From t=0.0 to t=``begin``, the interval's value is 0.0.
    ///
    /// **Dart Source:** `curves.dart:165`
    public let begin: Double

    /// The smallest value for which this interval is 1.0.
    ///
    /// From t=``end`` to t=1.0, the interval's value is 1.0.
    ///
    /// **Dart Source:** `curves.dart:170`
    public let end: Double

    /// The curve to apply between ``begin`` and ``end``.
    ///
    /// **Dart Source:** `curves.dart:173`
    public let curve: any Curve

    /// **Dart Source:** `curves.dart:176-187`
    public func transformInternal(_ t: Double) -> Double {
        assert(begin >= 0.0)
        assert(begin <= 1.0)
        assert(end >= 0.0)
        assert(end <= 1.0)
        assert(end >= begin)
        let t = clampDouble((t - begin) / (end - begin), 0.0, 1.0)
        if t == 0.0 || t == 1.0 {
            return t
        }
        return curve.transform(t)
    }

    /// **Dart Source:** `curves.dart:190-195`
    public var description: String {
        if !(curve is LinearCurve) {
            return "\(objectRuntimeType(self, "Interval"))(\(begin)\u{22EF}\(end))\u{27A9}\(curve)"
        }
        return "\(objectRuntimeType(self, "Interval"))(\(begin)\u{22EF}\(end))"
    }
}

// MARK: - Split

/// A curve that progresses according to ``beginCurve`` until ``split``, then
/// according to ``endCurve``.
///
/// Split curves are useful in situations where a widget must track the
/// user's finger (which requires a linear animation), but can also be flung
/// using a curve specified with the ``endCurve`` argument, after the finger is
/// released. In such a case, the value of ``split`` would be the progress
/// of the animation at the time when the finger was released.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Split`
/// **Lines:** 213-265
public struct Split: Curve {
    /// Creates a split curve.
    ///
    /// **Dart Source:** `curves.dart:215`
    public init(
        _ split: Double,
        beginCurve: any Curve,
        endCurve: any Curve
    ) {
        self.split = split
        self.beginCurve = beginCurve
        self.endCurve = endCurve
    }

    /// Creates a split curve with a linear begin curve and easeOutCubic end curve (the defaults).
    ///
    /// **Dart Source:** `curves.dart:215`
    public init(_ split: Double) {
        self.split = split
        self.beginCurve = LinearCurve()
        self.endCurve = Cubic(0.215, 0.61, 0.355, 1.0)  // Curves.easeOutCubic
    }

    /// Creates a split curve with a custom begin curve and easeOutCubic end curve.
    ///
    /// **Dart Source:** `curves.dart:215`
    public init(_ split: Double, beginCurve: any Curve) {
        self.split = split
        self.beginCurve = beginCurve
        self.endCurve = Cubic(0.215, 0.61, 0.355, 1.0)  // Curves.easeOutCubic
    }

    /// Creates a split curve with a linear begin curve (the default).
    ///
    /// **Dart Source:** `curves.dart:215`
    public init(_ split: Double, endCurve: any Curve) {
        self.split = split
        self.beginCurve = LinearCurve()
        self.endCurve = endCurve
    }

    /// The progress value separating ``beginCurve`` from ``endCurve``.
    ///
    /// The value before which the curve progresses according to ``beginCurve`` and
    /// after which the curve progresses according to ``endCurve``.
    ///
    /// When t is exactly ``split``, the curve has the value ``split``.
    ///
    /// Must be between 0 and 1.0, inclusively.
    ///
    /// **Dart Source:** `curves.dart:225`
    public let split: Double

    /// The curve to use before ``split`` is reached.
    ///
    /// Defaults to linear.
    ///
    /// **Dart Source:** `curves.dart:230`
    public let beginCurve: any Curve

    /// The curve to use after ``split`` is reached.
    ///
    /// **Dart Source:** `curves.dart:235`
    public let endCurve: any Curve

    /// Split overrides `transform` directly rather than `transformInternal`,
    /// matching the Dart source where `Split.transform` handles all logic.
    /// This stub satisfies the protocol requirement.
    public func transformInternal(_ t: Double) -> Double {
        fatalError("Split.transform is overridden directly; transformInternal should not be called.")
    }

    /// **Dart Source:** `curves.dart:238-259`
    public func transform(_ t: Double) -> Double {
        assert(t >= 0.0 && t <= 1.0)
        assert(split >= 0.0 && split <= 1.0)

        if t == 0.0 || t == 1.0 {
            return t
        }

        if t == split {
            return split
        }

        if t < split {
            let curveProgress = t / split
            let transformed = beginCurve.transform(curveProgress)
            return lerpDouble(0, split, transformed)!
        } else {
            let curveProgress = (t - split) / (1 - split)
            let transformed = endCurve.transform(curveProgress)
            return lerpDouble(split, 1, transformed)!
        }
    }

    /// **Dart Source:** `curves.dart:262-264`
    public var description: String {
        "\(describeIdentity(self))(\(split), \(beginCurve), \(endCurve))"
    }
}

// MARK: - Threshold

/// A curve that is 0.0 until it hits the threshold, then it jumps to 1.0.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Threshold`
/// **Lines:** 270-285
public struct Threshold: Curve {
    /// Creates a threshold curve.
    ///
    /// **Dart Source:** `curves.dart:272`
    public init(_ threshold: Double) {
        self.threshold = threshold
    }

    /// The value before which the curve is 0.0 and after which the curve is 1.0.
    ///
    /// When t is exactly ``threshold``, the curve has the value 1.0.
    ///
    /// **Dart Source:** `curves.dart:277`
    public let threshold: Double

    /// **Dart Source:** `curves.dart:280-284`
    public func transformInternal(_ t: Double) -> Double {
        assert(threshold >= 0.0)
        assert(threshold <= 1.0)
        return t < threshold ? 0.0 : 1.0
    }
}

// MARK: - Cubic

/// A cubic polynomial mapping of the unit interval.
///
/// The ``Cubic`` class implements third-order Bezier curves.
///
/// See also:
///
///  * ``Curves``, where many more predefined curves are available.
///  * ``CatmullRomCurve``, a curve which passes through specific values.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Cubic`
/// **Lines:** 365-424
public struct Cubic: Curve {
    /// Creates a cubic curve.
    ///
    /// Rather than creating a new instance, consider using one of the common
    /// cubic curves in ``Curves``.
    ///
    /// **Dart Source:** `curves.dart:370`
    public init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    /// The x coordinate of the first control point.
    ///
    /// The line through the point (0, 0) and the first control point is tangent
    /// to the curve at the point (0, 0).
    ///
    /// **Dart Source:** `curves.dart:376`
    public let a: Double

    /// The y coordinate of the first control point.
    ///
    /// The line through the point (0, 0) and the first control point is tangent
    /// to the curve at the point (0, 0).
    ///
    /// **Dart Source:** `curves.dart:382`
    public let b: Double

    /// The x coordinate of the second control point.
    ///
    /// The line through the point (1, 1) and the second control point is tangent
    /// to the curve at the point (1, 1).
    ///
    /// **Dart Source:** `curves.dart:388`
    public let c: Double

    /// The y coordinate of the second control point.
    ///
    /// The line through the point (1, 1) and the second control point is tangent
    /// to the curve at the point (1, 1).
    ///
    /// **Dart Source:** `curves.dart:394`
    public let d: Double

    /// **Dart Source:** `curves.dart:396`
    private static let cubicErrorBound: Double = 0.001

    /// **Dart Source:** `curves.dart:398-400`
    private func evaluateCubic(_ a: Double, _ b: Double, _ m: Double) -> Double {
        return 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
    }

    /// **Dart Source:** `curves.dart:403-418`
    public func transformInternal(_ t: Double) -> Double {
        var start = 0.0
        var end = 1.0
        while true {
            let midpoint = (start + end) / 2
            let estimate = evaluateCubic(a, c, midpoint)
            if Swift.abs(t - estimate) < Cubic.cubicErrorBound {
                return evaluateCubic(b, d, midpoint)
            }
            if estimate < t {
                start = midpoint
            } else {
                end = midpoint
            }
        }
    }

    /// **Dart Source:** `curves.dart:421-423`
    public var description: String {
        "\(objectRuntimeType(self, "Cubic"))(\(String(format: "%.2f", a)), \(String(format: "%.2f", b)), \(String(format: "%.2f", c)), \(String(format: "%.2f", d)))"
    }
}

// MARK: - ThreePointCubic

/// A cubic polynomial composed of two curves that share a common center point.
///
/// The curve runs through three points: (0,0), the ``midpoint``, and (1,1).
///
/// The ``ThreePointCubic`` class implements third-order Bezier curves, where two
/// curves share an interior ``midpoint`` that the curve passes through. If the
/// control points surrounding the middle point (``b1``, and ``a2``) are not
/// collinear with the middle point, then the curve's derivative will have a
/// discontinuity (a cusp) at the shared middle point.
///
/// See also:
///
///  * ``Curves``, where many more predefined curves are available.
///  * ``Cubic``, which defines a single cubic polynomial.
///  * ``CatmullRomCurve``, a curve which passes through specific values.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `ThreePointCubic`
/// **Lines:** 444-516
public struct ThreePointCubic: Curve {
    /// Creates two cubic curves that share a common control point.
    ///
    /// The arguments correspond to the control points for the two curves,
    /// including the ``midpoint``, but do not include the two implied end points at
    /// (0,0) and (1,1), which are fixed.
    ///
    /// **Dart Source:** `curves.dart:453`
    public init(_ a1: Offset, _ b1: Offset, _ midpoint: Offset, _ a2: Offset, _ b2: Offset) {
        self.a1 = a1
        self.b1 = b1
        self.midpoint = midpoint
        self.a2 = a2
        self.b2 = b2
    }

    /// The coordinates of the first control point of the first curve.
    ///
    /// The line through the point (0, 0) and this control point is tangent to the
    /// curve at the point (0, 0).
    ///
    /// **Dart Source:** `curves.dart:459`
    public let a1: Offset

    /// The coordinates of the second control point of the first curve.
    ///
    /// The line through the ``midpoint`` and this control point is tangent to the
    /// curve approaching the ``midpoint``.
    ///
    /// **Dart Source:** `curves.dart:465`
    public let b1: Offset

    /// The coordinates of the middle shared point.
    ///
    /// The curve will go through this point. If the control points surrounding
    /// this middle point (``b1``, and ``a2``) are not collinear with this point, then
    /// the curve's derivative will have a discontinuity (a cusp) at this point.
    ///
    /// **Dart Source:** `curves.dart:472`
    public let midpoint: Offset

    /// The coordinates of the first control point of the second curve.
    ///
    /// The line through the ``midpoint`` and this control point is tangent to the
    /// curve approaching the ``midpoint``.
    ///
    /// **Dart Source:** `curves.dart:478`
    public let a2: Offset

    /// The coordinates of the second control point of the second curve.
    ///
    /// The line through the point (1, 1) and this control point is tangent to the
    /// curve at (1, 1).
    ///
    /// **Dart Source:** `curves.dart:484`
    public let b2: Offset

    /// **Dart Source:** `curves.dart:487-510`
    public func transformInternal(_ t: Double) -> Double {
        let firstCurve = t < midpoint.dx
        let scaleX = firstCurve ? midpoint.dx : 1.0 - midpoint.dx
        let scaleY = firstCurve ? midpoint.dy : 1.0 - midpoint.dy
        let scaledT = (t - (firstCurve ? 0.0 : midpoint.dx)) / scaleX
        if firstCurve {
            return Cubic(
                a1.dx / scaleX,
                a1.dy / scaleY,
                b1.dx / scaleX,
                b1.dy / scaleY
            ).transform(scaledT) * scaleY
        } else {
            return Cubic(
                (a2.dx - midpoint.dx) / scaleX,
                (a2.dy - midpoint.dy) / scaleY,
                (b2.dx - midpoint.dx) / scaleX,
                (b2.dy - midpoint.dy) / scaleY
            ).transform(scaledT) * scaleY + midpoint.dy
        }
    }

    /// **Dart Source:** `curves.dart:513-515`
    public var description: String {
        "\(objectRuntimeType(self, "ThreePointCubic(\(a1), \(b1), \(midpoint), \(a2), \(b2))")) "
    }
}

// MARK: - Curve2DSample

/// A class that holds a sample of a 2D parametric curve, containing the ``value``
/// (the X, Y coordinates) of the curve at the parametric value ``t``.
///
/// See also:
///
///  * ``Curve2D/generateSamples(start:end:tolerance:)``, which generates samples of this type.
///  * ``Curve2D``, a parametric curve that maps a double parameter to a 2D location.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Curve2DSample`
/// **Lines:** 667-681
public struct Curve2DSample {
    /// Creates an object that holds a sample; used with ``Curve2D`` subclasses.
    ///
    /// **Dart Source:** `curves.dart:669`
    public init(_ t: Double, _ value: Offset) {
        self.t = t
        self.value = value
    }

    /// The parametric location of this sample point along the curve.
    ///
    /// **Dart Source:** `curves.dart:672`
    public let t: Double

    /// The value (the X, Y coordinates) of the curve at parametric value ``t``.
    ///
    /// **Dart Source:** `curves.dart:675`
    public let value: Offset
}

extension Curve2DSample: CustomStringConvertible {
    /// **Dart Source:** `curves.dart:678-680`
    public var description: String {
        "[(\(String(format: "%.2f", value.dx)), \(String(format: "%.2f", value.dy))), \(String(format: "%.2f", t))]"
    }
}

// MARK: - SeededRandom

/// A simple seeded pseudo-random number generator using a linear congruential
/// generator, replicating Dart's `math.Random(seed)` for deterministic sampling.
struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Match Dart's Random seed initialization behavior
        state = UInt64(bitPattern: Int64(seed))
        // Warm up the generator
        for _ in 0..<4 {
            _ = nextDouble()
        }
    }

    /// Returns a random Double in [0, 1).
    mutating func nextDouble() -> Double {
        // Linear congruential generator parameters (same family as many standard implementations)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let shifted = state >> 11
        return Double(shifted) / Double(UInt64(1) << 53)
    }
}

// MARK: - Curve2D

/// Abstract protocol that defines an API for evaluating 2D parametric curves.
///
/// ``Curve2D`` differs from ``Curve`` in that the values interpolated are ``Offset``
/// values instead of ``Double`` values, hence the "2D" in the name. They both
/// take a single `Double` `t` that has a range of 0.0 to 1.0, inclusive, as input
/// to the ``transform(_:)`` function. Unlike ``Curve``, ``Curve2D`` is not required to
/// map `t=0.0` and `t=1.0` to specific output values.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Curve2D`
/// **Lines:** 539-658
public protocol Curve2D: ParametricCurve where Output == Offset {
    /// Returns a seed value used by ``generateSamples(start:end:tolerance:)`` to seed a random number
    /// generator to avoid sample aliasing.
    ///
    /// **Dart Source:** `curves.dart:627`
    var samplingSeed: Int { get }

    /// Generates a list of samples with a recursive subdivision until a tolerance
    /// of `tolerance` is reached.
    ///
    /// **Dart Source:** `curves.dart:563-617`
    func generateSamples(start: Double, end: Double, tolerance: Double) -> [Curve2DSample]

    /// Returns the parameter `t` that corresponds to the given x value of the spline.
    ///
    /// **Dart Source:** `curves.dart:636-657`
    func findInverse(_ x: Double) -> Double
}

extension Curve2D {
    /// Default sampling seed.
    ///
    /// **Dart Source:** `curves.dart:627`
    public var samplingSeed: Int { 0 }

    /// Generates a list of samples with a recursive subdivision until a tolerance
    /// of `tolerance` is reached.
    ///
    /// Samples are generated in order.
    ///
    /// **Dart Source:** `curves.dart:563-617`
    public func generateSamples(
        start: Double = 0.0,
        end: Double = 1.0,
        tolerance: Double = 1e-10
    ) -> [Curve2DSample] {
        assert(end > start)
        var rand = SeededRandom(seed: samplingSeed)

        func isFlat(_ p: Offset, _ q: Offset, _ r: Offset) -> Bool {
            let pr = p - r
            let qr = q - r
            let z = pr.dx * qr.dy - qr.dx * pr.dy
            return (z * z) < tolerance
        }

        let first = Curve2DSample(start, transform(start))
        let last = Curve2DSample(end, transform(end))
        var samples = [first]

        func sample(_ p: Curve2DSample, _ q: Curve2DSample, forceSubdivide: Bool = false) {
            let t = p.t + (0.45 + 0.1 * rand.nextDouble()) * (q.t - p.t)
            let r = Curve2DSample(t, transform(t))

            if !forceSubdivide && isFlat(p.value, q.value, r.value) {
                samples.append(q)
            } else {
                sample(p, r)
                sample(r, q)
            }
        }

        let forceSubdivide: Bool =
            Swift.abs(first.value.dx - last.value.dx) < tolerance &&
            Swift.abs(first.value.dy - last.value.dy) < tolerance
        sample(first, last, forceSubdivide: forceSubdivide)
        return samples
    }

    /// Returns the parameter `t` that corresponds to the given x value of the spline.
    ///
    /// This will only work properly for curves which are single-valued in x.
    ///
    /// **Dart Source:** `curves.dart:636-657`
    public func findInverse(_ x: Double) -> Double {
        var start = 0.0
        var end = 1.0
        var mid = 0.0
        func offsetToOrigin(_ pos: Double) -> Double { x - transform(pos).dx }
        let errorLimit = 1e-6
        var count = 100
        let startValue = offsetToOrigin(start)
        while (end - start) / 2.0 > errorLimit && count > 0 {
            mid = (end + start) / 2.0
            let value = offsetToOrigin(mid)
            if value.sign == startValue.sign {
                start = mid
            } else {
                end = mid
            }
            count -= 1
        }
        return mid
    }
}

// MARK: - CatmullRomSpline

/// A 2D spline that passes smoothly through the given control points using a
/// centripetal Catmull-Rom spline.
///
/// When the curve is evaluated with ``transform(_:)``, the output values will move
/// smoothly from one control point to the next, passing through the control
/// points.
///
/// Unlike most cubic splines, Catmull-Rom splines have the advantage that their
/// curves pass through the control points given to them. They are cubic
/// polynomial representations, and, in fact, Catmull-Rom splines can be
/// converted mathematically into cubic splines. This class implements a
/// "centripetal" Catmull-Rom spline. The term centripetal implies that it won't
/// form loops or self-intersections within a single segment.
///
/// See also:
///
///  * [Centripetal Catmull-Rom splines](https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline)
///    on Wikipedia.
///  * ``CatmullRomCurve``, an animation curve that uses a ``CatmullRomSpline`` as its
///    internal representation.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `CatmullRomSpline`
/// **Lines:** 706-905
public class CatmullRomSpline: Curve2D {
    /// Constructs a centripetal Catmull-Rom spline curve.
    ///
    /// The `controlPoints` argument is a list of four or more points that
    /// describe the points that the curve must pass through.
    ///
    /// The optional `tension` argument controls how tightly the curve approaches
    /// the given `controlPoints`. It must be in the range 0.0 to 1.0, inclusive.
    /// It defaults to 0.0, which provides the smoothest curve.
    ///
    /// The internal curve data structures are lazily computed the first time
    /// ``transform(_:)`` is called. If you would rather pre-compute the structures,
    /// use ``precompute(controlPoints:tension:startHandle:endHandle:)`` instead.
    ///
    /// **Dart Source:** `curves.dart:733-748`
    public init(
        controlPoints: [Offset],
        tension: Double = 0.0,
        startHandle: Offset? = nil,
        endHandle: Offset? = nil
    ) {
        assert(tension <= 1.0, "tension \(tension) must not be greater than 1.0.")
        assert(tension >= 0.0, "tension \(tension) must not be negative.")
        assert(
            controlPoints.count > 3,
            "There must be at least four control points to create a CatmullRomSpline."
        )
        self._controlPoints = controlPoints
        self._startHandle = startHandle
        self._endHandle = endHandle
        self._tension = tension
        self._cubicSegments = []
    }

    /// Constructs a centripetal Catmull-Rom spline curve with precomputed segments.
    ///
    /// The same as ``init(controlPoints:tension:startHandle:endHandle:)``, except that the internal
    /// data structures are precomputed instead of being computed lazily.
    ///
    /// **Dart Source:** `curves.dart:754-774`
    private init(precomputedSegments: [[Offset]]) {
        self._controlPoints = nil
        self._startHandle = nil
        self._endHandle = nil
        self._tension = nil
        self._cubicSegments = precomputedSegments
    }

    /// Creates a precomputed CatmullRomSpline.
    ///
    /// **Dart Source:** `curves.dart:754-774`
    public static func precompute(
        controlPoints: [Offset],
        tension: Double = 0.0,
        startHandle: Offset? = nil,
        endHandle: Offset? = nil
    ) -> CatmullRomSpline {
        assert(tension <= 1.0, "tension \(tension) must not be greater than 1.0.")
        assert(tension >= 0.0, "tension \(tension) must not be negative.")
        assert(
            controlPoints.count > 3,
            "There must be at least four control points to create a CatmullRomSpline."
        )
        let segments = computeSegments(
            controlPoints,
            tension,
            startHandle: startHandle,
            endHandle: endHandle
        )
        return CatmullRomSpline(precomputedSegments: segments)
    }

    /// **Dart Source:** `curves.dart:776-848`
    static func computeSegments(
        _ controlPoints: [Offset],
        _ tension: Double,
        startHandle: Offset? = nil,
        endHandle: Offset? = nil
    ) -> [[Offset]] {
        assert(
            startHandle == nil || startHandle!.isFinite,
            "The provided startHandle of CatmullRomSpline must be finite. The startHandle given was \(String(describing: startHandle))."
        )
        assert(
            endHandle == nil || endHandle!.isFinite,
            "The provided endHandle of CatmullRomSpline must be finite. The endHandle given was \(String(describing: endHandle))."
        )
        assert({
            for index in 0..<controlPoints.count {
                if !controlPoints[index].isFinite {
                    assertionFailure(
                        "The provided CatmullRomSpline control point at index \(index) is not finite. The control point given was \(controlPoints[index])."
                    )
                    return false
                }
            }
            return true
        }())

        let startHandle = startHandle ?? controlPoints[0] * 2.0 - controlPoints[1]
        let endHandle = endHandle ?? controlPoints[controlPoints.count - 1] * 2.0 - controlPoints[controlPoints.count - 2]
        let allPoints = [startHandle] + controlPoints + [endHandle]

        let alpha = 0.5
        let reverseTension = 1.0 - tension
        var result: [[Offset]] = []
        for i in 0..<(allPoints.count - 3) {
            let curve = [allPoints[i], allPoints[i + 1], allPoints[i + 2], allPoints[i + 3]]
            let diffCurve10 = curve[1] - curve[0]
            let diffCurve21 = curve[2] - curve[1]
            let diffCurve32 = curve[3] - curve[2]
            let t01 = pow(diffCurve10.distance, alpha)
            let t12 = pow(diffCurve21.distance, alpha)
            let t23 = pow(diffCurve32.distance, alpha)

            let m1 = (diffCurve21 + (diffCurve10 / t01 - (curve[2] - curve[0]) / (t01 + t12)) * t12) * reverseTension
            let m2 = (diffCurve21 + (diffCurve32 / t23 - (curve[3] - curve[1]) / (t12 + t23)) * t12) * reverseTension
            let sumM12 = m1 + m2

            let segment: [Offset] = [
                diffCurve21 * -2.0 + sumM12,
                diffCurve21 * 3.0 - m1 - sumM12,
                m1,
                curve[1],
            ]
            result.append(segment)
        }
        return result
    }

    /// The list of control point lists for each cubic segment of the spline.
    ///
    /// **Dart Source:** `curves.dart:852`
    private var _cubicSegments: [[Offset]]

    /// These are non-nil only if the _cubicSegments are being computed lazily.
    ///
    /// **Dart Source:** `curves.dart:855-858`
    private let _controlPoints: [Offset]?
    private let _startHandle: Offset?
    private let _endHandle: Offset?
    private let _tension: Double?

    /// **Dart Source:** `curves.dart:860-872`
    private func _initializeIfNeeded() {
        if !_cubicSegments.isEmpty {
            return
        }
        // Safe to mutate because CatmullRomSpline is a class (reference type)
        let segments = CatmullRomSpline.computeSegments(
            _controlPoints!,
            _tension!,
            startHandle: _startHandle,
            endHandle: _endHandle
        )
        _cubicSegments.append(contentsOf: segments)
    }

    /// **Dart Source:** `curves.dart:876-880`
    public var samplingSeed: Int {
        _initializeIfNeeded()
        let seedPoint = _cubicSegments[0][1]
        return Int(((seedPoint.dx + seedPoint.dy) * 10000).rounded())
    }

    /// **Dart Source:** `curves.dart:883-904`
    public func transformInternal(_ t: Double) -> Offset {
        _initializeIfNeeded()
        let length = Double(_cubicSegments.count)
        let position: Double
        let localT: Double
        let index: Int
        if t < 1.0 {
            position = t * length
            localT = position.truncatingRemainder(dividingBy: 1.0)
            index = Int(position)
        } else {
            position = length
            localT = 1.0
            index = _cubicSegments.count - 1
        }
        let cubicControlPoints = _cubicSegments[index]
        let localT2 = localT * localT
        return cubicControlPoints[0] * localT2 * localT
            + cubicControlPoints[1] * localT2
            + cubicControlPoints[2] * localT
            + cubicControlPoints[3]
    }

    /// **Dart Source:** `curves.dart:53-54` (inherited from ParametricCurve)
    public var description: String {
        objectRuntimeType(self, "CatmullRomSpline")
    }
}

// MARK: - CatmullRomCurve

/// An animation easing curve that passes smoothly through the given control
/// points using a centripetal Catmull-Rom spline.
///
/// When this curve is evaluated with ``transform(_:)``, the values will interpolate
/// smoothly from one control point to the next, passing through (0.0, 0.0), the
/// given points, and then (1.0, 1.0).
///
/// This class uses a centripetal Catmull-Rom curve (a ``CatmullRomSpline``) as
/// its internal representation. The term centripetal implies that it won't form
/// loops or self-intersections within a single segment, and corresponds to a
/// Catmull-Rom alpha value of 0.5.
///
/// See also:
///
///  * ``CatmullRomSpline``, the 2D spline that this curve uses to generate its values.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `CatmullRomCurve`
/// **Lines:** 928-1215
public class CatmullRomCurve: Curve {
    /// Constructs a centripetal ``CatmullRomCurve``.
    ///
    /// It takes a list of two or more points that describe the points that the
    /// curve must pass through. The curve will begin with an implicit control point
    /// at (0.0, 0.0) and end with an implicit control point at (1.0, 1.0).
    ///
    /// The internal curve data structures are lazily computed the first time
    /// ``transform(_:)`` is called. If you would rather pre-compute the curve, use
    /// ``precompute(controlPoints:tension:)`` instead.
    ///
    /// **Dart Source:** `curves.dart:950-963`
    public init(controlPoints: [Offset], tension: Double = 0.0) {
        self.controlPoints = controlPoints
        self.tension = tension
        self._precomputedSamples = []
        assert({
            let reasons = CatmullRomCurve.validateControlPoints(
                controlPoints,
                tension: tension
            )
            if let reasons = reasons {
                assertionFailure("control points \(controlPoints) could not be validated:\n  \(reasons.joined(separator: "\n  "))")
                return false
            }
            return true
        }())
    }

    /// Private init for the precompute factory.
    private init(controlPoints: [Offset], tension: Double, precomputedSamples: [Curve2DSample]) {
        self.controlPoints = controlPoints
        self.tension = tension
        self._precomputedSamples = precomputedSamples
    }

    /// Creates a precomputed ``CatmullRomCurve``.
    ///
    /// Same as ``init(controlPoints:tension:)``, but precomputes the internal data
    /// structures for a more predictable computation load.
    ///
    /// **Dart Source:** `curves.dart:969-982`
    public static func precompute(controlPoints: [Offset], tension: Double = 0.0) -> CatmullRomCurve {
        assert({
            let reasons = CatmullRomCurve.validateControlPoints(
                controlPoints,
                tension: tension
            )
            if let reasons = reasons {
                assertionFailure("control points \(controlPoints) could not be validated:\n  \(reasons.joined(separator: "\n  "))")
                return false
            }
            return true
        }())
        let samples = computeSamples(controlPoints, tension)
        return CatmullRomCurve(controlPoints: controlPoints, tension: tension, precomputedSamples: samples)
    }

    /// **Dart Source:** `curves.dart:984-991`
    private static func computeSamples(_ controlPoints: [Offset], _ tension: Double) -> [Curve2DSample] {
        return CatmullRomSpline.precompute(
            controlPoints: [Offset.zero] + controlPoints + [Offset(1.0, 1.0)],
            tension: tension
        ).generateSamples(tolerance: 1e-12)
    }

    /// The precomputed approximation curve samples.
    ///
    /// **Dart Source:** `curves.dart:1001`
    private var _precomputedSamples: [Curve2DSample]

    /// The control points used to create this curve.
    ///
    /// The `dx` value of each ``Offset`` in ``controlPoints`` represents the
    /// animation value at which the curve should pass through the `dy` value of
    /// the same control point.
    ///
    /// **Dart Source:** `curves.dart:1029`
    public let controlPoints: [Offset]

    /// The "tension" of the curve.
    ///
    /// The tension attribute controls how tightly the curve approaches the
    /// given ``controlPoints``. It must be in the range 0.0 to 1.0, inclusive.
    /// It defaults to 0.0, which provides the smoothest curve.
    ///
    /// **Dart Source:** `curves.dart:1038`
    public let tension: Double

    /// Validates that a given set of control points for a ``CatmullRomCurve`` is
    /// well-formed and will not produce a spline that self-intersects.
    ///
    /// Returns `nil` if the control points are valid, or a list of reason strings
    /// if validation fails.
    ///
    /// **Dart Source:** `curves.dart:1053-1181`
    public static func validateControlPoints(
        _ controlPoints: [Offset]?,
        tension: Double = 0.0
    ) -> [String]? {
        guard let controlPoints = controlPoints else {
            return ["Supplied control points cannot be null"]
        }

        if controlPoints.count < 2 {
            return ["There must be at least two points supplied to create a valid curve."]
        }

        let allPoints = [Offset.zero] + controlPoints + [Offset(1.0, 1.0)]
        let startHandle = allPoints[0] * 2.0 - allPoints[1]
        let endHandle = allPoints[allPoints.count - 1] * 2.0 - allPoints[allPoints.count - 2]
        let withHandles = [startHandle] + allPoints + [endHandle]

        var reasons: [String] = []
        var lastX = -Double.infinity
        for i in 0..<withHandles.count {
            if i > 1 && i < withHandles.count - 2 &&
                (withHandles[i].dx <= 0.0 || withHandles[i].dx >= 1.0) {
                reasons.append(
                    "Control points must have X values between 0.0 and 1.0, exclusive. "
                    + "Point \(i) has an x value (\(withHandles[i].dx)) which is outside the range."
                )
                return reasons
            }
            if withHandles[i].dx <= lastX {
                reasons.append(
                    "Each X coordinate must be greater than the preceding X coordinate "
                    + "(i.e. must be monotonically increasing in X). Point \(i) has an x value of "
                    + "\(withHandles[i].dx), which is not greater than \(lastX)"
                )
                return reasons
            }
            lastX = withHandles[i].dx
        }

        // Empirical test to make sure things are single-valued in X.
        lastX = -Double.infinity
        let tolerance = 1e-3
        let testSpline = CatmullRomSpline(controlPoints: withHandles, tension: tension)
        let start = testSpline.findInverse(0.0)
        let end = testSpline.findInverse(1.0)
        let samplePoints = testSpline.generateSamples(start: start, end: end)

        if Swift.abs(samplePoints.first!.value.dy) > tolerance ||
            Swift.abs(1.0 - samplePoints.last!.value.dy) > tolerance {
            reasons.append(
                "The curve has more than one Y value at X = \(samplePoints.first!.value.dx). "
                + "Try moving some control points further away from this value of X, or increasing "
                + "the tension."
            )
        }

        for sample in samplePoints {
            let point = sample.value
            let t = sample.t
            let x = point.dx
            if t >= start && t <= end && (x < -1e-3 || x > 1.0 + 1e-3) {
                reasons.append(
                    "The resulting curve has an X value (\(x)) which is outside "
                    + "the range [0.0, 1.0], inclusive."
                )
            }
            if x < lastX {
                reasons.append(
                    "The curve has more than one Y value at x = \(x). Try moving "
                    + "some control points further apart in X, or increasing the tension."
                )
            }
            lastX = x
        }

        return reasons.isEmpty ? nil : reasons
    }

    /// **Dart Source:** `curves.dart:1184-1214`
    public func transformInternal(_ t: Double) -> Double {
        if _precomputedSamples.isEmpty {
            _precomputedSamples.append(contentsOf: CatmullRomCurve.computeSamples(controlPoints, tension))
        }
        var start = 0
        var end = _precomputedSamples.count - 1
        var mid: Int
        var startValue = _precomputedSamples[start].value
        var endValue = _precomputedSamples[end].value
        // Binary search to find the sample point just before t.
        while end - start > 1 {
            mid = (end + start) / 2
            let value = _precomputedSamples[mid].value
            if t >= value.dx {
                start = mid
                startValue = value
            } else {
                end = mid
                endValue = value
            }
        }

        // Interpolate between the found sample and the next one.
        let t2 = (t - startValue.dx) / (endValue.dx - startValue.dx)
        return lerpDouble(startValue.dy, endValue.dy, t2)!
    }
}

// MARK: - FlippedCurve

/// A curve that is the reversed inversion of its given curve.
///
/// This curve evaluates the given curve in reverse (i.e., from 1.0 to 0.0 as
/// t increases from 0.0 to 1.0) and returns the inverse of the given curve's value
/// (i.e., 1.0 minus the given curve's value).
///
/// See also:
///
///  * ``Curve/flipped``, which provides the ``FlippedCurve`` of a ``Curve``.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `FlippedCurve`
/// **Lines:** 1235-1249
public struct FlippedCurve: Curve {
    /// Creates a flipped curve.
    ///
    /// **Dart Source:** `curves.dart:1237`
    public init(_ curve: any Curve) {
        self.curve = curve
    }

    /// The curve that is being flipped.
    ///
    /// **Dart Source:** `curves.dart:1240`
    public let curve: any Curve

    /// **Dart Source:** `curves.dart:1243`
    public func transformInternal(_ t: Double) -> Double {
        1.0 - curve.transform(1.0 - t)
    }

    /// **Dart Source:** `curves.dart:1246-1248`
    public var description: String {
        "\(objectRuntimeType(self, "FlippedCurve"))(\(curve))"
    }
}

// MARK: - DecelerateCurve

/// A curve where the rate of change starts out quickly and then decelerates; an
/// upside-down `f(t) = t^2` parabola.
///
/// This is equivalent to the Android `DecelerateInterpolator` class with a unit
/// factor (the default factor).
///
/// See ``Curves/decelerate`` for an instance of this type.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `_DecelerateCurve`
/// **Lines:** 1258-1269
struct DecelerateCurve: Curve {
    /// **Dart Source:** `curves.dart:1262-1268`
    func transformInternal(_ t: Double) -> Double {
        let t = 1.0 - t
        return 1.0 - t * t
    }
}

// MARK: - Bounce Curves

/// Bounce helper function used by the bounce curve types.
///
/// **Dart Source:** `curves.dart:1273-1285`
func bounce(_ t: Double) -> Double {
    if t < 1.0 / 2.75 {
        return 7.5625 * t * t
    } else if t < 2 / 2.75 {
        let t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    } else if t < 2.5 / 2.75 {
        let t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    }
    let t = t - 2.625 / 2.75
    return 7.5625 * t * t + 0.984375
}

/// An oscillating curve that grows in magnitude.
///
/// See ``Curves/bounceIn`` for an instance of this type.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `_BounceInCurve`
/// **Lines:** 1290-1297
struct BounceInCurve: Curve {
    /// **Dart Source:** `curves.dart:1294-1296`
    func transformInternal(_ t: Double) -> Double {
        1.0 - bounce(1.0 - t)
    }
}

/// An oscillating curve that shrinks in magnitude.
///
/// See ``Curves/bounceOut`` for an instance of this type.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `_BounceOutCurve`
/// **Lines:** 1302-1309
struct BounceOutCurve: Curve {
    /// **Dart Source:** `curves.dart:1306-1308`
    func transformInternal(_ t: Double) -> Double {
        bounce(t)
    }
}

/// An oscillating curve that first grows and then shrinks in magnitude.
///
/// See ``Curves/bounceInOut`` for an instance of this type.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `_BounceInOutCurve`
/// **Lines:** 1314-1325
struct BounceInOutCurve: Curve {
    /// **Dart Source:** `curves.dart:1318-1324`
    func transformInternal(_ t: Double) -> Double {
        if t < 0.5 {
            return (1.0 - bounce(1.0 - t * 2.0)) * 0.5
        } else {
            return bounce(t * 2.0 - 1.0) * 0.5 + 0.5
        }
    }
}

// MARK: - Elastic Curves

/// An oscillating curve that grows in magnitude while overshooting its bounds.
///
/// An instance of this class using the default period of 0.4 is available as
/// ``Curves/elasticIn``.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `ElasticInCurve`
/// **Lines:** 1335-1355
public struct ElasticInCurve: Curve {
    /// Creates an elastic-in curve.
    ///
    /// Rather than creating a new instance, consider using ``Curves/elasticIn``.
    ///
    /// **Dart Source:** `curves.dart:1339`
    public init(_ period: Double = 0.4) {
        self.period = period
    }

    /// The duration of the oscillation.
    ///
    /// **Dart Source:** `curves.dart:1342`
    public let period: Double

    /// **Dart Source:** `curves.dart:1345-1349`
    public func transformInternal(_ t: Double) -> Double {
        let s = period / 4.0
        let t = t - 1.0
        return -pow(2.0, 10.0 * t) * sin((t - s) * (Double.pi * 2.0) / period)
    }

    /// **Dart Source:** `curves.dart:1352-1354`
    public var description: String {
        "\(objectRuntimeType(self, "ElasticInCurve"))(\(period))"
    }
}

/// An oscillating curve that shrinks in magnitude while overshooting its bounds.
///
/// An instance of this class using the default period of 0.4 is available as
/// ``Curves/elasticOut``.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `ElasticOutCurve`
/// **Lines:** 1363-1382
public struct ElasticOutCurve: Curve {
    /// Creates an elastic-out curve.
    ///
    /// Rather than creating a new instance, consider using ``Curves/elasticOut``.
    ///
    /// **Dart Source:** `curves.dart:1367`
    public init(_ period: Double = 0.4) {
        self.period = period
    }

    /// The duration of the oscillation.
    ///
    /// **Dart Source:** `curves.dart:1370`
    public let period: Double

    /// **Dart Source:** `curves.dart:1373-1376`
    public func transformInternal(_ t: Double) -> Double {
        let s = period / 4.0
        return pow(2.0, -10.0 * t) * sin((t - s) * (Double.pi * 2.0) / period) + 1.0
    }

    /// **Dart Source:** `curves.dart:1379-1381`
    public var description: String {
        "\(objectRuntimeType(self, "ElasticOutCurve"))(\(period))"
    }
}

/// An oscillating curve that grows and then shrinks in magnitude while
/// overshooting its bounds.
///
/// An instance of this class using the default period of 0.4 is available as
/// ``Curves/elasticInOut``.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `ElasticInOutCurve`
/// **Lines:** 1391-1415
public struct ElasticInOutCurve: Curve {
    /// Creates an elastic-in-out curve.
    ///
    /// Rather than creating a new instance, consider using ``Curves/elasticInOut``.
    ///
    /// **Dart Source:** `curves.dart:1395`
    public init(_ period: Double = 0.4) {
        self.period = period
    }

    /// The duration of the oscillation.
    ///
    /// **Dart Source:** `curves.dart:1398`
    public let period: Double

    /// **Dart Source:** `curves.dart:1401-1409`
    public func transformInternal(_ t: Double) -> Double {
        let s = period / 4.0
        let t = 2.0 * t - 1.0
        if t < 0.0 {
            return -0.5 * pow(2.0, 10.0 * t) * sin((t - s) * (Double.pi * 2.0) / period)
        } else {
            return pow(2.0, -10.0 * t) * sin((t - s) * (Double.pi * 2.0) / period) * 0.5 + 1.0
        }
    }

    /// **Dart Source:** `curves.dart:1412-1414`
    public var description: String {
        "\(objectRuntimeType(self, "ElasticInOutCurve"))(\(period))"
    }
}

// MARK: - Curves Constants

/// A collection of common animation curves.
///
/// See also:
///
///  * ``Curve``, the interface implemented by the constants available from the
///    ``Curves`` enum.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/curves.dart`
/// **Original Name:** `Curves`
/// **Lines:** 1465-1900
public enum Curves {
    /// A linear animation curve.
    ///
    /// This is the identity map over the unit interval: its ``Curve/transform(_:)``
    /// method returns its input unmodified.
    ///
    /// **Dart Source:** `curves.dart:1473`
    nonisolated(unsafe) public static let linear: any Curve = LinearCurve()

    /// A curve where the rate of change starts out quickly and then decelerates; an
    /// upside-down `f(t) = t^2` parabola.
    ///
    /// **Dart Source:** `curves.dart:1482`
    nonisolated(unsafe) public static let decelerate: any Curve = DecelerateCurve()

    /// A curve that is very steep and linear at the beginning, but quickly flattens out
    /// and very slowly eases in.
    ///
    /// **Dart Source:** `curves.dart:1491`
    nonisolated(unsafe) public static let fastLinearToSlowEaseIn: any Curve = Cubic(0.18, 1.0, 0.04, 1.0)

    /// A curve that starts slowly, speeds up very quickly, and then ends slowly.
    ///
    /// **Dart Source:** `curves.dart:1505-1511`
    nonisolated(unsafe) public static let fastEaseInToSlowEaseOut: any Curve = ThreePointCubic(
        Offset(0.056, 0.024),
        Offset(0.108, 0.3085),
        Offset(0.198, 0.541),
        Offset(0.3655, 1.0),
        Offset(0.5465, 0.989)
    )

    /// A cubic animation curve that speeds up quickly and ends slowly.
    ///
    /// **Dart Source:** `curves.dart:1518`
    nonisolated(unsafe) public static let ease: any Curve = Cubic(0.25, 0.1, 0.25, 1.0)

    /// A cubic animation curve that starts slowly and ends quickly.
    ///
    /// **Dart Source:** `curves.dart:1525`
    nonisolated(unsafe) public static let easeIn: any Curve = Cubic(0.42, 0.0, 1.0, 1.0)

    /// A cubic animation curve that starts slowly and ends linearly.
    ///
    /// **Dart Source:** `curves.dart:1532`
    nonisolated(unsafe) public static let easeInToLinear: any Curve = Cubic(0.67, 0.03, 0.65, 0.09)

    /// A cubic animation curve that starts slowly and ends quickly, with sinusoidal easing.
    ///
    /// **Dart Source:** `curves.dart:1542`
    nonisolated(unsafe) public static let easeInSine: any Curve = Cubic(0.47, 0.0, 0.745, 0.715)

    /// A cubic animation curve that starts slowly and ends quickly, based on a quadratic equation.
    ///
    /// **Dart Source:** `curves.dart:1553`
    nonisolated(unsafe) public static let easeInQuad: any Curve = Cubic(0.55, 0.085, 0.68, 0.53)

    /// A cubic animation curve that starts slowly and ends quickly, based on a cubic equation.
    ///
    /// **Dart Source:** `curves.dart:1564`
    nonisolated(unsafe) public static let easeInCubic: any Curve = Cubic(0.55, 0.055, 0.675, 0.19)

    /// A cubic animation curve that starts slowly and ends quickly, based on a quartic equation.
    ///
    /// **Dart Source:** `curves.dart:1577`
    nonisolated(unsafe) public static let easeInQuart: any Curve = Cubic(0.895, 0.03, 0.685, 0.22)

    /// A cubic animation curve that starts slowly and ends quickly, based on a quintic equation.
    ///
    /// **Dart Source:** `curves.dart:1587`
    nonisolated(unsafe) public static let easeInQuint: any Curve = Cubic(0.755, 0.05, 0.855, 0.06)

    /// A cubic animation curve that starts slowly and ends quickly, based on an exponential equation.
    ///
    /// **Dart Source:** `curves.dart:1600`
    nonisolated(unsafe) public static let easeInExpo: any Curve = Cubic(0.95, 0.05, 0.795, 0.035)

    /// A cubic animation curve that starts slowly and ends quickly, effectively a quarter circle.
    ///
    /// **Dart Source:** `curves.dart:1611`
    nonisolated(unsafe) public static let easeInCirc: any Curve = Cubic(0.6, 0.04, 0.98, 0.335)

    /// A cubic animation curve that starts slowly and ends quickly, overshooting once.
    ///
    /// **Dart Source:** `curves.dart:1621`
    nonisolated(unsafe) public static let easeInBack: any Curve = Cubic(0.6, -0.28, 0.735, 0.045)

    /// A cubic animation curve that starts quickly and ends slowly.
    ///
    /// **Dart Source:** `curves.dart:1628`
    nonisolated(unsafe) public static let easeOut: any Curve = Cubic(0.0, 0.0, 0.58, 1.0)

    /// A cubic animation curve that starts linearly and ends slowly.
    ///
    /// **Dart Source:** `curves.dart:1635`
    nonisolated(unsafe) public static let linearToEaseOut: any Curve = Cubic(0.35, 0.91, 0.33, 0.97)

    /// A cubic animation curve that starts quickly and ends slowly, with sinusoidal easing.
    ///
    /// **Dart Source:** `curves.dart:1645`
    nonisolated(unsafe) public static let easeOutSine: any Curve = Cubic(0.39, 0.575, 0.565, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, based on a quadratic equation.
    ///
    /// **Dart Source:** `curves.dart:1656`
    nonisolated(unsafe) public static let easeOutQuad: any Curve = Cubic(0.25, 0.46, 0.45, 0.94)

    /// A cubic animation curve that starts quickly and ends slowly, based on a cubic equation.
    ///
    /// **Dart Source:** `curves.dart:1669`
    nonisolated(unsafe) public static let easeOutCubic: any Curve = Cubic(0.215, 0.61, 0.355, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, based on a quartic equation.
    ///
    /// **Dart Source:** `curves.dart:1682`
    nonisolated(unsafe) public static let easeOutQuart: any Curve = Cubic(0.165, 0.84, 0.44, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, based on a quintic equation.
    ///
    /// **Dart Source:** `curves.dart:1692`
    nonisolated(unsafe) public static let easeOutQuint: any Curve = Cubic(0.23, 1.0, 0.32, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, based on an exponential equation.
    ///
    /// **Dart Source:** `curves.dart:1702`
    nonisolated(unsafe) public static let easeOutExpo: any Curve = Cubic(0.19, 1.0, 0.22, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, effectively a quarter circle.
    ///
    /// **Dart Source:** `curves.dart:1713`
    nonisolated(unsafe) public static let easeOutCirc: any Curve = Cubic(0.075, 0.82, 0.165, 1.0)

    /// A cubic animation curve that starts quickly and ends slowly, overshooting once.
    ///
    /// **Dart Source:** `curves.dart:1723`
    nonisolated(unsafe) public static let easeOutBack: any Curve = Cubic(0.175, 0.885, 0.32, 1.275)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly.
    ///
    /// **Dart Source:** `curves.dart:1731`
    nonisolated(unsafe) public static let easeInOut: any Curve = Cubic(0.42, 0.0, 0.58, 1.0)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// with sinusoidal easing.
    ///
    /// **Dart Source:** `curves.dart:1740`
    nonisolated(unsafe) public static let easeInOutSine: any Curve = Cubic(0.445, 0.05, 0.55, 0.95)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// based on a quadratic equation.
    ///
    /// **Dart Source:** `curves.dart:1751`
    nonisolated(unsafe) public static let easeInOutQuad: any Curve = Cubic(0.455, 0.03, 0.515, 0.955)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// based on a cubic equation.
    ///
    /// **Dart Source:** `curves.dart:1765`
    nonisolated(unsafe) public static let easeInOutCubic: any Curve = Cubic(0.645, 0.045, 0.355, 1.0)

    /// A cubic animation curve that starts slowly, speeds up shortly thereafter,
    /// and then ends slowly. A steeper version of ``easeInOutCubic``.
    ///
    /// **Dart Source:** `curves.dart:1777-1783`
    nonisolated(unsafe) public static let easeInOutCubicEmphasized: any Curve = ThreePointCubic(
        Offset(0.05, 0),
        Offset(0.133333, 0.06),
        Offset(0.166666, 0.4),
        Offset(0.208333, 0.82),
        Offset(0.25, 1)
    )

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// based on a quartic equation.
    ///
    /// **Dart Source:** `curves.dart:1797`
    nonisolated(unsafe) public static let easeInOutQuart: any Curve = Cubic(0.77, 0.0, 0.175, 1.0)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// based on a quintic equation.
    ///
    /// **Dart Source:** `curves.dart:1808`
    nonisolated(unsafe) public static let easeInOutQuint: any Curve = Cubic(0.86, 0.0, 0.07, 1.0)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// with an exceptionally steep midpoint.
    ///
    /// **Dart Source:** `curves.dart:1822`
    nonisolated(unsafe) public static let easeInOutExpo: any Curve = Cubic(1.0, 0.0, 0.0, 1.0)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// effectively a half circle.
    ///
    /// **Dart Source:** `curves.dart:1836`
    nonisolated(unsafe) public static let easeInOutCirc: any Curve = Cubic(0.785, 0.135, 0.15, 0.86)

    /// A cubic animation curve that starts slowly, speeds up, and then ends slowly,
    /// overshooting its bounds twice.
    ///
    /// **Dart Source:** `curves.dart:1850`
    nonisolated(unsafe) public static let easeInOutBack: any Curve = Cubic(0.68, -0.55, 0.265, 1.55)

    /// A curve that starts quickly and eases into its final position.
    ///
    /// **Dart Source:** `curves.dart:1863`
    nonisolated(unsafe) public static let fastOutSlowIn: any Curve = Cubic(0.4, 0.0, 0.2, 1.0)

    /// A cubic animation curve that starts quickly, slows down, and then ends quickly.
    ///
    /// **Dart Source:** `curves.dart:1869`
    nonisolated(unsafe) public static let slowMiddle: any Curve = Cubic(0.15, 0.85, 0.85, 0.15)

    /// An oscillating curve that grows in magnitude.
    ///
    /// **Dart Source:** `curves.dart:1874`
    nonisolated(unsafe) public static let bounceIn: any Curve = BounceInCurve()

    /// An oscillating curve that shrinks in magnitude.
    ///
    /// **Dart Source:** `curves.dart:1879`
    nonisolated(unsafe) public static let bounceOut: any Curve = BounceOutCurve()

    /// An oscillating curve that first grows and then shrinks in magnitude.
    ///
    /// **Dart Source:** `curves.dart:1884`
    nonisolated(unsafe) public static let bounceInOut: any Curve = BounceInOutCurve()

    /// An oscillating curve that grows in magnitude while overshooting its bounds.
    ///
    /// **Dart Source:** `curves.dart:1889`
    nonisolated(unsafe) public static let elasticIn: any Curve = ElasticInCurve()

    /// An oscillating curve that shrinks in magnitude while overshooting its bounds.
    ///
    /// **Dart Source:** `curves.dart:1894`
    nonisolated(unsafe) public static let elasticOut: any Curve = ElasticOutCurve()

    /// An oscillating curve that grows and then shrinks in magnitude while overshooting its bounds.
    ///
    /// **Dart Source:** `curves.dart:1899`
    nonisolated(unsafe) public static let elasticInOut: any Curve = ElasticInOutCurve()
}
