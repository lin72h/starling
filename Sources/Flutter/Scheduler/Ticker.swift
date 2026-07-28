// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Ticker, TickerFuture, TickerProvider, and related types.
///
/// **Dart Source:** `packages/flutter/lib/src/scheduler/ticker.dart`

import FlutterSwiftBridge
@preconcurrency import Foundation

// MARK: - TickerScheduler

/// Global scheduler that drives Tickers via the engine's vsync callbacks.
///
/// In Dart's Flutter, `SchedulerBinding` provides frame callbacks that drive
/// Tickers. This is a minimal equivalent: active Tickers register here, and
/// `Adapter.swift` calls `tick()` on every `onBeginFrame` to advance them.
public class TickerScheduler: @unchecked Sendable {
    public static nonisolated(unsafe) let shared = TickerScheduler()
    private init() {}

    private var _activeTickers: [ObjectIdentifier: Ticker] = [:]

    /// Register a Ticker to receive vsync ticks.
    func register(_ ticker: Ticker) {
        _activeTickers[ObjectIdentifier(ticker)] = ticker
        PlatformDispatcher.instance.scheduleFrame()
    }

    /// Unregister a Ticker (called on stop/dispose).
    func unregister(_ ticker: Ticker) {
        _activeTickers.removeValue(forKey: ObjectIdentifier(ticker))
    }

    /// Whether there are active tickers that need frames.
    public var hasActiveTickers: Bool {
        !_activeTickers.isEmpty
    }

    /// Called from `onBeginFrame` to advance all active Tickers.
    /// Must be called BEFORE `buildScope` so that animation-driven `setState`
    /// calls are picked up in the same frame.
    public func tick() {
        guard !_activeTickers.isEmpty else { return }
        let tickers = Array(_activeTickers.values)
        for ticker in tickers {
            ticker._schedulerTick()
        }
        // If tickers are still active after ticking, schedule another frame
        if !_activeTickers.isEmpty {
            PlatformDispatcher.instance.scheduleFrame()
        }
    }
}

// MARK: - TickerCallback

/// Signature for the callback passed to the `Ticker` class's constructor.
///
/// The argument is the time elapsed from the frame timestamp when the ticker
/// was last started to the current frame timestamp.
///
/// **Dart Source:** `ticker.dart:24`
public typealias TickerCallback = (Duration) -> Void

// MARK: - TickerProvider

/// An interface implemented by classes that can vend `Ticker` objects.
///
/// Tickers can be used by any object that wants to be notified whenever a frame
/// triggers, but are most commonly used indirectly via an
/// `AnimationController`. `AnimationController`s need a `TickerProvider` to
/// obtain their `Ticker`.
///
/// **Dart Source:** `ticker.dart:43-53`
public protocol TickerProvider {
    /// Creates a ticker with the given callback.
    ///
    /// The kind of ticker provided depends on the kind of ticker provider.
    ///
    /// **Dart Source:** `ticker.dart:52`
    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker
}

// MARK: - Ticker

/// Calls its callback once per animation frame, when enabled.
///
/// When created, a ticker is initially disabled. Call `start` to
/// enable the ticker.
///
/// A `Ticker` can be silenced by setting `muted` to true. While silenced, time
/// still elapses, and `start` and `stop` can still be called, but no callbacks
/// are called.
///
/// **Dart Source:** `ticker.dart:78-393`
///
/// DIFFERENCE FROM DART: This is a stub implementation. The full Ticker
/// requires SchedulerBinding for frame callbacks.
/// REASON: AnimationController needs Ticker to compile; the full scheduler
/// will be migrated separately.
open class Ticker {
    /// Creates a ticker that will call the provided callback once per frame while
    /// running.
    ///
    /// An optional label can be provided for debugging purposes.
    ///
    /// **Dart Source:** `ticker.dart:84-90`
    public init(_ onTick: @escaping TickerCallback, debugLabel: String? = nil) {
        self._onTick = onTick
        self.debugLabel = debugLabel
    }

    private let _onTick: TickerCallback

