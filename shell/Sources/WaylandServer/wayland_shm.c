// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_shm.c — wl_shm and wl_shm_pool implementation
 *
 * Implements shared memory buffer support so standard Wayland clients
 * (that don't use DMA-BUF) can render via mmap'd pixel buffers.
 */

#define _GNU_SOURCE  /* for mremap */
#include "wayland_server_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

/* ------------------------------------------------------------------ */
/* ShmPool lifecycle                                                    */
/* ------------------------------------------------------------------ */

static void shm_pool_ref(struct ShmPool* pool) {
    pool->refcount++;
}

static void shm_pool_unref(struct ShmPool* pool) {
    if (--pool->refcount <= 0) {
        if (pool->data && pool->data != MAP_FAILED)
            munmap(pool->data, pool->size);
        if (pool->fd >= 0)
            close(pool->fd);
        free(pool);
    }
}

/* ------------------------------------------------------------------ */
/* wl_buffer interface (for SHM buffers)                                */
/* ------------------------------------------------------------------ */

static void shm_buffer_destroy_request(struct wl_client* client,
                                        struct wl_resource* resource) {
    wl_resource_destroy(resource);
}

static const struct wl_buffer_interface shm_buffer_impl = {
    .destroy = shm_buffer_destroy_request,
};

static void shm_buffer_destroy(struct wl_resource* resource) {
    struct ShmBuffer* buf = wl_resource_get_user_data(resource);
    if (buf) {
        if (buf->pool)
            shm_pool_unref(buf->pool);
        free(buf);
    }
}

/* ------------------------------------------------------------------ */
/* wl_shm_pool implementation                                           */
/* ------------------------------------------------------------------ */

static void shm_pool_create_buffer(struct wl_client* client,
                                    struct wl_resource* resource,
                                    uint32_t id,
                                    int32_t offset,
                                    int32_t width, int32_t height,
                                    int32_t stride, uint32_t format) {
    struct ShmPool* pool = wl_resource_get_user_data(resource);
    if (!pool) {
        wl_resource_post_error(resource, 0, "invalid pool");
        return;
    }

    /* Validate that the buffer fits in the pool */
    size_t needed = (size_t)offset + (size_t)stride * (size_t)height;
    if (needed > pool->size || offset < 0 || width <= 0 || height <= 0 || stride <= 0) {
        wl_resource_post_error(resource, 0,
            "buffer does not fit in pool (need %zu, pool %zu)",
            needed, pool->size);
        return;
    }

    struct ShmBuffer* buf = calloc(1, sizeof(struct ShmBuffer));
    if (!buf) {
        wl_resource_post_no_memory(resource);
        return;
    }

    buf->type = BUFFER_TYPE_SHM;
    buf->pool = pool;
    shm_pool_ref(pool);
    buf->offset = offset;
    buf->width = width;
    buf->height = height;
    buf->stride = stride;
    buf->format = format;

    struct wl_resource* buffer_resource = wl_resource_create(client,
        &wl_buffer_interface, 1, id);
    if (!buffer_resource) {
        shm_pool_unref(pool);
        free(buf);
        wl_resource_post_no_memory(resource);
        return;
    }

    wl_resource_set_implementation(buffer_resource, &shm_buffer_impl,
                                   buf, shm_buffer_destroy);
    buf->resource = buffer_resource;
}

static void shm_pool_destroy(struct wl_client* client,
                              struct wl_resource* resource) {
    wl_resource_destroy(resource);
}

static void shm_pool_resize(struct wl_client* client,
                             struct wl_resource* resource,
                             int32_t size) {
    struct ShmPool* pool = wl_resource_get_user_data(resource);
    if (!pool) return;

    if ((size_t)size <= pool->size)
        return;

    /* Validate the claimed size against the backing file. mremap happily
     * maps past EOF; the SIGBUS then comes later, on the first pixel read,
     * killing the whole shell. Reject undersized files up front. */
    struct stat st;
    if (fstat(pool->fd, &st) == 0 && st.st_size < (off_t)size) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD,
                               "pool resize to %d exceeds backing file size %lld",
                               size, (long long)st.st_size);
        return;
    }

    /* Re-mmap with the larger size */
    void* new_data = mremap(pool->data, pool->size, (size_t)size, MREMAP_MAYMOVE);
    if (new_data == MAP_FAILED) {
        wl_resource_post_error(resource, 0, "mremap failed");
        return;
    }

    pool->data = new_data;
    pool->size = (size_t)size;
}

