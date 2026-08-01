// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An immutable description of how to paint an arbitrary shape.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/shape_decoration.dart`

import FlutterSwiftBridge

// MARK: - ShapeDecoration

/// An immutable description of how to paint an arbitrary shape.
///
/// The `ShapeDecoration` class provides a way to draw a `ShapeBorder`,
/// optionally filling it with a color or a gradient, and optionally casting
/// a shadow.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/shape_decoration.dart`
/// **Original Name:** `ShapeDecoration`
/// **Lines:** 65-288
public final class ShapeDecoration: Decoration {

    // MARK: - Properties

    /// The color to fill in the background of the shape.
    ///
    /// The color is under the image.
    ///
    /// If a `gradient` is specified, `color` must be nil.
    ///
    /// **Dart Source:** `shape_decoration.dart:128`
    public let color: Color?

    /// A gradient to use when filling the shape.
    ///
    /// The gradient is under the image.
    ///
    /// If a `color` is specified, `gradient` must be nil.
    ///
    /// **Dart Source:** `shape_decoration.dart:135`
    public let gradient: GradientBase?

    // TODO: Add `image: DecorationImage?` property when DecorationImage is migrated.

    /// A list of shadows cast by the `shape`.
    ///
    /// **Dart Source:** `shape_decoration.dart:149`
    public let shadows: [BoxShadow]?

    /// The shape to fill the `color`, `gradient`, and image into and to cast as
    /// the `shadows`.
    ///
    /// Shapes can be stacked (using the `+` operator). The color, gradient, and
    /// image are drawn into the inner-most shape specified.
    ///
    /// The `shape` property specifies the outline (border) of the decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:172`
    public let shape: any ShapeBorder

    // MARK: - Initializer

    /// Creates a shape decoration.
    ///
    /// * If `color` is nil, this decoration does not paint a background color.
    /// * If `gradient` is nil, this decoration does not paint gradients.
    /// * If `shadows` is nil, this decoration does not paint a shadow.
    ///
    /// The `color` and `gradient` properties are mutually exclusive, one (or
    /// both) of them must be nil.
    ///
    /// **Dart Source:** `shape_decoration.dart:75-76`
    public init(
        color: Color? = nil,
        gradient: GradientBase? = nil,
        shadows: [BoxShadow]? = nil,
        shape: any ShapeBorder
    ) {
        assert(
            !(color != nil && gradient != nil),
            "The color and gradient properties are mutually exclusive."
        )
        self.color = color
        self.gradient = gradient
        self.shadows = shadows
        self.shape = shape
    }

    // TODO: Add `fromBoxDecoration(_:)` static factory method when BoxDecoration is migrated.

    // MARK: - Decoration Protocol

    /// Returns a closed `Path` that describes the outer edge of this decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:118-121`
    public func getClipPath(_ rect: Rect, _ textDirection: TextDirection) -> Path {
        shape.getOuterPath(rect, textDirection: textDirection)
    }

    /// The inset space occupied by the `shape`'s border.
    ///
    /// This value may be misleading. See the discussion at `ShapeBorder.dimensions`.
    ///
    /// **Dart Source:** `shape_decoration.dart:177-178`
    public var padding: any EdgeInsetsGeometry {
        shape.dimensions
    }

    /// Whether this decoration is complex enough to benefit from caching its painting.
    ///
    /// **Dart Source:** `shape_decoration.dart:180-181`
    public var isComplex: Bool {
        shadows != nil
    }

    /// Tests whether the given point, on a rectangle of a given size,
    /// would be considered to hit the decoration or not.
    ///
    /// **Dart Source:** `shape_decoration.dart:278-281`
    public func hitTest(_ size: Size, _ position: Offset, textDirection: TextDirection? = nil) -> Bool {
        shape.getOuterPath(
            Rect.fromLTWH(0, 0, size.width, size.height),
            textDirection: textDirection
        ).contains(position)
    }

    /// Returns a `BoxPainter` that will paint this decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:283-287`
    public func createBoxPainter(_ onChanged: VoidCallback? = nil) -> BoxPainter {
        // TODO: Assert onChanged != nil || image == nil when DecorationImage is added
        return ShapeDecorationPainter(self, onChanged: onChanged)
    }

    // MARK: - Lerp Methods

    /// Linearly interpolates from another `Decoration` to `this`.
    ///
    /// **Dart Source:** `shape_decoration.dart:183-190`
    public func lerpFrom(_ a: (any Decoration)?, t: Double) -> (any Decoration)? {
        // TODO: Handle BoxDecoration case when BoxDecoration is migrated
        if a == nil || a is ShapeDecoration {
            return ShapeDecoration.lerp(a as? ShapeDecoration, self, t)
        }
        return nil
    }

