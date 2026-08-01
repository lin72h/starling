// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// A simple error type for testing
private enum TestError: Error, Equatable {
    case someError
    case otherError
}

/// Tests for ConnectionState and AsyncSnapshot.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/async_test.dart`
final class AsyncTests: XCTestCase {

    // MARK: - ConnectionState

    func testConnectionStateValues() {
        let states: [ConnectionState] = [.none, .waiting, .active, .done]
        XCTAssertEqual(states.count, 4)
    }

    // MARK: - AsyncSnapshot Factory Methods

    func testAsyncSnapshotNothing() {
        let snapshot: AsyncSnapshot<Int> = .nothing()
        XCTAssertEqual(snapshot.connectionState, .none)
        XCTAssertNil(snapshot.data)
        XCTAssertNil(snapshot.error)
        XCTAssertNil(snapshot.stackTrace)
        XCTAssertFalse(snapshot.hasData)
        XCTAssertFalse(snapshot.hasError)
    }

    func testAsyncSnapshotWaiting() {
        let snapshot: AsyncSnapshot<String> = .waiting()
        XCTAssertEqual(snapshot.connectionState, .waiting)
        XCTAssertNil(snapshot.data)
        XCTAssertNil(snapshot.error)
        XCTAssertFalse(snapshot.hasData)
        XCTAssertFalse(snapshot.hasError)
    }

    func testAsyncSnapshotWithData() {
        let snapshot = AsyncSnapshot<Int>.withData(.active, 42)
        XCTAssertEqual(snapshot.connectionState, .active)
        XCTAssertEqual(snapshot.data, 42)
        XCTAssertNil(snapshot.error)
        XCTAssertTrue(snapshot.hasData)
        XCTAssertFalse(snapshot.hasError)
    }

    func testAsyncSnapshotWithDataDone() {
        let snapshot = AsyncSnapshot<String>.withData(.done, "result")
        XCTAssertEqual(snapshot.connectionState, .done)
        XCTAssertEqual(snapshot.data, "result")
        XCTAssertTrue(snapshot.hasData)
    }

    func testAsyncSnapshotWithError() {
        let snapshot = AsyncSnapshot<Int>.withError(.done, TestError.someError)
        XCTAssertEqual(snapshot.connectionState, .done)
        XCTAssertNil(snapshot.data)
        XCTAssertNotNil(snapshot.error)
        XCTAssertTrue(snapshot.hasError)
        XCTAssertFalse(snapshot.hasData)
    }

    func testAsyncSnapshotWithErrorAndStackTrace() {
        let snapshot = AsyncSnapshot<Int>.withError(.done, TestError.someError, "stack trace here")
        XCTAssertEqual(snapshot.connectionState, .done)
        XCTAssertNotNil(snapshot.error)
        XCTAssertEqual(snapshot.stackTrace, "stack trace here")
    }

    // MARK: - requireData

    func testAsyncSnapshotRequireDataWithData() {
        let snapshot = AsyncSnapshot<Int>.withData(.done, 42)
        XCTAssertEqual(snapshot.requireData, 42)
    }

    // MARK: - inState

    func testAsyncSnapshotInStatePreservesData() {
        let snapshot = AsyncSnapshot<Int>.withData(.active, 42)
        let changed = snapshot.inState(.done)
        XCTAssertEqual(changed.connectionState, .done)
        XCTAssertEqual(changed.data, 42)
        XCTAssertNil(changed.error)
    }

    func testAsyncSnapshotInStatePreservesError() {
        let snapshot = AsyncSnapshot<Int>.withError(.active, TestError.someError, "trace")
        let changed = snapshot.inState(.done)
        XCTAssertEqual(changed.connectionState, .done)
        XCTAssertNotNil(changed.error)
        XCTAssertEqual(changed.stackTrace, "trace")
    }

    func testAsyncSnapshotInStateToNone() {
        let snapshot = AsyncSnapshot<Int>.withData(.done, 42)
        let changed = snapshot.inState(.none)
        XCTAssertEqual(changed.connectionState, .none)
        // Data persists even when going to .none
        XCTAssertEqual(changed.data, 42)
    }

    // MARK: - Equality

    func testAsyncSnapshotEqualitySameNothing() {
        let a: AsyncSnapshot<Int> = .nothing()
        let b: AsyncSnapshot<Int> = .nothing()
        XCTAssertEqual(a, b)
    }

    func testAsyncSnapshotEqualitySameData() {
        let a = AsyncSnapshot<Int>.withData(.done, 42)
        let b = AsyncSnapshot<Int>.withData(.done, 42)
        XCTAssertEqual(a, b)
    }

    func testAsyncSnapshotEqualityDifferentData() {
        let a = AsyncSnapshot<Int>.withData(.done, 42)
        let b = AsyncSnapshot<Int>.withData(.done, 99)
        XCTAssertNotEqual(a, b)
    }

    func testAsyncSnapshotEqualityDifferentState() {
        let a = AsyncSnapshot<Int>.withData(.active, 42)
        let b = AsyncSnapshot<Int>.withData(.done, 42)
        XCTAssertNotEqual(a, b)
    }

    func testAsyncSnapshotEqualityDataVsNoData() {
        let a = AsyncSnapshot<Int>.withData(.done, 42)
        let b: AsyncSnapshot<Int> = .nothing()
        XCTAssertNotEqual(a, b)
    }

    func testAsyncSnapshotEqualityErrorVsNoError() {
        let a = AsyncSnapshot<Int>.withError(.done, TestError.someError)
        let b: AsyncSnapshot<Int> = .nothing()
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testAsyncSnapshotHashEqualObjectsSameHash() {
        let a = AsyncSnapshot<Int>.withData(.done, 42)
        let b = AsyncSnapshot<Int>.withData(.done, 42)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testAsyncSnapshotHashWorksInSet() {
        let a = AsyncSnapshot<Int>.withData(.done, 42)
        let b = AsyncSnapshot<Int>.withData(.done, 99)
        let c = AsyncSnapshot<Int>.withData(.done, 42) // Same as a
        let set: Set<AsyncSnapshot<Int>> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Description

    func testAsyncSnapshotDescriptionNothing() {
        let snapshot: AsyncSnapshot<Int> = .nothing()
        let desc = snapshot.description
        XCTAssertTrue(desc.contains("AsyncSnapshot"))
        XCTAssertTrue(desc.contains("none"))
    }

    func testAsyncSnapshotDescriptionWithData() {
        let snapshot = AsyncSnapshot<Int>.withData(.done, 42)
        let desc = snapshot.description
        XCTAssertTrue(desc.contains("AsyncSnapshot"))
        XCTAssertTrue(desc.contains("done"))
        XCTAssertTrue(desc.contains("42"))
    }

    // MARK: - AsyncSnapshot with various types

    func testAsyncSnapshotWithStringData() {
        let snapshot = AsyncSnapshot<String>.withData(.done, "hello")
        XCTAssertEqual(snapshot.data, "hello")
        XCTAssertEqual(snapshot.requireData, "hello")
    }

    func testAsyncSnapshotWithDoubleData() {
        let snapshot = AsyncSnapshot<Double>.withData(.active, 3.14)
        XCTAssertEqual(snapshot.data, 3.14)
        XCTAssertTrue(snapshot.hasData)
    }

    func testAsyncSnapshotWithOptionalData() {
        let snapshot = AsyncSnapshot<Int?>.withData(.done, nil)
        // data is Optional<Optional<Int>> — the outer optional is non-nil
        XCTAssertTrue(snapshot.hasData)
    }
}
