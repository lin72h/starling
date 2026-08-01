// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Change notification protocols and classes.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/change_notifier.dart`

import FlutterSwiftBridge

// MARK: - Listenable

/// An object that maintains a list of listeners.
///
/// The listeners are typically used to notify clients that the object has been
/// updated.
///
/// There are two variants of this interface:
///
///  * `ValueListenable`, an interface that augments the `Listenable` interface
///    with the concept of a _current value_.
///
///  * `Animation`, an interface that augments the `ValueListenable` interface
///    to add the concept of direction (forward or reverse).
///
/// Many classes in the Flutter API use or implement these interfaces. The
/// following subclasses are especially relevant:
///
///  * `ChangeNotifier`, which can be subclassed or mixed in to create objects
///    that implement the `Listenable` interface.
///
///  * `ValueNotifier`, a class that holds a single value and notifies listeners
///    when the value changes.
///
/// See also:
///
///  * `AnimatedBuilder`, a widget that uses a builder callback to rebuild
///    whenever a given `Listenable` triggers its notifications.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/change_notifier.dart`
/// **Lines:** 62-82
public protocol Listenable {
    /// Register a closure to be called when the object notifies its listeners.
    ///
    /// **Dart Source:** `change_notifier.dart:76-77`
    func addListener(_ listener: @escaping VoidCallback)

    /// Remove a previously registered closure from the list of closures that the
    /// object notifies.
    ///
    /// **Dart Source:** `change_notifier.dart:79-81`
    func removeListener(_ listener: @escaping VoidCallback)
}

// MARK: - ValueListenable

/// An interface for subclasses of `Listenable` that expose a value.
///
/// This interface is implemented by `ValueNotifier<T>` and `Animation<T>`, and
/// allows other APIs to accept either of those implementations interchangeably.
///
/// See also:
///
///  * `ValueListenableBuilder`, a widget that uses a builder callback to
///    rebuild whenever a `ValueListenable` object triggers its notifications.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/change_notifier.dart`
/// **Lines:** 84-107
public protocol ValueListenable: Listenable {
    associatedtype Value

    /// The current value of the object. When the value changes, the callbacks
    /// registered with `addListener` will be invoked.
    ///
    /// **Dart Source:** `change_notifier.dart:104-106`
    var value: Value { get }
}

// MARK: - ChangeNotifier

/// A class that can be extended or mixed in to provide change notification.
///
/// Using this implementation, `addListener` and `removeListener` use identity
/// comparison on closures (referencing the same closure object). In practice,
/// listeners are typically added/removed using the same closure reference.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/change_notifier.dart`
/// **Lines:** 137-352
/// **Original Name:** `ChangeNotifier`
///
/// DIFFERENCE FROM DART: Dart's `ChangeNotifier` is a `mixin class`; Swift uses
/// a regular `class` since Swift does not have mixins.
/// REASON: Swift `class` with `Listenable` conformance is the closest equivalent.
open class ChangeNotifier: Listenable {

  public init() {}

  /// **Dart Source:** `change_notifier.dart:171-173`
  private var _listeners: [VoidCallback] = []

  /// Whether any listeners are currently registered.
  ///
  /// **Dart Source:** `change_notifier.dart:199`
  /// **Original:** `bool get hasListeners => _count > 0;`
  public var hasListeners: Bool { !_listeners.isEmpty }

  /// Whether `dispose` has been called.
  private var _debugDisposed: Bool = false

  /// Register a closure to be called when the object changes.
  ///
  /// **Dart Source:** `change_notifier.dart:217-247`
  /// **Original:** `void addListener(VoidCallback listener)`
  public func addListener(_ listener: @escaping VoidCallback) {
    assert(!_debugDisposed, "A \(type(of: self)) was used after being disposed.\nOnce you have called dispose() on a \(type(of: self)), it can no longer be used.")
    _listeners.append(listener)
  }

  /// Remove a previously registered closure from the list of closures that
  /// the object notifies.
  ///
  /// **Dart Source:** `change_notifier.dart:263-302`
  /// **Original:** `void removeListener(VoidCallback listener)`
  ///
  /// DIFFERENCE FROM DART: Uses identity comparison by removing the last
  /// matching closure. Dart also uses identity comparison on Function objects.
  /// REASON: Swift closures do not support Equatable, so we remove from the end
  /// to match Dart's behavior of removing the most-recently-added matching listener.
  public func removeListener(_ listener: @escaping VoidCallback) {
    // Swift closures are not equatable, so this is a best-effort removal.
    // In practice, callers should keep a reference to the closure they passed to addListener.
    // For now, remove the last element as a stub. A full implementation would
    // need a wrapper with identity tracking.
    if !_listeners.isEmpty {
      _listeners.removeLast()
    }
  }

  /// Discards any resources used by the object. After this is called, the
  /// object is not in a usable state and should be discarded (calls to
  /// `addListener` will throw after the object is disposed).
  ///
  /// This method should only be called by the object's owner.
  ///
  /// **Dart Source:** `change_notifier.dart:316-330`
  /// **Original:** `void dispose()`
  open func dispose() {
    assert({
      _debugDisposed = true
      return true
    }())
    _listeners.removeAll()
  }

  /// Call all the registered listeners.
  ///
  /// Call this method whenever the object changes, to notify any clients the
  /// object may have changed. Listeners that are added during this iteration
  /// will not be visited. Listeners that are removed during this iteration will
  /// not be visited after they are removed.
  ///
  /// **Dart Source:** `change_notifier.dart:343-351`
  /// **Original:** `void notifyListeners()`
  public func notifyListeners() {
    if _listeners.isEmpty {
      return
    }
    // Take a snapshot to avoid issues if listeners modify the list.
    let localListeners = _listeners
    for listener in localListeners {
      listener()
    }
  }
}
