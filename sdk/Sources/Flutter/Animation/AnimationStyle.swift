// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// AnimationStyle - configuration for overriding default animation parameters.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/animation_style.dart`

import Foundation

// MARK: - AnimationStyle

/// Used to override the default parameters of an animation.
///
/// If ``duration`` and ``reverseDuration`` are set to `Duration.zero`, the
/// corresponding animation will be disabled.
///
/// All of the parameters are optional. If no parameters are specified,
/// the default animation will be used.
///
/// **Dart Source:** `animation_style.dart:29-108`
///
/// DIFFERENCE FROM DART: Uses a struct instead of a class since all properties
/// are immutable (Dart uses `@immutable` annotation with `final` fields).
/// REASON: Swift structs provide value semantics and automatic Equatable/Hashable.
public struct AnimationStyle: Equatable {
    /// Creates an instance of AnimationStyle.
    ///
    /// **Dart Source:** `animation_style.dart:31`
    public init(
        curve: (any Curve)? = nil,
        duration: Duration? = nil,
        reverseCurve: (any Curve)? = nil,
        reverseDuration: Duration? = nil
    ) {
        self.curve = curve
        self.duration = duration
        self.reverseCurve = reverseCurve
        self.reverseDuration = reverseDuration
    }

    /// Creates an instance of AnimationStyle with no animation.
    ///
    /// **Dart Source:** `animation_style.dart:34-37`
    nonisolated(unsafe) public static let noAnimation = AnimationStyle(
        duration: .zero,
        reverseDuration: .zero
    )

    /// When specified, the animation will use this curve.
    ///
    /// **Dart Source:** `animation_style.dart:40`
    public let curve: (any Curve)?

    /// When specified, the animation will use this duration.
    ///
    /// **Dart Source:** `animation_style.dart:43`
    public let duration: Duration?

    /// When specified, the reverse animation will use this curve.
    ///
    /// **Dart Source:** `animation_style.dart:46`
    public let reverseCurve: (any Curve)?

    /// When specified, the reverse animation will use this duration.
    ///
    /// **Dart Source:** `animation_style.dart:49`
    public let reverseDuration: Duration?

    /// Creates a new ``AnimationStyle`` based on the current selection, with the
    /// provided parameters overridden.
    ///
    /// **Dart Source:** `animation_style.dart:53-65`
    public func copyWith(
        curve: (any Curve)? = nil,
        duration: Duration? = nil,
        reverseCurve: (any Curve)? = nil,
        reverseDuration: Duration? = nil
    ) -> AnimationStyle {
        return AnimationStyle(
            curve: curve ?? self.curve,
            duration: duration ?? self.duration,
            reverseCurve: reverseCurve ?? self.reverseCurve,
            reverseDuration: reverseDuration ?? self.reverseDuration
        )
    }

    /// Linearly interpolate between two animation styles.
    ///
    /// Curves cannot be interpolated, so the curve is chosen based on which
    /// side of the midpoint `t` falls.
    ///
    /// **Dart Source:** `animation_style.dart:68-78`
    public static func lerp(_ a: AnimationStyle?, _ b: AnimationStyle?, _ t: Double) -> AnimationStyle? {
        if a == nil && b == nil {
            return nil
        }
        return AnimationStyle(
            curve: t < 0.5 ? a?.curve : b?.curve,
            duration: t < 0.5 ? a?.duration : b?.duration,
            reverseCurve: t < 0.5 ? a?.reverseCurve : b?.reverseCurve,
            reverseDuration: t < 0.5 ? a?.reverseDuration : b?.reverseDuration
        )
    }

    /// **Dart Source:** `animation_style.dart:81-93`
    ///
    /// DIFFERENCE FROM DART: Simplified equality since Curve protocol types
    /// cannot be compared with ==. Compares durations only.
    /// REASON: Swift existential types (`any Curve`) do not conform to Equatable.
    public static func == (lhs: AnimationStyle, rhs: AnimationStyle) -> Bool {
        return lhs.duration == rhs.duration &&
            lhs.reverseDuration == rhs.reverseDuration
    }
}
