// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An immutable description of how to paint a box.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_decoration.dart`

import FlutterSwiftBridge

// MARK: - BoxDecoration

/// An immutable description of how to paint a box.
///
/// The `BoxDecoration` class provides a variety of ways to draw a box.
///
/// The box has a `border`, a body, and may cast a `boxShadow`.
///
/// The `shape` of the box can be `BoxShape.circle` or `BoxShape.rectangle`. If
/// it is `BoxShape.rectangle`, then the `borderRadius` property can be used to
/// make it a rounded rectangle (`RRect`).
///
/// The body of the box is painted in layers. The bottom-most layer is the
/// `color`, which fills the box. Above that is the `gradient`, which also fills
/// the box.
///
/// The `border` paints over the body; the `boxShadow`, naturally, paints below it.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_decoration.dart`
/// **Original Name:** `BoxDecoration`
/// **Lines:** 81-397
public final class BoxDecoration: Decoration {

    // MARK: - Properties

    /// The color to fill in the background of the box.
    ///
    /// The color is filled into the `shape` of the box (e.g., either a rectangle,
    /// potentially with a `borderRadius`, or a circle).
    ///
    /// This is ignored if `gradient` is non-nil.
    ///
    /// The `color` is drawn under the image.
    ///
    /// **Dart Source:** `box_decoration.dart:149`
    public let color: Color?

    // TODO: Add `image` property when DecorationImage is migrated.
    // public let image: DecorationImage?

    /// A border to draw above the background `color`, `gradient`, or image.
    ///
    /// Follows the `shape` and `borderRadius`.
    ///
    /// Use `Border` objects to describe borders that do not depend on the reading
    /// direction.
    ///
    /// Use `BoxBorder` objects to describe borders that should flip their left
    /// and right edges based on whether the text is being read left-to-right or
    /// right-to-left.
    ///
    /// **Dart Source:** `box_decoration.dart:168`
    public let border: BoxBorder?

    /// If non-nil, the corners of this box are rounded by this `BorderRadius`.
    ///
    /// Applies only to boxes with rectangular shapes; ignored if `shape` is not
    /// `BoxShape.rectangle`.
    ///
    /// **Dart Source:** `box_decoration.dart:176`
    public let borderRadius: (any BorderRadiusGeometry)?

    /// A list of shadows cast by this box behind the box.
    ///
    /// The shadow follows the `shape` of the box.
    ///
    /// **Dart Source:** `box_decoration.dart:187`
    public let boxShadow: [BoxShadow]?

    /// A gradient to use when filling the box.
    ///
    /// If this is specified, `color` has no effect.
    ///
    /// The `gradient` is drawn under the image.
    ///
    /// **Dart Source:** `box_decoration.dart:194`
    public let gradient: GradientBase?

    /// The blend mode applied to the `color` or `gradient` background of the box.
    ///
    /// If no `backgroundBlendMode` is provided then the default painting blend
    /// mode is used.
    ///
    /// If no `color` or `gradient` is provided then the blend mode has no impact.
    ///
    /// **Dart Source:** `box_decoration.dart:202`
    public let backgroundBlendMode: BlendMode?

    /// The shape to fill the background `color`, `gradient`, and image into and
    /// to cast as the `boxShadow`.
    ///
    /// If this is `BoxShape.circle` then `borderRadius` is ignored.
    ///
    /// The `shape` cannot be interpolated; animating between two `BoxDecoration`s
    /// with different `shape`s will result in a discontinuity in the rendering.
    /// To interpolate between two shapes, consider using `ShapeDecoration` and
    /// different `ShapeBorder`s; in particular, `CircleBorder` instead of
    /// `BoxShape.circle` and `RoundedRectangleBorder` instead of
    /// `BoxShape.rectangle`.
    ///
    /// **Dart Source:** `box_decoration.dart:217`
    public let shape: BoxShape

    // MARK: - Initializer

