// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A shadow cast by a box.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_shadow.dart`

import FlutterSwiftBridge

// MARK: - BoxShadow

/// A shadow cast by a box.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_shadow.dart`
/// **Original Name:** `BoxShadow`
/// **Lines:** 32-180
///
/// `BoxShadow` can cast non-rectangular shadows if the box is non-rectangular
/// (e.g., has a border radius or a circular shape).
///
/// This class is similar to CSS box-shadow.
///
/// See also:
///
///  - `Canvas.drawShadow`, which is a more efficient way to draw shadows.
///  - `PhysicalModel`, a widget for showing shadows.
///  - `kElevationToShadow`, for some predefined shadows used in Material Design.
///  - `Shadow`, which is the parent class that lacks `spreadRadius`.
public struct BoxShadow: Hashable, Equatable, CustomStringConvertible {

    // MARK: - Properties

    /// The color of the shadow.
    ///
    /// **Dart Source:** `box_shadow.dart` (inherited from `ui.Shadow`)
    ///
    /// The shadows are shapes composited directly over the base canvas, and do not
    /// represent optical occlusion.
    public let color: Color

    /// The displacement of the shadow from the casting element.
    ///
    /// **Dart Source:** `box_shadow.dart` (inherited from `ui.Shadow`)
    ///
    /// Positive x/y offsets will shift the shadow to the right and down, while
    /// negative offsets shift the shadow to the left and up. The offsets are
    /// relative to the position of the element that is casting it.
    public let offset: Offset

    /// The standard deviation of the Gaussian to convolve with the shadow's shape.
    ///
    /// **Dart Source:** `box_shadow.dart` (inherited from `ui.Shadow`)
    public let blurRadius: Double

    /// The amount the box should be inflated prior to applying the blur.
    ///
    /// **Dart Source:** `box_shadow.dart:46`
    public let spreadRadius: Double

    /// The `BlurStyle` to use for this shadow.
    ///
    /// **Dart Source:** `box_shadow.dart:48-54`
    ///
    /// Defaults to `BlurStyle.normal`.
    ///
    /// When `debugDisableShadows` is true, `toPaint` ignores the `blurStyle` and
    /// acts as if `BlurStyle.normal` was used.
    public let blurStyle: BlurStyle

    // MARK: - Initializer

    /// Creates a box shadow.
    ///
    /// **Dart Source:** `box_shadow.dart:37-43`
    ///
    /// By default, the shadow is solid black with zero `offset`, zero `blurRadius`,
    /// zero `spreadRadius`, and `BlurStyle.normal`.
    public init(
        color: Color = Color(0xFF000000),
        offset: Offset = .zero,
        blurRadius: Double = 0.0,
        spreadRadius: Double = 0.0,
        blurStyle: BlurStyle = .normal
    ) {
        self.color = color
        self.offset = offset
        self.blurRadius = blurRadius
        self.spreadRadius = spreadRadius
        self.blurStyle = blurStyle
    }

    // MARK: - Computed Properties

    /// The `blurRadius` in sigmas instead of logical pixels.
    ///
    /// **Dart Source:** (inherited from `ui.Shadow`)
    ///
    /// See the sigma argument to `MaskFilter.blur`.
    public var blurSigma: Double {
        Shadow.convertRadiusToSigma(blurRadius)
    }

    // MARK: - Shadow Compatibility

    /// Convert to a `Shadow` (loses `spreadRadius` and `blurStyle` information).
    ///
    /// Since Dart's `BoxShadow extends Shadow`, this provides compatibility
    /// for APIs that expect a `Shadow`.
    public var asShadow: Shadow {
        Shadow(color: color, offset: offset, blurRadius: blurRadius)
    }

    // MARK: - Methods

    /// Create the `Paint` object that corresponds to this shadow description.
    ///
    /// **Dart Source:** `box_shadow.dart:69-80`
    ///
    /// The `offset` and `spreadRadius` are not represented in the `Paint` object.
    /// To honor those as well, the shape should be inflated by `spreadRadius` pixels
    /// in every direction and then translated by `offset` before being filled using
    /// this `Paint`.
    ///
    /// The `blurStyle` is ignored if `debugDisableShadows` is true. This causes
    /// an especially significant change to the rendering when `BlurStyle.outer`
    /// is used; the caller is responsible for adjusting for that case if
    /// necessary. (This only matters when using `debugDisableShadows`, e.g. in
    /// tests that use golden file testing.)
    public func toPaint() -> Paint {
        let result = Paint()
        result.color = color
        result.maskFilter = MaskFilter(blur: blurStyle, blurSigma)
        #if DEBUG
        if debugDisableShadows {
            result.maskFilter = nil
        }
        #endif
        return result
    }

