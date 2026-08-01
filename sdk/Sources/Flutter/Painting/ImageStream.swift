// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of image stream types for image_provider.dart dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
///
/// NOTE: This is a minimal stub to support ImageProvider migration.
/// A full implementation will be completed in a future task.

import FlutterSwiftBridge

// MARK: - Typedefs

/// Signature for callbacks reporting that an image is available.
///
/// Used in `ImageStreamListener`.
///
/// **Dart Source:** `image_stream.dart:250`
public typealias ImageListener = (ImageInfo, Bool) -> Void

/// Signature for listening to `ImageChunkEvent` events.
///
/// Used in `ImageStreamListener`.
///
/// **Dart Source:** `image_stream.dart:255`
public typealias ImageChunkListener = (ImageChunkEvent) -> Void

/// Signature for reporting errors when resolving images.
///
/// Used in `ImageStreamListener`, as well as by `ImageCache.putIfAbsent` and
/// `precacheImage`, to report errors.
///
/// **Dart Source:** `image_stream.dart:261`
public typealias ImageErrorListener = (Any, String?) -> Void

// MARK: - ImageInfo

/// A `dart:ui.Image` object with its corresponding scale.
///
/// ImageInfo objects are used by `ImageStream` objects to represent the
/// actual data of the image once it has been obtained.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 41-160
public final class ImageInfo: Equatable, Hashable {

    // MARK: - Properties

    /// The raw image pixels.
    ///
    /// **Dart Source:** `image_stream.dart:112`
    public let image: Image

    /// The linear scale factor for drawing this image at its intended size.
    ///
    /// **Dart Source:** `image_stream.dart:128`
    public let scale: Double

    /// A string used for debugging purposes to identify the source of this image.
    ///
    /// **Dart Source:** `image_stream.dart:131`
    public let debugLabel: String?

    /// The size of raw image pixels in bytes.
    ///
    /// **Dart Source:** `image_stream.dart:115`
    public var sizeBytes: Int { image.height * image.width * 4 }

    // MARK: - Initialization

    /// Creates an `ImageInfo` object for the given image and scale.
    ///
    /// **Dart Source:** `image_stream.dart:47`
    public init(image: Image, scale: Double = 1.0, debugLabel: String? = nil) {
        self.image = image
        self.scale = scale
        self.debugLabel = debugLabel
    }

    // MARK: - Methods

    /// Creates an `ImageInfo` with a cloned image.
    ///
    /// **Dart Source:** `image_stream.dart:63-65`
    public func clone() -> ImageInfo {
        return ImageInfo(image: image.clone(), scale: scale, debugLabel: debugLabel)
    }

    /// Whether this `ImageInfo` is a clone of the `other`.
    ///
    /// **Dart Source:** `image_stream.dart:103-105`
    public func isCloneOf(_ other: ImageInfo) -> Bool {
        return other.image.isCloneOf(image) && scale == other.scale && debugLabel == other.debugLabel
    }

    /// Disposes of this object.
    ///
    /// **Dart Source:** `image_stream.dart:137-141`
    public func dispose() {
        image.dispose()
    }

    // MARK: - Equatable & Hashable

    public static func == (lhs: ImageInfo, rhs: ImageInfo) -> Bool {
        return lhs.image === rhs.image && lhs.scale == rhs.scale && lhs.debugLabel == rhs.debugLabel
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(image))
        hasher.combine(scale)
        hasher.combine(debugLabel)
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        let label = debugLabel != nil ? "\(debugLabel!) " : ""
        return "\(label)\(image) @ \(scale)x"
    }
}

// MARK: - ImageStreamListener

/// Interface for receiving notifications about the loading of an image.
///
/// Used by `ImageStream` and `ImageStreamCompleter`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 173-234
public struct ImageStreamListener: Equatable {

    /// Callback for getting notified that an image is available.
    ///
    /// **Dart Source:** `image_stream.dart:191`
    public let onImage: ImageListener

    /// Callback for getting notified when a chunk of bytes has been received
    /// during the loading of the image.
    ///
    /// **Dart Source:** `image_stream.dart:204`
    public let onChunk: ImageChunkListener?

    /// Callback for getting notified when an error occurs while loading an image.
    ///
    /// **Dart Source:** `image_stream.dart:219`
    public let onError: ImageErrorListener?

