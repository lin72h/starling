// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// pwcast.c — PipeWire video-source stream (see pwcast.h).
//
// The stream model is the one xdg-desktop-portal-wlr ships: connect as an
// OUTPUT driver stream, and push each frame as it arrives by dequeueing a
// daemon buffer under the thread-loop lock, copying, and queueing. No
// on_process pacing — the capture's own cadence (presents) is the clock,
// which is also what makes the redundancy-skip upstream meaningful: a
// present that was skipped produces no PipeWire frame either.

#include "include/pwcast.h"

#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <pipewire/pipewire.h>
#include <spa/param/video/format-utils.h>

struct PwCast {
    struct pw_thread_loop *loop;
    struct pw_stream *stream;
    uint32_t width, height, stride;
    int ready;    // stream reached PAUSED/STREAMING (node exists daemon-side)
    int failed;
};

static pthread_once_t pw_init_once = PTHREAD_ONCE_INIT;
static void _pw_init(void) { pw_init(NULL, NULL); }

int pwcast_available(void) {
    const char *dir = getenv("PIPEWIRE_RUNTIME_DIR");
    if (!dir || !dir[0]) dir = getenv("XDG_RUNTIME_DIR");
    if (!dir || !dir[0]) return 0;
    const char *name = getenv("PIPEWIRE_REMOTE");
    if (!name || !name[0]) name = "pipewire-0";
    char path[512];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    return access(path, F_OK) == 0;
}

// --- Stream events (fire on the stream's own loop thread) ---

static void _on_state_changed(void *data, enum pw_stream_state old,
                              enum pw_stream_state state, const char *error) {
    PwCast *c = data;
    (void)old;
    if (state == PW_STREAM_STATE_ERROR) {
        fprintf(stderr, "[PwCast] stream error: %s\n", error ? error : "?");
        c->failed = 1;
    } else if (state == PW_STREAM_STATE_PAUSED ||
               state == PW_STREAM_STATE_STREAMING) {
        c->ready = 1;
    }
    pw_thread_loop_signal(c->loop, false);
}

