// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The multi-day (day/week/work-week/custom) view: a header with day labels
// and a multi-day event lane, and a vertically scrollable body of day columns
// with hour lines, event tiles and the "now" indicator.
//
// Ported from: kalender/lib/src/widgets/multi_day/multi_day_body.dart,
// multi_day_header.dart, events_widgets/day_events_widget.dart,
// draggable/day_draggable.dart (tap-to-create only; the Dart page view
// becomes a single page rebuilt from the view controller's currentPage).

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
        guard let viewController = provider.calendarController.viewController as? MultiDayViewController else {
            assertionFailure("The CalendarController's ViewController needs to be a MultiDayViewController")
            return SizedBox(width: 0, height: 0)
        }

        return KalListenableBuilder(
            listenables: [viewController.currentPage, provider.eventsController],
            builder: { [self] context in
                self._buildHeader(context, provider: provider, viewController: viewController)
            }
        )
    }

    private func _buildHeader(
        _ context: any BuildContext,
        provider: CalendarProvider,
        viewController: MultiDayViewController
    ) -> Widget {
        let components = provider.components
        let visibleRange = viewController.pageIndexCalculator
            .dateTimeRangeFromIndex(viewController.currentPage.value)
        let visibleDates = visibleRange.dates()

        // Day headers, one per column.
        var headerCells: [Widget] = []
        for date in visibleDates {
            let callbacks = provider.callbacks
            headerCells.append(Expanded(
                child: GestureDetector(
                    onTap: { callbacks?.onTapped?(date) },
                    child: DayHeader(date: date, style: components.dayHeaderStyle)
                )
            ))
        }

        // The multi-day event lane.
        var laneChildren: [Widget] = []
        if configuration.showTiles {
            let events = provider.eventsController.eventsFromDateTimeRange(
                visibleRange,
                multiDayRule: viewController.viewConfiguration.multiDayRule,
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
                    LayoutId(
                        id: event.id,
                        child: multiDayEventTile(
                            event: event,
                            tileRange: visibleRange,
                            tileComponents: tileComponents,
                            provider: provider
                        )
                    )
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
                color: KalenderColors.surface,
                border: Border(bottom: BorderSide(color: KalenderColors.outline))
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

/// A tile in the multi-day lane: tap selects and reports the event.
func multiDayEventTile(
    event: CalendarEvent,
    tileRange: DateTimeRange,
    tileComponents: TileComponents,
    provider: CalendarProvider
) -> Widget {
    let controller = provider.calendarController
    let callbacks = provider.callbacks
    return GestureDetector(
        onTap: {
            controller.selectEvent(event, internal: true)
            callbacks?.onEventTapped?(event)
        },
        child: Padding(
            padding: EdgeInsets(left: 0, top: 0, right: 3, bottom: 2),
            child: tileComponents.tileBuilder(event, tileRange)
        )
    )
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
        guard let viewController = provider.calendarController.viewController as? MultiDayViewController else {
            assertionFailure("The CalendarController's ViewController needs to be a MultiDayViewController")
            return SizedBox(width: 0, height: 0)
        }

        return KalListenableBuilder(
            listenables: [
                viewController.currentPage,
                viewController.heightPerMinute,
                provider.eventsController,
                provider.calendarController.selectedEvent,
            ],
            builder: { [self] context in
                self._buildBody(context, provider: provider, viewController: viewController)
            }
        )
    }

    private func _buildBody(
        _ context: any BuildContext,
        provider: CalendarProvider,
        viewController: MultiDayViewController
    ) -> Widget {
        let components = provider.components
        let viewConfiguration = viewController.multiDayViewConfiguration
        let timeOfDayRange = viewConfiguration.timeOfDayRange
        let heightPerMinute = viewController.heightPerMinute.value
        let pageHeight = Double(timeOfDayRange.durationInMinutes) * heightPerMinute

        let visibleRange = viewController.pageIndexCalculator
            .dateTimeRangeFromIndex(viewController.currentPage.value)
        let visibleDates = visibleRange.dates()

        var dayColumns: [Widget] = []
        for (index, date) in visibleDates.enumerated() {
            dayColumns.append(Expanded(child: _buildDayColumn(
                date: date,
                isFirst: index == 0,
                pageHeight: pageHeight,
                heightPerMinute: heightPerMinute,
                provider: provider,
                viewController: viewController
            )))
        }

        return SingleChildScrollView(
            controller: viewController.scrollController,
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
        isFirst: Bool,
        pageHeight: Double,
        heightPerMinute: Double,
        provider: CalendarProvider,
        viewController: MultiDayViewController
    ) -> Widget {
        let components = provider.components
        let viewConfiguration = viewController.multiDayViewConfiguration
        let timeOfDayRange = viewConfiguration.timeOfDayRange

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

        // The tap layer: tapping an empty slot creates an event.
        let interaction = provider.interaction
        let callbacks = provider.callbacks
        let eventsController = provider.eventsController
        let controller = provider.calendarController
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
                    let tapDate = dayStart.addingMinutes(snapped)

                    callbacks?.onTapped?(tapDate)
                    controller.deselectEvent()

                    guard interaction.allowEventCreation else { return }
                    let newEvent = CalendarEvent(
                        dateTimeRange: DateTimeRange(
                            start: tapDate,
                            end: tapDate.addingTimeInterval(defaultNewEventDuration)
                        )
                    )
                    guard let toAdd = callbacks?.onEventCreate?(newEvent) else { return }
                    eventsController.addEvent(toAdd)
                    callbacks?.onEventCreated?(toAdd)
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
                heightPerMinute: heightPerMinute,
                provider: provider,
                viewController: viewController
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
        heightPerMinute: Double,
        provider: CalendarProvider,
        viewController: MultiDayViewController
    ) -> Widget {
        let viewConfiguration = viewController.multiDayViewConfiguration
        let dayRange = DateTimeRange(start: date.startOfDay, end: date.endOfDay)

        let events = provider.eventsController.eventsFromDateTimeRange(
            dayRange,
            multiDayRule: viewConfiguration.multiDayRule,
            includeMultiDayEvents: configuration.showMultiDayEvents,
            includeDayEvents: true
        )
        if events.isEmpty { return SizedBox(expand: ()) }

        let delegate = configuration.eventLayoutStrategy(
            events,
            date,
            viewConfiguration.timeOfDayRange,
            heightPerMinute,
            configuration.minimumTileHeight
        )
        // The delegate identifies children by index into its (sorted) events.
        let sorted = delegate.sortEvents(events)
        let sortedDelegate = configuration.eventLayoutStrategy(
            sorted,
            date,
            viewConfiguration.timeOfDayRange,
            heightPerMinute,
            configuration.minimumTileHeight
        )

        let controller = provider.calendarController
        let callbacks = provider.callbacks
        let tiles: [Widget] = sorted.enumerated().map { index, event in
            let isSelected = controller.selectedEventId == event.id
            var tile: Widget = tileComponents.tileBuilder(event, dayRange)
            if isSelected {
                // The tile is inset so the ring stays visible: a decoration
                // paints under its child, and an opaque tile would cover it.
                tile = DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(color: KalenderColors.selection, width: 2),
                        borderRadius: BorderRadius.circular(6)
                    ),
                    child: Padding(padding: EdgeInsets(all: 2), child: tile)
                )
            }
            return LayoutId(id: index, child: GestureDetector(
                onTap: {
                    controller.selectEvent(event, internal: true)
                    callbacks?.onEventTapped?(event)
                },
                child: tile
            ))
        }

        return CustomMultiChildLayout(delegate: sortedDelegate, children: tiles)
    }
}
