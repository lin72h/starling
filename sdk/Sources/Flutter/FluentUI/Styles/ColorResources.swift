// Fluent UI color resources ported from fluent_ui/lib/src/styles/color_resources.dart
// Based on https://github.com/microsoft/microsoft-ui-xaml/blob/main/dev/CommonStyles/Common_themeresources_any.xaml

import FlutterSwiftBridge

// MARK: - ResourceDictionary

/// A dictionary of colors used by all the Fluent UI components.
///
/// Use `ResourceDictionary.light()` or `ResourceDictionary.dark()` to get colors
/// adapted to light and dark mode, respectively.
public struct ResourceDictionary: Equatable {
    // MARK: Text Fill Colors
    public var textFillColorPrimary: Color
    public var textFillColorSecondary: Color
    public var textFillColorTertiary: Color
    public var textFillColorDisabled: Color
    public var textFillColorInverse: Color
    public var accentTextFillColorDisabled: Color
    public var textOnAccentFillColorSelectedText: Color
    public var textOnAccentFillColorPrimary: Color
    public var textOnAccentFillColorSecondary: Color
    public var textOnAccentFillColorDisabled: Color

    // MARK: Control Fill Colors
    public var controlFillColorDefault: Color
    public var controlFillColorSecondary: Color
    public var controlFillColorTertiary: Color
    public var controlFillColorQuarternary: Color
    public var controlFillColorDisabled: Color
    public var controlFillColorTransparent: Color
    public var controlFillColorInputActive: Color
    public var controlStrongFillColorDefault: Color
    public var controlStrongFillColorDisabled: Color
    public var controlSolidFillColorDefault: Color

    // MARK: Subtle Fill Colors
    public var subtleFillColorTransparent: Color
    public var subtleFillColorSecondary: Color
    public var subtleFillColorTertiary: Color
    public var subtleFillColorDisabled: Color

    // MARK: Control Alt Fill Colors
    public var controlAltFillColorTransparent: Color
    public var controlAltFillColorSecondary: Color
    public var controlAltFillColorTertiary: Color
    public var controlAltFillColorQuarternary: Color
    public var controlAltFillColorDisabled: Color

    // MARK: Control On Image Fill Colors
    public var controlOnImageFillColorDefault: Color
    public var controlOnImageFillColorSecondary: Color
    public var controlOnImageFillColorTertiary: Color
    public var controlOnImageFillColorDisabled: Color

    // MARK: Accent Fill Colors
    public var accentFillColorDisabled: Color

    // MARK: Control Stroke Colors
    public var controlStrokeColorDefault: Color
    public var controlStrokeColorSecondary: Color
    public var controlStrokeColorOnAccentDefault: Color
    public var controlStrokeColorOnAccentSecondary: Color
    public var controlStrokeColorOnAccentTertiary: Color
    public var controlStrokeColorOnAccentDisabled: Color
    public var controlStrokeColorForStrongFillWhenOnImage: Color

    // MARK: Card Stroke Colors
    public var cardStrokeColorDefault: Color
    public var cardStrokeColorDefaultSolid: Color

    // MARK: Control Strong Stroke Colors
    public var controlStrongStrokeColorDefault: Color
    public var controlStrongStrokeColorDisabled: Color

    // MARK: Surface Stroke Colors
    public var surfaceStrokeColorDefault: Color
    public var surfaceStrokeColorFlyout: Color
    public var surfaceStrokeColorInverse: Color

    // MARK: Divider Stroke Colors
    public var dividerStrokeColorDefault: Color

    // MARK: Focus Stroke Colors
    public var focusStrokeColorOuter: Color
    public var focusStrokeColorInner: Color

    // MARK: Card Background Fill Colors
    public var cardBackgroundFillColorDefault: Color
    public var cardBackgroundFillColorSecondary: Color
    public var cardBackgroundFillColorTertiary: Color

    // MARK: Smoke Fill Colors
    public var smokeFillColorDefault: Color

    // MARK: Layer Fill Colors
    public var layerFillColorDefault: Color
    public var layerFillColorAlt: Color
    public var layerOnAcrylicFillColorDefault: Color
    public var layerOnAccentAcrylicFillColorDefault: Color
    public var layerOnMicaBaseAltFillColorDefault: Color
    public var layerOnMicaBaseAltFillColorSecondary: Color
    public var layerOnMicaBaseAltFillColorTertiary: Color
    public var layerOnMicaBaseAltFillColorTransparent: Color

    // MARK: Solid Background Fill Colors
    public var solidBackgroundFillColorBase: Color
    public var solidBackgroundFillColorSecondary: Color
    public var solidBackgroundFillColorTertiary: Color
    public var solidBackgroundFillColorQuarternary: Color
    public var solidBackgroundFillColorQuinary: Color
    public var solidBackgroundFillColorSenary: Color
    public var solidBackgroundFillColorTransparent: Color
    public var solidBackgroundFillColorBaseAlt: Color

    // MARK: System Fill Colors
    public var systemFillColorSuccess: Color
    public var systemFillColorCaution: Color
    public var systemFillColorCritical: Color
    public var systemFillColorNeutral: Color
    public var systemFillColorSolidNeutral: Color
    public var systemFillColorAttentionBackground: Color
    public var systemFillColorSuccessBackground: Color
    public var systemFillColorCautionBackground: Color
    public var systemFillColorCriticalBackground: Color
    public var systemFillColorNeutralBackground: Color
    public var systemFillColorSolidAttentionBackground: Color
    public var systemFillColorSolidNeutralBackground: Color

    // MARK: - Light Factory

