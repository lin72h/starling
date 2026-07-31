// @StateObject / @ObservedObject — the SwiftUI side of the ObservableObject story.
// These are @frozen property wrappers the app INLINES, so their layout must match Apple
// byte-for-byte (measured: StateObject<M> 17/24, ObservedObject<M> 16/16, Wrapper 8/8).
//
// VERIFIED end-to-end: `D_observable`/`D_obs_rich` render the @Published value (2026-06-16), and
// `D_obs_react` (a button doing `m.c += 1`) now drives live re-renders 0→1→2→3→4 (2026-06-20).
// machold realizes the binary's ObjC-interop `class M: ObservableObject` on Linux (class metadata
// realization + ivar-offset globals + Darwin→Linux header conversion + singleton-init flag-clear;
// all in linux/loader/machold.c), and these wrappers' layout + symbols carry the render. The
// `.initially(thunk)` storage case matches Apple's `Storage` enum {initially | object} byte-for-byte
// (closure@0 + tag=0@16 == our {thunk@0, _seed:UInt8@16}). wrappedValue PERSISTS the object across
// re-walks (below) so a @Published mutation sticks. Push-based re-render is wired too: any @Published
// mutation / objectWillChange.send() (even outside a button action) re-renders via the
// swiftui_compat_invalidate hook (see FlutterBridge); `.sink` delivers the current value on subscribe.
// REMAINING: `.sink` FUTURE-value push (subject-backed Published.Publisher) — see NEXT-FEATURES.md.

@_spi(Reflection) import Swift   // _forEachField: field (name, offset, type) enumeration
import Combine
import Foundation                // UserDefaults (the @AppStorage store: param type)

// The protocol @State/@StateObject/@ObservedObject conform to. Minimal — only the
// type identity is needed (the app uses it as a constraint, resolved via metadata).
public protocol DynamicProperty {}

// Global @StateObject persistence cache (see StateObject.wrappedValue). Keyed by the stored
// thunk closure's FUNCTION POINTER (its first word). That pointer is the closure's code address
// — one per `@StateObject var x = T()` source site — and is stable across every walk (initial
// render and each re-render), whereas the closure's *context* word churns (a fresh box per CV
// copy), so context must NOT be part of the key. Distinct declarations have distinct closure
// functions → distinct entries; the `as? ObjectType` cast guards the rare case of a shared
// thunk across types. Holds objects strongly for the process lifetime (fine for the single-
// window compat host). Single-threaded walk → nonisolated(unsafe) is sound.
nonisolated(unsafe) var _stateObjectCache: [UInt: AnyObject] = [:]

// @frozen, 17/24: {thunk: () -> ObjectType (16) @0, _seed: UInt8 (1) @16}.
@frozen @propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty {
    @usableFromInline var thunk: () -> ObjectType
    @usableFromInline var _seed: UInt8
    @inlinable public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {
        self.thunk = thunk
        self._seed = 0
    }
    // PERSISTENCE (the @StateObject contract): the object must survive across re-walks so a
    // @Published mutation made by a button action is still there when the host re-renders.
    // We have no attribute-graph box, but the root view is retained (`_hostRoot`), so each
    // @StateObject's stored `thunk` closure's FUNCTION POINTER is stable across walks. Key a
    // global cache by that pointer and create the object lazily once; the same declaration
    // re-walked → cache hit → the same instance the action mutated. (@ObservedObject is
    // unchanged — it wraps an externally-owned object, no caching.)
    public var wrappedValue: ObjectType {
        let key = unsafeBitCast(thunk, to: (UInt, UInt).self).0   // closure function pointer
        if let cached = _stateObjectCache[key] as? ObjectType { return cached }
        let obj = thunk()
        _stateObjectCache[key] = obj
        return obj
    }
    // `$m` bindings must target the SAME persisted object, so route through wrappedValue.
    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject(wrappedValue: wrappedValue).projectedValue
    }
}

// ── @EnvironmentObject ────────────────────────────────────────────────────────
// @frozen, 16/16: {_store: ObjectType? (8) @0, _seed: Int (8) @8} — matches Apple's
// swiftinterface exactly. wrappedValue is @inlinable (`guard let store = _store else
// { error() }`), so the binary reads `_store` at +0 INLINE — nothing populates it by
// symbol call. The environment/DynamicProperty system must write it before `body`
// runs: our walk does that in the default View._makeView via _injectEnvironmentObjects
// (below), reading the object `.environmentObject(_:)` wrote into the inherited
// EnvironmentValues (through the `environmentStore` keypath, also below). init()/
// error()/projectedValue/descriptor are the binary's 4 EnvironmentObject imports —
// resilient, declared in the STRUCT BODY (an extension would mangle an `E` infix).
@frozen @propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty {
    // @dynamicMemberLookup → Binding into the object's fields ($m.c). @frozen, 8/8.
    @dynamicMemberLookup @frozen public struct Wrapper {
        @usableFromInline let root: ObjectType
        @usableFromInline init(root: ObjectType) { self.root = root }
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let o = root
            return Binding(get: { o[keyPath: keyPath] }, set: { o[keyPath: keyPath] = $0 })
        }
    }
    @usableFromInline var _store: ObjectType?
    @usableFromInline var _seed: Int = 0
    @inlinable public var wrappedValue: ObjectType {
        guard let store = _store else { error() }
        return store
    }
    public var projectedValue: Wrapper { Wrapper(root: wrappedValue) }
    public init() {}
    @usableFromInline func error() -> Never {
        fatalError("No ObservableObject of type \(ObjectType.self) found. "
            + "A View.environmentObject(_:) for \(ObjectType.self) may be missing as an ancestor of this view.")
    }
}

