// Ported from: fluent_ui/lib/src/fluent_app.dart

import FlutterSwiftBridge

// MARK: - ThemeMode

/// Describes which theme will be used by [FluentApp].
public enum ThemeMode {
    /// Use the light or dark theme based on what the system reports.
    case system

    /// Always use the light theme.
    case light

    /// Always use the dark theme.
    case dark
}

// MARK: - FluentApp

/// An application that uses Windows (Fluent) design.
///
/// A convenience widget that wraps a number of widgets commonly required for
/// Fluent Design applications. It resolves the active theme based on
/// [themeMode] and wraps the [home] widget with [AnimatedFluentTheme],
/// [IconTheme], and [DefaultTextStyle].
///
/// Simplified port: routing, localizations, scroll behavior, hero controller,
/// and Material interop are omitted. The widget focuses on theme resolution
/// and composition.
public class FluentApp: StatefulWidget {

    /// Default visual properties for this app's Fluent widgets.
    ///
    /// When both [theme] and [darkTheme] are provided, [themeMode] controls
    /// which one is used. Defaults to a light theme when nil.
    public let theme: FluentThemeData?

    /// The [FluentThemeData] to use when a dark mode is active.
    ///
    /// Falls back to [theme] when nil.
    public let darkTheme: FluentThemeData?

    /// Determines which theme will be used if both [theme] and [darkTheme]
    /// are provided.
    ///
    /// Defaults to [ThemeMode.system].
    public let themeMode: ThemeMode

    /// The primary content of the application.
    public let home: Widget

    /// A short description of the application, used as the window title.
    public let title: String

    public init(
        key: (any Key)? = nil,
        theme: FluentThemeData? = nil,
        darkTheme: FluentThemeData? = nil,
        themeMode: ThemeMode = .system,
        home: Widget,
        title: String = ""
    ) {
        self.theme = theme
        self.darkTheme = darkTheme
        self.themeMode = themeMode
        self.home = home
        self.title = title
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _FluentAppState()
    }
}

// MARK: - _FluentAppState

class _FluentAppState: State<StatefulWidget> {

    private var app: FluentApp {
        return widget as! FluentApp
    }

    /// Resolves the active theme based on [themeMode] and platform brightness.
    private func resolveTheme() -> FluentThemeData {
        let mode = app.themeMode

        // In a full implementation we would query MediaQuery.platformBrightnessOf
        // to detect the system preference. Since MediaQuery is not yet available
        // in flutter_swift, ThemeMode.system falls back to the light theme.
        let useDarkStyle: Bool
        switch mode {
        case .dark:
            useDarkStyle = true
        case .light:
            useDarkStyle = false
        case .system:
            // Fallback: no MediaQuery, default to light.
            useDarkStyle = false
        }

        if useDarkStyle {
            return app.darkTheme ?? app.theme ?? FluentThemeData(brightness: .dark)
        } else {
            return app.theme ?? FluentThemeData(brightness: .light)
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        let themeData = resolveTheme()

        return Directionality(
            textDirection: .ltr,
            child: AnimatedFluentTheme(
                data: themeData,
                // Navigator (with its own Overlay) so that showDialog /
                // Navigator.push work inside Fluent apps.
                child: Navigator(home: self.app.home),
                curve: themeData.animationCurve
            )
        )
    }
}
