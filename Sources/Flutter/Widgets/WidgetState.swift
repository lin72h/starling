// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - WidgetStatesConstraint

/// Interface for objects that can be used as keys in a `WidgetStateMap`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:27-47`
public protocol WidgetStatesConstraint: CustomStringConvertible {
    /// Whether this constraint is satisfied by the given set of states.
    func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool
}

// MARK: - Constraint Combinators (internal)

/// Base for AND/OR constraint combinators.
///
/// **Dart Source:** `widget_state.dart:49-59`
class _WidgetStateCombo: WidgetStatesConstraint {
    let first: any WidgetStatesConstraint
    let second: any WidgetStatesConstraint

    init(_ first: any WidgetStatesConstraint, _ second: any WidgetStatesConstraint) {
        self.first = first
        self.second = second
    }

    func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool {
        fatalError("Subclass must override")
    }

    var description: String { fatalError("Subclass must override") }
}

/// Logical AND of two constraints.
///
/// **Dart Source:** `widget_state.dart:61-77`
class _WidgetStateAnd: _WidgetStateCombo {
    override func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool {
        first.isSatisfiedBy(states) && second.isSatisfiedBy(states)
    }

    override var description: String { "(\(first) & \(second))" }
}

/// Logical OR of two constraints.
///
/// **Dart Source:** `widget_state.dart:79-95`
class _WidgetStateOr: _WidgetStateCombo {
    override func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool {
        first.isSatisfiedBy(states) || second.isSatisfiedBy(states)
    }

    override var description: String { "(\(first) | \(second))" }
}

/// Logical NOT of a constraint.
///
/// **Dart Source:** `widget_state.dart:97-116`
class _WidgetStateNot: WidgetStatesConstraint {
    let constraint: any WidgetStatesConstraint

    init(_ constraint: any WidgetStatesConstraint) {
        self.constraint = constraint
    }

    func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool {
        !constraint.isSatisfiedBy(states)
    }

    var description: String { "~\(constraint)" }
}

// MARK: - WidgetStatesConstraint Operators

/// Operators for combining constraints.
///
/// **Dart Source:** `widget_state.dart:128-137`
public func & (lhs: any WidgetStatesConstraint, rhs: any WidgetStatesConstraint) -> any WidgetStatesConstraint {
    _WidgetStateAnd(lhs, rhs)
}

public func | (lhs: any WidgetStatesConstraint, rhs: any WidgetStatesConstraint) -> any WidgetStatesConstraint {
    _WidgetStateOr(lhs, rhs)
}

public prefix func ~ (value: any WidgetStatesConstraint) -> any WidgetStatesConstraint {
    _WidgetStateNot(value)
}

// MARK: - _AnyWidgetStates

/// A constraint that is always satisfied.
///
/// **Dart Source:** `widget_state.dart:140-148`
class _AnyWidgetStates: WidgetStatesConstraint {
    func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool { true }
    var description: String { "WidgetState.any" }
}

// MARK: - WidgetState

/// Enum of interactive states that a widget can be in.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:180-241`
public enum WidgetState: Hashable, Sendable, WidgetStatesConstraint {
    case hovered
    case focused
    case pressed
    case dragged
    case selected
    case scrolledUnder
    case disabled
    case error

    /// A constraint that matches any set of states (always true).
    ///
    /// **Dart Source:** `widget_state.dart:234`
    public static var any: any WidgetStatesConstraint { _AnyWidgetStates() }

    /// **Dart Source:** `widget_state.dart:237`
    public func isSatisfiedBy(_ states: Set<WidgetState>) -> Bool {
        states.contains(self)
    }

    /// **Dart Source:** `widget_state.dart:240`
    public var description: String { "\(self)" }
}

// MARK: - WidgetPropertyResolver

/// Signature for a callback that resolves a value based on widget states.
///
/// **Dart Source:** `widget_state.dart:245`
public typealias WidgetPropertyResolver<T> = (Set<WidgetState>) -> T

// MARK: - WidgetStateMap

/// A list of constraint-value pairs used to resolve a value based on widget states.
///
/// In Dart this is `Map<WidgetStatesConstraint, T>`, but since Swift protocol
/// existentials cannot conform to `Hashable`, we use an ordered array of tuples.
/// The first entry whose constraint is satisfied wins.
///
/// **Dart Source:** `widget_state.dart:967`
public typealias WidgetStateMap<T> = [(constraint: any WidgetStatesConstraint, value: T)]

// MARK: - WidgetStateProperty

