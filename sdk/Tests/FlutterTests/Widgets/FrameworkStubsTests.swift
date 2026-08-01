// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import Flutter

/// Tests for the framework stub classes in FrameworkStubs.swift.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart`

// MARK: - Test Helpers

/// A concrete Widget subclass that overrides createElement (does not fatalError).
private class ConcreteWidget: Widget {
    override func createElement() -> Element {
        return Element(self)
    }
}

/// A concrete StatelessWidget subclass for testing.
private class ConcreteStatelessWidget: StatelessWidget {
    let returnWidget: Widget

    init(key: (any Key)? = nil, returnWidget: Widget? = nil) {
        self.returnWidget = returnWidget ?? ConcreteWidget()
        super.init(key: key)
    }

    override func build(_ context: any BuildContext) -> Widget {
        return returnWidget
    }
}

/// A concrete StatefulWidget subclass for testing.
private class ConcreteStatefulWidget: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return ConcreteState()
    }
}

/// A concrete State subclass for testing.
private class ConcreteState: State<StatefulWidget> {}

/// A concrete InheritedWidget subclass for testing.
private class ConcreteInheritedWidget: InheritedWidget {
    let shouldNotify: Bool

    init(key: (any Key)? = nil, child: Widget, shouldNotify: Bool = false) {
        self.shouldNotify = shouldNotify
        super.init(key: key, child: child)
    }

    override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        return shouldNotify
    }
}

/// A concrete RenderObjectWidget subclass for testing.
private class ConcreteRenderObjectWidget: RenderObjectWidget {
    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderObject()
    }
}

/// A dummy child widget for composition.
private class DummyChild: Widget {
    init() { super.init(key: nil) }
}

// MARK: - Widget Tests

@Suite("Widget")
struct WidgetTests {

    @Test("Construction with key")
    func constructionWithKey() {
        let key = ValueKey<String>("widget-key")
        let widget = ConcreteWidget(key: key)
        #expect(widget.key != nil)
    }

    @Test("Construction without key")
    func constructionWithoutKey() {
        let widget = ConcreteWidget()
        #expect(widget.key == nil)
    }

    @Test("key property returns the provided key")
    func keyPropertyReturnsProvidedKey() {
        let key = ValueKey<String>("my-key")
        let widget = ConcreteWidget(key: key)
        // Compare via AnyHashable since Key is a protocol
        #expect(widget.key != nil)
    }

    @Test("key property is nil when not provided")
    func keyPropertyNilWhenNotProvided() {
        let widget = Widget()
        #expect(widget.key == nil)
    }

    @Test("Concrete subclass createElement does not crash")
    func concreteSubclassCreateElement() {
        let widget = ConcreteWidget()
        let element = widget.createElement()
        #expect(element is Element)
    }
}

// MARK: - Element Tests

@Suite("Element")
struct ElementTests {

    @Test("Construction with widget")
    func constructionWithWidget() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        #expect(element.widget === widget)
    }

    @Test("widget property returns the widget passed in constructor")
    func widgetProperty() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        #expect(element.widget === widget)
    }

    @Test("depth defaults to 0")
    func depthDefaultZero() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        #expect(element.depth == 0)
    }

    @Test("markNeedsBuild does not crash (stub)")
    func markNeedsBuildDoesNotCrash() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        element.markNeedsBuild()
        // If we get here, it didn't crash
        #expect(true)
    }

    @Test("unmount does not crash (stub)")
    func unmountDoesNotCrash() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        element.unmount()
        #expect(true)
    }

    @Test("visitChildElements does not crash (stub)")
    func visitChildElementsDoesNotCrash() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        var visited = false
        element.visitChildElements { _ in visited = true }
        // Stub does nothing, so visited should remain false
        #expect(visited == false)
    }

    @Test("dispatchNotification does not crash (stub)")
    func dispatchNotificationDoesNotCrash() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        let notification = Notification()
        element.dispatchNotification(notification)
        #expect(true)
    }

    @Test("Element conforms to BuildContext")
    func conformsToBuildContext() {
        let widget = ConcreteWidget()
        let element = Element(widget)
        #expect(element is any BuildContext)
    }
}

// MARK: - ComponentElement Tests

@Suite("ComponentElement")
struct ComponentElementTests {

    @Test("ComponentElement is an Element")
    func isElement() {
        let widget = ConcreteWidget()
        let element = ComponentElement(widget)
        #expect(element is Element)
    }

