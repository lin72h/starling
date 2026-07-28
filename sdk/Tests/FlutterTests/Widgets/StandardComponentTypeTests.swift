// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for StandardComponentType migrated from standard_component_type.dart.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/standard_component_type.dart`
final class StandardComponentTypeTests: XCTestCase {

    // MARK: - Case Existence Tests

    /// Test that all four standard component type cases exist.
    func testAllCasesExist() {
        let backButton: StandardComponentType = .backButton
        let closeButton: StandardComponentType = .closeButton
        let moreButton: StandardComponentType = .moreButton
        let drawerButton: StandardComponentType = .drawerButton

        XCTAssertNotNil(backButton)
        XCTAssertNotNil(closeButton)
        XCTAssertNotNil(moreButton)
        XCTAssertNotNil(drawerButton)
    }

    // MARK: - Key Property Tests

    /// Test that each case returns a ValueKey wrapping that case.
    func testKeyPropertyReturnsValueKey() {
        let backKey = StandardComponentType.backButton.key
        XCTAssertTrue(type(of: backKey) == ValueKey<StandardComponentType>.self)

        let closeKey = StandardComponentType.closeButton.key
        XCTAssertTrue(type(of: closeKey) == ValueKey<StandardComponentType>.self)

        let moreKey = StandardComponentType.moreButton.key
        XCTAssertTrue(type(of: moreKey) == ValueKey<StandardComponentType>.self)

        let drawerKey = StandardComponentType.drawerButton.key
        XCTAssertTrue(type(of: drawerKey) == ValueKey<StandardComponentType>.self)
    }

    // MARK: - Key Equality Tests

    /// Test that the same case produces equal keys.
    func testKeyEqualityForSameCase() {
        XCTAssertEqual(
            StandardComponentType.backButton.key,
            StandardComponentType.backButton.key
        )
        XCTAssertEqual(
            StandardComponentType.closeButton.key,
            StandardComponentType.closeButton.key
        )
        XCTAssertEqual(
            StandardComponentType.moreButton.key,
            StandardComponentType.moreButton.key
        )
        XCTAssertEqual(
            StandardComponentType.drawerButton.key,
            StandardComponentType.drawerButton.key
        )
    }

    /// Test that different cases produce different keys.
    func testKeyInequalityForDifferentCases() {
        let allCases: [StandardComponentType] = [.backButton, .closeButton, .moreButton, .drawerButton]

        for i in 0..<allCases.count {
            for j in (i + 1)..<allCases.count {
                XCTAssertNotEqual(
                    allCases[i].key,
                    allCases[j].key,
                    "\(allCases[i]) and \(allCases[j]) should produce different keys"
                )
            }
        }
    }

    // MARK: - Hashable Tests

    /// Test that StandardComponentType can be used in a Set with all 4 cases distinct.
    func testHashableInSet() {
        let set: Set<StandardComponentType> = [.backButton, .closeButton, .moreButton, .drawerButton]
        XCTAssertEqual(set.count, 4)
        XCTAssertTrue(set.contains(.backButton))
        XCTAssertTrue(set.contains(.closeButton))
        XCTAssertTrue(set.contains(.moreButton))
        XCTAssertTrue(set.contains(.drawerButton))
    }

    /// Test that the same case produces the same hash value.
    func testSameCaseProducesSameHash() {
        let hash1 = StandardComponentType.backButton.hashValue
        let hash2 = StandardComponentType.backButton.hashValue
        XCTAssertEqual(hash1, hash2)

        let hash3 = StandardComponentType.closeButton.hashValue
        let hash4 = StandardComponentType.closeButton.hashValue
        XCTAssertEqual(hash3, hash4)

        let hash5 = StandardComponentType.moreButton.hashValue
        let hash6 = StandardComponentType.moreButton.hashValue
        XCTAssertEqual(hash5, hash6)

        let hash7 = StandardComponentType.drawerButton.hashValue
        let hash8 = StandardComponentType.drawerButton.hashValue
        XCTAssertEqual(hash7, hash8)
    }

    // MARK: - Equatable Tests

    /// Test that same cases are equal.
    func testEquatableSameCasesAreEqual() {
        XCTAssertEqual(StandardComponentType.backButton, StandardComponentType.backButton)
        XCTAssertEqual(StandardComponentType.closeButton, StandardComponentType.closeButton)
        XCTAssertEqual(StandardComponentType.moreButton, StandardComponentType.moreButton)
        XCTAssertEqual(StandardComponentType.drawerButton, StandardComponentType.drawerButton)
    }

    /// Test that different cases are not equal.
    func testEquatableDifferentCasesAreNotEqual() {
        XCTAssertNotEqual(StandardComponentType.backButton, StandardComponentType.closeButton)
        XCTAssertNotEqual(StandardComponentType.backButton, StandardComponentType.moreButton)
        XCTAssertNotEqual(StandardComponentType.backButton, StandardComponentType.drawerButton)
        XCTAssertNotEqual(StandardComponentType.closeButton, StandardComponentType.moreButton)
        XCTAssertNotEqual(StandardComponentType.closeButton, StandardComponentType.drawerButton)
        XCTAssertNotEqual(StandardComponentType.moreButton, StandardComponentType.drawerButton)
    }

    // MARK: - Key Value Extraction Tests

    /// Test that ValueKey.value matches the original case.
    func testKeyValueExtraction() {
        XCTAssertEqual(StandardComponentType.backButton.key.value, .backButton)
        XCTAssertEqual(StandardComponentType.closeButton.key.value, .closeButton)
        XCTAssertEqual(StandardComponentType.moreButton.key.value, .moreButton)
        XCTAssertEqual(StandardComponentType.drawerButton.key.value, .drawerButton)
    }
}
