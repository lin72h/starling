// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Platform view rendering types.
///
/// Provides the base types and enums for embedding platform views within
/// the Flutter rendering tree. Includes hit test behavior, gesture handling,
/// and the base render box for platform view surfaces.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/platform_view.dart`

import FlutterSwiftBridge

// MARK: - PlatformViewHitTestBehavior

/// How an embedded platform view behaves during hit tests.
///
/// **Dart Source:** `platform_view.dart:19-32`
public enum PlatformViewHitTestBehavior: Sendable {
    /// Opaque targets can be hit by hit tests, causing them to both receive
    /// events within their bounds and prevent targets visually behind them from
    /// also receiving events.
    ///
    /// **Dart Source:** `platform_view.dart:23`
    case opaque

    /// Translucent targets both receive events within their bounds and permit
    /// targets visually behind them to also receive events.
    ///
    /// **Dart Source:** `platform_view.dart:27`
    case translucent

    /// Transparent targets don't receive events within their bounds and permit
    /// targets visually behind them to receive events.
    ///
    /// **Dart Source:** `platform_view.dart:31`
    case transparent
}

// MARK: - PlatformViewState

/// Internal state of a platform view during its lifecycle.
///
/// **Dart Source:** `platform_view.dart:34`
internal enum PlatformViewState {
    case uninitialized
    case resizing
    case ready
}

// MARK: - PlatformViewLayer (Stub)

/// A compositing layer that displays a platform view.
///
/// Platform views are composited by the system compositor rather than by
/// Flutter's own compositor. This layer tells the system compositor where
/// to place the platform view.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/layer.dart:1003-1069`
public class PlatformViewLayer: Layer {

    /// Creates a platform view layer.
    ///
    /// **Dart Source:** `layer.dart:1009-1013`
    public init(rect: Rect, viewId: Int) {
        self.rect = rect
        self.viewId = viewId
        super.init()
    }

    /// Bounding rectangle of this layer in the parent layer's coordinate system.
    ///
    /// **Dart Source:** `layer.dart:1016`
    public let rect: Rect

    /// The unique identifier of the platform view displayed by this layer.
    ///
    /// **Dart Source:** `layer.dart:1019`
    public let viewId: Int

    /// Adds this platform view layer to the scene.
    ///
    /// **Dart Source:** `layer.dart:1022-1030`
    public override func addToScene(_ builder: SceneBuilder) {
        // TODO: Full engine integration for platform view compositing.
        // builder.addPlatformView(viewId, offset: rect.topLeft,
        //     width: rect.width, height: rect.height)
    }

    /// Platform view layers are always leaves and do not contain annotations.
    ///
    /// **Dart Source:** `layer.dart:1040-1068`
    public override func findAnnotations<S>(
        _ result: AnnotationResult<S>,
        _ localPosition: Offset,
        onlyFirst: Bool
    ) -> Bool {
        return false
    }
}

// MARK: - PlatformViewController Protocol

/// Protocol for platform view controllers.
///
/// Defines the interface for controllers that manage platform views
/// embedded within the Flutter view hierarchy.
///
/// **Dart Source:** `services/platform_views.dart`
public protocol PlatformViewController: AnyObject {
    /// The unique identifier of the platform view managed by this controller.
    var viewId: Int { get }

    /// Dispatches a pointer event to the platform view.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    func dispatchPointerEvent(_ event: PointerEvent)
}

/// Default implementation for PlatformViewController methods.
extension PlatformViewController {
    /// Default no-op implementation for dispatching pointer events.
    public func dispatchPointerEvent(_ event: PointerEvent) {
        // Default no-op; subclasses provide platform-specific implementation.
    }
}

// MARK: - AndroidViewController (Stub)

/// Android platform view controller stub.
///
/// Provides the interface for controlling an Android platform view embedded
/// in the Flutter view hierarchy. This stub includes the properties and
/// methods required by `RenderAndroidView` for layout, painting, and
/// lifecycle management.
///
/// **Dart Source:** `services/platform_views.dart`
public class AndroidViewController: PlatformViewController {
    /// The unique identifier of the platform view.
    public let viewId: Int

    /// Creates an Android view controller with the given view identifier.
    public init(viewId: Int) {
        self.viewId = viewId
    }

    /// The texture ID for the Android view's backing texture, or `nil` if the
    /// view has not yet been created.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public var textureId: Int? { nil }

    /// Whether the platform view has been created on the platform side.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public var isCreated: Bool { false }

    /// A function that transforms a global offset to the local coordinate
    /// system of the platform view. Set by the render object.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public var pointTransformer: ((Offset) -> Offset)?

    /// Listeners that are called when the platform view is created.
    private var _platformViewCreatedListeners: [(Int) -> Void] = []

    /// Registers a callback to be invoked after the platform view is created.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public func addOnPlatformViewCreatedListener(_ listener: @escaping (Int) -> Void) {
        _platformViewCreatedListeners.append(listener)
    }

    /// Removes a previously registered platform view creation callback.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public func removeOnPlatformViewCreatedListener(_ listener: @escaping (Int) -> Void) {
        // In a full implementation, this would remove the matching closure.
        // Since closures are not Equatable in Swift, this is a no-op stub.
        // TODO: Use a token-based or identifier-based listener pattern.
    }

    /// Resizes the Android view to `size` and returns the resulting texture
    /// size.
    ///
    /// This is an asynchronous operation on Android because the platform view
    /// must allocate a new texture of the requested size.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public func setSize(_ size: Size) async -> Size {
        // TODO: Full platform channel integration for resizing.
        return size
    }

    /// Sets the offset of the platform view in global coordinates.
    ///
    /// This allows the Android native view to draw accessibility highlights
    /// and be positioned correctly on screen.
    ///
    /// **Dart Source:** `services/platform_views.dart`
    public func setOffset(_ offset: Offset) async {
        // TODO: Full platform channel integration for offset updates.
    }
}

