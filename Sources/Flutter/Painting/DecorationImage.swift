// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Decoration image utilities.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`

import FlutterSwiftBridge

// MARK: - ImageRepeat

/// How to paint any portions of a box not covered by an image.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `ImageRepeat`
/// **Lines:** 29-41
public enum ImageRepeat: Sendable {
    /// Repeat the image in both the x and y directions until the box is filled.
    ///
    /// **Dart Source:** `decoration_image.dart:31`
    case `repeat`

    /// Repeat the image in the x direction until the box is filled horizontally.
    ///
    /// **Dart Source:** `decoration_image.dart:34`
    case repeatX

    /// Repeat the image in the y direction until the box is filled vertically.
    ///
    /// **Dart Source:** `decoration_image.dart:37`
    case repeatY

    /// Leave uncovered portions of the box transparent.
    ///
    /// **Dart Source:** `decoration_image.dart:40`
    case noRepeat
}

// MARK: - DecorationImagePainter

/// The painter for a `DecorationImage`.
///
/// To obtain a painter, call `DecorationImage.createPainter`.
///
/// To paint, call `paint`. The `onChanged` callback passed to
/// `DecorationImage.createPainter` will be called if the image needs to paint
/// again (e.g. because it is animated or because it had not yet loaded the
/// first time the `paint` method was called).
///
/// This object should be disposed using the `dispose` method when it is no
/// longer needed.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `DecorationImagePainter`
/// **Lines:** 270-318
public protocol DecorationImagePainter: AnyObject {
    /// Draw the image onto the given canvas.
    ///
    /// The image is drawn at the position and size given by the `rect` argument.
    ///
    /// The image is clipped to the given `clipPath`, if any.
    ///
    /// The `configuration` object is used to resolve the image (e.g. to pick
    /// resolution-specific assets), and to implement the
    /// `DecorationImage.matchTextDirection` feature.
    ///
    /// **Dart Source:** `decoration_image.dart:282-310`
    func paint(
        _ canvas: Canvas,
        rect: Rect,
        clipPath: Path?,
        configuration: ImageConfiguration,
        blend: Double,
        blendMode: BlendMode
    )

    /// Releases the resources used by this painter.
    ///
    /// This should be called whenever the painter is no longer needed.
    ///
    /// After this method has been called, the object is no longer usable.
    ///
    /// **Dart Source:** `decoration_image.dart:317`
    func dispose()
}

// MARK: - DecorationImage

/// An image for a box decoration.
///
/// The image is painted using `paintImage`, which describes the meanings of the
/// various fields on this class in more detail.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `DecorationImage`
/// **Lines:** 48-268
public struct DecorationImage: Hashable, CustomStringConvertible {

    // MARK: - Properties

    /// The image to be painted into the decoration.
    ///
    /// Typically this will be an `AssetImage` (for an image shipped with the
    /// application) or a `NetworkImage` (for an image obtained from the network).
    ///
    /// **Dart Source:** `decoration_image.dart:70`
    public let image: AnyImageProvider

    /// An optional error callback for errors emitted when loading `image`.
    ///
    /// **Dart Source:** `decoration_image.dart:73`
    public let onError: ImageErrorListener?

    /// A color filter to apply to the image before painting it.
    ///
    /// **Dart Source:** `decoration_image.dart:76`
    public let colorFilter: ColorFilter?

    /// How the image should be inscribed into the box.
    ///
    /// The default is `BoxFit.scaleDown` if `centerSlice` is nil, and
    /// `BoxFit.fill` if `centerSlice` is not nil.
    ///
    /// See the discussion at `paintImage` for more details.
    ///
    /// **Dart Source:** `decoration_image.dart:84`
    public let fit: BoxFit?

    /// How to align the image within its bounds.
    ///
    /// The alignment aligns the given position in the image to the given position
    /// in the layout bounds. For example, an `Alignment` alignment of (-1.0,
    /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
    /// `Alignment` alignment of (1.0, 1.0) aligns the bottom right of the
    /// image with the bottom right corner of its layout bounds. Similarly, an
    /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
    /// middle of the bottom edge of its layout bounds.
    ///
    /// To display a subpart of an image, consider using a `CustomPainter` and
    /// `Canvas.drawImageRect`.
    ///
    /// If the `alignment` is `TextDirection`-dependent (i.e. if it is a
    /// `AlignmentDirectional`), then a `TextDirection` must be available
    /// when the image is painted.
    ///
    /// Defaults to `Alignment.center`.
    ///
    /// **Dart Source:** `decoration_image.dart:111`
    public let alignment: any AlignmentGeometry

    /// The center slice for a nine-patch image.
    ///
    /// The region of the image inside the center slice will be stretched both
    /// horizontally and vertically to fit the image into its destination. The
    /// region of the image above and below the center slice will be stretched
    /// only horizontally and the region of the image to the left and right of
    /// the center slice will be stretched only vertically.
    ///
    /// The stretching will be applied in order to make the image fit into the box
    /// specified by `fit`. When `centerSlice` is not nil, `fit` defaults to
    /// `BoxFit.fill`, which distorts the destination image size relative to the
    /// image's original aspect ratio. Values of `BoxFit` which do not distort the
    /// destination image size will result in `centerSlice` having no effect
    /// (since the nine regions of the image will be rendered with the same
    /// scaling, as if it wasn't specified).
    ///
    /// **Dart Source:** `decoration_image.dart:128`
    public let centerSlice: Rect?

