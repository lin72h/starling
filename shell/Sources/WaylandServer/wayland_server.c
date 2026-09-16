// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef _GNU_SOURCE
#define _GNU_SOURCE  /* pipe2 */
#endif
#include "wayland_server_internal.h"
#include "xdg-shell-protocol.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

/* Forward declarations for deferred input. */
static int deferred_input_drain(int fd, uint32_t mask, void* data);
static void deferred_input_send_one(WaylandServer* server,
                                    const struct WaylandPointerEvent* ev);

/* --------------------------------------------------------------------------
 * Helpers
 * -------------------------------------------------------------------------- */

uint32_t wayland_server_next_serial(struct WaylandServer* server) {
    /* Single serial domain: configure serials come from the same counter as
     * input serials (wl_display_next_serial). A private counter here would
     * collide with input serials — harmless today, but any future serial
     * validation (xdg_popup.grab, set_selection serial checks, activation)
     * would reject valid requests on cross-domain matches. */
    return wl_display_next_serial(server->display);
}

struct WaylandSurface* wayland_server_find_surface(struct WaylandServer* server,
                                                    uint32_t surface_id) {
    struct WaylandSurface* surface;
    wl_list_for_each(surface, &server->surfaces, link) {
        if (surface->id == surface_id)
            return surface;
    }
    return NULL;
}

/* --------------------------------------------------------------------------
 * Lifecycle
 * -------------------------------------------------------------------------- */

WaylandServer* wayland_server_create(const WaylandServerConfig* config) {
    struct WaylandServer* server = calloc(1, sizeof(struct WaylandServer));
    if (!server) {
        fprintf(stderr, "wayland_server: failed to allocate server\n");
        return NULL;
    }

    server->config = *config;
    server->next_surface_id = 1;

    server->display = wl_display_create();
    if (!server->display) {
        fprintf(stderr, "wayland_server: wl_display_create failed\n");
        free(server);
        return NULL;
    }

    /* Increase the default per-client buffer size from 4096 to 1 MB.
     * The default is too small — when a client binds many globals in one
     * roundtrip the accumulated response events overflow the 4 KB ring buffer,
     * producing "Data too big for buffer" and disconnecting the client. */
    wl_display_set_default_max_buffer_size(server->display, 1024 * 1024);

    const char* socket = wl_display_add_socket_auto(server->display);
    if (!socket) {
        fprintf(stderr, "wayland_server: wl_display_add_socket_auto failed\n");
        wl_display_destroy(server->display);
        free(server);
        return NULL;
    }
    snprintf(server->socket_name, sizeof(server->socket_name), "%s", socket);

    /* This socket is the session's keyboard and its screen: any client that
     * connects can receive key events and read window content. It is
     * owner-only.
     *
     * Dev mode runs the compositor as root while clients run as the login
     * user, which is what the old unconditional 0777 was for — but it also
     * applied to the packaged unprivileged session, leaving every local uid
     * able to attach. Hand the socket to whoever owns XDG_RUNTIME_DIR
     * instead (the launcher chowns that dir to the login user for exactly
     * this reason) and keep the mode closed. */
    {
        const char *xdg = getenv("XDG_RUNTIME_DIR");
        if (xdg) {
            char path[256];
            snprintf(path, sizeof(path), "%s/%s", xdg, socket);
            if (geteuid() == 0) {
                struct stat st;
                if (stat(xdg, &st) == 0 && st.st_uid != 0) {
                    if (chown(path, st.st_uid, st.st_gid) != 0) {
                        fprintf(stderr, "wayland_server: chown(%s) failed\n", path);
                    }
                }
            }
            chmod(path, 0700);
        }
    }

    server->event_loop = wl_display_get_event_loop(server->display);

    wl_list_init(&server->surfaces);

    /* Initialize protocol globals */
    wayland_compositor_init(server);
    wayland_shm_init(server);
    wayland_dmabuf_init(server);
    wayland_xdg_shell_init(server);
    wayland_seat_init(server);
    wayland_output_init(server);
    wayland_decoration_init(server);
    wayland_subcompositor_init(server);
    wayland_data_device_init(server);
    wayland_data_control_init(server);
    wayland_fractional_scale_init(server);
    wayland_viewporter_init(server);
    wayland_cursor_shape_init(server);
    wayland_pointer_constraints_init(server);
    wayland_relative_pointer_init(server);
    wayland_primary_selection_init(server);
    wayland_text_input_init(server);
    wayland_idle_inhibit_init(server);
    wayland_xdg_output_init(server);
    wayland_xdg_activation_init(server);
    wayland_presentation_init(server);
    wayland_layer_shell_init(server);
    wayland_alpha_modifier_init(server);
    wayland_foreign_toplevel_init(server);
    wayland_screencopy_init(server);
    wayland_zones_init(server);
    wayland_single_pixel_buffer_init(server);
    wayland_misc_protocols_init(server);
    wayland_shortcuts_inhibit_init(server);
    wayland_pointer_gestures_init(server);
    wayland_tablet_init(server);
    wayland_ext_data_control_init(server);
    wayland_idle_notify_init(server);
    wayland_image_copy_capture_init(server);
    wayland_xdg_foreign_init(server);
    wayland_color_representation_init(server);
    wayland_security_context_init(server);
    wayland_output_management_init(server);
    wayland_session_lock_init(server);
    wayland_workspace_init(server);
    wayland_background_effect_init(server);
    wayland_transient_seat_init(server);
    wayland_virtual_input_init(server);
    wayland_pointer_warp_init(server);
    wayland_toplevel_drag_init(server);

    /* Initialize deferred pointer event pipe + event source. Both ends are
     * non-blocking: the write side runs on the Flutter UI thread and must
     * never block behind a stalled event loop (a full pipe is fine — one
     * pending wakeup byte is enough). */
    pthread_mutex_init(&server->deferred_input.lock, NULL);
    server->deferred_input.pipe_fd[0] = -1;
    server->deferred_input.pipe_fd[1] = -1;
    if (pipe2(server->deferred_input.pipe_fd, O_NONBLOCK | O_CLOEXEC) == 0) {
        server->deferred_input.source = wl_event_loop_add_fd(
            server->event_loop,
            server->deferred_input.pipe_fd[0],
            WL_EVENT_READABLE,
            deferred_input_drain,
            server);
    }

    fprintf(stderr, "wayland_server: listening on %s\n", server->socket_name);
    return server;
}

