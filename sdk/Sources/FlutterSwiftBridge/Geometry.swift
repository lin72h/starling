// Geometry.swift
// Flutter Swift Bridge
//
// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart`

import Foundation
import FlutterSwiftBridgeCxx

// MARK: - Custom Operators

/// Truncating division operator (equivalent to Dart's ~/ operator).
///
/// **Dart Source:** This operator is built into Dart for integer division.
/// REASON: Swift doesn't have a built-in ~/ operator; we define it here for Dart compatibility.
infix operator ~/: MultiplicationPrecedence

// MARK: - OffsetBase Protocol

/// Base protocol for `Size` and `Offset`, which are both ways to describe
/// a distance as a two-dimensional axis-aligned vector.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:7-92`
/// **Original Name:** `OffsetBase` (abstract class)
///
/// DIFFERENCE FROM DART: Using protocol instead of abstract class.
/// REASON: Swift doesn't have abstract classes; protocol + extension provides equivalent functionality.
public protocol OffsetBase {
    /// The horizontal component of this object.
    ///
    /// **Dart Source:** `geometry.dart:17`
    /// **Original:** `final double _dx;`
    var dx: Double { get }

    /// The vertical component of this object.
    ///
    /// **Dart Source:** `geometry.dart:18`
    /// **Original:** `final double _dy;`
    var dy: Double { get }
}

// MARK: - OffsetBase Default Implementations

extension OffsetBase {
    /// Returns true if either component is `Double.infinity`, and false if both
    /// are finite (or negative infinity, or NaN).
    ///
    /// This is different than comparing for equality with an instance that has
    /// _both_ components set to `Double.infinity`.
    ///
    /// **Dart Source:** `geometry.dart:20-29`
    /// **Original:** `bool get isInfinite => _dx >= double.infinity || _dy >= double.infinity;`
    ///
    /// See also:
    ///  * `isFinite`, which is true if both components are finite (and not NaN).
    public var isInfinite: Bool {
        dx >= .infinity || dy >= .infinity
    }

    /// Whether both components are finite (neither infinite nor NaN).
    ///
    /// **Dart Source:** `geometry.dart:31-37`
    /// **Original:** `bool get isFinite => _dx.isFinite && _dy.isFinite;`
    ///
    /// See also:
    ///  * `isInfinite`, which returns true if either component is equal to
    ///    positive infinity.
    public var isFinite: Bool {
        dx.isFinite && dy.isFinite
    }
}

// MARK: - OffsetBase Comparison Operators

/// Less-than operator. Compares an `Offset` or `Size` to another `Offset` or
/// `Size`, and returns true if both the horizontal and vertical values of the
/// left-hand-side operand are smaller than the horizontal and vertical values
/// of the right-hand-side operand respectively. Returns false otherwise.
///
/// This is a partial ordering. It is possible for two values to be neither
/// less, nor greater than, nor equal to, another.
///
/// **Dart Source:** `geometry.dart:39-46`
/// **Original:** `bool operator <(OffsetBase other) => _dx < other._dx && _dy < other._dy;`
public func < <T: OffsetBase, U: OffsetBase>(lhs: T, rhs: U) -> Bool {
    lhs.dx < rhs.dx && lhs.dy < rhs.dy
}

/// Less-than-or-equal-to operator. Compares an `Offset` or `Size` to another
/// `Offset` or `Size`, and returns true if both the horizontal and vertical
/// values of the left-hand-side operand are smaller than or equal to the
/// horizontal and vertical values of the right-hand-side operand
/// respectively. Returns false otherwise.
///
/// This is a partial ordering. It is possible for two values to be neither
/// less, nor greater than, nor equal to, another.
///
/// **Dart Source:** `geometry.dart:48-56`
/// **Original:** `bool operator <=(OffsetBase other) => _dx <= other._dx && _dy <= other._dy;`
public func <= <T: OffsetBase, U: OffsetBase>(lhs: T, rhs: U) -> Bool {
    lhs.dx <= rhs.dx && lhs.dy <= rhs.dy
}

/// Greater-than operator. Compares an `Offset` or `Size` to another `Offset`
/// or `Size`, and returns true if both the horizontal and vertical values of
/// the left-hand-side operand are bigger than the horizontal and vertical
/// values of the right-hand-side operand respectively. Returns false
/// otherwise.
///
/// This is a partial ordering. It is possible for two values to be neither
/// less, nor greater than, nor equal to, another.
///
/// **Dart Source:** `geometry.dart:58-66`
/// **Original:** `bool operator >(OffsetBase other) => _dx > other._dx && _dy > other._dy;`
public func > <T: OffsetBase, U: OffsetBase>(lhs: T, rhs: U) -> Bool {
    lhs.dx > rhs.dx && lhs.dy > rhs.dy
}

/// Greater-than-or-equal-to operator. Compares an `Offset` or `Size` to
/// another `Offset` or `Size`, and returns true if both the horizontal and
/// vertical values of the left-hand-side operand are bigger than or equal to
/// the horizontal and vertical values of the right-hand-side operand
/// respectively. Returns false otherwise.
///
/// This is a partial ordering. It is possible for two values to be neither
/// less, nor greater than, nor equal to, another.
///
/// **Dart Source:** `geometry.dart:68-76`
/// **Original:** `bool operator >=(OffsetBase other) => _dx >= other._dx && _dy >= other._dy;`
public func >= <T: OffsetBase, U: OffsetBase>(lhs: T, rhs: U) -> Bool {
    lhs.dx >= rhs.dx && lhs.dy >= rhs.dy
}

// MARK: - OffsetBase Equality & Hashing
// Note: The == operator and hashCode are handled by Equatable and Hashable
// conformance on concrete types (Offset, Size) rather than on the protocol.
// This matches Swift idioms where equality is typically type-specific.
//
// **Dart Source:** `geometry.dart:78-88`
// **Original:**
//   bool operator ==(Object other) => other is OffsetBase && other._dx == _dx && other._dy == _dy;
//   int get hashCode => Object.hash(_dx, _dy);
//
// DIFFERENCE FROM DART: Equality and hashCode moved to concrete types.
// REASON: Swift protocols cannot define == that returns Bool for Self without
// making the protocol non-existential. Concrete types (Offset, Size) will
// conform to Equatable and Hashable directly.

// MARK: - OffsetBase String Representation
// Note: toString() is also type-specific and will be implemented on concrete types.
//
// **Dart Source:** `geometry.dart:90-91`
// **Original:** `String toString() => 'OffsetBase(${_dx.toStringAsFixed(1)}, ${_dy.toStringAsFixed(1)})';`
//
// DIFFERENCE FROM DART: String representation moved to CustomStringConvertible conformance.
// REASON: Swift idiom uses CustomStringConvertible protocol for string representation.

// MARK: - RSTransform

/// A transform consisting of a translation, a rotation, and a uniform scale.
///
/// Used by `Canvas.drawAtlas`. This is a more efficient way to represent these
/// simple transformations than a full matrix.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:2112-2201`
/// **Original Name:** `RSTransform`
///
/// DIFFERENCE FROM DART: Using `[Float]` array instead of `Float32List`.
/// REASON: Swift doesn't have `Float32List`; `[Float]` provides equivalent functionality.
public struct RSTransform {
    /// Internal storage for the transform values.
    ///
    /// **Dart Source:** `geometry.dart:2184`
    /// **Original:** `final Float32List _value = Float32List(4);`
    private var _value: [Float]

    /// Creates an RSTransform.
    ///
    /// An `RSTransform` expresses the combination of a translation, a rotation
    /// around a particular point, and a scale factor.
    ///
    /// The first argument, `scos`, is the cosine of the rotation, multiplied by
    /// the scale factor.
    ///
    /// The second argument, `ssin`, is the sine of the rotation, multiplied by
    /// that same scale factor.
    ///
    /// The third argument is the x coordinate of the translation, minus the
    /// `scos` argument multiplied by the x-coordinate of the rotation point, plus
    /// the `ssin` argument multiplied by the y-coordinate of the rotation point.
    ///
    /// The fourth argument is the y coordinate of the translation, minus the `ssin`
    /// argument multiplied by the x-coordinate of the rotation point, minus the
    /// `scos` argument multiplied by the y-coordinate of the rotation point.
    ///
    /// The `RSTransform.fromComponents` method may be a simpler way to
    /// construct these values. However, if there is a way to factor out the
    /// computations of the sine and cosine of the rotation so that they can be
    /// reused over multiple calls to this constructor, it may be more efficient
    /// to directly use this constructor instead.
    ///
    /// **Dart Source:** `geometry.dart:2142-2148`
    /// **Original:**
    /// ```dart
    /// RSTransform(double scos, double ssin, double tx, double ty) {
    ///   _value
    ///     ..[0] = scos
    ///     ..[1] = ssin
    ///     ..[2] = tx
    ///     ..[3] = ty;
    /// }
    /// ```
    public init(_ scos: Double, _ ssin: Double, _ tx: Double, _ ty: Double) {
        _value = [Float(scos), Float(ssin), Float(tx), Float(ty)]
    }

    /// Creates an RSTransform from its individual components.
    ///
    /// The `rotation` parameter gives the rotation in radians.
    ///
    /// The `scale` parameter describes the uniform scale factor.
    ///
    /// The `anchorX` and `anchorY` parameters give the coordinate of the point
    /// around which to rotate.
    ///
    /// The `translateX` and `translateY` parameters give the coordinate of the
    /// offset by which to translate.
    ///
    /// This constructor computes the arguments of the `RSTransform.init`
    /// constructor and then defers to that constructor to actually create the
    /// object. If many `RSTransform` objects are being created and there is a way
    /// to factor out the computations of the sine and cosine of the rotation
    /// (which are computed each time this constructor is called) and reuse them
    /// over multiple `RSTransform` objects, it may be more efficient to directly
    /// use the more direct `RSTransform.init` constructor instead.
    ///
    /// **Dart Source:** `geometry.dart:2169-2182`
    /// **Original:**
    /// ```dart
    /// factory RSTransform.fromComponents({
    ///   required double rotation,
    ///   required double scale,
    ///   required double anchorX,
    ///   required double anchorY,
    ///   required double translateX,
    ///   required double translateY,
    /// }) {
    ///   final double scos = math.cos(rotation) * scale;
    ///   final double ssin = math.sin(rotation) * scale;
    ///   final double tx = translateX + -scos * anchorX + ssin * anchorY;
    ///   final double ty = translateY + -ssin * anchorX - scos * anchorY;
    ///   return RSTransform(scos, ssin, tx, ty);
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Factory constructor becomes static method.
    /// REASON: Swift doesn't have factory constructors.
    public static func fromComponents(
        rotation: Double,
        scale: Double,
        anchorX: Double,
        anchorY: Double,
        translateX: Double,
        translateY: Double
    ) -> RSTransform {
        let scos = cos(rotation) * scale
        let ssin = sin(rotation) * scale
        let tx = translateX + -scos * anchorX + ssin * anchorY
        let ty = translateY + -ssin * anchorX - scos * anchorY
        return RSTransform(scos, ssin, tx, ty)
    }

    /// The cosine of the rotation multiplied by the scale factor.
    ///
    /// **Dart Source:** `geometry.dart:2186-2187`
    /// **Original:** `double get scos => _value[0];`
    public var scos: Double {
        Double(_value[0])
    }

    /// The sine of the rotation multiplied by that same scale factor.
    ///
    /// **Dart Source:** `geometry.dart:2189-2190`
    /// **Original:** `double get ssin => _value[1];`
    public var ssin: Double {
        Double(_value[1])
    }

    /// The x coordinate of the translation, minus `scos` multiplied by the
    /// x-coordinate of the rotation point, plus `ssin` multiplied by the
    /// y-coordinate of the rotation point.
    ///
    /// **Dart Source:** `geometry.dart:2192-2195`
    /// **Original:** `double get tx => _value[2];`
    public var tx: Double {
        Double(_value[2])
    }

    /// The y coordinate of the translation, minus `ssin` multiplied by the
    /// x-coordinate of the rotation point, minus `scos` multiplied by the
    /// y-coordinate of the rotation point.
    ///
    /// **Dart Source:** `geometry.dart:2197-2200`
    /// **Original:** `double get ty => _value[3];`
    public var ty: Double {
        Double(_value[3])
    }
}

// MARK: - Radius

/// A radius for either circular or elliptical shapes.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:936-1095`
/// **Original Name:** `Radius`
public struct Radius: Hashable, Equatable, Sendable {
    /// The radius value on the horizontal axis.
    ///
    /// **Dart Source:** `geometry.dart:950-951`
    /// **Original:** `final double x;`
    public let x: Double

    /// The radius value on the vertical axis.
    ///
    /// **Dart Source:** `geometry.dart:953-954`
    /// **Original:** `final double y;`
    public let y: Double

