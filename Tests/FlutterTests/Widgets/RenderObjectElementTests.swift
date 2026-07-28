// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A concrete RenderObject with observable state for testing.
private class TestRenderObject: RenderObject {
    var updateCount = 0
    var didUnmountCount = 0
    var isDisposed = false

    override func dispose() {
        isDisposed = true
        super.dispose()
    }
}

/// A concrete LeafRenderObjectWidget that uses TestRenderObject with tracking.
private class TestLeafWidget: LeafRenderObjectWidget {
    var createCount = 0
    var updateCount = 0
    var didUnmountCount = 0
    var lastCreatedRenderObject: TestRenderObject?

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        createCount += 1
        let ro = TestRenderObject()
        lastCreatedRenderObject = ro
        return ro
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        updateCount += 1
        (renderObject as! TestRenderObject).updateCount += 1
    }

    override func didUnmountRenderObject(_ renderObject: RenderObject) {
        didUnmountCount += 1
        (renderObject as! TestRenderObject).didUnmountCount += 1
    }
}

/// A concrete SingleChildRenderObjectWidget for setting up parent elements.
private class ParentWidget: SingleChildRenderObjectWidget {
    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return TestRenderObject()
    }
}

/// A concrete widget for use as a plain Element placeholder (non-RenderObject).
private class PlaceholderWidget: Widget {
    override func createElement() -> Element {
        return Element(self)
    }
}

/// A tracking RenderObjectElement subclass that records
/// insertRenderObjectChild and removeRenderObjectChild calls.
private class TrackingRenderObjectElement: RenderObjectElement {
    var insertedChildren: [(child: RenderObject, slot: Any?)] = []
    var removedChildren: [(child: RenderObject, slot: Any?)] = []

    override func insertRenderObjectChild(_ child: RenderObject, _ slot: Any?) {
        insertedChildren.append((child: child, slot: slot))
    }

    override func removeRenderObjectChild(_ child: RenderObject, _ slot: Any?) {
        removedChildren.append((child: child, slot: slot))
    }
}

/// A RenderTreeRootElement concrete subclass for testing.
private class TestRenderTreeRootWidget: LeafRenderObjectWidget {
    override func createElement() -> Element {
        return TestConcreteRenderTreeRootElement(self)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return TestRenderObject()
    }
}

private class TestConcreteRenderTreeRootElement: RenderTreeRootElement {
    init(_ widget: TestRenderTreeRootWidget) {
        super.init(widget)
    }
}

/// Helper: creates a parent element with a BuildOwner, ready for mounting children.
private func makeParent() -> Element {
    let parentWidget = ParentWidget()
    let parent = parentWidget.createElement()
    parent.owner = BuildOwner()
    return parent
}

// MARK: - RenderObjectElement Mount Tests

@Suite("RenderObjectElement Mount")
struct RenderObjectElementMountTests {

    @Test("mount creates render object via widget's createRenderObject")
    func mountCreatesRenderObject() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()

        element.mount(parent, nil)

        #expect(element.renderObject != nil)
        #expect(widget.createCount == 1)
        #expect(element.renderObject is TestRenderObject)
    }

    @Test("mount sets lifecycle to active")
    func mountSetsLifecycleActive() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()

        #expect(element.mounted == false)
        element.mount(parent, nil)
        #expect(element.mounted == true)
    }

    @Test("mount clears dirty flag")
    func mountClearsDirtyFlag() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()

        #expect(element._dirty == true)
        element.mount(parent, nil)
        #expect(element._dirty == false)
    }

    @Test("mount sets parent reference and depth from parent")
    func mountSetsParentAndDepth() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        parent._lifecycleState = .active
        parent.depth = 3

        element.mount(parent, nil)

        #expect(element._parent === parent)
        #expect(element.depth == 4)
    }

    @Test("mount inherits owner from parent")
    func mountInheritsOwner() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let owner = BuildOwner()
        let parentWidget = ParentWidget()
        let parent = parentWidget.createElement()
        parent.owner = owner

        element.mount(parent, nil)

        #expect(element.owner === owner)
    }

    @Test("mount stores the slot via attachRenderObject")
    func mountStoresSlot() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()

        element.mount(parent, "test-slot" as AnyObject)

        #expect(element._slot as? String == "test-slot")
    }
}

// MARK: - RenderObjectElement Update Tests

@Suite("RenderObjectElement Update")
struct RenderObjectElementUpdateTests {

    @Test("update calls updateRenderObject on the widget")
    func updateCallsUpdateRenderObject() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        #expect(renderObject.updateCount == 0)

        let newWidget = TestLeafWidget()
        element.update(newWidget)