    /// How to paint any portions of the box that would not otherwise be covered
    /// by the image.
    ///
    /// **Dart Source:** `decoration_image.dart:132`
    public let `repeat`: ImageRepeat

    /// Whether to paint the image in the direction of the `TextDirection`.
    ///
    /// If this is true, then in `TextDirection.ltr` contexts, the image will be
    /// drawn with its origin in the top left (the "normal" painting direction for
    /// images); and in `TextDirection.rtl` contexts, the image will be drawn with
    /// a scaling factor of -1 in the horizontal direction so that the origin is
    /// in the top right.
    ///
    /// **Dart Source:** `decoration_image.dart:141`
    public let matchTextDirection: Bool

    /// Defines image pixels to be shown per logical pixels.
    ///
    /// By default the value of scale is 1.0. The scale for the image is
    /// calculated by multiplying `scale` with `scale` of the given `ImageProvider`.
    ///
    /// **Dart Source:** `decoration_image.dart:147`
    public let scale: Double

    /// If non-null, the value is multiplied with the opacity of each image
    /// pixel before painting onto the canvas.
    ///
    /// This is more efficient than using `Opacity` or `FadeTransition` to
    /// change the opacity of an image.
    ///
    /// **Dart Source:** `decoration_image.dart:154`
    public let opacity: Double

    /// Used to set the filterQuality of the image.
    ///
    /// Defaults to `FilterQuality.medium`.
    ///
    /// **Dart Source:** `decoration_image.dart:159`
    public let filterQuality: FilterQuality

    /// Whether the colors of the image are inverted when drawn.
    ///
    /// Inverting the colors of an image applies a new color filter to the paint.
    /// If there is another specified color filter, the invert will be applied
    /// after it. This is primarily used for implementing smart invert on iOS.
    ///
    /// **Dart Source:** `decoration_image.dart:170`
    public let invertColors: Bool

    /// Whether to paint the image with anti-aliasing.
    ///
    /// Anti-aliasing alleviates the sawtooth artifact when the image is rotated.
    ///
    /// **Dart Source:** `decoration_image.dart:175`
    public let isAntiAlias: Bool

    /// When non-nil, holds the `_BlendedDecorationImage` that created this
    /// struct so that `createPainter` can return a `_BlendedDecorationImagePainter`
    /// instead of a regular `DecorationImagePainterImpl`.
    ///
    /// This is an internal implementation detail used by `DecorationImage.lerp`.
    internal let _blendedSource: _BlendedDecorationImage?

    // MARK: - Initializer

    /// Creates an image to show in a `BoxDecoration`.
    ///
    /// **Dart Source:** `decoration_image.dart:50-64`
    public init(
        image: AnyImageProvider,
        onError: ImageErrorListener? = nil,
        colorFilter: ColorFilter? = nil,
        fit: BoxFit? = nil,
        alignment: any AlignmentGeometry = Alignment.center,
        centerSlice: Rect? = nil,
        repeat: ImageRepeat = .noRepeat,
        matchTextDirection: Bool = false,
        scale: Double = 1.0,
        opacity: Double = 1.0,
        filterQuality: FilterQuality = .medium,
        invertColors: Bool = false,
        isAntiAlias: Bool = false
    ) {
        self.image = image
        self.onError = onError
        self.colorFilter = colorFilter
        self.fit = fit
        self.alignment = alignment
        self.centerSlice = centerSlice
        self.repeat = `repeat`
        self.matchTextDirection = matchTextDirection
        self.scale = scale
        self.opacity = opacity
        self.filterQuality = filterQuality
        self.invertColors = invertColors
        self.isAntiAlias = isAntiAlias
        self._blendedSource = nil
    }

    /// Internal initializer used by `_BlendedDecorationImage` to create a
    /// `DecorationImage` that retains a reference to the blended source for
    /// proper blended painter creation.
    internal init(
        image: AnyImageProvider,
        onError: ImageErrorListener? = nil,
        colorFilter: ColorFilter? = nil,
        fit: BoxFit? = nil,
        alignment: any AlignmentGeometry = Alignment.center,
        centerSlice: Rect? = nil,
        repeat: ImageRepeat = .noRepeat,
        matchTextDirection: Bool = false,
        scale: Double = 1.0,
        opacity: Double = 1.0,
        filterQuality: FilterQuality = .medium,
        invertColors: Bool = false,
        isAntiAlias: Bool = false,
        blendedSource: _BlendedDecorationImage
    ) {
        self.image = image
        self.onError = onError
        self.colorFilter = colorFilter
        self.fit = fit
        self.alignment = alignment
        self.centerSlice = centerSlice
        self.repeat = `repeat`
        self.matchTextDirection = matchTextDirection
        self.scale = scale
        self.opacity = opacity
        self.filterQuality = filterQuality
        self.invertColors = invertColors
        self.isAntiAlias = isAntiAlias
        self._blendedSource = blendedSource
    }

