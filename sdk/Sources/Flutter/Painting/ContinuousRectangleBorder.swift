// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A rectangular border with smooth continuous transitions between the straight
/// sides and the rounded corners.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/continuous_rectangle_border.dart`

import FlutterSwiftBridge

// MARK: - ContinuousRectangleBorder

/// A rectangular border with smooth continuous transitions between the straight
/// sides and the rounded corners.
///
/// See also:
///
///  * `RoundedRectangleBorder` Which creates rectangles with rounded corners,
///    however its straight sides change into a rounded corner with a circular
///    radius in a step function instead of gradually like the
///    `ContinuousRectangleBorder`.
///
/// **Dart Source:** `continuous_rectangle_border.dart:38-158`
public struct ContinuousRectangleBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// The radius for each corner.
    ///
    /// Negative radius values are clamped to 0.0 by `getInnerPath` and
    /// `getOuterPath`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:42-46`
    public let borderRadius: any BorderRadiusGeometry

    // MARK: - Initializer

    /// Creates a `ContinuousRectangleBorder`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:39-40`
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
    /// **Dart Source:** `continuous_rectangle_border.dart:120-126`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        ContinuousRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius
        )
    }

    /// Returns a copy of this ContinuousRectangleBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:120-126`
    public func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil
    ) -> ContinuousRectangleBorder {
        ContinuousRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius
        )
    }

    // MARK: - ShapeBorder Protocol

    /// The widths of the sides of this border represented as an `EdgeInsets`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:48-49`
    public var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: side.width)
    }

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:51-54`
    public func scale(_ t: Double) -> any ShapeBorder {
        ContinuousRectangleBorder(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t)
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:56-65`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? ContinuousRectangleBorder {
            return ContinuousRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t)!
            )
        }
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:67-76`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? ContinuousRectangleBorder {
            return ContinuousRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t)!
            )
        }
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Clamps a value to the shortest side of the rrect.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:78-80`
    private func clampToShortest(_ rrect: RRect, _ value: Double) -> Double {
        return value > rrect.shortestSide ? rrect.shortestSide : value
    }

    /// Creates a path with smooth continuous transitions between
    /// straight sides and rounded corners using cubic bezier curves.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:82-108`
    private func getPath(_ rrect: RRect) -> Path {
        let left = rrect.left
        let right = rrect.right
        let top = rrect.top
        let bottom = rrect.bottom
        // Radii will be clamped to the value of the shortest side
        // of rrect to avoid strange tie-fighter shapes.
        let tlRadiusX = max(0.0, clampToShortest(rrect, rrect.tlRadiusX))
        let tlRadiusY = max(0.0, clampToShortest(rrect, rrect.tlRadiusY))
        let trRadiusX = max(0.0, clampToShortest(rrect, rrect.trRadiusX))
        let trRadiusY = max(0.0, clampToShortest(rrect, rrect.trRadiusY))
        let blRadiusX = max(0.0, clampToShortest(rrect, rrect.blRadiusX))
        let blRadiusY = max(0.0, clampToShortest(rrect, rrect.blRadiusY))
        let brRadiusX = max(0.0, clampToShortest(rrect, rrect.brRadiusX))
        let brRadiusY = max(0.0, clampToShortest(rrect, rrect.brRadiusY))

        let path = Path()
        path.moveTo(left, top + tlRadiusX)
        path.cubicTo(left, top, left, top, left + tlRadiusY, top)
        path.lineTo(right - trRadiusX, top)
        path.cubicTo(right, top, right, top, right, top + trRadiusY)
        path.lineTo(right, bottom - brRadiusX)
        path.cubicTo(right, bottom, right, bottom, right - brRadiusY, bottom)
        path.lineTo(left + blRadiusX, bottom)
        path.cubicTo(left, bottom, left, bottom, left, bottom - blRadiusY)
        path.close()
        return path
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:110-113`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        getPath(
            borderRadius.resolve(textDirection).toRRect(rect).deflate(side.width)
        )
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:115-118`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        getPath(borderRadius.resolve(textDirection).toRRect(rect))
    }

    // MARK: - Painting

    /// Paint a canvas with the appropriate shape.
    ///
    /// **Dart Source:** `borders.dart:608-617`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        // Default implementation - not optimized for this shape
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `borders.dart:619-638`
    public var preferPaintInterior: Bool { false }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `continuous_rectangle_border.dart:128-139`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        if rect.isEmpty {
            return
        }
        switch side.style {
        case .none:
            break
        case .solid:
            canvas.drawPath(getOuterPath(rect, textDirection: textDirection), side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `continuous_rectangle_border.dart:141-149`
    public static func == (lhs: ContinuousRectangleBorder, rhs: ContinuousRectangleBorder) -> Bool {
        lhs.side == rhs.side && lhs.borderRadius == rhs.borderRadius
    }

    /// **Dart Source:** `continuous_rectangle_border.dart:151-152`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `continuous_rectangle_border.dart:154-157`
    public var description: String {
        "\(objectRuntimeType(self, "ContinuousRectangleBorder"))(\(side), \(borderRadius))"
    }
}
