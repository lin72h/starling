// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_seat.c — wl_seat, wl_pointer, and wl_keyboard implementation
 *
 * Implements the wl_seat global with pointer and keyboard capabilities.
 * Sends a default xkb keymap to keyboard clients via shared memory.
 */

#define _GNU_SOURCE
#include "wayland_server_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <xkbcommon/xkbcommon.h>

/* ========================================================================== */
/* wl_pointer                                                                 */
/* ========================================================================== */

static void pointer_set_cursor(struct wl_client* client,
                               struct wl_resource* resource,
                               uint32_t serial,
                               struct wl_resource* surface,
                               int32_t hotspot_x,
                               int32_t hotspot_y) {
    (void)client;
    (void)resource;
    (void)serial;
    (void)surface;
    (void)hotspot_x;
    (void)hotspot_y;
    /* Cursor surface handling not implemented — the compositor draws its own. */
}

static void input_resource_destroy(struct wl_resource* resource) {
    struct WaylandInputResource* ir = wl_resource_get_user_data(resource);
    if (ir) {
        wl_list_remove(&ir->link);
        free(ir);
    }
}

static void pointer_release(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

/*
 * wl_pointer requests (in protocol order):
 *   0  set_cursor
 *   1  release  (since v3)
 */
static const struct wl_pointer_interface pointer_impl = {
    .set_cursor = pointer_set_cursor,
    .release    = pointer_release,
};

/* ========================================================================== */
/* wl_keyboard                                                                */
/* ========================================================================== */

static void keyboard_release(struct wl_client* client,
                             struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

/*
 * wl_keyboard requests (in protocol order):
 *   0  release  (since v3)
 */
static const struct wl_keyboard_interface keyboard_impl = {
    .release = keyboard_release,
};

/* ========================================================================== */
/* Keymap helper                                                              */
/* ========================================================================== */

static void send_default_keymap(struct wl_resource* keyboard) {
    struct xkb_context* ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx) {
        fprintf(stderr, "wayland_seat: xkb_context_new failed\n");
        return;
    }

    struct xkb_keymap* keymap = xkb_keymap_new_from_names(ctx, NULL,
        XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!keymap) {
        fprintf(stderr, "wayland_seat: xkb_keymap_new_from_names failed\n");
        xkb_context_unref(ctx);
        return;
    }

    char* keymap_str = xkb_keymap_get_as_string(keymap,
        XKB_KEYMAP_FORMAT_TEXT_V1);
    if (!keymap_str) {
        fprintf(stderr, "wayland_seat: xkb_keymap_get_as_string failed\n");
        xkb_keymap_unref(keymap);
        xkb_context_unref(ctx);
        return;
    }

    size_t keymap_size = strlen(keymap_str) + 1;

    /* Create anonymous shared memory fd for the keymap string. */
    int fd = memfd_create("xkb-keymap", MFD_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "wayland_seat: memfd_create failed\n");
        free(keymap_str);
        xkb_keymap_unref(keymap);
        xkb_context_unref(ctx);
        return;
    }

    ftruncate(fd, keymap_size);
    void* ptr = mmap(NULL, keymap_size, PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        fprintf(stderr, "wayland_seat: mmap failed\n");
        close(fd);
        free(keymap_str);
        xkb_keymap_unref(keymap);
        xkb_context_unref(ctx);
        return;
    }
    memcpy(ptr, keymap_str, keymap_size);
    munmap(ptr, keymap_size);

    wl_keyboard_send_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,
                            fd, keymap_size);
    close(fd);

    free(keymap_str);
    xkb_keymap_unref(keymap);
    xkb_context_unref(ctx);
}

/* ========================================================================== */
/* wl_seat                                                                    */
/* ========================================================================== */

static void seat_get_pointer(struct wl_client* client,
                             struct wl_resource* resource, uint32_t id) {
    struct WaylandSeatDesc* desc = wl_resource_get_user_data(resource);
    struct WaylandServer* server = desc->server;
    struct wl_resource* pointer = wl_resource_create(client,
        &wl_pointer_interface, wl_resource_get_version(resource), id);
    if (!pointer) {
        wl_client_post_no_memory(client);
        return;
    }
    struct WaylandInputResource* ir = calloc(1, sizeof(*ir));
    if (!ir) {
        wl_resource_destroy(pointer);
        wl_client_post_no_memory(client);
        return;
    }
    ir->resource = pointer;
    ir->seat = desc->index;
    wl_list_insert(&server->pointer_resources, &ir->link);
    wl_resource_set_implementation(pointer, &pointer_impl, ir, input_resource_destroy);
}

