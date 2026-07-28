// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/inputs/toggle_switch.dart

import FlutterSwiftBridge

// MARK: - ToggleSwitch

/// A toggle switch represents a physical switch that allows users to turn
/// things on or off, like a light switch.
///
/// Use toggle switch controls to present users with two mutually exclusive
/// options (such as on/off), where choosing an option provides immediate results.
public class ToggleSwitch: StatefulWidget {
    /// Whether this toggle switch is checked.
    public let checked: Bool

    /// Called when the value of the switch should change.
    /// If nil, the switch is considered disabled.
    public let onChanged: ((Bool) -> Void)?

    /// The style applied to the toggle switch.
    public let style: ToggleSwitchThemeData?

    /// The content displayed next to the switch (usually a label).
    public let content: Widget?

    /// Whether to position content before the switch.
    public let leadingContent: Bool

    public init(
        key: (any Key)? = nil,
        checked: Bool,
        onChanged: ((Bool) -> Void)?,
        style: ToggleSwitchThemeData? = nil,
        content: Widget? = nil,
        leadingContent: Bool = false
    ) {
        self.checked = checked
        self.onChanged = onChanged
        self.style = style
        self.content = content
        self.leadingContent = leadingContent
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _ToggleSwitchState()
    }
}

// MARK: - _ToggleSwitchState

class _ToggleSwitchState: State<StatefulWidget> {
    private var toggleSwitch: ToggleSwitch {
        return widget as! ToggleSwitch
    }

    private var isDisabled: Bool {
        return toggleSwitch.onChanged == nil
    }

    override func build(_ context: any BuildContext) -> Widget {
        let resolvedStyle = ToggleSwitchTheme.of(context).merge(toggleSwitch.style)

        return HoverButton(
            builder: { [self] context, states in
                // Resolve track decoration
                let trackDecoration: BoxDecoration? = toggleSwitch.checked
                    ? resolvedStyle.checkedDecoration?.resolve(states)
                    : resolvedStyle.uncheckedDecoration?.resolve(states)

                // Resolve knob decoration
                let knobDecoration: BoxDecoration? = toggleSwitch.checked
                    ? resolvedStyle.checkedKnobDecoration?.resolve(states)
                    : resolvedStyle.uncheckedKnobDecoration?.resolve(states)

                // Build knob — size changes on hover/press
                let knobWidth: Double = 12.0
                    + (states.isHovered ? 2.0 : 0.0)
                    + (states.isPressed ? 5.0 : 0.0)
                let knobMarginH: Double = states.isHovered ? 2.0 : 3.0
                let knobMarginV: Double = states.isHovered ? 2.0 : 3.0

                let knobBox: Widget = _ToggleSwitchBox(
                    decoration: knobDecoration ?? BoxDecoration(),
                    boxWidth: knobWidth,
                    boxHeight: 14.0
                )

                let knob: Widget = Padding(
                    padding: EdgeInsets(
                        left: knobMarginH,
                        top: knobMarginV,
                        right: knobMarginH,
                        bottom: knobMarginV
                    ),
                    child: knobBox
                )

                // Build track with knob aligned left or right
                let alignment: Alignment = toggleSwitch.checked
                    ? Alignment.centerRight
                    : Alignment.centerLeft

                var child: Widget = _ToggleSwitchTrack(
                    decoration: trackDecoration ?? BoxDecoration(),
                    trackWidth: 40.0,
                    trackHeight: 20.0,
                    alignment: alignment,
                    child: knob
                )

                // Add content label if provided
                if let labelContent = toggleSwitch.content {
                    let foregroundColor = resolvedStyle.foregroundColor?.resolve(states)
                    let inheritedStyle = DefaultTextStyle.of(context).style
                    let mergedStyle = inheritedStyle.merge(TextStyle(color: foregroundColor))
                    let label: Widget = DefaultTextStyle(
                        style: mergedStyle,
                        child: labelContent
                    )

                    let children: [Widget] = toggleSwitch.leadingContent
                        ? [label, SizedBox(width: 10), child]
                        : [child, SizedBox(width: 10), label]

                    child = Row(
                        mainAxisSize: .min,
                        children: children
                    )
                }

                return FocusBorder(
                    child: child,
                    focused: states.isFocused
                )
            },
            onPressed: isDisabled
                ? nil
                : { [toggleSwitch] in
                    toggleSwitch.onChanged?(!toggleSwitch.checked)
                }
        )
    }
}

// MARK: - _ToggleSwitchBox

