// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_text_input.c — zwp_text_input_v3 implementation
 *
 * Real IME delivery for Wayland clients (Chromium, GTK, the test client):
 * `enter`/`leave` follow keyboard focus, clients `enable` + report their
 * cursor rectangle, and the shell's fcitx pipeline delivers composition via
 * wayland_server_text_input_preedit()/commit_string(). The v3 `done` serial
 * mirrors the number of `commit` requests received, per spec.
 */

#include "wayland_server_internal.h"
#include "text-input-unstable-v3-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Per-bound-resource state. Pending values apply on `commit` (v3 is
 * double-buffered). */
struct TextInputV3 {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint32_t commit_count;         /* v3 serial = number of commits */
    int enabled, pending_enabled;
    int32_t cx, cy, cw, ch;        /* cursor rect, surface-local logical */
    int32_t pcx, pcy, pcw, pch;
    struct wl_list link;           /* in server->text_inputs */
};

/* The client owning the current keyboard focus (set by focus_enter). */
static struct wl_client* focus_client(struct WaylandServer* server) {
    if (!server->ti_focus) return NULL;
    return wl_resource_get_client(server->ti_focus->resource);
}

static void notify_state(struct TextInputV3* ti) {
    struct WaylandServer* server = ti->server;
    if (!server->cb.on_text_input_state || !server->ti_focus) return;
    if (wl_resource_get_client(ti->resource) != focus_client(server)) return;
    server->cb.on_text_input_state(server->cb_ctx, server->ti_focus->id,
                                   ti->enabled, ti->cx, ti->cy, ti->cw,
                                   ti->ch);
}

/* ========================================================================== */
/* zwp_text_input_v3 requests                                                 */
/* ========================================================================== */

static void text_input_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void text_input_enable(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    struct TextInputV3* ti = wl_resource_get_user_data(resource);
    if (ti) ti->pending_enabled = 1;
}

static void text_input_disable(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    struct TextInputV3* ti = wl_resource_get_user_data(resource);
    if (ti) ti->pending_enabled = 0;
}

static void text_input_set_surrounding_text(struct wl_client* client,
                                            struct wl_resource* resource,
                                            const char* text,
                                            int32_t cursor,
                                            int32_t anchor) {
    (void)client; (void)resource; (void)text; (void)cursor; (void)anchor;
}

static void text_input_set_text_change_cause(struct wl_client* client,
                                             struct wl_resource* resource,
                                             uint32_t cause) {
    (void)client; (void)resource; (void)cause;
}

static void text_input_set_content_type(struct wl_client* client,
                                        struct wl_resource* resource,
                                        uint32_t hint,
                                        uint32_t purpose) {
    (void)client; (void)resource; (void)hint; (void)purpose;
}

static void text_input_set_cursor_rectangle(struct wl_client* client,
                                            struct wl_resource* resource,
                                            int32_t x, int32_t y,
                                            int32_t width, int32_t height) {
    (void)client;
    struct TextInputV3* ti = wl_resource_get_user_data(resource);
    if (!ti) return;
    ti->pcx = x;
    ti->pcy = y;
    ti->pcw = width;
    ti->pch = height;
}

static void text_input_commit(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    struct TextInputV3* ti = wl_resource_get_user_data(resource);
    if (!ti) return;
    ti->commit_count++;
    ti->enabled = ti->pending_enabled;
    ti->cx = ti->pcx;
    ti->cy = ti->pcy;
    ti->cw = ti->pcw;
    ti->ch = ti->pch;
    notify_state(ti);
}

static const struct zwp_text_input_v3_interface text_input_impl = {
    .destroy = text_input_destroy,
    .enable = text_input_enable,
    .disable = text_input_disable,
    .set_surrounding_text = text_input_set_surrounding_text,
    .set_text_change_cause = text_input_set_text_change_cause,
    .set_content_type = text_input_set_content_type,
    .set_cursor_rectangle = text_input_set_cursor_rectangle,
    .commit = text_input_commit,
};

static void text_input_resource_destroyed(struct wl_resource* resource) {
    struct TextInputV3* ti = wl_resource_get_user_data(resource);
    if (!ti) return;
    wl_list_remove(&ti->link);
    free(ti);
}

/* ========================================================================== */
/* Focus tracking (called from the keyboard enter/leave dispatch)             */
/* ========================================================================== */

void wayland_text_input_focus_enter(struct WaylandServer* server,
                                    struct WaylandSurface* surface) {
    server->ti_focus = surface;
    struct wl_client* client = wl_resource_get_client(surface->resource);
    struct TextInputV3* ti;
    wl_list_for_each(ti, &server->text_inputs, link) {
        if (wl_resource_get_client(ti->resource) == client)
            zwp_text_input_v3_send_enter(ti->resource, surface->resource);
    }
}