void wayland_server_destroy(WaylandServer* server) {
    if (!server)
        return;

    /* Destroy clients FIRST so every resource destructor (which frees the
     * WaylandSurface structs and unlinks them) runs while the structs are
     * still alive. Freeing the surfaces before wl_display_destroy would make
     * those destructors double-free. */
    wl_display_destroy_clients(server->display);

    /* Safety net for any surface not owned by a client resource (should be
     * empty after destroy_clients). */
    struct WaylandSurface* surface;
    struct WaylandSurface* tmp;
    wl_list_for_each_safe(surface, tmp, &server->surfaces, link) {
        wl_list_remove(&surface->link);
        free(surface);
    }

    /* Per-server state no client resource owned: a committed security
     * context's listening socket outlives its object by design, and the
     * workspace list is the shell's push. Both hold event sources, so they
     * go while the event loop still exists. */
    wayland_security_context_fini(server);
    wayland_workspace_fini(server);

    if (server->extra_socket_path[0])
        unlink(server->extra_socket_path);
    if (server->deferred_input.source)
        wl_event_source_remove(server->deferred_input.source);
    if (server->deferred_input.pipe_fd[0] >= 0)
        close(server->deferred_input.pipe_fd[0]);
    if (server->deferred_input.pipe_fd[1] >= 0)
        close(server->deferred_input.pipe_fd[1]);
    free(server->deferred_input.queue);
    pthread_mutex_destroy(&server->deferred_input.lock);

    wl_display_destroy(server->display);
    free(server);
}

/* --------------------------------------------------------------------------
 * Event loop
 * -------------------------------------------------------------------------- */

int wayland_server_get_fd(WaylandServer* server) {
    return wl_event_loop_get_fd(server->event_loop);
}

void wayland_server_dispatch(WaylandServer* server) {
    /* Record the event-loop thread on first dispatch — the reference point
     * for WARN_IF_OFF_LOOP_THREAD in the direct-send entry points. */
    if (!server->loop_thread_set) {
        server->loop_thread = pthread_self();
        server->loop_thread_set = 1;
    }
    /* wl_event_loop_dispatch processes all registered fds including our
     * deferred input pipe.  The pipe callback (deferred_input_drain) sends
     * pointer events and flushes — this is the ONLY safe place to call
     * wl_pointer_send_* since it runs inside the Wayland event loop. */
    wl_event_loop_dispatch(server->event_loop, 0);
    wl_display_flush_clients(server->display);
}

