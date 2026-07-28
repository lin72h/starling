// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// List body layout — core structure and parent data.
///
/// Displays children sequentially along a given axis, forcing them to the
/// dimensions of the parent in the other axis.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/list_body.dart`

import FlutterSwiftBridge

// MARK: - ListBodyParentData

/// Parent data for use with `RenderListBody`.
///
/// This class extends `ContainerBoxParentData<RenderBox>` and adds no
/// extra fields — it exists solely so that `setupParentData` can identify
/// children that have already been set up.
///
/// **Dart Source:** list_body.dart:13
public class ListBodyParentData: ContainerBoxParentData<RenderBox> {}

// MARK: - ChildSizingFunction

/// Function that returns a sizing metric for a given child.
///
/// Used internally by `RenderListBody` to compute intrinsic dimensions
/// along the main and cross axes.
///
/// **Dart Source:** list_body.dart:15
internal typealias ChildSizingFunction = (RenderBox) -> Double

// MARK: - RenderListBody

/// Displays its children sequentially along a given axis, forcing them to the
/// dimensions of the parent in the other axis.
///
/// This layout algorithm arranges its children linearly along the main axis
/// (either horizontally or vertically). In the cross axis, children are
/// stretched to match the box's cross-axis extent. In the main axis, children
/// are given unlimited space and the box expands its main axis to contain all
/// its children. Because `RenderListBody` boxes expand in the main axis, they
/// must be given unlimited space in the main axis, typically by being contained
/// in a viewport with a scrolling direction that matches the box's main axis.
///
/// In Dart this class extends `RenderBox` and mixes in
/// `ContainerRenderObjectMixin<RenderBox, ListBodyParentData>` and
/// `RenderBoxContainerDefaultsMixin<RenderBox, ListBodyParentData>`.
///
/// Since Swift does not support generic mixins, the container management
/// (linked-list child pointers) is implemented inline, and the class
/// conforms to `RenderBoxContainerDefaults` for default paint and
/// hit-testing behavior.
///
/// **Dart Source:** list_body.dart:27-63
public class RenderListBody: RenderBox, RenderBoxContainerDefaults {
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
        let parentData = child.parentData as! ListBodyParentData
        return parentData.nextSibling
    }

    /// Returns the previous sibling of the given child.
    ///
    /// **Dart Source:** object.dart:4399 (ContainerRenderObjectMixin)
    public func childBefore(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! ListBodyParentData
        return parentData.previousSibling
    }

    /// Inserts a child into the linked list.
    ///
    /// **Dart Source:** object.dart:4234-4268 (ContainerRenderObjectMixin._insertIntoChildList)
    private func _insertIntoChildList(_ child: RenderBox, after: RenderBox? = nil) {
        let childParentData = child.parentData as! ListBodyParentData
        childCount += 1
        assert(childCount > 0)
        if let after = after {
            let afterParentData = after.parentData as! ListBodyParentData
            if afterParentData.nextSibling == nil {
                // Inserting at the end — update lastChild
                childParentData.previousSibling = after
                afterParentData.nextSibling = child
                lastChild = child
            } else {
                // Inserting in the middle
                childParentData.nextSibling = afterParentData.nextSibling
                childParentData.previousSibling = after
                let nextParentData = afterParentData.nextSibling!.parentData as! ListBodyParentData
                nextParentData.previousSibling = child
                afterParentData.nextSibling = child
            }
        } else {
            childParentData.nextSibling = firstChild
            if let first = firstChild {
                let firstParentData = first.parentData as! ListBodyParentData
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
        let childParentData = child.parentData as! ListBodyParentData
        if childParentData.previousSibling == nil {
            // child is firstChild
            firstChild = childParentData.nextSibling
        } else {
            let previousParentData =
                childParentData.previousSibling!.parentData as! ListBodyParentData
            previousParentData.nextSibling = childParentData.nextSibling
        }
        if childParentData.nextSibling == nil {
            // child is lastChild
            lastChild = childParentData.previousSibling
        } else {
            let nextParentData =
                childParentData.nextSibling!.parentData as! ListBodyParentData
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

    // MARK: - Initializer

    /// Creates a render object that arranges its children sequentially along a
    /// given axis.
    ///
    /// By default, children are arranged along the vertical axis.
    ///
    /// **Dart Source:** list_body.dart:35-38
    public init(children: [RenderBox]? = nil, axisDirection: AxisDirection = .down) {
        self._axisDirection = axisDirection
        super.init()
        addAll(children)
    }

    // MARK: - setupParentData

    /// Ensures the child has `ListBodyParentData`.
    ///
    /// If the child's `parentData` is not already a `ListBodyParentData`,
    /// replaces it.
    ///
    /// **Dart Source:** list_body.dart:41-45
    public override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is ListBodyParentData) {
            child.parentData = ListBodyParentData()
        }
    }

    // MARK: - axisDirection

    /// The direction in which the children are laid out.
    ///
    /// For example, if the `axisDirection` is `AxisDirection.down`, each child
    /// will be laid out below the next, vertically.
    ///
    /// **Dart Source:** list_body.dart:47-59
    public var axisDirection: AxisDirection {
        get { _axisDirection }
        set {
            if _axisDirection == newValue {
                return
            }
            _axisDirection = newValue
            markNeedsLayout()
        }
    }

    /// Backing storage for `axisDirection`.
    ///
    /// **Dart Source:** list_body.dart:52
    private var _axisDirection: AxisDirection

    // MARK: - mainAxis

    /// The axis (horizontal or vertical) corresponding to the current
    /// `axisDirection`.
    ///
    /// **Dart Source:** list_body.dart:61-63
    public var mainAxis: Axis {
        axisDirectionToAxis(axisDirection)
    }

    // MARK: - Debug Check Constraints

    /// Debug assertion that checks the main axis is unbounded and the cross
    /// axis is bounded.
    ///
    /// In release builds this is a no-op.  In debug builds it throws a
    /// `FlutterError` when the constraints violate the requirements.
    ///
    /// **Dart Source:** list_body.dart:134-192
    private func _debugCheckConstraints(_ constraints: BoxConstraints) -> Bool {
        assert({
            switch mainAxis {
            case .horizontal:
                if !constraints.hasBoundedWidth {
                    return true
                }
            case .vertical:
                if !constraints.hasBoundedHeight {
                    return true
                }
            }
            let error = FlutterError(
                "RenderListBody must have unlimited space along its main axis.\n"
                + "RenderListBody does not clip or resize its children, so it must be "
                + "placed in a parent that does not constrain the main axis.\n"
                + "You probably want to put the RenderListBody inside a "
                + "RenderViewport with a matching main axis."
            )
            fatalError("\(error)")
        }())
        assert({
            switch mainAxis {
            case .horizontal:
                if constraints.hasBoundedHeight {
                    return true
                }
            case .vertical:
                if constraints.hasBoundedWidth {
                    return true
                }
            }
            let error = FlutterError(
                "RenderListBody must have a bounded constraint for its cross axis.\n"
                + "RenderListBody forces its children to expand to fit the RenderListBody's container, "
                + "so it must be placed in a parent that constrains the cross axis to a finite dimension.\n"
                + "If you are attempting to nest a RenderListBody with "
                + "one direction inside one of another direction, you will want to "
                + "wrap the inner one inside a box that fixes the dimension in that direction, "
                + "for example, a RenderIntrinsicWidth or RenderIntrinsicHeight object. "
                + "This is relatively expensive, however."
            )
            fatalError("\(error)")
        }())
        return true
    }

    // MARK: - Dry Baseline

    /// Computes the dry baseline for the given constraints and baseline type.
    ///
    /// For horizontal axis directions, returns the minimum baseline offset
    /// across all children.  For vertical axis directions (`up`/`down`),
    /// returns the first child's baseline offset plus the accumulated
    /// main-axis extent before it.
    ///
    /// **Dart Source:** list_body.dart:66-100
    public override func computeDryBaseline(
        _ constraints: BoxConstraints,
        _ baseline: TextBaseline
    ) -> Double? {
        assert(_debugCheckConstraints(constraints))
        var child: RenderBox?
        let nextChild: (RenderBox) -> RenderBox?
        switch axisDirection {
        case .right, .left:
            let childConstraints = BoxConstraints.tightFor(height: constraints.maxHeight)
            var baselineOffset = BaselineOffset.noBaseline
            child = firstChild
            while let currentChild = child {
                baselineOffset = baselineOffset.minOf(
                    BaselineOffset(currentChild.getDryBaseline(childConstraints, baseline).offset)
                )
                child = childAfter(currentChild)
            }
            return baselineOffset.offset
        case .up:
            child = lastChild
            nextChild = childBefore
        case .down:
            child = firstChild
            nextChild = childAfter
        }
        let childConstraints = BoxConstraints.tightFor(width: constraints.maxWidth)
        var mainAxisExtent = 0.0
        while let currentChild = child {
            let childBaseline = currentChild.getDryBaseline(childConstraints, baseline)
            if let childBaselineValue = childBaseline.offset {
                return childBaselineValue + mainAxisExtent
            }
            mainAxisExtent += currentChild.getDryLayout(childConstraints).height
            child = nextChild(currentChild)
        }
        return nil
    }

    // MARK: - Dry Layout

    /// Computes the dry layout size for the given constraints.
    ///
    /// Iterates all children, lays them out dry with tight cross-axis
    /// constraints, and accumulates the main-axis extent.
    ///
    /// **Dart Source:** list_body.dart:102-132
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        assert(_debugCheckConstraints(constraints))
        var mainAxisExtent = 0.0
        var child = firstChild
        switch axisDirection {
        case .right, .left:
            let innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight)
            while let currentChild = child {
                let childSize = currentChild.getDryLayout(innerConstraints)
                mainAxisExtent += childSize.width
                child = childAfter(currentChild)
            }
            return constraints.constrain(Size(mainAxisExtent, constraints.maxHeight))
        case .up, .down:
            let innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth)
            while let currentChild = child {
                let childSize = currentChild.getDryLayout(innerConstraints)
                mainAxisExtent += childSize.height
                child = childAfter(currentChild)
            }
            return constraints.constrain(Size(constraints.maxWidth, mainAxisExtent))
        }
    }

    // MARK: - Perform Layout

    /// Performs wet layout, placing children sequentially along the axis
    /// direction.
    ///
    /// For `.right` and `.down` the children are positioned in a single
    /// forward pass accumulating offsets.  For `.left` and `.up` a first
    /// pass lays out all children and accumulates the total extent, then a
    /// second pass assigns offsets in reverse order.
    ///
    /// **Dart Source:** list_body.dart:194-271
    public override func performLayout() {
        let constraints = boxConstraints
        assert(_debugCheckConstraints(constraints))
        var mainAxisExtent = 0.0
        var child = firstChild
        switch axisDirection {
        case .right:
            let innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight)
            while let currentChild = child {
                currentChild.layout(innerConstraints, parentUsesSize: true)
                let childParentData = currentChild.parentData as! ListBodyParentData
                childParentData.offset = Offset(mainAxisExtent, 0.0)
                mainAxisExtent += currentChild.size.width
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            size = constraints.constrain(Size(mainAxisExtent, constraints.maxHeight))

        case .left:
            let innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight)
            while let currentChild = child {
                currentChild.layout(innerConstraints, parentUsesSize: true)
                let childParentData = currentChild.parentData as! ListBodyParentData
                mainAxisExtent += currentChild.size.width
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            var position = 0.0
            child = firstChild
            while let currentChild = child {
                let childParentData = currentChild.parentData as! ListBodyParentData
                position += currentChild.size.width
                childParentData.offset = Offset(mainAxisExtent - position, 0.0)
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            size = constraints.constrain(Size(mainAxisExtent, constraints.maxHeight))

        case .down:
            let innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth)
            while let currentChild = child {
                currentChild.layout(innerConstraints, parentUsesSize: true)
                let childParentData = currentChild.parentData as! ListBodyParentData
                childParentData.offset = Offset(0.0, mainAxisExtent)
                mainAxisExtent += currentChild.size.height
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            size = constraints.constrain(Size(constraints.maxWidth, mainAxisExtent))

        case .up:
            let innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth)
            while let currentChild = child {
                currentChild.layout(innerConstraints, parentUsesSize: true)
                let childParentData = currentChild.parentData as! ListBodyParentData
                mainAxisExtent += currentChild.size.height
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            var position = 0.0
            child = firstChild
            while let currentChild = child {
                let childParentData = currentChild.parentData as! ListBodyParentData
                position += currentChild.size.height
                childParentData.offset = Offset(0.0, mainAxisExtent - position)
                assert(currentChild.parentData === childParentData)
                child = childParentData.nextSibling
            }
            size = constraints.constrain(Size(constraints.maxWidth, mainAxisExtent))
        }
        assert(size.isFinite)
    }

    // MARK: - Intrinsic Dimension Helpers

    /// Returns the maximum cross-axis intrinsic dimension across all children.
    ///
    /// **Dart Source:** list_body.dart:279-288
    private func _getIntrinsicCrossAxis(_ childSize: ChildSizingFunction) -> Double {
        var extent = 0.0
        var child = firstChild
        while let currentChild = child {
            extent = max(extent, childSize(currentChild))
            let childParentData = currentChild.parentData as! ListBodyParentData
            child = childParentData.nextSibling
        }
        return extent
    }

    /// Returns the sum of main-axis intrinsic dimensions across all children.
    ///
    /// **Dart Source:** list_body.dart:290-299
    private func _getIntrinsicMainAxis(_ childSize: ChildSizingFunction) -> Double {
        var extent = 0.0
        var child = firstChild
        while let currentChild = child {
            extent += childSize(currentChild)
            let childParentData = currentChild.parentData as! ListBodyParentData
            child = childParentData.nextSibling
        }
        return extent
    }

    // MARK: - Intrinsic Dimensions

    /// Computes the minimum intrinsic width.
    ///
    /// When the main axis is horizontal this is the sum of children's
    /// minimum intrinsic widths; when vertical it is the maximum.
    ///
    /// **Dart Source:** list_body.dart:301-311
    public override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        switch mainAxis {
        case .horizontal:
            return _getIntrinsicMainAxis { child in child.getMinIntrinsicWidth(height) }
        case .vertical:
            return _getIntrinsicCrossAxis { child in child.getMinIntrinsicWidth(height) }
        }
    }

    /// Computes the maximum intrinsic width.
    ///
    /// When the main axis is horizontal this is the sum of children's
    /// maximum intrinsic widths; when vertical it is the maximum.
    ///
    /// **Dart Source:** list_body.dart:313-323
    public override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        switch mainAxis {
        case .horizontal:
            return _getIntrinsicMainAxis { child in child.getMaxIntrinsicWidth(height) }
        case .vertical:
            return _getIntrinsicCrossAxis { child in child.getMaxIntrinsicWidth(height) }
        }
    }

    /// Computes the minimum intrinsic height.
    ///
    /// When the main axis is horizontal this is the maximum of children's
    /// minimum intrinsic heights; when vertical it is the sum.
    ///
    /// **Dart Source:** list_body.dart:325-335
    public override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        switch mainAxis {
        case .horizontal:
            return _getIntrinsicCrossAxis { child in child.getMinIntrinsicHeight(width) }
        case .vertical:
            return _getIntrinsicMainAxis { child in child.getMinIntrinsicHeight(width) }
        }
    }

    /// Computes the maximum intrinsic height.
    ///
    /// When the main axis is horizontal this is the maximum of children's
    /// maximum intrinsic heights; when vertical it is the sum.
    ///
    /// **Dart Source:** list_body.dart:337-347
    public override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        switch mainAxis {
        case .horizontal:
            return _getIntrinsicCrossAxis { child in child.getMaxIntrinsicHeight(width) }
        case .vertical:
            return _getIntrinsicMainAxis { child in child.getMaxIntrinsicHeight(width) }
        }
    }

    // MARK: - Baseline

    /// Computes the distance to the actual baseline by delegating to
    /// `defaultComputeDistanceToFirstActualBaseline`.
    ///
    /// **Dart Source:** list_body.dart:349-352
    public override func computeDistanceToActualBaseline(
        _ baseline: TextBaseline
    ) -> Double? {
        return defaultComputeDistanceToFirstActualBaseline(baseline)
    }

    // MARK: - Paint

    /// Paints children by delegating to `defaultPaint`.
    ///
    /// **Dart Source:** list_body.dart:354-357
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        defaultPaint(context, offset)
    }

    // MARK: - Hit Testing

    /// Hit tests children by delegating to `defaultHitTestChildren`.
    ///
    /// **Dart Source:** list_body.dart:359-362
    public override func hitTestChildren(
        _ result: BoxHitTestResult,
        position: Offset
    ) -> Bool {
        return defaultHitTestChildren(result, position: position)
    }

    // MARK: - Diagnostics

    /// Adds `axisDirection` to the diagnostics properties.
    ///
    /// **Dart Source:** list_body.dart:273-277
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        // super.debugFillProperties(properties) — not yet available on RenderObject stub.
        // TODO: Call super.debugFillProperties(properties) once available.
        properties.add(
            DiagnosticsProperty<String>(
                "axisDirection",
                String(describing: axisDirection)
            )
        )
    }
}

// MARK: - ContainerRenderObjectHost Conformance

extension RenderListBody: ContainerRenderObjectHost {
    public func move(_ child: RenderBox, after: RenderBox?) {
        remove(child)
        insert(child, after: after)
    }
}
