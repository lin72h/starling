// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - TaskbarAppIcon

/// An app icon in the taskbar. Shows a small accent dot when the app has an
/// open window.
class TaskbarAppIcon: StatelessWidget {

    let iconType: IconType
    let label: String
    let isRunning: Bool
    let onTap: (() -> Void)?

    init(
        iconType: IconType,
        label: String,
        isRunning: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.iconType = iconType
        self.label = label
        self.isRunning = isRunning
        self.onTap = onTap
    }

    override func build(_ context: any BuildContext) -> Widget {
        return SizedBox(
            width: 44,
            height: DesktopTheme.kTaskbarHeight,
            child: HoverButton(
                builder: { [self] context, states in
                    let bgColor: Color
                    if states.isPressed {
                        bgColor = Color(0x40FFFFFF)
                    } else if states.isHovered {
                        bgColor = Color(0x20FFFFFF)
                    } else {
                        bgColor = Color(0x00000000)
                    }
                    return ColoredBox(
                        color: bgColor,
                        child: Column(
                            mainAxisAlignment: .center,
                            children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CustomPaint(
                                        painter: IconPainter(iconType, color: Color(0xDDFFFFFF))
                                    )
                                ),
                                SizedBox(height: 3),
                                // Running indicator dot
                                SizedBox(
                                    width: 6,
                                    height: 3,
                                    child: isRunning
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.all(Radius(circular: 1.5)),
                                            child: ColoredBox(
                                                color: DesktopTheme.accent,
                                                child: SizedBox(expand: ())
                                            )
                                        )
                                        : SizedBox(shrink: ())
                                ),
                            ]
                        )
                    )
                },
                onPressed: onTap
            )
        )
    }
}
