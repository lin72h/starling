// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Swift implementation of Flutter's pointer.dart
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart`
///
/// This file provides the Swift implementation of pointer event types
/// and data structures for pointer input handling.
/// Pure Swift data structures (no C++ bridge needed).

// MARK: - PointerChange

/// How the pointer has changed since the last report.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:7-52`
/// **Original Name:** `PointerChange`
public enum PointerChange {
  /// The input from the pointer is no longer directed towards this receiver.
  ///
  /// **Dart Source:** `pointer.dart:9-10`
  case cancel

  /// The device has started tracking the pointer.
  ///
  /// For example, the pointer might be hovering above the device, having not yet
  /// made contact with the surface of the device.
  ///
  /// **Dart Source:** `pointer.dart:12-16`
  case add

  /// The device is no longer tracking the pointer.
  ///
  /// For example, the pointer might have drifted out of the device's hover
  /// detection range or might have been disconnected from the system entirely.
  ///
  /// **Dart Source:** `pointer.dart:18-22`
  case remove

  /// The pointer has moved with respect to the device while not in contact with
  /// the device.
  ///
  /// **Dart Source:** `pointer.dart:24-26`
  case hover

  /// The pointer has made contact with the device.
  ///
  /// **Dart Source:** `pointer.dart:28-29`
  case down

  /// The pointer has moved with respect to the device while in contact with the
  /// device.
  ///
  /// **Dart Source:** `pointer.dart:31-33`
  case move

  /// The pointer has stopped making contact with the device.
  ///
  /// **Dart Source:** `pointer.dart:35-36`
  case up

  /// A pan/zoom has started on this pointer.
  ///
  /// This type of event will always have kind `PointerDeviceKind.trackpad`.
  ///
  /// **Dart Source:** `pointer.dart:38-41`
  case panZoomStart

  /// The pan/zoom on this pointer has updated.
  ///
  /// This type of event will always have kind `PointerDeviceKind.trackpad`.
  ///
  /// **Dart Source:** `pointer.dart:43-46`
  case panZoomUpdate

  /// The pan/zoom on this pointer has ended.
  ///
  /// This type of event will always have kind `PointerDeviceKind.trackpad`.
  ///
  /// **Dart Source:** `pointer.dart:48-51`
  case panZoomEnd
}

// MARK: - PointerDeviceKind

/// The kind of pointer device.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:54-120`
/// **Original Name:** `PointerDeviceKind`
public enum PointerDeviceKind {
  /// A touch-based pointer device.
  ///
  /// The most common case is a touch screen.
  ///
  /// When the user is operating with a trackpad on iOS, clicking will also
  /// dispatch events with kind `touch` if
  /// `UIApplicationSupportsIndirectInputEvents` is not present in `Info.plist`
  /// or returns NO.
  ///
  /// See also:
  ///
  ///  * [UIApplicationSupportsIndirectInputEvents](https://developer.apple.com/documentation/bundleresources/information_property_list/uiapplicationsupportsindirectinputevents?language=objc).
  ///
  /// **Dart Source:** `pointer.dart:56-68`
  case touch

  /// A mouse-based pointer device.
  ///
  /// The most common case is a mouse on the desktop or Web.
  ///
  /// When the user is operating with a trackpad on iOS, moving the pointing
  /// cursor will also dispatch events with kind `mouse`, and clicking will
  /// dispatch events with kind `mouse` if
  /// `UIApplicationSupportsIndirectInputEvents` is not present in `Info.plist`
  /// or returns NO.
  ///
  /// See also:
  ///
  ///  * [UIApplicationSupportsIndirectInputEvents](https://developer.apple.com/documentation/bundleresources/information_property_list/uiapplicationsupportsindirectinputevents?language=objc).
  ///
  /// **Dart Source:** `pointer.dart:70-83`
  case mouse

  /// A pointer device with a stylus.
  ///
  /// **Dart Source:** `pointer.dart:85-86`
  case stylus

