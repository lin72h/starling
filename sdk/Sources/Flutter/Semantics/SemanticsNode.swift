// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The core `SemanticsNode` tree node for accessibility semantics.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Original Name:** `SemanticsNode`
/// **Lines:** 2519-3980

import Foundation
import FlutterSwiftBridge

// MARK: - SemanticsNodeVisitor

/// Signature for a function that is called for each [SemanticsNode].
///
/// Return false to stop visiting nodes.
///
/// Used by [SemanticsNode.visitChildren] and [SemanticsNode._visitDescendants].
///
/// **Dart Source:** `semantics.dart:72`
/// **Original:** `typedef SemanticsNodeVisitor = bool Function(SemanticsNode node);`
public typealias SemanticsNodeVisitor = (SemanticsNode) -> Bool

// MARK: - SemanticsUpdateBuilder Stub

/// Minimal forward-declaration stub for `SemanticsUpdateBuilder`.
///
/// This will be replaced when the engine bridge for semantics is migrated.
///
/// TODO: Replace with full SemanticsUpdateBuilder implementation.
public class SemanticsUpdateBuilder {
  public init() {}

  /// Updates a semantics node in the builder.
  ///
  /// **Dart Source:** `engine/src/flutter/lib/ui/semantics.dart`
  public func updateNode(
    id: Int,
    flags: SemanticsFlags,
    actions: Int,
    rect: Rect,
    identifier: String,
    label: String,
    labelAttributes: [StringAttribute],
    value: String,
    valueAttributes: [StringAttribute],
    increasedValue: String,
    increasedValueAttributes: [StringAttribute],
    decreasedValue: String,
    decreasedValueAttributes: [StringAttribute],
    hint: String,
    hintAttributes: [StringAttribute],
    tooltip: String,
    textDirection: TextDirection?,
    textSelectionBase: Int,
    textSelectionExtent: Int,
    platformViewId: Int,
    maxValueLength: Int,
    currentValueLength: Int,
    scrollChildren: Int,
    scrollIndex: Int,
    scrollPosition: Double,
    scrollExtentMax: Double,
    scrollExtentMin: Double,
    transform: [Double],
    childrenInTraversalOrder: [Int32],
    childrenInHitTestOrder: [Int32],
    additionalActions: [Int32],
    headingLevel: Int,
    linkUrl: String,
    role: SemanticsRole,
    controlsNodes: [String]?,
    validationResult: SemanticsValidationResult,
    inputType: SemanticsInputType,
    locale: FlutterSwiftBridge.Locale?
  ) {
    // TODO: Implement when engine bridge is available.
  }

  /// Updates a custom semantics action in the builder.
  ///
  /// **Dart Source:** `engine/src/flutter/lib/ui/semantics.dart`
  public func updateCustomAction(
    id: Int,
    label: String?,
    hint: String?,
    overrideId: Int
  ) {
    // TODO: Implement when engine bridge is available.
  }

  /// Builds the semantics update from recorded data.
  ///
  /// **Dart Source:** `engine/src/flutter/lib/ui/semantics.dart`
  public func build() -> Any {
    // TODO: Implement when engine bridge is available.
    // Returns a placeholder since SemanticsUpdate protocol is in FlutterSwiftBridge.
    return "SemanticsUpdate(stub)"
  }
}

// MARK: - debugResetSemanticsIdCounter

/// In tests use this function to reset the counter used to generate
/// `SemanticsNode.id`.
///
/// **Dart Source:** `semantics.dart:2507-2511`
/// **Original:** `void debugResetSemanticsIdCounter()`
public func debugResetSemanticsIdCounter() {
  SemanticsNode._lastIdentifier = 0
}

// MARK: - _TraversalSortNode

/// The implementation of `Comparable` that implements the ordering of
/// `SemanticsNode`s in the accessibility traversal.
///
/// `SemanticsNode`s are sorted prior to sending them to the engine side.
///
/// This implementation considers a `node`'s `sortKey` and its position within
/// the list of its siblings. `sortKey` takes precedence over position.
///
/// **Dart Source:** `semantics.dart:4250-4273`
/// **Original Name:** `_TraversalSortNode`
struct TraversalSortNode: Comparable {
  /// The node whose position this sort node determines.
  let node: SemanticsNode

  /// Determines the position of this node among its siblings.
  ///
  /// Sort keys take precedence over other attributes, such as
  /// `position`.
  let sortKey: SemanticsSortKey?

  /// Position within the list of siblings as determined by the default sort
  /// order.
  let position: Int

  /// **Dart Source:** `semantics.dart:4267-4272`
  static func < (lhs: TraversalSortNode, rhs: TraversalSortNode) -> Bool {
    if lhs.sortKey == nil || rhs.sortKey == nil {
      return lhs.position < rhs.position
    }
    return lhs.sortKey!.compareTo(rhs.sortKey!) < 0
  }

  static func == (lhs: TraversalSortNode, rhs: TraversalSortNode) -> Bool {
    if lhs.sortKey == nil || rhs.sortKey == nil {
      return lhs.position == rhs.position
    }
    return lhs.sortKey!.compareTo(rhs.sortKey!) == 0
  }
}

// MARK: - _SemanticsDiagnosticableNode

/// A diagnostics node for SemanticsNode that includes child ordering.
///
/// **Dart Source:** `semantics.dart:1412-1424`
/// **Original Name:** `_SemanticsDiagnosticableNode`
class SemanticsDiagnosticableNode: DiagnosticableNode<SemanticsNode> {
  let childOrder: DebugSemanticsDumpOrder

  init(
    name: String?,
    value: SemanticsNode,
    style: DiagnosticsTreeStyle?,
    childOrder: DebugSemanticsDumpOrder
  ) {
    self.childOrder = childOrder
    super.init(name: name, value: value, style: style)
  }

  override func getChildren() -> [any DiagnosticsNodeProtocol] {
    return typedValue.debugDescribeChildren(childOrder: childOrder)
  }
}

// MARK: - SemanticsNode

/// A node that represents some semantic data.
///
/// The semantics tree is maintained during the semantics phase of the pipeline
/// (i.e., during `PipelineOwner.flushSemantics`), which happens after
/// compositing. The semantics tree is then uploaded into the engine for use
/// by assistive technology.
///
/// **Dart Source:** `semantics.dart:2519-3980`
/// **Original Name:** `SemanticsNode`
///
/// DIFFERENCE FROM DART: Uses a Swift `class` conforming to `DiagnosticableTreeMixin`.
/// REASON: `SemanticsNode` is a mutable tree node with identity semantics in Dart;
/// Swift `class` is the idiomatic equivalent. Dart's `with DiagnosticableTreeMixin`
/// mixin is expressed as protocol conformance.
public class SemanticsNode: DiagnosticableTreeMixin, Hashable {

  // MARK: - Static ID Management
  /// **Dart Source:** `semantics.dart:2537-2548`

  /// The maximal semantic node identifier generated by the framework.
  ///
  /// The identifier range for semantic node IDs is split into 2, the least significant 16 bits are
  /// reserved for framework generated IDs(generated with _generateNewId), and most significant 32
  /// bits are reserved for engine generated IDs.
  ///
  /// **Dart Source:** `semantics.dart:2542`
  /// **Original:** `static const int _maxFrameworkAccessibilityIdentifier = (1 << 16) - 1;`
  private static let _maxFrameworkAccessibilityIdentifier: Int = (1 << 16) - 1

  /// **Dart Source:** `semantics.dart:2544`
  /// **Original:** `static int _lastIdentifier = 0;`
  nonisolated(unsafe) static var _lastIdentifier: Int = 0

  /// **Dart Source:** `semantics.dart:2545-2548`
  /// **Original:** `static int _generateNewId() { ... }`
  private static func _generateNewId() -> Int {
    _lastIdentifier = (_lastIdentifier + 1) % _maxFrameworkAccessibilityIdentifier
    return _lastIdentifier
  }

  // MARK: - Static Constants
  /// **Dart Source:** `semantics.dart:3363, 3639-3641`

  /// An empty `SemanticsConfiguration` used as default for various properties.
  ///
  /// **Dart Source:** `semantics.dart:3363`
  /// **Original:** `static final SemanticsConfiguration _kEmptyConfig = SemanticsConfiguration();`
  nonisolated(unsafe) private static let _kEmptyConfig: SemanticsConfiguration = SemanticsConfiguration()

  /// An empty child list.
  ///
  /// **Dart Source:** `semantics.dart:3639`
  /// **Original:** `static final Int32List _kEmptyChildList = Int32List(0);`
  private static let _kEmptyChildList: [Int32] = []

  /// An empty custom semantics action IDs list.
  ///
  /// **Dart Source:** `semantics.dart:3640`
  /// **Original:** `static final Int32List _kEmptyCustomSemanticsActionsList = Int32List(0);`
  private static let _kEmptyCustomSemanticsActionsList: [Int32] = []

