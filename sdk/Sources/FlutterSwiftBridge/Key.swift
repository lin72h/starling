// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Swift implementation of Flutter's key.dart
///
/// **Dart Source:** `engine/src/flutter/lib/ui/key.dart`
///
/// This file provides the Swift implementation of key event types
/// and data structures for keyboard input handling.

// MARK: - KeyEventType

/// The type of a key event.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/key.dart:7-28`
/// **Original Name:** `KeyEventType`
///
/// Must match the KeyEventType enum in ui/window/key_data.h.
public enum KeyEventType {
    /// The key is pressed.
    ///
    /// **Dart Source:** `key.dart:10-11`
    case down

    /// The key is released.
    ///
    /// **Dart Source:** `key.dart:13-14`
    case up

    /// The key is held, causing a repeated key input.
    ///
    /// **Dart Source:** `key.dart:16-17`
    case `repeat`

    /// Returns a human-readable label for the key event type.
    ///
    /// **Dart Source:** `key.dart:21-27`
    /// **Original:**
    /// ```dart
    /// String get label {
    ///   return switch (this) {
    ///     down => 'Key Down',
    ///     up => 'Key Up',
    ///     repeat => 'Key Repeat',
    ///   };
    /// }
    /// ```
    public var label: String {
        switch self {
        case .down:
            return "Key Down"
        case .up:
            return "Key Up"
        case .repeat:
            return "Key Repeat"
        }
    }
}

// MARK: - KeyEventDeviceType

/// The source device for the key event.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/key.dart:30-62`
/// **Original Name:** `KeyEventDeviceType`
///
/// Not all platforms supply an accurate type.
/// Must match the KeyEventDeviceType enum in ui/window/key_data.h.
public enum KeyEventDeviceType {
    /// The device is a keyboard.
    ///
    /// **Dart Source:** `key.dart:35-36`
    case keyboard

    /// The device is a directional pad on something like a television remote
    /// control or similar.
    ///
    /// **Dart Source:** `key.dart:38-40`
    case directionalPad

    /// The device is a gamepad button.
    ///
    /// **Dart Source:** `key.dart:42-43`
    case gamepad

    /// The device is a joystick button.
    ///
    /// **Dart Source:** `key.dart:45-46`
    case joystick

    /// The device is a device connected to an HDMI bus.
    ///
    /// **Dart Source:** `key.dart:48-49`
    case hdmi

    /// Returns a human-readable label for the key event device type.
    ///
    /// **Dart Source:** `key.dart:53-61`
    /// **Original:**
    /// ```dart
    /// String get label {
    ///   return switch (this) {
    ///     keyboard => 'Keyboard',
    ///     directionalPad => 'Directional Pad',
    ///     gamepad => 'Gamepad',
    ///     joystick => 'Joystick',
    ///     hdmi => 'HDMI',
    ///   };
    /// }
    /// ```
    public var label: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .directionalPad:
            return "Directional Pad"
        case .gamepad:
            return "Gamepad"
        case .joystick:
            return "Joystick"
        case .hdmi:
            return "HDMI"
        }
    }
}

// MARK: - KeyData

/// Information about a key event.
///
/// **Dart Source:** `engine/src/flutter/lib/ui/key.dart:64-247`
/// **Original Name:** `KeyData`
///
/// DIFFERENCE FROM DART: Uses `struct` instead of `class`
/// REASON: KeyData is an immutable value type (all `final` fields, `const` constructor)
///         which maps to Swift struct with value semantics
///
/// DIFFERENCE FROM DART: `timeStamp` uses `TimeInterval` (Double, seconds) instead of `Duration`
/// REASON: Swift has no built-in Duration type like Dart; TimeInterval is the standard
///         Swift type for time intervals. The value represents seconds (Double).
public struct KeyData {
    /// Creates an object that represents a key event.
    ///
    /// **Dart Source:** `key.dart:66-75`
    /// **Original:**
    /// ```dart
    /// const KeyData({
    ///   required this.timeStamp,
    ///   required this.type,
    ///   required this.physical,
    ///   required this.logical,
    ///   required this.character,
    ///   required this.synthesized,
    ///   this.deviceType = KeyEventDeviceType.keyboard,
    /// });
    /// ```
    public init(
        timeStamp: TimeInterval,
        type: KeyEventType,
        physical: Int64,
        logical: Int64,
        character: String?,
        synthesized: Bool,
        deviceType: KeyEventDeviceType = .keyboard
    ) {
        self.timeStamp = timeStamp
        self.type = type
        self.physical = physical
        self.logical = logical
        self.character = character
        self.synthesized = synthesized
        self.deviceType = deviceType
    }

