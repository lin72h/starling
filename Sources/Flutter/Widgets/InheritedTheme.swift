// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - InheritedTheme

/// An `InheritedWidget` that defines visual properties like colors
/// and text styles, which the `child`'s subtree depends on.
///
/// The `wrap` method is used by `captureAll` and `CapturedThemes.wrap` to
/// construct a widget that will wrap a child in all of the inherited themes
/// which are present in a specified part of the widget tree.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/inherited_theme.dart:36-127`
open class InheritedTheme: InheritedWidget {

    /// Creates an inherited theme widget.
    ///
    /// **Dart Source:** `inherited_theme.dart:40`
    public override init(key: (any Key)? = nil, child: Widget) {
        super.init(key: key, child: child)
    }

    /// Return a copy of this inherited theme with the specified `child`.
    ///
    /// **Dart Source:** `inherited_theme.dart:51`
    open func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        fatalError("Subclasses of InheritedTheme must override wrap()")
    }

    /// Returns a widget that will `wrap` `child` in all of the inherited themes
    /// which are present between `context` and the specified `to` `BuildContext`.
    ///
    /// The `to` context must be an ancestor of `context`. If `to` is not
    /// specified, all inherited themes up to the root of the widget tree are
    /// captured.
    ///
    /// **Dart Source:** `inherited_theme.dart:66-68`
    public static func captureAll(
        _ context: any BuildContext,
        child: Widget,
        to: (any BuildContext)? = nil
    ) -> Widget {
        return capture(from: context, to: to).wrap(child)
    }

    /// Returns a `CapturedThemes` object that includes all the `InheritedTheme`s
    /// between the given `from` and `to` `BuildContext`s.
    ///
    /// The `to` context must be an ancestor of the `from` context. If `to` is
    /// nil, all ancestor inherited themes of `from` up to the root of the
    /// widget tree are captured.
    ///
    /// **Dart Source:** `inherited_theme.dart:87-126`
    public static func capture(
        from: any BuildContext,
        to: (any BuildContext)? = nil
    ) -> CapturedThemes {
        if let to = to, from === to {
            return CapturedThemes([])
        }

        var themes: [InheritedTheme] = []
        var themeTypes: Set<ObjectIdentifier> = []

        from.visitAncestorElements { ancestor in
            if let to = to, ancestor === to {
                return false
            }
            if let inheritedElement = ancestor as? InheritedElement,
               let theme = inheritedElement.widget as? InheritedTheme {
                let themeType = ObjectIdentifier(type(of: theme))
                // Only remember the first theme of any type. This assumes
                // that inherited themes completely shadow ancestors of the
                // same type.
                if !themeTypes.contains(themeType) {
                    themeTypes.insert(themeType)
                    themes.append(theme)
                }
            }
            return true
        }

        return CapturedThemes(themes)
    }
}

// MARK: - CapturedThemes

/// Stores a list of captured `InheritedTheme`s that can be wrapped around a
/// child `Widget`.
///
/// Used as return type by `InheritedTheme.capture`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/inherited_theme.dart:133-142`
public class CapturedThemes {

    /// Creates a captured themes object.
    ///
    /// **Dart Source:** `inherited_theme.dart:134`
    internal init(_ themes: [InheritedTheme]) {
        self._themes = themes
    }

    private let _themes: [InheritedTheme]

    /// Wraps a `child` `Widget` in the `InheritedTheme`s captured in this object.
    ///
    /// **Dart Source:** `inherited_theme.dart:139-141`
    public func wrap(_ child: Widget) -> Widget {
        return CaptureAll(themes: _themes, child: child)
    }
}

// MARK: - CaptureAll

/// Internal widget that wraps a child in a list of inherited themes.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/inherited_theme.dart:144-158`
internal class CaptureAll: StatelessWidget {

    /// Creates a capture-all widget.
    ///
    /// **Dart Source:** `inherited_theme.dart:145`
    init(themes: [InheritedTheme], child: Widget) {
        self.themes = themes
        self._child = child
        super.init()
    }

    let themes: [InheritedTheme]
    let _child: Widget

    /// **Dart Source:** `inherited_theme.dart:151-157`
    override func build(_ context: any BuildContext) -> Widget {
        var wrappedChild: Widget = _child
        for theme in themes {
            wrappedChild = theme.wrap(context, wrappedChild)
        }
        return wrappedChild
    }
}
