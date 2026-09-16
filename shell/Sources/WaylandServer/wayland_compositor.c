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

/* Where a subsurface ranks among its window's subsurfaces: depth-first
 * through the stacking lists, bottom first; -1 if it is not in the tree. */
static int sub_rank_walk(struct WaylandSurface* parent, struct WaylandSurface* target,
                         int* counter) {
    struct WaylandSurface* c;
    wl_list_for_each(c, &parent->sub_children, sub_link) {
        if (c == target) return *counter;
        (*counter)++;
        int r = sub_rank_walk(c, target, counter);
        if (r >= 0) return r;
    }
    return -1;
}

/* The toplevel a subsurface ultimately belongs to, and its offset from
 * that toplevel's surface origin through every subsurface ancestor. */
static struct WaylandSurface* sub_toplevel(struct WaylandSurface* s, int32_t* off_x, int32_t* off_y) {
    struct WaylandSurface* top = s->subsurface_parent;
    int32_t x = s->subsurface_x, y = s->subsurface_y;
    int guard = 0;
    while (top && top->is_subsurface && top->subsurface_parent && guard++ < 16) {
        x += top->subsurface_x;
        y += top->subsurface_y;
        top = top->subsurface_parent;
    }
    if (off_x) *off_x = x;
    if (off_y) *off_y = y;
    return top;
}

/* Synchronized mode is inherited: a desynchronized subsurface under a
 * synchronized one still waits for the ancestor's commit. */
static int sub_effectively_synced(struct WaylandSurface* s) {
    int guard = 0;
    while (s && s->is_subsurface && guard++ < 16) {
        if (s->sub_synced) return 1;
        s = s->subsurface_parent;
    }
    return 0;
}

static void surface_apply(struct WaylandSurface* surface);

/* A parent's state was applied: the subsurfaces that committed under sync
 * mode since then apply now, each taking its own waiting children along. */
static void apply_cached_children(struct WaylandSurface* parent) {
    struct WaylandSurface* c;
    struct WaylandSurface* tmp;
    wl_list_for_each_safe(c, tmp, &parent->sub_children, sub_link) {
        if (c->sub_cached) {
            c->sub_cached = 0;
            surface_apply(c);
        }
    }
}

/* wl_surface.commit. A synchronized subsurface's commit is held (cached)
 * until its parent commits; everything else applies at once. */
static void surface_commit(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    struct WaylandSurface* surface = wl_resource_get_user_data(resource);
    if (!surface) return;
    if (sub_effectively_synced(surface)) {
        surface->sub_cached = 1;
        return;
    }
    surface_apply(surface);
}

void wayland_subsurface_apply_cached(struct WaylandSurface* s) {
    if (s->sub_cached && !sub_effectively_synced(s)) {
        s->sub_cached = 0;
        surface_apply(s);
    }
}

