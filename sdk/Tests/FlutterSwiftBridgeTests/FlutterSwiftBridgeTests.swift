// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
@testable import FlutterSwiftBridge

// MARK: - FlutterSwiftBridge Module Tests
/// Tests for the FlutterSwiftBridge module infrastructure.
///
/// These tests verify the basic module setup and error types.
/// Additional test files will be added as dart:ui modules are migrated.

@Suite("FlutterSwiftBridge Module Tests")
struct FlutterSwiftBridgeModuleTests {

    @Test("Module version is defined")
    func testModuleVersionDefined() {
        #expect(!flutterSwiftBridgeVersion.isEmpty)
        #expect(flutterSwiftBridgeVersion == "0.1.0")
    }

    @Test("FlutterSwiftBridgeError cases are distinct")
    func testErrorCasesDistinct() {
        let invalidArg = FlutterSwiftBridgeError.invalidArgument("test")
        let precondition = FlutterSwiftBridgeError.preconditionFailed("test")
        let invalidState = FlutterSwiftBridgeError.invalidState("test")
        let notFound = FlutterSwiftBridgeError.resourceNotFound("test")

        #expect(invalidArg != precondition)
        #expect(precondition != invalidState)
        #expect(invalidState != notFound)
    }

    @Test("FlutterSwiftBridgeError equality works correctly")
    func testErrorEquality() {
        let error1 = FlutterSwiftBridgeError.invalidArgument("same message")
        let error2 = FlutterSwiftBridgeError.invalidArgument("same message")
        let error3 = FlutterSwiftBridgeError.invalidArgument("different message")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
