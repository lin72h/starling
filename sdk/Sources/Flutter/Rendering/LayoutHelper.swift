// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Layout helper utilities migrated from `layout_helper.dart`.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/layout_helper.dart`

import FlutterSwiftBridge

// MARK: - Typedefs

/// Signature for a function that takes a `RenderBox` and returns the `Size`
/// that the `RenderBox` would have if it were laid out with the given
/// `BoxConstraints`.
///
/// `ChildLayoutHelper.dryLayoutChild` and `ChildLayoutHelper.layoutChild` adhere
/// to this signature.
///
/// **Dart Source:** `layout_helper.dart:15`
public typealias ChildLayouter = (_ child: RenderBox, _ constraints: BoxConstraints) -> Size

/// Signature for a function that takes a `RenderBox` and returns the baseline
/// offset this `RenderBox` would have if it were laid out with the given
/// `BoxConstraints`.
///
/// `ChildLayoutHelper.getDryBaseline` and `ChildLayoutHelper.getBaseline` adhere
/// to this signature.
///
/// **Dart Source:** `layout_helper.dart:23-24`
public typealias ChildBaselineGetter = (
    _ child: RenderBox, _ constraints: BoxConstraints, _ baseline: TextBaseline
) -> Double?

// MARK: - ChildLayoutHelper

/// A collection of static functions to layout a `RenderBox` child with the
/// given set of `BoxConstraints`.
///
/// All of the functions adhere to the `ChildLayouter` signature.
///
/// **Dart Source:** `layout_helper.dart:30-83`
public enum ChildLayoutHelper {

    /// Returns the `Size` that the `RenderBox` would have if it were to
    /// be laid out with the given `BoxConstraints`.
    ///
    /// This method calls `RenderBox.getDryLayout` on the given `RenderBox`.
    ///
    /// This method should only be called by the parent of the provided
    /// `RenderBox` child as it binds parent and child together (if the child
    /// is marked as dirty, the child will also be marked as dirty).
    ///
    /// **Dart Source:** `layout_helper.dart:44-46`
    public static func dryLayoutChild(_ child: RenderBox, _ constraints: BoxConstraints) -> Size {
        return child.getDryLayout(constraints)
    }

    /// Lays out the `RenderBox` with the given constraints and returns its
    /// `Size`.
    ///
    /// This method calls `RenderBox.layout` on the given `RenderBox` with
    /// `parentUsesSize` set to true to receive its `Size`.
    ///
    /// This method should only be called by the parent of the provided
    /// `RenderBox` child as it binds parent and child together (if the child
    /// is marked as dirty, the child will also be marked as dirty).
    ///
    /// **Dart Source:** `layout_helper.dart:61-64`
    public static func layoutChild(_ child: RenderBox, _ constraints: BoxConstraints) -> Size {
        child.layout(constraints, parentUsesSize: true)
        return child.size
    }

    /// Convenience function that calls `RenderBox.getDryBaseline`.
    ///
    /// **Dart Source:** `layout_helper.dart:67-73`
    public static func getDryBaseline(
        _ child: RenderBox,
        _ constraints: BoxConstraints,
        _ baseline: TextBaseline
    ) -> Double? {
        return child.getDryBaseline(constraints, baseline).offset
    }

    /// Convenience function that calls `RenderBox.getDistanceToBaseline`.
    ///
    /// The given `child` must be already laid out with `constraints`.
    ///
    /// **Dart Source:** `layout_helper.dart:78-82`
    public static func getBaseline(
        _ child: RenderBox,
        _ constraints: BoxConstraints,
        _ baseline: TextBaseline
    ) -> Double? {
        assert(!child.debugNeedsLayout)
        assert(child.boxConstraints == constraints)
        return child.getDistanceToBaseline(baseline, onlyReal: true)
    }
}
