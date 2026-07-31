// The faithful render path: SwiftUI's real View._makeView recursion, driven through
// the View witness tables (verified by the spike — the unmodified binary's custom
// views bind their _makeView slot to our default, which evaluates `body` and recurses).
// This replaces the Mirror-based reflection in Reflect.swift: composites, modifiers,
// and controls all render via witness dispatch; only TupleView/ForEach flattening
// still uses Mirror (no Apple variadic machinery to reuse). Output is a RenderNode
// tree that FlutterBridge serialises to the same JSON the host already renders.

import Foundation

// Fully-rendered tree (mirrors the host's RNode; the closure on .button is the
// SwiftUI action to fire on tap).
public indirect enum RenderNode {
    case text(String, color: String?, font: String?, bold: Bool, lines: Int? = nil, italic: Bool = false)
    case empty, spacer, divider
    case image(String, color: String?), colorBox(String)
    case linearGradient([String], sx: CGFloat, sy: CGFloat, ex: CGFloat, ey: CGFloat)  // colorNames + start/end unit points
    case radialGradient([String], cx: CGFloat, cy: CGFloat, startRadius: CGFloat, endRadius: CGFloat)
    case angularGradient([String], cx: CGFloat, cy: CGFloat, startAngle: CGFloat, endAngle: CGFloat)  // angles in radians
    // vstack/hstack carry a cross-axis alignment: 0 = start (leading/top), 1 = center, 2 = end
    // (trailing/bottom) — see `_crossAxis`. The host maps it to Flutter's CrossAxisAlignment.
    case vstack(CGFloat?, Int, [RenderNode]), hstack(CGFloat?, Int, [RenderNode]), zstack([RenderNode])
    case list([RenderNode])
    case tabview([RenderNode], [RenderNode])     // (tab labels, tab pages) — parallel arrays
    case geometryReader(Int)                     // id of the registered GR closure (resolved by the host with a size)
    case navStack(RenderNode)                    // NavigationStack root content
    case navLink(RenderNode, RenderNode)         // (label, eager destination) — tapping the label pushes the destination
    case scroll(RenderNode), padding(CGFloat?, RenderNode)
    case frame(CGFloat?, CGFloat?, RenderNode), clip(String, CGFloat, RenderNode)  // (shapeKind, cornerRadius, content)
    case background(RenderNode?, RenderNode)     // (background paint node — Color/gradient/…, content)
    case shaped(RenderNode, shapeKind: String, cornerRadius: CGFloat)  // a paint node clipped to a shape (for .background/.overlay(_:in:))
    case overlay(RenderNode, RenderNode, Int)   // (content, overlay, alignment h*3+v) — overlay drawn on top
    case button(() -> Void, RenderNode, style: String? = nil), toggle(Bool, RenderNode), textField(String, RenderNode), slider(Double)
    case progress(CGFloat?)                      // determinate fraction 0…1, or nil = indeterminate
    case stepper(RenderNode, () -> Void, () -> Void)   // (label, onDecrement, onIncrement)
    case grid(Int, [RenderNode])                       // (column count, flattened items)
    case picker(RenderNode, [RenderNode], Int, [() -> Void])   // (label, option labels, selected idx, per-option select actions)
    case tappable(() -> Void, RenderNode)              // .onTapGesture — content wrapped in a tap target
    case sheet(() -> Void, RenderNode, RenderNode)     // (.sheet dismiss action, base, presented content)
    case opacity(Double, RenderNode)                   // .opacity
    case scale(Double, Double, RenderNode)             // .scaleEffect (sx, sy)
    case shadow(String, CGFloat, CGFloat, CGFloat, RenderNode)  // .shadow (colorName, radius, dx, dy)
    case menu(RenderNode, [RenderNode])                // Menu (label, items) — host expands on tap
    case offsetBy(Double, Double, RenderNode)          // .offset (dx, dy)
    case rotate(Double, RenderNode)                    // .rotationEffect (radians, center-anchored)
    case blur(Double, RenderNode)                      // .blur (radius)
    case stroked(RenderNode, shapeKind: String, cornerRadius: CGFloat, width: CGFloat)  // shape OUTLINE in a paint
    case draggable((DragGesture.Value) -> Void, RenderNode)   // .gesture(DragGesture().onChanged) — host pan events
}
// Modifiers that render as their content (no host effect yet / by design).
protocol _AnyPassthroughModifier {}

