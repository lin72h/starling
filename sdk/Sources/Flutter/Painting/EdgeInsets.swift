// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Edge insets for positioning and padding.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/edge_insets.dart`

import FlutterSwiftBridge

// MARK: - EdgeInsetsGeometry

/// Base protocol for `EdgeInsets` that allows for text-direction aware resolution.
///
/// A property or argument of this type accepts classes created either with
/// `EdgeInsets.fromLTRB` and its variants, or `EdgeInsetsDirectional.fromSTEB`
/// and its variants.
///
/// To convert an `EdgeInsetsGeometry` object of indeterminate type into an
/// `EdgeInsets` object, call the `resolve` method.
///
/// **Dart Source:** `edge_insets.dart:31-343`
public protocol EdgeInsetsGeometry: Hashable, CustomStringConvertible {
    /// Internal left offset.
    var _left: Double { get }
    /// Internal right offset.
    var _right: Double { get }
    /// Internal start offset.
    var _start: Double { get }
    /// Internal end offset.
    var _end: Double { get }
    /// Internal top offset.
    var _top: Double { get }
    /// Internal bottom offset.
    var _bottom: Double { get }

    /// Convert this instance into an `EdgeInsets`, which uses literal coordinates.
    ///
    /// **Dart Source:** `edge_insets.dart:288-297`
    func resolve(_ direction: TextDirection?) -> EdgeInsets
}

// MARK: - EdgeInsetsGeometry Extension

extension EdgeInsetsGeometry {
    /// Whether every dimension is non-negative.
    ///
    /// **Dart Source:** `edge_insets.dart:96-103`
    public var isNonNegative: Bool {
        _left >= 0.0 &&
        _right >= 0.0 &&
        _start >= 0.0 &&
        _end >= 0.0 &&
        _top >= 0.0 &&
        _bottom >= 0.0
    }

    /// The total offset in the horizontal direction.
    ///
    /// **Dart Source:** `edge_insets.dart:105-106`
    public var horizontal: Double { _left + _right + _start + _end }

    /// The total offset in the vertical direction.
    ///
    /// **Dart Source:** `edge_insets.dart:108-109`
    public var vertical: Double { _top + _bottom }

    /// The total offset in the given direction.
    ///
    /// **Dart Source:** `edge_insets.dart:111-117`
    public func along(_ axis: Axis) -> Double {
        switch axis {
        case .horizontal: return horizontal
        case .vertical: return vertical
        }
    }

    /// The size that this EdgeInsets would occupy with an empty interior.
    ///
    /// **Dart Source:** `edge_insets.dart:119-120`
    public var collapsedSize: Size { Size(horizontal, vertical) }

    /// Returns a new size that is bigger than the given size by the amount of
    /// inset in the horizontal and vertical directions.
    ///
    /// **Dart Source:** `edge_insets.dart:135-137`
    public func inflateSize(_ size: Size) -> Size {
        Size(size.width + horizontal, size.height + vertical)
    }

    /// Returns a new size that is smaller than the given size by the amount of
    /// inset in the horizontal and vertical directions.
    ///
    /// **Dart Source:** `edge_insets.dart:151-153`
    public func deflateSize(_ size: Size) -> Size {
        Size(size.width - horizontal, size.height - vertical)
    }