/// Interface for classes that resolve to a value of type `T` based
/// on a widget's interactive "state".
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:809-880`
public protocol WidgetStateProperty<T> {
    associatedtype T

    /// Returns a value of type `T` that depends on the given set of states.
    ///
    /// **Dart Source:** `widget_state.dart:879`
    func resolve(_ states: Set<WidgetState>) -> T
}

/// Static convenience methods for `WidgetStateProperty`.
///
/// **Dart Source:** `widget_state.dart:836-858`
public enum WidgetStatePropertyHelper {
    /// Resolves the value for the given set of states if `value` conforms to
    /// `WidgetStateProperty`, otherwise returns the value itself.
    ///
    /// **Dart Source:** `widget_state.dart:836-842`
    public static func resolveAs<T>(_ value: T, states: Set<WidgetState>) -> T {
        if let property = value as? any WidgetStateProperty {
            if let resolved = property.resolve(states) as? T {
                return resolved
            }
        }
        return value
    }

    /// Creates a `WidgetStateProperty` from a resolver callback.
    ///
    /// **Dart Source:** `widget_state.dart:846-847`
    public static func resolveWith<T>(_ callback: @escaping WidgetPropertyResolver<T>) -> some WidgetStateProperty<T> {
        _WidgetStatePropertyWith(callback)
    }

    /// Creates a `WidgetStateProperty` that resolves to a single value for all states.
    ///
    /// **Dart Source:** `widget_state.dart:858`
    public static func all<T>(_ value: T) -> WidgetStatePropertyAll<T> {
        WidgetStatePropertyAll(value)
    }
}

// MARK: - _WidgetStatePropertyWith (internal)

/// **Dart Source:** `widget_state.dart:898-905`
class _WidgetStatePropertyWith<T>: WidgetStateProperty {
    init(_ resolve: @escaping WidgetPropertyResolver<T>) {
        self._resolve = resolve
    }

    private let _resolve: WidgetPropertyResolver<T>

    func resolve(_ states: Set<WidgetState>) -> T {
        _resolve(states)
    }
}

// MARK: - _LerpProperties (internal)

/// **Dart Source:** `widget_state.dart:882-896`
class _LerpProperties<T>: WidgetStateProperty {
    init(
        _ a: (any WidgetStateProperty<T>)?,
        _ b: (any WidgetStateProperty<T>)?,
        _ t: Double,
        _ lerpFunction: @escaping (T?, T?, Double) -> T?
    ) {
        self.a = a
        self.b = b
        self.t = t
        self.lerpFunction = lerpFunction
    }

    let a: (any WidgetStateProperty<T>)?
    let b: (any WidgetStateProperty<T>)?
    let t: Double
    let lerpFunction: (T?, T?, Double) -> T?

    func resolve(_ states: Set<WidgetState>) -> T? {
        let resolvedA: T? = a?.resolve(states)
        let resolvedB: T? = b?.resolve(states)
        return lerpFunction(resolvedA, resolvedB, t)
    }
}

// MARK: - WidgetStateMapper

/// Uses a `WidgetStateMap` to resolve to a single value of type `T` based on
/// the current set of widget states.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:988-1055`
public class WidgetStateMapper<T>: WidgetStateProperty, CustomStringConvertible {
    /// Creates a `WidgetStateProperty` that resolves using the provided map.
    ///
    /// **Dart Source:** `widget_state.dart:991`
    public init(_ map: WidgetStateMap<T>) {
        self._map = map
    }

    private let _map: WidgetStateMap<T>

    /// **Dart Source:** `widget_state.dart:996-1014`
    public func resolve(_ states: Set<WidgetState>) -> T {
        for entry in _map {
            if entry.constraint.isSatisfiedBy(states) {
                return entry.value
            }
        }
        // In Dart, this returns `null as T` which throws if T is non-nullable.
        // In Swift, we fatalError since we can't return nil for non-Optional T.
        fatalError(
            "The current set of widget states is \(states).\n"
            + "None of the provided map keys matched this set.\n"
            + "Consider adding the WidgetState.any key to this map."
        )
    }

    /// **Dart Source:** `widget_state.dart:1025-1027`
    public var description: String {
        "WidgetStateMapper(\(_map))"
    }
}

// MARK: - WidgetStatePropertyAll

/// A `WidgetStateProperty` that resolves to the given value for all states.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:1065-1094`
public class WidgetStatePropertyAll<T>: WidgetStateProperty, CustomStringConvertible {
    /// Creates a `WidgetStateProperty` that always resolves to the given value.
    ///
    /// **Dart Source:** `widget_state.dart:1068`
    public init(_ value: T) {
        self.value = value
    }

    /// The value of the property that will be used for all states.
    ///
    /// **Dart Source:** `widget_state.dart:1071`
    public let value: T

    /// **Dart Source:** `widget_state.dart:1074`
    public func resolve(_ states: Set<WidgetState>) -> T {
        value
    }

    /// **Dart Source:** `widget_state.dart:1077-1083`
    public var description: String {
        if let doubleValue = value as? Double {
            return "WidgetStatePropertyAll(\(debugFormatDouble(doubleValue)))"
        }
        return "WidgetStatePropertyAll(\(value))"
    }
}

// MARK: - WidgetStatesController

/// Manages a set of `WidgetState`s and notifies listeners of changes.
///
/// Used by widgets that expose their internal state for the sake of
/// extensions that add support for additional states.
///
/// The controller's `value` is its current set of states. Listeners
/// are notified whenever the `value` changes. The `value` should only be
/// changed with `update`; it should not be modified directly.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/widget_state.dart:1128-1140`
public class WidgetStatesController: ValueNotifier<Set<WidgetState>> {
    /// Creates a WidgetStatesController.
    ///
    /// **Dart Source:** `widget_state.dart:1130`
    public override init(_ value: Set<WidgetState>) {
        super.init(value)
    }

    /// Creates a WidgetStatesController with an empty set of states.
    public convenience init() {
        self.init(Set<WidgetState>())
    }

    /// Adds `state` to `value` if `add` is true, and removes it otherwise,
    /// and notifies listeners if `value` has changed.
    ///
    /// **Dart Source:** `widget_state.dart:1134-1139`
    public func update(_ state: WidgetState, _ add: Bool) {
        // Build new set to avoid double-notification from value setter + explicit notify.
        // ValueNotifier.value setter already calls notifyListeners() if the value changed.
        var newValue = value
        let valueChanged: Bool
        if add {
            let (inserted, _) = newValue.insert(state)
            valueChanged = inserted
        } else {
            valueChanged = newValue.remove(state) != nil
        }
        if valueChanged {
            value = newValue  // triggers notifyListeners() via setter
        }
    }
}