  /// A pointer device with a stylus that has been inverted.
  ///
  /// **Dart Source:** `pointer.dart:88-89`
  case invertedStylus

  /// Gestures from a trackpad.
  ///
  /// A trackpad here is defined as a touch-based pointer device with an
  /// indirect surface (the user operates the screen by touching something that
  /// is not the screen).
  ///
  /// When the user makes zoom, pan, scroll or rotate gestures with a physical
  /// trackpad, supporting platforms dispatch events with kind `trackpad`.
  ///
  /// Events with kind `trackpad` can only have a `PointerChange` of `add`,
  /// `remove`, and pan-zoom related values.
  ///
  /// Some platforms don't support (or don't fully support) trackpad
  /// gestures, and might convert trackpad gestures into fake pointer events
  /// that simulate dragging. These events typically have kind `touch` or
  /// `mouse` instead of `trackpad`. This includes (but is not limited to) Web,
  /// and iOS when `UIApplicationSupportsIndirectInputEvents` isn't present in
  /// `Info.plist` or returns NO.
  ///
  /// Moving the pointing cursor or clicking with a trackpad typically triggers
  /// `touch` or `mouse` events, but never triggers `trackpad` events.
  ///
  /// See also:
  ///
  ///  * [UIApplicationSupportsIndirectInputEvents](https://developer.apple.com/documentation/bundleresources/information_property_list/uiapplicationsupportsindirectinputevents?language=objc).
  ///
  /// **Dart Source:** `pointer.dart:91-116`
  case trackpad

  /// An unknown pointer device.
  ///
  /// **Dart Source:** `pointer.dart:118-119`
  case unknown
}

// MARK: - PointerSignalKind

/// The kind of pointer signal event.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:122-138`
/// **Original Name:** `PointerSignalKind`
public enum PointerSignalKind {
  /// The event is not associated with a pointer signal.
  ///
  /// **Dart Source:** `pointer.dart:124-125`
  case none

  /// A pointer-generated scroll (e.g., mouse wheel or trackpad scroll).
  ///
  /// **Dart Source:** `pointer.dart:127-128`
  case scroll

  /// A pointer-generated scroll-inertia cancel.
  ///
  /// **Dart Source:** `pointer.dart:130-131`
  case scrollInertiaCancel

  /// A pointer-generated scale event (e.g. trackpad pinch).
  ///
  /// **Dart Source:** `pointer.dart:133-134`
  case scale

  /// An unknown pointer signal kind.
  ///
  /// **Dart Source:** `pointer.dart:136-137`
  case unknown
}

// MARK: - PointerDataRespondCallback

/// A function that implements the `PointerData.respond` method.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:140-141`
/// **Original:** `typedef PointerDataRespondCallback = void Function({bool allowPlatformDefault});`
///
/// DIFFERENCE FROM DART: Swift closures cannot have named parameters like Dart's
/// `{bool allowPlatformDefault}`. Instead, this uses a labeled parameter `_ allowPlatformDefault:`.
/// Callers must pass the argument positionally rather than by name.
/// REASON: Swift language limitation - closure types don't support argument labels.
public typealias PointerDataRespondCallback = (_ allowPlatformDefault: Bool) -> Void

// MARK: - PointerData

/// Information about the state of a pointer.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:143-460`
/// **Original Name:** `PointerData`
///
/// DIFFERENCE FROM DART: Uses Swift `struct` instead of Dart `class`.
/// REASON: PointerData is an immutable value type; Swift structs provide
/// value semantics which is more appropriate than reference semantics.
///
/// DIFFERENCE FROM DART: Uses Swift's built-in `Duration` instead of Dart's `Duration`.
/// REASON: Swift's Duration type (available since Swift 5.7) provides equivalent
/// functionality. Dart's Duration stores microseconds internally; Swift's Duration
/// supports the same precision.
public struct PointerData {
  /// The ID of the `FlutterView` this pointer event originated from.
  ///
  /// **Dart Source:** `pointer.dart:186-187`
  public let viewId: Int64

