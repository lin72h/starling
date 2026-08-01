// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The date model of the kalender port: `DateTimeRange`, `TimeOfDay`,
// `TimeOfDayRange` and the calendar math kalender defines as extensions on
// `DateTime` / `DateTimeRange`.
//
// The Dart package routes every calculation through `InternalDateTime`, its
// timezone-normalised wrapper around the `timezone` package. This port has no
// timezone database, so it computes in the local calendar throughout: `Date`
// plus a fixed Gregorian `Calendar`. The half-open range conventions are kept
// exactly (`endOfDay` is the *next* midnight, ranges are `[start, end)`).
//
// Ported from: kalender/lib/src/extensions/internal_date_time.dart,
// internal_date_time_range.dart, time_of_day.dart, time_of_day_range.dart

import Foundation

/// The calendar all kalender date math runs in: Gregorian, local timezone.
public var kalCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
}()

/// Dart-style positive modulo: Dart's `%` never returns a negative value for
/// a positive modulus, Swift's `%` does. The week math depends on the Dart
/// behaviour.
@inline(__always)
func positiveMod(_ a: Int, _ n: Int) -> Int {
    let r = a % n
    return r < 0 ? r + n : r
}

// MARK: - Weekday constants (Dart DateTime numbering, ISO 8601)

/// Dart's `DateTime.monday` ... `DateTime.sunday` (1...7), which kalender's
/// `firstDayOfWeek` API is expressed in.
public enum KalWeekday {
    public static let monday = 1
    public static let tuesday = 2
    public static let wednesday = 3
    public static let thursday = 4
    public static let friday = 5
    public static let saturday = 6
    public static let sunday = 7
    public static let daysPerWeek = 7
}

// MARK: - Date extensions

extension Date {
    /// The ISO 8601 weekday number (monday = 1 ... sunday = 7), matching
    /// Dart's `DateTime.weekday`.
    public var kalWeekday: Int {
        // Foundation: 1 = Sunday ... 7 = Saturday.
        let foundationWeekday = kalCalendar.component(.weekday, from: self)
        return positiveMod(foundationWeekday + 5, 7) + 1
    }

    public var kalYear: Int { kalCalendar.component(.year, from: self) }
    public var kalMonth: Int { kalCalendar.component(.month, from: self) }
    public var kalDay: Int { kalCalendar.component(.day, from: self) }
    public var kalHour: Int { kalCalendar.component(.hour, from: self) }
    public var kalMinute: Int { kalCalendar.component(.minute, from: self) }

    /// Midnight at the start of this date's calendar day.
    public var startOfDay: Date { kalCalendar.startOfDay(for: self) }

    /// Midnight of the *next* day — kalender's `endOfDay` is an exclusive
    /// upper bound, not 23:59.
    public var endOfDay: Date { startOfDay.addingDays(1) }

    /// Whether this date sits exactly on a day boundary.
    public var isStartOfDay: Bool { self == startOfDay }

    /// The first day of this date's month, at midnight.
    public var startOfMonth: Date {
        let components = kalCalendar.dateComponents([.year, .month], from: self)
        return kalCalendar.date(from: components)!
    }

    /// The first day of the *next* month (exclusive upper bound).
    public var endOfMonth: Date {
        kalCalendar.date(byAdding: .month, value: 1, to: startOfMonth)!
    }

    /// Midnight of the first day of this date's week.
    public func startOfWeek(firstDayOfWeek: Int = KalWeekday.monday) -> Date {
        let daysToSubtract = positiveMod(kalWeekday - firstDayOfWeek, 7)
        return startOfDay.addingDays(-daysToSubtract)
    }

    /// Midnight of the day after the last day of this date's week (exclusive).
    public func endOfWeek(firstDayOfWeek: Int = KalWeekday.monday) -> Date {
        let daysToAdd = positiveMod(firstDayOfWeek - kalWeekday - 1, 7)
        return startOfDay.addingDays(daysToAdd + 1)
    }

    /// Calendar-day arithmetic (DST-safe, unlike adding 86400-second chunks).
    public func addingDays(_ days: Int) -> Date {
        kalCalendar.date(byAdding: .day, value: days, to: self)!
    }

    public func addingMonths(_ months: Int) -> Date {
        kalCalendar.date(byAdding: .month, value: months, to: self)!
    }

    public func addingMinutes(_ minutes: Int) -> Date {
        kalCalendar.date(byAdding: .minute, value: minutes, to: self)!
    }

    /// Whether two instants fall on the same calendar day.
    public func isSameDay(_ other: Date) -> Bool {
        kalCalendar.isDate(self, inSameDayAs: other)
    }

    /// Whole calendar days from `other` to self (positive when self is later).
    public func daysSince(_ other: Date) -> Int {
        kalCalendar.dateComponents([.day], from: other.startOfDay, to: startOfDay).day ?? 0
    }

    /// Whether this date is "today" on the local wall clock.
    public var isToday: Bool { isSameDay(Date()) }
}

