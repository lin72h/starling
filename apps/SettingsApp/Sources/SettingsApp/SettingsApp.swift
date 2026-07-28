// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import CupertinoIcons
import Foundation
import Observation

// MARK: - SettingsApp

class SettingsApp: StatefulWidget {
    override func createState() -> State<StatefulWidget> {
        return _SettingsAppState()
    }
}

/// Theme-driven text ramp: white levels on dark, black levels on light.
/// Sidebar tile colors and status colors stay fixed; `accent` tracks the
/// desktop shell's per-theme system blue so selection pills and links
/// highlight with the same blue as the rest of the desktop.
private struct Palette {
    let textStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textPlaceholder: Color
    let accent: Color
    let fieldFill: Color
    let fieldBorder: Color
    /// Window surfaces. Opaque: the see-through liquid-glass haze read as
    /// blur over busy backdrops, so Settings paints solid (the shell's
    /// frost stays hidden behind it).
    let glassCanvas: Color
    let glassSidebar: Color

    init(dark: Bool) {
        if dark {
            textStrong = Color(0xFFFFFFFF)
            textPrimary = Color(0xFFFFFFFF)
            textSecondary = Color(0xC7FFFFFF)
            textTertiary = Color(0x99FFFFFF)
            textPlaceholder = Color(0x80FFFFFF)
            accent = Color(0xFF0A84FF)
            fieldFill = Color(0x14FFFFFF)
            fieldBorder = Color(0x1FFFFFFF)
            glassCanvas = Color(0xFF21252C)
            glassSidebar = Color(0xFF1D2129)
        } else {
            textStrong = Color(0xE6000000)
            textPrimary = Color(0xDD000000)
            textSecondary = Color(0xB3000000)
            textTertiary = Color(0x8C000000)
            textPlaceholder = Color(0x59000000)
            accent = Color(0xFF007AFF)
            fieldFill = Color(0x0F000000)
            fieldBorder = Color(0x1A000000)
            glassCanvas = Color(0xFFF4F4F6)
            glassSidebar = Color(0xFFECECEF)
        }
    }
}

class _SettingsAppState: State<StatefulWidget>, @unchecked Sendable {

    let bloc = SettingsBloc()

    /// Refreshed from MacosTheme at every build; read by the section
    /// builders (they don't take a BuildContext).
    private var pal = Palette(dark: true)

    override func initState() {
        super.initState()
        settingsBlocShared = bloc
        bloc.add(.loadInitialData)
        CupertinoIcons.registerFont()
    }

