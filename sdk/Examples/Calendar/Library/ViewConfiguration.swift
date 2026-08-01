// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/view_configurations/view_configuration.dart,
// multi_day_view_configuration.dart, month_view_configuration.dart
//
// Omitted relative to Dart: the view-transition policies (dateTransition /
// scrollResolver / zoomResolver — this port carries the focused date across
// view switches, kalender's carryFocus default), the freeScroll type (needs
// fractional-viewport paging), and nowCallback/locale/location.

import Foundation

// MARK: - Defaults

public let defaultTileHeight = 24.0
public let defaultNewEventDuration: TimeInterval = 30 * 60
public let defaultShowMultiDayEvents = false
public let defaultFirstDayOfWeek = Weekday.monday
public let defaultShowEventTiles = true
public let defaultInitialTimeOfDay = TimeOfDay(hour: 0, minute: 0)
public let defaultHeightPerMinute = 0.7

// MARK: - ViewConfiguration

/// The base class for all view configurations, which configure the view of
/// the calendar (day/week/month...).
open class ViewConfiguration: Hashable {
    /// The name of the configuration (also the label a view switcher shows).
    public let name: String

    /// Decides which events belong in the multi-day header rather than the
    /// day timeline. An individual event can opt out with
    /// `CalendarEvent.multiDayRule`.
    public let multiDayRule: MultiDayRule

    /// The date the view starts on. Nil uses "now" (or the focused date
    /// carried over from the previous view on a switch).
    public let initialDateTime: Date?

    /// The functions for navigating between pages.
    public let pageIndexCalculator: PageIndexCalculator

    /// The overall range the calendar can display.
    public var dateTimeRange: DateTimeRange { pageIndexCalculator.dateTimeRange }

    public init(
        name: String,
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        pageIndexCalculator: PageIndexCalculator
    ) {
        self.name = name
        self.initialDateTime = initialDateTime
        self.multiDayRule = multiDayRule
        self.pageIndexCalculator = pageIndexCalculator
    }

    open func isEqual(to other: ViewConfiguration) -> Bool {
        type(of: self) == type(of: other)
            && name == other.name
            && initialDateTime == other.initialDateTime
            && multiDayRule == other.multiDayRule
            && pageIndexCalculator == other.pageIndexCalculator
    }

    public static func == (lhs: ViewConfiguration, rhs: ViewConfiguration) -> Bool {
        lhs.isEqual(to: rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(initialDateTime)
        hasher.combine(multiDayRule)
        hasher.combine(pageIndexCalculator)
    }
}

// MARK: - MultiDayViewConfiguration

public enum MultiDayViewType: Hashable {
    case singleDay
    case week
    case workWeek
    case custom
}

/// The configuration used by the `MultiDayBody` and `MultiDayHeader`.
public final class MultiDayViewConfiguration: ViewConfiguration {
    public let type: MultiDayViewType

    /// The slice of the day the body displays.
    public let timeOfDayRange: TimeOfDayRange

    /// The first day of the week: `Weekday.monday`, `.saturday` or `.sunday`.
    public let firstDayOfWeek: Int

    /// The number of days a page displays.
    public let numberOfDays: Int

    /// The time of day the body is initially scrolled to.
    public let initialTimeOfDay: TimeOfDay

    /// The initial zoom level (pixels per minute).
    public let initialHeightPerMinute: Double

    init(
        name: String,
        initialDateTime: Date?,
        multiDayRule: MultiDayRule,
        timeOfDayRange: TimeOfDayRange,
        numberOfDays: Int,
        firstDayOfWeek: Int,
        pageIndexCalculator: PageIndexCalculator,
        type: MultiDayViewType,
        initialTimeOfDay: TimeOfDay,
        initialHeightPerMinute: Double
    ) {
        assert(
            firstDayOfWeek >= 1 && firstDayOfWeek <= 7,
            "First day of week must be a valid week day number (use Weekday.monday, etc.)"
        )
        self.type = type
        self.timeOfDayRange = timeOfDayRange
        self.firstDayOfWeek = firstDayOfWeek
        self.numberOfDays = numberOfDays
        self.initialTimeOfDay = initialTimeOfDay
        self.initialHeightPerMinute = initialHeightPerMinute
        super.init(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            pageIndexCalculator: pageIndexCalculator
        )
    }

