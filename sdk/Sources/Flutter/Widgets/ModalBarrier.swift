// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A widget that prevents the user from interacting with widgets behind itself.
///
/// The modal barrier is the scrim that is rendered behind each route, which
/// generally prevents the user from interacting with the route below the
/// current route, and normally partially obscures such routes.
///
/// For example, when a dialog is on the screen, the page below the dialog is
/// usually darkened by the modal barrier.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/modal_barrier.dart`

import FlutterSwiftBridge

// MARK: - ModalBarrier

/// A widget that blocks user interaction.
///
/// When [dismissible] is true, tapping the barrier calls the [onDismiss]
/// callback. If [onDismiss] is nil and dismissible is true, the barrier
/// tap is still absorbed but no action is taken (Navigator is not yet
/// available in this Swift port).
///
/// The barrier renders as a full-screen colored overlay that absorbs all
/// pointer events.
///
/// **Dart Source:** `modal_barrier.dart:128`
public class ModalBarrier: StatelessWidget {
    /// If non-nil, fill the barrier with this color.
    public let color: Color?

    /// Whether tapping the barrier will dismiss it.
    ///
    /// If true and [onDismiss] is non-nil, [onDismiss] will be called.
    /// If false, tapping the barrier will do nothing.
    public let dismissible: Bool

    /// Called when the barrier is being dismissed.
    ///
    /// If non-nil, [onDismiss] will be called in place of popping the current
    /// route. It is up to the callback to handle dismissing the barrier.
    ///
    /// This field is ignored if [dismissible] is false.
    public let onDismiss: (() -> Void)?

    /// Semantics label used for the barrier if it is [dismissible].
    public let semanticsLabel: String?

    public init(
        key: (any Key)? = nil,
        color: Color? = nil,
        dismissible: Bool = true,
        onDismiss: (() -> Void)? = nil,
        semanticsLabel: String? = nil
    ) {
        self.color = color
        self.dismissible = dismissible
        self.onDismiss = onDismiss
        self.semanticsLabel = semanticsLabel
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        // Build the visual barrier: a full-screen colored (or transparent) box
        let colorChild: Widget? = color != nil ? ColoredBox(color: color!) : nil
        let constrainedBarrier: Widget = ConstrainedBox(
            constraints: BoxConstraints.expand(),
            child: colorChild
        )

        // Wrap with a Listener to capture pointer-down events for dismissal
        let handleDismiss: (() -> Void)? = dismissible ? {
            self.onDismiss?()
        } : nil

        let barrier: Widget = Listener(
            onPointerDown: handleDismiss != nil ? { _ in handleDismiss!() } : nil,
            behavior: .opaque,
            child: constrainedBarrier
        )

        return barrier
    }
}
