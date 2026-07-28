// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shapes with notches in their outlines, typically used for accommodating
/// a FloatingActionButton in a BottomAppBar.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/notched_shapes.dart`

import Foundation
import FlutterSwiftBridge

// MARK: - NotchedShape

/// A shape with a notch in its outline.
///
/// Typically used as the outline of a 'host' widget to make a notch that
/// accommodates a 'guest' widget. e.g the `BottomAppBar` may have a notch to
/// accommodate the `FloatingActionButton`.
///
/// See also:
///
///  * `ShapeBorder`, which defines a shaped border without a dynamic notch.
///  * `AutomaticNotchedShape`, an adapter from `ShapeBorder` to `NotchedShape`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/notched_shapes.dart`
/// **Lines:** 23-35
public protocol NotchedShape {
    /// Creates a `Path` that describes the outline of the shape.
    ///
    /// The `host` is the bounding rectangle of the shape.
    ///
    /// The `guest` is the bounding rectangle of the shape for which a notch will
    /// be made. It is nil when there is no guest.
    ///
    /// **Dart Source:** `notched_shapes.dart:28-34`
    func getOuterPath(host: Rect, guest: Rect?) -> Path
}

// MARK: - CircularNotchedRectangle

/// A rectangle with a smooth circular notch.
///
/// See also:
///
///  * `CircleBorder`, a `ShapeBorder` that describes a circle.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/notched_shapes.dart`
/// **Lines:** 42-142
public struct CircularNotchedRectangle: NotchedShape {

    /// Creates a `CircularNotchedRectangle`.
    ///
    /// The same object can be used to create multiple shapes.
    ///
    /// **Dart Source:** `notched_shapes.dart:43-46`
    public init(inverted: Bool = false) {
        self.inverted = inverted
    }

    /// If `inverted` is true, the notch is placed at the bottom of the
    /// rectangle.
    ///
    /// **Dart Source:** `notched_shapes.dart:48-50`
    public let inverted: Bool

    /// Creates a `Path` that describes a rectangle with a smooth circular notch.
    ///
    /// `host` is the bounding box for the returned shape. Conceptually this is
    /// the rectangle to which the notch will be applied.
    ///
    /// `guest` is the bounding box of a circle that the notch accommodates. All
    /// points in the circle bounded by `guest` will be outside of the returned
    /// path.
    ///
    /// The notch is a curve that smoothly connects the host's top edge and
    /// the guest circle.
    ///
    /// **Dart Source:** `notched_shapes.dart:52-141`
    public func getOuterPath(host: Rect, guest: Rect?) -> Path {
        // notched_shapes.dart:65-68
        if guest == nil || !host.overlaps(guest!) {
            let path = Path()
            path.addRect(host)
            return path
        }

        let guest = guest!

        // The guest's shape is a circle bounded by the guest rectangle.
        // So the guest's radius is half the guest width.
        // notched_shapes.dart:72
        let r = guest.width / 2.0
        let notchRadius = Radius(circular: r)

        // The variables p2yA and p2yB need to be inverted
        // when the notch is drawn on the bottom of a path.
        // notched_shapes.dart:77
        let invertMultiplier: Double = inverted ? -1.0 : 1.0

        // We build a path for the notch from 3 segments:
        // Segment A - a Bezier curve from the host's top edge to segment B.
        // Segment B - an arc with radius notchRadius.
        // Segment C - a Bezier curve from segment B back to the host's top edge.
        //
        // A detailed explanation and the derivation of the formulas below is
        // available at: https://docs.google.com/document/d/e/2PACX-1vRVPWGtR85bawGynRSWzYTKgQtqrxCnxXCKC5xM9ab3IvtRHueku4rRIuJ4TbedzyMz2oy2pkzM71-_/pub

        // notched_shapes.dart:87-88
        let s1 = 15.0
        let s2 = 1.0

        // notched_shapes.dart:90-91
        let a = -r - s2
        let b = (inverted ? host.bottom : host.top) - guest.center.dy

        // notched_shapes.dart:93-97
        let n2 = sqrt(b * b * r * r * (a * a + b * b - r * r))
        let p2xA = ((a * r * r) - n2) / (a * a + b * b)
        let p2xB = ((a * r * r) + n2) / (a * a + b * b)
        let p2yA = sqrt(r * r - p2xA * p2xA) * invertMultiplier
        let p2yB = sqrt(r * r - p2xB * p2xB) * invertMultiplier

        // notched_shapes.dart:99
        var p = [Offset](repeating: Offset.zero, count: 6)

        // p0, p1, and p2 are the control points for segment A.
        // notched_shapes.dart:102-105
        p[0] = Offset(a - s1, b)
        p[1] = Offset(a, b)
        let cmp: Double = b < 0 ? -1.0 : 1.0
        p[2] = cmp * p2yA > cmp * p2yB ? Offset(p2xA, p2yA) : Offset(p2xB, p2yB)

        // p3, p4, and p5 are the control points for segment B, which is a mirror
        // of segment A around the y axis.
        // notched_shapes.dart:109-111
        p[3] = Offset(-1.0 * p[2].dx, p[2].dy)
        p[4] = Offset(-1.0 * p[1].dx, p[1].dy)
        p[5] = Offset(-1.0 * p[0].dx, p[0].dy)

        // Translate all points back to the absolute coordinate system.
        // notched_shapes.dart:114-116
        for i in 0..<p.count {
            p[i] = p[i] + guest.center
        }

        // Use the calculated points to draw out a path object.
        // notched_shapes.dart:119-138
        let path = Path()
        path.moveTo(host.left, host.top)
        if !inverted {
            path.lineTo(p[0].dx, p[0].dy)
            path.quadraticBezierTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy)
            path.arcToPoint(
                Offset(p[3].dx, p[3].dy),
                radius: notchRadius,
                clockwise: false
            )
            path.quadraticBezierTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy)
            path.lineTo(host.right, host.top)
            path.lineTo(host.right, host.bottom)
            path.lineTo(host.left, host.bottom)
        } else {
            path.lineTo(host.right, host.top)
            path.lineTo(host.right, host.bottom)
            path.lineTo(p[5].dx, p[5].dy)
            path.quadraticBezierTo(p[4].dx, p[4].dy, p[3].dx, p[3].dy)
            path.arcToPoint(
                Offset(p[2].dx, p[2].dy),
                radius: notchRadius,
                clockwise: false
            )
            path.quadraticBezierTo(p[1].dx, p[1].dy, p[0].dx, p[0].dy)
            path.lineTo(host.left, host.bottom)
        }

        // notched_shapes.dart:140
        path.close()
        return path
    }
}

