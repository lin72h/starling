// FlutterHost: the Flutter/AppKit-facing half of the SwiftUI binary-compat shim.
//
// It is deliberately a SEPARATE module from `SwiftUI`: our reconstructed module is
// literally named `SwiftUI`, and importing AppKit/Flutter there pulls in Apple's
// `SwiftUICore` (whose @_originallyDefinedIn("SwiftUI") symbols collide with ours
// → SIL deserialization crash). So `SwiftUI` talks to this module only through the
// neutral `RNode` tree below — no Flutter/AppKit/SwiftUICore types cross the line.

import Foundation
import AppKit
import Flutter
import FlutterSwiftBridge   // Color
import FlutterMacOSBridge   // FlutterEngine, FlutterViewController
import SwiftRuntime         // createRuntimeCallbacks

/// Neutral description of a translated SwiftUI view tree (no SwiftUI/Flutter types).
public indirect enum RNode: Sendable {
    case text(String)
    case column([RNode])
    case padding(Double, RNode)
    case button(Int, RNode)   // (action id, label)
    case empty
}

// Calls back into the SwiftUI module to invoke the original SwiftUI action closure.
@_silgen_name("swiftui_compat_dispatch")
func _dispatch(_ id: Int)

func toWidget(_ node: RNode) -> Flutter.Widget {
    switch node {
    case .text(let s):
        return Flutter.Text(s, style: TextStyle(color: Color(0xFF1D1D1F), fontSize: 28))
    case .empty:
        return Flutter.Text("")
    case .column(let kids):
        return Flutter.Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            children: kids.map { toWidget($0) }
        )
    case .button(let id, let label):
        return Flutter.GestureDetector(
            onTap: { _dispatch(id) },
            child: Flutter.Padding(
                padding: EdgeInsets(all: 10),
                child: Flutter.ColoredBox(
                    color: Color(0xFF0A84FF),
                    child: Flutter.Padding(
                        padding: EdgeInsets(horizontal: 16, vertical: 8),
                        child: toWidget(label)
                    )
                )
            )
        )
    case .padding(let len, let child):
        return Flutter.Padding(padding: EdgeInsets(all: len), child: toWidget(child))
    }
}

// Stateful root: holds the current tree and rebuilds when SwiftUI pushes an update
// (e.g. after a button tap mutates @State and re-walks the view tree).
final class HostRootWidget: StatefulWidget {
    let initial: RNode
    init(_ n: RNode) { self.initial = n; super.init(key: nil) }
    override func createState() -> State<StatefulWidget> { HostRootState() }
}
final class HostRootState: State<StatefulWidget> {
    var node: RNode = .empty
    override func initState() {
        super.initState()
        node = (widget as! HostRootWidget).initial
        hostRootState = self
    }
    func apply(_ n: RNode) {
        setState { self.node = n }
        PlatformDispatcher.instance.scheduleFrame()
        // macOS Swift-mode: ScheduleFrame() alone doesn't make the engine deliver a
        // vsync frame, but a window-metrics change does (same path a manual resize
        // uses). Nudge the content height by 1pt and back to force the engine to
        // produce + present a frame carrying the new tree.
        if let w = hostWindow {
            let s = w.contentLayoutRect.size
            w.setContentSize(NSSize(width: s.width, height: s.height + 1))
            w.setContentSize(NSSize(width: s.width, height: s.height))
        }
    }
    override func build(_ context: any BuildContext) -> Widget {
        return Flutter.Directionality(
            textDirection: .ltr,
            child: Flutter.ColoredBox(
                color: Color(0xFFF5F5F7),
                child: Flutter.Center(child: toWidget(node))))
    }
}
nonisolated(unsafe) var hostRootState: HostRootState?
nonisolated(unsafe) var hostWindow: NSWindow?

// C entry points called from the `SwiftUI` module (which imports only Foundation,
// to avoid pulling in Apple's SwiftUICore). The tree crosses as JSON.
@_cdecl("swiftui_compat_run")
public func swiftui_compat_run(_ jsonPtr: UnsafePointer<CChar>) {
    runFlutterHost(root: parseRNode(String(cString: jsonPtr)))
}

// Push a freshly-walked tree (after @State changed) into the live root.
@_cdecl("swiftui_compat_update")
public func swiftui_compat_update(_ jsonPtr: UnsafePointer<CChar>) {
    let node = parseRNode(String(cString: jsonPtr))
    hlog("update; hostRootState set=\(hostRootState != nil)")
    MainActor.assumeIsolated { hostRootState?.apply(node) }
}

func parseRNode(_ json: String) -> RNode {
    guard let data = json.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .empty }
    return rnode(from: obj)
}

func rnode(from d: [String: Any]) -> RNode {
    switch d["t"] as? String ?? "" {
    case "text": return .text(d["s"] as? String ?? "")
    case "column":
        let arr = d["children"] as? [[String: Any]] ?? []
        return .column(arr.map { rnode(from: $0) })
    case "padding":
        let len = (d["len"] as? NSNumber)?.doubleValue ?? 16
        return .padding(len, (d["child"] as? [String: Any]).map { rnode(from: $0) } ?? .empty)
    case "button":
        let id = (d["id"] as? NSNumber)?.intValue ?? 0
        return .button(id, (d["child"] as? [String: Any]).map { rnode(from: $0) } ?? .empty)
    default: return .empty
    }
}

/// Boot NSApplication + the Flutter engine and render `root` in a macOS window.
/// The AppKit + embedder path. Never returns (runs the AppKit loop).
func hlog(_ s: String) { FileHandle.standardError.write(Data("[FlutterHost] \(s)\n".utf8)) }

func runFlutterHost(root: RNode) {
    MainActor.assumeIsolated {
        hlog("enter; root=\(root)")
        let rootWidget = HostRootWidget(root)

        let nsApp = NSApplication.shared
        nsApp.setActivationPolicy(.regular)

        let engine = FlutterEngine(name: "swiftui-compat", project: nil, allowHeadlessExecution: true)
        hlog("engine created; calling runApp")
        runApp(rootWidget)
        hlog("runApp done; starting engine (Swift mode)")

        var callbacks = createRuntimeCallbacks()
        let started = withUnsafePointer(to: &callbacks) { ptr in
            engine.runSwift(withRuntimeCallbacks: UnsafeRawPointer(ptr))
        }
        hlog("engine started=\(started)")
        guard started else { fatalError("[FlutterHost] engine failed to start") }

        let vc = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        hlog("view controller created")
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 640, 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "SwiftUI → Flutter (binary-compat)"
        window.contentViewController = vc
        window.setContentSize(NSMakeSize(640, 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        nsApp.activate(ignoringOtherApps: true)
        hlog("window ordered front (\(window.frame)); scheduling frame + running loop")

        hostWindow = window
        PlatformDispatcher.instance.scheduleFrame()
        nsApp.run()
    }
}
