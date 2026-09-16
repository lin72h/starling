// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_single_pixel_buffer.c — wp_single_pixel_buffer_manager_v1
 *
 * A 1x1 wl_buffer of one colour, without the client allocating shared
 * memory for it. GTK4, Mutter's clients and Chromium use it for solid
 * backdrops and subsurface fills; without it they fall back to an shm pool
 * per colour. The buffer is an ordinary ShmBuffer over a private anonymous
 * page, so every path that consumes wl_shm buffers consumes this one
 * unchanged — the ShmPool holds no fd and is unmapped with its last ref.
 */

#include "wayland_server_internal.h"
#include "single-pixel-buffer-v1-protocol.h"
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

static void buffer_destroy_request(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct wl_buffer_interface buffer_impl = {
    .destroy = buffer_destroy_request,
};

static void buffer_resource_destroyed(struct wl_resource* r) {
    struct ShmBuffer* buf = wl_resource_get_user_data(r);
    if (!buf) return;
    if (buf->pool) {
        if (--buf->pool->refcount <= 0) {
            if (buf->pool->data && buf->pool->data != MAP_FAILED)
                munmap(buf->pool->data, buf->pool->size);
            free(buf->pool);
        }
    }
    free(buf);
}

static void manager_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void manager_create_buffer(struct wl_client* client,
                                  struct wl_resource* resource, uint32_t id,
                                  uint32_t r, uint32_t g, uint32_t b, uint32_t a) {
    (void)resource;
    struct ShmPool* pool = calloc(1, sizeof(*pool));
    struct ShmBuffer* buf = calloc(1, sizeof(*buf));
    if (!pool || !buf) {
        free(pool);
        free(buf);
        wl_client_post_no_memory(client);
        return;
    }
    pool->fd = -1;
    pool->size = 4096;
    pool->refcount = 1;
    pool->data = mmap(NULL, pool->size, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (pool->data == MAP_FAILED) {
        free(pool);
        free(buf);
        wl_client_post_no_memory(client);
        return;
    }
    /* wl_shm ARGB8888 is B,G,R,A in memory; the channels arrive as 32-bit
     * premultiplied values, of which the top byte is the 8-bit one. */
    uint8_t* px = pool->data;
    px[0] = (uint8_t)(b >> 24);
    px[1] = (uint8_t)(g >> 24);
    px[2] = (uint8_t)(r >> 24);
    px[3] = (uint8_t)(a >> 24);

    buf->type = BUFFER_TYPE_SHM;
    buf->pool = pool;
    buf->offset = 0;
    buf->width = 1;
    buf->height = 1;
    buf->stride = 4;
    buf->format = WL_SHM_FORMAT_ARGB8888;

    struct wl_resource* br = wl_resource_create(client, &wl_buffer_interface, 1, id);
    if (!br) {
        munmap(pool->data, pool->size);
        free(pool);
        free(buf);
        wl_client_post_no_memory(client);
        return;
    }
    buf->resource = br;
    wl_resource_set_implementation(br, &buffer_impl, buf, buffer_resource_destroyed);
}

static const struct wp_single_pixel_buffer_manager_v1_interface manager_impl = {
    .destroy = manager_destroy,
    .create_u32_rgba_buffer = manager_create_buffer,
};

static void manager_bind(struct wl_client* client, void* data,
                         uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client,
        &wp_single_pixel_buffer_manager_v1_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &manager_impl, data, NULL);
}

void wayland_single_pixel_buffer_init(struct WaylandServer* server) {
    server->single_pixel_buffer_global = wl_global_create(server->display,
        &wp_single_pixel_buffer_manager_v1_interface, 1, server, manager_bind);
}
