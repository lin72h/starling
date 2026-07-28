// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of ServicesBinding for PaintingBinding dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/services/binding.dart`
/// **Lines:** 45-394
///
/// NOTE: This is a minimal stub to support PaintingBinding migration.
/// A full ServicesBinding implementation will be completed in a future task.

import FlutterSwiftBridge

// MARK: - ServicesBinding Protocol

/// Listens for platform messages and directs them to the `defaultBinaryMessenger`.
///
/// The `ServicesBinding` also registers a `LicenseEntryCollector` that exposes
/// the licenses found in the `LICENSE` file stored at the root of the asset
/// bundle, and implements the `ext.flutter.evict` service extension.
///
/// **Dart Source:** `packages/flutter/lib/src/services/binding.dart`
/// **Lines:** 45-394
public protocol ServicesBinding: AnyObject {
    /// Handle a system message.
    ///
    /// This method is called when a system message is received. Subclasses
    /// can override this method to handle specific system messages.
    ///
    /// **Dart Source:** `binding.dart:197-219`
    func handleSystemMessage(_ message: Any) async -> Void

    /// Called when an asset is evicted from the asset bundle.
    ///
    /// Subclasses can override this method to take action when assets are evicted.
    ///
    /// **Dart Source:** `binding.dart:164-183`
    func evict(_ asset: String)

    /// Called when the system reports that it is running low on memory.
    ///
    /// **Dart Source:** `binding.dart:221-224`
    func handleMemoryPressure()
}

// MARK: - Default Implementations

extension ServicesBinding {
    /// Default implementation of handleSystemMessage.
    ///
    /// **Dart Source:** `binding.dart:197-219`
    public func handleSystemMessage(_ message: Any) async {
        // Default no-op implementation
    }

    /// Default implementation of evict.
    ///
    /// **Dart Source:** `binding.dart:164-183`
    public func evict(_ asset: String) {
        // Default no-op implementation
    }

    /// Default implementation of handleMemoryPressure.
    ///
    /// **Dart Source:** `binding.dart:221-224`
    public func handleMemoryPressure() {
        // Default no-op implementation
    }
}
