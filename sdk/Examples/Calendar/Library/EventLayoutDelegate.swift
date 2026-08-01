// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The vertical (time-axis) event layout: positions each event tile in a day
// column by its start/end time, packing overlapping events either on top of
// each other (`overlapLayoutStrategy`) or next to each other
// (`sideBySideLayoutStrategy`).
//
// Ported from: kalender/lib/src/layout_delegates/event_layout_delegate.dart
// (The Dart delegate also carries a per-date cache keyed by event hash; this
// port recomputes, which at example scale is well under a frame.)

import Flutter
import FlutterSwiftBridge
import Foundation

/// The strategy that determines how day events are laid out.
public typealias EventLayoutStrategy = (
    _ events: [CalendarEvent],
    _ date: Date,
    _ timeOfDayRange: TimeOfDayRange,
    _ heightPerMinute: Double,
    _ minimumTileHeight: Double?
) -> EventLayoutDelegate

/// A strategy that stacks overlapping tiles on top of one another.
public func overlapLayoutStrategy(
    _ events: [CalendarEvent],
    _ date: Date,
    _ timeOfDayRange: TimeOfDayRange,
    _ heightPerMinute: Double,
    _ minimumTileHeight: Double?
) -> EventLayoutDelegate {
    OverlapLayoutDelegate(
        events: events,
        date: date,
        timeOfDayRange: timeOfDayRange,
        heightPerMinute: heightPerMinute,
        minimumTileHeight: minimumTileHeight
    )
}

/// A strategy that lays overlapping tiles out side by side.
public func sideBySideLayoutStrategy(
    _ events: [CalendarEvent],
    _ date: Date,
    _ timeOfDayRange: TimeOfDayRange,
    _ heightPerMinute: Double,
    _ minimumTileHeight: Double?
) -> EventLayoutDelegate {
    SideBySideLayoutDelegate(
        events: events,
        date: date,
        timeOfDayRange: timeOfDayRange,
        heightPerMinute: heightPerMinute,
        minimumTileHeight: minimumTileHeight
    )
}

// MARK: - EventLayoutDelegate

/// The base `MultiChildLayoutDelegate` for laying out `CalendarEvent`s in a
/// `CustomMultiChildLayout`. Children are identified by their index into
/// `events`.
open class EventLayoutDelegate: MultiChildLayoutDelegate {
    /// The date whose column is being laid out.
    public let date: Date

    /// The time slice of the day being displayed.
    public let timeOfDayRange: TimeOfDayRange

    /// The events to lay out, in the same order as the widget's children.
    public let events: [CalendarEvent]

    /// Pixels per minute.
    public let heightPerMinute: Double

    /// A floor on rendered tile height.
    public let minimumTileHeight: Double?

    public init(
        events: [CalendarEvent],
        date: Date,
        timeOfDayRange: TimeOfDayRange,
        heightPerMinute: Double,
        minimumTileHeight: Double?
    ) {
        self.events = events
        self.date = date
        self.timeOfDayRange = timeOfDayRange
        self.heightPerMinute = heightPerMinute
        self.minimumTileHeight = minimumTileHeight
        super.init()
    }

