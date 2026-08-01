// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Kalender — the demo of the kalender calendar package
// (github.com/werner-scholtz/kalender), ported to this framework: a calendar
// with Day / Week / Month views, page navigation, seeded events, tap-to-select
// and tap-to-create.
//
//   swift run -c release KalenderApp

#if os(Linux)
import ExampleHost
import Flutter
import FlutterSwiftBridge
import Foundation
import Kalender

// MARK: - Event

/// The demo's event type: kalender's example subclasses `CalendarEvent` the
/// same way to attach a title and color.
final class Event: CalendarEvent {
    let title: String
    let color: Color

    init(
        id: String? = nil,
        dateTimeRange: Kalender.DateTimeRange,
        title: String,
        color: Color = Color(0xFF2196F3)
    ) {
        self.title = title
        self.color = color
        super.init(id: id, dateTimeRange: dateTimeRange)
    }

    override func copyWith(
        dateTimeRange: Kalender.DateTimeRange? = nil,
        interaction: EventInteraction? = nil
    ) -> CalendarEvent {
        Event(
            id: id,
            dateTimeRange: dateTimeRange ?? self.dateTimeRange,
            title: title,
            color: color
        )
    }
}

// MARK: - Seed data

/// A handful of events around "now", so every view has something to show:
/// the shape kalender's example seeds (meetings today, a pair of overlapping
/// events, and a multi-day span in the header lane).
func seedEvents() -> [CalendarEvent] {
    let today = Date().startOfDay

    func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0, lasting minutes: Int) -> Kalender.DateTimeRange {
        let start = today.addingDays(dayOffset).addingMinutes(hour * 60 + minute)
        return Kalender.DateTimeRange(start: start, end: start.addingMinutes(minutes))
    }

    return [
        Event(dateTimeRange: at(0, 9, lasting: 60), title: "Standup", color: Color(0xFF43A047)),
        Event(dateTimeRange: at(0, 11, lasting: 90), title: "Design review", color: Color(0xFF2196F3)),
        // Two overlapping events exercise the side-by-side layout.
        Event(dateTimeRange: at(0, 13, lasting: 120), title: "Pairing", color: Color(0xFFF4511E)),
        Event(dateTimeRange: at(0, 13, 30, lasting: 60), title: "1:1", color: Color(0xFF8E24AA)),
        Event(dateTimeRange: at(1, 10, lasting: 45), title: "Planning", color: Color(0xFF2196F3)),
        Event(dateTimeRange: at(2, 15, lasting: 60), title: "Retro", color: Color(0xFF43A047)),
        Event(dateTimeRange: at(-1, 16, lasting: 30), title: "Coffee chat", color: Color(0xFF8E24AA)),
        // A multi-day event for the header lane and the month view.
        Event(
            dateTimeRange: Kalender.DateTimeRange(
                start: today.addingDays(1),
                end: today.addingDays(4)
            ),
            title: "Conference",
            color: Color(0xFFFB8C00)
        ),
    ]
}

// MARK: - Tiles

/// The event tile: a rounded box in the event's color with its title, the
/// look of kalender's example tile builder.
func eventTileBuilder(_ event: CalendarEvent, _ tileRange: Kalender.DateTimeRange) -> Widget {
    let title = (event as? Event)?.title ?? "Event"
    let color = (event as? Event)?.color ?? Color(0xFF2196F3)
    return DecoratedBox(
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4)
        ),
        child: Padding(
            padding: EdgeInsets(left: 4, top: 2, right: 4, bottom: 2),
            child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                    title,
                    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11),
                    maxLines: 1
                )
            )
        )
    )
}

// MARK: - Toolbar chrome

/// A bordered text button for the toolbar (the framework has no Material
/// button; this is the demo's stand-in).
class ToolbarButton: StatelessWidget {
    let label: String
    let onPressed: () -> Void
    let isActive: Bool

    init(_ label: String, isActive: Bool = false, onPressed: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.onPressed = onPressed
        super.init(key: nil)
    }

