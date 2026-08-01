// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Box border types for defining box outlines with four sides.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_border.dart`

import FlutterSwiftBridge

// MARK: - BoxShape

/// The shape to use when rendering a `Border` or `BoxDecoration`.
///
/// Consider using `ShapeBorder` conforming types directly (with `ShapeDecoration`),
/// instead of using `BoxShape` and `Border`, if the shapes will need to be
/// interpolated or animated. The `Border` class cannot interpolate between
/// different shapes.
///
/// **Dart Source:** `box_border.dart:26-49`
public enum BoxShape: Sendable, Hashable {
    /// An axis-aligned rectangle, optionally with rounded corners.
    ///
    /// The amount of corner rounding, if any, is determined by the border radius
    /// specified by classes such as `BoxDecoration` or `Border`. The rectangle's
    /// edges match those of the box in which it is painted.
    case rectangle

    /// A circle centered in the middle of the box into which the `Border` or
    /// `BoxDecoration` is painted. The diameter of the circle is the shortest
    /// dimension of the box, either the width or the height, such that the circle
    /// touches the edges of the box.
    case circle
}

// MARK: - BoxBorder

/// Base class for box borders that can paint as rectangles, circles, or rounded
/// rectangles.
///
/// This class is extended by `Border` and `BorderDirectional` to provide
/// concrete versions of four-sided borders using different conventions for
/// specifying the sides.
///
/// The only API difference that this class introduces over `ShapeBorder` is
/// that its `paint` method takes additional arguments.
///
/// **Dart Source:** `box_border.dart:67-364`
open class BoxBorder: ShapeBorder, Equatable, Hashable {

    /// Creates a BoxBorder.
    ///
    /// **Dart Source:** `box_border.dart:68-70`
    public init() {}

    // MARK: - Factory Methods

    /// Creates a `Border`.
    ///
    /// All the sides of the border default to `BorderSide.none`.
    ///
    /// **Dart Source:** `box_border.dart:75-80`
    public static func fromLTRB(
        top: BorderSide = .none,
        right: BorderSide = .none,
        bottom: BorderSide = .none,
        left: BorderSide = .none
    ) -> Border {
        Border(top: top, right: right, bottom: bottom, left: left)
    }

    /// A uniform `Border` with all sides the same color and width.
    ///
    /// The sides default to black solid borders, one logical pixel wide.
    ///
    /// **Dart Source:** `box_border.dart:85-86`
    public static func all(
        color: Color = Color(0xFF000000),
        width: Double = 1.0,
        style: BorderStyle = .solid,
        strokeAlign: Double = BorderSide.strokeAlignInside
    ) -> Border {
        let side = BorderSide(
            color: color,
            width: width,
            style: style,
            strokeAlign: strokeAlign
        )
        return Border(top: side, right: side, bottom: side, left: side)
    }

    /// Creates a `Border` whose sides are all the same.
    ///
    /// **Dart Source:** `box_border.dart:89`
    public static func fromBorderSide(_ side: BorderSide) -> Border {
        Border(top: side, right: side, bottom: side, left: side)
    }

    /// Creates a `Border` with symmetrical vertical and horizontal sides.
    ///
    /// The `vertical` argument applies to the `left` and `right` sides, and the
    /// `horizontal` argument applies to the `top` and `bottom` sides.
    ///
    /// All arguments default to `BorderSide.none`.
    ///
    /// **Dart Source:** `box_border.dart:97-98`
    public static func symmetric(
        vertical: BorderSide = .none,
        horizontal: BorderSide = .none
    ) -> Border {
        Border(top: horizontal, right: vertical, bottom: horizontal, left: vertical)
    }

    /// Creates a `BorderDirectional`.
    ///
    /// The `start` and `end` sides represent the horizontal sides; the start side
    /// is on the leading edge given the reading direction, and the end side is on
    /// the trailing edge. They are resolved during `paint`.
    ///
    /// All the sides of the border default to `BorderSide.none`.
    ///
    /// **Dart Source:** `box_border.dart:107-112`
    public static func fromSTEB(
        top: BorderSide = .none,
        start: BorderSide = .none,
        end: BorderSide = .none,
        bottom: BorderSide = .none
    ) -> BorderDirectional {
        BorderDirectional(top: top, start: start, end: end, bottom: bottom)
    }

    // MARK: - Abstract Properties

    /// The top side of this border.
    ///
    /// This getter is available on both `Border` and `BorderDirectional`. If
    /// `isUniform` is true, then this is the same style as all the other sides.
    ///
    /// **Dart Source:** `box_border.dart:118`
    open var top: BorderSide {
        fatalError("Subclasses must override top")
    }

    /// The bottom side of this border.
    ///
    /// **Dart Source:** `box_border.dart:121`
    open var bottom: BorderSide {
        fatalError("Subclasses must override bottom")
    }

    /// Whether all four sides of the border are identical. Uniform borders are
    /// typically more efficient to paint.
    ///
    /// **Dart Source:** `box_border.dart:130`
    open var isUniform: Bool {
        fatalError("Subclasses must override isUniform")
    }

