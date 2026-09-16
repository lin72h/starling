// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0
/*
 * wayland_primary_selection.c — zwp_primary_selection_v1
 *
 * The X11-style primary selection: select text anywhere, middle-click to
 * paste it somewhere else. GTK and Qt set it on every selection change and
 * read it on a middle click; the terminal does both.
 *
 * The same shape as the clipboard in wayland_data_device.c, with an owner
 * of its own (server->primary): set_selection replaces the owner and tells
 * the old one it lost the selection, every bound device is handed a fresh
 * offer, and a client that binds a device LATER gets its offer when its
 * pointer or keyboard enters a surface (wayland_server.c) — never from
 * get_device, which runs inside Qt's init roundtrip before its clipboard
 * exists; a selection event there crashed every Qt6 app. An offer carries
 * the selection's serial, and a receive against a superseded offer reads
 * EOF rather than a source that may be gone.
 */
#include "wayland_server_internal.h"
#include "primary-selection-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PRIMARY_MAX_MIMES 32

struct PrimarySource {
    struct wl_resource* resource;
    struct WaylandServer* server;
    char* mimes[PRIMARY_MAX_MIMES];
    int mime_count;
};

struct PrimaryDevice {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct wl_list link;             // server->primary_device_resources
    uint64_t sent_serial;            // the selection this device last got
};

struct PrimaryOffer {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint64_t serial;                 // the selection it was minted for
};

static const struct zwp_primary_selection_offer_v1_interface offer_impl;
static void offer_resource_destroy(struct wl_resource* r);

/* ========================================================================== */
/* The selection                                                              */
/* ========================================================================== */

static void source_send(void* owner, const char* mime, int32_t fd) {
    struct PrimarySource* s = owner;
    if (s && s->resource) zwp_primary_selection_source_v1_send_send(s->resource, mime, fd);
}

static void source_cancel(void* owner) {
    struct PrimarySource* s = owner;
    if (s && s->resource) zwp_primary_selection_source_v1_send_cancelled(s->resource);
}

/* Mint an offer for the current selection and hand it to one device; an
 * empty selection is selection(NULL). */
static void send_selection_to_device(struct WaylandServer* server, struct PrimaryDevice* dev) {
    dev->sent_serial = server->primary.serial;
    if (!server->primary.owner) {
        zwp_primary_selection_device_v1_send_selection(dev->resource, NULL);
        return;
    }
    struct PrimaryOffer* offer = calloc(1, sizeof(*offer));
    if (!offer) return;
    struct wl_resource* r = wl_resource_create(wl_resource_get_client(dev->resource),
        &zwp_primary_selection_offer_v1_interface, wl_resource_get_version(dev->resource), 0);
    if (!r) { free(offer); return; }
    offer->resource = r;
    offer->server = server;
    offer->serial = server->primary.serial;
    wl_resource_set_implementation(r, &offer_impl, offer, offer_resource_destroy);
    zwp_primary_selection_device_v1_send_data_offer(dev->resource, r);
    for (int i = 0; i < server->primary.mime_count; i++)
        zwp_primary_selection_offer_v1_send_offer(r, server->primary.mimes[i]);
    zwp_primary_selection_device_v1_send_selection(dev->resource, r);
}

static void broadcast(struct WaylandServer* server) {
    struct PrimaryDevice* dev;
    wl_list_for_each(dev, &server->primary_device_resources, link)
        send_selection_to_device(server, dev);
}

static void primary_set(struct WaylandServer* server, struct PrimarySource* owner) {
    if (server->primary.owner && server->primary.owner != owner && server->primary.cancel)
        server->primary.cancel(server->primary.owner);
    server->primary.owner = owner;
    server->primary.mimes = owner ? owner->mimes : NULL;
    server->primary.mime_count = owner ? owner->mime_count : 0;
    server->primary.send = owner ? source_send : NULL;
    server->primary.cancel = owner ? source_cancel : NULL;
    server->primary.serial++;
    broadcast(server);
}

/* The owning source is going: the selection empties, with no cancel to a
 * resource that is already gone. */
static void primary_clear_if_owner(struct WaylandServer* server, void* owner) {
    if (server->primary.owner != owner) return;
    server->primary.owner = NULL;
    server->primary.mimes = NULL;
    server->primary.mime_count = 0;
    server->primary.send = NULL;
    server->primary.cancel = NULL;
    server->primary.serial++;
    broadcast(server);
}

void wayland_primary_selection_offer_on_interaction(struct WaylandServer* server,
                                                    struct WaylandSurface* surface) {
    if (!server || !surface || !surface->resource) return;
    if (!server->primary.owner) return;
    struct wl_client* client = wl_resource_get_client(surface->resource);
    if (!client) return;
    struct PrimaryDevice* dev;
    wl_list_for_each(dev, &server->primary_device_resources, link) {
        if (wl_resource_get_client(dev->resource) == client &&
            dev->sent_serial != server->primary.serial)
            send_selection_to_device(server, dev);
    }
}

