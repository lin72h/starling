// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A border that fits a star or polygon-shaped border within the rectangle of
/// the widget it is applied to.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/star_border.dart`

import Foundation
import FlutterSwiftBridge

// MARK: - Private Constants

/// Conversion from radians to degrees.
///
/// **Dart Source:** `star_border.dart:21`
private let kRadToDeg: Double = 180 / .pi

/// Conversion from degrees to radians.
///
/// **Dart Source:** `star_border.dart:23`
private let kDegToRad: Double = .pi / 180

// MARK: - StarBorder

/// A border that fits a star or polygon-shaped border within the rectangle of
/// the widget it is applied to.
///
/// Typically used with `ShapeDecoration` to draw a polygonal or star shaped
/// border.
///
/// See also:
///
///  * `BorderSide`, which is used to describe how the edge of the shape is
///    drawn.
///
/// **Dart Source:** `star_border.dart:45-448`
public struct StarBorder: OutlinedBorder, Hashable {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// If `side` is `BorderSide.none`, which is the default, an outline is not drawn.
    /// Otherwise the outline is centered over the shape's boundary.
    ///
    /// **Dart Source:** `star_border.dart` - inherited from OutlinedBorder
    public let side: BorderSide

    /// The number of points in this star, or sides on a polygon.
    ///
    /// This is a floating point number: if this is not a whole number, then an
    /// additional star point or corner shorter than the others will be added to
    /// finish the shape. Only whole-numbered values will yield a symmetric shape.
    /// (This enables the number of points to be animated smoothly.)
    ///
    /// For stars created with `StarBorder`, this is the number of points on
    /// the star. For polygons created with `StarBorder.polygon`, this is the
    /// number of sides on the polygon.
    ///
    /// Must be greater than or equal to two.
    ///
    /// **Dart Source:** `star_border.dart:90-102`
    public let points: Double

    /// The amount of rounding on the points of stars, or the corners of polygons.
    ///
    /// This is a value between zero and one which describes how rounded the point
    /// or corner should be. A value of zero means no rounding (sharp corners),
    /// and a value of one means that the entire point or corner is a portion of a
    /// circle.
    ///
    /// Defaults to zero. The sum of `pointRounding` and `valleyRounding` must be
    /// less than or equal to one.
    ///
    /// **Dart Source:** `star_border.dart:123-132`
    public let pointRounding: Double

    /// The amount of rounding of the interior corners of stars.
    ///
    /// This is a value between zero and one which describes how rounded the inner
    /// corners in a star (the "valley" between points) should be. A value of zero
    /// means no rounding (sharp corners), and a value of one means that the
    /// entire corner is a portion of a circle.
    ///
    /// Defaults to zero. The sum of `pointRounding` and `valleyRounding` must be
    /// less than or equal to one. For polygons created with `StarBorder.polygon`,
    /// this will always be zero.
    ///
    /// **Dart Source:** `star_border.dart:134-144`
    public let valleyRounding: Double

    /// How much of the aspect ratio of the attached widget to take on.
    ///
    /// If `squash` is non-zero, the border will match the aspect ratio of the
    /// bounding box of the widget that it is attached to, which can give a
    /// squashed appearance.
    ///
    /// The `squash` parameter lets you control how much of that aspect ratio this
    /// border takes on.
    ///
    /// A value of zero means that the border will be drawn with a square aspect
    /// ratio at the size of the shortest side of the bounding rectangle, ignoring
    /// the aspect ratio of the widget, and a value of one means it will be drawn
    /// with the aspect ratio of the widget. The value of `squash` has no effect
    /// if the widget is square to begin with.
    ///
    /// Defaults to zero, and must be between zero and one, inclusive.
    ///
    /// **Dart Source:** `star_border.dart:155-171`
    public let squash: Double

    /// The rotation in radians (internal storage).
    ///
    /// **Dart Source:** `star_border.dart:153`
    private let _rotationRadians: Double

    /// The raw inner radius ratio, nil for polygons (computed from incircle).
    ///
    /// **Dart Source:** `star_border.dart:121`
    private let _innerRadiusRatio: Double?

    // MARK: - Initializer

