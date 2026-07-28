// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - Taskbar

/// Bottom taskbar panel containing start button, app icons, and system tray.
class Taskbar: StatelessWidget {

    let onStartTap: (() -> Void)?
    let onAppTap: ((String) -> Void)?

    /// Set of app IDs that currently have open windows.
    let runningAppIds: Set<String>

    init(
        onStartTap: (() -> Void)? = nil,
        onAppTap: ((String) -> Void)? = nil,
        runningAppIds: Set<String> = []
    ) {
        self.onStartTap = onStartTap
        self.onAppTap = onAppTap
        self.runningAppIds = runningAppIds
    }

    override func build(_ context: any BuildContext) -> Widget {
        return ColoredBox(
            color: DesktopTheme.taskbarBackground,
            child: Row(
                children: [
                    // Start button
                    StartButton(onTap: onStartTap),

                    // Vertical divider
                    SizedBox(
                        width: 1,
                        height: 28,
                        child: ColoredBox(
                            color: Color(0x40FFFFFF),
                            child: SizedBox(expand: ())
                        )
                    ),

                    // App icons
                    TaskbarAppIcon(
                        iconType: .settings,
                        label: "Settings",
                        isRunning: runningAppIds.contains("settings"),
                        onTap: { [self] in onAppTap?("settings") }
                    ),
                    TaskbarAppIcon(
                        iconType: .folder,
                        label: "Files",
                        isRunning: runningAppIds.contains("files"),
                        onTap: { [self] in onAppTap?("files") }
                    ),
                    TaskbarAppIcon(
                        iconType: .document,
                        label: "Text Viewer",
                        isRunning: runningAppIds.contains("textviewer"),
                        onTap: { [self] in onAppTap?("textviewer") }
                    ),
                    TaskbarAppIcon(
                        iconType: .externalApp,
                        label: "External App",
                        isRunning: runningAppIds.contains("externalapp"),
                        onTap: { [self] in onAppTap?("externalapp") }
                    ),
                    TaskbarAppIcon(
                        iconType: .flutterApp,
                        label: "Flutter App",
                        isRunning: runningAppIds.contains("flutterapp"),
                        onTap: { [self] in onAppTap?("flutterapp") }
                    ),

                    // Spacer pushes system tray to the right
                    Expanded(child: SizedBox(width: 0)),

                    // System tray (clock + indicators)
                    SystemTray(),
                ]
            )
        )
    }
}
