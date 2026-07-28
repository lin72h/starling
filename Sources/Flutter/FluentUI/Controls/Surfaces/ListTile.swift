// Ported from: fluent_ui/lib/src/controls/surfaces/list_tile.dart

import FlutterSwiftBridge

// MARK: - Constants

/// The default minimum height of a one-line list tile.
public let kOneLineTileHeight: Double = 40.0

/// The default content padding of a list tile.
public let kDefaultListTilePadding = EdgeInsets(left: 12, top: 6, right: 12, bottom: 6)

/// The default margin of a list tile.
public let kDefaultListTileMargin = EdgeInsets(left: 4, top: 2, right: 4, bottom: 2)

// MARK: - ListTile

/// A Fluent Design list tile — a row-based layout with optional leading,
/// title, subtitle, and trailing widgets.
///
/// If `onPressed` is non-nil the tile is wrapped in a `HoverButton` for
/// interactive hover/press feedback.
public class ListTile: StatelessWidget {

    /// A widget to display before the title.
    ///
    /// Typically an icon or avatar.
    public let leading: Widget?

    /// The primary content of the list tile.
    public let title: Widget?

    /// Additional content displayed below the title.
    public let subtitle: Widget?

    /// A widget to display after the title.
    public let trailing: Widget?

    /// Called when the user taps this list tile.
    public let onPressed: (() -> Void)?

    /// The background color of the tile. Resolves against widget states.
    public let tileColor: Color?

    /// How the children should be placed along the cross axis.
    ///
    /// Defaults to `.center`.
    public let contentAlignment: CrossAxisAlignment

    /// Padding applied to the tile's content.
    public let contentPadding: EdgeInsets

    /// Margin around the tile.
    public let margin: EdgeInsets?

    /// The border radius of the tile's corners.
    public let borderRadius: BorderRadius

    public init(
        key: (any Key)? = nil,
        leading: Widget? = nil,
        title: Widget? = nil,
        subtitle: Widget? = nil,
        trailing: Widget? = nil,
        onPressed: (() -> Void)? = nil,
        tileColor: Color? = nil,
        contentAlignment: CrossAxisAlignment = .center,
        contentPadding: EdgeInsets = kDefaultListTilePadding,
        margin: EdgeInsets? = kDefaultListTileMargin,
        borderRadius: BorderRadius = BorderRadius.all(Radius(circular: 4))
    ) {
        self.leading = leading
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.onPressed = onPressed
        self.tileColor = tileColor
        self.contentAlignment = contentAlignment
        self.contentPadding = contentPadding
        self.margin = margin
        self.borderRadius = borderRadius
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        return HoverButton(
            builder: { [self] context, states in
                let resolvedColor = _resolveColor(theme: theme, states: states)

                let tile = _buildTile(theme: theme)

                let decoration = BoxDecoration(
                    color: resolvedColor,
                    borderRadius: borderRadius
                )

                var result: Widget = Padding(padding: contentPadding, child: tile)
                result = ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: 88,
                        minHeight: kOneLineTileHeight
                    ),
                    child: _ListTileDecoratedBox(decoration: decoration, child: result)
                )

                result = FocusBorder(child: result, focused: states.isFocused, renderOutside: false)

                if let margin = margin {
                    result = Padding(padding: margin, child: result)
                }

                return result
            },
            onPressed: onPressed
        )
    }

    // MARK: - Private Helpers

    private func _resolveColor(theme: FluentThemeData, states: Set<WidgetState>) -> Color {
        if let tileColor = tileColor {
            return tileColor
        }

        if states.isDisabled { return Color(0x00000000) }
        if states.isPressed {
            return theme.resources.subtleFillColorTertiary
        }
        if states.isHovered {
            return theme.resources.subtleFillColorSecondary
        }
        return Color(0x00000000)
    }

    private func _buildTile(theme: FluentThemeData) -> Widget {
        var columnChildren: [Widget] = []

        if let title = title {
            let titleStyle = (theme.typography.body ?? TextStyle()).copyWith(fontSize: 16)
            columnChildren.append(
                DefaultTextStyle(style: titleStyle, child: title)
            )
        }
        if let subtitle = subtitle {
            let captionStyle = theme.typography.caption ?? TextStyle()
            columnChildren.append(
                DefaultTextStyle(style: captionStyle, child: subtitle)
            )
        }

        var rowChildren: [Widget] = []

        // Leading placeholder / widget
        if let leading = leading {
            rowChildren.append(
                Padding(padding: EdgeInsets(left: 0, top: 0, right: 14, bottom: 0), child: leading)
            )
        } else {
            rowChildren.append(SizedBox(width: 12))
        }

        // Title / subtitle column
        rowChildren.append(
            Expanded(child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: columnChildren
            ))
        )

        // Trailing widget
        if let trailing = trailing {
            rowChildren.append(trailing)
        }

        return Row(
            crossAxisAlignment: contentAlignment,
            children: rowChildren
        )
    }
}

// MARK: - _ListTileDecoratedBox (private helper)

/// A widget that paints a `Decoration` behind its child.
private class _ListTileDecoratedBox: SingleChildRenderObjectWidget {
    let decoration: Decoration

    init(
        key: (any Key)? = nil,
        decoration: Decoration,
        child: Widget? = nil
    ) {
        self.decoration = decoration
        super.init(key: key, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderDecoratedBox(decoration: decoration)
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderDecoratedBox
        ro.decoration = decoration
    }
}
