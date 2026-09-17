// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// The shell's side of the protocols that need something of the desktop
// itself rather than of a window: the spaces as workspaces
// (ext-workspace), frosted glass behind a client's content
// (ext-background-effect), input a client makes up (virtual pointer and
// keyboard, pointer warp), drag-and-drop across windows with its icon and
// a toplevel riding along (wl_data_device, xdg-toplevel-drag), and a
// display configuration applied from a client (wlr-output-management).

import Flutter
import FlutterSwiftBridge
import Foundation
import WaylandServerBridge
#if os(Linux)
import FlutterDRMBridge
#endif

extension _DesktopShellState {

    // MARK: - Workspaces

    /// The user spaces, named the way Mission Control labels them. Special
    /// spaces (a fullscreen app, the agent workspace) are the shell's own
    /// and stay out of the list.
    func _workspaceEntries() -> [WaylandWorkspaceEntry] {
        var entries: [WaylandWorkspaceEntry] = []
        var userNumber = 0
        for (index, space) in windowManager.spaces.enumerated() where space.isUser {
            userNumber += 1
            entries.append(WaylandWorkspaceEntry(
                id: UInt32(space.id), name: "Desktop \(userNumber)",
                active: index == windowManager.activeSpaceIndex))
        }
        return entries
    }

    func _wireWorkspaces(_ wayland: WaylandIntegration) {
        wayland.onWorkspaceRequest = { [weak self] id, request, _ in
            guard let self = self else { return }
            let wm = self.windowManager
            switch Int(request) {
            case Int(WAYLAND_WORKSPACE_REQUEST_ACTIVATE):
                if let index = wm.spaces.firstIndex(where: { $0.id == Int(id) }) {
                    self._switchToSpace(index)
                }
            case Int(WAYLAND_WORKSPACE_REQUEST_REMOVE):
                if let index = wm.spaces.firstIndex(where: { $0.id == Int(id) }) {
                    self.setState { wm.removeSpace(at: index) }
                }
            case Int(WAYLAND_WORKSPACE_REQUEST_CREATE):
                self.setState { _ = wm.addSpace() }
            default:
                break   // deactivate: one space is always showing
            }
        }
    }

    // MARK: - Background effect

