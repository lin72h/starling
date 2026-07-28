// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - Debug Flags
//
// Debug flag variables from debug.dart referenced by framework.dart.

/// Whether to print a debug message when dirty widgets are rebuilt.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugPrintRebuildDirtyWidgets = false

/// Whether to print the call stacks when dirty widgets are rebuilt.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugPrintBuildScope = false

/// Whether to print the call stacks when global keys are duplicated.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugPrintGlobalKeyedWidgetLifecycle = false

/// Whether to check for keys that are used by more than one widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugCheckForReturnedFutures = false

/// Whether to profile the build phase.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugProfileBuildsEnabled = false

/// Whether to profile the build phase on a per-widget basis.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugProfileBuildsEnabledUserWidgets = false

/// Whether to highlight nodes that are repainted.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/debug.dart`
nonisolated(unsafe) public var debugHighlightDeprecatedWidgets = false