// The per-type environment slot `.environmentObject(_:)` writes through. The binary's
// inlined `environmentObject(object)` is `environment(T.environmentStore, object)` —
// it calls THIS getter (resilient, so the keypath's shape is entirely ours) and stores
// the result in an _EnvironmentKeyWritingModifier. The keypath goes through a subscript
// keyed by an (empty, Hashable) per-type key struct into EnvironmentValues._objects.
public struct _EnvironmentObjectKey<T>: Hashable { public init() {} }
extension EnvironmentValues {
    subscript<T: ObservableObject>(_envObject key: _EnvironmentObjectKey<T>) -> T? {
        get { _objects[ObjectIdentifier(T.self)] as? T }
        set { _objects[ObjectIdentifier(T.self)] = newValue }
    }
}
extension ObservableObject {
    public static var environmentStore: WritableKeyPath<EnvironmentValues, Self?> {
        \EnvironmentValues[_envObject: _EnvironmentObjectKey<Self>()]
    }
}

// The injection pass: before a custom view's `body` runs, populate every
// @EnvironmentObject / @Environment field from the walk's inherited environment.
// Fields are found with the stdlib's @_spi(Reflection) _forEachField (name, byte
// offset, type) and written through a raw pointer — reflection can't mutate, and the
// inlined wrappedValue reads the raw field, so this is the one honest way in. Re-runs
// every walk (the walk calls body on a fresh copy each time). @EnvironmentObject: a
// missing object leaves _store nil → the inlined guard calls error(), matching Apple.
protocol _AnyEnvironmentInjectable {
    static func _inject(at ptr: UnsafeMutableRawPointer, from env: EnvironmentValues)
}
extension EnvironmentObject: _AnyEnvironmentInjectable {
    static func _inject(at ptr: UnsafeMutableRawPointer, from env: EnvironmentValues) {
        let p = ptr.assumingMemoryBound(to: EnvironmentObject<ObjectType>.self)
        if p.pointee._store == nil {
            p.pointee._store = env[_envObject: _EnvironmentObjectKey<ObjectType>()]
        }
    }
}
func _injectEnvironmentObjects<V>(_ view: inout V, _ env: EnvironmentValues) {
    withUnsafeMutablePointer(to: &view) { p in
        let raw = UnsafeMutableRawPointer(p)
        _ = _forEachField(of: V.self, options: []) { _, offset, fieldType, _ in
            if let e = fieldType as? _AnyEnvironmentInjectable.Type { e._inject(at: raw + offset, from: env) }
            return true
        }
    }
}

// ── @Environment ──────────────────────────────────────────────────────────────
// @frozen, ONE stored field: `content`, a @frozen 2-case enum {keyPath | value} —
// matches Apple (case ORDER is tag-ABI). Both init(_:) and wrappedValue are @inlinable
// in Apple's interface: the binary stores `.keyPath(kp)` inline and switches on the
// content inline. The injection pass rewrites `.keyPath(kp)` → `.value(env[keyPath: kp])`
// before `body` runs, so the inlined getter takes the `.value` case — Apple's
// "not installed on a View" os_log fallback branch is dead code under the walk (its
// os_log imports bind to machold no-op stubs).
@frozen @propertyWrapper
public struct Environment<Value>: DynamicProperty {
    @usableFromInline @frozen enum Content {
        case keyPath(KeyPath<EnvironmentValues, Value>)
        case value(Value)
    }
    @usableFromInline var content: Content
    @inlinable public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        content = .keyPath(keyPath)
    }
    @inlinable public var wrappedValue: Value {
        switch content {
        case let .value(v): return v
        case let .keyPath(kp): return EnvironmentValues()[keyPath: kp]   // uninstalled: defaults
        }
    }
    @usableFromInline func error() -> Never {
        fatalError("Environment<\(Value.self)> accessed outside of a View")
    }
}
extension Environment: _AnyEnvironmentInjectable {
    static func _inject(at ptr: UnsafeMutableRawPointer, from env: EnvironmentValues) {
        let p = ptr.assumingMemoryBound(to: Environment<Value>.self)
        if case let .keyPath(kp) = p.pointee.content {
            p.pointee.content = .value(env[keyPath: kp])
        }
    }
}