// Render the children of a container: flatten TupleView/ForEach/Group (Mirror/expand),
// then _makeView each via witness dispatch.
func _childNodes(_ content: any View, _ inputs: _ViewInputs) -> [RenderNode] {
    _stackChildren(content).map { $0._mvErased(inputs).node }
}

// ── Leaf views ───────────────────────────────────────────────────────────────
extension Text {
    public static func _makeView(view: _GraphValue<Text>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let t = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.text(t._resolvedString,
            color: t._resolvedColor?._name ?? inputs.fgColor,
            font: t._resolvedFont?._name, bold: (t._resolvedWeight?.value ?? 0) >= 0.4,
            lines: inputs.env.lineLimit, italic: t._resolvedItalic))
    }
}
extension EmptyView {
    public static func _makeView(view: _GraphValue<EmptyView>, inputs: _ViewInputs) -> _ViewOutputs { _ViewOutputs(.empty) }
}
// if/else: render whichever branch the app selected.
extension _ConditionalContent where TrueContent: View, FalseContent: View {
    public static func _makeView(view: _GraphValue<_ConditionalContent>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        switch v.storage {
        case .trueContent(let t):  return _ViewOutputs(t._mvErased(inputs).node)
        case .falseContent(let f): return _ViewOutputs(f._mvErased(inputs).node)
        }
    }
}
// if (no else): render the wrapped view, or nothing when nil.
extension Optional where Wrapped: View {
    public static func _makeView(view: _GraphValue<Optional<Wrapped>>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value, let w = v else { return _ViewOutputs(.empty) }
        return _ViewOutputs(w._mvErased(inputs).node)
    }
}
extension Spacer {
    public static func _makeView(view: _GraphValue<Spacer>, inputs: _ViewInputs) -> _ViewOutputs { _ViewOutputs(.spacer) }
}
extension Divider {
    public static func _makeView(view: _GraphValue<Divider>, inputs: _ViewInputs) -> _ViewOutputs { _ViewOutputs(.divider) }
}
extension Image {
    public static func _makeView(view: _GraphValue<Image>, inputs: _ViewInputs) -> _ViewOutputs {
        _ViewOutputs(.image(view._value?._systemName ?? "", color: inputs.fgColor))
    }
}
extension Color {
    public static func _makeView(view: _GraphValue<Color>, inputs: _ViewInputs) -> _ViewOutputs {
        _ViewOutputs(.colorBox(view._value?._name ?? "primary"))
    }
}
// Label renders as an HStack of [icon, title] (centered, small gap) — the standard SwiftUI layout.
extension Label {
    public static func _makeView(view: _GraphValue<Label>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.hstack(6, 1, [v.icon._mvErased(inputs).node, v.title._mvErased(inputs).node]))
    }
}
// ProgressView → a determinate bar at fraction value/total (nil value ⇒ indeterminate).
extension ProgressView {
    public static func _makeView(view: _GraphValue<ProgressView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let frac: CGFloat? = v.value.map { v.total > 0 ? CGFloat($0 / v.total) : 0 }
        return _ViewOutputs(.progress(frac))
    }
}
// Stepper → label + −/+ controls; the inc/dec closures (built from the Binding) are registered as
// tap actions by FlutterBridge (like buttons), so tapping mutates the binding → @State → re-render.
extension Stepper {
    public static func _makeView(view: _GraphValue<Stepper>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.stepper(v.label._mvErased(inputs).node, v.onDecrement ?? {}, v.onIncrement ?? {}))
    }
}
// LinearGradient is a greedy leaf (fills offered space, like Color). Emit its stop
// colors + start/end unit points; the host paints them via a DecoratedBox gradient.
extension LinearGradient {
    public static func _makeView(view: _GraphValue<LinearGradient>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.linearGradient(v.gradient._colorNames,
            sx: v.startPoint.x, sy: v.startPoint.y, ex: v.endPoint.x, ey: v.endPoint.y))
    }
}
extension RadialGradient {
    public static func _makeView(view: _GraphValue<RadialGradient>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.radialGradient(v.gradient._colorNames,
            cx: v.center.x, cy: v.center.y, startRadius: v.startRadius, endRadius: v.endRadius))
    }
}
extension AngularGradient {
    public static func _makeView(view: _GraphValue<AngularGradient>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.angularGradient(v.gradient._colorNames,
            cx: v.center.x, cy: v.center.y, startAngle: v.startAngle.radians, endAngle: v.endAngle.radians))
    }
}

