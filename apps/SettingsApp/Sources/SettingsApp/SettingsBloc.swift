// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import Foundation
import Observation

/// Set by _SettingsAppState so the themed root can sync the Dark Mode
/// switch when the shell pushes an appearance change.
nonisolated(unsafe) var settingsBlocShared: SettingsBloc?

// MARK: - Settings State

struct SettingsState {
    // Navigation
    var selectedIndex: Int = 0

    // System Info
    var osVersion: String = ""
    var kernelVersion: String = ""
    var mesaVersion: String = ""

    // Network
    var wifiEnabled: Bool = false
    var wifiNetworks: [WifiNetwork] = []
    var connectionInfo: WifiConnectionInfo? = nil
    var savedConnections: [String] = []
    var networkStatus: String? = nil

    // Display
    var dpiValue: Double = SystemInfo.currentDPI()

    // Personalization. The shell owns the desktop appearance and pushes it at
    // connect, before this bloc exists — seed from it so the Dark Mode switch
    // agrees with the theme the app is actually drawn in.
    #if os(Linux)
    var darkMode: Bool = GpuDmaBufRenderer.lastPushedThemeIsDark ?? true
    /// Window-manager layout — the shell owns it and pushes at connect.
    var tilingWM: Bool = GpuDmaBufRenderer.lastPushedLayoutIsTiling ?? false
    #else
    var darkMode: Bool = true
    var tilingWM: Bool = false
    #endif
    var notifications: Bool = true
    var autoUpdate: Bool = false
    var brightness: Double = 75.0
    var volume: Double = 50.0
}

// MARK: - Settings Events

enum SettingsEvent {
    // Lifecycle
    case loadInitialData

    // Navigation
    case selectTab(Int)

    // Network
    case toggleWifi(Bool)
    case scanNetworks
    case connectToNetwork(ssid: String, password: String?)
    case disconnect(connectionName: String)
    case forgetNetwork(connectionName: String)

    // Display
    case changeDpi(Double)

    // Personalization
    case toggleDarkMode(Bool)
    /// Appearance pushed by the shell (no echo back).
    case themeApplied(Bool)
    case toggleTilingWM(Bool)
    /// Layout pushed by the shell (no echo back).
    case layoutApplied(Bool)
    case toggleNotifications(Bool)
    case toggleAutoUpdate(Bool)
    case changeBrightness(Double)
    case changeVolume(Double)
}

// MARK: - Settings BLoC

@Observable
final class SettingsBloc: @unchecked Sendable {

    /// The single source of truth for the UI.
    private(set) var state = SettingsState()

    /// The only way the UI talks to the BLoC.
    func add(_ event: SettingsEvent) {
        switch event {
        case .loadInitialData:
            _loadInitialData()
        case .selectTab(let index):
            state.selectedIndex = index
        case .toggleWifi(let enabled):
            _toggleWifi(enabled)
        case .scanNetworks:
            _scanNetworks()
        case .connectToNetwork(let ssid, let password):
            _connectToNetwork(ssid: ssid, password: password)
        case .disconnect(let name):
            _disconnect(connectionName: name)
        case .forgetNetwork(let name):
            _forgetNetwork(connectionName: name)
        case .changeDpi(let value):
            state.dpiValue = value
            _applyDpi(value)
        case .toggleDarkMode(let value):
            state.darkMode = value
            _applyTheme(value)
        case .themeApplied(let value):
            state.darkMode = value
        case .toggleTilingWM(let value):
            state.tilingWM = value
            _applyLayout(value)
        case .layoutApplied(let value):
            state.tilingWM = value
        case .toggleNotifications(let value):
            state.notifications = value
        case .toggleAutoUpdate(let value):
            state.autoUpdate = value
        case .changeBrightness(let value):
            state.brightness = value
        case .changeVolume(let value):
            state.volume = value
        }
    }

    // MARK: - Event Handlers

