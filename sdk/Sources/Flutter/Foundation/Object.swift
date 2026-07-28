// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - Object Runtime Type
/// Utility function for getting the runtime type of an object.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/object.dart`
/// **Lines:** 5-18

/// Framework code should use this method in favor of calling `String(describing:)` on
/// `type(of:)`.
///
/// Calling `String(describing:)` on a runtime type is a non-trivial operation that can
/// negatively impact performance. If asserts are enabled (debug mode), this function will
/// return `String(describing: type(of: object))`; otherwise, it will return the
/// `optimizedValue`, which must be a simple constant string.
///
/// - Parameters:
///   - object: The object whose runtime type should be returned.
///   - optimizedValue: A simple constant string to return in release mode.
/// - Returns: The runtime type string in debug mode, or the optimized value in release mode.
///
/// **Dart Source:** `object.dart:5-18`
public func objectRuntimeType(_ object: Any?, _ optimizedValue: String) -> String {
    #if DEBUG
    if let obj = object {
        return String(describing: type(of: obj))
    } else {
        return "nil"
    }
    #else
    return optimizedValue
    #endif
}
