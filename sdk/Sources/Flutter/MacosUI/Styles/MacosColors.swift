// macOS UI color definitions ported from macos_ui/lib/src/theme/macos_colors.dart

import FlutterSwiftBridge

// MARK: - MacosAccentColor

/// The macOS accent color which can be changed by the user in System Settings.
public enum MacosAccentColor: CaseIterable, Sendable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite
}

// MARK: - ControlSize

/// The out-of-the-box sizes that certain macOS control widgets can be.
public enum ControlSize: Sendable {
    case mini
    case small
    case regular
    case large
}

// MARK: - MacosColors

/// A collection of color values from the macOS system color picker.
///
/// Ported from the macOS Human Interface Guidelines color definitions.
public enum MacosColors {

    // MARK: - Base Colors

    public static let transparent = Color(0x00000000)
    public static let black = Color(0xFF000000)
    public static let white = Color(0xFFFFFFFF)

    // MARK: - Label Colors

    /// The text of a label containing primary content.
    public static func labelColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.85)
            : Color(rgbo: 255, 255, 255, 0.85)
    }

    /// The text of a label of lesser importance than a primary label.
    public static func secondaryLabelColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.5)
            : Color(rgbo: 255, 255, 255, 0.55)
    }

    /// The text of a label of lesser importance than a secondary label.
    public static func tertiaryLabelColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.26)
            : Color(rgbo: 255, 255, 255, 0.26)
    }

    /// The text of a label of lesser importance than a tertiary label.
    public static func quaternaryLabelColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.1)
            : Color(rgbo: 255, 255, 255, 0.1)
    }

    // MARK: - System Colors

    public static func systemRed(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFFF3B30) : Color(0xFFFF453A)
    }

    public static func systemGreen(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF34C759) : Color(0xFF30D158)
    }

    public static func systemBlue(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF007AFF) : Color(0xFF0A84FF)
    }

    public static func systemOrange(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFFF9500) : Color(0xFFFF9F0A)
    }

    public static func systemYellow(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFFF9F0A) : Color(0xFFFFD60A)
    }

    public static func systemBrown(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFA2845E) : Color(0xFFAC8E68)
    }

    public static func systemPink(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFFF2D55) : Color(0xFFFF375F)
    }

    public static func systemPurple(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFAF52DE) : Color(0xFFBF5AF2)
    }

    public static func systemTeal(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF55BEF0) : Color(0xFF5AC8F5)
    }

    public static func systemIndigo(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF5856D6) : Color(0xFF5E5CE6)
    }

    public static func systemGray(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF8E8E93) : Color(0xFF98989D)
    }

    // MARK: - Semantic Colors

    /// A link to other content.
    public static func linkColor(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFF0068DA) : Color(rgbo: 65, 156, 255, 1)
    }

    /// A placeholder string in a control or text view.
    public static let placeholderTextColor = Color(0xFF737473)

    public static let windowFrameColor = Color(0xFFDDDDDE)

    /// The text of a selected menu.
    public static let selectedMenuItemTextColor = Color(0xFFFEFFFF)

    /// The text on a selected surface in a list or table.
    public static let alternateSelectedControlTextColor = white

    /// The text of a header cell in a table.
    public static let headerTextColor = white

    /// A separator between different sections of content.
    public static let separatorColor = Color(0xFF39373C)

    /// The gridlines of an interface element such as a table.
    public static let gridColor = Color(0xFF39373C)

    /// The text in a document.
    public static let textColor = white

    /// Text background.
    public static let textBackgroundColor = Color(0xFF1E1E1E)

    /// Selected text.
    public static let selectedTextColor = white

    /// The background of selected text.
    public static let selectedTextBackgroundColor = Color(0xFF3F638B)

    /// A background for selected text in a non-key window or view.
    public static func unemphasizedSelectedTextBackgroundColor(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFDCDCDC) : Color(0xFF464646)
    }

    /// The background of a window.
    public static let windowBackgroundColor = Color(0xFF3B373D)

    /// The background behind a document's content.
    public static let underPageBackgroundColor = Color(0xFF282828)

    /// The background of a large interface element, such as a browser or table.
    public static func controlBackgroundColor(for brightness: Brightness) -> Color {
        brightness == .light ? Color(0xFFFFFFFF) : Color(0xFF1E1E1E)
    }

    public static let selectedControlBackgroundColor = Color(0xFF0058D0)

    /// The selected content in a non-key window or view.
    public static let unemphasizedSelectedContentBackgroundColor = Color(0xFF464646)

    public static let alternatingContentBackgroundColor = Color(0xFF2E2C31)

    /// The color of a find indicator.
    public static let findHighlightColor = Color(0xFFFFFF00)

    /// The surface of a control.
    public static func controlColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.1)
            : Color(rgbo: 255, 255, 255, 0.25)
    }

    /// The text of a control that isn't disabled.
    public static func controlTextColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.85)
            : Color(0xFFDDDDDE)
    }

    /// The text of a control that's disabled.
    public static func disabledControlTextColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.25)
            : Color(rgbo: 255, 255, 255, 0.25)
    }

    /// The surface of a selected control.
    public static func selectedControlColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 179, 215, 255, 1)
            : Color(rgbo: 63, 99, 139, 1)
    }

    /// The ring that appears around the currently focused control.
    public static func keyboardFocusIndicatorColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 103, 244, 0.25)
            : Color(rgbo: 26, 169, 255, 0.3)
    }

    /// The color of the slider thumb.
    public static func sliderThumbColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 255, 255, 255, 1)
            : Color(rgbo: 152, 152, 157, 1)
    }

    /// The color of slider tick marks that are not selected.
    public static func tickBackgroundColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 220, 220, 220, 1)
            : Color(rgbo: 70, 70, 70, 1)
    }

    /// The color of the unselected portion of the slider.
    public static func sliderBackgroundColor(for brightness: Brightness) -> Color {
        brightness == .light
            ? Color(rgbo: 0, 0, 0, 0.1)
            : Color(rgbo: 255, 255, 255, 0.1)
    }

    /// The accent color selected by the user in system preferences.
    public static let controlAccentColor = Color(rgbo: 0, 122, 255, 1)

    // MARK: - Apple Named Colors

    public static let appleBlue = Color(0xFF0433FF)
    public static let appleBrown = Color(0xFFAA7942)
    public static let appleCyan = Color(0xFF00FDFF)
    public static let appleGreen = Color(0xFF00F900)
    public static let appleMagenta = Color(0xFFFF40FF)
    public static let appleOrange = Color(0xFFFF9300)
    public static let applePurple = Color(0xFF942192)
    public static let appleRed = Color(0xFFFF2600)
    public static let appleYellow = Color(0xFFFFFB00)
}

