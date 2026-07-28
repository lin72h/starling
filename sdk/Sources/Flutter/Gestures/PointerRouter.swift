// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// A callback that receives a [PointerEvent].
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/pointer_router.dart`
/// **Line:** 14
public typealias PointerRoute = (PointerEvent) -> Void

// MARK: - PointerRouteEntry

/// An opaque token representing a registered pointer route.
///
/// In Dart, `PointerRoute` (a function typedef) is used directly as a map key,
/// relying on function reference identity. Swift closures are not `Hashable`,
/// so this wrapper provides a stable identity for each registration.
///
/// Callers receive a `PointerRouteEntry` from `addRoute` or `addGlobalRoute`
/// and must pass it to the corresponding `removeRoute` or `removeGlobalRoute`.
public final class PointerRouteEntry {
    /// The registered route callback.
    public let route: PointerRoute

    /// The transform to apply to pointer events before dispatching.
    public let transform: Matrix4?

    /// A unique identifier used for dictionary keying.
    internal let id: UInt64

    /// Auto-incrementing counter for unique IDs.
    nonisolated(unsafe) private static var _nextId: UInt64 = 0

    internal init(route: @escaping PointerRoute, transform: Matrix4?) {
        self.route = route
        self.transform = transform
        self.id = PointerRouteEntry._nextId
        PointerRouteEntry._nextId += 1
    }
}

// MARK: - PointerRouter

/// A routing table for [PointerEvent] events.
///
/// This class maintains a set of routes (callbacks) that are invoked when
/// pointer events are dispatched. Routes can be registered for specific
/// pointer IDs or globally for all pointer events.
///
/// **API Difference from Dart:** In Dart, `PointerRoute` (a function typedef)
/// is used directly as a map key using function reference identity. Since Swift
/// closures are not `Hashable`, the `addRoute` and `addGlobalRoute` methods
/// return a `PointerRouteEntry` token that must be passed to the corresponding
/// `removeRoute` or `removeGlobalRoute` method.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/pointer_router.dart`
/// **Lines:** 17-146
public class PointerRouter {

    public init() {}

    // MARK: - Storage

    /// Per-pointer routes: maps pointer ID to an ordered dictionary of routes.
    private var _routeMap: [Int: [UInt64: PointerRouteEntry]] = [:]

    /// Maintains insertion order for per-pointer routes.
    private var _routeOrder: [Int: [UInt64]] = [:]

    /// Global routes that receive all pointer events.
    private var _globalRoutes: [UInt64: PointerRouteEntry] = [:]

    /// Maintains insertion order for global routes.
    private var _globalRouteOrder: [UInt64] = []

    // MARK: - Route Registration

    /// Adds a route to the routing table.
    ///
    /// Whenever this object routes a [PointerEvent] corresponding to
    /// `pointer`, the route callback will be called.
    ///
    /// Routes added reentrantly within `route(_:)` will take effect when
    /// routing the next event.
    ///
    /// - Parameters:
    ///   - pointer: The pointer ID to register the route for.
    ///   - route: The callback to invoke when a matching event is dispatched.
    ///   - transform: An optional transform matrix to apply to the event.
    /// - Returns: A `PointerRouteEntry` token to pass to `removeRoute`.
    ///
    /// **Dart Source:** `pointer_router.dart:28-35`
    @discardableResult
    public func addRoute(
        _ pointer: Int,
        _ route: @escaping PointerRoute,
        _ transform: Matrix4? = nil
    ) -> PointerRouteEntry {
        let entry = PointerRouteEntry(route: route, transform: transform)
        if _routeMap[pointer] == nil {
            _routeMap[pointer] = [:]
            _routeOrder[pointer] = []
        }
        _routeMap[pointer]![entry.id] = entry
        _routeOrder[pointer]!.append(entry.id)
        return entry
    }

    /// Removes a route from the routing table.
    ///
    /// No longer calls the route when routing a [PointerEvent] corresponding to
    /// the pointer. Requires that this entry was previously added to the router.
    ///
    /// Routes removed reentrantly within `route(_:)` will take effect
    /// immediately.
    ///
    /// - Parameters:
    ///   - pointer: The pointer ID the route was registered for.
    ///   - entry: The `PointerRouteEntry` returned from `addRoute`.
    ///
    /// **Dart Source:** `pointer_router.dart:44-52`
    public func removeRoute(_ pointer: Int, _ entry: PointerRouteEntry) {
        assert(_routeMap[pointer] != nil)
        let routes = _routeMap[pointer]!
        assert(routes[entry.id] != nil)
        _routeMap[pointer]!.removeValue(forKey: entry.id)
        _routeOrder[pointer]!.removeAll { $0 == entry.id }
        if _routeMap[pointer]!.isEmpty {
            _routeMap.removeValue(forKey: pointer)
            _routeOrder.removeValue(forKey: pointer)
        }
    }

