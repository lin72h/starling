// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Viewport offset classes and scroll direction types.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/viewport_offset.dart`

import Foundation

// MARK: - ScrollDirection

/// The direction of a scroll, relative to the positive scroll offset axis given
/// by an `AxisDirection` and a `GrowthDirection`.
///
/// This is similar to `GrowthDirection`, but contrasts in that it has a third
/// value, `idle`, for the case where no scroll is occurring.
///
/// This is used by `RenderSliverFloatingPersistentHeader` to only expand when
/// the user is scrolling in the same direction as the detected scroll offset
/// change.
///
/// See also:
///
///  * `AxisDirection`, which is a directional version of this enum (with values
///    like left and right, rather than just horizontal).
///  * `GrowthDirection`, the direction in which slivers and their content are
///    ordered, relative to the scroll offset axis as specified by
///    `AxisDirection`.
///  * `UserScrollNotification`, which will notify listeners when the
///    `ScrollDirection` changes.
///
/// **Dart Source:** `viewport_offset.dart:16-71`
public enum ScrollDirection {
    /// No scrolling is underway.
    ///
    /// **Dart Source:** `viewport_offset.dart:48`
    case idle

    /// Scrolling is happening in the negative scroll offset direction.
    ///
    /// For example, for the `GrowthDirection.forward` part of a vertical
    /// `AxisDirection.down` list, which is the default directional configuration
    /// of all scroll views, this means the content is going down, exposing
    /// earlier content as it approaches the zero position.
    ///
    /// **Dart Source:** `viewport_offset.dart:49-59`
    case forward

    /// Scrolling is happening in the positive scroll offset direction.
    ///
    /// For example, for the `GrowthDirection.forward` part of a vertical
    /// `AxisDirection.down` list, which is the default directional configuration
    /// of all scroll views, this means the content is moving up, exposing
    /// lower content.
    ///
    /// **Dart Source:** `viewport_offset.dart:61-71`
    case reverse
}

// MARK: - flipScrollDirection

/// Returns the opposite of the given `ScrollDirection`.
///
/// Specifically, returns `ScrollDirection.reverse` for `ScrollDirection.forward`
/// (and vice versa) and returns `ScrollDirection.idle` for
/// `ScrollDirection.idle`.
///
/// **Dart Source:** `viewport_offset.dart:73-84`
public func flipScrollDirection(_ direction: ScrollDirection) -> ScrollDirection {
    switch direction {
    case .idle: return .idle
    case .forward: return .reverse
    case .reverse: return .forward
    }
}

// MARK: - ViewportOffset

/// Which part of the content inside the viewport should be visible.
///
/// The `pixels` value determines the scroll offset that the viewport uses to
/// select which part of its content to display. As the user scrolls the
/// viewport, this value changes, which changes the content that is displayed.
///
/// This object is a `Listenable` that notifies its listeners when `pixels`
/// changes.
///
/// See also:
///
///  * `ScrollPosition`, which is a commonly used concrete subclass.
///  * `RenderViewportBase`, which is a render object that uses viewport offsets.
///
/// **Dart Source:** `viewport_offset.dart:86-283`
///
/// DIFFERENCE FROM DART: Dart's `ViewportOffset` is abstract; Swift uses
/// an open class with `fatalError` stubs for abstract methods.
/// REASON: Swift does not have abstract classes; this pattern allows subclassing.
open class ViewportOffset: ChangeNotifier {

    /// Default constructor.
    ///
    /// Allows subclasses to construct this object directly.
    ///
    /// **Dart Source:** `viewport_offset.dart:100-108`
    public override init() {
        super.init()
    }

    /// Creates a viewport offset with the given `pixels` value.
    ///
    /// The `pixels` value does not change unless the viewport issues a
    /// correction.
    ///
    /// **Dart Source:** `viewport_offset.dart:110-114`
    public static func fixed(_ value: Double) -> ViewportOffset {
        FixedViewportOffset(value)
    }

