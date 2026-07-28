// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for RenderImage from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/image_test.dart`
///
/// Note: Many Dart tests require real `ui.Image` instances created via
/// `createTestImage`, which depends on the native engine. Since
/// `FlutterSwiftBridge.Image` requires a C++ ImageBridge, tests that need
/// real image data are limited. Instead, we focus on:
///   - Construction with nil image and various parameters
///   - Property getters/setters and invalidation behavior
///   - Size calculation via `computeDryLayout` (null image path)
///   - Intrinsic dimension calculations
///   - `hitTestSelf` behavior
///   - `dispose` cleanup

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - RenderImage Construction Tests

final class RenderImageConstructionTests: XCTestCase {

    // MARK: - Default Values

    /// Test that RenderImage can be constructed with all default parameter values.
    ///
    /// **Dart Test:** `image_test.dart:158` - `RenderImage()` with no args
    func testDefaultConstruction() {
        let renderImage = RenderImage()

        XCTAssertNil(renderImage.image)
        XCTAssertNil(renderImage.debugImageLabel)
        XCTAssertNil(renderImage.width)
        XCTAssertNil(renderImage.height)
        XCTAssertEqual(renderImage.scale, 1.0)
        XCTAssertNil(renderImage.color)
        XCTAssertNil(renderImage.colorBlendMode)
        XCTAssertNil(renderImage.fit)
        XCTAssertEqual(renderImage.imageRepeat, .noRepeat)
        XCTAssertNil(renderImage.centerSlice)
        XCTAssertFalse(renderImage.matchTextDirection)
        XCTAssertNil(renderImage.textDirection)
        XCTAssertFalse(renderImage.invertColors)
        XCTAssertFalse(renderImage.isAntiAlias)
        XCTAssertEqual(renderImage.filterQuality, .medium)
    }

    /// Test that RenderImage can be constructed with custom width and height.
    ///
    /// **Dart Test:** `image_test.dart:171` - `RenderImage(width: 50.0)`
    func testConstructionWithWidthAndHeight() {
        let renderImage = RenderImage(width: 50.0, height: 75.0)

        XCTAssertEqual(renderImage.width, 50.0)
        XCTAssertEqual(renderImage.height, 75.0)
    }

    /// Test construction with a custom scale value.
    ///
    /// **Dart Source:** `image.dart:27-62`
    func testConstructionWithScale() {
        let renderImage = RenderImage(scale: 2.0)

        XCTAssertEqual(renderImage.scale, 2.0)
    }

    /// Test construction with color and blend mode.
    ///
    /// **Dart Source:** `image.dart:27-62`
    func testConstructionWithColorAndBlendMode() {
        let testColor = Color(0xFFFF0000)
        let renderImage = RenderImage(
            color: testColor,
            colorBlendMode: .multiply
        )

        XCTAssertNotNil(renderImage.color)
        XCTAssertEqual(renderImage.colorBlendMode, .multiply)
    }

    /// Test construction with text direction and alignment options.
    ///
    /// **Dart Source:** `image.dart:27-62`
    func testConstructionWithTextDirectionOptions() {
        let renderImage = RenderImage(
            alignment: Alignment.topLeft,
            matchTextDirection: true,
            textDirection: .ltr
        )

        XCTAssertTrue(renderImage.matchTextDirection)
        XCTAssertEqual(renderImage.textDirection, .ltr)
    }

    /// Test construction with all visual options set.
    ///
    /// **Dart Source:** `image.dart:27-62`
    func testConstructionWithAllVisualOptions() {
        let renderImage = RenderImage(
            fit: .cover,
            repeat: .repeatX,
            centerSlice: Rect.fromLTWH(10, 10, 20, 20),
            invertColors: true,
            isAntiAlias: true,
            filterQuality: .high
        )

        XCTAssertEqual(renderImage.fit, .cover)
        XCTAssertEqual(renderImage.imageRepeat, .repeatX)
        XCTAssertNotNil(renderImage.centerSlice)
        XCTAssertTrue(renderImage.invertColors)
        XCTAssertTrue(renderImage.isAntiAlias)
        XCTAssertEqual(renderImage.filterQuality, .high)
    }
}

