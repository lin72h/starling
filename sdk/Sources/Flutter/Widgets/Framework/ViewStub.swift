// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - View Stub

/// Minimal stub for the `View` widget from `widgets/view.dart`.
///
/// Provides `View.of(context)` which returns the `FlutterView` for the given
/// context. The full `View` widget implementation will replace this stub.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/view.dart`
public enum View {
    /// Returns the `FlutterView` that the given context is rendering into.
    ///
    /// **Dart Source:** `view.dart` (View.of)
    public static func of(_ context: any BuildContext) -> FlutterView {
        // Stub: In full implementation, this walks the element tree to find
        // the nearest View widget's FlutterView.
        fatalError("View.of() requires full View widget migration")
    }
}