  /// Unique identifier that ties the pointer event to the embedder event that created it.
  ///
  /// No two pointer events can have the same `embedderId`. This is different
  /// from `pointerIdentifier` - used for hit-testing, whereas `embedderId` is
  /// used to identify the platform event.
  ///
  /// **Dart Source:** `pointer.dart:189-196`
  public let embedderId: Int64

  /// Time of event dispatch, relative to an arbitrary timeline.
  ///
  /// **Dart Source:** `pointer.dart:198-199`
  public let timeStamp: Duration

  /// How the pointer has changed since the last report.
  ///
  /// **Dart Source:** `pointer.dart:201-202`
  public let change: PointerChange

  /// The kind of input device for which the event was generated.
  ///
  /// **Dart Source:** `pointer.dart:204-205`
  public let kind: PointerDeviceKind

  /// The kind of signal for a pointer signal event.
  ///
  /// **Dart Source:** `pointer.dart:207-208`
  public let signalKind: PointerSignalKind?

  /// Unique identifier for the pointing device, reused across interactions.
  ///
  /// **Dart Source:** `pointer.dart:210-211`
  public let device: Int64

  /// Unique identifier for the pointer.
  ///
  /// This field changes for each new pointer down event. Framework uses this
  /// identifier to determine hit test result.
  ///
  /// **Dart Source:** `pointer.dart:213-217`
  public let pointerIdentifier: Int64

  /// X coordinate of the position of the pointer, in physical pixels in the
  /// global coordinate space.
  ///
  /// **Dart Source:** `pointer.dart:219-221`
  public let physicalX: Double

  /// Y coordinate of the position of the pointer, in physical pixels in the
  /// global coordinate space.
  ///
  /// **Dart Source:** `pointer.dart:223-225`
  public let physicalY: Double

  /// The distance of pointer movement on X coordinate in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:227-228`
  public let physicalDeltaX: Double

  /// The distance of pointer movement on Y coordinate in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:230-231`
  public let physicalDeltaY: Double

  /// Bit field using the *Button constants (primaryMouseButton,
  /// secondaryStylusButton, etc). For example, if this has the value 6 and the
  /// `kind` is `PointerDeviceKind.invertedStylus`, then this indicates an
  /// upside-down stylus with both its primary and secondary buttons pressed.
  ///
  /// **Dart Source:** `pointer.dart:233-237`
  public let buttons: Int64

  /// Set if an application from a different security domain is in any way
  /// obscuring this application's window. (Aspirational; not currently
  /// implemented.)
  ///
  /// **Dart Source:** `pointer.dart:239-242`
  public let obscured: Bool

  /// Set if this pointer data was synthesized by pointer data packet converter.
  /// pointer data packet converter will synthesize additional pointer datas if
  /// the input sequence of pointer data is illegal.
  ///
  /// For example, a down pointer data will be synthesized if the converter receives
  /// a move pointer data while the pointer is not previously down.
  ///
  /// **Dart Source:** `pointer.dart:244-250`
  public let synthesized: Bool

  /// The pressure of the touch as a number ranging from 0.0, indicating a touch
  /// with no discernible pressure, to 1.0, indicating a touch with "normal"
  /// pressure, and possibly beyond, indicating a stronger touch. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0.
  ///
  /// **Dart Source:** `pointer.dart:252-256`
  public let pressure: Double

  /// The minimum value that `pressure` can return for this pointer. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0. This will always be
  /// a number less than or equal to 1.0.
  ///
  /// **Dart Source:** `pointer.dart:258-261`
  public let pressureMin: Double

  /// The maximum value that `pressure` can return for this pointer. For devices
  /// that do not detect pressure (e.g. mice), returns 1.0. This will always be
  /// a greater than or equal to 1.0.
  ///
  /// **Dart Source:** `pointer.dart:263-266`
  public let pressureMax: Double

  /// The distance of the detected object from the input surface (e.g. the
  /// distance of a stylus or finger from a touch screen), in arbitrary units on
  /// an arbitrary (not necessarily linear) scale. If the pointer is down, this
  /// is 0.0 by definition.
  ///
  /// **Dart Source:** `pointer.dart:268-272`
  public let distance: Double

