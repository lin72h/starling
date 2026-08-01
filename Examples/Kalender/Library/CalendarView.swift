// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The root widget of the port: creates the `ViewController` from the
// `ViewConfiguration`, attaches it to the `CalendarController`, provides the
// controllers/callbacks/components to the subtree, and stacks the header
// above the body.
//
// Ported from: kalender/lib/src/calendar_view.dart, calendar_header.dart,
// calendar_body.dart

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - CalendarView

/// A calendar: give it an `EventsController`, a `CalendarController`, a
/// `ViewConfiguration` and a header/body pair (usually `CalendarHeader()` and
/// `CalendarBody()`).
public class CalendarView: StatefulWidget {
    public let eventsController: EventsController
    public let calendarController: CalendarController
    public let viewConfiguration: ViewConfiguration
    public let callbacks: CalendarCallbacks?
    public let components: CalendarComponents
    public let interaction: CalendarInteraction
    public let header: Widget?
    public let body: Widget?

    public init(
        key: (any Key)? = nil,
        eventsController: EventsController,
        calendarController: CalendarController,
        viewConfiguration: ViewConfiguration,
        callbacks: CalendarCallbacks? = nil,
        components: CalendarComponents = CalendarComponents(),
        interaction: CalendarInteraction = CalendarInteraction(),
        header: Widget? = nil,
        body: Widget? = nil
    ) {
        self.eventsController = eventsController
        self.calendarController = calendarController
        self.viewConfiguration = viewConfiguration
        self.callbacks = callbacks
        self.components = components
        self.interaction = interaction
        self.header = header
        self.body = body
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _CalendarViewState()
    }
}

private class _CalendarViewState: State<StatefulWidget> {
    private var _viewController: ViewController?
    /// Guards the notifier subscriptions the same way KalListenableBuilder
    /// does: closures from an earlier generation fall silent.
    private var _generation = 0

    private var _calendarView: CalendarView { widget as! CalendarView }

    override func initState() {
        super.initState()
        _createAndAttach()
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let old = oldWidget as! CalendarView
        let new = _calendarView

        if old.calendarController !== new.calendarController {
            old.calendarController.detach()
            if let viewController = _viewController {
                new.calendarController.attach(viewController)
            }
        }

        // A different view configuration replaces the view controller. The
        // focused date carries across (kalender's carryFocus default): a
        // month view's range starts in the previous month's trailing week,
        // so it contributes its dominant month rather than its range start.
        if old.viewConfiguration != new.viewConfiguration
            || old.eventsController !== new.eventsController {
            var focusedDate: Date?
            if let range = _viewController?.visibleDateTimeRange.value {
                focusedDate = _viewController is MonthViewController
                    ? range.dominantMonthDate
                    : range.start
            }
            _viewController?.dispose()
            _createAndAttach(focusedDate: focusedDate)
            setState {}
        }
    }

    override func dispose() {
        _generation += 1
        _viewController?.dispose()
        _calendarView.calendarController.detach()
        super.dispose()
    }

