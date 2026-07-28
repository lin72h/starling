// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sliver grid layout types for placing multiple box children in a
/// two-dimensional arrangement within a scrollable region.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver_grid.dart`

import FlutterSwiftBridge

// MARK: - SliverGridGeometry

/// Describes the placement of a child in a `RenderSliverGrid`.
///
/// This type is similar to `Rect`, in that it gives a two-dimensional position
/// and a two-dimensional dimension, but is direction-agnostic.
///
/// **Dart Source:** `sliver_grid.dart:41-98`
public struct SliverGridGeometry: CustomStringConvertible, Sendable {

    /// Creates an object that describes the placement of a child in a
    /// `RenderSliverGrid`.
    ///
    /// **Dart Source:** `sliver_grid.dart:43-48`
    public init(
        scrollOffset: Double,
        crossAxisOffset: Double,
        mainAxisExtent: Double,
        crossAxisExtent: Double
    ) {
        self.scrollOffset = scrollOffset
        self.crossAxisOffset = crossAxisOffset
        self.mainAxisExtent = mainAxisExtent
        self.crossAxisExtent = crossAxisExtent
    }

    /// The scroll offset of the leading edge of the child relative to the
    /// leading edge of the parent.
    ///
    /// **Dart Source:** `sliver_grid.dart:52`
    public let scrollOffset: Double

    /// The offset of the child in the non-scrolling axis.
    ///
    /// If the scroll axis is vertical, this offset is from the left-most edge of
    /// the parent to the left-most edge of the child. If the scroll axis is
    /// horizontal, this offset is from the top-most edge of the parent to the
    /// top-most edge of the child.
    ///
    /// **Dart Source:** `sliver_grid.dart:61`
    public let crossAxisOffset: Double

    /// The extent of the child in the scrolling axis.
    ///
    /// If the scroll axis is vertical, this extent is the child's height. If the
    /// scroll axis is horizontal, this extent is the child's width.
    ///
    /// **Dart Source:** `sliver_grid.dart:68`
    public let mainAxisExtent: Double

    /// The extent of the child in the non-scrolling axis.
    ///
    /// If the scroll axis is vertical, this extent is the child's width. If the
    /// scroll axis is horizontal, this extent is the child's height.
    ///
    /// **Dart Source:** `sliver_grid.dart:75`
    public let crossAxisExtent: Double

    /// The scroll offset of the trailing edge of the child relative to the
    /// leading edge of the parent.
    ///
    /// **Dart Source:** `sliver_grid.dart:78`
    public var trailingScrollOffset: Double {
        scrollOffset + mainAxisExtent
    }

    /// Returns a tight `BoxConstraints` that forces the child to have the
    /// required size, given a `SliverConstraints`.
    ///
    /// **Dart Source:** `sliver_grid.dart:82-88`
    public func getBoxConstraints(_ constraints: SliverConstraints) -> BoxConstraints {
        return constraints.asBoxConstraints(
            minExtent: mainAxisExtent,
            maxExtent: mainAxisExtent,
            crossAxisExtent: crossAxisExtent
        )
    }

    /// **Dart Source:** `sliver_grid.dart:90-97`
    public var description: String {
        "SliverGridGeometry(scrollOffset: \(scrollOffset), crossAxisOffset: \(crossAxisOffset), mainAxisExtent: \(mainAxisExtent), crossAxisExtent: \(crossAxisExtent))"
    }
}

// MARK: - SliverGridLayout

/// The size and position of all the tiles in a `RenderSliverGrid`.
///
/// Rather than providing a grid with a `SliverGridLayout` directly, the grid is
/// provided a `SliverGridDelegate`, which computes a `SliverGridLayout` given a
/// set of `SliverConstraints`. This allows the algorithm to dynamically respond
/// to changes in the environment (e.g. the user rotating the device).
///
/// **Dart Source:** `sliver_grid.dart:130-149`
public protocol SliverGridLayout {

