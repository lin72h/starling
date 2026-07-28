// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for PageStorageKey, PageStorageBucket, and PageStorage.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/page_storage_test.dart`
final class PageStorageTests: XCTestCase {

    // MARK: - PageStorageKey: Equality

    func testPageStorageKeyEqualityWithSameValue() {
        let key1 = PageStorageKey("page1")
        let key2 = PageStorageKey("page1")
        XCTAssertEqual(key1, key2)
    }

    func testPageStorageKeyInequalityWithDifferentValue() {
        let key1 = PageStorageKey("page1")
        let key2 = PageStorageKey("page2")
        XCTAssertNotEqual(key1, key2)
    }

    func testPageStorageKeyEqualityWithIntValue() {
        let key1 = PageStorageKey(42)
        let key2 = PageStorageKey(42)
        XCTAssertEqual(key1, key2)
    }

    func testPageStorageKeyInequalityWithDifferentIntValue() {
        let key1 = PageStorageKey(1)
        let key2 = PageStorageKey(2)
        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - PageStorageKey: Hashing

    func testPageStorageKeyHashConsistency() {
        let key1 = PageStorageKey("test")
        let key2 = PageStorageKey("test")
        XCTAssertEqual(key1.hashValue, key2.hashValue)
    }

    func testPageStorageKeyUsableInSet() {
        let key1 = PageStorageKey("a")
        let key2 = PageStorageKey("b")
        let key3 = PageStorageKey("a") // duplicate
        let set: Set<PageStorageKey<String>> = [key1, key2, key3]
        XCTAssertEqual(set.count, 2)
    }

    func testPageStorageKeyUsableAsDictionaryKey() {
        let key1 = PageStorageKey("x")
        let key2 = PageStorageKey("y")
        var dict: [PageStorageKey<String>: Int] = [:]
        dict[key1] = 10
        dict[key2] = 20
        XCTAssertEqual(dict[key1], 10)
        XCTAssertEqual(dict[key2], 20)

        // Same value, different instance should retrieve same entry
        let key1Copy = PageStorageKey("x")
        XCTAssertEqual(dict[key1Copy], 10)
    }

    // MARK: - PageStorageKey: Description

    func testPageStorageKeyDescriptionWithString() {
        let key = PageStorageKey("myPage")
        let desc = key.description
        XCTAssertTrue(desc.contains("PageStorageKey"))
        XCTAssertTrue(desc.contains("myPage"))
        // String values should be quoted with single quotes
        XCTAssertTrue(desc.contains("'myPage'"))
    }

    func testPageStorageKeyDescriptionWithInt() {
        let key = PageStorageKey(42)
        let desc = key.description
        XCTAssertTrue(desc.contains("PageStorageKey"))
        XCTAssertTrue(desc.contains("42"))
        // Int values should NOT have quotes
        XCTAssertFalse(desc.contains("'42'"))
    }

    // MARK: - PageStorageKey: Value Access

    func testPageStorageKeyValueAccess() {
        let key = PageStorageKey("hello")
        XCTAssertEqual(key.value, "hello")

        let intKey = PageStorageKey(99)
        XCTAssertEqual(intKey.value, 99)
    }

    // MARK: - PageStorageBucket: Read/Write with Explicit Identifier

    func testBucketWriteAndReadWithExplicitIdentifier() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        bucket.writeState(context, 42, identifier: AnyHashable("id1"))
        let read = bucket.readState(context, identifier: AnyHashable("id1"))
        XCTAssertEqual(read as? Int, 42)
    }