    // MARK: - Painter Creation

    /// Creates a `DecorationImagePainter` for this `DecorationImage`.
    ///
    /// The `onChanged` argument will be called whenever the image needs to be
    /// repainted, e.g. because it is loading incrementally or because it is
    /// animated.
    ///
    /// If this `DecorationImage` was created by `lerp`, the painter returned
    /// will be a `_BlendedDecorationImagePainter` that paints both the source
    /// and target images with interpolated opacity.
    ///
    /// **Dart Source:** `decoration_image.dart:182-184`
    public func createPainter(_ onChanged: @escaping VoidCallback) -> any DecorationImagePainter {
        if let blendedSource = _blendedSource {
            return blendedSource.createPainter(onChanged)
        }
        return DecorationImagePainterImpl(self, onChanged)
    }

    // MARK: - Equatable

    /// Compares two `DecorationImage` instances for equality.
    ///
    /// Note: The `onError` callback is not compared for equality because
    /// function/closure types are not `Equatable` in Swift.
    ///
    /// **Dart Source:** `decoration_image.dart:187-207`
    public static func == (lhs: DecorationImage, rhs: DecorationImage) -> Bool {
        let alignmentEqual: Bool
        if let lhsA = lhs.alignment as? Alignment, let rhsA = rhs.alignment as? Alignment {
            alignmentEqual = lhsA == rhsA
        } else if let lhsA = lhs.alignment as? AlignmentDirectional,
                  let rhsA = rhs.alignment as? AlignmentDirectional {
            alignmentEqual = lhsA == rhsA
        } else {
            alignmentEqual = false
        }
        return lhs.image == rhs.image &&
            lhs.colorFilter == rhs.colorFilter &&
            lhs.fit == rhs.fit &&
            alignmentEqual &&
            lhs.centerSlice == rhs.centerSlice &&
            lhs.repeat == rhs.repeat &&
            lhs.matchTextDirection == rhs.matchTextDirection &&
            lhs.scale == rhs.scale &&
            lhs.opacity == rhs.opacity &&
            lhs.filterQuality == rhs.filterQuality &&
            lhs.invertColors == rhs.invertColors &&
            lhs.isAntiAlias == rhs.isAntiAlias
    }

    // MARK: - Hashable

    /// The hash code for this decoration image.
    ///
    /// **Dart Source:** `decoration_image.dart:210-223`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(image)
        hasher.combine(colorFilter)
        hasher.combine(fit)
        hasher.combine(alignment)
        hasher.combine(centerSlice)
        hasher.combine(`repeat`)
        hasher.combine(matchTextDirection)
        hasher.combine(scale)
        hasher.combine(opacity)
        hasher.combine(filterQuality)
        hasher.combine(invertColors)
        hasher.combine(isAntiAlias)
    }

    // MARK: - CustomStringConvertible

    /// A brief textual description of this decoration image.
    ///
    /// **Dart Source:** `decoration_image.dart:226-245`
    public var description: String {
        var properties: [String] = []
        properties.append("\(image)")
        if let colorFilter = colorFilter {
            properties.append("\(colorFilter)")
        }
        if let fit = fit {
            let isDefaultFill = fit == .fill && centerSlice != nil
            let isDefaultScaleDown = fit == .scaleDown && centerSlice == nil
            if !isDefaultFill && !isDefaultScaleDown {
                properties.append("\(fit)")
            }
        }
        properties.append("\(alignment)")
        if let centerSlice = centerSlice {
            properties.append("centerSlice: \(centerSlice)")
        }
        if `repeat` != .noRepeat {
            properties.append("\(`repeat`)")
        }
        if matchTextDirection {
            properties.append("match text direction")
        }
        properties.append("scale \(String(format: "%.1f", scale))")
        properties.append("opacity \(String(format: "%.1f", opacity))")
        properties.append("\(filterQuality)")
        if invertColors {
            properties.append("invert colors")
        }
        if isAntiAlias {
            properties.append("use anti-aliasing")
        }
        return "\(objectRuntimeType(self, "DecorationImage"))(\(properties.joined(separator: ", ")))"
    }

    // MARK: - Lerp

    /// Linearly interpolates between two `DecorationImage`s.
    ///
    /// The `t` argument represents position on the timeline, with 0.0 meaning
    /// that the interpolation has not started, returning `a`, 1.0 meaning that
    /// the interpolation has finished, returning `b`, and values in between
    /// meaning that the interpolation is at the relevant point on the timeline
    /// between `a` and `b`. The interpolation can be extrapolated beyond 0.0
    /// and 1.0, so negative values and values greater than 1.0 are valid (and can
    /// easily be generated by curves such as `Curves.elasticInOut`).
    ///
    /// Values for `t` are usually obtained from an `Animation<Double>`, such as
    /// an `AnimationController`.
    ///
    /// **Dart Source:** `decoration_image.dart:259-267`
    public static func lerp(_ a: DecorationImage?, _ b: DecorationImage?, _ t: Double) -> DecorationImage? {
        if a == b || t == 0.0 {
            return a
        }
        if t == 1.0 {
            return b
        }
        return _BlendedDecorationImage(a, b, t).asDecorationImage
    }
}

