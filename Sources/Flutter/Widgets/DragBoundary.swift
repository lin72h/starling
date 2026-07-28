// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - DragBoundaryDelegate

/// The interface for defining the algorithm for a boundary that a specified
/// shape is dragged within.
///
/// `T` is a data class that defines the shape being dragged. For example,
/// when dragging a rectangle within the boundary, `T` should be a `Rect`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/drag_boundary.dart:16-25`
public protocol DragBoundaryDelegate<T> {
    associatedtype T

    /// Returns whether the specified dragged object is within the boundary.
    ///
    /// **Dart Source:** `drag_boundary.dart:18`
    func isWithinBoundary(_ draggedObject: T) -> Bool

    /// Returns the given dragged object after moving it fully inside
    /// the boundary with the shortest distance.
    ///
    /// If the bounds cannot contain the dragged object, an exception is thrown.
    ///
    /// **Dart Source:** `drag_boundary.dart:24`
    func nearestPositionWithinBoundary(_ draggedObject: T) -> T
}

// MARK: - _DragBoundaryDelegateForRect

/// A `DragBoundaryDelegate<Rect>` that constrains a `Rect` within an
/// optional rectangular boundary.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/drag_boundary.dart:27-63`
class _DragBoundaryDelegateForRect: DragBoundaryDelegate {
    init(_ boundary: Rect?) {
        self.boundary = boundary
    }

    let boundary: Rect?

    /// **Dart Source:** `drag_boundary.dart:31-37`
    func isWithinBoundary(_ draggedObject: Rect) -> Bool {
        guard let boundary = boundary else {
            return true
        }
        return boundary.contains(draggedObject.topLeft)
            && boundary.contains(draggedObject.bottomRight)
    }

    /// **Dart Source:** `drag_boundary.dart:40-62`
    func nearestPositionWithinBoundary(_ draggedObject: Rect) -> Rect {
        guard let boundary = boundary else {
            return draggedObject
        }
        if boundary.right - draggedObject.width < boundary.left
            || boundary.bottom - draggedObject.height < boundary.top
        {
            fatalError(
                "The rect is larger than the boundary. "
                + "The rect width must be less than the boundary width, "
                + "and the rect height must be less than the boundary height."
            )
        }
        let left = clampDouble(
            draggedObject.left,
            boundary.left,
            boundary.right - draggedObject.width
        )
        let top = clampDouble(
            draggedObject.top,
            boundary.top,
            boundary.bottom - draggedObject.height
        )
        return Rect.fromLTWH(left, top, draggedObject.width, draggedObject.height)
    }
}

// MARK: - DragBoundary

/// Provides a `DragBoundaryDelegate` for its descendants whose bounds are
/// those defined by this widget.
///
/// `forRectOf` and `forRectMaybeOf` return a delegate for a drag object
/// of type `Rect`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/drag_boundary.dart:75-123`
public class DragBoundary: InheritedWidget {

    /// Creates a widget that provides a boundary to its descendants.
    ///
    /// **Dart Source:** `drag_boundary.dart:77`
    public override init(key: (any Key)? = nil, child: Widget) {
        super.init(key: key, child: child)
    }

    /// Retrieve the `DragBoundary` from the nearest ancestor to get its
    /// `DragBoundaryDelegate` of `Rect`.
    ///
    /// The `useGlobalPosition` specifies whether to retrieve the delegate
    /// in global coordinates. If false, local coordinates of the boundary
    /// are used. Defaults to true.
    ///
    /// If no `DragBoundary` ancestor is found, returns a delegate that
    /// allows the drag object to move freely.
    ///
    /// **Dart Source:** `drag_boundary.dart:88-94`
    public static func forRectOf(
        _ context: any BuildContext,
        useGlobalPosition: Bool = true
    ) -> any DragBoundaryDelegate<Rect> {
        return forRectMaybeOf(context, useGlobalPosition: useGlobalPosition)
            ?? _DragBoundaryDelegateForRect(nil)
    }

    /// Retrieve the `DragBoundary` from the nearest ancestor to get its
    /// `DragBoundaryDelegate` of `Rect`.
    ///
    /// Returns nil if no ancestor is found.
    ///
    /// **Dart Source:** `drag_boundary.dart:99-117`
    public static func forRectMaybeOf(
        _ context: any BuildContext,
        useGlobalPosition: Bool = true
    ) -> (any DragBoundaryDelegate<Rect>)? {
        let element = context.getElementForInheritedWidgetOfExactType(DragBoundary.self)
        guard let element = element else {
            return nil
        }
        let rb = element.findRenderObject() as? RenderBox
        assert(rb != nil && rb!.hasSize, "DragBoundary is not available")
        let boundary: Rect
        if useGlobalPosition {
            boundary = Rect.fromPoints(
                rb!.localToGlobal(Offset.zero),
                rb!.localToGlobal(rb!.size.bottomRight(Offset.zero))
            )
        } else {
            boundary = Offset.zero & rb!.size
        }
        return _DragBoundaryDelegateForRect(boundary)
    }

    /// **Dart Source:** `drag_boundary.dart:120-122`
    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        return true
    }
}
