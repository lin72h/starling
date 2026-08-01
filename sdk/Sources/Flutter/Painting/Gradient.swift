// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// 2D gradient types for painting.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/gradient.dart`

import Foundation
import FlutterSwiftBridge

// MARK: - ColorsAndStops (Internal Helper)

/// Internal helper to bundle interpolated colors and stops together.
///
/// **Dart Source:** `gradient.dart:20-24`
struct ColorsAndStops {
    let colors: [Color]
    let stops: [Double]
}

// MARK: - Sample Function (Internal)

/// Calculate the color at position `t` of the gradient defined by `colors` and `stops`.
///
/// **Dart Source:** `gradient.dart:27-43`
func sampleGradient(_ colors: [Color], _ stops: [Double], _ t: Double) -> Color {
    assert(!colors.isEmpty)
    assert(!stops.isEmpty)
    if t <= stops.first! {
        return colors.first!
    }
    if t >= stops.last! {
        return colors.last!
    }
    let index = stops.lastIndex(where: { $0 <= t })!
    return Color.lerp(
        colors[index],
        colors[index + 1],
        (t - stops[index]) / (stops[index + 1] - stops[index])
    )!
}

// MARK: - Interpolate Colors And Stops (Internal)

/// Interpolate two gradient color/stop sets at position `t`.
///
/// **Dart Source:** `gradient.dart:45-67`
func interpolateColorsAndStops(
    _ aColors: [Color],
    _ aStops: [Double],
    _ bColors: [Color],
    _ bStops: [Double],
    _ t: Double
) -> ColorsAndStops {
    assert(aColors.count >= 2)
    assert(bColors.count >= 2)
    assert(aStops.count == aColors.count)
    assert(bStops.count == bColors.count)
    // Merge and sort stops (equivalent to Dart's SplayTreeSet)
    let allStops = Set(aStops + bStops).sorted()
    let interpolatedColors = allStops.map { stop in
        Color.lerp(
            sampleGradient(aColors, aStops, stop),
            sampleGradient(bColors, bStops, stop),
            t
        )!
    }
    return ColorsAndStops(colors: interpolatedColors, stops: allStops)
}

// MARK: - GradientTransform

/// Base protocol for transforming gradient shaders without applying the same
/// transform to the entire canvas.
///
/// **Dart Source:** `gradient.dart:75-88`
public protocol GradientTransform: Equatable {
    /// When a gradient creates its shader, it will call this method to
    /// determine what transform to apply to the shader for the given rect and
    /// text direction.
    ///
    /// Implementers may return nil from this method, which achieves the same
    /// final effect as returning `Matrix4.identity()`.
    func transform(bounds: Rect, textDirection: TextDirection?) -> Matrix4?
}

// MARK: - AnyGradientTransform

/// A type-erased wrapper for GradientTransform that provides Equatable and Hashable
/// conformance for use in gradient types.
///
/// This is needed because Swift protocols with associated type requirements (Equatable)
/// cannot be used as existential types in stored properties directly.
public struct AnyGradientTransform: Equatable, Hashable {
    private let _transform: (Rect, TextDirection?) -> Matrix4?
    private let _equals: (AnyGradientTransform) -> Bool
    private let _hashInto: (inout Hasher) -> Void
    private let _description: () -> String

    /// The boxed value (for type checking).
    internal let base: Any

    /// Creates a type-erased gradient transform wrapping the given value.
    public init<T: GradientTransform & Hashable>(_ wrapped: T) {
        self.base = wrapped
        self._transform = { bounds, textDirection in
            wrapped.transform(bounds: bounds, textDirection: textDirection)
        }
        self._equals = { other in
            guard let otherBase = other.base as? T else { return false }
            return wrapped == otherBase
        }
        self._hashInto = { hasher in
            wrapped.hash(into: &hasher)
        }
        self._description = {
            String(describing: wrapped)
        }
    }

    /// Applies the transform.
    public func transform(bounds: Rect, textDirection: TextDirection?) -> Matrix4? {
        _transform(bounds, textDirection)
    }

