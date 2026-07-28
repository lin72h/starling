// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_pointer_constraints.c — zwp_pointer_constraints_v1 implementation
 *
 * Allows clients to lock or confine the pointer to a surface region.
 * Chrome uses this for fullscreen video, games, and pointer lock API.
 *
 * We accept lock/confine requests and immediately send the locked/confined
 * event back. The actual constraint enforcement is left to the compositor.
 */

#include "wayland_server_internal.h"
#include "pointer-constraints-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* zwp_locked_pointer_v1                                                      */
/* ========================================================================== */

static void locked_pointer_destroy(struct wl_client* client,
                                   struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void locked_pointer_set_cursor_position_hint(struct wl_client* client,
                                                    struct wl_resource* resource,
                                                    wl_fixed_t x, wl_fixed_t y) {
    (void)client; (void)resource; (void)x; (void)y;
    /* Accept — compositor can use this to warp cursor on unlock. */
}

static void locked_pointer_set_region(struct wl_client* client,
                                      struct wl_resource* resource,
                                      struct wl_resource* region) {
    (void)client; (void)resource; (void)region;
    /* Accept — we don't constrain to sub-regions. */
}

static const struct zwp_locked_pointer_v1_interface locked_pointer_impl = {
    .destroy = locked_pointer_destroy,
    .set_cursor_position_hint = locked_pointer_set_cursor_position_hint,
    .set_region = locked_pointer_set_region,
};

/* ========================================================================== */
/* zwp_confined_pointer_v1                                                    */
/* ========================================================================== */

static void confined_pointer_destroy(struct wl_client* client,
                                     struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void confined_pointer_set_region(struct wl_client* client,
                                        struct wl_resource* resource,
                                        struct wl_resource* region) {
    (void)client; (void)resource; (void)region;
}

static const struct zwp_confined_pointer_v1_interface confined_pointer_impl = {
    .destroy = confined_pointer_destroy,
    .set_region = confined_pointer_set_region,
};

/* ========================================================================== */
/* zwp_pointer_constraints_v1 (global)                                        */
/* ========================================================================== */

static void constraints_destroy(struct wl_client* client,
                                struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void constraints_lock_pointer(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t id,
                                     struct wl_resource* surface,
                                     struct wl_resource* pointer,
                                     struct wl_resource* region,
                                     uint32_t lifetime) {
    (void)surface; (void)pointer; (void)region; (void)lifetime;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* locked = wl_resource_create(client,
        &zwp_locked_pointer_v1_interface, 1, id);
    if (!locked) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(locked, &locked_pointer_impl, server, NULL);

    /* Immediately confirm the lock. */
    zwp_locked_pointer_v1_send_locked(locked);
}

static void constraints_confine_pointer(struct wl_client* client,
                                        struct wl_resource* resource,
                                        uint32_t id,
                                        struct wl_resource* surface,
                                        struct wl_resource* pointer,
                                        struct wl_resource* region,
                                        uint32_t lifetime) {
    (void)surface; (void)pointer; (void)region; (void)lifetime;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* confined = wl_resource_create(client,
        &zwp_confined_pointer_v1_interface, 1, id);
    if (!confined) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(confined, &confined_pointer_impl, server, NULL);

    /* Immediately confirm confinement. */
    zwp_confined_pointer_v1_send_confined(confined);
}

static const struct zwp_pointer_constraints_v1_interface constraints_impl = {
    .destroy = constraints_destroy,
    .lock_pointer = constraints_lock_pointer,
    .confine_pointer = constraints_confine_pointer,
};

static void constraints_bind(struct wl_client* client, void* data,
                             uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_pointer_constraints_v1_interface, version, id);
    wl_resource_set_implementation(resource, &constraints_impl, data, NULL);
}

void wayland_pointer_constraints_init(struct WaylandServer* server) {
    server->pointer_constraints_global = wl_global_create(server->display,
        &zwp_pointer_constraints_v1_interface, 1, server, constraints_bind);
}
