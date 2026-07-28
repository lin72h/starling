// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An offset that's expressed as a fraction of a Size.
///
/// `FractionalOffset` uses a coordinate system with an origin in the top-left
/// corner of the rectangle, whereas `Alignment` uses a coordinate system with
/// an origin in the center of the rectangle.
///
/// `FractionalOffset(1.0, 0.0)` represents the top right of the Size.
/// `FractionalOffset(0.0, 1.0)` represents the bottom left of the Size.
///
/// Alignment is generally preferred over FractionalOffset for new code.
/// FractionalOffset is maintained for backward compatibility.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/fractional_offset.dart`

import FlutterSwiftBridge

// MARK: - FractionalOffset

/// An offset that's expressed as a fraction of a Size.
///
/// `FractionalOffset` specifies offsets in terms of a distance from the
/// top left, regardless of the `TextDirection`.
///
/// The coordinate conversion between `FractionalOffset` and `Alignment`:
/// - `FractionalOffset` uses top-left origin with range [0.0, 1.0]
/// - `Alignment` uses center origin with range [-1.0, 1.0]
///
/// Conversion: `x = dx * 2.0 - 1.0`, `y = dy * 2.0 - 1.0`
///
/// **Dart Source:** `fractional_offset.dart:54-187`
/// **Original Name:** `FractionalOffset`
public struct FractionalOffset: AlignmentGeometry, Hashable, Sendable {

    // MARK: - Internal Storage

    /// The x component in Alignment coordinates (center-origin).
    ///
    /// **Dart Source:** `fractional_offset.dart:56` (inherited from Alignment)
    public let x: Double

    /// The y component in Alignment coordinates (center-origin).
    ///
    /// **Dart Source:** `fractional_offset.dart:56` (inherited from Alignment)
    public let y: Double

    // MARK: - Initializers

    /// Creates a fractional offset.
    ///
    /// The `dx` and `dy` arguments correspond to the fractional distance from
    /// the top-left corner.
    ///
    /// Internally converts from FractionalOffset coordinates to Alignment
    /// coordinates: `x = dx * 2.0 - 1.0`, `y = dy * 2.0 - 1.0`.
    ///
    /// **Dart Source:** `fractional_offset.dart:55-56`
    public init(_ dx: Double, _ dy: Double) {
        self.x = dx * 2.0 - 1.0
        self.y = dy * 2.0 - 1.0
    }

    /// Internal initializer that takes raw Alignment-coordinate values.
    ///
    /// This is used by operators and lerp to avoid double-conversion.
    internal init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    // MARK: - AlignmentGeometry Protocol

    /// **Dart Source:** `fractional_offset.dart` (inherited from Alignment)
    public var _x: Double { x }

    /// **Dart Source:** `fractional_offset.dart` (inherited from Alignment)
    public var _start: Double { 0.0 }

    /// **Dart Source:** `fractional_offset.dart` (inherited from Alignment)
    public var _y: Double { y }

    /// Resolves this alignment. Since `FractionalOffset` does not depend on
    /// text direction, resolving returns an equivalent `Alignment`.
    ///
    /// **Dart Source:** `fractional_offset.dart` (inherited from Alignment)
    public func resolve(_ direction: TextDirection?) -> Alignment {
        Alignment(x, y)
    }

    // MARK: - Properties (Getters)

    /// The distance fraction in the horizontal direction.
    ///
    /// A value of 0.0 corresponds to the leftmost edge. A value of 1.0
    /// corresponds to the rightmost edge. Values are not limited to that range;
    /// negative values represent positions to the left of the left edge, and
    /// values greater than 1.0 represent positions to the right of the right
    /// edge.
    ///
    /// **Dart Source:** `fractional_offset.dart:86`
    public var dx: Double { (x + 1.0) / 2.0 }

    /// The distance fraction in the vertical direction.
    ///
    /// A value of 0.0 corresponds to the topmost edge. A value of 1.0
    /// corresponds to the bottommost edge. Values are not limited to that range;
    /// negative values represent positions above the top, and values greater
    /// than 1.0 represent positions below the bottom.
    ///
    /// **Dart Source:** `fractional_offset.dart:94`
    public var dy: Double { (y + 1.0) / 2.0 }

    // MARK: - Static Constants

    /// The top left corner.
    ///
    /// **Dart Source:** `fractional_offset.dart:97`
    public static let topLeft = FractionalOffset(0.0, 0.0)

    /// The center point along the top edge.
    ///
    /// **Dart Source:** `fractional_offset.dart:100`
    public static let topCenter = FractionalOffset(0.5, 0.0)

    /// The top right corner.
    ///
    /// **Dart Source:** `fractional_offset.dart:103`
    public static let topRight = FractionalOffset(1.0, 0.0)

    /// The center point along the left edge.
    ///
    /// **Dart Source:** `fractional_offset.dart:106`
    public static let centerLeft = FractionalOffset(0.0, 0.5)

    /// The center point, both horizontally and vertically.
    ///
    /// **Dart Source:** `fractional_offset.dart:109`
    public static let center = FractionalOffset(0.5, 0.5)

    /// The center point along the right edge.
    ///
    /// **Dart Source:** `fractional_offset.dart:112`
    public static let centerRight = FractionalOffset(1.0, 0.5)

    /// The bottom left corner.
    ///
    /// **Dart Source:** `fractional_offset.dart:115`
    public static let bottomLeft = FractionalOffset(0.0, 1.0)

