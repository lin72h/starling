// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_viewporter.c — wp_viewporter implementation
 *
 * Allows clients to crop (set_source) and scale (set_destination) surface
 * contents. Chrome uses this extensively for video, tab thumbnails, and
 * surface scaling.
 *
 * The state is double-buffered — applied on wl_surface.commit. Our compositor
 * doesn't use the crop/scale values itself (the client handles rendering),
 * so we just accept and store the requests without error.
 */

#include "wayland_server_internal.h"
#include "viewporter-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* wp_viewport (per-surface crop/scale object)                                */
/* ========================================================================== */

/* Reference the surface by id, not pointer: the WaylandSurface can be freed
 * while the wp_viewport is still alive (destroy wl_surface, keep viewport —
 * legal order). An id lookup can only ever miss; a stored pointer dangles. */
struct ViewportData {
    struct WaylandServer* server;
    uint32_t surface_id;
};

/* Resource destructor — runs on explicit destroy AND client disconnect
 * (freeing only in the destroy *request* leaked one ViewportData per
 * viewport on every disconnect). */
static void viewport_resource_destroy(struct wl_resource* resource) {
    struct ViewportData* vd = wl_resource_get_user_data(resource);
    free(vd);
}

static void viewport_destroy(struct wl_client* client,
                             struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);  /* triggers viewport_resource_destroy */
}

static void viewport_set_source(struct wl_client* client,
                                struct wl_resource* resource,
                                wl_fixed_t x, wl_fixed_t y,
                                wl_fixed_t width, wl_fixed_t height) {
    (void)client;
    (void)resource;
    /* Accept and ignore — our compositor doesn't need to crop the source.
     * The client's renderer handles this internally. */
    (void)x; (void)y; (void)width; (void)height;
}

static void viewport_set_destination(struct wl_client* client,
                                     struct wl_resource* resource,
                                     int32_t width, int32_t height) {
    (void)client;
    /* Store viewport destination on the surface for buffer→surface mapping.
     * Applied on the next wl_surface.commit (double-buffered). */
    struct ViewportData* vd = wl_resource_get_user_data(resource);
    if (!vd) return;
    struct WaylandSurface* surface =
        wayland_server_find_surface(vd->server, vd->surface_id);
    if (surface) {
        surface->viewport_dst_width = width > 0 ? width : 0;
        surface->viewport_dst_height = height > 0 ? height : 0;
    }
}

static const struct wp_viewport_interface viewport_impl = {
    .destroy = viewport_destroy,
    .set_source = viewport_set_source,
    .set_destination = viewport_set_destination,
};

/* ========================================================================== */
/* wp_viewporter (global)                                                     */
/* ========================================================================== */

static void viewporter_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void viewporter_get_viewport(struct wl_client* client,
                                    struct wl_resource* resource,
                                    uint32_t id,
                                    struct wl_resource* surface_resource) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* vp_resource = wl_resource_create(client,
        &wp_viewport_interface, 1, id);
    if (!vp_resource) {
        wl_client_post_no_memory(client);
        return;
    }

    /* Find the WaylandSurface for this wl_surface resource. */
    struct ViewportData* vd = calloc(1, sizeof(struct ViewportData));
    if (vd) {
        vd->server = server;
        struct WaylandSurface* surf;
        wl_list_for_each(surf, &server->surfaces, link) {
            if (surf->resource == surface_resource) {
                vd->surface_id = surf->id;
                break;
            }
        }
    }
    wl_resource_set_implementation(vp_resource, &viewport_impl, vd,
                                   viewport_resource_destroy);
}

static const struct wp_viewporter_interface viewporter_impl = {
    .destroy = viewporter_destroy,
    .get_viewport = viewporter_get_viewport,
};

static void viewporter_bind(struct wl_client* client, void* data,
                            uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wp_viewporter_interface, version, id);
    wl_resource_set_implementation(resource, &viewporter_impl, data, NULL);
}

void wayland_viewporter_init(struct WaylandServer* server) {
    server->viewporter_global = wl_global_create(server->display,
        &wp_viewporter_interface, 1, server, viewporter_bind);
}
