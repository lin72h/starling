// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The BLoC of the kalender port, in the shape of the desktop's
// FileExplorerBloc: one value-type state struct as the single source of
// truth, one event enum as the only way the UI talks to it, and an
// @Observable bloc whose `add(_:)` dispatches to private handlers.
//
// This replaces the controller/callback surface the Dart package has
// (EventsController, CalendarController, CalendarCallbacks, per-view
// ViewControllers): event storage, selection, paging, view switching and
// tap-to-create all live here now.

import Flutter
import Foundation
import Observation

// MARK: - Calendar State

/// The single source of truth for the calendar UI.
public struct CalendarState {
    // Views
    /// The views the calendar can display (e.g. day, week, month).
    public var viewConfigurations: [ViewConfiguration]
    /// The index of the view currently displayed.
    public var selectedViewIndex: Int

    // Events
    /// Every calendar event, in insertion order.
    public var events: [CalendarEvent]
    /// The id of the event selected by tap, if any.
    public var selectedEventId: String? = nil

    // Navigation
    /// The page the current view displays.
    public var currentPage: Int = 0

    // Body
    /// The zoom level of multi-day bodies (pixels per minute). Preserved
    /// across view switches, kalender's ZoomTransition.preserve.
    public var heightPerMinute: Double = defaultHeightPerMinute

    // Options
    /// Whether tapping an empty slot creates a new event.
    public var allowEventCreation: Bool = true

    // Computed
    public var viewConfiguration: ViewConfiguration { viewConfigurations[selectedViewIndex] }

    /// The date range the current page displays.
    public var visibleDateTimeRange: DateTimeRange {
        viewConfiguration.pageIndexCalculator.dateTimeRangeFromIndex(currentPage)
    }

    /// The event selected by tap, if any.
    public var selectedEvent: CalendarEvent? {
        guard let id = selectedEventId else { return nil }
        return events.first { $0.id == id }
    }

    /// The events that occur during `dateTimeRange`, filtered by the current
    /// view's multi-day rule (an event overriding it takes precedence).
    public func eventsIn(
        _ dateTimeRange: DateTimeRange,
        includeMultiDayEvents: Bool = true,
        includeDayEvents: Bool = true
    ) -> [CalendarEvent] {
        let rule = viewConfiguration.multiDayRule
        return events.filter { event in
            let isMultiDay = event.spansMultipleDays(defaultRule: rule)
            if isMultiDay && !includeMultiDayEvents { return false }
            if !isMultiDay && !includeDayEvents { return false }

            // A zero-duration event sitting exactly on a day boundary has an
            // empty range; count it as touching so it still shows that day.
            if event.start == event.end && event.start.isStartOfDay {
                return dateTimeRange.contains(event.start)
            }
            return event.dateTimeRange.overlaps(dateTimeRange)
        }
    }
}

// MARK: - Calendar Events

extension CalendarBloc {
    /// The events the UI dispatches — `CalendarBloc.Event`, nested because
    /// the top-level name `CalendarEvent` belongs to the model type.
    public enum Event {
        // Event store
        case addEvent(CalendarEvent)
        case addEvents([CalendarEvent])
        case updateEvent(id: String, dateTimeRange: DateTimeRange)
        case removeEvent(id: String)
        case clearEvents

        // Selection
        case selectEvent(id: String)
        case deselectEvent

        // Navigation
        case nextPage
        case previousPage
        case jumpToDate(Date)
        case jumpToToday

        // Views
        case switchView(index: Int)

        // Taps on empty calendar area: deselect, and create when allowed —
        // a timed event in a multi-day body slot, an all-day event on a
        // month day.
        case tapTimeSlot(Date)
        case tapDay(Date)
    }
}

// MARK: - Calendar BLoC

@Observable
open class CalendarBloc: @unchecked Sendable {

    /// The single source of truth for the UI.
    public private(set) var state: CalendarState

    /// The vertical scroll controller shared by the multi-day bodies. Owned
    /// here so the scroll position survives page turns and view switches
    /// (kalender's ScrollTransition.preserve). Not part of `state`: it is a
    /// live UI object, not a value.
    @ObservationIgnored public let scrollController: ScrollController

