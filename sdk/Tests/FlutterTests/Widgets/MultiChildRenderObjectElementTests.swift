// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A concrete LeafRenderObjectWidget used as a child in multi-child tests.
private class MCTestLeafWidget: LeafRenderObjectWidget {
    let id: String

    init(key: (any Key)? = nil, id: String = "") {
        self.id = id
        super.init(key: key)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A concrete MultiChildRenderObjectWidget for testing.
private class MCTestWidget: MultiChildRenderObjectWidget {
    override init(key: (any Key)? = nil, children: [Widget] = []) {
        super.init(key: key, children: children)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A root element that acts as the parent and provides a BuildOwner.
/// This allows mount/deactivate operations to work correctly.
private class MCTestRootElement: RenderObjectElement {
    init() {
        super.init(MCTestWidget())
    }

    func setupOwner() {
        let buildOwner = BuildOwner()
        self.owner = buildOwner
        self._lifecycleState = .active
        self.renderObject = (widget as! RenderObjectWidget).createRenderObject(self)
    }
}

// MARK: - Tests

@Suite("MultiChildRenderObjectElement - Detailed")
struct MultiChildRenderObjectElementDetailedTests {

    /// Creates a mounted MultiChildRenderObjectElement with the given widget,
    /// attached to a root element that has a BuildOwner.
    private func mountElement(_ widget: MultiChildRenderObjectWidget) -> MultiChildRenderObjectElement {
        let root = MCTestRootElement()
        root.setupOwner()
        let element = MultiChildRenderObjectElement(widget)
        element.mount(root, nil)
        return element
    }

    @Test("mount with empty children produces empty _children array")
    func mountEmptyChildren() {
        let widget = MCTestWidget(children: [])
        let element = mountElement(widget)

        #expect(element._children.isEmpty)
    }

    @Test("mount with multiple children inflates all children")
    func mountMultipleChildren() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let child3 = MCTestLeafWidget(id: "c")
        let widget = MCTestWidget(children: [child1, child2, child3])

        let element = mountElement(widget)

        #expect(element._children.count == 3)
        for child in element._children {
            #expect(child is LeafRenderObjectElement)
        }
    }

    @Test("mount assigns IndexedSlot with correct indices and previous children")
    func mountSlotsCorrect() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget)

        // First child slot: index 0, value nil
        let slot0 = element._children[0]._slot as? IndexedSlot<Element?>
        #expect(slot0 != nil)
        #expect(slot0?.index == 0)
        #expect(slot0?.value == nil)

        // Second child slot: index 1, value is first child element
        let slot1 = element._children[1]._slot as? IndexedSlot<Element?>
        #expect(slot1 != nil)
        #expect(slot1?.index == 1)
        #expect(slot1?.value === element._children[0])
    }

    @Test("mount sets children as active with correct parent")
    func mountChildrenActiveWithParent() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget)

