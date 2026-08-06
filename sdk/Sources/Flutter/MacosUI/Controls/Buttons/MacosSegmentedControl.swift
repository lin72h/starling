// MacosSegmentedControl — AppKit's NSSegmentedControl (select-one mode).
//
// Not in macos_ui, so this is modelled on the AppKit control itself: a
// rounded bezel holding equal-height segments, the selected one filled with
// the accent colour and its label in white. Use it for a small set of
// mutually exclusive choices that all deserve to stay visible; reach for a
// pop-up menu instead once the list grows past about five.

import FlutterSwiftBridge

// MARK: - Constants

private let _kSegmentHeight: Double = 22.0
private let _kSegmentRadius: Double = 6.0
private let _kSegmentHPadding: Double = 11.0
private let _kSegmentFontSize: Double = 12.0

// MARK: - MacosSegmentedControl

/// A horizontal row of mutually exclusive options, AppKit's select-one
/// segmented control.
public class MacosSegmentedControl: StatefulWidget {
    /// Segment labels, left to right.
    public let labels: [String]

    /// Index of the selected segment. Out-of-range selects nothing, which is
    /// the honest rendering for a value this control doesn't know about
    /// (e.g. a newer shell offering a choice this build has no label for).
    public let selectedIndex: Int

    /// Called with the tapped segment's index. Nil disables the control.
    public let onChanged: ((Int) -> Void)?

    public var isDisabled: Bool { onChanged == nil }

    public init(
        key: (any Key)? = nil,
        labels: [String],
        selectedIndex: Int,
        onChanged: ((Int) -> Void)?
    ) {
        self.labels = labels
        self.selectedIndex = selectedIndex
        self.onChanged = onChanged
        super.init(key: key)
    }

    public override func createState() -> State<StatefulWidget> {
        return _MacosSegmentedControlState()
    }
}

class _MacosSegmentedControlState: State<StatefulWidget> {
    private var control: MacosSegmentedControl {
        return widget as! MacosSegmentedControl
    }

    /// Hover comes from `Listener.onPointerHover`, not `MouseRegion`:
    /// MouseRegion's enter/exit never fire under the DRM embedder, so a
    /// segment can never learn it was left. One index held here means
    /// hovering any segment clears every other — the same shape MacosMenu
    /// uses, and for the same reason.
    private var hoveredIndex: Int = -1

    override func build(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        let isDark = theme.brightness == .dark

        let bezelColor = isDark
            ? Color(rgbo: 255, 255, 255, 0.09)
            : Color(rgbo: 0, 0, 0, 0.05)
        let borderColor = isDark
            ? Color(rgbo: 255, 255, 255, 0.12)
            : Color(rgbo: 0, 0, 0, 0.10)

        var segments: [Widget] = []
        for (i, label) in control.labels.enumerated() {
            let selected = i == control.selectedIndex
            let hovered = i == hoveredIndex && !selected && !control.isDisabled

            let fill: Color
            if selected {
                fill = control.isDisabled
                    ? (isDark ? Color(rgbo: 255, 255, 255, 0.18)
                              : Color(rgbo: 0, 0, 0, 0.14))
                    : theme.primaryColor
            } else if hovered {
                fill = isDark ? Color(rgbo: 255, 255, 255, 0.07)
                              : Color(rgbo: 0, 0, 0, 0.05)
            } else {
                fill = Color(0x00000000)
            }

            let textColor: Color
            if selected {
                textColor = MacosColors.white
            } else if control.isDisabled {
                textColor = isDark ? Color(rgbo: 255, 255, 255, 0.3)
                                   : Color(rgbo: 0, 0, 0, 0.3)
            } else {
                textColor = theme.typography.body.color
                    ?? MacosColors.labelColor(for: theme.brightness)
            }

            segments.append(
                Listener(
                    onPointerHover: { [self] _ in
                        guard hoveredIndex != i else { return }
                        setState { hoveredIndex = i }
                    },
                    behavior: .opaque,
                    child: GestureDetector(
                        onTap: { [self] in
                            guard !control.isDisabled, i != control.selectedIndex
                            else { return }
                            control.onChanged?(i)
                        },
                        child: SizedBox(
                            height: _kSegmentHeight,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: fill,
                                    borderRadius: BorderRadius.all(
                                        Radius(circular: _kSegmentRadius - 1))
                                ),
                                child: Padding(
                                    padding: EdgeInsets(
                                        horizontal: _kSegmentHPadding),
                                    child: Center(
                                        child: Text(
                                            label,
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: _kSegmentFontSize,
                                                fontWeight: selected ? .w500 : .w400
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        }

        return DecoratedBox(
            decoration: BoxDecoration(
                color: bezelColor,
                border: Border.all(color: borderColor, width: 0.5),
                borderRadius: BorderRadius.all(Radius(circular: _kSegmentRadius))
            ),
            child: Padding(
                padding: EdgeInsets(all: 1),
                child: Row(mainAxisSize: .min, children: segments)
            )
        )
    }
}