    /// An optional label for debugging purposes.
    ///
    /// **Dart Source:** `ticker.dart:369`
    public let debugLabel: String?

    private var _future: TickerFuture?

    /// Whether this ticker has been silenced.
    ///
    /// While silenced, a ticker's clock can still run, but the callback will not
    /// be called.
    ///
    /// **Dart Source:** `ticker.dart:98-99`
    public var muted: Bool {
        get { _muted }
        set {
            if newValue == _muted { return }
            _muted = newValue
        }
    }
    private var _muted: Bool = false

    /// Whether time is elapsing for this `Ticker`. Becomes true when `start` is
    /// called and false when `stop` is called.
    ///
    /// **Dart Source:** `ticker.dart:155`
    public var isActive: Bool { _future != nil }

    /// The frame timestamp when the ticker was last started.
    ///
    /// **Dart Source:** `ticker.dart:159`
    private var _startTime: Duration?

    /// Starts the clock for this `Ticker`.
    ///
    /// The returned future resolves once the ticker `stop`s ticking. If the
    /// ticker is disposed, the future does not resolve.
    ///
    /// Calling this sets `isActive` to true.
    ///
    /// This method cannot be called while the ticker is active.
    ///
    /// **Dart Source:** `ticker.dart:176-199`
    @discardableResult
    public func start() -> TickerFuture {
        assert(!isActive, "A ticker was started twice.")
        assert(_startTime == nil)
        _future = TickerFuture()

        // Register with the vsync-driven TickerScheduler.
        // The scheduler calls _schedulerTick() on every onBeginFrame callback,
        // which is synchronized with the engine's frame timing.
        _animationStartDate = Date()
        TickerScheduler.shared.register(self)

        // A ticker needs a frame to tick in. Without this, a ticker started
        // outside an input burst (e.g. an animation kicked off in initState
        // when an element mounts) never receives its first tick — the
        // scheduler only runs from onBeginFrame. Mirrors Flutter's
        // SchedulerBinding.scheduleFrame() call in Ticker.start().
        PlatformDispatcher.instance.scheduleFrame()

        return _future!
    }

    /// The time at which the ticker was started, used to compute elapsed time.
    private var _animationStartDate: Date?

    /// Called by TickerScheduler on each vsync frame.
    func _schedulerTick() {
        guard !_muted, _future != nil,
              let startDate = _animationStartDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        let elapsedDuration = Duration.microseconds(Int64(elapsed * 1_000_000))
        _onTick(elapsedDuration)
    }

    /// Stops calling this `Ticker`'s callback.
    ///
    /// If called with `canceled` set to false (the default), causes the future
    /// returned by `start` to resolve. If called with `canceled` set to true,
    /// the future does not resolve.
    ///
    /// Calling this sets `isActive` to false.
    ///
    /// This method does nothing if called when the ticker is inactive.
    ///
    /// **Dart Source:** `ticker.dart:222-241`
    public func stop(canceled: Bool = false) {
        if !isActive { return }

        TickerScheduler.shared.unregister(self)
        _animationStartDate = nil

        let localFuture = _future!
        _future = nil
        _startTime = nil
        assert(!isActive)

        if canceled {
            localFuture._cancel(self)
        } else {
            localFuture._complete()
        }
    }

    /// Makes this `Ticker` take the state of another ticker, and disposes the
    /// other ticker.
    ///
    /// This is useful if an object with a `Ticker` is given a new
    /// `TickerProvider` but needs to maintain continuity.
    ///
    /// This ticker must not be active when this method is called.
    ///
    /// **Dart Source:** `ticker.dart:315-335`
    public func absorbTicker(_ originalTicker: Ticker) {
        assert(!isActive)
        assert(_future == nil)
        assert(_startTime == nil)
        if originalTicker._future != nil {
            _future = originalTicker._future
            _startTime = originalTicker._startTime
            originalTicker._future = nil
        }
        originalTicker.dispose()
    }