    /// Creates a viewport offset with a `pixels` value of 0.0.
    ///
    /// The `pixels` value does not change unless the viewport issues a
    /// correction.
    ///
    /// **Dart Source:** `viewport_offset.dart:116-120`
    public static func zero() -> ViewportOffset {
        FixedViewportOffset(0.0)
    }

    /// The number of pixels to offset the children in the opposite of the axis direction.
    ///
    /// For example, if the axis direction is down, then the pixel value
    /// represents the number of logical pixels to move the children _up_ the
    /// screen. Similarly, if the axis direction is left, then the pixels value
    /// represents the number of logical pixels to move the children to _right_.
    ///
    /// This object notifies its listeners when this value changes (except when
    /// the value changes due to `correctBy`).
    ///
    /// **Dart Source:** `viewport_offset.dart:122-131`
    open var pixels: Double {
        fatalError("Subclass must override pixels")
    }

    /// Whether the `pixels` property is available.
    ///
    /// **Dart Source:** `viewport_offset.dart:133-134`
    open var hasPixels: Bool {
        fatalError("Subclass must override hasPixels")
    }

    /// Called when the viewport's extents are established.
    ///
    /// The argument is the dimension of the `RenderViewport` in the main axis
    /// (e.g. the height, for a vertical viewport).
    ///
    /// If applying the viewport dimensions changes the scroll offset, return
    /// false. Otherwise, return true.
    ///
    /// **Dart Source:** `viewport_offset.dart:136-159`
    open func applyViewportDimension(_ viewportDimension: Double) -> Bool {
        fatalError("Subclass must override applyViewportDimension")
    }

    /// Called when the viewport's content extents are established.
    ///
    /// The arguments are the minimum and maximum scroll extents respectively. The
    /// minimum will be equal to or less than the maximum.
    ///
    /// If applying the content dimensions changes the scroll offset, return
    /// false. Otherwise, return true.
    ///
    /// **Dart Source:** `viewport_offset.dart:161-186`
    open func applyContentDimensions(_ minScrollExtent: Double, _ maxScrollExtent: Double) -> Bool {
        fatalError("Subclass must override applyContentDimensions")
    }

    /// Apply a layout-time correction to the scroll offset.
    ///
    /// This method should change the `pixels` value by `correction`, but without
    /// calling `notifyListeners`. It is called during layout by the
    /// `RenderViewport`, before `applyContentDimensions`.
    ///
    /// **Dart Source:** `viewport_offset.dart:188-200`
    open func correctBy(_ correction: Double) {
        fatalError("Subclass must override correctBy")
    }

    /// Jumps `pixels` from its current value to the given value,
    /// without animation, and without checking if the new value is in range.
    ///
    /// **Dart Source:** `viewport_offset.dart:202-209`
    open func jumpTo(_ pixels: Double) {
        fatalError("Subclass must override jumpTo")
    }

    /// Animates `pixels` from its current value to the given value.
    ///
    /// The returned `Future` will complete when the animation ends, whether it
    /// completed successfully or whether it was interrupted prematurely.
    ///
    /// The duration must not be zero. To jump to a particular value without an
    /// animation, use `jumpTo`.
    ///
    /// **Dart Source:** `viewport_offset.dart:211-218`
    open func animateTo(_ to: Double, duration: Duration, curve: any Curve) async {
        fatalError("Subclass must override animateTo")
    }

    /// Calls `jumpTo` if duration is nil or `Duration.zero`, otherwise
    /// `animateTo` is called.
    ///
    /// If `animateTo` is called then `curve` defaults to `Curves.ease`. The
    /// `clamp` parameter is ignored by this stub implementation but subclasses
    /// like `ScrollPosition` handle it by adjusting `to` to prevent over or
    /// underscroll.
    ///
    /// **Dart Source:** `viewport_offset.dart:220-234`
    open func moveTo(_ to: Double, duration: Duration? = nil, curve: (any Curve)? = nil, clamp: Bool? = nil) async {
        if duration == nil || duration == .zero {
            jumpTo(to)
            return
        } else {
            await animateTo(to, duration: duration!, curve: curve ?? Curves.ease)
        }
    }