    /// Sorts events before they are passed to the delegate as children.
    /// The widget calls this so its child order matches the layout's.
    open func sortEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        fatalError("Subclasses must override sortEvents")
    }

    /// Sorts the computed vertical layout data before grouping.
    open func sortVerticalLayoutData(_ layoutData: [VerticalLayoutData]) -> [VerticalLayoutData] {
        fatalError("Subclasses must override sortVerticalLayoutData")
    }

    /// The pixel offset of `instant` from the top of the day.
    ///
    /// Both the top and bottom of an event are derived from this single
    /// conversion so that back-to-back events get bit-identical boundaries
    /// and never read as overlapping through floating point noise.
    func offsetFromDayStart(_ instant: Date) -> Double {
        let dayStart = timeOfDayRange.start.toDateTime(date)
        return instant.timeIntervalSince(dayStart) * heightPerMinute / 60.0
    }

    /// The top and bottom of each event, clamped into the widget's bounds.
    public func calculateVerticalLayoutData(_ size: Size) -> [VerticalLayoutData] {
        var layoutData: [VerticalLayoutData] = []
        layoutData.reserveCapacity(events.count)

        for (id, event) in events.enumerated() {
            let range = event.dateTimeRange.dateTimeRangeOnDate(date)
            let eventStart = range?.start ?? date.startOfDay
            let eventEnd = range?.end ?? date.startOfDay

            var top = offsetFromDayStart(eventStart)
            // Derive the bottom from the end instant with the same conversion
            // as the top (not top + height) — see offsetFromDayStart.
            var bottom = offsetFromDayStart(eventEnd)

            if let minimum = minimumTileHeight, bottom - top < minimum {
                bottom = top + minimum
            }

            // Shift events that stick out past the bottom back into view.
            let overlap = size.height - bottom
            if overlap < 0 {
                top += overlap
                bottom += overlap
            }

            // Round to one decimal place to keep floating point noise from
            // perturbing the grouping.
            top = (top * 10).rounded() / 10
            bottom = (bottom * 10).rounded() / 10

            layoutData.append(VerticalLayoutData(id: id, top: top, bottom: bottom))
        }

        return sortVerticalLayoutData(layoutData)
    }

    /// Groups the vertical layout data into clusters of transitively
    /// overlapping events; each group shares the column width.
    public func groupVerticalLayoutData(_ verticalLayoutData: [VerticalLayoutData]) -> [HorizontalGroupData] {
        var groups: [HorizontalGroupData] = []

        for layoutData in verticalLayoutData {
            if groups.contains(where: { $0.containsId(layoutData.id) }) { continue }

            if let index = groups.firstIndex(where: { $0.overlaps(layoutData.top, layoutData.bottom) }) {
                groups[index].add(layoutData)
            } else {
                groups.append(HorizontalGroupData(layoutData))
            }
        }

        return groups
    }

    /// The length of the longest chain of pairwise-overlapping events, which
    /// decides the column count in side-by-side layouts. Memoised DFS.
    public func findLongestChain(_ verticalLayoutData: [VerticalLayoutData]) -> Int {
        if verticalLayoutData.isEmpty { return 0 }

        var memo: [Int: Int] = [:]

        func depthFirstSearch(_ currentIndex: Int, _ visited: Set<Int>) -> Int {
            if let cached = memo[currentIndex] { return cached }
            var maxLength = 1

            for i in verticalLayoutData.indices
            where i != currentIndex
                && !visited.contains(i)
                && verticalLayoutData[currentIndex].overlaps(verticalLayoutData[i]) {
                var newVisited = visited
                newVisited.insert(i)
                maxLength = max(maxLength, 1 + depthFirstSearch(i, newVisited))
            }

            memo[currentIndex] = maxLength
            return maxLength
        }

        var maxChain = 1
        for i in verticalLayoutData.indices {
            maxChain = max(maxChain, depthFirstSearch(i, [i]))
        }
        return maxChain
    }

    public override func shouldRelayout(_ oldDelegate: MultiChildLayoutDelegate) -> Bool {
        guard let old = oldDelegate as? EventLayoutDelegate else { return true }
        return old.events.count != events.count
            || !zip(old.events, events).allSatisfy { $0.layoutEquals($1) }
            || old.heightPerMinute != heightPerMinute
            || old.timeOfDayRange != timeOfDayRange
            || old.date != date
            || old.minimumTileHeight != minimumTileHeight
    }
}

// MARK: - OverlapLayoutDelegate

/// Stacks overlapping events on top of one another, each successive tile
/// narrower and pushed toward the right edge.
public final class OverlapLayoutDelegate: EventLayoutDelegate {
    public override func sortEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        // Longest first; equal durations sort by later start first (matching
        // the Dart double-sort).
        events.sorted { a, b in
            if a.duration != b.duration { return a.duration > b.duration }
            return a.start > b.start
        }
    }

    public override func sortVerticalLayoutData(_ layoutData: [VerticalLayoutData]) -> [VerticalLayoutData] {
        layoutData
    }

    public override func performLayout(_ size: Size) {
        let verticalLayoutData = calculateVerticalLayoutData(size)
        let horizontalGroups = groupVerticalLayoutData(verticalLayoutData)

        for group in horizontalGroups {
            var layoutData: [EventLayoutData] = []
            for data in group.verticalLayoutData {
                // How many already-placed tiles this one overlaps decides how
                // deep in the stack it sits.
                let overlaps = layoutData.filter { $0.overlaps(data) }
                let numberOfOverlaps = overlaps.count + 1

                let lastWidth = overlaps.map(\.width).min()

                let width: Double
                let xOffset: Double
                if let lastWidth {
                    width = lastWidth / 1.8
                    xOffset = size.width - width
                } else {
                    width = size.width / Double(numberOfOverlaps)
                    xOffset = width * Double(numberOfOverlaps - 1)
                }

                if hasChild(data.id) {
                    _ = layoutChild(data.id, BoxConstraints.tightFor(width: width, height: data.height))
                    positionChild(data.id, Offset(xOffset, data.top))
                }

                layoutData.append(EventLayoutData(left: xOffset, right: size.width, verticalLayoutData: data))
            }
        }
    }
}

