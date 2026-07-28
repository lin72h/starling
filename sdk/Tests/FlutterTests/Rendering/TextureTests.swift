// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for TextureBox from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/texture_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - TextureBox Construction Tests

final class TextureBoxConstructionTests: XCTestCase {

    /// Test that TextureBox can be constructed with only the required textureId parameter.
    ///
    /// **Dart Source:** `texture.dart:41-47`
    func testDefaultConstruction() {
        let box = TextureBox(textureId: 1)
        XCTAssertEqual(box.textureId, 1)
        XCTAssertFalse(box.freeze)
        XCTAssertEqual(box.filterQuality, .low)
    }

    /// Test that TextureBox can be constructed with custom values for all parameters.
    ///
    /// **Dart Source:** `texture.dart:41-47`
    func testConstructionWithCustomValues() {
        let box = TextureBox(textureId: 42, freeze: true, filterQuality: .high)
        XCTAssertEqual(box.textureId, 42)
        XCTAssertTrue(box.freeze)
        XCTAssertEqual(box.filterQuality, .high)
    }

    /// Test construction with textureId of zero.
    func testConstructionWithZeroTextureId() {
        let box = TextureBox(textureId: 0)
        XCTAssertEqual(box.textureId, 0)
    }

    /// Test construction with a large textureId.
    func testConstructionWithLargeTextureId() {
        let box = TextureBox(textureId: 999999)
        XCTAssertEqual(box.textureId, 999999)
    }

    /// Test construction with freeze set to true and default filterQuality.
    func testConstructionWithFreezeOnly() {
        let box = TextureBox(textureId: 5, freeze: true)
        XCTAssertEqual(box.textureId, 5)
        XCTAssertTrue(box.freeze)
        XCTAssertEqual(box.filterQuality, .low)
    }

    /// Test construction with custom filterQuality and default freeze.
    func testConstructionWithFilterQualityOnly() {
        let box = TextureBox(textureId: 7, filterQuality: .medium)
        XCTAssertEqual(box.textureId, 7)
        XCTAssertFalse(box.freeze)
        XCTAssertEqual(box.filterQuality, .medium)
    }
}

// MARK: - TextureBox textureId Setter Tests

final class TextureBoxTextureIdSetterTests: XCTestCase {

    /// Test that setting textureId to a new value triggers markNeedsPaint.
    ///
    /// **Dart Source:** `texture.dart:49-57`
    func testTextureIdSetterTriggersMarkNeedsPaint() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.textureId = 2
        XCTAssertTrue(box.needsPaint, "Setting a new textureId should trigger markNeedsPaint")
        XCTAssertEqual(box.textureId, 2)
    }

    /// Test that setting textureId to the same value is a no-op.
    ///
    /// **Dart Source:** `texture.dart:53-55` - early return on equal
    func testTextureIdSetterNoOpOnSameValue() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.textureId = 1
        XCTAssertFalse(box.needsPaint, "Setting the same textureId should not trigger markNeedsPaint")
    }

    /// Test that setting textureId from non-zero to zero triggers markNeedsPaint.
    func testTextureIdSetterFromNonZeroToZero() {
        let box = TextureBox(textureId: 5)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.textureId = 0
        XCTAssertTrue(box.needsPaint, "Changing textureId to 0 should trigger markNeedsPaint")
        XCTAssertEqual(box.textureId, 0)
    }
}

// MARK: - TextureBox freeze Setter Tests

final class TextureBoxFreezeSetterTests: XCTestCase {

    /// Test that setting freeze to a new value triggers markNeedsPaint.
    ///
    /// **Dart Source:** `texture.dart:59-67`
    func testFreezeSetterTriggersMarkNeedsPaint() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.freeze = true
        XCTAssertTrue(box.needsPaint, "Setting freeze to true should trigger markNeedsPaint")
        XCTAssertTrue(box.freeze)
    }

    /// Test that setting freeze to the same value is a no-op.
    ///
    /// **Dart Source:** `texture.dart:63-65` - early return on equal
    func testFreezeSetterNoOpOnSameValue() {
        let box = TextureBox(textureId: 1, freeze: true)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.freeze = true
        XCTAssertFalse(box.needsPaint, "Setting the same freeze value should not trigger markNeedsPaint")
    }

    /// Test that setting freeze back to false triggers markNeedsPaint.
    func testFreezeSetterBackToFalse() {
        let box = TextureBox(textureId: 1, freeze: true)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.freeze = false
        XCTAssertTrue(box.needsPaint, "Changing freeze to false should trigger markNeedsPaint")
        XCTAssertFalse(box.freeze)
    }
}

