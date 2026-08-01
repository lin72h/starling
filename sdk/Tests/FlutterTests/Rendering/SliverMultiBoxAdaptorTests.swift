// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for SliverMultiBoxAdaptor types from the Rendering layer.
///
/// **Swift Source:** `Sources/Flutter/Rendering/SliverMultiBoxAdaptor.swift`
///
/// These tests cover:
///   - RenderSliverBoxChildManager protocol and default implementations
///   - SliverMultiBoxAdaptorParentData (init, properties, keepAlive, description)
///   - KeepAliveParentDataMixin conformance
///   - RenderSliverMultiBoxAdaptor (construction, child management, keep-alive bucket,
///     garbage collection, indexOf, visitChildren, debug)

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// Creates a standard SliverConstraints for testing.
private func makeSliverConstraints(
    axisDirection: AxisDirection = .down,
    growthDirection: GrowthDirection = .forward,
    scrollOffset: Double = 0.0,
    remainingPaintExtent: Double = 600.0,
    crossAxisExtent: Double = 400.0,
    viewportMainAxisExtent: Double = 600.0
) -> SliverConstraints {
    SliverConstraints(
        axisDirection: axisDirection,
        growthDirection: growthDirection,
        userScrollDirection: .idle,
        scrollOffset: scrollOffset,
        precedingScrollExtent: 0.0,
        overlap: 0.0,
        remainingPaintExtent: remainingPaintExtent,
        crossAxisExtent: crossAxisExtent,
        crossAxisDirection: .right,
        viewportMainAxisExtent: viewportMainAxisExtent,
        remainingCacheExtent: 850.0,
        cacheOrigin: 0.0
    )
}

/// A concrete RenderBox subclass with configurable size.
private class TestRenderBox: RenderBox {
    var fixedWidth: Double
    var fixedHeight: Double

    init(width: Double = 100.0, height: Double = 50.0) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

/// A mock implementation of RenderSliverBoxChildManager for testing.
private class MockChildManager: RenderSliverBoxChildManager {
    var adaptor: RenderSliverMultiBoxAdaptor?
    var createdChildren: [Int: TestRenderBox] = [:]
    var removedChildren: [RenderBox] = []
    var didUnderflowValue: Bool = false
    var startLayoutCalled = false
    var finishLayoutCalled = false
    var adoptedChildren: [RenderBox] = []
    var _childCount: Int = 10

    var childCount: Int { _childCount }
    var estimatedChildCount: Int? { _childCount }

    func createChild(_ index: Int, after: RenderBox?) {
        guard index >= 0 && index < _childCount else { return }
        let child = TestRenderBox()
        createdChildren[index] = child
        // Pre-set parentData with index before insert so _debugVerifyChildOrder
        // can safely call indexOf.
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = index
        child.parentData = pd
        adaptor?.insert(child, after: after)
    }

    func removeChild(_ child: RenderBox) {
        removedChildren.append(child)
        adaptor?.remove(child)
    }

    func estimateMaxScrollOffset(
        _ constraints: SliverConstraints,
        firstIndex: Int?,
        lastIndex: Int?,
        leadingScrollOffset: Double?,
        trailingScrollOffset: Double?
    ) -> Double {
        return Double(_childCount) * 50.0
    }

    func didAdoptChild(_ child: RenderBox) {
        adoptedChildren.append(child)
    }

    func setDidUnderflow(_ value: Bool) {
        didUnderflowValue = value
    }

    func didStartLayout() {
        startLayoutCalled = true
    }

    func didFinishLayout() {
        finishLayoutCalled = true
    }