// MARK: - DecorationImagePainterImpl

/// Concrete implementation of `DecorationImagePainter`.
///
/// Handles resolving the image from the `DecorationImage`'s image provider,
/// tracking the image stream and current image, and delegating actual painting
/// to the `paintImage()` function.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_DecorationImagePainter`
/// **Lines:** 320-443
internal class DecorationImagePainterImpl: DecorationImagePainter {

    /// The decoration image configuration (image provider, fit, alignment, etc.).
    ///
    /// **Dart Source:** `decoration_image.dart:325`
    private let _details: DecorationImage

    /// Callback invoked when the image changes asynchronously and needs repaint.
    ///
    /// **Dart Source:** `decoration_image.dart:326`
    private let _onChanged: VoidCallback

    /// The current image stream being listened to.
    ///
    /// **Dart Source:** `decoration_image.dart:328`
    private var _imageStream: ImageStream?

    /// The currently loaded image, if any.
    ///
    /// **Dart Source:** `decoration_image.dart:329`
    private var _image: ImageInfo?

    /// Creates a `DecorationImagePainterImpl` with the given decoration details
    /// and repaint callback.
    ///
    /// **Dart Source:** `decoration_image.dart:321-323`
    init(_ details: DecorationImage, _ onChanged: @escaping VoidCallback) {
        self._details = details
        self._onChanged = onChanged
    }

    /// Paints the decoration image onto the given canvas.
    ///
    /// Resolves the image from the provider using the given configuration,
    /// sets up or updates the image stream listener, and delegates to
    /// `paintImage()` once the image is available.
    ///
    /// **Dart Source:** `decoration_image.dart:332-414`
    func paint(
        _ canvas: Canvas,
        rect: Rect,
        clipPath: Path?,
        configuration: ImageConfiguration,
        blend: Double = 1.0,
        blendMode: BlendMode = .srcOver
    ) {
        var flipHorizontally = false
        if _details.matchTextDirection {
            assert(
                configuration.textDirection != nil,
                "DecorationImage.matchTextDirection can only be used when a TextDirection is available."
            )
            if configuration.textDirection == .rtl {
                flipHorizontally = true
            }
        }

        let newImageStream = _details.image.resolve(configuration)
        if newImageStream.key !== _imageStream?.key {
            let listener = ImageStreamListener(
                _handleImage,
                onError: _details.onError
            )
            _imageStream?.removeListener(listener)
            _imageStream = newImageStream
            _imageStream!.addListener(listener)
        }
        if _image == nil {
            return
        }

        if clipPath != nil {
            canvas.save()
            canvas.clipPath(clipPath!)
        }

        paintImage(
            canvas: canvas,
            rect: rect,
            image: _image!.image,
            debugImageLabel: _image!.debugLabel,
            scale: _details.scale * _image!.scale,
            colorFilter: _details.colorFilter,
            fit: _details.fit,
            alignment: _details.alignment.resolve(configuration.textDirection),
            centerSlice: _details.centerSlice,
            repeat: _details.repeat,
            flipHorizontally: flipHorizontally,
            opacity: _details.opacity * blend,
            filterQuality: _details.filterQuality,
            invertColors: _details.invertColors,
            isAntiAlias: _details.isAntiAlias,
            blendMode: blendMode
        )

        if clipPath != nil {
            canvas.restore()
        }
    }

    /// Handles a new image from the image stream.
    ///
    /// If the new image is identical to the current one, it is ignored.
    /// If it is a clone of the current image, the new value is disposed to avoid
    /// unnecessary memory usage. Otherwise the old image is disposed and replaced,
    /// and if the call was asynchronous, the `onChanged` callback is invoked.
    ///
    /// **Dart Source:** `decoration_image.dart:416-429`
    private func _handleImage(_ value: ImageInfo, _ synchronousCall: Bool) {
        if _image === value {
            return
        }
        if _image != nil && _image!.isCloneOf(value) {
            value.dispose()
            return
        }
        _image?.dispose()
        _image = value
        if !synchronousCall {
            _onChanged()
        }
    }

    /// Releases resources used by this painter.
    ///
    /// Removes the listener from the current image stream and disposes
    /// the current image. After calling this method, the painter is no
    /// longer usable.
    ///
    /// **Dart Source:** `decoration_image.dart:432-437`
    func dispose() {
        _imageStream?.removeListener(
            ImageStreamListener(_handleImage, onError: _details.onError)
        )
        _image?.dispose()
        _image = nil
    }

    /// A textual representation of this painter for debugging.
    ///
    /// **Dart Source:** `decoration_image.dart:439-442`
    var description: String {
        return "\(objectRuntimeType(self, "DecorationImagePainter"))(stream: \(String(describing: _imageStream)), image: \(String(describing: _image))) for \(_details)"
    }
}

// MARK: - Debug Image Size Tracking

/// Used by `paintImage` to report image sizes drawn at the end of the frame.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_pendingImageSizeInfo`
/// **Lines:** 446
nonisolated(unsafe) private var _pendingImageSizeInfo: [String: ImageSizeInfo] = [:]

