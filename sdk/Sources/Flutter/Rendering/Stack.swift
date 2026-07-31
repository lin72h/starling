// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stack layout model types.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/stack.dart`

import FlutterSwiftBridge

// MARK: - RelativeRect

/// An immutable 2D, axis-aligned, floating-point rectangle whose coordinates
/// are given relative to another rectangle's edges, known as the container.
/// Since the dimensions of the rectangle are relative to those of the
/// container, this struct has no width and height members. To determine the
/// width or height of the rectangle, convert it to a `Rect` using `toRect()`
/// (passing the container's own Rect), and then examine that object.
///
/// **Dart Source:** `stack.dart:28-201`
public struct RelativeRect: Equatable, Hashable, CustomStringConvertible, Sendable {

    // MARK: - Properties

    /// Distance from the left side of the container to the left side of this
    /// rectangle.
    ///
    /// May be negative if the left side of the rectangle is outside of the
    /// container.
    ///
    /// **Dart Source:** `stack.dart:87`
    public let left: Double

    /// Distance from the top side of the container to the top side of this
    /// rectangle.
    ///
    /// May be negative if the top side of the rectangle is outside of the
    /// container.
    ///
    /// **Dart Source:** `stack.dart:91`
    public let top: Double

    /// Distance from the right side of the container to the right side of this
    /// rectangle.
    ///
    /// May be positive if the right side of the rectangle is outside of the
    /// container.
    ///
    /// **Dart Source:** `stack.dart:97`
    public let right: Double

    /// Distance from the bottom side of the container to the bottom side of this
    /// rectangle.
    ///
    /// May be positive if the bottom side of the rectangle is outside of the
    /// container.
    ///
    /// **Dart Source:** `stack.dart:102`
    public let bottom: Double

    // MARK: - Static Constants