    /// The minimum child index that intersects with (or is after) this scroll
    /// offset.
    ///
    /// **Dart Source:** `sliver_grid.dart:136`
    func getMinChildIndexForScrollOffset(_ scrollOffset: Double) -> Int

    /// The maximum child index that intersects with (or is before) this scroll
    /// offset.
    ///
    /// **Dart Source:** `sliver_grid.dart:139`
    func getMaxChildIndexForScrollOffset(_ scrollOffset: Double) -> Int

    /// The size and position of the child with the given index.
    ///
    /// **Dart Source:** `sliver_grid.dart:142`
    func getGeometryForChildIndex(_ index: Int) -> SliverGridGeometry

    /// The scroll extent needed to fully display all the tiles if there are
    /// `childCount` children in total.
    ///
    /// **Dart Source:** `sliver_grid.dart:148`
    func computeMaxScrollOffset(_ childCount: Int) -> Double
}

// MARK: - SliverGridRegularTileLayout

/// A `SliverGridLayout` that uses equally sized and spaced tiles.
///
/// Rather than providing a grid with a `SliverGridLayout` directly, you instead
/// provide the grid a `SliverGridDelegate`, which can compute a
/// `SliverGridLayout` given the current `SliverConstraints`.
///
/// This layout is used by `SliverGridDelegateWithFixedCrossAxisCount` and
/// `SliverGridDelegateWithMaxCrossAxisExtent`.
///
/// **Dart Source:** `sliver_grid.dart:171-267`
public struct SliverGridRegularTileLayout: SliverGridLayout {

    /// Creates a layout that uses equally sized and spaced tiles.
    ///
    /// All of the arguments must not be negative. The `crossAxisCount` argument
    /// must be greater than zero.
    ///
    /// **Dart Source:** `sliver_grid.dart:176-187`
    public init(
        crossAxisCount: Int,
        mainAxisStride: Double,
        crossAxisStride: Double,
        childMainAxisExtent: Double,
        childCrossAxisExtent: Double,
        reverseCrossAxis: Bool
    ) {
        assert(crossAxisCount > 0)
        assert(mainAxisStride >= 0)
        assert(crossAxisStride >= 0)
        assert(childMainAxisExtent >= 0)
        assert(childCrossAxisExtent >= 0)
        self.crossAxisCount = crossAxisCount
        self.mainAxisStride = mainAxisStride
        self.crossAxisStride = crossAxisStride
        self.childMainAxisExtent = childMainAxisExtent
        self.childCrossAxisExtent = childCrossAxisExtent
        self.reverseCrossAxis = reverseCrossAxis
    }

    /// The number of children in the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:190`
    public let crossAxisCount: Int

    /// The number of pixels from the leading edge of one tile to the leading edge
    /// of the next tile in the main axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:194`
    public let mainAxisStride: Double

    /// The number of pixels from the leading edge of one tile to the leading edge
    /// of the next tile in the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:198`
    public let crossAxisStride: Double

    /// The number of pixels from the leading edge of one tile to the trailing
    /// edge of the same tile in the main axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:202`
    public let childMainAxisExtent: Double

    /// The number of pixels from the leading edge of one tile to the trailing
    /// edge of the same tile in the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:206`
    public let childCrossAxisExtent: Double

    /// Whether the children should be placed in the opposite order of increasing
    /// coordinates in the cross axis.
    ///
    /// For example, if the cross axis is horizontal, the children are placed from
    /// left to right when `reverseCrossAxis` is false and from right to left when
    /// `reverseCrossAxis` is true.
    ///
    /// **Dart Source:** `sliver_grid.dart:217`
    public let reverseCrossAxis: Bool

    /// **Dart Source:** `sliver_grid.dart:220-223`
    public func getMinChildIndexForScrollOffset(_ scrollOffset: Double) -> Int {
        if mainAxisStride > precisionErrorTolerance {
            return crossAxisCount * Int(scrollOffset / mainAxisStride)
        }
        return 0
    }

