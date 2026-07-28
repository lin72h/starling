// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Implicitly animated widgets that automatically transition between values.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/implicit_animations.dart`

import FlutterSwiftBridge

// MARK: - Tween Subclasses

/// An interpolation between two `Decoration` values.
///
/// **Dart Source:** `implicit_animations.dart:37-47`
public class DecorationTween: Tween<(any Decoration)?> {
    public override init(
        begin: (any Decoration)?? = nil,
        end: (any Decoration)?? = nil
    ) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    public override func lerp(_ t: Double) -> (any Decoration)? {
        return lerpDecoration(begin!, end!, t)
    }
}

/// An interpolation between two `EdgeInsetsGeometry` values.
///
/// **Dart Source:** `implicit_animations.dart:56-66`
public class EdgeInsetsGeometryTween: Tween<(any EdgeInsetsGeometry)?> {
    public override init(
        begin: (any EdgeInsetsGeometry)?? = nil,
        end: (any EdgeInsetsGeometry)?? = nil
    ) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    public override func lerp(_ t: Double) -> (any EdgeInsetsGeometry)? {
        return EdgeInsetsGeometryStatics.lerp(begin!, end!, t)
    }
}

/// An interpolation between two `BoxConstraints` values.
///
/// **Dart Source:** `implicit_animations.dart:99-109`
public class BoxConstraintsTween: Tween<BoxConstraints?> {
    public override init(begin: BoxConstraints?? = nil, end: BoxConstraints?? = nil) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    public override func lerp(_ t: Double) -> BoxConstraints? {
        return BoxConstraints.lerp(begin!, end!, t)
    }
}

// MARK: - ImplicitlyAnimatedWidget

/// An abstract class for building widgets that animate changes to their
/// properties.
///
/// Subclasses' states must extend `ImplicitlyAnimatedWidgetState` and manage
/// tweens directly (rather than using Dart's `forEachTween` visitor pattern,
/// which relies on dynamic typing).
///
/// **Dart Source:** `implicit_animations.dart:120-141`
public class ImplicitlyAnimatedWidget: StatefulWidget {
    /// The duration over which to animate the parameters of this container.
    public let duration: Duration

    /// The curve to apply when animating the parameters of this container.
    public let curve: any Curve

    /// Called every time an animation completes.
    public let onEnd: VoidCallback?

    public init(
        key: (any Key)? = nil,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil
    ) {
        self.curve = curve
        self.duration = duration
        self.onEnd = onEnd
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        fatalError("Subclasses of ImplicitlyAnimatedWidget must override createState()")
    }
}

// MARK: - ImplicitlyAnimatedWidgetState

/// Base state for `ImplicitlyAnimatedWidget` subclasses.
///
/// Manages an `AnimationController` and `CurvedAnimation`. Subclasses override
/// `initTweens()` and `updateTweens()` to manage their specific tweens.
///
/// **Dart Source:** `implicit_animations.dart:166-291`
public class ImplicitlyAnimatedWidgetState: State<StatefulWidget>, TickerProvider {

    private var _controller: AnimationController!
    private var _curvedAnimation: CurvedAnimation!

    /// The animation driven by the implicit animation controller.
    /// Subclasses evaluate their tweens against this animation.
    public var animation: Animation<Double> { _curvedAnimation }

    private var implicitWidget: ImplicitlyAnimatedWidget {
        return widget as! ImplicitlyAnimatedWidget
    }

    // MARK: - TickerProvider

    public func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    // MARK: - Lifecycle

    public override func initState() {
        super.initState()
        _controller = AnimationController(
            duration: implicitWidget.duration,
            vsync: self
        )
        _curvedAnimation = CurvedAnimation(
            parent: _controller,
            curve: implicitWidget.curve
        )
        _controller.addStatusListener { [weak self] status in
            guard let self = self else { return }
            if status == .completed {
                self.implicitWidget.onEnd?()
            }
        }
        initTweens()
    }

    public override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        _controller.duration = implicitWidget.duration
        // Always recreate CurvedAnimation when widget updates, since Curve is
        // a protocol type and identity comparison isn't reliable.
        _curvedAnimation = CurvedAnimation(
            parent: _controller,
            curve: implicitWidget.curve
        )

        let changed = updateTweens()
        if changed {
            _controller.value = 0.0
            _controller.forward()
        }
    }

    public override func dispose() {
        _controller.dispose()
        super.dispose()
    }

    // MARK: - Subclass Hooks

    /// Called once from `initState` to set up initial tween begin/end values.
    /// Subclasses should create tweens with begin=end=currentWidgetValue.
    open func initTweens() {}

    /// Called from `didUpdateWidget` to update tween begin (from current animated
    /// value) and end (from new widget properties). Return `true` if any tween
    /// changed, which triggers the animation to run.
    open func updateTweens() -> Bool { return false }
}

// MARK: - AnimatedWidgetBaseState

