// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Flex layout model types: enums, helper structs, parent data, and the
/// RenderFlex render box.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/flex.dart`

import FlutterSwiftBridge

// MARK: - Internal Helper Types

/// A 2D vector that uses a `RenderFlex`'s main axis and cross axis as its
/// first and second coordinate axes.
///
/// It represents the same vector as `(mainAxisExtent, crossAxisExtent)`.
///
/// Dart name: `_AxisSize` (private extension type wrapping `Size`).
///
/// **Dart Source:** flex.dart:20-51
internal struct FlexAxisSize: Equatable {
    /// The extent along the main axis.
    var mainAxisExtent: Double

    /// The extent along the cross axis.
    var crossAxisExtent: Double

    /// Creates a `FlexAxisSize` with the given main and cross axis extents.
    ///
    /// **Dart Source:** flex.dart:21-22
    init(mainAxisExtent: Double, crossAxisExtent: Double) {
        self.mainAxisExtent = mainAxisExtent
        self.crossAxisExtent = crossAxisExtent
    }

    /// An empty axis size with both extents set to zero.
    ///
    /// **Dart Source:** flex.dart:26
    static let empty = FlexAxisSize(mainAxisExtent: 0, crossAxisExtent: 0)

    /// Creates a `FlexAxisSize` from a `Size`, converting based on direction.
    ///
    /// For horizontal direction, width maps to main axis and height to cross.
    /// For vertical direction, the axes are swapped.
    ///
    /// **Dart Source:** flex.dart:23-24
    init(from size: Size, direction: Axis) {
        let converted = FlexAxisSize._convert(size, direction)
        self.mainAxisExtent = converted.width
        self.crossAxisExtent = converted.height
    }

    /// Converts a `Size` by swapping width/height for vertical direction.
    ///
    /// **Dart Source:** flex.dart:28-33
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
    /// **Dart Source:** flex.dart:38
    func toSize(_ direction: Axis) -> Size {
        FlexAxisSize._convert(Size(mainAxisExtent, crossAxisExtent), direction)
    }

    /// Returns a new `FlexAxisSize` constrained by the given box constraints
    /// and direction.
    ///
    /// **Dart Source:** flex.dart:40-46
    func applyConstraints(_ constraints: BoxConstraints, _ direction: Axis) -> FlexAxisSize {
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
        return FlexAxisSize(mainAxisExtent: constrained.width, crossAxisExtent: constrained.height)
    }

    /// Adds two axis sizes: sums main axis extents and takes the max of cross
    /// axis extents.
    ///
    /// **Dart Source:** flex.dart:48-51
    static func + (lhs: FlexAxisSize, rhs: FlexAxisSize) -> FlexAxisSize {
        FlexAxisSize(
            mainAxisExtent: lhs.mainAxisExtent + rhs.mainAxisExtent,
            crossAxisExtent: max(lhs.crossAxisExtent, rhs.crossAxisExtent)
        )
    }
}

// MARK: - AscentDescent

/// The ascent and descent of a baseline-aligned child.
///
/// Baseline-aligned children contribute to the cross axis extent of a
/// `RenderFlex` differently from children with other `CrossAxisAlignment`s.
///
/// Dart name: `_AscentDescent` (private extension type).
///
/// **Dart Source:** flex.dart:57-75
internal struct AscentDescent {
    /// The ascent and descent values, or `nil` if no baseline is available.
    let ascentDescent: (ascent: Double, descent: Double)?

    /// Creates an `AscentDescent` from a baseline offset and cross size.
    ///
    /// **Dart Source:** flex.dart:58-62
    init(baselineOffset: Double?, crossSize: Double) {
        if let baselineOffset = baselineOffset {
            self.ascentDescent = (baselineOffset, crossSize - baselineOffset)
        } else {
            self.ascentDescent = nil
        }
    }

    /// Private initializer for internal use.
    private init(tuple: (ascent: Double, descent: Double)?) {
        self.ascentDescent = tuple
    }

    /// No baseline information available.
    ///
    /// **Dart Source:** flex.dart:63
    static let none = AscentDescent(tuple: nil)

    /// The baseline offset (ascent), or `nil` if no baseline.
    ///
    /// **Dart Source:** flex.dart:65
    var baselineOffset: Double? {
        ascentDescent?.ascent
    }

    /// Combines two `AscentDescent` values by taking the max of each component.
    ///
    /// If either operand is `none`, returns the other operand.
    ///
    /// **Dart Source:** flex.dart:67-74
    static func + (lhs: AscentDescent, rhs: AscentDescent) -> AscentDescent {
        switch (lhs.ascentDescent, rhs.ascentDescent) {
        case (nil, _):
            return rhs
        case (_, nil):
            return lhs
        case let (x?, y?):
            return AscentDescent(tuple: (max(x.ascent, y.ascent), max(x.descent, y.descent)))
        }
    }
}

// MARK: - Typedefs

/// Callback to compute a child's size given a cross-axis extent.
///
/// **Dart Source:** flex.dart:77
internal typealias FlexChildSizingFunction = (RenderBox, Double) -> Double

/// Callback to retrieve the next child in the child list.
///
/// **Dart Source:** flex.dart:78
internal typealias FlexNextChild = (RenderBox) -> RenderBox?

// MARK: - LayoutSizes

/// Layout result for the flex algorithm: constrained axis size, free space,
/// baseline offset, and space per flex unit.
///
/// Dart name: `_LayoutSizes` (private class).
///
/// **Dart Source:** flex.dart:80-102
internal struct LayoutSizes {
    /// The final constrained axis size of the RenderFlex.
    ///
    /// **Dart Source:** flex.dart:89
    let axisSize: FlexAxisSize

    /// The free space along the main axis. Positive means distributable;
    /// negative means the RenderFlex overflows.
    ///
    /// **Dart Source:** flex.dart:94
    let mainAxisFreeSpace: Double

    /// The baseline offset, or nil if not baseline-aligned or no valid baseline.
    ///
    /// **Dart Source:** flex.dart:98
    let baselineOffset: Double?

