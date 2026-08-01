// Ported from: fluent_ui/lib/src/controls/form/info_label.dart
//
// A simple label + child wrapper used to label form controls with a text
// heading. Lays out as a Column with the label on top and the child below.

import FlutterSwiftBridge

// MARK: - InfoLabel

/// A widget that displays a text label above an optional child widget.
///
/// `InfoLabel` is commonly used in form layouts to pair a descriptive label
/// with an input control such as a `Slider`, `Checkbox`, or `DropDownButton`.
///
/// Usage:
/// ```swift
/// InfoLabel(
///     label: "Volume",
///     child: Slider(value: volume, onChanged: { v in ... })
/// )
/// ```
public class InfoLabel: StatelessWidget {
    /// The text displayed as the label.
    public let label: String

    /// An optional style for the label text.
    /// If nil, a default style is derived from the current theme.
    public let labelStyle: TextStyle?

    /// The child widget displayed below the label.
    public let child: Widget?

    /// Whether the label should be rendered as a header (larger, bolder text).
    public let isHeader: Bool

    /// Creates an info label.
    public init(
        key: (any Key)? = nil,
        label: String,
        labelStyle: TextStyle? = nil,
        isHeader: Bool = false,
        child: Widget? = nil
    ) {
        self.label = label
        self.labelStyle = labelStyle
        self.isHeader = isHeader
        self.child = child
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        let defaultStyle: TextStyle
        if isHeader {
            defaultStyle = TextStyle(
                color: theme.resources.textFillColorPrimary,
                fontSize: 14,
                fontWeight: .w600
            )
        } else {
            defaultStyle = TextStyle(
                color: theme.resources.textFillColorPrimary,
                fontSize: 14
            )
        }

        let resolvedStyle = labelStyle ?? defaultStyle

        let labelWidget: Widget = Text(label, style: resolvedStyle)

        var children: [Widget] = [labelWidget]

        if let child = child {
            children.append(SizedBox(height: 4))
            children.append(child)
        }

        return Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: children
        )
    }
}