// MARK: - DarwinPlatformViewController (Stub)

/// Protocol for Darwin (iOS/macOS) platform view controllers.
///
/// **Dart Source:** `services/platform_views.dart`
public protocol DarwinPlatformViewController: AnyObject {
    /// The unique identifier of the platform view.
    var id: Int { get }

    /// Accept a gesture.
    func acceptGesture()

    /// Reject a gesture.
    func rejectGesture()
}

// MARK: - UiKitViewController (Stub)

/// iOS UIKit platform view controller stub.
///
/// Manages an iOS UIKit `UIView` embedded within the Flutter view hierarchy.
/// This is a minimal stub; full implementation requires engine integration.
///
/// **Dart Source:** `services/platform_views.dart`
public class UiKitViewController: DarwinPlatformViewController {
    /// The unique identifier of the platform view.
    public let viewId: Int

    /// The Darwin-protocol identifier, forwarding to `viewId`.
    public var id: Int { viewId }

    /// Creates a UIKit view controller with the given view identifier.
    public init(viewId: Int) {
        self.viewId = viewId
    }

    /// Accepts a gesture, notifying the platform that the touch sequence
    /// should be forwarded to the UIKit view.
    public func acceptGesture() {
        // TODO: Full engine integration to release touch to the UIKit view.
    }

    /// Rejects a gesture, notifying the platform that the touch sequence
    /// should not be forwarded to the UIKit view.
    public func rejectGesture() {
        // TODO: Full engine integration to reject touch on the UIKit view.
    }
}

// MARK: - AppKitViewController (Stub)

/// macOS AppKit platform view controller stub.
///
/// Manages a macOS AppKit `NSView` embedded within the Flutter view hierarchy.
/// This is a minimal stub; full implementation requires engine integration.
///
/// **Dart Source:** `services/platform_views.dart`
public class AppKitViewController: DarwinPlatformViewController {
    /// The unique identifier of the platform view.
    public let viewId: Int

    /// The Darwin-protocol identifier, forwarding to `viewId`.
    public var id: Int { viewId }

    /// Creates an AppKit view controller with the given view identifier.
    public init(viewId: Int) {
        self.viewId = viewId
    }

    /// Accepts a gesture.
    public func acceptGesture() {
        // TODO: Full engine integration for macOS gesture handling.
    }

    /// Rejects a gesture.
    public func rejectGesture() {
        // TODO: Full engine integration for macOS gesture handling.
    }
}

// MARK: - Helper Functions

/// Compares two optional sets of `Factory<OneSequenceGestureRecognizer>` by
/// the types they produce.
///
/// Returns `true` if both sets contain factories for the same types of gesture
/// recognizers.
///
/// **Dart Source:** `platform_view.dart:36-44`
internal func factoryTypesSetEquals(
    _ a: Set<Factory<OneSequenceGestureRecognizer>>?,
    _ b: Set<Factory<OneSequenceGestureRecognizer>>?
) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    let aTypes = factoriesTypeSet(a)
    let bTypes = factoriesTypeSet(b)
    return aTypes == bTypes
}

/// Extracts the set of types produced by the given set of factories.
///
/// **Dart Source:** `platform_view.dart:46-48`
internal func factoriesTypeSet(
    _ factories: Set<Factory<OneSequenceGestureRecognizer>>
) -> Set<ObjectIdentifier> {
    return Set(factories.map { ObjectIdentifier($0.type) })
}

// MARK: - Factory Hashable Conformance

/// Make `Factory` conform to `Equatable` so it can be compared by type.
///
/// Two factories are considered equal if they produce the same type. This
/// matches the Dart behavior where the `type` property is the identity key.
extension Factory: Equatable where T: AnyObject {
    public static func == (lhs: Factory<T>, rhs: Factory<T>) -> Bool {
        return lhs.type == rhs.type
    }
}

/// Make `Factory` conform to `Hashable` so it can be stored in a `Set`.
extension Factory: Hashable where T: AnyObject {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }
}

// MARK: - _PlatformViewGestureRecognizer

/// A gesture recognizer that dispatches pointer events to a platform view.
///
/// This recognizer constructs gesture recognizers from a set of gesture
/// recognizer factories, adds all of them to a gesture arena team with itself
/// as the team captain. As long as the gesture arena is unresolved, the
/// recognizer caches all pointer events. When the team wins, the recognizer
/// sends all the cached pointer events to the handler, and sets itself to a
/// "forwarding mode" where it will forward any new pointer event immediately.
///
/// **Dart Source:** `platform_view.dart:554-658`
internal class PlatformViewGestureRecognizer: OneSequenceGestureRecognizer {

    /// Creates a platform view gesture recognizer.
    ///
    /// **Dart Source:** `platform_view.dart:555-578`
    internal init(
        _ handlePointerEvent: @escaping (PointerEvent) -> Void,
        _ gestureRecognizerFactories: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        self.gestureRecognizerFactories = gestureRecognizerFactories
        self._handlePointerEvent = handlePointerEvent
        // Build child recognizers from factories.
        self._gestureRecognizers = gestureRecognizerFactories.map { factory in
            return factory.constructor()
        }
        super.init()
    }

