// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// Base class for pointer events.
///
/// Pointer events represent interactions with the device's input surface,
/// such as touches, mouse movements, and stylus inputs. This abstract base
/// class defines the common properties and methods shared by all pointer
/// event types.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 251-632
open class PointerEvent: Diagnosticable {

    // MARK: - Initializer

    /// Creates a pointer event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    public init(
        viewId: Int = 0,
        embedderId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        delta: Offset = .zero,
        buttons: Int = 0,
        down: Bool = false,
        obscured: Bool = false,
        pressure: Double = 1.0,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
        distance: Double = 0.0,
        distanceMax: Double = 0.0,
        size: Double = 0.0,
        radiusMajor: Double = 0.0,
        radiusMinor: Double = 0.0,
        radiusMin: Double = 0.0,
        radiusMax: Double = 0.0,
        orientation: Double = 0.0,
        tilt: Double = 0.0,
        platformData: Int = 0,
        synthesized: Bool = false,
        transform: Matrix4? = nil,
        original: PointerEvent? = nil
    ) {
        self.viewId = viewId
        self.embedderId = embedderId
        self.timeStamp = timeStamp
        self.pointer = pointer
        self.kind = kind
        self.device = device
        self.position = position
        self.delta = delta
        self.buttons = buttons
        self.down = down
        self.obscured = obscured
        self.pressure = pressure
        self.pressureMin = pressureMin
        self.pressureMax = pressureMax
        self.distance = distance
        self.distanceMax = distanceMax
        self.size = size
        self.radiusMajor = radiusMajor
        self.radiusMinor = radiusMinor
        self.radiusMin = radiusMin
        self.radiusMax = radiusMax
        self.orientation = orientation
        self.tilt = tilt
        self.platformData = platformData
        self.synthesized = synthesized
        self.transform = transform
        self.original = original
    }

    // MARK: - Stored Properties

    /// The ID of the `FlutterView` which this event originated from.
    ///
    /// **Dart Source:** `events.dart:285`
    public let viewId: Int

    /// Unique identifier that ties the `PointerEvent` to the embedder event that created it.
    ///
    /// No two pointer events can have the same `embedderId` on platforms that set it.
    /// This is different from `pointer` identifier - used for hit-testing,
    /// whereas `embedderId` is used to identify the platform event.
    ///
    /// **Dart Source:** `events.dart:287-294`
    public let embedderId: Int

    /// Time of event dispatch, relative to an arbitrary timeline.
    ///
    /// **Dart Source:** `events.dart:297`
    public let timeStamp: Duration

    /// Unique identifier for the pointer, not reused. Changes for each new
    /// pointer down event.
    ///
    /// **Dart Source:** `events.dart:301`
    public let pointer: Int

    /// The kind of input device for which the event was generated.
    ///
    /// **Dart Source:** `events.dart:304`
    public let kind: PointerDeviceKind

    /// Unique identifier for the pointing device, reused across interactions.
    ///
    /// **Dart Source:** `events.dart:307`
    public let device: Int

    /// Coordinate of the position of the pointer, in logical pixels in the global
    /// coordinate space.
    ///
    /// See also:
    ///
    ///  * `localPosition`, which is the `position` transformed into the local
    ///    coordinate system of the event receiver.
    ///
    /// **Dart Source:** `events.dart:316`
    public let position: Offset

    /// Distance in logical pixels that the pointer moved since the last
    /// `PointerMoveEvent` or `PointerHoverEvent`.
    ///
    /// This value is always 0.0 for down, up, and cancel events.
    ///
    /// See also:
    ///
    ///  * `localDelta`, which is the `delta` transformed into the local
    ///    coordinate space of the event receiver.
    ///
    /// **Dart Source:** `events.dart:337`
    public let delta: Offset

    /// Bit field using the *Button constants such as `kPrimaryMouseButton`,
    /// `kSecondaryStylusButton`, etc.
    ///
    /// For example, if this has the value 6 and the
    /// `kind` is `PointerDeviceKind.invertedStylus`, then this indicates an
    /// upside-down stylus with both its primary and secondary buttons pressed.
    ///
    /// **Dart Source:** `events.dart:356`
    public let buttons: Int

    /// Set if the pointer is currently down.
    ///
    /// For touch and stylus pointers, this means the object (finger, pen) is in
    /// contact with the input surface. For mice, it means a button is pressed.
    ///
    /// **Dart Source:** `events.dart:362`
    public let down: Bool

    /// Set if an application from a different security domain is in any way
    /// obscuring this application's window.
    ///
    /// This is not currently implemented.
    ///
    /// **Dart Source:** `events.dart:368`
    public let obscured: Bool

    /// The pressure of the touch.
    ///
    /// This value is a number ranging from 0.0, indicating a touch with no
    /// discernible pressure, to 1.0, indicating a touch with "normal" pressure,
    /// and possibly beyond, indicating a stronger touch. For devices that do not
    /// detect pressure (e.g. mice), returns 1.0.
    ///
    /// **Dart Source:** `events.dart:376`
    public let pressure: Double

    /// The minimum value that `pressure` can return for this pointer.
    ///
    /// For devices that do not detect pressure (e.g. mice), returns 1.0.
    /// This will always be a number less than or equal to 1.0.
    ///
    /// **Dart Source:** `events.dart:382`
    public let pressureMin: Double

    /// The maximum value that `pressure` can return for this pointer.
    ///
    /// For devices that do not detect pressure (e.g. mice), returns 1.0.
    /// This will always be a greater than or equal to 1.0.
    ///
    /// **Dart Source:** `events.dart:388`
    public let pressureMax: Double

    /// The distance of the detected object from the input surface.
    ///
    /// For instance, this value could be the distance of a stylus or finger
    /// from a touch screen, in arbitrary units on an arbitrary (not necessarily
    /// linear) scale. If the pointer is down, this is 0.0 by definition.
    ///
    /// **Dart Source:** `events.dart:395`
    public let distance: Double

    /// The maximum value that `distance` can return for this pointer.
    ///
    /// If this input device cannot detect "hover touch" input events,
    /// then this will be 0.0.
    ///
    /// **Dart Source:** `events.dart:406`
    public let distanceMax: Double

    /// The area of the screen being pressed.
    ///
    /// This value is scaled to a range between 0 and 1. It can be used to
    /// determine fat touch events. This value is only set on Android and is
    /// a device specific approximation within the range of detectable values.
    /// So, for example, the value of 0.1 could mean a touch with the tip of
    /// the finger, 0.2 a touch with full finger, and 0.3 the full palm.
    ///
    /// Because this value uses device-specific range and is uncalibrated,
    /// it is of limited use and is primarily retained in order to be able
    /// to reconstruct original pointer events for `AndroidView`.
    ///
    /// **Dart Source:** `events.dart:419`
    public let size: Double

    /// The radius of the contact ellipse along the major axis, in logical pixels.
    ///
    /// **Dart Source:** `events.dart:422`
    public let radiusMajor: Double

    /// The radius of the contact ellipse along the minor axis, in logical pixels.
    ///
    /// **Dart Source:** `events.dart:425`
    public let radiusMinor: Double

    /// The minimum value that could be reported for `radiusMajor` and `radiusMinor`
    /// for this pointer, in logical pixels.
    ///
    /// **Dart Source:** `events.dart:429`
    public let radiusMin: Double

    /// The maximum value that could be reported for `radiusMajor` and `radiusMinor`
    /// for this pointer, in logical pixels.
    ///
    /// **Dart Source:** `events.dart:433`
    public let radiusMax: Double

    /// The orientation angle of the detected object, in radians.
    ///
    /// For `PointerDeviceKind.touch` events:
    ///
    /// The angle of the contact ellipse, in radians in the range:
    ///
    ///     -pi/2 < orientation <= pi/2
    ///
    /// ...giving the angle of the major axis of the ellipse with the y-axis
    /// (negative angles indicating an orientation along the top-left /
    /// bottom-right diagonal, positive angles indicating an orientation along the
    /// top-right / bottom-left diagonal, and zero indicating an orientation
    /// parallel with the y-axis).
    ///
    /// For `PointerDeviceKind.stylus` and `PointerDeviceKind.invertedStylus` events:
    ///
    /// The angle of the stylus, in radians in the range:
    ///
    ///     -pi < orientation <= pi
    ///
    /// ...giving the angle of the axis of the stylus projected onto the input
    /// surface, relative to the positive y-axis of that surface (thus 0.0
    /// indicates the stylus, if projected onto that surface, would go from the
    /// contact point vertically up in the positive y-axis direction, pi would
    /// indicate that the stylus would go down in the negative y-axis direction;
    /// pi/4 would indicate that the stylus goes up and to the right, -pi/2 would
    /// indicate that the stylus goes to the left, etc).
    ///
    /// **Dart Source:** `events.dart:462`
    public let orientation: Double

    /// The tilt angle of the detected object, in radians.
    ///
    /// For `PointerDeviceKind.stylus` and `PointerDeviceKind.invertedStylus` events:
    ///
    /// The angle of the stylus, in radians in the range:
    ///
    ///     0 <= tilt <= pi/2
    ///
    /// ...giving the angle of the axis of the stylus, relative to the axis
    /// perpendicular to the input surface (thus 0.0 indicates the stylus is
    /// orthogonal to the plane of the input surface, while pi/2 indicates that
    /// the stylus is flat on that surface).
    ///
    /// **Dart Source:** `events.dart:476`
    public let tilt: Double

    /// Opaque platform-specific data associated with the event.
    ///
    /// **Dart Source:** `events.dart:479`
    public let platformData: Int

    /// Set if the event was synthesized by Flutter.
    ///
    /// We occasionally synthesize PointerEvents that aren't exact translations
    /// of `PointerData` from the engine to cover small cross-OS discrepancies
    /// in pointer behaviors.
    ///
    /// For instance, on end events, Android always drops any location changes
    /// that happened between its reporting intervals when emitting the end events.
    ///
    /// On iOS, minor incorrect location changes from the previous move events
    /// can be reported on end events. We synthesize a `PointerEvent` to cover
    /// the difference between the 2 events in that case.
    ///
    /// **Dart Source:** `events.dart:493`
    public let synthesized: Bool

    /// The transformation used to transform this event from the global coordinate
    /// space into the coordinate space of the event receiver.
    ///
    /// This value affects what is returned by `localPosition` and `localDelta`.
    /// If this value is nil, it is treated as the identity transformation.
    ///
    /// Unlike a paint transform, this transform usually does not contain any
    /// "perspective" components, meaning that the third row and the third column
    /// of the matrix should be equal to "0, 0, 1, 0". This ensures that
    /// `localPosition` describes the point in the local coordinate system of the
    /// event receiver at which the user is actually touching the screen.
    ///
    /// See also:
    ///
    ///  * `transformed`, which transforms this event into a different coordinate
    ///    space.
    ///
    /// **Dart Source:** `events.dart:511`
    public let transform: Matrix4?

    /// The original un-transformed `PointerEvent` before any transforms were
    /// applied.
    ///
    /// If `transform` is nil or the identity transformation this may be nil.
    ///
    /// When multiple event receivers in different coordinate spaces receive an
    /// event, they all receive the event transformed to their local coordinate
    /// space. The `original` property can be used to determine if all those
    /// transformed events actually originated from the same pointer interaction.
    ///
    /// **Dart Source:** `events.dart:522`
    public let original: PointerEvent?

    // MARK: - Computed Properties

    /// The `position` transformed into the event receiver's local coordinate
    /// system according to `transform`.
    ///
    /// If this event has not been transformed, `position` is returned as-is.
    ///
    /// See also:
    ///
    ///  * `position`, which is the position in the global coordinate system of
    ///    the screen.
    ///
    /// **Dart Source:** `events.dart:326`
    open var localPosition: Offset {
        return position
    }

    /// The `delta` transformed into the event receiver's local coordinate
    /// system according to `transform`.
    ///
    /// If this event has not been transformed, `delta` is returned as-is.
    ///
    /// See also:
    ///
    ///  * `delta`, which is the distance the pointer moved in the global
    ///    coordinate system of the screen.
    ///
    /// **Dart Source:** `events.dart:348`
    open var localDelta: Offset {
        return delta
    }

    /// The minimum value that `distance` can return for this pointer.
    ///
    /// This value is always 0.0.
    ///
    /// **Dart Source:** `events.dart:400`
    open var distanceMin: Double {
        return 0.0
    }

    // MARK: - Abstract Methods

    /// Transforms the event from the global coordinate space into the coordinate
    /// space of an event receiver.
    ///
    /// The coordinate space of the event receiver is described by `transform`. A
    /// nil value for `transform` is treated as the identity transformation.
    ///
    /// The resulting event will store the base event as `original`, delegates
    /// most properties to `original`, except for `localPosition` and `localDelta`,
    /// which are calculated based on `transform` on first use and cached.
    ///
    /// The method may return the same object instance if for example the
    /// transformation has no effect on the event. Otherwise, the resulting event
    /// will be a subclass of, but not exactly, the original event class (e.g.
    /// `PointerDownEvent.transformed` may return a subclass of `PointerDownEvent`).
    ///
    /// Transforms are not commutative, and are based on `original` events.
    /// If this method is called on a transformed event, the provided `transform`
    /// will override (instead of multiplied onto) the existing `transform` and
    /// used to calculate the new `localPosition` and `localDelta`.
    ///
    /// **Dart Source:** `events.dart:543`
    open func transformed(_ transform: Matrix4?) -> PointerEvent {
        fatalError("Subclass must override transformed(_:)")
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// Calling this method on a transformed event will return a new transformed
    /// event based on the current `transform` and the provided properties.
    ///
    /// **Dart Source:** `events.dart:549-573`
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil
    ) -> PointerEvent {
        fatalError("Subclass must override copyWith(...)")
    }

    // MARK: - Static Methods

    /// Returns the transformation of `position` into the coordinate system
    /// described by `transform`.
    ///
    /// The z-value of `position` is assumed to be 0.0. If `transform` is nil,
    /// `position` is returned as-is.
    ///
    /// **Dart Source:** `events.dart:580-587`
    public static func transformPosition(_ transform: Matrix4?, _ position: Offset) -> Offset {
        if transform == nil {
            return position
        }
        let position3 = Vector3(position.dx, position.dy, 0.0)
        let transformed3 = transform!.perspectiveTransform(position3)
        return Offset(transformed3.x, transformed3.y)
    }

    /// Transforms `untransformedDelta` into the coordinate system described by
    /// `transform`.
    ///
    /// It uses the provided `untransformedEndPosition` and
    /// `transformedEndPosition` of the provided delta to increase accuracy.
    ///
    /// If `transform` is nil, `untransformedDelta` is returned.
    ///
    /// **Dart Source:** `events.dart:596-616`
    public static func transformDeltaViaPositions(
        untransformedEndPosition: Offset,
        transformedEndPosition: Offset? = nil,
        untransformedDelta: Offset,
        transform: Matrix4?
    ) -> Offset {
        if transform == nil {
            return untransformedDelta
        }
        // We could transform the delta directly with the transformation matrix.
        // While that is mathematically equivalent, in practice we are seeing a
        // greater precision error with that approach. Instead, we are transforming
        // start and end point of the delta separately and calculate the delta in
        // the new space for greater accuracy.
        let resolvedTransformedEndPosition = transformedEndPosition
            ?? transformPosition(transform, untransformedEndPosition)
        let transformedStartPosition = transformPosition(
            transform,
            untransformedEndPosition - untransformedDelta
        )
        return resolvedTransformedEndPosition - transformedStartPosition
    }

    /// Removes the "perspective" component from `transform`.
    ///
    /// When applying the resulting transform matrix to a point with a
    /// z-coordinate of zero (which is generally assumed for all points
    /// represented by an `Offset`), the other coordinates will get transformed as
    /// before, but the new z-coordinate is going to be zero again. This is
    /// achieved by setting the third column and third row of the matrix to
    /// "0, 0, 1, 0".
    ///
    /// **Dart Source:** `events.dart:626-631`
    public static func removePerspectiveTransform(_ transform: Matrix4) -> Matrix4 {
        let vector = Vector4(0, 0, 1, 0)
        var result = transform
        result.setColumn(2, vector)
        result.setRow(2, vector)
        return result
    }

    // MARK: - Diagnosticable

    // TODO: Implement debugFillProperties for full diagnostics support.
    // The default implementation from the Diagnosticable protocol extension is used.
}