    func debugAssertChildListLocked() -> Bool { true }
}

/// Creates a RenderSliverMultiBoxAdaptor and its MockChildManager, with
/// sliver constraints pre-applied so layout callbacks can execute.
private func makeAdaptorWithManager() -> (RenderSliverMultiBoxAdaptor, MockChildManager) {
    let manager = MockChildManager()
    let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
    manager.adaptor = adaptor
    // Apply constraints so sliverConstraints is available
    let constraints = makeSliverConstraints()
    adaptor.layout(constraints)
    return (adaptor, manager)
}

/// Helper to insert a child with a given index into the adaptor.
/// Sets parentData with index BEFORE insert() so that _debugVerifyChildOrder()
/// (called inside insert) can safely call indexOf() without asserting on nil.
private func insertChildWithIndex(
    _ adaptor: RenderSliverMultiBoxAdaptor,
    index: Int,
    after: RenderBox? = nil,
    width: Double = 100.0,
    height: Double = 50.0
) -> TestRenderBox {
    let child = TestRenderBox(width: width, height: height)
    // Pre-set parentData with index so setupParentData inside insert()
    // preserves it (it checks `is SliverMultiBoxAdaptorParentData`).
    let pd = SliverMultiBoxAdaptorParentData()
    pd.index = index
    child.parentData = pd
    adaptor.insert(child, after: after)
    return child
}

// =============================================================================
// MARK: - RenderSliverBoxChildManager Protocol Tests
// =============================================================================

@Suite("RenderSliverBoxChildManager Protocol Tests")
struct RenderSliverBoxChildManagerTests {

    @Test("Default estimatedChildCount returns nil")
    func testDefaultEstimatedChildCount() {
        // The protocol extension provides a default nil for estimatedChildCount.
        // MockChildManager overrides it, so we test a minimal conformance instead.
        class MinimalManager: RenderSliverBoxChildManager {
            func createChild(_ index: Int, after: RenderBox?) {}
            func removeChild(_ child: RenderBox) {}
            func estimateMaxScrollOffset(
                _ constraints: SliverConstraints,
                firstIndex: Int?, lastIndex: Int?,
                leadingScrollOffset: Double?, trailingScrollOffset: Double?
            ) -> Double { 0 }
            var childCount: Int { 0 }
            func didAdoptChild(_ child: RenderBox) {}
            func setDidUnderflow(_ value: Bool) {}
        }
        let m = MinimalManager()
        #expect(m.estimatedChildCount == nil)
    }

    @Test("Default debugAssertChildListLocked returns true")
    func testDefaultDebugAssertChildListLocked() {
        class MinimalManager: RenderSliverBoxChildManager {
            func createChild(_ index: Int, after: RenderBox?) {}
            func removeChild(_ child: RenderBox) {}
            func estimateMaxScrollOffset(
                _ constraints: SliverConstraints,
                firstIndex: Int?, lastIndex: Int?,
                leadingScrollOffset: Double?, trailingScrollOffset: Double?
            ) -> Double { 0 }
            var childCount: Int { 0 }
            func didAdoptChild(_ child: RenderBox) {}
            func setDidUnderflow(_ value: Bool) {}
        }
        let m = MinimalManager()
        #expect(m.debugAssertChildListLocked() == true)
    }

    @Test("Default didStartLayout does nothing")
    func testDefaultDidStartLayout() {
        class MinimalManager: RenderSliverBoxChildManager {
            func createChild(_ index: Int, after: RenderBox?) {}
            func removeChild(_ child: RenderBox) {}
            func estimateMaxScrollOffset(
                _ constraints: SliverConstraints,
                firstIndex: Int?, lastIndex: Int?,
                leadingScrollOffset: Double?, trailingScrollOffset: Double?
            ) -> Double { 0 }
            var childCount: Int { 0 }
            func didAdoptChild(_ child: RenderBox) {}
            func setDidUnderflow(_ value: Bool) {}
        }
        let m = MinimalManager()
        // Should not crash
        m.didStartLayout()
    }

