// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/inputs/toggle_button.dart

import FlutterSwiftBridge

// MARK: - ToggleButton

/// A button that can be on or off.
///
/// When checked, it appears as a `FilledButton` (accent background).
/// When unchecked, it appears as a standard `Button`.
public class ToggleButton: StatelessWidget {

    /// Whether this toggle button is checked.
    public let checked: Bool

    /// Called when the toggle button's value should change.
    public let onChanged: ((Bool) -> Void)?

    /// The content of the button.
    public let child: Widget?

    /// The style of the button.
    public let style: ToggleButtonThemeData?

    /// Whether to autofocus this button.
    public let autofocus: Bool

    /// Creates a toggle button.
    public init(
        key: (any Key)? = nil,
        checked: Bool,
        onChanged: ((Bool) -> Void)? = nil,
        child: Widget? = nil,
        style: ToggleButtonThemeData? = nil,
        autofocus: Bool = false
    ) {
        self.checked = checked
        self.onChanged = onChanged
        self.child = child
        self.style = style
        self.autofocus = autofocus
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = ToggleButtonTheme.of(context).merge(style)
        let buttonStyle = checked ? theme.checkedButtonStyle : theme.uncheckedButtonStyle
        let onPressedAction: (() -> Void)? = onChanged == nil ? nil : { [checked, onChanged] in
            onChanged!(!checked)
        }
        let content: Widget = child ?? SizedBox(width: 0, height: 0)
        return Button(
            onPressed: onPressedAction,
            style: buttonStyle,
            autofocus: autofocus,
            child: content
        )
    }
}

// MARK: - ToggleButtonThemeData

/// Theme data for `ToggleButton` widgets.
///
/// Defines the styles for toggle buttons in their checked and unchecked states.
public class ToggleButtonThemeData {

    /// The style applied when the toggle button is checked.
    public let checkedButtonStyle: ButtonStyle?

    /// The style applied when the toggle button is unchecked.
    public let uncheckedButtonStyle: ButtonStyle?

    /// Creates toggle button theme data.
    public init(
        checkedButtonStyle: ButtonStyle? = nil,
        uncheckedButtonStyle: ButtonStyle? = nil
    ) {
        self.checkedButtonStyle = checkedButtonStyle
        self.uncheckedButtonStyle = uncheckedButtonStyle
    }

    /// Creates the standard `ToggleButtonThemeData` based on the given theme.
    public static func standard(_ theme: FluentThemeData) -> ToggleButtonThemeData {
        return ToggleButtonThemeData(
            checkedButtonStyle: ButtonStyle(
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
        )
    }

    /// Merges this `ToggleButtonThemeData` with another, with the other taking precedence.
    public func merge(_ other: ToggleButtonThemeData?) -> ToggleButtonThemeData {
        guard let other = other else { return self }
        return ToggleButtonThemeData(
            checkedButtonStyle: other.checkedButtonStyle ?? checkedButtonStyle,
            uncheckedButtonStyle: other.uncheckedButtonStyle ?? uncheckedButtonStyle
        )
    }
}

// MARK: - ToggleButtonTheme

/// An inherited widget that defines the configuration for
/// `ToggleButton`s in this widget's subtree.
public class ToggleButtonTheme: InheritedTheme {

    /// The properties for descendant `ToggleButton` widgets.
    public let data: ToggleButtonThemeData

    /// Creates a theme that controls how descendant toggle buttons look.
    public init(key: (any Key)? = nil, data: ToggleButtonThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest `ToggleButtonThemeData` which encloses the given context.
    public static func of(_ context: any BuildContext) -> ToggleButtonThemeData {
        let theme = FluentTheme.of(context)
        let inheritedTheme = context.dependOnInheritedWidgetOfExactType(ToggleButtonTheme.self)
        return ToggleButtonThemeData.standard(theme).merge(inheritedTheme?.data)
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return ToggleButtonTheme(data: data, child: child)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? ToggleButtonTheme else { return true }
        return data !== old.data
    }
}
