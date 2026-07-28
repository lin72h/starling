// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for StrutStyle (painting layer).
///
/// **Dart Test Source:** `packages/flutter/test/painting/strut_style_test.dart`
///
/// Note: `Flutter.StrutStyle` (painting layer) is distinct from
/// `FlutterSwiftBridge.StrutStyle` (dart:ui layer). We use a typealias
/// to refer to the painting-layer version unambiguously.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Typealias to disambiguate from FlutterSwiftBridge.StrutStyle (dart:ui level).
private typealias PaintingStrutStyle = Flutter.StrutStyle

/// Typealias to disambiguate from FlutterSwiftBridge.TextStyle (dart:ui level).
private typealias TextStyle = Flutter.TextStyle

final class StrutStyleTests: XCTestCase {

    // MARK: - Diagnostics Tests (ported from Dart)

    /// Test basic diagnostics output with fontFamily and fontSize.
    ///
    /// **Dart Test:** `strut_style_test.dart:10-11`
    func testDiagnosticsBasic() {
        let s0 = PaintingStrutStyle(fontFamily: "Serif", fontSize: 14)
        XCTAssertEqual(s0.description, "StrutStyle(family: Serif, size: 14.0)")
    }

    /// Test diagnostics with forceStrutHeight true.
    ///
    /// **Dart Test:** `strut_style_test.dart:13-17`
    func testDiagnosticsForceTrue() {
        let s1 = PaintingStrutStyle(fontFamily: "Serif", fontSize: 14, forceStrutHeight: true)
        XCTAssertEqual(s1.fontFamily, "Serif")
        XCTAssertEqual(s1.fontSize, 14.0)
        XCTAssertEqual(s1, s1)
        XCTAssertEqual(
            s1.description,
            "StrutStyle(family: Serif, size: 14.0, <strut height forced>)"
        )
    }

    /// Test diagnostics with forceStrutHeight false.
    ///
    /// **Dart Test:** `strut_style_test.dart:19-20`
    func testDiagnosticsForceFalse() {
        let s2 = PaintingStrutStyle(fontFamily: "Serif", fontSize: 14, forceStrutHeight: false)
        XCTAssertEqual(
            s2.description,
            "StrutStyle(family: Serif, size: 14.0, <strut height normal>)"
        )
    }

    /// Test diagnostics for empty StrutStyle.
    ///
    /// **Dart Test:** `strut_style_test.dart:22-23`
    func testDiagnosticsEmpty() {
        let s3 = PaintingStrutStyle()
        XCTAssertEqual(s3.description, "StrutStyle")
    }

    /// Test diagnostics with only forceStrutHeight false.
    ///
    /// **Dart Test:** `strut_style_test.dart:25-26`
    func testDiagnosticsOnlyForceFalse() {
        let s4 = PaintingStrutStyle(forceStrutHeight: false)
        XCTAssertEqual(s4.description, "StrutStyle(<strut height normal>)")
    }

    /// Test diagnostics with only forceStrutHeight true.
    ///
    /// **Dart Test:** `strut_style_test.dart:28-29`
    func testDiagnosticsOnlyForceTrue() {
        let s5 = PaintingStrutStyle(forceStrutHeight: true)
        XCTAssertEqual(s5.description, "StrutStyle(<strut height forced>)")
    }

    /// Test diagnostics with height and leadingDistribution even.
    ///
    /// **Dart Test:** `strut_style_test.dart:31-32`
    func testDiagnosticsLeadingDistributionEven() {
        let s6 = PaintingStrutStyle(height: 14, leadingDistribution: .even)
        XCTAssertEqual(
            s6.description,
            "StrutStyle(height: 14.0x, leadingDistribution: even)"
        )
    }

    /// Test diagnostics with height and leadingDistribution proportional.
    ///
    /// **Dart Test:** `strut_style_test.dart:34-38`
    func testDiagnosticsLeadingDistributionProportional() {
        let s7 = PaintingStrutStyle(height: 14, leadingDistribution: .proportional)
        XCTAssertEqual(
            s7.description,
            "StrutStyle(height: 14.0x, leadingDistribution: proportional)"
        )
    }

    /// Test equality with different leadingDistribution values.
    ///
    /// **Dart Test:** `strut_style_test.dart:40`
    func testEqualityDifferentLeadingDistribution() {
        let s6 = PaintingStrutStyle(height: 14, leadingDistribution: .even)
        let s7 = PaintingStrutStyle(height: 14, leadingDistribution: .proportional)
        XCTAssertNotEqual(s6, s7)
    }

