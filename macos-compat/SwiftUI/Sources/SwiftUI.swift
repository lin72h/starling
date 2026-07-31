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

public struct _GraphValue<Value> {
    public init() {}
}

public struct _ViewInputs { public init() {} }
public struct _ViewOutputs { public init() {} }
public struct _ViewListInputs { public init() {} }
public struct _ViewListOutputs { public init() {} }
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

extension View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        // Default: this is the hook into Flutter. Milestone 2 walks `body` here.
        return _ViewOutputs()
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        return _ViewListOutputs()
    }
    public static func _viewListCount(inputs: _ViewListCountInputs) -> Int? {
        return nil
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
        // Instantiate the unmodified app and introspect its UI via reflection.
        _reflectAndDump(Self())
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
public final class AnyTextStorage {
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
        case anyTextStorage(AnyTextStorage)
        public static func == (l: Storage, r: Storage) -> Bool {
            switch (l, r) {
            case let (.verbatim(a), .verbatim(b)): return a == b
            case let (.anyTextStorage(a), .anyTextStorage(b)): return a === b
            default: return false
            }
        }
    }
    public struct Modifier {}   // payload type for `modifiers`; array stays empty

    @usableFromInline var storage: Storage
    @usableFromInline var modifiers: [Modifier]

    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {
        self.storage = .anyTextStorage(AnyTextStorage(key._key))
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
}

@frozen
public struct TupleView<T>: View {
    public var value: T
    public init(_ value: T) { self.value = value }
    public typealias Body = Never
    public var body: Never { return fatalError("TupleView is primitive") }
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

@frozen
public struct _PaddingLayout: ViewModifier {
    @usableFromInline var edges: Edge.Set
    @usableFromInline var insets: CGFloat?
    public init(edges: Edge.Set, insets: CGFloat?) {
        self.edges = edges
        self.insets = insets
    }
}

extension View {
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        ModifiedContent(content: self, modifier: _PaddingLayout(edges: edges, insets: length))
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
        nonmutating set { _location?.value = newValue }
    }
    public var projectedValue: Binding<Value> {
        Binding(get: { self.wrappedValue }, set: { self.wrappedValue = $0 })
    }
}

@propertyWrapper
public struct Binding<Value> {
    var get: () -> Value
    var set: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
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
