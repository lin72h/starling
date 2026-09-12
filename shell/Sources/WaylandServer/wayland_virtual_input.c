// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_virtual_input.c — zwlr_virtual_pointer_v1 and zwp_virtual_keyboard_v1
 *
 * Input from a client instead of a device: wtype and ydotool typing,
 * wayvnc and remote-control agents moving the pointer. It joins the same
 * stream as the real mouse and keyboard — the shell feeds it to the engine
 * (fl_drm_view_inject_pointer_abs) and its own key router, so the desktop's
 * chrome, chords and clients see no difference.
 *
 * A virtual pointer accumulates a frame (motion, buttons, wheel) and hands
 * it over on `frame`. A virtual keyboard brings its own xkb keymap; every
 * key is decoded through it here, so the shell receives what it would from
 * a physical key: the evdev code, the keysym, the text.
 */

#include "wayland_server_internal.h"
#include "wlr-virtual-pointer-unstable-v1-protocol.h"
#include "virtual-keyboard-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <xkbcommon/xkbcommon.h>

/* --- pointer -------------------------------------------------------------- */

struct VirtualPointer {
    struct WaylandServer* server;
    int output_index;
    double dx, dy;
    int has_abs;
    double ax, ay;
    uint32_t buttons;                    /* Flutter mask */
    double wheel_dx, wheel_dy;
    int dirty;
};

static void vp_motion(struct wl_client* c, struct wl_resource* r, uint32_t time,
                      wl_fixed_t dx, wl_fixed_t dy) {
    (void)c; (void)time;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp) return;
    vp->dx += wl_fixed_to_double(dx);
    vp->dy += wl_fixed_to_double(dy);
    vp->dirty = 1;
}

static void vp_motion_absolute(struct wl_client* c, struct wl_resource* r, uint32_t time,
                               uint32_t x, uint32_t y, uint32_t x_extent, uint32_t y_extent) {
    (void)c; (void)time;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp || x_extent == 0 || y_extent == 0) return;
    vp->has_abs = 1;
    vp->ax = (double)x / (double)x_extent;
    vp->ay = (double)y / (double)y_extent;
    vp->dirty = 1;
}

static void vp_button(struct wl_client* c, struct wl_resource* r, uint32_t time,
                      uint32_t button, uint32_t state) {
    (void)c; (void)time;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp) return;
    uint32_t bit = 0;
    switch (button) {
        case 0x110: bit = 1; break;   /* BTN_LEFT   → primary */
        case 0x111: bit = 2; break;   /* BTN_RIGHT  → secondary */
        case 0x112: bit = 4; break;   /* BTN_MIDDLE → middle */
        default: return;
    }
    if (state) vp->buttons |= bit; else vp->buttons &= ~bit;
    vp->dirty = 1;
}

static void vp_axis(struct wl_client* c, struct wl_resource* r, uint32_t time,
                    uint32_t axis, wl_fixed_t value) {
    (void)c; (void)time;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp) return;
    /* wl_pointer.axis units are ~10 per wheel notch; Flutter's ~20. */
    double v = wl_fixed_to_double(value) * 2.0;
    if (axis == 0) vp->wheel_dy += v; else vp->wheel_dx += v;
    vp->dirty = 1;
}

static void vp_frame(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp || !vp->dirty) return;
    struct WaylandServer* server = vp->server;
    if (server->cb.on_virtual_pointer) {
        server->cb.on_virtual_pointer(server->cb_ctx, vp->output_index, vp->has_abs,
                                      vp->ax, vp->ay, vp->dx, vp->dy, vp->buttons,
                                      vp->wheel_dx, vp->wheel_dy);
    }
    vp->dx = vp->dy = 0;
    vp->has_abs = 0;
    vp->wheel_dx = vp->wheel_dy = 0;
    vp->dirty = 0;
}

static void vp_axis_source(struct wl_client* c, struct wl_resource* r, uint32_t source) {
    (void)c; (void)r; (void)source;
}

static void vp_axis_stop(struct wl_client* c, struct wl_resource* r, uint32_t time, uint32_t axis) {
    (void)c; (void)r; (void)time; (void)axis;
}

static void vp_axis_discrete(struct wl_client* c, struct wl_resource* r, uint32_t time,
                             uint32_t axis, wl_fixed_t value, int32_t discrete) {
    (void)c; (void)time; (void)value;
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp) return;
    double v = discrete * 20.0;
    if (axis == 0) vp->wheel_dy += v; else vp->wheel_dx += v;
    vp->dirty = 1;
}

static void vp_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_virtual_pointer_v1_interface vp_impl = {
    .motion = vp_motion,
    .motion_absolute = vp_motion_absolute,
    .button = vp_button,
    .axis = vp_axis,
    .frame = vp_frame,
    .axis_source = vp_axis_source,
    .axis_stop = vp_axis_stop,
    .axis_discrete = vp_axis_discrete,
    .destroy = vp_destroy,
};

static void vp_resource_destroyed(struct wl_resource* r) {
    struct VirtualPointer* vp = wl_resource_get_user_data(r);
    if (!vp) return;
    /* A pointer that dies with a button down releases it. */
    if (vp->buttons && vp->server->cb.on_virtual_pointer) {
        vp->server->cb.on_virtual_pointer(vp->server->cb_ctx, vp->output_index, 0,
                                          0, 0, 0, 0, 0, 0, 0);
    }
    free(vp);
}

