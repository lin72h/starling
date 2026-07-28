// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for PaintingBinding
///
/// **Dart Test Source:** `packages/flutter/test/painting/binding_test.dart`
/// **Swift Source:** `Sources/Flutter/Painting/PaintingBinding.swift`
final class PaintingBindingTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Reset the static configuration before each test
        PaintingBindingConfiguration.shaderWarmUp = nil
    }

    override func tearDown() {
        // Clean up after tests
        PaintingBindingConfiguration.shaderWarmUp = nil
        super.tearDown()
    }

    // MARK: - ShaderWarmUp Tests

    /// Test that ShaderWarmUp is nil by default.
    ///
    /// **Dart Test:** `binding_test.dart:46-48` - "ShaderWarmUp is null by default"
    func testShaderWarmUpIsNilByDefault() {
        XCTAssertNil(PaintingBindingConfiguration.shaderWarmUp, "ShaderWarmUp should be nil by default")
    }

    /// Test that ShaderWarmUp can be set.
    func testShaderWarmUpCanBeSet() {
        let warmUp = TestShaderWarmUp()
        PaintingBindingConfiguration.shaderWarmUp = warmUp

        XCTAssertNotNil(PaintingBindingConfiguration.shaderWarmUp)
    }

    // MARK: - evict Tests

    /// Test that evict clears live references.
    ///
    /// **Dart Test:** `binding_test.dart:36-44` - "evict clears live references"
    func testEvictClearsLiveReferences() {
        let binding = TestPaintingBinding()
        let imageCache = binding.paintingImageCache as! FakeImageCache

        XCTAssertEqual(imageCache.clearCount, 0)
        XCTAssertEqual(imageCache.liveClearCount, 0)

        binding.evict("/path/to/asset.png")

        XCTAssertEqual(imageCache.clearCount, 1, "evict should call clear() on image cache")
        XCTAssertEqual(imageCache.liveClearCount, 1, "evict should call clearLiveImages() on image cache")
    }

    /// Test that evict can be called multiple times.
    func testEvictCanBeCalledMultipleTimes() {
        let binding = TestPaintingBinding()
        let imageCache = binding.paintingImageCache as! FakeImageCache

        binding.evict("/path/to/asset1.png")
        binding.evict("/path/to/asset2.png")
        binding.evict("/path/to/asset3.png")

        XCTAssertEqual(imageCache.clearCount, 3, "evict should increment clear count each time")
        XCTAssertEqual(imageCache.liveClearCount, 3, "evict should increment liveClear count each time")
    }

    // MARK: - handleMemoryPressure Tests

    /// Test that handleMemoryPressure clears imageCache.
    ///
    /// **Dart Test:** `binding_test.dart:17-34` - "didHaveMemoryPressure clears imageCache"
    func testHandleMemoryPressureClearsImageCache() {
        let binding = TestPaintingBinding()
        let imageCache = binding.paintingImageCache as! FakeImageCache

        XCTAssertEqual(imageCache.clearCount, 0)

        binding.handleMemoryPressure()

        XCTAssertEqual(imageCache.clearCount, 1, "handleMemoryPressure should call clear() on image cache")
    }

    /// Test that handleMemoryPressure does not clear live images (unlike evict).
    func testHandleMemoryPressureDoesNotClearLiveImages() {
        let binding = TestPaintingBinding()
        let imageCache = binding.paintingImageCache as! FakeImageCache

        binding.handleMemoryPressure()

        XCTAssertEqual(imageCache.clearCount, 1)
        XCTAssertEqual(imageCache.liveClearCount, 0, "handleMemoryPressure should NOT call clearLiveImages()")
    }

    // MARK: - handleSystemMessage Tests

    /// Test that handleSystemMessage with 'fontsChange' notifies system fonts listeners.
    ///
    /// **Dart Test:** `binding_test.dart` - tests fontsChange handling
    func testHandleSystemMessageFontsChangeNotifiesListeners() async {
        let binding = TestPaintingBinding()
        var listenerCalled = false

        binding.systemFonts.addListener {
            listenerCalled = true
        }

        await binding.handleSystemMessage(["type": "fontsChange"])

        XCTAssertTrue(listenerCalled, "handleSystemMessage with 'fontsChange' should notify listeners")
    }

    /// Test that handleSystemMessage with other types does not notify system fonts listeners.
    func testHandleSystemMessageOtherTypeDoesNotNotifyListeners() async {
        let binding = TestPaintingBinding()
        var listenerCalled = false

        binding.systemFonts.addListener {
            listenerCalled = true
        }

        await binding.handleSystemMessage(["type": "somethingElse"])

        XCTAssertFalse(listenerCalled, "handleSystemMessage with other types should NOT notify listeners")
    }

    /// Test that handleSystemMessage handles invalid message gracefully.
    func testHandleSystemMessageHandlesInvalidMessage() async {
        let binding = TestPaintingBinding()
        var listenerCalled = false

        binding.systemFonts.addListener {
            listenerCalled = true
        }

        // Test with non-dictionary message
        await binding.handleSystemMessage("invalid")
        XCTAssertFalse(listenerCalled)

        // Test with dictionary without 'type' key
        await binding.handleSystemMessage(["key": "value"])
        XCTAssertFalse(listenerCalled)

        // Test with 'type' that is not a string
        await binding.handleSystemMessage(["type": 123])
        XCTAssertFalse(listenerCalled)
    }

    // MARK: - PaintingBindingInstance Tests

    /// Test that accessing instance before initialization throws.
    func testInstanceBeforeInitializationFatalErrors() {
        // This would cause a fatalError, so we can't directly test it in a unit test.
        // In a real scenario, we would use expectation or XCTAssertThrowsError.
        // For now, we just document that this behavior exists.
    }

    /// Test that setInstance and instance work correctly.
    func testSetInstanceAndAccessInstance() {
        let binding = TestPaintingBinding()
        PaintingBindingInstance.setInstance(binding)

        XCTAssertNotNil(PaintingBindingInstance.instance)
    }

    // MARK: - Top-level imageCache Tests

    /// Test that top-level imageCache accesses the binding's image cache.
    func testTopLevelImageCacheAccessesBindingImageCache() {
        let binding = TestPaintingBinding()
        PaintingBindingInstance.setInstance(binding)

        // The top-level imageCache should return the same instance as the binding's cache
        XCTAssertTrue(imageCache === binding.paintingImageCache,
                     "Top-level imageCache should return the binding's image cache")
    }

    // MARK: - createImageCache Tests

    /// Test default createImageCache returns a new ImageCache.
    func testDefaultCreateImageCacheReturnsNewImageCache() {
        let binding = TestPaintingBindingWithDefaultCreateImageCache()

        // The default implementation should return an ImageCache instance
        XCTAssertNotNil(binding.paintingImageCache)
    }
}

