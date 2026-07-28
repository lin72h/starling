// Reconstructed `SwiftUI` module — binary-compatible replacement.
//
// Goal: export the exact mangled symbols an unmodified macOS SwiftUI app binary
// imports, so dyld resolves them to *our* implementations (backed by the Flutter
// engine) instead of Apple's SwiftUI.framework — with no recompile of the app.
//
// This module is named `SwiftUI`, so every type declared here mangles as
// `_$s7SwiftUI...`, matching what the binary references. Apple actually declares
// many of these in `SwiftUICore` with `@_originallyDefinedIn(module: "SwiftUI")`,
// which collapses to the same ABI module name — we just declare them directly.
//
// MILESTONE 1: get the unmodified binary to LOAD and reach `App.main()`.
// dyld binds by symbol *name*, not by signature/layout, so the bodies below are
// mostly stubs. Member ORDER of the App/View/Scene protocols is ABI-critical
// (the app's own conformances bind witness slots positionally) and matches
// Apple's .swiftinterface exactly. Layout fidelity comes in the rendering step.

import Foundation

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Render ABI value types (we own their layout; the app never field-accesses them)
// ════════════════════════════════════════════════════════════════════════════

// We render in one shot (no attribute graph / reactivity), so _GraphValue simply
// carries the concrete view value through the _makeView recursion. The binary never
// constructs _GraphValue (only our reconstructed _makeView impls do), so its layout
// is ours to define.
public struct _GraphValue<Value> {
    @usableFromInline var _value: Value?
    public init() { _value = nil }
    @usableFromInline init(_ v: Value) { _value = v }
}

// Our reconstructions own these types (the binary never constructs them), so they
// carry the actual render data through the _makeView recursion: inputs carry the
// inherited environment; outputs carry the produced render node(s). See MakeView.swift.
public struct _ViewInputs {
    @usableFromInline var fgColor: String?
    // The inherited environment: every _EnvironmentKeyWritingModifier (.foregroundColor /
    // .environment / .environmentObject) applies its keypath to a copy for its subtree;
    // the default View._makeView injects @EnvironmentObject fields from it before `body`.
    @usableFromInline var env: EnvironmentValues = EnvironmentValues()
    public init() {}
    @usableFromInline init(fgColor: String?) { self.fgColor = fgColor }
}
public struct _ViewOutputs {
    @usableFromInline var node: RenderNode
    public init() { node = .empty }
    @usableFromInline init(_ n: RenderNode) { node = n }
}
public struct _ViewListInputs {
    @usableFromInline var fgColor: String?
    public init() {}
    @usableFromInline init(_ i: _ViewInputs) { fgColor = i.fgColor }
}
public struct _ViewListOutputs {
    @usableFromInline var nodes: [RenderNode]
    public init() { nodes = [] }
    @usableFromInline init(_ n: [RenderNode]) { nodes = n }
}
public struct _ViewListCountInputs { public init() {} }
public struct _SceneInputs { public init() {} }
public struct _SceneOutputs { public init() {} }
public struct _Graph { public init() {} }

// ════════════════════════════════════════════════════════════════════════════
// MARK: - View (member order must match Apple: _makeView, _makeViewList, _viewListCount, Body, body)
// ════════════════════════════════════════════════════════════════════════════

