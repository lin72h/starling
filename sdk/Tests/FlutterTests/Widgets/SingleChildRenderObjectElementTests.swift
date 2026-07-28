// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A concrete LeafRenderObjectWidget for use as a child widget.
private class TestLeafWidget: LeafRenderObjectWidget {
    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A concrete SingleChildRenderObjectWidget with controllable child.
private class TestSCROWidget: SingleChildRenderObjectWidget {
    init(child: Widget? = nil) {
        super.init(key: nil, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A root element that can serve as a parent and provide a BuildOwner.
private class TestRootElement: RenderObjectElement {
    let buildOwner: BuildOwner

    init() {
        let widget = TestSCROWidget()
        self.buildOwner = BuildOwner()
        super.init(widget)
    }

    /// Set up this root element as an active parent with an owner.
    func setup() {
        owner = buildOwner
        _lifecycleState = .active
        renderObject = RenderObject()
    }

    override func insertRenderObjectChild(_ child: RenderObject, _ slot: Any?) {
        // No-op for test root
    }

    override func removeRenderObjectChild(_ child: RenderObject, _ slot: Any?) {
        // No-op for test root
    }
}

// MARK: - Tests

@Suite("SingleChildRenderObjectElement Lifecycle")
struct SingleChildRenderObjectElementLifecycleTests {

    /// Creates a root element suitable for parenting test elements.
    private func makeRoot() -> TestRootElement {
        let root = TestRootElement()
        root.setup()
        return root
    }

    @Test("mount inflates child widget and sets _child")
    func mountInflatesChild() {
        let root = makeRoot()
        let childWidget = TestLeafWidget()
        let widget = TestSCROWidget(child: childWidget)
        let element = SingleChildRenderObjectElement(widget)

        element.mount(root, nil)

        #expect(element._child != nil)
        #expect(element._child!.widget === childWidget)
        #expect(element.renderObject != nil)
    }

    @Test("mount with nil child leaves _child nil")
    func mountWithNilChild() {
        let root = makeRoot()
        let widget = TestSCROWidget(child: nil)
        let element = SingleChildRenderObjectElement(widget)

        element.mount(root, nil)

        #expect(element._child == nil)
        #expect(element.renderObject != nil)
    }

    @Test("update updates existing child via updateChild")
    func updateUpdatesChild() {
        let root = makeRoot()
        let childWidget1 = TestLeafWidget()
        let widget1 = TestSCROWidget(child: childWidget1)
        let element = SingleChildRenderObjectElement(widget1)
        element.mount(root, nil)

        let originalChild = element._child
        #expect(originalChild != nil)

        // Update with a new widget of the same type — should reuse the child element
        let childWidget2 = TestLeafWidget()
        let widget2 = TestSCROWidget(child: childWidget2)
        element.update(widget2)

        #expect(element._child != nil)
        // Same type => child element is reused and updated
        #expect(element._child === originalChild)
        #expect(element._child!.widget === childWidget2)
    }

    @Test("update from child to nil deactivates child")
    func updateFromChildToNil() {
        let root = makeRoot()
        let childWidget = TestLeafWidget()
        let widget1 = TestSCROWidget(child: childWidget)
        let element = SingleChildRenderObjectElement(widget1)
        element.mount(root, nil)

        #expect(element._child != nil)

        // Update with nil child
        let widget2 = TestSCROWidget(child: nil)
        element.update(widget2)

        #expect(element._child == nil)
    }

    @Test("update from nil to child inflates new child")
    func updateFromNilToChild() {
        let root = makeRoot()
        let widget1 = TestSCROWidget(child: nil)
        let element = SingleChildRenderObjectElement(widget1)
        element.mount(root, nil)

        #expect(element._child == nil)

        // Update to add a child
        let childWidget = TestLeafWidget()
        let widget2 = TestSCROWidget(child: childWidget)
        element.update(widget2)

        #expect(element._child != nil)
        #expect(element._child!.widget === childWidget)
    }

    @Test("visitChildElements visits single child")
    func visitChildElementsVisitsChild() {
        let root = makeRoot()
        let childWidget = TestLeafWidget()
        let widget = TestSCROWidget(child: childWidget)
        let element = SingleChildRenderObjectElement(widget)
        element.mount(root, nil)

        var visited: [Element] = []
        element.visitChildElements { child in
            visited.append(child)
        }

        #expect(visited.count == 1)
        #expect(visited[0] === element._child)
    }

    @Test("visitChildElements with no child does not call visitor")
    func visitChildElementsNoChild() {
        let root = makeRoot()
        let widget = TestSCROWidget(child: nil)
        let element = SingleChildRenderObjectElement(widget)
        element.mount(root, nil)

        var visitCount = 0
        element.visitChildElements { _ in
            visitCount += 1
        }

        #expect(visitCount == 0)
    }

    @Test("forgetChild clears _child")
    func forgetChildClearsChild() {
        let root = makeRoot()
        let childWidget = TestLeafWidget()
        let widget = TestSCROWidget(child: childWidget)
        let element = SingleChildRenderObjectElement(widget)
        element.mount(root, nil)

        let child = element._child!
        element.forgetChild(child)

        #expect(element._child == nil)
    }
}
