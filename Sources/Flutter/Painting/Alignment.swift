// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Alignment types for positioning content.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/alignment.dart`

import FlutterSwiftBridge

// MARK: - AlignmentGeometry

/// Base protocol for alignment types that allows for text-direction aware resolution.
///
/// A property or argument of this type accepts classes created either with
/// `Alignment` and its variants, or `AlignmentDirectional`.
///
/// To convert an `AlignmentGeometry` object of indeterminate type into an
/// `Alignment` object, call the `resolve` method.
///
/// **Dart Source:** `alignment.dart:24-211`
public protocol AlignmentGeometry: Hashable, CustomStringConvertible {
    /// The x component of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:99`
    var _x: Double { get }

    /// The start component of this alignment (for RTL-aware positioning).
    ///
    /// **Dart Source:** `alignment.dart:101`
    var _start: Double { get }

    /// The y component of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:103`
    var _y: Double { get }

    /// Convert this instance into an `Alignment`, which uses literal
    /// coordinates (the `x` coordinate being explicitly a distance from the
    /// left).
    ///
    /// **Dart Source:** `alignment.dart:182-191`
    func resolve(_ direction: TextDirection?) -> Alignment
}

// MARK: - AlignmentGeometry Extension

extension AlignmentGeometry {
    /// Returns the sum of two `AlignmentGeometry` objects.
    ///
    /// If you know you are adding two `Alignment` or two `AlignmentDirectional`
    /// objects, consider using the `+` operator instead, which always returns an
    /// object of the same type as the operands, and is typed accordingly.
    ///
    /// If `add` is applied to two objects of the same type (`Alignment` or
    /// `AlignmentDirectional`), an object of that type will be returned (though
    /// this is not reflected in the type system). Otherwise, an object
    /// representing a combination of both is returned. That object can be turned
    /// into a concrete `Alignment` using `resolve`.
    ///
    /// **Dart Source:** `alignment.dart:105-118`
    public func add(_ other: any AlignmentGeometry) -> MixedAlignment {
        MixedAlignment(_x + other._x, _start + other._start, _y + other._y)
    }

    /// Default `description` implementation based on Dart's `toString()`.
    ///
    /// **Dart Source:** `alignment.dart:193-202`
    public var description: String {
        if _start == 0.0 {
            return Alignment._stringify(_x, _y)
        }
        if _x == 0.0 {
            return AlignmentDirectional._stringify(_start, _y)
        }
        return "\(Alignment._stringify(_x, _y)) + \(AlignmentDirectional._stringify(_start, 0.0))"
    }

    /// Default `hashValue` implementation.
    ///
    /// **Dart Source:** `alignment.dart:209-210`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_x)
        hasher.combine(_start)
        hasher.combine(_y)
    }
}

/// Default equality implementation for AlignmentGeometry.
///
/// **Dart Source:** `alignment.dart:204-207`
public func == (lhs: any AlignmentGeometry, rhs: any AlignmentGeometry) -> Bool {
    lhs._x == rhs._x && lhs._start == rhs._start && lhs._y == rhs._y
}

// MARK: - AlignmentGeometry Static Methods