    /// Constructs an elliptical radius with the given radii.
    ///
    /// **Dart Source:** `geometry.dart:944-948`
    /// **Original:** `const Radius.elliptical(this.x, this.y);`
    public init(elliptical x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    /// Constructs a circular radius. [x] and [y] will have the same radius value.
    ///
    /// **Dart Source:** `geometry.dart:938-942`
    /// **Original:** `const Radius.circular(double radius) : this.elliptical(radius, radius);`
    public init(circular radius: Double) {
        self.x = radius
        self.y = radius
    }

    /// A radius with [x] and [y] values set to zero.
    ///
    /// You can use `Radius.zero` with `RRect` or `RSuperellipse` to have
    /// right-angle corners.
    ///
    /// **Dart Source:** `geometry.dart:956-960`
    /// **Original:** `static const Radius zero = Radius.circular(0.0);`
    public static let zero = Radius(circular: 0.0)

    /// Returns this [Radius], with values clamped to the given min and max
    /// [Radius] values.
    ///
    /// The `minimum` value defaults to `Radius.circular(-Double.infinity)`, and
    /// the `maximum` value defaults to `Radius.circular(Double.infinity)`.
    ///
    /// **Dart Source:** `geometry.dart:962-974`
    /// **Original:**
    /// ```dart
    /// Radius clamp({Radius? minimum, Radius? maximum}) {
    ///   minimum ??= const Radius.circular(-double.infinity);
    ///   maximum ??= const Radius.circular(double.infinity);
    ///   return Radius.elliptical(
    ///     clampDouble(x, minimum.x, maximum.x),
    ///     clampDouble(y, minimum.y, maximum.y),
    ///   );
    /// }
    /// ```
    public func clamp(minimum: Radius? = nil, maximum: Radius? = nil) -> Radius {
        let min = minimum ?? Radius(circular: -.infinity)
        let max = maximum ?? Radius(circular: .infinity)
        return Radius(
            elliptical: clampDouble(x, min.x, max.x),
            clampDouble(y, min.y, max.y)
        )
    }

    /// Returns this [Radius], with values clamped to the given min and max
    /// values in each dimension.
    ///
    /// The `minimumX` and `minimumY` values default to `-Double.infinity`, and
    /// the `maximumX` and `maximumY` values default to `Double.infinity`.
    ///
    /// **Dart Source:** `geometry.dart:976-986`
    /// **Original:**
    /// ```dart
    /// Radius clampValues({double? minimumX, double? minimumY, double? maximumX, double? maximumY}) {
    ///   return Radius.elliptical(
    ///     clampDouble(x, minimumX ?? -double.infinity, maximumX ?? double.infinity),
    ///     clampDouble(y, minimumY ?? -double.infinity, maximumY ?? double.infinity),
    ///   );
    /// }
    /// ```
    public func clampValues(
        minimumX: Double? = nil,
        minimumY: Double? = nil,
        maximumX: Double? = nil,
        maximumY: Double? = nil
    ) -> Radius {
        return Radius(
            elliptical: clampDouble(x, minimumX ?? -.infinity, maximumX ?? .infinity),
            clampDouble(y, minimumY ?? -.infinity, maximumY ?? .infinity)
        )
    }

    /// Unary negation operator.
    ///
    /// Returns a Radius with the distances negated.
    ///
    /// Radiuses with negative values aren't geometrically meaningful, but could
    /// occur as part of expressions. For example, negating a radius of one pixel
    /// and then adding the result to another radius is equivalent to subtracting
    /// a radius of one pixel from the other.
    ///
    /// **Dart Source:** `geometry.dart:988-996`
    /// **Original:** `Radius operator -() => Radius.elliptical(-x, -y);`
    public static prefix func - (radius: Radius) -> Radius {
        Radius(elliptical: -radius.x, -radius.y)
    }

    /// Binary subtraction operator.
    ///
    /// Returns a radius whose [x] value is the left-hand-side operand's [x]
    /// minus the right-hand-side operand's [x] and whose [y] value is the
    /// left-hand-side operand's [y] minus the right-hand-side operand's [y].
    ///
    /// **Dart Source:** `geometry.dart:998-1003`
    /// **Original:** `Radius operator -(Radius other) => Radius.elliptical(x - other.x, y - other.y);`
    public static func - (lhs: Radius, rhs: Radius) -> Radius {
        Radius(elliptical: lhs.x - rhs.x, lhs.y - rhs.y)
    }

    /// Binary addition operator.
    ///
    /// Returns a radius whose [x] value is the sum of the [x] values of the
    /// two operands, and whose [y] value is the sum of the [y] values of the
    /// two operands.
    ///
    /// **Dart Source:** `geometry.dart:1005-1010`
    /// **Original:** `Radius operator +(Radius other) => Radius.elliptical(x + other.x, y + other.y);`
    public static func + (lhs: Radius, rhs: Radius) -> Radius {
        Radius(elliptical: lhs.x + rhs.x, lhs.y + rhs.y)
    }

    /// Multiplication operator.
    ///
    /// Returns a radius whose coordinates are the coordinates of the
    /// left-hand-side operand (a radius) multiplied by the scalar
    /// right-hand-side operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:1012-1017`
    /// **Original:** `Radius operator *(double operand) => Radius.elliptical(x * operand, y * operand);`
    public static func * (lhs: Radius, rhs: Double) -> Radius {
        Radius(elliptical: lhs.x * rhs, lhs.y * rhs)
    }

    /// Division operator.
    ///
    /// Returns a radius whose coordinates are the coordinates of the
    /// left-hand-side operand (a radius) divided by the scalar right-hand-side
    /// operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:1019-1024`
    /// **Original:** `Radius operator /(double operand) => Radius.elliptical(x / operand, y / operand);`
    public static func / (lhs: Radius, rhs: Double) -> Radius {
        Radius(elliptical: lhs.x / rhs, lhs.y / rhs)
    }

    /// Integer (truncating) division operator.
    ///
    /// Returns a radius whose coordinates are the coordinates of the
    /// left-hand-side operand (a radius) divided by the scalar right-hand-side
    /// operand (a double), rounded towards zero.
    ///
    /// **Dart Source:** `geometry.dart:1026-1032`
    /// **Original:** `Radius operator ~/(double operand) => Radius.elliptical((x ~/ operand).toDouble(), (y ~/ operand).toDouble());`
    ///
    /// DIFFERENCE FROM DART: Using custom infix operator `~/` for truncating division.
    /// REASON: Swift doesn't have a built-in `~/` operator; we define a custom one.
    public static func ~/ (lhs: Radius, rhs: Double) -> Radius {
        Radius(elliptical: Double(Int(lhs.x / rhs)), Double(Int(lhs.y / rhs)))
    }

    /// Modulo (remainder) operator.
    ///
    /// Returns a radius whose coordinates are the remainder of dividing the
    /// coordinates of the left-hand-side operand (a radius) by the scalar
    /// right-hand-side operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:1034-1039`
    /// **Original:** `Radius operator %(double operand) => Radius.elliptical(x % operand, y % operand);`
    public static func % (lhs: Radius, rhs: Double) -> Radius {
        Radius(elliptical: lhs.x.truncatingRemainder(dividingBy: rhs), lhs.y.truncatingRemainder(dividingBy: rhs))
    }

    /// Linearly interpolate between two radii.
    ///
    /// If either is nil, this function substitutes `Radius.zero` instead.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    ///
    /// **Dart Source:** `geometry.dart:1041-1071`
    /// **Original:**
    /// ```dart
    /// static Radius? lerp(Radius? a, Radius? b, double t) {
    ///   if (b == null) {
    ///     if (a == null) {
    ///       return null;
    ///     } else {
    ///       final double k = 1.0 - t;
    ///       return Radius.elliptical(a.x * k, a.y * k);
    ///     }
    ///   } else {
    ///     if (a == null) {
    ///       return Radius.elliptical(b.x * t, b.y * t);
    ///     } else {
    ///       return Radius.elliptical(_lerpDouble(a.x, b.x, t), _lerpDouble(a.y, b.y, t));
    ///     }
    ///   }
    /// }
    /// ```
    public static func lerp(_ a: Radius?, _ b: Radius?, _ t: Double) -> Radius? {
        if b == nil {
            if a == nil {
                return nil
            } else {
                let k = 1.0 - t
                return Radius(elliptical: a!.x * k, a!.y * k)
            }
        } else {
            if a == nil {
                return Radius(elliptical: b!.x * t, b!.y * t)
            } else {
                return Radius(elliptical: _lerpDouble(a!.x, b!.x, t), _lerpDouble(a!.y, b!.y, t))
            }
        }
    }

    /// Equality operator.
    ///
    /// **Dart Source:** `geometry.dart:1073-1083`
    /// **Original:**
    /// ```dart
    /// bool operator ==(Object other) {
    ///   if (identical(this, other)) {
    ///     return true;
    ///   }
    ///   if (runtimeType != other.runtimeType) {
    ///     return false;
    ///   }
    ///   return other is Radius && other.x == x && other.y == y;
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Swift's Equatable handles the type check automatically.
    /// REASON: Swift idiom; structs conform to Equatable with synthesized == implementation.
    /// The `identical` check is not needed in Swift since structs are value types.
    public static func == (lhs: Radius, rhs: Radius) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    /// Hash code.
    ///
    /// **Dart Source:** `geometry.dart:1085-1086`
    /// **Original:** `int get hashCode => Object.hash(x, y);`
    ///
    /// DIFFERENCE FROM DART: Using Swift's Hashable protocol.
    /// REASON: Swift idiom for hashing; provides better standard library integration.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

// MARK: - Radius CustomStringConvertible

extension Radius: CustomStringConvertible {
    /// String representation of this radius.
    ///
    /// **Dart Source:** `geometry.dart:1088-1094`
    /// **Original:**
    /// ```dart
    /// String toString() {
    ///   return x == y
    ///       ? 'Radius.circular(${x.toStringAsFixed(1)})'
    ///       : 'Radius.elliptical(${x.toStringAsFixed(1)}, '
    ///             '${y.toStringAsFixed(1)})';
    /// }
    /// ```
    public var description: String {
        if x == y {
            return "Radius.circular(\(String(format: "%.1f", x)))"
        } else {
            return "Radius.elliptical(\(String(format: "%.1f", x)), \(String(format: "%.1f", y)))"
        }
    }
}

// MARK: - Offset

/// An immutable 2D floating-point offset.
///
/// Generally speaking, Offsets can be interpreted in two ways:
///
/// 1. As representing a point in Cartesian space a specified distance from a
///    separately-maintained origin. For example, the top-left position of
///    children in the `RenderBox` protocol is typically represented as an
///    `Offset` from the top left of the parent box.
///
/// 2. As a vector that can be applied to coordinates. For example, when
///    painting a `RenderObject`, the parent is passed an `Offset` from the
///    screen's origin which it can add to the offsets of its children to find
///    the `Offset` from the screen's origin to each of the children.
///
/// Because a particular `Offset` can be interpreted as one sense at one time
/// then as the other sense at a later time, the same class is used for both
/// senses.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:94-341`
/// **Original Name:** `Offset` (class extends OffsetBase)
///
/// See also:
///  * `Size`, which represents a vector describing the size of a rectangle.
public struct Offset: OffsetBase, Hashable, Equatable, Sendable {
    /// The x component of the offset.
    ///
    /// The y component is given by `dy`.
    ///
    /// **Dart Source:** `geometry.dart:129-132`
    /// **Original:** `double get dx => _dx;`
    public let dx: Double

    /// The y component of the offset.
    ///
    /// The x component is given by `dx`.
    ///
    /// **Dart Source:** `geometry.dart:134-137`
    /// **Original:** `double get dy => _dy;`
    public let dy: Double

    /// Creates an offset. The first argument sets `dx`, the horizontal component,
    /// and the second sets `dy`, the vertical component.
    ///
    /// **Dart Source:** `geometry.dart:116-118`
    /// **Original:** `const Offset(super.dx, super.dy);`
    public init(_ dx: Double, _ dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    /// Creates an offset from its `direction` and `distance`.
    ///
    /// The direction is in radians clockwise from the positive x-axis.
    ///
    /// The distance can be omitted, to create a unit vector (distance = 1.0).
    ///
    /// **Dart Source:** `geometry.dart:120-127`
    /// **Original:**
    /// ```dart
    /// factory Offset.fromDirection(double direction, [double distance = 1.0]) {
    ///   return Offset(distance * math.cos(direction), distance * math.sin(direction));
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Factory constructor becomes static method.
    /// REASON: Swift doesn't have factory constructors.
    public static func fromDirection(_ direction: Double, _ distance: Double = 1.0) -> Offset {
        Offset(distance * cos(direction), distance * sin(direction))
    }

    /// The magnitude of the offset.
    ///
    /// If you need this value to compare it to another `Offset`'s distance,
    /// consider using `distanceSquared` instead, since it is cheaper to compute.
    ///
    /// **Dart Source:** `geometry.dart:139-143`
    /// **Original:** `double get distance => math.sqrt(dx * dx + dy * dy);`
    public var distance: Double {
        sqrt(dx * dx + dy * dy)
    }

    /// The square of the magnitude of the offset.
    ///
    /// This is cheaper than computing the `distance` itself.
    ///
    /// **Dart Source:** `geometry.dart:145-148`
    /// **Original:** `double get distanceSquared => dx * dx + dy * dy;`
    public var distanceSquared: Double {
        dx * dx + dy * dy
    }

    /// The angle of this offset as radians clockwise from the positive x-axis, in
    /// the range -π to π, assuming positive values of the x-axis go to the
    /// right and positive values of the y-axis go down.
    ///
    /// Zero means that `dy` is zero and `dx` is zero or positive.
    ///
    /// Values from zero to π/2 indicate positive values of `dx` and `dy`, the
    /// bottom-right quadrant.
    ///
    /// Values from π/2 to π indicate negative values of `dx` and positive
    /// values of `dy`, the bottom-left quadrant.
    ///
    /// Values from zero to -π/2 indicate positive values of `dx` and negative
    /// values of `dy`, the top-right quadrant.
    ///
    /// Values from -π/2 to -π indicate negative values of `dx` and `dy`,
    /// the top-left quadrant.
    ///
    /// When `dy` is zero and `dx` is negative, the `direction` is π.
    ///
    /// When `dx` is zero, `direction` is π/2 if `dy` is positive and -π/2
    /// if `dy` is negative.
    ///
    /// **Dart Source:** `geometry.dart:150-177`
    /// **Original:** `double get direction => math.atan2(dy, dx);`
    ///
    /// See also:
    ///  * `distance`, to compute the magnitude of the vector.
    ///  * `Canvas.rotate`, which uses the same convention for its angle.
    public var direction: Double {
        atan2(dy, dx)
    }

    /// An offset with zero magnitude.
    ///
    /// This can be used to represent the origin of a coordinate space.
    ///
    /// **Dart Source:** `geometry.dart:179-182`
    /// **Original:** `static const Offset zero = Offset(0.0, 0.0);`
    public static let zero = Offset(0.0, 0.0)

    /// An offset with infinite x and y components.
    ///
    /// **Dart Source:** `geometry.dart:184-191`
    /// **Original:** `static const Offset infinite = Offset(double.infinity, double.infinity);`
    ///
    /// See also:
    ///  * `isInfinite`, which checks whether either component is infinite.
    ///  * `isFinite`, which checks whether both components are finite.
    public static let infinite = Offset(.infinity, .infinity)

    /// Returns a new offset with the x component scaled by `scaleX` and the y
    /// component scaled by `scaleY`.
    ///
    /// If the two scale arguments are the same, consider using the `*` operator
    /// instead:
    ///
    /// ```swift
    /// let a = Offset(10.0, 10.0)
    /// let b = a * 2.0 // same as: a.scale(2.0, 2.0)
    /// ```
    ///
    /// If the two arguments are -1, consider using the unary `-` operator
    /// instead:
    ///
    /// ```swift
    /// let a = Offset(10.0, 10.0)
    /// let b = -a // same as: a.scale(-1.0, -1.0)
    /// ```
    ///
    /// **Dart Source:** `geometry.dart:193-211`
    /// **Original:** `Offset scale(double scaleX, double scaleY) => Offset(dx * scaleX, dy * scaleY);`
    public func scale(_ scaleX: Double, _ scaleY: Double) -> Offset {
        Offset(dx * scaleX, dy * scaleY)
    }

    /// Returns a new offset with translateX added to the x component and
    /// translateY added to the y component.
    ///
    /// If the arguments come from another `Offset`, consider using the `+` or `-`
    /// operators instead:
    ///
    /// ```swift
    /// let a = Offset(10.0, 10.0)
    /// let b = Offset(10.0, 10.0)
    /// let c = a + b // same as: a.translate(b.dx, b.dy)
    /// let d = a - b // same as: a.translate(-b.dx, -b.dy)
    /// ```
    ///
    /// **Dart Source:** `geometry.dart:213-226`
    /// **Original:** `Offset translate(double translateX, double translateY) => Offset(dx + translateX, dy + translateY);`
    public func translate(_ translateX: Double, _ translateY: Double) -> Offset {
        Offset(dx + translateX, dy + translateY)
    }

    /// Unary negation operator.
    ///
    /// Returns an offset with the coordinates negated.
    ///
    /// If the `Offset` represents an arrow on a plane, this operator returns the
    /// same arrow but pointing in the reverse direction.
    ///
    /// **Dart Source:** `geometry.dart:228-234`
    /// **Original:** `Offset operator -() => Offset(-dx, -dy);`
    public static prefix func - (offset: Offset) -> Offset {
        Offset(-offset.dx, -offset.dy)
    }

    /// Binary subtraction operator.
    ///
    /// Returns an offset whose `dx` value is the left-hand-side operand's `dx`
    /// minus the right-hand-side operand's `dx` and whose `dy` value is the
    /// left-hand-side operand's `dy` minus the right-hand-side operand's `dy`.
    ///
    /// **Dart Source:** `geometry.dart:236-243`
    /// **Original:** `Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);`
    ///
    /// See also `translate`.
    public static func - (lhs: Offset, rhs: Offset) -> Offset {
        Offset(lhs.dx - rhs.dx, lhs.dy - rhs.dy)
    }

    /// Binary addition operator.
    ///
    /// Returns an offset whose `dx` value is the sum of the `dx` values of the
    /// two operands, and whose `dy` value is the sum of the `dy` values of the
    /// two operands.
    ///
    /// **Dart Source:** `geometry.dart:245-252`
    /// **Original:** `Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);`
    ///
    /// See also `translate`.
    public static func + (lhs: Offset, rhs: Offset) -> Offset {
        Offset(lhs.dx + rhs.dx, lhs.dy + rhs.dy)
    }

    /// Multiplication operator.
    ///
    /// Returns an offset whose coordinates are the coordinates of the
    /// left-hand-side operand (an Offset) multiplied by the scalar
    /// right-hand-side operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:254-261`
    /// **Original:** `Offset operator *(double operand) => Offset(dx * operand, dy * operand);`
    ///
    /// See also `scale`.
    public static func * (lhs: Offset, rhs: Double) -> Offset {
        Offset(lhs.dx * rhs, lhs.dy * rhs)
    }

    /// Division operator.
    ///
    /// Returns an offset whose coordinates are the coordinates of the
    /// left-hand-side operand (an Offset) divided by the scalar right-hand-side
    /// operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:263-270`
    /// **Original:** `Offset operator /(double operand) => Offset(dx / operand, dy / operand);`
    ///
    /// See also `scale`.
    public static func / (lhs: Offset, rhs: Double) -> Offset {
        Offset(lhs.dx / rhs, lhs.dy / rhs)
    }

    /// Integer (truncating) division operator.
    ///
    /// Returns an offset whose coordinates are the coordinates of the
    /// left-hand-side operand (an Offset) divided by the scalar right-hand-side
    /// operand (a double), rounded towards zero.
    ///
    /// **Dart Source:** `geometry.dart:272-278`
    /// **Original:** `Offset operator ~/(double operand) => Offset((dx ~/ operand).toDouble(), (dy ~/ operand).toDouble());`
    ///
    /// DIFFERENCE FROM DART: Using custom infix operator `~/` for truncating division.
    /// REASON: Swift doesn't have a built-in `~/` operator; we define a custom one.
    public static func ~/ (lhs: Offset, rhs: Double) -> Offset {
        Offset(Double(Int(lhs.dx / rhs)), Double(Int(lhs.dy / rhs)))
    }

    /// Modulo (remainder) operator.
    ///
    /// Returns an offset whose coordinates are the remainder of dividing the
    /// coordinates of the left-hand-side operand (an Offset) by the scalar
    /// right-hand-side operand (a double).
    ///
    /// **Dart Source:** `geometry.dart:280-285`
    /// **Original:** `Offset operator %(double operand) => Offset(dx % operand, dy % operand);`
    public static func % (lhs: Offset, rhs: Double) -> Offset {
        Offset(lhs.dx.truncatingRemainder(dividingBy: rhs), lhs.dy.truncatingRemainder(dividingBy: rhs))
    }

    /// Linearly interpolate between two offsets.
    ///
    /// If either offset is nil, this function interpolates from `Offset.zero`.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    ///
    /// **Dart Source:** `geometry.dart:299-328`
    /// **Original:**
    /// ```dart
    /// static Offset? lerp(Offset? a, Offset? b, double t) {
    ///   if (b == null) {
    ///     if (a == null) {
    ///       return null;
    ///     } else {
    ///       return a * (1.0 - t);
    ///     }
    ///   } else {
    ///     if (a == null) {
    ///       return b * t;
    ///     } else {
    ///       return Offset(_lerpDouble(a.dx, b.dx, t), _lerpDouble(a.dy, b.dy, t));
    ///     }
    ///   }
    /// }
    /// ```
    public static func lerp(_ a: Offset?, _ b: Offset?, _ t: Double) -> Offset? {
        if b == nil {
            if a == nil {
                return nil
            } else {
                return a! * (1.0 - t)
            }
        } else {
            if a == nil {
                return b! * t
            } else {
                return Offset(_lerpDouble(a!.dx, b!.dx, t), _lerpDouble(a!.dy, b!.dy, t))
            }
        }
    }

    /// Equality operator.
    ///
    /// Compares two Offsets for equality.
    ///
    /// **Dart Source:** `geometry.dart:330-334`
    /// **Original:**
    /// ```dart
    /// bool operator ==(Object other) {
    ///   return other is Offset && other.dx == dx && other.dy == dy;
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Swift's Equatable handles the type check automatically.
    /// REASON: Swift idiom; structs conform to Equatable with synthesized == implementation.
    public static func == (lhs: Offset, rhs: Offset) -> Bool {
        lhs.dx == rhs.dx && lhs.dy == rhs.dy
    }

    /// Hash code.
    ///
    /// **Dart Source:** `geometry.dart:336-337`
    /// **Original:** `int get hashCode => Object.hash(dx, dy);`
    ///
    /// DIFFERENCE FROM DART: Using Swift's Hashable protocol.
    /// REASON: Swift idiom for hashing; provides better standard library integration.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dx)
        hasher.combine(dy)
    }
}

// MARK: - Offset CustomStringConvertible

extension Offset: CustomStringConvertible {
    /// String representation of this offset.
    ///
    /// **Dart Source:** `geometry.dart:339-340`
    /// **Original:** `String toString() => 'Offset(${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)})';`
    public var description: String {
        "Offset(\(String(format: "%.1f", dx)), \(String(format: "%.1f", dy)))"
    }
}

// MARK: - Offset & Size -> Rect Operator

/// Custom operator for rectangle construction from Offset and Size.
///
/// **Dart Source:** `geometry.dart:287-297`
/// **Original:** `Rect operator &(Size other) => Rect.fromLTWH(dx, dy, other.width, other.height);`
infix operator &: MultiplicationPrecedence

/// Rectangle constructor operator.
///
/// Combines an `Offset` and a `Size` to form a `Rect` whose top-left
/// coordinate is the point given by adding the offset (left-hand-side
/// operand) to the origin, and whose size is the right-hand-side operand.
///
/// ```swift
/// let myRect = Offset.zero & Size(100.0, 100.0)
/// // same as: Rect.fromLTWH(0.0, 0.0, 100.0, 100.0)
/// ```
///
/// **Dart Source:** `geometry.dart:287-297`
/// **Original:** `Rect operator &(Size other) => Rect.fromLTWH(dx, dy, other.width, other.height);`
public func & (lhs: Offset, rhs: Size) -> Rect {
    Rect.fromLTWH(lhs.dx, lhs.dy, rhs.width, rhs.height)
}

// MARK: - Size

/// Holds a 2D floating-point size.
///
/// You can think of this as an `Offset` from the origin.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:343-616`
/// **Original Name:** `Size` (class extends OffsetBase)
public struct Size: OffsetBase, Hashable, Equatable, Sendable {
    /// The horizontal extent of this size.
    ///
    /// **Dart Source:** `geometry.dart:378-379`
    /// **Original:** `double get width => _dx;`
    public let width: Double

    /// The vertical extent of this size.
    ///
    /// **Dart Source:** `geometry.dart:381-382`
    /// **Original:** `double get height => _dy;`
    public let height: Double

    // MARK: - OffsetBase Protocol Conformance

    /// The horizontal component of this size (same as `width`).
    ///
    /// Required for OffsetBase protocol conformance.
    public var dx: Double { width }

    /// The vertical component of this size (same as `height`).
    ///
    /// Required for OffsetBase protocol conformance.
    public var dy: Double { height }

    // MARK: - Initializers

    /// Creates a `Size` with the given `width` and `height`.
    ///
    /// **Dart Source:** `geometry.dart:347-348`
    /// **Original:** `const Size(super.width, super.height);`
    public init(_ width: Double, _ height: Double) {
        self.width = width
        self.height = height
    }

    /// Creates an instance of `Size` that has the same values as another.
    ///
    /// **Dart Source:** `geometry.dart:350-352`
    /// **Original:** `Size.copy(Size source) : super(source.width, source.height);`
    public init(copy source: Size) {
        self.width = source.width
        self.height = source.height
    }

    /// Creates a square `Size` whose `width` and `height` are the given dimension.
    ///
    /// **Dart Source:** `geometry.dart:354-360`
    /// **Original:** `const Size.square(double dimension) : super(dimension, dimension);`
    ///
    /// See also:
    ///  * `Size.init(fromRadius:)`, which is more convenient when the available size
    ///    is the radius of a circle.
    public init(square dimension: Double) {
        self.width = dimension
        self.height = dimension
    }

    /// Creates a `Size` with the given `width` and an infinite `height`.
    ///
    /// **Dart Source:** `geometry.dart:362-363`
    /// **Original:** `const Size.fromWidth(double width) : super(width, double.infinity);`
    public init(fromWidth width: Double) {
        self.width = width
        self.height = .infinity
    }

    /// Creates a `Size` with the given `height` and an infinite `width`.
    ///
    /// **Dart Source:** `geometry.dart:365-366`
    /// **Original:** `const Size.fromHeight(double height) : super(double.infinity, height);`
    public init(fromHeight height: Double) {
        self.width = .infinity
        self.height = height
    }

    /// Creates a square `Size` whose `width` and `height` are twice the given
    /// dimension.
    ///
    /// This is a square that contains a circle with the given radius.
    ///
    /// **Dart Source:** `geometry.dart:368-376`
    /// **Original:** `const Size.fromRadius(double radius) : super(radius * 2.0, radius * 2.0);`
    ///
    /// See also:
    ///  * `Size.init(square:)`, which creates a square with the given dimension.
    public init(fromRadius radius: Double) {
        self.width = radius * 2.0
        self.height = radius * 2.0
    }

    // MARK: - Static Constants

    /// An empty size, one with a zero width and a zero height.
    ///
    /// **Dart Source:** `geometry.dart:411-412`
    /// **Original:** `static const Size zero = Size(0.0, 0.0);`
    public static let zero = Size(0.0, 0.0)

    /// A size whose `width` and `height` are infinite.
    ///
    /// **Dart Source:** `geometry.dart:414-420`
    /// **Original:** `static const Size infinite = Size(double.infinity, double.infinity);`
    ///
    /// See also:
    ///  * `isInfinite`, which checks whether either dimension is infinite.
    ///  * `isFinite`, which checks whether both dimensions are finite.
    public static let infinite = Size(.infinity, .infinity)

    // MARK: - Computed Properties

    /// The aspect ratio of this size.
    ///
    /// This returns the `width` divided by the `height`.
    ///
    /// If the `width` is zero, the result will be zero. If the `height` is zero
    /// (and the `width` is not), the result will be `Double.infinity` or
    /// `-Double.infinity` as determined by the sign of `width`.
    ///
    /// **Dart Source:** `geometry.dart:384-409`
    /// **Original:**
    /// ```dart
    /// double get aspectRatio {
    ///   if (height != 0.0) {
    ///     return width / height;
    ///   }
    ///   if (width > 0.0) {
    ///     return double.infinity;
    ///   }
    ///   if (width < 0.0) {
    ///     return double.negativeInfinity;
    ///   }
    ///   return 0.0;
    /// }
    /// ```
    ///
    /// See also:
    ///  * `AspectRatio`, a widget for giving a child widget a specific aspect ratio.
    ///  * `FittedBox`, a widget that (in most modes) attempts to maintain a
    ///    child widget's aspect ratio while changing its size.
    public var aspectRatio: Double {
        if height != 0.0 {
            return width / height
        }
        if width > 0.0 {
            return .infinity
        }
        if width < 0.0 {
            return -.infinity
        }
        return 0.0
    }

    /// Whether this size encloses a zero area.
    ///
    /// Negative areas are considered empty.
    ///
    /// **Dart Source:** `geometry.dart:422-425`
    /// **Original:** `bool get isEmpty => width <= 0.0 || height <= 0.0;`
    public var isEmpty: Bool {
        width <= 0.0 || height <= 0.0
    }

    /// The lesser of the magnitudes of the `width` and the `height`.
    ///
    /// **Dart Source:** `geometry.dart:491-492`
    /// **Original:** `double get shortestSide => math.min(width.abs(), height.abs());`
    public var shortestSide: Double {
        Swift.min(Swift.abs(width), Swift.abs(height))
    }

    /// The greater of the magnitudes of the `width` and the `height`.
    ///
    /// **Dart Source:** `geometry.dart:494-495`
    /// **Original:** `double get longestSide => math.max(width.abs(), height.abs());`
    public var longestSide: Double {
        Swift.max(Swift.abs(width), Swift.abs(height))
    }

    /// A `Size` with the `width` and `height` swapped.
    ///
    /// **Dart Source:** `geometry.dart:570-571`
    /// **Original:** `Size get flipped => Size(height, width);`
    public var flipped: Size {
        Size(height, width)
    }

    // MARK: - Offset Calculation Methods

    /// The offset to the intersection of the top and left edges of the rectangle
    /// described by the given `Offset` (which is interpreted as the top-left corner)
    /// and this `Size`.
    ///
    /// **Dart Source:** `geometry.dart:500-505`
    /// **Original:** `Offset topLeft(Offset origin) => origin;`
    ///
    /// See also `Rect.topLeft`.
    public func topLeft(_ origin: Offset) -> Offset {
        origin
    }

    /// The offset to the center of the top edge of the rectangle described by the
    /// given offset (which is interpreted as the top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:507-511`
    /// **Original:** `Offset topCenter(Offset origin) => Offset(origin.dx + width / 2.0, origin.dy);`
    ///
    /// See also `Rect.topCenter`.
    public func topCenter(_ origin: Offset) -> Offset {
        Offset(origin.dx + width / 2.0, origin.dy)
    }

    /// The offset to the intersection of the top and right edges of the rectangle
    /// described by the given offset (which is interpreted as the top-left corner)
    /// and this size.
    ///
    /// **Dart Source:** `geometry.dart:513-518`
    /// **Original:** `Offset topRight(Offset origin) => Offset(origin.dx + width, origin.dy);`
    ///
    /// See also `Rect.topRight`.
    public func topRight(_ origin: Offset) -> Offset {
        Offset(origin.dx + width, origin.dy)
    }

    /// The offset to the center of the left edge of the rectangle described by the
    /// given offset (which is interpreted as the top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:520-524`
    /// **Original:** `Offset centerLeft(Offset origin) => Offset(origin.dx, origin.dy + height / 2.0);`
    ///
    /// See also `Rect.centerLeft`.
    public func centerLeft(_ origin: Offset) -> Offset {
        Offset(origin.dx, origin.dy + height / 2.0)
    }

    /// The offset to the point halfway between the left and right and the top and
    /// bottom edges of the rectangle described by the given offset (which is
    /// interpreted as the top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:526-531`
    /// **Original:** `Offset center(Offset origin) => Offset(origin.dx + width / 2.0, origin.dy + height / 2.0);`
    ///
    /// See also `Rect.center`.
    public func center(_ origin: Offset) -> Offset {
        Offset(origin.dx + width / 2.0, origin.dy + height / 2.0)
    }

    /// The offset to the center of the right edge of the rectangle described by the
    /// given offset (which is interpreted as the top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:533-537`
    /// **Original:** `Offset centerRight(Offset origin) => Offset(origin.dx + width, origin.dy + height / 2.0);`
    ///
    /// See also `Rect.centerRight`.
    public func centerRight(_ origin: Offset) -> Offset {
        Offset(origin.dx + width, origin.dy + height / 2.0)
    }

    /// The offset to the intersection of the bottom and left edges of the
    /// rectangle described by the given offset (which is interpreted as the
    /// top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:539-544`
    /// **Original:** `Offset bottomLeft(Offset origin) => Offset(origin.dx, origin.dy + height);`
    ///
    /// See also `Rect.bottomLeft`.
    public func bottomLeft(_ origin: Offset) -> Offset {
        Offset(origin.dx, origin.dy + height)
    }

    /// The offset to the center of the bottom edge of the rectangle described by
    /// the given offset (which is interpreted as the top-left corner) and this
    /// size.
    ///
    /// **Dart Source:** `geometry.dart:546-551`
    /// **Original:** `Offset bottomCenter(Offset origin) => Offset(origin.dx + width / 2.0, origin.dy + height);`
    ///
    /// See also `Rect.bottomCenter`.
    public func bottomCenter(_ origin: Offset) -> Offset {
        Offset(origin.dx + width / 2.0, origin.dy + height)
    }

    /// The offset to the intersection of the bottom and right edges of the
    /// rectangle described by the given offset (which is interpreted as the
    /// top-left corner) and this size.
    ///
    /// **Dart Source:** `geometry.dart:553-558`
    /// **Original:** `Offset bottomRight(Offset origin) => Offset(origin.dx + width, origin.dy + height);`
    ///
    /// See also `Rect.bottomRight`.
    public func bottomRight(_ origin: Offset) -> Offset {
        Offset(origin.dx + width, origin.dy + height)
    }

    /// Whether the point specified by the given offset (which is assumed to be
    /// relative to the top left of the size) lies between the left and right and
    /// the top and bottom edges of a rectangle of this size.
    ///
    /// Rectangles include their top and left edges but exclude their bottom and
    /// right edges.
    ///
    /// **Dart Source:** `geometry.dart:560-568`
    /// **Original:**
    /// ```dart
    /// bool contains(Offset offset) {
    ///   return offset.dx >= 0.0 && offset.dx < width && offset.dy >= 0.0 && offset.dy < height;
    /// }
    /// ```
    public func contains(_ offset: Offset) -> Bool {
        offset.dx >= 0.0 && offset.dx < width && offset.dy >= 0.0 && offset.dy < height
    }

    // MARK: - Operators

    /// Binary subtraction operator for `Size`.
    ///
    /// Subtracting a `Size` from a `Size` returns the `Offset` that describes how
    /// much bigger the left-hand-side operand is than the right-hand-side
    /// operand. Adding that resulting `Offset` to the `Size` that was the
    /// right-hand-side operand would return a `Size` equal to the `Size` that was
    /// the left-hand-side operand. (i.e. if `sizeA - sizeB -> offsetA`, then
    /// `offsetA + sizeB -> sizeA`)
    ///
    /// **Dart Source:** `geometry.dart:443-451`
    /// **Original:**
    /// ```dart
    /// OffsetBase operator -(OffsetBase other) {
    ///   if (other is Size) {
    ///     return Offset(width - other.width, height - other.height);
    ///   }
    ///   if (other is Offset) {
    ///     return Size(width - other.dx, height - other.dy);
    ///   }
    ///   throw ArgumentError(other);
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Separate operators for Size - Size and Size - Offset
    /// instead of a single operator returning OffsetBase.
    /// REASON: Swift's type system doesn't allow returning different types from
    /// the same operator. We provide type-safe alternatives.
    public static func - (lhs: Size, rhs: Size) -> Offset {
        Offset(lhs.width - rhs.width, lhs.height - rhs.height)
    }

    /// Binary subtraction operator for subtracting an `Offset` from a `Size`.
    ///
    /// Subtracting an `Offset` from a `Size` returns the `Size` that is smaller than
    /// the `Size` operand by the difference given by the `Offset` operand. In other
    /// words, the returned `Size` has a `width` consisting of the `width` of the
    /// left-hand-side operand minus the `Offset.dx` dimension of the
    /// right-hand-side operand, and a `height` consisting of the `height` of the
    /// left-hand-side operand minus the `Offset.dy` dimension of the
    /// right-hand-side operand.
    ///
    /// **Dart Source:** `geometry.dart:443-451` (part of the combined operator)
    public static func - (lhs: Size, rhs: Offset) -> Size {
        Size(lhs.width - rhs.dx, lhs.height - rhs.dy)
    }

    /// Binary addition operator for adding an `Offset` to a `Size`.
    ///
    /// Returns a `Size` whose `width` is the sum of the `width` of the
    /// left-hand-side operand, a `Size`, and the `Offset.dx` dimension of the
    /// right-hand-side operand, an `Offset`, and whose `height` is the sum of the
    /// `height` of the left-hand-side operand and the `Offset.dy` dimension of
    /// the right-hand-side operand.
    ///
    /// **Dart Source:** `geometry.dart:453-460`
    /// **Original:** `Size operator +(Offset other) => Size(width + other.dx, height + other.dy);`
    public static func + (lhs: Size, rhs: Offset) -> Size {
        Size(lhs.width + rhs.dx, lhs.height + rhs.dy)
    }

    /// Multiplication operator.
    ///
    /// Returns a `Size` whose dimensions are the dimensions of the left-hand-side
    /// operand (a `Size`) multiplied by the scalar right-hand-side operand (a
    /// `Double`).
    ///
    /// **Dart Source:** `geometry.dart:462-467`
    /// **Original:** `Size operator *(double operand) => Size(width * operand, height * operand);`
    public static func * (lhs: Size, rhs: Double) -> Size {
        Size(lhs.width * rhs, lhs.height * rhs)
    }

    /// Division operator.
    ///
    /// Returns a `Size` whose dimensions are the dimensions of the left-hand-side
    /// operand (a `Size`) divided by the scalar right-hand-side operand (a
    /// `Double`).
    ///
    /// **Dart Source:** `geometry.dart:469-474`
    /// **Original:** `Size operator /(double operand) => Size(width / operand, height / operand);`
    public static func / (lhs: Size, rhs: Double) -> Size {
        Size(lhs.width / rhs, lhs.height / rhs)
    }

    /// Integer (truncating) division operator.
    ///
    /// Returns a `Size` whose dimensions are the dimensions of the left-hand-side
    /// operand (a `Size`) divided by the scalar right-hand-side operand (a
    /// `Double`), rounded towards zero.
    ///
    /// **Dart Source:** `geometry.dart:476-482`
    /// **Original:** `Size operator ~/(double operand) => Size((width ~/ operand).toDouble(), (height ~/ operand).toDouble());`
    ///
    /// DIFFERENCE FROM DART: Using custom infix operator `~/` for truncating division.
    /// REASON: Swift doesn't have a built-in `~/` operator; we define a custom one.
    public static func ~/ (lhs: Size, rhs: Double) -> Size {
        Size(Double(Int(lhs.width / rhs)), Double(Int(lhs.height / rhs)))
    }

    /// Modulo (remainder) operator.
    ///
    /// Returns a `Size` whose dimensions are the remainder of dividing the
    /// left-hand-side operand (a `Size`) by the scalar right-hand-side operand (a
    /// `Double`).
    ///
    /// **Dart Source:** `geometry.dart:484-489`
    /// **Original:** `Size operator %(double operand) => Size(width % operand, height % operand);`
    public static func % (lhs: Size, rhs: Double) -> Size {
        Size(lhs.width.truncatingRemainder(dividingBy: rhs), lhs.height.truncatingRemainder(dividingBy: rhs))
    }

    // MARK: - Interpolation

    /// Linearly interpolate between two sizes.
    ///
    /// If either size is nil, this function interpolates from `Size.zero`.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    ///
    /// **Dart Source:** `geometry.dart:573-602`
    /// **Original:**
    /// ```dart
    /// static Size? lerp(Size? a, Size? b, double t) {
    ///   if (b == null) {
    ///     if (a == null) {
    ///       return null;
    ///     } else {
    ///       return a * (1.0 - t);
    ///     }
    ///   } else {
    ///     if (a == null) {
    ///       return b * t;
    ///     } else {
    ///       return Size(_lerpDouble(a.width, b.width, t), _lerpDouble(a.height, b.height, t));
    ///     }
    ///   }
    /// }
    /// ```
    public static func lerp(_ a: Size?, _ b: Size?, _ t: Double) -> Size? {
        if b == nil {
            if a == nil {
                return nil
            } else {
                return a! * (1.0 - t)
            }
        } else {
            if a == nil {
                return b! * t
            } else {
                return Size(_lerpDouble(a!.width, b!.width, t), _lerpDouble(a!.height, b!.height, t))
            }
        }
    }

    // MARK: - Equality & Hashing

    /// Compares two Sizes for equality.
    ///
    /// **Dart Source:** `geometry.dart:604-609`
    /// **Original:**
    /// ```dart
    /// // We don't compare the runtimeType because of _DebugSize in the framework.
    /// bool operator ==(Object other) {
    ///   return other is Size && other._dx == _dx && other._dy == _dy;
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Swift's Equatable handles the type check automatically.
    /// REASON: Swift idiom; structs conform to Equatable with synthesized == implementation.
    /// Note: We don't need to worry about _DebugSize subclass in Swift since Size is a struct.
    public static func == (lhs: Size, rhs: Size) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }

    /// Hash code.
    ///
    /// **Dart Source:** `geometry.dart:611-612`
    /// **Original:** `int get hashCode => Object.hash(_dx, _dy);`
    ///
    /// DIFFERENCE FROM DART: Using Swift's Hashable protocol.
    /// REASON: Swift idiom for hashing; provides better standard library integration.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

// MARK: - Size CustomStringConvertible

extension Size: CustomStringConvertible {
    /// String representation of this size.
    ///
    /// **Dart Source:** `geometry.dart:614-615`
    /// **Original:** `String toString() => 'Size(${width.toStringAsFixed(1)}, ${height.toStringAsFixed(1)})';`
    public var description: String {
        "Size(\(String(format: "%.1f", width)), \(String(format: "%.1f", height)))"
    }
}

// MARK: - Rect

/// An immutable, 2D, axis-aligned, floating-point rectangle whose coordinates
/// are relative to a given origin.
///
/// A Rect can be created with one of its constructors or from an `Offset` and a
/// `Size` using the `&` operator:
///
/// ```swift
/// let myRect = Offset(1.0, 2.0) & Size(3.0, 4.0)
/// ```
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:618-934`
/// **Original Name:** `Rect` (class)
public struct Rect: Hashable, Equatable, Sendable {
    /// The offset of the left edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:690-691`
    /// **Original:** `final double left;`
    public let left: Double

    /// The offset of the top edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:693-694`
    /// **Original:** `final double top;`
    public let top: Double

    /// The offset of the right edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:696-697`
    /// **Original:** `final double right;`
    public let right: Double

    /// The offset of the bottom edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:699-700`
    /// **Original:** `final double bottom;`
    public let bottom: Double

    // MARK: - Private Initializer

    /// Private initializer with all fields.
    private init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    // MARK: - Factory Constructors (Static Methods)

    /// Construct a rectangle from its left, top, right, and bottom edges.
    ///
    /// **Dart Source:** `geometry.dart:628-632`
    /// **Original:** `const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide equivalent functionality.
    public static func fromLTRB(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Rect {
        Rect(left: left, top: top, right: right, bottom: bottom)
    }

    /// Construct a rectangle from its left and top edges, its width, and its
    /// height.
    ///
    /// To construct a `Rect` from an `Offset` and a `Size`, you can use the
    /// rectangle constructor operator `&`. See `Offset & Size`.
    ///
    /// **Dart Source:** `geometry.dart:634-643`
    /// **Original:** `const Rect.fromLTWH(double left, double top, double width, double height) : this.fromLTRB(left, top, left + width, top + height);`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide equivalent functionality.
    public static func fromLTWH(_ left: Double, _ top: Double, _ width: Double, _ height: Double) -> Rect {
        Rect.fromLTRB(left, top, left + width, top + height)
    }

    /// Construct a rectangle that bounds the given circle.
    ///
    /// The `center` argument is assumed to be an offset from the origin.
    ///
    /// **Dart Source:** `geometry.dart:645-652`
    /// **Original:** `Rect.fromCircle({required Offset center, required double radius}) : this.fromCenter(center: center, width: radius * 2, height: radius * 2);`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide equivalent functionality.
    public static func fromCircle(center: Offset, radius: Double) -> Rect {
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2)
    }

    /// Constructs a rectangle from its center point, width, and height.
    ///
    /// The `center` argument is assumed to be an offset from the origin.
    ///
    /// **Dart Source:** `geometry.dart:654-666`
    /// **Original:**
    /// ```dart
    /// Rect.fromCenter({required Offset center, required double width, required double height})
    ///   : this.fromLTRB(
    ///       center.dx - width / 2,
    ///       center.dy - height / 2,
    ///       center.dx + width / 2,
    ///       center.dy + height / 2,
    ///     );
    /// ```
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide equivalent functionality.
    public static func fromCenter(center: Offset, width: Double, height: Double) -> Rect {
        Rect.fromLTRB(
            center.dx - width / 2,
            center.dy - height / 2,
            center.dx + width / 2,
            center.dy + height / 2
        )
    }

    /// Construct the smallest rectangle that encloses the given offsets, treating
    /// them as vectors from the origin.
    ///
    /// **Dart Source:** `geometry.dart:668-679`
    /// **Original:**
    /// ```dart
    /// Rect.fromPoints(Offset a, Offset b)
    ///   : this.fromLTRB(
    ///       math.min(a.dx, b.dx),
    ///       math.min(a.dy, b.dy),
    ///       math.max(a.dx, b.dx),
    ///       math.max(a.dy, b.dy),
    ///     );
    /// ```
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide equivalent functionality.
    public static func fromPoints(_ a: Offset, _ b: Offset) -> Rect {
        Rect.fromLTRB(
            Swift.min(a.dx, b.dx),
            Swift.min(a.dy, b.dy),
            Swift.max(a.dx, b.dx),
            Swift.max(a.dy, b.dy)
        )
    }

    // MARK: - Static Constants

    /// A rectangle with left, top, right, and bottom edges all at zero.
    ///
    /// **Dart Source:** `geometry.dart:715-716`
    /// **Original:** `static const Rect zero = Rect.fromLTRB(0.0, 0.0, 0.0, 0.0);`
    public static let zero = Rect.fromLTRB(0.0, 0.0, 0.0, 0.0)

    /// Internal constant matching kGiantRect from layer.h.
    ///
    /// **Dart Source:** `geometry.dart:718`
    /// **Original:** `static const double _giantScalar = 1.0E+9;`
    private static let _giantScalar: Double = 1.0e+9

    /// A rectangle that covers the entire coordinate space.
    ///
    /// This covers the space from -1e9,-1e9 to 1e9,1e9.
    /// This is the space over which graphics operations are valid.
    ///
    /// **Dart Source:** `geometry.dart:720-729`
    /// **Original:**
    /// ```dart
    /// static const Rect largest = Rect.fromLTRB(
    ///   -_giantScalar,
    ///   -_giantScalar,
    ///   _giantScalar,
    ///   _giantScalar,
    /// );
    /// ```
    public static let largest = Rect.fromLTRB(
        -_giantScalar,
        -_giantScalar,
        _giantScalar,
        _giantScalar
    )

    // MARK: - Computed Properties

    /// The distance between the left and right edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:702-703`
    /// **Original:** `double get width => right - left;`
    public var width: Double {
        right - left
    }

    /// The distance between the top and bottom edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:705-706`
    /// **Original:** `double get height => bottom - top;`
    public var height: Double {
        bottom - top
    }

    /// The distance between the upper-left corner and the lower-right corner of
    /// this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:708-710`
    /// **Original:** `Size get size => Size(width, height);`
    public var size: Size {
        Size(width, height)
    }

    /// Whether any of the dimensions are `NaN`.
    ///
    /// **Dart Source:** `geometry.dart:712-713`
    /// **Original:** `bool get hasNaN => left.isNaN || top.isNaN || right.isNaN || bottom.isNaN;`
    public var hasNaN: Bool {
        left.isNaN || top.isNaN || right.isNaN || bottom.isNaN
    }

    /// Whether any of the coordinates of this rectangle are equal to positive infinity.
    ///
    /// **Dart Source:** `geometry.dart:731-738`
    /// **Original:**
    /// ```dart
    /// bool get isInfinite {
    ///   return left >= double.infinity ||
    ///       top >= double.infinity ||
    ///       right >= double.infinity ||
    ///       bottom >= double.infinity;
    /// }
    /// ```
    public var isInfinite: Bool {
        left >= .infinity ||
            top >= .infinity ||
            right >= .infinity ||
            bottom >= .infinity
    }

    /// Whether all coordinates of this rectangle are finite.
    ///
    /// **Dart Source:** `geometry.dart:740-741`
    /// **Original:** `bool get isFinite => left.isFinite && top.isFinite && right.isFinite && bottom.isFinite;`
    public var isFinite: Bool {
        left.isFinite && top.isFinite && right.isFinite && bottom.isFinite
    }

    /// Whether this rectangle encloses a non-zero area. Negative areas are
    /// considered empty.
    ///
    /// **Dart Source:** `geometry.dart:743-745`
    /// **Original:** `bool get isEmpty => left >= right || top >= bottom;`
    public var isEmpty: Bool {
        left >= right || top >= bottom
    }

    /// The lesser of the magnitudes of the `width` and the `height` of this
    /// rectangle.
    ///
    /// **Dart Source:** `geometry.dart:812-814`
    /// **Original:** `double get shortestSide => math.min(width.abs(), height.abs());`
    public var shortestSide: Double {
        Swift.min(Swift.abs(width), Swift.abs(height))
    }

    /// The greater of the magnitudes of the `width` and the `height` of this
    /// rectangle.
    ///
    /// **Dart Source:** `geometry.dart:816-818`
    /// **Original:** `double get longestSide => math.max(width.abs(), height.abs());`
    public var longestSide: Double {
        Swift.max(Swift.abs(width), Swift.abs(height))
    }

    /// The offset to the intersection of the top and left edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:820-823`
    /// **Original:** `Offset get topLeft => Offset(left, top);`
    ///
    /// See also `Size.topLeft`.
    public var topLeft: Offset {
        Offset(left, top)
    }

    /// The offset to the center of the top edge of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:825-828`
    /// **Original:** `Offset get topCenter => Offset(left + width / 2.0, top);`
    ///
    /// See also `Size.topCenter`.
    public var topCenter: Offset {
        Offset(left + width / 2.0, top)
    }

    /// The offset to the intersection of the top and right edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:830-833`
    /// **Original:** `Offset get topRight => Offset(right, top);`
    ///
    /// See also `Size.topRight`.
    public var topRight: Offset {
        Offset(right, top)
    }

    /// The offset to the center of the left edge of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:835-838`
    /// **Original:** `Offset get centerLeft => Offset(left, top + height / 2.0);`
    ///
    /// See also `Size.centerLeft`.
    public var centerLeft: Offset {
        Offset(left, top + height / 2.0)
    }

    /// The offset to the point halfway between the left and right and the top and
    /// bottom edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:840-844`
    /// **Original:** `Offset get center => Offset(left + width / 2.0, top + height / 2.0);`
    ///
    /// See also `Size.center`.
    public var center: Offset {
        Offset(left + width / 2.0, top + height / 2.0)
    }

    /// The offset to the center of the right edge of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:846-849`
    /// **Original:** `Offset get centerRight => Offset(right, top + height / 2.0);`
    ///
    /// See also `Size.centerRight`.
    public var centerRight: Offset {
        Offset(right, top + height / 2.0)
    }

    /// The offset to the intersection of the bottom and left edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:851-854`
    /// **Original:** `Offset get bottomLeft => Offset(left, bottom);`
    ///
    /// See also `Size.bottomLeft`.
    public var bottomLeft: Offset {
        Offset(left, bottom)
    }

    /// The offset to the center of the bottom edge of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:856-859`
    /// **Original:** `Offset get bottomCenter => Offset(left + width / 2.0, bottom);`
    ///
    /// See also `Size.bottomCenter`.
    public var bottomCenter: Offset {
        Offset(left + width / 2.0, bottom)
    }

    /// The offset to the intersection of the bottom and right edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:861-864`
    /// **Original:** `Offset get bottomRight => Offset(right, bottom);`
    ///
    /// See also `Size.bottomRight`.
    public var bottomRight: Offset {
        Offset(right, bottom)
    }

    // MARK: - Transformation Methods

    /// Returns a new rectangle translated by the given offset.
    ///
    /// To translate a rectangle by separate x and y components rather than by an
    /// `Offset`, consider `translate`.
    ///
    /// **Dart Source:** `geometry.dart:747-753`
    /// **Original:** `Rect shift(Offset offset) { return Rect.fromLTRB(left + offset.dx, top + offset.dy, right + offset.dx, bottom + offset.dy); }`
    public func shift(_ offset: Offset) -> Rect {
        Rect.fromLTRB(left + offset.dx, top + offset.dy, right + offset.dx, bottom + offset.dy)
    }

    /// Returns a new rectangle with translateX added to the x components and
    /// translateY added to the y components.
    ///
    /// To translate a rectangle by an `Offset` rather than by separate x and y
    /// components, consider `shift`.
    ///
    /// **Dart Source:** `geometry.dart:755-767`
    /// **Original:**
    /// ```dart
    /// Rect translate(double translateX, double translateY) {
    ///   return Rect.fromLTRB(
    ///     left + translateX,
    ///     top + translateY,
    ///     right + translateX,
    ///     bottom + translateY,
    ///   );
    /// }
    /// ```
    public func translate(_ translateX: Double, _ translateY: Double) -> Rect {
        Rect.fromLTRB(
            left + translateX,
            top + translateY,
            right + translateX,
            bottom + translateY
        )
    }

    /// Returns a new rectangle with edges moved outwards by the given delta.
    ///
    /// **Dart Source:** `geometry.dart:769-772`
    /// **Original:** `Rect inflate(double delta) { return Rect.fromLTRB(left - delta, top - delta, right + delta, bottom + delta); }`
    public func inflate(_ delta: Double) -> Rect {
        Rect.fromLTRB(left - delta, top - delta, right + delta, bottom + delta)
    }

    /// Returns a new rectangle with edges moved inwards by the given delta.
    ///
    /// **Dart Source:** `geometry.dart:774-775`
    /// **Original:** `Rect deflate(double delta) => inflate(-delta);`
    public func deflate(_ delta: Double) -> Rect {
        inflate(-delta)
    }

    /// Returns a new rectangle that is the intersection of the given
    /// rectangle and this rectangle. The two rectangles must overlap
    /// for this to be meaningful. If the two rectangles do not overlap,
    /// then the resulting Rect will have a negative width or height.
    ///
    /// **Dart Source:** `geometry.dart:777-788`
    /// **Original:**
    /// ```dart
    /// Rect intersect(Rect other) {
    ///   return Rect.fromLTRB(
    ///     math.max(left, other.left),
    ///     math.max(top, other.top),
    ///     math.min(right, other.right),
    ///     math.min(bottom, other.bottom),
    ///   );
    /// }
    /// ```
    public func intersect(_ other: Rect) -> Rect {
        Rect.fromLTRB(
            Swift.max(left, other.left),
            Swift.max(top, other.top),
            Swift.min(right, other.right),
            Swift.min(bottom, other.bottom)
        )
    }

    /// Returns a new rectangle which is the bounding box containing this
    /// rectangle and the given rectangle.
    ///
    /// **Dart Source:** `geometry.dart:790-799`
    /// **Original:**
    /// ```dart
    /// Rect expandToInclude(Rect other) {
    ///   return Rect.fromLTRB(
    ///     math.min(left, other.left),
    ///     math.min(top, other.top),
    ///     math.max(right, other.right),
    ///     math.max(bottom, other.bottom),
    ///   );
    /// }
    /// ```
    public func expandToInclude(_ other: Rect) -> Rect {
        Rect.fromLTRB(
            Swift.min(left, other.left),
            Swift.min(top, other.top),
            Swift.max(right, other.right),
            Swift.max(bottom, other.bottom)
        )
    }

    /// Whether `other` has a nonzero area of overlap with this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:801-810`
    /// **Original:**
    /// ```dart
    /// bool overlaps(Rect other) {
    ///   if (right <= other.left || other.right <= left) {
    ///     return false;
    ///   }
    ///   if (bottom <= other.top || other.bottom <= top) {
    ///     return false;
    ///   }
    ///   return true;
    /// }
    /// ```
    public func overlaps(_ other: Rect) -> Bool {
        if right <= other.left || other.right <= left {
            return false
        }
        if bottom <= other.top || other.bottom <= top {
            return false
        }
        return true
    }

    /// Whether the point specified by the given offset (which is assumed to be
    /// relative to the origin) lies between the left and right and the top and
    /// bottom edges of this rectangle.
    ///
    /// Rectangles include their top and left edges but exclude their bottom and
    /// right edges.
    ///
    /// **Dart Source:** `geometry.dart:866-874`
    /// **Original:** `bool contains(Offset offset) { return offset.dx >= left && offset.dx < right && offset.dy >= top && offset.dy < bottom; }`
    public func contains(_ offset: Offset) -> Bool {
        offset.dx >= left && offset.dx < right && offset.dy >= top && offset.dy < bottom
    }

    // MARK: - Interpolation

    /// Linearly interpolate between two rectangles.
    ///
    /// If either rect is nil, `Rect.zero` is used as a substitute.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    ///
    /// **Dart Source:** `geometry.dart:876-911`
    /// **Original:**
    /// ```dart
    /// static Rect? lerp(Rect? a, Rect? b, double t) {
    ///   if (b == null) {
    ///     if (a == null) {
    ///       return null;
    ///     } else {
    ///       final double k = 1.0 - t;
    ///       return Rect.fromLTRB(a.left * k, a.top * k, a.right * k, a.bottom * k);
    ///     }
    ///   } else {
    ///     if (a == null) {
    ///       return Rect.fromLTRB(b.left * t, b.top * t, b.right * t, b.bottom * t);
    ///     } else {
    ///       return Rect.fromLTRB(
    ///         _lerpDouble(a.left, b.left, t),
    ///         _lerpDouble(a.top, b.top, t),
    ///         _lerpDouble(a.right, b.right, t),
    ///         _lerpDouble(a.bottom, b.bottom, t),
    ///       );
    ///     }
    ///   }
    /// }
    /// ```
    public static func lerp(_ a: Rect?, _ b: Rect?, _ t: Double) -> Rect? {
        if b == nil {
            if a == nil {
                return nil
            } else {
                let k = 1.0 - t
                return Rect.fromLTRB(a!.left * k, a!.top * k, a!.right * k, a!.bottom * k)
            }
        } else {
            if a == nil {
                return Rect.fromLTRB(b!.left * t, b!.top * t, b!.right * t, b!.bottom * t)
            } else {
                return Rect.fromLTRB(
                    _lerpDouble(a!.left, b!.left, t),
                    _lerpDouble(a!.top, b!.top, t),
                    _lerpDouble(a!.right, b!.right, t),
                    _lerpDouble(a!.bottom, b!.bottom, t)
                )
            }
        }
    }

    // MARK: - Equality & Hashing

    /// Compares two Rects for equality.
    ///
    /// **Dart Source:** `geometry.dart:913-926`
    /// **Original:**
    /// ```dart
    /// @override
    /// bool operator ==(Object other) {
    ///   if (identical(this, other)) {
    ///     return true;
    ///   }
    ///   if (runtimeType != other.runtimeType) {
    ///     return false;
    ///   }
    ///   return other is Rect &&
    ///       other.left == left &&
    ///       other.top == top &&
    ///       other.right == right &&
    ///       other.bottom == bottom;
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Swift's Equatable handles the type check automatically.
    /// REASON: Swift idiom; structs conform to Equatable with synthesized == implementation.
    /// The `identical` check is not needed in Swift since structs are value types.
    public static func == (lhs: Rect, rhs: Rect) -> Bool {
        lhs.left == rhs.left &&
            lhs.top == rhs.top &&
            lhs.right == rhs.right &&
            lhs.bottom == rhs.bottom
    }

    /// Hash code.
    ///
    /// **Dart Source:** `geometry.dart:928-929`
    /// **Original:** `int get hashCode => Object.hash(left, top, right, bottom);`
    ///
    /// DIFFERENCE FROM DART: Using Swift's Hashable protocol.
    /// REASON: Swift idiom for hashing; provides better standard library integration.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(right)
        hasher.combine(bottom)
    }
}

