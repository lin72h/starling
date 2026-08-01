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

        // Day headers, one per column.
        let headerCells: [Widget] = visibleDates.map { date in
            Expanded(child: DayHeader(date: date, style: components.dayHeaderStyle))
        }

        // The multi-day event lane.
        var laneChildren: [Widget] = []
        if configuration.showTiles {
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

            if !visibleEvents.isEmpty {
                let tiles: [Widget] = visibleEvents.map { event in
                    LayoutId(id: event.id, child: GestureDetector(
                        onTap: { bloc.add(.selectEvent(id: event.id)) },
                        child: Padding(
                            padding: EdgeInsets(left: 0, top: 0, right: 3, bottom: 2),
                            child: tileComponents.tileBuilder(event, visibleRange)
                        )
                    ))
                }
                laneChildren.append(CustomMultiChildLayout(
                    delegate: MultiDayLayout(
                        dateTimeRange: visibleRange,
                        layoutInfo: layoutInfo,
                        numberOfRows: layoutInfo.map { $0.row + 1 }.max() ?? 0,
                        tileHeight: configuration.tileHeight
                    ),
                    children: tiles
                ))
            }
        }

        let timelineWidth = components.timelineStyle.width
        var columnChildren: [Widget] = [Row(children: headerCells)]
        columnChildren.append(contentsOf: laneChildren)

        return DecoratedBox(
            decoration: BoxDecoration(
                color: CalendarColors.surface,
                border: Border(bottom: BorderSide(color: CalendarColors.outline))
            ),
            child: Row(crossAxisAlignment: .end, children: [
                SizedBox(width: timelineWidth, height: 1),
                Expanded(
                    child: Padding(
                        padding: EdgeInsets(bottom: 2),
                        child: Column(crossAxisAlignment: .stretch, children: columnChildren)
                    )
                ),
            ])
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

        var dayColumns: [Widget] = []
        for date in visibleDates {
            dayColumns.append(Expanded(child: _buildDayColumn(
                date: date,
                viewConfiguration: viewConfiguration,
                pageHeight: pageHeight,
                bloc: bloc,
                components: components
            )))
        }

        return SingleChildScrollView(
            controller: bloc.scrollController,
            child: SizedBox(
                height: pageHeight,
                child: Row(crossAxisAlignment: .stretch, children: [
                    SizedBox(
                        width: components.timelineStyle.width,
                        height: pageHeight,
                        child: TimeLine(
                            timeOfDayRange: timeOfDayRange,
                            heightPerMinute: heightPerMinute,
                            style: components.timelineStyle
                        )
                    ),
                    Expanded(child: Row(crossAxisAlignment: .stretch, children: dayColumns)),
                ])
            )
        )
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

        var stackChildren: [Widget] = []

        // The day separator: every column draws its left edge (the timeline
        // gutter ends in the first one's).
        stackChildren.append(Positioned(
            fill: (),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border(left: BorderSide(
                        color: components.daySeparatorStyle.color,
                        width: components.daySeparatorStyle.width
                    ))
                ),
                child: SizedBox(expand: ())
            )
        ))

        // Hour lines behind the events.
        stackChildren.append(Positioned(
            fill: (),
            child: HourLines(
                timeOfDayRange: timeOfDayRange,
                heightPerMinute: heightPerMinute,
                style: components.hourLinesStyle
            )
        ))

        // The tap layer: tapping an empty slot deselects and, when the bloc
        // allows it, creates an event at the tapped (snapped) time.
        let snapMinutes = configuration.snapIntervalMinutes
        stackChildren.append(Positioned(
            fill: (),
            child: GestureDetector(
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
        ))

        // The event tiles.
        stackChildren.append(Positioned(
            fill: (),
            left: configuration.horizontalPadding.left,
            right: configuration.horizontalPadding.right,
            child: _buildDayEvents(
                date: date,
                viewConfiguration: viewConfiguration,
                bloc: bloc
            )
        ))

        // The "now" line.
        if date.isToday {
            let now = Date()
            let dayStart = timeOfDayRange.start.toDateTime(date)
            let offset = now.timeIntervalSince(dayStart) / 60.0 * heightPerMinute
            let radius = components.timeIndicatorStyle.circleRadius
            if offset >= 0 && offset <= pageHeight {
                stackChildren.append(Positioned(
                    left: 0,
                    top: offset - radius,
                    right: 0,
                    height: radius * 2,
                    child: TimeIndicator(style: components.timeIndicatorStyle)
                ))
            }
        }

        return Stack(clipBehavior: .none, children: stackChildren)
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
            let isSelected = state.selectedEventId == event.id
            var tile: Widget = tileComponents.tileBuilder(event, dayRange)
            if isSelected {
                // The tile is inset so the ring stays visible: a decoration
                // paints under its child, and an opaque tile would cover it.
                tile = DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(color: CalendarColors.selection, width: 2),
                        borderRadius: BorderRadius.circular(6)
                    ),
                    child: Padding(padding: EdgeInsets(all: 2), child: tile)
                )
            }
            return LayoutId(id: index, child: GestureDetector(
                onTap: { bloc.add(.selectEvent(id: event.id)) },
                child: tile
            ))
        }

        return CustomMultiChildLayout(delegate: delegate, children: tiles)
    }
}