    // MARK: - Static Constant Tests

    /// Test the disabled constant.
    func testDisabledConstant() {
        let disabled = PaintingStrutStyle.disabled
        XCTAssertEqual(disabled.height, 0.0)
        XCTAssertEqual(disabled.leading, 0.0)
        XCTAssertNil(disabled.fontFamily)
        XCTAssertNil(disabled.fontSize)
        XCTAssertNil(disabled.fontWeight)
        XCTAssertNil(disabled.fontStyle)
        XCTAssertNil(disabled.forceStrutHeight)
    }

    // MARK: - Default Values Tests

    /// Test that default initializer leaves all properties nil.
    func testDefaultInitializer() {
        let style = PaintingStrutStyle()
        XCTAssertNil(style.fontFamily)
        XCTAssertNil(style.fontFamilyFallback)
        XCTAssertNil(style.fontSize)
        XCTAssertNil(style.height)
        XCTAssertNil(style.leadingDistribution)
        XCTAssertNil(style.leading)
        XCTAssertNil(style.fontWeight)
        XCTAssertNil(style.fontStyle)
        XCTAssertNil(style.forceStrutHeight)
        XCTAssertNil(style.debugLabel)
    }

    /// Test initializer with all properties.
    func testFullInitializer() {
        let style = PaintingStrutStyle(
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial", "Helvetica"],
            fontSize: 16.0,
            height: 1.5,
            leadingDistribution: .even,
            leading: 0.5,
            fontWeight: .w700,
            fontStyle: .italic,
            forceStrutHeight: true,
            debugLabel: "test"
        )
        XCTAssertEqual(style.fontFamily, "Roboto")
        XCTAssertEqual(style.fontFamilyFallback, ["Arial", "Helvetica"])
        XCTAssertEqual(style.fontSize, 16.0)
        XCTAssertEqual(style.height, 1.5)
        XCTAssertEqual(style.leadingDistribution, TextLeadingDistribution.even)
        XCTAssertEqual(style.leading, 0.5)
        XCTAssertEqual(style.fontWeight, FontWeight.w700)
        XCTAssertEqual(style.fontStyle, FontStyle.italic)
        XCTAssertEqual(style.forceStrutHeight, true)
        XCTAssertEqual(style.debugLabel, "test")
    }

    // MARK: - Package Prefixing Tests

    /// Test that fontFamily is prefixed with package name.
    func testPackagePrefixing() {
        let s = PaintingStrutStyle(fontFamily: "Roboto", package: "my_package")
        XCTAssertEqual(s.fontFamily, "packages/my_package/Roboto")
    }

    /// Test that fontFamilyFallback entries are prefixed with package name.
    func testFontFamilyFallbackWithPackage() {
        let s = PaintingStrutStyle(
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial", "Helvetica"],
            package: "my_package"
        )
        XCTAssertEqual(s.fontFamily, "packages/my_package/Roboto")
        XCTAssertEqual(
            s.fontFamilyFallback,
            ["packages/my_package/Arial", "packages/my_package/Helvetica"]
        )
    }

    /// Test that fontFamilyFallback without package is returned as-is.
    func testFontFamilyFallbackWithoutPackage() {
        let s = PaintingStrutStyle(
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial", "Helvetica"]
        )
        XCTAssertEqual(s.fontFamilyFallback, ["Arial", "Helvetica"])
    }

    /// Test fontFamily without package is not prefixed.
    func testFontFamilyWithoutPackage() {
        let s = PaintingStrutStyle(fontFamily: "Roboto")
        XCTAssertEqual(s.fontFamily, "Roboto")
    }

    // MARK: - Equality Tests

