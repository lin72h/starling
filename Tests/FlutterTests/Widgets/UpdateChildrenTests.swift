// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A concrete MultiChildRenderObjectWidget for testing updateChildren.
/// Tracks an `id` property for identity verification and supports keys.
private class TestMultiChildWidget: MultiChildRenderObjectWidget {
    let id: String

    init(id: String, key: (any Key)? = nil, children: [Widget] = []) {
        self.id = id
        super.init(key: key, children: children)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A simple leaf widget for use as children in updateChildren tests.
/// Two TestWidgets with the same `id` have the same Swift type,
/// so `Widget.canUpdate` returns true (same type, same key).
private class TestWidget: Widget {
    let id: String

    init(id: String, key: (any Key)? = nil) {
        self.id = id
        super.init(key: key)
    }

    override func createElement() -> Element {
        return TestElement(self)
    }
}

/// A different widget type so canUpdate returns false against TestWidget.
private class OtherWidget: Widget {
    let id: String

    init(id: String, key: (any Key)? = nil) {
        self.id = id
        super.init(key: key)
    }

    override func createElement() -> Element {
        return TestElement(self)
    }
}

/// A simple Element subclass for TestWidget / OtherWidget.
private class TestElement: Element {
    override init(_ widget: Widget) {
        super.init(widget)
    }
}

/// Creates a mounted parent MultiChildRenderObjectElement with a BuildOwner,
/// then inflates the given child widgets as its children, returning the parent
/// element and its children array.
private func makeParentWithChildren(_ childWidgets: [Widget]) -> (MultiChildRenderObjectElement, [Element]) {
    let parentWidget = TestMultiChildWidget(id: "parent", children: childWidgets)
    let parentElement = MultiChildRenderObjectElement(parentWidget)

    // Create a root element to own the BuildOwner
    let rootWidget = TestMultiChildWidget(id: "root")
    let rootElement = MultiChildRenderObjectElement(rootWidget)
    let buildOwner = BuildOwner()
    rootElement.owner = buildOwner
    rootElement._lifecycleState = .active
    rootElement.depth = 0

    // Mount the parent under the root
    parentElement.mount(rootElement, nil)

    return (parentElement, parentElement._children)
}

// MARK: - UpdateChildren Tests

@Suite("UpdateChildren")
struct UpdateChildrenTests {

    // MARK: - 1. Empty old list -> new widgets creates all fresh

    @Test("Empty old children with new widgets creates fresh elements")
    func emptyOldToNewWidgets() {
        let (parent, _) = makeParentWithChildren([])

        let newWidgets: [Widget] = [
            TestWidget(id: "a"),
            TestWidget(id: "b"),
            TestWidget(id: "c"),
        ]

        let result = parent.updateChildren([], newWidgets)

        #expect(result.count == 3)
        for (i, element) in result.enumerated() {
            #expect(element.widget is TestWidget)
            #expect((element.widget as! TestWidget).id == ["a", "b", "c"][i])
            #expect(element.mounted)
        }
    }

    // MARK: - 2. Empty new list -> deactivates all old children

    @Test("Non-empty old children with empty new widgets deactivates all")
    func nonEmptyOldToEmptyNew() {
        let childWidgets: [Widget] = [
            TestWidget(id: "a"),
            TestWidget(id: "b"),
        ]
        let (parent, oldChildren) = makeParentWithChildren(childWidgets)

        #expect(oldChildren.count == 2)
        let elemA = oldChildren[0]
        let elemB = oldChildren[1]
        #expect(elemA.mounted)
        #expect(elemB.mounted)

        let result = parent.updateChildren(oldChildren, [])

        #expect(result.isEmpty)
        // Deactivated elements are no longer active
        #expect(!elemA.mounted)
        #expect(!elemB.mounted)
    }

    // MARK: - 3. Same widgets, same order -> reuses all elements

    @Test("Same widgets in same order reuses all elements")
    func sameWidgetsSameOrder() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let w3 = TestWidget(id: "c")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        #expect(oldChildren.count == 3)
        let elem0 = oldChildren[0]
        let elem1 = oldChildren[1]
        let elem2 = oldChildren[2]

        // Pass the exact same widget instances
        let result = parent.updateChildren(oldChildren, [w1, w2, w3])

        #expect(result.count == 3)
        // Elements should be reused (same identity)
        #expect(result[0] === elem0)
        #expect(result[1] === elem1)
        #expect(result[2] === elem2)
    }

    // MARK: - 4. Same widgets, different order (keyed) -> reuses with reorder

    @Test("Keyed widgets reordered reuses elements")
    func keyedReorder() {
        let keyA = ValueKey<String>("a")
        let keyB = ValueKey<String>("b")
        let keyC = ValueKey<String>("c")

        let w1 = TestWidget(id: "a", key: keyA)
        let w2 = TestWidget(id: "b", key: keyB)
        let w3 = TestWidget(id: "c", key: keyC)
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]
        let elemC = oldChildren[2]

        // Reorder: C, A, B
        let newW1 = TestWidget(id: "c2", key: keyC)
        let newW2 = TestWidget(id: "a2", key: keyA)
        let newW3 = TestWidget(id: "b2", key: keyB)

        let result = parent.updateChildren(oldChildren, [newW1, newW2, newW3])

        #expect(result.count == 3)
        // Elements should be reused based on key matching
        #expect(result[0] === elemC)
        #expect(result[1] === elemA)
        #expect(result[2] === elemB)
    }