    /// A rect that covers the entire container.
    ///
    /// **Dart Source:** `stack.dart:82`
    public static let fill = RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0)

    // MARK: - Factory Methods

    /// Creates a `RelativeRect` with the given values.
    ///
    /// **Dart Source:** `stack.dart:30`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide
    /// equivalent functionality.
    public static func fromLTRB(
        _ left: Double,
        _ top: Double,
        _ right: Double,
        _ bottom: Double
    ) -> RelativeRect {
        RelativeRect(left: left, top: top, right: right, bottom: bottom)
    }

    /// Creates a `RelativeRect` from a `Rect` and a `Size`. The `Rect` (first
    /// argument) and the `RelativeRect` (the output) are in the coordinate
    /// space of the rectangle described by the `Size`, with 0,0 being at the
    /// top left.
    ///
    /// **Dart Source:** `stack.dart:35-39`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide
    /// equivalent functionality.
    public static func fromSize(_ rect: Rect, _ container: Size) -> RelativeRect {
        RelativeRect(
            left: rect.left,
            top: rect.top,
            right: container.width - rect.right,
            bottom: container.height - rect.bottom
        )
    }

    /// Creates a `RelativeRect` from two `Rect`s. The second `Rect` provides
    /// the container, the first provides the rectangle, in the same coordinate
    /// space, that is to be converted to a `RelativeRect`. The output will be
    /// in the container's coordinate space.
    ///
    /// For example, if the top left of the rect is at 0,0, and the top left of
    /// the container is at 100,100, then the top left of the output will be at
    /// -100,-100.
    ///
    /// If the first rect is actually in the container's coordinate space, then
    /// use `RelativeRect.fromSize` and pass the container's size as the second
    /// argument instead.
    ///
    /// **Dart Source:** `stack.dart:53-57`
    ///
    /// DIFFERENCE FROM DART: Named constructor becomes static factory method.
    /// REASON: Swift doesn't have named constructors; static methods provide
    /// equivalent functionality.
    public static func fromRect(_ rect: Rect, _ container: Rect) -> RelativeRect {
        RelativeRect(
            left: rect.left - container.left,
            top: rect.top - container.top,
            right: container.right - rect.right,
            bottom: container.bottom - rect.bottom
        )
    }

    /// Creates a `RelativeRect` from horizontal position using `start` and
    /// `end` rather than `left` and `right`.
    ///
    /// If `textDirection` is `.rtl`, then the `start` argument is used for the
    /// `right` property and the `end` argument is used for the `left` property.
    /// Otherwise, if `textDirection` is `.ltr`, then the `start` argument is
    /// used for the `left` property and the `end` argument is used for the
    /// `right` property.
    ///
    /// **Dart Source:** `stack.dart:67-79`
    ///
    /// DIFFERENCE FROM DART: Factory constructor becomes static factory method.
    /// REASON: Swift doesn't have factory constructors; static methods provide
    /// equivalent functionality.
    public static func fromDirectional(
        textDirection: TextDirection,
        start: Double,
        top: Double,
        end: Double,
        bottom: Double
    ) -> RelativeRect {
        let (left, right): (Double, Double) = switch textDirection {
        case .rtl: (end, start)
        case .ltr: (start, end)
        }
        return RelativeRect.fromLTRB(left, top, right, bottom)
    }

    // MARK: - Computed Properties

    /// Returns whether any of the values are greater than zero.
    ///
    /// This corresponds to one of the sides (`left`, `top`, `right`, or
    /// `bottom`) having some positive inset towards the center.
    ///
    /// **Dart Source:** `stack.dart:108`
    public var hasInsets: Bool {
        left > 0.0 || top > 0.0 || right > 0.0 || bottom > 0.0
    }

    // MARK: - Methods

    /// Returns a new rectangle object translated by the given offset.
    ///
    /// **Dart Source:** `stack.dart:111-118`
    public func shift(_ offset: Offset) -> RelativeRect {
        RelativeRect.fromLTRB(
            left + offset.dx,
            top + offset.dy,
            right - offset.dx,
            bottom - offset.dy
        )
    }

    /// Returns a new rectangle with edges moved outwards by the given delta.
    ///
    /// **Dart Source:** `stack.dart:121-123`
    public func inflate(_ delta: Double) -> RelativeRect {
        RelativeRect.fromLTRB(left - delta, top - delta, right - delta, bottom - delta)
    }

    /// Returns a new rectangle with edges moved inwards by the given delta.
    ///
    /// **Dart Source:** `stack.dart:126-128`
    public func deflate(_ delta: Double) -> RelativeRect {
        inflate(-delta)
    }

    /// Returns a new rectangle that is the intersection of the given rectangle
    /// and this rectangle.
    ///
    /// **Dart Source:** `stack.dart:131-138`
    public func intersect(_ other: RelativeRect) -> RelativeRect {
        RelativeRect.fromLTRB(
            max(left, other.left),
            max(top, other.top),
            max(right, other.right),
            max(bottom, other.bottom)
        )
    }

    /// Convert this `RelativeRect` to a `Rect`, in the coordinate space of the
    /// container.
    ///
    /// See also:
    ///
    ///  * `toSize`, which returns the size part of the rect, based on the size
    ///    of the container.
    ///
    /// **Dart Source:** `stack.dart:146-148`
    public func toRect(_ container: Rect) -> Rect {
        Rect.fromLTRB(left, top, container.width - right, container.height - bottom)
    }

    /// Convert this `RelativeRect` to a `Size`, assuming a container with the
    /// given size.
    ///
    /// See also:
    ///
    ///  * `toRect`, which also computes the position relative to the container.
    ///
    /// **Dart Source:** `stack.dart:155-157`
    public func toSize(_ container: Size) -> Size {
        Size(container.width - left - right, container.height - top - bottom)
    }

    // MARK: - Static Methods

    /// Linearly interpolate between two `RelativeRect`s.
    ///
    /// If either rect is nil, this function interpolates from
    /// `RelativeRect.fill`.
    ///
    /// **Dart Source:** `stack.dart:164-181`
    public static func lerp(_ a: RelativeRect?, _ b: RelativeRect?, _ t: Double) -> RelativeRect? {
        if a == b {
            return a
        }
        if a == nil {
            return RelativeRect.fromLTRB(
                b!.left * t,
                b!.top * t,
                b!.right * t,
                b!.bottom * t
            )
        }
        if b == nil {
            let k = 1.0 - t
            return RelativeRect.fromLTRB(
                a!.left * k,
                a!.top * k,
                a!.right * k,
                a!.bottom * k
            )
        }
        return RelativeRect.fromLTRB(
            lerpDouble(a!.left, b!.left, t)!,
            lerpDouble(a!.top, b!.top, t)!,
            lerpDouble(a!.right, b!.right, t)!,
            lerpDouble(a!.bottom, b!.bottom, t)!
        )
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `stack.dart:199-200`
    public var description: String {
        "RelativeRect.fromLTRB(\(String(format: "%.1f", left)), \(String(format: "%.1f", top)), \(String(format: "%.1f", right)), \(String(format: "%.1f", bottom)))"
    }
}

// MARK: - StackParentData

/// Parent data for use with `RenderStack`.
///
/// Extends `ContainerBoxParentData<RenderBox>` with optional positioning
/// properties that determine how a child is laid out within a `Stack`.
///
/// **Dart Source:** `stack.dart:204-289`
public class StackParentData: ContainerBoxParentData<RenderBox> {

    /// The distance by which the child's top edge is inset from the top of the
    /// stack.
    ///
    /// **Dart Source:** `stack.dart:206`
    public var top: Double?

