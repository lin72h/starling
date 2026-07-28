// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_fractional_scale.c — wp_fractional_scale_v1 implementation
 *
 * Allows the compositor to send a preferred fractional scale to clients.
 * Chrome uses this to determine buffer sizing (buffer = configure * scale).
 * Hyprland sends preferred_scale=180 (1.5x) for 3840x2160 displays.
 */

#include "wayland_server_internal.h"
#include "fractional-scale-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* wp_fractional_scale_v1 (per-surface scale object)                          */
/* ========================================================================== */

static void fractional_scale_destroy(struct wl_client* client,
                                     struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct wp_fractional_scale_v1_interface fractional_scale_impl = {
    .destroy = fractional_scale_destroy,
};

/* Resource destructor — clear the surface back-pointer so it can't dangle
 * when the client destroys the fs object but keeps the surface. If the
 * surface died first it's no longer in the list and this is a no-op. */
static void fractional_scale_resource_destroy(struct wl_resource* resource) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    if (!server) return;
    struct WaylandSurface* surf;
    wl_list_for_each(surf, &server->surfaces, link) {
        if (surf->fractional_scale_resource == resource) {
            surf->fractional_scale_resource = NULL;
            break;
        }
    }
}

/* ========================================================================== */
/* wp_fractional_scale_manager_v1 (global)                                    */
/* ========================================================================== */

static void manager_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void manager_get_fractional_scale(struct wl_client* client,
                                         struct wl_resource* resource,
                                         uint32_t id,
                                         struct wl_resource* surface_resource) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* fs_resource = wl_resource_create(client,
        &wp_fractional_scale_v1_interface, 1, id);
    if (!fs_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(fs_resource, &fractional_scale_impl, server,
                                   fractional_scale_resource_destroy);

    /* Send preferred_scale immediately.
     * Scale is in 120ths: 120 = 1.0x, 180 = 1.5x, 240 = 2.0x.
     * Must match the integer output scale — Chrome computes fullscreen
     * buffer dimensions using the fractional scale, and mismatched scales
     * cause incorrect buffer heights. */
    uint32_t preferred = server->fractional_scale_120ths;
    if (preferred == 0) {
        int scale = server->config.scale > 0 ? server->config.scale : 1;
        preferred = (uint32_t)(scale * 120);
    }
    wp_fractional_scale_v1_send_preferred_scale(fs_resource, preferred);

    /* Also store on the surface so we can re-send on output enter. */
    struct WaylandSurface* surf;
    wl_list_for_each(surf, &server->surfaces, link) {
        if (surf->resource == surface_resource) {
            surf->fractional_scale_resource = fs_resource;
            break;
        }
    }
}

static const struct wp_fractional_scale_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .get_fractional_scale = manager_get_fractional_scale,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wp_fractional_scale_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &manager_impl, data, NULL);
}

void wayland_fractional_scale_init(struct WaylandServer* server) {
    server->fractional_scale_global = wl_global_create(server->display,
        &wp_fractional_scale_manager_v1_interface, 1, server, manager_bind);
}
