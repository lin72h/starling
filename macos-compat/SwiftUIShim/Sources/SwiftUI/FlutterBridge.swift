// SwiftUI-side bridge. This module is named `SwiftUI` and must import ONLY
// Foundation — importing AppKit/Flutter (or anything that does, transitively)
// pulls in Apple's SwiftUICore, whose @_originallyDefinedIn("SwiftUI") symbols
// collide with ours during SIL linking. So we cross to FlutterHost through plain
// C symbols (resolved within the same dylib), passing the view tree as JSON.

import Foundation

@_silgen_name("swiftui_compat_run")
func _swiftui_compat_run(_ json: UnsafePointer<CChar>)

@_silgen_name("swiftui_compat_update")
func _swiftui_compat_update(_ json: UnsafePointer<CChar>)

// The unmodified app's root view (e.g. ContentView), retained so we can re-walk
// its `body` after @State changes. SwiftUI views are value types, but @State is
// reference-backed, so copies share the same storage — re-walking sees mutations.
nonisolated(unsafe) var _hostRoot: (any View)?
// Button action closures by id; rebuilt on every walk (ids are walk-order stable).
nonisolated(unsafe) var _actions: [Int: () -> Void] = [:]
nonisolated(unsafe) var _buttonCounter = 0

// GeometryReader closures by id. A GR's body needs the laid-out size, unknown during the
// tree walk, so _makeView registers the closure here and the host calls back with the size
// (swiftui_compat_geometry) at build time. Rebuilt on every walk, like button actions.
nonisolated(unsafe) var _geometryReaders: [Int: (CGFloat, CGFloat) -> RenderNode] = [:]
nonisolated(unsafe) var _geometryCounter = 0
func _registerGeometry(_ f: @escaping (CGFloat, CGFloat) -> RenderNode) -> Int {
    let id = _geometryCounter; _geometryCounter += 1; _geometryReaders[id] = f; return id
}

// Host → SwiftUI callback: run GeometryReader `id`'s closure with the available size and
// return its rendered subtree as JSON (caller frees the malloc'd string).
@_cdecl("swiftui_compat_geometry")
public func swiftui_compat_geometry(_ id: Int, _ w: Double, _ h: Double) -> UnsafeMutablePointer<CChar>? {
    let node = _geometryReaders[id]?(CGFloat(w), CGFloat(h)) ?? .empty
    return strdup(_nodeJSON(node))
}

private func _jsonString(_ s: String) -> String {
    if _traceOn {
        // Dump the raw _StringObject (two words) — a pure bit copy, safe even if the
        // string's storage is foreign/corrupt. Discriminator byte is the top byte of
        // word1 (small-ASCII 0xE0+, native large 0x00, foreign/shared/cocoa otherwise).
        let raw = unsafeBitCast(s, to: (UInt64, UInt64).self)
        FileHandle.standardError.write(Data(
            "[trace] _jsonString raw=0x\(String(raw.0, radix: 16)),0x\(String(raw.1, radix: 16))\n".utf8))
    }
    var out = "\""
    for c in s {
        switch c {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        default: out.append(c)
        }
    }
    out += "\""
    return out
}

func _opt(_ s: String?) -> String { s.map { _jsonString($0) } ?? "null" }
func _num(_ d: CGFloat?) -> String { d.map { String(describing: $0) } ?? "null" }

