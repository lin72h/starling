// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Velocity tracking types for pointer gesture recognition.
///
/// Provides velocity estimation from sequences of pointer position samples,
/// using least-squares polynomial fitting (for the base `VelocityTracker`) or
/// weighted averaging (for the iOS and macOS scroll view fling trackers).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/velocity_tracker.dart`

import FlutterSwiftBridge
import Foundation

// MARK: - Duration Helpers (internal to this file)

/// Converts a Swift `Duration` to microseconds as an `Int64`.
///
/// Swift's `Duration` stores time as (seconds, attoseconds). This helper
/// converts that representation into a single microsecond count, matching
/// Dart's `Duration.inMicroseconds`.
private func durationToMicroseconds(_ duration: Duration) -> Int64 {
    let components = duration.components
    return components.seconds * 1_000_000 + components.attoseconds / 1_000_000_000_000
}

/// Converts a Swift `Duration` to milliseconds as an `Int64`.
///
/// Equivalent to Dart's `Duration.inMilliseconds`.
private func durationToMilliseconds(_ duration: Duration) -> Int64 {
    let components = duration.components
    return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
}

// MARK: - SimpleStopwatch

/// A simple stopwatch replacement for velocity tracking.
///
/// In Dart, `VelocityTracker` uses `GestureBinding.instance.samplingClock.stopwatch()`.
/// Since `GestureBinding` is not yet migrated, this provides equivalent elapsed-time
/// tracking using `ProcessInfo.processInfo.systemUptime`.
///
/// **Dart Source:** `velocity_tracker.dart:151-156` (Stopwatch via GestureBinding)
///
/// DIFFERENCE FROM DART: Uses `ProcessInfo.systemUptime` instead of
/// `GestureBinding.instance.samplingClock.stopwatch()`.
/// REASON: `GestureBinding` is not yet migrated to Swift.
internal class SimpleStopwatch {
    private var startTime: TimeInterval?

    /// The elapsed time since the stopwatch was last started/reset.
    var elapsedMilliseconds: Int {
        guard let startTime = startTime else { return 0 }
        return Int((ProcessInfo.processInfo.systemUptime - startTime) * 1000)
    }

    /// Starts the stopwatch. If already started, this is a no-op.
    func start() {
        if startTime == nil {
            startTime = ProcessInfo.processInfo.systemUptime
        }
    }

    /// Resets the elapsed time to zero and records a new start time.
    func reset() {
        startTime = ProcessInfo.processInfo.systemUptime
    }
}

// MARK: - Velocity

/// A velocity in two dimensions.
///
/// **Dart Source:** `velocity_tracker.dart:14-72` (class `Velocity`)
public struct Velocity: Hashable, CustomStringConvertible, Sendable {

    /// Creates a `Velocity` with the given pixels-per-second offset.
    ///
    /// **Dart Source:** `velocity_tracker.dart:17`
    public init(pixelsPerSecond: Offset) {
        self.pixelsPerSecond = pixelsPerSecond
    }

    /// A velocity that isn't moving at all.
    ///
    /// **Dart Source:** `velocity_tracker.dart:20`
    public static let zero = Velocity(pixelsPerSecond: .zero)

    /// The number of pixels per second of velocity in the x and y directions.
    ///
    /// **Dart Source:** `velocity_tracker.dart:23`
    public let pixelsPerSecond: Offset

    /// Return the negation of a velocity.
    ///
    /// **Dart Source:** `velocity_tracker.dart:26`
    public static prefix func - (velocity: Velocity) -> Velocity {
        Velocity(pixelsPerSecond: -velocity.pixelsPerSecond)
    }

    /// Return the difference of two velocities.
    ///
    /// **Dart Source:** `velocity_tracker.dart:29-31`
    public static func - (lhs: Velocity, rhs: Velocity) -> Velocity {
        Velocity(pixelsPerSecond: lhs.pixelsPerSecond - rhs.pixelsPerSecond)
    }

    /// Return the sum of two velocities.
    ///
    /// **Dart Source:** `velocity_tracker.dart:34-36`
    public static func + (lhs: Velocity, rhs: Velocity) -> Velocity {
        Velocity(pixelsPerSecond: lhs.pixelsPerSecond + rhs.pixelsPerSecond)
    }

