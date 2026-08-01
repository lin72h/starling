// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Flutter logo painting types.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/flutter_logo.dart`

import FlutterSwiftBridge

// MARK: - FlutterLogoStyle

/// Possible ways to draw Flutter's logo.
///
/// **Dart Source:** `flutter_logo.dart:25-36`
public enum FlutterLogoStyle: String, Sendable, Hashable, CaseIterable {
    /// Show only Flutter's logo, not the "Flutter" label.
    ///
    /// This is the default behavior for `FlutterLogoDecoration` objects.
    ///
    /// **Dart Source:** `flutter_logo.dart:27-29`
    case markOnly

    /// Show Flutter's logo on the left, and the "Flutter" label to its right.
    ///
    /// **Dart Source:** `flutter_logo.dart:31-32`
    case horizontal

    /// Show Flutter's logo above the "Flutter" label.
    ///
    /// **Dart Source:** `flutter_logo.dart:34-35`
    case stacked
}

// MARK: - FlutterLogoDecoration

/// An immutable description of how to paint Flutter's logo.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/flutter_logo.dart`
/// **Original Name:** `FlutterLogoDecoration`
/// **Lines:** 39-214
public final class FlutterLogoDecoration: Decoration {

    // MARK: - Properties

    /// The color used to paint the "Flutter" text on the logo, if `style` is
    /// `FlutterLogoStyle.horizontal` or `FlutterLogoStyle.stacked`.
    ///
    /// If possible, the default (a medium grey) should be used against a white
    /// background.
    ///
    /// **Dart Source:** `flutter_logo.dart:63-68`
    public let textColor: Color

    /// Whether and where to draw the "Flutter" text. By default, only the logo
    /// itself is drawn.
    ///
    /// **Dart Source:** `flutter_logo.dart:70-74`
    public let style: FlutterLogoStyle

    /// How far to inset the logo from the edge of the container.
    ///
    /// **Dart Source:** `flutter_logo.dart:76-77`
    public let margin: EdgeInsets

    // The following are set when lerping, to represent states that can't be
    // represented by the constructor.
    // **Dart Source:** `flutter_logo.dart:79-82`

    /// -1.0 for stacked, 1.0 for horizontal, 0.0 for no logo
    internal let _position: Double

    /// 0.0 .. 1.0
    internal let _opacity: Double

    // MARK: - Initializers

    /// Creates a decoration that knows how to paint Flutter's logo.
    ///
    /// The `style` controls whether and where to draw the "Flutter" label. If one
    /// is shown, the `textColor` controls the color of the label.
    ///
    /// **Dart Source:** `flutter_logo.dart:44-53`
    public init(
        textColor: Color = Color(0xFF757575),
        style: FlutterLogoStyle = .markOnly,
        margin: EdgeInsets = .zero
    ) {
        self.textColor = textColor
        self.style = style
        self.margin = margin
        switch style {
        case .markOnly:
            self._position = 0.0
        case .horizontal:
            self._position = 1.0
        case .stacked:
            self._position = -1.0
        }
        self._opacity = 1.0
    }

    /// Internal initializer for lerp states that can't be represented by the
    /// public constructor.
    ///
    /// **Dart Source:** `flutter_logo.dart:55-61`
    internal init(
        _ textColor: Color,
        _ style: FlutterLogoStyle,
        _ margin: EdgeInsets,
        _ position: Double,
        _ opacity: Double
    ) {
        self.textColor = textColor
        self.style = style
        self.margin = margin
        self._position = position
        self._opacity = opacity
    }

    // MARK: - Computed Properties

    /// Whether the logo is in an intermediate transition state.
    ///
    /// **Dart Source:** `flutter_logo.dart:84-85`
    internal var _inTransition: Bool {
        _opacity != 1.0 || (_position != -1.0 && _position != 0.0 && _position != 1.0)
    }

    // MARK: - Decoration Protocol

    /// In debug mode, throws an exception if the object is not in a
    /// valid configuration. Otherwise, returns true.
    ///
    /// **Dart Source:** `flutter_logo.dart:87-91`
    public func debugAssertIsValid() -> Bool {
        assert(_position.isFinite && _opacity >= 0.0 && _opacity <= 1.0)
        return true
    }

    /// Whether this decoration is complex enough to benefit from caching its painting.
    ///
    /// **Dart Source:** `flutter_logo.dart:93-94`
    public var isComplex: Bool {
        !_inTransition
    }

