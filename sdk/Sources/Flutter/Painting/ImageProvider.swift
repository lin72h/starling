// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Types from image_provider.dart: configuration, enums, protocols, and base classes.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`

import FlutterSwiftBridge
import Foundation

// MARK: - ImageConfiguration

/// Configuration information passed to the `ImageProvider.resolve` method to
/// select a specific image.
///
/// See also:
///
///  * `createLocalImageConfiguration`, which creates an `ImageConfiguration`
///    based on ambient configuration in a `Widget` environment.
///  * `ImageProvider`, which uses `ImageConfiguration` objects to determine
///    which image to obtain.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ImageConfiguration`
/// **Lines:** 44-171
public struct ImageConfiguration: Hashable, CustomStringConvertible, Sendable {

    // MARK: - Properties

    /// The preferred `AssetBundle` to use if the `ImageProvider` needs one and
    /// does not have one already selected.
    ///
    /// **Dart Source:** `image_provider.dart:82`
    public let bundle: (any AssetBundle)?

    /// The device pixel ratio where the image will be shown.
    ///
    /// **Dart Source:** `image_provider.dart:85`
    public let devicePixelRatio: Double?

    /// The language and region for which to select the image.
    ///
    /// **Dart Source:** `image_provider.dart:88`
    public let locale: FlutterSwiftBridge.Locale?

    /// The reading direction of the language for which to select the image.
    ///
    /// **Dart Source:** `image_provider.dart:91`
    public let textDirection: TextDirection?

    /// The size at which the image will be rendered.
    ///
    /// **Dart Source:** `image_provider.dart:94`
    public let size: Size?

    /// The `TargetPlatform` for which assets should be used. This allows images
    /// to be specified in a platform-neutral fashion yet use different assets on
    /// different platforms, to match local conventions e.g. for color matching or
    /// shadows.
    ///
    /// **Dart Source:** `image_provider.dart:100`
    public let platform: TargetPlatform?

    // MARK: - Initializer

    /// Creates an object holding the configuration information for an `ImageProvider`.
    ///
    /// All the arguments are optional. Configuration information is merely
    /// advisory and best-effort.
    ///
    /// **Dart Source:** `image_provider.dart:49-56`
    public init(
        bundle: (any AssetBundle)? = nil,
        devicePixelRatio: Double? = nil,
        locale: FlutterSwiftBridge.Locale? = nil,
        textDirection: TextDirection? = nil,
        size: Size? = nil,
        platform: TargetPlatform? = nil
    ) {
        self.bundle = bundle
        self.devicePixelRatio = devicePixelRatio
        self.locale = locale
        self.textDirection = textDirection
        self.size = size
        self.platform = platform
    }

    // MARK: - Static

    /// An image configuration that provides no additional information.
    ///
    /// Useful when resolving an `ImageProvider` without any context.
    ///
    /// **Dart Source:** `image_provider.dart:105`
    public static let empty = ImageConfiguration()

    // MARK: - Copy With

    /// Creates a copy of this object but with the given fields replaced with the
    /// new values.
    ///
    /// All the arguments are optional. Configuration information is merely
    /// advisory and best-effort.
    ///
    /// **Dart Source:** `image_provider.dart:62-78`
    public func copyWith(
        bundle: (any AssetBundle)? = nil,
        devicePixelRatio: Double? = nil,
        locale: FlutterSwiftBridge.Locale? = nil,
        textDirection: TextDirection? = nil,
        size: Size? = nil,
        platform: TargetPlatform? = nil
    ) -> ImageConfiguration {
        ImageConfiguration(
            bundle: bundle ?? self.bundle,
            devicePixelRatio: devicePixelRatio ?? self.devicePixelRatio,
            locale: locale ?? self.locale,
            textDirection: textDirection ?? self.textDirection,
            size: size ?? self.size,
            platform: platform ?? self.platform
        )
    }

    // MARK: - Equatable

    /// Compares two `ImageConfiguration` instances for equality.
    ///
    /// Note: `bundle` is compared by reference identity (`===`) since `AssetBundle`
    /// is a protocol (reference type).
    ///
    /// **Dart Source:** `image_provider.dart:108-119`
    public static func == (lhs: ImageConfiguration, rhs: ImageConfiguration) -> Bool {
        lhs.bundle === rhs.bundle &&
        lhs.devicePixelRatio == rhs.devicePixelRatio &&
        lhs.locale == rhs.locale &&
        lhs.textDirection == rhs.textDirection &&
        lhs.size == rhs.size &&
        lhs.platform == rhs.platform
    }

    // MARK: - Hashable

    /// Hashes the essential components of this configuration.
    ///
    /// Note: `bundle` is hashed via `ObjectIdentifier` since `AssetBundle` is a
    /// protocol (reference type).
    ///
    /// **Dart Source:** `image_provider.dart:122`
    public func hash(into hasher: inout Hasher) {
        if let bundle = bundle {
            hasher.combine(ObjectIdentifier(bundle))
        }
        hasher.combine(devicePixelRatio)
        hasher.combine(locale)
        hasher.combine(size)
        hasher.combine(platform)
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this configuration.
    ///
    /// **Dart Source:** `image_provider.dart:125-170`
    public var description: String {
        var result = "ImageConfiguration("
        var hasArguments = false
        if let bundle = bundle {
            result += "bundle: \(bundle)"
            hasArguments = true
        }
        if let devicePixelRatio = devicePixelRatio {
            if hasArguments {
                result += ", "
            }
            result += "devicePixelRatio: \(String(format: "%.1f", devicePixelRatio))"
            hasArguments = true
        }
        if let locale = locale {
            if hasArguments {
                result += ", "
            }
            result += "locale: \(locale)"
            hasArguments = true
        }
        if let textDirection = textDirection {
            if hasArguments {
                result += ", "
            }
            result += "textDirection: \(textDirection)"
            hasArguments = true
        }
        if let size = size {
            if hasArguments {
                result += ", "
            }
            result += "size: \(size)"
            hasArguments = true
        }
        if let platform = platform {
            if hasArguments {
                result += ", "
            }
            result += "platform: \(platform.rawValue)"
            hasArguments = true
        }
        result += ")"
        return result
    }
}

// MARK: - ResizeImagePolicy

/// Configures the behavior for `ResizeImage`.
///
/// This is used in `ResizeImage.policy` to affect how the `ResizeImage.width`
/// and `ResizeImage.height` properties are interpreted.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ResizeImagePolicy`
/// **Lines:** 834-1221
public enum ResizeImagePolicy: Sendable {
    /// Sizes the image to the exact width and height specified by
    /// `ResizeImage.width` and `ResizeImage.height`.
    ///
    /// If `ResizeImage.width` and `ResizeImage.height` are both non-nil, the
    /// output image will have the specified width and height (with the
    /// corresponding aspect ratio) regardless of whether it matches the source
    /// image's intrinsic aspect ratio. This case is similar to `BoxFit.fill`.
    ///
    /// If only one of `width` and `height` is non-nil, then the output image
    /// will be scaled to the associated width or height, and the other dimension
    /// will take whatever value is needed to maintain the image's original aspect
    /// ratio. These cases are similar to `BoxFit.fitWidth` and
    /// `BoxFit.fitHeight`, respectively.
    ///
    /// If `ResizeImage.allowUpscaling` is false (the default), the width and the
    /// height of the output image will each be clamped to the intrinsic width and
    /// height of the image. This may result in a different aspect ratio than the
    /// aspect ratio specified by the target width and height (e.g. if the height
    /// gets clamped downwards but the width does not).
    ///
    /// **Dart Source:** `image_provider.dart:1027`
    case exact

    /// Scales the image as necessary to ensure that it fits within the bounding
    /// box specified by `ResizeImage.width` and `ResizeImage.height` while
    /// maintaining its aspect ratio.
    ///
    /// If `ResizeImage.allowUpscaling` is true, the image will be scaled up or
    /// down to best fit the bounding box; otherwise it will only ever be scaled
    /// down.
    ///
    /// This is conceptually similar to `BoxFit.contain`.
    ///
    /// **Dart Source:** `image_provider.dart:1220`
    case fit
}

// MARK: - WebHtmlElementStrategy

/// Configures how network images are rendered on the web platform.
///
/// This option is only effective on the Web platform. Other platforms always
/// display network images by fetching bytes.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `WebHtmlElementStrategy`
/// **Lines:** 1495-1514
public enum WebHtmlElementStrategy: Sendable {
    /// Only show images by fetching bytes, and report errors if the fetch
    /// encounters errors.
    ///
    /// **Dart Source:** `image_provider.dart:1498`
    case never

    /// Prefer fetching bytes to display images, and fall back to HTML elements
    /// when fetching bytes is not available.
    ///
    /// This strategy uses HTML elements only if `headers` is empty and the fetch
    /// encounters errors. Errors may still be reported if neither approach works.
    ///
    /// **Dart Source:** `image_provider.dart:1505`
    case fallback

