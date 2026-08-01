// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of TargetPlatform for image_provider.dart dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/platform.dart`
/// **Lines:** 8-46
///
/// NOTE: This is a minimal stub to support ImageProvider migration.
/// A full TargetPlatform implementation will be completed in a future task.

// MARK: - TargetPlatform

/// The platform that user interaction should adapt to target.
///
/// The `defaultTargetPlatform` getter returns the current platform.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/platform.dart`
/// **Lines:** 8-46
public enum TargetPlatform: String, Sendable, Hashable, CaseIterable {
    /// Android
    ///
    /// **Dart Source:** `platform.dart:9`
    case android

    /// Fuchsia
    ///
    /// **Dart Source:** `platform.dart:11`
    case fuchsia

    /// iOS
    ///
    /// **Dart Source:** `platform.dart:13`
    case iOS

    /// Linux
    ///
    /// **Dart Source:** `platform.dart:15`
    case linux

    /// macOS
    ///
    /// **Dart Source:** `platform.dart:17`
    case macOS

    /// Windows
    ///
    /// **Dart Source:** `platform.dart:19`
    case windows
}
