// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Wrap layout model types: enums, helper structs, and parent data.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/wrap.dart`

import FlutterSwiftBridge

// MARK: - Typealiases

/// Callback to retrieve the next child in the child list.
///
/// **Dart Source:** wrap.dart:17
internal typealias NextChild = (RenderBox) -> RenderBox?

/// Callback to position a child at a given offset.
///
/// **Dart Source:** wrap.dart:18
internal typealias PositionChild = (RenderBox, Offset) -> Void

/// Callback to retrieve a child's size given box constraints.
///
/// **Dart Source:** wrap.dart:19
internal typealias GetChildSize = (RenderBox, BoxConstraints) -> Size

// MARK: - WrapAxisSize

/// A 2D vector that uses a `RenderWrap`'s main axis and cross axis as its
/// first and second coordinate axes.
///
/// It represents the same vector as `(mainAxisExtent, crossAxisExtent)`.
///
/// Dart name: `_AxisSize` (private extension type wrapping `Size`).
///
/// **Dart Source:** wrap.dart:22-56
internal struct WrapAxisSize: Equatable {
    /// The extent along the main axis.
    ///
    /// **Dart Source:** wrap.dart:37
    var mainAxisExtent: Double

    /// The extent along the cross axis.
    ///
    /// **Dart Source:** wrap.dart:38
    var crossAxisExtent: Double

    /// Creates a `WrapAxisSize` with the given main and cross axis extents.
    ///
    /// **Dart Source:** wrap.dart:23-24
    init(mainAxisExtent: Double, crossAxisExtent: Double) {
        self.mainAxisExtent = mainAxisExtent
        self.crossAxisExtent = crossAxisExtent
    }

    /// An empty axis size with both extents set to zero.
    ///
    /// **Dart Source:** wrap.dart:28
    static let empty = WrapAxisSize(mainAxisExtent: 0, crossAxisExtent: 0)

    /// Creates a `WrapAxisSize` from a `Size`, converting based on direction.
    ///
    /// For horizontal direction, width maps to main axis and height to cross.
    /// For vertical direction, the axes are swapped.
    ///
    /// **Dart Source:** wrap.dart:25-26
    init(from size: Size, direction: Axis) {
        let converted = WrapAxisSize._convert(size, direction)
        self.mainAxisExtent = converted.width
        self.crossAxisExtent = converted.height
    }

    /// Converts a `Size` by swapping width/height for vertical direction.
    ///
    /// **Dart Source:** wrap.dart:30-35
    private static func _convert(_ size: Size, _ direction: Axis) -> Size {
        switch direction {
        case .horizontal:
            return size
        case .vertical:
            return size.flipped
        }
    }

    /// Converts this axis size back to a `Size` for the given direction.
    ///
    /// **Dart Source:** wrap.dart:40
    func toSize(_ direction: Axis) -> Size {
        WrapAxisSize._convert(Size(mainAxisExtent, crossAxisExtent), direction)
    }

    /// Returns a new `WrapAxisSize` constrained by the given box constraints
    /// and direction.
    ///
    /// **Dart Source:** wrap.dart:42-48
    func applyConstraints(_ constraints: BoxConstraints, direction: Axis) -> WrapAxisSize {
        let effectiveConstraints: BoxConstraints
        switch direction {
        case .horizontal:
            effectiveConstraints = constraints
        case .vertical:
            effectiveConstraints = constraints.flipped
        }
        let constrained = effectiveConstraints.constrain(
            Size(mainAxisExtent, crossAxisExtent)
        )
        return WrapAxisSize(mainAxisExtent: constrained.width, crossAxisExtent: constrained.height)
    }

    /// Returns a new `WrapAxisSize` with the axes swapped.
    ///
    /// **Dart Source:** wrap.dart:50
    var flipped: WrapAxisSize {
        WrapAxisSize(mainAxisExtent: crossAxisExtent, crossAxisExtent: mainAxisExtent)
    }

    /// Adds two axis sizes: sums main axis extents and takes the max of cross
    /// axis extents.
    ///
    /// **Dart Source:** wrap.dart:51-53
    static func + (lhs: WrapAxisSize, rhs: WrapAxisSize) -> WrapAxisSize {
        WrapAxisSize(
            mainAxisExtent: lhs.mainAxisExtent + rhs.mainAxisExtent,
            crossAxisExtent: max(lhs.crossAxisExtent, rhs.crossAxisExtent)
        )
    }

    /// Subtracts one axis size from another (component-wise).
    ///
    /// **Dart Source:** wrap.dart:54-55
    static func - (lhs: WrapAxisSize, rhs: WrapAxisSize) -> WrapAxisSize {
        WrapAxisSize(
            mainAxisExtent: lhs.mainAxisExtent - rhs.mainAxisExtent,
            crossAxisExtent: lhs.crossAxisExtent - rhs.crossAxisExtent
        )
    }
}

// MARK: - WrapAlignment

