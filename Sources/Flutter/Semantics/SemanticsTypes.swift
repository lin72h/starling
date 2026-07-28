// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Semantics type aliases and simple types migrated from `semantics.dart`.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`

import FlutterSwiftBridge

// MARK: - Type Aliases

/// Signature for [SemanticsAction]s that move the cursor.
///
/// If `extendSelection` is set to true the cursor movement should extend the
/// current selection or (if nothing is currently selected) start a selection.
///
/// **Dart Source:** `semantics.dart:74-78`
/// **Original:** `typedef MoveCursorHandler = void Function(bool extendSelection);`
public typealias MoveCursorHandler = (Bool) -> Void

/// Signature for the [SemanticsAction.setText] handlers to replace the
/// current text with the input `text`.
///
/// **Dart Source:** `semantics.dart:84-86`
/// **Original:** `typedef SetTextHandler = void Function(String text);`
public typealias SetTextHandler = (String) -> Void

/// Signature for a handler of a [SemanticsAction].
///
/// Returned by [SemanticsConfiguration.getActionHandler].
///
/// **Dart Source:** `semantics.dart:92-95`
/// **Original:** `typedef SemanticsActionHandler = void Function(Object? args);`
// DIFFERENCE FROM DART: Uses `Any?` instead of `Object?`.
// REASON: Swift's `Any?` is the equivalent of Dart's `Object?` for representing
// any type including null/nil.
public typealias SemanticsActionHandler = (Any?) -> Void

/// Signature for the [SemanticsAction.setSelection] handlers to change the
/// text selection (or re-position the cursor) to `selection`.
///
/// **Dart Source:** `semantics.dart:80-82`
/// **Original:** `typedef SetSelectionHandler = void Function(TextSelection selection);`
public typealias SetSelectionHandler = (TextSelection) -> Void

/// Signature for the [SemanticsAction.scrollToOffset] handlers to scroll the
/// scrollable container to the given `targetOffset`.
///
/// **Dart Source:** `semantics.dart:88-90`
/// **Original:** `typedef ScrollToOffsetHandler = void Function(Offset targetOffset);`
public typealias ScrollToOffsetHandler = (Offset) -> Void

// Note: The following type aliases are deferred until their referenced types are defined:
// - SemanticsNodeVisitor (references SemanticsNode)              semantics.dart:72
// - SemanticsUpdateCallback (references SemanticsUpdate)         semantics.dart:97-100
// - ChildSemanticsConfigurationsDelegate -> defined in ChildSemanticsConfigurationsResult.swift

// MARK: - Constants

/// A bitmask of [SemanticsAction]s that are not blocked by user actions.
///
/// These are actions that do not require user interaction to be performed,
/// specifically gaining and losing accessibility focus.
///
/// **Dart Source:** `semantics.dart:117-119`
/// **Original:**
/// ```dart
/// final int _kUnblockedUserActions =
///     SemanticsAction.didGainAccessibilityFocus.index |
///     SemanticsAction.didLoseAccessibilityFocus.index;
/// ```
let _kUnblockedUserActions: Int =
  SemanticsAction.didGainAccessibilityFocus.index
  | SemanticsAction.didLoseAccessibilityFocus.index

// MARK: - SemanticsTag

/// A tag for a [SemanticsNode].
///
/// Tags can be interpreted by the parent of a [SemanticsNode]
/// and depending on the [SemanticsTag] they may for example decide
/// how to add the tagged node as a child. Tags are not sent to the engine.
///
/// As an example, the [RenderSemanticsGestureHandler] uses tags to determine
/// if a child node should be excluded from the scrollable area for semantic
/// purposes.
///
/// The provided [name] is only used for debugging. Two tags created with the
/// same [name] and the `new` keyword are not considered identical. However,
/// two tags created with the same [name] and the `const` keyword in Dart are
/// always identical.
///
/// **Dart Source:** `semantics.dart:511-527`
/// **Original Name:** `SemanticsTag`
// DIFFERENCE FROM DART: Uses a Swift class (reference type) instead of Dart const class.
// REASON: Dart's SemanticsTag relies on identity equality (two `new` SemanticsTag with the
// same name are NOT equal, but two `const` SemanticsTag with the same name ARE equal).
// Swift classes use reference identity by default, matching Dart's `new` behavior.
// Dart's `const` identity behavior cannot be replicated in Swift, but in practice
// SemanticsTag instances are compared by identity (===) rather than by value.
public final class SemanticsTag: CustomStringConvertible, Sendable {
  /// Creates a [SemanticsTag].
  ///
  /// The provided [name] is only used for debugging. Two tags created with the
  /// same [name] are not considered identical.
  ///
  /// **Dart Source:** `semantics.dart:518`
  /// **Original:** `const SemanticsTag(this.name);`
  public init(_ name: String) {
    self.name = name
  }

  /// A human-readable name for this tag used for debugging.
  ///
  /// This string is not used to determine if two tags are identical.
  ///
  /// **Dart Source:** `semantics.dart:523`
  public let name: String

  /// **Dart Source:** `semantics.dart:526`
  /// **Original:** `String toString() => '${objectRuntimeType(this, 'SemanticsTag')}($name)';`
  public var description: String {
    "SemanticsTag(\(name))"
  }
}

// MARK: - DebugSemanticsDumpOrder

/// Determines the order in which semantics nodes are printed in debug output.
///
/// **Dart Source:** `semantics.dart:6197-6210`
/// **Original Name:** `DebugSemanticsDumpOrder`
public enum DebugSemanticsDumpOrder: Sendable {
  /// Print nodes in inverse hit test order.
  ///
  /// In inverse hit test order, the last child of a [SemanticsNode] will be
  /// asked first if it wants to respond to a user's interaction, followed by
  /// the second last, etc. until a taker is found.
  ///
  /// **Dart Source:** `semantics.dart:6198-6203`
  case inverseHitTest

  /// Print nodes in semantic traversal order.
  ///
  /// This is the order in which a user would navigate the UI using the "next"
  /// and "previous" gestures.
  ///
  /// **Dart Source:** `semantics.dart:6205-6209`
  case traversalOrder
}
