// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sliver fixed/varied extent list types.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver_fixed_extent_list.dart`

import FlutterSwiftBridge

// =============================================================================
// MARK: - S1: RenderSliverFixedExtentBoxAdaptor
// =============================================================================

/// A sliver that contains multiple box children that have the explicit extent
/// in the main axis.
///
/// `RenderSliverFixedExtentBoxAdaptor` places its children in a linear array
/// along the main axis. Each child is forced to have the returned value of
/// `itemExtentBuilder` when the `itemExtentBuilder` is non-nil, or the
/// `itemExtent` when `itemExtentBuilder` is nil, in the main axis and the
/// `SliverConstraints.crossAxisExtent` in the cross axis.
///
/// Subclasses should override `itemExtent` or `itemExtentBuilder` to control
/// the size of the children in the main axis. For a concrete subclass with a
/// configurable `itemExtent`, see `RenderSliverFixedExtentList` or
/// `RenderSliverVariedExtentList`.
///
/// `RenderSliverFixedExtentBoxAdaptor` is more efficient than
/// `RenderSliverList` because `RenderSliverFixedExtentBoxAdaptor` does not
/// need to perform layout on its children to obtain their extent in the
/// main axis.
///
/// See also:
///
///  - `RenderSliverFixedExtentList`, which has a configurable `itemExtent`.
///  - `RenderSliverFillViewport`, which determines the `itemExtent` based on
///    `SliverConstraints.viewportMainAxisExtent`.
///  - `RenderSliverFillRemaining`, which determines the `itemExtent` based on
///    `SliverConstraints.remainingPaintExtent`.
///  - `RenderSliverList`, which does not require its children to have the same
///    extent in the main axis.
///
/// **Dart Source:** `sliver_fixed_extent_list.dart:42-448`
open class RenderSliverFixedExtentBoxAdaptor: RenderSliverMultiBoxAdaptor {

    // MARK: - Initializer

    /// Creates a sliver that contains multiple box children that have the same
    /// extent in the main axis.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:45`
    public override init(childManager: any RenderSliverBoxChildManager) {
        super.init(childManager: childManager)
    }

    // MARK: - Properties

    /// The main-axis extent of each item.
    ///
    /// If this is non-nil, the `itemExtentBuilder` must be nil.
    /// If this is nil, the `itemExtentBuilder` must be non-nil.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:51`
    open var itemExtent: Double? {
        fatalError("Subclass must override itemExtent")
    }

    /// The main-axis extent builder of each item.
    ///
    /// If this is non-nil, the `itemExtent` must be nil.
    /// If this is nil, the `itemExtent` must be non-nil.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:57`
    open var itemExtentBuilder: ItemExtentBuilder? { nil }

    // MARK: - Layout Offset Computation

    /// The current sliver layout dimensions, set at the beginning of each layout pass.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:273`
    private var _currentLayoutDimensions: SliverLayoutDimensions!

    /// The layout offset for the child with the given index.
    ///
    /// This function uses the returned value of `itemExtentBuilder` or the
    /// `itemExtent` to avoid recomputing item size repeatedly during layout.
    ///
    /// By default, places the children in order, without gaps, starting from
    /// layout offset zero.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:68-95`
    open func indexToLayoutOffset(_ itemExtent: Double, _ index: Int) -> Double {
        if itemExtentBuilder == nil {
            let extent = self.itemExtent!
            return extent * Double(index)
        } else {
            var offset = 0.0
            for i in 0..<index {
                let childCount = childManager.estimatedChildCount
                if let childCount = childCount, i > childCount - 1 {
                    break
                }
                let extent = itemExtentBuilder!(i, _currentLayoutDimensions)
                if extent == nil {
                    break
                }
                offset += extent!
            }
            return offset
        }
    }