// The daemon accepted our format — announce the buffers we want it to
// allocate (single-plane RGBA, mapped into us by FLAG_MAP_BUFFERS).
static void _on_param_changed(void *data, uint32_t id,
                              const struct spa_pod *param) {
    PwCast *c = data;
    if (id != SPA_PARAM_Format || param == NULL) return;

    uint8_t buffer[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    const struct spa_pod *params[1];
    params[0] = spa_pod_builder_add_object(&b,
        SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
        SPA_PARAM_BUFFERS_buffers,  SPA_POD_CHOICE_RANGE_Int(4, 2, 8),
        SPA_PARAM_BUFFERS_blocks,   SPA_POD_Int(1),
        SPA_PARAM_BUFFERS_size,     SPA_POD_Int((int32_t)(c->stride * c->height)),
        SPA_PARAM_BUFFERS_stride,   SPA_POD_Int((int32_t)c->stride),
        SPA_PARAM_BUFFERS_dataType,
            SPA_POD_CHOICE_FLAGS_Int((1 << SPA_DATA_MemFd) |
                                     (1 << SPA_DATA_MemPtr)));
    pw_stream_update_params(c->stream, params, 1);
}

static const struct pw_stream_events stream_events = {
    PW_VERSION_STREAM_EVENTS,
    .state_changed = _on_state_changed,
    .param_changed = _on_param_changed,
};

// --- Public API ---

PwCast *pwcast_start(uint32_t width, uint32_t height) {
    pthread_once(&pw_init_once, _pw_init);

    PwCast *c = calloc(1, sizeof(PwCast));
    if (!c) return NULL;
    c->width = width;
    c->height = height;
    c->stride = width * 4;

    c->loop = pw_thread_loop_new("starling-screencast", NULL);
    if (!c->loop) { free(c); return NULL; }
    if (pw_thread_loop_start(c->loop) < 0) {
        pw_thread_loop_destroy(c->loop);
        free(c);
        return NULL;
    }

    pw_thread_loop_lock(c->loop);
    c->stream = pw_stream_new_simple(
        pw_thread_loop_get_loop(c->loop), "starling-screencast",
        pw_properties_new(PW_KEY_MEDIA_CLASS, "Video/Source",
                          PW_KEY_MEDIA_TYPE, "Video",
                          PW_KEY_MEDIA_ROLE, "Screen",
                          PW_KEY_NODE_NAME, "starling-screencast",
                          NULL),
        &stream_events, c);
    if (!c->stream) {
        pw_thread_loop_unlock(c->loop);
        goto fail;
    }

    // Fixed size, variable framerate (0/1) — the portal-stream convention:
    // frames arrive when the screen changes, maxFramerate bounds a consumer
    // that wants to negotiate pacing.
    uint8_t pod_buf[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(pod_buf, sizeof(pod_buf));
    const struct spa_pod *params[1];
    struct spa_rectangle size = SPA_RECTANGLE(width, height);
    struct spa_fraction rate_var = SPA_FRACTION(0, 1);
    struct spa_fraction rate_def = SPA_FRACTION(30, 1);
    struct spa_fraction rate_min = SPA_FRACTION(1, 1);
    struct spa_fraction rate_max = SPA_FRACTION(60, 1);
    params[0] = spa_pod_builder_add_object(&b,
        SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
        SPA_FORMAT_mediaType,        SPA_POD_Id(SPA_MEDIA_TYPE_video),
        SPA_FORMAT_mediaSubtype,     SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
        SPA_FORMAT_VIDEO_format,     SPA_POD_Id(SPA_VIDEO_FORMAT_RGBA),
        SPA_FORMAT_VIDEO_size,       SPA_POD_Rectangle(&size),
        SPA_FORMAT_VIDEO_framerate,  SPA_POD_Fraction(&rate_var),
        SPA_FORMAT_VIDEO_maxFramerate,
            SPA_POD_CHOICE_RANGE_Fraction(&rate_def, &rate_min, &rate_max));

    if (pw_stream_connect(c->stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
                          PW_STREAM_FLAG_DRIVER | PW_STREAM_FLAG_MAP_BUFFERS,
                          params, 1) < 0) {
        pw_thread_loop_unlock(c->loop);
        goto fail;
    }

    // Wait for the daemon to bind the node (ready) — that is when the node
    // id exists for the portal to hand out.
    for (int waited = 0; !c->ready && !c->failed && waited < 3; waited++)
        pw_thread_loop_timed_wait(c->loop, 1);
    uint32_t node = c->stream ? pw_stream_get_node_id(c->stream) : SPA_ID_INVALID;
    pw_thread_loop_unlock(c->loop);

    if (!c->ready || c->failed || node == SPA_ID_INVALID) {
        fprintf(stderr, "[PwCast] stream never became ready (node=%u)\n", node);
        goto fail;
    }
    fprintf(stderr, "[PwCast] streaming %ux%u as node %u\n", width, height, node);
    return c;

fail:
    pwcast_stop(c);
    return NULL;
}

uint32_t pwcast_node_id(PwCast *c) {
    if (!c || !c->stream) return SPA_ID_INVALID;
    pw_thread_loop_lock(c->loop);
    uint32_t id = pw_stream_get_node_id(c->stream);
    pw_thread_loop_unlock(c->loop);
    return id;
}

void pwcast_push_frame(PwCast *c, const uint8_t *rgba,
                       uint32_t width, uint32_t height) {
    if (!c || !c->stream || width != c->width || height != c->height) return;

    pw_thread_loop_lock(c->loop);
    struct pw_buffer *b = pw_stream_dequeue_buffer(c->stream);
    if (b) {
        struct spa_data *d = &b->buffer->datas[0];
        uint32_t bytes = c->stride * c->height;
        if (d->data && d->maxsize >= bytes) {
            memcpy(d->data, rgba, bytes);
            d->chunk->offset = 0;
            d->chunk->stride = (int32_t)c->stride;
            d->chunk->size = bytes;
        }
        pw_stream_queue_buffer(c->stream, b);
    }
    pw_thread_loop_unlock(c->loop);
}

void pwcast_stop(PwCast *c) {
    if (!c) return;
    if (c->loop) {
        if (c->stream) {
            pw_thread_loop_lock(c->loop);
            pw_stream_destroy(c->stream);
            c->stream = NULL;
            pw_thread_loop_unlock(c->loop);
        }
        pw_thread_loop_stop(c->loop);
        pw_thread_loop_destroy(c->loop);
    }
    free(c);
}