    /// Creates a new `ImageStreamListener`.
    ///
    /// **Dart Source:** `image_stream.dart:175`
    public init(
        _ onImage: @escaping ImageListener,
        onChunk: ImageChunkListener? = nil,
        onError: ImageErrorListener? = nil
    ) {
        self.onImage = onImage
        self.onChunk = onChunk
        self.onError = onError
    }

    // MARK: - Equatable

    /// Stub equality - compares by identity of closures using unsafeBitCast.
    /// In practice, closure equality is limited in Swift.
    public static func == (lhs: ImageStreamListener, rhs: ImageStreamListener) -> Bool {
        // Closure comparison is not fully supported in Swift.
        // This is a stub; full implementation will use proper identity comparison.
        return false
    }
}

// MARK: - ImageChunkEvent

/// An immutable notification of image bytes that have been incrementally loaded.
///
/// Chunk events represent progress notifications while an image is being
/// loaded (e.g. from disk or over the network).
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 273-301
public struct ImageChunkEvent {

    /// The number of bytes that have been received across the wire thus far.
    ///
    /// **Dart Source:** `image_stream.dart:279`
    public let cumulativeBytesLoaded: Int

    /// The expected number of bytes that need to be received to finish loading
    /// the image.
    ///
    /// This value will be nil if the number is not known in advance.
    ///
    /// **Dart Source:** `image_stream.dart:293`
    public let expectedTotalBytes: Int?

    /// Creates a new chunk event.
    ///
    /// **Dart Source:** `image_stream.dart:275`
    public init(cumulativeBytesLoaded: Int, expectedTotalBytes: Int?) {
        assert(cumulativeBytesLoaded >= 0)
        assert(expectedTotalBytes == nil || expectedTotalBytes! >= 0)
        self.cumulativeBytesLoaded = cumulativeBytesLoaded
        self.expectedTotalBytes = expectedTotalBytes
    }
}

// MARK: - ImageStream

/// A handle to an image resource.
///
/// ImageStream represents a handle to a `dart:ui.Image` object and its scale
/// (together represented by an `ImageInfo` object). The underlying image object
/// might change over time, either because the image is animating or because the
/// underlying image resource was mutated.
///
/// ImageStream objects can also represent an image that hasn't finished
/// loading.
///
/// ImageStream objects are backed by `ImageStreamCompleter` objects.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 324-439
public class ImageStream {

    // MARK: - Properties

    /// The completer that has been assigned to this image stream.
    ///
    /// **Dart Source:** `image_stream.dart:333`
    public var completer: ImageStreamCompleter? { _completer }
    private var _completer: ImageStreamCompleter?

    /// Pending listeners before a completer is assigned.
    private var _listeners: [ImageStreamListener]?

    // MARK: - Initialization

    /// Create an initially unbound image stream.
    ///
    /// **Dart Source:** `image_stream.dart:328`
    public init() {}

    // MARK: - Methods

    /// Assigns a particular `ImageStreamCompleter` to this `ImageStream`.
    ///
    /// This method can only be called once per stream.
    ///
    /// **Dart Source:** `image_stream.dart:346-356`
    public func setCompleter(_ value: ImageStreamCompleter) {
        assert(_completer == nil)
        _completer = value
        if let initialListeners = _listeners {
            _listeners = nil
            for listener in initialListeners {
                _completer!.addListener(listener)
            }
        }
    }

    /// Adds a listener callback that is called whenever a new concrete `ImageInfo`
    /// object is available.
    ///
    /// **Dart Source:** `image_stream.dart:379-385`
    public func addListener(_ listener: ImageStreamListener) {
        if let completer = _completer {
            completer.addListener(listener)
            return
        }
        if _listeners == nil {
            _listeners = []
        }
        _listeners!.append(listener)
    }

    /// Stops listening for events from this stream's `ImageStreamCompleter`.
    ///
    /// **Dart Source:** `image_stream.dart:391-402`
    public func removeListener(_ listener: ImageStreamListener) {
        if let completer = _completer {
            completer.removeListener(listener)
            return
        }
        assert(_listeners != nil)
        if let index = _listeners!.firstIndex(of: listener) {
            _listeners!.remove(at: index)
        }
    }

    /// Returns an object which can be used with `==` to determine if this
    /// `ImageStream` shares the same listeners list as another `ImageStream`.
    ///
    /// **Dart Source:** `image_stream.dart:415`
    public var key: AnyObject { (_completer as AnyObject?) ?? (self as AnyObject) }
}