/* ========================================================================== */
/* zwp_primary_selection_offer_v1                                             */
/* ========================================================================== */

static void offer_receive(struct wl_client* client, struct wl_resource* resource,
                          const char* mime_type, int32_t fd) {
    (void)client;
    struct PrimaryOffer* offer = wl_resource_get_user_data(resource);
    struct WaylandServer* server = offer ? offer->server : NULL;
    if (server && server->primary.owner && server->primary.send &&
        server->primary.serial == offer->serial) {
        server->primary.send(server->primary.owner, mime_type, fd);
    }
    close(fd);   /* ours; the owner got its own copy over the socket */
}

static void offer_destroy(struct wl_client* client, struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_offer_v1_interface offer_impl = {
    .receive = offer_receive,
    .destroy = offer_destroy,
};

static void offer_resource_destroy(struct wl_resource* r) {
    free(wl_resource_get_user_data(r));
}

/* ========================================================================== */
/* zwp_primary_selection_source_v1                                            */
/* ========================================================================== */

static void source_offer(struct wl_client* client, struct wl_resource* resource,
                         const char* mime_type) {
    (void)client;
    struct PrimarySource* s = wl_resource_get_user_data(resource);
    if (!s || s->mime_count >= PRIMARY_MAX_MIMES) return;
    s->mimes[s->mime_count++] = strdup(mime_type);
}

static void source_destroy(struct wl_client* client, struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_source_v1_interface source_impl = {
    .offer = source_offer,
    .destroy = source_destroy,
};

static void source_resource_destroy(struct wl_resource* r) {
    struct PrimarySource* s = wl_resource_get_user_data(r);
    if (!s) return;
    s->resource = NULL;
    primary_clear_if_owner(s->server, s);
    for (int i = 0; i < s->mime_count; i++) free(s->mimes[i]);
    free(s);
}

/* ========================================================================== */
/* zwp_primary_selection_device_v1                                            */
/* ========================================================================== */

static void device_set_selection(struct wl_client* client, struct wl_resource* resource,
                                 struct wl_resource* source, uint32_t serial) {
    (void)client; (void)serial;
    struct PrimaryDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    struct PrimarySource* s = source ? wl_resource_get_user_data(source) : NULL;
    primary_set(dev->server, s);
}

static void device_destroy(struct wl_client* client, struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_device_v1_interface device_impl = {
    .set_selection = device_set_selection,
    .destroy = device_destroy,
};

/* Explicit destroy and client disconnect alike: unlink, or the next
 * broadcast walks a freed device. */
static void device_resource_destroy(struct wl_resource* r) {
    struct PrimaryDevice* dev = wl_resource_get_user_data(r);
    if (!dev) return;
    wl_list_remove(&dev->link);
    free(dev);
}

/* ========================================================================== */
/* zwp_primary_selection_device_manager_v1 (global)                           */
/* ========================================================================== */

static void manager_create_source(struct wl_client* client, struct wl_resource* resource,
                                  uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct PrimarySource* s = calloc(1, sizeof(*s));
    if (!s) { wl_client_post_no_memory(client); return; }
    struct wl_resource* r = wl_resource_create(client,
        &zwp_primary_selection_source_v1_interface, 1, id);
    if (!r) { free(s); wl_client_post_no_memory(client); return; }
    s->resource = r;
    s->server = server;
    wl_resource_set_implementation(r, &source_impl, s, source_resource_destroy);
}

static void manager_get_device(struct wl_client* client, struct wl_resource* resource,
                               uint32_t id, struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct wl_resource* r = wl_resource_create(client,
        &zwp_primary_selection_device_v1_interface, 1, id);
    if (!r) { wl_client_post_no_memory(client); return; }
    struct PrimaryDevice* dev = calloc(1, sizeof(*dev));
    if (!dev) { wl_resource_destroy(r); wl_client_post_no_memory(client); return; }
    dev->resource = r;
    dev->server = server;
    wl_list_insert(&server->primary_device_resources, &dev->link);
    wl_resource_set_implementation(r, &device_impl, dev, device_resource_destroy);
    /* No selection event here — see the file comment: get_device runs
     * inside Qt's init roundtrip. The first pointer or keyboard enter
     * delivers it. */
}

static void manager_destroy(struct wl_client* client, struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_primary_selection_device_manager_v1_interface manager_impl = {
    .create_source = manager_create_source,
    .get_device = manager_get_device,
    .destroy = manager_destroy,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &zwp_primary_selection_device_manager_v1_interface, version, id);
    if (!r) { wl_client_post_no_memory(client); return; }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_primary_selection_init(struct WaylandServer* server) {
    wl_list_init(&server->primary_device_resources);
    server->primary_selection_manager_global = wl_global_create(server->display,
        &zwp_primary_selection_device_manager_v1_interface, 1, server, manager_bind);
}