    /// The allocated space per flex unit for flex children, or nil if none.
    ///
    /// **Dart Source:** flex.dart:101
    let spacePerFlex: Double?
}

// MARK: - FlexFit

/// How the child is inscribed into the available space.
///
/// **Dart Source:** flex.dart:112-123
public enum FlexFit {
    /// The child is forced to fill the available space.
    ///
    /// The `Expanded` widget assigns this kind of `FlexFit` to its child.
    ///
    /// **Dart Source:** flex.dart:116
    case tight

    /// The child can be at most as large as the available space (but is
    /// allowed to be smaller).
    ///
    /// The `Flexible` widget assigns this kind of `FlexFit` to its child.
    ///
    /// **Dart Source:** flex.dart:122
    case loose
}

// MARK: - FlexParentData

/// Parent data for use with `RenderFlex`.
///
/// **Dart Source:** flex.dart:126-146
public class FlexParentData: ContainerBoxParentData<RenderBox> {
    /// The flex factor to use for this child.
    ///
    /// If null or zero, the child is inflexible and determines its own size. If
    /// non-zero, the amount of space the child can occupy in the main axis is
    /// determined by dividing the free space (after placing the inflexible
    /// children) according to the flex factors of the flexible children.
    ///
    /// **Dart Source:** flex.dart:133
    public var flex: Int? = nil

    /// How a flexible child is inscribed into the available space.
    ///
    /// If `flex` is non-zero, the `fit` determines whether the child fills the
    /// space the parent makes available during layout. If the fit is
    /// `FlexFit.tight`, the child is required to fill the available space. If the
    /// fit is `FlexFit.loose`, the child can be at most as large as the available
    /// space (but is allowed to be smaller).
    ///
    /// **Dart Source:** flex.dart:142
    public var fit: FlexFit? = nil
}

// MARK: - MainAxisSize

/// How much space should be occupied in the main axis.
///
/// During a flex layout, available space along the main axis is allocated to
/// children. After allocating space, there might be some remaining free space.
/// This value controls whether to maximize or minimize the amount of free
/// space, subject to the incoming layout constraints.
///
/// **Dart Source:** flex.dart:162-187
public enum MainAxisSize {
    /// Minimize the amount of free space along the main axis, subject to the
    /// incoming layout constraints.
    ///
    /// **Dart Source:** flex.dart:174
    case min

    /// Maximize the amount of free space along the main axis, subject to the
    /// incoming layout constraints.
    ///
    /// **Dart Source:** flex.dart:186
    case max
}

// MARK: - MainAxisAlignment

/// How the children should be placed along the main axis in a flex layout.
///
/// **Dart Source:** flex.dart:195-265
public enum MainAxisAlignment {
    /// Place the children as close to the start of the main axis as possible.
    ///
    /// **Dart Source:** flex.dart:203
    case start

    /// Place the children as close to the end of the main axis as possible.
    ///
    /// **Dart Source:** flex.dart:212
    case end

    /// Place the children as close to the middle of the main axis as possible.
    ///
    /// **Dart Source:** flex.dart:215
    case center

    /// Place the free space evenly between the children.
    ///
    /// **Dart Source:** flex.dart:218
    case spaceBetween

    /// Place the free space evenly between the children as well as half of that
    /// space before and after the first and last child.
    ///
    /// **Dart Source:** flex.dart:222
    case spaceAround

    /// Place the free space evenly between the children as well as before and
    /// after the first and last child.
    ///
    /// **Dart Source:** flex.dart:226
    case spaceEvenly

    /// Distributes free space into leading space and between-item spacing.
    ///
    /// Returns a tuple of `(leadingSpace, betweenSpace)`.
    ///
    /// **Dart Source:** flex.dart:228-265
    internal func distributeSpace(
        freeSpace: Double,
        itemCount: Int,
        flipped: Bool,
        spacing: Double
    ) -> (leadingSpace: Double, betweenSpace: Double) {
        assert(itemCount >= 0)
        switch self {
        case .start:
            return (flipped ? freeSpace : 0.0, spacing)

        case .end:
            return MainAxisAlignment.start.distributeSpace(
                freeSpace: freeSpace,
                itemCount: itemCount,
                flipped: !flipped,
                spacing: spacing
            )

        case .center:
            return (freeSpace / 2.0, spacing)

        case .spaceBetween:
            if itemCount < 2 {
                return MainAxisAlignment.start.distributeSpace(
                    freeSpace: freeSpace,
                    itemCount: itemCount,
                    flipped: flipped,
                    spacing: spacing
                )
            }
            return (0.0, freeSpace / Double(itemCount - 1) + spacing)

        case .spaceAround:
            if itemCount == 0 {
                return MainAxisAlignment.start.distributeSpace(
                    freeSpace: freeSpace,
                    itemCount: itemCount,
                    flipped: flipped,
                    spacing: spacing
                )
            }
            return (
                freeSpace / Double(itemCount) / 2,
                freeSpace / Double(itemCount) + spacing
            )

        case .spaceEvenly:
            return (
                freeSpace / Double(itemCount + 1),
                freeSpace / Double(itemCount + 1) + spacing
            )
        }
    }
}

// MARK: - CrossAxisAlignment

/// How the children should be placed along the cross axis in a flex layout.
///
/// **Dart Source:** flex.dart:276-363
public enum CrossAxisAlignment {
    /// Place the children with their start edge aligned with the start side of
    /// the cross axis.
    ///
    /// **Dart Source:** flex.dart:289
    case start

    /// Place the children as close to the end of the cross axis as possible.
    ///
    /// **Dart Source:** flex.dart:302
    case end

    /// Place the children so that their centers align with the middle of the
    /// cross axis.
    ///
    /// This is the default cross-axis alignment.
    ///
    /// **Dart Source:** flex.dart:308
    case center

    /// Require the children to fill the cross axis.
    ///
    /// This causes the constraints passed to the children to be tight in the
    /// cross axis.
    ///
    /// **Dart Source:** flex.dart:314
    case stretch

