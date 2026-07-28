// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/buttons/icon_button.dart

import FlutterSwiftBridge

// MARK: - IconButtonMode

/// The size mode for an `IconButton`.
///
/// This determines the overall size and padding of the icon button.
public enum IconButtonMode {
    /// A very small icon button, typically used in compact UI areas.
    case tiny
    /// A small icon button, suitable for toolbars and dense layouts.
    case small
    /// A large icon button with more padding, the default size.
    case large
}

// MARK: - IconButton

/// A button that displays only an icon.
///
/// Icon buttons are commonly used in toolbars, app bars, and other places where
/// space is limited and the icon alone is sufficient to convey the action.
public class IconButton: BaseButton {

    /// How this icon button will behave.
    ///
    /// If nil, defaults to large.
    public let iconButtonMode: IconButtonMode?

    /// Creates an icon button.
    ///
    /// The `icon` is typically an `Icon` widget.
    public init(
        key: (any Key)? = nil,
        icon: Widget,
        onPressed: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapUp: (() -> Void)? = nil,
        style: ButtonStyle? = nil,
        focusable: Bool = true,
        autofocus: Bool = false,
        iconButtonMode: IconButtonMode? = nil
    ) {
        self.iconButtonMode = iconButtonMode
        super.init(
            key: key,
            onPressed: onPressed,
            onLongPress: onLongPress,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            style: style,
            focusable: focusable,
            autofocus: autofocus,
            child: icon
        )
    }

    override public func defaultStyleOf(_ context: any BuildContext) -> ButtonStyle {
        let theme = FluentTheme.of(context)
        let isIconSmall = iconButtonMode == .tiny
        let isSmall = iconButtonMode != nil ? iconButtonMode != .large : false

        return ButtonStyle(
            backgroundColor: _WidgetStatePropertyWith<Color?> { [self] states in
                if states.isDisabled {
                    return ButtonThemeData.buttonColor(context, states)
                } else {
                    return self.uncheckedInputColor(theme, states, transparentWhenNone: true)
                }
            },
            foregroundColor: _WidgetStatePropertyWith<Color?> { states in
                if states.isDisabled {
                    return theme.resources.textFillColorDisabled
                }
                return nil
            },
            padding: WidgetStatePropertyAll(
                isSmall
                    ? kDefaultButtonPadding
                    : EdgeInsets(all: 8)
            ),
            shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
            ),
            iconSize: WidgetStatePropertyAll(isIconSmall ? 11.0 : nil)
        )
    }

    override public func themeStyleOf(_ context: any BuildContext) -> ButtonStyle? {
        return ButtonTheme.of(context).iconButtonStyle
    }

    /// Returns the background color for unchecked input controls.
    private func uncheckedInputColor(
        _ theme: FluentThemeData,
        _ states: Set<WidgetState>,
        transparentWhenNone: Bool = false
    ) -> Color {
        let res = theme.resources
        if states.isDisabled {
            return res.controlAltFillColorDisabled
        }
        if states.isPressed {
            return res.subtleFillColorTertiary
        }
        if states.isHovered {
            return res.subtleFillColorSecondary
        }
        return transparentWhenNone
            ? res.subtleFillColorTransparent
            : res.controlAltFillColorSecondary
    }
}
