// CompatHost (Linux/arm64) — the Flutter-facing half of the SwiftUI binary-compat
// shim, the counterpart to the macOS FlutterHost. The reconstructed `SwiftUI`
// module (libSwiftUI.so, Foundation-only) crosses into here through the C symbols
// `swiftui_compat_run` / `swiftui_compat_update`, handing over the reflected view
// tree of the *unmodified* Mach-O binary as JSON. We translate it to this repo's
// Swift `Flutter` widgets and render it through the Flutter engine in a GLFW/
// Wayland window — taps route back via `swiftui_compat_dispatch` into the app's
// real SwiftUI action closures (@State mutates → re-walk → update → rebuild).
//
// The engine bootstrap is the GLFW + embedder windowed path: create a GLFW
// window, hand its GL context to the embedder, drive frames from its loop.

import Foundation
import Glibc
import SwiftRuntime
import FlutterSwiftBridge   // Color, PlatformDispatcher
import FlutterEmbedderBridge
import GLFWBridge
import Flutter

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Neutral tree (no SwiftUI types cross the line) + Flutter translation
// ════════════════════════════════════════════════════════════════════════════

public indirect enum RNode: Sendable {
    case text(String, color: String?, font: String?, bold: Bool, lines: Int? = nil, italic: Bool = false)
    case column(Double?, Int, [RNode]); case row(Double?, Int, [RNode]); case stack([RNode]); case list([RNode])
    case tabview([RNode], [RNode])   // (tab labels, tab pages)
    case geometry(Int)               // GeometryReader id — resolved at build time with the available size
    case navStack(RNode)             // NavigationStack root
    case navLink(RNode, RNode)       // (label, destination) — tapping pushes the destination host-side
    case scroll(RNode); case padding(Double, RNode)
    case frame(Double?, Double?, RNode); case clip(String, Double, RNode); case fgcolor(String?, RNode)
    case background(RNode?, RNode); case overlay(RNode, RNode, Int)
    case shaped(RNode, String, Double)   // (paint, shapeKind, cornerRadius) — style clipped to a shape
    case spacer; case divider; case image(String, String?); case colorBox(String)
    case linearGradient([String], Double, Double, Double, Double)  // colorNames, startX, startY, endX, endY
    case radialGradient([String], Double, Double, Double, Double)  // colorNames, centerX, centerY, startRadius, endRadius
    case angularGradient([String], Double, Double, Double, Double) // colorNames, centerX, centerY, startAngle, endAngle (radians)
    case button(Int, RNode, String? = nil); case toggle(Bool, RNode); case textField(String, Int, RNode); case slider(Double)
    case progress(Double?)
    case stepper(RNode, Int, Int)   // (label, decrement action id, increment action id)
    case grid(Int, [RNode])         // (column count, flattened items)
    case picker(RNode, [RNode], Int, [Int])   // (label, option labels, selected idx, per-option action ids)
    case tappable(Int, RNode)       // .onTapGesture — tapping dispatches the action id
    case sheet(Int, RNode, RNode)   // (.sheet dismiss id, base, presented content) — modal over base
    case opacity(Double, RNode)     // .opacity
    case scale(Double, Double, RNode)                 // .scaleEffect (sx, sy)
    case shadow(String, Double, Double, Double, RNode)  // .shadow (colorName, radius, dx, dy)
    case menu(RNode, [RNode])       // Menu — label expands to the items on tap (host state)
    case offsetBy(Double, Double, RNode)   // .offset
    case rotate(Double, RNode)             // .rotationEffect (radians)
    case blur(Double, RNode)               // .blur
    case stroked(RNode, String, Double, Double)   // shape OUTLINE (paint, kind, radius, width)
    case draggable(Int, RNode)      // .gesture(DragGesture) — pan events route to the drag id
    case empty
}

// Back into the SwiftUI module: invokes the unmodified app's SwiftUI action.
@_silgen_name("swiftui_compat_dispatch")
func _dispatch(_ id: Int)

// Back into the SwiftUI module: run GeometryReader `id`'s closure with the available size,
// returning its rendered subtree as JSON (we free the malloc'd string).
@_silgen_name("swiftui_compat_geometry")
func _geometry(_ id: Int, _ w: Double, _ h: Double) -> UnsafeMutablePointer<CChar>?

// Back into the SwiftUI module: a pan event for drag id (position + drag-start position).
@_silgen_name("swiftui_compat_drag")
func _dispatchDrag(_ id: Int, _ x: Double, _ y: Double, _ sx: Double, _ sy: Double)

// Back into the app: an editable text field (id) was submitted/changed with new text.
// (machold routes it to the NSTextField's target/action or delegate; the SwiftUI tier's
// definition, if any, resolves via RTLD_NEXT.)
@_silgen_name("swiftui_compat_text")
func _dispatchText(_ id: Int, _ text: UnsafePointer<CChar>?)

// SwiftUI semantic color name → Color (dark appearance, matching the macOS run).
func colorFor(_ name: String?) -> Color {
    // Value colors: "rgba:r,g,b,a" with 0…1 components (e.g. .shadow's default color).
    if let name, name.hasPrefix("rgba:") {
        let p = name.dropFirst(5).split(separator: ",").compactMap { Double($0) }
        if p.count == 4 {
            func ch(_ v: Double) -> Int { Int(min(max(v, 0), 1) * 255) }
            return Color((ch(p[3]) << 24) | (ch(p[0]) << 16) | (ch(p[1]) << 8) | ch(p[2]))
        }
    }
    switch name ?? "primary" {
    case "blue": return Color(0xFF0A84FF)
    case "green": return Color(0xFF5BD15B)
    case "yellow": return Color(0xFFFFD60A)
    case "orange": return Color(0xFFFF9F0A)
    case "red": return Color(0xFFFF453A)
    case "white": return Color(0xFFFFFFFF)
    case "black": return Color(0xFF000000)
    case "secondary": return Color(0xFF98989D)
    default: return Color(0xFFFFFFFF)   // primary = white in dark mode
    }
}
// SwiftUI UnitPoint (0…1, y-down) → Flutter Alignment (−1…1, y-down): v*2−1.
func unitAlign(_ x: Double, _ y: Double) -> Alignment { Alignment(x * 2 - 1, y * 2 - 1) }

