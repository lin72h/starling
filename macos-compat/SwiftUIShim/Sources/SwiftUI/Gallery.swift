// Gallery breadth reconstruction — the 57 SwiftUI symbols probe/Gallery needs
// beyond probe/Hello (stacks, containers, controls, modifiers, Color/Font). Shared
// Swift source (built on both macOS and Linux); see linux/GALLERY-WORKLIST.md.
//
// Layout discipline (same lesson as Hello): a type the app embeds BY VALUE with a
// statically-known concrete type into another @frozen aggregate (e.g. a child in a
// TupleView, or a modifier in ModifiedContent the app inlines) must match Apple's
// @frozen layout byte-for-byte. Types used only generically / behind `some View`
// (opaque) are copied via the value-witness table, so their layout is ours to pick.
// Marked @frozen + field-ordered where the app inlines them; resilient otherwise.

import Foundation
#if canImport(CGCompatShims)
import CGCompatShims   // CGLineCap/CGLineJoin as __C structs (So…V manglings; StrokeStyle fields)
#else
import CoreGraphics    // macOS: the real __C types
#endif

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Alignment (VerticalAlignment / Alignment), Axis
// ════════════════════════════════════════════════════════════════════════════

@frozen public struct VerticalAlignment: Equatable {
    @usableFromInline var key: Int
    @usableFromInline init(key: Int) { self.key = key }
    public static let top = VerticalAlignment(key: 0)
    public static let center = VerticalAlignment(key: 1)
    public static let bottom = VerticalAlignment(key: 2)
    public static let firstTextBaseline = VerticalAlignment(key: 3)
    public static let lastTextBaseline = VerticalAlignment(key: 4)
}

// {horizontal: HorizontalAlignment(8), vertical: VerticalAlignment(8)} = 16
@frozen public struct Alignment: Equatable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    @inlinable public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal; self.vertical = vertical
    }
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

@frozen public enum Axis: Int8, CaseIterable {
    case horizontal = 0
    case vertical = 1
    @frozen public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let horizontal = Axis.Set(rawValue: 1 << 0)
        public static let vertical = Axis.Set(rawValue: 1 << 1)
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - HStack / ZStack / Group / Spacer / Divider  (layout-critical @frozen)
// ════════════════════════════════════════════════════════════════════════════

// _HStackLayout: like _VStackLayout but vertical alignment → 24 bytes
//   {alignment: VerticalAlignment(8)@0, spacing: CGFloat?(16)@8}
@frozen public struct _HStackLayout {
    public var alignment: VerticalAlignment
    public var spacing: CGFloat?
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {
        self.alignment = alignment; self.spacing = spacing
    }
}
extension _HStackLayout: _VariadicView_Root {}

@frozen public struct HStack<Content: View>: View {
    @usableFromInline var alignment: VerticalAlignment
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("HStack is primitive") }
}

// _ZStackLayout: {alignment: Alignment(16)} = 16
@frozen public struct _ZStackLayout {
    public var alignment: Alignment
    public init(alignment: Alignment = .center) { self.alignment = alignment }
}
extension _ZStackLayout: _VariadicView_Root {}

@frozen public struct ZStack<Content: View>: View {
    @usableFromInline var alignment: Alignment
    @usableFromInline var content: Content
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("ZStack is primitive") }
}

// Group: transparent container; @frozen, {content} inline.
@frozen public struct Group<Content> {
    @usableFromInline var content: Content
    @usableFromInline init(_content: Content) { self.content = _content }
}
extension Group: View where Content: View {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public typealias Body = Never
    public var body: Never { fatalError("Group is primitive") }
}

// Spacer: @frozen {minLength: CGFloat?(16)} = 16
@frozen public struct Spacer: View {
    @usableFromInline var minLength: CGFloat?
    @inlinable public init(minLength: CGFloat? = nil) { self.minLength = minLength }
    public typealias Body = Never
    public var body: Never { fatalError("Spacer is primitive") }
}

// Divider: resilient; the app calls our init() symbol.
public struct Divider: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { fatalError("Divider is primitive") }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - ScrollView / ForEach  (resilient; metadata-driven)
// ════════════════════════════════════════════════════════════════════════════

@frozen public struct ScrollView<Content: View>: View {
    public var content: Content
    public var axes: Axis.Set
    public var showsIndicators: Bool
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes; self.showsIndicators = showsIndicators; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("ScrollView is primitive") }
}

public struct ForEach<Data, ID, Content> where Data: RandomAccessCollection, ID: Hashable {
    public var data: Data
    public var content: (Data.Element) -> Content
}
extension ForEach: View where Content: View {
    public typealias Body = Never
    public var body: Never { fatalError("ForEach is primitive") }
}
extension ForEach where Data == Range<Int>, ID == Int, Content: View {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = data
        self.content = content
    }
}
// ForEach over an Identifiable collection: `ForEach(products) { p in … }`.
extension ForEach where Content: View, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - LazyVStack / LazyHStack / List
// ════════════════════════════════════════════════════════════════════════════

// PinnedScrollableViews: OptionSet (4 B {rawValue: UInt32}) — passed by value into the
// Lazy*Stack inits, so the layout matches Apple. We don't pin (render is a plain stack),
// but the type + OptionSet conformance + metadata accessor must exist for the init.
@frozen public struct PinnedScrollableViews: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}

// LazyVStack/LazyHStack: their init is a real (imported) call — the app constructs them via
// our init and hands them over opaquely — so the layout is OURS. Lazy is a perf variant,
// visually identical to VStack/HStack, so _makeView emits the same stack node.
public struct LazyVStack<Content: View>: View {
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("LazyVStack is primitive") }
}
public struct LazyHStack<Content: View>: View {
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("LazyHStack is primitive") }
}

// GridItem + LazyVGrid — resilient; binary calls our inits + _makeView. We only need the column
// COUNT (= columns.count) to lay out a grid; the per-item Size/spacing/alignment are accepted but
// the host renders a uniform grid of `columns.count` columns. GridItem.Size's cases + the init's
// defaults match Apple so the binary's `GridItem(.flexible())` / `LazyVGrid(columns:){…}` bind.
public struct GridItem: Sendable {
    public enum Size: Sendable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }
    public var size: Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size; self.spacing = spacing; self.alignment = alignment
    }
}
public struct LazyVGrid<Content: View>: View {
    @usableFromInline var columns: [GridItem]
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.columns = columns; self.spacing = spacing; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("LazyVGrid is primitive") }
}

// ── Picker + the `.tag` trait subsystem ──────────────────────────────────────
// `.tag(value)` attaches a hashable selection value to an option view via a trait modifier.
// The binary embeds BOTH forms behind an inlined `#available(macOS 26)` — the modern
// _TagTraitWritingModifier and the legacy _TraitWritingModifier<TagValueTraitKey<Optional<V>>>.
// Which one exists at runtime is decided TWICE: the inlined body picks the VALUE representation
// via the stdlib availability entry, and the `.tag` opaque type descriptor's kind-9
// (accessor-function) references pick the TYPE metadata via statically-linked compiler-rt
// (__isPlatformVersionAtLeast). machold's convention makes both report FALSE (see
// machold_os_version_atleast in machold.c), so the LEGACY form is constructed AND resolved.
// All four types must exist (metadata + conformances) so the symbols bind; MakeView extracts
// the tag from either form.
public protocol _ViewTraitKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
@frozen public struct _TraitWritingModifier<Trait: _ViewTraitKey>: ViewModifier {
    public let value: Trait.Value
    @inlinable public init(value: Trait.Value) { self.value = value }
}
public struct TagValueTraitKey<V: Hashable>: _ViewTraitKey {
    @frozen public enum Value { case untagged; case tagged(V) }
    public static var defaultValue: Value { .untagged }
}
@frozen public struct _TagTraitWritingModifier<TagValue: Hashable>: ViewModifier {
    public let tag: TagValue
    public let includeOptional: Bool
    @_alwaysEmitIntoClient public init(tag: TagValue, includeOptional: Bool) {
        self.tag = tag; self.includeOptional = includeOptional
    }
}

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var selection: Binding<SelectionValue>
    @usableFromInline var content: Content
    public typealias Body = Never
    public var body: Never { fatalError("Picker is primitive") }
}
extension Picker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>,
                @ViewBuilder content: () -> Content) {
        self.label = Text(titleKey); self.selection = selection; self.content = content()
    }
}

// List: the minimal `Selection == Never` form. Layout is ours (init is a real call). Maps
// to a scrollable column of rows. SelectionValue: Hashable + Content: View match Apple's
// generic signature (the conformance descriptor is List<A, B> : View).
public struct List<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    @usableFromInline var content: Content
    public typealias Body = Never
    public var body: Never { fatalError("List is primitive") }
}
extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
}