    private func _loadInitialData() {
        // Load on background thread to avoid blocking the first frame.
        Task.detached {
            let os = SystemInfo.osVersion()
            let kernel = SystemInfo.kernelVersion()
            let mesa = SystemInfo.mesaVersion()
            #if os(Linux)
            let wifiOn = WifiManager.isWifiEnabled()
            let networks = wifiOn ? WifiManager.listNetworks() : [WifiNetwork]()
            let connInfo = wifiOn ? WifiManager.activeConnectionInfo() : nil
            let saved = wifiOn ? WifiManager.savedConnections() : [String]()
            #endif
            await MainActor.run { [self] in
                state.osVersion = os
                state.kernelVersion = kernel
                state.mesaVersion = mesa
                #if os(Linux)
                state.wifiEnabled = wifiOn
                state.wifiNetworks = networks
                state.connectionInfo = connInfo
                state.savedConnections = saved
                #endif
            }
        }
    }

    private func _toggleWifi(_ enabled: Bool) {
        state.wifiEnabled = enabled
        if !enabled {
            state.wifiNetworks = []
            state.connectionInfo = nil
        }
        Task.detached {
            WifiManager.setWifiEnabled(enabled)
            if enabled {
                let networks = WifiManager.listNetworks()
                let info = WifiManager.activeConnectionInfo()
                await MainActor.run { [self] in
                    state.wifiNetworks = networks
                    state.connectionInfo = info
                }
            }
        }
    }

    private func _scanNetworks() {
        state.networkStatus = "Scanning..."
        Task.detached {
            let networks = WifiManager.scanAndListNetworks()
            let info = WifiManager.activeConnectionInfo()
            await MainActor.run { [self] in
                state.wifiNetworks = networks
                state.connectionInfo = info
                state.networkStatus = nil
            }
        }
    }

    private func _connectToNetwork(ssid: String, password: String?) {
        state.networkStatus = "Connecting to \(ssid)..."
        Task.detached {
            let error = WifiManager.connect(ssid: ssid, password: password)
            let networks = WifiManager.listNetworks()
            let info = WifiManager.activeConnectionInfo()
            let saved = WifiManager.savedConnections()
            await MainActor.run { [self] in
                state.networkStatus = error.map { "Failed: \($0)" }
                state.wifiNetworks = networks
                state.connectionInfo = info
                state.savedConnections = saved
            }
        }
    }

    private func _disconnect(connectionName: String) {
        state.connectionInfo = nil
        state.networkStatus = "Disconnecting..."
        Task.detached {
            let _ = WifiManager.disconnect(connectionName: connectionName)
            let networks = WifiManager.listNetworks()
            await MainActor.run { [self] in
                state.wifiNetworks = networks
                state.networkStatus = nil
            }
        }
    }

    private func _applyDpi(_ dpi: Double) {
        #if os(Linux)
        GpuDmaBufRenderer.current?.sendDpiChange(dpi)
        #endif
    }

    /// Forward the Dark Mode toggle to the shell, which switches the
    /// desktop appearance and persists it.
    private func _applyTheme(_ dark: Bool) {
        #if os(Linux)
        GpuDmaBufRenderer.current?.sendThemeChange(dark: dark)
        #endif
    }

    /// Forward the Tiling Windows toggle to the shell, which switches the
    /// window manager and persists it.
    private func _applyLayout(_ tiling: Bool) {
        #if os(Linux)
        GpuDmaBufRenderer.current?.sendLayoutChange(tiling: tiling)
        #endif
    }

    private func _forgetNetwork(connectionName: String) {
        state.networkStatus = "Forgetting \"\(connectionName)\"..."
        Task.detached {
            let _ = WifiManager.forget(connectionName: connectionName)
            let saved = WifiManager.savedConnections()
            await MainActor.run { [self] in
                state.savedConnections = saved
                state.networkStatus = "Forgot \"\(connectionName)\""
            }
        }
    }
}
