// Reconstructed Combine — a module literally named `Combine` so its symbols mangle as
// `7Combine…`, matching the symbols the unmodified macOS binary imports. There is no
// Combine on Linux (it's closed-source, Apple-only), so this is a from-scratch minimal
// surface: just enough for `class M: ObservableObject { @Published var … }` to declare,
// instantiate, render its @Published values, and re-render on mutation. Reactivity is wired:
// @Published mutation / objectWillChange.send() → swiftui_compat_invalidate → host re-walk;
// `.sink` delivers the current value on subscribe (future-value push is the remaining slice).

// Re-render hook provided by the SwiftUI shim (libSwiftUI) — resolved across dylibs at load
// time, like swiftui_compat_run/update. Called whenever a @Published value changes or
// objectWillChange fires, so a mutation OUTSIDE a button action (timer, async, sink) still
// triggers a host re-walk. The SwiftUI side coalesces/defers (see swiftui_compat_invalidate).
@_silgen_name("swiftui_compat_invalidate")
func _compat_invalidate()

public protocol Subscriber {
    associatedtype Input
    associatedtype Failure: Error
    // Minimal of Apple's three requirements — enough for sink to receive values. (Apple also has
    // receive(subscription:)/receive(completion:) and returns Subscribers.Demand; we don't need
    // demand back-pressure for the compat surface.)
    func receive(_ input: Input)
}

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure: Error
    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure
}

public final class ObservableObjectPublisher: Publisher {
    public typealias Output = ()
    public typealias Failure = Never
    public init() {}
    public func receive<S: Subscriber>(subscriber: S) where S.Input == (), S.Failure == Never {}
    public func send() { _compat_invalidate() }
}

public protocol ObservableObject: AnyObject {
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
        where ObjectWillChangePublisher.Failure == Never
    var objectWillChange: ObjectWillChangePublisher { get }
}

// Default objectWillChange (the `(extension in Combine):ObservableObject.objectWillChange`
// symbol). Apple lazily reflects @Published fields and caches a publisher; we just hand
// back a fresh one — render reads values, it doesn't subscribe.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    public var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }
}

// Resilient (NOT @frozen) — the binary reaches Published via its metadata accessor, so the
// runtime sizes it from our descriptor. The stored value sits first so the @Published
// static subscript reads it through the enclosing object's keyPath.
@propertyWrapper public struct Published<Value> {
    @usableFromInline var stored: Value

    public init(initialValue: Value) { self.stored = initialValue }
    @_alwaysEmitIntoClient public init(wrappedValue: Value) { self.init(initialValue: wrappedValue) }

    public struct Publisher: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        @usableFromInline var current: Value          // snapshot captured when `$x` was accessed
        @usableFromInline init(_ current: Value) { self.current = current }
        // Deliver the current value to a new subscriber — Combine sends a @Published's current
        // value immediately on subscribe. FUTURE values aren't pushed yet (see sink's note); the
        // view still updates on every mutation via the setter → swiftui_compat_invalidate hook.
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Value, S.Failure == Never {
            subscriber.receive(current)
        }
    }

    public var wrappedValue: Value {
        get { stored }
        set { stored = newValue }
    }
    // get+set to match Apple's ABI (the binary imports projectedValue.setter too). The publisher
    // snapshots the current stored value; the setter is a no-op (we don't reassign publishers).
    public var projectedValue: Publisher {
        get { Publisher(stored) }
        set { _ = newValue }
    }

    // The enclosing-instance accessor the compiler emits for `@Published` on a class:
    // `m.c` lowers to Published[_enclosingInstance: m, wrapped: \M.c, storage: \M._c].
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get { object[keyPath: storageKeyPath].stored }
        set { object[keyPath: storageKeyPath].stored = newValue; _compat_invalidate() }
    }
}

// ── Cancellable / AnyCancellable — subscription handles ──────────────────────────
// A `.sink {…}` returns an AnyCancellable which apps keep alive via `.store(in:&set)`.
public protocol Cancellable {
    func cancel()
}

// Type-erased cancellation token. `final class` so reference identity is the Hashable/Equatable
// basis (it's stored in `Set<AnyCancellable>` by `.store(in:)`). Apple cancels on deinit; we
// only need it to bind + be Set-storable for the render path (no live delivery yet).
public final class AnyCancellable: Cancellable, Hashable {
    @usableFromInline let _cancel: () -> Void
    public init(_ cancel: @escaping () -> Void) { self._cancel = cancel }
    public init<C: Cancellable>(_ canceller: C) { self._cancel = { canceller.cancel() } }
    public func cancel() { _cancel() }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }
}

extension AnyCancellable {
    // The overload the binary imports: store(in: inout Set<AnyCancellable>).
    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }
}

// Minimal Subscriber that forwards each delivered value to a closure (the engine behind `sink`).
final class _AnySink<Input>: Subscriber {
    typealias Failure = Never
    let onValue: (Input) -> Void
    init(_ f: @escaping (Input) -> Void) { onValue = f }
    func receive(_ input: Input) { onValue(input) }
}

// Publisher.sink(receiveValue:) — the no-completion form, valid only where Failure == Never.
// Subscribes via the protocol's receive(subscriber:); for a `Published.Publisher` that delivers
// the CURRENT value immediately (e.g. `store.$c.sink { v in … }` in .onAppear fires once with the
// current `c`). FUTURE values aren't pushed yet — that needs a subject-backed Published.Publisher
// (a shared box with a subscriber list); guarded against because the view already re-renders on
// each @Published mutation via the setter → swiftui_compat_invalidate hook. Returns a no-op
// AnyCancellable (we don't track/cancel subscriptions — fine for the compat surface).
extension Publisher where Failure == Never {
    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        receive(subscriber: _AnySink<Output>(receiveValue))
        return AnyCancellable({})
    }
}
