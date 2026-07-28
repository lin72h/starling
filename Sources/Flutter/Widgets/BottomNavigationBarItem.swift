// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - BottomNavigationBarItem

/// An interactive button within either material's `BottomNavigationBar`
/// or the iOS themed `CupertinoTabBar` with an icon and title.
///
/// This class is rarely used in isolation. It is typically embedded in one of
/// the bottom navigation widgets above.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/bottom_navigation_bar_item.dart:30-107`
public class BottomNavigationBarItem {

    /// Creates an item that is used with `BottomNavigationBar.items`.
    ///
    /// The argument `icon` should not be nil and the argument `label` should
    /// not be nil when used in a Material Design's `BottomNavigationBar`.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:34-41`
    public init(
        key: (any Key)? = nil,
        icon: Widget,
        label: String? = nil,
        activeIcon: Widget? = nil,
        backgroundColor: Color? = nil,
        tooltip: String? = nil
    ) {
        self.key = key
        self.icon = icon
        self.label = label
        self.activeIcon = activeIcon ?? icon
        self.backgroundColor = backgroundColor
        self.tooltip = tooltip
    }

    /// A key to be passed through to the resultant widget.
    ///
    /// This allows the identification of different `BottomNavigationBarItem`s
    /// through their keys.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:49`
    public let key: (any Key)?

    /// The icon of the item.
    ///
    /// Typically the icon is an `Icon` or an `ImageIcon` widget. If another type
    /// of widget is provided then it should configure itself to match the current
    /// `IconTheme` size and color.
    ///
    /// If `activeIcon` is provided, this will only be displayed when the item is
    /// not selected.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:68`
    public let icon: Widget

    /// An alternative icon displayed when this bottom navigation item is
    /// selected.
    ///
    /// If this icon is not provided, the bottom navigation bar will display
    /// `icon` in either state.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:79`
    public let activeIcon: Widget

    /// The text label for this `BottomNavigationBarItem`.
    ///
    /// This will be used to create a `Text` widget to put in the bottom
    /// navigation bar.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:84`
    public let label: String?

    /// The color of the background radial animation for material
    /// `BottomNavigationBar`.
    ///
    /// If the navigation bar's type is `BottomNavigationBarType.shifting`, then
    /// the entire bar is flooded with the `backgroundColor` when this item is
    /// tapped.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:99`
    public let backgroundColor: Color?

    /// The text to display in the `Tooltip` for this `BottomNavigationBarItem`.
    ///
    /// A `Tooltip` will only appear on this item if `tooltip` is set to a
    /// non-empty string.
    ///
    /// Defaults to nil, in which case the tooltip is not shown.
    ///
    /// **Dart Source:** `bottom_navigation_bar_item.dart:106`
    public let tooltip: String?
}