    /// Place the children along the cross axis such that their baselines match.
    ///
    /// Because baselines are always horizontal, this alignment is intended for
    /// horizontal main axes. If the main axis is vertical, then this value is
    /// treated like `start`.
    ///
    /// **Dart Source:** flex.dart:349
    case baseline

    /// Returns the cross-axis offset for a child given the free space and
    /// whether the cross axis is flipped.
    ///
    /// **Dart Source:** flex.dart:351-362
    internal func getChildCrossAxisOffset(_ freeSpace: Double, _ flipped: Bool) -> Double {
        // This method should not be used to position baseline-aligned children.
        switch self {
        case .stretch, .baseline:
            return 0.0
        case .start:
            return flipped ? freeSpace : 0.0
        case .center:
            return freeSpace / 2
        case .end:
            return CrossAxisAlignment.start.getChildCrossAxisOffset(freeSpace, !flipped)
        }
    }
}

// MARK: - RenderFlex

/// Displays its children in a one-dimensional array.
///
/// A `RenderFlex` lays out each child and attempts to place the child adjacent
/// to the previous child in the main axis, given by `direction`, leaving
/// `spacing` logical pixels between each child.
///
/// In Dart this class extends `RenderBox` and mixes in
/// `ContainerRenderObjectMixin<RenderBox, FlexParentData>`,
/// `RenderBoxContainerDefaultsMixin<RenderBox, FlexParentData>`, and
/// `DebugOverflowIndicatorMixin`.
///
/// Since Swift does not support generic mixins, the container management
/// (linked-list child pointers) is implemented inline, and the class
/// conforms to `RenderBoxContainerDefaults` for default paint and
/// hit-testing behavior.
///
/// **Dart Source:** flex.dart:412-1419
public class RenderFlex: RenderBox, RenderBoxContainerDefaults, DebugOverflowIndicator {
    public typealias ChildType = RenderBox

    // MARK: - DebugOverflowIndicator conformance

    /// Whether a report should be generated the next time overflow is detected.
    ///
    /// **Dart Source:** debug_overflow_indicator.dart:127
    public var _overflowReportNeeded: Bool = true

    /// Cached text painters for the overflow labels, one per side.
    ///
    /// **Dart Source:** debug_overflow_indicator.dart:111-115
    public var _indicatorLabel: [TextPainter] = createOverflowIndicatorLabels()

    // MARK: - Container child management (ContainerRenderObjectMixin)

    /// The first child in the child list.
    ///
    /// **Dart Source:** object.dart:4222
    public private(set) var firstChild: RenderBox?

    /// The last child in the child list.
    ///
    /// **Dart Source:** object.dart:4223
    public private(set) var lastChild: RenderBox?

    /// The number of children.
    ///
    /// **Dart Source:** object.dart:4226
    public private(set) var childCount: Int = 0

    /// Returns the next sibling of the given child.
    ///
    /// **Dart Source:** object.dart:4393
    public func childAfter(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! FlexParentData
        return parentData.nextSibling
    }

    /// Returns the previous sibling of the given child.
    ///
    /// **Dart Source:** object.dart:4399
    public func childBefore(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! FlexParentData
        return parentData.previousSibling
    }

    /// Inserts a child into the linked list.
    ///
    /// **Dart Source:** object.dart:4234-4268
    private func _insertIntoChildList(_ child: RenderBox, after: RenderBox? = nil) {
        let childParentData = child.parentData as! FlexParentData
        childCount += 1
        assert(childCount > 0)
        if let after = after {
            let afterParentData = after.parentData as! FlexParentData
            childParentData.nextSibling = afterParentData.nextSibling
            if let nextSibling = afterParentData.nextSibling {
                let nextParentData = nextSibling.parentData as! FlexParentData
                nextParentData.previousSibling = child
            }
            afterParentData.nextSibling = child
            childParentData.previousSibling = after
            if after === lastChild {
                lastChild = child
            }
        } else {
            childParentData.nextSibling = firstChild
            if let first = firstChild {
                let firstParentData = first.parentData as! FlexParentData
                firstParentData.previousSibling = child
            }
            firstChild = child
            lastChild = lastChild ?? child
        }
    }

    /// Removes a child from the linked list.
    ///
    /// **Dart Source:** object.dart:4271-4295
    private func _removeFromChildList(_ child: RenderBox) {
        let childParentData = child.parentData as! FlexParentData
        if childParentData.previousSibling == nil {
            firstChild = childParentData.nextSibling
        } else {
            let previousParentData =
                childParentData.previousSibling!.parentData as! FlexParentData
            previousParentData.nextSibling = childParentData.nextSibling
        }
        if childParentData.nextSibling == nil {
            lastChild = childParentData.previousSibling
        } else {
            let nextParentData =
                childParentData.nextSibling!.parentData as! FlexParentData
            nextParentData.previousSibling = childParentData.previousSibling
        }
        childParentData.previousSibling = nil
        childParentData.nextSibling = nil
        childCount -= 1
    }

    /// Adds a child to the child list, optionally after the given child.
    ///
    /// **Dart Source:** object.dart:4310-4323
    public func insert(_ child: RenderBox, after: RenderBox? = nil) {
        adoptChild(child)
        _insertIntoChildList(child, after: after)
    }

    /// Appends all the given children to the end of the child list.
    ///
    /// **Dart Source:** object.dart:4325-4341
    public func addAll(_ children: [RenderBox]?) {
        children?.forEach { insert($0, after: lastChild) }
    }

    /// Removes a child from the child list.
    ///
    /// **Dart Source:** object.dart:4343-4353
    public func remove(_ child: RenderBox) {
        _removeFromChildList(child)
        dropChild(child)
    }

    // MARK: - Constructor

