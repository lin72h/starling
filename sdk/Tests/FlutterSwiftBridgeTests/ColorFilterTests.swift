// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Migrated from: engine/src/flutter/testing/dart/color_filter_test.dart

import Testing
@testable import FlutterSwiftBridge

// MARK: - Test Constants

/// Transparent color (ARGB: 0x00000000)
private let transparentColor = Color(0x00000000)

/// Red color (ARGB: 0xFFAA0000)
private let redColor = Color(0xFFAA0000)

/// Green color (ARGB: 0xFF00AA00)
private let greenColor = Color(0xFF00AA00)

/// Greyscale color matrix - converts colors to grayscale using luminance weights.
///
/// **Dart Source:** `color_filter_test.dart` uses similar matrices for testing.
/// This matrix uses standard luminance coefficients (0.2126, 0.7152, 0.0722).
private let greyscaleColorMatrix: [Double] = [
    0.2126, 0.7152, 0.0722, 0, 0,  // Red output
    0.2126, 0.7152, 0.0722, 0, 0,  // Green output
    0.2126, 0.7152, 0.0722, 0, 0,  // Blue output
    0, 0, 0, 1, 0                   // Alpha output (unchanged)
]

/// Identity color matrix - passes colors through unchanged.
///
/// **Dart Source:** `color_filter_test.dart:123` - 'ColorFilter - NOP matrix does not crash'
/// This is the 5x4 identity matrix for RGBA color transformation.
private let identityColorMatrix: [Double] = [
    1, 0, 0, 0, 0,  // Red output (unchanged)
    0, 1, 0, 0, 0,  // Green output (unchanged)
    0, 0, 1, 0, 0,  // Blue output (unchanged)
    0, 0, 0, 1, 0   // Alpha output (unchanged)
]

// MARK: - ColorFilter Tests

@Suite("ColorFilter Tests")
struct ColorFilterTests {
    // MARK: - Constructor Tests

    /// Tests that ColorFilter mode constructor creates a valid filter.
    ///
    /// **Dart Source:** `color_filter_test.dart` - mode filter construction
    ///
    /// Verifies:
    /// - Filter can be created without crash
    /// - filterType == 1 (mode type)
    /// - filterColor matches input color
    /// - filterBlendMode matches input blend mode
    @Test("ColorFilter mode constructor creates valid filter")
    func testColorFilterModeConstructor() {
        // Create a mode filter with red color and .color blend mode
        let color = Color(0xFFAA0000)
        let blendMode = BlendMode.color
        let filter = ColorFilter(mode: color, blendMode)

        // Verify filter type is mode (1)
        #expect(filter.filterType == 1)

        // Verify filter color matches input
        #expect(filter.filterColor != nil)
        #expect(filter.filterColor!.toARGB32() == color.toARGB32())

        // Verify filter blend mode matches input
        #expect(filter.filterBlendMode != nil)
        #expect(filter.filterBlendMode == blendMode)
    }

    /// Tests that ColorFilter matrix constructor creates a valid filter.
    ///
    /// **Dart Source:** `color_filter_test.dart` - matrix filter construction
    ///
    /// Verifies:
    /// - Filter can be created without crash
    /// - filterType == 2 (matrix type)
    /// - filterMatrix matches input matrix (20 elements)
    @Test("ColorFilter matrix constructor creates valid filter")
    func testColorFilterMatrixConstructor() {
        // Create a matrix filter with greyscale matrix
        let filter = ColorFilter(matrix: greyscaleColorMatrix)

        // Verify filter type is matrix (2)
        #expect(filter.filterType == 2)

        // Verify filter matrix matches input (20 elements)
        #expect(filter.filterMatrix != nil)
        #expect(filter.filterMatrix!.count == 20)

        // Verify each element of the matrix matches
        for i in 0..<20 {
            #expect(filter.filterMatrix![i] == greyscaleColorMatrix[i])
        }
    }

    /// Tests that ColorFilter linearToSrgbGamma constructor creates a valid filter.
    ///
    /// **Dart Source:** `color_filter_test.dart:141` - 'ColorFilter - linearToSrgbGamma'
    ///
    /// Verifies:
    /// - Filter can be created without crash
    /// - filterType == 3 (linearToSrgbGamma type)
    @Test("ColorFilter linearToSrgbGamma constructor creates valid filter")
    func testColorFilterLinearToSrgbGammaConstructor() {
        // Create a linearToSrgbGamma filter
        let filter = ColorFilter(linearToSrgbGamma: ())

        // Verify filter type is linearToSrgbGamma (3)
        #expect(filter.filterType == 3)
    }