public protocol View {
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
    static func _viewListCount(inputs: _ViewListCountInputs) -> Int?
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

import Foundation
nonisolated(unsafe) let _mvTrace = ProcessInfo.processInfo.environment["MAKEVIEW"] != nil
func _mvLog(_ s: String) { if _mvTrace { FileHandle.standardError.write(Data("[mv] \(s)\n".utf8)) } }

extension View {
    // DEFAULT _makeView = a *custom* (composite) view: render its `body`. Primitive
    // views (Text, VStack, …) override this to emit their own render output. This is
    // the real SwiftUI render recursion, driven through the View witness tables — the
    // binary's own ContentView uses this default (its witness slot binds to it), so
    // calling ContentView._makeView evaluates the app's `body` and recurses.
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _mvLog("custom <\(Self.self)>  body=\(Body.self)")
        guard var v = view._value else { return _ViewOutputs() }
        // Populate @EnvironmentObject fields (their inlined wrappedValue reads _store
        // directly) from the inherited environment before the body runs. This is the
        // single funnel every user struct's body goes through.
        _injectEnvironmentObjects(&v, inputs.env)
        return v.body._mvErased(inputs)
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        return _ViewListOutputs()
    }
    public static func _viewListCount(inputs: _ViewListCountInputs) -> Int? {
        return nil
    }
    // Dispatch _makeView on an existential `any View` (opens it; Self = dynamic type).
    func _mvErased(_ inputs: _ViewInputs) -> _ViewOutputs {
        Self._makeView(view: _GraphValue(self), inputs: inputs)
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Scene  (order: Body, body, _makeScene)
// ════════════════════════════════════════════════════════════════════════════

public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    static func _makeScene(scene: _GraphValue<Self>, inputs: _SceneInputs) -> _SceneOutputs
}

extension Scene {
    public static func _makeScene(scene: _GraphValue<Self>, inputs: _SceneInputs) -> _SceneOutputs {
        return _SceneOutputs()
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - App  (order: Body, body, init) + the entry point
// ════════════════════════════════════════════════════════════════════════════

public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()
}

extension App {
    public static func main() {
        // *** This is where control enters our code from the unmodified binary. ***
        print(">>> [reimpl SwiftUI] App.main() reached — app type = \(Self.self)")
        // Instantiate the unmodified app, translate its view tree to Flutter
        // widgets, and render through the Flutter engine in a macOS window.
        _runViaFlutter(Self())
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Result builders
// ════════════════════════════════════════════════════════════════════════════

@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content { content }
}

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        TupleView((repeat each content))
    }
    // if/else and if (no else). Apple's are @_alwaysEmitIntoClient so the app inlines
    // its own; these exist so OUR module and any non-inlined caller resolve, and to
    // mirror the exact result types (_ConditionalContent / Optional).
    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(first))
    }
    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(second))
    }
    public static func buildOptional<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Primitive / container views
// ════════════════════════════════════════════════════════════════════════════

@frozen
public struct EmptyView: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { return fatalError("EmptyView has no body") }
}

// Backing class for Text.Storage.anyTextStorage. Apple stores text built from a
// LocalizedStringKey as `.anyTextStorage(class)` (never `.verbatim`), so we do the
// same: the @frozen enum's tag must correspond to a real class payload, otherwise
// the app's inlined destroy misreads a small-string's bits as the class case and
// release()s the inline characters.
// Named uniquely (NOT `AnyTextStorage`): Apple's SwiftUICore.AnyTextStorage is
// loaded at runtime (via AppKit) and, with @_originallyDefinedIn("SwiftUI"),
// registers the same ObjC class name — a collision. Layout only needs a class ref.
public final class _CompatTextBacking {
    public let string: String
    public init(_ s: String) { self.string = s }
}

// Layout MUST match Apple's `@frozen public struct Text` (32 bytes):
//   storage: Storage    (enum: verbatim(String) | anyTextStorage(class) → 24 bytes)
//   modifiers: [Modifier]  (Array → 8 bytes)
// Text is @frozen, so the app passes it BY VALUE (e.g. `title: Text?` = 32 bytes,
// which is why the closure spilled to x6/x7) and inlines copy/release using this
// exact layout.
@frozen
public struct Text: View, Equatable {
    @frozen public enum Storage: Equatable {
        case verbatim(String)
        case anyTextStorage(_CompatTextBacking)
        public static func == (l: Storage, r: Storage) -> Bool {
            switch (l, r) {
            case let (.verbatim(a), .verbatim(b)): return a == b
            case let (.anyTextStorage(a), .anyTextStorage(b)): return a === b
            default: return false
            }
        }
    }
    // Apple stores text-level styling (.font/.foregroundColor/.bold/…) in this
    // `modifiers` array, NOT in extra struct fields — so Text stays exactly 32
    // bytes (storage 24 + Array pointer 8). The Array's element layout is ours
    // (heap, metadata-driven), so making Modifier a real enum is layout-safe.
    public enum Modifier {
        case color(Color?)
        case font(Font?)
        case weight(Font.Weight?)
        case italic
    }

    @usableFromInline var storage: Storage
    @usableFromInline var modifiers: [Modifier]

    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {
        self.storage = .anyTextStorage(_CompatTextBacking(key._key))
        self.modifiers = []
    }
    public typealias Body = Never
    public var body: Never { return fatalError("Text is primitive") }
    public static func == (l: Text, r: Text) -> Bool { l.storage == r.storage }

    var _resolvedString: String {
        switch storage {
        case .verbatim(let s): return s
        case .anyTextStorage(let st): return st.string
        }
    }

