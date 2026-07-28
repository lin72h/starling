// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

// MARK: - Physics Utilities

/// Whether two doubles are within a given distance of each other.
///
/// The `epsilon` argument must be positive.
/// The `a` and `b` arguments may be nil. A nil value is only considered
/// near-equal to another nil value.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/utils.dart`
/// **Original Name:** `nearEqual`
/// **Lines:** 10-16
public func nearEqual(_ a: Double?, _ b: Double?, _ epsilon: Double) -> Bool {
    assert(epsilon >= 0.0, "epsilon must be non-negative")
    if a == nil || b == nil {
        return a == b
    }
    return (a! > (b! - epsilon)) && (a! < (b! + epsilon)) || a == b
}

/// Whether a double is within a given distance of zero.
///
/// The epsilon argument must be positive.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/utils.dart`
/// **Original Name:** `nearZero`
/// **Lines:** 21
public func nearZero(_ a: Double, _ epsilon: Double) -> Bool {
    return nearEqual(a, 0.0, epsilon)
}