    /// A single-day view.
    public static func singleDay(
        name: String = "Day",
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        timeOfDayRange: TimeOfDayRange? = nil,
        firstDayOfWeek: Int = defaultFirstDayOfWeek,
        initialTimeOfDay: TimeOfDay = defaultInitialTimeOfDay,
        initialHeightPerMinute: Double = defaultHeightPerMinute
    ) -> MultiDayViewConfiguration {
        MultiDayViewConfiguration(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            timeOfDayRange: timeOfDayRange ?? .allDay(),
            numberOfDays: 1,
            firstDayOfWeek: firstDayOfWeek,
            pageIndexCalculator: .singleDay(displayRange ?? kDefaultRange()),
            type: .singleDay,
            initialTimeOfDay: initialTimeOfDay,
            initialHeightPerMinute: initialHeightPerMinute
        )
    }

    /// A week view.
    public static func week(
        name: String = "Week",
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        timeOfDayRange: TimeOfDayRange? = nil,
        firstDayOfWeek: Int = defaultFirstDayOfWeek,
        initialTimeOfDay: TimeOfDay = defaultInitialTimeOfDay,
        initialHeightPerMinute: Double = defaultHeightPerMinute
    ) -> MultiDayViewConfiguration {
        MultiDayViewConfiguration(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            timeOfDayRange: timeOfDayRange ?? .allDay(),
            numberOfDays: 7,
            firstDayOfWeek: firstDayOfWeek,
            pageIndexCalculator: .week(displayRange ?? kDefaultRange(), firstDayOfWeek),
            type: .week,
            initialTimeOfDay: initialTimeOfDay,
            initialHeightPerMinute: initialHeightPerMinute
        )
    }

    /// A work-week view (Monday to Friday).
    public static func workWeek(
        name: String = "Work Week",
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        timeOfDayRange: TimeOfDayRange? = nil,
        initialTimeOfDay: TimeOfDay = defaultInitialTimeOfDay,
        initialHeightPerMinute: Double = defaultHeightPerMinute
    ) -> MultiDayViewConfiguration {
        MultiDayViewConfiguration(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            timeOfDayRange: timeOfDayRange ?? .allDay(),
            numberOfDays: 5,
            firstDayOfWeek: Weekday.monday,
            pageIndexCalculator: .workWeek(displayRange ?? kDefaultRange()),
            type: .workWeek,
            initialTimeOfDay: initialTimeOfDay,
            initialHeightPerMinute: initialHeightPerMinute
        )
    }

    /// A view showing a custom number of days per page.
    public static func custom(
        name: String = "Custom",
        numberOfDays: Int,
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        timeOfDayRange: TimeOfDayRange? = nil,
        firstDayOfWeek: Int = defaultFirstDayOfWeek,
        initialTimeOfDay: TimeOfDay = defaultInitialTimeOfDay,
        initialHeightPerMinute: Double = defaultHeightPerMinute
    ) -> MultiDayViewConfiguration {
        MultiDayViewConfiguration(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            timeOfDayRange: timeOfDayRange ?? .allDay(),
            numberOfDays: numberOfDays,
            firstDayOfWeek: firstDayOfWeek,
            pageIndexCalculator: .custom(displayRange ?? kDefaultRange(), numberOfDays),
            type: .custom,
            initialTimeOfDay: initialTimeOfDay,
            initialHeightPerMinute: initialHeightPerMinute
        )
    }

    public override func isEqual(to other: ViewConfiguration) -> Bool {
        guard let other = other as? MultiDayViewConfiguration else { return false }
        return super.isEqual(to: other)
            && type == other.type
            && timeOfDayRange == other.timeOfDayRange
            && firstDayOfWeek == other.firstDayOfWeek
            && numberOfDays == other.numberOfDays
            && initialTimeOfDay == other.initialTimeOfDay
            && initialHeightPerMinute == other.initialHeightPerMinute
    }
}

// MARK: - MonthViewConfiguration

/// The configuration used by the `MonthBody` and `MonthHeader`.
public final class MonthViewConfiguration: ViewConfiguration {
    public let firstDayOfWeek: Int