    // MARK: - 5. Insert at beginning / middle / end

    @Test("Insert widget at beginning")
    func insertAtBeginning() {
        let w1 = TestWidget(id: "a", key: ValueKey<String>("a"))
        let w2 = TestWidget(id: "b", key: ValueKey<String>("b"))
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]

        let newW0 = TestWidget(id: "z", key: ValueKey<String>("z"))
        let result = parent.updateChildren(oldChildren, [newW0, w1, w2])

        #expect(result.count == 3)
        // New element at the beginning
        #expect(result[0] !== elemA)
        #expect(result[0] !== elemB)
        #expect((result[0].widget as! TestWidget).id == "z")
        // Original elements reused
        #expect(result[1] === elemA)
        #expect(result[2] === elemB)
    }

    @Test("Insert widget in middle")
    func insertInMiddle() {
        let w1 = TestWidget(id: "a", key: ValueKey<String>("a"))
        let w2 = TestWidget(id: "c", key: ValueKey<String>("c"))
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemC = oldChildren[1]

        let newMid = TestWidget(id: "b", key: ValueKey<String>("b"))
        let result = parent.updateChildren(oldChildren, [w1, newMid, w2])

        #expect(result.count == 3)
        #expect(result[0] === elemA)
        #expect((result[1].widget as! TestWidget).id == "b")
        #expect(result[1] !== elemA)
        #expect(result[1] !== elemC)
        #expect(result[2] === elemC)
    }

    @Test("Insert widget at end")
    func insertAtEnd() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]

        let newEnd = TestWidget(id: "c")
        let result = parent.updateChildren(oldChildren, [w1, w2, newEnd])

        #expect(result.count == 3)
        #expect(result[0] === elemA)
        #expect(result[1] === elemB)
        #expect((result[2].widget as! TestWidget).id == "c")
    }

    // MARK: - 6. Remove from beginning / middle / end

    @Test("Remove widget from beginning")
    func removeFromBeginning() {
        let w1 = TestWidget(id: "a", key: ValueKey<String>("a"))
        let w2 = TestWidget(id: "b", key: ValueKey<String>("b"))
        let w3 = TestWidget(id: "c", key: ValueKey<String>("c"))
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemB = oldChildren[1]
        let elemC = oldChildren[2]

        let result = parent.updateChildren(oldChildren, [w2, w3])

        #expect(result.count == 2)
        #expect(result[0] === elemB)
        #expect(result[1] === elemC)
    }

    @Test("Remove widget from middle")
    func removeFromMiddle() {
        let w1 = TestWidget(id: "a", key: ValueKey<String>("a"))
        let w2 = TestWidget(id: "b", key: ValueKey<String>("b"))
        let w3 = TestWidget(id: "c", key: ValueKey<String>("c"))
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemA = oldChildren[0]
        let elemC = oldChildren[2]

        let result = parent.updateChildren(oldChildren, [w1, w3])

        #expect(result.count == 2)
        #expect(result[0] === elemA)
        #expect(result[1] === elemC)
    }

    @Test("Remove widget from end")
    func removeFromEnd() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let w3 = TestWidget(id: "c")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]
        let elemC = oldChildren[2]

        let result = parent.updateChildren(oldChildren, [w1, w2])

        #expect(result.count == 2)
        #expect(result[0] === elemA)
        #expect(result[1] === elemB)
        #expect(!elemC.mounted)
    }

    // MARK: - 7. Replace widget (same type, canUpdate=true) -> updates element

    @Test("Replace with same-type widget updates existing element")
    func replaceWithSameType() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]

        // New widgets of same type (TestWidget) -> canUpdate = true
        let newW1 = TestWidget(id: "a-updated")
        let newW2 = TestWidget(id: "b-updated")
        let result = parent.updateChildren(oldChildren, [newW1, newW2])

        #expect(result.count == 2)
        // Elements are reused (same identity) but updated with new widgets
        #expect(result[0] === elemA)
        #expect(result[1] === elemB)
        #expect((result[0].widget as! TestWidget).id == "a-updated")
        #expect((result[1].widget as! TestWidget).id == "b-updated")
    }

    // MARK: - 8. Replace widget (different type) -> deactivates old, inflates new

    @Test("Replace with different-type widget creates new element")
    func replaceWithDifferentType() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]

        // Replace first with OtherWidget (different type) -> canUpdate = false
        let newW1 = OtherWidget(id: "x")
        let newW2 = TestWidget(id: "b-updated")
        let result = parent.updateChildren(oldChildren, [newW1, newW2])

        #expect(result.count == 2)
        // First element is new (different type)
        #expect(result[0] !== elemA)
        #expect(result[0].widget is OtherWidget)
        #expect((result[0].widget as! OtherWidget).id == "x")
        #expect(!elemA.mounted)
        // Second element is reused
        #expect(result[1] === elemB)
    }

    // MARK: - 9. Mix of keyed and non-keyed children

    @Test("Mix of keyed and non-keyed children")
    func mixedKeyedAndNonKeyed() {
        let w1 = TestWidget(id: "a")  // no key
        let w2 = TestWidget(id: "b", key: ValueKey<String>("b"))  // keyed
        let w3 = TestWidget(id: "c")  // no key
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemB = oldChildren[1]

        // Swap order, remove w1, add new non-keyed at end
        let newW1 = TestWidget(id: "b2", key: ValueKey<String>("b"))
        let newW2 = TestWidget(id: "d")
        let result = parent.updateChildren(oldChildren, [newW1, newW2])

        #expect(result.count == 2)
        // Keyed element b should be reused
        #expect(result[0] === elemB)
        #expect((result[0].widget as! TestWidget).id == "b2")
        // Second is a new non-keyed element
        #expect(result[1].widget is TestWidget)
        #expect((result[1].widget as! TestWidget).id == "d")
    }

    // MARK: - 10. Keyed children reordered across boundaries

    @Test("Keyed children reordered across top and bottom boundaries")
    func keyedReorderAcrossBoundaries() {
        let keyA = ValueKey<String>("a")
        let keyB = ValueKey<String>("b")
        let keyC = ValueKey<String>("c")
        let keyD = ValueKey<String>("d")

        let w1 = TestWidget(id: "a", key: keyA)
        let w2 = TestWidget(id: "b", key: keyB)
        let w3 = TestWidget(id: "c", key: keyC)
        let w4 = TestWidget(id: "d", key: keyD)
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3, w4])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]
        let elemC = oldChildren[2]
        let elemD = oldChildren[3]

        // Reverse order: D, C, B, A
        let result = parent.updateChildren(oldChildren, [
            TestWidget(id: "d2", key: keyD),
            TestWidget(id: "c2", key: keyC),
            TestWidget(id: "b2", key: keyB),
            TestWidget(id: "a2", key: keyA),
        ])

        #expect(result.count == 4)
        #expect(result[0] === elemD)
        #expect(result[1] === elemC)
        #expect(result[2] === elemB)
        #expect(result[3] === elemA)
    }

    // MARK: - 11. forgottenChildren are treated as null (deactivated/skipped)

    @Test("Forgotten children are skipped during update")
    func forgottenChildrenSkipped() {
        let w1 = TestWidget(id: "a")
        let w2 = TestWidget(id: "b")
        let w3 = TestWidget(id: "c")
        let (parent, oldChildren) = makeParentWithChildren([w1, w2, w3])

        let elemB = oldChildren[1]

        // Mark the middle child as forgotten
        let forgotten: Set<ObjectIdentifier> = [ObjectIdentifier(elemB)]

        // Provide two new widgets of the same type
        let newW1 = TestWidget(id: "a2")
        let newW2 = TestWidget(id: "c2")
        let result = parent.updateChildren(oldChildren, [newW1, newW2], forgottenChildren: forgotten)

        #expect(result.count == 2)
        // First old child is reused (same type, canUpdate = true)
        #expect(result[0] === oldChildren[0])
        #expect((result[0].widget as! TestWidget).id == "a2")
        // The forgotten child (elemB) is skipped; third old child matches second new widget
        #expect(result[1] === oldChildren[2])
        #expect((result[1].widget as! TestWidget).id == "c2")
    }

    // MARK: - 12. Stress: large list with scattered changes

    @Test("Large list with scattered insertions, removals, and reordering")
    func stressLargeList() {
        // Create 20 keyed widgets
        let oldWidgets: [Widget] = (0..<20).map { i in
            TestWidget(id: "w\(i)", key: ValueKey<Int>(i))
        }
        let (parent, oldChildren) = makeParentWithChildren(oldWidgets)

        #expect(oldChildren.count == 20)

        // Build new list:
        // - Remove indices 3, 7, 15
        // - Reverse order of 10..14
        // - Add 3 new widgets at index 5
        var newWidgets: [Widget] = []
        let removedIndices: Set<Int> = [3, 7, 15]
        for i in 0..<20 {
            if removedIndices.contains(i) { continue }
            if i == 5 {
                // Insert 3 new keyed widgets
                newWidgets.append(TestWidget(id: "new-a", key: ValueKey<Int>(100)))
                newWidgets.append(TestWidget(id: "new-b", key: ValueKey<Int>(101)))
                newWidgets.append(TestWidget(id: "new-c", key: ValueKey<Int>(102)))
            }
            newWidgets.append(TestWidget(id: "w\(i)-upd", key: ValueKey<Int>(i)))
        }

        let result = parent.updateChildren(oldChildren, newWidgets)

        #expect(result.count == newWidgets.count)

        // Verify all old keyed elements that should be reused are reused
        for element in result {
            let widget = element.widget as! TestWidget
            if widget.id.hasPrefix("new-") {
                // New widgets should have newly created elements
                #expect(element.mounted)
            } else {
                // Old widgets should be reused - extract key index
                let keyVal = (widget.key as! ValueKey<Int>).value
                #expect(element === oldChildren[keyVal])
            }
        }

        // Verify removed elements are deactivated
        for i in removedIndices {
            #expect(!oldChildren[i].mounted)
        }
    }

    // MARK: - Additional edge cases

    @Test("Single element list, same widget")
    func singleElementSameWidget() {
        let w = TestWidget(id: "only")
        let (parent, oldChildren) = makeParentWithChildren([w])

        let result = parent.updateChildren(oldChildren, [w])

        #expect(result.count == 1)
        #expect(result[0] === oldChildren[0])
    }

    @Test("Single element list, replace with different type")
    func singleElementDifferentType() {
        let w = TestWidget(id: "only")
        let (parent, oldChildren) = makeParentWithChildren([w])

        let oldElem = oldChildren[0]
        let newW = OtherWidget(id: "replacement")
        let result = parent.updateChildren(oldChildren, [newW])

        #expect(result.count == 1)
        #expect(result[0] !== oldElem)
        #expect(result[0].widget is OtherWidget)
        #expect(!oldElem.mounted)
    }

    @Test("Both old and new lists empty returns empty")
    func bothEmpty() {
        let (parent, _) = makeParentWithChildren([])
        let result = parent.updateChildren([], [])
        #expect(result.isEmpty)
    }

    @Test("Keyed widget with type change deactivates old even though key matches")
    func keyedTypeMismatch() {
        let key = ValueKey<String>("shared")
        let w1 = TestWidget(id: "a", key: key)
        let (parent, oldChildren) = makeParentWithChildren([w1])

        let oldElem = oldChildren[0]

        // Same key but different widget type -> canUpdate false
        let newW = OtherWidget(id: "b", key: key)
        let result = parent.updateChildren(oldChildren, [newW])

        #expect(result.count == 1)
        #expect(result[0] !== oldElem)
        #expect(result[0].widget is OtherWidget)
        #expect(!oldElem.mounted)
    }

    @Test("Grow list from 1 to many")
    func growListFromOne() {
        let w = TestWidget(id: "a")
        let (parent, oldChildren) = makeParentWithChildren([w])

        let elemA = oldChildren[0]
        let result = parent.updateChildren(oldChildren, [
            w,
            TestWidget(id: "b"),
            TestWidget(id: "c"),
            TestWidget(id: "d"),
        ])

        #expect(result.count == 4)
        #expect(result[0] === elemA)
        for i in 1..<4 {
            #expect(result[i].mounted)
            #expect(result[i] !== elemA)
        }
    }

    @Test("Shrink list from many to 1")
    func shrinkListFromMany() {
        let widgets: [Widget] = [
            TestWidget(id: "a"),
            TestWidget(id: "b"),
            TestWidget(id: "c"),
            TestWidget(id: "d"),
        ]
        let (parent, oldChildren) = makeParentWithChildren(widgets)

        let elemA = oldChildren[0]
        let result = parent.updateChildren(oldChildren, [widgets[0]])

        #expect(result.count == 1)
        #expect(result[0] === elemA)
        // Other elements deactivated
        for i in 1..<4 {
            #expect(!oldChildren[i].mounted)
        }
    }

    @Test("Swap two keyed elements")
    func swapTwoKeyed() {
        let keyA = ValueKey<String>("a")
        let keyB = ValueKey<String>("b")
        let w1 = TestWidget(id: "a", key: keyA)
        let w2 = TestWidget(id: "b", key: keyB)
        let (parent, oldChildren) = makeParentWithChildren([w1, w2])

        let elemA = oldChildren[0]
        let elemB = oldChildren[1]

        // Swap
        let result = parent.updateChildren(oldChildren, [
            TestWidget(id: "b2", key: keyB),
            TestWidget(id: "a2", key: keyA),
        ])

        #expect(result.count == 2)
        #expect(result[0] === elemB)
        #expect(result[1] === elemA)
        #expect((result[0].widget as! TestWidget).id == "b2")
        #expect((result[1].widget as! TestWidget).id == "a2")
    }
}