// MARK: - Rect CustomStringConvertible

extension Rect: CustomStringConvertible {
    /// String representation of this rect.
    ///
    /// **Dart Source:** `geometry.dart:931-933`
    /// **Original:** `String toString() => 'Rect.fromLTRB(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, ${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';`
    public var description: String {
        "Rect.fromLTRB(\(String(format: "%.1f", left)), \(String(format: "%.1f", top)), \(String(format: "%.1f", right)), \(String(format: "%.1f", bottom)))"
    }
}

// MARK: - RRectLike Protocol

/// Protocol for rounded rectangle types (RRect, RSuperellipse).
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:1098-1515`
/// **Original Name:** `_RRectLike<T extends _RRectLike<T>>` (abstract class)
///
/// DIFFERENCE FROM DART: Using protocol instead of abstract class with generics.
/// REASON: Swift doesn't have abstract classes; protocol + extension provides equivalent functionality.
/// The CRTP (Curiously Recurring Template Pattern) is replaced with associated type.
public protocol RRectLike: Hashable, CustomStringConvertible {
    /// The offset of the left edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1141`
    var left: Double { get }

    /// The offset of the top edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1144`
    var top: Double { get }

    /// The offset of the right edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1147`
    var right: Double { get }

    /// The offset of the bottom edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1150`
    var bottom: Double { get }

    /// The top-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1153`
    var tlRadiusX: Double { get }

    /// The top-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1156`
    var tlRadiusY: Double { get }

    /// The top-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1162`
    var trRadiusX: Double { get }

    /// The top-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1165`
    var trRadiusY: Double { get }

    /// The bottom-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1171`
    var brRadiusX: Double { get }

    /// The bottom-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1174`
    var brRadiusY: Double { get }

    /// The bottom-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1180`
    var blRadiusX: Double { get }

    /// The bottom-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1183`
    var blRadiusY: Double { get }

    /// Factory method to create an instance with the given parameters.
    /// Used by various methods that construct an object of the same shape.
    ///
    /// **Dart Source:** `geometry.dart:1125-1138`
    /// **Original:** `T _create({...})`
    ///
    /// DIFFERENCE FROM DART: Using static factory method instead of instance method returning Self.
    /// REASON: Swift protocols can't have abstract methods returning Self with complex parameters;
    /// we use a static method pattern instead.
    static func create(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        tlRadiusX: Double,
        tlRadiusY: Double,
        trRadiusX: Double,
        trRadiusY: Double,
        brRadiusX: Double,
        brRadiusY: Double,
        blRadiusX: Double,
        blRadiusY: Double
    ) -> Self

    /// The class name for use in toString().
    /// Subclasses provide their specific class name.
    static var className: String { get }
}

