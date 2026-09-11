// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_screencopy.c — zwlr_screencopy_manager_v1 (v3)
 *
 * The screenshot protocol grim, slurp+grim, wf-recorder and OBS's wlroots
 * capture speak. A client asks for an output (or a region of it), we tell
 * it the buffer to allocate (wl_shm XRGB8888, the output's device pixels),
 * it hands the buffer over with copy(), and we fill it and say ready.
 *
 * The pixels are the shell's to give: it reads the presented framebuffer
 * back from the engine (BGRX, top-down — exactly XRGB8888's memory layout)
 * on its own schedule and answers with wayland_server_screencopy_deliver,
 * on the event-loop thread, which memcpys rows into the client's pool and
 * sends flags + ready. The compositor never touches the GPU here.
 *
 * Only shm buffers, no linux_dmabuf offer: the v3 buffer_done event tells a
 * client the list is complete either way. The cursor is a hardware plane and
 * never in the framebuffer, so overlay_cursor is accepted and ignored.
 */

#include "wayland_server_internal.h"
#include "wlr-screencopy-unstable-v1-protocol.h"
#include "ext-image-capture-source-v1-protocol.h"
#include "ext-image-copy-capture-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void ext_frame_delivered(struct WaylandScreencopyFrame* f, uint64_t time_ns);
static void ext_frame_failed(struct WaylandScreencopyFrame* f, uint32_t reason);

static struct WaylandScreencopyFrame* frame_from(struct wl_resource* r) {
    return wl_resource_get_user_data(r);
}

static struct WaylandScreencopyFrame* frame_by_id(struct WaylandServer* server,
                                                  uint32_t id) {
    struct WaylandScreencopyFrame* f;
    wl_list_for_each(f, &server->screencopy_frames, link) {
        if (f->id == id) return f;
    }
    return NULL;
}

static void frame_buffer_gone(struct wl_listener* l, void* data) {
    (void)data;
    struct WaylandScreencopyFrame* f = wl_container_of(l, f, buffer_destroy);
    wl_list_remove(&f->buffer_destroy.link);
    wl_list_init(&f->buffer_destroy.link);
    f->buffer = NULL;
}

static void frame_copy_common(struct wl_resource* r, struct wl_resource* buffer,
                              int with_damage) {
    struct WaylandScreencopyFrame* f = frame_from(r);
    if (!f) return;
    if (f->buffer || f->requested) {
        wl_resource_post_error(r, ZWLR_SCREENCOPY_FRAME_V1_ERROR_ALREADY_USED,
                               "frame already copied");
        return;
    }
    struct ShmBuffer* shm = wayland_shm_buffer_from_resource(buffer);
    if (!shm) {
        wl_resource_post_error(r, ZWLR_SCREENCOPY_FRAME_V1_ERROR_INVALID_BUFFER,
                               "screencopy needs a wl_shm buffer");
        return;
    }
    if ((shm->format != WL_SHM_FORMAT_XRGB8888 &&
         shm->format != WL_SHM_FORMAT_ARGB8888) ||
        shm->width != f->w || shm->height != f->h || shm->stride < f->w * 4) {
        wl_resource_post_error(r, ZWLR_SCREENCOPY_FRAME_V1_ERROR_INVALID_BUFFER,
                               "buffer is %dx%d stride %d format 0x%x, frame wants "
                               "%dx%d XRGB8888",
                               shm->width, shm->height, shm->stride, shm->format,
                               f->w, f->h);
        return;
    }
    f->buffer = buffer;
    f->buffer_destroy.notify = frame_buffer_gone;
    wl_resource_add_destroy_listener(buffer, &f->buffer_destroy);
    f->with_damage = with_damage;
    f->requested = 1;

    struct WaylandServer* server = f->server;
    if (!server->cb.on_screencopy_request) {
        zwlr_screencopy_frame_v1_send_failed(r);
        return;
    }
    server->cb.on_screencopy_request(server->cb_ctx, f->id, f->output_index,
                                     f->x, f->y, f->w, f->h);
}

static void frame_copy(struct wl_client* c, struct wl_resource* r,
                       struct wl_resource* buffer) {
    (void)c;
    frame_copy_common(r, buffer, 0);
}

static void frame_copy_with_damage(struct wl_client* c, struct wl_resource* r,
                                   struct wl_resource* buffer) {
    (void)c;
    frame_copy_common(r, buffer, 1);
}

static void frame_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_screencopy_frame_v1_interface frame_impl = {
    .copy = frame_copy,
    .destroy = frame_destroy,
    .copy_with_damage = frame_copy_with_damage,
};

static void frame_resource_destroyed(struct wl_resource* r) {
    struct WaylandScreencopyFrame* f = frame_from(r);
    if (!f) return;
    if (f->buffer) wl_list_remove(&f->buffer_destroy.link);
    wl_list_remove(&f->link);
    free(f);
}

/* ========================================================================== */
/* Manager                                                                    */
/* ========================================================================== */

static void manager_capture(struct wl_client* client, struct wl_resource* resource,
                            uint32_t id, int32_t overlay_cursor,
                            struct wl_resource* output,
                            int has_region, int32_t rx, int32_t ry,
                            int32_t rw, int32_t rh) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    int idx = wayland_output_index_of(server, output);
    if (idx < 0) idx = 0;
    struct WaylandOutput* o = &server->outputs[idx];
    int32_t scale = o->scale > 0 ? o->scale : 1;

    struct WaylandScreencopyFrame* f = calloc(1, sizeof(*f));
    if (!f) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_screencopy_frame_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        free(f);
        wl_client_post_no_memory(client);
        return;
    }
    f->resource = r;
    f->server = server;
    f->id = ++server->next_screencopy_id;
    f->output_index = idx;
    f->overlay_cursor = overlay_cursor;
    wl_list_init(&f->buffer_destroy.link);
    if (has_region) {
        /* Logical, output-local, clipped to the output. */
        int32_t lw = o->physical_w / scale, lh = o->physical_h / scale;
        if (rx < 0) { rw += rx; rx = 0; }
        if (ry < 0) { rh += ry; ry = 0; }
        if (rx + rw > lw) rw = lw - rx;
        if (ry + rh > lh) rh = lh - ry;
        f->x = rx * scale;
        f->y = ry * scale;
        f->w = rw * scale;
        f->h = rh * scale;
    } else {
        f->x = 0;
        f->y = 0;
        f->w = o->physical_w;
        f->h = o->physical_h;
    }
    wl_list_insert(&server->screencopy_frames, &f->link);
    wl_resource_set_implementation(r, &frame_impl, f, frame_resource_destroyed);

    if (f->w <= 0 || f->h <= 0) {
        zwlr_screencopy_frame_v1_send_failed(r);
        return;
    }
    zwlr_screencopy_frame_v1_send_buffer(r, WL_SHM_FORMAT_XRGB8888,
                                         (uint32_t)f->w, (uint32_t)f->h,
                                         (uint32_t)(f->w * 4));
    if (wl_resource_get_version(r) >= ZWLR_SCREENCOPY_FRAME_V1_BUFFER_DONE_SINCE_VERSION)
        zwlr_screencopy_frame_v1_send_buffer_done(r);
}

