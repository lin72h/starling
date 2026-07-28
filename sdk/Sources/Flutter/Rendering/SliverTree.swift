// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sliver tree types for rendering tree-structured lists.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver_tree.dart`

import FlutterSwiftBridge

// MARK: - TreeSliverNodesAnimation

/// Represents the animation of the children of a parent tree node that
/// are animating into or out of view.
///
/// The `fromIndex` and `toIndex` identify the animating children following
/// the parent, with the `value` representing the status of the current
/// animation. The value of `toIndex` is inclusive, meaning the child at that
/// index is included in the animating segment.
///
/// Provided to `RenderTreeSliver` as part of
/// `RenderTreeSliver.activeAnimations` to properly offset animating children.
///
/// **Dart Source:** `sliver_tree.dart:30`
public struct TreeSliverNodesAnimation {
    /// The starting index of the animating children.
    public let fromIndex: Int

    /// The ending index (inclusive) of the animating children.
    public let toIndex: Int

    /// The current animation value (0.0 to 1.0).
    public let value: Double

    /// Creates a tree sliver nodes animation.
    public init(fromIndex: Int, toIndex: Int, value: Double) {
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.value = value
    }
}

// MARK: - TreeSliverNodeParentData

/// Parent data used by `RenderTreeSliver`.
///
/// Extends `SliverMultiBoxAdaptorParentData` with a `depth` property
/// used to offset children by the `TreeSliverIndentationType`.
///
/// **Dart Source:** `sliver_tree.dart:33-37`
public class TreeSliverNodeParentData: SliverMultiBoxAdaptorParentData {
    /// The depth of the node, used by `RenderTreeSliver` to offset children
    /// by the `TreeSliverIndentationType`.
    ///
    /// **Dart Source:** `sliver_tree.dart:36`
    public var depth: Int = 0
}

// MARK: - TreeSliverIndentationType

/// The style of indentation for tree nodes in a tree sliver.
///
/// By default, the indentation is handled by `RenderTreeSliver`. Child nodes
/// are offset by the indentation specified by
/// `TreeSliverIndentationType.value` in the cross axis of the viewport. This
/// means the space allotted to the indentation will not be part of the space
/// made available to the widget returned by the tree node builder.
///
/// Alternatively, the indentation can be implemented in the tree node builder,
/// with the depth of the given tree row accessed by the node's depth. This
/// allows for more customization in building tree rows, such as filling the
/// indented area with decorations or ink effects.
///
/// **Dart Source:** `sliver_tree.dart:65-95`
public struct TreeSliverIndentationType: Sendable {

    /// The number of pixels by which tree nodes will be offset according
    /// to their depth.
    ///
    /// **Dart Source:** `sliver_tree.dart:70-71`
    public let value: Double

    /// Internal initializer.
    private init(_ value: Double) {
        self.value = value
    }

    /// The default indentation of child nodes in a tree sliver.
    ///
    /// Child nodes will be offset by 10 pixels for each level in the tree.
    ///
    /// **Dart Source:** `sliver_tree.dart:76`
    public static let standard = TreeSliverIndentationType(10.0)

    /// Configures no offsetting of child nodes in a tree sliver.
    ///
    /// Useful if the indentation is implemented in the tree node builder
    /// instead for more customization options.
    ///
    /// Child nodes will not be offset in the tree.
    ///
    /// **Dart Source:** `sliver_tree.dart:84`
    public static let none = TreeSliverIndentationType(0.0)

    /// Configures a custom offset for indenting child nodes in a tree sliver.
    ///
    /// Child nodes will be offset by the provided number of pixels in the tree.
    /// The `value` must be a non-negative number.
    ///
    /// **Dart Source:** `sliver_tree.dart:91-94`
    public static func custom(_ value: Double) -> TreeSliverIndentationType {
        assert(value >= 0.0)
        return TreeSliverIndentationType(value)
    }
}

// MARK: - _PaintSegment

/// Used during paint to delineate animating portions of the tree.
///
/// **Dart Source:** `sliver_tree.dart:98`
private struct _PaintSegment {
    let leadingIndex: Int
    let trailingIndex: Int
}

// MARK: - RenderTreeSliver

/// A sliver that places multiple tree nodes in a linear array along the
/// main axis, while staggering nodes that are animating into and out of view.
///
/// The extent of each child node is determined by the `itemExtentBuilder`.
///
/// See also:
///
///  - `TreeSliver`, the widget that creates and manages this render object.
///
/// **Dart Source:** `sliver_tree.dart:109-409`
open class RenderTreeSliver: RenderSliverVariedExtentList {

    // MARK: - Initializer

