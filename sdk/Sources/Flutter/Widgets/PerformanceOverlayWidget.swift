// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Displays performance statistics.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/performance_overlay.dart:29-55`
public class PerformanceOverlay: LeafRenderObjectWidget {
    /// The mask created by shifting 1 by the index of the specific
    /// PerformanceOverlayOption to enable.
    public let optionsMask: Int

    /// Create a performance overlay with specific statistics.
    public init(key: (any Key)? = nil, optionsMask: Int = 0) {
        self.optionsMask = optionsMask
        super.init(key: key)
    }

    /// Create a performance overlay that displays all available statistics.
    public static func allEnabled(key: (any Key)? = nil) -> PerformanceOverlay {
        let mask: Int =
            1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue |
            1 << PerformanceOverlayOption.visualizeRasterizerStatistics.rawValue |
            1 << PerformanceOverlayOption.displayEngineStatistics.rawValue |
            1 << PerformanceOverlayOption.visualizeEngineStatistics.rawValue
        return PerformanceOverlay(key: key, optionsMask: mask)
    }

    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderPerformanceOverlay(optionsMask: optionsMask)
    }

    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let overlay = renderObject as! RenderPerformanceOverlay
        overlay.optionsMask = optionsMask
    }
}
