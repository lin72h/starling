// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The horizontal (day-axis) event layout: packs multi-day events into rows of
// a header lane (or month week row), assigning each event the first row whose
// day columns it does not clash with.
//
// Ported from: kalender/lib/src/layout_delegates/multi_day_event_layout.dart
// (LTR only; the Dart original also parameterises text direction.)

import Flutter
import FlutterSwiftBridge
import Foundation

/// Generates the layout frame for multi-day events over a visible range.
public typealias GenerateMultiDayLayoutFrame = (
    _ visibleDateTimeRange: DateTimeRange,
    _ events: [CalendarEvent]
) -> MultiDayLayoutFrame

/// The default frame generator:
/// 1. Sort events by duration (descending), then start (ascending).
/// 2. Map each event to the columns (dates) it spans.
/// 3. Assign each event the first row whose columns are free.
public func defaultMultiDayFrameGenerator(
    visibleDateTimeRange: DateTimeRange,
    events: [CalendarEvent]
) -> MultiDayLayoutFrame {
    let visibleDates = visibleDateTimeRange.dates()

    struct FrameEntry {
        let event: CalendarEvent
        let start: Date
        let roundedEnd: Date
    }

    var entries: [FrameEntry] = []
    for event in events {
        let range = event.dateTimeRange
        // Round the end up to the end of the day unless it already sits on a
        // day boundary, so the final day of the event is included.
        let roundedEnd = range.end.isStartOfDay ? range.end : range.end.endOfDay
        entries.append(FrameEntry(event: event, start: range.start, roundedEnd: roundedEnd))
    }

    entries.sort { a, b in
        let durationA = a.event.duration
        let durationB = b.event.duration
        if durationA != durationB { return durationA > durationB }
        return a.start < b.roundedEnd
    }

    let sortedEvents = entries.map(\.event)

    var layoutInfo: [EventLayoutInformation] = []

    // The columns occupied by each row, indexed by row.
    var rowColumns: [Set<Int>] = []
    var maxRow = 0

    var columnForDate: [Date: Int] = [:]
    for (i, date) in visibleDates.enumerated() { columnForDate[date] = i }

    // -1 is a sentinel: no event assigned to this column yet, so columns
    // without events do not trigger spurious overflow buttons.
    var columnRowMap: [Int: Int] = [:]
    for i in visibleDates.indices { columnRowMap[i] = -1 }

    for entry in entries {
        let range = DateTimeRange(start: entry.start, end: entry.roundedEnd)

        var columns: [Int] = []
        for date in range.dates() {
            guard let index = columnForDate[date] else { continue }
            columns.append(index)
        }

        // An event with no visible columns cannot be laid out.
        if columns.isEmpty { continue }

        // The event spans a contiguous range of columns, so overlap only
        // depends on its first and last column.
        let start = columns.min()!
        let end = columns.max()!

        // The first row whose occupied columns do not clash with this event.
        var rowToUse = -1
        for (row, occupied) in rowColumns.enumerated() {
            if !(start...end).contains(where: { occupied.contains($0) }) {
                rowToUse = row
                break
            }
        }

        if rowToUse == -1 {
            rowToUse = rowColumns.count
            rowColumns.append([])
        }

        for column in start...end {
            rowColumns[rowToUse].insert(column)
        }

        let layout = EventLayoutInformation(id: entry.event.id, row: rowToUse, columns: columns)
        maxRow = max(maxRow, layout.row)

        for column in columns {
            columnRowMap[column] = max(columnRowMap[column] ?? -1, layout.row)
        }

        layoutInfo.append(layout)
    }

    return MultiDayLayoutFrame(
        dateTimeRange: visibleDateTimeRange,
        layoutInfo: layoutInfo,
        events: sortedEvents,
        totalNumberOfRows: sortedEvents.isEmpty ? 0 : maxRow + 1,
        columnRowMap: columnRowMap
    )
}

// MARK: - MultiDayLayoutFrame

/// Everything needed to lay out multi-day events with `MultiDayLayout`.
public struct MultiDayLayoutFrame {
    /// The range of dates this frame covers (e.g. one week).
    public let dateTimeRange: DateTimeRange

    /// The sorted events the tiles are generated from.
    public let events: [CalendarEvent]

