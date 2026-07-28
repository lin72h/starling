// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tween classes for interpolating animation values.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/tween.dart`

import FlutterSwiftBridge
import Foundation

// MARK: - Tween

/// A linear interpolation between a beginning and ending value.
///
/// `Tween` is useful if you want to interpolate across a range.
///
/// The base `Tween<T>` requires subclasses to override `lerp`. For `Double`
/// interpolation, use `Tween<Double>` directly as a default `lerp` is provided.
///
/// **Dart Source:** `tween.dart:267-374`
///
/// DIFFERENCE FROM DART: Dart uses dynamic dispatch (`begin + (end - begin) * t`)
/// for the default `lerp`. Swift cannot do this, so the base `lerp` calls
/// `fatalError` and subclasses must override it. A default `lerp` for
/// `Tween<Double>` is provided via an extension.
/// REASON: Swift does not support dynamic arithmetic on generic types.
open class Tween<T>: Animatable<T> {

    /// Creates a tween.
    ///
    /// The `begin` and `end` properties must be non-nil before the tween is
    /// first used, but the arguments can be nil if the values are going to be
    /// filled in later.
    ///
    /// **Dart Source:** `tween.dart:273`
    public init(begin: T? = nil, end: T? = nil) {
        self.begin = begin
        self.end = end
    }

    /// The value this variable has at the beginning of the animation.
    ///
    /// **Dart Source:** `tween.dart:279`
    public var begin: T?

    /// The value this variable has at the end of the animation.
    ///
    /// **Dart Source:** `tween.dart:285`
    public var end: T?

    /// Returns the value this variable has at the given animation clock value.
    ///
    /// Subclasses must override this method to provide the interpolation logic.
    ///
    /// **Dart Source:** `tween.dart:296-347`
    open func lerp(_ t: Double) -> T {
        fatalError("Subclass of Tween<\(T.self)> must override lerp()")
    }

    /// Returns the interpolated value for the current value of the given animation.
    ///
    /// This method returns `begin` and `end` when the animation values are 0.0 or
    /// 1.0, respectively.
    ///
    /// **Dart Source:** `tween.dart:362-370`
    public override func transform(_ t: Double) -> T {
        if t == 0.0 {
            return begin!
        }
        if t == 1.0 {
            return end!
        }
        return lerp(t)
    }

    /// **Dart Source:** `tween.dart:373`
    open var tweenDescription: String {
        return "Animatable(\(begin as Any) \u{2192} \(end as Any))"
    }
}

// MARK: - DoubleTween (Tween<Double> default lerp)

/// A `Tween` specialized for `Double` values with a default `lerp`
/// implementation.
///
/// **Dart Source:** `tween.dart:296-347` (the dynamic `lerp` in Dart handles
/// Double natively; in Swift we provide this concrete subclass)
///
/// DIFFERENCE FROM DART: Dart's generic `Tween<T>.lerp` uses dynamic dispatch.
/// In Swift, we provide `DoubleTween` as the concrete `Tween<Double>`.
/// REASON: Swift generics do not support arithmetic on arbitrary `T`.
public class DoubleTween: Tween<Double> {
    /// **Dart Source:** `tween.dart:296-347`
    public override func lerp(_ t: Double) -> Double {
        return begin! + (end! - begin!) * t
    }
}

// MARK: - ReverseTween

/// A `Tween` that evaluates its parent in reverse.
///
/// **Dart Source:** `tween.dart:377-390`
public class ReverseTween<T>: Tween<T> {
    /// Construct a `Tween` that evaluates its parent in reverse.
    ///
    /// **Dart Source:** `tween.dart:379`
    public init(parent: Tween<T>) {
        self.parent = parent
        super.init(begin: parent.end, end: parent.begin)
    }

    /// This tween's value is the same as the parent's value evaluated in reverse.
    ///
    /// **Dart Source:** `tween.dart:386`
    public let parent: Tween<T>

    /// **Dart Source:** `tween.dart:389`
    public override func lerp(_ t: Double) -> T {
        return parent.lerp(1.0 - t)
    }
}

// MARK: - ColorTween

/// An interpolation between two colors.
///
/// This class specializes the interpolation of `Tween<Color?>` to use
/// `Color.lerp`.
///
/// **Dart Source:** `tween.dart:401-416`
public class ColorTween: Tween<Color?> {
    /// Creates a `Color` tween.
    ///
    /// **Dart Source:** `tween.dart:411`
    public override init(begin: Color?? = nil, end: Color?? = nil) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    /// **Dart Source:** `tween.dart:415`
    public override func lerp(_ t: Double) -> Color? {
        return Color.lerp(begin!, end!, t)
    }
}

