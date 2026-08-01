// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Border types for defining shape outlines.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/borders.dart`

import FlutterSwiftBridge

// MARK: - BorderStyle

/// The style of line to draw for a `BorderSide` in a `Border`.
///
/// **Dart Source:** `borders.dart:19-27`
public enum BorderStyle: Sendable, Hashable {
    /// Skip the border.
    case none

    /// Draw the border as a solid line.
    case solid
}

// MARK: - BorderSide

/// A side of a border of a box.
///
/// A `Border` consists of four `BorderSide` objects: `Border.top`,
/// `Border.left`, `Border.right`, and `Border.bottom`.
///
/// Setting `BorderSide.width` to 0.0 will result in hairline rendering; see
/// `BorderSide.width` for a more involved explanation.
///
/// **Dart Source:** `borders.dart:64-350`
public struct BorderSide: Hashable, Sendable {
    /// The color of this side of the border.
    ///
    /// **Dart Source:** `borders.dart:108-109`
    public let color: Color

    /// The width of this side of the border, in logical pixels.
    ///
    /// Setting width to 0.0 will result in a hairline border. This means that
    /// the border will have the width of one physical pixel. Hairline
    /// rendering takes shortcuts when the path overlaps a pixel more than once.
    /// This means that it will render faster than otherwise, but it might
    /// double-hit pixels, giving it a slightly darker/lighter result.
    ///
    /// To omit the border entirely, set the `style` to `BorderStyle.none`.
    ///
    /// **Dart Source:** `borders.dart:111-120`
    public let width: Double

    /// The style of this side of the border.
    ///
    /// To omit a side, set `style` to `BorderStyle.none`. This skips
    /// painting the border, but the border still has a `width`.
    ///
    /// **Dart Source:** `borders.dart:122-126`
    public let style: BorderStyle

    /// The relative position of the stroke on a `BorderSide` in an
    /// `OutlinedBorder` or `Border`.
    ///
    /// Values typically range from -1.0 (`strokeAlignInside`, inside border,
    /// default) to 1.0 (`strokeAlignOutside`, outside border), without any
    /// bound constraints (e.g., a value of -2.0 is not typical, but allowed).
    /// A value of 0 (`strokeAlignCenter`) will center the border on the edge
    /// of the widget.
    ///
    /// **Dart Source:** `borders.dart:131-160`
    public let strokeAlign: Double

    // MARK: - Static Constants

    /// A hairline black border that is not rendered.
    ///
    /// **Dart Source:** `borders.dart:128-129`
    public static let none = BorderSide(width: 0.0, style: .none)

    /// The border is drawn fully inside of the border path.
    ///
    /// This is a constant for use with `strokeAlign`.
    /// This is the default value for `strokeAlign`.
    ///
    /// **Dart Source:** `borders.dart:162-167`
    public static let strokeAlignInside: Double = -1.0

    /// The border is drawn on the center of the border path, with half of the
    /// `BorderSide.width` on the inside, and the other half on the outside of
    /// the path.
    ///
    /// This is a constant for use with `strokeAlign`.
    ///
    /// **Dart Source:** `borders.dart:169-174`
    public static let strokeAlignCenter: Double = 0.0

    /// The border is drawn on the outside of the border path.
    ///
    /// This is a constant for use with `strokeAlign`.
    ///
    /// **Dart Source:** `borders.dart:176-179`
    public static let strokeAlignOutside: Double = 1.0

    // MARK: - Initializer

    /// Creates the side of a border.
    ///
    /// By default, the border is 1.0 logical pixels wide and solid black.
    ///
    /// **Dart Source:** `borders.dart:66-74`
    public init(
        color: Color = Color(0xFF000000),
        width: Double = 1.0,
        style: BorderStyle = .solid,
        strokeAlign: Double = strokeAlignInside
    ) {
        assert(width >= 0.0, "width must be non-negative")
        self.color = color
        self.width = width
        self.style = style
        self.strokeAlign = strokeAlign
    }

    // MARK: - Static Methods

    /// Creates a `BorderSide` that represents the addition of the two given
    /// `BorderSide`s.
    ///
    /// It is only valid to call this if `canMerge` returns true for the two
    /// sides.
    ///
    /// **Dart Source:** `borders.dart:85-106`
    public static func merge(_ a: BorderSide, _ b: BorderSide) -> BorderSide {
        assert(canMerge(a, b), "Cannot merge: sides must have same color and style or be none")
        let aIsNone = a.style == .none && a.width == 0.0
        let bIsNone = b.style == .none && b.width == 0.0
        if aIsNone && bIsNone {
            return .none
        }
        if aIsNone {
            return b
        }
        if bIsNone {
            return a
        }
        assert(a.color == b.color, "Colors must match")
        assert(a.style == b.style, "Styles must match")
        return BorderSide(
            color: a.color,
            width: a.width + b.width,
            style: a.style,
            strokeAlign: max(a.strokeAlign, b.strokeAlign)
        )
    }