    // Resolve the styling the modifiers describe (last write wins).
    var _resolvedColor: Color? {
        modifiers.reversed().compactMap { if case .color(let c) = $0 { return c } else { return nil } }.first ?? nil
    }
    var _resolvedFont: Font? {
        modifiers.reversed().compactMap { if case .font(let f) = $0 { return f } else { return nil } }.first ?? nil
    }
    var _resolvedWeight: Font.Weight? {
        modifiers.reversed().compactMap { if case .weight(let w) = $0 { return w } else { return nil } }.first ?? nil
    }
    var _resolvedItalic: Bool {
        modifiers.contains { if case .italic = $0 { return true } else { return false } }
    }

    // Resilient Text-returning styling methods (2026-07-02 sweep 3; both struct-body,
    // the binary CALLS them). foregroundStyle: the Color case lands in the modifiers
    // array like .foregroundColor; non-Color styles are accepted and ignored.
    public func foregroundStyle<S>(_ style: S) -> Text where S: ShapeStyle {
        var t = self
        if let c = style as? Color { t.modifiers.append(.color(c)) }   // non-Color styles: no-op
        return t
    }
    public func italic() -> Text {
        var t = self
        t.modifiers.append(.italic)
        return t
    }
}

@frozen
public struct TupleView<T>: View {
    public var value: T
    public init(_ value: T) { self.value = value }
    public typealias Body = Never
    public var body: Never { return fatalError("TupleView is primitive") }
}

// `if/else` in a @ViewBuilder. Apple's buildEither(first:)/(second:) are
// @_alwaysEmitIntoClient (inlined into the app), which CALL our _ConditionalContent
// .init(storage:) and read the @frozen Storage enum by value — so the type, the enum
// (cases in this order), and the init must match Apple's layout byte-for-byte. _makeView
// renders whichever branch is active (see MakeView.swift).
// Struct UNCONSTRAINED and init/View in CONSTRAINED extensions — mirrors Apple exactly
// so the inlined buildEither binds the extension init symbol
// (…_ConditionalContent< where A: View, B: View>.init(storage:)).
@frozen
public struct _ConditionalContent<TrueContent, FalseContent> {
    @frozen public enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    @usableFromInline var storage: Storage
}
extension _ConditionalContent where TrueContent: View, FalseContent: View {
    @usableFromInline init(storage: Storage) { self.storage = storage }
}
extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    public typealias Body = Never
    public var body: Never { return fatalError("_ConditionalContent is primitive") }
}

// `if`/`if let` without `else` in a @ViewBuilder. Apple's buildIf returns `Content?`,
// so the body carries an Optional<some View>. Optional already conforms to View in real
// SwiftUI; we mirror that so the value can be opened as `any View` and rendered (the
// .some branch, or nothing when nil) — see Optional._makeView in MakeView.swift.
extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { return fatalError("Optional<View> is primitive") }
}

// @frozen; flat {alignment, spacing, content} reproduces Apple's nested
// {_tree: Tree<_VStackLayout, Content>} layout: alignment@0, spacing@8, content@24.
@frozen
public struct VStack<Content: View>: View {
    @usableFromInline var alignment: HorizontalAlignment
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    public typealias Body = Never
    public var body: Never { return fatalError("VStack is primitive") }
}

public struct Button<Label: View>: View {
    var action: () -> Void
    var label: Label
    public typealias Body = Never
    public var body: Never { fatalError("Button is primitive") }
}

extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.action = action
        self.label = Text(titleKey)
    }
}

// ModifiedContent + the padding modifier
public protocol ViewModifier {}

@frozen
public struct ModifiedContent<Content, Modifier> {
    public var content: Content
    public var modifier: Modifier
    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}
extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public typealias Body = Never
    public var body: Never { return fatalError("ModifiedContent is primitive") }
}

// @frozen, 32 bytes — must match Apple's `EdgeInsets` (4 × CGFloat in declaration
// order: top, leading, bottom, trailing). The app inlines `padding(_:_:)` (it's
// @inlinable) and builds the `EdgeInsets?` directly, so this layout is ABI-load-bearing
// even though the app imports no EdgeInsets symbol — the runtime reads _PaddingLayout's
// field types (→ EdgeInsets) off our nominal type descriptor to size
// ModifiedContent<…, _PaddingLayout>. Mangles as `7SwiftUI10EdgeInsetsV` (Apple's is
// @_originallyDefinedIn("SwiftUI") from SwiftUICore), so it binds straight through.
@frozen
public struct EdgeInsets {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat
    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }
    // Apple's internal all-edges init, CALLED (not inlined) by the @inlinable
    // padding(_:_:) when given a scalar length — `.padding(8)` lowers to
    // EdgeInsets(_all: 8). @usableFromInline so the symbol is emitted for the app to
    // bind (CGFloat mangles via Foundation on Linux; machold rewrites CoreGraphics→Foundation).
    @usableFromInline init(_all v: CGFloat) {
        self.top = v; self.leading = v; self.bottom = v; self.trailing = v
    }
}