// ── Containers ───────────────────────────────────────────────────────────────
// Map a Horizontal/VerticalAlignment.key (leading/top=0, center=1, trailing/bottom=2, text
// baselines=3/4) to the cross-axis bucket the host understands (0 start, 1 center, 2 end);
// baselines fall back to start.
func _crossAxis(_ key: Int) -> Int { key == 1 ? 1 : (key == 2 ? 2 : 0) }

extension VStack {
    public static func _makeView(view: _GraphValue<VStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.vstack(v.spacing, _crossAxis(v.alignment.key), _childNodes(v.content, inputs)))
    }
}
extension HStack {
    public static func _makeView(view: _GraphValue<HStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.hstack(v.spacing, _crossAxis(v.alignment.key), _childNodes(v.content, inputs)))
    }
}
extension ZStack {
    public static func _makeView(view: _GraphValue<ZStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.zstack(_childNodes(v.content, inputs)))
    }
}
extension Group where Content: View {
    public static func _makeView(view: _GraphValue<Group>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.vstack(nil, 0, _childNodes(v.content, inputs)))
    }
}
extension ScrollView {
    public static func _makeView(view: _GraphValue<ScrollView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.scroll(v.content._mvErased(inputs).node))
    }
}
extension ForEach where Content: View {
    public static func _makeView(view: _GraphValue<ForEach>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.vstack(nil, 0, v._expanded.map { $0._mvErased(inputs).node }))
    }
}
// Lazy stacks: perf variants of VStack/HStack — render identically.
extension LazyVStack {
    public static func _makeView(view: _GraphValue<LazyVStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.vstack(v.spacing, 1, _childNodes(v.content, inputs)))   // Apple LazyVStack default: .center
    }
}
extension LazyVGrid {
    public static func _makeView(view: _GraphValue<LazyVGrid>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.grid(max(v.columns.count, 1), _childNodes(v.content, inputs)))
    }
}
// `.tag` extraction: a tag modifier exposes its value as AnyHashable; a tagged option (a
// ModifiedContent whose modifier is one) yields its rendered label + that tag. BOTH `.tag`
// forms occur at runtime: machold reports every #available(macOS 26) as FALSE (see
// machold_os_version_atleast in machold.c), so the binary constructs — and the .tag opaque
// descriptor's kind-9 accessors resolve — the LEGACY _TraitWritingModifier<TagValueTraitKey<V?>>;
// the modern _TagTraitWritingModifier is kept for binding and for any TRUE-convention future.
protocol _AnyTagProvider { var _pickerTag: AnyHashable? { get } }
extension _TagTraitWritingModifier: _AnyTagProvider { var _pickerTag: AnyHashable? { AnyHashable(tag) } }
protocol _AnyTagTraitValue { var _tagValue: AnyHashable? { get } }
extension TagValueTraitKey.Value: _AnyTagTraitValue {
    var _tagValue: AnyHashable? {
        guard case .tagged(let v) = self else { return nil }
        // The legacy lowering of `.tag(x)` is TagValueTraitKey<Optional<V>> with .tagged(.some(x));
        // unwrap so the tag compares equal to the (non-optional) selection value.
        let m = Mirror(reflecting: v)
        if m.displayStyle == .optional {
            guard let inner = m.children.first?.value else { return nil }   // .some(nil) → untagged
            return (inner as? any Hashable).map { AnyHashable($0) }
        }
        return AnyHashable(v)
    }
}
extension _TraitWritingModifier: _AnyTagProvider {
    var _pickerTag: AnyHashable? { (value as? _AnyTagTraitValue)?._tagValue }
}
protocol _AnyTaggedOption { func _labelAndTag(_ inputs: _ViewInputs) -> (RenderNode, AnyHashable?) }
extension ModifiedContent: _AnyTaggedOption where Content: View, Modifier: _AnyTagProvider {
    func _labelAndTag(_ inputs: _ViewInputs) -> (RenderNode, AnyHashable?) {
        (content._mvErased(inputs).node, modifier._pickerTag)
    }
}
// Picker → label + a segmented control of the (tagged) options; the selected option is the one
// whose tag == selection.wrappedValue, and tapping an option writes its tag back to the binding.
extension Picker {
    public static func _makeView(view: _GraphValue<Picker>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let cur = AnyHashable(v.selection.wrappedValue)
        var options: [RenderNode] = [], actions: [() -> Void] = [], selected = 0
        for (i, opt) in _stackChildren(v.content).enumerated() {
            let labelNode: RenderNode, tag: AnyHashable?
            if let tagged = opt as? _AnyTaggedOption { (labelNode, tag) = tagged._labelAndTag(inputs) }
            else { labelNode = opt._mvErased(inputs).node; tag = nil }
            options.append(labelNode)
            if let tag = tag, tag == cur { selected = i }
            actions.append({ if let t = tag?.base as? SelectionValue { v.selection.wrappedValue = t } })
        }
        return _ViewOutputs(.picker(v.label._mvErased(inputs).node, options, selected, actions))
    }
}
extension LazyHStack {
    public static func _makeView(view: _GraphValue<LazyHStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.hstack(v.spacing, 1, _childNodes(v.content, inputs)))   // Apple LazyHStack default: .center
    }
}
// List: scrollable column of rows (host adds row insets + separators).
extension List {
    public static func _makeView(view: _GraphValue<List>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.list(_childNodes(v.content, inputs)))
    }
}
// NavigationStack: render the root (the host shows it, or a pushed destination + back bar).
extension NavigationStack {
    public static func _makeView(view: _GraphValue<NavigationStack>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.navStack(v.root._mvErased(inputs).node))
    }
}
// NavigationLink: emit (label, eager-rendered destination); the host pushes the destination on tap.
extension NavigationLink {
    public static func _makeView(view: _GraphValue<NavigationLink>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.navLink(v.label._mvErased(inputs).node, v.destination._mvErased(inputs).node))
    }
}
// GeometryReader: can't run its body during the (size-less) walk — register the closure and
// emit a placeholder; the host calls back with the available size (see FlutterBridge).
extension GeometryReader {
    public static func _makeView(view: _GraphValue<GeometryReader>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let id = _registerGeometry { w, h in
            v.content(GeometryProxy(size: CGSize(width: w, height: h)))._mvErased(inputs).node
        }
        return _ViewOutputs(.geometryReader(id))
    }
}
// _TabItemView on its own renders as its page content (the label only matters in a TabView).
extension _TabItemView {
    public static func _makeView(view: _GraphValue<_TabItemView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(v.content._mvErased(inputs).node)
    }
}
// TabView: flatten the content into tabs, pulling each tab's page + label via _AnyTabItem
// (a tab without .tabItem gets a blank label). Host draws a tab bar + the selected page.
extension TabView {
    public static func _makeView(view: _GraphValue<TabView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        var labels: [RenderNode] = [], pages: [RenderNode] = []
        for tab in _stackChildren(v.content) {
            if let ti = tab as? _AnyTabItem {
                labels.append(ti._tabLabel(inputs)); pages.append(ti._tabPage(inputs))
            } else {
                labels.append(.empty); pages.append(tab._mvErased(inputs).node)
            }
        }
        return _ViewOutputs(.tabview(labels, pages))
    }
}

