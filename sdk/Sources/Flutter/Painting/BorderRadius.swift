// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Border radius types for defining rounded corners.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/border_radius.dart`

import FlutterSwiftBridge

// MARK: - BorderRadiusGeometry

/// Base protocol for `BorderRadius` that allows for text-direction aware resolution.
///
/// A property or argument of this type accepts classes created either with
/// `BorderRadius.only` and its variants, or `BorderRadiusDirectional.only`
/// and its variants.
///
/// To convert a `BorderRadiusGeometry` object of indeterminate type into a
/// `BorderRadius` object, call the `resolve` method.
///
/// **Dart Source:** `border_radius.dart:25-339`
public protocol BorderRadiusGeometry: Hashable, CustomStringConvertible {
    /// The top-left radius (physical corner).
    var _topLeft: Radius { get }
    /// The top-right radius (physical corner).
    var _topRight: Radius { get }
    /// The bottom-left radius (physical corner).
    var _bottomLeft: Radius { get }
    /// The bottom-right radius (physical corner).
    var _bottomRight: Radius { get }
    /// The top-start radius (logical corner).
    var _topStart: Radius { get }
    /// The top-end radius (logical corner).
    var _topEnd: Radius { get }
    /// The bottom-start radius (logical corner).
    var _bottomStart: Radius { get }
    /// The bottom-end radius (logical corner).
    var _bottomEnd: Radius { get }

    /// Returns the [BorderRadiusGeometry] object with each corner radius negated.
    ///
    /// This is the same as multiplying the object by -1.0.
    ///
    /// **Dart Source:** `border_radius.dart:159`
    func negated() -> any BorderRadiusGeometry

    /// Scales the [BorderRadiusGeometry] object's corners by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:164`
    func multiplied(by other: Double) -> any BorderRadiusGeometry

    /// Divides the [BorderRadiusGeometry] object's corners by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:169`
    func divided(by other: Double) -> any BorderRadiusGeometry

    /// Integer divides the [BorderRadiusGeometry] object's corners by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:177`
    func truncatingDivision(_ other: Double) -> any BorderRadiusGeometry

    /// Computes the remainder of each corner by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:185`
    func remainder(_ other: Double) -> any BorderRadiusGeometry

    /// Convert this instance into a `BorderRadius`, so that the radii are
    /// expressed for specific physical corners (top-left, top-right, etc) rather
    /// than in a direction-dependent manner.
    ///
    /// **Dart Source:** `border_radius.dart:218`
    func resolve(_ direction: TextDirection?) -> BorderRadius
}

// MARK: - BorderRadiusGeometry Extension

extension BorderRadiusGeometry {
    /// Returns the difference between two `BorderRadiusGeometry` objects.
    ///
    /// **Dart Source:** `border_radius.dart:117-128`
    public func subtract(_ other: any BorderRadiusGeometry) -> MixedBorderRadius {
        MixedBorderRadius(
            topLeft: _topLeft - other._topLeft,
            topRight: _topRight - other._topRight,
            bottomLeft: _bottomLeft - other._bottomLeft,
            bottomRight: _bottomRight - other._bottomRight,
            topStart: _topStart - other._topStart,
            topEnd: _topEnd - other._topEnd,
            bottomStart: _bottomStart - other._bottomStart,
            bottomEnd: _bottomEnd - other._bottomEnd
        )
    }

    /// Returns the sum of two `BorderRadiusGeometry` objects.
    ///
    /// **Dart Source:** `border_radius.dart:141-152`
    public func add(_ other: any BorderRadiusGeometry) -> MixedBorderRadius {
        MixedBorderRadius(
            topLeft: _topLeft + other._topLeft,
            topRight: _topRight + other._topRight,
            bottomLeft: _bottomLeft + other._bottomLeft,
            bottomRight: _bottomRight + other._bottomRight,
            topStart: _topStart + other._topStart,
            topEnd: _topEnd + other._topEnd,
            bottomStart: _bottomStart + other._bottomStart,
            bottomEnd: _bottomEnd + other._bottomEnd
        )
    }

