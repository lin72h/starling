// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Traversal sort helper types for computing the default accessibility
/// traversal order of `SemanticsNode` children.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Lines:** 3982-4273

import Foundation
import FlutterSwiftBridge

// MARK: - BoxEdge

/// An edge of a box, such as top, bottom, left or right, used to compute
/// `SemanticsNode`s that overlap vertically or horizontally.
///
/// For computing horizontal overlap in an LTR setting we create two `BoxEdge`
/// objects for each `SemanticsNode`: one representing the left edge (marked
/// with `isLeadingEdge` equal to true) and one for the right edge (with
/// `isLeadingEdge` equal to false). Similarly, for vertical overlap we also
/// create two objects for each `SemanticsNode`, one for the top and one for
/// the bottom edge.
///
/// **Dart Source:** `semantics.dart:3990-4016`
/// **Original Name:** `_BoxEdge`
///
/// DIFFERENCE FROM DART: Uses a Swift `struct` instead of Dart `class`.
/// REASON: `_BoxEdge` is an immutable value type with no identity semantics;
/// Swift `struct` is the idiomatic equivalent.
struct BoxEdge: Comparable {
  /// True if the edge comes before the second edge along the traversal
  /// direction, and false otherwise.
  ///
  /// For example, in LTR traversal the left edge's `isLeadingEdge` is set to
  /// true, the right edge's `isLeadingEdge` is set to false. When considering
  /// vertical ordering of boxes, the top edge is the start edge, and the
  /// bottom edge is the end edge.
  ///
  /// **Dart Source:** `semantics.dart:4003`
  let isLeadingEdge: Bool

  /// The offset from the start edge of the parent `SemanticsNode` in the
  /// direction of the traversal.
  ///
  /// **Dart Source:** `semantics.dart:4007`
  let offset: Double

  /// The node whom this edge belongs.
  ///
  /// **Dart Source:** `semantics.dart:4010`
  let node: SemanticsNode

  /// Creates a box edge.
  ///
  /// **Dart Source:** `semantics.dart:3991-3992`
  /// **Original:** `_BoxEdge({required this.isLeadingEdge, required this.offset, required this.node})`
  init(isLeadingEdge: Bool, offset: Double, node: SemanticsNode) {
    assert(offset.isFinite)
    self.isLeadingEdge = isLeadingEdge
    self.offset = offset
    self.node = node
  }

  /// **Dart Source:** `semantics.dart:4013-4015`
  /// **Original:** `int compareTo(_BoxEdge other) => offset.compareTo(other.offset);`
  static func < (lhs: BoxEdge, rhs: BoxEdge) -> Bool {
    lhs.offset < rhs.offset
  }

  /// Equality is based on offset comparison, matching Dart's `Comparable`
  /// semantics where `compareTo` returning 0 implies equality for sorting.
  static func == (lhs: BoxEdge, rhs: BoxEdge) -> Bool {
    lhs.offset == rhs.offset
  }
}

// MARK: - SemanticsSortGroup

/// A group of `nodes` that are disjoint vertically or horizontally from other
/// nodes that share the same `SemanticsNode` parent.
///
/// The `nodes` are sorted among each other separately from other nodes.
///
/// **Dart Source:** `semantics.dart:4022-4171`
/// **Original Name:** `_SemanticsSortGroup`
///
/// DIFFERENCE FROM DART: Uses a Swift `class` instead of Dart `class`.
/// REASON: The Dart class uses identity semantics (mutable `nodes` list
/// modified after construction) and is passed by reference; Swift `class`
/// is the correct equivalent.
class SemanticsSortGroup: Comparable {

  /// The offset from the start edge of the parent `SemanticsNode` in the
  /// direction of the traversal.
  ///
  /// This value is equal to the `BoxEdge.offset` of the first node in the
  /// `nodes` list being considered.
  ///
  /// **Dart Source:** `semantics.dart:4030`
  let startOffset: Double

  /// **Dart Source:** `semantics.dart:4032`
  let textDirection: TextDirection

  /// The nodes that are sorted among each other.
  ///
  /// **Dart Source:** `semantics.dart:4035`
  var nodes: [SemanticsNode] = []

  /// Creates a semantics sort group.
  ///
  /// **Dart Source:** `semantics.dart:4023`
  /// **Original:** `_SemanticsSortGroup({required this.startOffset, required this.textDirection})`
  init(startOffset: Double, textDirection: TextDirection) {
    self.startOffset = startOffset
    self.textDirection = textDirection
  }

