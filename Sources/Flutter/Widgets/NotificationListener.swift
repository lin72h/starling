// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - NotificationListenerCallback

/// Signature for `Notification` listeners.
///
/// Return true to cancel the notification bubbling. Return false to allow the
/// notification to continue to be dispatched to further ancestors.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/notification_listener.dart:25`
public typealias NotificationListenerCallback<T: Notification> = (T) -> Bool

// MARK: - Notification

/// A notification that can bubble up the widget tree.
///
/// You can determine the type of a notification using type checks.
///
/// To listen for notifications in a subtree, use a `NotificationListener`.
///
/// To send a notification, call `dispatch` on the notification you wish to
/// send. The notification will be delivered to any `NotificationListener`
/// widgets with the appropriate type parameters that are ancestors of the given
/// `BuildContext`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/notification_listener.dart:56-90`
open class Notification: CustomStringConvertible {

    /// Abstract const constructor. This constructor enables subclasses to provide
    /// initializers so that they can be used in expressions.
    ///
    /// **Dart Source:** `notification_listener.dart:59`
    public init() {}

    /// Start bubbling this notification at the given build context.
    ///
    /// The notification will be delivered to any `NotificationListener` widgets
    /// with the appropriate type parameters that are ancestors of the given
    /// `BuildContext`. If the `BuildContext` is nil, the notification is not
    /// dispatched.
    ///
    /// **Dart Source:** `notification_listener.dart:67-69`
    public func dispatch(_ target: BuildContext?) {
        target?.dispatchNotification(self)
    }

    /// **Dart Source:** `notification_listener.dart:72-76`
    public var description: String {
        var parts: [String] = []
        debugFillDescription(&parts)
        return "\(objectRuntimeType(self, "Notification"))(\(parts.joined(separator: ", ")))"
    }

    /// Add additional information to the given description for use by `description`.
    ///
    /// This method makes it easier for subclasses to coordinate to provide a
    /// high-quality description. The `description` property on the `Notification`
    /// base class calls `debugFillDescription` to collect useful information from
    /// subclasses to incorporate into its return value.
    ///
    /// Implementations of this method should start with a call to the inherited
    /// method, as in `super.debugFillDescription(&description)`.
    ///
    /// **Dart Source:** `notification_listener.dart:89`
    open func debugFillDescription(_ description: inout [String]) {}
}

// MARK: - NotificationListener

/// A widget that listens for `Notification`s bubbling up the tree.
///
/// Notifications will trigger the `onNotification` callback only if their
/// runtime type is a subtype of `T`.
///
/// To dispatch notifications, use the `Notification.dispatch` method.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/notification_listener.dart:100-124`
public class NotificationListener<T: Notification>: ProxyWidget {

    /// Creates a widget that listens for notifications.
    ///
    /// **Dart Source:** `notification_listener.dart:102`
    public init(key: (any Key)? = nil, child: Widget, onNotification: NotificationListenerCallback<T>? = nil) {
        self.onNotification = onNotification
        super.init(key: key, child: child)
    }

    /// Called when a notification of the appropriate type arrives at this
    /// location in the tree.
    ///
    /// Return true to cancel the notification bubbling. Return false to
    /// allow the notification to continue to be dispatched to further ancestors.
    ///
    /// **Dart Source:** `notification_listener.dart:118`
    public let onNotification: NotificationListenerCallback<T>?

    /// **Dart Source:** `notification_listener.dart:121-123`
    public override func createElement() -> Element {
        return NotificationElement<T>(self)
    }
}

// MARK: - NotificationElement

/// An element used to host `NotificationListener` elements.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/notification_listener.dart:127-144`
public class NotificationElement<T: Notification>: ProxyElement, NotifiableElementMixin {

    /// Creates a notification element.
    ///
    /// **Dart Source:** `notification_listener.dart:129`
    public init(_ widget: NotificationListener<T>) {
        super.init(widget)
    }

    /// **Dart Source:** `notification_listener.dart:132-138`
    public func onNotification(_ notification: Notification) -> Bool {
        guard let listener = widget as? NotificationListener<T> else { return false }
        if let callback = listener.onNotification, let typed = notification as? T {
            return callback(typed)
        }
        return false
    }

    /// **Dart Source:** `notification_listener.dart:141-143`
    public override func notifyClients(_ oldWidget: ProxyWidget) {
        // Notification tree does not need to notify clients.
    }
}

// MARK: - LayoutChangedNotification

/// Indicates that the layout of one of the descendants of the object receiving
/// this notification has changed in some way, and that therefore any
/// assumptions about that layout are no longer valid.
///
/// Useful if, for instance, you're trying to align multiple descendants.
///
/// To listen for notifications in a subtree, use a
/// `NotificationListener<LayoutChangedNotification>`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/notification_listener.dart:174-177`
open class LayoutChangedNotification: Notification {

    /// Create a new `LayoutChangedNotification`.
    ///
    /// **Dart Source:** `notification_listener.dart:176`
    public override init() {
        super.init()
    }
}