    /// The distance by which the child's right edge is inset from the right of
    /// the stack.
    ///
    /// **Dart Source:** `stack.dart:209`
    public var right: Double?

    /// The distance by which the child's bottom edge is inset from the bottom
    /// of the stack.
    ///
    /// **Dart Source:** `stack.dart:212`
    public var bottom: Double?

    /// The distance by which the child's left edge is inset from the left of
    /// the stack.
    ///
    /// **Dart Source:** `stack.dart:215`
    public var left: Double?

    /// The child's width.
    ///
    /// Ignored if both `left` and `right` are non-nil.
    ///
    /// **Dart Source:** `stack.dart:220`
    public var width: Double?

    /// The child's height.
    ///
    /// Ignored if both `top` and `bottom` are non-nil.
    ///
    /// **Dart Source:** `stack.dart:225`
    public var height: Double?

    /// Get or set the current values in terms of a `RelativeRect` object.
    ///
    /// **Dart Source:** `stack.dart:228-234`
    public var rect: RelativeRect {
        get {
            RelativeRect.fromLTRB(left!, top!, right!, bottom!)
        }
        set {
            top = newValue.top
            right = newValue.right
            bottom = newValue.bottom
            left = newValue.left
        }
    }

    /// Whether this child is considered positioned.
    ///
    /// A child is positioned if any of the `top`, `right`, `bottom`, or `left`
    /// properties are non-nil. Positioned children do not factor into
    /// determining the size of the stack but are instead placed relative to the
    /// non-positioned children in the stack.
    ///
    /// **Dart Source:** `stack.dart:242-248`
    public var isPositioned: Bool {
        top != nil
            || right != nil
            || bottom != nil
            || left != nil
            || width != nil
            || height != nil
    }

    /// Computes the `BoxConstraints` the stack layout algorithm would give to
    /// this child, given the `Size` of the stack.
    ///
    /// This method should only be called when `isPositioned` is true for the
    /// child.
    ///
    /// **Dart Source:** `stack.dart:254-271`
    public func positionedChildConstraints(_ stackSize: Size) -> BoxConstraints {
        assert(isPositioned)

        let resolvedWidth: Double? = switch (left, right) {
        case let (l?, r?): stackSize.width - r - l
        default: self.width
        }

        let resolvedHeight: Double? = switch (top, bottom) {
        case let (t?, b?): stackSize.height - b - t
        default: self.height
        }

        assert(resolvedHeight == nil || !resolvedHeight!.isNaN)
        assert(resolvedWidth == nil || !resolvedWidth!.isNaN)

        return BoxConstraints.tightFor(
            width: resolvedWidth == nil ? nil : max(0.0, resolvedWidth!),
            height: resolvedHeight == nil ? nil : max(0.0, resolvedHeight!)
        )
    }

    /// A description of this parent data, including position fields.
    ///
    /// **Dart Source:** `stack.dart:274-288`
    public override var description: String {
        var values: [String] = []
        if let top { values.append("top=\(debugFormatDouble(top))") }
        if let right { values.append("right=\(debugFormatDouble(right))") }
        if let bottom { values.append("bottom=\(debugFormatDouble(bottom))") }
        if let left { values.append("left=\(debugFormatDouble(left))") }
        if let width { values.append("width=\(debugFormatDouble(width))") }
        if let height { values.append("height=\(debugFormatDouble(height))") }
        if values.isEmpty {
            values.append("not positioned")
        }
        values.append(super.description)
        return values.joined(separator: "; ")
    }
}

// MARK: - StackFit

/// How to size the non-positioned children of a `Stack`.
///
/// This enum is used with `Stack.fit` and `RenderStack.fit` to control
/// how the `BoxConstraints` passed from the stack's parent to the stack's
/// child are adjusted.
///
/// **Dart Source:** `stack.dart:301-331`
public enum StackFit: Sendable {

    /// The constraints passed to the stack from its parent are loosened.
    ///
    /// For example, if the stack has constraints that force it to 350x600, then
    /// this would allow the non-positioned children of the stack to have any
    /// width from zero to 350 and any height from zero to 600.
    ///
    /// **Dart Source:** `stack.dart:314`
    case loose

    /// The constraints passed to the stack from its parent are tightened to the
    /// biggest size allowed.
    ///
    /// For example, if the stack has loose constraints with a width in the range
    /// 10 to 100 and a height in the range 0 to 600, then the non-positioned
    /// children of the stack would all be sized as 100 pixels wide and 600 high.
    ///
    /// **Dart Source:** `stack.dart:322`
    case expand

