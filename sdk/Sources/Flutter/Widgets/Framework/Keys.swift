// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ObjectKey

/// A key that takes its identity from the object used as its value.
///
/// Used to tie the identity of a widget to the identity of an object used to
/// generate that widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:89`
public class ObjectKey: LocalKey {
    /// The object whose identity is used by this key's `==` operator.
    public let value: AnyObject?

    /// Creates a key that delegates its `==` to the given value's identity.
    public init(_ value: AnyObject?) {
        self.value = value
    }

    public static func == (lhs: ObjectKey, rhs: ObjectKey) -> Bool {
        return lhs.value === rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        if let value = value {
            hasher.combine(ObjectIdentifier(value))
        }
    }

    public var description: String {
        if let value = value {
            return "[\(objectRuntimeType(self, "ObjectKey")) \(objectRuntimeType(value, "Object"))]"
        }
        return "[\(objectRuntimeType(self, "ObjectKey")) nil]"
    }
}

// MARK: - GlobalKey

/// Non-generic marker for `GlobalKey<T>` so elements can recognize global
/// keys (e.g. to register them in the BuildOwner's global key registry).
public protocol AnyGlobalKey: AnyObject {}

/// A key that is unique across the entire app.
///
/// Global keys uniquely identify elements. Global keys provide access to other
/// objects that are associated with those elements, such as `BuildContext`
/// and, for `StatefulWidget`s, `State`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:159`
open class GlobalKey<T: State<StatefulWidget>>: LocalKey, AnyGlobalKey {
    /// Creates a global key.
    public init(debugLabel: String? = nil) {
        self._debugLabel = debugLabel
    }

    fileprivate let _debugLabel: String?

    /// The element currently using this key in the tree, if any.
    internal var _currentElement: Element? {
        return WidgetsBinding.instance.buildOwner?._globalKeyRegistry[ObjectIdentifier(self)]
    }

    /// The widget in the tree that currently has this global key.
    open var currentWidget: Widget? {
        return _currentElement?.widget
    }

    /// The build context for the widget that currently has this global key.
    open var currentContext: (any BuildContext)? {
        return _currentElement
    }

    /// The state for the widget that currently has this global key.
    open var currentState: T? {
        if let element = _currentElement as? StatefulElement {
            return element.state as? T
        }
        return nil
    }

    // MARK: - Key conformance

    public static func == (lhs: GlobalKey<T>, rhs: GlobalKey<T>) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public var description: String {
        let label = _debugLabel ?? ""
        let extra = label.isEmpty ? "" : " \(label)"
        return "[\(objectRuntimeType(self, "GlobalKey"))\(extra)]"
    }
}

// MARK: - LabeledGlobalKey

/// A global key with a debug label.
///
/// The debug label is useful for documentation and for debugging. The label
/// does not affect the key's identity.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:242`
public class LabeledGlobalKey<T: State<StatefulWidget>>: GlobalKey<T> {
    /// Creates a global key with a debugging label.
    ///
    /// The label does not affect the key's identity.
    public override init(debugLabel: String? = nil) {
        super.init(debugLabel: debugLabel)
    }

    public override var description: String {
        let label = _debugLabel ?? ""
        let extra = label.isEmpty ? "" : " \(label)"
        return "[\(objectRuntimeType(self, "LabeledGlobalKey"))\(extra)]"
    }
}

// MARK: - GlobalObjectKey

/// A global key that takes its identity from the object used as its value.
///
/// Used to tie the identity of a widget to the identity of an object used to
/// generate that widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/framework.dart:259`
public class GlobalObjectKey<T: State<StatefulWidget>>: GlobalKey<T> {
    /// The object whose identity is used by this key's `==` operator.
    public let value: AnyObject

    /// Creates a global key that uses object identity.
    public init(_ value: AnyObject) {
        self.value = value
        super.init()
    }

    public static func == (lhs: GlobalObjectKey<T>, rhs: GlobalObjectKey<T>) -> Bool {
        return lhs.value === rhs.value
    }

    public override func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(value))
    }

    public override var description: String {
        return "[\(objectRuntimeType(self, "GlobalObjectKey")) \(objectRuntimeType(value, "Object"))]"
    }
}
