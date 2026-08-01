// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Interface for objects that receive updates about drags.
///
/// This protocol is used in various ways. For example,
/// `MultiDragGestureRecognizer` uses it to update its clients when it
/// recognizes a gesture. Similarly, the scrolling infrastructure in the widgets
/// library uses it to notify the `DragScrollActivity` when the user drags the
/// scrollable.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/drag.dart`

import FlutterSwiftBridge

// MARK: - Drag

/// Interface for objects that receive updates about drags.
///
/// This protocol is used in various ways. For example,
/// `MultiDragGestureRecognizer` uses it to update its clients when it
/// recognizes a gesture. Similarly, the scrolling infrastructure in the widgets
/// library uses it to notify the `DragScrollActivity` when the user drags the
/// scrollable.
///
/// **Dart Source:** `drag.dart:21-36`
///
/// DIFFERENCE FROM DART: In Dart, `Drag` is an abstract class with empty
/// method bodies providing default no-op implementations. In Swift, this is
/// modeled as a protocol with a default extension providing the same empty
/// implementations.
/// REASON: Swift protocols with default extensions are the idiomatic
/// equivalent of Dart abstract classes with default method bodies.
public protocol Drag: AnyObject {

    /// The pointer has moved.
    ///
    /// **Dart Source:** `drag.dart:23`
    func update(_ details: DragUpdateDetails)

    /// The pointer is no longer in contact with the screen.
    ///
    /// The velocity at which the pointer was moving when it stopped contacting
    /// the screen is available in the `details`.
    ///
    /// **Dart Source:** `drag.dart:29`
    func end(_ details: DragEndDetails)

    /// The input from the pointer is no longer directed towards this receiver.
    ///
    /// For example, the user might have been interrupted by a system-modal dialog
    /// in the middle of the drag.
    ///
    /// **Dart Source:** `drag.dart:35`
    func cancel()
}

// MARK: - Default Implementations

/// Default (no-op) implementations for the ``Drag`` protocol.
///
/// These match the empty method bodies in the Dart `Drag` abstract class,
/// allowing conforming types to override only the methods they need.
///
/// **Dart Source:** `drag.dart:23, 29, 35`
public extension Drag {

    /// Default no-op implementation for ``update(_:)``.
    func update(_ details: DragUpdateDetails) {}

    /// Default no-op implementation for ``end(_:)``.
    func end(_ details: DragEndDetails) {}

    /// Default no-op implementation for ``cancel()``.
    func cancel() {}
}
