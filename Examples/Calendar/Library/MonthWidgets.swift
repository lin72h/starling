// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The month view: a weekday-name header row and a grid of week rows, each
// carrying day-number headers, a multi-day event lane (single-day events
// included), and "+n" overflow markers where a day has more events than fit.
//
// Every read comes from `bloc.state`, every interaction dispatches a
// `CalendarBloc.Event`; the observation roots in CalendarView.swift rebuild these
// widgets whenever the state changes.

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - MonthHeader

/// The header of the month view: the weekday names.
public class MonthHeader: StatelessWidget {
    public override init(key: (any Key)? = nil) {
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let provider = CalendarProvider.of(context)
        let state = provider.bloc.state
        guard state.viewConfiguration is MonthViewConfiguration else {
            assertionFailure("MonthHeader needs a MonthViewConfiguration")
            return SizedBox(width: 0, height: 0)
        }

        let firstWeek = Array(state.visibleDateTimeRange.dates().prefix(Weekday.daysPerWeek))

        return DecoratedBox(
            decoration: BoxDecoration(
                color: CalendarColors.surface,
                border: Border(bottom: BorderSide(color: CalendarColors.outline))
            ),
            child: Row(children: firstWeek.map { date in
                Expanded(child: WeekDayHeader(date: date, style: provider.components.weekDayHeaderStyle))
            })
        )
    }
}

// MARK: - MonthBody

/// The body of the month view.
public class MonthBody: StatelessWidget {
    public let configuration: MultiDayHeaderConfiguration
    public let tileComponents: TileComponents

    /// The height of the day-number strip at the top of each cell.
    static let dayHeaderHeight = 26.0
    /// The height reserved for the "+n" overflow strip.
    static let overflowHeight = 16.0
    /// Rows shown per week when the configuration sets no explicit cap.
    static let defaultMaxRows = 3

    public init(
        configuration: MultiDayHeaderConfiguration = MultiDayHeaderConfiguration(allowSingleDayEvents: true),
        tileComponents: TileComponents = .defaultComponents(),
        key: (any Key)? = nil
    ) {
        self.configuration = configuration
        self.tileComponents = tileComponents
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let provider = CalendarProvider.of(context)
        let bloc = provider.bloc
        let state = bloc.state
        guard state.viewConfiguration is MonthViewConfiguration else {
            assertionFailure("MonthBody needs a MonthViewConfiguration")
            return SizedBox(width: 0, height: 0)
        }

        let calculator = state.viewConfiguration.pageIndexCalculator as! MonthIndexCalculator
        let visibleRange = state.visibleDateTimeRange
        let numberOfRows = calculator.numberOfRowsForRange(visibleRange)
        let focusedMonthStart = calculator.monthStartFromIndex(state.currentPage)

        var weekRows: [Widget] = []
        for row in 0..<numberOfRows {
            let start = visibleRange.start.addingDays(row * Weekday.daysPerWeek)
            let weekRange = DateTimeRange(start: start, end: start.addingDays(Weekday.daysPerWeek))
            weekRows.append(Expanded(child: _buildWeekRow(
                weekRange: weekRange,
                focusedMonthStart: focusedMonthStart,
                bloc: bloc,
                components: provider.components
            )))
        }

        return Column(crossAxisAlignment: .stretch, children: weekRows)
    }

