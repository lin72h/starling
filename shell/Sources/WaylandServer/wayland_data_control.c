// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_data_control.c — zwlr_data_control_unstable_v1
 *
 * The focus-FREE clipboard protocol. Unlike wl_data_device (whose
 * set_selection requires a serial from an input event, so only a focused
 * client can copy), data-control lets a client set and read the selection
 * with no keyboard focus. That is exactly what clipboard managers — and the
 * Waydroid clipboard bridge (clipboard_manager.py → pyclip → wl-copy/paste)
 * — need: a background process syncing the clipboard.
 *
 * The selection is the SAME server->clipboard shared with wl_data_device
 * (wayland_data_device.c), so a copy from an Android app via wl-copy is
 * pasteable in Chrome and vice-versa. This file only implements the
 * data-control half: broadcasting the shared selection to bound control
 * clients, minting control offers, and routing a control source's data.
 *
 * Advertised at version 2; set_primary_selection is accepted but not wired
 * to the primary selection (a no-op) — the separate zwp_primary_selection
 * protocol already serves native primary selection.
 */

#include "wayland_server_internal.h"
#include "wlr-data-control-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_MIME_TYPES 32

struct WaylandDataControlSource {
    struct wl_resource* resource;
    struct WaylandServer* server;
    char* mime_types[MAX_MIME_TYPES];
    int mime_count;
    int used;                          /* set once used in set_selection */
};

struct WaylandDataControlOffer {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint64_t serial;                   /* clipboard serial this offer serves */
};

struct WaylandDataControlDevice {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct wl_list link;               /* in server->data_control_devices */
};

/* Forward decls (offer impl referenced by the broadcaster above it). */
static const struct zwlr_data_control_offer_v1_interface dc_offer_impl;
static void dc_offer_resource_destroy(struct wl_resource* resource);

/* ------------------------------------------------------------------ */
/* Source: serve data / notify-lost callbacks for the unified clipboard */
/* ------------------------------------------------------------------ */

static void dc_source_send(void* owner, const char* mime, int32_t fd) {
    struct WaylandDataControlSource* s = owner;
    if (s && s->resource)
        zwlr_data_control_source_v1_send_send(s->resource, mime, fd);
}
static void dc_source_cancel(void* owner) {
    struct WaylandDataControlSource* s = owner;
    if (s && s->resource)
        zwlr_data_control_source_v1_send_cancelled(s->resource);
}

/* ------------------------------------------------------------------ */
/* Broadcast the shared selection to control devices                   */
/* ------------------------------------------------------------------ */

static void dc_send_selection_to_device(struct WaylandServer* server,
                                        struct wl_resource* device) {
    if (!server->clipboard.owner) {
        zwlr_data_control_device_v1_send_selection(device, NULL);
        return;
    }
    struct WaylandDataControlOffer* offer = calloc(1, sizeof(*offer));
    if (!offer) return;
    struct wl_resource* offer_res = wl_resource_create(
        wl_resource_get_client(device),
        &zwlr_data_control_offer_v1_interface,
        wl_resource_get_version(device), 0);
    if (!offer_res) { free(offer); return; }
    offer->resource = offer_res;
    offer->server = server;
    offer->serial = server->clipboard.serial;
    wl_resource_set_implementation(offer_res, &dc_offer_impl, offer,
                                   dc_offer_resource_destroy);
    /* data_offer (creates client-side), MIME types, then selection handoff. */
    zwlr_data_control_device_v1_send_data_offer(device, offer_res);
    for (int i = 0; i < server->clipboard.mime_count; i++)
        zwlr_data_control_offer_v1_send_offer(offer_res,
                                              server->clipboard.mimes[i]);
    zwlr_data_control_device_v1_send_selection(device, offer_res);
}

void wayland_data_control_broadcast_selection(struct WaylandServer* server) {
    struct WaylandDataControlDevice* dcd;
    wl_list_for_each(dcd, &server->data_control_devices, link)
        dc_send_selection_to_device(server, dcd->resource);
}

/* ------------------------------------------------------------------ */
/* zwlr_data_control_offer                                             */
/* ------------------------------------------------------------------ */

static void dc_offer_receive(struct wl_client* client,
                             struct wl_resource* resource,
                             const char* mime_type, int32_t fd) {
    (void)client;
    struct WaylandDataControlOffer* offer = wl_resource_get_user_data(resource);
    struct WaylandServer* server = offer ? offer->server : NULL;
    if (!server || !server->clipboard.owner || !server->clipboard.send ||
        server->clipboard.serial != offer->serial) {
        close(fd);
        return;
    }
    server->clipboard.send(server->clipboard.owner, mime_type, fd);
    close(fd);
}

static void dc_offer_destroy(struct wl_client* client,
                             struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwlr_data_control_offer_v1_interface dc_offer_impl = {
    .receive = dc_offer_receive,
    .destroy = dc_offer_destroy,
};

static void dc_offer_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataControlOffer* offer = wl_resource_get_user_data(resource);
    free(offer);
}

/* ------------------------------------------------------------------ */
/* zwlr_data_control_source                                           */
/* ------------------------------------------------------------------ */

