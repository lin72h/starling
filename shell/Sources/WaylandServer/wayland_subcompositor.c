// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_subcompositor.c — wl_subcompositor and wl_subsurface stubs
 *
 * Minimal implementation so clients like Chrome that require
 * wl_subcompositor (for tooltips/popups) don't crash on bind failure.
 * All wl_subsurface requests are no-ops.
 */

#include "wayland_server_internal.h"
#include <stdlib.h>
#include <stdio.h>

/* ========================================================================== */
/* wl_subsurface stubs                                                        */
/* ========================================================================== */

static void subsurface_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void subsurface_set_position(struct wl_client* client,
                                    struct wl_resource* resource,
                                    int32_t x, int32_t y) {
    (void)client;
    /* The subsurface resource carries the child WaylandSurface as user_data
     * (set in get_subsurface). Record the offset so the compositor can place
     * the subsurface's content within the parent window. */
    struct WaylandSurface* s = wl_resource_get_user_data(resource);
    if (s) {
        s->subsurface_x = x;
        s->subsurface_y = y;
    }
}

static void subsurface_place_above(struct wl_client* client,
                                   struct wl_resource* resource,
                                   struct wl_resource* sibling) {
    (void)client; (void)resource; (void)sibling;
}

static void subsurface_place_below(struct wl_client* client,
                                   struct wl_resource* resource,
                                   struct wl_resource* sibling) {
    (void)client; (void)resource; (void)sibling;
}

static void subsurface_set_sync(struct wl_client* client,
                                struct wl_resource* resource) {
    (void)client; (void)resource;
}

static void subsurface_set_desync(struct wl_client* client,
                                  struct wl_resource* resource) {
    (void)client; (void)resource;
}

/*
 * wl_subsurface requests (in protocol order):
 *   0  destroy
 *   1  set_position
 *   2  place_above
 *   3  place_below
 *   4  set_sync
 *   5  set_desync
 */
static const struct wl_subsurface_interface subsurface_impl = {
    .destroy       = subsurface_destroy,
    .set_position  = subsurface_set_position,
    .place_above   = subsurface_place_above,
    .place_below   = subsurface_place_below,
    .set_sync      = subsurface_set_sync,
    .set_desync    = subsurface_set_desync,
};

/* ========================================================================== */
/* wl_subcompositor                                                           */
/* ========================================================================== */

static void subcompositor_destroy(struct wl_client* client,
                                  struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void subcompositor_get_subsurface(struct wl_client* client,
                                         struct wl_resource* resource,
                                         uint32_t id,
                                         struct wl_resource* surface,
                                         struct wl_resource* parent) {
    struct wl_resource* subsurface = wl_resource_create(
        client, &wl_subsurface_interface,
        wl_resource_get_version(resource), id);
    if (!subsurface) {
        wl_resource_post_no_memory(resource);
        return;
    }

    struct WaylandSurface* s = wl_resource_get_user_data(surface);
    struct WaylandSurface* p = wl_resource_get_user_data(parent);

    /* Wire the subsurface->parent relationship so the compositor can route the
     * subsurface's committed buffer up to its toplevel ancestor's window
     * texture. The subsurface resource carries the child WaylandSurface so
     * set_position can update its offset. */
    if (s) {
        s->is_subsurface = 1;
        s->subsurface_parent = p;
        s->subsurface_x = 0;
        s->subsurface_y = 0;
    }
    wl_resource_set_implementation(subsurface, &subsurface_impl, s, NULL);
}

/*
 * wl_subcompositor requests:
 *   0  destroy
 *   1  get_subsurface
 */
static const struct wl_subcompositor_interface subcompositor_impl = {
    .destroy        = subcompositor_destroy,
    .get_subsurface = subcompositor_get_subsurface,
};

static void subcompositor_bind(struct wl_client* client, void* data,
                               uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(
        client, &wl_subcompositor_interface, version, id);
    wl_resource_set_implementation(resource, &subcompositor_impl, data, NULL);
}

void wayland_subcompositor_init(struct WaylandServer* server) {
    server->subcompositor_global = wl_global_create(
        server->display, &wl_subcompositor_interface, 1,
        server, subcompositor_bind);
}