    /// Creates a flex render object.
    ///
    /// By default, the flex layout is horizontal and children are aligned to the
    /// start of the main axis and the center of the cross axis.
    ///
    /// **Dart Source:** flex.dart:421-443
    public init(
        children: [RenderBox]? = nil,
        direction: Axis = .horizontal,
        mainAxisAlignment: MainAxisAlignment = .start,
        mainAxisSize: MainAxisSize = .max,
        crossAxisAlignment: CrossAxisAlignment = .center,
        textDirection: TextDirection? = nil,
        verticalDirection: VerticalDirection = .down,
        textBaseline: TextBaseline? = nil,
        clipBehavior: Clip = .none,
        spacing: Double = 0.0
    ) {
        assert(spacing >= 0.0)
        self._direction = direction
        self._mainAxisAlignment = mainAxisAlignment
        self._mainAxisSize = mainAxisSize
        self._crossAxisAlignment = crossAxisAlignment
        self._textDirection = textDirection
        self._verticalDirection = verticalDirection
        self._textBaseline = textBaseline
        self._clipBehavior = clipBehavior
        self._spacing = spacing
        super.init()
        addAll(children)
    }

    // MARK: - Properties

    /// The direction to use as the main axis.
    ///
    /// **Dart Source:** flex.dart:446-453
    public var direction: Axis {
        get { _direction }
        set {
            if _direction != newValue {
                _direction = newValue
                markNeedsLayout()
            }
        }
    }
    private var _direction: Axis

    /// How the children should be placed along the main axis.
    ///
    /// **Dart Source:** flex.dart:464-471
    public var mainAxisAlignment: MainAxisAlignment {
        get { _mainAxisAlignment }
        set {
            if _mainAxisAlignment != newValue {
                _mainAxisAlignment = newValue
                markNeedsLayout()
            }
        }
    }
    private var _mainAxisAlignment: MainAxisAlignment

    /// How much space should be occupied in the main axis.
    ///
    /// **Dart Source:** flex.dart:483-490
    public var mainAxisSize: MainAxisSize {
        get { _mainAxisSize }
        set {
            if _mainAxisSize != newValue {
                _mainAxisSize = newValue
                markNeedsLayout()
            }
        }
    }
    private var _mainAxisSize: MainAxisSize

    /// How the children should be placed along the cross axis.
    ///
    /// **Dart Source:** flex.dart:501-508
    public var crossAxisAlignment: CrossAxisAlignment {
        get { _crossAxisAlignment }
        set {
            if _crossAxisAlignment != newValue {
                _crossAxisAlignment = newValue
                markNeedsLayout()
            }
        }
    }
    private var _crossAxisAlignment: CrossAxisAlignment

    /// Determines the order to lay children out horizontally and how to
    /// interpret `start` and `end` in the horizontal direction.
    ///
    /// **Dart Source:** flex.dart:530-537
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

    /// Determines the order to lay children out vertically and how to
    /// interpret `start` and `end` in the vertical direction.
    ///
    /// **Dart Source:** flex.dart:557-564
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

    /// If aligning items according to their baseline, which baseline to use.
    ///
    /// Must not be nil if `crossAxisAlignment` is `.baseline`.
    ///
    /// **Dart Source:** flex.dart:569-577
    public var textBaseline: TextBaseline? {
        get { _textBaseline }
        set {
            assert(_crossAxisAlignment != .baseline || newValue != nil)
            if _textBaseline != newValue {
                _textBaseline = newValue
                markNeedsLayout()
            }
        }
    }
    private var _textBaseline: TextBaseline?

    /// Set during layout if overflow occurred on the main axis.
    ///
    /// **Dart Source:** flex.dart:623
    internal var _overflow: Double = 0

    /// Check whether any meaningful overflow is present. Values below an epsilon
    /// are treated as not overflowing.
    ///
    /// **Dart Source:** flex.dart:626
    internal var _hasOverflow: Bool { _overflow > precisionErrorTolerance }

    /// Controls how to clip.
    ///
    /// Defaults to `Clip.none`.
    ///
    /// **Dart Source:** flex.dart:631-639
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

    /// How much space to place between children in the main axis.
    ///
    /// The spacing is only applied between children in the main axis.
    ///
    /// Defaults to 0.0.
    ///
    /// **Dart Source:** flex.dart:694-702
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

    // MARK: - Setup Parent Data