    /// The constraints passed to the stack from its parent are passed unmodified
    /// to the non-positioned children.
    ///
    /// For example, if a `Stack` is an `Expanded` child of a `Row`, the
    /// horizontal constraints will be tight and the vertical constraints will be
    /// loose.
    ///
    /// **Dart Source:** `stack.dart:330`
    case passthrough
}

// MARK: - RenderStack

/// A render object that lays out its children relative to the edges of its box.
///
/// In Dart, `RenderStack` extends `RenderBox` and mixes in
/// `ContainerRenderObjectMixin<RenderBox, StackParentData>` and
/// `RenderBoxContainerDefaultsMixin<RenderBox, StackParentData>`.
///
/// Since Swift does not support generic mixins, the container management
/// (linked-list child pointers) is implemented inline, and the class
/// conforms to `RenderBoxContainerDefaults` for default paint and
/// hit-testing behavior.
///
/// **Dart Source:** `stack.dart:369-759`
public class RenderStack: RenderBox, RenderBoxContainerDefaults {
    public typealias ChildType = RenderBox

    // MARK: - Container child management (ContainerRenderObjectMixin)

    /// The first child in the child list.
    ///
    /// **Dart Source:** `object.dart:4222 (ContainerRenderObjectMixin)`
    public private(set) var firstChild: RenderBox?

    /// The last child in the child list.
    ///
    /// **Dart Source:** `object.dart:4223 (ContainerRenderObjectMixin)`
    public private(set) var lastChild: RenderBox?

    /// The number of children.
    ///
    /// **Dart Source:** `object.dart:4226 (ContainerRenderObjectMixin)`
    public private(set) var childCount: Int = 0

    /// Returns the next sibling of the given child.
    ///
    /// **Dart Source:** `object.dart:4393 (ContainerRenderObjectMixin)`
    public func childAfter(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! StackParentData
        return parentData.nextSibling
    }

    /// Returns the previous sibling of the given child.
    ///
    /// **Dart Source:** `object.dart:4399 (ContainerRenderObjectMixin)`
    public func childBefore(_ child: RenderBox) -> RenderBox? {
        let parentData = child.parentData as! StackParentData
        return parentData.previousSibling
    }

    /// Inserts a child into the linked list.
    ///
    /// **Dart Source:** `object.dart:4234-4268 (ContainerRenderObjectMixin._insertIntoChildList)`
    private func _insertIntoChildList(_ child: RenderBox, after: RenderBox? = nil) {
        let childParentData = child.parentData as! StackParentData
        childCount += 1
        assert(childCount > 0)
        if let after = after {
            let afterParentData = after.parentData as! StackParentData
            if afterParentData.nextSibling == nil {
                // Inserting at the end — update lastChild
                childParentData.previousSibling = after
                afterParentData.nextSibling = child
                lastChild = child
            } else {
                // Inserting in the middle
                childParentData.nextSibling = afterParentData.nextSibling
                childParentData.previousSibling = after
                let nextParentData = afterParentData.nextSibling!.parentData as! StackParentData
                nextParentData.previousSibling = child
                afterParentData.nextSibling = child
            }
        } else {
            childParentData.nextSibling = firstChild
            if let first = firstChild {
                let firstParentData = first.parentData as! StackParentData
                firstParentData.previousSibling = child
            }
            firstChild = child
            lastChild = lastChild ?? child
        }
    }

    /// Removes a child from the linked list.
    ///
    /// **Dart Source:** `object.dart:4271-4295 (ContainerRenderObjectMixin._removeFromChildList)`
    private func _removeFromChildList(_ child: RenderBox) {
        let childParentData = child.parentData as! StackParentData
        if childParentData.previousSibling == nil {
            firstChild = childParentData.nextSibling
        } else {
            let previousParentData =
                childParentData.previousSibling!.parentData as! StackParentData
            previousParentData.nextSibling = childParentData.nextSibling
        }
        if childParentData.nextSibling == nil {
            lastChild = childParentData.previousSibling
        } else {
            let nextParentData =
                childParentData.nextSibling!.parentData as! StackParentData
            nextParentData.previousSibling = childParentData.previousSibling
        }
        childParentData.previousSibling = nil
        childParentData.nextSibling = nil
        childCount -= 1
    }

    /// Adds a child to the child list, optionally after the given child.
    ///
    /// **Dart Source:** `object.dart:4310-4323 (ContainerRenderObjectMixin.insert)`
    public func insert(_ child: RenderBox, after: RenderBox? = nil) {
        adoptChild(child)
        _insertIntoChildList(child, after: after)
    }

    /// Appends all the given children to the end of the child list.
    ///
    /// **Dart Source:** `object.dart:4325-4341 (ContainerRenderObjectMixin.addAll)`
    public func addAll(_ children: [RenderBox]?) {
        children?.forEach { insert($0, after: lastChild) }
    }