static void dc_source_offer(struct wl_client* client,
                            struct wl_resource* resource,
                            const char* mime_type) {
    (void)client;
    struct WaylandDataControlSource* s = wl_resource_get_user_data(resource);
    if (!s || s->mime_count >= MAX_MIME_TYPES) return;
    s->mime_types[s->mime_count++] = strdup(mime_type);
}

static void dc_source_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwlr_data_control_source_v1_interface dc_source_impl = {
    .offer = dc_source_offer,
    .destroy = dc_source_destroy,
};

static void dc_source_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataControlSource* s = wl_resource_get_user_data(resource);
    if (!s) return;
    /* If this source still owns the selection, clear it (broadcast NULL).
     * Don't cancel() the dying source — its resource is already gone. */
    if (s->server && s->server->clipboard.owner == s) {
        s->server->clipboard.owner = NULL;
        s->server->clipboard.mimes = NULL;
        s->server->clipboard.mime_count = 0;
        s->server->clipboard.send = NULL;
        s->server->clipboard.cancel = NULL;
        s->server->clipboard.serial++;
        wayland_data_device_broadcast_selection(s->server);
        wayland_data_control_broadcast_selection(s->server);
    }
    for (int i = 0; i < s->mime_count; i++) free(s->mime_types[i]);
    free(s);
}

/* ------------------------------------------------------------------ */
/* zwlr_data_control_device                                           */
/* ------------------------------------------------------------------ */

static void dc_device_set_selection(struct wl_client* client,
                                    struct wl_resource* resource,
                                    struct wl_resource* source_resource) {
    (void)client;
    struct WaylandDataControlDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    struct WaylandServer* server = dev->server;

    if (source_resource) {
        struct WaylandDataControlSource* s =
            wl_resource_get_user_data(source_resource);
        if (!s) return;
        s->used = 1;
        wayland_clipboard_set(server, s, s->mime_types, s->mime_count,
                              dc_source_send, dc_source_cancel);
    } else {
        wayland_clipboard_set(server, NULL, NULL, 0, NULL, NULL);
    }
}

static void dc_device_set_primary_selection(struct wl_client* client,
                                            struct wl_resource* resource,
                                            struct wl_resource* source_resource) {
    (void)client; (void)resource; (void)source_resource;
    /* Primary selection via data-control not wired (zwp_primary_selection
     * serves native primary). No-op keeps v2 clients happy. */
}

static void dc_device_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwlr_data_control_device_v1_interface dc_device_impl = {
    .set_selection = dc_device_set_selection,
    .destroy = dc_device_destroy,
    .set_primary_selection = dc_device_set_primary_selection,
};

static void dc_device_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataControlDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    wl_list_remove(&dev->link);
    free(dev);
}

/* ------------------------------------------------------------------ */
/* zwlr_data_control_manager                                          */
/* ------------------------------------------------------------------ */

static void dc_manager_create_data_source(struct wl_client* client,
                                          struct wl_resource* resource,
                                          uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandDataControlSource* s = calloc(1, sizeof(*s));
    if (!s) { wl_client_post_no_memory(client); return; }
    struct wl_resource* res = wl_resource_create(client,
        &zwlr_data_control_source_v1_interface,
        wl_resource_get_version(resource), id);
    if (!res) { free(s); wl_client_post_no_memory(client); return; }
    s->resource = res;
    s->server = server;
    wl_resource_set_implementation(res, &dc_source_impl, s,
                                   dc_source_resource_destroy);
}

static void dc_manager_get_data_device(struct wl_client* client,
                                       struct wl_resource* resource,
                                       uint32_t id,
                                       struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct wl_resource* device = wl_resource_create(client,
        &zwlr_data_control_device_v1_interface,
        wl_resource_get_version(resource), id);
    if (!device) { wl_client_post_no_memory(client); return; }
    struct WaylandDataControlDevice* dev = calloc(1, sizeof(*dev));
    if (!dev) {
        wl_resource_destroy(device);
        wl_client_post_no_memory(client);
        return;
    }
    dev->resource = device;
    dev->server = server;
    wl_list_insert(&server->data_control_devices, &dev->link);
    wl_resource_set_implementation(device, &dc_device_impl, dev,
                                   dc_device_resource_destroy);
    /* Per spec: immediately advertise the current selection so a client that
     * binds AFTER a copy (e.g. wl-paste spawned on demand by the Waydroid
     * bridge) learns it — this is the focus-free equivalent of the
     * send-on-keyboard-focus that wl_data_device relies on. */
    dc_send_selection_to_device(server, device);
}

static void dc_manager_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwlr_data_control_manager_v1_interface dc_manager_impl = {
    .create_data_source = dc_manager_create_data_source,
    .get_data_device = dc_manager_get_data_device,
    .destroy = dc_manager_destroy,
};

static void dc_manager_bind(struct wl_client* client, void* data,
                            uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwlr_data_control_manager_v1_interface, version, id);
    if (!resource) { wl_client_post_no_memory(client); return; }
    wl_resource_set_implementation(resource, &dc_manager_impl, data, NULL);
}

void wayland_data_control_init(struct WaylandServer* server) {
    wl_list_init(&server->data_control_devices);
    server->data_control_manager_global = wl_global_create(
        server->display, &zwlr_data_control_manager_v1_interface, 2,
        server, dc_manager_bind);
}
