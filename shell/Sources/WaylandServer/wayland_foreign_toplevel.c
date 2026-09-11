// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_foreign_toplevel.c — what a taskbar knows
 *
 *   zwlr_foreign_toplevel_manager_v1 (v3)  the wlroots protocol: every
 *       mapped toplevel as a handle with title, app_id, outputs and state,
 *       plus requests to activate, (un)minimize, (un)maximize, (un)fullscreen
 *       and close it. Taskbars, docks, and wmbench's unminimise use it.
 *   ext_foreign_toplevel_list_v1 (v1)      the standardised read-only half:
 *       the same list with a stable identifier per toplevel and no requests.
 *
 * One manager object per bind; one handle per (manager, toplevel). A
 * toplevel is announced when it maps (first buffer) and closed when its
 * xdg_toplevel goes. The state a handle reports is the shell's
 * (surface->toplevel_states); the requests a handle carries go to the shell
 * as on_toplevel_request, which applies its policy and pushes the result
 * back through wayland_server_set_toplevel_state.
 */

#include "wayland_server_internal.h"
#include "wlr-foreign-toplevel-management-unstable-v1-protocol.h"
#include "ext-foreign-toplevel-list-v1-protocol.h"
#include "xdg-shell-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ========================================================================== */
/* Handles                                                                    */
/* ========================================================================== */

static void handle_send_state(struct WaylandForeignHandle* h) {
    if (h->manager->ext || !h->surface) return;
    uint32_t st = h->surface->toplevel_states;
    uint32_t version = wl_resource_get_version(h->resource);
    struct wl_array arr;
    wl_array_init(&arr);
    uint32_t* v;
    if (st & WAYLAND_TOPLEVEL_MAXIMIZED) {
        v = wl_array_add(&arr, sizeof(*v));
        *v = ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED;
    }
    if (st & WAYLAND_TOPLEVEL_MINIMIZED) {
        v = wl_array_add(&arr, sizeof(*v));
        *v = ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED;
    }
    if (st & WAYLAND_TOPLEVEL_ACTIVATED) {
        v = wl_array_add(&arr, sizeof(*v));
        *v = ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED;
    }
    if ((st & WAYLAND_TOPLEVEL_FULLSCREEN) &&
        version >= ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_FULLSCREEN_SINCE_VERSION) {
        v = wl_array_add(&arr, sizeof(*v));
        *v = ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_FULLSCREEN;
    }
    zwlr_foreign_toplevel_handle_v1_send_state(h->resource, &arr);
    wl_array_release(&arr);
}

/* output_enter/leave for one output, to the wl_output resources THIS
 * handle's client bound. */
static void handle_send_output(struct WaylandForeignHandle* h,
                               struct WaylandOutput* output, int enter) {
    if (h->manager->ext) return;
    struct wl_client* client = wl_resource_get_client(h->resource);
    struct wl_resource* out;
    wl_resource_for_each(out, &output->resources) {
        if (wl_resource_get_client(out) != client) continue;
        if (enter)
            zwlr_foreign_toplevel_handle_v1_send_output_enter(h->resource, out);
        else
            zwlr_foreign_toplevel_handle_v1_send_output_leave(h->resource, out);
    }
}

static void handle_send_title(struct WaylandForeignHandle* h) {
    if (!h->surface) return;
    if (h->manager->ext)
        ext_foreign_toplevel_handle_v1_send_title(h->resource, h->surface->title);
    else
        zwlr_foreign_toplevel_handle_v1_send_title(h->resource, h->surface->title);
}

static void handle_send_app_id(struct WaylandForeignHandle* h) {
    if (!h->surface) return;
    if (h->manager->ext)
        ext_foreign_toplevel_handle_v1_send_app_id(h->resource, h->surface->app_id);
    else
        zwlr_foreign_toplevel_handle_v1_send_app_id(h->resource, h->surface->app_id);
}

