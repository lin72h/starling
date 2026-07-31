// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A minimal StatelessWidget that returns a fixed child.
private class TestStatelessWidget: StatelessWidget {
    let child: Widget

    init(child: Widget) {
        self.child = child
        super.init()
    }

    override func build(_ context: any BuildContext) -> Widget {
        return child
    }
}

/// A concrete LeafRenderObjectWidget for use as a leaf in the tree.
private class TestLeafWidget: LeafRenderObjectWidget {
    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return TestRenderObject()
    }
}

/// A concrete RenderObject subclass for testing.
/// Conforms to `SingleChildRenderObjectHost` because `TestSingleChildROWidget`
/// below hands it to a real `SingleChildRenderObjectElement`, whose
/// `insertRenderObjectChild` casts to that protocol to store the child — as
/// Dart's does. Without the conformance, mounting a child crashed the whole
/// test run inside the cast rather than failing one case.
private class TestRenderObject: RenderBox, SingleChildRenderObjectHost {
    var child: RenderBox?
}

/// A concrete SingleChildRenderObjectWidget for testing render object ancestor queries.
private class TestSingleChildROWidget: SingleChildRenderObjectWidget {
    init(child: Widget? = nil) {
        super.init(key: nil, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return TestRenderObject()
    }
}

/// A concrete StatefulWidget for testing findAncestorStateOfType.
private class TestStatefulWidget: StatefulWidget {
    let child: Widget

    init(child: Widget) {
        self.child = child
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return TestState()
    }
}

/// The State for TestStatefulWidget.
private class TestState: State<StatefulWidget> {
    override func build(_ context: any BuildContext) -> Widget {
        return (widget as! TestStatefulWidget).child
    }
}

/// A concrete InheritedWidget for testing dependency registration.
private class TestInheritedWidget: InheritedWidget {
    let value: Int

    init(value: Int, child: Widget) {
        self.value = value
        super.init(child: child)
    }

    override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let old = oldWidget as? TestInheritedWidget else { return true }
        return value != old.value
    }
}

/// A root element that provides a BuildOwner to the tree.
private class TestRootElement: RenderObjectElement {
    let buildOwner: BuildOwner

    init(owner: BuildOwner = BuildOwner()) {
        self.buildOwner = owner
        let widget = TestSingleChildROWidget()
        super.init(widget)
    }

    func setup() {
        self.owner = buildOwner
        _lifecycleState = .active
        renderObject = RenderObject()
    }

    override func insertRenderObjectChild(_ child: RenderObject, _ slot: Any?) {}
    override func removeRenderObjectChild(_ child: RenderObject, _ slot: Any?) {}
}

// MARK: - BuildContext Tests

@Suite("BuildContext")
struct BuildContextTests {

    private func makeRoot(owner: BuildOwner = BuildOwner()) -> TestRootElement {
        let root = TestRootElement(owner: owner)
        root.setup()
        return root
    }

    // MARK: - findAncestorWidgetOfExactType

    @Test("findAncestorWidgetOfExactType finds correct ancestor widget")
    func findAncestorWidgetOfExactType_found() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let statelessWidget = TestStatelessWidget(child: leafWidget)

        // Mount the stateless element under root
        let statelessElement = statelessWidget.createElement()
        statelessElement.mount(root, nil)

        // The stateless element builds a child; get it
        let childElement = (statelessElement as! ComponentElement)._child!