    /// Creates a resource dictionary with colors adapted for light mode.
    public static func light() -> ResourceDictionary {
        ResourceDictionary(
            textFillColorPrimary: Color(0xe4000000),
            textFillColorSecondary: Color(0x9e000000),
            textFillColorTertiary: Color(0x72000000),
            textFillColorDisabled: Color(0x5c000000),
            textFillColorInverse: Color(0xFFffffff),
            accentTextFillColorDisabled: Color(0x5c000000),
            textOnAccentFillColorSelectedText: Color(0xFFffffff),
            textOnAccentFillColorPrimary: Color(0xFFffffff),
            textOnAccentFillColorSecondary: Color(0xb3ffffff),
            textOnAccentFillColorDisabled: Color(0xFFffffff),
            controlFillColorDefault: Color(0xb3ffffff),
            controlFillColorSecondary: Color(0x80f9f9f9),
            controlFillColorTertiary: Color(0x4df9f9f9),
            controlFillColorQuarternary: Color(0xc2f3f3f3),
            controlFillColorDisabled: Color(0x4df9f9f9),
            controlFillColorTransparent: Color(0x00ffffff),
            controlFillColorInputActive: Color(0xFFffffff),
            controlStrongFillColorDefault: Color(0x72000000),
            controlStrongFillColorDisabled: Color(0x51000000),
            controlSolidFillColorDefault: Color(0xFFffffff),
            subtleFillColorTransparent: Color(0x00ffffff),
            subtleFillColorSecondary: Color(0x09000000),
            subtleFillColorTertiary: Color(0x06000000),
            subtleFillColorDisabled: Color(0x00ffffff),
            controlAltFillColorTransparent: Color(0x00ffffff),
            controlAltFillColorSecondary: Color(0x06000000),
            controlAltFillColorTertiary: Color(0x0f000000),
            controlAltFillColorQuarternary: Color(0x18000000),
            controlAltFillColorDisabled: Color(0x00ffffff),
            controlOnImageFillColorDefault: Color(0xc9ffffff),
            controlOnImageFillColorSecondary: Color(0xFFf3f3f3),
            controlOnImageFillColorTertiary: Color(0xFFebebeb),
            controlOnImageFillColorDisabled: Color(0x00ffffff),
            accentFillColorDisabled: Color(0x37000000),
            controlStrokeColorDefault: Color(0x0f000000),
            controlStrokeColorSecondary: Color(0x29000000),
            controlStrokeColorOnAccentDefault: Color(0x14ffffff),
            controlStrokeColorOnAccentSecondary: Color(0x66000000),
            controlStrokeColorOnAccentTertiary: Color(0x37000000),
            controlStrokeColorOnAccentDisabled: Color(0x0f000000),
            controlStrokeColorForStrongFillWhenOnImage: Color(0x59ffffff),
            cardStrokeColorDefault: Color(0x0f000000),
            cardStrokeColorDefaultSolid: Color(0xFFebebeb),
            controlStrongStrokeColorDefault: Color(0x72000000),
            controlStrongStrokeColorDisabled: Color(0x37000000),
            surfaceStrokeColorDefault: Color(0x66757575),
            surfaceStrokeColorFlyout: Color(0x0f000000),
            surfaceStrokeColorInverse: Color(0x15ffffff),
            dividerStrokeColorDefault: Color(0x0f000000),
            focusStrokeColorOuter: Color(0xe4000000),
            focusStrokeColorInner: Color(0xb3ffffff),
            cardBackgroundFillColorDefault: Color(0xb3ffffff),
            cardBackgroundFillColorSecondary: Color(0x80f6f6f6),
            cardBackgroundFillColorTertiary: Color(0xFFffffff),
            smokeFillColorDefault: Color(0x4d000000),
            layerFillColorDefault: Color(0x80ffffff),
            layerFillColorAlt: Color(0xFFffffff),
            layerOnAcrylicFillColorDefault: Color(0x40ffffff),
            layerOnAccentAcrylicFillColorDefault: Color(0x40ffffff),
            layerOnMicaBaseAltFillColorDefault: Color(0xb3ffffff),
            layerOnMicaBaseAltFillColorSecondary: Color(0x0a000000),
            layerOnMicaBaseAltFillColorTertiary: Color(0xFFf9f9f9),
            layerOnMicaBaseAltFillColorTransparent: Color(0x00000000),
            solidBackgroundFillColorBase: Color(0xFFf3f3f3),
            solidBackgroundFillColorSecondary: Color(0xFFeeeeee),
            solidBackgroundFillColorTertiary: Color(0xFFf9f9f9),
            solidBackgroundFillColorQuarternary: Color(0xFFffffff),
            solidBackgroundFillColorQuinary: Color(0xFFfdfdfd),
            solidBackgroundFillColorSenary: Color(0xFFffffff),
            solidBackgroundFillColorTransparent: Color(0x00f3f3f3),
            solidBackgroundFillColorBaseAlt: Color(0xFFdadada),
            systemFillColorSuccess: Color(0xFF0f7b0f),
            systemFillColorCaution: Color(0xFF9d5d00),
            systemFillColorCritical: Color(0xFFc42b1c),
            systemFillColorNeutral: Color(0x72000000),
            systemFillColorSolidNeutral: Color(0xFF8a8a8a),
            systemFillColorAttentionBackground: Color(0x80f6f6f6),
            systemFillColorSuccessBackground: Color(0xFFdff6dd),
            systemFillColorCautionBackground: Color(0xFFfff4ce),
            systemFillColorCriticalBackground: Color(0xFFfde7e9),
            systemFillColorNeutralBackground: Color(0x06000000),
            systemFillColorSolidAttentionBackground: Color(0xFFf7f7f7),
            systemFillColorSolidNeutralBackground: Color(0xFFf3f3f3)
        )
    }