    // MARK: - Lerp Methods

    /// Linearly interpolate between two Flutter logo descriptions.
    ///
    /// Interpolates both the color and the style in a continuous fashion.
    ///
    /// If both values are nil, this returns nil. Otherwise, it returns a
    /// non-nil value. If one of the values is nil, then the result is obtained
    /// by scaling the other value's opacity and `margin`.
    ///
    /// **Dart Source:** `flutter_logo.dart:109-146`
    public static func lerp(
        _ a: FlutterLogoDecoration?,
        _ b: FlutterLogoDecoration?,
        _ t: Double
    ) -> FlutterLogoDecoration? {
        assert(a == nil || a!.debugAssertIsValid())
        assert(b == nil || b!.debugAssertIsValid())
        if a === b {
            return a
        }
        if a == nil {
            return FlutterLogoDecoration(
                b!.textColor,
                b!.style,
                b!.margin * t,
                b!._position,
                b!._opacity * clampDouble(t, 0.0, 1.0)
            )
        }
        if b == nil {
            return FlutterLogoDecoration(
                a!.textColor,
                a!.style,
                a!.margin * t,
                a!._position,
                a!._opacity * clampDouble(1.0 - t, 0.0, 1.0)
            )
        }
        if t == 0.0 {
            return a
        }
        if t == 1.0 {
            return b
        }
        return FlutterLogoDecoration(
            Color.lerp(a!.textColor, b!.textColor, t)!,
            t < 0.5 ? a!.style : b!.style,
            EdgeInsets.lerp(a!.margin, b!.margin, t)!,
            a!._position + (b!._position - a!._position) * t,
            clampDouble(a!._opacity + (b!._opacity - a!._opacity) * t, 0.0, 1.0)
        )
    }

    /// Linearly interpolates from another `Decoration` to `this`.
    ///
    /// **Dart Source:** `flutter_logo.dart:148-156`
    public func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)? {
        assert(debugAssertIsValid())
        if a == nil || a is FlutterLogoDecoration {
            let aLogo = a as? FlutterLogoDecoration
            assert(aLogo?.debugAssertIsValid() ?? true)
            return FlutterLogoDecoration.lerp(aLogo, self, t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `Decoration`.
    ///
    /// **Dart Source:** `flutter_logo.dart:158-166`
    public func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)? {
        assert(debugAssertIsValid())
        if b == nil || b is FlutterLogoDecoration {
            let bLogo = b as? FlutterLogoDecoration
            assert(bLogo?.debugAssertIsValid() ?? true)
            return FlutterLogoDecoration.lerp(self, bLogo, t)
        }
        return nil
    }

    // MARK: - Hit Testing

    /// Tests whether the given point, on a rectangle of a given size,
    /// would be considered to hit the decoration or not.
    ///
    /// **Dart Source:** `flutter_logo.dart:168-170`
    public func hitTest(_ size: Size, _ position: Offset, textDirection: TextDirection? = nil) -> Bool {
        true
    }

    // MARK: - BoxPainter Creation

    /// Returns a `BoxPainter` that will paint this decoration.
    ///
    /// **Dart Source:** `flutter_logo.dart:172-176`
    public func createBoxPainter(_ onChanged: VoidCallback? = nil) -> BoxPainter {
        assert(debugAssertIsValid())
        return FlutterLogoPainter(self)
    }

    // MARK: - Clip Path

    /// Returns a closed `Path` that describes the outer edge of this decoration.
    ///
    /// **Dart Source:** `flutter_logo.dart:178-181`
    public func getClipPath(_ rect: Rect, _ textDirection: TextDirection) -> Path {
        let path = Path()
        path.addRect(rect)
        return path
    }

    // MARK: - Equatable

    /// Compares two `FlutterLogoDecoration` instances for equality.
    ///
    /// **Dart Source:** `flutter_logo.dart:183-193`
    public static func == (lhs: FlutterLogoDecoration, rhs: FlutterLogoDecoration) -> Bool {
        if lhs === rhs { return true }
        return lhs.textColor == rhs.textColor &&
               lhs._position == rhs._position &&
               lhs._opacity == rhs._opacity
    }

    // MARK: - Hashable

    /// The hash code for this decoration.
    ///
    /// **Dart Source:** `flutter_logo.dart:195-199`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(textColor)
        hasher.combine(_position)
        hasher.combine(_opacity)
    }

    // MARK: - Diagnosticable

    /// A brief description of this object.
    ///
    /// **Dart Source:** `flutter_logo.dart:39` (via Decoration)
    public func toStringShort() -> String {
        objectRuntimeType(self, "FlutterLogoDecoration")
    }

    /// Add additional properties associated with the node.
    ///
    /// **Dart Source:** `flutter_logo.dart:201-213`
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(ColorProperty("textColor", textColor))
        properties.add(EnumProperty<FlutterLogoStyle>("style", style))
        if _inTransition {
            properties.add(
                DiagnosticsNode.message(
                    "transition \(debugFormatDouble(_position)):\(debugFormatDouble(_opacity))"
                )
            )
        }
    }

    /// Returns a `DiagnosticsNode` representation of this object.
    public func toDiagnosticsNode(name: String? = nil, style: DiagnosticsTreeStyle? = nil) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style)
    }
}