    /// **Dart Source:** `sliver_grid.dart:227-233`
    public func getMaxChildIndexForScrollOffset(_ scrollOffset: Double) -> Int {
        if mainAxisStride > 0.0 {
            let mainAxisCount = Int((scrollOffset / mainAxisStride).rounded(.up))
            return max(0, crossAxisCount * mainAxisCount - 1)
        }
        return 0
    }

    /// Returns the offset from the start in the cross axis direction.
    ///
    /// **Dart Source:** `sliver_grid.dart:235-243`
    private func _getOffsetFromStartInCrossAxis(_ crossAxisStart: Double) -> Double {
        if reverseCrossAxis {
            return Double(crossAxisCount) * crossAxisStride
                - crossAxisStart
                - childCrossAxisExtent
                - (crossAxisStride - childCrossAxisExtent)
        }
        return crossAxisStart
    }

    /// **Dart Source:** `sliver_grid.dart:246-254`
    public func getGeometryForChildIndex(_ index: Int) -> SliverGridGeometry {
        let crossAxisStart = Double(index % crossAxisCount) * crossAxisStride
        return SliverGridGeometry(
            scrollOffset: Double(index / crossAxisCount) * mainAxisStride,
            crossAxisOffset: _getOffsetFromStartInCrossAxis(crossAxisStart),
            mainAxisExtent: childMainAxisExtent,
            crossAxisExtent: childCrossAxisExtent
        )
    }

    /// **Dart Source:** `sliver_grid.dart:257-266`
    public func computeMaxScrollOffset(_ childCount: Int) -> Double {
        if childCount == 0 {
            return 0.0
        }
        let mainAxisCount = ((childCount - 1) / crossAxisCount) + 1
        let mainAxisSpacing = mainAxisStride - childMainAxisExtent
        return mainAxisStride * Double(mainAxisCount) - mainAxisSpacing
    }
}

// MARK: - SliverGridDelegate

/// Controls the layout of tiles in a grid.
///
/// Given the current constraints on the grid, a `SliverGridDelegate` computes
/// the layout for the tiles in the grid. The tiles can be placed arbitrarily,
/// but it is more efficient to place tiles roughly in order by scroll offset
/// because grids reify a contiguous sequence of children.
///
/// **Dart Source:** `sliver_grid.dart:294-309`
public protocol SliverGridDelegate: AnyObject {

    /// Returns information about the size and position of the tiles in the grid.
    ///
    /// **Dart Source:** `sliver_grid.dart:300`
    func getLayout(_ constraints: SliverConstraints) -> SliverGridLayout

    /// Override this method to return true when the children need to be
    /// laid out.
    ///
    /// This should compare the fields of the current delegate and the given
    /// `oldDelegate` and return true if the fields are such that the layout would
    /// be different.
    ///
    /// **Dart Source:** `sliver_grid.dart:308`
    func shouldRelayout(_ oldDelegate: SliverGridDelegate) -> Bool
}

// MARK: - SliverGridDelegateWithFixedCrossAxisCount

/// Creates grid layouts with a fixed number of tiles in the cross axis.
///
/// For example, if the grid is vertical, this delegate will create a layout
/// with a fixed number of columns. If the grid is horizontal, this delegate
/// will create a layout with a fixed number of rows.
///
/// This delegate creates grids with equally sized and spaced tiles.
///
/// **Dart Source:** `sliver_grid.dart:346-418`
public class SliverGridDelegateWithFixedCrossAxisCount: SliverGridDelegate {

    /// Creates a delegate that makes grid layouts with a fixed number of tiles in
    /// the cross axis.
    ///
    /// The `mainAxisSpacing`, `mainAxisExtent` and `crossAxisSpacing` arguments
    /// must not be negative. The `crossAxisCount` and `childAspectRatio`
    /// arguments must be greater than zero.
    ///
    /// **Dart Source:** `sliver_grid.dart:353-363`
    public init(
        crossAxisCount: Int,
        mainAxisSpacing: Double = 0.0,
        crossAxisSpacing: Double = 0.0,
        childAspectRatio: Double = 1.0,
        mainAxisExtent: Double? = nil
    ) {
        assert(crossAxisCount > 0)
        assert(mainAxisSpacing >= 0)
        assert(crossAxisSpacing >= 0)
        assert(childAspectRatio > 0)
        assert(mainAxisExtent == nil || mainAxisExtent! >= 0)
        self.crossAxisCount = crossAxisCount
        self.mainAxisSpacing = mainAxisSpacing
        self.crossAxisSpacing = crossAxisSpacing
        self.childAspectRatio = childAspectRatio
        self.mainAxisExtent = mainAxisExtent
    }

