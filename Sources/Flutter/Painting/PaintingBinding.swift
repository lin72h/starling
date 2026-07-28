// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Binding for the painting library.
///
/// Hooks into the cache eviction logic to clear the image cache.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/binding.dart`
///
/// NOTE: The deprecated `instantiateImageCodecFromBuffer` method (Dart lines 108-126)
/// is intentionally not migrated per the migration guide's deprecation policy.

import FlutterSwiftBridge

// MARK: - PaintingBinding Protocol

/// Binding for the painting library.
///
/// Hooks into the cache eviction logic to clear the image cache.
///
/// Requires the `ServicesBinding` to be mixed in earlier.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/binding.dart`
/// **Original Name:** `PaintingBinding` (mixin)
/// **Lines:** 23-186
public protocol PaintingBinding: ServicesBinding, AnyObject {
    /// The singleton that implements the Flutter framework's image cache.
    ///
    /// The cache is used internally by `ImageProvider` and should generally not
    /// be accessed directly.
    ///
    /// The image cache is created during startup by the `createImageCache`
    /// method.
    ///
    /// **Dart Source:** `binding.dart:71-79`
    var paintingImageCache: ImageCache { get }

    /// Creates the `ImageCache` singleton (accessible via `paintingImageCache`).
    ///
    /// This method can be overridden to provide a custom image cache.
    ///
    /// **Dart Source:** `binding.dart:81-85`
    func createImageCache() -> ImageCache

    /// Calls through to `instantiateImageCodecWithSize` from `ImageCache`.
    ///
    /// The `buffer` parameter should be an `ImmutableBuffer` instance which can
    /// be acquired from `ImmutableBuffer.fromUint8List` or `ImmutableBuffer.fromAsset`.
    ///
    /// The `getTargetSize` parameter, when specified, will be invoked and passed
    /// the image's intrinsic size to determine the size to decode the image to.
    /// The width and the height of the size it returns must be positive values
    /// greater than or equal to 1, or null. It is valid to return a `TargetImageSize`
    /// that specifies only one of `width` and `height` with the other remaining
    /// null, in which case the omitted dimension will be scaled to maintain the
    /// aspect ratio of the original dimensions. When both are null or omitted,
    /// the image will be decoded at its native resolution (as will be the case if
    /// the `getTargetSize` parameter is omitted).
    ///
    /// **Dart Source:** `binding.dart:128-148`
    func instantiateImageCodecWithSize(
        _ buffer: ImmutableBuffer,
        getTargetSize: TargetImageSizeCallback?
    ) async throws -> any Codec

    /// Listenable that notifies when the available fonts on the system have
    /// changed.
    ///
    /// System fonts can change when the system installs or removes new font. To
    /// correctly reflect the change, it is important to relayout text related
    /// widgets when this happens.
    ///
    /// Objects that show text and/or measure text (e.g. via `TextPainter` or
    /// `Paragraph`) should listen to this and redraw/remeasure.
    ///
    /// **Dart Source:** `binding.dart:163-173`
    var systemFonts: SystemFontsNotifier { get }
}

// MARK: - PaintingBinding Default Implementations

extension PaintingBinding {
    /// Initialize the painting binding instances.
    ///
    /// This method should be called by concrete binding implementations from their
    /// `initInstances()` method. It executes the optional shader warm-up if configured.
    ///
    /// In the Dart source, this is part of the mixin's `initInstances()` override
    /// which also sets up `_instance` and `_imageCache`. In Swift, since protocols
    /// can't have stored properties, the singleton management is handled by
    /// `PaintingBindingInstance` (Subtask 5) and image cache storage must be
    /// provided by the conforming type.
    ///
    /// Typical usage in a concrete binding:
    /// ```swift
    /// class MyBinding: BindingBase, PaintingBinding {
    ///     private var _imageCache: ImageCache!
    ///     private let _systemFonts = SystemFontsNotifier()
    ///
    ///     var paintingImageCache: ImageCache { _imageCache }
    ///     var systemFonts: SystemFontsNotifier { _systemFonts }
    ///
    ///     override func initInstances() {
    ///         super.initInstances()
    ///         _imageCache = createImageCache()
    ///         initPaintingBinding()
    ///     }
    /// }
    /// ```
    ///
    /// **Dart Source:** `binding.dart:25-30`
    public func initPaintingBinding() async {
        // Execute shader warm-up if configured
        // Note: The shaderWarmUp static property is defined in PaintingBindingConfiguration (Subtask 5)
        // For now, this is a placeholder that concrete implementations can extend
        await PaintingBindingConfiguration.shaderWarmUp?.execute()
    }

    /// Default implementation of `createImageCache`.
    ///
    /// Returns a new `ImageCache` instance.
    ///
    /// **Dart Source:** `binding.dart:84-85`
    public func createImageCache() -> ImageCache {
        return ImageCache()
    }

    /// Default implementation of `instantiateImageCodecWithSize`.
    ///
    /// Calls through to the FlutterSwiftBridge `instantiateImageCodecWithSize` function.
    ///
    /// **Dart Source:** `binding.dart:143-148`
    public func instantiateImageCodecWithSize(
        _ buffer: ImmutableBuffer,
        getTargetSize: TargetImageSizeCallback? = nil
    ) async throws -> any Codec {
        return try await FlutterSwiftBridge.instantiateImageCodecWithSize(
            buffer,
            getTargetSize: getTargetSize
        )
    }

