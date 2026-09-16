// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_layer_shell.c — zwlr_layer_shell_v1 (v5)
 *
 * The role a panel, a bar, a notification, a launcher or a lock screen takes:
 * a surface anchored to an output's edges in one of four layers, placed by
 * the compositor at a screen coordinate rather than managed as a window.
 * wmbench uses it for every window it must put somewhere and photograph.
 *
 * The compositor's half is small — validate, keep the double-buffered state,
 * answer the initial commit with a configure carrying the size — and the
 * shell's half is the placement: it hears the arrangement through
 * on_new_layer_surface/on_layer_surface_changed and draws the surface's
 * texture in the right layer of its own stack, above or below the windows.
 * The position is computed shell-side from anchor, margins and the buffer
 * the client ACTUALLY committed, not the size we suggested — a client is
 * allowed to disagree with a configure.
 *
 * Exclusive zones are reported, not arranged: the shell carves them out of
 * the work area (maximised windows, zones) rather than pushing other layer
 * surfaces around, which is enough for a bar and a notification to coexist.
 */

#include "wayland_server_internal.h"
#include "wlr-layer-shell-unstable-v1-protocol.h"
#include "xdg-shell-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ANCHOR_TOP    ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
#define ANCHOR_BOTTOM ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM
#define ANCHOR_LEFT   ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT
#define ANCHOR_RIGHT  ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT
#define ANCHOR_ALL    (ANCHOR_TOP | ANCHOR_BOTTOM | ANCHOR_LEFT | ANCHOR_RIGHT)

/* The output a layer surface sits on, in logical pixels. */
static void layer_output_size(struct WaylandServer* server, int index,
                              int32_t* w, int32_t* h) {
    struct WaylandOutput* o = &server->outputs[index];
    int32_t scale = o->scale > 0 ? o->scale : 1;
    *w = o->physical_w / scale;
    *h = o->physical_h / scale;
    if (*w < 1) *w = 1;
    if (*h < 1) *h = 1;
}

/* The exclusive edge a zone applies to, derived the way wlroots does when the
 * client did not name one: the single edge the surface is anchored to, or
 * the odd edge out of three. Anchored to none, two opposite, or all four
 * edges reserves nothing. */
static uint32_t derive_exclusive_edge(uint32_t anchor) {
    int top = (anchor & ANCHOR_TOP) != 0, bottom = (anchor & ANCHOR_BOTTOM) != 0;
    int left = (anchor & ANCHOR_LEFT) != 0, right = (anchor & ANCHOR_RIGHT) != 0;
    if (top && !bottom && (left == right)) return ANCHOR_TOP;
    if (bottom && !top && (left == right)) return ANCHOR_BOTTOM;
    if (left && !right && (top == bottom)) return ANCHOR_LEFT;
    if (right && !left && (top == bottom)) return ANCHOR_RIGHT;
    return 0;
}

static void layer_compute_info(struct WaylandServer* server,
                               struct WaylandLayerSurface* ls,
                               WaylandLayerSurfaceInfo* info) {
    const struct WaylandLayerState* st = &ls->current;
    int32_t ow, oh;
    layer_output_size(server, ls->output_index, &ow, &oh);
    int left = (st->anchor & ANCHOR_LEFT) != 0, right = (st->anchor & ANCHOR_RIGHT) != 0;
    int top = (st->anchor & ANCHOR_TOP) != 0, bottom = (st->anchor & ANCHOR_BOTTOM) != 0;

    /* A zero size stretches along the axis the surface is anchored on both
     * ends of; a client that asks for zero without anchoring both ends has
     * made a protocol error, which we answer with the whole output rather
     * than a disconnect. */
    int32_t w = (int32_t)st->desired_w, h = (int32_t)st->desired_h;
    if (w <= 0) w = (left && right) ? ow - st->margin_left - st->margin_right : ow;
    if (h <= 0) h = (top && bottom) ? oh - st->margin_top - st->margin_bottom : oh;
    if (w < 1) w = 1;
    if (h < 1) h = 1;

    memset(info, 0, sizeof(*info));
    info->output_index = ls->output_index;
    info->layer = st->layer;
    info->anchor = st->anchor;
    info->margin_top = st->margin_top;
    info->margin_right = st->margin_right;
    info->margin_bottom = st->margin_bottom;
    info->margin_left = st->margin_left;
    info->width = w;
    info->height = h;
    info->exclusive_zone = st->exclusive_zone;
    info->exclusive_edge = st->exclusive_zone > 0
        ? (st->exclusive_edge ? st->exclusive_edge : derive_exclusive_edge(st->anchor))
        : 0;
    info->keyboard_interactivity = st->keyboard_interactivity;
    snprintf(info->namespace_, sizeof(info->namespace_), "%s", ls->namespace_);
}

