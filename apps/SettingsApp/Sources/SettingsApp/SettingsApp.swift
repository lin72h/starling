// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import CupertinoIcons
import Foundation
import Observation
import StarlingNet

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
                                    self._sidebarItem(index: 4, icon: CupertinoIcons.battery_100,
                                                      tile: Color(0xFF63A56E), label: "Power", selected: s.selectedIndex),
                                    SizedBox(height: 2),
                                    self._sidebarItem(index: 5, icon: CupertinoIcons.info_circle_fill,
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
        case 4: return "Power"
        case 5: return "About"
        default: return "Settings"
        }
    }

    private func _buildPage(_ context: any BuildContext, index: Int) -> Widget {
        switch index {
        case 0: return _buildGeneralPage()
        case 1: return _buildNetworkPage(context)
        case 2: return _buildDisplayPage()
        case 3: return _buildAppearancePage()
        case 4: return _buildPowerPage()
        case 5: return _buildAboutPage()
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
                        _settingsRow("Starling OS", "Version \(SystemInfo.starlingVersion())"),
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

        // Wired first: on a desktop it is usually the connection that matters,
        // and it needs no interaction to be useful.
        if !s.wiredLinks.isEmpty {
            children.append(_sectionHeader("Wired"))
            children.append(SizedBox(height: 12))
            var rows: [Widget] = []
            for (i, link) in s.wiredLinks.enumerated() {
                let dev = link.device
                let isUp = link.connected
                if i > 0 { rows.append(_divider()) }
                rows.append(
                    _settingsRowWithTrailingIcon(
                        CupertinoIcons.globe,
                        link.device,
                        link.summary,
                        // Without a cable there is nothing a button could do
                        // but fail, so don't offer one.
                        link.carrier ? PushButton(
                            child: Text(isUp ? "Disconnect" : "Connect"),
                            controlSize: .small,
                            onPressed: { [self] in
                                bloc.add(.setWiredConnected(device: dev,
                                                            connected: !isUp))
                            }
                        ) : nil
                    )
                )
                if link.connected {
                    rows.append(_detailRow("IP Address", link.ipAddress))
                    rows.append(_detailRow("Gateway", link.gateway))
                    rows.append(_detailRow("DNS", link.dns.joined(separator: ", ")))
                    rows.append(_detailRow("MAC", link.mac))
                }
            }
            children.append(_macosGroupBox(rows))
            children.append(SizedBox(height: 20))
        }

        // Wi-Fi toggle
        children.append(_sectionHeader("Wi-Fi"))
        children.append(SizedBox(height: 12))
        children.append(
            _macosGroupBox([
                _settingsRowWithTrailing(
                    "Wi-Fi",
                    // "Connected to X" / "On" / "Off" — radio-on is not
                    // "Connected"; that is what connectionInfo answers.
                    s.wifiEnabled
                        ? (s.connectionInfo.map { "Connected to \($0.ssid)" } ?? "On")
                        : "Off",
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
            // Scrolls like the main path: with the wired details above it,
            // this branch is no longer guaranteed to be short.
            return Padding(
                padding: EdgeInsets(all: 24),
                child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: .start, children: children)
                )
            )
        }

        // Active connection
        if let info = s.connectionInfo {
            children.append(SizedBox(height: 20))
            children.append(_sectionHeader("Current Network"))
            children.append(SizedBox(height: 12))
            children.append(
                _macosGroupBox([
                    // No emoji in labels — Noto Sans has no glyph for ✅ (or
                    // the block-element bars), and the fallback renders a
                    // tofu box. Icons come from CupertinoIcons, which the
                    // app registers at startup.
                    _settingsRowWithTrailingIcon(
                        CupertinoIcons.checkmark_circle_fill,
                        info.ssid,
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
                    _detailRow("Interface", info.device.isEmpty
                        ? "" : "\(info.device)  \u{2022}  \(info.mac)"),
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
                    child: Row(mainAxisSize: .min, children: [
                        MacosIcon(icon: CupertinoIcons.arrow_clockwise,
                                  color: pal.accent, size: 12),
                        SizedBox(width: 4),
                        Text("Scan", style: TextStyle(color: pal.accent, fontSize: 12)),
                    ])
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
                let isSaved = s.savedConnections.contains(ssid)
                if i > 0 { rows.append(_divider()) }
                rows.append(
                    _wifiListRow(
                        network,
                        network.inUse ? nil : GestureDetector(
                            onTap: { [self] in
                                if isOpen || isSaved {
                                    // Open, or saved with a stored password —
                                    // no dialog to answer.
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

    /// Four ascending bars lit by signal strength — drawn rects, not the
    /// ▂▄▆█ block glyphs: Noto Sans ships no block elements, so the text
    /// spelling renders as tofu (same fix as the shell popup's bars).
    private func _signalBars(_ signal: Int) -> Widget {
        var bars: [Widget] = []
        let heights: [Double] = [4, 6, 8, 10]
        let thresholds = [1, 30, 55, 80]
        for i in 0..<4 {
            if i > 0 { bars.append(SizedBox(width: 2)) }
            bars.append(DecoratedBox(
                decoration: BoxDecoration(
                    color: signal >= thresholds[i] ? pal.textSecondary : pal.fieldFill,
                    borderRadius: BorderRadius.all(Radius(circular: 1))
                ),
                child: SizedBox(width: 3, height: heights[i])
            ))
        }
        return Row(mainAxisSize: .min, crossAxisAlignment: .end, children: bars)
    }

    /// An available-network row: signal bars + SSID + security subtitle.
    private func _wifiListRow(_ network: WifiNetwork, _ trailing: Widget?) -> Widget {
        return Padding(
            padding: EdgeInsets(horizontal: 16, vertical: 8),
            child: Row(children: [
                _signalBars(network.signal),
                SizedBox(width: 10),
                Expanded(
                    child: Column(crossAxisAlignment: .start, children: [
                        Text(network.ssid, style: TextStyle(color: pal.textPrimary, fontSize: 13)),
                        SizedBox(height: 2),
                        Text(network.securityLabel + (network.inUse ? "  \u{2022}  Connected" : ""),
                             style: TextStyle(color: pal.textSecondary, fontSize: 11)),
                    ])
                ),
                trailing ?? SizedBox(shrink: ()),
            ])
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
                        ]),
                        SizedBox(height: 20),
                        _sectionHeader("Wallpaper"),
                        SizedBox(height: 12),
                        _macosGroupBox([
                            Padding(
                                padding: EdgeInsets(horizontal: 16, vertical: 12),
                                child: Row(children: _wallpaperSwatches(selected: s.wallpaper))
                            ),
                        ]),
                        // No Notifications or Auto-Update toggles, no
                        // Brightness or Volume sliders, and no accent picker.
                        // All five sat here once, flipping local state and
                        // nothing else — a control that looks settable and
                        // isn't is worse than its absence. Each comes back
                        // with the backend that makes it real (a notification
                        // daemon, an updater, a backlight writer, an audio
                        // layer, the accent plumbing).
                    ]
                )
            )
        )
    }

    /// One swatch per shell wallpaper preset. The raw values and colors
    /// mirror WallpaperPreset in the shell — the shell owns the enum; this
    /// is its presentation here, and an unknown value from a newer shell
    /// simply shows no selection ring.
    private func _wallpaperSwatches(selected: Int) -> [Widget] {
        let presets: [(raw: Int, name: String, color: Color)] = [
            (0, "Photo", Color(0xFF3A6EA8)),
            (1, "Slate", Color(0xFF2C3444)),
            (2, "Dusk",  Color(0xFF342C4E)),
            (3, "Ocean", Color(0xFF173540)),
            (4, "Ember", Color(0xFF3C302B)),
        ]
        var out: [Widget] = []
        for p in presets {
            out.append(GestureDetector(
                onTap: { [self] in bloc.add(.selectWallpaper(p.raw)) },
                child: Padding(
                    padding: EdgeInsets(right: 14),
                    child: Column(mainAxisSize: .min, children: [
                        DecoratedBox(
                            decoration: BoxDecoration(
                                color: p.color,
                                border: selected == p.raw
                                    ? Border.all(color: Color(0xFF4880C8), width: 2)
                                    : Border.all(color: Color(0x33808080), width: 1),
                                borderRadius: BorderRadius.circular(6)
                            ),
                            child: SizedBox(width: 64, height: 40)
                        ),
                        SizedBox(height: 4),
                        Text(p.name, style: TextStyle(
                            color: selected == p.raw ? pal.textPrimary : pal.textSecondary,
                            fontSize: 11)),
                    ])
                )
            ))
        }
        return out
    }

    // MARK: - Power Page

    /// "2 h 05 min" under an hour shortens to "45 min" — the same spelling
    /// as the shell's battery popup.
    private func _formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
        }
        return "\(minutes) min"
    }

    private func _buildPowerPage() -> Widget {
        let b = bloc.state.battery
        var children: [Widget] = [
            _sectionHeader("Battery"),
            SizedBox(height: 12),
        ]
        if b.present {
            let barColor: Color = b.state == .discharging && b.percent <= 20
                ? Color(0xFFFF3B30)
                : (b.state == .charging ? Color(0xFF34C759) : Color(0xFF4880C8))
            var rows: [Widget] = [
                _settingsRow("Charge", "\(b.percent)%"),
                Padding(
                    padding: EdgeInsets(left: 16, top: 2, right: 16, bottom: 12),
                    child: SizedBox(
                        height: 8,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Color(0x33808080),
                                borderRadius: BorderRadius.circular(4)
                            ),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                    widthFactor: Double(b.percent) / 100.0,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: SizedBox(expand: ())
                                    )
                                )
                            )
                        )
                    )
                ),
                _divider(),
                _settingsRow("Status", b.state.label),
                _divider(),
                _settingsRow("Power Source", b.acOnline ? "AC Power" : "Battery"),
            ]
            // Estimate rows only when the kernel offered a rate — a missing
            // estimate reads as a missing row, never a made-up time.
            if b.state == .charging, let m = b.minutesToFull {
                rows.append(_divider())
                rows.append(_settingsRow("Time to Full", _formatMinutes(m)))
            } else if b.state == .discharging, let m = b.minutesToEmpty {
                rows.append(_divider())
                rows.append(_settingsRow("Time Remaining", _formatMinutes(m)))
            }
            children.append(_macosGroupBox(rows))
        } else {
            children.append(_macosGroupBox([
                _settingsRow("Battery", "None detected"),
            ]))
            children.append(SizedBox(height: 8))
            children.append(Text(
                "This machine reports no system battery — power settings apply to laptops.",
                style: TextStyle(color: pal.textTertiary, fontSize: 11)
            ))
        }
        return Padding(
            padding: EdgeInsets(all: 24),
            child: SingleChildScrollView(
                child: Column(crossAxisAlignment: .start, children: children)
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
                                        "Version \(SystemInfo.starlingVersion())",
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

    /// A settings row led by an icon (label, subtitle, trailing widget).
    private func _settingsRowWithTrailingIcon(
        _ icon: IconData, _ label: String, _ subtitle: String, _ trailing: Widget?
    ) -> Widget {
        return Padding(
            padding: EdgeInsets(horizontal: 16, vertical: 8),
            child: Row(children: [
                MacosIcon(icon: icon, color: pal.accent, size: 15),
                SizedBox(width: 8),
                Expanded(
                    child: Column(crossAxisAlignment: .start, children: [
                        Text(label, style: TextStyle(color: pal.textPrimary, fontSize: 13)),
                        SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: pal.textSecondary, fontSize: 11)),
                    ])
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

    /// The framework has no editable text field widget, so the dialog types
    /// the way TextEditorApp does: a FocusNode receives raw KeyData and this
    /// state keeps the string, while a controller-driven MacosTextField
    /// (display-only by design) renders the masked dots.
    private let focus = FocusNode(debugLabel: "WifiPasswordDialog")
    private let masked = TextEditingController()
    /// The build context of the last frame — Enter/Escape need one for
    /// Navigator.pop and arrive outside any build.
    private weak var _elementContext: Element?

    override func initState() {
        super.initState()
        focus.onKeyData = { [weak self] keyData in
            return self?._handleKey(keyData) ?? false
        }
        focus.requestFocus()
    }

    override func dispose() {
        focus.dispose()
        masked.dispose()
        super.dispose()
    }

    private func _handleKey(_ keyData: KeyData) -> Bool {
        guard keyData.type == .down || keyData.type == .repeat else { return false }
        // Child apps receive X11 keysyms in `logical` (the DRM embedder's
        // convention — see TextEditorApp's Keysym table). The shell's own
        // widgets switch on HID `physical`; do not copy that code here.
        switch keyData.logical {
        case 0xFF1B:  // Escape — cancel
            if let ctx = _elementContext { Navigator.pop(ctx) }
            return true
        case 0xFF08:  // Backspace
            if !password.isEmpty {
                password.removeLast()
                _syncMask()
            }
            return true
        case 0xFF0D, 0xFF8D:  // Enter / keypad Enter — connect
            if let ctx = _elementContext { _connect(ctx) }
            return true
        default:
            if let ch = keyData.character,
               let s = ch.unicodeScalars.first,
               s.value >= 0x20, s.value != 0x7F {
                password += ch
                _syncMask()
                return true
            }
            return false
        }
    }

    private func _syncMask() {
        masked.text = String(repeating: "\u{2022}", count: password.count)
        setState {}
    }

    override func build(_ context: any BuildContext) -> Widget {
        let dialog = widget as! _WifiPasswordDialog
        _elementContext = context as? Element
        return MacosAlertDialog(
            appIcon: Text("\u{1F512}", style: TextStyle(fontSize: 32)),
            title: Text("Connect to \(dialog.ssid)"),
            message: Column(mainAxisSize: .min, children: [
                Text("Enter the Wi-Fi password to join this network."),
                SizedBox(height: 10),
                MacosTextField(
                    controller: masked,
                    placeholder: "Password"
                ),
            ]),
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
