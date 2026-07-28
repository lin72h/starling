// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A border that fits a stadium-shaped border (a box with semicircles on the ends)
/// within the rectangle of the widget it is applied to.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/stadium_border.dart`

import FlutterSwiftBridge

// MARK: - StadiumBorder

/// A border that fits a stadium-shaped border (a box with semicircles on the ends)
/// within the rectangle of the widget it is applied to.
///
/// Typically used with `ShapeDecoration` to draw a stadium border.
///
/// If the rectangle is taller than it is wide, then the semicircles will be on the
/// top and bottom, and on the left and right otherwise.
///
/// See also:
///
///  * `BorderSide`, which is used to describe the border of the stadium.
///
/// **Dart Source:** `stadium_border.dart:29-135`
public struct StadiumBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `stadium_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    // MARK: - Initializer

    /// Create a stadium border.
    ///
    /// **Dart Source:** `stadium_border.dart:31`
    public init(side: BorderSide = .none) {
        self.side = side
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `stadium_border.dart:81-83`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        StadiumBorder(side: side ?? self.side)
    }

    /// Returns a copy of this StadiumBorder with the given fields
    /// replaced with the new values.
    ///
    /// **Dart Source:** `stadium_border.dart:81-83`
    public func copyWith(side: BorderSide? = nil) -> StadiumBorder {
        StadiumBorder(side: side ?? self.side)
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
    /// **Dart Source:** `stadium_border.dart:34`
    public func scale(_ t: Double) -> any ShapeBorder {
        StadiumBorder(side: side.scale(t))
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `stadium_border.dart:37-56`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? StadiumBorder {
            return StadiumBorder(side: BorderSide.lerp(a.side, side, t))
        }
        if let a = a as? CircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                circularity: 1.0 - t,
                eccentricity: a.eccentricity
            )
        }
        if let a = a as? RoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: a.borderRadius,
                rectilinearity: 1.0 - t
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
    /// **Dart Source:** `stadium_border.dart:59-78`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? StadiumBorder {
            return StadiumBorder(side: BorderSide.lerp(side, b.side, t))
        }
        if let b = b as? CircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                circularity: t,
                eccentricity: b.eccentricity
            )
        }
        if let b = b as? RoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: b.borderRadius,
                rectilinearity: t
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
    /// **Dart Source:** `stadium_border.dart:86-91`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let radius = Radius(circular: rect.shortestSide / 2.0)
        let borderRect = RRect(fromRectAndRadius: rect, radius)
        let adjustedRect = borderRect.deflate(side.strokeInset)
        let path = Path()
        path.addRRect(adjustedRect)
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `stadium_border.dart:94-97`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let radius = Radius(circular: rect.shortestSide / 2.0)
        let path = Path()
        path.addRRect(RRect(fromRectAndRadius: rect, radius))
        return path
    }

    // MARK: - Painting

    /// Paint the interior of the shape on the given canvas.
    ///
    /// **Dart Source:** `stadium_border.dart:100-103`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        let radius = Radius(circular: rect.shortestSide / 2.0)
        canvas.drawRRect(RRect(fromRectAndRadius: rect, radius), paint)
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// Returns `true` because `drawRRect` is faster than `drawPath`.
    ///
    /// **Dart Source:** `stadium_border.dart:106`
    public var preferPaintInterior: Bool { true }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `stadium_border.dart:109-118`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            let radius = Radius(circular: rect.shortestSide / 2)
            let borderRect = RRect(fromRectAndRadius: rect, radius)
            canvas.drawRRect(borderRect.inflate(side.strokeOffset / 2), side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `stadium_border.dart:121-126`
    public static func == (lhs: StadiumBorder, rhs: StadiumBorder) -> Bool {
        lhs.side == rhs.side
    }

    /// **Dart Source:** `stadium_border.dart:129`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `stadium_border.dart:132-134`
    public var description: String {
        "\(objectRuntimeType(self, "StadiumBorder"))(\(side))"
    }
}

// MARK: - StadiumToCircleBorder

/// Class to help with transitioning to/from a CircleBorder.
///
/// **Dart Source:** `stadium_border.dart:138-299`
struct StadiumToCircleBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `stadium_border.dart` - inherited from OutlinedBorder
    let side: BorderSide

    /// How circular the border is (0.0 = stadium, 1.0 = circle).
    ///
    /// **Dart Source:** `stadium_border.dart:141`
    let circularity: Double

    /// The eccentricity of the circle (0.0 = circle, 1.0 = oval).
    ///
    /// **Dart Source:** `stadium_border.dart:142`
    let eccentricity: Double

    // MARK: - Initializer

    /// **Dart Source:** `stadium_border.dart:139`
    init(
        side: BorderSide = .none,
        circularity: Double = 0.0,
        eccentricity: Double
    ) {
        self.side = side
        self.circularity = circularity
        self.eccentricity = eccentricity
    }

    // MARK: - OutlinedBorder Protocol

    /// **Dart Source:** `stadium_border.dart:260-266`
    func copyWith(side: BorderSide?) -> any OutlinedBorder {
        StadiumToCircleBorder(
            side: side ?? self.side,
            circularity: circularity,
            eccentricity: eccentricity
        )
    }

    /// **Dart Source:** `stadium_border.dart:260-266`
    func copyWith(
        side: BorderSide? = nil,
        circularity: Double? = nil,
        eccentricity: Double? = nil
    ) -> StadiumToCircleBorder {
        StadiumToCircleBorder(
            side: side ?? self.side,
            circularity: circularity ?? self.circularity,
            eccentricity: eccentricity ?? self.eccentricity
        )
    }

    // MARK: - ShapeBorder Protocol

    /// **Dart Source:** `borders.dart:662-663` - inherited from OutlinedBorder
    var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }

    /// **Dart Source:** `stadium_border.dart:145-147`
    func scale(_ t: Double) -> any ShapeBorder {
        StadiumToCircleBorder(
            side: side.scale(t),
            circularity: t,
            eccentricity: eccentricity
        )
    }

    /// **Dart Source:** `stadium_border.dart:150-173`
    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? StadiumBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                circularity: circularity * t,
                eccentricity: eccentricity
            )
        }
        if let a = a as? CircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                circularity: circularity + (1.0 - circularity) * (1.0 - t),
                eccentricity: a.eccentricity
            )
        }
        if let a = a as? StadiumToCircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(a.side, side, t),
                circularity: lerpDouble(a.circularity, circularity, t)!,
                eccentricity: lerpDouble(a.eccentricity, eccentricity, t)!
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// **Dart Source:** `stadium_border.dart:176-199`
    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? StadiumBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                circularity: circularity * (1.0 - t),
                eccentricity: eccentricity
            )
        }
        if let b = b as? CircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                circularity: circularity + (1.0 - circularity) * t,
                eccentricity: b.eccentricity
            )
        }
        if let b = b as? StadiumToCircleBorder {
            return StadiumToCircleBorder(
                side: BorderSide.lerp(side, b.side, t),
                circularity: lerpDouble(circularity, b.circularity, t)!,
                eccentricity: lerpDouble(eccentricity, b.eccentricity, t)!
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
    /// **Dart Source:** `stadium_border.dart:201-214`
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
    /// **Dart Source:** `stadium_border.dart:216-238`
    private func adjustBorderRadius(_ rect: Rect) -> BorderRadius {
        let circleRadius = BorderRadius.circular(rect.shortestSide / 2)
        if eccentricity != 0.0 {
            if rect.width < rect.height {
                return BorderRadius.lerp(
                    circleRadius,
                    BorderRadius.all(
                        Radius(elliptical: rect.width / 2, (0.5 + eccentricity / 2) * rect.height / 2)
                    ),
                    circularity
                )!
            } else {
                return BorderRadius.lerp(
                    circleRadius,
                    BorderRadius.all(
                        Radius(elliptical: (0.5 + eccentricity / 2) * rect.width / 2, rect.height / 2)
                    ),
                    circularity
                )!
            }
        }
        return circleRadius
    }

    // MARK: - Path Methods

    /// **Dart Source:** `stadium_border.dart:241-243`
    func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRRect(adjustBorderRadius(rect).toRRect(adjustRect(rect)).deflate(side.strokeInset))
        return path
    }

    /// **Dart Source:** `stadium_border.dart:247-249`
    func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRRect(adjustBorderRadius(rect).toRRect(adjustRect(rect)))
        return path
    }

    // MARK: - Painting

    /// **Dart Source:** `stadium_border.dart:252-254`
    func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        canvas.drawRRect(adjustBorderRadius(rect).toRRect(adjustRect(rect)), paint)
    }

    /// **Dart Source:** `stadium_border.dart:257`
    var preferPaintInterior: Bool { true }

    /// **Dart Source:** `stadium_border.dart:269-277`
    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            let borderRect = adjustBorderRadius(rect).toRRect(adjustRect(rect))
            canvas.drawRRect(borderRect.inflate(side.strokeOffset / 2), side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `stadium_border.dart:280-287`
    static func == (lhs: StadiumToCircleBorder, rhs: StadiumToCircleBorder) -> Bool {
        lhs.side == rhs.side && lhs.circularity == rhs.circularity
    }

    /// **Dart Source:** `stadium_border.dart:290`
    func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(circularity)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `stadium_border.dart:293-298`
    var description: String {
        if eccentricity != 0.0 {
            return "StadiumBorder(\(side), \(String(format: "%.1f", circularity * 100))% of the way to being a CircleBorder that is \(String(format: "%.1f", eccentricity * 100))% oval)"
        }
        return "StadiumBorder(\(side), \(String(format: "%.1f", circularity * 100))% of the way to being a CircleBorder)"
    }
}

// MARK: - StadiumToRoundedRectangleBorder

/// Class to help with transitioning to/from a RoundedRectangleBorder.
///
/// **Dart Source:** `stadium_border.dart:302-452`
struct StadiumToRoundedRectangleBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `stadium_border.dart` - inherited from OutlinedBorder
    let side: BorderSide

    /// The border radius of the target RoundedRectangleBorder.
    ///
    /// **Dart Source:** `stadium_border.dart:309`
    let borderRadius: any BorderRadiusGeometry

    /// How rectilinear the border is (0.0 = stadium, 1.0 = rounded rectangle).
    ///
    /// **Dart Source:** `stadium_border.dart:311`
    let rectilinearity: Double

    // MARK: - Initializer

    /// **Dart Source:** `stadium_border.dart:303-307`
    init(
        side: BorderSide = .none,
        borderRadius: any BorderRadiusGeometry = BorderRadius.zero,
        rectilinearity: Double = 0.0
    ) {
        self.side = side
        self.borderRadius = borderRadius
        self.rectilinearity = rectilinearity
    }

    // MARK: - OutlinedBorder Protocol

    /// **Dart Source:** `stadium_border.dart:408-418`
    func copyWith(side: BorderSide?) -> any OutlinedBorder {
        StadiumToRoundedRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius,
            rectilinearity: rectilinearity
        )
    }

    /// **Dart Source:** `stadium_border.dart:408-418`
    func copyWith(
        side: BorderSide? = nil,
        borderRadius: (any BorderRadiusGeometry)? = nil,
        rectilinearity: Double? = nil
    ) -> StadiumToRoundedRectangleBorder {
        StadiumToRoundedRectangleBorder(
            side: side ?? self.side,
            borderRadius: borderRadius ?? self.borderRadius,
            rectilinearity: rectilinearity ?? self.rectilinearity
        )
    }

    // MARK: - ShapeBorder Protocol

    /// **Dart Source:** `borders.dart:662-663` - inherited from OutlinedBorder
    var dimensions: any EdgeInsetsGeometry {
        EdgeInsets(all: max(side.strokeInset, 0))
    }

    /// **Dart Source:** `stadium_border.dart:314-320`
    func scale(_ t: Double) -> any ShapeBorder {
        StadiumToRoundedRectangleBorder(
            side: side.scale(t),
            borderRadius: borderRadius.multiplied(by: t),
            rectilinearity: t
        )
    }

    /// **Dart Source:** `stadium_border.dart:323-346`
    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? StadiumBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: borderRadius,
                rectilinearity: rectilinearity * t
            )
        }
        if let a = a as? RoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: borderRadius,
                rectilinearity: rectilinearity + (1.0 - rectilinearity) * (1.0 - t)
            )
        }
        if let a = a as? StadiumToRoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(a.side, side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(a.borderRadius, borderRadius, t)!,
                rectilinearity: lerpDouble(a.rectilinearity, rectilinearity, t)!
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// **Dart Source:** `stadium_border.dart:349-372`
    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? StadiumBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: borderRadius,
                rectilinearity: rectilinearity * (1.0 - t)
            )
        }
        if let b = b as? RoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: borderRadius,
                rectilinearity: rectilinearity + (1.0 - rectilinearity) * t
            )
        }
        if let b = b as? StadiumToRoundedRectangleBorder {
            return StadiumToRoundedRectangleBorder(
                side: BorderSide.lerp(side, b.side, t),
                borderRadius: BorderRadiusGeometryStatics.lerp(borderRadius, b.borderRadius, t)!,
                rectilinearity: lerpDouble(rectilinearity, b.rectilinearity, t)!
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Adjusts the border radius based on rectilinearity.
    ///
    /// When `borderRadius` is a `BorderRadius`, uses `BorderRadius.lerp` directly
    /// to avoid producing a `MixedBorderRadius` that requires a `TextDirection`
    /// to resolve.
    ///
    /// **Dart Source:** `stadium_border.dart:374-380`
    private func adjustBorderRadius(_ rect: Rect) -> any BorderRadiusGeometry {
        let stadiumRadius = BorderRadius.all(Radius(circular: rect.shortestSide / 2.0))
        if let br = borderRadius as? BorderRadius {
            return BorderRadius.lerp(
                br,
                stadiumRadius,
                1.0 - rectilinearity
            )!
        }
        return BorderRadiusGeometryStatics.lerp(
            borderRadius,
            stadiumRadius,
            1.0 - rectilinearity
        )!
    }

    // MARK: - Path Methods

    /// **Dart Source:** `stadium_border.dart:383-387`
    func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let borderRect = adjustBorderRadius(rect).resolve(textDirection).toRRect(rect)
        let adjustedRect = borderRect.deflate(lerpDouble(side.width, 0, side.strokeAlign)!)
        let path = Path()
        path.addRRect(adjustedRect)
        return path
    }

    /// **Dart Source:** `stadium_border.dart:390-392`
    func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRRect(adjustBorderRadius(rect).resolve(textDirection).toRRect(rect))
        return path
    }

    // MARK: - Painting

    /// **Dart Source:** `stadium_border.dart:395-402`
    func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        let adjustedBorderRadius = adjustBorderRadius(rect)
        if adjustedBorderRadius == BorderRadius.zero {
            canvas.drawRect(rect, paint)
        } else {
            canvas.drawRRect(adjustedBorderRadius.resolve(textDirection).toRRect(rect), paint)
        }
    }

    /// **Dart Source:** `stadium_border.dart:405`
    var preferPaintInterior: Bool { true }

    /// **Dart Source:** `stadium_border.dart:421-430`
    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            let adjustedBorderRadius = adjustBorderRadius(rect)
            let borderRect = adjustedBorderRadius.resolve(textDirection).toRRect(rect)
            canvas.drawRRect(borderRect.inflate(side.strokeOffset / 2), side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `stadium_border.dart:433-441`
    static func == (lhs: StadiumToRoundedRectangleBorder, rhs: StadiumToRoundedRectangleBorder) -> Bool {
        lhs.side == rhs.side &&
        lhs.borderRadius == rhs.borderRadius &&
        lhs.rectilinearity == rhs.rectilinearity
    }

    /// **Dart Source:** `stadium_border.dart:444`
    func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(borderRadius)
        hasher.combine(rectilinearity)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `stadium_border.dart:447-451`
    var description: String {
        "StadiumBorder(\(side), \(borderRadius), " +
        "\(String(format: "%.1f", rectilinearity * 100))% of the way to being a " +
        "RoundedRectangleBorder)"
    }
}