/// How `Wrap` should align objects.
///
/// Used both to align children within a run in the main axis as well as to
/// align the runs themselves in the cross axis.
///
/// **Dart Source:** wrap.dart:62-127
public enum WrapAlignment: Sendable {
    /// Place the objects as close to the start of the axis as possible.
    ///
    /// If this value is used in a horizontal direction, a `TextDirection` must be
    /// available to determine if the start is the left or the right.
    ///
    /// If this value is used in a vertical direction, a `VerticalDirection` must be
    /// available to determine if the start is the top or the bottom.
    ///
    /// **Dart Source:** wrap.dart:70
    case start

    /// Place the objects as close to the end of the axis as possible.
    ///
    /// If this value is used in a horizontal direction, a `TextDirection` must be
    /// available to determine if the end is the left or the right.
    ///
    /// If this value is used in a vertical direction, a `VerticalDirection` must be
    /// available to determine if the end is the top or the bottom.
    ///
    /// **Dart Source:** wrap.dart:79
    case end

    /// Place the objects as close to the middle of the axis as possible.
    ///
    /// **Dart Source:** wrap.dart:82
    case center

    /// Place the free space evenly between the objects.
    ///
    /// **Dart Source:** wrap.dart:85
    case spaceBetween

    /// Place the free space evenly between the objects as well as half of that
    /// space before and after the first and last objects.
    ///
    /// **Dart Source:** wrap.dart:89
    case spaceAround

    /// Place the free space evenly between the objects as well as before and
    /// after the first and last objects.
    ///
    /// **Dart Source:** wrap.dart:93
    case spaceEvenly

    /// Distributes free space into leading space and between-item spacing.
    ///
    /// Returns a tuple of `(leadingSpace, betweenSpace)`.
    ///
    /// **Dart Source:** wrap.dart:95-126
    internal func distributeSpace(
        freeSpace: Double,
        itemSpacing: Double,
        itemCount: Int,
        flipped: Bool
    ) -> (leadingSpace: Double, betweenSpace: Double) {
        assert(itemCount > 0)
        switch self {
        case .start:
            return (flipped ? freeSpace : 0.0, itemSpacing)

        case .end:
            return WrapAlignment.start.distributeSpace(
                freeSpace: freeSpace,
                itemSpacing: itemSpacing,
                itemCount: itemCount,
                flipped: !flipped
            )

        case .center:
            return (freeSpace / 2.0, itemSpacing)

        case .spaceBetween:
            if itemCount < 2 {
                return WrapAlignment.start.distributeSpace(
                    freeSpace: freeSpace,
                    itemSpacing: itemSpacing,
                    itemCount: itemCount,
                    flipped: flipped
                )
            }
            return (0, freeSpace / Double(itemCount - 1) + itemSpacing)

        case .spaceAround:
            return (
                freeSpace / Double(itemCount) / 2,
                freeSpace / Double(itemCount) + itemSpacing
            )

        case .spaceEvenly:
            return (
                freeSpace / Double(itemCount + 1),
                freeSpace / Double(itemCount + 1) + itemSpacing
            )
        }
    }
}

// MARK: - WrapCrossAlignment

/// How `Wrap` should align children within a run in the cross axis.
///
/// **Dart Source:** wrap.dart:129-168
public enum WrapCrossAlignment: Sendable {
    /// Place the children as close to the start of the run in the cross axis as
    /// possible.
    ///
    /// If this value is used in a horizontal direction, a `TextDirection` must be
    /// available to determine if the start is the left or the right.
    ///
    /// If this value is used in a vertical direction, a `VerticalDirection` must be
    /// available to determine if the start is the top or the bottom.
    ///
    /// **Dart Source:** wrap.dart:139
    case start

    /// Place the children as close to the end of the run in the cross axis as
    /// possible.
    ///
    /// If this value is used in a horizontal direction, a `TextDirection` must be
    /// available to determine if the end is the left or the right.
    ///
    /// If this value is used in a vertical direction, a `VerticalDirection` must be
    /// available to determine if the end is the top or the bottom.
    ///
    /// **Dart Source:** wrap.dart:149
    case end

    /// Place the children as close to the middle of the run in the cross axis as
    /// possible.
    ///
    /// **Dart Source:** wrap.dart:153
    case center

    // TODO(ianh): baseline.

    /// Returns the flipped cross alignment (start <-> end, center stays).
    ///
    /// **Dart Source:** wrap.dart:157-161
    internal var flipped: WrapCrossAlignment {
        switch self {
        case .start: return .end
        case .end: return .start
        case .center: return .center
        }
    }

    /// Returns the alignment value as a fraction (0 for start, 0.5 for center,
    /// 1 for end).
    ///
    /// **Dart Source:** wrap.dart:163-167
    internal var alignment: Double {
        switch self {
        case .start: return 0
        case .end: return 1
        case .center: return 0.5
        }
    }
}

// MARK: - WrapRunMetrics

/// Metrics for a single run in a `RenderWrap` layout.
///
/// Dart name: `_RunMetrics` (private class).
///
/// **Dart Source:** wrap.dart:170-199
internal struct WrapRunMetrics {
    /// The combined axis size of all children in this run.
    ///
    /// **Dart Source:** wrap.dart:173
    var axisSize: WrapAxisSize