    /// Create a star-shaped border with the given number of `points` on the star.
    ///
    /// **Dart Source:** `star_border.dart:48-71`
    public init(
        side: BorderSide = .none,
        points: Double = 5,
        innerRadiusRatio: Double = 0.4,
        pointRounding: Double = 0,
        valleyRounding: Double = 0,
        rotation: Double = 0,
        squash: Double = 0
    ) {
        assert(squash >= 0, "squash must be >= 0")
        assert(squash <= 1, "squash must be <= 1")
        assert(pointRounding >= 0, "pointRounding must be >= 0")
        assert(pointRounding <= 1, "pointRounding must be <= 1")
        assert(valleyRounding >= 0, "valleyRounding must be >= 0")
        assert(valleyRounding <= 1, "valleyRounding must be <= 1")
        assert(
            (valleyRounding + pointRounding) <= 1,
            "The sum of valleyRounding (\(valleyRounding)) and "
            + "pointRounding (\(pointRounding)) must not exceed one."
        )
        assert(innerRadiusRatio >= 0, "innerRadiusRatio must be >= 0")
        assert(innerRadiusRatio <= 1, "innerRadiusRatio must be <= 1")
        assert(points >= 2, "points must be >= 2")
        self.side = side
        self.points = points
        self.pointRounding = pointRounding
        self.valleyRounding = valleyRounding
        self.squash = squash
        self._rotationRadians = rotation * kDegToRad
        self._innerRadiusRatio = innerRadiusRatio
    }

    // MARK: - Polygon Factory

    /// Create a polygon border with the given number of `sides`.
    ///
    /// **Dart Source:** `star_border.dart:74-88`
    public static func polygon(
        side: BorderSide = .none,
        sides: Double = 5,
        pointRounding: Double = 0,
        rotation: Double = 0,
        squash: Double = 0
    ) -> StarBorder {
        assert(squash >= 0, "squash must be >= 0")
        assert(squash <= 1, "squash must be <= 1")
        assert(pointRounding >= 0, "pointRounding must be >= 0")
        assert(pointRounding <= 1, "pointRounding must be <= 1")
        assert(sides >= 2, "sides must be >= 2")
        return StarBorder(
            side: side,
            points: sides,
            innerRadiusRatio: nil,
            pointRounding: pointRounding,
            valleyRounding: 0,
            rotation: rotation,
            squash: squash
        )
    }

    /// Internal initializer that accepts a raw optional innerRadiusRatio (nil for polygons).
    private init(
        side: BorderSide,
        points: Double,
        innerRadiusRatio: Double?,
        pointRounding: Double,
        valleyRounding: Double,
        rotation: Double,
        squash: Double
    ) {
        self.side = side
        self.points = points
        self._innerRadiusRatio = innerRadiusRatio
        self.pointRounding = pointRounding
        self.valleyRounding = valleyRounding
        self.squash = squash
        self._rotationRadians = rotation * kDegToRad
    }

    // MARK: - Computed Properties

    /// The ratio of the inner radius of a star with the outer radius.
    ///
    /// When making a star using `StarBorder`, this is the ratio of the inner
    /// radius to the outer radius. If it is one, then the inner radius
    /// will equal the outer radius.
    ///
    /// For polygons created with `StarBorder.polygon`, getting this value will
    /// return the incircle radius of the polygon (the radius of a circle
    /// inscribed inside the polygon).
    ///
    /// Defaults to 0.4 for stars, and must be between zero and one, inclusive.
    ///
    /// **Dart Source:** `star_border.dart:115-119`
    public var innerRadiusRatio: Double {
        // Polygons are just a special case of a star where the inner radius is the
        // incircle radius of the polygon (the radius of an inscribed circle).
        _innerRadiusRatio ?? cos(.pi / points)
    }

    /// The rotation in clockwise degrees around the center of the shape.
    ///
    /// The rotation occurs before the `squash` effect is applied, so that you can
    /// fine tune where the points of a star or corners of a polygon start.
    ///
    /// Defaults to zero, meaning that the first point or corner is pointing up.
    ///
    /// **Dart Source:** `star_border.dart:152`
    public var rotation: Double {
        _rotationRadians * kRadToDeg
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `star_border.dart:362-380`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        StarBorder(
            side: side ?? self.side,
            points: points,
            innerRadiusRatio: innerRadiusRatio,
            pointRounding: pointRounding,
            valleyRounding: valleyRounding,
            rotation: rotation,
            squash: squash
        )
    }