    override func build(_ context: any BuildContext) -> Widget {
        GestureDetector(
            onTap: onPressed,
            behavior: .opaque,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: isActive ? Color(0xFF2196F3) : Color(0xFFFFFFFF),
                    border: Border.all(color: isActive ? Color(0xFF2196F3) : Color(0x33000000)),
                    borderRadius: BorderRadius.circular(4)
                ),
                child: Padding(
                    padding: EdgeInsets(left: 10, top: 5, right: 10, bottom: 5),
                    child: Text(
                        label,
                        style: TextStyle(
                            color: isActive ? Color(0xFFFFFFFF) : Color(0xDD000000),
                            fontSize: 12
                        ),
                        maxLines: 1
                    )
                )
            )
        )
    }
}

// MARK: - App

class KalenderHomePage: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _KalenderHomePageState()
    }
}

class _KalenderHomePageState: State<StatefulWidget> {
    private let _eventsController = DefaultEventsController()
    private let _calendarController = CalendarController()

    /// The available views, kalender's example lineup.
    private let _viewConfigurations: [Kalender.ViewConfiguration] = [
        MultiDayViewConfiguration.singleDay(),
        MultiDayViewConfiguration.week(),
        MonthViewConfiguration.singleMonth(),
    ]
    private var _selectedIndex = 1 // Week

    override func initState() {
        super.initState()
        _eventsController.addEvents(seedEvents())
    }

    private var _callbacks: CalendarCallbacks {
        CalendarCallbacks(
            onEventTapped: { event in
                let title = (event as? Event)?.title ?? event.id
                print("[Kalender] tapped: \(title)")
            },
            onEventCreate: { event in
                Event(
                    id: event.id,
                    dateTimeRange: event.dateTimeRange,
                    title: "New Event",
                    color: Color(0xFF607D8B)
                )
            },
            onEventCreated: { event in
                print("[Kalender] created: \(event.dateTimeRange)")
            },
            onPageChanged: { range in
                print("[Kalender] page: \(range)")
            }
        )
    }

    private func _buildToolbar() -> Widget {
        var children: [Widget] = []

        // View switcher.
        for (index, configuration) in _viewConfigurations.enumerated() {
            children.append(ToolbarButton(
                configuration.name,
                isActive: index == _selectedIndex,
                onPressed: { [weak self] in
                    self?.setState { self?._selectedIndex = index }
                }
            ))
            children.append(SizedBox(width: 6, height: 1))
        }

        children.append(Expanded(child: KalListenableBuilder(
            listenable: _calendarController.visibleDateTimeRange,
            builder: { [weak self] _ in
                guard let self, let range = self._calendarController.visibleDateTimeRange.value else {
                    return SizedBox(width: 1, height: 1)
                }
                return Center(child: Text(
                    monthYearName(range.dominantMonthDate),
                    style: TextStyle(color: Color(0xDD000000), fontSize: 15, fontWeight: .w500),
                    maxLines: 1
                ))
            }
        )))

        // Navigation.
        children.append(ToolbarButton("<") { [weak self] in
            self?._calendarController.animateToPreviousPage()
        })
        children.append(SizedBox(width: 6, height: 1))
        children.append(ToolbarButton("Today") { [weak self] in
            self?._calendarController.animateToDate(Date())
        })
        children.append(SizedBox(width: 6, height: 1))
        children.append(ToolbarButton(">") { [weak self] in
            self?._calendarController.animateToNextPage()
        })

        return DecoratedBox(
            decoration: BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(bottom: BorderSide(color: Color(0x1F000000)))
            ),
            child: Padding(
                padding: EdgeInsets(left: 10, top: 8, right: 10, bottom: 8),
                child: Row(crossAxisAlignment: .center, children: children)
            )
        )
    }

    override func build(_ context: any BuildContext) -> Widget {
        let tileComponents = TileComponents(tileBuilder: eventTileBuilder)

        let calendar = CalendarView(
            eventsController: _eventsController,
            calendarController: _calendarController,
            viewConfiguration: _viewConfigurations[_selectedIndex],
            callbacks: _callbacks,
            header: CalendarHeader(multiDayTileComponents: tileComponents),
            body: CalendarBody(
                multiDayTileComponents: tileComponents,
                monthTileComponents: tileComponents
            )
        )

        return ColoredBox(
            color: Color(0xFFFAFAFA),
            child: Column(crossAxisAlignment: .stretch, children: [
                _buildToolbar(),
                Expanded(child: calendar),
            ])
        )
    }
}

runExampleApp(title: "Kalender", width: 960, height: 720) {
    Directionality(textDirection: .ltr, child: KalenderHomePage())
}

#else
fatalError("The example apps currently target Linux desktop sessions.")
#endif
