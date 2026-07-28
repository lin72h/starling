// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_primary_selection.c — zwp_primary_selection_v1 implementation
 *
 * X11-style primary selection (middle-click paste). GTK/Qt apps expect this.
 * We accept source/device creation and selection-set requests but don't
 * implement cross-client clipboard transfer — just enough for clients
 * to not complain about the missing protocol.
 */

#include "wayland_server_internal.h"
#include "primary-selection-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* ========================================================================== */
/* zwp_primary_selection_source_v1                                            */
/* ========================================================================== */

static void source_offer(struct wl_client* client,
                         struct wl_resource* resource,
                         const char* mime_type) {
    (void)client; (void)resource; (void)mime_type;
    /* Accept mime type advertisement. */
}

static void source_destroy(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_source_v1_interface source_impl = {
    .offer = source_offer,
    .destroy = source_destroy,
};

/* ========================================================================== */
/* zwp_primary_selection_offer_v1                                             */
/* ========================================================================== */

static void offer_receive(struct wl_client* client,
                          struct wl_resource* resource,
                          const char* mime_type,
                          int32_t fd) {
    (void)client; (void)resource; (void)mime_type;
    /* No data to transfer — just close the fd. */
    close(fd);
}

static void offer_destroy(struct wl_client* client,
                          struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_offer_v1_interface offer_impl = {
    .receive = offer_receive,
    .destroy = offer_destroy,
};

/* ========================================================================== */
/* zwp_primary_selection_device_v1                                            */
/* ========================================================================== */

static void device_set_selection(struct wl_client* client,
                                 struct wl_resource* resource,
                                 struct wl_resource* source,
                                 uint32_t serial) {
    (void)client; (void)resource; (void)source; (void)serial;
    /* Accept selection set — no cross-client forwarding. */
}

static void device_destroy(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_device_v1_interface device_impl = {
    .set_selection = device_set_selection,
    .destroy = device_destroy,
};

/* ========================================================================== */
/* zwp_primary_selection_device_manager_v1 (global)                           */
/* ========================================================================== */

static void manager_create_source(struct wl_client* client,
                                  struct wl_resource* resource,
                                  uint32_t id) {
    struct wl_resource* src = wl_resource_create(client,
        &zwp_primary_selection_source_v1_interface, 1, id);
    if (!src) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(src, &source_impl,
        wl_resource_get_user_data(resource), NULL);
}

static void manager_get_device(struct wl_client* client,
                               struct wl_resource* resource,
                               uint32_t id,
                               struct wl_resource* seat) {
    (void)seat;
    struct wl_resource* dev = wl_resource_create(client,
        &zwp_primary_selection_device_v1_interface, 1, id);
    if (!dev) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(dev, &device_impl,
        wl_resource_get_user_data(resource), NULL);

    /* Do NOT send a selection event here. get_device runs during the
     * client's init roundtrip (Qt's QWaylandDisplay::initialize), before
     * QGuiApplication has constructed its clipboard — and Qt6's selection
     * handler unconditionally calls clipboard()->emitChanged(), which
     * segfaults on the still-null clipboard. Real compositors send the
     * selection event on keyboard-focus-enter (after init completes), not
     * at device creation; the client correctly defaults to no selection
     * until then. Sending selection(NULL) here crashed every Qt6 Wayland
     * app (Telegram, native Zoom). */
}

static void manager_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_device_manager_v1_interface manager_impl = {
    .create_source = manager_create_source,
    .get_device = manager_get_device,
    .destroy = manager_destroy,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_primary_selection_device_manager_v1_interface, version, id);
    wl_resource_set_implementation(resource, &manager_impl, data, NULL);
}

void wayland_primary_selection_init(struct WaylandServer* server) {
    server->primary_selection_manager_global = wl_global_create(server->display,
        &zwp_primary_selection_device_manager_v1_interface, 1, server, manager_bind);
}