    /// Returns a copy of this StarBorder with the given fields replaced
    /// with the new values.
    ///
    /// **Dart Source:** `star_border.dart:362-380`
    public func copyWith(
        side: BorderSide? = nil,
        points: Double? = nil,
        innerRadiusRatio: Double? = nil,
        pointRounding: Double? = nil,
        valleyRounding: Double? = nil,
        rotation: Double? = nil,
        squash: Double? = nil
    ) -> StarBorder {
        StarBorder(
            side: side ?? self.side,
            points: points ?? self.points,
            innerRadiusRatio: innerRadiusRatio ?? self.innerRadiusRatio,
            pointRounding: pointRounding ?? self.pointRounding,
            valleyRounding: valleyRounding ?? self.valleyRounding,
            rotation: rotation ?? self.rotation,
            squash: squash ?? self.squash
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
    /// **Dart Source:** `star_border.dart:174-184`
    public func scale(_ t: Double) -> any ShapeBorder {
        StarBorder(
            side: side.scale(t),
            points: points,
            innerRadiusRatio: innerRadiusRatio,
            pointRounding: pointRounding,
            valleyRounding: valleyRounding,
            rotation: rotation,
            squash: squash
        )
    }

    // MARK: - Lerp Helper

    /// Two-phase lerp helper: delegates to `first` when t < split, and to
    /// `second` for t >= split, each remapped to [0, 1].
    ///
    /// **Dart Source:** `star_border.dart:186-199`
    private func _twoPhaseLerp(
        _ t: Double,
        _ split: Double,
        _ first: (Double) -> (any ShapeBorder)?,
        _ second: (Double) -> (any ShapeBorder)?
    ) -> (any ShapeBorder)? {
        if t < split {
            return first(t * (1 / split))
        } else {
            let remapped = (1 / (1.0 - split)) * (t - split)
            return second(remapped)
        }
    }

    // MARK: - Lerp Methods

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `star_border.dart:202-280`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if t == 0 {
            return a
        }
        if t == 1.0 {
            return self
        }
        if let a = a as? StarBorder {
            return StarBorder(
                side: BorderSide.lerp(a.side, side, t),
                points: lerpDouble(a.points, points, t)!,
                innerRadiusRatio: lerpDouble(a.innerRadiusRatio, innerRadiusRatio, t)!,
                pointRounding: lerpDouble(a.pointRounding, pointRounding, t)!,
                valleyRounding: lerpDouble(a.valleyRounding, valleyRounding, t)!,
                rotation: lerpDouble(a._rotationRadians, _rotationRadians, t)! * kRadToDeg,
                squash: lerpDouble(a.squash, squash, t)!
            )
        }

        if let a = a as? CircleBorder {
            if points >= 2.5 {
                let lerpedPoints = lerpDouble(points.rounded(), points, t)!
                return StarBorder(
                    side: BorderSide.lerp(a.side, side, t),
                    points: lerpedPoints,
                    innerRadiusRatio: lerpDouble(cos(.pi / lerpedPoints), innerRadiusRatio, t)!,
                    pointRounding: lerpDouble(1.0, pointRounding, t)!,
                    valleyRounding: lerpDouble(0.0, valleyRounding, t)!,
                    rotation: rotation,
                    squash: lerpDouble(a.eccentricity, squash, t)!
                )
            } else {
                // Have a slightly different lerp for two-pointed stars, since they get
                // kind of squirrelly with near-zero innerRadiusRatios.
                let lerpedPoints = lerpDouble(points, 2, t)!
                return StarBorder(
                    side: BorderSide.lerp(a.side, side, t),
                    points: lerpedPoints,
                    innerRadiusRatio: lerpDouble(1, innerRadiusRatio, t)!,
                    pointRounding: lerpDouble(0.5, pointRounding, t)!,
                    valleyRounding: lerpDouble(0.5, valleyRounding, t)!,
                    rotation: rotation,
                    squash: lerpDouble(a.eccentricity, squash, t)!
                )
            }
        }

        if let a = a as? StadiumBorder {
            // Lerp from a stadium to a circle first, and from there to a star.
            let lerpedSide = BorderSide.lerp(a.side, side, t)
            return _twoPhaseLerp(
                t,
                0.5,
                { t in a.lerpTo(CircleBorder(side: lerpedSide), t) },
                { t in self.lerpFrom(CircleBorder(side: lerpedSide), t) }
            )
        }

        if let a = a as? RoundedRectangleBorder {
            // Lerp from a rectangle to a stadium, then from a Stadium to a circle,
            // then from a circle to a star.
            let lerpedSide = BorderSide.lerp(a.side, side, t)
            return _twoPhaseLerp(
                t,
                1.0 / 3.0,
                { t in
                    StadiumBorder(side: lerpedSide).lerpFrom(a, t)
                },
                { t in
                    self._twoPhaseLerp(
                        t,
                        0.5,
                        { t in StadiumBorder(side: lerpedSide).lerpTo(CircleBorder(side: lerpedSide), t) },
                        { t in self.lerpFrom(CircleBorder(side: lerpedSide), t) }
                    )
                }
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
    /// **Dart Source:** `star_border.dart:282-359`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if t == 0 {
            return self
        }
        if t == 1.0 {
            return b
        }
        if let b = b as? StarBorder {
            return StarBorder(
                side: BorderSide.lerp(side, b.side, t),
                points: lerpDouble(points, b.points, t)!,
                innerRadiusRatio: lerpDouble(innerRadiusRatio, b.innerRadiusRatio, t)!,
                pointRounding: lerpDouble(pointRounding, b.pointRounding, t)!,
                valleyRounding: lerpDouble(valleyRounding, b.valleyRounding, t)!,
                rotation: lerpDouble(_rotationRadians, b._rotationRadians, t)! * kRadToDeg,
                squash: lerpDouble(squash, b.squash, t)!
            )
        }

        if let b = b as? CircleBorder {
            // Have a slightly different lerp for two-pointed stars, since they get
            // kind of squirrelly with near-zero innerRadiusRatios.
            if points >= 2.5 {
                let lerpedPoints = lerpDouble(points, points.rounded(), t)!
                return StarBorder(
                    side: BorderSide.lerp(side, b.side, t),
                    points: lerpedPoints,
                    innerRadiusRatio: lerpDouble(innerRadiusRatio, cos(.pi / lerpedPoints), t)!,
                    pointRounding: lerpDouble(pointRounding, 1.0, t)!,
                    valleyRounding: lerpDouble(valleyRounding, 0.0, t)!,
                    rotation: rotation,
                    squash: lerpDouble(squash, b.eccentricity, t)!
                )
            } else {
                let lerpedPoints = lerpDouble(points, 2, t)!
                return StarBorder(
                    side: BorderSide.lerp(side, b.side, t),
                    points: lerpedPoints,
                    innerRadiusRatio: lerpDouble(innerRadiusRatio, 1, t)!,
                    pointRounding: lerpDouble(pointRounding, 0.5, t)!,
                    valleyRounding: lerpDouble(valleyRounding, 0.5, t)!,
                    rotation: rotation,
                    squash: lerpDouble(squash, b.eccentricity, t)!
                )
            }
        }

        if let b = b as? StadiumBorder {
            // Lerp to a circle first, then to a stadium.
            let lerpedSide = BorderSide.lerp(side, b.side, t)
            return _twoPhaseLerp(
                t,
                0.5,
                { t in self.lerpTo(CircleBorder(side: lerpedSide), t) },
                { t in b.lerpFrom(CircleBorder(side: lerpedSide), t) }
            )
        }

        if let b = b as? RoundedRectangleBorder {
            // Lerp to a circle, and then to a stadium, then to a rounded rect.
            let lerpedSide = BorderSide.lerp(side, b.side, t)
            return _twoPhaseLerp(
                t,
                2.0 / 3.0,
                { t in
                    self._twoPhaseLerp(
                        t,
                        0.5,
                        { t in self.lerpTo(CircleBorder(side: lerpedSide), t) },
                        { t in
                            StadiumBorder(side: lerpedSide).lerpFrom(CircleBorder(side: lerpedSide), t)
                        }
                    )
                },
                { t in
                    StadiumBorder(side: lerpedSide).lerpTo(b, t)
                }
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
    /// **Dart Source:** `star_border.dart:383-393`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let adjustedRect = rect.deflate(side.strokeInset)
        return StarGenerator(
            points: points,
            innerRadiusRatio: innerRadiusRatio,
            pointRounding: pointRounding,
            valleyRounding: valleyRounding,
            rotation: _rotationRadians,
            squash: squash
        ).generate(adjustedRect)
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `star_border.dart:395-405`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        return StarGenerator(
            points: points,
            innerRadiusRatio: innerRadiusRatio,
            pointRounding: pointRounding,
            valleyRounding: valleyRounding,
            rotation: _rotationRadians,
            squash: squash
        ).generate(rect)
    }

    // MARK: - Painting

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `star_border.dart:407-424`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        switch side.style {
        case .none:
            break
        case .solid:
            let adjustedRect = rect.inflate(side.strokeOffset / 2)
            let path = StarGenerator(
                points: points,
                innerRadiusRatio: innerRadiusRatio,
                pointRounding: pointRounding,
                valleyRounding: valleyRounding,
                rotation: _rotationRadians,
                squash: squash
            ).generate(adjustedRect)
            canvas.drawPath(path, side.toPaint())
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `star_border.dart:427-439`
    public static func == (lhs: StarBorder, rhs: StarBorder) -> Bool {
        lhs.side == rhs.side
            && lhs.points == rhs.points
            && lhs._innerRadiusRatio == rhs._innerRadiusRatio
            && lhs.pointRounding == rhs.pointRounding
            && lhs.valleyRounding == rhs.valleyRounding
            && lhs._rotationRadians == rhs._rotationRadians
            && lhs.squash == rhs.squash
    }

    /// **Dart Source:** `star_border.dart:442`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `star_border.dart:445-447`
    public var description: String {
        "\(objectRuntimeType(self, "StarBorder"))(\(side), points: \(points), innerRadiusRatio: \(innerRadiusRatio))"
    }
}

// MARK: - PointInfo

/// Helper struct for storing point calculation results during star generation.
///
/// **Dart Source:** `star_border.dart:450-466`
struct PointInfo {
    var valley: Offset
    var point: Offset
    var valleyArc1: Offset
    var pointArc1: Offset
    var pointArc2: Offset
    var valleyArc2: Offset
}

// MARK: - StarGenerator

/// Generates star and polygon `Path`s for use by `StarBorder`.
///
/// **Dart Source:** `star_border.dart:468-706`
struct StarGenerator {

    // MARK: - Properties

    /// **Dart Source:** `star_border.dart:487-492`
    let points: Double
    let innerRadiusRatio: Double
    let pointRounding: Double
    let valleyRounding: Double
    let rotation: Double
    let squash: Double

    // MARK: - Initializer

    /// **Dart Source:** `star_border.dart:469-485`
    init(
        points: Double,
        innerRadiusRatio: Double,
        pointRounding: Double,
        valleyRounding: Double,
        rotation: Double,
        squash: Double
    ) {
        assert(points > 1, "points must be > 1")
        assert(innerRadiusRatio <= 1, "innerRadiusRatio must be <= 1")
        assert(innerRadiusRatio >= 0, "innerRadiusRatio must be >= 0")
        assert(squash >= 0, "squash must be >= 0")
        assert(squash <= 1, "squash must be <= 1")
        assert(pointRounding >= 0, "pointRounding must be >= 0")
        assert(pointRounding <= 1, "pointRounding must be <= 1")
        assert(valleyRounding >= 0, "valleyRounding must be >= 0")
        assert(valleyRounding <= 1, "valleyRounding must be <= 1")
        assert(pointRounding + valleyRounding <= 1, "pointRounding + valleyRounding must be <= 1")
        self.points = points
        self.innerRadiusRatio = innerRadiusRatio
        self.pointRounding = pointRounding
        self.valleyRounding = valleyRounding
        self.rotation = rotation
        self.squash = squash
    }

    // MARK: - Path Generation

    /// Generates the star/polygon path for the given rect.
    ///
    /// **Dart Source:** `star_border.dart:494-539`
    func generate(_ rect: Rect) -> Path {
        let radius = rect.shortestSide / 2
        let center = rect.center

        // The minimum allowed inner radius ratio. Numerical instabilities occur near
        // zero, so we just don't allow values in that range.
        let minInnerRadiusRatio: Double = 0.002

        // Map the innerRadiusRatio so that we don't get values close to zero, since
        // things get a little squirrelly there because the path thinks that the
        // length of the conicTo is small enough that it can render it as a straight
        // line, even though it will be scaled up later. This maps the range from
        // [0, 1] to [minInnerRadiusRatio, 1].
        let mappedInnerRadiusRatio =
            (innerRadiusRatio * (1.0 - minInnerRadiusRatio)) + minInnerRadiusRatio

        // First, generate the "points" of the star.
        var pointList = [PointInfo]()
        let maxDiameter =
            2.0
            * _generatePoints(
                pointList: &pointList,
                center: center,
                radius: radius,
                innerRadius: radius * mappedInnerRadiusRatio
            )

        // Calculate the endpoints of each of the arcs, then draw the arcs.
        let path = Path()
        _drawPoints(path, pointList)

        var scale = Offset(rect.width / maxDiameter, rect.height / maxDiameter)
        if rect.shortestSide == rect.width {
            scale = Offset(scale.dx, squash * scale.dy + (1 - squash) * scale.dx)
        } else {
            scale = Offset(squash * scale.dx + (1 - squash) * scale.dy, scale.dy)
        }

        // Scale the border so that it matches the size of the widget rectangle, so
        // that "rotation" of the shape doesn't affect how much of the rectangle it
        // covers.
        var squashMatrix = Matrix4.translationValues(rect.center.dx, rect.center.dy, 0)
        squashMatrix = squashMatrix * Matrix4.diagonal3Values(scale.dx, scale.dy, 1)
        squashMatrix = squashMatrix * Matrix4.rotationZ(rotation)
        squashMatrix = squashMatrix * Matrix4.translationValues(-rect.center.dx, -rect.center.dy, 0)
        return path.transform(squashMatrix.storage)
    }

    // MARK: - Private Methods

    /// Generates the points of the star.
    ///
    /// **Dart Source:** `star_border.dart:541-645`
    private func _generatePoints(
        pointList: inout [PointInfo],
        center: Offset,
        radius: Double,
        innerRadius: Double
    ) -> Double {
        let step = .pi / points
        // Start initial rotation one step before zero.
        var angle = -.pi / 2 - step
        var valley = Offset(
            center.dx + cos(angle) * innerRadius,
            center.dy + sin(angle) * innerRadius
        )

        // In order to do overall scale properly, calculate the actual radius at the
        // point, taking into account the rounding of the points and the weight of
        // the corner point. This effectively is evaluating the rational quadratic
        // bezier at the midpoint of the curve.
        func getCurveMidpoint(_ a: Offset, _ b: Offset, _ c: Offset, _ a1: Offset, _ c1: Offset) -> Offset {
            let angle = _getAngle(a, b, c)
            let w = _getWeight(angle) / 2
            return (a1 / 4 + b * w + c1 / 4) / (0.5 + w)
        }

        func addPoint(
            _ pointAngle: Double,
            _ pointStep: Double,
            _ pointRadius: Double,
            _ pointInnerRadius: Double
        ) -> Double {
            var pointAngle = pointAngle
            pointAngle += pointStep
            let point = Offset(
                center.dx + cos(pointAngle) * pointRadius,
                center.dy + sin(pointAngle) * pointRadius
            )
            pointAngle += pointStep
            let nextValley = Offset(
                center.dx + cos(pointAngle) * pointInnerRadius,
                center.dy + sin(pointAngle) * pointInnerRadius
            )
            let valleyArc1 = valley + (point - valley) * valleyRounding
            let pointArc1 = point + (valley - point) * pointRounding
            let pointArc2 = point + (nextValley - point) * pointRounding
            let valleyArc2 = nextValley + (point - nextValley) * valleyRounding

            pointList.append(
                PointInfo(
                    valley: valley,
                    point: point,
                    valleyArc1: valleyArc1,
                    pointArc1: pointArc1,
                    pointArc2: pointArc2,
                    valleyArc2: valleyArc2
                )
            )
            valley = nextValley
            return pointAngle
        }

        let remainder = points - points.rounded(.towardZero)
        let hasIntegerSides = remainder < 1e-6
        let wholeSides = points - (hasIntegerSides ? 0 : 1)
        for _ in 0..<Int(wholeSides) {
            angle = addPoint(angle, step, radius, innerRadius)
        }

        var valleyRadius: Double = 0
        var pointRadius: Double = 0
        let thisPoint = pointList[0]
        let nextPoint = pointList[1]

        let pointMidpoint = getCurveMidpoint(
            thisPoint.valley,
            thisPoint.point,
            nextPoint.valley,
            thisPoint.pointArc1,
            thisPoint.pointArc2
        )
        let valleyMidpoint = getCurveMidpoint(
            thisPoint.point,
            nextPoint.valley,
            nextPoint.point,
            thisPoint.valleyArc2,
            nextPoint.valleyArc1
        )
        valleyRadius = (valleyMidpoint - center).distance
        pointRadius = (pointMidpoint - center).distance

        // Add the final point to close the shape if there are fractional sides to
        // account for.
        if !hasIntegerSides {
            let effectiveInnerRadius = max(valleyRadius, innerRadius)
            let endingRadius =
                effectiveInnerRadius + remainder * (radius - effectiveInnerRadius)
            angle = addPoint(angle, step * remainder, endingRadius, innerRadius)
        }

        // The rounding added to the valley radius can sometimes push it outside of
        // the rounding of the point, since the rounding amount can be different
        // between the points and the valleys, so we have to evaluate both the
        // valley and the point radii, and pick the largest. Also, since this value
        // is used later to determine the scale, we need to keep it finite and
        // non-zero.
        return clampDouble(max(valleyRadius, pointRadius), Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude)
    }

    /// Draws the points of the star as a path.
    ///
    /// **Dart Source:** `star_border.dart:647-684`
    private func _drawPoints(_ path: Path, _ points: [PointInfo]) {
        let startingPoint = points.first!.pointArc1
        path.moveTo(startingPoint.dx, startingPoint.dy)
        let pointAngle = _getAngle(points[0].valley, points[0].point, points[1].valley)
        let pointWeight = _getWeight(pointAngle)
        let valleyAngle = _getAngle(points[1].point, points[1].valley, points[0].point)
        let valleyWeight = _getWeight(valleyAngle)

        for i in 0..<points.count {
            let point = points[i]
            let nextPoint = points[(i + 1) % points.count]
            path.lineTo(point.pointArc1.dx, point.pointArc1.dy)
            if pointAngle != 180 && pointAngle != 0 {
                path.conicTo(
                    point.point.dx,
                    point.point.dy,
                    point.pointArc2.dx,
                    point.pointArc2.dy,
                    pointWeight
                )
            } else {
                path.lineTo(point.pointArc2.dx, point.pointArc2.dy)
            }
            path.lineTo(point.valleyArc2.dx, point.valleyArc2.dy)
            if valleyAngle != 180 && valleyAngle != 0 {
                path.conicTo(
                    nextPoint.valley.dx,
                    nextPoint.valley.dy,
                    nextPoint.valleyArc1.dx,
                    nextPoint.valleyArc1.dy,
                    valleyWeight
                )
            } else {
                path.lineTo(nextPoint.valleyArc1.dx, nextPoint.valleyArc1.dy)
            }
        }
        path.close()
    }

    /// Calculates the weight for a conic curve based on the angle.
    ///
    /// **Dart Source:** `star_border.dart:686-688`
    private func _getWeight(_ angle: Double) -> Double {
        return cos((angle / 2).truncatingRemainder(dividingBy: .pi / 2))
    }

    /// Returns the included angle between points ABC in radians.
    ///
    /// **Dart Source:** `star_border.dart:690-705`
    private func _getAngle(_ a: Offset, _ b: Offset, _ c: Offset) -> Double {
        if a == c || b == c || b == a {
            return 0
        }
        let u = a - b
        let v = c - b
        let dot = u.dx * v.dx + u.dy * v.dy
        let m1 = b.dx == a.dx ? Double.infinity : -u.dy / -u.dx
        let m2 = b.dx == c.dx ? Double.infinity : -v.dy / -v.dx
        var angle = atan2(m1 - m2, 1 + m1 * m2).magnitude
        if dot < 0 {
            angle += .pi
        }
        return angle
    }
}