    /// Linearly interpolates from `this` to another `Decoration`.
    ///
    /// **Dart Source:** `shape_decoration.dart:192-199`
    public func lerpTo(_ b: (any Decoration)?, t: Double) -> (any Decoration)? {
        // TODO: Handle BoxDecoration case when BoxDecoration is migrated
        if b == nil || b is ShapeDecoration {
            return ShapeDecoration.lerp(self, b as? ShapeDecoration, t)
        }
        return nil
    }

    /// Linearly interpolate between two shapes.
    ///
    /// Interpolates each parameter of the decoration separately.
    ///
    /// If both values are nil, this returns nil. Otherwise, it returns a
    /// non-nil value, with nil arguments treated like a `ShapeDecoration` whose
    /// fields are all nil (including the `shape`, which cannot normally be
    /// nil).
    ///
    /// **Dart Source:** `shape_decoration.dart:219-238`
    public static func lerp(_ a: ShapeDecoration?, _ b: ShapeDecoration?, _ t: Double) -> ShapeDecoration? {
        if a === b {
            return a
        }
        if a != nil && b != nil {
            if t == 0.0 {
                return a
            }
            if t == 1.0 {
                return b
            }
        }
        // TODO: Add DecorationImage.lerp when DecorationImage is migrated
        return ShapeDecoration(
            color: Color.lerp(a?.color, b?.color, t),
            gradient: GradientBase.lerp(a?.gradient, b?.gradient, t),
            shadows: BoxShadow.lerpList(a?.shadows, b?.shadows, t),
            shape: ShapeBorderStatics.lerp(a?.shape, b?.shape, t)!
        )
    }

    // MARK: - Diagnosticable

    /// A brief description of this object.
    ///
    /// **Dart Source:** `shape_decoration.dart` (via Decoration)
    public func toStringShort() -> String {
        objectRuntimeType(self, "ShapeDecoration")
    }

    /// Add additional properties associated with the node.
    ///
    /// **Dart Source:** `shape_decoration.dart:260-276`
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.defaultDiagnosticsTreeStyle = .whitespace
        properties.add(ColorProperty("color", color, defaultValue: nil))
        properties.add(DiagnosticsProperty("gradient", gradient, defaultValue: nil))
        // TODO: Add image property when DecorationImage is migrated
        if let shadows = shadows {
            properties.add(IterableProperty<BoxShadow>("shadows", shadows, defaultValue: nil, style: .whitespace))
        } else {
            properties.add(IterableProperty<BoxShadow>("shadows", nil, defaultValue: nil, style: .whitespace))
        }
        properties.add(DiagnosticsProperty("shape", shape))
    }

    /// Returns a `DiagnosticsNode` representation of this object.
    public func toDiagnosticsNode(name: String? = nil, style: DiagnosticsTreeStyle? = nil) -> DiagnosticsNode {
        DiagnosticableNode(name: name, value: self, style: style)
    }
}

// MARK: - Equatable

extension ShapeDecoration: Equatable {
    /// Compares two `ShapeDecoration` instances for equality.
    ///
    /// **Dart Source:** `shape_decoration.dart:241-254`
    public static func == (lhs: ShapeDecoration, rhs: ShapeDecoration) -> Bool {
        if lhs === rhs { return true }
        // Compare shape using description (existential ShapeBorder can't use ==)
        return lhs.color == rhs.color &&
            lhs.gradient == rhs.gradient &&
            lhs.shadows == rhs.shadows &&
            shapeBorderEqual(lhs.shape, rhs.shape)
    }
}

// MARK: - Hashable

extension ShapeDecoration: Hashable {
    /// The hash code for this decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:256-258`
    public func hash(into hasher: inout Hasher) {
        hasher.combine(color)
        hasher.combine(gradient)
        // TODO: Add image hash when DecorationImage is migrated
        hasher.combine(shapeBorderHashValue(shape))
        if let shadows = shadows {
            for shadow in shadows {
                hasher.combine(shadow)
            }
        }
    }
}

// MARK: - ShapeBorder Equality/Hashing Helpers

