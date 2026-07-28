// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Migrated from: engine/src/flutter/testing/dart/color_test.dart

import Testing
@testable import FlutterSwiftBridge

/// Compares two Colors component-wise within a threshold.
///
/// Checks that both colors have the same `colorSpace` and that the absolute
/// difference of each channel (`a`, `r`, `g`, `b`) is within the given
/// `threshold` (default `1.0 / 255.0`).
private func colorMatches(_ color: Color, _ target: Color, threshold: Double = 1.0 / 255.0) -> Bool {
    return color.colorSpace == target.colorSpace
        && abs(color.a - target.a) <= threshold
        && abs(color.r - target.r) <= threshold
        && abs(color.g - target.g) <= threshold
        && abs(color.b - target.b) <= threshold
}

@Suite("Color Tests")
struct ColorTests {
    // MARK: Constructors & Accessors

    /// Dart: 'color accessors should work' (line 40)
    @Test("color accessors should work")
    func testColorAccessors() {
        let color = Color(0x12345678)

        // Verify toARGB32() bit extraction
        let argb32 = color.toARGB32()
        let alpha = (argb32 >> 24) & 0xFF
        let red = (argb32 >> 16) & 0xFF
        let green = (argb32 >> 8) & 0xFF
        let blue = argb32 & 0xFF

        #expect(alpha == 0x12)
        #expect(red == 0x34)
        #expect(green == 0x56)
        #expect(blue == 0x78)

        // Verify float accessors (.a, .r, .g, .b)
        // 0x12 = 18, 0x34 = 52, 0x56 = 86, 0x78 = 120
        #expect(abs(color.a - Double(0x12) / 255.0) < 1.0 / 255.0)
        #expect(abs(color.r - Double(0x34) / 255.0) < 1.0 / 255.0)
        #expect(abs(color.g - Double(0x56) / 255.0) < 1.0 / 255.0)
        #expect(abs(color.b - Double(0x78) / 255.0) < 1.0 / 255.0)
    }

    /// Dart: 'color created with out of bounds value' (line 55)
    @Test("color created with out of bounds value")
    func testColorOutOfBoundsValue() {
        // 0x100 << 24 = 0x10000000000 (exceeds 32-bit ARGB range)
        let color = Color(0x100 << 24)
        // Verify no crash and colorSpace is sRGB (default)
        #expect(color.colorSpace == .sRGB)
    }

    /// Dart: 'color created with wildly out of bounds value' (line 61)
    /// DIFFERENCE FROM DART: Uses Int.max instead of 1 << 1000000
    /// REASON: Dart BigInt allows arbitrary precision; Swift integers overflow.
    ///         Using Int.max tests the same edge case (value far exceeding 32-bit ARGB range).
    @Test("color created with wildly out of bounds value")
    func testColorWildlyOutOfBoundsValue() {
        let color = Color(Int.max)
        // Verify no crash and colorSpace is sRGB (default)
        #expect(color.colorSpace == .sRGB)
    }

    /// Dart: 'from and accessors' (line 201)
    @Test("from and accessors")
    func testFromAndAccessors() {
        let color = Color(alpha: 0.1, red: 0.2, green: 0.3, blue: 0.4)

        // Verify float accessors
        #expect(color.a == 0.1)
        #expect(color.r == 0.2)
        #expect(color.g == 0.3)
        #expect(color.b == 0.4)
        #expect(color.colorSpace == .sRGB)

        // Verify toARGB32() bit extraction
        // alpha = 0.1 * 255 ≈ 25.5 → 26
        // red = 0.2 * 255 ≈ 51
        // green = 0.3 * 255 ≈ 76.5 → 77
        // blue = 0.4 * 255 ≈ 102
        let argb32 = color.toARGB32()
        let alpha = (argb32 >> 24) & 0xFF
        let red = (argb32 >> 16) & 0xFF
        let green = (argb32 >> 8) & 0xFF
        let blue = argb32 & 0xFF

        #expect(alpha == 26)
        #expect(red == 51)
        #expect(green == 77)
        #expect(blue == 102)

        // Verify toARGB32() returns expected value
        #expect(color.toARGB32() == 0x1a334d66)
    }

    /// Dart: 'fromARGB and accessors' (line 217)
    @Test("fromARGB and accessors")
    func testFromARGBAndAccessors() {
        let color = Color(argb: 10, 20, 35, 47)

        // Verify toARGB32() bit extraction matches input values
        let argb32 = color.toARGB32()
        let alpha = (argb32 >> 24) & 0xFF
        let red = (argb32 >> 16) & 0xFF
        let green = (argb32 >> 8) & 0xFF
        let blue = argb32 & 0xFF

        #expect(alpha == 10)
        #expect(red == 20)
        #expect(green == 35)
        #expect(blue == 47)
    }

