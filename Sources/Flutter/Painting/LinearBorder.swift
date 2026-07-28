// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An OutlinedBorder that draws a rectangular box border defined by zero to four
/// LinearBorderEdge edges.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/linear_border.dart`

import FlutterSwiftBridge

// MARK: - LinearBorderEdge

/// Defines the relative size and alignment of one `LinearBorder` edge.
///
/// A `LinearBorder` defines a box outline as zero to four edges, each
/// of which is rendered as a single line. The width and color of the
/// lines is defined by `LinearBorder.side`.
///
/// Each line's length is defined by `size`, a value between 0.0 and 1.0
/// (the default) which defines the length as a percentage of the
/// length of a box edge.
///
/// When `size` is less than 1.0, the line is aligned within the
/// available space according to `alignment`, a value between -1.0 and
/// 1.0. The default is 0.0, which means centered, -1.0 means align on the
/// "start" side, and 1.0 means align on the "end" side.
///
/// **Dart Source:** `linear_border.dart:32-103`
public struct LinearBorderEdge: Hashable, Sendable, CustomStringConvertible {

    // MARK: - Properties

    /// A value between 0.0 and 1.0 that defines the length of the edge as a
    /// percentage of the length of the corresponding box edge. Default is 1.0.
    ///
    /// **Dart Source:** `linear_border.dart:44`
    public let size: Double

    /// A value between -1.0 and 1.0 that defines how edges for which `size`
    /// is less than 1.0 are aligned relative to the corresponding box edge.
    ///
    /// * -1.0, aligned in the "start" direction.
    /// * 0.0, centered.
    /// * 1.0, aligned in the "end" direction.
    ///
    /// **Dart Source:** `linear_border.dart:54`
    public let alignment: Double

    // MARK: - Initializer

    /// Defines one side of a `LinearBorder`.
    ///
    /// The values of `size` and `alignment` must be between
    /// 0.0 and 1.0, and -1.0 and 1.0 respectively.
    ///
    /// **Dart Source:** `linear_border.dart:38-39`
    public init(size: Double = 1.0, alignment: Double = 0.0) {
        assert(size >= 0.0 && size <= 1.0, "size must be between 0.0 and 1.0")
        self.size = size
        self.alignment = alignment
    }

    // MARK: - Static Methods

    /// Linearly interpolates between two `LinearBorderEdge`s.
    ///
    /// If both `a` and `b` are nil then nil is returned. If `a` is nil
    /// then we interpolate to `b` varying `size` from 0.0 to `b.size`. If `b`
    /// is nil then we interpolate from `a` varying size from `a.size` to zero.
    /// Otherwise both values are interpolated.
    ///
    /// **Dart Source:** `linear_border.dart:62-74`
    public static func lerp(_ a: LinearBorderEdge?, _ b: LinearBorderEdge?, _ t: Double) -> LinearBorderEdge? {
        if a == b {
            return a
        }

        let resolvedA = a ?? LinearBorderEdge(size: 0, alignment: b!.alignment)
        let resolvedB = b ?? LinearBorderEdge(size: 0, alignment: resolvedA.alignment)

        return LinearBorderEdge(
            size: lerpDouble(resolvedA.size, resolvedB.size, t)!,
            alignment: lerpDouble(resolvedA.alignment, resolvedB.alignment, t)!
        )
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `linear_border.dart:91-102`
    public var description: String {
        var s = "\(objectRuntimeType(self, "LinearBorderEdge"))("
        if size != 1.0 {
            s += "size: \(size)"
        }
        if alignment != 0 {
            let comma = size != 1.0 ? ", " : ""
            s += "\(comma)alignment: \(alignment)"
        }
        s += ")"
        return s
    }
}

// MARK: - LinearBorder

/// An `OutlinedBorder` like `BoxBorder` that allows one to define a rectangular
/// (box) border in terms of zero to four `LinearBorderEdge`s, each of which is
/// rendered as a single line.
///
/// The color and width of each line are defined by `side`.
///
/// This type resolves itself against the current `TextDirection`.
/// Start and end values resolve to left and right for `TextDirection.ltr` and to
/// right and left for `TextDirection.rtl`.
///
/// Convenience factory methods are included for the common case where just one
/// edge is specified: `LinearBorder.start()`, `LinearBorder.end()`,
/// `LinearBorder.top()`, `LinearBorder.bottom()`.
///
/// **Dart Source:** `linear_border.dart:140-381`
public struct LinearBorder: OutlinedBorder, Hashable, Sendable, CustomStringConvertible {