    @Test("Default didFinishLayout does nothing")
    func testDefaultDidFinishLayout() {
        class MinimalManager: RenderSliverBoxChildManager {
            func createChild(_ index: Int, after: RenderBox?) {}
            func removeChild(_ child: RenderBox) {}
            func estimateMaxScrollOffset(
                _ constraints: SliverConstraints,
                firstIndex: Int?, lastIndex: Int?,
                leadingScrollOffset: Double?, trailingScrollOffset: Double?
            ) -> Double { 0 }
            var childCount: Int { 0 }
            func didAdoptChild(_ child: RenderBox) {}
            func setDidUnderflow(_ value: Bool) {}
        }
        let m = MinimalManager()
        // Should not crash
        m.didFinishLayout()
    }

    @Test("Mock manager tracks createChild calls")
    func testMockManagerCreateChild() {
        let (adaptor, manager) = makeAdaptorWithManager()
        manager.createChild(0, after: nil)
        #expect(manager.createdChildren.count == 1)
        #expect(adaptor.firstChild != nil)
    }

    @Test("Mock manager tracks removeChild calls")
    func testMockManagerRemoveChild() {
        let (adaptor, manager) = makeAdaptorWithManager()
        let child = insertChildWithIndex(adaptor, index: 0)
        manager.removeChild(child)
        #expect(manager.removedChildren.count == 1)
    }

    @Test("Mock manager childCount returns configured value")
    func testMockManagerChildCount() {
        let manager = MockChildManager()
        #expect(manager.childCount == 10)
        manager._childCount = 5
        #expect(manager.childCount == 5)
    }
}

// =============================================================================
// MARK: - SliverMultiBoxAdaptorParentData Tests
// =============================================================================

@Suite("SliverMultiBoxAdaptorParentData Tests")
struct SliverMultiBoxAdaptorParentDataTests {

    @Test("Default values after init")
    func testDefaultValues() {
        let pd = SliverMultiBoxAdaptorParentData()
        #expect(pd.index == nil)
        #expect(pd.keepAlive == false)
        #expect(pd.keptAlive == false)
        #expect(pd.previousSibling == nil)
        #expect(pd.nextSibling == nil)
    }

    @Test("Index can be set")
    func testIndexSetting() {
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = 5
        #expect(pd.index == 5)
    }

    @Test("Index can be set to nil")
    func testIndexSetNil() {
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = 3
        pd.index = nil
        #expect(pd.index == nil)
    }

    @Test("keepAlive can be toggled")
    func testKeepAliveToggle() {
        let pd = SliverMultiBoxAdaptorParentData()
        #expect(pd.keepAlive == false)
        pd.keepAlive = true
        #expect(pd.keepAlive == true)
        pd.keepAlive = false
        #expect(pd.keepAlive == false)
    }

    @Test("keptAlive reflects internal state")
    func testKeptAliveReflectsInternalState() {
        let pd = SliverMultiBoxAdaptorParentData()
        #expect(pd.keptAlive == false)
        pd._keptAlive = true
        #expect(pd.keptAlive == true)
    }

    @Test("Sibling references can be set")
    func testSiblingReferences() {
        let pd = SliverMultiBoxAdaptorParentData()
        let box1 = TestRenderBox()
        let box2 = TestRenderBox()
        pd.previousSibling = box1
        pd.nextSibling = box2
        #expect(pd.previousSibling === box1)
        #expect(pd.nextSibling === box2)
    }

    @Test("Description includes index")
    func testDescriptionWithIndex() {
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = 3
        let desc = pd.description
        #expect(desc.contains("index=3"))
    }

    @Test("Description includes keepAlive when true")
    func testDescriptionWithKeepAlive() {
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = 1
        pd.keepAlive = true
        let desc = pd.description
        #expect(desc.contains("keepAlive"))
    }

    @Test("Description shows nil index")
    func testDescriptionWithNilIndex() {
        let pd = SliverMultiBoxAdaptorParentData()
        let desc = pd.description
        #expect(desc.contains("index=nil"))
    }

    @Test("Conforms to KeepAliveParentDataMixin")
    func testKeepAliveParentDataMixinConformance() {
        let pd: KeepAliveParentDataMixin = SliverMultiBoxAdaptorParentData()
        pd.keepAlive = true
        #expect(pd.keepAlive == true)
        #expect(pd.keptAlive == false) // _keptAlive defaults to false
    }