  /// The maximum value that a distance can return for this pointer. If this
  /// input device cannot detect "hover touch" input events, then this will be
  /// 0.0.
  ///
  /// **Dart Source:** `pointer.dart:274-277`
  public let distanceMax: Double

  /// The area of the screen being pressed, scaled to a value between 0 and 1.
  /// The value of size can be used to determine fat touch events. This value
  /// is only set on Android, and is a device specific approximation within
  /// the range of detectable values. So, for example, the value of 0.1 could
  /// mean a touch with the tip of the finger, 0.2 a touch with full finger,
  /// and 0.3 the full palm.
  ///
  /// **Dart Source:** `pointer.dart:279-285`
  public let size: Double

  /// The radius of the contact ellipse along the major axis, in logical pixels.
  ///
  /// **Dart Source:** `pointer.dart:287-288`
  public let radiusMajor: Double

  /// The radius of the contact ellipse along the minor axis, in logical pixels.
  ///
  /// **Dart Source:** `pointer.dart:290-291`
  public let radiusMinor: Double

  /// The minimum value that could be reported for radiusMajor and radiusMinor
  /// for this pointer, in logical pixels.
  ///
  /// **Dart Source:** `pointer.dart:293-295`
  public let radiusMin: Double

  /// The minimum value that could be reported for radiusMajor and radiusMinor
  /// for this pointer, in logical pixels.
  ///
  /// **Dart Source:** `pointer.dart:297-299`
  public let radiusMax: Double

  /// For PointerDeviceKind.touch events:
  ///
  /// The angle of the contact ellipse, in radius in the range:
  ///
  ///    -pi/2 < orientation <= pi/2
  ///
  /// ...giving the angle of the major axis of the ellipse with the y-axis
  /// (negative angles indicating an orientation along the top-left /
  /// bottom-right diagonal, positive angles indicating an orientation along the
  /// top-right / bottom-left diagonal, and zero indicating an orientation
  /// parallel with the y-axis).
  ///
  /// For PointerDeviceKind.stylus and PointerDeviceKind.invertedStylus events:
  ///
  /// The angle of the stylus, in radians in the range:
  ///
  ///    -pi < orientation <= pi
  ///
  /// ...giving the angle of the axis of the stylus projected onto the input
  /// surface, relative to the positive y-axis of that surface (thus 0.0
  /// indicates the stylus, if projected onto that surface, would go from the
  /// contact point vertically up in the positive y-axis direction, pi would
  /// indicate that the stylus would go down in the negative y-axis direction;
  /// pi/4 would indicate that the stylus goes up and to the right, -pi/2 would
  /// indicate that the stylus goes to the left, etc).
  ///
  /// **Dart Source:** `pointer.dart:301-326`
  public let orientation: Double

  /// For PointerDeviceKind.stylus and PointerDeviceKind.invertedStylus events:
  ///
  /// The angle of the stylus, in radians in the range:
  ///
  ///    0 <= tilt <= pi/2
  ///
  /// ...giving the angle of the axis of the stylus, relative to the axis
  /// perpendicular to the input surface (thus 0.0 indicates the stylus is
  /// orthogonal to the plane of the input surface, while pi/2 indicates that
  /// the stylus is flat on that surface).
  ///
  /// **Dart Source:** `pointer.dart:328-338`
  public let tilt: Double

  /// Opaque platform-specific data associated with the event.
  ///
  /// **Dart Source:** `pointer.dart:340-341`
  public let platformData: Int64

  /// For events with signalKind of PointerSignalKind.scroll:
  ///
  /// The amount to scroll in the x direction, in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:343-346`
  public let scrollDeltaX: Double

