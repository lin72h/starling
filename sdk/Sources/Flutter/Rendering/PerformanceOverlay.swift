// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Performance overlay rendering types.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/performance_overlay.dart`

import FlutterSwiftBridge

// MARK: - PerformanceOverlayOption

/// The options that control whether the performance overlay displays certain
/// aspects of the compositor.
///
/// The raw values correspond to the constants in
/// `//engine/src/sky/compositor/performance_overlay_layer.h`.
///
/// **Dart Source:** performance_overlay.dart:16-48
public enum PerformanceOverlayOption: Int {

    /// Display the frame time and FPS of the last frame rendered. This field is
    /// updated every frame.
    ///
    /// This is the time spent by the rasterizer as it tries
    /// to convert the layer tree obtained from the widgets into OpenGL commands
    /// and tries to flush them onto the screen. When the total time taken by this
    /// step exceeds the frame slice, a frame is lost.
    ///
    /// **Dart Source:** performance_overlay.dart:27
    case displayRasterizerStatistics = 0

    /// Display the rasterizer frame times as they change over a set period of
    /// time in the form of a graph. The y axis of the graph denotes the total
    /// time spent by the rasterizer as a fraction of the total frame slice. When
    /// the bar turns red, a frame is lost.
    ///
    /// **Dart Source:** performance_overlay.dart:33
    case visualizeRasterizerStatistics = 1

    /// Display the frame time and FPS at which the interface can construct a
    /// layer tree for the rasterizer (whose behavior is described above) to
    /// consume.
    ///
    /// This involves all layout, animations, etc. When the total time taken by
    /// this step exceeds the frame slice, a frame is lost.
    ///
    /// **Dart Source:** performance_overlay.dart:41
    case displayEngineStatistics = 2

    /// Display the engine frame times as they change over a set period of time
    /// in the form of a graph. The y axis of the graph denotes the total time
    /// spent by the engine as a fraction of the total frame slice. When the bar
    /// turns red, a frame is lost.
    ///
    /// **Dart Source:** performance_overlay.dart:47
    case visualizeEngineStatistics = 3
}

// MARK: - PerformanceOverlayLayer (Stub)

/// A compositing layer that displays performance statistics.
///
/// This is a stub for the `PerformanceOverlayLayer` that will be fully
/// implemented in the engine layer types. It stores the overlay rect and
/// options mask needed to render performance statistics.
///
/// **Dart Source:** Referenced by performance_overlay.dart:131-134
public class PerformanceOverlayLayer: Layer {

    /// Creates a performance overlay layer.
    ///
    /// **Dart Source:** performance_overlay.dart:131-134
    public init(overlayRect: Rect, optionsMask: Int) {
        self.overlayRect = overlayRect
        self.optionsMask = optionsMask
        super.init()
    }

    /// The rectangle in which to paint the performance overlay.
    public let overlayRect: Rect

    /// The mask of which performance statistics to display.
    public let optionsMask: Int

    /// Adds this layer to the scene.
    ///
    /// Stub implementation -- full engine integration pending.
    public override func addToScene(_ builder: SceneBuilder) {
        // TODO: Full engine integration for performance overlay rendering.
    }
}

// MARK: - Constants

/// Height per row of performance statistics in the overlay.
///
/// **Dart Source:** performance_overlay.dart:63
private let kDefaultGraphHeight: Double = 80.0

// MARK: - RenderPerformanceOverlay

/// Displays performance statistics.
///
/// The overlay shows two time series. The first shows how much time was
/// required on this thread to produce each frame. The second shows how much
/// time was required on the raster thread (formerly known as the GPU thread)
/// to produce each frame. Ideally, both these values would be less than
/// the total frame budget for the hardware on which the app is running.
/// For example, if the hardware has a screen that updates at 60 Hz, each
/// thread should ideally spend less than 16ms producing each frame.
/// This ideal condition is indicated by a green vertical line for each thread.
/// Otherwise, the performance overlay shows a red vertical line.
///
/// **Dart Source:** performance_overlay.dart:65-137
public class RenderPerformanceOverlay: RenderBox {

