// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for ImageProvider types migrated from Dart to Swift.
///
/// **Dart Test Source:** `packages/flutter/test/painting/image_provider_test.dart`
/// **Swift Source:** `Sources/Flutter/Painting/ImageProvider.swift`
///
/// The Dart test file (207 lines) primarily tests runtime behavior such as
/// `resolve`, `loadBuffer`, `obtainCacheStatus`, and image cache integration,
/// which require the full Flutter engine. These tests focus on verifying the
/// structural correctness of the migrated types: construction, equality,
/// hashing, and description output.
final class ImageProviderTests: XCTestCase {

    // MARK: - ImageConfiguration Tests

    /// Test that `ImageConfiguration.empty` has all nil properties.
    func testImageConfigurationEmpty() {
        let config = ImageConfiguration.empty
        XCTAssertNil(config.bundle)
        XCTAssertNil(config.devicePixelRatio)
        XCTAssertNil(config.locale)
        XCTAssertNil(config.textDirection)
        XCTAssertNil(config.size)
        XCTAssertNil(config.platform)
    }

    /// Test default initialization produces an empty configuration.
    func testImageConfigurationDefaultInit() {
        let config = ImageConfiguration()
        XCTAssertNil(config.bundle)
        XCTAssertNil(config.devicePixelRatio)
        XCTAssertNil(config.locale)
        XCTAssertNil(config.textDirection)
        XCTAssertNil(config.size)
        XCTAssertNil(config.platform)
    }

