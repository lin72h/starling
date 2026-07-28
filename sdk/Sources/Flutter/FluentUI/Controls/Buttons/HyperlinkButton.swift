// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/buttons/hyperlink_button.dart

import FlutterSwiftBridge

// MARK: - HyperlinkButton

/// A borderless button styled like a hyperlink.
///
/// The `HyperlinkButton` is used for less prominent actions or for inline
/// actions within text. It has a transparent background and displays text
/// in the accent color, similar to a web hyperlink.
public class HyperlinkButton: BaseButton {

    /// Creates a hyperlink button.
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

        return ButtonStyle(
            textStyle: WidgetStatePropertyAll(
                TextStyle(fontWeight: .w600, letterSpacing: 0.5)
            ),
            backgroundColor: _WidgetStatePropertyWith<Color?> { states in
                return HyperlinkButton.resolveBackgroundColor(theme, states)
            },
            foregroundColor: _WidgetStatePropertyWith<Color?> { states in
                if states.isDisabled {
                    return theme.resources.controlFillColorDisabled
                } else if states.isPressed {
                    return theme.accentColor.tertiaryBrushFor(theme.brightness)
                } else if states.isHovered {
                    return theme.accentColor.secondaryBrushFor(theme.brightness)
                } else {
                    return theme.accentColor.defaultBrushFor(theme.brightness)
                }
            },
            padding: WidgetStatePropertyAll(kDefaultButtonPadding),
            shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
            )
        )
    }

    override public func themeStyleOf(_ context: any BuildContext) -> ButtonStyle? {
        return ButtonTheme.of(context).hyperlinkButtonStyle
    }

    /// Returns the background color for a hyperlink button based on its state.
    public static func resolveBackgroundColor(_ theme: FluentThemeData, _ states: Set<WidgetState>) -> Color {
        let res = theme.resources
        if states.isDisabled {
            return res.subtleFillColorDisabled
        } else if states.isPressed {
            return res.subtleFillColorTertiary
        } else if states.isHovered {
            return res.subtleFillColorSecondary
        } else {
            return res.subtleFillColorTransparent
        }
    }
}
