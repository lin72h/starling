// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_data_device.c — wl_data_device_manager, wl_data_source,
 *                          wl_data_device, wl_data_offer
 *
 * Implements clipboard copy/paste for focus-based Wayland clients.
 * The selection itself lives in server->clipboard (see wayland_server_
 * internal.h) and is SHARED with the focus-free zwlr_data_control protocol
 * (wayland_data_control.c) so a copy in any client pastes in any other.
 * This file owns the wl_data_device half: it broadcasts the shared
 * selection to bound wl_data_device clients and mints wl_data_offers.
 *
 * Also hosts the protocol-agnostic wayland_clipboard_set() used by both
 * set_selection paths.
 */

#include "wayland_server_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* ========================================================================== */
/* Internal data structures                                                    */
/* ========================================================================== */

#define MAX_MIME_TYPES 32

struct WaylandDataSource {
    struct wl_resource* resource;
    struct WaylandServer* server;  /* back-reference for cleanup */
    char* mime_types[MAX_MIME_TYPES];
    int mime_count;
};

/* One per wl_data_offer resource. Validity is checked against the live
 * clipboard serial at receive time — no per-source offer list needed: if the
 * selection changed (or its source died), server->clipboard.serial no longer
 * matches and the receive returns EOF instead of touching a freed source. */
struct WaylandDataOffer {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint64_t serial;                   /* clipboard serial this offer serves */
};

/* One per bound wl_data_device resource (a client may bind several across
 * connections). Unlinks itself in the resource destructor. */
struct WaylandDataDevice {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct wl_list link;               /* in server->data_device_resources */
    /* Clipboard serial this device has already been told about. 0 = none.
     * Lets the interaction hooks below re-offer a selection to a client that
     * missed the broadcast (it bound afterwards) without re-minting an offer
     * on every pointer crossing. */
    uint64_t sent_serial;
};

/* Forward declarations (offer impl + destructor are defined further down but
 * referenced by the selection broadcaster above them). */
static const struct wl_data_offer_interface data_offer_impl;
static void data_offer_resource_destroy(struct wl_resource* resource);

/* ========================================================================== */
/* Unified clipboard (shared with wayland_data_control.c)                      */
/* ========================================================================== */

/* Serve data / notify-lost for a wl_data_source-owned selection. */
static void wl_source_send(void* owner, const char* mime, int32_t fd) {
    struct WaylandDataSource* s = owner;
    if (s && s->resource) wl_data_source_send_send(s->resource, mime, fd);
}
static void wl_source_cancel(void* owner) {
    struct WaylandDataSource* s = owner;
    if (s && s->resource) wl_data_source_send_cancelled(s->resource);
}

/* Mint a wl_data_offer for the current selection and hand it to one device
 * (used on every set + on keyboard focus enter). NULL selection → send NULL. */
static void wl_send_selection_to_device(struct WaylandServer* server,
                                        struct WaylandDataDevice* dev) {
    struct wl_resource* dd = dev->resource;
    dev->sent_serial = server->clipboard.serial;
    if (!server->clipboard.owner) {
        wl_data_device_send_selection(dd, NULL);
        return;
    }
    struct WaylandDataOffer* offer = calloc(1, sizeof(*offer));
    if (!offer) return;
    struct wl_resource* offer_res = wl_resource_create(
        wl_resource_get_client(dd), &wl_data_offer_interface,
        wl_resource_get_version(dd), 0);
    if (!offer_res) { free(offer); return; }
    offer->resource = offer_res;
    offer->server = server;
    offer->serial = server->clipboard.serial;
    wl_resource_set_implementation(offer_res, &data_offer_impl, offer,
                                   data_offer_resource_destroy);
    /* data_offer (creates client-side), MIME types, then selection handoff. */
    wl_data_device_send_data_offer(dd, offer_res);
    for (int i = 0; i < server->clipboard.mime_count; i++)
        wl_data_offer_send_offer(offer_res, server->clipboard.mimes[i]);
    wl_data_device_send_selection(dd, offer_res);
}

void wayland_data_device_broadcast_selection(struct WaylandServer* server) {
    struct WaylandDataDevice* dd;
    wl_list_for_each(dd, &server->data_device_resources, link)
        wl_send_selection_to_device(server, dd);
}

