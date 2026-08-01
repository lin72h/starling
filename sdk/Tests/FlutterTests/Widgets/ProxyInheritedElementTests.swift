// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

// MARK: - Test Helpers

/// A simple concrete widget whose createElement returns a plain Element.
private class SimpleWidget: Widget {
    override func createElement() -> Element {
        return Element(self)
    }
}

/// A ProxyWidget subclass that tracks calls to notifyClients and updated.
private class TrackingProxyWidget: ProxyWidget {
    override func createElement() -> Element {
        return TrackingProxyElement(self)
    }
}

/// A ProxyElement subclass that tracks calls to updated and notifyClients.
private class TrackingProxyElement: ProxyElement {
    var updatedCallCount = 0
    var updatedOldWidgets: [ProxyWidget] = []
    var notifyClientsCallCount = 0
    var notifyClientsOldWidgets: [ProxyWidget] = []

    override func updated(_ oldWidget: ProxyWidget) {
        updatedCallCount += 1
        updatedOldWidgets.append(oldWidget)
        super.updated(oldWidget)
    }

    override func notifyClients(_ oldWidget: ProxyWidget) {
        notifyClientsCallCount += 1
        notifyClientsOldWidgets.append(oldWidget)
    }
}

/// An InheritedWidget subclass with controllable updateShouldNotify.
private class TrackingInheritedWidget: InheritedWidget {
    let shouldNotify: Bool

    init(child: Widget, shouldNotify: Bool = true) {
        self.shouldNotify = shouldNotify
        super.init(child: child)
    }

    override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        return shouldNotify
    }

    override func createElement() -> Element {
        return TrackingInheritedElement(self)
    }
}

/// An InheritedElement subclass that tracks calls to notifyClients and notifyDependent.
private class TrackingInheritedElement: InheritedElement {
    var notifyClientsCallCount = 0
    var notifyDependentCallCount = 0
    var notifiedDependents: [Element] = []

    override func notifyClients(_ oldWidget: ProxyWidget) {
        notifyClientsCallCount += 1
        super.notifyClients(oldWidget)
    }

    override func notifyDependent(_ oldWidget: InheritedWidget, _ dependent: Element) {
        notifyDependentCallCount += 1
        notifiedDependents.append(dependent)
        super.notifyDependent(oldWidget, dependent)
    }
}

/// An Element subclass that tracks didChangeDependencies calls.
private class TrackingElement: Element {
    var didChangeDependenciesCallCount = 0

    init() {
        super.init(SimpleWidget())
    }

    override func didChangeDependencies() {
        didChangeDependenciesCallCount += 1
        super.didChangeDependencies()
    }
}

/// A root element that provides a BuildOwner, suitable for parenting test elements.
private class TestRootElement: Element {
    let buildOwner: BuildOwner

    init() {
        self.buildOwner = BuildOwner()
        super.init(SimpleWidget())
    }

    func activateAsRoot() {
        owner = buildOwner
        _lifecycleState = .active
    }
}

// MARK: - ProxyElement Tests

@Suite("ProxyElement")
struct ProxyElementExpandedTests {

    private func makeRoot() -> TestRootElement {
        let root = TestRootElement()
        root.activateAsRoot()
        return root
    }

    @Test("build returns the proxy widget's child")
    func buildReturnsChild() {
        let child = SimpleWidget()
        let proxyWidget = TrackingProxyWidget(child: child)
        let element = ProxyElement(proxyWidget)

        let built = element.build()

        #expect(built === child)
    }

    @Test("update calls updated with old widget then rebuilds")
    func updateCallsUpdatedThenRebuilds() {
        let child1 = SimpleWidget()
        let child2 = SimpleWidget()
        let widget1 = TrackingProxyWidget(child: child1)
        let widget2 = TrackingProxyWidget(child: child2)
        let element = TrackingProxyElement(widget1)

        // Mount so element is active and can rebuild
        let root = makeRoot()
        element.mount(root, nil)

        // Reset tracking after mount (mount triggers a first build)
        element.updatedCallCount = 0
        element.updatedOldWidgets = []

        element.update(widget2)

        // updated should have been called with widget1 as the old widget
        #expect(element.updatedCallCount == 1)
        #expect(element.updatedOldWidgets.first === widget1)
        // Widget should now be widget2
        #expect(element.widget === widget2)
    }