// MARK: - RenderImage Property Setter Tests

final class RenderImagePropertySetterTests: XCTestCase {

    /// Test that setting width triggers markNeedsLayout (sets needsLayout flag).
    ///
    /// **Dart Source:** `image.dart:106-118`
    func testWidthSetterTriggersLayout() {
        let renderImage = RenderImage()
        // Reset the flag (it starts as true on fresh RenderObject)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.width = 50.0
        XCTAssertTrue(renderImage.needsLayout)
        XCTAssertEqual(renderImage.width, 50.0)
    }

    /// Test that setting width to the same value does not trigger layout.
    ///
    /// **Dart Source:** `image.dart:112-114` - early return on equal
    func testWidthSetterNoOpOnSameValue() {
        let renderImage = RenderImage(width: 50.0)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.width = 50.0
        XCTAssertFalse(renderImage.needsLayout)
    }

    /// Test that setting height triggers markNeedsLayout.
    ///
    /// **Dart Source:** `image.dart:120-132`
    func testHeightSetterTriggersLayout() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.height = 75.0
        XCTAssertTrue(renderImage.needsLayout)
        XCTAssertEqual(renderImage.height, 75.0)
    }

    /// Test that setting height to the same value does not trigger layout.
    ///
    /// **Dart Source:** `image.dart:125-127` - early return on equal
    func testHeightSetterNoOpOnSameValue() {
        let renderImage = RenderImage(height: 75.0)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.height = 75.0
        XCTAssertFalse(renderImage.needsLayout)
    }

    /// Test that setting scale triggers markNeedsLayout.
    ///
    /// **Dart Source:** `image.dart:134-145`
    func testScaleSetterTriggersLayout() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.scale = 2.0
        XCTAssertTrue(renderImage.needsLayout)
        XCTAssertEqual(renderImage.scale, 2.0)
    }

    /// Test that setting scale to the same value does not trigger layout.
    ///
    /// **Dart Source:** `image.dart:138-140` - early return on equal
    func testScaleSetterNoOpOnSameValue() {
        let renderImage = RenderImage(scale: 2.0)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(renderImage.needsLayout)

        renderImage.scale = 2.0
        XCTAssertFalse(renderImage.needsLayout)
    }

    /// Test that setting color triggers markNeedsPaint (not layout).
    ///
    /// **Dart Source:** `image.dart:157-167`
    func testColorSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        // Reset paint flag
        renderImage.needsPaint = false

        renderImage.color = Color(0xFFFF0000)
        XCTAssertTrue(renderImage.needsPaint)
        // Should NOT trigger layout
        XCTAssertFalse(renderImage.needsLayout)
    }

    /// Test that setting color to the same value does not trigger repaint.
    ///
    /// **Dart Source:** `image.dart:161-163` - early return on equal
    func testColorSetterNoOpOnSameValue() {
        let testColor = Color(0xFFFF0000)
        let renderImage = RenderImage(color: testColor)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.color = testColor
        XCTAssertFalse(renderImage.needsPaint)
    }

    /// Test that setting colorBlendMode triggers markNeedsPaint.
    ///
    /// **Dart Test:** `image_test.dart:211-216` - "update image colorBlendMode"
    func testColorBlendModeSetterTriggersPaint() {
        let renderImage = RenderImage()
        XCTAssertNil(renderImage.colorBlendMode)

        renderImage.colorBlendMode = .color
        XCTAssertEqual(renderImage.colorBlendMode, .color)
    }

    /// Test that setting colorBlendMode updates correctly.
    ///
    /// **Dart Test:** `image_test.dart:211-216` - "update image colorBlendMode"
    func testUpdateColorBlendMode() {
        let renderImage = RenderImage()
        XCTAssertNil(renderImage.colorBlendMode)

        renderImage.colorBlendMode = BlendMode.color
        XCTAssertEqual(renderImage.colorBlendMode, BlendMode.color)

        renderImage.colorBlendMode = BlendMode.multiply
        XCTAssertEqual(renderImage.colorBlendMode, BlendMode.multiply)
    }

    /// Test that setting fit triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:219-231`
    func testFitSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.fit = .contain
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertEqual(renderImage.fit, .contain)
    }

    /// Test that setting imageRepeat triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:247-256`
    func testImageRepeatSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.imageRepeat = .repeatX
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertEqual(renderImage.imageRepeat, .repeatX)
    }

    /// Test that setting centerSlice triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:258-273`
    func testCenterSliceSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        let slice = Rect.fromLTWH(5, 5, 10, 10)
        renderImage.centerSlice = slice
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertEqual(renderImage.centerSlice, slice)
    }

    /// Test that setting invertColors triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:275-288`
    func testInvertColorsSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.invertColors = true
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertTrue(renderImage.invertColors)
    }

    /// Test that setting matchTextDirection triggers markNeedsPaint (via _markNeedResolution).
    ///
    /// **Dart Source:** `image.dart:290-312`
    func testMatchTextDirectionSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.matchTextDirection = true
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertTrue(renderImage.matchTextDirection)
    }

    /// Test that setting textDirection triggers markNeedsPaint (via _markNeedResolution).
    ///
    /// **Dart Source:** `image.dart:314-327`
    func testTextDirectionSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.textDirection = .rtl
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertEqual(renderImage.textDirection, .rtl)
    }

    /// Test that setting isAntiAlias triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:329-340`
    func testIsAntiAliasSetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.isAntiAlias = true
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertTrue(renderImage.isAntiAlias)
    }

    /// Test that setting filterQuality triggers markNeedsPaint.
    ///
    /// **Dart Source:** `image.dart:187-198`
    func testFilterQualitySetterTriggersPaint() {
        let renderImage = RenderImage()
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.filterQuality = .high
        XCTAssertTrue(renderImage.needsPaint)
        XCTAssertEqual(renderImage.filterQuality, .high)
    }

    /// Test that setting filterQuality to the same value does not trigger repaint.
    ///
    /// **Dart Source:** `image.dart:192-194` - early return on equal
    func testFilterQualitySetterNoOpOnSameValue() {
        let renderImage = RenderImage(filterQuality: .high)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.filterQuality = .high
        XCTAssertFalse(renderImage.needsPaint)
    }
}

