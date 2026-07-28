// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - DefaultSelectionStyle

/// The selection style to apply to descendant `EditableText` widgets which
/// don't have an explicit style.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/default_selection_style.dart:28-130`
public class DefaultSelectionStyle: InheritedTheme {

    /// The color of the text field's cursor.
    ///
    /// The cursor indicates the current location of the text insertion point in
    /// the field.
    ///
    /// **Dart Source:** `default_selection_style.dart:89`
    public let cursorColor: Color?

    /// The background color of selected text.
    ///
    /// **Dart Source:** `default_selection_style.dart:92`
    public let selectionColor: Color?

    /// The `MouseCursor` for mouse pointers hovering over selectable Text widgets.
    ///
    /// If this property is nil, `SystemMouseCursors.text` will be used.
    ///
    /// **Dart Source:** `default_selection_style.dart:97`
    public let mouseCursor: MouseCursor?

    /// Creates a default selection style widget that specifies the selection
    /// properties for all widgets below it in the widget tree.
    ///
    /// **Dart Source:** `default_selection_style.dart:31-37`
    public init(
        key: (any Key)? = nil,
        cursorColor: Color? = nil,
        selectionColor: Color? = nil,
        mouseCursor: MouseCursor? = nil,
        child: Widget
    ) {
        self.cursorColor = cursorColor
        self.selectionColor = selectionColor
        self.mouseCursor = mouseCursor
        super.init(key: key, child: child)
    }

    /// A const-constructable default selection style that provides fallback
    /// values (nil).
    ///
    /// Returned from `of` when the given `BuildContext` doesn't have an enclosing
    /// default selection style.
    ///
    /// This constructor creates a `DefaultSelectionStyle` with an invalid child,
    /// which means the constructed value cannot be incorporated into the tree.
    ///
    /// **Dart Source:** `default_selection_style.dart:47-51`
    public convenience init(fallback key: (any Key)? = nil) {
        self.init(
            key: key,
            cursorColor: nil,
            selectionColor: nil,
            mouseCursor: nil,
            child: _NullWidget()
        )
    }

    /// The default cursor and selection color (semi-transparent grey).
    ///
    /// This is the color that the `Text` widget uses when the specified selection
    /// color is nil.
    ///
    /// **Dart Source:** `default_selection_style.dart:83`
    public static let defaultColor = Color(0x80808080)

    /// Creates a default selection style that overrides the selection styles in
    /// scope at this point in the widget tree.
    ///
    /// Any arguments that are not nil replace the corresponding properties on the
    /// default selection style for the `BuildContext` where the widget is inserted.
    ///
    /// **Dart Source:** `default_selection_style.dart:58-77`
    public static func merge(
        key: (any Key)? = nil,
        cursorColor: Color? = nil,
        selectionColor: Color? = nil,
        mouseCursor: MouseCursor? = nil,
        child: Widget
    ) -> Widget {
        return Builder { context in
            let parent = DefaultSelectionStyle.of(context)
            return DefaultSelectionStyle(
                key: key,
                cursorColor: cursorColor ?? parent.cursorColor,
                selectionColor: selectionColor ?? parent.selectionColor,
                mouseCursor: mouseCursor ?? parent.mouseCursor,
                child: child
            )
        }
    }

    /// The closest instance of this class that encloses the given context.
    ///
    /// If no such instance exists, returns an instance created by
    /// `DefaultSelectionStyle.fallback`, which contains fallback values.
    ///
    /// **Dart Source:** `default_selection_style.dart:109-112`
    public static func of(_ context: any BuildContext) -> DefaultSelectionStyle {
        return context.dependOnInheritedWidgetOfExactType(DefaultSelectionStyle.self)
            ?? DefaultSelectionStyle(fallback: nil)
    }

    /// **Dart Source:** `default_selection_style.dart:115-122`
    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return DefaultSelectionStyle(
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            mouseCursor: mouseCursor,
            child: child
        )
    }

    /// **Dart Source:** `default_selection_style.dart:125-129`
    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let oldWidget = oldWidget as? DefaultSelectionStyle else { return true }
        return cursorColor != oldWidget.cursorColor
            || selectionColor != oldWidget.selectionColor
            || mouseCursor !== oldWidget.mouseCursor
    }
}

// MARK: - _NullWidget

/// Private widget used as a placeholder child for `DefaultSelectionStyle.fallback`.
///
/// **Dart Source:** `default_selection_style.dart:132-143`
private class _NullWidget: StatelessWidget {
    init() {
        super.init()
    }

    override func build(_ context: any BuildContext) -> Widget {
        fatalError(
            "A DefaultSelectionStyle constructed with DefaultSelectionStyle.fallback "
            + "cannot be incorporated into the widget tree, it is meant only to provide "
            + "a fallback value returned by DefaultSelectionStyle.of() when no enclosing "
            + "default selection style is present in a BuildContext."
        )
    }
}
