// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// A callback used by `PointerEventResampler.sample` and
/// `PointerEventResampler.stop` to process a resampled `event`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/resampler.dart`
/// **Line:** 13
public typealias HandleEventCallback = (_ event: PointerEvent) -> Void

/// Class for pointer event resampling.
///
/// An instance of this class can be used to resample one sequence
/// of pointer events. Multiple instances are expected to be used for
/// multi-touch support. The sampling frequency and the sampling
/// offset is determined by the caller.
///
/// This can be used to get smooth touch event processing at the cost
/// of adding some latency. Devices with low frequency sensors or when
/// the frequency is not a multiple of the display frequency
/// (e.g., 120Hz input and 90Hz display) benefit from this.
///
/// The following pointer event types are supported:
/// `PointerAddedEvent`, `PointerHoverEvent`, `PointerDownEvent`,
/// `PointerMoveEvent`, `PointerCancelEvent`, `PointerUpEvent`,
/// `PointerRemovedEvent`.
///
/// Resampling is currently limited to event position and delta. All
/// pointer event types except `PointerAddedEvent` will be resampled.
/// `PointerHoverEvent` and `PointerMoveEvent` will only be generated
/// when the position has changed.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/resampler.dart`
/// **Lines:** 36-352
public class PointerEventResampler {

    // MARK: - Initializer

    public init() {}

    // MARK: - Private State

    /// Events queued for processing.
    ///
    /// **Dart Source:** `resampler.dart:38`
    ///
    /// DIFFERENCE FROM DART: Uses `[PointerEvent]` (Swift Array) instead of `Queue<PointerEvent>`.
    /// REASON: Swift does not have a built-in `Queue` type; Array with `removeFirst()` provides
    /// equivalent FIFO semantics.
    private var _queuedEvents: [PointerEvent] = []

    /// Pointer state required for resampling.
    ///
    /// **Dart Source:** `resampler.dart:41-47`
    private var _last: PointerEvent? = nil
    private var _next: PointerEvent? = nil
    private var _position: Offset = .zero
    private var _isTracked: Bool = false
    private var _isDown: Bool = false
    private var _pointerIdentifier: Int = 0
    private var _hasButtons: Int = 0

    // MARK: - Private Helpers

    /// Creates a `PointerHoverEvent` from the given event with resampled position/delta/timeStamp.
    ///
    /// **Dart Source:** `resampler.dart:49-79`
    private func _toHoverEvent(
        _ event: PointerEvent,
        position: Offset,
        delta: Offset,
        timeStamp: Duration,
        buttons: Int
    ) -> PointerEvent {
        return PointerHoverEvent(
            viewId: event.viewId,
            timeStamp: timeStamp,
            kind: event.kind,
            device: event.device,
            position: position,
            delta: delta,
            buttons: event.buttons,
            obscured: event.obscured,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distance: event.distance,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            synthesized: event.synthesized,
            embedderId: event.embedderId
        )
    }

    /// Creates a `PointerMoveEvent` from the given event with resampled position/delta/timeStamp.
    ///
    /// **Dart Source:** `resampler.dart:81-114`
    private func _toMoveEvent(
        _ event: PointerEvent,
        position: Offset,
        delta: Offset,
        pointerIdentifier: Int,
        timeStamp: Duration,
        buttons: Int
    ) -> PointerEvent {
        return PointerMoveEvent(
            viewId: event.viewId,
            timeStamp: timeStamp,
            pointer: pointerIdentifier,
            kind: event.kind,
            device: event.device,
            position: position,
            delta: delta,
            buttons: buttons,
            obscured: event.obscured,
            pressure: event.pressure,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            platformData: event.platformData,
            synthesized: event.synthesized,
            embedderId: event.embedderId
        )
    }

    /// Creates a `PointerMoveEvent` or `PointerHoverEvent` depending on `isDown`.
    ///
    /// **Dart Source:** `resampler.dart:116-128`
    private func _toMoveOrHoverEvent(
        _ event: PointerEvent,
        position: Offset,
        delta: Offset,
        pointerIdentifier: Int,
        timeStamp: Duration,
        isDown: Bool,
        buttons: Int
    ) -> PointerEvent {
        return isDown
            ? _toMoveEvent(event, position: position, delta: delta, pointerIdentifier: pointerIdentifier, timeStamp: timeStamp, buttons: buttons)
            : _toHoverEvent(event, position: position, delta: delta, timeStamp: timeStamp, buttons: buttons)
    }

