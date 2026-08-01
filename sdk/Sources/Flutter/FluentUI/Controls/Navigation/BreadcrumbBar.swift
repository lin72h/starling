// Ported from: fluent_ui/lib/src/controls/navigation/breadcrumb_bar.dart

import FlutterSwiftBridge

// MARK: - BreadcrumbOverflowBehavior

/// Determines how a `BreadcrumbBar` handles overflow.
public enum BreadcrumbOverflowBehavior {
    /// Items wrap to the next line when they overflow.
    case wrap

    /// Items are scrollable when they overflow.
    case scrolling
}

// MARK: - BreadcrumbItem

/// An item displayed in a `BreadcrumbBar`.
///
/// Each item contains a `label` widget (usually `Text`) and an associated
/// `value` of a generic type.
public class BreadcrumbItem<T> {
    /// The label of the item. Usually a `Text` widget.
    public let label: Widget

    /// The value associated with the item.
    public let value: T

    /// Creates a breadcrumb item.
    public init(label: Widget, value: T) {
        self.label = label
        self.value = value
    }
}

// MARK: - BreadcrumbBar

/// A navigation trail showing the path to the current location.
///
/// `BreadcrumbBar` displays a horizontal list of items representing the
/// user's navigation path, such as folders in a file system. Users can click
/// any item (except the last/current one) to navigate back to that location.
public class BreadcrumbBar<T>: StatelessWidget {
    /// The items rendered in the bar.
    public let items: [BreadcrumbItem<T>]

    /// Called when an item is pressed.
    public let onItemPressed: ((BreadcrumbItem<T>) -> Void)?

    /// How to handle overflow when items don't fit.
    public let overflowBehavior: BreadcrumbOverflowBehavior

    /// The size of the chevron separator icon.
    public let chevronIconSize: Double

    /// Creates a breadcrumb bar.
    public init(
        key: (any Key)? = nil,
        items: [BreadcrumbItem<T>],
        onItemPressed: ((BreadcrumbItem<T>) -> Void)? = nil,
        overflowBehavior: BreadcrumbOverflowBehavior = .wrap,
        chevronIconSize: Double = 8.0
    ) {
        self.items = items
        self.onItemPressed = onItemPressed
        self.overflowBehavior = overflowBehavior
        self.chevronIconSize = chevronIconSize
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        if items.isEmpty {
            return SizedBox(width: 0, height: 0)
        }

        // Build the list of item widgets with chevron separators
        var rowChildren: [Widget] = []

        for i in 0..<items.count {
            let item = items[i]
            let isLastItem = i == items.count - 1

            // Build the item label
            let itemWidget: Widget = _buildBreadcrumbItem(
                context,
                item: item,
                isLastItem: isLastItem,
                theme: theme
            )

            rowChildren.append(itemWidget)

            // Add chevron separator (not after last item)
            if !isLastItem {
                let chevron: Widget = Padding(
                    padding: EdgeInsets(left: 6, top: 0, right: 6, bottom: 0),
                    child: Text(
                        "\u{203A}",  // single right-pointing angle quotation mark
                        style: TextStyle(
                            color: theme.resources.textFillColorPrimary,
                            fontSize: chevronIconSize + 4
                        )
                    )
                )
                rowChildren.append(chevron)
            }
        }

        // Layout based on overflow behavior
        switch overflowBehavior {
        case .wrap:
            return Wrap(
                crossAxisAlignment: .center,
                children: rowChildren
            )
        case .scrolling:
            return ClipRect(
                child: Row(
                    mainAxisSize: .min,
                    children: rowChildren
                )
            )
        }
    }

    // MARK: - Item Builder

    private func _buildBreadcrumbItem(
        _ context: any BuildContext,
        item: BreadcrumbItem<T>,
        isLastItem: Bool,
        theme: FluentThemeData
    ) -> Widget {
        // The last item is the current page (non-interactive)
        if isLastItem {
            return DefaultTextStyle(
                style: TextStyle(
                    color: theme.resources.textFillColorPrimary,
                    fontWeight: .w600
                ),
                child: item.label
            )
        }

        // Interactive items
        return HoverButton(
            builder: { context, states in
                let foregroundColor: Color = {
                    if states.isDisabled {
                        return theme.resources.textFillColorDisabled
                    } else if states.isPressed {
                        return theme.resources.textFillColorTertiary
                    } else if states.isHovered {
                        return theme.resources.textFillColorPrimary
                    } else {
                        return theme.resources.textFillColorSecondary
                    }
                }()

                return DefaultTextStyle(
                    style: TextStyle(color: foregroundColor),
                    child: item.label
                )
            },
            onPressed: onItemPressed == nil
                ? nil
                : { [weak self] in
                    self?.onItemPressed?(item)
                }
        )
    }
}