static void handle_send_done(struct WaylandForeignHandle* h) {
    if (h->manager->ext)
        ext_foreign_toplevel_handle_v1_send_done(h->resource);
    else
        zwlr_foreign_toplevel_handle_v1_send_done(h->resource);
}

static void request(struct wl_resource* r, int what) {
    struct WaylandForeignHandle* h = wl_resource_get_user_data(r);
    if (!h || !h->surface) return;   /* inert after closed */
    struct WaylandServer* server = h->manager->server;
    if (server->cb.on_toplevel_request)
        server->cb.on_toplevel_request(server->cb_ctx, h->surface->id, what);
}

static void h_set_maximized(struct wl_client* c, struct wl_resource* r) {
    (void)c; request(r, WAYLAND_TOPLEVEL_REQUEST_MAXIMIZE);
}
static void h_unset_maximized(struct wl_client* c, struct wl_resource* r) {
    (void)c; request(r, WAYLAND_TOPLEVEL_REQUEST_UNMAXIMIZE);
}
static void h_set_minimized(struct wl_client* c, struct wl_resource* r) {
    (void)c; request(r, WAYLAND_TOPLEVEL_REQUEST_MINIMIZE);
}
static void h_unset_minimized(struct wl_client* c, struct wl_resource* r) {
    (void)c; request(r, WAYLAND_TOPLEVEL_REQUEST_UNMINIMIZE);
}
static void h_activate(struct wl_client* c, struct wl_resource* r,
                       struct wl_resource* seat) {
    (void)c; (void)seat; request(r, WAYLAND_TOPLEVEL_REQUEST_ACTIVATE);
}
static void h_close(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    /* A taskbar's close is the window's close button: ask the client to
     * quit through xdg_toplevel.close, exactly as the dock's Quit does. */
    struct WaylandForeignHandle* h = wl_resource_get_user_data(r);
    if (!h || !h->surface || !h->surface->xdg_toplevel) return;
    xdg_toplevel_send_close(h->surface->xdg_toplevel);
}
static void h_set_rectangle(struct wl_client* c, struct wl_resource* r,
                            struct wl_resource* surface, int32_t x, int32_t y,
                            int32_t w, int32_t h) {
    (void)c; (void)r; (void)surface; (void)x; (void)y; (void)w; (void)h;
    /* Where the taskbar draws this window's button — a hint for minimize
     * animations, which the shell zooms to its own dock instead. */
}
static void h_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c; wl_resource_destroy(r);
}
static void h_set_fullscreen(struct wl_client* c, struct wl_resource* r,
                             struct wl_resource* output) {
    (void)c; (void)output;
    struct WaylandForeignHandle* h = wl_resource_get_user_data(r);
    if (!h || !h->surface) return;
    struct WaylandServer* server = h->manager->server;
    if (server->cb.on_fullscreen_request)
        server->cb.on_fullscreen_request(server->cb_ctx, h->surface->id);
}
static void h_unset_fullscreen(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandForeignHandle* h = wl_resource_get_user_data(r);
    if (!h || !h->surface) return;
    struct WaylandServer* server = h->manager->server;
    if (server->cb.on_unfullscreen_request)
        server->cb.on_unfullscreen_request(server->cb_ctx, h->surface->id);
}

static const struct zwlr_foreign_toplevel_handle_v1_interface zwlr_handle_impl = {
    .set_maximized = h_set_maximized,
    .unset_maximized = h_unset_maximized,
    .set_minimized = h_set_minimized,
    .unset_minimized = h_unset_minimized,
    .activate = h_activate,
    .close = h_close,
    .set_rectangle = h_set_rectangle,
    .destroy = h_destroy,
    .set_fullscreen = h_set_fullscreen,
    .unset_fullscreen = h_unset_fullscreen,
};

static const struct ext_foreign_toplevel_handle_v1_interface ext_handle_impl = {
    .destroy = h_destroy,
};

/* Explicit destroy and disconnect. The manager may already be gone (its
 * resource died first on disconnect, or it was stopped): then the handle
 * was detached from it and only the surface list remains. */
