// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Base class for mixins that provide singleton services.
///
/// The Flutter engine exposes some low-level services, but these are typically
/// not suitable for direct use, for example because they only provide a single
/// callback which an application may wish to multiplex to allow multiple listeners.
///
/// Bindings provide the glue between these low-level APIs and the higher-level
/// framework APIs. They _bind_ the two together, whence the name.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/binding.dart`
///
/// **NOTE:** The deprecated `window` property (Dart lines 185-227) is intentionally
/// not migrated per the migration guide's deprecation policy.

import FlutterSwiftBridge
import Foundation

// MARK: - Type Aliases

/// Signature for service extensions.
///
/// The returned map must not contain the keys "type" or "method", as
/// they will be replaced before the value is sent to the client.
///
/// **Dart Source:** `binding.dart:49-50`
public typealias ServiceExtensionCallback = ([String: String]) async throws -> [String: Any]

// MARK: - BindingBase

/// Base class for mixins that provide singleton services.
///
/// The Flutter engine exposes some low-level services, but these are typically
/// not suitable for direct use. Bindings provide the glue between these low-level
/// APIs and the higher-level framework APIs.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/binding.dart`
/// **Lines:** 148-986
open class BindingBase {

    // MARK: - Properties

    /// The `PlatformDispatcher` to which this binding is bound.
    ///
    /// A number of additional bindings are defined as extensions of
    /// `BindingBase`, e.g., `ServicesBinding`, `RendererBinding`, and
    /// `WidgetsBinding`. Each of these bindings define behaviors that interact
    /// with a `PlatformDispatcher`.
    ///
    /// **Dart Source:** `binding.dart:229-249`
    open var platformDispatcher: PlatformDispatcher {
        PlatformDispatcher.instance
    }

    /// Whether `lockEvents` is currently locking events.
    ///
    /// Binding subclasses that fire events should check this first, and if it is
    /// set, queue events instead of firing them.
    ///
    /// Events should be flushed when `unlocked` is called.
    ///
    /// **Dart Source:** `binding.dart:635-643`
    public var locked: Bool { _lockCount > 0 }
    private var _lockCount: Int = 0

    /// Whether `debugCheckZone` should throw (true) or just report the error (false).
    ///
    /// **Dart Source:** `binding.dart:437-452`
    nonisolated(unsafe) public static var debugZoneErrorsAreFatal: Bool = false

    /// The URI of the connected VM service, if any.
    ///
    /// **Dart Source:** `binding.dart:569-572` (implicit via service extension)
    public var connectedVmServiceUri: String?

    /// The address of the active DevTools server, if any.
    ///
    /// **Dart Source:** `binding.dart:575-580` (implicit via service extension)
    public var activeDevToolsServerAddress: String?

    /// Debug override for brightness.
    ///
    /// **Dart Source:** `binding.dart:611` (implicit via service extension)
    public var debugBrightnessOverride: Brightness?

    // MARK: - Initializer

    /// Default constructor for bindings.
    ///
    /// First calls `initInstances` to have bindings initialize their
    /// instance pointers and other state, then calls `initServiceExtensions`
    /// to have bindings initialize their VM service extensions, if any.
    ///
    /// **Dart Source:** `binding.dart:155-179`
    public init() {
        initInstances()
        initServiceExtensions()
    }

    // MARK: - Instance Management

    /// The initialization method. Subclasses override this method to hook into
    /// the platform and otherwise configure their services. Subclasses must call
    /// `super.initInstances()`.
    ///
    /// The binding is not fully initialized when this method runs (for
    /// example, other binding mixins may not yet have run their
    /// `initInstances` method). For this reason, code in this method
    /// should avoid invoking callbacks or synchronously triggering any
    /// code that would normally assume that the bindings are ready.
    ///
    /// **Dart Source:** `binding.dart:251-297`
    open func initInstances() {
        // Subclasses override and call super
    }

    /// A method that shows a useful error message if the given binding
    /// instance is not initialized.
    ///
    /// See `initInstances` for advice on using this method.
    ///
    /// This method either returns the argument or throws an exception.
    /// In release mode it always returns the argument.
    ///
    /// **Dart Source:** `binding.dart:299-403`
    public static func checkInstance<T: BindingBase>(_ instance: T?) -> T {
        guard let instance = instance else {
            fatalError("Binding has not yet been initialized.")
        }
        return instance
    }

    /// In debug builds, the type of the current binding, if any, or else nil.
    ///
    /// This may be useful in asserts to verify that the binding has not been initialized
    /// before the point in the application code that wants to initialize the binding.
    ///
    /// **Dart Source:** `binding.dart:405-433`
    public static func debugBindingType() -> Any.Type? {
        return nil // Stub - type tracking not implemented
    }

    /// Checks that the current execution context is compatible with when
    /// the binding was initialized.
    ///
    /// **Note:** Dart's Zone concept doesn't exist in Swift.
    /// This method is provided for API compatibility but zone checking is not performed.
    ///
    /// **Dart Source:** `binding.dart:454-527`
    open func debugCheckZone(_ entryPoint: String) -> Bool {
        // Swift doesn't have Zones - this is a no-op
        return true
    }

    // MARK: - Service Extensions

    /// Called when the binding is initialized, to register service extensions.
    ///
    /// Bindings that want to expose service extensions should override
    /// this method to register them using calls to
    /// `registerSignalServiceExtension`,
    /// `registerBoolServiceExtension`,
    /// `registerNumericServiceExtension`, and
    /// `registerServiceExtension` (in increasing order of complexity).
    ///
    /// Implementations of this method must call their superclass implementation.
    ///
    /// **Dart Source:** `binding.dart:529-633`
    open func initServiceExtensions() {
        // Stub: service extensions are Dart VM-specific
    }

