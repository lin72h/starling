// MacosTooltip ported from macos_ui/lib/src/labels/tooltip.dart

import FlutterSwiftBridge

// MARK: - MacosTooltip

/// A macOS-style tooltip that appears on hover.
public class MacosTooltip: StatelessWidget {
    /// The message displayed in the tooltip.
    public let message: String

    /// The widget that triggers the tooltip on hover.
    public let child: Widget

    /// The style of the tooltip text.
    public let style: TextStyle?

    /// The padding inside the tooltip.
    public let padding: EdgeInsets

    public init(
        key: (any Key)? = nil,
        message: String,
        child: Widget,
        style: TextStyle? = nil,
        padding: EdgeInsets = EdgeInsets(horizontal: 8, vertical: 4)
    ) {
        self.message = message
        self.child = child
        self.style = style
        self.padding = padding
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        // Simplified: tooltip shown as a Tooltip widget
        // Full implementation would use Overlay with hover detection
        return Tooltip(
            message: message,
            child: child
        )
    }
}

// MARK: - MacosLabel

/// A simple macOS-style text label.
public class MacosLabel: StatelessWidget {
    public let text: String
    public let style: TextStyle?

    public init(
        key: (any Key)? = nil,
        text: String,
        style: TextStyle? = nil
    ) {
        self.text = text
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        return Text(text, style: style ?? theme.typography.body)
    }
}

// MARK: - MacosIcon

/// A macOS-style icon with theme-aware sizing.
public class MacosIcon: StatelessWidget {
    public let icon: IconData
    public let color: Color?
    public let size: Double?

    public init(
        key: (any Key)? = nil,
        icon: IconData,
        color: Color? = nil,
        size: Double? = nil
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let iconColor = color ?? theme.iconTheme.color ?? theme.primaryColor
        let iconSize = size ?? theme.iconTheme.size ?? 20
        // Icon widget not available; render codePoint as Unicode text
        let scalar = UnicodeScalar(icon.codePoint)
        let char = scalar != nil ? String(scalar!) : "?"
        return Text(
            char,
            style: TextStyle(
                color: iconColor,
                fontSize: iconSize,
                fontFamily: icon.fontFamily
            )
        )
    }
}
