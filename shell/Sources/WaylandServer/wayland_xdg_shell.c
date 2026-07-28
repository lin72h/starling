// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#include "wayland_server_internal.h"
#include "xdg-shell-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ==========================================================================
 * xdg_positioner — stub implementation (needed for protocol compliance)
 * ========================================================================== */

/* Resource destructor — frees the positioner when the resource is destroyed
 * (either via explicit destroy request or client disconnect). */
static void positioner_resource_destroy(struct wl_resource* resource) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    free(pos);
}

static void positioner_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);  /* triggers positioner_resource_destroy */
}

static void positioner_set_size(struct wl_client* client,
                                struct wl_resource* resource,
                                int32_t width, int32_t height) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    if (pos) { pos->width = width; pos->height = height; }
}

static void positioner_set_anchor_rect(struct wl_client* client,
                                       struct wl_resource* resource,
                                       int32_t x, int32_t y,
                                       int32_t width, int32_t height) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    if (pos) { pos->anchor_x = x; pos->anchor_y = y; pos->anchor_w = width; pos->anchor_h = height; }
}

static void positioner_set_anchor(struct wl_client* client,
                                  struct wl_resource* resource,
                                  uint32_t anchor) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    if (pos) { pos->anchor = anchor; }
}

static void positioner_set_gravity(struct wl_client* client,
                                   struct wl_resource* resource,
                                   uint32_t gravity) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    if (pos) { pos->gravity = gravity; }
}

static void positioner_set_constraint_adjustment(struct wl_client* client,
                                                 struct wl_resource* resource,
                                                 uint32_t constraint_adjustment) {
    /* ignored — we don't constrain popups */
}

static void positioner_set_offset(struct wl_client* client,
                                  struct wl_resource* resource,
                                  int32_t x, int32_t y) {
    struct WaylandPositioner* pos = wl_resource_get_user_data(resource);
    if (pos) { pos->offset_x = x; pos->offset_y = y; }
}

static void positioner_set_reactive(struct wl_client* client,
                                    struct wl_resource* resource) {
    /* ignored */
}

static void positioner_set_parent_size(struct wl_client* client,
                                       struct wl_resource* resource,
                                       int32_t parent_width,
                                       int32_t parent_height) {
    /* ignored */
}

static void positioner_set_parent_configure(struct wl_client* client,
                                            struct wl_resource* resource,
                                            uint32_t serial) {
    /* ignored */
}

/* Compute popup position from positioner data.
 * Uses anchor rect center + gravity + offset (simplified). */
static void positioner_compute_position(const struct WaylandPositioner* pos,
                                         int32_t* out_x, int32_t* out_y) {
    /* Start at anchor rect position. Apply anchor edge to find the anchor point. */
    int32_t ax = pos->anchor_x;
    int32_t ay = pos->anchor_y;

    /* Anchor: 0=none(center), 1=top, 2=bottom, 3=left, 4=right,
     * 5=top-left, 6=bottom-left, 7=top-right, 8=bottom-right */
    if (pos->anchor == 2 || pos->anchor == 6 || pos->anchor == 8)
        ay += pos->anchor_h;
    else if (pos->anchor == 0 || pos->anchor == 3 || pos->anchor == 4)
        ay += pos->anchor_h / 2;

    if (pos->anchor == 4 || pos->anchor == 7 || pos->anchor == 8)
        ax += pos->anchor_w;
    else if (pos->anchor == 0 || pos->anchor == 1 || pos->anchor == 2)
        ax += pos->anchor_w / 2;

    /* Gravity: where the popup grows from the anchor point.
     * Same enum as anchor. Default (0/none) = bottom-right growth. */
    if (pos->gravity == 1 || pos->gravity == 5 || pos->gravity == 7)
        ay -= pos->height;
    else if (pos->gravity == 0 || pos->gravity == 3 || pos->gravity == 4)
        ay -= pos->height / 2;

    if (pos->gravity == 3 || pos->gravity == 5 || pos->gravity == 6)
        ax -= pos->width;
    else if (pos->gravity == 0 || pos->gravity == 1 || pos->gravity == 2)
        ax -= pos->width / 2;

    *out_x = ax + pos->offset_x;
    *out_y = ay + pos->offset_y;
}

