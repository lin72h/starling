// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A gesture recognizer that eagerly claims victory in all gesture arenas.
///
/// This is typically passed in `AndroidView.gestureRecognizers` in order to
/// immediately dispatch all touch events inside the view bounds to the
/// embedded Android view. See `AndroidView.gestureRecognizers` for more
/// details.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/eager.dart`
/// **Lines:** 1-40

import FlutterSwiftBridge

// MARK: - EagerGestureRecognizer

/// A gesture recognizer that eagerly claims victory in all gesture arenas.
///
/// This is typically passed in `AndroidView.gestureRecognizers` in order to
/// immediately dispatch all touch events inside the view bounds to the
/// embedded Android view. See `AndroidView.gestureRecognizers` for more
/// details.
///
/// **Dart Source:** `eager.dart:14-40`
public class EagerGestureRecognizer: OneSequenceGestureRecognizer {

    /// Create an eager gesture recognizer.
    ///
    /// **Dart Source:** `eager.dart:23`
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// Registers a new allowed pointer and immediately resolves the gesture
    /// as accepted, then stops tracking the pointer.
    ///
    /// This causes the recognizer to eagerly win in the gesture arena,
    /// preventing other gesture recognizers from claiming the pointer.
    ///
    /// **Dart Source:** `eager.dart:26-30`
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        resolve(.accepted)
        stopTrackingPointer(event.pointer)
    }

    /// Returns a very short pretty description of the gesture that the
    /// recognizer looks for.
    ///
    /// **Dart Source:** `eager.dart:33`
    public override var debugDescription: String {
        return "eager"
    }

    /// Called when the number of pointers this recognizer is tracking changes
    /// from one to zero.
    ///
    /// **Dart Source:** `eager.dart:36`
    public override func didStopTrackingLastPointer(_ pointer: Int) {}

    /// Called when a pointer event is routed to this recognizer.
    ///
    /// **Dart Source:** `eager.dart:39`
    public override func handleEvent(_ event: PointerEvent) {}
}
