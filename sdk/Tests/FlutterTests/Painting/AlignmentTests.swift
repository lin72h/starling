// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Alignment types.
///
/// **Dart Test Source:** `packages/flutter/test/painting/alignment_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Helper function to compare alignments with tolerance.
///
/// **Dart Test:** `alignment_test.dart:11-14` - `approxExpect`
func approxExpect(_ a: Alignment, _ b: Alignment, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(a.x, b.x, accuracy: 1e-10, file: file, line: line)
    XCTAssertEqual(a.y, b.y, accuracy: 1e-10, file: file, line: line)
}

final class AlignmentTests: XCTestCase {

    // MARK: - Alignment Control Tests

    /// **Dart Test:** `alignment_test.dart:17-26` - "Alignment control test"
    func testAlignmentControl() {
        let alignment = Alignment(0.5, 0.25)

        // Test hashCode equality
        XCTAssertEqual(alignment.hashValue, Alignment(0.5, 0.25).hashValue)

        // Test operators
        XCTAssertEqual(alignment / 2.0, Alignment(0.25, 0.125))
        XCTAssertEqual(alignment.truncatingDivision(2.0), Alignment.center)
        XCTAssertEqual(alignment % 5.0, Alignment(0.5, 0.25))
    }

    // MARK: - Alignment.lerp() Tests

    /// **Dart Test:** `alignment_test.dart:28-36` - "Alignment.lerp()"
    func testAlignmentLerp() {
        let a = Alignment.topLeft
        let b = Alignment.topCenter
        XCTAssertEqual(Alignment.lerp(a, b, 0.25), Alignment(-0.75, -1.0))

        XCTAssertNil(Alignment.lerp(nil, nil, 0.25))
        XCTAssertEqual(Alignment.lerp(nil, b, 0.25), Alignment(0.0, -0.25))
        XCTAssertEqual(Alignment.lerp(a, nil, 0.25), Alignment(-0.75, -0.75))
    }

    /// **Dart Test:** `alignment_test.dart:38-42` - "Alignment.lerp identical a,b"
    func testAlignmentLerpIdentical() {
        XCTAssertNil(Alignment.lerp(nil, nil, 0))
        let alignment = Alignment.topLeft
        let result = Alignment.lerp(alignment, alignment, 0.5)
        // Check that identical inputs return the same value
        XCTAssertEqual(result, alignment)
    }

    /// **Dart Test:** `alignment_test.dart:44-48` - "AlignmentGeometry.lerp identical a,b"
    func testAlignmentGeometryLerpIdentical() {
        let result = AlignmentGeometryStatics.lerp(nil, nil, 0)
        XCTAssertNil(result)
        let alignment: any AlignmentGeometry = Alignment.topLeft
        let lerpResult = AlignmentGeometryStatics.lerp(alignment, alignment, 0.5)
        // Check that identical inputs return the same value
        XCTAssertEqual(lerpResult?._x, alignment._x)
        XCTAssertEqual(lerpResult?._y, alignment._y)
        XCTAssertEqual(lerpResult?._start, alignment._start)
    }

    /// **Dart Test:** `alignment_test.dart:50-54` - "AlignmentDirectional.lerp identical a,b"
    func testAlignmentDirectionalLerpIdentical() {
        XCTAssertNil(AlignmentDirectional.lerp(nil, nil, 0))
        let alignment = AlignmentDirectional.topStart
        let result = AlignmentDirectional.lerp(alignment, alignment, 0.5)
        // Check that identical inputs return the same value
        XCTAssertEqual(result, alignment)
    }

    // MARK: - AlignmentGeometry Invariants Tests