    /// Returns the sum of two EdgeInsetsGeometry objects.
    ///
    /// **Dart Source:** `edge_insets.dart:193-202`
    public func add(_ other: any EdgeInsetsGeometry) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: _left + other._left,
            right: _right + other._right,
            start: _start + other._start,
            end: _end + other._end,
            top: _top + other._top,
            bottom: _bottom + other._bottom
        )
    }

    /// Returns the difference between two EdgeInsetsGeometry objects.
    ///
    /// **Dart Source:** `edge_insets.dart:171-180`
    public func subtract(_ other: any EdgeInsetsGeometry) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: _left - other._left,
            right: _right - other._right,
            start: _start - other._start,
            end: _end - other._end,
            top: _top - other._top,
            bottom: _bottom - other._bottom
        )
    }

    /// Default description implementation.
    ///
    /// **Dart Source:** `edge_insets.dart:300-328`
    public var description: String {
        if _start == 0.0 && _end == 0.0 {
            if _left == 0.0 && _right == 0.0 && _top == 0.0 && _bottom == 0.0 {
                return "EdgeInsets.zero"
            }
            if _left == _right && _right == _top && _top == _bottom {
                return "EdgeInsets.all(\(String(format: "%.1f", _left)))"
            }
            return "EdgeInsets(\(String(format: "%.1f", _left)), " +
                   "\(String(format: "%.1f", _top)), " +
                   "\(String(format: "%.1f", _right)), " +
                   "\(String(format: "%.1f", _bottom)))"
        }
        if _left == 0.0 && _right == 0.0 {
            return "EdgeInsetsDirectional(\(String(format: "%.1f", _start)), " +
                   "\(String(format: "%.1f", _top)), " +
                   "\(String(format: "%.1f", _end)), " +
                   "\(String(format: "%.1f", _bottom)))"
        }
        return "EdgeInsets(\(String(format: "%.1f", _left)), " +
               "\(String(format: "%.1f", _top)), " +
               "\(String(format: "%.1f", _right)), " +
               "\(String(format: "%.1f", _bottom)))" +
               " + " +
               "EdgeInsetsDirectional(\(String(format: "%.1f", _start)), " +
               "0.0, " +
               "\(String(format: "%.1f", _end)), " +
               "0.0)"
    }

    /// Default hash implementation.
    ///
    /// **Dart Source:** `edge_insets.dart:342`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_left)
        hasher.combine(_right)
        hasher.combine(_start)
        hasher.combine(_end)
        hasher.combine(_top)
        hasher.combine(_bottom)
    }
}

/// Equality for EdgeInsetsGeometry.
///
/// **Dart Source:** `edge_insets.dart:331-339`
public func == (lhs: any EdgeInsetsGeometry, rhs: any EdgeInsetsGeometry) -> Bool {
    lhs._left == rhs._left &&
    lhs._right == rhs._right &&
    lhs._start == rhs._start &&
    lhs._end == rhs._end &&
    lhs._top == rhs._top &&
    lhs._bottom == rhs._bottom
}

// MARK: - EdgeInsetsGeometry Static Methods

/// Extension providing static methods for `EdgeInsetsGeometry`.
public enum EdgeInsetsGeometryStatics {
    /// An EdgeInsets with zero offsets in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:74`
    public static var zero: any EdgeInsetsGeometry { EdgeInsets.zero }

    /// Linearly interpolate between two EdgeInsetsGeometry objects.
    ///
    /// **Dart Source:** `edge_insets.dart:262-286`
    public static func lerp(
        _ a: (any EdgeInsetsGeometry)?,
        _ b: (any EdgeInsetsGeometry)?,
        _ t: Double
    ) -> (any EdgeInsetsGeometry)? {
        if let aVal = a, let bVal = b,
           aVal._left == bVal._left &&
           aVal._right == bVal._right &&
           aVal._start == bVal._start &&
           aVal._end == bVal._end &&
           aVal._top == bVal._top &&
           aVal._bottom == bVal._bottom {
            return a
        }
        if a == nil {
            guard let b = b else { return nil }
            return MixedEdgeInsets(
                left: b._left * t,
                right: b._right * t,
                start: b._start * t,
                end: b._end * t,
                top: b._top * t,
                bottom: b._bottom * t
            )
        }
        if b == nil {
            guard let a = a else { return nil }
            let factor = 1.0 - t
            return MixedEdgeInsets(
                left: a._left * factor,
                right: a._right * factor,
                start: a._start * factor,
                end: a._end * factor,
                top: a._top * factor,
                bottom: a._bottom * factor
            )
        }
        guard let a = a, let b = b else { return nil }

        // Check if both are EdgeInsets
        if let aInsets = a as? EdgeInsets, let bInsets = b as? EdgeInsets {
            return EdgeInsets.lerp(aInsets, bInsets, t)
        }
        // Check if both are EdgeInsetsDirectional
        if let aDir = a as? EdgeInsetsDirectional, let bDir = b as? EdgeInsetsDirectional {
            return EdgeInsetsDirectional.lerp(aDir, bDir, t)
        }
        // Mixed case
        return MixedEdgeInsets(
            left: lerpDouble(a._left, b._left, t)!,
            right: lerpDouble(a._right, b._right, t)!,
            start: lerpDouble(a._start, b._start, t)!,
            end: lerpDouble(a._end, b._end, t)!,
            top: lerpDouble(a._top, b._top, t)!,
            bottom: lerpDouble(a._bottom, b._bottom, t)!
        )
    }
}

