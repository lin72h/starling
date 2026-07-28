// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/utils/divider.dart

import FlutterSwiftBridge

// MARK: - Divider

/// A thin line used to separate content into groups.
///
/// Dividers help organize content and establish visual hierarchy by creating
/// clear boundaries between sections or items.
public class Divider: StatelessWidget {
    /// The direction of the divider.
    /// Use `.horizontal` for a line that spans horizontally (default).
    /// Use `.vertical` for a line that spans vertically.
    public let direction: Axis

    /// The style of the divider.
    public let style: DividerThemeData?

    /// The size of the divider (the dimension opposite to the thickness).
    public let size: Double?

    public init(
        key: (any Key)? = nil,
        direction: Axis = .horizontal,
        style: DividerThemeData? = nil,
        size: Double? = nil
    ) {
        self.direction = direction
        self.style = style
        self.size = size
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let resolvedStyle = DividerTheme.of(context).merge(self.style)
        let thickness = resolvedStyle.thickness ?? 1.0

        let boxDecoration = resolvedStyle.decoration ?? BoxDecoration(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault
        )

        let height: Double? = direction == .horizontal ? thickness : size
        let width: Double? = direction == .vertical ? thickness : size

        // Build: DecoratedBox with a SizedBox to constrain dimensions
        var child: Widget = _DividerBox(
            decoration: boxDecoration,
            boxWidth: width,
            boxHeight: height
        )

        // Apply margin
        let margin: EdgeInsets? = direction == .horizontal
            ? resolvedStyle.horizontalMargin
            : resolvedStyle.verticalMargin
        if let margin = margin {
            child = Padding(padding: margin, child: child)
        }

        return child
    }
}

// MARK: - _DividerBox

/// Internal widget that paints a decoration with optional fixed dimensions.
private class _DividerBox: SingleChildRenderObjectWidget {
    let decoration: BoxDecoration
    let boxWidth: Double?
    let boxHeight: Double?

    init(
        key: (any Key)? = nil,
        decoration: BoxDecoration,
        boxWidth: Double?,
        boxHeight: Double?
    ) {
        self.decoration = decoration
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
        super.init(key: key, child: nil)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderDividerBox(
            decoration: decoration,
            boxWidth: boxWidth,
            boxHeight: boxHeight
        )
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! _RenderDividerBox
        ro.decoration = decoration
        ro.boxWidth = boxWidth
        ro.boxHeight = boxHeight
    }
}

private class _RenderDividerBox: RenderDecoratedBox {
    var boxWidth: Double? {
        didSet { if boxWidth != oldValue { markNeedsLayout() } }
    }
    var boxHeight: Double? {
        didSet { if boxHeight != oldValue { markNeedsLayout() } }
    }

    init(decoration: BoxDecoration, boxWidth: Double?, boxHeight: Double?) {
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
        super.init(decoration: decoration)
    }

    override func performLayout() {
        let boxConstraints = constraints as! BoxConstraints
        let width = boxWidth ?? boxConstraints.maxWidth
        let height = boxHeight ?? boxConstraints.maxHeight
        size = boxConstraints.constrain(Size(width, height))
    }
}

// MARK: - DividerTheme

/// An inherited theme that controls how descendant Dividers look.
public class DividerTheme: InheritedTheme {
    /// The theme data for the divider theme.
    public let data: DividerThemeData

    public init(key: (any Key)? = nil, data: DividerThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest DividerThemeData which encloses the given context.
    public static func of(_ context: any BuildContext) -> DividerThemeData {
        let theme = FluentTheme.of(context)
        let inherited = context.dependOnInheritedWidgetOfExactType(DividerTheme.self)
        return DividerThemeData.standard(theme).merge(inherited?.data)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? DividerTheme else { return true }
        return data !== old.data
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return DividerTheme(data: data, child: child)
    }
}

// MARK: - DividerThemeData

/// Theme data for Divider widgets.
public class DividerThemeData {
    /// The thickness of the divider line.
    public let thickness: Double?

    /// The decoration of the divider.
    public let decoration: BoxDecoration?

    /// The horizontal margin (used when direction is horizontal).
    public let horizontalMargin: EdgeInsets?

    /// The vertical margin (used when direction is vertical).
    public let verticalMargin: EdgeInsets?

    public init(
        thickness: Double? = nil,
        decoration: BoxDecoration? = nil,
        horizontalMargin: EdgeInsets? = nil,
        verticalMargin: EdgeInsets? = nil
    ) {
        self.thickness = thickness
        self.decoration = decoration
        self.horizontalMargin = horizontalMargin
        self.verticalMargin = verticalMargin
    }

    /// Creates the standard DividerThemeData based on the given theme.
    public static func standard(_ theme: FluentThemeData) -> DividerThemeData {
        return DividerThemeData(
            thickness: 1,
            decoration: BoxDecoration(
                color: theme.resources.dividerStrokeColorDefault
            ),
            horizontalMargin: EdgeInsets(left: 10, right: 10),
            verticalMargin: EdgeInsets(top: 10, bottom: 10)
        )
    }

    /// Merge this theme data with another, with the other taking precedence.
    public func merge(_ other: DividerThemeData?) -> DividerThemeData {
        guard let other = other else { return self }
        return DividerThemeData(
            thickness: other.thickness ?? thickness,
            decoration: other.decoration ?? decoration,
            horizontalMargin: other.horizontalMargin ?? horizontalMargin,
            verticalMargin: other.verticalMargin ?? verticalMargin
        )
    }
}