    /// Removes a child from the child list.
    ///
    /// **Dart Source:** `object.dart:4343-4353 (ContainerRenderObjectMixin.remove)`
    public func remove(_ child: RenderBox) {
        _removeFromChildList(child)
        dropChild(child)
    }

    // MARK: - Initializer

    /// Creates a stack render object.
    ///
    /// **Dart Source:** `stack.dart:369-381`
    public init(
        children: [RenderBox]? = nil,
        alignment: any AlignmentGeometry = AlignmentDirectional.topStart,
        textDirection: TextDirection? = nil,
        fit: StackFit = .loose,
        clipBehavior: Clip = .hardEdge
    ) {
        self._alignment = alignment
        self._textDirection = textDirection
        self._fit = fit
        self._clipBehavior = clipBehavior
        super.init()
        addAll(children)
    }

    // MARK: - Internal State

    /// Whether the stack has visual overflow (children that extend beyond
    /// the stack's bounds).
    ///
    /// **Dart Source:** `stack.dart:383`
    private var _hasVisualOverflow: Bool = false

    // MARK: - setupParentData

    /// Ensures the child has `StackParentData`.
    ///
    /// **Dart Source:** `stack.dart:386-390`
    public override func setupParentData(_ child: RenderObject) {
        if !(child.parentData is StackParentData) {
            child.parentData = StackParentData()
        }
    }

    // MARK: - Resolved Alignment

    /// Cached resolved alignment.
    ///
    /// **Dart Source:** `stack.dart:392`
    private var _resolvedAlignment: Alignment?

    /// Resolves the alignment using the current text direction.
    ///
    /// **Dart Source:** `stack.dart:394-397`
    private func _resolve() {
        if _resolvedAlignment != nil {
            return
        }
        _resolvedAlignment = _alignment.resolve(textDirection)
    }

    /// Clears the resolved alignment cache and marks the object as needing
    /// layout.
    ///
    /// **Dart Source:** `stack.dart:399-402`
    private func _markNeedResolution() {
        _resolvedAlignment = nil
        markNeedsLayout()
    }

    // MARK: - alignment

    /// How to align the non-positioned and partially-positioned children in
    /// the stack.
    ///
    /// **Dart Source:** `stack.dart:404-416`
    public var alignment: any AlignmentGeometry {
        get { _alignment }
        set {
            if _alignment._x == newValue._x
                && _alignment._start == newValue._start
                && _alignment._y == newValue._y
            {
                return
            }
            _alignment = newValue
            _markNeedResolution()
        }
    }

    /// Backing storage for `alignment`.
    ///
    /// **Dart Source:** `stack.dart:405`
    private var _alignment: any AlignmentGeometry

    // MARK: - textDirection

    /// The text direction with which to resolve `alignment`.
    ///
    /// This may be changed to nil, but only after the `alignment` has been
    /// changed to a value that does not depend on the direction.
    ///
    /// **Dart Source:** `stack.dart:418-429`
    public var textDirection: TextDirection? {
        get { _textDirection }
        set {
            if _textDirection == newValue {
                return
            }
            _textDirection = newValue
            _markNeedResolution()
        }
    }

    /// Backing storage for `textDirection`.
    ///
    /// **Dart Source:** `stack.dart:419`
    private var _textDirection: TextDirection?

    // MARK: - fit

    /// How to size the non-positioned children in the stack.
    ///
    /// **Dart Source:** `stack.dart:431-442`
    public var fit: StackFit {
        get { _fit }
        set {
            if _fit == newValue {
                return
            }
            _fit = newValue
            markNeedsLayout()
        }
    }

    /// Backing storage for `fit`.
    ///
    /// **Dart Source:** `stack.dart:432`
    private var _fit: StackFit

    // MARK: - clipBehavior

    /// Controls how to clip children of this stack.
    ///
    /// Defaults to `Clip.hardEdge`.
    ///
    /// **Dart Source:** `stack.dart:444-456`
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

    /// Backing storage for `clipBehavior`.
    ///
    /// **Dart Source:** `stack.dart:445`
    private var _clipBehavior: Clip

    // MARK: - Intrinsic Dimensions

    /// Returns the result of applying `mainChildSizeGetter` to the
    /// non-positioned children, returning the maximum value.
    ///
    /// **Dart Source:** `stack.dart:459-474`
    private static func _getIntrinsicDimension(
        _ firstChild: RenderBox?,
        _ childAfter: (RenderBox) -> RenderBox?,
        _ mainChildSizeGetter: (RenderBox) -> Double
    ) -> Double {
        var extent: Double = 0.0
        var child = firstChild
        while let currentChild = child {
            let childParentData = currentChild.parentData as! StackParentData
            if !childParentData.isPositioned {
                extent = max(extent, mainChildSizeGetter(currentChild))
            }
            child = childAfter(currentChild)
        }
        return extent
    }

