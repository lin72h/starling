// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_pointer_warp.c — wp_pointer_warp_v1
 *
 * A client with pointer focus asks for the pointer to be put at a point of
 * its surface: games recentring, a virtual-machine viewer syncing the
 * guest's cursor. The request names the wl_pointer and a recent input
 * serial; the shell decides whether the surface really has the pointer
 * and moves the real cursor there (on_pointer_warp).
 */

#include "wayland_server_internal.h"
#include "pointer-warp-v1-protocol.h"

static void warp_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void warp_pointer(struct wl_client* c, struct wl_resource* r,
                         struct wl_resource* wl_surface, struct wl_resource* pointer,
                         wl_fixed_t x, wl_fixed_t y, uint32_t serial) {
    (void)c; (void)pointer; (void)serial;
    struct WaylandServer* server = wl_resource_get_user_data(r);
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (!surface) return;
    if (server->cb.on_pointer_warp)
        server->cb.on_pointer_warp(server->cb_ctx, surface->id,
                                   wl_fixed_to_double(x), wl_fixed_to_double(y));
}

static const struct wp_pointer_warp_v1_interface warp_impl = {
    .destroy = warp_destroy,
    .warp_pointer = warp_pointer,
};

static void warp_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client, &wp_pointer_warp_v1_interface,
                                               version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &warp_impl, data, NULL);
}

void wayland_pointer_warp_init(struct WaylandServer* server) {
    server->pointer_warp_global = wl_global_create(server->display,
        &wp_pointer_warp_v1_interface, 1, server, warp_bind);
}
