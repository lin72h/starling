// Ported from: fluent_ui/lib/src/controls/surfaces/card.dart

import FlutterSwiftBridge

// MARK: - Card

/// A Fluent Design card — a container that slightly separates its content
/// from the surrounding UI, giving it a subtle but distinct appearance.
///
/// Cards are commonly used to group related pieces of information.
public class Card: StatelessWidget {

    /// The widget below this widget in the tree.
    public let child: Widget

    /// The amount of space by which to inset the child.
    ///
    /// Defaults to `EdgeInsets(all: 12)`.
    public let padding: EdgeInsets

    /// Empty space to surround the card.
    public let margin: EdgeInsets?

    /// The card's background color.
    ///
    /// If nil, defaults to `FluentThemeData.cardColor`.
    public let backgroundColor: Color?

    /// The color of the card's border.
    ///
    /// If nil, defaults to `ResourceDictionary.cardStrokeColorDefault`.
    public let borderColor: Color?

    /// The border radius of the card's corners.
    ///
    /// Defaults to `BorderRadius.all(Radius(circular: 4))`.
    public let borderRadius: BorderRadius

    public init(
        key: (any Key)? = nil,
        child: Widget,
        padding: EdgeInsets = EdgeInsets(all: 12),
        margin: EdgeInsets? = nil,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        borderRadius: BorderRadius = BorderRadius.all(Radius(circular: 4))
    ) {
        self.child = child
        self.padding = padding
        self.margin = margin
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderRadius = borderRadius
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        let decoration = BoxDecoration(
            color: backgroundColor ?? theme.cardColor,
            border: Border.all(
                color: borderColor ?? theme.resources.cardStrokeColorDefault
            ),
            borderRadius: borderRadius
        )

        var result: Widget = Padding(padding: padding, child: child)
        result = _DecoratedBox(decoration: decoration, child: result)

        if let margin = margin {
            result = Padding(padding: margin, child: result)
        }

        return result
    }
}

// MARK: - _DecoratedBox (private helper)

/// A widget that paints a `Decoration` behind its child.
///
/// This is a minimal port of Flutter's `DecoratedBox` widget.
private class _DecoratedBox: SingleChildRenderObjectWidget {
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
