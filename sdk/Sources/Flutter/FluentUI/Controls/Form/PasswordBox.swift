// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/form/password_box.dart (simplified)
// A password input field that wraps TextBox with obscured text display
// and an optional reveal toggle button.

import FlutterSwiftBridge

// MARK: - PasswordRevealMode

/// Controls when the password reveal button is available.
public enum PasswordRevealMode {
    /// The password is always hidden and cannot be revealed.
    case hidden
    /// The password can be revealed while the reveal button is held.
    case peek
    /// The reveal button toggles between showing and hiding the password.
    case visible
}

// MARK: - PasswordBox

/// A Fluent UI password input field.
///
/// Wraps `TextBox` with obscured text display and an optional reveal button.
/// The reveal button behavior is controlled by `revealMode`.
public class PasswordBox: StatefulWidget {
    /// Controls the text being edited.
    public let controller: TextEditingController?

    /// A widget displayed when the text field is empty.
    public let placeholder: Widget?

    /// The placeholder text displayed when the field is empty and no
    /// placeholder widget is provided.
    public let placeholderText: String?

    /// Called when the text changes.
    public let onChanged: ((String) -> Void)?

    /// Called when the user submits the text.
    public let onSubmitted: ((String) -> Void)?

    /// Whether the password box is enabled.
    public let enabled: Bool

    /// Controls when/how the password can be revealed.
    public let revealMode: PasswordRevealMode

    /// The character used for obscuring text. Defaults to bullet.
    public let obscuringCharacter: String

    /// The style of the text in the field.
    public let style: TextStyle?

    /// Creates a Fluent UI password box.
    public init(
        key: (any Key)? = nil,
        controller: TextEditingController? = nil,
        placeholder: Widget? = nil,
        placeholderText: String? = "Password",
        onChanged: ((String) -> Void)? = nil,
        onSubmitted: ((String) -> Void)? = nil,
        enabled: Bool = true,
        revealMode: PasswordRevealMode = .peek,
        obscuringCharacter: String = "\u{2022}",
        style: TextStyle? = nil
    ) {
        self.controller = controller
        self.placeholder = placeholder
        self.placeholderText = placeholderText
        self.onChanged = onChanged
        self.onSubmitted = onSubmitted
        self.enabled = enabled
        self.revealMode = revealMode
        self.obscuringCharacter = obscuringCharacter
        self.style = style
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _PasswordBoxState()
    }
}

// MARK: - _PasswordBoxState

class _PasswordBoxState: State<StatefulWidget> {
    private var passwordBox: PasswordBox {
        return widget as! PasswordBox
    }

    /// Whether the password is currently revealed (visible).
    private var _isRevealed: Bool = false

    /// Whether the peek button is currently pressed.
    private var _isPeeking: Bool = false

    /// Whether the password text should be shown as plain text.
    private var _showPassword: Bool {
        switch passwordBox.revealMode {
        case .hidden:
            return false
        case .peek:
            return _isPeeking
        case .visible:
            return _isRevealed
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        // Build the reveal button suffix if applicable
        let suffixWidget: Widget?
        switch passwordBox.revealMode {
        case .hidden:
            suffixWidget = nil
        case .peek:
            suffixWidget = _buildPeekButton(theme)
        case .visible:
            suffixWidget = _buildToggleButton(theme)
        }

        // Build the placeholder
        let effectivePlaceholder: Widget?
        if let placeholder = passwordBox.placeholder {
            effectivePlaceholder = placeholder
        } else if let placeholderText = passwordBox.placeholderText {
            effectivePlaceholder = Text(
                placeholderText,
                style: TextStyle(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 14
                )
            )
        } else {
            effectivePlaceholder = nil
        }

        return FluentTextBox(
            controller: passwordBox.controller,
            placeholder: effectivePlaceholder,
            onChanged: passwordBox.onChanged,
            onSubmitted: passwordBox.onSubmitted,
            maxLines: 1,
            readOnly: false,
            enabled: passwordBox.enabled,
            style: passwordBox.style,
            obscureText: !_showPassword,
            obscuringCharacter: passwordBox.obscuringCharacter,
            suffix: suffixWidget
        )
    }

    /// Builds the peek reveal button (press and hold to reveal).
    private func _buildPeekButton(_ theme: FluentThemeData) -> Widget {
        let iconColor = theme.resources.textFillColorSecondary

        let eyeIcon: Widget = Text(
            _isPeeking ? "\u{1F441}" : "\u{2022}\u{2022}\u{2022}",
            style: TextStyle(
                color: iconColor,
                fontSize: 12
            )
        )

        return HoverButton(
            builder: { context, states in
                let bgColor: Color = Set<WidgetState>.forStates(
                    states,
                    disabled: theme.resources.subtleFillColorTransparent,
                    none: theme.resources.subtleFillColorTransparent,
                    pressed: theme.resources.subtleFillColorTertiary,
                    hovering: theme.resources.subtleFillColorSecondary
                )

                return _PasswordBoxDecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(3)
                    ),
                    child: Padding(
                        padding: EdgeInsets(left: 4, top: 2, right: 4, bottom: 2),
                        child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: eyeIcon
                        )
                    )
                )
            },
            onPressed: {},
            onTapDown: { [self] in
                setState {
                    self._isPeeking = true
                }
            },
            onTapUp: { [self] in
                setState {
                    self._isPeeking = false
                }
            }
        )
    }

    /// Builds the toggle reveal button (click to toggle visibility).
    private func _buildToggleButton(_ theme: FluentThemeData) -> Widget {
        let iconColor = theme.resources.textFillColorSecondary

        let eyeIcon: Widget = Text(
            _isRevealed ? "\u{1F441}" : "\u{2022}\u{2022}\u{2022}",
            style: TextStyle(
                color: iconColor,
                fontSize: 12
            )
        )

        return HoverButton(
            builder: { context, states in
                let bgColor: Color = Set<WidgetState>.forStates(
                    states,
                    disabled: theme.resources.subtleFillColorTransparent,
                    none: theme.resources.subtleFillColorTransparent,
                    pressed: theme.resources.subtleFillColorTertiary,
                    hovering: theme.resources.subtleFillColorSecondary
                )

                return _PasswordBoxDecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(3)
                    ),
                    child: Padding(
                        padding: EdgeInsets(left: 4, top: 2, right: 4, bottom: 2),
                        child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: eyeIcon
                        )
                    )
                )
            },
            onPressed: { [self] in
                setState {
                    self._isRevealed = !self._isRevealed
                }
            }
        )
    }
}

// MARK: - _PasswordBoxDecoratedBox

/// A widget that paints a `BoxDecoration` behind its child.
private class _PasswordBoxDecoratedBox: SingleChildRenderObjectWidget {
    let decoration: BoxDecoration

    init(
        key: (any Key)? = nil,
        decoration: BoxDecoration,
        child: Widget? = nil
    ) {
        self.decoration = decoration
        super.init(key: key, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderDecoratedBox(decoration: decoration)
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderDecoratedBox
        ro.decoration = decoration
    }
}