    /// Registers a service extension method with the given name (full
    /// name "ext.flutter.name"), which takes no arguments and returns
    /// no value.
    ///
    /// Calls the `callback` callback when the service extension is called.
    ///
    /// **Dart Source:** `binding.dart:739-755`
    public func registerSignalServiceExtension(name: String, callback: @escaping () async -> Void) {
        // Stub: service extensions are Dart VM-specific
    }

    /// Registers a service extension method with the given name (full
    /// name "ext.flutter.name"), which takes a single argument
    /// "enabled" which can have the value "true" or the value "false"
    /// or can be omitted to read the current value.
    ///
    /// **Dart Source:** `binding.dart:757-787`
    public func registerBoolServiceExtension(
        name: String,
        getter: @escaping () async -> Bool,
        setter: @escaping (Bool) async -> Void
    ) {
        // Stub: service extensions are Dart VM-specific
    }

    /// Registers a service extension method with the given name (full
    /// name "ext.flutter.name"), which takes a single argument with the
    /// same name as the method which, if present, must have a value
    /// that can be parsed by `Double.parse`, and can be omitted to read
    /// the current value.
    ///
    /// **Dart Source:** `binding.dart:789-818`
    public func registerNumericServiceExtension(
        name: String,
        getter: @escaping () async -> Double,
        setter: @escaping (Double) async -> Void
    ) {
        // Stub: service extensions are Dart VM-specific
    }

    /// Registers a service extension method with the given name (full name
    /// "ext.flutter.name"), which optionally takes a single argument with the
    /// name "value". If the argument is omitted, the value is to be read,
    /// otherwise it is to be set. Returns the current value.
    ///
    /// **Dart Source:** `binding.dart:848-876`
    public func registerStringServiceExtension(
        name: String,
        getter: @escaping () async -> String,
        setter: @escaping (String) async -> Void
    ) {
        // Stub: service extensions are Dart VM-specific
    }

    /// Registers a service extension method with the given name (full name
    /// "ext.flutter.name").
    ///
    /// The given callback is called when the extension method is called. The
    /// callback must return a result in the form of a name/value map where the
    /// values can all be converted to JSON.
    ///
    /// **Dart Source:** `binding.dart:878-982`
    public func registerServiceExtension(name: String, callback: @escaping ServiceExtensionCallback) {
        // Stub: service extensions are Dart VM-specific
    }

    /// All events dispatched by a `BindingBase` use this method instead of
    /// calling `developer.postEvent` directly so that tests for `BindingBase`
    /// can track which events were dispatched by overriding this method.
    ///
    /// This is unrelated to the events managed by `lockEvents`.
    ///
    /// **Dart Source:** `binding.dart:838-846`
    open func postEvent(_ eventKind: String, _ eventData: [String: Any]) {
        // Stub: no-op in Swift (developer.postEvent is Dart VM-specific)
    }

    // MARK: - Event Locking

    /// Locks the dispatching of asynchronous events and callbacks until the
    /// callback's future completes.
    ///
    /// This causes input lag and should therefore be avoided when possible. It is
    /// primarily intended for use during non-user-interactive time such as to
    /// allow `reassembleApplication` to block input while it walks the tree
    /// (which it partially does asynchronously).
    ///
    /// **Dart Source:** `binding.dart:645-689`
    public func lockEvents(_ callback: () async throws -> Void) async rethrows {
        _lockCount += 1
        defer {
            _lockCount -= 1
            if !locked {
                unlocked()
            }
        }
        try await callback()
    }

    /// Called by `lockEvents` when events get unlocked.
    ///
    /// This should flush any events that were queued while `locked` was true.
    ///
    /// **Dart Source:** `binding.dart:691-698`
    open func unlocked() {
        assert(!locked)
        // Subclasses override to flush queued events
    }

    // MARK: - Reassemble

    /// Cause the entire application to redraw, e.g. after a hot reload.
    ///
    /// This is used by development tools when the application code has changed,
    /// to cause the application to pick up any changed code. It can be triggered
    /// manually by sending the `ext.flutter.reassemble` service extension signal.
    ///
    /// This method is very computationally expensive and should not be used in
    /// production code.
    ///
    /// While this method runs, events are locked (e.g. pointer events are not
    /// dispatched).
    ///
    /// Subclasses (binding classes) should override `performReassemble` to react
    /// to this method being called. This method itself should not be overridden.
    ///
    /// **Dart Source:** `binding.dart:700-720`
    public func reassembleApplication() async {
        await lockEvents {
            await self.performReassemble()
        }
    }

    /// This method is called by `reassembleApplication` to actually cause the
    /// application to reassemble, e.g. after a hot reload.
    ///
    /// Bindings are expected to use this method to re-register anything that uses
    /// closures, so that they do not keep pointing to old code, and to flush any
    /// caches of previously computed values, in case the new code would compute
    /// them differently.
    ///
    /// Do not call this method directly. Instead, use `reassembleApplication`.
    ///
    /// **Dart Source:** `binding.dart:722-737`
    open func performReassemble() async {
        FlutterError.resetErrorCount()
    }
}

// MARK: - CustomStringConvertible

extension BindingBase: CustomStringConvertible {
    /// **Dart Source:** `binding.dart:984-986`
    public var description: String {
        "<\(objectRuntimeType(self, "BindingBase"))>"
    }
}

// MARK: - Exit Application (Internal)

/// Terminate the Flutter application.
///
/// **Dart Source:** `binding.dart:988-991`
private func exitApplication() async {
    #if os(macOS) || os(Linux)
    Foundation.exit(0)
    #endif
}