// TabView<SelectionValue, Content>. `TabView { … }` binds the SelectionValue == Int init
// (Int is the default tag type), a real (imported) call → layout is ours. Renders as a tab
// bar + page body; selection wiring is a follow-up (the no-binding form's selection is
// internal UI state). SelectionValue: Hashable, Content: View match Apple.
public struct TabView<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    @usableFromInline var content: Content
    public typealias Body = Never
    public var body: Never { fatalError("TabView is primitive") }
}
extension TabView where SelectionValue == Int {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
}

// .tabItem { label } tags a view with its tab-bar label. Returns `some View` (opaque) — the
// underlying type is ours: _TabItemView carries the page content + the label. TabView pulls
// both out via _AnyTabItem when it flattens its content. (Rendered on its own, a _TabItemView
// is just its page content.)
public struct _TabItemView<Content: View, Label: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var label: Label
    @usableFromInline init(content: Content, label: Label) { self.content = content; self.label = label }
    public typealias Body = Never
    public var body: Never { fatalError("_TabItemView is primitive") }
}
extension View {
    public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View {
        _TabItemView(content: self, label: label())
    }
}
protocol _AnyTabItem { func _tabPage(_ inputs: _ViewInputs) -> RenderNode; func _tabLabel(_ inputs: _ViewInputs) -> RenderNode }
extension _TabItemView: _AnyTabItem {
    func _tabPage(_ inputs: _ViewInputs) -> RenderNode { content._mvErased(inputs).node }
    func _tabLabel(_ inputs: _ViewInputs) -> RenderNode { label._mvErased(inputs).node }
}

