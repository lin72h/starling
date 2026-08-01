// MacosProgressIndicator ported from macos_ui/lib/src/indicators/progress_indicators.dart

import FlutterSwiftBridge
import Foundation

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

/// A macOS-style slider: thin rounded track filled to the thumb in the
/// accent colour, round white thumb. Click jumps, drag tracks — a real
/// control (the original was display-only, thumb pinned at zero, and
/// every caller that needed a working slider reached for the Fluent one
/// in a macOS-styled desktop).
///
/// Controlled component: the thumb draws from `value`; `onChanged` fires
/// continuously during a drag and once for a click, `onChangeStart`/
/// `onChangeEnd` bracket a gesture for callers that want to commit work
/// (a seek, a file write) once per gesture rather than per pixel.
public class MacosSlider: StatefulWidget {
    public let value: Double
    public let onChanged: ((Double) -> Void)?
    public let onChangeStart: ((Double) -> Void)?
    public let onChangeEnd: ((Double) -> Void)?
    public let min: Double
    public let max: Double
    public let color: Color?

    public init(
        key: (any Key)? = nil,
        value: Double,
        onChanged: ((Double) -> Void)? = nil,
        onChangeStart: ((Double) -> Void)? = nil,
        onChangeEnd: ((Double) -> Void)? = nil,
        min: Double = 0.0,
        max: Double = 1.0,
        color: Color? = nil
    ) {
        self.value = value
        self.onChanged = onChanged
        self.onChangeStart = onChangeStart
        self.onChangeEnd = onChangeEnd
        self.min = min
        self.max = max
        self.color = color
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosSliderState()
    }
}

private class _MacosSliderState: State<StatefulWidget> {
    /// Laid-out width from MeasureSize — pointer x → value needs it.
    private var trackW: Double = 0

    private var w: MacosSlider { widget as! MacosSlider }

    private static let kThumbD = 16.0
    private static let kTrackH = 4.0
    private static let kHeight = 20.0

    private func valueAt(_ x: Double) -> Double {
        let usable = Swift.max(trackW - Self.kThumbD, 1)
        let f = Swift.min(Swift.max((x - Self.kThumbD / 2) / usable, 0), 1)
        return w.min + f * (w.max - w.min)
    }

    private func recordWidth(_ size: Size) {
        if abs(size.width - trackW) < 0.5 { return }
        let width = size.width
        // Fires during layout — hop to the main queue before mutating.
        let update: () -> Void = { [weak self] in
            guard let self else { return }
            self.setState { self.trackW = width }
        }
        DispatchQueue.main.async(
            execute: unsafeBitCast(update, to: (@Sendable () -> Void).self))
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark
        let trackColor = w.color ?? theme.primaryColor
        let trackBg = isDark
            ? Color(rgbo: 255, 255, 255, 0.16)
            : Color(rgbo: 0, 0, 0, 0.1)

        let span = w.max - w.min
        let fraction = span > 0
            ? Swift.min(Swift.max((w.value - w.min) / span, 0), 1) : 0
        let usable = Swift.max(trackW - Self.kThumbD, 1)
        let thumbX = usable * fraction

        return GestureDetector(
            onTapUp: { [self] d in
                let v = valueAt(d.localPosition.dx)
                w.onChangeStart?(v)
                w.onChanged?(v)
                w.onChangeEnd?(v)
            },
            onHorizontalDragStart: { [self] d in
                let v = valueAt(d.localPosition.dx)
                w.onChangeStart?(v)
                w.onChanged?(v)
            },
            onHorizontalDragUpdate: { [self] d in
                w.onChanged?(valueAt(d.localPosition.dx))
            },
            onHorizontalDragEnd: { [self] _ in
                w.onChangeEnd?(w.value)
            },
            behavior: .opaque,
            child: MeasureSize(
                onSize: { [weak self] size in self?.recordWidth(size) },
                child: SizedBox(
                    height: Self.kHeight,
                    child: Stack(children: [
                        // Track background
                        Positioned(
                            left: 0, top: (Self.kHeight - Self.kTrackH) / 2,
                            right: 0, height: Self.kTrackH,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: trackBg,
                                    borderRadius: BorderRadius.all(Radius(circular: 2))
                                )
                            )
                        ),
                        // Active track
                        Positioned(
                            left: 0, top: (Self.kHeight - Self.kTrackH) / 2,
                            width: Swift.max(thumbX + Self.kThumbD / 2, Self.kTrackH),
                            height: Self.kTrackH,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: trackColor,
                                    borderRadius: BorderRadius.all(Radius(circular: 2))
                                )
                            )
                        ),
                        // Thumb
                        Positioned(
                            left: thumbX, top: (Self.kHeight - Self.kThumbD) / 2,
                            width: Self.kThumbD, height: Self.kThumbD,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: MacosColors.white,
                                    boxShadow: [
                                        BoxShadow(
                                            color: Color(rgbo: 0, 0, 0, 0.25),
                                            offset: Offset(0, 1),
                                            blurRadius: 2
                                        )
                                    ],
                                    shape: .circle
                                )
                            )
                        )
                    ])
                )
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