/// Internal widget that renders a decorated box with a fixed size.
/// Used for the knob.
private class _ToggleSwitchBox: SingleChildRenderObjectWidget {
    let decoration: BoxDecoration
    let boxWidth: Double
    let boxHeight: Double

    init(
        key: (any Key)? = nil,
        decoration: BoxDecoration,
        boxWidth: Double,
        boxHeight: Double
    ) {
        self.decoration = decoration
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
        super.init(key: key, child: nil)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderToggleSwitchBox(
            decoration: decoration,
            boxWidth: boxWidth,
            boxHeight: boxHeight
        )
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! _RenderToggleSwitchBox
        ro.decoration = decoration
        ro.boxWidth = boxWidth
        ro.boxHeight = boxHeight
    }
}

private class _RenderToggleSwitchBox: RenderDecoratedBox {
    var boxWidth: Double {
        didSet { if boxWidth != oldValue { markNeedsLayout() } }
    }
    var boxHeight: Double {
        didSet { if boxHeight != oldValue { markNeedsLayout() } }
    }

    init(decoration: BoxDecoration, boxWidth: Double, boxHeight: Double) {
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
        super.init(decoration: decoration)
    }

    override func performLayout() {
        size = Size(boxWidth, boxHeight)
    }
}

// MARK: - _ToggleSwitchTrack

/// Internal widget that renders the track with a fixed size and aligned child (knob).
private class _ToggleSwitchTrack: SingleChildRenderObjectWidget {
    let decoration: BoxDecoration
    let trackWidth: Double
    let trackHeight: Double
    let alignment: Alignment

    init(
        key: (any Key)? = nil,
        decoration: BoxDecoration,
        trackWidth: Double,
        trackHeight: Double,
        alignment: Alignment,
        child: Widget? = nil
    ) {
        self.decoration = decoration
        self.trackWidth = trackWidth
        self.trackHeight = trackHeight
        self.alignment = alignment
        super.init(key: key, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderToggleSwitchTrack(
            decoration: decoration,
            trackWidth: trackWidth,
            trackHeight: trackHeight,
            alignment: alignment
        )
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! _RenderToggleSwitchTrack
        ro.decoration = decoration
        ro.trackWidth = trackWidth
        ro.trackHeight = trackHeight
        ro.alignment = alignment
    }
}

private class _RenderToggleSwitchTrack: RenderDecoratedBox {
    var trackWidth: Double {
        didSet { if trackWidth != oldValue { markNeedsLayout() } }
    }
    var trackHeight: Double {
        didSet { if trackHeight != oldValue { markNeedsLayout() } }
    }
    var alignment: Alignment {
        didSet { if alignment != oldValue { markNeedsLayout() } }
    }

    init(
        decoration: BoxDecoration,
        trackWidth: Double,
        trackHeight: Double,
        alignment: Alignment
    ) {
        self.trackWidth = trackWidth
        self.trackHeight = trackHeight
        self.alignment = alignment
        super.init(decoration: decoration)
    }

    override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is BoxParentData) {
            child.parentData = BoxParentData()
        }
    }

    override func performLayout() {
        size = Size(trackWidth, trackHeight)
        if let child = child as? RenderBox {
            child.layout(BoxConstraints(maxWidth: trackWidth, maxHeight: trackHeight), parentUsesSize: true)
            // Position the child based on alignment
            let childSize = child.size
            let x = ((1.0 + alignment.x) / 2.0) * (trackWidth - childSize.width)
            let y = ((1.0 + alignment.y) / 2.0) * (trackHeight - childSize.height)
            if let parentData = child.parentData as? BoxParentData {
                parentData.offset = Offset(x, y)
            }
        }
    }

    override func paint(_ context: PaintingContext, _ offset: Offset) {
        // Paint the track decoration (background)
        let painter = decoration.createBoxPainter(nil)
        painter.paint(context.canvas, offset, ImageConfiguration(size: size))

        // Paint the child (knob) at its positioned offset
        if let child = child as? RenderBox,
           let childParentData = child.parentData as? BoxParentData {
            context.paintChild(child, offset + childParentData.offset)
        }
    }
}

// MARK: - ToggleSwitchTheme

/// An inherited theme that controls how descendant ToggleSwitches look.
public class ToggleSwitchTheme: InheritedTheme {
    /// The theme data for the toggle switch theme.
    public let data: ToggleSwitchThemeData

