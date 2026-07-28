// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Border specification for Table widgets.
///
/// This is like `Border`, with the addition of two sides: the inner horizontal
/// borders between rows and the inner vertical borders between columns.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/table_border.dart`

import FlutterSwiftBridge

// MARK: - TableBorder

/// Border specification for `Table` widgets.
///
/// This is like `Border`, with the addition of two sides: the inner horizontal
/// borders between rows and the inner vertical borders between columns.
///
/// The sides are represented by `BorderSide` objects.
///
/// **Dart Source:** `table_border.dart:18-361`
public struct TableBorder: Equatable, Hashable, CustomStringConvertible {

    // MARK: - Properties

    /// The top side of this border.
    ///
    /// **Dart Source:** `table_border.dart:67`
    public let top: BorderSide

    /// The right side of this border.
    ///
    /// **Dart Source:** `table_border.dart:70`
    public let right: BorderSide

    /// The bottom side of this border.
    ///
    /// **Dart Source:** `table_border.dart:73`
    public let bottom: BorderSide

    /// The left side of this border.
    ///
    /// **Dart Source:** `table_border.dart:76`
    public let left: BorderSide

    /// The horizontal interior sides of this border.
    ///
    /// **Dart Source:** `table_border.dart:79`
    public let horizontalInside: BorderSide

    /// The vertical interior sides of this border.
    ///
    /// **Dart Source:** `table_border.dart:82`
    public let verticalInside: BorderSide

    /// The `BorderRadius` to use when painting the corners of this border.
    ///
    /// It is also applied to `DataTable`'s `Material`.
    ///
    /// **Dart Source:** `table_border.dart:87`
    public let borderRadius: BorderRadius

    // MARK: - Initializer

