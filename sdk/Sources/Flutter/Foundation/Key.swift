// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Key types for identifying Widgets, Elements and SemanticsNodes.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`

// MARK: - Key

/// A Key is an identifier for Widgets, Elements, and SemanticsNodes.
///
/// A new widget will only be used to update an existing element if its key is
/// the same as the key of the current widget associated with the element.
///
/// Keys must be unique amongst the Elements with the same parent.
///
/// Subclasses of Key should either subclass LocalKey or GlobalKey.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`
/// **Lines:** 27-41
public protocol Key: Hashable, CustomStringConvertible {}

// MARK: - LocalKey

/// A key that is not a GlobalKey.
///
/// Keys must be unique amongst the Elements with the same parent. By
/// contrast, GlobalKeys must be unique across the entire app.
///
/// See also:
///
///  * Widget.key, which discusses how widgets use keys.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`
/// **Lines:** 43-55
public protocol LocalKey: Key {}

// MARK: - UniqueKey

/// A key that is only equal to itself.
///
/// This cannot be created with a const constructor because that implies that
/// all instantiated keys would be the same instance and therefore not be unique.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`
/// **Lines:** 57-72
public final class UniqueKey: LocalKey {
    /// Creates a key that is equal only to itself.
    ///
    /// The key cannot be created with a const constructor because that implies
    /// that all instantiated keys would be the same instance and therefore not
    /// be unique.
    ///
    /// **Dart Source:** `key.dart:62-68`
    public init() {}

    /// **Dart Source:** `key.dart:96-101`
    public static func == (lhs: UniqueKey, rhs: UniqueKey) -> Bool {
        return lhs === rhs  // Identity comparison
    }

    /// Hash based on object identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /// **Dart Source:** `key.dart:70-71`
    public var description: String {
        return "[#\(shortHash(self))]"
    }
}

// MARK: - ValueKey

/// A key that uses a value of a particular type to identify itself.
///
/// A `ValueKey<T>` is equal to another `ValueKey<T>` if, and only if, their
/// values are equal.
///
/// This class can be subclassed to create value keys that will not be equal to
/// other value keys that happen to use the same value. If the subclass is
/// private, this results in a value key type that cannot collide with keys from
/// other sources, which could be useful, for example, if the keys are being
/// used as fallbacks in the same scope as keys supplied from another widget.
///
/// See also:
///
///  * Widget.key, which discusses how widgets use keys.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`
/// **Lines:** 74-116
public struct ValueKey<T: Hashable>: LocalKey {
    /// The value to which this key delegates its equality.
    ///
    /// **Dart Source:** `key.dart:92-93`
    public let value: T

    /// Creates a key that delegates its equality to the given value.
    ///
    /// **Dart Source:** `key.dart:89-90`
    public init(_ value: T) {
        self.value = value
    }

    /// **Dart Source:** `key.dart:95-101`
    public static func == (lhs: ValueKey<T>, rhs: ValueKey<T>) -> Bool {
        return lhs.value == rhs.value
    }

    /// **Dart Source:** `key.dart:103-104`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    /// **Dart Source:** `key.dart:106-115`
    public var description: String {
        let valueString: String
        if T.self == String.self {
            valueString = "<'\(value)'>"
        } else {
            valueString = "<\(value)>"
        }
        // In Dart, there's a workaround for SDK issue #33297 to check if
        // runtimeType is exactly ValueKey<T>. In Swift, we simplify to always
        // return the format without the type prefix since Swift's type system
        // doesn't have this issue.
        return "[\(valueString)]"
    }
}

// MARK: - Key Factory Function

/// Construct a `ValueKey<String>` with the given `String`.
///
/// This is the simplest way to create keys.
///
/// This free function serves as the Swift equivalent of the Dart factory
/// constructor `Key(String value)`, which creates a `ValueKey<String>`.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/key.dart`
/// **Lines:** 30-33
/// ```dart
/// const factory Key(String value) = ValueKey<String>;
/// ```
///
/// **Swift Note:** Named `makeKey` instead of `Key` because Swift does not allow
/// a free function with the same name as a protocol in the same module.
///
/// - Parameter value: The string value that identifies this key.
/// - Returns: A `ValueKey<String>` with the given value.
public func makeKey(_ value: String) -> ValueKey<String> {
    return ValueKey(value)
}