    /// Creates the render object that lays out the tree nodes of a tree sliver.
    ///
    /// **Dart Source:** `sliver_tree.dart:112-118`
    public init(
        childManager: any RenderSliverBoxChildManager,
        itemExtentBuilder: @escaping ItemExtentBuilder,
        activeAnimations: [UniqueKey: TreeSliverNodesAnimation],
        indentation: Double
    ) {
        self._activeAnimations = activeAnimations
        self._indentation = indentation
        super.init(childManager: childManager, itemExtentBuilder: itemExtentBuilder)
    }

    // MARK: - Active Animations

    /// The currently active tree node animations.
    ///
    /// Since the index of animating nodes can change at any time, the unique key
    /// is used to track an animation of nodes across frames.
    ///
    /// **Dart Source:** `sliver_tree.dart:128-136`
    public var activeAnimations: [UniqueKey: TreeSliverNodesAnimation] {
        get { _activeAnimations }
        set {
            _activeAnimations = newValue
            markNeedsLayout()
        }
    }
    private var _activeAnimations: [UniqueKey: TreeSliverNodesAnimation]

    // MARK: - Indentation

    /// The number of pixels by which child nodes will be offset in the cross axis
    /// based on their `TreeSliverNodeParentData.depth`.
    ///
    /// If zero, can alternatively offset children in the tree node builder for
    /// more options to customize the indented space.
    ///
    /// **Dart Source:** `sliver_tree.dart:144-153`
    public var indentation: Double {
        get { _indentation }
        set {
            if _indentation == newValue {
                return
            }
            assert(newValue >= 0.0)
            _indentation = newValue
            markNeedsLayout()
        }
    }
    private var _indentation: Double

    // MARK: - Animation Cache

    /// Maps the index of parents to the animation key of their children.
    ///
    /// **Dart Source:** `sliver_tree.dart:156`
    private var _animationLeadingIndices: [Int: UniqueKey] = [:]

    /// Maps the key of child node animations to the fixed distance they are
    /// traversing during the animation. Determined at the start of the animation.
    ///
    /// **Dart Source:** `sliver_tree.dart:159`
    private var _animationOffsets: [UniqueKey: Double] = [:]

    /// Updates the animation cache from the current active animations.
    ///
    /// **Dart Source:** `sliver_tree.dart:160-175`
    private func _updateAnimationCache() {
        _animationLeadingIndices.removeAll()
        for (key, animation) in _activeAnimations {
            _animationLeadingIndices[animation.fromIndex - 1] = key
        }
        // Remove any stored offsets or clip layers that are no longer actively
        // animating.
        _animationOffsets = _animationOffsets.filter { key, _ in
            _activeAnimations.keys.contains(key)
        }
        _clipHandles = _clipHandles.filter { key, handle in
            if !_activeAnimations.keys.contains(key) {
                handle.layer = nil
                return false
            }
            return true
        }
    }

    // MARK: - Parent Data