    private func _buildWeekRow(
        weekRange: DateTimeRange,
        focusedMonthStart: Date,
        bloc: CalendarBloc,
        components: CalendarComponents
    ) -> Widget {
        let state = bloc.state
        let dates = weekRange.dates()
        let gridSide = BorderSide(
            color: components.monthGridStyle.color,
            width: components.monthGridStyle.thickness
        )

        // The background layer: grid lines and the tap targets. Tapping an
        // empty day deselects and, when the bloc allows it, creates an
        // all-day event.
        var cells: [Widget] = []
        for (index, date) in dates.enumerated() {
            cells.append(Expanded(child: DecoratedBox(
                decoration: BoxDecoration(
                    border: index == 0
                        ? Border(top: gridSide)
                        : Border(top: gridSide, left: gridSide)
                ),
                child: GestureDetector(
                    onTap: { bloc.add(.tapDay(date)) },
                    behavior: .opaque,
                    child: SizedBox(expand: ())
                )
            )))
        }

        // The day-number strip.
        let dayHeaders = Row(children: dates.map { date in
            Expanded(child: MonthDayHeader(
                date: date,
                isInFocusedMonth: date.calMonth == focusedMonthStart.calMonth
                    && date.calYear == focusedMonthStart.calYear,
                style: components.monthDayHeaderStyle
            ))
        })

        // The event lane.
        let maxRows = configuration.maximumNumberOfVerticalEvents ?? MonthBody.defaultMaxRows
        var laneAndOverflow: [Widget] = []
        if configuration.showTiles {
            let events = state.eventsIn(
                weekRange,
                includeMultiDayEvents: true,
                includeDayEvents: configuration.allowSingleDayEvents
            )
            let frame = defaultMultiDayFrameGenerator(
                visibleDateTimeRange: weekRange,
                events: events
            )
            let (visibleEvents, layoutInfo) = frame.visibleEvents(maxRows)

            if !visibleEvents.isEmpty {
                let tiles: [Widget] = visibleEvents.map { event in
                    let isSelected = state.selectedEventId == event.id
                    var tile: Widget = tileComponents.tileBuilder(event, weekRange)
                    if isSelected {
                        // Inset so the ring stays visible over an opaque tile.
                        tile = DecoratedBox(
                            decoration: BoxDecoration(
                                border: Border.all(color: CalendarColors.selection, width: 2),
                                borderRadius: BorderRadius.circular(6)
                            ),
                            child: Padding(padding: EdgeInsets(all: 2), child: tile)
                        )
                    }
                    return LayoutId(id: event.id, child: GestureDetector(
                        onTap: { bloc.add(.selectEvent(id: event.id)) },
                        child: Padding(
                            padding: EdgeInsets(left: 1, top: 0, right: 4, bottom: 2),
                            child: tile
                        )
                    ))
                }
                laneAndOverflow.append(CustomMultiChildLayout(
                    delegate: MultiDayLayout(
                        dateTimeRange: weekRange,
                        layoutInfo: layoutInfo,
                        numberOfRows: layoutInfo.map { $0.row + 1 }.max() ?? 0,
                        tileHeight: configuration.tileHeight
                    ),
                    children: tiles
                ))
            }

            // "+n" markers where a column overflows the row cap.
            if frame.totalNumberOfRows > maxRows {
                var overflowCells: [Widget] = []
                var hasOverflow = false
                for column in 0..<Weekday.daysPerWeek {
                    let hiddenCount = frame.layoutInfo
                        .filter { $0.columns.contains(column) && $0.row >= maxRows }
                        .count
                    if hiddenCount > 0 {
                        hasOverflow = true
                        overflowCells.append(Expanded(child: Padding(
                            padding: EdgeInsets(horizontal: 4),
                            child: Text(
                                "+\(hiddenCount)",
                                style: TextStyle(color: CalendarColors.onSurfaceVariant, fontSize: 10),
                                maxLines: 1
                            )
                        )))
                    } else {
                        overflowCells.append(Expanded(child: SizedBox(width: 1, height: 1)))
                    }
                }
                if hasOverflow {
                    laneAndOverflow.append(SizedBox(
                        height: MonthBody.overflowHeight,
                        child: Row(children: overflowCells)
                    ))
                }
            }
        }

        var contentChildren: [Widget] = [
            SizedBox(height: MonthBody.dayHeaderHeight, child: dayHeaders)
        ]
        contentChildren.append(contentsOf: laneAndOverflow)

        return Stack(children: [
            Positioned(fill: (), child: Row(crossAxisAlignment: .stretch, children: cells)),
            Positioned(
                fill: (),
                child: Column(crossAxisAlignment: .stretch, children: contentChildren)
            ),
        ])
    }
}
