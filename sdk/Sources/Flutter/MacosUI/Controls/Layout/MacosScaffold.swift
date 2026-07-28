// MacosScaffold ported from macos_ui/lib/src/layout/scaffold.dart

import FlutterSwiftBridge

// MARK: - MacosScaffold

/// A macOS-style scaffold providing sidebar, toolbar, and content area layout.
///
/// Layout: sidebar on the left (full height), toolbar + content on the right.
/// The sidebar extends from top to bottom; the toolbar sits above the content
/// area on the right side only — matching macOS System Preferences.
public class MacosScaffold: StatelessWidget {
    /// The main content of the scaffold. Typically [MacosSidebar, Expanded(content)].
    public let children: [Widget]

    /// An optional toolbar displayed at the top of the content area (right side).
    public let toolBar: MacosToolBar?

    /// The background color for the scaffold.
    public let backgroundColor: Color?

    public init(
        key: (any Key)? = nil,
        children: [Widget] = [],
        toolBar: MacosToolBar? = nil,
        backgroundColor: Color? = nil
    ) {
        self.children = children
        self.toolBar = toolBar
        self.backgroundColor = backgroundColor
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)

        // Separate the sidebar (first child if it's a MacosSidebar) from content
        var sidebar: Widget? = nil
        var contentChildren: [Widget] = []

        for child in children {
            if sidebar == nil, child is MacosSidebar {
                sidebar = child
            } else {
                contentChildren.append(child)
            }
        }

        // Build the right-side column: toolbar + divider + content
        var rightColumnChildren: [Widget] = []

        if let toolbar = toolBar {
            rightColumnChildren.append(toolbar)
            rightColumnChildren.append(
                SizedBox(
                    height: 1,
                    child: DecoratedBox(
                        decoration: BoxDecoration(color: theme.dividerColor)
                    )
                )
            )
        }

        if contentChildren.count == 1 {
            rightColumnChildren.append(Expanded(child: contentChildren[0]))
        } else if contentChildren.count > 1 {
            rightColumnChildren.append(
                Expanded(child: Row(children: contentChildren))
            )
        } else {
            rightColumnChildren.append(Expanded(child: SizedBox(expand: ())))
        }

        let rightSide: Widget = Expanded(
            child: Column(children: rightColumnChildren)
        )

        // Compose: sidebar | right-side
        var rowChildren: [Widget] = []
        if let sidebar = sidebar {
            rowChildren.append(sidebar)
        }
        rowChildren.append(rightSide)

        return DecoratedBox(
            decoration: BoxDecoration(color: backgroundColor ?? theme.canvasColor),
            child: Row(children: rowChildren)
        )
    }
}