    /// The handler to forward pointer events to once the gesture is accepted.
    ///
    /// **Dart Source:** `platform_view.dart:580`
    private let _handlePointerEvent: (PointerEvent) -> Void

    /// Maps a pointer to a list of its cached pointer events.
    ///
    /// Before the arena for a pointer is resolved all events are cached here.
    /// If we win the arena, the cached events are dispatched to
    /// `_handlePointerEvent`; if we lose, the cache for the pointer is cleared.
    ///
    /// **Dart Source:** `platform_view.dart:586`
    internal var cachedEvents: [Int: [PointerEvent]] = [:]

    /// Pointers for which we have already won the arena; events for pointers in
    /// this set are immediately dispatched to `_handlePointerEvent`.
    ///
    /// **Dart Source:** `platform_view.dart:590`
    internal var forwardedPointers: Set<Int> = Set()

    /// The factories used to create the child gesture recognizers.
    ///
    /// **Dart Source:** `platform_view.dart:595`
    internal let gestureRecognizerFactories: Set<Factory<OneSequenceGestureRecognizer>>

    /// The child gesture recognizers created from the factories.
    ///
    /// **Dart Source:** `platform_view.dart:596`
    private var _gestureRecognizers: [OneSequenceGestureRecognizer]

    /// **Dart Source:** `platform_view.dart:598-603`
    internal override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        for recognizer in _gestureRecognizers {
            recognizer.addPointer(event)
        }
    }

    /// **Dart Source:** `platform_view.dart:607`
    open override func handleEvent(_ event: PointerEvent) {
        if !forwardedPointers.contains(event.pointer) {
            _cacheEvent(event)
        } else {
            _handlePointerEvent(event)
        }
        stopTrackingIfPointerNoLongerDown(event)
    }

    /// **Dart Source:** `platform_view.dart:619-622`
    open override func acceptGesture(_ pointer: Int) {
        _flushPointerCache(pointer)
        forwardedPointers.insert(pointer)
    }

    /// **Dart Source:** `platform_view.dart:625-628`
    open override func rejectGesture(_ pointer: Int) {
        stopTrackingPointer(pointer)
        cachedEvents.removeValue(forKey: pointer)
    }

    /// **Dart Source:** `platform_view.dart:630-635`
    private func _cacheEvent(_ event: PointerEvent) {
        if cachedEvents[event.pointer] == nil {
            cachedEvents[event.pointer] = []
        }
        cachedEvents[event.pointer]!.append(event)
    }

    /// **Dart Source:** `platform_view.dart:637-639`
    private func _flushPointerCache(_ pointer: Int) {
        if let events = cachedEvents.removeValue(forKey: pointer) {
            for event in events {
                _handlePointerEvent(event)
            }
        }
    }

    /// **Dart Source:** `platform_view.dart:641-645`
    open override func stopTrackingPointer(_ pointer: Int) {
        super.stopTrackingPointer(pointer)
        forwardedPointers.remove(pointer)
    }

    /// **Dart Source:** `platform_view.dart:647-653`
    internal func reset() {
        for pointer in forwardedPointers {
            super.stopTrackingPointer(pointer)
        }
        forwardedPointers.removeAll()
        for pointer in cachedEvents.keys {
            super.stopTrackingPointer(pointer)
        }
        cachedEvents.removeAll()
        resolve(.rejected)
    }

    /// **Dart Source:** `platform_view.dart:606`
    override func didStopTrackingLastPointer(_ pointer: Int) {}
}

// MARK: - UiKitViewGestureRecognizer

/// A gesture recognizer for UIKit platform views.
///
/// This recognizer constructs gesture recognizers from a set of gesture
/// recognizer factories, adds all of them to a gesture arena team with itself
/// as the team captain. When the team wins, the recognizer notifies the engine
/// that it should release the touch sequence to the embedded UIView.
///
/// **Dart Source:** `platform_view.dart:482-544`
internal class UiKitViewGestureRecognizer: OneSequenceGestureRecognizer {

    /// Creates a UIKit view gesture recognizer.
    ///
    /// **Dart Source:** `platform_view.dart:483-501`
    internal init(
        _ controller: UiKitViewController,
        _ gestureRecognizerFactories: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        self.controller = controller
        self.gestureRecognizerFactories = gestureRecognizerFactories
        super.init()
        self.team = GestureArenaTeam()
        self.team?.captain = self
        self._gestureRecognizers = gestureRecognizerFactories.map { factory in
            let recognizer = factory.constructor()
            recognizer.team = self.team!
            return recognizer
        }
    }

    /// The factories used to create the child gesture recognizers.
    ///
    /// **Dart Source:** `platform_view.dart:507`
    internal let gestureRecognizerFactories: Set<Factory<OneSequenceGestureRecognizer>>

    /// The child gesture recognizers created from the factories.
    ///
    /// **Dart Source:** `platform_view.dart:508`
    private var _gestureRecognizers: [OneSequenceGestureRecognizer] = []

    /// The UIKit view controller that this recognizer is associated with.
    ///
    /// **Dart Source:** `platform_view.dart:510`
    internal let controller: UiKitViewController