    /// Dart: 'constructor and accessors' (line 225)
    @Test("constructor and accessors")
    func testConstructorAndAccessors() {
        let color = Color(0xffeeddcc)

        // Verify toARGB32() bit extraction matches expected values
        let argb32 = color.toARGB32()
        let alpha = (argb32 >> 24) & 0xFF
        let red = (argb32 >> 16) & 0xFF
        let green = (argb32 >> 8) & 0xFF
        let blue = argb32 & 0xFF

        #expect(alpha == 0xff)
        #expect(red == 0xee)
        #expect(green == 0xdd)
        #expect(blue == 0xcc)
    }

    // MARK: Equality & Hashing

    /// Dart: 'paint set to black' (line 48)
    /// DIFFERENCE FROM DART: Only tests Color equality; Paint interaction is skipped.
    /// REASON: Paint is a separate class in Swift. This test validates that black Color
    ///         instances compare equal, which was the underlying equality check in Dart.
    @Test("paint set to black")
    func testPaintSetToBlack() {
        let black1 = Color(0x00000000)
        let black2 = Color(0x00000000)
        #expect(black1 == black2)
    }

    /// Dart: 'two colors are only == if they have the same runtime type' (line 67)
    /// DIFFERENCE FROM DART: Tests value equality only; subclass tests skipped.
    /// REASON: Color is a struct in Swift, so subclassing is not possible.
    ///         The original Dart test verified that Color subclasses with same value
    ///         are not equal. In Swift, we test that Colors with same/different
    ///         values compare correctly.
    @Test("color equality")
    func testColorEquality() {
        // Same value should be equal
        let color1 = Color(0x12345678)
        let color2 = Color(0x12345678)
        #expect(color1 == color2)

        // Different values should not be equal
        let color3 = Color(0x87654321)
        #expect(color1 != color3)
    }

    /// Dart: 'hash considers colorspace' (line 299)
    @Test("hash considers colorspace")
    func testHashConsidersColorspace() {
        let srgb = Color(alpha: 1, red: 1, green: 0, blue: 0)
        let p3 = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)

