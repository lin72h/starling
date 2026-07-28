// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - WidgetsBinding Stubs
//
// Minimal stubs for binding.dart types needed by framework.dart.
// These will be replaced by full implementations when binding.dart is migrated.

/// Stub for `WidgetsBinding`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/binding.dart`
public class WidgetsBinding {
    /// The singleton instance of WidgetsBinding.
    nonisolated(unsafe) public static var instance: WidgetsBinding = WidgetsBinding()

    /// The build owner for this binding.
    public var buildOwner: BuildOwner?

    /// Creates a widgets binding.
    public init() {}
}
