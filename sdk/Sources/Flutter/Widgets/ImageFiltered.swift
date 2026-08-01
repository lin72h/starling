// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ImageFiltered

/// Applies an `ImageFilter` to its child.
///
/// An image filter will always apply its filter operation to the child widget,
/// even if said filter is conceptually a "no-op", such as an `ImageFilter.blur`
/// with a radius of 0 or an `ImageFilter.matrix` with an identity matrix. Setting
/// `ImageFiltered.enabled` to `false` is a more efficient manner of disabling
/// an image filter.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/image_filter.dart:39-69`
public class ImageFiltered: SingleChildRenderObjectWidget {

    /// Creates a widget that applies an `ImageFilter` to its child.
    ///
    /// **Dart Source:** `image_filter.dart:41`
    public init(
        key: (any Key)? = nil,
        imageFilter: any ImageFilter,
        child: Widget? = nil,
        enabled: Bool = true
    ) {
        self.imageFilter = imageFilter
        self.enabled = enabled
        super.init(key: key, child: child)
    }

    /// The image filter to apply to the child of this widget.
    ///
    /// **Dart Source:** `image_filter.dart:44`
    public let imageFilter: any ImageFilter

    /// Whether or not to apply the image filter operation to the child of this
    /// widget.
    ///
    /// Prefer setting enabled to `false` instead of creating a "no-op" filter
    /// type for performance reasons.
    ///
    /// **Dart Source:** `image_filter.dart:51`
    public let enabled: Bool

    /// **Dart Source:** `image_filter.dart:54-55`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _ImageFilterRenderObject(imageFilter, enabled)
    }

    /// **Dart Source:** `image_filter.dart:58-62`
    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! _ImageFilterRenderObject
        ro.enabled = enabled
        ro.imageFilter = imageFilter
    }
}

// MARK: - _ImageFilterRenderObject

/// A render object that applies an image filter to its child.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/image_filter.dart:71-109`
public class _ImageFilterRenderObject: RenderProxyBox {

    /// **Dart Source:** `image_filter.dart:72`
    init(_ imageFilter: any ImageFilter, _ enabled: Bool) {
        self._imageFilter = imageFilter
        self._enabled = enabled
        super.init()
    }

    /// **Dart Source:** `image_filter.dart:74-86`
    public var enabled: Bool {
        get { _enabled }
        set {
            if _enabled == newValue { return }
            _enabled = newValue
            markNeedsPaint()
        }
    }
    private var _enabled: Bool

    /// **Dart Source:** `image_filter.dart:88-95`
    public var imageFilter: any ImageFilter {
        get { _imageFilter }
        set {
            if AnyHashable(newValue) == AnyHashable(_imageFilter) { return }
            _imageFilter = newValue
            markNeedsPaint()
        }
    }
    private var _imageFilter: any ImageFilter

    /// Whether this render object always needs compositing.
    ///
    /// **Dart Source:** `image_filter.dart:98`
    public override var alwaysNeedsCompositing: Bool {
        child != nil && enabled
    }

    /// Whether this render object is a repaint boundary.
    ///
    /// **Dart Source:** `image_filter.dart:101`
    public override var isRepaintBoundary: Bool {
        alwaysNeedsCompositing
    }

    // Note: updateCompositedLayer is not yet implemented because ImageFilterLayer
    // and OffsetLayer have not been migrated. Will be added when Layer types are ported.
    // Dart Source: image_filter.dart:104-108
}