// MARK: - AutomaticNotchedShape

/// A `NotchedShape` created from `ShapeBorder`s.
///
/// Two shapes can be provided. The `host` is the shape of the widget that
/// uses the `NotchedShape` (typically a `BottomAppBar`). The `guest` is
/// subtracted from the `host` to create the notch (typically to make room
/// for a `FloatingActionButton`).
///
/// **Dart Source:** `packages/flutter/lib/src/painting/notched_shapes.dart`
/// **Lines:** 150-181
public struct AutomaticNotchedShape: NotchedShape {

    /// Creates a `NotchedShape` that is defined by two `ShapeBorder`s.
    ///
    /// The `guest` may be nil, in which case no notch is created even
    /// if a guest rectangle is provided to `getOuterPath`.
    ///
    /// **Dart Source:** `notched_shapes.dart:150-155`
    public init(host: any ShapeBorder, guest: (any ShapeBorder)? = nil) {
        self.host = host
        self.guest = guest
    }

    /// The shape of the widget that uses the `NotchedShape` (typically a
    /// `BottomAppBar`).
    ///
    /// This shape cannot depend on the `TextDirection`, as no text direction
    /// is available to `NotchedShape`s.
    ///
    /// **Dart Source:** `notched_shapes.dart:157-162`
    public let host: any ShapeBorder

    /// The shape to subtract from the `host` to make the notch.
    ///
    /// This shape cannot depend on the `TextDirection`, as no text direction
    /// is available to `NotchedShape`s.
    ///
    /// If this is nil, `getOuterPath` ignores the guest rectangle.
    ///
    /// **Dart Source:** `notched_shapes.dart:164-170`
    public let guest: (any ShapeBorder)?

    /// **Dart Source:** `notched_shapes.dart:172-180`
    public func getOuterPath(host hostRect: Rect, guest guestRect: Rect?) -> Path {
        // notched_shapes.dart:174
        let hostPath = host.getOuterPath(hostRect, textDirection: nil)
        // notched_shapes.dart:175-177
        if let guest = guest, let guestRect = guestRect {
            let guestPath = guest.getOuterPath(guestRect, textDirection: nil)
            return Path.combine(.difference, hostPath, guestPath)
        }
        // notched_shapes.dart:179
        return hostPath
    }
}