    /// Attempts to combine this border with another, returning nil if not compatible.
    ///
    /// **Dart Source:** `box_border.dart:134-135`
    open func add(_ other: any ShapeBorder, reversed: Bool = false) -> BoxBorder? {
        return nil
    }

    // MARK: - ShapeBorder Protocol

    /// The widths of the sides of this border represented as an `EdgeInsetsGeometry`.
    ///
    /// **Dart Source:** `box_border.dart` - inherited from ShapeBorder
    open var dimensions: any EdgeInsetsGeometry {
        fatalError("Subclasses must override dimensions")
    }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `box_border.dart` - inherited from ShapeBorder
    open func scale(_ t: Double) -> any ShapeBorder {
        fatalError("Subclasses must override scale")
    }

    /// Linearly interpolates from another `ShapeBorder` to `this`.
    ///
    /// **Dart Source:** `box_border.dart` - inherited from ShapeBorder
    open func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder`.
    ///
    /// **Dart Source:** `box_border.dart` - inherited from ShapeBorder
    open func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `box_border.dart:220-227`
    open func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        assert(
            textDirection != nil,
            "The textDirection argument to \(type(of: self)).getInnerPath must not be nil."
        )
        let path = Path()
        path.addRect(dimensions.resolve(textDirection).deflateRect(rect))
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `box_border.dart:229-236`
    open func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        assert(
            textDirection != nil,
            "The textDirection argument to \(type(of: self)).getOuterPath must not be nil."
        )
        let path = Path()
        path.addRect(rect)
        return path
    }

    /// Paint a canvas with the appropriate shape.
    ///
    /// **Dart Source:** `box_border.dart:238-245`
    open func paintInterior(
        _ canvas: Canvas,
        _ rect: Rect,
        _ paint: Paint,
        textDirection: TextDirection? = nil
    ) {
        canvas.drawRect(rect, paint)
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `box_border.dart:247-248`
    open var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `box_border.dart:271-278`
    open func paint(
        _ canvas: Canvas,
        _ rect: Rect,
        textDirection: TextDirection? = nil,
        shape: BoxShape = .rectangle,
        borderRadius: BorderRadius? = nil
    ) {
        fatalError("Subclasses must override paint")
    }

    /// Default paint implementation (satisfies ShapeBorder protocol).
    ///
    /// Delegates to the extended paint method.
    open func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        paint(canvas, rect, textDirection: textDirection, shape: .rectangle, borderRadius: nil)
    }

    // MARK: - Static Lerp

    /// Linearly interpolate between two borders.
    ///
    /// If a border is nil, it is treated as having four `BorderSide.none` borders.
    ///
    /// This supports interpolating between `Border` and `BorderDirectional`
    /// objects. If both objects are different types but both have sides on one or
    /// both of their lateral edges (the two sides that aren't the top and bottom)
    /// other than `BorderSide.none`, then the sides are interpolated by reducing
    /// `a`'s lateral edges to `BorderSide.none` over the first half of the
    /// animation, and then bringing `b`'s lateral edges from `BorderSide.none`
    /// over the second half of the animation.
    ///
    /// **Dart Source:** `box_border.dart:154-218`
    public static func lerp(_ a: BoxBorder?, _ b: BoxBorder?, _ t: Double) -> BoxBorder? {
        if a === b {
            return a
        }
        if (a == nil || a is Border) && (b == nil || b is Border) {
            return Border.lerp(a as? Border, b as? Border, t)
        }
        if (a == nil || a is BorderDirectional) && (b == nil || b is BorderDirectional) {
            return BorderDirectional.lerp(a as? BorderDirectional, b as? BorderDirectional, t)
        }
        var effectiveA = a
        var effectiveB = b
        var effectiveT = t
        if effectiveB is Border && effectiveA is BorderDirectional {
            swap(&effectiveA, &effectiveB)
            effectiveT = 1.0 - effectiveT
        }
        if let aBorder = effectiveA as? Border, let bDirectional = effectiveB as? BorderDirectional {
            if bDirectional.start == .none && bDirectional.end == .none {
                return Border(
                    top: BorderSide.lerp(aBorder.top, bDirectional.top, effectiveT),
                    right: BorderSide.lerp(aBorder.right, .none, effectiveT),
                    bottom: BorderSide.lerp(aBorder.bottom, bDirectional.bottom, effectiveT),
                    left: BorderSide.lerp(aBorder.left, .none, effectiveT)
                )
            }
            if aBorder.left == .none && aBorder.right == .none {
                return BorderDirectional(
                    top: BorderSide.lerp(aBorder.top, bDirectional.top, effectiveT),
                    start: BorderSide.lerp(.none, bDirectional.start, effectiveT),
                    end: BorderSide.lerp(.none, bDirectional.end, effectiveT),
                    bottom: BorderSide.lerp(aBorder.bottom, bDirectional.bottom, effectiveT)
                )
            }
            if effectiveT < 0.5 {
                return Border(
                    top: BorderSide.lerp(aBorder.top, bDirectional.top, effectiveT),
                    right: BorderSide.lerp(aBorder.right, .none, effectiveT * 2.0),
                    bottom: BorderSide.lerp(aBorder.bottom, bDirectional.bottom, effectiveT),
                    left: BorderSide.lerp(aBorder.left, .none, effectiveT * 2.0)
                )
            }
            return BorderDirectional(
                top: BorderSide.lerp(aBorder.top, bDirectional.top, effectiveT),
                start: BorderSide.lerp(.none, bDirectional.start, (effectiveT - 0.5) * 2.0),
                end: BorderSide.lerp(.none, bDirectional.end, (effectiveT - 0.5) * 2.0),
                bottom: BorderSide.lerp(aBorder.bottom, bDirectional.bottom, effectiveT)
            )
        }
        fatalError(
            "BoxBorder.lerp can only interpolate Border and BorderDirectional classes.\n"
            + "BoxBorder.lerp() was called with two objects of type \(type(of: a as Any)) and \(type(of: b as Any)):\n"
            + "  \(String(describing: a))\n"
            + "  \(String(describing: b))\n"
            + "However, only Border and BorderDirectional classes are supported by this method.\n"
            + "For a more general interpolation method, consider using ShapeBorder.lerp instead."
        )
    }

    // MARK: - Static Paint Helpers

    /// Paints a uniform border with a border radius.
    ///
    /// **Dart Source:** `box_border.dart:280-300`
    fileprivate static func paintUniformBorderWithRadius(
        _ canvas: Canvas,
        _ rect: Rect,
        _ side: BorderSide,
        _ borderRadius: BorderRadius
    ) {
        assert(side.style != .none)
        let paint = Paint()
        paint.color = side.color
        let width = side.width
        if width == 0.0 {
            paint.style = .stroke
            paint.strokeWidth = 0.0
            canvas.drawRRect(borderRadius.toRRect(rect), paint)
        } else {
            let borderRect = borderRadius.toRRect(rect)
            let inner = borderRect.deflate(side.strokeInset)
            let outer = borderRect.inflate(side.strokeOutset)
            canvas.drawDRRect(outer, inner, paint)
        }
    }

    /// Paints a Border with different widths, styles and strokeAligns, on any
    /// borderRadius while using a single color.
    ///
    /// **Dart Source:** `box_border.dart:309-352`
    public static func paintNonUniformBorder(
        _ canvas: Canvas,
        _ rect: Rect,
        shape: BoxShape = .rectangle,
        borderRadius: BorderRadius? = nil,
        textDirection: TextDirection? = nil,
        top: BorderSide = .none,
        right: BorderSide = .none,
        bottom: BorderSide = .none,
        left: BorderSide = .none,
        color: Color
    ) {
        let borderRect: RRect
        switch shape {
        case .rectangle:
            borderRect = (borderRadius ?? .zero).resolve(textDirection).toRRect(rect)
        case .circle:
            assert(
                borderRadius == nil,
                "A circle cannot have a border radius. Remove either the shape or the borderRadius argument."
            )
            borderRect = RRect(
                fromRectAndRadius: Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2.0),
                Radius(circular: rect.width)
            )
        }
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

    /// Paints a uniform border with a circle shape.
    ///
    /// **Dart Source:** `box_border.dart:354-358`
    fileprivate static func paintUniformBorderWithCircle(
        _ canvas: Canvas,
        _ rect: Rect,
        _ side: BorderSide
    ) {
        assert(side.style != .none)
        let radius = (rect.shortestSide + side.strokeOffset) / 2
        canvas.drawCircle(rect.center, radius, side.toPaint())
    }

    /// Paints a uniform border with a rectangle shape.
    ///
    /// **Dart Source:** `box_border.dart:360-363`
    fileprivate static func paintUniformBorderWithRectangle(
        _ canvas: Canvas,
        _ rect: Rect,
        _ side: BorderSide
    ) {
        assert(side.style != .none)
        canvas.drawRect(rect.inflate(side.strokeOffset / 2), side.toPaint())
    }

    // MARK: - Equatable

    /// Subclasses must override this to provide value equality.
    open func isEqual(to other: BoxBorder) -> Bool {
        return self === other
    }

    public static func == (lhs: BoxBorder, rhs: BoxBorder) -> Bool {
        if lhs === rhs { return true }
        return lhs.isEqual(to: rhs)
    }

    // MARK: - Hashable

    open func hash(into hasher: inout Hasher) {
        fatalError("Subclasses must override hash(into:)")
    }

    // MARK: - CustomStringConvertible

    open var description: String {
        "\(objectRuntimeType(self, "BoxBorder"))()"
    }
}

// MARK: - EdgeInsets RRect Extensions

/// Extensions on `EdgeInsets` for inflating/deflating `RRect`s.
///
/// These are needed by `BoxBorder.paintNonUniformBorder` and correspond to
/// `EdgeInsets.inflateRRect` and `EdgeInsets.deflateRRect` in Dart.
///
/// **Dart Source:** `edge_insets.dart:556-605`
extension EdgeInsets {
    /// Returns a new `RRect` that is bigger than the given `RRect` by the inset amounts.
    ///
    /// Corner radii are adjusted per-axis and clamped to be non-negative.
    ///
    /// **Dart Source:** `edge_insets.dart:566-577`
    func inflateRRect(_ rect: RRect) -> RRect {
        RRect(
            fromLTRBAndCorners: rect.left - left,
            rect.top - top,
            rect.right + right,
            rect.bottom + bottom,
            topLeft: (rect.tlRadius + Radius(elliptical: left, top)).clamp(minimum: .zero),
            topRight: (rect.trRadius + Radius(elliptical: right, top)).clamp(minimum: .zero),
            bottomRight: (rect.brRadius + Radius(elliptical: right, bottom)).clamp(minimum: .zero),
            bottomLeft: (rect.blRadius + Radius(elliptical: left, bottom)).clamp(minimum: .zero)
        )
    }

    /// Returns a new `RRect` that is smaller than the given `RRect` by the inset amounts.
    ///
    /// Corner radii are adjusted per-axis and clamped to be non-negative.
    ///
    /// **Dart Source:** `edge_insets.dart:597-605`
    func deflateRRect(_ rect: RRect) -> RRect {
        RRect(
            fromLTRBAndCorners: rect.left + left,
            rect.top + top,
            rect.right - right,
            rect.bottom - bottom,
            topLeft: (rect.tlRadius - Radius(elliptical: left, top)).clamp(minimum: .zero),
            topRight: (rect.trRadius - Radius(elliptical: right, top)).clamp(minimum: .zero),
            bottomRight: (rect.brRadius - Radius(elliptical: right, bottom)).clamp(minimum: .zero),
            bottomLeft: (rect.blRadius - Radius(elliptical: left, bottom)).clamp(minimum: .zero)
        )
    }
}

// MARK: - Border

/// A border of a box, comprised of four sides: top, right, bottom, left.
///
/// The sides are represented by `BorderSide` objects.
///
/// **Dart Source:** `box_border.dart:431-780`
public final class Border: BoxBorder {
    // MARK: - Stored Properties

    /// The top side of this border.
    ///
    /// **Dart Source:** `box_border.dart:499-500`
    public override var top: BorderSide { _top }
    private let _top: BorderSide

    /// The right side of this border.
    ///
    /// **Dart Source:** `box_border.dart:503`
    public let right: BorderSide

    /// The bottom side of this border.
    ///
    /// **Dart Source:** `box_border.dart:505-506`
    public override var bottom: BorderSide { _bottom }
    private let _bottom: BorderSide

    /// The left side of this border.
    ///
    /// **Dart Source:** `box_border.dart:509`
    public let left: BorderSide

    // MARK: - Initializers

    /// Creates a border.
    ///
    /// All the sides of the border default to `BorderSide.none`.
    ///
    /// **Dart Source:** `box_border.dart:435-440`
    public init(
        top: BorderSide = .none,
        right: BorderSide = .none,
        bottom: BorderSide = .none,
        left: BorderSide = .none
    ) {
        self._top = top
        self.right = right
        self._bottom = bottom
        self.left = left
        super.init()
    }

    // MARK: - Static Methods

    /// Creates a `Border` that represents the addition of the two given `Border`s.
    ///
    /// It is only valid to call this if `BorderSide.canMerge` returns true for
    /// the pairwise combination of each side on both `Border`s.
    ///
    /// **Dart Source:** `box_border.dart:486-497`
    public static func merge(_ a: Border, _ b: Border) -> Border {
        assert(BorderSide.canMerge(a.top, b.top))
        assert(BorderSide.canMerge(a.right, b.right))
        assert(BorderSide.canMerge(a.bottom, b.bottom))
        assert(BorderSide.canMerge(a.left, b.left))
        return Border(
            top: BorderSide.merge(a.top, b.top),
            right: BorderSide.merge(a.right, b.right),
            bottom: BorderSide.merge(a.bottom, b.bottom),
            left: BorderSide.merge(a.left, b.left)
        )
    }

    // MARK: - Computed Properties

    /// **Dart Source:** `box_border.dart:511-519`
    public override var dimensions: any EdgeInsetsGeometry {
        EdgeInsets.fromLTRB(
            left.strokeInset,
            top.strokeInset,
            right.strokeInset,
            bottom.strokeInset
        )
    }

    /// **Dart Source:** `box_border.dart:521-523`
    public override var isUniform: Bool {
        colorIsUniform && widthIsUniform && styleIsUniform && strokeAlignIsUniform
    }

    private var colorIsUniform: Bool {
        let topColor = top.color
        return left.color == topColor && bottom.color == topColor && right.color == topColor
    }

    private var widthIsUniform: Bool {
        let topWidth = top.width
        return left.width == topWidth && bottom.width == topWidth && right.width == topWidth
    }

    private var styleIsUniform: Bool {
        let topStyle = top.style
        return left.style == topStyle && bottom.style == topStyle && right.style == topStyle
    }

    private var strokeAlignIsUniform: Bool {
        let topStrokeAlign = top.strokeAlign
        return left.strokeAlign == topStrokeAlign &&
            bottom.strokeAlign == topStrokeAlign &&
            right.strokeAlign == topStrokeAlign
    }

    private func distinctVisibleColors() -> Set<Color> {
        var colors = Set<Color>()
        if top.style != .none { colors.insert(top.color) }
        if right.style != .none { colors.insert(right.color) }
        if bottom.style != .none { colors.insert(bottom.color) }
        if left.style != .none { colors.insert(left.color) }
        return colors
    }

    private var hasHairlineBorder: Bool {
        (top.style == .solid && top.width == 0.0) ||
        (right.style == .solid && right.width == 0.0) ||
        (bottom.style == .solid && bottom.width == 0.0) ||
        (left.style == .solid && left.width == 0.0)
    }

    // MARK: - Instance Methods

    /// Returns a `Border` representing the addition of `self` with `other`, or
    /// nil if not compatible.
    ///
    /// **Dart Source:** `box_border.dart:565-575`
    public override func add(_ other: any ShapeBorder, reversed: Bool = false) -> BoxBorder? {
        if let otherBorder = other as? Border,
           BorderSide.canMerge(top, otherBorder.top) &&
           BorderSide.canMerge(right, otherBorder.right) &&
           BorderSide.canMerge(bottom, otherBorder.bottom) &&
           BorderSide.canMerge(left, otherBorder.left) {
            return Border.merge(self, otherBorder)
        }
        return nil
    }

    /// **Dart Source:** `box_border.dart:577-585`
    public override func scale(_ t: Double) -> any ShapeBorder {
        Border(
            top: top.scale(t),
            right: right.scale(t),
            bottom: bottom.scale(t),
            left: left.scale(t)
        )
    }

    /// **Dart Source:** `box_border.dart:587-593`
    public override func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let aBorder = a as? Border {
            return Border.lerp(aBorder, self, t)
        }
        return super.lerpFrom(a, t)
    }

    /// **Dart Source:** `box_border.dart:595-601`
    public override func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let bBorder = b as? Border {
            return Border.lerp(self, bBorder, t)
        }
        return super.lerpTo(b, t)
    }

    /// Linearly interpolate between two borders.
    ///
    /// If a border is nil, it is treated as having four `BorderSide.none` borders.
    ///
    /// **Dart Source:** `box_border.dart:609-625`
    public static func lerp(_ a: Border?, _ b: Border?, _ t: Double) -> Border? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t) as? Border
        }
        if b == nil {
            return a!.scale(1.0 - t) as? Border
        }
        return Border(
            top: BorderSide.lerp(a!.top, b!.top, t),
            right: BorderSide.lerp(a!.right, b!.right, t),
            bottom: BorderSide.lerp(a!.bottom, b!.bottom, t),
            left: BorderSide.lerp(a!.left, b!.left, t)
        )
    }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `box_border.dart:652-747`
    public override func paint(
        _ canvas: Canvas,
        _ rect: Rect,
        textDirection: TextDirection? = nil,
        shape: BoxShape = .rectangle,
        borderRadius: BorderRadius? = nil
    ) {
        if isUniform {
            switch top.style {
            case .none:
                return
            case .solid:
                switch shape {
                case .circle:
                    assert(
                        borderRadius == nil,
                        "A circle cannot have a border radius. Remove either the shape or the borderRadius argument."
                    )
                    BoxBorder.paintUniformBorderWithCircle(canvas, rect, top)
                case .rectangle:
                    if let borderRadius = borderRadius, borderRadius != .zero {
                        BoxBorder.paintUniformBorderWithRadius(canvas, rect, top, borderRadius)
                        return
                    }
                    BoxBorder.paintUniformBorderWithRectangle(canvas, rect, top)
                }
                return
            }
        }

        if styleIsUniform && top.style == .none {
            return
        }

        // Allow painting non-uniform borders if the visible colors are uniform.
        let visibleColors = distinctVisibleColors()
        let hasHairline = hasHairlineBorder
        if visibleColors.count == 1 &&
            !hasHairline &&
            (shape == .circle || (borderRadius != nil && borderRadius != .zero)) {
            BoxBorder.paintNonUniformBorder(
                canvas,
                rect,
                shape: shape,
                borderRadius: borderRadius,
                textDirection: textDirection,
                top: top.style == .none ? .none : top,
                right: right.style == .none ? .none : right,
                bottom: bottom.style == .none ? .none : bottom,
                left: left.style == .none ? .none : left,
                color: visibleColors.first!
            )
            return
        }

        assert({
            if hasHairline {
                assert(
                    borderRadius == nil || borderRadius == .zero,
                    "A hairline border like `BorderSide(width: 0.0, style: BorderStyle.solid)` can only be drawn when BorderRadius is zero or null."
                )
            }
            if let borderRadius = borderRadius, borderRadius != .zero {
                assert(
                    colorIsUniform,
                    "A borderRadius can only be given on borders with uniform colors."
                )
            }
            return true
        }())
        assert({
            if shape != .rectangle {
                assert(
                    colorIsUniform,
                    "A Border can only be drawn as a circle on borders with uniform colors."
                )
            }
            return true
        }())
        assert({
            if !strokeAlignIsUniform || top.strokeAlign != BorderSide.strokeAlignInside {
                assertionFailure(
                    "A Border can only draw strokeAlign different than BorderSide.strokeAlignInside on borders with uniform colors."
                )
            }
            return true
        }())

        paintBorder(canvas, rect, top: top, right: right, bottom: bottom, left: left)
    }

    // MARK: - Equatable

    /// **Dart Source:** `box_border.dart:750-762`
    public override func isEqual(to other: BoxBorder) -> Bool {
        guard let otherBorder = other as? Border else { return false }
        return _top == otherBorder._top &&
            right == otherBorder.right &&
            _bottom == otherBorder._bottom &&
            left == otherBorder.left
    }

    // MARK: - Hashable

    /// **Dart Source:** `box_border.dart:764-765`
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: self)))
        hasher.combine(_top)
        hasher.combine(right)
        hasher.combine(_bottom)
        hasher.combine(left)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `box_border.dart:767-779`
    public override var description: String {
        if isUniform {
            return "Border.all(\(top))"
        }
        var arguments: [String] = []
        if top != .none { arguments.append("top: \(top)") }
        if right != .none { arguments.append("right: \(right)") }
        if bottom != .none { arguments.append("bottom: \(bottom)") }
        if left != .none { arguments.append("left: \(left)") }
        return "Border(\(arguments.joined(separator: ", ")))"
    }
}

// MARK: - BorderDirectional

/// A border of a box, comprised of four sides, the lateral sides of which
/// flip over based on the reading direction.
///
/// The lateral sides are called `start` and `end`. When painted in
/// left-to-right environments, the `start` side will be painted on the left and
/// the `end` side on the right; in right-to-left environments, it is the
/// reverse. The other two sides are `top` and `bottom`.
///
/// The sides are represented by `BorderSide` objects.
///
/// **Dart Source:** `box_border.dart:804-1144`
public final class BorderDirectional: BoxBorder {
    // MARK: - Stored Properties

    /// The top side of this border.
    ///
    /// **Dart Source:** `box_border.dart:837-838`
    public override var top: BorderSide { _top }
    internal let _top: BorderSide

    /// The start side of this border.
    ///
    /// This is the side on the left in left-to-right text and on the right in
    /// right-to-left text.
    ///
    /// **Dart Source:** `box_border.dart:848`
    public let start: BorderSide

    /// The end side of this border.
    ///
    /// This is the side on the right in left-to-right text and on the left in
    /// right-to-left text.
    ///
    /// **Dart Source:** `box_border.dart:858`
    public let end: BorderSide

    /// The bottom side of this border.
    ///
    /// **Dart Source:** `box_border.dart:860-861`
    public override var bottom: BorderSide { _bottom }
    internal let _bottom: BorderSide

    // MARK: - Initializer

    /// Creates a border.
    ///
    /// The `start` and `end` sides represent the horizontal sides; the start side
    /// is on the leading edge given the reading direction, and the end side is on
    /// the trailing edge. They are resolved during `paint`.
    ///
    /// All the sides of the border default to `BorderSide.none`.
    ///
    /// **Dart Source:** `box_border.dart:812-817`
    public init(
        top: BorderSide = .none,
        start: BorderSide = .none,
        end: BorderSide = .none,
        bottom: BorderSide = .none
    ) {
        self._top = top
        self.start = start
        self.end = end
        self._bottom = bottom
        super.init()
    }

    // MARK: - Static Methods

    /// Creates a `BorderDirectional` that represents the addition of the two
    /// given `BorderDirectional`s.
    ///
    /// **Dart Source:** `box_border.dart:824-835`
    public static func merge(_ a: BorderDirectional, _ b: BorderDirectional) -> BorderDirectional {
        assert(BorderSide.canMerge(a.top, b.top))
        assert(BorderSide.canMerge(a.start, b.start))
        assert(BorderSide.canMerge(a.end, b.end))
        assert(BorderSide.canMerge(a.bottom, b.bottom))
        return BorderDirectional(
            top: BorderSide.merge(a.top, b.top),
            start: BorderSide.merge(a.start, b.start),
            end: BorderSide.merge(a.end, b.end),
            bottom: BorderSide.merge(a.bottom, b.bottom)
        )
    }

    // MARK: - Computed Properties

    /// **Dart Source:** `box_border.dart:863-871`
    public override var dimensions: any EdgeInsetsGeometry {
        EdgeInsetsDirectional.fromSTEB(
            start.strokeInset,
            top.strokeInset,
            end.strokeInset,
            bottom.strokeInset
        )
    }

    /// **Dart Source:** `box_border.dart:873-875`
    public override var isUniform: Bool {
        colorIsUniform && widthIsUniform && styleIsUniform && strokeAlignIsUniform
    }

    private var colorIsUniform: Bool {
        let topColor = top.color
        return start.color == topColor && bottom.color == topColor && end.color == topColor
    }

    private var widthIsUniform: Bool {
        let topWidth = top.width
        return start.width == topWidth && bottom.width == topWidth && end.width == topWidth
    }

    private var styleIsUniform: Bool {
        let topStyle = top.style
        return start.style == topStyle && bottom.style == topStyle && end.style == topStyle
    }

    private var strokeAlignIsUniform: Bool {
        let topStrokeAlign = top.strokeAlign
        return start.strokeAlign == topStrokeAlign &&
            bottom.strokeAlign == topStrokeAlign &&
            end.strokeAlign == topStrokeAlign
    }

    private func distinctVisibleColors() -> Set<Color> {
        var colors = Set<Color>()
        if top.style != .none { colors.insert(top.color) }
        if end.style != .none { colors.insert(end.color) }
        if bottom.style != .none { colors.insert(bottom.color) }
        if start.style != .none { colors.insert(start.color) }
        return colors
    }

    private var hasHairlineBorder: Bool {
        (top.style == .solid && top.width == 0.0) ||
        (end.style == .solid && end.width == 0.0) ||
        (bottom.style == .solid && bottom.width == 0.0) ||
        (start.style == .solid && start.width == 0.0)
    }

    // MARK: - Instance Methods

    /// Returns a `BoxBorder` representing the addition of `self` with `other`, or
    /// nil if not compatible.
    ///
    /// **Dart Source:** `box_border.dart:914-955`
    public override func add(_ other: any ShapeBorder, reversed: Bool = false) -> BoxBorder? {
        if let otherDirectional = other as? BorderDirectional {
            if BorderSide.canMerge(top, otherDirectional.top) &&
               BorderSide.canMerge(start, otherDirectional.start) &&
               BorderSide.canMerge(end, otherDirectional.end) &&
               BorderSide.canMerge(bottom, otherDirectional.bottom) {
                return BorderDirectional.merge(self, otherDirectional)
            }
            return nil
        }
        if let otherBorder = other as? Border {
            if !BorderSide.canMerge(otherBorder.top, top) ||
               !BorderSide.canMerge(otherBorder.bottom, bottom) {
                return nil
            }
            if start != .none || end != .none {
                if otherBorder.left != .none || otherBorder.right != .none {
                    return nil
                }
                assert(otherBorder.left == .none)
                assert(otherBorder.right == .none)
                return BorderDirectional(
                    top: BorderSide.merge(otherBorder.top, top),
                    start: start,
                    end: end,
                    bottom: BorderSide.merge(otherBorder.bottom, bottom)
                )
            }
            assert(start == .none)
            assert(end == .none)
            return Border(
                top: BorderSide.merge(otherBorder.top, top),
                right: otherBorder.right,
                bottom: BorderSide.merge(otherBorder.bottom, bottom),
                left: otherBorder.left
            )
        }
        return nil
    }

    /// **Dart Source:** `box_border.dart:957-965`
    public override func scale(_ t: Double) -> any ShapeBorder {
        BorderDirectional(
            top: top.scale(t),
            start: start.scale(t),
            end: end.scale(t),
            bottom: bottom.scale(t)
        )
    }

    /// **Dart Source:** `box_border.dart:967-973`
    public override func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let aDirectional = a as? BorderDirectional {
            return BorderDirectional.lerp(aDirectional, self, t)
        }
        return super.lerpFrom(a, t)
    }

    /// **Dart Source:** `box_border.dart:975-981`
    public override func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let bDirectional = b as? BorderDirectional {
            return BorderDirectional.lerp(self, bDirectional, t)
        }
        return super.lerpTo(b, t)
    }

    /// Linearly interpolate between two borders.
    ///
    /// If a border is nil, it is treated as having four `BorderSide.none` borders.
    ///
    /// **Dart Source:** `box_border.dart:989-1005`
    public static func lerp(
        _ a: BorderDirectional?,
        _ b: BorderDirectional?,
        _ t: Double
    ) -> BorderDirectional? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t) as? BorderDirectional
        }
        if b == nil {
            return a!.scale(1.0 - t) as? BorderDirectional
        }
        return BorderDirectional(
            top: BorderSide.lerp(a!.top, b!.top, t),
            start: BorderSide.lerp(a!.start, b!.start, t),
            end: BorderSide.lerp(a!.end, b!.end, t),
            bottom: BorderSide.lerp(a!.bottom, b!.bottom, t)
        )
    }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `box_border.dart:1030-1114`
    public override func paint(
        _ canvas: Canvas,
        _ rect: Rect,
        textDirection: TextDirection? = nil,
        shape: BoxShape = .rectangle,
        borderRadius: BorderRadius? = nil
    ) {
        if isUniform {
            switch top.style {
            case .none:
                return
            case .solid:
                switch shape {
                case .circle:
                    assert(
                        borderRadius == nil,
                        "A circle cannot have a border radius. Remove either the shape or the borderRadius argument."
                    )
                    BoxBorder.paintUniformBorderWithCircle(canvas, rect, top)
                case .rectangle:
                    if let borderRadius = borderRadius, borderRadius != .zero {
                        BoxBorder.paintUniformBorderWithRadius(canvas, rect, top, borderRadius)
                        return
                    }
                    BoxBorder.paintUniformBorderWithRectangle(canvas, rect, top)
                }
                return
            }
        }

        if styleIsUniform && top.style == .none {
            return
        }

        assert(
            textDirection != nil,
            "Non-uniform BorderDirectional objects require a TextDirection when painting."
        )
        let left: BorderSide
        let right: BorderSide
        switch textDirection! {
        case .rtl:
            left = end
            right = start
        case .ltr:
            left = start
            right = end
        @unknown default:
            left = start
            right = end
        }

        // Allow painting non-uniform borders if the visible colors are uniform.
        let visibleColors = distinctVisibleColors()
        let hasHairline = hasHairlineBorder
        if visibleColors.count == 1 &&
            !hasHairline &&
            (shape == .circle || (borderRadius != nil && borderRadius != .zero)) {
            BoxBorder.paintNonUniformBorder(
                canvas,
                rect,
                shape: shape,
                borderRadius: borderRadius,
                textDirection: textDirection,
                top: top.style == .none ? .none : top,
                right: right.style == .none ? .none : right,
                bottom: bottom.style == .none ? .none : bottom,
                left: left.style == .none ? .none : left,
                color: visibleColors.first!
            )
            return
        }

        if hasHairline {
            assert(
                borderRadius == nil || borderRadius == .zero,
                "A side like `BorderSide(width: 0.0, style: BorderStyle.solid)` can only be drawn when BorderRadius is zero or null."
            )
        }
        assert(
            borderRadius == nil,
            "A borderRadius can only be given for borders with uniform colors."
        )
        assert(
            shape == .rectangle,
            "A Border can only be drawn as a circle on borders with uniform colors."
        )
        assert(
            strokeAlignIsUniform && top.strokeAlign == BorderSide.strokeAlignInside,
            "A Border can only draw strokeAlign different than strokeAlignInside on borders with uniform colors."
        )

        paintBorder(canvas, rect, top: top, right: right, bottom: bottom, left: left)
    }

    // MARK: - Equatable

    /// **Dart Source:** `box_border.dart:1117-1129`
    public override func isEqual(to other: BoxBorder) -> Bool {
        guard let otherDirectional = other as? BorderDirectional else { return false }
        return _top == otherDirectional._top &&
            start == otherDirectional.start &&
            end == otherDirectional.end &&
            _bottom == otherDirectional._bottom
    }

    // MARK: - Hashable

    /// **Dart Source:** `box_border.dart:1131-1132`
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: self)))
        hasher.combine(_top)
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(_bottom)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `box_border.dart:1134-1143`
    public override var description: String {
        var arguments: [String] = []
        if top != .none { arguments.append("top: \(top)") }
        if start != .none { arguments.append("start: \(start)") }
        if end != .none { arguments.append("end: \(end)") }
        if bottom != .none { arguments.append("bottom: \(bottom)") }
        return "BorderDirectional(\(arguments.joined(separator: ", ")))"
    }
}

// MARK: - ShapeBorder + operator

/// The `+` operator for combining `ShapeBorder` objects.
///
/// This corresponds to Dart's `ShapeBorder.operator+`. If the two borders
/// can be merged (via `add`), they are merged into one; otherwise a compound
/// description is returned.
///
/// **Dart Source:** `borders.dart:388-413`
public func + (lhs: any ShapeBorder, rhs: any ShapeBorder) -> any ShapeBorder {
    // Try lhs.add(rhs) then rhs.add(lhs, reversed: true)
    if let lhsBox = lhs as? BoxBorder, let result = lhsBox.add(rhs) {
        return result
    }
    if let rhsBox = rhs as? BoxBorder, let result = rhsBox.add(lhs, reversed: true) {
        return result
    }
    // Fallback: compound border description
    return CompoundBorder(lhs, rhs)
}

// MARK: - CompoundBorder

/// A simple compound border that holds two borders that couldn't be merged.
///
/// This is a minimal implementation to support the `+` operator when borders
/// can't be merged together.
///
/// **Dart Source:** Loosely based on `borders.dart` compound border concept
internal class CompoundBorder: BoxBorder {
    let outer: any ShapeBorder
    let inner: any ShapeBorder

    init(_ outer: any ShapeBorder, _ inner: any ShapeBorder) {
        self.outer = outer
        self.inner = inner
        super.init()
    }

    override var dimensions: any EdgeInsetsGeometry {
        outer.dimensions.add(inner.dimensions)
    }

    override var top: BorderSide { .none }
    override var bottom: BorderSide { .none }
    override var isUniform: Bool { false }

    override func scale(_ t: Double) -> any ShapeBorder {
        CompoundBorder(outer.scale(t), inner.scale(t))
    }

    override func paint(
        _ canvas: Canvas,
        _ rect: Rect,
        textDirection: TextDirection? = nil,
        shape: BoxShape = .rectangle,
        borderRadius: BorderRadius? = nil
    ) {
        outer.paint(canvas, rect, textDirection: textDirection)
        let innerRect = dimensions.resolve(textDirection).deflateRect(rect)
        inner.paint(canvas, innerRect, textDirection: textDirection)
    }

    override var preferPaintInterior: Bool {
        if let outerBox = outer as? BoxBorder, let innerBox = inner as? BoxBorder {
            return outerBox.preferPaintInterior && innerBox.preferPaintInterior
        }
        return false
    }

    override func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(CompoundBorder.self))
    }

    override var description: String {
        "\(outer) + \(inner)"
    }
}
