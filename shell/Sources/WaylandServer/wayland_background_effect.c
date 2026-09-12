// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_background_effect.c — ext_background_effect_manager_v1
 *
 * A client asks for what is behind a region of its surface to be blurred —
 * the frosted panels and translucent sidebars of GNOME and KDE apps. The
 * region is double-buffered and reaches the shell on commit
 * (on_surface_blur), which draws a blur under the window's content there;
 * a surface with a blur region keeps its alpha, since the effect is only
 * visible through a translucent window.
 */

#include "wayland_server_internal.h"
#include "ext-background-effect-v1-protocol.h"
#include <stdlib.h>
#include <string.h>

static void effect_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void effect_set_blur_region(struct wl_client* c, struct wl_resource* r,
                                   struct wl_resource* region) {
    (void)c;
    struct WaylandSurface* surface = wl_resource_get_user_data(r);
    if (!surface) {
        wl_resource_post_error(r, EXT_BACKGROUND_EFFECT_SURFACE_V1_ERROR_SURFACE_DESTROYED,
                               "the wl_surface is gone");
        return;
    }
    struct WaylandRegion* reg = region ? wl_resource_get_user_data(region) : NULL;
    surface->pending_blur_count = reg ? reg->count : 0;
    if (reg) memcpy(surface->pending_blur_rects, reg->rects, sizeof(reg->rects));
    surface->pending_blur_set = 1;
}

static const struct ext_background_effect_surface_v1_interface effect_impl = {
    .destroy = effect_destroy,
    .set_blur_region = effect_set_blur_region,
};

static void effect_resource_destroyed(struct wl_resource* r) {
    struct WaylandSurface* surface = wl_resource_get_user_data(r);
    if (!surface) return;
    if (surface->background_effect_resource == r) surface->background_effect_resource = NULL;
    /* Gone: the region clears on the next commit, like the alpha modifier. */
    surface->pending_blur_count = 0;
    surface->pending_blur_set = 1;
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_get_background_effect(struct wl_client* client, struct wl_resource* resource,
                                          uint32_t id, struct wl_resource* wl_surface) {
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (surface && surface->background_effect_resource) {
        wl_resource_post_error(resource,
            EXT_BACKGROUND_EFFECT_MANAGER_V1_ERROR_BACKGROUND_EFFECT_EXISTS,
            "the surface already has a background effect");
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &ext_background_effect_surface_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &effect_impl, surface, effect_resource_destroyed);
    if (surface) surface->background_effect_resource = r;
}

static const struct ext_background_effect_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .get_background_effect = manager_get_background_effect,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_background_effect_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
    ext_background_effect_manager_v1_send_capabilities(r,
        EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR);
}

void wayland_background_effect_init(struct WaylandServer* server) {
    server->background_effect_global = wl_global_create(server->display,
        &ext_background_effect_manager_v1_interface, 1, server, manager_bind);
}

void wayland_background_effect_commit(struct WaylandServer* server,
                                      struct WaylandSurface* surface) {
    if (!surface->pending_blur_set) return;
    surface->pending_blur_set = 0;
    int same = surface->pending_blur_count == surface->blur_count &&
               memcmp(surface->pending_blur_rects, surface->blur_rects,
                      (size_t)surface->blur_count * sizeof(surface->blur_rects[0])) == 0;
    if (same) return;
    surface->blur_count = surface->pending_blur_count;
    memcpy(surface->blur_rects, surface->pending_blur_rects, sizeof(surface->blur_rects));
    if (server->cb.on_surface_blur)
        server->cb.on_surface_blur(server->cb_ctx, surface->id,
                                   &surface->blur_rects[0][0], surface->blur_count);
}
