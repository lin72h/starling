// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Paints a `Decoration` either before or after its sliver child paints.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/decorated_sliver.dart`

import FlutterSwiftBridge

// MARK: - RenderDecoratedSliver

/// Paints a `Decoration` either before or after its child paints.
///
/// If the child has infinite scroll extent, then the `Decoration` paints
/// itself up to the bottom cache extent.
///
/// **Dart Source:** `decorated_sliver.dart:14-129`
open class RenderDecoratedSliver: RenderProxySliver {

    // MARK: - Initializer

    /// Creates a decorated sliver.
    ///
    /// The `decoration`, `position`, and `configuration` arguments must not be
    /// nil. By default the decoration paints behind the child.
    ///
    /// The `ImageConfiguration` will be passed to the decoration (with the size
    /// filled in) to let it resolve images.
    ///
    /// **Dart Source:** `decorated_sliver.dart:22-28`
    public init(
        decoration: any Decoration,
        position: DecorationPosition = .background,
        configuration: ImageConfiguration = .empty
    ) {
        _decoration = decoration
        _position = position
        _configuration = configuration
        super.init()
    }

    // MARK: - Decoration

    /// What decoration to paint.
    ///
    /// Commonly a `BoxDecoration`.
    ///
    /// **Dart Source:** `decorated_sliver.dart:33-43`
    public var decoration: any Decoration {
        get { _decoration }
        set {
            if _decoration === newValue {
                return
            }
            _decoration = newValue
            _painter?.dispose()
            _painter = _decoration.createBoxPainter(markNeedsPaint)
            markNeedsPaint()
        }
    }
    private var _decoration: any Decoration

    // MARK: - Position

    /// Whether to paint the box decoration behind or in front of the child.
    ///
    /// **Dart Source:** `decorated_sliver.dart:46-54`
    public var position: DecorationPosition {
        get { _position }
        set {
            if newValue == _position {
                return
            }
            _position = newValue
            markNeedsPaint()
        }
    }
    private var _position: DecorationPosition

    // MARK: - Configuration

    /// The settings to pass to the decoration when painting, so that it can
    /// resolve images appropriately. See `ImageProvider.resolve` and
    /// `BoxPainter.paint`.
    ///
    /// The `ImageConfiguration.textDirection` field is also used by
    /// direction-sensitive `Decoration`s for painting and hit-testing.
    ///
    /// **Dart Source:** `decorated_sliver.dart:63-70`
    public var configuration: ImageConfiguration {
        get { _configuration }
        set {
            if newValue == _configuration {
                return
            }
            _configuration = newValue
            markNeedsPaint()
        }
    }
    private var _configuration: ImageConfiguration

    // MARK: - Painter

    /// The box painter created by the decoration.
    ///
    /// Created on `attach`, disposed on `detach` and `dispose`.
    ///
    /// **Dart Source:** `decorated_sliver.dart:72`
    private var _painter: BoxPainter?

    // MARK: - Lifecycle

    /// Called when the object is attached to a pipeline owner.
    ///
    /// Creates the box painter from the current decoration.
    ///
    /// **Dart Source:** `decorated_sliver.dart:74-78`
    open override func attach(_ owner: PipelineOwner) {
        _painter = decoration.createBoxPainter(markNeedsPaint)
        super.attach(owner)
    }

    /// Called when the object is detached from its pipeline owner.
    ///
    /// Disposes the box painter.
    ///
    /// **Dart Source:** `decorated_sliver.dart:80-85`
    open override func detach() {
        _painter?.dispose()
        _painter = nil
        super.detach()
    }

    /// Releases any resources held by this render object.
    ///
    /// Disposes the box painter.
    ///
    /// **Dart Source:** `decorated_sliver.dart:87-92`
    open override func dispose() {
        _painter?.dispose()
        _painter = nil
        super.dispose()
    }

    // MARK: - Paint

    /// Paints the decoration before or after the child based on `position`.
    ///
    /// In the case where the child sliver has infinite scroll extent, the
    /// decoration only extends down to the bottom cache extent.
    ///
    /// Computes the decoration size from the child's geometry, accounting for
    /// the scroll axis direction. Paints the decoration either before
    /// (`background`) or after (`foreground`) the child.
    ///
    /// **Dart Source:** `decorated_sliver.dart:94-129`
    open override func paint(_ context: PaintingContext, _ offset: Offset) {
        guard let child = child, let childGeometry = child.geometry, childGeometry.visible else {
            return
        }

        // In the case where the child sliver has infinite scroll extent, the
        // decoration should only extend down to the bottom cache extent.
        let cappedMainAxisExtent: Double
        if childGeometry.scrollExtent.isInfinite {
            cappedMainAxisExtent =
                sliverConstraints.scrollOffset + childGeometry.cacheExtent
                + sliverConstraints.cacheOrigin
        } else {
            cappedMainAxisExtent = childGeometry.scrollExtent
        }

        let childSize: Size
        let scrollOffset: Offset
        switch sliverConstraints.axis {
        case .horizontal:
            childSize = Size(cappedMainAxisExtent, sliverConstraints.crossAxisExtent)
            scrollOffset = Offset(-sliverConstraints.scrollOffset, 0.0)
        case .vertical:
            childSize = Size(sliverConstraints.crossAxisExtent, cappedMainAxisExtent)
            scrollOffset = Offset(0.0, -sliverConstraints.scrollOffset)
        }

        let childParentData = child.parentData! as! SliverPhysicalParentData
        let adjustedOffset = offset + childParentData.paintOffset

        let paintDecoration = {
            self._painter!.paint(
                context.canvas,
                adjustedOffset + scrollOffset,
                self.configuration.copyWith(size: childSize)
            )
        }

        switch position {
        case .background:
            paintDecoration()
            context.paintChild(child, adjustedOffset)
        case .foreground:
            context.paintChild(child, adjustedOffset)
            paintDecoration()
        }
    }
}
