// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_presentation.c — wp_presentation implementation
 *
 * Frame presentation timing feedback. Chrome uses this for smooth rendering
 * and VSync coordination. We send CLOCK_MONOTONIC as the clock and provide
 * basic feedback with vsync flag on frame_done.
 */

#include "wayland_server_internal.h"
#include "presentation-time-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* ========================================================================== */
/* wp_presentation_feedback (per-frame feedback object)                       */
/* ========================================================================== */

/* No client requests — feedback objects only receive events from compositor. */

/* ========================================================================== */
/* wp_presentation (global)                                                   */
/* ========================================================================== */

static void presentation_destroy(struct wl_client* client,
                                 struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void presentation_feedback_resource_destroy(struct wl_resource* resource) {
    struct WaylandPresentationFeedback* fb = wl_resource_get_user_data(resource);
    if (fb) {
        wl_list_remove(&fb->link);
        free(fb);
    }
}

static void presentation_feedback(struct wl_client* client,
                                  struct wl_resource* resource,
                                  struct wl_resource* surface,
                                  uint32_t callback_id) {
    (void)client;
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    struct wl_resource* fb_resource = wl_resource_create(client,
        &wp_presentation_feedback_interface, 1, callback_id);
    if (!fb_resource) {
        wl_client_post_no_memory(client);
        return;
    }

    struct WaylandPresentationFeedback* fb =
        calloc(1, sizeof(struct WaylandPresentationFeedback));
    if (!fb) {
        wl_client_post_no_memory(client);
        return;
    }
    fb->resource = fb_resource;

    /* Find matching surface to get its id. */
    struct WaylandSurface* surf;
    wl_list_for_each(surf, &server->surfaces, link) {
        if (surf->resource == surface) {
            fb->surface_id = surf->id;
            break;
        }
    }

    wl_list_insert(&server->presentation_feedbacks, &fb->link);
    wl_resource_set_implementation(fb_resource, NULL, fb,
        presentation_feedback_resource_destroy);
}

static const struct wp_presentation_interface presentation_impl = {
    .destroy = presentation_destroy,
    .feedback = presentation_feedback,
};

static void presentation_bind(struct wl_client* client, void* data,
                              uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wp_presentation_interface, version, id);
    wl_resource_set_implementation(resource, &presentation_impl, data, NULL);

    /* Tell client we use CLOCK_MONOTONIC. */
    wp_presentation_send_clock_id(resource, CLOCK_MONOTONIC);
}

void wayland_presentation_init(struct WaylandServer* server) {
    wl_list_init(&server->presentation_feedbacks);
    server->presentation_global = wl_global_create(server->display,
        &wp_presentation_interface, 1, server, presentation_bind);
}

/* Public API — called by the compositor after frame_done. */
void wayland_server_presentation_feedback(struct WaylandServer* server,
                                          uint32_t surface_id) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);

    uint32_t tv_sec_hi = (uint32_t)(ts.tv_sec >> 32);
    uint32_t tv_sec_lo = (uint32_t)(ts.tv_sec & 0xFFFFFFFF);
    uint32_t tv_nsec = (uint32_t)ts.tv_nsec;
    uint32_t refresh_ns = 0;
    if (server->config.refresh_mhz > 0) {
        /* Convert mHz to ns: 1e12 / refresh_mhz */
        refresh_ns = (uint32_t)(1000000000000ULL / server->config.refresh_mhz);
    }

    server->presentation_seq++;
    uint32_t flags = WP_PRESENTATION_FEEDBACK_KIND_VSYNC;

    struct WaylandPresentationFeedback* fb;
    struct WaylandPresentationFeedback* tmp;
    wl_list_for_each_safe(fb, tmp, &server->presentation_feedbacks, link) {
        if (fb->surface_id == surface_id) {
            wp_presentation_feedback_send_presented(fb->resource,
                tv_sec_hi, tv_sec_lo, tv_nsec, refresh_ns,
                0, server->presentation_seq, flags);
            wl_resource_destroy(fb->resource);
            /* destroy callback removes from list and frees */
        }
    }
}

/* Flip-driven path: every pending feedback corresponds to a commit that is
 * on screen as of this flip (or will be within one refresh) — answer them
 * all with the kernel's scanout timestamp and the real refresh period. */
void wayland_server_presentation_present_all(struct WaylandServer* server,
                                             uint64_t flip_time_ns,
                                             uint32_t refresh_ns) {
    uint64_t secs = flip_time_ns / 1000000000ull;
    uint32_t tv_sec_hi = (uint32_t)(secs >> 32);
    uint32_t tv_sec_lo = (uint32_t)(secs & 0xFFFFFFFF);
    uint32_t tv_nsec = (uint32_t)(flip_time_ns % 1000000000ull);
    uint32_t flags = WP_PRESENTATION_FEEDBACK_KIND_VSYNC |
                     WP_PRESENTATION_FEEDBACK_KIND_HW_CLOCK |
                     WP_PRESENTATION_FEEDBACK_KIND_HW_COMPLETION;

    server->presentation_seq++;

    struct WaylandPresentationFeedback* fb;
    struct WaylandPresentationFeedback* tmp;
    wl_list_for_each_safe(fb, tmp, &server->presentation_feedbacks, link) {
        wp_presentation_feedback_send_presented(fb->resource,
            tv_sec_hi, tv_sec_lo, tv_nsec, refresh_ns,
            0, server->presentation_seq, flags);
        wl_resource_destroy(fb->resource);
        /* destroy callback removes from list and frees */
    }
}

/* Called when a surface is destroyed: its content was never (or will never
 * be) presented again — discard outstanding feedback so the objects don't
 * pile up until the client disconnects. */
void wayland_server_presentation_discard(struct WaylandServer* server,
                                         uint32_t surface_id) {
    struct WaylandPresentationFeedback* fb;
    struct WaylandPresentationFeedback* tmp;
    wl_list_for_each_safe(fb, tmp, &server->presentation_feedbacks, link) {
        if (fb->surface_id == surface_id) {
            wp_presentation_feedback_send_discarded(fb->resource);
            wl_resource_destroy(fb->resource);
            /* destroy callback removes from list and frees */
        }
    }
}