/// Helper to compare two existential `ShapeBorder` values for equality.
///
/// Since Swift existential types don't support `==` directly, we check if both
/// are the same concrete type and compare their `description` and `dimensions`.
private func shapeBorderEqual(_ lhs: any ShapeBorder, _ rhs: any ShapeBorder) -> Bool {
    // Try known concrete types first
    if let l = lhs as? CircleBorder, let r = rhs as? CircleBorder {
        return l == r
    }
    if let l = lhs as? RoundedRectangleBorder, let r = rhs as? RoundedRectangleBorder {
        return l == r
    }
    if let l = lhs as? OvalBorder, let r = rhs as? OvalBorder {
        return l == r
    }
    if let l = lhs as? BoxBorder, let r = rhs as? BoxBorder {
        return l == r
    }
    // Fallback: compare descriptions
    return lhs.description == rhs.description
}

/// Helper to produce a hash value for an existential `ShapeBorder`.
private func shapeBorderHashValue(_ border: any ShapeBorder) -> Int {
    var hasher = Hasher()
    if let b = border as? CircleBorder {
        b.hash(into: &hasher)
    } else if let b = border as? RoundedRectangleBorder {
        b.hash(into: &hasher)
    } else if let b = border as? OvalBorder {
        b.hash(into: &hasher)
    } else if let b = border as? BoxBorder {
        b.hash(into: &hasher)
    } else {
        hasher.combine(border.description)
    }
    return hasher.finalize()
}

// MARK: - ShapeDecorationPainter

/// An object that paints a `ShapeDecoration` into a canvas.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/shape_decoration.dart`
/// **Original Name:** `_ShapeDecorationPainter`
/// **Lines:** 291-482
internal class ShapeDecorationPainter: BoxPainter {

    // MARK: - Properties

    /// The decoration configuration.
    ///
    /// **Dart Source:** `shape_decoration.dart:294`
    private let decoration: ShapeDecoration

    /// **Dart Source:** `shape_decoration.dart:296`
    private var lastRect: Rect?

    /// **Dart Source:** `shape_decoration.dart:297`
    private var lastTextDirection: TextDirection?

    /// **Dart Source:** `shape_decoration.dart:298`
    private var outerPath: Path?

    /// **Dart Source:** `shape_decoration.dart:299`
    private var innerPath: Path?

    /// **Dart Source:** `shape_decoration.dart:300`
    private var interiorPaint: Paint?

    /// **Dart Source:** `shape_decoration.dart:301`
    private var shadowCount: Int?

    /// **Dart Source:** `shape_decoration.dart:302`
    private var shadowBounds: [Rect] = []

    /// **Dart Source:** `shape_decoration.dart:303`
    private var shadowPaths: [Path] = []

    /// **Dart Source:** `shape_decoration.dart:304`
    private var shadowPaints: [Paint] = []

    // TODO: Add `imagePainter: DecorationImagePainter?` when DecorationImage is migrated.

    // MARK: - Initializer

    /// Creates a `ShapeDecorationPainter` for the given decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:292`
    init(_ decoration: ShapeDecoration, onChanged: VoidCallback?) {
        self.decoration = decoration
        super.init(onChanged: onChanged)
    }

    // MARK: - Dispose

    /// Disposes of painting resources.
    ///
    /// **Dart Source:** `shape_decoration.dart:465-469`
    override func dispose() {
        // TODO: Dispose imagePainter when DecorationImage is migrated
        super.dispose()
    }

    // MARK: - Precache

    /// Caches painting resources based on the given rect and text direction.
    ///
    /// **Dart Source:** `shape_decoration.dart:309-364`
    private func precache(_ rect: Rect, _ textDirection: TextDirection?) {
        if rect == lastRect && textDirection == lastTextDirection {
            return
        }

        // Initialize interior paint if needed
        if interiorPaint == nil && (decoration.color != nil || decoration.gradient != nil) {
            interiorPaint = Paint()
            if let color = decoration.color {
                interiorPaint!.color = color
            }
        }
        // Update gradient shader
        if let gradient = decoration.gradient {
            interiorPaint!.shader = gradient.createShader(
                rect: rect,
                textDirection: textDirection
            )
        }
        // Setup shadow painting data
        if let shadows = decoration.shadows {
            if shadowCount == nil {
                shadowCount = shadows.count
                shadowPaints = shadows.map { $0.toPaint() }
            }
            if decoration.shape.preferPaintInterior {
                shadowBounds = shadows.map { shadow in
                    rect.shift(shadow.offset).inflate(shadow.spreadRadius)
                }
            } else {
                shadowPaths = shadows.map { shadow in
                    decoration.shape.getOuterPath(
                        rect.shift(shadow.offset).inflate(shadow.spreadRadius),
                        textDirection: textDirection
                    )
                }
            }
        }
        // Compute outer path
        if !decoration.shape.preferPaintInterior
            && (interiorPaint != nil || shadowCount != nil) {
            outerPath = decoration.shape.getOuterPath(rect, textDirection: textDirection)
        }
        // TODO: Compute inner path when DecorationImage is migrated

        lastRect = rect
        lastTextDirection = textDirection
    }

