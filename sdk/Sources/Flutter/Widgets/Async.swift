// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - ConnectionState

/// The state of connection to an asynchronous computation.
///
/// The usual flow of state is as follows:
///
/// 1. `none`, maybe with some initial data.
/// 2. `waiting`, indicating that the asynchronous operation has begun,
///    typically with the data being null.
/// 3. `active`, with data being non-null, and possibly changing over time.
/// 4. `done`, with data being non-null.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/async.dart:176-193`
public enum ConnectionState: Sendable {
    /// Not currently connected to any asynchronous computation.
    ///
    /// **Dart Source:** `async.dart:180`
    case none

    /// Connected to an asynchronous computation and awaiting interaction.
    ///
    /// **Dart Source:** `async.dart:183`
    case waiting

    /// Connected to an active asynchronous computation.
    ///
    /// **Dart Source:** `async.dart:189`
    case active

    /// Connected to a terminated asynchronous computation.
    ///
    /// **Dart Source:** `async.dart:192`
    case done
}

// MARK: - AsyncSnapshot

/// Immutable representation of the most recent interaction with an asynchronous
/// computation.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/async.dart:205-315`
public struct AsyncSnapshot<T> {

    // MARK: - Private Initializer

    /// **Dart Source:** `async.dart:209-211`
    private init(
        connectionState: ConnectionState,
        data: T?,
        error: (any Error)?,
        stackTrace: String?
    ) {
        assert(data == nil || error == nil)
        assert(stackTrace == nil || error != nil)
        self.connectionState = connectionState
        self.data = data
        self.error = error
        self.stackTrace = stackTrace
    }

    // MARK: - Factory Constructors

    /// Creates an `AsyncSnapshot` in `ConnectionState.none` with null data and error.
    ///
    /// **Dart Source:** `async.dart:214`
    public static func nothing() -> AsyncSnapshot<T> {
        AsyncSnapshot(connectionState: .none, data: nil, error: nil, stackTrace: nil)
    }

    /// Creates an `AsyncSnapshot` in `ConnectionState.waiting` with null data and error.
    ///
    /// **Dart Source:** `async.dart:217`
    public static func waiting() -> AsyncSnapshot<T> {
        AsyncSnapshot(connectionState: .waiting, data: nil, error: nil, stackTrace: nil)
    }

    /// Creates an `AsyncSnapshot` in the specified state and with the specified data.
    ///
    /// **Dart Source:** `async.dart:220`
    public static func withData(_ state: ConnectionState, _ data: T) -> AsyncSnapshot<T> {
        AsyncSnapshot(connectionState: state, data: data, error: nil, stackTrace: nil)
    }

    /// Creates an `AsyncSnapshot` in the specified state with the specified error
    /// and an optional stack trace.
    ///
    /// **Dart Source:** `async.dart:226-230`
    public static func withError(
        _ state: ConnectionState,
        _ error: any Error,
        _ stackTrace: String? = nil
    ) -> AsyncSnapshot<T> {
        AsyncSnapshot(connectionState: state, data: nil, error: error, stackTrace: stackTrace ?? "")
    }

    // MARK: - Properties

    /// Current state of connection to the asynchronous computation.
    ///
    /// **Dart Source:** `async.dart:233`
    public let connectionState: ConnectionState

    /// The latest data received by the asynchronous computation.
    ///
    /// If this is non-nil, `hasData` will be true.
    ///
    /// **Dart Source:** `async.dart:244`
    public let data: T?

    /// The latest error received by the asynchronous computation.
    ///
    /// If this is non-nil, `hasError` will be true.
    ///
    /// **Dart Source:** `async.dart:265`
    public let error: (any Error)?

    /// The latest stack trace received by the asynchronous computation.
    ///
    /// This will not be nil if `error` is not nil.
    ///
    /// **Dart Source:** `async.dart:274`
    public let stackTrace: String?

    // MARK: - Computed Properties

    /// Returns latest data received, failing if there is no data.
    ///
    /// Throws the error if `hasError`. Throws a runtime error if neither
    /// `hasData` nor `hasError`.
    ///
    /// **Dart Source:** `async.dart:250-258`
    public var requireData: T {
        if hasData {
            return data!
        }
        if hasError {
            fatalError("AsyncSnapshot has error: \(error!)")
        }
        fatalError("Snapshot has neither data nor error")
    }

    /// Returns whether this snapshot contains a non-nil data value.
    ///
    /// **Dart Source:** `async.dart:289`
    public var hasData: Bool { data != nil }

    /// Returns whether this snapshot contains a non-nil error value.
    ///
    /// **Dart Source:** `async.dart:295`
    public var hasError: Bool { error != nil }

    // MARK: - Methods

    /// Returns a snapshot like this one, but in the specified state.
    ///
    /// The data, error, and stackTrace fields persist unmodified, even if the
    /// new state is `ConnectionState.none`.
    ///
    /// **Dart Source:** `async.dart:280-281`
    public func inState(_ state: ConnectionState) -> AsyncSnapshot<T> {
        AsyncSnapshot(connectionState: state, data: data, error: error, stackTrace: stackTrace)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `async.dart:298-299`
    public var description: String {
        "AsyncSnapshot(\(connectionState), \(String(describing: data)), \(String(describing: error)), \(String(describing: stackTrace)))"
    }
}

// MARK: - AsyncSnapshot + Equatable (conditional)

extension AsyncSnapshot: Equatable where T: Equatable {
    /// **Dart Source:** `async.dart:302-311`
    public static func == (lhs: AsyncSnapshot<T>, rhs: AsyncSnapshot<T>) -> Bool {
        lhs.connectionState == rhs.connectionState
            && lhs.data == rhs.data
            && lhs.hasError == rhs.hasError
            && lhs.stackTrace == rhs.stackTrace
    }
}

// MARK: - AsyncSnapshot + Hashable (conditional)

extension AsyncSnapshot: Hashable where T: Hashable {
    /// **Dart Source:** `async.dart:314`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(connectionState)
        hasher.combine(data)
        hasher.combine(hasError)
    }
}

// MARK: - AsyncWidgetBuilder

/// Signature for strategies that build widgets based on asynchronous
/// interaction.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/async.dart:326`
public typealias AsyncWidgetBuilder<T> = (any BuildContext, AsyncSnapshot<T>) -> Widget