    /// Computes the minimum intrinsic width for the given height.
    ///
    /// **Dart Source:** `stack.dart:477-479`
    public override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return RenderStack._getIntrinsicDimension(firstChild, { self.childAfter($0) }) { child in
            child.getMinIntrinsicWidth(height)
        }
    }

    /// Computes the maximum intrinsic width for the given height.
    ///
    /// **Dart Source:** `stack.dart:482-484`
    public override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return RenderStack._getIntrinsicDimension(firstChild, { self.childAfter($0) }) { child in
            child.getMaxIntrinsicWidth(height)
        }
    }

    /// Computes the minimum intrinsic height for the given width.
    ///
    /// **Dart Source:** `stack.dart:487-489`
    public override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return RenderStack._getIntrinsicDimension(firstChild, { self.childAfter($0) }) { child in
            child.getMinIntrinsicHeight(width)
        }
    }

    /// Computes the maximum intrinsic height for the given width.
    ///
    /// **Dart Source:** `stack.dart:492-494`
    public override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return RenderStack._getIntrinsicDimension(firstChild, { self.childAfter($0) }) { child in
            child.getMaxIntrinsicHeight(width)
        }
    }

    // MARK: - Baseline

    /// Computes the distance to the actual baseline by delegating to
    /// `defaultComputeDistanceToHighestActualBaseline`.
    ///
    /// **Dart Source:** `stack.dart:497-500`
    public override func computeDistanceToActualBaseline(
        _ baseline: TextBaseline
    ) -> Double? {
        return defaultComputeDistanceToHighestActualBaseline(baseline)
    }

    // MARK: - Layout Positioned Child

    /// Lays out a positioned child and returns whether it overflows the stack.
    ///
    /// This method positions a child that has at least one non-nil positioning
    /// property (top, right, bottom, left, width, height). It applies the
    /// constraints derived from the positioning properties, lays out the child,
    /// and then determines the child's offset within the stack.
    ///
    /// **Dart Source:** `stack.dart:502-546`
    public static func layoutPositionedChild(
        _ child: RenderBox,
        _ parentData: StackParentData,
        _ size: Size,
        _ alignment: Alignment
    ) -> Bool {
        assert(parentData.isPositioned)
        var hasVisualOverflow = false
        var childConstraints = BoxConstraints()

        if parentData.left != nil && parentData.right != nil {
            childConstraints = childConstraints.tighten(
                width: size.width - parentData.right! - parentData.left!
            )
        } else if parentData.width != nil {
            childConstraints = childConstraints.tighten(width: parentData.width)
        }

        if parentData.top != nil && parentData.bottom != nil {
            childConstraints = childConstraints.tighten(
                height: size.height - parentData.bottom! - parentData.top!
            )
        } else if parentData.height != nil {
            childConstraints = childConstraints.tighten(height: parentData.height)
        }

        child.layout(childConstraints, parentUsesSize: true)

        let x: Double
        if parentData.left != nil {
            x = parentData.left!
        } else if parentData.right != nil {
            x = size.width - parentData.right! - child.size.width
        } else {
            x = alignment.alongOffset(Offset(size.width - child.size.width, size.height - child.size.height)).dx
        }

        if x < 0.0 || x + child.size.width > size.width {
            hasVisualOverflow = true
        }

        let y: Double
        if parentData.top != nil {
            y = parentData.top!
        } else if parentData.bottom != nil {
            y = size.height - parentData.bottom! - child.size.height
        } else {
            y = alignment.alongOffset(Offset(size.width - child.size.width, size.height - child.size.height)).dy
        }

        if y < 0.0 || y + child.size.height > size.height {
            hasVisualOverflow = true
        }

        parentData.offset = Offset(x, y)

        return hasVisualOverflow
    }

    // MARK: - Size Computation

    /// Computes the size of the stack from the given constraints and a
    /// child-sizing function.
    ///
    /// This method iterates over non-positioned children, lays them out using
    /// the provided `layoutChild` closure, and computes the size of the stack
    /// based on the largest non-positioned child and the constraints.
    ///
    /// **Dart Source:** `stack.dart:549-605`
    private func _computeSize(
        constraints: BoxConstraints,
        layoutChild: ChildLayouter
    ) -> Size {
        _resolve()
        assert(_resolvedAlignment != nil)

        var hasNonPositionedChildren = false
        if childCount == 0 {
            return constraints.biggest.width.isFinite && constraints.biggest.height.isFinite
                ? constraints.biggest
                : constraints.smallest
        }

        var width = constraints.minWidth
        var height = constraints.minHeight

        let nonPositionedConstraints: BoxConstraints
        switch fit {
        case .loose:
            nonPositionedConstraints = constraints.loosen()
        case .expand:
            nonPositionedConstraints = BoxConstraints.tight(constraints.biggest)
        case .passthrough:
            nonPositionedConstraints = constraints
        }

        var child = firstChild
        while let currentChild = child {
            let childParentData = currentChild.parentData as! StackParentData
            if !childParentData.isPositioned {
                hasNonPositionedChildren = true
                let childSize = layoutChild(currentChild, nonPositionedConstraints)
                width = max(width, childSize.width)
                height = max(height, childSize.height)
            }
            child = childAfter(currentChild)
        }

        let computedSize: Size
        if hasNonPositionedChildren {
            computedSize = Size(width, height)
            assert(computedSize.width == constraints.constrainWidth(width))
            assert(computedSize.height == constraints.constrainHeight(height))
        } else {
            computedSize = constraints.biggest.width.isFinite && constraints.biggest.height.isFinite
                ? constraints.biggest
                : constraints.smallest
        }

        assert(computedSize.isFinite)
        return computedSize
    }

    // MARK: - Dry Layout

    /// Computes the dry layout size for the given constraints.
    ///
    /// **Dart Source:** `stack.dart:608-610`
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return _computeSize(
            constraints: constraints,
            layoutChild: ChildLayoutHelper.dryLayoutChild
        )
    }

    // MARK: - performLayout

    /// Performs layout by computing the size from non-positioned children, then
    /// positioning all children.
    ///
    /// Non-positioned children are aligned using the resolved alignment.
    /// Positioned children are laid out using `layoutPositionedChild`.
    ///
    /// **Dart Source:** `stack.dart:613-651`
    public override func performLayout() {
        let constraints = boxConstraints
        _hasVisualOverflow = false

        size = _computeSize(
            constraints: constraints,
            layoutChild: ChildLayoutHelper.layoutChild
        )

        assert(_resolvedAlignment != nil)
        let resolvedAlignment = _resolvedAlignment!

        var child = firstChild
        while let currentChild = child {
            let childParentData = currentChild.parentData as! StackParentData

            if !childParentData.isPositioned {
                childParentData.offset = resolvedAlignment.alongOffset(
                    Offset(size.width - currentChild.size.width, size.height - currentChild.size.height)
                )
            } else {
                _hasVisualOverflow = RenderStack.layoutPositionedChild(
                    currentChild, childParentData, size, resolvedAlignment
                ) || _hasVisualOverflow
            }

            assert(currentChild.parentData === childParentData)
            child = childAfter(currentChild)
        }
    }

    // MARK: - Hit Testing

    /// Hit tests children by delegating to `defaultHitTestChildren`.
    ///
    /// **Dart Source:** `stack.dart:654-657`
    public override func hitTestChildren(
        _ result: BoxHitTestResult,
        position: Offset
    ) -> Bool {
        return defaultHitTestChildren(result, position: position)
    }

    // MARK: - Painting

    /// Paints the stack's children.
    ///
    /// Subclasses may override this method to customize how children are
    /// painted. The default implementation delegates to `defaultPaint`.
    ///
    /// **Dart Source:** `stack.dart:662-664`
    open func paintStack(_ context: PaintingContext, _ offset: Offset) {
        defaultPaint(context, offset)
    }

    /// The clip rect layer handle used for clipping overflow.
    ///
    /// **Dart Source:** `stack.dart:750`
    private let _clipRectLayer = LayerHandle<ClipRectLayer>()

    /// Paints this render object and its children, clipping if there is
    /// visual overflow.
    ///
    /// **Dart Source:** `stack.dart:667-694`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        if clipBehavior != .none && _hasVisualOverflow {
            _clipRectLayer.layer = context.pushClipRect(
                needsCompositing,
                offset,
                Offset.zero & size,
                paintStack,
                clipBehavior: clipBehavior,
                oldLayer: _clipRectLayer.layer
            )
        } else {
            _clipRectLayer.layer = nil
            paintStack(context, offset)
        }
    }

    // MARK: - dispose

    /// Releases resources held by this render object.
    ///
    /// Clears the `_clipRectLayer` handle and calls super's dispose.
    ///
    /// **Dart Source:** `stack.dart:753-758`
    public override func dispose() {
        _clipRectLayer.layer = nil
        super.dispose()
    }
}