// MARK: - MixedEdgeInsets

/// A mixed edge insets combining both EdgeInsets (left/right) and
/// EdgeInsetsDirectional (start/end) components.
///
/// This is an internal type used when adding or lerping between EdgeInsets
/// and EdgeInsetsDirectional objects.
///
/// **Dart Source:** `edge_insets.dart:976-1075`
public struct MixedEdgeInsets: EdgeInsetsGeometry, Sendable {
    /// The left offset.
    public let _left: Double
    /// The right offset.
    public let _right: Double
    /// The start offset.
    public let _start: Double
    /// The end offset.
    public let _end: Double
    /// The top offset.
    public let _top: Double
    /// The bottom offset.
    public let _bottom: Double

    /// Creates a mixed edge insets.
    ///
    /// **Dart Source:** `edge_insets.dart:977-984`
    public init(
        left: Double,
        right: Double,
        start: Double,
        end: Double,
        top: Double,
        bottom: Double
    ) {
        self._left = left
        self._right = right
        self._start = start
        self._end = end
        self._top = top
        self._bottom = bottom
    }

    /// Whether every dimension is non-negative.
    ///
    /// **Dart Source:** `edge_insets.dart:1005-1012`
    public var isNonNegative: Bool {
        _left >= 0.0 &&
        _right >= 0.0 &&
        _start >= 0.0 &&
        _end >= 0.0 &&
        _top >= 0.0 &&
        _bottom >= 0.0
    }

    /// Returns the negation of this edge insets.
    ///
    /// **Dart Source:** `edge_insets.dart:1015-1017`
    public static prefix func - (insets: MixedEdgeInsets) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: -insets._left,
            right: -insets._right,
            start: -insets._start,
            end: -insets._end,
            top: -insets._top,
            bottom: -insets._bottom
        )
    }

    /// Scales this edge insets by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:1020-1029`
    public static func * (lhs: MixedEdgeInsets, rhs: Double) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: lhs._left * rhs,
            right: lhs._right * rhs,
            start: lhs._start * rhs,
            end: lhs._end * rhs,
            top: lhs._top * rhs,
            bottom: lhs._bottom * rhs
        )
    }

    /// Divides this edge insets by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:1032-1041`
    public static func / (lhs: MixedEdgeInsets, rhs: Double) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: lhs._left / rhs,
            right: lhs._right / rhs,
            start: lhs._start / rhs,
            end: lhs._end / rhs,
            top: lhs._top / rhs,
            bottom: lhs._bottom / rhs
        )
    }

    /// Integer divides this edge insets by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:1044-1053`
    public func truncatingDivision(_ other: Double) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: Double(Int(_left / other)),
            right: Double(Int(_right / other)),
            start: Double(Int(_start / other)),
            end: Double(Int(_end / other)),
            top: Double(Int(_top / other)),
            bottom: Double(Int(_bottom / other))
        )
    }

    /// Computes the remainder in each dimension.
    ///
    /// **Dart Source:** `edge_insets.dart:1056-1065`
    public static func % (lhs: MixedEdgeInsets, rhs: Double) -> MixedEdgeInsets {
        MixedEdgeInsets(
            left: lhs._left.truncatingRemainder(dividingBy: rhs),
            right: lhs._right.truncatingRemainder(dividingBy: rhs),
            start: lhs._start.truncatingRemainder(dividingBy: rhs),
            end: lhs._end.truncatingRemainder(dividingBy: rhs),
            top: lhs._top.truncatingRemainder(dividingBy: rhs),
            bottom: lhs._bottom.truncatingRemainder(dividingBy: rhs)
        )
    }

    /// Resolves this mixed edge insets to a concrete EdgeInsets.
    ///
    /// **Dart Source:** `edge_insets.dart:1068-1074`
    public func resolve(_ direction: TextDirection?) -> EdgeInsets {
        switch direction! {
        case .rtl:
            return EdgeInsets.fromLTRB(_end + _left, _top, _start + _right, _bottom)
        case .ltr:
            return EdgeInsets.fromLTRB(_start + _left, _top, _end + _right, _bottom)
        @unknown default:
            return EdgeInsets.fromLTRB(_start + _left, _top, _end + _right, _bottom)
        }
    }
}