    /// Time of event dispatch, relative to an arbitrary timeline.
    ///
    /// For synthesized events, the `timeStamp` might not be the actual time that
    /// the key press or release happens.
    ///
    /// **Dart Source:** `key.dart:77-81`
    /// **Original:** `final Duration timeStamp`
    ///
    /// DIFFERENCE FROM DART: Uses `TimeInterval` (Double, seconds) instead of `Duration`
    /// REASON: Swift has no built-in Duration type; TimeInterval is idiomatic Swift
    public let timeStamp: TimeInterval

    /// The type of the event.
    ///
    /// **Dart Source:** `key.dart:83-84`
    /// **Original:** `final KeyEventType type`
    public let type: KeyEventType

    /// Describes what type of device (keyboard, directional pad, etc.) this event
    /// originated from.
    ///
    /// **Dart Source:** `key.dart:86-88`
    /// **Original:** `final KeyEventDeviceType deviceType`
    public let deviceType: KeyEventDeviceType

    /// The key code for the physical key that has changed.
    ///
    /// **Dart Source:** `key.dart:90-91`
    /// **Original:** `final int physical`
    public let physical: Int64

    /// The key code for the logical key that has changed.
    ///
    /// **Dart Source:** `key.dart:93-94`
    /// **Original:** `final int logical`
    public let logical: Int64

    /// Character input from the event.
    ///
    /// Ignored for up events.
    ///
    /// **Dart Source:** `key.dart:96-99`
    /// **Original:** `final String? character`
    public let character: String?

    /// If `synthesized` is true, this event does not correspond to a native
    /// event.
    ///
    /// Although most of Flutter's keyboard events are transformed from native
    /// events, some events are not based on native events, and are synthesized
    /// only to conform Flutter's key event model (as documented in the
    /// `HardwareKeyboard` class in the framework).
    ///
    /// For example, some key downs or ups might be lost when the window loses
    /// focus. Some platforms provide ways to query whether a key is being held.
    /// If the embedder detects an inconsistency between its internal record and
    /// the state returned by the system, the embedder will synthesize a
    /// corresponding event to synchronize the state without breaking the event
    /// model.
    ///
    /// As another example, macOS treats CapsLock in a special way by sending down
    /// and up events at the down of alternate presses to indicate the direction
    /// in which the lock is toggled instead of that the physical key is going. A
    /// macOS embedder should normalize the behavior by converting a native down
    /// event into a down event followed immediately by a synthesized up event,
    /// and the native up event also into a down event followed immediately by a
    /// synthesized up event.
    ///
    /// Synthesized events do not have a trustworthy `timeStamp`, and should not
    /// be processed as if the key actually went down or up at the time of the
    /// callback.
    ///
    /// `KeyRepeatEvent` is never synthesized.
    ///
    /// **Dart Source:** `key.dart:101-129`
    /// **Original:** `final bool synthesized`
    public let synthesized: Bool

    // MARK: - Private Helper Methods

