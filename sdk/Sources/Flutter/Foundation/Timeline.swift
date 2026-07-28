// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Timeline utilities for measuring how long blocks of code take to run.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`

import Foundation

// MARK: - Slice Size Constant

/// The size of each slice in the chain buffers.
///
/// **Dart Source:** `timeline.dart:262`
private let kSliceSize: Int = 500

// MARK: - Performance Timestamp

/// Returns the current timestamp in microseconds from a monotonically
/// increasing clock.
///
/// Uses `DispatchTime.now()` which provides a monotonic clock suitable
/// for performance measurements.
///
/// **Dart Source:** `_timeline_io.dart:11` and `_timeline_web.dart:15`
@inlinable
public func performanceTimestamp() -> Double {
    // DispatchTime.now() returns nanoseconds, convert to microseconds
    return Double(DispatchTime.now().uptimeNanoseconds) / 1000.0
}

// MARK: - FlutterTimeline

/// Measures how long blocks of code take to run.
///
/// This class can be used as a drop-in replacement for `Timeline` as it
/// provides methods compatible with `Timeline` signature-wise, and it has
/// minimal overhead.
///
/// Provides `debugReset` and `debugCollect` methods that make it convenient to use in
/// frame-oriented environment where collected metrics can be attributed to a
/// frame, then aggregated into frame statistics, e.g. frame averages.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `FlutterTimeline`
/// **Lines:** 24-152
public enum FlutterTimeline {
    /// The buffer used to record timing data.
    ///
    /// Note: This is intentionally `nonisolated(unsafe)` because `FlutterTimeline`
    /// is designed to be used from a single thread, similar to the original Dart
    /// implementation.
    nonisolated(unsafe) private static var _buffer = BlockBuffer()

    /// Whether block timings are collected and can be retrieved using the
    /// `debugCollect` method.
    ///
    /// This is always false in release mode.
    ///
    /// **Dart Source:** `timeline.dart:31`
    public static var debugCollectionEnabled: Bool {
        get { _collectionEnabled }
        set {
            if kReleaseMode {
                preconditionFailure("FlutterTimeline metric collection not supported in release mode.")
            }
            if newValue == _collectionEnabled {
                return
            }
            _collectionEnabled = newValue
            debugReset()
        }
    }

    /// Note: This is intentionally `nonisolated(unsafe)` because `FlutterTimeline`
    /// is designed to be used from a single thread, similar to the original Dart
    /// implementation.
    nonisolated(unsafe) private static var _collectionEnabled: Bool = false

    /// Start a synchronous operation labeled `name`.
    ///
    /// Optionally takes a map of `arguments`. This slice may also optionally be
    /// associated with a flow event. This operation must be finished by calling
    /// `finishSync` before returning to the event queue.
    ///
    /// This is a drop-in replacement for `Timeline.startSync`.
    ///
    /// **Dart Source:** `timeline.dart:66-71`
    public static func startSync(_ name: String, arguments: [String: Any]? = nil) {
        // Note: Swift doesn't have a built-in Timeline like Dart's dart:developer.
        // In a real implementation, this would integrate with os_signpost or similar.
        if !kReleaseMode && _collectionEnabled {
            _buffer.startSync(name, arguments: arguments)
        }
    }

    /// Finish the last synchronous operation that was started.
    ///
    /// This is a drop-in replacement for `Timeline.finishSync`.
    ///
    /// **Dart Source:** `timeline.dart:76-81`
    public static func finishSync() {
        // Note: Swift doesn't have a built-in Timeline like Dart's dart:developer.
        if !kReleaseMode && _collectionEnabled {
            _buffer.finishSync()
        }
    }

    /// Emit an instant event.
    ///
    /// This is a drop-in replacement for `Timeline.instantSync`.
    ///
    /// **Dart Source:** `timeline.dart:86-88`
    public static func instantSync(_ name: String, arguments: [String: Any]? = nil) {
        // Note: Swift doesn't have a built-in Timeline like Dart's dart:developer.
        // This could be implemented with os_signpost if needed.
    }

    /// A utility method to time a synchronous `function`. Internally calls
    /// `function` bracketed by calls to `startSync` and `finishSync`.
    ///
    /// This is a drop-in replacement for `Timeline.timeSync`.
    ///
    /// **Dart Source:** `timeline.dart:94-106`
    public static func timeSync<T>(
        _ name: String,
        _ function: () throws -> T,
        arguments: [String: Any]? = nil
    ) rethrows -> T {
        startSync(name, arguments: arguments)
        defer { finishSync() }
        return try function()
    }

