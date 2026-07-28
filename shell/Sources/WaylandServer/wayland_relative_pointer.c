// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_relative_pointer.c — zwp_relative_pointer_v1 implementation
 *
 * Provides raw relative pointer motion events (dx/dy deltas) independent
 * of absolute position. Used together with pointer constraints for games,
 * 3D viewports, and Chrome's pointer lock API.
 *
 * We track relative pointer resources per-client so the compositor can
 * send relative motion events when pointer lock is active.
 */

#include "wayland_server_internal.h"
#include "relative-pointer-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* zwp_relative_pointer_v1 (per-pointer relative motion receiver)             */
/* ========================================================================== */

/* Resource destructor — runs on explicit destroy AND client disconnect.
 * Cleanup must live here, not in the request handler: a client that
 * disconnects without sending `destroy` (normal for Chrome process churn)
 * would otherwise leave a freed resource linked in server->relative_pointers
 * — a use-after-free for the first relative-motion send afterwards. */
static void relative_pointer_resource_destroy(struct wl_resource* resource) {
    struct WaylandRelativePointerResource* rp = wl_resource_get_user_data(resource);
    if (rp) {
        wl_list_remove(&rp->link);
        free(rp);
    }
}

static void relative_pointer_destroy(struct wl_client* client,
                                     struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);  /* triggers relative_pointer_resource_destroy */
}

static const struct zwp_relative_pointer_v1_interface relative_pointer_impl = {
    .destroy = relative_pointer_destroy,
};

/* ========================================================================== */
/* zwp_relative_pointer_manager_v1 (global)                                   */
/* ========================================================================== */

static void manager_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void manager_get_relative_pointer(struct wl_client* client,
                                         struct wl_resource* resource,
                                         uint32_t id,
                                         struct wl_resource* pointer) {
    (void)pointer;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* rp_resource = wl_resource_create(client,
        &zwp_relative_pointer_v1_interface, 1, id);
    if (!rp_resource) {
        wl_client_post_no_memory(client);
        return;
    }

    struct WaylandRelativePointerResource* rp =
        calloc(1, sizeof(struct WaylandRelativePointerResource));
    if (!rp) {
        wl_resource_destroy(rp_resource);
        wl_client_post_no_memory(client);
        return;
    }
    rp->resource = rp_resource;
    wl_list_insert(&server->relative_pointers, &rp->link);

    wl_resource_set_implementation(rp_resource, &relative_pointer_impl, rp,
                                   relative_pointer_resource_destroy);
}

static const struct zwp_relative_pointer_manager_v1_interface rel_ptr_manager_impl = {
    .destroy = manager_destroy,
    .get_relative_pointer = manager_get_relative_pointer,
};

static void rel_ptr_manager_bind(struct wl_client* client, void* data,
                                 uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_relative_pointer_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &rel_ptr_manager_impl, data, NULL);
}

void wayland_relative_pointer_init(struct WaylandServer* server) {
    wl_list_init(&server->relative_pointers);
    server->relative_pointer_manager_global = wl_global_create(server->display,
        &zwp_relative_pointer_manager_v1_interface, 1, server, rel_ptr_manager_bind);
}