    /// The center point along the bottom edge.
    ///
    /// **Dart Source:** `fractional_offset.dart:118`
    public static let bottomCenter = FractionalOffset(0.5, 1.0)

    /// The bottom right corner.
    ///
    /// **Dart Source:** `fractional_offset.dart:121`
    public static let bottomRight = FractionalOffset(1.0, 1.0)

    // MARK: - Factory Methods

    /// Creates a fractional offset from a specific offset and size.
    ///
    /// The returned `FractionalOffset` describes the position of the
    /// `Offset` in the `Size`, as a fraction of the `Size`.
    ///
    /// **Dart Source:** `fractional_offset.dart:62-64`
    public static func fromOffsetAndSize(_ offset: Offset, _ size: Size) -> FractionalOffset {
        FractionalOffset(offset.dx / size.width, offset.dy / size.height)
    }

    /// Creates a fractional offset from a specific offset and rectangle.
    ///
    /// The offset is assumed to be relative to the same origin as the rectangle.
    ///
    /// If the offset is relative to the top left of the rectangle, use
    /// `fromOffsetAndSize` instead, passing `rect.size`.
    ///
    /// **Dart Source:** `fractional_offset.dart:75-77`
    public static func fromOffsetAndRect(_ offset: Offset, _ rect: Rect) -> FractionalOffset {
        FractionalOffset.fromOffsetAndSize(offset - rect.topLeft, rect.size)
    }

    // MARK: - Operators

    /// Returns the difference of two `FractionalOffset`s.
    ///
    /// **Dart Source:** `fractional_offset.dart:123-129`
    public static func - (lhs: FractionalOffset, rhs: FractionalOffset) -> FractionalOffset {
        FractionalOffset(lhs.dx - rhs.dx, lhs.dy - rhs.dy)
    }

    /// Returns the sum of two `FractionalOffset`s.
    ///
    /// **Dart Source:** `fractional_offset.dart:131-137`
    public static func + (lhs: FractionalOffset, rhs: FractionalOffset) -> FractionalOffset {
        FractionalOffset(lhs.dx + rhs.dx, lhs.dy + rhs.dy)
    }

    /// Returns the negation of the given `FractionalOffset`.
    ///
    /// **Dart Source:** `fractional_offset.dart:139-142`
    public static prefix func - (offset: FractionalOffset) -> FractionalOffset {
        FractionalOffset(-offset.dx, -offset.dy)
    }

    /// Scales the `FractionalOffset` in each dimension by the given factor.
    ///
    /// **Dart Source:** `fractional_offset.dart:144-147`
    public static func * (lhs: FractionalOffset, rhs: Double) -> FractionalOffset {
        FractionalOffset(lhs.dx * rhs, lhs.dy * rhs)
    }

    /// Divides the `FractionalOffset` in each dimension by the given factor.
    ///
    /// **Dart Source:** `fractional_offset.dart:149-152`
    public static func / (lhs: FractionalOffset, rhs: Double) -> FractionalOffset {
        FractionalOffset(lhs.dx / rhs, lhs.dy / rhs)
    }

    /// Integer divides the `FractionalOffset` in each dimension by the given factor.
    ///
    /// Swift does not have the `~/` operator, so this is provided as a method.
    ///
    /// **Dart Source:** `fractional_offset.dart:154-157`
    public func truncatingDivision(_ other: Double) -> FractionalOffset {
        FractionalOffset(
            Double(Int(dx / other)),
            Double(Int(dy / other))
        )
    }

    /// Computes the remainder in each dimension by the given factor.
    ///
    /// **Dart Source:** `fractional_offset.dart:159-162`
    public static func % (lhs: FractionalOffset, rhs: Double) -> FractionalOffset {
        FractionalOffset(
            lhs.dx.truncatingRemainder(dividingBy: rhs),
            lhs.dy.truncatingRemainder(dividingBy: rhs)
        )
    }

    // MARK: - Lerp

    /// Linearly interpolate between two `FractionalOffset`s.
    ///
    /// If either is nil, this function interpolates from `FractionalOffset.center`.
    ///
    /// **Dart Source:** `fractional_offset.dart:169-180`
    public static func lerp(_ a: FractionalOffset?, _ b: FractionalOffset?, _ t: Double) -> FractionalOffset? {
        if let a = a, let b = b, a.x == b.x && a.y == b.y {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return FractionalOffset(
                lerpDouble(0.5, b.dx, t)!,
                lerpDouble(0.5, b.dy, t)!
            )
        }
        if b == nil {
            guard let a = a else { return nil }
            return FractionalOffset(
                lerpDouble(a.dx, 0.5, t)!,
                lerpDouble(a.dy, 0.5, t)!
            )
        }
        guard let a = a, let b = b else { return nil }
        return FractionalOffset(
            lerpDouble(a.dx, b.dx, t)!,
            lerpDouble(a.dy, b.dy, t)!
        )
    }

    // MARK: - Hashable

    /// Hashes the essential components of this `FractionalOffset`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }

    /// Equality comparison for `FractionalOffset`.
    public static func == (lhs: FractionalOffset, rhs: FractionalOffset) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    // MARK: - String Representation

    /// A textual representation of this `FractionalOffset`.
    ///
    /// The format is `FractionalOffset(dx, dy)` where dx and dy are the
    /// fractional offset values formatted with one decimal place.
    ///
    /// **Dart Source:** `fractional_offset.dart:182-186`
    public var description: String {
        "FractionalOffset(\(String(format: "%.1f", dx)), \(String(format: "%.1f", dy)))"
    }
}
