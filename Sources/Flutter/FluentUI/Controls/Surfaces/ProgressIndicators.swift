// Ported from: fluent_ui/lib/src/controls/surfaces/progress_indicators.dart

import FlutterSwiftBridge
import Foundation

private let _kMinProgressRingIndicatorSize: Double = 36
private let _kMinProgressBarWidth: Double = 130

// MARK: - ProgressBar

/// A linear progress indicator that shows operation progress.
///
/// The progress bar can operate in two modes:
///
/// * **Determinate** - Shows specific progress from 0-100%. Use when you can
///   measure or estimate the operation's progress.
///
/// * **Indeterminate** - Shows an animation without specific progress. Use when
///   the operation duration is unknown.
public class ProgressBar: StatefulWidget {

    /// The current value of the indicator (0 to 100).
    /// If nil, an indeterminate progress bar is created.
    public let value: Double?

    /// The height of the progress bar. Defaults to 4.5 logical pixels.
    public let strokeWidth: Double

    /// The background color of the progress bar.
    /// If nil, `FluentThemeData.inactiveBackgroundColor` is used.
    public let backgroundColor: Color?

    /// The active color of the progress bar.
    /// If nil, `FluentThemeData.accentColor` is used.
    public let activeColor: Color?

    public init(
        key: (any Key)? = nil,
        value: Double? = nil,
        strokeWidth: Double = 4.5,
        backgroundColor: Color? = nil,
        activeColor: Color? = nil
    ) {
        assert(value == nil || (value! >= 0 && value! <= 100))
        assert(strokeWidth >= 0)
        self.value = value
        self.strokeWidth = strokeWidth
        self.backgroundColor = backgroundColor
        self.activeColor = activeColor
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _ProgressBarState()
    }
}

// MARK: - _ProgressBarState

private class _ProgressBarState: State<StatefulWidget>, TickerProvider {

    private var _controller: AnimationController?

    private var progressBar: ProgressBar {
        return widget as! ProgressBar
    }

    // Indeterminate animation state
    private var p1: Double = 0
    private var p2: Double = 0
    private var idleFrames: Double = 15
    private var cycle: Double = 1
    private var idle: Double = 1
    private var lastValue: Double = 0

    // MARK: - TickerProvider

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    // MARK: - Lifecycle

    override func initState() {
        super.initState()
        _controller = AnimationController(
            duration: .milliseconds(3000),
            vsync: self
        )
        if progressBar.value == nil {
            _controller!.repeat()
        }
        _controller!.addListener { [weak self] in
            guard let self = self, self.mounted else { return }
            self.setState {}
        }
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let w = progressBar
        if w.value == nil && !(_controller?.isAnimating ?? false) {
            _controller?.repeat()
        } else if w.value != nil && (_controller?.isAnimating ?? false) {
            _controller?.stop()
        }
    }

    override func dispose() {
        _controller?.dispose()
        _controller = nil
        super.dispose()
    }

    // MARK: - Build

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        let w = progressBar

        let resolvedActiveColor = w.activeColor
            ?? theme.accentColor.defaultBrushFor(theme.brightness)
        let resolvedBgColor = w.backgroundColor
            ?? theme.inactiveBackgroundColor

        // Compute delta for indeterminate animation
        var deltaValue: Double = 0
        if let controller = _controller {
            deltaValue = controller.value - lastValue
            lastValue = controller.value
            if deltaValue < 0 { deltaValue += 1 }
        }

        return SizedBox(
            height: w.strokeWidth,
            child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: _kMinProgressBarWidth),
                child: CustomPaint(
                    painter: _ProgressBarPainter(
                        value: w.value != nil ? w.value! / 100 : nil,
                        strokeWidth: w.strokeWidth,
                        activeColor: resolvedActiveColor,
                        backgroundColor: resolvedBgColor,
                        p1: p1,
                        p2: p2,
                        idleFrames: idleFrames,
                        cycle: cycle,
                        idle: idle,
                        deltaValue: deltaValue,
                        onUpdate: { [weak self] values in
                            self?.p1 = values[0]
                            self?.p2 = values[1]
                            self?.idleFrames = values[2]
                            self?.cycle = values[3]
                            self?.idle = values[4]
                        }
                    )
                )
            )
        )
    }
}

// MARK: - _ProgressBarPainter

private class _ProgressBarPainter: CustomPainter {

    static let _step1: Double = 2.7
    static let _step2: Double = 4.5
    static let _velocityScale: Double = 0.8
    static let _short: Double = 0.4
    static let _long: Double = 80.0 / 130.0

    var p1: Double
    var p2: Double
    var idleFrames: Double
    var cycle: Double
    var idle: Double
    var deltaValue: Double
    let onUpdate: ([Double]) -> Void

    let strokeWidth: Double
    let backgroundColor: Color
    let activeColor: Color
    let value: Double?

