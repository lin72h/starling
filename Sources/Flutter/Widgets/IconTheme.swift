// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - IconTheme

/// Controls the default properties of icons in a widget subtree.
///
/// The icon theme is honored by `Icon` and `ImageIcon` widgets.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/icon_theme.dart:24-100`
public class IconTheme: InheritedTheme {

    /// Creates an icon theme that controls properties of descendant widgets.
    ///
    /// **Dart Source:** `icon_theme.dart:26`
    public init(key: (any Key)? = nil, data: IconThemeData, child: Widget) {
        self.data = data
        super.init(key: key, child: child)
    }

    // Note: `merge` static method is not yet implemented because it requires
    // the `Builder` widget from basic.dart, which has not been migrated.
    // Dart Source: icon_theme.dart:30-40

    /// The set of properties to use for icons in this subtree.
    ///
    /// **Dart Source:** `icon_theme.dart:43`
    public let data: IconThemeData

    /// The data from the closest instance of this class that encloses the given
    /// context, if any.
    ///
    /// If there is no ambient icon theme, defaults to `IconThemeData.fallback()`.
    /// The returned `IconThemeData` is concrete (all values are non-null; see
    /// `IconThemeData.isConcrete`). Any properties on the ambient icon theme that
    /// are null get defaulted to the values specified on `IconThemeData.fallback()`.
    ///
    /// **Dart Source:** `icon_theme.dart:64-80`
    public static func of(_ context: any BuildContext) -> IconThemeData {
        let iconThemeData = _getInheritedIconThemeData(context).resolve(context)
        if iconThemeData.isConcrete {
            return iconThemeData
        }
        let fb = IconThemeData.fallback()
        return iconThemeData.copyWith(
            size: iconThemeData.size ?? fb.size,
            fill: iconThemeData.fill ?? fb.fill,
            weight: iconThemeData.weight ?? fb.weight,
            grade: iconThemeData.grade ?? fb.grade,
            opticalSize: iconThemeData.opticalSize ?? fb.opticalSize,
            color: iconThemeData.color ?? fb.color,
            opacity: iconThemeData.opacity ?? fb.opacity,
            shadows: iconThemeData.shadows ?? fb.shadows,
            applyTextScaling: iconThemeData.applyTextScaling ?? fb.applyTextScaling
        )
    }

    /// **Dart Source:** `icon_theme.dart:82-85`
    private static func _getInheritedIconThemeData(_ context: any BuildContext) -> IconThemeData {
        let iconTheme = context.dependOnInheritedWidgetOfExactType(IconTheme.self)
        return iconTheme?.data ?? IconThemeData.fallback()
    }

    /// **Dart Source:** `icon_theme.dart:88`
    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        guard let oldIconTheme = oldWidget as? IconTheme else { return true }
        return data != oldIconTheme.data
    }

    /// **Dart Source:** `icon_theme.dart:91-93`
    public override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
        return IconTheme(data: data, child: child)
    }
}