    /// Returns the interpolated position at `sampleTime`.
    ///
    /// Uses `_next` position by default, and interpolates between `_last` and `_next`
    /// if `_next` timestamp is past `sampleTime`.
    ///
    /// **Dart Source:** `resampler.dart:130-149`
    ///
    /// DIFFERENCE FROM DART: Uses `_durationToMicroseconds` helper instead of `.inMicroseconds`.
    /// REASON: Swift's `Duration` does not have a direct `inMicroseconds` property like Dart.
    private func _positionAt(_ sampleTime: Duration) -> Offset {
        // Use `next` position by default.
        var x = _next?.position.dx ?? 0.0
        var y = _next?.position.dy ?? 0.0

        let nextTimeStamp = _next?.timeStamp ?? .zero
        let lastTimeStamp = _last?.timeStamp ?? .zero

        // Resample if `next` time stamp is past `sampleTime`.
        if nextTimeStamp > sampleTime && nextTimeStamp > lastTimeStamp {
            let interval = Double(_durationToMicroseconds(nextTimeStamp - lastTimeStamp))
            let scalar = Double(_durationToMicroseconds(sampleTime - lastTimeStamp)) / interval
            let lastX = _last?.position.dx ?? 0.0
            let lastY = _last?.position.dy ?? 0.0
            x = lastX + (x - lastX) * scalar
            y = lastY + (y - lastY) * scalar
        }

        return Offset(x, y)
    }

    /// Updates `_last` and `_next` pointers based on queued events and `sampleTime`.
    ///
    /// **Dart Source:** `resampler.dart:151-172`
    private func _processPointerEvents(_ sampleTime: Duration) {
        for event in _queuedEvents {
            // Update both `last` and `next` pointer event if time stamp is older
            // or equal to `sampleTime`.
            if event.timeStamp <= sampleTime || _last == nil {
                _last = event
                _next = event
                continue
            }

            // Update only `next` pointer event if time stamp is more recent than
            // `sampleTime` and next event is not already more recent.
            let nextTimeStamp = _next?.timeStamp ?? .zero
            if nextTimeStamp < sampleTime {
                _next = event
                break
            }
        }
    }

    /// Dequeues and dispatches non-hover/move pointer events up to `sampleTime`,
    /// with early processing of up and removed events up to `nextSampleTime`.
    ///
    /// **Dart Source:** `resampler.dart:174-275`
    private func _dequeueAndSampleNonHoverOrMovePointerEventsUntil(
        _ sampleTime: Duration,
        nextSampleTime: Duration,
        callback: HandleEventCallback
    ) {
        var endTime = sampleTime
        // Scan queued events to determine end time.
        for event in _queuedEvents {
            // Potentially stop dispatching events if more recent than `sampleTime`.
            if event.timeStamp > sampleTime {
                // Definitely stop if more recent than `nextSampleTime`.
                if event.timeStamp >= nextSampleTime {
                    break
                }

                // Update `endTime` to allow early processing of up and removed
                // events as this improves resampling of these events, which is
                // important for fling animations.
                if event is PointerUpEvent || event is PointerRemovedEvent {
                    endTime = event.timeStamp
                    continue
                }

                // Stop if event is not move or hover.
                if !(event is PointerMoveEvent) && !(event is PointerHoverEvent) {
                    break
                }
            }
        }

        while !_queuedEvents.isEmpty {
            let event = _queuedEvents.first!

            // Stop dispatching events if more recent than `endTime`.
            if event.timeStamp > endTime {
                break
            }

            let wasTracked = _isTracked
            let wasDown = _isDown
            let hadButtons = _hasButtons

            // Update pointer state.
            _isTracked = !(event is PointerRemovedEvent)
            _isDown = event.down
            _hasButtons = event.buttons

            // Position at `sampleTime`.
            let position = _positionAt(sampleTime)

            // Initialize position if we are starting to track this pointer.
            if _isTracked && !wasTracked {
                _position = position
            }

            // Current pointer identifier.
            let pointerIdentifier = event.pointer

            // Initialize pointer identifier for `move` events.
            // Identifier is expected to be the same while `down`.
            assert(!wasDown || _pointerIdentifier == pointerIdentifier)
            _pointerIdentifier = pointerIdentifier

            // Skip `move` and `hover` events as they are automatically
            // generated when the position has changed.
            if !(event is PointerMoveEvent) && !(event is PointerHoverEvent) {
                // Add synthetic `move` or `hover` event if position has changed.
                //
                // Devices without `hover` events are expected to always have
                // `add` and `down` events with the same position and this logic will
                // therefore never produce `hover` events.
                if position != _position {
                    let delta = position - _position
                    callback(
                        _toMoveOrHoverEvent(
                            event,
                            position: position,
                            delta: delta,
                            pointerIdentifier: _pointerIdentifier,
                            timeStamp: sampleTime,
                            isDown: wasDown,
                            buttons: hadButtons
                        )
                    )
                    _position = position
                }
                callback(
                    event.copyWith(
                        timeStamp: sampleTime,
                        pointer: pointerIdentifier,
                        position: position,
                        delta: .zero
                    )
                )
            }

            _queuedEvents.removeFirst()
        }
    }