static void seat_get_keyboard(struct wl_client* client,
                              struct wl_resource* resource, uint32_t id) {
    struct WaylandSeatDesc* desc = wl_resource_get_user_data(resource);
    struct WaylandServer* server = desc->server;
    struct wl_resource* keyboard = wl_resource_create(client,
        &wl_keyboard_interface, wl_resource_get_version(resource), id);
    if (!keyboard) {
        wl_client_post_no_memory(client);
        return;
    }
    struct WaylandInputResource* ir = calloc(1, sizeof(*ir));
    if (!ir) {
        wl_resource_destroy(keyboard);
        wl_client_post_no_memory(client);
        return;
    }
    ir->resource = keyboard;
    ir->seat = desc->index;
    wl_list_insert(&server->keyboard_resources, &ir->link);
    wl_resource_set_implementation(keyboard, &keyboard_impl, ir, input_resource_destroy);

    /* Send a minimal xkb keymap so the client can interpret key events. */
    send_default_keymap(keyboard);

    /* v4+: repeat_info is expected immediately after keymap; without it
     * Chrome/VS Code default to no key auto-repeat at all. */
    if (wl_resource_get_version(keyboard) >= 4) {
        wl_keyboard_send_repeat_info(keyboard, 25 /* keys/sec */, 400 /* delay ms */);
    }
}

/* Touch is not advertised in capabilities, but a client may still create the
 * object; a NULL implementation table would make its `release` request a
 * NULL-deref that kills the compositor. */
static void touch_release(struct wl_client* client,
                          struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct wl_touch_interface touch_impl = {
    .release = touch_release,
};

static void seat_get_touch(struct wl_client* client,
                           struct wl_resource* resource, uint32_t id) {
    (void)client;
    struct wl_resource* touch = wl_resource_create(
        wl_resource_get_client(resource),
        &wl_touch_interface, wl_resource_get_version(resource), id);
    if (!touch) {
        wl_client_post_no_memory(wl_resource_get_client(resource));
        return;
    }
    wl_resource_set_implementation(touch, &touch_impl, NULL, NULL);
}

static void seat_release(struct wl_client* client,
                         struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

/*
 * wl_seat requests (in protocol order):
 *   0  get_pointer
 *   1  get_keyboard
 *   2  get_touch
 *   3  release  (since v5)
 */
static const struct wl_seat_interface seat_impl = {
    .get_pointer  = seat_get_pointer,
    .get_keyboard = seat_get_keyboard,
    .get_touch    = seat_get_touch,
    .release      = seat_release,
};

static void seat_bind(struct wl_client* client, void* data,
                      uint32_t version, uint32_t id) {
    struct WaylandSeatDesc* desc = data;
    struct wl_resource* resource = wl_resource_create(client,
        &wl_seat_interface, version, id);
    wl_resource_set_implementation(resource, &seat_impl, desc, NULL);

    /* WL_SEAT_CAPABILITY_POINTER (1) | WL_SEAT_CAPABILITY_KEYBOARD (2) */
    wl_seat_send_capabilities(resource, 3);
    if (version >= 2) {
        wl_seat_send_name(resource, desc->index == 0 ? "seat0" : "seat-agent");
    }
}

void wayland_seat_init(struct WaylandServer* server) {
    wl_list_init(&server->pointer_resources);
    wl_list_init(&server->keyboard_resources);
    /* Two seats (Murmuration): the human's, and an agent seat whose
     * pointer/keyboard focus streams are fully independent — broker input
     * into agent-owned windows never disturbs what the human is doing. */
    server->seat_descs[0] = (struct WaylandSeatDesc){ server, 0 };
    server->seat_descs[1] = (struct WaylandSeatDesc){ server, 1 };
    server->seat_global = wl_global_create(server->display,
        &wl_seat_interface, 7, &server->seat_descs[0], seat_bind);
    server->seat_agent_global = wl_global_create(server->display,
        &wl_seat_interface, 7, &server->seat_descs[1], seat_bind);
}