        for child in element._children {
            #expect(child.mounted)
            #expect(child._parent === element)
        }
    }

    @Test("update diffs children via updateChildren")
    func updateDiffsChildren() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget1 = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget1)
        let originalChild0 = element._children[0]
        let originalChild1 = element._children[1]

        // Update with same-type widgets (canUpdate returns true because same type, no keys)
        let child1b = MCTestLeafWidget(id: "a2")
        let child2b = MCTestLeafWidget(id: "b2")
        let widget2 = MCTestWidget(children: [child1b, child2b])

        element.update(widget2)

        // Children should be reused (same type, no key)
        #expect(element._children.count == 2)
        #expect(element._children[0] === originalChild0)
        #expect(element._children[1] === originalChild1)
    }

    @Test("update adding children inflates new children")
    func updateAddingChildren() {
        let child1 = MCTestLeafWidget(id: "a")
        let widget1 = MCTestWidget(children: [child1])

        let element = mountElement(widget1)
        #expect(element._children.count == 1)

        // Update with two children
        let child1b = MCTestLeafWidget(id: "a")
        let child2b = MCTestLeafWidget(id: "b")
        let widget2 = MCTestWidget(children: [child1b, child2b])

        element.update(widget2)

        #expect(element._children.count == 2)
        #expect(element._children[1] is LeafRenderObjectElement)
    }

    @Test("update removing children deactivates old children")
    func updateRemovingChildren() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget1 = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget1)
        let removedChild = element._children[1]
        #expect(element._children.count == 2)

        // Update with only one child
        let child1b = MCTestLeafWidget(id: "a2")
        let widget2 = MCTestWidget(children: [child1b])

        element.update(widget2)

        #expect(element._children.count == 1)
        // The removed child should be deactivated (inactive)
        #expect(removedChild._lifecycleState == .inactive)
    }

    @Test("visitChildElements visits all non-forgotten children")
    func visitChildElementsVisitsAll() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let child3 = MCTestLeafWidget(id: "c")
        let widget = MCTestWidget(children: [child1, child2, child3])

        let element = mountElement(widget)

        var visited: [Element] = []
        element.visitChildElements { child in
            visited.append(child)
        }

        #expect(visited.count == 3)
        #expect(visited[0] === element._children[0])
        #expect(visited[1] === element._children[1])
        #expect(visited[2] === element._children[2])
    }

    @Test("visitChildElements skips forgotten children")
    func visitChildElementsSkipsForgotten() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let child3 = MCTestLeafWidget(id: "c")
        let widget = MCTestWidget(children: [child1, child2, child3])

        let element = mountElement(widget)

        // Forget the second child
        element.forgetChild(element._children[1])

        var visited: [Element] = []
        element.visitChildElements { child in
            visited.append(child)
        }

        // Should visit only child[0] and child[2], skipping the forgotten child[1]
        #expect(visited.count == 2)
        #expect(visited[0] === element._children[0])
        #expect(visited[1] === element._children[2])
    }

    @Test("forgetChild adds child to _forgottenChildren set")
    func forgetChildAddsToSet() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget)
        let childToForget = element._children[0]

        #expect(element._forgottenChildren.isEmpty)

        element.forgetChild(childToForget)

        #expect(element._forgottenChildren.contains(ObjectIdentifier(childToForget)))
        #expect(element._forgottenChildren.count == 1)
    }

    @Test("_forgottenChildren is cleared after update")
    func forgottenChildrenClearedAfterUpdate() {
        let child1 = MCTestLeafWidget(id: "a")
        let child2 = MCTestLeafWidget(id: "b")
        let widget1 = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget1)

        // Forget a child
        element.forgetChild(element._children[0])
        #expect(!element._forgottenChildren.isEmpty)

        // Update should clear forgotten children
        let child1b = MCTestLeafWidget(id: "a2")
        let child2b = MCTestLeafWidget(id: "b2")
        let widget2 = MCTestWidget(children: [child1b, child2b])

        element.update(widget2)

        #expect(element._forgottenChildren.isEmpty)
    }

    @Test("children with keys are reused across updates")
    func childrenWithKeysReused() {
        let key1 = ValueKey<String>("key1")
        let key2 = ValueKey<String>("key2")

        let child1 = MCTestLeafWidget(key: key1, id: "a")
        let child2 = MCTestLeafWidget(key: key2, id: "b")
        let widget1 = MCTestWidget(children: [child1, child2])

        let element = mountElement(widget1)
        let originalElement1 = element._children[0]
        let originalElement2 = element._children[1]

        // Update with children in reversed order, same keys
        let child2b = MCTestLeafWidget(key: key2, id: "b2")
        let child1b = MCTestLeafWidget(key: key1, id: "a2")
        let widget2 = MCTestWidget(children: [child2b, child1b])

        element.update(widget2)

        // Keyed children should be reused: element at position 0 now has key2's element,
        // and element at position 1 now has key1's element
        #expect(element._children.count == 2)
        #expect(element._children[0] === originalElement2)
        #expect(element._children[1] === originalElement1)
    }
}