static void handle_resource_destroyed(struct wl_resource* r) {
    struct WaylandForeignHandle* h = wl_resource_get_user_data(r);
    if (!h) return;
    if (h->manager) wl_list_remove(&h->link);
    if (h->surface) wl_list_remove(&h->surface_link);
    free(h);
}

static void handle_create(struct WaylandForeignManager* m,
                          struct WaylandSurface* s) {
    struct WaylandForeignHandle* h = calloc(1, sizeof(*h));
    if (!h) return;
    struct wl_client* client = wl_resource_get_client(m->resource);
    uint32_t version = wl_resource_get_version(m->resource);
    struct wl_resource* r = wl_resource_create(client,
        m->ext ? &ext_foreign_toplevel_handle_v1_interface
               : &zwlr_foreign_toplevel_handle_v1_interface,
        version, 0);
    if (!r) {
        free(h);
        return;
    }
    h->resource = r;
    h->manager = m;
    h->surface = s;
    wl_list_insert(&m->handles, &h->link);
    wl_list_insert(&s->foreign_handles, &h->surface_link);
    if (m->ext) {
        wl_resource_set_implementation(r, &ext_handle_impl, h,
                                       handle_resource_destroyed);
        ext_foreign_toplevel_list_v1_send_toplevel(m->resource, r);
        ext_foreign_toplevel_handle_v1_send_identifier(r, s->foreign_identifier);
        handle_send_title(h);
        handle_send_app_id(h);
    } else {
        wl_resource_set_implementation(r, &zwlr_handle_impl, h,
                                       handle_resource_destroyed);
        zwlr_foreign_toplevel_manager_v1_send_toplevel(m->resource, r);
        handle_send_title(h);
        handle_send_app_id(h);
        for (int i = 0; i < m->server->output_count; i++) {
            if (s->outputs_mask & (1u << i))
                handle_send_output(h, &m->server->outputs[i], 1);
        }
        handle_send_state(h);
        if (version >= ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_PARENT_SINCE_VERSION)
            zwlr_foreign_toplevel_handle_v1_send_parent(r, NULL);
    }
    handle_send_done(h);
}

/* ========================================================================== */
/* Managers                                                                   */
/* ========================================================================== */

static void manager_detach_handles(struct WaylandForeignManager* m) {
    struct WaylandForeignHandle* h, *tmp;
    wl_list_for_each_safe(h, tmp, &m->handles, link) {
        wl_list_remove(&h->link);
        wl_list_init(&h->link);
        h->manager = NULL;
        /* Inert from here: no manager means no server to route requests to,
         * and request() checks the surface, so also drop that link. */
        if (h->surface) {
            wl_list_remove(&h->surface_link);
            wl_list_init(&h->surface_link);
            h->surface = NULL;
        }
    }
}

static void manager_resource_destroyed(struct wl_resource* r) {
    struct WaylandForeignManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    manager_detach_handles(m);
    wl_list_remove(&m->link);
    free(m);
}

static void zwlr_manager_stop(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandForeignManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    m->stopped = 1;
    /* finished is a destructor event: the object is gone once sent. */
    zwlr_foreign_toplevel_manager_v1_send_finished(r);
    wl_resource_destroy(r);
}

static const struct zwlr_foreign_toplevel_manager_v1_interface zwlr_manager_impl = {
    .stop = zwlr_manager_stop,
};

static void ext_list_stop(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandForeignManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    m->stopped = 1;
    ext_foreign_toplevel_list_v1_send_finished(r);
}