static const struct xdg_positioner_interface xdg_positioner_impl = {
    .destroy = positioner_destroy,
    .set_size = positioner_set_size,
    .set_anchor_rect = positioner_set_anchor_rect,
    .set_anchor = positioner_set_anchor,
    .set_gravity = positioner_set_gravity,
    .set_constraint_adjustment = positioner_set_constraint_adjustment,
    .set_offset = positioner_set_offset,
    .set_reactive = positioner_set_reactive,
    .set_parent_size = positioner_set_parent_size,
    .set_parent_configure = positioner_set_parent_configure,
};

/* ==========================================================================
 * xdg_toplevel
 * ========================================================================== */

static void xdg_toplevel_destroy_handler(struct wl_client* client,
                                         struct wl_resource* resource) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (surface) {
        struct WaylandServer* server = surface->server;
        /* Unmapping: the surface leaves the output. */
        wayland_output_send_leave(server, surface);
        if (server->cb.on_toplevel_destroy) {
            server->cb.on_toplevel_destroy(server->cb_ctx,
                                               surface->id);
        }
        surface->xdg_toplevel = NULL;
    }
    wl_resource_destroy(resource);
}

static void xdg_toplevel_set_parent_handler(struct wl_client* client,
                                            struct wl_resource* resource,
                                            struct wl_resource* parent) {
    /* stub — we don't track parent-child relationships yet */
}

static void xdg_toplevel_set_title_handler(struct wl_client* client,
                                           struct wl_resource* resource,
                                           const char* title) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;

    snprintf(surface->title, sizeof(surface->title), "%s", title);

    struct WaylandServer* server = surface->server;
    if (server->cb.on_title_changed) {
        server->cb.on_title_changed(server->cb_ctx,
                                        surface->id, title);
    }
}

static void xdg_toplevel_set_app_id_handler(struct wl_client* client,
                                            struct wl_resource* resource,
                                            const char* app_id) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;

    snprintf(surface->app_id, sizeof(surface->app_id), "%s", app_id);

    struct WaylandServer* server = surface->server;
    if (server->cb.on_app_id_changed) {
        server->cb.on_app_id_changed(server->cb_ctx,
                                         surface->id, app_id);
    }
}

static void xdg_toplevel_show_window_menu_handler(struct wl_client* client,
                                                   struct wl_resource* resource,
                                                   struct wl_resource* seat,
                                                   uint32_t serial,
                                                   int32_t x, int32_t y) {
    /* stub — we don't support window menus */
}

static void xdg_toplevel_move_handler(struct wl_client* client,
                                      struct wl_resource* resource,
                                      struct wl_resource* seat,
                                      uint32_t serial) {
    (void)client; (void)seat; (void)serial;
    /* Client asks the compositor to take over a pointer drag as a window
     * move (CSD titlebar drag, Chrome tab-strip drag). The shell diverts
     * subsequent pointer motion into window movement until button release.
     * Serial is not validated — the request only arrives mid-grab anyway. */
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    struct WaylandServer* server = surface->server;
    if (server->cb.on_move_request) {
        server->cb.on_move_request(server->cb_ctx, surface->id);
    }
}

static void xdg_toplevel_resize_handler(struct wl_client* client,
                                        struct wl_resource* resource,
                                        struct wl_resource* seat,
                                        uint32_t serial,
                                        uint32_t edges) {
    (void)client; (void)seat; (void)serial;
    /* Same as move, but resizing from the given edge/corner. */
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    struct WaylandServer* server = surface->server;
    if (server->cb.on_interactive_resize_request) {
        server->cb.on_interactive_resize_request(server->cb_ctx,
                                                 surface->id, edges);
    }
}