// MARK: - EdgeInsets

/// An immutable set of offsets in each of the four cardinal directions.
///
/// Typically used for an offset from each of the four sides of a box. For
/// example, the padding inside a box can be represented using this class.
///
/// The `EdgeInsets` class specifies offsets in terms of visual edges, left,
/// top, right, and bottom. These values are not affected by the TextDirection.
///
/// **Dart Source:** `edge_insets.dart:390-729`
public struct EdgeInsets: EdgeInsetsGeometry, Sendable {
    /// The offset from the left.
    ///
    /// **Dart Source:** `edge_insets.dart:459-463`
    public let left: Double

    /// The offset from the top.
    ///
    /// **Dart Source:** `edge_insets.dart:465-469`
    public let top: Double

    /// The offset from the right.
    ///
    /// **Dart Source:** `edge_insets.dart:471-475`
    public let right: Double

    /// The offset from the bottom.
    ///
    /// **Dart Source:** `edge_insets.dart:477-481`
    public let bottom: Double

    // MARK: - EdgeInsetsGeometry Protocol

    /// **Dart Source:** `edge_insets.dart:462-463`
    public var _left: Double { left }

    /// **Dart Source:** `edge_insets.dart:468-469`
    public var _top: Double { top }

    /// **Dart Source:** `edge_insets.dart:474-475`
    public var _right: Double { right }

    /// **Dart Source:** `edge_insets.dart:480-481`
    public var _bottom: Double { bottom }

    /// **Dart Source:** `edge_insets.dart:483-484`
    public var _start: Double { 0.0 }

    /// **Dart Source:** `edge_insets.dart:486-487`
    public var _end: Double { 0.0 }

    // MARK: - Initializers

