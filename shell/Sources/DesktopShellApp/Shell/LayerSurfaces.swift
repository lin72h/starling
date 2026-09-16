// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation
import WaylandServerBridge

// MARK: - Layer surfaces (zwlr_layer_shell_v1)
//
// A layer surface is a client surface the compositor places at a screen
// coordinate instead of managing: a bar, a notification, a launcher, a lock
// screen — or, for wmbench, every window it needs to put somewhere exactly
// and then photograph. It is anchored to an output's edges with margins, sits
// in one of four layers around the windows, and is never decorated.
//
// The compositor (wayland_layer_shell.c) validates and configures; this file
// is the placement. The position is computed from the anchor, the margins
// and the buffer the client ACTUALLY committed — a client may answer a
// configure with a different size, and a right-anchored bar must still hug
// the right edge.
//
// Only the host output draws layer surfaces today: the secondary outputs'
// own Flutter views (SecondaryOutputScreen) have no layer pass yet, so a
// surface asked onto output N>0 is drawn on the host at its host-relative
// position. Exclusive zones on the host feed WindowManager.layerInsets, so a
// third-party panel keeps maximized windows off its strip.

/// One mapped layer surface, as the shell tracks it.
final class LayerSurfaceEntry {
    let surfaceId: UInt32
    let textureId: Int
    var info: LayerSurfaceInfo
    /// The committed buffer's logical size; 0 until the first buffer.
    var bufferWidth: Double = 0
    var bufferHeight: Double = 0
    /// wp_alpha_modifier
    var alpha: Double = 1.0
    /// Where the surface was placed by the last layout pass (host logical
    /// coordinates), so popups parented to it can be positioned.
    var absX: Double = 0
    var absY: Double = 0
    var width: Double = 0
    var height: Double = 0

    init(surfaceId: UInt32, textureId: Int, info: LayerSurfaceInfo) {
        self.surfaceId = surfaceId
        self.textureId = textureId
        self.info = info
    }

    var mapped: Bool { bufferWidth > 0 && bufferHeight > 0 }
}

enum LayerShellAnchor {
    static let top: UInt32 = 1
    static let bottom: UInt32 = 2
    static let left: UInt32 = 4
    static let right: UInt32 = 8
}

extension _DesktopShellState {

    /// The logical rect of the output a layer surface was asked onto — the
    /// host's, in host coordinates, since that is the only view drawing
    /// layer surfaces today.
    private func _layerOutputRect() -> Rect {
        if let host = displayLayout?.host {
            // The host view's origin is its own logical origin, and the
            // desktop Stack is laid out in global logical coordinates with
            // the host at (0,0) — see _buildShellRoot.
            return Rect.fromLTWH(0, 0, host.logicalWidth, host.logicalHeight)
        }
        return Rect.fromLTWH(0, 0, screenWidth, screenHeight)
    }

    /// Place every layer surface: size from the committed buffer (falling
    /// back to the configured size), position from anchor + margins.
    func _layoutLayerSurfaces() {
        let out = _layerOutputRect()
        for entry in layerSurfaces.values {
            let info = entry.info
            let w = entry.bufferWidth > 0 ? entry.bufferWidth : Double(info.width)
            let h = entry.bufferHeight > 0 ? entry.bufferHeight : Double(info.height)
            let a = info.anchor
            let left = a & LayerShellAnchor.left != 0, right = a & LayerShellAnchor.right != 0
            let top = a & LayerShellAnchor.top != 0, bottom = a & LayerShellAnchor.bottom != 0
            let ml = Double(info.marginLeft), mr = Double(info.marginRight)
            let mt = Double(info.marginTop), mb = Double(info.marginBottom)
            var x: Double
            var y: Double
            if left && !right {
                x = ml
            } else if right && !left {
                x = out.width - w - mr
            } else if left && right {
                x = ml + (out.width - ml - mr - w) / 2
            } else {
                x = (out.width - w) / 2
            }
            if top && !bottom {
                y = mt
            } else if bottom && !top {
                y = out.height - h - mb
            } else if top && bottom {
                y = mt + (out.height - mt - mb - h) / 2
            } else {
                y = (out.height - h) / 2
            }
            entry.absX = out.left + x
            entry.absY = out.top + y
            entry.width = w
            entry.height = h
        }
    }