// ── Controls (read their @State binding) ─────────────────────────────────────
extension Button {
    public static func _makeView(view: _GraphValue<Button>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        // .disabled(true) upstream → isEnabled false → the tap becomes a no-op.
        let action = inputs.env.isEnabled ? v.action : {}
        return _ViewOutputs(.button(action, v.label._mvErased(inputs).node, style: inputs.env._buttonStyle))
    }
}
// .buttonStyle: thread the style name down the environment for the subtree's Buttons.
extension _ButtonStyledView {
    public static func _makeView(view: _GraphValue<_ButtonStyledView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        var i = inputs
        i.env._buttonStyle = v.styleName
        return v.content._mvErased(i)
    }
}
extension Toggle {
    public static func _makeView(view: _GraphValue<Toggle>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.toggle(v.isOn.wrappedValue, v.label._mvErased(inputs).node))
    }
}
extension TextField {
    public static func _makeView(view: _GraphValue<TextField>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.textField(v.text.wrappedValue, v.label._mvErased(inputs).node))
    }
}
extension Slider {
    public static func _makeView(view: _GraphValue<Slider>, inputs: _ViewInputs) -> _ViewOutputs {
        _ViewOutputs(.slider(view._value?.value.wrappedValue ?? 0))
    }
}

// ── Modifiers (ModifiedContent) ──────────────────────────────────────────────
extension ModifiedContent where Content: View, Modifier: ViewModifier {
    public static func _makeView(view: _GraphValue<ModifiedContent>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        if let p = v.modifier as? _PaddingLayout {
            // insets is EdgeInsets? (Apple's layout); use .top as the representative pad.
            return _ViewOutputs(.padding(p.insets?.top, v.content._mvErased(inputs).node))
        }
        if let f = v.modifier as? _FrameLayout {
            return _ViewOutputs(.frame(f.width, f.height, v.content._mvErased(inputs).node))
        }
        if let ff = v.modifier as? _FlexFrameLayout {
            // .frame(maxWidth:.infinity) → fill width (nil ⇒ host fills); finite max ⇒
            // approximated as a fixed dimension. maxHeight .infinity ⇒ intrinsic (nil).
            func dim(_ m: CGFloat?) -> CGFloat? {
                guard let m, m.isFinite else { return nil }
                return m
            }
            return _ViewOutputs(.frame(dim(ff.maxWidth), dim(ff.maxHeight),
                                       v.content._mvErased(inputs).node))
        }
        if let clip = v.modifier as? _AnyClipEffect {
            // .cornerRadius / .clipShape(anyShape) — clip the content to the shape.
            return _ViewOutputs(.clip(clip._clipKind, clip._clipCornerRadius, v.content._mvErased(inputs).node))
        }
        if let bg = v.modifier as? _AnyBackgroundModifier {
            return _ViewOutputs(.background(bg._bgNode(inputs), v.content._mvErased(inputs).node))
        }
        if let ov = v.modifier as? _AnyOverlayModifier {
            return _ViewOutputs(.overlay(v.content._mvErased(inputs).node, ov._overlayNode(inputs), ov._overlayAlign))
        }
        if let op = v.modifier as? _OpacityEffect {
            return _ViewOutputs(.opacity(op.opacity, v.content._mvErased(inputs).node))
        }
        if let sc = v.modifier as? _ScaleEffect {
            return _ViewOutputs(.scale(sc.scale.width, sc.scale.height, v.content._mvErased(inputs).node))
        }
        if let sh = v.modifier as? _ShadowEffect {
            return _ViewOutputs(.shadow(sh.color._name, sh.radius, sh.offset.width, sh.offset.height,
                                        v.content._mvErased(inputs).node))
        }
        if let off = v.modifier as? _OffsetEffect {
            return _ViewOutputs(.offsetBy(off.offset.width, off.offset.height, v.content._mvErased(inputs).node))
        }
        if let rot = v.modifier as? _RotationEffect {
            return _ViewOutputs(.rotate(rot.angle.radians, v.content._mvErased(inputs).node))
        }
        if let bl = v.modifier as? _BlurEffect {
            return _ViewOutputs(.blur(bl.radius, v.content._mvErased(inputs).node))
        }
        if v.modifier is _FixedSizeLayout || v.modifier is _SafeAreaRegionsIgnoringLayout
            || v.modifier is _HoverRegionModifier || v.modifier is _AnyPassthroughModifier {
            // fixedSize: the host shrink-wraps intrinsics already; safe areas don't exist
            // in this window; hover isn't routed; animations snap.
            return v.content._mvErased(inputs)
        }
        if let w = v.modifier as? _AnyEnvWriter {
            // Environment write (.foregroundColor / .environment / .environmentObject):
            // apply the stored keypath to a copy of the inherited environment — the
            // subtree sees the updated values (COPY: siblings are unaffected). fgColor
            // stays mirrored as the fast-path field the leaf renderers read.
            var i = inputs
            w._write(into: &i.env)
            if let c = i.env.foregroundColor { i.fgColor = c._name }
            return v.content._mvErased(i)
        }
        if let task = v.modifier as? _TaskModifier {
            // .task: fire the async action ONCE per appearance (keyed by the closure fn
            // pointer, the .onAppear convention), after the content renders. The action
            // runs on the concurrency runtime; its @State/@Published mutations re-render
            // through the (thread-mailboxed) invalidate path.
            let node = v.content._mvErased(inputs).node
            let key = unsafeBitCast(task.action, to: (UInt, UInt).self).0
            if !_appearedFired.contains(key) {
                _appearedFired.insert(key)
                let action = task.action
                Task { await action() }
            }
            return _ViewOutputs(node)
        }
        if let appear = v.modifier as? _AppearanceActionModifier {
            // .onAppear/.onDisappear: render the wrapped content, then fire `appear` ONCE per
            // appearance (keyed by the closure fn pointer). The closure often mutates @Published
            // or sets up a `.sink` — any resulting invalidation is deferred (we're mid-walk) and
            // settled afterwards. Content is rendered first so the first frame shows the pre-onAppear
            // value, then the settle pass reflects the mutation (Apple-like ordering).
            let node = v.content._mvErased(inputs).node
            if let fn = appear.appear {
                let key = _closureFn(fn)
                if !_appearedFired.contains(key) { _appearedFired.insert(key); fn() }
            }
            return _ViewOutputs(node)
        }
        return v.content._mvErased(inputs)
    }
}