// A "paint" RenderNode (Color / gradient) → a BoxDecoration. Shared by the bare view
// and the `.background(style)` modifier: DecoratedBox paints the decoration behind the
// child, sized to the child — exactly SwiftUI's `.background` sizing. Non-paint → nil.
func boxDecoration(for node: RNode) -> Flutter.BoxDecoration? {
    switch node {
    case .colorBox(let name):
        return Flutter.BoxDecoration(color: colorFor(name))
    case .linearGradient(let names, let sx, let sy, let ex, let ey):
        return Flutter.BoxDecoration(gradient: Flutter.LinearGradient(
            begin: unitAlign(sx, sy), end: unitAlign(ex, ey), colors: names.map { colorFor($0) }))
    case .radialGradient(let names, let cx, let cy, _, _):
        // SwiftUI start/endRadius are absolute points; Flutter's radius is a fraction of
        // the box's shortest side (resolved at paint time). Use the default 0.5 — a
        // centered radial filling the box; exact point radii need box size (GeometryReader-class).
        return Flutter.BoxDecoration(gradient: Flutter.RadialGradient(
            center: unitAlign(cx, cy), radius: 0.5, colors: names.map { colorFor($0) }))
    case .angularGradient(let names, let cx, let cy, let sa, let ea):
        return Flutter.BoxDecoration(gradient: Flutter.SweepGradient(
            center: unitAlign(cx, cy), startAngle: sa, endAngle: ea, colors: names.map { colorFor($0) }))
    case .shaped(let paint, let kind, let radius):
        // A paint (color/gradient) clipped to a shape: take the paint's decoration and add
        // the shape — BoxDecoration clips its fill to borderRadius / a circle.
        guard let base = boxDecoration(for: paint) else { return nil }
        switch kind {
        case "roundedrect": return base.copyWith(borderRadius: BorderRadius.circular(radius))
        case "capsule":     return base.copyWith(borderRadius: BorderRadius.circular(9999))  // pill (clamped to half-height)
        case "circle", "ellipse": return base.copyWith(shape: .circle)
        default:            return base   // rectangle: no rounding
        }
    case .stroked(let paint, let kind, let radius, let width):
        // Shape OUTLINE (Shape.stroke / the inlined .border): a border-only decoration
        // in the paint's color (borders are solid-color; gradients fall back to primary).
        var strokeColor = colorFor("primary")
        if case let .colorBox(name) = paint { strokeColor = colorFor(name) }
        let border = Border.all(color: strokeColor, width: width)
        switch kind {
        case "roundedrect": return Flutter.BoxDecoration(border: border, borderRadius: BorderRadius.circular(radius))
        case "capsule":     return Flutter.BoxDecoration(border: border, borderRadius: BorderRadius.circular(9999))
        case "circle", "ellipse": return Flutter.BoxDecoration(border: border, shape: .circle)
        default:            return Flutter.BoxDecoration(border: border)
        }
    default:
        return nil
    }
}

func fontSize(_ name: String?) -> Double {
    // Font.system(size:weight:) encodes "sys:SIZE:WEIGHT" in the name.
    if let name, name.hasPrefix("sys:") {
        return Double(name.split(separator: ":").dropFirst().first ?? "17") ?? 17
    }
    switch name ?? "body" {
    case "largeTitle": return 32; case "title": return 26; case "headline": return 19
    case "subheadline": return 14; case "caption": return 11; default: return 17
    }
}
// A "sys:SIZE:WEIGHT" font's weight (≥ 0.4 = bold, the Font.Weight scale).
func fontIsBold(_ name: String?) -> Bool {
    guard let name, name.hasPrefix("sys:"), let w = Double(name.split(separator: ":").last ?? "0") else { return false }
    return w >= 0.4
}

// Interleave SwiftUI stack spacing between children (Flutter's Column/Row have none).
func _spaced(_ kids: [RNode], _ sp: Double, vertical: Bool) -> [Flutter.Widget] {
    var out: [Flutter.Widget] = []
    for (i, k) in kids.enumerated() {
        if i > 0 { out.append(vertical ? Flutter.SizedBox(height: sp) : Flutter.SizedBox(width: sp)) }
        out.append(toWidget(k))
    }
    return out
}

