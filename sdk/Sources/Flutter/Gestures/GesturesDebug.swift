// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Debug flags and assertion functions for the gestures library.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/debug.dart`

// MARK: - Debug Flags

/// Whether to print the results of each hit test to the console.
///
/// When this is set, in debug mode, any time a hit test is triggered by the
/// GestureBinding the results are dumped to the console.
///
/// This has no effect in release builds.
///
/// **Dart Source:** `debug.dart:20`
nonisolated(unsafe) public var debugPrintHitTestResults: Bool = false

/// Whether to print the details of each mouse hover event to the console.
///
/// When this is set, in debug mode, any time a mouse hover event is triggered
/// by the GestureBinding, the results are dumped to the console.
///
/// This has no effect in release builds, and only applies to mouse hover
/// events.
///
/// **Dart Source:** `debug.dart:29`
nonisolated(unsafe) public var debugPrintMouseHoverEvents: Bool = false

/// Prints information about gesture recognizers and gesture arenas.
///
/// This flag only has an effect in debug mode.
///
/// See also:
///
///  - ``debugPrintRecognizerCallbacksTrace``, for debugging issues with
///    gesture recognizers.
///
/// **Dart Source:** `debug.dart:40`
nonisolated(unsafe) public var debugPrintGestureArenaDiagnostics: Bool = false

/// Logs a message every time a gesture recognizer callback is invoked.
///
/// This flag only has an effect in debug mode.
///
/// This is specifically used by gesture recognizer `invokeCallback`. Gesture
/// recognizers that do not use this method to invoke callbacks may not honor
/// the ``debugPrintRecognizerCallbacksTrace`` flag.
///
/// See also:
///
///  - ``debugPrintGestureArenaDiagnostics``, for debugging issues with gesture
///    arenas.
///
/// **Dart Source:** `debug.dart:54`
nonisolated(unsafe) public var debugPrintRecognizerCallbacksTrace: Bool = false

/// Whether to print the resampling margin to the console.
///
/// When this is set, in debug mode, any time resampling is triggered by the
/// GestureBinding the resampling margin is dumped to the console. The
/// resampling margin is the delta between the time of the last received
/// touch event and the current sample time. Positive value indicates that
/// resampling is effective and the resampling offset can potentially be
/// reduced for improved latency. Negative value indicates that resampling
/// is failing and resampling offset needs to be increased for smooth
/// touch event processing.
///
/// This has no effect in release builds.
///
/// **Dart Source:** `debug.dart:68`
nonisolated(unsafe) public var debugPrintResamplingMargin: Bool = false

// MARK: - Debug Assertions

/// Returns true if none of the gestures library debug variables have been changed.
///
/// This function is used by the test framework to ensure that debug variables
/// haven't been inadvertently changed.
///
/// **Dart Source:** `debug.dart:77`
public func debugAssertAllGesturesVarsUnset(_ reason: String) -> Bool {
    assert(
        {
            if debugPrintHitTestResults
                || debugPrintGestureArenaDiagnostics
                || debugPrintRecognizerCallbacksTrace
                || debugPrintResamplingMargin
            {
                assertionFailure(reason)
            }
            return true
        }()
    )
    return true
}
