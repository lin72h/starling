// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Debug flags, constants, and typedefs for the rendering library.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/debug.dart`

import FlutterSwiftBridge

// Any changes to this file should be reflected in the debugAssertAllRenderVarsUnset()
// function (to be added in Subtask 2).

// MARK: - Constants

/// The default repaint color used when `debugRepaintRainbowEnabled` is active.
///
/// **Dart Source:** `debug.dart:25`
nonisolated(unsafe) private let _kDebugDefaultRepaintColor = HSVColor.fromAHSV(0.4, 60.0, 1.0, 1.0)

// MARK: - Debug Paint Flags

/// Causes each RenderBox to paint a box around its bounds, and some extra
/// boxes, such as RenderPadding, to draw construction lines.
///
/// The edges of the boxes are painted as a one-pixel-thick `Color(0xFF00FFFF)` outline.
///
/// Spacing is painted as a solid `Color(0x90909090)` area.
///
/// Padding is filled in solid `Color(0x900090FF)`, with the inner edge
/// outlined in `Color(0xFF0090FF)`, using `debugPaintPadding`.
///
/// **Dart Source:** `debug.dart:36`
nonisolated(unsafe) public var debugPaintSizeEnabled: Bool = false

/// Causes each RenderBox to paint a line at each of its baselines.
///
/// **Dart Source:** `debug.dart:39`
nonisolated(unsafe) public var debugPaintBaselinesEnabled: Bool = false

/// Causes each RenderParagraph to paint the layout boxes of its text.
///
/// **Dart Source:** `debug.dart:48`
nonisolated(unsafe) public var debugPaintTextLayoutBoxes: Bool = false

/// Causes each Layer to paint a box around its bounds.
///
/// **Dart Source:** `debug.dart:51`
nonisolated(unsafe) public var debugPaintLayerBordersEnabled: Bool = false

/// Causes objects like RenderPointerListener to flash while they are being
/// tapped. This can be useful to see how large the hit box is, e.g. when
/// debugging buttons that are harder to hit than expected.
///
/// **Dart Source:** `debug.dart:59`
nonisolated(unsafe) public var debugPaintPointersEnabled: Bool = false

/// Overlay a rotating set of colors when repainting layers in debug mode.
///
/// **Dart Source:** `debug.dart:67`
nonisolated(unsafe) public var debugRepaintRainbowEnabled: Bool = false

/// Overlay a rotating set of colors when repainting text in debug mode.
///
/// **Dart Source:** `debug.dart:70`
nonisolated(unsafe) public var debugRepaintTextRainbowEnabled: Bool = false

// MARK: - Debug Repaint Color

/// The current color to overlay when repainting a layer.
///
/// This is used by painting debug code that implements
/// `debugRepaintRainbowEnabled` or `debugRepaintTextRainbowEnabled`.
///
/// The value is incremented by `RenderView.compositeFrame` if either of those
/// flags is enabled.
///
/// **Dart Source:** `debug.dart:79`
nonisolated(unsafe) public var debugCurrentRepaintColor: HSVColor = _kDebugDefaultRepaintColor

// MARK: - Debug Print Flags

/// Log the call stacks that mark render objects as needing layout.
///
/// For sanity, this only logs the stack traces of cases where an object is
/// added to the list of nodes needing layout. This avoids printing multiple
/// redundant stack traces as a single `RenderObject.markNeedsLayout` call walks
/// up the tree.
///
/// **Dart Source:** `debug.dart:87`
nonisolated(unsafe) public var debugPrintMarkNeedsLayoutStacks: Bool = false

/// Log the call stacks that mark render objects as needing paint.
///
/// **Dart Source:** `debug.dart:90`
nonisolated(unsafe) public var debugPrintMarkNeedsPaintStacks: Bool = false

/// Log the dirty render objects that are laid out each frame.
///
/// Combined with `debugPrintBeginFrameBanner`, this allows you to distinguish
/// layouts triggered by the initial mounting of a render tree (e.g. in a call
/// to `runApp`) from the regular layouts triggered by the pipeline.
///
/// Combined with `debugPrintMarkNeedsLayoutStacks`, this lets you watch a
/// render object's dirty/clean lifecycle.
///
/// **Dart Source:** `debug.dart:110`
nonisolated(unsafe) public var debugPrintLayouts: Bool = false

// MARK: - Debug Check Flags

/// Check the intrinsic sizes of each RenderBox during layout.
///
/// By default this is turned off since these checks are expensive. If you are
/// implementing your own children of RenderBox with custom intrinsics, turn
/// this on in your unit tests for additional validations.
///
/// **Dart Source:** `debug.dart:117`
nonisolated(unsafe) public var debugCheckIntrinsicSizes: Bool = false

