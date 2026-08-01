// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for BoxFit, FittedSizes, and applyBoxFit
///
/// **Dart Test Source:** `packages/flutter/test/painting/box_fit_test.dart`
final class BoxFitTests: XCTestCase {

    // MARK: - applyBoxFit Tests

    /// Test applyBoxFit with scaleDown when source is smaller than output
    ///
    /// **Dart Test:** `box_fit_test.dart:12-14`
    func testApplyBoxFitScaleDownSmallerSource() {
        let result = applyBoxFit(.scaleDown, Size(100.0, 1000.0), Size(200.0, 2000.0))
        XCTAssertEqual(result.source, Size(100.0, 1000.0))
        XCTAssertEqual(result.destination, Size(100.0, 1000.0))
    }

    /// Test applyBoxFit with scaleDown when source is larger than output
    ///
    /// **Dart Test:** `box_fit_test.dart:16-18`
    func testApplyBoxFitScaleDownLargerSource() {
        let result = applyBoxFit(.scaleDown, Size(300.0, 3000.0), Size(200.0, 2000.0))
        XCTAssertEqual(result.source, Size(300.0, 3000.0))
        XCTAssertEqual(result.destination, Size(200.0, 2000.0))
    }

    /// Test applyBoxFit with fitWidth when width-constrained (cover-like)
    ///
    /// **Dart Test:** `box_fit_test.dart:20-22`
    func testApplyBoxFitFitWidthCoverLike() {
        let result = applyBoxFit(.fitWidth, Size(2000.0, 400.0), Size(1000.0, 100.0))
        XCTAssertEqual(result.source, Size(2000.0, 200.0))
        XCTAssertEqual(result.destination, Size(1000.0, 100.0))
    }

    /// Test applyBoxFit with fitWidth when height-constrained (contain-like)
    ///
    /// **Dart Test:** `box_fit_test.dart:24-26`
    func testApplyBoxFitFitWidthContainLike() {
        let result = applyBoxFit(.fitWidth, Size(2000.0, 400.0), Size(1000.0, 300.0))
        XCTAssertEqual(result.source, Size(2000.0, 400.0))
        XCTAssertEqual(result.destination, Size(1000.0, 200.0))
    }

    /// Test applyBoxFit with fitHeight when height-constrained (cover-like)
    ///
    /// **Dart Test:** `box_fit_test.dart:28-30`
    func testApplyBoxFitFitHeightCoverLike() {
        let result = applyBoxFit(.fitHeight, Size(400.0, 2000.0), Size(100.0, 1000.0))
        XCTAssertEqual(result.source, Size(200.0, 2000.0))
        XCTAssertEqual(result.destination, Size(100.0, 1000.0))
    }

    /// Test applyBoxFit with fitHeight when width-constrained (contain-like)
    ///
    /// **Dart Test:** `box_fit_test.dart:32-34`
    func testApplyBoxFitFitHeightContainLike() {
        let result = applyBoxFit(.fitHeight, Size(400.0, 2000.0), Size(300.0, 1000.0))
        XCTAssertEqual(result.source, Size(400.0, 2000.0))
        XCTAssertEqual(result.destination, Size(200.0, 1000.0))
    }

    // MARK: - Zero and Negative Size Tests

