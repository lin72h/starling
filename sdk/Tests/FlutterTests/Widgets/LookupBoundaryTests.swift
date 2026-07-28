// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for the LookupBoundary widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/lookup_boundary.dart`
final class LookupBoundaryTests: XCTestCase {

    // MARK: - Test Helpers

    /// A simple test widget for use in ancestor chains.
    private class TestWidget: Widget {}

    /// A concrete InheritedWidget subclass for testing inherited lookups.
    private class TestInheritedWidget: InheritedWidget {
        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return false
        }
    }

    /// A concrete StatefulWidget for testing ancestor state lookups.
    private class TestStatefulWidget: StatefulWidget {
        override func createState() -> State<StatefulWidget> {
            return TestState()
        }
    }

    /// The state associated with TestStatefulWidget.
    private class TestState: State<StatefulWidget> {}

    /// A concrete RenderObjectWidget for testing ancestor render object lookups.
    private class TestRenderObjectWidget: RenderObjectWidget {
        override func createRenderObject(_ context: any BuildContext) -> RenderObject {
            return TestRenderObject()
        }
    }

    /// A concrete RenderObject for testing.
    private class TestRenderObject: RenderObject {}

    /// A mock element that supports configurable ancestor and child chains.
    ///
    /// This element stores a list of ancestor elements and child elements,
    /// and can return configurable results for inherited widget lookups.
    private class MockElement: Element {
        var ancestors: [Element] = []
        var children: [Element] = []
        var inheritedElements: [String: InheritedElement] = [:]

        init() { super.init(Widget()) }

        override func visitAncestorElements(_ visitor: (Element) -> Bool) {
            for ancestor in ancestors {
                if !visitor(ancestor) { return }
            }
        }

        override func visitChildElements(_ visitor: (Element) -> Void) {
            for child in children {
                visitor(child)
            }
        }

        override func getElementForInheritedWidgetOfExactType<T: InheritedWidget>(
            _ type: T.Type
        ) -> InheritedElement? {
            let key = String(describing: type)
            return inheritedElements[key]
        }

        override func dependOnInheritedWidgetOfExactType<T: InheritedWidget>(
            _ type: T.Type
        ) -> T? {
            let key = String(describing: type)
            return inheritedElements[key]?.widget as? T
        }

        override func dependOnInheritedElement(
            _ ancestor: InheritedElement,
            aspect: AnyHashable? = nil
        ) -> InheritedWidget {
            return ancestor.widget as! InheritedWidget
        }
    }

    // MARK: - Constructor Tests

    func testConstructorCreatesInstance() {
        let child = Widget()
        let boundary = LookupBoundary(child: child)
        XCTAssertNotNil(boundary)
    }

    func testConstructorStoresChild() {
        let child = Widget()
        let boundary = LookupBoundary(child: child)
        XCTAssertTrue(boundary.child === child)
    }

    func testConstructorKeyIsNilByDefault() {
        let boundary = LookupBoundary(child: Widget())
        XCTAssertNil(boundary.key)
    }

    func testConstructorWithKey() {
        let key = ValueKey(42)
        let boundary = LookupBoundary(key: key, child: Widget())
        XCTAssertNotNil(boundary.key)
    }

    // MARK: - Inheritance Tests

    func testIsInheritedWidget() {
        let boundary = LookupBoundary(child: Widget())
        XCTAssertTrue(boundary is InheritedWidget)
    }

    func testIsProxyWidget() {
        let boundary = LookupBoundary(child: Widget())
        XCTAssertTrue(boundary is ProxyWidget)
    }

    func testIsWidget() {
        let boundary = LookupBoundary(child: Widget())
        XCTAssertTrue(boundary is Widget)
    }

    // MARK: - updateShouldNotify Tests

    func testUpdateShouldNotifyAlwaysReturnsFalse() {
        let boundary1 = LookupBoundary(child: Widget())
        let boundary2 = LookupBoundary(child: Widget())
        XCTAssertFalse(boundary1.updateShouldNotify(boundary2))
    }

    func testUpdateShouldNotifyReturnsFalseForSameInstance() {
        let boundary = LookupBoundary(child: Widget())
        XCTAssertFalse(boundary.updateShouldNotify(boundary))
    }

    func testUpdateShouldNotifyReturnsFalseForDifferentChild() {
        let boundary1 = LookupBoundary(child: Widget())
        let boundary2 = LookupBoundary(child: TestWidget())
        XCTAssertFalse(boundary1.updateShouldNotify(boundary2))
    }

    func testUpdateShouldNotifyReturnsFalseForDifferentKey() {
        let boundary1 = LookupBoundary(key: ValueKey(1), child: Widget())
        let boundary2 = LookupBoundary(key: ValueKey(2), child: Widget())
        XCTAssertFalse(boundary1.updateShouldNotify(boundary2))
    }

    func testUpdateShouldNotifyReturnsFalseForPlainInheritedWidget() {
        let boundary = LookupBoundary(child: Widget())
        let otherWidget = InheritedWidget(child: Widget())
        XCTAssertFalse(boundary.updateShouldNotify(otherWidget))
    }

    // MARK: - getElementForInheritedWidgetOfExactType Tests

    func testGetElementReturnsNilWhenNoCandidate() {
        let context = MockElement()
        // No inherited elements registered
        let result = LookupBoundary.getElementForInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        XCTAssertNil(result)
    }

    func testGetElementReturnsCandidateWhenNoBoundary() {
        let context = MockElement()
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 1
        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        // No LookupBoundary registered

        let result = LookupBoundary.getElementForInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        XCTAssertTrue(result === inheritedElement)
    }

    func testGetElementReturnsCandidateWhenBoundaryIsAboveCandidate() {
        let context = MockElement()

        // Register the inherited widget at depth 5
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 5

        // Register a LookupBoundary at depth 3 (above / lower depth than candidate)
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryElement = InheritedElement(boundaryWidget)
        boundaryElement.depth = 3

        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        context.inheritedElements[String(describing: LookupBoundary.self)] = boundaryElement

        let result = LookupBoundary.getElementForInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        // Boundary depth (3) is NOT > candidate depth (5), so candidate is returned
        XCTAssertTrue(result === inheritedElement)
    }

    func testGetElementReturnsNilWhenBoundaryIsBelowCandidate() {
        let context = MockElement()

        // Register the inherited widget at depth 2
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 2

        // Register a LookupBoundary at depth 5 (below / higher depth than candidate)
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryElement = InheritedElement(boundaryWidget)
        boundaryElement.depth = 5

        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        context.inheritedElements[String(describing: LookupBoundary.self)] = boundaryElement

        let result = LookupBoundary.getElementForInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        // Boundary depth (5) > candidate depth (2), so nil is returned
        XCTAssertNil(result)
    }

    func testGetElementReturnsCandidateWhenBoundaryAtSameDepth() {
        let context = MockElement()

        // Register the inherited widget at depth 3
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 3

        // Register a LookupBoundary at depth 3 (same depth)
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryElement = InheritedElement(boundaryWidget)
        boundaryElement.depth = 3

        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        context.inheritedElements[String(describing: LookupBoundary.self)] = boundaryElement

        let result = LookupBoundary.getElementForInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        // Boundary depth (3) is NOT > candidate depth (3), so candidate is returned
        XCTAssertTrue(result === inheritedElement)
    }

    // MARK: - getInheritedWidgetOfExactType Tests

    func testGetInheritedWidgetReturnsNilWhenNoCandidate() {
        let context = MockElement()
        let result: TestInheritedWidget? = LookupBoundary.getInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        XCTAssertNil(result)
    }

    func testGetInheritedWidgetReturnsWidgetWhenNoBoundary() {
        let context = MockElement()
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 1
        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement

        let result: TestInheritedWidget? = LookupBoundary.getInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        XCTAssertTrue(result === inheritedWidget)
    }

    func testGetInheritedWidgetReturnsNilWhenHiddenByBoundary() {
        let context = MockElement()

        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 2

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryElement = InheritedElement(boundaryWidget)
        boundaryElement.depth = 5

        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        context.inheritedElements[String(describing: LookupBoundary.self)] = boundaryElement

        let result: TestInheritedWidget? = LookupBoundary.getInheritedWidgetOfExactType(
            TestInheritedWidget.self,
            context
        )
        XCTAssertNil(result)
    }

    // MARK: - dependOnInheritedWidgetOfExactType Tests

    func testDependOnReturnsNilWhenNoCandidate() {
        let context = MockElement()
        let result: TestInheritedWidget? = LookupBoundary.dependOnInheritedWidgetOfExactType(
            context
        )
        XCTAssertNil(result)
    }

    func testDependOnReturnsWidgetWhenNoBoundary() {
        let context = MockElement()
        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 1
        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement

        let result: TestInheritedWidget? = LookupBoundary.dependOnInheritedWidgetOfExactType(
            context
        )
        XCTAssertTrue(result === inheritedWidget)
    }

    func testDependOnReturnsNilWhenHiddenByBoundary() {
        let context = MockElement()

        let inheritedWidget = TestInheritedWidget(child: Widget())
        let inheritedElement = InheritedElement(inheritedWidget)
        inheritedElement.depth = 2

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryElement = InheritedElement(boundaryWidget)
        boundaryElement.depth = 5

        context.inheritedElements[String(describing: TestInheritedWidget.self)] = inheritedElement
        context.inheritedElements[String(describing: LookupBoundary.self)] = boundaryElement

        let result: TestInheritedWidget? = LookupBoundary.dependOnInheritedWidgetOfExactType(
            context
        )
        XCTAssertNil(result)
    }

    // MARK: - findAncestorWidgetOfExactType Tests

    func testFindAncestorWidgetReturnsNilWhenNoAncestors() {
        let context = MockElement()
        let result = LookupBoundary.findAncestorWidgetOfExactType(TestWidget.self, context)
        XCTAssertNil(result)
    }

    func testFindAncestorWidgetReturnsMatchingAncestor() {
        let context = MockElement()
        let testWidget = TestWidget()
        let ancestor = MockElement()
        ancestor.widget = testWidget
        context.ancestors = [ancestor]

        let result = LookupBoundary.findAncestorWidgetOfExactType(TestWidget.self, context)
        XCTAssertTrue(result === testWidget)
    }

    func testFindAncestorWidgetReturnsNilWhenHiddenByBoundary() {
        let context = MockElement()

        // First ancestor is a LookupBoundary
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        // Second ancestor is the target (beyond the boundary)
        let testWidget = TestWidget()
        let targetAncestor = MockElement()
        targetAncestor.widget = testWidget

        context.ancestors = [boundaryAncestor, targetAncestor]

        let result = LookupBoundary.findAncestorWidgetOfExactType(TestWidget.self, context)
        XCTAssertNil(result)
    }

    func testFindAncestorWidgetReturnsWidgetBeforeBoundary() {
        let context = MockElement()

        // First ancestor is the target (before the boundary)
        let testWidget = TestWidget()
        let targetAncestor = MockElement()
        targetAncestor.widget = testWidget

        // Second ancestor is a LookupBoundary
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        context.ancestors = [targetAncestor, boundaryAncestor]

        let result = LookupBoundary.findAncestorWidgetOfExactType(TestWidget.self, context)
        XCTAssertTrue(result === testWidget)
    }

    // MARK: - findAncestorStateOfType Tests

    func testFindAncestorStateReturnsNilWhenNoAncestors() {
        let context = MockElement()
        let result = LookupBoundary.findAncestorStateOfType(TestState.self, context)
        XCTAssertNil(result)
    }

    func testFindAncestorStateReturnsMatchingState() {
        let context = MockElement()

        let statefulWidget = TestStatefulWidget()
        let statefulElement = StatefulElement(statefulWidget)
        context.ancestors = [statefulElement]

        let result = LookupBoundary.findAncestorStateOfType(TestState.self, context)
        XCTAssertNotNil(result)
        XCTAssertTrue(result is TestState)
    }

    func testFindAncestorStateReturnsNilWhenHiddenByBoundary() {
        let context = MockElement()

        // Boundary is closer
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        // Target state is beyond the boundary
        let statefulWidget = TestStatefulWidget()
        let statefulElement = StatefulElement(statefulWidget)

        context.ancestors = [boundaryAncestor, statefulElement]

        let result = LookupBoundary.findAncestorStateOfType(TestState.self, context)
        XCTAssertNil(result)
    }

    // MARK: - findRootAncestorStateOfType Tests

    func testFindRootAncestorStateReturnsNilWhenNoAncestors() {
        let context = MockElement()
        let result = LookupBoundary.findRootAncestorStateOfType(TestState.self, context)
        XCTAssertNil(result)
    }

    func testFindRootAncestorStateReturnsFurthestMatch() {
        let context = MockElement()

        let statefulWidget1 = TestStatefulWidget()
        let statefulElement1 = StatefulElement(statefulWidget1)

        let statefulWidget2 = TestStatefulWidget()
        let statefulElement2 = StatefulElement(statefulWidget2)

        // element1 is closer, element2 is farther (root)
        context.ancestors = [statefulElement1, statefulElement2]

        let result = LookupBoundary.findRootAncestorStateOfType(TestState.self, context)
        // Should return the furthest (root) match
        XCTAssertTrue(result === statefulElement2.state as? TestState)
    }

    func testFindRootAncestorStateStopsAtBoundary() {
        let context = MockElement()

        let statefulWidget1 = TestStatefulWidget()
        let statefulElement1 = StatefulElement(statefulWidget1)

        // Boundary stops the search
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        // This one is beyond the boundary
        let statefulWidget2 = TestStatefulWidget()
        let statefulElement2 = StatefulElement(statefulWidget2)

        context.ancestors = [statefulElement1, boundaryAncestor, statefulElement2]

        let result = LookupBoundary.findRootAncestorStateOfType(TestState.self, context)
        // Should return only the one before the boundary
        XCTAssertTrue(result === statefulElement1.state as? TestState)
    }

    // MARK: - findAncestorRenderObjectOfType Tests

    func testFindAncestorRenderObjectReturnsNilWhenNoAncestors() {
        let context = MockElement()
        let result = LookupBoundary.findAncestorRenderObjectOfType(TestRenderObject.self, context)
        XCTAssertNil(result)
    }

    func testFindAncestorRenderObjectReturnsMatchingRenderObject() {
        let context = MockElement()

        let renderObjectWidget = TestRenderObjectWidget()
        let renderObjectElement = RenderObjectElement(renderObjectWidget)
        let renderObject = TestRenderObject()
        renderObjectElement.renderObject = renderObject

        context.ancestors = [renderObjectElement]

        let result = LookupBoundary.findAncestorRenderObjectOfType(TestRenderObject.self, context)
        XCTAssertTrue(result === renderObject)
    }

    func testFindAncestorRenderObjectReturnsNilWhenHiddenByBoundary() {
        let context = MockElement()

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        let renderObjectWidget = TestRenderObjectWidget()
        let renderObjectElement = RenderObjectElement(renderObjectWidget)
        renderObjectElement.renderObject = TestRenderObject()

        context.ancestors = [boundaryAncestor, renderObjectElement]

        let result = LookupBoundary.findAncestorRenderObjectOfType(TestRenderObject.self, context)
        XCTAssertNil(result)
    }

    // MARK: - visitAncestorElements Tests

    func testVisitAncestorElementsVisitsAllWithNoBoundary() {
        let context = MockElement()

        let ancestor1 = MockElement()
        ancestor1.widget = TestWidget()
        let ancestor2 = MockElement()
        ancestor2.widget = TestWidget()

        context.ancestors = [ancestor1, ancestor2]

        var visited: [Element] = []
        LookupBoundary.visitAncestorElements(context) { element in
            visited.append(element)
            return true
        }
        XCTAssertEqual(visited.count, 2)
    }

    func testVisitAncestorElementsStopsAtBoundary() {
        let context = MockElement()

        let ancestor1 = MockElement()
        ancestor1.widget = TestWidget()

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        let ancestor2 = MockElement()
        ancestor2.widget = TestWidget()

        context.ancestors = [ancestor1, boundaryAncestor, ancestor2]

        var visited: [Element] = []
        LookupBoundary.visitAncestorElements(context) { element in
            visited.append(element)
            return true
        }
        // Should visit ancestor1 and boundaryAncestor, but stop before ancestor2
        // The boundary element itself IS visited, but the walk stops after it
        XCTAssertEqual(visited.count, 2)
    }

    func testVisitAncestorElementsStopsWhenVisitorReturnsFalse() {
        let context = MockElement()

        let ancestor1 = MockElement()
        ancestor1.widget = TestWidget()
        let ancestor2 = MockElement()
        ancestor2.widget = TestWidget()

        context.ancestors = [ancestor1, ancestor2]

        var visited: [Element] = []
        LookupBoundary.visitAncestorElements(context) { element in
            visited.append(element)
            return false  // stop after first
        }
        XCTAssertEqual(visited.count, 1)
    }

    // MARK: - visitChildElements Tests

    func testVisitChildElementsVisitsNonBoundaryChildren() {
        let context = MockElement()

        let child1 = MockElement()
        child1.widget = TestWidget()
        let child2 = MockElement()
        child2.widget = TestWidget()

        context.children = [child1, child2]

        var visited: [Element] = []
        LookupBoundary.visitChildElements(context) { element in
            visited.append(element)
        }
        XCTAssertEqual(visited.count, 2)
    }

    func testVisitChildElementsSkipsBoundaryChildren() {
        let context = MockElement()

        let child1 = MockElement()
        child1.widget = TestWidget()

        let boundaryChild = MockElement()
        boundaryChild.widget = LookupBoundary(child: Widget())

        let child2 = MockElement()
        child2.widget = TestWidget()

        context.children = [child1, boundaryChild, child2]

        var visited: [Element] = []
        LookupBoundary.visitChildElements(context) { element in
            visited.append(element)
        }
        // The boundary child should be skipped
        XCTAssertEqual(visited.count, 2)
    }

    func testVisitChildElementsVisitsNothingWhenAllAreBoundaries() {
        let context = MockElement()

        let boundaryChild1 = MockElement()
        boundaryChild1.widget = LookupBoundary(child: Widget())
        let boundaryChild2 = MockElement()
        boundaryChild2.widget = LookupBoundary(child: Widget())

        context.children = [boundaryChild1, boundaryChild2]

        var visited: [Element] = []
        LookupBoundary.visitChildElements(context) { element in
            visited.append(element)
        }
        XCTAssertEqual(visited.count, 0)
    }

    // MARK: - debugIsHidingAncestorWidgetOfExactType Tests

    func testDebugIsHidingReturnsFalseWhenNoAncestor() {
        let context = MockElement()
        let result = LookupBoundary.debugIsHidingAncestorWidgetOfExactType(
            TestWidget.self,
            context
        )
        XCTAssertFalse(result)
    }

    func testDebugIsHidingReturnsFalseWhenAncestorWithNoBoundary() {
        let context = MockElement()

        let testWidget = TestWidget()
        let ancestor = MockElement()
        ancestor.widget = testWidget

        context.ancestors = [ancestor]

        let result = LookupBoundary.debugIsHidingAncestorWidgetOfExactType(
            TestWidget.self,
            context
        )
        XCTAssertFalse(result)
    }

    func testDebugIsHidingReturnsTrueWhenBoundaryHidesAncestor() {
        let context = MockElement()

        // Boundary is between context and the target
        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        let testWidget = TestWidget()
        let targetAncestor = MockElement()
        targetAncestor.widget = testWidget

        context.ancestors = [boundaryAncestor, targetAncestor]

        let result = LookupBoundary.debugIsHidingAncestorWidgetOfExactType(
            TestWidget.self,
            context
        )
        XCTAssertTrue(result)
    }

    func testDebugIsHidingReturnsFalseWhenBoundaryIsAfterAncestor() {
        let context = MockElement()

        // Target is found before the boundary
        let testWidget = TestWidget()
        let targetAncestor = MockElement()
        targetAncestor.widget = testWidget

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        context.ancestors = [targetAncestor, boundaryAncestor]

        let result = LookupBoundary.debugIsHidingAncestorWidgetOfExactType(
            TestWidget.self,
            context
        )
        // Ancestor is found, but the boundary is NOT between context and ancestor
        XCTAssertFalse(result)
    }

    // MARK: - debugIsHidingAncestorStateOfType Tests

    func testDebugIsHidingStateReturnsFalseWhenNoAncestor() {
        let context = MockElement()
        let result = LookupBoundary.debugIsHidingAncestorStateOfType(
            TestState.self,
            context
        )
        XCTAssertFalse(result)
    }

    func testDebugIsHidingStateReturnsTrueWhenBoundaryHidesState() {
        let context = MockElement()

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        let statefulWidget = TestStatefulWidget()
        let statefulElement = StatefulElement(statefulWidget)

        context.ancestors = [boundaryAncestor, statefulElement]

        let result = LookupBoundary.debugIsHidingAncestorStateOfType(
            TestState.self,
            context
        )
        XCTAssertTrue(result)
    }

    func testDebugIsHidingStateReturnsFalseWhenStateIsBeforeBoundary() {
        let context = MockElement()

        let statefulWidget = TestStatefulWidget()
        let statefulElement = StatefulElement(statefulWidget)

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        context.ancestors = [statefulElement, boundaryAncestor]

        let result = LookupBoundary.debugIsHidingAncestorStateOfType(
            TestState.self,
            context
        )
        XCTAssertFalse(result)
    }

    // MARK: - debugIsHidingAncestorRenderObjectOfType Tests

    func testDebugIsHidingRenderObjectReturnsFalseWhenNoAncestor() {
        let context = MockElement()
        let result = LookupBoundary.debugIsHidingAncestorRenderObjectOfType(
            TestRenderObject.self,
            context
        )
        XCTAssertFalse(result)
    }

    func testDebugIsHidingRenderObjectReturnsTrueWhenBoundaryHides() {
        let context = MockElement()

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        let renderObjectWidget = TestRenderObjectWidget()
        let renderObjectElement = RenderObjectElement(renderObjectWidget)
        renderObjectElement.renderObject = TestRenderObject()

        context.ancestors = [boundaryAncestor, renderObjectElement]

        let result = LookupBoundary.debugIsHidingAncestorRenderObjectOfType(
            TestRenderObject.self,
            context
        )
        XCTAssertTrue(result)
    }

    func testDebugIsHidingRenderObjectReturnsFalseWhenRenderObjectIsBeforeBoundary() {
        let context = MockElement()

        let renderObjectWidget = TestRenderObjectWidget()
        let renderObjectElement = RenderObjectElement(renderObjectWidget)
        renderObjectElement.renderObject = TestRenderObject()

        let boundaryWidget = LookupBoundary(child: Widget())
        let boundaryAncestor = MockElement()
        boundaryAncestor.widget = boundaryWidget

        context.ancestors = [renderObjectElement, boundaryAncestor]

        let result = LookupBoundary.debugIsHidingAncestorRenderObjectOfType(
            TestRenderObject.self,
            context
        )
        XCTAssertFalse(result)
    }
}