    public static func == (lhs: AnyGradientTransform, rhs: AnyGradientTransform) -> Bool {
        lhs._equals(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        _hashInto(&hasher)
    }
}

extension AnyGradientTransform: CustomStringConvertible {
    public var description: String {
        _description()
    }
}

// MARK: - GradientRotation

/// A `GradientTransform` that rotates the gradient around the center-point of
/// its bounding box.
///
/// **Dart Source:** `gradient.dart:104-145`
public struct GradientRotation: GradientTransform, Hashable, CustomStringConvertible {
    /// The angle of rotation in radians in the clockwise direction.
    ///
    /// **Dart Source:** `gradient.dart:112`
    public let radians: Double

    /// Constructs a `GradientRotation` for the specified angle.
    ///
    /// The angle is in radians in the clockwise direction.
    ///
    /// **Dart Source:** `gradient.dart:109`
    public init(_ radians: Double) {
        self.radians = radians
    }

    /// **Dart Source:** `gradient.dart:114-125`
    public func transform(bounds: Rect, textDirection: TextDirection?) -> Matrix4? {
        let sinRadians = sin(radians)
        let oneMinusCosRadians = 1 - cos(radians)
        let center = bounds.center
        let originX = sinRadians * center.dy + oneMinusCosRadians * center.dx
        let originY = -sinRadians * center.dx + oneMinusCosRadians * center.dy

        return Matrix4.translationValues(originX, originY, 0.0) * Matrix4.rotationZ(radians)
    }

    /// **Dart Source:** `gradient.dart:127-136`
    public static func == (lhs: GradientRotation, rhs: GradientRotation) -> Bool {
        lhs.radians == rhs.radians
    }

    /// **Dart Source:** `gradient.dart:138-139`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(radians)
    }

    /// **Dart Source:** `gradient.dart:141-144`
    public var description: String {
        "\(objectRuntimeType(self, "GradientRotation"))(radians: \(debugFormatDouble(radians)))"
    }
}

// MARK: - GradientBase

/// A 2D gradient.
///
/// This is the base class that allows `LinearGradient`, `RadialGradient`, and
/// `SweepGradient` to be used interchangeably.
///
/// **Dart Source:** `gradient.dart:156-333`
public class GradientBase: Equatable, Hashable, CustomStringConvertible {
    /// The colors the gradient should obtain at each of the stops.
    ///
    /// **Dart Source:** `gradient.dart:181`
    public let colors: [Color]

    /// A list of values from 0.0 to 1.0 that denote fractions along the gradient.
    ///
    /// **Dart Source:** `gradient.dart:199`
    public let stops: [Double]?

    /// The transform, if any, to apply to the gradient.
    ///
    /// **Dart Source:** `gradient.dart:205`
    public let transform: AnyGradientTransform?

    /// Initialize the gradient's colors, stops, and transform.
    ///
    /// **Dart Source:** `gradient.dart:173`
    public init(colors: [Color], stops: [Double]? = nil, transform: AnyGradientTransform? = nil) {
        self.colors = colors
        self.stops = stops
        self.transform = transform
    }

    /// Returns the implied stops for this gradient.
    ///
    /// **Dart Source:** `gradient.dart:207-214`
    public func impliedStops() -> [Double] {
        if let stops = stops {
            return stops
        }
        assert(colors.count >= 2, "colors list must have at least two colors")
        let separation = 1.0 / Double(colors.count - 1)
        return (0..<colors.count).map { Double($0) * separation }
    }

    /// Creates a `Shader` for this gradient to fill the given rect.
    ///
    /// **Dart Source:** `gradient.dart:224-225`
    public func createShader(rect: Rect, textDirection: TextDirection? = nil) -> Shader {
        fatalError("Subclasses must override createShader")
    }

    /// Returns a new gradient with its properties scaled by the given factor.
    ///
    /// **Dart Source:** `gradient.dart:236`
    public func scale(_ factor: Double) -> GradientBase {
        fatalError("Subclasses must override scale")
    }

    /// Returns a new gradient with each color set to the given opacity.
    ///
    /// **Dart Source:** `gradient.dart:239`
    public func withOpacity(_ opacity: Double) -> GradientBase {
        fatalError("Subclasses must override withOpacity")
    }