    init(
        value: Double?,
        strokeWidth: Double,
        activeColor: Color,
        backgroundColor: Color,
        p1: Double,
        p2: Double,
        idleFrames: Double,
        cycle: Double,
        idle: Double,
        deltaValue: Double,
        onUpdate: @escaping ([Double]) -> Void
    ) {
        self.value = value
        self.strokeWidth = strokeWidth
        self.activeColor = activeColor
        self.backgroundColor = backgroundColor
        self.p1 = p1
        self.p2 = p2
        self.idleFrames = idleFrames
        self.cycle = cycle
        self.idle = idle
        self.deltaValue = deltaValue
        self.onUpdate = onUpdate
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let adjustedSize = Size(size.width - strokeWidth / 2, size.height - strokeWidth / 2)

        func drawProgressLine(_ xy1: Offset, _ xy2: Offset, _ color: Color) {
            var p1 = xy1 + Offset(strokeWidth / 2, 0)
            // Clamp p1
            p1 = Offset(
                min(max(p1.dx, 0), adjustedSize.width),
                min(max(p1.dy, 0), adjustedSize.height)
            )
            // Clamp p2 with p1 as minimum
            var p2 = xy2
            p2 = Offset(
                min(max(p2.dx, p1.dx), adjustedSize.width),
                min(max(p2.dy, p1.dy), adjustedSize.height)
            )

            let paint = Paint()
            paint.color = color
            paint.strokeWidth = strokeWidth
            paint.style = .stroke
            paint.strokeCap = .round
            canvas.drawLine(p1, p2, paint)
        }

        // Background line
        drawProgressLine(
            Offset(0, adjustedSize.height),
            Offset(adjustedSize.width, adjustedSize.height),
            backgroundColor
        )

        if let value = value {
            drawProgressLine(
                Offset(0, adjustedSize.height),
                Offset(min(max(value, 0.0), 1.0) * adjustedSize.width, adjustedSize.height),
                activeColor
            )
            return
        }

        // Indeterminate animation math (courtesy of raitonoberu)
        func update() {
            onUpdate([p1, p2, idleFrames, cycle, idle])
        }

        func coords(_ percentage: Double) -> Offset {
            return Offset(adjustedSize.width * percentage, adjustedSize.height)
        }

        func calcVelocity(_ p: Double) -> Double {
            return (1 + cos(Double.pi * p - (Double.pi / 2)) * _ProgressBarPainter._velocityScale)
                * deltaValue
        }

        let v1 = calcVelocity(p1)
        let v2 = calcVelocity(p2)

        if cycle == 1 {
            // short line
            p2 = min(p2 + _ProgressBarPainter._step1 * v2, 1)
            if p2 - p1 >= _ProgressBarPainter._short || p2 == 1 {
                p1 = min(p1 + _ProgressBarPainter._step1 * v1, 1)
            }
        }
        if cycle == -1 {
            // long line
            p2 = min(p2 + _ProgressBarPainter._step2 * v2, 1)
            if p2 - p1 >= _ProgressBarPainter._long || p2 == 1 {
                p1 = min(p1 + _ProgressBarPainter._step2 * v1, 1)
            }
        }
        if p1 == 1 {
            // the end reached
            idle = idleFrames
            cycle *= -1
            p1 = 0
            p2 = 0
        }
        update()

        if idle != 0 {
            drawProgressLine(coords(p1), coords(p2), activeColor)
        }
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return true
    }
}

// MARK: - ProgressRing

/// A circular progress indicator that shows operation progress.
///
/// The progress ring can operate in two modes:
///
/// * **Determinate** - Shows specific progress from 0-100%.
///
/// * **Indeterminate** - Shows a spinning animation.
public class ProgressRing: StatefulWidget {

    /// The current value of the indicator (0 to 100).
    /// If nil, an indeterminate progress ring is created.
    public let value: Double?

    /// The stroke width of the progress ring. Defaults to 4.5.
    public let strokeWidth: Double

    /// The background color of the progress ring.
    /// If nil, `FluentThemeData.inactiveBackgroundColor` is used.
    public let backgroundColor: Color?

    /// The active color of the progress ring.
    /// If nil, `FluentThemeData.accentColor` is used.
    public let activeColor: Color?

    /// Whether the indicator spins backwards. Defaults to false.
    public let backwards: Bool

    public init(
        key: (any Key)? = nil,
        value: Double? = nil,
        strokeWidth: Double = 4.5,
        backgroundColor: Color? = nil,
        activeColor: Color? = nil,
        backwards: Bool = false
    ) {
        assert(value == nil || (value! >= 0 && value! <= 100))
        self.value = value
        self.strokeWidth = strokeWidth
        self.backgroundColor = backgroundColor
        self.activeColor = activeColor
        self.backwards = backwards
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _ProgressRingState()
    }
}

// MARK: - _ProgressRingState

private class _ProgressRingState: State<StatefulWidget>, TickerProvider {