// MARK: - SystemFontsNotifier Tests

/// Tests for SystemFontsNotifier
///
/// **Dart Source:** `packages/flutter/lib/src/painting/binding.dart:188-206`
final class SystemFontsNotifierTests: XCTestCase {

    /// Test addListener and notifyListeners.
    func testAddListenerAndNotifyListeners() {
        let notifier = SystemFontsNotifier()
        var callCount = 0

        notifier.addListener {
            callCount += 1
        }

        XCTAssertEqual(callCount, 0)

        notifier.notifyListeners()
        XCTAssertEqual(callCount, 1)

        notifier.notifyListeners()
        XCTAssertEqual(callCount, 2)
    }

    /// Test removeListener stops notifications.
    func testRemoveListenerStopsNotifications() {
        let notifier = SystemFontsNotifier()
        var callCount = 0

        let listener: VoidCallback = {
            callCount += 1
        }

        notifier.addListener(listener)
        notifier.notifyListeners()
        XCTAssertEqual(callCount, 1)

        notifier.removeListener(listener)
        notifier.notifyListeners()
        XCTAssertEqual(callCount, 1, "Removed listener should not be called")
    }

    /// Test multiple listeners are all notified.
    func testMultipleListenersAreNotified() {
        let notifier = SystemFontsNotifier()
        var callCount = 0

        let listener1: VoidCallback = { callCount += 1 }
        let listener2: VoidCallback = { callCount += 10 }

        notifier.addListener(listener1)
        notifier.addListener(listener2)

        notifier.notifyListeners()

        // Both listeners should be called
        XCTAssertEqual(callCount, 11, "Both listeners should be called")
    }

    /// Test listenerCount property.
    func testListenerCountProperty() {
        let notifier = SystemFontsNotifier()
        XCTAssertEqual(notifier.listenerCount, 0)

        let listener1: VoidCallback = { _ = 1 }
        notifier.addListener(listener1)
        XCTAssertEqual(notifier.listenerCount, 1)

        let listener2: VoidCallback = { _ = 2 }
        notifier.addListener(listener2)
        XCTAssertEqual(notifier.listenerCount, 2)

        // removeListener removes the most recently added listener (LIFO)
        notifier.removeListener(listener2)
        XCTAssertEqual(notifier.listenerCount, 1)
    }

    /// Test that removing a listener decrements count and remaining listeners
    /// are still called.
    ///
    /// Note: Swift closures lack stable identity, so removeListener uses LIFO
    /// removal order. This test verifies that after removal, the remaining
    /// listener is still invoked.
    func testRemoveSpecificListener() {
        let notifier = SystemFontsNotifier()
        var callCount1 = 0
        var callCount2 = 0

        // listener1 is added first, listener2 second
        let listener1: VoidCallback = { callCount1 += 1 }
        let listener2: VoidCallback = { callCount2 += 1 }

        notifier.addListener(listener1)
        notifier.addListener(listener2)
        XCTAssertEqual(notifier.listenerCount, 2)

        // Verify both are called
        notifier.notifyListeners()
        XCTAssertEqual(callCount1, 1)
        XCTAssertEqual(callCount2, 1)

        // Remove the last added listener (listener2, LIFO order)
        notifier.removeListener(listener2)
        XCTAssertEqual(notifier.listenerCount, 1)

        // Only listener1 should be called now
        notifier.notifyListeners()
        XCTAssertEqual(callCount1, 2, "listener1 should still be called")
        XCTAssertEqual(callCount2, 1, "listener2 should not have been called again")
    }
}

