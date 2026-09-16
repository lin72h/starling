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
    uint32_t dnd_actions;          /* wl_data_source.set_actions */
};

/* One per wl_data_offer resource. Validity is checked against the live
 * clipboard serial at receive time — no per-source offer list needed: if the
 * selection changed (or its source died), server->clipboard.serial no longer
 * matches and the receive returns EOF instead of touching a freed source. */
struct WaylandDataOffer {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint64_t serial;                   /* clipboard serial this offer serves */
    int dnd;                           /* a drag's offer, not the clipboard's */
};

/* One per bound wl_data_device resource (a client may bind several across
 * connections). Unlinks itself in the resource destructor. */
struct WaylandDataDevice {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct wl_list link;               /* in server->data_device_resources */
    int seat;                          /* the wl_seat it was made for (0 = the human's) */
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
    wayland_ext_data_control_broadcast_selection(server);
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
    wayland_ext_data_control_broadcast_selection(server);
}

/* ========================================================================== */
/* wl_data_offer                                                               */
/* ========================================================================== */

static void data_offer_accept(struct wl_client* client,
                               struct wl_resource* resource,
                               uint32_t serial, const char* mime_type) {
    (void)client; (void)serial;
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    if (!offer || !offer->dnd) return;
    struct WaylandServer* server = offer->server;
    if (server->drag.focus_offer == resource) {
        server->drag.accepted = mime_type != NULL;
        if (server->drag.source_resource)
            wl_data_source_send_target(server->drag.source_resource, mime_type);
    }
}

