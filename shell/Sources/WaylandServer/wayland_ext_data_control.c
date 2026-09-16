// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_ext_data_control.c — ext_data_control_v1
 *
 * wayland-protocols' standardisation of wlr-data-control: the same focus-free
 * clipboard protocol (a clipboard manager copies and reads the selection
 * with no keyboard focus) with an `ext_` prefix, so newer wl-clipboard,
 * cliphist and the like find it on a compositor that no longer offers the
 * wlroots one. Same requests, same events, same shared server->clipboard —
 * this file is the wlr module with the names changed, regenerate it from
 * there rather than editing the two apart. The one difference: the wlr
 * module's dying-source path also broadcasts to THIS module's devices, and
 * this one's to the wlr module's, so a clipboard set through either
 * protocol is seen by both.
 */

#include "wayland_server_internal.h"
#include "ext-data-control-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_MIME_TYPES 32

struct WaylandExtDataControlSource {
    struct wl_resource* resource;
    struct WaylandServer* server;
    char* mime_types[MAX_MIME_TYPES];
    int mime_count;
    int used;                          /* set once used in set_selection */
};

struct WaylandExtDataControlOffer {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint64_t serial;                   /* the serial of the selection it serves */
    int primary;                       /* serves server->primary, not the clipboard */
};

struct WaylandExtDataControlDevice {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct wl_list link;               /* in server->ext_data_control_devices */
};

/* Forward decls (offer impl referenced by the broadcaster above it). */
static const struct ext_data_control_offer_v1_interface edc_offer_impl;
static void edc_offer_resource_destroy(struct wl_resource* resource);

/* ------------------------------------------------------------------ */
/* Source: serve data / notify-lost callbacks for the unified clipboard */
/* ------------------------------------------------------------------ */

static void edc_source_send(void* owner, const char* mime, int32_t fd) {
    struct WaylandExtDataControlSource* s = owner;
    if (s && s->resource)
        ext_data_control_source_v1_send_send(s->resource, mime, fd);
}
static void edc_source_cancel(void* owner) {
    struct WaylandExtDataControlSource* s = owner;
    if (s && s->resource)
        ext_data_control_source_v1_send_cancelled(s->resource);
}

/* ------------------------------------------------------------------ */
/* Broadcast the shared selection to control devices                   */
/* ------------------------------------------------------------------ */

static void edc_send_selection_to_device(struct WaylandServer* server,
                                        struct wl_resource* device) {
    if (!server->clipboard.owner) {
        ext_data_control_device_v1_send_selection(device, NULL);
        return;
    }
    struct WaylandExtDataControlOffer* offer = calloc(1, sizeof(*offer));
    if (!offer) return;
    struct wl_resource* offer_res = wl_resource_create(
        wl_resource_get_client(device),
        &ext_data_control_offer_v1_interface,
        wl_resource_get_version(device), 0);
    if (!offer_res) { free(offer); return; }
    offer->resource = offer_res;
    offer->server = server;
    offer->serial = server->clipboard.serial;
    wl_resource_set_implementation(offer_res, &edc_offer_impl, offer,
                                   edc_offer_resource_destroy);
    /* data_offer (creates client-side), MIME types, then selection handoff. */
    ext_data_control_device_v1_send_data_offer(device, offer_res);
    for (int i = 0; i < server->clipboard.mime_count; i++)
        ext_data_control_offer_v1_send_offer(offer_res,
                                              server->clipboard.mimes[i]);
    ext_data_control_device_v1_send_selection(device, offer_res);
}