// MARK: - RenderIndexedStack

/// Implements the same layout algorithm as RenderStack but only paints the child
/// specified by `index`.
///
/// Although only one child is displayed, the cost of the layout algorithm is
/// still O(N), like an ordinary stack.
///
/// **Dart Source:** `stack.dart:766-897`
public class RenderIndexedStack: RenderStack {

    // MARK: - Initializer

    /// Creates an indexed stack render object.
    ///
    /// **Dart Source:** `stack.dart:767-775`
    public init(
        children: [RenderBox]? = nil,
        alignment: any AlignmentGeometry = AlignmentDirectional.topStart,
        textDirection: TextDirection? = nil,
        fit: StackFit = .loose,
        clipBehavior: Clip = .hardEdge,
        index: Int? = 0
    ) {
        self._index = index
        super.init(
            children: children,
            alignment: alignment,
            textDirection: textDirection,
            fit: fit,
            clipBehavior: clipBehavior
        )
    }

    // MARK: - Semantics

    /// Visits only the displayed child for semantics purposes.
    ///
    /// **Dart Source:** `stack.dart:779-782`
    public func visitChildrenForSemantics(_ visitor: RenderObjectVisitor) {
        let displayedChild = _childAtIndex()
        if let displayedChild {
            visitor(displayedChild)
        }
    }