/// `ImageSizeInfo`s that were reported on the last frame.
///
/// Used to prevent duplicative reports from frame to frame.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_lastFrameImageSizeInfo`
/// **Lines:** 448-451
nonisolated(unsafe) private var _lastFrameImageSizeInfo: Set<ImageSizeInfo> = []

/// Flushes inter-frame tracking of image size information from `paintImage`.
///
/// Has no effect if asserts are disabled.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `debugFlushLastFrameImageSizeInfo`
/// **Lines:** 457-462
public func debugFlushLastFrameImageSizeInfo() {
    #if DEBUG
    _lastFrameImageSizeInfo = []
    #endif
}

// MARK: - paintImage

/// Paints an image into the given rectangle on the canvas.
///
/// The arguments have the following meanings:
///
///  * `canvas`: The canvas onto which the image will be painted.
///
///  * `rect`: The region of the canvas into which the image will be painted.
///    The image might not fill the entire rectangle (e.g., depending on the
///    `fit`). If `rect` is empty, nothing is painted.
///
///  * `image`: The image to paint onto the canvas.
///
///  * `scale`: The number of image pixels for each logical pixel.
///
///  * `opacity`: The opacity to paint the image onto the canvas with.
///
///  * `colorFilter`: If non-nil, the color filter to apply when painting the
///    image.
///
///  * `fit`: How the image should be inscribed into `rect`. If nil, the
///    default behavior depends on `centerSlice`. If `centerSlice` is also nil,
///    the default behavior is `BoxFit.scaleDown`. If `centerSlice` is
///    non-nil, the default behavior is `BoxFit.fill`. See `BoxFit` for
///    details.
///
///  * `alignment`: How the destination rectangle defined by applying `fit` is
///    aligned within `rect`. For example, if `fit` is `BoxFit.contain` and
///    `alignment` is `Alignment.bottomRight`, the image will be as large
///    as possible within `rect` and placed with its bottom right corner at the
///    bottom right corner of `rect`. Defaults to `Alignment.center`.
///
///  * `centerSlice`: The image is drawn in nine portions described by splitting
///    the image by drawing two horizontal lines and two vertical lines, where
///    `centerSlice` describes the rectangle formed by the four points where
///    these four lines intersect each other. (This forms a 3-by-3 grid
///    of regions, the center region being described by `centerSlice`.)
///    The four regions in the corners are drawn, without scaling, in the four
///    corners of the destination rectangle defined by applying `fit`. The
///    remaining five regions are drawn by stretching them to fit such that they
///    exactly cover the destination rectangle while maintaining their relative
///    positions. See also `Canvas.drawImageNine`.
///
///  * `repeat`: If the image does not fill `rect`, whether and how the image
///    should be repeated to fill `rect`. By default, the image is not repeated.
///    See `ImageRepeat` for details.
///
///  * `flipHorizontally`: Whether to flip the image horizontally. This is
///    occasionally used with images in right-to-left environments, for images
///    that were designed for left-to-right locales (or vice versa). Be careful,
///    when using this, to not flip images with integral shadows, text, or other
///    effects that will look incorrect when flipped.
///
///  * `invertColors`: Inverting the colors of an image applies a new color
///    filter to the paint. If there is another specified color filter, the
///    invert will be applied after it. This is primarily used for implementing
///    smart invert on iOS.
///
///  * `filterQuality`: Use this to change the quality when scaling an image.
///     Defaults to `FilterQuality.medium`.
///
/// See also:
///
///  * `paintBorder`, which paints a border around a rectangle on a canvas.
///  * `DecorationImage`, which holds a configuration for calling this function.
///  * `BoxDecoration`, which uses this function to paint a `DecorationImage`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `paintImage`
/// **Lines:** 529-756
public func paintImage(
    canvas: Canvas,
    rect: Rect,
    image: Image,
    debugImageLabel: String? = nil,
    scale: Double = 1.0,
    colorFilter: ColorFilter? = nil,
    fit: BoxFit? = nil,
    alignment: Alignment = .center,
    centerSlice: Rect? = nil,
    repeat imageRepeat: ImageRepeat = .noRepeat,
    flipHorizontally: Bool = false,
    opacity: Double = 1.0,
    filterQuality: FilterQuality = .medium,
    invertColors: Bool = false,
    isAntiAlias: Bool = false,
    blendMode: BlendMode = .srcOver
) {
    // Dart source line 553: if (rect.isEmpty) return;
    if rect.isEmpty {
        return
    }

    // Dart source lines 556-563: Calculate output/input sizes, handle centerSlice border
    var outputSize = rect.size
    var inputSize = Size(Double(image.width), Double(image.height))
    var sliceBorder: Offset?
    if let centerSlice = centerSlice {
        // Dart: sliceBorder = inputSize / scale - centerSlice.size as Offset;
        sliceBorder = inputSize / scale - centerSlice.size
        // Dart: outputSize = outputSize - sliceBorder as Size;
        outputSize = outputSize - sliceBorder!
        // Dart: inputSize = inputSize - sliceBorder * scale as Size;
        inputSize = inputSize - sliceBorder! * scale
    }

    // Dart source line 564: fit ??= centerSlice == null ? BoxFit.scaleDown : BoxFit.fill;
    let resolvedFit = fit ?? (centerSlice == nil ? BoxFit.scaleDown : BoxFit.fill)
    assert(
        centerSlice == nil || (resolvedFit != .none && resolvedFit != .cover),
        "centerSlice was used with a BoxFit (\(resolvedFit)) that is not supported."
    )

    // Dart source lines 566-578: Apply box fit and adjust sizes
    let fittedSizes = applyBoxFit(resolvedFit, inputSize / scale, outputSize)
    let sourceSize = fittedSizes.source * scale
    var destinationSize = fittedSizes.destination
    if centerSlice != nil {
        // Dart: outputSize += sliceBorder!;
        outputSize = outputSize + sliceBorder!
        // Dart: destinationSize += sliceBorder;
        destinationSize = destinationSize + sliceBorder!
        assert(
            sourceSize == inputSize,
            "centerSlice was used with a BoxFit that does not guarantee that the image is fully visible."
        )
    }

    // Dart source lines 580-584: Optimize away repeat if image fills output exactly
    var imageRepeat = imageRepeat
    if imageRepeat != .noRepeat && destinationSize == outputSize {
        imageRepeat = .noRepeat
    }

    // Dart source lines 585-592: Configure the paint object
    let paint = Paint()
    paint.isAntiAlias = isAntiAlias
    if let colorFilter = colorFilter {
        paint.colorFilter = colorFilter
    }
    // Dart: paint.color = Color.fromRGBO(0, 0, 0, clampDouble(opacity, 0.0, 1.0));
    paint.color = Color(rgbo: 0, 0, 0, clampDouble(opacity, 0.0, 1.0))
    paint.filterQuality = filterQuality
    paint.invertColors = invertColors
    paint.blendMode = blendMode

    // Dart source lines 593-599: Calculate destination position and rect
    let halfWidthDelta = (outputSize.width - destinationSize.width) / 2.0
    let halfHeightDelta = (outputSize.height - destinationSize.height) / 2.0
    let dx = halfWidthDelta
        + (flipHorizontally ? -alignment.x : alignment.x) * halfWidthDelta
    let dy = halfHeightDelta + alignment.y * halfHeightDelta
    let destinationPosition = rect.topLeft.translate(dx, dy)
    let destinationRect = destinationPosition & destinationSize

    // Dart source line 602: Set to true if we added a saveLayer to invert/flip the image.
    var invertedCanvas = false

    // Dart source lines 610-705: Debug/profile mode features
    // Implement cacheWidth/cacheHeight warning, debugInvertOversizedImages,
    // debugOnPaintImage, and Flutter.ImageSizesForFrame events.
    if !kReleaseMode {
        // We can use the devicePixelRatio of the views directly here (instead of
        // going through a MediaQuery) because if it changes, whatever is aware of
        // the MediaQuery will be repainting the image anyways.
        // Furthermore, for the memory check below we just assume that all images
        // are decoded for the view with the highest device pixel ratio and use that
        // as an upper bound for the display size of the image.
        // Dart: PaintingBinding.instance.platformDispatcher.views.fold(...)
        // We use PlatformDispatcher.instance directly, which is equivalent.
        let maxDevicePixelRatio = PlatformDispatcher.instance.views.reduce(
            0.0
        ) { previousValue, view in
            Swift.max(previousValue, view.devicePixelRatio)
        }
        let sizeInfo = ImageSizeInfo(
            // Some ImageProvider implementations may not have given this.
            source: debugImageLabel
                ?? "<Unknown Image(\(image.width)\u{00D7}\(image.height))>",
            displaySize: outputSize * maxDevicePixelRatio,
            imageSize: Size(Double(image.width), Double(image.height))
        )
        #if DEBUG
        if debugInvertOversizedImages
            && sizeInfo.decodedSizeInBytes
                > sizeInfo.displaySizeInBytes + debugImageOverheadAllowance
        {
            let overheadInKilobytes =
                (sizeInfo.decodedSizeInBytes - sizeInfo.displaySizeInBytes) / 1024
            let outputWidth = Int(sizeInfo.displaySize.width)
            let outputHeight = Int(sizeInfo.displaySize.height)
            // Dart: FlutterError.reportError(...)
            print(
                "Image \(debugImageLabel ?? "<unknown>") has a display size of "
                    + "\(outputWidth)\u{00D7}\(outputHeight) but a decode size of "
                    + "\(image.width)\u{00D7}\(image.height), which uses an additional "
                    + "\(overheadInKilobytes)KB (assuming a device pixel ratio of "
                    + "\(maxDevicePixelRatio)).\n\n"
                    + "Consider resizing the asset ahead of time, supplying a cacheWidth "
                    + "parameter of \(outputWidth), a cacheHeight parameter of "
                    + "\(outputHeight), or using a ResizeImage."
            )
            // Invert the colors of the canvas.
            let invertPaint = Paint()
            invertPaint.colorFilter = ColorFilter(matrix: [
                -1, 0, 0, 0, 255,
                0, -1, 0, 0, 255,
                0, 0, -1, 0, 255,
                0, 0, 0, 1, 0,
            ])
            canvas.saveLayer(destinationRect, invertPaint)
            // Flip the canvas vertically.
            let debugDy = -(rect.top + rect.height / 2.0)
            canvas.translate(0.0, -debugDy)
            canvas.scale(1.0, -1.0)
            canvas.translate(0.0, debugDy)
            invertedCanvas = true
        }
        #endif
        // Avoid emitting events that are the same as those emitted in the last frame.
        if !_lastFrameImageSizeInfo.contains(sizeInfo) {
            let existingSizeInfo = _pendingImageSizeInfo[sizeInfo.source!]
            if existingSizeInfo == nil
                || existingSizeInfo!.displaySizeInBytes < sizeInfo.displaySizeInBytes
            {
                _pendingImageSizeInfo[sizeInfo.source!] = sizeInfo
            }
            debugOnPaintImage?(sizeInfo)
            // NOTE: SchedulerBinding.instance.addPostFrameCallback is not yet available
            // in this Swift migration. The post-frame callback that flushes
            // _pendingImageSizeInfo into _lastFrameImageSizeInfo and posts
            // 'Flutter.ImageSizesForFrame' developer events is omitted until
            // SchedulerBinding is migrated. The debug tracking dictionaries are
            // still maintained for debugOnPaintImage and test use.
        }
    }

    // Dart source lines 707-718: Save canvas state if needed and apply transforms
    let needSave =
        centerSlice != nil || imageRepeat != .noRepeat || flipHorizontally
    if needSave {
        canvas.save()
    }
    if imageRepeat != .noRepeat {
        canvas.clipRect(rect)
    }
    if flipHorizontally {
        let flipDx = -(rect.left + rect.width / 2.0)
        canvas.translate(-flipDx, 0.0)
        canvas.scale(-1.0, 1.0)
        canvas.translate(flipDx, 0.0)
    }

    // Dart source lines 720-748: Draw the image
    if centerSlice == nil {
        // Dart: final Rect sourceRect = alignment.inscribe(sourceSize, Offset.zero & inputSize);
        let sourceRect = alignment.inscribe(sourceSize, Offset.zero & inputSize)
        if imageRepeat == .noRepeat {
            canvas.drawImageRect(image, sourceRect, destinationRect, paint)
        } else {
            for tileRect in _generateImageTileRects(
                outputRect: rect, fundamentalRect: destinationRect, repeat: imageRepeat
            ) {
                canvas.drawImageRect(image, sourceRect, tileRect, paint)
            }
        }
    } else {
        canvas.scale(1.0 / scale, nil)
        if imageRepeat == .noRepeat {
            canvas.drawImageNine(
                image,
                _scaleRect(centerSlice!, scale: scale),
                _scaleRect(destinationRect, scale: scale),
                paint
            )
        } else {
            for tileRect in _generateImageTileRects(
                outputRect: rect, fundamentalRect: destinationRect, repeat: imageRepeat
            ) {
                canvas.drawImageNine(
                    image,
                    _scaleRect(centerSlice!, scale: scale),
                    _scaleRect(tileRect, scale: scale),
                    paint
                )
            }
        }
    }

    // Dart source lines 749-751: Restore canvas state
    if needSave {
        canvas.restore()
    }

    // Dart source lines 753-755: Restore inverted canvas
    if invertedCanvas {
        canvas.restore()
    }
}

