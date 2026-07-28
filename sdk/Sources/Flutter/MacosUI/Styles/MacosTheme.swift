// macOS theme ported from macos_ui/lib/src/theme/macos_theme.dart

import FlutterSwiftBridge

// MARK: - MacosThemeData

/// Defines the configuration for a macOS-style theme.
///
/// Contains all the colors, typography, and component styling used
/// to create a native macOS look and feel.
public struct MacosThemeData: Equatable {

    /// The overall theme brightness.
    public let brightness: Brightness

    /// A color used on primary interactive elements of the theme.
    public let primaryColor: Color

    /// The default color of scaffold backgrounds.
    public let canvasColor: Color

    /// The default text styling for this theme.
    public let typography: MacosTypography

    /// The color to use for dividers and separators.
    public let dividerColor: Color

    /// The default style for push buttons.
    public let pushButtonTheme: MacosPushButtonThemeData

    /// The default style for icon buttons.
    public let iconButtonTheme: MacosIconButtonThemeData

    /// Theme data for icons.
    public let iconTheme: IconThemeData

    /// The system accent color preference.
    public let accentColor: MacosAccentColor

    /// Whether the app is running in the main (active) window.
    public let isMainWindow: Bool

    // MARK: - Equatable

    public static func == (lhs: MacosThemeData, rhs: MacosThemeData) -> Bool {
        lhs.brightness == rhs.brightness
            && lhs.primaryColor == rhs.primaryColor
            && lhs.canvasColor == rhs.canvasColor
            && lhs.typography == rhs.typography
            && lhs.dividerColor == rhs.dividerColor
            && lhs.pushButtonTheme == rhs.pushButtonTheme
            && lhs.iconButtonTheme == rhs.iconButtonTheme
            && lhs.iconTheme == rhs.iconTheme
            && lhs.accentColor == rhs.accentColor
            && lhs.isMainWindow == rhs.isMainWindow
    }

    // MARK: - Factory

    /// Creates a new MacosThemeData with sensible defaults.
    public init(
        brightness: Brightness? = nil,
        primaryColor: Color? = nil,
        canvasColor: Color? = nil,
        typography: MacosTypography? = nil,
        dividerColor: Color? = nil,
        pushButtonTheme: MacosPushButtonThemeData? = nil,
        iconButtonTheme: MacosIconButtonThemeData? = nil,
        iconTheme: IconThemeData? = nil,
        accentColor: MacosAccentColor? = nil,
        isMainWindow: Bool? = nil
    ) {
        let resolvedBrightness = brightness ?? .light
        let isDark = resolvedBrightness == .dark
        let resolvedAccent = accentColor ?? .blue
        let resolvedIsMainWindow = isMainWindow ?? true

        let resolvedPrimary = primaryColor ?? _MacosColorProvider.primaryColor(
            accentColor: resolvedAccent,
            isDark: isDark,
            isMainWindow: resolvedIsMainWindow
        )

        let resolvedActiveColor = _MacosColorProvider.activeColor(
            accentColor: resolvedAccent,
            isDark: isDark,
            isMainWindow: resolvedIsMainWindow
        )

        self.brightness = resolvedBrightness
        self.primaryColor = resolvedPrimary
        self.accentColor = resolvedAccent
        self.isMainWindow = resolvedIsMainWindow

        self.canvasColor = canvasColor ?? (isDark
            ? Color(rgbo: 40, 40, 40, 1.0)
            : Color(rgbo: 246, 246, 246, 1.0))

        self.typography = typography ?? (isDark
            ? MacosTypography.lightOpaque()
            : MacosTypography.darkOpaque())

        self.dividerColor = dividerColor ?? (isDark
            ? Color(0x1FFFFFFF)
            : Color(0x1F000000))

        self.pushButtonTheme = pushButtonTheme ?? MacosPushButtonThemeData(
            color: resolvedPrimary,
            secondaryColor: isDark
                ? Color(rgbo: 110, 109, 112, 1.0)
                : MacosColors.white,
            disabledColor: isDark
                ? Color(rgbo: 255, 255, 255, 0.1)
                : Color(rgbo: 244, 245, 245, 1.0)
        )

        self.iconButtonTheme = iconButtonTheme ?? MacosIconButtonThemeData(
            backgroundColor: MacosColors.transparent,
            disabledColor: isDark ? Color(0xFF353535) : Color(0xFFE5E5E5),
            hoverColor: isDark ? Color(0xFF333336) : Color(0xFFF3F2F2)
        )

        self.iconTheme = iconTheme ?? IconThemeData(
            size: 20,
            color: resolvedActiveColor
        )
    }