    // MARK: - Paint Shadows

    /// Paints the shadows for the decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:366-426`
    private func paintShadows(_ canvas: Canvas, _ rect: Rect, _ textDirection: TextDirection?) {
        guard let shadowCount = shadowCount, let shadows = decoration.shadows else {
            return
        }

        if decoration.shape.preferPaintInterior {
            for index in 0..<shadowCount {
                #if DEBUG
                debugHandleDisabledShadowStart(
                    canvas,
                    shadows[index],
                    decoration.shape.getOuterPath(
                        shadowBounds[index],
                        textDirection: textDirection
                    )
                )
                #endif
                decoration.shape.paintInterior(
                    canvas,
                    shadowBounds[index],
                    shadowPaints[index],
                    textDirection: textDirection
                )
                #if DEBUG
                debugHandleDisabledShadowEnd(canvas, shadows[index])
                #endif
            }
        } else {
            for index in 0..<shadowCount {
                #if DEBUG
                debugHandleDisabledShadowStart(
                    canvas,
                    shadows[index],
                    shadowPaths[index]
                )
                #endif
                canvas.drawPath(shadowPaths[index], shadowPaints[index])
                #if DEBUG
                debugHandleDisabledShadowEnd(canvas, shadows[index])
                #endif
            }
        }
    }

    /// Handles debug disabled shadow clipping start.
    ///
    /// **Dart Source:** `shape_decoration.dart:375-385`
    #if DEBUG
    private func debugHandleDisabledShadowStart(
        _ canvas: Canvas,
        _ boxShadow: BoxShadow,
        _ path: Path
    ) {
        if debugDisableShadows && boxShadow.blurStyle == .outer {
            canvas.save()
            let clipPath = Path()
            clipPath.fillType = .evenOdd
            clipPath.addRect(Rect.largest)
            clipPath.addPath(path, .zero)
            canvas.clipPath(clipPath)
        }
    }
    #endif

    /// Handles debug disabled shadow clipping end.
    ///
    /// **Dart Source:** `shape_decoration.dart:387-392`
    #if DEBUG
    private func debugHandleDisabledShadowEnd(
        _ canvas: Canvas,
        _ boxShadow: BoxShadow
    ) {
        if debugDisableShadows && boxShadow.blurStyle == .outer {
            canvas.restore()
        }
    }
    #endif

    // MARK: - Paint Interior

    /// Paints the interior (color/gradient fill) of the decoration.
    ///
    /// **Dart Source:** `shape_decoration.dart:428-444`
    private func paintInterior(_ canvas: Canvas, _ rect: Rect, _ textDirection: TextDirection?) {
        guard let interiorPaint = interiorPaint else { return }

        if decoration.shape.preferPaintInterior {
            // When border is filled, the rect is reduced to avoid anti-aliasing
            // rounding error leaking the background color around the clipped shape.
            let adjustedRect = adjustedRectOnOutlinedBorder(rect)
            decoration.shape.paintInterior(
                canvas,
                adjustedRect,
                interiorPaint,
                textDirection: textDirection
            )
        } else {
            canvas.drawPath(outerPath!, interiorPaint)
        }
    }

    /// Adjusts the rect for outlined borders to avoid anti-aliasing artifacts.
    ///
    /// **Dart Source:** `shape_decoration.dart:446-454`
    private func adjustedRectOnOutlinedBorder(_ rect: Rect) -> Rect {
        if let outlinedBorder = decoration.shape as? any OutlinedBorder,
           decoration.color != nil {
            let side = outlinedBorder.side
            if Int((side.color.a * 255.0).rounded()) == 255 && side.style == .solid {
                return rect.deflate(side.strokeInset / 2)
            }
        }
        return rect
    }

    // MARK: - Paint

    /// Paints the decoration on the canvas.
    ///
    /// **Dart Source:** `shape_decoration.dart:471-481`
    override func paint(_ canvas: Canvas, _ offset: Offset, _ configuration: ImageConfiguration) {
        assert(configuration.size != nil)
        let rect = Rect.fromLTWH(
            offset.dx,
            offset.dy,
            configuration.size!.width,
            configuration.size!.height
        )
        let textDirection = configuration.textDirection
        precache(rect, textDirection)
        paintShadows(canvas, rect, textDirection)
        paintInterior(canvas, rect, textDirection)
        // TODO: Paint image when DecorationImage is migrated
        decoration.shape.paint(canvas, rect, textDirection: textDirection)
    }
}
