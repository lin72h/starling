// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - BuildContext Protocol

/// A handle to the location of a widget in the widget tree.
///
/// This class is used as an interface by widget implementations to communicate
/// with the framework. It is typically used by `State.build` methods and to
/// interact with inherited widgets.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2306`
public protocol BuildContext: AnyObject {
    /// The current configuration for this context.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2308`
    var widget: Widget { get }

    /// The `BuildOwner` for this context.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2311`
    var owner: BuildOwner? { get }

    /// Whether the `Widget` this context is associated with is currently
    /// mounted in the widget tree.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2320`
    var mounted: Bool { get }

    /// Whether the widget is currently updating the widget or render tree.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2330`
    var debugDoingBuild: Bool { get }

    /// Dispatch a notification up the tree.
    func dispatchNotification(_ notification: Notification)

    /// Returns the nearest widget of the exact type `T`, and registers
    /// this build context as a dependent.
    func dependOnInheritedWidgetOfExactType<T: InheritedWidget>(_ type: T.Type) -> T?

    /// Returns the `InheritedElement` for the nearest widget of the exact
    /// type `T`, or nil if no such ancestor exists.
    func getElementForInheritedWidgetOfExactType<T: InheritedWidget>(_ type: T.Type) -> InheritedElement?

    /// Registers this build context with `ancestor` so that when `ancestor`'s
    /// widget changes, this build context is rebuilt.
    func dependOnInheritedElement(_ ancestor: InheritedElement, aspect: AnyHashable?) -> InheritedWidget

    /// Walks the ancestor chain, calling `visitor` for each ancestor.
    /// If `visitor` returns false, the walk stops.
    func visitAncestorElements(_ visitor: (Element) -> Bool)

    /// Calls the argument for each child element.
    func visitChildElements(_ visitor: (Element) -> Void)

    /// Returns the nearest ancestor widget of the given type `T`, which
    /// must be the type of a concrete `Widget` subclass.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2390`
    func findAncestorWidgetOfExactType<T: Widget>(_ type: T.Type) -> T?

    /// Returns the `State` object of the nearest ancestor `StatefulWidget` widget
    /// that is an instance of the given type `T`.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2440`
    func findAncestorStateOfType<T: AnyObject>(_ type: T.Type) -> T?

    /// Returns the `State` object of the furthest ancestor `StatefulWidget` widget
    /// that is an instance of the given type `T`.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2479`
    func findRootAncestorStateOfType<T: AnyObject>(_ type: T.Type) -> T?

    /// Returns the `RenderObject` of the nearest ancestor `RenderObjectWidget`.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2517`
    func findAncestorRenderObjectOfType<T: RenderObject>(_ type: T.Type) -> T?

    /// Returns the nearest `RenderObject` associated with this element.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:4421`
    func findRenderObject() -> RenderObject?

    /// The size of the `RenderBox` returned by `findRenderObject`.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2561`
    var size: Size? { get }

    /// Returns a description of the `Element` associated with the current
    /// build context.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2586`
    func describeElement(_ name: String) -> String

    /// Returns a description of the `Widget` associated with the current
    /// build context.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2594`
    func describeWidget(_ name: String) -> String

    /// Returns a description of the ownership chain from a specific element
    /// to the root of the tree.
    ///
    /// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:2621`
    func describeOwnershipChain(_ name: String) -> String
}

/// Default implementations for BuildContext protocol methods.
public extension BuildContext {
    var owner: BuildOwner? { nil }
    var mounted: Bool { true }
    var debugDoingBuild: Bool { false }
    var size: Size? { nil }

    func findAncestorStateOfType<T: AnyObject>(_ type: T.Type) -> T? { nil }
    func findRootAncestorStateOfType<T: AnyObject>(_ type: T.Type) -> T? { nil }
    func findAncestorRenderObjectOfType<T: RenderObject>(_ type: T.Type) -> T? { nil }
    func findRenderObject() -> RenderObject? { nil }

    func describeElement(_ name: String) -> String {
        return "\(name): \(widget.toStringShort())"
    }

    func describeWidget(_ name: String) -> String {
        return "\(name): \(widget.toStringShort())"
    }

    func describeOwnershipChain(_ name: String) -> String {
        return "\(name): \(widget.toStringShort())"
    }
}

// MARK: - NotifiableElementMixin

/// Mixin-like protocol for elements that receive notifications.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:3474`
public protocol NotifiableElementMixin: AnyObject {
    /// Called when a notification arrives at this location in the tree.
    ///
    /// Return true to cancel the notification bubbling. Return false to
    /// allow the notification to continue to be dispatched to further ancestors.
    func onNotification(_ notification: Notification) -> Bool
}

// MARK: - Visitor Typealiases

/// Signature for visiting an element and returning whether to continue.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:81`
public typealias ConditionalElementVisitor = (Element) -> Bool

/// Signature for visiting an element.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:75`
public typealias ElementVisitor = (Element) -> Void

// MARK: - WidgetBuilder

/// Signature for a function that creates a widget, e.g. `StatelessWidget.build`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:148`
public typealias WidgetBuilder = (any BuildContext) -> Widget
