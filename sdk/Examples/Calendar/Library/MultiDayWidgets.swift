// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The multi-day (day/week/work-week/custom) view: a header with day labels
// and a multi-day event lane, and a vertically scrollable body of day columns
// with hour lines, event tiles and the "now" indicator.
//
// Every read comes from `bloc.state`, every interaction dispatches a
// `CalendarBloc.Event`; the observation roots in CalendarView.swift rebuild these
// widgets whenever the state changes.

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - MultiDayHeader

/// The header of a multi-day view: a leading gutter aligned with the body's
/// timeline, a `DayHeader` per visible day, and the multi-day event lane.
public class MultiDayHeader: StatelessWidget {
    public let configuration: MultiDayHeaderConfiguration
    public let tileComponents: TileComponents

    public init(
        configuration: MultiDayHeaderConfiguration = MultiDayHeaderConfiguration(),
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
        guard state.viewConfiguration is MultiDayViewConfiguration else {
            assertionFailure("MultiDayHeader needs a MultiDayViewConfiguration")
            return SizedBox(width: 0, height: 0)
        }

        let components = provider.components
        let visibleRange = state.visibleDateTimeRange
        let visibleDates = visibleRange.dates()

        return DecoratedBox(
            decoration: BoxDecoration(
                color: CalendarColors.surface,
                border: Border(bottom: BorderSide(color: CalendarColors.outline))
            )
        ) {
            Row(crossAxisAlignment: .end) {
                SizedBox(width: components.timelineStyle.width, height: 1)
                Expanded {
                    Padding(padding: EdgeInsets(bottom: 2)) {
                        Column(crossAxisAlignment: .stretch) {
                            // Day headers, one per column.
                            Row {
                                for date in visibleDates {
                                    Expanded { DayHeader(date: date, style: components.dayHeaderStyle) }
                                }
                            }
                            // The multi-day event lane.
                            if configuration.showTiles {
                                _buildLane(visibleRange: visibleRange, state: state, bloc: bloc)
                            }
                        }
                    }
                }
            }
        }
    }

    /// The multi-day lane, or nil when there is nothing to lay out.
    private func _buildLane(
        visibleRange: DateTimeRange,
        state: CalendarState,
        bloc: CalendarBloc
    ) -> Widget? {
        let events = state.eventsIn(
            visibleRange,
            includeMultiDayEvents: true,
            includeDayEvents: configuration.allowSingleDayEvents
        )
        let frame = defaultMultiDayFrameGenerator(
            visibleDateTimeRange: visibleRange,
            events: events
        )
        let (visibleEvents, layoutInfo) = frame.visibleEvents(configuration.maximumNumberOfVerticalEvents)
        if visibleEvents.isEmpty { return nil }

        // Data-driven children keyed for the layout delegate — the ported
        // array form is the natural fit here, not a builder block.
        let tiles: [Widget] = visibleEvents.map { event in
            LayoutId(id: event.id, child: GestureDetector(
                onTap: { bloc.add(.selectEvent(id: event.id)) },
                child: Padding(padding: EdgeInsets(left: 0, top: 0, right: 3, bottom: 2)) {
                    tileComponents.tileBuilder(event, visibleRange)
                }
            ))
        }
        return CustomMultiChildLayout(
            delegate: MultiDayLayout(
                dateTimeRange: visibleRange,
                layoutInfo: layoutInfo,
                numberOfRows: layoutInfo.map { $0.row + 1 }.max() ?? 0,
                tileHeight: configuration.tileHeight
            ),
            children: tiles
        )
    }
}

// MARK: - MultiDayBody

/// The body of a multi-day view: the timeline gutter and one column per
/// visible day, vertically scrollable, with hour lines behind the event
/// tiles and the "now" line on today.
public class MultiDayBody: StatelessWidget {
    public let configuration: MultiDayBodyConfiguration
    public let tileComponents: TileComponents