// ── Resilient View-extension modifiers (2026-07-02 sweep) ────────────────────
// These four methods are IMPORTED by the binary (resilient, F + FQOMQ opaque-descriptor
// pairs), so the signatures must mangle exactly but the underlying types are entirely
// ours — the .tabItem pattern. Labels are mangling-load-bearing (5count7perform, 2of7initial_,
// 11isPresented9onDismiss7content).
public struct _TapGestureView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var action: () -> Void
    @usableFromInline init(content: Content, action: @escaping () -> Void) { self.content = content; self.action = action }
    public typealias Body = Never
    public var body: Never { fatalError("_TapGestureView is primitive") }
}
public struct _NavigationTitledView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var title: LocalizedStringKey
    @usableFromInline init(content: Content, title: LocalizedStringKey) { self.content = content; self.title = title }
    public typealias Body = Never
    public var body: Never { fatalError("_NavigationTitledView is primitive") }
}
public struct _OnChangeView<V: Equatable, Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var value: V
    @usableFromInline var initial: Bool
    @usableFromInline var action: (V, V) -> Void
    @usableFromInline init(content: Content, value: V, initial: Bool, action: @escaping (V, V) -> Void) {
        self.content = content; self.value = value; self.initial = initial; self.action = action
    }
    public typealias Body = Never
    public var body: Never { fatalError("_OnChangeView is primitive") }
}
public struct _SheetView<Base: View, SheetContent: View>: View {
    @usableFromInline var base: Base
    @usableFromInline var isPresented: Binding<Bool>
    @usableFromInline var onDismiss: (() -> Void)?
    @usableFromInline var sheet: () -> SheetContent
    @usableFromInline init(base: Base, isPresented: Binding<Bool>, onDismiss: (() -> Void)?, sheet: @escaping () -> SheetContent) {
        self.base = base; self.isPresented = isPresented; self.onDismiss = onDismiss; self.sheet = sheet
    }
    public typealias Body = Never
    public var body: Never { fatalError("_SheetView is primitive") }
}
extension View {
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        _TapGestureView(content: self, action: action)
    }
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View {
        _NavigationTitledView(content: self, title: titleKey)   // title carried; bar display is a follow-up
    }
    public func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some View where V: Equatable {
        _OnChangeView(content: self, value: value, initial: initial, action: action)
    }
    public func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                     @ViewBuilder content: @escaping () -> Content) -> some View {
        _SheetView(base: self, isPresented: isPresented, onDismiss: onDismiss, sheet: content)
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - NavigationStack / NavigationLink / NavigationPath
// ════════════════════════════════════════════════════════════════════════════

// NavigationPath: only its nominal descriptor is referenced (the default `Data` of the
// root-only NavigationStack). Never constructed or passed by value here, so layout is free.
public struct NavigationPath {
    @usableFromInline var _items: [AnyHashable]
    public init() { _items = [] }
    public var count: Int { _items.count }
    public var isEmpty: Bool { _items.isEmpty }
}

// NavigationStack<Data, Root>: the root-only init (Data == NavigationPath) is a real
// (imported) call → layout ours. Stores the root; the host manages the push/pop stack.
public struct NavigationStack<Data, Root>: View where Root: View {
    @usableFromInline var root: Root
    // Apple declares this as a struct-body init with a `where Data == NavigationPath`
    // clause (NOT an extension) — the mangling differs (trailing same-type requirement
    // `…AFRszrlufC` vs an extension's `…RszrlE…fC`), and the inlined call binds the former.
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath { self.root = root() }
    public typealias Body = Never
    public var body: Never { fatalError("NavigationStack is primitive") }
}

// NavigationLink<Label, Destination>: the (titleKey, destination) init (Label == Text) is the
// imported one — destination is EAGER (the value, not a closure; the modern @ViewBuilder form
// inlines to it). Layout ours. Tapping the link pushes the (already-built) destination onto the
// host's nav stack — so navigation is handled host-side, no SwiftUI round-trip.
public struct NavigationLink<Label, Destination>: View where Label: View, Destination: View {
    @usableFromInline var label: Label
    @usableFromInline var destination: Destination
    public typealias Body = Never
    public var body: Never { fatalError("NavigationLink is primitive") }
}
extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: Destination) {
        self.label = Text(titleKey); self.destination = destination
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - GeometryReader  (the bidirectional one — body depends on the laid-out size)
// ════════════════════════════════════════════════════════════════════════════

// GeometryProxy: layout is OURS — the app never constructs one; it receives a proxy (built by
// our geometry callback) and reads `.size` through the imported getter symbol (not an inlined
// offset, so we're free). Minimal: just the size. The public stored `size` emits the getter.
public struct GeometryProxy {
    public var size: CGSize
    @usableFromInline init(size: CGSize) { self.size = size }
}

// GeometryReader<Content>: @frozen, holds the content closure. The init is INLINED by the app
// (no symbol imported), so the {closure} layout is ABI-load-bearing — a thick closure = 16 B.
// The body depends on the laid-out size, which only the host knows, so _makeView can't run the
// closure during the (size-less) tree walk: it registers the closure by id and emits a
// `.geometryReader(id)` placeholder. The host calls back with the available size at build time
// (swiftui_compat_geometry) → the closure runs → its subtree renders. (Per-region size needs a
// real LayoutBuilder; for now the host supplies the window's content size — correct for a
// root/full-bleed GeometryReader, the canonical use.)
@frozen public struct GeometryReader<Content: View>: View {
    @usableFromInline var content: (GeometryProxy) -> Content
    @inlinable public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }
    public typealias Body = Never
    public var body: Never { fatalError("GeometryReader is primitive") }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Modifiers the app INLINES (must match @frozen layout)
// ════════════════════════════════════════════════════════════════════════════

// .frame(width:height:alignment:) inlines `ModifiedContent(self, _FrameLayout(...))`
// and calls our _FrameLayout.init. {width: CGFloat?(16), height: CGFloat?(16),
// alignment: Alignment(16)} = 48.
@frozen public struct _FrameLayout: ViewModifier {
    @usableFromInline var width: CGFloat?
    @usableFromInline var height: CGFloat?
    @usableFromInline var alignment: Alignment
    public init(width: CGFloat?, height: CGFloat?, alignment: Alignment) {
        self.width = width; self.height = height; self.alignment = alignment
    }
}

// .frame(maxWidth:minWidth:…:alignment:) inlines `ModifiedContent(self, _FlexFrameLayout(...))`
// and CALLS our init. @frozen, 112 B = {6 × CGFloat?(16) in declaration order
// minWidth/idealWidth/maxWidth/minHeight/idealHeight/maxHeight, then alignment: Alignment(16)}.
// Matches Apple byte-for-byte (the app imports our nominal descriptor to size
// ModifiedContent<…, _FlexFrameLayout>). The render maps the dominant `.frame(maxWidth:
// .infinity)` (fill width) precisely; finite maxes are approximated as fixed.
@frozen public struct _FlexFrameLayout: ViewModifier {
    @usableFromInline var minWidth: CGFloat?
    @usableFromInline var idealWidth: CGFloat?
    @usableFromInline var maxWidth: CGFloat?
    @usableFromInline var minHeight: CGFloat?
    @usableFromInline var idealHeight: CGFloat?
    @usableFromInline var maxHeight: CGFloat?
    @usableFromInline var alignment: Alignment
    public init(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                alignment: Alignment = .center) {
        self.minWidth = minWidth; self.idealWidth = idealWidth; self.maxWidth = maxWidth
        self.minHeight = minHeight; self.idealHeight = idealHeight; self.maxHeight = maxHeight
        self.alignment = alignment
    }
}

// Minimal Shape so _ClipEffect<RoundedRectangle> can form. Only used opaquely.
public protocol Shape {}

// InsettableShape refines Shape. `.background(style, in: shape)` has a dedicated
// overload for insettable shapes → _InsettableBackgroundShapeModifier<Style, S: InsettableShape>,
// so its generic constraint (and thus the witness-table layout the app passes to our
// metadata accessor) must be InsettableShape, not Shape. Empty like Shape — we only
// need the conformance to exist so the metadata instantiates and the witness resolves.
public protocol InsettableShape: Shape {}

// Extracts a render-side shape descriptor (kind + corner radius) from a reconstructed
// shape, so .background(_:in:)/.overlay(_:in:) can clip the painted style.
protocol _AnyShapeDescriptor { var _shapeKind: String { get }; var _shapeCornerRadius: CGFloat { get } }

// Resilient (Apple imports its metadata accessor + a resilient enum-case witness),
// so the binary builds these via metadata/symbols, not inline — our layout is free.
public enum RoundedCornerStyle {
    case circular
    case continuous
}

// @frozen to match Apple (17 B: cornerSize CGSize@0, style RoundedCornerStyle@16=1 B).
// `.cornerRadius`/`.clipShape` are @inlinable, so the app builds RoundedRectangle by
// value inline — its layout must match Apple's @frozen byte-for-byte. `style` stays a
// resilient enum (Apple imports its metadata accessor), so the struct's size resolves at
// runtime even though it's @frozen — exactly Apple's arrangement.
@frozen public struct RoundedRectangle: Shape {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    public init(cornerSize: CGSize, style: RoundedCornerStyle = .circular) {
        self.cornerSize = cornerSize; self.style = style
    }
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {
        self.cornerSize = CGSize(width: cornerRadius, height: cornerRadius); self.style = style
    }
}
extension RoundedRectangle: InsettableShape {}
extension RoundedRectangle: _AnyShapeDescriptor {
    var _shapeKind: String { "roundedrect" }
    var _shapeCornerRadius: CGFloat { cornerSize.width }
}

// The other primitive shapes. Each is @frozen with Apple's exact size (Rectangle/Circle/
// Ellipse empty = 0 B; Capsule = 1 B {style}); inits are inlined (no symbol imported), so
// only the nominal descriptor + Shape/InsettableShape conformances (resolved at runtime
// from our module for the shape-fill modifiers' metadata) are needed. Each maps to a host
// clip/decoration "kind" via _AnyShapeDescriptor.
@frozen public struct Rectangle: Shape, InsettableShape { public init() {} }
extension Rectangle: _AnyShapeDescriptor { var _shapeKind: String { "rect" }; var _shapeCornerRadius: CGFloat { 0 } }

@frozen public struct Circle: Shape, InsettableShape { public init() {} }
extension Circle: _AnyShapeDescriptor { var _shapeKind: String { "circle" }; var _shapeCornerRadius: CGFloat { 0 } }
extension Rectangle._Inset: _AnyShapeDescriptor { var _shapeKind: String { "rect" }; var _shapeCornerRadius: CGFloat { 0 } }

@frozen public struct Ellipse: Shape, InsettableShape { public init() {} }
extension Ellipse: _AnyShapeDescriptor { var _shapeKind: String { "ellipse" }; var _shapeCornerRadius: CGFloat { 0 } }

@frozen public struct Capsule: Shape, InsettableShape {
    public var style: RoundedCornerStyle
    public init(style: RoundedCornerStyle = .continuous) { self.style = style }
}
extension Capsule: _AnyShapeDescriptor { var _shapeKind: String { "capsule" }; var _shapeCornerRadius: CGFloat { 0 } }

// @frozen to match Apple (2 B: {isEOFilled: Bool, isAntialiased: Bool}); embedded by
// value in the app-inlined _ClipEffect.
@frozen public struct FillStyle: Equatable {
    public var isEOFilled: Bool
    public var isAntialiased: Bool
    public init(eoFill isEOFilled: Bool = false, antialiased isAntialiased: Bool = true) {
        self.isEOFilled = isEOFilled; self.isAntialiased = isAntialiased
    }
}

// _ClipEffect<S: Shape>: built by the inlined .cornerRadius/.clipShape (both @inlinable)
// and used opaquely. @frozen to match Apple (19/24 B for <RoundedRectangle>): the app
// constructs it by value inline, so a resilient (non-@frozen) reconstruction would carry
// the wrong calling convention even though the size matches. @inlinable init mirrors
// Apple's so the app's inlined construction binds to the same layout.
@frozen public struct _ClipEffect<ClipShape: Shape> {
    public var shape: ClipShape
    public var style: FillStyle
    @inlinable public init(shape: ClipShape, style: FillStyle = FillStyle()) {
        self.shape = shape; self.style = style
    }
}
extension _ClipEffect: ViewModifier {}

// Erasure so the render path handles `.clipShape(anyShape)` / `.cornerRadius` uniformly
// (the ClipShape generic is open — RoundedRectangle, Circle, Ellipse, …). Conditional on
// the shape being describable; every reconstructed shape conforms, so the runtime cast
// `modifier as? _AnyClipEffect` succeeds for each _ClipEffect<Shape> instantiation.
protocol _AnyClipEffect { var _clipKind: String { get }; var _clipCornerRadius: CGFloat { get } }
extension _ClipEffect: _AnyClipEffect where ClipShape: _AnyShapeDescriptor {
    var _clipKind: String { shape._shapeKind }
    var _clipCornerRadius: CGFloat { shape._shapeCornerRadius }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - .background / .overlay  (modifiers the app INLINES; need the @frozen type)
// ════════════════════════════════════════════════════════════════════════════

// Color (and gradients) conform to ShapeStyle; .background(_:)/.foregroundStyle take a
// ShapeStyle. Minimal protocol — only the type identity + Color's conformance are needed
// so _BackgroundStyleModifier<Color> metadata can be instantiated from our descriptor.
public protocol ShapeStyle {}
extension Color: ShapeStyle {}

// .background(Style) inlines `ModifiedContent(self, _BackgroundStyleModifier(style:…))`.
// @frozen {style: Style, ignoresSafeAreaEdges: Edge.Set} — matches Apple.
@frozen public struct _BackgroundStyleModifier<Style: ShapeStyle>: ViewModifier {
    public var style: Style
    public var ignoresSafeAreaEdges: Edge.Set
    @inlinable public init(style: Style, ignoresSafeAreaEdges: Edge.Set = .all) {
        self.style = style; self.ignoresSafeAreaEdges = ignoresSafeAreaEdges
    }
}

// .overlay(View, alignment:) inlines `ModifiedContent(self, _OverlayModifier(overlay:…))`.
// @frozen {overlay: Overlay, alignment: Alignment} — matches Apple.
@frozen public struct _OverlayModifier<Overlay: View>: ViewModifier {
    public var overlay: Overlay
    public var alignment: Alignment
    @inlinable public init(overlay: Overlay, alignment: Alignment = .center) {
        self.overlay = overlay; self.alignment = alignment
    }
}

// .overlay(ShapeStyle) — `.overlay(LinearGradient(…))`/`.overlay(Color)` — picks the
// ShapeStyle overload (NOT _OverlayModifier<V: View>, even though Color/LinearGradient
// are also Views), which inlines `ModifiedContent(self, _OverlayStyleModifier(style:…))`.
// @frozen {style: Style, ignoresSafeAreaEdges: Edge.Set} = 9 B for <Color> — identical
// layout to _BackgroundStyleModifier (measured against Apple). init is @inlinable (no
// symbol imported — the app inlines the construction, reading the layout from our descriptor).
@frozen public struct _OverlayStyleModifier<Style: ShapeStyle>: ViewModifier {
    public var style: Style
    public var ignoresSafeAreaEdges: Edge.Set
    @inlinable public init(style: Style, ignoresSafeAreaEdges: Edge.Set = .all) {
        self.style = style; self.ignoresSafeAreaEdges = ignoresSafeAreaEdges
    }
}

// .background(style, in: shape) / .overlay(style, in: shape) — fill a ShapeStyle clipped
// to a Shape, behind / over the content. Both inline `ModifiedContent(self, modifier)`
// (no init symbol imported), so the @frozen {style, shape, fillStyle} layout (27 B for
// <Color, RoundedRectangle> = 8+17+2, matches Apple) is ABI-load-bearing. .background's
// insettable-shape overload binds the InsettableShape-constrained variant; .overlay uses
// the plain Shape constraint. The constraints are witness-table-significant (the app passes
// the matching witness to our metadata accessor), so they mirror Apple exactly.
@frozen public struct _InsettableBackgroundShapeModifier<Style: ShapeStyle, S: InsettableShape>: ViewModifier {
    public var style: Style
    public var shape: S
    public var fillStyle: FillStyle
    @inlinable public init(style: Style, shape: S, fillStyle: FillStyle = FillStyle()) {
        self.style = style; self.shape = shape; self.fillStyle = fillStyle
    }
}
@frozen public struct _OverlayShapeModifier<Style: ShapeStyle, S: Shape>: ViewModifier {
    public var style: Style
    public var shape: S
    public var fillStyle: FillStyle
    @inlinable public init(style: Style, shape: S, fillStyle: FillStyle = FillStyle()) {
        self.style = style; self.shape = shape; self.fillStyle = fillStyle
    }
}

// Erasure boxes: the Style/Overlay generic args are open (Color, Text, gradients, …) so
// the render path can't `as?` a concrete instantiation — it casts to these instead and
// lets the conformance extract the render data with the type still bound.
protocol _AnyBackgroundModifier { func _bgNode(_ inputs: _ViewInputs) -> RenderNode? }
extension _BackgroundStyleModifier: _AnyBackgroundModifier {
    // Any ShapeStyle that is also a View (Color, LinearGradient, …) renders behind via
    // its own _makeView; non-View styles (Material, …) → nil (background passthrough).
    func _bgNode(_ inputs: _ViewInputs) -> RenderNode? { (style as? any View)?._mvErased(inputs).node }
}
// _overlayAlign packs the overlay's 2-D alignment as h*3+v (h/v each 0 leading/top, 1 center,
// 2 trailing/bottom; center = 4). Style/shape overlays fill the content's bounds, so alignment
// is moot for them → center.
protocol _AnyOverlayModifier {
    func _overlayNode(_ inputs: _ViewInputs) -> RenderNode
    var _overlayAlign: Int { get }
}
extension _AnyOverlayModifier { var _overlayAlign: Int { 4 } }   // default: center
extension _OverlayModifier: _AnyOverlayModifier {
    func _overlayNode(_ inputs: _ViewInputs) -> RenderNode { overlay._mvErased(inputs).node }
    var _overlayAlign: Int { _crossAxis(alignment.horizontal.key) * 3 + _crossAxis(alignment.vertical.key) }
}
// .overlay(ShapeStyle): the style is the overlay — render it (Color/gradient → paint
// node; the host paints it on top of the content, filling the content's bounds).
extension _OverlayStyleModifier: _AnyOverlayModifier {
    func _overlayNode(_ inputs: _ViewInputs) -> RenderNode { (style as? any View)?._mvErased(inputs).node ?? .empty }
}

// .background(style, in: shape) / .overlay(style, in: shape): wrap the painted style in a
// `.shaped` node carrying the shape's clip (kind + corner radius) so the host fills the
// style clipped to the shape. Reuses the existing background/overlay dispatch + the host's
// boxDecoration(for:) (adds borderRadius / circle to the paint's decoration).
func _shapedStyleNode(_ style: Any, _ shape: Any, _ inputs: _ViewInputs) -> RenderNode {
    guard let paint = (style as? any View)?._mvErased(inputs).node else { return .empty }
    let kind = (shape as? _AnyShapeDescriptor)?._shapeKind ?? "rect"
    let radius = (shape as? _AnyShapeDescriptor)?._shapeCornerRadius ?? 0
    return .shaped(paint, shapeKind: kind, cornerRadius: radius)
}
extension _InsettableBackgroundShapeModifier: _AnyBackgroundModifier {
    func _bgNode(_ inputs: _ViewInputs) -> RenderNode? { _shapedStyleNode(style, shape, inputs) }
}
extension _OverlayShapeModifier: _AnyOverlayModifier {
    func _overlayNode(_ inputs: _ViewInputs) -> RenderNode { _shapedStyleNode(style, shape, inputs) }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Environment (.foregroundColor on non-Text inlines a keypath write)
// ════════════════════════════════════════════════════════════════════════════

// AnyLocation: Apple's type-erased @State/Binding backing. Referenced by descriptor.
public class AnyLocation<Value> {}

public struct EnvironmentValues {
    public init() {}
    private var _foregroundColor: Color?
    public var foregroundColor: Color? {
        get { _foregroundColor }
        set { _foregroundColor = newValue }
    }
    // `.environmentObject(_:)` storage: one slot per ObservableObject type (Apple keys the
    // same way — the last write of a type wins). Read/written via the subscript keypath
    // `ObservableObject.environmentStore` returns (StateObject.swift). Resilient type, so
    // adding storage is layout-safe.
    var _objects: [ObjectIdentifier: AnyObject] = [:]
    // .disabled / .lineLimit — resilient computed accessors (the binary CALLS them and
    // forms `\.isEnabled` / `\.lineLimit` keypath literals against our property descriptors).
    private var _isEnabled: Bool = true
    public var isEnabled: Bool {
        get { _isEnabled }
        set { _isEnabled = newValue }
    }
    private var _lineLimit: Int?
    public var lineLimit: Int? {
        get { _lineLimit }
        set { _lineLimit = newValue }
    }
    // @Environment(\.colorScheme) — the host renders the dark appearance, so dark is
    // the truthful default (matches the semantic-color table in the host's colorFor).
    private var _colorScheme: ColorScheme = .dark
    public var colorScheme: ColorScheme {
        get { _colorScheme }
        set { _colorScheme = newValue }
    }
    // .buttonStyle — carried as the style type's name (internal; set by _ButtonStyledView,
    // read by Button._makeView, mapped to chrome by the host).
    var _buttonStyle: String?
    // .tint / .multilineTextAlignment (sweep 3) — resilient accessors + auto property
    // descriptors for the binary's inlined keypath writes.
    private var _tintColor: Color?
    public var tintColor: Color? {
        get { _tintColor }
        set { _tintColor = newValue }
    }
    private var _multilineTextAlignment: TextAlignment = .leading
    public var multilineTextAlignment: TextAlignment {
        get { _multilineTextAlignment }
        set { _multilineTextAlignment = newValue }
    }
}
// Resilient enums (case + synthesized-== symbols export; layout free).
public enum TextAlignment: Hashable, CaseIterable {
    case leading, center, trailing
}

// ColorScheme: RESILIENT (not @frozen) — the binary reaches cases/==/metadata through
// our exported case + synthesized-Equatable symbols (like Color.RGBColorSpace).
public enum ColorScheme: CaseIterable, Hashable {
    case light
    case dark
}

// _EnvironmentKeyWritingModifier<Value>: @frozen {keyPath, value}; built inline by
// the inlined `.foregroundColor(_:)` on non-Text views, and by the inlined
// `.environmentObject(_:)` → `environment(T.environmentStore, object)`.
@frozen public struct _EnvironmentKeyWritingModifier<Value>: ViewModifier {
    public var keyPath: WritableKeyPath<EnvironmentValues, Value>
    public var value: Value
    @inlinable public init(keyPath: WritableKeyPath<EnvironmentValues, Value>, value: Value) {
        self.keyPath = keyPath; self.value = value
    }
}
// Erasure so MakeView can apply ANY environment write (the modifier's Value is open):
// the conformance applies the stored keypath to the walk's inherited environment copy.
protocol _AnyEnvWriter { func _write(into env: inout EnvironmentValues) }
extension _EnvironmentKeyWritingModifier: _AnyEnvWriter {
    func _write(into env: inout EnvironmentValues) { env[keyPath: keyPath] = value }
}

// _EnvironmentKeyTransformModifier<Value>: @frozen {keyPath@0 (8), transform@8 (16)} = 24,
// matches Apple. Built inline by the inlined `.transformEnvironment` / `.disabled(_:)`
// (whose body is `transform: { $0 = $0 && !disabled }` on `\.isEnabled`).
@frozen public struct _EnvironmentKeyTransformModifier<Value>: ViewModifier {
    public var keyPath: WritableKeyPath<EnvironmentValues, Value>
    public var transform: (inout Value) -> Void
    @inlinable public init(keyPath: WritableKeyPath<EnvironmentValues, Value>,
                           transform: @escaping (inout Value) -> Void) {
        self.keyPath = keyPath; self.transform = transform
    }
}
extension _EnvironmentKeyTransformModifier: _AnyEnvWriter {
    func _write(into env: inout EnvironmentValues) { transform(&env[keyPath: keyPath]) }
}

// ── Render-effect modifiers (2026-07-02 sweep) — @frozen, constructed INLINE by the
// binary (.opacity/.scaleEffect/.shadow are @inlinable), so field order/size must match
// Apple: _OpacityEffect {opacity:Double}=8; _ScaleEffect {scale:CGSize@0, anchor:UnitPoint@16}=32
// (the CGFloat overload of .scaleEffect collapses inline to CGSize(s,s) + .center);
// _ShadowEffect {color:Color@0, radius:CGFloat@8, offset:CGSize@16}=32.
@frozen public struct _OpacityEffect: ViewModifier {
    public var opacity: Double
    @inlinable public init(opacity: Double) { self.opacity = opacity }
}
@frozen public struct _ScaleEffect: ViewModifier {
    public var scale: CGSize
    public var anchor: UnitPoint
    @inlinable public init(scale: CGSize, anchor: UnitPoint = .center) {
        self.scale = scale; self.anchor = anchor
    }
}
@frozen public struct _ShadowEffect: ViewModifier {
    public var color: Color
    public var radius: CGFloat
    public var offset: CGSize
    @inlinable public init(color: Color, radius: CGFloat, offset: CGSize) {
        self.color = color; self.radius = radius; self.offset = offset
    }
}

// _AppearanceActionModifier: @frozen {appear, disappear}, both `(() -> Void)?` (16 B each = 32 B,
// matches Apple). `.onAppear(perform:)` is @inlinable so the binary inlines it to
// `ModifiedContent<Content, _AppearanceActionModifier>(content, _AppearanceActionModifier(appear:))`;
// our ModifiedContent._makeView renders the content and fires `appear` once at walk time (see
// MakeView). The init must be @inlinable + match Apple's field order so the inlined construction
// writes appear@0/disappear@16 into our layout.
@frozen public struct _AppearanceActionModifier: ViewModifier {
    public var appear: (() -> Void)?
    public var disappear: (() -> Void)?
    @inlinable public init(appear: (() -> Void)? = nil, disappear: (() -> Void)? = nil) {
        self.appear = appear
        self.disappear = disappear
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Leaf views: Image, Color
// ════════════════════════════════════════════════════════════════════════════

// @frozen single provider (8 bytes) — like Color/Font, the binary returns Image
// by value in a register (no metadata accessor imported).
public final class _ImageBox { public let systemName: String; public init(_ n: String) { systemName = n } }
@frozen public struct Image: View {
    @usableFromInline var provider: _ImageBox
    public init(systemName: String) { self.provider = _ImageBox(systemName) }
    public var _systemName: String { provider.systemName }
    public typealias Body = Never
    public var body: Never { fatalError("Image is primitive") }
}

// Label<Title, Icon> — resilient (NOT @frozen), so the binary calls our init + _makeView (it
// imports `init(_:systemImage:)` + the nominal descriptor + the View conformance). The Text/Image
// convenience init lives in an extension `where Title == Text, Icon == Image` (matching Apple's
// mangling); _makeView (MakeView.swift) renders it as an HStack[icon, title].
public struct Label<Title: View, Icon: View>: View {
    @usableFromInline var title: Title
    @usableFromInline var icon: Icon
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {
        self.title = title(); self.icon = icon()
    }
    public typealias Body = Never
    public var body: Never { fatalError("Label is primitive") }
}
extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) {
        self.title = Text(titleKey); self.icon = Image(systemName: name)
    }
}

// Stepper<Label> — resilient; the `where Label == Text` value:step: init builds the inc/dec
// closures from the Binding (mutates value.wrappedValue by ±step). Interactive: _makeView ships
// the two closures, FlutterBridge registers them as tap actions, the host renders − / + buttons.
public struct Stepper<Label: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var onIncrement: (() -> Void)?
    @usableFromInline var onDecrement: (() -> Void)?
    public typealias Body = Never
    public var body: Never { fatalError("Stepper is primitive") }
}
extension Stepper where Label == Text {
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>,
                              step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.label = Text(titleKey)
        self.onIncrement = { value.wrappedValue = value.wrappedValue.advanced(by: step) }
        self.onDecrement = { value.wrappedValue = value.wrappedValue.advanced(by: 0 - step) }
    }
}

// ProgressView<Label, CurrentValueLabel> — resilient; binary calls our init + _makeView. The
// determinate `value:total:` init is in an extension `where CurrentValueLabel == EmptyView` with
// `where Label == EmptyView` on the init (matching Apple's mangling). _makeView emits a `.progress`
// node with the fraction (value/total), or nil for indeterminate.
public struct ProgressView<Label: View, CurrentValueLabel: View>: View {
    @usableFromInline var value: Double?
    @usableFromInline var total: Double = 1.0
    public typealias Body = Never
    public var body: Never { fatalError("ProgressView is primitive") }
}
// Both same-type constraints on the INIT (unconstrained extension) so the mangling matches the
// binary's import (`…V5value5total…AGRszAGRs_SBRd__lufC` — no extension-context infix). Putting
// `CurrentValueLabel == EmptyView` on the extension instead bakes it into the extension descriptor
// (`…E…`) and the symbol won't bind.
extension ProgressView {
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0)
        where Label == EmptyView, CurrentValueLabel == EmptyView {
        self.value = value.map { Double($0) }
        self.total = Double(total)
    }
}

