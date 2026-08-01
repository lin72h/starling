// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/controllers/calendar_controller.dart,
// calendar_callbacks.dart, calendar_interaction.dart

import Flutter
import Foundation

// MARK: - CalendarController

/// Controls a single `CalendarView` and provides functions for navigating it.
///
/// The `CalendarView` attaches its `ViewController` by calling `attach`, and
/// detaches it with `detach`.
public final class CalendarController: ChangeNotifier {
    /// This controller's id.
    public let id: Int

    private var _viewController: ViewController?
    public var viewController: ViewController? { _viewController }
    public var isAttached: Bool { _viewController != nil }

    /// The `DateTimeRange` currently visible.
    public let visibleDateTimeRange = ValueNotifier<DateTimeRange?>(nil)

    /// The events currently visible.
    public let visibleEvents = ValueNotifier<Set<CalendarEvent>>([])

    /// The event currently focused (selected by tap).
    public let selectedEvent = ValueNotifier<CalendarEvent?>(nil)
    private var _selectedEventId: String?
    public var selectedEventId: String? { _selectedEventId }

    /// Whether the current focus came from within the package.
    private var _internalFocus = false
    public var internalFocus: Bool { _internalFocus }

    public override init() {
        id = Int(Date().timeIntervalSince1970 * 1000)
        super.init()
    }

    /// Place focus on an event. Leave `internal` false when calling from
    /// outside the package.
    public func selectEvent(_ event: CalendarEvent, internal isInternal: Bool = false) {
        _selectedEventId = event.id
        _internalFocus = isInternal
        selectedEvent.value = event
    }

    /// Deselect the event.
    public func deselectEvent() {
        _internalFocus = false
        _selectedEventId = nil
        selectedEvent.value = nil
    }

    public func isAttachedTo(_ viewController: ViewController) -> Bool {
        viewController === _viewController
    }

    /// Attach a `ViewController` to this controller.
    public func attach(_ viewController: ViewController) {
        if isAttached { detach() }
        _viewController = viewController
        visibleDateTimeRange.value = viewController.visibleDateTimeRange.value

        // Forward the view controller's visible range into this controller's
        // notifier. The subscription outlives detach harmlessly: it checks
        // that the source is still the attached controller before writing.
        viewController.visibleDateTimeRange.addListener { [weak self, weak viewController] in
            guard let self, let viewController, self._viewController === viewController else { return }
            self.visibleDateTimeRange.value = viewController.visibleDateTimeRange.value
        }
        viewController.visibleEvents.addListener { [weak self, weak viewController] in
            guard let self, let viewController, self._viewController === viewController else { return }
            self.visibleEvents.value = viewController.visibleEvents.value
        }

        notifyListeners()
    }

    /// Detach the current `ViewController`.
    public func detach() {
        _viewController = nil
    }

    // MARK: Navigation

    /// Jump to the given page.
    public func jumpToPage(_ page: Int) { viewController?.jumpToPage(page) }

    /// Jump to the page showing the given date.
    public func jumpToDate(_ date: Date) { viewController?.jumpToDate(date) }

    /// Move to the next page.
    public func animateToNextPage() { viewController?.animateToNextPage() }

    /// Move to the previous page.
    public func animateToPreviousPage() { viewController?.animateToPreviousPage() }

    /// Move to the page showing `date`.
    public func animateToDate(_ date: Date) { viewController?.animateToDate(date) }

    /// Move to `date`'s page and, where the view scrolls, its time of day.
    public func animateToDateTime(_ date: Date) { viewController?.animateToDateTime(date) }

    /// Move to the page (and scroll position) showing `event`.
    public func animateToEvent(_ event: CalendarEvent) { viewController?.animateToEvent(event) }
}

// MARK: - CalendarCallbacks

/// The callbacks the calendar surfaces to the app.
///
/// Ported from: calendar_callbacks.dart (the drag/resize callbacks of the
/// Dart package are omitted with the drag machinery).
public final class CalendarCallbacks {
    /// Called when an event tile is tapped.
    public let onEventTapped: ((_ event: CalendarEvent) -> Void)?

    /// Called before a tap-created event is added. Return the event (possibly
    /// transformed) to add it, or nil to cancel creation.
    public let onEventCreate: ((_ event: CalendarEvent) -> CalendarEvent?)?

    /// Called after a tap-created event was added to the `EventsController`.
    public let onEventCreated: ((_ event: CalendarEvent) -> Void)?

    /// Called when an empty area of the calendar is tapped, with the date
    /// (and, in multi-day bodies, time) of the tap.
    public let onTapped: ((_ date: Date) -> Void)?

    /// Called when the visible page changes.
    public let onPageChanged: ((_ visibleDateTimeRange: DateTimeRange) -> Void)?

    public init(
        onEventTapped: ((CalendarEvent) -> Void)? = nil,
        onEventCreate: ((CalendarEvent) -> CalendarEvent?)? = nil,
        onEventCreated: ((CalendarEvent) -> Void)? = nil,
        onTapped: ((Date) -> Void)? = nil,
        onPageChanged: ((DateTimeRange) -> Void)? = nil
    ) {
        self.onEventTapped = onEventTapped
        self.onEventCreate = onEventCreate
        self.onEventCreated = onEventCreated
        self.onTapped = onTapped
        self.onPageChanged = onPageChanged
    }
}

// MARK: - CalendarInteraction

/// Which user interactions the calendar allows.
///
/// Ported from: calendar_interaction.dart (resizing/rescheduling flags are
/// carried for API fidelity; the drag machinery itself is not in this port).
public struct CalendarInteraction {
    /// Whether tapping an empty slot creates a new event.
    public let allowEventCreation: Bool

    /// Whether events can be resized. (Reserved; no drag machinery yet.)
    public let allowResizing: Bool

    /// Whether events can be rescheduled. (Reserved; no drag machinery yet.)
    public let allowRescheduling: Bool

    public init(
        allowEventCreation: Bool = true,
        allowResizing: Bool = true,
        allowRescheduling: Bool = true
    ) {
        self.allowEventCreation = allowEventCreation
        self.allowResizing = allowResizing
        self.allowRescheduling = allowRescheduling
    }
}
