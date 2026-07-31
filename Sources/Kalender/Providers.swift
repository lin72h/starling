// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The provider plumbing of the kalender port: the inherited widgets that make
// the controllers, callbacks and components available to every calendar
// widget below the `CalendarView`, and the rebuild primitive they listen
// through.
//
// Ported from: kalender/lib/src/models/providers/calendar_provider.dart

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - KalListenableBuilder

/// Rebuilds whenever any of the given `Listenable`s notifies.
///
/// The Dart package leans on `ValueListenableBuilder`; this framework's
/// `ChangeNotifier.removeListener` is documented as best-effort (Swift
/// closures have no identity, so it pops the most recently added listener —
/// possibly someone else's). A calendar hangs many widgets off a few shared
/// notifiers, which is exactly the shape that corrupts. So this builder never
/// removes its listener: the closure holds its State weakly, checks that the
/// State is still mounted and still bound to the same listenable generation,
/// and otherwise does nothing. Stale closures on a long-lived notifier are a
/// few no-op frames of overhead, traded for never detaching a live listener.
public class KalListenableBuilder: StatefulWidget {
    public let listenables: [any Listenable]
    public let builder: (any BuildContext) -> Widget

    public init(
        key: (any Key)? = nil,
        listenable: any Listenable,
        builder: @escaping (any BuildContext) -> Widget
    ) {
        self.listenables = [listenable]
        self.builder = builder
        super.init(key: key)
    }

    public init(
        key: (any Key)? = nil,
        listenables: [any Listenable],
        builder: @escaping (any BuildContext) -> Widget
    ) {
        self.listenables = listenables
        self.builder = builder
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _KalListenableBuilderState()
    }
}

private class _KalListenableBuilderState: State<StatefulWidget> {
    /// Bumped whenever the widget's listenables change, so closures added for
    /// an earlier set fall silent instead of triggering rebuilds for it.
    private var _generation = 0
    private var _subscribed: [AnyObject] = []

    override func initState() {
        super.initState()
        _subscribe()
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let old = _subscribed
        let new = (widget as! KalListenableBuilder).listenables
        let changed = old.count != new.count
            || zip(old, new).contains { $0 !== ($1 as AnyObject) }
        if changed { _subscribe() }
    }

    private func _subscribe() {
        _generation += 1
        let generation = _generation
        let listenables = (widget as! KalListenableBuilder).listenables
        _subscribed = listenables.map { $0 as AnyObject }
        for listenable in listenables {
            listenable.addListener { [weak self] in
                guard let self, self.mounted, self._generation == generation else { return }
                self.setState {}
            }
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        return (widget as! KalListenableBuilder).builder(context)
    }
}

// MARK: - CalendarProvider

/// Everything the calendar widgets read from their surrounding
/// `CalendarView`: the controllers, callbacks, components and interaction
/// configuration.
///
/// The Dart package spreads these over several `InheritedWidget`s
/// (EventsControllerProvider, CalendarControllerProvider, Callbacks,
/// Components, ...); one carrier keeps the Swift tree shallower while the
/// accessors keep kalender's names.
public class CalendarProvider: InheritedWidget {
    public let eventsController: EventsController
    public let calendarController: CalendarController
    public let callbacks: CalendarCallbacks?
    public let components: CalendarComponents
    public let interaction: CalendarInteraction

    public init(
        eventsController: EventsController,
        calendarController: CalendarController,
        callbacks: CalendarCallbacks?,
        components: CalendarComponents,
        interaction: CalendarInteraction,
        child: Widget
    ) {
        self.eventsController = eventsController
        self.calendarController = calendarController
        self.callbacks = callbacks
        self.components = components
        self.interaction = interaction
        super.init(child: child)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        let old = oldWidget as! CalendarProvider
        return old.eventsController !== eventsController
            || old.calendarController !== calendarController
            || old.callbacks !== callbacks
            || old.components !== components
    }

    public static func of(_ context: any BuildContext) -> CalendarProvider {
        guard let provider = context.dependOnInheritedWidgetOfExactType(CalendarProvider.self) else {
            fatalError(
                "CalendarProvider.of() called with a context that does not contain a CalendarView."
            )
        }
        return provider
    }
}