    /// The current time stamp from the clock used by the timeline in
    /// microseconds.
    ///
    /// Uses a monotonic clock suitable for performance measurements.
    ///
    /// This is a drop-in replacement for `Timeline.now`.
    ///
    /// **Dart Source:** `timeline.dart:117`
    public static var now: Int64 {
        return Int64(performanceTimestamp())
    }

    /// Returns timings collected since `debugCollectionEnabled` was set to true,
    /// since the previous `debugCollect`, or since the previous `debugReset`,
    /// whichever was last.
    ///
    /// Resets the collected timings.
    ///
    /// This is only meant to be used in non-release modes, typically in profile
    /// mode that provides timings close to release mode timings.
    ///
    /// **Dart Source:** `timeline.dart:127-137`
    public static func debugCollect() -> AggregatedTimings {
        if kReleaseMode {
            preconditionFailure("FlutterTimeline metric collection not supported in release mode.")
        }
        if !_collectionEnabled {
            preconditionFailure("Timeline metric collection not enabled.")
        }
        let result = AggregatedTimings(_buffer.computeTimings())
        debugReset()
        return result
    }

    /// Forgets all previously collected timing data.
    ///
    /// Use this method to scope metrics to a frame, a pointer event, or any
    /// other event. To do that, call `debugReset` at the start of the event, then
    /// call `debugCollect` at the end of the event.
    ///
    /// This is only meant to be used in non-release modes.
    ///
    /// **Dart Source:** `timeline.dart:146-151`
    public static func debugReset() {
        if kReleaseMode {
            preconditionFailure("FlutterTimeline metric collection not supported in release mode.")
        }
        _buffer = BlockBuffer()
    }
}

// MARK: - TimedBlock

/// Provides `start`, `end`, and `duration` of a named block of code, timed by
/// `FlutterTimeline`.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `TimedBlock`
/// **Lines:** 157-186
public struct TimedBlock: Hashable, Sendable {
    /// Creates a timed block of code from a `name`, `start`, and `end`.
    ///
    /// The `name` should be sufficiently unique and descriptive for someone to
    /// easily tell which part of code was measured.
    ///
    /// **Dart Source:** `timeline.dart:162-163`
    public init(name: String, start: Double, end: Double) {
        assert(end >= start, "The start timestamp must not be greater than the end timestamp.")
        self.name = name
        self.start = start
        self.end = end
    }

    /// A readable label for a block of code that was measured.
    ///
    /// This field should be sufficiently unique and descriptive for someone to
    /// easily tell which part of code was measured.
    ///
    /// **Dart Source:** `timeline.dart:169`
    public let name: String

    /// The timestamp in microseconds that marks the beginning of the measured
    /// block of code.
    ///
    /// **Dart Source:** `timeline.dart:173`
    public let start: Double

    /// The timestamp in microseconds that marks the end of the measured block of
    /// code.
    ///
    /// **Dart Source:** `timeline.dart:177`
    public let end: Double

    /// How long the measured block of code took to execute in microseconds.
    ///
    /// **Dart Source:** `timeline.dart:180`
    public var duration: Double { end - start }
}

extension TimedBlock: CustomStringConvertible {
    /// **Dart Source:** `timeline.dart:183-185`
    public var description: String {
        return "TimedBlock(\(name), \(start), \(end), \(duration))"
    }
}

// MARK: - AggregatedTimings

/// Provides aggregated results for timings collected by `FlutterTimeline`.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `AggregatedTimings`
/// **Lines:** 190-228
public final class AggregatedTimings: @unchecked Sendable {
    /// Creates aggregated timings for the provided timed blocks.
    ///
    /// **Dart Source:** `timeline.dart:192`
    public init(_ timedBlocks: [TimedBlock]) {
        self.timedBlocks = timedBlocks
    }

    /// All timed blocks collected between the last reset and `FlutterTimeline.debugCollect`.
    ///
    /// **Dart Source:** `timeline.dart:195`
    public let timedBlocks: [TimedBlock]

    /// Aggregated timed blocks collected between the last reset and `FlutterTimeline.debugCollect`.
    ///
    /// Does not guarantee that all code blocks will be reported. Only those that
    /// executed since the last reset are listed here. Use `getAggregated` for
    /// graceful handling of missing code blocks.
    ///
    /// **Dart Source:** `timeline.dart:202`
    public private(set) lazy var aggregatedBlocks: [AggregatedTimedBlock] = _computeAggregatedBlocks()