// MARK: - RRectLike Default Implementations

extension RRectLike {
    /// The top-left [Radius].
    ///
    /// **Dart Source:** `geometry.dart:1159`
    /// **Original:** `Radius get tlRadius => Radius.elliptical(tlRadiusX, tlRadiusY);`
    public var tlRadius: Radius {
        Radius(elliptical: tlRadiusX, tlRadiusY)
    }

    /// The top-right [Radius].
    ///
    /// **Dart Source:** `geometry.dart:1168`
    /// **Original:** `Radius get trRadius => Radius.elliptical(trRadiusX, trRadiusY);`
    public var trRadius: Radius {
        Radius(elliptical: trRadiusX, trRadiusY)
    }

    /// The bottom-right [Radius].
    ///
    /// **Dart Source:** `geometry.dart:1177`
    /// **Original:** `Radius get brRadius => Radius.elliptical(brRadiusX, brRadiusY);`
    public var brRadius: Radius {
        Radius(elliptical: brRadiusX, brRadiusY)
    }

    /// The bottom-left [Radius].
    ///
    /// **Dart Source:** `geometry.dart:1186`
    /// **Original:** `Radius get blRadius => Radius.elliptical(blRadiusX, blRadiusY);`
    public var blRadius: Radius {
        Radius(elliptical: blRadiusX, blRadiusY)
    }