// MARK: - Debug Profile Flags

/// Adds Timeline events for every RenderObject layout.
///
/// The timing information this flag exposes is not representative of the actual
/// cost of layout, because the overhead of adding timeline events is
/// significant relative to the time each object takes to lay out. However, it
/// can expose unexpected layout behavior in the timeline.
///
/// **Dart Source:** `debug.dart:143`
nonisolated(unsafe) public var debugProfileLayoutsEnabled: Bool = false

/// Adds Timeline events for every RenderObject painted.
///
/// The timing information this flag exposes is not representative of actual
/// paints, because the overhead of adding timeline events is significant
/// relative to the time each object takes to paint. However, it can expose
/// unexpected painting in the timeline.
///
/// **Dart Source:** `debug.dart:172`
nonisolated(unsafe) public var debugProfilePaintsEnabled: Bool = false

/// Adds debugging information to Timeline events related to RenderObject
/// layouts.
///
/// This flag will only add Timeline event arguments for debug builds.
/// Additional arguments will be added for the "LAYOUT" timeline event and for
/// all RenderObject layout Timeline events, which are the events that are
/// added when `debugProfileLayoutsEnabled` is true.
///
/// **Dart Source:** `debug.dart:193`
nonisolated(unsafe) public var debugEnhanceLayoutTimelineArguments: Bool = false

/// Adds debugging information to Timeline events related to RenderObject
/// paints.
///
/// This flag will only add Timeline event arguments for debug builds.
/// Additional arguments will be added for the "PAINT" timeline event and for
/// all RenderObject paint Timeline events, which are the Timeline events
/// that are added when `debugProfilePaintsEnabled` is true.
///
/// **Dart Source:** `debug.dart:214`
nonisolated(unsafe) public var debugEnhancePaintTimelineArguments: Bool = false

// MARK: - ProfilePaintCallback Typedef

/// Signature for `debugOnProfilePaint` implementations.
///
/// **Dart Source:** `debug.dart:217`
public typealias ProfilePaintCallback = (_ renderObject: RenderObject) -> Void

// MARK: - Debug Paint Callback

/// Callback invoked for every RenderObject painted each frame.
///
/// This callback is only invoked in debug builds.
///
/// **Dart Source:** `debug.dart:233`
nonisolated(unsafe) public var debugOnProfilePaint: ProfilePaintCallback? = nil

// MARK: - Debug Disable Flags

/// Setting to true will cause all clipping effects from the layer tree to be
/// ignored.
///
/// Can be used to debug whether objects being clipped are painting excessively
/// in clipped areas. Can also be used to check whether excessive use of
/// clipping is affecting performance.
///
/// This will not reduce the number of Layer objects created; the compositing
/// strategy is unaffected. It merely causes the clipping layers to be skipped
/// when building the scene.
///
/// **Dart Source:** `debug.dart:245`
nonisolated(unsafe) public var debugDisableClipLayers: Bool = false

/// Setting to true will cause all physical modeling effects from the layer
/// tree, such as shadows from elevations, to be ignored.
///
/// Can be used to check whether excessive use of physical models is affecting
/// performance.
///
/// This will not reduce the number of Layer objects created; the compositing
/// strategy is unaffected. It merely causes the physical shape layers to be
/// skipped when building the scene.
///
/// **Dart Source:** `debug.dart:256`
nonisolated(unsafe) public var debugDisablePhysicalShapeLayers: Bool = false

/// Setting to true will cause all opacity effects from the layer tree to be
/// ignored.
///
/// An optimization to not paint the child at all when opacity is 0 will still
/// remain.
///
/// Can be used to check whether excessive use of opacity effects is affecting
/// performance.
///
/// This will not reduce the number of Layer objects created; the compositing
/// strategy is unaffected. It merely causes the opacity layers to be skipped
/// when building the scene.
///
/// **Dart Source:** `debug.dart:270`
nonisolated(unsafe) public var debugDisableOpacityLayers: Bool = false

// MARK: - Debug Paint Helpers

/// Paints a visualization of padding.
///
/// Fills the region between `outerRect` and `innerRect` in a tealish color,
/// with a solid outline around the inner region.
///
/// This is a stub; the full implementation will be provided in a later subtask.
///
/// **Dart Source:** `debug.dart:294-333`
public func debugPaintPadding(
    _ canvas: any Canvas,
    _ outerRect: Rect,
    _ innerRect: Rect?,
    outlineWidth: Double = 2.0
) {
    // TODO: Full implementation in a later subtask.
    // The full implementation paints the padding area in Color(0x900090FF)
    // and draws an outline around innerRect in Color(0xFF0090FF).
}