// ── @AppStorage ───────────────────────────────────────────────────────────────
// @frozen {location: UserDefaultLocation<Value> (class ref)} = 8 B, matches Apple.
// wrappedValue (get/nonmutating set), projectedValue and the inits are all RESILIENT
// (ours), with `where Value == Int` ON the init (the Menu pattern). Backing store:
// an in-process dictionary (cross-launch persistence out of scope; the `store:` param
// is accepted and ignored — its Darwin mangling So14NSUserDefaultsC is rewritten to
// Foundation.UserDefaults by machold). A set invalidates like a @Published mutation.
@usableFromInline final class UserDefaultLocation<Value> {
    let key: String
    let defaultValue: Value
    init(key: String, defaultValue: Value) { self.key = key; self.defaultValue = defaultValue }
}
nonisolated(unsafe) var _appStorageValues: [String: Any] = [:]
@frozen @propertyWrapper
public struct AppStorage<Value>: DynamicProperty {
    @usableFromInline var location: UserDefaultLocation<Value>
    public var wrappedValue: Value {
        get { _appStorageValues[location.key] as? Value ?? location.defaultValue }
        nonmutating set { _appStorageValues[location.key] = newValue; swiftui_compat_invalidate() }
    }
    public var projectedValue: Binding<Value> {
        let loc = location
        return Binding(get: { _appStorageValues[loc.key] as? Value ?? loc.defaultValue },
                       set: { _appStorageValues[loc.key] = $0; swiftui_compat_invalidate() })
    }
}
extension AppStorage {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {
        self.location = UserDefaultLocation(key: key, defaultValue: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {
        self.location = UserDefaultLocation(key: key, defaultValue: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {
        self.location = UserDefaultLocation(key: key, defaultValue: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {
        self.location = UserDefaultLocation(key: key, defaultValue: wrappedValue)
    }
}

// ── @SceneStorage ─────────────────────────────────────────────────────────────
// @frozen — and NOT the AppStorage shape: Apple stores FIVE fields
// {_key: String @0 (16), _domain: String? @16 (16), _value: Value @32,
//  _location: AnyLocation<Value>? , _transformBox: class} = 56 B for Int
// (measured + swiftinterface). The first guess (8 B like AppStorage) crashed
// WindowGroup's outlined copy — the binary lays out the enclosing view with
// Apple's 56 B. Accessors and the where-on-init inits are resilient; backing =
// the in-process store under a "scene:" namespace.
@usableFromInline final class SceneStorageTransformBox {}
@frozen @propertyWrapper
public struct SceneStorage<Value>: DynamicProperty {
    @usableFromInline var _key: String
    @usableFromInline var _domain: String?
    @usableFromInline var _value: Value
    @usableFromInline var _location: AnyLocation<Value>?
    @usableFromInline var _transformBox: SceneStorageTransformBox
    public var wrappedValue: Value {
        get { _appStorageValues["scene:" + _key] as? Value ?? _value }
        nonmutating set { _appStorageValues["scene:" + _key] = newValue; swiftui_compat_invalidate() }
    }
    public var projectedValue: Binding<Value> {
        let key = _key, dflt = _value
        return Binding(get: { _appStorageValues["scene:" + key] as? Value ?? dflt },
                       set: { _appStorageValues["scene:" + key] = $0; swiftui_compat_invalidate() })
    }
    @usableFromInline init(_key: String, _value: Value) {
        self._key = _key; self._domain = nil; self._value = _value
        self._location = nil; self._transformBox = SceneStorageTransformBox()
    }
}
extension SceneStorage {
    public init(wrappedValue: Value, _ key: String) where Value == Int {
        self.init(_key: key, _value: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String) where Value == String {
        self.init(_key: key, _value: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String) where Value == Bool {
        self.init(_key: key, _value: wrappedValue)
    }
    public init(wrappedValue: Value, _ key: String) where Value == Double {
        self.init(_key: key, _value: wrappedValue)
    }
}

// @frozen, 16/16: {object: ObjectType (8) @0, _seed: Int (8) @8}.
@frozen @propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty {
    @usableFromInline var object: ObjectType
    @usableFromInline var _seed: Int
    @_alwaysEmitIntoClient public init(initialValue: ObjectType) { self.init(wrappedValue: initialValue) }
    public init(wrappedValue: ObjectType) {
        self.object = wrappedValue
        self._seed = 0
    }
    public var wrappedValue: ObjectType { object }
    public var projectedValue: Wrapper { Wrapper(object: object) }

    // @dynamicMemberLookup → Binding into the object's @Published fields. @frozen, 8/8.
    @dynamicMemberLookup @frozen public struct Wrapper {
        @usableFromInline var object: ObjectType
        @usableFromInline init(object: ObjectType) { self.object = object }
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let o = object
            return Binding(get: { o[keyPath: keyPath] }, set: { o[keyPath: keyPath] = $0 })
        }
    }
}
