// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Animated transition widgets that rebuild when an animation changes.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/transitions.dart`

import FlutterSwiftBridge

// MARK: - Animation: Listenable conformance

/// `Animation<T>` already implements `addListener`/`removeListener` but does
/// not declare `Listenable` conformance. This extension bridges that gap so
/// that `AnimatedWidget` can store an `Animation` as `any Listenable`.
extension Animation: Listenable {}

// MARK: - AnimatedWidget

/// A widget that rebuilds when the given `Listenable` changes value.
///
/// Subclasses override `build(_:)` to produce a widget tree that depends
/// on the current value of the `listenable`.
///
/// **Dart Source:** `transitions.dart:83-139`
public class AnimatedWidget: StatefulWidget {
    /// The `Listenable` to which this widget is listening.
    ///
    /// Stored as `AnyObject` because `Listenable` is not class-constrained,
    /// but all concrete implementations are classes.
    internal let _listenable: AnyObject

    /// Returns the listenable as the `Listenable` protocol type.
    public var listenable: any Listenable {
        _listenable as! any Listenable
    }

    public init(
        key: (any Key)? = nil,
        listenable: any Listenable
    ) {
        self._listenable = listenable as AnyObject
        super.init(key: key)
    }

    /// Override this method to build the widget tree.
    ///
    /// The framework calls this method when the `listenable` notifies.
    open func build(_ context: any BuildContext) -> Widget {
        fatalError("AnimatedWidget subclasses must override build(_:)")
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedWidgetState()
    }
}

/// Internal state that listens to the `AnimatedWidget.listenable` and
/// triggers rebuilds.
///
/// **Dart Source:** `transitions.dart:141-167`
private class _AnimatedWidgetState: State<StatefulWidget> {
    override func initState() {
        super.initState()
        (widget as! AnimatedWidget).listenable.addListener(_handleChange)
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let oldAnimated = oldWidget as! AnimatedWidget
        let newAnimated = widget as! AnimatedWidget
        // Always swap listeners — identity check not possible on existentials
        oldAnimated.listenable.removeListener(_handleChange)
        newAnimated.listenable.addListener(_handleChange)
    }

    override func dispose() {
        (widget as! AnimatedWidget).listenable.removeListener(_handleChange)
        super.dispose()
    }

    private func _handleChange() {
        setState {}
    }

    override func build(_ context: any BuildContext) -> Widget {
        return (widget as! AnimatedWidget).build(context)
    }
}

// MARK: - AnimatedBuilder

/// A general-purpose `AnimatedWidget` that uses a builder callback.
///
/// **Dart Source:** `transitions.dart:219-268`
public class AnimatedBuilder: AnimatedWidget {
    /// The builder callback invoked on every animation tick.
    public let builder: (any BuildContext, Widget?) -> Widget

    /// An optional child widget that does not depend on the animation.
    ///
    /// Passing a pre-built child avoids rebuilding it on every tick.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        animation: any Listenable,
        builder: @escaping (any BuildContext, Widget?) -> Widget,
        child: Widget? = nil
    ) {
        self.builder = builder
        self.child = child
        super.init(key: key, listenable: animation)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        return builder(context, child)
    }
}

// MARK: - SlideTransition

/// Animates the position of a widget relative to its normal position.
///
/// The translation is expressed as an `Offset` scaled to the child's size.
/// For example, an `Offset` with a `dx` of 0.25 will result in a horizontal
/// translation of one quarter the width of the child.
///
/// **Dart Source:** `transitions.dart:326-395`
public class SlideTransition: AnimatedWidget {
    /// The animation that controls the position of the child.
    public var position: Animation<Offset> {
        _listenable as! Animation<Offset>
    }

    /// Whether to apply the translation when hit testing.
    public let transformHitTests: Bool

    /// The widget below this widget in the tree.
    public let child: Widget?

    /// The axis-aligned text direction for resolving directional offsets.
    public let textDirection: TextDirection?

    public init(
        key: (any Key)? = nil,
        position: Animation<Offset>,
        transformHitTests: Bool = true,
        textDirection: TextDirection? = nil,
        child: Widget? = nil
    ) {
        self.transformHitTests = transformHitTests
        self.textDirection = textDirection
        self.child = child
        super.init(key: key, listenable: position)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        return FractionalTranslation(
            translation: position.value,
            transformHitTests: transformHitTests,
            child: child
        )
    }
}

// MARK: - ScaleTransition