func toWidget(_ node: RNode) -> Flutter.Widget {
    switch node {
    case .text(let s, let color, let font, let bold, let lines, let italic):
        return Flutter.Text(s, style: TextStyle(color: colorFor(color), fontSize: fontSize(font),
                                                fontWeight: (bold || fontIsBold(font)) ? .w700 : .w400,
                                                fontStyle: italic ? .italic : nil),
                            maxLines: lines)
    case .empty:
        return Flutter.SizedBox(width: 0, height: 0)
    case .column(let sp, let al, let kids):
        // crossAxisAlignment from the VStack's HorizontalAlignment (al: 0 start/leading,
        // 1 center, 2 end/trailing). Never .stretch — that tight-forces children to the
        // column's cross-axis width, which is infinite whenever the column is nested where
        // width is unbounded (Column in ZStack in HStack) → Text children infinitely wide →
        // RenderStack's computedSize.isFinite assertion. .start/.center/.end all keep
        // intrinsic children finite (the column shrink-wraps to the widest), so they're safe.
        return Flutter.Column(mainAxisSize: .min, crossAxisAlignment: _crossAxis(al),
                              children: _spaced(kids, sp ?? 8, vertical: true))
    case .row(let sp, let al, let kids):
        // HStack's VerticalAlignment (top=0→start, center=1→center, bottom=2→end).
        return Flutter.Row(crossAxisAlignment: _crossAxis(al), children: _spaced(kids, sp ?? 8, vertical: false))
    case .grid(let cols, let kids):
        // LazyVGrid: chunk the items into rows of `cols`, each an HStack, stacked in a Column.
        let n = max(cols, 1)
        var rows: [Flutter.Widget] = []
        var i = 0
        while i < kids.count {
            if i > 0 { rows.append(Flutter.SizedBox(height: 8)) }
            let slice = Array(kids[i..<min(i + n, kids.count)])
            rows.append(Flutter.Row(mainAxisSize: .min, children: _spaced(slice, 12, vertical: false)))
            i += n
        }
        return Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .center, children: rows)
    case .picker(let label, let options, let sel, let ids):
        // Label + a segmented control: the selected option is highlighted; tapping one dispatches
        // its registered action (writes the option's tag back to the selection binding).
        if _firstPickerIds == nil { _firstPickerIds = ids }   // headless-test hook
        var seg: [Flutter.Widget] = []
        for (i, opt) in options.enumerated() {
            if i > 0 { seg.append(Flutter.SizedBox(width: 8)) }
            let item = Flutter.Padding(padding: EdgeInsets(horizontal: 10, vertical: 5), child: toWidget(opt))
            let styled: Flutter.Widget = i == sel
                ? Flutter.DecoratedBox(decoration: Flutter.BoxDecoration(
                    color: Color(0x330A84FF), borderRadius: BorderRadius.circular(6)), child: item)
                : item
            let id = i < ids.count ? ids[i] : -1
            seg.append(Flutter.GestureDetector(onTap: { if id >= 0 { _dispatch(id) } }, child: styled))
        }
        return Flutter.Row(mainAxisSize: .min, children: [
            toWidget(label), Flutter.SizedBox(width: 12), Flutter.Row(mainAxisSize: .min, children: seg),
        ])
    case .stack(let kids):
        return Flutter.Stack(alignment: Alignment.center, children: kids.map { toWidget($0) })
    case .list(let rows):
        // macOS-ish list: a scrollable column of rows, each inset, with hairline
        // separators between (a plain ScrollView+Column of the rows otherwise).
        var children: [Flutter.Widget] = []
        for (i, r) in rows.enumerated() {
            if i > 0 { children.append(Flutter.SizedBox(height: 1, child: Flutter.ColoredBox(color: Color(0xFF48484A)))) }
            children.append(Flutter.Padding(padding: EdgeInsets(horizontal: 16, vertical: 8), child: toWidget(r)))
        }
        return Flutter.SingleChildScrollView(child:
            Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .start, children: children))
    case .navStack(let root):
        // Empty stack → the root; otherwise the top pushed destination under a back bar.
        if navStack.isEmpty { return toWidget(root) }
        let backBar = Flutter.Row(children: [
            Flutter.PushButton(child: Flutter.Text("‹ Back",
                style: TextStyle(color: colorFor("blue"), fontSize: 15)),
                controlSize: .large, onPressed: { _navPop() }),
            Flutter.Expanded(child: Flutter.SizedBox(width: 0, height: 0)),
        ])
        return Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .start, children: [
            backBar, Flutter.SizedBox(height: 12), toWidget(navStack[navStack.count - 1]),
        ])
    case .navLink(let label, let dest):
        // A tappable link; tapping pushes the (eager) destination onto the nav stack.
        if _firstNavLinkDest == nil { _firstNavLinkDest = dest }   // headless-test hook
        return Flutter.Align(alignment: Alignment.centerLeft, child:
            Flutter.PushButton(child: toWidget(label), controlSize: .large, onPressed: { _navPush(dest) }))
    case .geometry(let id):
        // Resolve the GeometryReader: call back into SwiftUI with the available size (the
        // window's content size — correct for a root/full-bleed GR), then render the subtree
        // its closure produced. (Per-region size needs a real LayoutBuilder — a follow-up.)
        var w: Int32 = 0, h: Int32 = 0
        if let win = hostAppState?.window { glfwGetWindowSize(win, &w, &h) }
        let dw = w > 0 ? Double(w) : 720, dh = h > 0 ? Double(h) : 560
        guard let cstr = _geometry(id, dw, dh) else { return Flutter.SizedBox(width: 0, height: 0) }
        let json = String(cString: cstr); free(cstr)
        return toWidget(parseRNode(json))
    case .tabview(let labels, let pages):
        // A centered tab bar (selected tab highlighted) + the selected page. Selection is
        // host-side state (`selectedTab`), switched by tapping a tab item — mirrors navStack's
        // host-side push/pop (the .tabview node already carries every rendered page).
        _tabCount = labels.count
        let sel = pages.isEmpty ? 0 : min(max(selectedTab, 0), pages.count - 1)
        var bar: [Flutter.Widget] = []
        for (i, lbl) in labels.enumerated() {
            if i > 0 { bar.append(Flutter.SizedBox(width: 12)) }
            let item = Flutter.Padding(padding: EdgeInsets(horizontal: 12, vertical: 6), child: toWidget(lbl))
            let styled: Flutter.Widget = i == sel
                ? Flutter.DecoratedBox(decoration: Flutter.BoxDecoration(
                    color: Color(0x330A84FF), borderRadius: BorderRadius.circular(6)), child: item)
                : item
            bar.append(Flutter.GestureDetector(onTap: { _selectTab(i) }, child: styled))
        }
        let page = pages.indices.contains(sel) ? toWidget(pages[sel]) : Flutter.SizedBox(width: 0, height: 0)
        return Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .center, children: [
            Flutter.Row(mainAxisSize: .min, children: bar),
            Flutter.SizedBox(height: 16), page,
        ])
    case .scroll(let child):
        return Flutter.SingleChildScrollView(child: toWidget(child))
    case .padding(let len, let child):
        return Flutter.Padding(padding: EdgeInsets(all: len == 0 ? 20 : len), child: toWidget(child))
    case .spacer:
        return Flutter.Expanded(child: Flutter.SizedBox(width: 0, height: 0))
    case .divider:
        return Flutter.SizedBox(height: 1, child: Flutter.ColoredBox(color: Color(0xFF48484A)))
    case .image(let name, let color):
        return Flutter.Text(name == "star.fill" ? "★" : "◻︎",
            style: TextStyle(color: colorFor(color), fontSize: 18))
    case .colorBox(let name):
        return Flutter.ColoredBox(color: colorFor(name))
    case .linearGradient, .radialGradient, .angularGradient, .shaped, .stroked:
        // A bare paint (gradient or shape-clipped style) fills like Color, but a childless
        // DecoratedBox sizes to constraints.smallest (0×0), so expand it to fill.
        let box = Flutter.DecoratedBox(decoration: boxDecoration(for: node) ?? Flutter.BoxDecoration())
        return Flutter.SizedBox(width: Double.infinity, height: Double.infinity, child: box)
    case .frame(let w, let h, let child):
        // nil width = "fill available width" (SwiftUI Color/shape semantics).
        return Flutter.SizedBox(width: w ?? Double.infinity, height: h, child: toWidget(child))
    case .clip(let kind, let r, let child):
        // Clip the content to the shape. ClipOval covers circle (square box) + ellipse;
        // capsule ≈ a very large corner radius (clamped to half-height → stadium).
        switch kind {
        case "circle", "ellipse":
            return Flutter.ClipOval(child: toWidget(child))
        case "capsule":
            return Flutter.ClipRRect(borderRadius: BorderRadius.circular(9999), child: toWidget(child))
        case "rect":
            return Flutter.ClipRect(child: toWidget(child))
        default:  // roundedrect
            return Flutter.ClipRRect(borderRadius: BorderRadius.circular(r), child: toWidget(child))
        }
    case .background(let bg, let content):
        // .background(style): paint the style behind the content, sized to the content.
        // Color/gradient become a BoxDecoration on a DecoratedBox (exact SwiftUI sizing);
        // any other view falls back to a behind-stack. nil (unhandled style) → passthrough.
        guard let bg else { return toWidget(content) }
        if let deco = boxDecoration(for: bg) {
            return Flutter.DecoratedBox(decoration: deco, child: toWidget(content))
        }
        return Flutter.Stack(alignment: Alignment.center, children: [toWidget(bg), toWidget(content)])
    case .overlay(let content, let over, let al):
        // .overlay(style): paint the style (color/gradient) ON TOP of the content,
        // filling the content's bounds — a foreground DecoratedBox (symmetric to
        // .background). .overlay(view): stack the view on top at the requested alignment.
        if let deco = boxDecoration(for: over) {
            return Flutter.DecoratedBox(decoration: deco, position: .foreground, child: toWidget(content))
        }
        // The Stack sizes to the (larger) content and positions the overlay within its bounds
        // per `al` (h*3+v). The content fills the stack so its own alignment is a no-op.
        return Flutter.Stack(alignment: _overlayAlignment(al), children: [toWidget(content), toWidget(over)])
    case .fgcolor(_, let child):
        // foregroundColor is now folded into the leaf (image/text) by the _makeView
        // environment propagation upstream, so this is just a passthrough.
        return toWidget(child)
    case .button(let id, let label, let style):
        // .borderedProminent → filled accent chip; everything else keeps the stock look.
        if style == "BorderedProminentButtonStyle" {
            let chip = Flutter.DecoratedBox(
                decoration: Flutter.BoxDecoration(color: colorFor("blue"), borderRadius: BorderRadius.circular(6)),
                child: Flutter.Padding(padding: EdgeInsets(horizontal: 14, vertical: 6), child: toWidget(label)))
            return Flutter.Align(alignment: Alignment.centerRight, child:
                Flutter.GestureDetector(onTap: { _dispatch(id) }, child: chip))
        }
        return Flutter.Align(alignment: Alignment.centerRight, child:
            Flutter.PushButton(child: toWidget(label), controlSize: .large, onPressed: { _dispatch(id) }))
    case .toggle(let on, let label):
        return Flutter.Row(children: [
            Flutter.MacosCheckbox(value: on, onChanged: { _ in }),
            Flutter.SizedBox(width: 8), toWidget(label),
            Flutter.Expanded(child: Flutter.SizedBox(width: 0, height: 0)),
        ])
    case .textField(let text, let id, _):
        if _firstTextFieldId == nil && id >= 0 { _firstTextFieldId = id }
        return Flutter.MacosTextField(
            controller: TextEditingController(text: text),
            onSubmitted: { s in if id >= 0 { s.withCString { _dispatchText(id, $0) } } })
    case .slider(let value):
        return Flutter.MacosSlider(value: value, onChanged: { _ in })
    case .progress(let value):
        // Determinate bar: a gray track with a blue fill at `value` (0…1). Indeterminate
        // (nil value) → just the track (no spinner animation yet).
        let w = 200.0, h = 6.0
        let track = Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(color: Color(0xFF48484A), borderRadius: BorderRadius.circular(3)),
            child: Flutter.SizedBox(width: w, height: h))
        guard let v = value else { return track }
        let fill = Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(color: colorFor("blue"), borderRadius: BorderRadius.circular(3)),
            child: Flutter.SizedBox(width: w * min(max(v, 0), 1), height: h))
        return Flutter.Stack(alignment: Alignment.centerLeft, children: [track, fill])
    case .tappable(let id, let child):
        // .onTapGesture — same dispatch path as Button, no chrome.
        return Flutter.GestureDetector(onTap: { _dispatch(id) }, child: toWidget(child))
    case .draggable(let id, let child):
        // .gesture(DragGesture().onChanged): pan events → swiftui_compat_drag with the
        // current + drag-start positions (global coords; the compat scenes are windowed).
        return Flutter.GestureDetector(
            onPanStart: { details in
                _dragStarts[id] = (details.globalPosition.dx, details.globalPosition.dy)
            },
            onPanUpdate: { details in
                let start = _dragStarts[id] ?? (details.globalPosition.dx, details.globalPosition.dy)
                _dispatchDrag(id, details.globalPosition.dx, details.globalPosition.dy, start.0, start.1)
            },
            child: toWidget(child))
    case .opacity(let o, let child):
        return Flutter.Opacity(opacity: min(max(o, 0), 1), child: toWidget(child))
    case .offsetBy(let dx, let dy, let child):
        // Pure translation: anchor-independent, takes RenderTransform's no-layer fast path.
        return Flutter.Transform(transform: Matrix4.translationValues(dx, dy, 0), child: toWidget(child))
    case .rotate(let rad, let child):
        // Center-anchored like .scaleEffect → the same Align shrink-wrap (see .scale).
        return Flutter.Align(alignment: Alignment.topLeft, widthFactor: 1, heightFactor: 1,
                             child: Flutter.Transform(rotate: rad, child: toWidget(child)))
    case .blur(_, let child):
        // ImageFiltered/ImageFilterLayer doesn't paint in this compositor path yet —
        // render the content unblurred rather than blank (cosmetic gap).
        return toWidget(child)
    case .scale(let sx, let sy, let child):
        // SwiftUI anchors .scaleEffect at the VIEW's own bounds (default .center), so the
        // Transform box must shrink-wrap the child — under tight constraints (e.g. at the
        // root) a bare Transform would be window-sized and a centered anchor would fling
        // top-left content off-screen. Align(width/heightFactor: 1) is the layout-neutral
        // shrink-wrapper (sizes itself to the child under any constraints).
        return Flutter.Align(alignment: Alignment.topLeft, widthFactor: 1, heightFactor: 1,
                             child: Flutter.Transform(transform: Matrix4.diagonal3Values(sx, sy, 1),
                                                      alignment: Alignment.center,
                                                      child: toWidget(child)))
    case .shadow(let color, let r, let dx, let dy, let child):
        return Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(boxShadow: [
                BoxShadow(color: colorFor(color), offset: Offset(dx, dy), blurRadius: r),
            ]),
            child: toWidget(child))
    case .menu(let label, let items):
        // Dropdown: the label is a button-ish chip; tapping toggles the items panel below
        // (host state, like tab selection). Item taps dispatch their own registered actions.
        _hasMenu = true
        let head = Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(color: Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(6)),
            child: Flutter.Padding(padding: EdgeInsets(horizontal: 12, vertical: 6), child: toWidget(label)))
        let toggler = Flutter.GestureDetector(onTap: { _toggleMenu() }, child: head)
        guard _menuOpen else { return toggler }
        var rows: [Flutter.Widget] = []
        for (i, item) in items.enumerated() {
            if i > 0 { rows.append(Flutter.SizedBox(height: 4)) }
            rows.append(toWidget(item))
        }
        let panel = Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(color: Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
            child: Flutter.Padding(padding: EdgeInsets(horizontal: 10, vertical: 8),
                                   child: Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .start, children: rows)))
        return Flutter.Column(mainAxisSize: .min, crossAxisAlignment: .start, children: [
            toggler, Flutter.SizedBox(height: 4), panel,
        ])
    case .sheet(let id, let base, let content):
        // .sheet modal: base beneath a full-bleed scrim (tap = dismiss → binding false →
        // re-render without the sheet) and a centered rounded panel with the content.
        let scrim = Flutter.GestureDetector(onTap: { _dispatch(id) }, child:
            Flutter.SizedBox(width: Double.infinity, height: Double.infinity,
                             child: Flutter.ColoredBox(color: Color(0x99000000))))
        let panel = Flutter.DecoratedBox(
            decoration: Flutter.BoxDecoration(color: Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(12)),
            child: Flutter.Padding(padding: EdgeInsets(horizontal: 32, vertical: 24), child: toWidget(content)))
        return Flutter.Stack(alignment: Alignment.center, children: [toWidget(base), scrim, panel])
    case .stepper(let label, let dec, let inc):
        // Label + a − / + button pair; each tap dispatches the registered inc/dec closure
        // (which mutates the Binding → @State → re-render), exactly like a Button.
        return Flutter.Row(mainAxisSize: .min, children: [
            toWidget(label),
            Flutter.SizedBox(width: 12),
            Flutter.PushButton(child: toWidget(.text("−", color: nil, font: nil, bold: false)),
                               controlSize: .large, onPressed: { _dispatch(dec) }),
            Flutter.SizedBox(width: 6),
            Flutter.PushButton(child: toWidget(.text("+", color: nil, font: nil, bold: false)),
                               controlSize: .large, onPressed: { _dispatch(inc) }),
        ])
    }
}