    /// Default implementation of `evict`.
    ///
    /// Clears the image cache when an asset is evicted.
    ///
    /// **Dart Source:** `binding.dart:150-155`
    public func evict(_ asset: String) {
        // Note: In Swift protocols, we can't call super. The concrete binding
        // implementation should handle calling any parent evict behavior.
        paintingImageCache.clear()
        paintingImageCache.clearLiveImages()
    }

    /// Default implementation of `handleMemoryPressure`.
    ///
    /// Clears the image cache on memory pressure.
    ///
    /// **Dart Source:** `binding.dart:157-161`
    public func handleMemoryPressure() {
        // Note: In Swift protocols, we can't call super. The concrete binding
        // implementation should handle calling any parent handleMemoryPressure behavior.
        paintingImageCache.clear()
    }

    /// Default implementation of `handleSystemMessage`.
    ///
    /// Handles 'fontsChange' system messages by notifying system fonts listeners.
    ///
    /// **Dart Source:** `binding.dart:175-185`
    public func handleSystemMessage(_ systemMessage: Any) async {
        // Note: In Swift protocols, we can't call super. The concrete binding
        // implementation should handle calling any parent handleSystemMessage behavior.
        guard let message = systemMessage as? [String: Any],
              let type = message["type"] as? String else {
            return
        }
        switch type {
        case "fontsChange":
            systemFonts.notifyListeners()
        default:
            break
        }
    }
}

// MARK: - PaintingBindingConfiguration

/// Static configuration for the painting binding.
///
/// This enum provides static configuration options that can be set before the
/// binding is initialized.
///
/// **Dart Source:** `binding.dart:40-69`
public enum PaintingBindingConfiguration {
    /// `ShaderWarmUp` instance to be executed during `initInstances`.
    ///
    /// Defaults to `nil`, meaning no shader warm-up is done. Some platforms may
    /// not support shader warm-up before at least one frame has been displayed.
    ///
    /// If the application has scenes that require the compilation of complex
    /// shaders, it may cause jank in the middle of an animation or interaction.
    /// In that case, setting `shaderWarmUp` to a custom `ShaderWarmUp` before
    /// creating the binding (usually before calling `runApp` for normal Flutter apps)
    /// may help if that object paints the difficult scene in its
    /// `warmUpOnCanvas` method, as this allows Flutter to pre-compile and cache
    /// the required shaders during startup.
    ///
    /// Currently the warm-up happens synchronously on the raster thread which
    /// means the rendering of the first frame on the raster thread will be
    /// postponed until the warm-up is finished.
    ///
    /// The warm up is only costly (100ms-200ms, depending on the shaders to
    /// compile) during the first run after the installation or a data wipe. The
    /// warm up does not block the platform thread so there should be no
    /// "Application Not Responding" warning.
    ///
    /// **Dart Source:** `binding.dart:40-69`
    nonisolated(unsafe) public static var shaderWarmUp: (any ShaderWarmUp)?
}

// MARK: - PaintingBindingInstance

/// Singleton holder for the `PaintingBinding` instance.
///
/// This enum provides static access to the current `PaintingBinding` instance,
/// mirroring the Dart pattern where the mixin has a static `instance` getter
/// and `_instance` storage.
///
/// **Dart Source:** `binding.dart:37-38`
public enum PaintingBindingInstance {
    /// Private storage for the singleton instance.
    ///
    /// Uses a weak reference to avoid retain cycles, matching the Dart pattern
    /// where the binding is typically held by a concrete binding class.
    ///
    /// **Dart Source:** `binding.dart:38`
    nonisolated(unsafe) private static weak var _instance: (any PaintingBinding)?

    /// The current `PaintingBinding`, if one has been created.
    ///
    /// Provides access to the features exposed by the `PaintingBinding` protocol.
    /// The binding must be initialized before using this getter; this is typically
    /// done by calling `runApp` or `WidgetsFlutterBinding.ensureInitialized`.
    ///
    /// - Returns: The current `PaintingBinding` instance.
    /// - Precondition: The binding must have been initialized via `setInstance(_:)`.
    ///
    /// **Dart Source:** `binding.dart:37`
    public static var instance: any PaintingBinding {
        guard let instance = _instance else {
            fatalError(
                "PaintingBinding has not been initialized. "
                + "Ensure runApp() or WidgetsFlutterBinding.ensureInitialized() has been called."
            )
        }
        return instance
    }

    /// Sets the current `PaintingBinding` instance.
    ///
    /// This method should be called by concrete binding implementations from their
    /// `initInstances()` method after calling `super.initInstances()`.
    ///
    /// Typical usage in a concrete binding:
    /// ```swift
    /// class MyBinding: BindingBase, PaintingBinding {
    ///     override func initInstances() {
    ///         super.initInstances()
    ///         PaintingBindingInstance.setInstance(self)
    ///         // ... additional initialization
    ///     }
    /// }
    /// ```
    ///
    /// **Dart Source:** `binding.dart:27`
    public static func setInstance(_ binding: any PaintingBinding) {
        _instance = binding
    }
}

// MARK: - Top-level imageCache accessor

/// The singleton that implements the Flutter framework's image cache.
///
/// The cache is used internally by `ImageProvider` and should generally not be
/// accessed directly.
///
/// The image cache is created during startup by the `PaintingBinding`'s
/// `createImageCache()` method.
///
/// **Dart Source:** `binding.dart:208-215`
public var imageCache: ImageCache {
    return PaintingBindingInstance.instance.paintingImageCache
}