    /// Default description implementation.
    ///
    /// **Dart Source:** `border_radius.dart:221-307`
    public var description: String {
        var visual: String?
        var logical: String?

        if _topLeft == _topRight && _topRight == _bottomLeft && _bottomLeft == _bottomRight {
            if _topLeft != Radius.zero {
                if _topLeft.x == _topLeft.y {
                    visual = "BorderRadius.circular(\(String(format: "%.1f", _topLeft.x)))"
                } else {
                    visual = "BorderRadius.all(\(_topLeft))"
                }
            }
        } else {
            // visuals aren't the same and at least one isn't zero
            var result = "BorderRadius.only("
            var comma = false
            if _topLeft != Radius.zero {
                result += "topLeft: \(_topLeft)"
                comma = true
            }
            if _topRight != Radius.zero {
                if comma { result += ", " }
                result += "topRight: \(_topRight)"
                comma = true
            }
            if _bottomLeft != Radius.zero {
                if comma { result += ", " }
                result += "bottomLeft: \(_bottomLeft)"
                comma = true
            }
            if _bottomRight != Radius.zero {
                if comma { result += ", " }
                result += "bottomRight: \(_bottomRight)"
            }
            result += ")"
            visual = result
        }

        if _topStart == _topEnd && _topEnd == _bottomEnd && _bottomEnd == _bottomStart {
            if _topStart != Radius.zero {
                if _topStart.x == _topStart.y {
                    logical = "BorderRadiusDirectional.circular(\(String(format: "%.1f", _topStart.x)))"
                } else {
                    logical = "BorderRadiusDirectional.all(\(_topStart))"
                }
            }
        } else {
            // logicals aren't the same and at least one isn't zero
            var result = "BorderRadiusDirectional.only("
            var comma = false
            if _topStart != Radius.zero {
                result += "topStart: \(_topStart)"
                comma = true
            }
            if _topEnd != Radius.zero {
                if comma { result += ", " }
                result += "topEnd: \(_topEnd)"
                comma = true
            }
            if _bottomStart != Radius.zero {
                if comma { result += ", " }
                result += "bottomStart: \(_bottomStart)"
                comma = true
            }
            if _bottomEnd != Radius.zero {
                if comma { result += ", " }
                result += "bottomEnd: \(_bottomEnd)"
            }
            result += ")"
            logical = result
        }

        if let visual = visual, let logical = logical {
            return "\(visual) + \(logical)"
        }
        return visual ?? logical ?? "BorderRadius.zero"
    }

    /// Default hash implementation.
    ///
    /// **Dart Source:** `border_radius.dart:329-338`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_topLeft)
        hasher.combine(_topRight)
        hasher.combine(_bottomLeft)
        hasher.combine(_bottomRight)
        hasher.combine(_topStart)
        hasher.combine(_topEnd)
        hasher.combine(_bottomStart)
        hasher.combine(_bottomEnd)
    }
}

/// Equality for BorderRadiusGeometry.
///
/// **Dart Source:** `border_radius.dart:310-326`
public func == (lhs: any BorderRadiusGeometry, rhs: any BorderRadiusGeometry) -> Bool {
    lhs._topLeft == rhs._topLeft &&
    lhs._topRight == rhs._topRight &&
    lhs._bottomLeft == rhs._bottomLeft &&
    lhs._bottomRight == rhs._bottomRight &&
    lhs._topStart == rhs._topStart &&
    lhs._topEnd == rhs._topEnd &&
    lhs._bottomStart == rhs._bottomStart &&
    lhs._bottomEnd == rhs._bottomEnd
}

// MARK: - BorderRadiusGeometry Static Methods

/// Extension providing static methods for `BorderRadiusGeometry`.
public enum BorderRadiusGeometryStatics {
    /// A BorderRadius with all zero radii.
    ///
    /// **Dart Source:** `border_radius.dart:90`
    public static var zero: any BorderRadiusGeometry { BorderRadius.zero }

    /// Linearly interpolate between two `BorderRadiusGeometry` objects.
    ///
    /// If either is nil, this function interpolates from `BorderRadius.zero`,
    /// and the result is an object of the same type as the non-nil argument.
    ///
    /// **Dart Source:** `border_radius.dart:200-207`
    public static func lerp(
        _ a: (any BorderRadiusGeometry)?,
        _ b: (any BorderRadiusGeometry)?,
        _ t: Double
    ) -> (any BorderRadiusGeometry)? {
        if let aVal = a, let bVal = b,
           aVal._topLeft == bVal._topLeft &&
           aVal._topRight == bVal._topRight &&
           aVal._bottomLeft == bVal._bottomLeft &&
           aVal._bottomRight == bVal._bottomRight &&
           aVal._topStart == bVal._topStart &&
           aVal._topEnd == bVal._topEnd &&
           aVal._bottomStart == bVal._bottomStart &&
           aVal._bottomEnd == bVal._bottomEnd {
            return a
        }
        guard let aVal = a ?? BorderRadius.zero as (any BorderRadiusGeometry)?,
              let bVal = b ?? BorderRadius.zero as (any BorderRadiusGeometry)? else {
            return nil
        }
        return aVal.add(bVal.subtract(aVal).multiplied(by: t))
    }
}

// MARK: - BorderRadius

