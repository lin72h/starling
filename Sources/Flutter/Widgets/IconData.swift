// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - IconData

/// A description of an icon fulfilled by a font glyph.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/icon_data.dart:23-109`
public struct IconData: Hashable, Sendable, CustomStringConvertible {

    /// Creates icon data.
    ///
    /// Rarely used directly. Instead, consider using one of the predefined icons
    /// like the `Icons` collection.
    ///
    /// The `fontFamily` argument is normally required when using custom icons.
    ///
    /// **Dart Source:** `icon_data.dart:47-53`
    public init(
        _ codePoint: Int,
        fontFamily: String? = nil,
        fontPackage: String? = nil,
        matchTextDirection: Bool = false,
        fontFamilyFallback: [String]? = nil
    ) {
        self.codePoint = codePoint
        self.fontFamily = fontFamily
        self.fontPackage = fontPackage
        self.matchTextDirection = matchTextDirection
        self.fontFamilyFallback = fontFamilyFallback
    }

    /// The Unicode code point at which this icon is stored in the icon font.
    ///
    /// **Dart Source:** `icon_data.dart:56`
    public let codePoint: Int

    /// The font family from which the glyph for the `codePoint` will be selected.
    ///
    /// **Dart Source:** `icon_data.dart:59`
    public let fontFamily: String?

    /// The name of the package from which the font family is included.
    ///
    /// **Dart Source:** `icon_data.dart:69`
    public let fontPackage: String?

    /// Whether this icon should be automatically mirrored in right-to-left
    /// environments.
    ///
    /// **Dart Source:** `icon_data.dart:76`
    public let matchTextDirection: Bool

    /// The ordered list of font families to fall back on when a glyph cannot be
    /// found in a higher priority font family.
    ///
    /// **Dart Source:** `icon_data.dart:81`
    public let fontFamilyFallback: [String]?

    // MARK: - Equatable

    /// **Dart Source:** `icon_data.dart:84-94`
    public static func == (lhs: IconData, rhs: IconData) -> Bool {
        return lhs.codePoint == rhs.codePoint
            && lhs.fontFamily == rhs.fontFamily
            && lhs.fontPackage == rhs.fontPackage
            && lhs.matchTextDirection == rhs.matchTextDirection
            && lhs.fontFamilyFallback == rhs.fontFamilyFallback
    }

    // MARK: - Hashable

    /// **Dart Source:** `icon_data.dart:97-105`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(codePoint)
        hasher.combine(fontFamily)
        hasher.combine(fontPackage)
        hasher.combine(matchTextDirection)
        if let fallback = fontFamilyFallback {
            for family in fallback {
                hasher.combine(family)
            }
        }
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `icon_data.dart:108`
    public var description: String {
        return String(format: "IconData(U+%05X)", codePoint)
    }
}

// MARK: - IconDataProperty

/// `DiagnosticsProperty` that has an `IconData` as value.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/icon_data.dart:112-131`
public class IconDataProperty: DiagnosticsProperty<IconData> {

    /// Create a diagnostics property for `IconData`.
    ///
    /// **Dart Source:** `icon_data.dart:114-121`
    public init(
        _ name: String,
        _ value: IconData?,
        ifNull: String? = nil,
        showName: Bool = true,
        style: DiagnosticsTreeStyle = .singleLine,
        level: DiagnosticLevel = .info
    ) {
        super.init(
            name,
            value,
            ifNull: ifNull,
            showName: showName,
            style: style,
            level: level
        )
    }

    /// **Dart Source:** `icon_data.dart:123-130`
    public override func toJsonMap(delegate: DiagnosticsSerializationDelegate) -> [String: Any?] {
        var json = super.toJsonMap(delegate: delegate)
        if let iconData = typedValue {
            json["valueProperties"] = ["codePoint": iconData.codePoint] as [String: Any]
        }
        return json
    }
}