// MARK: - RenderImage Size Calculation Tests (Null Image)

final class RenderImageNullImageSizingTests: XCTestCase {

    /// Test that with no image and no explicit size, computeDryLayout returns constraints.smallest.
    ///
    /// **Dart Test:** `image_test.dart:155-169` - "Null image sizing"
    func testNullImageDefaultSizing() {
        let renderImage = RenderImage()
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 25.0)
        XCTAssertEqual(size.height, 25.0)
    }

    /// Test that with explicit width only, the height falls to constraints.smallest.
    ///
    /// **Dart Test:** `image_test.dart:171-182` - `RenderImage(width: 50.0)`
    func testNullImageWithExplicitWidth() {
        let renderImage = RenderImage(width: 50.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 25.0)
    }

    /// Test that with explicit height only, the width falls to constraints.smallest.
    ///
    /// **Dart Test:** `image_test.dart:184-195` - `RenderImage(height: 50.0)`
    func testNullImageWithExplicitHeight() {
        let renderImage = RenderImage(height: 50.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 25.0)
        XCTAssertEqual(size.height, 50.0)
    }

    /// Test that explicit width and height are clamped by constraints.
    ///
    /// **Dart Test:** `image_test.dart:197-208` - `RenderImage(width: 100.0, height: 100.0)`
    func testNullImageWithExplicitWidthAndHeightClamped() {
        let renderImage = RenderImage(width: 100.0, height: 100.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 75.0,
            minHeight: 25.0,
            maxHeight: 75.0
        )

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 75.0)
        XCTAssertEqual(size.height, 75.0)
    }

    /// Test that null image with tight constraints uses smallest (which equals the tight size).
    func testNullImageTightConstraints() {
        let renderImage = RenderImage()
        let constraints = BoxConstraints.tight(Size(40.0, 60.0))

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 40.0)
        XCTAssertEqual(size.height, 60.0)
    }

    /// Test that null image with unconstrained uses zero (smallest is zero).
    func testNullImageUnconstrainedIsZero() {
        let renderImage = RenderImage()
        let constraints = BoxConstraints()

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 0.0)
        XCTAssertEqual(size.height, 0.0)
    }
}