/// An immutable set of radii for each corner of a rectangle.
///
/// Used by `BoxDecoration` when the shape is a `BoxShape.rectangle`.
///
/// The `BorderRadius` class specifies offsets in terms of visual corners, e.g.
/// `topLeft`. These values are not affected by the `TextDirection`. To support
/// both left-to-right and right-to-left layouts, consider using
/// `BorderRadiusDirectional`, which is expressed in terms that are relative to
/// a `TextDirection` (typically obtained from the ambient `Directionality`).
///
/// **Dart Source:** `border_radius.dart:341-584`
public struct BorderRadius: BorderRadiusGeometry, Sendable {
    /// The top-left `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:396-400`
    public let topLeft: Radius

    /// The top-right `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:402-406`
    public let topRight: Radius

    /// The bottom-left `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:408-412`
    public let bottomLeft: Radius

    /// The bottom-right `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:414-418`
    public let bottomRight: Radius

    // MARK: - BorderRadiusGeometry Protocol

    /// **Dart Source:** `border_radius.dart:399-400`
    public var _topLeft: Radius { topLeft }

    /// **Dart Source:** `border_radius.dart:405-406`
    public var _topRight: Radius { topRight }

    /// **Dart Source:** `border_radius.dart:411-412`
    public var _bottomLeft: Radius { bottomLeft }

    /// **Dart Source:** `border_radius.dart:417-418`
    public var _bottomRight: Radius { bottomRight }