    /// Whether the two given `BorderSide`s can be merged using `BorderSide.merge`.
    ///
    /// Two sides can be merged if one or both are zero-width with
    /// `BorderStyle.none`, or if they both have the same color and style.
    ///
    /// **Dart Source:** `borders.dart:244-250`
    public static func canMerge(_ a: BorderSide, _ b: BorderSide) -> Bool {
        if (a.style == .none && a.width == 0.0) ||
           (b.style == .none && b.width == 0.0) {
            return true
        }
        return a.style == b.style && a.color == b.color
    }

    /// Linearly interpolate between two border sides.
    ///
    /// **Dart Source:** `borders.dart:255-297`
    public static func lerp(_ a: BorderSide, _ b: BorderSide, _ t: Double) -> BorderSide {
        if a == b {
            return a
        }
        if t == 0.0 {
            return a
        }
        if t == 1.0 {
            return b
        }
        let width = lerpDouble(a.width, b.width, t)!
        if width < 0.0 {
            return .none
        }
        if a.style == b.style && a.strokeAlign == b.strokeAlign {
            return BorderSide(
                color: Color.lerp(a.color, b.color, t)!,
                width: width,
                style: a.style,
                strokeAlign: a.strokeAlign
            )
        }
        let colorA: Color
        switch a.style {
        case .solid: colorA = a.color
        case .none: colorA = a.color.withAlpha(0)
        }
        let colorB: Color
        switch b.style {
        case .solid: colorB = b.color
        case .none: colorB = b.color.withAlpha(0)
        }
        if a.strokeAlign != b.strokeAlign {
            return BorderSide(
                color: Color.lerp(colorA, colorB, t)!,
                width: width,
                strokeAlign: lerpDouble(a.strokeAlign, b.strokeAlign, t)!
            )
        }
        return BorderSide(
            color: Color.lerp(colorA, colorB, t)!,
            width: width,
            strokeAlign: a.strokeAlign
        )
    }

    // MARK: - Instance Methods

    /// Creates a copy of this border but with the given fields replaced with the new values.
    ///
    /// **Dart Source:** `borders.dart:181-189`
    public func copyWith(
        color: Color? = nil,
        width: Double? = nil,
        style: BorderStyle? = nil,
        strokeAlign: Double? = nil
    ) -> BorderSide {
        BorderSide(
            color: color ?? self.color,
            width: width ?? self.width,
            style: style ?? self.style,
            strokeAlign: strokeAlign ?? self.strokeAlign
        )
    }

    /// Creates a copy of this border side description but with the width scaled
    /// by the factor `t`.
    ///
    /// **Dart Source:** `borders.dart:207-213`
    public func scale(_ t: Double) -> BorderSide {
        BorderSide(
            color: color,
            width: max(0.0, width * t),
            style: t <= 0.0 ? .none : style
        )
    }

    /// Create a `Paint` object that, if used to stroke a line, will draw the line
    /// in this border's style.
    ///
    /// The `strokeAlign` property is not reflected in the `Paint`; consumers must
    /// implement that directly by inflating or deflating their region appropriately.
    ///
    /// **Dart Source:** `borders.dart:224-237`
    public func toPaint() -> Paint {
        switch style {
        case .solid:
            let paint = Paint()
            paint.color = color
            paint.strokeWidth = width
            paint.style = .stroke
            return paint
        case .none:
            let paint = Paint()
            paint.color = Color(0x00000000)
            paint.strokeWidth = 0.0
            paint.style = .stroke
            return paint
        }
    }

    // MARK: - Computed Properties

    /// Get the amount of the stroke width that lies inside of the `BorderSide`.
    ///
    /// For example, this will return the `width` for a `strokeAlign` of -1, half
    /// the `width` for a `strokeAlign` of 0, and 0 for a `strokeAlign` of 1.
    ///
    /// **Dart Source:** `borders.dart:299-303`
    public var strokeInset: Double {
        width * (1 - (1 + strokeAlign) / 2)
    }

    /// Get the amount of the stroke width that lies outside of the `BorderSide`.
    ///
    /// For example, this will return 0 for a `strokeAlign` of -1, half the
    /// `width` for a `strokeAlign` of 0, and the `width` for a `strokeAlign`
    /// of 1.
    ///
    /// **Dart Source:** `borders.dart:305-310`
    public var strokeOutset: Double {
        width * (1 + strokeAlign) / 2
    }