    /// Prefer HTML elements to display images, and fall back to fetching bytes
    /// when HTML elements do not work.
    ///
    /// This strategy fetches bytes only if `headers` is not empty, since HTML
    /// elements do not support headers. Errors may still be reported if neither
    /// approach works.
    ///
    /// **Dart Source:** `image_provider.dart:1513`
    case prefer
}

// MARK: - ImageDecoderCallback

/// Performs the decode process for use in `ImageProvider.loadImage`.
///
/// This callback allows decoupling of the `getTargetSize` parameter from
/// implementations of `ImageProvider` that do not expose it.
///
/// The Dart signature is:
/// ```dart
/// typedef ImageDecoderCallback = Future<ui.Codec> Function(
///   ui.ImmutableBuffer buffer, {
///   ui.TargetImageSizeCallback? getTargetSize,
/// });
/// ```
///
/// In Swift, this becomes an async throwing closure returning `any Codec`.
///
/// See also:
///
///  * `ResizeImage`, which uses this to load images at specific sizes.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ImageDecoderCallback`
/// **Lines:** 206-210
public typealias PaintingImageDecoderCallback =
    @Sendable (ImmutableBuffer, TargetImageSizeCallback?) async throws -> any Codec

// MARK: - AssetBundleImageKey

/// Key used by `AssetBundleImageProvider` to describe the precise asset to load.
///
/// This is `@immutable` in Dart and is therefore a value type (struct) in Swift.
///
/// See also:
///
///  * `AssetBundleImageProvider`, which uses this as its cache key type.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `AssetBundleImageKey`
/// **Lines:** 686-721
public struct AssetBundleImageKey: Hashable, CustomStringConvertible, Sendable {

    // MARK: - Properties

    /// The bundle from which the image will be obtained.
    ///
    /// The image is obtained by calling `AssetBundle.load` on the given `bundle`
    /// using the key given by `name`.
    ///
    /// **Dart Source:** `image_provider.dart:695`
    public let bundle: any AssetBundle

    /// The key to use to obtain the resource from the `bundle`. This is the
    /// argument passed to `AssetBundle.load`.
    ///
    /// **Dart Source:** `image_provider.dart:699`
    public let name: String

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// **Dart Source:** `image_provider.dart:702`
    public let scale: Double

    // MARK: - Initializer

    /// Creates the key for an `AssetImage` or `AssetBundleImageProvider`.
    ///
    /// **Dart Source:** `image_provider.dart:689`
    public init(bundle: any AssetBundle, name: String, scale: Double) {
        self.bundle = bundle
        self.name = name
        self.scale = scale
    }

    // MARK: - Equatable

    /// Compares two `AssetBundleImageKey` instances for equality.
    ///
    /// Note: `bundle` is compared by reference identity (`===`) since `AssetBundle`
    /// is a protocol (reference type).
    ///
    /// **Dart Source:** `image_provider.dart:704-713`
    public static func == (lhs: AssetBundleImageKey, rhs: AssetBundleImageKey) -> Bool {
        lhs.bundle === rhs.bundle &&
        lhs.name == rhs.name &&
        lhs.scale == rhs.scale
    }

    // MARK: - Hashable

    /// Hashes the essential components of this key.
    ///
    /// Note: `bundle` is hashed via `ObjectIdentifier` since `AssetBundle` is a
    /// protocol (reference type).
    ///
    /// **Dart Source:** `image_provider.dart:716`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(bundle))
        hasher.combine(name)
        hasher.combine(scale)
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this key.
    ///
    /// **Dart Source:** `image_provider.dart:718-720`
    public var description: String {
        "AssetBundleImageKey(bundle: \(bundle), name: \"\(name)\", scale: \(scale))"
    }
}

// MARK: - AssetBundleImageProvider

/// A subclass of `ImageProvider` that knows about `AssetBundle`s.
///
/// This factors out the common logic of `AssetBundle`-based `ImageProvider`
/// classes, simplifying what subclasses must implement to just `obtainKey`.
///
/// The `loadImage` method loads bytes from the asset bundle, decodes them
/// using the provided decode callback, and wraps the result in a
/// `MultiFrameImageStreamCompleter`.
///
/// Note: The deprecated `loadBuffer()` method from Dart is intentionally not
/// migrated to Swift.
///
/// See also:
///
///  * `AssetImage`, which is a subclass of this.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `AssetBundleImageProvider`
/// **Lines:** 727-790
open class AssetBundleImageProvider: ImageProvider<AssetBundleImageKey>, @unchecked Sendable {

    // MARK: - Initialization

    /// Abstract const constructor. This constructor enables subclasses to provide
    /// convenience initializers so that they can be used in const expressions.
    ///
    /// **Dart Source:** `image_provider.dart:730`
    public override init() {
        super.init()
    }

    // MARK: - loadImage

    /// Converts a key into an `ImageStreamCompleter`, and begins fetching the
    /// image using the asset bundle.
    ///
    /// Creates a `MultiFrameImageStreamCompleter` that loads the asset data
    /// from `key.bundle`, decodes it using the provided `decode` callback,
    /// and produces frames at the scale specified by `key.scale`.
    ///
    /// If the asset is not found or cannot be loaded, the error is reported
    /// through the completer's error handling mechanism.
    ///
    /// Note: The deprecated `loadBuffer()` override is intentionally not
    /// migrated. Only `loadImage` is provided.
    ///
    /// **Dart Source:** `image_provider.dart:733-748`
    open override func loadImage(
        key: AssetBundleImageKey,
        decode: PaintingImageDecoderCallback
    ) -> ImageStreamCompleter {
        // The `decode` parameter is non-escaping, but we need to capture it
        // in the async `codec` closure for `MultiFrameImageStreamCompleter`.
        // We use `withoutActuallyEscaping` to bridge this safely — the closure
        // will be retained by the completer and invoked during image loading.
        let capturedKey = key
        let providerDescription = "\(self)"
        let keyDescription = "\(key)"

        return withoutActuallyEscaping(decode) { escapingDecode in
            let codec: @Sendable () async throws -> any Codec = {
                let buffer: ImmutableBuffer
                // Hot reload/restart could change whether an asset bundle or key in a
                // bundle are available, or if it is a network backed bundle.
                do {
                    buffer = try await capturedKey.bundle.loadBuffer(capturedKey.name)
                } catch let error as FlutterError {
                    _ = PaintingBindingInstance.instance.paintingImageCache.evict(AnyHashable(capturedKey))
                    throw error
                }
                return try await escapingDecode(buffer, nil)
            }

            return MultiFrameImageStreamCompleter(
                codec: codec,
                scale: key.scale,
                debugLabel: key.name,
                informationCollector: {
                    [
                        DiagnosticsProperty("Image provider", providerDescription),
                        DiagnosticsProperty("Image key", keyDescription),
                    ]
                }
            )
        }
    }

}

// MARK: - ResizeImageKey

/// Key used internally by `ResizeImage` to uniquely identify a resized image
/// in the image cache.
///
/// This is `@immutable` in Dart and is therefore a value type (struct) in Swift.
///
/// In Dart, this class has a private constructor so that only `ResizeImage` can
/// create instances. In Swift, we use `internal` access for the initializer to
/// achieve a similar effect within the module.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ResizeImageKey`
/// **Lines:** 796-828
public struct ResizeImageKey: Hashable, CustomStringConvertible {

    // MARK: - Properties

    /// The cache key of the underlying image provider.
    ///
    /// **Dart Source:** `image_provider.dart:807`
    public let providerCacheKey: AnyHashable

    /// The resize policy to apply.
    ///
    /// **Dart Source:** `image_provider.dart:808`
    public let policy: ResizeImagePolicy

    /// The target width, or `nil` to preserve the aspect ratio based on `height`.
    ///
    /// **Dart Source:** `image_provider.dart:809`
    public let width: Int?

    /// The target height, or `nil` to preserve the aspect ratio based on `width`.
    ///
    /// **Dart Source:** `image_provider.dart:810`
    public let height: Int?

    /// Whether the image is allowed to be upscaled.
    ///
    /// **Dart Source:** `image_provider.dart:811`
    public let allowUpscaling: Bool

    // MARK: - Initializer

    /// Creates a `ResizeImageKey`.
    ///
    /// In Dart, this constructor is private (`ResizeImageKey._`). In Swift, it is
    /// `internal` to restrict creation to within the module.
    ///
    /// **Dart Source:** `image_provider.dart:799-805`
    internal init(
        providerCacheKey: AnyHashable,
        policy: ResizeImagePolicy,
        width: Int?,
        height: Int?,
        allowUpscaling: Bool
    ) {
        self.providerCacheKey = providerCacheKey
        self.policy = policy
        self.width = width
        self.height = height
        self.allowUpscaling = allowUpscaling
    }

    // MARK: - Equatable

    /// Compares two `ResizeImageKey` instances for equality.
    ///
    /// **Dart Source:** `image_provider.dart:813-824`
    public static func == (lhs: ResizeImageKey, rhs: ResizeImageKey) -> Bool {
        lhs.providerCacheKey == rhs.providerCacheKey &&
        lhs.policy == rhs.policy &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.allowUpscaling == rhs.allowUpscaling
    }

