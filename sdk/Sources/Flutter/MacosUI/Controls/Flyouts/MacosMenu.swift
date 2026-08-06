// MacosMenu — the macOS context / pull-down menu.
//
// The Fluent `MenuFlyout` was standing in for this everywhere the desktop
// needed a right-click menu, which is why the shell's menus looked like
// Windows: square-ish panel, full-bleed hover band, Fluent divider. This is
// the macOS shape instead — a rounded slab, items inset from the panel edge so
// the selection pill floats inside it, accent-filled selection with white
// text, and hairline separators.
//
// Metrics follow AppKit's NSMenu at default control size: 22pt rows, 13pt
// text, 5pt panel inset, 4pt pill radius on a 6pt panel radius.

import FlutterSwiftBridge

// MARK: - Metrics

/// Height of a standard menu row.
public let kMacosMenuItemHeight: Double = 22

/// Inset from the panel edge to a row's selection pill.
public let kMacosMenuHorizontalInset: Double = 5

/// Padding above and below the item column.
public let kMacosMenuVerticalPadding: Double = 4

/// Corner radius of the menu panel.
public let kMacosMenuRadius: Double = 6

/// Corner radius of a row's selection pill.
public let kMacosMenuItemRadius: Double = 4

// MARK: - MacosMenuEntry

/// Base class for anything that can appear in a `MacosMenu`.
///
/// Mirrors the shape of the Fluent `MenuFlyoutItemBase` it replaces so call
/// sites convert one line at a time.
open class MacosMenuEntry {
    public let key: (any Key)?

    public init(key: (any Key)? = nil) {
        self.key = key
    }

    /// Builds this entry. `showLeadingGutter` is true when any sibling has a
    /// leading widget, so text stays aligned down the column. `highlighted`
    /// and `onHover` are owned by the menu — see `_MacosMenuState` for why a
    /// row cannot track its own hover.
    open func buildEntry(_ context: any BuildContext,
                         brightness: Brightness,
                         accentColor: Color,
                         showLeadingGutter: Bool,
                         highlighted: Bool,
                         onHover: @escaping () -> Void) -> Widget {
        fatalError("Subclasses must override buildEntry")
    }
}

// MARK: - MacosMenuItem

/// A single command in a `MacosMenu`.
///
/// `text` is a String rather than a Widget: menu rows are text plus optional
/// affordances in AppKit, and taking a Widget invites callers to rebuild the
/// row's typography by hand, which is how a menu stops looking like a menu.
public class MacosMenuItem: MacosMenuEntry {
    public let text: String
    public let leading: Widget?
    /// Trailing affordance — a keyboard shortcut hint, a submenu chevron.
    public let trailing: Widget?
    /// nil disables the row (dimmed, no hover, no hit).
    public let onPressed: (() -> Void)?
    /// Destructive commands render in the system red, as in AppKit.
    public let isDestructive: Bool
    /// Draws the checkmark gutter macOS uses for a chosen option.
    public let isSelected: Bool

    public init(
        key: (any Key)? = nil,
        text: String,
        leading: Widget? = nil,
        trailing: Widget? = nil,
        onPressed: (() -> Void)? = nil,
        isDestructive: Bool = false,
        isSelected: Bool = false
    ) {
        self.text = text
        self.leading = leading
        self.trailing = trailing
        self.onPressed = onPressed
        self.isDestructive = isDestructive
        self.isSelected = isSelected
        super.init(key: key)
    }

    public override func buildEntry(_ context: any BuildContext,
                                    brightness: Brightness,
                                    accentColor: Color,
                                    showLeadingGutter: Bool,
                                    highlighted: Bool,
                                    onHover: @escaping () -> Void) -> Widget {
        return _MacosMenuItemRow(
            item: self,
            brightness: brightness,
            accentColor: accentColor,
            showLeadingGutter: showLeadingGutter,
            highlighted: highlighted,
            onHover: onHover
        )
    }
}

// MARK: - MacosMenuSeparator

/// A hairline rule between groups of commands.
public class MacosMenuSeparator: MacosMenuEntry {
    public override init(key: (any Key)? = nil) {
        super.init(key: key)
    }

