// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for AssetImage and image resolution logic.
///
/// **Dart Test Source:** `packages/flutter/test/painting/image_resolution_test.dart`
///
/// Note: The Dart tests use a TestAssetBundle with a full asset manifest pipeline
/// (StandardMessageCodec, AssetManifest.bin, etc.) to test via `obtainKey`. Since
/// the Swift migration uses stub services, we test the variant selection algorithm
/// directly via `chooseVariant` (made internal for testing) while testing basic
/// AssetImage properties through the public API.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal AssetBundle implementation for testing.
///
/// This does not need to load actual data; it just provides identity for
/// bundle comparisons in AssetBundleImageKey.
private final class _TestAssetBundle: AssetBundle, @unchecked Sendable {
    func load(_ key: String) async throws -> [UInt8] {
        fatalError("Not implemented for tests")
    }

    func loadBuffer(_ key: String) async throws -> ImmutableBuffer {
        fatalError("Not implemented for tests")
    }

    func loadString(_ key: String, cache: Bool) async throws -> String {
        fatalError("Not implemented for tests")
    }

    func loadStructuredData<T>(_ key: String, parser: @escaping (String) async throws -> T) async throws -> T {
        fatalError("Not implemented for tests")
    }

    func loadStructuredBinaryData<T>(_ key: String, parser: @escaping ([UInt8]) async throws -> T) async throws -> T {
        fatalError("Not implemented for tests")
    }

    func evict(_ key: String) {
        // No-op
    }
}

/// Helper to call `AssetImage`'s value-based `==` operator via static dispatch.
///
/// `AssetImage` inherits `Equatable` from `ImageProvider<Key>`, whose `==` uses
/// identity (`===`). `AssetImage` overrides `==` with value-based semantics
/// (comparing `keyName` and bundle identity). Because `Equatable` conformance
/// is declared on the parent class, dynamic dispatch (e.g., in `Set` or
/// `XCTAssertEqual`) uses the parent's `==`. This helper forces static dispatch
/// to the `AssetImage`-specific operator.
private func assetImagesEqual(_ lhs: AssetImage, _ rhs: AssetImage) -> Bool {
    return lhs == rhs
}

// MARK: - AssetImage Basic Tests

final class AssetImageBasicTests: XCTestCase {

    // MARK: - Construction

    /// Test that AssetImage can be constructed with just a name.
    func testConstructionWithDefaults() {
        let image = AssetImage("heart.png")
        XCTAssertEqual(image.assetName, "heart.png")
        XCTAssertNil(image.bundle)
        XCTAssertNil(image.package)
    }

    /// Test that AssetImage can be constructed with all parameters.
    func testConstructionWithAllParameters() {
        let bundle = _TestAssetBundle()
        let image = AssetImage("heart.png", bundle: bundle, package: "my_icons")
        XCTAssertEqual(image.assetName, "heart.png")
        XCTAssertTrue(image.bundle === bundle)
        XCTAssertEqual(image.package, "my_icons")
    }

    // MARK: - keyName

    /// Test that keyName returns assetName when no package is specified.
    ///
    /// **Dart Source:** `image_resolution.dart:252`
    func testKeyNameWithoutPackage() {
        let image = AssetImage("assets/icon.png")
        XCTAssertEqual(image.keyName, "assets/icon.png")
    }

    /// Test that keyName includes the package prefix when package is specified.
    ///
    /// **Dart Source:** `image_resolution.dart:252`
    func testKeyNameWithPackage() {
        let image = AssetImage("icon.png", package: "my_icons")
        XCTAssertEqual(image.keyName, "packages/my_icons/icon.png")
    }

    /// Test keyName with nested asset paths and package.
    func testKeyNameWithNestedPathAndPackage() {
        let image = AssetImage("images/icons/heart.png", package: "design_system")
        XCTAssertEqual(image.keyName, "packages/design_system/images/icons/heart.png")
    }

    // MARK: - Equality

