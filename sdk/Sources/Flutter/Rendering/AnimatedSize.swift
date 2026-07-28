// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A render object that animates its size to its child's size over a given
/// duration and with a given curve.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/animated_size.dart`

import FlutterSwiftBridge

// MARK: - RenderAnimatedSizeState

/// A `RenderAnimatedSize` can be in exactly one of these states.
///
/// The state machine drives the animation behavior:
/// - `start` -> `stable`: initial layout, record child size
/// - `stable` -> `changed`: child size changed, begin animation
/// - `changed` -> `stable`: child size stabilized, continue animation
/// - `changed` -> `unstable`: child size changed again, track directly
/// - `unstable` -> `stable`: child size stabilized, stop tracking
///
/// **Dart Source:** `animated_size.dart:15-51`
@_spi(Testing)
public enum RenderAnimatedSizeState: Sendable {
    /// The initial state, when we do not yet know what the starting and target
    /// sizes are to animate.
    ///
    /// The next state is `stable`.
    ///
    /// **Dart Source:** `animated_size.dart:20`
    case start

    /// At this state the child's size is assumed to be stable and we are either
    /// animating, or waiting for the child's size to change.
    ///
    /// If the child's size changes, the state will become `changed`. Otherwise,
    /// it remains `stable`.
    ///
    /// **Dart Source:** `animated_size.dart:27`
    case stable

    /// At this state we know that the child has changed once after being assumed
    /// `stable`.
    ///
    /// The next state will be one of:
    ///
    /// * `stable` if the child's size stabilized immediately. This is a signal
    ///   for the render object to begin animating the size towards the child's new
    ///   size.
    ///
    /// * `unstable` if the child's size continues to change.
    ///
    /// **Dart Source:** `animated_size.dart:39`
    case changed

    /// At this state the child's size is assumed to be unstable (changing each
    /// frame).
    ///
    /// Instead of chasing the child's size in this state, the render object
    /// tightly tracks the child's size until it stabilizes.
    ///
    /// The render object remains in this state until a frame where the child's
    /// size remains the same as the previous frame. At that time, the next state
    /// is `stable`.
    ///
    /// **Dart Source:** `animated_size.dart:50`
    case unstable
}

// MARK: - RenderAnimatedSize

/// A render object that animates its size to its child's size over a given
/// `duration` and with a given `curve`. If the child's size itself animates
/// (i.e. if it changes size two frames in a row, as opposed to abruptly
/// changing size in one frame then remaining that size in subsequent frames),
/// this render object sizes itself to fit the child instead of animating
/// itself.
///
/// When the child overflows the current animated size of this render object, it
/// is clipped.
///
/// **Dart Source:** `animated_size.dart:62-412`
open class RenderAnimatedSize: RenderAligningShiftedBox {

    // MARK: - Initializer

    /// Creates a render object that animates its size to match its child.
    /// The `duration` and `curve` arguments define the animation.
    ///
    /// The `alignment` argument is used to align the child when the parent is not
    /// (yet) the same size as the child.
    ///
    /// The `duration` is required.
    ///
    /// The `vsync` should specify a `TickerProvider` for the animation
    /// controller.
    ///
    /// **Dart Source:** `animated_size.dart:76-97`
    public init(
        vsync: TickerProvider,
        duration: Duration,
        reverseDuration: Duration? = nil,
        curve: any Curve = Curves.linear,
        alignment: any AlignmentGeometry = Alignment.center,
        textDirection: TextDirection? = nil,
        child: RenderBox? = nil,
        clipBehavior: Clip = .hardEdge,
        onEnd: VoidCallback? = nil
    ) {
        _vsync = vsync
        _clipBehavior = clipBehavior
        _onEnd = onEnd
        _controller = AnimationController(
            duration: duration,
            reverseDuration: reverseDuration,
            vsync: vsync
        )
        _animation = CurvedAnimation(parent: _controller, curve: curve)
        super.init(alignment: alignment, textDirection: textDirection, child: child)

        _controller.addListener { [weak self] in
            guard let self = self else { return }
            if self._controller.value != self._lastValue {
                self.markNeedsLayout()
            }
        }
    }

    // MARK: - Internal State