/// Animates the scale of a transformed widget.
///
/// **Dart Source:** `transitions.dart:400-463`
public class ScaleTransition: AnimatedWidget {
    /// The animation that controls the scale of the child.
    public var scale: Animation<Double> {
        _listenable as! Animation<Double>
    }

    /// The alignment of the origin of the coordinate system in which the scale
    /// takes place, relative to the size of the box.
    public let alignment: any AlignmentGeometry

    /// The widget below this widget in the tree.
    public let child: Widget?

    /// The filter quality to use when applying the scale.
    public let filterQuality: FilterQuality?

    public init(
        key: (any Key)? = nil,
        scale: Animation<Double>,
        alignment: any AlignmentGeometry = Alignment.center,
        filterQuality: FilterQuality? = nil,
        child: Widget? = nil
    ) {
        self.alignment = alignment
        self.filterQuality = filterQuality
        self.child = child
        super.init(key: key, listenable: scale)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let scaleValue = scale.value
        return Transform(
            scale: scaleValue,
            alignment: alignment,
            filterQuality: filterQuality,
            child: child
        )
    }
}

// MARK: - RotationTransition

/// Animates the rotation of a widget.
///
/// The `turns` animation value is in turns (1.0 = 360 degrees).
///
/// **Dart Source:** `transitions.dart:468-530`
public class RotationTransition: AnimatedWidget {
    /// The animation that controls the rotation of the child.
    ///
    /// The value is in turns (1.0 = 360 degrees).
    public var turns: Animation<Double> {
        _listenable as! Animation<Double>
    }

    /// The alignment of the origin of the coordinate system around which
    /// the rotation occurs.
    public let alignment: any AlignmentGeometry

    /// The widget below this widget in the tree.
    public let child: Widget?

    /// The filter quality to use when painting.
    public let filterQuality: FilterQuality?

    public init(
        key: (any Key)? = nil,
        turns: Animation<Double>,
        alignment: any AlignmentGeometry = Alignment.center,
        filterQuality: FilterQuality? = nil,
        child: Widget? = nil
    ) {
        self.alignment = alignment
        self.filterQuality = filterQuality
        self.child = child
        super.init(key: key, listenable: turns)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let turnsValue = turns.value
        let angle = turnsValue * 2.0 * Double.pi
        return Transform(
            rotate: angle,
            alignment: alignment,
            filterQuality: filterQuality,
            child: child
        )
    }
}

// MARK: - SizeTransition

/// Animates its own size and clips and aligns the child.
///
/// `SizeTransition` acts as a `ClipRect` that animates either its width or its
/// height, depending upon the value of `axis`. The alignment of the child
/// along the `axis` is specified by the `axisAlignment`.
///
/// **Dart Source:** `transitions.dart:538-621`
public class SizeTransition: AnimatedWidget {
    /// The animation that controls the (clipped) size of the child.
    ///
    /// The value is clamped to 0.0-1.0 range.
    public var sizeFactor: Animation<Double> {
        _listenable as! Animation<Double>
    }

    /// The axis along which to vary the child's size.
    public let axis: Axis

    /// Describes how to align the child along the axis that `sizeFactor` is
    /// modifying.
    ///
    /// A value of -1.0 indicates the top when `axis` is `Axis.vertical`, and
    /// the start when `axis` is `Axis.horizontal`. The start is on the left
    /// when the text direction in effect is `TextDirection.ltr` and on the
    /// right when it is `TextDirection.rtl`.
    ///
    /// A value of 1.0 indicates the bottom or end.
    ///
    /// A value of 0.0 (the default) indicates the center.
    public let axisAlignment: Double

    /// A factor for how much of the cross axis of the child should be used.
    ///
    /// If nil, the cross axis is unconstrained.
    public let fixedCrossAxisSizeFactor: Double?

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        axis: Axis = .vertical,
        sizeFactor: Animation<Double>,
        axisAlignment: Double = 0.0,
        fixedCrossAxisSizeFactor: Double? = nil,
        child: Widget? = nil
    ) {
        self.axis = axis
        self.axisAlignment = axisAlignment
        self.fixedCrossAxisSizeFactor = fixedCrossAxisSizeFactor
        self.child = child
        super.init(key: key, listenable: sizeFactor)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let alignmentValue: any AlignmentGeometry
        if axis == .vertical {
            alignmentValue = AlignmentDirectional(0.0, axisAlignment)
        } else {
            alignmentValue = AlignmentDirectional(axisAlignment, 0.0)
        }
        return ClipRect(
            child: Align(
                alignment: alignmentValue,
                widthFactor: axis == .horizontal
                    ? max(sizeFactor.value, 0.0)
                    : fixedCrossAxisSizeFactor,
                heightFactor: axis == .vertical
                    ? max(sizeFactor.value, 0.0)
                    : fixedCrossAxisSizeFactor,
                child: child
            )
        )
    }
}