// MARK: - ImageStreamCompleterHandle

/// An opaque handle that keeps an `ImageStreamCompleter` alive even if it has
/// lost its last listener.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 450-472
public class ImageStreamCompleterHandle {

    private var _completer: ImageStreamCompleter?

    /// Internal initializer used by `ImageStreamCompleter.keepAlive()`.
    ///
    /// **Dart Source:** `image_stream.dart:451-453`
    internal init(_ completer: ImageStreamCompleter) {
        _completer = completer
        _completer!._keepAliveHandles += 1
    }

    /// Call this method to signal the `ImageStreamCompleter` that it can now be
    /// disposed when its last listener drops.
    ///
    /// **Dart Source:** `image_stream.dart:462-471`
    public func dispose() {
        assert(_completer != nil)
        assert(_completer!._keepAliveHandles > 0)
        _completer!._keepAliveHandles -= 1
        _completer!._maybeDispose()
        _completer = nil
    }
}

// MARK: - ImageStreamCompleter

/// Base class for those that manage the loading of `dart:ui.Image` objects for
/// `ImageStream`s.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 480-879
open class ImageStreamCompleter {

    // MARK: - Properties

    private var _listeners: [ImageStreamListener] = []
    private var _currentImage: ImageInfo?
    private var _currentError: FlutterErrorDetails?

    /// A string identifying the source of the underlying image.
    ///
    /// **Dart Source:** `image_stream.dart:487`
    public var debugLabel: String?

    /// Whether any listeners are currently registered.
    ///
    /// **Dart Source:** `image_stream.dart:509`
    public var hasListeners: Bool { !_listeners.isEmpty }

    /// Internal keep-alive handle count.
    internal var _keepAliveHandles: Int = 0

    private var _disposed: Bool = false

    private var _onLastListenerRemovedCallbacks: [VoidCallback] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Listener Management

    /// Adds a listener callback that is called whenever a new concrete `ImageInfo`
    /// object is available or an error is reported.
    ///
    /// **Dart Source:** `image_stream.dart:534-564`
    open func addListener(_ listener: ImageStreamListener) {
        _checkDisposed()
        _listeners.append(listener)
        if let currentImage = _currentImage {
            listener.onImage(currentImage.clone(), false)
        }
        if let currentError = _currentError, let onError = listener.onError {
            onError(currentError.exception, nil)
        }
    }

    /// Stops the specified listener from receiving image stream events.
    ///
    /// **Dart Source:** `image_stream.dart:640-656`
    open func removeListener(_ listener: ImageStreamListener) {
        _checkDisposed()
        if let index = _listeners.firstIndex(of: listener) {
            _listeners.remove(at: index)
        }
        if _listeners.isEmpty {
            let callbacks = _onLastListenerRemovedCallbacks
            _onLastListenerRemovedCallbacks.removeAll()
            for callback in callbacks {
                callback()
            }
            _maybeDispose()
        }
    }

    /// Creates an `ImageStreamCompleterHandle` that will prevent this stream from
    /// being disposed at least until the handle is disposed.
    ///
    /// **Dart Source:** `image_stream.dart:628-631`
    public func keepAlive() -> ImageStreamCompleterHandle {
        _checkDisposed()
        return ImageStreamCompleterHandle(self)
    }

    /// Adds a callback to call when `removeListener` results in an empty
    /// list of listeners.
    ///
    /// **Dart Source:** `image_stream.dart:711-714`
    public func addOnLastListenerRemovedCallback(_ callback: @escaping VoidCallback) {
        _checkDisposed()
        _onLastListenerRemovedCallbacks.append(callback)
    }

    /// Removes a callback previously supplied to
    /// `addOnLastListenerRemovedCallback`.
    ///
    /// **Dart Source:** `image_stream.dart:718-721`
    public func removeOnLastListenerRemovedCallback(_ callback: @escaping VoidCallback) {
        _checkDisposed()
        // Note: In Swift, direct closure comparison is not reliable.
        // A full implementation would use identifiable wrappers.
    }

    // MARK: - Image Management

    /// Calls all the registered listeners to notify them of a new image.
    ///
    /// **Dart Source:** `image_stream.dart:726-749`
    public func setImage(_ image: ImageInfo) {
        _checkDisposed()
        _currentImage?.dispose()
        _currentImage = image

        if _listeners.isEmpty { return }

        let localListeners = Array(_listeners)
        for listener in localListeners {
            listener.onImage(image.clone(), false)
        }
    }