static void manager_capture_output(struct wl_client* client,
                                   struct wl_resource* resource, uint32_t id,
                                   int32_t overlay_cursor,
                                   struct wl_resource* output) {
    manager_capture(client, resource, id, overlay_cursor, output, 0, 0, 0, 0, 0);
}

static void manager_capture_output_region(struct wl_client* client,
                                          struct wl_resource* resource,
                                          uint32_t id, int32_t overlay_cursor,
                                          struct wl_resource* output,
                                          int32_t x, int32_t y,
                                          int32_t w, int32_t h) {
    manager_capture(client, resource, id, overlay_cursor, output, 1, x, y, w, h);
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_screencopy_manager_v1_interface manager_impl = {
    .capture_output = manager_capture_output,
    .capture_output_region = manager_capture_output_region,
    .destroy = manager_destroy,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_screencopy_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_screencopy_init(struct WaylandServer* server) {
    wl_list_init(&server->screencopy_frames);
    server->screencopy_manager_global = wl_global_create(server->display,
        &zwlr_screencopy_manager_v1_interface, 3, server, manager_bind);
}

/* ========================================================================== */
/* The shell's answer                                                         */
/* ========================================================================== */

static void frame_send_failed(struct WaylandScreencopyFrame* f) {
    if (f->ext)
        ext_frame_failed(f, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_UNKNOWN);
    else
        zwlr_screencopy_frame_v1_send_failed(f->resource);
}

void wayland_server_screencopy_deliver(WaylandServer* server, uint32_t frame_id,
                                       const void* bgrx, int32_t stride,
                                       uint64_t time_ns) {
    WARN_IF_OFF_LOOP_THREAD(server, "screencopy_deliver");
    struct WaylandScreencopyFrame* f = frame_by_id(server, frame_id);
    if (!f) return;                      /* the client gave up meanwhile */
    if (!f->buffer || !bgrx) {
        frame_send_failed(f);
        return;
    }
    struct ShmBuffer* shm = wayland_shm_buffer_from_resource(f->buffer);
    if (!shm || !shm->pool || !shm->pool->data) {
        frame_send_failed(f);
        return;
    }
    /* The pool is mapped read-only for client buffers (we only ever read
     * them); a screencopy target is the one buffer we write. */
    char* dst = (char*)shm->pool->data + shm->offset;
    const char* src = bgrx;
    size_t row = (size_t)f->w * 4;
    for (int32_t y = 0; y < f->h; y++) {
        memcpy(dst + (size_t)y * shm->stride, src + (size_t)y * stride, row);
    }
    if (time_ns == 0) {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        time_ns = (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
    }
    if (f->ext) {
        ext_frame_delivered(f, time_ns);
        return;
    }
    zwlr_screencopy_frame_v1_send_flags(f->resource, 0);
    if (f->with_damage &&
        wl_resource_get_version(f->resource) >= ZWLR_SCREENCOPY_FRAME_V1_DAMAGE_SINCE_VERSION) {
        zwlr_screencopy_frame_v1_send_damage(f->resource, 0, 0,
                                             (uint32_t)f->w, (uint32_t)f->h);
    }
    uint64_t sec = time_ns / 1000000000ull;
    zwlr_screencopy_frame_v1_send_ready(f->resource,
        (uint32_t)(sec >> 32), (uint32_t)(sec & 0xffffffffu),
        (uint32_t)(time_ns % 1000000000ull));
}

void wayland_server_screencopy_fail(WaylandServer* server, uint32_t frame_id) {
    WARN_IF_OFF_LOOP_THREAD(server, "screencopy_fail");
    struct WaylandScreencopyFrame* f = frame_by_id(server, frame_id);
    if (!f) return;
    frame_send_failed(f);
}

/* ========================================================================== */
/* ext-image-copy-capture — the same readback behind the standardised
 * protocol: a capture SOURCE names an output, a SESSION on it announces the
 * buffer to allocate (device size, shm formats), and each FRAME attaches a
 * buffer and asks for a capture. grim 1.5+, wf-recorder and OBS's wlroots
 * capture prefer this over wlr-screencopy when both are offered.
 * ========================================================================== */

/* --- capture source: an output ------------------------------------------- */

struct ImageCaptureSource {
    struct WaylandServer* server;
    int output_index;
};

static void source_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_image_capture_source_v1_interface source_impl = {
    .destroy = source_destroy,
};

static void source_resource_destroyed(struct wl_resource* r) {
    free(wl_resource_get_user_data(r));
}

static void source_manager_create(struct wl_client* client, struct wl_resource* resource,
                                  uint32_t id, struct wl_resource* output) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct ImageCaptureSource* src = calloc(1, sizeof(*src));
    if (!src) {
        wl_client_post_no_memory(client);
        return;
    }
    src->server = server;
    src->output_index = wayland_output_index_of(server, output);
    if (src->output_index < 0) src->output_index = 0;
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_capture_source_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        free(src);
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &source_impl, src, source_resource_destroyed);
}

static const struct ext_output_image_capture_source_manager_v1_interface source_manager_impl = {
    .create_source = source_manager_create,
    .destroy = source_destroy,
};

static void source_manager_bind(struct wl_client* client, void* data,
                                uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_output_image_capture_source_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &source_manager_impl, data, NULL);
}