    // MARK: - Dark Factory

    /// Creates a resource dictionary with colors adapted for dark mode.
    public static func dark() -> ResourceDictionary {
        ResourceDictionary(
            textFillColorPrimary: Color(0xFFffffff),
            textFillColorSecondary: Color(0xc5ffffff),
            textFillColorTertiary: Color(0x87ffffff),
            textFillColorDisabled: Color(0x5dffffff),
            textFillColorInverse: Color(0xe4000000),
            accentTextFillColorDisabled: Color(0x5dffffff),
            textOnAccentFillColorSelectedText: Color(0xFFffffff),
            textOnAccentFillColorPrimary: Color(0xFF000000),
            textOnAccentFillColorSecondary: Color(0x80000000),
            textOnAccentFillColorDisabled: Color(0x87ffffff),
            controlFillColorDefault: Color(0x0fffffff),
            controlFillColorSecondary: Color(0x15ffffff),
            controlFillColorTertiary: Color(0x08ffffff),
            controlFillColorQuarternary: Color(0x0fffffff),
            controlFillColorDisabled: Color(0x0bffffff),
            controlFillColorTransparent: Color(0x00ffffff),
            controlFillColorInputActive: Color(0xb31e1e1e),
            controlStrongFillColorDefault: Color(0x8bffffff),
            controlStrongFillColorDisabled: Color(0x3fffffff),
            controlSolidFillColorDefault: Color(0xFF454545),
            subtleFillColorTransparent: Color(0x00ffffff),
            subtleFillColorSecondary: Color(0x0fffffff),
            subtleFillColorTertiary: Color(0x0affffff),
            subtleFillColorDisabled: Color(0x00ffffff),
            controlAltFillColorTransparent: Color(0x00ffffff),
            controlAltFillColorSecondary: Color(0x19000000),
            controlAltFillColorTertiary: Color(0x0bffffff),
            controlAltFillColorQuarternary: Color(0x12ffffff),
            controlAltFillColorDisabled: Color(0x00ffffff),
            controlOnImageFillColorDefault: Color(0xb31c1c1c),
            controlOnImageFillColorSecondary: Color(0xFF1a1a1a),
            controlOnImageFillColorTertiary: Color(0xFF131313),
            controlOnImageFillColorDisabled: Color(0xFF1e1e1e),
            accentFillColorDisabled: Color(0x28ffffff),
            controlStrokeColorDefault: Color(0x12ffffff),
            controlStrokeColorSecondary: Color(0x18ffffff),
            controlStrokeColorOnAccentDefault: Color(0x14ffffff),
            controlStrokeColorOnAccentSecondary: Color(0x23000000),
            controlStrokeColorOnAccentTertiary: Color(0x37000000),
            controlStrokeColorOnAccentDisabled: Color(0x33000000),
            controlStrokeColorForStrongFillWhenOnImage: Color(0x6b000000),
            cardStrokeColorDefault: Color(0x19000000),
            cardStrokeColorDefaultSolid: Color(0xFF1c1c1c),
            controlStrongStrokeColorDefault: Color(0x8bffffff),
            controlStrongStrokeColorDisabled: Color(0x28ffffff),
            surfaceStrokeColorDefault: Color(0x66757575),
            surfaceStrokeColorFlyout: Color(0x33000000),
            surfaceStrokeColorInverse: Color(0x0f000000),
            dividerStrokeColorDefault: Color(0x15ffffff),
            focusStrokeColorOuter: Color(0xFFffffff),
            focusStrokeColorInner: Color(0xb3000000),
            cardBackgroundFillColorDefault: Color(0x0dffffff),
            cardBackgroundFillColorSecondary: Color(0x08ffffff),
            cardBackgroundFillColorTertiary: Color(0x12ffffff),
            smokeFillColorDefault: Color(0x4d000000),
            layerFillColorDefault: Color(0x4c3a3a3a),
            layerFillColorAlt: Color(0x0dffffff),
            layerOnAcrylicFillColorDefault: Color(0x09ffffff),
            layerOnAccentAcrylicFillColorDefault: Color(0x09ffffff),
            layerOnMicaBaseAltFillColorDefault: Color(0x733a3a3a),
            layerOnMicaBaseAltFillColorSecondary: Color(0x0fffffff),
            layerOnMicaBaseAltFillColorTertiary: Color(0xFF2c2c2c),
            layerOnMicaBaseAltFillColorTransparent: Color(0x00ffffff),
            solidBackgroundFillColorBase: Color(0xFF202020),
            solidBackgroundFillColorSecondary: Color(0xFF1c1c1c),
            solidBackgroundFillColorTertiary: Color(0xFF282828),
            solidBackgroundFillColorQuarternary: Color(0xFF2c2c2c),
            solidBackgroundFillColorQuinary: Color(0xFF333333),
            solidBackgroundFillColorSenary: Color(0xFF373737),
            solidBackgroundFillColorTransparent: Color(0x00202020),
            solidBackgroundFillColorBaseAlt: Color(0xFF0a0a0a),
            systemFillColorSuccess: Color(0xFF6ccb5f),
            systemFillColorCaution: Color(0xFFfce100),
            systemFillColorCritical: Color(0xFFff99a4),
            systemFillColorNeutral: Color(0x8bffffff),
            systemFillColorSolidNeutral: Color(0xFF9d9d9d),
            systemFillColorAttentionBackground: Color(0x08ffffff),
            systemFillColorSuccessBackground: Color(0xFF393d1b),
            systemFillColorCautionBackground: Color(0xFF433519),
            systemFillColorCriticalBackground: Color(0xFF442726),
            systemFillColorNeutralBackground: Color(0x08ffffff),
            systemFillColorSolidAttentionBackground: Color(0xFF2e2e2e),
            systemFillColorSolidNeutralBackground: Color(0xFF2e2e2e)
        )
    }