// MARK: - FadeTransition

/// Animates the opacity of a widget.
///
/// Uses the existing `RenderAnimatedOpacity` from `ProxyBox.swift`.
///
/// **Dart Source:** `transitions.dart:625-688`
public class FadeTransition: SingleChildRenderObjectWidget {
    /// The animation that controls the opacity of the child.
    public let opacity: Animation<Double>

    /// Whether to always include the child in the semantics tree, even when
    /// the opacity is zero.
    public let alwaysIncludeSemantics: Bool

    public init(
        key: (any Key)? = nil,
        opacity: Animation<Double>,
        alwaysIncludeSemantics: Bool = false,
        child: Widget? = nil
    ) {
        self.opacity = opacity
        self.alwaysIncludeSemantics = alwaysIncludeSemantics
        super.init(key: key, child: child)
    }

    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderAnimatedOpacity(
            opacity: opacity,
            alwaysIncludeSemantics: alwaysIncludeSemantics
        )
    }

    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderAnimatedOpacity
        ro.opacity = opacity
        ro.alwaysIncludeSemantics = alwaysIncludeSemantics
    }
}

// MARK: - DecoratedBoxTransition

/// Animates the different properties of a `DecoratedBox`.
///
/// **Dart Source:** `transitions.dart:696-733`
public class DecoratedBoxTransition: AnimatedWidget {
    /// The animation of the decoration to paint.
    public var decoration: Animation<any Decoration> {
        _listenable as! Animation<any Decoration>
    }

    /// Whether to paint the decoration behind or in front of the child.
    public let position: DecorationPosition

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        decoration: Animation<any Decoration>,
        position: DecorationPosition = .background,
        child: Widget? = nil
    ) {
        self.position = position
        self.child = child
        super.init(key: key, listenable: decoration)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        return DecoratedBox(
            decoration: decoration.value,
            position: position,
            child: child
        )
    }
}

// MARK: - AlignTransition

/// Animated version of `Align` which automatically transitions the
/// child's position over a given duration whenever the given alignment changes.
///
/// **Dart Source:** `transitions.dart:802-852`
public class AlignTransition: AnimatedWidget {
    /// The animation that controls the child's alignment.
    public var alignment: Animation<any AlignmentGeometry> {
        _listenable as! Animation<any AlignmentGeometry>
    }

    /// An optional factor for the child's width. Null means unconstrained.
    public let widthFactor: Double?

    /// An optional factor for the child's height. Null means unconstrained.
    public let heightFactor: Double?

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        alignment: Animation<any AlignmentGeometry>,
        widthFactor: Double? = nil,
        heightFactor: Double? = nil,
        child: Widget? = nil
    ) {
        self.widthFactor = widthFactor
        self.heightFactor = heightFactor
        self.child = child
        super.init(key: key, listenable: alignment)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        return Align(
            alignment: alignment.value,
            widthFactor: widthFactor,
            heightFactor: heightFactor,
            child: child
        )
    }
}

// MARK: - AnimatedOpacity

/// Animates the opacity of a widget implicitly.
///
/// When the `opacity` changes, this widget automatically animates to the new
/// value over the given `duration`.
///
/// **Dart Source:** `implicit_animations.dart:933-988`
public class AnimatedOpacity: ImplicitlyAnimatedWidget {
    /// The target opacity.
    public let opacity: Double

    /// The widget below this widget in the tree.
    public let child: Widget?

    /// Whether to always include the child in the semantics tree.
    public let alwaysIncludeSemantics: Bool

    public init(
        key: (any Key)? = nil,
        opacity: Double,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil,
        alwaysIncludeSemantics: Bool = false,
        child: Widget? = nil
    ) {
        assert(opacity >= 0.0 && opacity <= 1.0)
        self.opacity = opacity
        self.alwaysIncludeSemantics = alwaysIncludeSemantics
        self.child = child
        super.init(key: key, curve: curve, duration: duration, onEnd: onEnd)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedOpacityState()
    }
}

private class _AnimatedOpacityState: AnimatedWidgetBaseState {
    private var _opacityTween: Tween<Double>?

    private var opacityWidget: AnimatedOpacity {
        widget as! AnimatedOpacity
    }