static void xdg_toplevel_set_max_size_handler(struct wl_client* client,
                                              struct wl_resource* resource,
                                              int32_t width, int32_t height) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;

    /* Store max size — the compositor may use this as a hint */
    struct WaylandServer* server = surface->server;
    if (server->cb.on_toplevel_resize_request) {
        server->cb.on_toplevel_resize_request(server->cb_ctx,
                                                  surface->id, width, height);
    }
}

static void xdg_toplevel_set_min_size_handler(struct wl_client* client,
                                              struct wl_resource* resource,
                                              int32_t width, int32_t height) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;

    /* Store min size — the compositor may use this as a hint */
    struct WaylandServer* server = surface->server;
    if (server->cb.on_toplevel_resize_request) {
        server->cb.on_toplevel_resize_request(server->cb_ctx,
                                                  surface->id, width, height);
    }
}

static void xdg_toplevel_set_maximized_handler(struct wl_client* client,
                                               struct wl_resource* resource) {
    /* stub */
}

static void xdg_toplevel_unset_maximized_handler(struct wl_client* client,
                                                 struct wl_resource* resource) {
    /* stub */
}

static void xdg_toplevel_set_fullscreen_handler(struct wl_client* client,
                                                struct wl_resource* resource,
                                                struct wl_resource* output) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;
    struct WaylandServer* server = surface->server;
    if (server->cb.on_fullscreen_request)
        server->cb.on_fullscreen_request(server->cb_ctx, surface->id);
}

static void xdg_toplevel_unset_fullscreen_handler(struct wl_client* client,
                                                  struct wl_resource* resource) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;
    struct WaylandServer* server = surface->server;
    if (server->cb.on_unfullscreen_request)
        server->cb.on_unfullscreen_request(server->cb_ctx, surface->id);
}

static void xdg_toplevel_set_minimized_handler(struct wl_client* client,
                                               struct wl_resource* resource) {
    /* stub */
}

static const struct xdg_toplevel_interface xdg_toplevel_impl = {
    .destroy = xdg_toplevel_destroy_handler,
    .set_parent = xdg_toplevel_set_parent_handler,
    .set_title = xdg_toplevel_set_title_handler,
    .set_app_id = xdg_toplevel_set_app_id_handler,
    .show_window_menu = xdg_toplevel_show_window_menu_handler,
    .move = xdg_toplevel_move_handler,
    .resize = xdg_toplevel_resize_handler,
    .set_max_size = xdg_toplevel_set_max_size_handler,
    .set_min_size = xdg_toplevel_set_min_size_handler,
    .set_maximized = xdg_toplevel_set_maximized_handler,
    .unset_maximized = xdg_toplevel_unset_maximized_handler,
    .set_fullscreen = xdg_toplevel_set_fullscreen_handler,
    .unset_fullscreen = xdg_toplevel_unset_fullscreen_handler,
    .set_minimized = xdg_toplevel_set_minimized_handler,
};

/* ==========================================================================
 * xdg_surface
 * ========================================================================== */

static void xdg_surface_destroy_handler(struct wl_client* client,
                                        struct wl_resource* resource) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (surface) {
        surface->xdg_surface = NULL;
    }
    wl_resource_destroy(resource);
}

static void xdg_surface_get_toplevel(struct wl_client* client,
                                      struct wl_resource* resource,
                                      uint32_t id) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    struct WaylandServer* server = surface->server;

    struct wl_resource* toplevel = wl_resource_create(client,
        &xdg_toplevel_interface, wl_resource_get_version(resource), id);
    if (!toplevel) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(toplevel, &xdg_toplevel_impl, surface, NULL);
    surface->xdg_toplevel = toplevel;
    surface->had_role = 1;

    /* The surface is (about to be) shown on our output. */
    wayland_output_send_enter(server, surface);

    /* Notify compositor of new toplevel — the Swift side will call
     * wayland_server_configure_toplevel() to send the initial configure
     * with the window's content area size. */
    if (server->cb.on_new_toplevel) {
        server->cb.on_new_toplevel(server->cb_ctx, surface->id,
                                   (uint64_t)(uintptr_t)client);
    }
    surface->initial_configure_sent = 1;
}