    // MARK: - Hashable

    /// Hashes the essential components of this key.
    ///
    /// **Dart Source:** `image_provider.dart:827`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(providerCacheKey)
        hasher.combine(policy)
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(allowUpscaling)
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this key.
    public var description: String {
        "ResizeImageKey(providerCacheKey: \(providerCacheKey), policy: \(policy), width: \(String(describing: width)), height: \(String(describing: height)), allowUpscaling: \(allowUpscaling))"
    }
}

// MARK: - ImageProviderProtocol

/// Protocol defining the contract for image providers.
///
/// In Dart, `ImageProvider<T extends Object>` is an abstract class with generics.
/// In Swift, we split the interface into a protocol (for type-erasure and
/// existential usage) and a base open class `ImageProvider<T>`.
///
/// Subclasses / conformances must provide:
///   - `obtainKey(configuration:)` to compute the cache key
///   - `loadImage(key:decode:)` to start fetching the image
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ImageProvider<T extends Object>` (abstract interface)
/// **Lines:** 359-677
public protocol ImageProviderProtocol: AnyObject {

    /// The type of the key used to identify images in the cache.
    ///
    /// Must be `Hashable` so it can be used with `ImageCache` (which stores
    /// keys as `AnyHashable`).
    associatedtype Key: Hashable

    /// Converts this image provider's settings plus an `ImageConfiguration` to a
    /// key that describes the precise image to load.
    ///
    /// The type of the key is determined by the subclass. It is a value that
    /// unambiguously identifies the image (_including its scale_) that the
    /// `loadImage` method will fetch. Different `ImageProvider`s given the same
    /// constructor arguments and `ImageConfiguration` objects should return keys
    /// that are `==` to each other.
    ///
    /// In Dart this returns `Future<T>`; in Swift we use `async throws` to
    /// represent the potentially asynchronous key resolution.
    ///
    /// **Dart Source:** `image_provider.dart:620-633`
    func obtainKey(configuration: ImageConfiguration) async throws -> Key

    /// Converts a key into an `ImageStreamCompleter`, and begins fetching the
    /// image.
    ///
    /// The `decode` callback provides the logic to obtain the codec for the
    /// image.
    ///
    /// See also:
    ///
    ///  * `ResizeImage`, for modifying the key to account for cache dimensions.
    ///
    /// **Dart Source:** `image_provider.dart:655-672`
    func loadImage(key: Key, decode: PaintingImageDecoderCallback) -> ImageStreamCompleter

    /// Called by `resolve` to create the `ImageStream` it returns.
    ///
    /// Subclasses should override this instead of `resolve` if they need to
    /// return some subclass of `ImageStream`. The stream created here will be
    /// passed to `resolveStreamForKey`.
    ///
    /// **Dart Source:** `image_provider.dart:411-419`
    func createStream(configuration: ImageConfiguration) -> ImageStream
}

// MARK: - ImageProvider Base Class

/// Abstract base class for objects that can provide images for rendering.
///
/// In Dart, `ImageProvider<T extends Object>` is an abstract class. In Swift, this
/// is an open generic class that subclasses should extend to implement concrete
/// image providers (e.g. `NetworkImage`, `AssetImage`, `FileImage`).
///
/// The `T` parameter is the key type used to identify images in the cache.
///
/// ## Lifecycle
///
/// `resolve` is the entry point for the image loading lifecycle:
///   1. `resolve` calls `createStream` to produce an `ImageStream`.
///   2. `resolve` calls `obtainKey` asynchronously to compute a cache key.
///   3. `resolve` calls `resolveStreamForKey` with the key and stream.
///   4. `resolveStreamForKey` consults the `ImageCache` and calls `loadImage`
///      if the image is not yet cached.
///
/// ## Subclassing
///
/// Subclasses must override:
///   - `obtainKey(configuration:)` — compute a `T` key for the image
///   - `loadImage(key:decode:)` — start fetching the image data
///
/// Subclasses may optionally override:
///   - `createStream(configuration:)` — provide a custom `ImageStream` subclass
///   - `resolveStreamForKey(...)` — customise cache interaction
///
/// Note: The deprecated `loadBuffer()` method is intentionally not migrated.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ImageProvider<T extends Object>`
/// **Lines:** 359-677
open class ImageProvider<T: Hashable>: ImageProviderProtocol, @unchecked Sendable {

    // MARK: - Key type

    /// The key type for this image provider is `T`.
    public typealias Key = T

    // MARK: - Initialization

    /// Abstract initializer. This constructor enables subclasses to provide
    /// convenience initializers.
    ///
    /// **Dart Source:** `image_provider.dart:362`
    public init() {}

    // MARK: - resolve

    /// Resolves this image provider using the given `configuration`, returning
    /// an `ImageStream`.
    ///
    /// This is the public entry-point of the `ImageProvider` class hierarchy.
    ///
    /// Subclasses should implement `obtainKey` and `loadImage`, which are used
    /// by this method. If they need to change the implementation of
    /// `ImageStream` used, they should override `createStream`. If they need to
    /// manage the actual resolution of the image, they should override
    /// `resolveStreamForKey`.
    ///
    /// This method is `@nonVirtual` in Dart (cannot be overridden); in Swift we
    /// mark it `final` for the same effect.
    ///
    /// **Dart Source:** `image_provider.dart:376-409`
    public final func resolve(_ configuration: ImageConfiguration) -> ImageStream {
        let stream = createStream(configuration: configuration)

        // Asynchronously obtain the key and resolve, handling errors.
        // In Dart, this uses _createErrorHandlerAndKey with zone-based error
        // handling. In Swift, we use a Task to bridge the async obtainKey call.
        _resolveAsync(configuration: configuration, stream: stream)

        return stream
    }

    /// Internal helper that performs the asynchronous portion of `resolve`.
    ///
    /// Separated to avoid Swift 6 strict-concurrency issues with capturing
    /// `self` and `stream` in a `Task` closure.
    ///
    /// Performs the asynchronous key resolution and stream setup.
    ///
    /// Uses `UncheckedSendableBox` to safely capture the non-Sendable
    /// `ImageStream` in a `Task` closure. This mirrors Dart's single-threaded
    /// execution model where all image resolution happens on the main isolate.
    private func _resolveAsync(configuration: ImageConfiguration, stream: ImageStream) {
        let streamBox = UncheckedSendableBox(stream)

        Task {
            let stream = streamBox.value
            do {
                let key = try await self.obtainKey(configuration: configuration)
                var didError = false
                let handleError: ImageErrorListener = { exception, stack in
                    guard !didError else { return }
                    didError = true
                    self._reportResolutionError(
                        stream: stream,
                        exception: exception,
                        stack: stack
                    )
                }
                self.resolveStreamForKey(
                    configuration: configuration,
                    stream: stream,
                    key: key,
                    handleError: handleError
                )
            } catch {
                self._reportResolutionError(
                    stream: stream,
                    exception: error,
                    stack: nil
                )
            }
        }
    }

    /// Reports an error that occurred during image resolution.
    ///
    /// Sets up an `ErrorImageCompleter` on the stream if needed, and calls
    /// `reportError` with an appropriate error description.
    private func _reportResolutionError(
        stream: ImageStream,
        exception: Any,
        stack: String?
    ) {
        if stream.completer == nil {
            stream.setCompleter(ErrorImageCompleter())
        }
        stream.completer!.reportError(
            context: ErrorDescription("while resolving an image"),
            exception: ImageProviderError.resolutionFailed(
                description: "\(exception)",
                stack: stack
            ),
            stack: stack,
            silent: true  // could be a network error or whatnot
        )
    }

    // MARK: - createStream

    /// Called by `resolve` to create the `ImageStream` it returns.
    ///
    /// Subclasses should override this instead of `resolve` if they need to
    /// return some subclass of `ImageStream`. The stream created here will be
    /// passed to `resolveStreamForKey`.
    ///
    /// **Dart Source:** `image_provider.dart:417-419`
    open func createStream(configuration: ImageConfiguration) -> ImageStream {
        return ImageStream()
    }

    // MARK: - resolveStreamForKey

