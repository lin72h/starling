// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of AssetManifest and AssetMetadata for image_resolution dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_manifest.dart`
///
/// NOTE: This is a minimal stub to support AssetImage migration.
/// A full implementation will be completed in a future task.

import Foundation

// MARK: - AssetManifest

/// Contains details about available assets and their variants.
///
/// See [Resolution-aware image assets](https://flutter.dev/to/resolution-aware-images)
/// to learn about asset variants and how to declare them.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_manifest.dart`
/// **Original Name:** `AssetManifest`
/// **Lines:** 24-69
public protocol AssetManifest {
    /// Lists the keys of all main assets. This does not include assets
    /// that are variants of other assets.
    ///
    /// **Dart Source:** `asset_manifest.dart:61`
    func listAssets() -> [String]

    /// Retrieves metadata about an asset and its variants. Returns nil if the
    /// key was not found in the asset manifest.
    ///
    /// This method considers a main asset to be a variant of itself. The returned
    /// list will include it if it exists.
    ///
    /// **Dart Source:** `asset_manifest.dart:68`
    func getAssetVariants(_ key: String) -> [AssetMetadata]?
}

extension AssetManifest {
    /// Loads asset manifest data from an `AssetBundle` object and creates an
    /// `AssetManifest` object from that data.
    ///
    /// **Dart Source:** `asset_manifest.dart:27-50`
    ///
    /// NOTE: This is a stub that returns a placeholder manifest.
    /// The real implementation parses the binary AssetManifest.bin file.
    public static func loadFromAssetBundle(_ bundle: any AssetBundle) async throws -> any AssetManifest {
        return _StubAssetManifest()
    }
}

// MARK: - loadAssetManifest

/// Loads an `AssetManifest` from the given `AssetBundle`.
///
/// This is a top-level convenience function that wraps the protocol extension
/// static method, since Swift does not allow calling static methods on protocol
/// existentials directly.
///
/// **Dart Source:** `asset_manifest.dart:27-50` (called as `AssetManifest.loadFromAssetBundle`)
public func loadAssetManifest(from bundle: any AssetBundle) async throws -> any AssetManifest {
    return try await _StubAssetManifest.loadFromAssetBundle(bundle)
}

// MARK: - _StubAssetManifest

/// Stub implementation of AssetManifest for compilation purposes.
///
/// This will be replaced with the real _AssetManifestBin implementation
/// when the services module is fully migrated.
private final class _StubAssetManifest: AssetManifest {
    func listAssets() -> [String] {
        return []
    }

    func getAssetVariants(_ key: String) -> [AssetMetadata]? {
        return nil
    }
}

// MARK: - AssetMetadata

/// Contains information about an asset.
///
/// **Dart Source:** `packages/flutter/lib/src/services/asset_manifest.dart`
/// **Original Name:** `AssetMetadata`
/// **Lines:** 131-158
public struct AssetMetadata: Equatable, Sendable {
    /// Creates an object containing information about an asset.
    ///
    /// **Dart Source:** `asset_manifest.dart:133-137`
    public init(key: String, targetDevicePixelRatio: Double?, main: Bool) {
        self.key = key
        self.targetDevicePixelRatio = targetDevicePixelRatio
        self.main = main
    }

    /// The asset's key, which is the path to the asset specified in the pubspec.yaml
    /// file at build time.
    ///
    /// **Dart Source:** `asset_manifest.dart:153`
    public let key: String

    /// The device pixel ratio that this asset is most ideal for. This is determined
    /// by the name of the parent folder of the asset file. For example, if the
    /// parent folder is named "3.0x", the target device pixel ratio of that
    /// asset will be interpreted as 3.
    ///
    /// This will be nil if the parent folder name is not a ratio value followed
    /// by an "x".
    ///
    /// **Dart Source:** `asset_manifest.dart:149`
    public let targetDevicePixelRatio: Double?

    /// Whether or not this is a main asset. In other words, this is true if
    /// this asset is not a variant of another asset.
    ///
    /// **Dart Source:** `asset_manifest.dart:157`
    public let main: Bool
}
