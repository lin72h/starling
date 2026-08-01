// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import FlutterSwiftBridge

/// Reports its child's laid-out size after every layout pass — including the
/// first (unlike SizeChangedLayoutNotifier, which skips it). For widgets
/// whose behaviour needs their own geometry: sliders turning pointer x into
/// values, panels feeding exact rects to shaders.
///
/// The callback fires during layout: don't mutate widget state synchronously
/// from it — bounce through the main queue first.
public final class MeasureSize: SingleChildRenderObjectWidget {
    public let onSize: (Size) -> Void

    public init(onSize: @escaping (Size) -> Void, child: Widget) {
        self.onSize = onSize
        super.init(key: nil, child: child)
    }

    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderMeasureSize(onSize: onSize)
    }

    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
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
