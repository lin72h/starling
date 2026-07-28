// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Constants for gesture recognition thresholds and timeouts.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`

import Foundation

// Modeled after Android's ViewConfiguration:
// https://github.com/android/platform_frameworks_base/blob/main/core/java/android/view/ViewConfiguration.java

/// The time that must elapse before a tap gesture sends onTapDown, if there's
/// any doubt that the gesture is a tap.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 14
public let kPressTimeout: TimeInterval = 0.1

/// Maximum length of time between a tap down and a tap up for the gesture to be
/// considered a tap. (Currently not honored by the TapGestureRecognizer.)
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 20
// TODO(ianh): Remove this, or implement a hover-tap gesture recognizer which
// uses this.
public let kHoverTapTimeout: TimeInterval = 0.15

/// Maximum distance between the down and up pointers for a tap. (Currently not
/// honored by the `TapGestureRecognizer`; `PrimaryPointerGestureRecognizer`,
/// which TapGestureRecognizer inherits from, uses `kTouchSlop`.)
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 26
// TODO(ianh): Remove this or implement it correctly.
public let kHoverTapSlop: Double = 20.0 // Logical pixels

/// The time before a long press gesture attempts to win.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 29
public let kLongPressTimeout: TimeInterval = 0.5

/// The maximum time from the start of the first tap to the start of the second
/// tap in a double-tap gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 35
// In Android, this is actually the time from the first's up event
// to the second's down event, according to the ViewConfiguration docs.
public let kDoubleTapTimeout: TimeInterval = 0.3

/// The minimum time from the end of the first tap to the start of the second
/// tap in a double-tap gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 39
public let kDoubleTapMinTime: TimeInterval = 0.04

/// The maximum distance that the first touch in a double-tap gesture can travel
/// before deciding that it is not part of a double-tap gesture.
/// DoubleTapGestureRecognizer also restricts the second touch to this distance.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 44
public let kDoubleTapTouchSlop: Double = kTouchSlop // Logical pixels

/// Distance between the initial position of the first touch and the start
/// position of a potential second touch for the second touch to be considered
/// the second touch of a double-tap gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 49
public let kDoubleTapSlop: Double = 100.0 // Logical pixels

/// The time for which zoom controls (e.g. in a map interface) are to be
/// displayed on the screen, from the moment they were last requested.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 53
public let kZoomControlsTimeout: TimeInterval = 3.0

/// The distance a touch has to travel for the framework to be confident that
/// the gesture is a scroll gesture, or, inversely, the maximum distance that a
/// touch can travel before the framework becomes confident that it is not a
/// tap.
///
/// A total delta less than or equal to `kTouchSlop` is not considered to be a
/// drag, whereas if the delta is greater than `kTouchSlop` it is considered to
/// be a drag.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 65
// This value was empirically derived. We started at 8.0 and increased it to
// 18.0 after getting complaints that it was too difficult to hit targets.
public let kTouchSlop: Double = 18.0 // Logical pixels

/// The distance a touch has to travel for the framework to be confident that
/// the gesture is a paging gesture. (Currently not used, because paging uses a
/// regular drag gesture, which uses kTouchSlop.)
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 72
// TODO(ianh): Create variants of HorizontalDragGestureRecognizer et al for
// paging, which use this constant.
public let kPagingTouchSlop: Double = kTouchSlop * 2.0 // Logical pixels

/// The distance a touch has to travel for the framework to be confident that
/// the gesture is a panning gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 76
public let kPanSlop: Double = kTouchSlop * 2.0 // Logical pixels

/// The distance a touch has to travel for the framework to be confident that
/// the gesture is a scale gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 80
public let kScaleSlop: Double = kTouchSlop // Logical pixels

/// The margin around a dialog, popup menu, or other window-like widget inside
/// which we do not consider a tap to dismiss the widget. (Not currently used.)
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 85
// TODO(ianh): Make ModalBarrier support this.
public let kWindowTouchSlop: Double = 16.0 // Logical pixels

/// The minimum velocity for a touch to consider that touch to trigger a fling
/// gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 90
// TODO(ianh): Make sure nobody has their own version of this.
public let kMinFlingVelocity: Double = 50.0 // Logical pixels / second

/// Drag gesture fling velocities are clipped to this value.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 95
// TODO(ianh): Make sure nobody has their own version of this.
public let kMaxFlingVelocity: Double = 8000.0 // Logical pixels / second

/// The maximum time from the start of the first tap to the start of the second
/// tap in a jump-tap gesture.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 100
// TODO(ianh): Implement jump-tap gestures.
public let kJumpTapTimeout: TimeInterval = 0.5

/// Like `kTouchSlop`, but for more precise pointers like mice and trackpads.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 103
public let kPrecisePointerHitSlop: Double = 1.0 // Logical pixels

/// Like `kPanSlop`, but for more precise pointers like mice and trackpads.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 106
public let kPrecisePointerPanSlop: Double = kPrecisePointerHitSlop * 2.0 // Logical pixels

/// Like `kScaleSlop`, but for more precise pointers like mice and trackpads.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/constants.dart`, line 109
public let kPrecisePointerScaleSlop: Double = kPrecisePointerHitSlop // Logical pixels
