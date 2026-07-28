// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ColorFiltered

/// Applies a `ColorFilter` to its child.
///
/// This widget applies a function independently to each pixel of `child`'s
/// content, according to the `ColorFilter` specified.
/// Use the `ColorFilter.mode` constructor to apply a `Color` using a `BlendMode`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/color_filter.dart:36-56`
public class ColorFiltered: SingleChildRenderObjectWidget {

    /// Creates a widget that applies a `ColorFilter` to its child.
    ///
    /// **Dart Source:** `color_filter.dart:38`
    public init(colorFilter: ColorFilter, child: Widget? = nil, key: (any Key)? = nil) {
        self.colorFilter = colorFilter
        super.init(key: key, child: child)
    }

    /// The color filter to apply to the child of this widget.
    ///
    /// **Dart Source:** `color_filter.dart:41`
    public let colorFilter: ColorFilter

    /// **Dart Source:** `color_filter.dart:44`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return ColorFilterRenderObject(colorFilter)
    }

    /// **Dart Source:** `color_filter.dart:47-49`
    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        guard let renderObject = renderObject as? ColorFilterRenderObject else { return }
        renderObject.colorFilter = colorFilter
    }

    /// **Dart Source:** `color_filter.dart:52-55`
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<ColorFilter>("colorFilter", colorFilter))
    }
}

// MARK: - ColorFilterRenderObject

/// A render object that applies a `ColorFilter` to its child.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/color_filter.dart:58-86`
public class ColorFilterRenderObject: RenderProxyBox {

    /// Creates a render object that applies a color filter.
    ///
    /// **Dart Source:** `color_filter.dart:59`
    public init(_ colorFilter: ColorFilter) {
        self._colorFilter = colorFilter
        super.init()
    }

    /// The color filter to apply when painting.
    ///
    /// **Dart Source:** `color_filter.dart:61-68`
    public var colorFilter: ColorFilter {
        get { _colorFilter }
        set {
            if newValue != _colorFilter {
                _colorFilter = newValue
                markNeedsPaint()
            }
        }
    }
    private var _colorFilter: ColorFilter

    /// **Dart Source:** `color_filter.dart:71`
    public var alwaysNeedsCompositingOverride: Bool {
        return child != nil
    }

    /// **Dart Source:** `color_filter.dart:74-85`
    public override func paint(_ context: PaintingContext, _ offset: Offset) {
        // TODO: Full implementation requires PaintingContext.pushColorFilter
        // and ColorFilterLayer, which are not yet available.
        // Currently delegates to super.paint for basic rendering.
        //
        // Dart original:
        //   layer = context.pushColorFilter(
        //     offset, colorFilter, super.paint,
        //     oldLayer: layer as ColorFilterLayer?,
        //   );
        super.paint(context, offset)
    }
}