    private func _createAndAttach(focusedDate: Date? = nil) {
        let view = _calendarView
        let initialDate = view.viewConfiguration.initialDateTime ?? focusedDate

        let viewController: ViewController
        switch view.viewConfiguration {
        case let configuration as MultiDayViewConfiguration:
            viewController = MultiDayViewController(
                viewConfiguration: configuration,
                visibleDateTimeRange: ValueNotifier<DateTimeRange?>(nil),
                visibleEvents: ValueNotifier<Set<CalendarEvent>>([]),
                initialDate: initialDate
            )
        case let configuration as MonthViewConfiguration:
            viewController = MonthViewController(
                viewConfiguration: configuration,
                visibleDateTimeRange: ValueNotifier<DateTimeRange?>(nil),
                visibleEvents: ValueNotifier<Set<CalendarEvent>>([]),
                initialDate: initialDate
            )
        default:
            fatalError("Unsupported ViewConfiguration: \(view.viewConfiguration.name)")
        }

        _viewController = viewController
        view.calendarController.attach(viewController)

        // Keep `visibleEvents` and the page-change callback current from
        // outside the build phase: page jumps and event mutations both start
        // from user actions.
        _generation += 1
        let generation = _generation
        let updateVisibleEvents: () -> Void = { [weak self, weak viewController] in
            guard let self, self._generation == generation,
                  let viewController, let view = self.widget as? CalendarView else { return }
            guard let range = viewController.visibleDateTimeRange.value else { return }
            let events = view.eventsController.eventsFromDateTimeRange(
                range,
                multiDayRule: viewController.viewConfiguration.multiDayRule
            )
            viewController.visibleEvents.value = Set(events)
        }
        updateVisibleEvents()

        viewController.currentPage.addListener { [weak self, weak viewController] in
            guard let self, self._generation == generation, let viewController else { return }
            updateVisibleEvents()
            if let range = viewController.visibleDateTimeRange.value {
                (self.widget as? CalendarView)?.callbacks?.onPageChanged?(range)
            }
        }
        view.eventsController.addListener {
            updateVisibleEvents()
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        let view = _calendarView

        var columnChildren: [Widget] = []
        if let header = view.header {
            columnChildren.append(header)
        }
        if let body = view.body {
            columnChildren.append(Expanded(child: body))
        }

        return CalendarProvider(
            eventsController: view.eventsController,
            calendarController: view.calendarController,
            callbacks: view.callbacks,
            components: view.components,
            interaction: view.interaction,
            child: Column(crossAxisAlignment: .stretch, children: columnChildren)
        )
    }
}

// MARK: - CalendarHeader

/// Creates the correct header for the attached view controller:
/// `MultiDayHeader` or `MonthHeader`.
public class CalendarHeader: StatelessWidget {
    public let multiDayTileComponents: TileComponents?
    public let multiDayHeaderConfiguration: MultiDayHeaderConfiguration?

    public init(
        key: (any Key)? = nil,
        multiDayTileComponents: TileComponents? = nil,
        multiDayHeaderConfiguration: MultiDayHeaderConfiguration? = nil
    ) {
        self.multiDayTileComponents = multiDayTileComponents
        self.multiDayHeaderConfiguration = multiDayHeaderConfiguration
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let provider = CalendarProvider.of(context)
        switch provider.calendarController.viewController {
        case is MultiDayViewController:
            return MultiDayHeader(
                configuration: multiDayHeaderConfiguration ?? MultiDayHeaderConfiguration(),
                tileComponents: multiDayTileComponents ?? .defaultComponents()
            )
        case is MonthViewController:
            return MonthHeader()
        default:
            assertionFailure("Unsupported ViewController type for CalendarHeader")
            return SizedBox(width: 0, height: 0)
        }
    }
}

// MARK: - CalendarBody

/// Creates the correct body for the attached view controller:
/// `MultiDayBody` or `MonthBody`.
public class CalendarBody: StatelessWidget {
    public let multiDayTileComponents: TileComponents?
    public let multiDayBodyConfiguration: MultiDayBodyConfiguration?
    public let monthTileComponents: TileComponents?
    public let monthBodyConfiguration: MultiDayHeaderConfiguration?

    public init(
        key: (any Key)? = nil,
        multiDayTileComponents: TileComponents? = nil,
        multiDayBodyConfiguration: MultiDayBodyConfiguration? = nil,
        monthTileComponents: TileComponents? = nil,
        monthBodyConfiguration: MultiDayHeaderConfiguration? = nil
    ) {
        self.multiDayTileComponents = multiDayTileComponents
        self.multiDayBodyConfiguration = multiDayBodyConfiguration
        self.monthTileComponents = monthTileComponents
        self.monthBodyConfiguration = monthBodyConfiguration
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let provider = CalendarProvider.of(context)
        switch provider.calendarController.viewController {
        case is MultiDayViewController:
            return MultiDayBody(
                configuration: multiDayBodyConfiguration ?? MultiDayBodyConfiguration(),
                tileComponents: multiDayTileComponents ?? .defaultComponents()
            )
        case is MonthViewController:
            return MonthBody(
                configuration: monthBodyConfiguration
                    ?? MultiDayHeaderConfiguration(allowSingleDayEvents: true),
                tileComponents: monthTileComponents ?? .defaultComponents()
            )
        default:
            assertionFailure("Unsupported ViewController type for CalendarBody")
            return SizedBox(width: 0, height: 0)
        }
    }
}