/// A variant of `ImplicitlyAnimatedWidgetState` that automatically calls
/// `setState` on every animation tick, forcing a rebuild each frame.
///
/// Most implicitly animated widgets use this so their `build()` method can
/// evaluate tweens at the current animation value.
///
/// **Dart Source:** `implicit_animations.dart:300-320`
public class AnimatedWidgetBaseState: ImplicitlyAnimatedWidgetState {
    public override func initState() {
        super.initState()
        (animation as! CurvedAnimation).parent.addListener { [weak self] in
            guard let self = self, self.mounted else { return }
            self.setState {}
        }
    }
}

// MARK: - AnimatedContainer

/// A container that gradually changes its values over a period of time.
///
/// The `AnimatedContainer` will automatically animate between the old and new
/// values of properties when they change using the provided curve and duration.
///
/// **Dart Source:** `implicit_animations.dart:471-525`
public class AnimatedContainer: ImplicitlyAnimatedWidget {
    public let alignment: (any AlignmentGeometry)?
    public let padding: (any EdgeInsetsGeometry)?
    public let decoration: (any Decoration)?
    public let foregroundDecoration: (any Decoration)?
    public let constraints: BoxConstraints?
    public let margin: (any EdgeInsetsGeometry)?
    public let child: Widget?
    public let clipBehavior: Clip

    public init(
        key: (any Key)? = nil,
        alignment: (any AlignmentGeometry)? = nil,
        padding: (any EdgeInsetsGeometry)? = nil,
        color: Color? = nil,
        decoration: (any Decoration)? = nil,
        foregroundDecoration: (any Decoration)? = nil,
        width: Double? = nil,
        height: Double? = nil,
        constraints: BoxConstraints? = nil,
        margin: (any EdgeInsetsGeometry)? = nil,
        curve: any Curve = Curves.linear,
        duration: Duration,
        onEnd: VoidCallback? = nil,
        clipBehavior: Clip = .none,
        child: Widget? = nil
    ) {
        assert(
            color == nil || decoration == nil,
            "Cannot provide both a color and a decoration. "
            + "To provide both, use \"decoration: BoxDecoration(color: color)\"."
        )

        // Fold color into decoration
        var resolvedDecoration = decoration
        if let color = color {
            resolvedDecoration = BoxDecoration(color: color)
        }

        // Fold width/height into constraints
        var resolvedConstraints = constraints
        if width != nil || height != nil {
            resolvedConstraints = (constraints ?? BoxConstraints()).tighten(
                width: width, height: height
            )
        }

        self.alignment = alignment
        self.padding = padding
        self.decoration = resolvedDecoration
        self.foregroundDecoration = foregroundDecoration
        self.constraints = resolvedConstraints
        self.margin = margin
        self.child = child
        self.clipBehavior = clipBehavior
        super.init(key: key, curve: curve, duration: duration, onEnd: onEnd)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedContainerState()
    }
}

// MARK: - _AnimatedContainerState

/// **Dart Source:** `implicit_animations.dart:527-591`
class _AnimatedContainerState: AnimatedWidgetBaseState {

    private var _alignment: AlignmentGeometryTween?
    private var _padding: EdgeInsetsGeometryTween?
    private var _decoration: DecorationTween?
    private var _foregroundDecoration: DecorationTween?
    private var _constraints: BoxConstraintsTween?
    private var _margin: EdgeInsetsGeometryTween?

    private var containerWidget: AnimatedContainer {
        return widget as! AnimatedContainer
    }

    // MARK: - Tween Management

    override func initTweens() {
        if let alignment = containerWidget.alignment {
            _alignment = AlignmentGeometryTween(begin: alignment, end: alignment)
        }
        if let padding = containerWidget.padding {
            _padding = EdgeInsetsGeometryTween(begin: padding, end: padding)
        }
        if let decoration = containerWidget.decoration {
            _decoration = DecorationTween(begin: decoration, end: decoration)
        }
        if let foregroundDecoration = containerWidget.foregroundDecoration {
            _foregroundDecoration = DecorationTween(begin: foregroundDecoration, end: foregroundDecoration)
        }
        if let constraints = containerWidget.constraints {
            _constraints = BoxConstraintsTween(begin: constraints, end: constraints)
        }
        if let margin = containerWidget.margin {
            _margin = EdgeInsetsGeometryTween(begin: margin, end: margin)
        }
    }