static void data_offer_receive(struct wl_client* client,
                                struct wl_resource* resource,
                                const char* mime_type, int32_t fd) {
    (void)client;
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    struct WaylandServer* server = offer ? offer->server : NULL;
    if (!server) {
        close(fd);
        return;
    }
    /* A drag's offer reads from the drag's source, for as long as the
     * drag (or its drop) is being served. */
    if (offer->dnd) {
        if (server->drag.source_resource && server->drag.focus_offer == resource)
            wl_data_source_send_send(server->drag.source_resource, mime_type, fd);
        close(fd);
        return;
    }
    /* Only serve if this offer is for the CURRENT selection (serial match)
     * and the owner is still live. Otherwise the receiver just sees EOF. */
    if (!server->clipboard.owner || !server->clipboard.send ||
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

static void dnd_choose_action(struct WaylandServer* server);

static void data_offer_finish(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    if (!offer || !offer->dnd) return;
    struct WaylandServer* server = offer->server;
    if (server->drag.focus_offer != resource) return;
    /* The target is done reading the dropped data: the source may free it. */
    if (server->drag.source_resource &&
        wl_resource_get_version(server->drag.source_resource) >=
            WL_DATA_SOURCE_DND_FINISHED_SINCE_VERSION) {
        wl_data_source_send_dnd_finished(server->drag.source_resource);
    }
    server->drag.focus_offer = NULL;
    server->drag.focus = NULL;
    server->drag.source_resource = NULL;
    server->drag.source = NULL;
}

static void data_offer_set_actions(struct wl_client* client,
                                    struct wl_resource* resource,
                                    uint32_t dnd_actions,
                                    uint32_t preferred_action) {
    (void)client;
    struct WaylandDataOffer* offer = wl_resource_get_user_data(resource);
    if (!offer || !offer->dnd) return;
    struct WaylandServer* server = offer->server;
    if (server->drag.focus_offer != resource) return;
    server->drag.offer_actions = dnd_actions;
    server->drag.offer_preferred = preferred_action;
    dnd_choose_action(server);
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
    (void)client;
    struct WaylandDataSource* source = wl_resource_get_user_data(resource);
    if (source) source->dnd_actions = dnd_actions;
}

static const struct wl_data_source_interface data_source_impl = {
    .offer = data_source_offer,
    .destroy = data_source_destroy,
    .set_actions = data_source_set_actions,
};

static void data_source_resource_destroy(struct wl_resource* resource) {
    struct WaylandDataSource* source = wl_resource_get_user_data(resource);
    if (!source) return;
    if (source->server && source->server->drag.source == source) {
        source->server->drag.source = NULL;
        source->server->drag.source_resource = NULL;
        if (source->server->drag.active) wayland_dnd_end(source->server, 0);
    }
    if (source->server)
        clipboard_clear_if_owner(source->server, source);
    for (int i = 0; i < source->mime_count; i++)
        free(source->mime_types[i]);
    free(source);
}

/* ========================================================================== */
/* wl_data_device                                                              */
/* ========================================================================== */

/* ========================================================================== */
/* Drag-and-drop                                                               */
/*                                                                             */
/* start_drag makes the pointer a drag pointer: while it lasts the shell's    */
/* pointer events (still sent per surface, with the surface they are over)   */
/* become wl_data_device enter/motion/leave on the surface under the pointer, */
/* each entered surface gets a fresh offer of the source's mime types, and    */
/* the button's release is the drop — delivered when the entered client       */
/* accepted something, cancelled otherwise. wl_pointer stays quiet meanwhile, */
/* as the protocol says. The icon surface is drawn by the shell at the        */
/* pointer; an attached toplevel (xdg-toplevel-drag) follows it too.          */
/* ========================================================================== */

static void dnd_send_action(struct WaylandServer* server) {
    struct WaylandDrag* d = &server->drag;
    if (d->focus_offer &&
        wl_resource_get_version(d->focus_offer) >= WL_DATA_OFFER_ACTION_SINCE_VERSION)
        wl_data_offer_send_action(d->focus_offer, d->chosen_action);
    if (d->source_resource &&
        wl_resource_get_version(d->source_resource) >= WL_DATA_SOURCE_ACTION_SINCE_VERSION)
        wl_data_source_send_action(d->source_resource, d->chosen_action);
}

/* The action both sides agree on: the target's preference if the source
 * offers it, else the first the two have in common, else none. A source
 * that never set actions (protocol v2 and below) is treated as copy. */
static void dnd_choose_action(struct WaylandServer* server) {
    struct WaylandDrag* d = &server->drag;
    uint32_t src = d->source_actions ? d->source_actions
                                     : WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
    uint32_t common = src & d->offer_actions;
    uint32_t chosen = 0;
    if (common & d->offer_preferred) chosen = d->offer_preferred;
    else if (common & WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY) chosen = WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
    else if (common & WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE) chosen = WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE;
    else if (common & WL_DATA_DEVICE_MANAGER_DND_ACTION_ASK) chosen = WL_DATA_DEVICE_MANAGER_DND_ACTION_ASK;
    if (chosen != d->chosen_action) {
        d->chosen_action = chosen;
        dnd_send_action(server);
    }
}

/* The wl_data_device of the client owning `surface` for the human's seat —
 * the one the drag is on. A client with several seats bound (GTK binds
 * every wl_seat, the agent's included) answers a drag only on the device
 * of the seat whose pointer is dragging; the others refuse it. */
static struct WaylandDataDevice* dnd_device_for(struct WaylandServer* server,
                                                struct WaylandSurface* surface) {
    if (!surface || !surface->resource) return NULL;
    struct wl_client* client = wl_resource_get_client(surface->resource);
    struct WaylandDataDevice* dd;
    wl_list_for_each(dd, &server->data_device_resources, link) {
        if (wl_resource_get_client(dd->resource) == client && dd->seat == 0) return dd;
    }
    return NULL;
}

static void dnd_leave(struct WaylandServer* server) {
    struct WaylandDrag* d = &server->drag;
    if (!d->focus) return;
    struct WaylandDataDevice* dd = dnd_device_for(server, d->focus);
    if (dd) wl_data_device_send_leave(dd->resource);
    d->focus = NULL;
    d->focus_offer = NULL;   /* the client destroys its offer */
    d->accepted = 0;
    d->offer_actions = 0;
    d->offer_preferred = 0;
    d->chosen_action = 0;
}

static void dnd_enter(struct WaylandServer* server, struct WaylandSurface* surface,
                      double x, double y) {
    struct WaylandDrag* d = &server->drag;
    struct WaylandDataDevice* dd = dnd_device_for(server, surface);
    if (!dd) return;                     /* a client with no data device: not a target */
    struct wl_resource* offer_res = NULL;
    if (d->source) {
        struct WaylandDataOffer* offer = calloc(1, sizeof(*offer));
        if (!offer) return;
        offer_res = wl_resource_create(wl_resource_get_client(dd->resource),
                                       &wl_data_offer_interface,
                                       wl_resource_get_version(dd->resource), 0);
        if (!offer_res) {
            free(offer);
            return;
        }
        offer->resource = offer_res;
        offer->server = server;
        offer->dnd = 1;
        wl_resource_set_implementation(offer_res, &data_offer_impl, offer,
                                       data_offer_resource_destroy);
        wl_data_device_send_data_offer(dd->resource, offer_res);
        for (int i = 0; i < d->source->mime_count; i++)
            wl_data_offer_send_offer(offer_res, d->source->mime_types[i]);
        if (wl_resource_get_version(offer_res) >= WL_DATA_OFFER_SOURCE_ACTIONS_SINCE_VERSION)
            wl_data_offer_send_source_actions(offer_res, d->source_actions);
    }
    d->focus = surface;
    d->focus_offer = offer_res;
    d->accepted = 0;
    d->chosen_action = 0;
    d->offer_actions = 0;
    d->offer_preferred = 0;
    wl_data_device_send_enter(dd->resource, wl_display_next_serial(server->display),
                              surface->resource, wl_fixed_from_double(x),
                              wl_fixed_from_double(y), offer_res);
}

int wayland_dnd_pointer_event(struct WaylandServer* server,
                              const struct WaylandPointerEvent* ev,
                              struct WaylandSurface* surface) {
    struct WaylandDrag* d = &server->drag;
    switch (ev->type) {
    case WL_PTR_ENTER:
        if (d->focus != surface) {
            dnd_leave(server);
            dnd_enter(server, surface, ev->x, ev->y);
        }
        d->last_x = ev->x;
        d->last_y = ev->y;
        return 1;
    case WL_PTR_MOTION:
        if (d->focus != surface) {
            dnd_leave(server);
            dnd_enter(server, surface, ev->x, ev->y);
        } else if (d->focus) {
            struct WaylandDataDevice* dd = dnd_device_for(server, d->focus);
            if (dd) wl_data_device_send_motion(dd->resource, ev->time_ms,
                                               wl_fixed_from_double(ev->x),
                                               wl_fixed_from_double(ev->y));
        }
        d->last_x = ev->x;
        d->last_y = ev->y;
        return 1;
    case WL_PTR_LEAVE:
        if (d->focus == surface) dnd_leave(server);
        return 1;
    case WL_PTR_BUTTON:
        if (ev->state == 0) wayland_dnd_end(server, 1);
        return 1;
    default:
        return 1;                        /* axes: swallowed during a drag */
    }
}

/* Re-enter the pointer on `surface` for its client: the drag hid it. */
static void dnd_pointer_reenter(struct WaylandServer* server, struct WaylandSurface* surface,
                                double x, double y) {
    if (!surface || !surface->resource) return;
    struct wl_client* target = wl_resource_get_client(surface->resource);
    uint32_t serial = wl_display_next_serial(server->display);
    struct WaylandInputResource* ir;
    wl_list_for_each(ir, &server->pointer_resources, link) {
        if (wl_resource_get_client(ir->resource) != target || ir->seat != 0) continue;
        wl_pointer_send_enter(ir->resource, serial, surface->resource,
                              wl_fixed_from_double(x), wl_fixed_from_double(y));
        if (wl_resource_get_version(ir->resource) >= WL_POINTER_FRAME_SINCE_VERSION)
            wl_pointer_send_frame(ir->resource);
    }
}

void wayland_dnd_end(struct WaylandServer* server, int dropped) {
    struct WaylandDrag* d = &server->drag;
    if (!d->active) return;
    struct WaylandSurface* under = d->focus;
    int delivered = 0;
    if (dropped && d->focus && d->accepted && d->chosen_action) {
        struct WaylandDataDevice* dd = dnd_device_for(server, d->focus);
        if (dd) {
            wl_data_device_send_drop(dd->resource);
            if (d->source_resource &&
                wl_resource_get_version(d->source_resource) >=
                    WL_DATA_SOURCE_DND_DROP_PERFORMED_SINCE_VERSION)
                wl_data_source_send_dnd_drop_performed(d->source_resource);
            delivered = 1;
        }
    }
    if (!delivered) {
        dnd_leave(server);
        if (d->source_resource) wl_data_source_send_cancelled(d->source_resource);
        d->source = NULL;
        d->source_resource = NULL;
    }
    /* Dropped: the target's offer.finish closes the transfer, so the focus
     * and its offer stay for that. Either way the drag itself is over. */
    d->active = 0;
    if (d->attached && server->cb.on_toplevel_drag)
        server->cb.on_toplevel_drag(server->cb_ctx, d->attached->id, 0, 0, 0);
    d->attached = NULL;
    d->toplevel_drag = NULL;
    if (d->icon) {
        d->icon->is_drag_icon = 0;
        d->icon = NULL;
    }
    if (server->cb.on_drag_icon) server->cb.on_drag_icon(server->cb_ctx, 0, 0);
    /* The surface under the pointer gets its pointer back with a fresh
     * enter, so the client's idea of focus agrees with the shell's again. */
    dnd_pointer_reenter(server, under, d->last_x, d->last_y);
    fprintf(stderr, "[wayland_dnd] drag ended: %s\n",
            delivered ? "dropped" : dropped ? "released, no target" : "cancelled");
}

void wayland_dnd_surface_destroyed(struct WaylandServer* server,
                                   struct WaylandSurface* surface) {
    struct WaylandDrag* d = &server->drag;
    if (d->icon == surface) {
        d->icon = NULL;
        if (server->cb.on_drag_icon) server->cb.on_drag_icon(server->cb_ctx, 0, d->active);
    }
    if (d->focus == surface) {
        d->focus = NULL;
        d->focus_offer = NULL;
        d->accepted = 0;
    }
    if (d->origin == surface) d->origin = NULL;
    if (d->attached == surface) d->attached = NULL;
}

void wayland_server_pointer_global_release(WaylandServer* server) {
    if (!server) return;
    /* Any thread: ride the deferred input queue as a button-up on the
     * drag's focus (or nothing); the drain ends the drag on the loop thread. */
    wayland_server_pointer_button(server, 0, 0, 0x110, 0);
}

static void data_device_start_drag(struct wl_client* client,
                                    struct wl_resource* resource,
                                    struct wl_resource* source,
                                    struct wl_resource* origin,
                                    struct wl_resource* icon,
                                    uint32_t serial) {
    (void)serial;
    struct WaylandDataDevice* dev = wl_resource_get_user_data(resource);
    if (!dev) return;
    struct WaylandServer* server = dev->server;
    struct WaylandDrag* d = &server->drag;
    if (d->active) wayland_dnd_end(server, 0);

    struct WaylandSurface* origin_s = origin ? wl_resource_get_user_data(origin) : NULL;
    struct WaylandSurface* icon_s = icon ? wl_resource_get_user_data(icon) : NULL;
    if (icon_s && (icon_s->xdg_surface || icon_s->layer || icon_s->is_subsurface)) {
        wl_resource_post_error(resource, WL_DATA_DEVICE_ERROR_ROLE,
                               "the drag icon surface already has a role");
        return;
    }
    struct WaylandDataSource* src = source ? wl_resource_get_user_data(source) : NULL;

    d->active = 1;
    d->client = client;
    d->source = src;
    d->source_resource = source;
    d->source_actions = src ? src->dnd_actions : 0;
    d->origin = origin_s;
    d->icon = icon_s;
    d->focus = NULL;
    d->focus_offer = NULL;
    d->accepted = 0;
    d->chosen_action = 0;
    d->offer_actions = 0;
    d->offer_preferred = 0;
    if (icon_s) {
        icon_s->is_drag_icon = 1;
        icon_s->had_role = 1;
    }
    if (server->cb.on_drag_icon) server->cb.on_drag_icon(server->cb_ctx, icon_s ? icon_s->id : 0, 1);

    /* The pointer leaves the origin for the drag's duration; the origin is
     * where the pointer is, so it is the first drag target. */
    if (origin_s && origin_s->resource) {
        struct wl_client* target = wl_resource_get_client(origin_s->resource);
        uint32_t s = wl_display_next_serial(server->display);
        struct WaylandInputResource* ir;
        wl_list_for_each(ir, &server->pointer_resources, link) {
            if (wl_resource_get_client(ir->resource) != target || ir->seat != 0) continue;
            wl_pointer_send_leave(ir->resource, s, origin_s->resource);
            if (wl_resource_get_version(ir->resource) >= WL_POINTER_FRAME_SINCE_VERSION)
                wl_pointer_send_frame(ir->resource);
        }
        dnd_enter(server, origin_s, d->last_x, d->last_y);
    }
    /* A toplevel attached before the drag began (xdg-toplevel-drag) starts
     * following now. */
    if (d->attached && d->toplevel_drag && server->cb.on_toplevel_drag) {
        server->cb.on_toplevel_drag(server->cb_ctx, d->attached->id,
                                    d->attach_x, d->attach_y, 1);
    }
    fprintf(stderr, "[wayland_dnd] drag started (source %s, icon %u, origin %u)\n",
            src ? "yes" : "none", icon_s ? icon_s->id : 0, origin_s ? origin_s->id : 0);
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
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSeatDesc* seat_desc = seat ? wl_resource_get_user_data(seat) : NULL;

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
    dev->seat = seat_desc ? seat_desc->index : 0;
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
