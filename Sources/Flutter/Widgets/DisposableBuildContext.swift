// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - DisposableBuildContext

/// Provides non-leaking access to a `BuildContext`.
///
/// A `BuildContext` is only valid if it is pointing to an active `Element`.
/// Once the `Element` is unmounted, the `BuildContext` should not be accessed
/// further. This class makes it possible for a `StatefulWidget` to share its
/// build context safely with other objects.
///
/// Creators of this object must guarantee the following:
///
///   1. They create this object at or after `State.initState` but before
///      `State.dispose`. In particular, do not attempt to create this from the
///      constructor of a state.
///   2. They call `dispose` from `State.dispose`.
///
/// This object will not hold on to the `State` after disposal.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/disposable_build_context.dart:25-75`
public class DisposableBuildContext<T: State<StatefulWidget>> {

    /// Creates an object that provides access to a `BuildContext` without leaking
    /// a `State`.
    ///
    /// Creators must call `dispose` when the `State` is disposed.
    ///
    /// `State.mounted` must be true.
    ///
    /// **Dart Source:** `disposable_build_context.dart:32-38`
    public init(_ state: T) {
        assert(
            state.mounted,
            "A DisposableBuildContext was given a BuildContext for an Element that is not mounted."
        )
        self._state = state
    }

    private var _state: T?

    /// Provides safe access to the build context.
    ///
    /// If `dispose` has been called, will return nil.
    ///
    /// Otherwise, asserts the `_state` is still mounted and returns its context.
    ///
    /// **Dart Source:** `disposable_build_context.dart:47-50`
    public var context: (any BuildContext)? {
        assert(_debugValidate())
        return _state?.context
    }

    /// Called from asserts or tests to determine whether this object is in a
    /// valid state.
    ///
    /// Always returns true, but will assert if `dispose` has not been called
    /// but the state this is tracking is unmounted.
    ///
    /// **Dart Source:** `disposable_build_context.dart:57-65`
    private func _debugValidate() -> Bool {
        assert(
            _state == nil || _state!.mounted,
            "A DisposableBuildContext tried to access the BuildContext of a disposed "
            + "State object. This can happen when the creator of this "
            + "DisposableBuildContext fails to call dispose when it is disposed."
        )
        return true
    }

    /// Marks the `BuildContext` as disposed.
    ///
    /// Creators of this object must call `dispose` when their `Element` is
    /// unmounted, i.e. when `State.dispose` is called.
    ///
    /// **Dart Source:** `disposable_build_context.dart:71-74`
    public func dispose() {
        _state = nil
    }
}