// .focused — no focus engine; render the content.
extension _FocusedView {
    public static func _makeView(view: _GraphValue<_FocusedView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)
    }
}
// .gesture — a recognized drag-changed action becomes a host pan target.
extension _GestureView {
    public static func _makeView(view: _GraphValue<_GestureView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let node = v.content._mvErased(inputs).node
        guard let action = v.dragChanged else { return _ViewOutputs(node) }
        return _ViewOutputs(.draggable(action, node))
    }
}
// IDView (.id) — identity is irrelevant to this walk; render the content.
extension IDView {
    public static func _makeView(view: _GraphValue<IDView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)
    }
}
// Shape.fill → a shaped paint node (the .background(_:in:) pipeline); a stroked
// shape (Shape.stroke / the inlined .border path) → an OUTLINE node instead.
protocol _AnyStrokedShape { var _strokeInner: _AnyShapeDescriptor? { get }; var _strokeWidth: CGFloat { get } }
extension _StrokedShape: _AnyStrokedShape {
    var _strokeInner: _AnyShapeDescriptor? { shape as? _AnyShapeDescriptor }
    var _strokeWidth: CGFloat { style.lineWidth }
}
extension _ShapeView {
    public static func _makeView(view: _GraphValue<_ShapeView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let paint = (v.style as? any View)?._mvErased(inputs).node ?? .colorBox("primary")
        if let stroked = v.shape as? _AnyStrokedShape {
            let inner = stroked._strokeInner
            return _ViewOutputs(.stroked(paint, shapeKind: inner?._shapeKind ?? "rect",
                                         cornerRadius: inner?._shapeCornerRadius ?? 0,
                                         width: stroked._strokeWidth))
        }
        let desc = v.shape as? _AnyShapeDescriptor
        return _ViewOutputs(.shaped(paint, shapeKind: desc?._shapeKind ?? "rect",
                                    cornerRadius: desc?._shapeCornerRadius ?? 0))
    }
}
// The iOS-17 concrete stroke result: unwrap the nested tree; a non-empty Background
// paints behind the outline.
extension StrokeShapeView {
    public static func _makeView(view: _GraphValue<StrokeShapeView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let stroked = v.view.content._mvErased(inputs)
        if v.view.modifier.background is EmptyView { return stroked }
        return _ViewOutputs(.background(v.view.modifier.background._mvErased(inputs).node, stroked.node))
    }
}
// AnyView: render the boxed view.
extension AnyView {
    public static func _makeView(view: _GraphValue<AnyView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.storage.view._mvErased(inputs)
    }
}
// Grid → a vstack of hstacks (one per GridRow; a bare child is its own row).
protocol _AnyGridRow { func _rowChildren(_ inputs: _ViewInputs) -> [RenderNode] }
extension GridRow: _AnyGridRow {
    func _rowChildren(_ inputs: _ViewInputs) -> [RenderNode] { _childNodes(content, inputs) }
}
extension Grid {
    public static func _makeView(view: _GraphValue<Grid>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let hs = v._tree.root.horizontalSpacing, vs = v._tree.root.verticalSpacing
        let rows = _stackChildren(v._tree.content).map { r -> RenderNode in
            if let gr = r as? _AnyGridRow { return .hstack(hs, 1, gr._rowChildren(inputs)) }
            return r._mvErased(inputs).node
        }
        return _ViewOutputs(.vstack(vs, _crossAxis(v._tree.root.alignment.horizontal.key), rows))
    }
}
// Compose an extra action onto every rendered Button (alert buttons must also dismiss).
func _composeButtonActions(_ n: RenderNode, _ extra: @escaping () -> Void) -> RenderNode {
    switch n {
    case let .button(a, c, s): return .button({ a(); extra() }, c, style: s)
    case let .vstack(sp, al, ch): return .vstack(sp, al, ch.map { _composeButtonActions($0, extra) })
    case let .hstack(sp, al, ch): return .hstack(sp, al, ch.map { _composeButtonActions($0, extra) })
    default: return n
    }
}
// Sweep-3 wrapper views.
extension _AlertView {
    public static func _makeView(view: _GraphValue<_AlertView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let base = v.base._mvErased(inputs).node
        guard v.isPresented.wrappedValue else { return _ViewOutputs(base) }
        let dismiss = { v.isPresented.wrappedValue = false }
        // Alert = a modal panel (the sheet node) of title + actions; every action
        // button also dismisses (Apple's alert semantics), as does the scrim.
        let actionNodes = _childNodes(v.actions, inputs).map { _composeButtonActions($0, dismiss) }
        let panel = RenderNode.vstack(12, 1, [_sectionHeader(Text(v.title)._mvErased(inputs).node),
                                              .hstack(8, 1, actionNodes)])
        return _ViewOutputs(.sheet(dismiss, base, panel))
    }
}
extension _ToolbarView {
    public static func _makeView(view: _GraphValue<_ToolbarView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        // Items in a top bar row above the content.
        return _ViewOutputs(.vstack(10, 1, [.hstack(8, 1, _childNodes(v.bar, inputs)),
                                            v.base._mvErased(inputs).node]))
    }
}
extension _ContextMenuView {
    public static func _makeView(view: _GraphValue<_ContextMenuView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        // No right-click routing yet: reuse the menu dropdown (tap the content to expand).
        return _ViewOutputs(.menu(v.base._mvErased(inputs).node, _childNodes(v.items, inputs)))
    }
}
extension _OnSubmitView {
    public static func _makeView(view: _GraphValue<_OnSubmitView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)   // submit events not wired in the host yet
    }
}
extension _ToggleStyledView {
    public static func _makeView(view: _GraphValue<_ToggleStyledView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)   // host checkbox ≈ switch; style accepted
    }
}
extension _TextFieldStyledView {
    public static func _makeView(view: _GraphValue<_TextFieldStyledView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)   // host field is already rounded-border-ish
    }
}
extension SecureField {
    public static func _makeView(view: _GraphValue<SecureField>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let masked = String(repeating: "•", count: v.text.wrappedValue.count)
        return _ViewOutputs(.textField(masked, v.label._mvErased(inputs).node))
    }
}
extension TextEditor {
    public static func _makeView(view: _GraphValue<TextEditor>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.textField(v.text.wrappedValue, .empty))
    }
}
extension GroupBox {
    public static func _makeView(view: _GraphValue<GroupBox>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let inner = RenderNode.padding(12, .vstack(6, 0, [_sectionHeader(v.label._mvErased(inputs).node)]
                                                          + _childNodes(v.content, inputs)))
        return _ViewOutputs(.clip("rrect", 8, .background(.colorBox("rgba:0.18,0.18,0.2,1"), inner)))
    }
}
extension LazyHGrid {
    public static func _makeView(view: _GraphValue<LazyHGrid>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        // Chunk items into columns of rows.count (the transpose of LazyVGrid).
        let items = _childNodes(v.content, inputs)
        let n = max(v.rows.count, 1)
        var cols: [RenderNode] = []
        var i = 0
        while i < items.count {
            cols.append(.vstack(v.spacing, 1, Array(items[i..<min(i + n, items.count)])))
            i += n
        }
        return _ViewOutputs(.hstack(v.spacing, 1, cols))
    }
}

