// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Owns `SemanticsNode` objects and notifies listeners of changes to the
/// render tree semantics.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Original Name:** `SemanticsOwner`
/// **Lines:** 4281-4540

import Foundation
import FlutterSwiftBridge

// MARK: - SemanticsUpdateCallback

/// Signature for a function that receives a semantics update and returns no result.
///
/// Used by `SemanticsOwner.onSemanticsUpdate`.
///
/// **Dart Source:** `semantics.dart:97-100`
/// **Original:** `typedef SemanticsUpdateCallback = void Function(SemanticsUpdate update);`
///
/// DIFFERENCE FROM DART: The callback parameter type is `Any` instead of
/// `SemanticsUpdate` (the FlutterSwiftBridge protocol).
/// REASON: The stub `SemanticsUpdateBuilder.build()` returns `Any` since the
/// full engine bridge is not yet wired up. When the bridge is complete, this
/// should become `(any SemanticsUpdate) -> Void`.
public typealias SemanticsUpdateCallback = (Any) -> Void

// MARK: - SemanticsOwner

/// Owns `SemanticsNode` objects and notifies listeners of changes to the
/// render tree semantics.
///
/// To listen for semantic updates, call `SemanticsBinding.ensureSemantics` or
/// `PipelineOwner.ensureSemantics` to obtain a `SemanticsHandle`. This will
/// create a `SemanticsOwner` if necessary.
///
/// **Dart Source:** `semantics.dart:4281-4540`
/// **Original Name:** `SemanticsOwner`
///
/// DIFFERENCE FROM DART: Extends `ChangeNotifier` class instead of Dart's
/// `mixin class ChangeNotifier`.
/// REASON: Swift does not have mixins; a class hierarchy achieves the same effect.
public class SemanticsOwner: ChangeNotifier {

  /// Creates a `SemanticsOwner` that manages zero or more `SemanticsNode` objects.
  ///
  /// **Dart Source:** `semantics.dart:4283-4285`
  /// **Original:** `SemanticsOwner({required this.onSemanticsUpdate})`
  public init(onSemanticsUpdate: @escaping SemanticsUpdateCallback) {
    self.onSemanticsUpdate = onSemanticsUpdate
    super.init()
  }

  /// The `onSemanticsUpdate` callback is expected to dispatch `SemanticsUpdate`s
  /// to the `FlutterView` that is associated with this `PipelineOwner` and/or
  /// `SemanticsOwner`.
  ///
  /// A `SemanticsOwner` calls `onSemanticsUpdate` during `sendSemanticsUpdate`
  /// after the `SemanticsUpdate` has been built, but before the `SemanticsOwner`'s
  /// listeners have been notified.
  ///
  /// **Dart Source:** `semantics.dart:4287-4294`
  /// **Original:** `final SemanticsUpdateCallback onSemanticsUpdate;`
  public let onSemanticsUpdate: SemanticsUpdateCallback

  /// The set of dirty semantics nodes that need updating.
  ///
  /// **Dart Source:** `semantics.dart:4295`
  /// **Original:** `final Set<SemanticsNode> _dirtyNodes = <SemanticsNode>{};`
  var _dirtyNodes: Set<SemanticsNode> = []

  /// Map from semantics node IDs to nodes.
  ///
  /// **Dart Source:** `semantics.dart:4296`
  /// **Original:** `final Map<int, SemanticsNode> _nodes = <int, SemanticsNode>{};`
  var _nodes: [Int: SemanticsNode] = [:]

  /// Set of detached nodes awaiting cleanup.
  ///
  /// **Dart Source:** `semantics.dart:4297`
  /// **Original:** `final Set<SemanticsNode> _detachedNodes = <SemanticsNode>{};`
  var _detachedNodes: Set<SemanticsNode> = []

  /// The root node of the semantics tree, if any.
  ///
  /// If the semantics tree is empty, returns nil.
  ///
  /// **Dart Source:** `semantics.dart:4299-4302`
  /// **Original:** `SemanticsNode? get rootSemanticsNode => _nodes[0];`
  public var rootSemanticsNode: SemanticsNode? {
    _nodes[0]
  }

  // MARK: - dispose

  /// Discards any resources used by the object.
  ///
  /// **Dart Source:** `semantics.dart:4304-4311`
  /// **Original:** `void dispose()`
  public override func dispose() {
    _dirtyNodes.removeAll()
    _nodes.removeAll()
    _detachedNodes.removeAll()
    super.dispose()
  }

  // MARK: - sendSemanticsUpdate