        #expect(renderObject.updateCount == 1)
        #expect(newWidget.updateCount == 1)
    }

    @Test("update sets the new widget on the element")
    func updateSetsNewWidget() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let newWidget = TestLeafWidget()
        element.update(newWidget)

        #expect(element.widget === newWidget)
    }

    @Test("update reuses the same render object instance")
    func updateReusesRenderObject() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)
        let originalRO = element.renderObject

        let newWidget = TestLeafWidget()
        element.update(newWidget)

        #expect(element.renderObject === originalRO)
    }
}

// MARK: - RenderObjectElement Rebuild Tests

@Suite("RenderObjectElement Rebuild")
struct RenderObjectElementRebuildTests {

    @Test("performRebuild calls updateRenderObject and clears dirty flag")
    func performRebuildCallsUpdateAndClearsDirty() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        #expect(renderObject.updateCount == 0)

        element._dirty = true
        element.performRebuild()

        #expect(renderObject.updateCount == 1)
        #expect(element._dirty == false)
    }

    @Test("rebuild skips when not dirty")
    func rebuildSkipsWhenNotDirty() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        // After mount, dirty is false
        #expect(element._dirty == false)

        element.rebuild()

        // updateRenderObject should not have been called
        #expect(renderObject.updateCount == 0)
    }

    @Test("rebuild calls performRebuild when dirty and active")
    func rebuildCallsPerformRebuildWhenDirty() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        element._dirty = true
        element.rebuild()

        #expect(renderObject.updateCount == 1)
        #expect(element._dirty == false)
    }
}

// MARK: - RenderObjectElement Unmount Tests

@Suite("RenderObjectElement Unmount")
struct RenderObjectElementUnmountTests {

    @Test("unmount calls didUnmountRenderObject on the widget")
    func unmountCallsDidUnmount() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        #expect(renderObject.didUnmountCount == 0)

        element.unmount()

        #expect(renderObject.didUnmountCount == 1)
        #expect(widget.didUnmountCount == 1)
    }

    @Test("unmount disposes the render object")
    func unmountDisposesRenderObject() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject
        #expect(renderObject.isDisposed == false)

        element.unmount()

        #expect(renderObject.isDisposed == true)
    }

    @Test("unmount sets renderObject to nil")
    func unmountSetsRenderObjectToNil() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        #expect(element.renderObject != nil)
        element.unmount()
        #expect(element.renderObject == nil)
    }

    @Test("unmount sets lifecycle state to defunct")
    func unmountSetsLifecycleDefunct() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        element.unmount()

        #expect(element._lifecycleState == .defunct)
    }
}

// MARK: - RenderObjectElement FindRenderObject Tests

@Suite("RenderObjectElement FindRenderObject")
struct RenderObjectElementFindRenderObjectTests {

    @Test("findRenderObject returns the element's render object after mount")
    func findRenderObjectReturnsRenderObject() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let found = element.findRenderObject()

        #expect(found === element.renderObject)
        #expect(found is TestRenderObject)
    }

    @Test("findRenderObject returns nil before mount")
    func findRenderObjectReturnsNilBeforeMount() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement

        #expect(element.findRenderObject() == nil)
    }
}

// MARK: - RenderObjectElement Attach/Detach Tests

@Suite("RenderObjectElement Attach Detach")
struct RenderObjectElementAttachDetachTests {

    @Test("attachRenderObject finds ancestor and calls insertRenderObjectChild")
    func attachFindsAncestorAndInserts() {
        let parentWidget = TestLeafWidget()
        let trackingParent = TrackingRenderObjectElement(parentWidget)
        trackingParent.owner = BuildOwner()
        trackingParent._lifecycleState = .active
        trackingParent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(trackingParent, nil)

        #expect(trackingParent.insertedChildren.count == 1)
        #expect(trackingParent.insertedChildren[0].child === child.renderObject)
    }

    @Test("attachRenderObject sets _ancestorRenderObjectElement")
    func attachSetsAncestor() {
        let parentWidget = TestLeafWidget()
        let trackingParent = TrackingRenderObjectElement(parentWidget)
        trackingParent.owner = BuildOwner()
        trackingParent._lifecycleState = .active
        trackingParent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(trackingParent, nil)

        #expect(child._ancestorRenderObjectElement === trackingParent)
    }

    @Test("detachRenderObject calls removeRenderObjectChild on ancestor")
    func detachCallsRemoveOnAncestor() {
        let parentWidget = TestLeafWidget()
        let trackingParent = TrackingRenderObjectElement(parentWidget)
        trackingParent.owner = BuildOwner()
        trackingParent._lifecycleState = .active
        trackingParent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(trackingParent, "slot-1" as AnyObject)

        child.detachRenderObject()

        #expect(trackingParent.removedChildren.count == 1)
        #expect(trackingParent.removedChildren[0].child === child.renderObject)
    }