    public init(
        name: String = "Month",
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        firstDayOfWeek: Int = defaultFirstDayOfWeek
    ) {
        self.firstDayOfWeek = firstDayOfWeek
        super.init(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            pageIndexCalculator: .month(displayRange ?? kDefaultRange(), firstDayOfWeek)
        )
    }

    /// kalender's `MonthViewConfiguration.singleMonth` constructor.
    public static func singleMonth(
        name: String = "Month",
        initialDateTime: Date? = nil,
        multiDayRule: MultiDayRule = defaultMultiDayRule,
        displayRange: DateTimeRange? = nil,
        firstDayOfWeek: Int = defaultFirstDayOfWeek
    ) -> MonthViewConfiguration {
        MonthViewConfiguration(
            name: name,
            initialDateTime: initialDateTime,
            multiDayRule: multiDayRule,
            displayRange: displayRange,
            firstDayOfWeek: firstDayOfWeek
        )
    }

    public override func isEqual(to other: ViewConfiguration) -> Bool {
        guard let other = other as? MonthViewConfiguration else { return false }
        return super.isEqual(to: other) && firstDayOfWeek == other.firstDayOfWeek
    }
}

// MARK: - Body / header configurations

/// The configuration used by the `MultiDayBody`.
public struct MultiDayBodyConfiguration {
    /// Whether to show multi-day events in the body (they normally live in
    /// the header lane).
    public let showMultiDayEvents: Bool

    /// The horizontal padding between events and the edge of the day column.
    public let horizontalPadding: EdgeInsetsLite

    /// The layout strategy used to lay out overlapping events.
    public let eventLayoutStrategy: EventLayoutStrategy

    /// A floor on rendered tile height, so very short events stay visible.
    public let minimumTileHeight: Double?

    /// New events created by tapping snap to this many minutes.
    public let snapIntervalMinutes: Int

    public init(
        showMultiDayEvents: Bool = defaultShowMultiDayEvents,
        horizontalPadding: EdgeInsetsLite = EdgeInsetsLite(left: 0, right: 3),
        eventLayoutStrategy: @escaping EventLayoutStrategy = sideBySideLayoutStrategy,
        minimumTileHeight: Double? = nil,
        snapIntervalMinutes: Int = 15
    ) {
        self.showMultiDayEvents = showMultiDayEvents
        self.horizontalPadding = horizontalPadding
        self.eventLayoutStrategy = eventLayoutStrategy
        self.minimumTileHeight = minimumTileHeight
        self.snapIntervalMinutes = snapIntervalMinutes
    }
}

/// The configuration used by the `MultiDayHeader` and `MonthBody`.
public struct MultiDayHeaderConfiguration {
    /// The height of a multi-day tile row.
    public let tileHeight: Double

    /// Whether to show event tiles at all.
    public let showTiles: Bool

    /// The maximum number of tile rows shown vertically; nil means no limit.
    public let maximumNumberOfVerticalEvents: Int?

    /// Whether single-day events also render in this horizontal lane.
    public let allowSingleDayEvents: Bool

    public init(
        tileHeight: Double = defaultTileHeight,
        showTiles: Bool = defaultShowEventTiles,
        maximumNumberOfVerticalEvents: Int? = nil,
        allowSingleDayEvents: Bool = false
    ) {
        self.tileHeight = tileHeight
        self.showTiles = showTiles
        self.maximumNumberOfVerticalEvents = maximumNumberOfVerticalEvents
        self.allowSingleDayEvents = allowSingleDayEvents
    }
}

/// A plain-value insets pair (the framework's `EdgeInsets` is geometry-aware;
/// the layout math here only needs numbers).
public struct EdgeInsetsLite: Hashable {
    public let left: Double
    public let right: Double

    public init(left: Double = 0, right: Double = 0) {
        self.left = left
        self.right = right
    }

    public var horizontal: Double { left + right }
}
