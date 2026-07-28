// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - IconThemeData

/// Defines the size, font variations, color, opacity, and shadows of icons.
///
/// Used by `IconTheme` to control those properties in a widget subtree.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/icon_theme_data.dart:27-248`
public struct IconThemeData: Hashable {

    /// Creates an icon theme data.
    ///
    /// The opacity applies to both explicit and default icon colors. The value
    /// is clamped between 0.0 and 1.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:32-45`
    public init(
        size: Double? = nil,
        fill: Double? = nil,
        weight: Double? = nil,
        grade: Double? = nil,
        opticalSize: Double? = nil,
        color: Color? = nil,
        opacity: Double? = nil,
        shadows: [Shadow]? = nil,
        applyTextScaling: Bool? = nil
    ) {
        assert(fill == nil || (0.0 <= fill! && fill! <= 1.0))
        assert(weight == nil || (0.0 < weight!))
        assert(opticalSize == nil || (0.0 < opticalSize!))
        self.size = size
        self.fill = fill
        self.weight = weight
        self.grade = grade
        self.opticalSize = opticalSize
        self.color = color
        self._opacity = opacity
        self.shadows = shadows
        self.applyTextScaling = applyTextScaling
    }

    /// Creates an icon theme with some reasonable default values.
    ///
    /// The `size` is 24.0, `fill` is 0.0, `weight` is 400.0, `grade` is 0.0,
    /// `opticalSize` is 48.0, `color` is black, and `opacity` is 1.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:51-60`
    public static func fallback() -> IconThemeData {
        IconThemeData(
            size: 24.0,
            fill: 0.0,
            weight: 400.0,
            grade: 0.0,
            opticalSize: 48.0,
            color: Color(0xFF000000),
            opacity: 1.0,
            shadows: nil,
            applyTextScaling: false
        )
    }

    // MARK: - Properties

    /// The default for `Icon.size`. Falls back to 24.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:140`
    public let size: Double?

    /// The default for `Icon.fill`. Falls back to 0.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:145`
    public let fill: Double?

    /// The default for `Icon.weight`. Falls back to 400.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:150`
    public let weight: Double?

    /// The default for `Icon.grade`. Falls back to 0.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:155`
    public let grade: Double?

    /// The default for `Icon.opticalSize`. Falls back to 48.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:160`
    public let opticalSize: Double?

    /// The default for `Icon.color`.
    ///
    /// **Dart Source:** `icon_theme_data.dart:169`
    public let color: Color?

    /// An opacity to apply to both explicit and default icon colors.
    /// Falls back to 1.0.
    ///
    /// **Dart Source:** `icon_theme_data.dart:174-175`
    public var opacity: Double? {
        guard let op = _opacity else { return nil }
        return clampDouble(op, 0.0, 1.0)
    }
    private let _opacity: Double?

    /// The default for `Icon.shadows`.
    ///
    /// **Dart Source:** `icon_theme_data.dart:178`
    public let shadows: [Shadow]?

    /// The default for `Icon.applyTextScaling`.
    ///
    /// **Dart Source:** `icon_theme_data.dart:181`
    public let applyTextScaling: Bool?

    // MARK: - Methods

    /// Creates a copy of this icon theme but with the given fields replaced
    /// with the new values.
    ///
    /// **Dart Source:** `icon_theme_data.dart:64-86`
    public func copyWith(
        size: Double?? = nil,
        fill: Double?? = nil,
        weight: Double?? = nil,
        grade: Double?? = nil,
        opticalSize: Double?? = nil,
        color: Color?? = nil,
        opacity: Double?? = nil,
        shadows: [Shadow]?? = nil,
        applyTextScaling: Bool?? = nil
    ) -> IconThemeData {
        IconThemeData(
            size: size ?? self.size,
            fill: fill ?? self.fill,
            weight: weight ?? self.weight,
            grade: grade ?? self.grade,
            opticalSize: opticalSize ?? self.opticalSize,
            color: color ?? self.color,
            opacity: opacity ?? self.opacity,
            shadows: shadows ?? self.shadows,
            applyTextScaling: applyTextScaling ?? self.applyTextScaling
        )
    }

    /// Returns a new icon theme that matches this icon theme but with some
    /// values replaced by the non-null parameters of the given icon theme.
    /// If the given icon theme is nil, returns this icon theme.
    ///
    /// **Dart Source:** `icon_theme_data.dart:91-106`
    public func merge(_ other: IconThemeData?) -> IconThemeData {
        guard let other = other else { return self }
        return IconThemeData(
            size: other.size ?? self.size,
            fill: other.fill ?? self.fill,
            weight: other.weight ?? self.weight,
            grade: other.grade ?? self.grade,
            opticalSize: other.opticalSize ?? self.opticalSize,
            color: other.color ?? self.color,
            opacity: other.opacity ?? self._opacity,
            shadows: other.shadows ?? self.shadows,
            applyTextScaling: other.applyTextScaling ?? self.applyTextScaling
        )
    }

    /// Called by `IconTheme.of` to convert this instance to an `IconThemeData`
    /// that fits the given `BuildContext`.
    ///
    /// The default implementation returns this `IconThemeData` as-is.
    ///
    /// **Dart Source:** `icon_theme_data.dart:124`
    public func resolve(_ context: any BuildContext) -> IconThemeData {
        self
    }

    /// Whether all the properties (except shadows) of this object are non-null.
    ///
    /// **Dart Source:** `icon_theme_data.dart:127-135`
    public var isConcrete: Bool {
        size != nil
            && fill != nil
            && weight != nil
            && grade != nil
            && opticalSize != nil
            && color != nil
            && opacity != nil
            && applyTextScaling != nil
    }

    /// Linearly interpolate between two icon theme data objects.
    ///
    /// **Dart Source:** `icon_theme_data.dart:186-201`
    public static func lerp(_ a: IconThemeData?, _ b: IconThemeData?, _ t: Double) -> IconThemeData {
        if a == b, let a = a {
            return a
        }
        return IconThemeData(
            size: lerpDouble(a?.size, b?.size, t),
            fill: lerpDouble(a?.fill, b?.fill, t),
            weight: lerpDouble(a?.weight, b?.weight, t),
            grade: lerpDouble(a?.grade, b?.grade, t),
            opticalSize: lerpDouble(a?.opticalSize, b?.opticalSize, t),
            color: Color.lerp(a?.color, b?.color, t),
            opacity: lerpDouble(a?.opacity, b?.opacity, t),
            shadows: Shadow.lerpList(a?.shadows, b?.shadows, t),
            applyTextScaling: t < 0.5 ? a?.applyTextScaling : b?.applyTextScaling
        )
    }

    // MARK: - Hashable

    /// **Dart Source:** `icon_theme_data.dart:204-218`
    public static func == (lhs: IconThemeData, rhs: IconThemeData) -> Bool {
        lhs.size == rhs.size
            && lhs.fill == rhs.fill
            && lhs.weight == rhs.weight
            && lhs.grade == rhs.grade
            && lhs.opticalSize == rhs.opticalSize
            && lhs.color == rhs.color
            && lhs.opacity == rhs.opacity
            && lhs.shadows == rhs.shadows
            && lhs.applyTextScaling == rhs.applyTextScaling
    }

    /// **Dart Source:** `icon_theme_data.dart:221-231`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(size)
        hasher.combine(fill)
        hasher.combine(weight)
        hasher.combine(grade)
        hasher.combine(opticalSize)
        hasher.combine(color)
        hasher.combine(opacity)
        hasher.combine(shadows)
        hasher.combine(applyTextScaling)
    }
}
