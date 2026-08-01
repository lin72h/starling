// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A border that fits an elliptical shape.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/oval_border.dart`

import FlutterSwiftBridge

// MARK: - OvalBorder

/// A border that fits an elliptical shape.
///
/// Typically used with `ShapeDecoration` to draw an oval. Instead of centering
/// the border to a square, like `CircleBorder`, it fills the available space,
/// such that it touches the edges of the box. There is no difference between
/// `CircleBorder(eccentricity: 1.0)` and `OvalBorder()`. `OvalBorder` works as
/// an alias for users to discover this feature.
///
/// **Dart Source:** `oval_border.dart:29-70`
public struct OvalBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `oval_border.dart` - inherited from OutlinedBorder via CircleBorder
    public let side: BorderSide

    /// Defines the ratio (0.0-1.0) from which the border will deform
    /// to fit a rectangle.
    /// When 0.0, it draws a circle touching at least two sides of the rectangle.
    /// When 1.0, it draws an oval touching all sides of the rectangle.
    ///
    /// **Dart Source:** `oval_border.dart:31` - inherited from CircleBorder, default 1.0
    public let eccentricity: Double

    // MARK: - Initializer

    /// Create an oval border.
    ///
    /// The `eccentricity` argument must be between 0.0 and 1.0 (inclusive).
    /// Defaults to 1.0 (full oval touching all edges), unlike `CircleBorder` which
    /// defaults to 0.0.
    ///
    /// **Dart Source:** `oval_border.dart:30-31`
    public init(
        side: BorderSide = .none,
        eccentricity: Double = 1.0
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
    /// **Dart Source:** `oval_border.dart:37-39`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        OvalBorder(
            side: side ?? self.side,
            eccentricity: eccentricity
        )
    }

    /// Returns a copy of this OvalBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `oval_border.dart:36-39`
    public func copyWith(
        side: BorderSide? = nil,
        eccentricity: Double? = nil
    ) -> OvalBorder {
        OvalBorder(
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
    /// **Dart Source:** `oval_border.dart:33-34`
    public func scale(_ t: Double) -> any ShapeBorder {
        OvalBorder(side: side.scale(t), eccentricity: eccentricity)
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// When `a` is an `OvalBorder`, interpolates both side and eccentricity.
    /// When `a` is a `CircleBorder`, falls back to CircleBorder-style interpolation.
    ///
    /// **Dart Source:** `oval_border.dart:41-50`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? OvalBorder {
            return OvalBorder(
                side: BorderSide.lerp(a.side, side, t),
                eccentricity: clampDouble(lerpDouble(a.eccentricity, eccentricity, t)!, 0.0, 1.0)
            )
        }
        // Fall back to CircleBorder-style lerpFrom behavior
        // **Dart Source:** `oval_border.dart:49` - super.lerpFrom(a, t) calls CircleBorder.lerpFrom
        if let a = a as? CircleBorder {
            return OvalBorder(
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
    /// When `b` is an `OvalBorder`, interpolates both side and eccentricity.
    /// When `b` is a `CircleBorder`, falls back to CircleBorder-style interpolation.
    ///
    /// **Dart Source:** `oval_border.dart:52-61`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? OvalBorder {
            return OvalBorder(
                side: BorderSide.lerp(side, b.side, t),
                eccentricity: clampDouble(lerpDouble(eccentricity, b.eccentricity, t)!, 0.0, 1.0)
            )
        }
        // Fall back to CircleBorder-style lerpTo behavior
        // **Dart Source:** `oval_border.dart:60` - super.lerpTo(b, t) calls CircleBorder.lerpTo
        if let b = b as? CircleBorder {
            return OvalBorder(
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
    /// **Dart Source:** `circle_border.dart:126-137` - inherited from CircleBorder
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
    /// **Dart Source:** `circle_border.dart:81-83` - inherited from CircleBorder
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addOval(adjustRect(rect).deflate(side.strokeInset))
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `circle_border.dart:86-88` - inherited from CircleBorder
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
    /// **Dart Source:** `circle_border.dart:91-97` - inherited from CircleBorder
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
    /// **Dart Source:** `circle_border.dart:99-100` - inherited from CircleBorder
    public var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `circle_border.dart:108-124` - inherited from CircleBorder
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

    /// **Dart Source:** `circle_border.dart:140-145` - inherited equality from CircleBorder
    public static func == (lhs: OvalBorder, rhs: OvalBorder) -> Bool {
        lhs.side == rhs.side && lhs.eccentricity == rhs.eccentricity
    }

    /// **Dart Source:** `circle_border.dart:148` - inherited hashCode from CircleBorder
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(eccentricity)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `oval_border.dart:63-69`
    public var description: String {
        if eccentricity != 1.0 {
            return "\(objectRuntimeType(self, "OvalBorder"))(\(side), eccentricity: \(eccentricity))"
        }
        return "\(objectRuntimeType(self, "OvalBorder"))(\(side))"
    }
}