// MARK: - _generateImageTileRects

/// Generates rectangles for tiling an image to fill an output region.
///
/// Given an output rectangle to fill and a fundamental rectangle representing the
/// base image position, this function computes all the tile positions needed to
/// cover the output area based on the specified repeat mode.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_generateImageTileRects`
/// **Lines:** 758-780
private func _generateImageTileRects(
    outputRect: Rect, fundamentalRect: Rect, repeat imageRepeat: ImageRepeat
) -> [Rect] {
    var startX = 0
    var startY = 0
    var stopX = 0
    var stopY = 0
    let strideX = fundamentalRect.width
    let strideY = fundamentalRect.height

    if imageRepeat == .repeat || imageRepeat == .repeatX {
        startX = Int(
            ((outputRect.left - fundamentalRect.left) / strideX).rounded(.down))
        stopX = Int(
            ((outputRect.right - fundamentalRect.right) / strideX).rounded(.up))
    }

    if imageRepeat == .repeat || imageRepeat == .repeatY {
        startY = Int(
            ((outputRect.top - fundamentalRect.top) / strideY).rounded(.down))
        stopY = Int(
            ((outputRect.bottom - fundamentalRect.bottom) / strideY).rounded(.up))
    }

    var result: [Rect] = []
    for i in startX...stopX {
        for j in startY...stopY {
            result.append(
                fundamentalRect.shift(
                    Offset(Double(i) * strideX, Double(j) * strideY)))
        }
    }
    return result
}