    /// The minimum child index that is visible at the given scroll offset.
    ///
    /// This function uses the returned value of `itemExtentBuilder` or the
    /// `itemExtent` to avoid recomputing item size repeatedly during layout.
    ///
    /// By default, returns a value consistent with the children being placed in
    /// order, without gaps, starting from layout offset zero.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:106-128`
    open func getMinChildIndexForScrollOffset(
        _ scrollOffset: Double,
        _ itemExtent: Double
    ) -> Int {
        if itemExtentBuilder == nil {
            let extent = self.itemExtent!
            if extent > 0.0 {
                let actual = scrollOffset / extent
                let round = Int((actual).rounded())
                if Swift.abs(actual * extent - Double(round) * extent) < precisionErrorTolerance {
                    return round
                }
                return Int(actual)
            }
            return 0
        } else {
            return _getChildIndexForScrollOffset(scrollOffset, itemExtentBuilder!)
        }
    }

    /// The maximum child index that is visible at the given scroll offset.
    ///
    /// This function uses the returned value of `itemExtentBuilder` or the
    /// `itemExtent` to avoid recomputing item size repeatedly during layout.
    ///
    /// By default, returns a value consistent with the children being placed in
    /// order, without gaps, starting from layout offset zero.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:139-161`
    open func getMaxChildIndexForScrollOffset(
        _ scrollOffset: Double,
        _ itemExtent: Double
    ) -> Int {
        if itemExtentBuilder == nil {
            let extent = self.itemExtent!
            if extent > 0.0 {
                let actual = scrollOffset / extent - 1
                let round = Int((actual).rounded())
                if Swift.abs(actual * extent - Double(round) * extent) < precisionErrorTolerance {
                    return max(0, round)
                }
                return max(0, Int(actual.rounded(.up)))
            }
            return 0
        } else {
            return _getChildIndexForScrollOffset(scrollOffset, itemExtentBuilder!)
        }
    }

    /// Called to estimate the total scrollable extents of this object.
    ///
    /// Must return the total distance from the start of the child with the
    /// earliest possible index to the end of the child with the last possible
    /// index.
    ///
    /// By default, defers to `RenderSliverBoxChildManager.estimateMaxScrollOffset`.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:176-190`
    open func estimateMaxScrollOffset(
        _ constraints: SliverConstraints,
        firstIndex: Int? = nil,
        lastIndex: Int? = nil,
        leadingScrollOffset: Double? = nil,
        trailingScrollOffset: Double? = nil
    ) -> Double {
        return childManager.estimateMaxScrollOffset(
            constraints,
            firstIndex: firstIndex,
            lastIndex: lastIndex,
            leadingScrollOffset: leadingScrollOffset,
            trailingScrollOffset: trailingScrollOffset
        )
    }

    /// Called to obtain a precise measure of the total scrollable extents of
    /// this object.
    ///
    /// If `itemExtentBuilder` is nil, multiplies the `itemExtent` by the number
    /// of children reported by `RenderSliverBoxChildManager.childCount`.
    /// If `itemExtentBuilder` is non-nil, sums the extents of the first
    /// `childCount` children.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:216-239`
    open func computeMaxScrollOffset(
        _ constraints: SliverConstraints,
        _ itemExtent: Double
    ) -> Double {
        if itemExtentBuilder == nil {
            let extent = self.itemExtent!
            return Double(childManager.childCount) * extent
        } else {
            var offset = 0.0
            for i in 0..<childManager.childCount {
                let extent = itemExtentBuilder!(i, _currentLayoutDimensions)
                if extent == nil {
                    break
                }
                offset += extent!
            }
            return offset
        }
    }

    // MARK: - Private Helpers

    /// Returns the child index for a given scroll offset when using a variable extent builder.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:241-261`
    private func _getChildIndexForScrollOffset(
        _ scrollOffset: Double,
        _ callback: ItemExtentBuilder
    ) -> Int {
        if scrollOffset == 0.0 {
            return 0
        }
        var position = 0.0
        var index = 0
        while position < scrollOffset {
            let childCount = childManager.estimatedChildCount
            if let childCount = childCount, index > childCount - 1 {
                break
            }
            let extent = callback(index, _currentLayoutDimensions)
            if extent == nil {
                break
            }
            position += extent!
            index += 1
        }
        return index - 1
    }