    /// **Dart Source:** `platform_view.dart:513-518`
    internal override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        for recognizer in _gestureRecognizers {
            recognizer.addPointer(event)
        }
    }

    /// **Dart Source:** `platform_view.dart:524`
    override func didStopTrackingLastPointer(_ pointer: Int) {}

    /// **Dart Source:** `platform_view.dart:527-529`
    open override func handleEvent(_ event: PointerEvent) {
        stopTrackingIfPointerNoLongerDown(event)
    }

    /// **Dart Source:** `platform_view.dart:532-534`
    open override func acceptGesture(_ pointer: Int) {
        controller.acceptGesture()
    }

    /// **Dart Source:** `platform_view.dart:537-539`
    open override func rejectGesture(_ pointer: Int) {
        controller.rejectGesture()
    }

    /// Resets the gesture recognizer, rejecting any ongoing gesture.
    ///
    /// **Dart Source:** `platform_view.dart:541-543`
    internal func reset() {
        resolve(.rejected)
    }
}

// MARK: - RenderDarwinPlatformView

/// Common render-layer functionality for iOS and macOS platform views.
///
/// Provides the basic rendering logic for Darwin (iOS/macOS) platform views.
/// Subclasses override `handleEvent` and `updateGestureRecognizers` in order
/// to execute custom event logic.
///
/// `T` represents the class of the view controller for the corresponding widget.
///
/// **Dart Source:** `platform_view.dart:279-391`
open class RenderDarwinPlatformView<T: DarwinPlatformViewController>: RenderBox {

    /// Creates a render object for a Darwin platform view.
    ///
    /// **Dart Source:** `platform_view.dart:281-287`
    public init(
        viewController: T,
        hitTestBehavior: PlatformViewHitTestBehavior,
        gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        self._viewController = viewController
        self._hitTestBehavior = hitTestBehavior
        super.init()
        updateGestureRecognizers(gestureRecognizers)
    }

    // MARK: - View Controller

    /// The platform view controller managed by this render object.
    ///
    /// **Dart Source:** `platform_view.dart:290-302`
    public var viewController: T {
        get { _viewController }
        set {
            if _viewController === newValue {
                return
            }
            let needsSemanticsUpdate = _viewController.id != newValue.id
            _viewController = newValue
            markNeedsPaint()
            if needsSemanticsUpdate {
                // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
            }
        }
    }
    private var _viewController: T

    // MARK: - Hit Test Behavior

    /// How to behave during hit testing.
    ///
    /// The implicit setter is sufficient here as changing this value will just
    /// affect any newly arriving events; there is nothing to invalidate.
    ///
    /// **Dart Source:** `platform_view.dart:304-307`
    public var hitTestBehavior: PlatformViewHitTestBehavior {
        get { _hitTestBehavior }
        set { _hitTestBehavior = newValue }
    }
    private var _hitTestBehavior: PlatformViewHitTestBehavior

    // MARK: - Gesture State

    /// The last pointer down event received by this render object.
    ///
    /// Used by `_handleGlobalPointerEvent` to determine whether a pointer event
    /// within bounds was absorbed by a different render object.
    ///
    /// **Dart Source:** `platform_view.dart:318`
    internal var _lastPointerDownEvent: PointerEvent?

    /// The gesture recognizer for this Darwin platform view.
    ///
    /// **Dart Source:** `platform_view.dart:320`
    internal var _gestureRecognizer: UiKitViewGestureRecognizer?

    // MARK: - RenderBox Overrides

    /// The size is determined entirely by the parent's constraints.
    ///
    /// **Dart Source:** `platform_view.dart:310`
    open override var sizedByParent: Bool { true }

    /// This render object always needs compositing because platform views are
    /// composited by the system compositor.
    ///
    /// **Dart Source:** `platform_view.dart:313`
    public override var alwaysNeedsCompositing: Bool { true }

    /// This render object is a repaint boundary.
    ///
    /// **Dart Source:** `platform_view.dart:316`
    open override var isRepaintBoundary: Bool { true }

    /// Computes the dry layout size for the given constraints.
    ///
    /// Returns the biggest size that satisfies the constraints, since platform
    /// views fill all available space.
    ///
    /// **Dart Source:** `platform_view.dart:323-326`
    open override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.biggest
    }

    // MARK: - Paint

    /// Paints the platform view by adding a `PlatformViewLayer`.
    ///
    /// **Dart Source:** `platform_view.dart:329-331`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        assert(alwaysNeedsCompositing)
        // PaintingContext.addLayer is not yet available.
        // Creating the layer for reference; it will be added once PaintingContext
        // supports addLayer.
        let _ = PlatformViewLayer(
            rect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
            viewId: _viewController.id
        )
    }

    // MARK: - Hit Testing

    /// Determines the set of render objects located at the given position.
    ///
    /// **Dart Source:** `platform_view.dart:334-340`
    public override func hitTest(_ result: BoxHitTestResult, position: Offset) -> Bool {
        if hitTestBehavior == .transparent || !size.contains(position) {
            return false
        }
        result.add(BoxHitTestEntry(AnyHitTestTarget(self), position))
        return hitTestBehavior == .opaque
    }

    /// Returns true if the hit test should consider this render object itself.
    ///
    /// **Dart Source:** `platform_view.dart:343`
    open override func hitTestSelf(_ position: Offset) -> Bool {
        return hitTestBehavior != .transparent
    }

    // MARK: - Global Pointer Event Handling

    /// Registered as a global pointer route while this render object is attached.
    ///
    /// If a pointer-down event lands within this render object's bounds but was
    /// not delivered via `handleEvent`, it means a different render object
    /// absorbed the event. In that case, the view controller is told to reject
    /// the gesture so the platform-side intercepting view does the same.
    ///
    /// **Dart Source:** `platform_view.dart:346-368`
    internal func _handleGlobalPointerEvent(_ event: PointerEvent) {
        if !hasSize {
            return
        }
        if !(event is PointerDownEvent) {
            return
        }
        let localPosition = globalToLocal(event.position)
        if !((Offset.zero & size).contains(localPosition)) {
            return
        }
        if (event.original ?? event) !== _lastPointerDownEvent {
            _viewController.rejectGesture()
        }
        _lastPointerDownEvent = nil
    }

    // MARK: - Lifecycle

    /// The route entry for the global pointer route, stored for removal.
    private var _globalRouteEntry: PointerRouteEntry?

    /// Called when the object is attached to a pipeline owner.
    ///
    /// Registers a global pointer route so we can detect absorbed pointer events.
    ///
    /// **Dart Source:** `platform_view.dart:378-381`
    open override func attach(_ owner: PipelineOwner) {
        super.attach(owner)
        _globalRouteEntry = GestureBinding.instance.pointerRouter.addGlobalRoute(
            _handleGlobalPointerEvent
        )
    }

    /// Called when the object is detached from the pipeline owner.
    ///
    /// Removes the global pointer route.
    ///
    /// **Dart Source:** `platform_view.dart:384-387`
    open override func detach() {
        if let entry = _globalRouteEntry {
            GestureBinding.instance.pointerRouter.removeGlobalRoute(entry)
            _globalRouteEntry = nil
        }
        super.detach()
    }

    /// Updates which gestures should be forwarded to the platform view.
    ///
    /// Subclasses must override this method to configure gesture recognizers.
    ///
    /// **Dart Source:** `platform_view.dart:389-391`
    open func updateGestureRecognizers(
        _ gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        // Subclasses must override.
    }
}