    public init(key: (any Key)? = nil, data: ToggleSwitchThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    /// Returns the closest ToggleSwitchThemeData which encloses the given context.
    public static func of(_ context: any BuildContext) -> ToggleSwitchThemeData {
        let theme = FluentTheme.of(context)
        let inherited = context.dependOnInheritedWidgetOfExactType(ToggleSwitchTheme.self)
        return ToggleSwitchThemeData.standard(theme).merge(inherited?.data)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? ToggleSwitchTheme else { return true }
        return data !== old.data
    }

    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return ToggleSwitchTheme(data: data, child: child)
    }
}

// MARK: - ToggleSwitchThemeData

/// Theme data for ToggleSwitch widgets.
public class ToggleSwitchThemeData {
    /// The decoration of the track when the switch is checked.
    public let checkedDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The decoration of the track when the switch is unchecked.
    public let uncheckedDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The decoration of the knob when the switch is checked.
    public let checkedKnobDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The decoration of the knob when the switch is unchecked.
    public let uncheckedKnobDecoration: (any WidgetStateProperty<BoxDecoration?>)?

    /// The padding inside the track.
    public let padding: EdgeInsets?

    /// The margin around the switch.
    public let margin: EdgeInsets?

    /// The foreground color of the content.
    public let foregroundColor: (any WidgetStateProperty<Color?>)?

    public init(
        checkedDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        uncheckedDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        checkedKnobDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        uncheckedKnobDecoration: (any WidgetStateProperty<BoxDecoration?>)? = nil,
        padding: EdgeInsets? = nil,
        margin: EdgeInsets? = nil,
        foregroundColor: (any WidgetStateProperty<Color?>)? = nil
    ) {
        self.checkedDecoration = checkedDecoration
        self.uncheckedDecoration = uncheckedDecoration
        self.checkedKnobDecoration = checkedKnobDecoration
        self.uncheckedKnobDecoration = uncheckedKnobDecoration
        self.padding = padding
        self.margin = margin
        self.foregroundColor = foregroundColor
    }

    /// Creates the standard ToggleSwitchThemeData based on the given theme.
    public static func standard(_ theme: FluentThemeData) -> ToggleSwitchThemeData {
        return ToggleSwitchThemeData(
            checkedDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                BoxDecoration(
                    color: checkedInputColor(theme, states),
                    border: Border.all(
                        color: checkedInputColor(theme, states)
                    ),
                    borderRadius: BorderRadius.circular(100)
                )
            }),
            uncheckedDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                BoxDecoration(
                    color: Set<WidgetState>.forStates(
                        states,
                        disabled: theme.resources.controlAltFillColorDisabled,
                        none: theme.resources.controlAltFillColorSecondary,
                        pressed: theme.resources.controlAltFillColorQuarternary,
                        hovering: theme.resources.controlAltFillColorTertiary
                    ),
                    border: Border.all(
                        color: Set<WidgetState>.forStates(
                            states,
                            disabled: theme.resources.controlStrongFillColorDisabled,
                            none: theme.resources.controlStrongFillColorDefault
                        )
                    ),
                    borderRadius: BorderRadius.circular(100)
                )
            }),
            checkedKnobDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                BoxDecoration(
                    color: states.isDisabled
                        ? theme.resources.textOnAccentFillColorDisabled
                        : theme.resources.textOnAccentFillColorPrimary,
                    borderRadius: BorderRadius.circular(100)
                )
            }),
            uncheckedKnobDecoration: WidgetStatePropertyHelper.resolveWith({ states -> BoxDecoration? in
                BoxDecoration(
                    color: states.isDisabled
                        ? theme.resources.textFillColorDisabled
                        : theme.resources.textFillColorSecondary,
                    borderRadius: BorderRadius.circular(100)
                )
            }),
            foregroundColor: WidgetStatePropertyHelper.resolveWith({ states -> Color? in
                states.isDisabled ? theme.resources.textFillColorDisabled : nil
            })
        )
    }

    /// Merge this theme data with another, with the other taking precedence.
    public func merge(_ other: ToggleSwitchThemeData?) -> ToggleSwitchThemeData {
        guard let other = other else { return self }
        return ToggleSwitchThemeData(
            checkedDecoration: other.checkedDecoration ?? checkedDecoration,
            uncheckedDecoration: other.uncheckedDecoration ?? uncheckedDecoration,
            checkedKnobDecoration: other.checkedKnobDecoration ?? checkedKnobDecoration,
            uncheckedKnobDecoration: other.uncheckedKnobDecoration ?? uncheckedKnobDecoration,
            padding: other.padding ?? padding,
            margin: other.margin ?? margin,
            foregroundColor: other.foregroundColor ?? foregroundColor
        )
    }
}