    @Test("updated calls notifyClients by default")
    func updatedCallsNotifyClients() {
        let child = SimpleWidget()
        let widget1 = TrackingProxyWidget(child: child)
        let widget2 = TrackingProxyWidget(child: child)
        let element = TrackingProxyElement(widget1)

        let root = makeRoot()
        element.mount(root, nil)

        element.notifyClientsCallCount = 0
        element.notifyClientsOldWidgets = []

        element.update(widget2)

        // updated -> notifyClients should have been called
        #expect(element.notifyClientsCallCount == 1)
        #expect(element.notifyClientsOldWidgets.first === widget1)
    }

    @Test("update changes widget reference to new widget")
    func updateChangesWidgetReference() {
        let child1 = SimpleWidget()
        let child2 = SimpleWidget()
        let widget1 = TrackingProxyWidget(child: child1)
        let widget2 = TrackingProxyWidget(child: child2)
        let element = ProxyElement(widget1)

        let root = makeRoot()
        element.mount(root, nil)

        #expect(element.widget === widget1)

        element.update(widget2)

        #expect(element.widget === widget2)
    }
}

// MARK: - InheritedElement Tests

@Suite("InheritedElement")
struct InheritedElementExpandedTests {

    private func makeRoot() -> TestRootElement {
        let root = TestRootElement()
        root.activateAsRoot()
        return root
    }

    @Test("_updateInheritance registers in inherited map under widget type")
    func updateInheritanceRegistersInMap() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let element = TrackingInheritedElement(inheritedWidget)

        let root = makeRoot()
        // mount calls _updateInheritance
        element.mount(root, nil)