    // MARK: - Properties

    /// The border outline's color and weight.
    ///
    /// **Dart Source:** `linear_border.dart:142` - inherited from OutlinedBorder
    public let side: BorderSide

    /// Defines the left edge for `TextDirection.ltr` or the right
    /// for `TextDirection.rtl`.
    ///
    /// **Dart Source:** `linear_border.dart:179`
    public let start: LinearBorderEdge?

    /// Defines the right edge for `TextDirection.ltr` or the left
    /// for `TextDirection.rtl`.
    ///
    /// **Dart Source:** `linear_border.dart:183`
    public let end: LinearBorderEdge?

    /// Defines the top edge.
    ///
    /// **Dart Source:** `linear_border.dart:186`
    public let top: LinearBorderEdge?

    /// Defines the bottom edge.
    ///
    /// **Dart Source:** `linear_border.dart:189`
    public let bottom: LinearBorderEdge?

    // MARK: - Static Constants

    /// No border.
    ///
    /// **Dart Source:** `linear_border.dart:175`
    public static let none = LinearBorder()

    // MARK: - Initializer

    /// Creates a rectangular box border that's rendered as zero to four lines.
    ///
    /// **Dart Source:** `linear_border.dart:142`
    public init(
        side: BorderSide = .none,
        start: LinearBorderEdge? = nil,
        end: LinearBorderEdge? = nil,
        top: LinearBorderEdge? = nil,
        bottom: LinearBorderEdge? = nil
    ) {
        self.side = side
        self.start = start
        self.end = end
        self.top = top
        self.bottom = bottom
    }

    // MARK: - Static Factory Methods

    /// Creates a rectangular box border with an edge on the left for
    /// `TextDirection.ltr` or on the right for `TextDirection.rtl`.
    ///
    /// **Dart Source:** `linear_border.dart:146-150`
    public static func start(
        side: BorderSide = .none,
        alignment: Double = 0.0,
        size: Double = 1.0
    ) -> LinearBorder {
        LinearBorder(
            side: side,
            start: LinearBorderEdge(size: size, alignment: alignment)
        )
    }

    /// Creates a rectangular box border with an edge on the right for
    /// `TextDirection.ltr` or on the left for `TextDirection.rtl`.
    ///
    /// **Dart Source:** `linear_border.dart:154-158`
    public static func end(
        side: BorderSide = .none,
        alignment: Double = 0.0,
        size: Double = 1.0
    ) -> LinearBorder {
        LinearBorder(
            side: side,
            end: LinearBorderEdge(size: size, alignment: alignment)
        )
    }

    /// Creates a rectangular box border with an edge on the top.
    ///
    /// **Dart Source:** `linear_border.dart:161-165`
    public static func top(
        side: BorderSide = .none,
        alignment: Double = 0.0,
        size: Double = 1.0
    ) -> LinearBorder {
        LinearBorder(
            side: side,
            top: LinearBorderEdge(size: size, alignment: alignment)
        )
    }

    /// Creates a rectangular box border with an edge on the bottom.
    ///
    /// **Dart Source:** `linear_border.dart:168-172`
    public static func bottom(
        side: BorderSide = .none,
        alignment: Double = 0.0,
        size: Double = 1.0
    ) -> LinearBorder {
        LinearBorder(
            side: side,
            bottom: LinearBorderEdge(size: size, alignment: alignment)
        )
    }

    // MARK: - OutlinedBorder Protocol

    /// Returns a copy of this OutlinedBorder that draws its outline with the
    /// specified `side`, if `side` is non-nil.
    ///
    /// **Dart Source:** `linear_border.dart:238-252`
    public func copyWith(side: BorderSide?) -> any OutlinedBorder {
        LinearBorder(
            side: side ?? self.side,
            start: start,
            end: end,
            top: top,
            bottom: bottom
        )
    }

