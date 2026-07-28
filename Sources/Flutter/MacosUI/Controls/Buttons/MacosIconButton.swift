// MacosIconButton ported from macos_ui/lib/src/buttons/icon_button.dart

import FlutterSwiftBridge

// MARK: - MacosIconButton

/// A simple clickable icon button with hover and disabled states.
public class MacosIconButton: StatefulWidget {
    public let icon: Widget
    public let onPressed: (() -> Void)?
    public let backgroundColor: Color?
    public let disabledColor: Color?
    public let hoverColor: Color?
    public let shape: BoxShape
    public let borderRadius: BorderRadius?
    public let padding: EdgeInsets
    public let boxConstraints: BoxConstraints?
    public let semanticLabel: String?

    public var enabled: Bool { onPressed != nil }

    public init(
        key: (any Key)? = nil,
        icon: Widget,
        onPressed: (() -> Void)? = nil,
        backgroundColor: Color? = nil,
        disabledColor: Color? = nil,
        hoverColor: Color? = nil,
        shape: BoxShape = .circle,
        borderRadius: BorderRadius? = nil,
        padding: EdgeInsets = EdgeInsets(all: 4),
        boxConstraints: BoxConstraints? = nil,
        semanticLabel: String? = nil
    ) {
        self.icon = icon
        self.onPressed = onPressed
        self.backgroundColor = backgroundColor
        self.disabledColor = disabledColor
        self.hoverColor = hoverColor
        self.shape = shape
        self.borderRadius = borderRadius
        self.padding = padding
        self.boxConstraints = boxConstraints
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosIconButtonState()
    }
}

class _MacosIconButtonState: State<StatefulWidget> {
    private var isHovered = false

    private var btn: MacosIconButton {
        return widget as! MacosIconButton
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)

        let bgColor: Color
        if !btn.enabled {
            bgColor = btn.disabledColor ?? theme.iconButtonTheme.disabledColor
        } else if isHovered {
            bgColor = btn.hoverColor ?? theme.iconButtonTheme.hoverColor
        } else {
            bgColor = btn.backgroundColor ?? theme.iconButtonTheme.backgroundColor
        }

        let constraints = btn.boxConstraints ?? BoxConstraints(
            minWidth: 20, maxWidth: 30,
            minHeight: 20, maxHeight: 30
        )

        return MouseRegion(
            onEnter: { _ in self.setState { self.isHovered = true } },
            onExit: { _ in self.setState { self.isHovered = false } },
            child: GestureDetector(
                onTap: btn.onPressed,
                child: ConstrainedBox(
                    constraints: constraints,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: btn.shape == .rectangle ? btn.borderRadius : nil,
                            shape: btn.shape
                        ),
                        child: Padding(
                            padding: btn.padding,
                            child: Center(child: btn.icon)
                        )
                    )
                )
            )
        )
    }
}
