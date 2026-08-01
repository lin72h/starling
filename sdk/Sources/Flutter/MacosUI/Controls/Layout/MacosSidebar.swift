// MacosSidebar ported from macos_ui/lib/src/layout/sidebar/sidebar.dart

import FlutterSwiftBridge

// MARK: - MacosSidebar

/// A sidebar widget that sits on the left side of a MacosScaffold.
///
/// Provides navigation with a list of items and optional header/footer.
public class MacosSidebar: StatelessWidget {
    /// The minimum width of the sidebar. Defaults to 200.
    public let minWidth: Double

    /// The maximum width of the sidebar. Defaults to 300.
    public let maxWidth: Double

    /// The top-level widget displayed above sidebar items.
    public let top: Widget?

    /// The bottom widget displayed below sidebar items.
    public let bottom: Widget?

    /// The builder for the sidebar content.
    public let builder: (_ context: any BuildContext, _ scrollController: ScrollController) -> Widget

    /// The background color of the sidebar.
    public let decoration: BoxDecoration?

    public init(
        key: (any Key)? = nil,
        minWidth: Double = 200,
        maxWidth: Double = 300,
        top: Widget? = nil,
        bottom: Widget? = nil,
        decoration: BoxDecoration? = nil,
        builder: @escaping (_ context: any BuildContext, _ scrollController: ScrollController) -> Widget
    ) {
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.top = top
        self.bottom = bottom
        self.decoration = decoration
        self.builder = builder
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgDecoration = decoration ?? BoxDecoration(
            color: isDark
                ? Color(rgbo: 45, 45, 45, 1.0)
                : Color(rgbo: 236, 236, 236, 1.0),
            border: Border(
                right: BorderSide(color: theme.dividerColor, width: 1)
            )
        )

        var columnChildren: [Widget] = []

        if let top = top {
            columnChildren.append(top)
        }

        let scrollController = ScrollController()
        columnChildren.append(
            Expanded(child: builder(context, scrollController))
        )

        if let bottom = bottom {
            columnChildren.append(bottom)
        }

        return ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: minWidth,
                maxWidth: maxWidth
            ),
            child: DecoratedBox(
                decoration: bgDecoration,
                child: Column(children: columnChildren)
            )
        )
    }
}

// MARK: - SidebarItem

/// An individual item in a MacosSidebar.
public class SidebarItem: StatelessWidget {
    public let leading: Widget?
    public let label: Widget
    public let trailing: Widget?
    public let selected: Bool
    public let onTap: (() -> Void)?

    public init(
        key: (any Key)? = nil,
        leading: Widget? = nil,
        label: Widget,
        trailing: Widget? = nil,
        selected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.leading = leading
        self.label = label
        self.trailing = trailing
        self.selected = selected
        self.onTap = onTap
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bgColor: Color = selected
            ? (isDark
                ? Color(rgbo: 255, 255, 255, 0.1)
                : Color(rgbo: 0, 0, 0, 0.06))
            : MacosColors.transparent

        var rowChildren: [Widget] = []
        if let leading = leading {
            rowChildren.append(leading)
            rowChildren.append(SizedBox(width: 8))
        }
        rowChildren.append(Expanded(child: label))
        if let trailing = trailing {
            rowChildren.append(SizedBox(width: 8))
            rowChildren.append(trailing)
        }

        return GestureDetector(
            onTap: onTap,
            behavior: .opaque,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.all(Radius(circular: 5))
                ),
                child: Padding(
                    padding: EdgeInsets(horizontal: 10, vertical: 6),
                    child: Row(children: rowChildren)
                )
            )
        )
    }
}
