// Ported from: fluent_ui/lib/src/styles/theme.dart (AnimatedFluentTheme)

import FlutterSwiftBridge

// MARK: - FluentThemeDataTween

/// A tween that interpolates between two [FluentThemeData] values using
/// [FluentThemeData.lerp].
public class FluentThemeDataTween: Tween<FluentThemeData> {

    public override init(begin: FluentThemeData? = nil, end: FluentThemeData? = nil) {
        super.init(begin: begin, end: end)
    }

    public override func lerp(_ t: Double) -> FluentThemeData {
        return FluentThemeData.lerp(begin!, end!, t)
    }
}

// MARK: - kThemeAnimationDuration

/// The default duration for theme transition animations (200ms).
nonisolated(unsafe) public let kThemeAnimationDuration: Duration = .milliseconds(200)

// MARK: - AnimatedFluentTheme

/// Animated version of [FluentTheme] which automatically transitions the
/// colors, typography, etc. over a given duration whenever the given theme
/// changes.
///
/// Since [ImplicitlyAnimatedWidget] is not yet available in flutter_swift,
/// this widget manually manages an [AnimationController] and
/// [FluentThemeDataTween] to drive the interpolation.
public class AnimatedFluentTheme: StatefulWidget {

    /// Specifies the color and typography values for descendant widgets.
    public let data: FluentThemeData

    /// The widget below this widget in the tree.
    public let child: Widget

    /// The duration over which to animate theme changes.
    public let duration: Duration

    /// The curve to apply to the animation.
    public let curve: any Curve

    public init(
        key: (any Key)? = nil,
        data: FluentThemeData,
        child: Widget,
        duration: Duration = kThemeAnimationDuration,
        curve: any Curve = Curves.linear
    ) {
        self.data = data
        self.child = child
        self.duration = duration
        self.curve = curve
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _AnimatedFluentThemeState()
    }
}

// MARK: - _AnimatedFluentThemeState

class _AnimatedFluentThemeState: State<StatefulWidget>, TickerProvider {

    private var _controller: AnimationController?
    private var _tween: FluentThemeDataTween?
    private var _curvedAnimation: CurvedAnimation?

    private var animatedTheme: AnimatedFluentTheme {
        return widget as! AnimatedFluentTheme
    }

    // MARK: - TickerProvider

    func createTicker(_ onTick: @escaping TickerCallback) -> Ticker {
        return Ticker(onTick)
    }

    // MARK: - Lifecycle

    override func initState() {
        super.initState()

        _controller = AnimationController(
            duration: animatedTheme.duration,
            vsync: self
        )

        _curvedAnimation = CurvedAnimation(
            parent: _controller!,
            curve: animatedTheme.curve
        )

        _tween = FluentThemeDataTween(
            begin: animatedTheme.data,
            end: animatedTheme.data
        )

        _controller!.addListener { [weak self] in
            guard let self = self, self.mounted else { return }
            self.setState {}
        }
    }

    override func didUpdateWidget(_ oldWidget: StatefulWidget) {
        super.didUpdateWidget(oldWidget)

        guard let oldTheme = oldWidget as? AnimatedFluentTheme else { return }

        if oldTheme.data != animatedTheme.data {
            // Capture the current interpolated value as the new starting point
            let currentValue = _tween!.evaluate(_curvedAnimation!)
            _tween!.begin = currentValue
            _tween!.end = animatedTheme.data

            // Update duration and curve if changed
            _controller!.duration = animatedTheme.duration
            _curvedAnimation = CurvedAnimation(
                parent: _controller!,
                curve: animatedTheme.curve
            )

            // Reset and run the animation forward
            _controller!.value = 0.0
            _controller!.forward()
        }
    }

    override func dispose() {
        _controller?.dispose()
        _controller = nil
        super.dispose()
    }

    // MARK: - Build

    override func build(_ context: any BuildContext) -> Widget {
        let currentData = _tween!.evaluate(_curvedAnimation!)
        return FluentTheme(data: currentData, child: animatedTheme.child)
    }
}