/* --- frames ---------------------------------------------------------------- */

static void ext_frame_delivered(struct WaylandScreencopyFrame* f, uint64_t time_ns) {
    ext_image_copy_capture_frame_v1_send_transform(f->resource, WL_OUTPUT_TRANSFORM_NORMAL);
    ext_image_copy_capture_frame_v1_send_damage(f->resource, 0, 0, f->w, f->h);
    uint64_t sec = time_ns / 1000000000ull;
    ext_image_copy_capture_frame_v1_send_presentation_time(f->resource,
        (uint32_t)(sec >> 32), (uint32_t)(sec & 0xffffffffu),
        (uint32_t)(time_ns % 1000000000ull));
    ext_image_copy_capture_frame_v1_send_ready(f->resource);
    if (f->session && f->session->frame == f) f->session->frame = NULL;
}

static void ext_frame_failed(struct WaylandScreencopyFrame* f, uint32_t reason) {
    ext_image_copy_capture_frame_v1_send_failed(f->resource, reason);
    if (f->session && f->session->frame == f) f->session->frame = NULL;
}

static void ext_frame_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void ext_frame_attach_buffer(struct wl_client* c, struct wl_resource* r,
                                    struct wl_resource* buffer) {
    (void)c;
    struct WaylandScreencopyFrame* f = frame_from(r);
    if (!f) return;
    if (f->requested) {
        wl_resource_post_error(r, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_ERROR_ALREADY_CAPTURED,
                               "frame already captured");
        return;
    }
    if (f->buffer) wl_list_remove(&f->buffer_destroy.link);
    f->buffer = buffer;
    if (buffer) {
        f->buffer_destroy.notify = frame_buffer_gone;
        wl_resource_add_destroy_listener(buffer, &f->buffer_destroy);
    } else {
        wl_list_init(&f->buffer_destroy.link);
    }
}