    // MARK: - copyWith

    /// Creates a copy of this resource dictionary with the given fields replaced.
    public func copyWith(
        textFillColorPrimary: Color? = nil,
        textFillColorSecondary: Color? = nil,
        textFillColorTertiary: Color? = nil,
        textFillColorDisabled: Color? = nil,
        textFillColorInverse: Color? = nil,
        accentTextFillColorDisabled: Color? = nil,
        textOnAccentFillColorSelectedText: Color? = nil,
        textOnAccentFillColorPrimary: Color? = nil,
        textOnAccentFillColorSecondary: Color? = nil,
        textOnAccentFillColorDisabled: Color? = nil,
        controlFillColorDefault: Color? = nil,
        controlFillColorSecondary: Color? = nil,
        controlFillColorTertiary: Color? = nil,
        controlFillColorQuarternary: Color? = nil,
        controlFillColorDisabled: Color? = nil,
        controlFillColorTransparent: Color? = nil,
        controlFillColorInputActive: Color? = nil,
        controlStrongFillColorDefault: Color? = nil,
        controlStrongFillColorDisabled: Color? = nil,
        controlSolidFillColorDefault: Color? = nil,
        subtleFillColorTransparent: Color? = nil,
        subtleFillColorSecondary: Color? = nil,
        subtleFillColorTertiary: Color? = nil,
        subtleFillColorDisabled: Color? = nil,
        controlAltFillColorTransparent: Color? = nil,
        controlAltFillColorSecondary: Color? = nil,
        controlAltFillColorTertiary: Color? = nil,
        controlAltFillColorQuarternary: Color? = nil,
        controlAltFillColorDisabled: Color? = nil,
        controlOnImageFillColorDefault: Color? = nil,
        controlOnImageFillColorSecondary: Color? = nil,
        controlOnImageFillColorTertiary: Color? = nil,
        controlOnImageFillColorDisabled: Color? = nil,
        accentFillColorDisabled: Color? = nil,
        controlStrokeColorDefault: Color? = nil,
        controlStrokeColorSecondary: Color? = nil,
        controlStrokeColorOnAccentDefault: Color? = nil,
        controlStrokeColorOnAccentSecondary: Color? = nil,
        controlStrokeColorOnAccentTertiary: Color? = nil,
        controlStrokeColorOnAccentDisabled: Color? = nil,
        controlStrokeColorForStrongFillWhenOnImage: Color? = nil,
        cardStrokeColorDefault: Color? = nil,
        cardStrokeColorDefaultSolid: Color? = nil,
        controlStrongStrokeColorDefault: Color? = nil,
        controlStrongStrokeColorDisabled: Color? = nil,
        surfaceStrokeColorDefault: Color? = nil,
        surfaceStrokeColorFlyout: Color? = nil,
        surfaceStrokeColorInverse: Color? = nil,
        dividerStrokeColorDefault: Color? = nil,
        focusStrokeColorOuter: Color? = nil,
        focusStrokeColorInner: Color? = nil,
        cardBackgroundFillColorDefault: Color? = nil,
        cardBackgroundFillColorSecondary: Color? = nil,
        cardBackgroundFillColorTertiary: Color? = nil,
        smokeFillColorDefault: Color? = nil,
        layerFillColorDefault: Color? = nil,
        layerFillColorAlt: Color? = nil,
        layerOnAcrylicFillColorDefault: Color? = nil,
        layerOnAccentAcrylicFillColorDefault: Color? = nil,
        layerOnMicaBaseAltFillColorDefault: Color? = nil,
        layerOnMicaBaseAltFillColorSecondary: Color? = nil,
        layerOnMicaBaseAltFillColorTertiary: Color? = nil,
        layerOnMicaBaseAltFillColorTransparent: Color? = nil,
        solidBackgroundFillColorBase: Color? = nil,
        solidBackgroundFillColorSecondary: Color? = nil,
        solidBackgroundFillColorTertiary: Color? = nil,
        solidBackgroundFillColorQuarternary: Color? = nil,
        solidBackgroundFillColorQuinary: Color? = nil,
        solidBackgroundFillColorSenary: Color? = nil,
        solidBackgroundFillColorTransparent: Color? = nil,
        solidBackgroundFillColorBaseAlt: Color? = nil,
        systemFillColorSuccess: Color? = nil,
        systemFillColorCaution: Color? = nil,
        systemFillColorCritical: Color? = nil,
        systemFillColorNeutral: Color? = nil,
        systemFillColorSolidNeutral: Color? = nil,
        systemFillColorAttentionBackground: Color? = nil,
        systemFillColorSuccessBackground: Color? = nil,
        systemFillColorCautionBackground: Color? = nil,
        systemFillColorCriticalBackground: Color? = nil,
        systemFillColorNeutralBackground: Color? = nil,
        systemFillColorSolidAttentionBackground: Color? = nil,
        systemFillColorSolidNeutralBackground: Color? = nil
    ) -> ResourceDictionary {
        ResourceDictionary(
            textFillColorPrimary: textFillColorPrimary ?? self.textFillColorPrimary,
            textFillColorSecondary: textFillColorSecondary ?? self.textFillColorSecondary,
            textFillColorTertiary: textFillColorTertiary ?? self.textFillColorTertiary,
            textFillColorDisabled: textFillColorDisabled ?? self.textFillColorDisabled,
            textFillColorInverse: textFillColorInverse ?? self.textFillColorInverse,
            accentTextFillColorDisabled: accentTextFillColorDisabled ?? self.accentTextFillColorDisabled,
            textOnAccentFillColorSelectedText: textOnAccentFillColorSelectedText ?? self.textOnAccentFillColorSelectedText,
            textOnAccentFillColorPrimary: textOnAccentFillColorPrimary ?? self.textOnAccentFillColorPrimary,
            textOnAccentFillColorSecondary: textOnAccentFillColorSecondary ?? self.textOnAccentFillColorSecondary,
            textOnAccentFillColorDisabled: textOnAccentFillColorDisabled ?? self.textOnAccentFillColorDisabled,
            controlFillColorDefault: controlFillColorDefault ?? self.controlFillColorDefault,
            controlFillColorSecondary: controlFillColorSecondary ?? self.controlFillColorSecondary,
            controlFillColorTertiary: controlFillColorTertiary ?? self.controlFillColorTertiary,
            controlFillColorQuarternary: controlFillColorQuarternary ?? self.controlFillColorQuarternary,
            controlFillColorDisabled: controlFillColorDisabled ?? self.controlFillColorDisabled,
            controlFillColorTransparent: controlFillColorTransparent ?? self.controlFillColorTransparent,
            controlFillColorInputActive: controlFillColorInputActive ?? self.controlFillColorInputActive,
            controlStrongFillColorDefault: controlStrongFillColorDefault ?? self.controlStrongFillColorDefault,
            controlStrongFillColorDisabled: controlStrongFillColorDisabled ?? self.controlStrongFillColorDisabled,
            controlSolidFillColorDefault: controlSolidFillColorDefault ?? self.controlSolidFillColorDefault,
            subtleFillColorTransparent: subtleFillColorTransparent ?? self.subtleFillColorTransparent,
            subtleFillColorSecondary: subtleFillColorSecondary ?? self.subtleFillColorSecondary,
            subtleFillColorTertiary: subtleFillColorTertiary ?? self.subtleFillColorTertiary,
            subtleFillColorDisabled: subtleFillColorDisabled ?? self.subtleFillColorDisabled,
            controlAltFillColorTransparent: controlAltFillColorTransparent ?? self.controlAltFillColorTransparent,
            controlAltFillColorSecondary: controlAltFillColorSecondary ?? self.controlAltFillColorSecondary,
            controlAltFillColorTertiary: controlAltFillColorTertiary ?? self.controlAltFillColorTertiary,
            controlAltFillColorQuarternary: controlAltFillColorQuarternary ?? self.controlAltFillColorQuarternary,
            controlAltFillColorDisabled: controlAltFillColorDisabled ?? self.controlAltFillColorDisabled,
            controlOnImageFillColorDefault: controlOnImageFillColorDefault ?? self.controlOnImageFillColorDefault,
            controlOnImageFillColorSecondary: controlOnImageFillColorSecondary ?? self.controlOnImageFillColorSecondary,
            controlOnImageFillColorTertiary: controlOnImageFillColorTertiary ?? self.controlOnImageFillColorTertiary,
            controlOnImageFillColorDisabled: controlOnImageFillColorDisabled ?? self.controlOnImageFillColorDisabled,
            accentFillColorDisabled: accentFillColorDisabled ?? self.accentFillColorDisabled,
            controlStrokeColorDefault: controlStrokeColorDefault ?? self.controlStrokeColorDefault,
            controlStrokeColorSecondary: controlStrokeColorSecondary ?? self.controlStrokeColorSecondary,
            controlStrokeColorOnAccentDefault: controlStrokeColorOnAccentDefault ?? self.controlStrokeColorOnAccentDefault,
            controlStrokeColorOnAccentSecondary: controlStrokeColorOnAccentSecondary ?? self.controlStrokeColorOnAccentSecondary,
            controlStrokeColorOnAccentTertiary: controlStrokeColorOnAccentTertiary ?? self.controlStrokeColorOnAccentTertiary,
            controlStrokeColorOnAccentDisabled: controlStrokeColorOnAccentDisabled ?? self.controlStrokeColorOnAccentDisabled,
            controlStrokeColorForStrongFillWhenOnImage: controlStrokeColorForStrongFillWhenOnImage ?? self.controlStrokeColorForStrongFillWhenOnImage,
            cardStrokeColorDefault: cardStrokeColorDefault ?? self.cardStrokeColorDefault,
            cardStrokeColorDefaultSolid: cardStrokeColorDefaultSolid ?? self.cardStrokeColorDefaultSolid,
            controlStrongStrokeColorDefault: controlStrongStrokeColorDefault ?? self.controlStrongStrokeColorDefault,
            controlStrongStrokeColorDisabled: controlStrongStrokeColorDisabled ?? self.controlStrongStrokeColorDisabled,
            surfaceStrokeColorDefault: surfaceStrokeColorDefault ?? self.surfaceStrokeColorDefault,
            surfaceStrokeColorFlyout: surfaceStrokeColorFlyout ?? self.surfaceStrokeColorFlyout,
            surfaceStrokeColorInverse: surfaceStrokeColorInverse ?? self.surfaceStrokeColorInverse,
            dividerStrokeColorDefault: dividerStrokeColorDefault ?? self.dividerStrokeColorDefault,
            focusStrokeColorOuter: focusStrokeColorOuter ?? self.focusStrokeColorOuter,
            focusStrokeColorInner: focusStrokeColorInner ?? self.focusStrokeColorInner,
            cardBackgroundFillColorDefault: cardBackgroundFillColorDefault ?? self.cardBackgroundFillColorDefault,
            cardBackgroundFillColorSecondary: cardBackgroundFillColorSecondary ?? self.cardBackgroundFillColorSecondary,
            cardBackgroundFillColorTertiary: cardBackgroundFillColorTertiary ?? self.cardBackgroundFillColorTertiary,
            smokeFillColorDefault: smokeFillColorDefault ?? self.smokeFillColorDefault,
            layerFillColorDefault: layerFillColorDefault ?? self.layerFillColorDefault,
            layerFillColorAlt: layerFillColorAlt ?? self.layerFillColorAlt,
            layerOnAcrylicFillColorDefault: layerOnAcrylicFillColorDefault ?? self.layerOnAcrylicFillColorDefault,
            layerOnAccentAcrylicFillColorDefault: layerOnAccentAcrylicFillColorDefault ?? self.layerOnAccentAcrylicFillColorDefault,
            layerOnMicaBaseAltFillColorDefault: layerOnMicaBaseAltFillColorDefault ?? self.layerOnMicaBaseAltFillColorDefault,
            layerOnMicaBaseAltFillColorSecondary: layerOnMicaBaseAltFillColorSecondary ?? self.layerOnMicaBaseAltFillColorSecondary,
            layerOnMicaBaseAltFillColorTertiary: layerOnMicaBaseAltFillColorTertiary ?? self.layerOnMicaBaseAltFillColorTertiary,
            layerOnMicaBaseAltFillColorTransparent: layerOnMicaBaseAltFillColorTransparent ?? self.layerOnMicaBaseAltFillColorTransparent,
            solidBackgroundFillColorBase: solidBackgroundFillColorBase ?? self.solidBackgroundFillColorBase,
            solidBackgroundFillColorSecondary: solidBackgroundFillColorSecondary ?? self.solidBackgroundFillColorSecondary,
            solidBackgroundFillColorTertiary: solidBackgroundFillColorTertiary ?? self.solidBackgroundFillColorTertiary,
            solidBackgroundFillColorQuarternary: solidBackgroundFillColorQuarternary ?? self.solidBackgroundFillColorQuarternary,
            solidBackgroundFillColorQuinary: solidBackgroundFillColorQuinary ?? self.solidBackgroundFillColorQuinary,
            solidBackgroundFillColorSenary: solidBackgroundFillColorSenary ?? self.solidBackgroundFillColorSenary,
            solidBackgroundFillColorTransparent: solidBackgroundFillColorTransparent ?? self.solidBackgroundFillColorTransparent,
            solidBackgroundFillColorBaseAlt: solidBackgroundFillColorBaseAlt ?? self.solidBackgroundFillColorBaseAlt,
            systemFillColorSuccess: systemFillColorSuccess ?? self.systemFillColorSuccess,
            systemFillColorCaution: systemFillColorCaution ?? self.systemFillColorCaution,
            systemFillColorCritical: systemFillColorCritical ?? self.systemFillColorCritical,
            systemFillColorNeutral: systemFillColorNeutral ?? self.systemFillColorNeutral,
            systemFillColorSolidNeutral: systemFillColorSolidNeutral ?? self.systemFillColorSolidNeutral,
            systemFillColorAttentionBackground: systemFillColorAttentionBackground ?? self.systemFillColorAttentionBackground,
            systemFillColorSuccessBackground: systemFillColorSuccessBackground ?? self.systemFillColorSuccessBackground,
            systemFillColorCautionBackground: systemFillColorCautionBackground ?? self.systemFillColorCautionBackground,
            systemFillColorCriticalBackground: systemFillColorCriticalBackground ?? self.systemFillColorCriticalBackground,
            systemFillColorNeutralBackground: systemFillColorNeutralBackground ?? self.systemFillColorNeutralBackground,
            systemFillColorSolidAttentionBackground: systemFillColorSolidAttentionBackground ?? self.systemFillColorSolidAttentionBackground,
            systemFillColorSolidNeutralBackground: systemFillColorSolidNeutralBackground ?? self.systemFillColorSolidNeutralBackground
        )
    }

