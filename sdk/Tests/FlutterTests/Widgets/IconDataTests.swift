// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for IconData and IconDataProperty.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/icon_data_test.dart`
final class IconDataTests: XCTestCase {

    // MARK: - IconData Constructor

    func testIconDataDefaultConstructor() {
        let icon = IconData(0xE800)
        XCTAssertEqual(icon.codePoint, 0xE800)
        XCTAssertNil(icon.fontFamily)
        XCTAssertNil(icon.fontPackage)
        XCTAssertFalse(icon.matchTextDirection)
        XCTAssertNil(icon.fontFamilyFallback)
    }

    func testIconDataFullConstructor() {
        let icon = IconData(
            0xE801,
            fontFamily: "MaterialIcons",
            fontPackage: "material",
            matchTextDirection: true,
            fontFamilyFallback: ["Roboto", "Arial"]
        )
        XCTAssertEqual(icon.codePoint, 0xE801)
        XCTAssertEqual(icon.fontFamily, "MaterialIcons")
        XCTAssertEqual(icon.fontPackage, "material")
        XCTAssertTrue(icon.matchTextDirection)
        XCTAssertEqual(icon.fontFamilyFallback, ["Roboto", "Arial"])
    }

    // MARK: - Equality

    func testIconDataEqualitySameValues() {
        let a = IconData(0xE800, fontFamily: "Icons", fontPackage: "pkg")
        let b = IconData(0xE800, fontFamily: "Icons", fontPackage: "pkg")
        XCTAssertEqual(a, b)
    }

    func testIconDataEqualityDifferentCodePoint() {
        let a = IconData(0xE800)
        let b = IconData(0xE801)
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityDifferentFontFamily() {
        let a = IconData(0xE800, fontFamily: "Icons")
        let b = IconData(0xE800, fontFamily: "Other")
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityDifferentFontPackage() {
        let a = IconData(0xE800, fontPackage: "pkg1")
        let b = IconData(0xE800, fontPackage: "pkg2")
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityDifferentMatchTextDirection() {
        let a = IconData(0xE800, matchTextDirection: false)
        let b = IconData(0xE800, matchTextDirection: true)
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityDifferentFontFamilyFallback() {
        let a = IconData(0xE800, fontFamilyFallback: ["A"])
        let b = IconData(0xE800, fontFamilyFallback: ["B"])
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityNilVsNonNilFallback() {
        let a = IconData(0xE800, fontFamilyFallback: nil)
        let b = IconData(0xE800, fontFamilyFallback: ["A"])
        XCTAssertNotEqual(a, b)
    }

    func testIconDataEqualityBothNilFallback() {
        let a = IconData(0xE800, fontFamilyFallback: nil)
        let b = IconData(0xE800, fontFamilyFallback: nil)
        XCTAssertEqual(a, b)
    }

    // MARK: - Hashable

    func testIconDataHashableEqualObjectsSameHash() {
        let a = IconData(0xE800, fontFamily: "Icons", fontPackage: "pkg")
        let b = IconData(0xE800, fontFamily: "Icons", fontPackage: "pkg")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testIconDataHashableWorksInSet() {
        let icon1 = IconData(0xE800)
        let icon2 = IconData(0xE801)
        let icon3 = IconData(0xE800) // Same as icon1
        let set: Set<IconData> = [icon1, icon2, icon3]
        XCTAssertEqual(set.count, 2)
    }

    func testIconDataHashableWorksAsDictionaryKey() {
        let icon = IconData(0xE800, fontFamily: "Icons")
        var dict: [IconData: String] = [:]
        dict[icon] = "test"
        let sameIcon = IconData(0xE800, fontFamily: "Icons")
        XCTAssertEqual(dict[sameIcon], "test")
    }

    // MARK: - CustomStringConvertible

    func testIconDataDescription() {
        let icon = IconData(0xE800)
        XCTAssertEqual(icon.description, "IconData(U+0E800)")
    }

    func testIconDataDescriptionLowCodePoint() {
        let icon = IconData(0x41) // 'A'
        XCTAssertEqual(icon.description, "IconData(U+00041)")
    }

    func testIconDataDescriptionHighCodePoint() {
        let icon = IconData(0x1F600) // Emoji
        XCTAssertEqual(icon.description, "IconData(U+1F600)")
    }

    func testIconDataDescriptionZero() {
        let icon = IconData(0)
        XCTAssertEqual(icon.description, "IconData(U+00000)")
    }

    // MARK: - Sendable

    func testIconDataIsSendable() {
        let icon = IconData(0xE800)
        // Sendable conformance - can be used across concurrency boundaries
        let _: any Sendable = icon
        XCTAssertTrue(true) // Compiles = passes
    }

    // MARK: - IconDataProperty

    func testIconDataPropertyBasic() {
        let icon = IconData(0xE800)
        let property = IconDataProperty("icon", icon)
        XCTAssertNotNil(property)
    }

    func testIconDataPropertyNilValue() {
        let property = IconDataProperty("icon", nil, ifNull: "no icon")
        XCTAssertNotNil(property)
    }
}