/// Extension providing static methods for `AlignmentGeometry`.
///
/// **Note:** In Swift, protocols cannot have static stored properties or factory
/// constructors. These are provided as free functions or through a namespace type.
public enum AlignmentGeometryStatics {
    /// Linearly interpolate between two `AlignmentGeometry` objects.
    ///
    /// If either is null, this function interpolates from `Alignment.center`, and
    /// the result is an object of the same type as the non-null argument.
    ///
    /// If `lerp` is applied to two objects of the same type (`Alignment` or
    /// `AlignmentDirectional`), an object of that type will be returned (though
    /// this is not reflected in the type system). Otherwise, an object
    /// representing a combination of both is returned. That object can be turned
    /// into a concrete `Alignment` using `resolve`.
    ///
    /// **Dart Source:** `alignment.dart:147-180`
    public static func lerp(
        _ a: (any AlignmentGeometry)?,
        _ b: (any AlignmentGeometry)?,
        _ t: Double
    ) -> (any AlignmentGeometry)? {
        // If both are identical (same object), return a
        if let aVal = a, let bVal = b,
           aVal._x == bVal._x && aVal._start == bVal._start && aVal._y == bVal._y {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            // Create result by scaling b by t
            return MixedAlignment(b._x * t, b._start * t, b._y * t)
        }
        if b == nil {
            guard let a = a else { return nil }
            // Create result by scaling a by (1 - t)
            return MixedAlignment(a._x * (1.0 - t), a._start * (1.0 - t), a._y * (1.0 - t))
        }
        guard let a = a, let b = b else { return nil }

        // Check if both are Alignment
        if let aAlignment = a as? Alignment, let bAlignment = b as? Alignment {
            return Alignment.lerp(aAlignment, bAlignment, t)
        }
        // Check if both are AlignmentDirectional
        if let aDir = a as? AlignmentDirectional, let bDir = b as? AlignmentDirectional {
            return AlignmentDirectional.lerp(aDir, bDir, t)
        }
        // Mixed case - use MixedAlignment
        return MixedAlignment(
            lerpDouble(a._x, b._x, t)!,
            lerpDouble(a._start, b._start, t)!,
            lerpDouble(a._y, b._y, t)!
        )
    }
}

// MARK: - MixedAlignment

/// A mixed alignment that combines both `Alignment` (x-based) and
/// `AlignmentDirectional` (start-based) components.
///
/// This is an internal type used when adding or lerping between `Alignment`
/// and `AlignmentDirectional` objects.
///
/// **Dart Source:** `alignment.dart:614-663`
public struct MixedAlignment: AlignmentGeometry, Sendable {
    /// The x component.
    ///
    /// **Dart Source:** `alignment.dart:617-618`
    public let _x: Double

    /// The start component.
    ///
    /// **Dart Source:** `alignment.dart:620-621`
    public let _start: Double

    /// The y component.
    ///
    /// **Dart Source:** `alignment.dart:623-624`
    public let _y: Double

    /// Creates a mixed alignment with the given components.
    ///
    /// **Dart Source:** `alignment.dart:615`
    public init(_ x: Double, _ start: Double, _ y: Double) {
        self._x = x
        self._start = start
        self._y = y
    }

    // MARK: - Operators

    /// Returns the negation of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:626-629`
    public static prefix func - (alignment: MixedAlignment) -> MixedAlignment {
        MixedAlignment(-alignment._x, -alignment._start, -alignment._y)
    }

    /// Scales this alignment by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:631-634`
    public static func * (lhs: MixedAlignment, rhs: Double) -> MixedAlignment {
        MixedAlignment(lhs._x * rhs, lhs._start * rhs, lhs._y * rhs)
    }

    /// Divides this alignment by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:636-639`
    public static func / (lhs: MixedAlignment, rhs: Double) -> MixedAlignment {
        MixedAlignment(lhs._x / rhs, lhs._start / rhs, lhs._y / rhs)
    }

    /// Integer divides this alignment by the given factor.
    ///
    /// Swift does not have the `~/` operator, so this is provided as a method.
    ///
    /// **Dart Source:** `alignment.dart:641-648`
    public func truncatingDivision(_ other: Double) -> MixedAlignment {
        MixedAlignment(
            Double(Int(_x / other)),
            Double(Int(_start / other)),
            Double(Int(_y / other))
        )
    }

    /// Computes the remainder in each dimension.
    ///
    /// **Dart Source:** `alignment.dart:650-653`
    public static func % (lhs: MixedAlignment, rhs: Double) -> MixedAlignment {
        MixedAlignment(lhs._x.truncatingRemainder(dividingBy: rhs),
                       lhs._start.truncatingRemainder(dividingBy: rhs),
                       lhs._y.truncatingRemainder(dividingBy: rhs))
    }