void wayland_server_flush_clients(WaylandServer* server) {
    WARN_IF_OFF_LOOP_THREAD(server, "flush_clients");
    wl_display_flush_clients(server->display);
}

void wayland_server_on_present(WaylandServer* server,
                               uint64_t flip_time_ns,
                               uint32_t refresh_ns,
                               uint32_t flip_output_mask) {
    WARN_IF_OFF_LOOP_THREAD(server, "on_present");

    if (!server->saw_flip) {
        server->saw_flip = 1;
        fprintf(stderr,
                "wayland_server: flip-driven frame pacing active (refresh %.1f Hz)\n",
                refresh_ns ? 1e9 / (double)refresh_ns : 0.0);
    }

    /* Fire the pending frame callbacks PACED BY THIS OUTPUT with the real
     * scanout time — the commit that armed the callback is on screen as of
     * this flip. Surfaces on other outputs wait for their own panel's flip:
     * completing a 30Hz monitor's clients on a 90Hz panel's flips makes
     * them render frames nobody scans out (and vice versa starves).
     * pace_mask 0 = primary, which is always bit 0. */
    uint32_t ms = (uint32_t)(flip_time_ns / 1000000ull);
    struct WaylandSurface* surface;
    wl_list_for_each(surface, &server->surfaces, link) {
        uint32_t pace = surface->pace_mask ? surface->pace_mask : 1u;
        if (!(pace & flip_output_mask)) {
            continue;  /* paced by another output's flips */
        }
        if (surface->frame_callback) {
            if (surface->frame_throttle_ms &&
                ms - surface->last_frame_done_ms < surface->frame_throttle_ms) {
                continue;  /* held — fires on a later flip */
            }
            surface->last_frame_done_ms = ms;
            wl_callback_send_done(surface->frame_callback, ms);
            wl_resource_destroy(surface->frame_callback);
            surface->frame_callback = NULL;
        }
    }

    /* Answer presentation feedback with the same flip timing — same
     * per-output partition. */
    wayland_server_presentation_present_all(server, flip_time_ns, refresh_ns,
                                            flip_output_mask);

    wl_display_flush_clients(server->display);
}

/* --------------------------------------------------------------------------
 * Window management
 * -------------------------------------------------------------------------- */

/* Ask a toplevel to close itself — the xdg_shell equivalent of clicking the
 * window's close button. Well-behaved clients run their normal quit path
 * (prompting to save, tearing down child processes) and then disconnect.
 *
 * There IS a server->client close in this protocol; an older comment in the
 * shell claimed otherwise and left Quit as a no-op, so quitting an app took
 * its window off the desktop and left the process running forever. Nothing
 * obliges a client to honour it, which is why the shell follows up with a
 * signal to the pid below if the client is still there. */
void wayland_server_close_toplevel(WaylandServer* server, uint32_t surface_id) {
    WARN_IF_OFF_LOOP_THREAD(server, "close_toplevel");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface || !surface->xdg_toplevel) return;
    xdg_toplevel_send_close(surface->xdg_toplevel);
}

/* The pid on the other end of the surface's connection, straight from the
 * socket's peer credentials — no client cooperation and no _NET_WM_PID-style
 * property to spoof or omit. 0 when the surface or client is gone. */
pid_t wayland_server_surface_pid(WaylandServer* server, uint32_t surface_id) {
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface || !surface->resource) return 0;
    struct wl_client* client = wl_resource_get_client(surface->resource);
    if (!client) return 0;
    pid_t pid = 0;
    wl_client_get_credentials(client, &pid, NULL, NULL);
    return pid;
}

void wayland_server_configure_toplevel(WaylandServer* server,
                                       uint32_t surface_id,
                                       int width, int height) {
    WARN_IF_OFF_LOOP_THREAD(server, "configure_toplevel");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface) return;
    wayland_xdg_shell_configure(server, surface, width, height);
}

void wayland_server_configure_toplevel_natural(WaylandServer* server, uint32_t surface_id) {
    WARN_IF_OFF_LOOP_THREAD(server, "configure_toplevel_natural");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface) return;
    wayland_xdg_shell_configure_natural(server, surface);
}