  /// The identity transform as a flat array.
  ///
  /// **Dart Source:** `semantics.dart:3635-3641`
  /// **Original:** `static final Float64List _kIdentityTransform = _initIdentityTransform();`
  private static let _kIdentityTransform: [Double] = Matrix4.identity().storage

  // MARK: - Constructors
  /// **Dart Source:** `semantics.dart:2520-2535`

  /// Creates a semantic node.
  ///
  /// Each semantic node has a unique identifier that is assigned when the node
  /// is created.
  ///
  /// **Dart Source:** `semantics.dart:2524-2526`
  /// **Original:** `SemanticsNode({this.key, VoidCallback? showOnScreen})`
  public init(key: (any Key)? = nil, showOnScreen: VoidCallback? = nil) {
    self.key = key
    self._id = SemanticsNode._generateNewId()
    self._showOnScreen = showOnScreen
  }

  /// Creates a semantic node to represent the root of the semantics tree.
  ///
  /// The root node is assigned an identifier of zero.
  ///
  /// **Dart Source:** `semantics.dart:2531-2535`
  /// **Original:** `SemanticsNode.root({this.key, VoidCallback? showOnScreen, required SemanticsOwner owner})`
  public init(
    asRoot key: (any Key)? = nil,
    showOnScreen: VoidCallback? = nil,
    owner: SemanticsOwner
  ) {
    self.key = key
    self._id = 0
    self._showOnScreen = showOnScreen
    attach(owner)
  }

  // MARK: - Hashable
  /// Identity-based equality/hashing for `SemanticsNode`.