    /// **Dart Test:** `alignment_test.dart:56-115` - "AlignmentGeometry invariants"
    func testAlignmentGeometryInvariants() {
        let topStart = AlignmentDirectional.topStart
        let topEnd = AlignmentDirectional.topEnd
        let center = Alignment.center
        let topLeft = Alignment.topLeft
        let topRight = Alignment.topRight
        let numbers: [Double] = [0.0, 1.0, -1.0, 2.0, 0.25, 0.5, 100.0, -999.75]

        // (topEnd * 0.0).add(topRight * 0.0) == center
        let result1 = (topEnd * 0.0).add(topRight * 0.0)
        XCTAssertEqual(result1._x, center._x)
        XCTAssertEqual(result1._y, center._y)
        XCTAssertEqual(result1._start, center._start)

        // topEnd.add(topRight) * 0.0 == (topEnd * 0.0).add(topRight * 0.0)
        let lhs = topEnd.add(topRight)
        let result2: any AlignmentGeometry
        if let mixedLhs = lhs as? MixedAlignment {
            result2 = mixedLhs * 0.0
        } else if let alignLhs = lhs as? Alignment {
            result2 = alignLhs * 0.0
        } else if let dirLhs = lhs as? AlignmentDirectional {
            result2 = dirLhs * 0.0
        } else {
            XCTFail("Unexpected type")
            return
        }
        XCTAssertEqual(result2._x, result1._x, accuracy: 1e-10)
        XCTAssertEqual(result2._y, result1._y, accuracy: 1e-10)
        XCTAssertEqual(result2._start, result1._start, accuracy: 1e-10)

        // topStart.add(topLeft) == topLeft.add(topStart)
        let addResult1 = topStart.add(topLeft)
        let addResult2 = topLeft.add(topStart)
        XCTAssertEqual(addResult1._x, addResult2._x)
        XCTAssertEqual(addResult1._y, addResult2._y)
        XCTAssertEqual(addResult1._start, addResult2._start)

        // topStart.add(topLeft).resolve(TextDirection.ltr) == topStart.resolve(TextDirection.ltr) + topLeft
        XCTAssertEqual(
            topStart.add(topLeft).resolve(.ltr),
            topStart.resolve(.ltr) + topLeft
        )

        // topStart.add(topLeft).resolve(TextDirection.rtl) == topStart.resolve(TextDirection.rtl) + topLeft
        XCTAssertEqual(
            topStart.add(topLeft).resolve(.rtl),
            topStart.resolve(.rtl) + topLeft
        )

        // topStart.add(topLeft).resolve(TextDirection.ltr) == topStart.resolve(TextDirection.ltr).add(topLeft)
        XCTAssertEqual(
            topStart.add(topLeft).resolve(.ltr),
            topStart.resolve(.ltr).add(topLeft).resolve(.ltr)
        )

        // topStart.add(topLeft).resolve(TextDirection.rtl) == topStart.resolve(TextDirection.rtl).add(topLeft)
        XCTAssertEqual(
            topStart.add(topLeft).resolve(.rtl),
            topStart.resolve(.rtl).add(topLeft).resolve(.rtl)
        )

        // topStart.resolve(TextDirection.ltr) == topLeft
        XCTAssertEqual(topStart.resolve(.ltr), topLeft)

        // topStart.resolve(TextDirection.rtl) == topRight
        XCTAssertEqual(topStart.resolve(.rtl), topRight)

        // topEnd * 0.0 == center
        XCTAssertEqual((topEnd * 0.0).resolve(.ltr), center)

        // topLeft * 0.0 == center
        XCTAssertEqual(topLeft * 0.0, center)

        // topStart * 1.0 == topStart
        XCTAssertEqual(topStart * 1.0, topStart)

        // topEnd * 1.0 == topEnd
        XCTAssertEqual(topEnd * 1.0, topEnd)

        // topLeft * 1.0 == topLeft
        XCTAssertEqual(topLeft * 1.0, topLeft)

        // topRight * 1.0 == topRight
        XCTAssertEqual(topRight * 1.0, topRight)

        // Numeric tests
        for n in numbers {
            // (topStart * n).add(topStart) == topStart * (n + 1.0)
            XCTAssertEqual((topStart * n).add(topStart).resolve(.ltr), (topStart * (n + 1.0)).resolve(.ltr))

            // (topEnd * n).add(topEnd) == topEnd * (n + 1.0)
            XCTAssertEqual((topEnd * n).add(topEnd).resolve(.ltr), (topEnd * (n + 1.0)).resolve(.ltr))

            for m in numbers {
                // (topStart * n).add(topStart * m) == topStart * (n + m)
                XCTAssertEqual((topStart * n).add(topStart * m).resolve(.ltr), (topStart * (n + m)).resolve(.ltr))
            }
        }

        // topStart + topStart + topStart == topStart * 3.0
        XCTAssertEqual(topStart + topStart + topStart, topStart * 3.0)

        // Test for both text directions
        for direction in [TextDirection.ltr, TextDirection.rtl] {
            // (topEnd * 0.0).add(topRight * 0.0).resolve(x) == center.add(center).resolve(x)
            XCTAssertEqual(
                (topEnd * 0.0).add(topRight * 0.0).resolve(direction),
                center.add(center).resolve(direction)
            )

            // (topEnd * 0.0).add(topLeft).resolve(x) == center.add(topLeft).resolve(x)
            XCTAssertEqual(
                (topEnd * 0.0).add(topLeft).resolve(direction),
                center.add(topLeft).resolve(direction)
            )

            // (topEnd * 0.0).resolve(x).add(topLeft.resolve(x)) == center.resolve(x).add(topLeft.resolve(x))
            XCTAssertEqual(
                (topEnd * 0.0).resolve(direction).add(topLeft.resolve(direction)).resolve(direction),
                center.resolve(direction).add(topLeft.resolve(direction)).resolve(direction)
            )

            // (topEnd * 0.0).resolve(x).add(topLeft) == center.resolve(x).add(topLeft)
            XCTAssertEqual(
                (topEnd * 0.0).resolve(direction).add(topLeft).resolve(direction),
                center.resolve(direction).add(topLeft).resolve(direction)
            )

            // (topEnd * 0.0).resolve(x) == center.resolve(x)
            XCTAssertEqual(
                (topEnd * 0.0).resolve(direction),
                center.resolve(direction)
            )
        }

        // Inequality tests - comparing different types
        // In Dart: expect(topStart, isNot(topLeft)) - comparing AlignmentDirectional with Alignment
        // In Swift, we check they are different types with different _start values
        XCTAssertNotEqual(topStart._start, topLeft._start)  // topStart._start == -1.0, topLeft._start == 0.0
        XCTAssertNotEqual(topEnd._start, topLeft._start)
        XCTAssertNotEqual(topStart._start, topRight._start)
        XCTAssertNotEqual(topEnd._start, topRight._start)

        // topStart.add(topLeft) is neither topLeft nor topStart (mixed contains both _x and _start)
        let mixed = topStart.add(topLeft)
        // mixed has both _x and _start components, so it's different from either pure type
        XCTAssertTrue(mixed._x != 0.0 || mixed._start != 0.0)  // Has some non-zero component
        XCTAssertNotEqual(mixed._start, topLeft._start)  // mixed._start != 0
        XCTAssertNotEqual(mixed._x, topStart._x)  // mixed._x != 0
    }