    /// The offset of the stroke, taking into account the stroke alignment.
    ///
    /// For example, this will return the negative `width` of the stroke
    /// for a `strokeAlign` of -1, 0 for a `strokeAlign` of 0, and the
    /// `width` for a `strokeAlign` of 1.
    ///
    /// **Dart Source:** `borders.dart:312-317`
    public var strokeOffset: Double {
        width * strokeAlign
    }

    // MARK: - Hashable

    /// **Dart Source:** `borders.dart:334-335`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(color)
        hasher.combine(width)
        hasher.combine(style)
        hasher.combine(strokeAlign)
    }
}

// MARK: - ShapeBorder Protocol

/// Base protocol for shape outlines.
///
/// This protocol handles how to add multiple borders together. Conforming types define
/// various shapes, like circles (`CircleBorder`), rounded rectangles
/// (`RoundedRectangleBorder`), continuous rectangles
/// (`ContinuousRectangleBorder`), or beveled rectangles
/// (`BeveledRectangleBorder`).
///
/// **Dart Source:** `borders.dart:367-652`
public protocol ShapeBorder: CustomStringConvertible {
    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// Specifically, this is the amount by which a rectangle should be inset so
    /// as to avoid painting over any important part of the border. It is the
    /// amount by which additional borders will be inset before they are drawn.
    ///
    /// **Dart Source:** `borders.dart:372-386`
    var dimensions: any EdgeInsetsGeometry { get }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `borders.dart:415-437`
    func scale(_ t: Double) -> any ShapeBorder

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// When implementing this method in subclasses, return nil if this class
    /// cannot interpolate from `a`. In that case, `lerp` will try `a`'s `lerpTo`
    /// method instead. If `a` is nil, this must not return nil.
    ///
    /// **Dart Source:** `borders.dart:464-469`
    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)?

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// When implementing this method in subclasses, return nil if this class
    /// cannot interpolate to `b`. In that case, `lerp` will apply a default
    /// behavior instead. If `b` is nil, this must not return nil.
    ///
    /// **Dart Source:** `borders.dart:496-502`
    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)?

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// This path must not cross the path given by `getInnerPath` for the same
    /// `Rect`.
    ///
    /// **Dart Source:** `borders.dart:520-539`
    func getOuterPath(_ rect: Rect, textDirection: TextDirection?) -> Path

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// This path must not cross the path given by `getOuterPath` for the same
    /// `Rect`.
    ///
    /// **Dart Source:** `borders.dart:541-560`
    func getInnerPath(_ rect: Rect, textDirection: TextDirection?) -> Path

    /// Paint a canvas with the appropriate shape.
    ///
    /// **Dart Source:** `borders.dart:608-617`
    func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?)

    /// Reports whether `paintInterior` is implemented.
    ///
    /// Classes such as `ShapeDecoration` prefer to use `paintInterior` if this
    /// getter returns true. This is intended to enable faster painting.
    ///
    /// By default, this getter returns false.
    ///
    /// **Dart Source:** `borders.dart:619-638`
    var preferPaintInterior: Bool { get }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `borders.dart:640-646`
    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection?)
}

// MARK: - ShapeBorder Extension

extension ShapeBorder {
    /// Default implementation for lerpFrom.
    ///
    /// **Dart Source:** `borders.dart:464-469`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Default implementation for lerpTo.
    ///
    /// **Dart Source:** `borders.dart:496-502`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    /// Default implementation for paintInterior.
    ///
    /// **Dart Source:** `borders.dart:608-617`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        assert(!preferPaintInterior, "paintInterior is not implemented but preferPaintInterior returns true")
    }

    /// Default implementation for preferPaintInterior.
    ///
    /// **Dart Source:** `borders.dart:619-638`
    public var preferPaintInterior: Bool { false }

    /// Default description implementation.
    ///
    /// **Dart Source:** `borders.dart:648-651`
    public var description: String {
        "\(objectRuntimeType(self, "ShapeBorder"))()"
    }
}

// MARK: - ShapeBorder Static Methods

/// Extension providing static methods for `ShapeBorder`.
public enum ShapeBorderStatics {
    /// Linearly interpolates between two `ShapeBorder`s.
    ///
    /// This defers to `b`'s `lerpFrom` function if `b` is not nil. If `b` is
    /// nil or if its `lerpFrom` returns nil, it uses `a`'s `lerpTo`
    /// function instead. If both return nil, it returns `a` before `t=0.5`
    /// and `b` after `t=0.5`.
    ///
    /// **Dart Source:** `borders.dart:504-518`
    public static func lerp(_ a: (any ShapeBorder)?, _ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        // Cannot do identity check for existential types, so skip that optimization
        let result = b?.lerpFrom(a, t) ?? a?.lerpTo(b, t)
        return result ?? (t < 0.5 ? a : b)
    }
}