/* The primary selection: the same, from server->primary. */
static void edc_send_primary_to_device(struct WaylandServer* server,
                                       struct wl_resource* device) {
    if (!server->primary.owner) {
        ext_data_control_device_v1_send_primary_selection(device, NULL);
        return;
    }
    struct WaylandExtDataControlOffer* offer = calloc(1, sizeof(*offer));
    if (!offer) return;
    struct wl_resource* offer_res = wl_resource_create(
        wl_resource_get_client(device),
        &ext_data_control_offer_v1_interface,
        wl_resource_get_version(device), 0);
    if (!offer_res) { free(offer); return; }
    offer->resource = offer_res;
    offer->server = server;
    offer->serial = server->primary.serial;
    offer->primary = 1;
    wl_resource_set_implementation(offer_res, &edc_offer_impl, offer,
                                   edc_offer_resource_destroy);
    ext_data_control_device_v1_send_data_offer(device, offer_res);
    for (int i = 0; i < server->primary.mime_count; i++)
        ext_data_control_offer_v1_send_offer(offer_res, server->primary.mimes[i]);
    ext_data_control_device_v1_send_primary_selection(device, offer_res);
}

void wayland_ext_data_control_broadcast_primary(struct WaylandServer* server) {
    struct WaylandExtDataControlDevice* dcd;
    wl_list_for_each(dcd, &server->ext_data_control_devices, link)
        edc_send_primary_to_device(server, dcd->resource);
}

void wayland_ext_data_control_broadcast_selection(struct WaylandServer* server) {
    struct WaylandExtDataControlDevice* dcd;
    wl_list_for_each(dcd, &server->ext_data_control_devices, link)
        edc_send_selection_to_device(server, dcd->resource);
}

/* ------------------------------------------------------------------ */
/* ext_data_control_offer                                             */
/* ------------------------------------------------------------------ */

static void edc_offer_receive(struct wl_client* client,
                             struct wl_resource* resource,
                             const char* mime_type, int32_t fd) {
    (void)client;
    struct WaylandExtDataControlOffer* offer = wl_resource_get_user_data(resource);
    struct WaylandServer* server = offer ? offer->server : NULL;
    struct WaylandClipboard* sel = NULL;
    if (server) sel = offer->primary ? &server->primary : &server->clipboard;
    if (!sel || !sel->owner || !sel->send || sel->serial != offer->serial) {
        close(fd);
        return;
    }
    sel->send(sel->owner, mime_type, fd);
    close(fd);
}

static void edc_offer_destroy(struct wl_client* client,
                             struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct ext_data_control_offer_v1_interface edc_offer_impl = {
    .receive = edc_offer_receive,
    .destroy = edc_offer_destroy,
};

static void edc_offer_resource_destroy(struct wl_resource* resource) {
    struct WaylandExtDataControlOffer* offer = wl_resource_get_user_data(resource);
    free(offer);
}

/* ------------------------------------------------------------------ */
/* ext_data_control_source                                           */
/* ------------------------------------------------------------------ */

static void edc_source_offer(struct wl_client* client,
                            struct wl_resource* resource,
                            const char* mime_type) {
    (void)client;
    struct WaylandExtDataControlSource* s = wl_resource_get_user_data(resource);
    if (!s || s->mime_count >= MAX_MIME_TYPES) return;
    s->mime_types[s->mime_count++] = strdup(mime_type);
}

static void edc_source_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct ext_data_control_source_v1_interface edc_source_impl = {
    .offer = edc_source_offer,
    .destroy = edc_source_destroy,
};

static void edc_source_resource_destroy(struct wl_resource* resource) {
    struct WaylandExtDataControlSource* s = wl_resource_get_user_data(resource);
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
        wayland_ext_data_control_broadcast_selection(s->server);
    }
    if (s->server) wayland_primary_clear_if_owner(s->server, s);
    for (int i = 0; i < s->mime_count; i++) free(s->mime_types[i]);
    free(s);
}

/* ------------------------------------------------------------------ */
/* ext_data_control_device                                           */
/* ------------------------------------------------------------------ */

static void edc_device_set_selection(struct wl_client* client,
                                    struct wl_resource* resource,
                                    struct wl_resource* source_resource) {
    (void)client;
    struct WaylandExtDataControlDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    struct WaylandServer* server = dev->server;

    if (source_resource) {
        struct WaylandExtDataControlSource* s =
            wl_resource_get_user_data(source_resource);
        if (!s) return;
        s->used = 1;
        wayland_clipboard_set(server, s, s->mime_types, s->mime_count,
                              edc_source_send, edc_source_cancel);
    } else {
        wayland_clipboard_set(server, NULL, NULL, 0, NULL, NULL);
    }
}