    /// The layout information for each event.
    public let layoutInfo: [EventLayoutInformation]

    /// The number of rows needed to lay out all the events.
    public let totalNumberOfRows: Int

    /// The highest row index used per column (-1 when the column is empty).
    public let columnRowMap: [Int: Int]

    public init(
        dateTimeRange: DateTimeRange,
        layoutInfo: [EventLayoutInformation],
        events: [CalendarEvent],
        totalNumberOfRows: Int,
        columnRowMap: [Int: Int]
    ) {
        self.dateTimeRange = dateTimeRange
        self.layoutInfo = layoutInfo
        self.events = events
        self.totalNumberOfRows = totalNumberOfRows
        self.columnRowMap = columnRowMap
    }

    /// The date shown in the given column.
    public func dateFromColumn(_ column: Int) -> Date {
        dateTimeRange.start.addingDays(column)
    }

    /// The events and layout info that fit within `maxNumberOfRows` (nil
    /// returns everything).
    public func visibleEvents(_ maxNumberOfRows: Int?) -> ([CalendarEvent], [EventLayoutInformation]) {
        guard let maxNumberOfRows else { return (events, layoutInfo) }
        if totalNumberOfRows <= maxNumberOfRows { return (events, layoutInfo) }

        let info = layoutInfo.filter { $0.row < maxNumberOfRows }
        let visible = info.compactMap { item in events.first { $0.id == item.id } }
        return (visible, info)
    }

    /// The events displayed in the given column.
    public func eventsForColumn(_ column: Int) -> [CalendarEvent] {
        layoutInfo
            .filter { $0.columns.contains(column) }
            .compactMap { item in events.first { $0.id == item.id } }
    }
}

/// The placement of a single event within a `MultiDayLayout`.
public struct EventLayoutInformation {
    public let id: String
    public let row: Int
    public let columns: [Int]

    public var start: Int { columns.first! }
    public var end: Int { columns.last! }

    public init(id: String, row: Int, columns: [Int]) {
        assert(!columns.isEmpty, "Columns cannot be empty")
        self.id = id
        self.row = row
        self.columns = columns
    }

    /// Whether the two events' column ranges intersect.
    public func overlaps(_ other: EventLayoutInformation) -> Bool {
        !(end < other.start || start > other.end)
    }
}

// MARK: - MultiDayLayout

/// The `MultiChildLayoutDelegate` that positions multi-day tiles: column
/// range → horizontal extent, row → vertical offset. Children are identified
/// by event id.
public final class MultiDayLayout: MultiChildLayoutDelegate {
    public let dateTimeRange: DateTimeRange
    public let layoutInfo: [EventLayoutInformation]
    public let numberOfRows: Int
    public let tileHeight: Double

    public init(
        dateTimeRange: DateTimeRange,
        layoutInfo: [EventLayoutInformation],
        numberOfRows: Int,
        tileHeight: Double
    ) {
        self.dateTimeRange = dateTimeRange
        self.layoutInfo = layoutInfo
        self.numberOfRows = numberOfRows
        self.tileHeight = tileHeight
        super.init()
    }

    public override func getSize(_ constraints: BoxConstraints) -> Size {
        Size(constraints.maxWidth, Double(numberOfRows) * tileHeight)
    }

    public override func performLayout(_ size: Size) {
        let visibleDates = dateTimeRange.dates()
        let dayWidth = size.width / Double(visibleDates.count)

        for information in layoutInfo {
            let dx = Double(information.start) * dayWidth
            let dy = Double(information.row) * tileHeight
            let width = Double(information.columns.count) * dayWidth

            _ = layoutChild(
                information.id,
                BoxConstraints.tightFor(width: width, height: tileHeight)
            )
            positionChild(information.id, Offset(dx, dy))
        }
    }

    public override func shouldRelayout(_ oldDelegate: MultiChildLayoutDelegate) -> Bool {
        guard let old = oldDelegate as? MultiDayLayout else { return true }
        return old.dateTimeRange != dateTimeRange
            || old.numberOfRows != numberOfRows
            || old.tileHeight != tileHeight
            || old.layoutInfo.count != layoutInfo.count
            || !zip(old.layoutInfo, layoutInfo).allSatisfy {
                $0.id == $1.id && $0.row == $1.row && $0.columns == $1.columns
            }
    }
}
