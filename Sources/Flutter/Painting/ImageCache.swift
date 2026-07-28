// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of ImageCache for PaintingBinding dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_cache.dart`
/// **Lines:** 86-535
///
/// NOTE: This is a minimal stub to support PaintingBinding migration.
/// A full ImageCache implementation will be completed in a future task.

import FlutterSwiftBridge

// MARK: - Constants

/// Default maximum number of images to cache.
///
/// **Dart Source:** `image_cache.dart:10`
private let _kDefaultSize: Int = 1000

/// Default maximum total size of cached images in bytes (100 MB).
///
/// **Dart Source:** `image_cache.dart:11`
private let _kDefaultSizeBytes: Int = 100 << 20 // 100 MiB

// MARK: - ImageCache

/// Class for caching images.
///
/// Implements a least-recently-used cache of up to 1000 images, and up to 100 MB. The
/// maximum size can be adjusted using `maximumSize` and `maximumSizeBytes`.
///
/// The cache also holds references to live images, which are those that have at
/// least one active listener.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_cache.dart`
/// **Lines:** 86-535
open class ImageCache {

    // MARK: - Properties

    /// Maximum number of entries to store in the cache.
    ///
    /// Once this many entries have been cached, the least-recently-used entry is
    /// evicted when adding a new entry.
    ///
    /// **Dart Source:** `image_cache.dart:96-101`
    public var maximumSize: Int {
        get { _maximumSize }
        set {
            assert(newValue >= 0)
            if newValue == _maximumSize { return }
            _maximumSize = newValue
            if maximumSize == 0 {
                clear()
            } else {
                _checkCacheSize()
            }
        }
    }
    private var _maximumSize: Int = _kDefaultSize

    /// The current number of cached entries.
    ///
    /// **Dart Source:** `image_cache.dart:130-131`
    public var currentSize: Int { _cache.count }

    /// Maximum size of entries to store in the cache in bytes.
    ///
    /// Once more than this amount of bytes have been cached, the
    /// least-recently-used entry is evicted until there are fewer than the
    /// maximum bytes.
    ///
    /// **Dart Source:** `image_cache.dart:133-150`
    public var maximumSizeBytes: Int {
        get { _maximumSizeBytes }
        set {
            assert(newValue >= 0)
            if newValue == _maximumSizeBytes { return }
            _maximumSizeBytes = newValue
            if maximumSizeBytes == 0 {
                clear()
            } else {
                _checkCacheSize()
            }
        }
    }
    private var _maximumSizeBytes: Int = _kDefaultSizeBytes

    /// The current size of cached entries in bytes.
    ///
    /// **Dart Source:** `image_cache.dart:174-175`
    public private(set) var currentSizeBytes: Int = 0

    /// The current number of live images being tracked.
    ///
    /// **Dart Source:** `image_cache.dart:177-178`
    public var liveImageCount: Int { _liveImages.count }

    /// The current number of pending images being tracked.
    ///
    /// **Dart Source:** `image_cache.dart:180-181`
    public var pendingImageCount: Int { _pendingImages.count }

    // MARK: - Internal Storage

    /// Pending image completers keyed by their cache key.
    private var _pendingImages: [AnyHashable: Any] = [:]

    /// Cached images keyed by their cache key.
    private var _cache: [AnyHashable: Any] = [:]

    /// Live images (those with active listeners).
    private var _liveImages: [AnyHashable: Any] = [:]

    // MARK: - Initialization

    /// Creates a new ImageCache.
    ///
    /// **Dart Source:** `image_cache.dart:86`
    public init() {}

    // MARK: - Methods

    /// Evicts all pending and keepAlive entries from the cache.
    ///
    /// This is useful if, for instance, the root asset bundle has been updated
    /// and therefore new images must be obtained.
    ///
    /// Images which have not finished loading yet will not be removed from the
    /// cache, and when they complete they will be inserted as normal.
    ///
    /// This method does not clear live references to images, since clearing those
    /// would not reduce memory pressure. Such images still have listeners in the
    /// application code, and will still remain resident in memory.
    ///
    /// To clear the live references, call `clearLiveImages` after this method.
    ///
    /// **Dart Source:** `image_cache.dart:183-222`
    open func clear() {
        _cache.removeAll()
        _pendingImages.removeAll()
        currentSizeBytes = 0
    }