void wayland_server_configure_fullscreen(WaylandServer* server,
                                         uint32_t surface_id,
                                         int width, int height) {
    WARN_IF_OFF_LOOP_THREAD(server, "configure_fullscreen");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface) return;
    /* The old entry point: fullscreen implied, the rest of the bits kept.
     * The shell now pushes states explicitly and this is a convenience. */
    surface->toplevel_states |= WAYLAND_TOPLEVEL_FULLSCREEN;
    wayland_xdg_shell_configure(server, surface, width, height);
}

void wayland_server_set_toplevel_state(WaylandServer* server,
                                       uint32_t surface_id, uint32_t states) {
    WARN_IF_OFF_LOOP_THREAD(server, "set_toplevel_state");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface) return;
    wayland_xdg_shell_set_states(server, surface, states);
}

/* --------------------------------------------------------------------------
 * Input — Deferred pointer event queue
 *
 * Pointer events are queued from Flutter callbacks (which may run during
 * engine frame dispatch) and drained inside wl_event_loop_dispatch via a
 * pipe wakeup.  This avoids calling wl_pointer_send_* from outside the
 * Wayland event loop, which causes segfaults in libwayland-server.
 * -------------------------------------------------------------------------- */

static void deferred_input_enqueue(WaylandServer* server,
                                   const struct WaylandPointerEvent* ev) {
    pthread_mutex_lock(&server->deferred_input.lock);

    /* Coalesce consecutive motion events for the same surface to avoid
     * flooding the client's Wayland buffer during rapid mouse movement. */
    if (ev->type == WL_PTR_MOTION && server->deferred_input.count > 0) {
        struct WaylandPointerEvent* last =
            &server->deferred_input.queue[server->deferred_input.count - 1];
        if (last->type == WL_PTR_MOTION && last->surface_id == ev->surface_id) {
            *last = *ev;
            pthread_mutex_unlock(&server->deferred_input.lock);
            return;
        }
    }

    if (server->deferred_input.count >= server->deferred_input.capacity) {
        int new_cap = server->deferred_input.capacity ? server->deferred_input.capacity * 2 : 64;
        struct WaylandPointerEvent* new_q = realloc(server->deferred_input.queue,
            new_cap * sizeof(struct WaylandPointerEvent));
        if (!new_q) {
            pthread_mutex_unlock(&server->deferred_input.lock);
            return;
        }
        server->deferred_input.queue = new_q;
        server->deferred_input.capacity = new_cap;
    }
    server->deferred_input.queue[server->deferred_input.count++] = *ev;
    pthread_mutex_unlock(&server->deferred_input.lock);

    /* Wake the event loop so dispatch drains the queue promptly. Non-blocking:
     * if the pipe is full a wakeup is already pending. */
    if (server->deferred_input.pipe_fd[1] >= 0) {
        char c = 1;
        (void)write(server->deferred_input.pipe_fd[1], &c, 1);
    }
}

/* Iterate every pointer/keyboard resource belonging to the same wl_client as
 * the surface. The protocol requires delivering input to ALL wl_pointer /
 * wl_keyboard objects the focused client created (Chrome can hold several
 * across seat re-binds); sending to just one leaves the others silently dead.
 * The same serial is reused for every resource of one event, matching what
 * other compositors do. */
#define FOR_EACH_INPUT_OF_CLIENT(ir, list, target)                     \
    wl_list_for_each(ir, list, link)                                   \
        if (wl_resource_get_client(ir->resource) == (target) &&        \
            ir->seat == ev->seat)

/* wl_pointer.frame exists from version 5. A client that bound the seat
 * older than that — weston's demos bind version 1 — has no listener slot
 * for it, and libwayland aborts the client on an event it cannot
 * dispatch: weston-simple-egl died on its first pointer enter. */
static void pointer_frame(struct wl_resource* pointer) {
    if (wl_resource_get_version(pointer) >= WL_POINTER_FRAME_SINCE_VERSION)
        wl_pointer_send_frame(pointer);
}