    /// Recompute the strips exclusive zones reserve on the host output and
    /// hand the resulting work area to the window manager (maximize) and
    /// the compositor (xx-zones).
    func _applyLayerInsets() {
        var top = 0.0, bottom = 0.0, left = 0.0, right = 0.0
        for entry in layerSurfaces.values where entry.info.exclusiveZone > 0 {
            let z = Double(entry.info.exclusiveZone)
            switch entry.info.exclusiveEdge {
            case LayerShellAnchor.top:    top = max(top, z + Double(entry.info.marginTop))
            case LayerShellAnchor.bottom: bottom = max(bottom, z + Double(entry.info.marginBottom))
            case LayerShellAnchor.left:   left = max(left, z + Double(entry.info.marginLeft))
            case LayerShellAnchor.right:  right = max(right, z + Double(entry.info.marginRight))
            default: break
            }
        }
        let insets = (top: top, bottom: bottom, left: left, right: right)
        if windowManager.layerInsets != insets {
            windowManager.layerInsets = insets
        }
        _pushWorkArea()
    }

    /// The host output's work area, for the compositor's zones.
    func _pushWorkArea() {
        let ref = _layerOutputRect()
        let wa = windowManager.workArea(for: ref, screenWidth: screenWidth, screenHeight: screenHeight)
        waylandIntegration?.setWorkArea(outputIndex: 0,
                                        x: Int(wa.left.rounded()), y: Int(wa.top.rounded()),
                                        width: Int(wa.width.rounded()), height: Int(wa.height.rounded()))
    }

    /// The widgets for every mapped layer surface in `layers` (0 background,
    /// 1 bottom, 2 top, 3 overlay), each followed by the popups rooted at
    /// it, which `stashedLayerPopups` collected during the popup pass.
    func _layerSurfaceWidgets(layers: Set<Int>,
                              stashedLayerPopups: [UInt32: [Widget]],
                              namespace: String? = nil) -> [Widget] {
        guard let wl = waylandIntegration else { return [] }
        var out: [Widget] = []
        let ordered = layerSurfaces.values
            .filter { layers.contains($0.info.layer) && $0.mapped &&
                      (namespace == nil || $0.info.namespace == namespace) }
            .sorted { $0.info.layer != $1.info.layer ? $0.info.layer < $1.info.layer
                                                     : $0.surfaceId < $1.surfaceId }
        for entry in ordered {
            let surfaceId = entry.surfaceId
            var texture: Widget = TextureWidget(textureId: entry.textureId, filterQuality: .none)
            // Wayland buffers arrive top-down; the texture path draws bottom-up.
            texture = Transform(
                transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
                alignment: Alignment.center,
                child: texture)
            if entry.alpha < 1.0 {
                texture = Opacity(opacity: max(0.0, entry.alpha), child: texture)
            }
            let onDemandKeys = entry.info.keyboardInteractivity == 2
            let child = Listener(
                onPointerDown: { [weak self] event in
                    // On-demand keyboard interactivity: a click hands the
                    // surface the keyboard until a window takes it back.
                    if onDemandKeys { self?._layerKeyboardSurface = surfaceId }
                    wl.sendPointerEvent(surfaceId: surfaceId, phase: 2,
                                        x: event.localPosition.dx, y: event.localPosition.dy,
                                        buttons: Int64(event.buttons))
                },
                onPointerMove: { event in
                    wl.sendPointerEvent(surfaceId: surfaceId, phase: 3,
                                        x: event.localPosition.dx, y: event.localPosition.dy,
                                        buttons: Int64(event.buttons))
                },
                onPointerUp: { event in
                    wl.sendPointerEvent(surfaceId: surfaceId, phase: 1,
                                        x: event.localPosition.dx, y: event.localPosition.dy,
                                        buttons: 0)
                },
                onPointerHover: { event in
                    wl.sendPointerEvent(surfaceId: surfaceId, phase: 6,
                                        x: event.localPosition.dx, y: event.localPosition.dy,
                                        buttons: 0)
                },
                onPointerSignal: { event in
                    if let scroll = event as? PointerScrollEvent {
                        wl.sendScrollEvent(surfaceId: surfaceId,
                                           x: scroll.localPosition.dx, y: scroll.localPosition.dy,
                                           scrollDeltaX: scroll.scrollDelta.dx,
                                           scrollDeltaY: scroll.scrollDelta.dy)
                    }
                },
                behavior: .opaque,
                child: texture)
            out.append(Positioned(
                key: ValueKey("layer-\(surfaceId)"),
                left: entry.absX, top: entry.absY,
                width: entry.width, height: entry.height,
                child: child))
            if let popups = stashedLayerPopups[surfaceId] {
                out.append(contentsOf: popups)
            }
        }
        return out
    }

