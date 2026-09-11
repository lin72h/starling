// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_idle_notify.c — ext_idle_notifier_v1 (v2)
 *
 * "Tell me when the user has been idle for N ms, and when they come back."
 * swayidle, gammastep's idle mode, and lock-screen daemons build on it.
 * Idleness is measured from the last input event the compositor delivered
 * to a client on the human seat (wayland_idle_notify_activity, called from
 * the input send path); the agent seat's synthetic input is not a person.
 *
 * A v1 notification honours idle inhibitors — a client playing video keeps
 * the user "active" — while v2's get_input_idle_notification ignores them
 * and reports input alone. Each notification runs its own event-loop timer,
 * re-armed by every input event; when it fires, `idled` goes out and
 * `resumed` is owed on the next input.
 */

#include "wayland_server_internal.h"
#include "ext-idle-notify-v1-protocol.h"
#include <stdlib.h>

static int notification_timer_fired(void* data) {
    struct WaylandIdleNotification* n = data;
    struct WaylandServer* server = n->server;
    if (!n->ignore_inhibitors && server->idle_inhibitors > 0) {
        /* Something is holding the screen awake: look again later. */
        wl_event_source_timer_update(n->timer, n->timeout_ms > 0 ? n->timeout_ms : 1000);
        return 0;
    }
    if (!n->idle) {
        n->idle = 1;
        ext_idle_notification_v1_send_idled(n->resource);
    }
    return 0;
}

static void notification_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_idle_notification_v1_interface notification_impl = {
    .destroy = notification_destroy,
};

static void notification_resource_destroyed(struct wl_resource* r) {
    struct WaylandIdleNotification* n = wl_resource_get_user_data(r);
    if (!n) return;
    if (n->timer) wl_event_source_remove(n->timer);
    wl_list_remove(&n->link);
    free(n);
}

static void notifier_get(struct wl_client* client, struct wl_resource* resource,
                         uint32_t id, uint32_t timeout, struct wl_resource* seat,
                         int ignore_inhibitors) {
    (void)seat;
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandIdleNotification* n = calloc(1, sizeof(*n));
    if (!n) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &ext_idle_notification_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        free(n);
        wl_client_post_no_memory(client);
        return;
    }
    n->resource = r;
    n->server = server;
    n->timeout_ms = timeout;
    n->ignore_inhibitors = ignore_inhibitors;
    n->timer = wl_event_loop_add_timer(server->event_loop, notification_timer_fired, n);
    wl_list_insert(&server->idle_notifications, &n->link);
    wl_resource_set_implementation(r, &notification_impl, n,
                                   notification_resource_destroyed);
    /* A zero timeout means "idle right now", per the protocol. */
    if (n->timer) wl_event_source_timer_update(n->timer, timeout > 0 ? (int)timeout : 1);
}

static void notifier_get_idle(struct wl_client* client, struct wl_resource* r,
                              uint32_t id, uint32_t timeout,
                              struct wl_resource* seat) {
    notifier_get(client, r, id, timeout, seat, 0);
}

static void notifier_get_input_idle(struct wl_client* client, struct wl_resource* r,
                                    uint32_t id, uint32_t timeout,
                                    struct wl_resource* seat) {
    notifier_get(client, r, id, timeout, seat, 1);
}

static void notifier_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_idle_notifier_v1_interface notifier_impl = {
    .destroy = notifier_destroy,
    .get_idle_notification = notifier_get_idle,
    .get_input_idle_notification = notifier_get_input_idle,
};

static void notifier_bind(struct wl_client* client, void* data,
                          uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_idle_notifier_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &notifier_impl, data, NULL);
}

void wayland_idle_notify_init(struct WaylandServer* server) {
    wl_list_init(&server->idle_notifications);
    server->idle_notifier_global = wl_global_create(server->display,
        &ext_idle_notifier_v1_interface, 2, server, notifier_bind);
}

void wayland_idle_notify_activity(struct WaylandServer* server) {
    struct WaylandIdleNotification* n;
    wl_list_for_each(n, &server->idle_notifications, link) {
        if (n->idle) {
            n->idle = 0;
            ext_idle_notification_v1_send_resumed(n->resource);
        }
        if (n->timer)
            wl_event_source_timer_update(n->timer, n->timeout_ms > 0 ? (int)n->timeout_ms : 1);
    }
}
