// MacosSwitch ported from macos_ui/lib/src/buttons/switch.dart

import FlutterSwiftBridge

// MARK: - Constants

private let _kSwitchWidth: Double = 26.0
private let _kSwitchHeight: Double = 15.0
private let _kKnobSize: Double = 13.0

// MARK: - MacosSwitch

/// A toggle switch that lets the user turn something on or off.
///
/// Follows macOS design with a pill-shaped track and sliding knob.
public class MacosSwitch: StatefulWidget {
    /// Whether the switch is on.
    public let value: Bool

    /// Called when the user toggles the switch.
    public let onChanged: ((Bool) -> Void)?

    /// The size of the switch. Defaults to regular.
    public let size: ControlSize

    /// The semantic label used by screen readers.
    public let semanticLabel: String?

    public var isDisabled: Bool { onChanged == nil }

    public init(
        key: (any Key)? = nil,
        value: Bool,
        onChanged: ((Bool) -> Void)?,
        size: ControlSize = .regular,
        semanticLabel: String? = nil
    ) {
        self.value = value
        self.onChanged = onChanged
        self.size = size
        self.semanticLabel = semanticLabel
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosSwitchState()
    }
}

class _MacosSwitchState: State<StatefulWidget> {
    private var sw: MacosSwitch {
        return widget as! MacosSwitch
    }

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let trackColor: Color
        if sw.isDisabled {
            trackColor = isDark
                ? Color(rgbo: 255, 255, 255, 0.1)
                : Color(rgbo: 0, 0, 0, 0.06)
        } else if sw.value {
            trackColor = theme.primaryColor
        } else {
            trackColor = isDark
                ? Color(rgbo: 255, 255, 255, 0.15)
                : Color(rgbo: 0, 0, 0, 0.09)
        }

        let knobColor: Color = sw.isDisabled
            ? (isDark ? Color(rgbo: 152, 152, 157, 0.5) : Color(rgbo: 255, 255, 255, 0.7))
            : (isDark ? Color(rgbo: 152, 152, 157, 1) : MacosColors.white)

        let knobOffset: Double = sw.value
            ? _kSwitchWidth - _kKnobSize - 1
            : 1

        return GestureDetector(
            onTap: {
                self.sw.onChanged?(!self.sw.value)
            },
            child: SizedBox(
                width: _kSwitchWidth,
                height: _kSwitchHeight,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: trackColor,
                        border: Border.all(
                            color: isDark
                                ? Color(rgbo: 255, 255, 255, 0.15)
                                : Color(rgbo: 0, 0, 0, 0.1),
                            width: 0.5
                        ),
                        borderRadius: BorderRadius.all(Radius(circular: _kSwitchHeight / 2))
                    ),
                    child: Stack(children: [
                        Positioned(
                            left: knobOffset,
                            top: 0.5,
                            child: SizedBox(
                                width: _kKnobSize,
                                height: _kKnobSize,
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: knobColor,
                                        boxShadow: [
                                            BoxShadow(
                                                color: Color(rgbo: 0, 0, 0, 0.15),
                                                offset: Offset(0, 0.5),
                                                blurRadius: 1
                                            )
                                        ],
                                        shape: .circle
                                    )
                                )
                            )
                        )
                    ])
                )
            )
        )
    }
}