    // MARK: - Index Property

    /// The index of the child to show, or nil to show nothing.
    ///
    /// **Dart Source:** `stack.dart:784-790`
    public var index: Int? {
        get { _index }
        set {
            if _index != newValue {
                _index = newValue
                markNeedsLayout()
            }
        }
    }

    /// Backing storage for `index`.
    private var _index: Int?

    // MARK: - Child At Index

    /// Returns the child at the current `index`, or nil if `index` is nil
    /// or there are no children.
    ///
    /// **Dart Source:** `stack.dart:792-802`
    private func _childAtIndex() -> RenderBox? {
        guard let index else {
            return nil
        }
        var child = firstChild
        for _ in 0..<index {
            guard let current = child else { break }
            child = childAfter(current)
        }
        assert(firstChild == nil || child != nil)
        return child
    }

    // MARK: - Baseline

    /// Computes the distance to the actual baseline using only the displayed
    /// child.
    ///
    /// **Dart Source:** `stack.dart:805-812`
    public override func computeDistanceToActualBaseline(
        _ baseline: TextBaseline
    ) -> Double? {
        let displayedChild = _childAtIndex()
        guard let displayedChild else {
            return nil
        }
        let childParentData = displayedChild.parentData as! StackParentData
        let offset =
            BaselineOffset(displayedChild.getDistanceToActualBaseline(baseline))
            + childParentData.offset.dy
        return offset.offset
    }

    // MARK: - Hit Testing

    /// Hit tests only the displayed child.
    ///
    /// **Dart Source:** `stack.dart:815-826`
    public override func hitTestChildren(
        _ result: BoxHitTestResult,
        position: Offset
    ) -> Bool {
        let displayedChild = _childAtIndex()
        guard let displayedChild else {
            return false
        }
        let childParentData = displayedChild.parentData as! StackParentData
        return result.addWithPaintOffset(
            offset: childParentData.offset,
            position: position,
            hitTest: { (result: BoxHitTestResult, transformed: Offset) -> Bool in
                return displayedChild.hitTest(result, position: transformed)
            }
        )
    }

    // MARK: - Painting

    /// Paints only the displayed child.
    ///
    /// **Dart Source:** `stack.dart:829-834`
    public override func paintStack(_ context: PaintingContext, _ offset: Offset) {
        let displayedChild = _childAtIndex()
        guard let displayedChild else {
            return
        }
        let childParentData = displayedChild.parentData as! StackParentData
        context.paintChild(displayedChild, childParentData.offset + offset)
    }
}

// MARK: - ContainerRenderObjectHost Conformance

extension RenderStack: ContainerRenderObjectHost {
    /// Reorders a child that is already ours.
    ///
    /// Relinks the child in place. It must NOT go through `remove`/`insert`:
    /// those drop and re-adopt, `dropChild` clears the parent data, and
    /// `setupParentData` then hands back a blank `StackParentData` — so a
    /// reordered child would silently lose its `Positioned`
    /// top/left/bottom/right and be laid out as an unpositioned child, aligned
    /// instead of placed. Nothing would restore it: parent data is re-applied
    /// by `attachRenderObject`, which a move does not call. Reordering is
    /// routine — any stack whose children list changes shape between builds.
    ///
    /// **Dart Source:** `object.dart:4448-4460`
    public func move(_ child: RenderBox, after: RenderBox?) {
        guard let childParentData = child.parentData as? StackParentData else { return }
        if childParentData.previousSibling === after { return }
        _removeFromChildList(child)
        _insertIntoChildList(child, after: after)
        markNeedsLayout()
    }
}
