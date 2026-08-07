// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The GTK host for a FlutterSwift app: the engine's real Linux embedder
// (libflutter_linux_gtk.so — FlView, FlEngine, input, IME, a11y) inside a
// GtkWindow, with the engine started in Swift mode so the Swift framework
// drives frames instead of a Dart isolate.
//
// This header is the whole Swift-visible surface. GTK and flutter_linux
// types stay behind it — the C glue includes them, the C++-interop importer
// never sees them.

#ifndef FLUTTER_GTK_BRIDGE_H
#define FLUTTER_GTK_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FlGtkHost FlGtkHost;

// Initializes GTK, creates the window and FlView, and puts the engine into
// Swift mode with `runtime_controller` (a SwiftRuntimeCallbacks*, which must
// outlive the host). The engine itself starts when the window is shown.
// Returns NULL if GTK cannot initialize (no display) — the reason lands on
// stderr.
FlGtkHost* flgtk_host_create(const char* title,
                             int32_t width,
                             int32_t height,
                             const void* runtime_controller);

// Shows the window; the FlView realizes and the engine starts in Swift mode.
void flgtk_host_show(FlGtkHost* host);

// Runs the GTK main loop (with the GCD main queue drained on a timer so
// @MainActor / DispatchQueue.main work). Returns when the window is closed.
void flgtk_host_run(FlGtkHost* host);

// Fullscreens or restores the window (gtk_window_fullscreen/unfullscreen).
void flgtk_host_set_fullscreen(FlGtkHost* host, int32_t fullscreen);

// A DMA-BUF-backed external texture: frames arrive as dma-buf fds and the
// raster thread samples the producer's GPU memory directly (EGLImage import,
// cached per buffer) — no CPU pixel copies, no per-frame GL uploads. Display
// it with a TextureWidget carrying the texture's id.
typedef struct FlGtkDmaBufTexture FlGtkDmaBufTexture;

// Registers a new texture with the engine. NULL if the engine's texture
// registrar is unavailable.
FlGtkDmaBufTexture* flgtk_host_create_dmabuf_texture(FlGtkHost* host);

// The id a TextureWidget refers to this texture by.
int64_t flgtk_dmabuf_texture_get_id(FlGtkDmaBufTexture* texture);

// Hands over the next frame. Takes ownership of `fd` (dup one if the buffer
// is pooled). Callable from any thread; marks the frame available.
void flgtk_dmabuf_texture_update(FlGtkDmaBufTexture* texture,
                                 int fd,
                                 int32_t width,
                                 int32_t height,
                                 int32_t stride,
                                 uint32_t fourcc,
                                 uint64_t modifier);

// Unregisters and releases the texture.
void flgtk_dmabuf_texture_destroy(FlGtkDmaBufTexture* texture);

// ── Clipboard ───────────────────────────────────────────────────────────────
// The system clipboard via GtkClipboard, so a Flutter-Swift app in a normal
// GNOME/KDE window copies and pastes with everything else on that desktop.
//
// The callback fires on the GLib main loop, which IS the UI thread under
// gtk_main. Callers must NOT hop it through GCD's main queue: that queue is
// never drained here, so the hop would silently swallow every paste.
typedef void (*FlGtkClipboardTextCallback)(void* ctx, const char* text);

// Take ownership of the selection with `text` (copied by GTK).
void flgtk_clipboard_set_text(const char* text);

// Ask for the selection as text. `cb` runs exactly once, on the GLib main
// loop; `text` is NULL when there is nothing to paste.
void flgtk_clipboard_get_text(FlGtkClipboardTextCallback cb, void* ctx);

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_GTK_BRIDGE_H