    // MARK: - lerp

    /// Linearly interpolates between two resource dictionaries.
    public static func lerp(_ a: ResourceDictionary, _ b: ResourceDictionary, _ t: Double) -> ResourceDictionary {
        ResourceDictionary(
            textFillColorPrimary: Color.lerp(a.textFillColorPrimary, b.textFillColorPrimary, t)!,
            textFillColorSecondary: Color.lerp(a.textFillColorSecondary, b.textFillColorSecondary, t)!,
            textFillColorTertiary: Color.lerp(a.textFillColorTertiary, b.textFillColorTertiary, t)!,
            textFillColorDisabled: Color.lerp(a.textFillColorDisabled, b.textFillColorDisabled, t)!,
            textFillColorInverse: Color.lerp(a.textFillColorInverse, b.textFillColorInverse, t)!,
            accentTextFillColorDisabled: Color.lerp(a.accentTextFillColorDisabled, b.accentTextFillColorDisabled, t)!,
            textOnAccentFillColorSelectedText: Color.lerp(a.textOnAccentFillColorSelectedText, b.textOnAccentFillColorSelectedText, t)!,
            textOnAccentFillColorPrimary: Color.lerp(a.textOnAccentFillColorPrimary, b.textOnAccentFillColorPrimary, t)!,
            textOnAccentFillColorSecondary: Color.lerp(a.textOnAccentFillColorSecondary, b.textOnAccentFillColorSecondary, t)!,
            textOnAccentFillColorDisabled: Color.lerp(a.textOnAccentFillColorDisabled, b.textOnAccentFillColorDisabled, t)!,
            controlFillColorDefault: Color.lerp(a.controlFillColorDefault, b.controlFillColorDefault, t)!,
            controlFillColorSecondary: Color.lerp(a.controlFillColorSecondary, b.controlFillColorSecondary, t)!,
            controlFillColorTertiary: Color.lerp(a.controlFillColorTertiary, b.controlFillColorTertiary, t)!,
            controlFillColorQuarternary: Color.lerp(a.controlFillColorQuarternary, b.controlFillColorQuarternary, t)!,
            controlFillColorDisabled: Color.lerp(a.controlFillColorDisabled, b.controlFillColorDisabled, t)!,
            controlFillColorTransparent: Color.lerp(a.controlFillColorTransparent, b.controlFillColorTransparent, t)!,
            controlFillColorInputActive: Color.lerp(a.controlFillColorInputActive, b.controlFillColorInputActive, t)!,
            controlStrongFillColorDefault: Color.lerp(a.controlStrongFillColorDefault, b.controlStrongFillColorDefault, t)!,
            controlStrongFillColorDisabled: Color.lerp(a.controlStrongFillColorDisabled, b.controlStrongFillColorDisabled, t)!,
            controlSolidFillColorDefault: Color.lerp(a.controlSolidFillColorDefault, b.controlSolidFillColorDefault, t)!,
            subtleFillColorTransparent: Color.lerp(a.subtleFillColorTransparent, b.subtleFillColorTransparent, t)!,
            subtleFillColorSecondary: Color.lerp(a.subtleFillColorSecondary, b.subtleFillColorSecondary, t)!,
            subtleFillColorTertiary: Color.lerp(a.subtleFillColorTertiary, b.subtleFillColorTertiary, t)!,
            subtleFillColorDisabled: Color.lerp(a.subtleFillColorDisabled, b.subtleFillColorDisabled, t)!,
            controlAltFillColorTransparent: Color.lerp(a.controlAltFillColorTransparent, b.controlAltFillColorTransparent, t)!,
            controlAltFillColorSecondary: Color.lerp(a.controlAltFillColorSecondary, b.controlAltFillColorSecondary, t)!,
            controlAltFillColorTertiary: Color.lerp(a.controlAltFillColorTertiary, b.controlAltFillColorTertiary, t)!,
            controlAltFillColorQuarternary: Color.lerp(a.controlAltFillColorQuarternary, b.controlAltFillColorQuarternary, t)!,
            controlAltFillColorDisabled: Color.lerp(a.controlAltFillColorDisabled, b.controlAltFillColorDisabled, t)!,
            controlOnImageFillColorDefault: Color.lerp(a.controlOnImageFillColorDefault, b.controlOnImageFillColorDefault, t)!,
            controlOnImageFillColorSecondary: Color.lerp(a.controlOnImageFillColorSecondary, b.controlOnImageFillColorSecondary, t)!,
            controlOnImageFillColorTertiary: Color.lerp(a.controlOnImageFillColorTertiary, b.controlOnImageFillColorTertiary, t)!,
            controlOnImageFillColorDisabled: Color.lerp(a.controlOnImageFillColorDisabled, b.controlOnImageFillColorDisabled, t)!,
            accentFillColorDisabled: Color.lerp(a.accentFillColorDisabled, b.accentFillColorDisabled, t)!,
            controlStrokeColorDefault: Color.lerp(a.controlStrokeColorDefault, b.controlStrokeColorDefault, t)!,
            controlStrokeColorSecondary: Color.lerp(a.controlStrokeColorSecondary, b.controlStrokeColorSecondary, t)!,
            controlStrokeColorOnAccentDefault: Color.lerp(a.controlStrokeColorOnAccentDefault, b.controlStrokeColorOnAccentDefault, t)!,
            controlStrokeColorOnAccentSecondary: Color.lerp(a.controlStrokeColorOnAccentSecondary, b.controlStrokeColorOnAccentSecondary, t)!,
            controlStrokeColorOnAccentTertiary: Color.lerp(a.controlStrokeColorOnAccentTertiary, b.controlStrokeColorOnAccentTertiary, t)!,
            controlStrokeColorOnAccentDisabled: Color.lerp(a.controlStrokeColorOnAccentDisabled, b.controlStrokeColorOnAccentDisabled, t)!,
            controlStrokeColorForStrongFillWhenOnImage: Color.lerp(a.controlStrokeColorForStrongFillWhenOnImage, b.controlStrokeColorForStrongFillWhenOnImage, t)!,
            cardStrokeColorDefault: Color.lerp(a.cardStrokeColorDefault, b.cardStrokeColorDefault, t)!,
            cardStrokeColorDefaultSolid: Color.lerp(a.cardStrokeColorDefaultSolid, b.cardStrokeColorDefaultSolid, t)!,
            controlStrongStrokeColorDefault: Color.lerp(a.controlStrongStrokeColorDefault, b.controlStrongStrokeColorDefault, t)!,
            controlStrongStrokeColorDisabled: Color.lerp(a.controlStrongStrokeColorDisabled, b.controlStrongStrokeColorDisabled, t)!,
            surfaceStrokeColorDefault: Color.lerp(a.surfaceStrokeColorDefault, b.surfaceStrokeColorDefault, t)!,
            surfaceStrokeColorFlyout: Color.lerp(a.surfaceStrokeColorFlyout, b.surfaceStrokeColorFlyout, t)!,
            surfaceStrokeColorInverse: Color.lerp(a.surfaceStrokeColorInverse, b.surfaceStrokeColorInverse, t)!,
            dividerStrokeColorDefault: Color.lerp(a.dividerStrokeColorDefault, b.dividerStrokeColorDefault, t)!,
            focusStrokeColorOuter: Color.lerp(a.focusStrokeColorOuter, b.focusStrokeColorOuter, t)!,
            focusStrokeColorInner: Color.lerp(a.focusStrokeColorInner, b.focusStrokeColorInner, t)!,
            cardBackgroundFillColorDefault: Color.lerp(a.cardBackgroundFillColorDefault, b.cardBackgroundFillColorDefault, t)!,
            cardBackgroundFillColorSecondary: Color.lerp(a.cardBackgroundFillColorSecondary, b.cardBackgroundFillColorSecondary, t)!,
            cardBackgroundFillColorTertiary: Color.lerp(a.cardBackgroundFillColorTertiary, b.cardBackgroundFillColorTertiary, t)!,
            smokeFillColorDefault: Color.lerp(a.smokeFillColorDefault, b.smokeFillColorDefault, t)!,
            layerFillColorDefault: Color.lerp(a.layerFillColorDefault, b.layerFillColorDefault, t)!,
            layerFillColorAlt: Color.lerp(a.layerFillColorAlt, b.layerFillColorAlt, t)!,
            layerOnAcrylicFillColorDefault: Color.lerp(a.layerOnAcrylicFillColorDefault, b.layerOnAcrylicFillColorDefault, t)!,
            layerOnAccentAcrylicFillColorDefault: Color.lerp(a.layerOnAccentAcrylicFillColorDefault, b.layerOnAccentAcrylicFillColorDefault, t)!,
            layerOnMicaBaseAltFillColorDefault: Color.lerp(a.layerOnMicaBaseAltFillColorDefault, b.layerOnMicaBaseAltFillColorDefault, t)!,
            layerOnMicaBaseAltFillColorSecondary: Color.lerp(a.layerOnMicaBaseAltFillColorSecondary, b.layerOnMicaBaseAltFillColorSecondary, t)!,
            layerOnMicaBaseAltFillColorTertiary: Color.lerp(a.layerOnMicaBaseAltFillColorTertiary, b.layerOnMicaBaseAltFillColorTertiary, t)!,
            layerOnMicaBaseAltFillColorTransparent: Color.lerp(a.layerOnMicaBaseAltFillColorTransparent, b.layerOnMicaBaseAltFillColorTransparent, t)!,
            solidBackgroundFillColorBase: Color.lerp(a.solidBackgroundFillColorBase, b.solidBackgroundFillColorBase, t)!,
            solidBackgroundFillColorSecondary: Color.lerp(a.solidBackgroundFillColorSecondary, b.solidBackgroundFillColorSecondary, t)!,
            solidBackgroundFillColorTertiary: Color.lerp(a.solidBackgroundFillColorTertiary, b.solidBackgroundFillColorTertiary, t)!,
            solidBackgroundFillColorQuarternary: Color.lerp(a.solidBackgroundFillColorQuarternary, b.solidBackgroundFillColorQuarternary, t)!,
            solidBackgroundFillColorQuinary: Color.lerp(a.solidBackgroundFillColorQuinary, b.solidBackgroundFillColorQuinary, t)!,
            solidBackgroundFillColorSenary: Color.lerp(a.solidBackgroundFillColorSenary, b.solidBackgroundFillColorSenary, t)!,
            solidBackgroundFillColorTransparent: Color.lerp(a.solidBackgroundFillColorTransparent, b.solidBackgroundFillColorTransparent, t)!,
            solidBackgroundFillColorBaseAlt: Color.lerp(a.solidBackgroundFillColorBaseAlt, b.solidBackgroundFillColorBaseAlt, t)!,
            systemFillColorSuccess: Color.lerp(a.systemFillColorSuccess, b.systemFillColorSuccess, t)!,
            systemFillColorCaution: Color.lerp(a.systemFillColorCaution, b.systemFillColorCaution, t)!,
            systemFillColorCritical: Color.lerp(a.systemFillColorCritical, b.systemFillColorCritical, t)!,
            systemFillColorNeutral: Color.lerp(a.systemFillColorNeutral, b.systemFillColorNeutral, t)!,
            systemFillColorSolidNeutral: Color.lerp(a.systemFillColorSolidNeutral, b.systemFillColorSolidNeutral, t)!,
            systemFillColorAttentionBackground: Color.lerp(a.systemFillColorAttentionBackground, b.systemFillColorAttentionBackground, t)!,
            systemFillColorSuccessBackground: Color.lerp(a.systemFillColorSuccessBackground, b.systemFillColorSuccessBackground, t)!,
            systemFillColorCautionBackground: Color.lerp(a.systemFillColorCautionBackground, b.systemFillColorCautionBackground, t)!,
            systemFillColorCriticalBackground: Color.lerp(a.systemFillColorCriticalBackground, b.systemFillColorCriticalBackground, t)!,
            systemFillColorNeutralBackground: Color.lerp(a.systemFillColorNeutralBackground, b.systemFillColorNeutralBackground, t)!,
            systemFillColorSolidAttentionBackground: Color.lerp(a.systemFillColorSolidAttentionBackground, b.systemFillColorSolidAttentionBackground, t)!,
            systemFillColorSolidNeutralBackground: Color.lerp(a.systemFillColorSolidNeutralBackground, b.systemFillColorSolidNeutralBackground, t)!
        )
    }
}