    /// Returns a clone translated by the given offset.
    ///
    /// **Dart Source:** `geometry.dart:1189-1204`
    /// **Original:**
    /// ```dart
    /// T shift(Offset offset) {
    ///   return _create(
    ///     left: left + offset.dx,
    ///     top: top + offset.dy,
    ///     ...
    ///   );
    /// }
    /// ```
    public func shift(_ offset: Offset) -> Self {
        Self.create(
            left: left + offset.dx,
            top: top + offset.dy,
            right: right + offset.dx,
            bottom: bottom + offset.dy,
            tlRadiusX: tlRadiusX,
            tlRadiusY: tlRadiusY,
            trRadiusX: trRadiusX,
            trRadiusY: trRadiusY,
            brRadiusX: brRadiusX,
            brRadiusY: brRadiusY,
            blRadiusX: blRadiusX,
            blRadiusY: blRadiusY
        )
    }

    /// Returns a clone with edges and radii moved outwards by the given delta.
    ///
    /// **Dart Source:** `geometry.dart:1208-1223`
    /// **Original:**
    /// ```dart
    /// T inflate(double delta) {
    ///   return _create(
    ///     left: left - delta,
    ///     top: top - delta,
    ///     right: right + delta,
    ///     bottom: bottom + delta,
    ///     tlRadiusX: math.max(0, tlRadiusX + delta),
    ///     ...
    ///   );
    /// }
    /// ```
    public func inflate(_ delta: Double) -> Self {
        Self.create(
            left: left - delta,
            top: top - delta,
            right: right + delta,
            bottom: bottom + delta,
            tlRadiusX: max(0, tlRadiusX + delta),
            tlRadiusY: max(0, tlRadiusY + delta),
            trRadiusX: max(0, trRadiusX + delta),
            trRadiusY: max(0, trRadiusY + delta),
            brRadiusX: max(0, brRadiusX + delta),
            brRadiusY: max(0, brRadiusY + delta),
            blRadiusX: max(0, blRadiusX + delta),
            blRadiusY: max(0, blRadiusY + delta)
        )
    }

    /// Returns a clone with edges and radii moved inwards by the given delta.
    ///
    /// **Dart Source:** `geometry.dart:1226`
    /// **Original:** `T deflate(double delta) => inflate(-delta);`
    public func deflate(_ delta: Double) -> Self {
        inflate(-delta)
    }

    /// The distance between the left and right edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1229`
    /// **Original:** `double get width => right - left;`
    public var width: Double {
        right - left
    }

