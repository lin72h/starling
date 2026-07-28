// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - SizeChangedLayoutNotification

/// Indicates that the size of one of the descendants of the object receiving
/// this notification has changed, and that therefore any assumptions about that
/// layout are no longer valid.
///
/// For example, sent by the `SizeChangedLayoutNotifier` widget whenever that
/// widget changes size.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/size_changed_layout_notifier.dart:34-37`
public class SizeChangedLayoutNotification: LayoutChangedNotification {
    /// Create a new `SizeChangedLayoutNotification`.
    public override init() {
        super.init()
    }
}

// MARK: - SizeChangedLayoutNotifier

/// A widget that automatically dispatches a `SizeChangedLayoutNotification`
/// when the layout dimensions of its child change.
///
/// The notification is not sent for the initial layout (since the size doesn't
/// change in that case, it's just established).
///
/// To listen for the notification dispatched by this widget, use a
/// `NotificationListener<SizeChangedLayoutNotification>`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/size_changed_layout_notifier.dart:58-71`
public class SizeChangedLayoutNotifier: SingleChildRenderObjectWidget {

    /// Creates a `SizeChangedLayoutNotifier` that dispatches layout changed
    /// notifications when `child` changes layout size.
    ///
    /// **Dart Source:** `size_changed_layout_notifier.dart:61`
    public override init(key: (any Key)? = nil, child: Widget? = nil) {
        super.init(key: key, child: child)
    }

    /// **Dart Source:** `size_changed_layout_notifier.dart:64-70`
    public override func createRenderObject(_ context: any BuildContext) -> RenderObject {
        return _RenderSizeChangedWithCallback(
            onLayoutChangedCallback: { [weak context] in
                SizeChangedLayoutNotification().dispatch(context)
            }
        )
    }
}

// MARK: - _RenderSizeChangedWithCallback

/// A render object that calls a callback when its size changes.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/size_changed_layout_notifier.dart:73-96`
private class _RenderSizeChangedWithCallback: RenderProxyBox {

    /// **Dart Source:** `size_changed_layout_notifier.dart:74-75`
    init(child: RenderBox? = nil, onLayoutChangedCallback: @escaping VoidCallback) {
        self.onLayoutChangedCallback = onLayoutChangedCallback
        super.init(child: child)
    }

    // There's a 1:1 relationship between the _RenderSizeChangedWithCallback and
    // the `context` that is captured by the closure created by createRenderObject
    // above to assign to onLayoutChangedCallback, and thus we know that the
    // onLayoutChangedCallback will never change nor need to change.

    /// **Dart Source:** `size_changed_layout_notifier.dart:82`
    let onLayoutChangedCallback: VoidCallback

    /// **Dart Source:** `size_changed_layout_notifier.dart:84`
    private var _oldSize: Size?

    /// **Dart Source:** `size_changed_layout_notifier.dart:87-95`
    override func performLayout() {
        super.performLayout()
        // Don't send the initial notification, or this will be SizeObserver all
        // over again!
        if _oldSize != nil && size != _oldSize {
            onLayoutChangedCallback()
        }
        _oldSize = size
    }
}