    public init(
        configuration: MultiDayBodyConfiguration = MultiDayBodyConfiguration(),
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
        guard let viewConfiguration = state.viewConfiguration as? MultiDayViewConfiguration else {
            assertionFailure("MultiDayBody needs a MultiDayViewConfiguration")
            return SizedBox(width: 0, height: 0)
        }

        let components = provider.components
        let timeOfDayRange = viewConfiguration.timeOfDayRange
        let heightPerMinute = state.heightPerMinute
        let pageHeight = Double(timeOfDayRange.durationInMinutes) * heightPerMinute
        let visibleDates = state.visibleDateTimeRange.dates()

        return SingleChildScrollView(controller: bloc.scrollController) {
            SizedBox(height: pageHeight) {
                Row(crossAxisAlignment: .stretch) {
                    SizedBox(width: components.timelineStyle.width, height: pageHeight) {
                        TimeLine(
                            timeOfDayRange: timeOfDayRange,
                            heightPerMinute: heightPerMinute,
                            style: components.timelineStyle
                        )
                    }
                    Expanded {
                        Row(crossAxisAlignment: .stretch) {
                            for date in visibleDates {
                                Expanded {
                                    _buildDayColumn(
                                        date: date,
                                        viewConfiguration: viewConfiguration,
                                        pageHeight: pageHeight,
                                        bloc: bloc,
                                        components: components
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// One day column: separator + hour lines behind, tap layer, event tiles,
    /// and the "now" indicator on today.
    private func _buildDayColumn(
        date: Date,
        viewConfiguration: MultiDayViewConfiguration,
        pageHeight: Double,
        bloc: CalendarBloc,
        components: CalendarComponents
    ) -> Widget {
        let timeOfDayRange = viewConfiguration.timeOfDayRange
        let heightPerMinute = bloc.state.heightPerMinute
        let snapMinutes = configuration.snapIntervalMinutes

        return Stack(clipBehavior: .none) {
            // The day separator: every column draws its left edge (the
            // timeline gutter ends in the first one's).
            Positioned(left: 0, top: 0, right: 0, bottom: 0) {
                DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border(left: BorderSide(
                            color: components.daySeparatorStyle.color,
                            width: components.daySeparatorStyle.width
                        ))
                    )
                ) { SizedBox(expand: ()) }
            }

            // Hour lines behind the events.
            Positioned(left: 0, top: 0, right: 0, bottom: 0) {
                HourLines(
                    timeOfDayRange: timeOfDayRange,
                    heightPerMinute: heightPerMinute,
                    style: components.hourLinesStyle
                )
            }

            // The tap layer: tapping an empty slot deselects and, when the
            // bloc allows it, creates an event at the tapped (snapped) time.
            Positioned(left: 0, top: 0, right: 0, bottom: 0) {
                GestureDetector(
                    onTapUp: { details in
                        let dayStart = timeOfDayRange.start.toDateTime(date)
                        let minutes = details.localPosition.dy / heightPerMinute
                        let snapped = snapMinutes > 0
                            ? Int(minutes / Double(snapMinutes)) * snapMinutes
                            : Int(minutes)
                        bloc.add(.tapTimeSlot(dayStart.addingMinutes(snapped)))
                    },
                    behavior: .opaque,
                    child: SizedBox(expand: ())
                )
            }

            // The event tiles.
            Positioned(
                left: configuration.horizontalPadding.left,
                top: 0,
                right: configuration.horizontalPadding.right,
                bottom: 0
            ) {
                _buildDayEvents(
                    date: date,
                    viewConfiguration: viewConfiguration,
                    bloc: bloc
                )
            }

            // The "now" line.
            if date.isToday {
                let dayStart = timeOfDayRange.start.toDateTime(date)
                let offset = Date().timeIntervalSince(dayStart) / 60.0 * heightPerMinute
                let radius = components.timeIndicatorStyle.circleRadius
                if offset >= 0 && offset <= pageHeight {
                    Positioned(left: 0, top: offset - radius, right: 0, height: radius * 2) {
                        TimeIndicator(style: components.timeIndicatorStyle)
                    }
                }
            }
        }
    }

    /// The `CustomMultiChildLayout` of a day's event tiles.
    private func _buildDayEvents(
        date: Date,
        viewConfiguration: MultiDayViewConfiguration,
        bloc: CalendarBloc
    ) -> Widget {
        let state = bloc.state
        let dayRange = DateTimeRange(start: date.startOfDay, end: date.endOfDay)

        let events = state.eventsIn(
            dayRange,
            includeMultiDayEvents: configuration.showMultiDayEvents,
            includeDayEvents: true
        )
        if events.isEmpty { return SizedBox(expand: ()) }

        // The delegate identifies children by index into its (sorted) events.
        let sorter = configuration.eventLayoutStrategy(
            events,
            date,
            viewConfiguration.timeOfDayRange,
            state.heightPerMinute,
            configuration.minimumTileHeight
        )
        let sorted = sorter.sortEvents(events)
        let delegate = configuration.eventLayoutStrategy(
            sorted,
            date,
            viewConfiguration.timeOfDayRange,
            state.heightPerMinute,
            configuration.minimumTileHeight
        )

        let tiles: [Widget] = sorted.enumerated().map { index, event in
            let base = tileComponents.tileBuilder(event, dayRange)
            let tile: Widget
            if state.selectedEventId == event.id {
                // The tile is inset so the ring stays visible: a decoration
                // paints under its child, and an opaque tile would cover it.
                tile = DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(color: CalendarColors.selection, width: 2),
                        borderRadius: BorderRadius.circular(6)
                    )
                ) { Padding(padding: EdgeInsets(all: 2)) { base } }
            } else {
                tile = base
            }
            return LayoutId(id: index, child: GestureDetector(
                onTap: { bloc.add(.selectEvent(id: event.id)) },
                child: tile
            ))
        }

        return CustomMultiChildLayout(delegate: delegate, children: tiles)
    }
}