  /// **Dart Source:** `semantics.dart:4038-4040`
  /// **Original:** `int compareTo(_SemanticsSortGroup other) => startOffset.compareTo(other.startOffset);`
  static func < (lhs: SemanticsSortGroup, rhs: SemanticsSortGroup) -> Bool {
    lhs.startOffset < rhs.startOffset
  }

  static func == (lhs: SemanticsSortGroup, rhs: SemanticsSortGroup) -> Bool {
    lhs.startOffset == rhs.startOffset
  }

  // MARK: - sortedWithinVerticalGroup

  /// Sorts this group assuming that `nodes` belong to the same vertical group.
  ///
  /// This method breaks up this group into horizontal `SemanticsSortGroup`s
  /// then sorts them using `sortedWithinKnot`.
  ///
  /// **Dart Source:** `semantics.dart:4046-4093`
  /// **Original:** `List<SemanticsNode> sortedWithinVerticalGroup()`
  func sortedWithinVerticalGroup() -> [SemanticsNode] {
    var edges: [BoxEdge] = []
    for child in nodes {
      // Using a small delta to shrink child rects removes overlapping cases.
      let childRect = child.rect.deflate(0.1)
      edges.append(
        BoxEdge(
          isLeadingEdge: true,
          offset: pointInParentCoordinates(child, childRect.topLeft).dx,
          node: child
        )
      )
      edges.append(
        BoxEdge(
          isLeadingEdge: false,
          offset: pointInParentCoordinates(child, childRect.bottomRight).dx,
          node: child
        )
      )
    }
    edges.sort()

    var horizontalGroups: [SemanticsSortGroup] = []
    var group: SemanticsSortGroup?
    var depth = 0
    for edge in edges {
      if edge.isLeadingEdge {
        depth += 1
        if group == nil {
          group = SemanticsSortGroup(
            startOffset: edge.offset,
            textDirection: textDirection
          )
        }
        group!.nodes.append(edge.node)
      } else {
        depth -= 1
      }
      if depth == 0 {
        horizontalGroups.append(group!)
        group = nil
      }
    }
    horizontalGroups.sort()

    if textDirection == .rtl {
      horizontalGroups.reverse()
    }

    return horizontalGroups.flatMap { $0.sortedWithinKnot() }
  }

  // MARK: - sortedWithinKnot

  /// Sorts `nodes` where nodes intersect both vertically and horizontally.
  ///
  /// In the special case when `nodes` contains one or fewer nodes, this method
  /// returns `nodes` unchanged.
  ///
  /// This method constructs a graph, where vertices are `SemanticsNode`s and
  /// edges are "traversed before" relation between pairs of nodes. The sort
  /// order is the topological sorting of the graph, with the original order of
  /// `nodes` used as the tie breaker.
  ///
  /// Whether a node is traversed before another node is determined by the
  /// vector that connects the two nodes' centers. If the vector "points to the
  /// right or down", defined as the `Offset.direction` being between `-pi/4`
  /// and `3*pi/4`, then the semantics node whose center is at the end of the
  /// vector is said to be traversed after.
  ///
  /// **Dart Source:** `semantics.dart:4110-4170`
  /// **Original:** `List<SemanticsNode> sortedWithinKnot()`
  func sortedWithinKnot() -> [SemanticsNode] {
    if nodes.count <= 1 {
      // Trivial knot. Nothing to do.
      return nodes
    }

    var nodeMap: [Int: SemanticsNode] = [:]
    var edges: [Int: Int] = [:]
    for node in nodes {
      nodeMap[node.id] = node
      let center = pointInParentCoordinates(node, node.rect.center)
      for nextNode in nodes {
        if node === nextNode || edges[nextNode.id] == node.id {
          // Skip self or when we've already established that the next node
          // points to current node.
          continue
        }

        let nextCenter = pointInParentCoordinates(nextNode, nextNode.rect.center)
        let centerDelta = nextCenter - center
        // When centers coincide, direction is 0.0.
        let direction = centerDelta.direction
        let isLtrAndForward =
          textDirection == .ltr
          && -.pi / 4 < direction
          && direction < 3 * .pi / 4
        let isRtlAndForward =
          textDirection == .rtl
          && (direction < -3 * .pi / 4 || direction > 3 * .pi / 4)
        if isLtrAndForward || isRtlAndForward {
          edges[node.id] = nextNode.id
        }
      }
    }

    var sortedIds: [Int] = []
    var visitedIds: Set<Int> = []

    let startNodes = nodes.sorted { a, b in
      let aTopLeft = pointInParentCoordinates(a, a.rect.topLeft)
      let bTopLeft = pointInParentCoordinates(b, b.rect.topLeft)
      let verticalDiff = aTopLeft.dy < bTopLeft.dy ? -1 : (aTopLeft.dy > bTopLeft.dy ? 1 : 0)
      if verticalDiff != 0 {
        return -verticalDiff < 0
      }
      return -(aTopLeft.dx < bTopLeft.dx ? -1 : (aTopLeft.dx > bTopLeft.dx ? 1 : 0)) < 0
    }

    func search(_ id: Int) {
      if visitedIds.contains(id) {
        return
      }
      visitedIds.insert(id)
      if let nextId = edges[id] {
        search(nextId)
      }
      sortedIds.append(id)
    }

    for node in startNodes {
      search(node.id)
    }

    return sortedIds.reversed().compactMap { nodeMap[$0] }
  }
}

