// macOS typography ported from macos_ui/lib/src/theme/typography.dart

import FlutterSwiftBridge

// MARK: - MacosTypography

/// macOS typography following Apple's Human Interface Guidelines.
///
/// | Style       | Size | Weight | Spacing |
/// |:------------|-----:|:-------|--------:|
/// | largeTitle  |  26  | w400   |   0.22  |
/// | title1      |  22  | w400   |  -0.26  |
/// | title2      |  17  | w400   |  -0.43  |
/// | title3      |  15  | w400   |  -0.23  |
/// | headline    |  13  | w700   |  -0.08  |
/// | body        |  13  | w400   |   0.06  |
/// | callout     |  12  | w400   |    0    |
/// | subheadline |  11  | w400   |   0.06  |
/// | footnote    |  10  | w400   |   0.12  |
/// | caption1    |  10  | w400   |   0.12  |
/// | caption2    |  10  | w510   |   0.12  |
public struct MacosTypography: Equatable {
    public let largeTitle: TextStyle
    public let title1: TextStyle
    public let title2: TextStyle
    public let title3: TextStyle
    public let headline: TextStyle
    public let subheadline: TextStyle
    public let body: TextStyle
    public let callout: TextStyle
    public let footnote: TextStyle
    public let caption1: TextStyle
    public let caption2: TextStyle

    /// Creates a typography with all style properties specified directly.
    public init(
        largeTitle: TextStyle,
        title1: TextStyle,
        title2: TextStyle,
        title3: TextStyle,
        headline: TextStyle,
        subheadline: TextStyle,
        body: TextStyle,
        callout: TextStyle,
        footnote: TextStyle,
        caption1: TextStyle,
        caption2: TextStyle
    ) {
        self.largeTitle = largeTitle
        self.title1 = title1
        self.title2 = title2
        self.title3 = title3
        self.headline = headline
        self.subheadline = subheadline
        self.body = body
        self.callout = callout
        self.footnote = footnote
        self.caption1 = caption1
        self.caption2 = caption2
    }

    /// Creates a macOS typography with the given color.
    ///
    /// Follows Apple's HIG type ramp with `.AppleSystemUIFont` family.
    public init(color: Color) {
        self.largeTitle = TextStyle(
            color: color, fontSize: 26, fontWeight: .w400,
            letterSpacing: 0.22
        )
        self.title1 = TextStyle(
            color: color, fontSize: 22, fontWeight: .w400,
            letterSpacing: -0.26
        )
        self.title2 = TextStyle(
            color: color, fontSize: 17, fontWeight: .w400,
            letterSpacing: -0.43
        )
        self.title3 = TextStyle(
            color: color, fontSize: 15, fontWeight: .w400,
            letterSpacing: -0.23
        )
        self.headline = TextStyle(
            color: color, fontSize: 13, fontWeight: .w700,
            letterSpacing: -0.08
        )
        self.body = TextStyle(
            color: color, fontSize: 13, fontWeight: .w400,
            letterSpacing: 0.06
        )
        self.callout = TextStyle(
            color: color, fontSize: 12, fontWeight: .w400
        )
        self.subheadline = TextStyle(
            color: color, fontSize: 11, fontWeight: .w400,
            letterSpacing: 0.06
        )
        self.footnote = TextStyle(
            color: color, fontSize: 10, fontWeight: .w400,
            letterSpacing: 0.12
        )
        self.caption1 = TextStyle(
            color: color, fontSize: 10, fontWeight: .w400,
            letterSpacing: 0.12
        )
        self.caption2 = TextStyle(
            color: color, fontSize: 10, fontWeight: .w500,
            letterSpacing: 0.12
        )
    }

    /// Creates a dark-opaque typography (dark text for light backgrounds).
    public static func darkOpaque() -> MacosTypography {
        // labelColor.color for light mode: rgba(0, 0, 0, 0.85)
        MacosTypography(color: Color(rgbo: 0, 0, 0, 0.85))
    }

    /// Creates a light-opaque typography (light text for dark backgrounds).
    public static func lightOpaque() -> MacosTypography {
        // labelColor.darkColor for dark mode: rgba(255, 255, 255, 0.85)
        MacosTypography(color: Color(rgbo: 255, 255, 255, 0.85))
    }

    /// Merges another typography into this one. Values from `other` take precedence.
    public func merge(_ other: MacosTypography?) -> MacosTypography {
        guard let other = other else { return self }
        return MacosTypography(
            largeTitle: other.largeTitle,
            title1: other.title1,
            title2: other.title2,
            title3: other.title3,
            headline: other.headline,
            subheadline: other.subheadline,
            body: other.body,
            callout: other.callout,
            footnote: other.footnote,
            caption1: other.caption1,
            caption2: other.caption2
        )
    }

    /// Linearly interpolates between two typographies.
    public static func lerp(_ a: MacosTypography, _ b: MacosTypography, _ t: Double) -> MacosTypography {
        return MacosTypography(
            largeTitle: TextStyle.lerp(a.largeTitle, b.largeTitle, t)!,
            title1: TextStyle.lerp(a.title1, b.title1, t)!,
            title2: TextStyle.lerp(a.title2, b.title2, t)!,
            title3: TextStyle.lerp(a.title3, b.title3, t)!,
            headline: TextStyle.lerp(a.headline, b.headline, t)!,
            subheadline: TextStyle.lerp(a.subheadline, b.subheadline, t)!,
            body: TextStyle.lerp(a.body, b.body, t)!,
            callout: TextStyle.lerp(a.callout, b.callout, t)!,
            footnote: TextStyle.lerp(a.footnote, b.footnote, t)!,
            caption1: TextStyle.lerp(a.caption1, b.caption1, t)!,
            caption2: TextStyle.lerp(a.caption2, b.caption2, t)!
        )
    }
}
