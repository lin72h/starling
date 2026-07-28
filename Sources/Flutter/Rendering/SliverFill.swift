// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sliver fill types for viewports and remaining space.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver_fill.dart`

import FlutterSwiftBridge

// =============================================================================
// MARK: - S1: RenderSliverFillViewport
// =============================================================================

/// A sliver that contains multiple box children that each fill the viewport.
///
/// `RenderSliverFillViewport` places its children in a linear array along the
/// main axis. Each child is sized to fill the viewport, both in the main and
/// cross axis. A `viewportFraction` factor can be provided to size the children
/// to a multiple of the viewport's main axis dimension (typically a fraction
/// less than 1.0).
///
/// See also:
///
///  - `RenderSliverFillRemaining`, which sizes the children based on the
///    remaining space rather than the viewport itself.
///  - `RenderSliverFixedExtentList`, which has a configurable `itemExtent`.
///  - `RenderSliverList`, which does not require its children to have the same
///    extent in the main axis.
///
/// **Dart Source:** `sliver_fill.dart:32-56`
open class RenderSliverFillViewport: RenderSliverFixedExtentBoxAdaptor {

    // MARK: - Initializer

    /// Creates a sliver that contains multiple box children that each fill the
    /// viewport.
    ///
    /// **Dart Source:** `sliver_fill.dart:35-37`
    public init(
        childManager: any RenderSliverBoxChildManager,
        viewportFraction: Double = 1.0
    ) {
        assert(viewportFraction > 0.0)
        _viewportFraction = viewportFraction
        super.init(childManager: childManager)
    }

    // MARK: - Properties

    /// The main-axis extent of each item, computed as the viewport's main axis
    /// extent multiplied by `viewportFraction`.
    ///
    /// **Dart Source:** `sliver_fill.dart:40`
    open override var itemExtent: Double? {
        sliverConstraints.viewportMainAxisExtent * viewportFraction
    }

    /// The fraction of the viewport that each child should fill in the main axis.
    ///
    /// If this fraction is less than 1.0, more than one child will be visible at
    /// once. If this fraction is greater than 1.0, each child will be larger than
    /// the viewport in the main axis.
    ///
    /// **Dart Source:** `sliver_fill.dart:47-55`
    public var viewportFraction: Double {
        get { _viewportFraction }
        set {
            if _viewportFraction == newValue {
                return
            }
            _viewportFraction = newValue
            markNeedsLayout()
        }
    }
    private var _viewportFraction: Double
}

// =============================================================================
// MARK: - S2: RenderSliverFillRemainingWithScrollable
// =============================================================================

/// A sliver that contains a single box child that contains a scrollable and
/// fills the viewport.
///
/// `RenderSliverFillRemainingWithScrollable` sizes its child to fill the
/// viewport in the cross axis and to fill the remaining space in the viewport
/// in the main axis.
///
/// Typically this will be the last sliver in a viewport, since (by definition)
/// there is never any room for anything beyond this sliver.
///
/// See also:
///
///  - `RenderSliverFillRemaining`, which lays out its
///    non-scrollable child slightly different than this widget.
///  - `RenderSliverFillRemainingAndOverscroll`, which incorporates the
///    overscroll into the remaining space to fill.
///  - `RenderSliverFillViewport`, which sizes its children based on the
///    size of the viewport, regardless of what else is in the scroll view.
///  - `RenderSliverList`, which shows a list of variable-sized children in a
///    viewport.
///
/// **Dart Source:** `sliver_fill.dart:79-122`
open class RenderSliverFillRemainingWithScrollable: RenderSliverSingleBoxAdapter {

    /// Creates a `RenderSliver` that wraps a scrollable `RenderBox` which is
    /// sized to fit the remaining space in the viewport.
    ///
    /// **Dart Source:** `sliver_fill.dart:82`
    public override init(child: RenderBox? = nil) {
        super.init(child: child)
    }

    // MARK: - Layout

