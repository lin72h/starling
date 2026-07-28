// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Decoration protocol and BoxPainter class.
///
/// **Dart Test Source:** `packages/flutter/test/painting/decoration_test.dart`
///
/// Note: Tests that depend on BoxDecoration (not yet migrated) are skipped.
/// Only tests for the Decoration protocol, its default implementations,
/// the lerpDecoration() function, and the BoxPainter base class are included.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal concrete Decoration implementation for testing default behavior.
///
/// This stands in for BoxDecoration / other concrete decorations that are not yet migrated.
private final class TestDecoration: Decoration {
    let id: Int

    init(id: Int = 0) {
        self.id = id
    }

    func createBoxPainter(_ onChanged: VoidCallback?) -> BoxPainter {
        TestBoxPainter(onChanged: onChanged)
    }

    func toStringShort() -> String {
        objectRuntimeType(self, "TestDecoration")
    }

    func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {}
    func toDiagnosticsNode(name: String?, style: DiagnosticsTreeStyle?) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style ?? .singleLine)
    }
}

/// A Decoration that implements lerpFrom and lerpTo for testing interpolation.
private final class LerpableDecoration: Decoration {
    let value: Double

    init(value: Double = 0.0) {
        self.value = value
    }

    func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)? {
        guard let a = a as? LerpableDecoration else { return nil }
        return LerpableDecoration(value: a.value + (value - a.value) * t)
    }

    func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)? {
        guard let b = b as? LerpableDecoration else { return nil }
        return LerpableDecoration(value: value + (b.value - value) * t)
    }

    func createBoxPainter(_ onChanged: VoidCallback?) -> BoxPainter {
        TestBoxPainter(onChanged: onChanged)
    }

    func toStringShort() -> String {
        objectRuntimeType(self, "LerpableDecoration")
    }

    func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {}
    func toDiagnosticsNode(name: String?, style: DiagnosticsTreeStyle?) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style ?? .singleLine)
    }
}

/// A second Decoration type that cannot lerp with LerpableDecoration, for testing
/// the fallback path through nil in lerpDecoration().
///
/// Analogous to the Dart test using FlutterLogoDecoration vs BoxDecoration.
///
/// **Dart Test:** `decoration_test.dart:485-502` - "Decoration.lerp with unrelated decorations"
private final class UnrelatedDecoration: Decoration {
    let tag: String

    init(tag: String = "unrelated") {
        self.tag = tag
    }

    func createBoxPainter(_ onChanged: VoidCallback?) -> BoxPainter {
        TestBoxPainter(onChanged: onChanged)
    }

    func toStringShort() -> String {
        objectRuntimeType(self, "UnrelatedDecoration")
    }

    func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {}
    func toDiagnosticsNode(name: String?, style: DiagnosticsTreeStyle?) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style ?? .singleLine)
    }
}

/// A concrete BoxPainter subclass for testing.
private final class TestBoxPainter: BoxPainter {
    var paintCallCount = 0

    override func paint(_ canvas: Canvas, _ offset: Offset, _ configuration: ImageConfiguration) {
        paintCallCount += 1
    }
}

// MARK: - DecorationTests

final class DecorationTests: XCTestCase {

    // MARK: - Decoration Default Implementation Tests

    /// Test that default padding returns EdgeInsets.zero.
    ///
    /// **Dart Source:** `decoration.dart:69` - padding getter default
    func testDefaultPadding() {
        let decoration = TestDecoration()
        let padding = decoration.padding
        if let edgeInsets = padding as? EdgeInsets {
            XCTAssertEqual(edgeInsets, EdgeInsets.zero)
        } else {
            XCTFail("Default padding should be EdgeInsets.zero")
        }
    }

    /// Test that default isComplex returns false.
    ///
    /// **Dart Source:** `decoration.dart:72` - isComplex getter default
    func testDefaultIsComplex() {
        let decoration = TestDecoration()
        XCTAssertFalse(decoration.isComplex)
    }

    /// Test that default debugAssertIsValid returns true.
    ///
    /// **Dart Source:** `decoration.dart:41-48` - debugAssertIsValid default
    func testDefaultDebugAssertIsValid() {
        let decoration = TestDecoration()
        XCTAssertTrue(decoration.debugAssertIsValid())
    }

    /// Test that default lerpFrom returns nil.
    ///
    /// **Dart Source:** `decoration.dart:100` - lerpFrom default
    func testDefaultLerpFromReturnsNil() {
        let decoration = TestDecoration()
        let result = decoration.lerpFrom(nil, t: 0.5)
        XCTAssertNil(result)
    }

    /// Test that default lerpTo returns nil.
    ///
    /// **Dart Source:** `decoration.dart:129` - lerpTo default
    func testDefaultLerpToReturnsNil() {
        let decoration = TestDecoration()
        let result = decoration.lerpTo(nil, t: 0.5)
        XCTAssertNil(result)
    }