    // MARK: - Initializer

    /// Creates a performance overlay render object.
    ///
    /// **Dart Source:** performance_overlay.dart:67
    public init(optionsMask: Int = 0) {
        self._optionsMask = optionsMask
        super.init()
    }

    // MARK: - Properties

    /// The mask is created by shifting 1 by the index of the specific
    /// `PerformanceOverlayOption` to enable.
    ///
    /// **Dart Source:** performance_overlay.dart:71-79
    public var optionsMask: Int {
        get { _optionsMask }
        set {
            if newValue == _optionsMask {
                return
            }
            _optionsMask = newValue
            markNeedsPaint()
        }
    }
    private var _optionsMask: Int

    /// Whether this render object's layout information is determined solely
    /// by the constraints provided by the parent.
    ///
    /// **Dart Source:** performance_overlay.dart:82
    public override var sizedByParent: Bool { true }

    /// Whether this render object always needs compositing.
    ///
    /// Performance overlay always uses a compositing layer.
    ///
    /// **Dart Source:** performance_overlay.dart:85
    public override var alwaysNeedsCompositing: Bool { true }

    // MARK: - Intrinsic Dimensions

    /// The intrinsic height based on which performance overlay options are enabled.
    ///
    /// Uses bitmask to determine how many rows of statistics are enabled
    /// and multiplies by `kDefaultGraphHeight`.
    ///
    /// Note: The Dart source at lines 100-107 uses bitwise OR `|` for checking
    /// bits, which appears to be a bug (should be `&`), but is preserved here
    /// for consistency with the original source.
    ///
    /// **Dart Source:** performance_overlay.dart:97-109
    private var _intrinsicHeight: Double {
        var result = 0.0
        if (optionsMask | (1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue) > 0)
            || (optionsMask | (1 << PerformanceOverlayOption.visualizeRasterizerStatistics.rawValue) > 0) {
            result += kDefaultGraphHeight
        }
        if (optionsMask | (1 << PerformanceOverlayOption.displayEngineStatistics.rawValue) > 0)
            || (optionsMask | (1 << PerformanceOverlayOption.visualizeEngineStatistics.rawValue) > 0) {
            result += kDefaultGraphHeight
        }
        return result
    }

    /// Returns the minimum intrinsic width for the given height.
    ///
    /// **Dart Source:** performance_overlay.dart:88-90
    public override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return 0.0
    }

    /// Returns the maximum intrinsic width for the given height.
    ///
    /// **Dart Source:** performance_overlay.dart:93-95
    public override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return 0.0
    }

    /// Returns the minimum intrinsic height for the given width.
    ///
    /// **Dart Source:** performance_overlay.dart:112-114
    public override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return _intrinsicHeight
    }

    /// Returns the maximum intrinsic height for the given width.
    ///
    /// **Dart Source:** performance_overlay.dart:117-119
    public override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return _intrinsicHeight
    }

    // MARK: - Layout

    /// Computes the dry layout size for the given constraints.
    ///
    /// Constrains the size to be as wide as possible and as tall as the
    /// intrinsic height.
    ///
    /// **Dart Source:** performance_overlay.dart:122-125
    public override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(Double.infinity, _intrinsicHeight))
    }

    // MARK: - Paint

    /// Paints the performance overlay by adding a `PerformanceOverlayLayer`
    /// to the compositing tree.
    ///
    /// **Dart Source:** performance_overlay.dart:128-136
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        assert(alwaysNeedsCompositing)
        // context.addLayer(
        //     PerformanceOverlayLayer(
        //         overlayRect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        //         optionsMask: optionsMask
        //     )
        // )
        // TODO: PaintingContext.addLayer is not yet available.
        // Creating the layer for reference; it will be added once PaintingContext
        // supports addLayer.
        let _ = PerformanceOverlayLayer(
            overlayRect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
            optionsMask: optionsMask
        )
    }
}
