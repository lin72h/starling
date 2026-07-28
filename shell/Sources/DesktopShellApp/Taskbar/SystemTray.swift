// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - SystemTray

/// Right side of the taskbar: clock + status indicators.
class SystemTray: StatelessWidget {

    override func build(_ context: any BuildContext) -> Widget {
        // Read current time (updates on every rebuild/interaction)
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        let dateString = dateFormatter.string(from: now)

        return Padding(
            padding: EdgeInsets(horizontal: 12),
            child: Row(
                mainAxisSize: .min,
                spacing: 10,
                children: [
                    // Status indicators (small colored dots)
                    Row(
                        mainAxisSize: .min,
                        spacing: 6,
                        children: [
                            _statusDot(Color(0xFF4CAF50)),  // green = connected
                            _statusDot(Color(0xFF60CDFF)),  // blue = bluetooth
                        ]
                    ),
                    // Clock
                    Column(
                        mainAxisAlignment: .center,
                        crossAxisAlignment: .end,
                        children: [
                            Text(
                                timeString,
                                style: TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 12
                                )
                            ),
                            Text(
                                dateString,
                                style: TextStyle(
                                    color: Color(0xB0FFFFFF),
                                    fontSize: 11
                                )
                            ),
                        ]
                    ),
                ]
            )
        )
    }

    private func _statusDot(_ color: Color) -> Widget {
        return SizedBox(
            width: 8,
            height: 8,
            child: ClipOval(
                child: ColoredBox(
                    color: color,
                    child: SizedBox(expand: ())
                )
            )
        )
    }
}
