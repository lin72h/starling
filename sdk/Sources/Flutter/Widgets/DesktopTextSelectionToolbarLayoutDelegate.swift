// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - DesktopTextSelectionToolbarLayoutDelegate

/// Positions the toolbar at `anchor` if it fits, otherwise moves it so that it
/// just fits fully on-screen.
///
/// See also:
///
///   - `TextSelectionToolbarLayoutDelegate`, which does a similar layout for
///     the mobile text selection toolbars.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/desktop_text_selection_toolbar_layout_delegate.dart:24-54`
public class DesktopTextSelectionToolbarLayoutDelegate: SingleChildLayoutDelegate {

    /// Creates an instance of `DesktopTextSelectionToolbarLayoutDelegate`.
    ///
    /// **Dart Source:** `desktop_text_selection_toolbar_layout_delegate.dart:26`
    public init(anchor: Offset) {
        self.anchor = anchor
        super.init()
    }

    /// The point at which to render the menu, if possible.
    ///
    /// Should be provided in local coordinates.
    ///
    /// **Dart Source:** `desktop_text_selection_toolbar_layout_delegate.dart:31`
    public let anchor: Offset

    /// **Dart Source:** `desktop_text_selection_toolbar_layout_delegate.dart:34-36`
    public override func getConstraintsForChild(_ constraints: BoxConstraints) -> BoxConstraints {
        return constraints.loosen()
    }

    /// **Dart Source:** `desktop_text_selection_toolbar_layout_delegate.dart:39-48`
    public override func getPositionForChild(_ size: Size, _ childSize: Size) -> Offset {
        let overhang = Offset(
            anchor.dx + childSize.width - size.width,
            anchor.dy + childSize.height - size.height
        )
        return Offset(
            overhang.dx > 0.0 ? anchor.dx - overhang.dx : anchor.dx,
            overhang.dy > 0.0 ? anchor.dy - overhang.dy : anchor.dy
        )
    }

    /// **Dart Source:** `desktop_text_selection_toolbar_layout_delegate.dart:51-53`
    public override func shouldRelayout(_ oldDelegate: SingleChildLayoutDelegate) -> Bool {
        guard let oldDelegate = oldDelegate as? DesktopTextSelectionToolbarLayoutDelegate else {
            return true
        }
        return anchor != oldDelegate.anchor
    }
}