static void edc_device_set_primary_selection(struct wl_client* client,
                                             struct wl_resource* resource,
                                             struct wl_resource* source_resource) {
    (void)client;
    struct WaylandExtDataControlDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    if (source_resource) {
        struct WaylandExtDataControlSource* s = wl_resource_get_user_data(source_resource);
        if (!s) return;
        s->used = 1;
        wayland_primary_set(dev->server, s, s->mime_types, s->mime_count,
                            edc_source_send, edc_source_cancel);
    } else {
        wayland_primary_set(dev->server, NULL, NULL, 0, NULL, NULL);
    }
}

static void edc_device_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct ext_data_control_device_v1_interface edc_device_impl = {
    .set_selection = edc_device_set_selection,
    .destroy = edc_device_destroy,
    .set_primary_selection = edc_device_set_primary_selection,
};

static void edc_device_resource_destroy(struct wl_resource* resource) {
    struct WaylandExtDataControlDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    wl_list_remove(&dev->link);
    free(dev);
}

/* ------------------------------------------------------------------ */
/* ext_data_control_manager                                          */
/* ------------------------------------------------------------------ */

static void edc_manager_create_data_source(struct wl_client* client,
                                          struct wl_resource* resource,
                                          uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandExtDataControlSource* s = calloc(1, sizeof(*s));
    if (!s) { wl_client_post_no_memory(client); return; }
    struct wl_resource* res = wl_resource_create(client,
        &ext_data_control_source_v1_interface,
        wl_resource_get_version(resource), id);
    if (!res) { free(s); wl_client_post_no_memory(client); return; }
    s->resource = res;
    s->server = server;
    wl_resource_set_implementation(res, &edc_source_impl, s,
                                   edc_source_resource_destroy);
}

static void edc_manager_get_data_device(struct wl_client* client,
                                       struct wl_resource* resource,
                                       uint32_t id,
                                       struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct wl_resource* device = wl_resource_create(client,
        &ext_data_control_device_v1_interface,
        wl_resource_get_version(resource), id);
    if (!device) { wl_client_post_no_memory(client); return; }
    struct WaylandExtDataControlDevice* dev = calloc(1, sizeof(*dev));
    if (!dev) {
        wl_resource_destroy(device);
        wl_client_post_no_memory(client);
        return;
    }
    dev->resource = device;
    dev->server = server;
    wl_list_insert(&server->ext_data_control_devices, &dev->link);
    wl_resource_set_implementation(device, &edc_device_impl, dev,
                                   edc_device_resource_destroy);
    /* Per spec: immediately advertise the current selection so a client that
     * binds AFTER a copy (e.g. wl-paste spawned on demand by the Waydroid
     * bridge) learns it — this is the focus-free equivalent of the
     * send-on-keyboard-focus that wl_data_device relies on. */
    edc_send_selection_to_device(server, device);
    edc_send_primary_to_device(server, device);
}

static void edc_manager_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct ext_data_control_manager_v1_interface edc_manager_impl = {
    .create_data_source = edc_manager_create_data_source,
    .get_data_device = edc_manager_get_data_device,
    .destroy = edc_manager_destroy,
};

static void edc_manager_bind(struct wl_client* client, void* data,
                            uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &ext_data_control_manager_v1_interface, version, id);
    if (!resource) { wl_client_post_no_memory(client); return; }
    wl_resource_set_implementation(resource, &edc_manager_impl, data, NULL);
}

void wayland_ext_data_control_init(struct WaylandServer* server) {
    wl_list_init(&server->ext_data_control_devices);
    server->ext_data_control_manager_global = wl_global_create(
        server->display, &ext_data_control_manager_v1_interface, 1,
        server, edc_manager_bind);
}