    /// Creates a box decoration.
    ///
    /// - If `color` is nil, this decoration does not paint a background color.
    /// - If `border` is nil, this decoration does not paint a border.
    /// - If `borderRadius` is nil, this decoration uses more efficient background
    ///   painting commands. The `borderRadius` argument must be nil if `shape` is
    ///   `BoxShape.circle`.
    /// - If `boxShadow` is nil, this decoration does not paint a shadow.
    /// - If `gradient` is nil, this decoration does not paint gradients.
    /// - If `backgroundBlendMode` is nil, this decoration paints with `BlendMode.srcOver`.
    ///
    /// **Dart Source:** `box_decoration.dart:93-106`
    public init(
        color: Color? = nil,
        border: BoxBorder? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil,
        boxShadow: [BoxShadow]? = nil,
        gradient: GradientBase? = nil,
        backgroundBlendMode: BlendMode? = nil,
        shape: BoxShape = .rectangle
    ) {
        assert(
            backgroundBlendMode == nil || color != nil || gradient != nil,
            "backgroundBlendMode applies to BoxDecoration's background color or "
            + "gradient, but no color or gradient was provided."
        )
        self.color = color
        self.border = border
        self.borderRadius = borderRadius
        self.boxShadow = boxShadow
        self.gradient = gradient
        self.backgroundBlendMode = backgroundBlendMode
        self.shape = shape
    }

    // MARK: - Copy With

    /// Creates a copy of this object but with the given fields replaced with the
    /// new values.
    ///
    /// **Dart Source:** `box_decoration.dart:110-130`
    public func copyWith(
        color: Color?? = nil,
        border: BoxBorder?? = nil,
        borderRadius: (any BorderRadiusGeometry)?? = nil,
        boxShadow: [BoxShadow]?? = nil,
        gradient: GradientBase?? = nil,
        backgroundBlendMode: BlendMode?? = nil,
        shape: BoxShape? = nil
    ) -> BoxDecoration {
        BoxDecoration(
            color: color ?? self.color,
            border: border ?? self.border,
            borderRadius: borderRadius ?? self.borderRadius,
            boxShadow: boxShadow ?? self.boxShadow,
            gradient: gradient ?? self.gradient,
            backgroundBlendMode: backgroundBlendMode ?? self.backgroundBlendMode,
            shape: shape ?? self.shape
        )
    }

    // MARK: - Debug Validation

    /// In debug mode, throws an exception if the object is not in a valid
    /// configuration. Otherwise, returns true.
    ///
    /// **Dart Source:** `box_decoration.dart:132-139`
    public func debugAssertIsValid() -> Bool {
        assert(
            shape != .circle || borderRadius == nil,
            "A circle cannot have a border radius. Remove either the shape or the borderRadius argument."
        )
        return true
    }

    // MARK: - Decoration Protocol

    /// Returns the insets to apply when using this decoration on a box
    /// that has contents, so that the contents do not overlap the edges
    /// of the decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:219-220`
    public var padding: any EdgeInsetsGeometry {
        border?.dimensions ?? EdgeInsets.zero as any EdgeInsetsGeometry
    }

    /// Returns a closed `Path` that describes the outer edge of this decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:222-236`
    public func getClipPath(_ rect: Rect, _ textDirection: TextDirection) -> Path {
        switch shape {
        case .circle:
            let center = rect.center
            let radius = rect.shortestSide / 2.0
            let square = Rect.fromCircle(center: center, radius: radius)
            let path = Path()
            path.addOval(square)
            return path
        case .rectangle:
            if let borderRadius = borderRadius {
                let path = Path()
                path.addRRect(borderRadius.resolve(textDirection).toRRect(rect))
                return path
            }
            let path = Path()
            path.addRect(rect)
            return path
        }
    }

