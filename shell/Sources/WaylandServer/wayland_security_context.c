// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_security_context.c — wp_security_context_manager_v1
 *
 * A sandbox (Flatpak, a container runner) creates a listening socket of its
 * own, hands the compositor its fd with the sandbox's identity, and lets the
 * confined app connect through it. Every client that arrives that way is
 * known to be sandboxed — and knowing that is the point: the privileged
 * globals (screen capture, the clipboard managers' protocols, the layer
 * shell, the taskbar lists, output configuration, this protocol itself) are
 * hidden from it through wl_global_set_filter, so a confined app cannot
 * read the screen or place a bar over the desktop. Everything an ordinary
 * app needs stays visible.
 *
 * libwayland accepts on the sockets it owns; ours we accept ourselves, from
 * an event source on the listening fd, and turn each connection into a
 * wl_client. The close_fd is the sandbox's lifetime: readable (its far end
 * closed) means stop listening.
 */

#include "wayland_server_internal.h"
#include "security-context-v1-protocol.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

/* Globals a sandboxed client must not see. */
static const char* const privileged_globals[] = {
    "zwlr_screencopy_manager_v1",
    "ext_image_copy_capture_manager_v1",
    "ext_output_image_capture_source_manager_v1",
    "zwlr_data_control_manager_v1",
    "ext_data_control_manager_v1",
    "zwlr_layer_shell_v1",
    "zwlr_foreign_toplevel_manager_v1",
    "ext_foreign_toplevel_list_v1",
    "zwlr_output_manager_v1",
    "wp_security_context_manager_v1",
    "xx_zone_manager_v1",
    "zwp_keyboard_shortcuts_inhibit_manager_v1",
    "ext_idle_notifier_v1",
    NULL,
};

struct WaylandSandboxedClient* wayland_client_sandbox(struct WaylandServer* server,
                                                      struct wl_client* client) {
    struct WaylandSandboxedClient* sc;
    wl_list_for_each(sc, &server->sandboxed_clients, link) {
        if (sc->client == client) return sc;
    }
    return NULL;
}

static bool global_filter(const struct wl_client* client, const struct wl_global* global,
                          void* data) {
    struct WaylandServer* server = data;
    if (!wayland_client_sandbox(server, (struct wl_client*)client)) return true;
    const struct wl_interface* iface = wl_global_get_interface(global);
    for (int i = 0; privileged_globals[i]; i++) {
        if (strcmp(iface->name, privileged_globals[i]) == 0) return false;
    }
    return true;
}

static void sandboxed_client_gone(struct wl_listener* l, void* data) {
    (void)data;
    struct WaylandSandboxedClient* sc = wl_container_of(l, sc, destroy);
    wl_list_remove(&sc->destroy.link);
    wl_list_remove(&sc->link);
    free(sc);
}

/* A connection on a sandbox's socket. */
static int listener_readable(int fd, uint32_t mask, void* data) {
    (void)mask;
    struct WaylandSecurityContext* ctx = data;
    struct WaylandServer* server = ctx->server;
    int client_fd = accept4(fd, NULL, NULL, SOCK_CLOEXEC);
    if (client_fd < 0) {
        if (errno != EAGAIN && errno != EWOULDBLOCK)
            fprintf(stderr, "[security_context] accept: %s\n", strerror(errno));
        return 0;
    }
    struct WaylandSandboxedClient* sc = calloc(1, sizeof(*sc));
    if (!sc) {
        close(client_fd);
        return 0;
    }
    struct wl_client* client = wl_client_create(server->display, client_fd);
    if (!client) {
        free(sc);
        close(client_fd);
        return 0;
    }
    sc->client = client;
    snprintf(sc->sandbox_engine, sizeof(sc->sandbox_engine), "%s", ctx->sandbox_engine);
    snprintf(sc->app_id, sizeof(sc->app_id), "%s", ctx->app_id);
    snprintf(sc->instance_id, sizeof(sc->instance_id), "%s", ctx->instance_id);
    sc->destroy.notify = sandboxed_client_gone;
    wl_client_add_destroy_listener(client, &sc->destroy);
    wl_list_insert(&server->sandboxed_clients, &sc->link);
    fprintf(stderr, "[security_context] sandboxed client: %s %s\n",
            sc->sandbox_engine, sc->app_id);
    return 0;
}

static void context_stop_listening(struct WaylandSecurityContext* ctx) {
    if (ctx->listen_source) {
        wl_event_source_remove(ctx->listen_source);
        ctx->listen_source = NULL;
    }
    if (ctx->close_source) {
        wl_event_source_remove(ctx->close_source);
        ctx->close_source = NULL;
    }
    if (ctx->listen_fd >= 0) {
        close(ctx->listen_fd);
        ctx->listen_fd = -1;
    }
    if (ctx->close_fd >= 0) {
        close(ctx->close_fd);
        ctx->close_fd = -1;
    }
}

/* The sandbox went away: its socket stops accepting. Clients already
 * connected keep running — that is the protocol's contract. */
static int close_fd_readable(int fd, uint32_t mask, void* data) {
    (void)fd; (void)mask;
    struct WaylandSecurityContext* ctx = data;
    context_stop_listening(ctx);
    return 0;
}