    /// Return a velocity whose magnitude has been clamped to `minValue`
    /// and `maxValue`.
    ///
    /// If the magnitude of this Velocity is less than `minValue` then return a new
    /// Velocity with the same direction and with magnitude `minValue`. Similarly,
    /// if the magnitude of this Velocity is greater than `maxValue` then return a
    /// new Velocity with the same direction and magnitude `maxValue`.
    ///
    /// If the magnitude of this Velocity is within the specified bounds then
    /// just return this.
    ///
    /// **Dart Source:** `velocity_tracker.dart:48-59`
    public func clampMagnitude(minValue: Double, maxValue: Double) -> Velocity {
        assert(minValue >= 0.0)
        assert(maxValue >= 0.0 && maxValue >= minValue)
        let valueSquared = pixelsPerSecond.distanceSquared
        if valueSquared > maxValue * maxValue {
            return Velocity(
                pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * maxValue
            )
        }
        if valueSquared < minValue * minValue {
            return Velocity(
                pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * minValue
            )
        }
        return self
    }

    // MARK: Hashable

    /// **Dart Source:** `velocity_tracker.dart:62-64`
    public static func == (lhs: Velocity, rhs: Velocity) -> Bool {
        lhs.pixelsPerSecond == rhs.pixelsPerSecond
    }

    /// **Dart Source:** `velocity_tracker.dart:67`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pixelsPerSecond)
    }

    // MARK: CustomStringConvertible

    /// **Dart Source:** `velocity_tracker.dart:70-71`
    public var description: String {
        "Velocity(\(String(format: "%.1f", pixelsPerSecond.dx)), \(String(format: "%.1f", pixelsPerSecond.dy)))"
    }
}

// MARK: - VelocityEstimate

/// A two dimensional velocity estimate.
///
/// `VelocityEstimate`s are computed by `VelocityTracker.getVelocityEstimate()`. An
/// estimate's `confidence` measures how well the velocity tracker's position
/// data fit a straight line, `duration` is the time that elapsed between the
/// first and last position sample used to compute the velocity, and `offset`
/// is similarly the difference between the first and last positions.
///
/// See also:
///
///  * `VelocityTracker`, which computes `VelocityEstimate`s.
///  * `Velocity`, which encapsulates (just) a velocity vector and provides some
///    useful velocity operations.
///
/// **Dart Source:** `velocity_tracker.dart:87-116` (class `VelocityEstimate`)
public struct VelocityEstimate: CustomStringConvertible {

    /// Creates a dimensional velocity estimate.
    ///
    /// **Dart Source:** `velocity_tracker.dart:89-94`
    public init(pixelsPerSecond: Offset, confidence: Double, duration: Duration, offset: Offset) {
        self.pixelsPerSecond = pixelsPerSecond
        self.confidence = confidence
        self.duration = duration
        self.offset = offset
    }

    /// The number of pixels per second of velocity in the x and y directions.
    ///
    /// **Dart Source:** `velocity_tracker.dart:97`
    public let pixelsPerSecond: Offset

    /// A value between 0.0 and 1.0 that indicates how well `VelocityTracker`
    /// was able to fit a straight line to its position data.
    ///
    /// The value of this property is 1.0 for a perfect fit, 0.0 for a poor fit.
    ///
    /// **Dart Source:** `velocity_tracker.dart:103`
    public let confidence: Double

    /// The time that elapsed between the first and last position sample used
    /// to compute `pixelsPerSecond`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:107`
    public let duration: Duration

    /// The difference between the first and last position sample used
    /// to compute `pixelsPerSecond`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:111`
    public let offset: Offset

    // MARK: CustomStringConvertible

    /// **Dart Source:** `velocity_tracker.dart:114-115`
    public var description: String {
        "VelocityEstimate(\(String(format: "%.1f", pixelsPerSecond.dx)), \(String(format: "%.1f", pixelsPerSecond.dy)); offset: \(offset), duration: \(duration), confidence: \(String(format: "%.1f", confidence)))"
    }
}

// MARK: - PointAtTime

