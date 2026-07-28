// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/buttons/theme.dart

import FlutterSwiftBridge

// MARK: - ButtonStyle

/// Defines the visual properties for a Fluent UI button widget.
///
/// Used to style buttons like `Button`, `FilledButton`, `HyperlinkButton`,
/// and `IconButton`.
public class ButtonStyle {

    /// The text style for the button's child text widgets.
    public let textStyle: (any WidgetStateProperty<TextStyle?>)?

    /// The background color of the button.
    public let backgroundColor: (any WidgetStateProperty<Color?>)?

    /// The foreground color of the button (text and icon color).
    public let foregroundColor: (any WidgetStateProperty<Color?>)?

    /// The shadow color for the button's elevation.
    public let shadowColor: (any WidgetStateProperty<Color?>)?

    /// The elevation of the button.
    public let elevation: (any WidgetStateProperty<Double?>)?

    /// The padding inside the button.
    public let padding: (any WidgetStateProperty<EdgeInsets?>)?

    /// The shape of the button.
    public let shape: (any WidgetStateProperty<(any ShapeBorder)?>)?

    /// The size of icons within the button.
    public let iconSize: (any WidgetStateProperty<Double?>)?

    /// Creates a button style.
    public init(
        textStyle: (any WidgetStateProperty<TextStyle?>)? = nil,
        backgroundColor: (any WidgetStateProperty<Color?>)? = nil,
        foregroundColor: (any WidgetStateProperty<Color?>)? = nil,
        shadowColor: (any WidgetStateProperty<Color?>)? = nil,
        elevation: (any WidgetStateProperty<Double?>)? = nil,
        padding: (any WidgetStateProperty<EdgeInsets?>)? = nil,
        shape: (any WidgetStateProperty<(any ShapeBorder)?>)? = nil,
        iconSize: (any WidgetStateProperty<Double?>)? = nil
    ) {
        self.textStyle = textStyle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shadowColor = shadowColor
        self.elevation = elevation
        self.padding = padding
        self.shape = shape
        self.iconSize = iconSize
    }

    /// Merges this `ButtonStyle` with another, with the other taking precedence.
    public func merge(_ other: ButtonStyle?) -> ButtonStyle {
        guard let other = other else { return self }
        return ButtonStyle(
            textStyle: other.textStyle ?? textStyle,
            backgroundColor: other.backgroundColor ?? backgroundColor,
            foregroundColor: other.foregroundColor ?? foregroundColor,
            shadowColor: other.shadowColor ?? shadowColor,
            elevation: other.elevation ?? elevation,
            padding: other.padding ?? padding,
            shape: other.shape ?? shape,
            iconSize: other.iconSize ?? iconSize
        )
    }

    /// Creates a copy of this `ButtonStyle` with the given fields replaced.
    public func copyWith(
        textStyle: (any WidgetStateProperty<TextStyle?>)? = nil,
        backgroundColor: (any WidgetStateProperty<Color?>)? = nil,
        foregroundColor: (any WidgetStateProperty<Color?>)? = nil,
        shadowColor: (any WidgetStateProperty<Color?>)? = nil,
        elevation: (any WidgetStateProperty<Double?>)? = nil,
        padding: (any WidgetStateProperty<EdgeInsets?>)? = nil,
        shape: (any WidgetStateProperty<(any ShapeBorder)?>)? = nil,
        iconSize: (any WidgetStateProperty<Double?>)? = nil
    ) -> ButtonStyle {
        return ButtonStyle(
            textStyle: textStyle ?? self.textStyle,
            backgroundColor: backgroundColor ?? self.backgroundColor,
            foregroundColor: foregroundColor ?? self.foregroundColor,
            shadowColor: shadowColor ?? self.shadowColor,
            elevation: elevation ?? self.elevation,
            padding: padding ?? self.padding,
            shape: shape ?? self.shape,
            iconSize: iconSize ?? self.iconSize
        )
    }
}

// MARK: - ButtonThemeData

/// Theme data for button widgets.
///
/// This class defines the default styles for different button types in the
/// Fluent UI design system.
public class ButtonThemeData {

    /// The style for default `Button` widgets.
    public let defaultButtonStyle: ButtonStyle?

    /// The style for `FilledButton` widgets.
    public let filledButtonStyle: ButtonStyle?

    /// The style for `HyperlinkButton` widgets.
    public let hyperlinkButtonStyle: ButtonStyle?

    /// The style for outlined button widgets.
    public let outlinedButtonStyle: ButtonStyle?