    /// Resolves this alignment to a concrete `Alignment` based on the given text direction.
    ///
    /// **Dart Source:** `alignment.dart:655-662`
    public func resolve(_ direction: TextDirection?) -> Alignment {
        debugCheckCanResolveTextDirection(direction, "MixedAlignment")
        switch direction! {
        case .rtl:
            return Alignment(_x - _start, _y)
        case .ltr:
            return Alignment(_x + _start, _y)
        }
    }
}

// MARK: - Alignment

/// A point within a rectangle.
///
/// `Alignment(0.0, 0.0)` represents the center of the rectangle. The distance
/// from -1.0 to +1.0 is the distance from one side of the rectangle to the
/// other side of the rectangle. Therefore, 2.0 units horizontally (or
/// vertically) is equivalent to the width (or height) of the rectangle.
///
/// `Alignment(-1.0, -1.0)` represents the top left of the rectangle.
///
/// `Alignment(1.0, 1.0)` represents the bottom right of the rectangle.
///
/// `Alignment(0.0, 3.0)` represents a point that is horizontally centered with
/// respect to the rectangle and vertically below the bottom of the rectangle by
/// the height of the rectangle.
///
/// `Alignment(0.0, -0.5)` represents a point that is horizontally centered with
/// respect to the rectangle and vertically half way between the top edge and
/// the center.
///
/// `Alignment(x, y)` in a rectangle with height h and width w describes
/// the point (x * w/2 + w/2, y * h/2 + h/2) in the coordinate system of the
/// rectangle.
///
/// `Alignment` uses visual coordinates, which means increasing `x` moves the
/// point from left to right. To support layouts with a right-to-left
/// `TextDirection`, consider using `AlignmentDirectional`, in which the
/// direction the point moves when increasing the horizontal value depends on
/// the `TextDirection`.
///
/// **Dart Source:** `alignment.dart:253-434`
public struct Alignment: AlignmentGeometry, Sendable {
    /// The distance fraction in the horizontal direction.
    ///
    /// A value of -1.0 corresponds to the leftmost edge. A value of 1.0
    /// corresponds to the rightmost edge. Values are not limited to that range;
    /// values less than -1.0 represent positions to the left of the left edge,
    /// and values greater than 1.0 represent positions to the right of the right
    /// edge.
    ///
    /// **Dart Source:** `alignment.dart:257-264`
    public let x: Double

    /// The distance fraction in the vertical direction.
    ///
    /// A value of -1.0 corresponds to the topmost edge. A value of 1.0
    /// corresponds to the bottommost edge. Values are not limited to that range;
    /// values less than -1.0 represent positions above the top, and values
    /// greater than 1.0 represent positions below the bottom.
    ///
    /// **Dart Source:** `alignment.dart:266-272`
    public let y: Double

    /// Creates an alignment.
    ///
    /// **Dart Source:** `alignment.dart:254-255`
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    // MARK: - AlignmentGeometry Protocol

    /// **Dart Source:** `alignment.dart:274-275`
    public var _x: Double { x }

    /// **Dart Source:** `alignment.dart:277-278`
    public var _start: Double { 0.0 }

    /// **Dart Source:** `alignment.dart:280-281`
    public var _y: Double { y }

    // MARK: - Static Constants

    /// The top left corner.
    ///
    /// **Dart Source:** `alignment.dart:283-284`
    public static let topLeft = Alignment(-1.0, -1.0)

    /// The center point along the top edge.
    ///
    /// **Dart Source:** `alignment.dart:286-287`
    public static let topCenter = Alignment(0.0, -1.0)

    /// The top right corner.
    ///
    /// **Dart Source:** `alignment.dart:289-290`
    public static let topRight = Alignment(1.0, -1.0)

