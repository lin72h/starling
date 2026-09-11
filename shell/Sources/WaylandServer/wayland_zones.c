// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_zones.c — xx_zone_manager_v1 (experimental)
 *
 * Explicit placement of managed toplevels, which core Wayland forbids: a
 * client gets a "zone" — here, one output's work area — and asks for its
 * window at (x, y) inside it; the compositor places the window (clamping as
 * it likes) and reports where it actually is, also when the user drags it.
 * wmbench uses it to walk windows across the screen while they stay real,
 * decorated, managed toplevels, and reads their positions back instead of
 * trusting its own. As of writing no shipping compositor offers it; the
 * shell's free-floating window manager makes it nearly free for us.
 *
 * Coordinates are the window FRAME's top-left (title bar included) relative
 * to the work area's top-left, in logical pixels; frame_extents tells the
 * client how thick the frame is. The shell answers a position request
 * asynchronously with wayland_server_toplevel_position; a request made
 * while the item has no zone fails at once.
 */

#include "wayland_server_internal.h"
#include "xx-zones-v1-protocol.h"
#include "xdg-shell-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void zone_size(struct WaylandServer* server, int index,
                      int32_t* w, int32_t* h) {
    if (index < 0 || index >= server->output_count) {
        *w = -1;
        *h = -1;
        return;
    }
    if (server->work_area[index].w > 0 && server->work_area[index].h > 0) {
        *w = server->work_area[index].w;
        *h = server->work_area[index].h;
        return;
    }
    struct WaylandOutput* o = &server->outputs[index];
    int32_t scale = o->scale > 0 ? o->scale : 1;
    *w = o->physical_w / scale;
    *h = o->physical_h / scale;
}

/* ========================================================================== */
/* xx_zone_item_v1                                                            */
/* ========================================================================== */

static void item_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void item_set_position(struct wl_client* c, struct wl_resource* r,
                              int32_t x, int32_t y) {
    (void)c;
    struct WaylandZoneItem* it = wl_resource_get_user_data(r);
    if (!it || !it->surface) return;     /* inert */
    it->pending_x = x;
    it->pending_y = y;
    it->pending_pos_set = 1;
}

static const struct xx_zone_item_v1_interface item_impl = {
    .destroy = item_destroy,
    .set_position = item_set_position,
};

static void item_leave_zone(struct WaylandZoneItem* it) {
    if (!it->zone) return;
    xx_zone_v1_send_item_left(it->zone->resource, it->resource);
    it->zone = NULL;
}

static void item_resource_destroyed(struct wl_resource* r) {
    struct WaylandZoneItem* it = wl_resource_get_user_data(r);
    if (!it) return;
    if (it->surface) {
        item_leave_zone(it);
        if (it->surface->zone_item == it) it->surface->zone_item = NULL;
    }
    wl_list_remove(&it->link);
    free(it);
}

/* ========================================================================== */
/* xx_zone_v1                                                                 */
/* ========================================================================== */

static void zone_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void zone_add_item(struct wl_client* c, struct wl_resource* r,
                          struct wl_resource* item_res) {
    (void)c;
    struct WaylandZone* z = wl_resource_get_user_data(r);
    struct WaylandZoneItem* it = item_res ? wl_resource_get_user_data(item_res) : NULL;
    if (!z || !it || !it->surface) return;   /* inert item: ignore */
    int32_t w, h;
    zone_size(z->server, z->output_index, &w, &h);
    if (w < 0) {
        wl_resource_post_error(r, XX_ZONE_V1_ERROR_INVALID,
                               "zone is invalid");
        return;
    }
    it->pending_zone = z;
    it->pending_zone_set = 1;
    it->pending_remove = 0;
}

static void zone_remove_item(struct wl_client* c, struct wl_resource* r,
                             struct wl_resource* item_res) {
    (void)c;
    struct WaylandZone* z = wl_resource_get_user_data(r);
    struct WaylandZoneItem* it = item_res ? wl_resource_get_user_data(item_res) : NULL;
    if (!z || !it || !it->surface) return;
    it->pending_remove = 1;
    it->pending_zone_set = 0;
    it->pending_zone = NULL;
}

static const struct xx_zone_v1_interface zone_impl = {
    .destroy = zone_destroy,
    .add_item = zone_add_item,
    .remove_item = zone_remove_item,
};