/// A position sample at a particular point in time.
///
/// **Dart Source:** `velocity_tracker.dart:118-126` (class `_PointAtTime`)
///
/// DIFFERENCE FROM DART: Internal instead of private (file-private).
/// REASON: Swift's access control model differs from Dart's; `internal` is
/// appropriate for cross-file access within the module.
internal struct PointAtTime: CustomStringConvertible {

    /// Creates a point-at-time sample.
    ///
    /// **Dart Source:** `velocity_tracker.dart:119`
    init(point: Offset, time: Duration) {
        self.point = point
        self.time = time
    }

    /// The time at which this position was recorded.
    ///
    /// **Dart Source:** `velocity_tracker.dart:121`
    let time: Duration

    /// The position of the pointer at `time`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:122`
    let point: Offset

    // MARK: CustomStringConvertible

    /// **Dart Source:** `velocity_tracker.dart:125`
    var description: String {
        "PointAtTime(\(point) at \(time))"
    }
}

// MARK: - VelocityTracker

/// Computes a pointer's velocity based on data from `PointerMoveEvent`s.
///
/// The input data is provided by calling `addPosition`. Adding data is cheap.
///
/// To obtain a velocity, call `getVelocity` or `getVelocityEstimate`. This will
/// compute the velocity based on the data added so far. Only call these when
/// you need to use the velocity, as they are comparatively expensive.
///
/// The quality of the velocity estimation will be better if more data points
/// have been received.
///
/// **Dart Source:** `velocity_tracker.dart:138-272` (class `VelocityTracker`)
public class VelocityTracker {

    /// Create a new velocity tracker for a pointer `kind`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:140`
    public init(kind: PointerDeviceKind) {
        self.kind = kind
    }

    // MARK: - Constants

    /// If the pointer has not moved for this many milliseconds, assume it has
    /// stopped.
    ///
    /// **Dart Source:** `velocity_tracker.dart:142`
    internal static let assumePointerMoveStoppedMilliseconds = 40

    /// Size of the circular sample buffer.
    ///
    /// **Dart Source:** `velocity_tracker.dart:143`
    fileprivate static let historySize = 20

    /// Only consider samples within this time horizon (milliseconds).
    ///
    /// **Dart Source:** `velocity_tracker.dart:144`
    private static let horizonMilliseconds = 100

    /// Minimum number of samples required for a least-squares fit.
    ///
    /// **Dart Source:** `velocity_tracker.dart:145`
    private static let minSampleSize = 3

    // MARK: - Properties

    /// The kind of pointer this tracker is for.
    ///
    /// **Dart Source:** `velocity_tracker.dart:148`
    public let kind: PointerDeviceKind

    /// Time difference since the last sample was added.
    ///
    /// **Dart Source:** `velocity_tracker.dart:151-154`
    ///
    /// DIFFERENCE FROM DART: Uses `SimpleStopwatch` instead of
    /// `GestureBinding.instance.samplingClock.stopwatch()`.
    /// REASON: `GestureBinding` is not yet migrated to Swift.
    internal lazy var sinceLastSample: SimpleStopwatch = SimpleStopwatch()

    /// Circular buffer; current sample at `index`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:159`
    fileprivate var samples: [PointAtTime?] = Array(repeating: nil, count: VelocityTracker.historySize)

    /// The current index into the circular buffer.
    ///
    /// **Dart Source:** `velocity_tracker.dart:160`
    fileprivate var index: Int = 0

    // MARK: - Methods

    /// Adds a position as the given time to the tracker.
    ///
    /// **Dart Source:** `velocity_tracker.dart:163-171`
    public func addPosition(_ time: Duration, _ position: Offset) {
        sinceLastSample.start()
        sinceLastSample.reset()
        index += 1
        if index == VelocityTracker.historySize {
            index = 0
        }
        samples[index] = PointAtTime(point: position, time: time)
    }