    /// Wire the compositor's layer-shell, alpha, zone and state hooks. Called
    /// once, from the Wayland callback block in initState.
    func _wireWaylandProtocols(_ wayland: WaylandIntegration) {
        // The frame the shell draws: a title bar above the content.
        wayland.setFrameExtents(top: Int(DesktopTheme.kTitleBarHeight), bottom: 0, left: 0, right: 0)

        // What every configure carries and what taskbars see.
        wayland.stateProvider = { [weak self] windowId in
            guard let self = self,
                  let win = self.windowManager.windows.first(where: { $0.id == windowId })
            else { return UInt32(WAYLAND_TOPLEVEL_ACTIVATED) | UInt32(WAYLAND_TOPLEVEL_MAXIMIZED) }
            var bits: UInt32 = 0
            if win.isMaximized { bits |= UInt32(WAYLAND_TOPLEVEL_MAXIMIZED) }
            if win.isFullscreen { bits |= UInt32(WAYLAND_TOPLEVEL_FULLSCREEN) }
            if win.isMinimized || self._minimizingWindows.contains(windowId) {
                bits |= UInt32(WAYLAND_TOPLEVEL_MINIMIZED)
            }
            if self.windowManager.focusedWindowId == windowId && !win.isMinimized {
                bits |= UInt32(WAYLAND_TOPLEVEL_ACTIVATED)
            }
            return bits
        }

        // A client's own set_maximized/set_minimized, a taskbar's requests,
        // an activation: the shell's policy, then the state pushed back.
        wayland.onToplevelRequest = { [weak self] windowId, request in
            guard let self = self,
                  let win = self.windowManager.windows.first(where: { $0.id == windowId })
            else { return }
            switch Int(request) {
            case Int(WAYLAND_TOPLEVEL_REQUEST_ACTIVATE):
                self.setState {
                    if win.isMinimized { self.windowManager.restoreWindow(windowId) }
                    self.windowManager.bringToFront(windowId)
                    self._layerKeyboardSurface = nil
                }
            case Int(WAYLAND_TOPLEVEL_REQUEST_MAXIMIZE):
                guard !win.isMaximized, !win.isFullscreen else { break }
                self.setState {
                    self.windowManager.maximizeWindow(windowId, screenWidth: self.screenWidth,
                                                      screenHeight: self.screenHeight)
                    self._windowChildCache.removeValue(forKey: windowId)
                }
                self._configureFromRect(windowId)
            case Int(WAYLAND_TOPLEVEL_REQUEST_UNMAXIMIZE):
                guard win.isMaximized, !win.isFullscreen else { break }
                self.setState {
                    self.windowManager.maximizeWindow(windowId, screenWidth: self.screenWidth,
                                                      screenHeight: self.screenHeight)
                    self._windowChildCache.removeValue(forKey: windowId)
                }
                self._configureFromRect(windowId)
            case Int(WAYLAND_TOPLEVEL_REQUEST_MINIMIZE):
                guard !win.isMinimized else { break }
                self.requestWindowMinimize(windowId)
            case Int(WAYLAND_TOPLEVEL_REQUEST_UNMINIMIZE):
                guard win.isMinimized || self._minimizingWindows.contains(windowId) else { break }
                self.setState {
                    self._minimizingWindows.remove(windowId)
                    self.windowManager.restoreWindow(windowId)
                }
            case Int(WAYLAND_TOPLEVEL_REQUEST_FULLSCREEN):
                wayland.onFullscreenRequest?(windowId)
            case Int(WAYLAND_TOPLEVEL_REQUEST_UNFULLSCREEN):
                wayland.onUnfullscreenRequest?(windowId)
            case Int(WAYLAND_TOPLEVEL_REQUEST_CLOSE):
                self.requestWindowClose(windowId)
            default:
                break
            }
            // Whatever the window's state is now, the client hears it —
            // even when nothing changed, a refusal is an answer.
            wayland.syncToplevelState(windowId: windowId)
        }

        wayland.onNewLayerSurface = { [weak self] surfaceId, textureId, info in
            guard let self = self else { return }
            self.setState {
                self.layerSurfaces[surfaceId] = LayerSurfaceEntry(
                    surfaceId: surfaceId, textureId: textureId, info: info)
                if info.keyboardInteractivity == 1 {
                    self._layerKeyboardSurface = surfaceId
                }
                self._applyLayerInsets()
            }
        }
        wayland.onLayerSurfaceChanged = { [weak self] surfaceId, info in
            guard let self = self, let entry = self.layerSurfaces[surfaceId] else { return }
            entry.info = info
            if info.keyboardInteractivity == 1 {
                self._layerKeyboardSurface = surfaceId
            } else if self._layerKeyboardSurface == surfaceId && info.keyboardInteractivity == 0 {
                self._layerKeyboardSurface = nil
            }
            self._applyLayerInsets()
            self._layerSurfacesDidChange()
        }
        wayland.onLayerSurfaceBufferResized = { [weak self] surfaceId, w, h in
            guard let self = self, let entry = self.layerSurfaces[surfaceId] else { return }
            entry.bufferWidth = Double(w)
            entry.bufferHeight = Double(h)
            self._layerSurfacesDidChange()
        }
        wayland.onLayerSurfaceDestroyed = { [weak self] surfaceId in
            guard let self = self else { return }
            self.setState {
                self.layerSurfaces.removeValue(forKey: surfaceId)
                if self._layerKeyboardSurface == surfaceId { self._layerKeyboardSurface = nil }
                self._applyLayerInsets()
            }
        }

        _wireWorkspaces(wayland)
        _wireBackgroundEffect(wayland)
        _wireVirtualInput(wayland)
        _wireDragAndDrop(wayland)
        _wireOutputConfig(wayland)

        // wp_alpha_modifier: whichever kind of surface it is.
        wayland.onSurfaceAlpha = { [weak self] surfaceId, alpha in
            guard let self = self else { return }
            if let entry = self.layerSurfaces[surfaceId] {
                entry.alpha = alpha
                self._layerSurfacesDidChange()
            } else if let id = wayland.windowId(forSurfaceId: surfaceId) {
                if self.popups[id] != nil {
                    self.popupAlpha[id] = alpha
                    self._popupsDidChange()
                } else if let win = self.windowManager.windows.first(where: { $0.id == id }) {
                    self.setState {
                        win.contentOpacity = alpha
                        self._windowChildCache.removeValue(forKey: id)
                    }
                }
            }
        }

        // xx-zones: put the window's frame at (x, y) of the work area. A
        // placed window is a free window (a maximized one leaves that
        // state); a fullscreen one cannot be moved and says so.
        wayland.onToplevelPositionRequest = { [weak self] windowId, _, x, y in
            guard let self = self,
                  let win = self.windowManager.windows.first(where: { $0.id == windowId })
            else { return }
            if win.isFullscreen {
                wayland.reportToplevelPositionFailed(windowId: windowId)
                return
            }
            let wa = self.windowManager.workArea(for: self._layerOutputRect(),
                                                 screenWidth: self.screenWidth,
                                                 screenHeight: self.screenHeight)
            self.setState {
                if win.isMaximized {
                    // Leave maximized at the size the window had before —
                    // the client asked for a position, not the screen.
                    let size = win.savedRect ?? Rect.fromLTWH(0, 0, DesktopTheme.kDefaultWindowWidth,
                                                                 DesktopTheme.kDefaultWindowHeight)
                    win.rect = Rect.fromLTWH(win.rect.left, win.rect.top, size.width, size.height)
                    win.isMaximized = false
                    win.savedRect = nil
                    self._windowChildCache.removeValue(forKey: windowId)
                }
                // Keep at least a grab of the title bar on screen.
                let minVisible = 80.0
                var nx = wa.left + Double(x)
                var ny = wa.top + Double(y)
                nx = min(max(nx, wa.left - win.rect.width + minVisible), wa.right - minVisible)
                ny = min(max(ny, wa.top), wa.bottom - DesktopTheme.kTitleBarHeight)
                self.windowManager.moveWindow(windowId, to: Offset(nx, ny))
            }
            // The size half may have changed with the un-maximize.
            self._configureFromRect(windowId)
            self._reportWindowPositions()
        }

        wayland.onSystemBell = { windowId in
            FileHandle.standardError.write(Data(
                "[shell] bell from \(windowId ?? "no window")\n".utf8))
        }

        wayland.onSessionLock = { [weak self] locked in
            guard let self = self else { return }
            self.setState {
                self._sessionLocked = locked
                if !locked { self._layerKeyboardSurface = nil }
                // The lock replaces every layer of the desktop: a fresh
                // element tree, and the window cache with it.
                self._windowChildCache.removeAll()
            }
        }

        // Screencopy's frame-pump rider is wired with the recorders' (see
        // pokePump in initState): the same closure, the same rules.
    }