    /// Returns a new box decoration that is scaled by the given factor.
    ///
    /// **Dart Source:** `box_decoration.dart:239-249`
    public func scale(_ factor: Double) -> BoxDecoration {
        // TODO: Add DecorationImage.lerp(nil, image, factor) when DecorationImage is migrated.
        BoxDecoration(
            color: Color.lerp(nil, color, factor),
            border: BoxBorder.lerp(nil, border, factor),
            borderRadius: shape == .circle ? nil : BorderRadiusGeometryStatics.lerp(nil, borderRadius, factor),
            boxShadow: BoxShadow.lerpList(nil, boxShadow, factor),
            gradient: gradient?.scale(factor),
            shape: shape
        )
    }

    /// Whether this decoration is complex enough to benefit from caching its painting.
    ///
    /// **Dart Source:** `box_decoration.dart:251-252`
    public var isComplex: Bool {
        boxShadow != nil
    }

    /// Linearly interpolates from another `Decoration` to `this`.
    ///
    /// **Dart Source:** `box_decoration.dart:254-259`
    public func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)? {
        if a == nil {
            return scale(t)
        }
        if let aBox = a as? BoxDecoration {
            return BoxDecoration.lerp(aBox, self, t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `Decoration`.
    ///
    /// **Dart Source:** `box_decoration.dart:261-266`
    public func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)? {
        if b == nil {
            return scale(1.0 - t)
        }
        if let bBox = b as? BoxDecoration {
            return BoxDecoration.lerp(self, bBox, t)
        }
        return nil
    }

    /// Linearly interpolate between two box decorations.
    ///
    /// Interpolates each parameter of the box decoration separately.
    ///
    /// The `shape` is not interpolated. To interpolate the shape, consider using
    /// a `ShapeDecoration` with different border shapes.
    ///
    /// If both values are nil, this returns nil. Otherwise, it returns a
    /// non-nil value. If one of the values is nil, then the result is obtained
    /// by applying `scale` to the other value. If neither value is nil and `t ==
    /// 0.0`, then `a` is returned unmodified; if `t == 1.0` then `b` is returned
    /// unmodified. Otherwise, the values are computed by interpolating the
    /// properties appropriately.
    ///
    /// **Dart Source:** `box_decoration.dart:291-316`
    public static func lerp(_ a: BoxDecoration?, _ b: BoxDecoration?, _ t: Double) -> BoxDecoration? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        if t == 0.0 {
            return a
        }
        if t == 1.0 {
            return b
        }
        // TODO: Add DecorationImage.lerp(a.image, b.image, t) when DecorationImage is migrated.
        let lerpedShape = t < 0.5 ? a!.shape : b!.shape
        // When the interpolated shape is a circle, borderRadius must be nil
        // (circles cannot have a border radius). Skip the lerp to avoid
        // BorderRadiusGeometryStatics.lerp(nil, nil, t) returning .zero.
        let lerpedBorderRadius: (any BorderRadiusGeometry)? =
            lerpedShape == .circle
            ? nil
            : BorderRadiusGeometryStatics.lerp(a!.borderRadius, b!.borderRadius, t)
        return BoxDecoration(
            color: Color.lerp(a!.color, b!.color, t),
            border: BoxBorder.lerp(a!.border, b!.border, t),
            borderRadius: lerpedBorderRadius,
            boxShadow: BoxShadow.lerpList(a!.boxShadow, b!.boxShadow, t),
            gradient: GradientBase.lerp(a!.gradient, b!.gradient, t),
            shape: lerpedShape
        )
    }

    // MARK: - Hit Testing

    /// Tests whether the given point, on a rectangle of a given size,
    /// would be considered to hit the decoration or not.
    ///
    /// **Dart Source:** `box_decoration.dart:374-390`
    public func hitTest(_ size: Size, _ position: Offset, textDirection: TextDirection? = nil) -> Bool {
        assert(Rect.fromLTWH(0, 0, size.width, size.height).contains(position))
        switch shape {
        case .rectangle:
            if let borderRadius = borderRadius {
                let bounds = borderRadius.resolve(textDirection).toRRect(
                    Rect.fromLTWH(0, 0, size.width, size.height)
                )
                return bounds.contains(position)
            }
            return true
        case .circle:
            // Circles are inscribed into our smallest dimension.
            let center = size.center(.zero)
            let distance = (position - center).distance
            return distance <= min(size.width, size.height) / 2.0
        }
    }

    // MARK: - BoxPainter Creation

    /// Returns a `BoxPainter` that will paint this decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:392-396`
    public func createBoxPainter(_ onChanged: VoidCallback? = nil) -> BoxPainter {
        return BoxDecorationPainter(self, onChanged: onChanged)
    }

    // MARK: - Equatable

    /// Compares two `BoxDecoration` instances for equality.
    ///
    /// **Dart Source:** `box_decoration.dart:318-335`
    public static func == (lhs: BoxDecoration, rhs: BoxDecoration) -> Bool {
        if lhs === rhs { return true }
        // Use the global == operator for `any BorderRadiusGeometry` since the
        // existential type itself cannot conform to Equatable.
        let borderRadiusEqual: Bool
        if let lhsBR = lhs.borderRadius, let rhsBR = rhs.borderRadius {
            borderRadiusEqual = (lhsBR == rhsBR)
        } else {
            borderRadiusEqual = lhs.borderRadius == nil && rhs.borderRadius == nil
        }
        return lhs.color == rhs.color &&
            lhs.border == rhs.border &&
            borderRadiusEqual &&
            lhs.boxShadow == rhs.boxShadow &&
            lhs.gradient == rhs.gradient &&
            lhs.backgroundBlendMode == rhs.backgroundBlendMode &&
            lhs.shape == rhs.shape
    }

    // MARK: - Hashable

    /// The hash code for this decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:337-347`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(color)
        hasher.combine(border)
        if let borderRadius = borderRadius {
            hasher.combine(borderRadius)
        }
        if let boxShadow = boxShadow {
            for shadow in boxShadow {
                hasher.combine(shadow)
            }
        } else {
            hasher.combine(0)
        }
        hasher.combine(gradient)
        hasher.combine(backgroundBlendMode)
        hasher.combine(shape)
    }

    // MARK: - Diagnosticable

    /// A brief description of this object.
    ///
    /// **Dart Source:** `box_decoration.dart` (via Decoration)
    public func toStringShort() -> String {
        objectRuntimeType(self, "BoxDecoration")
    }

    /// Add additional properties associated with the node.
    ///
    /// **Dart Source:** `box_decoration.dart:349-372`
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.defaultDiagnosticsTreeStyle = .whitespace
        properties.emptyBodyDescription = "<no decorations specified>"

        properties.add(ColorProperty("color", color, defaultValue: nil))
        properties.add(
            DiagnosticsProperty<BoxBorder>("border", border, defaultValue: nil)
        )
        properties.add(
            DiagnosticsProperty<AnyHashable>(
                "borderRadius",
                borderRadius.map { AnyHashable($0) },
                defaultValue: nil
            )
        )
        properties.add(
            IterableProperty<BoxShadow>(
                "boxShadow",
                boxShadow,
                defaultValue: nil,
                style: .whitespace
            )
        )
        properties.add(
            DiagnosticsProperty<GradientBase>("gradient", gradient, defaultValue: nil)
        )
        properties.add(
            DiagnosticsProperty<BoxShape>("shape", shape, defaultValue: BoxShape.rectangle)
        )
    }

    /// Returns a `DiagnosticsNode` representation of this object.
    public func toDiagnosticsNode(name: String? = nil, style: DiagnosticsTreeStyle? = nil) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style)
    }
}