    /// The animation controller that drives the resizing.
    ///
    /// **Dart Source:** `animated_size.dart:132`
    private let _controller: AnimationController

    /// The curved animation that applies the curve to the controller.
    ///
    /// **Dart Source:** `animated_size.dart:133`
    private let _animation: CurvedAnimation

    /// The size tween used to interpolate between the begin and end sizes.
    ///
    /// **Dart Source:** `animated_size.dart:135`
    private let _sizeTween = SizeTween()

    /// Whether the current animated size is smaller than the target size,
    /// causing visual overflow.
    ///
    /// **Dart Source:** `animated_size.dart:136`
    private var _hasVisualOverflow: Bool = false

    /// The last recorded animation controller value.
    ///
    /// **Dart Source:** `animated_size.dart:137`
    private var _lastValue: Double?

    /// The current size after layout (including animation).
    ///
    /// **Dart Source:** `animated_size.dart:243`
    private var _currentSize: Size = .zero

    // MARK: - Debug Accessors

    /// When asserts are enabled, returns the animation controller that is used
    /// to drive the resizing.
    ///
    /// Otherwise, returns nil.
    ///
    /// This getter is intended for use in framework unit tests. Applications must
    /// not depend on its value.
    ///
    /// **Dart Source:** `animated_size.dart:107-114`
    @_spi(Testing)
    public var debugController: AnimationController? {
        var controller: AnimationController?
        assert({
            controller = _controller
            return true
        }())
        return controller
    }

    /// When asserts are enabled, returns the animation that drives the resizing.
    ///
    /// Otherwise, returns nil.
    ///
    /// This getter is intended for use in framework unit tests. Applications must
    /// not depend on its value.
    ///
    /// **Dart Source:** `animated_size.dart:123-130`
    @_spi(Testing)
    public var debugAnimation: CurvedAnimation? {
        var animation: CurvedAnimation?
        assert({
            animation = _animation
            return true
        }())
        return animation
    }

    // MARK: - State

    /// The state this size animation is in.
    ///
    /// See `RenderAnimatedSizeState` for possible states.
    ///
    /// **Dart Source:** `animated_size.dart:142-144`
    @_spi(Testing)
    public var state: RenderAnimatedSizeState { _state }
    private var _state: RenderAnimatedSizeState = .start

    // MARK: - Properties

    /// The duration of the animation.
    ///
    /// **Dart Source:** `animated_size.dart:147-153`
    public var duration: Duration {
        get { _controller.duration! }
        set {
            if newValue == _controller.duration {
                return
            }
            _controller.duration = newValue
        }
    }

    /// The duration of the animation when running in reverse.
    ///
    /// **Dart Source:** `animated_size.dart:156-162`
    public var reverseDuration: Duration? {
        get { _controller.reverseDuration }
        set {
            if newValue == _controller.reverseDuration {
                return
            }
            _controller.reverseDuration = newValue
        }
    }

    /// The curve of the animation.
    ///
    /// **Dart Source:** `animated_size.dart:165-171`
    public var curve: any Curve {
        get { _animation.curve }
        set {
            // Curve is a protocol, so we cannot use == for comparison.
            // Always set the value, matching the Dart behavior when the curve
            // type changes.
            _animation.curve = newValue
        }
    }

    /// Controls how to clip the child when the animated size is smaller than
    /// the child's size.
    ///
    /// Defaults to `Clip.hardEdge`.
    ///
    /// **Dart Source:** `animated_size.dart:176-184`
    public var clipBehavior: Clip {
        get { _clipBehavior }
        set {
            if newValue != _clipBehavior {
                _clipBehavior = newValue
                markNeedsPaint()
                // markNeedsSemanticsUpdate() is not available on RenderObject
                // in the current stub. Will be called once semantics is migrated.
            }
        }
    }
    private var _clipBehavior: Clip = .hardEdge

    /// Whether the size is being currently animated towards the child's size.
    ///
    /// See `RenderAnimatedSizeState` for situations when we may not be animating
    /// the size.
    ///
    /// **Dart Source:** `animated_size.dart:190`
    public var isAnimating: Bool { _controller.isAnimating }