    /// Test equality for identical styles.
    func testEqualityIdentical() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        XCTAssertEqual(s1, s2)
    }

    /// Test inequality for different fontFamily.
    func testInequalityFontFamily() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto")
        let s2 = PaintingStrutStyle(fontFamily: "Arial")
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different fontSize.
    func testInequalityFontSize() {
        let s1 = PaintingStrutStyle(fontSize: 14)
        let s2 = PaintingStrutStyle(fontSize: 16)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different fontWeight.
    func testInequalityFontWeight() {
        let s1 = PaintingStrutStyle(fontWeight: .w400)
        let s2 = PaintingStrutStyle(fontWeight: .w700)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different fontStyle.
    func testInequalityFontStyle() {
        let s1 = PaintingStrutStyle(fontStyle: .normal)
        let s2 = PaintingStrutStyle(fontStyle: .italic)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different height.
    func testInequalityHeight() {
        let s1 = PaintingStrutStyle(height: 1.0)
        let s2 = PaintingStrutStyle(height: 2.0)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different leading.
    func testInequalityLeading() {
        let s1 = PaintingStrutStyle(leading: 0.0)
        let s2 = PaintingStrutStyle(leading: 1.0)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different forceStrutHeight.
    func testInequalityForceStrutHeight() {
        let s1 = PaintingStrutStyle(forceStrutHeight: true)
        let s2 = PaintingStrutStyle(forceStrutHeight: false)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test that debugLabel is NOT considered in equality.
    func testDebugLabelNotInEquality() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", debugLabel: "label1")
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", debugLabel: "label2")
        XCTAssertEqual(s1, s2)
    }

    /// Test leadingDistribution equality nuance: only compared when height != nil.
    func testLeadingDistributionEqualityWithNilHeight() {
        let s1 = PaintingStrutStyle(leadingDistribution: .even)
        let s2 = PaintingStrutStyle(leadingDistribution: .proportional)
        // When height is nil, leadingDistribution is NOT compared
        XCTAssertEqual(s1, s2)
    }

    /// Test leadingDistribution equality when height is non-nil.
    func testLeadingDistributionEqualityWithHeight() {
        let s1 = PaintingStrutStyle(height: 1.0, leadingDistribution: .even)
        let s2 = PaintingStrutStyle(height: 1.0, leadingDistribution: .proportional)
        XCTAssertNotEqual(s1, s2)
    }

    /// Test inequality for different fontFamilyFallback.
    func testInequalityFontFamilyFallback() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontFamilyFallback: ["Arial"])
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", fontFamilyFallback: ["Helvetica"])
        XCTAssertNotEqual(s1, s2)
    }

    // MARK: - Hashable Tests

    /// Test hash consistency for equal styles.
    func testHashCodeConsistency() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14, height: 1.5)
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14, height: 1.5)
        XCTAssertEqual(s1.hashValue, s2.hashValue)
    }

    /// Test StrutStyle can be used as Set element.
    func testAsSetElement() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let s3 = PaintingStrutStyle(fontFamily: "Arial", fontSize: 16)

        var set = Set<PaintingStrutStyle>()
        set.insert(s1)
        set.insert(s2)  // Should not increase count (equal to s1)
        set.insert(s3)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(s1))
        XCTAssertTrue(set.contains(s3))
    }

    // MARK: - compareTo Tests

    /// Test compareTo returns identical for same instance.
    func testCompareToIdentical() {
        let s = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        XCTAssertEqual(s.compareTo(s), RenderComparison.identical)
    }

    /// Test compareTo returns identical for equal styles.
    func testCompareToEqual() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let s2 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.identical)
    }

    /// Test compareTo returns layout for different fontFamily.
    func testCompareToLayoutFontFamily() {
        let s1 = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let s2 = PaintingStrutStyle(fontFamily: "Arial", fontSize: 14)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns layout for different fontSize.
    func testCompareToLayoutFontSize() {
        let s1 = PaintingStrutStyle(fontSize: 14)
        let s2 = PaintingStrutStyle(fontSize: 16)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns layout for different height.
    func testCompareToLayoutHeight() {
        let s1 = PaintingStrutStyle(height: 1.0)
        let s2 = PaintingStrutStyle(height: 2.0)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns layout for different forceStrutHeight.
    func testCompareToLayoutForceStrutHeight() {
        let s1 = PaintingStrutStyle(forceStrutHeight: true)
        let s2 = PaintingStrutStyle(forceStrutHeight: false)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns layout for different leadingDistribution when height is set.
    func testCompareToLayoutLeadingDistribution() {
        let s1 = PaintingStrutStyle(height: 1.0, leadingDistribution: .even)
        let s2 = PaintingStrutStyle(height: 1.0, leadingDistribution: .proportional)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns identical when leadingDistribution differs but height is nil.
    func testCompareToIdenticalLeadingDistributionNilHeight() {
        let s1 = PaintingStrutStyle(leadingDistribution: .even)
        let s2 = PaintingStrutStyle(leadingDistribution: .proportional)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.identical)
    }

    // MARK: - fromTextStyle Tests

    /// Test fromTextStyle inherits properties from TextStyle.
    func testFromTextStyleBasic() {
        let textStyle = TextStyle(
            fontSize: 16.0,
            fontWeight: .w700,
            fontStyle: .italic,
            height: 1.5,
            leadingDistribution: .even,
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial"]
        )

        let strut = PaintingStrutStyle.fromTextStyle(textStyle)

        XCTAssertEqual(strut.fontFamily, "Roboto")
        XCTAssertEqual(strut.fontFamilyFallback, ["Arial"])
        XCTAssertEqual(strut.fontSize, 16.0)
        XCTAssertEqual(strut.height, 1.5)
        XCTAssertEqual(strut.leadingDistribution, TextLeadingDistribution.even)
        XCTAssertEqual(strut.fontWeight, FontWeight.w700)
        XCTAssertEqual(strut.fontStyle, FontStyle.italic)
        XCTAssertNil(strut.leading)
        XCTAssertNil(strut.forceStrutHeight)
    }

    /// Test fromTextStyle with overrides.
    func testFromTextStyleWithOverrides() {
        let textStyle = TextStyle(
            fontSize: 16.0,
            fontWeight: .w400,
            fontFamily: "Roboto"
        )

        let strut = PaintingStrutStyle.fromTextStyle(
            textStyle,
            fontFamily: "Arial",
            fontSize: 20.0,
            fontWeight: .w700,
            forceStrutHeight: true
        )

        XCTAssertEqual(strut.fontFamily, "Arial")
        XCTAssertEqual(strut.fontSize, 20.0)
        XCTAssertEqual(strut.fontWeight, FontWeight.w700)
        XCTAssertEqual(strut.forceStrutHeight, true)
    }

    /// Test fromTextStyle with package prefixing.
    func testFromTextStyleWithPackage() {
        let textStyle = TextStyle(fontFamily: "Roboto")

        let strut = PaintingStrutStyle.fromTextStyle(
            textStyle,
            fontFamily: "CustomFont",
            package: "my_package"
        )

        XCTAssertEqual(strut.fontFamily, "packages/my_package/CustomFont")
    }

    /// Test fromTextStyle falls back to textStyle fontFamily when not overridden.
    func testFromTextStyleFallbackFontFamily() {
        let textStyle = TextStyle(fontFamily: "Roboto")

        let strut = PaintingStrutStyle.fromTextStyle(textStyle)

        XCTAssertEqual(strut.fontFamily, "Roboto")
    }

    // MARK: - inheritFromTextStyle Tests

    /// Test inheritFromTextStyle with nil returns self.
    func testInheritFromTextStyleNil() {
        let strut = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        let nilStyle: TextStyle? = nil
        let result = strut.inheritFromTextStyle(nilStyle)
        XCTAssertEqual(result, strut)
    }

    /// Test inheritFromTextStyle fills in nil properties.
    func testInheritFromTextStyleFillsNilProperties() {
        let strut = PaintingStrutStyle(fontFamily: "Roboto")
        let textStyle = TextStyle(
            fontSize: 16.0,
            fontWeight: .w700,
            fontStyle: .italic,
            height: 1.5
        )

        let result = strut.inheritFromTextStyle(textStyle)

        XCTAssertEqual(result.fontFamily, "Roboto")  // Kept from strut
        XCTAssertEqual(result.fontSize, 16.0)         // From textStyle
        XCTAssertEqual(result.height, 1.5)            // From textStyle
        XCTAssertEqual(result.fontWeight, FontWeight.w700)   // From textStyle
        XCTAssertEqual(result.fontStyle, FontStyle.italic)   // From textStyle
    }

    /// Test inheritFromTextStyle preserves existing non-nil properties.
    func testInheritFromTextStylePreservesExistingProperties() {
        let strut = PaintingStrutStyle(
            fontFamily: "Roboto",
            fontSize: 14.0,
            fontWeight: .w400
        )
        let textStyle = TextStyle(
            fontSize: 20.0,
            fontWeight: .w700,
            fontFamily: "Arial"
        )

        let result = strut.inheritFromTextStyle(textStyle)

        XCTAssertEqual(result.fontFamily, "Roboto")    // Kept from strut
        XCTAssertEqual(result.fontSize, 14.0)           // Kept from strut
        XCTAssertEqual(result.fontWeight, FontWeight.w400)  // Kept from strut
    }

    /// Test inheritFromTextStyle leadingDistribution behavior.
    func testInheritFromTextStyleLeadingDistribution() {
        // When height is nil in both, leadingDistribution should be nil
        let strut1 = PaintingStrutStyle()
        let textStyle1 = TextStyle(leadingDistribution: .even)
        let result1 = strut1.inheritFromTextStyle(textStyle1)
        XCTAssertNil(result1.leadingDistribution)

        // When height comes from textStyle, leadingDistribution should be inherited
        let strut2 = PaintingStrutStyle()
        let textStyle2 = TextStyle(height: 1.5, leadingDistribution: .even)
        let result2 = strut2.inheritFromTextStyle(textStyle2)
        XCTAssertEqual(result2.leadingDistribution, TextLeadingDistribution.even)

        // When strut has height, its leadingDistribution takes precedence
        let strut3 = PaintingStrutStyle(height: 1.0, leadingDistribution: .proportional)
        let textStyle3 = TextStyle(leadingDistribution: .even)
        let result3 = strut3.inheritFromTextStyle(textStyle3)
        XCTAssertEqual(result3.leadingDistribution, TextLeadingDistribution.proportional)
    }

    /// Test inheritFromTextStyle preserves leading and forceStrutHeight from strut.
    func testInheritFromTextStylePreservesStrutOnlyProperties() {
        let strut = PaintingStrutStyle(leading: 0.5, forceStrutHeight: true)
        let textStyle = TextStyle(fontSize: 16.0, fontFamily: "Roboto")

        let result = strut.inheritFromTextStyle(textStyle)

        XCTAssertEqual(result.leading, 0.5)
        XCTAssertEqual(result.forceStrutHeight, true)
    }

    // MARK: - Value Semantics Tests

    /// Test struct value semantics.
    func testValueSemantics() {
        let original = PaintingStrutStyle(fontFamily: "Roboto", fontSize: 14)
        var copy = original

        // Since StrutStyle uses let properties, we can't modify in place.
        // Reassign with different values.
        copy = PaintingStrutStyle(fontFamily: "Arial", fontSize: 16)

        // Original should be unchanged
        XCTAssertEqual(original.fontFamily, "Roboto")
        XCTAssertEqual(original.fontSize, 14)
        XCTAssertEqual(copy.fontFamily, "Arial")
        XCTAssertEqual(copy.fontSize, 16)
    }

    // MARK: - Diagnostics Edge Case Tests

    /// Test diagnostics with debugLabel.
    func testDiagnosticsWithDebugLabel() {
        let s = PaintingStrutStyle(fontFamily: "Roboto", debugLabel: "body")
        XCTAssertEqual(s.description, "StrutStyle(debugLabel: body, family: Roboto)")
    }

    /// Test diagnostics with fontWeight.
    func testDiagnosticsWithFontWeight() {
        let s = PaintingStrutStyle(fontWeight: .w700)
        XCTAssertEqual(s.description, "StrutStyle(weight: w700)")
    }

    /// Test diagnostics with fontStyle.
    func testDiagnosticsWithFontStyle() {
        let s = PaintingStrutStyle(fontStyle: .italic)
        XCTAssertEqual(s.description, "StrutStyle(style: italic)")
    }

    /// Test diagnostics with fontFamilyFallback.
    func testDiagnosticsWithFallback() {
        let s = PaintingStrutStyle(fontFamily: "Roboto", fontFamilyFallback: ["Arial", "Helvetica"])
        XCTAssertEqual(
            s.description,
            "StrutStyle(family: Roboto, familyFallback: [Arial, Helvetica])"
        )
    }

    /// Test diagnostics - leadingDistribution only shown when height is not nil.
    func testDiagnosticsLeadingDistributionOnlyWithHeight() {
        // With height nil, leadingDistribution should NOT appear
        let s1 = PaintingStrutStyle(leadingDistribution: .even)
        XCTAssertEqual(s1.description, "StrutStyle")

        // With height non-nil, leadingDistribution should appear
        let s2 = PaintingStrutStyle(height: 1.0, leadingDistribution: .even)
        XCTAssertTrue(s2.description.contains("leadingDistribution: even"))
    }
}