    /// The center point along the left edge.
    ///
    /// **Dart Source:** `alignment.dart:292-293`
    public static let centerLeft = Alignment(-1.0, 0.0)

    /// The center point, both horizontally and vertically.
    ///
    /// **Dart Source:** `alignment.dart:295-296`
    public static let center = Alignment(0.0, 0.0)

    /// The center point along the right edge.
    ///
    /// **Dart Source:** `alignment.dart:298-299`
    public static let centerRight = Alignment(1.0, 0.0)

    /// The bottom left corner.
    ///
    /// **Dart Source:** `alignment.dart:301-302`
    public static let bottomLeft = Alignment(-1.0, 1.0)

    /// The center point along the bottom edge.
    ///
    /// **Dart Source:** `alignment.dart:304-305`
    public static let bottomCenter = Alignment(0.0, 1.0)

    /// The bottom right corner.
    ///
    /// **Dart Source:** `alignment.dart:307-308`
    public static let bottomRight = Alignment(1.0, 1.0)

    // MARK: - Add Method Override

    /// Returns the sum of two `AlignmentGeometry` objects.
    ///
    /// If `other` is an `Alignment`, returns an `Alignment`.
    /// Otherwise, returns a `MixedAlignment`.
    ///
    /// **Dart Source:** `alignment.dart:310-316`
    public func add(_ other: any AlignmentGeometry) -> any AlignmentGeometry {
        if let otherAlignment = other as? Alignment {
            return self + otherAlignment
        }
        return MixedAlignment(_x + other._x, _start + other._start, _y + other._y)
    }

    // MARK: - Operators

