// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_session_lock.c — ext_session_lock_v1
 *
 * The lock-screen protocol swaylock, gtklock and hyprlock speak. A locker
 * asks for the session; once `locked` is sent the desktop may show nothing
 * but the locker's own surfaces (one per output, sized to it) and black
 * where none has been drawn yet, and no input reaches anything else. The
 * locker unlocks with unlock_and_destroy — or dies, in which case the
 * protocol's rule is that the session STAYS locked and the next locker
 * takes over; a crash must not be an unlock.
 *
 * Lock surfaces are lent to the layer-shell machinery: each is placed as an
 * overlay surface anchored to all four edges with exclusive keyboard
 * interactivity, in the namespace "session-lock", so the shell draws and
 * routes them like any bar or launcher; on_session_lock is what makes it
 * hide everything else. The configure they need is this protocol's own.
 */

#include "wayland_server_internal.h"
#include "ext-session-lock-v1-protocol.h"
#include "wlr-layer-shell-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

struct LockSurface {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct WaylandLayerSurface* layer;   // the placement, NULL once gone
    int output_index;
};

/* --- lock surface ---------------------------------------------------------- */

static void lock_surface_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void lock_surface_ack_configure(struct wl_client* c, struct wl_resource* r,
                                       uint32_t serial) {
    (void)c; (void)r; (void)serial;
}

static const struct ext_session_lock_surface_v1_interface lock_surface_impl = {
    .destroy = lock_surface_destroy,
    .ack_configure = lock_surface_ack_configure,
};

static void lock_surface_resource_destroyed(struct wl_resource* r) {
    struct LockSurface* lsf = wl_resource_get_user_data(r);
    if (!lsf) return;
    wayland_layer_shell_release(lsf->layer);
    free(lsf);
}

/* --- lock -------------------------------------------------------------------- */

static void lock_get_lock_surface(struct wl_client* client, struct wl_resource* resource,
                                  uint32_t id, struct wl_resource* wl_surface,
                                  struct wl_resource* output) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (!surface) return;
    if (surface->xdg_surface || surface->xdg_toplevel || surface->xdg_popup ||
        surface->layer || surface->is_subsurface) {
        wl_resource_post_error(resource, EXT_SESSION_LOCK_V1_ERROR_ROLE,
                               "wl_surface already has a role");
        return;
    }
    int idx = wayland_output_index_of(server, output);
    if (idx < 0) idx = 0;
    struct WaylandLayerSurface* ls;
    wl_list_for_each(ls, &server->layer_surfaces, link) {
        if (!ls->resource && ls->surface && ls->output_index == idx &&
            wl_resource_get_client(ls->surface->resource) == client) {
            wl_resource_post_error(resource, EXT_SESSION_LOCK_V1_ERROR_DUPLICATE_OUTPUT,
                                   "a lock surface already covers this output");
            return;
        }
    }
    struct LockSurface* lsf = calloc(1, sizeof(*lsf));
    if (!lsf) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &ext_session_lock_surface_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(lsf);
        wl_client_post_no_memory(client);
        return;
    }
    lsf->resource = r;
    lsf->server = server;
    lsf->output_index = idx;
    lsf->layer = wayland_layer_shell_adopt(server, surface, idx,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
        ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_EXCLUSIVE, "session-lock");
    wl_resource_set_implementation(r, &lock_surface_impl, lsf, lock_surface_resource_destroyed);

    struct WaylandOutput* o = &server->outputs[idx];
    int32_t scale = o->scale > 0 ? o->scale : 1;
    ext_session_lock_surface_v1_send_configure(r, wayland_server_next_serial(server),
        (uint32_t)(o->physical_w / scale), (uint32_t)(o->physical_h / scale));
}

static void session_set_locked(struct WaylandServer* server, int locked) {
    if (server->session_locked == locked) return;
    server->session_locked = locked;
    fprintf(stderr, "[session_lock] session %s\n", locked ? "locked" : "unlocked");
    if (server->cb.on_session_lock) server->cb.on_session_lock(server->cb_ctx, locked);
}

static void lock_unlock_and_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandServer* server = wl_resource_get_user_data(r);
    if (server->session_lock != r) {
        wl_resource_post_error(r, EXT_SESSION_LOCK_V1_ERROR_INVALID_UNLOCK,
                               "unlock from a lock that does not hold the session");
        return;
    }
    server->session_lock = NULL;
    session_set_locked(server, 0);
    wl_resource_destroy(r);
}

static void lock_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandServer* server = wl_resource_get_user_data(r);
    if (server->session_lock == r) {
        wl_resource_post_error(r, EXT_SESSION_LOCK_V1_ERROR_INVALID_DESTROY,
                               "destroy while holding the lock (use unlock_and_destroy)");
        return;
    }
    wl_resource_destroy(r);
}

static const struct ext_session_lock_v1_interface lock_impl = {
    .destroy = lock_destroy,
    .get_lock_surface = lock_get_lock_surface,
    .unlock_and_destroy = lock_unlock_and_destroy,
};

/* Disconnect while holding the lock: the session stays locked. */
static void lock_resource_destroyed(struct wl_resource* r) {
    struct WaylandServer* server = wl_resource_get_user_data(r);
    if (server->session_lock == r) {
        server->session_lock = NULL;
        fprintf(stderr, "[session_lock] the locker went away; the session stays locked\n");
    }
}

/* --- manager ------------------------------------------------------------------ */

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_lock(struct wl_client* client, struct wl_resource* resource, uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct wl_resource* r = wl_resource_create(client, &ext_session_lock_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &lock_impl, server, lock_resource_destroyed);
    if (server->session_lock) {
        /* Someone holds it. A locker whose predecessor died may take over
         * (the session is locked with nobody to unlock it otherwise). */
        ext_session_lock_v1_send_finished(r);
        return;
    }
    server->session_lock = r;
    ext_session_lock_v1_send_locked(r);
    session_set_locked(server, 1);
}

static const struct ext_session_lock_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .lock = manager_lock,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client, &ext_session_lock_manager_v1_interface,
                                               version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_session_lock_init(struct WaylandServer* server) {
    server->session_lock_manager_global = wl_global_create(server->display,
        &ext_session_lock_manager_v1_interface, 1, server, manager_bind);
}
