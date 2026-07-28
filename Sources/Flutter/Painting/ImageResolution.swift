// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Image resolution logic for asset-based images.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_resolution.dart`

// MARK: - Constants

/// A screen with a device-pixel ratio strictly less than this value is
/// considered a low-resolution screen (typically entry-level to mid-range
/// laptops, desktop screens up to QHD, low-end tablets such as Kindle Fire).
///
/// **Dart Source:** `image_resolution.dart:19`
/// **Original Name:** `_kLowDprLimit`
private let kLowDprLimit: Double = 2.0

// MARK: - AssetImage

/// Fetches an image from an `AssetBundle`, having determined the exact image to
/// use based on the context.
///
/// Given a main asset and a set of variants, `AssetImage` chooses the most
/// appropriate asset for the current context, based on the device pixel ratio
/// and size given in the configuration passed to `resolve`.
///
/// To show a specific image from a bundle without any asset resolution, use an
/// `AssetBundleImageProvider`.
///
/// ## Naming assets for matching with different pixel densities
///
/// Main assets are presumed to match a nominal pixel ratio of 1.0. To specify
/// assets targeting different pixel ratios, place the variant assets in
/// the application bundle under subdirectories named in the form "Nx", where
/// N is the nominal device pixel ratio for that asset.
///
/// For example, suppose an application wants to use an icon named
/// "heart.png". This icon has representations at 1.0 (the main icon), as well
/// as 2.0 and 4.0 pixel ratios (variants). The asset bundle should then
/// contain the following assets:
///
///     heart.png
///     2.0x/heart.png
///     4.0x/heart.png
///
/// On a device with a 1.0 device pixel ratio, the image chosen would be
/// heart.png; on a device with a 2.0 device pixel ratio, the image chosen
/// would be 2.0x/heart.png; on a device with a 4.0 device pixel ratio, the
/// image chosen would be 4.0x/heart.png.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_resolution.dart`
/// **Original Name:** `AssetImage`
/// **Lines:** 236-402
public final class AssetImage: AssetBundleImageProvider, @unchecked Sendable {

    /// Creates an object that fetches an image from an asset bundle.
    ///
    /// The `assetName` argument should name the main asset from the set of images
    /// to choose from. The `package` argument must be non-nil when fetching an
    /// asset that is included in a package.
    ///
    /// **Dart Source:** `image_resolution.dart:243`
    public init(_ assetName: String, bundle: (any AssetBundle)? = nil, package: String? = nil) {
        self.assetName = assetName
        self._bundle = bundle
        self.package = package
        super.init()
    }

    /// The name of the main asset from the set of images to choose from.
    ///
    /// **Dart Source:** `image_resolution.dart:247`
    public let assetName: String

    /// The name used to generate the key to obtain the asset. For local assets
    /// this is `assetName`, and for assets from packages the `assetName` is
    /// prefixed `packages/<package_name>/`.
    ///
    /// **Dart Source:** `image_resolution.dart:252`
    public var keyName: String {
        if let package = package {
            return "packages/\(package)/\(assetName)"
        }
        return assetName
    }

    /// The bundle from which the image will be obtained.
    ///
    /// If the provided `bundle` is nil, the bundle provided in the
    /// `ImageConfiguration` passed to the `resolve` call will be used instead. If
    /// that is also nil, the `rootBundle` is used.
    ///
    /// The image is obtained by calling `AssetBundle.load` on the given bundle
    /// using the key given by `keyName`.
    ///
    /// **Dart Source:** `image_resolution.dart:262`
    public var bundle: (any AssetBundle)? { _bundle }
    private let _bundle: (any AssetBundle)?

    /// The name of the package from which the image is included.
    ///
    /// **Dart Source:** `image_resolution.dart:266`
    public let package: String?

    /// We assume the main asset is designed for a device pixel ratio of 1.0.
    ///
    /// **Dart Source:** `image_resolution.dart:269`
    private static let naturalResolution: Double = 1.0

    // MARK: - obtainKey

    /// Converts this `AssetImage`'s settings plus `ImageConfiguration` to a key
    /// that describes the precise image to load.
    ///
    /// This method resolves the asset by:
    /// 1. Selecting the appropriate bundle (explicit bundle, configuration bundle,
    ///    or `rootBundle`)
    /// 2. Loading the `AssetManifest` from that bundle
    /// 3. Looking up the variants for `keyName`
    /// 4. Choosing the best variant for the device pixel ratio via `chooseVariant`
    /// 5. Returning an `AssetBundleImageKey` with the chosen variant
    ///
    /// **Dart Source:** `image_resolution.dart:272-326`
    public override func obtainKey(configuration: ImageConfiguration) async throws -> AssetBundleImageKey {
        let chosenBundle = _bundle ?? configuration.bundle ?? rootBundle
        let manifest = try! await loadAssetManifest(from: chosenBundle)
        let candidateVariants = manifest.getAssetVariants(keyName)
        let chosenVariant = chooseVariant(
            mainAssetKey: keyName,
            config: configuration,
            candidateVariants: candidateVariants
        )
        return AssetBundleImageKey(
            bundle: chosenBundle,
            name: chosenVariant.key,
            scale: chosenVariant.targetDevicePixelRatio ?? AssetImage.naturalResolution
        )
    }

