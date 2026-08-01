// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Clip utilities used by `PaintingContext`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/clip.dart`

import FlutterSwiftBridge

// MARK: - ClipContext

/// Clip utilities used by `PaintingContext`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/clip.dart`
/// **Original Name:** `ClipContext`
/// **Lines:** 11-97
public protocol ClipContext {
    /// The canvas on which to paint.
    ///
    /// **Dart Source:** `clip.dart:13`
    var canvas: Canvas { get }
}

// MARK: - ClipContext Extension

extension ClipContext {

    /// Clips the canvas and paints using the given clip call and painter.
    ///
    /// **Dart Source:** `clip.dart:15-38`
    fileprivate func _clipAndPaint(
        _ canvasClipCall: (Bool) -> Void,
        clipBehavior: Clip,
        bounds: Rect,
        painter: () -> Void
    ) {
        // **Dart Source:** `clip.dart:21`
        canvas.save()
        switch clipBehavior {
        case .none:
            // **Dart Source:** `clip.dart:23-24`
            break
        case .hardEdge:
            // **Dart Source:** `clip.dart:25-26`
            canvasClipCall(false)
        case .antiAlias:
            // **Dart Source:** `clip.dart:27-28`
            canvasClipCall(true)
        case .antiAliasWithSaveLayer:
            // **Dart Source:** `clip.dart:29-31`
            canvasClipCall(true)
            canvas.saveLayer(bounds, Paint())
        }
        // **Dart Source:** `clip.dart:33`
        painter()
        // **Dart Source:** `clip.dart:34-36`
        if clipBehavior == .antiAliasWithSaveLayer {
            canvas.restore()
        }
        // **Dart Source:** `clip.dart:37`
        canvas.restore()
    }

    /// Clip `canvas` with `Path` according to `Clip` and then paint. `canvas` is
    /// restored to the pre-clip status afterwards.
    ///
    /// `bounds` is the saveLayer bounds used for `Clip.antiAliasWithSaveLayer`.
    ///
    /// **Dart Source:** `clip.dart:44-51`
    public func clipPathAndPaint(
        _ path: Path,
        clipBehavior: Clip,
        bounds: Rect,
        painter: () -> Void
    ) {
        _clipAndPaint(
            { doAntiAlias in canvas.clipPath(path, doAntiAlias: doAntiAlias) },
            clipBehavior: clipBehavior,
            bounds: bounds,
            painter: painter
        )
    }

    /// Clip `canvas` with `RRect` and then paint. `canvas` is
    /// restored to the pre-clip status afterwards.
    ///
    /// `bounds` is the saveLayer bounds used for `Clip.antiAliasWithSaveLayer`.
    ///
    /// **Dart Source:** `clip.dart:57-64`
    public func clipRRectAndPaint(
        _ rrect: RRect,
        clipBehavior: Clip,
        bounds: Rect,
        painter: () -> Void
    ) {
        _clipAndPaint(
            { doAntiAlias in canvas.clipRRect(rrect, doAntiAlias: doAntiAlias) },
            clipBehavior: clipBehavior,
            bounds: bounds,
            painter: painter
        )
    }

    /// Clip `canvas` with `RSuperellipse` and then paint. `canvas` is
    /// restored to the pre-clip status afterwards.
    ///
    /// `bounds` is the saveLayer bounds used for `Clip.antiAliasWithSaveLayer`.
    ///
    /// **Dart Source:** `clip.dart:71-83`
    public func clipRSuperellipseAndPaint(
        _ rse: RSuperellipse,
        clipBehavior: Clip,
        bounds: Rect,
        painter: () -> Void
    ) {
        _clipAndPaint(
            { doAntiAlias in canvas.clipRSuperellipse(rse, doAntiAlias: doAntiAlias) },
            clipBehavior: clipBehavior,
            bounds: bounds,
            painter: painter
        )
    }

    /// Clip `canvas` with `Rect` and then paint. `canvas` is
    /// restored to the pre-clip status afterwards.
    ///
    /// `bounds` is the saveLayer bounds used for `Clip.antiAliasWithSaveLayer`.
    ///
    /// **Dart Source:** `clip.dart:89-96`
    public func clipRectAndPaint(
        _ rect: Rect,
        clipBehavior: Clip,
        bounds: Rect,
        painter: () -> Void
    ) {
        _clipAndPaint(
            { doAntiAlias in canvas.clipRect(rect, clipOp: .intersect, doAntiAlias: doAntiAlias) },
            clipBehavior: clipBehavior,
            bounds: bounds,
            painter: painter
        )
    }
}
