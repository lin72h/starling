// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_xdg_activation.c — xdg_activation_v1 implementation
 *
 * Window activation token protocol. Allows apps to request focus for
 * themselves or other apps. Chrome uses this for window.focus() and
 * opening new windows.
 *
 * We generate a dummy token on commit and accept activate requests.
 */

#include "wayland_server_internal.h"
#include "xdg-activation-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>

/* Simple monotonic token counter. */
static uint32_t token_counter = 0;

/* ========================================================================== */
/* xdg_activation_token_v1                                                    */
/* ========================================================================== */

static void token_set_serial(struct wl_client* client,
                             struct wl_resource* resource,
                             uint32_t serial,
                             struct wl_resource* seat) {
    (void)client; (void)resource; (void)serial; (void)seat;
}

static void token_set_app_id(struct wl_client* client,
                             struct wl_resource* resource,
                             const char* app_id) {
    (void)client; (void)resource; (void)app_id;
}

static void token_set_surface(struct wl_client* client,
                              struct wl_resource* resource,
                              struct wl_resource* surface) {
    (void)client; (void)resource; (void)surface;
}

static void token_commit(struct wl_client* client,
                         struct wl_resource* resource) {
    (void)client;
    /* Generate a simple unique token string. */
    char token_str[32];
    snprintf(token_str, sizeof(token_str), "flutter-tok-%u", ++token_counter);
    xdg_activation_token_v1_send_done(resource, token_str);
}

static void token_destroy(struct wl_client* client,
                          struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static const struct xdg_activation_token_v1_interface activation_token_impl = {
    .set_serial = token_set_serial,
    .set_app_id = token_set_app_id,
    .set_surface = token_set_surface,
    .commit = token_commit,
    .destroy = token_destroy,
};

/* ========================================================================== */
/* xdg_activation_v1 (global)                                                 */
/* ========================================================================== */

static void activation_destroy(struct wl_client* client,
                               struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void activation_get_activation_token(struct wl_client* client,
                                            struct wl_resource* resource,
                                            uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* token = wl_resource_create(client,
        &xdg_activation_token_v1_interface, 1, id);
    if (!token) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(token, &activation_token_impl, server, NULL);
}

static void activation_activate(struct wl_client* client,
                                struct wl_resource* resource,
                                const char* token,
                                struct wl_resource* surface) {
    (void)client; (void)resource; (void)token; (void)surface;
    /* Accept activation — our compositor doesn't have a focus policy
     * that would reject this. */
}

static const struct xdg_activation_v1_interface activation_impl = {
    .destroy = activation_destroy,
    .get_activation_token = activation_get_activation_token,
    .activate = activation_activate,
};

static void activation_bind(struct wl_client* client, void* data,
                            uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &xdg_activation_v1_interface, version, id);
    wl_resource_set_implementation(resource, &activation_impl, data, NULL);
}

void wayland_xdg_activation_init(struct WaylandServer* server) {
    server->xdg_activation_global = wl_global_create(server->display,
        &xdg_activation_v1_interface, 1, server, activation_bind);
}