    /// **Dart Source:** `sliver_fill.dart:85-121`
    open override func performLayout() {
        let constraints = self.sliverConstraints
        let extent = constraints.remainingPaintExtent - min(constraints.overlap, 0.0)

        let cacheExtent = calculateCacheOffset(
            constraints,
            from: 0.0,
            to: constraints.viewportMainAxisExtent
        )

        if let child = child {
            var maxExtent = extent

            // If sliver has no extent, but is within viewport's cacheExtent, use the
            // sliver's cacheExtent as the maxExtent so that it does not get dropped
            // from the semantic tree.
            if extent == 0 && cacheExtent > 0 {
                maxExtent = cacheExtent
            }
            child.layout(
                constraints.asBoxConstraints(minExtent: extent, maxExtent: maxExtent)
            )
        }

        let paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent)
        assert(paintedChildSize.isFinite)
        assert(paintedChildSize >= 0.0)

        geometry = SliverGeometry(
            scrollExtent: constraints.viewportMainAxisExtent,
            paintExtent: paintedChildSize,
            maxPaintExtent: paintedChildSize,
            hasVisualOverflow: extent > constraints.remainingPaintExtent
                || constraints.scrollOffset > 0.0,
            cacheExtent: cacheExtent
        )
        if let child = child {
            setChildParentData(child, constraints, geometry!)
        }
    }
}

// =============================================================================
// MARK: - S3: RenderSliverFillRemaining
// =============================================================================

/// A sliver that contains a single box child that is non-scrollable and fills
/// the remaining space in the viewport.
///
/// `RenderSliverFillRemaining` sizes its child to fill the viewport in the
/// cross axis and to fill the remaining space in the viewport in the main axis.
///
/// Typically this will be the last sliver in a viewport, since (by definition)
/// there is never any room for anything beyond this sliver.
///
/// See also:
///
///  - `RenderSliverFillRemainingWithScrollable`, which lays out its scrollable
///    child slightly different than this widget.
///  - `RenderSliverFillRemainingAndOverscroll`, which incorporates the
///    overscroll into the remaining space to fill.
///  - `RenderSliverFillViewport`, which sizes its children based on the
///    size of the viewport, regardless of what else is in the scroll view.
///  - `RenderSliverList`, which shows a list of variable-sized children in a
///    viewport.
///
/// **Dart Source:** `sliver_fill.dart:144-193`
open class RenderSliverFillRemaining: RenderSliverSingleBoxAdapter {

    /// Creates a `RenderSliver` that wraps a non-scrollable `RenderBox` which is
    /// sized to fit the remaining space in the viewport.
    ///
    /// **Dart Source:** `sliver_fill.dart:147`
    public override init(child: RenderBox? = nil) {
        super.init(child: child)
    }

    // MARK: - Layout

    /// **Dart Source:** `sliver_fill.dart:150-192`
    open override func performLayout() {
        let constraints = self.sliverConstraints
        // The remaining space in the viewportMainAxisExtent. Can be <= 0 if we have
        // scrolled beyond the extent of the screen.
        var extent = constraints.viewportMainAxisExtent - constraints.precedingScrollExtent

        if let child = child {
            let childExtent: Double
            switch constraints.axis {
            case .horizontal:
                childExtent = child.getMaxIntrinsicWidth(constraints.crossAxisExtent)
            case .vertical:
                childExtent = child.getMaxIntrinsicHeight(constraints.crossAxisExtent)
            }

            // If the childExtent is greater than the computed extent, we want to use
            // that instead of potentially cutting off the child. This allows us to
            // safely specify a maxExtent.
            extent = max(extent, childExtent)
            child.layout(
                constraints.asBoxConstraints(minExtent: extent, maxExtent: extent)
            )
        }

        assert(
            extent.isFinite,
            "The calculated extent for the child of SliverFillRemaining is not finite. "
            + "This can happen if the child is a scrollable, in which case, the "
            + "hasScrollBody property of SliverFillRemaining should not be set to "
            + "false."
        )
        let paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent)
        assert(paintedChildSize.isFinite)
        assert(paintedChildSize >= 0.0)

