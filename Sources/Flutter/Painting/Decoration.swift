// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A description of a box decoration (a decoration applied to a Rect).
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration.dart`

import FlutterSwiftBridge

// MARK: - Decoration

/// A description of a box decoration (a decoration applied to a `Rect`).
///
/// This protocol presents the abstract interface for all decorations.
/// See `BoxDecoration` for a concrete example.
///
/// To actually paint a `Decoration`, use the `createBoxPainter`
/// method to obtain a `BoxPainter`. `Decoration` objects can be
/// shared between boxes; `BoxPainter` objects can cache resources to
/// make painting on a particular surface faster.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration.dart`
/// **Original Name:** `Decoration`
/// **Lines:** 32-199
public protocol Decoration: Diagnosticable {
    /// Returns the insets to apply when using this decoration on a box
    /// that has contents, so that the contents do not overlap the edges
    /// of the decoration.
    ///
    /// **Dart Source:** `decoration.dart:69`
    var padding: any EdgeInsetsGeometry { get }

    /// Whether this decoration is complex enough to benefit from caching its painting.
    ///
    /// **Dart Source:** `decoration.dart:72`
    var isComplex: Bool { get }

    /// Linearly interpolates from another `Decoration` to `this`.
    ///
    /// When implementing this method in subclasses, return nil if this class
    /// cannot interpolate from `a`. In that case, `lerp` will try `a`'s `lerpTo`
    /// method instead.
    ///
    /// **Dart Source:** `decoration.dart:74-100`
    func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)?

    /// Linearly interpolates from `this` to another `Decoration`.
    ///
    /// This is called if `b`'s `lerpFrom` did not know how to handle this class.
    ///
    /// **Dart Source:** `decoration.dart:102-129`
    func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)?

    /// Tests whether the given point, on a rectangle of a given size,
    /// would be considered to hit the decoration or not.
    ///
    /// **Dart Source:** `decoration.dart:159-174`
    func hitTest(_ size: Size, _ position: Offset, textDirection: TextDirection?) -> Bool

    /// Returns a `BoxPainter` that will paint this decoration.
    ///
    /// **Dart Source:** `decoration.dart:176-182`
    func createBoxPainter(_ onChanged: VoidCallback?) -> BoxPainter

    /// Returns a closed `Path` that describes the outer edge of this decoration.
    ///
    /// **Dart Source:** `decoration.dart:184-198`
    func getClipPath(_ rect: Rect, _ textDirection: TextDirection) -> Path
}

// MARK: - Decoration Default Implementations

extension Decoration {
    /// **Dart Source:** `decoration.dart:39`
    public func toStringShort() -> String {
        objectRuntimeType(self, "Decoration")
    }

    /// In debug mode, throws an exception if the object is not in a
    /// valid configuration. Otherwise, returns true.
    ///
    /// **Dart Source:** `decoration.dart:41-48`
    public func debugAssertIsValid() -> Bool { true }

    /// **Dart Source:** `decoration.dart:69`
    public var padding: any EdgeInsetsGeometry { EdgeInsets.zero }

    /// **Dart Source:** `decoration.dart:72`
    public var isComplex: Bool { false }

    /// **Dart Source:** `decoration.dart:100`
    public func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)? { nil }

    /// **Dart Source:** `decoration.dart:129`
    public func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)? { nil }

    /// **Dart Source:** `decoration.dart:174`
    public func hitTest(_ size: Size, _ position: Offset, textDirection: TextDirection? = nil) -> Bool { true }

    /// **Dart Source:** `decoration.dart:194-198`
    public func getClipPath(_ rect: Rect, _ textDirection: TextDirection) -> Path {
        fatalError("\(objectRuntimeType(self, "This Decoration subclass")) does not expect to be used for clipping.")
    }
}

// MARK: - Decoration.lerp

/// Linearly interpolates between two `Decoration`s.
///
/// This attempts to use `lerpFrom` and `lerpTo` on `b` and `a`
/// respectively to find a solution. If the two values can't directly be
/// interpolated, then the interpolation is done via nil (at `t == 0.5`).
///
/// **Dart Source:** `decoration.dart:131-157`
public func lerpDecoration(_ a: (any Decoration)?, _ b: (any Decoration)?, _ t: Double) -> (any Decoration)? {
    if a === b {
        return a
    }
    if a == nil {
        return b!.lerpFrom(nil, t: t) ?? b
    }
    if b == nil {
        return a!.lerpTo(nil, t: t) ?? a
    }
    if t == 0.0 {
        return a
    }
    if t == 1.0 {
        return b
    }
    return b!.lerpFrom(a, t: t)
        ?? a!.lerpTo(b, t: t)
        ?? (t < 0.5 ? (a!.lerpTo(nil, t: t * 2.0) ?? a) : (b!.lerpFrom(nil, t: (t - 0.5) * 2.0) ?? b))
}

// MARK: - BoxPainter

/// A stateful class that can paint a particular `Decoration`.
///
/// `BoxPainter` objects can cache resources so that they can be used
/// multiple times.
///
/// Some resources used by `BoxPainter` may load asynchronously. When this
/// happens, the `onChanged` callback will be invoked. To stop this callback
/// from being called after the painter has been discarded, call `dispose`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/decoration.dart`
/// **Original Name:** `BoxPainter`
/// **Lines:** 209-256
open class BoxPainter {
    /// Callback that is invoked if an asynchronously-loading resource used by the
    /// decoration finishes loading.
    ///
    /// **Dart Source:** `decoration.dart:242-248`
    public let onChanged: VoidCallback?

    /// Creates a box painter.
    ///
    /// **Dart Source:** `decoration.dart:212`
    public init(onChanged: VoidCallback? = nil) {
        self.onChanged = onChanged
    }

    /// Paints the `Decoration` for which this object was created on the
    /// given canvas using the given configuration.
    ///
    /// **Dart Source:** `decoration.dart:214-240`
    open func paint(_ canvas: Canvas, _ offset: Offset, _ configuration: ImageConfiguration) {
        fatalError("Subclasses must implement paint()")
    }

    /// Discard any resources being held by the object.
    ///
    /// The `onChanged` callback will not be invoked after this method has been
    /// called.
    ///
    /// **Dart Source:** `decoration.dart:250-255`
    open func dispose() {
        // Base implementation does nothing
    }
}