// Cross-axis bucket (0 start, 1 center, 2 end) → Flutter CrossAxisAlignment.
func _crossAxis(_ a: Int) -> CrossAxisAlignment { a == 1 ? .center : (a == 2 ? .end : .start) }

// Packed overlay alignment (h*3+v, h/v each 0 leading/top, 1 center, 2 trailing/bottom) →
// Flutter Alignment(x, y) with x/y in -1…1 (left/top = -1, right/bottom = 1).
func _overlayAlignment(_ a: Int) -> Alignment {
    func axis(_ k: Int) -> Double { k == 0 ? -1 : (k == 2 ? 1 : 0) }
    return Alignment(axis(a / 3), axis(a % 3))
}

func parseRNode(_ json: String) -> RNode {
    guard let data = json.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .empty }
    return rnode(from: obj)
}

func rnode(from d: [String: Any]) -> RNode {
    func child(_ k: String) -> RNode { (d[k] as? [String: Any]).map { rnode(from: $0) } ?? .empty }
    func kids() -> [RNode] { (d["children"] as? [[String: Any]] ?? []).map { rnode(from: $0) } }
    func dbl(_ k: String) -> Double? { (d[k] as? NSNumber)?.doubleValue }
    func int(_ k: String) -> Int { (d[k] as? NSNumber)?.intValue ?? 0 }
    func str(_ k: String) -> String? { d[k] as? String }
    switch d["t"] as? String ?? "" {
    case "text": return .text(str("s") ?? "", color: str("color"), font: str("font"),
                              bold: d["bold"] as? Bool ?? false, lines: (d["lines"] as? NSNumber)?.intValue,
                              italic: d["italic"] as? Bool ?? false)
    case "grid": return .grid(int("cols"), kids())
    case "picker":
        let opts = (d["options"] as? [[String: Any]] ?? []).map { rnode(from: $0) }
        let ids = (d["ids"] as? [NSNumber] ?? []).map { $0.intValue }
        return .picker(child("label"), opts, int("sel"), ids)
    case "column": return .column(dbl("sp"), int("align"), kids())
    case "row": return .row(dbl("sp"), int("align"), kids())
    case "stack": return .stack(kids())
    case "list": return .list(kids())
    case "tabview":
        let labels = (d["labels"] as? [[String: Any]] ?? []).map { rnode(from: $0) }
        let pages = (d["pages"] as? [[String: Any]] ?? []).map { rnode(from: $0) }
        return .tabview(labels, pages)
    case "geometry": return .geometry((d["id"] as? NSNumber)?.intValue ?? 0)
    case "navstack": return .navStack(child("root"))
    case "navlink": return .navLink(child("label"), child("dest"))
    case "scroll": return .scroll(child("child"))
    case "padding": return .padding(dbl("len") ?? 16, child("child"))
    case "frame": return .frame(dbl("w"), dbl("h"), child("child"))
    case "clip": return .clip(str("kind") ?? "roundedrect", dbl("r") ?? 0, child("child"))
    case "background": return .background((d["bg"] as? [String: Any]).map { rnode(from: $0) }, child("child"))
    case "shaped": return .shaped(child("paint"), str("kind") ?? "rect", dbl("r") ?? 0)
    case "stroked": return .stroked(child("paint"), str("kind") ?? "rect", dbl("r") ?? 0, dbl("w") ?? 1)
    case "draggable": return .draggable(int("id"), child("child"))
    case "overlay": return .overlay(child("child"), child("over"), int("align"))
    case "fgcolor": return .fgcolor(str("color"), child("child"))
    case "spacer": return .spacer
    case "divider": return .divider
    case "image": return .image(str("name") ?? "", str("color"))
    case "colorbox": return .colorBox(str("name") ?? "")
    case "lineargradient":
        let cols = (d["colors"] as? [String]) ?? []
        return .linearGradient(cols, dbl("sx") ?? 0.5, dbl("sy") ?? 0, dbl("ex") ?? 0.5, dbl("ey") ?? 1)
    case "radialgradient":
        let cols = (d["colors"] as? [String]) ?? []
        return .radialGradient(cols, dbl("cx") ?? 0.5, dbl("cy") ?? 0.5, dbl("sr") ?? 0, dbl("er") ?? 0)
    case "angulargradient":
        let cols = (d["colors"] as? [String]) ?? []
        return .angularGradient(cols, dbl("cx") ?? 0.5, dbl("cy") ?? 0.5, dbl("sa") ?? 0, dbl("ea") ?? 0)
    case "button": return .button((d["id"] as? NSNumber)?.intValue ?? 0, child("child"), str("style"))
    case "toggle": return .toggle(d["on"] as? Bool ?? false, child("child"))
    case "textfield": return .textField(str("text") ?? "", int("id"), child("child"))
    case "slider": return .slider(dbl("value") ?? 0)
    case "progress": return .progress(dbl("value"))
    case "stepper": return .stepper(child("label"), int("dec"), int("inc"))
    case "tappable": return .tappable(int("id"), child("child"))
    case "sheet": return .sheet(int("id"), child("base"), child("content"))
    case "opacity": return .opacity(dbl("o") ?? 1, child("child"))
    case "scale": return .scale(dbl("sx") ?? 1, dbl("sy") ?? 1, child("child"))
    case "shadow": return .shadow(str("color") ?? "black", dbl("r") ?? 0, dbl("dx") ?? 0, dbl("dy") ?? 0, child("child"))
    case "menu":
        let items = (d["items"] as? [[String: Any]])?.map { rnode(from: $0) } ?? []
        return .menu(child("label"), items)
    case "offset": return .offsetBy(dbl("dx") ?? 0, dbl("dy") ?? 0, child("child"))
    case "rotate": return .rotate(dbl("rad") ?? 0, child("child"))
    case "blur": return .blur(dbl("r") ?? 0, child("child"))
    default: return .empty
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Stateful root widget (rebuilds on @State-driven updates)
// ════════════════════════════════════════════════════════════════════════════

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
        // Wake the GLFW loop so the scheduled frame is produced + presented now
        // (no window-nudge hack needed as on the macOS embedder — the Linux loop
        // is vsync/event driven).
        glfwPostEmptyEvent()
    }
    override func build(_ context: any BuildContext) -> Widget {
        // Dark macOS appearance + MacosTheme so the Macos* controls resolve their
        // theme; the ScrollView fills the window (no Center, which would shrink-wrap).
        return Flutter.Directionality(
            textDirection: .ltr,
            child: Flutter.MacosTheme(
                data: MacosThemeData.dark(),
                child: Flutter.ColoredBox(
                    color: Color(0xFF1E1E1E),
                    child: toWidget(node))))
    }
}
nonisolated(unsafe) var hostRootState: HostRootState?