static void deferred_input_send_one(WaylandServer* server,
                                    const struct WaylandPointerEvent* ev) {
    /* Not input: dma-buf modifier demotion queued from the raster thread
     * (EGL import failure). Handled before the surface lookup — it has none. */
    if (ev->type == WL_DMABUF_DEMOTE) {
        wayland_dmabuf_demote_on_loop_thread(server, ev->button, ev->modifier);
        return;
    }

    struct WaylandSurface* surface = wayland_server_find_surface(server, ev->surface_id);
    if (!surface) {
        /* A drag released over no client surface (the desktop, the shell's
         * own chrome): the drag ends there, with nothing to drop on. */
        if (server->drag.active && ev->seat == 0 && ev->type == WL_PTR_BUTTON &&
            ev->state == 0 && ev->surface_id == 0) {
            wayland_dnd_end(server, 1);
        }
        /* A press on no client surface: a grabbed menu closes, as it does
         * on every desktop when the user clicks the wallpaper or a panel. */
        if (ev->seat == 0 && ev->type == WL_PTR_BUTTON && ev->state == 1 &&
            ev->surface_id == 0 && server->popup_grab_count > 0) {
            wayland_popup_grab_dismiss_all(server);
        }
        return;
    }

    /* A person moved, clicked, scrolled or typed: ext-idle-notify's clocks
     * restart. The agent seat's synthetic input is not a person. */
    if (ev->seat == 0 && (ev->type == WL_PTR_MOTION || ev->type == WL_PTR_BUTTON ||
                          ev->type == WL_PTR_AXIS || ev->type == WL_KB_KEY)) {
        wayland_idle_notify_activity(server);
    }

    /* Where the human's pointer last was on a surface: a drag that begins
     * now starts there. */
    if (ev->seat == 0 && !server->drag.active &&
        (ev->type == WL_PTR_MOTION || ev->type == WL_PTR_ENTER)) {
        server->drag.last_x = ev->x;
        server->drag.last_y = ev->y;
    }

    /* A drag in progress owns the pointer: enter/motion/leave/button become
     * data_device events on the surface under it, and wl_pointer stays
     * quiet until the drop. */
    if (server->drag.active && ev->seat == 0 &&
        wayland_dnd_pointer_event(server, ev, surface)) {
        return;
    }

    struct wl_client* target = wl_resource_get_client(surface->resource);
    struct WaylandInputResource* ir;

    switch (ev->type) {
    case WL_PTR_ENTER: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->pointer_resources, target) {
            wl_pointer_send_enter(ir->resource, serial,
                                  surface->resource,
                                  wl_fixed_from_double(ev->x),
                                  wl_fixed_from_double(ev->y));
            pointer_frame(ir->resource);
        }
        /* Keyboard focus is lazy (first keystroke), so this is the earliest
         * point a mouse-only client can be handed a selection it missed. */
        wayland_data_device_offer_on_interaction(server, surface);
        wayland_primary_selection_offer_on_interaction(server, surface);
        break;
    }
    case WL_PTR_LEAVE: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->pointer_resources, target) {
            wl_pointer_send_leave(ir->resource, serial, surface->resource);
            pointer_frame(ir->resource);
        }
        break;
    }
    case WL_PTR_MOTION:
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->pointer_resources, target) {
            wl_pointer_send_motion(ir->resource, ev->time_ms,
                                   wl_fixed_from_double(ev->x),
                                   wl_fixed_from_double(ev->y));
            pointer_frame(ir->resource);
        }
        break;
    case WL_PTR_BUTTON: {
        /* xdg_popup.grab: a press anywhere but inside the grabbed popup's
         * tree — the parent window, another window, a bar — dismisses the
         * whole tree before the press is delivered where it landed. */
        if (ev->seat == 0 && ev->state == 1 && server->popup_grab_count > 0 &&
            !wayland_popup_grab_contains(server, surface)) {
            wayland_popup_grab_dismiss_all(server);
        }
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->pointer_resources, target) {
            wl_pointer_send_button(ir->resource, serial,
                                   ev->time_ms, ev->button, ev->state);
            pointer_frame(ir->resource);
        }
        break;
    }
    case WL_KB_ENTER: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->keyboard_resources, target) {
            struct wl_array keys;
            wl_array_init(&keys);
            wl_keyboard_send_enter(ir->resource, serial,
                                   surface->resource, &keys);
            wl_array_release(&keys);
        }
        wayland_text_input_focus_enter(server, surface);
        wayland_data_device_offer_on_interaction(server, surface);
        wayland_primary_selection_offer_on_interaction(server, surface);
        break;
    }
    case WL_KB_LEAVE: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->keyboard_resources, target) {
            wl_keyboard_send_leave(ir->resource, serial, surface->resource);
        }
        wayland_text_input_focus_leave(server, surface);
        break;
    }
    case WL_KB_KEY: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->keyboard_resources, target) {
            wl_keyboard_send_key(ir->resource, serial,
                                 ev->time_ms, ev->button, ev->state);
        }
        break;
    }
    case WL_KB_MODIFIERS: {
        uint32_t serial = wl_display_next_serial(server->display);
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->keyboard_resources, target) {
            wl_keyboard_send_modifiers(ir->resource, serial,
                                       ev->mods_depressed, ev->mods_latched,
                                       ev->mods_locked, ev->group);
        }
        break;
    }
    case WL_PTR_AXIS: {
        /* x,y carry scroll deltas: x=horizontal(axis 1), y=vertical(axis 0) */
        FOR_EACH_INPUT_OF_CLIENT(ir, &server->pointer_resources, target) {
            if (ev->y != 0.0) {
                wl_pointer_send_axis(ir->resource, ev->time_ms,
                                     0 /* WL_POINTER_AXIS_VERTICAL_SCROLL */,
                                     wl_fixed_from_double(ev->y));
            }
            if (ev->x != 0.0) {
                wl_pointer_send_axis(ir->resource, ev->time_ms,
                                     1 /* WL_POINTER_AXIS_HORIZONTAL_SCROLL */,
                                     wl_fixed_from_double(ev->x));
            }
            pointer_frame(ir->resource);
        }
        break;
    }

    case WL_DMABUF_DEMOTE:
        break;  /* handled before the surface lookup above */
    }
}