    /// **Dart Source:** `border_radius.dart:420-421`
    public var _topStart: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:423-424`
    public var _topEnd: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:426-427`
    public var _bottomStart: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:429-430`
    public var _bottomEnd: Radius { Radius.zero }

    // MARK: - Initializers

    /// Creates a border radius where all radii are `radius`.
    ///
    /// **Dart Source:** `border_radius.dart:352-353`
    public static func all(_ radius: Radius) -> BorderRadius {
        BorderRadius.only(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }

    /// Creates a border radius where all radii are `Radius(circular: radius)`.
    ///
    /// **Dart Source:** `border_radius.dart:356`
    public static func circular(_ radius: Double) -> BorderRadius {
        BorderRadius.all(Radius(circular: radius))
    }

    /// Creates a vertically symmetric border radius where the top and bottom
    /// sides of the rectangle have the same radii.
    ///
    /// **Dart Source:** `border_radius.dart:360-361`
    public static func vertical(top: Radius = .zero, bottom: Radius = .zero) -> BorderRadius {
        BorderRadius.only(topLeft: top, topRight: top, bottomLeft: bottom, bottomRight: bottom)
    }

    /// Creates a horizontally symmetrical border radius where the left and right
    /// sides of the rectangle have the same radii.
    ///
    /// **Dart Source:** `border_radius.dart:365-366`
    public static func horizontal(left: Radius = .zero, right: Radius = .zero) -> BorderRadius {
        BorderRadius.only(topLeft: left, topRight: right, bottomLeft: left, bottomRight: right)
    }

    /// Creates a border radius with only the given non-zero values. The other
    /// corners will be right angles.
    ///
    /// **Dart Source:** `border_radius.dart:370-375`
    public static func only(
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomLeft: Radius = .zero,
        bottomRight: Radius = .zero
    ) -> BorderRadius {
        BorderRadius(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }

    /// Creates a border radius with the given values.
    ///
    /// **Dart Source:** `border_radius.dart:370-375`
    public init(
        topLeft: Radius = .zero,
        topRight: Radius = .zero,
        bottomLeft: Radius = .zero,
        bottomRight: Radius = .zero
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    // MARK: - Static Constants

    /// A border radius with all zero radii.
    ///
    /// **Dart Source:** `border_radius.dart:394`
    public static let zero = BorderRadius.all(Radius.zero)

    // MARK: - Instance Methods

    /// Returns a copy of this BorderRadius with the given fields replaced with
    /// the new values.
    ///
    /// **Dart Source:** `border_radius.dart:379-391`
    public func copyWith(
        topLeft: Radius? = nil,
        topRight: Radius? = nil,
        bottomLeft: Radius? = nil,
        bottomRight: Radius? = nil
    ) -> BorderRadius {
        BorderRadius.only(
            topLeft: topLeft ?? self.topLeft,
            topRight: topRight ?? self.topRight,
            bottomLeft: bottomLeft ?? self.bottomLeft,
            bottomRight: bottomRight ?? self.bottomRight
        )
    }

    /// Creates an `RRect` from the current border radius and a `Rect`.
    ///
    /// If any of the radii have negative values in x or y, those values will be
    /// clamped to zero in order to produce a valid `RRect`.
    ///
    /// **Dart Source:** `border_radius.dart:436-447`
    public func toRRect(_ rect: Rect) -> RRect {
        // Because the current radii could be negative, we must clamp them before
        // converting them to an RRect to be rendered, since negative radii on
        // RRects don't make sense.
        RRect(
            fromRectAndCorners: rect,
            topLeft: topLeft.clamp(minimum: Radius.zero),
            topRight: topRight.clamp(minimum: Radius.zero),
            bottomRight: bottomRight.clamp(minimum: Radius.zero),
            bottomLeft: bottomLeft.clamp(minimum: Radius.zero)
        )
    }

    /// Creates an `RSuperellipse` from the current border radius and a `Rect`.
    ///
    /// If any of the radii have negative values in x or y, those values will be
    /// clamped to zero in order to produce a valid `RSuperellipse`.
    ///
    /// **Dart Source:** `border_radius.dart:453-464`
    public func toRSuperellipse(_ rect: Rect) -> RSuperellipse {
        // Because the current radii could be negative, we must clamp them before
        // converting them to an RSuperellipse to be rendered, since negative radii on
        // RSuperellipses don't make sense.
        RSuperellipse(
            fromRectAndCorners: rect,
            topLeft: topLeft.clamp(minimum: Radius.zero),
            topRight: topRight.clamp(minimum: Radius.zero),
            bottomRight: bottomRight.clamp(minimum: Radius.zero),
            bottomLeft: bottomLeft.clamp(minimum: Radius.zero)
        )
    }

    /// Returns the difference between two BorderRadius objects.
    ///
    /// **Dart Source:** `border_radius.dart:482-489`
    public static func - (lhs: BorderRadius, rhs: BorderRadius) -> BorderRadius {
        BorderRadius.only(
            topLeft: lhs.topLeft - rhs.topLeft,
            topRight: lhs.topRight - rhs.topRight,
            bottomLeft: lhs.bottomLeft - rhs.bottomLeft,
            bottomRight: lhs.bottomRight - rhs.bottomRight
        )
    }

    /// Returns the sum of two BorderRadius objects.
    ///
    /// **Dart Source:** `border_radius.dart:493-500`
    public static func + (lhs: BorderRadius, rhs: BorderRadius) -> BorderRadius {
        BorderRadius.only(
            topLeft: lhs.topLeft + rhs.topLeft,
            topRight: lhs.topRight + rhs.topRight,
            bottomLeft: lhs.bottomLeft + rhs.bottomLeft,
            bottomRight: lhs.bottomRight + rhs.bottomRight
        )
    }

    /// Returns the BorderRadius object with each corner negated.
    ///
    /// This is the same as multiplying the object by -1.0.
    ///
    /// **Dart Source:** `border_radius.dart:506-513`
    public func negated() -> any BorderRadiusGeometry {
        BorderRadius.only(
            topLeft: -topLeft,
            topRight: -topRight,
            bottomLeft: -bottomLeft,
            bottomRight: -bottomRight
        )
    }

    /// Scales each corner of the BorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:517-524`
    public func multiplied(by other: Double) -> any BorderRadiusGeometry {
        BorderRadius.only(
            topLeft: topLeft * other,
            topRight: topRight * other,
            bottomLeft: bottomLeft * other,
            bottomRight: bottomRight * other
        )
    }

    /// Scales each corner of the BorderRadius by the given factor (operator version).
    ///
    /// **Dart Source:** `border_radius.dart:517-524`
    public static func * (lhs: BorderRadius, rhs: Double) -> BorderRadius {
        BorderRadius.only(
            topLeft: lhs.topLeft * rhs,
            topRight: lhs.topRight * rhs,
            bottomLeft: lhs.bottomLeft * rhs,
            bottomRight: lhs.bottomRight * rhs
        )
    }

    /// Divides each corner of the BorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:528-535`
    public func divided(by other: Double) -> any BorderRadiusGeometry {
        BorderRadius.only(
            topLeft: topLeft / other,
            topRight: topRight / other,
            bottomLeft: bottomLeft / other,
            bottomRight: bottomRight / other
        )
    }

    /// Divides each corner of the BorderRadius by the given factor (operator version).
    ///
    /// **Dart Source:** `border_radius.dart:528-535`
    public static func / (lhs: BorderRadius, rhs: Double) -> BorderRadius {
        BorderRadius.only(
            topLeft: lhs.topLeft / rhs,
            topRight: lhs.topRight / rhs,
            bottomLeft: lhs.bottomLeft / rhs,
            bottomRight: lhs.bottomRight / rhs
        )
    }

