// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - StartButton

/// The "Start" button on the left side of the taskbar.
/// Displays a 3x3 grid icon and triggers `onTap` when pressed.
class StartButton: StatelessWidget {

    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    override func build(_ context: any BuildContext) -> Widget {
        return Listener(
            onPointerDown: { [self] _ in
                onTap?()
            },
            behavior: .opaque,
            child: SizedBox(
                width: 44,
                height: DesktopTheme.kTaskbarHeight,
                child: ColoredBox(
                    color: Color(0x00000000),
                    child: Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CustomPaint(
                                painter: IconPainter(.apps, color: Color(0xFFFFFFFF))
                            )
                        )
                    )
                )
            )
        )
    }
}
