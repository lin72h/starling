// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - StartMenuEntry

/// Describes a single item in the start menu.
struct StartMenuEntry {
    let appId: String
    let title: String
    let subtitle: String
    let iconType: IconType
}

// MARK: - StartMenu

/// The launcher panel that appears above the taskbar when the start button
/// is clicked. Contains a list of launchable apps.
class StartMenu: StatelessWidget {

    let entries: [StartMenuEntry]
    let onLaunch: ((String) -> Void)?
    let onDismiss: (() -> Void)?

    init(
        entries: [StartMenuEntry] = StartMenu.defaultEntries,
        onLaunch: ((String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.entries = entries
        self.onLaunch = onLaunch
        self.onDismiss = onDismiss
    }

    static let defaultEntries: [StartMenuEntry] = [
        StartMenuEntry(
            appId: "settings",
            title: "Settings",
            subtitle: "System preferences",
            iconType: .settings
        ),
        StartMenuEntry(
            appId: "files",
            title: "File Browser",
            subtitle: "Browse files and folders",
            iconType: .folder
        ),
        StartMenuEntry(
            appId: "textviewer",
            title: "Text Viewer",
            subtitle: "View text documents",
            iconType: .document
        ),
        StartMenuEntry(
            appId: "externalapp",
            title: "External App",
            subtitle: "Offscreen rendered (texture)",
            iconType: .externalApp
        ),
        StartMenuEntry(
            appId: "flutterapp",
            title: "Flutter App",
            subtitle: "Standalone Flutter app",
            iconType: .flutterApp
        ),
    ]

    override func build(_ context: any BuildContext) -> Widget {
        // Build the menu items
        var menuItems: [Widget] = []

        // Header
        menuItems.append(
            Padding(
                padding: EdgeInsets(left: 16, top: 16, right: 16, bottom: 8),
                child: Text(
                    "Apps",
                    style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 14,
                        fontWeight: .bold
                    )
                )
            )
        )

        // App entries
        for entry in entries {
            let appId = entry.appId
            menuItems.append(
                ListTile(
                    leading: SizedBox(
                        width: 24,
                        height: 24,
                        child: CustomPaint(
                            painter: IconPainter(entry.iconType, color: DesktopTheme.accent)
                        )
                    ),
                    title: Text(
                        entry.title,
                        style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 13
                        )
                    ),
                    subtitle: Text(
                        entry.subtitle,
                        style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 11
                        )
                    ),
                    onPressed: { [self] in
                        onLaunch?(appId)
                    }
                )
            )
        }

        return Card(
            child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: menuItems
            ),
            padding: EdgeInsets(all: 8),
            backgroundColor: Color(0xF02C2C2C),
            borderColor: Color(0x40FFFFFF),
            borderRadius: BorderRadius.all(Radius(circular: 8))
        )
    }
}