    /// Reconfigure a Wayland window from its current rect (after a state
    /// change the shell made on a client's request).
    func _configureFromRect(_ windowId: String) {
        guard let win = windowManager.windows.first(where: { $0.id == windowId }),
              let wl = waylandIntegration,
              let surfId = wl.surfaceId(forWindowId: windowId) else { return }
        let contentW = win.rect.width
        let contentH = win.isFullscreen ? win.rect.height
                                        : win.rect.height - DesktopTheme.kTitleBarHeight
        if contentW > 0, contentH > 0 {
            wl.sendResizeForced(surfaceId: surfId, width: Int(contentW), height: Int(contentH))
        } else {
            wl.syncToplevelState(windowId: windowId)
        }
    }

    /// After a build: every Wayland window's state and frame position reach
    /// the compositor (foreign-toplevel handles, xx-zones), diff-guarded on
    /// the way so a steady desktop sends nothing.
    func _syncWaylandWindowState() {
        guard let wl = waylandIntegration else { return }
        wl.syncAllToplevelStates()
        _reportWindowPositions()
        wl.setWorkspaces(_workspaceEntries())
    }

    func _reportWindowPositions() {
        guard let wl = waylandIntegration else { return }
        let wa = windowManager.workArea(for: _layerOutputRect(),
                                        screenWidth: screenWidth, screenHeight: screenHeight)
        for win in windowManager.windows where win.appId.hasPrefix("wayland-") {
            wl.reportToplevelPosition(windowId: win.id,
                                      x: Int((win.rect.left - wa.left).rounded()),
                                      y: Int((win.rect.top - wa.top).rounded()))
        }
    }
}
