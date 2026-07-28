// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/inputs/radio_button.dart
//
// Simplified: no RawRadio or RadioGroupRegistry; interaction via HoverButton
// with explicit value/groupValue comparison.

import FlutterSwiftBridge

// MARK: - RadioButton

/// Radio buttons let users select one option from a collection of two or more
/// mutually exclusive, but related, options.
///
/// ```swift
/// RadioButton<Int>(
///     value: 1,
///     groupValue: selectedValue,
///     onChanged: { v in setState { selectedValue = v } },
///     content: Text("Option 1")
/// )
/// ```
public class RadioButton<T: Equatable>: StatelessWidget {
    /// The value this radio button represents.
    public let value: T

    /// The currently selected value for the group.
    /// When `value == groupValue`, this radio button is selected.
    public let groupValue: T?

    /// Called when the user selects this radio button.
    /// If nil, the radio button is considered disabled.
    public let onChanged: ((T?) -> Void)?

    /// The style applied to the radio button.
    public let style: RadioButtonThemeData?

    /// The content displayed to the right of the radio button.
    public let content: Widget?

    public init(
        key: (any Key)? = nil,
        value: T,
        groupValue: T? = nil,
        onChanged: ((T?) -> Void)? = nil,
        style: RadioButtonThemeData? = nil,
        content: Widget? = nil
    ) {
        self.value = value
        self.groupValue = groupValue
        self.onChanged = onChanged
        self.style = style
        self.content = content
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let resolvedStyle = RadioButtonTheme.of(context).merge(style)
        let theme = FluentTheme.of(context)
        let isSelected = value == groupValue
        let size: Double = 20.0

        return HoverButton(
            builder: { [self] context, states in
                // Resolve decoration based on checked state
                let decoration: BoxDecoration = {
                    if isSelected {
                        return resolvedStyle.checkedDecoration?.resolve(states)
                            ?? BoxDecoration(shape: .circle)
                    } else {
                        return resolvedStyle.uncheckedDecoration?.resolve(states)
                            ?? BoxDecoration(shape: .circle)
                    }
                }()

                var child: Widget = AnimatedContainer(
                    decoration: decoration,
                    width: size,
                    height: size,
                    curve: theme.animationCurve,
                    duration: theme.fastAnimationDuration
                )

                // Add content label if provided
                if let labelContent = content {
                    let foregroundColor = resolvedStyle.foregroundColor?.resolve(states)
                    let inheritedStyle = DefaultTextStyle.of(context).style
                    let mergedStyle = inheritedStyle.merge(TextStyle(color: foregroundColor))
                    child = Row(
                        mainAxisSize: .min,
                        children: [
                            child,
                            SizedBox(width: 6),
                            Flexible(
                                child: DefaultTextStyle(
                                    style: mergedStyle,
                                    child: labelContent
                                )
                            ),
                        ]
                    )
                }

                return FocusBorder(
                    child: child,
                    focused: states.isFocused
                )
            },
            onPressed: onChanged == nil
                ? nil
                : { [value, onChanged] in
                    onChanged?(value)
                }
        )
    }
}

// MARK: - RadioButtonTheme

/// An inherited theme that controls how descendant RadioButtons look.
public class RadioButtonTheme: InheritedTheme {
    /// The theme data for the radio button theme.
    public let data: RadioButtonThemeData

    public init(key: (any Key)? = nil, data: RadioButtonThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest RadioButtonThemeData which encloses the given context.
    public static func of(_ context: any BuildContext) -> RadioButtonThemeData {
        let theme = FluentTheme.of(context)
        let inherited = context.dependOnInheritedWidgetOfExactType(RadioButtonTheme.self)
        return RadioButtonThemeData.standard(theme).merge(inherited?.data)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? RadioButtonTheme else { return true }
        return data !== old.data
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return RadioButtonTheme(data: data, child: child)
    }
}

// MARK: - RadioButtonThemeData

/// Theme data for RadioButton widgets.
public class RadioButtonThemeData {
    /// The decoration of the radio button when it's checked.
    public let checkedDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The decoration of the radio button when it's unchecked.
    public let uncheckedDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The color of the radio button's content.
    public let foregroundColor: (any WidgetStateProperty<Color?>)?

    public init(
        checkedDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        uncheckedDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        foregroundColor: (any WidgetStateProperty<Color?>)? = nil
    ) {
        self.checkedDecoration = checkedDecoration
        self.uncheckedDecoration = uncheckedDecoration
        self.foregroundColor = foregroundColor
    }

    /// Creates the standard RadioButtonThemeData based on the given theme.
    public static func standard(_ theme: FluentThemeData) -> RadioButtonThemeData {
        return RadioButtonThemeData(
            checkedDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                let borderWidth: Double
                if states.isDisabled {
                    borderWidth = 4.0
                } else if states.isHovered && !states.isPressed {
                    borderWidth = 3.4
                } else {
                    borderWidth = 5.0
                }
                return BoxDecoration(
                    color: theme.resources.textOnAccentFillColorPrimary,
                    border: Border.all(
                        color: checkedInputColor(theme, states),
                        width: borderWidth
                    ),
                    shape: .circle
                )
            }),
            uncheckedDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                let borderWidth: Double = states.isPressed ? 4.5 : 1.0
                let borderColor: Color = Set<WidgetState>.forStates(
                    states,
                    disabled: theme.resources.textFillColorDisabled,
                    none: theme.resources.textFillColorTertiary,
                    pressed: theme.accentColor.defaultBrushFor(theme.brightness)
                )
                return BoxDecoration(
                    color: Set<WidgetState>.forStates(
                        states,
                        disabled: theme.resources.controlAltFillColorDisabled,
                        none: theme.resources.controlAltFillColorSecondary,
                        pressed: theme.resources.controlAltFillColorQuarternary,
                        hovering: theme.resources.controlAltFillColorTertiary
                    ),
                    border: Border.all(
                        color: borderColor,
                        width: borderWidth
                    ),
                    shape: .circle
                )
            }),
            foregroundColor: WidgetStatePropertyHelper.resolveWith({ states -> Color? in
                states.isDisabled ? theme.resources.textFillColorDisabled : nil
            })
        )
    }

    /// Merge this theme data with another, with the other taking precedence.
    public func merge(_ other: RadioButtonThemeData?) -> RadioButtonThemeData {
        guard let other = other else { return self }
        return RadioButtonThemeData(
            checkedDecoration: other.checkedDecoration ?? checkedDecoration,
            uncheckedDecoration: other.uncheckedDecoration ?? uncheckedDecoration,
            foregroundColor: other.foregroundColor ?? foregroundColor
        )
    }
}