    func testBucketReadReturnsNilForUnknownIdentifier() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        let read = bucket.readState(context, identifier: AnyHashable("unknown"))
        XCTAssertNil(read)
    }

    func testBucketWriteOverwritesPreviousValue() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        bucket.writeState(context, "first", identifier: AnyHashable("key"))
        bucket.writeState(context, "second", identifier: AnyHashable("key"))
        let read = bucket.readState(context, identifier: AnyHashable("key"))
        XCTAssertEqual(read as? String, "second")
    }

    func testBucketMultipleIdentifiers() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        bucket.writeState(context, 10, identifier: AnyHashable("a"))
        bucket.writeState(context, 20, identifier: AnyHashable("b"))
        bucket.writeState(context, 30, identifier: AnyHashable("c"))

        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("a")) as? Int, 10)
        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("b")) as? Int, 20)
        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("c")) as? Int, 30)
    }

    func testBucketWriteNilClearsValue() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        bucket.writeState(context, "value", identifier: AnyHashable("key"))
        XCTAssertNotNil(bucket.readState(context, identifier: AnyHashable("key")))

        bucket.writeState(context, nil, identifier: AnyHashable("key"))
        XCTAssertNil(bucket.readState(context, identifier: AnyHashable("key")))
    }

    func testBucketReadWithoutIdentifierAndNoPageStorageKeys() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext() // no PageStorageKey

        // Without explicit identifier and no PageStorageKeys in context,
        // read should return nil
        let read = bucket.readState(context)
        XCTAssertNil(read)
    }

    func testBucketWriteWithoutIdentifierAndNoPageStorageKeysDoesNotStore() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext() // no PageStorageKey

        // Without explicit identifier and no PageStorageKeys,
        // write should be a no-op
        bucket.writeState(context, "data")

        // Verify nothing was stored by trying to read with same context
        let read = bucket.readState(context)
        XCTAssertNil(read)
    }

    func testBucketStoresDifferentTypes() {
        let bucket = PageStorageBucket()
        let context = _MockBuildContext()

        bucket.writeState(context, 3.14, identifier: AnyHashable("double"))
        bucket.writeState(context, "hello", identifier: AnyHashable("string"))
        bucket.writeState(context, [1, 2, 3], identifier: AnyHashable("array"))

        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("double")) as? Double, 3.14)
        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("string")) as? String, "hello")
        XCTAssertEqual(bucket.readState(context, identifier: AnyHashable("array")) as? [Int], [1, 2, 3])
    }

    // MARK: - PageStorage Widget: Construction

    func testPageStorageWidgetConstruction() {
        let bucket = PageStorageBucket()
        let child = _DummyWidget()
        let storage = PageStorage(bucket: bucket, child: child)

        XCTAssertTrue(storage.bucket === bucket)
        XCTAssertTrue(storage.child === child)
    }

    func testPageStorageWidgetWithKey() {
        let bucket = PageStorageBucket()
        let child = _DummyWidget()
        let key = PageStorageKey("storage")
        let storage = PageStorage(key: key, bucket: bucket, child: child)

        XCTAssertNotNil(storage.key)
    }

    func testPageStorageBuildReturnsChild() {
        let bucket = PageStorageBucket()
        let child = _DummyWidget()
        let storage = PageStorage(bucket: bucket, child: child)
        let context = _MockBuildContext()

        let built = storage.build(context)
        XCTAssertTrue(built === child)
    }

    // MARK: - _StorageEntryIdentifier

    func testStorageEntryIdentifierEquality() {
        let id1 = _StorageEntryIdentifier([AnyHashable("a"), AnyHashable(1)])
        let id2 = _StorageEntryIdentifier([AnyHashable("a"), AnyHashable(1)])
        XCTAssertEqual(id1, id2)
    }

    func testStorageEntryIdentifierInequality() {
        let id1 = _StorageEntryIdentifier([AnyHashable("a")])
        let id2 = _StorageEntryIdentifier([AnyHashable("b")])
        XCTAssertNotEqual(id1, id2)
    }

    func testStorageEntryIdentifierInequalityDifferentLength() {
        let id1 = _StorageEntryIdentifier([AnyHashable("a")])
        let id2 = _StorageEntryIdentifier([AnyHashable("a"), AnyHashable("b")])
        XCTAssertNotEqual(id1, id2)
    }

    func testStorageEntryIdentifierIsNotEmpty() {
        let empty = _StorageEntryIdentifier([])
        let nonEmpty = _StorageEntryIdentifier([AnyHashable("key")])
        XCTAssertFalse(empty.isNotEmpty)
        XCTAssertTrue(nonEmpty.isNotEmpty)
    }

    func testStorageEntryIdentifierHashConsistency() {
        let id1 = _StorageEntryIdentifier([AnyHashable("x"), AnyHashable(42)])
        let id2 = _StorageEntryIdentifier([AnyHashable("x"), AnyHashable(42)])
        XCTAssertEqual(id1.hashValue, id2.hashValue)
    }

    func testStorageEntryIdentifierDescription() {
        let id = _StorageEntryIdentifier([AnyHashable("page"), AnyHashable(1)])
        let desc = id.description
        XCTAssertTrue(desc.contains("StorageEntryIdentifier"))
    }

    func testStorageEntryIdentifierUsableAsDictionaryKey() {
        let id1 = _StorageEntryIdentifier([AnyHashable("a")])
        let id2 = _StorageEntryIdentifier([AnyHashable("b")])
        var dict: [_StorageEntryIdentifier: String] = [:]
        dict[id1] = "first"
        dict[id2] = "second"
        XCTAssertEqual(dict[id1], "first")
        XCTAssertEqual(dict[id2], "second")
    }
}

// MARK: - Test Helpers

/// Minimal mock BuildContext for testing PageStorageBucket without a real widget tree.
private class _MockBuildContext: Element {
    init() {
        super.init(_DummyWidget())
    }

    override func visitAncestorElements(_ visitor: (Element) -> Bool) {
        // No ancestors - this is a root context for testing
    }

    override func findAncestorWidgetOfExactType<T: Widget>(_ type: T.Type) -> T? {
        return nil
    }
}

/// A minimal dummy widget for testing.
private class _DummyWidget: Widget {
    init() {
        super.init()
    }
}
