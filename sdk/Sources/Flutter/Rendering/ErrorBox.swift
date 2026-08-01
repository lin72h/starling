// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A render object used as a placeholder when an error occurs.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/error.dart`

import FlutterSwiftBridge

// MARK: - Private Constants

/// **Dart Source:** `error.dart:14`
private let _kMaxWidth: Double = 100000.0

/// **Dart Source:** `error.dart:15`
private let _kMaxHeight: Double = 100000.0

// MARK: - RenderErrorBox

/// A render object used as a placeholder when an error occurs.
///
/// The box will be painted in the color given by the
/// `RenderErrorBox.backgroundColor` static property.
///
/// A message can be provided. To simplify the class and thus help reduce the
/// likelihood of this class itself being the source of errors, the message
/// cannot be changed once the object has been created. If provided, the text
/// will be painted on top of the background, using the styles given by the
/// `RenderErrorBox.textStyle` and `RenderErrorBox.paragraphStyle` static
/// properties.
///
/// Again to help simplify the class, if the parent has left the constraints
/// unbounded, this box tries to be 100000.0 pixels wide and high, to
/// approximate being infinitely high but without using infinities.
///
/// **Dart Source:** `error.dart:32-177`
open class RenderErrorBox: RenderBox {

    // MARK: - Initializer

    /// Creates a RenderErrorBox render object.
    ///
    /// A message can optionally be provided. If a message is provided, an attempt
    /// will be made to render the message when the box paints.
    ///
    /// **Dart Source:** `error.dart:37-60`
    public init(message: String = "") {
        self.message = message
        self._paragraph = nil
        super.init()

        // This class is intentionally doing things using the low-level
        // primitives to avoid depending on any subsystems that may have ended
        // up in an unstable state -- after all, this class is mainly used when
        // things have gone wrong.
        //
        // Generally, the much better way to draw text in a RenderObject is to
        // use the TextPainter class. If you're looking for code to crib from,
        // see the paragraph.dart file and the RenderParagraph class.
        //
        // The Dart version wraps this in try/catch to swallow errors. In Swift,
        // ParagraphBuilder methods are not throwing, so no do/catch is needed.
        // If this code ever becomes throwing, wrap in do/catch.
        if !message.isEmpty {
            let builder = ParagraphBuilders.create(RenderErrorBox.paragraphStyle)
            builder.pushStyle(RenderErrorBox.textStyle)
            builder.addText(message)
            _paragraph = builder.build()
        }
    }

    // MARK: - Properties

    /// The message to attempt to display at paint time.
    ///
    /// **Dart Source:** `error.dart:63`
    public let message: String

    /// The built paragraph for painting, or nil if the message is empty or
    /// an error occurred during construction.
    ///
    /// **Dart Source:** `error.dart:65`
    private var _paragraph: (any Paragraph)?

    // MARK: - Intrinsic Dimensions

