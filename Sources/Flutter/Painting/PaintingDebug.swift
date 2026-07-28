// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Debug utilities for the painting library.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/debug.dart`

import FlutterSwiftBridge

// MARK: - Debug Flags

/// Whether to replace all shadows with solid color blocks.
///
/// This is useful when writing golden file tests since the rendering of shadows
/// is not guaranteed to be pixel-for-pixel identical from version to version
/// (or even from run to run).
///
/// This is set to true in automated test bindings. Tests will fail if they
/// change this value and do not reset it before the end of the test.
///
/// When this is set, `BoxShadow.toPaint()` acts as if the `blurStyle`
/// was `.normal` regardless of the actual specified blur style. This
/// is compensated for in `BoxDecoration` and `ShapeDecoration` but may need to
/// be explicitly considered in other situations.
///
/// This property should not be changed during a frame (e.g. during a call to
/// `ShapeBorder.paintInterior` or `ShapeBorder.getOuterPath`); doing so may
/// cause undefined effects.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/debug.dart:40`
/// **Original Name:** `debugDisableShadows`
nonisolated(unsafe) public var debugDisableShadows: Bool = false

// MARK: - debugCheckCanResolveTextDirection

/// Asserts that a given TextDirection is not null.
///
/// Used by painting library classes that require a TextDirection to resolve
/// their properties, such as `AlignmentDirectional` and `BorderRadiusDirectional`.
///
/// Does nothing if asserts are disabled. Always returns true.
///
/// **Dart Source:** `debug.dart:246-271` - `debugCheckCanResolveTextDirection()`
///
/// - Parameters:
///   - direction: The TextDirection to check.
///   - target: A string describing the target property being resolved (e.g., "AlignmentDirectional").
/// - Returns: Always returns `true` (assertion runs in debug mode only).
@discardableResult
public func debugCheckCanResolveTextDirection(
    _ direction: TextDirection?,
    _ target: String
) -> Bool {
    #if DEBUG
    assert(direction != nil, """
        No TextDirection found.

        To resolve \(target) properties, it must be provided with a TextDirection.

        This error usually occurs when \(target) is used in a widget without
        a Directionality ancestor.

        Typically, the Directionality widget is introduced by the MaterialApp
        or WidgetsApp widget at the top of your application widget tree. It
        determines the ambient reading direction and is used, for example, to
        determine how to lay out text, how to interpret "start" and "end"
        values, and to resolve EdgeInsetsDirectional,
        AlignmentDirectional, and other *Directional objects.
        """)
    #endif
    return true
}

// MARK: - ImageSizeInfo

/// Tracks the bytes used by a `dart:ui.Image` compared to the bytes needed to
/// paint that image without scaling it.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/debug.dart`
/// **Original Name:** `ImageSizeInfo`
/// **Lines:** 68-126
public struct ImageSizeInfo: Hashable, Sendable {

    /// A unique identifier for this image, for example its asset path or network
    /// URL.
    ///
    /// **Dart Source:** `debug.dart:79`
    public let source: String?

    /// The size of the area the image will be rendered in.
    ///
    /// **Dart Source:** `debug.dart:82`
    public let displaySize: Size

    /// The size the image has been decoded to.
    ///
    /// **Dart Source:** `debug.dart:85`
    public let imageSize: Size

    /// Creates an object to track the backing size of a `dart:ui.Image` compared
    /// to its display size on a `Canvas`.
    ///
    /// **Dart Source:** `debug.dart:75`
    public init(source: String? = nil, displaySize: Size, imageSize: Size) {
        self.source = source
        self.displaySize = displaySize
        self.imageSize = imageSize
    }

    /// The number of bytes needed to render the image without scaling it.
    ///
    /// **Dart Source:** `debug.dart:88`
    public var displaySizeInBytes: Int {
        return _sizeToBytes(displaySize)
    }

    /// The number of bytes used by the image in memory.
    ///
    /// **Dart Source:** `debug.dart:91`
    public var decodedSizeInBytes: Int {
        return _sizeToBytes(imageSize)
    }

    /// Converts a size to an approximate byte count.
    ///
    /// Assumes 4 bytes per pixel and that mipmapping will be used, which adds 4/3.
    ///
    /// **Dart Source:** `debug.dart:93-97`
    private func _sizeToBytes(_ size: Size) -> Int {
        return Int(size.width * size.height * 4.0 * (4.0 / 3.0))
    }

    /// Returns a JSON-encodable representation of this object.
    ///
    /// **Dart Source:** `debug.dart:100-108`
    public func toJson() -> [String: Any?] {
        return [
            "source": source,
            "displaySize": ["width": displaySize.width, "height": displaySize.height],
            "imageSize": ["width": imageSize.width, "height": imageSize.height],
            "displaySizeInBytes": displaySizeInBytes,
            "decodedSizeInBytes": decodedSizeInBytes,
        ]
    }
}

// MARK: - PaintImageCallback

/// Signature for the callback used by `debugOnPaintImage`.
///
/// Called when the framework is about to paint an `Image` to a `Canvas`
/// with an `ImageSizeInfo` that contains the decoded size of the image as
/// well as its output size.
///
/// **Dart Source:** `debug.dart:63`
/// **Original Name:** `PaintImageCallback`
public typealias PaintImageCallback = (ImageSizeInfo) -> Void

// MARK: - debugOnPaintImage

/// If not nil, called when the framework is about to paint an `Image` to a
/// `Canvas` with an `ImageSizeInfo` that contains the decoded size of the
/// image as well as its output size.
///
/// A test can use this callback to detect if images under test are being
/// rendered with the appropriate cache dimensions.
///
/// **Dart Source:** `debug.dart:128-150`
/// **Original Name:** `debugOnPaintImage`
nonisolated(unsafe) public var debugOnPaintImage: PaintImageCallback? = nil

// MARK: - debugInvertOversizedImages

/// If true, the framework will color invert and horizontally flip images that
/// have been decoded to a size taking at least `debugImageOverheadAllowance`
/// bytes more than necessary.
///
/// **Dart Source:** `debug.dart:152-172`
/// **Original Name:** `debugInvertOversizedImages`
nonisolated(unsafe) public var debugInvertOversizedImages: Bool = false

// MARK: - debugImageOverheadAllowance

/// The number of bytes an image must use before it triggers inversion when
/// `debugInvertOversizedImages` is true.
///
/// Default is 1024 (1 KB).
///
/// **Dart Source:** `debug.dart:174-193`
/// **Original Name:** `debugImageOverheadAllowance`
nonisolated(unsafe) public var debugImageOverheadAllowance: Int = 1024