    /// Called by `resolve` with the key returned by `obtainKey`.
    ///
    /// Subclasses should override this method rather than calling `obtainKey` if
    /// they need to use a key directly. The `resolve` method installs
    /// appropriate error handling guards so that errors will bubble up to the
    /// right places in the framework, and passes those guards along to this
    /// method via the `handleError` parameter.
    ///
    /// It is safe for the implementation of this method to call `handleError`
    /// multiple times if multiple errors occur, or if an error is thrown both
    /// synchronously into the current part of the stack and thrown into the
    /// enclosing zone.
    ///
    /// The default implementation uses the key to interact with the `ImageCache`,
    /// calling `ImageCache.putIfAbsent` and notifying listeners of the `stream`.
    /// Implementers that do not call super are expected to correctly use the
    /// `ImageCache`.
    ///
    /// **Dart Source:** `image_provider.dart:524-565`
    open func resolveStreamForKey(
        configuration: ImageConfiguration,
        stream: ImageStream,
        key: T,
        handleError: @escaping ImageErrorListener
    ) {
        // This is an unusual edge case where someone has told us that they found
        // the image we want before getting to this method. We should avoid calling
        // loadImage again, but still update the image cache with LRU information.
        if stream.completer != nil {
            // Stub: In a full implementation, this would call
            //   PaintingBindingInstance.instance.paintingImageCache.putIfAbsent(
            //       AnyHashable(key), { stream.completer! }, onError: handleError)
            // and assert the returned completer is identical to stream.completer.
            //
            // The putIfAbsent method is not yet available on ImageCache.
            return
        }

        // In a full implementation, this calls:
        //   let completer = PaintingBindingInstance.instance.paintingImageCache.putIfAbsent(
        //       AnyHashable(key),
        //       { self.loadImage(key: key, decode: PaintingBindingInstance.instance.instantiateImageCodecWithSize) },
        //       onError: handleError
        //   )
        //   if let completer = completer {
        //       stream.setCompleter(completer)
        //   }
        //
        // For now, we directly call loadImage and set the completer since
        // ImageCache.putIfAbsent is not yet implemented.
        let decode: PaintingImageDecoderCallback = { buffer, getTargetSize in
            try await PaintingBindingInstance.instance.instantiateImageCodecWithSize(
                buffer, getTargetSize: getTargetSize
            )
        }
        let completer = loadImage(key: key, decode: decode)

        // If the result is the sentinel _AbstractImageStreamCompleter, it means
        // the subclass did not override loadImage. The deprecated loadBuffer()
        // fallback is intentionally not implemented.
        if completer is AbstractImageStreamCompleter {
            // No-op: deprecated loadBuffer() path is not migrated.
            return
        }

        stream.setCompleter(completer)
    }

    // MARK: - evict

    /// Evicts an entry from the image cache.
    ///
    /// Returns whether the value was successfully removed.
    ///
    /// The `ImageProvider` used does not need to be the same instance that was
    /// passed to an `Image` widget, but it does need to create a key which is
    /// equal to one.
    ///
    /// The `cache` is optional and defaults to the global image cache.
    ///
    /// The `configuration` is optional and defaults to
    /// `ImageConfiguration.empty`.
    ///
    /// **Dart Source:** `image_provider.dart:611-618`
    public func evict(
        cache: ImageCache? = nil,
        configuration: ImageConfiguration = .empty
    ) async throws -> Bool {
        let resolvedCache = cache ?? imageCache
        let key = try await obtainKey(configuration: configuration)
        return resolvedCache.evict(AnyHashable(key))
    }

    // MARK: - obtainCacheStatus

    /// Returns the cache location for the key that this `ImageProvider` creates.
    ///
    /// The location may be `ImageCacheStatus.untracked`, indicating that this
    /// image provider's key is not available in the `ImageCache`.
    ///
    /// If the `handleError` parameter is nil, errors will be reported to
    /// `FlutterError.onError`, and the method will return nil.
    ///
    /// A completed return value of nil indicates that an error has occurred.
    ///
    /// **Dart Source:** `image_provider.dart:430-466`
    public func obtainCacheStatus(
        configuration: ImageConfiguration,
        handleError: ImageErrorListener? = nil
    ) async -> ImageCacheStatus? {
        do {
            let key = try await obtainKey(configuration: configuration)
            // Stub: In a full implementation, this would call:
            //   PaintingBindingInstance.instance.paintingImageCache.statusForKey(AnyHashable(key))
            // The statusForKey method is not yet available on ImageCache.
            _ = key
            return ImageCacheStatus(pending: false, keepAlive: false, live: false)
        } catch {
            if let handleError = handleError {
                handleError(error, nil)
            } else {
                FlutterError.reportError(
                    FlutterErrorDetails(
                        exception: error,
                        context: ErrorDescription("while checking the cache location of an image")
                    )
                )
            }
            return nil
        }
    }

    // MARK: - obtainKey (abstract)

    /// Converts this image provider's settings plus an `ImageConfiguration` to a
    /// key that describes the precise image to load.
    ///
    /// The type of the key is determined by the subclass. It is a value that
    /// unambiguously identifies the image (_including its scale_) that the
    /// `loadImage` method will fetch. Different `ImageProvider`s given the same
    /// constructor arguments and `ImageConfiguration` objects should return keys
    /// that are `==` to each other.
    ///
    /// Subclasses **must** override this method.
    ///
    /// **Dart Source:** `image_provider.dart:620-633`
    open func obtainKey(configuration: ImageConfiguration) async throws -> T {
        fatalError("Subclasses of ImageProvider must override obtainKey(configuration:)")
    }

    // MARK: - loadImage (abstract)

    /// Converts a key into an `ImageStreamCompleter`, and begins fetching the
    /// image.
    ///
    /// The `decode` callback provides the logic to obtain the codec for the
    /// image.
    ///
    /// Note: The deprecated `loadBuffer()` method is intentionally not migrated.
    /// Subclasses should override `loadImage` directly.
    ///
    /// See also:
    ///
    ///  * `ResizeImage`, for modifying the key to account for cache dimensions.
    ///
    /// **Dart Source:** `image_provider.dart:655-672`
    open func loadImage(key: T, decode: PaintingImageDecoderCallback) -> ImageStreamCompleter {
        return AbstractImageStreamCompleter()
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this image provider.
    ///
    /// **Dart Source:** `image_provider.dart:675-676`
    open var description: String {
        "\(type(of: self))()"
    }
}

// MARK: - AnyImageProvider (Type-erased wrapper)

/// A type-erased wrapper for `ImageProvider` to allow heterogeneous usage.
///
/// Since `ImageProvider` is generic (`ImageProvider<T>`), this type-erased
/// wrapper enables storage in collections and properties that need a
/// non-generic `ImageProvider` type (e.g. `DecorationImage.image`).
///
/// In Dart, `ImageProvider` is not generic at the type level in the same way,
/// so code like `DecorationImage` can store an `ImageProvider<Object>` directly.
/// In Swift, we need this wrapper to erase the generic parameter.
///
/// Can also be subclassed directly for testing or custom providers.
open class AnyImageProvider: Hashable {

    /// Creates a type-erased image provider wrapping the given provider.
    public convenience init<T: Hashable>(_ provider: ImageProvider<T>) {
        self.init()
        self._wrapped = provider
    }

    /// Creates an `AnyImageProvider`. Subclasses should override `resolve`.
    public init() {
        self._wrapped = nil
    }

    private var _wrapped: AnyObject?

    /// Resolves this image provider using the given `configuration`.
    open func resolve(_ configuration: ImageConfiguration) -> ImageStream {
        if let provider = _wrapped {
            // Use the type-erased helper to call resolve on the wrapped provider
            return _anyProviderResolve(provider, configuration)
        }
        fatalError("Subclasses must override resolve(_:)")
    }

    // MARK: - Hashable

    public static func == (lhs: AnyImageProvider, rhs: AnyImageProvider) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// Helper to call resolve on a type-erased wrapped provider.
private func _anyProviderResolve(_ provider: AnyObject, _ configuration: ImageConfiguration) -> ImageStream {
    // The wrapped provider is an ImageProvider<T> for some T.
    // We need to call resolve without knowing T.
    // Since resolve is defined on the base class and doesn't depend on T in its signature,
    // we can use protocol-based dispatch.
    if let resolvable = provider as? _Resolvable {
        return resolvable._resolve(configuration)
    }
    fatalError("Wrapped provider does not support resolve")
}

/// Internal protocol to enable type-erased resolve calls.
private protocol _Resolvable: AnyObject {
    func _resolve(_ configuration: ImageConfiguration) -> ImageStream
}

extension ImageProvider: _Resolvable {
    fileprivate func _resolve(_ configuration: ImageConfiguration) -> ImageStream {
        resolve(configuration)
    }
}

// MARK: - ImageProviderError

/// Errors that can occur during image provider resolution.
///
/// This wraps underlying errors from `obtainKey` or `loadImage` with additional
/// context, providing a Swift `Error` type for the `reportError` method which
/// requires `any Error`.
public enum ImageProviderError: Error, CustomStringConvertible, Sendable {
    /// The image resolution failed with an underlying error.
    case resolutionFailed(description: String, stack: String?)