// The binary references NO metadata accessor for Color/Font/Font.Weight — only
// their static getters — so Apple declares them @frozen and returns them BY VALUE
// in registers. Our reconstructions must therefore be @frozen with the same shape:
// SwiftUI's Color and Font are each a single provider class reference (8 bytes);
// Font.Weight is a single CGFloat (8 bytes). A wrong size/representation makes the
// binary's inlined Optional<Color>/Optional<Font> construction read at wrong offsets.

public final class _ColorBox { public let name: String; public init(_ n: String) { name = n } }
public final class _FontBox  { public let name: String; public init(_ n: String) { name = n } }

@frozen public struct Color: View, Equatable {
    @usableFromInline var provider: _ColorBox
    @usableFromInline init(_name: String) { self.provider = _ColorBox(_name) }
    public var _name: String { provider.name }
    public typealias Body = Never
    public var body: Never { fatalError("Color is primitive") }
    public static func == (l: Color, r: Color) -> Bool { l.provider.name == r.provider.name }

    public static var blue: Color { Color(_name: "blue") }
    public static var green: Color { Color(_name: "green") }
    public static var red: Color { Color(_name: "red") }
    public static var white: Color { Color(_name: "white") }
    public static var black: Color { Color(_name: "black") }
    public static var yellow: Color { Color(_name: "yellow") }
    public static var orange: Color { Color(_name: "orange") }
    public static var primary: Color { Color(_name: "primary") }
    public static var secondary: Color { Color(_name: "secondary") }
}
// Value colors (e.g. .shadow's default `Color(.sRGBLinear, white: 0, opacity: 0.33)`).
// Encoded into the provider name as "rgba:r,g,b,a" (0…1 components); the host's
// colorFor parses the prefix. RGBColorSpace is RESILIENT (case symbols exported —
// the binary calls the case constructors); the color-space distinction is ignored.
extension Color {
    public enum RGBColorSpace {
        case sRGB, sRGBLinear, displayP3
    }
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {
        self.init(_name: "rgba:\(white),\(white),\(white),\(opacity)")
    }
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.init(_name: "rgba:\(red),\(green),\(blue),\(opacity)")
    }
}