// MARK: - _MacosColorProvider

/// Provides accent-based primary and active colors for theming.
internal enum _MacosColorProvider {

    /// Returns the primary color based on accent color, dark mode, and window state.
    static func primaryColor(
        accentColor: MacosAccentColor,
        isDark: Bool,
        isMainWindow: Bool
    ) -> Color {
        if isDark {
            if !isMainWindow {
                return Color(rgbo: 100, 100, 100, 0.625)
            }
            switch accentColor {
            case .blue:     return Color(rgbo: 29, 151, 255, 1.0)
            case .purple:   return Color(rgbo: 204, 118, 207, 1.0)
            case .pink:     return Color(rgbo: 255, 114, 194, 1.0)
            case .red:      return Color(rgbo: 225, 118, 124, 1.0)
            case .orange:   return Color(rgbo: 255, 147, 44, 1.0)
            case .yellow:   return Color(rgbo: 255, 220, 24, 1.0)
            case .green:    return Color(rgbo: 114, 202, 87, 1.0)
            case .graphite: return Color(rgbo: 152, 152, 152, 1.0)
            }
        }

        if !isMainWindow {
            return Color(rgbo: 190, 190, 190, 1.0)
        }

        switch accentColor {
        case .blue:     return Color(rgbo: 0, 88, 224, 1.0)
        case .purple:   return Color(rgbo: 131, 44, 134, 1.0)
        case .pink:     return Color(rgbo: 212, 45, 126, 1.0)
        case .red:      return Color(rgbo: 203, 45, 43, 1.0)
        case .orange:   return Color(rgbo: 198, 82, 0, 1.0)
        case .yellow:   return Color(rgbo: 206, 154, 2, 1.0)
        case .green:    return Color(rgbo: 56, 146, 30, 1.0)
        case .graphite: return Color(rgbo: 100, 100, 100, 1.0)
        }
    }

    /// Returns the active/selection color based on accent color, dark mode, and window state.
    static func activeColor(
        accentColor: MacosAccentColor,
        isDark: Bool,
        isMainWindow: Bool
    ) -> Color {
        if isDark {
            if !isMainWindow {
                return Color(rgbo: 76, 78, 65, 1.0)
            }
            switch accentColor {
            case .blue:     return Color(rgbo: 22, 105, 229, 0.749)
            case .purple:   return Color(rgbo: 204, 45, 202, 0.749)
            case .pink:     return Color(rgbo: 229, 74, 145, 0.749)
            case .red:      return Color(rgbo: 238, 64, 68, 0.749)
            case .orange:   return Color(rgbo: 244, 114, 0, 0.749)
            case .yellow:   return Color(rgbo: 233, 176, 0, 0.749)
            case .green:    return Color(rgbo: 76, 177, 45, 0.749)
            case .graphite: return Color(rgbo: 129, 129, 122, 0.824)
            }
        }

        if !isMainWindow {
            return Color(rgbo: 180, 180, 180, 1.0)
        }

        switch accentColor {
        case .blue:     return Color(rgbo: 9, 129, 255, 0.749)
        case .purple:   return Color(rgbo: 162, 28, 165, 0.749)
        case .pink:     return Color(rgbo: 234, 81, 152, 0.749)
        case .red:      return Color(rgbo: 220, 32, 40, 0.749)
        case .orange:   return Color(rgbo: 245, 113, 0, 0.749)
        case .yellow:   return Color(rgbo: 240, 180, 2, 0.749)
        case .green:    return Color(rgbo: 66, 174, 33, 0.749)
        case .graphite: return Color(rgbo: 174, 174, 167, 0.847)
        }
    }
}