    /// Returns the box constraints for the child at the given index.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:263-271`
    private func _getChildConstraints(_ index: Int) -> BoxConstraints {
        let extent: Double
        if itemExtentBuilder == nil {
            extent = itemExtent!
        } else {
            extent = itemExtentBuilder!(index, _currentLayoutDimensions)!
        }
        return sliverConstraints.asBoxConstraints(minExtent: extent, maxExtent: extent)
    }

    // MARK: - Layout

    /// Performs the layout of this sliver.
    ///
    /// Computes the first and last visible child indices from the scroll offset
    /// and item extents, creates/recycles children on demand, and sets the
    /// sliver geometry.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:276-448`
    open override func performLayout() {
        assert(
            (itemExtent != nil && itemExtentBuilder == nil)
                || (itemExtent == nil && itemExtentBuilder != nil)
        )
        assert(itemExtentBuilder != nil || (itemExtent!.isFinite && itemExtent! >= 0))

        let constraints = self.sliverConstraints
        childManager.didStartLayout()
        childManager.setDidUnderflow(false)

        let scrollOffset = constraints.scrollOffset + constraints.cacheOrigin
        assert(scrollOffset >= 0.0)
        let remainingExtent = constraints.remainingCacheExtent
        assert(remainingExtent >= 0.0)
        let targetEndScrollOffset = scrollOffset + remainingExtent

        _currentLayoutDimensions = SliverLayoutDimensions(
            scrollOffset: constraints.scrollOffset,
            precedingScrollExtent: constraints.precedingScrollExtent,
            viewportMainAxisExtent: constraints.viewportMainAxisExtent,
            crossAxisExtent: constraints.crossAxisExtent
        )

        // The deprecated extra item extent constant (unused but required by the API).
        let deprecatedExtraItemExtent: Double = -1

        let firstIndex = getMinChildIndexForScrollOffset(scrollOffset, deprecatedExtraItemExtent)
        let targetLastIndex: Int? = targetEndScrollOffset.isFinite
            ? getMaxChildIndexForScrollOffset(targetEndScrollOffset, deprecatedExtraItemExtent)
            : nil

        if firstChild != nil {
            let leadingGarbage = calculateLeadingGarbage(firstIndex: firstIndex)
            let trailingGarbage: Int
            if let targetLastIndex = targetLastIndex {
                trailingGarbage = calculateTrailingGarbage(lastIndex: targetLastIndex)
            } else {
                trailingGarbage = 0
            }
            collectGarbage(leadingGarbage, trailingGarbage)
        } else {
            collectGarbage(0, 0)
        }

        if firstChild == nil {
            let layoutOffset = indexToLayoutOffset(deprecatedExtraItemExtent, firstIndex)
            if !addInitialChild(index: firstIndex, layoutOffset: layoutOffset) {
                // There are either no children, or we are past the end of all our children.
                let maxScrollExtent: Double
                if firstIndex <= 0 {
                    maxScrollExtent = 0.0
                } else {
                    maxScrollExtent = computeMaxScrollOffset(constraints, deprecatedExtraItemExtent)
                }
                geometry = SliverGeometry(
                    scrollExtent: maxScrollExtent,
                    maxPaintExtent: maxScrollExtent
                )
                childManager.didFinishLayout()
                return
            }
        }

        var trailingChildWithLayout: RenderBox?

        for index in stride(from: indexOf(firstChild!) - 1, through: firstIndex, by: -1) {
            let child = insertAndLayoutLeadingChild(_getChildConstraints(index))
            if child == nil {
                // Items before the previously first child are no longer present.
                // Reset the scroll offset to offset all items prior and up to the
                // missing item. Let parent re-layout everything.
                geometry = SliverGeometry(
                    scrollOffsetCorrection: indexToLayoutOffset(deprecatedExtraItemExtent, index)
                )
                return
            }
            let childParentData = child!.parentData! as! SliverMultiBoxAdaptorParentData
            childParentData.layoutOffset = indexToLayoutOffset(deprecatedExtraItemExtent, index)
            assert(childParentData.index == index)
            if trailingChildWithLayout == nil {
                trailingChildWithLayout = child
            }
        }

        if trailingChildWithLayout == nil {
            firstChild!.layout(_getChildConstraints(indexOf(firstChild!)))
            let childParentData = firstChild!.parentData! as! SliverMultiBoxAdaptorParentData
            childParentData.layoutOffset = indexToLayoutOffset(
                deprecatedExtraItemExtent, firstIndex
            )
            trailingChildWithLayout = firstChild
        }

        var estimatedMaxScrollOffset = Double.infinity
        var index = indexOf(trailingChildWithLayout!) + 1
        while targetLastIndex == nil || index <= targetLastIndex! {
            var child = childAfter(trailingChildWithLayout!)
            if child == nil || indexOf(child!) != index {
                child = insertAndLayoutChild(
                    _getChildConstraints(index),
                    after: trailingChildWithLayout!
                )
                if child == nil {
                    // We have run out of children.
                    estimatedMaxScrollOffset = indexToLayoutOffset(
                        deprecatedExtraItemExtent, index
                    )
                    break
                }
            } else {
                child!.layout(_getChildConstraints(index))
            }
            trailingChildWithLayout = child
            let childParentData = child!.parentData! as! SliverMultiBoxAdaptorParentData
            assert(childParentData.index == index)
            childParentData.layoutOffset = indexToLayoutOffset(
                deprecatedExtraItemExtent,
                childParentData.index!
            )
            index += 1
        }

        let lastIndex = indexOf(lastChild!)
        let leadingScrollOffset = indexToLayoutOffset(deprecatedExtraItemExtent, firstIndex)
        let trailingScrollOffset = indexToLayoutOffset(
            deprecatedExtraItemExtent,
            lastIndex + 1
        )

        assert(
            firstIndex == 0
                || childScrollOffset(firstChild!)! - scrollOffset <= precisionErrorTolerance
        )
        assert(debugAssertChildListIsNonEmptyAndContiguous())
        assert(indexOf(firstChild!) == firstIndex)
        assert(targetLastIndex == nil || lastIndex <= targetLastIndex!)

        estimatedMaxScrollOffset = min(
            estimatedMaxScrollOffset,
            estimateMaxScrollOffset(
                constraints,
                firstIndex: firstIndex,
                lastIndex: lastIndex,
                leadingScrollOffset: leadingScrollOffset,
                trailingScrollOffset: trailingScrollOffset
            )
        )

        let paintExtent = calculatePaintOffset(
            constraints,
            from: leadingScrollOffset,
            to: trailingScrollOffset
        )

        let cacheExtent = calculateCacheOffset(
            constraints,
            from: leadingScrollOffset,
            to: trailingScrollOffset
        )

        let targetEndScrollOffsetForPaint =
            constraints.scrollOffset + constraints.remainingPaintExtent
        let targetLastIndexForPaint: Int? =
            targetEndScrollOffsetForPaint.isFinite
            ? getMaxChildIndexForScrollOffset(
                targetEndScrollOffsetForPaint, deprecatedExtraItemExtent)
            : nil

        geometry = SliverGeometry(
            scrollExtent: estimatedMaxScrollOffset,
            paintExtent: paintExtent,
            maxPaintExtent: estimatedMaxScrollOffset,
            // Conservative to avoid flickering away the clip during scroll.
            hasVisualOverflow: (targetLastIndexForPaint != nil
                && lastIndex >= targetLastIndexForPaint!)
                || constraints.scrollOffset > 0.0,
            cacheExtent: cacheExtent
        )

        // We may have started the layout while scrolled to the end, which would
        // not expose a new child.
        if estimatedMaxScrollOffset == trailingScrollOffset {
            childManager.setDidUnderflow(true)
        }
        childManager.didFinishLayout()
    }
}