    /// Creates a border for a table.
    ///
    /// All the sides of the border default to `BorderSide.none`.
    ///
    /// **Dart Source:** `table_border.dart:22-30`
    public init(
        top: BorderSide = .none,
        right: BorderSide = .none,
        bottom: BorderSide = .none,
        left: BorderSide = .none,
        horizontalInside: BorderSide = .none,
        verticalInside: BorderSide = .none,
        borderRadius: BorderRadius = .zero
    ) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
        self.horizontalInside = horizontalInside
        self.verticalInside = verticalInside
        self.borderRadius = borderRadius
    }

    // MARK: - Factory Methods

    /// A uniform border with all sides the same color and width.
    ///
    /// The sides default to black solid borders, one logical pixel wide.
    ///
    /// **Dart Source:** `table_border.dart:35-51`
    public static func all(
        color: Color = Color(0xFF000000),
        width: Double = 1.0,
        style: BorderStyle = .solid,
        borderRadius: BorderRadius = .zero
    ) -> TableBorder {
        let side = BorderSide(color: color, width: width, style: style)
        return TableBorder(
            top: side,
            right: side,
            bottom: side,
            left: side,
            horizontalInside: side,
            verticalInside: side,
            borderRadius: borderRadius
        )
    }

    /// Creates a border for a table where all the interior sides use the same
    /// styling and all the exterior sides use the same styling.
    ///
    /// **Dart Source:** `table_border.dart:55-64`
    public static func symmetric(
        inside: BorderSide = .none,
        outside: BorderSide = .none,
        borderRadius: BorderRadius = .zero
    ) -> TableBorder {
        return TableBorder(
            top: outside,
            right: outside,
            bottom: outside,
            left: outside,
            horizontalInside: inside,
            verticalInside: inside,
            borderRadius: borderRadius
        )
    }

    // MARK: - Computed Properties

    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// This can be used, for example, with a `Padding` widget to inset a box by
    /// the size of these borders.
    ///
    /// **Dart Source:** `table_border.dart:93-95`
    public var dimensions: EdgeInsets {
        EdgeInsets.fromLTRB(left.width, top.width, right.width, bottom.width)
    }

    /// Whether all the sides of the border (outside and inside) are identical.
    /// Uniform borders are typically more efficient to paint.
    ///
    /// **Dart Source:** `table_border.dart:99-103`
    public var isUniform: Bool {
        _allSidesMatch({ $0.color }) &&
        _allSidesMatch({ $0.width }) &&
        _allSidesMatch({ $0.style })
    }

    /// Whether all the outer sides of the border are identical.
    ///
    /// **Dart Source:** `table_border.dart:106-110`
    private var _outerBorderIsUniform: Bool {
        _outerSidesMatch({ $0.color }) &&
        _outerSidesMatch({ $0.width }) &&
        _outerSidesMatch({ $0.style })
    }

    // MARK: - Private Helpers

    /// Returns true if all six sides (outer + inner) have the same value for the
    /// given selector.
    ///
    /// **Dart Source:** `table_border.dart:112-120`
    private func _allSidesMatch<T: Equatable>(_ selector: (BorderSide) -> T) -> Bool {
        let topValue = selector(top)
        return selector(right) == topValue &&
            selector(bottom) == topValue &&
            selector(left) == topValue &&
            selector(horizontalInside) == topValue &&
            selector(verticalInside) == topValue
    }

    /// Returns true if all four outer sides have the same value for the given selector.
    ///
    /// **Dart Source:** `table_border.dart:122-128`
    private func _outerSidesMatch<T: Equatable>(_ selector: (BorderSide) -> T) -> Bool {
        let topValue = selector(top)
        return selector(right) == topValue &&
            selector(bottom) == topValue &&
            selector(left) == topValue
    }

    /// Returns the set of distinct visible colors from the outer border sides.
    ///
    /// Only includes colors from border sides that are not `BorderStyle.none`.
    ///
    /// **Dart Source:** `table_border.dart:133-140`
    private func _distinctVisibleOuterColors() -> Set<Color> {
        var colors = Set<Color>()
        if top.style != .none { colors.insert(top.color) }
        if right.style != .none { colors.insert(right.color) }
        if bottom.style != .none { colors.insert(bottom.color) }
        if left.style != .none { colors.insert(left.color) }
        return colors
    }

    // MARK: - Private Painting Methods

    /// Paints the outer table border.
    ///
    /// **Dart Source:** `table_border.dart:142-167`
    private func _paintTableBorder(_ canvas: Canvas, _ rect: Rect) {
        if _outerBorderIsUniform && borderRadius != .zero {
            let outer = borderRadius.toRRect(rect)
            let inner = outer.deflate(top.width)
            let paint = Paint()
            paint.color = top.color
            canvas.drawDRRect(outer, inner, paint)
            return
        }

        let visibleColors = _distinctVisibleOuterColors()
        if visibleColors.count == 1 && borderRadius != .zero {
            TableBorder._paintNonUniformBorderWithRadius(
                canvas,
                rect,
                borderRadius: borderRadius,
                color: visibleColors.first!,
                top: top.style == .none ? .none : top,
                right: right.style == .none ? .none : right,
                bottom: bottom.style == .none ? .none : bottom,
                left: left.style == .none ? .none : left
            )
            return
        }

        paintBorder(canvas, rect, top: top, right: right, bottom: bottom, left: left)
    }

    /// Paints a non-uniform border with border radius support.
    ///
    /// This is similar to `BoxBorder.paintNonUniformBorder` but adapted for table borders.
    ///
    /// **Dart Source:** `table_border.dart:172-200`
    private static func _paintNonUniformBorderWithRadius(
        _ canvas: Canvas,
        _ rect: Rect,
        borderRadius: BorderRadius,
        color: Color,
        top: BorderSide,
        right: BorderSide,
        bottom: BorderSide,
        left: BorderSide
    ) {
        let borderRect = borderRadius.toRRect(rect)
        let paint = Paint()
        paint.color = color

        let inner = EdgeInsets.fromLTRB(
            left.strokeInset,
            top.strokeInset,
            right.strokeInset,
            bottom.strokeInset
        ).deflateRRect(borderRect)

        let outer = EdgeInsets.fromLTRB(
            left.strokeOutset,
            top.strokeOutset,
            right.strokeOutset,
            bottom.strokeOutset
        ).inflateRRect(borderRect)

        canvas.drawDRRect(outer, inner, paint)
    }

    // MARK: - Instance Methods

    /// Creates a copy of this border but with the widths scaled by the factor `t`.
    ///
    /// The `t` argument represents the multiplicand, or the position on the
    /// timeline for an interpolation from nothing to `this`, with 0.0 meaning
    /// that the object returned should be the nil variant of this object, 1.0
    /// meaning that no change should be applied, returning `this` (or something
    /// equivalent to `this`), and other values meaning that the object should be
    /// multiplied by `t`. Negative values are treated like zero.
    ///
    /// Values for `t` are usually obtained from an `Animation<Double>`, such as
    /// an `AnimationController`.
    ///
    /// See also:
    ///
    ///  * `BorderSide.scale`, which is used to implement this method.
    ///
    /// **Dart Source:** `table_border.dart:217-226`
    public func scale(_ t: Double) -> TableBorder {
        return TableBorder(
            top: top.scale(t),
            right: right.scale(t),
            bottom: bottom.scale(t),
            left: left.scale(t),
            horizontalInside: horizontalInside.scale(t),
            verticalInside: verticalInside.scale(t)
        )
    }

    // MARK: - Static Methods

    /// Linearly interpolate between two table borders.
    ///
    /// If a border is nil, it is treated as having only `BorderSide.none`
    /// borders.
    ///
    /// **Dart Source:** `table_border.dart:234-252`
    public static func lerp(_ a: TableBorder?, _ b: TableBorder?, _ t: Double) -> TableBorder? {
        if a == b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        return TableBorder(
            top: BorderSide.lerp(a!.top, b!.top, t),
            right: BorderSide.lerp(a!.right, b!.right, t),
            bottom: BorderSide.lerp(a!.bottom, b!.bottom, t),
            left: BorderSide.lerp(a!.left, b!.left, t),
            horizontalInside: BorderSide.lerp(a!.horizontalInside, b!.horizontalInside, t),
            verticalInside: BorderSide.lerp(a!.verticalInside, b!.verticalInside, t)
        )
    }

    // MARK: - Paint

    /// Paints the border around the given `Rect` on the given `Canvas`, with the
    /// given rows and columns.
    ///
    /// Uniform borders are more efficient to paint than more complex borders.
    ///
    /// The `rows` argument specifies the vertical positions between the rows,
    /// relative to the given rectangle. For example, if the table contained two
    /// rows of height 100.0 each, then `rows` would contain a single value,
    /// 100.0, which is the vertical position between the two rows (relative to
    /// the top edge of `rect`).
    ///
    /// The `columns` argument specifies the horizontal positions between the
    /// columns, relative to the given rectangle. For example, if the table
    /// contained two columns of height 100.0 each, then `columns` would contain a
    /// single value, 100.0, which is the vertical position between the two
    /// columns (relative to the left edge of `rect`).
    ///
    /// The `verticalInside` border is only drawn if there are at least two
    /// columns. The `horizontalInside` border is only drawn if there are at least
    /// two rows. The horizontal borders are drawn after the vertical borders.
    ///
    /// The outer borders (in the order `top`, `right`, `bottom`, `left`, with
    /// `left` above the others) are painted after the inner borders.
    ///
    /// The paint order is particularly notable in the case of
    /// partially-transparent borders.
    ///
    /// **Dart Source:** `table_border.dart:280-334`
    public func paint(
        _ canvas: Canvas,
        _ rect: Rect,
        rows: [Double],
        columns: [Double]
    ) {
        assert(rows.isEmpty || (rows.first! >= 0.0 && rows.last! <= rect.height))
        assert(columns.isEmpty || (columns.first! >= 0.0 && columns.last! <= rect.width))

        if !columns.isEmpty || !rows.isEmpty {
            let paint = Paint()
            let path = Path()

            if !columns.isEmpty {
                switch verticalInside.style {
                case .solid:
                    paint.color = verticalInside.color
                    paint.strokeWidth = verticalInside.width
                    paint.style = .stroke
                    path.reset()
                    for x in columns {
                        path.moveTo(rect.left + x, rect.top)
                        path.lineTo(rect.left + x, rect.bottom)
                    }
                    canvas.drawPath(path, paint)
                case .none:
                    break
                }
            }

            if !rows.isEmpty {
                switch horizontalInside.style {
                case .solid:
                    paint.color = horizontalInside.color
                    paint.strokeWidth = horizontalInside.width
                    paint.style = .stroke
                    path.reset()
                    for y in rows {
                        path.moveTo(rect.left, rect.top + y)
                        path.lineTo(rect.right, rect.top + y)
                    }
                    canvas.drawPath(path, paint)
                case .none:
                    break
                }
            }
        }

        _paintTableBorder(canvas, rect)
    }

    // MARK: - Equatable

    /// **Dart Source:** `table_border.dart:337-352`
    public static func == (lhs: TableBorder, rhs: TableBorder) -> Bool {
        return lhs.top == rhs.top &&
            lhs.right == rhs.right &&
            lhs.bottom == rhs.bottom &&
            lhs.left == rhs.left &&
            lhs.horizontalInside == rhs.horizontalInside &&
            lhs.verticalInside == rhs.verticalInside &&
            lhs.borderRadius == rhs.borderRadius
    }

    // MARK: - Hashable

    /// **Dart Source:** `table_border.dart:355-356`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(top)
        hasher.combine(right)
        hasher.combine(bottom)
        hasher.combine(left)
        hasher.combine(horizontalInside)
        hasher.combine(verticalInside)
        hasher.combine(borderRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `table_border.dart:359-360`
    public var description: String {
        "TableBorder(\(top), \(right), \(bottom), \(left), \(horizontalInside), \(verticalInside), \(borderRadius))"
    }
}
