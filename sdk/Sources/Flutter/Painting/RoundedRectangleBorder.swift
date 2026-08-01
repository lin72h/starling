// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Rounded rectangle border types for defining shape outlines with rounded corners.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/rounded_rectangle_border.dart`

import FlutterSwiftBridge

// MARK: - RRectLikeBorder Protocol

/// A common interface for `RoundedRectangleBorder` and `RoundedSuperellipseBorder`.
///
/// **Dart Source:** `rounded_rectangle_border.dart:20-22`
protocol RRectLikeBorder: OutlinedBorder {
    var borderRadius: any BorderRadiusGeometry { get }
}

// MARK: - RoundedRectangleBorder

/// A rectangular border with rounded corners.
///
/// Typically used with `ShapeDecoration` to draw a box with a rounded
/// rectangle.
///
/// This shape can interpolate to and from `CircleBorder`.
///
/// See also:
///
///  * `BorderSide`, which is used to describe each side of the box.
///  * `Border`, which, when used with `BoxDecoration`, can also
///    describe a rounded rectangle.
///  * `RoundedSuperellipseBorder`, which uses a smoother shape similar to the one
///    used in iOS design.
///
/// **Dart Source:** `rounded_rectangle_border.dart:38-158`
public struct RoundedRectangleBorder: OutlinedBorder, RRectLikeBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// The radii for each corner.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:42-44`
    public let borderRadius: any BorderRadiusGeometry

    // MARK: - Initializer

    /// Creates a rounded rectangle border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:38-40`
    public init(
        side: BorderSide = .none,
        borderRadius: any BorderRadiusGeometry = BorderRadius.zero
    ) {
        self.side = side
        self.borderRadius = borderRadius
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:89-97`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        RoundedRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius
        )
    }

    /// Returns a copy of this RoundedRectangleBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:89-97`
    public func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil
    ) -> RoundedRectangleBorder {
        RoundedRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius
        )
    }

    // MARK: - ShapeBorder Protocol

    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// **Dart Source:** `borders.dart:662-663` - inherited from OutlinedBorder
    public var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:46-49`
    public func scale(_ t: Double) -> any ShapeBorder {
        RoundedRectangleBorder(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t)
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:51-68`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? RoundedRectangleBorder {
            return RoundedRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t)!
            )
        }
        if let a = a as? CircleBorder {
            return RoundedRectangleToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: borderRadius,
                circularity: 1.0 - t,
                eccentricity: a.eccentricity
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:70-87`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? RoundedRectangleBorder {
            return RoundedRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t)!
            )
        }
        if let b = b as? CircleBorder {
            return RoundedRectangleToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: borderRadius,
                circularity: t,
                eccentricity: b.eccentricity
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:99-104`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let borderRect = borderRadius.resolve(textDirection).toRRect(rect)
        let adjustedRect = borderRect.deflate(side.strokeInset)
        let path = Path()
        path.addRRect(adjustedRect)
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:106-109`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRRect(borderRadius.resolve(textDirection).toRRect(rect))
        return path
    }

    // MARK: - Painting

    /// Paint the interior of the shape on the given canvas.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:111-118`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        if borderRadius == BorderRadius.zero {
            canvas.drawRect(rect, paint)
        } else {
            canvas.drawRRect(borderRadius.resolve(textDirection).toRRect(rect), paint)
        }
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:120-121`
    public var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:123-139`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            if side.width == 0.0 {
                canvas.drawRRect(borderRadius.resolve(textDirection).toRRect(rect), side.toPaint())
            } else {
                let paint = Paint()
                paint.color = side.color
                let borderRect = borderRadius.resolve(textDirection).toRRect(rect)
                let inner = borderRect.deflate(side.strokeInset)
                let outer = borderRect.inflate(side.strokeOutset)
                canvas.drawDRRect(outer, inner, paint)
            }
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `rounded_rectangle_border.dart:141-149`
    public static func == (lhs: RoundedRectangleBorder, rhs: RoundedRectangleBorder) -> Bool {
        lhs.side == rhs.side && lhs.borderRadius == rhs.borderRadius
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:151-152`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `rounded_rectangle_border.dart:154-157`
    public var description: String {
        "\(objectRuntimeType(self, "RoundedRectangleBorder"))(\(side), \(borderRadius))"
    }
}

// MARK: - RoundedSuperellipseBorder

/// A rectangular border with rounded corners following the shape of an
/// `RSuperellipse`.
///
/// Typically used with `ShapeDecoration` to draw a box that mimics the rounded
/// rectangle style commonly seen in iOS design.
///
/// See also:
///
///  * `RSuperellipse`, which defines the shape.
///  * `RoundedRectangleBorder`, which uses the traditional `RRect` shape.
///
/// **Dart Source:** `rounded_rectangle_border.dart:226-360`
public struct RoundedSuperellipseBorder: OutlinedBorder, RRectLikeBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// The radii for each corner.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:234-236`
    public let borderRadius: any BorderRadiusGeometry

    // MARK: - Initializer

    /// Creates a rounded superellipse border.
    ///
    /// If `borderRadius` is not specified or nil, it defaults to
    /// `BorderRadius.zero`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:226-232`
    public init(
        side: BorderSide = .none,
        borderRadius: (any BorderRadiusGeometry)? = nil
    ) {
        self.side = side
        self.borderRadius = borderRadius ?? BorderRadius.zero
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:281-289`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        RoundedSuperellipseBorder(
            side: side ?? self.side,
            borderRadius: borderRadius
        )
    }

    /// Returns a copy of this RoundedSuperellipseBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:281-289`
    public func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil
    ) -> RoundedSuperellipseBorder {
        RoundedSuperellipseBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius
        )
    }

    // MARK: - ShapeBorder Protocol

    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// **Dart Source:** `borders.dart:662-663` - inherited from OutlinedBorder
    public var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:238-241`
    public func scale(_ t: Double) -> any ShapeBorder {
        RoundedSuperellipseBorder(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t)
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:243-260`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? RoundedSuperellipseBorder {
            return RoundedSuperellipseBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t)
            )
        }
        if let a = a as? CircleBorder {
            return RoundedSuperellipseToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: borderRadius,
                circularity: 1.0 - t,
                eccentricity: a.eccentricity
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:262-279`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? RoundedSuperellipseBorder {
            return RoundedSuperellipseBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t)
            )
        }
        if let b = b as? CircleBorder {
            return RoundedSuperellipseToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: borderRadius,
                circularity: t,
                eccentricity: b.eccentricity
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:291-300`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        if borderRadius == BorderRadius.zero {
            path.addRect(rect.deflate(side.strokeInset))
        } else {
            let borderRect = borderRadius.resolve(textDirection).toRSuperellipse(rect)
            let adjustedRect = borderRect.deflate(side.strokeInset)
            path.addRSuperellipse(adjustedRect)
        }
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:302-309`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        if borderRadius == BorderRadius.zero {
            path.addRect(rect)
        } else {
            path.addRSuperellipse(borderRadius.resolve(textDirection).toRSuperellipse(rect))
        }
        return path
    }

    // MARK: - Painting

    /// Paint the interior of the shape on the given canvas.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:311-318`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        if borderRadius == BorderRadius.zero {
            canvas.drawRect(rect, paint)
        } else {
            canvas.drawRSuperellipse(borderRadius.resolve(textDirection).toRSuperellipse(rect), paint)
        }
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:320-321`
    public var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:323-341`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            let strokeOffset = (side.strokeOutset - side.strokeInset) / 2
            if borderRadius == BorderRadius.zero {
                let base = rect.inflate(strokeOffset)
                canvas.drawRect(base, side.toPaint())
            } else {
                let base = borderRadius
                    .resolve(textDirection)
                    .toRSuperellipse(rect)
                    .inflate(strokeOffset)
                canvas.drawRSuperellipse(base, side.toPaint())
            }
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `rounded_rectangle_border.dart:343-351`
    public static func == (lhs: RoundedSuperellipseBorder, rhs: RoundedSuperellipseBorder) -> Bool {
        lhs.side == rhs.side && lhs.borderRadius == rhs.borderRadius
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:353-354`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `rounded_rectangle_border.dart:356-359`
    public var description: String {
        "\(objectRuntimeType(self, "RoundedSuperellipseBorder"))(\(side), \(borderRadius))"
    }
}

// MARK: - ShapeToCircleBorder

/// Generic base class for shape-to-circle transition borders.
///
/// Used when lerping between a rounded rectangle type and a `CircleBorder`.
///
/// **Dart Source:** `rounded_rectangle_border.dart:404-604`
class ShapeToCircleBorder<T: RRectLikeBorder>: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart` - inherited from OutlinedBorder
    let side: BorderSide

    /// The border radius.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:415`
    let borderRadius: any BorderRadiusGeometry

    /// How circular the border is (0.0 = original shape, 1.0 = circle).
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:416`
    let circularity: Double

    /// The eccentricity of the circle (0.0 = circle, 1.0 = oval).
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:417`
    let eccentricity: Double

    // MARK: - Initializer

    /// **Dart Source:** `rounded_rectangle_border.dart:404-410`
    init(
        side: BorderSide = .none,
        borderRadius: any BorderRadiusGeometry = BorderRadius.zero,
        circularity: Double,
        eccentricity: Double
    ) {
        self.side = side
        self.borderRadius = borderRadius
        self.circularity = circularity
        self.eccentricity = eccentricity
    }

    // MARK: - Abstract Methods

    /// Draws the shape on the canvas.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:412`
    func drawShape(_ canvas: Canvas, _ rect: Rect, _ radius: BorderRadius, _ paint: Paint, _ inflation: Double? = nil) {
        fatalError("Subclasses must implement drawShape")
    }

    /// Builds a path for the shape.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:413`
    func buildPath(_ rect: Rect, _ radius: BorderRadius, _ inflation: Double? = nil) -> Path {
        fatalError("Subclasses must implement buildPath")
    }

    /// Returns a copy with the given fields replaced.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:560-565`
    func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil,
        circularity: Double? = nil,
        eccentricity: Double? = nil
    ) -> ShapeToCircleBorder<T> {
        fatalError("Subclasses must implement copyWith")
    }

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:560-565`
    func copyWith(side: BorderSide?) -> any OutlinedBorder {
        copyWith(side: side, borderRadius: nil, circularity: nil, eccentricity: nil)
    }

    // MARK: - ShapeBorder Protocol

    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// **Dart Source:** `borders.dart:662-663` - inherited from OutlinedBorder
    var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:419-427`
    func scale(_ t: Double) -> any ShapeBorder {
        copyWith(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t),
            circularity: t,
            eccentricity: eccentricity
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:429-456`
    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? T {
            return copyWith(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t),
                circularity: circularity * t,
                eccentricity: eccentricity
            )
        }
        if let a = a as? CircleBorder {
            return copyWith(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: borderRadius,
                circularity: circularity + (1.0 - circularity) * (1.0 - t),
                eccentricity: a.eccentricity
            )
        }
        if let a = a as? ShapeToCircleBorder<T> {
            return copyWith(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t),
                circularity: lerpDouble(a.circularity, circularity, t),
                eccentricity: eccentricity
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:458-485`
    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? T {
            return copyWith(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t),
                circularity: circularity * (1.0 - t),
                eccentricity: eccentricity
            )
        }
        if let b = b as? CircleBorder {
            return copyWith(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: borderRadius,
                circularity: circularity + (1.0 - circularity) * t,
                eccentricity: b.eccentricity
            )
        }
        if let b = b as? ShapeToCircleBorder<T> {
            return copyWith(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t),
                circularity: lerpDouble(circularity, b.circularity, t),
                eccentricity: eccentricity
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Adjusts the rect based on circularity and eccentricity.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:487-500`
    private func adjustRect(_ rect: Rect) -> Rect {
        if circularity == 0.0 || rect.width == rect.height {
            return rect
        }
        if rect.width < rect.height {
            let partialDelta = (rect.height - rect.width) / 2
            let delta = circularity * partialDelta * (1.0 - eccentricity)
            return Rect.fromLTRB(rect.left, rect.top + delta, rect.right, rect.bottom - delta)
        } else {
            let partialDelta = (rect.width - rect.height) / 2
            let delta = circularity * partialDelta * (1.0 - eccentricity)
            return Rect.fromLTRB(rect.left + delta, rect.top, rect.right - delta, rect.bottom)
        }
    }

    /// Adjusts the border radius based on circularity and eccentricity.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:502-531`
    private func adjustBorderRadius(_ rect: Rect, _ textDirection: TextDirection?) -> BorderRadius {
        let resolvedRadius = borderRadius.resolve(textDirection)
        if circularity == 0.0 {
            return resolvedRadius
        }
        if eccentricity != 0.0 {
            if rect.width < rect.height {
                return BorderRadius.lerp(
                    resolvedRadius,
                    BorderRadius.all(
                        Radius(elliptical: rect.width / 2, (0.5 + eccentricity / 2) * rect.height / 2)
                    ),
                    circularity
                )!
            } else {
                return BorderRadius.lerp(
                    resolvedRadius,
                    BorderRadius.all(
                        Radius(elliptical: (0.5 + eccentricity / 2) * rect.width / 2, rect.height / 2)
                    ),
                    circularity
                )!
            }
        }
        return BorderRadius.lerp(
            resolvedRadius,
            BorderRadius.circular(rect.shortestSide / 2),
            circularity
        )!
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:533-540`
    func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        buildPath(
            adjustRect(rect),
            adjustBorderRadius(rect, textDirection),
            -lerpDouble(side.width, 0, side.strokeAlign)!
        )
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:542-545`
    func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        buildPath(adjustRect(rect), adjustBorderRadius(rect, textDirection))
    }

    // MARK: - Painting

    /// Paint the interior of the shape on the given canvas.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:547-555`
    func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        let adjustedBorderRadius = adjustBorderRadius(rect, textDirection)
        if adjustedBorderRadius == BorderRadius.zero {
            canvas.drawRect(adjustRect(rect), paint)
        } else {
            drawShape(canvas, adjustRect(rect), adjustedBorderRadius, paint)
        }
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:557-558`
    var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `rounded_rectangle_border.dart:567-581`
    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            drawShape(
                canvas,
                adjustRect(rect),
                adjustBorderRadius(rect, textDirection),
                side.toPaint(),
                side.strokeOffset / 2
            )
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `rounded_rectangle_border.dart:583-592`
    static func == (lhs: ShapeToCircleBorder<T>, rhs: ShapeToCircleBorder<T>) -> Bool {
        lhs.side == rhs.side &&
        lhs.borderRadius == rhs.borderRadius &&
        lhs.circularity == rhs.circularity
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:594-595`
    func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
        hasher.combine(circularity)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `rounded_rectangle_border.dart:597-603`
    var description: String {
        if eccentricity != 0.0 {
            return "\(T.self)(\(side), \(borderRadius), \(String(format: "%.1f", circularity * 100))% of the way to being a CircleBorder that is \(String(format: "%.1f", eccentricity * 100))% oval)"
        }
        return "\(T.self)(\(side), \(borderRadius), \(String(format: "%.1f", circularity * 100))% of the way to being a CircleBorder)"
    }
}

// MARK: - RoundedRectangleToCircleBorder

/// Transition border for lerping between `RoundedRectangleBorder` and `CircleBorder`.
///
/// **Dart Source:** `rounded_rectangle_border.dart:160-200`
class RoundedRectangleToCircleBorder: ShapeToCircleBorder<RoundedRectangleBorder> {

    // MARK: - Initializer

    /// **Dart Source:** `rounded_rectangle_border.dart:160-166`
    override init(
        side: BorderSide = .none,
        borderRadius: any BorderRadiusGeometry = BorderRadius.zero,
        circularity: Double,
        eccentricity: Double
    ) {
        super.init(
            side: side,
            borderRadius: borderRadius,
            circularity: circularity,
            eccentricity: eccentricity
        )
    }

    // MARK: - Override Methods

    /// **Dart Source:** `rounded_rectangle_border.dart:168-175`
    override func drawShape(_ canvas: Canvas, _ rect: Rect, _ radius: BorderRadius, _ paint: Paint, _ inflation: Double? = nil) {
        var rrect = radius.toRRect(rect)
        if let inflation = inflation {
            rrect = rrect.inflate(inflation)
        }
        canvas.drawRRect(rrect, paint)
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:177-184`
    override func buildPath(_ rect: Rect, _ radius: BorderRadius, _ inflation: Double? = nil) -> Path {
        var rrect = radius.toRRect(rect)
        if let inflation = inflation {
            rrect = rrect.inflate(inflation)
        }
        let path = Path()
        path.addRRect(rrect)
        return path
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:186-199`
    override func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil,
        circularity: Double? = nil,
        eccentricity: Double? = nil
    ) -> ShapeToCircleBorder<RoundedRectangleBorder> {
        RoundedRectangleToCircleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius,
            circularity: circularity ?? self.circularity,
            eccentricity: eccentricity ?? self.eccentricity
        )
    }
}

