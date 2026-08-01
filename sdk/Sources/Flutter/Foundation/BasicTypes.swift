// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Basic types used throughout the Flutter framework.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/basic_types.dart`

import FlutterSwiftBridge

// MARK: - Common Signatures

/// Signature for callbacks that report that an underlying value has changed.
///
/// See also:
///
///  * `ValueSetter`, for callbacks that report that a value has been set.
///
/// **Dart Source:** `basic_types.dart:12-17`
public typealias ValueChanged<T> = (T) -> Void

/// Signature for callbacks that report that a value has been set.
///
/// This is the same signature as `ValueChanged`, but is used when the
/// callback is called even if the underlying value has not changed.
/// For example, service extensions use this callback because they
/// call the callback whenever the extension is called with a
/// value, regardless of whether the given value is new or not.
///
/// See also:
///
///  * `ValueGetter`, the getter equivalent of this signature.
///  * `AsyncValueSetter`, an asynchronous version of this signature.
///
/// **Dart Source:** `basic_types.dart:19-31`
public typealias ValueSetter<T> = (T) -> Void

/// Signature for callbacks that are to report a value on demand.
///
/// See also:
///
///  * `ValueSetter`, the setter equivalent of this signature.
///  * `AsyncValueGetter`, an asynchronous version of this signature.
///
/// **Dart Source:** `basic_types.dart:33-39`
public typealias ValueGetter<T> = () -> T

/// Signature for callbacks that filter an iterable.
///
/// **Dart Source:** `basic_types.dart:41-42`
public typealias IterableFilter<T> = (any Sequence<T>) -> any Sequence<T>

// MARK: - Async Signatures

/// Signature of callbacks that have no arguments and return no data, but that
/// return a Future to indicate when their work is complete.
///
/// See also:
///
///  * `VoidCallback`, a synchronous version of this signature.
///  * `AsyncValueGetter`, a signature for asynchronous getters.
///  * `AsyncValueSetter`, a signature for asynchronous setters.
///
/// **Dart Source:** `basic_types.dart:44-52`
public typealias AsyncCallback = () async -> Void

/// Signature for callbacks that report that a value has been set and return a
/// Future that completes when the value has been saved.
///
/// See also:
///
///  * `ValueSetter`, a synchronous version of this signature.
///  * `AsyncValueGetter`, the getter equivalent of this signature.
///
/// **Dart Source:** `basic_types.dart:54-61`
public typealias AsyncValueSetter<T> = (T) async -> Void

/// Signature for callbacks that are to asynchronously report a value on demand.
///
/// See also:
///
///  * `ValueGetter`, a synchronous version of this signature.
///  * `AsyncValueSetter`, the setter equivalent of this signature.
///
/// **Dart Source:** `basic_types.dart:63-69`
public typealias AsyncValueGetter<T> = () async -> T

// MARK: - Lazy Caching Iterable

/// A lazy caching version of `Sequence`.
///
/// This iterable is efficient in the following ways:
///
///  * It will not walk the given iterator more than you ask for.
///
///  * If you use it twice (e.g. you check `isEmpty`, then
///    use `first`), it will only walk the given iterator
///    once. This caching will even work efficiently if you are
///    running two side-by-side iterators on the same iterable.
///
///  * `toArray()` uses the cached results to create its
///    array quickly.
///
/// It is inefficient in the following ways:
///
///  * The first iteration through has caching overhead.
///
///  * It requires more memory than a non-caching iterator.
///
///  * The `count` and `toArray()` properties immediately pre-cache the
///    entire list. Using these fields therefore loses the laziness of
///    the iterable. However, it still gets cached.
///
/// The caching behavior is propagated to the iterators that are
/// created by `map`, `filter`, `prefix`, and `drop`.
///
/// Because a CachingIterable only walks the underlying data once, it
/// cannot be used multiple times with the underlying data changing
/// between each use. You must create a new iterable each time. This
/// also applies to any iterables derived from this one, e.g. as
/// returned by `filter`.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/basic_types.dart`
/// **Original Name:** `CachingIterable`
/// **Lines:** 73-212
public final class CachingIterable<E>: Sequence {
    public typealias Element = E
    public typealias Iterator = CachingIterator<E>

    /// The source iterator that provides elements on-demand.
    private var _prefillIterator: AnyIterator<E>

    /// The cached results.
    internal var _results: [E] = []

    /// Creates a `CachingIterable` using the given `IteratorProtocol` as the source of
    /// data. The iterator must not throw exceptions.
    ///
    /// Since the argument is an `IteratorProtocol`, not a `Sequence`, it is
    /// guaranteed that the underlying data set will only be walked
    /// once. If you have a `Sequence`, you can pass its `makeIterator()`
    /// result as the argument to this constructor.
    ///
    /// **Dart Source:** `basic_types.dart:108-133`
    public init<I: IteratorProtocol>(_ iterator: I) where I.Element == E {
        var mutableIterator = iterator
        self._prefillIterator = AnyIterator { mutableIterator.next() }
    }

    /// Creates a `CachingIterable` from a `Sequence`.
    ///
    /// Convenience initializer that accepts a Sequence instead of an Iterator.
    public init<S: Sequence>(_ sequence: S) where S.Element == E {
        var iterator = sequence.makeIterator()
        self._prefillIterator = AnyIterator { iterator.next() }
    }

    /// Returns an iterator over the elements of this sequence.
    ///
    /// **Dart Source:** `basic_types.dart:138-141`
    public func makeIterator() -> CachingIterator<E> {
        return CachingIterator(self)
    }

    /// Returns a new `CachingIterable` that transforms each element using the given closure.
    ///
    /// **Dart Source:** `basic_types.dart:143-146`
    public func cachingMap<T>(_ transform: @escaping (E) -> T) -> CachingIterable<T> {
        return CachingIterable<T>(self.lazy.map(transform))
    }