/* ==========================================================================
 * xdg_popup — minimal implementation so clients don't crash
 *
 * Popups (dropdown menus, tooltips, autocomplete) are created but not
 * composited as separate windows. We send the required configure events
 * so the client doesn't get a protocol error.
 * ========================================================================== */

static void xdg_popup_destroy_handler(struct wl_client* client,
                                       struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void xdg_popup_grab_handler(struct wl_client* client,
                                    struct wl_resource* resource,
                                    struct wl_resource* seat,
                                    uint32_t serial) {
    (void)client;
    (void)resource;
    (void)seat;
    (void)serial;
    /* No-op — we don't track popup grabs. */
}

static void xdg_popup_reposition_handler(struct wl_client* client,
                                          struct wl_resource* resource,
                                          struct wl_resource* positioner,
                                          uint32_t token) {
    (void)client;
    (void)resource;
    (void)positioner;
    (void)token;
}

static const struct xdg_popup_interface xdg_popup_impl = {
    .destroy = xdg_popup_destroy_handler,
    .grab = xdg_popup_grab_handler,
    .reposition = xdg_popup_reposition_handler,
};

static void xdg_popup_resource_destroy(struct wl_resource* resource) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;

    if (surface->xdg_popup == resource) {
        struct WaylandServer* server = surface->server;
        /* Unmapping: the surface leaves the output (Chrome reuses popup
         * wl_surfaces across shows, so pair every enter with a leave). */
        wayland_output_send_leave(server, surface);
        if (server->cb.on_popup_destroy) {
            server->cb.on_popup_destroy(server->cb_ctx, surface->id);
        }
        surface->xdg_popup = NULL;
    }
}

static void xdg_surface_get_popup_handler(struct wl_client* client,
                                          struct wl_resource* resource,
                                          uint32_t id,
                                          struct wl_resource* parent,
                                          struct wl_resource* positioner) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    struct WaylandServer* server = surface->server;

    /* Compute popup position from positioner. */
    int32_t popup_x = 0, popup_y = 0;
    int32_t popup_w = 200, popup_h = 200;
    struct WaylandPositioner* pos = positioner ? wl_resource_get_user_data(positioner) : NULL;
    if (pos) {
        positioner_compute_position(pos, &popup_x, &popup_y);
        if (pos->width > 0) popup_w = pos->width;
        if (pos->height > 0) popup_h = pos->height;
    }

    /* Find parent surface id. */
    uint32_t parent_id = 0;
    if (parent) {
        struct WaylandSurface* parent_surface = wl_resource_get_user_data(parent);
        if (parent_surface) parent_id = parent_surface->id;
    }

    /* Store popup state on the surface. */
    surface->parent_surface_id = parent_id;
    surface->popup_x = popup_x;
    surface->popup_y = popup_y;

    /* Create the xdg_popup resource. */
    struct wl_resource* popup = wl_resource_create(client,
        &xdg_popup_interface, wl_resource_get_version(resource), id);
    if (!popup) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(popup, &xdg_popup_impl, surface,
                                   xdg_popup_resource_destroy);
    surface->xdg_popup = popup;
    surface->had_role = 1;

    fprintf(stderr, "[WaylandServer] get_popup: surface=%u parent=%u pos=(%d,%d) size=(%d,%d)\n",
            surface->id, parent_id, popup_x, popup_y, popup_w, popup_h);

    /* Send popup configure with computed position and size. */
    xdg_popup_send_configure(popup, popup_x, popup_y, popup_w, popup_h);

    /* Send xdg_surface.configure to complete the initial configure sequence. */
    xdg_surface_send_configure(resource,
                                wayland_server_next_serial(server));

    /* Notify compositor of new popup. */
    if (server->cb.on_new_popup) {
        server->cb.on_new_popup(server->cb_ctx, surface->id,
                                     parent_id, popup_x, popup_y,
                                     popup_w, popup_h);
    }

    /* The popup surface is (about to be) shown on our output. */
    wayland_output_send_enter(server, surface);
}

