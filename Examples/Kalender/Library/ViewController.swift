// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/controllers/view_controller.dart,
// view_controllers/multi_day_view_controller.dart, month_view_controller.dart
//
// The Dart controllers drive a PageView through a PageController; this
// framework has no PageView, so paging is a `currentPage` notifier the body
// rebuilds from, and the animate* navigation functions jump. The vertical
// scroll of the multi-day body keeps a real ScrollController.

import Flutter
import Foundation

// MARK: - ViewController

/// Controls a single calendar view. Created by the `CalendarView` from its
/// `ViewConfiguration` and attached to the `CalendarController`.
open class ViewController {
    /// The `DateTimeRange` currently visible.
    public let visibleDateTimeRange: ValueNotifier<DateTimeRange?>

    /// The events currently visible.
    public let visibleEvents: ValueNotifier<Set<CalendarEvent>>

    /// The page currently displayed. Kalender widgets rebuild from this
    /// where the Dart package pages a PageView.
    public let currentPage: ValueNotifier<Int>

    public init(
        visibleDateTimeRange: ValueNotifier<DateTimeRange?>,
        visibleEvents: ValueNotifier<Set<CalendarEvent>>,
        initialPage: Int
    ) {
        self.visibleDateTimeRange = visibleDateTimeRange
        self.visibleEvents = visibleEvents
        self.currentPage = ValueNotifier<Int>(initialPage)
    }

    open var viewConfiguration: ViewConfiguration {
        fatalError("Subclasses must override viewConfiguration")
    }

    open var pageIndexCalculator: PageIndexCalculator { viewConfiguration.pageIndexCalculator }

    /// The number of pages the view can display.
    public var numberOfPages: Int { pageIndexCalculator.numberOfPages() }

    /// Jump to the given page.
    open func jumpToPage(_ page: Int) {
        let clamped = min(max(page, 0), max(numberOfPages - 1, 0))
        currentPage.value = clamped
        visibleDateTimeRange.value = pageIndexCalculator.dateTimeRangeFromIndex(clamped)
    }

    /// Jump to the page showing the given date.
    open func jumpToDate(_ date: Date) {
        jumpToPage(pageIndexCalculator.indexFromDate(date))
    }

    /// Move to the next page. (Named for the Dart API; this port jumps.)
    open func animateToNextPage() { jumpToPage(currentPage.value + 1) }

    /// Move to the previous page.
    open func animateToPreviousPage() { jumpToPage(currentPage.value - 1) }

    /// Move to the page showing `date`.
    open func animateToDate(_ date: Date) { jumpToDate(date) }

    /// Move to `date`'s page and, where the view scrolls, its time of day.
    open func animateToDateTime(_ date: Date) { jumpToDate(date) }

    /// Move to the page (and scroll position) showing `event`.
    open func animateToEvent(_ event: CalendarEvent) { animateToDateTime(event.start) }

    open func dispose() {}
}

// MARK: - MultiDayViewController

/// The view controller for day/week/work-week/custom views.
public final class MultiDayViewController: ViewController {
    private let _viewConfiguration: MultiDayViewConfiguration
    public override var viewConfiguration: ViewConfiguration { _viewConfiguration }
    public var multiDayViewConfiguration: MultiDayViewConfiguration { _viewConfiguration }

    /// The initial page of the view.
    public let initialPage: Int

    /// The vertical scroll controller of the body.
    public let scrollController: ScrollController

    /// The zoom level (pixels per minute).
    public let heightPerMinute: ValueNotifier<Double>

    public init(
        viewConfiguration: MultiDayViewConfiguration,
        visibleDateTimeRange: ValueNotifier<DateTimeRange?>,
        visibleEvents: ValueNotifier<Set<CalendarEvent>>,
        initialDate: Date? = nil
    ) {
        self._viewConfiguration = viewConfiguration
        let calculator = viewConfiguration.pageIndexCalculator
        let initialPage = calculator.indexFromDate(initialDate ?? Date())
        self.initialPage = initialPage

        self.heightPerMinute = ValueNotifier<Double>(viewConfiguration.initialHeightPerMinute)

        // Align the top of the viewport with the configured initial
        // time-of-day.
        let now = Date()
        let topOfDay = viewConfiguration.initialTimeOfDay.toDateTime(now)
        let dayStart = viewConfiguration.timeOfDayRange.start.toDateTime(now)
        let scrollOffset = topOfDay.timeIntervalSince(dayStart) / 60.0
            * viewConfiguration.initialHeightPerMinute
        self.scrollController = ScrollController(initialScrollOffset: max(scrollOffset, 0))

        super.init(
            visibleDateTimeRange: visibleDateTimeRange,
            visibleEvents: visibleEvents,
            initialPage: initialPage
        )

        visibleDateTimeRange.value = calculator.dateTimeRangeFromIndex(initialPage)
        visibleEvents.value = []
    }

    public override func animateToDateTime(_ date: Date) {
        jumpToDate(date)

        // Scroll so the given time of day sits at the top of the viewport.
        let startOfDay = _viewConfiguration.timeOfDayRange.start.toDateTime(date)
        let timeOffset = date.timeIntervalSince(startOfDay) / 60.0 * heightPerMinute.value
        if scrollController.hasClients {
            scrollController.jumpTo(max(timeOffset, 0))
        }
    }

    public override func dispose() {
        scrollController.dispose()
    }
}

// MARK: - MonthViewController

/// The view controller for the month view.
public final class MonthViewController: ViewController {
    private let _viewConfiguration: MonthViewConfiguration
    public override var viewConfiguration: ViewConfiguration { _viewConfiguration }
    public var monthViewConfiguration: MonthViewConfiguration { _viewConfiguration }

    public init(
        viewConfiguration: MonthViewConfiguration,
        visibleDateTimeRange: ValueNotifier<DateTimeRange?>,
        visibleEvents: ValueNotifier<Set<CalendarEvent>>,
        initialDate: Date? = nil
    ) {
        self._viewConfiguration = viewConfiguration
        let calculator = viewConfiguration.pageIndexCalculator
        let initialPage = calculator.indexFromDate(initialDate ?? Date())

        super.init(
            visibleDateTimeRange: visibleDateTimeRange,
            visibleEvents: visibleEvents,
            initialPage: initialPage
        )

        visibleDateTimeRange.value = calculator.dateTimeRangeFromIndex(initialPage)
        visibleEvents.value = []
    }
}
