// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Ported from: fluent_ui/lib/src/controls/inputs/rating.dart
// and fluent_ui/lib/src/controls/utils/custom_icons.dart (RatingIcon)

import FlutterSwiftBridge

// MARK: - RatingBar

/// A control for viewing and setting star ratings.
///
/// The RatingBar allows users to rate content with a configurable number
/// of stars. Users can interact with tap and drag.
public class RatingBar: StatefulWidget {
    /// The current rating. Must be >= 0 and <= amount.
    public let rating: Double

    /// Called when the rating is changed.
    /// If nil, the RatingBar will not detect touch inputs.
    public let onChanged: ((Double) -> Void)?

    /// The number of stars in the bar. Defaults to 5.
    public let amount: Int

    /// The size of each star icon. Defaults to 20.
    public let iconSize: Double

    /// The space between each star. Defaults to 0.
    public let starSpacing: Double

    /// The color of rated (filled) stars. If nil, uses the accent color.
    public let ratedIconColor: Color?

    /// The color of unrated (empty) stars. If nil, uses a default control color.
    public let unratedIconColor: Color?

    public init(
        key: (any Key)? = nil,
        rating: Double,
        onChanged: ((Double) -> Void)? = nil,
        amount: Int = 5,
        iconSize: Double = 20.0,
        starSpacing: Double = 0,
        ratedIconColor: Color? = nil,
        unratedIconColor: Color? = nil
    ) {
        self.rating = rating
        self.onChanged = onChanged
        self.amount = amount
        self.iconSize = iconSize
        self.starSpacing = starSpacing
        self.ratedIconColor = ratedIconColor
        self.unratedIconColor = unratedIconColor
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _RatingBarState()
    }
}

// MARK: - _RatingBarState

class _RatingBarState: State<StatefulWidget> {
    private var ratingBar: RatingBar {
        return widget as! RatingBar
    }

    private func _handleUpdate(_ x: Double) {
        let iSize = ratingBar.iconSize
        let value = (x / iSize) - (ratingBar.starSpacing / Double(ratingBar.amount))
        if value >= 0 && value <= Double(ratingBar.amount) {
            ratingBar.onChanged?(value)
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        let ratedColor = ratingBar.ratedIconColor
            ?? theme.accentColor.defaultBrushFor(theme.brightness)
        let unratedColor = ratingBar.unratedIconColor
            ?? theme.resources.controlFillColorSecondary

        // Build star row using CustomPaint for each star
        var starWidgets: [Widget] = []
        var remaining = ratingBar.rating

        for i in 0..<ratingBar.amount {
            var starFraction = remaining
            remaining -= 1.0
            if starFraction > 1.0 {
                starFraction = 1.0
            } else if starFraction < 0.0 {
                starFraction = 0.0
            }

            let starWidget: Widget = _RatingStarWidget(
                fraction: starFraction,
                ratedColor: ratedColor,
                unratedColor: unratedColor,
                size: ratingBar.iconSize
            )

            if i < ratingBar.amount - 1 && ratingBar.starSpacing > 0 {
                starWidgets.append(
                    Padding(
                        padding: EdgeInsets(left: 0, top: 0, right: ratingBar.starSpacing, bottom: 0),
                        child: starWidget
                    )
                )
            } else {
                starWidgets.append(starWidget)
            }
        }

        let row: Widget = Row(
            mainAxisSize: .min,
            children: starWidgets
        )

        // If interactive, wrap in Listener for tap/drag
        if ratingBar.onChanged != nil {
            return Listener(
                onPointerDown: { [self] event in
                    _handleUpdate(event.localPosition.dx)
                },
                onPointerMove: { [self] event in
                    _handleUpdate(event.localPosition.dx)
                },
                behavior: .opaque,
                child: row
            )
        }

        return row
    }
}

// MARK: - _RatingStarWidget

/// Renders a single star using CustomPaint, supporting partial fill.
private class _RatingStarWidget: StatelessWidget {
    let fraction: Double
    let ratedColor: Color
    let unratedColor: Color
    let size: Double

    init(
        key: (any Key)? = nil,
        fraction: Double,
        ratedColor: Color,
        unratedColor: Color,
        size: Double
    ) {
        self.fraction = fraction
        self.ratedColor = ratedColor
        self.unratedColor = unratedColor
        self.size = size
        super.init(key: key)
    }

    override func build(_ context: any BuildContext) -> Widget {
        return CustomPaint(
            painter: _StarPainter(
                fraction: fraction,
                ratedColor: ratedColor,
                unratedColor: unratedColor
            ),
            size: Size(size, size),
            child: SizedBox(width: size, height: size)
        )
    }
}

// MARK: - _StarPainter

/// Draws a 5-pointed star with partial fill support.
/// The left portion (fraction of width) is filled with ratedColor,
/// the rest with unratedColor.
private class _StarPainter: CustomPainter {
    let fraction: Double
    let ratedColor: Color
    let unratedColor: Color

    init(fraction: Double, ratedColor: Color, unratedColor: Color) {
        self.fraction = fraction
        self.ratedColor = ratedColor
        self.unratedColor = unratedColor
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let centerX = size.width / 2.0
        let centerY = size.height / 2.0
        let outerRadius = Swift.min(size.width, size.height) / 2.0
        let innerRadius = outerRadius * 0.38

        // Draw the unrated (background) star
        let unratedPaint = Paint()
        unratedPaint.color = unratedColor
        unratedPaint.style = .fill
        _drawStar(canvas, centerX: centerX, centerY: centerY,
                  outerRadius: outerRadius, innerRadius: innerRadius,
                  paint: unratedPaint)

        // Draw the rated (foreground) star clipped to fraction
        if fraction > 0 {
            let ratedPaint = Paint()
            ratedPaint.color = ratedColor
            ratedPaint.style = .fill

            canvas.save()
            canvas.clipRect(Rect.fromLTWH(0, 0, size.width * fraction, size.height))
            _drawStar(canvas, centerX: centerX, centerY: centerY,
                      outerRadius: outerRadius, innerRadius: innerRadius,
                      paint: ratedPaint)
            canvas.restore()
        }
    }

    /// Draws a 5-pointed star centered at (centerX, centerY).
    private func _drawStar(_ canvas: any Canvas, centerX: Double, centerY: Double,
                           outerRadius: Double, innerRadius: Double, paint: Paint) {
        // 5-pointed star: 10 points alternating outer/inner
        // Start from the top point (-pi/2 rotation)
        let pi = Double.pi
        let path = Path()
        for i in 0..<10 {
            let angle = -pi / 2.0 + (Double(i) * pi / 5.0)
            let radius = (i % 2 == 0) ? outerRadius : innerRadius
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            if i == 0 {
                path.moveTo(x, y)
            } else {
                path.lineTo(x, y)
            }
        }
        path.close()
        canvas.drawPath(path, paint)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _StarPainter else { return true }
        return fraction != old.fraction
            || ratedColor != old.ratedColor
            || unratedColor != old.unratedColor
    }
}
