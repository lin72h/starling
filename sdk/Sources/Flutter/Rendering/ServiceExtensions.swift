// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Service extension constants for the rendering library.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/service_extensions.dart`

// MARK: - RenderingServiceExtensions

/// Service extension constants for the rendering library.
///
/// These constants will be used when registering service extensions in the
/// framework, and they will also be used by tools and services that call these
/// service extensions.
///
/// The String value for each of these extension names should be accessed by
/// calling the `.name` property on the enum value.
///
/// **Dart Source:** `service_extensions.dart:23-162`
public enum RenderingServiceExtensions: String, CaseIterable {
    /// Name of service extension that, when called, will toggle whether the
    /// framework will color invert and horizontally flip images that have been
    /// decoded to a size taking more bytes than necessary.
    ///
    /// **Dart Source:** `service_extensions.dart:24-35`
    case invertOversizedImages

    /// Name of service extension that, when called, will toggle whether each
    /// RenderBox will paint a box around its bounds as well as additional boxes
    /// showing construction lines.
    ///
    /// **Dart Source:** `service_extensions.dart:37-47`
    case debugPaint

    /// Name of service extension that, when called, will toggle whether each
    /// RenderBox will paint a line at each of its baselines.
    ///
    /// **Dart Source:** `service_extensions.dart:49-58`
    case debugPaintBaselinesEnabled

    /// Name of service extension that, when called, will toggle whether a rotating
    /// set of colors will be overlaid on the device when repainting layers in debug
    /// mode.
    ///
    /// **Dart Source:** `service_extensions.dart:60-70`
    case repaintRainbow

    /// Name of service extension that, when called, will dump a String
    /// representation of the layer tree to console.
    ///
    /// **Dart Source:** `service_extensions.dart:72-79`
    case debugDumpLayerTree

    /// Name of service extension that, when called, will toggle whether all
    /// clipping effects from the layer tree will be ignored.
    ///
    /// **Dart Source:** `service_extensions.dart:81-90`
    case debugDisableClipLayers

    /// Name of service extension that, when called, will toggle whether all
    /// physical modeling effects from the layer tree will be ignored.
    ///
    /// **Dart Source:** `service_extensions.dart:92-101`
    case debugDisablePhysicalShapeLayers

    /// Name of service extension that, when called, will toggle whether all opacity
    /// effects from the layer tree will be ignored.
    ///
    /// **Dart Source:** `service_extensions.dart:103-112`
    case debugDisableOpacityLayers

    /// Name of service extension that, when called, will dump a String
    /// representation of the render tree to console.
    ///
    /// **Dart Source:** `service_extensions.dart:114-121`
    case debugDumpRenderTree

    /// Name of service extension that, when called, will dump a String
    /// representation of the semantics tree (in traversal order) to console.
    ///
    /// **Dart Source:** `service_extensions.dart:123-130`
    case debugDumpSemanticsTreeInTraversalOrder

    /// Name of service extension that, when called, will dump a String
    /// representation of the semantics tree (in inverse hit test order) to console.
    ///
    /// **Dart Source:** `service_extensions.dart:132-139`
    case debugDumpSemanticsTreeInInverseHitTestOrder

    /// Name of service extension that, when called, will toggle whether Timeline
    /// events are added for every RenderObject painted.
    ///
    /// **Dart Source:** `service_extensions.dart:141-150`
    case profileRenderObjectPaints

    /// Name of service extension that, when called, will toggle whether Timeline
    /// events are added for every RenderObject laid out.
    ///
    /// **Dart Source:** `service_extensions.dart:152-161`
    case profileRenderObjectLayouts

    /// The string name of this service extension.
    public var name: String { rawValue }
}