    /// Test that default hitTest returns true.
    ///
    /// **Dart Source:** `decoration.dart:174` - hitTest default
    func testDefaultHitTest() {
        let decoration = TestDecoration()
        let result = decoration.hitTest(
            Size(100, 100),
            Offset(50, 50)
        )
        XCTAssertTrue(result)
    }

    /// Test that default hitTest with textDirection returns true.
    ///
    /// **Dart Source:** `decoration.dart:174` - hitTest default with optional textDirection
    func testDefaultHitTestWithTextDirection() {
        let decoration = TestDecoration()
        let result = decoration.hitTest(
            Size(100, 100),
            Offset(50, 50),
            textDirection: TextDirection.ltr
        )
        XCTAssertTrue(result)
    }

    /// Test that toStringShort uses objectRuntimeType.
    ///
    /// **Dart Source:** `decoration.dart:39` - toStringShort
    func testToStringShort() {
        let decoration = TestDecoration()
        let short = decoration.toStringShort()
        XCTAssertTrue(short.contains("TestDecoration"), "toStringShort should contain the type name")
    }

    // MARK: - lerpDecoration() Tests

    /// Test lerpDecoration with both nil inputs returns nil.
    ///
    /// **Dart Test:** `decoration_test.dart:143-144` - "Decoration.lerp identical a,b"
    func testLerpDecorationBothNil() {
        let result = lerpDecoration(nil, nil, 0.0)
        XCTAssertNil(result, "lerpDecoration(nil, nil, t) should return nil")
    }

    /// Test lerpDecoration with identical a and b returns same instance.
    ///
    /// **Dart Test:** `decoration_test.dart:145-146` - "Decoration.lerp identical a,b"
    func testLerpDecorationIdentical() {
        let decoration = TestDecoration()
        let result = lerpDecoration(decoration, decoration, 0.5)
        XCTAssertTrue(result === decoration, "lerpDecoration with identical a,b should return same instance")
    }

    /// Test lerpDecoration with nil a returns b (or b.lerpFrom(nil)).
    ///
    /// **Dart Source:** `decoration.dart:139-141` - nil a handling
    func testLerpDecorationNilA() {
        let b = TestDecoration(id: 42)
        let result = lerpDecoration(nil, b, 0.5)
        // TestDecoration has default lerpFrom that returns nil, so fallback returns b
        XCTAssertTrue(result === b, "lerpDecoration(nil, b, t) should return b when lerpFrom returns nil")
    }

    /// Test lerpDecoration with nil b returns a (or a.lerpTo(nil)).
    ///
    /// **Dart Source:** `decoration.dart:142-144` - nil b handling
    func testLerpDecorationNilB() {
        let a = TestDecoration(id: 7)
        let result = lerpDecoration(a, nil, 0.5)
        // TestDecoration has default lerpTo that returns nil, so fallback returns a
        XCTAssertTrue(result === a, "lerpDecoration(a, nil, t) should return a when lerpTo returns nil")
    }

    /// Test lerpDecoration at t=0 returns a.
    ///
    /// **Dart Source:** `decoration.dart:145-147` - t == 0.0
    func testLerpDecorationAtT0() {
        let a = TestDecoration(id: 1)
        let b = TestDecoration(id: 2)
        let result = lerpDecoration(a, b, 0.0)
        XCTAssertTrue(result === a, "lerpDecoration at t=0.0 should return a")
    }

    /// Test lerpDecoration at t=1 returns b.
    ///
    /// **Dart Source:** `decoration.dart:148-150` - t == 1.0
    func testLerpDecorationAtT1() {
        let a = TestDecoration(id: 1)
        let b = TestDecoration(id: 2)
        let result = lerpDecoration(a, b, 1.0)
        XCTAssertTrue(result === b, "lerpDecoration at t=1.0 should return b")
    }

    /// Test lerpDecoration with lerpable decorations at midpoint.
    ///
    /// **Dart Test:** `decoration_test.dart:129-141` - "Decoration.lerp()"
    /// Note: Uses LerpableDecoration instead of BoxDecoration since BoxDecoration is not yet migrated.
    func testLerpDecorationWithLerpableDecorations() {
        let a = LerpableDecoration(value: 0.0)
        let b = LerpableDecoration(value: 100.0)

        // At t=0, should return a
        let at0 = lerpDecoration(a, b, 0.0)
        XCTAssertTrue(at0 === a, "At t=0, should return a")

        // At t=0.25
        let at025 = lerpDecoration(a, b, 0.25) as? LerpableDecoration
        XCTAssertNotNil(at025)
        XCTAssertEqual(at025!.value, 25.0, accuracy: 0.0001)

        // At t=0.5
        let at05 = lerpDecoration(a, b, 0.5) as? LerpableDecoration
        XCTAssertNotNil(at05)
        XCTAssertEqual(at05!.value, 50.0, accuracy: 0.0001)

        // At t=1, should return b
        let at1 = lerpDecoration(a, b, 1.0)
        XCTAssertTrue(at1 === b, "At t=1, should return b")
    }