        let cacheExtent = calculateCacheOffset(constraints, from: 0.0, to: extent)
        geometry = SliverGeometry(
            scrollExtent: extent,
            paintExtent: paintedChildSize,
            maxPaintExtent: paintedChildSize,
            hasVisualOverflow: extent > constraints.remainingPaintExtent
                || constraints.scrollOffset > 0.0,
            cacheExtent: cacheExtent
        )
        if let child = child {
            setChildParentData(child, constraints, geometry!)
        }
    }
}

// =============================================================================
// MARK: - S4: RenderSliverFillRemainingAndOverscroll
// =============================================================================

/// A sliver that contains a single box child that is non-scrollable and fills
/// the remaining space in the viewport including any overscrolled area.
///
/// `RenderSliverFillRemainingAndOverscroll` sizes its child to fill the
/// viewport in the cross axis and to fill the remaining space in the viewport
/// in the main axis with the overscroll area included.
///
/// Typically this will be the last sliver in a viewport, since (by definition)
/// there is never any room for anything beyond this sliver.
///
/// See also:
///
///  - `RenderSliverFillRemainingWithScrollable`, which lays out its scrollable
///    child without overscroll.
///  - `RenderSliverFillRemaining`, which lays out its
///    non-scrollable child without overscroll.
///  - `RenderSliverFillViewport`, which sizes its children based on the
///    size of the viewport, regardless of what else is in the scroll view.
///  - `RenderSliverList`, which shows a list of variable-sized children in a
///    viewport.
///
/// **Dart Source:** `sliver_fill.dart:215-271`
open class RenderSliverFillRemainingAndOverscroll: RenderSliverSingleBoxAdapter {

    /// Creates a `RenderSliver` that wraps a non-scrollable `RenderBox` which is
    /// sized to fit the remaining space plus any overscroll in the viewport.
    ///
    /// **Dart Source:** `sliver_fill.dart:218`
    public override init(child: RenderBox? = nil) {
        super.init(child: child)
    }

    // MARK: - Layout

    /// **Dart Source:** `sliver_fill.dart:221-271`
    open override func performLayout() {
        let constraints = self.sliverConstraints
        // The remaining space in the viewportMainAxisExtent. Can be <= 0 if we have
        // scrolled beyond the extent of the screen.
        var extent = constraints.viewportMainAxisExtent - constraints.precedingScrollExtent
        // The maxExtent includes any overscrolled area. Can be < 0 if we have
        // overscroll in the opposite direction, away from the end of the list.
        var maxExtent = constraints.remainingPaintExtent - min(constraints.overlap, 0.0)

        if let child = child {
            let childExtent: Double
            switch constraints.axis {
            case .horizontal:
                childExtent = child.getMaxIntrinsicWidth(constraints.crossAxisExtent)
            case .vertical:
                childExtent = child.getMaxIntrinsicHeight(constraints.crossAxisExtent)
            }

            // If the childExtent is greater than the computed extent, we want to use
            // that instead of potentially cutting off the child. This allows us to
            // safely specify a maxExtent.
            extent = max(extent, childExtent)
            // The extent could be larger than the maxExtent due to a larger child
            // size or overscrolling at the top of the scrollable (rather than at the
            // end where this sliver is).
            maxExtent = max(extent, maxExtent)
            child.layout(
                constraints.asBoxConstraints(minExtent: extent, maxExtent: maxExtent)
            )
        }

        assert(
            extent.isFinite,
            "The calculated extent for the child of SliverFillRemaining is not finite. "
            + "This can happen if the child is a scrollable, in which case, the "
            + "hasScrollBody property of SliverFillRemaining should not be set to "
            + "false."
        )
        let paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent)
        assert(paintedChildSize.isFinite)
        assert(paintedChildSize >= 0.0)

        let cacheExtent = calculateCacheOffset(constraints, from: 0.0, to: extent)
        geometry = SliverGeometry(
            scrollExtent: extent,
            paintExtent: min(maxExtent, constraints.remainingPaintExtent),
            maxPaintExtent: maxExtent,
            hasVisualOverflow: extent > constraints.remainingPaintExtent
                || constraints.scrollOffset > 0.0,
            cacheExtent: cacheExtent
        )
        if let child = child {
            setChildParentData(child, constraints, geometry!)
        }
    }
}
