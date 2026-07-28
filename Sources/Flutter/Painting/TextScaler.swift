// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Types for scaling text for better readability.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_scaler.dart`

import FlutterSwiftBridge

// MARK: - TextScaler Protocol

/// A type that describes how textual contents should be scaled for better
/// readability.
///
/// The ``scale(_:)`` method computes the scaled font size given the original
/// unscaled font size specified by app developers.
///
/// The `==` operator defines the equality of 2 `TextScaler`s, which the
/// framework uses to determine whether text widgets should rebuild when their
/// `TextScaler` changes. Consider overriding the `==` operator if applicable
/// to avoid unnecessary rebuilds.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_scaler.dart`
/// **Original Name:** `TextScaler`
/// **Lines:** 19-76
///
/// NOTE: Dart's `textScaleFactor` getter was deprecated and intentionally not migrated.
/// See: text_scaler.dart:54-58 - @Deprecated('Use of textScaleFactor was deprecated...')
public protocol TextScaler: Equatable, CustomStringConvertible {
    /// Computes the scaled font size (in logical pixels) with the given unscaled
    /// `fontSize` (in logical pixels).
    ///
    /// The input `fontSize` must be finite and non-negative.
    ///
    /// When given the same `fontSize` input, this method returns the same value.
    /// The output of a larger input `fontSize` is typically larger than that of a
    /// smaller input, but on unusual occasions they may produce the same output.
    ///
    /// **Dart Source:** `text_scaler.dart:45`
    func scale(_ fontSize: Double) -> Double

    /// Returns a new `TextScaler` that restricts the scaled font size to within
    /// the range `[minScaleFactor * fontSize, maxScaleFactor * fontSize]`.
    ///
    /// **Dart Source:** `text_scaler.dart:62-75`
    func clamp(minScaleFactor: Double, maxScaleFactor: Double) -> any TextScaler
}

// MARK: - TextScalers Namespace

/// Namespace for `TextScaler` factory methods and constants.
///
/// Since Swift protocols cannot have static stored properties or factory
/// constructors, this enum provides a namespace for creating `TextScaler`
/// instances.
///
/// **Dart Source:** `text_scaler.dart:26-32` (factory constructor and noScaling constant)
public enum TextScalers {
    /// A `TextScaler` that doesn't scale the input font size.
    ///
    /// This is equivalent to `TextScalers.linear(1.0)`, the `scale`
    /// implementation always returns the input font size as-is.
    ///
    /// **Dart Source:** `text_scaler.dart:32`
    nonisolated(unsafe) public static let noScaling: any TextScaler = LinearTextScaler(1.0)

    /// Creates a proportional `TextScaler` that scales the incoming font size by
    /// multiplying it with the given `textScaleFactor`.
    ///
    /// **Dart Source:** `text_scaler.dart:26`
    public static func linear(_ textScaleFactor: Double) -> any TextScaler {
        LinearTextScaler(textScaleFactor)
    }
}

// MARK: - LinearTextScaler

/// A proportional `TextScaler` that scales the incoming font size by
/// multiplying it with a `textScaleFactor`.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_scaler.dart`
/// **Original Name:** `_LinearTextScaler`
/// **Lines:** 78-115
public struct LinearTextScaler: TextScaler, Hashable, Sendable {
    /// The scale factor to multiply by.
    ///
    /// **Dart Source:** `text_scaler.dart:82`
    public let textScaleFactor: Double

    /// Creates a linear text scaler with the given scale factor.
    ///
    /// **Dart Source:** `text_scaler.dart:79`
    public init(_ textScaleFactor: Double) {
        assert(textScaleFactor >= 0, "textScaleFactor must be non-negative")
        self.textScaleFactor = textScaleFactor
    }

    /// Computes the scaled font size by multiplying `fontSize` by `textScaleFactor`.
    ///
    /// **Dart Source:** `text_scaler.dart:84-89`
    public func scale(_ fontSize: Double) -> Double {
        assert(fontSize >= 0, "fontSize must be non-negative")
        assert(fontSize.isFinite, "fontSize must be finite")
        return fontSize * textScaleFactor
    }

    /// Returns a new `TextScaler` whose scale factor is clamped to the given range.
    ///
    /// If the clamped value equals the current `textScaleFactor`, returns `self`.
    ///
    /// **Dart Source:** `text_scaler.dart:91-100`
    public func clamp(minScaleFactor: Double = 0, maxScaleFactor: Double = Double.infinity) -> any TextScaler {
        assert(maxScaleFactor >= minScaleFactor, "maxScaleFactor must be >= minScaleFactor")
        assert(!maxScaleFactor.isNaN, "maxScaleFactor must not be NaN")
        assert(minScaleFactor.isFinite, "minScaleFactor must be finite")
        assert(minScaleFactor >= 0, "minScaleFactor must be non-negative")

        let newScaleFactor = clampDouble(textScaleFactor, minScaleFactor, maxScaleFactor)
        return newScaleFactor == textScaleFactor ? self : LinearTextScaler(newScaleFactor)
    }