// MARK: - TextureBox filterQuality Setter Tests

final class TextureBoxFilterQualitySetterTests: XCTestCase {

    /// Test that setting filterQuality to a new value triggers markNeedsPaint.
    ///
    /// **Dart Source:** `texture.dart:69-77`
    func testFilterQualitySetterTriggersMarkNeedsPaint() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.filterQuality = .high
        XCTAssertTrue(box.needsPaint, "Setting a new filterQuality should trigger markNeedsPaint")
        XCTAssertEqual(box.filterQuality, .high)
    }

    /// Test that setting filterQuality to the same value is a no-op.
    ///
    /// **Dart Source:** `texture.dart:73-75` - early return on equal
    func testFilterQualitySetterNoOpOnSameValue() {
        let box = TextureBox(textureId: 1, filterQuality: .high)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.filterQuality = .high
        XCTAssertFalse(box.needsPaint, "Setting the same filterQuality should not trigger markNeedsPaint")
    }

    /// Test that setting filterQuality from high to low triggers markNeedsPaint.
    func testFilterQualitySetterFromHighToLow() {
        let box = TextureBox(textureId: 1, filterQuality: .high)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.filterQuality = .low
        XCTAssertTrue(box.needsPaint, "Changing filterQuality to low should trigger markNeedsPaint")
        XCTAssertEqual(box.filterQuality, .low)
    }

    /// Test that setting filterQuality to medium triggers markNeedsPaint.
    func testFilterQualitySetterToMedium() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        box.needsPaint = false

        box.filterQuality = .medium
        XCTAssertTrue(box.needsPaint, "Changing filterQuality to medium should trigger markNeedsPaint")
        XCTAssertEqual(box.filterQuality, .medium)
    }
}

// MARK: - TextureBox Property Tests

final class TextureBoxPropertyTests: XCTestCase {

    /// Test that sizedByParent returns true.
    ///
    /// **Dart Source:** `texture.dart:80`
    func testSizedByParentReturnsTrue() {
        let box = TextureBox(textureId: 1)
        XCTAssertTrue(box.sizedByParent)
    }

    /// Test that alwaysNeedsCompositing returns true.
    ///
    /// **Dart Source:** `texture.dart:83`
    func testAlwaysNeedsCompositingReturnsTrue() {
        let box = TextureBox(textureId: 1)
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test that isRepaintBoundary returns true.
    ///
    /// **Dart Source:** `texture.dart:86`
    func testIsRepaintBoundaryReturnsTrue() {
        let box = TextureBox(textureId: 1)
        XCTAssertTrue(box.isRepaintBoundary)
    }
}

// MARK: - TextureBox hitTestSelf Tests

final class TextureBoxHitTestSelfTests: XCTestCase {

    /// Test that hitTestSelf always returns true for any position.
    ///
    /// **Dart Source:** `texture.dart:95`
    func testHitTestSelfReturnsTrue() {
        let box = TextureBox(textureId: 1)
        XCTAssertTrue(box.hitTestSelf(Offset.zero))
        XCTAssertTrue(box.hitTestSelf(Offset(10.0, 20.0)))
        XCTAssertTrue(box.hitTestSelf(Offset(-5.0, -5.0)))
        XCTAssertTrue(box.hitTestSelf(Offset(1000.0, 1000.0)))
    }