    /// Integer divides each corner of the BorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:539-546`
    public func truncatingDivision(_ other: Double) -> any BorderRadiusGeometry {
        BorderRadius.only(
            topLeft: topLeft.truncatingDivision(other),
            topRight: topRight.truncatingDivision(other),
            bottomLeft: bottomLeft.truncatingDivision(other),
            bottomRight: bottomRight.truncatingDivision(other)
        )
    }

    /// Computes the remainder of each corner by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:550-557`
    public func remainder(_ other: Double) -> any BorderRadiusGeometry {
        BorderRadius.only(
            topLeft: topLeft.remainder(other),
            topRight: topRight.remainder(other),
            bottomLeft: bottomLeft.remainder(other),
            bottomRight: bottomRight.remainder(other)
        )
    }

    /// Linearly interpolate between two BorderRadius objects.
    ///
    /// If either is nil, this function interpolates from `BorderRadius.zero`.
    ///
    /// **Dart Source:** `border_radius.dart:564-580`
    public static func lerp(_ a: BorderRadius?, _ b: BorderRadius?, _ t: Double) -> BorderRadius? {
        if let a = a, let b = b,
           a.topLeft == b.topLeft &&
           a.topRight == b.topRight &&
           a.bottomLeft == b.bottomLeft &&
           a.bottomRight == b.bottomRight {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return b * t
        }
        if b == nil {
            guard let a = a else { return nil }
            return a * (1.0 - t)
        }
        guard let a = a, let b = b else { return nil }
        return BorderRadius.only(
            topLeft: Radius.lerp(a.topLeft, b.topLeft, t)!,
            topRight: Radius.lerp(a.topRight, b.topRight, t)!,
            bottomLeft: Radius.lerp(a.bottomLeft, b.bottomLeft, t)!,
            bottomRight: Radius.lerp(a.bottomRight, b.bottomRight, t)!
        )
    }

    /// Returns this BorderRadius unchanged.
    ///
    /// **Dart Source:** `border_radius.dart:583`
    public func resolve(_ direction: TextDirection?) -> BorderRadius {
        self
    }
}

// MARK: - BorderRadiusDirectional

/// An immutable set of radii for each corner of a rectangle, but with the
/// corners specified in a manner dependent on the writing direction.
///
/// This can be used to specify a corner radius on the leading or trailing edge
/// of a box, so that it flips to the other side when the text alignment flips
/// (e.g. being on the top right in English text but the top left in Arabic
/// text).
///
/// **Dart Source:** `border_radius.dart:598-807`
public struct BorderRadiusDirectional: BorderRadiusGeometry, Sendable {
    /// The top-start `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:631-635`
    public let topStart: Radius

    /// The top-end `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:637-641`
    public let topEnd: Radius

    /// The bottom-start `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:643-647`
    public let bottomStart: Radius

    /// The bottom-end `Radius`.
    ///
    /// **Dart Source:** `border_radius.dart:649-653`
    public let bottomEnd: Radius

    // MARK: - BorderRadiusGeometry Protocol

    /// **Dart Source:** `border_radius.dart:634-635`
    public var _topStart: Radius { topStart }

    /// **Dart Source:** `border_radius.dart:640-641`
    public var _topEnd: Radius { topEnd }

    /// **Dart Source:** `border_radius.dart:646-647`
    public var _bottomStart: Radius { bottomStart }

    /// **Dart Source:** `border_radius.dart:652-653`
    public var _bottomEnd: Radius { bottomEnd }

    /// **Dart Source:** `border_radius.dart:655-656`
    public var _topLeft: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:658-659`
    public var _topRight: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:661-662`
    public var _bottomLeft: Radius { Radius.zero }

    /// **Dart Source:** `border_radius.dart:664-665`
    public var _bottomRight: Radius { Radius.zero }

    // MARK: - Initializers