// Serialise the RenderNode tree (produced by _renderRoot via the _makeView witness
// recursion) into the JSON the host already renders. Button actions are registered
// by walk-order-stable id so taps route back through swiftui_compat_dispatch.
func _nodeJSON(_ n: RenderNode) -> String {
    func kids(_ ns: [RenderNode]) -> String { ns.map { _nodeJSON($0) }.joined(separator: ",") }
    switch n {
    case .text(let s, let c, let f, let b, let lines, let italic):
        return "{\"t\":\"text\",\"s\":\(_jsonString(s)),\"color\":\(_opt(c)),\"font\":\(_opt(f)),\"bold\":\(b),\"lines\":\(lines.map(String.init) ?? "null"),\"italic\":\(italic)}"
    case .empty:           return "{\"t\":\"empty\"}"
    case .spacer:          return "{\"t\":\"spacer\"}"
    case .divider:         return "{\"t\":\"divider\"}"
    case .image(let n, let c):
        return "{\"t\":\"image\",\"name\":\(_jsonString(n)),\"color\":\(_opt(c))}"
    case .colorBox(let n): return "{\"t\":\"colorbox\",\"name\":\(_jsonString(n))}"
    case .linearGradient(let cols, let sx, let sy, let ex, let ey):
        let arr = cols.map { _jsonString($0) }.joined(separator: ",")
        return "{\"t\":\"lineargradient\",\"colors\":[\(arr)],\"sx\":\(sx),\"sy\":\(sy),\"ex\":\(ex),\"ey\":\(ey)}"
    case .radialGradient(let cols, let cx, let cy, let sr, let er):
        let arr = cols.map { _jsonString($0) }.joined(separator: ",")
        return "{\"t\":\"radialgradient\",\"colors\":[\(arr)],\"cx\":\(cx),\"cy\":\(cy),\"sr\":\(sr),\"er\":\(er)}"
    case .angularGradient(let cols, let cx, let cy, let sa, let ea):
        let arr = cols.map { _jsonString($0) }.joined(separator: ",")
        return "{\"t\":\"angulargradient\",\"colors\":[\(arr)],\"cx\":\(cx),\"cy\":\(cy),\"sa\":\(sa),\"ea\":\(ea)}"
    case .grid(let cols, let ch): return "{\"t\":\"grid\",\"cols\":\(cols),\"children\":[\(kids(ch))]}"
    case .picker(let label, let options, let sel, let actions):
        let ids = actions.map { a -> Int in let id = _buttonCounter; _buttonCounter += 1; _actions[id] = a; return id }
        return "{\"t\":\"picker\",\"label\":\(_nodeJSON(label)),\"options\":[\(kids(options))],\"sel\":\(sel),\"ids\":[\(ids.map { String($0) }.joined(separator: ","))]}"
    case .vstack(let sp, let al, let ch): return "{\"t\":\"column\",\"sp\":\(_num(sp)),\"align\":\(al),\"children\":[\(kids(ch))]}"
    case .hstack(let sp, let al, let ch): return "{\"t\":\"row\",\"sp\":\(_num(sp)),\"align\":\(al),\"children\":[\(kids(ch))]}"
    case .zstack(let ch):  return "{\"t\":\"stack\",\"children\":[\(kids(ch))]}"
    case .list(let ch):    return "{\"t\":\"list\",\"children\":[\(kids(ch))]}"
    case .tabview(let labels, let pages):
        return "{\"t\":\"tabview\",\"labels\":[\(kids(labels))],\"pages\":[\(kids(pages))]}"
    case .geometryReader(let id): return "{\"t\":\"geometry\",\"id\":\(id)}"
    case .navStack(let root): return "{\"t\":\"navstack\",\"root\":\(_nodeJSON(root))}"
    case .navLink(let label, let dest):
        return "{\"t\":\"navlink\",\"label\":\(_nodeJSON(label)),\"dest\":\(_nodeJSON(dest))}"
    case .scroll(let c):   return "{\"t\":\"scroll\",\"child\":\(_nodeJSON(c))}"
    case .padding(let len, let c): return "{\"t\":\"padding\",\"len\":\(len ?? 16),\"child\":\(_nodeJSON(c))}"
    case .frame(let w, let h, let c): return "{\"t\":\"frame\",\"w\":\(_num(w)),\"h\":\(_num(h)),\"child\":\(_nodeJSON(c))}"
    case .clip(let kind, let r, let c): return "{\"t\":\"clip\",\"kind\":\(_jsonString(kind)),\"r\":\(r),\"child\":\(_nodeJSON(c))}"
    case .background(let bg, let c):
        return "{\"t\":\"background\",\"bg\":\(bg.map { _nodeJSON($0) } ?? "null"),\"child\":\(_nodeJSON(c))}"
    case .shaped(let paint, let kind, let r):
        return "{\"t\":\"shaped\",\"paint\":\(_nodeJSON(paint)),\"kind\":\(_jsonString(kind)),\"r\":\(r)}"
    case .overlay(let c, let o, let al): return "{\"t\":\"overlay\",\"child\":\(_nodeJSON(c)),\"over\":\(_nodeJSON(o)),\"align\":\(al)}"
    case .button(let action, let c, let style):
        let id = _buttonCounter; _buttonCounter += 1; _actions[id] = action
        return "{\"t\":\"button\",\"id\":\(id),\"style\":\(_opt(style)),\"child\":\(_nodeJSON(c))}"
    case .toggle(let on, let c): return "{\"t\":\"toggle\",\"on\":\(on),\"child\":\(_nodeJSON(c))}"
    case .textField(let t, let c): return "{\"t\":\"textfield\",\"text\":\(_jsonString(t)),\"child\":\(_nodeJSON(c))}"
    case .slider(let v):   return "{\"t\":\"slider\",\"value\":\(v)}"
    case .progress(let f): return "{\"t\":\"progress\",\"value\":\(_num(f))}"
    case .stepper(let label, let dec, let inc):
        let d = _buttonCounter; _buttonCounter += 1; _actions[d] = dec
        let i = _buttonCounter; _buttonCounter += 1; _actions[i] = inc
        return "{\"t\":\"stepper\",\"label\":\(_nodeJSON(label)),\"dec\":\(d),\"inc\":\(i)}"
    case .tappable(let action, let c):
        let id = _buttonCounter; _buttonCounter += 1; _actions[id] = action
        return "{\"t\":\"tappable\",\"id\":\(id),\"child\":\(_nodeJSON(c))}"
    case .sheet(let dismiss, let base, let content):
        let id = _buttonCounter; _buttonCounter += 1; _actions[id] = dismiss
        return "{\"t\":\"sheet\",\"id\":\(id),\"base\":\(_nodeJSON(base)),\"content\":\(_nodeJSON(content))}"
    case .opacity(let o, let c):
        return "{\"t\":\"opacity\",\"o\":\(o),\"child\":\(_nodeJSON(c))}"
    case .scale(let sx, let sy, let c):
        return "{\"t\":\"scale\",\"sx\":\(sx),\"sy\":\(sy),\"child\":\(_nodeJSON(c))}"
    case .shadow(let color, let r, let dx, let dy, let c):
        return "{\"t\":\"shadow\",\"color\":\(_jsonString(color)),\"r\":\(r),\"dx\":\(dx),\"dy\":\(dy),\"child\":\(_nodeJSON(c))}"
    case .menu(let label, let items):
        return "{\"t\":\"menu\",\"label\":\(_nodeJSON(label)),\"items\":[\(kids(items))]}"
    case .offsetBy(let dx, let dy, let c):
        return "{\"t\":\"offset\",\"dx\":\(dx),\"dy\":\(dy),\"child\":\(_nodeJSON(c))}"
    case .rotate(let rad, let c):
        return "{\"t\":\"rotate\",\"rad\":\(rad),\"child\":\(_nodeJSON(c))}"
    case .blur(let r, let c):
        return "{\"t\":\"blur\",\"r\":\(r),\"child\":\(_nodeJSON(c))}"
    case .stroked(let paint, let kind, let r, let w):
        return "{\"t\":\"stroked\",\"paint\":\(_nodeJSON(paint)),\"kind\":\(_jsonString(kind)),\"r\":\(r),\"w\":\(w)}"
    case .draggable(let action, let c):
        let id = _dragCounter; _dragCounter += 1; _dragActions[id] = action
        return "{\"t\":\"draggable\",\"id\":\(id),\"child\":\(_nodeJSON(c))}"
    }
}