// ════════════════════════════════════════════════════════════════════════════
// MARK: - C entry points (called from the SwiftUI module; tree crosses as JSON)
// ════════════════════════════════════════════════════════════════════════════

func hlog(_ s: String) { FileHandle.standardError.write(Data("[CompatHost] \(s)\n".utf8)) }

@_cdecl("swiftui_compat_run")
public func swiftui_compat_run(_ jsonPtr: UnsafePointer<CChar>) {
    pendingLock.lock(); navStack.removeAll(); selectedTab = 0; pendingLock.unlock()   // fresh app → empty nav stack, tab 0
    let json = String(cString: jsonPtr)
    if ProcessInfo.processInfo.environment["COMPAT_JSON"] != nil { hlog("json: \(json)") }
    runFlutterHost(root: parseRNode(json))
}

// NavigationStack push/pop is handled entirely host-side (destinations are eager — the navLink
// node already carries the rendered destination tree). The stack of pushed destinations lives
// here; tapping a link pushes, the back bar pops. Re-render by re-applying the current root
// (toWidget then reads the updated stack) through the same main-thread mailbox taps use.
nonisolated(unsafe) var navStack: [RNode] = []
nonisolated(unsafe) var _firstNavLinkDest: RNode?   // recorded for the headless MACHOLD_AUTOTAP test
nonisolated(unsafe) var _firstPickerIds: [Int]?     // first picker's per-option action ids (autotap)
// TabView selection (host-side, like navStack). Switched by tapping a tab item; re-render by
// re-applying the current root so toWidget reads the new index. _tabCount drives the autotap test.
nonisolated(unsafe) var selectedTab: Int = 0
nonisolated(unsafe) var _tabCount: Int = 0
func _selectTab(_ i: Int) {
    pendingLock.lock(); selectedTab = i; pendingNode = hostRootState?.node; pendingLock.unlock()
    glfwPostEmptyEvent()
}
// Menu open/close (single-menu host state, toggled by tapping the menu label).
nonisolated(unsafe) var _menuOpen = false
// Per-drag-id start positions (set on pan start, read by pan updates).
nonisolated(unsafe) var _dragStarts: [Int: (Double, Double)] = [:]
nonisolated(unsafe) var _hasMenu = false    // set when a menu rendered (autotap hook)
nonisolated(unsafe) var _firstTextFieldId: Int? = nil   // first editable text field (autotext hook)
func _toggleMenu() {
    pendingLock.lock(); _menuOpen.toggle(); pendingNode = hostRootState?.node; pendingLock.unlock()
    glfwPostEmptyEvent()
}
func _navPush(_ dest: RNode) {
    pendingLock.lock(); navStack.append(dest); pendingNode = hostRootState?.node; pendingLock.unlock()
    glfwPostEmptyEvent()
}
func _navPop() {
    pendingLock.lock(); if !navStack.isEmpty { navStack.removeLast() }; pendingNode = hostRootState?.node; pendingLock.unlock()
    glfwPostEmptyEvent()
}