    /// Test that two AssetImages with the same name are equal (no bundle).
    ///
    /// Note: `AssetImage` is a class that inherits `Equatable` from `ImageProvider`.
    /// The inherited conformance uses identity (`===`), but `AssetImage` overrides
    /// `==` with value-based equality on `keyName` and `bundle`. We call the
    /// `AssetImage`-specific `==` operator via a helper to ensure static dispatch
    /// picks the correct overload.
    func testEqualityWithSameName() {
        let a = AssetImage("heart.png")
        let b = AssetImage("heart.png")
        XCTAssertTrue(assetImagesEqual(a, b), "AssetImages with the same name should be equal")
    }

    /// Test that two AssetImages with the same name and same bundle are equal.
    func testEqualityWithSameBundle() {
        let bundle = _TestAssetBundle()
        let a = AssetImage("heart.png", bundle: bundle)
        let b = AssetImage("heart.png", bundle: bundle)
        XCTAssertTrue(assetImagesEqual(a, b), "AssetImages with the same name and bundle should be equal")
    }

    /// Test that two AssetImages with different names are not equal.
    func testInequalityWithDifferentNames() {
        let a = AssetImage("heart.png")
        let b = AssetImage("star.png")
        XCTAssertFalse(assetImagesEqual(a, b), "AssetImages with different names should not be equal")
    }

    /// Test that two AssetImages with different bundles are not equal.
    func testInequalityWithDifferentBundles() {
        let bundleA = _TestAssetBundle()
        let bundleB = _TestAssetBundle()
        let a = AssetImage("heart.png", bundle: bundleA)
        let b = AssetImage("heart.png", bundle: bundleB)
        XCTAssertFalse(assetImagesEqual(a, b), "AssetImages with different bundles should not be equal")
    }

    /// Test that package affects equality via keyName.
    func testEqualityConsidersPackage() {
        let a = AssetImage("icon.png", package: "pkg_a")
        let b = AssetImage("icon.png", package: "pkg_b")
        XCTAssertFalse(assetImagesEqual(a, b), "AssetImages with different packages should not be equal")
    }

    /// Test that same name with and without package are not equal.
    func testEqualityWithAndWithoutPackage() {
        let a = AssetImage("icon.png")
        let b = AssetImage("icon.png", package: "my_pkg")
        XCTAssertFalse(assetImagesEqual(a, b), "AssetImages with/without package should not be equal")
    }

    // MARK: - Hashing

    /// Helper: compute hash value from AssetImage's hash(into:) method.
    private func computeHash(_ image: AssetImage) -> Int {
        var hasher = Hasher()
        image.hash(into: &hasher)
        return hasher.finalize()
    }

    /// Test that logically equal AssetImages produce the same hash value.
    ///
    /// AssetImage overrides `hash(into:)` to hash on `keyName` and bundle identity,
    /// matching its value-based `==` operator.
    func testHashConsistency() {
        let bundle = _TestAssetBundle()
        let a = AssetImage("heart.png", bundle: bundle)
        let b = AssetImage("heart.png", bundle: bundle)
        XCTAssertEqual(computeHash(a), computeHash(b), "Logically equal AssetImages should have the same hash")
    }

    /// Test that different AssetImages produce different hash values (not guaranteed but likely).
    func testDifferentImagesHaveDifferentHashes() {
        let a = AssetImage("heart.png")
        let b = AssetImage("star.png")
        // This is probabilistic but almost certainly true for different key names
        XCTAssertNotEqual(computeHash(a), computeHash(b), "Different AssetImages should likely have different hashes")
    }

    // MARK: - Description

    /// Test that description contains the class name and key name.
    ///
    /// **Dart Source:** `image_resolution.dart:400-401`
    func testDescription() {
        let image = AssetImage("heart.png")
        let desc = image.description
        XCTAssertTrue(desc.contains("AssetImage"), "Description should contain the class name")
        XCTAssertTrue(desc.contains("heart.png"), "Description should contain the asset name")
    }

