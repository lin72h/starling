// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - ViewportNotificationMixin

/// Protocol for notifications that track how many viewports they
/// have bubbled through.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:28-44`
public protocol ViewportNotificationMixin: AnyObject {
    /// The number of viewports that this notification has bubbled through.
    ///
    /// Typically listeners only respond to notifications with a `depth` of zero.
    var depth: Int { get set }
}

// MARK: - ViewportElementMixin

/// A protocol for elements containing Viewport-like widgets that correctly
/// modify the notification depth of a `ViewportNotificationMixin`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:52-60`
public protocol ViewportElementMixin: NotifiableElementMixin {
    // onNotification override increments depth
}

// MARK: - ScrollNotification

/// A notification related to scrolling.
///
/// `Scrollable` widgets notify their ancestors about scrolling-related changes.
/// The notifications have the following lifecycle:
///
///  * A `ScrollStartNotification`, which indicates that the widget has started scrolling.
///  * Zero or more `ScrollUpdateNotification`s, which indicate that the widget
///    has changed its scroll position, mixed with zero or more
///    `OverscrollNotification`s.
///  * A `ScrollEndNotification`, which indicates that the widget has stopped scrolling.
///  * A `UserScrollNotification`, with direction `.idle`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:129-148`
open class ScrollNotification: LayoutChangedNotification, ViewportNotificationMixin {
    /// A description of a `Scrollable`'s contents.
    ///
    /// **Dart Source:** `scroll_notification.dart:135`
    public let metrics: any ScrollMetrics

    /// The build context of the widget that fired this notification.
    ///
    /// **Dart Source:** `scroll_notification.dart:141`
    public let context: (any BuildContext)?

    /// The number of viewports that this notification has bubbled through.
    ///
    /// **Dart Source:** `scroll_notification.dart:36` (via ViewportNotificationMixin)
    public var depth: Int = 0

    /// Initializes fields for subclasses.
    ///
    /// **Dart Source:** `scroll_notification.dart:131`
    public init(metrics: any ScrollMetrics, context: (any BuildContext)?) {
        self.metrics = metrics
        self.context = context
        super.init()
    }

    open override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        description.append("\(metrics)")
        description.append("depth: \(depth) (\(depth == 0 ? "local" : "remote"))")
    }
}

// MARK: - ScrollStartNotification

/// A notification that a `Scrollable` widget has started scrolling.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:156-173`
public class ScrollStartNotification: ScrollNotification {
    /// If the `Scrollable` started scrolling because of a drag, the details about
    /// that drag start. Otherwise, nil.
    ///
    /// **Dart Source:** `scroll_notification.dart:164`
    public let dragDetails: DragStartDetails?

    /// Creates a notification that a `Scrollable` widget has started scrolling.
    ///
    /// **Dart Source:** `scroll_notification.dart:158`
    public init(
        metrics: any ScrollMetrics,
        context: (any BuildContext)?,
        dragDetails: DragStartDetails? = nil
    ) {
        self.dragDetails = dragDetails
        super.init(metrics: metrics, context: context)
    }

    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        if let dragDetails {
            description.append("\(dragDetails)")
        }
    }
}

// MARK: - ScrollUpdateNotification

/// A notification that a `Scrollable` widget has changed its scroll position.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:183-215`
public class ScrollUpdateNotification: ScrollNotification {
    /// If the `Scrollable` changed its scroll position because of a drag, the
    /// details about that drag update. Otherwise, nil.
    ///
    /// **Dart Source:** `scroll_notification.dart:202`
    public let dragDetails: DragUpdateDetails?

    /// The distance by which the `Scrollable` was scrolled, in logical pixels.
    ///
    /// **Dart Source:** `scroll_notification.dart:205`
    public let scrollDelta: Double?

    /// Creates a notification that a `Scrollable` widget has changed its scroll position.
    ///
    /// **Dart Source:** `scroll_notification.dart:186-196`
    public init(
        metrics: any ScrollMetrics,
        context: (any BuildContext)?,
        dragDetails: DragUpdateDetails? = nil,
        scrollDelta: Double? = nil,
        depth: Int? = nil
    ) {
        self.dragDetails = dragDetails
        self.scrollDelta = scrollDelta
        super.init(metrics: metrics, context: context)
        if let depth {
            self.depth = depth
        }
    }

    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        description.append("scrollDelta: \(scrollDelta.map { String($0) } ?? "nil")")
        if let dragDetails {
            description.append("\(dragDetails)")
        }
    }
}