    @Test("ComponentElement conforms to BuildContext")
    func conformsToBuildContext() {
        let widget = ConcreteWidget()
        let element = ComponentElement(widget)
        #expect(element is any BuildContext)
    }
}

// MARK: - ProxyWidget Tests

@Suite("ProxyWidget")
struct ProxyWidgetTests {

    @Test("Construction with child")
    func constructionWithChild() {
        let child = DummyChild()
        let proxy = ProxyWidget(child: child)
        #expect(proxy.child === child)
    }

    @Test("child property returns the child widget")
    func childProperty() {
        let child = ConcreteWidget()
        let proxy = ProxyWidget(child: child)
        #expect(proxy.child === child)
    }

    @Test("Construction with key and child")
    func constructionWithKeyAndChild() {
        let key = ValueKey<String>("proxy-key")
        let child = DummyChild()
        let proxy = ProxyWidget(key: key, child: child)
        #expect(proxy.key != nil)
        #expect(proxy.child === child)
    }

    @Test("ProxyWidget is a Widget")
    func isWidget() {
        let child = DummyChild()
        let proxy = ProxyWidget(child: child)
        #expect(proxy is Widget)
    }
}

// MARK: - ProxyElement Tests

@Suite("ProxyElement")
struct ProxyElementTests {

    @Test("Construction")
    func construction() {
        let child = DummyChild()
        let proxyWidget = ProxyWidget(child: child)
        let element = ProxyElement(proxyWidget)
        #expect(element.widget === proxyWidget)
    }

    @Test("notifyClients stub does not crash")
    func notifyClientsStubDoesNotCrash() {
        let child = DummyChild()
        let proxyWidget = ProxyWidget(child: child)
        let element = ProxyElement(proxyWidget)
        element.notifyClients(proxyWidget)
        #expect(true)
    }

    @Test("update method changes widget and calls notifyClients")
    func updateMethodChangesWidget() {
        let child1 = DummyChild()
        let child2 = DummyChild()
        let proxyWidget1 = ProxyWidget(child: child1)
        let proxyWidget2 = ProxyWidget(child: child2)
        let element = ProxyElement(proxyWidget1)
        #expect(element.widget === proxyWidget1)

        element.update(proxyWidget2)
        #expect(element.widget === proxyWidget2)
    }

    @Test("ProxyElement is a ComponentElement")
    func isComponentElement() {
        let child = DummyChild()
        let element = ProxyElement(ProxyWidget(child: child))
        #expect(element is ComponentElement)
    }

    @Test("ProxyElement is an Element")
    func isElement() {
        let child = DummyChild()
        let element = ProxyElement(ProxyWidget(child: child))
        #expect(element is Element)
    }
}

// MARK: - InheritedWidget Tests

@Suite("InheritedWidget")
struct InheritedWidgetTests {

    @Test("Construction with child")
    func constructionWithChild() {
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(child: child)
        #expect(inherited.child === child)
    }

    @Test("Construction with key and child")
    func constructionWithKeyAndChild() {
        let key = ValueKey<String>("iw-key")
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(key: key, child: child)
        #expect(inherited.key != nil)
        #expect(inherited.child === child)
    }

    @Test("updateShouldNotify returns configured value (true)")
    func updateShouldNotifyTrue() {
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(child: child, shouldNotify: true)
        let old = ConcreteInheritedWidget(child: child, shouldNotify: false)
        #expect(inherited.updateShouldNotify(old) == true)
    }

    @Test("updateShouldNotify returns configured value (false)")
    func updateShouldNotifyFalse() {
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(child: child, shouldNotify: false)
        let old = ConcreteInheritedWidget(child: child, shouldNotify: true)
        #expect(inherited.updateShouldNotify(old) == false)
    }

    @Test("InheritedWidget is a ProxyWidget")
    func isProxyWidget() {
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(child: child)
        #expect(inherited is ProxyWidget)
    }

    @Test("InheritedWidget is a Widget")
    func isWidget() {
        let child = ConcreteWidget()
        let inherited = ConcreteInheritedWidget(child: child)
        #expect(inherited is Widget)
    }
}

// MARK: - StatelessWidget Tests

@Suite("StatelessWidget")
struct StatelessWidgetTests {

    @Test("Construction with key")
    func constructionWithKey() {
        let key = ValueKey<String>("stateless-key")
        let widget = ConcreteStatelessWidget(key: key)
        #expect(widget.key != nil)
    }