static void vpm_create(struct wl_client* client, struct wl_resource* resource, uint32_t id,
                       struct wl_resource* seat, struct wl_resource* output) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct VirtualPointer* vp = calloc(1, sizeof(*vp));
    if (!vp) {
        wl_client_post_no_memory(client);
        return;
    }
    vp->server = server;
    vp->output_index = output ? wayland_output_index_of(server, output) : 0;
    if (vp->output_index < 0) vp->output_index = 0;
    struct wl_resource* r = wl_resource_create(client, &zwlr_virtual_pointer_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(vp);
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &vp_impl, vp, vp_resource_destroyed);
}

static void vpm_create_virtual_pointer(struct wl_client* client, struct wl_resource* resource,
                                       struct wl_resource* seat, uint32_t id) {
    vpm_create(client, resource, id, seat, NULL);
}

static void vpm_create_with_output(struct wl_client* client, struct wl_resource* resource,
                                   struct wl_resource* seat, struct wl_resource* output,
                                   uint32_t id) {
    vpm_create(client, resource, id, seat, output);
}

static void vpm_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_virtual_pointer_manager_v1_interface vpm_impl = {
    .create_virtual_pointer = vpm_create_virtual_pointer,
    .destroy = vpm_destroy,
    .create_virtual_pointer_with_output = vpm_create_with_output,
};

static void vpm_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_virtual_pointer_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &vpm_impl, data, NULL);
}

/* --- keyboard ------------------------------------------------------------- */

struct VirtualKeyboard {
    struct WaylandServer* server;
    struct xkb_context* ctx;
    struct xkb_keymap* keymap;
    struct xkb_state* state;
};

static void vk_keymap(struct wl_client* c, struct wl_resource* r, uint32_t format,
                      int32_t fd, uint32_t size) {
    (void)c;
    struct VirtualKeyboard* vk = wl_resource_get_user_data(r);
    if (!vk) {
        close(fd);
        return;
    }
    if (format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1 || size == 0) {
        close(fd);
        return;
    }
    void* map = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (map == MAP_FAILED) return;
    /* The map may not be NUL-terminated inside `size`: copy it out. */
    char* text = malloc((size_t)size + 1);
    if (text) {
        memcpy(text, map, size);
        text[size] = '\0';
    }
    munmap(map, size);
    if (!text) return;
    struct xkb_keymap* km = xkb_keymap_new_from_string(vk->ctx, text,
        XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
    free(text);
    if (!km) {
        fprintf(stderr, "[virtual_keyboard] keymap did not compile\n");
        return;
    }
    if (vk->state) xkb_state_unref(vk->state);
    if (vk->keymap) xkb_keymap_unref(vk->keymap);
    vk->keymap = km;
    vk->state = xkb_state_new(km);
}

static void vk_key(struct wl_client* c, struct wl_resource* r, uint32_t time,
                   uint32_t key, uint32_t state) {
    (void)c; (void)time;
    struct VirtualKeyboard* vk = wl_resource_get_user_data(r);
    if (!vk || !vk->state) return;
    xkb_keycode_t code = key + 8;
    uint32_t sym = xkb_state_key_get_one_sym(vk->state, code);
    char utf8[16] = "";
    if (state) xkb_state_key_get_utf8(vk->state, code, utf8, sizeof(utf8));
    xkb_state_update_key(vk->state, code, state ? XKB_KEY_DOWN : XKB_KEY_UP);
    struct WaylandServer* server = vk->server;
    if (server->cb.on_virtual_key)
        server->cb.on_virtual_key(server->cb_ctx, key, sym, utf8, state ? 1 : 0);
}

static void vk_modifiers(struct wl_client* c, struct wl_resource* r, uint32_t depressed,
                         uint32_t latched, uint32_t locked, uint32_t group) {
    (void)c;
    struct VirtualKeyboard* vk = wl_resource_get_user_data(r);
    if (!vk || !vk->state) return;
    xkb_state_update_mask(vk->state, depressed, latched, locked, 0, 0, group);
}

static void vk_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwp_virtual_keyboard_v1_interface vk_impl = {
    .keymap = vk_keymap,
    .key = vk_key,
    .modifiers = vk_modifiers,
    .destroy = vk_destroy,
};

static void vk_resource_destroyed(struct wl_resource* r) {
    struct VirtualKeyboard* vk = wl_resource_get_user_data(r);
    if (!vk) return;
    if (vk->state) xkb_state_unref(vk->state);
    if (vk->keymap) xkb_keymap_unref(vk->keymap);
    if (vk->ctx) xkb_context_unref(vk->ctx);
    free(vk);
}

static void vkm_create(struct wl_client* client, struct wl_resource* resource,
                       struct wl_resource* seat, uint32_t id) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct VirtualKeyboard* vk = calloc(1, sizeof(*vk));
    if (!vk) {
        wl_client_post_no_memory(client);
        return;
    }
    vk->server = server;
    vk->ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct wl_resource* r = wl_resource_create(client, &zwp_virtual_keyboard_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        if (vk->ctx) xkb_context_unref(vk->ctx);
        free(vk);
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &vk_impl, vk, vk_resource_destroyed);
}

static const struct zwp_virtual_keyboard_manager_v1_interface vkm_impl = {
    .create_virtual_keyboard = vkm_create,
};

static void vkm_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &zwp_virtual_keyboard_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &vkm_impl, data, NULL);
}

void wayland_virtual_input_init(struct WaylandServer* server) {
    server->virtual_pointer_manager_global = wl_global_create(server->display,
        &zwlr_virtual_pointer_manager_v1_interface, 2, server, vpm_bind);
    server->virtual_keyboard_manager_global = wl_global_create(server->display,
        &zwp_virtual_keyboard_manager_v1_interface, 1, server, vkm_bind);
}
