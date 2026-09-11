// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_xdg_activation.c — xdg_activation_v1
 *
 * Window activation tokens. A client asks for a token, hands it (or an
 * environment-supplied one) to whoever should be raised, and that client
 * calls activate with it: Chrome's window.focus(), a launcher raising the
 * app it started, wmbench raising its own windows over each other.
 *
 * Tokens this compositor minted are honoured, once each — that is the
 * protocol's focus-stealing guard: a client cannot activate itself with a
 * token it invented. Every honoured activate reaches the shell as an
 * on_toplevel_request(ACTIVATE), which raises and focuses the window the
 * way a dock click does.
 */

#include "wayland_server_internal.h"
#include "xdg-activation-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TOKEN_SLOTS (sizeof(((struct WaylandServer*)0)->issued_tokens) / \
                     sizeof(((struct WaylandServer*)0)->issued_tokens[0]))

void wayland_xdg_activation_issue_token(struct WaylandServer* server,
                                        char* out, size_t out_len) {
    static uint32_t counter = 0;
    /* Unpredictable enough that another client cannot guess the next one:
     * a counter salted with the address of the server and the time. */
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    snprintf(out, out_len, "starling-%08x-%08x-%08x", ++counter,
             (uint32_t)(ts.tv_nsec ^ (uintptr_t)server),
             (uint32_t)ts.tv_sec);
    char* slot = server->issued_tokens[server->issued_token_next % TOKEN_SLOTS];
    server->issued_token_next++;
    snprintf(slot, sizeof(server->issued_tokens[0]), "%s", out);
}

int wayland_xdg_activation_consume_token(struct WaylandServer* server,
                                         const char* token) {
    if (!token || !token[0]) return 0;
    for (size_t i = 0; i < TOKEN_SLOTS; i++) {
        if (strcmp(server->issued_tokens[i], token) == 0) {
            server->issued_tokens[i][0] = '\0';   /* single use */
            return 1;
        }
    }
    return 0;
}

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
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    char token[48];
    wayland_xdg_activation_issue_token(server, token, sizeof(token));
    xdg_activation_token_v1_send_done(resource, token);
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
                                struct wl_resource* wl_surface) {
    (void)client;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSurface* surface = wl_surface ? wl_resource_get_user_data(wl_surface) : NULL;
    if (!surface || !surface->xdg_toplevel) return;
    if (!wayland_xdg_activation_consume_token(server, token)) {
        fprintf(stderr, "[xdg_activation] surface %u: unknown token, ignored\n",
                surface->id);
        return;
    }
    if (server->cb.on_toplevel_request)
        server->cb.on_toplevel_request(server->cb_ctx, surface->id,
                                       WAYLAND_TOPLEVEL_REQUEST_ACTIVATE);
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