    public init(
        viewConfigurations: [ViewConfiguration],
        initialViewIndex: Int = 0,
        events: [CalendarEvent] = [],
        allowEventCreation: Bool = true
    ) {
        precondition(!viewConfigurations.isEmpty, "CalendarBloc needs at least one view configuration")
        let index = min(max(initialViewIndex, 0), viewConfigurations.count - 1)
        var state = CalendarState(
            viewConfigurations: viewConfigurations,
            selectedViewIndex: index,
            events: events
        )
        state.allowEventCreation = allowEventCreation

        let configuration = viewConfigurations[index]
        state.currentPage = configuration.pageIndexCalculator
            .indexFromDate(configuration.initialDateTime ?? Date())

        // The initial zoom and scroll offset come from the first multi-day
        // view in the lineup.
        let multiDay = viewConfigurations.compactMap { $0 as? MultiDayViewConfiguration }.first
        var scrollOffset = 0.0
        if let multiDay {
            state.heightPerMinute = multiDay.initialHeightPerMinute
            let now = Date()
            let topOfDay = multiDay.initialTimeOfDay.toDateTime(now)
            let dayStart = multiDay.timeOfDayRange.start.toDateTime(now)
            scrollOffset = max(topOfDay.timeIntervalSince(dayStart) / 60.0 * state.heightPerMinute, 0)
        }

        self.state = state
        self.scrollController = ScrollController(initialScrollOffset: scrollOffset)
    }

    /// The event a tap on empty calendar area creates. Override to attach
    /// app data (a title, a color) to created events — the template-method
    /// replacement for the Dart package's onEventCreate callback.
    open func makeEvent(for dateTimeRange: DateTimeRange) -> CalendarEvent {
        CalendarEvent(dateTimeRange: dateTimeRange)
    }

    /// The only way the UI talks to the BLoC.
    public func add(_ event: Event) {
        switch event {
        case .addEvent(let event):
            state.events.append(event)
        case .addEvents(let events):
            state.events.append(contentsOf: events)
        case .updateEvent(let id, let dateTimeRange):
            _updateEvent(id: id, dateTimeRange: dateTimeRange)
        case .removeEvent(let id):
            state.events.removeAll { $0.id == id }
            if state.selectedEventId == id { state.selectedEventId = nil }
        case .clearEvents:
            state.events = []
            state.selectedEventId = nil
        case .selectEvent(let id):
            state.selectedEventId = id
        case .deselectEvent:
            state.selectedEventId = nil
        case .nextPage:
            _jumpToPage(state.currentPage + 1)
        case .previousPage:
            _jumpToPage(state.currentPage - 1)
        case .jumpToDate(let date):
            _jumpToPage(state.viewConfiguration.pageIndexCalculator.indexFromDate(date))
        case .jumpToToday:
            _jumpToPage(state.viewConfiguration.pageIndexCalculator.indexFromDate(Date()))
        case .switchView(let index):
            _switchView(index)
        case .tapTimeSlot(let date):
            _tapEmpty(DateTimeRange(start: date, end: date.addingTimeInterval(defaultNewEventDuration)))
        case .tapDay(let date):
            _tapEmpty(DateTimeRange(start: date.startOfDay, end: date.endOfDay))
        }
    }

    // MARK: - Event Handlers

    private func _updateEvent(id: String, dateTimeRange: DateTimeRange) {
        guard let index = state.events.firstIndex(where: { $0.id == id }) else { return }
        state.events[index] = state.events[index].copyWith(dateTimeRange: dateTimeRange)
    }

    private func _jumpToPage(_ page: Int) {
        let pageCount = state.viewConfiguration.pageIndexCalculator.numberOfPages()
        state.currentPage = min(max(page, 0), max(pageCount - 1, 0))
    }

    /// Switch views, carrying the focused date across (kalender's carryFocus
    /// default): a month view's range starts in the previous month's trailing
    /// week, so it contributes its dominant month rather than its range start.
    private func _switchView(_ index: Int) {
        guard state.viewConfigurations.indices.contains(index),
              index != state.selectedViewIndex else { return }

        let outgoing = state.viewConfiguration
        let range = state.visibleDateTimeRange
        let focusedDate = outgoing is MonthViewConfiguration ? range.dominantMonthDate : range.start

        state.selectedViewIndex = index
        let incoming = state.viewConfiguration
        state.currentPage = incoming.pageIndexCalculator
            .indexFromDate(incoming.initialDateTime ?? focusedDate)
    }

    private func _tapEmpty(_ dateTimeRange: DateTimeRange) {
        state.selectedEventId = nil
        guard state.allowEventCreation else { return }
        state.events.append(makeEvent(for: dateTimeRange))
    }
}