// =============================================================================
// MARK: - S2: RenderSliverFixedExtentList
// =============================================================================

/// A sliver that places multiple box children with the same main axis extent
/// in a linear array.
///
/// `RenderSliverFixedExtentList` places its children in a linear array along
/// the main axis starting at offset zero and without gaps. Each child is forced
/// to have the `itemExtent` in the main axis and the
/// `SliverConstraints.crossAxisExtent` in the cross axis.
///
/// `RenderSliverFixedExtentList` is more efficient than `RenderSliverList`
/// because `RenderSliverFixedExtentList` does not need to perform layout on
/// its children to obtain their extent in the main axis.
///
/// See also:
///
///  - `RenderSliverList`, which does not require its children to have the same
///    extent in the main axis.
///  - `RenderSliverFillViewport`, which determines the `itemExtent` based on
///    `SliverConstraints.viewportMainAxisExtent`.
///  - `RenderSliverFillRemaining`, which determines the `itemExtent` based on
///    `SliverConstraints.remainingPaintExtent`.
///
/// **Dart Source:** `sliver_fixed_extent_list.dart:471-487`
open class RenderSliverFixedExtentList: RenderSliverFixedExtentBoxAdaptor {

    // MARK: - Initializer

    /// Creates a sliver that contains multiple box children that have a given
    /// extent in the main axis.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:474-475`
    public init(childManager: any RenderSliverBoxChildManager, itemExtent: Double) {
        _itemExtent = itemExtent
        super.init(childManager: childManager)
    }