static const struct wl_shm_pool_interface shm_pool_impl = {
    .create_buffer = shm_pool_create_buffer,
    .destroy = shm_pool_destroy,
    .resize = shm_pool_resize,
};

static void shm_pool_resource_destroy(struct wl_resource* resource) {
    struct ShmPool* pool = wl_resource_get_user_data(resource);
    if (pool)
        shm_pool_unref(pool);
}

/* ------------------------------------------------------------------ */
/* wl_shm implementation                                                */
/* ------------------------------------------------------------------ */

static void shm_create_pool(struct wl_client* client,
                             struct wl_resource* resource,
                             uint32_t id, int32_t fd, int32_t size) {
    if (size <= 0) {
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_STRIDE,
                               "invalid pool size %d", size);
        close(fd);
        return;
    }

    /* Same SIGBUS guard as resize: the mapping must be backed by real file
     * bytes or the first read faults. */
    {
        struct stat st;
        if (fstat(fd, &st) == 0 && st.st_size < (off_t)size) {
            wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD,
                                   "pool size %d exceeds backing file size %lld",
                                   size, (long long)st.st_size);
            close(fd);
            return;
        }
    }

    struct ShmPool* pool = calloc(1, sizeof(struct ShmPool));
    if (!pool) {
        close(fd);
        wl_resource_post_no_memory(resource);
        return;
    }

    pool->fd = fd;
    pool->size = (size_t)size;
    pool->refcount = 1;  /* The pool resource itself holds a ref */

    pool->data = mmap(NULL, pool->size, PROT_READ, MAP_SHARED, fd, 0);
    if (pool->data == MAP_FAILED) {
        fprintf(stderr, "[wayland_shm] mmap failed for pool fd=%d size=%d\n", fd, size);
        close(fd);
        free(pool);
        wl_resource_post_error(resource, WL_SHM_ERROR_INVALID_FD,
                               "mmap failed");
        return;
    }

    struct wl_resource* pool_resource = wl_resource_create(client,
        &wl_shm_pool_interface, wl_resource_get_version(resource), id);
    if (!pool_resource) {
        munmap(pool->data, pool->size);
        close(fd);
        free(pool);
        wl_resource_post_no_memory(resource);
        return;
    }

    wl_resource_set_implementation(pool_resource, &shm_pool_impl,
                                   pool, shm_pool_resource_destroy);

    /* Pool created successfully. */
}

static void shm_release(struct wl_client* client,
                         struct wl_resource* resource) {
    wl_resource_destroy(resource);
}

static const struct wl_shm_interface shm_impl = {
    .create_pool = shm_create_pool,
    .release = shm_release,
};

/* ------------------------------------------------------------------ */
/* Global bind — advertise supported formats                            */
/* ------------------------------------------------------------------ */

static void shm_bind(struct wl_client* client, void* data,
                      uint32_t version, uint32_t id) {
    struct wl_resource* resource = wl_resource_create(client,
        &wl_shm_interface, version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }

    wl_resource_set_implementation(resource, &shm_impl, data, NULL);

    /* Advertise supported pixel formats.
     * ARGB8888 and XRGB8888 are mandatory per the protocol spec. */
    wl_shm_send_format(resource, WL_SHM_FORMAT_ARGB8888);
    wl_shm_send_format(resource, WL_SHM_FORMAT_XRGB8888);
}

/* ------------------------------------------------------------------ */
/* Public init function                                                 */
/* ------------------------------------------------------------------ */

void wayland_shm_init(struct WaylandServer* server) {
    /* wl_shm version 1 is sufficient — version 2 adds release() which
     * we implement as a no-op. Advertise version 1 for max compatibility. */
    server->shm_global = wl_global_create(server->display,
        &wl_shm_interface, 1, server, shm_bind);
}