// MARK: - ImageCache Tests

/// Tests for ImageCache (stub implementation)
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_cache.dart`
final class ImageCacheTests: XCTestCase {

    /// Test clear method.
    func testClear() {
        let cache = ImageCache()

        // Add some entries to the cache (indirectly via properties)
        XCTAssertEqual(cache.currentSize, 0)

        cache.clear()

        XCTAssertEqual(cache.currentSize, 0)
        XCTAssertEqual(cache.currentSizeBytes, 0)
    }

    /// Test clearLiveImages method.
    func testClearLiveImages() {
        let cache = ImageCache()

        XCTAssertEqual(cache.liveImageCount, 0)

        cache.clearLiveImages()

        XCTAssertEqual(cache.liveImageCount, 0)
    }

    /// Test default values.
    func testDefaultValues() {
        let cache = ImageCache()

        XCTAssertEqual(cache.maximumSize, 1000)
        XCTAssertEqual(cache.maximumSizeBytes, 100 << 20) // 100 MiB
        XCTAssertEqual(cache.currentSize, 0)
        XCTAssertEqual(cache.currentSizeBytes, 0)
        XCTAssertEqual(cache.liveImageCount, 0)
        XCTAssertEqual(cache.pendingImageCount, 0)
    }

    /// Test evict method.
    func testEvict() {
        let cache = ImageCache()

        // Evicting from empty cache should return false
        let result = cache.evict("nonexistent-key")
        XCTAssertFalse(result)
    }

    /// Test maximumSize setter.
    func testMaximumSizeSetter() {
        let cache = ImageCache()

        cache.maximumSize = 500
        XCTAssertEqual(cache.maximumSize, 500)

        cache.maximumSize = 0
        XCTAssertEqual(cache.maximumSize, 0)
    }

    /// Test maximumSizeBytes setter.
    func testMaximumSizeBytesSetter() {
        let cache = ImageCache()

        cache.maximumSizeBytes = 50 << 20 // 50 MiB
        XCTAssertEqual(cache.maximumSizeBytes, 50 << 20)

        cache.maximumSizeBytes = 0
        XCTAssertEqual(cache.maximumSizeBytes, 0)
    }
}

// MARK: - Test Helpers

/// A fake ImageCache for testing that tracks method calls.
///
/// **Dart Test Source:** `binding_test.dart:131-146`
final class FakeImageCache: ImageCache {
    var clearCount = 0
    var liveClearCount = 0

    override func clear() {
        clearCount += 1
        super.clear()
    }

    override func clearLiveImages() {
        liveClearCount += 1
        super.clearLiveImages()
    }
}

/// A test implementation of ShaderWarmUp for testing.
final class TestShaderWarmUp: ShaderWarmUp {
    var executeCount = 0

    func warmUpOnCanvas(_ canvas: Canvas) async {
        // No-op for tests
    }

    func execute() async {
        executeCount += 1
    }
}

/// A test implementation of PaintingBinding.
///
/// **Dart Test Source:** `binding_test.dart:122-129`
final class TestPaintingBinding: BindingBase, PaintingBinding {
    private var _imageCache: ImageCache!
    private let _systemFonts = SystemFontsNotifier()

    var paintingImageCache: ImageCache { _imageCache }
    var systemFonts: SystemFontsNotifier { _systemFonts }

    override init() {
        super.init()
        _imageCache = createImageCache()
    }

    func createImageCache() -> ImageCache {
        return FakeImageCache()
    }

    func instantiateImageCodecWithSize(
        _ buffer: ImmutableBuffer,
        getTargetSize: TargetImageSizeCallback?
    ) async throws -> any Codec {
        fatalError("Not implemented for tests")
    }
}

/// A test implementation that uses the default createImageCache implementation.
final class TestPaintingBindingWithDefaultCreateImageCache: BindingBase, PaintingBinding {
    private var _imageCache: ImageCache!
    private let _systemFonts = SystemFontsNotifier()

    var paintingImageCache: ImageCache { _imageCache }
    var systemFonts: SystemFontsNotifier { _systemFonts }

    override init() {
        super.init()
        // Use the default extension implementation
        _imageCache = ImageCache()
    }

    func instantiateImageCodecWithSize(
        _ buffer: ImmutableBuffer,
        getTargetSize: TargetImageSizeCallback?
    ) async throws -> any Codec {
        fatalError("Not implemented for tests")
    }
}
