// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// notification_service.h — the freedesktop notification daemon
// (org.freedesktop.Notifications) on the session bus, using libsystemd
// sd-bus. Runs its own event loop on a background thread, like the portal
// (portal_service.h) — the shell draws the banners; this file only speaks
// the protocol.
//
// v1 capabilities: "body". No actions, no images — GetCapabilities says so
// and clients adapt (libnotify checks before sending buttons). The
// ActionInvoked signal is declared for introspection completeness but never
// emitted until actions exist.

#ifndef NOTIFICATION_SERVICE_H
#define NOTIFICATION_SERVICE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NotificationService NotificationService;

// --- Lifecycle ---

NotificationService *notification_service_create(void);
void notification_service_destroy(NotificationService *ns);

/// Start on a background thread. bus_address / target_uid have portal
/// semantics: pin the session's own bus, and as root drop the thread's euid
/// to the login user before connecting. Returns 0 or negative errno.
int notification_service_start(NotificationService *ns,
                               const char *bus_address,
                               unsigned int target_uid);

/// Stop the service and join the background thread.
void notification_service_stop(NotificationService *ns);

// --- Callbacks (fired on the SERVICE thread — hop before touching UI) ---

/// A client posted (or, when `replaces` is nonzero, updated) a notification.
/// `id` is final. urgency: 0 low / 1 normal / 2 critical (1 when the client
/// sent no hint). expire_timeout_ms as the client sent it: -1 = server
/// default, 0 = never expire.
typedef void (*notification_posted_fn)(void *userdata, uint32_t id,
                                       const char *app_name,
                                       const char *summary,
                                       const char *body,
                                       int urgency,
                                       int expire_timeout_ms,
                                       int replaces);

/// A client asked to close one by id (CloseNotification). The shell removes
/// the banner and answers with notification_service_emit_closed(id, 3).
typedef void (*notification_close_requested_fn)(void *userdata, uint32_t id);

void notification_service_set_callbacks(NotificationService *ns,
                                        notification_posted_fn posted,
                                        notification_close_requested_fn close_requested,
                                        void *userdata);

/// Emit NotificationClosed(id, reason) — reason 1 expired, 2 dismissed by
/// the user, 3 CloseNotification, 4 undefined. Thread-safe: queued and
/// emitted from the service thread.
void notification_service_emit_closed(NotificationService *ns,
                                      uint32_t id, uint32_t reason);

#ifdef __cplusplus
}
#endif

#endif // NOTIFICATION_SERVICE_H