/* Give a client the current selection when it starts interacting with a
 * surface, if it has not already been told about this one.
 *
 * Why this exists: the broadcast above only reaches devices bound at the time
 * of the copy. A client that starts LATER never learns about the selection —
 * copy a URL, then launch Chrome, and Chrome's clipboard is empty until
 * somebody copies again. That was a real, shipping bug.
 *
 * Why it hangs off interaction rather than focus: keyboard focus here is lazy,
 * sent from the first keystroke (see sendKeyEvent in WaylandIntegration.swift),
 * so a window that is merely focused and clicked has no wl_keyboard.enter and
 * would never get the offer — right-click → Paste would find nothing. Pointer
 * enter is the earliest reliable "the user is working in this window" signal.
 *
 * Why it is NOT sent from get_data_device: a selection event during client
 * init crashes Qt6, whose handler runs before QGuiApplication has built its
 * clipboard — the trap documented at length in wayland_primary_selection.c.
 * Any interaction is comfortably after init.
 *
 * The serial guard keeps this cheap: in the steady state every device is
 * already current from the broadcast, so crossing windows with the mouse mints
 * nothing. It fires once per client per selection, exactly for the client that
 * missed the broadcast. */
void wayland_data_device_offer_on_interaction(struct WaylandServer* server,
                                              struct WaylandSurface* surface) {
    if (!server || !surface || !surface->resource) return;
    if (!server->clipboard.owner) return;   /* nothing to offer */
    struct wl_client* client = wl_resource_get_client(surface->resource);
    if (!client) return;
    struct WaylandDataDevice* dd;
    wl_list_for_each(dd, &server->data_device_resources, link) {
        if (wl_resource_get_client(dd->resource) == client &&
            dd->sent_serial != server->clipboard.serial)
            wl_send_selection_to_device(server, dd);
    }
}

void wayland_clipboard_set(struct WaylandServer* server, void* owner,
                           char** mimes, int mime_count,
                           void (*send)(void*, const char*, int32_t),
                           void (*cancel)(void*)) {
    /* Tell the previous owner it lost the selection so it can drop its data
     * (Chrome otherwise believes it owns the clipboard forever). */
    if (server->clipboard.owner && server->clipboard.owner != owner &&
        server->clipboard.cancel) {
        server->clipboard.cancel(server->clipboard.owner);
    }
    server->clipboard.owner = owner;
    server->clipboard.mimes = owner ? mimes : NULL;
    server->clipboard.mime_count = owner ? mime_count : 0;
    server->clipboard.send = owner ? send : NULL;
    server->clipboard.cancel = owner ? cancel : NULL;
    server->clipboard.serial++;

    fprintf(stderr, "[WaylandServer] clipboard set: owner=%p mimes=%d serial=%llu\n",
            owner, server->clipboard.mime_count,
            (unsigned long long)server->clipboard.serial);

    /* Broadcast to BOTH protocols so the copy is visible everywhere. */
    wayland_data_device_broadcast_selection(server);
    wayland_data_control_broadcast_selection(server);
}

/* Clear the selection when its owning source is being destroyed. Does NOT
 * call cancel() on the dying owner (its resource is already gone). */
static void clipboard_clear_if_owner(struct WaylandServer* server, void* owner) {
    if (server->clipboard.owner != owner) return;
    server->clipboard.owner = NULL;
    server->clipboard.mimes = NULL;
    server->clipboard.mime_count = 0;
    server->clipboard.send = NULL;
    server->clipboard.cancel = NULL;
    server->clipboard.serial++;
    wayland_data_device_broadcast_selection(server);
    wayland_data_control_broadcast_selection(server);
}

/* ========================================================================== */
/* wl_data_offer                                                               */
/* ========================================================================== */

static void data_offer_accept(struct wl_client* client,
                               struct wl_resource* resource,
                               uint32_t serial, const char* mime_type) {
    (void)client; (void)resource; (void)serial; (void)mime_type;
    /* No-op for clipboard — accept is mainly for DnD feedback. */
}

static void data_offer_receive(struct wl_client* client,
                                struct wl_resource* resource,
                                const char* mime_type, int32_t fd) {
    (void)client;
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    struct WaylandServer* server = offer ? offer->server : NULL;
    /* Only serve if this offer is for the CURRENT selection (serial match)
     * and the owner is still live. Otherwise the receiver just sees EOF. */
    if (!server || !server->clipboard.owner || !server->clipboard.send ||
        server->clipboard.serial != offer->serial) {
        close(fd);
        return;
    }
    server->clipboard.send(server->clipboard.owner, mime_type, fd);
    close(fd);  /* Compositor closes its copy; owner has its own via SCM_RIGHTS */
}

static void data_offer_destroy(struct wl_client* client,
                                struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void data_offer_finish(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client; (void)resource;
    /* No-op — finish is for DnD only. */
}

static void data_offer_set_actions(struct wl_client* client,
                                    struct wl_resource* resource,
                                    uint32_t dnd_actions,
                                    uint32_t preferred_action) {
    (void)client; (void)resource;
    (void)dnd_actions; (void)preferred_action;
    /* No-op — actions are for DnD only. */
}

static const struct wl_data_offer_interface data_offer_impl = {
    .accept = data_offer_accept,
    .receive = data_offer_receive,
    .destroy = data_offer_destroy,
    .finish = data_offer_finish,
    .set_actions = data_offer_set_actions,
};

/* Resource destructor — runs on explicit destroy AND client disconnect.
 * Wired via wl_resource_set_implementation's destroy arg. */
static void data_offer_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    free(offer);
}