    @Test("Conforms to ContainerParentDataProtocol")
    func testContainerParentDataProtocolConformance() {
        let pd: any ContainerParentDataProtocol = SliverMultiBoxAdaptorParentData()
        // Just verifying conformance compiles
        #expect(pd is SliverMultiBoxAdaptorParentData)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Construction Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Construction Tests")
struct RenderSliverMultiBoxAdaptorConstructionTests {

    @Test("Initial state has no children")
    func testInitialStateEmpty() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        #expect(adaptor.firstChild == nil)
        #expect(adaptor.lastChild == nil)
        #expect(adaptor.childCount == 0)
    }

    @Test("childManager returns the provided manager")
    func testChildManagerProperty() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        #expect(adaptor.childManager === manager)
    }

    @Test("debugChildIntegrityEnabled defaults to true")
    func testDebugChildIntegrityDefault() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        #expect(adaptor.debugChildIntegrityEnabled == true)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Child Management Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Child Management Tests")
struct RenderSliverMultiBoxAdaptorChildManagementTests {

    @Test("Insert single child")
    func testInsertSingleChild() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child = insertChildWithIndex(adaptor, index: 0)
        #expect(adaptor.firstChild === child)
        #expect(adaptor.lastChild === child)
        #expect(adaptor.childCount == 1)
    }

    @Test("Insert multiple children")
    func testInsertMultipleChildren() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        let child2 = insertChildWithIndex(adaptor, index: 2, after: child1)
        #expect(adaptor.firstChild === child0)
        #expect(adaptor.lastChild === child2)
        #expect(adaptor.childCount == 3)
    }