    /// The number of children in this run.
    ///
    /// **Dart Source:** wrap.dart:174
    var childCount: Int

    /// The leading child in this run.
    ///
    /// **Dart Source:** wrap.dart:175
    var leadingChild: RenderBox

    /// Creates run metrics for a run starting with the given child and axis size.
    ///
    /// **Dart Source:** wrap.dart:171
    init(leadingChild: RenderBox, axisSize: WrapAxisSize) {
        self.leadingChild = leadingChild
        self.axisSize = axisSize
        self.childCount = 1
    }

    /// The extent of this run along the main axis.
    ///
    /// **Dart Source:** wrap.dart:173 (via axisSize.mainAxisExtent)
    var mainAxisExtent: Double {
        axisSize.mainAxisExtent
    }

    /// The extent of this run along the cross axis.
    ///
    /// **Dart Source:** wrap.dart:173 (via axisSize.crossAxisExtent)
    var crossAxisExtent: Double {
        axisSize.crossAxisExtent
    }

    /// Attempts to add a new child to this run.
    ///
    /// If incorporating the child would exceed `maxMainExtent`, returns a new
    /// `WrapRunMetrics` for a fresh run. Otherwise, updates this run's metrics
    /// in place and returns `nil`.
    ///
    /// **Dart Source:** wrap.dart:178-198
    mutating func tryAddingNewChild(
        _ child: RenderBox,
        childSize: WrapAxisSize,
        flipMainAxis: Bool,
        spacing: Double,
        maxMainExtent: Double
    ) -> WrapRunMetrics? {
        let needsNewRun =
            axisSize.mainAxisExtent + childSize.mainAxisExtent + spacing - maxMainExtent
            > precisionErrorTolerance
        if needsNewRun {
            return WrapRunMetrics(leadingChild: child, axisSize: childSize)
        } else {
            axisSize =
                axisSize
                + childSize
                + WrapAxisSize(mainAxisExtent: spacing, crossAxisExtent: 0.0)
            childCount += 1
            if flipMainAxis {
                leadingChild = child
            }
            return nil
        }
    }
}

// MARK: - WrapParentData

/// Parent data for use with `RenderWrap`.
///
/// **Dart Source:** wrap.dart:202
public class WrapParentData: ContainerBoxParentData<RenderBox> {}

// MARK: - RenderWrap

/// Displays its children in multiple horizontal or vertical runs.
///
/// A `RenderWrap` lays out each child and attempts to place the child adjacent
/// to the previous child in the main axis, given by `direction`, leaving
/// `spacing` logical pixels between each child. If there is not enough room to
/// fit the child, `RenderWrap` creates a new run adjacent in the cross axis to
/// the existing children, leaving `runSpacing` logical pixels between each run.
///
/// After all the children have been allocated to runs, the children within the
/// runs are positioned according to the `alignment` in the main axis and
/// according to the `crossAxisAlignment` in the cross axis. The runs
/// themselves are then positioned in the cross axis according to the
/// `runAlignment`.
///
/// In Dart this class extends `RenderBox` and mixes in
/// `ContainerRenderObjectMixin<RenderBox, WrapParentData>` and
/// `RenderBoxContainerDefaultsMixin<RenderBox, WrapParentData>`.
///
/// Since Swift does not support generic mixins, the container management
/// (linked-list child pointers) is implemented inline, and the class
/// conforms to `RenderBoxContainerDefaults` for default paint and
/// hit-testing behavior.
///
/// **Dart Source:** wrap.dart:218-878
public class RenderWrap: RenderBox, RenderBoxContainerDefaults {
    public typealias ChildType = RenderBox

    // MARK: - Container child management (ContainerRenderObjectMixin)

    /// The first child in the child list.
    ///
    /// **Dart Source:** object.dart:4222 (ContainerRenderObjectMixin)
    public private(set) var firstChild: RenderBox?

    /// The last child in the child list.
    ///
    /// **Dart Source:** object.dart:4223 (ContainerRenderObjectMixin)
    public private(set) var lastChild: RenderBox?

    /// The number of children.
    ///
    /// **Dart Source:** object.dart:4226 (ContainerRenderObjectMixin)
    public private(set) var childCount: Int = 0

    /// Returns the next sibling of the given child.
    ///
    /// **Dart Source:** object.dart:4393 (ContainerRenderObjectMixin)
    public func childAfter(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! WrapParentData
        return parentData.nextSibling
    }

    /// Returns the previous sibling of the given child.
    ///
    /// **Dart Source:** object.dart:4399 (ContainerRenderObjectMixin)
    public func childBefore(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! WrapParentData
        return parentData.previousSibling
    }