    /// Creates a border radius where all radii are `radius`.
    ///
    /// **Dart Source:** `border_radius.dart:600-601`
    public static func all(_ radius: Radius) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(topStart: radius, topEnd: radius, bottomStart: radius, bottomEnd: radius)
    }

    /// Creates a border radius where all radii are `Radius(circular: radius)`.
    ///
    /// **Dart Source:** `border_radius.dart:604`
    public static func circular(_ radius: Double) -> BorderRadiusDirectional {
        BorderRadiusDirectional.all(Radius(circular: radius))
    }

    /// Creates a vertically symmetric border radius where the top and bottom
    /// sides of the rectangle have the same radii.
    ///
    /// **Dart Source:** `border_radius.dart:608-609`
    public static func vertical(top: Radius = .zero, bottom: Radius = .zero) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(topStart: top, topEnd: top, bottomStart: bottom, bottomEnd: bottom)
    }

    /// Creates a horizontally symmetrical border radius where the start and end
    /// sides of the rectangle have the same radii.
    ///
    /// **Dart Source:** `border_radius.dart:613-614`
    public static func horizontal(start: Radius = .zero, end: Radius = .zero) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(topStart: start, topEnd: end, bottomStart: start, bottomEnd: end)
    }

    /// Creates a border radius with only the given non-zero values. The other
    /// corners will be right angles.
    ///
    /// **Dart Source:** `border_radius.dart:618-623`
    public static func only(
        topStart: Radius = .zero,
        topEnd: Radius = .zero,
        bottomStart: Radius = .zero,
        bottomEnd: Radius = .zero
    ) -> BorderRadiusDirectional {
        BorderRadiusDirectional(topStart: topStart, topEnd: topEnd, bottomStart: bottomStart, bottomEnd: bottomEnd)
    }

    /// Creates a border radius with the given values.
    ///
    /// **Dart Source:** `border_radius.dart:618-623`
    public init(
        topStart: Radius = .zero,
        topEnd: Radius = .zero,
        bottomStart: Radius = .zero,
        bottomEnd: Radius = .zero
    ) {
        self.topStart = topStart
        self.topEnd = topEnd
        self.bottomStart = bottomStart
        self.bottomEnd = bottomEnd
    }

    // MARK: - Static Constants

    /// A border radius with all zero radii.
    ///
    /// Consider using `BorderRadius.zero` instead, since that object has the same
    /// effect, but will be cheaper to resolve.
    ///
    /// **Dart Source:** `border_radius.dart:629`
    public static let zero = BorderRadiusDirectional.all(Radius.zero)

    // MARK: - Instance Methods

    /// Returns the difference between two BorderRadiusDirectional objects.
    ///
    /// **Dart Source:** `border_radius.dart:684-691`
    public static func - (lhs: BorderRadiusDirectional, rhs: BorderRadiusDirectional) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(
            topStart: lhs.topStart - rhs.topStart,
            topEnd: lhs.topEnd - rhs.topEnd,
            bottomStart: lhs.bottomStart - rhs.bottomStart,
            bottomEnd: lhs.bottomEnd - rhs.bottomEnd
        )
    }

    /// Returns the sum of two BorderRadiusDirectional objects.
    ///
    /// **Dart Source:** `border_radius.dart:694-701`
    public static func + (lhs: BorderRadiusDirectional, rhs: BorderRadiusDirectional) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(
            topStart: lhs.topStart + rhs.topStart,
            topEnd: lhs.topEnd + rhs.topEnd,
            bottomStart: lhs.bottomStart + rhs.bottomStart,
            bottomEnd: lhs.bottomEnd + rhs.bottomEnd
        )
    }

    /// Returns the BorderRadiusDirectional object with each corner negated.
    ///
    /// This is the same as multiplying the object by -1.0.
    ///
    /// **Dart Source:** `border_radius.dart:707-714`
    public func negated() -> any BorderRadiusGeometry {
        BorderRadiusDirectional.only(
            topStart: -topStart,
            topEnd: -topEnd,
            bottomStart: -bottomStart,
            bottomEnd: -bottomEnd
        )
    }

    /// Scales each corner of the BorderRadiusDirectional by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:718-725`
    public func multiplied(by other: Double) -> any BorderRadiusGeometry {
        BorderRadiusDirectional.only(
            topStart: topStart * other,
            topEnd: topEnd * other,
            bottomStart: bottomStart * other,
            bottomEnd: bottomEnd * other
        )
    }

    /// Scales each corner of the BorderRadiusDirectional by the given factor (operator version).
    ///
    /// **Dart Source:** `border_radius.dart:718-725`
    public static func * (lhs: BorderRadiusDirectional, rhs: Double) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(
            topStart: lhs.topStart * rhs,
            topEnd: lhs.topEnd * rhs,
            bottomStart: lhs.bottomStart * rhs,
            bottomEnd: lhs.bottomEnd * rhs
        )
    }

    /// Divides each corner of the BorderRadiusDirectional by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:729-736`
    public func divided(by other: Double) -> any BorderRadiusGeometry {
        BorderRadiusDirectional.only(
            topStart: topStart / other,
            topEnd: topEnd / other,
            bottomStart: bottomStart / other,
            bottomEnd: bottomEnd / other
        )
    }

    /// Divides each corner of the BorderRadiusDirectional by the given factor (operator version).
    ///
    /// **Dart Source:** `border_radius.dart:729-736`
    public static func / (lhs: BorderRadiusDirectional, rhs: Double) -> BorderRadiusDirectional {
        BorderRadiusDirectional.only(
            topStart: lhs.topStart / rhs,
            topEnd: lhs.topEnd / rhs,
            bottomStart: lhs.bottomStart / rhs,
            bottomEnd: lhs.bottomEnd / rhs
        )
    }

    /// Integer divides each corner of the BorderRadiusDirectional by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:740-747`
    public func truncatingDivision(_ other: Double) -> any BorderRadiusGeometry {
        BorderRadiusDirectional.only(
            topStart: topStart.truncatingDivision(other),
            topEnd: topEnd.truncatingDivision(other),
            bottomStart: bottomStart.truncatingDivision(other),
            bottomEnd: bottomEnd.truncatingDivision(other)
        )
    }

    /// Computes the remainder of each corner by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:751-758`
    public func remainder(_ other: Double) -> any BorderRadiusGeometry {
        BorderRadiusDirectional.only(
            topStart: topStart.remainder(other),
            topEnd: topEnd.remainder(other),
            bottomStart: bottomStart.remainder(other),
            bottomEnd: bottomEnd.remainder(other)
        )
    }

    /// Linearly interpolate between two BorderRadiusDirectional objects.
    ///
    /// If either is nil, this function interpolates from `BorderRadiusDirectional.zero`.
    ///
    /// **Dart Source:** `border_radius.dart:765-785`
    public static func lerp(_ a: BorderRadiusDirectional?, _ b: BorderRadiusDirectional?, _ t: Double) -> BorderRadiusDirectional? {
        if let a = a, let b = b,
           a.topStart == b.topStart &&
           a.topEnd == b.topEnd &&
           a.bottomStart == b.bottomStart &&
           a.bottomEnd == b.bottomEnd {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return b * t
        }
        if b == nil {
            guard let a = a else { return nil }
            return a * (1.0 - t)
        }
        guard let a = a, let b = b else { return nil }
        return BorderRadiusDirectional.only(
            topStart: Radius.lerp(a.topStart, b.topStart, t)!,
            topEnd: Radius.lerp(a.topEnd, b.topEnd, t)!,
            bottomStart: Radius.lerp(a.bottomStart, b.bottomStart, t)!,
            bottomEnd: Radius.lerp(a.bottomEnd, b.bottomEnd, t)!
        )
    }

    /// Resolves this BorderRadiusDirectional to a BorderRadius.
    ///
    /// **Dart Source:** `border_radius.dart:788-806`
    public func resolve(_ direction: TextDirection?) -> BorderRadius {
        assert(debugCheckCanResolveTextDirection(direction, "\(Self.self)"))
        switch direction! {
        case .rtl:
            return BorderRadius.only(
                topLeft: topEnd,
                topRight: topStart,
                bottomLeft: bottomEnd,
                bottomRight: bottomStart
            )
        case .ltr:
            return BorderRadius.only(
                topLeft: topStart,
                topRight: topEnd,
                bottomLeft: bottomStart,
                bottomRight: bottomEnd
            )
        @unknown default:
            return BorderRadius.only(
                topLeft: topStart,
                topRight: topEnd,
                bottomLeft: bottomStart,
                bottomRight: bottomEnd
            )
        }
    }
}

