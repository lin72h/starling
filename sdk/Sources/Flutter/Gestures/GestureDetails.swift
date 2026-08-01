// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An abstract interface representing gesture details that include positional information.
///
/// This protocol serves as a common interface for gesture details that involve positional data,
/// such as dragging and tapping. It simplifies gesture handling by enabling the use of shared logic
/// across multiple gesture types.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/gesture_details.dart`
/// **Lines:** 19-43

import FlutterSwiftBridge

// MARK: - PositionedGestureDetails

/// An abstract interface representing gesture details that include positional information.
///
/// **Dart Source:** `gesture_details.dart:19-43`
public protocol PositionedGestureDetails {
    /// The global position at which the pointer interacts with the screen.
    ///
    /// See also:
    ///
    ///  - ``localPosition``, which is the ``globalPosition`` transformed to the
    ///    coordinate space of the event receiver.
    ///
    /// **Dart Source:** `gesture_details.dart:31`
    var globalPosition: Offset { get }

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer interacts with the screen.
    ///
    /// See also:
    ///
    ///  - ``globalPosition``, which is the global position at which the pointer
    ///    interacts with the screen.
    ///
    /// **Dart Source:** `gesture_details.dart:42`
    var localPosition: Offset { get }
}