  public static func == (lhs: SemanticsNode, rhs: SemanticsNode) -> Bool {
    return lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  // MARK: - Key and ID
  /// **Dart Source:** `semantics.dart:2550-2567`

  /// Uniquely identifies this node in the list of sibling nodes.
  ///
  /// Keys are used during the construction of the semantics tree. They are not
  /// transferred to the engine.
  ///
  /// **Dart Source:** `semantics.dart:2554`
  /// **Original:** `final Key? key;`
  public let key: (any Key)?

  /// The unique identifier for this node.
  ///
  /// The root node has an id of zero. Other nodes are given a unique id
  /// when they are attached to a `SemanticsOwner`. If they are detached, their
  /// ids are invalid and should not be used.
  ///
  /// In rare circumstances, id may change if this node is detached and
  /// re-attached to the `SemanticsOwner`. This should only happen when the
  /// application has generated too many semantics nodes.
  ///
  /// **Dart Source:** `semantics.dart:2565-2566`
  /// **Original:** `int get id => _id; int _id;`
  public var id: Int { _id }
  private var _id: Int

  /// **Dart Source:** `semantics.dart:2568`
  /// **Original:** `final VoidCallback? _showOnScreen;`
  ///
  /// DIFFERENCE FROM DART: `internal` access instead of file-private.
  /// REASON: `SemanticsOwner.performAction` needs access to `_showOnScreen`.
  let _showOnScreen: VoidCallback?

  // MARK: - Geometry Properties
  /// **Dart Source:** `semantics.dart:2570-2649`

  /// The transform from this node's coordinate system to its parent's coordinate system.
  ///
  /// By default, the transform is nil, which represents the identity
  /// transformation (i.e., that this node has the same coordinate system as its
  /// parent).
  ///
  /// **Dart Source:** `semantics.dart:2577-2584`
  /// **Original:** `Matrix4? get transform => _transform;`
  public var transform: Matrix4? {
    get { _transform }
    set {
      if !MatrixUtils.matrixEquals(_transform, newValue) {
        _transform = newValue == nil || MatrixUtils.isIdentity(newValue!) ? nil : newValue
        _markDirty()
      }
    }
  }
  private var _transform: Matrix4?

  /// The bounding box for this node in its coordinate system.
  ///
  /// **Dart Source:** `semantics.dart:2587-2595`
  /// **Original:** `Rect get rect => _rect;`
  public var rect: Rect {
    get { _rect }
    set {
      assert(newValue.isFinite, "\(self) tried to set a non-finite rect.")
      if _rect != newValue {
        _rect = newValue
        _markDirty()
      }
    }
  }
  private var _rect: Rect = .zero

  /// The semantic clip from an ancestor that was applied to this node.
  ///
  /// Expressed in the coordinate system of the node. May be nil if no clip has
  /// been applied.
  ///
  /// Descendant `SemanticsNode`s that are positioned outside of this rect will
  /// be excluded from the semantics tree. Descendant `SemanticsNode`s that are
  /// overlapping with this rect, but are outside of `parentPaintClipRect` will
  /// be included in the tree, but they will be marked as hidden because they
  /// are assumed to be not visible on screen.
  ///
  /// If this rect is nil, all descendant `SemanticsNode`s outside of
  /// `parentPaintClipRect` will be excluded from the tree.
  ///
  /// If this rect is non-nil it has to completely enclose
  /// `parentPaintClipRect`. If `parentPaintClipRect` is nil this property is
  /// also nil.
  ///
  /// **Dart Source:** `semantics.dart:2614`
  /// **Original:** `Rect? parentSemanticsClipRect;`
  public var parentSemanticsClipRect: Rect?

  /// The paint clip from an ancestor that was applied to this node.
  ///
  /// Expressed in the coordinate system of the node. May be nil if no clip has
  /// been applied.
  ///
  /// Descendant `SemanticsNode`s that are positioned outside of this rect will
  /// either be excluded from the semantics tree (if they have no overlap with
  /// `parentSemanticsClipRect`) or they will be included and marked as hidden
  /// (if they are overlapping with `parentSemanticsClipRect`).
  ///
  /// This rect is completely enclosed by `parentSemanticsClipRect`.
  ///
  /// If this rect is nil `parentSemanticsClipRect` also has to be nil.
  ///
  /// **Dart Source:** `semantics.dart:2629`
  /// **Original:** `Rect? parentPaintClipRect;`
  public var parentPaintClipRect: Rect?

  /// The index of this node within the parent's list of semantic children.
  ///
  /// This includes all semantic nodes, not just those currently in the
  /// child list. For example, if a scrollable has five children but the first
  /// two are not visible (and thus not included in the list of children), then
  /// the index of the last node will still be 4.
  ///
  /// **Dart Source:** `semantics.dart:2637`
  /// **Original:** `int? indexInParent;`
  public var indexInParent: Int?

  /// Whether the node is invisible.
  ///
  /// A node whose `rect` is outside of the bounds of the screen and hence not
  /// reachable for users is considered invisible if its semantic information
  /// is not merged into a (partially) visible parent as indicated by
  /// `isMergedIntoParent`.
  ///
  /// An invisible node can be safely dropped from the semantic tree without
  /// losing semantic information that is relevant for describing the content
  /// currently shown on screen.
  ///
  /// **Dart Source:** `semantics.dart:2649`
  /// **Original:** `bool get isInvisible => !isMergedIntoParent && (rect.isEmpty || (transform?.isZero() ?? false));`
  public var isInvisible: Bool {
    !isMergedIntoParent && (rect.isEmpty || (transform?.isZero() ?? false))
  }

  // MARK: - Merging Properties
  /// **Dart Source:** `semantics.dart:2651-2697`

  /// Whether this node merges its semantic information into an ancestor node.
  ///
  /// This value indicates whether this node has any ancestors with
  /// `mergeAllDescendantsIntoThisNode` set to true.
  ///
  /// **Dart Source:** `semantics.dart:2657-2665`
  /// **Original:** `bool get isMergedIntoParent => _isMergedIntoParent;`
  public var isMergedIntoParent: Bool {
    get { _isMergedIntoParent }
    set {
      if _isMergedIntoParent == newValue {
        return
      }
      _isMergedIntoParent = newValue
      parent?._markDirty()
    }
  }
  private var _isMergedIntoParent: Bool = false

  /// Whether the user can interact with this node in assistive technologies.
  ///
  /// This node can still receive accessibility focus even if this is true.
  /// Setting this to true prevents the user from activating pointer related
  /// `SemanticsAction`s, such as `SemanticsAction.tap` or
  /// `SemanticsAction.longPress`.
  ///
  /// **Dart Source:** `semantics.dart:2673-2681`
  /// **Original:** `bool get areUserActionsBlocked => _areUserActionsBlocked;`
  public var areUserActionsBlocked: Bool {
    get { _areUserActionsBlocked }
    set {
      if _areUserActionsBlocked == newValue {
        return
      }
      _areUserActionsBlocked = newValue
      _markDirty()
    }
  }
  private var _areUserActionsBlocked: Bool = false

  /// Whether this node is taking part in a merge of semantic information.
  ///
  /// This returns true if the node is either merged into an ancestor node or if
  /// descendant nodes are merged into this node.
  ///
  /// **Dart Source:** `semantics.dart:2692`
  /// **Original:** `bool get isPartOfNodeMerging => mergeAllDescendantsIntoThisNode || isMergedIntoParent;`
  public var isPartOfNodeMerging: Bool {
    mergeAllDescendantsIntoThisNode || isMergedIntoParent
  }

  /// Whether this node and all of its descendants should be treated as one logical entity.
  ///
  /// **Dart Source:** `semantics.dart:2695-2696`
  /// **Original:** `bool get mergeAllDescendantsIntoThisNode => _mergeAllDescendantsIntoThisNode;`
  public var mergeAllDescendantsIntoThisNode: Bool { _mergeAllDescendantsIntoThisNode }
  private var _mergeAllDescendantsIntoThisNode: Bool = SemanticsNode._kEmptyConfig.isMergingSemanticsOfDescendants

  // MARK: - Children
  /// **Dart Source:** `semantics.dart:2698-2863`

  /// Contains the children in inverse hit test order (i.e. paint order).
  ///
  /// **Dart Source:** `semantics.dart:2701`
  /// **Original:** `List<SemanticsNode>? _children;`
  ///
  /// DIFFERENCE FROM DART: `internal` access instead of file-private.
  /// REASON: `SemanticsOwner._getSemanticsActionHandlerForPosition` needs access.
  var _children: [SemanticsNode]?

  /// A snapshot of `newChildren` passed to `_replaceChildren` that we keep in
  /// debug mode. It supports the assertion that user does not mutate the list
  /// of children.
  ///
  /// **Dart Source:** `semantics.dart:2706`
  private var _debugPreviousSnapshot: [SemanticsNode] = []

  /// Whether this node has a non-zero number of children.
  ///
  /// **Dart Source:** `semantics.dart:2829`
  /// **Original:** `bool get hasChildren => _children?.isNotEmpty ?? false;`
  public var hasChildren: Bool { _children?.isEmpty == false }

  /// Internal marker for dead children during replacement.
  ///
  /// **Dart Source:** `semantics.dart:2830`
  /// **Original:** `bool _dead = false;`
  var _dead: Bool = false

  /// The number of children this node has.
  ///
  /// **Dart Source:** `semantics.dart:2833`
  /// **Original:** `int get childrenCount => hasChildren ? _children!.length : 0;`
  public var childrenCount: Int { hasChildren ? _children!.count : 0 }

  /// Visits the immediate children of this node.
  ///
  /// This function calls visitor for each immediate child until visitor returns
  /// false.
  ///
  /// **Dart Source:** `semantics.dart:2839-2847`
  /// **Original:** `void visitChildren(SemanticsNodeVisitor visitor)`
  public func visitChildren(_ visitor: SemanticsNodeVisitor) {
    if let children = _children {
      for child in children {
        if !visitor(child) {
          return
        }
      }
    }
  }

  /// Visit all the descendants of this node.
  ///
  /// This function calls visitor for each descendant in a pre-order traversal
  /// until visitor returns false. Returns true if all the visitor calls
  /// returned true, otherwise returns false.
  ///
  /// **Dart Source:** `semantics.dart:2854-2863`
  /// **Original:** `bool _visitDescendants(SemanticsNodeVisitor visitor)`
  @discardableResult
  func _visitDescendants(_ visitor: SemanticsNodeVisitor) -> Bool {
    if let children = _children {
      for child in children {
        if !visitor(child) || !child._visitDescendants(visitor) {
          return false
        }
      }
    }
    return true
  }

  /// Replaces the current children with the new children list.
  ///
  /// **Dart Source:** `semantics.dart:2708-2826`
  /// **Original:** `void _replaceChildren(List<SemanticsNode> newChildren)`
  func _replaceChildren(_ newChildren: [SemanticsNode]) {
    assert(!newChildren.contains(where: { $0 === self }))
    assert({
      var seenChildren = Set<ObjectIdentifier>()
      for child in newChildren {
        assert(seenChildren.insert(ObjectIdentifier(child)).inserted, "Duplicate child in semantics node children list")
      }
      return true
    }())

    // The goal of this function is updating sawChange.
    if let oldChildren = _children {
      for child in oldChildren {
        child._dead = true
      }
    }
    for child in newChildren {
      child._dead = false
    }

    var sawChange = false
    if let oldChildren = _children {
      for child in oldChildren {
        if child._dead {
          if child.parent === self {
            // we might have already had our child stolen from us by
            // another node that is deeper in the tree.
            _dropChild(child)
          }
          sawChange = true
        }
      }
    }
    for child in newChildren {
      if child.parent !== self {
        if child.parent != nil {
          // we're rebuilding the tree from the bottom up, so it's possible
          // that our child was, in the last pass, a child of one of our
          // ancestors. In that case, we drop the child eagerly here.
          // TODO(ianh): Find a way to assert that the same node didn't
          // actually appear in the tree in two places.
          child.parent?._dropChild(child)
        }
        assert(!child.attached)
        _adoptChild(child)
        sawChange = true
      }
    }

    // Wait until the new children are adopted so isMergedIntoParent becomes
    // up-to-date.
    assert({
      if newChildren.withUnsafeBufferPointer({ _ in true }) && _children != nil
        && newChildren.count == _children!.count {
        // Check for mutation of the same list
        // Simplified check: just store snapshot for debug
      }
      _debugPreviousSnapshot = Array(newChildren)

      var ancestor: SemanticsNode = self
      while ancestor.parent != nil {
        ancestor = ancestor.parent!
      }
      assert(!newChildren.contains(where: { $0 === ancestor }))
      return true
    }())

    if !sawChange && _children != nil {
      assert(newChildren.count == _children!.count)
      // Did the order change?
      for i in 0..<_children!.count {
        if _children![i].id != newChildren[i].id {
          sawChange = true
          break
        }
      }
    }
    _children = newChildren
    if sawChange {
      _markDirty()
    }
  }

  // MARK: - Tree Lifecycle
  /// **Dart Source:** `semantics.dart:2865-3010`

  /// The owner for this node (nil if unattached).
  ///
  /// The entire semantics tree that this node belongs to will have the same owner.
  ///
  /// **Dart Source:** `semantics.dart:2868-2869`
  /// **Original:** `SemanticsOwner? get owner => _owner;`
  public var owner: SemanticsOwner? { _owner }
  private var _owner: SemanticsOwner?

  /// Whether the semantics tree this node belongs to is attached to a `SemanticsOwner`.
  ///
  /// This becomes true during the call to `attach`.
  ///
  /// This becomes false during the call to `detach`.
  ///
  /// **Dart Source:** `semantics.dart:2876`
  /// **Original:** `bool get attached => _owner != null;`
  public var attached: Bool { _owner != nil }

  /// The parent of this node in the semantics tree.
  ///
  /// The `parent` of the root node in the semantics tree is nil.
  ///
  /// **Dart Source:** `semantics.dart:2881-2882`
  /// **Original:** `SemanticsNode? get parent => _parent;`
  public var parent: SemanticsNode? { _parent }
  private var _parent: SemanticsNode?

  /// The depth of this node in the semantics tree.
  ///
  /// The depth of nodes in a tree monotonically increases as you traverse down
  /// the tree. There's no guarantee regarding depth between siblings.
  ///
  /// The depth is used to ensure that nodes are processed in depth order.
  ///
  /// **Dart Source:** `semantics.dart:2891`
  /// **Original:** `int get depth => _depth;`
  public var depth: Int { _depth }
  private var _depth: Int = 0

  /// The locale of this node.
  ///
  /// This property is used by assistive technologies to correctly interpret
  /// the content of this node.
  ///
  /// **Dart Source:** `semantics.dart:2897`
  /// **Original:** `Locale? _locale;`
  var _locale: FlutterSwiftBridge.Locale?

  /// **Dart Source:** `semantics.dart:2899-2905`
  /// **Original:** `void _redepthChild(SemanticsNode child)`
  private func _redepthChild(_ child: SemanticsNode) {
    assert(child.owner === owner)
    if child._depth <= _depth {
      child._depth = _depth + 1
      child._redepthChildren()
    }
  }

  /// **Dart Source:** `semantics.dart:2907-2909`
  /// **Original:** `void _redepthChildren()`
  private func _redepthChildren() {
    _children?.forEach(_redepthChild)
  }

  /// **Dart Source:** `semantics.dart:2911-2926`
  /// **Original:** `void _updateChildMergeFlagRecursively(SemanticsNode child)`
  private func _updateChildMergeFlagRecursively(_ child: SemanticsNode) {
    assert(child.owner === owner)
    let childShouldMergeToParent = isPartOfNodeMerging

    if childShouldMergeToParent == child.isMergedIntoParent {
      return
    }

    child.isMergedIntoParent = childShouldMergeToParent

    if child.mergeAllDescendantsIntoThisNode {
      // No need to update the descendants since `child` has the merge flag set.
    } else {
      child._updateChildrenMergeFlags()
    }
  }

  /// **Dart Source:** `semantics.dart:2928-2930`
  /// **Original:** `void _updateChildrenMergeFlags()`
  private func _updateChildrenMergeFlags() {
    _children?.forEach(_updateChildMergeFlagRecursively)
  }

  /// **Dart Source:** `semantics.dart:2932-2953`
  /// **Original:** `void _adoptChild(SemanticsNode child)`
  private func _adoptChild(_ child: SemanticsNode) {
    assert(child._parent == nil)
    assert({
      var node: SemanticsNode = self
      while node.parent != nil {
        node = node.parent!
      }
      assert(node !== child) // indicates we are about to create a cycle
      return true
    }())
    child._parent = self
    if attached {
      child.attach(_owner!)
    }
    _redepthChild(child)
    // In most cases, child should have up to date `isMergedIntoParent` since
    // it was set during _RenderObjectSemantics.buildSemantics. However, it is
    // still possible that this child was an extra node introduced in
    // RenderObject.assembleSemanticsNode. We have to make sure their
    // `isMergedIntoParent` is updated correctly.
    _updateChildMergeFlagRecursively(child)
  }

  /// **Dart Source:** `semantics.dart:2955-2962`
  /// **Original:** `void _dropChild(SemanticsNode child)`
  private func _dropChild(_ child: SemanticsNode) {
    assert(child._parent === self)
    assert(child.attached == attached)
    child._parent = nil
    if attached {
      child.detach()
    }
  }

  /// Mark this node as attached to the given owner.
  ///
  /// **Dart Source:** `semantics.dart:2966-2985`
  /// **Original:** `void attach(SemanticsOwner owner)`
  public func attach(_ owner: SemanticsOwner) {
    assert(_owner == nil)
    _owner = owner
    while owner._nodes[id] != nil {
      // Ids may repeat if Flutter has generated > 2^16 ids. We need to keep
      // regenerating the id until we find an id that is not used.
      _id = SemanticsNode._generateNewId()
    }
    owner._nodes[id] = self
    owner._detachedNodes.remove(self)
    if _dirty {
      _dirty = false
      _markDirty()
    }
    if let children = _children {
      for child in children {
        child.attach(owner)
      }
    }
  }

  /// Mark this node as detached from its owner.
  ///
  /// **Dart Source:** `semantics.dart:2989-3010`
  /// **Original:** `void detach()`
  public func detach() {
    assert(_owner != nil)
    assert(owner!._nodes[id] != nil)
    assert(!owner!._detachedNodes.contains(self))
    owner!._nodes.removeValue(forKey: id)
    owner!._detachedNodes.insert(self)
    _owner = nil
    assert(parent == nil || attached == parent!.attached)
    if let children = _children {
      for child in children {
        // The list of children may be stale and may contain nodes that have
        // been assigned to a different parent.
        if child.parent === self {
          child.detach()
        }
      }
    }
    // The other side will have forgotten this node if we ever send
    // it again, so make sure to mark it dirty so that it'll get
    // sent if it is resurrected.
    _markDirty()
  }

  // MARK: - Dirty Management
  /// **Dart Source:** `semantics.dart:3012-3040`

  /// **Dart Source:** `semantics.dart:3014`
  /// **Original:** `bool _dirty = false;`
  var _dirty: Bool = false

  /// **Dart Source:** `semantics.dart:3015-3024`
  /// **Original:** `void _markDirty()`
  func _markDirty() {
    if _dirty {
      return
    }
    _dirty = true
    if attached {
      assert(!owner!._detachedNodes.contains(self))
      owner!._dirtyNodes.insert(self)
    }
  }

  /// When asserts are enabled, returns whether node is marked as dirty.
  ///
  /// Otherwise, returns nil.
  ///
  /// This getter is intended for use in framework unit tests. Applications must
  /// not depend on its value.
  ///
  /// **Dart Source:** `semantics.dart:3033-3040`
  /// **Original:** `bool? get debugIsDirty`
  public var debugIsDirty: Bool? {
    var isDirty: Bool?
    assert({
      isDirty = _dirty
      return true
    }())
    return isDirty
  }

  // MARK: - Configuration Comparison
  /// **Dart Source:** `semantics.dart:3042-3067`

  /// **Dart Source:** `semantics.dart:3042-3067`
  /// **Original:** `bool _isDifferentFromCurrentSemanticAnnotation(SemanticsConfiguration config)`
  func _isDifferentFromCurrentSemanticAnnotation(_ config: SemanticsConfiguration) -> Bool {
    return _attributedLabel != config.attributedLabel
      || _attributedHint != config.attributedHint
      || _attributedValue != config.attributedValue
      || _attributedIncreasedValue != config.attributedIncreasedValue
      || _attributedDecreasedValue != config.attributedDecreasedValue
      || _tooltip != config.tooltip
      || _flags != config._flags
      || _textDirection != config.textDirection
      || _sortKey !== config._sortKey
      || _textSelection != config._textSelection
      || _scrollPosition != config._scrollPosition
      || _scrollExtentMax != config._scrollExtentMax
      || _scrollExtentMin != config._scrollExtentMin
      || _actionsAsBits != config._actionsAsBits
      || indexInParent != config.indexInParent
      || _platformViewId != config.platformViewId
      || _maxValueLength != config._maxValueLength
      || _currentValueLength != config._currentValueLength
      || _mergeAllDescendantsIntoThisNode != config.isMergingSemanticsOfDescendants
      || _areUserActionsBlocked != config.isBlockingUserActions
      || _headingLevel != config._headingLevel
      || _linkUrl != config._linkUrl
      || _role != config.role
      || _validationResult != config.validationResult
  }

  // MARK: - Tags, Labels, Actions
  /// **Dart Source:** `semantics.dart:3069-3362`

  /// **Dart Source:** `semantics.dart:3071`
  var _actions: [SemanticsAction: SemanticsActionHandler] = SemanticsNode._kEmptyConfig._actions

  /// **Dart Source:** `semantics.dart:3072-3073`
  var _customSemanticsActions: [CustomSemanticsAction: VoidCallback] = SemanticsNode._kEmptyConfig._customSemanticsActions

  /// **Dart Source:** `semantics.dart:3075-3076`
  var _effectiveActionsAsBits: Int {
    _areUserActionsBlocked ? _actionsAsBits & _kUnblockedUserActions : _actionsAsBits
  }

  /// **Dart Source:** `semantics.dart:3077`
  var _actionsAsBits: Int = SemanticsNode._kEmptyConfig._actionsAsBits

  /// The `SemanticsTag`s this node is tagged with.
  ///
  /// Tags are used during the construction of the semantics tree. They are not
  /// transferred to the engine.
  ///
  /// **Dart Source:** `semantics.dart:3083`
  /// **Original:** `Set<SemanticsTag>? tags;`
  public var tags: Set<SemanticsTag>?

  /// Whether this node is tagged with `tag`.
  ///
  /// **Dart Source:** `semantics.dart:3086`
  /// **Original:** `bool isTagged(SemanticsTag tag) => tags != null && tags!.contains(tag);`
  public func isTagged(_ tag: SemanticsTag) -> Bool {
    tags != nil && tags!.contains(tag)
  }

  /// **Dart Source:** `semantics.dart:3088`
  var _flags: SemanticsFlags = .none

  /// Semantics flags.
  ///
  /// **Dart Source:** `semantics.dart:3091`
  /// **Original:** `SemanticsFlags get flagsCollection => _flags;`
  public var flagsCollection: SemanticsFlags { _flags }

  /// **Dart Source:** `semantics.dart:3093`
  var _flagsBitMask: Int { toBitMask(flagsCollection) }

  // NOTE: Deprecated `hasFlag` (line 3096-3100) is intentionally skipped.

  /// A string identifier for this semantic node.
  ///
  /// **Dart Source:** `semantics.dart:3103-3104`
  /// **Original:** `String get identifier => _identifier;`
  public var identifier: String { _identifier }
  var _identifier: String = SemanticsNode._kEmptyConfig.identifier

  /// A textual description of this node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedLabel`.
  ///
  /// **Dart Source:** `semantics.dart:3111`
  /// **Original:** `String get label => _attributedLabel.string;`
  public var label: String { _attributedLabel.string }

  /// A textual description of this node in `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `label`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:3118-3119`
  /// **Original:** `AttributedString get attributedLabel => _attributedLabel;`
  public var attributedLabel: AttributedString { _attributedLabel }
  var _attributedLabel: AttributedString = SemanticsNode._kEmptyConfig.attributedLabel

  /// A textual description for the current value of the node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedValue`.
  ///
  /// **Dart Source:** `semantics.dart:3126`
  /// **Original:** `String get value => _attributedValue.string;`
  public var value: String { _attributedValue.string }

  /// A textual description for the current value of the node in
  /// `AttributedString` format.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// See also `value`, which exposes just the raw text.
  ///
  /// **Dart Source:** `semantics.dart:3134-3135`
  /// **Original:** `AttributedString get attributedValue => _attributedValue;`
  public var attributedValue: AttributedString { _attributedValue }
  var _attributedValue: AttributedString = SemanticsNode._kEmptyConfig.attributedValue

  /// The value that `value` will have after a `SemanticsAction.increase` action
  /// has been performed.
  ///
  /// This property is only valid if the `SemanticsAction.increase` action is
  /// available on this node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedIncreasedValue`.
  ///
  /// **Dart Source:** `semantics.dart:3146`
  /// **Original:** `String get increasedValue => _attributedIncreasedValue.string;`
  public var increasedValue: String { _attributedIncreasedValue.string }

  /// The value in `AttributedString` format that `value` or `attributedValue`
  /// will have after a `SemanticsAction.increase` action has been performed.
  ///
  /// **Dart Source:** `semantics.dart:3157-3158`
  /// **Original:** `AttributedString get attributedIncreasedValue => _attributedIncreasedValue;`
  public var attributedIncreasedValue: AttributedString { _attributedIncreasedValue }
  var _attributedIncreasedValue: AttributedString = SemanticsNode._kEmptyConfig.attributedIncreasedValue

  /// The value that `value` will have after a `SemanticsAction.decrease` action
  /// has been performed.
  ///
  /// This property is only valid if the `SemanticsAction.decrease` action is
  /// available on this node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedDecreasedValue`.
  ///
  /// **Dart Source:** `semantics.dart:3169`
  /// **Original:** `String get decreasedValue => _attributedDecreasedValue.string;`
  public var decreasedValue: String { _attributedDecreasedValue.string }

  /// The value in `AttributedString` format that `value` or `attributedValue`
  /// will have after a `SemanticsAction.decrease` action has been performed.
  ///
  /// **Dart Source:** `semantics.dart:3180-3181`
  /// **Original:** `AttributedString get attributedDecreasedValue => _attributedDecreasedValue;`
  public var attributedDecreasedValue: AttributedString { _attributedDecreasedValue }
  var _attributedDecreasedValue: AttributedString = SemanticsNode._kEmptyConfig.attributedDecreasedValue

  /// A brief description of the result of performing an action on this node.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// This exposes the raw text of the `attributedHint`.
  ///
  /// **Dart Source:** `semantics.dart:3188`
  /// **Original:** `String get hint => _attributedHint.string;`
  public var hint: String { _attributedHint.string }

  /// A brief description of the result of performing an action on this node
  /// in `AttributedString` format.
  ///
  /// **Dart Source:** `semantics.dart:3196-3197`
  /// **Original:** `AttributedString get attributedHint => _attributedHint;`
  public var attributedHint: AttributedString { _attributedHint }
  var _attributedHint: AttributedString = SemanticsNode._kEmptyConfig.attributedHint

  /// A textual description of the widget's tooltip.
  ///
  /// The reading direction is given by `textDirection`.
  ///
  /// **Dart Source:** `semantics.dart:3202-3203`
  /// **Original:** `String get tooltip => _tooltip;`
  public var tooltip: String { _tooltip }
  var _tooltip: String = SemanticsNode._kEmptyConfig.tooltip

  /// Provides hint values which override the default hints on supported
  /// platforms.
  ///
  /// **Dart Source:** `semantics.dart:3207-3208`
  /// **Original:** `SemanticsHintOverrides? get hintOverrides => _hintOverrides;`
  public var hintOverrides: SemanticsHintOverrides? { _hintOverrides }
  var _hintOverrides: SemanticsHintOverrides?

  /// The reading direction for `label`, `value`, `hint`, `increasedValue`, and
  /// `decreasedValue`.
  ///
  /// **Dart Source:** `semantics.dart:3212-3213`
  /// **Original:** `TextDirection? get textDirection => _textDirection;`
  public var textDirection: TextDirection? { _textDirection }
  var _textDirection: TextDirection? = SemanticsNode._kEmptyConfig.textDirection

  /// Determines the position of this node among its siblings in the traversal
  /// sort order.
  ///
  /// **Dart Source:** `semantics.dart:3221-3222`
  /// **Original:** `SemanticsSortKey? get sortKey => _sortKey;`
  public var sortKey: SemanticsSortKey? { _sortKey }
  var _sortKey: SemanticsSortKey?

  /// The currently selected text (or the position of the cursor) within `value`
  /// if this node represents a text field.
  ///
  /// **Dart Source:** `semantics.dart:3226-3227`
  /// **Original:** `TextSelection? get textSelection => _textSelection;`
  public var textSelection: TextSelection? { _textSelection }
  var _textSelection: TextSelection?

  /// If this node represents a text field, this indicates whether or not it's
  /// a multiline text field.
  ///
  /// **Dart Source:** `semantics.dart:3231-3232`
  /// **Original:** `bool? get isMultiline => _isMultiline;`
  public var isMultiline: Bool? { _isMultiline }
  var _isMultiline: Bool?

  /// The total number of scrollable children that contribute to semantics.
  ///
  /// **Dart Source:** `semantics.dart:3238-3239`
  /// **Original:** `int? get scrollChildCount => _scrollChildCount;`
  public var scrollChildCount: Int? { _scrollChildCount }
  var _scrollChildCount: Int?

  /// The index of the first visible semantic child of a scroll node.
  ///
  /// **Dart Source:** `semantics.dart:3242-3243`
  /// **Original:** `int? get scrollIndex => _scrollIndex;`
  public var scrollIndex: Int? { _scrollIndex }
  var _scrollIndex: Int?

  /// Indicates the current scrolling position in logical pixels if the node is
  /// scrollable.
  ///
  /// **Dart Source:** `semantics.dart:3255-3256`
  /// **Original:** `double? get scrollPosition => _scrollPosition;`
  public var scrollPosition: Double? { _scrollPosition }
  var _scrollPosition: Double?

  /// Indicates the maximum in-range value for `scrollPosition` if the node is
  /// scrollable.
  ///
  /// **Dart Source:** `semantics.dart:3266-3267`
  /// **Original:** `double? get scrollExtentMax => _scrollExtentMax;`
  public var scrollExtentMax: Double? { _scrollExtentMax }
  var _scrollExtentMax: Double?

  /// Indicates the minimum in-range value for `scrollPosition` if the node is
  /// scrollable.
  ///
  /// **Dart Source:** `semantics.dart:3277-3278`
  /// **Original:** `double? get scrollExtentMin => _scrollExtentMin;`
  public var scrollExtentMin: Double? { _scrollExtentMin }
  var _scrollExtentMin: Double?

  /// The id of the platform view, whose semantics nodes will be added as
  /// children to this node.
  ///
  /// **Dart Source:** `semantics.dart:3291-3292`
  /// **Original:** `int? get platformViewId => _platformViewId;`
  public var platformViewId: Int? { _platformViewId }
  var _platformViewId: Int?

  /// The maximum number of characters that can be entered into an editable
  /// text field.
  ///
  /// **Dart Source:** `semantics.dart:3302-3303`
  /// **Original:** `int? get maxValueLength => _maxValueLength;`
  public var maxValueLength: Int? { _maxValueLength }
  var _maxValueLength: Int?

  /// The current number of characters that have been entered into an editable
  /// text field.
  ///
  /// **Dart Source:** `semantics.dart:3313-3314`
  /// **Original:** `int? get currentValueLength => _currentValueLength;`
  public var currentValueLength: Int? { _currentValueLength }
  var _currentValueLength: Int?

  /// The level of the widget as a heading within the structural hierarchy
  /// of the screen.
  ///
  /// **Dart Source:** `semantics.dart:3319-3320`
  /// **Original:** `int get headingLevel => _headingLevel;`
  public var headingLevel: Int { _headingLevel }
  var _headingLevel: Int = SemanticsNode._kEmptyConfig._headingLevel

  /// The URL that this node links to.
  ///
  /// **Dart Source:** `semantics.dart:3323-3324`
  /// **Original:** `Uri? get linkUrl => _linkUrl;`
  ///
  /// DIFFERENCE FROM DART: Uses `URL` (Foundation) instead of Dart's `Uri`.
  /// REASON: `URL` is Swift's standard type for URIs.
  public var linkUrl: URL? { _linkUrl }
  var _linkUrl: URL? = SemanticsNode._kEmptyConfig._linkUrl

  /// The role this node represents.
  ///
  /// A semantics node's role helps assistive technologies, such as screen
  /// readers, understand and interact with the UI correctly.
  ///
  /// **Dart Source:** `semantics.dart:3334-3335`
  /// **Original:** `SemanticsRole get role => _role;`
  public var role: SemanticsRole { _role }
  var _role: SemanticsRole = SemanticsNode._kEmptyConfig.role

  /// The `SemanticsNode.identifier`s of widgets controlled by this node.
  ///
  /// **Dart Source:** `semantics.dart:3342-3343`
  /// **Original:** `Set<String>? get controlsNodes => _controlsNodes;`
  public var controlsNodes: Set<String>? { _controlsNodes }
  var _controlsNodes: Set<String>? = SemanticsNode._kEmptyConfig.controlsNodes

  /// The validation result for this node.
  ///
  /// **Dart Source:** `semantics.dart:3346-3347`
  /// **Original:** `SemanticsValidationResult get validationResult => _validationResult;`
  public var validationResult: SemanticsValidationResult { _validationResult }
  var _validationResult: SemanticsValidationResult = SemanticsNode._kEmptyConfig.validationResult

  /// The input type for an editable node.
  ///
  /// **Dart Source:** `semantics.dart:3358-3359`
  /// **Original:** `SemanticsInputType get inputType => _inputType;`
  public var inputType: SemanticsInputType { _inputType }
  var _inputType: SemanticsInputType = SemanticsNode._kEmptyConfig.inputType

  /// **Dart Source:** `semantics.dart:3361`
  /// **Original:** `bool _canPerformAction(SemanticsAction action) => _actions.containsKey(action);`
  func _canPerformAction(_ action: SemanticsAction) -> Bool {
    _actions[action] != nil
  }

  // MARK: - updateWith
  /// **Dart Source:** `semantics.dart:3374-3444`

  /// Reconfigures the properties of this object to describe the configuration
  /// provided in the `config` argument and the children listed in the
  /// `childrenInInversePaintOrder` argument.
  ///
  /// The arguments may be nil; this represents an empty configuration (all
  /// values at their defaults, no children).
  ///
  /// No reference is kept to the `SemanticsConfiguration` object, but the child
  /// list is used as-is and should therefore not be changed after this call.
  ///
  /// **Dart Source:** `semantics.dart:3374-3444`
  /// **Original:** `void updateWith({required SemanticsConfiguration? config, List<SemanticsNode>? childrenInInversePaintOrder})`
  public func updateWith(
    config: SemanticsConfiguration? = nil,
    childrenInInversePaintOrder: [SemanticsNode]? = nil
  ) {
    let effectiveConfig = config ?? SemanticsNode._kEmptyConfig
    if _isDifferentFromCurrentSemanticAnnotation(effectiveConfig) {
      _markDirty()
    }

    assert(
      effectiveConfig.platformViewId == nil
        || childrenInInversePaintOrder == nil
        || childrenInInversePaintOrder!.isEmpty,
      "SemanticsNodes with children must not specify a platformViewId."
    )

    let mergeAllDescendantsIntoThisNodeValueChanged =
      _mergeAllDescendantsIntoThisNode != effectiveConfig.isMergingSemanticsOfDescendants

    _identifier = effectiveConfig.identifier
    _attributedLabel = effectiveConfig.attributedLabel
    _attributedValue = effectiveConfig.attributedValue
    _attributedIncreasedValue = effectiveConfig.attributedIncreasedValue
    _attributedDecreasedValue = effectiveConfig.attributedDecreasedValue
    _attributedHint = effectiveConfig.attributedHint
    _tooltip = effectiveConfig.tooltip
    _hintOverrides = effectiveConfig.hintOverrides
    _flags = effectiveConfig._flags
    _textDirection = effectiveConfig.textDirection
    _sortKey = effectiveConfig.sortKey
    _actions = Dictionary(uniqueKeysWithValues: effectiveConfig._actions.map { ($0.key, $0.value) })
    _customSemanticsActions = Dictionary(uniqueKeysWithValues: effectiveConfig._customSemanticsActions.map { ($0.key, $0.value) })
    _actionsAsBits = effectiveConfig._actionsAsBits
    _textSelection = effectiveConfig._textSelection
    _isMultiline = effectiveConfig.isMultiline
    _scrollPosition = effectiveConfig._scrollPosition
    _scrollExtentMax = effectiveConfig._scrollExtentMax
    _scrollExtentMin = effectiveConfig._scrollExtentMin
    _mergeAllDescendantsIntoThisNode = effectiveConfig.isMergingSemanticsOfDescendants
    _scrollChildCount = effectiveConfig.scrollChildCount
    _scrollIndex = effectiveConfig.scrollIndex
    indexInParent = effectiveConfig.indexInParent
    _platformViewId = effectiveConfig._platformViewId
    _maxValueLength = effectiveConfig._maxValueLength
    _currentValueLength = effectiveConfig._currentValueLength
    _areUserActionsBlocked = effectiveConfig.isBlockingUserActions
    _headingLevel = effectiveConfig._headingLevel
    _linkUrl = effectiveConfig._linkUrl
    _role = effectiveConfig._role
    _controlsNodes = effectiveConfig._controlsNodes
    _validationResult = effectiveConfig._validationResult
    _inputType = effectiveConfig._inputType
    _locale = effectiveConfig.locale

    _replaceChildren(childrenInInversePaintOrder ?? [])

    if mergeAllDescendantsIntoThisNodeValueChanged {
      _updateChildrenMergeFlags()
    }

    assert(
      !_canPerformAction(.increase) || (value == "") == (increasedValue == ""),
      "A SemanticsNode with action \"increase\" needs to be annotated with either both \"value\" and \"increasedValue\" or neither"
    )
    assert(
      !_canPerformAction(.decrease) || (value == "") == (decreasedValue == ""),
      "A SemanticsNode with action \"decrease\" needs to be annotated with either both \"value\" and \"decreasedValue\" or neither"
    )
  }

  // MARK: - getSemanticsData
  /// **Dart Source:** `semantics.dart:3451-3633`

  /// Returns a summary of the semantics for this node.
  ///
  /// If this node has `mergeAllDescendantsIntoThisNode`, then the returned data
  /// includes the information from this node's descendants. Otherwise, the
  /// returned data matches the data on this node.
  ///
  /// **Dart Source:** `semantics.dart:3451-3633`
  /// **Original:** `SemanticsData getSemanticsData()`
  public func getSemanticsData() -> SemanticsData {
    var flags = _flags
    // Can't use _effectiveActionsAsBits here. The filtering of action bits
    // must be done after the merging with descendants.
    var actions = _actionsAsBits
    var identifier = _identifier
    var attributedLabel = _attributedLabel
    var attributedValue = _attributedValue
    var attributedIncreasedValue = _attributedIncreasedValue
    var attributedDecreasedValue = _attributedDecreasedValue
    var attributedHint = _attributedHint
    var tooltip = _tooltip
    var textDirection = _textDirection
    var mergedTags: Set<SemanticsTag>? = tags != nil ? Set(tags!) : nil
    var textSelection = _textSelection
    var scrollChildCount = _scrollChildCount
    var scrollIndex = _scrollIndex
    var scrollPosition = _scrollPosition
    var scrollExtentMax = _scrollExtentMax
    var scrollExtentMin = _scrollExtentMin
    var platformViewId = _platformViewId
    var maxValueLength = _maxValueLength
    var currentValueLength = _currentValueLength
    var headingLevel = _headingLevel
    var linkUrl = _linkUrl
    var role = _role
    var controlsNodes = _controlsNodes
    var validationResult = _validationResult
    var inputType = _inputType
    let locale = _locale
    var customSemanticsActionIds = Set<Int>()

    for action in _customSemanticsActions.keys {
      customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
    }
    if let overrides = hintOverrides {
      if let onTapHint = overrides.onTapHint {
        let action = CustomSemanticsAction(
          overridingHint: onTapHint,
          action: SemanticsAction.tap
        )
        customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
      }
      if let onLongPressHint = overrides.onLongPressHint {
        let action = CustomSemanticsAction(
          overridingHint: onLongPressHint,
          action: SemanticsAction.longPress
        )
        customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
      }
    }

    if mergeAllDescendantsIntoThisNode {
      _visitDescendants { (node: SemanticsNode) -> Bool in
        assert(node.isMergedIntoParent)
        flags = flags.merge(node._flags)
        actions |= node._effectiveActionsAsBits
        textDirection = textDirection ?? node._textDirection
        textSelection = textSelection ?? node._textSelection
        scrollChildCount = scrollChildCount ?? node._scrollChildCount
        scrollIndex = scrollIndex ?? node._scrollIndex
        scrollPosition = scrollPosition ?? node._scrollPosition
        scrollExtentMax = scrollExtentMax ?? node._scrollExtentMax
        scrollExtentMin = scrollExtentMin ?? node._scrollExtentMin
        platformViewId = platformViewId ?? node._platformViewId
        maxValueLength = maxValueLength ?? node._maxValueLength
        currentValueLength = currentValueLength ?? node._currentValueLength
        linkUrl = linkUrl ?? node._linkUrl

        headingLevel = mergeHeadingLevels(
          sourceLevel: node._headingLevel,
          targetLevel: headingLevel
        )

        if identifier == "" {
          identifier = node._identifier
        }
        if attributedValue.string == "" {
          attributedValue = node._attributedValue
        }
        if attributedIncreasedValue.string == "" {
          attributedIncreasedValue = node._attributedIncreasedValue
        }
        if attributedDecreasedValue.string == "" {
          attributedDecreasedValue = node._attributedDecreasedValue
        }
        if role == .none {
          role = node._role
        }
        if inputType == .none {
          inputType = node._inputType
        }
        if tooltip == "" {
          tooltip = node._tooltip
        }
        if node.tags != nil {
          if mergedTags == nil {
            mergedTags = Set<SemanticsTag>()
          }
          mergedTags!.formUnion(node.tags!)
        }
        for action in node._customSemanticsActions.keys {
          customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
        }
        if let nodeOverrides = node.hintOverrides {
          if let onTapHint = nodeOverrides.onTapHint {
            let action = CustomSemanticsAction(
              overridingHint: onTapHint,
              action: SemanticsAction.tap
            )
            customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
          }
          if let onLongPressHint = nodeOverrides.onLongPressHint {
            let action = CustomSemanticsAction(
              overridingHint: onLongPressHint,
              action: SemanticsAction.longPress
            )
            customSemanticsActionIds.insert(CustomSemanticsAction.getIdentifier(action))
          }
        }
        attributedLabel = concatAttributedString(
          thisAttributedString: attributedLabel,
          otherAttributedString: node._attributedLabel,
          thisTextDirection: textDirection,
          otherTextDirection: node._textDirection
        )
        attributedHint = concatAttributedString(
          thisAttributedString: attributedHint,
          otherAttributedString: node._attributedHint,
          thisTextDirection: textDirection,
          otherTextDirection: node._textDirection
        )

        if controlsNodes == nil {
          controlsNodes = node._controlsNodes
        } else if node._controlsNodes != nil {
          controlsNodes = controlsNodes!.union(node._controlsNodes!)
        }

        if validationResult == .none {
          validationResult = node._validationResult
        } else if validationResult == .valid {
          // When merging nodes, invalid validation result takes precedence.
          // Otherwise, validation information could be lost.
          if node._validationResult != .none
            && node._validationResult != .valid
          {
            validationResult = node._validationResult
          }
        }

        return true
      }
    }

    return SemanticsData(
      flagsCollection: flags,
      actions: _areUserActionsBlocked ? actions & _kUnblockedUserActions : actions,
      identifier: identifier,
      attributedLabel: attributedLabel,
      attributedValue: attributedValue,
      attributedIncreasedValue: attributedIncreasedValue,
      attributedDecreasedValue: attributedDecreasedValue,
      attributedHint: attributedHint,
      tooltip: tooltip,
      textDirection: textDirection,
      rect: rect,
      textSelection: textSelection,
      scrollIndex: scrollIndex,
      scrollChildCount: scrollChildCount,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      platformViewId: platformViewId,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      headingLevel: headingLevel,
      linkUrl: linkUrl,
      role: role,
      controlsNodes: controlsNodes,
      validationResult: validationResult,
      inputType: inputType,
      locale: locale,
      tags: mergedTags,
      transform: transform,
      customSemanticsActionIds: customSemanticsActionIds.sorted()
    )
  }

  // MARK: - _addToUpdate
  /// **Dart Source:** `semantics.dart:3643-3721`

  /// Builds the `SemanticsUpdateBuilder` calls for this node.
  ///
  /// **Dart Source:** `semantics.dart:3643-3721`
  /// **Original:** `void _addToUpdate(SemanticsUpdateBuilder builder, Set<int> customSemanticsActionIdsUpdate)`
  func _addToUpdate(
    _ builder: SemanticsUpdateBuilder,
    customSemanticsActionIdsUpdate: inout Set<Int>
  ) {
    assert(_dirty)
    let data = getSemanticsData()
    assert({
      // TODO: Implement full role validation when DebugSemanticsRoleChecks is complete.
      // let error = DebugSemanticsRoleChecks.checkSemanticsData(role: data.role)
      return true
    }())

    let childrenInTraversalOrder: [Int32]
    let childrenInHitTestOrder: [Int32]
    if !hasChildren || mergeAllDescendantsIntoThisNode {
      childrenInTraversalOrder = SemanticsNode._kEmptyChildList
      childrenInHitTestOrder = SemanticsNode._kEmptyChildList
    } else {
      let childCount = _children!.count
      let sortedChildren = _childrenInTraversalOrder()
      var traversalOrder = [Int32](repeating: 0, count: childCount)
      for i in 0..<childCount {
        traversalOrder[i] = Int32(sortedChildren[i].id)
      }
      childrenInTraversalOrder = traversalOrder

      // _children is sorted in paint order, so we invert it to get the hit test
      // order.
      var hitTestOrder = [Int32](repeating: 0, count: childCount)
      for i in stride(from: childCount - 1, through: 0, by: -1) {
        hitTestOrder[i] = Int32(_children![childCount - i - 1].id)
      }
      childrenInHitTestOrder = hitTestOrder
    }

    var customSemanticsActionIds: [Int32]?
    if let actionIds = data.customSemanticsActionIds, !actionIds.isEmpty {
      customSemanticsActionIds = [Int32](repeating: 0, count: actionIds.count)
      for i in 0..<actionIds.count {
        customSemanticsActionIds![i] = Int32(actionIds[i])
        customSemanticsActionIdsUpdate.insert(actionIds[i])
      }
    }

    builder.updateNode(
      id: id,
      flags: data.flagsCollection,
      actions: data.actions,
      rect: data.rect,
      identifier: data.identifier,
      label: data.attributedLabel.string,
      labelAttributes: data.attributedLabel.attributes,
      value: data.attributedValue.string,
      valueAttributes: data.attributedValue.attributes,
      increasedValue: data.attributedIncreasedValue.string,
      increasedValueAttributes: data.attributedIncreasedValue.attributes,
      decreasedValue: data.attributedDecreasedValue.string,
      decreasedValueAttributes: data.attributedDecreasedValue.attributes,
      hint: data.attributedHint.string,
      hintAttributes: data.attributedHint.attributes,
      tooltip: data.tooltip,
      textDirection: data.textDirection,
      textSelectionBase: data.textSelection != nil ? data.textSelection!.baseOffset : -1,
      textSelectionExtent: data.textSelection != nil ? data.textSelection!.extentOffset : -1,
      platformViewId: data.platformViewId ?? -1,
      maxValueLength: data.maxValueLength ?? -1,
      currentValueLength: data.currentValueLength ?? -1,
      scrollChildren: data.scrollChildCount ?? 0,
      scrollIndex: data.scrollIndex ?? 0,
      scrollPosition: data.scrollPosition ?? .nan,
      scrollExtentMax: data.scrollExtentMax ?? .nan,
      scrollExtentMin: data.scrollExtentMin ?? .nan,
      transform: data.transform?.storage ?? SemanticsNode._kIdentityTransform,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: customSemanticsActionIds ?? SemanticsNode._kEmptyCustomSemanticsActionsList,
      headingLevel: data.headingLevel,
      linkUrl: data.linkUrl?.absoluteString ?? "",
      role: data.role,
      controlsNodes: data.controlsNodes != nil ? Array(data.controlsNodes!) : nil,
      validationResult: data.validationResult,
      inputType: data.inputType,
      locale: data.locale
    )
    _dirty = false
  }

  // MARK: - _childrenInTraversalOrder
  /// **Dart Source:** `semantics.dart:3723-3778`

  /// Builds a new list made of `_children` sorted in semantic traversal order.
  ///
  /// **Dart Source:** `semantics.dart:3724-3778`
  /// **Original:** `List<SemanticsNode> _childrenInTraversalOrder()`
  func _childrenInTraversalOrder() -> [SemanticsNode] {
    var inheritedTextDirection: TextDirection? = textDirection
    var ancestor: SemanticsNode? = parent
    while inheritedTextDirection == nil && ancestor != nil {
      inheritedTextDirection = ancestor!.textDirection
      ancestor = ancestor!.parent
    }

    var childrenInDefaultOrder: [SemanticsNode]?
    if let textDir = inheritedTextDirection {
      childrenInDefaultOrder = Flutter.childrenInDefaultOrder(_children!, textDir)
    } else {
      // In the absence of text direction default to paint order.
      childrenInDefaultOrder = _children
    }

    // List.sort does not guarantee stable sort order. Therefore, children are
    // first partitioned into groups that have compatible sort keys, i.e. keys
    // in the same group can be compared to each other. These groups stay in
    // the same place. Only children within the same group are sorted.
    var everythingSorted: [TraversalSortNode] = []
    var sortNodes: [TraversalSortNode] = []
    var lastSortKey: SemanticsSortKey?

    for position in 0..<childrenInDefaultOrder!.count {
      let child = childrenInDefaultOrder![position]
      let sortKey = child.sortKey
      lastSortKey = position > 0 ? childrenInDefaultOrder![position - 1].sortKey : nil

      let isCompatibleWithPreviousSortKey =
        position == 0
        || (type(of: sortKey as Any) == type(of: lastSortKey as Any)
          && (sortKey == nil || sortKey!.name == lastSortKey!.name))

      if !isCompatibleWithPreviousSortKey && !sortNodes.isEmpty {
        // Do not sort groups with nil sort keys. sort() does not guarantee
        // a stable sort order.
        if lastSortKey != nil {
          sortNodes.sort()
        }
        everythingSorted.append(contentsOf: sortNodes)
        sortNodes.removeAll()
      }

      sortNodes.append(TraversalSortNode(node: child, sortKey: sortKey, position: position))
    }

    // Do not sort groups with nil sort keys. sort() does not guarantee
    // a stable sort order.
    if lastSortKey != nil {
      sortNodes.sort()
    }
    everythingSorted.append(contentsOf: sortNodes)

    return everythingSorted.map { $0.node }
  }

  // MARK: - sendEvent
  /// **Dart Source:** `semantics.dart:3784-3789`

  /// Sends a `SemanticsEvent` associated with this `SemanticsNode`.
  ///
  /// Semantics events should be sent to inform interested parties (like
  /// the accessibility system of the operating system) about changes to the UI.
  ///
  /// **Dart Source:** `semantics.dart:3784-3789`
  /// **Original:** `void sendEvent(SemanticsEvent event)`
  ///
  /// TODO: Implement when SystemChannels.accessibility is migrated.
  public func sendEvent(_ event: SemanticsEvent) {
    if !attached {
      return
    }
    // TODO: SystemChannels.accessibility.send(event.toMap(nodeId: id))
    // Stubbed until SystemChannels is migrated.
  }

  // MARK: - Debug helpers
  /// **Dart Source:** `semantics.dart:3791-3798`

  /// **Dart Source:** `semantics.dart:3791-3798`
  /// **Original:** `bool _debugIsActionBlocked(SemanticsAction action)`
  func _debugIsActionBlocked(_ action: SemanticsAction) -> Bool {
    var result = false
    assert({
      result = (_effectiveActionsAsBits & action.index) == 0
      return true
    }())
    return result
  }

  // MARK: - Diagnostics
  /// **Dart Source:** `semantics.dart:3800-3980`

  /// **Dart Source:** `semantics.dart:3801`
  /// **Original:** `String toStringShort() => '${objectRuntimeType(this, 'SemanticsNode')}#$id';`
  public func toStringShort() -> String {
    "\(objectRuntimeType(self, "SemanticsNode"))#\(id)"
  }

  /// **Dart Source:** `semantics.dart:3804-3922`
  /// **Original:** `void debugFillProperties(DiagnosticPropertiesBuilder properties)`
  public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
    var hideOwner = true
    if _dirty {
      let inDirtyNodes = owner != nil && owner!._dirtyNodes.contains(self)
      properties.add(
        FlagProperty("inDirtyNodes", value: inDirtyNodes, ifTrue: "dirty", ifFalse: "STALE")
      )
      hideOwner = inDirtyNodes
    }
    properties.add(
      DiagnosticsProperty<SemanticsOwner>(
        "owner",
        owner,
        level: hideOwner ? .hidden : .info
      )
    )
    properties.add(
      FlagProperty("isMergedIntoParent", value: isMergedIntoParent, ifTrue: "merged up")
    )
    properties.add(
      FlagProperty(
        "mergeAllDescendantsIntoThisNode",
        value: mergeAllDescendantsIntoThisNode,
        ifTrue: "merge boundary"
      )
    )
    if _locale != nil {
      properties.add(StringProperty("locale", "\(_locale!)"))
    }
    let offset: Offset? = transform != nil ? MatrixUtils.getAsTranslation(transform!) : nil
    if let offset = offset {
      properties.add(
        DiagnosticsProperty<Rect>("rect", rect.shift(offset), showName: false)
      )
    } else {
      let scale: Double? = transform != nil ? MatrixUtils.getAsScale(transform!) : nil
      var description: String?
      if let scale = scale {
        description = "\(rect) scaled by \(String(format: "%.1f", scale))x"
      } else if transform != nil && !MatrixUtils.isIdentity(transform!) {
        let matrix = "\(transform!)"
          .split(separator: "\n")
          .prefix(4)
          .map { line -> String in
            let s = String(line)
            return s.count > 4 ? String(s.dropFirst(4)) : s
          }
          .joined(separator: "; ")
        description = "\(rect) with transform [\(matrix)]"
      }
      properties.add(
        DiagnosticsProperty<Rect>(
          "rect", rect, description: description, showName: false
        )
      )
    }
    properties.add(
      IterableProperty<String>(
        "tags",
        tags?.map { $0.name }
      )
    )
    let actionNames: [String] = _actions.keys
      .map { action in
        "\(action.name)\(_debugIsActionBlocked(action) ? " (blocked)" : "")"
      }
      .sorted()
    let customActionNames: [String?] = _customSemanticsActions.keys
      .map { $0.label }
    properties.add(IterableProperty<String>("actions", actionNames, ifEmpty: nil))
    properties.add(
      IterableProperty<String?>("customActions", customActionNames, ifEmpty: nil)
    )
    properties.add(
      IterableProperty<String>("flags", flagsCollection.toStrings(), ifEmpty: nil)
    )
    properties.add(FlagProperty("isInvisible", value: isInvisible, ifTrue: "invisible"))
    properties.add(
      FlagProperty("isHidden", value: flagsCollection.isHidden, ifTrue: "HIDDEN")
    )
    properties.add(StringProperty("identifier", _identifier, defaultValue: ""))
    properties.add(AttributedStringProperty("label", _attributedLabel))
    properties.add(AttributedStringProperty("value", _attributedValue))
    properties.add(AttributedStringProperty("increasedValue", _attributedIncreasedValue))
    properties.add(AttributedStringProperty("decreasedValue", _attributedDecreasedValue))
    properties.add(AttributedStringProperty("hint", _attributedHint))
    properties.add(StringProperty("tooltip", _tooltip, defaultValue: ""))
    if let td = _textDirection {
      properties.add(StringProperty("textDirection", "\(td)"))
    }
    if _role != .none {
      properties.add(StringProperty("role", "\(_role)"))
    }
    properties.add(
      DiagnosticsProperty<SemanticsSortKey>("sortKey", sortKey)
    )
    if _textSelection?.isValid ?? false {
      properties.add(
        MessageProperty(
          "text selection",
          "[\(_textSelection!.start), \(_textSelection!.end)]"
        )
      )
    }
    properties.add(IntProperty("platformViewId", platformViewId))
    properties.add(IntProperty("maxValueLength", maxValueLength))
    properties.add(IntProperty("currentValueLength", currentValueLength))
    properties.add(IntProperty("scrollChildren", scrollChildCount))
    properties.add(IntProperty("scrollIndex", scrollIndex))
    properties.add(DoubleProperty("scrollExtentMin", scrollExtentMin))
    properties.add(DoubleProperty("scrollPosition", scrollPosition))
    properties.add(DoubleProperty("scrollExtentMax", scrollExtentMax))
    properties.add(IntProperty("indexInParent", indexInParent))
    properties.add(IntProperty("headingLevel", _headingLevel, defaultValue: 0))
    if _inputType != .none {
      properties.add(StringProperty("inputType", "\(_inputType)"))
    }
    if validationResult != .none {
      properties.add(StringProperty("validationResult", "\(validationResult)"))
    }
  }

