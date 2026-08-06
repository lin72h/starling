// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - Cross-tree shared state

/// The wallpaper GL texture, shared with secondary-output widget trees.
/// GL textures are engine-global; set by DesktopShell._loadWallpaperTexture.
nonisolated(unsafe) var sharedWallpaperTextureId: Int64 = -1

/// Flutter view id → DisplayOutput.id, for secondary outputs. Written on the
/// main thread at startup and on the ENGINE PLATFORM thread at hotplug (views
/// must be added there), so access is lock-guarded. Read by the multi-view
/// content builder and the shell.
final class SecondaryViewOutputsMap: @unchecked Sendable {
    private let lock = NSLock()
    private var map: [Int: Int] = [:]
    private var nextViewId = 1

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return map.isEmpty
    }

    /// DisplayOutput ids that already have a Flutter view.
    var outputIds: [Int] {
        lock.lock(); defer { lock.unlock() }
        return Array(map.values)
    }

    subscript(viewId: Int) -> Int? {
        get { lock.lock(); defer { lock.unlock() }; return map[viewId] }
        set { lock.lock(); map[viewId] = newValue; lock.unlock() }
    }

    /// Unique, nonzero Flutter view id (0 is the implicit primary view).
    func allocateViewId() -> Int {
        lock.lock(); defer { lock.unlock() }
        let id = nextViewId
        nextViewId += 1
        return id
    }

    /// Drop mappings for outputs that no longer exist (monitor unplugged),
    /// so a reconnected output gets a fresh view.
    func removeMappings(notIn aliveOutputIds: Set<Int>) {
        lock.lock(); defer { lock.unlock() }
        map = map.filter { aliveOutputIds.contains($0.value) }
    }
}

let secondaryViewOutputs = SecondaryViewOutputsMap()

/// Rebuild hooks for the secondary-output screens, keyed by output id.
/// Populated by SecondaryScreenHost states; poked by the primary shell
/// whenever its state changes (window moves, opens, closes, focus).
nonisolated(unsafe) var secondaryScreenInvalidators: [Int: () -> Void] = [:]

/// Ask every secondary screen to re-check its content. Each host skips the
/// rebuild unless the windows visible on ITS output actually changed.
func invalidateSecondaryScreens() {
    for invalidate in secondaryScreenInvalidators.values {
        invalidate()
    }
}

/// Keep Wayland clients' wl_surface enter/leave in step with where their
/// windows sit in the virtual desktop. Diffing happens in WaylandIntegration
/// (per-surface mask cache), so calling this on every shell state change is
/// cheap; non-Wayland windows no-op.
func updateWaylandSurfaceOutputs() {
    guard let dl = displayLayout, dl.outputs.count > 1,
          let wl = waylandIntegration,
          let shell = _shellState else { return }
    for win in shell.windowManager.visibleWindows {
        wl.updateSurfaceOutputs(
            windowId: win.id,
            intersectingIds: dl.outputs(intersectingRect: win.rect).map { $0.id })
    }
}

// MARK: - SecondaryScreenHost

/// Hosts one secondary output's screen in its own widget tree and rebuilds it
/// when the shared shell state changes. Rebuilds are signature-gated: dock
/// animations and other primary-only churn don't re-present a static output.
class SecondaryScreenHost: StatefulWidget {
    let output: DisplayOutput

    init(output: DisplayOutput) {
        self.output = output
        super.init()
    }

    override func createState() -> State<StatefulWidget> {
        return _SecondaryScreenHostState(output: output)
    }
}

class _SecondaryScreenHostState: State<StatefulWidget> {
    let output: DisplayOutput
    private var _lastSignature = ""

    init(output: DisplayOutput) {
        self.output = output
        super.init()
    }

    override func initState() {
        super.initState()
        secondaryScreenInvalidators[output.id] = { [weak self] in
            self?._poke()
        }
    }

    override func dispose() {
        secondaryScreenInvalidators.removeValue(forKey: output.id)
        super.dispose()
    }

    /// What this output shows, as a comparable string: the windows that
    /// intersect it (id/rect/focus) plus the shared wallpaper texture and
    /// the active theme (an appearance switch must re-present).
    private func _signature() -> String {
        var sig = "wp:\(sharedWallpaperTextureId):\(shellTheme.name)"
        if let wm = _shellState?.windowManager {
            for win in wm.visibleWindows where _intersectsOutput(win.rect) {
                let r = win.rect
                sig += "|\(win.id):\(r.left),\(r.top),\(r.width),\(r.height)" +
                    ":\(win.id == wm.focusedWindowId ? 1 : 0):\(win.zIndex)"
            }
        }
        return sig
    }