// Form/Section → a List of the flattened sections; a section header renders as a
// bold secondary sub-headline row above its rows.
func _sectionHeader(_ n: RenderNode) -> RenderNode {
    if case let .text(s, c, f, _, l, i) = n {
        return .text(s, color: c ?? "secondary", font: f ?? "subheadline", bold: true, lines: l, italic: i)
    }
    return n
}
protocol _AnySection { func _sectionNodes(_ inputs: _ViewInputs) -> [RenderNode] }
extension Section: _AnySection where Parent: View, Content: View, Footer: View {
    func _sectionNodes(_ inputs: _ViewInputs) -> [RenderNode] {
        [_sectionHeader(header._mvErased(inputs).node)] + _childNodes(content, inputs)
    }
}
extension Section where Parent: View, Content: View, Footer: View {
    public static func _makeView(view: _GraphValue<Section>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.vstack(6, 0, v._sectionNodes(inputs)))
    }
}
extension Form {
    public static func _makeView(view: _GraphValue<Form>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        var rows: [RenderNode] = []
        for child in _stackChildren(v.content) {
            if let s = child as? _AnySection { rows.append(contentsOf: s._sectionNodes(inputs)) }
            else { rows.append(child._mvErased(inputs).node) }
        }
        return _ViewOutputs(.list(rows))
    }
}