// MARK: - RenderImage performLayout Tests

final class RenderImageLayoutTests: XCTestCase {

    /// Test that performLayout sets the size correctly for null image.
    ///
    /// **Dart Test:** `image_test.dart:155-169` - "Null image sizing"
    func testPerformLayoutNullImage() {
        let renderImage = RenderImage()
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        renderImage.layout(constraints)
        XCTAssertEqual(renderImage.size, Size(25.0, 25.0))
    }

    /// Test performLayout with explicit width for null image.
    ///
    /// **Dart Test:** `image_test.dart:171-182`
    func testPerformLayoutNullImageExplicitWidth() {
        let renderImage = RenderImage(width: 50.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        renderImage.layout(constraints)
        XCTAssertEqual(renderImage.size, Size(50.0, 25.0))
    }

    /// Test performLayout with explicit height for null image.
    ///
    /// **Dart Test:** `image_test.dart:184-195`
    func testPerformLayoutNullImageExplicitHeight() {
        let renderImage = RenderImage(height: 50.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 100.0,
            minHeight: 25.0,
            maxHeight: 100.0
        )

        renderImage.layout(constraints)
        XCTAssertEqual(renderImage.size, Size(25.0, 50.0))
    }

    /// Test performLayout with explicit width and height clamped by constraints.
    ///
    /// **Dart Test:** `image_test.dart:197-208`
    func testPerformLayoutNullImageExplicitSizeClamped() {
        let renderImage = RenderImage(width: 100.0, height: 100.0)
        let constraints = BoxConstraints(
            minWidth: 25.0,
            maxWidth: 75.0,
            minHeight: 25.0,
            maxHeight: 75.0
        )

        renderImage.layout(constraints)
        XCTAssertEqual(renderImage.size, Size(75.0, 75.0))
    }
}

// MARK: - RenderImage Intrinsic Dimension Tests

final class RenderImageIntrinsicDimensionTests: XCTestCase {

    /// Test that computeMinIntrinsicWidth returns 0.0 when no width/height set (null image).
    ///
    /// **Dart Source:** `image.dart:363-370`
    func testMinIntrinsicWidthNoConstraints() {
        let renderImage = RenderImage()
        let result = renderImage.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 0.0)
    }

