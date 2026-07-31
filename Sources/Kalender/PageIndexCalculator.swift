// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Ported from: kalender/lib/src/models/view_configurations/page_index_calculator.dart
// (Location-parameterised in Dart; this port computes in the local calendar.)

import Foundation

/// Calculates page indices and date ranges for paginated calendar views:
/// converting dates to page indices, the range a page displays, and the total
/// page count. Each view type has its own subclass.
open class PageIndexCalculator: Hashable {
    /// The overall date range this calculator operates within. Not a hard
    /// limit: week and month calculators widen it to whole weeks / months.
    public let dateTimeRange: DateTimeRange

    public init(dateTimeRange: DateTimeRange) {
        self.dateTimeRange = dateTimeRange
    }

    public static func singleDay(_ dateTimeRange: DateTimeRange) -> PageIndexCalculator {
        DayIndexCalculator(dateTimeRange: dateTimeRange)
    }

    public static func week(_ dateTimeRange: DateTimeRange, _ firstDayOfWeek: Int) -> PageIndexCalculator {
        WeekIndexCalculator(dateTimeRange: dateTimeRange, firstDayOfWeek: firstDayOfWeek, daysToDisplay: 7)
    }

    public static func workWeek(_ dateTimeRange: DateTimeRange) -> PageIndexCalculator {
        WeekIndexCalculator(dateTimeRange: dateTimeRange, firstDayOfWeek: KalWeekday.monday, daysToDisplay: 5)
    }

    public static func custom(_ dateTimeRange: DateTimeRange, _ numberOfDays: Int) -> PageIndexCalculator {
        CustomIndexCalculator(dateTimeRange: dateTimeRange, numberOfDays: numberOfDays)
    }

    public static func month(_ dateTimeRange: DateTimeRange, _ firstDayOfWeek: Int) -> PageIndexCalculator {
        MonthIndexCalculator(dateTimeRange: dateTimeRange, firstDayOfWeek: firstDayOfWeek)
    }

    /// The visible date range for the page at `index`.
    open func dateTimeRangeFromIndex(_ index: Int) -> DateTimeRange {
        fatalError("Subclasses must override dateTimeRangeFromIndex")
    }

    /// The page index showing `date`, clamped to the valid range.
    open func indexFromDate(_ date: Date) -> Int {
        fatalError("Subclasses must override indexFromDate")
    }

    /// The number of pages (a count; the last valid index is count - 1).
    open func numberOfPages() -> Int {
        fatalError("Subclasses must override numberOfPages")
    }

    /// The `dateTimeRange` widened to this calculator's page unit.
    open func internalRange() -> DateTimeRange {
        fatalError("Subclasses must override internalRange")
    }

    /// The range displayed for the page containing `date`.
    public func dateTimeRangeFromDate(_ date: Date) -> DateTimeRange {
        dateTimeRangeFromIndex(indexFromDate(date))
    }

    open func isEqual(to other: PageIndexCalculator) -> Bool {
        type(of: self) == type(of: other) && dateTimeRange == other.dateTimeRange
    }

    public static func == (lhs: PageIndexCalculator, rhs: PageIndexCalculator) -> Bool {
        lhs.isEqual(to: rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: self)))
        hasher.combine(dateTimeRange)
    }
}

/// The default four-year navigation range, `[now - 2 years, now + 2 years)`.
public func kDefaultRange() -> DateTimeRange {
    let now = Date()
    let start = kalCalendar.date(from: DateComponents(year: now.kalYear - 2, month: 1, day: 1))!
    let end = kalCalendar.date(from: DateComponents(year: now.kalYear + 2, month: 1, day: 1))!
    return DateTimeRange(start: start, end: end)
}

// MARK: - DayIndexCalculator

/// One day per page.
public final class DayIndexCalculator: PageIndexCalculator {
    public override func dateTimeRangeFromIndex(_ index: Int) -> DateTimeRange {
        let start = internalRange().start.addingDays(index)
        return DateTimeRange(start: start, end: start.addingDays(1))
    }

    public override func indexFromDate(_ date: Date) -> Int {
        let days = date.startOfDay.daysSince(internalRange().start)
        let pageCount = numberOfPages()
        return pageCount == 0 ? 0 : min(max(days, 0), pageCount - 1)
    }

    public override func numberOfPages() -> Int {
        let range = internalRange()
        return range.end.daysSince(range.start)
    }

    public override func internalRange() -> DateTimeRange {
        let start = dateTimeRange.start.startOfDay
        let end = dateTimeRange.end.isStartOfDay ? dateTimeRange.end : dateTimeRange.end.endOfDay
        return DateTimeRange(start: start, end: end)
    }
}

// MARK: - WeekIndexCalculator

/// One week (or work week) per page.
public final class WeekIndexCalculator: PageIndexCalculator {
    public let firstDayOfWeek: Int
    public let daysToDisplay: Int

    public init(dateTimeRange: DateTimeRange, firstDayOfWeek: Int, daysToDisplay: Int) {
        self.firstDayOfWeek = firstDayOfWeek
        self.daysToDisplay = daysToDisplay
        super.init(dateTimeRange: dateTimeRange)
    }

    public override func dateTimeRangeFromIndex(_ index: Int) -> DateTimeRange {
        let start = internalRange().start.addingDays(index * KalWeekday.daysPerWeek)
        return DateTimeRange(start: start, end: start.addingDays(daysToDisplay))
    }