        // From childElement, find the TestStatelessWidget ancestor
        let found = childElement.findAncestorWidgetOfExactType(TestStatelessWidget.self)
        #expect(found != nil)
        #expect(found === statelessWidget)
    }

    @Test("findAncestorWidgetOfExactType returns nil when not found")
    func findAncestorWidgetOfExactType_notFound() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()

        let element = leafWidget.createElement()
        element.mount(root, nil)

        // No TestStatelessWidget in the ancestor chain
        let found = element.findAncestorWidgetOfExactType(TestStatelessWidget.self)
        #expect(found == nil)
    }

    // MARK: - findAncestorStateOfType

    @Test("findAncestorStateOfType finds State of nearest matching StatefulWidget")
    func findAncestorStateOfType_found() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let statefulWidget = TestStatefulWidget(child: leafWidget)

        let statefulElement = statefulWidget.createElement() as! StatefulElement
        statefulElement.mount(root, nil)

        // The stateful element builds a child
        let childElement = (statefulElement as ComponentElement)._child!

        let state = childElement.findAncestorStateOfType(TestState.self)
        #expect(state != nil)
        #expect(state === statefulElement.state)
    }

    // MARK: - findRootAncestorStateOfType

    @Test("findRootAncestorStateOfType finds State of furthest matching StatefulWidget")
    func findRootAncestorStateOfType_found() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        // Inner stateful wraps leaf
        let innerStateful = TestStatefulWidget(child: leafWidget)
        // Outer stateful wraps inner stateful
        let outerStateful = TestStatefulWidget(child: innerStateful)

        let outerElement = outerStateful.createElement() as! StatefulElement
        outerElement.mount(root, nil)

        // Walk down: outerElement -> innerStatefulElement -> leafElement
        let outerChild = (outerElement as ComponentElement)._child!
        let innerStatefulElement = outerChild as! StatefulElement
        let leafElement = (innerStatefulElement as ComponentElement)._child!

        // From the leaf, findRootAncestorStateOfType should find the outermost TestState
        let rootState = leafElement.findRootAncestorStateOfType(TestState.self)
        #expect(rootState != nil)
        #expect(rootState === outerElement.state)

        // Verify it's different from the nearest
        let nearestState = leafElement.findAncestorStateOfType(TestState.self)
        #expect(nearestState === innerStatefulElement.state)
        #expect(rootState !== nearestState)
    }

    // MARK: - findAncestorRenderObjectOfType

    @Test("findAncestorRenderObjectOfType finds RenderObject ancestor")
    func findAncestorRenderObjectOfType_found() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let singleChildWidget = TestSingleChildROWidget(child: leafWidget)

        let singleChildElement = singleChildWidget.createElement() as! SingleChildRenderObjectElement
        singleChildElement.mount(root, nil)

        let childElement = singleChildElement._child!

        let ro = childElement.findAncestorRenderObjectOfType(TestRenderObject.self)
        #expect(ro != nil)
        #expect(ro === singleChildElement.renderObject)
    }

    // MARK: - dependOnInheritedWidgetOfExactType

    @Test("dependOnInheritedWidgetOfExactType registers dependency and returns widget")
    func dependOnInheritedWidget_found() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let inheritedWidget = TestInheritedWidget(value: 42, child: leafWidget)

        let inheritedElement = inheritedWidget.createElement() as! InheritedElement
        inheritedElement.mount(root, nil)

        let childElement = (inheritedElement as ComponentElement)._child!

        let result = childElement.dependOnInheritedWidgetOfExactType(TestInheritedWidget.self)
        #expect(result != nil)
        #expect(result!.value == 42)

        // Verify dependency was registered
        #expect(childElement._dependencies != nil)
        #expect(childElement._dependencies!.contains(ObjectIdentifier(inheritedElement)))
    }

    @Test("dependOnInheritedWidgetOfExactType returns nil when not found and sets hadUnsatisfiedDependencies")
    func dependOnInheritedWidget_notFound() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()

        let element = leafWidget.createElement()
        element.mount(root, nil)

        #expect(element._hadUnsatisfiedDependencies == false)

        let result = element.dependOnInheritedWidgetOfExactType(TestInheritedWidget.self)
        #expect(result == nil)
        #expect(element._hadUnsatisfiedDependencies == true)
    }

    // MARK: - visitAncestorElements

    @Test("visitAncestorElements visits all ancestors and stops on false")
    func visitAncestorElements_stopsOnFalse() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let middleWidget = TestStatelessWidget(child: leafWidget)

        let middleElement = middleWidget.createElement()
        middleElement.mount(root, nil)

        let childElement = (middleElement as! ComponentElement)._child!

        // Visit all ancestors
        var allAncestors: [Element] = []
        childElement.visitAncestorElements { ancestor in
            allAncestors.append(ancestor)
            return true
        }
        // Should visit: middleElement, root
        #expect(allAncestors.count == 2)
        #expect(allAncestors[0] === middleElement)
        #expect(allAncestors[1] === root)

        // Visit ancestors stopping at first one
        var stoppedAncestors: [Element] = []
        childElement.visitAncestorElements { ancestor in
            stoppedAncestors.append(ancestor)
            return false // stop immediately
        }
        #expect(stoppedAncestors.count == 1)
        #expect(stoppedAncestors[0] === middleElement)
    }

    // MARK: - visitChildElements

    @Test("visitChildElements visits children")
    func visitChildElements_visitsChildren() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let statelessWidget = TestStatelessWidget(child: leafWidget)

        let element = statelessWidget.createElement()
        element.mount(root, nil)

        var children: [Element] = []
        element.visitChildElements { child in
            children.append(child)
        }

        // ComponentElement has one child
        #expect(children.count == 1)
        #expect(children[0].widget === leafWidget)
    }

    // MARK: - mounted

    @Test("mounted returns true when active, false otherwise")
    func mounted_lifecycle() {
        let root = makeRoot()
        let leafWidget = TestLeafWidget()
        let element = leafWidget.createElement()

        // Before mount: lifecycle is initial, mounted should be false
        #expect(element.mounted == false)

        element.mount(root, nil)
        #expect(element.mounted == true)

        element.deactivate()
        #expect(element.mounted == false)
    }
}

