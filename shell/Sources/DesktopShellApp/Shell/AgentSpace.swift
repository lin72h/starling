// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - AI Space (Murmuration)
//
// The agent workbench: sessions on the left, the conversation with the
// agent in the middle, and the app the agent is driving as the dominant
// stage on the right. The Claude Code TUI is chat-shaped, so the terminal
// IS the conversation column — typing there goes straight to its PTY.
// Agent-owned windows have no desktop presence; this is the only place
// they are drawn. Stored state lives in _DesktopShellState (extensions
// cannot add stored properties); this file is UI + launch/demo plumbing.

private enum AS {
    static let railW: Double = 280       // sessions rail
    static let chatW: Double = 688       // default; live width is _agentChatW
    static let chatMin: Double = 420
    static let chatMax: Double = 1100
    static let dividerW: Double = 8
    static let pad: Double = 14
    static let headerH: Double = 44      // per-column header strip
    static let rowH: Double = 58         // session row
    static let paneLabelH: Double = 22
}

extension _DesktopShellState {

    // MARK: Workbench

    func _buildAgentSpace(_ context: any BuildContext) -> Widget {
        _applyAgentWindowGeometry()
        #if os(Linux)
        _updateAgentFrameThrottles()
        #endif
        var layers: [Widget] = []


        // Dim scrim over the wallpaper so the space reads as its own mode.
        layers.append(Positioned(fill: (), child: ColoredBox(
            color: Color(0x8A0E0F15), child: SizedBox(expand: ()))))

        let agents = windowManager.agents
        let top = DesktopTheme.kStatusBarHeight

        if agents.isEmpty {
            layers.append(Positioned(
                left: 0, top: screenHeight * 0.38, width: screenWidth, height: 30,
                child: Center(child: Text(
                    "Agents run here — a conversation beside the apps it drives.",
                    style: TextStyle(color: shellTheme.overlayTextDim,
                                     fontSize: 15, fontWeight: .w400)))))
            layers.append(Positioned(
                left: (screenWidth - 160) / 2, top: screenHeight * 0.38 + 48,
                width: 160, height: 40,
                child: _agentButton("New Agent") { [self] in _newAgent() }))
            return Stack(children: layers)
        }

        let selected = agents.first(where: { $0.id == _agentFeaturedId }) ?? agents[0]

        // ── Sessions rail ────────────────────────────────────────────
        layers.append(Positioned(
            left: 0, top: top, width: AS.railW, height: screenHeight - top,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xE60F1118),
                    border: Border(right: BorderSide(color: Color(0x26FFFFFF), width: 1))),
                child: SizedBox(expand: ()))))
        layers.append(Positioned(
            left: AS.pad, top: top + 13,
            child: IgnorePointer(child: Text("AI Space", style: TextStyle(
                color: shellTheme.overlayText, fontSize: 15, fontWeight: .w700)))))
        layers.append(Positioned(
            left: AS.railW - AS.pad - 78, top: top + 9, width: 78, height: 26,
            child: _agentButton("+ New", fontSize: 11) { [self] in _newAgent() }))

        var rowY = top + 50
        for agent in agents {
            let isSel = agent.id == selected.id
            let owned = windowManager.windows(ownedBy: agent.id)
            let working = _agentIsWorking(agent, owned: owned)
            let apps = owned.filter { $0.id != agent.terminalWindowId }
            let contextLine = apps.last?.title
                ?? (agent.terminalWindowId != nil ? "terminal" : "connecting…")
            let agentId = agent.id
            let terminalId = agent.terminalWindowId
            let row: [Widget] = [
                Positioned(fill: (), child: GestureDetector(
                    onTap: { [self] in
                        setState {
                            _agentFeaturedId = agentId
                            if let tid = terminalId {
                                windowManager.focusedWindowId = tid
                            }
                        }
                    },
                    behavior: .opaque,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: isSel ? Color(0x26FFFFFF) : Color(0x0DFFFFFF),
                            border: Border.all(
                                color: isSel ? shellTheme.accent : Color(0x1FFFFFFF),
                                width: 1),
                            borderRadius: BorderRadius.all(Radius(circular: 8))),
                        child: SizedBox(expand: ())))),
                Positioned(left: 11, top: 13, width: 8, height: 8,
                    child: IgnorePointer(child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: working ? Color(0xFF7ED97E) : Color(0x55FFFFFF),
                            borderRadius: BorderRadius.all(Radius(circular: 4)))))),
                Positioned(left: 28, top: 7,
                    child: IgnorePointer(child: Text(agent.name, style: TextStyle(
                        color: shellTheme.overlayText, fontSize: 12, fontWeight: .w600)))),
                Positioned(left: 28, top: 29,
                    child: IgnorePointer(child: Text(
                        String(contextLine.prefix(32)),
                        style: TextStyle(color: shellTheme.overlayTextDim,
                                         fontSize: 10.5, fontWeight: .w400)))),
            ]
            layers.append(Positioned(
                key: ValueKey("sess-\(agent.id)"),
                left: 10, top: rowY, width: AS.railW - 20, height: AS.rowH,
                child: Stack(children: row)))
            rowY += AS.rowH + 8
        }

        // ── Conversation column: the terminal IS the chat ─────────────
        let chatX = AS.railW
        let chatW = _agentChatW
        layers.append(Positioned(
            left: chatX, top: top, width: chatW, height: screenHeight - top,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xD214151C),
                    border: Border(right: BorderSide(color: Color(0x26FFFFFF), width: 1))),
                child: SizedBox(expand: ()))))
        let ownedSel = windowManager.windows(ownedBy: selected.id)
        let terminal = selected.terminalWindowId
            .flatMap { tid in ownedSel.first(where: { $0.id == tid }) }
        layers.append(Positioned(
            left: chatX + AS.pad, top: top + 15,
            child: IgnorePointer(child: Text(selected.name, style: TextStyle(
                color: shellTheme.overlayText, fontSize: 13, fontWeight: .w600)))))
        if let term = terminal {
            let cw = term.rect.width
            let ch = term.rect.height - DesktopTheme.kTitleBarHeight
            let availH = screenHeight - top - AS.headerH - AS.pad
            let scale = min(1.0, (chatW - 2 * AS.pad) / cw, availH / ch)
            layers.append(Positioned(
                key: ValueKey("chat-\(term.id)"),
                left: chatX + AS.pad, top: top + AS.headerH,
                width: cw * scale, height: ch * scale,
                child: _agentPane(term, scale: scale,
                                  focused: windowManager.focusedWindowId == term.id)))
        } else {
            layers.append(Positioned(
                left: chatX + AS.pad, top: top + AS.headerH + 8, width: chatW - 2 * AS.pad, height: 40,
                child: IgnorePointer(child: Text(
                    selected.isExternal
                        ? "External agent — drives its apps over the broker socket."
                        : "Starting terminal…",
                    style: TextStyle(color: shellTheme.overlayTextDim,
                                     fontSize: 12, fontWeight: .w400)))))
        }

        // ── Stage: the app the agent is driving ───────────────────────
        let stageX = AS.railW + chatW
        let stageW = screenWidth - stageX
        let apps = ownedSel.filter { $0.id != selected.terminalWindowId }
        if apps.isEmpty {
            layers.append(Positioned(
                left: stageX, top: screenHeight * 0.42, width: stageW, height: 24,
                child: IgnorePointer(child: Center(child: Text(
                    "No app windows yet — they appear here when the agent opens one.",
                    style: TextStyle(color: shellTheme.overlayTextDim,
                                     fontSize: 13, fontWeight: .w400))))))
        } else {
            let explicit = _agentActiveTab[selected.id]
            let active = apps.first(where: { $0.id == explicit }) ?? apps.last!
            if explicit != nil && !apps.contains(where: { $0.id == explicit }) {
                _agentActiveTab.removeValue(forKey: selected.id)
            }

            // Tab strip; duplicate titles get an index suffix.
            var titleCounts: [String: Int] = [:]
            for w in apps { titleCounts[w.title, default: 0] += 1 }
            var titleSeen: [String: Int] = [:]
            let tabsRight = stageW - 2 * AS.pad - 150   // room for the demo button
            let tabW = min(190.0, max(96.0,
                (tabsRight - Double(apps.count - 1) * 6) / Double(apps.count)))
            var tx = stageX + AS.pad
            for win in apps {
                titleSeen[win.title, default: 0] += 1
                var label = win.title
                if titleCounts[win.title]! > 1 { label += " \(titleSeen[win.title]!)" }
                let isActive = win.id == active.id
                let winId = win.id
                var tabLayers: [Widget] = [
                    Positioned(fill: (), child: GestureDetector(
                        onTap: { [self] in
                            setState { _agentActiveTab[selected.id] = winId }
                        },
                        behavior: .opaque,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: isActive ? Color(0x38FFFFFF) : Color(0x14FFFFFF),
                                border: Border.all(
                                    color: isActive ? shellTheme.accent : Color(0x30FFFFFF),
                                    width: 1),
                                borderRadius: BorderRadius.all(Radius(circular: 6))),
                            child: Center(child: Text(label, style: TextStyle(
                                color: isActive ? shellTheme.overlayText : shellTheme.overlayTextDim,
                                fontSize: 11,
                                fontWeight: isActive ? .w600 : .w400)))))),
                ]
                if !isActive, _agentWindowActive(win) {
                    tabLayers.append(Positioned(
                        left: tabW - 12, top: 5, width: 6, height: 6,
                        child: IgnorePointer(child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Color(0xFF7ED97E),
                                borderRadius: BorderRadius.all(Radius(circular: 3)))))))
                }
                layers.append(Positioned(
                    left: tx, top: top + 11, width: tabW, height: 26,
                    child: Stack(children: tabLayers)))
                tx += tabW + 6
            }

            if apps.contains(where: { $0.appId.contains(":files") }) {
                layers.append(Positioned(
                    left: stageX + stageW - AS.pad - 132, top: top + 11,
                    width: 132, height: 26,
                    child: _agentButton("Run Files task", fontSize: 12) { [self] in
                        _runAgentDemo(selected)
                    }))
            }
            if let status = _agentDemoStatus {
                layers.append(Positioned(
                    left: stageX + AS.pad, top: screenHeight - 30,
                    child: IgnorePointer(child: Text("agent: \(status)", style: TextStyle(
                        color: shellTheme.accent, fontSize: 12, fontWeight: .w500)))))
            }

            let paneTop = top + AS.headerH
            let cw = active.rect.width
            let ch = active.rect.height - DesktopTheme.kTitleBarHeight
            let scale = min(1.0, (stageW - 2 * AS.pad) / cw,
                            (screenHeight - paneTop - AS.pad - AS.paneLabelH) / ch)
            let w = cw * scale, h = ch * scale
            let controlled = _humanControlledWindows.contains(active.id)
            layers.append(Positioned(
                key: ValueKey("stage-\(active.id)"),
                left: stageX + AS.pad, top: paneTop, width: w, height: h,
                child: _agentPane(active, scale: scale,
                                  focused: windowManager.focusedWindowId == active.id,
                                  controlled: controlled,
                                  takeoverTarget: true)))
            let label = controlled
                ? "\(active.title) — HUMAN HAS THE CONTROLS · Esc hands back"
                : "\(active.title) — agent-owned"
            layers.append(Positioned(
                left: stageX + AS.pad, top: paneTop + h + 2,
                width: w, height: AS.paneLabelH,
                child: IgnorePointer(child: Text(label, style: TextStyle(
                    color: controlled ? Color(0xFFFF9E80) : shellTheme.overlayTextDim,
                    fontSize: 11, fontWeight: controlled ? .w600 : .w400)))))
        }

        // ── Divider: drag to rebalance conversation vs stage ──────────
        layers.append(Positioned(
            left: stageX - AS.dividerW / 2, top: top,
            width: AS.dividerW, height: screenHeight - top,
            child: Listener(
                onPointerDown: { [self] _ in
                    setState { _agentDividerDragging = true }
                },
                onPointerMove: { [self] event in
                    guard _agentDividerDragging else { return }
                    let w = min(AS.chatMax, max(AS.chatMin, event.position.dx - AS.railW))
                    if abs(w - _agentChatW) >= 1 { setState { _agentChatW = w } }
                },
                onPointerUp: { [self] _ in
                    guard _agentDividerDragging else { return }
                    // Re-configure the clients once, at the drop.
                    setState { _agentDividerDragging = false }
                    _applyAgentWindowGeometry()
                },
                onPointerHover: { _ in DesktopCursor.setShape(.resizeEW) },
                behavior: .opaque,
                child: ColoredBox(
                    color: _agentDividerDragging ? shellTheme.accent : Color(0x00000000),
                    child: SizedBox(expand: ())))))

        return Stack(children: layers)
    }

    /// Content size of the workbench stage — agent app windows are
    /// configured to exactly this, so they fill the stage at scale 1.0
    /// rather than being letterboxed at the desktop's aspect ratio.
    func _agentStageContentSize() -> Size {
        let top = DesktopTheme.kStatusBarHeight
        let stageW = screenWidth - AS.railW - _agentChatW - 2 * AS.pad
        let stageH = screenHeight - top - AS.headerH - AS.pad - AS.paneLabelH
        return Size(max(320, stageW), max(240, stageH))
    }

    /// Content size of the conversation column — an agent's terminal is
    /// configured to this, so Claude Code reflows to the available rows
    /// instead of being scaled down as a texture.
    func _agentChatContentSize() -> Size {
        let top = DesktopTheme.kStatusBarHeight
        let w = _agentChatW - 2 * AS.pad
        let h = screenHeight - top - AS.headerH - AS.pad
        return Size(max(320, w), max(240, h))
    }

    /// Keep every agent window sized to the pane that shows it: the
    /// terminal fills the conversation column, app windows fill the stage.
    /// Diffed against the last applied size, so calling this per build is
    /// cheap, and re-applied when the geometry changes (screen size, DPI).
    /// The window rect is authoritative — the client follows via the same
    /// onContentResize path the desktop's resize handles use.
    func _applyAgentWindowGeometry() {
        // While the divider is in flight the panes scale; clients reflow
        // once on the drop rather than on every frame of the drag.
        guard !_agentDividerDragging else { return }
        let stage = _agentStageContentSize()
        let chat = _agentChatContentSize()
        for agent in windowManager.agents {
            for win in windowManager.windows(ownedBy: agent.id) {
                let target = win.id == agent.terminalWindowId ? chat : stage
                let applied = _agentSizeApplied[win.id]
                if let a = applied, abs(a.width - target.width) < 1,
                   abs(a.height - target.height) < 1 { continue }
                _agentSizeApplied[win.id] = target
                win.rect = Rect.fromLTWH(0, 0, target.width,
                                         target.height + DesktopTheme.kTitleBarHeight)
                win.onContentResize?(target.width, target.height)
            }
        }
        // Drop entries for windows that went away.
        let live = Set(windowManager.windows.compactMap {
            $0.ownerAgentId != nil ? $0.id : nil })
        _agentSizeApplied = _agentSizeApplied.filter { live.contains($0.key) }
    }

    /// working/idle, derived from broker op recency and owned-window frame
    /// recency (a streaming Claude Code repaints continuously; an agent
    /// awaiting input goes quiet).
    private func _agentIsWorking(_ agent: AgentInfo, owned: [WindowInfo]) -> Bool {
        #if os(Linux)
        guard let broker = _agentBroker else { return false }
        let now = broker.now
        if let op = broker.agentLastOpMs[agent.id], now - op < 2500 { return true }
        for w in owned {
            if let tex = w.textureId,
               let f = broker.lastFrame(forTexture: Int64(tex)),
               now - f < 1500 {
                return true
            }
        }
        #endif
        return false
    }

    #if os(Linux)
    /// Frame policy (design §4): tile-only Wayland agent windows idle at
    /// ~5fps; full rate while the human has the controls or the window is
    /// the SELECTED agent's active tab (it is large on the stage). Diffed
    /// against the last applied interval, so calling per build is cheap.
    /// DMA-BUF children self-pace and are unaffected.
    func _updateAgentFrameThrottles() {
        guard let wayland = waylandIntegration else { return }
        let agents = windowManager.agents
        guard !agents.isEmpty else { return }
        let selected = agents.first(where: { $0.id == _agentFeaturedId }) ?? agents[0]
        for win in windowManager.windows {
            guard let ownerId = win.ownerAgentId,
                  win.appId.hasPrefix("wayland-"),
                  let surfId = wayland.surfaceId(forWindowId: win.id) else { continue }
            let agent = agents.first(where: { $0.id == ownerId })
            let apps = windowManager.windows(ownedBy: ownerId)
                .filter { $0.id != agent?.terminalWindowId }
            let activeTab = apps.first(where: { $0.id == _agentActiveTab[ownerId] }) ?? apps.last
            let fullRate = _humanControlledWindows.contains(win.id)
                || (selected.id == ownerId && activeTab?.id == win.id)
            let interval: UInt32 = fullRate ? 0 : 200
            if _agentThrottleApplied[win.id] != interval {
                _agentThrottleApplied[win.id] = interval
                wayland.setSurfaceThrottle(surfaceId: surfId, intervalMs: interval)
            }
        }
    }
    #endif

    /// Frame-recency for one window (the tab activity dot).
    private func _agentWindowActive(_ win: WindowInfo) -> Bool {
        #if os(Linux)
        guard let broker = _agentBroker, let tex = win.textureId,
              let f = broker.lastFrame(forTexture: Int64(tex)) else { return false }
        return broker.now - f < 1500
        #else
        return false
        #endif
    }

    /// A live window pane: the window's texture scaled by `scale`, with
    /// pointer events mapped back to content-local coordinates and forwarded
    /// over the child's socket. Clicking focuses the window so keys route to
    /// it (that is how the human types to Claude Code in the tile).
    /// `takeoverTarget` panes arm the P2 take-over at pointer-down: the
    /// human's input routes to the window while the agent's broker
    /// injections are refused, until Esc hands the window back.
    private func _agentPane(_ win: WindowInfo, scale: Double, focused: Bool,
                            controlled: Bool = false,
                            takeoverTarget: Bool = false) -> Widget {
        var content: Widget
        if let texId = win.textureId {
            content = TextureWidget(textureId: texId, filterQuality: .low)
            if win.flipTextureY {
                content = Transform(
                    transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
                    alignment: Alignment.center,
                    child: content)
            }
        } else {
            content = ColoredBox(color: Color(0xFF1A1A20), child: SizedBox(expand: ()))
        }
        let winId = win.id
        let forwarded: Widget = Listener(
            onPointerDown: { [self] event in
                // Take-over arms at pointer-down (never mid-gesture).
                if takeoverTarget && !_humanControlledWindows.contains(winId)
                    || windowManager.focusedWindowId != winId {
                    setState {
                        if takeoverTarget { _humanControlledWindows.insert(winId) }
                        windowManager.focusedWindowId = winId
                    }
                }
                win.onPointerEvent?(2, event.localPosition.dx / scale,
                                    event.localPosition.dy / scale, Int64(event.buttons))
            },
            onPointerMove: { event in
                win.onPointerEvent?(3, event.localPosition.dx / scale,
                                    event.localPosition.dy / scale, Int64(event.buttons))
            },
            onPointerUp: { event in
                win.onPointerEvent?(1, event.localPosition.dx / scale,
                                    event.localPosition.dy / scale, 0)
            },
            onPointerHover: { event in
                DesktopCursor.setShape(.default)
                win.onPointerEvent?(6, event.localPosition.dx / scale,
                                    event.localPosition.dy / scale, 0)
            },
            onPointerSignal: { event in
                if let scroll = event as? PointerScrollEvent {
                    win.onScrollEvent?(scroll.localPosition.dx / scale,
                                       scroll.localPosition.dy / scale,
                                       scroll.scrollDelta.dx, scroll.scrollDelta.dy)
                }
            },
            behavior: .opaque,
            child: content)
        let borderColor = controlled ? Color(0xFFFF9E80)
            : (focused ? shellTheme.accent : Color(0x40FFFFFF))
        return DecoratedBox(
            decoration: BoxDecoration(
                border: Border.all(
                    color: borderColor,
                    width: controlled || focused ? 2 : 1),
                borderRadius: BorderRadius.all(Radius(circular: 6))),
            child: ClipRRect(
                borderRadius: BorderRadius.all(Radius(circular: 6)),
                child: forwarded))
    }

    private func _agentButton(_ label: String, fontSize: Double = 13,
                              onTap: @escaping () -> Void) -> Widget {
        return GestureDetector(
            onTap: onTap,
            behavior: .opaque,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0x2EFFFFFF),
                    border: Border.all(color: Color(0x50FFFFFF), width: 1),
                    borderRadius: BorderRadius.all(Radius(circular: 8))),
                child: Center(child: Text(label, style: TextStyle(
                    color: shellTheme.overlayText, fontSize: fontSize, fontWeight: .w500)))))
    }

    // MARK: Agent lifecycle (P0: hardcoded fleet of TerminalApp + Files)

    /// Register a new agent and launch its windows: a TerminalApp (which
    /// enters the devbox via $STARLING_DEV_SHELL — Claude Code's home) and
    /// one Files window for the scripted P0 task. Both are tagged with the
    /// agent's id at creation and never appear on any desktop.
    /// Make the desktop-driving skill discoverable by the agent that is about
    /// to run in this session — otherwise it has a broker, a CLI and no idea
    /// either exists.
    ///
    /// Claude Code finds skills under `~/.claude/skills`, and that directory
    /// is the user's, not ours. So: link rather than copy (a package upgrade
    /// then updates the skill too), and never replace something we did not put
    /// there. The link is refreshed when it points into a shipped tree,
    /// because that is how an install that moves the skill keeps resolving.
    func _linkAgentSkill() {
        #if os(Linux)
        let fm = FileManager.default
        var sources: [String] = []
        if let shipped = Self.dataFilePath("skills/starling-desktop") {
            sources.append(shipped)
        }
        // Dev tree: the skill sits beside the CLI in build/, not under sdk/,
        // so dataFilePath's own source fallback does not find it.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Shell/
            .deletingLastPathComponent()   // DesktopShellApp/
            .deletingLastPathComponent()   // Sources/
            .deletingLastPathComponent()   // shell/
            .deletingLastPathComponent()   // repo root
        sources.append(repoRoot.appendingPathComponent("build/skills/starling-desktop").path)
        guard let source = sources.first(where: { fm.fileExists(atPath: $0) }) else { return }

        let skillsDir = LoginUser.home + "/.claude/skills"
        let link = skillsDir + "/starling-desktop"

        var st = stat()
        if lstat(link, &st) == 0 {
            let existing = try? fm.destinationOfSymbolicLink(atPath: link)
            // Ours to refresh only if it is a symlink into a skills tree; a
            // real directory, or a link somewhere else, is the user's.
            guard (st.st_mode & S_IFMT) == S_IFLNK,
                  let dest = existing, dest.hasSuffix("/skills/starling-desktop") else { return }
            if dest == source { return }
            try? fm.removeItem(atPath: link)
        }

        try? fm.createDirectory(atPath: skillsDir, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o755])
        do {
            try fm.createSymbolicLink(atPath: link, withDestinationPath: source)
        } catch {
            return
        }

        // Dev mode runs the shell as root. Hand what we just made to the login
        // user, or their own agent cannot write beside it later.
        if getuid() == 0 {
            let uid = LoginUser.uid
            let gid = getpwuid(uid)?.pointee.pw_gid ?? gid_t(uid)
            _ = chown(LoginUser.home + "/.claude", uid, gid)
            _ = chown(skillsDir, uid, gid)
            _ = lchown(link, uid, gid)
        }
        #endif
    }

    func _newAgent() {
        #if os(Linux)
        _linkAgentSkill()
        let n = windowManager.agents.count + 1
        let agentId = "agent-\(n)"
        let agent = AgentInfo(id: agentId, name: "Agent \(n) — Claude Code")
        setState { windowManager.agents.append(agent) }
        // Launch at the size the pane will actually be. These used to be
        // fixed (660x1140 / 900x620), which is taller than the chat column
        // on a 1080-tall logical screen: the child laid out once at the
        // launch size, overflowed, and drew the framework's overflow marker
        // until the geometry pass below resized it and something forced a
        // reflow. _applyAgentWindowGeometry() still corrects these on every
        // build — this only makes the FIRST frame right.
        let chat = _agentChatContentSize()
        let stage = _agentStageContentSize()
        _launchAgentChildApp(
            agentId: agentId, execName: "TerminalApp",
            appId: "\(agentId):terminal", title: "Agent Terminal",
            // Tall and narrow: Claude Code renders chat-shaped at native
            // scale in the conversation column.
            rect: Rect.fromLTWH(0, 0, chat.width,
                                chat.height + DesktopTheme.kTitleBarHeight),
            isTerminal: true)
        _launchAgentChildApp(
            agentId: agentId, execName: "FileExplorerApp",
            appId: "\(agentId):files", title: "Files",
            rect: Rect.fromLTWH(0, 0, stage.width,
                                stage.height + DesktopTheme.kTitleBarHeight),
            isTerminal: false)
        #endif
    }

    #if os(Linux)
    /// Launch Chrome from the app runtime for an agent (Murmuration): same
    /// app-run path as the dock, but the arriving Wayland toplevel is
    /// claimed via _pendingAgentWayland instead of joining the desktop.
    func _launchAgentChrome(agentId: String, url: String? = nil,
                            onWindow: ((String) -> Void)? = nil) -> Bool {
        guard let wayland = waylandIntegration, let socketName = wayland.socketName else {
            return false
        }
        let xdgDir = LoginUser.runtimeDir
        let appRun = ProcessInfo.processInfo.environment["STARLING_APP_RUN"] ?? "/usr/bin/app-run"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appRun)
        process.arguments = url.map { ["chrome", $0] } ?? ["chrome"]
        var env = ProcessInfo.processInfo.environment
        env["STARLING_WAYLAND"] = socketName
        env["STARLING_XDG_DIR"] = xdgDir
        env["STARLING_APP_SCALE"] = String(currentShellDpi)
        // Per-agent CDP profile: the broker's cdp_endpoint op reads the
        // DevToolsActivePort this drops in the app home.
        env["STARLING_CDP"] = agentId
        process.environment = env
        _pendingAgentWayland = (agentId, onWindow)
        do {
            try process.run()
            return true
        } catch {
            _pendingAgentWayland = nil
            return false
        }
    }

    /// Agent-owned variant of the dock's child-app launch path: same
    /// DMA-BUF plumbing, but the window is tagged ownerAgentId (no desktop
    /// presence, no focus steal) and teardown skips the desktop close
    /// animation (the window was never mounted in the desktop tree).
    /// `onWindow` fires (main thread) once the window exists — the broker
    /// uses it to answer `launch` with the window id.
    func _launchAgentChildApp(agentId: String, execName: String,
                              appId: String, title: String,
                              rect: Rect, isTerminal: Bool,
                              onWindow: ((String) -> Void)? = nil) {
        guard let mgr = linuxProcessAppManager else { return }
        let contentW = Int(rect.width)
        let contentH = Int(rect.height - DesktopTheme.kTitleBarHeight)
        // Murmuration P3: each agent child gets a semantics endpoint the
        // broker can query (label/action tree, no coordinates).
        let endpointPath = (ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp")
            + "/starling-sem-\(getpid())-\(appId.replacingOccurrences(of: ":", with: "-")).sock"
        mgr.launchDmaBufApp(
            executableName: execName,
            contentWidth: contentW,
            contentHeight: contentH,
            extraEnv: ["STARLING_AGENT_ENDPOINT": endpointPath],
            onReady: { [self] (texId: Int64) in
                mgr.onFirstFrame(textureId: texId) { [self] in
                    setState {
                        processTextureIds[appId] = texId
                        let winId = windowManager.addWindow(
                            title: title,
                            appId: appId,
                            rect: rect,
                            textureId: Int(texId),
                            onWindowClose: {
                                mgr.destroyApp(textureId: texId)
                            },
                            onPointerEvent: { (phase, x, y, buttons) in
                                mgr.sendPointerEvent(
                                    textureId: texId, phase: phase,
                                    x: x, y: y, buttons: buttons)
                            },
                            onContentResize: { (width, height) in
                                mgr.sendResize(
                                    textureId: texId,
                                    width: Int(width), height: Int(height))
                            },
                            onScrollEvent: { (x, y, dx, dy) in
                                mgr.sendScrollEvent(
                                    textureId: texId,
                                    x: x, y: y, dx: dx, dy: dy)
                            },
                            ownerAgentId: agentId,
                            appBuilder: { _ in SizedBox(expand: ()) }
                        )
                        windowManager.windows.first(where: { $0.id == winId })?
                            .agentEndpointPath = endpointPath
                        if isTerminal {
                            windowManager.agents.first(where: { $0.id == agentId })?
                                .terminalWindowId = winId
                            // Looking at the AI Space right now → focus the
                            // terminal so keys reach the agent immediately.
                            if windowManager.activeSpace.isAgent {
                                windowManager.focusedWindowId = winId
                            }
                        }
                        onWindow?(winId)
                    }
                }
            },
            onTerminated: { [self] in
                setState {
                    processTextureIds.removeValue(forKey: appId)
                    if isTerminal {
                        windowManager.agents.first(where: { $0.id == agentId })?
                            .terminalWindowId = nil
                    }
                    // Not in the desktop tree — no close animation to play;
                    // drop the window directly.
                    if let win = windowManager.windows.first(where: { $0.appId == appId }) {
                        windowManager.closeWindow(win.id)
                    }
                }
            }
        )
    }
    #endif

    // MARK: Scripted P0 demo task

    /// P0 exit criterion: the agent completes a scripted Files task while
    /// the human keeps the cursor. Injects clicks over the Files window's
    /// own DMA-BUF socket (content-local coordinates) — the seat, and the
    /// human's pointer, are never touched.
    func _runAgentDemo(_ agent: AgentInfo) {
        guard let files = windowManager.windows(ownedBy: agent.id)
            .first(where: { $0.appId.contains(":files") }) else { return }
        let winId = files.id
        _agentDemoToken += 1
        let token = _agentDemoToken

        // Sidebar rows of a fresh 900x620 Files window, content-local.
        let clicks: [(label: String, x: Double, y: Double)] = [
            ("open Documents", 61, 99),
            ("open Pictures", 61, 159),
            ("back to Home", 61, 40),
        ]
        // Flatten to timed actions: press, release 70ms later, next row
        // after a beat — enough to watch it happen in the tile.
        var actions: [(delayMs: Int, run: () -> Void)] = []
        for c in clicks {
            actions.append((900, { [weak self] in
                guard let self else { return }
                self.setState { self._agentDemoStatus = c.label }
                self.windowManager.windows.first(where: { $0.id == winId })?
                    .onPointerEvent?(2, c.x, c.y, 1)
            }))
            actions.append((70, { [weak self] in
                self?.windowManager.windows.first(where: { $0.id == winId })?
                    .onPointerEvent?(1, c.x, c.y, 0)
            }))
        }
        actions.append((900, { [weak self] in
            guard let self else { return }
            self.setState { self._agentDemoStatus = "task complete" }
        }))
        actions.append((2500, { [weak self] in
            guard let self else { return }
            self.setState { self._agentDemoStatus = nil }
        }))

        func fire(_ i: Int) {
            guard _agentDemoToken == token, i < actions.count else { return }
            actions[i].run()
            let next: () -> Void = { [weak self] in
                guard let self, self._agentDemoToken == token else { return }
                fire(i + 1)
            }
            // Main-queue-only state; @Sendable coercion is the codebase
            // idiom (see _recordStatusPopupHeight). Foundation.Timer never
            // fires on the DRM embedder.
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(i + 1 < actions.count ? actions[i + 1].delayMs : 0),
                execute: unsafeBitCast(next, to: (@Sendable () -> Void).self))
        }
        if let first = actions.first {
            let start: () -> Void = { [weak self] in
                guard let self, self._agentDemoToken == token else { return }
                fire(0)
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(first.delayMs),
                execute: unsafeBitCast(start, to: (@Sendable () -> Void).self))
        }
    }
}