// MARK: - Equatable Conformance

extension FlutterLogoDecoration: Equatable {}

// MARK: - Hashable Conformance

extension FlutterLogoDecoration: Hashable {}

// MARK: - FlutterLogoPainter

/// An object that paints a `FlutterLogoDecoration` into a canvas.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/flutter_logo.dart`
/// **Original Name:** `_FlutterLogoPainter`
/// **Lines:** 217-463
internal class FlutterLogoPainter: BoxPainter {

    /// The decoration configuration.
    ///
    /// **Dart Source:** `flutter_logo.dart:222`
    private let _config: FlutterLogoDecoration

    // These are configured assuming a font size of 100.0.
    //
    // **Dart Source:** `flutter_logo.dart:224-226`
    // Note: TextPainter is not yet migrated, so we use placeholder values
    // for text bounding rect calculations.

    /// Text bounding rect for "Flutter" at font size 100.
    /// Calculated from the Dart source where TextPainter lays out
    /// "Flutter" text with fontSize = 100 * 350 / 247.
    ///
    /// **Dart Source:** `flutter_logo.dart:234-257`
    private var _textBoundingRect: Rect = .zero

    /// Creates a `FlutterLogoPainter` for the given config.
    ///
    /// **Dart Source:** `flutter_logo.dart:218-220`
    init(_ config: FlutterLogoDecoration) {
        assert(config.debugAssertIsValid())
        self._config = config
        super.init(onChanged: nil)
        _prepareText()
    }

    /// Disposes of text painting resources.
    ///
    /// **Dart Source:** `flutter_logo.dart:228-232`
    override func dispose() {
        // TextPainter disposal will be added when TextPainter is migrated
        super.dispose()
    }

    /// Prepares the text painter for rendering the "Flutter" label.
    ///
    /// **Dart Source:** `flutter_logo.dart:234-257`
    private func _prepareText() {
        // TextPainter is not yet migrated. When it is migrated, this method
        // will create a TextPainter with:
        //   text: TextSpan(text: "Flutter", style: TextStyle(
        //     color: _config.textColor,
        //     fontFamily: "Roboto",
        //     fontSize: 100.0 * 350.0 / 247.0,
        //     fontWeight: FontWeight.w300,
        //     textBaseline: TextBaseline.alphabetic,
        //   ))
        //   textDirection: TextDirection.ltr
        //
        // For now, use approximate bounding rect values derived from the Dart
        // layout at font size 100 * 350 / 247 ~= 141.7.
        // These are approximate values based on the Dart TextPainter layout.
        _textBoundingRect = Rect.fromLTRB(0.0, 0.0, 420.0, 141.7)
    }

    // This class contains a lot of magic numbers. They were derived from the
    // values in the SVG files exported from the original artwork source.
    //
    // **Dart Source:** `flutter_logo.dart:259-261`