        // Different colorspaces should produce different hash values
        #expect(srgb.hashValue != p3.hashValue)
    }

    /// Dart: 'equality considers colorspace' (line 311)
    @Test("equality considers colorspace")
    func testEqualityConsidersColorspace() {
        let srgb = Color(alpha: 1, red: 1, green: 0, blue: 0)
        let p3 = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)

        // Same component values but different colorspaces should NOT be equal
        #expect(srgb != p3)
    }

    // MARK: Color.lerp

    /// Dart: 'Color.lerp' (line 76)
    @Test("Color.lerp")
    func testColorLerp() {
        let black = Color(0x00000000)
        let white = Color(0xFFFFFFFF)

        // t=0.0 → returns start color
        let result0 = Color.lerp(black, white, 0.0)
        #expect(result0 == black)

        // t=0.5 → midpoint (use colorMatches for approximate comparison)
        let result05 = Color.lerp(black, white, 0.5)
        #expect(result05 != nil)
        #expect(colorMatches(result05!, Color(0x7F7F7F7F)))

        // t=1.0 → returns end color
        let result1 = Color.lerp(black, white, 1.0)
        #expect(result1 == white)

        // t=-0.1 → clamped to start
        let resultNeg = Color.lerp(black, white, -0.1)
        #expect(resultNeg == black)

        // t=1.1 → clamped to end
        let result11 = Color.lerp(black, white, 1.1)
        #expect(result11 == white)

        // Regression test: white-to-white at t=0.04 stays white (flutter#67423)
        let whiteToWhite = Color.lerp(white, white, 0.04)
        #expect(whiteToWhite == white)
    }

    /// Dart: 'Color.lerp different colorspaces' (line 105)
    /// DIFFERENCE FROM DART: Cannot verify assert() behavior in test.
    /// REASON: Dart throws an exception when Color.lerp is called with different
    ///         colorspaces; Swift uses assert() which traps in debug mode but cannot
    ///         be caught in tests. This test documents the precondition by verifying
    ///         that the two colors indeed have different colorspaces, which would
    ///         trigger the assert in Color.lerp if called.
    @Test("Color.lerp different colorspaces precondition")
    func testColorLerpDifferentColorspaces() {
        // Create colors with different colorspaces
        let p3Color = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)
        let srgbColor = Color(alpha: 1, red: 1, green: 0, blue: 0)

        // Verify the precondition: colors have different colorspaces
        #expect(p3Color.colorSpace == .displayP3)
        #expect(srgbColor.colorSpace == .sRGB)
        #expect(p3Color.colorSpace != srgbColor.colorSpace)

        // NOTE: In Dart, calling Color.lerp(p3Color, srgbColor, t) throws an exception.
        // In Swift, Color.lerp uses assert(x!.colorSpace == y!.colorSpace) which:
        // - In DEBUG builds: triggers a runtime trap (cannot be caught)
        // - In RELEASE builds: assertion is stripped, behavior undefined
        //
        // We do NOT call Color.lerp here because the assert would crash the test in debug mode.
        // This test documents the precondition that callers must ensure colors share the same colorspace.
    }

    /// Dart: 'Color.lerp same colorspaces' (line 119)
    @Test("Color.lerp same colorspaces")
    func testColorLerpSameColorspaces() {
        // Lerp two displayP3 colors at t=0.2
        let start = Color(alpha: 1, red: 0, green: 0, blue: 0, colorSpace: .displayP3)
        let end = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)
        let result = Color.lerp(start, end, 0.2)

        // Verify result equals expected displayP3 color
        let expected = Color(alpha: 1, red: 0.2, green: 0, blue: 0, colorSpace: .displayP3)

        #expect(result != nil)
        #expect(result!.colorSpace == .displayP3)
        #expect(colorMatches(result!, expected))
    }

    // MARK: Color.alphaBlend

    /// Dart: 'Color.alphaBlend' (line 132)
    @Test("Color.alphaBlend")
    func testColorAlphaBlend() {
        // Case 1: transparent + transparent = transparent
        #expect(
            Color.alphaBlend(foreground: Color(0x00000000), background: Color(0x00000000))
                == Color(0x00000000)
        )

        // Case 2: transparent + opaque = opaque (background shows through)
        #expect(
            Color.alphaBlend(foreground: Color(0x00000000), background: Color(0xFFFFFFFF))
                == Color(0xFFFFFFFF)
        )

        // Case 3: opaque + transparent = opaque (foreground covers)
        #expect(
            Color.alphaBlend(foreground: Color(0xFFFFFFFF), background: Color(0x00000000))
                == Color(0xFFFFFFFF)
        )

        // Case 4: opaque + opaque = opaque (foreground covers)
        #expect(
            Color.alphaBlend(foreground: Color(0xFFFFFFFF), background: Color(0xFFFFFFFF))
                == Color(0xFFFFFFFF)
        )

        // Case 5: semi-transparent white over black
        #expect(
            Color.alphaBlend(foreground: Color(0x80FFFFFF), background: Color(0xFF000000))
                == Color(0xFF808080)
        )

        // Case 6: semi-transparent gray over white (use colorMatches for approximate)
        #expect(
            colorMatches(
                Color.alphaBlend(foreground: Color(0x80808080), background: Color(0xFFFFFFFF)),
                Color(0xFFBFBFBF)
            )
        )

        // Case 7: semi-transparent gray over black (use colorMatches for approximate)
        #expect(
            colorMatches(
                Color.alphaBlend(foreground: Color(0x80808080), background: Color(0xFF000000)),
                Color(0xFF404040)
            )
        )

        // Case 8: very translucent color over black (use colorMatches for approximate)
        #expect(
            colorMatches(
                Color.alphaBlend(foreground: Color(0x01020304), background: Color(0xFF000000)),
                Color(0xFF000000)
            )
        )

        // Case 9: translucent color over black (use colorMatches for approximate)
        #expect(
            colorMatches(
                Color.alphaBlend(foreground: Color(0x11223344), background: Color(0xFF000000)),
                Color(0xFF020304)
            )
        )

        // Case 10: translucent color over semi-transparent black (use colorMatches for approximate)
        #expect(
            colorMatches(
                Color.alphaBlend(foreground: Color(0x11223344), background: Color(0x80000000)),
                Color(0x88040608)
            )
        )
    }

    /// Dart: 'Color.alphaBlend keeps colorspace' (line 175)
    @Test("Color.alphaBlend keeps colorspace")
    func testColorAlphaBlendKeepsColorspace() {
        // Blend displayP3 colors: semi-transparent white over opaque black
        let foreground = Color(alpha: 0.5, red: 1, green: 1, blue: 1, colorSpace: .displayP3)
        let background = Color(alpha: 1, red: 0, green: 0, blue: 0, colorSpace: .displayP3)
        let result = Color.alphaBlend(foreground: foreground, background: background)

        // Verify result colorSpace is .displayP3
        #expect(result.colorSpace == .displayP3)

        // Verify result matches expected displayP3 color
        let expected = Color(alpha: 1, red: 0.5, green: 0.5, blue: 0.5, colorSpace: .displayP3)
        #expect(colorMatches(result, expected))
    }

    // MARK: Luminance

    /// Dart: 'compute gray luminance' (line 185)
    @Test("compute gray luminance")
    func testComputeGrayLuminance() {
        // Each color component is at 20% (0x33 / 0xFF ≈ 0.2).
        let lightGray = Color(0xFF333333)
        // Relative luminance's formula is just the linearized color value for gray.
        // ((0.2 + 0.055) / 1.055) ^ 2.4 = 0.033104766570885055
        let expected = 0.033104766570885055
        let result = lightGray.computeLuminance()

        // Use tolerance-based comparison for floating-point precision
        #expect(abs(result - expected) < 1e-15)
    }

    /// Dart: 'compute color luminance' (line 193)
    @Test("compute color luminance")
    func testComputeColorLuminance() {
        // A reddish color: 0xFFFF3B30 (full red 0xFF, partial green 0x3B, partial blue 0x30)
        let color = Color(0xFFFF3B30)
        // Expected luminance from Dart test
        let expected = 0.24601329637099723
        let result = color.computeLuminance()

        // Use tolerance-based comparison for floating-point precision
        #expect(abs(result - expected) < 1e-15)
    }

    // MARK: Color Space Conversion

    /// Dart: 'p3 to extended srgb' (line 233)
    @Test("p3 to extended srgb")
    func testP3ToExtendedSRGB() {
        // Create a displayP3 red color
        let p3 = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)

        // Convert to extendedSRGB via withValues(colorSpace:)
        let srgb = p3.withValues(colorSpace: .extendedSRGB)

        // Verify components with 1e-4 tolerance
        #expect(srgb.a == 1.0)
        #expect(abs(srgb.r - 1.0931) < 1e-4)
        #expect(abs(srgb.g - (-0.22684034705162098)) < 1e-4)
        #expect(abs(srgb.b - (-0.15007957816123998)) < 1e-4)
        #expect(srgb.colorSpace == .extendedSRGB)
    }

    /// Dart: 'p3 to srgb' (line 249)
    @Test("p3 to srgb")
    func testP3ToSRGB() {
        // Create a displayP3 red color
        let p3 = Color(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: .displayP3)

        // Convert to sRGB via withValues(colorSpace:)
        let srgb = p3.withValues(colorSpace: .sRGB)

        // Verify components with 1e-4 tolerance
        // When converting P3 red to sRGB, out-of-gamut values are clamped to [0, 1]
        #expect(srgb.a == 1.0)
        #expect(abs(srgb.r - 1.0) < 1e-4)
        #expect(abs(srgb.g - 0.0) < 1e-4)
        #expect(abs(srgb.b - 0.0) < 1e-4)
        #expect(srgb.colorSpace == .sRGB)
    }

    /// Dart: 'extended srgb to p3' (line 265)
    @Test("extended srgb to p3")
    func testExtendedSRGBToP3() {
        // Create an extendedSRGB color that represents P3 red in extended sRGB space
        let srgb = Color(
            alpha: 1,
            red: 1.0931,
            green: -0.2268,
            blue: -0.1501,
            colorSpace: .extendedSRGB
        )

        // Convert to displayP3 via withValues(colorSpace:)
        let p3 = srgb.withValues(colorSpace: .displayP3)

        // Verify components with 1e-4 tolerance
        #expect(p3.a == 1.0)
        #expect(abs(p3.r - 1.0) < 1e-4)
        #expect(abs(p3.g - 0.0) < 1e-4)
        #expect(abs(p3.b - 0.0) < 1e-4)
        #expect(p3.colorSpace == .displayP3)
    }

    /// Dart: 'extended srgb to p3 clamped' (line 281)
    @Test("extended srgb to p3 clamped")
    func testExtendedSRGBToP3Clamped() {
        // Create an extendedSRGB color with out-of-gamut red value (red: 2)
        let srgb = Color(
            alpha: 1,
            red: 2,
            green: 0,
            blue: 0,
            colorSpace: .extendedSRGB
        )

        // Convert to displayP3 via withValues(colorSpace:)
        let p3 = srgb.withValues(colorSpace: .displayP3)

        // Verify alpha is preserved
        #expect(srgb.a == 1.0)

        // Verify all components are clamped to [0.0, 1.0]
        #expect(p3.r <= 1.0)
        #expect(p3.g <= 1.0)
        #expect(p3.b <= 1.0)
        #expect(p3.r >= 0.0)
        #expect(p3.g >= 0.0)
        #expect(p3.b >= 0.0)
    }

    // MARK: toARGB32

    /// Dart: 'toARGB32 converts to a 32-bit integer' (line 332)
    @Test("toARGB32 converts to a 32-bit integer")
    func testToARGB32() {
        let color = Color(alpha: 0.1, red: 0.2, green: 0.3, blue: 0.4)
        #expect(color.toARGB32() == 0x1a334d66)
    }
}