    @Test("detachRenderObject clears slot and ancestor reference")
    func detachClearsSlotAndAncestor() {
        let parentWidget = TestLeafWidget()
        let trackingParent = TrackingRenderObjectElement(parentWidget)
        trackingParent.owner = BuildOwner()
        trackingParent._lifecycleState = .active
        trackingParent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(trackingParent, "slot-1" as AnyObject)

        child.detachRenderObject()

        #expect(child._slot == nil)
        #expect(child._ancestorRenderObjectElement == nil)
    }

    @Test("attachRenderObject through non-RenderObjectElement intermediary finds correct ancestor")
    func attachThroughIntermediary() {
        let grandparentWidget = TestLeafWidget()
        let grandparent = TrackingRenderObjectElement(grandparentWidget)
        grandparent.owner = BuildOwner()
        grandparent._lifecycleState = .active
        grandparent.renderObject = TestRenderObject()

        let middleWidget = PlaceholderWidget()
        let middle = Element(middleWidget)
        middle.mount(grandparent, nil)

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(middle, nil)

        #expect(grandparent.insertedChildren.count == 1)
        #expect(grandparent.insertedChildren[0].child === child.renderObject)
        #expect(child._ancestorRenderObjectElement === grandparent)
    }

    @Test("detach and re-attach preserves render object identity")
    func detachReattachPreservesRenderObject() {
        let parentWidget = TestLeafWidget()
        let parent = TrackingRenderObjectElement(parentWidget)
        parent.owner = BuildOwner()
        parent._lifecycleState = .active
        parent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(parent, nil)
        let renderObject = child.renderObject

        child.detachRenderObject()
        #expect(parent.removedChildren.count == 1)

        child.attachRenderObject("new-slot" as AnyObject)
        #expect(parent.insertedChildren.count == 2)
        #expect(child.renderObject === renderObject)
        #expect(child._slot as? String == "new-slot")
    }

    @Test("attachRenderObject with no RenderObjectElement ancestor does not crash")
    func attachWithNoAncestor() {
        let rootWidget = PlaceholderWidget()
        let root = Element(rootWidget)
        root.owner = BuildOwner()
        root._lifecycleState = .active

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(root, nil)

        #expect(child._ancestorRenderObjectElement == nil)
        #expect(child.renderObject != nil)
    }
}

// MARK: - _findAncestorRenderObjectElement Tests

@Suite("RenderObjectElement Ancestor Traversal")
struct RenderObjectElementAncestorTraversalTests {

    @Test("finds nearest RenderObjectElement ancestor")
    func findsNearestAncestor() {
        let grandparentWidget = TestLeafWidget()
        let grandparent = TrackingRenderObjectElement(grandparentWidget)
        grandparent.owner = BuildOwner()
        grandparent._lifecycleState = .active
        grandparent.renderObject = TestRenderObject()

        let middleWidget = PlaceholderWidget()
        let middle = Element(middleWidget)
        middle.mount(grandparent, nil)

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(middle, nil)

        let found = child._findAncestorRenderObjectElement()
        #expect(found === grandparent)
    }

    @Test("returns nil when no RenderObjectElement ancestor exists")
    func returnsNilWhenNoAncestor() {
        let rootWidget = PlaceholderWidget()
        let root = Element(rootWidget)
        root.owner = BuildOwner()
        root._lifecycleState = .active

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(root, nil)

        let found = child._findAncestorRenderObjectElement()
        #expect(found == nil)
    }

    @Test("finds immediate parent when parent is RenderObjectElement")
    func findsImmediateParent() {
        let parentWidget = TestLeafWidget()
        let parent = TrackingRenderObjectElement(parentWidget)
        parent.owner = BuildOwner()
        parent._lifecycleState = .active
        parent.renderObject = TestRenderObject()

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(parent, nil)

        let found = child._findAncestorRenderObjectElement()
        #expect(found === parent)
    }

