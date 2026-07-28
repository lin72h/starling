// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - BackdropFilter

/// Applies an `ImageFilter` to existing painted content underneath this widget
/// (the "backdrop"), then paints its child on top.
///
/// Typically wrapped in a `ClipRect` or `ClipRRect` so the filter is bounded
/// to the area you want frosted. Use `ImageFilter.blur(sigmaX:, sigmaY:)` to
/// get the classic macOS-style frosted glass effect.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/basic.dart` (BackdropFilter)
public class BackdropFilter: SingleChildRenderObjectWidget {

    public init(
        key: (any Key)? = nil,
        filter: any ImageFilter,
        blendMode: BlendMode = .srcOver,
        enabled: Bool = true,
        child: Widget? = nil
    ) {
        self.filter = filter
        self.blendMode = blendMode
        self.enabled = enabled
        super.init(key: key, child: child)
    }

    public let filter: any ImageFilter
    public let blendMode: BlendMode
    public let enabled: Bool

    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderBackdropFilter(filter: filter, blendMode: blendMode, enabled: enabled)
    }

    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderBackdropFilter
        ro.filter = filter
        ro.blendMode = blendMode
        ro.enabled = enabled
    }
}