// Drag actions by id (walk-order stable, like buttons). The host routes pan events here
// with (x, y, startX, startY); a DragGesture.Value is synthesized for the app's closure.
nonisolated(unsafe) var _dragActions: [Int: (DragGesture.Value) -> Void] = [:]
nonisolated(unsafe) var _dragCounter = 0
@_cdecl("swiftui_compat_drag")
public func swiftui_compat_drag(_ id: Int, _ x: Double, _ y: Double, _ sx: Double, _ sy: Double) {
    guard let action = _dragActions[id] else { return }
    let prev = _rendering; _rendering = true
    action(DragGesture.Value(time: Date(), location: CGPoint(x: x, y: y),
                             startLocation: CGPoint(x: sx, y: sy)))
    _rendering = prev
    _renderAndPush()
}

// ── Push-based invalidation (objectWillChange / @Published mutation → re-render) ──
// `_rendering` is true while we're inside a tree walk or a dispatched action; a mutation that
// lands then is DEFERRED (Apple coalesces on the next runloop tick) by setting `_pendingInvalidate`,
// and the outermost operation re-renders once the value is committed. A mutation that lands while
// idle (e.g. a timer/async callback on the host loop) re-renders immediately.
nonisolated(unsafe) var _rendering = false
nonisolated(unsafe) var _pendingInvalidate = false
// `.onAppear` closures already fired, keyed by closure fn pointer — fire once per appearance so an
// onAppear that mutates state doesn't loop the settle pass.
nonisolated(unsafe) var _appearedFired: Set<UInt> = []
func _closureFn(_ c: @escaping () -> Void) -> UInt { unsafeBitCast(c, to: (UInt, UInt).self).0 }

