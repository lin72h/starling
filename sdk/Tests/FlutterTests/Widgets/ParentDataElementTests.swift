// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

/// Tests for ParentDataElement.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:6174`

// MARK: - Test Helpers

/// A concrete ParentData subclass with observable state.
private class TestParentData: ParentData {
    var value: Int = 0
}

/// A concrete ParentDataWidget that records calls to applyParentData.
private class TestParentDataWidget: ParentDataWidget<TestParentData> {
    var appliedRenderObjects: [RenderObject] = []
    let dataValue: Int

    init(child: Widget, dataValue: Int = 42) {
        self.dataValue = dataValue
        super.init(child: child)
    }

    override func applyParentData(_ renderObject: RenderObject) {
        appliedRenderObjects.append(renderObject)
    }
}

/// A leaf RenderObjectWidget that creates a simple RenderObject.
private class TestLeafRenderObjectWidget: LeafRenderObjectWidget {
    let renderObj: RenderObject

    init(renderObject: RenderObject) {
        self.renderObj = renderObject
        super.init()
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return renderObj
    }
}

/// A simple widget that creates a plain Element (non-RenderObject).
/// Used as a ComponentElement intermediary.
private class SimpleStatelessWidget: StatelessWidget {
    let childWidget: Widget

    init(child: Widget) {
        self.childWidget = child
        super.init()
    }

    override func build(_ context: any BuildContext) -> Widget {
        return childWidget
    }
}

/// A helper to create a root element with a BuildOwner, mounting the given
/// widget tree properly.
private func mountTree(_ widget: Widget) -> Element {
    let owner = BuildOwner()
    // Create a root RenderObjectWidget to host the tree.
    let rootWidget = TestRootWidget(child: widget)
    let rootElement = TestRootElement(rootWidget)
    rootElement.owner = owner
    rootElement._lifecycleState = .active
    // Attach a BuildScope so markNeedsBuild works.
    rootElement.mount(nil, nil)
    return rootElement
}