    /// Returns the bits that are not included in `valueMask`, shifted to the right.
    ///
    /// For example, if the input is 0x12abcdabcd, then the result is 0x12.
    ///
    /// **Dart Source:** `key.dart:131-162`
    /// **Original:** `static int _nonValueBits(int n)`
    ///
    /// DIFFERENCE FROM DART: Removed web platform check (`identical(0, 0.0)`)
    /// REASON: Swift doesn't run on web; always use direct bit shift
    ///
    /// DIFFERENCE FROM DART: Uses `Int64` for 64-bit integer operations
    /// REASON: Swift needs explicit 64-bit type for consistent cross-platform behavior
    private static func nonValueBits(_ n: Int64) -> Int64 {
        // valueMask = 0x000FFFFFFFF (32 bits of value)
        let valueMaskWidth = 32
        // JS only supports up to 2^53 - 1, therefore non-value bits can only
        // contain (maxSafeIntegerWidth - valueMaskWidth) bits.
        let maxSafeIntegerWidth = 52
        let nonValueMask: Int64 = (1 << (maxSafeIntegerWidth - valueMaskWidth)) - 1

        // DIFFERENCE FROM DART: No web platform check needed
        // DART: `if (identical(0, 0.0)) { return (n / divisorForValueMask).floor() & nonValueMask; }`
        // Swift doesn't run on web, so we always use direct bit shift
        return (n >> valueMaskWidth) & nonValueMask
    }

    /// Returns a string representation of the logical key code with plane description.
    ///
    /// **Dart Source:** `key.dart:164-195`
    /// **Original:** `String _logicalToString()`
    private func logicalToString() -> String {
        let result = "0x\(String(logical, radix: 16))"
        let planeNum = Self.nonValueBits(logical) & 0x0FF
        let planeDescription: String = {
            switch planeNum {
            case 0x000:
                return " (Unicode)"
            case 0x001:
                return " (Unprintable)"
            case 0x002:
                return " (Flutter)"
            case 0x011:
                return " (Android)"
            case 0x012:
                return " (Fuchsia)"
            case 0x013:
                return " (iOS)"
            case 0x014:
                return " (macOS)"
            case 0x015:
                return " (GTK)"
            case 0x016:
                return " (Windows)"
            case 0x017:
                return " (Web)"
            case 0x018:
                return " (GLFW)"
            default:
                return ""
            }
        }()
        return "\(result)\(planeDescription)"
    }

    /// Returns an escaped string representation of the character.
    ///
    /// **Dart Source:** `key.dart:197-215`
    /// **Original:** `String? _escapeCharacter()`
    private func escapeCharacter() -> String {
        guard let character = character else {
            return "<none>"
        }
        switch character {
        case "\n":
            return "\"\\n\""
        case "\t":
            return "\"\\t\""
        case "\r":
            return "\"\\r\""
        case "\u{08}":  // backspace
            return "\"\\b\""
        case "\u{0C}":  // form feed
            return "\"\\f\""
        default:
            return "\"\(character)\""
        }
    }

    /// Returns a quoted hex representation of the character's code units.
    ///
    /// **Dart Source:** `key.dart:217-225`
    /// **Original:** `String? _quotedCharCode()`
    ///
    /// DIFFERENCE FROM DART: Uses `String.utf16` instead of `codeUnits`
    /// REASON: Swift String API provides UTF-16 view; Dart's `codeUnits` returns UTF-16
    private func quotedCharCode() -> String {
        guard let character = character else {
            return ""
        }
        let hexChars = character.utf16.map { code in
            String(code, radix: 16).leftPadding(toLength: 2, withPad: "0")
        }
        return " (0x\(hexChars.joined(separator: " ")))"
    }
}

// MARK: - KeyData CustomStringConvertible

extension KeyData: CustomStringConvertible {
    /// Returns a string representation of the key data.
    ///
    /// **Dart Source:** `key.dart:227-234`
    /// **Original:**
    /// ```dart
    /// @override
    /// String toString() {
    ///   return 'KeyData(${type.label}, '
    ///       'physical: 0x${physical.toRadixString(16)}, '
    ///       'logical: ${_logicalToString()}, '
    ///       'character: ${_escapeCharacter()}${_quotedCharCode()}'
    ///       '${synthesized ? ', synthesized' : ''}';
    /// }
    /// ```
    public var description: String {
        var result = "KeyData(\(type.label), "
        result += "physical: 0x\(String(physical, radix: 16)), "
        result += "logical: \(logicalToString()), "
        result += "character: \(escapeCharacter())\(quotedCharCode())"
        if synthesized {
            result += ", synthesized"
        }
        return result
    }
}

// MARK: - KeyData Full Description

