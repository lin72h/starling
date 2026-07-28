// ContentArea ported from macos_ui/lib/src/layout/content_area.dart

import FlutterSwiftBridge

// MARK: - ContentArea

/// The main content area in a MacosScaffold layout.
///
/// Typically used as the right side of a sidebar/content split.
public class ContentArea: StatelessWidget {
    public let builder: (_ context: any BuildContext, _ scrollController: ScrollController) -> Widget
    public let minWidth: Double

    public init(
        key: (any Key)? = nil,
        minWidth: Double = 400,
        builder: @escaping (_ context: any BuildContext, _ scrollController: ScrollController) -> Widget
    ) {
        self.builder = builder
        self.minWidth = minWidth
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let scrollController = ScrollController()
        return ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: builder(context, scrollController)
        )
    }
}

// MARK: - MacosListTile

/// A list item with optional leading, title, subtitle, and trailing widgets.
///
/// Follows macOS list row conventions.
public class MacosListTile: StatelessWidget {
    public let leading: Widget?
    public let title: Widget
    public let subtitle: Widget?
    public let trailing: Widget?
    public let onTap: (() -> Void)?
    public let padding: EdgeInsets

    public init(
        key: (any Key)? = nil,
        leading: Widget? = nil,
        title: Widget,
        subtitle: Widget? = nil,
        trailing: Widget? = nil,
        onTap: (() -> Void)? = nil,
        padding: EdgeInsets = EdgeInsets(horizontal: 16, vertical: 8)
    ) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.onTap = onTap
        self.padding = padding
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        var rowChildren: [Widget] = []

        if let leading = leading {
            rowChildren.append(leading)
            rowChildren.append(SizedBox(width: 12))
        }

        var titleColumn: [Widget] = [title]
        if let subtitle = subtitle {
            titleColumn.append(SizedBox(height: 2))
            titleColumn.append(subtitle)
        }

        rowChildren.append(
            Expanded(
                child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: titleColumn
                )
            )
        )

        if let trailing = trailing {
            rowChildren.append(SizedBox(width: 12))
            rowChildren.append(trailing)
        }

        let content = Padding(
            padding: padding,
            child: Row(children: rowChildren)
        )

        if let onTap = onTap {
            return GestureDetector(onTap: onTap, child: content)
        }
        return content
    }
}
