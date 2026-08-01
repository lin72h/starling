// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The customization surface of the kalender port: tile builders, the style
// classes of the default components, and the palette they fall back to. The
// Dart package resolves default colors from the Material theme; the framework
// carries no Material theme, so the fallbacks are the Material-2-ish palette
// the example ports use.
//
// Ported from: kalender/lib/src/models/components/tile_components.dart,
// components.dart and the widgets/components/*.dart style classes.

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - Palette

/// The default colors of the kalender port's components.
public enum CalendarColors {
    public static let onSurface = Color(0xDD000000)          // black87
    public static let onSurfaceVariant = Color(0x8A000000)   // black54
    public static let outline = Color(0x1F000000)            // black12
    public static let surface = Color(0xFFFFFFFF)
    public static let primary = Color(0xFF2196F3)            // blue 500
    public static let primaryContainer = Color(0xFFBBDEFB)   // blue 100
    public static let onPrimaryContainer = Color(0xFF0D47A1) // blue 900
    public static let onPrimary = Color(0xFFFFFFFF)
    public static let timeIndicator = Color(0xFFF44336)      // red 500
    public static let selection = Color(0xFF1565C0)          // blue 800
}

// MARK: - Tile components

/// Builds the widget for an event tile.
///
/// `event` is the event the tile is built for; `tileRange` is the range of
/// the view slot the tile is displayed in.
public typealias TileBuilder = (_ event: CalendarEvent, _ tileRange: DateTimeRange) -> Widget

/// The components used by the bodies and headers to render event tiles.
///
/// The Dart original also carries drag feedback/drop-target builders used by
/// its drag-and-drop machinery; this port keeps the stationary builders.
public final class TileComponents {
    /// The builder for stationary event tiles.
    public let tileBuilder: TileBuilder

    /// The builder used for tiles in overflow situations (month "+n more"
    /// lanes use the regular builder when this is nil).
    public let overlayTileBuilder: TileBuilder?

    public init(
        tileBuilder: @escaping TileBuilder,
        overlayTileBuilder: TileBuilder? = nil
    ) {
        self.tileBuilder = tileBuilder
        self.overlayTileBuilder = overlayTileBuilder
    }

    public static func defaultComponents() -> TileComponents {
        TileComponents(tileBuilder: defaultTileBuilder)
    }
}

/// The default tile: a rounded rectangle in the primary-container color.
public func defaultTileBuilder(_ event: CalendarEvent, _ tileRange: DateTimeRange) -> Widget {
    DecoratedBox(
        decoration: BoxDecoration(
            color: CalendarColors.primaryContainer,
            borderRadius: BorderRadius.circular(4)
        )
    ) { SizedBox(expand: ()) }
}

// MARK: - Component styles

/// Styles the `TimeLine` (the hour labels down the left gutter).
public struct TimelineStyle {
    public let textStyle: Flutter.TextStyle?
    public let width: Double

    public init(textStyle: Flutter.TextStyle? = nil, width: Double = 52) {
        self.textStyle = textStyle
        self.width = width
    }
}

/// Styles the `HourLines` painted across the body.
public struct HourLinesStyle {
    public let color: Color
    public let thickness: Double

    public init(color: Color = CalendarColors.outline, thickness: Double = 1) {
        self.color = color
        self.thickness = thickness
    }
}

/// Styles the `DaySeparator` between day columns.
public struct DaySeparatorStyle {
    public let color: Color
    public let width: Double

    public init(color: Color = CalendarColors.outline, width: Double = 1) {
        self.color = color
        self.width = width
    }
}

/// Styles the `DayHeader` above each day column.
public struct DayHeaderStyle {
    public let textStyle: Flutter.TextStyle?
    public let numberTextStyle: Flutter.TextStyle?

    public init(textStyle: Flutter.TextStyle? = nil, numberTextStyle: Flutter.TextStyle? = nil) {
        self.textStyle = textStyle
        self.numberTextStyle = numberTextStyle
    }
}