// MARK: - RoundedSuperellipseToCircleBorder

/// Transition border for lerping between `RoundedSuperellipseBorder` and `CircleBorder`.
///
/// **Dart Source:** `rounded_rectangle_border.dart:362-402`
class RoundedSuperellipseToCircleBorder: ShapeToCircleBorder<RoundedSuperellipseBorder> {

    // MARK: - Initializer

    /// **Dart Source:** `rounded_rectangle_border.dart:362-368`
    override init(
        side: BorderSide = .none,
        borderRadius: any BorderRadiusGeometry = BorderRadius.zero,
        circularity: Double,
        eccentricity: Double
    ) {
        super.init(
            side: side,
            borderRadius: borderRadius,
            circularity: circularity,
            eccentricity: eccentricity
        )
    }

    // MARK: - Override Methods

    /// **Dart Source:** `rounded_rectangle_border.dart:370-377`
    override func drawShape(_ canvas: Canvas, _ rect: Rect, _ radius: BorderRadius, _ paint: Paint, _ inflation: Double? = nil) {
        var rsuperellipse = radius.toRSuperellipse(rect)
        if let inflation = inflation {
            rsuperellipse = rsuperellipse.inflate(inflation)
        }
        canvas.drawRSuperellipse(rsuperellipse, paint)
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:379-386`
    override func buildPath(_ rect: Rect, _ radius: BorderRadius, _ inflation: Double? = nil) -> Path {
        var rsuperellipse = radius.toRSuperellipse(rect)
        if let inflation = inflation {
            rsuperellipse = rsuperellipse.inflate(inflation)
        }
        let path = Path()
        path.addRSuperellipse(rsuperellipse)
        return path
    }

    /// **Dart Source:** `rounded_rectangle_border.dart:388-401`
    override func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil,
        circularity: Double? = nil,
        eccentricity: Double? = nil
    ) -> ShapeToCircleBorder<RoundedSuperellipseBorder> {
        RoundedSuperellipseToCircleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius,
            circularity: circularity ?? self.circularity,
            eccentricity: eccentricity ?? self.eccentricity
        )
    }
}
