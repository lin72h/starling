// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_misc_protocols.c — the small protocols
 *
 * Each of these is an object a client creates, sets a hint on and destroys;
 * the compositor's whole job is to exist so the client can ask. Offering
 * them costs a few lines each and stops a toolkit from taking the "no
 * support" branch, which in several cases is the slower or uglier one:
 *
 *   wp_content_type_v1          "this surface is video/a game" — a hint
 *   wp_tearing_control_v1       a game asking for async page flips — a hint
 *   xdg_toplevel_tag_v1         a stable per-window tag (GTK 4.18 sets it)
 *   xdg_wm_dialog_v1            "this toplevel is a modal dialog"
 *   xdg_system_bell_v1          the terminal bell, routed to the shell
 *   xdg_toplevel_icon_v1        a window icon (name or buffers); accepted
 *   zwp_keyboard_shortcuts_inhibit_manager_v1
 *                               a VM viewer or VNC client asking for every
 *                               key, chords included; granted and queryable
 *   zwp_pointer_gestures_v1     swipe/pinch/hold objects that never fire —
 *                               the desktop has no touchpad gesture source
 *   zwp_tablet_manager_v2       a tablet seat with no tablets on it
 */

#include "wayland_server_internal.h"
#include "content-type-v1-protocol.h"
#include "tearing-control-v1-protocol.h"
#include "xdg-toplevel-tag-v1-protocol.h"
#include "xdg-dialog-v1-protocol.h"
#include "xdg-system-bell-v1-protocol.h"
#include "xdg-toplevel-icon-v1-protocol.h"
#include "keyboard-shortcuts-inhibit-unstable-v1-protocol.h"
#include "pointer-gestures-unstable-v1-protocol.h"
#include "tablet-v2-protocol.h"
#include <stdlib.h>