// AnyView: @frozen {storage: class ref} = 8, matches Apple. init<V>(_ view: V) is
// RESILIENT (the binary CALLS it — unlike init(erasing:), which is AEIC and inlines
// to it), so the box is entirely ours.
@usableFromInline final class _AnyViewBox {
    let view: any View
    init(_ v: any View) { view = v }
}
@frozen public struct AnyView: View {
    @usableFromInline var storage: _AnyViewBox
    public init<V: View>(_ view: V) { storage = _AnyViewBox(view) }
    public typealias Body = Never
    public var body: Never { fatalError("AnyView is primitive") }
}

// Grid/GridRow: @frozen with @inlinable inits — the binary constructs BOTH inline
// (probe imports only descriptors + View conformances), so layouts are load-bearing:
// Grid = {_tree: Tree<GridLayout, Content>}, GridLayout = {alignment: Alignment(16),
// horizontalSpacing: CGFloat?(@16), verticalSpacing: CGFloat?(@32)} (48 stride);
// GridRow = {alignment: VerticalAlignment?(@0, stride 16), content(@16)}.
@frozen public struct GridLayout: _VariadicView_Root {
    public var alignment: Alignment
    public var horizontalSpacing: CGFloat?
    public var verticalSpacing: CGFloat?
    @inlinable public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil,
                           verticalSpacing: CGFloat? = nil) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
}
@frozen public struct Grid<Content: View>: View {
    @usableFromInline var _tree: _VariadicView.Tree<GridLayout, Content>
    @inlinable public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil,
                           verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        let root = GridLayout(alignment: alignment, horizontalSpacing: horizontalSpacing,
                              verticalSpacing: verticalSpacing)
        _tree = _VariadicView.Tree(root: root, content: content())
    }
    public typealias Body = Never
    public var body: Never { fatalError("Grid is primitive") }
}
@frozen public struct GridRow<Content: View>: View {
    @usableFromInline var alignment: VerticalAlignment?
    @usableFromInline var content: Content
    @inlinable public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("GridRow is primitive") }
}