    /// The `TickerProvider` for the `AnimationController` that runs the animation.
    ///
    /// **Dart Source:** `animated_size.dart:193-201`
    public var vsync: TickerProvider {
        get { _vsync }
        set {
            _vsync = newValue
            _controller.resync(newValue)
        }
    }
    private var _vsync: TickerProvider

    /// Called every time an animation completes.
    ///
    /// This can be useful to trigger additional actions (e.g. another animation)
    /// at the end of the current animation.
    ///
    /// **Dart Source:** `animated_size.dart:207-214`
    public var onEnd: VoidCallback? {
        get { _onEnd }
        set {
            _onEnd = newValue
        }
    }
    private var _onEnd: VoidCallback?

    // MARK: - Attach / Detach

    /// Called when the render object is attached to a pipeline owner.
    ///
    /// Resumes interrupted animations and adds the status listener.
    ///
    /// **Dart Source:** `animated_size.dart:216-229`
    public override func attach(_ owner: PipelineOwner) {
        super.attach(owner)
        switch state {
        case .start, .stable:
            break
        case .changed, .unstable:
            // Call markNeedsLayout in case the RenderObject isn't marked dirty
            // already, to resume interrupted resizing animation.
            markNeedsLayout()
        }
        _controller.addStatusListener(_animationStatusListener)
    }

    /// Called when the render object is detached from its pipeline owner.
    ///
    /// Stops the animation controller and removes the status listener.
    ///
    /// **Dart Source:** `animated_size.dart:232-237`
    public override func detach() {
        _controller.stop()
        _controller.removeStatusListener(_animationStatusListener)
        super.detach()
    }

    // MARK: - Animated Size

    /// The current animated size, computed by evaluating the size tween at
    /// the current animation value.
    ///
    /// **Dart Source:** `animated_size.dart:239-241`
    private var _animatedSize: Size? {
        return _sizeTween.evaluate(_animation)
    }

    // MARK: - Layout

    /// Computes the layout for this render object.
    ///
    /// This method implements a state machine that determines how to respond
    /// to child size changes:
    /// - In `start` state, records the initial child size.
    /// - In `stable` state, animates to new sizes when the child changes.
    /// - In `changed` state, checks if the child has stabilized.
    /// - In `unstable` state, tracks the child size directly.
    ///
    /// **Dart Source:** `animated_size.dart:246-277`
    public override func performLayout() {
        _lastValue = _controller.value
        _hasVisualOverflow = false
        let constraints = self.boxConstraints
        if child == nil || constraints.isTight {
            _controller.stop()
            size = constraints.smallest
            _currentSize = constraints.smallest
            _sizeTween.begin = constraints.smallest
            _sizeTween.end = constraints.smallest
            _state = .start
            child?.layout(constraints)
            return
        }

        child!.layout(constraints, parentUsesSize: true)

        switch _state {
        case .start:
            _layoutStart()
        case .stable:
            _layoutStable()
        case .changed:
            _layoutChanged()
        case .unstable:
            _layoutUnstable()
        }

        size = constraints.constrain(_animatedSize!)
        _currentSize = size
        alignChild()

        if size.width < _sizeTween.end!!.width || size.height < _sizeTween.end!!.height {
            _hasVisualOverflow = true
        }
    }

    /// Computes the dry layout size without side effects.
    ///
    /// This simplified version of `performLayout` only calculates the current
    /// size without modifying global state.
    ///
    /// **Dart Source:** `animated_size.dart:280-307`
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        if child == nil || constraints.isTight {
            return constraints.smallest
        }

        let childSize = child!.getDryLayout(constraints)
        switch _state {
        case .start:
            return constraints.constrain(childSize)
        case .stable:
            if _sizeTween.end != childSize {
                return constraints.constrain(_currentSize)
            } else if _controller.value == _controller.upperBound {
                return constraints.constrain(childSize)
            }
        case .unstable, .changed:
            if _sizeTween.end != childSize {
                return constraints.constrain(childSize)
            }
        }

