// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_alpha_modifier.c — wp_alpha_modifier_v1
 *
 * A whole-surface opacity multiplier, applied by the compositor on top of
 * the buffer's own alpha. Double-buffered: set_multiplier takes effect on
 * the next commit, and destroying the object is the same as setting it back
 * to 1.0 on the next commit. The shell hears the committed value through
 * on_surface_alpha and draws the window's content through an Opacity.
 */

#include "wayland_server_internal.h"
#include "alpha-modifier-v1-protocol.h"
#include <stdlib.h>

static void alpha_surface_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void alpha_surface_set_multiplier(struct wl_client* c,
                                         struct wl_resource* r,
                                         uint32_t factor) {
    (void)c;
    struct WaylandSurface* surface = wl_resource_get_user_data(r);
    if (!surface) {
        wl_resource_post_error(r, WP_ALPHA_MODIFIER_SURFACE_V1_ERROR_NO_SURFACE,
                               "the wl_surface is gone");
        return;
    }
    surface->pending_alpha = (double)factor / 4294967295.0;
    surface->pending_alpha_set = 1;
}

static const struct wp_alpha_modifier_surface_v1_interface alpha_surface_impl = {
    .destroy = alpha_surface_destroy,
    .set_multiplier = alpha_surface_set_multiplier,
};

/* Explicit destroy and client disconnect alike. */
static void alpha_surface_resource_destroyed(struct wl_resource* r) {
    struct WaylandSurface* surface = wl_resource_get_user_data(r);
    if (!surface) return;
    if (surface->alpha_resource == r) surface->alpha_resource = NULL;
    surface->pending_alpha = 1.0;
    surface->pending_alpha_set = 1;
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_get_surface(struct wl_client* client,
                                struct wl_resource* resource, uint32_t id,
                                struct wl_resource* wl_surface) {
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (surface && surface->alpha_resource) {
        wl_resource_post_error(resource,
            WP_ALPHA_MODIFIER_V1_ERROR_ALREADY_CONSTRUCTED,
            "wl_surface already has an alpha modifier");
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &wp_alpha_modifier_surface_v1_interface,
        wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &alpha_surface_impl, surface,
                                   alpha_surface_resource_destroyed);
    if (surface) surface->alpha_resource = r;
}

static const struct wp_alpha_modifier_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .get_surface = manager_get_surface,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &wp_alpha_modifier_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_alpha_modifier_init(struct WaylandServer* server) {
    server->alpha_modifier_global = wl_global_create(server->display,
        &wp_alpha_modifier_v1_interface, 1, server, manager_bind);
}

void wayland_alpha_modifier_commit(struct WaylandServer* server,
                                   struct WaylandSurface* surface) {
    if (!surface->pending_alpha_set) return;
    surface->pending_alpha_set = 0;
    double a = surface->pending_alpha;
    if (a < 0.0) a = 0.0;
    if (a > 1.0) a = 1.0;
    if (a == surface->alpha) return;
    surface->alpha = a;
    if (server->cb.on_surface_alpha)
        server->cb.on_surface_alpha(server->cb_ctx, surface->id, a);
}
