// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Alignment tween classes for interpolating alignment values during animations.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/tweens.dart`

import FlutterSwiftBridge

// MARK: - FractionalOffsetTween

/// An interpolation between two fractional offsets.
///
/// This class specializes the interpolation of `Tween<FractionalOffset?>` to be
/// appropriate for fractional offsets.
///
/// See `Tween` for a discussion on how to use interpolation objects.
///
/// See also:
///
///  * `AlignmentTween`, which interpolates between two `Alignment` objects.
///
/// **Dart Source:** `tweens.dart:18-28`
public class FractionalOffsetTween: Tween<FractionalOffset?> {
    /// Creates a fractional offset tween.
    ///
    /// The `begin` and `end` properties may be nil; the nil value
    /// is treated as meaning the center.
    ///
    /// **Dart Source:** `tweens.dart:23`
    public override init(begin: FractionalOffset?? = nil, end: FractionalOffset?? = nil) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    /// Returns the value this variable has at the given animation clock value.
    ///
    /// **Dart Source:** `tweens.dart:27`
    public override func lerp(_ t: Double) -> FractionalOffset? {
        return FractionalOffset.lerp(begin!, end!, t)
    }
}

// MARK: - AlignmentTween

/// An interpolation between two alignments.
///
/// This class specializes the interpolation of `Tween<Alignment>` to be
/// appropriate for alignments.
///
/// See `Tween` for a discussion on how to use interpolation objects.
///
/// See also:
///
///  * `AlignmentGeometryTween`, which interpolates between two
///    `AlignmentGeometry` objects.
///
/// **Dart Source:** `tweens.dart:41-51`
public class AlignmentTween: Tween<Alignment> {
    /// Creates an alignment tween.
    ///
    /// The `begin` and `end` properties may be nil; the nil value
    /// is treated as meaning the center.
    ///
    /// **Dart Source:** `tweens.dart:46`
    public override init(begin: Alignment? = nil, end: Alignment? = nil) {
        super.init(begin: begin, end: end)
    }

    /// Returns the value this variable has at the given animation clock value.
    ///
    /// **Dart Source:** `tweens.dart:50`
    public override func lerp(_ t: Double) -> Alignment {
        return Alignment.lerp(begin, end, t)!
    }
}

// MARK: - AlignmentGeometryTween

/// An interpolation between two `AlignmentGeometry` values.
///
/// This class specializes the interpolation of `Tween<AlignmentGeometry?>`
/// to be appropriate for alignments.
///
/// See `Tween` for a discussion on how to use interpolation objects.
///
/// See also:
///
///  * `AlignmentTween`, which interpolates between two `Alignment` objects.
///
/// **Dart Source:** `tweens.dart:63-73`
public class AlignmentGeometryTween: Tween<(any AlignmentGeometry)?> {
    /// Creates an alignment geometry tween.
    ///
    /// The `begin` and `end` properties may be nil; the nil value
    /// is treated as meaning the center.
    ///
    /// **Dart Source:** `tweens.dart:68`
    public override init(
        begin: (any AlignmentGeometry)?? = nil,
        end: (any AlignmentGeometry)?? = nil
    ) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    /// Returns the value this variable has at the given animation clock value.
    ///
    /// **Dart Source:** `tweens.dart:72`
    public override func lerp(_ t: Double) -> (any AlignmentGeometry)? {
        return AlignmentGeometryStatics.lerp(begin!, end!, t)
    }
}