// MARK: - Equatable Conformance

extension BoxDecoration: Equatable {}

// MARK: - Hashable Conformance

extension BoxDecoration: Hashable {}

// MARK: - BoxDecorationPainter

/// An object that paints a `BoxDecoration` into a canvas.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_decoration.dart`
/// **Original Name:** `_BoxDecorationPainter`
/// **Lines:** 400-591
internal class BoxDecorationPainter: BoxPainter {

    /// The decoration configuration.
    ///
    /// **Dart Source:** `box_decoration.dart:403`
    private let decoration: BoxDecoration

    /// Cached paint for the background.
    ///
    /// **Dart Source:** `box_decoration.dart:405`
    private var cachedBackgroundPaint: Paint?

    /// The rect for which the cached background paint was created.
    ///
    /// **Dart Source:** `box_decoration.dart:406`
    private var rectForCachedBackgroundPaint: Rect?

    /// Creates a `BoxDecorationPainter` for the given decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:401`
    init(_ decoration: BoxDecoration, onChanged: VoidCallback? = nil) {
        self.decoration = decoration
        super.init(onChanged: onChanged)
    }

    /// Get or create the background paint, caching it for reuse.
    ///
    /// **Dart Source:** `box_decoration.dart:407-427`
    private func getBackgroundPaint(_ rect: Rect, _ textDirection: TextDirection?) -> Paint {
        assert(decoration.gradient != nil || rectForCachedBackgroundPaint == nil)

        if cachedBackgroundPaint == nil ||
            (decoration.gradient != nil && rectForCachedBackgroundPaint != rect) {
            let paint = Paint()
            if let blendMode = decoration.backgroundBlendMode {
                paint.blendMode = blendMode
            }
            if let color = decoration.color {
                paint.color = color
            }
            if let gradient = decoration.gradient {
                paint.shader = gradient.createShader(rect: rect, textDirection: textDirection)
                rectForCachedBackgroundPaint = rect
            }
            cachedBackgroundPaint = paint
        }

        return cachedBackgroundPaint!
    }