    /// The distance between the top and bottom edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1232`
    /// **Original:** `double get height => bottom - top;`
    public var height: Double {
        bottom - top
    }

    /// The bounding box of this rounded rectangle (the rectangle with no rounded corners).
    ///
    /// **Dart Source:** `geometry.dart:1235`
    /// **Original:** `Rect get outerRect => Rect.fromLTRB(left, top, right, bottom);`
    public var outerRect: Rect {
        Rect.fromLTRB(left, top, right, bottom)
    }

    /// The non-rounded rectangle that is constrained by the smaller of the two
    /// diagonals, with each diagonal traveling through the middle of the curve
    /// corners. The middle of a corner is the intersection of the curve with its
    /// respective quadrant bisector.
    ///
    /// **Dart Source:** `geometry.dart:1241-1255`
    /// **Original:**
    /// ```dart
    /// Rect get safeInnerRect {
    ///   const double kInsetFactor = 0.29289321881; // 1-cos(pi/4)
    ///   ...
    /// }
    /// ```
    public var safeInnerRect: Rect {
        // 1-cos(pi/4)
        let kInsetFactor: Double = 0.29289321881

        let leftRadius = max(blRadiusX, tlRadiusX)
        let topRadius = max(tlRadiusY, trRadiusY)
        let rightRadius = max(trRadiusX, brRadiusX)
        let bottomRadius = max(brRadiusY, blRadiusY)

        return Rect.fromLTRB(
            left + leftRadius * kInsetFactor,
            top + topRadius * kInsetFactor,
            right - rightRadius * kInsetFactor,
            bottom - bottomRadius * kInsetFactor
        )
    }

    /// The rectangle that would be formed using the axis-aligned intersection of
    /// the sides of the rectangle, i.e., the rectangle formed from the
    /// inner-most centers of the ellipses that form the corners. This is the
    /// intersection of the [wideMiddleRect] and the [tallMiddleRect]. If any of
    /// the intersections are void, the resulting [Rect] will have negative width
    /// or height.
    ///
    /// **Dart Source:** `geometry.dart:1263-1274`
    /// **Original:**
    /// ```dart
    /// Rect get middleRect {
    ///   final double leftRadius = math.max(blRadiusX, tlRadiusX);
    ///   ...
    /// }
    /// ```
    public var middleRect: Rect {
        let leftRadius = max(blRadiusX, tlRadiusX)
        let topRadius = max(tlRadiusY, trRadiusY)
        let rightRadius = max(trRadiusX, brRadiusX)
        let bottomRadius = max(brRadiusY, blRadiusY)
        return Rect.fromLTRB(
            left + leftRadius,
            top + topRadius,
            right - rightRadius,
            bottom - bottomRadius
        )
    }

    /// The biggest rectangle that is entirely inside the rounded rectangle and
    /// has the full width of the rounded rectangle. If the rounded rectangle does
    /// not have an axis-aligned intersection of its left and right side, the
    /// resulting [Rect] will have negative width or height.
    ///
    /// **Dart Source:** `geometry.dart:1280-1283`
    /// **Original:**
    /// ```dart
    /// Rect get wideMiddleRect {
    ///   final double topRadius = math.max(tlRadiusY, trRadiusY);
    ///   final double bottomRadius = math.max(brRadiusY, blRadiusY);
    ///   return Rect.fromLTRB(left, top + topRadius, right, bottom - bottomRadius);
    /// }
    /// ```
    public var wideMiddleRect: Rect {
        let topRadius = max(tlRadiusY, trRadiusY)
        let bottomRadius = max(brRadiusY, blRadiusY)
        return Rect.fromLTRB(left, top + topRadius, right, bottom - bottomRadius)
    }

    /// The biggest rectangle that is entirely inside the rounded rectangle and
    /// has the full height of the rounded rectangle. If the rounded rectangle
    /// does not have an axis-aligned intersection of its top and bottom side, the
    /// resulting [Rect] will have negative width or height.
    ///
    /// **Dart Source:** `geometry.dart:1290-1293`
    /// **Original:**
    /// ```dart
    /// Rect get tallMiddleRect {
    ///   final double leftRadius = math.max(blRadiusX, tlRadiusX);
    ///   final double rightRadius = math.max(trRadiusX, brRadiusX);
    ///   return Rect.fromLTRB(left + leftRadius, top, right - rightRadius, bottom);
    /// }
    /// ```
    public var tallMiddleRect: Rect {
        let leftRadius = max(blRadiusX, tlRadiusX)
        let rightRadius = max(trRadiusX, brRadiusX)
        return Rect.fromLTRB(left + leftRadius, top, right - rightRadius, bottom)
    }

    /// Whether this rounded rectangle encloses a non-zero area.
    /// Negative areas are considered empty.
    ///
    /// **Dart Source:** `geometry.dart:1298`
    /// **Original:** `bool get isEmpty => left >= right || top >= bottom;`
    public var isEmpty: Bool {
        left >= right || top >= bottom
    }

    /// Whether all coordinates of this rounded rectangle are finite.
    ///
    /// **Dart Source:** `geometry.dart:1301`
    /// **Original:** `bool get isFinite => left.isFinite && top.isFinite && right.isFinite && bottom.isFinite;`
    public var isFinite: Bool {
        left.isFinite && top.isFinite && right.isFinite && bottom.isFinite
    }

    /// Whether this rounded rectangle is a simple rectangle with zero
    /// corner radii.
    ///
    /// **Dart Source:** `geometry.dart:1305-1310`
    /// **Original:**
    /// ```dart
    /// bool get isRect {
    ///   return (tlRadiusX == 0.0 || tlRadiusY == 0.0) &&
    ///       (trRadiusX == 0.0 || trRadiusY == 0.0) &&
    ///       (blRadiusX == 0.0 || blRadiusY == 0.0) &&
    ///       (brRadiusX == 0.0 || brRadiusY == 0.0);
    /// }
    /// ```
    public var isRect: Bool {
        (tlRadiusX == 0.0 || tlRadiusY == 0.0) &&
            (trRadiusX == 0.0 || trRadiusY == 0.0) &&
            (blRadiusX == 0.0 || blRadiusY == 0.0) &&
            (brRadiusX == 0.0 || brRadiusY == 0.0)
    }

    /// Whether this rounded rectangle has a side with no straight section.
    ///
    /// **Dart Source:** `geometry.dart:1313-1318`
    /// **Original:**
    /// ```dart
    /// bool get isStadium {
    ///   return tlRadius == trRadius &&
    ///       trRadius == brRadius &&
    ///       brRadius == blRadius &&
    ///       (width <= 2.0 * tlRadiusX || height <= 2.0 * tlRadiusY);
    /// }
    /// ```
    public var isStadium: Bool {
        tlRadius == trRadius &&
            trRadius == brRadius &&
            brRadius == blRadius &&
            (width <= 2.0 * tlRadiusX || height <= 2.0 * tlRadiusY)
    }

    /// Whether this rounded rectangle has no side with a straight section.
    ///
    /// **Dart Source:** `geometry.dart:1321-1327`
    /// **Original:**
    /// ```dart
    /// bool get isEllipse {
    ///   return tlRadius == trRadius &&
    ///       trRadius == brRadius &&
    ///       brRadius == blRadius &&
    ///       width <= 2.0 * tlRadiusX &&
    ///       height <= 2.0 * tlRadiusY;
    /// }
    /// ```
    public var isEllipse: Bool {
        tlRadius == trRadius &&
            trRadius == brRadius &&
            brRadius == blRadius &&
            width <= 2.0 * tlRadiusX &&
            height <= 2.0 * tlRadiusY
    }

    /// Whether this rounded rectangle would draw as a circle.
    ///
    /// **Dart Source:** `geometry.dart:1330`
    /// **Original:** `bool get isCircle => width == height && isEllipse;`
    public var isCircle: Bool {
        width == height && isEllipse
    }

    /// The lesser of the magnitudes of the [width] and the [height] of this
    /// rounded rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1334`
    /// **Original:** `double get shortestSide => math.min(width.abs(), height.abs());`
    public var shortestSide: Double {
        Swift.min(Swift.abs(width), Swift.abs(height))
    }

    /// The greater of the magnitudes of the [width] and the [height] of this
    /// rounded rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1338`
    /// **Original:** `double get longestSide => math.max(width.abs(), height.abs());`
    public var longestSide: Double {
        Swift.max(Swift.abs(width), Swift.abs(height))
    }

    /// Whether any of the dimensions are `NaN`.
    ///
    /// **Dart Source:** `geometry.dart:1341-1353`
    /// **Original:**
    /// ```dart
    /// bool get hasNaN =>
    ///     left.isNaN ||
    ///     top.isNaN ||
    ///     right.isNaN ||
    ///     bottom.isNaN ||
    ///     trRadiusX.isNaN ||
    ///     trRadiusY.isNaN ||
    ///     tlRadiusX.isNaN ||
    ///     tlRadiusY.isNaN ||
    ///     brRadiusX.isNaN ||
    ///     brRadiusY.isNaN ||
    ///     blRadiusX.isNaN ||
    ///     blRadiusY.isNaN;
    /// ```
    public var hasNaN: Bool {
        left.isNaN ||
            top.isNaN ||
            right.isNaN ||
            bottom.isNaN ||
            trRadiusX.isNaN ||
            trRadiusY.isNaN ||
            tlRadiusX.isNaN ||
            tlRadiusY.isNaN ||
            brRadiusX.isNaN ||
            brRadiusY.isNaN ||
            blRadiusX.isNaN ||
            blRadiusY.isNaN
    }

    /// The offset to the point halfway between the left and right and the top and
    /// bottom edges of this rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1357`
    /// **Original:** `Offset get center => Offset(left + width / 2.0, top + height / 2.0);`
    public var center: Offset {
        Offset(left + width / 2.0, top + height / 2.0)
    }

    /// Returns the minimum between min and scale to which radius1 and radius2
    /// should be scaled with in order not to exceed the limit.
    ///
    /// **Dart Source:** `geometry.dart:1361-1367`
    /// **Original:**
    /// ```dart
    /// double _getMin(double min, double radius1, double radius2, double limit) {
    ///   final double sum = radius1 + radius2;
    ///   if (sum > limit && sum != 0.0) {
    ///     return math.min(min, limit / sum);
    ///   }
    ///   return min;
    /// }
    /// ```
    internal func _getMin(_ minValue: Double, _ radius1: Double, _ radius2: Double, _ limit: Double) -> Double {
        let sum = radius1 + radius2
        if sum > limit && sum != 0.0 {
            return min(minValue, limit / sum)
        }
        return minValue
    }

    /// Scales all radii so that on each side their sum will not exceed the size
    /// of the width/height.
    ///
    /// Skia already handles RRects with radii that are too large in this way.
    /// Therefore, this method is only needed for use cases of [RRect] or
    /// [RSuperellipse] that require the appropriately scaled radii values.
    ///
    /// See the [Skia scaling implementation](https://github.com/google/skia/blob/main/src/core/SkRRect.cpp)
    /// for more details.
    ///
    /// **Dart Source:** `geometry.dart:1378-1417`
    /// **Original:**
    /// ```dart
    /// T scaleRadii() {
    ///   double scale = 1.0;
    ///   scale = _getMin(scale, blRadiusY, tlRadiusY, height);
    ///   ...
    /// }
    /// ```
    public func scaleRadii() -> Self {
        var scale: Double = 1.0
        scale = _getMin(scale, blRadiusY, tlRadiusY, height)
        scale = _getMin(scale, tlRadiusX, trRadiusX, width)
        scale = _getMin(scale, trRadiusY, brRadiusY, height)
        scale = _getMin(scale, brRadiusX, blRadiusX, width)
        assert(scale >= 0)

        if scale < 1.0 {
            return Self.create(
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                tlRadiusX: tlRadiusX * scale,
                tlRadiusY: tlRadiusY * scale,
                trRadiusX: trRadiusX * scale,
                trRadiusY: trRadiusY * scale,
                brRadiusX: brRadiusX * scale,
                brRadiusY: brRadiusY * scale,
                blRadiusX: blRadiusX * scale,
                blRadiusY: blRadiusY * scale
            )
        }

        return Self.create(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: tlRadiusX,
            tlRadiusY: tlRadiusY,
            trRadiusX: trRadiusX,
            trRadiusY: trRadiusY,
            brRadiusX: brRadiusX,
            brRadiusY: brRadiusY,
            blRadiusX: blRadiusX,
            blRadiusY: blRadiusY
        )
    }

    /// Linearly interpolate between this object and another of the same shape.
    ///
    /// **Dart Source:** `geometry.dart:1420-1454`
    /// **Original:**
    /// ```dart
    /// T _lerpTo(T? b, double t) {
    ///   assert(runtimeType == T);
    ///   if (b == null) {
    ///     final double k = 1.0 - t;
    ///     return _create(...);
    ///   } else {
    ///     return _create(
    ///       left: _lerpDouble(left, b.left, t),
    ///       ...
    ///     );
    ///   }
    /// }
    /// ```
    internal func _lerpTo(_ b: Self?, _ t: Double) -> Self {
        if let b = b {
            return Self.create(
                left: _lerpDouble(left, b.left, t),
                top: _lerpDouble(top, b.top, t),
                right: _lerpDouble(right, b.right, t),
                bottom: _lerpDouble(bottom, b.bottom, t),
                tlRadiusX: max(0, _lerpDouble(tlRadiusX, b.tlRadiusX, t)),
                tlRadiusY: max(0, _lerpDouble(tlRadiusY, b.tlRadiusY, t)),
                trRadiusX: max(0, _lerpDouble(trRadiusX, b.trRadiusX, t)),
                trRadiusY: max(0, _lerpDouble(trRadiusY, b.trRadiusY, t)),
                brRadiusX: max(0, _lerpDouble(brRadiusX, b.brRadiusX, t)),
                brRadiusY: max(0, _lerpDouble(brRadiusY, b.brRadiusY, t)),
                blRadiusX: max(0, _lerpDouble(blRadiusX, b.blRadiusX, t)),
                blRadiusY: max(0, _lerpDouble(blRadiusY, b.blRadiusY, t))
            )
        } else {
            let k = 1.0 - t
            return Self.create(
                left: left * k,
                top: top * k,
                right: right * k,
                bottom: bottom * k,
                tlRadiusX: max(0, tlRadiusX * k),
                tlRadiusY: max(0, tlRadiusY * k),
                trRadiusX: max(0, trRadiusX * k),
                trRadiusY: max(0, trRadiusY * k),
                brRadiusX: max(0, brRadiusX * k),
                brRadiusY: max(0, brRadiusY * k),
                blRadiusX: max(0, blRadiusX * k),
                blRadiusY: max(0, blRadiusY * k)
            )
        }
    }

    /// Hashable conformance.
    ///
    /// **Dart Source:** `geometry.dart:1480-1493`
    /// **Original:**
    /// ```dart
    /// @override
    /// int get hashCode => Object.hash(
    ///   left, top, right, bottom,
    ///   tlRadiusX, tlRadiusY, trRadiusX, trRadiusY,
    ///   blRadiusX, blRadiusY, brRadiusX, brRadiusY,
    /// );
    /// ```
    ///
    /// DIFFERENCE FROM DART: Using Swift's Hashable protocol.
    /// REASON: Swift idiom for hashing; provides better standard library integration.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(right)
        hasher.combine(bottom)
        hasher.combine(tlRadiusX)
        hasher.combine(tlRadiusY)
        hasher.combine(trRadiusX)
        hasher.combine(trRadiusY)
        hasher.combine(blRadiusX)
        hasher.combine(blRadiusY)
        hasher.combine(brRadiusX)
        hasher.combine(brRadiusY)
    }

    /// String representation using the provided class name.
    ///
    /// **Dart Source:** `geometry.dart:1495-1514`
    /// **Original:**
    /// ```dart
    /// String _toString({required String className}) {
    ///   final String rect = '${left.toStringAsFixed(1)}, ...';
    ///   if (tlRadius == trRadius && trRadius == brRadius && brRadius == blRadius) {
    ///     if (tlRadius.x == tlRadius.y) {
    ///       return '$className.fromLTRBR($rect, ${tlRadius.x.toStringAsFixed(1)})';
    ///     }
    ///     return '$className.fromLTRBXY($rect, ${tlRadius.x.toStringAsFixed(1)}, ${tlRadius.y.toStringAsFixed(1)})';
    ///   }
    ///   return '$className.fromLTRBAndCorners(...)';
    /// }
    /// ```
    internal func _toString(className: String) -> String {
        let rect = "\(String(format: "%.1f", left)), \(String(format: "%.1f", top)), \(String(format: "%.1f", right)), \(String(format: "%.1f", bottom))"
        if tlRadius == trRadius && trRadius == brRadius && brRadius == blRadius {
            if tlRadius.x == tlRadius.y {
                return "\(className).fromLTRBR(\(rect), \(String(format: "%.1f", tlRadius.x)))"
            }
            return "\(className).fromLTRBXY(\(rect), \(String(format: "%.1f", tlRadius.x)), \(String(format: "%.1f", tlRadius.y)))"
        }
        return "\(className).fromLTRBAndCorners(\(rect), topLeft: \(tlRadius), topRight: \(trRadius), bottomRight: \(brRadius), bottomLeft: \(blRadius))"
    }

    /// CustomStringConvertible conformance using the class-specific className.
    public var description: String {
        _toString(className: Self.className)
    }
}

