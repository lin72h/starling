// MacosProgressIndicator ported from macos_ui/lib/src/indicators/progress_indicators.dart

import FlutterSwiftBridge

// MARK: - MacosProgressIndicator

/// A linear progress indicator following macOS design.
///
/// When [value] is nil, displays an indeterminate animation.
/// When [value] is between 0.0 and 1.0, displays determinate progress.
public class MacosProgressIndicator: StatelessWidget {
    /// The current progress value, from 0.0 to 1.0. Nil for indeterminate.
    public let value: Double?

    /// The height of the progress bar. Defaults to 4.
    public let height: Double

    /// The color of the progress bar.
    public let color: Color?

    /// The background track color.
    public let trackColor: Color?

    public init(
        key: (any Key)? = nil,
        value: Double? = nil,
        height: Double = 4,
        color: Color? = nil,
        trackColor: Color? = nil
    ) {
        self.value = value
        self.height = height
        self.color = color
        self.trackColor = trackColor
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let progressColor = color ?? theme.primaryColor
        let bgColor = trackColor ?? (isDark
            ? Color(rgbo: 255, 255, 255, 0.1)
            : Color(rgbo: 0, 0, 0, 0.06))

        if let value = value {
            return SizedBox(
                height: height,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.all(Radius(circular: height / 2))
                    ),
                    child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: Swift.min(Swift.max(value, 0), 1),
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.all(Radius(circular: height / 2))
                            )
                        )
                    )
                )
            )
        } else {
            // Indeterminate: show full track (animation would require AnimationController)
            return SizedBox(
                height: height,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.all(Radius(circular: height / 2))
                    ),
                    child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.3,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.all(Radius(circular: height / 2))
                            )
                        )
                    )
                )
            )
        }
    }
}

// MARK: - MacosSlider

/// A macOS-style slider control for selecting a value from a range.
public class MacosSlider: StatelessWidget {
    public let value: Double
    public let onChanged: ((Double) -> Void)?
    public let min: Double
    public let max: Double
    public let color: Color?

    public init(
        key: (any Key)? = nil,
        value: Double,
        onChanged: ((Double) -> Void)? = nil,
        min: Double = 0.0,
        max: Double = 1.0,
        color: Color? = nil
    ) {
        self.value = value
        self.onChanged = onChanged
        self.min = min
        self.max = max
        self.color = color
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark
        let trackColor = color ?? theme.primaryColor

        let fraction = (value - min) / (max - min)

        let trackBg = isDark
            ? Color(rgbo: 255, 255, 255, 0.1)
            : Color(rgbo: 0, 0, 0, 0.1)

        let thumbColor = isDark
            ? Color(rgbo: 152, 152, 157, 1.0)
            : MacosColors.white

        return SizedBox(
            height: 20,
            child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                    // Track background
                    SizedBox(
                        height: 4,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: trackBg,
                                borderRadius: BorderRadius.all(Radius(circular: 2))
                            )
                        )
                    ),
                    // Active track
                    FractionallySizedBox(
                        widthFactor: Swift.min(Swift.max(fraction, 0), 1),
                        child: SizedBox(
                            height: 4,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: trackColor,
                                    borderRadius: BorderRadius.all(Radius(circular: 2))
                                )
                            )
                        )
                    ),
                    // Thumb indicator
                    Positioned(
                        left: 0, // Simplified -- real implementation needs layout width
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: thumbColor,
                                    boxShadow: [
                                        BoxShadow(
                                            color: Color(rgbo: 0, 0, 0, 0.2),
                                            offset: Offset(0, 1),
                                            blurRadius: 2
                                        )
                                    ],
                                    shape: .circle
                                )
                            )
                        )
                    )
                ]
            )
        )
    }
}

// MARK: - CapacityIndicator

/// A macOS-style capacity indicator showing usage levels.
public class CapacityIndicator: StatelessWidget {
    public let value: Double
    public let color: Color?
    public let backgroundColor: Color?

    public init(
        key: (any Key)? = nil,
        value: Double,
        color: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        self.value = value
        self.color = color
        self.backgroundColor = backgroundColor
        super.init(key: key)
    }

    public override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let barColor: Color
        if let color = color {
            barColor = color
        } else if value > 0.8 {
            barColor = MacosColors.systemRed(for: theme.brightness)
        } else if value > 0.6 {
            barColor = MacosColors.systemYellow(for: theme.brightness)
        } else {
            barColor = MacosColors.systemGreen(for: theme.brightness)
        }

        let bgColor = backgroundColor ?? (isDark
            ? Color(rgbo: 255, 255, 255, 0.1)
            : Color(rgbo: 0, 0, 0, 0.06))

        return SizedBox(
            height: 16,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.all(Radius(circular: 3))
                ),
                child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: Swift.min(Swift.max(value, 0), 1),
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.all(Radius(circular: 3))
                        )
                    )
                )
            )
        )
    }
}