/// Root widget to host a tree.
private class TestRootWidget: SingleChildRenderObjectWidget {
    init(child: Widget) {
        super.init(child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// Root element.
private class TestRootElement: SingleChildRenderObjectElement {
    init(_ widget: TestRootWidget) {
        super.init(widget)
    }

    override func mount(_ parent: Element?, _ newSlot: Any?) {
        // Custom mount: set owner first if no parent.
        if parent == nil {
            _lifecycleState = .active
        }
        super.mount(parent, newSlot)
    }
}

// MARK: - Tests

@Suite("ParentDataElement")
struct ParentDataElementTests {

    @Test("ParentDataElement is a ProxyElement")
    func isProxyElement() {
        let leafWidget = TestLeafRenderObjectWidget(renderObject: RenderObject())
        let widget = TestParentDataWidget(child: leafWidget)
        let element = widget.createElement()
        #expect(element is ProxyElement)
        #expect(element is ParentDataElement<TestParentData>)
        #expect(element is ComponentElement)
    }

    @Test("createElement returns a ParentDataElement")
    func createElementReturnsParentDataElement() {
        let leafWidget = TestLeafRenderObjectWidget(renderObject: RenderObject())
        let widget = TestParentDataWidget(child: leafWidget)
        let element = widget.createElement()
        #expect(element is ParentDataElement<TestParentData>)
    }

    @Test("applyWidgetOutOfTurn applies parent data to direct RenderObjectElement child")
    func applyWidgetOutOfTurnDirectChild() {
        let renderObj = RenderObject()
        let leafWidget = TestLeafRenderObjectWidget(renderObject: renderObj)
        let pdWidget = TestParentDataWidget(child: leafWidget, dataValue: 10)

        // Mount the tree via a root element.
        let owner = BuildOwner()
        let rootWidget = TestRootWidget(child: pdWidget)
        let rootElement = rootWidget.createElement()
        rootElement.owner = owner
        rootElement._lifecycleState = .active
        rootElement.mount(nil, nil)

        // Find the ParentDataElement in the tree.
        var parentDataElement: ParentDataElement<TestParentData>?
        rootElement.visitChildElements { child in
            if let pde = child as? ParentDataElement<TestParentData> {
                parentDataElement = pde
            }
        }

        #expect(parentDataElement != nil)

        // Create a new widget with the same child to call applyWidgetOutOfTurn.
        let newPDWidget = TestParentDataWidget(child: leafWidget, dataValue: 20)
        parentDataElement!.applyWidgetOutOfTurn(newPDWidget)

        // The new widget should have had applyParentData called with the render object.
        #expect(newPDWidget.appliedRenderObjects.count == 1)
        #expect(newPDWidget.appliedRenderObjects.first === renderObj)
    }

    @Test("applyWidgetOutOfTurn recurses through non-RenderObject children to find nested RenderObjectElements")
    func applyWidgetOutOfTurnRecursesThroughComponentElements() {
        let renderObj = RenderObject()
        let leafWidget = TestLeafRenderObjectWidget(renderObject: renderObj)
        // Wrap the leaf in a StatelessWidget (ComponentElement) intermediary.
        let intermediary = SimpleStatelessWidget(child: leafWidget)
        let pdWidget = TestParentDataWidget(child: intermediary, dataValue: 10)

        let owner = BuildOwner()
        let rootWidget = TestRootWidget(child: pdWidget)
        let rootElement = rootWidget.createElement()
        rootElement.owner = owner
        rootElement._lifecycleState = .active
        rootElement.mount(nil, nil)

        var parentDataElement: ParentDataElement<TestParentData>?
        rootElement.visitChildElements { child in
            if let pde = child as? ParentDataElement<TestParentData> {
                parentDataElement = pde
            }
        }

        #expect(parentDataElement != nil)

        let newPDWidget = TestParentDataWidget(child: intermediary, dataValue: 20)
        parentDataElement!.applyWidgetOutOfTurn(newPDWidget)

        // Despite the ComponentElement intermediary, applyParentData should reach the leaf.
        #expect(newPDWidget.appliedRenderObjects.count == 1)
        #expect(newPDWidget.appliedRenderObjects.first === renderObj)
    }

    @Test("notifyClients triggers _applyParentData with current widget")
    func notifyClientsAppliesCurrentWidget() {
        let renderObj = RenderObject()
        let leafWidget = TestLeafRenderObjectWidget(renderObject: renderObj)
        let pdWidget = TestParentDataWidget(child: leafWidget, dataValue: 99)

        let owner = BuildOwner()
        let rootWidget = TestRootWidget(child: pdWidget)
        let rootElement = rootWidget.createElement()
        rootElement.owner = owner
        rootElement._lifecycleState = .active
        rootElement.mount(nil, nil)

        var parentDataElement: ParentDataElement<TestParentData>?
        rootElement.visitChildElements { child in
            if let pde = child as? ParentDataElement<TestParentData> {
                parentDataElement = pde
            }
        }

        #expect(parentDataElement != nil)

        // Clear any applyParentData calls that happened during mount.
        pdWidget.appliedRenderObjects.removeAll()

        // Create a dummy old widget for the notifyClients call (it's unused since
        // notifyClients uses the element's current widget, not oldWidget).
        let dummyOldWidget = TestParentDataWidget(child: leafWidget, dataValue: 0)

        parentDataElement!.notifyClients(dummyOldWidget)

        // notifyClients should have applied the current widget (pdWidget) to the render object.
        #expect(pdWidget.appliedRenderObjects.count == 1)
        #expect(pdWidget.appliedRenderObjects.first === renderObj)
    }

    @Test("ParentDataElement properly inflates its child on mount")
    func inflatesChildOnMount() {
        let renderObj = RenderObject()
        let leafWidget = TestLeafRenderObjectWidget(renderObject: renderObj)
        let pdWidget = TestParentDataWidget(child: leafWidget)

        let owner = BuildOwner()
        let rootWidget = TestRootWidget(child: pdWidget)
        let rootElement = rootWidget.createElement()
        rootElement.owner = owner
        rootElement._lifecycleState = .active
        rootElement.mount(nil, nil)

        // After mounting, the ParentDataElement should have a child.
        var parentDataElement: ParentDataElement<TestParentData>?
        rootElement.visitChildElements { child in
            if let pde = child as? ParentDataElement<TestParentData> {
                parentDataElement = pde
            }
        }

        #expect(parentDataElement != nil)

        // The ParentDataElement (as a ComponentElement) should have a child element.
        var hasChild = false
        parentDataElement!.visitChildElements { _ in
            hasChild = true
        }
        #expect(hasChild)
    }

    @Test("_applyParentData applies to direct RenderObjectElement child (MultiChild)")
    func applyParentDataToMultiChildRenderObject() {
        let renderObj1 = RenderObject()
        let renderObj2 = RenderObject()
        let leaf1 = TestLeafRenderObjectWidget(renderObject: renderObj1)
        let leaf2 = TestLeafRenderObjectWidget(renderObject: renderObj2)

        // Use a multi-child widget under the ParentDataWidget.
        // _applyParentData stops at the first RenderObjectElement it finds,
        // so it applies to the MultiChildRenderObjectElement's render object,
        // not the leaves.
        let multiChild = TestMultiChildWidget(children: [leaf1, leaf2])
        let pdWidget = TestParentDataWidget(child: multiChild, dataValue: 55)

        let owner = BuildOwner()
        let rootWidget = TestRootWidget(child: pdWidget)
        let rootElement = rootWidget.createElement()
        rootElement.owner = owner
        rootElement._lifecycleState = .active
        rootElement.mount(nil, nil)

        var parentDataElement: ParentDataElement<TestParentData>?
        rootElement.visitChildElements { child in
            if let pde = child as? ParentDataElement<TestParentData> {
                parentDataElement = pde
            }
        }

        #expect(parentDataElement != nil)

        let newPDWidget = TestParentDataWidget(child: multiChild, dataValue: 77)
        parentDataElement!.applyWidgetOutOfTurn(newPDWidget)

        // _applyParentData applies to the MultiChildRenderObjectElement's render
        // object (the first RenderObjectElement found), not to the leaf render objects.
        #expect(newPDWidget.appliedRenderObjects.count == 1)
    }
}

// MARK: - Additional Test Helpers

/// A multi-child RenderObjectWidget for testing multiple children.
private class TestMultiChildWidget: MultiChildRenderObjectWidget {
    init(children: [Widget]) {
        super.init(children: children)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}