    override func initTweens() {
        _opacityTween = Tween<Double>(begin: opacityWidget.opacity, end: opacityWidget.opacity)
    }

    override func updateTweens() -> Bool {
        let newOpacity = opacityWidget.opacity
        if _opacityTween!.end != newOpacity {
            _opacityTween!.begin = _opacityTween!.evaluate(animation)
            _opacityTween!.end = newOpacity
            return true
        }
        return false
    }

    override func build(_ context: any BuildContext) -> Widget {
        return Opacity(
            opacity: _opacityTween!.evaluate(animation),
            alwaysIncludeSemantics: opacityWidget.alwaysIncludeSemantics,
            child: opacityWidget.child
        )
    }
}

// MARK: - AnimatedScale

/// Implicitly animates a scale transform.
///
/// **Dart Source:** `implicit_animations.dart:1068-1116`
public class AnimatedScale: ImplicitlyAnimatedWidget {
    /// The target scale factor.
    public let scale: Double

    /// The alignment of the origin of the coordinate system in which the scale
    /// takes place.
    public let alignment: any AlignmentGeometry

    /// The filter quality to use when applying the scale.
    public let filterQuality: FilterQuality?

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        scale: Double,
        alignment: any AlignmentGeometry = Alignment.center,
        filterQuality: FilterQuality? = nil,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil,
        child: Widget? = nil
    ) {
        self.scale = scale
        self.alignment = alignment
        self.filterQuality = filterQuality
        self.child = child
        super.init(key: key, curve: curve, duration: duration, onEnd: onEnd)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedScaleState()
    }
}

private class _AnimatedScaleState: AnimatedWidgetBaseState {
    private var _scaleTween: Tween<Double>?

    private var scaleWidget: AnimatedScale {
        widget as! AnimatedScale
    }

    override func initTweens() {
        _scaleTween = Tween<Double>(begin: scaleWidget.scale, end: scaleWidget.scale)
    }

    override func updateTweens() -> Bool {
        let newScale = scaleWidget.scale
        if _scaleTween!.end != newScale {
            _scaleTween!.begin = _scaleTween!.evaluate(animation)
            _scaleTween!.end = newScale
            return true
        }
        return false
    }

    override func build(_ context: any BuildContext) -> Widget {
        return Transform(
            scale: _scaleTween!.evaluate(animation),
            alignment: scaleWidget.alignment,
            filterQuality: scaleWidget.filterQuality,
            child: scaleWidget.child
        )
    }
}

// MARK: - AnimatedRotation

/// Implicitly animates a rotation transform.
///
/// The `turns` value is in turns (1.0 = 360 degrees).
///
/// **Dart Source:** `implicit_animations.dart:1118-1166`
public class AnimatedRotation: ImplicitlyAnimatedWidget {
    /// The target rotation, in turns (1.0 = 360 degrees).
    public let turns: Double

    /// The alignment of the origin of the coordinate system around which
    /// the rotation occurs.
    public let alignment: any AlignmentGeometry

    /// The filter quality to use when painting.
    public let filterQuality: FilterQuality?

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        turns: Double,
        alignment: any AlignmentGeometry = Alignment.center,
        filterQuality: FilterQuality? = nil,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil,
        child: Widget? = nil
    ) {
        self.turns = turns
        self.alignment = alignment
        self.filterQuality = filterQuality
        self.child = child
        super.init(key: key, curve: curve, duration: duration, onEnd: onEnd)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedRotationState()
    }
}

private class _AnimatedRotationState: AnimatedWidgetBaseState {
    private var _turnsTween: Tween<Double>?

    private var rotationWidget: AnimatedRotation {
        widget as! AnimatedRotation
    }

    override func initTweens() {
        _turnsTween = Tween<Double>(begin: rotationWidget.turns, end: rotationWidget.turns)
    }

    override func updateTweens() -> Bool {
        let newTurns = rotationWidget.turns
        if _turnsTween!.end != newTurns {
            _turnsTween!.begin = _turnsTween!.evaluate(animation)
            _turnsTween!.end = newTurns
            return true
        }
        return false
    }

    override func build(_ context: any BuildContext) -> Widget {
        let turnsVal = _turnsTween!.evaluate(animation)
        let angle = turnsVal * 2.0 * Double.pi
        return Transform(
            rotate: angle,
            alignment: rotationWidget.alignment,
            filterQuality: rotationWidget.filterQuality,
            child: rotationWidget.child
        )
    }
}

// MARK: - AnimatedSlide