    /// Tests that ColorFilter srgbToLinearGamma constructor creates a valid filter.
    ///
    /// **Dart Source:** `color_filter_test.dart:158` - 'ColorFilter - srgbToLinearGamma'
    ///
    /// Verifies:
    /// - Filter can be created without crash
    /// - filterType == 4 (srgbToLinearGamma type)
    @Test("ColorFilter srgbToLinearGamma constructor creates valid filter")
    func testColorFilterSrgbToLinearGammaConstructor() {
        // Create a srgbToLinearGamma filter
        let filter = ColorFilter(srgbToLinearGamma: ())

        // Verify filter type is srgbToLinearGamma (4)
        #expect(filter.filterType == 4)
    }

    // MARK: - Equality & Hashing Tests

    /// Tests equality for mode filters.
    ///
    /// **Dart Source:** `color_filter_test.dart` - Dart uses == operator for ColorFilter equality.
    ///
    /// Verifies:
    /// - Two filters with same color and blend mode should be equal
    /// - Two filters with different colors should not be equal
    /// - Two filters with different blend modes should not be equal
    /// - Mode filter should not equal matrix filter
    @Test("ColorFilter mode equality")
    func testColorFilterModeEquality() {
        // Create two filters with same color and blend mode
        let filter1 = ColorFilter(mode: redColor, .color)
        let filter2 = ColorFilter(mode: redColor, .color)

        // Two filters with same color and blend mode should be equal
        #expect(filter1 == filter2)

        // Create filter with different color
        let filterDifferentColor = ColorFilter(mode: greenColor, .color)

        // Two filters with different colors should not be equal
        #expect(filter1 != filterDifferentColor)

        // Create filter with different blend mode
        let filterDifferentBlendMode = ColorFilter(mode: redColor, .srcOver)

        // Two filters with different blend modes should not be equal
        #expect(filter1 != filterDifferentBlendMode)

        // Create matrix filter
        let matrixFilter = ColorFilter(matrix: greyscaleColorMatrix)

        // Mode filter should not equal matrix filter
        #expect(filter1 != matrixFilter)
    }

    /// Tests equality for matrix filters.
    ///
    /// **Dart Source:** `color_filter_test.dart` - Dart uses == operator for ColorFilter equality.
    ///
    /// Verifies:
    /// - Two filters with same matrix should be equal
    /// - Two filters with different matrices should not be equal
    /// - Matrix filter should not equal gamma filter
    @Test("ColorFilter matrix equality")
    func testColorFilterMatrixEquality() {
        // Create two filters with same matrix
        let filter1 = ColorFilter(matrix: greyscaleColorMatrix)
        let filter2 = ColorFilter(matrix: greyscaleColorMatrix)

        // Two filters with same matrix should be equal
        #expect(filter1 == filter2)

        // Create filter with different matrix (identity matrix)
        let filterDifferentMatrix = ColorFilter(matrix: identityColorMatrix)

        // Two filters with different matrices should not be equal
        #expect(filter1 != filterDifferentMatrix)

        // Create gamma filter
        let gammaFilter = ColorFilter(linearToSrgbGamma: ())

        // Matrix filter should not equal gamma filter
        #expect(filter1 != gammaFilter)
    }

    /// Tests Hashable conformance for ColorFilter.
    ///
    /// **Dart Source:** `color_filter_test.dart` - Dart ColorFilter has hashCode property.
    ///
    /// Verifies:
    /// - Equal filters should have equal hash values
    /// - Different filters (mode vs matrix vs gamma) should have different hash values (in most cases)
    /// - Verify filters can be used in a Set
    @Test("ColorFilter hashing")
    func testColorFilterHashing() {
        // Create equal mode filters
        let modeFilter1 = ColorFilter(mode: redColor, .color)
        let modeFilter2 = ColorFilter(mode: redColor, .color)

        // Equal filters should have equal hash values
        #expect(modeFilter1.hashValue == modeFilter2.hashValue)

        // Create equal matrix filters
        let matrixFilter1 = ColorFilter(matrix: greyscaleColorMatrix)
        let matrixFilter2 = ColorFilter(matrix: greyscaleColorMatrix)

        // Equal filters should have equal hash values
        #expect(matrixFilter1.hashValue == matrixFilter2.hashValue)

        // Create different types of filters
        let gammaFilter = ColorFilter(linearToSrgbGamma: ())
        let srgbFilter = ColorFilter(srgbToLinearGamma: ())

        // Different filter types should generally have different hash values
        // Note: Hash collisions are possible but unlikely for different filter types
        // We test that filters can be distinguished in a Set instead of relying on hash inequality
        var filterSet = Set<ColorFilter>()
        filterSet.insert(modeFilter1)
        filterSet.insert(matrixFilter1)
        filterSet.insert(gammaFilter)
        filterSet.insert(srgbFilter)

        // Verify all four distinct filters are in the set
        #expect(filterSet.count == 4)

        // Verify equal filters don't add duplicates
        filterSet.insert(modeFilter2)      // Equal to modeFilter1
        filterSet.insert(matrixFilter2)    // Equal to matrixFilter1

        // Count should still be 4 (no duplicates added)
        #expect(filterSet.count == 4)

        // Verify the set contains all expected filters
        #expect(filterSet.contains(modeFilter1))
        #expect(filterSet.contains(matrixFilter1))
        #expect(filterSet.contains(gammaFilter))
        #expect(filterSet.contains(srgbFilter))
    }

