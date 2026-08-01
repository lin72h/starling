// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/controllers/events_controller.dart,
// events_controller/default_events_controller.dart, default_event_store.dart

import Flutter
import Foundation

// MARK: - EventsController

/// Manages `CalendarEvent`s. Subclass to provide custom storage; see
/// `DefaultEventsController`.
open class EventsController: ChangeNotifier {
    public override init() { super.init() }

    /// The list of events.
    open var events: [CalendarEvent] {
        fatalError("Subclasses of EventsController must override events")
    }

    /// Adds an event. Returns the id assigned to it.
    @discardableResult
    open func addEvent(_ event: CalendarEvent) -> String {
        fatalError("Subclasses of EventsController must override addEvent")
    }

    /// Adds a list of events. Returns their ids in order.
    @discardableResult
    open func addEvents(_ events: [CalendarEvent]) -> [String] {
        fatalError("Subclasses of EventsController must override addEvents")
    }

    /// Removes an event.
    open func removeEvent(_ event: CalendarEvent) {
        fatalError("Subclasses of EventsController must override removeEvent")
    }

    /// Removes an event by id.
    open func removeById(_ id: String) {
        fatalError("Subclasses of EventsController must override removeById")
    }

    /// Removes the events for which `test` returns true.
    open func removeWhere(_ test: (String, CalendarEvent) -> Bool) {
        fatalError("Subclasses of EventsController must override removeWhere")
    }

    /// Removes all events.
    open func clearEvents() {
        fatalError("Subclasses of EventsController must override clearEvents")
    }

    /// Replaces all events with `events` in a single update.
    @discardableResult
    open func replaceEvents(_ events: [CalendarEvent]) -> [String] {
        clearEvents()
        return addEvents(events)
    }

    /// Replaces `event` with `updatedEvent` (which inherits its id).
    open func updateEvent(event: CalendarEvent, updatedEvent: CalendarEvent) {
        fatalError("Subclasses of EventsController must override updateEvent")
    }

    /// Retrieves an event by id if it exists.
    open func byId(_ id: String) -> CalendarEvent? {
        fatalError("Subclasses of EventsController must override byId")
    }

    /// The events that occur during `dateTimeRange`. `multiDayRule` decides
    /// which events count as multi-day — pass the current view's
    /// `ViewConfiguration.multiDayRule`; an event overriding it takes
    /// precedence.
    open func eventsFromDateTimeRange(
        _ dateTimeRange: DateTimeRange,
        multiDayRule: MultiDayRule,
        includeMultiDayEvents: Bool = true,
        includeDayEvents: Bool = true
    ) -> [CalendarEvent] {
        fatalError("Subclasses of EventsController must override eventsFromDateTimeRange")
    }
}

// MARK: - DefaultEventsController

/// The default `EventsController`, backed by an in-memory store.
open class DefaultEventsController: EventsController {
    let eventStore = DefaultEventStore()

    public override init() { super.init() }

    open override var events: [CalendarEvent] { eventStore.events }

    @discardableResult
    open override func addEvent(_ event: CalendarEvent) -> String {
        let id = eventStore.addNewEvent(event)
        notifyListeners()
        return id
    }

    @discardableResult
    open override func addEvents(_ events: [CalendarEvent]) -> [String] {
        let ids = events.map { eventStore.addNewEvent($0) }
        notifyListeners()
        return ids
    }

    open override func removeEvent(_ event: CalendarEvent) {
        eventStore.removeById(event.id)
        notifyListeners()
    }

    open override func removeById(_ id: String) {
        eventStore.removeById(id)
        notifyListeners()
    }

    open override func removeWhere(_ test: (String, CalendarEvent) -> Bool) {
        eventStore.removeWhere(test)
        notifyListeners()
    }

    open override func clearEvents() {
        eventStore.clear()
        notifyListeners()
    }

    @discardableResult
    open override func replaceEvents(_ events: [CalendarEvent]) -> [String] {
        eventStore.clear()
        let ids = events.map { eventStore.addNewEvent($0) }
        notifyListeners()
        return ids
    }

    open override func updateEvent(event: CalendarEvent, updatedEvent: CalendarEvent) {
        updatedEvent.id = event.id
        eventStore.updateEvent(event, updatedEvent)
        notifyListeners()
    }

    open override func byId(_ id: String) -> CalendarEvent? { eventStore.byId(id) }

    open override func eventsFromDateTimeRange(
        _ dateTimeRange: DateTimeRange,
        multiDayRule: MultiDayRule,
        includeMultiDayEvents: Bool = true,
        includeDayEvents: Bool = true
    ) -> [CalendarEvent] {
        let events = eventStore.events

        return events.filter { event in
            let isMultiDay = event.spansMultipleDays(defaultRule: multiDayRule)
            if isMultiDay && !includeMultiDayEvents { return false }
            if !isMultiDay && !includeDayEvents { return false }

            // A zero-duration event sitting exactly on a day boundary has an
            // empty range; count it as touching so it still shows on that day.
            let touching = event.start == event.end && event.start.isStartOfDay
            if touching {
                return event.start >= dateTimeRange.start && event.start < dateTimeRange.end
            }
            return event.dateTimeRange.overlaps(dateTimeRange)
        }
    }
}

// MARK: - DefaultEventStore

/// In-memory event storage keyed by id, keeping insertion order.
///
/// The Dart store additionally maintains per-location day indexes to speed up
/// range lookups; this port keeps the interface and uses a linear scan, which
/// is plenty for the example-scale data the port runs with.
final class DefaultEventStore {
    private var eventsById: [String: CalendarEvent] = [:]
    private var order: [String] = []

    var events: [CalendarEvent] { order.compactMap { eventsById[$0] } }

    func addNewEvent(_ event: CalendarEvent) -> String {
        if eventsById[event.id] == nil { order.append(event.id) }
        eventsById[event.id] = event
        return event.id
    }

    func removeById(_ id: String) {
        eventsById.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    func removeWhere(_ test: (String, CalendarEvent) -> Bool) {
        for (id, event) in eventsById where test(id, event) {
            eventsById.removeValue(forKey: id)
        }
        order.removeAll { eventsById[$0] == nil }
    }

    func updateEvent(_ event: CalendarEvent, _ updatedEvent: CalendarEvent) {
        eventsById[event.id] = updatedEvent
    }

    func byId(_ id: String) -> CalendarEvent? { eventsById[id] }

    func clear() {
        eventsById.removeAll()
        order.removeAll()
    }
}
