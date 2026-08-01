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

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_GTK_BRIDGE_H
