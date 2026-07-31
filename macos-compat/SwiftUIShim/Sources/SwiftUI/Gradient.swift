// LinearGradient reconstruction — the symbols probe/D_gradient imports beyond the
// Gallery set. A bare `LinearGradient(colors:startPoint:endPoint:)` body imports:
//   Gradient.init(colors:)                      (exported symbol — real call)
//   LinearGradient.init(gradient:startPoint:endPoint:)  (exported symbol — real call)
//   UnitPoint.top / .bottom getters             (exported symbols)
//   LinearGradient : View conformance + metadata + nominal descriptor
// The `init(colors:startPoint:endPoint:)` convenience is @_alwaysEmitIntoClient in
// Apple, so the app INLINES it into `Gradient(colors:)` + `LinearGradient(gradient:…)`
// — those two are the imported symbols, not the colors: init. We mark ours @inlinable
// to match (so our module + any non-inlined caller lower the same way).
//
// LAYOUT IS ABI-LOAD-BEARING for the *value-passing* ABI (not for field access — the
// app never field-reads these): Apple's types are @frozen, so the app's compiled call
// sites pass/return them by their exact @frozen size. UnitPoint (16 B, 2 regs) and
// Gradient (8 B, 1 reg) are passed by value INTO our init; LinearGradient (40 B) is
// RETURNED by our init via sret — a too-small reconstruction would be returned in
// registers instead, leaving the app's sret buffer unwritten (the same Binding sret
// gap from GALLERY-WORKLIST). So we mirror Apple's @frozen layouts byte-for-byte.

import Foundation

// ════════════════════════════════════════════════════════════════════════════
// MARK: - UnitPoint  (@frozen {x: CGFloat, y: CGFloat} = 16 B)
// ════════════════════════════════════════════════════════════════════════════

// Unit square: (0,0) = topLeading, (1,1) = bottomTrailing (y grows downward), so a
// LinearGradient(startPoint:.top, endPoint:.bottom) runs top→bottom. The app passes
// these by value into LinearGradient.init, so the @frozen 2×CGFloat layout matters.
@frozen public struct UnitPoint: Hashable {
    public var x: CGFloat
    public var y: CGFloat
    @inlinable public init() { self.x = 0; self.y = 0 }
    @inlinable public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }

    public static let zero            = UnitPoint(x: 0, y: 0)
    public static let center          = UnitPoint(x: 0.5, y: 0.5)
    public static let leading         = UnitPoint(x: 0, y: 0.5)
    public static let trailing        = UnitPoint(x: 1, y: 0.5)
    public static let top             = UnitPoint(x: 0.5, y: 0)
    public static let bottom          = UnitPoint(x: 0.5, y: 1)
    public static let topLeading      = UnitPoint(x: 0, y: 0)
    public static let topTrailing     = UnitPoint(x: 1, y: 0)
    public static let bottomLeading   = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing  = UnitPoint(x: 1, y: 1)
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Gradient  (@frozen {stops: [Stop]} = 8 B)
// ════════════════════════════════════════════════════════════════════════════

// Apple's Gradient is a single Array of Stops (8 B). The app builds it via the
// exported `init(colors:)` and hands the value straight to LinearGradient.init — it
// never field-accesses it — but it IS passed by value (1 register), so Gradient must
// be @frozen with a single 8-byte field to match the call's register ABI. Stop's own
// layout is internal-only (the app never names Stop), but we mirror Apple's anyway.
@frozen public struct Gradient: Equatable {
    @frozen public struct Stop: Equatable {
        public var color: Color
        public var location: CGFloat
        @inlinable public init(color: Color, location: CGFloat) {
            self.color = color; self.location = location
        }
    }
    public var stops: [Stop]
    public init(stops: [Stop]) { self.stops = stops }
    // colors → evenly-spaced stops (Apple: 0, 1/(n-1), … , 1).
    public init(colors: [Color]) {
        let n = colors.count
        if n == 1 { self.stops = [Stop(color: colors[0], location: 0)] ; return }
        self.stops = colors.enumerated().map { i, c in
            Stop(color: c, location: n > 1 ? CGFloat(i) / CGFloat(n - 1) : 0)
        }
    }
    public static func == (l: Gradient, r: Gradient) -> Bool { l.stops == r.stops }

    // Resolved color names in stop order — for the render path (see MakeView.swift).
    var _colorNames: [String] { stops.map { $0.color._name } }
}
extension Gradient: ShapeStyle {}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - LinearGradient  (@frozen {gradient, startPoint, endPoint} = 40 B; View + ShapeStyle)
// ════════════════════════════════════════════════════════════════════════════