    /// **Dart Source:** `timeline.dart:204-213`
    private func _computeAggregatedBlocks() -> [AggregatedTimedBlock] {
        var aggregate: [String: (duration: Double, count: Int)] = [:]
        for block in timedBlocks {
            let previousValue = aggregate[block.name] ?? (0, 0)
            aggregate[block.name] = (previousValue.duration + block.duration, previousValue.count + 1)
        }
        return aggregate.map { entry in
            AggregatedTimedBlock(name: entry.key, duration: entry.value.duration, count: entry.value.count)
        }
    }

    /// Returns aggregated numbers for a named block of code.
    ///
    /// If the block in question never executed since the last reset, returns an
    /// aggregation with zero duration and count.
    ///
    /// **Dart Source:** `timeline.dart:219-227`
    public func getAggregated(_ name: String) -> AggregatedTimedBlock {
        if let block = aggregatedBlocks.first(where: { $0.name == name }) {
            return block
        }
        // Handle the case where there are no recorded blocks of the specified
        // type. In this case, the aggregated duration is simply zero, and so is
        // the number of occurrences (i.e. count).
        return AggregatedTimedBlock(name: name, duration: 0, count: 0)
    }
}

// MARK: - AggregatedTimedBlock

/// Aggregates multiple `TimedBlock` objects that share a `name`.
///
/// It is common for the same block of code to be executed multiple times within
/// a frame. It is useful to combine multiple executions and report the total
/// amount of time attributed to that block of code.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `AggregatedTimedBlock`
/// **Lines:** 236-260
public struct AggregatedTimedBlock: Hashable, Sendable {
    /// Creates a timed block of code from a `name` and `duration`.
    ///
    /// The `name` should be sufficiently unique and descriptive for someone to
    /// easily tell which part of code was measured.
    ///
    /// **Dart Source:** `timeline.dart:241-242`
    public init(name: String, duration: Double, count: Int) {
        assert(duration >= 0)
        self.name = name
        self.duration = duration
        self.count = count
    }

    /// A readable label for a block of code that was measured.
    ///
    /// This field should be sufficiently unique and descriptive for someone to
    /// easily tell which part of code was measured.
    ///
    /// **Dart Source:** `timeline.dart:248`
    public let name: String

    /// The sum of `TimedBlock.duration` values of aggregated blocks.
    ///
    /// **Dart Source:** `timeline.dart:251`
    public let duration: Double

    /// The number of `TimedBlock` objects aggregated.
    ///
    /// **Dart Source:** `timeline.dart:254`
    public let count: Int
}

extension AggregatedTimedBlock: CustomStringConvertible {
    /// **Dart Source:** `timeline.dart:257-259`
    public var description: String {
        return "AggregatedTimedBlock(\(name), \(duration), \(count))"
    }
}

// MARK: - Float64ListChain

/// A growable list of float64 values with predictable `add` performance.
///
/// The list is organized into a "chain" of arrays. The object starts
/// with an array "slice". When `add` is called, the value is added to
/// the slice. Once the slice is full, it is moved into the chain, and a new
/// slice is allocated. Slice size is static and therefore its allocation has
/// predictable cost. This is unlike the default `Array` implementation, which,
/// when full, doubles its buffer size and copies all old elements into the new
/// buffer, leading to unpredictable performance. This makes it a poor choice
/// for recording performance because buffer reallocation would affect the
/// runtime.
///
/// The trade-off is that reading values back from the chain is more expensive
/// compared to `Array` because it requires iterating over multiple slices. This
/// is a reasonable trade-off for performance metrics, because it is more
/// important to minimize the overhead while recording metrics, than it is when
/// reading them.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `_Float64ListChain`
/// **Lines:** 281-314
internal final class Float64ListChain {
    init() {}

    private var _chain: [[Double]] = []
    private var _slice: [Double] = Array(repeating: 0, count: kSliceSize)
    private var _pointer: Int = 0

    private(set) var length: Int = 0

    /// Adds an element to this chain.
    ///
    /// **Dart Source:** `timeline.dart:292-301`
    func add(_ element: Double) {
        _slice[_pointer] = element
        _pointer += 1
        length += 1
        if _pointer >= kSliceSize {
            _chain.append(_slice)
            _slice = Array(repeating: 0, count: kSliceSize)
            _pointer = 0
        }
    }

    /// Returns all elements added to this chain.
    ///
    /// This getter is not optimized to be fast. It is assumed that when metrics
    /// are read back, they do not affect the timings of the work being
    /// benchmarked.
    ///
    /// **Dart Source:** `timeline.dart:308-313`
    func extractElements() -> [Double] {
        var result: [Double] = []
        result.reserveCapacity(length)
        for list in _chain {
            result.append(contentsOf: list)
        }
        for i in 0..<_pointer {
            result.append(_slice[i])
        }
        return result
    }
}