/* ========================================================================== */
/* wl_data_source                                                              */
/* ========================================================================== */

static void data_source_offer(struct wl_client* client,
                               struct wl_resource* resource,
                               const char* mime_type) {
    (void)client;
    struct WaylandDataSource* source = wl_resource_get_user_data(resource);
    if (!source || source->mime_count >= MAX_MIME_TYPES)
        return;
    source->mime_types[source->mime_count++] = strdup(mime_type);
}

static void data_source_destroy(struct wl_client* client,
                                 struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void data_source_set_actions(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t dnd_actions) {
    (void)client; (void)resource; (void)dnd_actions;
    /* No-op — DnD actions not supported. */
}

static const struct wl_data_source_interface data_source_impl = {
    .offer = data_source_offer,
    .destroy = data_source_destroy,
    .set_actions = data_source_set_actions,
};

static void data_source_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataSource* source = wl_resource_get_user_data(resource);
    if (!source) return;
    if (source->server)
        clipboard_clear_if_owner(source->server, source);
    for (int i = 0; i < source->mime_count; i++)
        free(source->mime_types[i]);
    free(source);
}

/* ========================================================================== */
/* wl_data_device                                                              */
/* ========================================================================== */

static void data_device_start_drag(struct wl_client* client,
                                    struct wl_resource* resource,
                                    struct wl_resource* source,
                                    struct wl_resource* origin,
                                    struct wl_resource* icon,
                                    uint32_t serial) {
    (void)client; (void)resource; (void)source;
    (void)origin; (void)icon; (void)serial;
    /* DnD not implemented. */
}

static void data_device_set_selection(struct wl_client* client,
                                       struct wl_resource* resource,
                                       struct wl_resource* source_resource,
                                       uint32_t serial) {
    (void)client; (void)serial;
    struct WaylandDataDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    struct WaylandServer* server = dev->server;

    if (source_resource) {
        struct WaylandDataSource* source =
            wl_resource_get_user_data(source_resource);
        if (!source) return;
        wayland_clipboard_set(server, source, source->mime_types,
                              source->mime_count, wl_source_send,
                              wl_source_cancel);
    } else {
        wayland_clipboard_set(server, NULL, NULL, 0, NULL, NULL);
    }
}

static void data_device_release(struct wl_client* client,
                                 struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct wl_data_device_interface data_device_impl = {
    .start_drag = data_device_start_drag,
    .set_selection = data_device_set_selection,
    .release = data_device_release,
};

/* ========================================================================== */
/* wl_data_device_manager                                                      */
/* ========================================================================== */

static void manager_create_data_source(struct wl_client* client,
                                        struct wl_resource* resource,
                                        uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandDataSource* source = calloc(1, sizeof(struct WaylandDataSource));
    if (!source) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* source_res = wl_resource_create(client,
        &wl_data_source_interface,
        wl_resource_get_version(resource), id);
    if (!source_res) {
        free(source);
        wl_client_post_no_memory(client);
        return;
    }
    source->resource = source_res;
    source->server = server;
    wl_resource_set_implementation(source_res, &data_source_impl,
                                   source, data_source_resource_destroy);
}

/* Resource destructor — unlinks the tracking entry on explicit release AND
 * on client disconnect. Never leave a bare pointer to a device resource
 * behind (the old single-slot `data_device_resource` dangled after release
 * → UAF on the next copy). */
static void data_device_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    wl_list_remove(&dev->link);
    free(dev);
}

static void manager_get_data_device(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t id,
                                     struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* device = wl_resource_create(client,
        &wl_data_device_interface,
        wl_resource_get_version(resource), id);
    if (!device) {
        wl_client_post_no_memory(client);
        return;
    }
    struct WaylandDataDevice* dev = calloc(1, sizeof(*dev));
    if (!dev) {
        wl_resource_destroy(device);
        wl_client_post_no_memory(client);
        return;
    }
    dev->resource = device;
    dev->server = server;
    wl_list_insert(&server->data_device_resources, &dev->link);
    wl_resource_set_implementation(device, &data_device_impl, dev,
                                   data_device_resource_destroy);
}

static const struct wl_data_device_manager_interface manager_impl = {
    .create_data_source = manager_create_data_source,
    .get_data_device = manager_get_data_device,
};

static void manager_bind(struct wl_client* client, void* data,
                          uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wl_data_device_manager_interface, version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &manager_impl, data, NULL);
}

void wayland_data_device_init(struct WaylandServer* server) {
    wl_list_init(&server->data_device_resources);
    server->data_device_manager_global = wl_global_create(
        server->display, &wl_data_device_manager_interface, 3,
        server, manager_bind);
}
