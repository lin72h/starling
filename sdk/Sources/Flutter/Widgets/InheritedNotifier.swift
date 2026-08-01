// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - InheritedNotifier

/// An inherited widget for a `Listenable` notifier, which updates its
/// dependencies when the notifier is triggered.
///
/// This is a variant of `InheritedWidget`, specialized for subclasses of
/// `Listenable`, such as `ChangeNotifier` or `ValueNotifier`.
///
/// Dependents are notified whenever the notifier sends notifications, or
/// whenever the identity of the notifier changes.
///
/// Multiple notifications are coalesced, so that dependents only rebuild once
/// even if the notifier fires multiple times between two frames.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/inherited_notifier.dart:65-91`
open class InheritedNotifier<T: Listenable>: InheritedWidget {

    /// Create an inherited widget that updates its dependents when `notifier`
    /// sends notifications.
    ///
    /// **Dart Source:** `inherited_notifier.dart:68`
    public init(key: (any Key)? = nil, notifier: T? = nil, child: Widget) {
        self.notifier = notifier
        super.init(key: key, child: child)
    }

    /// The `Listenable` object to which to listen.
    ///
    /// Whenever this object sends change notifications, the dependents of this
    /// widget are triggered.
    ///
    /// **Dart Source:** `inherited_notifier.dart:82`
    public let notifier: T?

    /// **Dart Source:** `inherited_notifier.dart:85-87`
    open override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        let old = oldWidget as! InheritedNotifier<T>
        let oldObj = old.notifier.map { $0 as AnyObject }
        let newObj = notifier.map { $0 as AnyObject }
        return oldObj !== newObj
    }

    /// **Dart Source:** `inherited_notifier.dart:90`
    open override func createElement() -> Element {
        return _InheritedNotifierElement<T>(self)
    }
}

// MARK: - _InheritedNotifierElement

/// Element that manages listener registration for `InheritedNotifier`.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/inherited_notifier.dart:93-135`
class _InheritedNotifierElement<T: Listenable>: InheritedElement {

    /// **Dart Source:** `inherited_notifier.dart:94-96`
    init(_ widget: InheritedNotifier<T>) {
        super.init(widget)
        widget.notifier?.addListener(_handleUpdate)
    }

    private var _notifierDirty = false

    /// **Dart Source:** `inherited_notifier.dart:101-109`
    override func update(_ newWidget: Widget) {
        let oldNotifier = (widget as! InheritedNotifier<T>).notifier
        let newNotifier = (newWidget as! InheritedNotifier<T>).notifier
        let oldObj = oldNotifier.map { $0 as AnyObject }
        let newObj = newNotifier.map { $0 as AnyObject }
        if oldObj !== newObj {
            oldNotifier?.removeListener(_handleUpdate)
            newNotifier?.addListener(_handleUpdate)
        }
        super.update(newWidget)
    }

    /// **Dart Source:** `inherited_notifier.dart:112-117`
    override func build() -> Widget {
        if _notifierDirty {
            notifyClients(widget as! InheritedNotifier<T>)
        }
        return super.build()
    }

    /// **Dart Source:** `inherited_notifier.dart:119-122`
    private func _handleUpdate() {
        _notifierDirty = true
        markNeedsBuild()
    }

    /// **Dart Source:** `inherited_notifier.dart:125-128`
    override func notifyClients(_ oldWidget: ProxyWidget) {
        super.notifyClients(oldWidget)
        _notifierDirty = false
    }

    /// **Dart Source:** `inherited_notifier.dart:131-134`
    override func unmount() {
        (widget as! InheritedNotifier<T>).notifier?.removeListener(_handleUpdate)
        super.unmount()
    }
}