// MARK: - RenderUiKitView

/// A render object for an iOS UIKit UIView.
///
/// `RenderUiKitView` is responsible for sizing and displaying an iOS
/// [UIView](https://developer.apple.com/documentation/uikit/uiview).
///
/// UIViews are added as subviews of the FlutterView and are composited
/// by Quartz.
///
/// **Dart Source:** `platform_view.dart:411-457`
public class RenderUiKitView: RenderDarwinPlatformView<UiKitViewController> {

    /// Creates a render object for an iOS UIView.
    ///
    /// **Dart Source:** `platform_view.dart:413-417`
    public override init(
        viewController: UiKitViewController,
        hitTestBehavior: PlatformViewHitTestBehavior,
        gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        super.init(
            viewController: viewController,
            hitTestBehavior: hitTestBehavior,
            gestureRecognizers: gestureRecognizers
        )
    }

    /// Updates which gestures should be forwarded to the platform view.
    ///
    /// **Dart Source:** `platform_view.dart:420-435`
    public override func updateGestureRecognizers(
        _ gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        assert(
            factoriesTypeSet(gestureRecognizers).count == gestureRecognizers.count,
            "There were multiple gesture recognizer factories for the same type, "
            + "there must only be a single gesture recognizer factory for each "
            + "gesture recognizer type."
        )
        if factoryTypesSetEquals(
            gestureRecognizers,
            _gestureRecognizer?.gestureRecognizerFactories
        ) {
            return
        }
        _gestureRecognizer?.dispose()
        _gestureRecognizer = UiKitViewGestureRecognizer(
            viewController,
            gestureRecognizers
        )
    }

    /// Handles pointer events that hit this render object.
    ///
    /// Only responds to `PointerDownEvent`s by forwarding them to the gesture
    /// recognizer and recording the event for global pointer event comparison.
    ///
    /// **Dart Source:** `platform_view.dart:438-444`
    open override func handleEvent(
        _ event: PointerEvent,
        entry: HitTestEntry<AnyHitTestTarget>
    ) {
        if !(event is PointerDownEvent) {
            return
        }
        _gestureRecognizer!.addPointer(event as! PointerDownEvent)
        _lastPointerDownEvent = event.original ?? event
    }

    /// Detaches this render object from the tree.
    ///
    /// Resets the gesture recognizer when detaching.
    ///
    /// **Dart Source:** `platform_view.dart:447-450`
    open override func detach() {
        _gestureRecognizer?.reset()
        super.detach()
    }

    /// Releases any resources held by this render object.
    ///
    /// **Dart Source:** `platform_view.dart:453-456`
    open override func dispose() {
        _gestureRecognizer?.dispose()
        super.dispose()
    }
}

// MARK: - RenderAppKitView

/// A render object for a macOS platform view.
///
/// `RenderAppKitView` is responsible for sizing and displaying a macOS
/// AppKit `NSView`.
///
/// **Dart Source:** `platform_view.dart:460-475`
public class RenderAppKitView: RenderDarwinPlatformView<AppKitViewController> {

    /// Creates a render object for a macOS AppKitView.
    ///
    /// **Dart Source:** `platform_view.dart:462-466`
    public override init(
        viewController: AppKitViewController,
        hitTestBehavior: PlatformViewHitTestBehavior,
        gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        super.init(
            viewController: viewController,
            hitTestBehavior: hitTestBehavior,
            gestureRecognizers: gestureRecognizers
        )
    }

    /// Updates gesture recognizers for the macOS platform view.
    ///
    /// Currently a no-op; macOS gesture handling is not yet implemented.
    ///
    /// **Dart Source:** `platform_view.dart:473-474`
    /// TODO(schectman): Add gesture functionality to macOS platform view when
    /// implemented. https://github.com/flutter/flutter/issues/128519
    public override func updateGestureRecognizers(
        _ gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        // No-op: macOS gesture handling not yet implemented.
    }
}

