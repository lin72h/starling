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

    /// Fullscreens or restores the window.
    public func setFullscreen(_ fullscreen: Bool) {
        flgtk_host_set_fullscreen(host, fullscreen ? 1 : 0)
    }

    /// Registers a DMA-BUF-backed external texture with the engine, or nil
    /// if the texture registrar is unavailable.
    public func makeDmaBufTexture() -> GTKDmaBufTexture? {
        guard let texture = flgtk_host_create_dmabuf_texture(host) else { return nil }
        return GTKDmaBufTexture(texture: texture)
    }
}

/// An external texture whose frames arrive as dma-buf fds: the raster thread
/// samples the producer's GPU memory directly (EGLImage import, cached per
/// buffer identity) — no CPU pixel copies, no per-frame GL uploads. Show it
/// with `TextureWidget(textureId: Int(texture.textureId))`.
public final class GTKDmaBufTexture {

    private let texture: OpaquePointer
    public let textureId: Int64

    fileprivate init(texture: OpaquePointer) {
        self.texture = texture
        self.textureId = flgtk_dmabuf_texture_get_id(texture)
    }

    /// Hands over the next frame. Takes ownership of `fd` — dup(2) a pooled
    /// buffer's fd before passing it. Callable from any thread.
    public func update(
        fd: Int32, width: Int32, height: Int32, stride: Int32,
        fourcc: UInt32, modifier: UInt64
    ) {
        flgtk_dmabuf_texture_update(texture, fd, width, height, stride, fourcc, modifier)
    }

    deinit {
        flgtk_dmabuf_texture_destroy(texture)
    }
}
#endif