extension KeyData {
    /// Returns a complete textual description of the information in this object.
    ///
    /// **Dart Source:** `key.dart:236-246`
    /// **Original:**
    /// ```dart
    /// String toStringFull() {
    ///   return '$runtimeType(type: ${type.label}, '
    ///       'deviceType: ${deviceType.label}, '
    ///       'timeStamp: $timeStamp, '
    ///       'physical: 0x${physical.toRadixString(16)}, '
    ///       'logical: 0x${logical.toRadixString(16)}, '
    ///       'character: ${_escapeCharacter()}, '
    ///       'synthesized: $synthesized'
    ///       ')';
    /// }
    /// ```
    ///
    /// DIFFERENCE FROM DART: timeStamp displayed as seconds (Double) instead of Duration
    /// REASON: Swift uses TimeInterval (seconds) instead of Dart's Duration type
    public func toStringFull() -> String {
        var result = "KeyData(type: \(type.label), "
        result += "deviceType: \(deviceType.label), "
        result += "timeStamp: \(timeStamp), "
        result += "physical: 0x\(String(physical, radix: 16)), "
        result += "logical: 0x\(String(logical, radix: 16)), "
        result += "character: \(escapeCharacter()), "
        result += "synthesized: \(synthesized)"
        result += ")"
        return result
    }
}

// MARK: - KeyData Binary Deserialization

extension KeyData {
    /// Deserializes a binary key data packet from the engine.
    ///
    /// Packet format (little-endian uint64 fields, mirroring the engine's
    /// `KeyDataPacket` = [charSize][KeyData struct][character bytes]):
    ///   [0] charDataSize — UTF-8 character byte count (0 if none)
    ///   [1] timestamp — microseconds
    ///   [2] type — KeyEventType raw value (0=down, 1=up, 2=repeat)
    ///   [3] physical — USB HID physical key code
    ///   [4] logical — logical key ID
    ///   [5] synthesized — 0 or 1
    ///   [6] deviceType — KeyEventDeviceType raw value
    ///   [UTF-8 character bytes after field 6]
    ///
    /// **Dart Source:** `platform_dispatcher.dart:573-594` (`_unpackKeyData`)
    public static func fromPacket(_ packet: Data) -> KeyData {
        let stride = 8

        func getUInt64(_ offset: Int) -> UInt64 {
            packet.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) }
        }

        var i = 0
        let charDataSize = Int(getUInt64(stride * i)); i += 1
        let timestamp = getUInt64(stride * i); i += 1
        let typeRaw = Int(getUInt64(stride * i)); i += 1
        let physical = Int64(bitPattern: getUInt64(stride * i)); i += 1
        let logical = Int64(bitPattern: getUInt64(stride * i)); i += 1
        let synthesized = getUInt64(stride * i) != 0; i += 1
        let deviceTypeRaw = Int(getUInt64(stride * i)); i += 1

        let character: String?
        if charDataSize > 0 {
            let start = stride * i
            character = String(data: packet[start ..< start + charDataSize], encoding: .utf8)
        } else {
            character = nil
        }

        let type: KeyEventType
        switch typeRaw {
        case 0: type = .down
        case 1: type = .up
        case 2: type = .repeat
        default: type = .down
        }

        let deviceType: KeyEventDeviceType
        switch deviceTypeRaw {
        case 1: deviceType = .directionalPad
        case 2: deviceType = .gamepad
        case 3: deviceType = .joystick
        case 4: deviceType = .hdmi
        default: deviceType = .keyboard
        }

        return KeyData(
            timeStamp: TimeInterval(timestamp) / 1_000_000.0,
            type: type,
            physical: physical,
            logical: logical,
            character: character,
            synthesized: synthesized,
            deviceType: deviceType
        )
    }
}

// MARK: - String Extension for Padding

/// Extension to provide left padding for strings.
///
/// **Dart Source:** N/A - Swift-specific helper
///
/// DIFFERENCE FROM DART: Swift doesn't have a built-in `padLeft` method
/// REASON: Dart's `String.padLeft` is used in `_quotedCharCode`; this extension provides equivalent
private extension String {
    func leftPadding(toLength length: Int, withPad padCharacter: Character) -> String {
        let padCount = length - self.count
        guard padCount > 0 else {
            return self
        }
        return String(repeating: padCharacter, count: padCount) + self
    }
}
