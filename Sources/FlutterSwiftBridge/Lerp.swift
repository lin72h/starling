// Lerp.swift
// Flutter Swift Bridge
//
// **Dart Source:** `engine/src/flutter/lib/ui/lerp.dart`

import Foundation

// MARK: - Linear Interpolation Functions

/// Linearly interpolate between two numbers, `a` and `b`, by an extrapolation
/// factor `t`.
///
/// When `a` and `b` are equal or both NaN, `a` is returned. Otherwise,
/// `a`, `b`, and `t` are required to be finite or null, and the result of `a +
/// (b - a) * t` is returned, where nulls are defaulted to 0.0.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/lerp.dart:7-23`
/// **Original Name:** `lerpDouble`
///
/// DIFFERENCE FROM DART: Using `Double?` instead of `num?` since Swift has no `num` type.
/// REASON: Swift's type system requires concrete numeric types; Double is the closest equivalent.
public func lerpDouble(_ a: Double?, _ b: Double?, _ t: Double) -> Double? {
    // When a and b are equal or both NaN, return a
    if a == b || (a?.isNaN ?? false) && (b?.isNaN ?? false) {
        return a
    }
    // Null values default to 0.0
    let aValue = a ?? 0.0
    let bValue = b ?? 0.0
    assert(aValue.isFinite, "Cannot interpolate between finite and non-finite values")
    assert(bValue.isFinite, "Cannot interpolate between finite and non-finite values")
    assert(t.isFinite, "t must be finite when interpolating between values")
    return aValue * (1.0 - t) + bValue * t
}

/// Linearly interpolate between two doubles.
///
/// Same as `lerpDouble` but specialized for non-null `Double` type.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/lerp.dart:25-32`
/// **Original Name:** `_lerpDouble`
///
/// Note: This doesn't match _lerpInt to preserve specific behaviors when dealing
/// with infinity and nan.
internal func _lerpDouble(_ a: Double, _ b: Double, _ t: Double) -> Double {
    // This doesn't match _lerpInt to preserve specific behaviors when dealing
    // with infinity and nan.
    return a * (1.0 - t) + b * t
}

/// Linearly interpolate between two integers.
///
/// Same as `lerpDouble` but specialized for non-null `Int64` type.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/lerp.dart:34-39`
/// **Original Name:** `_lerpInt`
///
/// DIFFERENCE FROM DART: Using `Int64` instead of `int` per migration guide type mapping.
/// REASON: Swift Int64 matches Dart's 64-bit integers for consistency.
internal func _lerpInt(_ a: Int64, _ b: Int64, _ t: Double) -> Double {
    return Double(a) + Double(b - a) * t
}
