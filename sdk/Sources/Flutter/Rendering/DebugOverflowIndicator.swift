// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Debug visual indicators for when a render object overflows its container.
///
/// This file provides the `DebugOverflowIndicator` protocol (equivalent to
/// Dart's `DebugOverflowIndicatorMixin`) which paints yellow-and-black striped
/// indicators at the edges where overflow occurs, along with text labels
/// showing the overflow amount in pixels.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/debug_overflow_indicator.dart`

import FlutterSwiftBridge

// MARK: - _OverflowSide

/// Describes which side a region data overflows on.
///
/// **Dart Source:** `debug_overflow_indicator.dart:18`
private enum _OverflowSide: Int, CaseIterable {
    case left
    case top
    case bottom
    case right
}

// MARK: - _OverflowRegionData

/// Data used by the DebugOverflowIndicator to manage the regions and labels
/// for the indicators.
///
/// **Dart Source:** `debug_overflow_indicator.dart:22-36`
private struct _OverflowRegionData {
    let rect: Rect
    var label: String = ""
    var labelOffset: Offset = Offset.zero
    var rotation: Double = 0.0
    let side: _OverflowSide
}

// MARK: - DebugOverflowIndicator Protocol

/// A protocol for rendering debug overflow indicators when a `RenderObject`
/// overflows its container.
///
/// This is used by some render objects that are containers to show where, and
/// by how much, their children overflow their containers. These indicators are
/// typically only shown in a debug build.
///
/// This protocol will also print a debug message to the console when the
/// container overflows. It will print on the first occurrence, and once after
/// each time that `reassemble` is called.
///
/// Since Swift does not have mixins, this is implemented as a protocol with
/// a default extension. Conforming types must provide storage for the
/// `_overflowReportNeeded` and `_indicatorLabel` properties.
///
/// **Dart Source:** `debug_overflow_indicator.dart:89-342`
public protocol DebugOverflowIndicator: AnyObject {
    /// Whether a report should be generated the next time overflow is detected.
    ///
    /// Conforming types must provide backing storage for this property.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:127`
    var _overflowReportNeeded: Bool { get set }

    /// Cached text painters for the overflow labels, one per side.
    ///
    /// Conforming types must provide backing storage for this property.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:111-115`
    var _indicatorLabel: [TextPainter] { get }
}

// MARK: - DebugOverflowIndicator Default Implementation

extension DebugOverflowIndicator {

    // MARK: - Static Constants

    /// The black color used in the overflow indicator stripe pattern.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:90`
    private static var _black: Color { Color(0xBF000000) }

    /// The yellow color used in the overflow indicator stripe pattern.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:91`
    private static var _yellow: Color { Color(0xBFFFFF00) }

    /// The fraction of the container that the indicator covers.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:93`
    private static var _indicatorFraction: Double { 0.1 }

    /// The font size of the overflow label text, in pixels.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:94`
    private static var _indicatorFontSizePixels: Double { 7.5 }

    /// The padding around the overflow label text, in pixels.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:95`
    private static var _indicatorLabelPaddingPixels: Double { 1.0 }

    /// The text style used for overflow label text.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:96-100`
    private static var _indicatorTextStyle: Flutter.TextStyle {
        Flutter.TextStyle(
            color: Color(0xFF900000),
            fontSize: _indicatorFontSizePixels,
            fontWeight: .w800
        )
    }

    // MARK: - Pixel Formatting

