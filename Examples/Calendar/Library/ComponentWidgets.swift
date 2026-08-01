// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The default component widgets of the kalender port: the timeline gutter,
// hour lines, day separators, day headers, the "now" indicator and the month
// grid pieces.
//
// Ported from: kalender/lib/src/widgets/components/*.dart

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - TimeLine

/// The hour labels down the left gutter of a multi-day body. Each label is
/// centered on its hour line; the first and last hours are skipped like the
/// Dart component (they would collide with the header and the bottom edge).
public class TimeLine: StatelessWidget {
    public let timeOfDayRange: TimeOfDayRange
    public let heightPerMinute: Double
    public let style: TimelineStyle

    public init(
        timeOfDayRange: TimeOfDayRange,
        heightPerMinute: Double,
        style: TimelineStyle,
        key: (any Key)? = nil
    ) {
        self.timeOfDayRange = timeOfDayRange
        self.heightPerMinute = heightPerMinute
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let textStyle = style.textStyle
            ?? TextStyle(color: CalendarColors.onSurfaceVariant, fontSize: 10)
        let startMinutes = timeOfDayRange.start.totalMinutes

        var children: [Widget] = []
        let lastHour = timeOfDayRange.end.hour
        var hour = timeOfDayRange.start.hour + 1
        while hour <= lastHour {
            let y = Double(hour * 60 - startMinutes) * heightPerMinute
            children.append(Positioned(
                top: y - 7,
                right: 6,
                child: Text(hourLabel(hour), style: textStyle, maxLines: 1)
            ))
            hour += 1
        }

        return Stack(clipBehavior: .none, children: children)
    }
}

// MARK: - HourLines

/// The horizontal lines marking each hour, drawn behind the events of a day
/// column. Rendered as positioned hairlines since the column height is known
/// exactly (minutes x heightPerMinute).
public class HourLines: StatelessWidget {
    public let timeOfDayRange: TimeOfDayRange
    public let heightPerMinute: Double
    public let style: HourLinesStyle

    public init(
        timeOfDayRange: TimeOfDayRange,
        heightPerMinute: Double,
        style: HourLinesStyle,
        key: (any Key)? = nil
    ) {
        self.timeOfDayRange = timeOfDayRange
        self.heightPerMinute = heightPerMinute
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let startMinutes = timeOfDayRange.start.totalMinutes
        var children: [Widget] = []
        var hour = timeOfDayRange.start.hour + 1
        while hour <= timeOfDayRange.end.hour {
            let y = Double(hour * 60 - startMinutes) * heightPerMinute
            children.append(Positioned(
                left: 0,
                top: y - style.thickness / 2,
                right: 0,
                height: style.thickness,
                child: ColoredBox(color: style.color, child: SizedBox(expand: ()))
            ))
            hour += 1
        }
        return Stack(children: children)
    }
}

// MARK: - DayHeader

/// The header above a day column: short weekday name over the day number,
/// with today's number highlighted in a filled circle.
public class DayHeader: StatelessWidget {
    public let date: Date
    public let style: DayHeaderStyle

    public init(date: Date, style: DayHeaderStyle, key: (any Key)? = nil) {
        self.date = date
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let isToday = date.isToday
        let nameStyle = style.textStyle
            ?? TextStyle(color: CalendarColors.onSurfaceVariant, fontSize: 11)
        let numberStyle = style.numberTextStyle
            ?? TextStyle(
                color: isToday ? CalendarColors.onPrimary : CalendarColors.onSurface,
                fontSize: 16
            )

        let number: Widget = isToday
            ? DecoratedBox(
                decoration: BoxDecoration(color: CalendarColors.primary, shape: .circle),
                child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(child: Text("\(date.calDay)", style: numberStyle))
                )
            )
            : SizedBox(
                width: 28,
                height: 28,
                child: Center(child: Text("\(date.calDay)", style: numberStyle))
            )

        return Padding(
            padding: EdgeInsets(vertical: 4),
            child: Column(mainAxisAlignment: .center, children: [
                Text(weekdayNameShort(date), style: nameStyle),
                SizedBox(width: 1, height: 2),
                number,
            ])
        )
    }
}

// MARK: - WeekDayHeader

/// A weekday-name label for the month view's header row.
public class WeekDayHeader: StatelessWidget {
    public let date: Date
    public let style: WeekDayHeaderStyle

    public init(date: Date, style: WeekDayHeaderStyle, key: (any Key)? = nil) {
        self.date = date
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let textStyle = style.textStyle
            ?? TextStyle(color: CalendarColors.onSurfaceVariant, fontSize: 11)
        return Padding(
            padding: EdgeInsets(vertical: 4),
            child: Center(child: Text(weekdayNameShort(date), style: textStyle))
        )
    }
}

// MARK: - MonthDayHeader

/// The day number at the top of a month cell; today gets the filled circle,
/// days outside the focused month are dimmed.
public class MonthDayHeader: StatelessWidget {
    public let date: Date
    public let isInFocusedMonth: Bool
    public let style: MonthDayHeaderStyle

    public init(
        date: Date,
        isInFocusedMonth: Bool,
        style: MonthDayHeaderStyle,
        key: (any Key)? = nil
    ) {
        self.date = date
        self.isInFocusedMonth = isInFocusedMonth
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let isToday = date.isToday
        let color: Color = isToday
            ? CalendarColors.onPrimary
            : (isInFocusedMonth ? CalendarColors.onSurface : CalendarColors.onSurfaceVariant)
        let textStyle = style.textStyle ?? TextStyle(color: color, fontSize: 12)

        let number: Widget = isToday
            ? DecoratedBox(
                decoration: BoxDecoration(color: CalendarColors.primary, shape: .circle),
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(child: Text("\(date.calDay)", style: textStyle))
                )
            )
            : SizedBox(
                width: 22,
                height: 22,
                child: Center(child: Text("\(date.calDay)", style: textStyle))
            )

        return Padding(padding: EdgeInsets(vertical: 2), child: Center(child: number))
    }
}

// MARK: - TimeIndicator

/// The "now" line: a hairline across today's column with a dot on its left
/// edge. Positioned by the parent; this widget is the line itself.
public class TimeIndicator: StatelessWidget {
    public let style: TimeIndicatorStyle

    public init(style: TimeIndicatorStyle, key: (any Key)? = nil) {
        self.style = style
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        Stack(clipBehavior: .none, children: [
            Positioned(
                left: 0,
                top: style.circleRadius - style.thickness / 2,
                right: 0,
                height: style.thickness,
                child: ColoredBox(color: style.color, child: SizedBox(expand: ()))
            ),
            Positioned(
                left: -style.circleRadius,
                top: 0,
                width: style.circleRadius * 2,
                height: style.circleRadius * 2,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: style.color, shape: .circle),
                    child: SizedBox(expand: ())
                )
            ),
        ])
    }
}