// ── Sweep 3 (2026-07-02): resilient controls + View-extension wrappers ───────
// SecureField/GroupBox: the Text-label inits are CONSTRAINED-EXTENSION mangled
// (…rlE…, the Section form). TextEditor/LazyHGrid: struct-body inits. All resilient
// (layouts ours).
public struct SecureField<Label: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var text: Binding<String>
    public typealias Body = Never
    public var body: Never { fatalError("SecureField is primitive") }
}
extension SecureField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.label = Text(titleKey); self.text = text
    }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {
        self.label = Text(titleKey); self.text = text
    }
}
public struct TextEditor: View {
    @usableFromInline var text: Binding<String>
    public init(text: Binding<String>) { self.text = text }
    public typealias Body = Never
    public var body: Never { fatalError("TextEditor is primitive") }
}
public struct GroupBox<Label: View, Content: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var content: Content
    public typealias Body = Never
    public var body: Never { fatalError("GroupBox is primitive") }
}
extension GroupBox where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = Text(titleKey); self.content = content()
    }
}
public struct LazyHGrid<Content: View>: View {
    @usableFromInline var rows: [GridItem]
    @usableFromInline var spacing: CGFloat?
    @usableFromInline var content: Content
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.rows = rows; self.spacing = spacing; self.content = content()
    }
    public typealias Body = Never
    public var body: Never { fatalError("LazyHGrid is primitive") }
}

// SubmitTriggers: resilient OptionSet (the binary imports the metadata accessor and
// the .text getter — layout free).
public struct SubmitTriggers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static var text: SubmitTriggers { SubmitTriggers(rawValue: 1 << 0) }
}

// Style protocols (the PrimitiveButtonStyle pattern: empty protocol + resilient style
// init; the style TYPE NAME rides the environment or is accepted-and-ignored).
public protocol ToggleStyle {}
public struct SwitchToggleStyle: ToggleStyle {
    public init() {}
}
public protocol TextFieldStyle {}
public struct RoundedBorderTextFieldStyle: TextFieldStyle {
    public init() {}
}

// Wrapper views for the resilient opaque View-extension methods (the .tabItem pattern).
public struct _AlertView<Base: View, Actions: View>: View {
    @usableFromInline var base: Base
    @usableFromInline var title: LocalizedStringKey
    @usableFromInline var isPresented: Binding<Bool>
    @usableFromInline var actions: Actions
    @usableFromInline init(base: Base, title: LocalizedStringKey, isPresented: Binding<Bool>, actions: Actions) {
        self.base = base; self.title = title; self.isPresented = isPresented; self.actions = actions
    }
    public typealias Body = Never
    public var body: Never { fatalError("_AlertView is primitive") }
}
public struct _ToolbarView<Base: View, Bar: View>: View {
    @usableFromInline var base: Base
    @usableFromInline var bar: Bar
    @usableFromInline init(base: Base, bar: Bar) { self.base = base; self.bar = bar }
    public typealias Body = Never
    public var body: Never { fatalError("_ToolbarView is primitive") }
}
public struct _ContextMenuView<Base: View, Items: View>: View {
    @usableFromInline var base: Base
    @usableFromInline var items: Items
    @usableFromInline init(base: Base, items: Items) { self.base = base; self.items = items }
    public typealias Body = Never
    public var body: Never { fatalError("_ContextMenuView is primitive") }
}
public struct _OnSubmitView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var action: () -> Void
    @usableFromInline init(content: Content, action: @escaping () -> Void) { self.content = content; self.action = action }
    public typealias Body = Never
    public var body: Never { fatalError("_OnSubmitView is primitive") }
}
public struct _ToggleStyledView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var styleName: String
    @usableFromInline init(content: Content, styleName: String) { self.content = content; self.styleName = styleName }
    public typealias Body = Never
    public var body: Never { fatalError("_ToggleStyledView is primitive") }
}
public struct _TextFieldStyledView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var styleName: String
    @usableFromInline init(content: Content, styleName: String) { self.content = content; self.styleName = styleName }
    public typealias Body = Never
    public var body: Never { fatalError("_TextFieldStyledView is primitive") }
}
extension View {
    public func alert<A>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>,
                         @ViewBuilder actions: () -> A) -> some View where A: View {
        _AlertView(base: self, title: titleKey, isPresented: isPresented, actions: actions())
    }
    public func toolbar<Content>(@ViewBuilder content: () -> Content) -> some View where Content: View {
        _ToolbarView(base: self, bar: content())
    }
    public func contextMenu<MenuItems>(@ViewBuilder menuItems: () -> MenuItems) -> some View where MenuItems: View {
        _ContextMenuView(base: self, items: menuItems())
    }
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping (() -> Void)) -> some View {
        _OnSubmitView(content: self, action: action)
    }
    public func toggleStyle<S>(_ style: S) -> some View where S: ToggleStyle {
        _ToggleStyledView(content: self, styleName: String(describing: S.self))
    }
    public func textFieldStyle<S>(_ style: S) -> some View where S: TextFieldStyle {
        _TextFieldStyledView(content: self, styleName: String(describing: S.self))
    }
}

// ── @FocusState + .focused (sweep 3 batch 3) ─────────────────────────────────
// @frozen {value: Value @0, location: AnyLocation<Value>? (ptr), resetValue: Value}
// (FocusState<Bool> = 17/24, measured = interface). ALL members resilient (fields are
// plain internal — nothing inlines), so semantics are ours: no focus system in the
// host, focus reads yield the initial value and writes are dropped.
@frozen @propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty {
    @frozen @propertyWrapper public struct Binding {
        @usableFromInline var _binding: SwiftUI.Binding<Value>
        @usableFromInline init(_ b: SwiftUI.Binding<Value>) { _binding = b }
        public var wrappedValue: Value {
            get { _binding.wrappedValue }
            nonmutating set { _binding.wrappedValue = newValue }
        }
        public var projectedValue: Binding { self }
    }
    var value: Value
    var location: AnyLocation<Value>?
    var resetValue: Value
    public var wrappedValue: Value {
        get { value }
        nonmutating set {}   // no focus engine — programmatic focus is dropped
    }
    public var projectedValue: Binding {
        let v = value
        return Binding(SwiftUI.Binding(get: { v }, set: { _ in }))
    }
    public init() where Value == Bool {
        value = false; location = nil; resetValue = false
    }
    public init<T>() where Value == T?, T: Hashable {
        value = nil; location = nil; resetValue = nil
    }
}
public struct _FocusedView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline init(content: Content) { self.content = content }
    public typealias Body = Never
    public var body: Never { fatalError("_FocusedView is primitive") }
}
extension View {
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        _FocusedView(content: self)
    }
    public func focused<Value>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View where Value: Hashable {
        _FocusedView(content: self)
    }
}

