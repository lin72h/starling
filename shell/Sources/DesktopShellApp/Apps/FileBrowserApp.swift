// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - FileBrowserApp

/// A demo file browser app using TreeView and BreadcrumbBar.
class FileBrowserApp: StatefulWidget {

    override func createState() -> State<StatefulWidget> {
        return _FileBrowserAppState()
    }
}

class _FileBrowserAppState: State<StatefulWidget> {

    /// Current path segments for breadcrumb display.
    var pathSegments: [String] = ["Home"]

    /// Mock files shown in the right panel.
    fileprivate var currentFiles: [_MockFile] = _MockFile.homeFiles

    override func build(_ context: any BuildContext) -> Widget {
        return Row(
            children: [
                // Left panel: TreeView (folder navigation)
                SizedBox(
                    width: 180,
                    child: ColoredBox(
                        color: Color(0xFF1A1A1A),
                        child: Padding(
                            padding: EdgeInsets(all: 4),
                            child: TreeView(
                                items: _buildTreeItems(),
                                selectionMode: .single,
                                onItemInvoked: { [self] (item: TreeViewItem) in
                                    if let name = (item.content as? Text)?.data {
                                        setState {
                                            _navigateToFolder(name)
                                        }
                                    }
                                }
                            )
                        )
                    )
                ),

                // Right panel: BreadcrumbBar + file grid
                Expanded(
                    child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                            // Breadcrumb navigation
                            Padding(
                                padding: EdgeInsets(left: 12, top: 8, right: 12, bottom: 4),
                                child: BreadcrumbBar<String>(
                                    items: pathSegments.map { segment in
                                        BreadcrumbItem<String>(
                                            label: Text(
                                                segment,
                                                style: TextStyle(
                                                    color: Color(0xDDFFFFFF),
                                                    fontSize: 12
                                                )
                                            ),
                                            value: segment
                                        )
                                    },
                                    onItemPressed: { [self] (item: BreadcrumbItem<String>) in
                                        setState {
                                            _navigateToBreadcrumb(item.value)
                                        }
                                    }
                                )
                            ),

                            // File grid
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets(all: 12),
                                    child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: currentFiles.map { file in
                                            _fileCard(file)
                                        }
                                    )
                                )
                            ),
                        ]
                    )
                ),
            ]
        )
    }

    // MARK: - Tree Items

    private func _buildTreeItems() -> [TreeViewItem] {
        return [
            TreeViewItem(
                content: Text("Home", style: TextStyle(fontSize: 12)),
                children: [
                    TreeViewItem(
                        content: Text("Documents", style: TextStyle(fontSize: 12)),
                        leading: SizedBox(
                            width: 14, height: 14,
                            child: CustomPaint(painter: IconPainter(.folder, color: Color(0xFFFFD700)))
                        )
                    ),
                    TreeViewItem(
                        content: Text("Pictures", style: TextStyle(fontSize: 12)),
                        leading: SizedBox(
                            width: 14, height: 14,
                            child: CustomPaint(painter: IconPainter(.folder, color: Color(0xFFFFD700)))
                        )
                    ),
                    TreeViewItem(
                        content: Text("Downloads", style: TextStyle(fontSize: 12)),
                        leading: SizedBox(
                            width: 14, height: 14,
                            child: CustomPaint(painter: IconPainter(.folder, color: Color(0xFFFFD700)))
                        )
                    ),
                ],
                expanded: true,
                leading: SizedBox(
                    width: 14, height: 14,
                    child: CustomPaint(painter: IconPainter(.folder, color: Color(0xFFFFD700)))
                )
            ),
            TreeViewItem(
                content: Text("Desktop", style: TextStyle(fontSize: 12)),
                leading: SizedBox(
                    width: 14, height: 14,
                    child: CustomPaint(painter: IconPainter(.folder, color: Color(0xFFFFD700)))
                )
            ),
        ]
    }

    // MARK: - File Card

    private func _fileCard(_ file: _MockFile) -> Widget {
        let iconType: IconType = file.isFolder ? .folder : .document
        let iconColor: Color = file.isFolder ? Color(0xFFFFD700) : Color(0xFF60CDFF)

        return SizedBox(
            width: 90,
            height: 90,
            child: Card(
                child: Column(
                    mainAxisAlignment: .center,
                    children: [
                        SizedBox(
                            width: 28,
                            height: 28,
                            child: CustomPaint(
                                painter: IconPainter(iconType, color: iconColor)
                            )
                        ),
                        SizedBox(height: 6),
                        Text(
                            file.name,
                            style: TextStyle(
                                color: Color(0xDDFFFFFF),
                                fontSize: 11
                            )
                        ),
                    ]
                ),
                padding: EdgeInsets(all: 6)
            )
        )
    }

    // MARK: - Navigation

    private func _navigateToFolder(_ name: String) {
        pathSegments = ["Home", name]
        currentFiles = _MockFile.filesFor(name)
    }

    private func _navigateToBreadcrumb(_ segment: String) {
        if segment == "Home" {
            pathSegments = ["Home"]
            currentFiles = _MockFile.homeFiles
        }
    }
}

// MARK: - _MockFile

private struct _MockFile {
    let name: String
    let isFolder: Bool

    static let homeFiles: [_MockFile] = [
        _MockFile(name: "Documents", isFolder: true),
        _MockFile(name: "Pictures", isFolder: true),
        _MockFile(name: "Downloads", isFolder: true),
        _MockFile(name: "readme.txt", isFolder: false),
        _MockFile(name: "notes.md", isFolder: false),
        _MockFile(name: "config.json", isFolder: false),
    ]

    static func filesFor(_ folder: String) -> [_MockFile] {
        switch folder {
        case "Documents":
            return [
                _MockFile(name: "report.pdf", isFolder: false),
                _MockFile(name: "budget.xlsx", isFolder: false),
                _MockFile(name: "letter.docx", isFolder: false),
            ]
        case "Pictures":
            return [
                _MockFile(name: "photo1.jpg", isFolder: false),
                _MockFile(name: "photo2.png", isFolder: false),
                _MockFile(name: "wallpaper", isFolder: true),
            ]
        case "Downloads":
            return [
                _MockFile(name: "setup.exe", isFolder: false),
                _MockFile(name: "archive.zip", isFolder: false),
            ]
        default:
            return homeFiles
        }
    }
}