    @Test("traverses multiple non-RenderObject layers to find ancestor")
    func traversesMultipleLayers() {
        let ancestorWidget = TestLeafWidget()
        let ancestor = TrackingRenderObjectElement(ancestorWidget)
        ancestor.owner = BuildOwner()
        ancestor._lifecycleState = .active
        ancestor.renderObject = TestRenderObject()

        let middle1Widget = PlaceholderWidget()
        let middle1 = Element(middle1Widget)
        middle1.mount(ancestor, nil)

        let middle2Widget = PlaceholderWidget()
        let middle2 = Element(middle2Widget)
        middle2.mount(middle1, nil)

        let middle3Widget = PlaceholderWidget()
        let middle3 = Element(middle3Widget)
        middle3.mount(middle2, nil)

        let childWidget = TestLeafWidget()
        let child = childWidget.createElement() as! LeafRenderObjectElement
        child.mount(middle3, nil)

        let found = child._findAncestorRenderObjectElement()
        #expect(found === ancestor)
    }
}

// MARK: - RenderObjectElement Debug Tests

@Suite("RenderObjectElement Debug")
struct RenderObjectElementDebugTests {

    @Test("debugDoingBuild reflects _debugDoingBuild state")
    func debugDoingBuildReflectsState() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! RenderObjectElement

        #expect(element.debugDoingBuild == false)
        element._debugDoingBuild = true
        #expect(element.debugDoingBuild == true)
        element._debugDoingBuild = false
        #expect(element.debugDoingBuild == false)
    }
}

// MARK: - RenderTreeRootElement Tests

@Suite("RenderTreeRootElement")
struct RenderTreeRootElementTests {

    @Test("attachRenderObject sets slot without ancestor insertion")
    func attachSetsSlotOnly() {
        let widget = TestRenderTreeRootWidget()
        let element = widget.createElement() as! TestConcreteRenderTreeRootElement
        element.owner = BuildOwner()
        element.renderObject = TestRenderObject()

        element.attachRenderObject("root-slot" as AnyObject)

        #expect(element._slot as? String == "root-slot")
        #expect(element._ancestorRenderObjectElement == nil)
    }

    @Test("detachRenderObject clears slot at root")
    func detachClearsSlot() {
        let widget = TestRenderTreeRootWidget()
        let element = widget.createElement() as! TestConcreteRenderTreeRootElement
        element.owner = BuildOwner()
        element._lifecycleState = .active
        element.renderObject = TestRenderObject()
        element._slot = "root-slot" as AnyObject

        element.detachRenderObject()

        #expect(element._slot == nil)
    }

    @Test("mount works with nil parent for root element")
    func mountWithNilParent() {
        let widget = TestRenderTreeRootWidget()
        let element = widget.createElement() as! TestConcreteRenderTreeRootElement
        element.owner = BuildOwner()

        element.mount(nil, "root-slot" as AnyObject)

        #expect(element.renderObject != nil)
        #expect(element._slot as? String == "root-slot")
    }
}

// MARK: - IndexedSlot Tests

@Suite("IndexedSlot")
struct IndexedSlotTests {

    @Test("stores value and index")
    func storesValueAndIndex() {
        let slot = IndexedSlot<String?>(value: "prev", index: 3)
        #expect(slot.value == "prev")
        #expect(slot.index == 3)
    }

    @Test("works with nil value")
    func nilValue() {
        let slot = IndexedSlot<String?>(value: nil, index: 0)
        #expect(slot.value == nil)
        #expect(slot.index == 0)
    }
}

// MARK: - Full Lifecycle Integration Tests

@Suite("RenderObjectElement Full Lifecycle")
struct RenderObjectElementFullLifecycleTests {

    @Test("complete lifecycle: mount, update, rebuild, unmount")
    func completeLifecycle() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()

        // 1. Mount
        element.mount(parent, nil)
        let renderObject = element.renderObject as! TestRenderObject
        #expect(element.mounted == true)
        #expect(widget.createCount == 1)
        #expect(renderObject.updateCount == 0)

        // 2. Update
        let newWidget = TestLeafWidget()
        element.update(newWidget)
        #expect(renderObject.updateCount == 1)
        #expect(element.widget === newWidget)

        // 3. performRebuild
        element._dirty = true
        element.performRebuild()
        #expect(renderObject.updateCount == 2)
        #expect(element._dirty == false)

        // 4. Unmount
        element.unmount()
        #expect(renderObject.didUnmountCount == 1)
        #expect(renderObject.isDisposed == true)
        #expect(element.renderObject == nil)
        #expect(element._lifecycleState == .defunct)
    }

    @Test("multiple updates accumulate on the same render object")
    func multipleUpdates() {
        let widget = TestLeafWidget()
        let element = widget.createElement() as! LeafRenderObjectElement
        let parent = makeParent()
        element.mount(parent, nil)

        let renderObject = element.renderObject as! TestRenderObject

        for i in 1...5 {
            let updatedWidget = TestLeafWidget()
            element.update(updatedWidget)
            #expect(renderObject.updateCount == i)
        }

        #expect(element.renderObject === renderObject)
    }
}