// ── DragGesture + .gesture (sweep 3 batch 3) ─────────────────────────────────
// The gesture types are RESILIENT (layouts ours); the engine gesture graph
// (_makeGesture/_GestureInputs) is NOT reconstructed — instead the walk recognizes
// the concrete _ChangedGesture<DragGesture> shape and routes the host's pan events
// into the action with a synthesized DragGesture.Value.
public protocol Gesture {
    associatedtype Value
}
public enum CoordinateSpace: Hashable {
    case global
    case local
    case named(AnyHashable)
}
public protocol CoordinateSpaceProtocol {}
public struct LocalCoordinateSpace: CoordinateSpaceProtocol {
    public init() {}
}
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace {
    public static var local: LocalCoordinateSpace { LocalCoordinateSpace() }
}
public struct DragGesture: Gesture {
    public struct Value: Equatable {
        public var time: Date
        public var location: CGPoint
        public var startLocation: CGPoint
        public var translation: CGSize {
            CGSize(width: location.x - startLocation.x, height: location.y - startLocation.y)
        }
        public var predictedEndLocation: CGPoint { location }
        public var predictedEndTranslation: CGSize { translation }
    }
    public var minimumDistance: CGFloat
    public var coordinateSpace: CoordinateSpace
    public init(minimumDistance: CGFloat = 10, coordinateSpace: some CoordinateSpaceProtocol = .local) {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = .local
    }
}
@frozen public struct GestureMask: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let none = GestureMask([])
    public static let gesture = GestureMask(rawValue: 1 << 0)
    public static let subviews = GestureMask(rawValue: 1 << 1)
    public static let all = GestureMask(rawValue: 0b11)
}
public struct _ChangedGesture<Content: Gesture>: Gesture where Content.Value: Equatable {
    public typealias Value = Content.Value
    @usableFromInline var base: Content
    @usableFromInline var action: (Content.Value) -> Void
    @usableFromInline init(base: Content, action: @escaping (Content.Value) -> Void) {
        self.base = base; self.action = action
    }
}
extension Gesture where Value: Equatable {
    public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> {
        _ChangedGesture(base: self, action: action)
    }
}
public struct _GestureView<Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var dragChanged: ((DragGesture.Value) -> Void)?
    @usableFromInline init(content: Content, dragChanged: ((DragGesture.Value) -> Void)?) {
        self.content = content; self.dragChanged = dragChanged
    }
    public typealias Body = Never
    public var body: Never { fatalError("_GestureView is primitive") }
}
extension View {
    public func gesture<T>(_ gesture: T, including mask: GestureMask = .all) -> some View where T: Gesture {
        _GestureView(content: self, dragChanged: (gesture as? _ChangedGesture<DragGesture>)?.action)
    }
}

// ── Shape.stroke / .border (sweep 3 batch 3) ─────────────────────────────────
// StrokeStyle: @frozen {lineWidth @0, lineCap @8 (4, __C struct), lineJoin @12 (4),
// miterLimit @16, dash @24 ([CGFloat] ptr), dashPhase @32} = 40 B. The init is
// RESILIENT (the binary calls it; its mangling embeds So9CGLineCapV/So10CGLineJoinV —
// reproduced by the CGCompatShims plain-C-enum imports).
@frozen public struct StrokeStyle: Equatable {
    public var lineWidth: CGFloat
    public var lineCap: CGLineCap
    public var lineJoin: CGLineJoin
    public var miterLimit: CGFloat
    public var dash: [CGFloat]
    public var dashPhase: CGFloat
    // The C types import differently per platform (Linux shim: struct + kCGLineCap…
    // globals; macOS CoreGraphics: enum + .butt/.miter) — bridge via statics. The init
    // is resilient, so its default-arg generators are ours and may reference these.
    public static var _defaultCap: CGLineCap {
        #if canImport(CGCompatShims)
        kCGLineCapButt
        #else
        .butt
        #endif
    }
    public static var _defaultJoin: CGLineJoin {
        #if canImport(CGCompatShims)
        kCGLineJoinMiter
        #else
        .miter
        #endif
    }
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = StrokeStyle._defaultCap,
                lineJoin: CGLineJoin = StrokeStyle._defaultJoin, miterLimit: CGFloat = 10,
                dash: [CGFloat] = [CGFloat](), dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin
        self.miterLimit = miterLimit; self.dash = dash; self.dashPhase = dashPhase
    }
    public static func == (l: StrokeStyle, r: StrokeStyle) -> Bool {
        l.lineWidth == r.lineWidth && l.lineCap.rawValue == r.lineCap.rawValue
            && l.lineJoin.rawValue == r.lineJoin.rawValue && l.miterLimit == r.miterLimit
            && l.dash == r.dash && l.dashPhase == r.dashPhase
    }
}
// The classic @inlinable stroke path: Shape.stroke → _StrokedShape{shape, style};
// .border → overlay(Rectangle().strokeBorder(…)) → inset(by:).stroke(style:).fill(…)
// — all constructed INLINE by the binary (only the descriptors are imported).
@frozen public struct _StrokedShape<S: Shape>: Shape {
    public var shape: S
    public var style: StrokeStyle
    @inlinable public init(shape: S, style: StrokeStyle) { self.shape = shape; self.style = style }
}
extension Rectangle {
    @frozen public struct _Inset: InsettableShape {
        @usableFromInline var amount: CGFloat
        @usableFromInline init(amount: CGFloat) { self.amount = amount }
    }
}
// The pre-iOS-15 view-background modifier — the stroke ShapeView family nests it.
@frozen public struct _BackgroundModifier<Background: View>: ViewModifier {
    public var background: Background
    public var alignment: Alignment
    @inlinable public init(background: Background, alignment: Alignment = .center) {
        self.background = background; self.alignment = alignment
    }
}
// iOS-17 concrete stroke result (AEIC-constructed by the binary): ONE stored field —
// the fully-nested ModifiedContent tree. Layout = that nest's layout.
public protocol ShapeView: View {}
@frozen public struct StrokeShapeView<Content: Shape, Style: ShapeStyle, Background: View>: ShapeView {
    @usableFromInline var view: ModifiedContent<_ShapeView<_StrokedShape<Content>, Style>, _BackgroundModifier<Background>>
    public typealias Body = Never
    public var body: Never { fatalError("StrokeShapeView is primitive") }
}

// ── Sweep 3 batch 2: @frozen inline-constructed types (layouts from the interface) ──
@frozen public struct _OffsetEffect: ViewModifier {
    public var offset: CGSize
    @inlinable public init(offset: CGSize) { self.offset = offset }
}
@frozen public struct _RotationEffect: ViewModifier {
    public var angle: Angle
    public var anchor: UnitPoint
    @inlinable public init(angle: Angle, anchor: UnitPoint = .center) {
        self.angle = angle; self.anchor = anchor
    }
}
@frozen public struct _BlurEffect: ViewModifier {
    public var radius: CGFloat
    public var isOpaque: Bool
    @inlinable public init(radius: CGFloat, opaque: Bool) { self.radius = radius; self.isOpaque = opaque }
}
@frozen public struct _FixedSizeLayout: ViewModifier {
    @usableFromInline var horizontal: Bool
    @usableFromInline var vertical: Bool
    @inlinable public init(horizontal: Bool = true, vertical: Bool = true) {
        self.horizontal = horizontal; self.vertical = vertical
    }
}
// SafeAreaRegions: @frozen OptionSet {rawValue: UInt}; the statics are RESILIENT
// (`public static let` exports the getter the binary calls).
@frozen public struct SafeAreaRegions: OptionSet {
    public let rawValue: UInt
    @inlinable public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let container = SafeAreaRegions(rawValue: 1 << 0)
    public static let keyboard = SafeAreaRegions(rawValue: 1 << 1)
    public static let all = SafeAreaRegions(rawValue: .max)
}
@frozen public struct _SafeAreaRegionsIgnoringLayout: ViewModifier {
    public var regions: SafeAreaRegions
    public var edges: Edge.Set
    @inlinable public init(regions: SafeAreaRegions, edges: Edge.Set) {
        self.regions = regions; self.edges = edges
    }
}
// IDView (.id(_:) — Apple declares it `package`, mangles like public): {content, id}.
@frozen public struct IDView<Content: View, ID: Hashable>: View {
    @usableFromInline var content: Content
    @usableFromInline var id: ID
    @inlinable public init(_ content: Content, id: ID) { self.content = content; self.id = id }
    public typealias Body = Never
    public var body: Never { fatalError("IDView is primitive") }
}
// Shape.fill(_:style:) inlines to _ShapeView {shape, style, fillStyle} (FillStyle = 2 B).
@frozen public struct _ShapeView<Content: Shape, Style: ShapeStyle>: View {
    public var shape: Content
    public var style: Style
    public var fillStyle: FillStyle
    @inlinable public init(shape: Content, style: Style, fillStyle: FillStyle = FillStyle()) {
        self.shape = shape; self.style = style; self.fillStyle = fillStyle
    }
    public typealias Body = Never
    public var body: Never { fatalError("_ShapeView is primitive") }
}
// .onHover — @frozen {callback: (Bool) -> Void} (16 B). Hover events not host-routed yet.
@frozen public struct _HoverRegionModifier: ViewModifier {
    public let callback: (Bool) -> Void
    @inlinable public init(_ callback: @escaping (Bool) -> Void) { self.callback = callback }
}
// Animation: @frozen {box: class ref} = 8 B; `.default` is a RESILIENT static let.
// No animation system in this host — values snap (the modifier is a pass-through).
@usableFromInline final class _AnimationBoxBase: @unchecked Sendable {}
@frozen public struct Animation: Equatable, Sendable {
    @usableFromInline var box: _AnimationBoxBase
    @usableFromInline init(box: _AnimationBoxBase) { self.box = box }
    public static func == (l: Animation, r: Animation) -> Bool { l.box === r.box }
    public static let `default` = Animation(box: _AnimationBoxBase())
}
@frozen public struct _AnimationModifier<Value: Equatable>: ViewModifier, _AnyPassthroughModifier {
    public var animation: Animation?
    public var value: Value
    @inlinable public init(animation: Animation?, value: Value) {
        self.animation = animation; self.value = value
    }
}
public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try body()   // no animation system: apply instantly
}
// .transition(.opacity): AnyTransition/OpacityTransition are resilient; the trait rides
// the existing _TraitWritingModifier machinery and is ignored at render time (no
// animations), so the content renders via the ModifiedContent pass-through.
public protocol Transition {}
public struct OpacityTransition: Transition {
    public init() {}
}
public struct AnyTransition {
    @usableFromInline var box: Any
    public init<T: Transition>(_ transition: T) { self.box = transition }
}
public struct TransitionTraitKey: _ViewTraitKey {
    public static var defaultValue: AnyTransition? { nil }
}