    /// Paint the box shape on the canvas using the given paint.
    ///
    /// **Dart Source:** `box_decoration.dart:429-446`
    private func paintBox(
        _ canvas: Canvas,
        _ rect: Rect,
        _ paint: Paint,
        _ textDirection: TextDirection?
    ) {
        switch decoration.shape {
        case .circle:
            assert(
                decoration.borderRadius == nil,
                "A circle cannot have a border radius. Remove either the shape or the borderRadius argument."
            )
            let center = rect.center
            let radius = rect.shortestSide / 2.0
            canvas.drawCircle(center, radius, paint)
        case .rectangle:
            if decoration.borderRadius == nil ||
               decoration.borderRadius as? BorderRadius == BorderRadius.zero {
                canvas.drawRect(rect, paint)
            } else {
                canvas.drawRRect(
                    decoration.borderRadius!.resolve(textDirection).toRRect(rect),
                    paint
                )
            }
        }
    }

    /// Paint the shadows for this decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:448-470`
    private func paintShadows(
        _ canvas: Canvas,
        _ rect: Rect,
        _ textDirection: TextDirection?
    ) {
        guard let shadows = decoration.boxShadow else { return }
        for boxShadow in shadows {
            let paint = boxShadow.toPaint()
            let bounds = rect.shift(boxShadow.offset).inflate(boxShadow.spreadRadius)
            #if DEBUG
            if debugDisableShadows && boxShadow.blurStyle == .outer {
                canvas.save()
                canvas.clipRect(bounds)
            }
            #endif
            paintBox(canvas, bounds, paint, textDirection)
            #if DEBUG
            if debugDisableShadows && boxShadow.blurStyle == .outer {
                canvas.restore()
            }
            #endif
        }
    }