static void xdg_surface_set_window_geometry_handler(struct wl_client* client,
                                                    struct wl_resource* resource,
                                                    int32_t x, int32_t y,
                                                    int32_t width, int32_t height) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;

    /* Double-buffered: store as pending, applied on wl_surface.commit. */
    surface->pending_geometry.x = x;
    surface->pending_geometry.y = y;
    surface->pending_geometry.width = width;
    surface->pending_geometry.height = height;
    surface->pending_geometry.set = 1;
}

static void xdg_surface_ack_configure_handler(struct wl_client* client,
                                              struct wl_resource* resource,
                                              uint32_t serial) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface)
        return;

    /* Mark surface as configured — client has acknowledged our configure */
    surface->pending_configure_serial = 0;
}

static const struct xdg_surface_interface xdg_surface_impl = {
    .destroy = xdg_surface_destroy_handler,
    .get_toplevel = xdg_surface_get_toplevel,
    .get_popup = xdg_surface_get_popup_handler,
    .set_window_geometry = xdg_surface_set_window_geometry_handler,
    .ack_configure = xdg_surface_ack_configure_handler,
};

/* ==========================================================================
 * xdg_wm_base
 * ========================================================================== */

static void xdg_wm_base_destroy_handler(struct wl_client* client,
                                        struct wl_resource* resource) {
    /* no-op cleanup */
}

static void xdg_wm_base_create_positioner_handler(struct wl_client* client,
                                                   struct wl_resource* resource,
                                                   uint32_t id) {
    struct WaylandPositioner* pos = calloc(1, sizeof(struct WaylandPositioner));
    if (!pos) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* positioner = wl_resource_create(client,
        &xdg_positioner_interface, wl_resource_get_version(resource), id);
    if (!positioner) {
        free(pos);
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(positioner, &xdg_positioner_impl, pos,
                                   positioner_resource_destroy);
}

static void xdg_wm_base_get_xdg_surface_handler(struct wl_client* client,
                                                 struct wl_resource* resource,
                                                 uint32_t id,
                                                 struct wl_resource* wl_surface) {
    struct WaylandSurface* surface = wl_resource_get_user_data(wl_surface);
    if (!surface) {
        fprintf(stderr, "wayland_xdg_shell: get_xdg_surface for unknown surface\n");
        return;
    }

    struct wl_resource* xdg_surface = wl_resource_create(client,
        &xdg_surface_interface, wl_resource_get_version(resource), id);
    if (!xdg_surface) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(xdg_surface, &xdg_surface_impl, surface, NULL);
    surface->xdg_surface = xdg_surface;
}

static void xdg_wm_base_pong_handler(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t serial) {
    /* Client responded to our ping — just log/ignore */
}

static const struct xdg_wm_base_interface xdg_wm_base_impl = {
    .destroy = xdg_wm_base_destroy_handler,
    .create_positioner = xdg_wm_base_create_positioner_handler,
    .get_xdg_surface = xdg_wm_base_get_xdg_surface_handler,
    .pong = xdg_wm_base_pong_handler,
};

/* ==========================================================================
 * Global bind
 * ========================================================================== */

static void xdg_wm_base_bind(struct wl_client* client, void* data,
                               uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &xdg_wm_base_interface, version, id);
    wl_resource_set_implementation(resource, &xdg_wm_base_impl, data, NULL);
}

void wayland_xdg_shell_init(struct WaylandServer* server) {
    server->xdg_wm_base_global = wl_global_create(server->display,
        &xdg_wm_base_interface, 5, server, xdg_wm_base_bind);
}
