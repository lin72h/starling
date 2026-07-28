// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - AnnotatedRegion

/// Annotates a region of the layer tree with a value.
///
/// See also:
///
///  * `Layer.find`, for an example of how this value is retrieved.
///  * `AnnotatedRegionLayer`, the layer pushed into the layer tree.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/annotated_region.dart:15-53`
public class AnnotatedRegion<T>: SingleChildRenderObjectWidget {

    /// Creates a new annotated region to insert `value` into the layer tree.
    ///
    /// Neither `child` nor `value` may be nil.
    ///
    /// `sized` defaults to true and controls whether the annotated region will
    /// clip its child.
    ///
    /// **Dart Source:** `annotated_region.dart:22-27`
    public init(
        key: (any Key)? = nil,
        child: Widget,
        value: T,
        sized: Bool = true
    ) {
        self.value = value
        self.sized = sized
        super.init(key: key, child: child)
    }

    /// A value which can be retrieved using `Layer.find`.
    ///
    /// **Dart Source:** `annotated_region.dart:30`
    public let value: T

    /// If false, the layer pushed into the tree will not be provided with a size.
    ///
    /// An `AnnotatedRegionLayer` with a size checks that the offset provided in
    /// `Layer.find` is within the bounds, returning nil otherwise.
    ///
    /// **Dart Source:** `annotated_region.dart:40`
    public let sized: Bool

    /// **Dart Source:** `annotated_region.dart:43-45`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderAnnotatedRegion<T>(value: value, sized: sized)
    }

    /// **Dart Source:** `annotated_region.dart:48-52`
    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderAnnotatedRegion<T>
        ro.value = value
        ro.sized = sized
    }
}
