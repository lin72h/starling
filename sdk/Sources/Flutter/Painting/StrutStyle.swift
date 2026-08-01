// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Defines the strut, which sets the minimum height a line can be
/// relative to the baseline.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/strut_style.dart`

import FlutterSwiftBridge

// MARK: - StrutStyle

/// Defines the strut, which sets the minimum height a line can be
/// relative to the baseline.
///
/// Strut applies to all lines in the paragraph. Strut is a feature that
/// allows minimum line heights to be set. The effect is as if a zero
/// width space was included at the beginning of each line in the
/// paragraph.
///
/// No lines may be shorter than the strut. The ascent and descent of the
/// strut are calculated, and any laid out text that has a shorter ascent or
/// descent than the strut's ascent or descent will take the ascent and
/// descent of the strut.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/strut_style.dart`
/// **Original Name:** `StrutStyle`
/// **Lines:** 291-659
public struct StrutStyle: Hashable, Sendable, CustomStringConvertible {

    // MARK: - Properties

    /// The name of the font to use when calculating the strut (e.g., Roboto).
    ///
    /// If the font is defined in a package, this will be prefixed with
    /// 'packages/package_name/' (e.g. 'packages/cool_fonts/Roboto'). The
    /// prefixing is done by the constructor when the `package` argument is
    /// provided.
    ///
    /// **Dart Source:** `strut_style.dart:383`
    public let fontFamily: String?

    /// The backing store for `fontFamilyFallback`.
    ///
    /// **Dart Source:** `strut_style.dart:411`
    private let _fontFamilyFallback: [String]?

    /// The package name used to prefix font families.
    ///
    /// **Dart Source:** `strut_style.dart:415`
    private let _package: String?

    /// The size of text (in logical pixels) to use when obtaining metrics from the font.
    ///
    /// The default fontSize is 14 logical pixels.
    ///
    /// **Dart Source:** `strut_style.dart:424`
    public let fontSize: Double?

    /// The minimum height of the strut, as a multiple of `fontSize`.
    ///
    /// **Dart Source:** `strut_style.dart:447`
    public let height: Double?

    /// How the vertical space added by the `height` multiplier should be
    /// distributed over and under the strut.
    ///
    /// **Dart Source:** `strut_style.dart:463`
    public let leadingDistribution: TextLeadingDistribution?

    /// The typeface thickness to use when calculating the strut (e.g., bold).
    ///
    /// The default fontWeight is `FontWeight.w400`.
    ///
    /// **Dart Source:** `strut_style.dart:468`
    public let fontWeight: FontWeight?

    /// The typeface variant to use when calculating the strut (e.g., italics).
    ///
    /// The default fontStyle is `FontStyle.normal`.
    ///
    /// **Dart Source:** `strut_style.dart:473`
    public let fontStyle: FontStyle?

    /// The additional leading to apply to the strut as a multiple of `fontSize`,
    /// independent of `height` and `leadingDistribution`.
    ///
    /// **Dart Source:** `strut_style.dart:484`
    public let leading: Double?

    /// Whether the strut height should be forced.
    ///
    /// When true, all lines will be laid out with the height of the
    /// strut. All line and run-specific metrics will be ignored/overridden
    /// and only strut metrics will be used instead.
    ///
    /// **Dart Source:** `strut_style.dart:503`
    public let forceStrutHeight: Bool?

    /// A human-readable description of this strut style.
    ///
    /// This property is maintained only in debug builds.
    ///
    /// This property is not considered when comparing strut styles using `==` or
    /// `compareTo`, and it does not affect `hashCode`.
    ///
    /// **Dart Source:** `strut_style.dart:511`
    public let debugLabel: String?

    // MARK: - Computed Properties

