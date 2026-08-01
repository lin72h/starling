// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Device-specific gesture settings scaled into logical pixels.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/gesture_settings.dart`

import FlutterSwiftBridge

// MARK: - DeviceGestureSettings

/// The device specific gesture settings scaled into logical pixels.
///
/// This configuration can be retrieved from the window, or more commonly from a
/// MediaQuery widget.
///
/// **Dart Source:** `gesture_settings.dart:23-56`
public struct DeviceGestureSettings: Hashable, CustomStringConvertible {
    /// Create a new DeviceGestureSettings with configured settings in logical pixels.
    ///
    /// **Dart Source:** `gesture_settings.dart:26`
    public init(touchSlop: Double? = nil) {
        self.touchSlop = touchSlop
    }

    /// Creates a DeviceGestureSettings from the given FlutterView by converting
    /// the physical touch slop into logical pixels using the device pixel ratio.
    ///
    /// **Dart Source:** `gesture_settings.dart:29-34`
    public static func fromView(_ view: FlutterView) -> DeviceGestureSettings {
        let physicalTouchSlop = view.gestureSettings.physicalTouchSlop
        return DeviceGestureSettings(
            touchSlop: physicalTouchSlop.map { $0 / view.devicePixelRatio }
        )
    }

    /// The touch slop value in logical pixels, or `nil` if it was not set.
    ///
    /// **Dart Source:** `gesture_settings.dart:37`
    public let touchSlop: Double?

    /// The touch slop value for pan gestures, in logical pixels, or `nil` if it
    /// was not set.
    ///
    /// **Dart Source:** `gesture_settings.dart:41`
    public var panSlop: Double? {
        touchSlop.map { $0 * 2 }
    }

    // MARK: - Hashable

    /// **Dart Source:** `gesture_settings.dart:44`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(touchSlop)
        hasher.combine(23)
    }

    // MARK: - Equatable

    /// **Dart Source:** `gesture_settings.dart:47-52`
    public static func == (lhs: DeviceGestureSettings, rhs: DeviceGestureSettings) -> Bool {
        lhs.touchSlop == rhs.touchSlop
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `gesture_settings.dart:55`
    public var description: String {
        "DeviceGestureSettings(touchSlop: \(touchSlop.map { String($0) } ?? "nil"))"
    }
}
