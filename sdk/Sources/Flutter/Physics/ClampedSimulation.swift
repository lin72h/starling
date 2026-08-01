// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ClampedSimulation

/// A simulation that applies limits to another simulation.
///
/// The limits are only applied to the other simulation's outputs. For example,
/// if a maximum position was applied to a gravity simulation with the
/// particle's initial velocity being up, and the acceleration being down, and
/// the maximum position being between the initial position and the curve's
/// apogee, then the particle would return to its initial position in the same
/// amount of time as it would have if the maximum had not been applied; the
/// difference would just be that the position would be reported as pinned to
/// the maximum value for the times that it would otherwise have been reported
/// as higher.
///
/// Similarly, this means that the `x(_:)` value will change at a rate that does not
/// match the reported `dx(_:)` value while one or the other is being clamped.
///
/// The `isDone(_:)` logic is unaffected by the clamping; it reflects the logic of
/// the underlying simulation.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/clamped_simulation.dart`
/// **Original Name:** `ClampedSimulation`
/// **Lines:** 28-70
public final class ClampedSimulation: Simulation {

    /// Creates a `ClampedSimulation` that clamps the given simulation.
    ///
    /// The named arguments specify the ranges for the clamping behavior, as
    /// applied to `x(_:)` and `dx(_:)`.
    ///
    /// **Dart Source:** `clamped_simulation.dart:33-40`
    public init(
        _ simulation: Simulation,
        xMin: Double = -.infinity,
        xMax: Double = .infinity,
        dxMin: Double = -.infinity,
        dxMax: Double = .infinity
    ) {
        assert(xMax >= xMin, "xMax must be >= xMin")
        assert(dxMax >= dxMin, "dxMax must be >= dxMin")
        self.simulation = simulation
        self.xMin = xMin
        self.xMax = xMax
        self.dxMin = dxMin
        self.dxMax = dxMax
        super.init()
    }

    /// The simulation being clamped. Calls to `x(_:)`, `dx(_:)`, and `isDone(_:)` are
    /// forwarded to the simulation.
    ///
    /// **Dart Source:** `clamped_simulation.dart:42-44`
    public let simulation: Simulation

    /// The minimum to apply to `x(_:)`.
    ///
    /// **Dart Source:** `clamped_simulation.dart:46-47`
    public let xMin: Double

    /// The maximum to apply to `x(_:)`.
    ///
    /// **Dart Source:** `clamped_simulation.dart:49-50`
    public let xMax: Double

    /// The minimum to apply to `dx(_:)`.
    ///
    /// **Dart Source:** `clamped_simulation.dart:52-53`
    public let dxMin: Double

    /// The maximum to apply to `dx(_:)`.
    ///
    /// **Dart Source:** `clamped_simulation.dart:55-56`
    public let dxMax: Double

    /// **Dart Source:** `clamped_simulation.dart:58-59`
    public override func x(_ time: Double) -> Double {
        clampDouble(simulation.x(time), xMin, xMax)
    }

    /// **Dart Source:** `clamped_simulation.dart:61-62`
    public override func dx(_ time: Double) -> Double {
        clampDouble(simulation.dx(time), dxMin, dxMax)
    }

    /// **Dart Source:** `clamped_simulation.dart:64-65`
    public override func isDone(_ time: Double) -> Bool {
        simulation.isDone(time)
    }

    /// **Dart Source:** `clamped_simulation.dart:67-69`
    public override var description: String {
        let xMinStr = String(format: "%.1f", xMin)
        let xMaxStr = String(format: "%.1f", xMax)
        let dxMinStr = String(format: "%.1f", dxMin)
        let dxMaxStr = String(format: "%.1f", dxMax)
        return "\(objectRuntimeType(self, "ClampedSimulation"))(simulation: \(simulation), x: \(xMinStr)..\(xMaxStr), dx: \(dxMinStr)..\(dxMaxStr))"
    }
}
