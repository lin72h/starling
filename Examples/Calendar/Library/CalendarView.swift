// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The root widgets of the port: `CalendarView` provides the bloc and the
// components to the subtree and stacks the header above the body;
// `CalendarHeader` / `CalendarBody` pick the concrete header/body for the
// state's current view configuration.
//
// Rebuilds follow the FileExplorerApp pattern: the header/body switchers are
// the observation roots — their builds run inside `withObservationTracking`,
// and any mutation of `bloc.state` re-runs them (children are fresh widget
// instances each time, so the whole calendar below rebuilds against the new
// state).

import Flutter
import FlutterSwiftBridge
import Foundation
import Observation

// MARK: - CalendarView

/// A calendar: give it a `CalendarBloc` and a header/body pair (usually
/// `CalendarHeader()` and `CalendarBody()`).
public class CalendarView: StatelessWidget {
    public let bloc: CalendarBloc
    public let components: CalendarComponents
    public let header: Widget?
    public let body: Widget?

    public init(
        key: (any Key)? = nil,
        bloc: CalendarBloc,
        components: CalendarComponents = CalendarComponents(),
        header: Widget? = nil,
        body: Widget? = nil
    ) {
        self.bloc = bloc
        self.components = components
        self.header = header
        self.body = body
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        var columnChildren: [Widget] = []
        if let header {
            columnChildren.append(header)
        }
        if let body {
            columnChildren.append(Expanded(child: body))
        }

        return CalendarProvider(
            bloc: bloc,
            components: components,
            child: Column(crossAxisAlignment: .stretch, children: columnChildren)
        )
    }
}

// MARK: - Observation root

/// Shared State base for the header/body switchers: builds through
/// `withObservationTracking` and re-renders on any `bloc.state` mutation.
/// The mutation always happens on the platform thread (gesture handlers run
/// there, and so does everything else in this host), so `setState` is called
/// directly rather than hopping through a MainActor task.
class ObservingCalendarState: State<StatefulWidget> {
    func buildTracked(_ context: any BuildContext) -> Widget {
        fatalError("Subclasses must override buildTracked")
    }

    override func build(_ context: any BuildContext) -> Widget {
        return withObservationTracking {
            buildTracked(context)
        } onChange: { [weak self] in
            guard let self, self.mounted else { return }
            self.setState {}
        }
    }
}

// MARK: - CalendarHeader

/// Creates the correct header for the state's current view:
/// `MultiDayHeader` or `MonthHeader`.
public class CalendarHeader: StatefulWidget {
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

    public override func createState() -> State<StatefulWidget> {
        return _CalendarHeaderState()
    }
}

private class _CalendarHeaderState: ObservingCalendarState {
    override func buildTracked(_ context: any BuildContext) -> Widget {
        let header = widget as! CalendarHeader
        let provider = CalendarProvider.of(context)
        switch provider.bloc.state.viewConfiguration {
        case is MultiDayViewConfiguration:
            return MultiDayHeader(
                configuration: header.multiDayHeaderConfiguration ?? MultiDayHeaderConfiguration(),
                tileComponents: header.multiDayTileComponents ?? .defaultComponents()
            )
        case is MonthViewConfiguration:
            return MonthHeader()
        default:
            assertionFailure("Unsupported ViewConfiguration for CalendarHeader")
            return SizedBox(width: 0, height: 0)
        }
    }
}

// MARK: - CalendarBody

/// Creates the correct body for the state's current view:
/// `MultiDayBody` or `MonthBody`.
public class CalendarBody: StatefulWidget {
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

    public override func createState() -> State<StatefulWidget> {
        return _CalendarBodyState()
    }
}

private class _CalendarBodyState: ObservingCalendarState {
    override func buildTracked(_ context: any BuildContext) -> Widget {
        let body = widget as! CalendarBody
        let provider = CalendarProvider.of(context)
        switch provider.bloc.state.viewConfiguration {
        case is MultiDayViewConfiguration:
            return MultiDayBody(
                configuration: body.multiDayBodyConfiguration ?? MultiDayBodyConfiguration(),
                tileComponents: body.multiDayTileComponents ?? .defaultComponents()
            )
        case is MonthViewConfiguration:
            return MonthBody(
                configuration: body.monthBodyConfiguration
                    ?? MultiDayHeaderConfiguration(allowSingleDayEvents: true),
                tileComponents: body.monthTileComponents ?? .defaultComponents()
            )
        default:
            assertionFailure("Unsupported ViewConfiguration for CalendarBody")
            return SizedBox(width: 0, height: 0)
        }
    }
}