static void zone_resource_destroyed(struct wl_resource* r) {
    struct WaylandZone* z = wl_resource_get_user_data(r);
    if (!z) return;
    /* Items keep their placement but lose the reference — a dangling zone
     * pointer would be read on the next commit. */
    struct WaylandZoneItem* it;
    wl_list_for_each(it, &z->server->zone_items, link) {
        if (it->zone == z) it->zone = NULL;
        if (it->pending_zone == z) {
            it->pending_zone = NULL;
            it->pending_zone_set = 0;
        }
    }
    wl_list_remove(&z->link);
    free(z);
}

static void zone_announce(struct WaylandZone* z) {
    int32_t w, h;
    zone_size(z->server, z->output_index, &w, &h);
    xx_zone_v1_send_size(z->resource, w, h);
    xx_zone_v1_send_handle(z->resource, w < 0 ? "" : z->handle);
    xx_zone_v1_send_done(z->resource);
}

static struct WaylandZone* zone_create(struct wl_client* client,
                                       struct wl_resource* manager, uint32_t id,
                                       int output_index, const char* handle) {
    struct WaylandServer* server = wl_resource_get_user_data(manager);
    struct WaylandZone* z = calloc(1, sizeof(*z));
    if (!z) {
        wl_client_post_no_memory(client);
        return NULL;
    }
    struct wl_resource* r = wl_resource_create(client, &xx_zone_v1_interface,
        wl_resource_get_version(manager), id);
    if (!r) {
        free(z);
        wl_client_post_no_memory(client);
        return NULL;
    }
    z->resource = r;
    z->server = server;
    z->output_index = output_index;
    if (handle && handle[0]) {
        snprintf(z->handle, sizeof(z->handle), "%s", handle);
    } else {
        snprintf(z->handle, sizeof(z->handle), "starling-zone-%d-%u",
                 output_index, ++server->next_zone_handle);
    }
    wl_list_insert(&server->zones, &z->link);
    wl_resource_set_implementation(r, &zone_impl, z, zone_resource_destroyed);
    zone_announce(z);
    return z;
}

/* ========================================================================== */
/* xx_zone_manager_v1                                                         */
/* ========================================================================== */

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_get_zone_item(struct wl_client* client,
                                  struct wl_resource* resource, uint32_t id,
                                  struct wl_resource* toplevel) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSurface* surface = toplevel ? wl_resource_get_user_data(toplevel) : NULL;
    struct WaylandZoneItem* it = calloc(1, sizeof(*it));
    if (!it) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &xx_zone_item_v1_interface,
        wl_resource_get_version(resource), id);
    if (!r) {
        free(it);
        wl_client_post_no_memory(client);
        return;
    }
    it->resource = r;
    it->server = server;
    it->surface = surface;
    wl_list_insert(&server->zone_items, &it->link);
    wl_resource_set_implementation(r, &item_impl, it, item_resource_destroyed);
    if (surface) {
        /* One item per toplevel is all the shell tracks; a second replaces
         * the first, which goes inert. */
        if (surface->zone_item) surface->zone_item->surface = NULL;
        surface->zone_item = it;
    } else {
        xx_zone_item_v1_send_closed(r);
    }
}

static void manager_get_zone(struct wl_client* client,
                             struct wl_resource* resource, uint32_t id,
                             struct wl_resource* output) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    int idx = output ? wayland_output_index_of(server, output) : 0;
    if (idx < 0) idx = 0;
    zone_create(client, resource, id, idx, NULL);
}

static void manager_get_zone_from_handle(struct wl_client* client,
                                         struct wl_resource* resource,
                                         uint32_t id, const char* handle) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandZone* z;
    wl_list_for_each(z, &server->zones, link) {
        if (handle && strcmp(z->handle, handle) == 0) {
            zone_create(client, resource, id, z->output_index, z->handle);
            return;
        }
    }
    zone_create(client, resource, id, 0, NULL);
}

static const struct xx_zone_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .get_zone_item = manager_get_zone_item,
    .get_zone = manager_get_zone,
    .get_zone_from_handle = manager_get_zone_from_handle,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &xx_zone_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_zones_init(struct WaylandServer* server) {
    wl_list_init(&server->zones);
    wl_list_init(&server->zone_items);
    server->zone_manager_global = wl_global_create(server->display,
        &xx_zone_manager_v1_interface, 1, server, manager_bind);
}