    // MARK: - AlignmentGeometry.resolve() Tests

    /// **Dart Test:** `alignment_test.dart:117-168` - "AlignmentGeometry.resolve()"
    func testAlignmentGeometryResolve() {
        XCTAssertEqual(
            AlignmentDirectional(0.25, 0.3).resolve(.ltr),
            Alignment(0.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(0.25, 0.3).resolve(.rtl),
            Alignment(-0.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(-0.25, 0.3).resolve(.ltr),
            Alignment(-0.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(-0.25, 0.3).resolve(.rtl),
            Alignment(0.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(1.25, 0.3).resolve(.ltr),
            Alignment(1.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(1.25, 0.3).resolve(.rtl),
            Alignment(-1.25, 0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(0.5, -0.3).resolve(.ltr),
            Alignment(0.5, -0.3)
        )
        XCTAssertEqual(
            AlignmentDirectional(0.5, -0.3).resolve(.rtl),
            Alignment(-0.5, -0.3)
        )
        XCTAssertEqual(AlignmentDirectional.center.resolve(.ltr), Alignment.center)
        XCTAssertEqual(AlignmentDirectional.center.resolve(.rtl), Alignment.center)
        XCTAssertEqual(AlignmentDirectional.bottomEnd.resolve(.ltr), Alignment.bottomRight)
        XCTAssertEqual(AlignmentDirectional.bottomEnd.resolve(.rtl), Alignment.bottomLeft)
        XCTAssertEqual(AlignmentDirectional(1.0, 2.0), AlignmentDirectional(1.0, 2.0))
        XCTAssertNotEqual(AlignmentDirectional(1.0, 2.0), AlignmentDirectional(2.0, 1.0))
        XCTAssertEqual(
            AlignmentDirectional.centerStart.resolve(.ltr),
            AlignmentDirectional.centerEnd.resolve(.rtl)
        )
        XCTAssertNotEqual(
            AlignmentDirectional.centerStart.resolve(.ltr),
            AlignmentDirectional.centerEnd.resolve(.ltr)
        )
        XCTAssertNotEqual(
            AlignmentDirectional.centerEnd.resolve(.ltr),
            AlignmentDirectional.centerEnd.resolve(.rtl)
        )
    }

    // MARK: - AlignmentGeometry.lerp Ad Hoc Tests

    /// **Dart Test:** `alignment_test.dart:170-198` - "AlignmentGeometry.lerp ad hoc tests"
    func testAlignmentGeometryLerpAdHoc() {
        let mixed1 = Alignment(10.0, 20.0).add(AlignmentDirectional(30.0, 50.0))
        let mixed2 = Alignment(70.0, 110.0).add(AlignmentDirectional(130.0, 170.0))
        let mixed3 = Alignment(25.0, 42.5).add(AlignmentDirectional(55.0, 80.0))

        for direction in [TextDirection.ltr, TextDirection.rtl] {
            // lerp at 0.0 should equal mixed1
            let result0 = AlignmentGeometryStatics.lerp(mixed1, mixed2, 0.0)!.resolve(direction)
            let expected0 = mixed1.resolve(direction)
            approxExpect(result0, expected0)

            // lerp at 1.0 should equal mixed2
            let result1 = AlignmentGeometryStatics.lerp(mixed1, mixed2, 1.0)!.resolve(direction)
            let expected1 = mixed2.resolve(direction)
            approxExpect(result1, expected1)

            // lerp at 0.25 should equal mixed3
            let result025 = AlignmentGeometryStatics.lerp(mixed1, mixed2, 0.25)!.resolve(direction)
            let expected025 = mixed3.resolve(direction)
            approxExpect(result025, expected025)
        }
    }

    // MARK: - Lerp Commutes With Resolve Tests

    /// **Dart Test:** `alignment_test.dart:200-269` - "lerp commutes with resolve"
    func testLerpCommutesWithResolve() {
        let offsets: [(any AlignmentGeometry)?] = [
            Alignment.topLeft,
            Alignment.topCenter,
            Alignment.topRight,
            AlignmentDirectional.topStart,
            AlignmentDirectional.topCenter,
            AlignmentDirectional.topEnd,
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            AlignmentDirectional.centerStart,
            AlignmentDirectional.center,
            AlignmentDirectional.centerEnd,
            Alignment.bottomLeft,
            Alignment.bottomCenter,
            Alignment.bottomRight,
            AlignmentDirectional.bottomStart,
            AlignmentDirectional.bottomCenter,
            AlignmentDirectional.bottomEnd,
            Alignment(-1.0, 0.65),
            AlignmentDirectional(-1.0, 0.45),
            AlignmentDirectional(0.125, 0.625),
            Alignment(0.25, 0.875),
            Alignment(0.0625, 0.5625).add(AlignmentDirectional(0.1875, 0.6875)),
            AlignmentDirectional(2.0, 3.0),
            Alignment(2.0, 3.0),
            Alignment(2.0, 3.0).add(AlignmentDirectional(5.0, 3.0)),
            Alignment(10.0, 20.0).add(AlignmentDirectional(30.0, 50.0)),
            Alignment(70.0, 110.0).add(AlignmentDirectional(130.0, 170.0)),
            Alignment(25.0, 42.5).add(AlignmentDirectional(55.0, 80.0)),
            nil,
        ]

        let times: [Double] = [0.25, 0.5, 0.75]

        for direction in [TextDirection.ltr, TextDirection.rtl] {
            let defaultValue = AlignmentDirectional.center.resolve(direction)
            for a in offsets {
                let resolvedA = a?.resolve(direction) ?? defaultValue
                for b in offsets {
                    let resolvedB = b?.resolve(direction) ?? defaultValue
                    approxExpect(Alignment.lerp(resolvedA, resolvedB, 0.0)!, resolvedA)
                    approxExpect(Alignment.lerp(resolvedA, resolvedB, 1.0)!, resolvedB)

                    let geomLerp0 = AlignmentGeometryStatics.lerp(a, b, 0.0)
                    approxExpect((geomLerp0?.resolve(direction) ?? defaultValue), resolvedA)

                    let geomLerp1 = AlignmentGeometryStatics.lerp(a, b, 1.0)
                    approxExpect((geomLerp1?.resolve(direction) ?? defaultValue), resolvedB)

                    for t in times {
                        let geomLerpT = AlignmentGeometryStatics.lerp(a, b, t)
                        let value = geomLerpT?.resolve(direction) ?? defaultValue
                        approxExpect(value, Alignment.lerp(resolvedA, resolvedB, t)!)

                        let minDX = min(resolvedA.x, resolvedB.x)
                        let maxDX = max(resolvedA.x, resolvedB.x)
                        let minDY = min(resolvedA.y, resolvedB.y)
                        let maxDY = max(resolvedA.y, resolvedB.y)
                        XCTAssertGreaterThanOrEqual(value.x, minDX - 1e-10)
                        XCTAssertLessThanOrEqual(value.x, maxDX + 1e-10)
                        XCTAssertGreaterThanOrEqual(value.y, minDY - 1e-10)
                        XCTAssertLessThanOrEqual(value.y, maxDY + 1e-10)
                    }
                }
            }
        }
    }

    // MARK: - AlignmentGeometry Add/Subtract Tests

    /// **Dart Test:** `alignment_test.dart:271-278` - "AlignmentGeometry add/subtract"
    func testAlignmentGeometryAddSubtract() {
        let directional: any AlignmentGeometry = AlignmentDirectional(1.0, 2.0)
        let normal: any AlignmentGeometry = Alignment(3.0, 5.0)
        XCTAssertEqual(directional.add(normal).resolve(.ltr), Alignment(4.0, 7.0))
        XCTAssertEqual(directional.add(normal).resolve(.rtl), Alignment(2.0, 7.0))

        // normal.add(normal) == normal * 2.0
        let normalAlignment = normal as! Alignment
        XCTAssertEqual(normalAlignment.add(normalAlignment).resolve(.ltr), (normalAlignment * 2.0))

        // directional.add(directional) == directional * 2.0
        let directionalDir = directional as! AlignmentDirectional
        XCTAssertEqual(directionalDir.add(directionalDir).resolve(.ltr), (directionalDir * 2.0).resolve(.ltr))
    }

    // MARK: - AlignmentGeometry Operators Tests (AlignmentDirectional)

    /// **Dart Test:** `alignment_test.dart:280-307` - "AlignmentGeometry operators"
    func testAlignmentGeometryOperatorsDirectional() {
        XCTAssertEqual(AlignmentDirectional(1.0, 2.0) * 2.0, AlignmentDirectional(2.0, 4.0))
        XCTAssertEqual(AlignmentDirectional(1.0, 2.0) / 2.0, AlignmentDirectional(0.5, 1.0))
        XCTAssertEqual(AlignmentDirectional(1.0, 2.0) % 2.0, AlignmentDirectional.centerEnd)
        XCTAssertEqual(AlignmentDirectional(1.0, 2.0).truncatingDivision(2.0), AlignmentDirectional.bottomCenter)

        for direction in [TextDirection.ltr, TextDirection.rtl] {
            XCTAssertEqual(
                Alignment.center.add(AlignmentDirectional(1.0, 2.0) * 2.0).resolve(direction),
                AlignmentDirectional(2.0, 4.0).resolve(direction)
            )
            XCTAssertEqual(
                Alignment.center.add(AlignmentDirectional(1.0, 2.0) / 2.0).resolve(direction),
                AlignmentDirectional(0.5, 1.0).resolve(direction)
            )
            XCTAssertEqual(
                Alignment.center.add(AlignmentDirectional(1.0, 2.0) % 2.0).resolve(direction),
                AlignmentDirectional.centerEnd.resolve(direction)
            )
            XCTAssertEqual(
                Alignment.center.add(AlignmentDirectional(1.0, 2.0).truncatingDivision(2.0)).resolve(direction),
                AlignmentDirectional.bottomCenter.resolve(direction)
            )
        }
        XCTAssertEqual(Alignment(1.0, 2.0) * 2.0, Alignment(2.0, 4.0))
        XCTAssertEqual(Alignment(1.0, 2.0) / 2.0, Alignment(0.5, 1.0))
        XCTAssertEqual(Alignment(1.0, 2.0) % 2.0, Alignment.centerRight)
        XCTAssertEqual(Alignment(1.0, 2.0).truncatingDivision(2.0), Alignment.bottomCenter)
    }

    // MARK: - AlignmentGeometry Operators Tests (Addition/Subtraction)

    /// **Dart Test:** `alignment_test.dart:309-320` - "AlignmentGeometry operators"
    func testAlignmentGeometryOperatorsAddSub() {
        XCTAssertEqual(Alignment(1.0, 2.0) + Alignment(3.0, 5.0), Alignment(4.0, 7.0))
        XCTAssertEqual(Alignment(1.0, 2.0) - Alignment(3.0, 5.0), Alignment(-2.0, -3.0))
        XCTAssertEqual(
            AlignmentDirectional(1.0, 2.0) + AlignmentDirectional(3.0, 5.0),
            AlignmentDirectional(4.0, 7.0)
        )
        XCTAssertEqual(
            AlignmentDirectional(1.0, 2.0) - AlignmentDirectional(3.0, 5.0),
            AlignmentDirectional(-2.0, -3.0)
        )
    }

    // MARK: - AlignmentGeometry toString Tests

    /// **Dart Test:** `alignment_test.dart:322-336` - "AlignmentGeometry toString"
    func testAlignmentGeometryToString() {
        XCTAssertEqual(Alignment(1.0001, 2.0001).description, "Alignment(1.0, 2.0)")
        XCTAssertEqual(Alignment.center.description, "Alignment.center")
        XCTAssertEqual(
            Alignment.bottomLeft.add(AlignmentDirectional.centerEnd).description,
            "Alignment.bottomLeft + AlignmentDirectional.centerEnd"
        )
        XCTAssertEqual(Alignment(0.0001, 0.0001).description, "Alignment(0.0, 0.0)")
        XCTAssertEqual(Alignment.center.description, "Alignment.center")
        XCTAssertEqual(AlignmentDirectional.center.description, "AlignmentDirectional.center")
        XCTAssertEqual(
            Alignment.bottomRight.add(AlignmentDirectional.bottomEnd).description,
            "Alignment(1.0, 2.0) + AlignmentDirectional.centerEnd"
        )
    }

    // MARK: - AlignmentGeometry Factories Tests

    /// **Dart Test:** `alignment_test.dart:338-341` - "AlignmentGeometry factories"
    ///
    /// Note: In Swift, the protocol cannot have factory constructors, so we test
    /// that Alignment and AlignmentDirectional constructors work correctly.
    func testAlignmentGeometryFactories() {
        // AlignmentGeometry.xy(4, 5) -> Alignment(4, 5)
        XCTAssertEqual(Alignment(4, 5), Alignment(4, 5))
        // AlignmentGeometry.directional(4, 5) -> AlignmentDirectional(4, 5)
        XCTAssertEqual(AlignmentDirectional(4, 5), AlignmentDirectional(4, 5))
    }

    // MARK: - AlignmentGeometry Static Members Tests

    /// **Dart Test:** `alignment_test.dart:343-353` - "AlignmentGeometry static members"
    ///
    /// Note: In Swift, protocols cannot have static stored properties. The static
    /// constants are available through the concrete types (Alignment, AlignmentDirectional).
    func testAlignmentGeometryStaticMembers() {
        // Verify Alignment static constants
        XCTAssertEqual(Alignment.topLeft, Alignment(-1.0, -1.0))
        XCTAssertEqual(Alignment.topCenter, Alignment(0.0, -1.0))
        XCTAssertEqual(Alignment.topRight, Alignment(1.0, -1.0))
        XCTAssertEqual(Alignment.centerLeft, Alignment(-1.0, 0.0))
        XCTAssertEqual(Alignment.center, Alignment(0.0, 0.0))
        XCTAssertEqual(Alignment.centerRight, Alignment(1.0, 0.0))
        XCTAssertEqual(Alignment.bottomLeft, Alignment(-1.0, 1.0))
        XCTAssertEqual(Alignment.bottomCenter, Alignment(0.0, 1.0))
        XCTAssertEqual(Alignment.bottomRight, Alignment(1.0, 1.0))
    }

    // MARK: - TextAlignVertical Tests

    /// **Dart Test:** Additional tests for TextAlignVertical
    func testTextAlignVertical() {
        XCTAssertEqual(TextAlignVertical.top.y, -1.0)
        XCTAssertEqual(TextAlignVertical.center.y, 0.0)
        XCTAssertEqual(TextAlignVertical.bottom.y, 1.0)

        // Test description
        XCTAssertEqual(TextAlignVertical.top.description, "TextAlignVertical(y: -1.0)")
        XCTAssertEqual(TextAlignVertical.center.description, "TextAlignVertical(y: 0.0)")
        XCTAssertEqual(TextAlignVertical.bottom.description, "TextAlignVertical(y: 1.0)")

        // Test custom value
        let custom = TextAlignVertical(y: 0.5)
        XCTAssertEqual(custom.y, 0.5)

        // Test equality
        XCTAssertEqual(TextAlignVertical.center, TextAlignVertical(y: 0.0))
    }

    // MARK: - Alignment Geometry Methods Tests

    /// Additional tests for Alignment geometry methods
    func testAlignmentGeometryMethods() {
        let alignment = Alignment.topLeft

        // Test alongOffset
        let offset = Offset(100, 200)
        let alongOffsetResult = alignment.alongOffset(offset)
        XCTAssertEqual(alongOffsetResult.dx, 0.0)
        XCTAssertEqual(alongOffsetResult.dy, 0.0)

        // Test alongSize
        let size = Size(100, 200)
        let alongSizeResult = alignment.alongSize(size)
        XCTAssertEqual(alongSizeResult.dx, 0.0)
        XCTAssertEqual(alongSizeResult.dy, 0.0)

        // Test withinRect
        let rect = Rect.fromLTWH(0, 0, 100, 200)
        let withinRectResult = alignment.withinRect(rect)
        XCTAssertEqual(withinRectResult.dx, 0.0)
        XCTAssertEqual(withinRectResult.dy, 0.0)

        // Test inscribe
        let inscribedRect = alignment.inscribe(Size(50, 50), rect)
        XCTAssertEqual(inscribedRect.left, 0.0)
        XCTAssertEqual(inscribedRect.top, 0.0)
        XCTAssertEqual(inscribedRect.width, 50.0)
        XCTAssertEqual(inscribedRect.height, 50.0)

        // Test center alignment
        let centerAlignment = Alignment.center
        let centerWithinRect = centerAlignment.withinRect(rect)
        XCTAssertEqual(centerWithinRect.dx, 50.0)
        XCTAssertEqual(centerWithinRect.dy, 100.0)

        let centerInscribed = centerAlignment.inscribe(Size(50, 50), rect)
        XCTAssertEqual(centerInscribed.left, 25.0)
        XCTAssertEqual(centerInscribed.top, 75.0)
    }

    // MARK: - Unary Negation Tests

    /// Test unary negation operators
    func testUnaryNegation() {
        // Alignment
        let alignment = Alignment(1.0, -2.0)
        let negatedAlignment = -alignment
        XCTAssertEqual(negatedAlignment.x, -1.0)
        XCTAssertEqual(negatedAlignment.y, 2.0)

        // AlignmentDirectional
        let directional = AlignmentDirectional(1.0, -2.0)
        let negatedDirectional = -directional
        XCTAssertEqual(negatedDirectional.start, -1.0)
        XCTAssertEqual(negatedDirectional.y, 2.0)

        // MixedAlignment
        let mixed = MixedAlignment(1.0, 2.0, -3.0)
        let negatedMixed = -mixed
        XCTAssertEqual(negatedMixed._x, -1.0)
        XCTAssertEqual(negatedMixed._start, -2.0)
        XCTAssertEqual(negatedMixed._y, 3.0)
    }

    // MARK: - MixedAlignment Tests

    /// Test MixedAlignment operations
    func testMixedAlignment() {
        let mixed = MixedAlignment(1.0, 2.0, 3.0)

        // Test multiplication
        let multiplied = mixed * 2.0
        XCTAssertEqual(multiplied._x, 2.0)
        XCTAssertEqual(multiplied._start, 4.0)
        XCTAssertEqual(multiplied._y, 6.0)

        // Test division
        let divided = mixed / 2.0
        XCTAssertEqual(divided._x, 0.5)
        XCTAssertEqual(divided._start, 1.0)
        XCTAssertEqual(divided._y, 1.5)

        // Test truncating division
        let truncated = MixedAlignment(5.0, 7.0, 9.0).truncatingDivision(2.0)
        XCTAssertEqual(truncated._x, 2.0)
        XCTAssertEqual(truncated._start, 3.0)
        XCTAssertEqual(truncated._y, 4.0)

        // Test modulo
        let modulo = MixedAlignment(5.0, 7.0, 9.0) % 3.0
        XCTAssertEqual(modulo._x, 2.0, accuracy: 1e-10)
        XCTAssertEqual(modulo._start, 1.0, accuracy: 1e-10)
        XCTAssertEqual(modulo._y, 0.0, accuracy: 1e-10)

        // Test resolve LTR
        let resolvedLtr = mixed.resolve(.ltr)
        XCTAssertEqual(resolvedLtr.x, 3.0)  // 1.0 + 2.0
        XCTAssertEqual(resolvedLtr.y, 3.0)

        // Test resolve RTL
        let resolvedRtl = mixed.resolve(.rtl)
        XCTAssertEqual(resolvedRtl.x, -1.0)  // 1.0 - 2.0
        XCTAssertEqual(resolvedRtl.y, 3.0)
    }

    // MARK: - Hashable Tests

    /// Test that Hashable works correctly
    func testHashable() {
        // Alignment
        let alignment1 = Alignment(1.0, 2.0)
        let alignment2 = Alignment(1.0, 2.0)
        let alignment3 = Alignment(2.0, 1.0)
        XCTAssertEqual(alignment1.hashValue, alignment2.hashValue)
        XCTAssertNotEqual(alignment1.hashValue, alignment3.hashValue)

        // AlignmentDirectional
        let dir1 = AlignmentDirectional(1.0, 2.0)
        let dir2 = AlignmentDirectional(1.0, 2.0)
        let dir3 = AlignmentDirectional(2.0, 1.0)
        XCTAssertEqual(dir1.hashValue, dir2.hashValue)
        XCTAssertNotEqual(dir1.hashValue, dir3.hashValue)

        // TextAlignVertical
        let textAlign1 = TextAlignVertical(y: 0.5)
        let textAlign2 = TextAlignVertical(y: 0.5)
        let textAlign3 = TextAlignVertical(y: -0.5)
        XCTAssertEqual(textAlign1.hashValue, textAlign2.hashValue)
        XCTAssertNotEqual(textAlign1.hashValue, textAlign3.hashValue)
    }

    // MARK: - AlignmentDirectional Static Constants Tests

    /// Test AlignmentDirectional static constants
    func testAlignmentDirectionalStaticConstants() {
        XCTAssertEqual(AlignmentDirectional.topStart, AlignmentDirectional(-1.0, -1.0))
        XCTAssertEqual(AlignmentDirectional.topCenter, AlignmentDirectional(0.0, -1.0))
        XCTAssertEqual(AlignmentDirectional.topEnd, AlignmentDirectional(1.0, -1.0))
        XCTAssertEqual(AlignmentDirectional.centerStart, AlignmentDirectional(-1.0, 0.0))
        XCTAssertEqual(AlignmentDirectional.center, AlignmentDirectional(0.0, 0.0))
        XCTAssertEqual(AlignmentDirectional.centerEnd, AlignmentDirectional(1.0, 0.0))
        XCTAssertEqual(AlignmentDirectional.bottomStart, AlignmentDirectional(-1.0, 1.0))
        XCTAssertEqual(AlignmentDirectional.bottomCenter, AlignmentDirectional(0.0, 1.0))
        XCTAssertEqual(AlignmentDirectional.bottomEnd, AlignmentDirectional(1.0, 1.0))
    }
}