    /// Returns a copy of this LinearBorder with the given fields replaced with
    /// the new values.
    ///
    /// **Dart Source:** `linear_border.dart:238-252`
    public func copyWith(
        side: BorderSide? = nil,
        start: LinearBorderEdge? = nil,
        end: LinearBorderEdge? = nil,
        top: LinearBorderEdge? = nil,
        bottom: LinearBorderEdge? = nil
    ) -> LinearBorder {
        LinearBorder(
            side: side ?? self.side,
            start: start ?? self.start,
            end: end ?? self.end,
            top: top ?? self.top,
            bottom: bottom ?? self.bottom
        )
    }

    // MARK: - ShapeBorder Protocol

    /// Creates a copy of this border, scaled by the factor `t`.
    ///
    /// **Dart Source:** `linear_border.dart:192-194`
    public func scale(_ t: Double) -> any ShapeBorder {
        LinearBorder(side: side.scale(t))
    }

    /// The widths of the sides of this border represented as an `EdgeInsetsGeometry`.
    ///
    /// **Dart Source:** `linear_border.dart:197-205`
    public var dimensions: any EdgeInsetsGeometry {
        let width = side.width
        return EdgeInsetsDirectional.fromSTEB(
            start == nil ? 0.0 : width,
            top == nil ? 0.0 : width,
            end == nil ? 0.0 : width,
            bottom == nil ? 0.0 : width
        )
    }

    /// Linearly interpolates from another `ShapeBorder` (possibly of another
    /// class) to `this`.
    ///
    /// **Dart Source:** `linear_border.dart:208-219`
    public func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let a = a as? LinearBorder {
            return LinearBorder(
                side: BorderSide.lerp(a.side, side, t),
                start: LinearBorderEdge.lerp(a.start, start, t),
                end: LinearBorderEdge.lerp(a.end, end, t),
                top: LinearBorderEdge.lerp(a.top, top, t),
                bottom: LinearBorderEdge.lerp(a.bottom, bottom, t)
            )
        }
        // Default implementation
        if a == nil {
            return scale(t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `ShapeBorder` (possibly of
    /// another class).
    ///
    /// **Dart Source:** `linear_border.dart:222-233`
    public func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        if let b = b as? LinearBorder {
            return LinearBorder(
                side: BorderSide.lerp(side, b.side, t),
                start: LinearBorderEdge.lerp(start, b.start, t),
                end: LinearBorderEdge.lerp(end, b.end, t),
                top: LinearBorderEdge.lerp(top, b.top, t),
                bottom: LinearBorderEdge.lerp(bottom, b.bottom, t)
            )
        }
        // Default implementation
        if b == nil {
            return scale(1.0 - t)
        }
        return nil
    }

    // MARK: - Path Methods

    /// Create a `Path` that describes the inner edge of the border.
    ///
    /// **Dart Source:** `linear_border.dart:255-258`
    public func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let adjustedRect = dimensions.resolve(textDirection).deflateRect(rect)
        let path = Path()
        path.addRect(adjustedRect)
        return path
    }

    /// Create a `Path` that describes the outer edge of the border.
    ///
    /// **Dart Source:** `linear_border.dart:261-263`
    public func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRect(rect)
        return path
    }

    // MARK: - Painting

    /// Paint a canvas with the appropriate shape.
    ///
    /// **Dart Source:** `borders.dart:608-617`
    public func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {
        // Default implementation - not optimized for this shape
    }

    /// Reports whether `paintInterior` is implemented.
    ///
    /// **Dart Source:** `borders.dart:619-638`
    public var preferPaintInterior: Bool { false }

    /// Paints the border within the given `Rect` on the given `Canvas`.
    ///
    /// **Dart Source:** `linear_border.dart:266-337`
    public func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        let insets = dimensions.resolve(textDirection)
        let rtl = textDirection == TextDirection.rtl

        let path = Path()
        let paint = Paint()
        paint.strokeWidth = 0.0

