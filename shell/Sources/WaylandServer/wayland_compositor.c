// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_compositor.c — wl_compositor and wl_surface implementation
 *
 * Implements the wl_compositor global (create_surface) and the full
 * wl_surface interface (attach, damage, frame, commit, etc.).
 */

#include "wayland_server_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

/* ========================================================================== */
/* wl_surface stubs                                                           */
/* ========================================================================== */

static void surface_destroy(struct wl_client* client,
                            struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

/* Listener: if the client destroys a wl_buffer while it's attached but not
 * yet committed, clear the pending pointer so commit doesn't use-after-free.
 * (attach → destroy → commit is protocol-legal; content is undefined, but the
 * compositor must survive. Weston handles this the same way.) */
static void pending_buffer_destroyed(struct wl_listener* listener, void* data) {
    (void)data;
    struct WaylandSurface* surface =
        wl_container_of(listener, surface, pending_buffer_destroy_listener);
    surface->pending.buffer = NULL;
}

static void surface_attach(struct wl_client* client,
                           struct wl_resource* resource,
                           struct wl_resource* buffer,
                           int32_t x, int32_t y) {
    (void)client;
    (void)x;
    (void)y;
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    /* Invariant: pending listener registered iff pending.buffer != NULL. */
    if (surface->pending.buffer)
        wl_list_remove(&surface->pending_buffer_destroy_listener.link);
    surface->pending.buffer = buffer;
    surface->pending.buffer_set = 1;
    if (buffer) {
        surface->pending_buffer_destroy_listener.notify = pending_buffer_destroyed;
        wl_resource_add_destroy_listener(buffer,
            &surface->pending_buffer_destroy_listener);
    }
}

static void surface_damage(struct wl_client* client,
                           struct wl_resource* resource,
                           int32_t x, int32_t y,
                           int32_t width, int32_t height) {
    (void)client;
    (void)resource;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    /* Damage tracking not needed — we always repaint the full surface. */
}

static void surface_frame(struct wl_client* client,
                          struct wl_resource* resource,
                          uint32_t callback_id) {
    (void)client;
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;

    /* Destroy previous pending callback if any — otherwise the resource
     * leaks in the server's object map and the client can't reuse its ID. */
    if (surface->pending.frame_callback) {
        wl_resource_destroy(surface->pending.frame_callback);
        surface->pending.frame_callback = NULL;
    }
    struct wl_resource* callback = wl_resource_create(
        wl_resource_get_client(resource),
        &wl_callback_interface, 1, callback_id);
    /* Store as pending — applied on commit. */
    surface->pending.frame_callback = callback;
}

static void surface_set_opaque_region(struct wl_client* client,
                                      struct wl_resource* resource,
                                      struct wl_resource* region) {
    (void)client;
    (void)resource;
    (void)region;
}

static void surface_set_input_region(struct wl_client* client,
                                     struct wl_resource* resource,
                                     struct wl_resource* region) {
    (void)client;
    (void)resource;
    (void)region;
}

/* Listener: if the client destroys a wl_buffer while it's our committed_buffer,
 * clear the pointer so we don't use-after-free. */
static void committed_buffer_destroyed(struct wl_listener* listener, void* data) {
    struct WaylandSurface* surface =
        wl_container_of(listener, surface, committed_buffer_destroy_listener);
    surface->committed_buffer = NULL;
}

static void surface_commit(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    struct WaylandServer* server = surface->server;

    /* Apply pending buffer_scale. */
    if (surface->pending.buffer_scale_set) {
        surface->buffer_scale = surface->pending.buffer_scale;
        surface->pending.buffer_scale_set = 0;
    }

    /* Apply pending window geometry (double-buffered per xdg-shell spec). */
    if (surface->pending_geometry.set) {
        int changed = !surface->geometry.set
            || surface->geometry.x != surface->pending_geometry.x
            || surface->geometry.y != surface->pending_geometry.y
            || surface->geometry.width != surface->pending_geometry.width
            || surface->geometry.height != surface->pending_geometry.height;
        surface->geometry = surface->pending_geometry;
        surface->pending_geometry.set = 0;
        if (changed && server->cb.on_window_geometry) {
            server->cb.on_window_geometry(
                server->cb_ctx,
                surface->id,
                surface->geometry.x, surface->geometry.y,
                surface->geometry.width, surface->geometry.height);
        }
    }

    /* Apply pending buffer. */
    if (surface->pending.buffer_set) {
        /* Release previous committed buffer back to client.
         * Release for toplevel AND popup surfaces so Chrome's buffer pool
         * doesn't exhaust (triple buffering = 3 buffers max). Without
         * release, Chrome's GPU scheduler freezes after 3 frames.
         * Only skip release for cursor/auxiliary surfaces which cycle
         * buffers rapidly and may already be freed.
         *
         * Gate on had_role (sticky) rather than the live xdg_toplevel/xdg_popup
         * pointers: Chrome unmaps a popup by destroying the xdg_popup FIRST and
         * only THEN committing a null buffer (attach(nil) + commit). At that
         * commit the role pointer is already NULL, so the live-role check would
         * skip the release and leak the popup's last buffer out of Chrome's
         * pool. On a wl_surface Chrome reuses for a re-shown submenu that
         * missing buffer shrinks the triple-buffer pool, so the re-show fade-in
         * stalls after a couple of frames and the popup stays translucent. */
        if (surface->committed_buffer) {
            wl_list_remove(&surface->committed_buffer_destroy_listener.link);
            if (surface->had_role &&
                surface->committed_buffer != surface->pending.buffer) {
                wl_buffer_send_release(surface->committed_buffer);
            }
        }
        /* The buffer graduates from pending to committed — swap which destroy
         * listener tracks it. */
        if (surface->pending.buffer)
            wl_list_remove(&surface->pending_buffer_destroy_listener.link);
        surface->committed_buffer = surface->pending.buffer;
        if (surface->committed_buffer) {
            surface->committed_buffer_destroy_listener.notify =
                committed_buffer_destroyed;
            wl_resource_add_destroy_listener(surface->committed_buffer,
                &surface->committed_buffer_destroy_listener);
        }
        surface->pending.buffer = NULL;
        surface->pending.buffer_set = 0;
    }

    /* Apply pending frame callback — move to active. */
    if (surface->pending.frame_callback) {
        if (surface->frame_callback) {
            /* Old active callback still alive — send done before replacing. */
            struct timespec ts;
            clock_gettime(CLOCK_MONOTONIC, &ts);
            uint32_t ms = (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
            wl_callback_send_done(surface->frame_callback, ms);
            wl_resource_destroy(surface->frame_callback);
        }
        surface->frame_callback = surface->pending.frame_callback;
        surface->pending.frame_callback = NULL;
    }

    /* Determine which surface's window texture receives this buffer. Normally
     * it's the committing surface itself (a toplevel/popup). But a subsurface
     * has no role and no window of its own — its content belongs to the
     * toplevel ancestor's window. Waydroid, for instance, renders the whole
     * Android screen to a full-size dma-buf subsurface layered over a 1x1
     * dummy toplevel; we route that subsurface's buffer up to the toplevel's
     * window texture so it actually composites.
     *
     * Routing up is only correct when the subsurface IS the window content.
     * Chrome also uses subsurfaces for small overlays (tab hover cards, drag
     * images); routing those up replaces the whole window texture with a
     * small, mostly-transparent buffer — the window goes black until the next
     * real frame, and on a damage-driven compositor it stays black. So only
     * route up a buffer at least as large as the toplevel's own content; a
     * dummy toplevel that never drew (Waydroid's 1x1) always qualifies.
     * Proper per-subsurface compositing would supersede this rule. */
    struct WaylandSurface* target = surface;
    if (!surface->xdg_toplevel && !surface->xdg_popup && surface->is_subsurface) {
        struct WaylandSurface* a = surface->subsurface_parent;
        int guard = 0;
        while (a && a->is_subsurface && a->subsurface_parent && guard++ < 16)
            a = a->subsurface_parent;
        if (a && (a->xdg_toplevel || a->xdg_popup)) {
            int32_t bw = 0, bh = 0;
            if (surface->committed_buffer) {
                enum WaylandBufferType* t =
                    wl_resource_get_user_data(surface->committed_buffer);
                if (t && *t == BUFFER_TYPE_DMABUF) {
                    struct DmaBufBuffer* b = (struct DmaBufBuffer*)t;
                    bw = b->width; bh = b->height;
                } else if (t && *t == BUFFER_TYPE_SHM) {
                    struct ShmBuffer* b = (struct ShmBuffer*)t;
                    bw = b->width; bh = b->height;
                }
            }
            if (bw >= a->own_buf_w && bh >= a->own_buf_h)
                target = a;
        }
    }

    /* Notify compositor if we have a buffer and the target has a role. */
    if (surface->committed_buffer && (target->xdg_toplevel || target->xdg_popup)) {
        enum WaylandBufferType* type_ptr =
            wl_resource_get_user_data(surface->committed_buffer);
        if (type_ptr) {
            int first = !target->first_commit_done;
            target->first_commit_done = 1;

            /* Remember what this surface drew for itself, so the routing rule
             * above can tell a full-size content subsurface from a small
             * overlay. Only self-commits count — a routed-up buffer says
             * nothing about the parent's own content. */
            if (target == surface) {
                if (*type_ptr == BUFFER_TYPE_DMABUF) {
                    struct DmaBufBuffer* b = (struct DmaBufBuffer*)type_ptr;
                    surface->own_buf_w = b->width;
                    surface->own_buf_h = b->height;
                } else if (*type_ptr == BUFFER_TYPE_SHM) {
                    struct ShmBuffer* b = (struct ShmBuffer*)type_ptr;
                    surface->own_buf_w = b->width;
                    surface->own_buf_h = b->height;
                }
            }

            if (*type_ptr == BUFFER_TYPE_DMABUF) {
                struct DmaBufBuffer* buf = (struct DmaBufBuffer*)type_ptr;

                if (server->cb.on_surface_commit) {
                    server->cb.on_surface_commit(
                        server->cb_ctx,
                        target->id,
                        buf->fd,
                        buf->width, buf->height,
                        buf->stride, buf->fourcc,
                        buf->modifier,
                        first,
                        surface->buffer_scale);
                }
            } else if (*type_ptr == BUFFER_TYPE_SHM) {
                struct ShmBuffer* buf = (struct ShmBuffer*)type_ptr;
                if (server->cb.on_shm_surface_commit && buf->pool && buf->pool->data) {
                    const void* pixel_data = (const char*)buf->pool->data + buf->offset;
                    server->cb.on_shm_surface_commit(
                        server->cb_ctx,
                        target->id,
                        pixel_data,
                        buf->width, buf->height,
                        buf->stride, buf->format,
                        first,
                        surface->buffer_scale);
                }
            }
        }
    }
    /* Frame pacing. Primary: real page flips (wayland_server_on_present)
     * fire frame callbacks + presentation feedback with kernel scanout
     * timestamps. The per-surface timer is the FALLBACK for commits that
     * don't lead to a shell flip (occluded/minimized windows, VT switched
     * away) — 100ms once flips have been seen. Before the first flip (or in
     * dev windowed mode, which has no DRM flips at all) the timer is the
     * only pacer, so it runs at the old 16ms (~60fps). It also drains
     * wp_presentation feedback, so arm it for any committed frame on a
     * mapped role surface — not just ones that requested a frame callback. */
    if (surface->frame_done_timer &&
        (surface->frame_callback ||
         ((surface->xdg_toplevel || surface->xdg_popup) && surface->committed_buffer))) {
        wl_event_source_timer_update(surface->frame_done_timer,
                                     server->saw_flip ? 100 : 16);
    }
}

static void surface_set_buffer_transform(struct wl_client* client,
                                         struct wl_resource* resource,
                                         int32_t transform) {
    (void)client;
    (void)resource;
    (void)transform;
}

static void surface_set_buffer_scale(struct wl_client* client,
                                     struct wl_resource* resource,
                                     int32_t scale) {
    (void)client;
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    if (scale < 1) scale = 1;
    if (scale != surface->buffer_scale) {
        fprintf(stderr, "[WaylandServer] surface %u set_buffer_scale: %d → %d\n",
                surface->id, surface->buffer_scale, scale);
    }
    surface->pending.buffer_scale = scale;
    surface->pending.buffer_scale_set = 1;
}

static void surface_damage_buffer(struct wl_client* client,
                                  struct wl_resource* resource,
                                  int32_t x, int32_t y,
                                  int32_t width, int32_t height) {
    (void)client;
    (void)resource;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
}

static void surface_offset(struct wl_client* client,
                           struct wl_resource* resource,
                           int32_t x, int32_t y) {
    (void)client;
    (void)resource;
    (void)x;
    (void)y;
}

/* ========================================================================== */
/* wl_surface interface vtable                                                */
/* ========================================================================== */

/*
 * wl_surface requests (in protocol order):
 *   0  destroy
 *   1  attach
 *   2  damage
 *   3  frame
 *   4  set_opaque_region
 *   5  set_input_region
 *   6  commit
 *   7  set_buffer_transform  (since v2)
 *   8  set_buffer_scale      (since v3)
 *   9  damage_buffer          (since v4)
 *  10  offset                 (since v5)
 */
static const struct wl_surface_interface surface_impl = {
    .destroy              = surface_destroy,
    .attach               = surface_attach,
    .damage               = surface_damage,
    .frame                = surface_frame,
    .set_opaque_region    = surface_set_opaque_region,
    .set_input_region     = surface_set_input_region,
    .commit               = surface_commit,
    .set_buffer_transform = surface_set_buffer_transform,
    .set_buffer_scale     = surface_set_buffer_scale,
    .damage_buffer        = surface_damage_buffer,
    .offset               = surface_offset,
};

/* ========================================================================== */
/* Frame-done throttle timer callback                                         */
/* ========================================================================== */

static int frame_done_timer_cb(void* data) {
    struct WaylandSurface* surface = data;
    if (surface->frame_callback) {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        uint32_t ms = (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
        wl_callback_send_done(surface->frame_callback, ms);
        wl_resource_destroy(surface->frame_callback);
        surface->frame_callback = NULL;
    }

    /* Answer wp_presentation feedback for the frame just shown. Without this
     * the feedback objects (Chrome requests one per commit) accumulate
     * unboundedly for the life of the connection. Runs on the event-loop
     * thread, so sending here is safe. */
    wayland_server_presentation_feedback(surface->server, surface->id);
    return 0;
}

/* ========================================================================== */
/* wl_surface resource destructor                                             */
/* ========================================================================== */

static void surface_destroy_resource(struct wl_resource* resource) {
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;

    /* Notify compositor that the toplevel/popup is gone. */
    if (surface->xdg_toplevel && surface->server->cb.on_toplevel_destroy) {
        surface->server->cb.on_toplevel_destroy(
            surface->server->cb_ctx, surface->id);
    }
    if (surface->xdg_popup && surface->server->cb.on_popup_destroy) {
        surface->server->cb.on_popup_destroy(
            surface->server->cb_ctx, surface->id);
    }

    /* Nullify user_data on related resources to prevent use-after-free.
     * When the client disconnects, libwayland destroys resources in arbitrary
     * order. If wl_surface is destroyed first, xdg_toplevel/xdg_surface
     * destructors would access freed memory without this. */
    if (surface->xdg_toplevel) {
        wl_resource_set_user_data(surface->xdg_toplevel, NULL);
    }
    if (surface->xdg_popup) {
        wl_resource_set_user_data(surface->xdg_popup, NULL);
    }
    if (surface->xdg_surface) {
        wl_resource_set_user_data(surface->xdg_surface, NULL);
    }
    if (surface->decoration) {
        wl_resource_set_user_data(surface->decoration, NULL);
    }

    /* Clean up buffer destroy listeners. */
    if (surface->committed_buffer) {
        wl_list_remove(&surface->committed_buffer_destroy_listener.link);
    }
    if (surface->pending.buffer) {
        wl_list_remove(&surface->pending_buffer_destroy_listener.link);
    }

    /* Discard any pending presentation feedback for this surface so the
     * objects don't linger until client disconnect. */
    wayland_server_presentation_discard(surface->server, surface->id);

    /* Clean up frame-done timer. */
    if (surface->frame_done_timer) {
        wl_event_source_remove(surface->frame_done_timer);
    }

    /* Clean up frame callbacks. */
    if (surface->frame_callback) {
        wl_resource_destroy(surface->frame_callback);
    }
    if (surface->pending.frame_callback) {
        wl_resource_destroy(surface->pending.frame_callback);
    }

    wl_list_remove(&surface->link);
    free(surface);
}

/* ========================================================================== */
/* wl_compositor                                                              */
/* ========================================================================== */

static void compositor_create_surface(struct wl_client* client,
                                      struct wl_resource* resource,
                                      uint32_t id) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);

    /* Create the wl_surface resource. */
    struct wl_resource* surface_res = wl_resource_create(
        client, &wl_surface_interface,
        wl_resource_get_version(resource), id);
    if (!surface_res) {
        wl_client_post_no_memory(client);
        return;
    }

    /* Allocate and initialise surface state. */
    struct WaylandSurface* surface = calloc(1, sizeof(struct WaylandSurface));
    if (!surface) {
        wl_resource_destroy(surface_res);
        wl_client_post_no_memory(client);
        return;
    }
    surface->resource = surface_res;
    surface->id = ++server->next_surface_id;
    surface->server = server;
    surface->pending.buffer = NULL;
    surface->pending.frame_callback = NULL;
    surface->pending.buffer_scale = 1;
    surface->pending.buffer_scale_set = 0;
    surface->buffer_scale = 1;
    surface->committed_buffer = NULL;
    surface->frame_callback = NULL;
    surface->frame_done_timer = wl_event_loop_add_timer(
        server->event_loop, frame_done_timer_cb, surface);

    wl_list_insert(&server->surfaces, &surface->link);
    wl_resource_set_implementation(surface_res, &surface_impl,
                                   surface, surface_destroy_resource);
}

/* wl_region — no-op implementation (we don't use damage regions) */

static void region_destroy(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

static void region_add(struct wl_client* client, struct wl_resource* resource,
                       int32_t x, int32_t y, int32_t width, int32_t height) {
    (void)client; (void)resource; (void)x; (void)y; (void)width; (void)height;
}

static void region_subtract(struct wl_client* client, struct wl_resource* resource,
                             int32_t x, int32_t y, int32_t width, int32_t height) {
    (void)client; (void)resource; (void)x; (void)y; (void)width; (void)height;
}

static const struct wl_region_interface region_impl = {
    .destroy  = region_destroy,
    .add      = region_add,
    .subtract = region_subtract,
};

static void compositor_create_region(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t id) {
    struct wl_resource* region = wl_resource_create(client,
        &wl_region_interface, wl_resource_get_version(resource), id);
    if (!region) {
        wl_resource_post_no_memory(resource);
        return;
    }
    wl_resource_set_implementation(region, &region_impl, NULL, NULL);
}

/*
 * wl_compositor requests:
 *   0  create_surface
 *   1  create_region
 */
static const struct wl_compositor_interface compositor_impl = {
    .create_surface = compositor_create_surface,
    .create_region  = compositor_create_region,
};

static void compositor_bind(struct wl_client* client, void* data,
                            uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(
        client, &wl_compositor_interface, version, id);
    wl_resource_set_implementation(resource, &compositor_impl, data, NULL);
}

void wayland_compositor_init(struct WaylandServer* server) {
    server->compositor_global = wl_global_create(
        server->display, &wl_compositor_interface, 5,
        server, compositor_bind);
}