    public var description: String {
        switch self {
        case .resolutionFailed(let description, _):
            return "Image resolution failed: \(description)"
        }
    }
}

// MARK: - AbstractImageStreamCompleter

/// A class that exists to facilitate backwards compatibility in the transition
/// from `ImageProvider.loadBuffer` to `ImageProvider.loadImage`.
///
/// When `loadImage` returns an instance of this type, `resolveStreamForKey`
/// would normally fall back to calling `loadBuffer`. Since `loadBuffer` is
/// deprecated and not migrated, this serves only as a sentinel value.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `_AbstractImageStreamCompleter`
/// **Lines:** 679-681
internal class AbstractImageStreamCompleter: ImageStreamCompleter {}

// MARK: - ErrorImageCompleter

/// A completer used when resolving an image fails synchronously.
///
/// This is created by `ImageProvider.resolve` when an error occurs during key
/// creation or image loading, to provide a completer to which errors can be
/// reported.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `_ErrorImageCompleter`
/// **Lines:** 1877
public class ErrorImageCompleter: ImageStreamCompleter {}

// MARK: - NetworkImage Protocol

/// An abstract representation of an image that is fetched over the network.
///
/// In Dart, `NetworkImage` is an abstract class with a factory constructor that
/// delegates to platform-specific implementations (e.g. `_network_image_io.NetworkImage`
/// on native platforms, `_network_image_web.NetworkImage` on the web). In Swift,
/// this is modeled as a protocol since Swift does not support factory constructors
/// in the same way. Platform-specific implementations should conform to this
/// protocol.
///
/// It is generally preferable to use `Image.network` to show an image from the
/// network, rather than directly using `NetworkImage`.
///
/// See also:
///
///  * `Image.network` for a shorthand of an `Image` widget backed by
///    `NetworkImage`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `NetworkImage`
/// **Lines:** 1535-1577
public protocol NetworkImageProtocol: ImageProviderProtocol {

    /// The URL from which the image will be fetched.
    ///
    /// **Dart Source:** `image_provider.dart:1551`
    var url: String { get }

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// **Dart Source:** `image_provider.dart:1554`
    var scale: Double { get }

    /// The HTTP headers that will be used with `HttpClient.get` to fetch image
    /// from network.
    ///
    /// When running Flutter on the web, headers are not used.
    ///
    /// **Dart Source:** `image_provider.dart:1559`
    var headers: [String: String]? { get }

    /// On the Web platform, specifies when the image is loaded as a
    /// `WebImageInfo`, which causes `Image.network` to display the image in an
    /// HTML element in a platform view.
    ///
    /// See `Image.network` for more explanation.
    ///
    /// Defaults to `WebHtmlElementStrategy.never`.
    ///
    /// Has no effect on other platforms, which always fetch bytes.
    ///
    /// **Dart Source:** `image_provider.dart:1570`
    var webHtmlElementStrategy: WebHtmlElementStrategy { get }
}

// MARK: - NetworkImageLoadException

/// The exception thrown when the HTTP request to load a network image fails.
///
/// See also:
///
///  * `NetworkImage`, which uses this exception to report HTTP errors.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `NetworkImageLoadException`
/// **Lines:** 1880-1897
public struct NetworkImageLoadException: Error, CustomStringConvertible {

    // MARK: - Properties

    /// The HTTP status code from the server.
    ///
    /// **Dart Source:** `image_provider.dart:1887`
    public let statusCode: Int

    /// Resolved URL of the requested image.
    ///
    /// **Dart Source:** `image_provider.dart:1893`
    public let uri: URL

    /// A human-readable error message.
    ///
    /// **Dart Source:** `image_provider.dart:1890`
    private let _message: String

    // MARK: - Initialization

    /// Creates a `NetworkImageLoadException` with the specified HTTP `statusCode`
    /// and `uri`.
    ///
    /// **Dart Source:** `image_provider.dart:1883-1884`
    public init(statusCode: Int, uri: URL) {
        self.statusCode = statusCode
        self.uri = uri
        self._message = "HTTP request failed, statusCode: \(statusCode), \(uri)"
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this exception.
    ///
    /// **Dart Source:** `image_provider.dart:1896`
    public var description: String { _message }
}

// MARK: - UncheckedSendableBox

/// A box that wraps a non-Sendable value to allow it to cross isolation
/// boundaries.
///
/// This is used internally to capture non-Sendable class references (such as
/// `ImageStream`) in `Task` closures. The caller is responsible for ensuring
/// that concurrent access does not occur. In the Flutter framework, this is
/// safe because image resolution follows Dart's single-isolate execution model.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - ResizeImage

/// Instructs Flutter to decode the image at the specified dimensions
/// instead of at its native size.
///
/// This allows finer control of the size of the image in `ImageCache` and is
/// generally used to reduce the memory footprint of `ImageCache`.
///
/// The decoded image may still be displayed at sizes other than the
/// cached size provided here.
///
/// `ResizeImage` wraps another `ImageProvider` and applies resizing during
/// decode via the `getTargetSize` callback. The `policy` property controls
/// how `width` and `height` are interpreted:
///
///  * `ResizeImagePolicy.exact` — sizes the image to the exact width and/or
///    height specified.
///  * `ResizeImagePolicy.fit` — scales the image to fit within the bounding
///    box defined by width and height while maintaining aspect ratio.
///
/// Note: The deprecated `loadBuffer()` method from Dart is intentionally not
/// migrated to Swift.
///
/// See also:
///
///  * `ResizeImagePolicy`, which controls how the width/height are interpreted.
///  * `ResizeImageKey`, which is the cache key type for this provider.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ResizeImage`
/// **Lines:** 1254-1485
public class ResizeImage: ImageProvider<ResizeImageKey>, @unchecked Sendable {

    // MARK: - Properties

    /// The `ImageProvider` that this class wraps.
    ///
    /// **Dart Source:** `image_provider.dart:1271`
    public let imageProvider: any ImageProviderProtocol

    /// The width the image should decode to and cache.
    ///
    /// At least one of this and `height` must be non-nil.
    ///
    /// **Dart Source:** `image_provider.dart:1276`
    public let width: Int?

    /// The height the image should decode to and cache.
    ///
    /// At least one of this and `width` must be non-nil.
    ///
    /// **Dart Source:** `image_provider.dart:1281`
    public let height: Int?

    /// The policy that determines how `width` and `height` are interpreted.
    ///
    /// Defaults to `ResizeImagePolicy.exact`.
    ///
    /// **Dart Source:** `image_provider.dart:1286`
    public let policy: ResizeImagePolicy

    /// Whether the `width` and `height` parameters should be clamped to the
    /// intrinsic width and height of the image.
    ///
    /// In general, it is better for memory usage to avoid scaling the image
    /// beyond its intrinsic dimensions when decoding it. If there is a need to
    /// scale an image larger, it is better to apply a scale to the canvas, or
    /// to use an appropriate `Image.fit`.
    ///
    /// **Dart Source:** `image_provider.dart:1295`
    public let allowUpscaling: Bool

    // MARK: - Initialization

    /// Creates an `ImageProvider` that decodes the image to the specified size.
    ///
    /// The cached image will be directly decoded and stored at the resolution
    /// defined by `width` and `height`. The image will lose detail and
    /// use less memory if resized to a size smaller than the native size.
    ///
    /// At least one of `width` and `height` must be non-nil.
    ///
    /// **Dart Source:** `image_provider.dart:1262-1268`
    public init(
        _ imageProvider: any ImageProviderProtocol,
        width: Int? = nil,
        height: Int? = nil,
        policy: ResizeImagePolicy = .exact,
        allowUpscaling: Bool = false
    ) {
        assert(width != nil || height != nil,
               "At least one of width and height must be non-nil.")
        self.imageProvider = imageProvider
        self.width = width
        self.height = height
        self.policy = policy
        self.allowUpscaling = allowUpscaling
        super.init()
    }

    // MARK: - resizeIfNeeded

    /// Composes the `provider` in a `ResizeImage` only when `cacheWidth` and
    /// `cacheHeight` are not both nil.
    ///
    /// When `cacheWidth` and `cacheHeight` are both nil, this will return the
    /// `provider` directly.
    ///
    /// **Dart Source:** `image_provider.dart:1302-1311`
    public static func resizeIfNeeded(
        cacheWidth: Int?,
        cacheHeight: Int?,
        provider: any ImageProviderProtocol
    ) -> any ImageProviderProtocol {
        if cacheWidth != nil || cacheHeight != nil {
            return ResizeImage(provider, width: cacheWidth, height: cacheHeight)
        }
        return provider
    }

    // MARK: - loadImage