    public override func indexFromDate(_ date: Date) -> Int {
        let startOfWeek = date.startOfDay.startOfWeek(firstDayOfWeek: firstDayOfWeek)
        let range = internalRange()
        if startOfWeek <= range.start { return 0 }
        let index = startOfWeek.daysSince(range.start) / KalWeekday.daysPerWeek
        return min(max(index, 0), numberOfPages() - 1)
    }

    public override func numberOfPages() -> Int {
        let range = internalRange()
        return range.end.daysSince(range.start) / KalWeekday.daysPerWeek
    }

    public override func internalRange() -> DateTimeRange {
        DateTimeRange(
            start: dateTimeRange.start.startOfWeek(firstDayOfWeek: firstDayOfWeek),
            end: dateTimeRange.end.endOfWeek(firstDayOfWeek: firstDayOfWeek)
        )
    }

    public override func isEqual(to other: PageIndexCalculator) -> Bool {
        guard let other = other as? WeekIndexCalculator else { return false }
        return dateTimeRange == other.dateTimeRange
            && firstDayOfWeek == other.firstDayOfWeek
            && daysToDisplay == other.daysToDisplay
    }
}

// MARK: - CustomIndexCalculator

/// A fixed number of days per page.
public final class CustomIndexCalculator: PageIndexCalculator {
    public let numberOfDays: Int

    public init(dateTimeRange: DateTimeRange, numberOfDays: Int) {
        self.numberOfDays = numberOfDays
        super.init(dateTimeRange: dateTimeRange)
    }

    public override func dateTimeRangeFromIndex(_ index: Int) -> DateTimeRange {
        let start = internalRange().start.addingDays(index * numberOfDays)
        return DateTimeRange(start: start, end: start.addingDays(numberOfDays))
    }

    public override func indexFromDate(_ date: Date) -> Int {
        let index = date.startOfDay.daysSince(internalRange().start) / numberOfDays
        return min(max(index, 0), numberOfPages() - 1)
    }

    public override func numberOfPages() -> Int {
        let range = internalRange()
        return range.end.daysSince(range.start) / numberOfDays
    }

    public override func internalRange() -> DateTimeRange {
        let start = dateTimeRange.start.startOfDay
        let end = dateTimeRange.end.isStartOfDay ? dateTimeRange.end : dateTimeRange.end.endOfDay
        let daysInRange = end.daysSince(start)
        let extraDays = positiveMod(daysInRange, numberOfDays)
        if extraDays == 0 {
            return DateTimeRange(start: start, end: end)
        }
        return DateTimeRange(start: start, end: end.addingDays(numberOfDays - extraDays))
    }

    public override func isEqual(to other: PageIndexCalculator) -> Bool {
        guard let other = other as? CustomIndexCalculator else { return false }
        return dateTimeRange == other.dateTimeRange && numberOfDays == other.numberOfDays
    }
}

// MARK: - MonthIndexCalculator

/// One month per page: a grid of whole weeks around the focused month.
public final class MonthIndexCalculator: PageIndexCalculator {
    /// The default number of week rows on a month page.
    public static let numberOfRows = 5

    public let firstDayOfWeek: Int

    public init(dateTimeRange: DateTimeRange, firstDayOfWeek: Int) {
        self.firstDayOfWeek = firstDayOfWeek
        super.init(dateTimeRange: dateTimeRange)
    }

    /// The first day of the focused month for the page at `index`. The grid
    /// also renders leading/trailing days of the adjacent months.
    public func monthStartFromIndex(_ index: Int) -> Date {
        internalRange().start.addingMonths(index)
    }

    public override func dateTimeRangeFromIndex(_ index: Int) -> DateTimeRange {
        let startOfMonth = monthStartFromIndex(index)

        var start = startOfMonth.startOfWeek(firstDayOfWeek: firstDayOfWeek)
        if start > startOfMonth { start = start.addingDays(-7) }

        var end = start.addingDays(KalWeekday.daysPerWeek * MonthIndexCalculator.numberOfRows)
        if end < startOfMonth.endOfMonth {
            end = start.addingDays(KalWeekday.daysPerWeek * (MonthIndexCalculator.numberOfRows + 1))
        }

        return DateTimeRange(start: start, end: end)
    }

    public override func indexFromDate(_ date: Date) -> Int {
        let range = DateTimeRange(start: internalRange().start, end: date.startOfDay)
        return min(max(range.monthDifference, 0), numberOfPages() - 1)
    }

    /// The number of week rows on the page showing `range`.
    public func numberOfRowsForRange(_ range: DateTimeRange) -> Int {
        range.dates().count / KalWeekday.daysPerWeek
    }

    public override func numberOfPages() -> Int {
        internalRange().monthDifference
    }

    public override func internalRange() -> DateTimeRange {
        let start = dateTimeRange.start.startOfMonth
        let end = dateTimeRange.end == dateTimeRange.end.startOfMonth
            ? dateTimeRange.end
            : dateTimeRange.end.endOfMonth
        return DateTimeRange(start: start, end: end)
    }

    public override func isEqual(to other: PageIndexCalculator) -> Bool {
        guard let other = other as? MonthIndexCalculator else { return false }
        return dateTimeRange == other.dateTimeRange && firstDayOfWeek == other.firstDayOfWeek
    }
}
