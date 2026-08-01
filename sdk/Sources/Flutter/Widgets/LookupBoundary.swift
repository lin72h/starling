// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A lookup boundary controls what entities are visible to descendants of
/// the boundary via the static lookup methods provided by the boundary.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/lookup_boundary.dart:70-359`
public class LookupBoundary: InheritedWidget {
    /// Creates a LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:74`
    public override init(key: (any Key)? = nil, child: Widget) {
        super.init(key: key, child: child)
    }

    /// Obtains the nearest widget of the given type `T` within the current
    /// LookupBoundary, and registers the context as dependent.
    ///
    /// **Dart Source:** `lookup_boundary.dart:91-106`
    public static func dependOnInheritedWidgetOfExactType<T: InheritedWidget>(
        _ context: any BuildContext,
        aspect: AnyHashable? = nil
    ) -> T? {
        // Register dependency on LookupBoundary itself
        let _: LookupBoundary? = context.dependOnInheritedWidgetOfExactType(LookupBoundary.self)
        guard let candidate = getElementForInheritedWidgetOfExactType(T.self, context) else {
            return nil
        }
        let _ = context.dependOnInheritedElement(candidate, aspect: aspect)
        return candidate.widget as? T
    }

    /// Obtains the nearest widget of the given type `T` within the current
    /// LookupBoundary of `context`.
    ///
    /// **Dart Source:** `lookup_boundary.dart:120-129`
    public static func getInheritedWidgetOfExactType<T: InheritedWidget>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> T? {
        guard let candidate = getElementForInheritedWidgetOfExactType(type, context) else {
            return nil
        }
        return candidate.widget as? T
    }

    /// Obtains the element corresponding to the nearest widget of the given type
    /// `T` within the current LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:145-157`
    public static func getElementForInheritedWidgetOfExactType<T: InheritedWidget>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> InheritedElement? {
        guard let candidate = context.getElementForInheritedWidgetOfExactType(type) else {
            return nil
        }
        let boundary = context.getElementForInheritedWidgetOfExactType(LookupBoundary.self)
        if let boundary = boundary, boundary.depth > candidate.depth {
            return nil
        }
        return candidate
    }

    /// Returns the nearest ancestor widget of the given type `T` within
    /// the current LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:172-182`
    public static func findAncestorWidgetOfExactType<T: Widget>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> T? {
        var target: Element? = nil
        context.visitAncestorElements { ancestor in
            if Swift.type(of: ancestor.widget) == T.self {
                target = ancestor
                return false
            }
            return Swift.type(of: ancestor.widget) != LookupBoundary.self
        }
        return target?.widget as? T
    }

    /// Returns the State object of the nearest ancestor StatefulWidget
    /// within the current LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:196-206`
    public static func findAncestorStateOfType<T: State<StatefulWidget>>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> T? {
        var target: StatefulElement? = nil
        context.visitAncestorElements { ancestor in
            if let statefulElement = ancestor as? StatefulElement,
               statefulElement.state is T {
                target = statefulElement
                return false
            }
            return Swift.type(of: ancestor.widget) != LookupBoundary.self
        }
        return target?.state as? T
    }

    /// Returns the State object of the furthest ancestor StatefulWidget
    /// within the current LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:219-228`
    public static func findRootAncestorStateOfType<T: State<StatefulWidget>>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> T? {
        var target: StatefulElement? = nil
        context.visitAncestorElements { ancestor in
            if let statefulElement = ancestor as? StatefulElement,
               statefulElement.state is T {
                target = statefulElement
            }
            return Swift.type(of: ancestor.widget) != LookupBoundary.self
        }
        return target?.state as? T
    }

    /// Returns the RenderObject of the nearest ancestor RenderObjectWidget
    /// within the current LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:242-252`
    public static func findAncestorRenderObjectOfType<T: RenderObject>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> T? {
        var target: Element? = nil
        context.visitAncestorElements { ancestor in
            if let roElement = ancestor as? RenderObjectElement,
               roElement.renderObject is T {
                target = ancestor
                return false
            }
            return Swift.type(of: ancestor.widget) != LookupBoundary.self
        }
        return (target as? RenderObjectElement)?.renderObject as? T
    }

    /// Walks the ancestor chain up to the closest LookupBoundary.
    ///
    /// **Dart Source:** `lookup_boundary.dart:264-268`
    public static func visitAncestorElements(
        _ context: any BuildContext,
        visitor: @escaping ConditionalElementVisitor
    ) {
        context.visitAncestorElements { ancestor in
            visitor(ancestor) && Swift.type(of: ancestor.widget) != LookupBoundary.self
        }
    }

    /// Walks the non-LookupBoundary child elements.
    ///
    /// **Dart Source:** `lookup_boundary.dart:277-283`
    public static func visitChildElements(
        _ context: any BuildContext,
        visitor: @escaping ElementVisitor
    ) {
        context.visitChildElements { child in
            if Swift.type(of: child.widget) != LookupBoundary.self {
                visitor(child)
            }
        }
    }

    /// Returns true if a LookupBoundary is hiding the nearest Widget of type T.
    ///
    /// **Dart Source:** `lookup_boundary.dart:289-306`
    public static func debugIsHidingAncestorWidgetOfExactType<T: Widget>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> Bool {
        var hiddenByBoundary = false
        var ancestorFound = false
        context.visitAncestorElements { ancestor in
            if Swift.type(of: ancestor.widget) == T.self {
                ancestorFound = true
                return false
            }
            hiddenByBoundary = hiddenByBoundary || Swift.type(of: ancestor.widget) == LookupBoundary.self
            return true
        }
        return ancestorFound && hiddenByBoundary
    }

    /// Returns true if a LookupBoundary is hiding the nearest State of type T.
    ///
    /// **Dart Source:** `lookup_boundary.dart:312-329`
    public static func debugIsHidingAncestorStateOfType<T: State<StatefulWidget>>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> Bool {
        var hiddenByBoundary = false
        var ancestorFound = false
        context.visitAncestorElements { ancestor in
            if let statefulElement = ancestor as? StatefulElement,
               statefulElement.state is T {
                ancestorFound = true
                return false
            }
            hiddenByBoundary = hiddenByBoundary || Swift.type(of: ancestor.widget) == LookupBoundary.self
            return true
        }
        return ancestorFound && hiddenByBoundary
    }

    /// Returns true if a LookupBoundary is hiding the nearest RenderObject of type T.
    ///
    /// **Dart Source:** `lookup_boundary.dart:336-355`
    public static func debugIsHidingAncestorRenderObjectOfType<T: RenderObject>(
        _ type: T.Type,
        _ context: any BuildContext
    ) -> Bool {
        var hiddenByBoundary = false
        var ancestorFound = false
        context.visitAncestorElements { ancestor in
            if let roElement = ancestor as? RenderObjectElement,
               roElement.renderObject is T {
                ancestorFound = true
                return false
            }
            hiddenByBoundary = hiddenByBoundary || Swift.type(of: ancestor.widget) == LookupBoundary.self
            return true
        }
        return ancestorFound && hiddenByBoundary
    }

    /// **Dart Source:** `lookup_boundary.dart:358`
    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        false
    }
}