    public override func buildEntry(_ context: any BuildContext,
                                    brightness: Brightness,
                                    accentColor: Color,
                                    showLeadingGutter: Bool,
                                    highlighted: Bool,
                                    onHover: @escaping () -> Void) -> Widget {
        // AppKit insets the rule to the panel's text margin, not the full
        // width — a full-bleed line reads as a Windows menu.
        let line = brightness == .dark
            ? Color(0x26FFFFFF)
            : Color(0x1A000000)
        return Padding(
            padding: EdgeInsets(left: kMacosMenuHorizontalInset,
                                top: 4,
                                right: kMacosMenuHorizontalInset,
                                bottom: 4),
            child: SizedBox(
                height: 1,
                child: ColoredBox(color: line, child: SizedBox(expand: ()))
            )
        )
    }
}

// MARK: - _MacosMenuItemRow

/// One rendered row. Stateless on purpose: which row is highlighted is the
/// MENU's business, because moving from row A to row B has to clear A, and a
/// row that only ever hears about its own pointer can never learn it was left.
class _MacosMenuItemRow: StatelessWidget {
    let item: MacosMenuItem
    let brightness: Brightness
    let accentColor: Color
    let showLeadingGutter: Bool
    let highlighted: Bool
    let onHover: () -> Void

    init(item: MacosMenuItem, brightness: Brightness,
         accentColor: Color, showLeadingGutter: Bool,
         highlighted: Bool, onHover: @escaping () -> Void) {
        self.item = item
        self.brightness = brightness
        self.accentColor = accentColor
        self.showLeadingGutter = showLeadingGutter
        self.highlighted = highlighted
        self.onHover = onHover
        super.init(key: nil)
    }

    override func build(_ context: any BuildContext) -> Widget {
        let enabled = item.onPressed != nil
        let isHighlighted = enabled && highlighted

        // Highlighted rows in AppKit fill with the accent and flip the label
        // to white — including destructive ones, which lose their red only
        // while highlighted.
        let labelColor: Color
        if !enabled {
            labelColor = MacosColors.tertiaryLabelColor(for: brightness)
        } else if isHighlighted {
            labelColor = MacosColors.selectedMenuItemTextColor
        } else if item.isDestructive {
            labelColor = MacosColors.systemRed(for: brightness)
        } else {
            labelColor = MacosColors.labelColor(for: brightness)
        }

        var rowChildren: [Widget] = []
        if showLeadingGutter {
            rowChildren.append(
                SizedBox(
                    width: 16,
                    height: 16,
                    child: item.leading ?? (item.isSelected
                        ? Center(child: Text("\u{2713}", style: TextStyle(
                            color: labelColor, fontSize: 12)))
                        : SizedBox(shrink: ()))
                )
            )
            rowChildren.append(SizedBox(width: 6))
        }
        rowChildren.append(
            Expanded(
                child: Text(
                    item.text,
                    style: TextStyle(
                        color: labelColor,
                        fontSize: 13,
                        fontWeight: .w400
                    ),
                    overflow: .ellipsis,
                    maxLines: 1
                )
            )
        )
        if let trailing = item.trailing {
            rowChildren.append(SizedBox(width: 12))
            rowChildren.append(trailing)
        }

        let content: Widget = Padding(
            padding: EdgeInsets(horizontal: 8),
            child: Row(
                mainAxisSize: .max,
                crossAxisAlignment: .center,
                children: rowChildren
            )
        )

        let pill: Widget = SizedBox(
            height: kMacosMenuItemHeight,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: isHighlighted ? accentColor : Color(0x00000000),
                    borderRadius: BorderRadius.all(
                        Radius(circular: kMacosMenuItemRadius))
                ),
                child: content
            )
        )

        let inset: Widget = Padding(
            padding: EdgeInsets(horizontal: kMacosMenuHorizontalInset),
            child: pill
        )

        // A disabled row must not report hover or swallow the tap, but it
        // still occupies its slot.
        guard enabled else { return inset }

        // Hover comes from Listener.onPointerHover, NOT MouseRegion.
        // MouseRegion is fully implemented here and its taps work, but its
        // enter/exit never fire under the DRM embedder — which is why every
        // hover in the shell is already written this way. `.opaque` so the row
        // claims the pointer instead of letting the panel answer as well.
        return Listener(
            onPointerHover: { [self] _ in onHover() },
            behavior: .opaque,
            child: GestureDetector(
                onTap: item.onPressed,
                child: inset
            )
        )
    }
}