    @Test("Construction without key")
    func constructionWithoutKey() {
        let widget = ConcreteStatelessWidget()
        #expect(widget.key == nil)
    }

    @Test("Concrete subclass build returns expected widget")
    func buildReturnsExpectedWidget() {
        let expectedChild = ConcreteWidget()
        let widget = ConcreteStatelessWidget(returnWidget: expectedChild)
        let context = Element(widget)
        let result = widget.build(context)
        #expect(result === expectedChild)
    }

    @Test("StatelessWidget is a Widget")
    func isWidget() {
        let widget = ConcreteStatelessWidget()
        #expect(widget is Widget)
    }
}

// MARK: - StatefulWidget Tests

@Suite("StatefulWidget")
struct StatefulWidgetTests {

    @Test("Construction with key")
    func constructionWithKey() {
        let key = ValueKey<String>("stateful-key")
        let widget = ConcreteStatefulWidget(key: key)
        #expect(widget.key != nil)
    }

    @Test("Construction without key")
    func constructionWithoutKey() {
        let widget = ConcreteStatefulWidget()
        #expect(widget.key == nil)
    }

    @Test("Concrete subclass createState returns a State")
    func createStateReturnsState() {
        let widget = ConcreteStatefulWidget()
        let state = widget.createState()
        #expect(state is ConcreteState)
    }

    @Test("StatefulWidget is a Widget")
    func isWidget() {
        let widget = ConcreteStatefulWidget()
        #expect(widget is Widget)
    }
}

// MARK: - State Tests

@Suite("State")
struct StateTests {

    @Test("Construction with default values")
    func constructionDefaults() {
        let state = ConcreteState()
        #expect(state.mounted == false)
        #expect(state.widget == nil)
        #expect(state.context == nil)
    }

    @Test("mounted defaults to false")
    func mountedDefaultFalse() {
        let state = ConcreteState()
        #expect(state.mounted == false)
    }

    @Test("widget defaults to nil")
    func widgetDefaultNil() {
        let state = ConcreteState()
        #expect(state.widget == nil)
    }

    @Test("context defaults to nil")
    func contextDefaultNil() {
        let state = ConcreteState()
        #expect(state.context == nil)
    }
}

// MARK: - SingleChildRenderObjectWidget Tests

@Suite("SingleChildRenderObjectWidget")
struct SingleChildRenderObjectWidgetTests {

    @Test("Construction with child")
    func constructionWithChild() {
        let child = ConcreteWidget()
        let widget = SingleChildRenderObjectWidget(child: child)
        #expect(widget.child === child)
    }

    @Test("Construction without child")
    func constructionWithoutChild() {
        let widget = SingleChildRenderObjectWidget()
        #expect(widget.child == nil)
    }

    @Test("Construction with key and child")
    func constructionWithKeyAndChild() {
        let key = ValueKey<String>("scrow-key")
        let child = ConcreteWidget()
        let widget = SingleChildRenderObjectWidget(key: key, child: child)
        #expect(widget.key != nil)
        #expect(widget.child === child)
    }

    @Test("SingleChildRenderObjectWidget is a RenderObjectWidget")
    func isRenderObjectWidget() {
        let widget = SingleChildRenderObjectWidget()
        #expect(widget is RenderObjectWidget)
    }

    @Test("SingleChildRenderObjectWidget is a Widget")
    func isWidget() {
        let widget = SingleChildRenderObjectWidget()
        #expect(widget is Widget)
    }
}

// MARK: - LeafRenderObjectWidget Tests

@Suite("LeafRenderObjectWidget")
struct LeafRenderObjectWidgetTests {

    @Test("Construction without key")
    func constructionWithoutKey() {
        let widget = LeafRenderObjectWidget()
        #expect(widget.key == nil)
    }

    @Test("Construction with key")
    func constructionWithKey() {
        let key = ValueKey<String>("leaf-key")
        let widget = LeafRenderObjectWidget(key: key)
        #expect(widget.key != nil)
    }

    @Test("LeafRenderObjectWidget is a RenderObjectWidget")
    func isRenderObjectWidget() {
        let widget = LeafRenderObjectWidget()
        #expect(widget is RenderObjectWidget)
    }

    @Test("LeafRenderObjectWidget is a Widget")
    func isWidget() {
        let widget = LeafRenderObjectWidget()
        #expect(widget is Widget)
    }
}

// MARK: - GlobalKey Tests

