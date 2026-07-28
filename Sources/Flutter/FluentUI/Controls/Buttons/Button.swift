// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/buttons/button.dart

import FlutterSwiftBridge

/// The default padding applied to fluent-styled buttons.
///
/// This matches the padding used by WinUI button controls.
public let kDefaultButtonPadding = EdgeInsets(
    left: 11, top: 5, right: 11, bottom: 6
)

// MARK: - Button

/// A standard button control that triggers an immediate action when clicked.
///
/// The `Button` widget is the most common type of button in Windows applications.
/// It has a neutral appearance with a subtle background that responds to hover,
/// press, and focus states.
public class Button: BaseButton {

    /// Creates a standard button.
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
    }

    override public func themeStyleOf(_ context: any BuildContext) -> ButtonStyle? {
        return ButtonTheme.of(context).defaultButtonStyle
    }
}