    /// Creates insets from offsets from the left, top, right, and bottom.
    ///
    /// **Dart Source:** `edge_insets.dart:391-392`
    public static func fromLTRB(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> EdgeInsets {
        EdgeInsets(left: left, top: top, right: right, bottom: bottom)
    }

    /// Creates insets where all the offsets are `value`.
    ///
    /// **Dart Source:** `edge_insets.dart:394-404`
    public init(all value: Double) {
        self.left = value
        self.top = value
        self.right = value
        self.bottom = value
    }

    /// Creates insets with only the given values non-zero.
    ///
    /// **Dart Source:** `edge_insets.dart:406-416`
    public init(left: Double = 0.0, top: Double = 0.0, right: Double = 0.0, bottom: Double = 0.0) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// Creates insets with symmetrical vertical and horizontal offsets.
    ///
    /// **Dart Source:** `edge_insets.dart:418-432`
    public init(horizontal: Double = 0.0, vertical: Double = 0.0) {
        self.left = horizontal
        self.right = horizontal
        self.top = vertical
        self.bottom = vertical
    }

    // MARK: - Static Constants

    /// An EdgeInsets with zero offsets in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:456-457`
    public static let zero = EdgeInsets(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0)

    // MARK: - Computed Properties

    /// An Offset describing the vector from the top left of a rectangle to the
    /// top left of that rectangle inset by this object.
    ///
    /// **Dart Source:** `edge_insets.dart:489-491`
    public var topLeft: Offset { Offset(left, top) }

    /// An Offset describing the vector from the top right of a rectangle to the
    /// top right of that rectangle inset by this object.
    ///
    /// **Dart Source:** `edge_insets.dart:493-495`
    public var topRight: Offset { Offset(-right, top) }

    /// An Offset describing the vector from the bottom left of a rectangle to the
    /// bottom left of that rectangle inset by this object.
    ///
    /// **Dart Source:** `edge_insets.dart:497-499`
    public var bottomLeft: Offset { Offset(left, -bottom) }

    /// An Offset describing the vector from the bottom right of a rectangle to the
    /// bottom right of that rectangle inset by this object.
    ///
    /// **Dart Source:** `edge_insets.dart:501-503`
    public var bottomRight: Offset { Offset(-right, -bottom) }

    /// An EdgeInsets with top and bottom as well as left and right flipped.
    ///
    /// **Dart Source:** `edge_insets.dart:505-507`
    public var flipped: EdgeInsets {
        EdgeInsets.fromLTRB(right, bottom, left, top)
    }

    // MARK: - Rect Operations

    /// Returns a new rect that is bigger than the given rect in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:519-526`
    public func inflateRect(_ rect: Rect) -> Rect {
        Rect.fromLTRB(
            rect.left - left,
            rect.top - top,
            rect.right + right,
            rect.bottom + bottom
        )
    }

    /// Returns a new rect that is smaller than the given rect in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:541-548`
    public func deflateRect(_ rect: Rect) -> Rect {
        Rect.fromLTRB(
            rect.left + left,
            rect.top + top,
            rect.right - right,
            rect.bottom - bottom
        )
    }

    // MARK: - Operators

    /// Returns the difference between two EdgeInsets.
    ///
    /// **Dart Source:** `edge_insets.dart:637-644`
    public static func - (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        EdgeInsets.fromLTRB(
            lhs.left - rhs.left,
            lhs.top - rhs.top,
            lhs.right - rhs.right,
            lhs.bottom - rhs.bottom
        )
    }

    /// Returns the sum of two EdgeInsets.
    ///
    /// **Dart Source:** `edge_insets.dart:647-654`
    public static func + (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        EdgeInsets.fromLTRB(
            lhs.left + rhs.left,
            lhs.top + rhs.top,
            lhs.right + rhs.right,
            lhs.bottom + rhs.bottom
        )
    }

    /// Returns the EdgeInsets object with each dimension negated.
    ///
    /// **Dart Source:** `edge_insets.dart:659-661`
    public static prefix func - (insets: EdgeInsets) -> EdgeInsets {
        EdgeInsets.fromLTRB(-insets.left, -insets.top, -insets.right, -insets.bottom)
    }

    /// Scales the EdgeInsets in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:664-667`
    public static func * (lhs: EdgeInsets, rhs: Double) -> EdgeInsets {
        EdgeInsets.fromLTRB(lhs.left * rhs, lhs.top * rhs, lhs.right * rhs, lhs.bottom * rhs)
    }

    /// Divides the EdgeInsets in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:670-673`
    public static func / (lhs: EdgeInsets, rhs: Double) -> EdgeInsets {
        EdgeInsets.fromLTRB(lhs.left / rhs, lhs.top / rhs, lhs.right / rhs, lhs.bottom / rhs)
    }

    /// Integer divides the EdgeInsets in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:676-685`
    public func truncatingDivision(_ other: Double) -> EdgeInsets {
        EdgeInsets.fromLTRB(
            Double(Int(left / other)),
            Double(Int(top / other)),
            Double(Int(right / other)),
            Double(Int(bottom / other))
        )
    }

    /// Computes the remainder in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:688-691`
    public static func % (lhs: EdgeInsets, rhs: Double) -> EdgeInsets {
        EdgeInsets.fromLTRB(
            lhs.left.truncatingRemainder(dividingBy: rhs),
            lhs.top.truncatingRemainder(dividingBy: rhs),
            lhs.right.truncatingRemainder(dividingBy: rhs),
            lhs.bottom.truncatingRemainder(dividingBy: rhs)
        )
    }

    // MARK: - Lerp

    /// Linearly interpolate between two EdgeInsets.
    ///
    /// **Dart Source:** `edge_insets.dart:698-714`
    public static func lerp(_ a: EdgeInsets?, _ b: EdgeInsets?, _ t: Double) -> EdgeInsets? {
        if let a = a, let b = b,
           a.left == b.left && a.top == b.top &&
           a.right == b.right && a.bottom == b.bottom {
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
        return EdgeInsets.fromLTRB(
            lerpDouble(a.left, b.left, t)!,
            lerpDouble(a.top, b.top, t)!,
            lerpDouble(a.right, b.right, t)!,
            lerpDouble(a.bottom, b.bottom, t)!
        )
    }

    // MARK: - Resolve

    /// Returns this EdgeInsets unchanged.
    ///
    /// EdgeInsets does not depend on text direction, so resolving always
    /// returns self.
    ///
    /// **Dart Source:** `edge_insets.dart:716-717`
    public func resolve(_ direction: TextDirection?) -> EdgeInsets {
        self
    }

    // MARK: - Copy

    /// Creates a copy of this EdgeInsets but with the given fields replaced.
    ///
    /// **Dart Source:** `edge_insets.dart:719-728`
    public func copyWith(
        left: Double? = nil,
        top: Double? = nil,
        right: Double? = nil,
        bottom: Double? = nil
    ) -> EdgeInsets {
        EdgeInsets(
            left: left ?? self.left,
            top: top ?? self.top,
            right: right ?? self.right,
            bottom: bottom ?? self.bottom
        )
    }
}

// MARK: - EdgeInsetsDirectional

/// An immutable set of offsets in each of the four cardinal directions, but
/// whose horizontal components are dependent on the writing direction.
///
/// This can be used to indicate padding from the left in `TextDirection.ltr`
/// text and padding from the right in `TextDirection.rtl` text without having
/// to be aware of the current text direction.
///
/// **Dart Source:** `edge_insets.dart:742-973`
public struct EdgeInsetsDirectional: EdgeInsetsGeometry, Sendable {
    /// The offset from the start side.
    ///
    /// **Dart Source:** `edge_insets.dart:809-812`
    public let start: Double

    /// The offset from the top.
    ///
    /// **Dart Source:** `edge_insets.dart:818-821`
    public let top: Double

    /// The offset from the end side.
    ///
    /// **Dart Source:** `edge_insets.dart:828-831`
    public let end: Double

    /// The offset from the bottom.
    ///
    /// **Dart Source:** `edge_insets.dart:837-840`
    public let bottom: Double

    // MARK: - EdgeInsetsGeometry Protocol

    /// **Dart Source:** `edge_insets.dart:811-812`
    public var _start: Double { start }

    /// **Dart Source:** `edge_insets.dart:820-821`
    public var _top: Double { top }

    /// **Dart Source:** `edge_insets.dart:830-831`
    public var _end: Double { end }

    /// **Dart Source:** `edge_insets.dart:839-840`
    public var _bottom: Double { bottom }

    /// **Dart Source:** `edge_insets.dart:842-843`
    public var _left: Double { 0.0 }

    /// **Dart Source:** `edge_insets.dart:845-846`
    public var _right: Double { 0.0 }

    // MARK: - Initializers

    /// Creates insets from offsets from the start, top, end, and bottom.
    ///
    /// **Dart Source:** `edge_insets.dart:743-744`
    public static func fromSTEB(_ start: Double, _ top: Double, _ end: Double, _ bottom: Double) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional(start: start, top: top, end: end, bottom: bottom)
    }

    /// Creates insets with only the given values non-zero.
    ///
    /// **Dart Source:** `edge_insets.dart:756-761`
    public init(
        start: Double = 0.0,
        top: Double = 0.0,
        end: Double = 0.0,
        bottom: Double = 0.0
    ) {
        self.start = start
        self.top = top
        self.end = end
        self.bottom = bottom
    }

    /// Creates insets with symmetric vertical and horizontal offsets.
    ///
    /// **Dart Source:** `edge_insets.dart:776-780`
    public init(horizontal: Double = 0.0, vertical: Double = 0.0) {
        self.start = horizontal
        self.end = horizontal
        self.top = vertical
        self.bottom = vertical
    }

    /// Creates insets where all the offsets are `value`.
    ///
    /// **Dart Source:** `edge_insets.dart:792-796`
    public init(all value: Double) {
        self.start = value
        self.top = value
        self.end = value
        self.bottom = value
    }

    // MARK: - Static Constants

    /// An EdgeInsetsDirectional with zero offsets in each direction.
    ///
    /// **Dart Source:** `edge_insets.dart:802`
    public static let zero = EdgeInsetsDirectional(start: 0.0, top: 0.0, end: 0.0, bottom: 0.0)

    // MARK: - Computed Properties

    /// Whether every dimension is non-negative.
    ///
    /// **Dart Source:** `edge_insets.dart:848-849`
    public var isNonNegative: Bool {
        start >= 0.0 && top >= 0.0 && end >= 0.0 && bottom >= 0.0
    }

    /// An EdgeInsetsDirectional with top and bottom as well as start and end flipped.
    ///
    /// **Dart Source:** `edge_insets.dart:852-853`
    public var flipped: EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(end, bottom, start, top)
    }