    // MARK: - Raw Init

    /// Creates a MacosThemeData with all values specified directly (no defaults).
    public init(
        brightness: Brightness,
        primaryColor: Color,
        canvasColor: Color,
        typography: MacosTypography,
        dividerColor: Color,
        pushButtonTheme: MacosPushButtonThemeData,
        iconButtonTheme: MacosIconButtonThemeData,
        iconTheme: IconThemeData,
        accentColor: MacosAccentColor,
        isMainWindow: Bool
    ) {
        self.brightness = brightness
        self.primaryColor = primaryColor
        self.canvasColor = canvasColor
        self.typography = typography
        self.dividerColor = dividerColor
        self.pushButtonTheme = pushButtonTheme
        self.iconButtonTheme = iconButtonTheme
        self.iconTheme = iconTheme
        self.accentColor = accentColor
        self.isMainWindow = isMainWindow
    }

    // MARK: - Convenience Factories

    /// Creates a default light theme.
    public static func light(accentColor: MacosAccentColor? = nil) -> MacosThemeData {
        MacosThemeData(brightness: .light, accentColor: accentColor)
    }

    /// Creates a default dark theme.
    public static func dark(accentColor: MacosAccentColor? = nil) -> MacosThemeData {
        MacosThemeData(brightness: .dark, accentColor: accentColor)
    }

    /// The default color theme (light).
    public static func fallback() -> MacosThemeData {
        MacosThemeData.light()
    }

    // MARK: - copyWith

    /// Creates a copy of this theme data with the given fields replaced.
    public func copyWith(
        brightness: Brightness? = nil,
        primaryColor: Color? = nil,
        canvasColor: Color? = nil,
        typography: MacosTypography? = nil,
        dividerColor: Color? = nil,
        pushButtonTheme: MacosPushButtonThemeData? = nil,
        iconButtonTheme: MacosIconButtonThemeData? = nil,
        iconTheme: IconThemeData? = nil,
        accentColor: MacosAccentColor? = nil,
        isMainWindow: Bool? = nil
    ) -> MacosThemeData {
        MacosThemeData(
            brightness: brightness ?? self.brightness,
            primaryColor: primaryColor ?? self.primaryColor,
            canvasColor: canvasColor ?? self.canvasColor,
            typography: self.typography.merge(typography),
            dividerColor: dividerColor ?? self.dividerColor,
            pushButtonTheme: pushButtonTheme ?? self.pushButtonTheme,
            iconButtonTheme: iconButtonTheme ?? self.iconButtonTheme,
            iconTheme: iconTheme ?? self.iconTheme,
            accentColor: accentColor ?? self.accentColor,
            isMainWindow: isMainWindow ?? self.isMainWindow
        )
    }

    // MARK: - lerp

    /// Linearly interpolates between two MacosThemeData objects.
    public static func lerp(_ a: MacosThemeData, _ b: MacosThemeData, _ t: Double) -> MacosThemeData {
        MacosThemeData(
            brightness: t < 0.5 ? a.brightness : b.brightness,
            primaryColor: Color.lerp(a.primaryColor, b.primaryColor, t)!,
            canvasColor: Color.lerp(a.canvasColor, b.canvasColor, t)!,
            typography: MacosTypography.lerp(a.typography, b.typography, t),
            dividerColor: Color.lerp(a.dividerColor, b.dividerColor, t)!,
            pushButtonTheme: a.pushButtonTheme,
            iconButtonTheme: a.iconButtonTheme,
            iconTheme: IconThemeData.lerp(a.iconTheme, b.iconTheme, t),
            accentColor: t < 0.5 ? a.accentColor : b.accentColor,
            isMainWindow: t < 0.5 ? a.isMainWindow : b.isMainWindow
        )
    }
}