    /// Converts a key into an `ImageStreamCompleter`, and begins fetching the
    /// image with resize logic applied.
    ///
    /// The resize is performed lazily via the `getTargetSize` callback, which
    /// computes the target dimensions based on the intrinsic image size, the
    /// requested `width`/`height`, the `policy`, and the `allowUpscaling` flag.
    ///
    /// Note: The deprecated `loadBuffer()` override from Dart is intentionally
    /// not migrated. Only `loadImage` is provided.
    ///
    /// **Dart Source:** `image_provider.dart:1350-1426`
    public override func loadImage(
        key: ResizeImageKey,
        decode: PaintingImageDecoderCallback
    ) -> ImageStreamCompleter {
        let capturedWidth = self.width
        let capturedHeight = self.height
        let capturedPolicy = self.policy
        let capturedAllowUpscaling = self.allowUpscaling
        let capturedKey = key

        // Build a wrapping decode callback that injects the resize getTargetSize.
        let decodeResize: PaintingImageDecoderCallback = { buffer, getTargetSize in
            assert(
                getTargetSize == nil,
                "ResizeImage cannot be composed with another ImageProvider that applies getTargetSize."
            )
            return try await decode(buffer, { (intrinsicWidth: Int, intrinsicHeight: Int) -> TargetImageSize in
                switch capturedPolicy {
                case .exact:
                    var targetWidth = capturedWidth
                    var targetHeight = capturedHeight

                    if !capturedAllowUpscaling {
                        if let tw = targetWidth, tw > intrinsicWidth {
                            targetWidth = intrinsicWidth
                        }
                        if let th = targetHeight, th > intrinsicHeight {
                            targetHeight = intrinsicHeight
                        }
                    }

                    return TargetImageSize(
                        width: targetWidth.map { Int64($0) },
                        height: targetHeight.map { Int64($0) }
                    )

                case .fit:
                    let aspectRatio = Double(intrinsicWidth) / Double(intrinsicHeight)
                    let maxWidth = capturedWidth ?? intrinsicWidth
                    let maxHeight = capturedHeight ?? intrinsicHeight
                    var targetWidth = intrinsicWidth
                    var targetHeight = intrinsicHeight

                    if targetWidth > maxWidth {
                        targetWidth = maxWidth
                        targetHeight = Int(Double(targetWidth) / aspectRatio)
                    }

                    if targetHeight > maxHeight {
                        targetHeight = maxHeight
                        targetWidth = Int((Double(targetHeight) * aspectRatio).rounded(.down))
                    }

                    if capturedAllowUpscaling {
                        if capturedWidth == nil {
                            assert(capturedHeight != nil)
                            targetHeight = capturedHeight!
                            targetWidth = Int((Double(targetHeight) * aspectRatio).rounded(.down))
                        } else if capturedHeight == nil {
                            targetWidth = capturedWidth!
                            targetHeight = Int(Double(targetWidth) / aspectRatio)
                        } else {
                            let derivedMaxWidth = Int((Double(maxHeight) * aspectRatio).rounded(.down))
                            let derivedMaxHeight = Int(Double(maxWidth) / aspectRatio)
                            targetWidth = min(maxWidth, derivedMaxWidth)
                            targetHeight = min(maxHeight, derivedMaxHeight)
                        }
                    }

                    return TargetImageSize(width: Int64(targetWidth), height: Int64(targetHeight))
                }
            })
        }

        // Use the inner provider's loadImage with the wrapped decode callback.
        let completer = _loadImageFromProvider(key: capturedKey, decode: decodeResize)
        if !kReleaseMode {
            completer.debugLabel =
                "\(completer.debugLabel ?? "") - Resized(\(String(describing: capturedKey.width))x\(String(describing: capturedKey.height)))"
        }
        _configureErrorListener(completer: completer, key: capturedKey)
        return completer
    }

    /// Loads an image from the wrapped `imageProvider` using type-erased key access.
    ///
    /// Because `imageProvider` is existential (`any ImageProviderProtocol`), we
    /// cannot directly call its generic `loadImage(key:decode:)` with a
    /// `ResizeImageKey`. Instead, we use the provider's own `resolveStreamForKey`
    /// flow. This helper bridges the type-erased provider to produce an
    /// `ImageStreamCompleter`.
    ///
    /// In Dart, this is done by calling `imageProvider.loadImage(key._providerCacheKey, decodeResize)`,
    /// which works because Dart's generics are erased at runtime. In Swift, we
    /// replicate this by calling the provider's loadImage through a type-erased helper.
    private func _loadImageFromProvider(
        key: ResizeImageKey,
        decode: PaintingImageDecoderCallback
    ) -> ImageStreamCompleter {
        return _typeErasedLoadImage(provider: imageProvider, rawKey: key.providerCacheKey, decode: decode)
    }

    /// Configures an ephemeral error listener on the completer that evicts the
    /// cache entry for `key` when an error occurs.
    ///
    /// The eviction is scheduled asynchronously (via `DispatchQueue.main.async`)
    /// to give the image cache a chance to track the key first, mirroring Dart's
    /// `scheduleMicrotask` behavior.
    ///
    /// **Dart Source:** `image_provider.dart:1428-1438`
    private func _configureErrorListener(
        completer: ImageStreamCompleter,
        key: ResizeImageKey
    ) {
        // In Dart, this uses `addEphemeralErrorListener` to schedule a microtask
        // that evicts from the cache. In Swift, we use a one-shot error listener
        // with `DispatchQueue.main.async` to approximate the microtask behavior.
        // Wrap the key in UncheckedSendableBox to safely cross isolation
        // boundaries into the DispatchQueue.main.async closure. This mirrors
        // Dart's scheduleMicrotask which runs on the same isolate.
        let keyBox = UncheckedSendableBox(AnyHashable(key))
        let errorListener = ImageStreamListener(
            { _, _ in },
            onError: { _, _ in
                DispatchQueue.main.async {
                    _ = PaintingBindingInstance.instance.paintingImageCache.evict(keyBox.value)
                }
            }
        )
        completer.addListener(errorListener)
    }

    // MARK: - obtainKey

    /// Converts this image provider's settings plus an `ImageConfiguration` to a
    /// `ResizeImageKey` that describes the precise resized image to load.
    ///
    /// Delegates to the wrapped `imageProvider.obtainKey` and wraps the result
    /// with the resize parameters.
    ///
    /// **Dart Source:** `image_provider.dart:1441-1465`
    public override func obtainKey(configuration: ImageConfiguration) async throws -> ResizeImageKey {
        let innerKey = try await _typeErasedObtainKey(provider: imageProvider, configuration: configuration)
        return ResizeImageKey(
            providerCacheKey: innerKey,
            policy: policy,
            width: width,
            height: height,
            allowUpscaling: allowUpscaling
        )
    }

    // MARK: - Equatable

    /// Compares two `ResizeImage` instances for equality.
    ///
    /// Two `ResizeImage` instances are equal if they wrap the same image provider
    /// (by reference identity) and have the same resize parameters.
    ///
    /// **Dart Source:** `image_provider.dart:1468-1481`
    public static func == (lhs: ResizeImage, rhs: ResizeImage) -> Bool {
        if lhs === rhs { return true }
        return lhs.imageProvider === rhs.imageProvider &&
            lhs.width == rhs.width &&
            lhs.height == rhs.height &&
            lhs.policy == rhs.policy &&
            lhs.allowUpscaling == rhs.allowUpscaling
    }

    // MARK: - Hashable

    /// A hash value for this `ResizeImage`, based on the wrapped provider's
    /// identity and the resize parameters.
    ///
    /// **Dart Source:** `image_provider.dart:1484`
    public var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(imageProvider))
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(policy)
        hasher.combine(allowUpscaling)
        return hasher.finalize()
    }

    // MARK: - Description

    /// A string representation of this resize image provider.
    public override var description: String {
        "ResizeImage(\(imageProvider), width: \(String(describing: width)), height: \(String(describing: height)), policy: \(policy), allowUpscaling: \(allowUpscaling))"
    }
}

// MARK: - Type-Erased ImageProvider Helpers

/// Calls `obtainKey` on a type-erased `ImageProviderProtocol` and returns the
/// result as `AnyHashable`.
///
/// This is needed because `ResizeImage` holds an existential
/// (`any ImageProviderProtocol`) and cannot directly call the generic
/// `obtainKey` method. This free function opens the existential.
private func _typeErasedObtainKey(
    provider: any ImageProviderProtocol,
    configuration: ImageConfiguration
) async throws -> AnyHashable {
    return try await _openedObtainKey(provider: provider, configuration: configuration)
}

/// Helper that opens the existential type of `provider` so we can call
/// `obtainKey` and wrap the result in `AnyHashable`.
private func _openedObtainKey<P: ImageProviderProtocol>(
    provider: P,
    configuration: ImageConfiguration
) async throws -> AnyHashable {
    let key = try await provider.obtainKey(configuration: configuration)
    return AnyHashable(key)
}

/// Calls `loadImage` on a type-erased `ImageProviderProtocol` with a raw key
/// obtained from `ResizeImageKey.providerCacheKey`.
///
/// This is needed because `ResizeImage` wraps an existential and cannot call
/// the generic `loadImage(key:decode:)` directly. This free function opens
/// the existential to perform the call.
private func _typeErasedLoadImage(
    provider: any ImageProviderProtocol,
    rawKey: AnyHashable,
    decode: PaintingImageDecoderCallback
) -> ImageStreamCompleter {
    return _openedLoadImage(provider: provider, rawKey: rawKey, decode: decode)
}

/// Helper that opens the existential type of `provider` so we can call
/// `loadImage` with the correct key type.
///
/// The `rawKey` is expected to be an `AnyHashable` wrapping a value of
/// `P.Key`. If the downcast fails, a fatal error is raised (this would
/// indicate a programming error in the framework).
private func _openedLoadImage<P: ImageProviderProtocol>(
    provider: P,
    rawKey: AnyHashable,
    decode: PaintingImageDecoderCallback
) -> ImageStreamCompleter {
    guard let typedKey = rawKey.base as? P.Key else {
        fatalError(
            "ResizeImage: could not downcast key of type \(type(of: rawKey.base)) "
            + "to \(P.Key.self) for provider \(type(of: provider))."
        )
    }
    return provider.loadImage(key: typedKey, decode: decode)
}

// MARK: - FileImageKey

/// Cache key used by `FileImage` to uniquely identify a file-based image.
///
/// In Dart, `FileImage` uses itself as the key type
/// (`ImageProvider<FileImage>`). In Swift, self-referential generic constraints
/// are not supported, so we use a separate value-type key that captures the
/// file path and scale — the same fields Dart's `FileImage` uses for equality
/// and hashing.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** Part of `FileImage` (lines 1642-1651)
public struct FileImageKey: Hashable, CustomStringConvertible, Sendable {

