// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import FlutterSwiftBridge

// MARK: - Paint Utilities

/// Draw a line between two points, which cuts diagonally back and forth across
/// the line that connects the two points.
///
/// The line will cross the line `zigs - 1` times.
///
/// If `zigs` is 1, then this will draw two sides of a triangle from `start` to
/// `end`, with the third point being `width` away from the line, as measured
/// perpendicular to that line.
///
/// If `width` is positive, the first `zig` will be to the left of the `start`
/// point when facing the `end` point. To reverse the zigging polarity, provide
/// a negative `width`.
///
/// The line is drawn using the provided `paint` on the provided `canvas`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/paint_utilities.dart:9-41`
/// **Original Name:** `paintZigZag`
public func paintZigZag(
    _ canvas: Canvas,
    paint: Paint,
    start: Offset,
    end: Offset,
    zigs: Int,
    width: Double
) {
    // Note: Dart asserts zigs.isFinite, but Int is always finite in Swift
    // **Dart Source:** `paint_utilities.dart:24-25`
    assert(zigs > 0, "zigs must be greater than 0")

    // **Dart Source:** `paint_utilities.dart:26`
    canvas.save()

    // **Dart Source:** `paint_utilities.dart:27`
    canvas.translate(start.dx, start.dy)

    // **Dart Source:** `paint_utilities.dart:28`
    let relativeEnd = end - start

    // **Dart Source:** `paint_utilities.dart:29`
    canvas.rotate(atan2(relativeEnd.dy, relativeEnd.dx))

    // **Dart Source:** `paint_utilities.dart:30-31`
    let length = relativeEnd.distance
    let spacing = length / (Double(zigs) * 2.0)

    // **Dart Source:** `paint_utilities.dart:32`
    let path = Path()
    path.moveTo(0.0, 0.0)

    // **Dart Source:** `paint_utilities.dart:33-37`
    for index in 0..<zigs {
        let x = (Double(index) * 2.0 + 1.0) * spacing
        let y = width * (Double(index % 2) * 2.0 - 1.0)
        path.lineTo(x, y)
    }

    // **Dart Source:** `paint_utilities.dart:38`
    path.lineTo(length, 0.0)

    // **Dart Source:** `paint_utilities.dart:39-40`
    canvas.drawPath(path, paint)
    canvas.restore()
}
