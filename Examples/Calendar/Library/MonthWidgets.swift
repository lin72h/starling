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
            )
        ) {
            Row {
                for date in firstWeek {
                    Expanded {
                        WeekDayHeader(date: date, style: provider.components.weekDayHeaderStyle)
                    }
                }
            }
        }
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

        return Column(crossAxisAlignment: .stretch) {
            for row in 0..<numberOfRows {
                let start = visibleRange.start.addingDays(row * Weekday.daysPerWeek)
                let weekRange = DateTimeRange(start: start, end: start.addingDays(Weekday.daysPerWeek))
                Expanded {
                    _buildWeekRow(
                        weekRange: weekRange,
                        focusedMonthStart: focusedMonthStart,
                        bloc: bloc,
                        components: provider.components
                    )
                }
            }
        }
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
        let maxRows = configuration.maximumNumberOfVerticalEvents ?? MonthBody.defaultMaxRows

        // The lane's layout frame, shared by the tiles and the "+n" markers.
        let frame: MultiDayLayoutFrame? = configuration.showTiles
            ? defaultMultiDayFrameGenerator(
                visibleDateTimeRange: weekRange,
                events: state.eventsIn(
                    weekRange,
                    includeMultiDayEvents: true,
                    includeDayEvents: configuration.allowSingleDayEvents
                )
            )
            : nil

        return Stack {
            // The background layer: grid lines and the tap targets. Tapping
            // an empty day deselects and, when the bloc allows it, creates
            // an all-day event.
            Positioned(left: 0, top: 0, right: 0, bottom: 0) {
                Row(crossAxisAlignment: .stretch) {
                    for (index, date) in dates.enumerated() {
                        Expanded {
                            DecoratedBox(
                                decoration: BoxDecoration(
                                    border: index == 0
                                        ? Border(top: gridSide)
                                        : Border(top: gridSide, left: gridSide)
                                )
                            ) {
                                GestureDetector(
                                    onTap: { bloc.add(.tapDay(date)) },
                                    behavior: .opaque,
                                    child: SizedBox(expand: ())
                                )
                            }
                        }
                    }
                }
            }

            // The content layer: day numbers, the event lane, "+n" markers.
            Positioned(left: 0, top: 0, right: 0, bottom: 0) {
                Column(crossAxisAlignment: .stretch) {
                    SizedBox(height: MonthBody.dayHeaderHeight) {
                        Row {
                            for date in dates {
                                Expanded {
                                    MonthDayHeader(
                                        date: date,
                                        isInFocusedMonth: date.calMonth == focusedMonthStart.calMonth
                                            && date.calYear == focusedMonthStart.calYear,
                                        style: components.monthDayHeaderStyle
                                    )
                                }
                            }
                        }
                    }
                    if let frame {
                        _buildLane(frame: frame, weekRange: weekRange, maxRows: maxRows, bloc: bloc)
                        if frame.totalNumberOfRows > maxRows {
                            _buildOverflowStrip(frame: frame, maxRows: maxRows)
                        }
                    }
                }
            }
        }
    }

    /// The week's event lane, or nil when there is nothing to lay out.
    private func _buildLane(
        frame: MultiDayLayoutFrame,
        weekRange: DateTimeRange,
        maxRows: Int,
        bloc: CalendarBloc
    ) -> Widget? {
        let state = bloc.state
        let (visibleEvents, layoutInfo) = frame.visibleEvents(maxRows)
        if visibleEvents.isEmpty { return nil }

        // Data-driven children keyed for the layout delegate — the ported
        // array form is the natural fit here, not a builder block.
        let tiles: [Widget] = visibleEvents.map { event in
            let base = tileComponents.tileBuilder(event, weekRange)
            let tile: Widget
            if state.selectedEventId == event.id {
                // Inset so the ring stays visible over an opaque tile.
                tile = DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(color: CalendarColors.selection, width: 2),
                        borderRadius: BorderRadius.circular(6)
                    )
                ) { Padding(padding: EdgeInsets(all: 2)) { base } }
            } else {
                tile = base
            }
            return LayoutId(id: event.id, child: GestureDetector(
                onTap: { bloc.add(.selectEvent(id: event.id)) },
                child: Padding(padding: EdgeInsets(left: 1, top: 0, right: 4, bottom: 2)) {
                    tile
                }
            ))
        }
        return CustomMultiChildLayout(
            delegate: MultiDayLayout(
                dateTimeRange: weekRange,
                layoutInfo: layoutInfo,
                numberOfRows: layoutInfo.map { $0.row + 1 }.max() ?? 0,
                tileHeight: configuration.tileHeight
            ),
            children: tiles
        )
    }

    /// The "+n" markers where a column overflows the row cap, or nil when no
    /// column does.
    private func _buildOverflowStrip(frame: MultiDayLayoutFrame, maxRows: Int) -> Widget? {
        let hiddenCounts = (0..<Weekday.daysPerWeek).map { column in
            frame.layoutInfo.filter { $0.columns.contains(column) && $0.row >= maxRows }.count
        }
        if hiddenCounts.allSatisfy({ $0 == 0 }) { return nil }

        return SizedBox(height: MonthBody.overflowHeight) {
            Row {
                for hiddenCount in hiddenCounts {
                    if hiddenCount > 0 {
                        Expanded {
                            Padding(padding: EdgeInsets(horizontal: 4)) {
                                Text(
                                    "+\(hiddenCount)",
                                    style: TextStyle(color: CalendarColors.onSurfaceVariant, fontSize: 10),
                                    maxLines: 1
                                )
                            }
                        }
                    } else {
                        Expanded { SizedBox(width: 1, height: 1) }
                    }
                }
            }
        }
    }
}
