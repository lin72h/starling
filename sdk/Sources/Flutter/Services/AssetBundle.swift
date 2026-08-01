// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of AssetBundle for image_provider.dart dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_bundle.dart`
/// **Lines:** 57-204
///
/// NOTE: This is a minimal stub to support ImageProvider migration.
/// A full AssetBundle implementation will be completed in a future task.

import FlutterSwiftBridge

// MARK: - AssetBundle

/// A collection of resources used by the application.
///
/// Asset bundles contain resources, such as images and strings, that can be
/// used by an application. Access to these resources is asynchronous so that
/// they can be transparently loaded over a network (e.g., from a
/// `NetworkAssetBundle`) or from the local file system without blocking the
/// application's user interface.
///
/// Applications have a `rootBundle`, which contains the resources that were
/// packaged with the application when it was built. To add resources to the
/// `rootBundle` for your application, add them to the `assets` subsection of
/// the `flutter` section of your application's `pubspec.yaml` manifest.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_bundle.dart`
/// **Lines:** 57-204
public protocol AssetBundle: AnyObject, Sendable {

    /// Retrieve a binary resource from the asset bundle as a byte array.
    ///
    /// Throws an exception if the asset is not found.
    ///
    /// **Dart Source:** `asset_bundle.dart:67`
    func load(_ key: String) async throws -> [UInt8]

    /// Retrieve a binary resource from the asset bundle as an immutable buffer.
    ///
    /// Throws an exception if the asset is not found.
    ///
    /// **Dart Source:** `asset_bundle.dart:73-76`
    func loadBuffer(_ key: String) async throws -> ImmutableBuffer

    /// Retrieve a string from the asset bundle.
    ///
    /// Throws an exception if the asset is not found.
    ///
    /// **Dart Source:** `asset_bundle.dart:88-102`
    func loadString(_ key: String, cache: Bool) async throws -> String

    /// Retrieve a `StructuredData` resource from the asset bundle.
    ///
    /// **Dart Source:** `asset_bundle.dart:112-120`
    func loadStructuredData<T>(_ key: String, parser: @escaping (String) async throws -> T) async throws -> T

    /// Retrieve a `StructuredBinaryData` resource from the asset bundle.
    ///
    /// **Dart Source:** `asset_bundle.dart:135-141`
    func loadStructuredBinaryData<T>(_ key: String, parser: @escaping ([UInt8]) async throws -> T) async throws -> T

    /// If this is a caching asset bundle, and the given key describes a cached
    /// asset, then evict the asset from the cache so that the next time it is
    /// loaded, the cache will be reread from the asset bundle.
    ///
    /// **Dart Source:** `asset_bundle.dart:149-150`
    func evict(_ key: String)
}

// MARK: - Default Implementations

extension AssetBundle {

    /// Default implementation of `loadString` with cache defaulting to true.
    ///
    /// **Dart Source:** `asset_bundle.dart:88-102`
    public func loadString(_ key: String, cache: Bool = true) async throws -> String {
        try await loadString(key, cache: cache)
    }

    /// Default implementation of `evict` that does nothing.
    ///
    /// **Dart Source:** `asset_bundle.dart:149-150`
    public func evict(_ key: String) {
        // Default no-op
    }
}

// MARK: - _PlatformAssetBundle

/// A minimal stub implementation of the platform asset bundle.
///
/// In Dart, `_PlatformAssetBundle` extends `CachingAssetBundle` and serves as
/// the default `rootBundle` for the application. This stub provides the minimal
/// implementation required to satisfy the `AssetBundle` protocol so that
/// `rootBundle` can be used as a fallback in image providers.
///
/// NOTE: This is a minimal stub. A full `PlatformAssetBundle` implementation
/// will be completed in a future task.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_bundle.dart`
/// **Original Name:** `_PlatformAssetBundle`
/// **Lines:** 339-389
private final class _PlatformAssetBundle: AssetBundle, @unchecked Sendable {

    func load(_ key: String) async throws -> [UInt8] {
        fatalError("_PlatformAssetBundle.load is not yet implemented.")
    }

    func loadBuffer(_ key: String) async throws -> ImmutableBuffer {
        fatalError("_PlatformAssetBundle.loadBuffer is not yet implemented.")
    }

    func loadString(_ key: String, cache: Bool) async throws -> String {
        fatalError("_PlatformAssetBundle.loadString is not yet implemented.")
    }

    func loadStructuredData<T>(_ key: String, parser: @escaping (String) async throws -> T) async throws -> T {
        fatalError("_PlatformAssetBundle.loadStructuredData is not yet implemented.")
    }

    func loadStructuredBinaryData<T>(_ key: String, parser: @escaping ([UInt8]) async throws -> T) async throws -> T {
        fatalError("_PlatformAssetBundle.loadStructuredBinaryData is not yet implemented.")
    }
}

// MARK: - rootBundle

/// The `AssetBundle` that contains the resources packaged with the application
/// when it was built.
///
/// To add resources to the `rootBundle` for your application, add them to the
/// `assets` subsection of the `flutter` section of your application's
/// `pubspec.yaml` manifest.
///
/// Rather than using `rootBundle` directly, consider obtaining the `AssetBundle`
/// for the current `BuildContext` using `DefaultAssetBundle.of`. This layer of
/// indirection lets ancestor widgets substitute a different `AssetBundle` at
/// runtime (e.g., for testing or localization) rather than directly relying upon
/// the `rootBundle` created at build time.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_bundle.dart`
/// **Original Name:** `rootBundle`
/// **Lines:** 418
public let rootBundle: any AssetBundle = _PlatformAssetBundle()
