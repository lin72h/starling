// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_cursor_shape.c — wp_cursor_shape_v1 implementation
 *
 * Lets clients request cursor shapes by enum name instead of providing
 * a wl_surface with cursor bitmap. Chrome/GTK use this for standard
 * cursors (pointer, text, resize handles, etc.).
 *
 * We forward shape changes to the compositor via the on_cursor_shape callback.
 */

#include "wayland_server_internal.h"
#include "cursor-shape-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* Stub for zwp_tablet_tool_v2_interface — referenced by the generated
 * cursor-shape protocol code (get_tablet_tool_v2 argument type).
 * We don't implement the tablet-v2 protocol, but need the symbol to link. */
struct wl_interface zwp_tablet_tool_v2_interface = {
    "zwp_tablet_tool_v2", 1, 0, NULL, 0, NULL,
};

/* ========================================================================== */
/* wp_cursor_shape_device_v1 (per-pointer shape setter)                       */
/* ========================================================================== */

static void cursor_shape_device_destroy(struct wl_client* client,
                                        struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void cursor_shape_device_set_shape(struct wl_client* client,
                                          struct wl_resource* resource,
                                          uint32_t serial,
                                          uint32_t shape) {
    (void)client;
    (void)serial;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    if (!wp_cursor_shape_device_v1_shape_is_valid(shape, 2)) {
        wl_resource_post_error(resource,
            WP_CURSOR_SHAPE_DEVICE_V1_ERROR_INVALID_SHAPE,
            "invalid cursor shape %u", shape);
        return;
    }

    /* Forward to the compositor so it can switch the hardware cursor. */
    if (server && server->cb.on_cursor_shape) {
        server->cb.on_cursor_shape(server->cb_ctx, shape);
    }
}

static const struct wp_cursor_shape_device_v1_interface cursor_shape_device_impl = {
    .destroy = cursor_shape_device_destroy,
    .set_shape = cursor_shape_device_set_shape,
};

/* ========================================================================== */
/* wp_cursor_shape_manager_v1 (global)                                        */
/* ========================================================================== */

static void cursor_shape_manager_destroy(struct wl_client* client,
                                         struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void cursor_shape_manager_get_pointer(struct wl_client* client,
                                             struct wl_resource* resource,
                                             uint32_t id,
                                             struct wl_resource* pointer) {
    (void)pointer;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* device = wl_resource_create(client,
        &wp_cursor_shape_device_v1_interface,
        wl_resource_get_version(resource), id);
    if (!device) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(device, &cursor_shape_device_impl, server, NULL);
}

static void cursor_shape_manager_get_tablet_tool(struct wl_client* client,
                                                 struct wl_resource* resource,
                                                 uint32_t id,
                                                 struct wl_resource* tablet_tool) {
    (void)tablet_tool;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    /* We don't implement zwp_tablet_tool_v2, but create the resource
     * so it doesn't leak if a client somehow calls this. */
    struct wl_resource* device = wl_resource_create(client,
        &wp_cursor_shape_device_v1_interface,
        wl_resource_get_version(resource), id);
    if (!device) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(device, &cursor_shape_device_impl, server, NULL);
}

static const struct wp_cursor_shape_manager_v1_interface cursor_shape_manager_impl = {
    .destroy = cursor_shape_manager_destroy,
    .get_pointer = cursor_shape_manager_get_pointer,
    .get_tablet_tool_v2 = cursor_shape_manager_get_tablet_tool,
};

static void cursor_shape_manager_bind(struct wl_client* client, void* data,
                                      uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wp_cursor_shape_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &cursor_shape_manager_impl, data, NULL);
}

void wayland_cursor_shape_init(struct WaylandServer* server) {
    server->cursor_shape_manager_global = wl_global_create(server->display,
        &wp_cursor_shape_manager_v1_interface, 1, server, cursor_shape_manager_bind);
}