    // MARK: - chooseVariant

    /// Selects the best asset variant for the current image configuration.
    ///
    /// If there are no candidate variants or the configuration has no device pixel
    /// ratio, returns a default `AssetMetadata` for the main asset at natural
    /// resolution (1.0).
    ///
    /// Otherwise, builds a sorted mapping of device pixel ratio to asset metadata
    /// from the candidates, then delegates to `findBestVariant` to select the
    /// optimal match.
    ///
    /// **Dart Source:** `image_resolution.dart:328-347`
    func chooseVariant(
        mainAssetKey: String,
        config: ImageConfiguration,
        candidateVariants: [AssetMetadata]?
    ) -> AssetMetadata {
        guard let candidateVariants = candidateVariants,
              !candidateVariants.isEmpty,
              let devicePixelRatio = config.devicePixelRatio else {
            return AssetMetadata(key: mainAssetKey, targetDevicePixelRatio: nil, main: true)
        }

        // Build a sorted array of (dpr, metadata) pairs, sorted by device pixel ratio.
        // This replaces the Dart SplayTreeMap<double, AssetMetadata>.
        var candidatesByDpr: [(dpr: Double, metadata: AssetMetadata)] = []
        for candidate in candidateVariants {
            let dpr = candidate.targetDevicePixelRatio ?? AssetImage.naturalResolution
            candidatesByDpr.append((dpr: dpr, metadata: candidate))
        }
        candidatesByDpr.sort { $0.dpr < $1.dpr }

        // Deduplicate by dpr (last write wins, matching SplayTreeMap behavior)
        var deduped: [(dpr: Double, metadata: AssetMetadata)] = []
        for entry in candidatesByDpr {
            if let last = deduped.last, last.dpr == entry.dpr {
                deduped[deduped.count - 1] = entry
            } else {
                deduped.append(entry)
            }
        }

        return findBestVariant(deduped, for: devicePixelRatio)
    }

    // MARK: - findBestVariant

    /// Returns the "best" asset variant amongst the available `candidates`.
    ///
    /// The best variant is chosen as follows:
    /// - Choose a variant whose key matches `value` exactly, if available.
    /// - If `value` is less than the lowest key, choose the variant with the
    ///   lowest key.
    /// - If `value` is greater than the highest key, choose the variant with
    ///   the highest key.
    /// - If the screen has low device pixel ratio (below `kLowDprLimit`),
    ///   choose the variant with the lowest key higher than `value` (prefer
    ///   higher resolution to avoid visible upscaling artifacts).
    /// - If the screen has high device pixel ratio, choose the variant with
    ///   the key nearest to `value` (save memory).
    ///
    /// **Dart Source:** `image_resolution.dart:361-386`
    func findBestVariant(
        _ candidatesByDpr: [(dpr: Double, metadata: AssetMetadata)],
        for value: Double
    ) -> AssetMetadata {
        // Exact match check
        if let exact = candidatesByDpr.first(where: { $0.dpr == value }) {
            return exact.metadata
        }

        // Find lower bound: largest dpr strictly less than value
        let lower = candidatesByDpr.last(where: { $0.dpr < value })

        // Find upper bound: smallest dpr strictly greater than value
        let upper = candidatesByDpr.first(where: { $0.dpr > value })

        if lower == nil {
            return upper!.metadata
        }
        if upper == nil {
            return lower!.metadata
        }

        // On screens with low device-pixel ratios the artifacts from upscaling
        // images are more visible than on screens with a higher device-pixel
        // ratios because the physical pixels are larger. Choose the higher
        // resolution image in that case instead of the nearest one.
        if value < kLowDprLimit || value > (lower!.dpr + upper!.dpr) / 2 {
            return upper!.metadata
        } else {
            return lower!.metadata
        }
    }

    // MARK: - Equatable

    /// **Dart Source:** `image_resolution.dart:389-393`
    public static func == (lhs: AssetImage, rhs: AssetImage) -> Bool {
        return lhs.keyName == rhs.keyName && lhs._bundle === rhs._bundle
    }

    // MARK: - Hashable

    /// **Dart Source:** `image_resolution.dart:397`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyName)
        if let b = _bundle {
            hasher.combine(ObjectIdentifier(b))
        }
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `image_resolution.dart:400-401`
    public override var description: String {
        return "AssetImage(bundle: \(String(describing: _bundle)), name: \"\(keyName)\")"
    }
}