  /// For events with signalKind of PointerSignalKind.scroll:
  ///
  /// The amount to scroll in the y direction, in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:348-351`
  public let scrollDeltaY: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The current panning magnitude of the pan/zoom in the x direction, in
  /// physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:353-357`
  public let panX: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The current panning magnitude of the pan/zoom in the y direction, in
  /// physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:359-363`
  public let panY: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The difference in panning of the pan/zoom in the x direction since the
  /// latest panZoomUpdate event, in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:365-369`
  public let panDeltaX: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The difference in panning of the pan/zoom in the y direction since the
  /// last panZoomUpdate event, in physical pixels.
  ///
  /// **Dart Source:** `pointer.dart:371-375`
  public let panDeltaY: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The current scale of the pan/zoom (unitless), with 1.0 as the initial scale.
  ///
  /// **Dart Source:** `pointer.dart:377-380`
  public let scale: Double

  /// For events with change of PointerChange.panZoomUpdate:
  ///
  /// The current angle of the pan/zoom in radians, with 0.0 as the initial angle.
  ///
  /// **Dart Source:** `pointer.dart:382-385`
  public let rotation: Double

  /// An optional function that allows the framework to respond to the event
  /// that triggered this PointerData instance.
  ///
  /// **Dart Source:** `pointer.dart:387-389`
  private let _onRespond: PointerDataRespondCallback?

  /// Creates an object that represents the state of a pointer.
  ///
  /// **Dart Source:** `pointer.dart:145-184`
  /// **Original:** `const PointerData({...})`
  public init(
    viewId: Int64 = 0,
    embedderId: Int64 = 0,
    timeStamp: Duration = .zero,
    change: PointerChange = .cancel,
    kind: PointerDeviceKind = .touch,
    signalKind: PointerSignalKind? = nil,
    device: Int64 = 0,
    pointerIdentifier: Int64 = 0,
    physicalX: Double = 0.0,
    physicalY: Double = 0.0,
    physicalDeltaX: Double = 0.0,
    physicalDeltaY: Double = 0.0,
    buttons: Int64 = 0,
    obscured: Bool = false,
    synthesized: Bool = false,
    pressure: Double = 0.0,
    pressureMin: Double = 0.0,
    pressureMax: Double = 0.0,
    distance: Double = 0.0,
    distanceMax: Double = 0.0,
    size: Double = 0.0,
    radiusMajor: Double = 0.0,
    radiusMinor: Double = 0.0,
    radiusMin: Double = 0.0,
    radiusMax: Double = 0.0,
    orientation: Double = 0.0,
    tilt: Double = 0.0,
    platformData: Int64 = 0,
    scrollDeltaX: Double = 0.0,
    scrollDeltaY: Double = 0.0,
    panX: Double = 0.0,
    panY: Double = 0.0,
    panDeltaX: Double = 0.0,
    panDeltaY: Double = 0.0,
    scale: Double = 0.0,
    rotation: Double = 0.0,
    onRespond: PointerDataRespondCallback? = nil
  ) {
    self.viewId = viewId
    self.embedderId = embedderId
    self.timeStamp = timeStamp
    self.change = change
    self.kind = kind
    self.signalKind = signalKind
    self.device = device
    self.pointerIdentifier = pointerIdentifier
    self.physicalX = physicalX
    self.physicalY = physicalY
    self.physicalDeltaX = physicalDeltaX
    self.physicalDeltaY = physicalDeltaY
    self.buttons = buttons
    self.obscured = obscured
    self.synthesized = synthesized
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
    self.scrollDeltaX = scrollDeltaX
    self.scrollDeltaY = scrollDeltaY
    self.panX = panX
    self.panY = panY
    self.panDeltaX = panDeltaX
    self.panDeltaY = panDeltaY
    self.scale = scale
    self.rotation = rotation
    self._onRespond = onRespond
  }