// @frozen, 48 bytes — {edges: Edge.Set @0 (Int8), insets: EdgeInsets? @8 (40B)}. The
// insets field MUST be `EdgeInsets?`, not `CGFloat?`: Apple's is EdgeInsets? (40B), and
// a CGFloat? (16B) here makes our metadata size 24B vs Apple's 48B for the SAME nominal
// `ModifiedContent<Content, _PaddingLayout>` — conflicting sizes for one type smash the
// heap nondeterministically when the app's by-value modifier flows through our render
// (see FOUNDATION-ISSUE.md / the padding probes).
@frozen
public struct _PaddingLayout: ViewModifier {
    @usableFromInline var edges: Edge.Set
    @usableFromInline var insets: EdgeInsets?
    public init(edges: Edge.Set = .all, insets: EdgeInsets?) {
        self.edges = edges
        self.insets = insets
    }
}

extension View {
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let insets = length.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) }
        return ModifiedContent(content: self, modifier: _PaddingLayout(edges: edges, insets: insets))
    }
}

// Internal layout marker types referenced only as type descriptors by the binary.
// The constraint `Root: _VariadicView_Root` is ABI-significant: it adds a witness-
// table pointer to Tree's metadata generic arguments. The app reads VStack's
// `content` field offset from THIS metadata's field-offset vector; without the
// constraint the vector is shifted and the app reads child views from a wrong
// offset (garbage), then release()s it.
public protocol _VariadicView_Root {}

public enum _VariadicView {
    @frozen public struct Tree<Root: _VariadicView_Root, Content> {
        public var root: Root
        public var content: Content
        public init(root: Root, content: Content) { self.root = root; self.content = content }
    }
}
// MUST be 24 bytes ({alignment: HorizontalAlignment, spacing: CGFloat?}) to match
// Apple's. The app finds VStack's `content` by instantiating OUR
// Tree<_VStackLayout, Content> metadata and reading the field offset = sizeof(root).
// If _VStackLayout were empty (0 bytes), content offset = 0 and the app reads the
// child views from the wrong location.
@frozen public struct _VStackLayout {
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat?
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }
}
extension _VStackLayout: _VariadicView_Root {}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - WindowGroup
// ════════════════════════════════════════════════════════════════════════════

