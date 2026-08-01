// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Widget wrapper for `RenderSliverToBoxAdapter`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/sliver.dart`

import FlutterSwiftBridge

// MARK: - SliverToBoxAdapter

/// A sliver that contains a single box widget.
///
/// `SliverToBoxAdapter` is useful when you want to include a single non-sliver
/// widget inside a `CustomScrollView` or other sliver-based scrollable. It wraps
/// the box widget in a `RenderSliverToBoxAdapter`, which sizes the sliver
/// according to the child's box constraints.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/sliver.dart:1508-1523`
public class SliverToBoxAdapter: SingleChildRenderObjectWidget {

    /// Creates a sliver that contains a single box widget.
    ///
    /// **Dart Source:** `sliver.dart:1512`
    public override init(
        key: (any Key)? = nil,
        child: Widget? = nil
    ) {
        super.init(key: key, child: child)
    }

    /// **Dart Source:** `sliver.dart:1515-1517`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return RenderSliverToBoxAdapter()
    }
}

// MARK: - SliverPadding Widget

/// A sliver that applies padding on each side of another sliver.
///
/// Slivers are special-purpose widgets that can be combined using a
/// `CustomScrollView` to create custom scroll effects. A `SliverPadding` is a
/// basic sliver that insets another sliver by applying padding on each side.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/basic.dart:6500-6540`
///
/// DIFFERENCE FROM DART: In Dart, `SliverPadding` is defined in `basic.dart`.
/// REASON: Grouped with other sliver widgets for organization.
public class SliverPadding: SingleChildRenderObjectWidget {

    /// The amount of space by which to inset the child sliver.
    public let padding: any EdgeInsetsGeometry

    /// Creates a sliver that applies padding on each side of another sliver.
    ///
    /// **Dart Source:** `basic.dart:6509`
    public init(
        key: (any Key)? = nil,
        padding: any EdgeInsetsGeometry,
        sliver: Widget? = nil
    ) {
        self.padding = padding
        super.init(key: key, child: sliver)
    }

    /// **Dart Source:** `basic.dart:6519-6524`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        let textDirection = Directionality.maybeOf(context)
        return RenderSliverPadding(
            padding: padding,
            textDirection: textDirection
        )
    }

    /// **Dart Source:** `basic.dart:6527-6532`
    public override func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        let ro = renderObject as! RenderSliverPadding
        ro.padding = padding
        ro.textDirection = Directionality.maybeOf(context)
    }
}
