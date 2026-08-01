// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for `SemanticsSortKey` and `OrdinalSortKey`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart:500-558`
final class SemanticsSortKeyTests: XCTestCase {

    // MARK: - OrdinalSortKey Construction Tests

    /// Test OrdinalSortKey construction with order only.
    func testOrdinalSortKeyConstructionOrderOnly() {
        let key = OrdinalSortKey(1.0)
        XCTAssertEqual(key.order, 1.0)
        XCTAssertNil(key.name)
    }

    /// Test OrdinalSortKey construction with order and name.
    func testOrdinalSortKeyConstructionWithName() {
        let key = OrdinalSortKey(2.5, name: "group")
        XCTAssertEqual(key.order, 2.5)
        XCTAssertEqual(key.name, "group")
    }

    // MARK: - OrdinalSortKey Comparison (Same Names)

    /// Test OrdinalSortKey compares correctly when names are the same.
    ///
    /// **Dart Test:** `semantics_test.dart:508-531`
    func testOrdinalSortKeyComparesCorrectlyWithSameNames() {
        // (OrdinalSortKey(0.0), OrdinalSortKey(0.0)) -> 0
        XCTAssertEqual(OrdinalSortKey(0.0).compareTo(OrdinalSortKey(0.0)), 0)

        // (OrdinalSortKey(0.0), OrdinalSortKey(1.0)) -> -1
        XCTAssertEqual(OrdinalSortKey(0.0).compareTo(OrdinalSortKey(1.0)), -1)

        // (OrdinalSortKey(1.0), OrdinalSortKey(0.0)) -> 1
        XCTAssertEqual(OrdinalSortKey(1.0).compareTo(OrdinalSortKey(0.0)), 1)

        // (OrdinalSortKey(1.0), OrdinalSortKey(1.0)) -> 0
        XCTAssertEqual(OrdinalSortKey(1.0).compareTo(OrdinalSortKey(1.0)), 0)

        // Named keys with same name
        // (OrdinalSortKey(0.0, name: 'a'), OrdinalSortKey(0.0, name: 'a')) -> 0
        XCTAssertEqual(OrdinalSortKey(0.0, name: "a").compareTo(OrdinalSortKey(0.0, name: "a")), 0)

        // (OrdinalSortKey(0.0, name: 'a'), OrdinalSortKey(1.0, name: 'a')) -> -1
        XCTAssertEqual(OrdinalSortKey(0.0, name: "a").compareTo(OrdinalSortKey(1.0, name: "a")), -1)

        // (OrdinalSortKey(1.0, name: 'a'), OrdinalSortKey(0.0, name: 'a')) -> 1
        XCTAssertEqual(OrdinalSortKey(1.0, name: "a").compareTo(OrdinalSortKey(0.0, name: "a")), 1)

        // (OrdinalSortKey(1.0, name: 'a'), OrdinalSortKey(1.0, name: 'a')) -> 0
        XCTAssertEqual(OrdinalSortKey(1.0, name: "a").compareTo(OrdinalSortKey(1.0, name: "a")), 0)
    }

    // MARK: - OrdinalSortKey Comparison (Different Names)

    /// Test OrdinalSortKey compares correctly when names are different.
    /// nil name comes before a named key; named keys are sorted alphabetically.
    ///
    /// **Dart Test:** `semantics_test.dart:533-558`
    func testOrdinalSortKeyComparesCorrectlyWithDifferentNames() {
        // nil name vs named: nil comes first (-1)
        XCTAssertEqual(OrdinalSortKey(0.0).compareTo(OrdinalSortKey(0.0, name: "bar")), -1)
        XCTAssertEqual(OrdinalSortKey(0.0).compareTo(OrdinalSortKey(1.0, name: "bar")), -1)
        XCTAssertEqual(OrdinalSortKey(1.0).compareTo(OrdinalSortKey(0.0, name: "bar")), -1)
        XCTAssertEqual(OrdinalSortKey(1.0).compareTo(OrdinalSortKey(1.0, name: "bar")), -1)

        // Named vs nil: named comes after (1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "foo").compareTo(OrdinalSortKey(0.0)), 1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "foo").compareTo(OrdinalSortKey(1.0)), 1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "foo").compareTo(OrdinalSortKey(0.0)), 1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "foo").compareTo(OrdinalSortKey(1.0)), 1)

        // "foo" vs "bar": "foo" > "bar" alphabetically, so foo comes after (1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "foo").compareTo(OrdinalSortKey(0.0, name: "bar")), 1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "foo").compareTo(OrdinalSortKey(1.0, name: "bar")), 1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "foo").compareTo(OrdinalSortKey(0.0, name: "bar")), 1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "foo").compareTo(OrdinalSortKey(1.0, name: "bar")), 1)

        // "bar" vs "foo": "bar" < "foo" alphabetically, so bar comes before (-1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "bar").compareTo(OrdinalSortKey(0.0, name: "foo")), -1)
        XCTAssertEqual(OrdinalSortKey(0.0, name: "bar").compareTo(OrdinalSortKey(1.0, name: "foo")), -1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "bar").compareTo(OrdinalSortKey(0.0, name: "foo")), -1)
        XCTAssertEqual(OrdinalSortKey(1.0, name: "bar").compareTo(OrdinalSortKey(1.0, name: "foo")), -1)
    }

    // MARK: - Comparable Conformance Tests

    /// Test the `<` operator.
    func testLessThanOperator() {
        let key1 = OrdinalSortKey(1.0)
        let key2 = OrdinalSortKey(2.0)
        XCTAssertTrue(key1 < key2)
        XCTAssertFalse(key2 < key1)
    }

    /// Test the `==` operator for equal keys.
    func testEqualOperator() {
        let key1 = OrdinalSortKey(1.0)
        let key2 = OrdinalSortKey(1.0)
        XCTAssertTrue(key1 == key2)
    }

    /// Test the `<` operator with names: nil name before named.
    func testLessThanOperatorNilNameBeforeNamed() {
        let unnamed = OrdinalSortKey(0.0)
        let named = OrdinalSortKey(0.0, name: "z")
        XCTAssertTrue(unnamed < named)
        XCTAssertFalse(named < unnamed)
    }

    /// Test sorting an array of OrdinalSortKeys.
    func testSortingArray() {
        let keys = [
            OrdinalSortKey(3.0),
            OrdinalSortKey(1.0),
            OrdinalSortKey(2.0),
        ]
        let sorted = keys.sorted()
        XCTAssertEqual(sorted[0].order, 1.0)
        XCTAssertEqual(sorted[1].order, 2.0)
        XCTAssertEqual(sorted[2].order, 3.0)
    }

    /// Test sorting with fractional orders.
    func testSortingWithFractionalOrders() {
        let keys = [
            OrdinalSortKey(2.0),
            OrdinalSortKey(1.5),
            OrdinalSortKey(1.0),
        ]
        let sorted = keys.sorted()
        XCTAssertEqual(sorted[0].order, 1.0)
        XCTAssertEqual(sorted[1].order, 1.5)
        XCTAssertEqual(sorted[2].order, 2.0)
    }
}
