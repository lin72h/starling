// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - Simulation
/// The base class for all simulations.
///
/// A simulation models an object, in a one-dimensional space, on which particular
/// forces are being applied, and exposes:
///
///  * The object's position, `x(_:)`
///  * The object's velocity, `dx(_:)`
///  * Whether the simulation is "done", `isDone(_:)`
///
/// A simulation is generally "done" if the object has, to a given `tolerance`,
/// come to a complete rest.
///
/// The `x(_:)`, `dx(_:)`, and `isDone(_:)` functions take a time argument which specifies
/// the time for which they are to be evaluated. In principle, simulations can
/// be stateless, and thus can be queried with arbitrary times. In practice,
/// however, some simulations are not, and calling any of these functions will
/// advance the simulation to the given time.
///
/// As a general rule, therefore, a simulation should only be queried using
/// times that are equal to or greater than all times previously used for that
/// simulation.
///
/// Simulations do not specify units for distance, velocity, and time. Client
/// should establish a convention and use that convention consistently with all
/// related objects.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/simulation.dart`
/// **Original Name:** `Simulation`
/// **Lines:** 36-60
open class Simulation: CustomStringConvertible {
    /// How close to the actual end of the simulation a value at a particular time
    /// must be before `isDone(_:)` considers the simulation to be "done".
    ///
    /// A simulation with an asymptotic curve would never technically be "done",
    /// but once the difference from the value at a particular time and the
    /// asymptote itself could not be seen, it would be pointless to continue. The
    /// tolerance defines how to determine if the difference could not be seen.
    ///
    /// **Dart Source:** `simulation.dart:49-56`
    public var tolerance: Tolerance

    /// Initializes the `tolerance` field for subclasses.
    ///
    /// **Dart Source:** `simulation.dart:37-38`
    public init(tolerance: Tolerance = .defaultTolerance) {
        self.tolerance = tolerance
    }

    /// The position of the object in the simulation at the given time.
    ///
    /// Subclasses must override this method.
    ///
    /// **Dart Source:** `simulation.dart:40-41`
    open func x(_ time: Double) -> Double {
        fatalError("Subclasses must implement x(_:)")
    }

    /// The velocity of the object in the simulation at the given time.
    ///
    /// Subclasses must override this method.
    ///
    /// **Dart Source:** `simulation.dart:43-44`
    open func dx(_ time: Double) -> Double {
        fatalError("Subclasses must implement dx(_:)")
    }

    /// Whether the simulation is "done" at the given time.
    ///
    /// Subclasses must override this method.
    ///
    /// **Dart Source:** `simulation.dart:46-47`
    open func isDone(_ time: Double) -> Bool {
        fatalError("Subclasses must implement isDone(_:)")
    }

    /// **Dart Source:** `simulation.dart:58-59`
    public var description: String {
        objectRuntimeType(self, "Simulation")
    }
}