    /// Inserts a child into the linked list.
    ///
    /// **Dart Source:** object.dart:4234-4268 (ContainerRenderObjectMixin._insertIntoChildList)
    private func _insertIntoChildList(_ child: RenderBox, after: RenderBox? = nil) {
        let childParentData = child.parentData as! WrapParentData
        childCount += 1
        assert(childCount > 0)
        if let after = after {
            let afterParentData = after.parentData as! WrapParentData
            if afterParentData.nextSibling == nil {
                // Inserting at the end — update lastChild
                childParentData.previousSibling = after
                afterParentData.nextSibling = child
                lastChild = child
            } else {
                // Inserting in the middle
                childParentData.nextSibling = afterParentData.nextSibling
                childParentData.previousSibling = after
                let nextParentData = afterParentData.nextSibling!.parentData as! WrapParentData
                nextParentData.previousSibling = child
                afterParentData.nextSibling = child
            }
        } else {
            childParentData.nextSibling = firstChild
            if let first = firstChild {
                let firstParentData = first.parentData as! WrapParentData
                firstParentData.previousSibling = child
            }
            firstChild = child
            lastChild = lastChild ?? child
        }
    }

    /// Removes a child from the linked list.
    ///
    /// **Dart Source:** object.dart:4271-4295 (ContainerRenderObjectMixin._removeFromChildList)
    private func _removeFromChildList(_ child: RenderBox) {
        let childParentData = child.parentData as! WrapParentData
        if childParentData.previousSibling == nil {
            // child is firstChild
            firstChild = childParentData.nextSibling
        } else {
            let previousParentData =
                childParentData.previousSibling!.parentData as! WrapParentData
            previousParentData.nextSibling = childParentData.nextSibling
        }
        if childParentData.nextSibling == nil {
            // child is lastChild
            lastChild = childParentData.previousSibling
        } else {
            let nextParentData =
                childParentData.nextSibling!.parentData as! WrapParentData
            nextParentData.previousSibling = childParentData.previousSibling
        }
        childParentData.previousSibling = nil
        childParentData.nextSibling = nil
        childCount -= 1
    }

    /// Adds a child to the child list, optionally after the given child.
    ///
    /// **Dart Source:** object.dart:4310-4323 (ContainerRenderObjectMixin.insert)
    public func insert(_ child: RenderBox, after: RenderBox? = nil) {
        adoptChild(child)
        _insertIntoChildList(child, after: after)
    }

    /// Appends all the given children to the end of the child list.
    ///
    /// **Dart Source:** object.dart:4325-4341 (ContainerRenderObjectMixin.addAll)
    public func addAll(_ children: [RenderBox]?) {
        children?.forEach { insert($0, after: lastChild) }
    }

    /// Removes a child from the child list.
    ///
    /// **Dart Source:** object.dart:4343-4353 (ContainerRenderObjectMixin.remove)
    public func remove(_ child: RenderBox) {
        _removeFromChildList(child)
        dropChild(child)
    }

    // MARK: - Constructor

    /// Creates a wrap render object.
    ///
    /// By default, the wrap layout is horizontal and both the children and the
    /// runs are aligned to the start.
    ///
    /// **Dart Source:** wrap.dart:226-247
    public init(
        children: [RenderBox]? = nil,
        direction: Axis = .horizontal,
        alignment: WrapAlignment = .start,
        spacing: Double = 0.0,
        runAlignment: WrapAlignment = .start,
        runSpacing: Double = 0.0,
        crossAxisAlignment: WrapCrossAlignment = .start,
        textDirection: TextDirection? = nil,
        verticalDirection: VerticalDirection = .down,
        clipBehavior: Clip = .none
    ) {
        self._direction = direction
        self._alignment = alignment
        self._spacing = spacing
        self._runAlignment = runAlignment
        self._runSpacing = runSpacing
        self._crossAxisAlignment = crossAxisAlignment
        self._textDirection = textDirection
        self._verticalDirection = verticalDirection
        self._clipBehavior = clipBehavior
        super.init()
        addAll(children)
    }

    // MARK: - Properties

    /// The direction to use as the main axis.
    ///
    /// For example, if `direction` is `Axis.horizontal`, the default, the
    /// children are placed adjacent to one another in a horizontal run until the
    /// available horizontal space is consumed, at which point subsequent
    /// children are placed in a new run vertically adjacent to the previous run.
    ///
    /// **Dart Source:** wrap.dart:255-263
    public var direction: Axis {
        get { _direction }
        set {
            if _direction == newValue {
                return
            }
            _direction = newValue
            markNeedsLayout()
        }
    }
    private var _direction: Axis

    /// How the children within a run should be placed in the main axis.
    ///
    /// For example, if `alignment` is `WrapAlignment.center`, the children in
    /// each run are grouped together in the center of their run in the main axis.
    ///
    /// Defaults to `WrapAlignment.start`.
    ///
    /// **Dart Source:** wrap.dart:278-286
    public var alignment: WrapAlignment {
        get { _alignment }
        set {
            if _alignment == newValue {
                return
            }
            _alignment = newValue
            markNeedsLayout()
        }
    }
    private var _alignment: WrapAlignment

