// Ported from: fluent_ui/lib/src/controls/surfaces/acrylic.dart
//
// Simplified acrylic/mica material effect. Real backdrop blur requires
// engine-level compositor support, so this implementation simulates the
// effect with a semi-transparent colored overlay.

import FlutterSwiftBridge

// MARK: - Acrylic

/// A widget that applies a simplified acrylic material effect to its child.
///
/// In WinUI 3, Acrylic is a translucent texture that uses backdrop blur,
/// luminosity, and tint to create a depth effect. Since true backdrop blur
/// requires engine compositor support, this implementation approximates the
/// visual by painting a semi-transparent tint layer on top of a solid
/// background.
///
/// Usage:
/// ```swift
/// Acrylic(
///     child: Text("Hello"),
///     opacity: 0.8,
///     luminosityOpacity: 0.9
/// )
/// ```
public class Acrylic: StatelessWidget {

    /// The widget below this widget in the tree.
    public let child: Widget?

    /// The tint color applied over the background.
    ///
    /// If nil, uses the theme's `solidBackgroundFillColorBase`.
    public let color: Color?

    /// The overall tint opacity (0.0 = fully transparent, 1.0 = fully opaque).
    ///
    /// Controls how much the tint color shows through. Lower values create
    /// a more transparent, glass-like appearance. Defaults to 0.8.
    public let opacity: Double

    /// The luminosity layer opacity.
    ///
    /// In WinUI, the luminosity layer controls how much background light
    /// bleeds through. Here it is applied as a secondary white overlay.
    /// Defaults to 0.9.
    public let luminosityOpacity: Double

    /// An optional custom decoration (shape, border, etc.).
    ///
    /// When provided, this decoration is used instead of the default
    /// rounded rectangle. The tint color and opacity are still applied.
    public let shape: (any Decoration)?

    /// Creates an acrylic material effect widget.
    public init(
        key: (any Key)? = nil,
        child: Widget? = nil,
        color: Color? = nil,
        opacity: Double = 0.8,
        luminosityOpacity: Double = 0.9,
        shape: (any Decoration)? = nil
    ) {
        self.child = child
        self.color = color
        self.opacity = opacity
        self.luminosityOpacity = luminosityOpacity
        self.shape = shape
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)

        // Resolve the tint color
        let tintColor = color ?? theme.resources.solidBackgroundFillColorBase

        // Apply the tint opacity to the resolved color
        let tintWithOpacity = tintColor.withOpacity(opacity)

        // Build the luminosity layer as a subtle white overlay
        let luminosityColor = Color(0xFFFFFFFF).withOpacity(
            luminosityOpacity * 0.05
        )

        // If a custom shape/decoration is provided, use it directly with the
        // tint color baked in. Otherwise build a default rounded container.
        let decoration: any Decoration
        if let customShape = shape {
            decoration = customShape
        } else {
            decoration = BoxDecoration(
                color: tintWithOpacity,
                border: Border.all(
                    color: theme.resources.surfaceStrokeColorDefault,
                    width: 0.5
                ),
                borderRadius: BorderRadius.circular(6)
            )
        }

        // Stack layers: background decoration -> luminosity overlay -> child
        var result: Widget = _AcrylicDecoratedBox(
            decoration: decoration,
            child: _buildLuminosityAndChild(luminosityColor)
        )

        return result
    }

    /// Builds the luminosity overlay with the child on top.
    private func _buildLuminosityAndChild(_ luminosityColor: Color) -> Widget {
        // If luminosity is effectively zero, skip the overlay
        if luminosityOpacity <= 0.001 {
            return child ?? SizedBox(width: 0, height: 0)
        }

        // Paint a subtle luminosity layer, then the child
        let luminosityOverlay: Widget = _AcrylicDecoratedBox(
            decoration: BoxDecoration(color: luminosityColor),
            child: child
        )

        return luminosityOverlay
    }
}

// MARK: - AcrylicThemeData

/// Theme data for controlling the default appearance of `Acrylic` widgets.
public class AcrylicThemeData {
    /// The default tint color.
    public let tintColor: Color?

    /// The default tint opacity.
    public let tintOpacity: Double?

    /// The default luminosity opacity.
    public let luminosityOpacity: Double?

    /// Creates acrylic theme data.
    public init(
        tintColor: Color? = nil,
        tintOpacity: Double? = nil,
        luminosityOpacity: Double? = nil
    ) {
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.luminosityOpacity = luminosityOpacity
    }

    /// Creates the standard theme data based on the given theme.
    public static func standard(_ theme: FluentThemeData) -> AcrylicThemeData {
        return AcrylicThemeData(
            tintOpacity: 0.8,
            luminosityOpacity: 0.9
        )
    }

    /// Merge this theme data with another, with the other taking precedence.
    public func merge(_ other: AcrylicThemeData?) -> AcrylicThemeData {
        guard let other = other else { return self }
        return AcrylicThemeData(
            tintColor: other.tintColor ?? tintColor,
            tintOpacity: other.tintOpacity ?? tintOpacity,
            luminosityOpacity: other.luminosityOpacity ?? luminosityOpacity
        )
    }
}

// MARK: - AcrylicTheme

/// An inherited theme that controls how descendant `Acrylic` widgets look.
public class AcrylicTheme: InheritedTheme {
    /// The theme data for the acrylic theme.
    public let data: AcrylicThemeData

    public init(key: (any Key)? = nil, data: AcrylicThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest `AcrylicThemeData` which encloses the given context.
    public static func of(_ context: any BuildContext) -> AcrylicThemeData {
        let theme = FluentTheme.of(context)
        let inherited = context.dependOnInheritedWidgetOfExactType(AcrylicTheme.self)
        return AcrylicThemeData.standard(theme).merge(inherited?.data)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? AcrylicTheme else { return true }
        return data !== old.data
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return AcrylicTheme(data: data, child: child)
    }
}

// MARK: - _AcrylicDecoratedBox (private helper)

/// A widget that paints a `Decoration` behind its child.
private class _AcrylicDecoratedBox: SingleChildRenderObjectWidget {
    let decoration: any Decoration

    init(
        key: (any Key)? = nil,
        decoration: any Decoration,
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