    @Test("childAfter returns correct sibling")
    func testChildAfter() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        #expect(adaptor.childAfter(child0) === child1)
        #expect(adaptor.childAfter(child1) == nil)
    }

    @Test("childBefore returns correct sibling")
    func testChildBefore() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        #expect(adaptor.childBefore(child0) == nil)
        #expect(adaptor.childBefore(child1) === child0)
    }

    @Test("Insert at beginning when after is nil")
    func testInsertAtBeginning() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child1 = insertChildWithIndex(adaptor, index: 1)
        let child0 = insertChildWithIndex(adaptor, index: 0) // after: nil inserts at front
        #expect(adaptor.firstChild === child0)
        #expect(adaptor.lastChild === child1)
        #expect(adaptor.childAfter(child0) === child1)
    }

    @Test("Remove single child from middle")
    func testRemoveMiddleChild() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        let child2 = insertChildWithIndex(adaptor, index: 2, after: child1)
        adaptor.remove(child1)
        #expect(adaptor.childCount == 2)
        #expect(adaptor.childAfter(child0) === child2)
    }

    @Test("Remove first child")
    func testRemoveFirstChild() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        adaptor.remove(child0)
        #expect(adaptor.firstChild === child1)
        #expect(adaptor.childCount == 1)
    }

    @Test("Remove last child")
    func testRemoveLastChild() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        adaptor.remove(child1)
        #expect(adaptor.lastChild === child0)
        #expect(adaptor.childCount == 1)
    }

    @Test("removeAll removes all children")
    func testRemoveAll() {
        let (adaptor, _) = makeAdaptorWithManager()
        _ = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: adaptor.lastChild)
        _ = insertChildWithIndex(adaptor, index: 2, after: adaptor.lastChild)
        adaptor.removeAll()
        #expect(adaptor.firstChild == nil)
        #expect(adaptor.lastChild == nil)
        #expect(adaptor.childCount == 0)
    }

    @Test("removeAll on empty adaptor does not crash")
    func testRemoveAllEmpty() {
        let (adaptor, _) = makeAdaptorWithManager()
        adaptor.removeAll()
        #expect(adaptor.childCount == 0)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor indexOf Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor indexOf Tests")
struct RenderSliverMultiBoxAdaptorIndexOfTests {

    @Test("indexOf returns correct index")
    func testIndexOf() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child = insertChildWithIndex(adaptor, index: 5)
        #expect(adaptor.indexOf(child) == 5)
    }

    @Test("indexOf returns correct index for multiple children")
    func testIndexOfMultiple() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child3 = insertChildWithIndex(adaptor, index: 3, after: child0)
        let child7 = insertChildWithIndex(adaptor, index: 7, after: child3)
        #expect(adaptor.indexOf(child0) == 0)
        #expect(adaptor.indexOf(child3) == 3)
        #expect(adaptor.indexOf(child7) == 7)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor setupParentData Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor setupParentData Tests")
struct RenderSliverMultiBoxAdaptorSetupParentDataTests {

    @Test("setupParentData creates SliverMultiBoxAdaptorParentData")
    func testSetupParentData() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        let child = TestRenderBox()
        adaptor.setupParentData(child)
        #expect(child.parentData is SliverMultiBoxAdaptorParentData)
    }

    @Test("setupParentData does not replace existing correct type")
    func testSetupParentDataExisting() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        let child = TestRenderBox()
        let existingPD = SliverMultiBoxAdaptorParentData()
        existingPD.index = 42
        child.parentData = existingPD
        adaptor.setupParentData(child)
        let pd = child.parentData as! SliverMultiBoxAdaptorParentData
        #expect(pd.index == 42) // Same instance retained
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor visitChildren Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor visitChildren Tests")
struct RenderSliverMultiBoxAdaptorVisitChildrenTests {

    @Test("visitChildren visits all children in order")
    func testVisitChildrenInOrder() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        let child2 = insertChildWithIndex(adaptor, index: 2, after: child1)

        var visited: [RenderObject] = []
        adaptor.visitChildren { visited.append($0) }
        #expect(visited.count == 3)
        #expect(visited[0] === child0)
        #expect(visited[1] === child1)
        #expect(visited[2] === child2)
    }

    @Test("visitChildren on empty adaptor visits nothing")
    func testVisitChildrenEmpty() {
        let (adaptor, _) = makeAdaptorWithManager()
        var visited: [RenderObject] = []
        adaptor.visitChildren { visited.append($0) }
        #expect(visited.isEmpty)
    }

    @Test("visitChildrenForSemantics visits only visible children")
    func testVisitChildrenForSemantics() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)

        var visited: [RenderObject] = []
        adaptor.visitChildrenForSemantics { visited.append($0) }
        #expect(visited.count == 2)
        #expect(visited[0] === child0)
        #expect(visited[1] === child1)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Garbage Collection Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Garbage Collection Tests")
struct RenderSliverMultiBoxAdaptorGarbageCollectionTests {

    @Test("calculateLeadingGarbage with no leading garbage")
    func testCalculateLeadingGarbageNone() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: child0)
        #expect(adaptor.calculateLeadingGarbage(firstIndex: 0) == 0)
    }

    @Test("calculateLeadingGarbage with some leading garbage")
    func testCalculateLeadingGarbageSome() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        _ = insertChildWithIndex(adaptor, index: 2, after: child1)
        #expect(adaptor.calculateLeadingGarbage(firstIndex: 2) == 2)
    }

    @Test("calculateTrailingGarbage with no trailing garbage")
    func testCalculateTrailingGarbageNone() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: child0)
        #expect(adaptor.calculateTrailingGarbage(lastIndex: 1) == 0)
    }

    @Test("calculateTrailingGarbage with some trailing garbage")
    func testCalculateTrailingGarbageSome() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        _ = insertChildWithIndex(adaptor, index: 2, after: child1)
        #expect(adaptor.calculateTrailingGarbage(lastIndex: 0) == 2)
    }

    @Test("collectGarbage with zero garbage does not remove children")
    func testCollectGarbageZero() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: child0)
        adaptor.collectGarbage(0, 0)
        #expect(adaptor.childCount == 2)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Attach/Detach Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Attach/Detach Tests")
