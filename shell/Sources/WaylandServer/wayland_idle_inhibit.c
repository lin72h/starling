// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_idle_inhibit.c — zwp_idle_inhibit_manager_v1 implementation
 *
 * Prevents the compositor from blanking/sleeping the screen while a client
 * (e.g. Chrome playing video) has an active inhibitor. We accept the
 * requests but don't implement actual idle tracking — our DRM shell
 * doesn't blank the screen anyway.
 */

#include "wayland_server_internal.h"
#include "idle-inhibit-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* zwp_idle_inhibitor_v1                                                      */
/* ========================================================================== */

static void inhibitor_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_idle_inhibitor_v1_interface inhibitor_impl = {
    .destroy = inhibitor_destroy,
};

/* ========================================================================== */
/* zwp_idle_inhibit_manager_v1 (global)                                       */
/* ========================================================================== */

static void manager_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void manager_create_inhibitor(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t id,
                                     struct wl_resource* surface) {
    (void)surface;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* inh = wl_resource_create(client,
        &zwp_idle_inhibitor_v1_interface, 1, id);
    if (!inh) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(inh, &inhibitor_impl, server, NULL);
}

static const struct zwp_idle_inhibit_manager_v1_interface idle_inhibit_manager_impl = {
    .destroy = manager_destroy,
    .create_inhibitor = manager_create_inhibitor,
};

static void idle_inhibit_manager_bind(struct wl_client* client, void* data,
                                      uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_idle_inhibit_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &idle_inhibit_manager_impl, data, NULL);
}

void wayland_idle_inhibit_init(struct WaylandServer* server) {
    server->idle_inhibit_manager_global = wl_global_create(server->display,
        &zwp_idle_inhibit_manager_v1_interface, 1, server, idle_inhibit_manager_bind);
}
