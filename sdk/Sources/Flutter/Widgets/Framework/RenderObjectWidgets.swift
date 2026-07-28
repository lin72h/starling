// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - RenderObjectWidget

/// A widget that has a `RenderObject` as its configuration.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1579`
open class RenderObjectWidget: Widget {
    public override init(key: (any Key)? = nil) {
        super.init(key: key)
    }

    /// Creates the render object for this widget.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1894`
    open func createRenderObject(_ context: any BuildContext) -> RenderObject {
        fatalError("Subclasses must override createRenderObject")
    }

    /// Copies the configuration described by this widget to the given render object.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1920`
    open func updateRenderObject(_ context: any BuildContext, renderObject: RenderObject) {
        // Default does nothing.
    }

    /// A render object previously associated with this widget has been removed
    /// from the tree. The given render object will be of the same type as
    /// returned by this object's `createRenderObject`.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1936`
    open func didUnmountRenderObject(_ renderObject: RenderObject) {
        // Default does nothing.
    }
}

// MARK: - SingleChildRenderObjectWidget

/// A `RenderObjectWidget` that has exactly one child widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1680`
open class SingleChildRenderObjectWidget: RenderObjectWidget {
    /// The widget below this widget in the tree.
    public let child: Widget?

    /// Creates a widget with at most one child.
    public init(key: (any Key)? = nil, child: Widget? = nil) {
        self.child = child
        super.init(key: key)
    }

    open override func createElement() -> Element {
        return SingleChildRenderObjectElement(self)
    }
}

// MARK: - LeafRenderObjectWidget

/// A `RenderObjectWidget` that has no children.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1938`
open class LeafRenderObjectWidget: RenderObjectWidget {
    /// Creates a leaf render object widget.
    public override init(key: (any Key)? = nil) {
        super.init(key: key)
    }

    open override func createElement() -> Element {
        return LeafRenderObjectElement(self)
    }
}

// MARK: - MultiChildRenderObjectWidget

/// A `RenderObjectWidget` that configures a `RenderObject` subclass that
/// has a linked list of children.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1955`
open class MultiChildRenderObjectWidget: RenderObjectWidget {
    /// The widgets below this widget in the tree.
    public let children: [Widget]

    /// Initializes children for subclasses of `MultiChildRenderObjectWidget`.
    public init(key: (any Key)? = nil, children: [Widget] = []) {
        self.children = children
        super.init(key: key)
    }

    open override func createElement() -> Element {
        return MultiChildRenderObjectElement(self)
    }
}