// MARK: - PlatformViewRenderBox

/// A render object for embedding a platform view.
///
/// `PlatformViewRenderBox` presents a platform view by adding a
/// `PlatformViewLayer` layer, integrates it with the gesture arenas system
/// and adds relevant semantic nodes to the semantics tree.
///
/// **Dart Source:** `platform_view.dart:664-742`
open class PlatformViewRenderBox: RenderBox {

    /// Creates a render object for a `PlatformViewSurface`.
    ///
    /// **Dart Source:** `platform_view.dart:666-674`
    public init(
        controller: PlatformViewController,
        hitTestBehavior: PlatformViewHitTestBehavior,
        gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        assert(controller.viewId > -1)
        self._controller = controller
        super.init()
        self.hitTestBehavior = hitTestBehavior
        updateGestureRecognizers(gestureRecognizers)
    }

    // MARK: - Controller

    /// The controller for this render object.
    ///
    /// **Dart Source:** `platform_view.dart:677`
    public var controller: PlatformViewController {
        get { _controller }
        set {
            assert(newValue.viewId > -1)
            if _controller === newValue {
                return
            }
            let needsSemanticsUpdate = _controller.viewId != newValue.viewId
            _controller = newValue
            markNeedsPaint()
            if needsSemanticsUpdate {
                // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
            }
        }
    }
    private var _controller: PlatformViewController

    // MARK: - Gesture Mixin Members

    /// How to behave during hit testing.
    ///
    /// **Dart Source:** `platform_view.dart:747-754`
    public var hitTestBehavior: PlatformViewHitTestBehavior {
        get { _hitTestBehavior ?? .opaque }
        set {
            if newValue != _hitTestBehavior {
                _hitTestBehavior = newValue
                if _owner != nil {
                    markNeedsPaint()
                }
            }
        }
    }
    private var _hitTestBehavior: PlatformViewHitTestBehavior?

    /// The handler to forward pointer events to.
    ///
    /// **Dart Source:** `platform_view.dart:758`
    private var _handlePointerEvent: ((PointerEvent) -> Void)?

    /// The gesture recognizer that dispatches events to the platform view.
    ///
    /// **Dart Source:** `platform_view.dart:784`
    private var _gestureRecognizer: PlatformViewGestureRecognizer?

    // MARK: - Gesture Management

    /// Updates which gestures should be forwarded to the platform view.
    ///
    /// Gesture recognizers created by factories in this set participate in the
    /// gesture arena for each pointer that was put down on the render box. If any
    /// of the recognizers on this list wins the gesture arena, the entire pointer
    /// event sequence starting from the pointer down event will be dispatched to
    /// the platform view.
    ///
    /// The `gestureRecognizers` must not contain more than one factory with the
    /// same `Factory.type`.
    ///
    /// Setting a new set of gesture recognizer factories with the same
    /// `Factory.type`s as the current set has no effect, because the factories'
    /// constructors would have already been called with the previous set.
    ///
    /// Any active gesture arena the `PlatformView` participates in is rejected
    /// when the set of gesture recognizers is changed.
    ///
    /// **Dart Source:** `platform_view.dart:711-713`
    public func updateGestureRecognizers(
        _ gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>
    ) {
        _updateGestureRecognizersWithCallBack(
            gestureRecognizers,
            _controller.dispatchPointerEvent
        )
    }

    /// Internal implementation of gesture recognizer updates.
    ///
    /// **Dart Source:** `platform_view.dart:764-782`
    internal func _updateGestureRecognizersWithCallBack(
        _ gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>>,
        _ handlePointerEvent: @escaping (PointerEvent) -> Void
    ) {
        assert(
            factoriesTypeSet(gestureRecognizers).count == gestureRecognizers.count,
            "There were multiple gesture recognizer factories for the same type, "
            + "there must only be a single gesture recognizer factory for each "
            + "gesture recognizer type."
        )
        if factoryTypesSetEquals(
            gestureRecognizers,
            _gestureRecognizer?.gestureRecognizerFactories
        ) {
            return
        }
        _gestureRecognizer?.dispose()
        _gestureRecognizer = PlatformViewGestureRecognizer(
            handlePointerEvent,
            gestureRecognizers
        )
        _handlePointerEvent = handlePointerEvent
    }

    // MARK: - RenderBox Overrides

    /// The size is determined entirely by the parent's constraints.
    ///
    /// **Dart Source:** `platform_view.dart:716`
    open override var sizedByParent: Bool { true }

    /// This render object always needs compositing because platform views are
    /// composited by the system compositor.
    ///
    /// **Dart Source:** `platform_view.dart:719`
    public override var alwaysNeedsCompositing: Bool { true }

    /// This render object is a repaint boundary.
    ///
    /// **Dart Source:** `platform_view.dart:722`
    open override var isRepaintBoundary: Bool { true }

