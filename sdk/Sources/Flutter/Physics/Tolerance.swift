// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - Tolerance
/// Structure that specifies maximum allowable magnitudes for distances,
/// durations, and velocity differences to be considered equal.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/tolerance.dart`
/// **Original Name:** `Tolerance`
/// **Lines:** 9-49
public struct Tolerance: Hashable, Sendable, CustomStringConvertible {
    /// Private default epsilon value
    /// **Dart Source:** `tolerance.dart:20`
    private static let epsilonDefault: Double = 1e-3

    /// A default tolerance of 0.001 for all three values.
    ///
    /// **Dart Source:** `tolerance.dart:23`
    public static let defaultTolerance = Tolerance()

    /// The magnitude of the maximum distance between two points for them to be
    /// considered within tolerance.
    ///
    /// The units for the distance tolerance must be the same as the units used
    /// for the distances that are to be compared to this tolerance.
    ///
    /// **Dart Source:** `tolerance.dart:25-30`
    public let distance: Double

    /// The magnitude of the maximum duration between two times for them to be
    /// considered within tolerance.
    ///
    /// The units for the time tolerance must be the same as the units used
    /// for the times that are to be compared to this tolerance.
    ///
    /// **Dart Source:** `tolerance.dart:32-37`
    public let time: Double

    /// The magnitude of the maximum difference between two velocities for them to
    /// be considered within tolerance.
    ///
    /// The units for the velocity tolerance must be the same as the units used
    /// for the velocities that are to be compared to this tolerance.
    ///
    /// **Dart Source:** `tolerance.dart:39-44`
    public let velocity: Double

    /// Creates a Tolerance object. By default, the distance, time, and velocity
    /// tolerances are all ±0.001; the constructor arguments override this.
    ///
    /// The arguments should all be positive values.
    ///
    /// **Dart Source:** `tolerance.dart:10-18`
    public init(
        distance: Double = 1e-3,
        time: Double = 1e-3,
        velocity: Double = 1e-3
    ) {
        self.distance = distance
        self.time = time
        self.velocity = velocity
    }

    /// **Dart Source:** `tolerance.dart:46-48`
    public var description: String {
        "\(objectRuntimeType(self, "Tolerance"))(distance: ±\(distance), time: ±\(time), velocity: ±\(velocity))"
    }
}