    private func _intersectsOutput(_ r: Rect) -> Bool {
        r.right > output.logicalLeft && r.left < output.logicalRight &&
        r.bottom > output.logicalTop && r.top < output.logicalBottom
    }

    private func _poke() {
        let sig = _signature()
        if sig != _lastSignature {
            setState {}
        }
    }

    override func build(_ context: any BuildContext) -> Widget {
        _lastSignature = _signature()
        return SecondaryOutputScreen(output: output).build()
    }
}

// MARK: - SecondaryOutputScreen

/// The desktop on a non-primary output: per-output wallpaper and menu bar
/// (macOS policy — a menu bar on every display; the single dock stays on the
/// primary), plus every window whose virtual-desktop rect intersects this
/// output, positioned in output-local coordinates. A window straddling the
/// seam renders on both outputs, each showing its own portion.
///
/// This widget lives in its own widget tree (one per Flutter view); shared
/// shell state is reached through the _shellState global and rebuilds arrive
/// via secondaryScreenInvalidators.
struct SecondaryOutputScreen {
    let output: DisplayOutput

    private func _statusBar() -> Widget {
        // Static clock: rendered at build time. Live per-output menu bar
        // content (frontmost app, ticking clock) arrives with the shared
        // window state work.
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        let combined = "\(timeFormatter.string(from: now))   \(dateFormatter.string(from: now))"

        return ClipRect(
            child: BackdropFilter(
                filter: ImageFilterFactory.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: shellTheme.barTint,
                        border: Border(bottom: BorderSide(color: shellTheme.barHairline, width: 1))),
                    child: Padding(
                        padding: EdgeInsets(left: 16, top: 0, right: 16, bottom: 0),
                        child: Row(
                            mainAxisAlignment: .spaceBetween,
                            crossAxisAlignment: .center,
                            children: [
                                Text(combined, style: TextStyle(
                                    color: shellTheme.fgPrimary, fontSize: 13,
                                    fontWeight: .w500)),
                                Text(output.name, style: TextStyle(
                                    color: shellTheme.fgSecondary, fontSize: 12)),
                            ])))))
    }

    private func _wallpaper() -> Widget {
        #if os(Linux)
        if sharedWallpaperTextureId >= 0 {
            return TextureWidget(
                textureId: Int(sharedWallpaperTextureId), filterQuality: .low)
        }
        #endif
        return DesktopBackground(preset: .slate)
    }

    /// Windows intersecting this output, in output-local coordinates.
    /// Callbacks mutate the shared shell state (and re-invalidate every
    /// screen through the shell's setState) — inert until pointer events
    /// route to secondary views, but correct once they do.
    private func _windows() -> [Widget] {
        guard let shell = _shellState else { return [] }
        let wm = shell.windowManager
        var widgets: [Widget] = []
        for win in wm.visibleWindows {
            let r = win.rect
            guard r.right > output.logicalLeft, r.left < output.logicalRight,
                  r.bottom > output.logicalTop, r.top < output.logicalBottom
            else { continue }
            let winId = win.id
            widgets.append(Positioned(
                key: ValueKey("sec\(output.id)-\(winId)"),
                left: r.left - output.originX,
                top: r.top - output.originY,
                width: r.width, height: r.height,
                child: DesktopWindow(
                    windowInfo: win,
                    isFocused: winId == wm.focusedWindowId,
                    onBringToFront: {
                        _shellState?.setState {
                            _shellState?.windowManager.bringToFront(winId)
                        }
                    },
                    onMove: { delta in
                        _shellState?.setState {
                            _shellState?.windowManager.moveWindowByDelta(winId, delta: delta)
                        }
                    },
                    onResize: { edge, delta in
                        _shellState?.setState {
                            _shellState?.windowManager.resizeWindow(winId, edge: edge, delta: delta)
                        }
                    })))
        }
        return widgets
    }

    func build() -> Widget {
        var layers: [Widget] = [Positioned(fill: (), child: _wallpaper())]
        layers.append(contentsOf: _windows())
        layers.append(Positioned(
            left: 0, top: 0,
            width: output.logicalWidth,
            height: DesktopTheme.kStatusBarHeight,
            child: _statusBar()))

        // This tree has no MacosApp above it, so establish text direction
        // ourselves — Stack/Row alignment resolution traps without it.
        return Directionality(
            textDirection: .ltr,
            child: Stack(fit: .expand, children: layers))
    }
}