    /// The number of children in the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:366`
    public let crossAxisCount: Int

    /// The number of logical pixels between each child along the main axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:369`
    public let mainAxisSpacing: Double

    /// The number of logical pixels between each child along the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:372`
    public let crossAxisSpacing: Double

    /// The ratio of the cross-axis to the main-axis extent of each child.
    ///
    /// **Dart Source:** `sliver_grid.dart:375`
    public let childAspectRatio: Double

    /// The extent of each tile in the main axis. If provided it would define the
    /// logical pixels taken by each tile in the main-axis.
    ///
    /// If nil, `childAspectRatio` is used instead.
    ///
    /// **Dart Source:** `sliver_grid.dart:381`
    public let mainAxisExtent: Double?

    /// **Dart Source:** `sliver_grid.dart:392-408`
    public func getLayout(_ constraints: SliverConstraints) -> SliverGridLayout {
        let usableCrossAxisExtent = max(
            0.0,
            constraints.crossAxisExtent - crossAxisSpacing * Double(crossAxisCount - 1)
        )
        let childCrossAxisExtent = usableCrossAxisExtent / Double(crossAxisCount)
        let childMainAxisExtent = mainAxisExtent ?? childCrossAxisExtent / childAspectRatio
        return SliverGridRegularTileLayout(
            crossAxisCount: crossAxisCount,
            mainAxisStride: childMainAxisExtent + mainAxisSpacing,
            crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
            childMainAxisExtent: childMainAxisExtent,
            childCrossAxisExtent: childCrossAxisExtent,
            reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection)
        )
    }

    /// **Dart Source:** `sliver_grid.dart:411-417`
    public func shouldRelayout(_ oldDelegate: SliverGridDelegate) -> Bool {
        guard let oldDelegate = oldDelegate as? SliverGridDelegateWithFixedCrossAxisCount else {
            return true
        }
        return oldDelegate.crossAxisCount != crossAxisCount
            || oldDelegate.mainAxisSpacing != mainAxisSpacing
            || oldDelegate.crossAxisSpacing != crossAxisSpacing
            || oldDelegate.childAspectRatio != childAspectRatio
            || oldDelegate.mainAxisExtent != mainAxisExtent
    }
}

// MARK: - SliverGridDelegateWithMaxCrossAxisExtent

/// Creates grid layouts with tiles that each have a maximum cross-axis extent.
///
/// This delegate will select a cross-axis extent for the tiles that is as
/// large as possible subject to the following conditions:
///
///  - The extent evenly divides the cross-axis extent of the grid.
///  - The extent is at most `maxCrossAxisExtent`.
///
/// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
/// `maxCrossAxisExtent` is 150.0, this delegate will create a grid with 4
/// columns that are 125.0 pixels wide.
///
/// This delegate creates grids with equally sized and spaced tiles.
///
/// **Dart Source:** `sliver_grid.dart:445-533`
public class SliverGridDelegateWithMaxCrossAxisExtent: SliverGridDelegate {

