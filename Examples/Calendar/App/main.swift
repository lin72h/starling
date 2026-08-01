// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Kalender — the demo of the kalender calendar package
// (github.com/werner-scholtz/kalender), ported to this framework: a calendar
// with Day / Week / Month views, page navigation, seeded events, tap-to-select
// and tap-to-create — all driven through a single CalendarBloc.
//
//   swift run -c release CalendarApp

#if os(Linux)
import ExampleHost
import Flutter
import FlutterSwiftBridge
import Foundation
import CalendarKit
import Observation

// MARK: - Event

/// The demo's event type: a `CalendarEvent` subclass carrying a title and a
/// color for the tiles.
final class Event: CalendarEvent {
    let title: String
    let color: Color

    init(
        id: String? = nil,
        dateTimeRange: CalendarKit.DateTimeRange,
        title: String,
        color: Color = Color(0xFF2196F3)
    ) {
        self.title = title
        self.color = color
        super.init(id: id, dateTimeRange: dateTimeRange)
    }

    override func copyWith(
        dateTimeRange: CalendarKit.DateTimeRange? = nil,
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

// MARK: - Bloc

/// The demo's bloc: the library's `CalendarBloc` with one template method
/// overridden so tap-created events carry the demo's payload.
final class DemoCalendarBloc: CalendarBloc {
    override func makeEvent(for dateTimeRange: CalendarKit.DateTimeRange) -> CalendarEvent {
        // Qualified: inside a CalendarBloc subclass, bare `Event` is the
        // nested CalendarBloc.Event dispatch enum, not the app's model type.
        CalendarApp.Event(dateTimeRange: dateTimeRange, title: "New Event", color: Color(0xFF607D8B))
    }
}

// MARK: - Seed data

/// A handful of events around "now", so every view has something to show:
/// meetings today, a pair of overlapping events for the side-by-side layout,
/// and a multi-day span for the header lane.
func seedEvents() -> [CalendarEvent] {
    let today = Date().startOfDay

    func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0, lasting minutes: Int) -> CalendarKit.DateTimeRange {
        let start = today.addingDays(dayOffset).addingMinutes(hour * 60 + minute)
        return CalendarKit.DateTimeRange(start: start, end: start.addingMinutes(minutes))
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
            dateTimeRange: CalendarKit.DateTimeRange(
                start: today.addingDays(1),
                end: today.addingDays(4)
            ),
            title: "Conference",
            color: Color(0xFFFB8C00)
        ),
    ]
}

// MARK: - Tiles

/// The event tile: a rounded box in the event's color with its title.
func eventTileBuilder(_ event: CalendarEvent, _ tileRange: CalendarKit.DateTimeRange) -> Widget {
    let title = (event as? Event)?.title ?? "Event"
    let color = (event as? Event)?.color ?? Color(0xFF2196F3)
    return DecoratedBox(
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4)
        )
    ) {
        Padding(padding: EdgeInsets(left: 4, top: 2, right: 4, bottom: 2)) {
            Align(alignment: Alignment.topLeft) {
                Text(
                    title,
                    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11),
                    maxLines: 1
                )
            }
        }
    }
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
                )
            ) {
                Padding(padding: EdgeInsets(left: 10, top: 5, right: 10, bottom: 5)) {
                    Text(
                        label,
                        style: TextStyle(
                            color: isActive ? Color(0xFFFFFFFF) : Color(0xDD000000),
                            fontSize: 12
                        ),
                        maxLines: 1
                    )
                }
            }
        )
    }
}

// MARK: - App

class CalendarHomePage: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _CalendarHomePageState()
    }
}

class _CalendarHomePageState: State<StatefulWidget> {
    let bloc = DemoCalendarBloc(
        viewConfigurations: [
            MultiDayViewConfiguration.singleDay(),
            MultiDayViewConfiguration.week(),
            MonthViewConfiguration.singleMonth(),
        ],
        initialViewIndex: 1, // Week
        events: seedEvents()
    )

    override func build(_ context: any BuildContext) -> Widget {
        return withObservationTracking {
            _buildContent(context)
        } onChange: { [weak self] in
            guard let self, self.mounted else { return }
            self.setState {}
        }
    }

    private func _buildContent(_ context: any BuildContext) -> Widget {
        return ColoredBox(color: Color(0xFFFAFAFA)) {
            Column(crossAxisAlignment: .stretch) {
                _buildToolbar()
                Expanded { _buildCalendar() }
            }
        }
    }

    private func _buildToolbar() -> Widget {
        let s = bloc.state

        return DecoratedBox(
            decoration: BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(bottom: BorderSide(color: Color(0x1F000000)))
            )
        ) {
            Padding(padding: EdgeInsets(left: 10, top: 8, right: 10, bottom: 8)) {
                Row(crossAxisAlignment: .center) {
                    // View switcher.
                    for (index, configuration) in s.viewConfigurations.enumerated() {
                        ToolbarButton(
                            configuration.name,
                            isActive: index == s.selectedViewIndex
                        ) { [self] in bloc.add(.switchView(index: index)) }
                        SizedBox(width: 6, height: 1)
                    }

                    // Title.
                    Expanded {
                        Center {
                            Text(
                                monthYearName(s.visibleDateTimeRange.dominantMonthDate),
                                style: TextStyle(color: Color(0xDD000000), fontSize: 15, fontWeight: .w500),
                                maxLines: 1
                            )
                        }
                    }

                    // Navigation.
                    ToolbarButton("<") { [self] in bloc.add(.previousPage) }
                    SizedBox(width: 6, height: 1)
                    ToolbarButton("Today") { [self] in bloc.add(.jumpToToday) }
                    SizedBox(width: 6, height: 1)
                    ToolbarButton(">") { [self] in bloc.add(.nextPage) }
                }
            }
        }
    }

    private func _buildCalendar() -> Widget {
        let tileComponents = TileComponents(tileBuilder: eventTileBuilder)
        return CalendarView(
            bloc: bloc,
            header: CalendarHeader(multiDayTileComponents: tileComponents),
            body: CalendarBody(
                multiDayTileComponents: tileComponents,
                monthTileComponents: tileComponents
            )
        )
    }
}

runExampleApp(title: "Calendar", width: 960, height: 720) {
    Directionality(textDirection: .ltr, child: CalendarHomePage())
}

#else
fatalError("The example apps currently target Linux desktop sessions.")
#endif