/* ========================================================================== */
/* Commit + hooks                                                             */
/* ========================================================================== */

static void item_send_position(struct WaylandZoneItem* it, int32_t x, int32_t y) {
    it->last_x = x;
    it->last_y = y;
    it->have_last = 1;
    xx_zone_item_v1_send_position(it->resource, x, y);
}

void wayland_zones_commit(struct WaylandServer* server,
                          struct WaylandSurface* surface) {
    struct WaylandZoneItem* it = surface->zone_item;
    if (!it) return;

    if (it->pending_remove) {
        it->pending_remove = 0;
        item_leave_zone(it);
    }
    if (it->pending_zone_set) {
        it->pending_zone_set = 0;
        struct WaylandZone* z = it->pending_zone;
        it->pending_zone = NULL;
        if (z) {
            if (it->zone && it->zone != z) item_leave_zone(it);
            it->zone = z;
            xx_zone_v1_send_item_entered(z->resource, it->resource);
            xx_zone_item_v1_send_frame_extents(it->resource,
                server->frame_top, server->frame_bottom,
                server->frame_left, server->frame_right);
            item_send_position(it, it->have_last ? it->last_x : 0,
                                   it->have_last ? it->last_y : 0);
        }
    }
    if (it->pending_pos_set) {
        it->pending_pos_set = 0;
        if (!it->zone || !server->cb.on_toplevel_position_request) {
            xx_zone_item_v1_send_position_failed(it->resource);
        } else {
            it->awaiting_position = 1;
            server->cb.on_toplevel_position_request(server->cb_ctx, surface->id,
                                                    it->zone->output_index,
                                                    it->pending_x, it->pending_y);
        }
    }
}

void wayland_zones_surface_destroyed(struct WaylandServer* server,
                                     struct WaylandSurface* surface) {
    (void)server;
    struct WaylandZoneItem* it = surface->zone_item;
    if (!it) return;
    item_leave_zone(it);
    xx_zone_item_v1_send_closed(it->resource);
    it->surface = NULL;
    surface->zone_item = NULL;
}

void wayland_zones_work_area_changed(struct WaylandServer* server,
                                     int output_index) {
    int32_t w, h;
    zone_size(server, output_index, &w, &h);
    struct WaylandZone* z;
    wl_list_for_each(z, &server->zones, link) {
        if (z->output_index == output_index) xx_zone_v1_send_size(z->resource, w, h);
    }
}

void wayland_server_toplevel_position(WaylandServer* server, uint32_t surface_id,
                                      int32_t x, int32_t y) {
    WARN_IF_OFF_LOOP_THREAD(server, "toplevel_position");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface || !surface->zone_item) return;
    struct WaylandZoneItem* it = surface->zone_item;
    if (!it->zone) return;
    if (!it->awaiting_position && it->have_last &&
        it->last_x == x && it->last_y == y) return;
    it->awaiting_position = 0;
    item_send_position(it, x, y);
}

void wayland_server_toplevel_position_failed(WaylandServer* server,
                                             uint32_t surface_id) {
    WARN_IF_OFF_LOOP_THREAD(server, "toplevel_position_failed");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface || !surface->zone_item) return;
    surface->zone_item->awaiting_position = 0;
    xx_zone_item_v1_send_position_failed(surface->zone_item->resource);
}

void wayland_server_set_frame_extents(WaylandServer* server, int32_t top,
                                      int32_t bottom, int32_t left, int32_t right) {
    if (!server) return;
    server->frame_top = top;
    server->frame_bottom = bottom;
    server->frame_left = left;
    server->frame_right = right;
}

void wayland_server_set_work_area(WaylandServer* server, int output_index,
                                  int32_t x, int32_t y, int32_t w, int32_t h) {
    if (!server || output_index < 0 || output_index >= WAYLAND_MAX_OUTPUTS) return;
    WARN_IF_OFF_LOOP_THREAD(server, "set_work_area");
    if (server->work_area[output_index].x == x && server->work_area[output_index].y == y &&
        server->work_area[output_index].w == w && server->work_area[output_index].h == h)
        return;
    server->work_area[output_index].x = x;
    server->work_area[output_index].y = y;
    server->work_area[output_index].w = w;
    server->work_area[output_index].h = h;
    wayland_zones_work_area_changed(server, output_index);
}