    func _wireBackgroundEffect(_ wayland: WaylandIntegration) {
        wayland.onSurfaceBlur = { [weak self] surfaceId, flat in
            guard let self = self,
                  let id = wayland.windowId(forSurfaceId: surfaceId),
                  let win = self.windowManager.windows.first(where: { $0.id == id })
            else { return }
            let k = wayland.surfaceToLogical
            var rects: [Rect] = []
            var i = 0
            while i + 3 < flat.count {
                rects.append(Rect.fromLTWH(Double(flat[i]) * k, Double(flat[i + 1]) * k,
                                           Double(flat[i + 2]) * k, Double(flat[i + 3]) * k))
                i += 4
            }
            self.setState {
                win.blurRects = rects
                self._windowChildCache.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Virtual input

    /// Where a window's content starts: below the shell's title bar,
    /// unless fullscreen, when the content is the whole rect.
    func _contentOrigin(of win: WindowInfo) -> Offset {
        Offset(win.rect.left,
               win.rect.top + (win.isFullscreen ? 0 : DesktopTheme.kTitleBarHeight))
    }

    /// A window's content area on screen (the frame less the title bar).
    func _contentRect(of win: WindowInfo) -> Rect {
        let o = _contentOrigin(of: win)
        let h = win.rect.height - (win.isFullscreen ? 0 : DesktopTheme.kTitleBarHeight)
        return Rect.fromLTWH(o.dx, o.dy, win.rect.width, max(h, 1))
    }

    /// The engine reports a warp we asked for as an ordinary move to that
    /// point; the constraint code must not read it as the user's.
    func _isInjectEcho(_ p: Offset) -> Bool {
        guard let i = _injectedPointer else { return false }
        return abs(i.dx - p.dx) < 0.75 && abs(i.dy - p.dy) < 0.75
    }

    /// The pointer moved (root listener). Under a lock: the delta since the
    /// last position goes to the client as relative motion and the cursor
    /// is warped back to the anchor; the warp's own echo only resets the
    /// last position. Under a confinement: a cursor outside the content is
    /// put back on its nearest edge.
    func _constraintPointerMoved(_ p: Offset, echo: Bool) {
        if let lock = _pointerLock {
            if echo {
                _lockLast = p
                return
            }
            let dx = p.dx - _lockLast.dx, dy = p.dy - _lockLast.dy
            _lockLast = p
            if dx != 0 || dy != 0 {
                waylandIntegration?.sendRelativeMotion(surfaceId: lock.surfaceId, dx: dx, dy: dy)
            }
            if abs(p.dx - _lockAnchor.dx) >= 0.75 || abs(p.dy - _lockAnchor.dy) >= 0.75 {
                _inject(_lockAnchor, buttons: Int64(_lastButtons))
            }
            return
        }
        if let c = _pointerConfine, !echo,
           let win = windowManager.windows.first(where: { $0.id == c.windowId }) {
            let r = _contentRect(of: win)
            let cx = min(max(p.dx, r.left), r.right - 1)
            let cy = min(max(p.dy, r.top), r.bottom - 1)
            if cx != p.dx || cy != p.dy {
                _inject(Offset(cx, cy), buttons: Int64(_lastButtons))
            }
        }
    }

    private func _inject(_ logical: Offset, buttons: Int64, wheelDx: Double = 0, wheelDy: Double = 0) {
        guard let view = drmViewHandle else { return }
        let x = min(max(logical.dx, 0), max(screenWidth - 1, 0))
        let y = min(max(logical.dy, 0), max(screenHeight - 1, 0))
        _injectedPointer = Offset(x, y)
        let s = currentShellDpi
        fl_drm_view_inject_pointer_abs(view, x * s, y * s, buttons, wheelDx, wheelDy)
    }

    func _wireVirtualInput(_ wayland: WaylandIntegration) {
        // A virtual pointer joins the real one's stream through the
        // engine, so chrome, chords and clients see it as the mouse.
        wayland.onVirtualPointer = { [weak self] outputIndex, hasAbs, ax, ay, dx, dy,
                                                 buttons, wheelDx, wheelDy in
            guard let self = self else { return }
            var p: Offset
            if hasAbs {
                if let dl = displayLayout, dl.outputs.indices.contains(outputIndex) {
                    let o = dl.outputs[outputIndex]
                    p = Offset(o.originX + ax * o.logicalWidth, o.originY + ay * o.logicalHeight)
                } else {
                    p = Offset(ax * self.screenWidth, ay * self.screenHeight)
                }
            } else {
                let base = self._injectedPointer ?? self._lastPointer
                p = Offset(base.dx + dx, base.dy + dy)
            }
            self._inject(p, buttons: buttons, wheelDx: wheelDx, wheelDy: wheelDy)
        }

        // A virtual key is routed exactly like a physical one, decoded
        // already: the evdev code becomes the HID usage the router keys
        // its chords on, the keysym and text are what the client meant.
        wayland.onVirtualKey = { [weak self] evdev, keysym, text, pressed in
            guard let self = self else { return }
            let keyData = KeyData(
                timeStamp: ProcessInfo.processInfo.systemUptime,
                type: pressed ? .down : .up,
                physical: Int64(bitPattern: HidEvdev.hid(fromEvdev: evdev)),
                logical: Int64(keysym),
                character: (pressed && !text.isEmpty) ? text : nil,
                synthesized: false)
            self._noteUserActivity()
            _ = self._keyRouter?(keyData)
        }

        // zwp_pointer_constraints. A lock: the cursor disappears and is
        // held at the window's content centre — the engine clamps the
        // pointer to the screen, so the centre gives the mouse the most
        // room in every direction — and every move becomes relative
        // motion for the client (_constraintPointerMoved). When it ends
        // the cursor comes back where the client asked, or where it was.
        // A confinement just keeps the cursor inside the content.
        wayland.onPointerConstraint = { [weak self] windowId, surfaceId, lock, active, hint in
            guard let self = self else { return }
            if !lock {
                if active {
                    self._pointerConfine = (surfaceId, windowId)
                } else if self._pointerConfine?.surfaceId == surfaceId {
                    self._pointerConfine = nil
                }
                return
            }
            if active {
                guard let win = self.windowManager.windows.first(where: { $0.id == windowId }) else { return }
                self._pointerLock = (surfaceId, windowId, self._lastPointer)
                DesktopCursor.hide()
                let r = self._contentRect(of: win)
                let center = Offset(r.left + r.width / 2, r.top + r.height / 2)
                self._lockAnchor = center
                self._lockLast = self._lastPointer
                self._inject(center, buttons: Int64(self._lastButtons))
            } else if let lock = self._pointerLock, lock.surfaceId == surfaceId {
                self._pointerLock = nil
                DesktopCursor.show()
                var target = lock.restore
                if let h = hint, let win = self.windowManager.windows.first(where: { $0.id == lock.windowId }) {
                    let o = self._contentOrigin(of: win)
                    target = Offset(o.dx + h.dx, o.dy + h.dy)
                }
                self._inject(target, buttons: Int64(self._lastButtons))
            }
        }

        // A warp moves the real cursor, for a surface the pointer is over.
        wayland.onPointerWarp = { [weak self] surfaceId, x, y in
            guard let self = self else { return }
            let here = self._lastPointer
            var target: Offset? = nil
            if let entry = self.layerSurfaces[surfaceId] {
                if here.dx >= entry.absX, here.dx < entry.absX + entry.width,
                   here.dy >= entry.absY, here.dy < entry.absY + entry.height {
                    target = Offset(entry.absX + x, entry.absY + y)
                }
            } else if let id = wayland.windowId(forSurfaceId: surfaceId),
                      let win = self.windowManager.windows.first(where: { $0.id == id }) {
                let r = win.rect
                if here.dx >= r.left, here.dx < r.right, here.dy >= r.top, here.dy < r.bottom {
                    let o = self._contentOrigin(of: win)
                    target = Offset(o.dx + x, o.dy + y)
                }
            }
            guard let t = target else { return }
            self._inject(t, buttons: Int64(self._lastButtons))
        }
    }

    // MARK: - Drag-and-drop

    /// The client surface under `p`, and `p` in its content coordinates:
    /// bars above the windows first, then the windows by stacking order,
    /// then the bars below. A shell-owned window (or a title bar) under
    /// the pointer is no target at all.
    func _dragTarget(at p: Offset) -> (surfaceId: UInt32, local: Offset)? {
        guard let wl = waylandIntegration else { return nil }
        func layerHit(_ layers: Set<Int>) -> (surfaceId: UInt32, local: Offset)? {
            for (sid, e) in layerSurfaces where layers.contains(Int(e.info.layer)) && e.mapped {
                if p.dx >= e.absX, p.dx < e.absX + e.width, p.dy >= e.absY, p.dy < e.absY + e.height {
                    return (sid, Offset(p.dx - e.absX, p.dy - e.absY))
                }
            }
            return nil
        }
        if let hit = layerHit([2, 3]) { return hit }
        for win in windowManager.visibleWindows.reversed() {
            let r = win.rect
            guard p.dx >= r.left, p.dx < r.right, p.dy >= r.top, p.dy < r.bottom else { continue }
            guard let sid = wl.surfaceId(forWindowId: win.id) else { return nil }
            let o = _contentOrigin(of: win)
            let local = Offset(p.dx - o.dx, p.dy - o.dy)
            if local.dy < 0 { return nil }
            return (sid, local)
        }
        return layerHit([0, 1])
    }

    /// The pointer moved while a drag is on: tell the compositor which
    /// surface it is over (it turns that into data_device enter/motion/
    /// leave), move the icon, and drag the attached toplevel along.
    func _dragPointerMoved(_ p: Offset) {
        guard let wl = waylandIntegration, wl.dragActive else { return }
        if let t = _dragTarget(at: p) {
            wl.sendDragPointer(surfaceId: t.surfaceId, phase: 3, x: t.local.dx, y: t.local.dy)
        } else {
            wl.sendDragPointer(surfaceId: 0, phase: 3, x: 0, y: 0)
        }
        if _dragIcon != nil { _popupsDidChange() }
        if let td = _toplevelDrag,
           let win = windowManager.windows.first(where: { $0.id == td.windowId }) {
            let left = p.dx - Double(td.xOff)
            let top = p.dy - Double(td.yOff)
                - (win.isFullscreen ? 0 : DesktopTheme.kTitleBarHeight)
            setState {
                win.rect = Rect.fromLTWH(left, top, win.rect.width, win.rect.height)
                self._windowChildCache.removeValue(forKey: win.id)
            }
        }
    }

    /// The button came up: the drop, on the surface under the pointer, or
    /// nowhere.
    func _dragPointerReleased(_ p: Offset) {
        guard let wl = waylandIntegration, wl.dragActive else { return }
        if let t = _dragTarget(at: p) {
            wl.sendDragPointer(surfaceId: t.surfaceId, phase: 1, x: t.local.dx, y: t.local.dy)
        } else {
            wl.pointerGlobalRelease()
        }
    }

    func _wireDragAndDrop(_ wayland: WaylandIntegration) {
        wayland.onDragStateChanged = { [weak self] active in
            guard let self = self else { return }
            if active {
                // The drag begins where the pointer is: enter that surface.
                self._dragPointerMoved(self._lastPointer)
            } else {
                self._toplevelDrag = nil
                DesktopCursor.setShape(.default)
            }
        }
        wayland.onDragIcon = { [weak self] iconId, textureId in
            guard let self = self else { return }
            if let id = iconId {
                self._dragIcon = (id: id, textureId: textureId, width: 0, height: 0)
            } else {
                self._dragIcon = nil
            }
            self._popupsDidChange()
        }
        wayland.onToplevelDrag = { [weak self] windowId, xOff, yOff, active in
            guard let self = self else { return }
            if active {
                self._toplevelDrag = (windowId: windowId, xOff: xOff, yOff: yOff)
                self.setState { self.windowManager.bringToFront(windowId) }
                self._dragPointerMoved(self._lastPointer)
            } else if self._toplevelDrag?.windowId == windowId {
                self._toplevelDrag = nil
            }
        }
    }

    // MARK: - Output configuration

    /// wlr-randr's `--scale` on the host output: the same path as the DPI
    /// slider, which re-renders the shell and every child at the new
    /// density. Anything else in a configuration was refused in C.
    func _wireOutputConfig(_ wayland: WaylandIntegration) {
        wayland.onOutputConfig = { configId, hostScale in
            guard let apply = linuxProcessAppManager?.onDpiChangeRequested else {
                wayland.outputConfigResult(configId: configId, ok: false)
                return
            }
            apply(hostScale)
            wayland.outputConfigResult(configId: configId, ok: true)
        }
    }
}
