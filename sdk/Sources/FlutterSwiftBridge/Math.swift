// Math.swift
// Flutter Swift Bridge
//
// **Dart Source:** `engine/src/flutter/lib/ui/math.dart`

import Foundation

// MARK: - Clamping Functions

/// Same as Swift's `Double.clamped(to:)` but optimized for non-optional Double.
///
/// This is faster because it avoids polymorphism, boxing, and special cases for
/// floating point numbers.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/math.dart:7-25`
/// **Original Name:** `clampDouble`
///
/// DIFFERENCE FROM DART: Added `@inlinable` attribute for performance optimization.
/// REASON: Swift optimization for frequently-called function; no behavior change.
@inlinable
public func clampDouble(_ x: Double, _ min: Double, _ max: Double) -> Double {
    assert(min <= max && !max.isNaN && !min.isNaN)
    if x < min {
        return min
    }
    if x > max {
        return max
    }
    if x.isNaN {
        return max
    }
    return x
}