    /// Calls all the registered error listeners to notify them of an error.
    ///
    /// **Dart Source:** `image_stream.dart:782-829`
    public func reportError(
        context: (any DiagnosticsNodeProtocol)? = nil,
        exception: any Error,
        stack: String? = nil,
        informationCollector: InformationCollector? = nil,
        silent: Bool = false
    ) {
        _currentError = FlutterErrorDetails(
            exception: exception,
            library: "image resource service",
            context: context,
            informationCollector: informationCollector,
            silent: silent
        )

        let errorListeners = _listeners.compactMap { $0.onError }
        var handled = false
        for errorListener in errorListeners {
            errorListener(exception, stack)
            handled = true
        }
        if !handled {
            FlutterError.reportError(_currentError!)
        }
    }

    /// Calls all the registered `ImageChunkListener`s to notify them of a new
    /// `ImageChunkEvent`.
    ///
    /// **Dart Source:** `image_stream.dart:835-847`
    public func reportImageChunkEvent(_ event: ImageChunkEvent) {
        _checkDisposed()
        if hasListeners {
            let localListeners = _listeners.compactMap { $0.onChunk }
            for listener in localListeners {
                listener(event)
            }
        }
    }

    // MARK: - Disposal

    /// Called when this `ImageStreamCompleter` has actually been disposed.
    ///
    /// **Dart Source:** `image_stream.dart:666`
    open func onDisposed() {}

    /// Disposes this `ImageStreamCompleter` unless it has listeners or keep-alive handles.
    ///
    /// **Dart Source:** `image_stream.dart:674-676`
    public func maybeDispose() {
        _maybeDispose()
    }

    internal func _maybeDispose() {
        if _disposed || !_listeners.isEmpty || _keepAliveHandles != 0 {
            return
        }
        _currentImage?.dispose()
        _currentImage = nil
        _disposed = true
        onDisposed()
    }

    private func _checkDisposed() {
        if _disposed {
            fatalError(
                "Stream has been disposed.\n"
                + "An ImageStream is considered disposed once at least one listener has "
                + "been added and subsequently all listeners have been removed and no "
                + "handles are outstanding from the keepAlive method."
            )
        }
    }
}

// MARK: - OneFrameImageStreamCompleter

/// Manages the loading of `dart:ui.Image` objects for static `ImageStream`s
/// (those with only one frame).
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 883-915
public class OneFrameImageStreamCompleter: ImageStreamCompleter {

    /// Creates a manager for one-frame `ImageStream`s.
    ///
    /// The image resource awaits the given async closure. When it resolves,
    /// it notifies the `ImageListener`s that have been registered with
    /// `addListener`.
    ///
    /// **Dart Source:** `image_stream.dart:898-914`
    public init(
        image: sending @escaping () async throws -> ImageInfo,
        informationCollector: InformationCollector? = nil
    ) {
        super.init()
        // Stub: In Dart, this uses Future.then. Full implementation to be added.
    }
}

// MARK: - MultiFrameImageStreamCompleter

/// Manages the decoding and scheduling of image frames.
///
/// New frames will only be emitted while there are registered listeners to the
/// stream (registered with `addListener`).
///
/// For single frame images the stream will only complete once.
///
/// For animated images, this class eagerly decodes the next image frame,
/// and notifies the listeners that a new frame is ready on the first app frame
/// that is scheduled after the image frame duration has passed.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_stream.dart`
/// **Lines:** 949-1132
public class MultiFrameImageStreamCompleter: ImageStreamCompleter {

    private let _scale: Double
    private let _informationCollector: InformationCollector?

    /// Creates an image stream completer.
    ///
    /// Immediately starts decoding the first image frame when the codec is ready.
    ///
    /// **Dart Source:** `image_stream.dart:968-1003`
    public init(
        codec: sending @escaping () async throws -> any Codec,
        scale: Double,
        debugLabel: String? = nil,
        chunkEvents: AsyncStream<ImageChunkEvent>? = nil,
        informationCollector: InformationCollector? = nil
    ) {
        self._scale = scale
        self._informationCollector = informationCollector
        super.init()
        self.debugLabel = debugLabel
        // Stub: In a full implementation, this would decode frames and schedule them
        // using Future.then and stream subscriptions as in the Dart source.
    }
}