    /// Test that hitTestSelf returns true regardless of the position or texture state.
    ///
    /// **Dart Source:** `texture.dart:95`
    func testHitTestSelfReturnsTrueWithFrozenTexture() {
        let box = TextureBox(textureId: 42, freeze: true, filterQuality: .high)
        box.layout(BoxConstraints.tight(Size(200.0, 200.0)))

        XCTAssertTrue(box.hitTestSelf(Offset(50.0, 50.0)))
        XCTAssertTrue(box.hitTestSelf(Offset(0.0, 0.0)))
        XCTAssertTrue(box.hitTestSelf(Offset(199.0, 199.0)))
    }
}

// MARK: - TextureBox computeDryLayout Tests

final class TextureBoxComputeDryLayoutTests: XCTestCase {

    /// Test that computeDryLayout returns constraints.biggest.
    ///
    /// **Dart Source:** `texture.dart:88-92`
    func testComputeDryLayoutReturnsBiggest() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 400.0,
            minHeight: 0.0, maxHeight: 300.0
        )
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test that computeDryLayout returns constraints.biggest with tight constraints.
    ///
    /// **Dart Source:** `texture.dart:88-92`
    func testComputeDryLayoutWithTightConstraints() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints.tight(Size(200.0, 150.0))
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 150.0)
    }

    /// Test that computeDryLayout returns constraints.biggest even when biggest equals smallest.
    func testComputeDryLayoutTightConstraintsBiggestEqualsSmallest() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints.tight(Size(100.0, 100.0))
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size, constraints.biggest)
        XCTAssertEqual(size, constraints.smallest)
    }

    /// Test that computeDryLayout uses full available space (maxWidth, maxHeight).
    func testComputeDryLayoutUsesFullSpace() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints(
            minWidth: 50.0, maxWidth: 800.0,
            minHeight: 100.0, maxHeight: 600.0
        )
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 800.0)
        XCTAssertEqual(size.height, 600.0)
    }

    /// Test computeDryLayout with zero-size constraints.
    func testComputeDryLayoutZeroConstraints() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints.tight(Size.zero)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size, Size.zero)
    }
}

// MARK: - TextureBox Layout Integration Tests

final class TextureBoxLayoutTests: XCTestCase {

    /// Test that layout sets size to constraints.biggest since sizedByParent is true.
    ///
    /// When sizedByParent is true, layout calls performResize which uses
    /// computeDryLayout to set the size.
    ///
    /// **Dart Source:** `texture.dart:80, 88-92`
    func testLayoutSetsSizeToBiggest() {
        let box = TextureBox(textureId: 1)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 300.0,
            minHeight: 0.0, maxHeight: 200.0
        )
        box.layout(constraints)
        XCTAssertEqual(box.size, Size(300.0, 200.0))
    }

    /// Test that layout with tight constraints produces the expected size.
    func testLayoutWithTightConstraints() {
        let box = TextureBox(textureId: 1)
        box.layout(BoxConstraints.tight(Size(640.0, 480.0)))
        XCTAssertEqual(box.size, Size(640.0, 480.0))
    }
}

// MARK: - TextureLayer Tests

final class TextureLayerTests: XCTestCase {

    /// Test that TextureLayer stores all construction parameters.
    func testLayerConstruction() {
        let rect = Rect.fromLTWH(10.0, 20.0, 300.0, 200.0)
        let layer = TextureLayer(
            rect: rect,
            textureId: 42,
            freeze: true,
            filterQuality: .high
        )
        XCTAssertEqual(layer.rect, rect)
        XCTAssertEqual(layer.textureId, 42)
        XCTAssertTrue(layer.freeze)
        XCTAssertEqual(layer.filterQuality, .high)
    }

    /// Test that TextureLayer uses default parameter values.
    func testLayerDefaultValues() {
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 100.0)
        let layer = TextureLayer(rect: rect, textureId: 1)
        XCTAssertEqual(layer.rect, rect)
        XCTAssertEqual(layer.textureId, 1)
        XCTAssertFalse(layer.freeze)
        XCTAssertEqual(layer.filterQuality, .low)
    }

    /// Test that findAnnotations always returns false (texture layers are leaves).
    func testFindAnnotationsReturnsFalse() {
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 100.0)
        let layer = TextureLayer(rect: rect, textureId: 1)
        let result = AnnotationResult<Int>()
        let found = layer.findAnnotations(result, Offset(50.0, 50.0), onlyFirst: true)
        XCTAssertFalse(found)
    }
}