  /// Update the semantics using `onSemanticsUpdate`.
  ///
  /// **Dart Source:** `semantics.dart:4314-4433`
  /// **Original:** `void sendSemanticsUpdate()`
  public func sendSemanticsUpdate() {
    // Once the tree is up-to-date, verify that every node is visible.
    assert({
      var invisibleNodes: [SemanticsNode] = []

      func findInvisibleNodes(_ node: SemanticsNode) -> Bool {
        if node.rect.isEmpty {
          invisibleNodes.append(node)
        } else if !node.mergeAllDescendantsIntoThisNode {
          node.visitChildren(findInvisibleNodes)
        }
        return true
      }

      if let root = rootSemanticsNode {
        // The root node is allowed to be invisible when it has no children.
        if root.childrenCount > 0 && root.rect.isEmpty {
          invisibleNodes.append(root)
        } else if !root.mergeAllDescendantsIntoThisNode {
          root.visitChildren(findInvisibleNodes)
        }
      }

      if !invisibleNodes.isEmpty {
        // In Dart this throws a FlutterError. Here we use assertionFailure
        // since FlutterError is not yet migrated.
        assertionFailure(
          "Invisible SemanticsNodes should not be added to the tree.\n"
          + "The following invisible SemanticsNodes were added to the tree:\n"
          + invisibleNodes.map { "\($0.toStringShort())" }.joined(separator: "\n")
          + "\nAn invisible SemanticsNode is one whose rect is not on screen hence not "
          + "reachable for users, and its semantic information is not merged into a visible parent."
        )
      }
      return true
    }())

    if _dirtyNodes.isEmpty {
      return
    }

    var customSemanticsActionIds = Set<Int>()
    var visitedNodes: [SemanticsNode] = []

    while !_dirtyNodes.isEmpty {
      let localDirtyNodes = _dirtyNodes.filter { node in
        !_detachedNodes.contains(node)
      }
      _dirtyNodes.removeAll()
      _detachedNodes.removeAll()

      var sortedLocalDirtyNodes = Array(localDirtyNodes)
      sortedLocalDirtyNodes.sort { a, b in a.depth - b.depth < 0 }

      visitedNodes.append(contentsOf: sortedLocalDirtyNodes)

      for node in sortedLocalDirtyNodes {
        assert(node._dirty)
        assert(
          node.parent == nil
            || !node.parent!.isPartOfNodeMerging
            || node.isMergedIntoParent
        )
        if node.isPartOfNodeMerging {
          assert(node.mergeAllDescendantsIntoThisNode || node.parent != nil)
          // If child node is merged into its parent, make sure the parent is marked as dirty
          if node.parent != nil && node.parent!.isPartOfNodeMerging {
            node.parent!._markDirty() // this can add the node to the dirty list
            node._dirty = false // Do not send update for this node, as it's now part of its parent
          }
        }
      }
    }

    visitedNodes.sort { a, b in a.depth - b.depth < 0 }

    /// **Dart Source:** `semantics.dart:4404`
    /// **Original:** `final SemanticsUpdateBuilder builder = SemanticsBinding.instance.createSemanticsUpdateBuilder();`
    ///
    /// DIFFERENCE FROM DART: Uses `SemanticsUpdateBuilder()` stub directly instead of
    /// `SemanticsBinding.instance.createSemanticsUpdateBuilder()`.
    /// REASON: `SemanticsBinding` is not yet migrated. The stub
    /// `SemanticsUpdateBuilder` in `SemanticsNode.swift` serves as a placeholder.
    /// When `SemanticsBinding` is migrated, this should use
    /// `SemanticsBinding.instance.createSemanticsUpdateBuilder()`.
    let builder = SemanticsUpdateBuilder()

    for node in visitedNodes {
      assert(node.parent?._dirty != true) // could be nil (no parent) or false (not dirty)
      // The _addToUpdate() method marks the node as not dirty, and
      // recurses through the tree to do a deep serialization of all
      // contiguous dirty nodes. This means that when we return here,
      // it's quite possible that subsequent nodes are no longer
      // dirty. We skip these here.
      // We also skip any nodes that were reset and subsequently
      // dropped entirely (RenderObject.markNeedsSemanticsUpdate()
      // calls reset() on its SemanticsNode if onlyChanges isn't set,
      // which happens e.g. when the node is no longer contributing
      // semantics).
      if node._dirty && node.attached {
        node._addToUpdate(builder, customSemanticsActionIdsUpdate: &customSemanticsActionIds)
      }
    }

    _dirtyNodes.removeAll()

    for actionId in customSemanticsActionIds {
      let action = CustomSemanticsAction.getAction(actionId)!
      builder.updateCustomAction(
        id: actionId,
        label: action.label,
        hint: action.hint,
        overrideId: action.action?.index ?? -1
      )
    }

    onSemanticsUpdate(builder.build())
    notifyListeners()
  }