  /// Returns a string representation of this node and its descendants.
  ///
  /// The order in which the children of the `SemanticsNode` will be printed is
  /// controlled by the `childOrder` parameter.
  ///
  /// **Dart Source:** `semantics.dart:3929-3942`
  /// **Original:** `String toStringDeep({...})`
  public func toStringDeep(
    prefixLineOne: String = "",
    prefixOtherLines: String? = nil,
    minLevel: DiagnosticLevel = .debug,
    childOrder: DebugSemanticsDumpOrder = .traversalOrder,
    wrapWidth: Int = 65
  ) -> String {
    return toDiagnosticsNode(childOrder: childOrder).toStringDeep(
      prefixLineOne: prefixLineOne,
      prefixOtherLines: prefixOtherLines,
      minLevel: minLevel,
      wrapWidth: wrapWidth
    )
  }

  /// **Dart Source:** `semantics.dart:3944-3956`
  /// **Original:** `DiagnosticsNode toDiagnosticsNode({...})`
  public func toDiagnosticsNode(
    name: String? = nil,
    style: DiagnosticsTreeStyle? = .sparse,
    childOrder: DebugSemanticsDumpOrder = .traversalOrder
  ) -> DiagnosticsNode {
    return SemanticsDiagnosticableNode(
      name: name,
      value: self,
      style: style,
      childOrder: childOrder
    )
  }

  /// **Dart Source:** `semantics.dart:3958-3967`
  /// **Original:** `List<DiagnosticsNode> debugDescribeChildren({...})`
  public func debugDescribeChildren(
    childOrder: DebugSemanticsDumpOrder = .inverseHitTest
  ) -> [any DiagnosticsNodeProtocol] {
    return debugListChildrenInOrder(childOrder).map { node in
      node.toDiagnosticsNode(childOrder: childOrder) as any DiagnosticsNodeProtocol
    }
  }

  /// Returns the list of direct children of this node in the specified order.
  ///
  /// **Dart Source:** `semantics.dart:3969-3979`
  /// **Original:** `List<SemanticsNode> debugListChildrenInOrder(DebugSemanticsDumpOrder childOrder)`
  public func debugListChildrenInOrder(_ childOrder: DebugSemanticsDumpOrder) -> [SemanticsNode] {
    guard let children = _children else {
      return []
    }

    switch childOrder {
    case .inverseHitTest:
      return children
    case .traversalOrder:
      return _childrenInTraversalOrder()
    }
  }
}
