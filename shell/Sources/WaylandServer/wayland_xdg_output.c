// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_xdg_output.c — zxdg_output_v1 implementation
 *
 * Extended output info (logical size, position, name). Chrome queries this
 * to determine display geometry in logical coordinates. We report the
 * display dimensions divided by the scale factor.
 */

#include "wayland_server_internal.h"
#include "xdg-output-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* ========================================================================== */
/* zxdg_output_v1 (per-output extended info)                                  */
/* ========================================================================== */

static void xdg_output_destroy(struct wl_client* client,
                                struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zxdg_output_v1_interface xdg_output_impl = {
    .destroy = xdg_output_destroy,
};

/* ========================================================================== */
/* zxdg_output_manager_v1 (global)                                            */
/* ========================================================================== */

static void xdg_output_manager_destroy(struct wl_client* client,
                                       struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void xdg_output_manager_get_xdg_output(struct wl_client* client,
                                               struct wl_resource* resource,
                                               uint32_t id,
                                               struct wl_resource* output) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    uint32_t version = wl_resource_get_version(resource);

    /* Each wl_output resource's user data is its WaylandOutput. */
    struct WaylandOutput* out =
        output ? wl_resource_get_user_data(output) : NULL;
    if (!out) {
        out = &server->outputs[0];
    }

    struct wl_resource* xdg_out = wl_resource_create(client,
        &zxdg_output_v1_interface, version, id);
    if (!xdg_out) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(xdg_out, &xdg_output_impl, server, NULL);

    /* Logical position in the global (virtual desktop) space. */
    zxdg_output_v1_send_logical_position(xdg_out, out->logical_x,
                                         out->logical_y);

    /* Logical size (physical / integer scale). */
    int scale = out->scale > 0 ? out->scale : 1;
    zxdg_output_v1_send_logical_size(xdg_out, out->physical_w / scale,
                                     out->physical_h / scale);

    /* Send name and description (version >= 2). */
    if (version >= 2) {
        zxdg_output_v1_send_name(xdg_out, out->name);
        zxdg_output_v1_send_description(xdg_out, "Starling DRM Output");
    }

    /* Commit the burst. Version 1-2 have their own done event; from version 3
     * the spec replaces it with wl_output.done, which the compositor must send
     * *after* the xdg_output properties — that event is what makes the state
     * atomic, so it has to follow these sends, not merely have happened once at
     * wl_output bind time.
     *
     * Omitting it looks harmless because most clients cope: GTK3 does not use
     * xdg_output at all, and Qt and Chromium take their geometry from
     * wl_output. GTK4 does not — it waits for the xdg_output state to be
     * committed before a monitor counts as complete, so without this the
     * monitor stays half-initialised, every scale query answers 0, and the app
     * dies on `gtk_icon_theme_lookup_icon: assertion 'scale >= 1' failed`
     * before it ever gets a window up. */
    if (version < 3) {
        zxdg_output_v1_send_done(xdg_out);
    } else if (output) {
        wl_output_send_done(output);
    }
}

static const struct zxdg_output_manager_v1_interface xdg_output_manager_impl = {
    .destroy = xdg_output_manager_destroy,
    .get_xdg_output = xdg_output_manager_get_xdg_output,
};

static void xdg_output_manager_bind(struct wl_client* client, void* data,
                                    uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zxdg_output_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &xdg_output_manager_impl, data, NULL);
}

void wayland_xdg_output_init(struct WaylandServer* server) {
    server->xdg_output_manager_global = wl_global_create(server->display,
        &zxdg_output_manager_v1_interface, 3, server, xdg_output_manager_bind);
}