/* The shape every "object with a destroy request" takes. */
static void destroy_request(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

/* Creating a child object whose only state is its existence. */
static struct wl_resource* child_create(struct wl_client* client,
                                        struct wl_resource* parent,
                                        const struct wl_interface* iface,
                                        uint32_t id, const void* impl,
                                        void* data) {
    struct wl_resource* r = wl_resource_create(client, iface,
        wl_resource_get_version(parent), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return NULL;
    }
    wl_resource_set_implementation(r, impl, data, NULL);
    return r;
}

#define SIMPLE_BIND(fn, iface, impl)                                          \
    static void fn(struct wl_client* client, void* data, uint32_t version,    \
                   uint32_t id) {                                             \
        struct wl_resource* r = wl_resource_create(client, &iface, version, id); \
        if (!r) { wl_client_post_no_memory(client); return; }                 \
        wl_resource_set_implementation(r, &impl, data, NULL);                 \
    }

/* ========================================================================== */
/* wp_content_type_manager_v1                                                 */
/* ========================================================================== */

static void content_type_set(struct wl_client* c, struct wl_resource* r,
                             uint32_t type) {
    (void)c; (void)r; (void)type;
}

static const struct wp_content_type_v1_interface content_type_impl = {
    .destroy = destroy_request,
    .set_content_type = content_type_set,
};

static void content_type_get(struct wl_client* client, struct wl_resource* r,
                             uint32_t id, struct wl_resource* surface) {
    (void)surface;
    child_create(client, r, &wp_content_type_v1_interface, id,
                 &content_type_impl, NULL);
}

static const struct wp_content_type_manager_v1_interface content_type_manager_impl = {
    .destroy = destroy_request,
    .get_surface_content_type = content_type_get,
};
SIMPLE_BIND(content_type_bind, wp_content_type_manager_v1_interface,
            content_type_manager_impl)

/* ========================================================================== */
/* wp_tearing_control_manager_v1                                              */
/* ========================================================================== */

static void tearing_set_hint(struct wl_client* c, struct wl_resource* r,
                             uint32_t hint) {
    (void)c; (void)r; (void)hint;
}

static const struct wp_tearing_control_v1_interface tearing_impl = {
    .set_presentation_hint = tearing_set_hint,
    .destroy = destroy_request,
};

static void tearing_get(struct wl_client* client, struct wl_resource* r,
                        uint32_t id, struct wl_resource* surface) {
    (void)surface;
    child_create(client, r, &wp_tearing_control_v1_interface, id,
                 &tearing_impl, NULL);
}

static const struct wp_tearing_control_manager_v1_interface tearing_manager_impl = {
    .destroy = destroy_request,
    .get_tearing_control = tearing_get,
};
SIMPLE_BIND(tearing_bind, wp_tearing_control_manager_v1_interface,
            tearing_manager_impl)

/* ========================================================================== */
/* xdg_toplevel_tag_manager_v1                                                */
/* ========================================================================== */

static void tag_set(struct wl_client* c, struct wl_resource* r,
                    struct wl_resource* toplevel, const char* tag) {
    (void)c; (void)r; (void)toplevel; (void)tag;
}

static void tag_set_description(struct wl_client* c, struct wl_resource* r,
                                struct wl_resource* toplevel,
                                const char* description) {
    (void)c; (void)r; (void)toplevel; (void)description;
}

static const struct xdg_toplevel_tag_manager_v1_interface tag_manager_impl = {
    .destroy = destroy_request,
    .set_toplevel_tag = tag_set,
    .set_toplevel_description = tag_set_description,
};
SIMPLE_BIND(tag_bind, xdg_toplevel_tag_manager_v1_interface, tag_manager_impl)

/* ========================================================================== */
/* xdg_wm_dialog_v1                                                           */
/* ========================================================================== */

static void dialog_set_modal(struct wl_client* c, struct wl_resource* r) {
    (void)c; (void)r;
}

static void dialog_unset_modal(struct wl_client* c, struct wl_resource* r) {
    (void)c; (void)r;
}

static const struct xdg_dialog_v1_interface dialog_impl = {
    .destroy = destroy_request,
    .set_modal = dialog_set_modal,
    .unset_modal = dialog_unset_modal,
};

static void dialog_get(struct wl_client* client, struct wl_resource* r,
                       uint32_t id, struct wl_resource* toplevel) {
    (void)toplevel;
    child_create(client, r, &xdg_dialog_v1_interface, id, &dialog_impl, NULL);
}

static const struct xdg_wm_dialog_v1_interface wm_dialog_impl = {
    .destroy = destroy_request,
    .get_xdg_dialog = dialog_get,
};
SIMPLE_BIND(dialog_bind, xdg_wm_dialog_v1_interface, wm_dialog_impl)

/* ========================================================================== */
/* xdg_system_bell_v1                                                         */
/* ========================================================================== */

static void bell_ring(struct wl_client* c, struct wl_resource* r,
                      struct wl_resource* surface) {
    (void)c;
    struct WaylandServer* server = wl_resource_get_user_data(r);
    struct WaylandSurface* s = surface ? wl_resource_get_user_data(surface) : NULL;
    if (server->cb.on_system_bell)
        server->cb.on_system_bell(server->cb_ctx, s ? s->id : 0);
}

static const struct xdg_system_bell_v1_interface bell_impl = {
    .destroy = destroy_request,
    .ring = bell_ring,
};
SIMPLE_BIND(bell_bind, xdg_system_bell_v1_interface, bell_impl)

/* ========================================================================== */
/* xdg_toplevel_icon_manager_v1                                               */
/* ========================================================================== */

static void icon_set_name(struct wl_client* c, struct wl_resource* r,
                          const char* name) {
    (void)c; (void)r; (void)name;
}

static void icon_add_buffer(struct wl_client* c, struct wl_resource* r,
                            struct wl_resource* buffer, int32_t scale) {
    (void)c; (void)r; (void)buffer; (void)scale;
}

static const struct xdg_toplevel_icon_v1_interface icon_impl = {
    .destroy = destroy_request,
    .set_name = icon_set_name,
    .add_buffer = icon_add_buffer,
};

static void icon_create(struct wl_client* client, struct wl_resource* r,
                        uint32_t id) {
    child_create(client, r, &xdg_toplevel_icon_v1_interface, id, &icon_impl, NULL);
}

static void icon_set(struct wl_client* c, struct wl_resource* r,
                     struct wl_resource* toplevel, struct wl_resource* icon) {
    (void)c; (void)r; (void)toplevel; (void)icon;
    /* The dock draws the app's registry icon, which is the one a user
     * recognises; a per-window icon would have to be decoded from the
     * client's buffers to matter. Accepted so the toolkit's set_icon path
     * succeeds. */
}

static const struct xdg_toplevel_icon_manager_v1_interface icon_manager_impl = {
    .destroy = destroy_request,
    .create_icon = icon_create,
    .set_icon = icon_set,
};

static void icon_manager_bind(struct wl_client* client, void* data,
                              uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &xdg_toplevel_icon_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &icon_manager_impl, data, NULL);
    /* The sizes the shell would draw at, so a client can pick buffers. */
    xdg_toplevel_icon_manager_v1_send_icon_size(r, 32);
    xdg_toplevel_icon_manager_v1_send_icon_size(r, 64);
    xdg_toplevel_icon_manager_v1_send_done(r);
}