    /// Returns an estimate of the velocity of the object being tracked by the
    /// tracker given the current information available to the tracker.
    ///
    /// Information is added using `addPosition`.
    ///
    /// Returns `nil` if there is no data on which to base an estimate.
    ///
    /// **Dart Source:** `velocity_tracker.dart:179-256`
    public func getVelocityEstimate() -> VelocityEstimate? {
        // Has user recently moved since last sample?
        if sinceLastSample.elapsedMilliseconds > VelocityTracker.assumePointerMoveStoppedMilliseconds {
            return VelocityEstimate(
                pixelsPerSecond: .zero,
                confidence: 1.0,
                duration: .zero,
                offset: .zero
            )
        }

        var x: [Double] = []
        var y: [Double] = []
        var w: [Double] = []
        var time: [Double] = []
        var sampleCount = 0
        var currentIndex = index

        guard let newestSample = samples[currentIndex] else {
            return nil
        }

        var previousSample = newestSample
        var oldestSample = newestSample

        // Starting with the most recent PointAtTime sample, iterate backwards while
        // the samples represent continuous motion.
        repeat {
            guard let sample = samples[currentIndex] else {
                break
            }

            let age = Double(durationToMicroseconds(newestSample.time - sample.time)) / 1000.0
            let delta = Double(abs(durationToMicroseconds(sample.time - previousSample.time))) / 1000.0
            previousSample = sample
            if age > Double(VelocityTracker.horizonMilliseconds)
                || delta > Double(VelocityTracker.assumePointerMoveStoppedMilliseconds)
            {
                break
            }

            oldestSample = sample
            let position = sample.point
            x.append(position.dx)
            y.append(position.dy)
            w.append(1.0)
            time.append(-age)
            currentIndex = (currentIndex == 0 ? VelocityTracker.historySize : currentIndex) - 1

            sampleCount += 1
        } while sampleCount < VelocityTracker.historySize

        if sampleCount >= VelocityTracker.minSampleSize {
            let xFit = LeastSquaresSolver(x: time, y: x, w: w).solve(degree: 2)
            let yFit = LeastSquaresSolver(x: time, y: y, w: w).solve(degree: 2)

            if let xFit = xFit, let yFit = yFit {
                return VelocityEstimate(
                    // convert from pixels/ms to pixels/s
                    pixelsPerSecond: Offset(
                        xFit.coefficients[1] * 1000,
                        yFit.coefficients[1] * 1000
                    ),
                    confidence: xFit.confidence * yFit.confidence,
                    duration: newestSample.time - oldestSample.time,
                    offset: newestSample.point - oldestSample.point
                )
            }
        }

        // We're unable to make a velocity estimate but we did have at least one
        // valid pointer position.
        return VelocityEstimate(
            pixelsPerSecond: .zero,
            confidence: 1.0,
            duration: newestSample.time - oldestSample.time,
            offset: newestSample.point - oldestSample.point
        )
    }

    /// Computes the velocity of the pointer at the time of the last
    /// provided data point.
    ///
    /// This can be expensive. Only call this when you need the velocity.
    ///
    /// Returns `Velocity.zero` if there is no data from which to compute an
    /// estimate or if the estimated velocity is zero.
    ///
    /// **Dart Source:** `velocity_tracker.dart:265-271`
    public func getVelocity() -> Velocity {
        let estimate = getVelocityEstimate()
        if estimate == nil || estimate!.pixelsPerSecond == Offset.zero {
            return .zero
        }
        return Velocity(pixelsPerSecond: estimate!.pixelsPerSecond)
    }
}

// MARK: - IOSScrollViewFlingVelocityTracker

/// A `VelocityTracker` subclass that provides a close approximation of iOS
/// scroll view's velocity estimation strategy.
///
/// The estimated velocity reported by this class is a close approximation of
/// the velocity an iOS scroll view would report with the same
/// `PointerMoveEvent`s, when the touch that initiates a fling is released.
///
/// This class differs from the `VelocityTracker` class in that it uses weighted
/// average of the latest few velocity samples of the tracked pointer, instead
/// of doing a linear regression on a relatively large amount of data points, to
/// estimate the velocity of the tracked pointer. Adding data points and
/// estimating the velocity are both cheap.
///
/// To obtain a velocity, call `getVelocity` or `getVelocityEstimate`. The
/// estimated velocity is typically used as the initial flinging velocity of a
/// `Scrollable`, when its drag gesture ends.
///
/// See also:
///
/// * [scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate/1619385-scrollviewwillenddragging),
///   the iOS method that reports the fling velocity when the touch is released.
///
/// **Dart Source:** `velocity_tracker.dart:295-398` (class `IOSScrollViewFlingVelocityTracker`)
public class IOSScrollViewFlingVelocityTracker: VelocityTracker {