// MARK: - _scaleRect

/// Scales a rectangle by multiplying all its edge coordinates by the given scale factor.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_scaleRect`
/// **Lines:** 782-783
private func _scaleRect(_ rect: Rect, scale: Double) -> Rect {
    Rect.fromLTRB(
        rect.left * scale, rect.top * scale, rect.right * scale,
        rect.bottom * scale)
}

// MARK: - _BlendedDecorationImage

/// Implements `DecorationImage.lerp` when the images are different.
///
/// This class paints both decorations on top of each other, blended together.
/// The decoration properties are forwarded to the target image.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_BlendedDecorationImage`
/// **Lines:** 790-851
internal class _BlendedDecorationImage {

    let a: DecorationImage?
    let b: DecorationImage?
    let t: Double

    init(_ a: DecorationImage?, _ b: DecorationImage?, _ t: Double) {
        assert(a != nil || b != nil)
        self.a = a
        self.b = b
        self.t = t
    }

    /// Converts this blended representation into a `DecorationImage` struct
    /// by forwarding properties to the target (`b`) or fallback (`a`) image.
    ///
    /// The returned struct retains a reference to this `_BlendedDecorationImage`
    /// so that `createPainter` returns a `_BlendedDecorationImagePainter`.
    var asDecorationImage: DecorationImage {
        let target = b ?? a!
        let source = a ?? b!
        return DecorationImage(
            image: target.image,
            onError: target.onError ?? source.onError,
            colorFilter: target.colorFilter ?? source.colorFilter,
            fit: target.fit ?? source.fit,
            alignment: target.alignment,
            centerSlice: target.centerSlice ?? source.centerSlice,
            repeat: target.repeat,
            matchTextDirection: target.matchTextDirection,
            scale: target.scale,
            opacity: target.opacity,
            filterQuality: target.filterQuality,
            invertColors: target.invertColors,
            isAntiAlias: target.isAntiAlias,
            blendedSource: self
        )
    }