void wayland_text_input_focus_leave(struct WaylandServer* server,
                                    struct WaylandSurface* surface) {
    struct wl_client* client = wl_resource_get_client(surface->resource);
    struct TextInputV3* ti;
    wl_list_for_each(ti, &server->text_inputs, link) {
        if (wl_resource_get_client(ti->resource) == client) {
            zwp_text_input_v3_send_leave(ti->resource, surface->resource);
            ti->enabled = 0;
            ti->pending_enabled = 0;
        }
    }
    if (server->ti_focus == surface) {
        server->ti_focus = NULL;
        if (server->cb.on_text_input_state)
            server->cb.on_text_input_state(server->cb_ctx, surface->id,
                                           0, 0, 0, 0, 0);
    }
}

void wayland_text_input_surface_destroyed(struct WaylandServer* server,
                                          struct WaylandSurface* surface) {
    if (server->ti_focus == surface) server->ti_focus = NULL;
}

/* ========================================================================== */
/* IME delivery (shell → focused client)                                      */
/* ========================================================================== */

/* Returns 1 when at least one enabled text input received the event. */
int wayland_server_text_input_commit_string(WaylandServer* server,
                                            const char* text) {
    struct wl_client* client = focus_client(server);
    if (!client || !text) return 0;
    int sent = 0;
    struct TextInputV3* ti;
    wl_list_for_each(ti, &server->text_inputs, link) {
        if (wl_resource_get_client(ti->resource) == client && ti->enabled) {
            zwp_text_input_v3_send_commit_string(ti->resource, text);
            zwp_text_input_v3_send_done(ti->resource, ti->commit_count);
            sent = 1;
        }
    }
    return sent;
}

int wayland_server_text_input_preedit(WaylandServer* server,
                                      const char* text,
                                      int32_t cursor) {
    struct wl_client* client = focus_client(server);
    if (!client) return 0;
    int sent = 0;
    struct TextInputV3* ti;
    wl_list_for_each(ti, &server->text_inputs, link) {
        if (wl_resource_get_client(ti->resource) == client && ti->enabled) {
            zwp_text_input_v3_send_preedit_string(
                ti->resource, text && text[0] ? text : NULL, cursor, cursor);
            zwp_text_input_v3_send_done(ti->resource, ti->commit_count);
            sent = 1;
        }
    }
    return sent;
}

/* 1 when the focused surface's client has an enabled text input. */
int wayland_server_text_input_active(WaylandServer* server) {
    struct wl_client* client = focus_client(server);
    if (!client) return 0;
    struct TextInputV3* ti;
    wl_list_for_each(ti, &server->text_inputs, link) {
        if (wl_resource_get_client(ti->resource) == client && ti->enabled)
            return 1;
    }
    return 0;
}

void wayland_server_on_text_input_state(
    WaylandServer* server,
    void (*cb)(void* ctx, uint32_t surface_id, int enabled,
               int32_t x, int32_t y, int32_t w, int32_t h),
    void* ctx) {
    server->cb.on_text_input_state = cb;
    server->cb_ctx = ctx;
}

/* ========================================================================== */
/* zwp_text_input_manager_v3 (global)                                         */
/* ========================================================================== */

static void manager_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void manager_get_text_input(struct wl_client* client,
                                   struct wl_resource* resource,
                                   uint32_t id,
                                   struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* res = wl_resource_create(client,
        &zwp_text_input_v3_interface, 1, id);
    if (!res) {
        wl_client_post_no_memory(client);
        return;
    }
    struct TextInputV3* ti = calloc(1, sizeof(*ti));
    if (!ti) {
        wl_resource_destroy(res);
        wl_client_post_no_memory(client);
        return;
    }
    ti->resource = res;
    ti->server = server;
    wl_list_insert(&server->text_inputs, &ti->link);
    wl_resource_set_implementation(res, &text_input_impl, ti,
                                   text_input_resource_destroyed);

    /* Late bind while this client already holds focus: deliver enter now. */
    if (server->ti_focus
        && wl_resource_get_client(server->ti_focus->resource) == client)
        zwp_text_input_v3_send_enter(res, server->ti_focus->resource);
}

static const struct zwp_text_input_manager_v3_interface text_input_manager_impl = {
    .destroy = manager_destroy,
    .get_text_input = manager_get_text_input,
};

static void text_input_manager_bind(struct wl_client* client, void* data,
                                    uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_text_input_manager_v3_interface, version, id);
    wl_resource_set_implementation(resource, &text_input_manager_impl, data, NULL);
}

void wayland_text_input_init(struct WaylandServer* server) {
    wl_list_init(&server->text_inputs);
    server->ti_focus = NULL;
    server->text_input_manager_global = wl_global_create(server->display,
        &zwp_text_input_manager_v3_interface, 1, server, text_input_manager_bind);
}
