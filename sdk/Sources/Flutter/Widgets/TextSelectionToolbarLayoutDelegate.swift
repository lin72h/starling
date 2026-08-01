// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - TextSelectionToolbarLayoutDelegate

/// A `SingleChildLayoutDelegate` that positions its child above `anchorAbove`
/// if it fits, or otherwise below `anchorBelow`.
///
/// Primarily intended for use with toolbars or context menus.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/text_selection_toolbar_layout_delegate.dart:26-94`
public class TextSelectionToolbarLayoutDelegate: SingleChildLayoutDelegate {

    /// Creates an instance of TextSelectionToolbarLayoutDelegate.
    ///
    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:30-34`
    public init(
        anchorAbove: Offset,
        anchorBelow: Offset,
        fitsAbove: Bool? = nil
    ) {
        self.anchorAbove = anchorAbove
        self.anchorBelow = anchorBelow
        self.fitsAbove = fitsAbove
    }

    /// The anchor point above which the toolbar should be positioned if it fits.
    ///
    /// Should be provided in local coordinates.
    ///
    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:39`
    public let anchorAbove: Offset

    /// The anchor point below which the toolbar should be positioned if it
    /// does not fit above.
    ///
    /// Should be provided in local coordinates.
    ///
    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:44`
    public let anchorBelow: Offset

    /// Whether or not the child should be considered to fit above `anchorAbove`.
    ///
    /// Typically used to force the child to be drawn at `anchorAbove` even when
    /// it doesn't fit, such as when the Material `TextSelectionToolbar` draws an
    /// open overflow menu.
    ///
    /// If not provided, it will be calculated.
    ///
    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:53`
    public let fitsAbove: Bool?

    /// Returns the distance from zero that centers `width` as closely as
    /// possible to `position` from zero while fitting between zero and `max`.
    ///
    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:57-70`
    public static func centerOn(_ position: Double, _ width: Double, _ max: Double) -> Double {
        // If it overflows on the left, put it as far left as possible.
        if position - width / 2.0 < 0.0 {
            return 0.0
        }

        // If it overflows on the right, put it as far right as possible.
        if position + width / 2.0 > max {
            return max - width
        }

        // Otherwise it fits while perfectly centered.
        return position - width / 2.0
    }

    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:73-75`
    override public func getConstraintsForChild(_ constraints: BoxConstraints) -> BoxConstraints {
        return constraints.loosen()
    }

    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:78-86`
    override public func getPositionForChild(_ size: Size, _ childSize: Size) -> Offset {
        let fitsAbove = self.fitsAbove ?? (anchorAbove.dy >= childSize.height)
        let anchor = fitsAbove ? anchorAbove : anchorBelow

        return Offset(
            TextSelectionToolbarLayoutDelegate.centerOn(anchor.dx, childSize.width, size.width),
            fitsAbove ? Swift.max(0.0, anchor.dy - childSize.height) : anchor.dy
        )
    }

    /// **Dart Source:** `text_selection_toolbar_layout_delegate.dart:89-93`
    override public func shouldRelayout(_ oldDelegate: SingleChildLayoutDelegate) -> Bool {
        guard let oldDelegate = oldDelegate as? TextSelectionToolbarLayoutDelegate else {
            return true
        }
        return anchorAbove != oldDelegate.anchorAbove
            || anchorBelow != oldDelegate.anchorBelow
            || fitsAbove != oldDelegate.fitsAbove
    }
}
