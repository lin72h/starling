// MacosRadioButton ported from macos_ui/lib/src/buttons/radio_button.dart

import FlutterSwiftBridge

// MARK: - MacosRadioButton

/// A radio button that lets the user select one option from a group.
///
/// A selected radio button contains a filled circle indicator.
public class MacosRadioButton<T: Equatable>: StatelessWidget {
    /// The value represented by this radio button.
    public let value: T

    /// The currently selected value for this group of radio buttons.
    public let groupValue: T?

    /// Called when this radio button is selected.
    public let onChanged: ((T) -> Void)?

    /// The size of the radio button. Defaults to 16.
    public let size: Double

    /// The semantic label used by screen readers.
    public let semanticLabel: String?

    public var isSelected: Bool { value == groupValue }
    public var isDisabled: Bool { onChanged == nil }

    public init(
        key: (any Key)? = nil,
        value: T,
        groupValue: T?,
        onChanged: ((T) -> Void)?,
        size: Double = 16.0,
        semanticLabel: String? = nil
    ) {
        self.value = value
        self.groupValue = groupValue
        self.onChanged = onChanged
        self.size = size
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgColor: Color
        if isDisabled {
            bgColor = isDark
                ? Color(rgbo: 74, 74, 74, 1.0)
                : Color(rgbo: 0, 0, 0, 0.06)
        } else if isSelected {
            bgColor = theme.primaryColor
        } else {
            bgColor = isDark
                ? Color(rgbo: 74, 74, 74, 1.0)
                : MacosColors.transparent
        }

        let borderColor: Color
        if isSelected && !isDisabled {
            borderColor = MacosColors.transparent
        } else if isDark {
            borderColor = Color(rgbo: 255, 255, 255, 0.25)
        } else {
            borderColor = Color(rgbo: 0, 0, 0, 0.15)
        }

        let indicatorColor: Color
        if isDisabled {
            indicatorColor = Color(rgbo: 172, 172, 172, 1.0)
        } else {
            indicatorColor = MacosColors.white
        }

        let innerDot: Widget
        if isSelected {
            innerDot = Center(
                child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: .circle
                        )
                    )
                )
            )
        } else {
            innerDot = SizedBox(shrink: ())
        }

        return GestureDetector(
            onTap: { self.onChanged?(self.value) },
            child: SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: borderColor, width: 0.5),
                        boxShadow: isDark
                            ? [BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.8),
                                offset: Offset(0, 0.5),
                                blurRadius: 0.7,
                                spreadRadius: -0.5
                              )]
                            : [],
                        shape: .circle
                    ),
                    child: innerDot
                )
            )
        )
    }
}
