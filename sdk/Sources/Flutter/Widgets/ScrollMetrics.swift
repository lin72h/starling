// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - ScrollMetrics

/// A description of a `Scrollable`'s contents, useful for modeling the state
/// of its viewport.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_metrics.dart:50-159`
public protocol ScrollMetrics: AnyObject {
    /// The minimum in-range value for `pixels`.
    var minScrollExtent: Double { get }

    /// The maximum in-range value for `pixels`.
    var maxScrollExtent: Double { get }

    /// Whether the `minScrollExtent` and the `maxScrollExtent` properties are available.
    var hasContentDimensions: Bool { get }

    /// The current scroll position, in logical pixels along the `axisDirection`.
    var pixels: Double { get }

    /// Whether the `pixels` property is available.
    var hasPixels: Bool { get }

    /// The extent of the viewport along the `axisDirection`.
    var viewportDimension: Double { get }

    /// Whether the `viewportDimension` property is available.
    var hasViewportDimension: Bool { get }

    /// The direction in which the scroll view scrolls.
    var axisDirection: AxisDirection { get }

    /// The `FlutterView.devicePixelRatio` of the view that the `Scrollable`
    /// associated with this metrics object is drawn into.
    var devicePixelRatio: Double { get }

    /// Creates a `ScrollMetrics` that has the same properties as this object.
    ///
    /// **Dart Source:** `scroll_metrics.dart:60-75`
    func copyWith(
        minScrollExtent: Double?,
        maxScrollExtent: Double?,
        pixels: Double?,
        viewportDimension: Double?,
        axisDirection: AxisDirection?,
        devicePixelRatio: Double?
    ) -> FixedScrollMetrics
}

// MARK: - ScrollMetrics Default Implementations

extension ScrollMetrics {
    /// The axis in which the scroll view scrolls.
    ///
    /// **Dart Source:** `scroll_metrics.dart:111`
    public var axis: Axis {
        axisDirectionToAxis(axisDirection)
    }

    /// Whether the `pixels` value is outside the `minScrollExtent` and `maxScrollExtent`.
    ///
    /// **Dart Source:** `scroll_metrics.dart:115`
    public var outOfRange: Bool {
        pixels < minScrollExtent || pixels > maxScrollExtent
    }

    /// Whether the `pixels` value is exactly at the `minScrollExtent` or the
    /// `maxScrollExtent`.
    ///
    /// **Dart Source:** `scroll_metrics.dart:119`
    public var atEdge: Bool {
        pixels == minScrollExtent || pixels == maxScrollExtent
    }

    /// The quantity of content conceptually "above" the viewport in the scrollable.
    ///
    /// **Dart Source:** `scroll_metrics.dart:123`
    public var extentBefore: Double {
        max(pixels - minScrollExtent, 0.0)
    }

    /// The quantity of content conceptually "inside" the viewport in the scrollable.
    ///
    /// **Dart Source:** `scroll_metrics.dart:133-140`
    public var extentInside: Double {
        assert(minScrollExtent <= maxScrollExtent)
        return viewportDimension
            - clampDouble(minScrollExtent - pixels, 0, viewportDimension)
            - clampDouble(pixels - maxScrollExtent, 0, viewportDimension)
    }

    /// The quantity of content conceptually "below" the viewport in the scrollable.
    ///
    /// **Dart Source:** `scroll_metrics.dart:144`
    public var extentAfter: Double {
        max(maxScrollExtent - pixels, 0.0)
    }

    /// The total quantity of content available.
    ///
    /// **Dart Source:** `scroll_metrics.dart:150`
    public var extentTotal: Double {
        maxScrollExtent - minScrollExtent + viewportDimension
    }

    /// Default implementation of `copyWith`.
    ///
    /// **Dart Source:** `scroll_metrics.dart:60-75`
    public func copyWith(
        minScrollExtent: Double? = nil,
        maxScrollExtent: Double? = nil,
        pixels: Double? = nil,
        viewportDimension: Double? = nil,
        axisDirection: AxisDirection? = nil,
        devicePixelRatio: Double? = nil
    ) -> FixedScrollMetrics {
        return FixedScrollMetrics(
            minScrollExtent: minScrollExtent ?? (hasContentDimensions ? self.minScrollExtent : nil),
            maxScrollExtent: maxScrollExtent ?? (hasContentDimensions ? self.maxScrollExtent : nil),
            pixels: pixels ?? (hasPixels ? self.pixels : nil),
            viewportDimension: viewportDimension ?? (hasViewportDimension ? self.viewportDimension : nil),
            axisDirection: axisDirection ?? self.axisDirection,
            devicePixelRatio: devicePixelRatio ?? self.devicePixelRatio
        )
    }
}

// MARK: - FixedScrollMetrics

/// An immutable snapshot of values associated with a `Scrollable` viewport.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_metrics.dart:172-221`
public class FixedScrollMetrics: ScrollMetrics, CustomStringConvertible {

    /// Creates an immutable snapshot of values associated with a `Scrollable` viewport.
    ///
    /// **Dart Source:** `scroll_metrics.dart:174-182`
    public init(
        minScrollExtent: Double?,
        maxScrollExtent: Double?,
        pixels: Double?,
        viewportDimension: Double?,
        axisDirection: AxisDirection,
        devicePixelRatio: Double
    ) {
        self._minScrollExtent = minScrollExtent
        self._maxScrollExtent = maxScrollExtent
        self._pixels = pixels
        self._viewportDimension = viewportDimension
        self.axisDirection = axisDirection
        self.devicePixelRatio = devicePixelRatio
    }

    /// **Dart Source:** `scroll_metrics.dart:185`
    public var minScrollExtent: Double { _minScrollExtent! }
    private let _minScrollExtent: Double?

    /// **Dart Source:** `scroll_metrics.dart:188`
    public var maxScrollExtent: Double { _maxScrollExtent! }
    private let _maxScrollExtent: Double?

    /// **Dart Source:** `scroll_metrics.dart:191`
    public var hasContentDimensions: Bool { _minScrollExtent != nil && _maxScrollExtent != nil }

    /// **Dart Source:** `scroll_metrics.dart:194`
    public var pixels: Double { _pixels! }
    private let _pixels: Double?

    /// **Dart Source:** `scroll_metrics.dart:197`
    public var hasPixels: Bool { _pixels != nil }

    /// **Dart Source:** `scroll_metrics.dart:200`
    public var viewportDimension: Double { _viewportDimension! }
    private let _viewportDimension: Double?

    /// **Dart Source:** `scroll_metrics.dart:203`
    public var hasViewportDimension: Bool { _viewportDimension != nil }

    /// **Dart Source:** `scroll_metrics.dart:206`
    public let axisDirection: AxisDirection

    /// **Dart Source:** `scroll_metrics.dart:209`
    public let devicePixelRatio: Double

    /// **Dart Source:** `scroll_metrics.dart:212-214`
    public var description: String {
        return "\(objectRuntimeType(self, "FixedScrollMetrics"))(\(String(format: "%.1f", extentBefore))..\(String(format: "[%.1f]", extentInside))..\(String(format: "%.1f", extentAfter)))"
    }
}