struct RenderSliverMultiBoxAdaptorAttachDetachTests {

    @Test("Attach propagates to pipeline owner")
    func testAttach() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        let owner = PipelineOwner()
        adaptor.attach(owner)
        #expect(adaptor._owner === owner)
    }

    @Test("Detach clears owner")
    func testDetach() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        let owner = PipelineOwner()
        adaptor.attach(owner)
        adaptor.detach()
        #expect(adaptor._owner == nil)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor addInitialChild Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor addInitialChild Tests")
struct RenderSliverMultiBoxAdaptorAddInitialChildTests {

    @Test("addInitialChild creates child at index 0")
    func testAddInitialChildDefaultIndex() {
        let (adaptor, manager) = makeAdaptorWithManager()
        let result = adaptor.addInitialChild()
        #expect(result == true)
        #expect(adaptor.firstChild != nil)
        #expect(adaptor.indexOf(adaptor.firstChild!) == 0)
        #expect(manager.didUnderflowValue == false)
    }

    @Test("addInitialChild with custom index")
    func testAddInitialChildCustomIndex() {
        let (adaptor, _) = makeAdaptorWithManager()
        let result = adaptor.addInitialChild(index: 3, layoutOffset: 150.0)
        #expect(result == true)
        #expect(adaptor.indexOf(adaptor.firstChild!) == 3)
        let pd = adaptor.firstChild!.parentData as! SliverMultiBoxAdaptorParentData
        #expect(pd.layoutOffset == 150.0)
    }

    @Test("addInitialChild returns false when no child created")
    func testAddInitialChildNoChild() {
        let (adaptor, manager) = makeAdaptorWithManager()
        manager._childCount = 0 // No children available
        let result = adaptor.addInitialChild(index: 0)
        #expect(result == false)
        #expect(manager.didUnderflowValue == true)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor childScrollOffset Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor childScrollOffset Tests")
struct RenderSliverMultiBoxAdaptorChildScrollOffsetTests {

    @Test("childScrollOffset returns layout offset")
    func testChildScrollOffset() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child = insertChildWithIndex(adaptor, index: 0)
        let pd = child.parentData as! SliverMultiBoxAdaptorParentData
        pd.layoutOffset = 100.0
        #expect(adaptor.childScrollOffset(child) == 100.0)
    }

    @Test("childMainAxisPosition accounts for scroll offset")
    func testChildMainAxisPosition() {
        let constraints = makeSliverConstraints(scrollOffset: 50.0)
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        manager.adaptor = adaptor
        adaptor.layout(constraints)

        let child = insertChildWithIndex(adaptor, index: 0)
        let pd = child.parentData as! SliverMultiBoxAdaptorParentData
        pd.layoutOffset = 100.0

        let position = adaptor.childMainAxisPosition(child)
        #expect(position == 50.0) // 100 - 50
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor paintsChild Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor paintsChild Tests")
struct RenderSliverMultiBoxAdaptorPaintsChildTests {

    @Test("paintsChild returns true for visible child with index")
    func testPaintsChildVisible() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child = insertChildWithIndex(adaptor, index: 0)
        #expect(adaptor.paintsChild(child) == true)
    }

    @Test("paintsChild returns false when index is nil")
    func testPaintsChildNilIndex() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child = TestRenderBox()
        adaptor.setupParentData(child)
        // parentData exists but index is nil
        #expect(adaptor.paintsChild(child) == false)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Debug Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Debug Tests")
struct RenderSliverMultiBoxAdaptorDebugTests {

    @Test("debugAssertChildListIsNonEmptyAndContiguous returns true for contiguous list")
    func testDebugAssertContiguousList() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        _ = insertChildWithIndex(adaptor, index: 2, after: child1)
        #expect(adaptor.debugAssertChildListIsNonEmptyAndContiguous() == true)
    }

    @Test("debugDescribeChildren returns children descriptions")
    func testDebugDescribeChildren() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: child0)
        let descriptions = adaptor.debugDescribeChildren()
        #expect(descriptions.count == 2)
    }

