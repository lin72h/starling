// MacosTextField ported from macos_ui/lib/src/fields/text_field.dart

import FlutterSwiftBridge

// MARK: - MacosTextField

/// A macOS-style text field with rounded borders and focus state styling.
public class MacosTextField: StatefulWidget {
    public let controller: TextEditingController?
    public let placeholder: String?
    public let prefix: Widget?
    public let suffix: Widget?
    public let enabled: Bool
    public let maxLines: Int
    public let minLines: Int
    public let onChanged: ((String) -> Void)?
    public let onSubmitted: ((String) -> Void)?
    public let style: TextStyle?
    public let padding: EdgeInsets
    public let decoration: BoxDecoration?

    public init(
        key: (any Key)? = nil,
        controller: TextEditingController? = nil,
        placeholder: String? = nil,
        prefix: Widget? = nil,
        suffix: Widget? = nil,
        enabled: Bool = true,
        maxLines: Int = 1,
        minLines: Int = 1,
        onChanged: ((String) -> Void)? = nil,
        onSubmitted: ((String) -> Void)? = nil,
        style: TextStyle? = nil,
        padding: EdgeInsets = EdgeInsets(horizontal: 6, vertical: 4),
        decoration: BoxDecoration? = nil
    ) {
        self.controller = controller
        self.placeholder = placeholder
        self.prefix = prefix
        self.suffix = suffix
        self.enabled = enabled
        self.maxLines = maxLines
        self.minLines = minLines
        self.onChanged = onChanged
        self.onSubmitted = onSubmitted
        self.style = style
        self.padding = padding
        self.decoration = decoration
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosTextFieldState()
    }
}

class _MacosTextFieldState: State<StatefulWidget> {
    private var field: MacosTextField {
        return widget as! MacosTextField
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgDecoration = field.decoration ?? BoxDecoration(
            color: isDark
                ? Color(rgbo: 30, 30, 30, 1.0)
                : MacosColors.white,
            border: Border.all(
                color: isDark
                    ? Color(rgbo: 255, 255, 255, 0.15)
                    : Color(rgbo: 0, 0, 0, 0.15),
                width: 0.5
            ),
            borderRadius: BorderRadius.all(Radius(circular: 5)),
            boxShadow: isDark
                ? []
                : [BoxShadow(
                    color: Color(rgbo: 0, 0, 0, 0.06),
                    offset: Offset(0, 0.5),
                    blurRadius: 1
                  )]
        )

        var rowChildren: [Widget] = []

        if let prefix = field.prefix {
            rowChildren.append(prefix)
            rowChildren.append(SizedBox(width: 4))
        }

        // EditableText/FocusNode not available; placeholder text display
        let displayText = field.controller?.text ?? field.placeholder ?? ""
        rowChildren.append(
            Expanded(
                child: Text(
                    displayText,
                    style: field.style ?? theme.typography.body
                )
            )
        )

        if let suffix = field.suffix {
            rowChildren.append(SizedBox(width: 4))
            rowChildren.append(suffix)
        }

        return DecoratedBox(
            decoration: bgDecoration,
            child: Padding(
                padding: field.padding,
                child: Row(children: rowChildren)
            )
        )
    }
}

// MARK: - MacosSearchField

/// A macOS-style search field with a magnifying glass icon.
public class MacosSearchField: StatelessWidget {
    public let controller: TextEditingController?
    public let placeholder: String
    public let onChanged: ((String) -> Void)?
    public let onSubmitted: ((String) -> Void)?
    public let enabled: Bool

    public init(
        key: (any Key)? = nil,
        controller: TextEditingController? = nil,
        placeholder: String = "Search",
        onChanged: ((String) -> Void)? = nil,
        onSubmitted: ((String) -> Void)? = nil,
        enabled: Bool = true
    ) {
        self.controller = controller
        self.placeholder = placeholder
        self.onChanged = onChanged
        self.onSubmitted = onSubmitted
        self.enabled = enabled
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        return MacosTextField(
            controller: controller,
            placeholder: placeholder,
            prefix: Text(
                "\u{2315}",
                style: TextStyle(color: MacosColors.placeholderTextColor, fontSize: 12)
            ),
            enabled: enabled,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: BoxDecoration(
                color: isDark
                    ? Color(rgbo: 30, 30, 30, 1.0)
                    : MacosColors.white,
                border: Border.all(
                    color: isDark
                        ? Color(rgbo: 255, 255, 255, 0.15)
                        : Color(rgbo: 0, 0, 0, 0.15),
                    width: 0.5
                ),
                borderRadius: BorderRadius.all(Radius(circular: 7))
            )
        )
    }
}
