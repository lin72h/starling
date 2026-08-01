// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/buttons/filled_button.dart

import FlutterSwiftBridge

// MARK: - FilledButton

/// An accent-colored button used for primary or most important actions.
///
/// The `FilledButton` has a filled background using the app's accent color,
/// making it stand out as the primary action in a dialog or page.
public class FilledButton: BaseButton {

    /// Creates a filled button.
    public override init(
        key: (any Key)? = nil,
        onPressed: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapUp: (() -> Void)? = nil,
        style: ButtonStyle? = nil,
        focusable: Bool = true,
        autofocus: Bool = false,
        child: Widget
    ) {
        super.init(
            key: key,
            onPressed: onPressed,
            onLongPress: onLongPress,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            style: style,
            focusable: focusable,
            autofocus: autofocus,
            child: child
        )
    }

    override public func defaultStyleOf(_ context: any BuildContext) -> ButtonStyle {
        let theme = FluentTheme.of(context)

        // Build the base style from a standard button first
        let baseStyle = ButtonStyle(
            backgroundColor: _WidgetStatePropertyWith<Color?> { states in
                return ButtonThemeData.buttonColor(context, states)
            },
            foregroundColor: _WidgetStatePropertyWith<Color?> { states in
                return ButtonThemeData.buttonForegroundColor(context, states)
            },
            shadowColor: WidgetStatePropertyAll(theme.shadowColor),
            padding: WidgetStatePropertyAll(kDefaultButtonPadding),
            shape: _WidgetStatePropertyWith<(any ShapeBorder)?> { states in
                return ButtonThemeData.shapeBorder(context, states)
            }
        )

        let filledStyle = ButtonStyle(
            backgroundColor: _WidgetStatePropertyWith<Color?> { states in
                return FilledButton.backgroundColor(theme, states)
            },
            foregroundColor: _WidgetStatePropertyWith<Color?> { states in
                return FilledButton.foregroundColor(theme, states)
            },
            shape: _WidgetStatePropertyWith<(any ShapeBorder)?> { states in
                return FilledButton.shapeBorder(theme, states)
            }
        )

        return baseStyle.merge(filledStyle)
    }

    override public func themeStyleOf(_ context: any BuildContext) -> ButtonStyle? {
        return ButtonTheme.of(context).filledButtonStyle
    }

    /// Returns the background color for a filled button based on its state.
    public static func backgroundColor(_ theme: FluentThemeData, _ states: Set<WidgetState>) -> Color {
        if states.isDisabled {
            return theme.resources.accentFillColorDisabled
        } else if states.isPressed {
            return theme.accentColor.tertiaryBrushFor(theme.brightness)
        } else if states.isHovered {
            return theme.accentColor.secondaryBrushFor(theme.brightness)
        } else {
            return theme.accentColor.defaultBrushFor(theme.brightness)
        }
    }

    /// Returns the foreground color for a filled button based on its state.
    public static func foregroundColor(_ theme: FluentThemeData, _ states: Set<WidgetState>) -> Color {
        let res = theme.resources
        if states.isPressed {
            return res.textOnAccentFillColorSecondary
        } else if states.isHovered {
            return res.textOnAccentFillColorPrimary
        } else if states.isDisabled {
            return res.textOnAccentFillColorDisabled
        }
        return res.textOnAccentFillColorPrimary
    }

    /// Returns the shape border for a filled button based on its state.
    public static func shapeBorder(_ theme: FluentThemeData, _ states: Set<WidgetState>) -> any ShapeBorder {
        if states.isPressed || states.isDisabled {
            return RoundedRectangleBorder(
                side: BorderSide(color: theme.resources.controlFillColorTransparent),
                borderRadius: BorderRadius.circular(4)
            )
        } else {
            return RoundedRectangleBorder(
                side: BorderSide(color: theme.resources.controlStrokeColorOnAccentDefault),
                borderRadius: BorderRadius.circular(4)
            )
        }
    }
}