    /// Sets up `TreeSliverNodeParentData` for the given child.
    ///
    /// **Dart Source:** `sliver_tree.dart:178-182`
    open override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is TreeSliverNodeParentData) {
            child.parentData = TreeSliverNodeParentData()
        }
    }

    // MARK: - Dispose

    /// Disposes of the clip layer handles and calls `super.dispose()`.
    ///
    /// **Dart Source:** `sliver_tree.dart:185-191`
    open override func dispose() {
        for (_, handle) in _clipHandles {
            handle.layer = nil
        }
        _clipHandles.removeAll()
        super.dispose()
    }

    // MARK: - Layout

    /// The current sliver layout dimensions, set at the beginning of each
    /// layout pass.
    ///
    /// **Dart Source:** `sliver_tree.dart:196`
    private var _currentLayoutDimensions: SliverLayoutDimensions!

    /// Performs the layout of this tree sliver.
    ///
    /// Asserts that the axis direction is `AxisDirection.down`, updates the
    /// animation cache, and delegates to the super class for layout.
    ///
    /// **Dart Source:** `sliver_tree.dart:199-213`
    open override func performLayout() {
        assert(
            sliverConstraints.axisDirection == .down,
            "TreeSliver is only supported in Viewports with an AxisDirection.down. "
                + "The current axis direction is: \(sliverConstraints.axisDirection)."
        )
        _updateAnimationCache()
        _currentLayoutDimensions = SliverLayoutDimensions(
            scrollOffset: sliverConstraints.scrollOffset,
            precedingScrollExtent: sliverConstraints.precedingScrollExtent,
            viewportMainAxisExtent: sliverConstraints.viewportMainAxisExtent,
            crossAxisExtent: sliverConstraints.crossAxisExtent
        )
        super.performLayout()
    }

    // MARK: - Child Index for Scroll Offset

    /// Returns the minimum child index for the given scroll offset.
    ///
    /// **Dart Source:** `sliver_tree.dart:216-220`
    open override func getMinChildIndexForScrollOffset(
        _ scrollOffset: Double,
        _ itemExtent: Double
    ) -> Int {
        // itemExtent is deprecated in the super class, we ignore it because we
        // use the builder anyways.
        return _getChildIndexForScrollOffset(scrollOffset)
    }

    /// Returns the maximum child index for the given scroll offset.
    ///
    /// **Dart Source:** `sliver_tree.dart:222-227`
    open override func getMaxChildIndexForScrollOffset(
        _ scrollOffset: Double,
        _ itemExtent: Double
    ) -> Int {
        // itemExtent is deprecated in the super class, we ignore it because we
        // use the builder anyways.
        return _getChildIndexForScrollOffset(scrollOffset)
    }

    /// Computes the child index corresponding to a given scroll offset,
    /// accounting for active animations.
    ///
    /// **Dart Source:** `sliver_tree.dart:229-262`
    private func _getChildIndexForScrollOffset(_ scrollOffset: Double) -> Int {
        if scrollOffset == 0.0 {
            return 0
        }
        var position = 0.0
        var index = 0
        var totalAnimationOffset = 0.0
        let childCount = childManager.estimatedChildCount
        while position < scrollOffset {
            if let childCount = childCount, index > childCount - 1 {
                break
            }

            guard let extent = itemExtentBuilder!(index, _currentLayoutDimensions) else {
                break
            }
            if _animationLeadingIndices.keys.contains(index) {
                let animationKey = _animationLeadingIndices[index]!
                if _animationOffsets[animationKey] == nil {
                    // We have not computed the distance this block is traversing
                    // over the lifetime of the animation.
                    _computeAnimationOffsetFor(animationKey, position)
                }
                // We add the offset accounting for the animation value.
                totalAnimationOffset +=
                    _animationOffsets[animationKey]!
                    * (1 - _activeAnimations[animationKey]!.value)
            }
            position += extent - totalAnimationOffset
            index += 1
        }
        return index - 1
    }

    /// Computes the animation offset for a given animation key.
    ///
    /// **Dart Source:** `sliver_tree.dart:264-287`
    private func _computeAnimationOffsetFor(_ key: UniqueKey, _ position: Double) {
        assert(_activeAnimations[key] != nil)
        let targetPosition =
            sliverConstraints.scrollOffset + sliverConstraints.remainingCacheExtent
        var currentPosition = position
        let startingIndex = _activeAnimations[key]!.fromIndex
        let lastIndex = _activeAnimations[key]!.toIndex
        var currentIndex = startingIndex
        var totalAnimatingOffset = 0.0
        // We animate only a portion of children that would be visible/in the
        // cache extent, unless all children would fit on the screen.
        while currentIndex <= lastIndex && currentPosition < targetPosition {
            let itemExtent = itemExtentBuilder!(currentIndex, _currentLayoutDimensions)!
            totalAnimatingOffset += itemExtent
            currentPosition += itemExtent
            currentIndex += 1
        }
        // For the life of this animation, which affects all children following
        // startingIndex (regardless of if they are a child of the triggering
        // parent), they will be offset by totalAnimatingOffset * the animation
        // value. This is because even though more children can be scrolled into
        // view, the same distance must be maintained for a smooth animation.
        _animationOffsets[key] = totalAnimatingOffset
    }

    // MARK: - Cross Axis Position

    /// Returns the cross axis position for the given child, based on its
    /// tree depth and the indentation value.
    ///
    /// **Dart Source:** `sliver_tree.dart:290-293`
    open override func childCrossAxisPosition(_ child: RenderObject) -> Double {
        let parentData = child.parentData! as! TreeSliverNodeParentData
        return Double(parentData.depth) * indentation
    }

    // MARK: - Index to Layout Offset

    /// Returns the layout offset for the child at the given index, accounting
    /// for active animations.
    ///
    /// **Dart Source:** `sliver_tree.dart:296-324`
    open override func indexToLayoutOffset(_ itemExtent: Double, _ index: Int) -> Double {
        // itemExtent is deprecated in the super class, we ignore it because we
        // use the builder anyways.
        var position = 0.0
        var currentIndex = 0
        var totalAnimationOffset = 0.0
        let childCount = childManager.estimatedChildCount
        while currentIndex < index {
            if let childCount = childCount, currentIndex > childCount - 1 {
                break
            }

            guard let extent = itemExtentBuilder!(currentIndex, _currentLayoutDimensions) else {
                break
            }
            if _animationLeadingIndices.keys.contains(currentIndex) {
                let animationKey = _animationLeadingIndices[currentIndex]!
                assert(_animationOffsets[animationKey] != nil)
                // We add the offset accounting for the animation value.
                totalAnimationOffset +=
                    _animationOffsets[animationKey]!
                    * (1 - _activeAnimations[animationKey]!.value)
            }
            position += extent
            currentIndex += 1
        }
        return position - totalAnimationOffset
    }

    // MARK: - Clip Handles

    /// Clip layer handles used during paint for animating segments.
    ///
    /// **Dart Source:** `sliver_tree.dart:326-327`
    private var _clipHandles: [UniqueKey: LayerHandle<ClipRectLayer>] = [:]

    // MARK: - Paint

    /// Paints this tree sliver and its visible children.
    ///
    /// Handles clipping for animating segments so that expanding/collapsing
    /// nodes do not overlap their siblings.
    ///
    /// **Dart Source:** `sliver_tree.dart:330-407`
    open override func paint(_ context: PaintingContext, _ offset: Offset) {
        guard firstChild != nil else {
            return
        }

        var nextChild: RenderBox? = firstChild

        func paintUpTo(
            _ index: Int,
            startWith: RenderBox?,
            context: PaintingContext,
            offset: Offset
        ) {
            var child = startWith
            while let current = child, indexOf(current) <= index {
                let mainAxisDelta = childMainAxisPosition(current)
                let parentData = current.parentData! as! TreeSliverNodeParentData
                let childOffset =
                    Offset(
                        Double(parentData.depth) * indentation,
                        parentData.layoutOffset! - sliverConstraints.scrollOffset
                    ) + offset
                // If the child's visible interval (mainAxisDelta, mainAxisDelta +
                // paintExtentOf(child)) does not intersect the paint extent
                // interval (0, constraints.remainingPaintExtent), it's hidden.
                if mainAxisDelta < sliverConstraints.remainingPaintExtent
                    && mainAxisDelta + paintExtentOf(current) > 0
                {
                    context.paintChild(current, childOffset)
                }
                child = childAfter(current)
            }
            nextChild = child
        }

        if _animationLeadingIndices.isEmpty {
            // There are no animations running.
            paintUpTo(indexOf(lastChild!), startWith: firstChild, context: context, offset: offset)
            return
        }

        // We are animating.
        // Separate animating segments to clip for any overlap.
        var leadingIndex = indexOf(firstChild!)
        var animationIndices = _animationLeadingIndices.keys.sorted()
        var paintSegments: [_PaintSegment] = []
        while !animationIndices.isEmpty {
            let trailingIndex = animationIndices.removeFirst()
            paintSegments.append(
                _PaintSegment(leadingIndex: leadingIndex, trailingIndex: trailingIndex))
            leadingIndex = trailingIndex + 1
        }
        paintSegments.append(
            _PaintSegment(leadingIndex: leadingIndex, trailingIndex: indexOf(lastChild!)))

        // Paint, clipping for all but the first segment.
        let firstSegment = paintSegments.removeFirst()
        paintUpTo(firstSegment.trailingIndex, startWith: nextChild, context: context, offset: offset)

        // Paint the rest with clip layers.
        while !paintSegments.isEmpty {
            let segment = paintSegments.removeFirst()

            // Rect is calculated by the trailing edge of the parent (preceding
            // leadingIndex), and the trailing edge of the trailing index. We
            // cannot rely on the leading edge of the leading index, because it
            // is currently moving.
            let parentIndex = max(segment.leadingIndex - 1, 0)
            let leadingOffset =
                indexToLayoutOffset(0.0, parentIndex)
                + (parentIndex == 0
                    ? 0.0 : itemExtentBuilder!(parentIndex, _currentLayoutDimensions)!)
            let trailingOffset =
                indexToLayoutOffset(0.0, segment.trailingIndex)
                + itemExtentBuilder!(segment.trailingIndex, _currentLayoutDimensions)!
            let rect = Rect.fromPoints(
                Offset(0.0, leadingOffset),
                Offset(sliverConstraints.crossAxisExtent, trailingOffset)
            )
            // We use the same animation key to keep track of the clip layer,
            // unless this is the odd man out segment.
            let key = _animationLeadingIndices[parentIndex]!
            if _clipHandles[key] == nil {
                _clipHandles[key] = LayerHandle<ClipRectLayer>()
            }
            _clipHandles[key]!.layer = context.pushClipRect(
                needsCompositing,
                offset,
                rect,
                { (context: PaintingContext, offset: Offset) in
                    paintUpTo(
                        segment.trailingIndex, startWith: nextChild, context: context,
                        offset: offset)
                },
                oldLayer: _clipHandles[key]!.layer
            )
        }
    }
}