// MARK: - BuildOwner Tests

@Suite("BuildOwner")
struct BuildOwnerTests {

    private func makeRoot(owner: BuildOwner) -> TestRootElement {
        let root = TestRootElement(owner: owner)
        root.setup()
        return root
    }

    // MARK: - scheduleBuildFor

    @Test("scheduleBuildFor adds element to dirty list and calls onBuildScheduled")
    func scheduleBuildFor_addsToDirtyList() {
        var scheduledCount = 0
        let owner = BuildOwner(onBuildScheduled: {
            scheduledCount += 1
        })
        let root = makeRoot(owner: owner)
        let leafWidget = TestLeafWidget()
        let element = leafWidget.createElement()
        element.mount(root, nil)

        // Reset dirty state so we can test scheduleBuildFor explicitly
        element._dirty = false
        element._inDirtyList = false

        owner.scheduleBuildFor(element)

        #expect(element._inDirtyList == true)
        #expect(owner.buildScope._dirtyElements.contains { $0 === element })
        #expect(scheduledCount == 1)
    }

    // MARK: - buildScopeWithCallback

    @Test("buildScopeWithCallback processes dirty elements by depth")
    func buildScopeWithCallback_processesByDepth() {
        let owner = BuildOwner()
        let root = makeRoot(owner: owner)

        // Create a chain: root -> statelessElement -> leafElement
        let leafWidget = TestLeafWidget()
        let statelessWidget = TestStatelessWidget(child: leafWidget)
        let statelessElement = statelessWidget.createElement()
        statelessElement.mount(root, nil)

        let leafElement = (statelessElement as! ComponentElement)._child!

        // Mark both dirty and add to dirty list
        statelessElement._dirty = true
        statelessElement._inDirtyList = true
        leafElement._dirty = true
        leafElement._inDirtyList = true

        // Add in reverse depth order to ensure sorting works
        owner.buildScope._dirtyElements.append(leafElement)
        owner.buildScope._dirtyElements.append(statelessElement)

        owner.buildScopeWithCallback(root)

        // After build, dirty list should be empty and elements no longer dirty
        #expect(owner.buildScope._dirtyElements.isEmpty)
        #expect(statelessElement._dirty == false)
        #expect(leafElement._dirty == false)
    }

    @Test("buildScopeWithCallback handles elements dirtied during rebuild")
    func buildScopeWithCallback_handlesDynamicDirty() {
        let owner = BuildOwner()
        let root = makeRoot(owner: owner)
        let leafWidget = TestLeafWidget()
        let statelessWidget = TestStatelessWidget(child: leafWidget)
        let statelessElement = statelessWidget.createElement()
        statelessElement.mount(root, nil)

        // Use the callback to dirty an element during the build scope
        let leafElement = (statelessElement as! ComponentElement)._child!

        owner.buildScopeWithCallback(root) {
            // During the callback, mark the leaf element dirty
            leafElement._dirty = true
            leafElement._inDirtyList = true
            owner.buildScope._dirtyElements.append(leafElement)
        }

        // After buildScope completes, the dynamically-dirtied element should be clean
        #expect(owner.buildScope._dirtyElements.isEmpty)
        #expect(leafElement._dirty == false)
    }

    // MARK: - finalizeTree

    @Test("finalizeTree unmounts inactive elements")
    func finalizeTree_unmountsInactive() {
        let owner = BuildOwner()
        let root = makeRoot(owner: owner)
        let leafWidget = TestLeafWidget()
        let element = leafWidget.createElement()
        element.mount(root, nil)

        #expect(element.mounted == true)

        // Deactivate the child, which adds it to inactive list
        root.deactivateChild(element)
        #expect(element._lifecycleState == .inactive)

        // Finalize should unmount all inactive elements
        owner.finalizeTree()
        #expect(element._lifecycleState == .defunct)
    }

    // MARK: - lockState

    @Test("lockState sets _debugStateLocked during callback")
    func lockState_setsFlag() {
        let owner = BuildOwner()

        #expect(owner._debugStateLocked == false)

        var wasLocked = false
        owner.lockState {
            wasLocked = owner._debugStateLocked
        }

        #expect(wasLocked == true)
        #expect(owner._debugStateLocked == false)
    }
}

// MARK: - BuildScope Tests

@Suite("BuildScope")
struct BuildScopeTests {

    @Test("BuildScope.dirty returns true when dirty elements exist")
    func dirty_reflectsDirtyElements() {
        let scope = BuildScope()
        #expect(scope.dirty == false)

        // Add a dummy element to the dirty list
        let widget = TestLeafWidget()
        let element = Element(widget)
        scope._dirtyElements.append(element)

        #expect(scope.dirty == true)

        scope._dirtyElements.removeAll()
        #expect(scope.dirty == false)
    }
}
