// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for InheritedModel and InheritedModelElement.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/inherited_model_test.dart`
final class InheritedModelTests: XCTestCase {

    // MARK: - Test Helpers

    /// A minimal child widget for constructing InheritedModel instances.
    private class DummyWidget: Widget {
        init() { super.init(key: nil) }
        override func createElement() -> Element {
            return Element(self)
        }
    }

    /// Concrete InheritedModel subclass with String aspects for testing.
    private class TestModel: InheritedModel<String> {
        var changedAspects: Set<String>

        init(key: (any Key)? = nil, child: Widget, changedAspects: Set<String> = []) {
            self.changedAspects = changedAspects
            super.init(key: key, child: child)
        }

        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return true
        }

        override func updateShouldNotifyDependent(
            _ oldWidget: InheritedModel<String>,
            dependencies: Set<String>
        ) -> Bool {
            return !changedAspects.isDisjoint(with: dependencies)
        }
    }

    /// Concrete InheritedModel subclass that restricts supported aspects.
    private class RestrictedModel: InheritedModel<String> {
        let supportedAspects: Set<String>

        init(child: Widget, supportedAspects: Set<String>) {
            self.supportedAspects = supportedAspects
            super.init(child: child)
        }

        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return true
        }

        override func updateShouldNotifyDependent(
            _ oldWidget: InheritedModel<String>,
            dependencies: Set<String>
        ) -> Bool {
            return true
        }

        override func isSupportedAspect(_ aspect: AnyHashable) -> Bool {
            guard let stringAspect = aspect.base as? String else { return false }
            return supportedAspects.contains(stringAspect)
        }
    }

    /// InheritedModel with Int aspects for testing generic type parameter.
    private class IntModel: InheritedModel<Int> {
        init(child: Widget) {
            super.init(child: child)
        }

        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return true
        }

        override func updateShouldNotifyDependent(
            _ oldWidget: InheritedModel<Int>,
            dependencies: Set<Int>
        ) -> Bool {
            return true
        }
    }

    // MARK: - Constructor

    func testConstructorStoresChild() {
        let child = DummyWidget()
        let model = TestModel(child: child)

        XCTAssertTrue(model.child === child)
    }

    func testConstructorWithKey() {
        let child = DummyWidget()
        let key = ValueKey("test-key")
        let model = TestModel(key: key, child: child)

        XCTAssertNotNil(model.key)
    }

    func testConstructorWithoutKey() {
        let child = DummyWidget()
        let model = TestModel(child: child)

        XCTAssertNil(model.key)
    }

    // MARK: - Inheritance hierarchy

    func testInheritedModelIsInheritedWidget() {
        let child = DummyWidget()
        let model = TestModel(child: child)

        XCTAssertTrue(model is InheritedWidget)
        XCTAssertTrue(model is ProxyWidget)
        XCTAssertTrue(model is Widget)
    }

    // MARK: - isSupportedAspect default

    func testIsSupportedAspectDefaultReturnsTrue() {
        let child = DummyWidget()
        let model = TestModel(child: child)

        // Default implementation returns true for any aspect
        XCTAssertTrue(model.isSupportedAspect(AnyHashable("color")))
        XCTAssertTrue(model.isSupportedAspect(AnyHashable("size")))
        XCTAssertTrue(model.isSupportedAspect(AnyHashable("")))
        XCTAssertTrue(model.isSupportedAspect(AnyHashable(42)))
    }

    // MARK: - isSupportedAspect overridden

    func testIsSupportedAspectOverriddenFilters() {
        let child = DummyWidget()
        let model = RestrictedModel(child: child, supportedAspects: ["color", "size"])

        XCTAssertTrue(model.isSupportedAspect(AnyHashable("color")))
        XCTAssertTrue(model.isSupportedAspect(AnyHashable("size")))
        XCTAssertFalse(model.isSupportedAspect(AnyHashable("weight")))
        XCTAssertFalse(model.isSupportedAspect(AnyHashable("unknown")))
    }

    // MARK: - createModelElement

    func testCreateModelElementReturnsInheritedModelElement() {
        let child = DummyWidget()
        let model = TestModel(child: child)
        let element = model.createModelElement()

        XCTAssertTrue(element is InheritedModelElement<String>)
        XCTAssertTrue(element is InheritedElement)
    }

    func testCreateModelElementWithIntAspect() {
        let child = DummyWidget()
        let model = IntModel(child: child)
        let element = model.createModelElement()

        XCTAssertTrue(element is InheritedModelElement<Int>)
        XCTAssertTrue(element is InheritedElement)
    }

    // MARK: - updateShouldNotifyDependent

    func testUpdateShouldNotifyDependentMatchingAspect() {
        let child = DummyWidget()
        let oldModel = TestModel(child: child, changedAspects: [])
        let newModel = TestModel(child: child, changedAspects: ["color"])

        // Dependencies include "color", which is in changedAspects
        let result = newModel.updateShouldNotifyDependent(oldModel, dependencies: ["color", "size"])
        XCTAssertTrue(result)
    }

    func testUpdateShouldNotifyDependentNoMatchingAspect() {
        let child = DummyWidget()
        let oldModel = TestModel(child: child, changedAspects: [])
        let newModel = TestModel(child: child, changedAspects: ["weight"])

        // Dependencies don't include "weight"
        let result = newModel.updateShouldNotifyDependent(oldModel, dependencies: ["color", "size"])
        XCTAssertFalse(result)
    }

    func testUpdateShouldNotifyDependentEmptyChangedAspects() {
        let child = DummyWidget()
        let oldModel = TestModel(child: child, changedAspects: [])
        let newModel = TestModel(child: child, changedAspects: [])

        let result = newModel.updateShouldNotifyDependent(oldModel, dependencies: ["color"])
        XCTAssertFalse(result)
    }

    func testUpdateShouldNotifyDependentEmptyDependencies() {
        let child = DummyWidget()
        let oldModel = TestModel(child: child, changedAspects: [])
        let newModel = TestModel(child: child, changedAspects: ["color"])

        let result = newModel.updateShouldNotifyDependent(oldModel, dependencies: [])
        XCTAssertFalse(result)
    }

    // MARK: - InheritedModelElement constructor

    func testInheritedModelElementStoresWidget() {
        let child = DummyWidget()
        let model = TestModel(child: child)
        let element = InheritedModelElement<String>(model)

        XCTAssertTrue(element.widget === model)
    }

    // MARK: - updateShouldNotify

    func testUpdateShouldNotifyReturnsTrue() {
        let child = DummyWidget()
        let model1 = TestModel(child: child)
        let model2 = TestModel(child: child)

        // TestModel always returns true from updateShouldNotify
        XCTAssertTrue(model1.updateShouldNotify(model2))
    }

    // MARK: - Generic type parameter

    func testIntModelAspectsWork() {
        let child = DummyWidget()
        let model = IntModel(child: child)

        // Default isSupportedAspect returns true for any aspect
        XCTAssertTrue(model.isSupportedAspect(AnyHashable(1)))
        XCTAssertTrue(model.isSupportedAspect(AnyHashable(999)))
    }
}
