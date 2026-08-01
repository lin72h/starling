// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for Key types (Key, LocalKey, UniqueKey, ValueKey)
///
/// **Dart Test Source:** `packages/flutter/test/foundation/key_test.dart`
final class KeyTests: XCTestCase {

    // MARK: - UniqueKey Tests

    /// Test that two UniqueKey instances are not equal.
    func testUniqueKeyNotEqualToAnotherUniqueKey() {
        let key1 = UniqueKey()
        let key2 = UniqueKey()
        XCTAssertNotEqual(key1, key2)
    }

    /// Test that a UniqueKey is equal to itself.
    func testUniqueKeyEqualToItself() {
        let key = UniqueKey()
        XCTAssertEqual(key, key)
    }

    /// Test UniqueKey description format.
    func testUniqueKeyDescription() {
        let key = UniqueKey()
        let desc = key.description
        // Description should be in format "[#XXXXX]" where XXXXX is a short hash
        XCTAssertTrue(desc.hasPrefix("[#"))
        XCTAssertTrue(desc.hasSuffix("]"))
    }

    /// Test that UniqueKey hashes are different for different instances.
    func testUniqueKeyHashDifferent() {
        let key1 = UniqueKey()
        let key2 = UniqueKey()
        // While hash collisions are theoretically possible, different
        // UniqueKey instances should generally have different hashes
        XCTAssertNotEqual(key1.hashValue, key2.hashValue)
    }

    /// Test that UniqueKey hash is consistent for the same instance.
    func testUniqueKeyHashConsistent() {
        let key = UniqueKey()
        XCTAssertEqual(key.hashValue, key.hashValue)
    }

    // MARK: - ValueKey Tests

    /// Test ValueKey equality with same String values.
    func testValueKeyStringEquality() {
        let key1 = ValueKey("test")
        let key2 = ValueKey("test")
        XCTAssertEqual(key1, key2)
    }

    /// Test ValueKey inequality with different String values.
    func testValueKeyStringInequality() {
        let key1 = ValueKey("test1")
        let key2 = ValueKey("test2")
        XCTAssertNotEqual(key1, key2)
    }

    /// Test ValueKey equality with same Int values.
    func testValueKeyIntEquality() {
        let key1 = ValueKey(42)
        let key2 = ValueKey(42)
        XCTAssertEqual(key1, key2)
    }

    /// Test ValueKey inequality with different Int values.
    func testValueKeyIntInequality() {
        let key1 = ValueKey(42)
        let key2 = ValueKey(43)
        XCTAssertNotEqual(key1, key2)
    }

    /// Test ValueKey hash equality for same values.
    func testValueKeyHashEquality() {
        let key1 = ValueKey("test")
        let key2 = ValueKey("test")
        XCTAssertEqual(key1.hashValue, key2.hashValue)
    }

    /// Test ValueKey hash inequality for different values.
    func testValueKeyHashInequality() {
        let key1 = ValueKey("test1")
        let key2 = ValueKey("test2")
        // Different values should generally have different hashes
        XCTAssertNotEqual(key1.hashValue, key2.hashValue)
    }

    /// Test ValueKey description format for String values.
    /// **Dart Source:** `key.dart:106-115`
    func testValueKeyStringDescription() {
        let key = ValueKey("hello")
        // String values should be quoted: [<'hello'>]
        XCTAssertEqual(key.description, "[<'hello'>]")
    }

    /// Test ValueKey description format for non-String values.
    /// **Dart Source:** `key.dart:106-115`
    func testValueKeyIntDescription() {
        let key = ValueKey(42)
        // Non-String values should not be quoted: [<42>]
        XCTAssertEqual(key.description, "[<42>]")
    }

    /// Test ValueKey value property.
    func testValueKeyValueProperty() {
        let key = ValueKey("test")
        XCTAssertEqual(key.value, "test")
    }

    /// Test ValueKey with Double type.
    func testValueKeyDouble() {
        let key1 = ValueKey(3.14)
        let key2 = ValueKey(3.14)
        let key3 = ValueKey(2.71)
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }

    /// Test ValueKey with Bool type.
    func testValueKeyBool() {
        let keyTrue1 = ValueKey(true)
        let keyTrue2 = ValueKey(true)
        let keyFalse = ValueKey(false)
        XCTAssertEqual(keyTrue1, keyTrue2)
        XCTAssertNotEqual(keyTrue1, keyFalse)
    }

    /// Test ValueKey in a Set (uses Hashable).
    func testValueKeyInSet() {
        let key1 = ValueKey("a")
        let key2 = ValueKey("a")
        let key3 = ValueKey("b")

        var set: Set<ValueKey<String>> = []
        set.insert(key1)
        XCTAssertEqual(set.count, 1)

        // Inserting key2 (same value) should not increase count
        set.insert(key2)
        XCTAssertEqual(set.count, 1)

        // Inserting key3 (different value) should increase count
        set.insert(key3)
        XCTAssertEqual(set.count, 2)
    }

    /// Test ValueKey as Dictionary key.
    func testValueKeyAsDictionaryKey() {
        var dict: [ValueKey<Int>: String] = [:]
        dict[ValueKey(1)] = "one"
        dict[ValueKey(2)] = "two"

        XCTAssertEqual(dict[ValueKey(1)], "one")
        XCTAssertEqual(dict[ValueKey(2)], "two")
        XCTAssertNil(dict[ValueKey(3)])
    }

    /// Test that ValueKey with empty string works correctly.
    func testValueKeyEmptyString() {
        let key1 = ValueKey("")
        let key2 = ValueKey("")
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.description, "[<''>]")
    }

    // MARK: - makeKey Factory Function Tests

    /// Test makeKey factory function creates ValueKey<String>.
    /// **Dart Source:** `key.dart:30-33`
    func testMakeKeyCreatesValueKeyString() {
        let key = makeKey("test")
        XCTAssertEqual(key.value, "test")
    }

    /// Test makeKey factory function equality.
    func testMakeKeyEquality() {
        let key1 = makeKey("hello")
        let key2 = makeKey("hello")
        let key3 = ValueKey("hello")

        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1, key3)
    }

    /// Test makeKey factory function with empty string.
    func testMakeKeyEmptyString() {
        let key = makeKey("")
        XCTAssertEqual(key.value, "")
        XCTAssertEqual(key.description, "[<''>]")
    }

    /// Test makeKey factory function inequality.
    func testMakeKeyInequality() {
        let key1 = makeKey("a")
        let key2 = makeKey("b")
        XCTAssertNotEqual(key1, key2)
    }
}