        return constraints.constrain(_animatedSize!)
    }

    // MARK: - Animation Helpers

    /// Restarts the animation from the beginning.
    ///
    /// **Dart Source:** `animated_size.dart:309-312`
    private func _restartAnimation() {
        _lastValue = 0.0
        _controller.forward(from: 0.0)
    }

    /// Laying out the child for the first time.
    ///
    /// We have the initial size to animate from, but we do not have the target
    /// size to animate to, so we set both ends to child's size.
    ///
    /// **Dart Source:** `animated_size.dart:318-321`
    private func _layoutStart() {
        _sizeTween.begin = child!.size
        _sizeTween.end = child!.size
        _state = .stable
    }

    /// At this state we're assuming the child size is stable and letting the
    /// animation run its course.
    ///
    /// If during animation the size of the child changes we restart the
    /// animation.
    ///
    /// **Dart Source:** `animated_size.dart:328-339`
    private func _layoutStable() {
        if _sizeTween.end != child!.size {
            _sizeTween.begin = size
            _sizeTween.end = child!.size
            _restartAnimation()
            _state = .changed
        } else if _controller.value == _controller.upperBound {
            // Animation finished. Reset target sizes.
            _sizeTween.begin = child!.size
            _sizeTween.end = child!.size
        } else if !_controller.isAnimating {
            _controller.forward() // resume the animation after being detached
        }
    }

    /// This state indicates that the size of the child changed once after being
    /// considered stable.
    ///
    /// If the child stabilizes immediately, we go back to stable state. If it
    /// changes again, we match the child's size, restart animation and go to
    /// unstable state.
    ///
    /// **Dart Source:** `animated_size.dart:348-361`
    private func _layoutChanged() {
        if _sizeTween.end != child!.size {
            // Child size changed again. Match the child's size and restart animation.
            _sizeTween.begin = child!.size
            _sizeTween.end = child!.size
            _restartAnimation()
            _state = .unstable
        } else {
            // Child size stabilized.
            _state = .stable
            if !_controller.isAnimating {
                // Resume the animation after being detached.
                _controller.forward()
            }
        }
    }

    /// The child's size is not stable.
    ///
    /// Continue tracking the child's size until it stabilizes.
    ///
    /// **Dart Source:** `animated_size.dart:367-377`
    private func _layoutUnstable() {
        if _sizeTween.end != child!.size {
            // Still unstable. Continue tracking the child.
            _sizeTween.begin = child!.size
            _sizeTween.end = child!.size
            _restartAnimation()
        } else {
            // Child size stabilized.
            _controller.stop()
            _state = .stable
        }
    }

    // MARK: - Animation Status Listener

    /// Listener called when the animation status changes.
    ///
    /// When the animation completes, calls the `onEnd` callback if set.
    ///
    /// **Dart Source:** `animated_size.dart:379-383`
    private func _animationStatusListener(_ status: AnimationStatus) {
        if status.isCompleted {
            _onEnd?()
        }
    }

    // MARK: - Painting

    /// Paints this render object and its child.
    ///
    /// If the child overflows the current animated size and `clipBehavior` is
    /// not `Clip.none`, the child is clipped to the current size using a
    /// `ClipRectLayer`.
    ///
    /// **Dart Source:** `animated_size.dart:385-401`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        if child != nil && _hasVisualOverflow && clipBehavior != .none {
            let rect = Offset.zero & size
            _clipRectLayer.layer = context.pushClipRect(
                needsCompositing,
                offset,
                rect,
                { (context: PaintingContext, offset: Offset) in
                    super.paint(context, offset)
                },
                clipBehavior: clipBehavior,
                oldLayer: _clipRectLayer.layer
            )
        } else {
            _clipRectLayer.layer = nil
            super.paint(context, offset)
        }
    }

    /// Layer handle for the clip rect layer used when the child overflows.
    ///
    /// **Dart Source:** `animated_size.dart:403`
    private let _clipRectLayer = LayerHandle<ClipRectLayer>()

    // MARK: - Dispose

    /// Releases the resources used by this render object.
    ///
    /// Cleans up the clip rect layer, animation controller, and curved animation.
    ///
    /// **Dart Source:** `animated_size.dart:405-411`
    public override func dispose() {
        _clipRectLayer.layer = nil
        _controller.dispose()
        _animation.dispose()
        super.dispose()
    }
}
