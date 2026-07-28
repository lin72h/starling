// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for geometry utilities.
///
/// **Dart Test Source:** `packages/flutter/test/painting/geometry_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class GeometryTests: XCTestCase {

    // MARK: - positionDependentBox Tests

    /// **Dart Test:** `geometry_test.dart:9-112` - "positionDependentBox"
    func testPositionDependentBox() {
        // For historical reasons, significantly more tests of this function
        // exist in: ../material/tooltip_test.dart

        // Test 1: Basic positioning - child centered on target, above
        // geometry_test.dart:12-21
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(20.0, 10.0),
                target: Offset(50.0, 50.0),
                preferBelow: false,
                margin: 0.0
            ),
            Offset(40.0, 40.0)
        )

        // Test 2: Child wider than container - centered in container
        // geometry_test.dart:22-31
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(200.0, 10.0),
                target: Offset(50.0, 50.0),
                preferBelow: false,
                margin: 0.0
            ),
            Offset(-50.0, 40.0)
        )

        // Test 3: Target at left edge, child wider than container
        // geometry_test.dart:32-41
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(200.0, 10.0),
                target: Offset(0.0, 50.0),
                preferBelow: false,
                margin: 0.0
            ),
            Offset(-50.0, 40.0)
        )

        // Test 4: Target at right edge, child wider than container
        // geometry_test.dart:42-51
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(200.0, 10.0),
                target: Offset(100.0, 50.0),
                preferBelow: false,
                margin: 0.0
            ),
            Offset(-50.0, 40.0)
        )

        // Test 5: With margin 20.0 (60.0 flexible space left)
        // geometry_test.dart:52-61
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(50.0, 50.0),
                preferBelow: false,
                margin: 20.0
            ),
            Offset(25.0, 40.0)
        )

        // Test 6: With margin 30.0 (40.0 flexible space left)
        // geometry_test.dart:62-71
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(50.0, 50.0),
                preferBelow: false,
                margin: 30.0
            ),
            Offset(25.0, 40.0)
        )

        // Test 7: Target at left edge, margin 20.0 (60.0 flexible space left)
        // geometry_test.dart:72-81
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(0.0, 50.0),
                preferBelow: false,
                margin: 20.0
            ),
            Offset(20.0, 40.0)
        )

        // Test 8: Target at left edge, margin 30.0 (40.0 flexible space left)
        // geometry_test.dart:82-91
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(0.0, 50.0),
                preferBelow: false,
                margin: 30.0
            ),
            Offset(25.0, 40.0)
        )

        // Test 9: Target at right edge, margin 20.0 (60.0 flexible space left)
        // geometry_test.dart:92-101
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(100.0, 50.0),
                preferBelow: false,
                margin: 20.0
            ),
            Offset(30.0, 40.0)
        )

        // Test 10: Target at right edge, margin 30.0 (40.0 flexible space left)
        // geometry_test.dart:102-111
        XCTAssertEqual(
            positionDependentBox(
                size: Size(100.0, 100.0),
                childSize: Size(50.0, 10.0),
                target: Offset(100.0, 50.0),
                preferBelow: false,
                margin: 30.0
            ),
            Offset(25.0, 40.0)
        )
    }

    // MARK: - Additional Vertical Positioning Tests

    /// Test preferBelow = true positions child below the target
    func testPositionDependentBoxPreferBelow() {
        let result = positionDependentBox(
            size: Size(100.0, 100.0),
            childSize: Size(20.0, 10.0),
            target: Offset(50.0, 30.0),
            preferBelow: true,
            margin: 0.0
        )
        // When preferBelow is true and it fits below, child should be below the target
        XCTAssertEqual(result, Offset(40.0, 30.0))
    }

    /// Test with verticalOffset
    func testPositionDependentBoxVerticalOffset() {
        let result = positionDependentBox(
            size: Size(100.0, 100.0),
            childSize: Size(20.0, 10.0),
            target: Offset(50.0, 50.0),
            preferBelow: true,
            verticalOffset: 5.0,
            margin: 0.0
        )
        // Child positioned below target with 5.0 offset
        XCTAssertEqual(result, Offset(40.0, 55.0))
    }

    /// Test default parameter values
    func testPositionDependentBoxDefaultParameters() {
        // Uses default verticalOffset=0.0 and margin=10.0
        let result = positionDependentBox(
            size: Size(200.0, 200.0),
            childSize: Size(40.0, 20.0),
            target: Offset(100.0, 100.0),
            preferBelow: true
        )
        // With default margin=10.0, verticalOffset=0.0
        // fitsBelow: 100 + 0 + 20 <= 200 - 10 => 120 <= 190 => true
        // fitsAbove: 100 - 0 - 20 >= 10 => 80 >= 10 => true
        // Both fit, so preferBelow wins => tooltipBelow = true
        // y = min(100 + 0, 200 - 10) = min(100, 190) = 100
        // flexibleSpace = 200 - 40 = 160, 160 > 2*10=20
        // x = clamp(100 - 40/2, 10, 160 - 10) = clamp(80, 10, 150) = 80
        XCTAssertEqual(result, Offset(80.0, 100.0))
    }
}