    // MARK: - Equatable

    /// **Dart Source:** `text_scaler.dart:102-108`
    public static func == (lhs: LinearTextScaler, rhs: LinearTextScaler) -> Bool {
        lhs.textScaleFactor == rhs.textScaleFactor
    }

    // MARK: - Hashable

    /// **Dart Source:** `text_scaler.dart:110-111`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(textScaleFactor)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `text_scaler.dart:113-114`
    public var description: String {
        textScaleFactor == 1.0 ? "no scaling" : "linear (\(textScaleFactor)x)"
    }
}

// MARK: - ClampedTextScaler

/// A `TextScaler` that clamps the scaled font size to a given range.
///
/// This wraps a `LinearTextScaler` and clamps its output. In Dart, this wraps
/// any `TextScaler`, but since our only concrete non-clamped scaler is
/// `LinearTextScaler`, we store it directly to avoid type-erasure complexity.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/text_scaler.dart`
/// **Original Name:** `_ClampedTextScaler`
/// **Lines:** 117-156
public struct ClampedTextScaler: TextScaler, Hashable, Sendable {
    /// The wrapped linear scaler.
    ///
    /// **Dart Source:** `text_scaler.dart:119`
    public let scaler: LinearTextScaler

    /// The minimum scale factor.
    ///
    /// **Dart Source:** `text_scaler.dart:120`
    public let minScale: Double

    /// The maximum scale factor.
    ///
    /// **Dart Source:** `text_scaler.dart:121`
    public let maxScale: Double

    /// Creates a clamped text scaler wrapping the given linear scaler.
    ///
    /// **Dart Source:** `text_scaler.dart:118`
    public init(_ scaler: LinearTextScaler, minScale: Double, maxScale: Double) {
        assert(maxScale > minScale, "maxScale must be > minScale")
        self.scaler = scaler
        self.minScale = minScale
        self.maxScale = maxScale
    }

    /// Computes the scaled font size, clamped to the configured range.
    ///
    /// **Dart Source:** `text_scaler.dart:126-131`
    public func scale(_ fontSize: Double) -> Double {
        assert(fontSize >= 0, "fontSize must be non-negative")
        assert(fontSize.isFinite, "fontSize must be finite")
        return clampDouble(scaler.scale(fontSize), minScale * fontSize, maxScale * fontSize)
    }

    /// Returns a new `TextScaler` with narrowed clamping bounds.
    ///
    /// If `minScaleFactor == maxScaleFactor`, returns a `LinearTextScaler` instead.
    ///
    /// **Dart Source:** `text_scaler.dart:133-138`
    public func clamp(minScaleFactor: Double = 0, maxScaleFactor: Double = Double.infinity) -> any TextScaler {
        if minScaleFactor == maxScaleFactor {
            return LinearTextScaler(minScaleFactor)
        }
        return ClampedTextScaler(
            scaler,
            minScale: max(minScaleFactor, minScale),
            maxScale: min(maxScaleFactor, maxScale)
        )
    }

    // MARK: - Equatable

    /// **Dart Source:** `text_scaler.dart:140-149`
    public static func == (lhs: ClampedTextScaler, rhs: ClampedTextScaler) -> Bool {
        lhs.minScale == rhs.minScale
            && lhs.maxScale == rhs.maxScale
            && lhs.scaler == rhs.scaler
    }

    // MARK: - Hashable

    /// **Dart Source:** `text_scaler.dart:151-152`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(scaler)
        hasher.combine(minScale)
        hasher.combine(maxScale)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `text_scaler.dart:154-155`
    public var description: String {
        "\(scaler) clamped [\(minScale), \(maxScale)]"
    }
}

// MARK: - Existential TextScaler Equality

/// Equality operator for existential `TextScaler` values.
///
/// This enables comparing `any TextScaler` values by type-checking and
/// delegating to the concrete type's equality operator.
public func == (lhs: any TextScaler, rhs: any TextScaler) -> Bool {
    if let lhsLinear = lhs as? LinearTextScaler, let rhsLinear = rhs as? LinearTextScaler {
        return lhsLinear == rhsLinear
    }
    if let lhsClamped = lhs as? ClampedTextScaler, let rhsClamped = rhs as? ClampedTextScaler {
        return lhsClamped == rhsClamped
    }
    return false
}

/// Inequality operator for existential `TextScaler` values.
public func != (lhs: any TextScaler, rhs: any TextScaler) -> Bool {
    !(lhs == rhs)
}