/* ========================================================================== */
/* zwlr_layer_surface_v1                                                      */
/* ========================================================================== */

static struct WaylandLayerSurface* ls_from(struct wl_resource* r) {
    return wl_resource_get_user_data(r);
}

static void ls_set_size(struct wl_client* c, struct wl_resource* r,
                        uint32_t w, uint32_t h) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    ls->pending.desired_w = w;
    ls->pending.desired_h = h;
}

static void ls_set_anchor(struct wl_client* c, struct wl_resource* r,
                          uint32_t anchor) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    if (anchor & ~ANCHOR_ALL) {
        wl_resource_post_error(r, ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_ANCHOR,
                               "invalid anchor %u", anchor);
        return;
    }
    ls->pending.anchor = anchor;
}

static void ls_set_exclusive_zone(struct wl_client* c, struct wl_resource* r,
                                  int32_t zone) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    ls->pending.exclusive_zone = zone;
}

static void ls_set_margin(struct wl_client* c, struct wl_resource* r,
                          int32_t top, int32_t right, int32_t bottom,
                          int32_t left) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    ls->pending.margin_top = top;
    ls->pending.margin_right = right;
    ls->pending.margin_bottom = bottom;
    ls->pending.margin_left = left;
}

static void ls_set_keyboard_interactivity(struct wl_client* c,
                                          struct wl_resource* r,
                                          uint32_t ki) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    if (ki > ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_ON_DEMAND) {
        wl_resource_post_error(r,
            ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_KEYBOARD_INTERACTIVITY,
            "invalid keyboard interactivity %u", ki);
        return;
    }
    ls->pending.keyboard_interactivity = ki;
}

static void ls_get_popup(struct wl_client* c, struct wl_resource* r,
                         struct wl_resource* popup) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls || !ls->surface || !popup) return;
    struct WaylandSurface* ps = wl_resource_get_user_data(popup);
    if (!ps) return;
    struct WaylandServer* server = ls->server;
    ps->parent_surface_id = ls->surface->id;
    /* The popup was made with a NULL parent and the shell has not heard of
     * it yet — now that it has a parent, it can be placed. */
    if (ps->popup_parent_pending) {
        ps->popup_parent_pending = 0;
        if (server->cb.on_new_popup) {
            server->cb.on_new_popup(server->cb_ctx, ps->id, ps->parent_surface_id,
                                    ps->popup_x, ps->popup_y,
                                    ps->popup_w, ps->popup_h);
        }
    }
}

static void ls_ack_configure(struct wl_client* c, struct wl_resource* r,
                             uint32_t serial) {
    (void)c; (void)r; (void)serial;
    /* Nothing to reconcile: the next commit carries the client's answer. */
}

static void ls_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void ls_set_layer(struct wl_client* c, struct wl_resource* r,
                         uint32_t layer) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    if (layer > ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY) {
        wl_resource_post_error(r, ZWLR_LAYER_SHELL_V1_ERROR_INVALID_LAYER,
                               "invalid layer %u", layer);
        return;
    }
    ls->pending.layer = layer;
}

