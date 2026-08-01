// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Marshals work from background queues onto the GTK main loop — the thread
// the framework runs the UI on. g_idle_add's callback is a C function
// pointer, so the closure rides along boxed in the user-data pointer.

#if os(Linux)
import CGtk3

enum MainThread {
    private final class Box {
        let body: () -> Void
        init(_ body: @escaping () -> Void) { self.body = body }
    }

    /// Runs `body` on the next main-loop iteration.
    static func run(_ body: @escaping () -> Void) {
        let box = Unmanaged.passRetained(Box(body)).toOpaque()
        g_idle_add({ pointer in
            let box = Unmanaged<Box>.fromOpaque(pointer!).takeRetainedValue()
            box.body()
            return 0  // G_SOURCE_REMOVE
        }, box)
    }
}
#endif
