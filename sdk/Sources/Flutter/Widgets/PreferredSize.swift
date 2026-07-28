// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - PreferredSizeWidget

/// An interface for widgets that can return the size this widget would prefer
/// if it were otherwise unconstrained.
///
/// There are a few cases, notably `AppBar` and `TabBar`, where it would be
/// undesirable for the widget to constrain its own size but where the widget
/// needs to expose a preferred or "default" size. For example a primary
/// `Scaffold` sets its app bar height to the app bar's preferred height
/// plus the height of the system status bar.
///
/// Widgets that need to know the preferred size of their child can require
/// that their child implement this interface by using this protocol rather
/// than `Widget` as the type of their `child` property.
///
/// Use `PreferredSize` to give a preferred size to an arbitrary widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/preferred_size.dart:27-35`
public protocol PreferredSizeWidget: AnyObject {
    /// The size this widget would prefer if it were otherwise unconstrained.
    ///
    /// In many cases it's only necessary to define one preferred dimension.
    /// For example the `Scaffold` only depends on its app bar's preferred
    /// height. In that case implementations can just return
    /// `Size.fromHeight(myAppBarHeight)`.
    ///
    /// **Dart Source:** `preferred_size.dart:34`
    var preferredSize: Size { get }
}

// MARK: - PreferredSize

/// A widget with a preferred size.
///
/// This widget does not impose any constraints on its child, and it doesn't
/// affect the child's layout in any way. It just advertises a preferred size
/// which can be used by the parent.
///
/// Parents like `Scaffold` use `PreferredSizeWidget` to require that their
/// children implement that interface. To give a preferred size to an arbitrary
/// widget so that it can be used in a `child` property of that type, this
/// widget, `PreferredSize`, can be used.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/preferred_size.dart:66-80`
public class PreferredSize: StatelessWidget, PreferredSizeWidget {

    /// Creates a widget that has a preferred size that the parent can query.
    ///
    /// **Dart Source:** `preferred_size.dart:68`
    public init(key: (any Key)? = nil, preferredSize: Size, child: Widget) {
        self.preferredSize = preferredSize
        self.child = child
        super.init(key: key)
    }

    /// The widget below this widget in the tree.
    ///
    /// **Dart Source:** `preferred_size.dart:73`
    public let child: Widget

    /// **Dart Source:** `preferred_size.dart:76`
    public let preferredSize: Size

    /// **Dart Source:** `preferred_size.dart:79`
    public override func build(_ context: any BuildContext) -> Widget {
        return child
    }
}
