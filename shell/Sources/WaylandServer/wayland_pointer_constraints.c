// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0
/*
 * wayland_pointer_constraints.c — zwp_pointer_constraints_v1
 *
 * A client asks for the pointer to be LOCKED to a surface (a game, a 3D
 * web page: the cursor stops and only relative motion reaches it) or
 * CONFINED to one (the cursor keeps moving but cannot leave). A constraint
 * takes effect when the pointer is on the surface — at once if it already
 * is — and ends when the pointer leaves, when the shell breaks it (the
 * window lost focus), or when the object or surface goes. A one-shot
 * constraint is finished after that; a persistent one arms again on the
 * next enter. The shell does the physical part on on_pointer_constraint:
 * hiding and holding the cursor, sending relative motion, clamping.
 * Regions are not honoured: a constraint covers the whole surface.
 */
#include "wayland_server_internal.h"
#include "pointer-constraints-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

struct PointerConstraint {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct WaylandSurface* surface;    // NULL once the surface is gone
    int lock;                          // 1 lock, 0 confine
    uint32_t lifetime;
    int active;
    int defunct;                       // one-shot, spent; or surface gone
    int has_hint;
    double hint_x, hint_y;
    struct wl_list link;               // server->pointer_constraints
};

static void notify(struct PointerConstraint* c, int active) {
    struct WaylandServer* server = c->server;
    if (!c->surface || !server->cb.on_pointer_constraint) return;
    server->cb.on_pointer_constraint(server->cb_ctx, c->surface->id, c->lock, active,
                                     c->has_hint, c->hint_x, c->hint_y);
}

static void activate(struct PointerConstraint* c) {
    if (c->active || c->defunct || !c->surface || !c->resource) return;
    c->active = 1;
    if (c->lock) zwp_locked_pointer_v1_send_locked(c->resource);
    else zwp_confined_pointer_v1_send_confined(c->resource);
    notify(c, 1);
}

static void deactivate(struct PointerConstraint* c, int send_event) {
    if (!c->active) return;
    c->active = 0;
    if (send_event && c->resource) {
        if (c->lock) zwp_locked_pointer_v1_send_unlocked(c->resource);
        else zwp_confined_pointer_v1_send_unconfined(c->resource);
    }
    notify(c, 0);
    if (c->lifetime == ZWP_POINTER_CONSTRAINTS_V1_LIFETIME_ONESHOT) c->defunct = 1;
}

void wayland_pointer_constraints_focus(struct WaylandServer* server,
                                       uint32_t surface_id, int entered) {
    struct PointerConstraint* c;
    struct PointerConstraint* tmp;
    wl_list_for_each_safe(c, tmp, &server->pointer_constraints, link) {
        if (!c->surface || c->surface->id != surface_id) continue;
        if (entered) activate(c);
        else deactivate(c, 1);
    }
}

void wayland_pointer_constraints_break(struct WaylandServer* server) {
    struct PointerConstraint* c;
    struct PointerConstraint* tmp;
    wl_list_for_each_safe(c, tmp, &server->pointer_constraints, link)
        deactivate(c, 1);
}

void wayland_pointer_constraints_surface_destroyed(struct WaylandServer* server,
                                                   struct WaylandSurface* surface) {
    struct PointerConstraint* c;
    struct PointerConstraint* tmp;
    wl_list_for_each_safe(c, tmp, &server->pointer_constraints, link) {
        if (c->surface != surface) continue;
        deactivate(c, 1);
        c->surface = NULL;
        c->defunct = 1;
    }
}

/* Explicit destroy and client disconnect alike. */
static void constraint_resource_destroy(struct wl_resource* r) {
    struct PointerConstraint* c = wl_resource_get_user_data(r);
    if (!c) return;
    c->resource = NULL;
    deactivate(c, 0);
    wl_list_remove(&c->link);
    free(c);
}

static void constraint_destroy_request(struct wl_client* client, struct wl_resource* r) {
    (void)client;
    wl_resource_destroy(r);
}

