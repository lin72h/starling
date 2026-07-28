// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A border that fits a circle within the available space.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/circle_border.dart`

import FlutterSwiftBridge

// MARK: - CircleBorder

/// A border that fits a circle within the available space.
///
/// Typically used with `ShapeDecoration` to draw a circle.
///
/// The `dimensions` assume that the border is being used in a square space.
/// When applied to a rectangular space, the border paints in the center of the
/// rectangle.
///
/// The `eccentricity` parameter describes how much a circle will deform to
/// fit the rectangle it is a border for. A value of zero implies no
/// deformation (a circle touching at least two sides of the rectangle), a
/// value of one implies full deformation (an oval touching all sides of the
/// rectangle).
///
/// **Dart Source:** `circle_border.dart:37-157`
public struct CircleBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `circle_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// Defines the ratio (0.0-1.0) from which the border will deform
    /// to fit a rectangle.
    /// When 0.0, it draws a circle touching at least two sides of the rectangle.
    /// When 1.0, it draws an oval touching all sides of the rectangle.
    ///
    /// **Dart Source:** `circle_border.dart:49-53`
    public let eccentricity: Double

    // MARK: - Initializer

    /// Create a circle border.
    ///
    /// The `eccentricity` argument must be between 0.0 and 1.0 (inclusive).
    ///
    /// **Dart Source:** `circle_border.dart:39-47`
    public init(
        side: BorderSide = .none,
        eccentricity: Double = 0.0
    ) {
        assert(
            eccentricity >= 0.0,
            "The eccentricity argument \(eccentricity) is not greater than or equal to zero."
        )
        assert(
            eccentricity <= 1.0,
            "The eccentricity argument \(eccentricity) is not less than or equal to one."
        )
        self.side = side
        self.eccentricity = eccentricity
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `circle_border.dart:103-105`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        CircleBorder(
            side: side ?? self.side,
            eccentricity: eccentricity
        )
    }

    /// Returns a copy of this CircleBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `circle_border.dart:103-105`
    public func copyWith(
        side: BorderSide? = nil,
        eccentricity: Double? = nil
    ) -> CircleBorder {
        CircleBorder(
            side: side ?? self.side,
            eccentricity: eccentricity ?? self.eccentricity
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
    /// **Dart Source:** `circle_border.dart:56`
    public func scale(_ t: Double) -> any ShapeBorder {
        CircleBorder(side: side.scale(t), eccentricity: eccentricity)
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `circle_border.dart:59-67`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? CircleBorder {
            return CircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                eccentricity: clampDouble(lerpDouble(a.eccentricity, eccentricity, t)!, 0.0, 1.0)
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
    /// **Dart Source:** `circle_border.dart:70-78`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? CircleBorder {
            return CircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                eccentricity: clampDouble(lerpDouble(eccentricity, b.eccentricity, t)!, 0.0, 1.0)
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Adjusts the rect based on eccentricity.
    ///
    /// When eccentricity is 0.0 or the rect is square, returns a square rect
    /// centered on the original rect with side length equal to the shortest side.
    /// Otherwise, shrinks the rect towards a square shape by the eccentricity factor.
    ///
    /// **Dart Source:** `circle_border.dart:126-137`
    private func adjustRect(_ rect: Rect) -> Rect {
        if eccentricity == 0.0 || rect.width == rect.height {
            return Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2.0)
        }
        if rect.width < rect.height {
            let delta = (1.0 - eccentricity) * (rect.height - rect.width) / 2.0
            return Rect.fromLTRB(rect.left, rect.top + delta, rect.right, rect.bottom - delta)
        } else {
            let delta = (1.0 - eccentricity) * (rect.width - rect.height) / 2.0
            return Rect.fromLTRB(rect.left + delta, rect.top, rect.right - delta, rect.bottom)
        }
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `circle_border.dart:81-83`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addOval(adjustRect(rect).deflate(side.strokeInset))
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `circle_border.dart:86-88`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addOval(adjustRect(rect))
        return path
    }

    // MARK: - Painting

    /// Paint the interior of the shape on the given canvas.
    ///
    /// Uses `drawCircle` when eccentricity is 0.0 for better performance,
    /// and `drawOval` otherwise.
    ///
    /// **Dart Source:** `circle_border.dart:91-97`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        if eccentricity == 0.0 {
            canvas.drawCircle(rect.center, rect.shortestSide / 2.0, paint)
        } else {
            canvas.drawOval(adjustRect(rect), paint)
        }
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// Returns `true` because `drawCircle`/`drawOval` are faster than `drawPath`.
    ///
    /// **Dart Source:** `circle_border.dart:99-100`
    public var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `circle_border.dart:108-124`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            if eccentricity == 0.0 {
                canvas.drawCircle(
                    rect.center,
                    (rect.shortestSide + side.strokeOffset) / 2,
                    side.toPaint()
                )
            } else {
                let borderRect = adjustRect(rect)
                canvas.drawOval(borderRect.inflate(side.strokeOffset / 2), side.toPaint())
            }
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `circle_border.dart:140-145`
    public static func == (lhs: CircleBorder, rhs: CircleBorder) -> Bool {
        lhs.side == rhs.side && lhs.eccentricity == rhs.eccentricity
    }

    /// **Dart Source:** `circle_border.dart:148`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(eccentricity)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `circle_border.dart:151-156`
    public var description: String {
        if eccentricity != 0.0 {
            return "\(objectRuntimeType(self, "CircleBorder"))(\(side), eccentricity: \(eccentricity))"
        }
        return "\(objectRuntimeType(self, "CircleBorder"))(\(side))"
    }
}
