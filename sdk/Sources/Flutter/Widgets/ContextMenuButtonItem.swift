// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ContextMenuButtonType

/// The buttons that can appear in a context menu by default.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/context_menu_button_item.dart:19-53`
public enum ContextMenuButtonType: Sendable {
    /// A button that cuts the current text selection.
    case cut

    /// A button that copies the current text selection.
    case copy

    /// A button that pastes the clipboard contents into the focused text field.
    case paste

    /// A button that selects all the contents of the focused text field.
    case selectAll

    /// A button that deletes the current text selection.
    case delete

    /// A button that looks up the current text selection.
    case lookUp

    /// A button that launches a web search for the current text selection.
    case searchWeb

    /// A button that displays the share screen for the current text selection.
    case share

    /// A button for starting Live Text input.
    case liveTextInput

    /// Anything other than the default button types.
    case custom
}

// MARK: - ContextMenuButtonItem

/// The type and callback for a context menu button.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/context_menu_button_item.dart:65-116`
public struct ContextMenuButtonItem: Equatable, CustomStringConvertible {

    /// Creates an instance of `ContextMenuButtonItem`.
    ///
    /// **Dart Source:** `context_menu_button_item.dart:67-71`
    public init(
        onPressed: VoidCallback?,
        type: ContextMenuButtonType = .custom,
        label: String? = nil
    ) {
        self.onPressed = onPressed
        self.type = type
        self.label = label
    }

    /// The callback to be called when the button is pressed.
    ///
    /// **Dart Source:** `context_menu_button_item.dart:74`
    public let onPressed: VoidCallback?

    /// The type of button this represents.
    ///
    /// **Dart Source:** `context_menu_button_item.dart:77`
    public let type: ContextMenuButtonType

    /// The label to display on the button.
    ///
    /// If a `type` other than `ContextMenuButtonType.custom` is given
    /// and a label is not provided, then the default label for that type for the
    /// platform will be looked up.
    ///
    /// **Dart Source:** `context_menu_button_item.dart:84`
    public let label: String?

    /// Creates a new `ContextMenuButtonItem` with the provided parameters
    /// overridden.
    ///
    /// **Dart Source:** `context_menu_button_item.dart:88-98`
    public func copyWith(
        onPressed: VoidCallback?? = nil,
        type: ContextMenuButtonType? = nil,
        label: String?? = nil
    ) -> ContextMenuButtonItem {
        return ContextMenuButtonItem(
            onPressed: onPressed ?? self.onPressed,
            type: type ?? self.type,
            label: label ?? self.label
        )
    }

    // MARK: - Equatable

    /// **Dart Source:** `context_menu_button_item.dart:101-109`
    public static func == (lhs: ContextMenuButtonItem, rhs: ContextMenuButtonItem) -> Bool {
        return lhs.label == rhs.label
            && lhs.type == rhs.type
        // Note: onPressed closures cannot be compared in Swift;
        // Dart compares function references with ==.
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `context_menu_button_item.dart:115`
    public var description: String {
        return "ContextMenuButtonItem \(type), \(label ?? "nil")"
    }
}
