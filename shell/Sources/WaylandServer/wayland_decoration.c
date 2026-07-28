// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_decoration.c — zxdg_decoration_manager_v1 and
 *                         zxdg_toplevel_decoration_v1 implementation
 *
 * Tells clients that the compositor provides server-side decorations (SSD).
 * All decoration mode requests are overridden to SERVER_SIDE.
 */

#include "wayland_server_internal.h"
#include "xdg-decoration-unstable-v1-protocol.h"
#include <stdlib.h>

/* ========================================================================== */
/* zxdg_toplevel_decoration_v1                                                */
/* ========================================================================== */

static void toplevel_decoration_destroy(struct wl_client* client,
                                        struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void toplevel_decoration_set_mode(struct wl_client* client,
                                         struct wl_resource* resource,
                                         uint32_t mode) {
    (void)client;
    (void)mode;
    /* Always override to server-side decorations. */
    zxdg_toplevel_decoration_v1_send_configure(resource,
        ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE);
}

static void toplevel_decoration_unset_mode(struct wl_client* client,
                                           struct wl_resource* resource) {
    (void)client;
    /* Compositor picks — always server-side. */
    zxdg_toplevel_decoration_v1_send_configure(resource,
        ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE);
}

/*
 * zxdg_toplevel_decoration_v1 requests (in protocol order):
 *   0  destroy
 *   1  set_mode
 *   2  unset_mode
 */
static const struct zxdg_toplevel_decoration_v1_interface toplevel_decoration_impl = {
    .destroy    = toplevel_decoration_destroy,
    .set_mode   = toplevel_decoration_set_mode,
    .unset_mode = toplevel_decoration_unset_mode,
};

/* ========================================================================== */
/* zxdg_decoration_manager_v1                                                 */
/* ========================================================================== */

static void decoration_manager_destroy(struct wl_client* client,
                                       struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void decoration_manager_get_toplevel_decoration(
    struct wl_client* client,
    struct wl_resource* resource,
    uint32_t id,
    struct wl_resource* toplevel) {
    (void)toplevel;  /* deliberately NOT stored: no handler needs it, and a
                        stored copy would dangle once the client destroys the
                        xdg_toplevel while keeping the decoration */

    struct wl_resource* decoration = wl_resource_create(client,
        &zxdg_toplevel_decoration_v1_interface,
        wl_resource_get_version(resource), id);
    if (!decoration) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(decoration, &toplevel_decoration_impl,
                                   NULL, NULL);

    /* Immediately tell client: server-side decorations. */
    zxdg_toplevel_decoration_v1_send_configure(decoration,
        ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE);
}

/*
 * zxdg_decoration_manager_v1 requests (in protocol order):
 *   0  destroy
 *   1  get_toplevel_decoration
 */
static const struct zxdg_decoration_manager_v1_interface decoration_manager_impl = {
    .destroy                  = decoration_manager_destroy,
    .get_toplevel_decoration  = decoration_manager_get_toplevel_decoration,
};

static void decoration_manager_bind(struct wl_client* client, void* data,
                                    uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zxdg_decoration_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &decoration_manager_impl,
                                   data, NULL);
}

void wayland_decoration_init(struct WaylandServer* server) {
    server->decoration_manager_global = wl_global_create(server->display,
        &zxdg_decoration_manager_v1_interface, 1, server,
        decoration_manager_bind);
}