    /// The file path to decode into an image.
    ///
    /// **Dart Source:** `image_provider.dart:1594` (via `file.path`)
    public let filePath: String

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// **Dart Source:** `image_provider.dart:1597`
    public let scale: Double

    /// Creates a key for a `FileImage`.
    public init(filePath: String, scale: Double) {
        self.filePath = filePath
        self.scale = scale
    }

    /// A string representation of this key.
    public var description: String {
        "FileImageKey(\"\(filePath)\", scale: \(String(format: "%.1f", scale)))"
    }
}

// MARK: - FileImage

/// Decodes a file as an image, associating it with the given scale.
///
/// The file at the given `URL` must contain encoded image data in one of the
/// supported image formats. The image is decoded from the file bytes when it
/// is needed.
///
/// In Dart, `FileImage` extends `ImageProvider<FileImage>` (using itself as the
/// key type). In Swift, self-referential generic constraints are not supported,
/// so we use a separate `FileImageKey` struct as the cache key.
///
/// See also:
///
///  * `Image.file` for a shorthand of an `Image` widget backed by `FileImage`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `FileImage`
/// **Lines:** 1588-1656
public final class FileImage: ImageProvider<FileImageKey>, @unchecked Sendable {

    // MARK: - Properties

    /// The file to decode into an image.
    ///
    /// In Dart this is `File`; in Swift we use `URL` for file paths.
    ///
    /// **Dart Source:** `image_provider.dart:1594`
    public let file: URL

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// **Dart Source:** `image_provider.dart:1597`
    public let scale: Double

    // MARK: - Initialization

    /// Creates an object that decodes a file as an image.
    ///
    /// **Dart Source:** `image_provider.dart:1591`
    public init(_ file: URL, scale: Double = 1.0) {
        self.file = file
        self.scale = scale
        super.init()
    }

    // MARK: - obtainKey

    /// Returns a `FileImageKey` for this image provider.
    ///
    /// In Dart this returns `SynchronousFuture<FileImage>(this)`, which
    /// completes synchronously, using the `FileImage` itself as the key.
    /// In Swift, we return a `FileImageKey` value type that captures the
    /// same fields used for equality and hashing.
    ///
    /// **Dart Source:** `image_provider.dart:1600-1602`
    public override func obtainKey(configuration: ImageConfiguration) async throws -> FileImageKey {
        return FileImageKey(filePath: file.path, scale: scale)
    }

    // MARK: - loadImage

    /// Converts a key into an `ImageStreamCompleter`, and begins fetching the
    /// image from the file system.
    ///
    /// Creates a `MultiFrameImageStreamCompleter` that loads the file bytes,
    /// decodes them using the provided `decode` callback, and produces frames
    /// at the scale specified by `key.scale`.
    ///
    /// If the file is empty or cannot be loaded, the image is evicted from the
    /// cache and an error is thrown.
    ///
    /// **Dart Source:** `image_provider.dart:1614-1623`
    public override func loadImage(
        key: FileImageKey,
        decode: PaintingImageDecoderCallback
    ) -> ImageStreamCompleter {
        let capturedKey = key
        let filePath = key.filePath

        return withoutActuallyEscaping(decode) { escapingDecode in
            let codec: @Sendable () async throws -> any Codec = {
                // Load the file from the file system.
                // In Dart, this uses ImmutableBuffer.fromFilePath for standard File
                // instances, falling back to readAsBytes() for subclasses.
                // In Swift, we use ImmutableBuffer.fromFilePath directly.
                let buffer: ImmutableBuffer
                do {
                    buffer = try ImmutableBuffer.fromFilePath(filePath)
                } catch {
                    // The file may become available later.
                    _ = PaintingBindingInstance.instance.paintingImageCache.evict(AnyHashable(capturedKey))
                    throw error
                }

                if buffer.length == 0 {
                    // The file may become available later.
                    _ = PaintingBindingInstance.instance.paintingImageCache.evict(AnyHashable(capturedKey))
                    throw FlutterError(
                        "\(filePath) is empty and cannot be loaded as an image."
                    )
                }

                return try await escapingDecode(buffer, nil)
            }

            return MultiFrameImageStreamCompleter(
                codec: codec,
                scale: key.scale,
                debugLabel: filePath,
                informationCollector: {
                    [ErrorDescription("Path: \(filePath)")]
                }
            )
        }
    }

    // MARK: - Equatable

    /// Compares two `FileImage` instances for equality.
    ///
    /// Two `FileImage` instances are equal if they reference the same file path
    /// and have the same scale.
    ///
    /// **Dart Source:** `image_provider.dart:1642-1648`
    public static func == (lhs: FileImage, rhs: FileImage) -> Bool {
        if lhs === rhs { return true }
        return lhs.file.path == rhs.file.path && lhs.scale == rhs.scale
    }

    // MARK: - Hashable

    /// A hash value for this `FileImage`, based on the file path and scale.
    ///
    /// **Dart Source:** `image_provider.dart:1651`
    public var hash: Int {
        var hasher = Hasher()
        hasher.combine(file.path)
        hasher.combine(scale)
        return hasher.finalize()
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this file image.
    ///
    /// **Dart Source:** `image_provider.dart:1654-1655`
    public override var description: String {
        "FileImage(\"\(file.path)\", scale: \(String(format: "%.1f", scale)))"
    }
}

// MARK: - MemoryImageKey

/// Cache key used by `MemoryImage` to uniquely identify a memory-based image.
///
/// In Dart, `MemoryImage` uses itself as the key type
/// (`ImageProvider<MemoryImage>`). In Swift, self-referential generic constraints
/// are not supported, so we use a separate value-type key that captures the
/// bytes and scale — the same fields Dart's `MemoryImage` uses for equality
/// and hashing.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** Part of `MemoryImage` (lines 1722-1731)
public struct MemoryImageKey: Hashable, CustomStringConvertible, Sendable {

    /// The bytes to decode into an image.
    ///
    /// **Dart Source:** `image_provider.dart:1683` (via `bytes`)
    public let bytes: [UInt8]

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// **Dart Source:** `image_provider.dart:1691`
    public let scale: Double

    /// Creates a key for a `MemoryImage`.
    public init(bytes: [UInt8], scale: Double) {
        self.bytes = bytes
        self.scale = scale
    }

    /// A string representation of this key.
    public var description: String {
        "MemoryImageKey(\(bytes.count) bytes, scale: \(String(format: "%.1f", scale)))"
    }
}

// MARK: - MemoryImage

/// Decodes the given `[UInt8]` buffer as an image, associating it with the
/// given scale.
///
/// The provided `bytes` buffer should not be changed after it is provided
/// to a `MemoryImage`. To provide an `ImageStream` that represents an image
/// that changes over time, consider creating a new subclass of `ImageProvider`
/// whose `loadImage` method returns a subclass of `ImageStreamCompleter` that
/// can handle providing multiple images.
///
/// In Dart, `MemoryImage` extends `ImageProvider<MemoryImage>` (using itself as
/// the key type). In Swift, self-referential generic constraints are not
/// supported, so we use a separate `MemoryImageKey` struct as the cache key.
///
/// See also:
///
///  * `Image.memory` for a shorthand of an `Image` widget backed by `MemoryImage`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `MemoryImage`
/// **Lines:** 1671-1736
public final class MemoryImage: ImageProvider<MemoryImageKey>, @unchecked Sendable {

    // MARK: - Properties

    /// The bytes to decode into an image.
    ///
    /// The bytes represent encoded image bytes and can be encoded in any of the
    /// supported image formats (JPEG, PNG, GIF, animated GIF, WebP, animated
    /// WebP, BMP, and WBMP).
    ///
    /// In Dart this is `Uint8List`; in Swift we use `[UInt8]`.
    ///
    /// See also:
    ///
    ///  * `PaintingBinding.instantiateImageCodecWithSize`
    ///
    /// **Dart Source:** `image_provider.dart:1683`
    public let bytes: [UInt8]

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// See also:
    ///
    ///  * `ImageInfo.scale`, which gives more information on how this scale is
    ///    applied.
    ///
    /// **Dart Source:** `image_provider.dart:1691`
    public let scale: Double