static void ls_set_exclusive_edge(struct wl_client* c, struct wl_resource* r,
                                  uint32_t edge) {
    (void)c;
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    if (edge != 0 && edge != ANCHOR_TOP && edge != ANCHOR_BOTTOM &&
        edge != ANCHOR_LEFT && edge != ANCHOR_RIGHT) {
        wl_resource_post_error(r, ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_EXCLUSIVE_EDGE,
                               "exclusive edge must be one anchor");
        return;
    }
    ls->pending.exclusive_edge = edge;
}

static const struct zwlr_layer_surface_v1_interface layer_surface_impl = {
    .set_size = ls_set_size,
    .set_anchor = ls_set_anchor,
    .set_exclusive_zone = ls_set_exclusive_zone,
    .set_margin = ls_set_margin,
    .set_keyboard_interactivity = ls_set_keyboard_interactivity,
    .get_popup = ls_get_popup,
    .ack_configure = ls_ack_configure,
    .destroy = ls_destroy,
    .set_layer = ls_set_layer,
    .set_exclusive_edge = ls_set_exclusive_edge,
};

static void layer_surface_teardown(struct WaylandLayerSurface* ls) {
    struct WaylandServer* server = ls->server;
    if (ls->surface) {
        struct WaylandSurface* s = ls->surface;
        if (ls->announced) {
            wayland_output_send_leave(server, s);
            if (server->cb.on_layer_surface_destroy)
                server->cb.on_layer_surface_destroy(server->cb_ctx, s->id);
        }
        s->layer = NULL;
        ls->surface = NULL;
    }
    ls->announced = 0;
    ls->configured = 0;
}

/* Runs on explicit destroy AND on client disconnect. */
static void layer_surface_resource_destroyed(struct wl_resource* r) {
    struct WaylandLayerSurface* ls = ls_from(r);
    if (!ls) return;
    layer_surface_teardown(ls);
    wl_list_remove(&ls->link);
    free(ls);
}

/* ========================================================================== */
/* zwlr_layer_shell_v1                                                        */
/* ========================================================================== */

static void shell_get_layer_surface(struct wl_client* client,
                                    struct wl_resource* resource, uint32_t id,
                                    struct wl_resource* wl_surface,
                                    struct wl_resource* output, uint32_t layer,
                                    const char* namespace_) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (!surface) {
        wl_resource_post_error(resource, ZWLR_LAYER_SHELL_V1_ERROR_ROLE,
                               "unknown wl_surface");
        return;
    }
    if (surface->xdg_surface || surface->xdg_toplevel || surface->xdg_popup ||
        surface->layer || surface->is_subsurface) {
        wl_resource_post_error(resource, ZWLR_LAYER_SHELL_V1_ERROR_ROLE,
                               "wl_surface already has a role");
        return;
    }
    if (layer > ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY) {
        wl_resource_post_error(resource, ZWLR_LAYER_SHELL_V1_ERROR_INVALID_LAYER,
                               "invalid layer %u", layer);
        return;
    }

    struct WaylandLayerSurface* ls = calloc(1, sizeof(*ls));
    if (!ls) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_layer_surface_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        free(ls);
        wl_client_post_no_memory(client);
        return;
    }
    ls->resource = r;
    ls->server = server;
    ls->surface = surface;
    ls->output_index = output ? wayland_output_index_of(server, output) : 0;
    if (ls->output_index < 0 || ls->output_index >= server->output_count)
        ls->output_index = 0;
    ls->pending.layer = layer;
    snprintf(ls->namespace_, sizeof(ls->namespace_), "%s", namespace_ ? namespace_ : "");
    wl_list_insert(&server->layer_surfaces, &ls->link);
    wl_resource_set_implementation(r, &layer_surface_impl, ls,
                                   layer_surface_resource_destroyed);
    surface->layer = ls;
    surface->had_role = 1;
}

static void shell_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_layer_shell_v1_interface layer_shell_impl = {
    .get_layer_surface = shell_get_layer_surface,
    .destroy = shell_destroy,
};

static void layer_shell_bind(struct wl_client* client, void* data,
                             uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_layer_shell_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &layer_shell_impl, data, NULL);
}

