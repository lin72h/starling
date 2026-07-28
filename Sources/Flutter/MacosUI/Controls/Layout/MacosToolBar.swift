// MacosToolBar ported from macos_ui/lib/src/layout/toolbar/toolbar.dart

import FlutterSwiftBridge

// MARK: - MacosToolBar

/// A toolbar displayed at the top of a MacosScaffold.
///
/// Follows macOS conventions with title, leading, and actions.
/// Default height is 52dp.
public class MacosToolBar: StatelessWidget {
    /// The height of the toolbar. Defaults to 52.
    public let height: Double

    /// The title displayed in the center of the toolbar.
    public let title: Widget?

    /// A widget displayed at the leading edge.
    public let leading: Widget?

    /// A list of action items displayed at the trailing edge.
    public let actions: [Widget]

    /// The alignment of the title within the toolbar.
    public let titleAlignment: Alignment

    /// The background color of the toolbar.
    public let decoration: BoxDecoration?

    /// The padding around the toolbar content.
    public let padding: EdgeInsets

    /// Whether to show a divider below the toolbar.
    public let dividerColor: Color?

    public init(
        key: (any Key)? = nil,
        height: Double = 52,
        title: Widget? = nil,
        leading: Widget? = nil,
        actions: [Widget] = [],
        titleAlignment: Alignment = .center,
        decoration: BoxDecoration? = nil,
        padding: EdgeInsets = EdgeInsets(horizontal: 8),
        dividerColor: Color? = nil
    ) {
        self.height = height
        self.title = title
        self.leading = leading
        self.actions = actions
        self.titleAlignment = titleAlignment
        self.decoration = decoration
        self.padding = padding
        self.dividerColor = dividerColor
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgDecoration = decoration ?? BoxDecoration(
            color: isDark
                ? Color(rgbo: 50, 50, 50, 1.0)
                : Color(rgbo: 246, 246, 246, 1.0)
        )

        var rowChildren: [Widget] = []

        if let leading = leading {
            rowChildren.append(leading)
            rowChildren.append(SizedBox(width: 8))
        }

        if let title = title {
            rowChildren.append(
                Expanded(
                    child: Align(
                        alignment: titleAlignment,
                        child: title
                    )
                )
            )
        } else {
            rowChildren.append(Expanded(child: SizedBox(shrink: ())))
        }

        if !actions.isEmpty {
            rowChildren.append(SizedBox(width: 8))
            for action in actions {
                rowChildren.append(action)
            }
        }

        return SizedBox(
            height: height,
            child: DecoratedBox(
                decoration: bgDecoration,
                child: Padding(
                    padding: padding,
                    child: Row(children: rowChildren)
                )
            )
        )
    }
}

// MARK: - TitleBar

/// A title bar displayed above the toolbar.
///
/// Contains the window title and optionally traffic light buttons.
/// Default height is 28dp.
public class TitleBar: StatelessWidget {
    public let height: Double
    public let title: Widget?
    public let padding: EdgeInsets
    public let decoration: BoxDecoration?

    public init(
        key: (any Key)? = nil,
        height: Double = 28,
        title: Widget? = nil,
        padding: EdgeInsets = EdgeInsets(horizontal: 8),
        decoration: BoxDecoration? = nil
    ) {
        self.height = height
        self.title = title
        self.padding = padding
        self.decoration = decoration
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)

        let bgDecoration = decoration ?? BoxDecoration(
            color: theme.canvasColor
        )

        return SizedBox(
            height: height,
            child: DecoratedBox(
                decoration: bgDecoration,
                child: Padding(
                    padding: padding,
                    child: Center(
                        child: title ?? SizedBox(shrink: ())
                    )
                )
            )
        )
    }
}