// ── .buttonStyle + .task ──────────────────────────────────────────────────────
// PrimitiveButtonStyle: minimal protocol — the binary imports only the CONFORMANCE
// descriptor (self-consistent within our module; no witness is ever dispatched) and
// BorderedProminentButtonStyle's resilient init (`.borderedProminent` is AEIC →
// inlines to `BorderedProminentButtonStyle()`). The style rides the environment as a
// type name; Button reads it and the host restyles the chrome.
public protocol PrimitiveButtonStyle {}
public struct BorderedProminentButtonStyle: PrimitiveButtonStyle {
    public init() {}
}
public struct _ButtonStyledView<S: PrimitiveButtonStyle, Content: View>: View {
    @usableFromInline var content: Content
    @usableFromInline var styleName: String
    @usableFromInline init(content: Content, styleName: String) {
        self.content = content; self.styleName = styleName
    }
    public typealias Body = Never
    public var body: Never { fatalError("_ButtonStyledView is primitive") }
}
extension View {
    public func buttonStyle<S>(_ style: S) -> some View where S: PrimitiveButtonStyle {
        _ButtonStyledView<S, Self>(content: self, styleName: String(describing: S.self))
    }
}

// _TaskModifier: @frozen {action: @Sendable () async -> Void @0 (16), priority @16 (1)}
// = 17/24, matches Apple. The SDK's public task(...) is AEIC gated on #available(26.4):
// under machold's FALSE availability convention the inlined fallback constructs THIS
// against our layout (never _TaskModifier2).
@frozen public struct _TaskModifier: ViewModifier {
    public var action: @Sendable () async -> Void
    public var priority: TaskPriority
    @inlinable public init(priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
        self.priority = priority
        self.action = action
    }
}

// Form: resilient container (binary calls our init) — rendered as a List of the
// flattened sections. Section<Parent, Content, Footer>: the struct is UNCONSTRAINED;
// the View conformance is conditional (where all three: View) and the Text-header init
// lives in a CONSTRAINED extension — its import mangles with the …rlE… extension infix
// (`where Parent == Text, Content: View, Footer == EmptyView`), the opposite of Menu's
// where-on-init form. Both shapes verified against the binary's symbols.
public struct Form<Content: View>: View {
    @usableFromInline var content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public typealias Body = Never
    public var body: Never { fatalError("Form is primitive") }
}
public struct Section<Parent, Content, Footer> {
    @usableFromInline var header: Parent
    @usableFromInline var content: Content
}
extension Section: View where Parent: View, Content: View, Footer: View {
    public typealias Body = Never
    public var body: Never { fatalError("Section is primitive") }
}
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.header = Text(titleKey)
        self.content = content()
    }
}

// Menu: RESILIENT (binary calls the init; layout free). MANGLING: the LocalizedStringKey
// init carries `where Label == Text` ON THE INIT (…AFRszrlufC, no extension-context
// infix) — an unconstrained extension with the where-clause on the member, NOT a
// constrained extension (the ProgressView lesson).
public struct Menu<Label, Content>: View where Label: View, Content: View {
    @usableFromInline var _menuLabel: any View
    @usableFromInline var content: Content
    public typealias Body = Never
    public var body: Never { fatalError("Menu is primitive") }
}
extension Menu {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text {
        self._menuLabel = Text(titleKey)
        self.content = content()
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Font (@frozen, single provider) + getters
// ════════════════════════════════════════════════════════════════════════════

@frozen public struct Font: Equatable {
    @usableFromInline var provider: _FontBox
    @usableFromInline init(_name: String) { self.provider = _FontBox(_name) }
    public var _name: String { provider.name }
    public static func == (l: Font, r: Font) -> Bool { l.provider.name == r.provider.name }

    // Font.system(size:weight:design:) — resilient static (the binary CALLS it) +
    // resilient Design enum. Encoded into the provider name as "sys:SIZE:WEIGHT";
    // the host parses size + maps weight ≥ 0.4 → bold.
    public enum Design: Hashable {
        case `default`, serif, rounded, monospaced
    }
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font {
        Font(_name: "sys:\(size):\(weight?.value ?? 0)")
    }

    public static var largeTitle: Font { Font(_name: "largeTitle") }
    public static var title: Font { Font(_name: "title") }
    public static var headline: Font { Font(_name: "headline") }
    public static var subheadline: Font { Font(_name: "subheadline") }
    public static var body: Font { Font(_name: "body") }
    public static var caption: Font { Font(_name: "caption") }

    // @frozen { value: CGFloat } = 8 bytes (matches Apple's Font.Weight return ABI).
    @frozen public struct Weight: Equatable {
        @usableFromInline var value: CGFloat
        @usableFromInline init(value: CGFloat) { self.value = value }
        public static var ultraLight: Weight { Weight(value: -0.8) }
        public static var light: Weight { Weight(value: -0.4) }
        public static var regular: Weight { Weight(value: 0) }
        public static var medium: Weight { Weight(value: 0.23) }
        public static var semibold: Weight { Weight(value: 0.3) }
        public static var bold: Weight { Weight(value: 0.4) }
        public static var heavy: Weight { Weight(value: 0.56) }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Controls bound to @State: Toggle / TextField / Slider
// ════════════════════════════════════════════════════════════════════════════

@frozen public struct Toggle<Label: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var isOn: Binding<Bool>
    public typealias Body = Never
    public var body: Never { fatalError("Toggle is primitive") }
}
extension Toggle where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {
        self.label = Text(titleKey); self.isOn = isOn
    }
}

@frozen public struct TextField<Label: View>: View {
    @usableFromInline var label: Label
    @usableFromInline var text: Binding<String>
    public typealias Body = Never
    public var body: Never { fatalError("TextField is primitive") }
}
extension TextField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>,
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                onCommit: @escaping () -> Void = {}) {
        self.label = Text(titleKey); self.text = text
    }
}

@frozen public struct Slider<Label: View, ValueLabel: View>: View {
    @usableFromInline var value: Binding<Double>
    @usableFromInline var bounds: ClosedRange<Double>
    public typealias Body = Never
    public var body: Never { fatalError("Slider is primitive") }
}
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    public init<V>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1,
                   onEditingChanged: @escaping (Bool) -> Void = { _ in })
        where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
        self.value = Binding(get: { Double(value.wrappedValue) },
                             set: { value.wrappedValue = V($0) })
        self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound)
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Text modifiers (return Text; fold into TextStyle at render time)
// ════════════════════════════════════════════════════════════════════════════

extension Text {
    public func font(_ font: Font?) -> Text { var t = self; t.modifiers.append(.font(font)); return t }
    public func fontWeight(_ weight: Font.Weight?) -> Text { var t = self; t.modifiers.append(.weight(weight)); return t }
    public func foregroundColor(_ color: Color?) -> Text { var t = self; t.modifiers.append(.color(color)); return t }
    public func bold() -> Text { var t = self; t.modifiers.append(.weight(.bold)); return t }
}

// ── Foundation-probe SwiftUI gaps ────────────────────────────────────────────
// Text(_ content: some StringProtocol) — the verbatim init used for a String *value*
// (vs the LocalizedStringKey init used for a string literal): `Text(product.name)`.
extension Text {
    public init<S>(_ content: S) where S: StringProtocol {
        self.storage = .verbatim(String(content))
        self.modifiers = []
    }
}
// String interpolation of a String value inside a Text literal: `Text("… \(str)")`.
extension LocalizedStringKey.StringInterpolation {
    public mutating func appendInterpolation(_ string: String) { output += string }
}