    /// Paint the background color of the decoration.
    ///
    /// **Dart Source:** `box_decoration.dart:472-479`
    private func paintBackgroundColor(
        _ canvas: Canvas,
        _ rect: Rect,
        _ textDirection: TextDirection?
    ) {
        if decoration.color != nil || decoration.gradient != nil {
            // When border is filled, the rect is reduced to avoid anti-aliasing
            // rounding error leaking the background color around the clipped shape.
            let adjustedRect = adjustedRectOnOutlinedBorder(rect, textDirection)
            paintBox(canvas, adjustedRect, getBackgroundPaint(rect, textDirection), textDirection)
        }
    }

    /// Calculate the adjusted side inset for anti-aliasing correction.
    ///
    /// **Dart Source:** `box_decoration.dart:481-486`
    private func calculateAdjustedSide(_ side: BorderSide) -> Double {
        if side.color.a == 1.0 && side.style == .solid {
            return side.strokeInset
        }
        return 0
    }

    /// Adjust the rect for outlined borders to avoid anti-aliasing artifacts.
    ///
    /// **Dart Source:** `box_decoration.dart:488-533`
    private func adjustedRectOnOutlinedBorder(
        _ rect: Rect,
        _ textDirection: TextDirection?
    ) -> Rect {
        guard let decoBorder = decoration.border else {
            return rect
        }

        if let border = decoBorder as? Border {
            let insets = EdgeInsets.fromLTRB(
                calculateAdjustedSide(border.left),
                calculateAdjustedSide(border.top),
                calculateAdjustedSide(border.right),
                calculateAdjustedSide(border.bottom)
            ) / 2

            return Rect.fromLTRB(
                rect.left + insets.left,
                rect.top + insets.top,
                rect.right - insets.right,
                rect.bottom - insets.bottom
            )
        } else if let border = decoBorder as? BorderDirectional, let textDirection = textDirection {
            let leftSide: BorderSide
            let rightSide: BorderSide
            switch textDirection {
            case .rtl:
                leftSide = border.end
                rightSide = border.start
            case .ltr:
                leftSide = border.start
                rightSide = border.end
            @unknown default:
                leftSide = border.start
                rightSide = border.end
            }

            let insets = EdgeInsets.fromLTRB(
                calculateAdjustedSide(leftSide),
                calculateAdjustedSide(border.top),
                calculateAdjustedSide(rightSide),
                calculateAdjustedSide(border.bottom)
            ) / 2

            return Rect.fromLTRB(
                rect.left + insets.left,
                rect.top + insets.top,
                rect.right - insets.right,
                rect.bottom - insets.bottom
            )
        }
        return rect
    }

    // TODO: Add _paintBackgroundImage when DecorationImage is migrated.
    // private var imagePainter: DecorationImagePainter?
    // private func paintBackgroundImage(_ canvas: Canvas, _ rect: Rect, _ configuration: ImageConfiguration) { ... }

    /// Discard any resources being held by the object.
    ///
    /// **Dart Source:** `box_decoration.dart:563-567`
    override func dispose() {
        // TODO: imagePainter?.dispose() when DecorationImage is migrated
        super.dispose()
    }

    /// Paint the box decoration into the given location on the given canvas.
    ///
    /// **Dart Source:** `box_decoration.dart:570-585`
    override func paint(_ canvas: Canvas, _ offset: Offset, _ configuration: ImageConfiguration) {
        assert(configuration.size != nil)
        let rect = Rect.fromLTWH(
            offset.dx, offset.dy,
            configuration.size!.width, configuration.size!.height
        )
        let textDirection = configuration.textDirection
        paintShadows(canvas, rect, textDirection)
        paintBackgroundColor(canvas, rect, textDirection)
        // TODO: paintBackgroundImage(canvas, rect, configuration) when DecorationImage is migrated
        decoration.border?.paint(
            canvas,
            rect,
            textDirection: configuration.textDirection,
            shape: decoration.shape,
            borderRadius: decoration.borderRadius?.resolve(textDirection)
        )
    }

    /// A string representation of this painter.
    ///
    /// **Dart Source:** `box_decoration.dart:587-590`
    var description: String {
        "BoxPainter for \(decoration)"
    }
}
