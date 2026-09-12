// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_transient_seat.c — ext_transient_seat_manager_v1
 *
 * A seat made on request, for a client that wants input of its own to bind
 * virtual devices to — a VNC server, a remote-control agent. This desktop
 * has one pointer and one keyboard on screen, so a transient seat is a new
 * wl_seat global that ALIASES the human seat: it has its own name and
 * global, and what is typed on its virtual devices lands in the same input
 * stream as the real ones. It goes away with the object that made it.
 */

#include "wayland_server_internal.h"
#include "ext-transient-seat-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

static void seat_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_transient_seat_v1_interface seat_impl = {
    .destroy = seat_destroy,
};

static void seat_resource_destroyed(struct wl_resource* r) {
    struct WaylandTransientSeat* ts = wl_resource_get_user_data(r);
    if (!ts) return;
    if (ts->global) wl_global_destroy(ts->global);
    wl_list_remove(&ts->link);
    free(ts);
}

static void manager_create(struct wl_client* client, struct wl_resource* resource, uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandTransientSeat* ts = calloc(1, sizeof(*ts));
    if (!ts) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &ext_transient_seat_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(ts);
        wl_client_post_no_memory(client);
        return;
    }
    static uint32_t counter = 0;
    snprintf(ts->name, sizeof(ts->name), "seat-transient-%u", ++counter);
    ts->resource = r;
    ts->desc.server = server;
    ts->desc.index = 0;
    ts->desc.name = ts->name;
    ts->global = wayland_seat_create_global(server, &ts->desc);
    wl_list_insert(&server->transient_seats, &ts->link);
    wl_resource_set_implementation(r, &seat_impl, ts, seat_resource_destroyed);
    if (!ts->global) {
        ext_transient_seat_v1_send_denied(r);
        return;
    }
    ext_transient_seat_v1_send_ready(r, wl_global_get_name(ts->global, client));
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_transient_seat_manager_v1_interface manager_impl = {
    .create = manager_create,
    .destroy = manager_destroy,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_transient_seat_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_transient_seat_init(struct WaylandServer* server) {
    wl_list_init(&server->transient_seats);
    server->transient_seat_manager_global = wl_global_create(server->display,
        &ext_transient_seat_manager_v1_interface, 1, server, manager_bind);
}
