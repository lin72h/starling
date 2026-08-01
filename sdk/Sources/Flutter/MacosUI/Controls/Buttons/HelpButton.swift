// HelpButton ported from macos_ui/lib/src/buttons/help_button.dart

import FlutterSwiftBridge

// MARK: - HelpButton

/// A small circular button with a question mark icon.
///
/// Used to provide contextual help in macOS interfaces.
public class HelpButton: StatefulWidget {
    public let onPressed: (() -> Void)?
    public let color: Color?
    public let disabledColor: Color?
    public let semanticLabel: String?

    public var enabled: Bool { onPressed != nil }

    public init(
        key: (any Key)? = nil,
        onPressed: (() -> Void)?,
        color: Color? = nil,
        disabledColor: Color? = nil,
        semanticLabel: String? = nil
    ) {
        self.onPressed = onPressed
        self.color = color
        self.disabledColor = disabledColor
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _HelpButtonState()
    }
}

class _HelpButtonState: State<StatefulWidget> {
    private var btn: HelpButton {
        return widget as! HelpButton
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgColor: Color
        if btn.enabled {
            bgColor = btn.color ?? (isDark
                ? Color(rgbo: 255, 255, 255, 0.1)
                : Color(rgbo: 244, 245, 245, 1.0))
        } else {
            bgColor = btn.disabledColor ?? (isDark
                ? Color(rgbo: 255, 255, 255, 0.1)
                : Color(rgbo: 244, 245, 245, 1.0))
        }

        let iconColor = isDark ? MacosColors.white : MacosColors.black

        return GestureDetector(
            onTap: btn.onPressed,
            child: SizedBox(
                width: 20,
                height: 20,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(
                            color: isDark
                                ? Color(rgbo: 255, 255, 255, 0.15)
                                : Color(rgbo: 0, 0, 0, 0.15),
                            width: 0.5
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: Color(rgbo: 0, 0, 0, isDark ? 0.4 : 0.15),
                                offset: Offset(0, 0.3),
                                blurRadius: 0.5
                            )
                        ],
                        shape: .circle
                    ),
                    child: Center(
                        child: Text("?", style: TextStyle(
                            color: btn.enabled ? iconColor : iconColor.withValues(alpha: 0.25),
                            fontSize: 12
                        ))
                    )
                )
            )
        )
    }
}