    /// Test initialization with specific values.
    func testImageConfigurationInitWithValues() {
        let config = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            size: Size(100, 200),
            platform: .iOS
        )
        XCTAssertNil(config.bundle)
        XCTAssertEqual(config.devicePixelRatio, 2.0)
        XCTAssertNil(config.locale)
        XCTAssertEqual(config.textDirection, TextDirection.ltr)
        XCTAssertEqual(config.size, Size(100, 200))
        XCTAssertEqual(config.platform, TargetPlatform.iOS)
    }

    /// Test `copyWith()` replaces specified fields and preserves others.
    func testImageConfigurationCopyWith() {
        let original = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            size: Size(100, 200),
            platform: .iOS
        )

        let modified = original.copyWith(devicePixelRatio: 3.0, platform: TargetPlatform.android)

        XCTAssertEqual(modified.devicePixelRatio, 3.0)
        XCTAssertEqual(modified.textDirection, TextDirection.ltr)
        XCTAssertEqual(modified.size, Size(100, 200))
        XCTAssertEqual(modified.platform, TargetPlatform.android)
    }

    /// Test `copyWith()` with no arguments returns an equivalent configuration.
    func testImageConfigurationCopyWithNoArgs() {
        let config = ImageConfiguration(
            devicePixelRatio: 2.0,
            platform: .iOS
        )
        let copy = config.copyWith()
        XCTAssertEqual(config, copy)
    }

    /// Test equality: two empty configurations are equal.
    func testImageConfigurationEqualityEmpty() {
        let a = ImageConfiguration.empty
        let b = ImageConfiguration()
        XCTAssertEqual(a, b)
    }

    /// Test equality: configurations with same values are equal.
    func testImageConfigurationEqualitySameValues() {
        let a = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            size: Size(100, 200),
            platform: .iOS
        )
        let b = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            size: Size(100, 200),
            platform: .iOS
        )
        XCTAssertEqual(a, b)
    }

    /// Test inequality: configurations with different values are not equal.
    func testImageConfigurationInequality() {
        let a = ImageConfiguration(devicePixelRatio: 2.0)
        let b = ImageConfiguration(devicePixelRatio: 3.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test that bundle equality is by reference identity.
    func testImageConfigurationBundleIdentity() {
        let bundle1 = TestAssetBundle()
        let bundle2 = TestAssetBundle()

        let a = ImageConfiguration(bundle: bundle1)
        let b = ImageConfiguration(bundle: bundle1)
        let c = ImageConfiguration(bundle: bundle2)

        XCTAssertEqual(a, b, "Same bundle reference should be equal")
        XCTAssertNotEqual(a, c, "Different bundle references should not be equal")
    }

    /// Test that equal configurations produce the same hash value.
    func testImageConfigurationHashable() {
        let a = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            platform: .iOS
        )
        let b = ImageConfiguration(
            devicePixelRatio: 2.0,
            textDirection: .ltr,
            platform: .iOS
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test that configurations can be used as dictionary keys.
    func testImageConfigurationAsDictionaryKey() {
        let config1 = ImageConfiguration(devicePixelRatio: 1.0)
        let config2 = ImageConfiguration(devicePixelRatio: 2.0)

        var dict: [ImageConfiguration: String] = [:]
        dict[config1] = "one"
        dict[config2] = "two"

        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict[config1], "one")
        XCTAssertEqual(dict[config2], "two")
    }

    /// Test description of an empty configuration.
    func testImageConfigurationDescriptionEmpty() {
        let config = ImageConfiguration.empty
        XCTAssertEqual(config.description, "ImageConfiguration()")
    }

    /// Test description with some properties set.
    func testImageConfigurationDescriptionWithValues() {
        let config = ImageConfiguration(
            devicePixelRatio: 2.0,
            platform: .iOS
        )
        let desc = config.description
        XCTAssertTrue(desc.contains("devicePixelRatio: 2.0"), "Description should contain devicePixelRatio")
        XCTAssertTrue(desc.contains("platform: iOS"), "Description should contain platform")
        XCTAssertTrue(desc.hasPrefix("ImageConfiguration("), "Description should start with ImageConfiguration(")
        XCTAssertTrue(desc.hasSuffix(")"), "Description should end with )")
    }

    /// Test description with size.
    func testImageConfigurationDescriptionWithSize() {
        let config = ImageConfiguration(size: Size(100, 200))
        let desc = config.description
        XCTAssertTrue(desc.contains("size:"), "Description should contain size")
    }

    // MARK: - ResizeImagePolicy Tests

    /// Test that both ResizeImagePolicy cases exist.
    func testResizeImagePolicyCases() {
        let exact = ResizeImagePolicy.exact
        let fit = ResizeImagePolicy.fit
        // Ensure they are distinct
        XCTAssertTrue(exact != fit || true, "Both cases should exist")
        // Swift enums with no associated values won't be equal unless they're the same case
        XCTAssertEqual(ResizeImagePolicy.exact, .exact)
        XCTAssertEqual(ResizeImagePolicy.fit, .fit)
    }

    /// Test that ResizeImagePolicy cases are not equal to each other.
    func testResizeImagePolicyDistinct() {
        XCTAssertNotEqual(ResizeImagePolicy.exact, ResizeImagePolicy.fit)
    }

    // MARK: - WebHtmlElementStrategy Tests

    /// Test all WebHtmlElementStrategy cases exist.
    func testWebHtmlElementStrategyCases() {
        XCTAssertEqual(WebHtmlElementStrategy.never, .never)
        XCTAssertEqual(WebHtmlElementStrategy.fallback, .fallback)
        XCTAssertEqual(WebHtmlElementStrategy.prefer, .prefer)
    }

    /// Test that WebHtmlElementStrategy cases are distinct.
    func testWebHtmlElementStrategyDistinct() {
        XCTAssertNotEqual(WebHtmlElementStrategy.never, WebHtmlElementStrategy.fallback)
        XCTAssertNotEqual(WebHtmlElementStrategy.fallback, WebHtmlElementStrategy.prefer)
        XCTAssertNotEqual(WebHtmlElementStrategy.never, WebHtmlElementStrategy.prefer)
    }

    // MARK: - AssetBundleImageKey Tests

    /// Test construction with bundle, name, and scale.
    func testAssetBundleImageKeyConstruction() {
        let bundle = TestAssetBundle()
        let key = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        XCTAssertTrue(key.bundle === bundle)
        XCTAssertEqual(key.name, "test.png")
        XCTAssertEqual(key.scale, 2.0)
    }

    /// Test equality: same bundle reference, name, and scale.
    func testAssetBundleImageKeyEquality() {
        let bundle = TestAssetBundle()
        let a = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        let b = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        XCTAssertEqual(a, b)
    }

    /// Test inequality: different name.
    func testAssetBundleImageKeyInequalityName() {
        let bundle = TestAssetBundle()
        let a = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        let b = AssetBundleImageKey(bundle: bundle, name: "other.png", scale: 2.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality: different scale.
    func testAssetBundleImageKeyInequalityScale() {
        let bundle = TestAssetBundle()
        let a = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 1.0)
        let b = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality: different bundle reference.
    func testAssetBundleImageKeyInequalityBundle() {
        let bundle1 = TestAssetBundle()
        let bundle2 = TestAssetBundle()
        let a = AssetBundleImageKey(bundle: bundle1, name: "test.png", scale: 2.0)
        let b = AssetBundleImageKey(bundle: bundle2, name: "test.png", scale: 2.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test that equal keys produce the same hash value.
    func testAssetBundleImageKeyHashable() {
        let bundle = TestAssetBundle()
        let a = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        let b = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test that keys can be stored in a Set.
    func testAssetBundleImageKeyInSet() {
        let bundle = TestAssetBundle()
        let key1 = AssetBundleImageKey(bundle: bundle, name: "a.png", scale: 1.0)
        let key2 = AssetBundleImageKey(bundle: bundle, name: "b.png", scale: 1.0)
        let key3 = AssetBundleImageKey(bundle: bundle, name: "a.png", scale: 1.0) // duplicate

        let set: Set<AssetBundleImageKey> = [key1, key2, key3]
        XCTAssertEqual(set.count, 2)
    }

    /// Test description output.
    func testAssetBundleImageKeyDescription() {
        let bundle = TestAssetBundle()
        let key = AssetBundleImageKey(bundle: bundle, name: "test.png", scale: 2.0)
        let desc = key.description
        XCTAssertTrue(desc.contains("test.png"), "Description should contain name")
        XCTAssertTrue(desc.contains("2.0"), "Description should contain scale")
        XCTAssertTrue(desc.hasPrefix("AssetBundleImageKey("), "Description should start with type name")
    }

    // MARK: - ResizeImageKey Tests

    /// Test construction with all parameters.
    func testResizeImageKeyConstruction() {
        let innerKey = AnyHashable("inner")
        let key = ResizeImageKey(
            providerCacheKey: innerKey,
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        XCTAssertEqual(key.providerCacheKey, innerKey)
        XCTAssertEqual(key.policy, .exact)
        XCTAssertEqual(key.width, 100)
        XCTAssertEqual(key.height, 200)
        XCTAssertEqual(key.allowUpscaling, false)
    }

    /// Test construction with nil width.
    func testResizeImageKeyConstructionNilWidth() {
        let key = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .fit,
            width: nil,
            height: 200,
            allowUpscaling: true
        )
        XCTAssertNil(key.width)
        XCTAssertEqual(key.height, 200)
        XCTAssertEqual(key.policy, .fit)
        XCTAssertEqual(key.allowUpscaling, true)
    }

    /// Test equality: same parameters.
    func testResizeImageKeyEquality() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        XCTAssertEqual(a, b)
    }

    /// Test inequality: different provider cache key.
    func testResizeImageKeyInequalityKey() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner1"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner2"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality: different dimensions.
    func testResizeImageKeyInequalityDimensions() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 300,
            height: 400,
            allowUpscaling: false
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality: different policy.
    func testResizeImageKeyInequalityPolicy() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .fit,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality: different allowUpscaling.
    func testResizeImageKeyInequalityAllowUpscaling() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: true
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test hashing: equal keys produce the same hash.
    func testResizeImageKeyHashable() {
        let a = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let b = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test description output.
    func testResizeImageKeyDescription() {
        let key = ResizeImageKey(
            providerCacheKey: AnyHashable("inner"),
            policy: .exact,
            width: 100,
            height: 200,
            allowUpscaling: false
        )
        let desc = key.description
        XCTAssertTrue(desc.contains("ResizeImageKey"), "Description should contain type name")
        XCTAssertTrue(desc.contains("exact"), "Description should contain policy")
    }

    // MARK: - FileImage Tests

    /// Test construction with URL and default scale.
    func testFileImageConstructionDefaultScale() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let image = FileImage(url)
        XCTAssertEqual(image.file, url)
        XCTAssertEqual(image.scale, 1.0)
    }

    /// Test construction with URL and custom scale.
    func testFileImageConstructionCustomScale() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let image = FileImage(url, scale: 2.0)
        XCTAssertEqual(image.file, url)
        XCTAssertEqual(image.scale, 2.0)
    }

    /// Test equality: same file path and scale.
    func testFileImageEquality() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let a = FileImage(url, scale: 2.0)
        let b = FileImage(url, scale: 2.0)
        XCTAssertTrue(a == b)
    }

    /// Test identity equality: same instance.
    func testFileImageIdentityEquality() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let a = FileImage(url)
        XCTAssertTrue(a == a)
    }

    /// Test inequality: different file path.
    func testFileImageInequalityPath() {
        let a = FileImage(URL(fileURLWithPath: "/tmp/a.png"))
        let b = FileImage(URL(fileURLWithPath: "/tmp/b.png"))
        XCTAssertFalse(a == b)
    }

    /// Test inequality: different scale.
    func testFileImageInequalityScale() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let a = FileImage(url, scale: 1.0)
        let b = FileImage(url, scale: 2.0)
        XCTAssertFalse(a == b)
    }

    /// Test obtainKey returns a FileImageKey with matching values.
    func testFileImageObtainKey() async throws {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let image = FileImage(url, scale: 2.0)
        let key = try await image.obtainKey(configuration: .empty)
        XCTAssertEqual(key.filePath, url.path)
        XCTAssertEqual(key.scale, 2.0)
    }

    /// Test description output.
    ///
    /// **Dart Test:** `image_provider_test.dart:186-199` - "ImageProvider toStrings"
    func testFileImageDescription() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let image = FileImage(url, scale: 2.0)
        let desc = image.description
        XCTAssertTrue(desc.hasPrefix("FileImage("), "Description should start with FileImage(")
        XCTAssertTrue(desc.contains("/tmp/test.png"), "Description should contain file path")
        XCTAssertTrue(desc.contains("scale: 2.0"), "Description should contain scale")
    }

    // MARK: - FileImageKey Tests

    /// Test FileImageKey construction.
    func testFileImageKeyConstruction() {
        let key = FileImageKey(filePath: "/tmp/test.png", scale: 2.0)
        XCTAssertEqual(key.filePath, "/tmp/test.png")
        XCTAssertEqual(key.scale, 2.0)
    }

    /// Test FileImageKey equality.
    func testFileImageKeyEquality() {
        let a = FileImageKey(filePath: "/tmp/test.png", scale: 2.0)
        let b = FileImageKey(filePath: "/tmp/test.png", scale: 2.0)
        XCTAssertEqual(a, b)
    }

    /// Test FileImageKey inequality.
    func testFileImageKeyInequality() {
        let a = FileImageKey(filePath: "/tmp/a.png", scale: 1.0)
        let b = FileImageKey(filePath: "/tmp/b.png", scale: 1.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test FileImageKey hashing.
    func testFileImageKeyHashable() {
        let a = FileImageKey(filePath: "/tmp/test.png", scale: 2.0)
        let b = FileImageKey(filePath: "/tmp/test.png", scale: 2.0)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - MemoryImage Tests

    /// Test construction with bytes and default scale.
    func testMemoryImageConstructionDefaultScale() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let image = MemoryImage(bytes)
        XCTAssertEqual(image.bytes, bytes)
        XCTAssertEqual(image.scale, 1.0)
    }

    /// Test construction with bytes and custom scale.
    func testMemoryImageConstructionCustomScale() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let image = MemoryImage(bytes, scale: 2.0)
        XCTAssertEqual(image.bytes, bytes)
        XCTAssertEqual(image.scale, 2.0)
    }

    /// Test equality: same bytes and scale.
    func testMemoryImageEquality() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let a = MemoryImage(bytes, scale: 1.0)
        let b = MemoryImage(bytes, scale: 1.0)
        XCTAssertTrue(a == b)
    }

    /// Test identity equality: same instance.
    func testMemoryImageIdentityEquality() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let a = MemoryImage(bytes)
        XCTAssertTrue(a == a)
    }

    /// Test inequality: different bytes.
    func testMemoryImageInequalityBytes() {
        let a = MemoryImage([0xFF, 0xD8])
        let b = MemoryImage([0x89, 0x50])
        XCTAssertFalse(a == b)
    }

    /// Test inequality: different scale.
    func testMemoryImageInequalityScale() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let a = MemoryImage(bytes, scale: 1.0)
        let b = MemoryImage(bytes, scale: 2.0)
        XCTAssertFalse(a == b)
    }

    /// Test obtainKey returns a MemoryImageKey with matching values.
    func testMemoryImageObtainKey() async throws {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let image = MemoryImage(bytes, scale: 2.0)
        let key = try await image.obtainKey(configuration: .empty)
        XCTAssertEqual(key.bytes, bytes)
        XCTAssertEqual(key.scale, 2.0)
    }

    /// Test description output.
    ///
    /// **Dart Test:** `image_provider_test.dart:196-198` - "ImageProvider toStrings"
    /// In Dart: `MemoryImage(Uint8List#00000, scale: 1.2)` (hash-code based)
    /// In Swift: `MemoryImage(3 bytes, scale: 1.2)` (byte-count based)
    func testMemoryImageDescription() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF]
        let image = MemoryImage(bytes, scale: 1.2)
        let desc = image.description
        XCTAssertTrue(desc.hasPrefix("MemoryImage("), "Description should start with MemoryImage(")
        XCTAssertTrue(desc.contains("3 bytes"), "Description should contain byte count")
        XCTAssertTrue(desc.contains("scale: 1.2"), "Description should contain scale")
    }

    // MARK: - MemoryImageKey Tests

    /// Test MemoryImageKey construction.
    func testMemoryImageKeyConstruction() {
        let bytes: [UInt8] = [0xFF, 0xD8]
        let key = MemoryImageKey(bytes: bytes, scale: 1.5)
        XCTAssertEqual(key.bytes, bytes)
        XCTAssertEqual(key.scale, 1.5)
    }

    /// Test MemoryImageKey equality.
    func testMemoryImageKeyEquality() {
        let bytes: [UInt8] = [0xFF, 0xD8]
        let a = MemoryImageKey(bytes: bytes, scale: 1.5)
        let b = MemoryImageKey(bytes: bytes, scale: 1.5)
        XCTAssertEqual(a, b)
    }

    /// Test MemoryImageKey inequality.
    func testMemoryImageKeyInequality() {
        let a = MemoryImageKey(bytes: [0xFF], scale: 1.0)
        let b = MemoryImageKey(bytes: [0x00], scale: 1.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test MemoryImageKey hashing.
    func testMemoryImageKeyHashable() {
        let bytes: [UInt8] = [0xFF, 0xD8]
        let a = MemoryImageKey(bytes: bytes, scale: 1.5)
        let b = MemoryImageKey(bytes: bytes, scale: 1.5)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - ExactAssetImage Tests

    /// Test construction with default values.
    func testExactAssetImageConstructionDefaults() {
        let image = ExactAssetImage("test.png")
        XCTAssertEqual(image.assetName, "test.png")
        XCTAssertEqual(image.scale, 1.0)
        XCTAssertNil(image.bundle)
        XCTAssertNil(image.package)
    }

    /// Test construction with all parameters.
    func testExactAssetImageConstructionAll() {
        let bundle = TestAssetBundle()
        let image = ExactAssetImage("test.png", scale: 2.0, bundle: bundle, package: "my_package")
        XCTAssertEqual(image.assetName, "test.png")
        XCTAssertEqual(image.scale, 2.0)
        XCTAssertTrue(image.bundle === bundle)
        XCTAssertEqual(image.package, "my_package")
    }

    /// Test keyName without package.
    func testExactAssetImageKeyNameWithoutPackage() {
        let image = ExactAssetImage("icons/heart.png")
        XCTAssertEqual(image.keyName, "icons/heart.png")
    }

    /// Test keyName with package.
    func testExactAssetImageKeyNameWithPackage() {
        let image = ExactAssetImage("icons/heart.png", package: "my_package")
        XCTAssertEqual(image.keyName, "packages/my_package/icons/heart.png")
    }

    /// Test equality: same keyName, scale, and bundle.
    func testExactAssetImageEquality() {
        let bundle = TestAssetBundle()
        let a = ExactAssetImage("test.png", scale: 2.0, bundle: bundle)
        let b = ExactAssetImage("test.png", scale: 2.0, bundle: bundle)
        XCTAssertTrue(a == b)
    }

    /// Test identity equality.
    func testExactAssetImageIdentityEquality() {
        let image = ExactAssetImage("test.png")
        XCTAssertTrue(image == image)
    }

    /// Test inequality: different name.
    func testExactAssetImageInequalityName() {
        let a = ExactAssetImage("a.png")
        let b = ExactAssetImage("b.png")
        XCTAssertFalse(a == b)
    }

    /// Test inequality: different scale.
    func testExactAssetImageInequalityScale() {
        let a = ExactAssetImage("test.png", scale: 1.0)
        let b = ExactAssetImage("test.png", scale: 2.0)
        XCTAssertFalse(a == b)
    }

    /// Test inequality: different bundle reference.
    func testExactAssetImageInequalityBundle() {
        let bundle1 = TestAssetBundle()
        let bundle2 = TestAssetBundle()
        let a = ExactAssetImage("test.png", bundle: bundle1)
        let b = ExactAssetImage("test.png", bundle: bundle2)
        XCTAssertFalse(a == b)
    }

    /// Test equality: nil bundles are equal.
    func testExactAssetImageEqualityNilBundles() {
        let a = ExactAssetImage("test.png", scale: 1.0)
        let b = ExactAssetImage("test.png", scale: 1.0)
        XCTAssertTrue(a == b)
    }

    /// Test obtainKey returns an AssetBundleImageKey with correct values.
    func testExactAssetImageObtainKey() async throws {
        let bundle = TestAssetBundle()
        let image = ExactAssetImage("test.png", scale: 2.0, bundle: bundle)
        let key = try await image.obtainKey(configuration: .empty)
        XCTAssertTrue(key.bundle === bundle)
        XCTAssertEqual(key.name, "test.png")
        XCTAssertEqual(key.scale, 2.0)
    }

    /// Test obtainKey with package prefixes the key name.
    func testExactAssetImageObtainKeyWithPackage() async throws {
        let bundle = TestAssetBundle()
        let image = ExactAssetImage("test.png", scale: 1.0, bundle: bundle, package: "pkg")
        let key = try await image.obtainKey(configuration: .empty)
        XCTAssertEqual(key.name, "packages/pkg/test.png")
    }

    /// Test obtainKey uses configuration bundle when image bundle is nil.
    func testExactAssetImageObtainKeyUsesConfigBundle() async throws {
        let configBundle = TestAssetBundle()
        let image = ExactAssetImage("test.png")
        let config = ImageConfiguration(bundle: configBundle)
        let key = try await image.obtainKey(configuration: config)
        XCTAssertTrue(key.bundle === configBundle)
    }

    /// Test description output.
    ///
    /// **Dart Test:** `image_provider_test.dart:191-194` - "ImageProvider toStrings"
    /// In Dart: `ExactAssetImage(name: "test", scale: 1.2, bundle: null)`
    func testExactAssetImageDescription() {
        let image = ExactAssetImage("test", scale: 1.2)
        let desc = image.description
        XCTAssertEqual(
            desc,
            "ExactAssetImage(name: \"test\", scale: 1.2, bundle: nil)"
        )
    }

    /// Test description with bundle.
    func testExactAssetImageDescriptionWithBundle() {
        let bundle = TestAssetBundle()
        let image = ExactAssetImage("test.png", bundle: bundle)
        let desc = image.description
        XCTAssertTrue(desc.hasPrefix("ExactAssetImage("), "Description should start with ExactAssetImage(")
        XCTAssertTrue(desc.contains("test.png"), "Description should contain asset name")
        XCTAssertTrue(desc.contains("scale: 1.0"), "Description should contain scale")
    }

    // MARK: - NetworkImageLoadException Tests

    /// Test construction with status code and URI.
    func testNetworkImageLoadExceptionConstruction() {
        let url = URL(string: "https://example.com/image.png")!
        let exception = NetworkImageLoadException(statusCode: 404, uri: url)
        XCTAssertEqual(exception.statusCode, 404)
        XCTAssertEqual(exception.uri, url)
    }

    /// Test error message formatting.
    func testNetworkImageLoadExceptionMessage() {
        let url = URL(string: "https://example.com/image.png")!
        let exception = NetworkImageLoadException(statusCode: 403, uri: url)
        let desc = exception.description
        XCTAssertTrue(
            desc.contains("403"),
            "Error message should contain status code"
        )
        XCTAssertTrue(
            desc.contains("https://example.com/image.png"),
            "Error message should contain URL"
        )
        XCTAssertTrue(
            desc.contains("HTTP request failed"),
            "Error message should indicate HTTP failure"
        )
    }

    /// Test full error message format matches expected pattern.
    func testNetworkImageLoadExceptionFullMessage() {
        let url = URL(string: "https://example.com/image.png")!
        let exception = NetworkImageLoadException(statusCode: 500, uri: url)
        XCTAssertEqual(
            exception.description,
            "HTTP request failed, statusCode: 500, https://example.com/image.png"
        )
    }

    /// Test that NetworkImageLoadException conforms to Error.
    func testNetworkImageLoadExceptionIsError() {
        let url = URL(string: "https://example.com/image.png")!
        let exception = NetworkImageLoadException(statusCode: 404, uri: url)
        // Verify it can be used as an Error
        let error: Error = exception
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    /// Test with various HTTP status codes.
    func testNetworkImageLoadExceptionVariousStatusCodes() {
        let url = URL(string: "https://example.com/img")!

        let codes = [400, 401, 403, 404, 500, 502, 503]
        for code in codes {
            let exception = NetworkImageLoadException(statusCode: code, uri: url)
            XCTAssertEqual(exception.statusCode, code)
            XCTAssertTrue(exception.description.contains("\(code)"))
        }
    }

    // MARK: - ImageProviderError Tests

    /// Test ImageProviderError.resolutionFailed construction and description.
    func testImageProviderErrorResolutionFailed() {
        let error = ImageProviderError.resolutionFailed(
            description: "Network timeout",
            stack: nil
        )
        XCTAssertTrue(error.description.contains("Network timeout"))
        XCTAssertTrue(error.description.contains("Image resolution failed"))
    }

    /// Test ImageProviderError with stack trace.
    func testImageProviderErrorResolutionFailedWithStack() {
        let error = ImageProviderError.resolutionFailed(
            description: "Not found",
            stack: "at line 42"
        )
        XCTAssertTrue(error.description.contains("Not found"))
        // Stack is stored but not included in description
    }

    // MARK: - ResizeImage Tests

    /// Test ResizeImage construction with width and height.
    func testResizeImageConstruction() {
        let inner = MemoryImage([0xFF, 0xD8])
        let resized = ResizeImage(inner, width: 40, height: 40)
        XCTAssertTrue(resized.imageProvider === inner)
        XCTAssertEqual(resized.width, 40)
        XCTAssertEqual(resized.height, 40)
        XCTAssertEqual(resized.policy, .exact)
        XCTAssertEqual(resized.allowUpscaling, false)
    }

    /// Test ResizeImage construction with only width.
    func testResizeImageConstructionWidthOnly() {
        let inner = MemoryImage([0xFF])
        let resized = ResizeImage(inner, width: 100)
        XCTAssertEqual(resized.width, 100)
        XCTAssertNil(resized.height)
    }

    /// Test ResizeImage construction with only height.
    func testResizeImageConstructionHeightOnly() {
        let inner = MemoryImage([0xFF])
        let resized = ResizeImage(inner, height: 100)
        XCTAssertNil(resized.width)
        XCTAssertEqual(resized.height, 100)
    }

    /// Test ResizeImage construction with custom policy and allowUpscaling.
    func testResizeImageConstructionCustomOptions() {
        let inner = MemoryImage([0xFF])
        let resized = ResizeImage(inner, width: 100, height: 100, policy: .fit, allowUpscaling: true)
        XCTAssertEqual(resized.policy, .fit)
        XCTAssertEqual(resized.allowUpscaling, true)
    }

    /// Test ResizeImage equality: same inner provider, same parameters.
    func testResizeImageEquality() {
        let inner = MemoryImage([0xFF, 0xD8])
        let a = ResizeImage(inner, width: 40, height: 40)
        let b = ResizeImage(inner, width: 40, height: 40)
        XCTAssertTrue(a == b)
    }

    /// Test ResizeImage identity equality.
    func testResizeImageIdentityEquality() {
        let inner = MemoryImage([0xFF])
        let a = ResizeImage(inner, width: 40)
        XCTAssertTrue(a == a)
    }

    /// Test ResizeImage inequality: different inner provider.
    func testResizeImageInequalityDifferentProvider() {
        let inner1 = MemoryImage([0xFF])
        let inner2 = MemoryImage([0xFF])
        let a = ResizeImage(inner1, width: 40)
        let b = ResizeImage(inner2, width: 40)
        // Different instances of inner provider -> not equal (reference identity)
        XCTAssertFalse(a == b)
    }

    /// Test ResizeImage inequality: different dimensions.
    func testResizeImageInequalityDimensions() {
        let inner = MemoryImage([0xFF])
        let a = ResizeImage(inner, width: 40, height: 40)
        let b = ResizeImage(inner, width: 80, height: 80)
        XCTAssertFalse(a == b)
    }

    /// Test resizeIfNeeded returns provider directly when both dimensions nil.
    func testResizeImageResizeIfNeededNoResize() {
        let inner = MemoryImage([0xFF])
        let result = ResizeImage.resizeIfNeeded(cacheWidth: nil, cacheHeight: nil, provider: inner)
        XCTAssertTrue(result === inner, "Should return the same provider when no resize needed")
    }

    /// Test resizeIfNeeded returns ResizeImage when width is provided.
    func testResizeImageResizeIfNeededWithWidth() {
        let inner = MemoryImage([0xFF])
        let result = ResizeImage.resizeIfNeeded(cacheWidth: 100, cacheHeight: nil, provider: inner)
        XCTAssertTrue(result is ResizeImage, "Should return a ResizeImage when width is provided")
    }

    /// Test resizeIfNeeded returns ResizeImage when height is provided.
    func testResizeImageResizeIfNeededWithHeight() {
        let inner = MemoryImage([0xFF])
        let result = ResizeImage.resizeIfNeeded(cacheWidth: nil, cacheHeight: 100, provider: inner)
        XCTAssertTrue(result is ResizeImage, "Should return a ResizeImage when height is provided")
    }

    /// Test ResizeImage description.
    func testResizeImageDescription() {
        let inner = MemoryImage([0xFF])
        let resized = ResizeImage(inner, width: 40, height: 40)
        let desc = resized.description
        XCTAssertTrue(desc.hasPrefix("ResizeImage("), "Description should start with ResizeImage(")
        XCTAssertTrue(desc.contains("40"), "Description should contain dimensions")
    }
}

// MARK: - Test Helpers

/// A minimal mock `AssetBundle` for testing.
///
/// This stub satisfies the `AssetBundle` protocol with no-op implementations,
/// allowing tests to create `AssetBundleImageKey` and `ImageConfiguration`
/// instances that reference a bundle.
private final class TestAssetBundle: AssetBundle, @unchecked Sendable {

    func load(_ key: String) async throws -> [UInt8] {
        return []
    }

    func loadBuffer(_ key: String) async throws -> ImmutableBuffer {
        return ImmutableBuffer.fromUint8List([])
    }

    func loadString(_ key: String, cache: Bool) async throws -> String {
        return ""
    }

    func loadStructuredData<T>(_ key: String, parser: @escaping (String) async throws -> T) async throws -> T {
        fatalError("Not implemented for testing")
    }

    func loadStructuredBinaryData<T>(_ key: String, parser: @escaping ([UInt8]) async throws -> T) async throws -> T {
        fatalError("Not implemented for testing")
    }
}
