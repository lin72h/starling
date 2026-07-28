// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ProxyWidget

/// A widget that has a child widget provided to it, instead of building a new widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1522`
open class ProxyWidget: Widget {
    /// The widget below this widget in the tree.
    public let child: Widget

    /// Creates a widget that has exactly one child widget.
    public init(key: (any Key)? = nil, child: Widget) {
        self.child = child
        super.init(key: key)
    }
}

// MARK: - ParentDataWidget

/// Base class for widgets that hook `ParentData` information to children of
/// `RenderObjectWidget`s.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1533`
open class ParentDataWidget<T: ParentData>: ProxyWidget {
    public override init(key: (any Key)? = nil, child: Widget) {
        super.init(key: key, child: child)
    }

    /// Write the data from this widget into the given render object's parent data.
    ///
    /// The framework calls this function whenever it detects that the
    /// `RenderObject` associated with the `child` has outdated
    /// `RenderObject.parentData`. For example, if the render object was recently
    /// inserted into the render tree, the render object's parent data may not
    /// match the data in this widget.
    open func applyParentData(_ renderObject: RenderObject) {
        fatalError("Subclasses must override applyParentData")
    }

    /// Whether the `ParentDataElement.applyWidgetOutOfTurn` method is allowed
    /// with this widget.
    open func debugIsValidRenderObject(_ renderObject: RenderObject) -> Bool {
        return true
    }

    /// The `RenderObject` superclass of the `RenderObject` that this widget's
    /// children must be placed in.
    open var debugTypicalAncestorWidgetClass: String {
        return "RenderObjectWidget"
    }

    open override func createElement() -> Element {
        return ParentDataElement<T>(self)
    }
}

// MARK: - InheritedWidget

/// Base class for widgets that efficiently propagate information down the tree.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:1556`
open class InheritedWidget: ProxyWidget {
    public override init(key: (any Key)? = nil, child: Widget) {
        super.init(key: key, child: child)
    }

    /// Whether the framework should notify widgets that inherit from this widget.
    open func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        fatalError("Subclasses must override updateShouldNotify")
    }

    open override func createElement() -> Element {
        return InheritedElement(self)
    }
}