    /// The style for `IconButton` widgets.
    public let iconButtonStyle: ButtonStyle?

    /// Creates button theme data with optional styles for each button type.
    public init(
        defaultButtonStyle: ButtonStyle? = nil,
        filledButtonStyle: ButtonStyle? = nil,
        hyperlinkButtonStyle: ButtonStyle? = nil,
        outlinedButtonStyle: ButtonStyle? = nil,
        iconButtonStyle: ButtonStyle? = nil
    ) {
        self.defaultButtonStyle = defaultButtonStyle
        self.filledButtonStyle = filledButtonStyle
        self.hyperlinkButtonStyle = hyperlinkButtonStyle
        self.outlinedButtonStyle = outlinedButtonStyle
        self.iconButtonStyle = iconButtonStyle
    }

    /// Creates button theme data with the same style for all button types.
    public convenience init(all style: ButtonStyle?) {
        self.init(
            defaultButtonStyle: style,
            filledButtonStyle: style,
            hyperlinkButtonStyle: style,
            outlinedButtonStyle: style,
            iconButtonStyle: style
        )
    }

    /// Merges this `ButtonThemeData` with another, with the other taking precedence.
    public func merge(_ other: ButtonThemeData?) -> ButtonThemeData {
        guard let other = other else { return self }
        return ButtonThemeData(
            defaultButtonStyle: other.defaultButtonStyle ?? defaultButtonStyle,
            filledButtonStyle: other.filledButtonStyle ?? filledButtonStyle,
            hyperlinkButtonStyle: other.hyperlinkButtonStyle ?? hyperlinkButtonStyle,
            outlinedButtonStyle: other.outlinedButtonStyle ?? outlinedButtonStyle,
            iconButtonStyle: other.iconButtonStyle ?? iconButtonStyle
        )
    }

    /// Defines the default background color used by buttons based on state.
    public static func buttonColor(
        _ context: any BuildContext,
        _ states: Set<WidgetState>,
        transparentWhenNone: Bool = false
    ) -> Color {
        let res = FluentTheme.of(context).resources
        if states.isPressed {
            return res.controlFillColorTertiary
        } else if states.isHovered {
            return res.controlFillColorSecondary
        } else if states.isDisabled {
            return res.controlFillColorDisabled
        }
        return transparentWhenNone
            ? res.subtleFillColorTransparent
            : res.controlFillColorDefault
    }

    /// Defines the default foreground color used by buttons based on state.
    public static func buttonForegroundColor(
        _ context: any BuildContext,
        _ states: Set<WidgetState>
    ) -> Color {
        let res = FluentTheme.of(context).resources
        if states.isPressed {
            return res.textFillColorSecondary
        } else if states.isDisabled {
            return res.textFillColorDisabled
        }
        return res.textFillColorPrimary
    }

    /// Returns the default shape border for buttons based on the current state.
    public static func shapeBorder(
        _ context: any BuildContext,
        _ states: Set<WidgetState>
    ) -> any ShapeBorder {
        let theme = FluentTheme.of(context)
        if states.isPressed || states.isDisabled {
            return RoundedRectangleBorder(
                side: BorderSide(color: theme.resources.controlStrokeColorDefault),
                borderRadius: BorderRadius.circular(4)
            )
        } else {
            // Simplified: use a plain rounded rect border since gradient borders
            // require RoundedRectangleGradientBorder which may not be available.
            return RoundedRectangleBorder(
                side: BorderSide(color: theme.resources.controlStrokeColorDefault),
                borderRadius: BorderRadius.circular(4)
            )
        }
    }
}

// MARK: - ButtonTheme

/// An inherited widget that defines the configuration for buttons
/// in this widget's subtree.
///
/// Values specified here are used for button properties that are not
/// given an explicit non-null value.
public class ButtonTheme: InheritedTheme {

    /// The properties for descendant button widgets.
    public let data: ButtonThemeData

    /// Creates a theme that controls how descendant buttons should look.
    public init(key: (any Key)? = nil, data: ButtonThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest `ButtonThemeData` which encloses the given context.
    ///
    /// Looks for a `ButtonTheme` ancestor. If none is found, returns an empty
    /// `ButtonThemeData`.
    public static func of(_ context: any BuildContext) -> ButtonThemeData {
        let inheritedTheme = context.dependOnInheritedWidgetOfExactType(ButtonTheme.self)
        return inheritedTheme?.data ?? ButtonThemeData()
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return ButtonTheme(data: data, child: child)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? ButtonTheme else { return true }
        return data !== old.data
    }
}