// MARK: - pointInParentCoordinates

/// Converts `point` to the `node`'s parent's coordinate system.
///
/// **Dart Source:** `semantics.dart:4174-4181`
/// **Original Name:** `_pointInParentCoordinates`
///
/// DIFFERENCE FROM DART: Uses `Matrix4` storage directly to replicate the
/// `transform3` behavior (affine transform without perspective division).
/// REASON: The Dart code uses `Vector3.transform3` which applies the 4x4
/// matrix without perspective division. This matches that behavior exactly.
func pointInParentCoordinates(_ node: SemanticsNode, _ point: Offset) -> Offset {
  guard let transform = node.transform else {
    return point
  }
  // Replicate Dart's Vector3.transform3 behavior:
  // Transforms (x, y, 0) by the matrix as if w=1, taking only x and y of the result.
  // This is equivalent to:
  //   final Vector3 vector = Vector3(point.dx, point.dy, 0.0);
  //   node.transform!.transform3(vector);
  //   return Offset(vector.x, vector.y);
  let s = transform.storage
  let x = point.dx
  let y = point.dy
  let rx = s[0] * x + s[4] * y + s[12]
  let ry = s[1] * x + s[5] * y + s[13]
  return Offset(rx, ry)
}

// MARK: - childrenInDefaultOrder

/// Sorts `children` using the default sorting algorithm, and returns them as a
/// new list.
///
/// The algorithm first breaks up children into groups such that no two nodes
/// from different groups overlap vertically. These groups are sorted vertically
/// according to their `SemanticsSortGroup.startOffset`.
///
/// Within each group, the nodes are sorted using
/// `SemanticsSortGroup.sortedWithinVerticalGroup`.
///
/// For an illustration of the algorithm see http://bit.ly/flutter-default-traversal.
///
/// **Dart Source:** `semantics.dart:4194-4241`
/// **Original Name:** `_childrenInDefaultOrder`
func childrenInDefaultOrder(
  _ children: [SemanticsNode],
  _ textDirection: TextDirection
) -> [SemanticsNode] {
  var edges: [BoxEdge] = []
  for child in children {
    assert(child.rect.isFinite)
    // Using a small delta to shrink child rects removes overlapping cases.
    let childRect = child.rect.deflate(0.1)
    edges.append(
      BoxEdge(
        isLeadingEdge: true,
        offset: pointInParentCoordinates(child, childRect.topLeft).dy,
        node: child
      )
    )
    edges.append(
      BoxEdge(
        isLeadingEdge: false,
        offset: pointInParentCoordinates(child, childRect.bottomRight).dy,
        node: child
      )
    )
  }
  edges.sort()

  var verticalGroups: [SemanticsSortGroup] = []
  var group: SemanticsSortGroup?
  var depth = 0
  for edge in edges {
    if edge.isLeadingEdge {
      depth += 1
      if group == nil {
        group = SemanticsSortGroup(
          startOffset: edge.offset,
          textDirection: textDirection
        )
      }
      group!.nodes.append(edge.node)
    } else {
      depth -= 1
    }
    if depth == 0 {
      verticalGroups.append(group!)
      group = nil
    }
  }
  verticalGroups.sort()

  return verticalGroups.flatMap { $0.sortedWithinVerticalGroup() }
}