// Mailbox for tree updates. swiftui_compat_update is invoked from whatever thread
// the SwiftUI action ran on — for a real tap that's the engine's UI thread, not the
// main/platform thread. Applying setState there would (correctly) trip
// MainActor.assumeIsolated. So just stash the node and let the main event loop drain
// and apply it (the same safe point the synthetic-tap path uses).
let pendingLock = NSLock()
nonisolated(unsafe) var pendingNode: RNode?

@_cdecl("swiftui_compat_update")
public func swiftui_compat_update(_ jsonPtr: UnsafePointer<CChar>) {
    let node = parseRNode(String(cString: jsonPtr))
    hlog("update; hostRootState set=\(hostRootState != nil)")
    pendingLock.lock(); pendingNode = node; pendingLock.unlock()
    glfwPostEmptyEvent()   // wake the loop to apply it promptly
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - GLFW + embedder engine boot
// ════════════════════════════════════════════════════════════════════════════

final class AppState: @unchecked Sendable {
    nonisolated(unsafe) var window: OpaquePointer? = nil
    nonisolated(unsafe) var resourceWindow: OpaquePointer? = nil
    nonisolated(unsafe) var engine: OpaquePointer? = nil
    nonisolated(unsafe) var pixelsPerScreenCoord: Double = 1.0
    nonisolated(unsafe) var pointerAdded = false
    nonisolated(unsafe) var pointerDown = false
    nonisolated(unsafe) var buttons: Int64 = 0
    nonisolated let taskQueue = FlutterTaskQueue()
    nonisolated let mainThreadPthread = pthread_self()
}
nonisolated(unsafe) var hostAppState: AppState?
nonisolated(unsafe) var presentCount = 0
let pixProof = ProcessInfo.processInfo.environment["MACHOLD_PIXPROOF"] != nil
let dumpPath = ProcessInfo.processInfo.environment["MACHOLD_DUMP"]

// glReadPixels the whole frame and write a binary PPM (P6), flipping vertically
// (GL's origin is bottom-left). Lets us inspect the actual rendering as an image.
func dumpFramebuffer(_ window: OpaquePointer?, to path: String) {
    guard let readPixels = glfwGetProcAddress("glReadPixels").map({ unsafeBitCast($0, to: GLReadPixels.self) })
    else { return }
    var w: Int32 = 0, h: Int32 = 0
    glfwGetFramebufferSize(window, &w, &h)
    guard w > 0, h > 0 else { return }
    let width = Int(w), height = Int(h)
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    rgba.withUnsafeMutableBytes { readPixels(0, 0, w, h, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, $0.baseAddress) }
    var ppm = Data("P6\n\(width) \(height)\n255\n".utf8)
    ppm.reserveCapacity(ppm.count + width * height * 3)
    for row in (0..<height).reversed() {            // flip: GL bottom-left → PPM top-left
        let base = row * width * 4
        for col in 0..<width {
            let p = base + col * 4
            ppm.append(rgba[p]); ppm.append(rgba[p + 1]); ppm.append(rgba[p + 2])
        }
    }
    try? ppm.write(to: URL(fileURLWithPath: path))
    hlog("dumped frame #\(presentCount) → \(path) (\(width)×\(height))")
}

// glReadPixels a center column of the just-rendered frame and report distinct
// colors found — proves Flutter actually rasterized the tree (light-gray bg
// 0xF5F5F7, blue button 0x0A84FF, dark text), independent of any window grab.
typealias GLReadPixels = @convention(c) (Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeMutableRawPointer?) -> Void
func sniffFramebuffer(_ window: OpaquePointer?) {
    guard let readPixels = glfwGetProcAddress("glReadPixels").map({ unsafeBitCast($0, to: GLReadPixels.self) })
    else { hlog("pixproof: glReadPixels unavailable"); return }
    var w: Int32 = 0, h: Int32 = 0
    glfwGetFramebufferSize(window, &w, &h)
    guard w > 0, h > 0 else { return }
    let cx = w / 2
    var colors: [UInt32: Int] = [:]
    var px = [UInt8](repeating: 0, count: 4)
    for frac in stride(from: 0.10, through: 0.90, by: 0.02) {
        let y = Int32(Double(h) * frac)
        px.withUnsafeMutableBytes { readPixels(cx, y, 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*GL_UNSIGNED_BYTE*/, $0.baseAddress) }
        colors[(UInt32(px[0]) << 16) | (UInt32(px[1]) << 8) | UInt32(px[2]), default: 0] += 1
    }
    let summary = colors.sorted { $0.value > $1.value }
        .map { String(format: "#%06X×%d", $0.key, $0.value) }.joined(separator: " ")
    hlog("pixproof (\(w)×\(h), center column): \(summary)")
}

final class FlutterTaskQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [(task: FlutterTask, targetNanos: UInt64)] = []
    func enqueue(_ task: FlutterTask, targetNanos: UInt64) {
        lock.lock(); tasks.append((task, targetNanos)); lock.unlock()
        glfwPostEmptyEvent()
    }
    func drainExpired() -> (expired: [(FlutterTask, UInt64)], nextNanos: UInt64?) {
        let now = FlutterEngineGetCurrentTime()
        lock.lock()
        var expired: [(FlutterTask, UInt64)] = []
        var remaining: [(task: FlutterTask, targetNanos: UInt64)] = []
        for entry in tasks {
            if entry.targetNanos <= now { expired.append((entry.task, entry.targetNanos)) }
            else { remaining.append(entry) }
        }
        tasks = remaining
        let nextNanos = remaining.map(\.targetNanos).min()
        lock.unlock()
        return (expired, nextNanos)
    }
}

func sendPointerEvent(_ state: AppState, phase: FlutterPointerPhase, x: Double, y: Double,
                      signalKind: FlutterPointerSignalKind = kFlutterPointerSignalKindNone,
                      scrollDeltaX: Double = 0, scrollDeltaY: Double = 0, buttons: Int64 = 0) {
    guard let engine = state.engine else { return }
    if !state.pointerAdded && phase != kAdd { sendPointerEvent(state, phase: kAdd, x: x, y: y) }
    if state.pointerAdded && phase == kAdd { return }
    var event = FlutterPointerEvent()
    event.struct_size = MemoryLayout<FlutterPointerEvent>.size
    event.phase = phase
    event.timestamp = Int(FlutterEngineGetCurrentTime() / 1000)
    event.x = x * state.pixelsPerScreenCoord
    event.y = y * state.pixelsPerScreenCoord
    event.device = 0
    event.signal_kind = signalKind
    event.scroll_delta_x = scrollDeltaX
    event.scroll_delta_y = scrollDeltaY
    event.device_kind = kFlutterPointerDeviceKindMouse
    event.buttons = buttons
    event.view_id = 0
    FlutterEngineSendPointerEvent(engine, &event, 1)
    switch phase {
    case kAdd: state.pointerAdded = true
    case kRemove: state.pointerAdded = false
    case kDown: state.pointerDown = true
    case kUp: state.pointerDown = false
    default: break
    }
}