    /// Creates a delegate that makes grid layouts with tiles that have a maximum
    /// cross-axis extent.
    ///
    /// The `maxCrossAxisExtent`, `mainAxisExtent`, `mainAxisSpacing`,
    /// and `crossAxisSpacing` arguments must not be negative.
    /// The `childAspectRatio` argument must be greater than zero.
    ///
    /// **Dart Source:** `sliver_grid.dart:452-462`
    public init(
        maxCrossAxisExtent: Double,
        mainAxisSpacing: Double = 0.0,
        crossAxisSpacing: Double = 0.0,
        childAspectRatio: Double = 1.0,
        mainAxisExtent: Double? = nil
    ) {
        assert(maxCrossAxisExtent > 0)
        assert(mainAxisSpacing >= 0)
        assert(crossAxisSpacing >= 0)
        assert(childAspectRatio > 0)
        assert(mainAxisExtent == nil || mainAxisExtent! >= 0)
        self.maxCrossAxisExtent = maxCrossAxisExtent
        self.mainAxisSpacing = mainAxisSpacing
        self.crossAxisSpacing = crossAxisSpacing
        self.childAspectRatio = childAspectRatio
        self.mainAxisExtent = mainAxisExtent
    }

    /// The maximum extent of tiles in the cross axis.
    ///
    /// This delegate will select a cross-axis extent for the tiles that is as
    /// large as possible subject to the following conditions:
    ///
    ///  - The extent evenly divides the cross-axis extent of the grid.
    ///  - The extent is at most `maxCrossAxisExtent`.
    ///
    /// **Dart Source:** `sliver_grid.dart:475`
    public let maxCrossAxisExtent: Double

    /// The number of logical pixels between each child along the main axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:478`
    public let mainAxisSpacing: Double

    /// The number of logical pixels between each child along the cross axis.
    ///
    /// **Dart Source:** `sliver_grid.dart:481`
    public let crossAxisSpacing: Double

    /// The ratio of the cross-axis to the main-axis extent of each child.
    ///
    /// **Dart Source:** `sliver_grid.dart:484`
    public let childAspectRatio: Double

    /// The extent of each tile in the main axis. If provided it would define the
    /// logical pixels taken by each tile in the main-axis.
    ///
    /// If nil, `childAspectRatio` is used instead.
    ///
    /// **Dart Source:** `sliver_grid.dart:491`
    public let mainAxisExtent: Double?

    /// **Dart Source:** `sliver_grid.dart:502-523`
    public func getLayout(_ constraints: SliverConstraints) -> SliverGridLayout {
        var crossAxisCount = Int(
            (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing)).rounded(.up)
        )
        // Ensure a minimum count of 1, can be zero and result in an infinite extent
        // below when the window size is 0.
        crossAxisCount = max(1, crossAxisCount)
        let usableCrossAxisExtent = max(
            0.0,
            constraints.crossAxisExtent - crossAxisSpacing * Double(crossAxisCount - 1)
        )
        let childCrossAxisExtent = usableCrossAxisExtent / Double(crossAxisCount)
        let childMainAxisExtent = mainAxisExtent ?? childCrossAxisExtent / childAspectRatio
        return SliverGridRegularTileLayout(
            crossAxisCount: crossAxisCount,
            mainAxisStride: childMainAxisExtent + mainAxisSpacing,
            crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
            childMainAxisExtent: childMainAxisExtent,
            childCrossAxisExtent: childCrossAxisExtent,
            reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection)
        )
    }

    /// **Dart Source:** `sliver_grid.dart:526-532`
    public func shouldRelayout(_ oldDelegate: SliverGridDelegate) -> Bool {
        guard let oldDelegate = oldDelegate as? SliverGridDelegateWithMaxCrossAxisExtent else {
            return true
        }
        return oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent
            || oldDelegate.mainAxisSpacing != mainAxisSpacing
            || oldDelegate.crossAxisSpacing != crossAxisSpacing
            || oldDelegate.childAspectRatio != childAspectRatio
            || oldDelegate.mainAxisExtent != mainAxisExtent
    }
}

// MARK: - SliverGridParentData

/// Parent data structure used by `RenderSliverGrid`.
///
/// **Dart Source:** `sliver_grid.dart:536-547`
public class SliverGridParentData: SliverMultiBoxAdaptorParentData {