// MARK: - MixedBorderRadius

/// A border radius combining both BorderRadius (physical corners) and
/// BorderRadiusDirectional (logical corners) components.
///
/// This is an internal type used when adding or lerping between BorderRadius
/// and BorderRadiusDirectional objects.
///
/// **Dart Source:** `border_radius.dart:809-936`
public struct MixedBorderRadius: BorderRadiusGeometry, Sendable {
    /// The top-left radius.
    public let _topLeft: Radius
    /// The top-right radius.
    public let _topRight: Radius
    /// The bottom-left radius.
    public let _bottomLeft: Radius
    /// The bottom-right radius.
    public let _bottomRight: Radius
    /// The top-start radius.
    public let _topStart: Radius
    /// The top-end radius.
    public let _topEnd: Radius
    /// The bottom-start radius.
    public let _bottomStart: Radius
    /// The bottom-end radius.
    public let _bottomEnd: Radius

    /// Creates a mixed border radius.
    ///
    /// **Dart Source:** `border_radius.dart:810-819`
    public init(
        topLeft: Radius,
        topRight: Radius,
        bottomLeft: Radius,
        bottomRight: Radius,
        topStart: Radius,
        topEnd: Radius,
        bottomStart: Radius,
        bottomEnd: Radius
    ) {
        self._topLeft = topLeft
        self._topRight = topRight
        self._bottomLeft = bottomLeft
        self._bottomRight = bottomRight
        self._topStart = topStart
        self._topEnd = topEnd
        self._bottomStart = bottomStart
        self._bottomEnd = bottomEnd
    }