// MARK: - SideBySideLayoutDelegate

/// Lays overlapping events out next to one another, dividing the column by
/// the longest overlap chain.
public final class SideBySideLayoutDelegate: EventLayoutDelegate {
    public override func sortEvents(_ events: [CalendarEvent]) -> [CalendarEvent] { events }

    public override func sortVerticalLayoutData(_ layoutData: [VerticalLayoutData]) -> [VerticalLayoutData] {
        // Top to bottom; equal tops put the taller (lower bottom) first.
        layoutData.sorted { a, b in
            if a.top != b.top { return a.top < b.top }
            return a.bottom > b.bottom
        }
    }

    public override func performLayout(_ size: Size) {
        let verticalLayoutData = calculateVerticalLayoutData(size)
        let horizontalGroups = groupVerticalLayoutData(verticalLayoutData)

        for group in horizontalGroups {
            // Tallest first; ties broken by lower top first.
            let groupData = group.verticalLayoutData.sorted { a, b in
                if a.height != b.height { return a.height > b.height }
                return a.top > b.top
            }

            let longest = findLongestChain(groupData)
            let childWidth = size.width / Double(max(longest, 1))

            var tiles: [Int: Offset] = [:]
            var tileWidths: [Int: Double] = [:]

            for (i, data) in groupData.enumerated() {
                // Tiles placed before this one that overlap it push it right.
                let tilesToLeft = groupData[0..<i]
                let overlapsLeft = tilesToLeft.filter { $0.overlaps(data) }

                let tileXOffset: Double
                if let lastOverlapLeft = overlapsLeft.last {
                    tileXOffset = tiles[lastOverlapLeft.id]!.dx + tileWidths[lastOverlapLeft.id]!
                } else {
                    tileXOffset = childWidth * Double(overlapsLeft.count)
                }

                // Without a neighbour on the right, stretch to the edge.
                let tilesToRight = groupData[(i + 1)...]
                let overlapsRight = tilesToRight.contains { $0.overlaps(data) }
                let tileWidth = overlapsRight ? childWidth : size.width - tileXOffset

                if hasChild(data.id) {
                    _ = layoutChild(data.id, BoxConstraints.tightFor(width: tileWidth, height: data.height))
                }

                tiles[data.id] = Offset(tileXOffset, data.top)
                tileWidths[data.id] = tileWidth
            }

            for (id, offset) in tiles where hasChild(id) {
                positionChild(id, offset)
            }
        }
    }
}

// MARK: - Layout data types

/// The vertical placement of a single event.
public struct VerticalLayoutData {
    public let id: Int
    public let top: Double
    public let bottom: Double

    public var height: Double { bottom - top }

    /// Whether the two vertical spans overlap (touching edges do not count).
    public func overlaps(_ other: VerticalLayoutData) -> Bool {
        let isInside = other.top > top && other.bottom < bottom
        let overlapTop = other.top <= top && other.bottom > top
        let overlapBottom = other.top < bottom && other.bottom >= bottom
        let outside = other.top <= top && other.bottom >= bottom
        return isInside || overlapTop || overlapBottom || outside
    }
}

/// The final placement of a single event within its group.
struct EventLayoutData {
    let left: Double
    let right: Double
    let verticalLayoutData: VerticalLayoutData

    var width: Double { right - left }
    var id: Int { verticalLayoutData.id }

    func overlaps(_ other: VerticalLayoutData) -> Bool {
        verticalLayoutData.overlaps(other)
    }
}

/// A cluster of transitively overlapping events and its overall span.
public struct HorizontalGroupData {
    public private(set) var verticalLayoutData: [VerticalLayoutData] = []
    public private(set) var top = Double.infinity
    public private(set) var bottom = -Double.infinity

    public init(_ initialData: VerticalLayoutData) {
        add(initialData)
    }

    public mutating func add(_ layoutData: VerticalLayoutData) {
        verticalLayoutData.append(layoutData)
        top = min(top, layoutData.top)
        bottom = max(bottom, layoutData.bottom)
    }

    public func overlaps(_ top: Double, _ bottom: Double) -> Bool {
        let isInside = top > self.top && bottom < self.bottom
        let overlapsTop = top <= self.top && bottom > self.top
        let overlapsBottom = top < self.bottom && bottom >= self.bottom
        let isOutside = top <= self.top && bottom >= self.bottom
        return isInside || overlapsTop || overlapsBottom || isOutside
    }

    public func containsId(_ id: Int) -> Bool {
        verticalLayoutData.contains { $0.id == id }
    }
}