static int deferred_input_drain(int fd, uint32_t mask, void* data) {
    struct WaylandServer* server = data;
    /* Consume wakeup bytes. */
    char buf[64];
    (void)read(fd, buf, sizeof(buf));
    /* Drain the queue under the lock — the enqueue side (Flutter UI thread)
     * may realloc/append concurrently. Sends only marshal into the client
     * connection buffer, so holding the lock across them is cheap; the actual
     * socket flush happens after unlock. */
    pthread_mutex_lock(&server->deferred_input.lock);
    for (int i = 0; i < server->deferred_input.count; i++) {
        deferred_input_send_one(server, &server->deferred_input.queue[i]);
    }
    server->deferred_input.count = 0;
    pthread_mutex_unlock(&server->deferred_input.lock);
    wl_display_flush_clients(server->display);
    return 0;
}

/* Public pointer functions — queue events for deferred delivery. */

void wayland_server_pointer_enter(WaylandServer* server,
                                  uint32_t surface_id,
                                  double x, double y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_ENTER, .surface_id = surface_id, .x = x, .y = y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_pointer_leave(WaylandServer* server,
                                  uint32_t surface_id) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_LEAVE, .surface_id = surface_id
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_pointer_motion(WaylandServer* server,
                                   uint32_t surface_id,
                                   uint32_t time_ms,
                                   double x, double y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_MOTION, .surface_id = surface_id,
        .time_ms = time_ms, .x = x, .y = y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_pointer_pressed_outside(WaylandServer* server) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_BUTTON, .surface_id = 0, .button = 0x110, .state = 1
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_pointer_button(WaylandServer* server,
                                   uint32_t surface_id,
                                   uint32_t time_ms,
                                   uint32_t button,
                                   uint32_t state) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_BUTTON, .surface_id = surface_id,
        .time_ms = time_ms, .button = button, .state = state
    };
    deferred_input_enqueue(server, &ev);
}

/* --------------------------------------------------------------------------
 * Input — Keyboard
 * -------------------------------------------------------------------------- */

void wayland_server_keyboard_enter(WaylandServer* server,
                                   uint32_t surface_id) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_ENTER, .surface_id = surface_id
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_keyboard_leave(WaylandServer* server,
                                   uint32_t surface_id) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_LEAVE, .surface_id = surface_id
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_keyboard_key(WaylandServer* server,
                                 uint32_t surface_id,
                                 uint32_t time_ms,
                                 uint32_t key,
                                 uint32_t state) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_KEY, .surface_id = surface_id,
        .time_ms = time_ms, .button = key, .state = state
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_keyboard_modifiers(WaylandServer* server,
                                       uint32_t surface_id,
                                       uint32_t mods_depressed,
                                       uint32_t mods_latched,
                                       uint32_t mods_locked,
                                       uint32_t group) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_MODIFIERS, .surface_id = surface_id,
        .mods_depressed = mods_depressed, .mods_latched = mods_latched,
        .mods_locked = mods_locked, .group = group
    };
    deferred_input_enqueue(server, &ev);
}