// @frozen 40 B = Gradient(8) + UnitPoint(16) + UnitPoint(16). The exact size matters
// for the RETURN ABI: the app's call to init(gradient:startPoint:endPoint:) expects a
// 40-byte struct returned via sret (Apple is @frozen). Field ORDER is internal (the app
// reads it back only via our _makeView), so it just needs init + _makeView to agree.
@frozen public struct LinearGradient: View, ShapeStyle {
    @usableFromInline var gradient: Gradient
    @usableFromInline var startPoint: UnitPoint
    @usableFromInline var endPoint: UnitPoint

    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = gradient
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    // @_alwaysEmitIntoClient in Apple → the app inlines this to the two calls above;
    // @inlinable so our module/non-inlined callers lower the same way (no extra symbol).
    @inlinable public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
    }
    @inlinable public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.init(gradient: Gradient(stops: stops), startPoint: startPoint, endPoint: endPoint)
    }
    public typealias Body = Never
    public var body: Never { fatalError("LinearGradient is primitive") }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Angle  (@frozen {radians: CGFloat} = 8 B) — AngularGradient's angle arg
// ════════════════════════════════════════════════════════════════════════════

// Passed by value (1 register) into AngularGradient.init(gradient:center:angle:); the
// app imports no Angle metadata (its .zero/.degrees are inlined), so only the @frozen
// 8-byte layout is ABI-load-bearing — the type exists to make the init mangling match.
@frozen public struct Angle: Equatable, Comparable {
    public var radians: CGFloat
    @inlinable public var degrees: CGFloat {
        get { radians * 180 / .pi } set { radians = newValue * .pi / 180 }
    }
    @inlinable public init() { radians = 0 }
    @inlinable public init(radians: CGFloat) { self.radians = radians }
    @inlinable public init(degrees: CGFloat) { self.radians = degrees * .pi / 180 }
    @inlinable public static func radians(_ r: CGFloat) -> Angle { Angle(radians: r) }
    @inlinable public static func degrees(_ d: CGFloat) -> Angle { Angle(degrees: d) }
    public static let zero = Angle(radians: 0)
    @inlinable public static func < (l: Angle, r: Angle) -> Bool { l.radians < r.radians }
    @inlinable static func + (l: Angle, r: Angle) -> Angle { Angle(radians: l.radians + r.radians) }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - RadialGradient  (@frozen {gradient, center, startRadius, endRadius} = 40 B)
// ════════════════════════════════════════════════════════════════════════════

// Same value/sret ABI discipline as LinearGradient: 40 B (Gradient 8 + UnitPoint 16 +
// 2×CGFloat 16). Field order is internal (init + _makeView agree). startRadius/endRadius
// are absolute points; the host approximates them against Flutter's fractional radius.
@frozen public struct RadialGradient: View, ShapeStyle {
    @usableFromInline var gradient: Gradient
    @usableFromInline var center: UnitPoint
    @usableFromInline var startRadius: CGFloat
    @usableFromInline var endRadius: CGFloat

    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = gradient; self.center = center
        self.startRadius = startRadius; self.endRadius = endRadius
    }
    @inlinable public init(colors: [Color], center: UnitPoint = .center, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadius: startRadius, endRadius: endRadius)
    }
    @inlinable public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadius: CGFloat, endRadius: CGFloat) {
        self.init(gradient: Gradient(stops: stops), center: center, startRadius: startRadius, endRadius: endRadius)
    }
    public typealias Body = Never
    public var body: Never { fatalError("RadialGradient is primitive") }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - AngularGradient  (@frozen {gradient, center, startAngle, endAngle} = 40 B)
// ════════════════════════════════════════════════════════════════════════════

// 40 B (Gradient 8 + UnitPoint 16 + 2×Angle 16). The imported init(gradient:center:angle:)
// is a full-conic form: startAngle = angle, endAngle = angle + 360°. Maps to Flutter's
// SweepGradient (radians, also center-based).
@frozen public struct AngularGradient: View, ShapeStyle {
    @usableFromInline var gradient: Gradient
    @usableFromInline var center: UnitPoint
    @usableFromInline var startAngle: Angle
    @usableFromInline var endAngle: Angle

    public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {
        self.gradient = gradient; self.center = center
        self.startAngle = angle; self.endAngle = angle + .degrees(360)
    }
    public init(gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) {
        self.gradient = gradient; self.center = center
        self.startAngle = startAngle; self.endAngle = endAngle
    }
    @inlinable public init(colors: [Color], center: UnitPoint = .center, angle: Angle = .zero) {
        self.init(gradient: Gradient(colors: colors), center: center, angle: angle)
    }
    @inlinable public init(colors: [Color], center: UnitPoint = .center, startAngle: Angle, endAngle: Angle) {
        self.init(gradient: Gradient(colors: colors), center: center, startAngle: startAngle, endAngle: endAngle)
    }
    @inlinable public init(stops: [Gradient.Stop], center: UnitPoint = .center, angle: Angle = .zero) {
        self.init(gradient: Gradient(stops: stops), center: center, angle: angle)
    }
    public typealias Body = Never
    public var body: Never { fatalError("AngularGradient is primitive") }
}