// MARK: - StringListChain

/// Same as `Float64ListChain` but for recording string values.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `_StringListChain`
/// **Lines:** 317-351
internal final class StringListChain {
    init() {}

    private var _chain: [[String?]] = []
    private var _slice: [String?] = Array(repeating: nil, count: kSliceSize)
    private var _pointer: Int = 0

    private(set) var length: Int = 0

    /// Adds an element to this chain.
    ///
    /// **Dart Source:** `timeline.dart:328-337`
    func add(_ element: String) {
        _slice[_pointer] = element
        _pointer += 1
        length += 1
        if _pointer >= kSliceSize {
            _chain.append(_slice)
            _slice = Array(repeating: nil, count: kSliceSize)
            _pointer = 0
        }
    }

    /// Returns all elements added to this chain.
    ///
    /// This getter is not optimized to be fast. It is assumed that when metrics
    /// are read back, they do not affect the timings of the work being
    /// benchmarked.
    ///
    /// **Dart Source:** `timeline.dart:344-350`
    func extractElements() -> [String] {
        var result: [String] = []
        result.reserveCapacity(length)
        for slice in _chain {
            for value in slice {
                result.append(value!)
            }
        }
        for i in 0..<_pointer {
            result.append(_slice[i]!)
        }
        return result
    }
}

// MARK: - BlockBuffer

/// A buffer that records starts and ends of code blocks, and their names.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/timeline.dart`
/// **Original Name:** `_BlockBuffer`
/// **Lines:** 354-416
internal final class BlockBuffer {
    // Start-finish blocks can be nested. Track this nestedness by stacking the
    // start timestamps. Finish timestamps will pop timings from the stack and
    // add the (start, finish) tuple to the _block.
    //
    // Note: These static variables are intentionally `nonisolated(unsafe)` because
    // `BlockBuffer` is designed to be used from a single thread, similar to the
    // original Dart implementation.
    private static let stackDepth: Int = 1000
    nonisolated(unsafe) private static var _startStack: [Double] = Array(repeating: 0, count: stackDepth)
    nonisolated(unsafe) private static var _nameStack: [String?] = Array(repeating: nil, count: stackDepth)
    nonisolated(unsafe) private static var _stackPointer: Int = 0

    private let _starts = Float64ListChain()
    private let _finishes = Float64ListChain()
    private let _names = StringListChain()

    /// Computes all timed blocks from the recorded data.
    ///
    /// **Dart Source:** `timeline.dart:367-391`
    func computeTimings() -> [TimedBlock] {
        assert(
            BlockBuffer._stackPointer == 0,
            """
            Invalid sequence of `startSync` and `finishSync`.
            The operation stack was not empty. The following operations are still \
            waiting to be finished via the `finishSync` method:
            \((0..<BlockBuffer._stackPointer).map { BlockBuffer._nameStack[$0]! }.joined(separator: ", "))
            """
        )

        var result: [TimedBlock] = []
        let length = _finishes.length
        let starts = _starts.extractElements()
        let finishes = _finishes.extractElements()
        let names = _names.extractElements()

        assert(starts.count == length)
        assert(finishes.count == length)
        assert(names.count == length)

        for i in 0..<length {
            result.append(TimedBlock(name: names[i], start: starts[i], end: finishes[i]))
        }

        return result
    }

    /// Starts timing a synchronous operation.
    ///
    /// **Dart Source:** `timeline.dart:393-397`
    func startSync(_ name: String, arguments: [String: Any]? = nil) {
        BlockBuffer._startStack[BlockBuffer._stackPointer] = performanceTimestamp()
        BlockBuffer._nameStack[BlockBuffer._stackPointer] = name
        BlockBuffer._stackPointer += 1
    }

    /// Finishes timing the current synchronous operation.
    ///
    /// **Dart Source:** `timeline.dart:399-415`
    func finishSync() {
        assert(
            BlockBuffer._stackPointer > 0,
            """
            Invalid sequence of `startSync` and `finishSync`.
            Attempted to finish timing a block of code, but there are no pending \
            `startSync` calls.
            """
        )

        let finishTime = performanceTimestamp()
        let startTime = BlockBuffer._startStack[BlockBuffer._stackPointer - 1]
        let name = BlockBuffer._nameStack[BlockBuffer._stackPointer - 1]!
        BlockBuffer._stackPointer -= 1

        _starts.add(startTime)
        _finishes.add(finishTime)
        _names.add(name)
    }
}