public struct WindowGroup<Content: View>: Scene {
    var content: Content
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    public init(id: String? = nil, title: Text? = nil, @ViewBuilder lazyContent: @escaping () -> Content) {
        self.content = lazyContent()
    }
    public typealias Body = Never
    public var body: Never { fatalError("WindowGroup is primitive") }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - State / Binding
// ════════════════════════════════════════════════════════════════════════════

// Backing store for @State. Behind a class reference so mutations persist
// across value copies (matching @State's reference semantics).
public final class _StateLocation<Value> {
    public var value: Value
    public init(_ v: Value) { value = v }
}

// Layout MUST match Apple's `@frozen public struct State<Value>`:
//   _value: Value           (offset 0)
//   _location: <class>?     (offset = sizeof(Value), 8-byte ref)
// State<Int> is therefore 16 bytes — the app embeds it by value in its own
// view types and accesses it at these offsets, so a mismatch corrupts memory.
@frozen
@propertyWrapper
public struct State<Value> {
    @usableFromInline var _value: Value
    @usableFromInline var _location: _StateLocation<Value>?
    public init(wrappedValue value: Value) {
        _value = value
        _location = _StateLocation(value)
    }
    public var wrappedValue: Value {
        get { _location?.value ?? _value }
        // Apple's accessor is RESILIENT, so every binary @State write lands here.
        // Invalidate like a @Published mutation: mid-walk/mid-action writes defer and
        // coalesce (dispatch's own re-render settles them); out-of-band writes (.task,
        // timers) re-render immediately — without this they'd be silent.
        nonmutating set { _location?.value = newValue; swiftui_compat_invalidate() }
    }
    public var projectedValue: Binding<Value> {
        Binding(get: { self.wrappedValue }, set: { self.wrappedValue = $0 })
    }
}

// Apple's Binding is @frozen and small (a Transaction + a location class). The
// binary holds Binding values by value as it threads $state into controls, so ours
// must be ≤ Apple's size or the binary's inlined copy overflows. Box the two
// closures behind one class → Binding is a single 8-byte reference.
public final class _BindingBox<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
}
// Apple's Binding is @frozen and 17 bytes — measured from the Gallery binary, which
// passes it as {x4, x5, byte@16} (an `ldurb` at offset 16). That 17th byte tips it
// over 16, so Apple RETURNS Binding indirectly (sret) and PASSES it in 2 regs + a
// byte. Ours must match that size exactly: a 16-byte version returns in registers
// instead, leaving the binary's sret buffer unwritten → garbage on the next use.
// Layout: {transaction(8), location/box(8), flag(1)}; only `box` is meaningful.
// @frozen, and it stores `_value` INLINE so the size tracks Apple's exactly:
// measured from the binary, Binding<Bool> is 17 bytes (loaded as x4,x5 + byte@16) but
// Binding<String> is 32 bytes (loaded as x4,x5,x6,x7) — i.e. Apple's layout is
// {transaction(8), location(8), value: Value}, value at offset 16. A fixed-size
// reconstruction mis-sizes Binding<String> and shifts every following stack arg
// (then the control init releases a stack neighbour → SIGBUS). The RETURN side has a
// separate Swift cross-version gap (the binary wants this returned via sret; Swift
// 6.2.4 returns ≤4-field structs in registers) handled by the loader's size-aware
// projectedValue adapter — see linux/GALLERY-WORKLIST.md.
@frozen @propertyWrapper
public struct Binding<Value> {
    @usableFromInline var _transaction: Int          // Apple's transaction slot (offset 0)
    @usableFromInline var box: _BindingBox<Value>    // offset 8 (Apple's location slot)
    @usableFromInline var _value: Value              // offset 16 — inline value (size tracks Apple)
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self._transaction = 0
        self.box = _BindingBox(get: get, set: set)
        self._value = get()
    }
    public var wrappedValue: Value {
        get { box.get() }
        nonmutating set { box.set(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Support types
// ════════════════════════════════════════════════════════════════════════════

public enum Edge: Int8, CaseIterable {
    case top, leading, bottom, trailing
    @frozen public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let top = Edge.Set(rawValue: 1 << 0)
        public static let leading = Edge.Set(rawValue: 1 << 1)
        public static let bottom = Edge.Set(rawValue: 1 << 2)
        public static let trailing = Edge.Set(rawValue: 1 << 3)
        public static let all: Edge.Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Edge.Set = [.leading, .trailing]
        public static let vertical: Edge.Set = [.top, .bottom]
    }
}

@frozen
public struct HorizontalAlignment: Equatable {
    @usableFromInline var key: Int
    @usableFromInline init(key: Int) { self.key = key }
    public static let leading = HorizontalAlignment(key: 0)
    public static let center = HorizontalAlignment(key: 1)
    public static let trailing = HorizontalAlignment(key: 2)
}

public protocol _FormatSpecifiable {}
extension Int: _FormatSpecifiable {}
extension Double: _FormatSpecifiable {}
extension Float: _FormatSpecifiable {}
// CGFloat too — `Text("\(geo.size.width)")` interpolates a CGFloat. (On Linux CGFloat is
// Foundation's; machold rewrites the binary's CoreGraphics.CGFloat import to it.)
extension CGFloat: _FormatSpecifiable {}

// Layout matches Apple's `@frozen public struct LocalizedStringKey` (32 bytes):
//   key: String (16) @0, hasFormatting: Bool (1) @16, arguments: [FormatArgument] (8) @24.
@frozen
public struct LocalizedStringKey: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Equatable {
    @usableFromInline var key: String
    @usableFromInline var hasFormatting: Bool = false
    @usableFromInline var arguments: [FormatArgument]

    @usableFromInline struct FormatArgument: Equatable {
        @usableFromInline var v: Int
        @usableFromInline init(_ v: Int) { self.v = v }
        @usableFromInline static func == (l: FormatArgument, r: FormatArgument) -> Bool { l.v == r.v }
    }

    public init(_ value: String) { key = value; arguments = [] }
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) { key = stringInterpolation.output; arguments = [] }
    public static func == (l: LocalizedStringKey, r: LocalizedStringKey) -> Bool { l.key == r.key }
    var _key: String { key }

    public struct StringInterpolation: StringInterpolationProtocol {
        var output: String = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { output += literal }
        public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T, specifier: String) {
            output += "\(value)"
        }
        public mutating func appendInterpolation<T>(_ value: T) { output += "\(value)" }
    }
}

// Never as a terminal View/Scene (Body types bottom out here).
extension Never: View, Scene {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