/* Thread-safe: rides the deferred queue onto the loop thread, where
 * wayland_dmabuf_demote_on_loop_thread() drops the modifier from the
 * advertisement and re-sends v4 feedback. Called from the raster thread
 * when the compositor's EGL rejects a client buffer's layout (e.g. zink
 * failing AMD-tiled imports that eglQueryDmaBufModifiersEXT claimed to
 * support) — advertising ground truth instead of the query's word. */
void wayland_server_demote_dmabuf_modifier(WaylandServer* server,
                                           uint32_t fourcc,
                                           uint64_t modifier) {
    if (!server) return;
    struct WaylandPointerEvent ev = {
        .type = WL_DMABUF_DEMOTE, .button = fourcc, .modifier = modifier
    };
    deferred_input_enqueue(server, &ev);
}

/* --------------------------------------------------------------------------
 * Input — Agent seat (Murmuration)
 *
 * Broker-injected input into agent-owned windows rides seat 1: its
 * enter/leave/focus stream is delivered only to wl_pointer/wl_keyboard
 * objects bound from the agent seat, so it never disturbs the human's.
 * -------------------------------------------------------------------------- */

void wayland_server_agent_pointer_enter(WaylandServer* server,
                                        uint32_t surface_id,
                                        double x, double y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_ENTER, .seat = 1, .surface_id = surface_id, .x = x, .y = y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_agent_pointer_motion(WaylandServer* server,
                                         uint32_t surface_id,
                                         uint32_t time_ms,
                                         double x, double y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_MOTION, .seat = 1, .surface_id = surface_id,
        .time_ms = time_ms, .x = x, .y = y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_agent_pointer_button(WaylandServer* server,
                                         uint32_t surface_id,
                                         uint32_t time_ms,
                                         uint32_t button,
                                         uint32_t state) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_BUTTON, .seat = 1, .surface_id = surface_id,
        .time_ms = time_ms, .button = button, .state = state
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_agent_pointer_axis(WaylandServer* server,
                                       uint32_t surface_id,
                                       uint32_t time_ms,
                                       double axis_x, double axis_y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_AXIS, .seat = 1, .surface_id = surface_id,
        .time_ms = time_ms, .x = axis_x, .y = axis_y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_agent_keyboard_enter(WaylandServer* server,
                                         uint32_t surface_id) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_ENTER, .seat = 1, .surface_id = surface_id
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_agent_keyboard_key(WaylandServer* server,
                                       uint32_t surface_id,
                                       uint32_t time_ms,
                                       uint32_t key,
                                       uint32_t state) {
    struct WaylandPointerEvent ev = {
        .type = WL_KB_KEY, .seat = 1, .surface_id = surface_id,
        .time_ms = time_ms, .button = key, .state = state
    };
    deferred_input_enqueue(server, &ev);
}

/* --------------------------------------------------------------------------
 * Input — Pointer Axis (scroll)
 * -------------------------------------------------------------------------- */

void wayland_server_pointer_axis(WaylandServer* server,
                                  uint32_t surface_id,
                                  uint32_t time_ms,
                                  double axis_x,
                                  double axis_y) {
    struct WaylandPointerEvent ev = {
        .type = WL_PTR_AXIS, .surface_id = surface_id,
        .time_ms = time_ms, .x = axis_x, .y = axis_y
    };
    deferred_input_enqueue(server, &ev);
}

void wayland_server_set_surface_throttle(WaylandServer* server,
                                         uint32_t surface_id,
                                         uint32_t interval_ms) {
    WARN_IF_OFF_LOOP_THREAD(server, "set_surface_throttle");
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface) return;
    if (surface->frame_throttle_ms == interval_ms) return;
    surface->frame_throttle_ms = interval_ms;
    fprintf(stderr, "wayland_server: surface %u frame throttle -> %ums\n",
            surface_id, interval_ms);
}

/* --------------------------------------------------------------------------
 * Callback registration
 * -------------------------------------------------------------------------- */

#define DEF_CB_SETTER(name) \
void wayland_server_on_##name(WaylandServer* server, \
    typeof(server->cb.on_##name) cb, void* ctx) { \
    server->cb.on_##name = cb; \
    server->cb_ctx = ctx; \
}

DEF_CB_SETTER(new_toplevel)
DEF_CB_SETTER(title_changed)
DEF_CB_SETTER(app_id_changed)
DEF_CB_SETTER(toplevel_destroy)
DEF_CB_SETTER(client_destroy)
DEF_CB_SETTER(surface_commit)
DEF_CB_SETTER(shm_surface_commit)
DEF_CB_SETTER(toplevel_parent)
DEF_CB_SETTER(popup_repositioned)
DEF_CB_SETTER(toplevel_size_hints)
DEF_CB_SETTER(subsurface_placed)
DEF_CB_SETTER(subsurface_unmapped)
DEF_CB_SETTER(move_request)
DEF_CB_SETTER(interactive_resize_request)
DEF_CB_SETTER(new_popup)
DEF_CB_SETTER(popup_destroy)
DEF_CB_SETTER(window_geometry)
DEF_CB_SETTER(cursor_shape)
DEF_CB_SETTER(fullscreen_request)
DEF_CB_SETTER(unfullscreen_request)
DEF_CB_SETTER(toplevel_request)
DEF_CB_SETTER(new_layer_surface)
DEF_CB_SETTER(layer_surface_changed)
DEF_CB_SETTER(layer_surface_destroy)
DEF_CB_SETTER(surface_alpha)
DEF_CB_SETTER(screencopy_request)
DEF_CB_SETTER(toplevel_position_request)
DEF_CB_SETTER(system_bell)
DEF_CB_SETTER(shortcuts_inhibit)
DEF_CB_SETTER(session_lock)
DEF_CB_SETTER(workspace_request)
DEF_CB_SETTER(surface_blur)
DEF_CB_SETTER(virtual_pointer)
DEF_CB_SETTER(virtual_key)
DEF_CB_SETTER(pointer_warp)
DEF_CB_SETTER(drag_icon)
DEF_CB_SETTER(toplevel_drag)
DEF_CB_SETTER(output_config)

#undef DEF_CB_SETTER

/* --------------------------------------------------------------------------
 * Utility
 * -------------------------------------------------------------------------- */

int wayland_server_add_socket_at(WaylandServer* server, const char* path) {
    if (!server || !path || !*path)
        return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof(addr.sun_path)) {
        fprintf(stderr, "wayland_server: socket path too long: %s\n", path);
        return -1;
    }
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) {
        fprintf(stderr, "wayland_server: socket(): %s\n", strerror(errno));
        return -1;
    }
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    unlink(path);  /* clear a socket a previous run left behind */
    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "wayland_server: bind %s: %s\n", path, strerror(errno));
        close(fd);
        return -1;
    }
    /* Confined snaps run as the session user; a root dev shell must let that
     * user connect. In a normal (unprivileged) session this is a no-op. */
    chmod(path, 0777);
    if (listen(fd, 128) < 0) {
        fprintf(stderr, "wayland_server: listen %s: %s\n", path, strerror(errno));
        close(fd);
        unlink(path);
        return -1;
    }
    if (wl_display_add_socket_fd(server->display, fd) < 0) {
        fprintf(stderr, "wayland_server: add_socket_fd %s failed\n", path);
        close(fd);
        unlink(path);
        return -1;
    }
    snprintf(server->extra_socket_path, sizeof(server->extra_socket_path), "%s", path);
    fprintf(stderr, "wayland_server: also listening at %s\n", path);
    return 0;
}

const char* wayland_server_get_socket_name(WaylandServer* server) {
    return server->socket_name;
}

int wayland_server_get_viewport_destination(WaylandServer* server,
                                            uint32_t surface_id,
                                            int* out_width, int* out_height) {
    struct WaylandSurface* surface = wayland_server_find_surface(server, surface_id);
    if (!surface || surface->viewport_dst_width <= 0 || surface->viewport_dst_height <= 0)
        return 0;
    if (out_width) *out_width = surface->viewport_dst_width;
    if (out_height) *out_height = surface->viewport_dst_height;
    return 1;
}