    /// Test applyBoxFit with BoxFit.fill handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:36, 46-80`
    func testApplyBoxFitFillZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .fill)
    }

    /// Test applyBoxFit with BoxFit.contain handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:37, 46-80`
    func testApplyBoxFitContainZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .contain)
    }

    /// Test applyBoxFit with BoxFit.cover handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:38, 46-80`
    func testApplyBoxFitCoverZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .cover)
    }

    /// Test applyBoxFit with BoxFit.fitWidth handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:39, 46-80`
    func testApplyBoxFitFitWidthZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .fitWidth)
    }

    /// Test applyBoxFit with BoxFit.fitHeight handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:40, 46-80`
    func testApplyBoxFitFitHeightZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .fitHeight)
    }

    /// Test applyBoxFit with BoxFit.none handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:41, 46-80`
    func testApplyBoxFitNoneZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .none)
    }

    /// Test applyBoxFit with BoxFit.scaleDown handles zero and negative sizes
    ///
    /// **Dart Test:** `box_fit_test.dart:42, 46-80`
    func testApplyBoxFitScaleDownZeroAndNegativeSizes() {
        testZeroAndNegativeSizes(fit: .scaleDown)
    }

    // MARK: - Helper Methods

    /// Helper method to test zero and negative sizes for a given BoxFit
    ///
    /// **Dart Source:** `box_fit_test.dart:46-80` (`_testZeroAndNegativeSizes`)
    private func testZeroAndNegativeSizes(fit: BoxFit) {
        var result: FittedSizes

        // Negative input width - box_fit_test.dart:49-51
        result = applyBoxFit(fit, Size(-400.0, 2000.0), Size(100.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Negative input height - box_fit_test.dart:53-55
        result = applyBoxFit(fit, Size(400.0, -2000.0), Size(100.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Negative output width - box_fit_test.dart:57-59
        result = applyBoxFit(fit, Size(400.0, 2000.0), Size(-100.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Negative output height - box_fit_test.dart:61-63
        result = applyBoxFit(fit, Size(400.0, 2000.0), Size(100.0, -1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Zero input width - box_fit_test.dart:65-67
        result = applyBoxFit(fit, Size(0.0, 2000.0), Size(100.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Zero input height - box_fit_test.dart:69-71
        result = applyBoxFit(fit, Size(400.0, 0.0), Size(100.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Zero output width - box_fit_test.dart:73-75
        result = applyBoxFit(fit, Size(400.0, 2000.0), Size(0.0, 1000.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)

        // Zero output height - box_fit_test.dart:77-79
        result = applyBoxFit(fit, Size(400.0, 2000.0), Size(100.0, 0.0))
        XCTAssertEqual(result.source, Size.zero)
        XCTAssertEqual(result.destination, Size.zero)
    }

    // MARK: - BoxFit Enum Tests

    /// Test that BoxFit has all expected cases
    func testBoxFitCases() {
        // Verify all cases exist and are distinct
        let allCases: [BoxFit] = [.fill, .contain, .cover, .fitWidth, .fitHeight, .none, .scaleDown]
        XCTAssertEqual(allCases.count, 7)

        // Verify each case is unique
        var seenCases = Set<String>()
        for boxFit in allCases {
            let description = String(describing: boxFit)
            XCTAssertFalse(seenCases.contains(description), "Duplicate case: \(description)")
            seenCases.insert(description)
        }
    }

    // MARK: - FittedSizes Tests

    /// Test FittedSizes initializer
    func testFittedSizesInit() {
        let source = Size(100.0, 200.0)
        let destination = Size(50.0, 100.0)
        let fittedSizes = FittedSizes(source: source, destination: destination)

        XCTAssertEqual(fittedSizes.source, source)
        XCTAssertEqual(fittedSizes.destination, destination)
    }

    /// Test FittedSizes Equatable conformance
    func testFittedSizesEquatable() {
        let source = Size(100.0, 200.0)
        let destination = Size(50.0, 100.0)

        let fittedSizes1 = FittedSizes(source: source, destination: destination)
        let fittedSizes2 = FittedSizes(source: source, destination: destination)
        let fittedSizes3 = FittedSizes(source: Size(150.0, 250.0), destination: destination)

        XCTAssertEqual(fittedSizes1, fittedSizes2)
        XCTAssertNotEqual(fittedSizes1, fittedSizes3)
    }

    // MARK: - Additional BoxFit Tests

    /// Test applyBoxFit with BoxFit.fill
    func testApplyBoxFitFill() {
        let result = applyBoxFit(.fill, Size(100.0, 200.0), Size(300.0, 400.0))
        XCTAssertEqual(result.source, Size(100.0, 200.0))
        XCTAssertEqual(result.destination, Size(300.0, 400.0))
    }

    /// Test applyBoxFit with BoxFit.contain when output is wider
    func testApplyBoxFitContainOutputWider() {
        let result = applyBoxFit(.contain, Size(100.0, 200.0), Size(400.0, 200.0))
        XCTAssertEqual(result.source, Size(100.0, 200.0))
        XCTAssertEqual(result.destination, Size(100.0, 200.0))
    }

    /// Test applyBoxFit with BoxFit.contain when output is taller
    func testApplyBoxFitContainOutputTaller() {
        let result = applyBoxFit(.contain, Size(200.0, 100.0), Size(200.0, 400.0))
        XCTAssertEqual(result.source, Size(200.0, 100.0))
        XCTAssertEqual(result.destination, Size(200.0, 100.0))
    }

    /// Test applyBoxFit with BoxFit.cover when output is wider
    func testApplyBoxFitCoverOutputWider() {
        let result = applyBoxFit(.cover, Size(100.0, 200.0), Size(400.0, 200.0))
        XCTAssertEqual(result.source, Size(100.0, 50.0))
        XCTAssertEqual(result.destination, Size(400.0, 200.0))
    }

    /// Test applyBoxFit with BoxFit.cover when output is taller
    func testApplyBoxFitCoverOutputTaller() {
        let result = applyBoxFit(.cover, Size(200.0, 100.0), Size(200.0, 400.0))
        XCTAssertEqual(result.source, Size(50.0, 100.0))
        XCTAssertEqual(result.destination, Size(200.0, 400.0))
    }

    /// Test applyBoxFit with BoxFit.none
    func testApplyBoxFitNone() {
        // When source fits within output
        var result = applyBoxFit(.none, Size(100.0, 200.0), Size(300.0, 400.0))
        XCTAssertEqual(result.source, Size(100.0, 200.0))
        XCTAssertEqual(result.destination, Size(100.0, 200.0))

        // When source is larger than output
        result = applyBoxFit(.none, Size(500.0, 600.0), Size(300.0, 400.0))
        XCTAssertEqual(result.source, Size(300.0, 400.0))
        XCTAssertEqual(result.destination, Size(300.0, 400.0))
    }
}
