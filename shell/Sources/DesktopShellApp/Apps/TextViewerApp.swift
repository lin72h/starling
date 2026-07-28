// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - TextViewerApp

/// A minimal text viewer app displaying sample text in monospace font.
class TextViewerApp: StatelessWidget {

    let content: String

    init(content: String = TextViewerApp.sampleContent) {
        self.content = content
    }

    override func build(_ context: any BuildContext) -> Widget {
        return ColoredBox(
            color: Color(0xFF1E1E1E),
            child: Padding(
                padding: EdgeInsets(all: 16),
                child: Column(
                    crossAxisAlignment: .start,
                    children: [
                        // File info header
                        Row(
                            children: [
                                SizedBox(
                                    width: 14, height: 14,
                                    child: CustomPaint(
                                        painter: IconPainter(.document, color: shellTheme.accent)
                                    )
                                ),
                                SizedBox(width: 8),
                                Text(
                                    "main.swift",
                                    style: TextStyle(
                                        color: Color(0xDDFFFFFF),
                                        fontSize: 12,
                                        fontWeight: .w600
                                    )
                                ),
                                Expanded(child: SizedBox(width: 0)),
                                Text(
                                    "UTF-8  |  Swift",
                                    style: TextStyle(
                                        color: Color(0x66FFFFFF),
                                        fontSize: 11
                                    )
                                ),
                            ]
                        ),
                        SizedBox(height: 12),
                        // Content area
                        Expanded(
                            child: Text(
                                content,
                                style: TextStyle(
                                    color: Color(0xFFD4D4D4),
                                    fontSize: 13,
                                    height: 1.5,
                                    fontFamily: "monospace"
                                )
                            )
                        ),
                    ]
                )
            )
        )
    }

    static let sampleContent = """
    import Flutter
    import FlutterSwiftBridge

    // Desktop Shell PoC
    // A proof-of-concept desktop environment
    // built with Flutter Swift + Fluent UI

    func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let engine = FlutterEngine(
            name: "swift-app",
            project: nil,
            allowHeadlessExecution: true
        )

        runApp(
            FluentApp(
                themeMode: .dark,
                home: DesktopShell()
            )
        )

        print("Desktop Shell is running!")
        app.run()
    }
    """
}