    /// Returns the maximum intrinsic width (_kMaxWidth).
    ///
    /// **Dart Source:** `error.dart:67-70`
    open override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return _kMaxWidth
    }

    /// Returns the maximum intrinsic height (_kMaxHeight).
    ///
    /// **Dart Source:** `error.dart:72-75`
    open override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return _kMaxHeight
    }

    // MARK: - Layout

    /// Whether the constraints are the only input to the sizing algorithm (in
    /// this case, yes).
    ///
    /// **Dart Source:** `error.dart:77-78`
    open override var sizedByParent: Bool { true }

    /// Returns true so that the error box is always hit-testable.
    ///
    /// **Dart Source:** `error.dart:80-81`
    open override func hitTestSelf(_ position: Offset) -> Bool { true }

    /// Computes the dry layout by constraining to the maximum size.
    ///
    /// **Dart Source:** `error.dart:83-87`
    open override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(_kMaxWidth, _kMaxHeight))
    }

    // MARK: - Static Configuration

    /// The distance to place around the text.
    ///
    /// This is intended to ensure that if the `RenderErrorBox` is placed at the top left
    /// of the screen, under the system's status bar, the error text is still visible in
    /// the area below the status bar.
    ///
    /// The padding is ignored if the error box is smaller than the padding.
    ///
    /// See also:
    ///
    ///  * `minimumWidth`, which controls how wide the box must be before the
    ///    horizontal padding is applied.
    ///
    /// **Dart Source:** `error.dart:89-101`
    nonisolated(unsafe) public static var padding: EdgeInsets = EdgeInsets.fromLTRB(
        64.0, 96.0, 64.0, 12.0
    )

    /// The width below which the horizontal padding is not applied.
    ///
    /// If the left and right padding would reduce the available width to less than
    /// this value, then the text is rendered flush with the left edge.
    ///
    /// **Dart Source:** `error.dart:103-107`
    nonisolated(unsafe) public static var minimumWidth: Double = 200.0

    /// The color to use when painting the background of `RenderErrorBox` objects.
    ///
    /// Defaults to red in debug mode, a light gray otherwise.
    ///
    /// **Dart Source:** `error.dart:109-121`
    nonisolated(unsafe) public static var backgroundColor: Color = _initBackgroundColor()

    /// **Dart Source:** `error.dart:114-121`
    private static func _initBackgroundColor() -> Color {
        #if DEBUG
            return Color(0xF0900000)
        #else
            return Color(0xF0C0C0C0)
        #endif
    }

    /// The text style to use when painting `RenderErrorBox` objects.
    ///
    /// Defaults to a yellow monospace font in debug mode, and a dark gray
    /// sans-serif font otherwise.
    ///
    /// **Dart Source:** `error.dart:123-145`
    nonisolated(unsafe) public static var textStyle: FlutterSwiftBridge.TextStyle = _initTextStyle()

    /// **Dart Source:** `error.dart:129-145`
    private static func _initTextStyle() -> FlutterSwiftBridge.TextStyle {
        #if DEBUG
            return FlutterSwiftBridge.TextStyle(
                color: Color(0xFFFFFF66),
                fontWeight: .bold,
                fontFamily: "monospace",
                fontSize: 14.0
            )
        #else
            return FlutterSwiftBridge.TextStyle(
                color: Color(0xFF303030),
                fontFamily: "sans-serif",
                fontSize: 18.0
            )
        #endif
    }

    /// The paragraph style to use when painting `RenderErrorBox` objects.
    ///
    /// **Dart Source:** `error.dart:147-151`
    nonisolated(unsafe) public static var paragraphStyle: ParagraphStyle = ParagraphStyle(
        textAlign: .left,
        textDirection: .ltr
    )

    // MARK: - Painting

    /// Paints the error box with a colored background and the error message text.
    ///
    /// The Dart version wraps the paint body in try/catch to swallow errors.
    /// In Swift, the canvas methods are not throwing, so no do/catch is needed.
    /// If these APIs ever become throwing, this method should be wrapped in do/catch.
    ///
    /// **Dart Source:** `error.dart:153-177`
    open override func paint(_ context: PaintingContext, _ offset: Offset) {
        let bgPaint = Paint()
        bgPaint.color = RenderErrorBox.backgroundColor
        context.canvas.drawRect(offset & size, bgPaint)
        if let paragraph = _paragraph {
            var width = size.width
            var left = 0.0
            var top = 0.0
            if width > RenderErrorBox.padding.left + RenderErrorBox.minimumWidth + RenderErrorBox.padding.right {
                width -= RenderErrorBox.padding.left + RenderErrorBox.padding.right
                left += RenderErrorBox.padding.left
            }
            paragraph.layout(ParagraphConstraints(width: width))
            if size.height > RenderErrorBox.padding.top + paragraph.height + RenderErrorBox.padding.bottom {
                top += RenderErrorBox.padding.top
            }
            context.canvas.drawParagraph(paragraph, offset + Offset(left, top))
        }
    }
}
