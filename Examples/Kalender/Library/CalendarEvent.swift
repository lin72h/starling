// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/calendar_events/calendar_event.dart,
// multi_day_rule.dart, calendar_interaction.dart (EventInteraction)

import Foundation

// MARK: - EventInteraction

/// Controls whether an event can be modified by the user.
///
/// The Dart package splits this into reschedule/resize flags consumed by its
/// drag-and-drop machinery; this port keeps the type and the tap-relevant
/// surface.
public struct EventInteraction: Hashable {
    /// Whether the event responds to user modification at all.
    public let canModify: Bool

    public init(canModify: Bool = true) {
        self.canModify = canModify
    }

    public static func fromCanModify(_ canModify: Bool) -> EventInteraction {
        EventInteraction(canModify: canModify)
    }
}

// MARK: - MultiDayRule

/// Decides which events belong in the multi-day header lane rather than the
/// day timeline.
///
/// Ported from: multi_day_rule.dart
public enum MultiDayRule: Hashable {
    /// Multi-day when the event lasts at least `minimum` seconds. Measures
    /// elapsed time, not day boundaries.
    case minimumDuration(TimeInterval)

    /// Multi-day when the event covers part of more than one calendar day,
    /// so a short event crossing midnight counts.
    case calendarDays

    public func isMultiDay(_ event: CalendarEvent) -> Bool {
        switch self {
        case .minimumDuration(let minimum):
            return event.duration >= minimum
        case .calendarDays:
            let range = event.dateTimeRange
            if range.dates().count > 1 { return true }
            // `dates()` is half-open, so a full day (00:00 to the next 00:00)
            // counts as one day above. Keep it multi-day so all-day events
            // stay in the header.
            return range.start.isStartOfDay && range.end.isStartOfDay && range.end > range.start
        }
    }
}

/// The rule a calendar uses when nothing overrides it: 24 hours or longer.
public let defaultMultiDayRule = MultiDayRule.minimumDuration(24 * 60 * 60)

// MARK: - CalendarEvent

/// Base class for events displayed in the calendar.
///
/// Stores a date range, a unique `id`, and an `interaction` config. Subclass
/// to attach custom data (title, color, etc.), overriding `copyWith` so
/// copies keep the payload and `layoutEquals` if the payload affects
/// rendering.
open class CalendarEvent: Hashable {
    /// The start of the event.
    public let start: Date

    /// The end of the event.
    public let end: Date

    /// Controls whether the event can be modified.
    public let interaction: EventInteraction

    /// Unique identifier. Auto-generated if not provided.
    public internal(set) var id: String

    /// Overrides the calendar's rule for this event alone. Nil, the default,
    /// uses `ViewConfiguration.multiDayRule`.
    public let multiDayRule: MultiDayRule?

    public init(
        id: String? = nil,
        dateTimeRange: DateTimeRange,
        interaction: EventInteraction? = nil,
        multiDayRule: MultiDayRule? = nil
    ) {
        self.id = id ?? CalendarEvent.createUniqueId()
        self.start = dateTimeRange.start
        self.end = dateTimeRange.end
        self.interaction = interaction ?? .fromCanModify(true)
        self.multiDayRule = multiDayRule
    }

    static func createUniqueId() -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<10).map { _ in alphabet.randomElement()! })
    }

    /// The date range as a `DateTimeRange`.
    public var dateTimeRange: DateTimeRange { DateTimeRange(start: start, end: end) }

    /// Total duration in seconds.
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    /// Whether this event belongs in the multi-day header lane rather than
    /// the day timeline. Applies `multiDayRule` when set, else `defaultRule`
    /// (supplied by the calendar from its view configuration).
    public func spansMultipleDays(defaultRule: MultiDayRule) -> Bool {
        (multiDayRule ?? defaultRule).isMultiDay(self)
    }

    /// All dates this event spans.
    public func datesSpanned() -> [Date] { dateTimeRange.dates() }

    /// Returns a copy with the given fields replaced. The `id` is preserved
    /// so selection and layout lookups keep referencing the same logical
    /// event; `multiDayRule` is carried over and deliberately not a
    /// parameter (see the Dart original).
    open func copyWith(
        dateTimeRange: DateTimeRange? = nil,
        interaction: EventInteraction? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            dateTimeRange: dateTimeRange ?? self.dateTimeRange,
            interaction: interaction ?? self.interaction,
            multiDayRule: multiDayRule
        )
    }

    /// Compares layout-affecting properties. Override in subclasses that add
    /// properties affecting rendering.
    open func layoutEquals(_ other: CalendarEvent) -> Bool {
        id == other.id
            && start == other.start
            && end == other.end
            && interaction == other.interaction
            && multiDayRule == other.multiDayRule
    }

    public static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.layoutEquals(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(interaction)
        hasher.combine(multiDayRule)
    }
}