    /// The offset of the child in the non-scrolling axis.
    ///
    /// If the scroll axis is vertical, this offset is from the left-most edge of
    /// the parent to the left-most edge of the child. If the scroll axis is
    /// horizontal, this offset is from the top-most edge of the parent to the
    /// top-most edge of the child.
    ///
    /// **Dart Source:** `sliver_grid.dart:543`
    public var crossAxisOffset: Double?

    /// **Dart Source:** `sliver_grid.dart:546`
    public override var description: String {
        "crossAxisOffset=\(crossAxisOffset.map { String($0) } ?? "nil"); \(super.description)"
    }
}

// MARK: - RenderSliverGrid

/// A sliver that places multiple box children in a two dimensional arrangement.
///
/// `RenderSliverGrid` places its children in arbitrary positions determined by
/// `gridDelegate`. Each child is forced to have the size specified by the
/// `gridDelegate`.
///
/// **Dart Source:** `sliver_grid.dart:561-729`
open class RenderSliverGrid: RenderSliverMultiBoxAdaptor {

    /// Creates a sliver that contains multiple box children whose size and
    /// position are determined by a delegate.
    ///
    /// **Dart Source:** `sliver_grid.dart:564-565`
    public init(childManager: RenderSliverBoxChildManager, gridDelegate: SliverGridDelegate) {
        self._gridDelegate = gridDelegate
        super.init(childManager: childManager)
    }

