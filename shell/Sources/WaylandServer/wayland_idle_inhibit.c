// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_idle_inhibit.c — zwp_idle_inhibit_manager_v1 implementation
 *
 * Prevents the screensaver from appearing while a client (e.g. Chrome
 * playing video) holds an inhibitor. We only count live inhibitors and
 * publish the count; the shell's idle timer reads it and treats a nonzero
 * count as activity. The surface argument is ignored — the protocol scopes
 * an inhibitor to one surface's visibility, but the shell has a single
 * full-screen saver, so any live inhibitor suppresses it.
 *
 * The count must be maintained by a resource DESTRUCTOR, not by the
 * explicit destroy request: a client that exits (or crashes) mid-video
 * never sends one, and a leaked inhibitor would suppress the screensaver
 * for the rest of the session. wl_resource destructors run on client
 * disconnect too, which is the only way to get this right.
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

/* Runs on explicit destroy AND on client disconnect — see the file header. */
static void inhibitor_resource_destroyed(struct wl_resource* resource) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    if (server && server->idle_inhibitors > 0) {
        server->idle_inhibitors--;
    }
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
    wl_resource_set_implementation(inh, &inhibitor_impl, server,
                                   inhibitor_resource_destroyed);
    server->idle_inhibitors++;
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
    server->idle_inhibitors = 0;
    server->idle_inhibit_manager_global = wl_global_create(server->display,
        &zwp_idle_inhibit_manager_v1_interface, 1, server, idle_inhibit_manager_bind);
}

int wayland_server_idle_inhibited(struct WaylandServer* server) {
    return server ? server->idle_inhibitors : 0;
}