void wayland_layer_shell_init(struct WaylandServer* server) {
    wl_list_init(&server->layer_surfaces);
    server->layer_shell_global = wl_global_create(server->display,
        &zwlr_layer_shell_v1_interface, 5, server, layer_shell_bind);
}

/* ========================================================================== */
/* Commit + lifecycle hooks                                                   */
/* ========================================================================== */

void wayland_layer_shell_commit(struct WaylandServer* server,
                                struct WaylandSurface* surface) {
    struct WaylandLayerSurface* ls = surface->layer;
    if (!ls) return;

    /* The pending state is the whole struct: every request rewrites one
     * field of it, so applying is a copy. */
    ls->current = ls->pending;

    WaylandLayerSurfaceInfo info;
    layer_compute_info(server, ls, &info);

    /* The initial commit — no buffer yet — is answered with a configure;
     * later commits get one only when the size we ask for changed. A
     * surface lent here by another role was configured by that role. */
    int size_changed = info.width != ls->last_info.width ||
                       info.height != ls->last_info.height;
    if (ls->resource && (!ls->configured || size_changed)) {
        zwlr_layer_surface_v1_send_configure(ls->resource,
            wayland_server_next_serial(server),
            (uint32_t)info.width, (uint32_t)info.height);
    }
    ls->configured = 1;

    if (!ls->announced) {
        ls->announced = 1;
        ls->last_info = info;
        /* On its output from the start — a layer surface never moves. */
        wayland_server_surface_set_outputs(server, surface->id,
                                           1u << ls->output_index,
                                           1u << ls->output_index);
        if (server->cb.on_new_layer_surface)
            server->cb.on_new_layer_surface(server->cb_ctx, surface->id, &info);
    } else if (memcmp(&info, &ls->last_info, sizeof(info)) != 0) {
        ls->last_info = info;
        if (server->cb.on_layer_surface_changed)
            server->cb.on_layer_surface_changed(server->cb_ctx, surface->id, &info);
    }
}

/* The wl_surface died under the role object (legal: a client may destroy
 * them in either order). The role resource lives on, inert. */
void wayland_layer_shell_surface_destroyed(struct WaylandServer* server,
                                           struct WaylandSurface* surface) {
    (void)server;
    struct WaylandLayerSurface* ls = surface->layer;
    if (!ls) return;
    layer_surface_teardown(ls);
}

void wayland_layer_shell_output_removed(struct WaylandServer* server,
                                        int output_index) {
    struct WaylandLayerSurface* ls, *tmp;
    wl_list_for_each_safe(ls, tmp, &server->layer_surfaces, link) {
        if (ls->output_index != output_index || !ls->surface) continue;
        if (ls->resource) zwlr_layer_surface_v1_send_closed(ls->resource);
        layer_surface_teardown(ls);
    }
}

struct WaylandLayerSurface* wayland_layer_shell_adopt(struct WaylandServer* server,
                                                      struct WaylandSurface* surface,
                                                      int output_index, uint32_t layer,
                                                      uint32_t anchor,
                                                      uint32_t keyboard_interactivity,
                                                      const char* namespace_) {
    struct WaylandLayerSurface* ls = calloc(1, sizeof(*ls));
    if (!ls) return NULL;
    ls->server = server;
    ls->surface = surface;
    ls->output_index = (output_index >= 0 && output_index < server->output_count)
                           ? output_index : 0;
    ls->pending.layer = layer;
    ls->pending.anchor = anchor;
    ls->pending.keyboard_interactivity = keyboard_interactivity;
    ls->pending.exclusive_zone = -1;
    snprintf(ls->namespace_, sizeof(ls->namespace_), "%s", namespace_ ? namespace_ : "");
    wl_list_insert(&server->layer_surfaces, &ls->link);
    surface->layer = ls;
    surface->had_role = 1;
    return ls;
}

void wayland_layer_shell_release(struct WaylandLayerSurface* ls) {
    if (!ls) return;
    layer_surface_teardown(ls);
    wl_list_remove(&ls->link);
    free(ls);
}
