// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - WindowLifecycleAnimation

/// macOS "scale effect" window lifecycle animations.
///
/// Open (and restore from minimize — both mount a fresh element): the
/// window's rect interpolates from a small rect on its dock icon to its
/// final position over 380ms of easeInOutCubic — the straight rectangular
/// zoom of macOS's scale effect (no genie warp). `zoomFrom` is the offset
/// from the window's center to the icon in global px; without it the
/// window falls back to an in-place 88% -> 100% pop.
///
/// Minimize: the same zoom in reverse — the window flies into its dock
/// icon with input ignored, then `onMinimized` fires and the owner
/// actually minimizes it (removal is deferred so the animation plays over
/// live content).
///
/// Close: the child shrinks in place to 72% (160ms, easeIn — macOS close
/// does not travel to the dock) with input ignored, then `onClosed` fires
/// for the real teardown.
///
/// Scale-only on purpose: this framework's RenderAnimatedOpacity gates at
/// alpha 0 but doesn't blend partial alpha, so a fade would read as a
/// one-frame blink rather than a fade — the scale carries the effect.
final class WindowLifecycleAnimation: StatefulWidget {
    let closing: Bool
    let minimizing: Bool
    /// When false at mount, the open zoom is skipped and the child renders
    /// settled immediately — used when a window mounts only because a space
    /// switch brought its desktop on screen, not because it is appearing.
    let animateOpen: Bool
    let onClosed: (() -> Void)?
    let onMinimized: (() -> Void)?
    let zoomFrom: Offset?
    let child: Widget

    init(closing: Bool = false, minimizing: Bool = false,
         animateOpen: Bool = true,
         onClosed: (() -> Void)? = nil, onMinimized: (() -> Void)? = nil,
         zoomFrom: Offset? = nil, child: Widget) {
        self.closing = closing
        self.minimizing = minimizing
        self.animateOpen = animateOpen
        self.onClosed = onClosed
        self.onMinimized = onMinimized
        self.zoomFrom = zoomFrom
        self.child = child
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return _WindowLifecycleAnimationState()
    }
}

private final class _WindowLifecycleAnimationState: State<StatefulWidget>, TickerProvider {
    private var _controller: AnimationController!
    private var _curved: CurvedAnimation!
    private var _closeScale: Animation<Double>?
    private var _closing = false
    private var _minimizing = false
    private var _openDone = false

    private var _widget: WindowLifecycleAnimation { widget as! WindowLifecycleAnimation }

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    override func initState() {
        super.initState()
        _controller = AnimationController(duration: .milliseconds(380), vsync: self)
        _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic)
        _controller.addStatusListener { [weak self] status in
            guard let self, status == .completed else { return }
            if self._closing {
                self._widget.onClosed?()
            } else if self._minimizing {
                self._widget.onMinimized?()
            } else {
                // Drop the transform wrapper once the zoom has landed.
                self.setState { self._openDone = true }
            }
        }
        if _widget.closing {
            _startClose()
        } else if _widget.minimizing {
            _startMinimize()
        } else if !_widget.animateOpen {
            // Mounted by a space switch — render settled, no open zoom.
            _openDone = true
        } else {
            _ = _controller.forward()
        }
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        // Terminal transitions only: a closing/minimizing window never
        // un-closes — the owner's finalize callback always follows.
        if _widget.closing && !_closing {
            _startClose()
        } else if _widget.minimizing && !_minimizing && !_closing {
            _startMinimize()
        }
    }

    /// Retarget the controller from wherever it is to the shrink-out.
    /// build() runs right after (initState/didUpdateWidget are both
    /// followed by a build), so the new animation is picked up without an
    /// explicit setState.
    private func _startClose() {
        _closing = true
        _controller.stop()
        _controller.duration = .milliseconds(160)
        _closeScale = CurvedAnimation(parent: _controller, curve: Curves.easeIn)
            .drive(DoubleTween(begin: 1.0, end: 0.72))
        _ = _controller.forward(from: 0)
    }

    /// Retarget to the reverse zoom — the window flies into its dock icon.
    private func _startMinimize() {
        _minimizing = true
        _openDone = false
        _controller.stop()
        _controller.duration = .milliseconds(380)
        _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic)
        _ = _controller.forward(from: 0)
    }

    override func dispose() {
        _controller.dispose()
        super.dispose()
    }

    /// The scale-effect transform at progress `e` (0 = on the dock icon,
    /// 1 = at the window's real rect): the rect interpolates linearly in
    /// the eased parameter — center travels icon -> window while the size
    /// scales 5% -> 100% about that center.
    private func _zoom(_ e: Double, offset: Offset, child: Widget) -> Widget {
        let s = 0.05 + 0.95 * e
        return Transform(
            translate: Offset(offset.dx * (1 - e), offset.dy * (1 - e)),
            child: Transform(scale: s, child: child)
        )
    }

    override func build(_ context: any BuildContext) -> Widget {
        if _closing {
            // A closing window no longer accepts input.
            return IgnorePointer(
                child: ScaleTransition(scale: _closeScale!, child: _widget.child))
        }
        if _minimizing {
            // Reverse zoom into the dock (in-place shrink if no icon known).
            let offset = _widget.zoomFrom ?? Offset(0, 0)
            return IgnorePointer(
                child: AnimatedBuilder(
                    animation: _controller,
                    builder: { [self] _, child in
                        _zoom(1 - _curved.value, offset: offset, child: child!)
                    },
                    child: _widget.child
                )
            )
        }
        if _openDone {
            return _widget.child
        }
        guard let zoom = _widget.zoomFrom else {
            // No dock origin known: in-place pop.
            return ScaleTransition(
                scale: _curved.drive(DoubleTween(begin: 0.88, end: 1.0)),
                child: _widget.child)
        }
        return AnimatedBuilder(
            animation: _controller,
            builder: { [self] _, child in
                _zoom(_curved.value, offset: zoom, child: child!)
            },
            child: _widget.child
        )
    }
}

// MARK: - DockBounce

/// macOS-style dock-icon bounce while an app is launching. While `active`,
/// the child hops on a sinusoidal arc with a short rest between hops; when
/// deactivated it settles back to rest and the ticker stops.
final class DockBounce: StatefulWidget {
    let active: Bool
    let child: Widget

    init(active: Bool, child: Widget) {
        self.active = active
        self.child = child
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return _DockBounceState()
    }
}

private final class _DockBounceState: State<StatefulWidget>, TickerProvider {
    private var _controller: AnimationController!

    private var _widget: DockBounce { widget as! DockBounce }

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    override func initState() {
        super.initState()
        _controller = AnimationController(duration: .milliseconds(700), vsync: self)
        if _widget.active { _ = _controller.repeat() }
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        if _widget.active && !_controller.isAnimating {
            _ = _controller.repeat()
        } else if !_widget.active && _controller.isAnimating {
            _controller.stop()
            _controller.value = 0
        }
    }

    override func dispose() {
        _controller.dispose()
        super.dispose()
    }

    override func build(_ context: any BuildContext) -> Widget {
        if !_widget.active {
            return _widget.child
        }
        return AnimatedBuilder(
            animation: _controller,
            builder: { [self] _, child in
                // Hop for the first 70% of the period, rest for the remainder
                // (macOS pauses briefly between bounces).
                let t = _controller.value
                let hop = t < 0.7 ? sin(.pi * t / 0.7) : 0.0
                return Transform(
                    translate: Offset(0, -22.0 * hop),
                    child: child
                )
            },
            child: _widget.child
        )
    }
}