// Menu → label + items; the host renders the label as a tap-to-expand dropdown.
extension Menu {
    public static func _makeView(view: _GraphValue<Menu>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.menu(v._menuLabel._mvErased(inputs).node, _childNodes(v.content, inputs)))
    }
}

// ── Resilient View-extension wrappers (2026-07-02 sweep) ─────────────────────
extension _TapGestureView {
    public static func _makeView(view: _GraphValue<_TapGestureView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return _ViewOutputs(.tappable(v.action, v.content._mvErased(inputs).node))
    }
}
extension _NavigationTitledView {
    public static func _makeView(view: _GraphValue<_NavigationTitledView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        return v.content._mvErased(inputs)   // title not yet surfaced (no per-view bar)
    }
}
// .onChange: compare against the previous walk's value (cached by the action closure's
// fn pointer — stable per declaration, the @StateObject/onAppear convention). Fires
// AFTER the content renders; a mutation made by the action lands in the deferred
// invalidate → settle pass (like .onAppear).
nonisolated(unsafe) var _onChangeCache: [UInt: Any] = [:]
extension _OnChangeView {
    public static func _makeView(view: _GraphValue<_OnChangeView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let out = v.content._mvErased(inputs)
        let key = unsafeBitCast(v.action, to: (UInt, UInt).self).0
        let old = _onChangeCache[key] as? V
        _onChangeCache[key] = v.value
        if let old { if old != v.value { v.action(old, v.value) } }
        else if v.initial { v.action(v.value, v.value) }
        return out
    }
}
extension _SheetView {
    public static func _makeView(view: _GraphValue<_SheetView>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let v = view._value else { return _ViewOutputs() }
        let base = v.base._mvErased(inputs).node
        guard v.isPresented.wrappedValue else { return _ViewOutputs(base) }
        let content = v.sheet()._mvErased(inputs).node
        let dismiss = { v.isPresented.wrappedValue = false; v.onDismiss?() }
        return _ViewOutputs(.sheet(dismiss, base, content))
    }
}

// ── Driver ───────────────────────────────────────────────────────────────────
func _renderRoot(_ root: any View) -> RenderNode {
    root._mvErased(_ViewInputs()).node
}