    /// Computes the dry layout size for the given constraints.
    ///
    /// Returns the biggest size that satisfies the constraints, since platform
    /// views fill all available space.
    ///
    /// **Dart Source:** `platform_view.dart:726-728`
    open override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.biggest
    }

    // MARK: - Paint

    /// Paints the platform view by adding a `PlatformViewLayer`.
    ///
    /// **Dart Source:** `platform_view.dart:731-733`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        assert(alwaysNeedsCompositing)
        // PaintingContext.addLayer is not yet available.
        // Creating the layer for reference; it will be added once PaintingContext
        // supports addLayer.
        let _ = PlatformViewLayer(
            rect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
            viewId: _controller.viewId
        )
    }

    // MARK: - Hit Testing

    /// Determines the set of render objects located at the given position.
    ///
    /// Overrides the default hit test to implement platform view hit test behavior.
    ///
    /// **Dart Source:** `platform_view.dart:787-793`
    public override func hitTest(_ result: BoxHitTestResult, position: Offset) -> Bool {
        if _hitTestBehavior == .transparent || !size.contains(position) {
            return false
        }
        result.add(BoxHitTestEntry(AnyHitTestTarget(self), position))
        return _hitTestBehavior == .opaque
    }

    /// Returns true if the hit test should consider this render object itself,
    /// regardless of whether any children were hit.
    ///
    /// **Dart Source:** `platform_view.dart:796`
    open override func hitTestSelf(_ position: Offset) -> Bool {
        return _hitTestBehavior != .transparent
    }

    // MARK: - Event Handling

    /// Handles pointer events that hit this render object.
    ///
    /// Dispatches `PointerDownEvent`s to the gesture recognizer, and
    /// `PointerHoverEvent`s directly to the pointer event handler.
    ///
    /// **Dart Source:** `platform_view.dart:811-818`
    open override func handleEvent(_ event: PointerEvent, entry: HitTestEntry<AnyHitTestTarget>) {
        if event is PointerDownEvent {
            _gestureRecognizer?.addPointer(event as! PointerDownEvent)
        }
        if event is PointerHoverEvent {
            _handlePointerEvent?(event)
        }
    }

    // MARK: - Lifecycle

    /// Detaches this render object from the tree.
    ///
    /// Resets the gesture recognizer when detaching.
    ///
    /// **Dart Source:** `platform_view.dart:820-824`
    open override func detach() {
        _gestureRecognizer?.reset()
        super.detach()
    }

    /// Releases any resources held by this render object.
    ///
    /// **Dart Source:** `platform_view.dart:826-830`
    open override func dispose() {
        _gestureRecognizer?.dispose()
        super.dispose()
    }
}

// MARK: - RenderAndroidView

/// Renders an Android platform view within the Flutter rendering tree.
///
/// This render object integrates an `AndroidViewController` with the
/// Flutter compositor by resizing the platform view's backing texture
/// to match the render object's layout size and painting the texture
/// into the scene. When the texture is larger than the widget (e.g.
/// during an in-flight resize) the content is optionally clipped.
///
/// **Dart Source:** `platform_view.dart:74-277`
public class RenderAndroidView: PlatformViewRenderBox {

    // MARK: - Initializer