    /// The ordered list of font families to fall back on when a higher priority
    /// font family cannot be found.
    ///
    /// If the font is defined in a package, each font family in the list will be
    /// prefixed with 'packages/package_name/'.
    ///
    /// **Dart Source:** `strut_style.dart:404-409`
    public var fontFamilyFallback: [String]? {
        if let package = _package, let fallback = _fontFamilyFallback {
            return fallback.map { "packages/\(package)/\($0)" }
        }
        return _fontFamilyFallback
    }

    // MARK: - Initializer

    /// Creates a strut style.
    ///
    /// The `package` argument must be non-null if the font family is defined in a
    /// package. It is combined with the `fontFamily` argument to set the
    /// `fontFamily` property.
    ///
    /// If provided, fontSize must be positive and non-zero, leading must be
    /// zero or positive.
    ///
    /// **Dart Source:** `strut_style.dart:300-317`
    public init(
        fontFamily: String? = nil,
        fontFamilyFallback: [String]? = nil,
        fontSize: Double? = nil,
        height: Double? = nil,
        leadingDistribution: TextLeadingDistribution? = nil,
        leading: Double? = nil,
        fontWeight: FontWeight? = nil,
        fontStyle: FontStyle? = nil,
        forceStrutHeight: Bool? = nil,
        debugLabel: String? = nil,
        package: String? = nil
    ) {
        assert(fontSize == nil || fontSize! > 0, "fontSize must be positive")
        assert(leading == nil || leading! >= 0, "leading must be non-negative")
        assert(
            package == nil || (fontFamily != nil || fontFamilyFallback != nil),
            "package requires fontFamily or fontFamilyFallback"
        )

        // Prefix fontFamily with package if provided
        if let package = package, let family = fontFamily {
            self.fontFamily = "packages/\(package)/\(family)"
        } else {
            self.fontFamily = fontFamily
        }

        self._fontFamilyFallback = fontFamilyFallback
        self._package = package
        self.fontSize = fontSize
        self.height = height
        self.leadingDistribution = leadingDistribution
        self.leading = leading
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.forceStrutHeight = forceStrutHeight
        self.debugLabel = debugLabel
    }

    // MARK: - Internal Initializer (for inheritFromTextStyle)

    /// Internal initializer that accepts a pre-resolved fontFamily (no package prefixing).
    ///
    /// Used by `inheritFromTextStyle` where fontFamily values are already resolved.
    private init(
        _resolvedFontFamily fontFamily: String?,
        fontFamilyFallback: [String]?,
        package: String?,
        fontSize: Double?,
        height: Double?,
        leadingDistribution: TextLeadingDistribution?,
        leading: Double?,
        fontWeight: FontWeight?,
        fontStyle: FontStyle?,
        forceStrutHeight: Bool?,
        debugLabel: String?
    ) {
        self.fontFamily = fontFamily
        self._fontFamilyFallback = fontFamilyFallback
        self._package = package
        self.fontSize = fontSize
        self.height = height
        self.leadingDistribution = leadingDistribution
        self.leading = leading
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.forceStrutHeight = forceStrutHeight
        self.debugLabel = debugLabel
    }

    // MARK: - Static Constants

    /// A `StrutStyle` that will have no impact on the text layout.
    ///
    /// Equivalent to having no strut at all. All lines will be laid out according to
    /// the properties defined in `TextStyle`.
    ///
    /// **Dart Source:** `strut_style.dart:369`
    public static let disabled = StrutStyle(height: 0.0, leading: 0.0)

    // MARK: - Factory Methods

