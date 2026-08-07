// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * flgtk_clipboard.c — the system clipboard for the GTK host.
 *
 * GtkClipboard already does the hard part (owning the selection, answering
 * paste requests, negotiating targets) on whatever display the app is running
 * on, so this is a thin shim. The Starling host cannot use it — a dma-buf child
 * has no GTK and no surface of its own, and talks zwlr_data_control instead; see
 * sdk/Sources/WaylandClipboardBridge.
 */

#include <gtk/gtk.h>
#include <stdlib.h>

#include "include/FlutterGTKBridge.h"

void flgtk_clipboard_set_text(const char* text) {
    if (!text) return;
    GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (!clipboard) return;
    gtk_clipboard_set_text(clipboard, text, -1);
    /* Deliberately no gtk_clipboard_store(): that asks the desktop's clipboard
     * manager to keep the data alive past our exit, which is the "clipboard
     * survives the owner" behaviour tracked as a separate decision in
     * docs/plans/clipboard.md. Leaving it out matches what the Starling host
     * does, so the two backends behave the same way. */
}

struct FlGtkClipboardRequest {
    FlGtkClipboardTextCallback cb;
    void* ctx;
};

static void flgtk_on_text(GtkClipboard* clipboard, const gchar* text,
                          gpointer data) {
    (void)clipboard;
    struct FlGtkClipboardRequest* req = data;
    if (!req) return;
    req->cb(req->ctx, text);   /* text is NULL when the selection has no text */
    free(req);
}

void flgtk_clipboard_get_text(FlGtkClipboardTextCallback cb, void* ctx) {
    if (!cb) return;
    GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (!clipboard) { cb(ctx, NULL); return; }

    struct FlGtkClipboardRequest* req = malloc(sizeof(*req));
    if (!req) { cb(ctx, NULL); return; }   /* still answer, or the caller hangs */
    req->cb = cb;
    req->ctx = ctx;
    gtk_clipboard_request_text(clipboard, flgtk_on_text, req);
}