static void surface_apply(struct WaylandSurface* surface) {
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

    /* Apply pending min/max size hints (double-buffered, like geometry). */
    if (surface->size_hints_pending) {
        surface->size_hints_pending = 0;
        int changed = surface->min_w != surface->pending_min_w
            || surface->min_h != surface->pending_min_h
            || surface->max_w != surface->pending_max_w
            || surface->max_h != surface->pending_max_h;
        surface->min_w = surface->pending_min_w;
        surface->min_h = surface->pending_min_h;
        surface->max_w = surface->pending_max_w;
        surface->max_h = surface->pending_max_h;
        if (changed && surface->xdg_toplevel && server->cb.on_toplevel_size_hints) {
            server->cb.on_toplevel_size_hints(server->cb_ctx, surface->id,
                                              surface->min_w, surface->min_h,
                                              surface->max_w, surface->max_h);
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
            /* A subsurface never gets an xdg role, so had_role stayed 0 and
             * its buffers were never released. Firefox draws its whole
             * content into a full-size subsurface with a four-buffer
             * WebRender swapchain: after four frames it had nothing to draw
             * into, showed a blank page, ignored every click and key it was
             * correctly receiving, and spun its main loop on roundtrips
             * waiting for a release that never came. The destroy listener
             * already covers a buffer freed early, so releasing on
             * replacement is as safe here as for a toplevel. (get_subsurface
             * now sets had_role too, for the immediate shm release below.) */
            if ((surface->had_role || surface->is_subsurface) &&
                !surface->committed_buffer_released &&
                surface->committed_buffer != surface->pending.buffer) {
                wl_buffer_send_release(surface->committed_buffer);
            }
        }
        /* The buffer graduates from pending to committed — swap which destroy
         * listener tracks it. */
        if (surface->pending.buffer)
            wl_list_remove(&surface->pending_buffer_destroy_listener.link);
        surface->committed_buffer = surface->pending.buffer;
        surface->committed_buffer_released = 0;
        if (surface->committed_buffer) {
            surface->committed_buffer_destroy_listener.notify =
                committed_buffer_destroyed;
            wl_resource_add_destroy_listener(surface->committed_buffer,
                &surface->committed_buffer_destroy_listener);
        }
        surface->pending.buffer = NULL;
        surface->pending.buffer_set = 0;
    }

    /* The other double-buffered state on this surface: a layer surface's
     * arrangement (which also answers the initial commit with a configure),
     * the alpha multiplier, and a zone item's membership and position. */
    wayland_layer_shell_commit(server, surface);
    wayland_alpha_modifier_commit(server, surface);
    wayland_zones_commit(server, surface);
    wayland_background_effect_commit(server, surface);

    /* A popup whose parent never arrived through the layer shell: the
     * shell has not heard of it at all yet, so tell it now, parentless. */
    if (surface->xdg_popup && surface->popup_parent_pending) {
        surface->popup_parent_pending = 0;
        if (server->cb.on_new_popup) {
            server->cb.on_new_popup(server->cb_ctx, surface->id,
                                    surface->parent_surface_id,
                                    surface->popup_x, surface->popup_y,
                                    surface->popup_w, surface->popup_h);
        }
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

    /* A subsurface that is not the window's content is drawn INSIDE the
     * window by the shell, at its offset from the toplevel's surface origin
     * (its own position plus every subsurface ancestor's). The shell hears
     * the placement first — it keys a texture on the id — and then the
     * buffer through the ordinary commit callbacks under that id. A null
     * buffer, or a buffer that now routes up as the content, unmaps it. */
    if (surface->is_subsurface && !surface->xdg_toplevel && !surface->xdg_popup) {
        int32_t off_x = 0, off_y = 0;
        struct WaylandSurface* top = sub_toplevel(surface, &off_x, &off_y);
        int drawable = top && top->xdg_toplevel && target == surface &&
                       surface->committed_buffer != NULL;
        if (drawable) {
            int counter = 0;
            int z = sub_rank_walk(top, surface, &counter);
            if (z < 0) z = 0;
            if (!surface->sub_placed || surface->sub_placed_x != off_x ||
                surface->sub_placed_y != off_y || surface->sub_placed_z != z) {
                surface->sub_placed = 1;
                surface->sub_placed_x = off_x;
                surface->sub_placed_y = off_y;
                surface->sub_placed_z = z;
                if (server->cb.on_subsurface_placed) {
                    server->cb.on_subsurface_placed(server->cb_ctx, surface->id,
                                                    top->id, off_x, off_y, z);
                }
            }
        } else if (surface->sub_placed) {
            surface->sub_placed = 0;
            if (server->cb.on_subsurface_unmapped)
                server->cb.on_subsurface_unmapped(server->cb_ctx, surface->id);
        }
    }

    /* Notify compositor if we have a buffer and the target has a role — or
     * is a subsurface the shell draws as part of one. */
    if (surface->committed_buffer &&
        (target->xdg_toplevel || target->xdg_popup || target->layer ||
         target->is_drag_icon || target->sub_placed)) {
        enum WaylandBufferType* type_ptr =
            wl_resource_get_user_data(surface->committed_buffer);
        if (type_ptr) {
            int first = !target->first_commit_done;
            target->first_commit_done = 1;
            /* Mapped: the taskbars (foreign-toplevel lists) announce it. */
            if (target->xdg_toplevel && !target->mapped)
                wayland_foreign_toplevel_map(server, target);

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
                    /* Toplevels routinely commit alpha 0 on an ARGB buffer,
                     * which composites the window away; only a popup (its
                     * shadow) or a layer surface (a translucent bar) means
                     * its alpha. */
                    int keep_alpha = buf->format == WL_SHM_FORMAT_ARGB8888 &&
                                     (target->xdg_popup || target->layer ||
                                      target->is_drag_icon || target->blur_count > 0 ||
                                      target->sub_placed);
                    server->cb.on_shm_surface_commit(
                        server->cb_ctx,
                        target->id,
                        pixel_data,
                        buf->width, buf->height,
                        buf->stride, buf->format,
                        first,
                        surface->buffer_scale,
                        keep_alpha);
                }
            }
        }
    }
    /* An shm buffer's pixels were copied out of the pool inside the
     * callback above, so the client may reuse it NOW — released here rather
     * than when the next buffer replaces it. A client that recycles a
     * buffer only once it is released (wmbench, weston-simple-shm, any
     * single- or double-buffered software client) otherwise waits a whole
     * frame for it — and a popup that is created, shown once and destroyed
     * never got its buffer back at all. dma-buf stays held until replaced:
     * the GPU reads it for as long as it is on screen. */
    if (surface->committed_buffer && !surface->committed_buffer_released &&
        surface->had_role) {
        enum WaylandBufferType* t = wl_resource_get_user_data(surface->committed_buffer);
        if (t && *t == BUFFER_TYPE_SHM) {
            wl_buffer_send_release(surface->committed_buffer);
            surface->committed_buffer_released = 1;
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
         ((surface->xdg_toplevel || surface->xdg_popup || surface->layer ||
           surface->is_drag_icon || surface->sub_placed) &&
          surface->committed_buffer))) {
        wl_event_source_timer_update(surface->frame_done_timer,
                                     server->saw_flip ? 100 : 16);
    }

    apply_cached_children(surface);
}