static void ext_frame_damage_buffer(struct wl_client* c, struct wl_resource* r,
                                    int32_t x, int32_t y, int32_t w, int32_t h) {
    (void)c;
    if (w <= 0 || h <= 0 || x < 0 || y < 0) {
        wl_resource_post_error(r, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_ERROR_INVALID_BUFFER_DAMAGE,
                               "invalid damage");
    }
    /* Whole-buffer copies: the damage hint changes nothing. */
}

static void ext_frame_capture(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandScreencopyFrame* f = frame_from(r);
    if (!f) return;
    if (f->requested) {
        wl_resource_post_error(r, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_ERROR_ALREADY_CAPTURED,
                               "frame already captured");
        return;
    }
    if (!f->buffer) {
        wl_resource_post_error(r, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_ERROR_NO_BUFFER,
                               "capture without a buffer");
        return;
    }
    f->requested = 1;
    if (!f->session || f->session->stopped) {
        ext_frame_failed(f, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_STOPPED);
        return;
    }
    struct ShmBuffer* shm = wayland_shm_buffer_from_resource(f->buffer);
    if (!shm ||
        (shm->format != WL_SHM_FORMAT_XRGB8888 && shm->format != WL_SHM_FORMAT_ARGB8888) ||
        shm->width != f->w || shm->height != f->h || shm->stride < f->w * 4) {
        ext_frame_failed(f, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_BUFFER_CONSTRAINTS);
        return;
    }
    struct WaylandServer* server = f->server;
    if (!server->cb.on_screencopy_request) {
        ext_frame_failed(f, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_UNKNOWN);
        return;
    }
    server->cb.on_screencopy_request(server->cb_ctx, f->id, f->output_index,
                                     f->x, f->y, f->w, f->h);
}

static const struct ext_image_copy_capture_frame_v1_interface ext_frame_impl = {
    .destroy = ext_frame_destroy,
    .attach_buffer = ext_frame_attach_buffer,
    .damage_buffer = ext_frame_damage_buffer,
    .capture = ext_frame_capture,
};

static void ext_frame_resource_destroyed(struct wl_resource* r) {
    struct WaylandScreencopyFrame* f = frame_from(r);
    if (!f) return;
    if (f->session && f->session->frame == f) f->session->frame = NULL;
    if (f->buffer) wl_list_remove(&f->buffer_destroy.link);
    wl_list_remove(&f->link);
    free(f);
}

/* --- sessions -------------------------------------------------------------- */

static void session_announce(struct WaylandImageCopySession* s) {
    struct WaylandOutput* o = &s->server->outputs[s->output_index];
    s->sent_w = o->physical_w;
    s->sent_h = o->physical_h;
    ext_image_copy_capture_session_v1_send_buffer_size(s->resource,
        (uint32_t)o->physical_w, (uint32_t)o->physical_h);
    ext_image_copy_capture_session_v1_send_shm_format(s->resource, WL_SHM_FORMAT_XRGB8888);
    ext_image_copy_capture_session_v1_send_shm_format(s->resource, WL_SHM_FORMAT_ARGB8888);
    ext_image_copy_capture_session_v1_send_done(s->resource);
}

static void session_create_frame(struct wl_client* client, struct wl_resource* resource,
                                 uint32_t id) {
    struct WaylandImageCopySession* s = wl_resource_get_user_data(resource);
    if (!s) return;
    if (s->frame) {
        wl_resource_post_error(resource, EXT_IMAGE_COPY_CAPTURE_SESSION_V1_ERROR_DUPLICATE_FRAME,
                               "a frame is already in flight");
        return;
    }
    struct WaylandScreencopyFrame* f = calloc(1, sizeof(*f));
    if (!f) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_copy_capture_frame_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        free(f);
        wl_client_post_no_memory(client);
        return;
    }
    struct WaylandServer* server = s->server;
    f->resource = r;
    f->server = server;
    f->id = ++server->next_screencopy_id;
    f->output_index = s->output_index;
    f->ext = 1;
    f->session = s;
    f->x = 0;
    f->y = 0;
    f->w = s->sent_w;
    f->h = s->sent_h;
    wl_list_init(&f->buffer_destroy.link);
    wl_list_insert(&server->screencopy_frames, &f->link);
    wl_resource_set_implementation(r, &ext_frame_impl, f, ext_frame_resource_destroyed);
    s->frame = f;
}

