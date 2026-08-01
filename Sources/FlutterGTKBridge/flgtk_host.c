// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/FlutterGTKBridge.h"

#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>

#include <gtk/gtk.h>

// Direct inclusion of individual flutter_linux headers, the same way the
// embedder compiles its own sources. The vendored copies live beside this
// file; their cross-references are quoted-relative, so no include path is
// needed.
#define FLUTTER_LINUX_COMPILATION
#include "flutter_linux/fl_dart_project.h"
#include "flutter_linux/fl_engine.h"
#include "flutter_linux/fl_view.h"

struct FlGtkHost {
  GtkWindow* window;
  FlView* view;
};

// Drains libdispatch's main queue so @MainActor code and
// DispatchQueue.main.async blocks run on the GTK main thread. Same
// arrangement as the other Linux hosts in this package, driven by a GLib
// timer instead of a hand-rolled poll loop. Resolved via dlsym because the
// symbol is a libdispatch implementation detail with no public header.
static gboolean drain_gcd_main_queue(gpointer user_data) {
  static void (*drain)(void*) = NULL;
  if (drain == NULL) {
    drain = (void (*)(void*))dlsym(RTLD_DEFAULT,
                                   "_dispatch_main_queue_callback_4CF");
  }
  if (drain != NULL) {
    drain(NULL);
  }
  return G_SOURCE_CONTINUE;
}

// The user closed the window. FlView also hooks delete-event to forward a
// System.requestAppExit to the framework, but the Swift framework port does
// not answer that channel yet, which would leave the window unclosable. This
// handler is connected first (at create, before FlView's realize), so it
// wins: quit the loop, let the process exit. Returning TRUE stops the
// emission before FlView's handler swallows it.
static gboolean on_delete_event(GtkWidget* widget,
                                GdkEvent* event,
                                gpointer user_data) {
  gtk_main_quit();
  return TRUE;
}

FlGtkHost* flgtk_host_create(const char* title,
                             int32_t width,
                             int32_t height,
                             const void* runtime_controller) {
  if (!gtk_init_check(NULL, NULL)) {
    fprintf(stderr,
            "[FlGtkHost] gtk_init failed — no Wayland/X11 display reachable\n");
    return NULL;
  }

  // Engine data files resolve the standard Flutter bundle way:
  // <executable dir>/data/{icudtl.dat,flutter_assets}.
  g_autoptr(FlDartProject) project = fl_dart_project_new();

  // The Swift framework is main-thread-bound (MainActor): runtime callbacks
  // and platform messages must arrive on the GTK main thread, not the
  // engine's own UI thread. Same arrangement as fl_drm_view's custom UI task
  // runner, expressed through the embedder's stock policy knob.
  fl_dart_project_set_ui_thread_policy(project,
                                       FL_UI_THREAD_POLICY_RUN_ON_PLATFORM_THREAD);

  FlView* view = fl_view_new(project);

  // Swift mode must be set before the view realizes (realize starts the
  // engine).
  fl_engine_set_swift_runtime(fl_view_get_engine(view), runtime_controller);

  GtkWindow* window = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_title(window, title);
  gtk_window_set_default_size(window, width, height);
  g_signal_connect(window, "delete-event", G_CALLBACK(on_delete_event), NULL);

  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  gtk_widget_show(GTK_WIDGET(view));

  FlGtkHost* host = g_new0(FlGtkHost, 1);
  host->window = window;
  host->view = view;
  return host;
}

void flgtk_host_show(FlGtkHost* host) {
  gtk_widget_show(GTK_WIDGET(host->window));
}

void flgtk_host_run(FlGtkHost* host) {
  (void)host;
  g_timeout_add(8, drain_gcd_main_queue, NULL);
  gtk_main();
}

void flgtk_host_set_fullscreen(FlGtkHost* host, int32_t fullscreen) {
  if (fullscreen) {
    gtk_window_fullscreen(host->window);
  } else {
    gtk_window_unfullscreen(host->window);
  }
}
