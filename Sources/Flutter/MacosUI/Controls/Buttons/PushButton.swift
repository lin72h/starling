// PushButton ported from macos_ui/lib/src/buttons/push_button.dart

import FlutterSwiftBridge

// MARK: - Size Constants

private let _kMiniButtonSize = Size(26.0, 11.0)
private let _kSmallButtonSize = Size(39.0, 14.0)
private let _kRegularButtonSize = Size(60.0, 18.0)
private let _kLargeButtonSize = Size(48.0, 26.0)

private let _kMiniButtonPadding = EdgeInsets(left: 6, right: 6, bottom: 1)
private let _kSmallButtonPadding = EdgeInsets(horizontal: 7, vertical: 1)
private let _kRegularButtonPadding = EdgeInsets(left: 8, top: 1, right: 8, bottom: 4)
private let _kLargeButtonPadding = EdgeInsets(left: 8, right: 8, bottom: 1)

private let _kMiniButtonRadius = BorderRadius.all(Radius(circular: 2))
private let _kSmallButtonRadius = BorderRadius.all(Radius(circular: 2))
private let _kRegularButtonRadius = BorderRadius.all(Radius(circular: 5))
private let _kLargeButtonRadius = BorderRadius.all(Radius(circular: 7))

// MARK: - ControlSize Extensions for PushButton

extension ControlSize {
    /// The padding for a push button at this control size.
    public var pushButtonPadding: EdgeInsets {
        switch self {
        case .mini: return _kMiniButtonPadding
        case .small: return _kSmallButtonPadding
        case .regular: return _kRegularButtonPadding
        case .large: return _kLargeButtonPadding
        }
    }

    /// The border radius for a push button at this control size.
    public var pushButtonBorderRadius: BorderRadius {
        switch self {
        case .mini: return _kMiniButtonRadius
        case .small: return _kSmallButtonRadius
        case .regular: return _kRegularButtonRadius
        case .large: return _kLargeButtonRadius
        }
    }

    /// The font size for a push button at this control size.
    public var pushButtonFontSize: Double {
        switch self {
        case .mini: return 9
        case .small: return 11
        case .regular: return 13
        case .large: return 13
        }
    }

    /// The minimum box constraints for a push button at this control size.
    public var pushButtonConstraints: BoxConstraints {
        switch self {
        case .mini:
            return BoxConstraints(
                minWidth: _kMiniButtonSize.width,
                minHeight: _kMiniButtonSize.height
            )
        case .small:
            return BoxConstraints(
                minWidth: _kSmallButtonSize.width,
                minHeight: _kSmallButtonSize.height
            )
        case .regular:
            return BoxConstraints(
                minWidth: _kRegularButtonSize.width,
                minHeight: _kRegularButtonSize.height
            )
        case .large:
            return BoxConstraints(
                minWidth: _kLargeButtonSize.width,
                minHeight: _kLargeButtonSize.height
            )
        }
    }
}

// MARK: - PushButton

/// A control that initiates an action. The standard button type in macOS.
///
/// Supports four sizes via [controlSize]: mini, small, regular, large.
/// Uses the theme's accent color for the primary background gradient.
public class PushButton: StatefulWidget {
    public let child: Widget
    public let controlSize: ControlSize
    public let padding: EdgeInsets?
    public let color: Color?
    public let disabledColor: Color?
    public let onPressed: (() -> Void)?
    public let borderRadius: BorderRadius?
    public let alignment: Alignment
    public let secondary: Bool
    public let semanticLabel: String?

    public var enabled: Bool { onPressed != nil }

    public init(
        key: (any Key)? = nil,
        child: Widget,
        controlSize: ControlSize = .regular,
        padding: EdgeInsets? = nil,
        color: Color? = nil,
        disabledColor: Color? = nil,
        onPressed: (() -> Void)? = nil,
        borderRadius: BorderRadius? = nil,
        alignment: Alignment = .center,
        secondary: Bool = false,
        semanticLabel: String? = nil
    ) {
        self.child = child
        self.controlSize = controlSize
        self.padding = padding
        self.color = color
        self.disabledColor = disabledColor
        self.onPressed = onPressed
        self.borderRadius = borderRadius
        self.alignment = alignment
        self.secondary = secondary
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _PushButtonState()
    }
}

class _PushButtonState: State<StatefulWidget> {
    private var buttonHeldDown = false

    private var button: PushButton {
        return widget as! PushButton
    }

    private func _handleTapDown(_ details: TapDownDetails) {
        if !buttonHeldDown {
            setState { self.buttonHeldDown = true }
        }
    }

    private func _handleTapUp(_ details: TapUpDetails) {
        if buttonHeldDown {
            setState { self.buttonHeldDown = false }
        }
    }

    private func _handleTapCancel() {
        if buttonHeldDown {
            setState { self.buttonHeldDown = false }
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark
        let isSecondary = button.secondary

        let backgroundColor: Color
        if let color = button.color {
            backgroundColor = button.enabled ? color : (button.disabledColor ?? theme.pushButtonTheme.disabledColor)
        } else if isSecondary {
            backgroundColor = theme.pushButtonTheme.secondaryColor
        } else {
            backgroundColor = button.enabled ? theme.pushButtonTheme.color : theme.pushButtonTheme.disabledColor
        }

        let foregroundColor: Color = button.enabled
            ? (backgroundColor.computeLuminance() < 0.5 ? MacosColors.white : MacosColors.black)
            : (backgroundColor.computeLuminance() < 0.5
                ? MacosColors.white.withValues(alpha: 0.25)
                : MacosColors.black.withValues(alpha: 0.25))

        let borderRadius = button.borderRadius ?? button.controlSize.pushButtonBorderRadius
        let padding = button.padding ?? button.controlSize.pushButtonPadding

        let baseStyle = theme.typography.body.copyWith(
            color: foregroundColor,
            fontSize: button.controlSize.pushButtonFontSize
        )

        let pressOverlay: BoxDecoration? = buttonHeldDown
            ? BoxDecoration(
                color: isDark
                    ? Color(rgbo: 255, 255, 255, 0.15)
                    : Color(rgbo: 0, 0, 0, 0.06),
                borderRadius: borderRadius
              )
            : nil

        return GestureDetector(
            onTapDown: button.enabled ? _handleTapDown : nil,
            onTapUp: button.enabled ? _handleTapUp : nil,
            onTap: button.onPressed,
            onTapCancel: button.enabled ? _handleTapCancel : nil,
            behavior: .opaque,
            child: ConstrainedBox(
                constraints: button.controlSize.pushButtonConstraints,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: borderRadius,
                        boxShadow: isDark
                            ? [BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.4),
                                offset: button.enabled ? Offset(0, 0.3) : Offset.zero,
                                blurRadius: 0.5
                              )]
                            : [BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.15),
                                offset: button.enabled ? Offset(0, 0.3) : Offset.zero,
                                blurRadius: 0.5
                              )]
                    ),
                    child: DecoratedBox(
                        decoration: pressOverlay ?? BoxDecoration(),
                        position: .foreground,
                        child: Padding(
                            padding: padding,
                            child: Align(
                                alignment: button.alignment,
                                widthFactor: 1.0,
                                heightFactor: 1.0,
                                child: DefaultTextStyle(
                                    style: baseStyle,
                                    child: button.child
                                )
                            )
                        )
                    )
                )
            )
        )
    }
}