func pointerPhaseForButtonState(_ state: AppState) -> FlutterPointerPhase {
    state.buttons == 0 ? (state.pointerDown ? kUp : kHover)
                       : (state.pointerDown ? kMove : kDown)
}

func getAppState(_ window: OpaquePointer?) -> AppState? {
    guard let window = window, let ptr = glfwGetWindowUserPointer(window) else { return nil }
    return Unmanaged<AppState>.fromOpaque(ptr).takeUnretainedValue()
}

let glfwFramebufferSizeCallback: @convention(c) (OpaquePointer?, Int32, Int32) -> Void = { window, widthPx, heightPx in
    guard let state = getAppState(window), let engine = state.engine else { return }
    var widthScreen: Int32 = 0
    glfwGetWindowSize(window, &widthScreen, nil)
    state.pixelsPerScreenCoord = widthScreen > 0 ? Double(widthPx) / Double(widthScreen) : 1.0
    var metrics = FlutterWindowMetricsEvent()
    metrics.struct_size = MemoryLayout<FlutterWindowMetricsEvent>.size
    metrics.width = Int(widthPx); metrics.height = Int(heightPx)
    metrics.pixel_ratio = state.pixelsPerScreenCoord; metrics.view_id = 0
    FlutterEngineSendWindowMetricsEvent(engine, &metrics)
}
let glfwCursorPosCallback: @convention(c) (OpaquePointer?, Double, Double) -> Void = { window, x, y in
    guard let state = getAppState(window) else { return }
    sendPointerEvent(state, phase: pointerPhaseForButtonState(state), x: x, y: y, buttons: state.buttons)
}
let glfwCursorEnterCallback: @convention(c) (OpaquePointer?, Int32) -> Void = { window, entered in
    guard let state = getAppState(window) else { return }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    sendPointerEvent(state, phase: entered != 0 ? kAdd : kRemove, x: x, y: y)
}
let glfwMouseButtonCallback: @convention(c) (OpaquePointer?, Int32, Int32, Int32) -> Void = { window, key, action, _ in
    guard let state = getAppState(window) else { return }
    let flutterButton: Int64
    switch key {
    case GLFW_MOUSE_BUTTON_LEFT:   flutterButton = Int64(kFlutterPointerButtonMousePrimary.rawValue)
    case GLFW_MOUSE_BUTTON_RIGHT:  flutterButton = Int64(kFlutterPointerButtonMouseSecondary.rawValue)
    case GLFW_MOUSE_BUTTON_MIDDLE: flutterButton = Int64(kFlutterPointerButtonMouseMiddle.rawValue)
    default: return
    }
    if action == GLFW_PRESS { state.buttons |= flutterButton } else { state.buttons &= ~flutterButton }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    sendPointerEvent(state, phase: pointerPhaseForButtonState(state), x: x, y: y, buttons: state.buttons)
}