    /// Returns a new `CachingIterable` that contains only elements that satisfy the given predicate.
    ///
    /// **Dart Source:** `basic_types.dart:148-151`
    public func cachingFilter(_ isIncluded: @escaping (E) -> Bool) -> CachingIterable<E> {
        return CachingIterable<E>(self.lazy.filter(isIncluded))
    }

    /// Returns a new `CachingIterable` containing the first `n` elements.
    ///
    /// **Dart Source:** `basic_types.dart:158-161`
    public func cachingPrefix(_ maxLength: Int) -> CachingIterable<E> {
        return CachingIterable<E>(self.prefix(maxLength))
    }

    /// Returns a new `CachingIterable` that skips the first `n` elements.
    ///
    /// **Dart Source:** `basic_types.dart:168-171`
    public func cachingDropFirst(_ k: Int) -> CachingIterable<E> {
        return CachingIterable<E>(self.dropFirst(k))
    }

    /// The number of elements in the sequence.
    ///
    /// This will pre-cache the entire list. Using this property therefore
    /// loses the laziness of the iterable. However, it still gets cached.
    ///
    /// **Dart Source:** `basic_types.dart:178-182`
    public var count: Int {
        _precacheEntireList()
        return _results.count
    }

    /// Returns the element at the specified index.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: The element at the specified position.
    /// - Precondition: `index` must be a valid index of the collection.
    ///
    /// **Dart Source:** `basic_types.dart:184-193`
    public subscript(index: Int) -> E {
        precondition(index >= 0, "Index must be non-negative")
        while _results.count <= index {
            if !_fillNext() {
                preconditionFailure("Index \(index) out of bounds (length: \(_results.count))")
            }
        }
        return _results[index]
    }

    /// Returns an array containing the results of this sequence.
    ///
    /// This will pre-cache the entire list.
    ///
    /// **Dart Source:** `basic_types.dart:195-199`
    public func toArray() -> [E] {
        _precacheEntireList()
        return Array(_results)
    }

    /// Pre-caches all remaining elements from the source iterator.
    ///
    /// **Dart Source:** `basic_types.dart:201-203`
    internal func _precacheEntireList() {
        while _fillNext() {}
    }

    /// Fills the next element from the source iterator into the cache.
    ///
    /// - Returns: `true` if an element was added, `false` if the iterator is exhausted.
    ///
    /// **Dart Source:** `basic_types.dart:205-211`
    internal func _fillNext() -> Bool {
        guard let next = _prefillIterator.next() else {
            return false
        }
        _results.append(next)
        return true
    }
}

/// An iterator for `CachingIterable` that reads from the cache when possible.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/basic_types.dart`
/// **Original Name:** `_LazyListIterator`
/// **Lines:** 214-240
public final class CachingIterator<E>: IteratorProtocol {
    public typealias Element = E

    /// The owning `CachingIterable`.
    private let _owner: CachingIterable<E>

    /// The current index in the cached results.
    private var _index: Int

    /// Creates an iterator for the given `CachingIterable`.
    ///
    /// **Dart Source:** `basic_types.dart:215`
    internal init(_ owner: CachingIterable<E>) {
        self._owner = owner
        self._index = -1
    }

    /// Advances to the next element and returns it, or `nil` if no next element exists.
    ///
    /// In Swift's `IteratorProtocol`, `next()` returns `Element?` and serves
    /// the combined purpose of Dart's `moveNext()` and `current` getter.
    ///
    /// **Dart Source:** `basic_types.dart:229-239`
    public func next() -> E? {
        _index += 1

        // If we're past the cached results, try to fill more
        if _index >= _owner._results.count {
            if !_owner._fillNext() {
                // Iterator exhausted, back up and return nil
                _index -= 1
                return nil
            }
        }

        return _owner._results[_index]
    }
}

// MARK: - Factory

/// A factory interface that also reports the type of the created objects.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/basic_types.dart`
/// **Original Name:** `Factory`
/// **Lines:** 242-257
public struct Factory<T> {
    /// Creates a new object of type T.
    ///
    /// **Dart Source:** `basic_types.dart:247-248`
    public let constructor: ValueGetter<T>

    /// Creates a new factory.
    ///
    /// **Dart Source:** `basic_types.dart:244-245`
    public init(_ constructor: @escaping ValueGetter<T>) {
        self.constructor = constructor
    }

    /// The type of the objects created by this factory.
    ///
    /// **Dart Source:** `basic_types.dart:250-251`
    public var type: Any.Type { T.self }
}

extension Factory: CustomStringConvertible {
    /// Returns a string representation of this factory.
    ///
    /// **Dart Source:** `basic_types.dart:253-256`
    public var description: String {
        return "Factory(type: \(type))"
    }
}

// MARK: - Duration Interpolation

/// Linearly interpolate between two `Duration`s.
///
/// This function performs linear interpolation between two durations based on
/// the parameter `t`, where `t == 0.0` returns `a`, `t == 1.0` returns `b`,
/// and values in between return proportionally interpolated durations.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/basic_types.dart`
/// **Original Name:** `lerpDuration`
/// **Lines:** 259-264
public func lerpDuration(_ a: Duration, _ b: Duration, _ t: Double) -> Duration {
    let aMicros = a.components.seconds * 1_000_000 + a.components.attoseconds / 1_000_000_000_000
    let bMicros = b.components.seconds * 1_000_000 + b.components.attoseconds / 1_000_000_000_000
    let result = Double(aMicros) + Double(bMicros - aMicros) * t
    return .microseconds(Int64(result.rounded()))
}