    /// Clears any live references to images in this cache.
    ///
    /// An image is considered live if its `ImageStreamCompleter` has never
    /// hit zero listeners after being added to this image cache. The
    /// `ImageStreamCompleter.addOnLastListenerRemovedCallback` is used to
    /// determine when this has happened.
    ///
    /// This does not lead to a reduction in memory usage, unless the images
    /// in this cache are not also being held in live widgets.
    ///
    /// **Dart Source:** `image_cache.dart:224-239`
    open func clearLiveImages() {
        _liveImages.removeAll()
    }

    /// Evicts a single entry from the cache, returning true if successful.
    ///
    /// Pending images waiting for completion are removed as well, returning true
    /// if successful. When a pending image is removed the listener on it is
    /// removed as well to prevent it from adding itself to the cache if it
    /// ever completes.
    ///
    /// If this method removes a live image from the cache, the live reference
    /// will still be held by the image cache until it is no longer in use.
    ///
    /// Returns whether or not a pending image or a cached image was successfully
    /// removed.
    ///
    /// **Dart Source:** `image_cache.dart:241-295`
    public func evict(_ key: AnyHashable, includeLive: Bool = true) -> Bool {
        let pendingRemoved = _pendingImages.removeValue(forKey: key) != nil
        let cacheRemoved = _cache.removeValue(forKey: key) != nil
        if includeLive {
            _liveImages.removeValue(forKey: key)
        }
        return pendingRemoved || cacheRemoved
    }

    // MARK: - Private Methods

    /// Check cache size and evict entries if necessary.
    private func _checkCacheSize() {
        // Stub implementation - full logic to be added when ImageCache is fully migrated
        while _cache.count > maximumSize {
            guard let firstKey = _cache.keys.first else { break }
            _cache.removeValue(forKey: firstKey)
        }
    }
}

// MARK: - ImageCacheStatus

/// Information about how the `ImageCache` is tracking an image.
///
/// A `pending` image is one that has not completed yet. A `keepAlive` image
/// is being held in the cache, which uses the `maximumSize` and
/// `maximumSizeBytes` to determine when to evict. A `live` image is being
/// held until its listener count goes to zero, and may be `keepAlive` as well
/// if it fits the sizing constraints of the cache.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_cache.dart`
/// **Lines:** 537-586
public struct ImageCacheStatus: Equatable, Hashable {

    // MARK: - Properties

    /// An image that has been submitted to `ImageCache.putIfAbsent`, but
    /// not yet completed.
    ///
    /// **Dart Source:** `image_cache.dart:543`
    public let pending: Bool

    /// An image that has been submitted to `ImageCache.putIfAbsent`, has
    /// completed, fits based on the sizing rules of the cache, and has not been
    /// evicted.
    ///
    /// **Dart Source:** `image_cache.dart:551`
    public let keepAlive: Bool

    /// An image that has been submitted to `ImageCache.putIfAbsent` and has at
    /// least one listener on its `ImageStreamCompleter`.
    ///
    /// **Dart Source:** `image_cache.dart:558`
    public let live: Bool

    /// An image that is tracked in some way by the `ImageCache`, whether
    /// `pending`, `keepAlive`, or `live`.
    ///
    /// **Dart Source:** `image_cache.dart:562`
    public var tracked: Bool { pending || keepAlive || live }

    /// An image that either has not been submitted to
    /// `ImageCache.putIfAbsent` or has otherwise been evicted from the
    /// `keepAlive` and `live` caches.
    ///
    /// **Dart Source:** `image_cache.dart:567`
    public var untracked: Bool { !pending && !keepAlive && !live }

    // MARK: - Initialization

    /// Creates an `ImageCacheStatus` with the given tracking state.
    ///
    /// **Dart Source:** `image_cache.dart:538`
    internal init(pending: Bool = false, keepAlive: Bool = false, live: Bool = false) {
        assert(!pending || !keepAlive)
        self.pending = pending
        self.keepAlive = keepAlive
        self.live = live
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "ImageCacheStatus(pending: \(pending), live: \(live), keepAlive: \(keepAlive))"
    }
}