func runFlutterHost(root: RNode) {
    MainActor.assumeIsolated {
        hlog("enter; root=\(root)")
        // Pick the GLFW backend explicitly. Default to Wayland (the visible GNOME
        // compositor on this box); GLFW's auto-detect otherwise falls back to an X11
        // server that may not be the desktop you're looking at. COMPAT_GLFW_PLATFORM
        // = wayland|x11|auto overrides. If the forced backend can't init, retry auto.
        let GLFW_PLATFORM = Int32(0x00050003)
        let GLFW_PLATFORM_WAYLAND = Int32(0x00060004), GLFW_PLATFORM_X11 = Int32(0x00060003)
        let GLFW_ANY_PLATFORM = Int32(0x00060000)
        let want = (ProcessInfo.processInfo.environment["COMPAT_GLFW_PLATFORM"] ?? "auto").lowercased()
        let hinted: Int32 = want == "x11" ? GLFW_PLATFORM_X11
                          : want == "auto" ? GLFW_ANY_PLATFORM : GLFW_PLATFORM_WAYLAND
        glfwInitHint(GLFW_PLATFORM, hinted)
        if glfwInit() == 0 {
            hlog("glfwInit() failed for \(want); retrying with auto-detect")
            glfwInitHint(GLFW_PLATFORM, GLFW_ANY_PLATFORM)
            guard glfwInit() != 0 else { fatalError("[CompatHost] glfwInit() failed") }
        }
        glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API)
        glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_EGL_CONTEXT_API)
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)

        let env = ProcessInfo.processInfo.environment
        let platform = glfwGetPlatform()
        let platformName = platform == 0x00060004 ? "Wayland"
                         : platform == 0x00060003 ? "X11"
                         : platform == 0x00060005 ? "NULL/headless" : "0x\(String(platform, radix: 16))"
        hlog("GLFW platform=\(platformName)  DISPLAY=\(env["DISPLAY"] ?? "<unset>")  WAYLAND_DISPLAY=\(env["WAYLAND_DISPLAY"] ?? "<unset>")")

        guard let mainWindow = glfwCreateWindow(720, 560, "SwiftUI → Flutter (binary-compat, Linux)", nil, nil) else {
            glfwTerminate(); fatalError("[CompatHost] glfwCreateWindow() failed")
        }
        glfwShowWindow(mainWindow)
        glfwWindowHint(GLFW_VISIBLE, 0)
        let resourceWindow = glfwCreateWindow(1, 1, "", nil, mainWindow)
        glfwWindowHint(GLFW_VISIBLE, 1)

        let appState = AppState()
        appState.window = mainWindow
        appState.resourceWindow = resourceWindow
        hostAppState = appState
        let statePtr = Unmanaged.passRetained(appState).toOpaque()
        glfwSetWindowUserPointer(mainWindow, statePtr)

        runApp(HostRootWidget(root))
        var callbacks = createRuntimeCallbacks()

        var rendererConfig = FlutterRendererConfig()
        rendererConfig.type = kOpenGL
        rendererConfig.open_gl.struct_size = MemoryLayout<FlutterOpenGLRendererConfig>.size
        rendererConfig.open_gl.make_current = { ud -> Bool in
            guard let ud = ud else { return false }
            glfwMakeContextCurrent(Unmanaged<AppState>.fromOpaque(ud).takeUnretainedValue().window); return true
        }
        rendererConfig.open_gl.clear_current = { _ -> Bool in glfwMakeContextCurrent(nil); return true }
        rendererConfig.open_gl.present = { ud -> Bool in
            guard let ud = ud else { return false }
            let st = Unmanaged<AppState>.fromOpaque(ud).takeUnretainedValue()
            presentCount += 1
            // Objective render proof (no screenshot tool on this box): before the
            // swap, sample the just-rendered back buffer for our known colors, and
            // optionally dump the whole frame to a PPM so the rendering can be
            // inspected as an image regardless of Wayland window visibility.
            if pixProof && presentCount <= 3 { sniffFramebuffer(st.window) }
            if let dumpPath = dumpPath, presentCount <= 4 { dumpFramebuffer(st.window, to: dumpPath) }
            glfwSwapBuffers(st.window)
            if presentCount <= 3 || presentCount % 60 == 0 { hlog("present #\(presentCount)") }
            return true
        }
        rendererConfig.open_gl.fbo_callback = { _ -> UInt32 in 0 }
        rendererConfig.open_gl.make_resource_current = { ud -> Bool in
            guard let ud = ud else { return false }
            glfwMakeContextCurrent(Unmanaged<AppState>.fromOpaque(ud).takeUnretainedValue().resourceWindow); return true
        }
        rendererConfig.open_gl.gl_proc_resolver = { _, name -> UnsafeMutableRawPointer? in
            guard let name = name, let fn = glfwGetProcAddress(name) else { return nil }
            return unsafeBitCast(fn, to: UnsafeMutableRawPointer.self)
        }

        var platformTaskRunner = FlutterTaskRunnerDescription()
        platformTaskRunner.struct_size = MemoryLayout<FlutterTaskRunnerDescription>.size
        platformTaskRunner.user_data = statePtr
        platformTaskRunner.runs_task_on_current_thread_callback = { ud -> Bool in
            guard let ud = ud else { return false }
            let s = Unmanaged<AppState>.fromOpaque(ud).takeUnretainedValue()
            return pthread_equal(pthread_self(), s.mainThreadPthread) != 0
        }
        platformTaskRunner.post_task_callback = { task, targetTimeNanos, ud in
            guard let ud = ud else { return }
            Unmanaged<AppState>.fromOpaque(ud).takeUnretainedValue().taskQueue.enqueue(task, targetNanos: targetTimeNanos)
        }
        var taskRunners = FlutterCustomTaskRunners()
        taskRunners.struct_size = MemoryLayout<FlutterCustomTaskRunners>.size

        // Assets/ICU: absolute paths via env (machold runs from macos-compat/linux,
        // so relative engine paths wouldn't resolve). Swift mode ignores assets.
        let engineOut = ProcessInfo.processInfo.environment["COMPAT_ENGINE_OUT"]
            ?? "../../../engine/src/out/host_debug"
        var args = FlutterProjectArgs()
        args.struct_size = MemoryLayout<FlutterProjectArgs>.size
        let assetsPath = strdup("\(engineOut)/flutter_assets")!
        let icuPath = strdup("\(engineOut)/icudtl.dat")!
        args.assets_path = UnsafePointer(assetsPath)
        args.icu_data_path = UnsafePointer(icuPath)
        let argv0 = strdup("CompatHost")!
        let argv1 = strdup("--enable-impeller=false")!
        let argvBuf = UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: 3)
        argvBuf[0] = UnsafePointer(argv0); argvBuf[1] = UnsafePointer(argv1); argvBuf[2] = nil
        args.command_line_argc = 2
        args.command_line_argv = UnsafePointer(argvBuf.baseAddress!)

        var engine: OpaquePointer? = nil
        let initResult = withUnsafeMutablePointer(to: &callbacks) { cbPtr in
            withUnsafeMutablePointer(to: &platformTaskRunner) { trPtr in
                taskRunners.platform_task_runner = UnsafePointer(trPtr)
                return withUnsafeMutablePointer(to: &taskRunners) { trsPtr in
                    args.custom_task_runners = UnsafePointer(trsPtr)
                    return FlutterEngineInitializeSwift(Int(FLUTTER_ENGINE_VERSION),
                        &rendererConfig, &args, statePtr, UnsafeRawPointer(cbPtr), &engine)
                }
            }
        }
        guard initResult == kSuccess, let engine = engine else {
            glfwTerminate(); fatalError("[CompatHost] FlutterEngineInitializeSwift failed")
        }
        appState.engine = engine
        guard FlutterEngineRunInitializedSwift(engine) == kSuccess else {
            glfwTerminate(); fatalError("[CompatHost] FlutterEngineRunInitializedSwift failed")
        }
        hlog("engine running")

        glfwSetFramebufferSizeCallback(mainWindow, glfwFramebufferSizeCallback)
        glfwSetCursorPosCallback(mainWindow, glfwCursorPosCallback)
        glfwSetCursorEnterCallback(mainWindow, glfwCursorEnterCallback)
        glfwSetMouseButtonCallback(mainWindow, glfwMouseButtonCallback)

        var widthPx: Int32 = 0, heightPx: Int32 = 0
        glfwGetFramebufferSize(mainWindow, &widthPx, &heightPx)
        glfwFramebufferSizeCallback(mainWindow, widthPx, heightPx)
        PlatformDispatcher.instance.scheduleFrame()
        hlog("entering GLFW event loop")

        // Headless verification of the interaction loop (no clickable window here):
        // with MACHOLD_AUTOTAP, once the first frame is on screen, synthesise a tap
        // on button 0 — same call the GestureDetector makes — to drive the full
        // path (SwiftUI action → @State → re-walk → update → rebuild → re-present).
        let autoTap = ProcessInfo.processInfo.environment["MACHOLD_AUTOTAP"] != nil
        let autoText = ProcessInfo.processInfo.environment["MACHOLD_AUTOTEXT"]   // text to inject into the 1st field
        var loopIter = 0, tapped = false

        while glfwWindowShouldClose(mainWindow) == 0 {
            // Apply any tree update enqueued from a tap or an async invalidate (on the
            // main thread, here, outside engine task processing — avoids cross-thread
            // setState). Only POP once the root widget has mounted: an early update
            // (e.g. a fast `.task` firing before the first build) must stay stashed,
            // not be consumed into hostRootState? = nil and dropped.
            pendingLock.lock()
            var pend: RNode? = nil
            if hostRootState != nil { pend = pendingNode; pendingNode = nil }
            pendingLock.unlock()
            if let pend = pend { hostRootState?.apply(pend) }

            let (expired, nextNanos) = appState.taskQueue.drainExpired()
            for (task, _) in expired { var mt = task; FlutterEngineRunTask(engine, &mt) }
            Foundation.RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.001))
            loopIter += 1
            if (autoTap || autoText != nil) && !tapped && presentCount >= 1 && loopIter > 5 {
                tapped = true
                if let t = autoText, let fid = _firstTextFieldId {   // text-field probe → inject text
                    hlog("AUTOTEXT → field \(fid) = \(t)")
                    t.withCString { _dispatchText(fid, $0) }
                } else if let dest = _firstNavLinkDest {       // NavigationLink probe → push the first link
                    hlog("AUTOTAP → navPush(first link)")
                    _navPush(dest)
                } else if _tabCount >= 2 {              // TabView probe → switch to the 2nd tab
                    hlog("AUTOTAP → selectTab(1)")
                    _selectTab(1)
                } else if let ids = _firstPickerIds, ids.count >= 2 {
                    hlog("AUTOTAP → picker option 2 (id \(ids[1]))")   // → writes its tag to the selection
                    _dispatch(ids[1])
                } else if _hasMenu {                    // Menu probe → open the dropdown
                    hlog("AUTOTAP → toggle menu")
                    _toggleMenu()
                } else {
                    hlog("AUTOTAP → dispatch(0)")
                    _dispatch(0)
                }
            }
            if let nextNanos = nextNanos {
                let now = FlutterEngineGetCurrentTime()
                if nextNanos > now {
                    glfwWaitEventsTimeout(min(Double(nextNanos - now) / 1_000_000_000.0, 0.016))
                } else { glfwPollEvents() }
            } else { glfwWaitEventsTimeout(0.016) }
        }
        FlutterEngineShutdown(engine)
        glfwTerminate()
    }
}