    /// **Dart Source:** `sliver_grid.dart:568-572`
    open override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is SliverGridParentData) {
            child.parentData = SliverGridParentData()
        }
    }

    /// The delegate that controls the size and position of the children.
    ///
    /// **Dart Source:** `sliver_grid.dart:575-585`
    public var gridDelegate: SliverGridDelegate {
        get { _gridDelegate }
        set {
            if _gridDelegate === newValue {
                return
            }
            if type(of: newValue) != type(of: _gridDelegate)
                || newValue.shouldRelayout(_gridDelegate)
            {
                markNeedsLayout()
            }
            _gridDelegate = newValue
        }
    }
    private var _gridDelegate: SliverGridDelegate

    /// **Dart Source:** `sliver_grid.dart:588-591`
    open override func childCrossAxisPosition(_ child: RenderObject) -> Double {
        let childParentData = child.parentData! as! SliverGridParentData
        return childParentData.crossAxisOffset!
    }

    /// **Dart Source:** `sliver_grid.dart:594-728`
    open override func performLayout() {
        let constraints = self.sliverConstraints
        childManager.didStartLayout()
        childManager.setDidUnderflow(false)

        let scrollOffset = constraints.scrollOffset + constraints.cacheOrigin
        assert(scrollOffset >= 0.0)
        let remainingExtent = constraints.remainingCacheExtent
        assert(remainingExtent >= 0.0)
        let targetEndScrollOffset = scrollOffset + remainingExtent

        let layout = _gridDelegate.getLayout(constraints)

        let firstIndex = layout.getMinChildIndexForScrollOffset(scrollOffset)
        let targetLastIndex: Int? = targetEndScrollOffset.isFinite
            ? layout.getMaxChildIndexForScrollOffset(targetEndScrollOffset)
            : nil

        if firstChild != nil {
            let leadingGarbage = calculateLeadingGarbage(firstIndex: firstIndex)
            let trailingGarbage = targetLastIndex != nil
                ? calculateTrailingGarbage(lastIndex: targetLastIndex!)
                : 0
            collectGarbage(leadingGarbage, trailingGarbage)
        } else {
            collectGarbage(0, 0)
        }

        let firstChildGridGeometry = layout.getGeometryForChildIndex(firstIndex)

        if firstChild == nil {
            if !addInitialChild(
                index: firstIndex,
                layoutOffset: firstChildGridGeometry.scrollOffset
            ) {
                // There are either no children, or we are past the end of all our children.
                let maxExtent = layout.computeMaxScrollOffset(childManager.childCount)
                geometry = SliverGeometry(
                    scrollExtent: maxExtent,
                    maxPaintExtent: maxExtent
                )
                childManager.didFinishLayout()
                return
            }
        }

        let leadingScrollOffset = firstChildGridGeometry.scrollOffset
        var trailingScrollOffset = firstChildGridGeometry.trailingScrollOffset
        var trailingChildWithLayout: RenderBox?
        var reachedEnd = false

        // Layout children before firstChild that should be visible.
        var index = indexOf(firstChild!) - 1
        while index >= firstIndex {
            let gridGeometry = layout.getGeometryForChildIndex(index)
            let child = insertAndLayoutLeadingChild(
                gridGeometry.getBoxConstraints(constraints)
            )!
            let childParentData = child.parentData! as! SliverGridParentData
            childParentData.layoutOffset = gridGeometry.scrollOffset
            childParentData.crossAxisOffset = gridGeometry.crossAxisOffset
            assert(childParentData.index == index)
            if trailingChildWithLayout == nil {
                trailingChildWithLayout = child
            }
            trailingScrollOffset = max(trailingScrollOffset, gridGeometry.trailingScrollOffset)
            index -= 1
        }

        if trailingChildWithLayout == nil {
            firstChild!.layout(firstChildGridGeometry.getBoxConstraints(constraints))
            let childParentData = firstChild!.parentData! as! SliverGridParentData
            childParentData.layoutOffset = firstChildGridGeometry.scrollOffset
            childParentData.crossAxisOffset = firstChildGridGeometry.crossAxisOffset
            trailingChildWithLayout = firstChild
        }

        // Layout children after trailingChildWithLayout.
        index = indexOf(trailingChildWithLayout!) + 1
        while targetLastIndex == nil || index <= targetLastIndex! {
            let gridGeometry = layout.getGeometryForChildIndex(index)
            let childConstraints = gridGeometry.getBoxConstraints(constraints)
            var child = childAfter(trailingChildWithLayout!)
            if child == nil || indexOf(child!) != index {
                child = insertAndLayoutChild(childConstraints, after: trailingChildWithLayout!)
                if child == nil {
                    reachedEnd = true
                    break
                }
            } else {
                child!.layout(childConstraints)
            }
            trailingChildWithLayout = child
            let childParentData = child!.parentData! as! SliverGridParentData
            childParentData.layoutOffset = gridGeometry.scrollOffset
            childParentData.crossAxisOffset = gridGeometry.crossAxisOffset
            assert(childParentData.index == index)
            trailingScrollOffset = max(trailingScrollOffset, gridGeometry.trailingScrollOffset)
            index += 1
        }

        let lastIndex = indexOf(lastChild!)

        assert(debugAssertChildListIsNonEmptyAndContiguous())
        assert(indexOf(firstChild!) == firstIndex)
        assert(targetLastIndex == nil || lastIndex <= targetLastIndex!)

        let estimatedTotalExtent: Double
        if reachedEnd {
            estimatedTotalExtent = trailingScrollOffset
        } else {
            estimatedTotalExtent = childManager.estimateMaxScrollOffset(
                constraints,
                firstIndex: firstIndex,
                lastIndex: lastIndex,
                leadingScrollOffset: leadingScrollOffset,
                trailingScrollOffset: trailingScrollOffset
            )
        }

        let paintExtent = calculatePaintOffset(
            constraints,
            from: min(constraints.scrollOffset, leadingScrollOffset),
            to: trailingScrollOffset
        )
        let cacheExtent = calculateCacheOffset(
            constraints,
            from: leadingScrollOffset,
            to: trailingScrollOffset
        )

        geometry = SliverGeometry(
            scrollExtent: estimatedTotalExtent,
            paintExtent: paintExtent,
            maxPaintExtent: estimatedTotalExtent,
            hasVisualOverflow: estimatedTotalExtent > paintExtent
                || constraints.scrollOffset > 0.0
                || constraints.overlap != 0.0,
            cacheExtent: cacheExtent
        )

        // We may have started the layout while scrolled to the end, which
        // would not expose a new child.
        if estimatedTotalExtent == trailingScrollOffset {
            childManager.setDidUnderflow(true)
        }
        childManager.didFinishLayout()
    }
}
