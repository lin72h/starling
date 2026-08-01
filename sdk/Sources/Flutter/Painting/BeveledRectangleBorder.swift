// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A rectangular border with flattened or "beveled" corners.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/beveled_rectangle_border.dart`

import FlutterSwiftBridge

// MARK: - BeveledRectangleBorder

/// A rectangular border with flattened or "beveled" corners.
///
/// The line segments that connect the rectangle's four sides will
/// begin and at locations offset by the corresponding border radius,
/// but not farther than the side's center. If all the border radii
/// exceed the sides' half widths/heights the resulting shape is
/// diamond made by connecting the centers of the sides.
///
/// **Dart Source:** `beveled_rectangle_border.dart:23-149`
public struct BeveledRectangleBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// The radii for each corner.
    ///
    /// Each corner `Radius` defines the endpoints of a line segment that
    /// spans the corner. The endpoints are located in the same place as
    /// they would be for `RoundedRectangleBorder`, but they're connected
    /// by a straight line instead of an arc.
    ///
    /// Negative radius values are clamped to 0.0 by `getInnerPath` and
    /// `getOuterPath`.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:28-37`
    public let borderRadius: any BorderRadiusGeometry

    // MARK: - Initializer

    /// Creates a border like a `RoundedRectangleBorder` except that the corners
    /// are joined by straight lines instead of arcs.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:24-26`
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
    /// **Dart Source:** `beveled_rectangle_border.dart:69-74`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        BeveledRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius
        )
    }

    /// Returns a copy of this BeveledRectangleBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:66-74`
    public func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil
    ) -> BeveledRectangleBorder {
        BeveledRectangleBorder(
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
    /// **Dart Source:** `beveled_rectangle_border.dart:40-42`
    public func scale(_ t: Double) -> any ShapeBorder {
        BeveledRectangleBorder(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t)
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:45-53`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? BeveledRectangleBorder {
            return BeveledRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t)!
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
    /// **Dart Source:** `beveled_rectangle_border.dart:56-64`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? BeveledRectangleBorder {
            return BeveledRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t)!
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Creates a path for the beveled rectangle.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:76-103`
    private func getPath(_ rrect: RRect) -> Path {
        let centerLeft = Offset(rrect.left, rrect.center.dy)
        let centerRight = Offset(rrect.right, rrect.center.dy)
        let centerTop = Offset(rrect.center.dx, rrect.top)
        let centerBottom = Offset(rrect.center.dx, rrect.bottom)

        let tlRadiusX = max(0.0, rrect.tlRadiusX)
        let tlRadiusY = max(0.0, rrect.tlRadiusY)
        let trRadiusX = max(0.0, rrect.trRadiusX)
        let trRadiusY = max(0.0, rrect.trRadiusY)
        let blRadiusX = max(0.0, rrect.blRadiusX)
        let blRadiusY = max(0.0, rrect.blRadiusY)
        let brRadiusX = max(0.0, rrect.brRadiusX)
        let brRadiusY = max(0.0, rrect.brRadiusY)

        let vertices: [Offset] = [
            Offset(rrect.left, min(centerLeft.dy, rrect.top + tlRadiusY)),
            Offset(min(centerTop.dx, rrect.left + tlRadiusX), rrect.top),
            Offset(max(centerTop.dx, rrect.right - trRadiusX), rrect.top),
            Offset(rrect.right, min(centerRight.dy, rrect.top + trRadiusY)),
            Offset(rrect.right, max(centerRight.dy, rrect.bottom - brRadiusY)),
            Offset(max(centerBottom.dx, rrect.right - brRadiusX), rrect.bottom),
            Offset(min(centerBottom.dx, rrect.left + blRadiusX), rrect.bottom),
            Offset(rrect.left, max(centerLeft.dy, rrect.bottom - blRadiusY)),
        ]

        let path = Path()
        path.addPolygon(vertices, true)
        return path
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:106-108`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        getPath(
            borderRadius.resolve(textDirection).toRRect(rect).deflate(side.strokeInset)
        )
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `beveled_rectangle_border.dart:111-113`
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
    /// **Dart Source:** `beveled_rectangle_border.dart:116-130`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        if rect.isEmpty {
            return
        }
        switch side.style {
        case .none:
            break
        case .solid:
            let borderRect = borderRadius.resolve(textDirection).toRRect(rect)
            let adjustedRect = borderRect.inflate(side.strokeOutset)
            let path = getPath(adjustedRect)
            path.addPath(getInnerPath(rect, textDirection: textDirection), .zero)
            canvas.drawPath(path, side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `beveled_rectangle_border.dart:133-140`
    public static func == (lhs: BeveledRectangleBorder, rhs: BeveledRectangleBorder) -> Bool {
        lhs.side == rhs.side && lhs.borderRadius == rhs.borderRadius
    }

    /// **Dart Source:** `beveled_rectangle_border.dart:143`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `beveled_rectangle_border.dart:146-148`
    public var description: String {
        "\(objectRuntimeType(self, "BeveledRectangleBorder"))(\(side), \(borderRadius))"
    }
}
