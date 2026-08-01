// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// TweenSequence types for defining animations from a sequence of tweens.
///
/// **Dart Source:** `packages/flutter/lib/src/animation/tween_sequence.dart`

// MARK: - TweenSequenceInterval (Internal)

/// Represents a start/end interval within [0, 1] for a TweenSequence item.
///
/// **Dart Source:** `tween_sequence.dart:151-163`
/// **Original Name:** `_Interval`
///
/// DIFFERENCE FROM DART: Renamed from `_Interval` to `TweenSequenceInterval`
/// and given internal visibility.
/// REASON: Swift does not have file-private types; internal is the closest
/// equivalent. Renamed to avoid confusion with `Interval` curve.
struct TweenSequenceInterval: CustomStringConvertible {
    /// **Dart Source:** `tween_sequence.dart:152`
    let start: Double
    let end: Double

    init(start: Double, end: Double) {
        assert(end > start)
        self.start = start
        self.end = end
    }

    /// Returns whether this interval contains the given value `t`.
    ///
    /// Uses a half-open range: [start, end).
    ///
    /// **Dart Source:** `tween_sequence.dart:157`
    func contains(_ t: Double) -> Bool {
        return t >= start && t < end
    }

    /// Returns the normalized value of `t` within this interval.
    ///
    /// Maps [start, end] to [0, 1].
    ///
    /// **Dart Source:** `tween_sequence.dart:159`
    func value(_ t: Double) -> Double {
        return (t - start) / (end - start)
    }

    /// **Dart Source:** `tween_sequence.dart:162`
    var description: String {
        return "<\(start), \(end)>"
    }
}

// MARK: - TweenSequenceItem

/// A simple holder for one element of a ``TweenSequence``.
///
/// **Dart Source:** `tween_sequence.dart:121-149`
public struct TweenSequenceItem<T> {
    /// Construct a TweenSequenceItem.
    ///
    /// The `weight` must be greater than 0.0.
    ///
    /// **Dart Source:** `tween_sequence.dart:125`
    public init(tween: Animatable<T>, weight: Double) {
        assert(weight > 0.0)
        self.tween = tween
        self.weight = weight
    }

    /// Defines the value of the ``TweenSequence`` for the interval within the
    /// animation's duration indicated by ``weight`` and this item's position
    /// in the list of items.
    ///
    /// **Dart Source:** `tween_sequence.dart:141`
    public let tween: Animatable<T>

    /// An arbitrary value that indicates the relative percentage of a
    /// ``TweenSequence`` animation's duration when ``tween`` will be used.
    ///
    /// The percentage for an individual item is the item's weight divided by the
    /// sum of all of the items' weights.
    ///
    /// **Dart Source:** `tween_sequence.dart:148`
    public let weight: Double
}

// MARK: - TweenSequence

/// Enables creating an `Animation` whose value is defined by a sequence of
/// `Tween`s.
///
/// Each ``TweenSequenceItem`` has a weight that defines its percentage of the
/// animation's duration. Each tween defines the animation's value during the
/// interval indicated by its weight.
///
/// **Dart Source:** `tween_sequence.dart:45-96`
public class TweenSequence<T>: Animatable<T> {
    /// Construct a TweenSequence.
    ///
    /// The `items` parameter must be a list of one or more ``TweenSequenceItem``s.
    ///
    /// **Dart Source:** `tween_sequence.dart:53-68`
    public init(_ items: [TweenSequenceItem<T>]) {
        assert(!items.isEmpty)
        self._items = items

        var totalWeight = 0.0
        for item in items {
            totalWeight += item.weight
        }
        assert(totalWeight > 0.0)

        var intervals: [TweenSequenceInterval] = []
        var start = 0.0
        for i in 0..<items.count {
            let end = i == items.count - 1 ? 1.0 : start + items[i].weight / totalWeight
            intervals.append(TweenSequenceInterval(start: start, end: end))
            start = end
        }
        self._intervals = intervals

        super.init()
    }

    /// **Dart Source:** `tween_sequence.dart:70`
    private let _items: [TweenSequenceItem<T>]

    /// **Dart Source:** `tween_sequence.dart:71`
    private let _intervals: [TweenSequenceInterval]

    /// **Dart Source:** `tween_sequence.dart:73-77`
    private func _evaluateAt(_ t: Double, index: Int) -> T {
        let element = _items[index]
        let tInterval = _intervals[index].value(t)
        return element.tween.transform(tInterval)
    }

    /// **Dart Source:** `tween_sequence.dart:80-92`
    public override func transform(_ t: Double) -> T {
        // Clamp to [0, 1] defensively — the animation value may slightly exceed
        // bounds due to floating-point arithmetic in RepeatingSimulation.
        let t = Swift.min(1.0, Swift.max(0.0, t.isNaN ? 0.0 : t))
        if t == 1.0 {
            return _evaluateAt(t, index: _items.count - 1)
        }
        for index in 0..<_items.count {
            if _intervals[index].contains(t) {
                return _evaluateAt(t, index: index)
            }
        }
        // Should be unreachable.
        fatalError("TweenSequence.transform() could not find an interval for \(t)")
    }
}

// MARK: - FlippedTweenSequence

/// Enables creating a flipped `Animation` whose value is defined by a sequence
/// of `Tween`s.
///
/// This creates a ``TweenSequence`` that evaluates to a result that flips the
/// tween both horizontally and vertically.
///
/// This tween sequence assumes that the evaluated result has to be a `Double`
/// between 0.0 and 1.0.
///
/// **Dart Source:** `tween_sequence.dart:106-118`
public class FlippedTweenSequence: TweenSequence<Double> {
    /// Creates a flipped ``TweenSequence``.
    ///
    /// The `items` parameter must be a list of one or more ``TweenSequenceItem``s.
    ///
    /// **Dart Source:** `tween_sequence.dart:114`
    public override init(_ items: [TweenSequenceItem<Double>]) {
        super.init(items)
    }

    /// **Dart Source:** `tween_sequence.dart:117`
    public override func transform(_ t: Double) -> Double {
        return 1 - super.transform(1 - t)
    }
}