    // MARK: - Description Tests

    /// Tests CustomStringConvertible conformance for ColorFilter.
    ///
    /// **Dart Source:** `color_filter_test.dart` - Dart ColorFilter has toString() method.
    ///
    /// Verifies:
    /// - Mode filter description should contain "ColorFilter.mode"
    /// - Matrix filter description should contain "ColorFilter.matrix"
    /// - LinearToSrgbGamma filter description should be "ColorFilter.linearToSrgbGamma()"
    /// - SrgbToLinearGamma filter description should be "ColorFilter.srgbToLinearGamma()"
    @Test("ColorFilter description")
    func testColorFilterDescription() {
        // Test mode filter description
        let modeFilter = ColorFilter(mode: redColor, .color)
        let modeDescription = modeFilter.description

        // Mode filter description should contain "ColorFilter.mode"
        #expect(modeDescription.contains("ColorFilter.mode"))

        // Test matrix filter description
        let matrixFilter = ColorFilter(matrix: greyscaleColorMatrix)
        let matrixDescription = matrixFilter.description

        // Matrix filter description should contain "ColorFilter.matrix"
        #expect(matrixDescription.contains("ColorFilter.matrix"))

        // Test linearToSrgbGamma filter description
        let linearToSrgbFilter = ColorFilter(linearToSrgbGamma: ())
        let linearToSrgbDescription = linearToSrgbFilter.description

        // LinearToSrgbGamma filter description should be exact
        #expect(linearToSrgbDescription == "ColorFilter.linearToSrgbGamma()")

        // Test srgbToLinearGamma filter description
        let srgbToLinearFilter = ColorFilter(srgbToLinearGamma: ())
        let srgbToLinearDescription = srgbToLinearFilter.description

        // SrgbToLinearGamma filter description should be exact
        #expect(srgbToLinearDescription == "ColorFilter.srgbToLinearGamma()")
    }

    // MARK: - No-Crash Tests

    /// Tests that creating a NOP (no-operation) mode filter does not crash.
    ///
    /// **Dart Source:** `color_filter_test.dart:87` - 'ColorFilter - NOP mode does not crash'
    ///
    /// A transparent color with srcOver blend mode is a NOP (no visible effect).
    /// The original Dart test used Canvas/Picture/Scene rendering to verify no crash
    /// during the render pipeline. Since the rendering pipeline is not yet available
    /// for testing, we verify no crash when:
    /// - Creating the filter
    /// - Calling toNativeColorFilter()
    @Test("ColorFilter NOP mode does not crash")
    func testColorFilterNopModeDoesNotCrash() {
        // Create a NOP mode filter: transparent color with srcOver blend mode
        // This combination has no visible effect (NOP = no operation)
        let filter = ColorFilter(mode: transparentColor, .srcOver)

        // Verify filter was created successfully (no crash)
        #expect(filter.filterType == 1)

        // Verify we can create a native color filter without crash
        // If this line executes without crashing, the test passes
        let nativeFilter = filter.toNativeColorFilter()

        // Verify native filter was created successfully by checking its creator
        // The creator property holds the original ColorFilter that was used
        #expect(nativeFilter.creator.filterType == 1)
    }

    /// Tests that creating a NOP (no-operation) matrix filter does not crash.
    ///
    /// **Dart Source:** `color_filter_test.dart:123` - 'ColorFilter - NOP matrix does not crash'
    ///
    /// An identity matrix is a NOP (no visible effect - colors pass through unchanged).
    /// The original Dart test used Canvas/Picture/Scene rendering to verify no crash
    /// during the render pipeline. Since the rendering pipeline is not yet available
    /// for testing, we verify no crash when:
    /// - Creating the filter
    /// - Calling toNativeColorFilter()
    @Test("ColorFilter NOP matrix does not crash")
    func testColorFilterNopMatrixDoesNotCrash() {
        // Create a NOP matrix filter: identity matrix
        // This matrix passes colors through unchanged (NOP = no operation)
        let filter = ColorFilter(matrix: identityColorMatrix)

        // Verify filter was created successfully (no crash)
        #expect(filter.filterType == 2)

        // Verify we can create a native color filter without crash
        // If this line executes without crashing, the test passes
        let nativeFilter = filter.toNativeColorFilter()

        // Verify native filter was created successfully by checking its creator
        // The creator property holds the original ColorFilter that was used
        #expect(nativeFilter.creator.filterType == 2)
    }
}