// MARK: - SizeTween

/// An interpolation between two sizes.
///
/// This class specializes the interpolation of `Tween<Size?>` to use
/// `Size.lerp`.
///
/// **Dart Source:** `tween.dart:426-436`
public class SizeTween: Tween<Size?> {
    /// Creates a `Size` tween.
    ///
    /// **Dart Source:** `tween.dart:431`
    public override init(begin: Size?? = nil, end: Size?? = nil) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    /// **Dart Source:** `tween.dart:435`
    public override func lerp(_ t: Double) -> Size? {
        return Size.lerp(begin!, end!, t)
    }
}

// MARK: - RectTween

/// An interpolation between two rectangles.
///
/// This class specializes the interpolation of `Tween<Rect?>` to use
/// `Rect.lerp`.
///
/// **Dart Source:** `tween.dart:447-457`
public class RectTween: Tween<Rect?> {
    /// Creates a `Rect` tween.
    ///
    /// **Dart Source:** `tween.dart:452`
    public override init(begin: Rect?? = nil, end: Rect?? = nil) {
        super.init(begin: begin ?? nil, end: end ?? nil)
    }

    /// **Dart Source:** `tween.dart:456`
    public override func lerp(_ t: Double) -> Rect? {
        return Rect.lerp(begin!, end!, t)
    }
}

// MARK: - IntTween

/// An interpolation between two integers that rounds.
///
/// This class specializes the interpolation of `Tween<Int>` to be
/// appropriate for integers by interpolating between the given begin
/// and end values and then rounding the result to the nearest integer.
///
/// **Dart Source:** `tween.dart:473-485`
public class IntTween: Tween<Int> {
    /// **Dart Source:** `tween.dart:479`
    public override init(begin: Int? = nil, end: Int? = nil) {
        super.init(begin: begin, end: end)
    }

    /// **Dart Source:** `tween.dart:484`
    public override func lerp(_ t: Double) -> Int {
        return Int((Double(begin!) + Double(end! - begin!) * t).rounded())
    }
}

// MARK: - StepTween

/// An interpolation between two integers that floors.
///
/// This class specializes the interpolation of `Tween<Int>` to be
/// appropriate for integers by interpolating between the given begin
/// and end values and then using `floor` to return the current
/// integer component, dropping the fractional component.
///
/// **Dart Source:** `tween.dart:501-513`
public class StepTween: Tween<Int> {
    /// **Dart Source:** `tween.dart:507`
    public override init(begin: Int? = nil, end: Int? = nil) {
        super.init(begin: begin, end: end)
    }

    /// **Dart Source:** `tween.dart:512`
    public override func lerp(_ t: Double) -> Int {
        return Int(floor(Double(begin!) + Double(end! - begin!) * t))
    }
}

// MARK: - ConstantTween

/// A tween with a constant value.
///
/// **Dart Source:** `tween.dart:516-526`
public class ConstantTween<T>: Tween<T> {
    /// Create a tween whose `begin` and `end` values equal `value`.
    ///
    /// **Dart Source:** `tween.dart:518`
    public init(_ value: T) {
        super.init(begin: value, end: value)
    }

    /// This tween doesn't interpolate, it always returns the same value.
    ///
    /// **Dart Source:** `tween.dart:522`
    public override func lerp(_ t: Double) -> T {
        return begin!
    }

    /// **Dart Source:** `tween.dart:525`
    public override var tweenDescription: String {
        return "ConstantTween(value: \(begin as Any))"
    }
}

// MARK: - CurveTween

/// Transforms the value of the given animation by the given curve.
///
/// This class differs from `CurvedAnimation` in that `CurvedAnimation` applies
/// a curve to an existing `Animation` object whereas `CurveTween` can be
/// chained with another `Tween` prior to receiving the underlying `Animation`.
///
/// **Dart Source:** `tween.dart:554-572`
public class CurveTween: Animatable<Double> {
    /// Creates a curve tween.
    ///
    /// **Dart Source:** `tween.dart:556`
    public init(curve: any Curve) {
        self.curve = curve
    }

    /// The curve to use when transforming the value of the animation.
    ///
    /// **Dart Source:** `tween.dart:559`
    public var curve: any Curve

    /// **Dart Source:** `tween.dart:562-568`
    public override func transform(_ t: Double) -> Double {
        if t == 0.0 || t == 1.0 {
            assert(curve.transform(t).rounded() == t)
            return t
        }
        return curve.transform(t)
    }
}