    /// Create a new IOSScrollViewFlingVelocityTracker.
    ///
    /// **Dart Source:** `velocity_tracker.dart:297`
    public override init(kind: PointerDeviceKind) {
        super.init(kind: kind)
    }

    /// The velocity estimation uses at most 4 `PointAtTime` samples. The extra
    /// samples are there to make the `VelocityEstimate.offset` sufficiently large
    /// to be recognized as a fling. See
    /// `VerticalDragGestureRecognizer.isFlingGesture`.
    ///
    /// **Dart Source:** `velocity_tracker.dart:303`
    fileprivate static let sampleSize = 20

    /// **Dart Source:** `velocity_tracker.dart:305`
    fileprivate var touchSamples: [PointAtTime?] = Array(
        repeating: nil, count: IOSScrollViewFlingVelocityTracker.sampleSize
    )

    // MARK: - Overrides

    /// **Dart Source:** `velocity_tracker.dart:308-323`
    public override func addPosition(_ time: Duration, _ position: Offset) {
        sinceLastSample.start()
        sinceLastSample.reset()
        assert({
            let previousPoint = touchSamples[index]
            if previousPoint == nil || durationToMicroseconds(previousPoint!.time) <= durationToMicroseconds(time) {
                return true
            }
            assertionFailure(
                "The position being added (\(position)) has a smaller timestamp (\(time)) "
                    + "than its predecessor: \(previousPoint!)."
            )
            return false
        }())
        index = (index + 1) % IOSScrollViewFlingVelocityTracker.sampleSize
        touchSamples[index] = PointAtTime(point: position, time: time)
    }

    // MARK: - Velocity Computation

    /// Computes the velocity using 2 adjacent points in history. When `index` = 0,
    /// it uses the latest point recorded and the point recorded immediately before
    /// it. The smaller `index` is, the earlier in history the points used are.
    ///
    /// **Dart Source:** `velocity_tracker.dart:328-345`
    fileprivate func previousVelocityAt(_ offset: Int) -> Offset {
        let size = IOSScrollViewFlingVelocityTracker.sampleSize
        let endIndex = (index + offset) %% size
        let startIndex = (index + offset - 1) %% size
        let end = touchSamples[endIndex]
        let start = touchSamples[startIndex]

        guard let end = end, let start = start else {
            return .zero
        }

        let dt = durationToMicroseconds(end.time - start.time)
        assert(dt >= 0)

        return dt > 0
            // Convert dt to milliseconds to preserve floating point precision.
            ? (end.point - start.point) * 1000.0 / (Double(dt) / 1000.0)
            : .zero
    }

    /// **Dart Source:** `velocity_tracker.dart:348-397`
    public override func getVelocityEstimate() -> VelocityEstimate? {
        // Has user recently moved since last sample?
        if sinceLastSample.elapsedMilliseconds > VelocityTracker.assumePointerMoveStoppedMilliseconds {
            return VelocityEstimate(
                pixelsPerSecond: .zero,
                confidence: 1.0,
                duration: .zero,
                offset: .zero
            )
        }

        // The velocity estimated using this expression is an approximation of the
        // scroll velocity of an iOS scroll view at the moment the user touch was
        // released, not the final velocity of the iOS pan gesture recognizer
        // installed on the scroll view would report. Typically in an iOS scroll
        // view the velocity values are different between the two, because the
        // scroll view usually slows down when the touch is released.
        let estimatedVelocity =
            previousVelocityAt(-2) * 0.6
            + previousVelocityAt(-1) * 0.35
            + previousVelocityAt(0) * 0.05

        let newestSample = touchSamples[index]
        var oldestNonNullSample: PointAtTime?

        let size = IOSScrollViewFlingVelocityTracker.sampleSize
        for i in 1...size {
            oldestNonNullSample = touchSamples[(index + i) % size]
            if oldestNonNullSample != nil {
                break
            }
        }

        if oldestNonNullSample == nil || newestSample == nil {
            assertionFailure("There must be at least 1 point in touchSamples: \(touchSamples)")
            return VelocityEstimate(
                pixelsPerSecond: .zero,
                confidence: 0.0,
                duration: .zero,
                offset: .zero
            )
        } else {
            return VelocityEstimate(
                pixelsPerSecond: estimatedVelocity,
                confidence: 1.0,
                duration: newestSample!.time - oldestNonNullSample!.time,
                offset: newestSample!.point - oldestNonNullSample!.point
            )
        }
    }
}

