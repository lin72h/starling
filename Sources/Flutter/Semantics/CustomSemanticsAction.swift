// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An identifier of a custom semantics action.
///
/// Custom semantics actions can be provided to make complex user
/// interactions more accessible. For instance, if an application has a
/// drag-and-drop list that requires the user to press and hold an item
/// to move it, users interacting with the application using a hardware
/// switch may have difficulty. This can be made accessible by creating custom
/// actions and pairing them with handlers that move a list item up or down in
/// the list.
///
/// In Android, these actions are presented in the local context menu. In iOS,
/// these are presented in the radial context menu.
///
/// Localization and text direction do not automatically apply to the provided
/// label or hint.
///
/// Instances of this class should either be instantiated with const or
/// new instances cached in static fields.
///
/// See also:
///
///  * `SemanticsProperties`, where the handler for a custom action is provided.
///
/// **Dart Source:** `semantics.dart:616-718`
/// **Original Name:** `CustomSemanticsAction`

import FlutterSwiftBridge

// MARK: - CustomSemanticsAction

// DIFFERENCE FROM DART: Uses a Swift `struct` instead of Dart `@immutable class`.
// REASON: Dart's `@immutable` annotation indicates value semantics, which Swift
// structs provide natively. A struct is the idiomatic Swift choice for an
// immutable value type.
public struct CustomSemanticsAction: Hashable, CustomStringConvertible, Sendable {

  // MARK: - Initializers

  /// Creates a new `CustomSemanticsAction`.
  ///
  /// The `label` must not be empty.
  ///
  /// **Dart Source:** `semantics.dart:640-646`
  /// **Original:** `const CustomSemanticsAction({required String this.label})`
  public init(label: String) {
    assert(!label.isEmpty, "CustomSemanticsAction label must not be empty")
    self.label = label
    self.hint = nil
    self.action = nil
  }

  /// Creates a new `CustomSemanticsAction` that overrides a standard semantics
  /// action.
  ///
  /// The `hint` must not be empty.
  ///
  /// **Dart Source:** `semantics.dart:648-656`
  /// **Original:** `const CustomSemanticsAction.overridingAction({required String this.hint, required SemanticsAction this.action})`
  // DIFFERENCE FROM DART: Named constructor becomes a separate `init` with
  // argument labels `overridingHint:action:`.
  // REASON: Swift does not have Dart's named constructor syntax. Using
  // descriptive argument labels provides equivalent clarity.
  public init(overridingHint hint: String, action: SemanticsAction) {
    assert(!hint.isEmpty, "CustomSemanticsAction hint must not be empty")
    self.label = nil
    self.hint = hint
    self.action = action
  }

  // MARK: - Properties

  /// The user readable name of this custom semantics action.
  ///
  /// **Dart Source:** `semantics.dart:659`
  public let label: String?

  /// The hint description of this custom semantics action.
  ///
  /// **Dart Source:** `semantics.dart:662`
  public let hint: String?

  /// The standard semantics action this action replaces.
  ///
  /// **Dart Source:** `semantics.dart:665`
  public let action: SemanticsAction?

  // MARK: - Hashable

  /// **Dart Source:** `semantics.dart:668`
  /// **Original:** `int get hashCode => Object.hash(label, hint, action);`
  public func hash(into hasher: inout Hasher) {
    hasher.combine(label)
    hasher.combine(hint)
    hasher.combine(action)
  }

  /// **Dart Source:** `semantics.dart:670-679`
  /// **Original:** `bool operator ==(Object other)`
  public static func == (lhs: CustomSemanticsAction, rhs: CustomSemanticsAction) -> Bool {
    lhs.label == rhs.label
      && lhs.hint == rhs.hint
      && lhs.action == rhs.action
  }

  // MARK: - CustomStringConvertible

  /// **Dart Source:** `semantics.dart:681-684`
  /// **Original:** `String toString() => 'CustomSemanticsAction(${_ids[this]}, label:$label, hint:$hint, action:$action)';`
  // DIFFERENCE FROM DART: Uses Swift's `CustomStringConvertible` protocol
  // conformance (`description`) instead of overriding `toString()`.
  // REASON: Swift convention for string representation is `description` via
  // `CustomStringConvertible`.
  public var description: String {
    let id = CustomSemanticsAction._ids[self]
    let idStr = id.map(String.init) ?? "nil"
    return "CustomSemanticsAction(\(idStr), label:\(label ?? "nil"), hint:\(hint ?? "nil"), action:\(action.map(String.init(describing:)) ?? "nil"))"
  }

  // MARK: - Static ID Management

  /// **Dart Source:** `semantics.dart:688`
  // DIFFERENCE FROM DART: Uses `nonisolated(unsafe)` for mutable static state.
  // REASON: Swift 6 strict concurrency requires explicit annotation for
  // static mutable state that is not actor-isolated. The Dart original has no
  // thread-safety guarantees either.
  nonisolated(unsafe) private static var _nextId: Int = 0

  /// **Dart Source:** `semantics.dart:689`
  nonisolated(unsafe) private static var _actions: [Int: CustomSemanticsAction] = [:]

  /// **Dart Source:** `semantics.dart:690`
  nonisolated(unsafe) private static var _ids: [CustomSemanticsAction: Int] = [:]

  /// Get the identifier for a given `action`.
  ///
  /// **Dart Source:** `semantics.dart:693-701`
  /// **Original:** `static int getIdentifier(CustomSemanticsAction action)`
  public static func getIdentifier(_ action: CustomSemanticsAction) -> Int {
    if let result = _ids[action] {
      return result
    }
    let result = _nextId
    _nextId += 1
    _ids[action] = result
    _actions[result] = action
    return result
  }

  /// Get the `action` for a given identifier.
  ///
  /// **Dart Source:** `semantics.dart:704-706`
  /// **Original:** `static CustomSemanticsAction? getAction(int id)`
  public static func getAction(_ id: Int) -> CustomSemanticsAction? {
    return _actions[id]
  }

  /// Resets internal state between tests. Does nothing if asserts are disabled.
  ///
  /// **Dart Source:** `semantics.dart:708-717`
  /// **Original:** `static void resetForTests()`
  // DIFFERENCE FROM DART: In Dart, the body is wrapped in `assert(() { ... }())`
  // so it only runs in debug mode. In Swift, we always reset because Swift does
  // not have a direct equivalent of Dart's assert-only execution blocks, and this
  // method is only intended for test usage.
  public static func resetForTests() {
    _actions.removeAll()
    _ids.removeAll()
    _nextId = 0
  }
}