    override func build(_ context: any BuildContext) -> Widget {
        return withObservationTracking {
            _buildContent(context)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.setState {}
            }
        }
    }

    // MARK: - Content

    private func _buildContent(_ context: any BuildContext) -> Widget {
        let theme = MacosTheme.of(context)
        pal = Palette(dark: theme.brightness == .dark)
        let s = bloc.state

        return MacosScaffold(
            children: [
                // Sidebar (macOS System Settings style: search field on top,
                // rows with colored rounded icon tiles, blue selection pill)
                MacosSidebar(
                    minWidth: 200,
                    maxWidth: 200,
                    top: Padding(
                        padding: EdgeInsets(left: 12, top: 12, right: 12, bottom: 10),
                        child: _searchField()
                    ),
                    decoration: BoxDecoration(
                        color: pal.glassSidebar,
                        border: Border(
                            right: BorderSide(color: theme.dividerColor, width: 1)
                        )
                    ),
                    builder: { [self] (ctx: any BuildContext, _: ScrollController) in
                        return Padding(
                            padding: EdgeInsets(horizontal: 8),
                            child: Column(
                                children: [
                                    // Tile hues sit in the same muted band as
                                    // the shell's dock/launcher icon palette.
                                    self._sidebarItem(index: 0, icon: CupertinoIcons.gear,
                                                      tile: Color(0xFF737B89), label: "General", selected: s.selectedIndex),
                                    SizedBox(height: 2),
                                    self._sidebarItem(index: 1, icon: CupertinoIcons.wifi,
                                                      tile: Color(0xFF5C8FD6), label: "Network", selected: s.selectedIndex),
                                    SizedBox(height: 2),
                                    self._sidebarItem(index: 2, icon: CupertinoIcons.desktopcomputer,
                                                      tile: Color(0xFF4880C8), label: "Displays", selected: s.selectedIndex),
                                    SizedBox(height: 2),
                                    self._sidebarItem(index: 3, icon: CupertinoIcons.paintbrush_fill,
                                                      tile: Color(0xFF8A70CE), label: "Appearance", selected: s.selectedIndex),
                                    SizedBox(height: 2),
                                    self._sidebarItem(index: 4, icon: CupertinoIcons.info_circle_fill,
                                                      tile: Color(0xFF4FA4B4), label: "About", selected: s.selectedIndex),
                                ]
                            )
                        )
                    }
                ),
                // Content area
                Expanded(
                    child: _buildPage(context, index: s.selectedIndex)
                ),
            ],
            toolBar: MacosToolBar(
                height: 52,
                title: Text(
                    _tabTitle(s.selectedIndex),
                    style: TextStyle(
                        color: pal.textStrong,
                        fontSize: 15,
                        fontWeight: .w600
                    )
                ),
                // Transparent: the glass canvas shows through the toolbar.
                decoration: BoxDecoration(color: Color(0x00000000)),
                padding: EdgeInsets(horizontal: 16)
            ),
            backgroundColor: pal.glassCanvas
        )
    }

    /// Decorative sidebar search field (macOS System Settings signature).
    private func _searchField() -> Widget {
        return SizedBox(
            height: 26,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: pal.fieldFill,
                    border: Border.all(color: pal.fieldBorder, width: 0.5),
                    borderRadius: BorderRadius.all(Radius(circular: 6))
                ),
                child: Padding(
                    padding: EdgeInsets(horizontal: 7),
                    child: Row(children: [
                        MacosIcon(icon: CupertinoIcons.search, color: pal.textPlaceholder, size: 12),
                        SizedBox(width: 5),
                        Text("Search", style: TextStyle(color: pal.textPlaceholder, fontSize: 12)),
                    ])
                )
            )
        )
    }

    /// macOS System Settings sidebar row: colored rounded icon tile + label,
    /// with a solid accent-blue selection pill and white text when selected.
    private func _sidebarItem(index: Int, icon: IconData, tile: Color,
                              label: String, selected: Int) -> Widget {
        let isSelected = index == selected
        let iconTile: Widget = SizedBox(
            width: 20, height: 20,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: tile,
                    borderRadius: BorderRadius.all(Radius(circular: 5))
                ),
                child: Center(
                    child: MacosIcon(icon: icon, color: Color(0xFFFFFFFF), size: 12)
                )
            )
        )
        return GestureDetector(
            onTap: { [self] in
                bloc.add(.selectTab(index))
            },
            behavior: .opaque,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: isSelected ? pal.accent : Color(0x00000000),
                    borderRadius: BorderRadius.all(Radius(circular: 5))
                ),
                child: Padding(
                    padding: EdgeInsets(horizontal: 8, vertical: 5),
                    child: Row(children: [
                        iconTile,
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                label,
                                style: TextStyle(
                                    color: isSelected ? Color(0xFFFFFFFF) : pal.textPrimary,
                                    fontSize: 13
                                )
                            )
                        ),
                    ])
                )
            )
        )
    }

    private func _tabTitle(_ index: Int) -> String {
        switch index {
        case 0: return "General"
        case 1: return "Network"
        case 2: return "Displays"
        case 3: return "Appearance"
        case 4: return "About"
        default: return "Settings"
        }
    }

    private func _buildPage(_ context: any BuildContext, index: Int) -> Widget {
        switch index {
        case 0: return _buildGeneralPage()
        case 1: return _buildNetworkPage(context)
        case 2: return _buildDisplayPage()
        case 3: return _buildAppearancePage()
        case 4: return _buildAboutPage()
        default: return SizedBox(shrink: ())
        }
    }

    // MARK: - General Page (System Info)

    private func _buildGeneralPage() -> Widget {
        let s = bloc.state
        return Padding(
            padding: EdgeInsets(all: 24),
            child: Column(
                crossAxisAlignment: .start,
                children: [
                    // System section
                    _sectionHeader("System Information"),
                    SizedBox(height: 12),
                    _macosGroupBox([
                        _settingsRow("Starling OS", "Version \(SystemInfo.starlingVersion)"),
                        _divider(),
                        _settingsRow("OS", s.osVersion),
                        _divider(),
                        _settingsRow("Kernel", s.kernelVersion),
                        _divider(),
                        _settingsRow("Mesa", s.mesaVersion),
                    ]),
                ]
            )
        )
    }

    // MARK: - Network Page

    private func _buildNetworkPage(_ context: any BuildContext) -> Widget {
        let s = bloc.state
        var children: [Widget] = []

        // Wi-Fi toggle
        children.append(_sectionHeader("Wi-Fi"))
        children.append(SizedBox(height: 12))
        children.append(
            _macosGroupBox([
                _settingsRowWithTrailing(
                    "Wi-Fi",
                    s.wifiEnabled ? "Connected" : "Off",
                    MacosSwitch(
                        value: s.wifiEnabled,
                        onChanged: { [self] (val: Bool) in
                            bloc.add(.toggleWifi(val))
                        }
                    )
                ),
            ])
        )

        guard s.wifiEnabled else {
            return Padding(
                padding: EdgeInsets(all: 24),
                child: Column(crossAxisAlignment: .start, children: children)
            )
        }

        // Active connection
        if let info = s.connectionInfo {
            children.append(SizedBox(height: 20))
            children.append(_sectionHeader("Current Network"))
            children.append(SizedBox(height: 12))
            children.append(
                _macosGroupBox([
                    _settingsRowWithTrailing(
                        "\u{2705} \(info.ssid)",
                        "\(info.security.isEmpty ? "Open" : info.security)  \u{2022}  Signal: \(info.signal)%",
                        PushButton(
                            child: Text("Disconnect"),
                            controlSize: .small,
                            onPressed: { [self] in
                                bloc.add(.disconnect(connectionName: info.ssid))
                            }
                        )
                    ),
                    _divider(),
                    _detailRow("IP Address", info.ipAddress),
                    _detailRow("Gateway", info.gateway),
                    _detailRow("DNS", info.dns.joined(separator: ", ")),
                ])
            )
        }

        // Status
        if let status = s.networkStatus {
            children.append(SizedBox(height: 8))
            children.append(
                Text(status, style: TextStyle(color: Color(0xFFFF8800), fontSize: 11))
            )
        }

        // Available networks
        children.append(SizedBox(height: 20))
        children.append(
            Row(children: [
                _sectionHeader("Available Networks"),
                Expanded(child: SizedBox(shrink: ())),
                GestureDetector(
                    onTap: { [self] in bloc.add(.scanNetworks) },
                    child: Text(
                        "\u{21BB} Scan",
                        style: TextStyle(color: pal.accent, fontSize: 12)
                    )
                ),
            ])
        )
        children.append(SizedBox(height: 12))

        if s.wifiNetworks.isEmpty {
            children.append(
                Text(
                    "No networks found. Tap Scan to search.",
                    style: TextStyle(color: pal.textTertiary, fontSize: 12)
                )
            )
        } else {
            var rows: [Widget] = []
            for (i, network) in s.wifiNetworks.enumerated() {
                let ssid = network.ssid
                let isOpen = network.isOpen
                if i > 0 { rows.append(_divider()) }
                rows.append(
                    _settingsRowWithTrailing(
                        "\(network.signalBars)  \(network.ssid)",
                        network.securityLabel + (network.inUse ? "  \u{2022}  Connected" : ""),
                        network.inUse ? nil : GestureDetector(
                            onTap: { [self] in
                                if isOpen {
                                    bloc.add(.connectToNetwork(ssid: ssid, password: nil))
                                } else {
                                    _showConnectDialog(context, ssid: ssid)
                                }
                            },
                            child: Text("Connect", style: TextStyle(color: pal.accent, fontSize: 12))
                        )
                    )
                )
            }
            children.append(_macosGroupBox(rows))
        }

        // Saved networks
        if !s.savedConnections.isEmpty {
            children.append(SizedBox(height: 20))
            children.append(_sectionHeader("Saved Networks"))
            children.append(SizedBox(height: 12))
            var rows: [Widget] = []
            for (i, name) in s.savedConnections.enumerated() {
                let connName = name
                if i > 0 { rows.append(_divider()) }
                rows.append(
                    _settingsRowWithTrailing(
                        name, "",
                        GestureDetector(
                            onTap: { [self] in bloc.add(.forgetNetwork(connectionName: connName)) },
                            child: Text("Forget", style: TextStyle(color: Color(0xFFFF6666), fontSize: 11))
                        )
                    )
                )
            }
            children.append(_macosGroupBox(rows))
        }

        return Padding(
            padding: EdgeInsets(all: 24),
            child: SingleChildScrollView(
                child: Column(crossAxisAlignment: .start, children: children)
            )
        )
    }

    private func _showConnectDialog(_ context: any BuildContext, ssid: String) {
        showDialog(context: context, barrierDismissible: true, builder: { [self] ctx in
            return _WifiPasswordDialog(ssid: ssid, onConnect: { (password: String) in
                self.bloc.add(.connectToNetwork(ssid: ssid, password: password))
            })
        })
    }

    // MARK: - Display Page

    private func _buildDisplayPage() -> Widget {
        let s = bloc.state
        let maxDpi = SystemInfo.maxDPI()
        let divisions = Int((maxDpi - 1.0) * 4)  // 0.25 steps
        return Padding(
            padding: EdgeInsets(all: 24),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: .start,
                    children: [
                        _sectionHeader("Resolution & Scaling"),
                        SizedBox(height: 12),
                        _macosGroupBox([
                            _settingsRow("Scale (DPI)", "\(String(format: "%.2f", s.dpiValue))x"),
                            SizedBox(height: 8),
                            Padding(
                                padding: EdgeInsets(horizontal: 16),
                                child: Row(children: [
                                    Text("1x", style: TextStyle(color: pal.textSecondary, fontSize: 11)),
                                    SizedBox(
                                        width: 300,
                                        child: Slider(
                                            value: min(s.dpiValue, maxDpi),
                                            onChanged: { [self] (val: Double) in
                                                bloc.add(.changeDpi(val))
                                            },
                                            min: 1.0, max: maxDpi,
                                            divisions: max(divisions, 1)
                                        )
                                    ),
                                    Text("\(String(format: "%.0f", maxDpi))x", style: TextStyle(color: pal.textSecondary, fontSize: 11)),
                                ])
                            ),
                            SizedBox(height: 4),
                            Padding(
                                padding: EdgeInsets(horizontal: 16, vertical: 4),
                                child: Text(
                                    _dpiDescription(s.dpiValue),
                                    style: TextStyle(color: pal.textTertiary, fontSize: 11)
                                )
                            ),
                        ]),
                    ]
                )
            )
        )
    }

    private func _dpiDescription(_ dpi: Double) -> String {
        let screenW = Int(Double(ProcessInfo.processInfo.environment["FLUTTER_SCREEN_WIDTH"] ?? "") ?? 3840)
        let screenH = Int(Double(ProcessInfo.processInfo.environment["FLUTTER_SCREEN_HEIGHT"] ?? "") ?? 2160)
        let logW = Int(Double(screenW) / dpi)
        let logH = Int(Double(screenH) / dpi)
        let pct = Int(dpi * 100)
        if dpi <= 1.0 { return "1:1 pixel mapping — \(logW)x\(logH)" }
        return "\(pct)% scaling — \(logW)x\(logH) logical"
    }

    // MARK: - Appearance Page

    private func _buildAppearancePage() -> Widget {
        let s = bloc.state
        return Padding(
            padding: EdgeInsets(all: 24),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: .start,
                    children: [
                        _sectionHeader("Appearance"),
                        SizedBox(height: 12),
                        _macosGroupBox([
                            _settingsRowWithTrailing(
                                "Dark Mode", "Use dark theme for the interface",
                                MacosSwitch(
                                    value: s.darkMode,
                                    onChanged: { [self] (val: Bool) in bloc.add(.toggleDarkMode(val)) }
                                )
                            ),
                            _divider(),
                            _settingsRowWithTrailing(
                                "Tiling Windows", "Automatically tile windows instead of free-floating",
                                MacosSwitch(
                                    value: s.tilingWM,
                                    onChanged: { [self] (val: Bool) in bloc.add(.toggleTilingWM(val)) }
                                )
                            ),
                            _divider(),
                            _settingsRowWithTrailing(
                                "Notifications", "Show desktop notifications",
                                MacosSwitch(
                                    value: s.notifications,
                                    onChanged: { [self] (val: Bool) in bloc.add(.toggleNotifications(val)) }
                                )
                            ),
                            _divider(),
                            _settingsRowWithTrailing(
                                "Auto-Update", "Automatically install system updates",
                                MacosSwitch(
                                    value: s.autoUpdate,
                                    onChanged: { [self] (val: Bool) in bloc.add(.toggleAutoUpdate(val)) }
                                )
                            ),
                        ]),
                        SizedBox(height: 20),
                        _sectionHeader("Sound & Brightness"),
                        SizedBox(height: 12),
                        _macosGroupBox([
                            Padding(
                                padding: EdgeInsets(horizontal: 16, vertical: 10),
                                child: Row(children: [
                                    SizedBox(
                                        width: 80,
                                        child: Text("Brightness", style: TextStyle(color: pal.textPrimary, fontSize: 13))
                                    ),
                                    Expanded(
                                        child: Slider(
                                            value: s.brightness,
                                            onChanged: { [self] (val: Double) in bloc.add(.changeBrightness(val)) },
                                            min: 0, max: 100
                                        )
                                    ),
                                ])
                            ),
                            _divider(),
                            Padding(
                                padding: EdgeInsets(horizontal: 16, vertical: 10),
                                child: Row(children: [
                                    SizedBox(
                                        width: 80,
                                        child: Text("Volume", style: TextStyle(color: pal.textPrimary, fontSize: 13))
                                    ),
                                    Expanded(
                                        child: Slider(
                                            value: s.volume,
                                            onChanged: { [self] (val: Double) in bloc.add(.changeVolume(val)) },
                                            min: 0, max: 100
                                        )
                                    ),
                                ])
                            ),
                        ]),
                        SizedBox(height: 20),
                        _sectionHeader("Accent Color"),
                        SizedBox(height: 12),
                        Row(
                            spacing: 8,
                            children: [
                                _colorSwatch(Color(0xFF007AFF)), // Blue
                                _colorSwatch(Color(0xFFAF52DE)), // Purple
                                _colorSwatch(Color(0xFFFF2D55)), // Pink
                                _colorSwatch(Color(0xFFFF3B30)), // Red
                                _colorSwatch(Color(0xFFFF9500)), // Orange
                                _colorSwatch(Color(0xFF34C759)), // Green
                                _colorSwatch(Color(0xFF8E8E93)), // Graphite
                            ]
                        ),
                    ]
                )
            )
        )
    }

    private func _colorSwatch(_ color: Color) -> Widget {
        return SizedBox(
            width: 28, height: 28,
            child: ClipRRect(
                borderRadius: BorderRadius.all(Radius(circular: 14)),
                child: ColoredBox(color: color, child: SizedBox(expand: ()))
            )
        )
    }

    // MARK: - About Page

    private func _buildAboutPage() -> Widget {
        #if os(macOS)
        let platformName = "macOS (Darwin)"
        #elseif os(Linux)
        let platformName = "Linux"
        #endif

        return Padding(
            padding: EdgeInsets(all: 24),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: .start,
                    children: [
                        // macOS-style centered logo area
                        SizedBox(height: 20),
                        Center(
                            child: Column(
                                children: [
                                    Text(
                                        "\u{2B50}",
                                        style: TextStyle(fontSize: 48)
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                        "Starling OS",
                                        style: TextStyle(
                                            color: pal.textStrong,
                                            fontSize: 20,
                                            fontWeight: .w600
                                        )
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                        "Version \(SystemInfo.starlingVersion)",
                                        style: TextStyle(color: pal.textSecondary, fontSize: 13)
                                    ),
                                ]
                            )
                        ),
                        SizedBox(height: 24),
                        _macosGroupBox([
                            _settingsRow("Framework", "Flutter Swift + macOS UI"),
                            _divider(),
                            _settingsRow("Platform", platformName),
                        ]),
                    ]
                )
            )
        )
    }

    // MARK: - macOS-style Helpers

    /// Section header text (small, gray, uppercase-style).
    private func _sectionHeader(_ title: String) -> Widget {
        // macOS-style group header: small and secondary. Note w600 would
        // render as full Bold — Noto Sans ships no SemiBold face, so
        // fontconfig substitutes 700 — which reads fat and soft in white.
        return Text(
            title,
            style: TextStyle(
                color: pal.textSecondary,
                fontSize: 12,
                fontWeight: .w600
            )
        )
    }

    /// A macOS-style grouped box with rounded corners and subtle background.
    private func _macosGroupBox(_ children: [Widget]) -> Widget {
        return DecoratedBox(
            decoration: BoxDecoration(
                color: Color(rgbo: 255, 255, 255, 0.06),
                border: Border.all(
                    color: Color(rgbo: 255, 255, 255, 0.1),
                    width: 0.5
                ),
                borderRadius: BorderRadius.all(Radius(circular: 8))
            ),
            child: Padding(
                padding: EdgeInsets(vertical: 4),
                child: Column(
                    crossAxisAlignment: .start,
                    children: children
                )
            )
        )
    }

    /// A settings row with label and value text.
    private func _settingsRow(_ label: String, _ value: String) -> Widget {
        return Padding(
            padding: EdgeInsets(horizontal: 16, vertical: 8),
            child: Row(children: [
                Text(label, style: TextStyle(color: pal.textPrimary, fontSize: 13)),
                Expanded(child: SizedBox(shrink: ())),
                Text(value, style: TextStyle(color: pal.textSecondary, fontSize: 13)),
            ])
        )
    }

    /// A settings row with label, subtitle, and a trailing widget.
    private func _settingsRowWithTrailing(_ label: String, _ subtitle: String, _ trailing: Widget?) -> Widget {
        return Padding(
            padding: EdgeInsets(horizontal: 16, vertical: 8),
            child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: .start,
                        children: subtitle.isEmpty
                            ? [Text(label, style: TextStyle(color: pal.textPrimary, fontSize: 13))]
                            : [
                                Text(label, style: TextStyle(color: pal.textPrimary, fontSize: 13)),
                                SizedBox(height: 2),
                                Text(subtitle, style: TextStyle(color: pal.textSecondary, fontSize: 11)),
                              ]
                    )
                ),
                trailing ?? SizedBox(shrink: ()),
            ])
        )
    }

    /// A detail key-value row (used in network info).
    private func _detailRow(_ label: String, _ value: String) -> Widget {
        return Padding(
            padding: EdgeInsets(left: 16, top: 2, right: 16, bottom: 2),
            child: Row(children: [
                SizedBox(
                    width: 80,
                    child: Text(label, style: TextStyle(color: pal.textTertiary, fontSize: 11))
                ),
                Expanded(
                    child: Text(value, style: TextStyle(color: pal.textSecondary, fontSize: 11))
                ),
            ])
        )
    }

    /// A thin divider line.
    private func _divider() -> Widget {
        return Padding(
            padding: EdgeInsets(horizontal: 16),
            child: SizedBox(
                height: 1,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(rgbo: 255, 255, 255, 0.08))
                )
            )
        )
    }
}