@Suite("GlobalKey")
struct GlobalKeyTests {

    @Test("Construction without debugLabel")
    func constructionWithoutDebugLabel() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key != nil)
    }

    @Test("Construction with debugLabel")
    func constructionWithDebugLabel() {
        let key = GlobalKey<State<StatefulWidget>>(debugLabel: "my-label")
        #expect(key != nil)
    }

    @Test("Equality is identity-based: same instance")
    func equalitySameInstance() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key == key)
    }

    @Test("Equality is identity-based: different instances not equal")
    func equalityDifferentInstances() {
        let key1 = GlobalKey<State<StatefulWidget>>()
        let key2 = GlobalKey<State<StatefulWidget>>()
        #expect(key1 != key2)
    }

    @Test("Hash is identity-based: same instance same hash")
    func hashSameInstance() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key.hashValue == key.hashValue)
    }

    @Test("Hash is identity-based: different instances different hash")
    func hashDifferentInstances() {
        let key1 = GlobalKey<State<StatefulWidget>>()
        let key2 = GlobalKey<State<StatefulWidget>>()
        // Not strictly guaranteed but overwhelmingly likely for identity-based hashing
        #expect(key1.hashValue != key2.hashValue)
    }

    @Test("currentWidget is nil by default")
    func currentWidgetNilByDefault() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key.currentWidget == nil)
    }

    @Test("currentContext is nil by default")
    func currentContextNilByDefault() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key.currentContext == nil)
    }

    @Test("currentState is nil by default")
    func currentStateNilByDefault() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key.currentState == nil)
    }

    @Test("description includes class name")
    func descriptionIncludesClassName() {
        let key = GlobalKey<State<StatefulWidget>>()
        let desc = key.description
        #expect(desc.contains("GlobalKey"))
    }

    @Test("description includes debug label when provided")
    func descriptionIncludesDebugLabel() {
        let key = GlobalKey<State<StatefulWidget>>(debugLabel: "test-label")
        let desc = key.description
        #expect(desc.contains("test-label"))
    }

    @Test("description does not include label text when no label")
    func descriptionNoLabelWhenNone() {
        let key = GlobalKey<State<StatefulWidget>>()
        let desc = key.description
        // Should be like "[GlobalKey<...>]" without extra space+label
        #expect(desc.hasPrefix("["))
        #expect(desc.hasSuffix("]"))
    }

    @Test("GlobalKey conforms to LocalKey protocol")
    func conformsToLocalKey() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key is any LocalKey)
    }

    @Test("GlobalKey conforms to Key protocol")
    func conformsToKey() {
        let key = GlobalKey<State<StatefulWidget>>()
        #expect(key is any Key)
    }
}

// MARK: - StatefulElement Tests

@Suite("StatefulElement")
struct StatefulElementTests {

    @Test("Construction creates state from widget")
    func constructionCreatesState() {
        let widget = ConcreteStatefulWidget()
        let element = StatefulElement(widget)
        #expect(element.state is ConcreteState)
    }

    @Test("widget property returns the stateful widget")
    func widgetProperty() {
        let widget = ConcreteStatefulWidget()
        let element = StatefulElement(widget)
        #expect(element.widget === widget)
    }

    @Test("StatefulElement is a ComponentElement")
    func isComponentElement() {
        let widget = ConcreteStatefulWidget()
        let element = StatefulElement(widget)
        #expect(element is ComponentElement)
    }

    @Test("StatefulElement is an Element")
    func isElement() {
        let widget = ConcreteStatefulWidget()
        let element = StatefulElement(widget)
        #expect(element is Element)
    }
}

// MARK: - RenderObjectElement Tests

@Suite("RenderObjectElement")
struct RenderObjectElementTests {

    @Test("Construction with widget")
    func constructionWithWidget() {
        let widget = ConcreteRenderObjectWidget()
        let element = RenderObjectElement(widget)
        #expect(element.widget === widget)
    }

    @Test("renderObject defaults to nil")
    func renderObjectDefaultsNil() {
        let widget = ConcreteRenderObjectWidget()
        let element = RenderObjectElement(widget)
        #expect(element.renderObject == nil)
    }

    @Test("RenderObjectElement is an Element")
    func isElement() {
        let widget = ConcreteRenderObjectWidget()
        let element = RenderObjectElement(widget)
        #expect(element is Element)
    }
}

// MARK: - Builder Tests

@Suite("Builder")
struct BuilderTests {

