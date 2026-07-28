// MacosBackButton ported from macos_ui/lib/src/buttons/back_button.dart

import FlutterSwiftBridge

// MARK: - MacosBackButton

/// A back button with a chevron icon used for navigation.
public class MacosBackButton: StatefulWidget {
    public let onPressed: (() -> Void)?
    public let semanticLabel: String?

    public init(
        key: (any Key)? = nil,
        onPressed: (() -> Void)? = nil,
        semanticLabel: String? = nil
    ) {
        self.onPressed = onPressed
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosBackButtonState()
    }
}

class _MacosBackButtonState: State<StatefulWidget> {
    private var isHovered = false

    private var btn: MacosBackButton {
        return widget as! MacosBackButton
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgColor: Color = isHovered
            ? (isDark ? Color(rgbo: 255, 255, 255, 0.1) : Color(rgbo: 0, 0, 0, 0.06))
            : MacosColors.transparent

        return MouseRegion(
            onEnter: { _ in self.setState { self.isHovered = true } },
            onExit: { _ in self.setState { self.isHovered = false } },
            child: GestureDetector(
                onTap: btn.onPressed,
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.all(Radius(circular: 5))
                        ),
                        child: Center(
                            child: Text("\u{2039}", style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 16
                            ))
                        )
                    )
                )
            )
        )
    }
}
