// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The provider of the kalender port: the inherited widget that hands the
// bloc and the component styles to every calendar widget below the
// `CalendarView`.

import Flutter
import FlutterSwiftBridge
import Foundation

/// What the calendar widgets read from their surrounding `CalendarView`:
/// the bloc they dispatch to and the components they style with.
public class CalendarProvider: InheritedWidget {
    public let bloc: CalendarBloc
    public let components: CalendarComponents

    public init(
        bloc: CalendarBloc,
        components: CalendarComponents,
        child: Widget
    ) {
        self.bloc = bloc
        self.components = components
        super.init(child: child)
    }

    public override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
        let old = oldWidget as! CalendarProvider
        return old.bloc !== bloc || old.components !== components
    }

    public static func of(_ context: any BuildContext) -> CalendarProvider {
        guard let provider = context.dependOnInheritedWidgetOfExactType(CalendarProvider.self) else {
            fatalError(
                "CalendarProvider.of() called with a context that does not contain a CalendarView."
            )
        }
        return provider
    }
}
