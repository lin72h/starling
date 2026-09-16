// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_color_representation.c — wp_color_representation_manager_v1
 *
 * Per-surface pixel-encoding metadata: whether the buffer's alpha is
 * premultiplied, and for YUV buffers which matrix and range decode them.
 * Everything this compositor imports is RGB with premultiplied alpha, so
 * that is the one alpha mode and the one coefficient set advertised; a
 * client asking for anything else is told with the protocol's own error,
 * as the spec directs, instead of getting silently misrendered pixels.
 */

#include "wayland_server_internal.h"
#include "color-representation-v1-protocol.h"
#include <stdlib.h>

static void destroy_request(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void surface_set_alpha_mode(struct wl_client* c, struct wl_resource* r, uint32_t mode) {
    (void)c;
    if (mode != WP_COLOR_REPRESENTATION_SURFACE_V1_ALPHA_MODE_PREMULTIPLIED_ELECTRICAL) {
        wl_resource_post_error(r, WP_COLOR_REPRESENTATION_SURFACE_V1_ERROR_ALPHA_MODE,
                               "unsupported alpha mode %u", mode);
    }
}

static void surface_set_coefficients(struct wl_client* c, struct wl_resource* r,
                                     uint32_t coefficients, uint32_t range) {
    (void)c;
    if (coefficients != WP_COLOR_REPRESENTATION_SURFACE_V1_COEFFICIENTS_IDENTITY ||
        range != WP_COLOR_REPRESENTATION_SURFACE_V1_RANGE_FULL) {
        wl_resource_post_error(r, WP_COLOR_REPRESENTATION_SURFACE_V1_ERROR_COEFFICIENTS,
                               "unsupported coefficients %u / range %u", coefficients, range);
    }
}

static void surface_set_chroma_location(struct wl_client* c, struct wl_resource* r,
                                        uint32_t location) {
    (void)c; (void)r; (void)location;
    /* Meaningful for subsampled YUV only; RGB has no chroma to locate. */
}

static const struct wp_color_representation_surface_v1_interface surface_impl = {
    .destroy = destroy_request,
    .set_alpha_mode = surface_set_alpha_mode,
    .set_coefficients_and_range = surface_set_coefficients,
    .set_chroma_location = surface_set_chroma_location,
};

static void manager_get_surface(struct wl_client* client, struct wl_resource* resource,
                                uint32_t id, struct wl_resource* surface) {
    (void)surface;
    struct wl_resource* r = wl_resource_create(client,
        &wp_color_representation_surface_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &surface_impl, NULL, NULL);
}

static const struct wp_color_representation_manager_v1_interface manager_impl = {
    .destroy = destroy_request,
    .get_surface = manager_get_surface,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &wp_color_representation_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
    wp_color_representation_manager_v1_send_supported_alpha_mode(r,
        WP_COLOR_REPRESENTATION_SURFACE_V1_ALPHA_MODE_PREMULTIPLIED_ELECTRICAL);
    wp_color_representation_manager_v1_send_supported_coefficients_and_ranges(r,
        WP_COLOR_REPRESENTATION_SURFACE_V1_COEFFICIENTS_IDENTITY,
        WP_COLOR_REPRESENTATION_SURFACE_V1_RANGE_FULL);
    wp_color_representation_manager_v1_send_done(r);
}

void wayland_color_representation_init(struct WaylandServer* server) {
    server->color_representation_global = wl_global_create(server->display,
        &wp_color_representation_manager_v1_interface, 1, server, manager_bind);
}
