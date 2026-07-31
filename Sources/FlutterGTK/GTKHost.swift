// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Runs a FlutterSwift app the way a real Flutter Linux app runs: inside the
// engine's GTK embedder (FlView in a GtkWindow), which owns the window,
// rendering surface, pointer/keyboard/touch input, IME and accessibility.
// The engine is started in Swift mode, so this framework drives frames
// through the SwiftRuntimeCallbacks table instead of a Dart isolate.
//
// All GTK/embedder mechanics live in the C glue (FlutterGTKBridge); this
// type only owns the callback table's lifetime and the run sequence.

#if os(Linux)
import Flutter
import FlutterSwiftBridge
import SwiftRuntime
import FlutterGTKBridge

public final class GTKHost {

    private let host: OpaquePointer
    // The engine holds this pointer for its lifetime; heap-allocate so it
    // never moves and never dies before the process does.
    private let callbacks: UnsafeMutablePointer<SwiftRuntimeCallbacks>

    /// Creates the window and view; the engine starts when run() shows the
    /// window. Returns nil when no Wayland/X11 display is reachable.
    public init?(width: Int, height: Int, title: String) {
        callbacks = UnsafeMutablePointer<SwiftRuntimeCallbacks>.allocate(capacity: 1)
        callbacks.initialize(to: createRuntimeCallbacks())
        guard let host = flgtk_host_create(title, Int32(width), Int32(height),
                                           UnsafeRawPointer(callbacks)) else {
            callbacks.deinitialize(count: 1)
            callbacks.deallocate()
            return nil
        }
        self.host = host
    }

    /// Sets up the widget binding. Call before run() — the tree must be
    /// mounted by the time the engine requests the first frame.
    public func mountWidget(_ builder: () -> Widget) {
        // Without FLUTTER_DMABUF_SOCKET set this only installs the binding;
        // the engine is ours and starts inside the GTK realize path.
        runApp(builder())
    }

    /// Shows the window (which starts the engine) and runs the GTK main
    /// loop. Returns when the window is closed.
    public func run() {
        flgtk_host_show(host)
        flgtk_host_run(host)
    }
}
#endif