static void ext_list_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_foreign_toplevel_list_v1_interface ext_list_impl = {
    .stop = ext_list_stop,
    .destroy = ext_list_destroy,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id, int ext) {
    struct WaylandServer* server = data;
    struct WaylandForeignManager* m = calloc(1, sizeof(*m));
    if (!m) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        ext ? &ext_foreign_toplevel_list_v1_interface
            : &zwlr_foreign_toplevel_manager_v1_interface, version, id);
    if (!r) {
        free(m);
        wl_client_post_no_memory(client);
        return;
    }
    m->resource = r;
    m->server = server;
    m->ext = ext;
    wl_list_init(&m->handles);
    wl_list_insert(&server->foreign_managers, &m->link);
    if (ext)
        wl_resource_set_implementation(r, &ext_list_impl, m, manager_resource_destroyed);
    else
        wl_resource_set_implementation(r, &zwlr_manager_impl, m, manager_resource_destroyed);

    /* Everything already on screen. */
    struct WaylandSurface* s;
    wl_list_for_each(s, &server->surfaces, link) {
        if (s->xdg_toplevel && s->mapped) handle_create(m, s);
    }
}

static void zwlr_manager_bind(struct wl_client* client, void* data,
                              uint32_t version, uint32_t id) {
    manager_bind(client, data, version, id, 0);
}

static void ext_list_bind(struct wl_client* client, void* data,
                          uint32_t version, uint32_t id) {
    manager_bind(client, data, version, id, 1);
}

void wayland_foreign_toplevel_init(struct WaylandServer* server) {
    wl_list_init(&server->foreign_managers);
    server->foreign_toplevel_manager_global = wl_global_create(server->display,
        &zwlr_foreign_toplevel_manager_v1_interface, 3, server, zwlr_manager_bind);
    server->ext_foreign_toplevel_list_global = wl_global_create(server->display,
        &ext_foreign_toplevel_list_v1_interface, 1, server, ext_list_bind);
}

/* ========================================================================== */
/* Hooks from the rest of the compositor                                      */
/* ========================================================================== */

void wayland_foreign_toplevel_map(struct WaylandServer* server,
                                  struct WaylandSurface* surface) {
    if (surface->mapped) return;
    surface->mapped = 1;
    static uint32_t map_counter = 0;
    snprintf(surface->foreign_identifier, sizeof(surface->foreign_identifier),
             "starling-%u-%u", surface->id, ++map_counter);
    struct WaylandForeignManager* m;
    wl_list_for_each(m, &server->foreign_managers, link) {
        if (!m->stopped) handle_create(m, surface);
    }
}

void wayland_foreign_toplevel_unmap(struct WaylandServer* server,
                                    struct WaylandSurface* surface) {
    (void)server;
    if (!surface->mapped) return;
    surface->mapped = 0;
    struct WaylandForeignHandle* h, *tmp;
    wl_list_for_each_safe(h, tmp, &surface->foreign_handles, surface_link) {
        if (h->manager && h->manager->ext)
            ext_foreign_toplevel_handle_v1_send_closed(h->resource);
        else
            zwlr_foreign_toplevel_handle_v1_send_closed(h->resource);
        wl_list_remove(&h->surface_link);
        wl_list_init(&h->surface_link);
        h->surface = NULL;   /* inert until the client destroys it */
    }
}

void wayland_foreign_toplevel_title(struct WaylandSurface* surface) {
    struct WaylandForeignHandle* h;
    wl_list_for_each(h, &surface->foreign_handles, surface_link) {
        handle_send_title(h);
        handle_send_done(h);
    }
}

void wayland_foreign_toplevel_app_id(struct WaylandSurface* surface) {
    struct WaylandForeignHandle* h;
    wl_list_for_each(h, &surface->foreign_handles, surface_link) {
        handle_send_app_id(h);
        handle_send_done(h);
    }
}

void wayland_foreign_toplevel_state(struct WaylandSurface* surface) {
    struct WaylandForeignHandle* h;
    wl_list_for_each(h, &surface->foreign_handles, surface_link) {
        if (h->manager->ext) continue;
        handle_send_state(h);
        handle_send_done(h);
    }
}

void wayland_foreign_toplevel_output(struct WaylandSurface* surface,
                                     struct WaylandOutput* output, int enter) {
    struct WaylandForeignHandle* h;
    wl_list_for_each(h, &surface->foreign_handles, surface_link) {
        if (h->manager->ext) continue;
        handle_send_output(h, output, enter);
        handle_send_done(h);
    }
}