// MARK: - DateTimeRange

/// A range of dates `[start, end)`, the port of Flutter's `DateTimeRange` plus
/// kalender's extensions on it.
public struct DateTimeRange: Hashable, CustomStringConvertible {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// The total duration of the range in seconds.
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public var description: String { "\(start) - \(end)" }

    /// The calendar dates covered by this range, at midnight each.
    ///
    /// The end date is excluded (half-open) unless `inclusive` is set.
    ///
    /// Ported from: internal_date_time_range.dart `dates()`
    public func dates(inclusive: Bool = false) -> [Date] {
        var dates = [start.startOfDay]
        if start.isSameDay(end) { return dates }

        var current = dates[0]
        while current < end || (inclusive && current == end) {
            let next = current.addingDays(1)
            if next < end || (inclusive && next == end) {
                dates.append(next)
                current = next
            } else {
                break
            }
        }
        return dates
    }

    /// The sub-range of this range that falls on `date`'s calendar day, or
    /// nil when the day is outside the range.
    ///
    /// * On the start day → `[start, endOfDay)`.
    /// * On the end day → `[startOfDay, end)`.
    /// * In between → the full day.
    ///
    /// Ported from: internal_date_time_range.dart `dateTimeRangeOnDate`
    public func dateTimeRangeOnDate(_ date: Date) -> DateTimeRange? {
        let dayRange = DateTimeRange(start: start.startOfDay, end: end.endOfDay)
        guard dayRange.contains(date) else { return nil }
        if start.isSameDay(end) { return self }
        if date.isSameDay(start) { return DateTimeRange(start: start, end: start.endOfDay) }
        if date.isSameDay(end) { return DateTimeRange(start: end.startOfDay, end: end) }
        return DateTimeRange(start: date.startOfDay, end: date.endOfDay)
    }

    /// Whether `date` falls within `[start, end)`.
    public func contains(_ date: Date) -> Bool { date >= start && date < end }

    /// Whether the two ranges overlap (touching edges do not count).
    public func overlaps(_ other: DateTimeRange) -> Bool {
        start < other.end && end > other.start
    }

    /// The number of calendar months between start and end.
    ///
    /// Ported from: internal_date_time_range.dart `monthDifference`
    public var monthDifference: Int {
        var months = (abs(start.kalYear - end.kalYear) - 1) * 12
        months += end.kalMonth + (12 - start.kalMonth)
        return months
    }

    /// The first day of the month holding the most days of this range; the
    /// earlier month wins ties.
    ///
    /// Ported from: internal_date_time_range.dart `dominantMonthDate`
    public var dominantMonthDate: Date {
        var counts: [Date: Int] = [:]
        for date in dates() {
            counts[date.startOfMonth, default: 0] += 1
        }
        let dominant = counts.max { a, b in
            a.value == b.value ? a.key > b.key : a.value < b.value
        }
        return dominant?.key ?? start.startOfMonth
    }
}

// MARK: - TimeOfDay

/// A wall-clock time, hour 0-23 and minute 0-59. Port of Flutter's `TimeOfDay`.
public struct TimeOfDay: Hashable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(fromDateTime date: Date) {
        self.hour = date.kalHour
        self.minute = date.kalMinute
    }

    /// Minutes past midnight.
    public var totalMinutes: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    /// This time of day on `date`'s calendar day.
    ///
    /// Ported from: time_of_day.dart `toInternalDateTime`
    public func toDateTime(_ date: Date) -> Date {
        kalCalendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: date.startOfDay
        ) ?? date.startOfDay
    }
}

// MARK: - TimeOfDayRange

/// A start and end `TimeOfDay` describing the slice of the day a multi-day
/// body displays. The range includes both endpoints, so `allDay` runs
/// 00:00-23:59 and has a duration of 24h.
///
/// Ported from: kalender/lib/src/models/time_of_day_range.dart
public struct TimeOfDayRange: Hashable {
    public let start: TimeOfDay
    public let end: TimeOfDay

    public init(start: TimeOfDay, end: TimeOfDay) {
        assert(start.totalMinutes <= end.totalMinutes)
        self.start = start
        self.end = end
    }

    /// The full day, 00:00 through 23:59.
    public static func allDay() -> TimeOfDayRange {
        TimeOfDayRange(
            start: TimeOfDay(hour: 0, minute: 0),
            end: TimeOfDay(hour: 23, minute: 59)
        )
    }

    /// A single hour.
    public static func forHour(_ hour: Int) -> TimeOfDayRange {
        TimeOfDayRange(
            start: TimeOfDay(hour: hour, minute: 0),
            end: TimeOfDay(hour: hour, minute: 59)
        )
    }

    public var isAllDay: Bool {
        start.hour == 0 && start.minute == 0 && end.hour == 23 && end.minute == 59
    }

    /// Duration in minutes, inclusive of the end minute.
    public var durationInMinutes: Int {
        (end.hour - start.hour) * 60 + (end.minute - start.minute) + 1
    }
}