    // MARK: - Item Extent

    /// The main-axis extent of each item.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:478-479`
    open override var itemExtent: Double? {
        get { _itemExtent }
    }
    private var _itemExtent: Double

    /// Sets the main-axis extent of each item.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:480-486`
    public func setItemExtent(_ value: Double) {
        if _itemExtent == value {
            return
        }
        _itemExtent = value
        markNeedsLayout()
    }
}

// =============================================================================
// MARK: - S3: RenderSliverVariedExtentList
// =============================================================================

/// A sliver that places multiple box children with the corresponding main axis
/// extent in a linear array.
///
/// **Dart Source:** `sliver_fixed_extent_list.dart:491-512`
open class RenderSliverVariedExtentList: RenderSliverFixedExtentBoxAdaptor {

    // MARK: - Initializer

    /// Creates a sliver that contains multiple box children that have an
    /// explicit extent in the main axis.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:494-497`
    public init(
        childManager: any RenderSliverBoxChildManager,
        itemExtentBuilder: @escaping ItemExtentBuilder
    ) {
        _itemExtentBuilder = itemExtentBuilder
        super.init(childManager: childManager)
    }

    // MARK: - Item Extent Builder

    /// The main-axis extent builder of each item.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:500`
    open override var itemExtentBuilder: ItemExtentBuilder? {
        get { _itemExtentBuilder }
    }
    private var _itemExtentBuilder: ItemExtentBuilder

    /// Sets the main-axis extent builder.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:502-508`
    public func setItemExtentBuilder(_ value: @escaping ItemExtentBuilder) {
        if _itemExtentBuilder as AnyObject === value as AnyObject {
            return
        }
        _itemExtentBuilder = value
        markNeedsLayout()
    }

    // MARK: - Item Extent

    /// Always returns nil; this subclass uses `itemExtentBuilder` instead.
    ///
    /// **Dart Source:** `sliver_fixed_extent_list.dart:511`
    open override var itemExtent: Double? { nil }
}