    override func updateTweens() -> Bool {
        var changed = false

        // Alignment — end is (any AlignmentGeometry)?? so flatten with ?? nil
        if let newAlignment = containerWidget.alignment {
            if _alignment == nil {
                _alignment = AlignmentGeometryTween(begin: newAlignment, end: newAlignment)
                changed = true
            } else if !alignmentGeometryEqual(_alignment!.end ?? nil, newAlignment) {
                _alignment!.begin = _alignment!.evaluate(animation)
                _alignment!.end = newAlignment
                changed = true
            }
        } else if _alignment != nil {
            _alignment = nil
            changed = true
        }

        // Padding
        if let newPadding = containerWidget.padding {
            if _padding == nil {
                _padding = EdgeInsetsGeometryTween(begin: newPadding, end: newPadding)
                changed = true
            } else if !edgeInsetsGeometryEqual(_padding!.end ?? nil, newPadding) {
                _padding!.begin = _padding!.evaluate(animation)
                _padding!.end = newPadding
                changed = true
            }
        } else if _padding != nil {
            _padding = nil
            changed = true
        }

        // Decoration
        if let newDecoration = containerWidget.decoration {
            if _decoration == nil {
                _decoration = DecorationTween(begin: newDecoration, end: newDecoration)
                changed = true
            } else if !decorationEqual(_decoration!.end ?? nil, newDecoration) {
                _decoration!.begin = _decoration!.evaluate(animation)
                _decoration!.end = newDecoration
                changed = true
            }
        } else if _decoration != nil {
            _decoration = nil
            changed = true
        }

        // Foreground Decoration
        if let newFgDeco = containerWidget.foregroundDecoration {
            if _foregroundDecoration == nil {
                _foregroundDecoration = DecorationTween(begin: newFgDeco, end: newFgDeco)
                changed = true
            } else if !decorationEqual(_foregroundDecoration!.end ?? nil, newFgDeco) {
                _foregroundDecoration!.begin = _foregroundDecoration!.evaluate(animation)
                _foregroundDecoration!.end = newFgDeco
                changed = true
            }
        } else if _foregroundDecoration != nil {
            _foregroundDecoration = nil
            changed = true
        }

        // Constraints
        if let newConstraints = containerWidget.constraints {
            if _constraints == nil {
                _constraints = BoxConstraintsTween(begin: newConstraints, end: newConstraints)
                changed = true
            } else if (_constraints!.end ?? nil) != newConstraints {
                _constraints!.begin = _constraints!.evaluate(animation)
                _constraints!.end = newConstraints
                changed = true
            }
        } else if _constraints != nil {
            _constraints = nil
            changed = true
        }

        // Margin
        if let newMargin = containerWidget.margin {
            if _margin == nil {
                _margin = EdgeInsetsGeometryTween(begin: newMargin, end: newMargin)
                changed = true
            } else if !edgeInsetsGeometryEqual(_margin!.end ?? nil, newMargin) {
                _margin!.begin = _margin!.evaluate(animation)
                _margin!.end = newMargin
                changed = true
            }
        } else if _margin != nil {
            _margin = nil
            changed = true
        }

        return changed
    }

    // MARK: - Build

    // Build order matches Dart's Container.build():
    // child → Align → Padding → DecoratedBox(bg) → DecoratedBox(fg) → ConstrainedBox → Padding(margin)
    override func build(_ context: any BuildContext) -> Widget {
        var current: Widget? = containerWidget.child

        if let alignment = _alignment?.evaluate(animation) {
            current = Align(alignment: alignment, child: current)
        }

        if let padding = _padding?.evaluate(animation) {
            current = Padding(padding: padding, child: current)
        }

        if let decoration = _decoration?.evaluate(animation) {
            current = DecoratedBox(decoration: decoration, child: current)
        }

        if let foregroundDecoration = _foregroundDecoration?.evaluate(animation) {
            current = DecoratedBox(
                decoration: foregroundDecoration,
                position: .foreground,
                child: current
            )
        }

        if let constraints = _constraints?.evaluate(animation) {
            current = ConstrainedBox(constraints: constraints, child: current)
        }

        if let margin = _margin?.evaluate(animation) {
            current = Padding(padding: margin, child: current)
        }

        // If nothing was applied but we still have a child, return it directly
        return current ?? SizedBox(width: 0, height: 0)
    }
}

// MARK: - Helpers

/// Compare two optional `Decoration` values for equality.
private func decorationEqual(_ a: (any Decoration)?, _ b: (any Decoration)?) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    // Both are BoxDecoration — compare structurally
    if let aBox = a as? BoxDecoration, let bBox = b as? BoxDecoration {
        return aBox == bBox
    }
    return a === b
}

/// Compare two optional `AlignmentGeometry` values for equality.
private func alignmentGeometryEqual(
    _ a: (any AlignmentGeometry)?,
    _ b: (any AlignmentGeometry)?
) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    return a == b
}

/// Compare two optional `EdgeInsetsGeometry` values for equality.
private func edgeInsetsGeometryEqual(
    _ a: (any EdgeInsetsGeometry)?,
    _ b: (any EdgeInsetsGeometry)?
) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    if let aEI = a as? EdgeInsets, let bEI = b as? EdgeInsets {
        return aEI == bEI
    }
    if let aEID = a as? EdgeInsetsDirectional, let bEID = b as? EdgeInsetsDirectional {
        return aEID == bEID
    }
    return false
}