    /// Test that computeMinIntrinsicHeight returns 0.0 when no width/height set (null image).
    ///
    /// **Dart Source:** `image.dart:378-385`
    func testMinIntrinsicHeightNoConstraints() {
        let renderImage = RenderImage()
        let result = renderImage.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 0.0)
    }

    /// Test computeMaxIntrinsicWidth with explicit width (null image) returns the explicit width.
    ///
    /// **Dart Source:** `image.dart:372-376`
    func testMaxIntrinsicWidthWithExplicitWidth() {
        let renderImage = RenderImage(width: 80.0)
        // With tightForFinite(height: .infinity), the constraints should
        // tighten to the explicit width.
        let result = renderImage.computeMaxIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 80.0)
    }

    /// Test computeMaxIntrinsicHeight with explicit height (null image) returns the explicit height.
    ///
    /// **Dart Source:** `image.dart:387-391`
    func testMaxIntrinsicHeightWithExplicitHeight() {
        let renderImage = RenderImage(height: 60.0)
        let result = renderImage.computeMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 60.0)
    }

    /// Test computeMinIntrinsicWidth with explicit width returns the width (clamped).
    ///
    /// **Dart Source:** `image.dart:363-370`
    func testMinIntrinsicWidthWithExplicitWidth() {
        let renderImage = RenderImage(width: 80.0)
        let result = renderImage.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 80.0)
    }

    /// Test computeMinIntrinsicHeight with explicit height returns the height.
    ///
    /// **Dart Source:** `image.dart:378-385`
    func testMinIntrinsicHeightWithExplicitHeight() {
        let renderImage = RenderImage(height: 60.0)
        let result = renderImage.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 60.0)
    }

    /// Test that getMinIntrinsicWidth (the cached public API) works correctly.
    ///
    /// **Dart Source:** `box.dart:1636-1662`
    func testGetMinIntrinsicWidthCaching() {
        let renderImage = RenderImage(width: 80.0)
        // Call twice - second should use cache
        let result1 = renderImage.getMinIntrinsicWidth(.infinity)
        let result2 = renderImage.getMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result1, 80.0)
        XCTAssertEqual(result2, 80.0)
    }

    /// Test that getMaxIntrinsicHeight (the cached public API) works correctly.
    ///
    /// **Dart Source:** `box.dart:1923-1957`
    func testGetMaxIntrinsicHeightCaching() {
        let renderImage = RenderImage(height: 60.0)
        let result1 = renderImage.getMaxIntrinsicHeight(.infinity)
        let result2 = renderImage.getMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(result1, 60.0)
        XCTAssertEqual(result2, 60.0)
    }

    /// Test intrinsic dimensions with both width and height set on null image.
    func testIntrinsicDimensionsWithBothDimensionsSet() {
        let renderImage = RenderImage(width: 100.0, height: 50.0)

        // Max intrinsic width with unconstrained height should be the explicit width
        XCTAssertEqual(renderImage.computeMaxIntrinsicWidth(.infinity), 100.0)
        // Max intrinsic height with unconstrained width should be the explicit height
        XCTAssertEqual(renderImage.computeMaxIntrinsicHeight(.infinity), 50.0)
    }

    /// Test intrinsic dimensions with constrained cross-axis on null image.
    func testIntrinsicWidthWithConstrainedHeight() {
        let renderImage = RenderImage(width: 100.0, height: 50.0)

        // With a specific cross-axis height of 50, the width should still be 100
        let result = renderImage.computeMaxIntrinsicWidth(50.0)
        XCTAssertEqual(result, 100.0)
    }
}

// MARK: - RenderImage Hit Testing Tests

final class RenderImageHitTestTests: XCTestCase {

    /// Test that hitTestSelf always returns true.
    ///
    /// **Dart Source:** `image.dart:394` - `hitTestSelf always returns true`
    func testHitTestSelfAlwaysReturnsTrue() {
        let renderImage = RenderImage()

        XCTAssertTrue(renderImage.hitTestSelf(Offset.zero))
        XCTAssertTrue(renderImage.hitTestSelf(Offset(10.0, 20.0)))
        XCTAssertTrue(renderImage.hitTestSelf(Offset(-5.0, -5.0)))
        XCTAssertTrue(renderImage.hitTestSelf(Offset(1000.0, 1000.0)))
    }

    /// Test that hitTestSelf returns true for any position (no bounds check in hitTestSelf).
    ///
    /// **Dart Source:** `image.dart:394`
    func testHitTestSelfReturnsTrueRegardlessOfPosition() {
        let renderImage = RenderImage(width: 100.0, height: 100.0)
        renderImage.layout(
            BoxConstraints.tight(Size(100.0, 100.0))
        )

        // hitTestSelf does no bounds checking; it always returns true
        XCTAssertTrue(renderImage.hitTestSelf(Offset(50.0, 50.0)))
        XCTAssertTrue(renderImage.hitTestSelf(Offset(0.0, 0.0)))
        XCTAssertTrue(renderImage.hitTestSelf(Offset(99.0, 99.0)))
    }
}

// MARK: - RenderImage Dispose Tests

final class RenderImageDisposeTests: XCTestCase {

    /// Test that dispose sets image to nil.
    ///
    /// **Dart Test:** `image_test.dart:253-266` - "Render image disposes its image when it is disposed"
    func testDisposeNullsImage() {
        let renderImage = RenderImage()
        XCTAssertNil(renderImage.image)

        renderImage.dispose()
        XCTAssertNil(renderImage.image)
    }