// MARK: - MacosMenu

/// A macOS context menu panel.
///
/// Draws the slab and lays out `items`; positioning and dismissal belong to
/// the caller, which already owns the anchor and the dismiss barrier.
///
/// ```swift
/// MacosMenu(
///     brightness: .dark,
///     items: [
///         MacosMenuItem(text: "Show", onPressed: { … }),
///         MacosMenuItem(text: "Quit", onPressed: { … }),
///         MacosMenuSeparator(),
///         MacosMenuItem(text: "Remove from Dock", onPressed: { … }),
///     ]
/// )
/// ```
public class MacosMenu: StatefulWidget {
    public let items: [MacosMenuEntry]
    /// Light or dark slab. Defaults to the ambient `MacosTheme`.
    public let brightness: Brightness?
    /// Selection fill. Defaults to the ambient theme's accent.
    public let accentColor: Color?
    /// Panel fill. Defaults to a near-opaque slab for the brightness.
    public let backgroundColor: Color?
    /// Minimum panel width. AppKit menus are never hairline-thin.
    public let minWidth: Double

    public init(
        key: (any Key)? = nil,
        items: [MacosMenuEntry] = [],
        brightness: Brightness? = nil,
        accentColor: Color? = nil,
        backgroundColor: Color? = nil,
        minWidth: Double = 160
    ) {
        self.items = items
        self.brightness = brightness
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.minWidth = minWidth
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosMenuState()
    }
}

// MARK: - _MacosMenuState

/// Owns which row is highlighted.
///
/// It lives here rather than in the row because clearing is the hard half:
/// moving from one row to the next has to un-highlight the one you left, and a
/// row only ever hears about pointers inside itself. One index here means
/// hovering a row implicitly clears every other.
///
/// Known gap: leaving the panel sideways leaves the last row highlighted until
/// the pointer returns or the menu closes, because nothing reports the exit —
/// MouseRegion.onExit, which would, does not fire under this embedder.
class _MacosMenuState: State<StatefulWidget> {
    private var hoveredIndex: Int? = nil

    private var menu: MacosMenu {
        return widget as! MacosMenu
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.maybeOf(context)
        let resolvedBrightness = menu.brightness ?? theme?.brightness ?? .dark
        let isDark = resolvedBrightness == .dark
        let accent = menu.accentColor
            ?? theme?.primaryColor
            ?? MacosColors.systemBlue(for: resolvedBrightness)

        let slab = menu.backgroundColor ?? (isDark
            ? Color(0xF01E1E1E)
            : Color(0xF0F6F6F6))
        let border = isDark ? Color(0x40FFFFFF) : Color(0x26000000)

        // Reserve the leading gutter for every row as soon as ONE row needs
        // it, so labels stay on a single left edge. macOS does the same with
        // its checkmark column.
        let showLeadingGutter = menu.items.contains { entry in
            if let item = entry as? MacosMenuItem {
                return item.leading != nil || item.isSelected
            }
            return false
        }

        let rows: [Widget] = menu.items.enumerated().map { (index, entry) in
            entry.buildEntry(context,
                             brightness: resolvedBrightness,
                             accentColor: accent,
                             showLeadingGutter: showLeadingGutter,
                             highlighted: self.hoveredIndex == index,
                             onHover: {
                                 if self.hoveredIndex != index {
                                     self.setState { self.hoveredIndex = index }
                                 }
                             })
        }

        let column: Widget = Padding(
            padding: EdgeInsets(vertical: kMacosMenuVerticalPadding),
            child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: rows
            )
        )

        return ConstrainedBox(
            constraints: BoxConstraints(minWidth: menu.minWidth),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: slab,
                    border: Border.all(color: border, width: 1),
                    borderRadius: BorderRadius.all(
                        Radius(circular: kMacosMenuRadius)),
                    boxShadow: [
                        BoxShadow(
                            color: Color(0x59000000),
                            offset: Offset(0, 6),
                            blurRadius: 16
                        )
                    ]
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.all(
                        Radius(circular: kMacosMenuRadius)),
                    child: column
                )
            )
        )
    }
}