    /// Creates a render object for an Android view.
    ///
    /// **Dart Source:** `platform_view.dart:76-93`
    public init(
        viewController: AndroidViewController,
        hitTestBehavior: PlatformViewHitTestBehavior = .opaque,
        gestureRecognizers: Set<Factory<OneSequenceGestureRecognizer>> = [],
        clipBehavior: Clip = .hardEdge
    ) {
        self._viewController = viewController
        self._clipBehavior = clipBehavior
        super.init(
            controller: viewController,
            hitTestBehavior: hitTestBehavior,
            gestureRecognizers: gestureRecognizers
        )
        _viewController.pointTransformer = { [weak self] offset in
            self?.globalToLocal(offset) ?? offset
        }
        updateGestureRecognizers(gestureRecognizers)
        _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated)
        self.hitTestBehavior = hitTestBehavior
        _setOffset()
    }

    // MARK: - State

    /// Internal lifecycle state of the platform view.
    ///
    /// **Dart Source:** `platform_view.dart:95`
    private var _state: PlatformViewState = .uninitialized

    /// The current size of the backing texture, or `nil` if the view has not
    /// yet been sized.
    ///
    /// **Dart Source:** `platform_view.dart:97`
    private var _currentTextureSize: Size?

    /// Whether this render object has been disposed.
    ///
    /// **Dart Source:** `platform_view.dart:99`
    private var _isDisposed: Bool = false

    // MARK: - View Controller

    /// The Android view controller for the Android view associated with this
    /// render object.
    ///
    /// **Dart Source:** `platform_view.dart:102-103`
    private var _viewController: AndroidViewController

    /// The Android view controller.
    ///
    /// When a new controller is set, the old controller's listeners are
    /// removed, the base class controller is updated, and the view is
    /// resized to the current layout size.
    ///
    /// **Dart Source:** `platform_view.dart:109-123`
    public var viewController: AndroidViewController {
        get { _viewController }
        set {
            assert(!_isDisposed)
            if _viewController === newValue {
                return
            }
            _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated)
            controller = newValue
            _viewController = newValue
            _viewController.pointTransformer = { [weak self] offset in
                self?.globalToLocal(offset) ?? offset
            }
            _sizePlatformView()
            if _viewController.isCreated {
                // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
            }
            _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated)
        }
    }

    // MARK: - Clip Behavior

    /// How to clip the platform view's texture.
    ///
    /// Defaults to `Clip.hardEdge`.
    ///
    /// **Dart Source:** `platform_view.dart:128-136`
    public var clipBehavior: Clip {
        get { _clipBehavior }
        set {
            if newValue != _clipBehavior {
                _clipBehavior = newValue
                markNeedsPaint()
                // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
            }
        }
    }
    private var _clipBehavior: Clip

    // MARK: - Platform View Created Callback

    /// Called when the platform view is created on the platform side.
    ///
    /// **Dart Source:** `platform_view.dart:138-141`
    private func _onPlatformViewCreated(_ id: Int) {
        assert(!_isDisposed)
        // TODO: Call markNeedsSemanticsUpdate() once semantics is available.
    }

    // MARK: - Layout

    /// The size is determined entirely by the parent's constraints.
    ///
    /// **Dart Source:** `platform_view.dart:144`
    open override var sizedByParent: Bool { true }

    /// Computes the dry layout size for the given constraints.
    ///
    /// Returns the biggest size that satisfies the constraints, since the
    /// platform view fills all available space.
    ///
    /// **Dart Source:** `platform_view.dart:154-156`
    open override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.biggest
    }

    /// Performs the resize step of layout.
    ///
    /// After the base class determines the size from constraints, this
    /// triggers an asynchronous resize of the backing Android platform view.
    ///
    /// **Dart Source:** `platform_view.dart:159-162`
    open override func performResize() {
        super.performResize()
        _sizePlatformView()
    }

    /// Resizes the backing Android platform view to match the current layout
    /// size.
    ///
    /// Android virtual displays cannot have a zero size. If the size is empty
    /// or a resize is already in progress, this method returns early. Once the
    /// resize completes, if the layout size has changed again while the resize
    /// was in flight, the method loops to resize again.
    ///
    /// **Dart Source:** `platform_view.dart:164-189`
    private func _sizePlatformView() {
        // Android virtual displays cannot have a zero size.
        // Trying to size it to 0 crashes the app, which was happening when
        // starting the app with a locked screen.
        // See: https://github.com/flutter/flutter/issues/20456
        if _state == .resizing || size.isEmpty {
            return
        }

        _state = .resizing
        markNeedsPaint()

        // TODO: Full async resize integration with platform channels.
        // In the Dart implementation this is an async loop that calls
        // _viewController.setSize(targetSize) and re-checks whether the
        // render object's size changed while awaiting.
        //
        // Stub: synchronously mark as ready.
        _currentTextureSize = size
        _state = .ready
        markNeedsPaint()
    }

    // MARK: - Offset

    /// Notifies the Android view controller of the current global offset so
    /// that accessibility highlights and native hit testing align with the
    /// Flutter widget position.
    ///
    /// In the Dart implementation this schedules itself via
    /// `SchedulerBinding.addPostFrameCallback` so the offset stays current
    /// after every frame.
    ///
    /// **Dart Source:** `platform_view.dart:198-208`
    private func _setOffset() {
        // TODO: Schedule via SchedulerBinding.addPostFrameCallback once
        // available. The Dart implementation continuously re-schedules itself
        // to keep the offset in sync every frame.
    }

    // MARK: - Paint

    /// Paints the platform view's texture into the scene.
    ///
    /// If the texture or texture ID is not yet available, painting is skipped.
    /// When the texture is larger than the widget (during a resize), the
    /// content is clipped according to `clipBehavior`.
    ///
    /// **Dart Source:** `platform_view.dart:211-239`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        if _viewController.textureId == nil || _currentTextureSize == nil {
            return
        }

        // As resizing the Android view happens asynchronously we don't know
        // exactly when a texture frame with the new size is ready. To prevent
        // unwanted scaling artifacts while resizing, clip the texture when it
        // is larger than the widget.
        let isTextureLargerThanWidget =
            _currentTextureSize!.width > size.width
            || _currentTextureSize!.height > size.height

        if isTextureLargerThanWidget && clipBehavior != .none {
            _clipRectLayer.layer = context.pushClipRect(
                true,
                offset,
                offset & size,
                _paintTexture,
                clipBehavior: clipBehavior,
                oldLayer: _clipRectLayer.layer
            )
            return
        }
        _clipRectLayer.layer = nil
        _paintTexture(context, offset)
    }

    /// The layer handle for the clip rect used when the texture is larger than
    /// the widget during a resize.
    ///
    /// **Dart Source:** `platform_view.dart:241`
    private let _clipRectLayer = LayerHandle<ClipRectLayer>()

    /// Paints the texture layer at the given offset.
    ///
    /// **Dart Source:** `platform_view.dart:251-259`
    private func _paintTexture(_ context: PaintingContext, _ offset: Offset) {
        guard let currentTextureSize = _currentTextureSize,
              let textureId = _viewController.textureId else {
            return
        }

        // PaintingContext.addLayer is not yet available.
        // Creating the layer for reference; it will be added once
        // PaintingContext supports addLayer.
        let _ = TextureLayer(
            rect: offset & currentTextureSize,
            textureId: textureId
        )
    }

    // MARK: - Lifecycle

    /// Called when the render object is attached to a pipeline owner.
    ///
    /// **Dart Source:** (Implicit from RenderObject)
    open override func attach(_ owner: PipelineOwner) {
        super.attach(owner)
    }

    /// Called when the render object is detached from the tree.
    ///
    /// Resets the gesture recognizer when detaching.
    ///
    /// **Dart Source:** `platform_view.dart` (inherited behavior)
    open override func detach() {
        super.detach()
    }

    /// Releases all resources held by this render object.
    ///
    /// Marks the render object as disposed, clears the clip rect layer handle,
    /// and removes the platform view creation listener.
    ///
    /// **Dart Source:** `platform_view.dart:244-249`
    open override func dispose() {
        _isDisposed = true
        _clipRectLayer.layer = nil
        _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated)
        super.dispose()
    }
}