    /// Adds a route to the global entry in the routing table.
    ///
    /// Whenever this object routes a [PointerEvent], the route callback
    /// will be called.
    ///
    /// Routes added reentrantly within `route(_:)` will take effect when
    /// routing the next event.
    ///
    /// - Parameters:
    ///   - route: The callback to invoke for all pointer events.
    ///   - transform: An optional transform matrix to apply to the event.
    /// - Returns: A `PointerRouteEntry` token to pass to `removeGlobalRoute`.
    ///
    /// **Dart Source:** `pointer_router.dart:60-63`
    @discardableResult
    public func addGlobalRoute(
        _ route: @escaping PointerRoute,
        _ transform: Matrix4? = nil
    ) -> PointerRouteEntry {
        let entry = PointerRouteEntry(route: route, transform: transform)
        _globalRoutes[entry.id] = entry
        _globalRouteOrder.append(entry.id)
        return entry
    }

    /// Removes a route from the global entry in the routing table.
    ///
    /// No longer calls the route when routing a [PointerEvent]. Requires that
    /// this entry was previously added via `addGlobalRoute`.
    ///
    /// Routes removed reentrantly within `route(_:)` will take effect
    /// immediately.
    ///
    /// - Parameter entry: The `PointerRouteEntry` returned from `addGlobalRoute`.
    ///
    /// **Dart Source:** `pointer_router.dart:72-75`
    public func removeGlobalRoute(_ entry: PointerRouteEntry) {
        assert(_globalRoutes[entry.id] != nil)
        _globalRoutes.removeValue(forKey: entry.id)
        _globalRouteOrder.removeAll { $0 == entry.id }
    }

    // MARK: - Debug

    /// The number of global routes that have been registered.
    ///
    /// This is valid in debug builds only. In release builds, this will throw a
    /// `fatalError`.
    ///
    /// **Dart Source:** `pointer_router.dart:81-91`
    public var debugGlobalRouteCount: Int {
        var count: Int?
        assert({
            count = _globalRoutes.count
            return true
        }())
        if let count = count {
            return count
        }
        fatalError("debugGlobalRouteCount is not supported in release builds")
    }

    // MARK: - Dispatching

    /// Calls the routes registered for this pointer event.
    ///
    /// Routes are called in the order in which they were added to the
    /// `PointerRouter` object.
    ///
    /// **Dart Source:** `pointer_router.dart:124-133`
    public func route(_ event: PointerEvent) {
        let routes = _routeMap[event.pointer]
        // Snapshot the global routes before dispatching so that routes added
        // reentrantly during dispatch do not take effect until the next event.
        let copiedGlobalRouteOrder = _globalRouteOrder
        let copiedGlobalRoutes = _globalRoutes

        if let routes = routes {
            let copiedOrder = _routeOrder[event.pointer] ?? []
            let copiedRoutes = routes
            _dispatchEventToRoutes(
                event,
                referenceRoutes: { [weak self] id in self?._routeMap[event.pointer]?[id] },
                copiedRoutes: copiedRoutes,
                copiedOrder: copiedOrder
            )
        }
        _dispatchEventToRoutes(
            event,
            referenceRoutes: { [weak self] id in self?._globalRoutes[id] },
            copiedRoutes: copiedGlobalRoutes,
            copiedOrder: copiedGlobalRouteOrder
        )
    }

    /// Dispatches an event to a single route.
    ///
    /// In the Dart source, this method wraps the call in a `try/catch` and
    /// reports errors via `FlutterError.reportError`. In Swift, `PointerRoute`
    /// is a non-throwing closure `(PointerEvent) -> Void`, so runtime errors
    /// cannot be caught in the same manner. The transformed event is applied
    /// and the route is invoked directly.
    ///
    /// **Dart Source:** `pointer_router.dart:94-118`
    private func _dispatch(
        _ event: PointerEvent,
        _ route: PointerRoute,
        _ transform: Matrix4?
    ) {
        let transformedEvent = event.transformed(transform)
        route(transformedEvent)
    }

    /// Dispatches an event to all routes in the copied routes collection,
    /// checking against the live reference routes to handle reentrant removal.
    ///
    /// **Dart Source:** `pointer_router.dart:135-145`
    private func _dispatchEventToRoutes(
        _ event: PointerEvent,
        referenceRoutes: (UInt64) -> PointerRouteEntry?,
        copiedRoutes: [UInt64: PointerRouteEntry],
        copiedOrder: [UInt64]
    ) {
        for id in copiedOrder {
            guard let entry = copiedRoutes[id] else { continue }
            // Only dispatch if the route is still present in the live reference.
            if referenceRoutes(id) != nil {
                _dispatch(event, entry.route, entry.transform)
            }
        }
    }
}