    /// Returns the MixedBorderRadius object with each corner negated.
    ///
    /// **Dart Source:** `border_radius.dart:846-857`
    public func negated() -> any BorderRadiusGeometry {
        MixedBorderRadius(
            topLeft: -_topLeft,
            topRight: -_topRight,
            bottomLeft: -_bottomLeft,
            bottomRight: -_bottomRight,
            topStart: -_topStart,
            topEnd: -_topEnd,
            bottomStart: -_bottomStart,
            bottomEnd: -_bottomEnd
        )
    }

    /// Scales each corner of the MixedBorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:861-872`
    public func multiplied(by other: Double) -> any BorderRadiusGeometry {
        MixedBorderRadius(
            topLeft: _topLeft * other,
            topRight: _topRight * other,
            bottomLeft: _bottomLeft * other,
            bottomRight: _bottomRight * other,
            topStart: _topStart * other,
            topEnd: _topEnd * other,
            bottomStart: _bottomStart * other,
            bottomEnd: _bottomEnd * other
        )
    }

    /// Divides each corner of the MixedBorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:875-886`
    public func divided(by other: Double) -> any BorderRadiusGeometry {
        MixedBorderRadius(
            topLeft: _topLeft / other,
            topRight: _topRight / other,
            bottomLeft: _bottomLeft / other,
            bottomRight: _bottomRight / other,
            topStart: _topStart / other,
            topEnd: _topEnd / other,
            bottomStart: _bottomStart / other,
            bottomEnd: _bottomEnd / other
        )
    }

    /// Integer divides each corner of the MixedBorderRadius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:889-900`
    public func truncatingDivision(_ other: Double) -> any BorderRadiusGeometry {
        MixedBorderRadius(
            topLeft: _topLeft.truncatingDivision(other),
            topRight: _topRight.truncatingDivision(other),
            bottomLeft: _bottomLeft.truncatingDivision(other),
            bottomRight: _bottomRight.truncatingDivision(other),
            topStart: _topStart.truncatingDivision(other),
            topEnd: _topEnd.truncatingDivision(other),
            bottomStart: _bottomStart.truncatingDivision(other),
            bottomEnd: _bottomEnd.truncatingDivision(other)
        )
    }

    /// Computes the remainder of each corner by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:903-914`
    public func remainder(_ other: Double) -> any BorderRadiusGeometry {
        MixedBorderRadius(
            topLeft: _topLeft.remainder(other),
            topRight: _topRight.remainder(other),
            bottomLeft: _bottomLeft.remainder(other),
            bottomRight: _bottomRight.remainder(other),
            topStart: _topStart.remainder(other),
            topEnd: _topEnd.remainder(other),
            bottomStart: _bottomStart.remainder(other),
            bottomEnd: _bottomEnd.remainder(other)
        )
    }

    /// Resolves this mixed border radius to a concrete BorderRadius.
    ///
    /// **Dart Source:** `border_radius.dart:917-935`
    public func resolve(_ direction: TextDirection?) -> BorderRadius {
        assert(debugCheckCanResolveTextDirection(direction, "\(Self.self)"))
        switch direction! {
        case .rtl:
            return BorderRadius.only(
                topLeft: _topLeft + _topEnd,
                topRight: _topRight + _topStart,
                bottomLeft: _bottomLeft + _bottomEnd,
                bottomRight: _bottomRight + _bottomStart
            )
        case .ltr:
            return BorderRadius.only(
                topLeft: _topLeft + _topStart,
                topRight: _topRight + _topEnd,
                bottomLeft: _bottomLeft + _bottomStart,
                bottomRight: _bottomRight + _bottomEnd
            )
        @unknown default:
            return BorderRadius.only(
                topLeft: _topLeft + _topStart,
                topRight: _topRight + _topEnd,
                bottomLeft: _bottomLeft + _bottomStart,
                bottomRight: _bottomRight + _bottomEnd
            )
        }
    }
}

// MARK: - Radius Extension

/// Extension to add truncating division and remainder operations to Radius.
extension Radius {
    /// Integer divides this Radius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:539-546` (used by BorderRadius)
    public func truncatingDivision(_ other: Double) -> Radius {
        Radius(
            elliptical: Double(Int(x / other)),
            Double(Int(y / other))
        )
    }

    /// Computes the remainder of this Radius by the given factor.
    ///
    /// **Dart Source:** `border_radius.dart:550-557` (used by BorderRadius)
    public func remainder(_ other: Double) -> Radius {
        Radius(
            elliptical: x.truncatingRemainder(dividingBy: other),
            y.truncatingRemainder(dividingBy: other)
        )
    }
}
