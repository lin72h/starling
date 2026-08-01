// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// A sliver that keeps its Widget child at the top of a `CustomScrollView`.
///
/// This sliver is preferable to the general purpose `SliverPersistentHeader`
/// for its relatively narrow use case because there's no need to create a
/// `SliverPersistentHeaderDelegate` or to predict the header's size.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/pinned_header_sliver.dart:56-65`
public class PinnedHeaderSliver: SingleChildRenderObjectWidget {

    /// Creates a sliver whose Widget child appears at the top of a
    /// `CustomScrollView`.
    ///
    /// **Dart Source:** `pinned_header_sliver.dart:59`
    public override init(key: (any Key)? = nil, child: Widget? = nil) {
        super.init(key: key, child: child)
    }

    /// **Dart Source:** `pinned_header_sliver.dart:62-64`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderPinnedHeaderSliver()
    }
}

// MARK: - _RenderPinnedHeaderSliver

/// Render object that pins its child at the top of the scroll view.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/pinned_header_sliver.dart:67-109`
class _RenderPinnedHeaderSliver: RenderSliverSingleBoxAdapter {

    /// **Dart Source:** `pinned_header_sliver.dart:68`
    override init(child: RenderBox? = nil) {
        super.init(child: child)
    }

    /// The extent of the child along the main axis.
    ///
    /// **Dart Source:** `pinned_header_sliver.dart:70-79`
    var childExtent: Double {
        guard let child = child else {
            return 0.0
        }
        assert(child.hasSize)
        switch sliverConstraints.axis {
        case .vertical:
            return child.size.height
        case .horizontal:
            return child.size.width
        }
    }

    /// **Dart Source:** `pinned_header_sliver.dart:82`
    override func childMainAxisPosition(_ child: RenderObject) -> Double {
        return 0
    }

    /// **Dart Source:** `pinned_header_sliver.dart:85-108`
    override func performLayout() {
        let constraints = self.sliverConstraints
        child?.layout(constraints.asBoxConstraints(), parentUsesSize: true)

        let layoutExtent = clampDouble(
            childExtent - constraints.scrollOffset,
            0,
            constraints.remainingPaintExtent
        )
        let paintExtent = Swift.min(
            childExtent,
            constraints.remainingPaintExtent - constraints.overlap
        )
        geometry = SliverGeometry(
            scrollExtent: childExtent,
            paintExtent: paintExtent,
            paintOrigin: constraints.overlap,
            layoutExtent: layoutExtent,
            maxPaintExtent: childExtent,
            maxScrollObstructionExtent: childExtent,
            hasVisualOverflow: true,
            cacheExtent: calculateCacheOffset(constraints, from: 0.0, to: childExtent)
        )
    }
}
