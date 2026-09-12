// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_toplevel_drag.c — xdg_toplevel_drag_manager_v1
 *
 * A window that rides along with a drag-and-drop: Chrome tearing a tab off
 * into its own window, a dock icon dragged out. The client starts an
 * ordinary wl_data_device drag, wraps its source in a toplevel-drag object,
 * and attaches a toplevel with the offset the pointer should keep from the
 * window's content origin. The drag itself lives in the data-device module;
 * this one records the attachment and tells the shell to follow the pointer
 * (on_toplevel_drag) until the drop.
 */

#include "wayland_server_internal.h"
#include "xdg-toplevel-drag-v1-protocol.h"
#include <stdlib.h>

struct ToplevelDrag {
    struct WaylandServer* server;
    struct wl_resource* source;          // the wl_data_source it wraps
    struct wl_listener source_gone;
};

static void drag_source_gone(struct wl_listener* l, void* data) {
    (void)data;
    struct ToplevelDrag* td = wl_container_of(l, td, source_gone);
    wl_list_remove(&td->source_gone.link);
    wl_list_init(&td->source_gone.link);
    td->source = NULL;
}

static void drag_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void drag_attach(struct wl_client* c, struct wl_resource* r,
                        struct wl_resource* toplevel, int32_t x_offset, int32_t y_offset) {
    (void)c;
    struct ToplevelDrag* td = wl_resource_get_user_data(r);
    if (!td) return;
    struct WaylandServer* server = td->server;
    struct WaylandSurface* surface = toplevel ? wl_resource_get_user_data(toplevel) : NULL;
    if (!surface) return;
    if (server->drag.active && server->drag.attached && server->drag.attached != surface) {
        wl_resource_post_error(r, XDG_TOPLEVEL_DRAG_V1_ERROR_TOPLEVEL_ATTACHED,
                               "a toplevel is already attached to this drag");
        return;
    }
    /* Attach may precede the drag's start: remember, and the drag picks it
     * up when it begins with this source; or apply at once if it is on. */
    server->drag.attached = surface;
    server->drag.attach_x = x_offset;
    server->drag.attach_y = y_offset;
    server->drag.toplevel_drag = r;
    if (server->drag.active && server->drag.source_resource == td->source &&
        server->cb.on_toplevel_drag) {
        server->cb.on_toplevel_drag(server->cb_ctx, surface->id, x_offset, y_offset, 1);
    }
}

static const struct xdg_toplevel_drag_v1_interface drag_impl = {
    .destroy = drag_destroy,
    .attach = drag_attach,
};

static void drag_resource_destroyed(struct wl_resource* r) {
    struct ToplevelDrag* td = wl_resource_get_user_data(r);
    if (!td) return;
    struct WaylandServer* server = td->server;
    if (server->drag.toplevel_drag == r) {
        server->drag.toplevel_drag = NULL;
        if (!server->drag.active) server->drag.attached = NULL;
    }
    if (td->source) wl_list_remove(&td->source_gone.link);
    free(td);
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_get_drag(struct wl_client* client, struct wl_resource* resource,
                             uint32_t id, struct wl_resource* source) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    if (!source) {
        wl_resource_post_error(resource, XDG_TOPLEVEL_DRAG_MANAGER_V1_ERROR_INVALID_SOURCE,
                               "a toplevel drag needs a data source");
        return;
    }
    struct ToplevelDrag* td = calloc(1, sizeof(*td));
    if (!td) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &xdg_toplevel_drag_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(td);
        wl_client_post_no_memory(client);
        return;
    }
    td->server = server;
    td->source = source;
    td->source_gone.notify = drag_source_gone;
    wl_resource_add_destroy_listener(source, &td->source_gone);
    wl_resource_set_implementation(r, &drag_impl, td, drag_resource_destroyed);
}

static const struct xdg_toplevel_drag_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .get_xdg_toplevel_drag = manager_get_drag,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &xdg_toplevel_drag_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_toplevel_drag_init(struct WaylandServer* server) {
    server->toplevel_drag_manager_global = wl_global_create(server->display,
        &xdg_toplevel_drag_manager_v1_interface, 1, server, manager_bind);
}