    @Test("debugDescribeChildren returns empty array for empty adaptor")
    func testDebugDescribeChildrenEmpty() {
        let (adaptor, _) = makeAdaptorWithManager()
        let descriptions = adaptor.debugDescribeChildren()
        #expect(descriptions.isEmpty)
    }

    @Test("debugFillProperties includes children info")
    func testDebugFillProperties() {
        let (adaptor, _) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        _ = insertChildWithIndex(adaptor, index: 1, after: child0)
        let builder = DiagnosticPropertiesBuilder()
        adaptor.debugFillProperties(builder)
        #expect(builder.properties.count > 0)
    }

    @Test("debugFillProperties when no children")
    func testDebugFillPropertiesEmpty() {
        let (adaptor, _) = makeAdaptorWithManager()
        let builder = DiagnosticPropertiesBuilder()
        adaptor.debugFillProperties(builder)
        #expect(builder.properties.count > 0)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Move Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Move Tests")
struct RenderSliverMultiBoxAdaptorMoveTests {

    @Test("Move child within child list reorders children")
    func testMoveChild() {
        let (adaptor, manager) = makeAdaptorWithManager()
        let child0 = insertChildWithIndex(adaptor, index: 0)
        let child1 = insertChildWithIndex(adaptor, index: 1, after: child0)
        let child2 = insertChildWithIndex(adaptor, index: 2, after: child1)

        // Move child0 after child2 (it will be re-adopted and re-indexed by didAdoptChild)
        adaptor.move(child0, after: child2)
        #expect(adaptor.lastChild === child0)
        #expect(manager.adoptedChildren.count > 0)
    }
}

// =============================================================================
// MARK: - RenderSliverMultiBoxAdaptor Semantic Bounds Tests
// =============================================================================

@Suite("RenderSliverMultiBoxAdaptor Semantic Bounds Tests")
struct RenderSliverMultiBoxAdaptorSemanticBoundsTests {

    @Test("semanticBounds returns valid rect when geometry is set")
    func testSemanticBoundsWithGeometry() {
        let (adaptor, _) = makeAdaptorWithManager()
        // Set geometry so paintBounds can compute without crashing
        adaptor.geometry = SliverGeometry(
            scrollExtent: 500.0,
            paintExtent: 300.0,
            maxPaintExtent: 500.0
        )
        let bounds = adaptor.semanticBounds
        #expect(bounds.width >= 0)
        #expect(bounds.height >= 0)
    }
}

// =============================================================================
// MARK: - KeepAliveParentDataMixin Tests
// =============================================================================

@Suite("KeepAliveParentDataMixin Tests")
struct KeepAliveParentDataMixinTests {

    @Test("Protocol requires keepAlive and keptAlive")
    func testProtocolRequirements() {
        let pd = SliverMultiBoxAdaptorParentData()
        var mixin: KeepAliveParentDataMixin = pd
        mixin.keepAlive = true
        #expect(mixin.keepAlive == true)
        #expect(mixin.keptAlive == false) // keptAlive is independent
    }
}

// =============================================================================
// MARK: - RenderSliverWithKeepAliveMixin Tests
// =============================================================================

@Suite("RenderSliverWithKeepAliveMixin Tests")
struct RenderSliverWithKeepAliveMixinTests {

    @Test("RenderSliverMultiBoxAdaptor conforms to RenderSliverWithKeepAliveMixin")
    func testConformance() {
        let manager = MockChildManager()
        let adaptor = RenderSliverMultiBoxAdaptor(childManager: manager)
        // Verify protocol conformance
        let mixin: RenderSliverWithKeepAliveMixin = adaptor
        let child = TestRenderBox()
        mixin.setupParentData(child)
        #expect(child.parentData is SliverMultiBoxAdaptorParentData)
    }
}