    /// How much space to place between children in a run in the main axis.
    ///
    /// For example, if `spacing` is 10.0, the children will be spaced at least
    /// 10.0 logical pixels apart in the main axis.
    ///
    /// Defaults to 0.0.
    ///
    /// **Dart Source:** wrap.dart:299-307
    public var spacing: Double {
        get { _spacing }
        set {
            if _spacing == newValue {
                return
            }
            _spacing = newValue
            markNeedsLayout()
        }
    }
    private var _spacing: Double

    /// How the runs themselves should be placed in the cross axis.
    ///
    /// For example, if `runAlignment` is `WrapAlignment.center`, the runs are
    /// grouped together in the center of the overall `RenderWrap` in the cross
    /// axis.
    ///
    /// Defaults to `WrapAlignment.start`.
    ///
    /// **Dart Source:** wrap.dart:323-331
    public var runAlignment: WrapAlignment {
        get { _runAlignment }
        set {
            if _runAlignment == newValue {
                return
            }
            _runAlignment = newValue
            markNeedsLayout()
        }
    }
    private var _runAlignment: WrapAlignment

    /// How much space to place between the runs themselves in the cross axis.
    ///
    /// For example, if `runSpacing` is 10.0, the runs will be spaced at least
    /// 10.0 logical pixels apart in the cross axis.
    ///
    /// Defaults to 0.0.
    ///
    /// **Dart Source:** wrap.dart:343-351
    public var runSpacing: Double {
        get { _runSpacing }
        set {
            if _runSpacing == newValue {
                return
            }
            _runSpacing = newValue
            markNeedsLayout()
        }
    }
    private var _runSpacing: Double

    /// How the children within a run should be aligned relative to each other in
    /// the cross axis.
    ///
    /// For example, if this is set to `WrapCrossAlignment.end`, and the
    /// `direction` is `Axis.horizontal`, then the children within each
    /// run will have their bottom edges aligned to the bottom edge of the run.
    ///
    /// Defaults to `WrapCrossAlignment.start`.
    ///
    /// **Dart Source:** wrap.dart:368-376
    public var crossAxisAlignment: WrapCrossAlignment {
        get { _crossAxisAlignment }
        set {
            if _crossAxisAlignment == newValue {
                return
            }
            _crossAxisAlignment = newValue
            markNeedsLayout()
        }
    }
    private var _crossAxisAlignment: WrapCrossAlignment

    /// Determines the order to lay children out horizontally and how to interpret
    /// `start` and `end` in the horizontal direction.
    ///
    /// **Dart Source:** wrap.dart:401-408
    public var textDirection: TextDirection? {
        get { _textDirection }
        set {
            if _textDirection != newValue {
                _textDirection = newValue
                markNeedsLayout()
            }
        }
    }
    private var _textDirection: TextDirection?

    /// Determines the order to lay children out vertically and how to interpret
    /// `start` and `end` in the vertical direction.
    ///
    /// **Dart Source:** wrap.dart:432-439
    public var verticalDirection: VerticalDirection {
        get { _verticalDirection }
        set {
            if _verticalDirection != newValue {
                _verticalDirection = newValue
                markNeedsLayout()
            }
        }
    }
    private var _verticalDirection: VerticalDirection

    /// Controls how to clip.
    ///
    /// Defaults to `Clip.none`.
    ///
    /// **Dart Source:** wrap.dart:444-452
    public var clipBehavior: Clip {
        get { _clipBehavior }
        set {
            if newValue != _clipBehavior {
                _clipBehavior = newValue
                markNeedsPaint()
                // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
            }
        }
    }
    private var _clipBehavior: Clip

    // MARK: - setupParentData