    /// Test that description includes the package in the key name.
    func testDescriptionWithPackage() {
        let image = AssetImage("icon.png", package: "my_icons")
        let desc = image.description
        XCTAssertTrue(
            desc.contains("packages/my_icons/icon.png"),
            "Description should contain the full key name including package prefix"
        )
    }

    /// Test that description includes bundle info.
    func testDescriptionShowsBundle() {
        let image = AssetImage("heart.png")
        let desc = image.description
        XCTAssertTrue(desc.contains("bundle:"), "Description should contain 'bundle:'")
        XCTAssertTrue(desc.contains("name:"), "Description should contain 'name:'")
    }
}

// MARK: - Variant Selection Algorithm Tests

/// Tests for the variant selection algorithm (chooseVariant / findBestVariant).
///
/// These tests port the key logic from the Dart test file lines 188-244,
/// which test the algorithm when assets available are 1.0 and 3.0.
///
/// **Dart Test Source:** `image_resolution_test.dart:188-244`
final class VariantSelectionAlgorithmTests: XCTestCase {

    /// Helper: creates an AssetImage and calls chooseVariant with the given
    /// device pixel ratio and candidate variants.
    ///
    /// This mirrors the Dart `buildBundleAndTestVariantLogic` helper.
    private func chooseVariantForDpr(
        _ deviceRatio: Double,
        mainAssetPath: String = "assets/normalFolder/normalFile.png",
        variants: [AssetMetadata]
    ) -> AssetMetadata {
        let image = AssetImage(mainAssetPath)
        let config = ImageConfiguration(devicePixelRatio: deviceRatio)
        return image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config,
            candidateVariants: variants
        )
    }

    /// The standard test variants: 1.0x main asset and 3.0x variant.
    ///
    /// This matches the Dart test manifest:
    /// ```dart
    /// 'assets/normalFolder/normalFile.png': [
    ///   {'asset': 'assets/normalFolder/normalFile.png'},
    ///   {'asset': 'assets/normalFolder/3.0x/normalFile.png', 'dpr': 3.0},
    /// ]
    /// ```
    private var standardVariants: [AssetMetadata] {
        return [
            AssetMetadata(
                key: "assets/normalFolder/normalFile.png",
                targetDevicePixelRatio: nil,
                main: true
            ),
            AssetMetadata(
                key: "assets/normalFolder/3.0x/normalFile.png",
                targetDevicePixelRatio: 3.0,
                main: false
            ),
        ]
    }

    private let mainAssetPath = "assets/normalFolder/normalFile.png"
    private let variantPath = "assets/normalFolder/3.0x/normalFile.png"

    // MARK: - chooseVariant with no candidates

    /// Test that chooseVariant returns the main asset when there are no candidates.
    func testChooseVariantWithNoCandidates() {
        let image = AssetImage(mainAssetPath)
        let config = ImageConfiguration(devicePixelRatio: 3.0)
        let result = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config,
            candidateVariants: nil
        )
        XCTAssertEqual(result.key, mainAssetPath)
        XCTAssertNil(result.targetDevicePixelRatio)
        XCTAssertTrue(result.main)
    }

    /// Test that chooseVariant returns the main asset when candidates array is empty.
    func testChooseVariantWithEmptyCandidates() {
        let image = AssetImage(mainAssetPath)
        let config = ImageConfiguration(devicePixelRatio: 3.0)
        let result = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config,
            candidateVariants: []
        )
        XCTAssertEqual(result.key, mainAssetPath)
        XCTAssertNil(result.targetDevicePixelRatio)
    }

    /// Test that chooseVariant returns the main asset when devicePixelRatio is nil.
    func testChooseVariantWithNoDevicePixelRatio() {
        let image = AssetImage(mainAssetPath)
        let config = ImageConfiguration()
        let result = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config,
            candidateVariants: standardVariants
        )
        XCTAssertEqual(result.key, mainAssetPath)
        XCTAssertNil(result.targetDevicePixelRatio)
    }

    // MARK: - Obvious exact matches (Dart test lines 221-227)

    /// Test: device ratio 1.0 selects the 1.0 asset (exact match).
    ///
    /// **Dart Test:** `image_resolution_test.dart:221-223`
    /// `test('Obvious case 1.0 - we have exact asset')`
    func testDeviceRatio1_0SelectsMainAsset() {
        let result = chooseVariantForDpr(1.0, variants: standardVariants)
        XCTAssertEqual(result.key, mainAssetPath, "Device ratio 1.0 should select the 1.0x main asset")
        // targetDevicePixelRatio is nil for the main asset (natural resolution)
        XCTAssertNil(result.targetDevicePixelRatio)
    }

    /// Test: device ratio 3.0 selects the 3.0 asset (exact match).
    ///
    /// **Dart Test:** `image_resolution_test.dart:225-227`
    /// `test('Obvious case 3.0 - we have exact asset')`
    func testDeviceRatio3_0SelectsVariantAsset() {
        let result = chooseVariantForDpr(3.0, variants: standardVariants)
        XCTAssertEqual(result.key, variantPath, "Device ratio 3.0 should select the 3.0x variant asset")
        XCTAssertEqual(result.targetDevicePixelRatio, 3.0)
    }

    // MARK: - Low DPR threshold behavior (Dart test lines 229-238)

    /// Test: device ratio 2.0 selects the 1.0 asset (at kLowDprLimit boundary).
    ///
    /// When the device ratio is exactly at kLowDprLimit (2.0), the algorithm
    /// considers this a "low DPR" device. With candidates 1.0 and 3.0,
    /// the midpoint is 2.0. Since value (2.0) < kLowDprLimit (2.0) is false,
    /// and value (2.0) > midpoint (2.0) is also false, we choose the lower
    /// variant (1.0).
    ///
    /// **Dart Test:** `image_resolution_test.dart:229-231`
    /// `test('Typical case 2.0')`
    func testDeviceRatio2_0SelectsMainAsset() {
        let result = chooseVariantForDpr(2.0, variants: standardVariants)
        XCTAssertEqual(result.key, mainAssetPath, "Device ratio 2.0 should select the 1.0x asset")
        XCTAssertNil(result.targetDevicePixelRatio)
    }

    /// Test: device ratio 2.01 selects the 3.0 asset (just above threshold).
    ///
    /// With candidates 1.0 and 3.0, midpoint is 2.0. Value (2.01) > midpoint
    /// (2.0) is true, so we choose the upper variant (3.0).
    ///
    /// **Dart Test:** `image_resolution_test.dart:233-235`
    /// `test('Borderline case 2.01')`
    func testDeviceRatio2_01SelectsVariantAsset() {
        let result = chooseVariantForDpr(2.01, variants: standardVariants)
        XCTAssertEqual(result.key, variantPath, "Device ratio 2.01 should select the 3.0x variant asset")
        XCTAssertEqual(result.targetDevicePixelRatio, 3.0)
    }

    /// Test: device ratio 2.9 selects the 3.0 asset.
    ///
    /// **Dart Test:** `image_resolution_test.dart:236-238`
    /// `test('Borderline case 2.9')`
    func testDeviceRatio2_9SelectsVariantAsset() {
        let result = chooseVariantForDpr(2.9, variants: standardVariants)
        XCTAssertEqual(result.key, variantPath, "Device ratio 2.9 should select the 3.0x variant asset")
        XCTAssertEqual(result.targetDevicePixelRatio, 3.0)
    }

    // MARK: - Beyond highest available (Dart test lines 240-242)

    /// Test: device ratio 4.0 selects the 3.0 asset (highest available).
    ///
    /// When the device ratio is higher than any available variant, the algorithm
    /// returns the highest available variant.
    ///
    /// **Dart Test:** `image_resolution_test.dart:240-242`
    /// `test('Typical case 4.0')`
    func testDeviceRatio4_0SelectsHighestVariant() {
        let result = chooseVariantForDpr(4.0, variants: standardVariants)
        XCTAssertEqual(result.key, variantPath, "Device ratio 4.0 should select the 3.0x variant (highest available)")
        XCTAssertEqual(result.targetDevicePixelRatio, 3.0)
    }

    // MARK: - Below lowest available

    /// Test: device ratio below the lowest variant selects the lowest.
    func testDeviceRatioBelowLowestSelectsLowest() {
        let result = chooseVariantForDpr(0.5, variants: standardVariants)
        // 0.5 is below 1.0, so should select the 1.0x asset (lowest available)
        XCTAssertEqual(result.key, mainAssetPath, "Device ratio 0.5 should select the lowest available (1.0x)")
    }

    // MARK: - Low DPR behavior with more granular variants

    /// Test that on a low DPR screen (< 2.0), higher resolution is preferred
    /// to avoid visible upscaling artifacts.
    ///
    /// With variants at 1.0 and 2.0, a device ratio of 1.5 is below kLowDprLimit.
    /// The algorithm should prefer the higher resolution variant (2.0).
    func testLowDprPrefersHigherResolution() {
        let variants: [AssetMetadata] = [
            AssetMetadata(key: "assets/img.png", targetDevicePixelRatio: nil, main: true),
            AssetMetadata(key: "assets/2.0x/img.png", targetDevicePixelRatio: 2.0, main: false),
        ]
        let result = chooseVariantForDpr(1.5, mainAssetPath: "assets/img.png", variants: variants)
        // 1.5 < kLowDprLimit (2.0), so algorithm prefers higher resolution
        XCTAssertEqual(result.key, "assets/2.0x/img.png", "Low DPR should prefer higher resolution variant")
        XCTAssertEqual(result.targetDevicePixelRatio, 2.0)
    }

    // MARK: - High DPR behavior prefers nearest

    /// Test that on a high DPR screen (> 2.0), the nearest variant is chosen
    /// to save memory.
    ///
    /// With variants at 2.0 and 4.0, a device ratio of 2.5 is above kLowDprLimit.
    /// Midpoint of 2.0 and 4.0 is 3.0. Since 2.5 < 3.0, the lower (2.0) is chosen.
    func testHighDprPrefersNearest() {
        let variants: [AssetMetadata] = [
            AssetMetadata(key: "assets/2.0x/img.png", targetDevicePixelRatio: 2.0, main: false),
            AssetMetadata(key: "assets/4.0x/img.png", targetDevicePixelRatio: 4.0, main: false),
        ]
        let result = chooseVariantForDpr(2.5, mainAssetPath: "assets/img.png", variants: variants)
        // 2.5 >= kLowDprLimit, midpoint = 3.0, 2.5 < 3.0 => choose lower (2.0)
        XCTAssertEqual(result.key, "assets/2.0x/img.png", "High DPR should prefer nearest (lower) variant")
        XCTAssertEqual(result.targetDevicePixelRatio, 2.0)
    }

    /// Test that on a high DPR screen above the midpoint, the upper variant is chosen.
    ///
    /// With variants at 2.0 and 4.0, a device ratio of 3.5 is above the midpoint (3.0).
    func testHighDprAboveMidpointPrefersUpper() {
        let variants: [AssetMetadata] = [
            AssetMetadata(key: "assets/2.0x/img.png", targetDevicePixelRatio: 2.0, main: false),
            AssetMetadata(key: "assets/4.0x/img.png", targetDevicePixelRatio: 4.0, main: false),
        ]
        let result = chooseVariantForDpr(3.5, mainAssetPath: "assets/img.png", variants: variants)
        // 3.5 >= kLowDprLimit, midpoint = 3.0, 3.5 > 3.0 => choose upper (4.0)
        XCTAssertEqual(result.key, "assets/4.0x/img.png", "High DPR above midpoint should prefer upper variant")
        XCTAssertEqual(result.targetDevicePixelRatio, 4.0)
    }

    // MARK: - Single variant only

    /// Test that a single variant is always chosen regardless of device ratio.
    func testSingleVariantAlwaysChosen() {
        let variants: [AssetMetadata] = [
            AssetMetadata(key: "assets/2.0x/img.png", targetDevicePixelRatio: 2.0, main: false),
        ]
        // Below the variant
        let result1 = chooseVariantForDpr(1.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(result1.key, "assets/2.0x/img.png")
        // At the variant
        let result2 = chooseVariantForDpr(2.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(result2.key, "assets/2.0x/img.png")
        // Above the variant
        let result3 = chooseVariantForDpr(4.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(result3.key, "assets/2.0x/img.png")
    }

    // MARK: - Multiple variants (1.0, 2.0, 3.0, 4.0)

    /// Test variant selection across a full range of available variants.
    func testMultipleVariantsSelection() {
        let variants: [AssetMetadata] = [
            AssetMetadata(key: "assets/img.png", targetDevicePixelRatio: nil, main: true),
            AssetMetadata(key: "assets/2.0x/img.png", targetDevicePixelRatio: 2.0, main: false),
            AssetMetadata(key: "assets/3.0x/img.png", targetDevicePixelRatio: 3.0, main: false),
            AssetMetadata(key: "assets/4.0x/img.png", targetDevicePixelRatio: 4.0, main: false),
        ]

        // Exact match 1.0
        let r1 = chooseVariantForDpr(1.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r1.key, "assets/img.png")

        // Exact match 2.0
        let r2 = chooseVariantForDpr(2.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r2.key, "assets/2.0x/img.png")

        // Exact match 3.0
        let r3 = chooseVariantForDpr(3.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r3.key, "assets/3.0x/img.png")

        // Exact match 4.0
        let r4 = chooseVariantForDpr(4.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r4.key, "assets/4.0x/img.png")

        // 1.5: low DPR (<2.0), prefers higher => 2.0x
        let r5 = chooseVariantForDpr(1.5, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r5.key, "assets/2.0x/img.png")

        // 5.0: above highest => 4.0x
        let r6 = chooseVariantForDpr(5.0, mainAssetPath: "assets/img.png", variants: variants)
        XCTAssertEqual(r6.key, "assets/4.0x/img.png")
    }
}

// MARK: - 1.0 Scale Device Tests (Dart test lines 57-113)

/// Tests for 1.0 scale device behavior when the asset is the main variant.
///
/// These tests verify that when an AssetImage is constructed and no variants
/// are found in the manifest (or the manifest returns nil), the main asset
/// is returned at scale 1.0.
///
/// **Dart Test Source:** `image_resolution_test.dart:57-113`
final class AssetImageScaleOneTests: XCTestCase {

    /// Helper: constructs an AssetImage and calls chooseVariant with no candidates
    /// and no device pixel ratio (1.0 scale device behavior).
    private func testMainAssetReturned(for path: String) {
        let image = AssetImage(path)
        let config = ImageConfiguration()
        let result = image.chooseVariant(
            mainAssetKey: path,
            config: config,
            candidateVariants: nil
        )
        XCTAssertEqual(result.key, path, "Main asset path should be returned")
        XCTAssertNil(result.targetDevicePixelRatio, "Scale should be nil (natural resolution 1.0)")
        XCTAssertTrue(result.main, "Result should be marked as main asset")
    }

    /// Test: normal folder path returns main asset at scale 1.0.
    ///
    /// **Dart Test:** `image_resolution_test.dart:78-80`
    func testNormalFolderAsset() {
        testMainAssetReturned(for: "assets/normalFolder/normalFile.png")
    }

    /// Test: path containing "3.0x" in its own name still returns as main at 1.0.
    ///
    /// **Dart Test:** `image_resolution_test.dart:82-87`
    func testPathContaining3xAsMainAsset() {
        testMainAssetReturned(for: "assets/parentFolder/3.0x/normalFile.png")
    }

    /// Test: parent folder containing variant-like name returns main at 1.0.
    ///
    /// **Dart Test:** `image_resolution_test.dart:89-94`
    func testParentFolderWithVariantName() {
        testMainAssetReturned(for: "assets/parentFolder/__3.0x__/leafFolder/normalFile.png")
    }

    /// Test: leaf folder containing variant-like name returns main at 1.0.
    ///
    /// **Dart Test:** `image_resolution_test.dart:96-101`
    func testLeafFolderWithVariantName() {
        testMainAssetReturned(for: "assets/parentFolder/__3.0x_leaf_folder_/normalFile.png")
    }

    /// Test: variant identifier in parent folder returns main at 1.0.
    ///
    /// **Dart Test:** `image_resolution_test.dart:110-112`
    func testVariantIdentifierInParentFolder() {
        testMainAssetReturned(for: "assets/parentFolder/3.0x/leafFolder/normalFile.png")
    }
}

// MARK: - High-Res Device Behavior Tests (Dart test lines 115-186)

/// Tests for high-resolution device behavior.
///
/// **Dart Test Source:** `image_resolution_test.dart:115-186`
final class AssetImageHighResTests: XCTestCase {

    private let mainAssetPath = "assets/normalFolder/normalFile.png"
    private let variantPath = "assets/normalFolder/3.0x/normalFile.png"

    /// Test: with a 3.0x variant available, 1.0 device gets main asset,
    /// 3.0 device gets the variant.
    ///
    /// **Dart Test:** `image_resolution_test.dart:116-148`
    func testVariantSelectedForHighResDevice() {
        let image = AssetImage(mainAssetPath)
        let variants: [AssetMetadata] = [
            AssetMetadata(key: variantPath, targetDevicePixelRatio: 3.0, main: false),
        ]

        // Device at 1.0 with no devicePixelRatio => main asset
        let configEmpty = ImageConfiguration()
        let resultEmpty = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: configEmpty,
            candidateVariants: variants
        )
        XCTAssertEqual(resultEmpty.key, mainAssetPath, "No DPR config should return main asset")

        // Device at 3.0 => variant asset
        let config3 = ImageConfiguration(devicePixelRatio: 3.0)
        let result3 = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config3,
            candidateVariants: variants
        )
        XCTAssertEqual(result3.key, variantPath, "3.0 device should select the 3.0x variant")
        XCTAssertEqual(result3.targetDevicePixelRatio, 3.0)
    }

    /// Test: when high-res variant is not present, high-res device gets main asset.
    ///
    /// **Dart Test:** `image_resolution_test.dart:150-185`
    func testMainAssetWhenNoHighResVariant() {
        let image = AssetImage(mainAssetPath)

        // Empty candidates: high-res device should still get main asset
        let config3 = ImageConfiguration(devicePixelRatio: 3.0)
        let result = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config3,
            candidateVariants: []
        )
        XCTAssertEqual(result.key, mainAssetPath, "No variants available should return main asset")
        XCTAssertNil(result.targetDevicePixelRatio)
    }

    /// Test: when only the main asset is in the candidates, it is returned for any DPR.
    func testOnlyMainAssetInCandidates() {
        let image = AssetImage(mainAssetPath)
        let variants: [AssetMetadata] = [
            AssetMetadata(key: mainAssetPath, targetDevicePixelRatio: nil, main: true),
        ]

        let config3 = ImageConfiguration(devicePixelRatio: 3.0)
        let result = image.chooseVariant(
            mainAssetKey: mainAssetPath,
            config: config3,
            candidateVariants: variants
        )
        // The only candidate has dpr = nil, which becomes 1.0 (naturalResolution)
        XCTAssertEqual(result.key, mainAssetPath)
    }
}