static void context_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void context_set_string(struct wl_resource* r, char* field, size_t len,
                               const char* value, const char* what) {
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    if (ctx->committed) {
        wl_resource_post_error(r, WP_SECURITY_CONTEXT_V1_ERROR_ALREADY_USED,
                               "the context was already committed");
        return;
    }
    if (field[0]) {
        wl_resource_post_error(r, WP_SECURITY_CONTEXT_V1_ERROR_ALREADY_SET,
                               "%s already set", what);
        return;
    }
    if (!value || !value[0]) {
        wl_resource_post_error(r, WP_SECURITY_CONTEXT_V1_ERROR_INVALID_METADATA,
                               "%s must not be empty", what);
        return;
    }
    snprintf(field, len, "%s", value);
}

static void context_set_sandbox_engine(struct wl_client* c, struct wl_resource* r,
                                       const char* name) {
    (void)c;
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    context_set_string(r, ctx->sandbox_engine, sizeof(ctx->sandbox_engine), name,
                       "sandbox_engine");
}

static void context_set_app_id(struct wl_client* c, struct wl_resource* r, const char* app_id) {
    (void)c;
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    context_set_string(r, ctx->app_id, sizeof(ctx->app_id), app_id, "app_id");
}

static void context_set_instance_id(struct wl_client* c, struct wl_resource* r,
                                    const char* instance_id) {
    (void)c;
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    context_set_string(r, ctx->instance_id, sizeof(ctx->instance_id), instance_id,
                       "instance_id");
}

static void context_commit(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    if (ctx->committed) {
        wl_resource_post_error(r, WP_SECURITY_CONTEXT_V1_ERROR_ALREADY_USED,
                               "the context was already committed");
        return;
    }
    if (!ctx->sandbox_engine[0]) {
        wl_resource_post_error(r, WP_SECURITY_CONTEXT_V1_ERROR_INVALID_METADATA,
                               "sandbox_engine is required");
        return;
    }
    ctx->committed = 1;
    struct WaylandServer* server = ctx->server;
    ctx->listen_source = wl_event_loop_add_fd(server->event_loop, ctx->listen_fd,
                                              WL_EVENT_READABLE, listener_readable, ctx);
    if (ctx->close_fd >= 0) {
        ctx->close_source = wl_event_loop_add_fd(server->event_loop, ctx->close_fd,
                                                 WL_EVENT_READABLE | WL_EVENT_HANGUP,
                                                 close_fd_readable, ctx);
    }
}

static const struct wp_security_context_v1_interface context_impl = {
    .destroy = context_destroy,
    .set_sandbox_engine = context_set_sandbox_engine,
    .set_app_id = context_set_app_id,
    .set_instance_id = context_set_instance_id,
    .commit = context_commit,
};

/* The object goes; a committed context's socket lives on until the sandbox
 * closes its close_fd (the protocol says the listener outlives the object). */
static void context_resource_destroyed(struct wl_resource* r) {
    struct WaylandSecurityContext* ctx = wl_resource_get_user_data(r);
    if (!ctx) return;
    ctx->resource = NULL;
    if (!ctx->committed) {
        context_stop_listening(ctx);
        wl_list_remove(&ctx->link);
        free(ctx);
    }
}

static void manager_create_listener(struct wl_client* client, struct wl_resource* resource,
                                    uint32_t id, int32_t listen_fd, int32_t close_fd) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    if (wayland_client_sandbox(server, client)) {
        wl_resource_post_error(resource, WP_SECURITY_CONTEXT_MANAGER_V1_ERROR_NESTED,
                               "a sandboxed client cannot nest a security context");
        close(listen_fd);
        if (close_fd >= 0) close(close_fd);
        return;
    }
    int accepting = 0;
    socklen_t len = sizeof(accepting);
    if (listen_fd < 0 ||
        getsockopt(listen_fd, SOL_SOCKET, SO_ACCEPTCONN, &accepting, &len) != 0 || !accepting) {
        wl_resource_post_error(resource, WP_SECURITY_CONTEXT_MANAGER_V1_ERROR_INVALID_LISTEN_FD,
                               "listen_fd is not a listening socket");
        if (listen_fd >= 0) close(listen_fd);
        if (close_fd >= 0) close(close_fd);
        return;
    }
    struct WaylandSecurityContext* ctx = calloc(1, sizeof(*ctx));
    if (!ctx) {
        close(listen_fd);
        if (close_fd >= 0) close(close_fd);
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &wp_security_context_v1_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(ctx);
        close(listen_fd);
        if (close_fd >= 0) close(close_fd);
        wl_client_post_no_memory(client);
        return;
    }
    ctx->resource = r;
    ctx->server = server;
    ctx->listen_fd = listen_fd;
    ctx->close_fd = close_fd;
    wl_list_insert(&server->security_contexts, &ctx->link);
    wl_resource_set_implementation(r, &context_impl, ctx, context_resource_destroyed);
}

static const struct wp_security_context_manager_v1_interface manager_impl = {
    .destroy = context_destroy,
    .create_listener = manager_create_listener,
};

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &wp_security_context_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_security_context_init(struct WaylandServer* server) {
    wl_list_init(&server->security_contexts);
    wl_list_init(&server->sandboxed_clients);
    wl_display_set_global_filter(server->display, global_filter, server);
    server->security_context_global = wl_global_create(server->display,
        &wp_security_context_manager_v1_interface, 1, server, manager_bind);
}