/* ========================================================================== */
/* zwp_keyboard_shortcuts_inhibit_manager_v1                                  */
/* ========================================================================== */

static void inhibitor_resource_destroyed(struct wl_resource* r) {
    struct WaylandShortcutsInhibitor* in = wl_resource_get_user_data(r);
    if (!in) return;
    if (in->surface) {
        struct WaylandServer* server = in->surface->server;
        wl_list_remove(&in->link);
        /* Still inhibited if another inhibitor names the same surface. */
        if (server->cb.on_shortcuts_inhibit &&
            !wayland_server_shortcuts_inhibited(server, in->surface->id)) {
            server->cb.on_shortcuts_inhibit(server->cb_ctx, in->surface->id, 0);
        }
    } else {
        wl_list_remove(&in->link);
    }
    free(in);
}

static const struct zwp_keyboard_shortcuts_inhibitor_v1_interface inhibitor_impl = {
    .destroy = destroy_request,
};

static void inhibit_shortcuts(struct wl_client* client, struct wl_resource* r,
                              uint32_t id, struct wl_resource* surface,
                              struct wl_resource* seat) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(r);
    struct WaylandSurface* s = surface ? wl_resource_get_user_data(surface) : NULL;
    struct WaylandShortcutsInhibitor* in = calloc(1, sizeof(*in));
    if (!in) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* res = wl_resource_create(client,
        &zwp_keyboard_shortcuts_inhibitor_v1_interface,
        wl_resource_get_version(r), id);
    if (!res) {
        free(in);
        wl_client_post_no_memory(client);
        return;
    }
    in->resource = res;
    in->surface = s;
    wl_list_insert(&server->shortcuts_inhibitors, &in->link);
    wl_resource_set_implementation(res, &inhibitor_impl, in,
                                   inhibitor_resource_destroyed);
    /* Granted at once: the shell hears on_shortcuts_inhibit and forwards
     * every key to the surface from here on, so the grant is real. */
    zwp_keyboard_shortcuts_inhibitor_v1_send_active(res);
    if (s && server->cb.on_shortcuts_inhibit)
        server->cb.on_shortcuts_inhibit(server->cb_ctx, s->id, 1);
}

static const struct zwp_keyboard_shortcuts_inhibit_manager_v1_interface
    shortcuts_manager_impl = {
    .destroy = destroy_request,
    .inhibit_shortcuts = inhibit_shortcuts,
};
SIMPLE_BIND(shortcuts_bind, zwp_keyboard_shortcuts_inhibit_manager_v1_interface,
            shortcuts_manager_impl)

void wayland_shortcuts_inhibit_init(struct WaylandServer* server) {
    wl_list_init(&server->shortcuts_inhibitors);
    server->shortcuts_inhibit_global = wl_global_create(server->display,
        &zwp_keyboard_shortcuts_inhibit_manager_v1_interface, 1, server,
        shortcuts_bind);
}

void wayland_shortcuts_inhibit_surface_destroyed(struct WaylandServer* server,
                                                 struct WaylandSurface* surface) {
    struct WaylandShortcutsInhibitor* in;
    int had = 0;
    wl_list_for_each(in, &server->shortcuts_inhibitors, link) {
        if (in->surface == surface) {
            in->surface = NULL;
            had = 1;
        }
    }
    if (had && server->cb.on_shortcuts_inhibit)
        server->cb.on_shortcuts_inhibit(server->cb_ctx, surface->id, 0);
}