static void session_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_image_copy_capture_session_v1_interface session_impl = {
    .create_frame = session_create_frame,
    .destroy = session_destroy,
};

static void session_resource_destroyed(struct wl_resource* r) {
    struct WaylandImageCopySession* s = wl_resource_get_user_data(r);
    if (!s) return;
    if (s->frame) {
        s->frame->session = NULL;
        if (!s->frame->requested)
            ext_frame_failed(s->frame, EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_STOPPED);
    }
    wl_list_remove(&s->link);
    free(s);
}

static struct WaylandImageCopySession* session_create(struct wl_client* client,
                                                      struct wl_resource* manager,
                                                      uint32_t id, int output_index) {
    struct WaylandServer* server = wl_resource_get_user_data(manager);
    struct WaylandImageCopySession* s = calloc(1, sizeof(*s));
    if (!s) {
        wl_client_post_no_memory(client);
        return NULL;
    }
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_copy_capture_session_v1_interface, wl_resource_get_version(manager), id);
    if (!r) {
        free(s);
        wl_client_post_no_memory(client);
        return NULL;
    }
    s->resource = r;
    s->server = server;
    s->output_index = output_index;
    wl_list_insert(&server->image_copy_sessions, &s->link);
    wl_resource_set_implementation(r, &session_impl, s, session_resource_destroyed);
    return s;
}

static void manager_create_session(struct wl_client* client, struct wl_resource* resource,
                                   uint32_t id, struct wl_resource* source,
                                   uint32_t options) {
    if (options & ~EXT_IMAGE_COPY_CAPTURE_MANAGER_V1_OPTIONS_PAINT_CURSORS) {
        wl_resource_post_error(resource, EXT_IMAGE_COPY_CAPTURE_MANAGER_V1_ERROR_INVALID_OPTION,
                               "invalid options %u", options);
        return;
    }
    struct ImageCaptureSource* src = source ? wl_resource_get_user_data(source) : NULL;
    struct WaylandImageCopySession* s = session_create(client, resource, id,
                                                       src ? src->output_index : 0);
    if (s) session_announce(s);
}

/* --- cursor sessions: no cursor image to give (the cursor is a hardware
 * plane), so the capture session behind one is stopped from the start. --- */

static void cursor_session_get_capture_session(struct wl_client* client,
                                               struct wl_resource* resource, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_copy_capture_session_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandImageCopySession* s = calloc(1, sizeof(*s));
    if (!s) {
        wl_resource_destroy(r);
        wl_client_post_no_memory(client);
        return;
    }
    s->resource = r;
    s->server = server;
    s->stopped = 1;
    wl_list_insert(&server->image_copy_sessions, &s->link);
    wl_resource_set_implementation(r, &session_impl, s, session_resource_destroyed);
    ext_image_copy_capture_session_v1_send_stopped(r);
}

static const struct ext_image_copy_capture_cursor_session_v1_interface cursor_session_impl = {
    .destroy = session_destroy,
    .get_capture_session = cursor_session_get_capture_session,
};

static void manager_create_cursor_session(struct wl_client* client,
                                          struct wl_resource* resource, uint32_t id,
                                          struct wl_resource* source,
                                          struct wl_resource* pointer) {
    (void)source; (void)pointer;
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_copy_capture_cursor_session_v1_interface,
        wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &cursor_session_impl,
                                   wl_resource_get_user_data(resource), NULL);
}

static const struct ext_image_copy_capture_manager_v1_interface copy_manager_impl = {
    .create_session = manager_create_session,
    .create_pointer_cursor_session = manager_create_cursor_session,
    .destroy = session_destroy,
};

static void copy_manager_bind(struct wl_client* client, void* data,
                              uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &ext_image_copy_capture_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &copy_manager_impl, data, NULL);
}

void wayland_image_copy_capture_init(struct WaylandServer* server) {
    wl_list_init(&server->image_copy_sessions);
    server->image_capture_source_manager_global = wl_global_create(server->display,
        &ext_output_image_capture_source_manager_v1_interface, 1, server, source_manager_bind);
    server->image_copy_capture_manager_global = wl_global_create(server->display,
        &ext_image_copy_capture_manager_v1_interface, 1, server, copy_manager_bind);
}