    /// Linearly interpolates from another gradient to `this`.
    ///
    /// **Dart Source:** `gradient.dart:264-270`
    public func lerpFrom(_ a: GradientBase?, _ t: Double) -> GradientBase? {
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another gradient.
    ///
    /// **Dart Source:** `gradient.dart:296-302`
    public func lerpTo(_ b: GradientBase?, _ t: Double) -> GradientBase? {
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    /// Linearly interpolates between two gradients.
    ///
    /// **Dart Source:** `gradient.dart:312-328`
    public static func lerp(_ a: GradientBase?, _ b: GradientBase?, _ t: Double) -> GradientBase? {
        if a === b {
            return a
        }
        var result: GradientBase?
        if let b = b {
            result = b.lerpFrom(a, t) // if a is nil, this must return non-nil
        }
        if result == nil, let a = a {
            result = a.lerpTo(b, t) // if b is nil, this must return non-nil
        }
        if let result = result {
            return result
        }
        assert(a != nil && b != nil)
        return t < 0.5 ? a!.scale(1.0 - (t * 2.0)) : b!.scale((t - 0.5) * 2.0)
    }

    /// Resolves the transform to a matrix storage array.
    ///
    /// **Dart Source:** `gradient.dart:330-332`
    func resolveTransform(bounds: Rect, textDirection: TextDirection?) -> [Double]? {
        return transform?.transform(bounds: bounds, textDirection: textDirection)?.storage
    }

    // MARK: - Equatable

    /// Checks equality by delegating to the virtual `isEqual(to:)` method.
    public static func == (lhs: GradientBase, rhs: GradientBase) -> Bool {
        lhs.isEqual(to: rhs)
    }

    /// Virtual equality method for subclass dispatch.
    /// Subclasses must override this.
    open func isEqual(to other: GradientBase) -> Bool {
        // Base class: only equal if same instance
        return self === other
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        // Base class: hash by identity
        hasher.combine(ObjectIdentifier(self))
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "\(objectRuntimeType(self, "GradientBase"))"
    }
}

// MARK: - LinearGradient

/// A 2D linear gradient.
///
/// This class is used by `BoxDecoration` to represent linear gradients. This
/// abstracts out the arguments to the `Gradient.linear` constructor from
/// the dart:ui library.
///
/// **Dart Source:** `gradient.dart:377-572`
public final class LinearGradient: GradientBase {
    /// The offset at which stop 0.0 of the gradient is placed.
    ///
    /// **Dart Source:** `gradient.dart:403`
    public let begin: any AlignmentGeometry

    /// The offset at which stop 1.0 of the gradient is placed.
    ///
    /// **Dart Source:** `gradient.dart:418`
    public let end: any AlignmentGeometry

    /// How this gradient should tile the plane beyond in the region before
    /// `begin` and after `end`.
    ///
    /// **Dart Source:** `gradient.dart:429`
    public let tileMode: TileMode

    /// Creates a linear gradient.
    ///
    /// **Dart Source:** `gradient.dart:381-388`
    public init(
        begin: any AlignmentGeometry = Alignment.centerLeft as any AlignmentGeometry,
        end: any AlignmentGeometry = Alignment.centerRight as any AlignmentGeometry,
        colors: [Color],
        stops: [Double]? = nil,
        tileMode: TileMode = .clamp,
        transform: AnyGradientTransform? = nil
    ) {
        self.begin = begin
        self.end = end
        self.tileMode = tileMode
        super.init(colors: colors, stops: stops, transform: transform)
    }

    /// **Dart Source:** `gradient.dart:431-441`
    public override func createShader(rect: Rect, textDirection: TextDirection? = nil) -> Shader {
        return FlutterSwiftBridge.Gradient(
            linear: begin.resolve(textDirection).withinRect(rect),
            to: end.resolve(textDirection).withinRect(rect),
            colors: colors,
            colorStops: impliedStops(),
            tileMode: tileMode,
            matrix4: resolveTransform(bounds: rect, textDirection: textDirection)
        )
    }

    /// Returns a new `LinearGradient` with its colors scaled by the given factor.
    ///
    /// **Dart Source:** `gradient.dart:447-456`
    public override func scale(_ factor: Double) -> LinearGradient {
        return LinearGradient(
            begin: begin,
            end: end,
            colors: colors.map { Color.lerp(nil, $0, factor)! },
            stops: stops,
            tileMode: tileMode
        )
    }

    /// **Dart Source:** `gradient.dart:458-464`
    public override func lerpFrom(_ a: GradientBase?, _ t: Double) -> GradientBase? {
        if a == nil || a is LinearGradient {
            return LinearGradient.lerp(a as? LinearGradient, self, t)
        }
        return super.lerpFrom(a, t)
    }

    /// **Dart Source:** `gradient.dart:466-472`
    public override func lerpTo(_ b: GradientBase?, _ t: Double) -> GradientBase? {
        if b == nil || b is LinearGradient {
            return LinearGradient.lerp(self, b as? LinearGradient, t)
        }
        return super.lerpTo(b, t)
    }

    /// Linearly interpolate between two `LinearGradient`s.
    ///
    /// **Dart Source:** `gradient.dart:493-518`
    public static func lerp(_ a: LinearGradient?, _ b: LinearGradient?, _ t: Double) -> LinearGradient? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        let interpolated = interpolateColorsAndStops(
            a!.colors,
            a!.impliedStops(),
            b!.colors,
            b!.impliedStops(),
            t
        )
        return LinearGradient(
            begin: AlignmentGeometryStatics.lerp(a!.begin, b!.begin, t)!,
            end: AlignmentGeometryStatics.lerp(a!.end, b!.end, t)!,
            colors: interpolated.colors,
            stops: interpolated.stops,
            tileMode: t < 0.5 ? a!.tileMode : b!.tileMode,
            transform: t < 0.5 ? a!.transform : b!.transform
        )
    }

    /// **Dart Source:** `gradient.dart:520-535`
    public override func withOpacity(_ opacity: Double) -> LinearGradient {
        return LinearGradient(
            begin: begin,
            end: end,
            colors: colors.map { $0.withOpacity(opacity) },
            stops: stops,
            tileMode: tileMode,
            transform: transform
        )
    }

    // MARK: - Equatable

    /// **Dart Source:** `gradient.dart:520-535`
    public override func isEqual(to other: GradientBase) -> Bool {
        guard let rhs = other as? LinearGradient else { return false }
        if self === rhs { return true }
        return begin == rhs.begin &&
            end == rhs.end &&
            tileMode == rhs.tileMode &&
            transform == rhs.transform &&
            colors == rhs.colors &&
            stops == rhs.stops
    }

    // MARK: - Hashable

    /// **Dart Source:** `gradient.dart:537-545`
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(begin)
        hasher.combine(end)
        hasher.combine(tileMode)
        hasher.combine(transform)
        for color in colors {
            hasher.combine(color)
        }
        if let stops = stops {
            for stop in stops {
                hasher.combine(stop)
            }
        }
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `gradient.dart:547-559`
    public override var description: String {
        var parts: [String] = [
            "begin: \(begin)",
            "end: \(end)",
            "colors: \(colors)",
        ]
        if let stops = stops {
            parts.append("stops: \(stops)")
        }
        parts.append("tileMode: \(tileMode)")
        if let transform = transform {
            parts.append("transform: \(transform)")
        }
        return "\(objectRuntimeType(self, "LinearGradient"))(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - RadialGradient

/// A 2D radial gradient.
///
/// This class is used by `BoxDecoration` to represent radial gradients. This
/// abstracts out the arguments to the `Gradient.radial` constructor from
/// the dart:ui library.
///
/// **Dart Source:** `gradient.dart:643-875`
public final class RadialGradient: GradientBase {
    /// The center of the gradient.
    ///
    /// **Dart Source:** `gradient.dart:672`
    public let center: any AlignmentGeometry

    /// The radius of the gradient, as a fraction of the shortest side
    /// of the paint box.
    ///
    /// **Dart Source:** `gradient.dart:681`
    public let radius: Double

    /// How this gradient should tile the plane beyond the outer ring at `radius`
    /// pixels from the `center`.
    ///
    /// **Dart Source:** `gradient.dart:696`
    public let tileMode: TileMode

    /// The focal point of the gradient.
    ///
    /// **Dart Source:** `gradient.dart:706`
    public let focal: (any AlignmentGeometry)?

    /// The radius of the focal point of gradient, as a fraction of the shortest
    /// side of the paint box.
    ///
    /// **Dart Source:** `gradient.dart:718`
    public let focalRadius: Double

    /// Creates a radial gradient.
    ///
    /// **Dart Source:** `gradient.dart:647-656`
    public init(
        center: any AlignmentGeometry = Alignment.center as any AlignmentGeometry,
        radius: Double = 0.5,
        colors: [Color],
        stops: [Double]? = nil,
        tileMode: TileMode = .clamp,
        focal: (any AlignmentGeometry)? = nil,
        focalRadius: Double = 0.0,
        transform: AnyGradientTransform? = nil
    ) {
        self.center = center
        self.radius = radius
        self.tileMode = tileMode
        self.focal = focal
        self.focalRadius = focalRadius
        super.init(colors: colors, stops: stops, transform: transform)
    }

    /// **Dart Source:** `gradient.dart:720-732`
    public override func createShader(rect: Rect, textDirection: TextDirection? = nil) -> Shader {
        return FlutterSwiftBridge.Gradient(
            radial: center.resolve(textDirection).withinRect(rect),
            radius: radius * rect.shortestSide,
            colors: colors,
            colorStops: impliedStops(),
            tileMode: tileMode,
            matrix4: resolveTransform(bounds: rect, textDirection: textDirection),
            focal: focal?.resolve(textDirection).withinRect(rect),
            focalRadius: focalRadius * rect.shortestSide
        )
    }

    /// Returns a new `RadialGradient` with its colors scaled by the given factor.
    ///
    /// **Dart Source:** `gradient.dart:738-749`
    public override func scale(_ factor: Double) -> RadialGradient {
        return RadialGradient(
            center: center,
            radius: radius,
            colors: colors.map { Color.lerp(nil, $0, factor)! },
            stops: stops,
            tileMode: tileMode,
            focal: focal,
            focalRadius: focalRadius
        )
    }

    /// **Dart Source:** `gradient.dart:751-757`
    public override func lerpFrom(_ a: GradientBase?, _ t: Double) -> GradientBase? {
        if a == nil || a is RadialGradient {
            return RadialGradient.lerp(a as? RadialGradient, self, t)
        }
        return super.lerpFrom(a, t)
    }

    /// **Dart Source:** `gradient.dart:759-765`
    public override func lerpTo(_ b: GradientBase?, _ t: Double) -> GradientBase? {
        if b == nil || b is RadialGradient {
            return RadialGradient.lerp(self, b as? RadialGradient, t)
        }
        return super.lerpTo(b, t)
    }

    /// Linearly interpolate between two `RadialGradient`s.
    ///
    /// **Dart Source:** `gradient.dart:786-813`
    public static func lerp(_ a: RadialGradient?, _ b: RadialGradient?, _ t: Double) -> RadialGradient? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        let interpolated = interpolateColorsAndStops(
            a!.colors,
            a!.impliedStops(),
            b!.colors,
            b!.impliedStops(),
            t
        )
        return RadialGradient(
            center: AlignmentGeometryStatics.lerp(a!.center, b!.center, t)!,
            radius: max(0.0, lerpDouble(a!.radius, b!.radius, t)!),
            colors: interpolated.colors,
            stops: interpolated.stops,
            tileMode: t < 0.5 ? a!.tileMode : b!.tileMode,
            focal: AlignmentGeometryStatics.lerp(a!.focal, b!.focal, t),
            focalRadius: max(0.0, lerpDouble(a!.focalRadius, b!.focalRadius, t)!),
            transform: t < 0.5 ? a!.transform : b!.transform
        )
    }

    /// **Dart Source:** `gradient.dart:862-874`
    public override func withOpacity(_ opacity: Double) -> RadialGradient {
        return RadialGradient(
            center: center,
            radius: radius,
            colors: colors.map { $0.withOpacity(opacity) },
            stops: stops,
            tileMode: tileMode,
            focal: focal,
            focalRadius: focalRadius,
            transform: transform
        )
    }

    // MARK: - Equatable

    /// **Dart Source:** `gradient.dart:815-832`
    public override func isEqual(to other: GradientBase) -> Bool {
        guard let rhs = other as? RadialGradient else { return false }
        if self === rhs { return true }
        return center == rhs.center &&
            radius == rhs.radius &&
            tileMode == rhs.tileMode &&
            transform == rhs.transform &&
            colors == rhs.colors &&
            stops == rhs.stops &&
            focalEquals(rhs) &&
            focalRadius == rhs.focalRadius
    }

    /// Helper to compare optional focal alignments.
    private func focalEquals(_ other: RadialGradient) -> Bool {
        if focal == nil && other.focal == nil { return true }
        guard let f1 = focal, let f2 = other.focal else { return false }
        return f1 == f2
    }

    // MARK: - Hashable

    /// **Dart Source:** `gradient.dart:834-844`
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(radius)
        hasher.combine(tileMode)
        hasher.combine(transform)
        for color in colors {
            hasher.combine(color)
        }
        if let stops = stops {
            for stop in stops {
                hasher.combine(stop)
            }
        }
        if let focal = focal {
            hasher.combine(focal)
        }
        hasher.combine(focalRadius)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `gradient.dart:846-860`
    public override var description: String {
        var parts: [String] = [
            "center: \(center)",
            "radius: \(debugFormatDouble(radius))",
            "colors: \(colors)",
        ]
        if let stops = stops {
            parts.append("stops: \(stops)")
        }
        parts.append("tileMode: \(tileMode)")
        if let focal = focal {
            parts.append("focal: \(focal)")
        }
        parts.append("focalRadius: \(debugFormatDouble(focalRadius))")
        if let transform = transform {
            parts.append("transform: \(transform)")
        }
        return "\(objectRuntimeType(self, "RadialGradient"))(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - SweepGradient

/// A 2D sweep gradient.
///
/// This class is used by `BoxDecoration` to represent sweep gradients. This
/// abstracts out the arguments to the `Gradient.sweep` constructor from
/// the dart:ui library.
///
/// **Dart Source:** `gradient.dart:955-1176`
public final class SweepGradient: GradientBase {
    /// The center of the gradient.
    ///
    /// **Dart Source:** `gradient.dart:983`
    public let center: any AlignmentGeometry

    /// The angle in radians at which stop 0.0 of the gradient is placed.
    ///
    /// **Dart Source:** `gradient.dart:996`
    public let startAngle: Double

    /// The angle in radians at which stop 1.0 of the gradient is placed.
    ///
    /// **Dart Source:** `gradient.dart:1009`
    public let endAngle: Double

    /// How this gradient should tile the plane in the region before
    /// `startAngle` and after `endAngle`.
    ///
    /// **Dart Source:** `gradient.dart:1027`
    public let tileMode: TileMode

    /// Creates a sweep gradient.
    ///
    /// **Dart Source:** `gradient.dart:959-967`
    public init(
        center: any AlignmentGeometry = Alignment.center as any AlignmentGeometry,
        startAngle: Double = 0.0,
        endAngle: Double = Double.pi * 2,
        colors: [Color],
        stops: [Double]? = nil,
        tileMode: TileMode = .clamp,
        transform: AnyGradientTransform? = nil
    ) {
        self.center = center
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.tileMode = tileMode
        super.init(colors: colors, stops: stops, transform: transform)
    }

    /// **Dart Source:** `gradient.dart:1029-1040`
    public override func createShader(rect: Rect, textDirection: TextDirection? = nil) -> Shader {
        return FlutterSwiftBridge.Gradient(
            sweep: center.resolve(textDirection).withinRect(rect),
            colors: colors,
            colorStops: impliedStops(),
            tileMode: tileMode,
            startAngle: startAngle,
            endAngle: endAngle,
            matrix4: resolveTransform(bounds: rect, textDirection: textDirection)
        )
    }

    /// Returns a new `SweepGradient` with its colors scaled by the given factor.
    ///
    /// **Dart Source:** `gradient.dart:1046-1056`
    public override func scale(_ factor: Double) -> SweepGradient {
        return SweepGradient(
            center: center,
            startAngle: startAngle,
            endAngle: endAngle,
            colors: colors.map { Color.lerp(nil, $0, factor)! },
            stops: stops,
            tileMode: tileMode
        )
    }

    /// **Dart Source:** `gradient.dart:1058-1064`
    public override func lerpFrom(_ a: GradientBase?, _ t: Double) -> GradientBase? {
        if a == nil || a is SweepGradient {
            return SweepGradient.lerp(a as? SweepGradient, self, t)
        }
        return super.lerpFrom(a, t)
    }

    /// **Dart Source:** `gradient.dart:1066-1072`
    public override func lerpTo(_ b: GradientBase?, _ t: Double) -> GradientBase? {
        if b == nil || b is SweepGradient {
            return SweepGradient.lerp(self, b as? SweepGradient, t)
        }
        return super.lerpTo(b, t)
    }

    /// Linearly interpolate between two `SweepGradient`s.
    ///
    /// **Dart Source:** `gradient.dart:1092-1118`
    public static func lerp(_ a: SweepGradient?, _ b: SweepGradient?, _ t: Double) -> SweepGradient? {
        if a === b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        let interpolated = interpolateColorsAndStops(
            a!.colors,
            a!.impliedStops(),
            b!.colors,
            b!.impliedStops(),
            t
        )
        return SweepGradient(
            center: AlignmentGeometryStatics.lerp(a!.center, b!.center, t)!,
            startAngle: max(0.0, lerpDouble(a!.startAngle, b!.startAngle, t)!),
            endAngle: max(0.0, lerpDouble(a!.endAngle, b!.endAngle, t)!),
            colors: interpolated.colors,
            stops: interpolated.stops,
            tileMode: t < 0.5 ? a!.tileMode : b!.tileMode,
            transform: t < 0.5 ? a!.transform : b!.transform
        )
    }

    /// **Dart Source:** `gradient.dart:1164-1175`
    public override func withOpacity(_ opacity: Double) -> SweepGradient {
        return SweepGradient(
            center: center,
            startAngle: startAngle,
            endAngle: endAngle,
            colors: colors.map { $0.withOpacity(opacity) },
            stops: stops,
            tileMode: tileMode,
            transform: transform
        )
    }

    // MARK: - Equatable

    /// **Dart Source:** `gradient.dart:1120-1136`
    public override func isEqual(to other: GradientBase) -> Bool {
        guard let rhs = other as? SweepGradient else { return false }
        if self === rhs { return true }
        return center == rhs.center &&
            startAngle == rhs.startAngle &&
            endAngle == rhs.endAngle &&
            tileMode == rhs.tileMode &&
            transform == rhs.transform &&
            colors == rhs.colors &&
            stops == rhs.stops
    }

    // MARK: - Hashable

    /// **Dart Source:** `gradient.dart:1138-1147`
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(startAngle)
        hasher.combine(endAngle)
        hasher.combine(tileMode)
        hasher.combine(transform)
        for color in colors {
            hasher.combine(color)
        }
        if let stops = stops {
            for stop in stops {
                hasher.combine(stop)
            }
        }
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `gradient.dart:1149-1162`
    public override var description: String {
        var parts: [String] = [
            "center: \(center)",
            "startAngle: \(debugFormatDouble(startAngle))",
            "endAngle: \(debugFormatDouble(endAngle))",
            "colors: \(colors)",
        ]
        if let stops = stops {
            parts.append("stops: \(stops)")
        }
        parts.append("tileMode: \(tileMode)")
        if let transform = transform {
            parts.append("transform: \(transform)")
        }
        return "\(objectRuntimeType(self, "SweepGradient"))(\(parts.joined(separator: ", ")))"
    }
}