    // MARK: - Operators

    /// Returns the difference between two EdgeInsetsDirectional objects.
    ///
    /// **Dart Source:** `edge_insets.dart:871-878`
    public static func - (lhs: EdgeInsetsDirectional, rhs: EdgeInsetsDirectional) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(
            lhs.start - rhs.start,
            lhs.top - rhs.top,
            lhs.end - rhs.end,
            lhs.bottom - rhs.bottom
        )
    }

    /// Returns the sum of two EdgeInsetsDirectional objects.
    ///
    /// **Dart Source:** `edge_insets.dart:881-888`
    public static func + (lhs: EdgeInsetsDirectional, rhs: EdgeInsetsDirectional) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(
            lhs.start + rhs.start,
            lhs.top + rhs.top,
            lhs.end + rhs.end,
            lhs.bottom + rhs.bottom
        )
    }

    /// Returns the EdgeInsetsDirectional object with each dimension negated.
    ///
    /// **Dart Source:** `edge_insets.dart:894-896`
    public static prefix func - (insets: EdgeInsetsDirectional) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(-insets.start, -insets.top, -insets.end, -insets.bottom)
    }

    /// Scales the EdgeInsetsDirectional object in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:900-902`
    public static func * (lhs: EdgeInsetsDirectional, rhs: Double) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(lhs.start * rhs, lhs.top * rhs, lhs.end * rhs, lhs.bottom * rhs)
    }

    /// Divides the EdgeInsetsDirectional object in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:906-908`
    public static func / (lhs: EdgeInsetsDirectional, rhs: Double) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(lhs.start / rhs, lhs.top / rhs, lhs.end / rhs, lhs.bottom / rhs)
    }

    /// Integer divides the EdgeInsetsDirectional object in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:912-920`
    public func truncatingDivision(_ other: Double) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(
            Double(Int(start / other)),
            Double(Int(top / other)),
            Double(Int(end / other)),
            Double(Int(bottom / other))
        )
    }

    /// Computes the remainder in each dimension by the given factor.
    ///
    /// **Dart Source:** `edge_insets.dart:924-926`
    public static func % (lhs: EdgeInsetsDirectional, rhs: Double) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional.fromSTEB(
            lhs.start.truncatingRemainder(dividingBy: rhs),
            lhs.top.truncatingRemainder(dividingBy: rhs),
            lhs.end.truncatingRemainder(dividingBy: rhs),
            lhs.bottom.truncatingRemainder(dividingBy: rhs)
        )
    }

    // MARK: - Lerp

    /// Linearly interpolate between two EdgeInsetsDirectional.
    ///
    /// **Dart Source:** `edge_insets.dart:937-953`
    public static func lerp(_ a: EdgeInsetsDirectional?, _ b: EdgeInsetsDirectional?, _ t: Double) -> EdgeInsetsDirectional? {
        if let a = a, let b = b,
           a.start == b.start && a.top == b.top &&
           a.end == b.end && a.bottom == b.bottom {
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
        return EdgeInsetsDirectional.fromSTEB(
            lerpDouble(a.start, b.start, t)!,
            lerpDouble(a.top, b.top, t)!,
            lerpDouble(a.end, b.end, t)!,
            lerpDouble(a.bottom, b.bottom, t)!
        )
    }

    // MARK: - Resolve

    /// Resolves this EdgeInsetsDirectional to an EdgeInsets.
    ///
    /// **Dart Source:** `edge_insets.dart:955-962`
    public func resolve(_ direction: TextDirection?) -> EdgeInsets {
        switch direction! {
        case .rtl:
            return EdgeInsets.fromLTRB(end, top, start, bottom)
        case .ltr:
            return EdgeInsets.fromLTRB(start, top, end, bottom)
        @unknown default:
            return EdgeInsets.fromLTRB(start, top, end, bottom)
        }
    }

    // MARK: - Copy

    /// Creates a copy of this EdgeInsetsDirectional but with the given fields replaced.
    ///
    /// **Dart Source:** `edge_insets.dart:964-973`
    public func copyWith(
        start: Double? = nil,
        top: Double? = nil,
        end: Double? = nil,
        bottom: Double? = nil
    ) -> EdgeInsetsDirectional {
        EdgeInsetsDirectional(
            start: start ?? self.start,
            top: top ?? self.top,
            end: end ?? self.end,
            bottom: bottom ?? self.bottom
        )
    }
}
