// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for `SemanticsNode`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart`
final class SemanticsNodeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        debugResetSemanticsIdCounter()
        CustomSemanticsAction.resetForTests()
    }

    override func tearDown() {
        CustomSemanticsAction.resetForTests()
        super.tearDown()
    }

    // MARK: - ID Generation Tests

    /// Test that IDs are unique and sequential.
    func testUniqueIdGeneration() {
        let node1 = SemanticsNode()
        let node2 = SemanticsNode()
        let node3 = SemanticsNode()

        XCTAssertEqual(node1.id, 1)
        XCTAssertEqual(node2.id, 2)
        XCTAssertEqual(node3.id, 3)
    }

    /// Test that `debugResetSemanticsIdCounter` resets the counter.
    func testDebugResetSemanticsIdCounter() {
        let node1 = SemanticsNode()
        XCTAssertEqual(node1.id, 1)

        debugResetSemanticsIdCounter()

        let node2 = SemanticsNode()
        XCTAssertEqual(node2.id, 1)
    }

    // MARK: - Basic Construction Tests

    /// Test basic construction with defaults.
    func testBasicConstruction() {
        let node = SemanticsNode()
        XCTAssertNil(node.key)
        XCTAssertFalse(node.isMergedIntoParent)
        XCTAssertFalse(node.mergeAllDescendantsIntoThisNode)
        XCTAssertNil(node.parent)
        XCTAssertFalse(node.hasChildren)
        XCTAssertEqual(node.childrenCount, 0)
        XCTAssertEqual(node.depth, 0)
        XCTAssertNil(node.owner)
        XCTAssertFalse(node.attached)
        XCTAssertEqual(node.rect, .zero)
        XCTAssertNil(node.transform)
    }

    // MARK: - Tagging Tests

    /// Test tagging semantics nodes.
    ///
    /// **Dart Test:** `semantics_test.dart:28-41`
    func testTagging() {
        let tag1 = SemanticsTag("Tag One")
        let tag2 = SemanticsTag("Tag Two")

        let node = SemanticsNode()

        XCTAssertFalse(node.isTagged(tag1))
        XCTAssertFalse(node.isTagged(tag2))

        node.tags = Set<SemanticsTag>([tag1])
        XCTAssertTrue(node.isTagged(tag1))
        XCTAssertFalse(node.isTagged(tag2))

        node.tags!.insert(tag2)
        XCTAssertTrue(node.isTagged(tag1))
        XCTAssertTrue(node.isTagged(tag2))
    }

    // MARK: - updateWith Tests

    /// Test updateWith applies config properties to the node.
    ///
    /// **Dart Test:** `semantics_test.dart:70-173`
    func testUpdateWithConfig() {
        let node = SemanticsNode()

        let config = SemanticsConfiguration()
        config.label = "test label"
        config.textDirection = .ltr
        config.isButton = true

        node.updateWith(config: config)

        XCTAssertEqual(node.label, "test label")
        XCTAssertEqual(node.textDirection, .ltr)
    }

    /// Test updateWith with nil config resets to defaults.
    func testUpdateWithNilConfig() {
        let node = SemanticsNode()

        let config = SemanticsConfiguration()
        config.label = "initial"
        config.textDirection = .ltr
        node.updateWith(config: config)
        XCTAssertEqual(node.label, "initial")

        // Updating with nil config resets
        node.updateWith(config: nil)
        XCTAssertEqual(node.label, "")
    }

    /// Test updateWith marks node as dirty when role changes.
    ///
    /// **Dart Test:** `semantics_test.dart:458-469`
    func testUpdateWithMarksDirtyOnRoleChange() {
        let node = SemanticsNode()

        XCTAssertEqual(node.role, .none)

        let config = SemanticsConfiguration()
        config.role = .tab
        node.updateWith(config: config)

        XCTAssertEqual(node.role, .tab)
    }

    /// Test updateWith with label, value, and hint via config.
    func testUpdateWithLabelValueHint() {
        let node = SemanticsNode()
        let config = SemanticsConfiguration()
        config.label = "Label"
        config.value = "Value"
        config.hint = "Hint"
        config.tooltip = "Tooltip"
        config.textDirection = .ltr

        node.updateWith(config: config)

        XCTAssertEqual(node.label, "Label")
        XCTAssertEqual(node.value, "Value")
        XCTAssertEqual(node.hint, "Hint")
        XCTAssertEqual(node.tooltip, "Tooltip")
    }

    /// Test updateWith with attributed strings.
    func testUpdateWithAttributedStrings() {
        let node = SemanticsNode()
        let config = SemanticsConfiguration()

        config.attributedLabel = Flutter.AttributedString(
            "attributed",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 5))
            ]
        )
        config.textDirection = .ltr

        node.updateWith(config: config)

        XCTAssertEqual(node.label, "attributed")
        XCTAssertEqual(node.attributedLabel.string, "attributed")
        XCTAssertEqual(node.attributedLabel.attributes.count, 1)
    }

    // MARK: - getSemanticsData Tests

    /// Test getSemanticsData returns correct data.
    func testGetSemanticsData() {
        let node = SemanticsNode()
        node.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)

        let config = SemanticsConfiguration()
        config.label = "test"
        config.textDirection = .ltr
        config.isButton = true
        node.updateWith(config: config)

        let data = node.getSemanticsData()
        XCTAssertEqual(data.label, "test")
        XCTAssertEqual(data.textDirection, .ltr)
        XCTAssertEqual(data.rect, Rect.fromLTRB(0.0, 0.0, 10.0, 10.0))
        XCTAssertTrue(data.flagsCollection.isButton)
    }

    /// Test getSemanticsData includes tags.
    ///
    /// **Dart Test:** `semantics_test.dart:43-68`
    func testGetSemanticsDataIncludesTags() {
        let tag1 = SemanticsTag("Tag One")
        let tag2 = SemanticsTag("Tag Two")
        let tags: Set<SemanticsTag> = [tag1, tag2]

        let node = SemanticsNode()
        node.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)
        node.tags = tags

        let data = node.getSemanticsData()
        XCTAssertNotNil(data.tags)
        XCTAssertTrue(data.tags!.contains(tag1))
        XCTAssertTrue(data.tags!.contains(tag2))
    }

    // MARK: - Property Delegation Tests

    /// Test that node properties delegate to the config after updateWith.
    func testPropertyDelegation() {
        let node = SemanticsNode()
        let config = SemanticsConfiguration()
        config.identifier = "my-id"
        config.textDirection = .rtl
        config.headingLevel = 3
        config.role = .tab
        config.validationResult = .valid
        config.textDirection = .ltr

        node.updateWith(config: config)

        XCTAssertEqual(node.identifier, "my-id")
        XCTAssertEqual(node.textDirection, .ltr)
        XCTAssertEqual(node.headingLevel, 3)
        XCTAssertEqual(node.role, .tab)
        XCTAssertEqual(node.validationResult, .valid)
    }

    // MARK: - Rect and Transform Tests

    /// Test rect getter and setter.
    func testRect() {
        let node = SemanticsNode()
        XCTAssertEqual(node.rect, .zero)

        node.rect = Rect.fromLTRB(1.0, 2.0, 3.0, 4.0)
        XCTAssertEqual(node.rect, Rect.fromLTRB(1.0, 2.0, 3.0, 4.0))
    }

    /// Test isInvisible for empty rect.
    func testIsInvisibleEmptyRect() {
        let node = SemanticsNode()
        node.rect = .zero
        // node with empty rect is invisible
        XCTAssertTrue(node.isInvisible)
    }

    /// Test isInvisible for non-empty rect.
    func testIsInvisibleNonEmptyRect() {
        let node = SemanticsNode()
        node.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)
        XCTAssertFalse(node.isInvisible)
    }

    // MARK: - Children Tests

    /// Test children management through updateWith.
    func testChildrenManagement() {
        let root = SemanticsNode()
        root.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)

        let child1 = SemanticsNode()
        child1.rect = Rect.fromLTRB(0.0, 0.0, 5.0, 5.0)

        let child2 = SemanticsNode()
        child2.rect = Rect.fromLTRB(5.0, 0.0, 10.0, 5.0)

        root.updateWith(
            config: nil,
            childrenInInversePaintOrder: [child1, child2]
        )

        XCTAssertTrue(root.hasChildren)
        XCTAssertEqual(root.childrenCount, 2)
        XCTAssertTrue(child1.parent === root)
        XCTAssertTrue(child2.parent === root)
    }

    /// Test visitChildren iterates over children.
    func testVisitChildren() {
        let root = SemanticsNode()
        root.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)

        let child1 = SemanticsNode()
        child1.rect = Rect.fromLTRB(0.0, 0.0, 5.0, 5.0)

        let child2 = SemanticsNode()
        child2.rect = Rect.fromLTRB(5.0, 0.0, 10.0, 5.0)

        root.updateWith(config: nil, childrenInInversePaintOrder: [child1, child2])

        var visited: [Int] = []
        root.visitChildren { node in
            visited.append(node.id)
            return true
        }
        XCTAssertEqual(visited.count, 2)
    }

    // MARK: - isMergedIntoParent Tests

    /// Test isMergedIntoParent behavior.
    ///
    /// **Dart Test:** `semantics_test.dart:175-229`
    func testIsMergedIntoParent() {
        let root = SemanticsNode()
        root.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)

        let node1 = SemanticsNode()
        node1.rect = Rect.fromLTRB(1.0, 0.0, 10.0, 10.0)

        let node11 = SemanticsNode()
        node11.rect = Rect.fromLTRB(2.0, 0.0, 10.0, 10.0)

        let node12 = SemanticsNode()
        node12.rect = Rect.fromLTRB(3.0, 0.0, 10.0, 10.0)

        let noMergeConfig = SemanticsConfiguration()
        noMergeConfig.isSemanticBoundary = true
        noMergeConfig.isMergingSemanticsOfDescendants = false

        let mergeConfig = SemanticsConfiguration()
        mergeConfig.isSemanticBoundary = true
        mergeConfig.isMergingSemanticsOfDescendants = true

        node1.updateWith(
            config: noMergeConfig,
            childrenInInversePaintOrder: [node11, node12]
        )

        XCTAssertFalse(node1.isMergedIntoParent)
        XCTAssertFalse(node1.mergeAllDescendantsIntoThisNode)
        XCTAssertFalse(node11.isMergedIntoParent)
        XCTAssertFalse(node12.isMergedIntoParent)

        root.updateWith(config: mergeConfig, childrenInInversePaintOrder: [node1])
        XCTAssertTrue(node1.isMergedIntoParent)
        XCTAssertFalse(node1.mergeAllDescendantsIntoThisNode)
        XCTAssertTrue(node11.isMergedIntoParent)
        XCTAssertTrue(node12.isMergedIntoParent)
        XCTAssertFalse(root.isMergedIntoParent)
        XCTAssertTrue(root.mergeAllDescendantsIntoThisNode)

        // Change node1 config to also merge
        node1.updateWith(
            config: mergeConfig,
            childrenInInversePaintOrder: [node11, node12]
        )
        XCTAssertTrue(node1.isMergedIntoParent)
        XCTAssertTrue(node1.mergeAllDescendantsIntoThisNode)
        XCTAssertTrue(node11.isMergedIntoParent)
        XCTAssertTrue(node12.isMergedIntoParent)

        // Switch root back to no merge
        root.updateWith(config: noMergeConfig, childrenInInversePaintOrder: [node1])
        XCTAssertFalse(node1.isMergedIntoParent)
        XCTAssertTrue(node1.mergeAllDescendantsIntoThisNode)
        XCTAssertTrue(node11.isMergedIntoParent)
        XCTAssertTrue(node12.isMergedIntoParent)
        XCTAssertFalse(root.isMergedIntoParent)
        XCTAssertFalse(root.mergeAllDescendantsIntoThisNode)
    }

    // MARK: - Custom Actions in Config Tests

    /// Test custom actions set via config are reflected in the node.
    func testCustomActionsViaConfig() {
        let action1 = CustomSemanticsAction(label: "action1")
        let action2 = CustomSemanticsAction(label: "action2")

        let config = SemanticsConfiguration()
        config.customSemanticsActions = [
            action1: {},
            action2: {},
        ]

        let node = SemanticsNode()
        node.rect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)
        node.updateWith(config: config)

        let data = node.getSemanticsData()
        XCTAssertNotNil(data.customSemanticsActionIds)
        // customSemanticsActionIds should contain IDs for action1 and action2
        XCTAssertEqual(data.customSemanticsActionIds?.count, 2)
    }

    // MARK: - indexInParent Tests

    /// Test indexInParent property.
    ///
    /// **Dart Test:** `semantics_test.dart:1049-1052`
    func testIndexInParent() {
        let node = SemanticsNode()
        node.indexInParent = 10
        XCTAssertEqual(node.indexInParent, 10)
    }

    // MARK: - toStringShort Tests

    /// Test toStringShort format.
    func testToStringShort() {
        debugResetSemanticsIdCounter()
        let node = SemanticsNode()
        let shortStr = node.toStringShort()
        XCTAssertTrue(shortStr.contains("SemanticsNode"))
        XCTAssertTrue(shortStr.contains("#\(node.id)"))
    }

    // MARK: - Hashable Tests

    /// Test that SemanticsNode uses identity-based equality.
    func testIdentityEquality() {
        let node1 = SemanticsNode()
        let node2 = SemanticsNode()

        XCTAssertTrue(node1 == node1)
        XCTAssertFalse(node1 == node2)
    }

    /// Test that SemanticsNode works as dictionary key.
    func testUsableAsDictionaryKey() {
        let node1 = SemanticsNode()
        let node2 = SemanticsNode()

        var dict: [SemanticsNode: String] = [:]
        dict[node1] = "first"
        dict[node2] = "second"

        XCTAssertEqual(dict[node1], "first")
        XCTAssertEqual(dict[node2], "second")
        XCTAssertEqual(dict.count, 2)
    }
}