    /// Returns a new box shadow with its offset, blurRadius, and spreadRadius
    /// scaled by the given factor.
    ///
    /// **Dart Source:** `box_shadow.dart:85-93`
    public func scale(_ factor: Double) -> BoxShadow {
        BoxShadow(
            color: color,
            offset: offset * factor,
            blurRadius: blurRadius * factor,
            spreadRadius: spreadRadius * factor,
            blurStyle: blurStyle
        )
    }

    /// Creates a copy of this object but with the given fields replaced with the
    /// new values.
    ///
    /// **Dart Source:** `box_shadow.dart:97-111`
    public func copyWith(
        color: Color? = nil,
        offset: Offset? = nil,
        blurRadius: Double? = nil,
        spreadRadius: Double? = nil,
        blurStyle: BlurStyle? = nil
    ) -> BoxShadow {
        BoxShadow(
            color: color ?? self.color,
            offset: offset ?? self.offset,
            blurRadius: blurRadius ?? self.blurRadius,
            spreadRadius: spreadRadius ?? self.spreadRadius,
            blurStyle: blurStyle ?? self.blurStyle
        )
    }

    // MARK: - Static Methods

    /// Linearly interpolate between two box shadows.
    ///
    /// **Dart Source:** `box_shadow.dart:120-137`
    ///
    /// If either box shadow is nil, this function linearly interpolates from
    /// a box shadow that matches the other box shadow in color but has a zero
    /// offset and a zero blurRadius and spreadRadius.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves).
    ///
    /// Values for `t` are usually obtained from an `Animation<Double>`, such as
    /// an `AnimationController`.
    public static func lerp(_ a: BoxShadow?, _ b: BoxShadow?, _ t: Double) -> BoxShadow? {
        if a == b {
            return a
        }
        if a == nil {
            return b!.scale(t)
        }
        if b == nil {
            return a!.scale(1.0 - t)
        }
        return BoxShadow(
            color: Color.lerp(a!.color, b!.color, t)!,
            offset: Offset.lerp(a!.offset, b!.offset, t)!,
            blurRadius: lerpDouble(a!.blurRadius, b!.blurRadius, t)!,
            spreadRadius: lerpDouble(a!.spreadRadius, b!.spreadRadius, t)!,
            blurStyle: a!.blurStyle == .normal ? b!.blurStyle : a!.blurStyle
        )
    }

    /// Linearly interpolate between two lists of box shadows.
    ///
    /// **Dart Source:** `box_shadow.dart:144-156`
    ///
    /// If the lists differ in length, excess items are lerped with nil.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a` (or something
    /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
    /// returning `b` (or something equivalent to `b`), and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0 and
    /// 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves).
    ///
    /// Values for `t` are usually obtained from an `Animation<Double>`, such as
    /// an `AnimationController`.
    public static func lerpList(_ a: [BoxShadow]?, _ b: [BoxShadow]?, _ t: Double) -> [BoxShadow]? {
        if a == nil && b == nil {
            return nil
        }
        let aList = a ?? []
        let bList = b ?? []
        let commonLength = min(aList.count, bList.count)
        var result: [BoxShadow] = []
        for i in 0..<commonLength {
            result.append(BoxShadow.lerp(aList[i], bList[i], t)!)
        }
        for i in commonLength..<aList.count {
            result.append(aList[i].scale(1.0 - t))
        }
        for i in commonLength..<bList.count {
            result.append(bList[i].scale(t))
        }
        return result
    }

    // MARK: - Equatable

    /// Compares two box shadows for equality.
    ///
    /// **Dart Source:** `box_shadow.dart:158-172`
    public static func == (lhs: BoxShadow, rhs: BoxShadow) -> Bool {
        return lhs.color == rhs.color &&
               lhs.offset == rhs.offset &&
               lhs.blurRadius == rhs.blurRadius &&
               lhs.spreadRadius == rhs.spreadRadius &&
               lhs.blurStyle == rhs.blurStyle
    }

    // MARK: - Hashable

    /// The hash code for this box shadow.
    ///
    /// **Dart Source:** `box_shadow.dart:174-175`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(color)
        hasher.combine(offset)
        hasher.combine(blurRadius)
        hasher.combine(spreadRadius)
        hasher.combine(blurStyle)
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this box shadow.
    ///
    /// **Dart Source:** `box_shadow.dart:177-179`
    public var description: String {
        "BoxShadow(\(color), \(offset), \(debugFormatDouble(blurRadius)), \(debugFormatDouble(spreadRadius)), \(blurStyle))"
    }
}