/// Styles the `WeekDayHeader` used by the month view.
public struct WeekDayHeaderStyle {
    public let textStyle: Flutter.TextStyle?

    public init(textStyle: Flutter.TextStyle? = nil) {
        self.textStyle = textStyle
    }
}

/// Styles the `MonthDayHeader` (the day number in a month cell).
public struct MonthDayHeaderStyle {
    public let textStyle: Flutter.TextStyle?

    public init(textStyle: Flutter.TextStyle? = nil) {
        self.textStyle = textStyle
    }
}

/// Styles the `MonthGrid` lines.
public struct MonthGridStyle {
    public let color: Color
    public let thickness: Double

    public init(color: Color = CalendarColors.outline, thickness: Double = 1) {
        self.color = color
        self.thickness = thickness
    }
}

/// Styles the `TimeIndicator` (the "now" line).
public struct TimeIndicatorStyle {
    public let color: Color
    public let thickness: Double
    public let circleRadius: Double

    public init(
        color: Color = CalendarColors.timeIndicator,
        thickness: Double = 2,
        circleRadius: Double = 4
    ) {
        self.color = color
        self.thickness = thickness
        self.circleRadius = circleRadius
    }
}

// MARK: - CalendarComponents

/// The components and styles used by the calendar. The Dart original lets
/// every component widget be swapped by builder; this port carries the style
/// knobs (and the tile builders through `CalendarHeader` / `CalendarBody`).
public final class CalendarComponents {
    public let timelineStyle: TimelineStyle
    public let hourLinesStyle: HourLinesStyle
    public let daySeparatorStyle: DaySeparatorStyle
    public let dayHeaderStyle: DayHeaderStyle
    public let weekDayHeaderStyle: WeekDayHeaderStyle
    public let monthDayHeaderStyle: MonthDayHeaderStyle
    public let monthGridStyle: MonthGridStyle
    public let timeIndicatorStyle: TimeIndicatorStyle

    public init(
        timelineStyle: TimelineStyle = TimelineStyle(),
        hourLinesStyle: HourLinesStyle = HourLinesStyle(),
        daySeparatorStyle: DaySeparatorStyle = DaySeparatorStyle(),
        dayHeaderStyle: DayHeaderStyle = DayHeaderStyle(),
        weekDayHeaderStyle: WeekDayHeaderStyle = WeekDayHeaderStyle(),
        monthDayHeaderStyle: MonthDayHeaderStyle = MonthDayHeaderStyle(),
        monthGridStyle: MonthGridStyle = MonthGridStyle(),
        timeIndicatorStyle: TimeIndicatorStyle = TimeIndicatorStyle()
    ) {
        self.timelineStyle = timelineStyle
        self.hourLinesStyle = hourLinesStyle
        self.daySeparatorStyle = daySeparatorStyle
        self.dayHeaderStyle = dayHeaderStyle
        self.weekDayHeaderStyle = weekDayHeaderStyle
        self.monthDayHeaderStyle = monthDayHeaderStyle
        self.monthGridStyle = monthGridStyle
        self.timeIndicatorStyle = timeIndicatorStyle
    }
}

// MARK: - Localized names

/// Short weekday name ("Mon") for a date, from the current locale.
public func weekdayNameShort(_ date: Date) -> String {
    let symbols = calendarSystem.shortWeekdaySymbols // Sunday-first
    let index = calendarSystem.component(.weekday, from: date) - 1
    if symbols.indices.contains(index) { return symbols[index] }
    return ""
}

/// Month-and-year title ("July 2026") for a date, from the current locale.
public func monthYearName(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendarSystem
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

/// Hour label for the timeline gutter ("7 AM" / "07:00" per locale).
public func hourLabel(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendarSystem
    formatter.locale = Locale.current
    formatter.setLocalizedDateFormatFromTemplate("j")
    var components = DateComponents()
    components.year = 2001
    components.month = 1
    components.day = 1
    components.hour = hour
    guard let date = calendarSystem.date(from: components) else { return "\(hour)" }
    return formatter.string(from: date)
}