    /// Builds a StrutStyle that contains values of the equivalent properties in
    /// the provided `textStyle`.
    ///
    /// The named parameters override the `textStyle`'s argument's properties.
    /// Since TextStyle does not contain `leading` or `forceStrutHeight`, these
    /// values will take on default values (nil) unless otherwise specified.
    ///
    /// If provided, fontSize must be positive and non-zero, leading must be
    /// zero or positive.
    ///
    /// **Dart Source:** `strut_style.dart:336-363`
    public static func fromTextStyle(
        _ textStyle: TextStyle,
        fontFamily: String? = nil,
        fontFamilyFallback: [String]? = nil,
        fontSize: Double? = nil,
        height: Double? = nil,
        leadingDistribution: TextLeadingDistribution? = nil,
        leading: Double? = nil,
        fontWeight: FontWeight? = nil,
        fontStyle: FontStyle? = nil,
        forceStrutHeight: Bool? = nil,
        debugLabel: String? = nil,
        package: String? = nil
    ) -> StrutStyle {
        assert(fontSize == nil || fontSize! > 0)
        assert(leading == nil || leading! >= 0)
        assert(package == nil || fontFamily != nil || fontFamilyFallback != nil)

        let resolvedFontFamily: String?
        if let family = fontFamily {
            resolvedFontFamily = package != nil ? "packages/\(package!)/\(family)" : family
        } else {
            resolvedFontFamily = textStyle.fontFamily
        }

        return StrutStyle(
            _resolvedFontFamily: resolvedFontFamily,
            fontFamilyFallback: fontFamilyFallback ?? textStyle.fontFamilyFallback,
            package: package,
            fontSize: fontSize ?? textStyle.fontSize,
            height: height ?? textStyle.height,
            leadingDistribution: leadingDistribution ?? textStyle.leadingDistribution,
            leading: leading,
            fontWeight: fontWeight ?? textStyle.fontWeight,
            fontStyle: fontStyle ?? textStyle.fontStyle,
            forceStrutHeight: forceStrutHeight,
            debugLabel: debugLabel
        )
    }

    // MARK: - Methods

    /// Describe the difference between this style and another, in terms of how
    /// much damage it will make to the rendering.
    ///
    /// **Dart Source:** `strut_style.dart:519-535`
    public func compareTo(_ other: StrutStyle) -> RenderComparison {
        if self == other {
            return .identical
        }
        if fontFamily != other.fontFamily ||
            fontSize != other.fontSize ||
            fontWeight != other.fontWeight ||
            fontStyle != other.fontStyle ||
            height != other.height ||
            leading != other.leading ||
            forceStrutHeight != other.forceStrutHeight ||
            fontFamilyFallback != other.fontFamilyFallback ||
            (height != nil && leadingDistribution != other.leadingDistribution) {
            return .layout
        }
        return .identical
    }

    /// Returns a new strut style that inherits its null values from
    /// corresponding properties in the `other` `TextStyle`.
    ///
    /// The "missing" properties of this strut style are filled by
    /// the properties of the provided `TextStyle`.
    ///
    /// If the given text style is nil, returns this strut style.
    ///
    /// **Dart Source:** `strut_style.dart:545-567`
    public func inheritFromTextStyle(_ other: TextStyle?) -> StrutStyle {
        guard let other = other else {
            return self
        }

        let effectiveHeight = height ?? other.height

        return StrutStyle(
            _resolvedFontFamily: fontFamily ?? other.fontFamily,
            fontFamilyFallback: fontFamilyFallback ?? other.fontFamilyFallback,
            package: nil,  // Package is embedded within the getters for fontFamilyFallback
            fontSize: fontSize ?? other.fontSize,
            height: effectiveHeight,
            leadingDistribution: effectiveHeight != nil
                ? (leadingDistribution ?? other.leadingDistribution)
                : nil,
            leading: leading,
            fontWeight: fontWeight ?? other.fontWeight,
            fontStyle: fontStyle ?? other.fontStyle,
            forceStrutHeight: forceStrutHeight,
            debugLabel: debugLabel
        )
    }

    // MARK: - Equatable