  /// Method that the framework/app can call to respond to the native event
  /// that triggered this `PointerData`.
  ///
  /// The parameter `allowPlatformDefault` allows the platform to perform the
  /// default action associated with the native event when it's set to `true`.
  ///
  /// This method can be called any number of times, but once `allowPlatformDefault`
  /// is set to `true`, it can't be set to `false` again.
  ///
  /// If `allowPlatformDefault` is never set to `true`, the Flutter engine will
  /// consume the event, so it won't be seen by the platform. In the web, this
  /// means that `preventDefault` will be called in the DOM event that triggered
  /// the `PointerData`. See [Event: preventDefault() method in MDN][EpDmiMDN].
  ///
  /// The implementation of this method is configured through the `onRespond`
  /// parameter of the `PointerData` constructor.
  ///
  /// See also `PointerDataRespondCallback`.
  ///
  /// [EpDmiMDN]: https://developer.mozilla.org/en-US/docs/Web/API/Event/preventDefault
  ///
  /// **Dart Source:** `pointer.dart:391-415`
  /// **Original:** `void respond({required bool allowPlatformDefault})`
  public func respond(allowPlatformDefault: Bool) {
    _onRespond?(allowPlatformDefault)
  }

  /// Returns a brief textual description of this object.
  ///
  /// **Dart Source:** `pointer.dart:417-418`
  /// **Original:** `String toString() => 'PointerData(viewId: $viewId, x: $physicalX, y: $physicalY)';`
  public var description: String {
    "PointerData(viewId: \(viewId), x: \(physicalX), y: \(physicalY))"
  }

  /// Returns a complete textual description of the information in this object.
  ///
  /// **Dart Source:** `pointer.dart:420-459`
  /// **Original:** `String toStringFull()`
  public func toStringFull() -> String {
    "PointerData("
    + "embedderId: \(embedderId), "
    + "timeStamp: \(timeStamp), "
    + "change: \(change), "
    + "kind: \(kind), "
    + "signalKind: \(String(describing: signalKind)), "
    + "device: \(device), "
    + "pointerIdentifier: \(pointerIdentifier), "
    + "physicalX: \(physicalX), "
    + "physicalY: \(physicalY), "
    + "physicalDeltaX: \(physicalDeltaX), "
    + "physicalDeltaY: \(physicalDeltaY), "
    + "buttons: \(buttons), "
    + "synthesized: \(synthesized), "
    + "pressure: \(pressure), "
    + "pressureMin: \(pressureMin), "
    + "pressureMax: \(pressureMax), "
    + "distance: \(distance), "
    + "distanceMax: \(distanceMax), "
    + "size: \(size), "
    + "radiusMajor: \(radiusMajor), "
    + "radiusMinor: \(radiusMinor), "
    + "radiusMin: \(radiusMin), "
    + "radiusMax: \(radiusMax), "
    + "orientation: \(orientation), "
    + "tilt: \(tilt), "
    + "platformData: \(platformData), "
    + "scrollDeltaX: \(scrollDeltaX), "
    + "scrollDeltaY: \(scrollDeltaY), "
    + "panX: \(panX), "
    + "panY: \(panY), "
    + "panDeltaX: \(panDeltaX), "
    + "panDeltaY: \(panDeltaY), "
    + "scale: \(scale), "
    + "rotation: \(rotation), "
    + "viewId: \(viewId)"
    + ")"
  }
}

// MARK: - PointerDataPacket

/// A sequence of reports about the state of pointers.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/pointer.dart:462-471`
/// **Original Name:** `PointerDataPacket`
///
/// DIFFERENCE FROM DART: Uses Swift `struct` instead of Dart `class`.
/// REASON: PointerDataPacket is an immutable value type; Swift structs provide
/// value semantics which is more appropriate than reference semantics.
public struct PointerDataPacket {
  /// Data about the individual pointers in this packet.
  ///
  /// This list might contain multiple pieces of data about the same pointer.
  ///
  /// **Dart Source:** `pointer.dart:467-470`
  /// **Original:** `final List<PointerData> data;`
  public let data: [PointerData]

  /// Creates a packet of pointer data reports.
  ///
  /// **Dart Source:** `pointer.dart:464-465`
  /// **Original:** `const PointerDataPacket({this.data = const <PointerData>[]});`
  public init(data: [PointerData] = []) {
    self.data = data
  }
}