    /// Release the resources used by this object. The object is no longer usable
    /// after this method is called.
    ///
    /// **Dart Source:** `ticker.dart:348-364`
    open func dispose() {
        TickerScheduler.shared.unregister(self)
        _animationStartDate = nil
        if _future != nil {
            let localFuture = _future!
            _future = nil
            assert(!isActive)
            localFuture._cancel(self)
        }
    }

    /// Simulates a tick with the given elapsed duration.
    ///
    /// DIFFERENCE FROM DART: Not present in Dart. Added for testing since
    /// the stub doesn't have SchedulerBinding integration.
    /// REASON: Allows AnimationController tests to drive ticks manually.
    public func tick(_ elapsed: Duration) {
        _startTime = _startTime ?? .zero
        _onTick(elapsed)
    }

    /// **Dart Source:** `ticker.dart:373-392`
    open var description: String {
        return "Ticker(\(debugLabel ?? ""))"
    }
}

// MARK: - TickerFuture

/// An object representing an ongoing `Ticker` sequence.
///
/// The `Ticker.start` method returns a `TickerFuture`. The `TickerFuture` will
/// complete successfully if the `Ticker` is stopped using `Ticker.stop` with
/// the `canceled` argument set to false (the default).
///
/// **Dart Source:** `ticker.dart:411-510`
///
/// DIFFERENCE FROM DART: Does not implement `Future<Void>`. Uses completion
/// callbacks instead.
/// REASON: Swift does not have Dart's `Future`/`Completer` pattern. The stub
/// provides the essential API surface needed by AnimationController.
public class TickerFuture {

    /// Creates a `TickerFuture` instance (internal use by `Ticker`).
    ///
    /// **Dart Source:** `ticker.dart:412`
    init() {
        _completed = nil
    }

    /// Creates a `TickerFuture` instance that represents an already-complete
    /// `Ticker` sequence.
    ///
    /// **Dart Source:** `ticker.dart:421-423`
    public static func complete() -> TickerFuture {
        let future = TickerFuture()
        future._complete()
        return future
    }

    /// null means unresolved, true means complete, false means canceled
    ///
    /// **Dart Source:** `ticker.dart:427`
    private var _completed: Bool?

    private var _whenCompleteOrCancelCallbacks: [VoidCallback] = []

    func _complete() {
        assert(_completed == nil)
        _completed = true
        for callback in _whenCompleteOrCancelCallbacks {
            callback()
        }
        _whenCompleteOrCancelCallbacks.removeAll()
    }

    func _cancel(_ ticker: Ticker) {
        assert(_completed == nil)
        _completed = false
        for callback in _whenCompleteOrCancelCallbacks {
            callback()
        }
        _whenCompleteOrCancelCallbacks.removeAll()
    }

    /// Calls `callback` either when this future resolves or when the ticker is
    /// canceled.
    ///
    /// **Dart Source:** `ticker.dart:448-454`
    public func whenCompleteOrCancel(_ callback: @escaping VoidCallback) {
        if _completed != nil {
            callback()
        } else {
            _whenCompleteOrCancelCallbacks.append(callback)
        }
    }

    /// **Dart Source:** `ticker.dart:504-509`
    public var description: String {
        if _completed == nil {
            return "TickerFuture(active)"
        } else if _completed! {
            return "TickerFuture(complete)"
        } else {
            return "TickerFuture(canceled)"
        }
    }
}

// MARK: - TickerCanceled

/// Exception thrown by `Ticker` objects when the ticker is canceled.
///
/// **Dart Source:** `ticker.dart:514-531`
public struct TickerCanceled: Error, CustomStringConvertible {
    /// Creates a canceled-ticker exception.
    ///
    /// **Dart Source:** `ticker.dart:516`
    public init(_ ticker: Ticker? = nil) {
        self.ticker = ticker
    }

    /// Reference to the `Ticker` object that was canceled.
    ///
    /// **Dart Source:** `ticker.dart:522`
    public let ticker: Ticker?

    /// **Dart Source:** `ticker.dart:525-529`
    public var description: String {
        if let ticker = ticker {
            return "This ticker was canceled: \(ticker.description)"
        }
        return "The ticker was canceled before the \"orCancel\" property was first used."
    }
}