/// Re-render the retained root view (reading current @State) into fresh JSON,
/// rebuilding the button-action registry — via the real _makeView render pass.
func _rebuildJSON() -> String {
    _actions.removeAll()
    _buttonCounter = 0
    _geometryReaders.removeAll()
    _geometryCounter = 0
    _dragActions.removeAll()
    _dragCounter = 0
    guard let root = _hostRoot else { return "{\"t\":\"empty\"}" }
    let prev = _rendering; _rendering = true        // mutations during the walk defer
    let node = _renderRoot(root)
    _rendering = prev
    return _nodeJSON(node)
}

/// Re-render and push to the host, settling any invalidations the walk itself triggers (e.g. an
/// onAppear mutation), capped so a pathological "mutate every render" can't spin forever.
func _renderAndPush() {
    _pendingInvalidate = false
    var json = _rebuildJSON()
    var n = 0
    while _pendingInvalidate && n < 8 { _pendingInvalidate = false; json = _rebuildJSON(); n += 1 }
    json.withCString { _swiftui_compat_update($0) }
}

// Called from Combine (libCombine) on a @Published mutation / ObservableObjectPublisher.send().
// The C symbol is resolved across the two dylibs at load time (like swiftui_compat_run/update).
@_cdecl("swiftui_compat_invalidate")
public func swiftui_compat_invalidate() {
    if _rendering { _pendingInvalidate = true; return }   // defer until the current op commits
    _renderAndPush()
}

// Called from FlutterHost when a rendered button is tapped.
@_cdecl("swiftui_compat_dispatch")
public func swiftui_compat_dispatch(_ id: Int) {
    let prev = _rendering; _rendering = true   // action mutations defer to the re-render below
    _actions[id]?()                            // invoke the SwiftUI action → mutates @State/@Published
    _rendering = prev
    _renderAndPush()                           // re-walk the (retained) root view + push
    _dbg("button \(id) tapped → re-rendered")
}

// Gated on MACHOLD_TRACE so the tree-build can be traced when bringing up a new
// probe (e.g. which view's construction faults) without noise in normal runs.
nonisolated(unsafe) let _traceOn = ProcessInfo.processInfo.environment["MACHOLD_TRACE"] != nil
func _dbg(_ s: String) { if _traceOn { FileHandle.standardError.write(Data("[trace] \(s)\n".utf8)) } }

func _runViaFlutter<A: App>(_ app: A) {
    _dbg("app.body …")
    let scene = app.body
    _dbg("got scene \(type(of: scene)); extracting root view …")
    let content: any View = (scene as? _AnyWindowGroup)?._rootView ?? EmptyView()
    _dbg("root view = \(type(of: content)); rendering via View._makeView …")
    _hostRoot = content
    // Settle onAppear-driven mutations INTO the first frame: `_swiftui_compat_run` may block in the
    // host event loop (L2/GLFW), so any re-render must happen before it. (Mutations that arrive
    // later, while the loop runs — timer/async — re-render through swiftui_compat_invalidate →
    // _swiftui_compat_update's mailbox.) Capped settle loop; onAppear fires once so it converges.
    _pendingInvalidate = false
    var json = _rebuildJSON()           // first walk; onAppear fires → may set _pendingInvalidate
    var n = 0
    while _pendingInvalidate && n < 8 { _pendingInvalidate = false; json = _rebuildJSON(); n += 1 }
    _dbg("rendered tree: \(json)")
    json.withCString { _swiftui_compat_run($0) }   // may block in the host event loop
}
