// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

/// Reports its child's laid-out size after every layout pass — including the
/// first. Copied from the shell (Shell/MeasureSize.swift); the scrubber needs
/// its own width to turn drag positions into seek targets.
///
/// The callback fires during layout: don't mutate widget state synchronously
/// from it — bounce through the main queue first.
final class MeasureSize: SingleChildRenderObjectWidget {
    let onSize: (Size) -> Void

    init(onSize: @escaping (Size) -> Void, child: Widget) {
        self.onSize = onSize
        super.init(key: nil, child: child)
    }

    override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderMeasureSize(onSize: onSize)
    }

    override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        (renderObject as! _RenderMeasureSize).onSize = onSize
    }
}

private final class _RenderMeasureSize: RenderProxyBox {
    var onSize: (Size) -> Void

    init(onSize: @escaping (Size) -> Void) {
        self.onSize = onSize
        super.init(child: nil)
    }

    override func performLayout() {
        super.performLayout()
        onSize(size)
    }
}