/* After a place_above/place_below: every placed subsurface of the window
 * whose rank moved is re-placed for the shell, which draws them in rank
 * order. */
static void sub_restack_walk(struct WaylandServer* server, struct WaylandSurface* top,
                             struct WaylandSurface* parent, int* counter) {
    struct WaylandSurface* c;
    wl_list_for_each(c, &parent->sub_children, sub_link) {
        int z = (*counter)++;
        if (c->sub_placed && c->sub_placed_z != z) {
            c->sub_placed_z = z;
            if (server->cb.on_subsurface_placed) {
                server->cb.on_subsurface_placed(server->cb_ctx, c->id, top->id,
                                                c->sub_placed_x, c->sub_placed_y, z);
            }
        }
        sub_restack_walk(server, top, c, counter);
    }
}

void wayland_subsurface_restacked(struct WaylandSurface* s) {
    struct WaylandSurface* top = sub_toplevel(s, NULL, NULL);
    if (!top || !top->xdg_toplevel) return;
    int counter = 0;
    sub_restack_walk(top->server, top, top, &counter);
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

    if (surface->sub_placed) {
        surface->sub_placed = 0;
        if (surface->server->cb.on_subsurface_unmapped)
            surface->server->cb.on_subsurface_unmapped(surface->server->cb_ctx, surface->id);
    }

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
    if (surface->subsurface_resource) {
        wl_resource_set_user_data(surface->subsurface_resource, NULL);
    }
    if (surface->alpha_resource) {
        wl_resource_set_user_data(surface->alpha_resource, NULL);
    }
    /* Role and helper objects that keep a raw pointer to this surface: a
     * layer surface goes inert, the zone item is closed, the taskbars hear
     * the window is gone, a shortcuts inhibitor forgets its surface. */
    wayland_layer_shell_surface_destroyed(surface->server, surface);
    wayland_foreign_toplevel_unmap(surface->server, surface);
    wayland_xdg_foreign_surface_destroyed(surface->server, surface);
    wayland_dnd_surface_destroyed(surface->server, surface);
    if (surface->background_effect_resource)
        wl_resource_set_user_data(surface->background_effect_resource, NULL);
    wayland_zones_surface_destroyed(surface->server, surface);
    wayland_shortcuts_inhibit_surface_destroyed(surface->server, surface);

    /* Children hold a raw pointer to us. Destroying a parent while a
     * subsurface still references it left that pointer dangling, and the
     * commit path walks it (and writes through it), so clear every child
     * that points here before the free below. */
    {
        struct WaylandSurface* other;
        wl_list_for_each(other, &surface->server->surfaces, link) {
            if (other->subsurface_parent == surface) {
                other->subsurface_parent = NULL;
                other->is_subsurface = 0;
                wl_list_remove(&other->sub_link);
                wl_list_init(&other->sub_link);
            }
        }
        wl_list_init(&surface->sub_children);
        if (!wl_list_empty(&surface->sub_link)) {
            wl_list_remove(&surface->sub_link);
            wl_list_init(&surface->sub_link);
        }
    }

    /* Text-input focus holds a raw surface pointer too. This cleanup hook
     * was declared, defined and exported but never called from anywhere,
     * so a focused client that destroyed its surface left server->ti_focus
     * pointing at freed memory — read back to clients through
     * zwp_text_input_v3.enter. */
    wayland_text_input_surface_destroyed(surface->server, surface);

    /* Clean up buffer destroy listeners — and hand the buffers back. A
     * surface that dies with a buffer attached or on screen is done with
     * it; a client that pools its buffers (every toolkit, wmbench) counts
     * one as busy until release, and a popup surface made and destroyed
     * per menu leaked its pool one buffer at a time. */
    if (surface->committed_buffer) {
        wl_list_remove(&surface->committed_buffer_destroy_listener.link);
        if (!surface->committed_buffer_released &&
            surface->committed_buffer != surface->pending.buffer) {
            wl_buffer_send_release(surface->committed_buffer);
        }
    }
    if (surface->pending.buffer) {
        wl_list_remove(&surface->pending_buffer_destroy_listener.link);
        wl_buffer_send_release(surface->pending.buffer);
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
    surface->alpha = 1.0;
    surface->pending_alpha = 1.0;
    wl_list_init(&surface->foreign_handles);
    wl_list_init(&surface->sub_children);
    wl_list_init(&surface->sub_link);
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
    (void)client;
    struct WaylandRegion* reg = wl_resource_get_user_data(resource);
    if (!reg || reg->count >= WAYLAND_MAX_REGION_RECTS || width <= 0 || height <= 0) return;
    reg->rects[reg->count][0] = x;
    reg->rects[reg->count][1] = y;
    reg->rects[reg->count][2] = width;
    reg->rects[reg->count][3] = height;
    reg->count++;
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

static void region_resource_destroyed(struct wl_resource* resource) {
    free(wl_resource_get_user_data(resource));
}

static void compositor_create_region(struct wl_client* client,
                                     struct wl_resource* resource,
                                     uint32_t id) {
    /* The rects a client adds are kept: a blur region
     * (ext-background-effect) reads them. Opaque/input regions are still
     * ignored — the shell composites whole surfaces. */
    struct WaylandRegion* reg = calloc(1, sizeof(*reg));
    struct wl_resource* region = wl_resource_create(client,
        &wl_region_interface, wl_resource_get_version(resource), id);
    if (!region || !reg) {
        free(reg);
        wl_resource_post_no_memory(resource);
        return;
    }
    wl_resource_set_implementation(region, &region_impl, reg, region_resource_destroyed);
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
        server->display, &wl_compositor_interface, 6,
        server, compositor_bind);
}