    /// Paints the Flutter logo shape on the canvas.
    ///
    /// **Dart Source:** `flutter_logo.dart:262-331`
    private func _paintLogo(_ canvas: Canvas, _ rect: Rect) {
        // Our points are in a coordinate space that's 166 pixels wide and 202 pixels high.
        // First, transform the rectangle so that our coordinate space is a square 202 pixels
        // to a side, with the top left at the origin.
        canvas.save()
        canvas.translate(rect.left, rect.top)
        canvas.scale(rect.width / 202.0, rect.height / 202.0)
        // Next, offset it some more so that the 166 horizontal pixels are centered
        // in that square (as opposed to being on the left side of it). This means
        // that if we draw in the rectangle from 0,0 to 166,202, we are drawing in
        // the center of the given rect.
        canvas.translate((202.0 - 166.0) / 2.0, 0.0)

        // Set up the styles.
        let lightPaint = Paint()
        lightPaint.color = Color(0xFF54C5F8)
        let mediumPaint = Paint()
        mediumPaint.color = Color(0xFF29B6F6)
        let darkPaint = Paint()
        darkPaint.color = Color(0xFF01579B)

        let triangleGradient = Gradient(
            linear: Offset(87.2623 + 37.9092, 28.8384 + 123.4389),
            to: Offset(42.9205 + 37.9092, 35.0952 + 123.4389),
            colors: [Color(0x001A237E), Color(0x661A237E)]
        )
        let trianglePaint = Paint()
        trianglePaint.shader = triangleGradient

        // Draw the basic shape.
        // **Dart Source:** `flutter_logo.dart:288-293`
        let topBeam = Path()
        topBeam.moveTo(37.7, 128.9)
        topBeam.lineTo(9.8, 101.0)
        topBeam.lineTo(100.4, 10.4)
        topBeam.lineTo(156.2, 10.4)
        canvas.drawPath(topBeam, lightPaint)

        // **Dart Source:** `flutter_logo.dart:295-300`
        let middleBeam = Path()
        middleBeam.moveTo(156.2, 94.0)
        middleBeam.lineTo(100.4, 94.0)
        middleBeam.lineTo(78.5, 115.9)
        middleBeam.lineTo(106.4, 143.8)
        canvas.drawPath(middleBeam, lightPaint)

        // **Dart Source:** `flutter_logo.dart:302-307`
        let bottomBeam = Path()
        bottomBeam.moveTo(79.5, 170.7)
        bottomBeam.lineTo(100.4, 191.6)
        bottomBeam.lineTo(156.2, 191.6)
        bottomBeam.lineTo(107.4, 142.8)
        canvas.drawPath(bottomBeam, darkPaint)

        // The overlap between middle and bottom beam.
        // **Dart Source:** `flutter_logo.dart:309-321`
        canvas.save()
        canvas.transform([
            // careful, this is in _column_-major order
            0.7071, -0.7071, 0.0, 0.0,
            0.7071, 0.7071, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            -77.697, 98.057, 0.0, 1.0,
        ])
        canvas.drawRect(Rect.fromLTWH(59.8, 123.1, 39.4, 39.4), mediumPaint)
        canvas.restore()

        // The gradients below the middle beam on top of the bottom beam.
        // **Dart Source:** `flutter_logo.dart:324-328`
        let triangle = Path()
        triangle.moveTo(79.5, 170.7)
        triangle.lineTo(120.9, 156.4)
        triangle.lineTo(107.4, 142.8)
        canvas.drawPath(triangle, trianglePaint)

        canvas.restore()
    }