static void locked_set_cursor_position_hint(struct wl_client* client, struct wl_resource* r,
                                            wl_fixed_t x, wl_fixed_t y) {
    (void)client;
    struct PointerConstraint* c = wl_resource_get_user_data(r);
    if (!c) return;
    c->has_hint = 1;
    c->hint_x = wl_fixed_to_double(x);
    c->hint_y = wl_fixed_to_double(y);
}

static void constraint_set_region(struct wl_client* client, struct wl_resource* r,
                                  struct wl_resource* region) {
    (void)client; (void)r; (void)region;   /* whole surface, always */
}

static const struct zwp_locked_pointer_v1_interface locked_pointer_impl = {
    .destroy = constraint_destroy_request,
    .set_cursor_position_hint = locked_set_cursor_position_hint,
    .set_region = constraint_set_region,
};

static const struct zwp_confined_pointer_v1_interface confined_pointer_impl = {
    .destroy = constraint_destroy_request,
    .set_region = constraint_set_region,
};

/* One live constraint per surface: a second is a protocol error. */
static struct PointerConstraint* live_constraint_on(struct WaylandServer* server,
                                                    struct WaylandSurface* surface) {
    struct PointerConstraint* c;
    wl_list_for_each(c, &server->pointer_constraints, link)
        if (c->surface == surface && !c->defunct) return c;
    return NULL;
}

static void create_constraint(struct wl_client* client, struct wl_resource* manager,
                              uint32_t id, struct wl_resource* surface_res,
                              uint32_t lifetime, int lock) {
    struct WaylandServer* server = wl_resource_get_user_data(manager);
    struct WaylandSurface* surface = surface_res ? wl_resource_get_user_data(surface_res) : NULL;
    if (surface && live_constraint_on(server, surface)) {
        wl_resource_post_error(manager, ZWP_POINTER_CONSTRAINTS_V1_ERROR_ALREADY_CONSTRAINED,
                               "the surface already has a pointer constraint");
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        lock ? &zwp_locked_pointer_v1_interface : &zwp_confined_pointer_v1_interface, 1, id);
    if (!r) { wl_client_post_no_memory(client); return; }
    struct PointerConstraint* c = calloc(1, sizeof(*c));
    if (!c) { wl_resource_destroy(r); wl_client_post_no_memory(client); return; }
    c->resource = r;
    c->server = server;
    c->surface = surface;
    c->lock = lock;
    c->lifetime = lifetime;
    wl_list_insert(&server->pointer_constraints, &c->link);
    if (lock) wl_resource_set_implementation(r, &locked_pointer_impl, c, constraint_resource_destroy);
    else wl_resource_set_implementation(r, &confined_pointer_impl, c, constraint_resource_destroy);
    /* The pointer is already there: in force at once. */
    if (surface && server->pointer_focus_id == surface->id) activate(c);
}

static void constraints_lock_pointer(struct wl_client* client, struct wl_resource* resource,
                                     uint32_t id, struct wl_resource* surface,
                                     struct wl_resource* pointer, struct wl_resource* region,
                                     uint32_t lifetime) {
    (void)pointer; (void)region;
    create_constraint(client, resource, id, surface, lifetime, 1);
}

static void constraints_confine_pointer(struct wl_client* client, struct wl_resource* resource,
                                        uint32_t id, struct wl_resource* surface,
                                        struct wl_resource* pointer, struct wl_resource* region,
                                        uint32_t lifetime) {
    (void)pointer; (void)region;
    create_constraint(client, resource, id, surface, lifetime, 0);
}

static void constraints_destroy(struct wl_client* client, struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct zwp_pointer_constraints_v1_interface constraints_impl = {
    .destroy = constraints_destroy,
    .lock_pointer = constraints_lock_pointer,
    .confine_pointer = constraints_confine_pointer,
};

static void constraints_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &zwp_pointer_constraints_v1_interface, version, id);
    if (!resource) { wl_client_post_no_memory(client); return; }
    wl_resource_set_implementation(resource, &constraints_impl, data, NULL);
}

void wayland_pointer_constraints_init(struct WaylandServer* server) {
    wl_list_init(&server->pointer_constraints);
    server->pointer_constraints_global = wl_global_create(server->display,
        &zwp_pointer_constraints_v1_interface, 1, server, constraints_bind);
}