    /// Creates a `_BlendedDecorationImagePainter` that paints both the `a` and
    /// `b` decoration images with interpolated opacity based on `t`.
    ///
    /// **Dart Source:** `decoration_image.dart:824-831`
    func createPainter(_ onChanged: @escaping VoidCallback) -> any DecorationImagePainter {
        return _BlendedDecorationImagePainter(
            a?.createPainter(onChanged),
            b?.createPainter(onChanged),
            t
        )
    }
}

// MARK: - _BlendedDecorationImagePainter

/// A `DecorationImagePainter` that paints two images blended together.
///
/// This painter is used by `_BlendedDecorationImage.createPainter()` (which
/// is invoked by `DecorationImage.lerp`) to paint two decoration images
/// simultaneously with interpolated opacity.
///
/// The `a` image is painted with opacity `blend * (1.0 - t)` and the `b`
/// image is painted with opacity `blend * t`. When both images are present,
/// the `b` image uses `BlendMode.plus` to additively blend with `a`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration_image.dart`
/// **Original Name:** `_BlendedDecorationImagePainter`
/// **Lines:** 853-895
internal class _BlendedDecorationImagePainter: DecorationImagePainter {

    /// The painter for the first (source) decoration image, or nil.
    ///
    /// **Dart Source:** `decoration_image.dart:858`
    private let a: (any DecorationImagePainter)?

    /// The painter for the second (target) decoration image, or nil.
    ///
    /// **Dart Source:** `decoration_image.dart:859`
    private let b: (any DecorationImagePainter)?

    /// The interpolation factor, where 0.0 means fully `a` and 1.0 means fully `b`.
    ///
    /// **Dart Source:** `decoration_image.dart:860`
    private let t: Double

    /// Creates a blended decoration image painter.
    ///
    /// **Dart Source:** `decoration_image.dart:854-856`
    init(
        _ a: (any DecorationImagePainter)?,
        _ b: (any DecorationImagePainter)?,
        _ t: Double
    ) {
        self.a = a
        self.b = b
        self.t = t
    }

    /// Paints both decoration images with interpolated opacity.
    ///
    /// Uses `canvas.saveLayer`/`canvas.restore` to composite the two images.
    /// The `a` image is painted with opacity `blend * (1.0 - t)` and the `b`
    /// image is painted with opacity `blend * t`. If `a` is non-nil, the `b`
    /// image uses `BlendMode.plus` for additive blending.
    ///
    /// **Dart Source:** `decoration_image.dart:862-882`
    func paint(
        _ canvas: Canvas,
        rect: Rect,
        clipPath: Path?,
        configuration: ImageConfiguration,
        blend: Double = 1.0,
        blendMode: BlendMode = .srcOver
    ) {
        canvas.saveLayer(nil, Paint())
        a?.paint(
            canvas,
            rect: rect,
            clipPath: clipPath,
            configuration: configuration,
            blend: blend * (1.0 - t),
            blendMode: blendMode
        )
        b?.paint(
            canvas,
            rect: rect,
            clipPath: clipPath,
            configuration: configuration,
            blend: blend * t,
            blendMode: a != nil ? .plus : blendMode
        )
        canvas.restore()
    }

    /// Releases resources used by both underlying painters.
    ///
    /// **Dart Source:** `decoration_image.dart:884-889`
    func dispose() {
        a?.dispose()
        b?.dispose()
    }

    /// A textual representation of this blended painter for debugging.
    ///
    /// **Dart Source:** `decoration_image.dart:891-894`
    var description: String {
        return "\(objectRuntimeType(self, "_BlendedDecorationImagePainter"))(\(String(describing: a)), \(String(describing: b)), \(t))"
    }
}