        // The element's _inheritedElements should now contain this element
        // mapped to the widget's type
        let found = element._inheritedElements?[TrackingInheritedWidget.self]
        #expect(found === element)
    }

    @Test("updated only calls notifyClients when updateShouldNotify returns true")
    func updatedOnlyNotifiesWhenShouldNotify() {
        let child = SimpleWidget()
        let widget1 = TrackingInheritedWidget(child: child, shouldNotify: true)
        let widget2 = TrackingInheritedWidget(child: child, shouldNotify: true)
        let element = TrackingInheritedElement(widget1)

        let root = makeRoot()
        element.mount(root, nil)
        element.notifyClientsCallCount = 0

        // widget2.updateShouldNotify returns true, so notifyClients should be called
        element.update(widget2)

        #expect(element.notifyClientsCallCount == 1)
    }

    @Test("updateShouldNotify returning false means dependents NOT notified")
    func updateShouldNotifyFalseSkipsNotification() {
        let child = SimpleWidget()
        let widget1 = TrackingInheritedWidget(child: child, shouldNotify: false)
        let widget2 = TrackingInheritedWidget(child: child, shouldNotify: false)
        let element = TrackingInheritedElement(widget1)

        let root = makeRoot()
        element.mount(root, nil)
        element.notifyClientsCallCount = 0

        // widget2.updateShouldNotify returns false, so notifyClients should NOT be called
        element.update(widget2)

        #expect(element.notifyClientsCallCount == 0)
    }

    @Test("setDependencies and getDependencies manage dependent map")
    func setAndGetDependencies() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)

        let dependent = Element(SimpleWidget())
        let testValue: AnyObject = SimpleWidget()

        // Initially no dependencies
        #expect(element.getDependencies(dependent) == nil)

        // Set dependencies
        element.setDependencies(dependent, testValue)
        let retrieved = element.getDependencies(dependent)
        #expect(retrieved === testValue)

        // Overwrite with nil
        element.setDependencies(dependent, nil)
        #expect(element.getDependencies(dependent) == nil)
        // But the entry still exists in _dependents (value is nil, not removed)
        #expect(element._dependents[ObjectIdentifier(dependent)] != nil)
    }

    @Test("removeDependent removes from map")
    func removeDependentRemovesFromMap() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)

        let dependent = Element(SimpleWidget())
        element.setDependencies(dependent, nil)

        // Verify entry exists
        #expect(element._dependents[ObjectIdentifier(dependent)] != nil)

        element.removeDependent(dependent)

        // Should be removed
        #expect(element._dependents[ObjectIdentifier(dependent)] == nil)
    }

    @Test("notifyClients iterates all dependents and calls notifyDependent")
    func notifyClientsIteratesDependents() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child, shouldNotify: true)
        let element = TrackingInheritedElement(inheritedWidget)

        // Add multiple dependents
        let dep1 = TrackingElement()
        let dep2 = TrackingElement()
        let dep3 = TrackingElement()
        element.setDependencies(dep1, nil)
        element.setDependencies(dep2, nil)
        element.setDependencies(dep3, nil)

        element.notifyClients(inheritedWidget)

        // notifyDependent should have been called for each dependent
        #expect(element.notifyDependentCallCount == 3)
        // All three dependents should have been notified
        let notifiedIds = Set(element.notifiedDependents.map { ObjectIdentifier($0) })
        #expect(notifiedIds.contains(ObjectIdentifier(dep1)))
        #expect(notifiedIds.contains(ObjectIdentifier(dep2)))
        #expect(notifiedIds.contains(ObjectIdentifier(dep3)))
    }

    @Test("notifyDependent calls didChangeDependencies on dependent")
    func notifyDependentCallsDidChangeDependencies() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)

        let dependent = TrackingElement()
        // Make dependent active so markNeedsBuild doesn't bail out early
        dependent._lifecycleState = .active

        element.notifyDependent(inheritedWidget, dependent)

        #expect(dependent.didChangeDependenciesCallCount == 1)
    }

    @Test("dependent elements receive didChangeDependencies on notification via update")
    func dependentsReceiveDidChangeDependenciesOnUpdate() {
        let child = SimpleWidget()
        let widget1 = TrackingInheritedWidget(child: child, shouldNotify: true)
        let widget2 = TrackingInheritedWidget(child: child, shouldNotify: true)
        let element = TrackingInheritedElement(widget1)

        let root = makeRoot()
        element.mount(root, nil)

        // Register dependents
        let dep1 = TrackingElement()
        dep1._lifecycleState = .active
        let dep2 = TrackingElement()
        dep2._lifecycleState = .active
        element.setDependencies(dep1, nil)
        element.setDependencies(dep2, nil)

        // Update triggers updated -> notifyClients -> notifyDependent -> didChangeDependencies
        element.update(widget2)

        #expect(dep1.didChangeDependenciesCallCount == 1)
        #expect(dep2.didChangeDependenciesCallCount == 1)
    }

    @Test("dependOnInheritedWidgetOfExactType registers dependency and returns widget")
    func dependOnInheritedWidgetOfExactType() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let inheritedElement = InheritedElement(inheritedWidget)

        let root = makeRoot()
        inheritedElement.mount(root, nil)

        // Create a child element mounted under the inherited element
        // so it inherits the inherited elements map
        let childElement = TrackingElement()
        childElement.mount(inheritedElement, nil)

        // Now look up the inherited widget
        let result = childElement.dependOnInheritedWidgetOfExactType(TrackingInheritedWidget.self)

        // Should return the inherited widget
        #expect(result === inheritedWidget)

        // The child should have recorded a dependency
        #expect(childElement._dependencies != nil)
        #expect(childElement._dependencies!.contains(ObjectIdentifier(inheritedElement)))

        // The inherited element should have recorded the child as a dependent
        #expect(inheritedElement._dependents[ObjectIdentifier(childElement)] != nil)
    }

    @Test("updateDependencies default implementation sets nil value")
    func updateDependenciesDefault() {
        let child = SimpleWidget()
        let inheritedWidget = TrackingInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)

        let dependent = Element(SimpleWidget())

        element.updateDependencies(dependent, aspect: nil)

        // Should have registered with nil value
        let entry = element._dependents[ObjectIdentifier(dependent)]
        #expect(entry != nil)
        #expect(entry?.element === dependent)
        #expect(entry?.value == nil)
    }
}