    /// Ensures the child has `WrapParentData`.
    ///
    /// **Dart Source:** wrap.dart:504-509
    public override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is WrapParentData) {
            child.parentData = WrapParentData()
        }
    }

    // MARK: - Helper Methods

    /// Returns the main axis extent of the given child size.
    ///
    /// For horizontal direction, returns the width; for vertical, the height.
    ///
    /// **Dart Source:** wrap.dart:580-585
    internal func _getMainAxisExtent(_ childSize: Size) -> Double {
        switch direction {
        case .horizontal:
            return childSize.width
        case .vertical:
            return childSize.height
        }
    }

    /// Returns the cross axis extent of the given child size.
    ///
    /// For horizontal direction, returns the height; for vertical, the width.
    ///
    /// **Dart Source:** wrap.dart:587-592
    internal func _getCrossAxisExtent(_ childSize: Size) -> Double {
        switch direction {
        case .horizontal:
            return childSize.height
        case .vertical:
            return childSize.width
        }
    }

    /// Creates an `Offset` from main and cross axis offsets, respecting direction.
    ///
    /// For horizontal direction, main maps to dx and cross to dy.
    /// For vertical direction, cross maps to dx and main to dy.
    ///
    /// **Dart Source:** wrap.dart:594-599
    internal func _getOffset(_ mainAxisOffset: Double, _ crossAxisOffset: Double) -> Offset {
        switch direction {
        case .horizontal:
            return Offset(mainAxisOffset, crossAxisOffset)
        case .vertical:
            return Offset(crossAxisOffset, mainAxisOffset)
        }
    }

    /// Returns whether the main and cross axes should be flipped.
    ///
    /// The first element indicates whether the main axis is flipped,
    /// the second whether the cross axis is flipped.
    ///
    /// **Dart Source:** wrap.dart:601-614
    internal var _areAxesFlipped: (flipMainAxis: Bool, flipCrossAxis: Bool) {
        let flipHorizontal: Bool
        switch textDirection ?? .ltr {
        case .ltr:
            flipHorizontal = false
        case .rtl:
            flipHorizontal = true
        }
        let flipVertical: Bool
        switch verticalDirection {
        case .down:
            flipVertical = false
        case .up:
            flipVertical = true
        }
        switch direction {
        case .horizontal:
            return (flipHorizontal, flipVertical)
        case .vertical:
            return (flipVertical, flipHorizontal)
        }
    }

    // MARK: - Intrinsic Dimensions

    /// Computes the minimum intrinsic width.
    ///
    /// For horizontal: the maximum of all children's minimum intrinsic widths.
    /// For vertical: the width from a dry layout with the given height constraint.
    ///
    /// **Dart Source:** wrap.dart:512-525
    public override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        switch direction {
        case .horizontal:
            var width = 0.0
            var child = firstChild
            while let currentChild = child {
                width = max(width, currentChild.getMinIntrinsicWidth(.infinity))
                child = childAfter(currentChild)
            }
            return width
        case .vertical:
            return getDryLayout(BoxConstraints(maxHeight: height)).width
        }
    }

    /// Computes the maximum intrinsic width.
    ///
    /// For horizontal: the sum of all children's maximum intrinsic widths.
    /// For vertical: the width from a dry layout with the given height constraint.
    ///
    /// **Dart Source:** wrap.dart:528-541
    public override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        switch direction {
        case .horizontal:
            var width = 0.0
            var child = firstChild
            while let currentChild = child {
                width += currentChild.getMaxIntrinsicWidth(.infinity)
                child = childAfter(currentChild)
            }
            return width
        case .vertical:
            return getDryLayout(BoxConstraints(maxHeight: height)).width
        }
    }

    /// Computes the minimum intrinsic height.
    ///
    /// For horizontal: the height from a dry layout with the given width constraint.
    /// For vertical: the maximum of all children's minimum intrinsic heights.
    ///
    /// **Dart Source:** wrap.dart:544-557
    public override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        switch direction {
        case .horizontal:
            return getDryLayout(BoxConstraints(maxWidth: width)).height
        case .vertical:
            var height = 0.0
            var child = firstChild
            while let currentChild = child {
                height = max(height, currentChild.getMinIntrinsicHeight(.infinity))
                child = childAfter(currentChild)
            }
            return height
        }
    }

    /// Computes the maximum intrinsic height.
    ///
    /// For horizontal: the height from a dry layout with the given width constraint.
    /// For vertical: the sum of all children's maximum intrinsic heights.
    ///
    /// **Dart Source:** wrap.dart:560-573
    public override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        switch direction {
        case .horizontal:
            return getDryLayout(BoxConstraints(maxWidth: width)).height
        case .vertical:
            var height = 0.0
            var child = firstChild
            while let currentChild = child {
                height += currentChild.getMaxIntrinsicHeight(.infinity)
                child = childAfter(currentChild)
            }
            return height
        }
    }

    // MARK: - Baseline

    /// Returns the distance to the actual baseline using the highest baseline
    /// among all children.
    ///
    /// **Dart Source:** wrap.dart:576-578
    public override func computeDistanceToActualBaseline(_ baseline: TextBaseline) -> Double? {
        return defaultComputeDistanceToHighestActualBaseline(baseline)
    }

    // MARK: - Layout

    /// Whether the wrap has visual overflow.
    ///
    /// Set during `performLayout` when children exceed the container size.
    ///
    /// **Dart Source:** wrap.dart:842
    private var _hasVisualOverflow: Bool = false

    /// A handle to the `ClipRectLayer` used for clip management during paint.
    ///
    /// **Dart Source:** wrap.dart:869
    private let _clipRectLayer: LayerHandle<ClipRectLayer> = LayerHandle<ClipRectLayer>()

    /// Computes the dry layout size for the given constraints using the
    /// specified child layouter.
    ///
    /// Iterates all children, groups them into runs based on available main
    /// axis space, and returns the constrained overall size.
    ///
    /// **Dart Source:** wrap.dart:650-690
    private func _computeDryLayout(
        _ constraints: BoxConstraints,
        layoutChild: ChildLayouter = ChildLayoutHelper.dryLayoutChild
    ) -> Size {
        let childConstraints: BoxConstraints
        let mainAxisLimit: Double
        switch direction {
        case .horizontal:
            childConstraints = BoxConstraints(maxWidth: constraints.maxWidth)
            mainAxisLimit = constraints.maxWidth
        case .vertical:
            childConstraints = BoxConstraints(maxHeight: constraints.maxHeight)
            mainAxisLimit = constraints.maxHeight
        }

        var mainAxisExtent = 0.0
        var crossAxisExtent = 0.0
        var runMainAxisExtent = 0.0
        var runCrossAxisExtent = 0.0
        var childCountInRun = 0
        var child = firstChild
        while let currentChild = child {
            let childSize = layoutChild(currentChild, childConstraints)
            let childMainAxisExtent = _getMainAxisExtent(childSize)
            let childCrossAxisExtent = _getCrossAxisExtent(childSize)
            if childCountInRun > 0
                && runMainAxisExtent + childMainAxisExtent + spacing > mainAxisLimit
            {
                mainAxisExtent = max(mainAxisExtent, runMainAxisExtent)
                crossAxisExtent += runCrossAxisExtent + runSpacing
                runMainAxisExtent = 0.0
                runCrossAxisExtent = 0.0
                childCountInRun = 0
            }
            runMainAxisExtent += childMainAxisExtent
            runCrossAxisExtent = max(runCrossAxisExtent, childCrossAxisExtent)
            if childCountInRun > 0 {
                runMainAxisExtent += spacing
            }
            childCountInRun += 1
            child = childAfter(currentChild)
        }
        crossAxisExtent += runCrossAxisExtent
        mainAxisExtent = max(mainAxisExtent, runMainAxisExtent)
        switch direction {
        case .horizontal:
            return constraints.constrain(Size(mainAxisExtent, crossAxisExtent))
        case .vertical:
            return constraints.constrain(Size(crossAxisExtent, mainAxisExtent))
        }
    }

    /// Computes the runs for layout.
    ///
    /// Iterates all children, lays them out with the given constraints and
    /// layouter, and groups them into `WrapRunMetrics` runs based on the
    /// available main axis space.
    ///
    /// Returns a tuple of the overall children axis size and an array of run
    /// metrics.
    ///
    /// **Dart Source:** wrap.dart:692-727
    private func _computeRuns(
        _ constraints: BoxConstraints,
        layoutChild: ChildLayouter
    ) -> (childrenSize: WrapAxisSize, runMetrics: [WrapRunMetrics]) {
        assert(firstChild != nil)
        let childConstraints: BoxConstraints
        let mainAxisLimit: Double
        switch direction {
        case .horizontal:
            childConstraints = BoxConstraints(maxWidth: constraints.maxWidth)
            mainAxisLimit = constraints.maxWidth
        case .vertical:
            childConstraints = BoxConstraints(maxHeight: constraints.maxHeight)
            mainAxisLimit = constraints.maxHeight
        }

        let (flipMainAxis, _) = _areAxesFlipped
        let spacing = self.spacing
        var runMetrics: [WrapRunMetrics] = []

        var currentRun: WrapRunMetrics? = nil
        var childrenAxisSize = WrapAxisSize.empty
        var child = firstChild
        while let currentChild = child {
            let childSize = WrapAxisSize(
                from: layoutChild(currentChild, childConstraints),
                direction: direction
            )
            if currentRun == nil {
                let newRun = WrapRunMetrics(leadingChild: currentChild, axisSize: childSize)
                runMetrics.append(newRun)
                childrenAxisSize = childrenAxisSize + (WrapAxisSize.empty)
                currentRun = newRun
            } else {
                let newRun = currentRun!.tryAddingNewChild(
                    currentChild,
                    childSize: childSize,
                    flipMainAxis: flipMainAxis,
                    spacing: spacing,
                    maxMainExtent: mainAxisLimit
                )
                if let newRun = newRun {
                    runMetrics.append(newRun)
                    childrenAxisSize = childrenAxisSize + currentRun!.axisSize.flipped
                    currentRun = newRun
                } else {
                    // Sync mutated metrics back to the array (currentRun is a value type)
                    runMetrics[runMetrics.count - 1] = currentRun!
                }
            }
            child = childAfter(currentChild)
        }
        assert(!runMetrics.isEmpty)
        let totalRunSpacing = runSpacing * Double(runMetrics.count - 1)
        childrenAxisSize = childrenAxisSize
            + WrapAxisSize(mainAxisExtent: totalRunSpacing, crossAxisExtent: 0.0)
            + currentRun!.axisSize.flipped
        return (childrenAxisSize.flipped, runMetrics)
    }

    /// Computes the dry layout for the given constraints.
    ///
    /// **Dart Source:** wrap.dart:647-649
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return _computeDryLayout(constraints)
    }

    /// Performs the actual layout of all children.
    ///
    /// Groups children into runs, computes the container size, determines
    /// visual overflow, and positions children within their runs.
    ///
    /// **Dart Source:** wrap.dart:729-741
    public override func performLayout() {
        let constraints = boxConstraints
        if firstChild == nil {
            size = constraints.smallest
            _hasVisualOverflow = false
            return
        }
        let (childrenAxisSize, runMetrics) = _computeRuns(
            constraints,
            layoutChild: ChildLayoutHelper.layoutChild
        )
        let containerAxisSize = childrenAxisSize.applyConstraints(constraints, direction: direction)
        size = containerAxisSize.toSize(direction)
        let freeAxisSize = containerAxisSize - childrenAxisSize
        _hasVisualOverflow =
            freeAxisSize.mainAxisExtent < 0.0 || freeAxisSize.crossAxisExtent < 0.0
        _positionChildren(
            runMetrics,
            freeAxisSize: freeAxisSize,
            containerAxisSize: containerAxisSize
        )
    }

    /// Returns the size of the given child.
    ///
    /// **Dart Source:** wrap.dart:743
    private static func _getChildSize(_ child: RenderBox) -> Size {
        return child.size
    }

    /// Sets the position (offset) of the given child.
    ///
    /// **Dart Source:** wrap.dart:744-746
    private static func _setChildPosition(_ child: RenderBox, _ offset: Offset) {
        (child.parentData! as! WrapParentData).offset = offset
    }

    /// Positions all children within their runs.
    ///
    /// Uses the alignment and cross alignment settings to distribute free space
    /// both within each run (main axis) and between runs (cross axis).
    ///
    /// **Dart Source:** wrap.dart:748-793
    private func _positionChildren(
        _ runMetrics: [WrapRunMetrics],
        freeAxisSize: WrapAxisSize,
        containerAxisSize: WrapAxisSize
    ) {
        assert(!runMetrics.isEmpty)
        let spacing = self.spacing
        let crossAxisFreeSpace = max(0.0, freeAxisSize.crossAxisExtent)
        let (flipMainAxis, flipCrossAxis) = _areAxesFlipped
        let effectiveCrossAlignment = flipCrossAxis
            ? crossAxisAlignment.flipped
            : crossAxisAlignment
        let (runLeadingSpace, runBetweenSpace) = runAlignment.distributeSpace(
            freeSpace: crossAxisFreeSpace,
            itemSpacing: runSpacing,
            itemCount: runMetrics.count,
            flipped: flipCrossAxis
        )
        let nextChild: NextChild = flipMainAxis ? childBefore : childAfter

        var runCrossAxisOffset = runLeadingSpace
        let runs: [WrapRunMetrics] = flipCrossAxis ? runMetrics.reversed() : runMetrics
        for run in runs {
            let runCrossAxisExtent = run.crossAxisExtent
            let childCountInRun = run.childCount
            let mainAxisFreeSpace = max(
                0.0, containerAxisSize.mainAxisExtent - run.mainAxisExtent
            )
            let (childLeadingSpace, childBetweenSpace) = alignment.distributeSpace(
                freeSpace: mainAxisFreeSpace,
                itemSpacing: spacing,
                itemCount: childCountInRun,
                flipped: flipMainAxis
            )
            var childMainAxisOffset = childLeadingSpace
            var remainingChildCount = run.childCount
            var child: RenderBox? = run.leadingChild
            while let currentChild = child, remainingChildCount > 0 {
                let childSize = WrapAxisSize(
                    from: RenderWrap._getChildSize(currentChild),
                    direction: direction
                )
                let childCrossAxisOffset =
                    effectiveCrossAlignment.alignment
                    * (runCrossAxisExtent - childSize.crossAxisExtent)
                RenderWrap._setChildPosition(
                    currentChild,
                    _getOffset(childMainAxisOffset, runCrossAxisOffset + childCrossAxisOffset)
                )
                childMainAxisOffset += childSize.mainAxisExtent + childBetweenSpace
                child = nextChild(currentChild)
                remainingChildCount -= 1
            }
            runCrossAxisOffset += runCrossAxisExtent + runBetweenSpace
        }
    }

    // MARK: - Hit Testing

    /// Hit-tests children using the default child hit-testing logic.
    ///
    /// **Dart Source:** wrap.dart:842-844
    public override func hitTestChildren(_ result: BoxHitTestResult, position: Offset) -> Bool {
        return defaultHitTestChildren(result, position: position)
    }

    // MARK: - Paint

    /// Paints this render object and its children, clipping if there is
    /// visual overflow.
    ///
    /// **Dart Source:** wrap.dart:847-863
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        if _hasVisualOverflow && clipBehavior != .none {
            _clipRectLayer.layer = context.pushClipRect(
                needsCompositing,
                offset,
                Offset.zero & size,
                { context, offset in self.defaultPaint(context, offset) },
                clipBehavior: clipBehavior,
                oldLayer: _clipRectLayer.layer
            )
        } else {
            _clipRectLayer.layer = nil
            defaultPaint(context, offset)
        }
    }

    // MARK: - Dispose

    /// Releases resources held by this render object.
    ///
    /// Clears the `_clipRectLayer` handle and calls super's dispose.
    ///
    /// **Dart Source:** wrap.dart:868-871
    public override func dispose() {
        _clipRectLayer.layer = nil
        super.dispose()
    }
}

// MARK: - ContainerRenderObjectHost Conformance

extension RenderWrap: ContainerRenderObjectHost {
    public func move(_ child: RenderBox, after: RenderBox?) {
        remove(child)
        insert(child, after: after)
    }
}