// MARK: - RRectLike Equatable Default Implementation

/// Equality operator for RRectLike types.
///
/// **Dart Source:** `geometry.dart:1457-1477`
/// **Original:**
/// ```dart
/// @override
/// bool operator ==(Object other) {
///   if (identical(this, other)) {
///     return true;
///   }
///   if (runtimeType != other.runtimeType) {
///     return false;
///   }
///   return other is _RRectLike &&
///       other.left == left &&
///       ...
/// }
/// ```
///
/// DIFFERENCE FROM DART: Swift's Equatable handles the type check automatically.
/// REASON: Swift idiom; structs conform to Equatable with synthesized == implementation.
/// The `identical` and `runtimeType` checks are handled by Swift's type system.
public func == <T: RRectLike>(lhs: T, rhs: T) -> Bool {
    lhs.left == rhs.left &&
        lhs.top == rhs.top &&
        lhs.right == rhs.right &&
        lhs.bottom == rhs.bottom &&
        lhs.tlRadiusX == rhs.tlRadiusX &&
        lhs.tlRadiusY == rhs.tlRadiusY &&
        lhs.trRadiusX == rhs.trRadiusX &&
        lhs.trRadiusY == rhs.trRadiusY &&
        lhs.blRadiusX == rhs.blRadiusX &&
        lhs.blRadiusY == rhs.blRadiusY &&
        lhs.brRadiusX == rhs.brRadiusX &&
        lhs.brRadiusY == rhs.brRadiusY
}

// MARK: - RRect

/// An immutable rounded rectangle with custom radii for all four corners.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:1517-1806`
/// **Original Name:** `RRect`
///
/// A rounded rectangle is a rectangle whose corners are quarter-ellipses.
/// The radii of these ellipses can be specified individually, allowing
/// for different rounding amounts on each corner.
public struct RRect: RRectLike, Sendable {
    // MARK: - Stored Properties

    /// The offset of the left edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1141` (inherited from _RRectLike)
    public let left: Double

    /// The offset of the top edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1144` (inherited from _RRectLike)
    public let top: Double

    /// The offset of the right edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1147` (inherited from _RRectLike)
    public let right: Double

    /// The offset of the bottom edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1150` (inherited from _RRectLike)
    public let bottom: Double

    /// The top-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1153` (inherited from _RRectLike)
    public let tlRadiusX: Double

    /// The top-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1156` (inherited from _RRectLike)
    public let tlRadiusY: Double

    /// The top-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1162` (inherited from _RRectLike)
    public let trRadiusX: Double

    /// The top-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1165` (inherited from _RRectLike)
    public let trRadiusY: Double

    /// The bottom-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1171` (inherited from _RRectLike)
    public let brRadiusX: Double

    /// The bottom-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1174` (inherited from _RRectLike)
    public let brRadiusY: Double

    /// The bottom-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1180` (inherited from _RRectLike)
    public let blRadiusX: Double

    /// The bottom-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1183` (inherited from _RRectLike)
    public let blRadiusY: Double

    // MARK: - RRectLike Protocol Conformance

    /// The class name for use in toString().
    ///
    /// **Dart Source:** `geometry.dart:1802-1805`
    public static var className: String { "RRect" }

    /// Factory method to create an RRect instance with the given parameters.
    ///
    /// **Dart Source:** `geometry.dart:1675-1702`
    /// **Original:** `RRect _create({...})`
    public static func create(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        tlRadiusX: Double,
        tlRadiusY: Double,
        trRadiusX: Double,
        trRadiusY: Double,
        brRadiusX: Double,
        brRadiusY: Double,
        blRadiusX: Double,
        blRadiusY: Double
    ) -> RRect {
        RRect(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: tlRadiusX,
            tlRadiusY: tlRadiusY,
            trRadiusX: trRadiusX,
            trRadiusY: trRadiusY,
            brRadiusX: brRadiusX,
            brRadiusY: brRadiusY,
            blRadiusX: blRadiusX,
            blRadiusY: blRadiusY
        )
    }

    // MARK: - Initializers

    /// Raw initializer with all parameters.
    ///
    /// **Dart Source:** `geometry.dart:1660-1673`
    /// **Original:** `const RRect._raw({...})`
    ///
    /// This is the base initializer that all other initializers delegate to.
    public init(
        left: Double = 0.0,
        top: Double = 0.0,
        right: Double = 0.0,
        bottom: Double = 0.0,
        tlRadiusX: Double = 0.0,
        tlRadiusY: Double = 0.0,
        trRadiusX: Double = 0.0,
        trRadiusY: Double = 0.0,
        brRadiusX: Double = 0.0,
        brRadiusY: Double = 0.0,
        blRadiusX: Double = 0.0,
        blRadiusY: Double = 0.0
    ) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
        self.tlRadiusX = tlRadiusX
        self.tlRadiusY = tlRadiusY
        self.trRadiusX = trRadiusX
        self.trRadiusY = trRadiusY
        self.brRadiusX = brRadiusX
        self.brRadiusY = brRadiusY
        self.blRadiusX = blRadiusX
        self.blRadiusY = blRadiusY
    }

    /// Construct a rounded rectangle from its left, top, right, and bottom edges,
    /// and the same radii along its horizontal axis and its vertical axis.
    ///
    /// **Dart Source:** `geometry.dart:1519-1543`
    /// **Original:** `const RRect.fromLTRBXY(...)`
    ///
    /// Will assert in debug mode if `radiusX` or `radiusY` are negative.
    public init(
        fromLTRBXY left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        _ radiusX: Double,
        _ radiusY: Double
    ) {
        assert(radiusX >= 0, "radiusX cannot be negative")
        assert(radiusY >= 0, "radiusY cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: radiusX,
            tlRadiusY: radiusY,
            trRadiusX: radiusX,
            trRadiusY: radiusY,
            brRadiusX: radiusX,
            brRadiusY: radiusY,
            blRadiusX: radiusX,
            blRadiusY: radiusY
        )
    }

    /// Construct a rounded rectangle from its left, top, right, and bottom edges,
    /// and the same radius in each corner.
    ///
    /// **Dart Source:** `geometry.dart:1545-1563`
    /// **Original:** `RRect.fromLTRBR(...)`
    ///
    /// Will assert in debug mode if the `radius` is negative in either x or y.
    public init(
        fromLTRBR left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        _ radius: Radius
    ) {
        assert(radius.x >= 0, "radius.x cannot be negative")
        assert(radius.y >= 0, "radius.y cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: radius.x,
            tlRadiusY: radius.y,
            trRadiusX: radius.x,
            trRadiusY: radius.y,
            brRadiusX: radius.x,
            brRadiusY: radius.y,
            blRadiusX: radius.x,
            blRadiusY: radius.y
        )
    }

    /// Construct a rounded rectangle from its bounding box and the same radii
    /// along its horizontal axis and its vertical axis.
    ///
    /// **Dart Source:** `geometry.dart:1565-1583`
    /// **Original:** `RRect.fromRectXY(...)`
    ///
    /// Will assert in debug mode if `radiusX` or `radiusY` are negative.
    public init(fromRectXY rect: Rect, _ radiusX: Double, _ radiusY: Double) {
        assert(radiusX >= 0, "radiusX cannot be negative")
        assert(radiusY >= 0, "radiusY cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: radiusX,
            tlRadiusY: radiusY,
            trRadiusX: radiusX,
            trRadiusY: radiusY,
            brRadiusX: radiusX,
            brRadiusY: radiusY,
            blRadiusX: radiusX,
            blRadiusY: radiusY
        )
    }

    /// Construct a rounded rectangle from its bounding box and a radius that is
    /// the same in each corner.
    ///
    /// **Dart Source:** `geometry.dart:1585-1603`
    /// **Original:** `RRect.fromRectAndRadius(...)`
    ///
    /// Will assert in debug mode if the `radius` is negative in either x or y.
    public init(fromRectAndRadius rect: Rect, _ radius: Radius) {
        assert(radius.x >= 0, "radius.x cannot be negative")
        assert(radius.y >= 0, "radius.y cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: radius.x,
            tlRadiusY: radius.y,
            trRadiusX: radius.x,
            trRadiusY: radius.y,
            brRadiusX: radius.x,
            brRadiusY: radius.y,
            blRadiusX: radius.x,
            blRadiusY: radius.y
        )
    }

    /// Construct a rounded rectangle from its left, top, right, and bottom edges,
    /// and topLeft, topRight, bottomRight, and bottomLeft radii.
    ///
    /// **Dart Source:** `geometry.dart:1605-1632`
    /// **Original:** `RRect.fromLTRBAndCorners(...)`
    ///
    /// The corner radii default to `Radius.zero`, i.e. right-angled corners. Will
    /// assert in debug mode if any of the radii are negative in either x or y.
    public init(
        fromLTRBAndCorners left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomRight: Radius = .zero,
        bottomLeft: Radius = .zero
    ) {
        assert(topLeft.x >= 0 && topLeft.y >= 0, "topLeft radius cannot be negative")
        assert(topRight.x >= 0 && topRight.y >= 0, "topRight radius cannot be negative")
        assert(bottomRight.x >= 0 && bottomRight.y >= 0, "bottomRight radius cannot be negative")
        assert(bottomLeft.x >= 0 && bottomLeft.y >= 0, "bottomLeft radius cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: topLeft.x,
            tlRadiusY: topLeft.y,
            trRadiusX: topRight.x,
            trRadiusY: topRight.y,
            brRadiusX: bottomRight.x,
            brRadiusY: bottomRight.y,
            blRadiusX: bottomLeft.x,
            blRadiusY: bottomLeft.y
        )
    }

    /// Construct a rounded rectangle from its bounding box and topLeft,
    /// topRight, bottomRight, and bottomLeft radii.
    ///
    /// **Dart Source:** `geometry.dart:1634-1658`
    /// **Original:** `RRect.fromRectAndCorners(...)`
    ///
    /// The corner radii default to `Radius.zero`, i.e. right-angled corners. Will
    /// assert in debug mode if any of the radii are negative in either x or y.
    public init(
        fromRectAndCorners rect: Rect,
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomRight: Radius = .zero,
        bottomLeft: Radius = .zero
    ) {
        assert(topLeft.x >= 0 && topLeft.y >= 0, "topLeft radius cannot be negative")
        assert(topRight.x >= 0 && topRight.y >= 0, "topRight radius cannot be negative")
        assert(bottomRight.x >= 0 && bottomRight.y >= 0, "bottomRight radius cannot be negative")
        assert(bottomLeft.x >= 0 && bottomLeft.y >= 0, "bottomLeft radius cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: topLeft.x,
            tlRadiusY: topLeft.y,
            trRadiusX: topRight.x,
            trRadiusY: topRight.y,
            brRadiusX: bottomRight.x,
            brRadiusY: bottomRight.y,
            blRadiusX: bottomLeft.x,
            blRadiusY: bottomLeft.y
        )
    }

    // MARK: - Static Constants

    /// A rounded rectangle with all the values set to zero.
    ///
    /// **Dart Source:** `geometry.dart:1721-1722`
    /// **Original:** `static const RRect zero = RRect._raw();`
    public static let zero = RRect()

    // MARK: - Methods

    /// Whether the point specified by the given offset lies inside the rounded
    /// rectangle.
    ///
    /// **Dart Source:** `geometry.dart:1724-1775`
    /// **Original:** `bool contains(Offset point) {...}`
    ///
    /// This method may allocate (and cache) a copy of the object with normalized
    /// radii the first time it is called on a particular RRect instance. When
    /// using this method, prefer to reuse existing RRects rather than
    /// recreating the object each time.
    public func contains(_ point: Offset) -> Bool {
        // Check if point is outside the bounding box
        if point.dx < left || point.dx >= right || point.dy < top || point.dy >= bottom {
            return false
        }

        // Scale radii to ensure they fit within the rectangle
        let scaled = scaleRadii()

        var x: Double
        var y: Double
        var radiusX: Double
        var radiusY: Double

        // Check whether point is in one of the rounded corner areas
        // x, y -> translate to ellipse center
        if point.dx < left + scaled.tlRadiusX && point.dy < top + scaled.tlRadiusY {
            // Top-left corner
            x = point.dx - left - scaled.tlRadiusX
            y = point.dy - top - scaled.tlRadiusY
            radiusX = scaled.tlRadiusX
            radiusY = scaled.tlRadiusY
        } else if point.dx > right - scaled.trRadiusX && point.dy < top + scaled.trRadiusY {
            // Top-right corner
            x = point.dx - right + scaled.trRadiusX
            y = point.dy - top - scaled.trRadiusY
            radiusX = scaled.trRadiusX
            radiusY = scaled.trRadiusY
        } else if point.dx > right - scaled.brRadiusX && point.dy > bottom - scaled.brRadiusY {
            // Bottom-right corner
            x = point.dx - right + scaled.brRadiusX
            y = point.dy - bottom + scaled.brRadiusY
            radiusX = scaled.brRadiusX
            radiusY = scaled.brRadiusY
        } else if point.dx < left + scaled.blRadiusX && point.dy > bottom - scaled.blRadiusY {
            // Bottom-left corner
            x = point.dx - left - scaled.blRadiusX
            y = point.dy - bottom + scaled.blRadiusY
            radiusX = scaled.blRadiusX
            radiusY = scaled.blRadiusY
        } else {
            // Inside and not within any rounded corner area
            return true
        }

        // Normalize to unit circle coordinates
        x = x / radiusX
        y = y / radiusY

        // Check if the point is outside the unit circle
        if x * x + y * y > 1.0 {
            return false
        }
        return true
    }

    /// Linearly interpolate between two rounded rectangles.
    ///
    /// **Dart Source:** `geometry.dart:1777-1800`
    /// **Original:** `static RRect? lerp(RRect? a, RRect? b, double t) {...}`
    ///
    /// If either is null, this function substitutes `RRect.zero` instead.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    public static func lerp(_ a: RRect?, _ b: RRect?, _ t: Double) -> RRect? {
        if a == nil {
            if b == nil {
                return nil
            }
            return b!._lerpTo(nil, 1 - t)
        }
        return a!._lerpTo(b, t)
    }

    // MARK: - Hashable

    /// Hash function for use in collections.
    ///
    /// **Dart Source:** `geometry.dart:1480-1493` (inherited from _RRectLike)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(right)
        hasher.combine(bottom)
        hasher.combine(tlRadiusX)
        hasher.combine(tlRadiusY)
        hasher.combine(trRadiusX)
        hasher.combine(trRadiusY)
        hasher.combine(brRadiusX)
        hasher.combine(brRadiusY)
        hasher.combine(blRadiusX)
        hasher.combine(blRadiusY)
    }
}

// MARK: - RSuperellipse

/// An immutable rounded superellipse.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart:1808-2049`
/// **Original Name:** `RSuperellipse`
///
/// A rounded superellipse (not to be confused with a standard superellipse) is
/// a shape formed by replacing the four curved corners of a superellipse with
/// circular arcs. A (standard) superellipse follows the formula x^n + y^n =
/// a^n, and while n > 2 gives it rounded corners, they tend to be too sharp and
/// pronounced. Replacing them with circular arcs makes the shape feel softer
/// and more natural.
///
/// Visually, a rounded superellipse looks similar to a typical rounded rectangle
/// (`RRect`) but with smoother transitions between the straight edges and
/// corners. It closely matches the `RoundedRectangle` shape in SwiftUI with the
/// `.continuous` corner style.
///
/// DIFFERENCE FROM DART: Uses C++ bridge for `contains()` method.
/// REASON: The containment algorithm for RSuperellipse is implemented in C++ engine.
public struct RSuperellipse: RRectLike, Sendable {
    // MARK: - Stored Properties