    /// Dispatches a `PointerMoveEvent` or `PointerHoverEvent` if position has changed
    /// at `sampleTime`.
    ///
    /// **Dart Source:** `resampler.dart:277-298`
    private func _samplePointerPosition(_ sampleTime: Duration, callback: HandleEventCallback) {
        // Position at `sampleTime`.
        let position = _positionAt(sampleTime)

        // Add `move` or `hover` events if position has changed.
        let next = _next
        if position != _position && next != nil {
            let delta = position - _position
            callback(
                _toMoveOrHoverEvent(
                    next!,
                    position: position,
                    delta: delta,
                    pointerIdentifier: _pointerIdentifier,
                    timeStamp: sampleTime,
                    isDown: _isDown,
                    buttons: _hasButtons
                )
            )
            _position = position
        }
    }

    // MARK: - Duration Helpers

    /// Converts a `Duration` to microseconds as an `Int64`.
    ///
    /// DIFFERENCE FROM DART: Uses `Duration.components` to extract microseconds.
    /// REASON: Swift's `Duration` does not have a direct `inMicroseconds` property like Dart.
    private func _durationToMicroseconds(_ duration: Duration) -> Int64 {
        let components = duration.components
        return components.seconds * 1_000_000 + components.attoseconds / 1_000_000_000_000
    }

    // MARK: - Public API

    /// Enqueue pointer `event` for resampling.
    ///
    /// **Dart Source:** `resampler.dart:301-303`
    public func addEvent(_ event: PointerEvent) {
        _queuedEvents.append(event)
    }

    /// Dispatch resampled pointer events for the specified `sampleTime`
    /// by calling `callback`.
    ///
    /// This may dispatch multiple events if position is not the only
    /// state that has changed since last sample.
    ///
    /// Calling `callback` must not add or sample events.
    ///
    /// Positive value for `nextSampleTime` allow early processing of
    /// up and removed events. This improves resampling of these events,
    /// which is important for fling animations.
    ///
    /// **Dart Source:** `resampler.dart:316-326`
    public func sample(
        sampleTime: Duration,
        nextSampleTime: Duration,
        callback: HandleEventCallback
    ) {
        _processPointerEvents(sampleTime)

        // Dequeue and sample pointer events until `sampleTime`.
        _dequeueAndSampleNonHoverOrMovePointerEventsUntil(sampleTime, nextSampleTime: nextSampleTime, callback: callback)

        // Dispatch resampled pointer location event if tracked.
        if _isTracked {
            _samplePointerPosition(sampleTime, callback: callback)
        }
    }

    /// Stop resampling.
    ///
    /// This will dispatch pending events by calling `callback` and reset
    /// internal state.
    ///
    /// **Dart Source:** `resampler.dart:332-342`
    public func stop(callback: HandleEventCallback) {
        while !_queuedEvents.isEmpty {
            callback(_queuedEvents.removeFirst())
        }
        _pointerIdentifier = 0
        _isDown = false
        _isTracked = false
        _position = .zero
        _next = nil
        _last = nil
    }

    /// Returns `true` if a call to `sample` can dispatch more events.
    ///
    /// **Dart Source:** `resampler.dart:345`
    public var hasPendingEvents: Bool {
        return !_queuedEvents.isEmpty
    }

    /// Returns `true` if pointer is currently tracked.
    ///
    /// **Dart Source:** `resampler.dart:348`
    public var isTracked: Bool {
        return _isTracked
    }

    /// Returns `true` if pointer is currently down.
    ///
    /// **Dart Source:** `resampler.dart:351`
    public var isDown: Bool {
        return _isDown
    }
}