  // MARK: - _getSemanticsActionHandlerForId

  /// Looks up the action handler for the given node id and action.
  ///
  /// If the node is part of a merge and cannot perform the action itself,
  /// this method walks the node's descendants looking for one that can.
  ///
  /// **Dart Source:** `semantics.dart:4435-4450`
  /// **Original:** `SemanticsActionHandler? _getSemanticsActionHandlerForId(int id, SemanticsAction action)`
  private func _getSemanticsActionHandlerForId(
    _ id: Int,
    _ action: SemanticsAction
  ) -> SemanticsActionHandler? {
    var result: SemanticsNode? = _nodes[id]
    if let node = result, node.isPartOfNodeMerging && !node._canPerformAction(action) {
      node._visitDescendants { child in
        if child._canPerformAction(action) {
          result = child
          return false // found node, abort walk
        }
        return true // continue walk
      }
    }
    guard let node = result, node._canPerformAction(action) else {
      return nil
    }
    return node._actions[action]
  }

  // MARK: - performAction

  /// Asks the `SemanticsNode` with the given id to perform the given action.
  ///
  /// If the `SemanticsNode` has not indicated that it can perform the action,
  /// this function does nothing.
  ///
  /// If the given `action` requires arguments they need to be passed in via
  /// the `args` parameter.
  ///
  /// **Dart Source:** `semantics.dart:4459-4470`
  /// **Original:** `void performAction(int id, SemanticsAction action, [Object? args])`
  public func performAction(_ id: Int, _ action: SemanticsAction, _ args: Any? = nil) {
    let handler = _getSemanticsActionHandlerForId(id, action)
    if let handler = handler {
      handler(args)
      return
    }

    // Default actions if no handler was provided.
    if action == SemanticsAction.showOnScreen, let showOnScreen = _nodes[id]?._showOnScreen {
      showOnScreen()
    }
  }

  // MARK: - _getSemanticsActionHandlerForPosition

  /// Hit-tests the semantics tree for an action handler at a given position.
  ///
  /// Walks the tree from the given node, transforming coordinates through
  /// each node's transform, and returns the handler for the deepest node
  /// that contains the position and can perform the action.
  ///
  /// **Dart Source:** `semantics.dart:4472-4514`
  /// **Original:** `SemanticsActionHandler? _getSemanticsActionHandlerForPosition(SemanticsNode node, Offset position, SemanticsAction action)`
  private func _getSemanticsActionHandlerForPosition(
    _ node: SemanticsNode,
    _ position: Offset,
    _ action: SemanticsAction
  ) -> SemanticsActionHandler? {
    var position = position

    if node.transform != nil {
      var inverse = node.transform!
      let det = inverse.invert()
      if det == 0.0 {
        return nil
      }
      position = MatrixUtils.transformPoint(inverse, position)
    }

    if !node.rect.contains(position) {
      return nil
    }

    if node.mergeAllDescendantsIntoThisNode {
      if node._canPerformAction(action) {
        return node._actions[action]
      }
      var result: SemanticsNode?
      node._visitDescendants { child in
        if child._canPerformAction(action) {
          result = child
          return false
        }
        return true
      }
      return result?._actions[action]
    }

    if node.hasChildren {
      for child in node._children!.reversed() {
        let handler = _getSemanticsActionHandlerForPosition(child, position, action)
        if handler != nil {
          return handler
        }
      }
    }

    return node._actions[action]
  }

  // MARK: - performActionAt

  /// Asks the `SemanticsNode` at the given position to perform the given action.
  ///
  /// If the `SemanticsNode` has not indicated that it can perform the action,
  /// this function does nothing.
  ///
  /// If the given `action` requires arguments they need to be passed in via
  /// the `args` parameter.
  ///
  /// **Dart Source:** `semantics.dart:4523-4536`
  /// **Original:** `void performActionAt(Offset position, SemanticsAction action, [Object? args])`
  public func performActionAt(_ position: Offset, _ action: SemanticsAction, _ args: Any? = nil) {
    guard let node = rootSemanticsNode else {
      return
    }
    let handler = _getSemanticsActionHandlerForPosition(node, position, action)
    if let handler = handler {
      handler(args)
    }
  }

  // MARK: - CustomStringConvertible

  /// **Dart Source:** `semantics.dart:4538-4539`
  /// **Original:** `String toString() => describeIdentity(this);`
  public var description: String {
    describeIdentity(self)
  }
}