    /// Test lerpDecoration with unrelated decorations falls back through nil.
    ///
    /// **Dart Test:** `decoration_test.dart:485-502` - "Decoration.lerp with unrelated decorations"
    /// Uses TestDecoration + UnrelatedDecoration instead of FlutterLogoDecoration + BoxDecoration.
    func testLerpDecorationWithUnrelatedDecorations() {
        let a = LerpableDecoration(value: 10.0)
        let b = UnrelatedDecoration(tag: "other")

        // At t=0 returns a
        let at0 = lerpDecoration(a, b, 0.0)
        XCTAssertTrue(at0 === a)

        // At t < 0.5, b.lerpFrom(a) returns nil, a.lerpTo(b) returns nil,
        // so falls back to a.lerpTo(nil, t*2) which returns nil, so returns a
        let at025 = lerpDecoration(a, b, 0.25)
        XCTAssertTrue(at025 === a)

        // At t >= 0.5, falls back to b.lerpFrom(nil, (t-0.5)*2) which returns nil, so returns b
        let at075 = lerpDecoration(a, b, 0.75)
        XCTAssertTrue(at075 === b)

        // At t=1 returns b
        let at1 = lerpDecoration(a, b, 1.0)
        XCTAssertTrue(at1 === b)
    }

    // MARK: - BoxPainter Tests

    /// Test BoxPainter initializer with no onChanged callback.
    ///
    /// **Dart Source:** `decoration.dart:212` - BoxPainter constructor
    func testBoxPainterDefaultInit() {
        let painter = BoxPainter()
        XCTAssertNil(painter.onChanged, "Default onChanged should be nil")
    }

    /// Test BoxPainter initializer with onChanged callback.
    ///
    /// **Dart Source:** `decoration.dart:212` - BoxPainter constructor with onChanged
    func testBoxPainterWithOnChanged() {
        var called = false
        let painter = BoxPainter(onChanged: { called = true })
        XCTAssertNotNil(painter.onChanged)

        painter.onChanged?()
        XCTAssertTrue(called, "onChanged callback should be invocable")
    }

    /// Test BoxPainter.dispose() does not throw.
    ///
    /// **Dart Source:** `decoration.dart:250-255` - dispose()
    func testBoxPainterDisposeDoesNotThrow() {
        let painter = BoxPainter()
        // Should not throw; base implementation does nothing
        painter.dispose()
    }

    /// Test BoxPainter.dispose() on a subclass does not throw.
    func testBoxPainterSubclassDisposeDoesNotThrow() {
        let painter = TestBoxPainter()
        painter.dispose()
    }

    /// Test that BoxPainter subclass can override paint.
    ///
    /// **Dart Source:** `decoration.dart:214-240` - paint() abstract method
    func testBoxPainterSubclassPaint() {
        let painter = TestBoxPainter()
        XCTAssertEqual(painter.paintCallCount, 0)

        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        painter.paint(canvas, .zero, ImageConfiguration.empty)

        XCTAssertEqual(painter.paintCallCount, 1, "paint should have been called once")
    }

    /// Test that createBoxPainter returns a usable BoxPainter.
    ///
    /// **Dart Source:** `decoration.dart:176-182` - createBoxPainter
    func testCreateBoxPainterFromDecoration() {
        let decoration = TestDecoration()
        var onChangedCalled = false
        let painter = decoration.createBoxPainter {
            onChangedCalled = true
        }

        XCTAssertNotNil(painter.onChanged)
        painter.onChanged?()
        XCTAssertTrue(onChangedCalled)
    }

    /// Test that createBoxPainter with nil onChanged works.
    func testCreateBoxPainterWithNilOnChanged() {
        let decoration = TestDecoration()
        let painter = decoration.createBoxPainter(nil)
        XCTAssertNil(painter.onChanged)
    }

    // MARK: - ImageConfiguration Tests

    /// Test ImageConfiguration.empty static property.
    ///
    /// **Dart Source:** `image_provider.dart:137` - ImageConfiguration.empty
    func testImageConfigurationEmpty() {
        let config = ImageConfiguration.empty
        XCTAssertNil(config.size)
        XCTAssertNil(config.devicePixelRatio)
        XCTAssertNil(config.textDirection)
    }

    /// Test ImageConfiguration initializer with all parameters.
    func testImageConfigurationWithParameters() {
        let config = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: TextDirection.ltr,
            size: Size(100, 200)
        )
        XCTAssertEqual(config.size, Size(100, 200))
        XCTAssertEqual(config.devicePixelRatio, 2.0)
        XCTAssertEqual(config.textDirection, TextDirection.ltr)
    }

    /// Test ImageConfiguration equality.
    func testImageConfigurationEquality() {
        let a = ImageConfiguration(devicePixelRatio: 2.0, size: Size(100, 200))
        let b = ImageConfiguration(devicePixelRatio: 2.0, size: Size(100, 200))
        let c = ImageConfiguration(size: Size(50, 50))

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
