// MacosCheckbox ported from macos_ui/lib/src/buttons/checkbox.dart

import FlutterSwiftBridge

// MARK: - MacosCheckbox

/// A checkbox that lets the user choose between two opposite states.
///
/// A selected checkbox contains a checkmark; an empty checkbox is off.
/// Supports a mixed/indeterminate state when [value] is nil.
public class MacosCheckbox: StatelessWidget {
    /// Whether the checkbox is checked. If nil, it's considered mixed.
    public let value: Bool?

    /// Called whenever the state of the checkbox changes. If nil, the checkbox is disabled.
    public let onChanged: ((Bool) -> Void)?

    /// The size of the checkbox. Defaults to 14.
    public let size: Double

    /// The background color when the checkbox is on or mixed.
    public let activeColor: Color?

    /// The semantic label used by screen readers.
    public let semanticLabel: String?

    public var isMixed: Bool { value == nil }
    public var isDisabled: Bool { onChanged == nil }

    public init(
        key: (any Key)? = nil,
        value: Bool?,
        onChanged: ((Bool) -> Void)?,
        size: Double = 14.0,
        activeColor: Color? = nil,
        semanticLabel: String? = nil
    ) {
        self.value = value
        self.onChanged = onChanged
        self.size = size
        self.activeColor = activeColor
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let isChecked = value == true
        let showActiveColor = isChecked || isMixed

        let bgColor: Color
        if isDisabled {
            bgColor = isDark
                ? Color(rgbo: 74, 74, 74, 1.0)
                : Color(rgbo: 0, 0, 0, 0.06)
        } else if showActiveColor {
            bgColor = activeColor ?? theme.primaryColor
        } else {
            bgColor = isDark
                ? Color(rgbo: 74, 74, 74, 1.0)
                : MacosColors.transparent
        }

        let checkColor: Color
        if isDisabled {
            checkColor = Color(rgbo: 172, 172, 172, 1.0)
        } else if isDark {
            checkColor = MacosColors.white
        } else if showActiveColor {
            checkColor = MacosColors.white
        } else {
            checkColor = MacosColors.black
        }

        let borderColor: Color
        if showActiveColor && !isDisabled {
            borderColor = MacosColors.transparent
        } else if isDark {
            borderColor = Color(rgbo: 255, 255, 255, 0.25)
        } else {
            borderColor = Color(rgbo: 0, 0, 0, 0.15)
        }

        let icon: Widget
        if value == false {
            icon = SizedBox(shrink: ())
        } else if isMixed {
            icon = Text("\u{2014}", style: TextStyle(color: checkColor, fontSize: size - 3))
        } else {
            icon = Text("\u{2713}", style: TextStyle(color: checkColor, fontSize: size - 3))
        }

        return GestureDetector(
            onTap: {
                if let value = self.value {
                    self.onChanged?(!value)
                } else {
                    self.onChanged?(true)
                }
            },
            child: SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: borderColor, width: 0.5),
                        borderRadius: BorderRadius.all(Radius(circular: 3.5)),
                        boxShadow: isDark
                            ? [BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.8),
                                offset: Offset(0, 0.5),
                                blurRadius: 0.7,
                                spreadRadius: -0.5
                              )]
                            : []
                    ),
                    child: Center(child: icon)
                )
            )
        )
    }
}
