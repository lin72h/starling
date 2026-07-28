// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Geometry utilities for positioning child boxes within containers.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/geometry.dart`

import FlutterSwiftBridge

// MARK: - positionDependentBox

/// Position a child box within a container box, either above or below a target
/// point.
///
/// The container's size is described by `size`.
///
/// The target point is specified by `target`, as an offset from the top left of
/// the container.
///
/// The child box's size is given by `childSize`.
///
/// The return value is the suggested distance from the top left of the
/// container box to the top left of the child box.
///
/// The suggested position will be above the target point if `preferBelow` is
/// false, and below the target point if it is true, unless it wouldn't fit on
/// the preferred side but would fit on the other side.
///
/// The suggested position will place the nearest side of the child to the
/// target point `verticalOffset` from the target point (even if it cannot fit
/// given that constraint).
///
/// The suggested position will be at least `margin` away from the edge of the
/// container. If possible, the child will be positioned so that its center is
/// aligned with the target point. If the child cannot fit horizontally within
/// the container given the margin, then the child will be centered in the
/// container.
///
/// Used by `Tooltip` to position a tooltip relative to its parent.
///
/// **Dart Source:** `geometry.dart:41-67`
public func positionDependentBox(
    size: Size,
    childSize: Size,
    target: Offset,
    preferBelow: Bool,
    verticalOffset: Double = 0.0,
    margin: Double = 10.0
) -> Offset {
    // VERTICAL DIRECTION
    // geometry.dart:49-58
    let fitsBelow = target.dy + verticalOffset + childSize.height <= size.height - margin
    let fitsAbove = target.dy - verticalOffset - childSize.height >= margin
    let tooltipBelow = fitsAbove == fitsBelow ? preferBelow : fitsBelow

    let y: Double
    if tooltipBelow {
        y = min(target.dy + verticalOffset, size.height - margin)
    } else {
        y = max(target.dy - verticalOffset - childSize.height, margin)
    }

    // HORIZONTAL DIRECTION
    // geometry.dart:59-66
    let flexibleSpace = size.width - childSize.width
    let x: Double
    if flexibleSpace <= 2 * margin {
        // If there's not enough horizontal space for margin + child, center the
        // child.
        x = flexibleSpace / 2.0
    } else {
        x = clampDouble(target.dx - childSize.width / 2, margin, flexibleSpace - margin)
    }

    return Offset(x, y)
}