    nonisolated(unsafe) static let _startAngleTween = TweenSequence<Double>([
        TweenSequenceItem(tween: DoubleTween(begin: 0, end: 450), weight: 1),
        TweenSequenceItem(tween: DoubleTween(begin: 450, end: 1080), weight: 1),
    ])
    nonisolated(unsafe) static let _sweepAngleTween = TweenSequence<Double>([
        TweenSequenceItem(tween: DoubleTween(begin: 0, end: 180), weight: 1),
        TweenSequenceItem(tween: DoubleTween(begin: 180, end: 0), weight: 1),
    ])

    private var _controller: AnimationController?

    private var progressRing: ProgressRing {
        return widget as! ProgressRing
    }

    // MARK: - TickerProvider

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    // MARK: - Lifecycle

    override func initState() {
        super.initState()
        _controller = AnimationController(
            duration: .milliseconds(2000),
            vsync: self
        )
        if progressRing.value == nil {
            _controller!.repeat()
        }
        _controller!.addListener { [weak self] in
            guard let self = self, self.mounted else { return }
            self.setState {}
        }
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)
        let w = progressRing
        if w.value == nil && !(_controller?.isAnimating ?? false) {
            _controller?.repeat()
        } else if w.value != nil && (_controller?.isAnimating ?? false) {
            _controller?.stop()
        }
    }

    override func dispose() {
        _controller?.dispose()
        _controller = nil
        super.dispose()
    }

    // MARK: - Build

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        let w = progressRing

        let resolvedActiveColor = w.activeColor
            ?? theme.accentColor.defaultBrushFor(theme.brightness)
        let resolvedBgColor = w.backgroundColor
            ?? theme.inactiveBackgroundColor

        let startAngle = _ProgressRingState._startAngleTween.evaluate(_controller!)
        let sweepAngle = _ProgressRingState._sweepAngleTween.evaluate(_controller!)

        return ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: _kMinProgressRingIndicatorSize,
                minHeight: _kMinProgressRingIndicatorSize
            ),
            child: CustomPaint(
                painter: _RingPainter(
                    backgroundColor: resolvedBgColor,
                    value: w.value,
                    color: resolvedActiveColor,
                    strokeWidth: w.strokeWidth,
                    startAngle: startAngle,
                    sweepAngle: sweepAngle,
                    backwards: w.backwards
                )
            )
        )
    }
}

// MARK: - _RingPainter

private class _RingPainter: CustomPainter {

    let color: Color
    let backgroundColor: Color
    let strokeWidth: Double
    let value: Double?
    let startAngle: Double
    let sweepAngle: Double
    let backwards: Bool

    static let _twoPi: Double = Double.pi * 2.0
    static let _epsilon: Double = 0.001
    static let _sweep: Double = _twoPi - _epsilon
    static let _startAngle: Double = -Double.pi / 2.0
    static let _deg2Rad: Double = (2 * Double.pi) / 360

    init(
        backgroundColor: Color,
        value: Double?,
        color: Color,
        strokeWidth: Double,
        startAngle: Double,
        sweepAngle: Double,
        backwards: Bool
    ) {
        self.backgroundColor = backgroundColor
        self.value = value
        self.color = color
        self.strokeWidth = strokeWidth
        self.startAngle = startAngle
        self.sweepAngle = sweepAngle
        self.backwards = backwards
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let offset = Offset(strokeWidth / 2, strokeWidth / 2)
        let adjustedSize = Size(size.width - strokeWidth, size.height - strokeWidth)

        // Skip painting if the rect would be degenerate
        guard adjustedSize.width > 0 && adjustedSize.height > 0 else { return }

        let rect = offset & adjustedSize

        // Background circle
        let bgPaint = Paint()
        bgPaint.color = backgroundColor
        bgPaint.style = .stroke
        bgPaint.strokeWidth = strokeWidth
        canvas.drawArc(rect, _RingPainter._startAngle, _RingPainter._sweep, false, bgPaint)

        // Active arc
        let activePaint = Paint()
        activePaint.color = color
        activePaint.strokeWidth = strokeWidth
        activePaint.strokeCap = .round
        activePaint.style = .stroke

        if value == nil {
            // Indeterminate
            let sweepRad = sweepAngle * _RingPainter._deg2Rad
            // Skip zero-length arcs — Impeller's stroke tessellation crashes
            // on degenerate arc geometry (sweepAngle passes through 0 during animation)
            if Swift.abs(sweepRad) > _RingPainter._epsilon {
                let angle = ((backwards ? -startAngle : startAngle) - 90) * _RingPainter._deg2Rad
                canvas.drawArc(rect, angle, sweepRad, false, activePaint)
            }
        } else {
            // Determinate
            let clampedValue = Swift.min(Swift.max(value! / 100, 0), 1)
            let sweepRad: Double = clampedValue * _RingPainter._sweep
            if Swift.abs(sweepRad) > _RingPainter._epsilon {
                canvas.drawArc(
                    rect,
                    _RingPainter._startAngle,
                    sweepRad,
                    false,
                    activePaint
                )
            }
        }
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return value == nil || (oldDelegate as? _RingPainter).map { value != $0.value } ?? true
    }
}