    /// Formats a pixel value for display in the overflow label.
    ///
    /// Values > 10 are shown as integers, values > 1 show one decimal place,
    /// and smaller values show three significant figures.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:129-136`
    private func _formatPixels(_ value: Double) -> String {
        assert(value > 0.0)
        if value > 10.0 {
            return String(format: "%.0f", value)
        } else if value > 1.0 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.3g", value)
        }
    }

    // MARK: - Overflow Region Calculation

    /// Calculates the overflow regions (indicator rectangles and labels) for the
    /// given overflow amounts.
    ///
    /// Each side that has positive overflow gets an indicator region with a
    /// colored rectangle and a text label showing how many pixels overflow.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:138-213`
    private func _calculateOverflowRegions(
        _ overflow: RelativeRect,
        _ containerRect: Rect
    ) -> [_OverflowRegionData] {
        var regions: [_OverflowRegionData] = []

        if overflow.left > 0.0 {
            let markerRect = Rect.fromLTWH(
                0.0,
                0.0,
                containerRect.width * Self._indicatorFraction,
                containerRect.height
            )
            regions.append(
                _OverflowRegionData(
                    rect: markerRect,
                    label: "LEFT OVERFLOWED BY \(_formatPixels(overflow.left)) PIXELS",
                    labelOffset: markerRect.centerLeft
                        + Offset(Self._indicatorFontSizePixels + Self._indicatorLabelPaddingPixels, 0.0),
                    rotation: Double.pi / 2.0,
                    side: .left
                )
            )
        }
        if overflow.right > 0.0 {
            let markerRect = Rect.fromLTWH(
                containerRect.width * (1.0 - Self._indicatorFraction),
                0.0,
                containerRect.width * Self._indicatorFraction,
                containerRect.height
            )
            regions.append(
                _OverflowRegionData(
                    rect: markerRect,
                    label: "RIGHT OVERFLOWED BY \(_formatPixels(overflow.right)) PIXELS",
                    labelOffset: markerRect.centerRight
                        - Offset(Self._indicatorFontSizePixels + Self._indicatorLabelPaddingPixels, 0.0),
                    rotation: -Double.pi / 2.0,
                    side: .right
                )
            )
        }
        if overflow.top > 0.0 {
            let markerRect = Rect.fromLTWH(
                0.0,
                0.0,
                containerRect.width,
                containerRect.height * Self._indicatorFraction
            )
            regions.append(
                _OverflowRegionData(
                    rect: markerRect,
                    label: "TOP OVERFLOWED BY \(_formatPixels(overflow.top)) PIXELS",
                    labelOffset: markerRect.topCenter
                        + Offset(0.0, Self._indicatorLabelPaddingPixels),
                    side: .top
                )
            )
        }
        if overflow.bottom > 0.0 {
            let markerRect = Rect.fromLTWH(
                0.0,
                containerRect.height * (1.0 - Self._indicatorFraction),
                containerRect.width,
                containerRect.height * Self._indicatorFraction
            )
            regions.append(
                _OverflowRegionData(
                    rect: markerRect,
                    label: "BOTTOM OVERFLOWED BY \(_formatPixels(overflow.bottom)) PIXELS",
                    labelOffset: markerRect.bottomCenter
                        - Offset(0.0, Self._indicatorFontSizePixels + Self._indicatorLabelPaddingPixels),
                    side: .bottom
                )
            )
        }
        return regions
    }

    // MARK: - Overflow Reporting

    /// Reports overflow to the console via `FlutterError.reportError`.
    ///
    /// Generates a human-readable error message describing which sides overflowed
    /// and by how much.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:215-277`
    private func _reportOverflow(
        _ overflow: RelativeRect,
        _ overflowHints: [any DiagnosticsNodeProtocol]?
    ) {
        var hints = overflowHints ?? []
        if hints.isEmpty {
            hints.append(
                ErrorDescription(
                    "The edge of the \(type(of: self)) that is "
                    + "overflowing has been marked in the rendering with a yellow and black "
                    + "striped pattern. This is usually caused by the contents being too big "
                    + "for the \(type(of: self))."
                )
            )
            hints.append(
                ErrorHint(
                    "This is considered an error condition because it indicates that there "
                    + "is content that cannot be seen. If the content is legitimately bigger "
                    + "than the available space, consider clipping it with a ClipRect widget "
                    + "before putting it in the \(type(of: self)), or using a scrollable "
                    + "container, like a ListView."
                )
            )
        }

        var overflows: [String] = []
        if overflow.left > 0.0 {
            overflows.append("\(_formatPixels(overflow.left)) pixels on the left")
        }
        if overflow.top > 0.0 {
            overflows.append("\(_formatPixels(overflow.top)) pixels on the top")
        }
        if overflow.bottom > 0.0 {
            overflows.append("\(_formatPixels(overflow.bottom)) pixels on the bottom")
        }
        if overflow.right > 0.0 {
            overflows.append("\(_formatPixels(overflow.right)) pixels on the right")
        }

        var overflowText = ""
        assert(
            !overflows.isEmpty,
            "Somehow \(type(of: self)) didn't actually overflow like it thought it did."
        )
        switch overflows.count {
        case 1:
            overflowText = overflows.first!
        case 2:
            overflowText = "\(overflows.first!) and \(overflows.last!)"
        default:
            overflows[overflows.count - 1] = "and \(overflows[overflows.count - 1])"
            overflowText = overflows.joined(separator: ", ")
        }

        let capturedHints = hints
        FlutterError.reportError(
            FlutterErrorDetails(
                exception: FlutterError("A \(type(of: self)) overflowed by \(overflowText)."),
                library: "rendering library",
                context: ErrorDescription("during layout"),
                informationCollector: {
                    return capturedHints
                }
            )
        )
    }

    // MARK: - Paint Overflow Indicator

    /// Paints overflow indicators if any overflow exists.
    ///
    /// This method calculates the overflow on each side by comparing the
    /// `containerRect` with the `childRect`. If any side overflows, it paints
    /// colored indicator rectangles and text labels at the overflow locations.
    ///
    /// Typically only called if there is an overflow, and only from within a
    /// debug build.
    ///
    /// **Dart Source:** `debug_overflow_indicator.dart:285-331`
    public func paintOverflowIndicator(
        _ context: PaintingContext,
        _ offset: Offset,
        _ containerRect: Rect,
        _ childRect: Rect,
        overflowHints: [any DiagnosticsNodeProtocol]? = nil
    ) {
        let overflow = RelativeRect.fromRect(containerRect, childRect)

        if overflow.left <= 0.0
            && overflow.right <= 0.0
            && overflow.top <= 0.0
            && overflow.bottom <= 0.0
        {
            return
        }

        let overflowRegions = _calculateOverflowRegions(overflow, containerRect)

        for region in overflowRegions {
            // Paint the indicator rectangle
            // TODO: Use gradient shader paint when full Canvas/Paint pipeline is available.
            // In Dart, this uses a linear gradient with black/yellow stripes:
            //   _indicatorPaint with shader = ui.Gradient.linear(...)
            let indicatorPaint = Paint()
            indicatorPaint.color = Self._yellow
            context.canvas.drawRect(region.rect.shift(offset), indicatorPaint)

            // Update the text painter for this side if the label changed
            let sideIndex = region.side.rawValue
            let textSpan = _indicatorLabel[sideIndex].text as? TextSpan
            if textSpan?.text != region.label {
                _indicatorLabel[sideIndex].text = TextSpan(
                    text: region.label,
                    style: Self._indicatorTextStyle
                )
                _indicatorLabel[sideIndex].layout()
            }

            // Paint the label with rotation
            let labelOffset = region.labelOffset + offset
            let centerOffset = Offset(-_indicatorLabel[sideIndex].width / 2.0, 0.0)
            let textBackgroundRect = centerOffset & _indicatorLabel[sideIndex].size

            let labelBackgroundPaint = Paint()
            labelBackgroundPaint.color = Color(0xFFFFFFFF)

            context.canvas.save()
            context.canvas.translate(labelOffset.dx, labelOffset.dy)
            context.canvas.rotate(region.rotation)
            context.canvas.drawRect(textBackgroundRect, labelBackgroundPaint)
            _indicatorLabel[sideIndex].paint(context.canvas, centerOffset)
            context.canvas.restore()
        }

        if _overflowReportNeeded {
            _overflowReportNeeded = false
            _reportOverflow(overflow, overflowHints)
        }
    }
}

// MARK: - Factory for Indicator Labels

/// Creates the default array of `TextPainter` objects for the four overflow sides.
///
/// This is a helper function for conforming types to initialize their
/// `_indicatorLabel` property.
///
/// **Dart Source:** `debug_overflow_indicator.dart:111-115`
public func createOverflowIndicatorLabels() -> [TextPainter] {
    return _OverflowSide.allCases.map { _ in
        TextPainter(textDirection: .ltr)
    }
}