// MARK: - OverscrollNotification

/// A notification that a `Scrollable` widget has not changed its scroll position
/// because the change would have caused its scroll position to go outside of
/// its scroll bounds.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:226-267`
public class OverscrollNotification: ScrollNotification {
    /// If the `Scrollable` overscrolled because of a drag, the details about that
    /// drag update. Otherwise, nil.
    ///
    /// **Dart Source:** `scroll_notification.dart:242`
    public let dragDetails: DragUpdateDetails?

    /// The number of logical pixels that the `Scrollable` avoided scrolling.
    ///
    /// This will be negative for overscroll on the "start" side and positive for
    /// overscroll on the "end" side.
    ///
    /// **Dart Source:** `scroll_notification.dart:248`
    public let overscroll: Double

    /// The velocity at which the `ScrollPosition` was changing when this
    /// overscroll happened.
    ///
    /// **Dart Source:** `scroll_notification.dart:256`
    public let velocity: Double

    /// Creates a notification that a `Scrollable` widget has changed its scroll
    /// position outside of its scroll bounds.
    ///
    /// **Dart Source:** `scroll_notification.dart:229-236`
    public init(
        metrics: any ScrollMetrics,
        context: (any BuildContext)?,
        dragDetails: DragUpdateDetails? = nil,
        overscroll: Double,
        velocity: Double = 0.0
    ) {
        assert(overscroll.isFinite)
        assert(overscroll != 0.0)
        self.dragDetails = dragDetails
        self.overscroll = overscroll
        self.velocity = velocity
        super.init(metrics: metrics, context: context)
    }

    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        description.append("overscroll: \(String(format: "%.1f", overscroll))")
        description.append("velocity: \(String(format: "%.1f", velocity))")
        if let dragDetails {
            description.append("\(dragDetails)")
        }
    }
}

// MARK: - ScrollEndNotification

/// A notification that a `Scrollable` widget has stopped scrolling.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:298-326`
public class ScrollEndNotification: ScrollNotification {
    /// If the `Scrollable` stopped scrolling because of a drag, the details about
    /// that drag end. Otherwise, nil.
    ///
    /// **Dart Source:** `scroll_notification.dart:317`
    public let dragDetails: DragEndDetails?

    /// Creates a notification that a `Scrollable` widget has stopped scrolling.
    ///
    /// **Dart Source:** `scroll_notification.dart:300-304`
    public init(
        metrics: any ScrollMetrics,
        context: (any BuildContext)?,
        dragDetails: DragEndDetails? = nil
    ) {
        self.dragDetails = dragDetails
        super.init(metrics: metrics, context: context)
    }

    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        if let dragDetails {
            description.append("\(dragDetails)")
        }
    }
}

// MARK: - UserScrollNotification

/// A notification that the user has changed the `ScrollDirection` in which they
/// are scrolling, or have stopped scrolling.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:339-363`
public class UserScrollNotification: ScrollNotification {
    /// The direction in which the user is scrolling.
    ///
    /// **Dart Source:** `scroll_notification.dart:356`
    public let direction: ScrollDirection

    /// Creates a notification that the user has changed the direction in which
    /// they are scrolling.
    ///
    /// **Dart Source:** `scroll_notification.dart:342-346`
    public init(
        metrics: any ScrollMetrics,
        context: (any BuildContext)?,
        direction: ScrollDirection
    ) {
        self.direction = direction
        super.init(metrics: metrics, context: context)
    }

    public override func debugFillDescription(_ description: inout [String]) {
        super.debugFillDescription(&description)
        description.append("direction: \(direction)")
    }
}

// MARK: - ScrollNotificationPredicate

/// A predicate for `ScrollNotification`, used to customize widgets that
/// listen to notifications from their children.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:367`
public typealias ScrollNotificationPredicate = (ScrollNotification) -> Bool

/// A `ScrollNotificationPredicate` that checks whether
/// `notification.depth == 0`, which means that the notification did not bubble
/// through any intervening scrolling widgets.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_notification.dart:372-374`
public func defaultScrollNotificationPredicate(_ notification: ScrollNotification) -> Bool {
    return notification.depth == 0
}