// MARK: - Modulo Operator (Python-style)

/// Python-style modulo operator that always returns a non-negative result.
///
/// Swift's `%` operator preserves the sign of the dividend, which can produce
/// negative results for negative dividends. This operator ensures the result
/// is always in the range `[0, rhs)`, matching Dart's `%` behavior for
/// positive `rhs`.
///
/// Used by the velocity tracker subclasses for circular buffer index arithmetic.
infix operator %%: MultiplicationPrecedence

/// Python-style modulo that always returns a non-negative result.
func %% (lhs: Int, rhs: Int) -> Int {
    let result = lhs % rhs
    return result >= 0 ? result : result + rhs
}

// MARK: - MacOSScrollViewFlingVelocityTracker

/// A `VelocityTracker` subclass that provides a close approximation of macOS
/// scroll view's velocity estimation strategy.
///
/// The estimated velocity reported by this class is a close approximation of
/// the velocity a macOS scroll view would report with the same
/// `PointerMoveEvent`s, when the touch that initiates a fling is released.
///
/// This class differs from the `VelocityTracker` class in that it uses weighted
/// average of the latest few velocity samples of the tracked pointer, instead
/// of doing a linear regression on a relatively large amount of data points, to
/// estimate the velocity of the tracked pointer. Adding data points and
/// estimating the velocity are both cheap.
///
/// To obtain a velocity, call `getVelocity` or `getVelocityEstimate`. The
/// estimated velocity is typically used as the initial flinging velocity of a
/// `Scrollable`, when its drag gesture ends.
///
/// **Dart Source:** `velocity_tracker.dart:416-469` (class `MacOSScrollViewFlingVelocityTracker`)
public class MacOSScrollViewFlingVelocityTracker: IOSScrollViewFlingVelocityTracker {

    /// Create a new MacOSScrollViewFlingVelocityTracker.
    ///
    /// **Dart Source:** `velocity_tracker.dart:418`
    public override init(kind: PointerDeviceKind) {
        super.init(kind: kind)
    }

    /// **Dart Source:** `velocity_tracker.dart:421-468`
    public override func getVelocityEstimate() -> VelocityEstimate? {
        // Has user recently moved since last sample?
        if sinceLastSample.elapsedMilliseconds > VelocityTracker.assumePointerMoveStoppedMilliseconds {
            return VelocityEstimate(
                pixelsPerSecond: .zero,
                confidence: 1.0,
                duration: .zero,
                offset: .zero
            )
        }

        // The velocity estimated using this expression is an approximation of the
        // scroll velocity of a macOS scroll view at the moment the user touch was
        // released.
        let estimatedVelocity =
            previousVelocityAt(-2) * 0.15
            + previousVelocityAt(-1) * 0.65
            + previousVelocityAt(0) * 0.2

        let newestSample = touchSamples[index]
        var oldestNonNullSample: PointAtTime?

        let size = IOSScrollViewFlingVelocityTracker.sampleSize
        for i in 1...size {
            oldestNonNullSample = touchSamples[(index + i) % size]
            if oldestNonNullSample != nil {
                break
            }
        }

        if oldestNonNullSample == nil || newestSample == nil {
            assertionFailure("There must be at least 1 point in touchSamples: \(touchSamples)")
            return VelocityEstimate(
                pixelsPerSecond: .zero,
                confidence: 0.0,
                duration: .zero,
                offset: .zero
            )
        } else {
            return VelocityEstimate(
                pixelsPerSecond: estimatedVelocity,
                confidence: 1.0,
                duration: newestSample!.time - oldestNonNullSample!.time,
                offset: newestSample!.point - oldestNonNullSample!.point
            )
        }
    }
}