// MARK: - Component Theme Data

/// Theme data for push buttons.
public struct MacosPushButtonThemeData: Equatable {
    public let color: Color
    public let secondaryColor: Color
    public let disabledColor: Color

    public init(color: Color, secondaryColor: Color, disabledColor: Color) {
        self.color = color
        self.secondaryColor = secondaryColor
        self.disabledColor = disabledColor
    }
}

/// Theme data for icon buttons.
public struct MacosIconButtonThemeData: Equatable {
    public let backgroundColor: Color
    public let disabledColor: Color
    public let hoverColor: Color

    public init(backgroundColor: Color, disabledColor: Color, hoverColor: Color) {
        self.backgroundColor = backgroundColor
        self.disabledColor = disabledColor
        self.hoverColor = hoverColor
    }
}

// MARK: - MacosTheme (Widget)

/// Applies a macOS-style theme to descendant widgets.
///
/// Use `MacosTheme.of(context)` to access the nearest `MacosThemeData`.
public class MacosTheme: StatelessWidget {
    /// The theme data to apply to descendants.
    public let data: MacosThemeData

    /// The widget below this widget in the tree.
    public let child: Widget

    public init(key: (any Key)? = nil, data: MacosThemeData, child: Widget) {
        self.data = data
        self.child = child
        super.init(key: key)
    }

    /// Returns the MacosThemeData from the closest MacosTheme ancestor.
    ///
    /// Throws if there is no ancestor. Use `maybeOf` if the theme might not exist.
    public static func of(_ context: any BuildContext) -> MacosThemeData {
        let inherited = context.dependOnInheritedWidgetOfExactType(_MacosThemeInherited.self)
        return inherited?.data ?? MacosThemeData.fallback()
    }

    /// Returns the MacosThemeData from the closest MacosTheme ancestor,
    /// or nil if there is no ancestor.
    public static func maybeOf(_ context: any BuildContext) -> MacosThemeData? {
        let inherited = context.dependOnInheritedWidgetOfExactType(_MacosThemeInherited.self)
        return inherited?.data
    }

    /// Retrieves the Brightness from the closest ancestor MacosTheme.
    public static func brightnessOf(_ context: any BuildContext) -> Brightness {
        return of(context).brightness
    }

    public override func build(_ context: any BuildContext) -> Widget {
        return _MacosThemeInherited(
            data: data,
            child: IconTheme(
                data: data.iconTheme,
                child: DefaultTextStyle(style: data.typography.body, child: child)
            )
        )
    }
}

// MARK: - _MacosThemeInherited

internal class _MacosThemeInherited: InheritedTheme {
    let data: MacosThemeData

    init(key: (any Key)? = nil, data: MacosThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? _MacosThemeInherited else { return true }
        return old.data != data
    }

    override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return _MacosThemeInherited(data: data, child: child)
    }
}

// MARK: - AnimatedMacosTheme

/// Animates the transition between MacosThemeData values.
public class AnimatedMacosTheme: StatefulWidget {
    public let data: MacosThemeData
    public let child: Widget
    public let curve: any Curve

    public init(
        key: (any Key)? = nil,
        data: MacosThemeData,
        child: Widget,
        curve: (any Curve)? = nil
    ) {
        self.data = data
        self.child = child
        self.curve = curve ?? Curves.linear
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedMacosThemeState()
    }
}

class _AnimatedMacosThemeState: State<StatefulWidget> {
    private var app: AnimatedMacosTheme {
        return widget as! AnimatedMacosTheme
    }

    override func build(_ context: any BuildContext) -> Widget {
        return MacosTheme(data: app.data, child: app.child)
    }
}