        /// **Dart Source:** `linear_border.dart:273-290`
        func drawEdge(_ rect: Rect, _ color: Color) {
            paint.color = color
            path.reset()
            path.moveTo(rect.left, rect.top)
            if rect.width == 0.0 {
                paint.style = .stroke
                path.lineTo(rect.left, rect.bottom)
            } else if rect.height == 0.0 {
                paint.style = .stroke
                path.lineTo(rect.right, rect.top)
            } else {
                paint.style = .fill
                path.lineTo(rect.right, rect.top)
                path.lineTo(rect.right, rect.bottom)
                path.lineTo(rect.left, rect.bottom)
            }
            canvas.drawPath(path, paint)
        }

        // Draw start edge
        // **Dart Source:** `linear_border.dart:292-305`
        if let startEdge = start, startEdge.size != 0.0, side.style != .none {
            let insetRect = Rect.fromLTWH(
                rect.left,
                rect.top + insets.top,
                rect.width,
                rect.height - insets.vertical
            )
            let x = rtl ? rect.right - insets.right : rect.left
            let width = rtl ? insets.right : insets.left
            let height = insetRect.height * startEdge.size
            let y = (insetRect.height - height) * ((startEdge.alignment + 1.0) / 2.0)
            let r = Rect.fromLTWH(x, y, width, height)
            drawEdge(r, side.color)
        }

        // Draw end edge
        // **Dart Source:** `linear_border.dart:307-320`
        if let endEdge = end, endEdge.size != 0.0, side.style != .none {
            let insetRect = Rect.fromLTWH(
                rect.left,
                rect.top + insets.top,
                rect.width,
                rect.height - insets.vertical
            )
            let x = rtl ? rect.left : rect.right - insets.right
            let width = rtl ? insets.left : insets.right
            let height = insetRect.height * endEdge.size
            let y = (insetRect.height - height) * ((endEdge.alignment + 1.0) / 2.0)
            let r = Rect.fromLTWH(x, y, width, height)
            drawEdge(r, side.color)
        }

        // Draw top edge
        // **Dart Source:** `linear_border.dart:322-328`
        if let topEdge = top, topEdge.size != 0.0, side.style != .none {
            let width = rect.width * topEdge.size
            let startX = (rect.width - width) * ((topEdge.alignment + 1.0) / 2.0)
            let x = rtl ? rect.width - startX - width : startX
            let r = Rect.fromLTWH(x, rect.top, width, insets.top)
            drawEdge(r, side.color)
        }

        // Draw bottom edge
        // **Dart Source:** `linear_border.dart:330-336`
        if let bottomEdge = bottom, bottomEdge.size != 0.0, side.style != .none {
            let width = rect.width * bottomEdge.size
            let startX = (rect.width - width) * ((bottomEdge.alignment + 1.0) / 2.0)
            let x = rtl ? rect.width - startX - width : startX
            let r = Rect.fromLTWH(x, rect.bottom - insets.bottom, width, side.width)
            drawEdge(r, side.color)
        }
    }

    // MARK: - Hashable

    /// **Dart Source:** `linear_border.dart:340-353`
    public static func == (lhs: LinearBorder, rhs: LinearBorder) -> Bool {
        lhs.side == rhs.side &&
        lhs.start == rhs.start &&
        lhs.end == rhs.end &&
        lhs.top == rhs.top &&
        lhs.bottom == rhs.bottom
    }

    /// **Dart Source:** `linear_border.dart:356`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(side)
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(top)
        hasher.combine(bottom)
    }

    // MARK: - CustomStringConvertible

    /// **Dart Source:** `linear_border.dart:359-380`
    public var description: String {
        if self == LinearBorder.none {
            return "LinearBorder.none"
        }

        var s = "\(objectRuntimeType(self, "LinearBorder"))(side: \(side)"

        if let start = start {
            s += ", start: \(start)"
        }
        if let end = end {
            s += ", end: \(end)"
        }
        if let top = top {
            s += ", top: \(top)"
        }
        if let bottom = bottom {
            s += ", bottom: \(bottom)"
        }
        s += ")"
        return s
    }
}