// MARK: - Wi-Fi Password Dialog

class _WifiPasswordDialog: StatefulWidget {
    let ssid: String
    let onConnect: (String) -> Void

    init(ssid: String, onConnect: @escaping (String) -> Void) {
        self.ssid = ssid
        self.onConnect = onConnect
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return _WifiPasswordDialogState()
    }
}

class _WifiPasswordDialogState: State<StatefulWidget> {
    var password: String = ""

    override func build(_ context: any BuildContext) -> Widget {
        let dialog = widget as! _WifiPasswordDialog
        return MacosAlertDialog(
            appIcon: Text("\u{1F512}", style: TextStyle(fontSize: 32)),
            title: Text("Connect to \(dialog.ssid)"),
            message: Text("Enter the Wi-Fi password to join this network."),
            primaryButton: PushButton(
                child: Text("Connect"),
                controlSize: .regular,
                onPressed: { [self] in _connect(context) }
            ),
            secondaryButton: PushButton(
                child: Text("Cancel"),
                controlSize: .regular,
                onPressed: { Navigator.pop(context) },
                secondary: true
            )
        )
    }

    private func _connect(_ context: any BuildContext) {
        let dialog = widget as! _WifiPasswordDialog
        Navigator.pop(context)
        dialog.onConnect(password)
    }
}