// MARK: - OutlinedBorder Protocol

/// A `ShapeBorder` that draws an outline with the width and color specified
/// by `side`.
///
/// **Dart Source:** `borders.dart:657-709`
public protocol OutlinedBorder: ShapeBorder {
    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `borders.dart:665-669`
    var side: BorderSide { get }

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `borders.dart:671-673`
    func copyWith(side: BorderSide?) -> any OutlinedBorder
}

// MARK: - OutlinedBorder Extension

extension OutlinedBorder {
    /// Default dimensions implementation.
    ///
    /// **Dart Source:** `borders.dart:662-663`
    public var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }
}

// MARK: - OutlinedBorder Static Methods

/// Extension providing static methods for `OutlinedBorder`.
public enum OutlinedBorderStatics {
    /// Linearly interpolates between two `OutlinedBorder`s.
    ///
    /// This defers to `b`'s `lerpFrom` function if `b` is not nil. If `b` is
    /// nil or if its `lerpFrom` returns nil, it uses `a`'s `lerpTo`
    /// function instead. If both return nil, it returns `a` before `t=0.5`
    /// and `b` after `t=0.5`.
    ///
    /// **Dart Source:** `borders.dart:702-708`
    public static func lerp(_ a: (any OutlinedBorder)?, _ b: (any OutlinedBorder)?, _ t: Double) -> (any OutlinedBorder)? {
        // Cannot do identity check for existential types, so skip that optimization
        let result = b?.lerpFrom(a, t) ?? a?.lerpTo(b, t)
        return result as? (any OutlinedBorder) ?? (t < 0.5 ? a : b)
    }
}

// MARK: - paintBorder Function

/// Paints a border around the given rectangle on the canvas.
///
/// The four sides can be independently specified. They are painted in the order
/// top, right, bottom, left.
///
/// **Dart Source:** `borders.dart:877-963`
public func paintBorder(
    _ canvas: Canvas,
    _ rect: Rect,
    top: BorderSide = .none,
    right: BorderSide = .none,
    bottom: BorderSide = .none,
    left: BorderSide = .none
) {
    let paint = Paint()
    paint.strokeWidth = 0.0

    let path = Path()

    // Top border
    switch top.style {
    case .solid:
        paint.color = top.color
        path.reset()
        path.moveTo(rect.left, rect.top)
        path.lineTo(rect.right, rect.top)
        if top.width == 0.0 {
            paint.style = .stroke
        } else {
            paint.style = .fill
            path.lineTo(rect.right - right.width, rect.top + top.width)
            path.lineTo(rect.left + left.width, rect.top + top.width)
        }
        canvas.drawPath(path, paint)
    case .none:
        break
    }

    // Right border
    switch right.style {
    case .solid:
        paint.color = right.color
        path.reset()
        path.moveTo(rect.right, rect.top)
        path.lineTo(rect.right, rect.bottom)
        if right.width == 0.0 {
            paint.style = .stroke
        } else {
            paint.style = .fill
            path.lineTo(rect.right - right.width, rect.bottom - bottom.width)
            path.lineTo(rect.right - right.width, rect.top + top.width)
        }
        canvas.drawPath(path, paint)
    case .none:
        break
    }

    // Bottom border
    switch bottom.style {
    case .solid:
        paint.color = bottom.color
        path.reset()
        path.moveTo(rect.right, rect.bottom)
        path.lineTo(rect.left, rect.bottom)
        if bottom.width == 0.0 {
            paint.style = .stroke
        } else {
            paint.style = .fill
            path.lineTo(rect.left + left.width, rect.bottom - bottom.width)
            path.lineTo(rect.right - right.width, rect.bottom - bottom.width)
        }
        canvas.drawPath(path, paint)
    case .none:
        break
    }

    // Left border
    switch left.style {
    case .solid:
        paint.color = left.color
        path.reset()
        path.moveTo(rect.left, rect.bottom)
        path.lineTo(rect.left, rect.top)
        if left.width == 0.0 {
            paint.style = .stroke
        } else {
            paint.style = .fill
            path.lineTo(rect.left + left.width, rect.top + top.width)
            path.lineTo(rect.left + left.width, rect.bottom - bottom.width)
        }
        canvas.drawPath(path, paint)
    case .none:
        break
    }
}