    /// Ensures the child has `FlexParentData`.
    ///
    /// **Dart Source:** flex.dart:705-709
    public override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is FlexParentData) {
            child.parentData = FlexParentData()
        }
    }

    // MARK: - Helper Methods

    /// Whether the layout should flip the main axis direction.
    ///
    /// Used to decide whether to lay out left-to-right/top-to-bottom (false),
    /// or right-to-left/bottom-to-top (true). Returns false when the layout
    /// direction does not matter (for instance, when there is no child).
    ///
    /// **Dart Source:** flex.dart:855-866
    internal var _flipMainAxis: Bool {
        guard firstChild != nil else { return false }
        switch direction {
        case .horizontal:
            switch textDirection {
            case nil, .ltr:
                return false
            case .rtl:
                return true
            }
        case .vertical:
            switch verticalDirection {
            case .down:
                return false
            case .up:
                return true
            }
        }
    }

    /// Whether the layout should flip the cross axis direction.
    ///
    /// **Dart Source:** flex.dart:868-879
    internal var _flipCrossAxis: Bool {
        guard firstChild != nil else { return false }
        switch direction {
        case .vertical:
            switch textDirection {
            case nil, .ltr:
                return false
            case .rtl:
                return true
            }
        case .horizontal:
            switch verticalDirection {
            case .down:
                return false
            case .up:
                return true
            }
        }
    }

    /// Whether this RenderFlex is baseline-aligned (only meaningful for
    /// horizontal direction).
    ///
    /// **Dart Source:** flex.dart:824-835
    internal var _isBaselineAligned: Bool {
        switch crossAxisAlignment {
        case .baseline:
            switch direction {
            case .horizontal:
                return true
            case .vertical:
                return false
            }
        case .start, .center, .end, .stretch:
            return false
        }
    }

    /// Returns the flex factor of a child, or 0 if the child is inflexible.
    ///
    /// **Dart Source:** flex.dart:814-817
    internal static func _getFlex(_ child: RenderBox) -> Int {
        let childParentData = child.parentData! as! FlexParentData
        return childParentData.flex ?? 0
    }

    /// Returns the flex fit of a child.
    ///
    /// **Dart Source:** flex.dart:819-822
    internal static func _getFit(_ child: RenderBox) -> FlexFit {
        let childParentData = child.parentData! as! FlexParentData
        return childParentData.fit ?? .tight
    }

    /// Returns the main axis size of a `Size` based on the current direction.
    ///
    /// **Dart Source:** flex.dart:844-849
    internal func _getMainSize(_ size: Size) -> Double {
        switch _direction {
        case .horizontal:
            return size.width
        case .vertical:
            return size.height
        }
    }

    /// Returns the cross axis size of a `Size` based on the current direction.
    ///
    /// **Dart Source:** flex.dart:837-842
    internal func _getCrossSize(_ size: Size) -> Double {
        switch _direction {
        case .horizontal:
            return size.height
        case .vertical:
            return size.width
        }
    }

    // MARK: - Intrinsic Dimensions

    /// Computes an intrinsic size in the given sizing direction.
    ///
    /// **Dart Source:** flex.dart:711-768
    private func _getIntrinsicSize(
        sizingDirection: Axis,
        extent: Double,
        childSize: FlexChildSizingFunction
    ) -> Double {
        if _direction == sizingDirection {
            // INTRINSIC MAIN SIZE
            // Intrinsic main size is the smallest size the flex container can take
            // while maintaining the min/max-content contributions of its flex items.
            var totalFlex: Double = 0.0
            var inflexibleSpace: Double = spacing * Double(childCount - 1)
            var maxFlexFractionSoFar: Double = 0.0
            var child = firstChild
            while let currentChild = child {
                let flex = RenderFlex._getFlex(currentChild)
                totalFlex += Double(flex)
                if flex > 0 {
                    let flexFraction = childSize(currentChild, extent) / Double(flex)
                    maxFlexFractionSoFar = Swift.max(maxFlexFractionSoFar, flexFraction)
                } else {
                    inflexibleSpace += childSize(currentChild, extent)
                }
                child = childAfter(currentChild)
            }
            return maxFlexFractionSoFar * totalFlex + inflexibleSpace
        } else {
            // INTRINSIC CROSS SIZE
            // Intrinsic cross size is the max of the intrinsic cross sizes of the
            // children, after the flexible children are fit into the available space,
            // with the children sized using their max intrinsic dimensions.
            let isHorizontal: Bool
            switch direction {
            case .horizontal:
                isHorizontal = true
            case .vertical:
                isHorizontal = false
            }

            let layoutChild: ChildLayouter = { child, constraints in
                let mainAxisSizeFromConstraints = isHorizontal
                    ? constraints.maxWidth
                    : constraints.maxHeight
                let maxMainAxisSize: Double
                if mainAxisSizeFromConstraints.isFinite {
                    maxMainAxisSize = mainAxisSizeFromConstraints
                } else {
                    maxMainAxisSize = isHorizontal
                        ? child.getMaxIntrinsicWidth(.infinity)
                        : child.getMaxIntrinsicHeight(.infinity)
                }
                return isHorizontal
                    ? Size(maxMainAxisSize, childSize(child, maxMainAxisSize))
                    : Size(childSize(child, maxMainAxisSize), maxMainAxisSize)
            }

            return _computeSizes(
                constraints: isHorizontal
                    ? BoxConstraints(maxWidth: extent)
                    : BoxConstraints(maxHeight: extent),
                layoutChild: layoutChild,
                getBaseline: ChildLayoutHelper.getDryBaseline
            ).axisSize.crossAxisExtent
        }
    }

    /// Computes the minimum intrinsic width.
    ///
    /// **Dart Source:** flex.dart:771-777
    public override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return _getIntrinsicSize(
            sizingDirection: Axis.horizontal,
            extent: height,
            childSize: { child, extent in child.getMinIntrinsicWidth(extent) }
        )
    }

    /// Computes the maximum intrinsic width.
    ///
    /// **Dart Source:** flex.dart:780-786
    public override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return _getIntrinsicSize(
            sizingDirection: Axis.horizontal,
            extent: height,
            childSize: { child, extent in child.getMaxIntrinsicWidth(extent) }
        )
    }

    /// Computes the minimum intrinsic height.
    ///
    /// **Dart Source:** flex.dart:789-795
    public override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return _getIntrinsicSize(
            sizingDirection: Axis.vertical,
            extent: width,
            childSize: { child, extent in child.getMinIntrinsicHeight(extent) }
        )
    }

    /// Computes the maximum intrinsic height.
    ///
    /// **Dart Source:** flex.dart:798-804
    public override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return _getIntrinsicSize(
            sizingDirection: Axis.vertical,
            extent: width,
            childSize: { child, extent in child.getMaxIntrinsicHeight(extent) }
        )
    }

    // MARK: - Baseline

    /// Returns the distance from the y-coordinate of the position of the box to
    /// the y-coordinate of the first given baseline.
    ///
    /// For horizontal direction, returns the highest actual baseline.
    /// For vertical direction, returns the first actual baseline.
    ///
    /// **Dart Source:** flex.dart:806-812
    public override func computeDistanceToActualBaseline(_ baseline: TextBaseline) -> Double? {
        switch _direction {
        case .horizontal:
            return defaultComputeDistanceToHighestActualBaseline(baseline)
        case .vertical:
            return defaultComputeDistanceToFirstActualBaseline(baseline)
        }
    }

    // MARK: - Constraints Helpers

    /// Returns the constraints for a non-flex child.
    ///
    /// **Dart Source:** flex.dart:881-899
    internal func _constraintsForNonFlexChild(_ constraints: BoxConstraints) -> BoxConstraints {
        let fillCrossAxis: Bool
        switch crossAxisAlignment {
        case .stretch:
            fillCrossAxis = true
        case .start, .center, .end, .baseline:
            fillCrossAxis = false
        }
        switch _direction {
        case .horizontal:
            return fillCrossAxis
                ? BoxConstraints.tightFor(height: constraints.maxHeight)
                : BoxConstraints(maxHeight: constraints.maxHeight)
        case .vertical:
            return fillCrossAxis
                ? BoxConstraints.tightFor(width: constraints.maxWidth)
                : BoxConstraints(maxWidth: constraints.maxWidth)
        }
    }

    /// Returns the constraints for a flex child given the maximum extent.
    ///
    /// **Dart Source:** flex.dart:901-933
    internal func _constraintsForFlexChild(
        _ child: RenderBox,
        _ constraints: BoxConstraints,
        _ maxChildExtent: Double
    ) -> BoxConstraints {
        assert(RenderFlex._getFlex(child) > 0)
        assert(maxChildExtent >= 0.0)
        let minChildExtent: Double
        switch RenderFlex._getFit(child) {
        case .tight:
            minChildExtent = maxChildExtent
        case .loose:
            minChildExtent = 0.0
        }
        let fillCrossAxis: Bool
        switch crossAxisAlignment {
        case .stretch:
            fillCrossAxis = true
        case .start, .center, .end, .baseline:
            fillCrossAxis = false
        }
        switch _direction {
        case .horizontal:
            return BoxConstraints(
                minWidth: minChildExtent,
                maxWidth: maxChildExtent,
                minHeight: fillCrossAxis ? constraints.maxHeight : 0.0,
                maxHeight: constraints.maxHeight
            )
        case .vertical:
            return BoxConstraints(
                minWidth: fillCrossAxis ? constraints.maxWidth : 0.0,
                maxWidth: constraints.maxWidth,
                minHeight: minChildExtent,
                maxHeight: maxChildExtent
            )
        }
    }

    // MARK: - _computeSizes

    /// The core flex layout algorithm.
    ///
    /// Lays out non-flex children, distributes remaining space to flex children,
    /// computes cross-axis extent, and returns the layout sizes.
    ///
    /// **Dart Source:** flex.dart:1129-1241
    internal func _computeSizes(
        constraints: BoxConstraints,
        layoutChild: ChildLayouter,
        getBaseline: ChildBaselineGetter
    ) -> LayoutSizes {
        let maxMainSize = _getMainSize(constraints.biggest)
        let canFlex = maxMainSize.isFinite
        let nonFlexChildConstraints = _constraintsForNonFlexChild(constraints)

        // Null indicates the children are not baseline aligned.
        let textBaseline: TextBaseline? = _isBaselineAligned ? self.textBaseline : nil

        // The first pass lays out non-flex children and computes total flex.
        var totalFlex = 0
        var firstFlexChild: RenderBox? = nil
        var accumulatedAscentDescent = AscentDescent.none
        // Initially, accumulatedSize is the sum of the spaces between children in
        // the main axis.
        var accumulatedSize = FlexAxisSize(
            mainAxisExtent: spacing * Double(childCount - 1),
            crossAxisExtent: 0.0
        )

        var child = firstChild
        while let currentChild = child {
            let flex: Int
            if canFlex && (RenderFlex._getFlex(currentChild)) > 0 {
                flex = RenderFlex._getFlex(currentChild)
                totalFlex += flex
                if firstFlexChild == nil {
                    firstFlexChild = currentChild
                }
            } else {
                let childSize = FlexAxisSize(
                    from: layoutChild(currentChild, nonFlexChildConstraints),
                    direction: direction
                )
                accumulatedSize = accumulatedSize + childSize
                // Baseline-aligned children contribute to the cross axis extent separately.
                let baselineOffset: Double? = textBaseline == nil
                    ? nil
                    : getBaseline(currentChild, nonFlexChildConstraints, textBaseline!)
                accumulatedAscentDescent = accumulatedAscentDescent + AscentDescent(
                    baselineOffset: baselineOffset,
                    crossSize: childSize.crossAxisExtent
                )
            }
            child = childAfter(currentChild)
        }

        assert((totalFlex == 0) == (firstFlexChild == nil))

        // The second pass distributes free space to flexible children.
        let flexSpace = Swift.max(0.0, maxMainSize - accumulatedSize.mainAxisExtent)
        let spacePerFlex = totalFlex > 0 ? flexSpace / Double(totalFlex) : 0.0

        if let firstFlex = firstFlexChild {
            var flexChild: RenderBox? = firstFlex
            var remainingFlex = totalFlex
            while let currentChild = flexChild, remainingFlex > 0 {
                let flex = RenderFlex._getFlex(currentChild)
                if flex == 0 {
                    flexChild = childAfter(currentChild)
                    continue
                }
                remainingFlex -= flex
                assert(spacePerFlex.isFinite)
                let maxChildExtent = spacePerFlex * Double(flex)
                let childConstraints = _constraintsForFlexChild(
                    currentChild,
                    constraints,
                    maxChildExtent
                )
                let childSize = FlexAxisSize(
                    from: layoutChild(currentChild, childConstraints),
                    direction: direction
                )
                accumulatedSize = accumulatedSize + childSize
                let baselineOffset: Double? = textBaseline == nil
                    ? nil
                    : getBaseline(currentChild, childConstraints, textBaseline!)
                accumulatedAscentDescent = accumulatedAscentDescent + AscentDescent(
                    baselineOffset: baselineOffset,
                    crossSize: childSize.crossAxisExtent
                )
                flexChild = childAfter(currentChild)
            }
        }

        // The overall height of baseline-aligned children contributes to the
        // cross axis extent.
        if let ad = accumulatedAscentDescent.ascentDescent {
            accumulatedSize = accumulatedSize + FlexAxisSize(
                mainAxisExtent: 0,
                crossAxisExtent: ad.ascent + ad.descent
            )
        }

        let idealMainSize: Double
        switch mainAxisSize {
        case .max where maxMainSize.isFinite:
            idealMainSize = maxMainSize
        default:
            idealMainSize = accumulatedSize.mainAxisExtent
        }

        let constrainedSize = FlexAxisSize(
            mainAxisExtent: idealMainSize,
            crossAxisExtent: accumulatedSize.crossAxisExtent
        ).applyConstraints(constraints, direction)

        return LayoutSizes(
            axisSize: constrainedSize,
            mainAxisFreeSpace: constrainedSize.mainAxisExtent - accumulatedSize.mainAxisExtent,
            baselineOffset: accumulatedAscentDescent.baselineOffset,
            spacePerFlex: firstFlexChild == nil ? nil : spacePerFlex
        )
    }

    // MARK: - Layout

    /// Computes the dry layout for the given constraints.
    ///
    /// Calls `_computeSizes` with `ChildLayoutHelper.dryLayoutChild` and
    /// `ChildLayoutHelper.getDryBaseline`, then converts the resulting axis
    /// size back to a `Size` for the current direction.
    ///
    /// **Dart Source:** flex.dart:1005-1024
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return _computeSizes(
            constraints: constraints,
            layoutChild: ChildLayoutHelper.dryLayoutChild,
            getBaseline: ChildLayoutHelper.getDryBaseline
        ).axisSize.toSize(direction)
    }

    /// Computes the dry baseline for the given constraints.
    ///
    /// When the flex is baseline-aligned, returns the baseline offset directly
    /// from `_computeSizes`. Otherwise computes the baseline by iterating
    /// children and accounting for their positions along the main/cross axes.
    ///
    /// **Dart Source:** flex.dart:936-1001
    public override func computeDryBaseline(
        _ constraints: BoxConstraints,
        _ baseline: TextBaseline
    ) -> Double? {
        let sizes = _computeSizes(
            constraints: constraints,
            layoutChild: ChildLayoutHelper.dryLayoutChild,
            getBaseline: ChildLayoutHelper.getDryBaseline
        )

        if _isBaselineAligned {
            return sizes.baselineOffset
        }

        let nonFlexConstraints = _constraintsForNonFlexChild(constraints)
        let constraintsForChild: (RenderBox) -> BoxConstraints = { child in
            if let spacePerFlex = sizes.spacePerFlex {
                let flex = RenderFlex._getFlex(child)
                if flex > 0 {
                    return self._constraintsForFlexChild(
                        child,
                        constraints,
                        Double(flex) * spacePerFlex
                    )
                }
            }
            return nonFlexConstraints
        }

        var baselineOffset = BaselineOffset.noBaseline
        switch direction {
        case .vertical:
            let freeSpace = Swift.max(0.0, sizes.mainAxisFreeSpace)
            let flipMain = _flipMainAxis
            let (leadingSpaceY, spaceBetween) = mainAxisAlignment.distributeSpace(
                freeSpace: freeSpace,
                itemCount: childCount,
                flipped: flipMain,
                spacing: spacing
            )
            var y: Double
            if flipMain {
                y =
                    leadingSpaceY
                    + Double(childCount - 1) * spaceBetween
                    + (sizes.axisSize.mainAxisExtent - sizes.mainAxisFreeSpace)
            } else {
                y = leadingSpaceY
            }
            let directionUnit = flipMain ? -1.0 : 1.0
            var child = firstChild
            while baselineOffset == BaselineOffset.noBaseline, let currentChild = child {
                let childConstraints = constraintsForChild(currentChild)
                let childSize = currentChild.getDryLayout(childConstraints)
                let childBaselineOffset = currentChild.getDryBaseline(
                    childConstraints, baseline
                ).offset
                let additionalY = flipMain ? -childSize.height : 0.0
                baselineOffset = BaselineOffset(childBaselineOffset) + y + additionalY
                y += directionUnit * (spaceBetween + childSize.height)
                child = childAfter(currentChild)
            }
        case .horizontal:
            let flipCross = _flipCrossAxis
            var child = firstChild
            while let currentChild = child {
                let childConstraints = constraintsForChild(currentChild)
                let distance = BaselineOffset(
                    currentChild.getDryBaseline(childConstraints, baseline).offset
                )
                let freeCrossAxisSpace =
                    sizes.axisSize.crossAxisExtent
                    - currentChild.getDryLayout(childConstraints).height
                let childBaseline =
                    distance
                    + crossAxisAlignment.getChildCrossAxisOffset(freeCrossAxisSpace, flipCross)
                baselineOffset = baselineOffset.minOf(childBaseline)
                child = childAfter(currentChild)
            }
        }
        return baselineOffset.offset
    }

    /// Performs the actual layout of all children.
    ///
    /// This is the main layout method for RenderFlex:
    /// 1. Calls `_computeSizes` with `ChildLayoutHelper.layoutChild` and
    ///    `ChildLayoutHelper.getBaseline` to lay out children and compute sizes.
    /// 2. Sets the box's own size based on `mainAxisSize`.
    /// 3. Computes child positions along the main axis using `mainAxisAlignment`.
    /// 4. Computes child positions along the cross axis using `crossAxisAlignment`.
    /// 5. Handles `textDirection` and `verticalDirection` for RTL/bottom-up.
    /// 6. Tracks overflow on the main axis.
    ///
    /// **Dart Source:** flex.dart:1243-1340
    public override func performLayout() {
        let constraints = boxConstraints

        let sizes = _computeSizes(
            constraints: constraints,
            layoutChild: ChildLayoutHelper.layoutChild,
            getBaseline: ChildLayoutHelper.getBaseline
        )

        let crossAxisExtent = sizes.axisSize.crossAxisExtent
        size = sizes.axisSize.toSize(direction)
        _overflow = Swift.max(0.0, -sizes.mainAxisFreeSpace)

        let remainingSpace = Swift.max(0.0, sizes.mainAxisFreeSpace)
        let flipMain = _flipMainAxis
        let flipCross = _flipCrossAxis
        let (leadingSpace, betweenSpace) = mainAxisAlignment.distributeSpace(
            freeSpace: remainingSpace,
            itemCount: childCount,
            flipped: flipMain,
            spacing: spacing
        )
        let nextChild: FlexNextChild
        let topLeftChild: RenderBox?
        if flipMain {
            nextChild = childBefore
            topLeftChild = lastChild
        } else {
            nextChild = childAfter
            topLeftChild = firstChild
        }
        let baselineOffsetValue = sizes.baselineOffset

        // Position all children in visual order: starting from the top-left
        // child and working towards the child farthest from the origin.
        var childMainPosition = leadingSpace
        var child = topLeftChild
        while let currentChild = child {
            let childBaselineOffset: Double?
            let baselineAlign: Bool
            if baselineOffsetValue != nil {
                childBaselineOffset = currentChild.getDistanceToBaseline(
                    textBaseline!, onlyReal: true
                )
                baselineAlign = childBaselineOffset != nil
            } else {
                childBaselineOffset = nil
                baselineAlign = false
            }
            let childCrossPosition: Double
            if baselineAlign {
                childCrossPosition = baselineOffsetValue! - childBaselineOffset!
            } else {
                childCrossPosition = crossAxisAlignment.getChildCrossAxisOffset(
                    crossAxisExtent - _getCrossSize(currentChild.size),
                    flipCross
                )
            }
            let childParentData = currentChild.parentData! as! FlexParentData
            switch direction {
            case .horizontal:
                childParentData.offset = Offset(childMainPosition, childCrossPosition)
            case .vertical:
                childParentData.offset = Offset(childCrossPosition, childMainPosition)
            }
            childMainPosition += _getMainSize(currentChild.size) + betweenSpace
            child = nextChild(currentChild)
        }
    }

    // MARK: - Paint and Hit Testing

    /// A handle to the `ClipRectLayer` used for clip management during paint.
    ///
    /// **Dart Source:** flex.dart:1375
    private let _clipRectLayer: LayerHandle<ClipRectLayer> = LayerHandle<ClipRectLayer>()

    /// Paints this render object and its children.
    ///
    /// If no overflow, uses `defaultPaint`. If overflow with clip, uses
    /// `pushClipRect` with a `ClipRectLayer`. In debug mode, paints overflow
    /// indicators via `paintOverflowIndicator`.
    ///
    /// **Dart Source:** flex.dart:1314-1373
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        if !_hasOverflow {
            defaultPaint(context, offset)
            return
        }

        // There's no point in drawing the children if we're empty.
        if size.isEmpty {
            return
        }

        _clipRectLayer.layer = context.pushClipRect(
            needsCompositing,
            offset,
            Offset.zero & size,
            { context, offset in self.defaultPaint(context, offset) },
            clipBehavior: clipBehavior,
            oldLayer: _clipRectLayer.layer
        )

        // Debug: paint overflow indicators.
        // Simulate a child rect that overflows by the right amount. This child
        // rect is never used for drawing, just for determining the overflow
        // location and amount.
        let overflowChildRect: Rect
        switch _direction {
        case .horizontal:
            overflowChildRect = Rect.fromLTWH(0.0, 0.0, size.width + _overflow, 0.0)
        case .vertical:
            overflowChildRect = Rect.fromLTWH(0.0, 0.0, 0.0, size.height + _overflow)
        }
        paintOverflowIndicator(
            context,
            offset,
            Offset.zero & size,
            overflowChildRect
        )
    }

    /// Hit tests children using the default child hit-testing logic.
    ///
    /// **Dart Source:** flex.dart:1310-1312
    public override func hitTestChildren(
        _ result: BoxHitTestResult,
        position: Offset
    ) -> Bool {
        return defaultHitTestChildren(result, position: position)
    }

    /// Releases resources held by this render object.
    ///
    /// Clears the `_clipRectLayer` handle and calls super's dispose.
    ///
    /// **Dart Source:** flex.dart:1377-1381
    public override func dispose() {
        _clipRectLayer.layer = nil
        super.dispose()
    }

    // MARK: - Diagnostics

    /// Adds all flex properties to the diagnostics tree.
    ///
    /// **Dart Source:** flex.dart:1406-1419
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        // TODO: Call super.debugFillProperties(properties) once available on RenderBox.
        properties.add(
            DiagnosticsProperty<String>("direction", String(describing: direction))
        )
        properties.add(
            DiagnosticsProperty<String>(
                "mainAxisAlignment", String(describing: mainAxisAlignment)
            )
        )
        properties.add(
            DiagnosticsProperty<String>("mainAxisSize", String(describing: mainAxisSize))
        )
        properties.add(
            DiagnosticsProperty<String>(
                "crossAxisAlignment", String(describing: crossAxisAlignment)
            )
        )
        properties.add(
            DiagnosticsProperty<String>(
                "textDirection",
                String(describing: textDirection),
                defaultValue: nil
            )
        )
        properties.add(
            DiagnosticsProperty<String>(
                "verticalDirection",
                String(describing: verticalDirection),
                defaultValue: nil
            )
        )
        properties.add(
            DiagnosticsProperty<String>(
                "textBaseline",
                String(describing: textBaseline),
                defaultValue: nil
            )
        )
        properties.add(
            DoubleProperty("spacing", spacing, defaultValue: nil)
        )
    }
}

// MARK: - ContainerRenderObjectHost Conformance

extension RenderFlex: ContainerRenderObjectHost {
    /// Reorders a child that is already ours.
    ///
    /// Relinks in place rather than `remove`/`insert`: those drop and re-adopt,
    /// which clears the parent data (see `RenderObject.dropChild`) and would
    /// cost a reordered child its `Expanded`/`Flexible` flex and fit — the row
    /// would silently lay out as if every child were inflexible.
    ///
    /// **Dart Source:** `object.dart:4448-4460`
    public func move(_ child: RenderBox, after: RenderBox?) {
        guard let childParentData = child.parentData as? FlexParentData else { return }
        if childParentData.previousSibling === after { return }
        _removeFromChildList(child)
        _insertIntoChildList(child, after: after)
        markNeedsLayout()
    }
}