    // MARK: - Initialization

    /// Creates an object that decodes a byte buffer as an image.
    ///
    /// **Dart Source:** `image_provider.dart:1673`
    public init(_ bytes: [UInt8], scale: Double = 1.0) {
        self.bytes = bytes
        self.scale = scale
        super.init()
    }

    // MARK: - obtainKey

    /// Returns a `MemoryImageKey` for this image provider.
    ///
    /// In Dart this returns `SynchronousFuture<MemoryImage>(this)`, which
    /// completes synchronously, using the `MemoryImage` itself as the key.
    /// In Swift, we return a `MemoryImageKey` value type that captures the
    /// same fields used for equality and hashing.
    ///
    /// **Dart Source:** `image_provider.dart:1694-1696`
    public override func obtainKey(configuration: ImageConfiguration) async throws -> MemoryImageKey {
        return MemoryImageKey(bytes: bytes, scale: scale)
    }

    // MARK: - loadImage

    /// Converts a key into an `ImageStreamCompleter`, and begins decoding the
    /// image from the in-memory byte buffer.
    ///
    /// Creates a `MultiFrameImageStreamCompleter` that wraps the bytes in an
    /// `ImmutableBuffer`, decodes them using the provided `decode` callback,
    /// and produces frames at the scale specified by `key.scale`.
    ///
    /// **Dart Source:** `image_provider.dart:1708-1715`
    public override func loadImage(
        key: MemoryImageKey,
        decode: PaintingImageDecoderCallback
    ) -> ImageStreamCompleter {
        let capturedBytes = key.bytes
        let debugIdentity = "MemoryImage(\(key.bytes.count) bytes)"

        return withoutActuallyEscaping(decode) { escapingDecode in
            let codec: @Sendable () async throws -> any Codec = {
                let buffer = ImmutableBuffer.fromUint8List(capturedBytes)
                return try await escapingDecode(buffer, nil)
            }

            return MultiFrameImageStreamCompleter(
                codec: codec,
                scale: key.scale,
                debugLabel: debugIdentity
            )
        }
    }

    // MARK: - Equatable

    /// Compares two `MemoryImage` instances for equality.
    ///
    /// Two `MemoryImage` instances are equal if they hold identical byte buffers
    /// and have the same scale.
    ///
    /// **Dart Source:** `image_provider.dart:1722-1728`
    public static func == (lhs: MemoryImage, rhs: MemoryImage) -> Bool {
        if lhs === rhs { return true }
        return lhs.bytes == rhs.bytes && lhs.scale == rhs.scale
    }

    // MARK: - Hashable

    /// A hash value for this `MemoryImage`, based on the bytes and scale.
    ///
    /// **Dart Source:** `image_provider.dart:1731`
    public var hash: Int {
        var hasher = Hasher()
        hasher.combine(bytes)
        hasher.combine(scale)
        return hasher.finalize()
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this memory image.
    ///
    /// **Dart Source:** `image_provider.dart:1734-1735`
    public override var description: String {
        "MemoryImage(\(bytes.count) bytes, scale: \(String(format: "%.1f", scale)))"
    }
}

// MARK: - ExactAssetImage

/// Fetches an image from an `AssetBundle`, associating it with the given scale.
///
/// This implementation does not perform any resolution, unlike `AssetImage`
/// which resolves the image to match the device pixel ratio of the
/// `ImageConfiguration` given in the `resolve` call. The exact asset specified
/// in the `assetName` argument is fetched at the given `scale`.
///
/// This class differs from `AssetImage` in that the scale is fixed at
/// construction time rather than being resolved from the device pixel ratio.
/// The `obtainKey` method returns the key directly (synchronously) without
/// any async resolution step.
///
/// ## Fetching assets
///
/// When fetching an image provided by the app itself, use the `assetName`
/// argument to name the asset to choose. For instance, consider a directory
/// `icons` with an image `heart.png`. First, the `pubspec.yaml` of the project
/// should specify its assets in the `flutter` section:
///
/// ```yaml
///   assets:
///     - icons/heart.png
/// ```
///
/// Then, to fetch the image and associate it with scale 1.5, use:
///
/// ```swift
/// let image = ExactAssetImage("icons/heart.png", scale: 1.5)
/// ```
///
/// ## Assets in packages
///
/// To fetch an asset from a package, the `package` argument must be provided.
/// The asset name is then prefixed with `packages/<package_name>/` to form
/// the key used with the `AssetBundle`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_provider.dart`
/// **Original Name:** `ExactAssetImage`
/// **Lines:** 1809-1874
public final class ExactAssetImage: AssetBundleImageProvider, @unchecked Sendable {

    // MARK: - Properties

    /// The name of the asset.
    ///
    /// **Dart Source:** `image_provider.dart:1823`
    public let assetName: String

    /// The key to use to obtain the resource from the `bundle`. This is the
    /// argument passed to `AssetBundle.load`.
    ///
    /// If the `package` is non-nil, the key name is prefixed with
    /// `packages/<package>/`.
    ///
    /// **Dart Source:** `image_provider.dart:1827`
    public var keyName: String {
        package == nil ? assetName : "packages/\(package!)/\(assetName)"
    }

    /// The scale to place in the `ImageInfo` object of the image.
    ///
    /// Unlike `AssetImage`, this scale is fixed at construction time rather
    /// than being resolved from the device pixel ratio.
    ///
    /// **Dart Source:** `image_provider.dart:1830`
    public let scale: Double

    /// The bundle from which the image will be obtained.
    ///
    /// If the provided `bundle` is nil, the bundle provided in the
    /// `ImageConfiguration` passed to the `resolve` call will be used instead.
    /// If that is also nil, the `rootBundle` is used.
    ///
    /// The image is obtained by calling `AssetBundle.load` on the given `bundle`
    /// using the key given by `keyName`.
    ///
    /// **Dart Source:** `image_provider.dart:1840`
    public let bundle: (any AssetBundle)?

    /// The name of the package from which the image is included. See the
    /// documentation for the `ExactAssetImage` class itself for details.
    ///
    /// **Dart Source:** `image_provider.dart:1844`
    public let package: String?

    // MARK: - Initialization

    /// Creates an object that fetches the given image from an asset bundle.
    ///
    /// The `scale` argument defaults to 1.0. The `bundle` argument may be nil, in
    /// which case the bundle provided in the `ImageConfiguration` passed to the
    /// `resolve` call will be used instead.
    ///
    /// The `package` argument must be non-nil when fetching an asset that is
    /// included in a package. See the documentation for the `ExactAssetImage`
    /// class itself for details.
    ///
    /// **Dart Source:** `image_provider.dart:1820`
    public init(
        _ assetName: String,
        scale: Double = 1.0,
        bundle: (any AssetBundle)? = nil,
        package: String? = nil
    ) {
        self.assetName = assetName
        self.scale = scale
        self.bundle = bundle
        self.package = package
        super.init()
    }

    // MARK: - obtainKey

    /// Returns an `AssetBundleImageKey` for this image provider.
    ///
    /// Unlike `AssetImage`, this does not perform any async resolution. The key
    /// is returned directly using the fixed `scale` and `keyName`.
    ///
    /// The bundle is resolved in order: the explicitly provided `bundle`, then
    /// the bundle from `configuration`, then `rootBundle`.
    ///
    /// **Dart Source:** `image_provider.dart:1847-1855`
    public override func obtainKey(configuration: ImageConfiguration) async throws -> AssetBundleImageKey {
        return AssetBundleImageKey(
            bundle: bundle ?? configuration.bundle ?? rootBundle,
            name: keyName,
            scale: scale
        )
    }

    // MARK: - Equatable

    /// Compares two `ExactAssetImage` instances for equality.
    ///
    /// Two `ExactAssetImage` instances are equal if they have the same `keyName`,
    /// `scale`, and `bundle` (compared by reference identity).
    ///
    /// **Dart Source:** `image_provider.dart:1858-1866`
    public static func == (lhs: ExactAssetImage, rhs: ExactAssetImage) -> Bool {
        if lhs === rhs { return true }
        return lhs.keyName == rhs.keyName &&
            lhs.scale == rhs.scale &&
            lhs.bundle === rhs.bundle
    }

    // MARK: - Hashable

    /// A hash value for this `ExactAssetImage`, based on `keyName`, `scale`,
    /// and `bundle`.
    ///
    /// **Dart Source:** `image_provider.dart:1869`
    public var hash: Int {
        var hasher = Hasher()
        hasher.combine(keyName)
        hasher.combine(scale)
        if let bundle = bundle {
            hasher.combine(ObjectIdentifier(bundle))
        }
        return hasher.finalize()
    }

    // MARK: - CustomStringConvertible

    /// A string representation of this exact asset image.
    ///
    /// **Dart Source:** `image_provider.dart:1872-1873`
    public override var description: String {
        "ExactAssetImage(name: \"\(keyName)\", scale: \(String(format: "%.1f", scale)), bundle: \(String(describing: bundle)))"
    }
}