int wayland_server_shortcuts_inhibited(WaylandServer* server, uint32_t surface_id) {
    if (!server) return 0;
    struct WaylandShortcutsInhibitor* in;
    wl_list_for_each(in, &server->shortcuts_inhibitors, link) {
        if (in->surface && in->surface->id == surface_id) return 1;
    }
    return 0;
}

/* ========================================================================== */
/* zwp_pointer_gestures_v1                                                    */
/* ========================================================================== */

static const struct zwp_pointer_gesture_swipe_v1_interface swipe_impl = {
    .destroy = destroy_request,
};
static const struct zwp_pointer_gesture_pinch_v1_interface pinch_impl = {
    .destroy = destroy_request,
};
static const struct zwp_pointer_gesture_hold_v1_interface hold_impl = {
    .destroy = destroy_request,
};

static void gestures_get_swipe(struct wl_client* client, struct wl_resource* r,
                               uint32_t id, struct wl_resource* pointer) {
    (void)pointer;
    child_create(client, r, &zwp_pointer_gesture_swipe_v1_interface, id,
                 &swipe_impl, NULL);
}

static void gestures_get_pinch(struct wl_client* client, struct wl_resource* r,
                               uint32_t id, struct wl_resource* pointer) {
    (void)pointer;
    child_create(client, r, &zwp_pointer_gesture_pinch_v1_interface, id,
                 &pinch_impl, NULL);
}

static void gestures_get_hold(struct wl_client* client, struct wl_resource* r,
                              uint32_t id, struct wl_resource* pointer) {
    (void)pointer;
    child_create(client, r, &zwp_pointer_gesture_hold_v1_interface, id,
                 &hold_impl, NULL);
}

static const struct zwp_pointer_gestures_v1_interface gestures_impl = {
    .get_swipe_gesture = gestures_get_swipe,
    .get_pinch_gesture = gestures_get_pinch,
    .release = destroy_request,
    .get_hold_gesture = gestures_get_hold,
};
SIMPLE_BIND(gestures_bind, zwp_pointer_gestures_v1_interface, gestures_impl)

void wayland_pointer_gestures_init(struct WaylandServer* server) {
    server->pointer_gestures_global = wl_global_create(server->display,
        &zwp_pointer_gestures_v1_interface, 3, server, gestures_bind);
}

/* ========================================================================== */
/* zwp_tablet_manager_v2                                                      */
/* ========================================================================== */

static const struct zwp_tablet_seat_v2_interface tablet_seat_impl = {
    .destroy = destroy_request,
};

static void tablet_get_seat(struct wl_client* client, struct wl_resource* r,
                            uint32_t id, struct wl_resource* seat) {
    (void)seat;
    child_create(client, r, &zwp_tablet_seat_v2_interface, id,
                 &tablet_seat_impl, NULL);
}

static const struct zwp_tablet_manager_v2_interface tablet_manager_impl = {
    .get_tablet_seat = tablet_get_seat,
    .destroy = destroy_request,
};
SIMPLE_BIND(tablet_bind, zwp_tablet_manager_v2_interface, tablet_manager_impl)

void wayland_tablet_init(struct WaylandServer* server) {
    server->tablet_manager_global = wl_global_create(server->display,
        &zwp_tablet_manager_v2_interface, 1, server, tablet_bind);
}

/* ========================================================================== */
/* The hint protocols' globals                                                */
/* ========================================================================== */

void wayland_misc_protocols_init(struct WaylandServer* server) {
    server->content_type_global = wl_global_create(server->display,
        &wp_content_type_manager_v1_interface, 1, server, content_type_bind);
    server->tearing_control_global = wl_global_create(server->display,
        &wp_tearing_control_manager_v1_interface, 1, server, tearing_bind);
    server->toplevel_tag_global = wl_global_create(server->display,
        &xdg_toplevel_tag_manager_v1_interface, 1, server, tag_bind);
    server->xdg_dialog_global = wl_global_create(server->display,
        &xdg_wm_dialog_v1_interface, 1, server, dialog_bind);
    server->system_bell_global = wl_global_create(server->display,
        &xdg_system_bell_v1_interface, 1, server, bell_bind);
    server->toplevel_icon_global = wl_global_create(server->display,
        &xdg_toplevel_icon_manager_v1_interface, 1, server, icon_manager_bind);
}