    /// Paints the Flutter logo and optional text label.
    ///
    /// **Dart Source:** `flutter_logo.dart:333-462`
    override func paint(_ canvas: Canvas, _ offset: Offset, _ configuration: ImageConfiguration) {
        var offset = offset
        offset = Offset(
            offset.dx + _config.margin.topLeft.dx,
            offset.dy + _config.margin.topLeft.dy
        )
        let canvasSize = _config.margin.deflateSize(configuration.size!)
        if canvasSize.isEmpty {
            return
        }
        // **Dart Source:** `flutter_logo.dart:340-344`
        let logoSize: Size
        if _config._position > 0.0 {
            logoSize = Size(820.0, 232.0)  // horizontal style
        } else if _config._position < 0.0 {
            logoSize = Size(252.0, 306.0)  // stacked style
        } else {
            logoSize = Size(202.0, 202.0)  // only the mark
        }
        let fittedSize = applyBoxFit(.contain, logoSize, canvasSize)
        assert(fittedSize.source == logoSize)
        let rect = Alignment.center.inscribe(fittedSize.destination, offset & canvasSize)
        let centerSquareHeight = canvasSize.shortestSide
        let centerSquare = Rect.fromLTWH(
            offset.dx + (canvasSize.width - centerSquareHeight) / 2.0,
            offset.dy + (canvasSize.height - centerSquareHeight) / 2.0,
            centerSquareHeight,
            centerSquareHeight
        )

        // **Dart Source:** `flutter_logo.dart:356-372`
        let logoTargetSquare: Rect
        if _config._position > 0.0 {
            // horizontal style
            logoTargetSquare = Rect.fromLTWH(rect.left, rect.top, rect.height, rect.height)
        } else if _config._position < 0.0 {
            // stacked style
            let logoHeight = rect.height * 191.0 / 306.0
            logoTargetSquare = Rect.fromLTWH(
                rect.left + (rect.width - logoHeight) / 2.0,
                rect.top,
                logoHeight,
                logoHeight
            )
        } else {
            // only the mark
            logoTargetSquare = centerSquare
        }
        let logoSquare = Rect.lerp(centerSquare, logoTargetSquare, Swift.abs(_config._position))!

        // **Dart Source:** `flutter_logo.dart:375-384`
        if _config._opacity < 1.0 {
            let layerPaint = Paint()
            layerPaint.colorFilter = ColorFilter(
                mode: Color(0xFFFFFFFF).withOpacity(_config._opacity),
                .modulate
            )
            canvas.saveLayer(offset & canvasSize, layerPaint)
        }

        // **Dart Source:** `flutter_logo.dart:385-456`
        if _config._position != 0.0 {
            if _config._position > 0.0 {
                // horizontal style
                // **Dart Source:** `flutter_logo.dart:387-415`
                let fontSize = 2.0 / 3.0 * logoSquare.height * (1 - (10.4 * 2.0) / 202.0)
                let scale = fontSize / 100.0
                let finalLeftTextPosition =
                    (256.4 / 820.0) * rect.width -
                    (32.0 / 350.0) * fontSize
                let initialLeftTextPosition =
                    rect.width / 2.0 - _textBoundingRect.width * scale
                let textOffset = Offset(
                    rect.left +
                        lerpDouble(initialLeftTextPosition, finalLeftTextPosition, _config._position)!,
                    rect.top + (rect.height - _textBoundingRect.height * scale) / 2.0
                )
                canvas.save()
                if _config._position < 1.0 {
                    let center = logoSquare.center
                    let clipPath = Path()
                    clipPath.moveTo(center.dx, center.dy)
                    clipPath.lineTo(center.dx + rect.width, center.dy - rect.width)
                    clipPath.lineTo(center.dx + rect.width, center.dy + rect.width)
                    clipPath.close()
                    canvas.clipPath(clipPath, doAntiAlias: true)
                }
                canvas.translate(textOffset.dx, textOffset.dy)
                canvas.scale(scale, scale)
                // _textPainter.paint(canvas, Offset.zero) - requires TextPainter migration
                canvas.restore()
            } else if _config._position < 0.0 {
                // stacked style
                // **Dart Source:** `flutter_logo.dart:416-456`
                let fontSize = 0.35 * logoTargetSquare.height * (1 - (10.4 * 2.0) / 202.0)
                let scale = fontSize / 100.0
                if _config._position > -1.0 {
                    canvas.saveLayer(_textBoundingRect, Paint())
                } else {
                    canvas.save()
                }
                canvas.translate(
                    logoTargetSquare.center.dx - (_textBoundingRect.width * scale / 2.0),
                    logoTargetSquare.bottom
                )
                canvas.scale(scale, scale)
                // _textPainter.paint(canvas, Offset.zero) - requires TextPainter migration
                if _config._position > -1.0 {
                    canvas.drawRect(
                        _textBoundingRect.inflate(_textBoundingRect.width * 0.5),
                        {
                            let paint = Paint()
                            paint.blendMode = .modulate
                            paint.shader = Gradient(
                                linear: Offset(_textBoundingRect.width * -0.5, 0.0),
                                to: Offset(_textBoundingRect.width * 1.5, 0.0),
                                colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFFFFFFF),
                                    Color(0x00FFFFFF),
                                    Color(0x00FFFFFF),
                                ],
                                colorStops: [
                                    0.0,
                                    max(0.0, Swift.abs(_config._position) - 0.1),
                                    min(Swift.abs(_config._position) + 0.1, 1.0),
                                    1.0,
                                ]
                            )
                            return paint
                        }()
                    )
                }
                canvas.restore()
            }
        }
        _paintLogo(canvas, logoSquare)
        if _config._opacity < 1.0 {
            canvas.restore()
        }
    }
}