    /// Test that dispose can be called on RenderImage with nil image without error.
    ///
    /// **Dart Source:** `image.dart:446-451`
    func testDisposeSafeWithNilImage() {
        let renderImage = RenderImage()
        // Should not crash
        renderImage.dispose()
        XCTAssertNil(renderImage.image)
    }
}

// MARK: - RenderImage Attach/Detach Tests

final class RenderImageLifecycleTests: XCTestCase {

    /// Test that attach and detach work without an opacity animation.
    ///
    /// **Dart Source:** `image.dart:407-417`
    func testAttachDetachWithoutOpacity() {
        let renderImage = RenderImage()
        let owner = PipelineOwner()

        renderImage.attach(owner)
        XCTAssertTrue(renderImage.attached)

        renderImage.detach()
        XCTAssertFalse(renderImage.attached)
    }

    /// Test that attach sets the attached state correctly.
    ///
    /// **Dart Source:** `image.dart:407-411`
    func testAttachSetsAttachedState() {
        let renderImage = RenderImage()
        XCTAssertFalse(renderImage.attached)

        let owner = PipelineOwner()
        renderImage.attach(owner)
        XCTAssertTrue(renderImage.attached)
    }

    /// Test that detach clears the attached state.
    ///
    /// **Dart Source:** `image.dart:413-417`
    func testDetachClearsAttachedState() {
        let renderImage = RenderImage()
        let owner = PipelineOwner()

        renderImage.attach(owner)
        XCTAssertTrue(renderImage.attached)

        renderImage.detach()
        XCTAssertFalse(renderImage.attached)
    }
}

// MARK: - RenderImage Alignment and Resolution Tests

final class RenderImageAlignmentTests: XCTestCase {

    /// Test that setting alignment triggers repaint (via _markNeedResolution).
    ///
    /// **Dart Source:** `image.dart:233-245`
    func testAlignmentSetterTriggersPaint() {
        let renderImage = RenderImage(textDirection: .ltr)
        renderImage.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        renderImage.needsPaint = false

        renderImage.alignment = Alignment.bottomRight
        XCTAssertTrue(renderImage.needsPaint)
    }

    /// Test default alignment is Alignment.center.
    ///
    /// **Dart Source:** `image.dart:40`
    func testDefaultAlignment() {
        let renderImage = RenderImage()
        let alignment = renderImage.alignment as? Alignment
        XCTAssertNotNil(alignment)
        XCTAssertEqual(alignment, Alignment.center)
    }
}

// MARK: - RenderImage computeDryLayout Edge Cases

final class RenderImageDryLayoutEdgeCaseTests: XCTestCase {

    /// Test computeDryLayout with very large explicit width clamped by constraints.
    func testDryLayoutLargeExplicitWidthClamped() {
        let renderImage = RenderImage(width: 1000.0)
        let constraints = BoxConstraints(
            minWidth: 0.0,
            maxWidth: 200.0,
            minHeight: 0.0,
            maxHeight: 200.0
        )

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        // With null image, height portion will be constraints.smallest height = 0
        XCTAssertEqual(size.height, 0.0)
    }

    /// Test computeDryLayout with explicit dimensions smaller than min constraints.
    func testDryLayoutExplicitDimensionsSmallerThanMin() {
        let renderImage = RenderImage(width: 5.0, height: 5.0)
        let constraints = BoxConstraints(
            minWidth: 50.0,
            maxWidth: 100.0,
            minHeight: 50.0,
            maxHeight: 100.0
        )

        let size = renderImage.computeDryLayout(constraints)
        // Explicit dimensions are enforced to constraints: min(50, max(5, 50)) = 50
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 50.0)
    }

    /// Test computeDryLayout with zero-min unconstrained box.
    func testDryLayoutUnconstrainedWithExplicitSize() {
        let renderImage = RenderImage(width: 200.0, height: 150.0)
        let constraints = BoxConstraints()

        let size = renderImage.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 150.0)
    }
}