    /// The direction in which the user is trying to change `pixels`, relative to
    /// the viewport's `RenderViewportBase.axisDirection`.
    ///
    /// If the _user_ is not scrolling, this will return `ScrollDirection.idle`
    /// even if there is (for example) a `ScrollActivity` currently animating the
    /// position.
    ///
    /// **Dart Source:** `viewport_offset.dart:236-250`
    open var userScrollDirection: ScrollDirection {
        fatalError("Subclass must override userScrollDirection")
    }

    /// Whether a viewport is allowed to change `pixels` implicitly to respond to
    /// a call to `RenderObject.showOnScreen`.
    ///
    /// **Dart Source:** `viewport_offset.dart:252-259`
    open var allowImplicitScrolling: Bool {
        fatalError("Subclass must override allowImplicitScrolling")
    }

    /// Returns a string representation of this viewport offset.
    ///
    /// **Dart Source:** `viewport_offset.dart:261-266`
    open var description: String {
        var descriptionParts: [String] = []
        debugFillDescription(&descriptionParts)
        return "\(describeIdentity(self))(\(descriptionParts.joined(separator: ", ")))"
    }

    /// Add additional information to the given description for use by `description`.
    ///
    /// This method makes it easier for subclasses to coordinate to provide a
    /// high-quality description. The `description` property on the `ViewportOffset`
    /// base class calls `debugFillDescription` to collect useful information from
    /// subclasses to incorporate into its return value.
    ///
    /// Implementations of this method should start with a call to the inherited
    /// method, as in `super.debugFillDescription(&description)`.
    ///
    /// **Dart Source:** `viewport_offset.dart:268-282`
    open func debugFillDescription(_ description: inout [String]) {
        if hasPixels {
            description.append("offset: \(String(format: "%.1f", pixels))")
        }
    }
}

// MARK: - FixedViewportOffset

/// A viewport offset that has a fixed `pixels` value.
///
/// **Dart Source:** `viewport_offset.dart:285-321`
/// **Original Name:** `_FixedViewportOffset`
///
/// DIFFERENCE FROM DART: Dart's `_FixedViewportOffset` is file-private;
/// Swift uses `internal` access since Swift has no file-private classes across
/// module boundaries.
/// REASON: Swift visibility model differs from Dart's library-private.
class FixedViewportOffset: ViewportOffset {

    /// Creates a fixed viewport offset with the given pixel value.
    ///
    /// **Dart Source:** `viewport_offset.dart:286`
    init(_ pixels: Double) {
        self._pixels = pixels
        super.init()
    }

    /// **Dart Source:** `viewport_offset.dart:289`
    private var _pixels: Double

    /// **Dart Source:** `viewport_offset.dart:291-292`
    override var pixels: Double { _pixels }

    /// **Dart Source:** `viewport_offset.dart:294-295`
    override var hasPixels: Bool { true }

    /// **Dart Source:** `viewport_offset.dart:297-298`
    override func applyViewportDimension(_ viewportDimension: Double) -> Bool { true }

    /// **Dart Source:** `viewport_offset.dart:300-301`
    override func applyContentDimensions(_ minScrollExtent: Double, _ maxScrollExtent: Double) -> Bool { true }

    /// **Dart Source:** `viewport_offset.dart:303-306`
    override func correctBy(_ correction: Double) {
        _pixels += correction
    }

    /// **Dart Source:** `viewport_offset.dart:308-311`
    override func jumpTo(_ pixels: Double) {
        // Do nothing, viewport is fixed.
    }

    /// **Dart Source:** `viewport_offset.dart:313-314`
    override func animateTo(_ to: Double, duration: Duration, curve: any Curve) async {
        // Do nothing, viewport is fixed.
    }

    /// **Dart Source:** `viewport_offset.dart:316-317`
    override var userScrollDirection: ScrollDirection { .idle }

    /// **Dart Source:** `viewport_offset.dart:319-320`
    override var allowImplicitScrolling: Bool { false }
}
