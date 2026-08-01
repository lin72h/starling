// MacosAlertDialog ported from macos_ui/lib/src/dialogs/macos_alert_dialog.dart

import FlutterSwiftBridge

// MARK: - MacosAlertDialog

/// A macOS-style modal alert dialog.
///
/// Displays a centered dialog with an icon, title, message, and action buttons.
public class MacosAlertDialog: StatelessWidget {
    /// The icon displayed at the top of the dialog.
    public let appIcon: Widget

    /// The title of the alert.
    public let title: Widget

    /// The message body of the alert.
    public let message: Widget

    /// The primary action button (e.g., "OK", "Delete").
    public let primaryButton: Widget

    /// An optional secondary action button (e.g., "Cancel").
    public let secondaryButton: Widget?

    /// Whether to show a suppress checkbox.
    public let suppress: Widget?

    public init(
        key: (any Key)? = nil,
        appIcon: Widget,
        title: Widget,
        message: Widget,
        primaryButton: Widget,
        secondaryButton: Widget? = nil,
        suppress: Widget? = nil
    ) {
        self.appIcon = appIcon
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.suppress = suppress
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        var columnChildren: [Widget] = [
            SizedBox(height: 16),
            appIcon,
            SizedBox(height: 16),
            DefaultTextStyle(
                style: theme.typography.headline,
                textAlign: .center,
                child: title
            ),
            SizedBox(height: 10),
            DefaultTextStyle(
                style: theme.typography.body,
                textAlign: .center,
                child: message
            ),
            SizedBox(height: 16),
        ]

        var buttonRow: [Widget] = [primaryButton]
        if let secondary = secondaryButton {
            buttonRow.insert(secondary, at: 0)
            buttonRow.insert(SizedBox(width: 8), at: 1)
        }

        columnChildren.append(
            Row(
                mainAxisAlignment: .center,
                children: buttonRow
            )
        )

        if let suppress = suppress {
            columnChildren.append(SizedBox(height: 10))
            columnChildren.append(suppress)
        }

        columnChildren.append(SizedBox(height: 16))

        return Center(
            child: SizedBox(
                width: 260,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: isDark
                            ? Color(rgbo: 50, 50, 50, 1.0)
                            : MacosColors.white,
                        borderRadius: BorderRadius.all(Radius(circular: 12)),
                        boxShadow: [
                            BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.3),
                                offset: Offset(0, 10),
                                blurRadius: 20
                            )
                        ]
                    ),
                    child: Padding(
                        padding: EdgeInsets(horizontal: 20),
                        child: Column(
                            mainAxisSize: .min,
                            children: columnChildren
                        )
                    )
                )
            )
        )
    }
}

// MARK: - MacosSheet

/// A macOS-style sheet overlay presented from the top of a window.
public class MacosSheet: StatelessWidget {
    public let child: Widget

    public init(
        key: (any Key)? = nil,
        child: Widget
    ) {
        self.child = child
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        return Center(
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: isDark
                            ? Color(rgbo: 50, 50, 50, 1.0)
                            : MacosColors.white,
                        borderRadius: BorderRadius.all(Radius(circular: 12)),
                        boxShadow: [
                            BoxShadow(
                                color: Color(rgbo: 0, 0, 0, 0.3),
                                offset: Offset(0, 10),
                                blurRadius: 20
                            )
                        ]
                    ),
                    child: Padding(
                        padding: EdgeInsets(all: 20),
                        child: child
                    )
                )
            )
        )
    }
}