/// Implicitly animates a fractional translation.
///
/// **Dart Source:** `implicit_animations.dart:1168-1216`
public class AnimatedSlide: ImplicitlyAnimatedWidget {
    /// The target translation offset.
    public let offset: Offset

    /// The widget below this widget in the tree.
    public let child: Widget?

    public init(
        key: (any Key)? = nil,
        offset: Offset,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil,
        child: Widget? = nil
    ) {
        self.offset = offset
        self.child = child
        super.init(key: key, curve: curve, duration: duration, onEnd: onEnd)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedSlideState()
    }
}

private class _AnimatedSlideState: AnimatedWidgetBaseState {
    private var _offsetTween: Tween<Offset>?

    private var slideWidget: AnimatedSlide {
        widget as! AnimatedSlide
    }

    override func initTweens() {
        _offsetTween = Tween<Offset>(begin: slideWidget.offset, end: slideWidget.offset)
    }

    override func updateTweens() -> Bool {
        let newOffset = slideWidget.offset
        if _offsetTween!.end != newOffset {
            _offsetTween!.begin = _offsetTween!.evaluate(animation)
            _offsetTween!.end = newOffset
            return true
        }
        return false
    }

    override func build(_ context: any BuildContext) -> Widget {
        return FractionalTranslation(
            translation: _offsetTween!.evaluate(animation),
            child: slideWidget.child
        )
    }
}

// MARK: - AnimatedSwitcher

/// A widget that by default does a cross-fade between a new widget and the
/// widget previously set on the AnimatedSwitcher as a child.
///
/// This is a simplified version — full AnimatedSwitcher with custom transitions
/// requires more infrastructure (GlobalKey-based child swapping). This version
/// provides basic fade transitions between children.
///
/// **Dart Source:** `animated_switcher.dart:25-260`
public class AnimatedSwitcher: StatefulWidget {
    /// The current child widget to display.
    public let child: Widget?

    /// The duration of the crossfade animation.
    public let duration: Duration

    /// The duration of the reverse crossfade animation.
    public let reverseDuration: Duration?

    /// The animation curve to use.
    public let switchInCurve: any Curve

    /// The animation curve to use for the outgoing widget.
    public let switchOutCurve: any Curve

    public init(
        key: (any Key)? = nil,
        child: Widget? = nil,
        duration: Duration,
        reverseDuration: Duration? = nil,
        switchInCurve: any Curve = Curves.linear,
        switchOutCurve: any Curve = Curves.linear
    ) {
        self.child = child
        self.duration = duration
        self.reverseDuration = reverseDuration
        self.switchInCurve = switchInCurve
        self.switchOutCurve = switchOutCurve
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedSwitcherState()
    }
}

private class _AnimatedSwitcherState: State<StatefulWidget>, TickerProvider {
    private var _controller: AnimationController?
    private var _animation: CurvedAnimation?
    private var _currentChild: Widget?

    private var switcherWidget: AnimatedSwitcher {
        widget as! AnimatedSwitcher
    }

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    override func initState() {
        super.initState()
        _currentChild = switcherWidget.child
        _controller = AnimationController(
            duration: switcherWidget.duration,
            reverseDuration: switcherWidget.reverseDuration,
            vsync: self
        )
        _animation = CurvedAnimation(
            parent: _controller!,
            curve: switcherWidget.switchInCurve
        )
        // Start fully visible
        _controller!.value = 1.0
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let oldSwitcher = oldWidget as! AnimatedSwitcher
        _controller!.duration = switcherWidget.duration
        _controller!.reverseDuration = switcherWidget.reverseDuration
        _animation = CurvedAnimation(
            parent: _controller!,
            curve: switcherWidget.switchInCurve
        )

        // Check if child changed (by key or type)
        let oldChild = oldSwitcher.child
        let newChild = switcherWidget.child
        let childChanged: Bool
        if let oldC = oldChild, let newC = newChild {
            childChanged = !Widget.canUpdate(oldC, newC)
        } else {
            childChanged = (oldChild == nil) != (newChild == nil)
        }

        if childChanged {
            _currentChild = newChild
            _controller!.value = 0.0
            _controller!.forward()
            _controller!.addListener { [weak self] in
                self?.setState {}
            }
        }
    }

    override func dispose() {
        _controller?.dispose()
        super.dispose()
    }

    override func build(_ context: any BuildContext) -> Widget {
        let opacityVal = _animation?.value ?? 1.0
        if let child = _currentChild {
            return Opacity(
                opacity: opacityVal,
                child: child
            )
        }
        return SizedBox(width: 0, height: 0)
    }
}