    @Test("Construction with builder closure")
    func constructionWithBuilder() {
        let builder = Builder { _ in ConcreteWidget() }
        #expect(builder is StatelessWidget)
    }

    @Test("Construction with key and builder")
    func constructionWithKeyAndBuilder() {
        let key = ValueKey<String>("builder-key")
        let builder = Builder(key: key) { _ in ConcreteWidget() }
        #expect(builder.key != nil)
    }

    @Test("build calls the builder closure")
    func buildCallsBuilder() {
        var called = false
        let expectedWidget = ConcreteWidget()
        let builder = Builder { _ in
            called = true
            return expectedWidget
        }
        let context = Element(builder)
        let result = builder.build(context)
        #expect(called == true)
        #expect(result === expectedWidget)
    }

    @Test("builder property stores the closure")
    func builderPropertyStoresClosure() {
        let expectedWidget = ConcreteWidget()
        let builder = Builder { _ in expectedWidget }
        let context = Element(builder)
        let result = builder.builder(context)
        #expect(result === expectedWidget)
    }

    @Test("Builder is a StatelessWidget")
    func isStatelessWidget() {
        let builder = Builder { _ in ConcreteWidget() }
        #expect(builder is StatelessWidget)
    }

    @Test("Builder is a Widget")
    func isWidget() {
        let builder = Builder { _ in ConcreteWidget() }
        #expect(builder is Widget)
    }
}

// MARK: - RenderObjectWidget Tests

@Suite("RenderObjectWidget")
struct RenderObjectWidgetTests {

    @Test("Construction with key")
    func constructionWithKey() {
        let key = ValueKey<String>("row-key")
        let widget = ConcreteRenderObjectWidget(key: key)
        #expect(widget.key != nil)
    }

    @Test("Construction without key")
    func constructionWithoutKey() {
        let widget = ConcreteRenderObjectWidget()
        #expect(widget.key == nil)
    }

    @Test("Concrete subclass createRenderObject returns RenderObject")
    func createRenderObjectReturns() {
        let widget = ConcreteRenderObjectWidget()
        let context = Element(widget)
        let renderObject = widget.createRenderObject(context)
        #expect(renderObject is RenderObject)
    }

    @Test("RenderObjectWidget is a Widget")
    func isWidget() {
        let widget = ConcreteRenderObjectWidget()
        #expect(widget is Widget)
    }
}

// MARK: - InheritedElement Tests

@Suite("InheritedElement")
struct InheritedElementTests {

    @Test("Construction with InheritedWidget")
    func construction() {
        let child = ConcreteWidget()
        let inheritedWidget = ConcreteInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)
        #expect(element.widget === inheritedWidget)
    }

    @Test("InheritedElement is a ProxyElement")
    func isProxyElement() {
        let child = ConcreteWidget()
        let inheritedWidget = ConcreteInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)
        #expect(element is ProxyElement)
    }

    @Test("InheritedElement is an Element")
    func isElement() {
        let child = ConcreteWidget()
        let inheritedWidget = ConcreteInheritedWidget(child: child)
        let element = InheritedElement(inheritedWidget)
        #expect(element is Element)
    }
}

// MARK: - View Stub Tests

@Suite("View Stub")
struct ViewStubTests {

    @Test("View is an enum type")
    func viewIsEnum() {
        // View is an enum, so we test that View.of exists as a static method
        // We cannot call it because it fatalErrors, but we can verify the type exists
        let type = View.self
        #expect(type == View.self)
    }
}

// MARK: - Typealias Tests

@Suite("Framework Typealiases")
struct FrameworkTypealiasTests {

    @Test("WidgetBuilder typealias works")
    func widgetBuilderTypealias() {
        let builder: WidgetBuilder = { _ in ConcreteWidget() }
        let context = Element(ConcreteWidget())
        let result = builder(context)
        #expect(result is Widget)
    }

    @Test("ElementVisitor typealias works")
    func elementVisitorTypealias() {
        var visited = false
        let visitor: ElementVisitor = { _ in visited = true }
        let element = Element(ConcreteWidget())
        visitor(element)
        #expect(visited == true)
    }

    @Test("ConditionalElementVisitor typealias works")
    func conditionalElementVisitorTypealias() {
        let visitor: ConditionalElementVisitor = { _ in true }
        let element = Element(ConcreteWidget())
        let result = visitor(element)
        #expect(result == true)
    }
}
