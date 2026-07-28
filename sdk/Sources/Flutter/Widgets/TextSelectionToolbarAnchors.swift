// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - TextSelectionToolbarAnchors

/// The position information for a text selection toolbar.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/text_selection_toolbar_anchors.dart:21-100`
public struct TextSelectionToolbarAnchors: Equatable, Sendable {

    /// Creates an instance directly from the anchor points.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:24`
    public init(primaryAnchor: Offset, secondaryAnchor: Offset? = nil) {
        self.primaryAnchor = primaryAnchor
        self.secondaryAnchor = secondaryAnchor
    }

    /// Creates an instance for some selection.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:27-50`
    public static func fromSelection(
        renderBox: RenderBox,
        startGlyphHeight: Double,
        endGlyphHeight: Double,
        selectionEndpoints: [TextSelectionPoint]
    ) -> TextSelectionToolbarAnchors {
        let selectionRect = getSelectionRect(
            renderBox: renderBox,
            startGlyphHeight: startGlyphHeight,
            endGlyphHeight: endGlyphHeight,
            selectionEndpoints: selectionEndpoints
        )
        if selectionRect == Rect.zero {
            return TextSelectionToolbarAnchors(primaryAnchor: Offset.zero)
        }
        let editingRegion = getEditingRegion(renderBox)
        return TextSelectionToolbarAnchors(
            primaryAnchor: Offset(
                selectionRect.left + selectionRect.width / 2,
                clampDouble(selectionRect.top, editingRegion.top, editingRegion.bottom)
            ),
            secondaryAnchor: Offset(
                selectionRect.left + selectionRect.width / 2,
                clampDouble(selectionRect.bottom, editingRegion.top, editingRegion.bottom)
            )
        )
    }

    /// Returns the `Rect` of the `RenderBox` in global coordinates.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:53-57`
    private static func getEditingRegion(_ renderBox: RenderBox) -> Rect {
        return Rect.fromPoints(
            renderBox.localToGlobal(Offset.zero),
            renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero))
        )
    }

    /// Returns the `Rect` covering the given selection in global coordinates.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:61-83`
    public static func getSelectionRect(
        renderBox: RenderBox,
        startGlyphHeight: Double,
        endGlyphHeight: Double,
        selectionEndpoints: [TextSelectionPoint]
    ) -> Rect {
        let editingRegion = getEditingRegion(renderBox)

        if editingRegion.left.isNaN || editingRegion.top.isNaN
            || editingRegion.right.isNaN || editingRegion.bottom.isNaN {
            return Rect.zero
        }

        let isMultiline = selectionEndpoints.last!.point.dy - selectionEndpoints.first!.point.dy > endGlyphHeight / 2

        return Rect.fromLTRB(
            isMultiline ? editingRegion.left : editingRegion.left + selectionEndpoints.first!.point.dx,
            editingRegion.top + selectionEndpoints.first!.point.dy - startGlyphHeight,
            isMultiline ? editingRegion.right : editingRegion.left + selectionEndpoints.last!.point.dx,
            editingRegion.top + selectionEndpoints.last!.point.dy
        )
    }

    /// The location that the toolbar should attempt to position itself at.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:90`
    public let primaryAnchor: Offset

    /// The fallback position if `primaryAnchor` doesn't work.
    ///
    /// **Dart Source:** `text_selection_toolbar_anchors.dart:93`
    public let secondaryAnchor: Offset?
}