    /// Returns the difference between two `Alignment`s.
    ///
    /// **Dart Source:** `alignment.dart:318-321`
    public static func - (lhs: Alignment, rhs: Alignment) -> Alignment {
        Alignment(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    /// Returns the sum of two `Alignment`s.
    ///
    /// **Dart Source:** `alignment.dart:323-326`
    public static func + (lhs: Alignment, rhs: Alignment) -> Alignment {
        Alignment(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    /// Returns the negation of the given `Alignment`.
    ///
    /// **Dart Source:** `alignment.dart:328-332`
    public static prefix func - (alignment: Alignment) -> Alignment {
        Alignment(-alignment.x, -alignment.y)
    }

    /// Scales the `Alignment` in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:334-338`
    public static func * (lhs: Alignment, rhs: Double) -> Alignment {
        Alignment(lhs.x * rhs, lhs.y * rhs)
    }

    /// Divides the `Alignment` in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:340-344`
    public static func / (lhs: Alignment, rhs: Double) -> Alignment {
        Alignment(lhs.x / rhs, lhs.y / rhs)
    }

    /// Integer divides the `Alignment` in each dimension by the given factor.
    ///
    /// Swift does not have the `~/` operator, so this is provided as a method.
    ///
    /// **Dart Source:** `alignment.dart:346-350`
    public func truncatingDivision(_ other: Double) -> Alignment {
        Alignment(Double(Int(x / other)), Double(Int(y / other)))
    }

    /// Computes the remainder in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:352-356`
    public static func % (lhs: Alignment, rhs: Double) -> Alignment {
        Alignment(lhs.x.truncatingRemainder(dividingBy: rhs),
                  lhs.y.truncatingRemainder(dividingBy: rhs))
    }

    // MARK: - Geometry Methods

    /// Returns the offset that is this fraction in the direction of the given offset.
    ///
    /// **Dart Source:** `alignment.dart:358-363`
    public func alongOffset(_ other: Offset) -> Offset {
        let centerX = other.dx / 2.0
        let centerY = other.dy / 2.0
        return Offset(centerX + x * centerX, centerY + y * centerY)
    }

    /// Returns the offset that is this fraction within the given size.
    ///
    /// **Dart Source:** `alignment.dart:365-370`
    public func alongSize(_ other: Size) -> Offset {
        let centerX = other.width / 2.0
        let centerY = other.height / 2.0
        return Offset(centerX + x * centerX, centerY + y * centerY)
    }

    /// Returns the point that is this fraction within the given rect.
    ///
    /// **Dart Source:** `alignment.dart:372-377`
    public func withinRect(_ rect: Rect) -> Offset {
        let halfWidth = rect.width / 2.0
        let halfHeight = rect.height / 2.0
        return Offset(rect.left + halfWidth + x * halfWidth,
                      rect.top + halfHeight + y * halfHeight)
    }

    /// Returns a rect of the given size, aligned within given rect as specified
    /// by this alignment.
    ///
    /// For example, a 100x100 size inscribed on a 200x200 rect using
    /// `Alignment.topLeft` would be the 100x100 rect at the top left of
    /// the 200x200 rect.
    ///
    /// **Dart Source:** `alignment.dart:379-394`
    public func inscribe(_ size: Size, _ rect: Rect) -> Rect {
        let halfWidthDelta = (rect.width - size.width) / 2.0
        let halfHeightDelta = (rect.height - size.height) / 2.0
        return Rect.fromLTWH(
            rect.left + halfWidthDelta + x * halfWidthDelta,
            rect.top + halfHeightDelta + y * halfHeightDelta,
            size.width,
            size.height
        )
    }

    // MARK: - Lerp

    /// Linearly interpolate between two `Alignment`s.
    ///
    /// If either is null, this function interpolates from `Alignment.center`.
    ///
    /// **Dart Source:** `alignment.dart:396-412`
    public static func lerp(_ a: Alignment?, _ b: Alignment?, _ t: Double) -> Alignment? {
        if let a = a, let b = b, a.x == b.x && a.y == b.y {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return Alignment(lerpDouble(0.0, b.x, t)!, lerpDouble(0.0, b.y, t)!)
        }
        if b == nil {
            guard let a = a else { return nil }
            return Alignment(lerpDouble(a.x, 0.0, t)!, lerpDouble(a.y, 0.0, t)!)
        }
        guard let a = a, let b = b else { return nil }
        return Alignment(lerpDouble(a.x, b.x, t)!, lerpDouble(a.y, b.y, t)!)
    }

    // MARK: - Resolve

    /// Returns this alignment unchanged.
    ///
    /// `Alignment` does not depend on text direction, so resolving always
    /// returns self.
    ///
    /// **Dart Source:** `alignment.dart:414-415`
    public func resolve(_ direction: TextDirection?) -> Alignment {
        self
    }

    // MARK: - String Representation

    /// Returns a string representation of the given alignment values.
    ///
    /// Returns named constants for common alignments, or a formatted string
    /// for custom values.
    ///
    /// **Dart Source:** `alignment.dart:417-430`
    public static func _stringify(_ x: Double, _ y: Double) -> String {
        switch (x, y) {
        case (-1.0, -1.0): return "Alignment.topLeft"
        case (0.0, -1.0): return "Alignment.topCenter"
        case (1.0, -1.0): return "Alignment.topRight"
        case (-1.0, 0.0): return "Alignment.centerLeft"
        case (0.0, 0.0): return "Alignment.center"
        case (1.0, 0.0): return "Alignment.centerRight"
        case (-1.0, 1.0): return "Alignment.bottomLeft"
        case (0.0, 1.0): return "Alignment.bottomCenter"
        case (1.0, 1.0): return "Alignment.bottomRight"
        default: return "Alignment(\(String(format: "%.1f", x)), \(String(format: "%.1f", y)))"
        }
    }

    /// A textual representation of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:432-433`
    public var description: String {
        Self._stringify(x, y)
    }
}

// MARK: - AlignmentDirectional

/// An offset that's expressed as a fraction of a `Size`, but whose horizontal
/// component is dependent on the writing direction.
///
/// This can be used to indicate an offset from the left in `TextDirection.ltr`
/// text and an offset from the right in `TextDirection.rtl` text without having
/// to be aware of the current text direction.
///
/// **Dart Source:** `alignment.dart:436-612`
public struct AlignmentDirectional: AlignmentGeometry, Sendable {
    /// The distance fraction in the horizontal direction.
    ///
    /// A value of -1.0 corresponds to the edge on the "start" side, which is the
    /// left side in `TextDirection.ltr` contexts and the right side in
    /// `TextDirection.rtl` contexts. A value of 1.0 corresponds to the opposite
    /// edge, the "end" side. Values are not limited to that range; values less
    /// than -1.0 represent positions beyond the start edge, and values greater than
    /// 1.0 represent positions beyond the end edge.
    ///
    /// This value is normalized into an `Alignment.x` value by the `resolve`
    /// method.
    ///
    /// **Dart Source:** `alignment.dart:451-462`
    public let start: Double

    /// The distance fraction in the vertical direction.
    ///
    /// A value of -1.0 corresponds to the topmost edge. A value of 1.0
    /// corresponds to the bottommost edge. Values are not limited to that range;
    /// values less than -1.0 represent positions above the top, and values
    /// greater than 1.0 represent positions below the bottom.
    ///
    /// This value is passed through to `Alignment.y` unmodified by the
    /// `resolve` method.
    ///
    /// **Dart Source:** `alignment.dart:464-473`
    public let y: Double

    /// Creates a directional alignment.
    ///
    /// **Dart Source:** `alignment.dart:448-449`
    public init(_ start: Double, _ y: Double) {
        self.start = start
        self.y = y
    }

    // MARK: - AlignmentGeometry Protocol

    /// **Dart Source:** `alignment.dart:475-476`
    public var _x: Double { 0.0 }

    /// **Dart Source:** `alignment.dart:478-479`
    public var _start: Double { start }

    /// **Dart Source:** `alignment.dart:481-482`
    public var _y: Double { y }

    // MARK: - Static Constants

    /// The top corner on the "start" side.
    ///
    /// **Dart Source:** `alignment.dart:484-485`
    public static let topStart = AlignmentDirectional(-1.0, -1.0)

    /// The center point along the top edge.
    ///
    /// Consider using `Alignment.topCenter` instead, as it does not need
    /// to be resolved to be used.
    ///
    /// **Dart Source:** `alignment.dart:487-491`
    public static let topCenter = AlignmentDirectional(0.0, -1.0)

    /// The top corner on the "end" side.
    ///
    /// **Dart Source:** `alignment.dart:493-494`
    public static let topEnd = AlignmentDirectional(1.0, -1.0)

    /// The center point along the "start" edge.
    ///
    /// **Dart Source:** `alignment.dart:496-497`
    public static let centerStart = AlignmentDirectional(-1.0, 0.0)

    /// The center point, both horizontally and vertically.
    ///
    /// Consider using `Alignment.center` instead, as it does not need to
    /// be resolved to be used.
    ///
    /// **Dart Source:** `alignment.dart:499-503`
    public static let center = AlignmentDirectional(0.0, 0.0)

    /// The center point along the "end" edge.
    ///
    /// **Dart Source:** `alignment.dart:505-506`
    public static let centerEnd = AlignmentDirectional(1.0, 0.0)

    /// The bottom corner on the "start" side.
    ///
    /// **Dart Source:** `alignment.dart:508-509`
    public static let bottomStart = AlignmentDirectional(-1.0, 1.0)

    /// The center point along the bottom edge.
    ///
    /// Consider using `Alignment.bottomCenter` instead, as it does not
    /// need to be resolved to be used.
    ///
    /// **Dart Source:** `alignment.dart:511-515`
    public static let bottomCenter = AlignmentDirectional(0.0, 1.0)

    /// The bottom corner on the "end" side.
    ///
    /// **Dart Source:** `alignment.dart:517-518`
    public static let bottomEnd = AlignmentDirectional(1.0, 1.0)

    // MARK: - Add Method Override

    /// Returns the sum of two `AlignmentGeometry` objects.
    ///
    /// If `other` is an `AlignmentDirectional`, returns an `AlignmentDirectional`.
    /// Otherwise, returns a `MixedAlignment`.
    ///
    /// **Dart Source:** `alignment.dart:520-526`
    public func add(_ other: any AlignmentGeometry) -> any AlignmentGeometry {
        if let otherDir = other as? AlignmentDirectional {
            return self + otherDir
        }
        return MixedAlignment(_x + other._x, _start + other._start, _y + other._y)
    }

    // MARK: - Operators

    /// Returns the difference between two `AlignmentDirectional`s.
    ///
    /// **Dart Source:** `alignment.dart:528-531`
    public static func - (lhs: AlignmentDirectional, rhs: AlignmentDirectional) -> AlignmentDirectional {
        AlignmentDirectional(lhs.start - rhs.start, lhs.y - rhs.y)
    }

    /// Returns the sum of two `AlignmentDirectional`s.
    ///
    /// **Dart Source:** `alignment.dart:533-536`
    public static func + (lhs: AlignmentDirectional, rhs: AlignmentDirectional) -> AlignmentDirectional {
        AlignmentDirectional(lhs.start + rhs.start, lhs.y + rhs.y)
    }

    /// Returns the negation of the given `AlignmentDirectional`.
    ///
    /// **Dart Source:** `alignment.dart:538-542`
    public static prefix func - (alignment: AlignmentDirectional) -> AlignmentDirectional {
        AlignmentDirectional(-alignment.start, -alignment.y)
    }

    /// Scales the `AlignmentDirectional` in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:544-548`
    public static func * (lhs: AlignmentDirectional, rhs: Double) -> AlignmentDirectional {
        AlignmentDirectional(lhs.start * rhs, lhs.y * rhs)
    }

    /// Divides the `AlignmentDirectional` in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:550-554`
    public static func / (lhs: AlignmentDirectional, rhs: Double) -> AlignmentDirectional {
        AlignmentDirectional(lhs.start / rhs, lhs.y / rhs)
    }

    /// Integer divides the `AlignmentDirectional` in each dimension by the given factor.
    ///
    /// Swift does not have the `~/` operator, so this is provided as a method.
    ///
    /// **Dart Source:** `alignment.dart:556-560`
    public func truncatingDivision(_ other: Double) -> AlignmentDirectional {
        AlignmentDirectional(Double(Int(start / other)), Double(Int(y / other)))
    }

    /// Computes the remainder in each dimension by the given factor.
    ///
    /// **Dart Source:** `alignment.dart:562-566`
    public static func % (lhs: AlignmentDirectional, rhs: Double) -> AlignmentDirectional {
        AlignmentDirectional(lhs.start.truncatingRemainder(dividingBy: rhs),
                             lhs.y.truncatingRemainder(dividingBy: rhs))
    }

    // MARK: - Lerp

    /// Linearly interpolate between two `AlignmentDirectional`s.
    ///
    /// If either is null, this function interpolates from `AlignmentDirectional.center`.
    ///
    /// **Dart Source:** `alignment.dart:568-584`
    public static func lerp(_ a: AlignmentDirectional?, _ b: AlignmentDirectional?, _ t: Double) -> AlignmentDirectional? {
        if let a = a, let b = b, a.start == b.start && a.y == b.y {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return AlignmentDirectional(lerpDouble(0.0, b.start, t)!, lerpDouble(0.0, b.y, t)!)
        }
        if b == nil {
            guard let a = a else { return nil }
            return AlignmentDirectional(lerpDouble(a.start, 0.0, t)!, lerpDouble(a.y, 0.0, t)!)
        }
        guard let a = a, let b = b else { return nil }
        return AlignmentDirectional(lerpDouble(a.start, b.start, t)!, lerpDouble(a.y, b.y, t)!)
    }

    // MARK: - Resolve

    /// Resolves this alignment to a concrete `Alignment` based on the given text direction.
    ///
    /// For LTR, the `start` value becomes the `x` value.
    /// For RTL, the `start` value is negated to become the `x` value.
    ///
    /// **Dart Source:** `alignment.dart:586-593`
    public func resolve(_ direction: TextDirection?) -> Alignment {
        debugCheckCanResolveTextDirection(direction, "AlignmentDirectional")
        switch direction! {
        case .rtl:
            return Alignment(-start, y)
        case .ltr:
            return Alignment(start, y)
        }
    }

    // MARK: - String Representation

    /// Returns a string representation of the given alignment values.
    ///
    /// Returns named constants for common alignments, or a formatted string
    /// for custom values.
    ///
    /// **Dart Source:** `alignment.dart:595-608`
    public static func _stringify(_ start: Double, _ y: Double) -> String {
        switch (start, y) {
        case (-1.0, -1.0): return "AlignmentDirectional.topStart"
        case (0.0, -1.0): return "AlignmentDirectional.topCenter"
        case (1.0, -1.0): return "AlignmentDirectional.topEnd"
        case (-1.0, 0.0): return "AlignmentDirectional.centerStart"
        case (0.0, 0.0): return "AlignmentDirectional.center"
        case (1.0, 0.0): return "AlignmentDirectional.centerEnd"
        case (-1.0, 1.0): return "AlignmentDirectional.bottomStart"
        case (0.0, 1.0): return "AlignmentDirectional.bottomCenter"
        case (1.0, 1.0): return "AlignmentDirectional.bottomEnd"
        default: return "AlignmentDirectional(\(String(format: "%.1f", start)), \(String(format: "%.1f", y)))"
        }
    }

    /// A textual representation of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:610-611`
    public var description: String {
        Self._stringify(start, y)
    }
}

// MARK: - TextAlignVertical

/// The vertical alignment of text within an input box.
///
/// A single `y` value that can range from -1.0 to 1.0. -1.0 aligns to the top
/// of an input box so that the top of the first line of text fits within the
/// box and its padding. 0.0 aligns to the center of the box. 1.0 aligns so that
/// the bottom of the last line of text aligns with the bottom interior edge of
/// the input box.
///
/// **Dart Source:** `alignment.dart:665-703`
public struct TextAlignVertical: Hashable, CustomStringConvertible, Sendable {
    /// A value ranging from -1.0 to 1.0 that defines the topmost and bottommost
    /// locations of the top and bottom of the input box.
    ///
    /// **Dart Source:** `alignment.dart:684-686`
    public let y: Double

    /// Creates a TextAlignVertical from any y value between -1.0 and 1.0.
    ///
    /// **Dart Source:** `alignment.dart:681-682`
    public init(y: Double) {
        assert(y >= -1.0 && y <= 1.0, "y must be in the range [-1.0, 1.0]")
        self.y = y
    }

    // MARK: - Static Constants

    /// Aligns a TextField's input Text with the topmost location within a
    /// TextField's input box.
    ///
    /// **Dart Source:** `alignment.dart:688-690`
    public static let top = TextAlignVertical(y: -1.0)

    /// Aligns a TextField's input Text to the center of the TextField.
    ///
    /// **Dart Source:** `alignment.dart:692-693`
    public static let center = TextAlignVertical(y: 0.0)

    /// Aligns a TextField's input Text with the bottommost location within a
    /// TextField.
    ///
    /// **Dart Source:** `alignment.dart:695-697`
    public static let bottom = TextAlignVertical(y: 1.0)

    // MARK: - String Representation

    /// A textual representation of this alignment.
    ///
    /// **Dart Source:** `alignment.dart:699-702`
    public var description: String {
        "TextAlignVertical(y: \(y))"
    }
}
