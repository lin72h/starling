// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - FlutterSwiftBridge Module
/// FlutterSwiftBridge - Swift implementation of Flutter's dart:ui layer.
///
/// This module provides a pure Swift implementation of the dart:ui APIs,
/// creating a bridge between the Flutter framework (Swift) and the Flutter
/// C++ engine. It eliminates the Dart VM dependency entirely.
///
/// ## Architecture
/// ```
/// Flutter Framework (Swift - future)
///          ↓
///     dart:ui layer (Swift - this module)
///          ↓
///     C++ Engine (Flutter engine core)
/// ```
///
/// ## Key Features
/// - Swift 6 native C++ interoperability
/// - Direct C++ calls without Dart VM overhead
/// - Automatic memory management via Swift ARC and SWIFT_SHARED_REFERENCE
/// - Strong type safety and compile-time guarantees
///
/// ## Migration Status
/// This module is being migrated from Dart to Swift. Each file includes
/// references to the original Dart source for traceability.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/`

// MARK: - Module Version
/// The version of the FlutterSwiftBridge module.
public let flutterSwiftBridgeVersion = "0.1.0"

// MARK: - Error Types
/// Errors that can occur in the FlutterSwiftBridge module.
///
/// **Note:** This is a Swift-specific addition for error handling.
/// Dart uses exceptions which are translated to Swift error types.
public enum FlutterSwiftBridgeError: Error, Equatable {
    /// An invalid argument was provided.
    case invalidArgument(String)

    /// A required precondition was not met.
    case preconditionFailed(String)

    /// An operation was attempted in an invalid state.
    case invalidState(String)

    /// A resource could not be found.
    case resourceNotFound(String)
}