    /// Compares two strut styles for equality.
    ///
    /// The `debugLabel` is not considered when comparing strut styles.
    ///
    /// **Dart Source:** `strut_style.dart:570-587`
    public static func == (lhs: StrutStyle, rhs: StrutStyle) -> Bool {
        return lhs.fontFamily == rhs.fontFamily &&
            lhs.fontSize == rhs.fontSize &&
            lhs.fontWeight == rhs.fontWeight &&
            lhs.fontStyle == rhs.fontStyle &&
            lhs.height == rhs.height &&
            lhs.leading == rhs.leading &&
            lhs.forceStrutHeight == rhs.forceStrutHeight &&
            (lhs.height == nil || lhs.leadingDistribution == rhs.leadingDistribution) &&
            lhs.fontFamilyFallback == rhs.fontFamilyFallback
    }

    // MARK: - Hashable

    /// The hash code for this strut style.
    ///
    /// **Dart Source:** `strut_style.dart:590-591`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fontFamily)
        hasher.combine(fontSize)
        hasher.combine(fontWeight)
        hasher.combine(fontStyle)
        hasher.combine(height)
        hasher.combine(leading)
        hasher.combine(forceStrutHeight)
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this strut style, matching the Dart diagnostics output format.
    ///
    /// The format is: `StrutStyle(prop1: val1, prop2: val2, ...)` when properties are specified,
    /// or just `StrutStyle` when no properties are specified.
    ///
    /// This mirrors the behavior of `Diagnosticable.toString()` with `DiagnosticsTreeStyle.singleLine`
    /// from the Dart implementation.
    ///
    /// **Dart Source:** `strut_style.dart:594` (`toStringShort`) and
    /// `strut_style.dart:598-658` (`debugFillProperties`)
    public var description: String {
        var parts: [String] = []

        // debugLabel is added as a separate property before styles
        // (but in the Dart output it's included in the parenthesized list)
        if let debugLabel = debugLabel {
            parts.append("debugLabel: \(debugLabel)")
        }

        // Build the styles list matching Dart's debugFillProperties
        var styles: [String?] = []

        // StringProperty: family
        if let family = fontFamily {
            styles.append("family: \(family)")
        }

        // IterableProperty: familyFallback
        if let fallback = fontFamilyFallback, !fallback.isEmpty {
            styles.append("familyFallback: [\(fallback.joined(separator: ", "))]")
        }

        // DoubleProperty: size
        if let size = fontSize {
            styles.append("size: \(debugFormatDouble(size))")
        }

        // DiagnosticsProperty<FontWeight>: weight
        if let weight = fontWeight {
            styles.append("weight: w\(weight.index + 1)00")
        }

        // EnumProperty<FontStyle>: style
        if let style = fontStyle {
            let styleName: String
            switch style {
            case .normal: styleName = "normal"
            case .italic: styleName = "italic"
            @unknown default: styleName = "unknown"
            }
            styles.append("style: \(styleName)")
        }

        // DoubleProperty: height (with unit "x")
        if let h = height {
            styles.append("height: \(debugFormatDouble(h))x")
        }

        // FlagProperty: forceStrutHeight
        if let force = forceStrutHeight {
            if force {
                styles.append("<strut height forced>")
            } else {
                styles.append("<strut height normal>")
            }
        }

        // EnumProperty: leadingDistribution (only when height != nil)
        if height != nil {
            if let dist = leadingDistribution {
                let distName: String
                switch dist {
                case .proportional: distName = "proportional"
                case .even: distName = "even"
                @unknown default: distName = "unknown"
                }
                styles.append("leadingDistribution: \(distName)")
            }
        }

        // Check if any style was specified (non-nil)
        let styleSpecified = styles.contains { $0 != nil }

        // Add all non-nil styles to parts
        for style in styles {
            if let s = style {
                parts.append(s)
            }
        }

        // If no style was specified, add forceStrutHeight flag as a fallback
        if !styleSpecified {
            if let force = forceStrutHeight {
                if force {
                    parts.append("<strut height forced>")
                } else {
                    parts.append("<strut height normal>")
                }
            }
        }

        if parts.isEmpty {
            return "StrutStyle"
        }
        return "StrutStyle(\(parts.joined(separator: ", ")))"
    }
}