    /// The offset of the left edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1141` (inherited from _RRectLike)
    public let left: Double

    /// The offset of the top edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1144` (inherited from _RRectLike)
    public let top: Double

    /// The offset of the right edge of this rectangle from the x axis.
    ///
    /// **Dart Source:** `geometry.dart:1147` (inherited from _RRectLike)
    public let right: Double

    /// The offset of the bottom edge of this rectangle from the y axis.
    ///
    /// **Dart Source:** `geometry.dart:1150` (inherited from _RRectLike)
    public let bottom: Double

    /// The top-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1153` (inherited from _RRectLike)
    public let tlRadiusX: Double

    /// The top-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1156` (inherited from _RRectLike)
    public let tlRadiusY: Double

    /// The top-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1162` (inherited from _RRectLike)
    public let trRadiusX: Double

    /// The top-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1165` (inherited from _RRectLike)
    public let trRadiusY: Double

    /// The bottom-right horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1171` (inherited from _RRectLike)
    public let brRadiusX: Double

    /// The bottom-right vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1174` (inherited from _RRectLike)
    public let brRadiusY: Double

    /// The bottom-left horizontal radius.
    ///
    /// **Dart Source:** `geometry.dart:1180` (inherited from _RRectLike)
    public let blRadiusX: Double

    /// The bottom-left vertical radius.
    ///
    /// **Dart Source:** `geometry.dart:1183` (inherited from _RRectLike)
    public let blRadiusY: Double

    // MARK: - RRectLike Protocol Conformance

    /// The class name for use in toString().
    ///
    /// **Dart Source:** `geometry.dart:2045-2048`
    public static var className: String { "RSuperellipse" }

    /// Factory method to create an RSuperellipse instance with the given parameters.
    ///
    /// **Dart Source:** `geometry.dart:1979-2005`
    /// **Original:** `RSuperellipse _create({...})`
    public static func create(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        tlRadiusX: Double,
        tlRadiusY: Double,
        trRadiusX: Double,
        trRadiusY: Double,
        brRadiusX: Double,
        brRadiusY: Double,
        blRadiusX: Double,
        blRadiusY: Double
    ) -> RSuperellipse {
        RSuperellipse(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: tlRadiusX,
            tlRadiusY: tlRadiusY,
            trRadiusX: trRadiusX,
            trRadiusY: trRadiusY,
            brRadiusX: brRadiusX,
            brRadiusY: brRadiusY,
            blRadiusX: blRadiusX,
            blRadiusY: blRadiusY
        )
    }

    // MARK: - Initializers

    /// Raw initializer with all parameters.
    ///
    /// **Dart Source:** `geometry.dart:1963-1976`
    /// **Original:** `const RSuperellipse._raw({...})`
    ///
    /// This is the base initializer that all other initializers delegate to.
    public init(
        left: Double = 0.0,
        top: Double = 0.0,
        right: Double = 0.0,
        bottom: Double = 0.0,
        tlRadiusX: Double = 0.0,
        tlRadiusY: Double = 0.0,
        trRadiusX: Double = 0.0,
        trRadiusY: Double = 0.0,
        brRadiusX: Double = 0.0,
        brRadiusY: Double = 0.0,
        blRadiusX: Double = 0.0,
        blRadiusY: Double = 0.0
    ) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
        self.tlRadiusX = tlRadiusX
        self.tlRadiusY = tlRadiusY
        self.trRadiusX = trRadiusX
        self.trRadiusY = trRadiusY
        self.brRadiusX = brRadiusX
        self.brRadiusY = brRadiusY
        self.blRadiusX = blRadiusX
        self.blRadiusY = blRadiusY
    }

    /// Construct a rounded superellipse from its left, top, right, and bottom edges,
    /// and the same radii along its horizontal axis and its vertical axis.
    ///
    /// **Dart Source:** `geometry.dart:1822-1846`
    /// **Original:** `const RSuperellipse.fromLTRBXY(...)`
    ///
    /// Will assert in debug mode if `radiusX` or `radiusY` are negative.
    public init(
        fromLTRBXY left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        _ radiusX: Double,
        _ radiusY: Double
    ) {
        assert(radiusX >= 0, "radiusX cannot be negative")
        assert(radiusY >= 0, "radiusY cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: radiusX,
            tlRadiusY: radiusY,
            trRadiusX: radiusX,
            trRadiusY: radiusY,
            brRadiusX: radiusX,
            brRadiusY: radiusY,
            blRadiusX: radiusX,
            blRadiusY: radiusY
        )
    }

    /// Construct a rounded superellipse from its left, top, right, and bottom edges,
    /// and the same radius in each corner.
    ///
    /// **Dart Source:** `geometry.dart:1848-1866`
    /// **Original:** `RSuperellipse.fromLTRBR(...)`
    ///
    /// Will assert in debug mode if the `radius` is negative in either x or y.
    public init(
        fromLTRBR left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        _ radius: Radius
    ) {
        assert(radius.x >= 0, "radius.x cannot be negative")
        assert(radius.y >= 0, "radius.y cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: radius.x,
            tlRadiusY: radius.y,
            trRadiusX: radius.x,
            trRadiusY: radius.y,
            brRadiusX: radius.x,
            brRadiusY: radius.y,
            blRadiusX: radius.x,
            blRadiusY: radius.y
        )
    }

    /// Construct a rounded superellipse from its bounding box and the same radii
    /// along its horizontal axis and its vertical axis.
    ///
    /// **Dart Source:** `geometry.dart:1868-1886`
    /// **Original:** `RSuperellipse.fromRectXY(...)`
    ///
    /// Will assert in debug mode if `radiusX` or `radiusY` are negative.
    public init(
        fromRectXY rect: Rect,
        _ radiusX: Double,
        _ radiusY: Double
    ) {
        assert(radiusX >= 0, "radiusX cannot be negative")
        assert(radiusY >= 0, "radiusY cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: radiusX,
            tlRadiusY: radiusY,
            trRadiusX: radiusX,
            trRadiusY: radiusY,
            brRadiusX: radiusX,
            brRadiusY: radiusY,
            blRadiusX: radiusX,
            blRadiusY: radiusY
        )
    }

    /// Construct a rounded superellipse from its bounding box and a radius that is
    /// the same in each corner.
    ///
    /// **Dart Source:** `geometry.dart:1888-1906`
    /// **Original:** `RSuperellipse.fromRectAndRadius(...)`
    ///
    /// Will assert in debug mode if the `radius` is negative in either x or y.
    public init(
        fromRectAndRadius rect: Rect,
        _ radius: Radius
    ) {
        assert(radius.x >= 0, "radius.x cannot be negative")
        assert(radius.y >= 0, "radius.y cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: radius.x,
            tlRadiusY: radius.y,
            trRadiusX: radius.x,
            trRadiusY: radius.y,
            brRadiusX: radius.x,
            brRadiusY: radius.y,
            blRadiusX: radius.x,
            blRadiusY: radius.y
        )
    }

    /// Construct a rounded superellipse from its left, top, right, and bottom edges,
    /// and topLeft, topRight, bottomRight, and bottomLeft radii.
    ///
    /// **Dart Source:** `geometry.dart:1908-1935`
    /// **Original:** `RSuperellipse.fromLTRBAndCorners(...)`
    ///
    /// The corner radii default to `Radius.zero`, i.e. right-angled corners. Will
    /// assert in debug mode if any of the radii are negative in either x or y.
    public init(
        fromLTRBAndCorners left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double,
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomRight: Radius = .zero,
        bottomLeft: Radius = .zero
    ) {
        assert(topLeft.x >= 0 && topLeft.y >= 0, "topLeft radius cannot be negative")
        assert(topRight.x >= 0 && topRight.y >= 0, "topRight radius cannot be negative")
        assert(bottomRight.x >= 0 && bottomRight.y >= 0, "bottomRight radius cannot be negative")
        assert(bottomLeft.x >= 0 && bottomLeft.y >= 0, "bottomLeft radius cannot be negative")
        self.init(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            tlRadiusX: topLeft.x,
            tlRadiusY: topLeft.y,
            trRadiusX: topRight.x,
            trRadiusY: topRight.y,
            brRadiusX: bottomRight.x,
            brRadiusY: bottomRight.y,
            blRadiusX: bottomLeft.x,
            blRadiusY: bottomLeft.y
        )
    }

    /// Construct a rounded superellipse from its bounding box and topLeft,
    /// topRight, bottomRight, and bottomLeft radii.
    ///
    /// **Dart Source:** `geometry.dart:1937-1961`
    /// **Original:** `RSuperellipse.fromRectAndCorners(...)`
    ///
    /// The corner radii default to `Radius.zero`, i.e. right-angled corners. Will
    /// assert in debug mode if any of the radii are negative in either x or y.
    public init(
        fromRectAndCorners rect: Rect,
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomRight: Radius = .zero,
        bottomLeft: Radius = .zero
    ) {
        assert(topLeft.x >= 0 && topLeft.y >= 0, "topLeft radius cannot be negative")
        assert(topRight.x >= 0 && topRight.y >= 0, "topRight radius cannot be negative")
        assert(bottomRight.x >= 0 && bottomRight.y >= 0, "bottomRight radius cannot be negative")
        assert(bottomLeft.x >= 0 && bottomLeft.y >= 0, "bottomLeft radius cannot be negative")
        self.init(
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            tlRadiusX: topLeft.x,
            tlRadiusY: topLeft.y,
            trRadiusX: topRight.x,
            trRadiusY: topRight.y,
            brRadiusX: bottomRight.x,
            brRadiusY: bottomRight.y,
            blRadiusX: bottomLeft.x,
            blRadiusY: bottomLeft.y
        )
    }

    // MARK: - Static Constants

    /// A rounded superellipse with all the values set to zero.
    ///
    /// **Dart Source:** `geometry.dart:2017-2018`
    /// **Original:** `static const RSuperellipse zero = RSuperellipse._raw();`
    public static let zero = RSuperellipse()

    // MARK: - Contains

    /// Whether the point specified by the given offset (which is assumed to be
    /// relative to the origin) lies inside the rounded superellipse.
    ///
    /// **Dart Source:** `geometry.dart:2011-2015`
    /// **Original:**
    /// ```dart
    /// bool contains(Offset point) {
    ///   return _native().contains(point);
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Uses C++ bridge directly instead of _NativeRSuperellipse wrapper.
    /// REASON: Swift directly calls the C++ bridge for the containment check algorithm.
    public func contains(_ point: Offset) -> Bool {
        let bridge = flutter.swift_bridge.RSuperellipseBridge(
            left, top, right, bottom,
            tlRadiusX, tlRadiusY,
            trRadiusX, trRadiusY,
            brRadiusX, brRadiusY,
            blRadiusX, blRadiusY
        )
        return bridge.Contains(point.dx, point.dy)
    }

    // MARK: - Interpolation

    /// Linearly interpolate between two rounded superellipses.
    ///
    /// **Dart Source:** `geometry.dart:2020-2043`
    /// **Original:** `static RSuperellipse? lerp(RSuperellipse? a, RSuperellipse? b, double t) {...}`
    ///
    /// If either is null, this function substitutes `RSuperellipse.zero` instead.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<double>`, such as
    /// an `AnimationController`.
    public static func lerp(_ a: RSuperellipse?, _ b: RSuperellipse?, _ t: Double) -> RSuperellipse? {
        if a == nil {
            if b == nil {
                return nil
            }
            return b!._lerpTo(nil, 1 - t)
        }
        return a!._lerpTo(b, t)
    }

    // MARK: - Hashable

    /// Hash function for use in collections.
    ///
    /// **Dart Source:** `geometry.dart:1480-1493` (inherited from _RRectLike)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(right)
        hasher.combine(bottom)
        hasher.combine(tlRadiusX)
        hasher.combine(tlRadiusY)
        hasher.combine(trRadiusX)
        hasher.combine(trRadiusY)
        hasher.combine(brRadiusX)
        hasher.combine(brRadiusY)
        hasher.combine(blRadiusX)
        hasher.combine(blRadiusY)
    }
}

// MARK: - NativeRSuperellipse

/// Native wrapper class for RSuperellipse containment checks.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/geometry.dart`
/// **Original Name:** `_NativeRSuperellipse`
/// **Lines:** 2051-2110
///
/// This class wraps the C++ RSuperellipseBridge to provide the containment
/// check algorithm for RSuperellipse. In Dart, this class extends
/// `NativeFieldWrapperClass1` and uses `@Native` annotations for FFI.
///
/// DIFFERENCE FROM DART: In Dart, `_NativeRSuperellipse` extends `NativeFieldWrapperClass1`
/// which is a Dart VM wrapper class for native objects. In Swift, we directly wrap the
/// C++ bridge class `RSuperellipseBridge` using Swift's native C++ interoperability.
/// REASON: Swift 6 can directly interoperate with C++ via SWIFT_SHARED_REFERENCE,
/// eliminating the need for Dart VM FFI mechanisms.
public final class NativeRSuperellipse: @unchecked Sendable {

    /// The underlying C++ bridge object.
    private let bridge: flutter.swift_bridge.RSuperellipseBridge

    /// Creates a native RSuperellipse wrapper from an RSuperellipse.
    ///
    /// **Dart Source:** `geometry.dart:2052-2067`
    /// **Original:**
    /// ```dart
    /// _NativeRSuperellipse(RSuperellipse rsuperellipse) {
    ///   _constructor(
    ///     rsuperellipse.left,
    ///     rsuperellipse.top,
    ///     rsuperellipse.right,
    ///     rsuperellipse.bottom,
    ///     rsuperellipse.tlRadiusX,
    ///     rsuperellipse.tlRadiusY,
    ///     rsuperellipse.trRadiusX,
    ///     rsuperellipse.trRadiusY,
    ///     rsuperellipse.brRadiusX,
    ///     rsuperellipse.brRadiusY,
    ///     rsuperellipse.blRadiusX,
    ///     rsuperellipse.blRadiusY,
    ///   );
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: Dart calls `_constructor` which is a native method annotated
    /// with `@Native<...>(symbol: 'RSuperellipse::Create')`. In Swift, we directly
    /// construct the C++ `RSuperellipseBridge` which internally calls the same engine code.
    /// REASON: Swift 6 C++ interop allows direct C++ class construction.
    public init(_ rsuperellipse: RSuperellipse) {
        self.bridge = flutter.swift_bridge.RSuperellipseBridge(
            rsuperellipse.left,
            rsuperellipse.top,
            rsuperellipse.right,
            rsuperellipse.bottom,
            rsuperellipse.tlRadiusX,
            rsuperellipse.tlRadiusY,
            rsuperellipse.trRadiusX,
            rsuperellipse.trRadiusY,
            rsuperellipse.brRadiusX,
            rsuperellipse.brRadiusY,
            rsuperellipse.blRadiusX,
            rsuperellipse.blRadiusY
        )
    }

    /// Whether the point lies inside the rounded superellipse.
    ///
    /// **Dart Source:** `geometry.dart:2101-2103`
    /// **Original:**
    /// ```dart
    /// bool contains(Offset point) {
    ///   return _contains(point.dx, point.dy);
    /// }
    /// ```
    ///
    /// The underlying `_contains` method is annotated with:
    /// ```dart
    /// @Native<Bool Function(Pointer<Void>, Double, Double)>(
    ///   symbol: 'RSuperellipse::contains',
    ///   isLeaf: true,
    /// )
    /// external bool _contains(double x, double y);
    /// ```
    ///
    /// DIFFERENCE FROM DART: Dart uses `@Native` annotation with `isLeaf: true` for
    /// efficient native calls. In Swift, we call the C++ bridge's `Contains` method
    /// directly, which provides equivalent functionality.
    /// REASON: Swift 6 C++ interop eliminates the need for FFI annotations.
    public func contains(_ point: Offset) -> Bool {
        return bridge.Contains(point.dx, point.dy)
    }
}
