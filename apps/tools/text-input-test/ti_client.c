/* Minimal zwp_text_input_v3 test client: maps a 300x200 SHM toplevel,
 * enables text input on keyboard enter, and prints every IME event. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "text-input-v3-client.h"
#include "xdg-shell-client.h"

static struct wl_compositor* compositor;
static struct wl_shm* shm;
static struct wl_seat* seat;
static struct xdg_wm_base* wm_base;
static struct zwp_text_input_manager_v3* ti_manager;
static struct zwp_text_input_v3* ti;
static struct wl_surface* surface;
static int configured;

static void registry_global(void* data, struct wl_registry* reg, uint32_t name,
                            const char* iface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(iface, wl_compositor_interface.name))
        compositor = wl_registry_bind(reg, name, &wl_compositor_interface, 4);
    else if (!strcmp(iface, wl_shm_interface.name))
        shm = wl_registry_bind(reg, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, wl_seat_interface.name))
        seat = wl_registry_bind(reg, name, &wl_seat_interface, 5);
    else if (!strcmp(iface, xdg_wm_base_interface.name))
        wm_base = wl_registry_bind(reg, name, &xdg_wm_base_interface, 1);
    else if (!strcmp(iface, zwp_text_input_manager_v3_interface.name))
        ti_manager = wl_registry_bind(reg, name,
                                      &zwp_text_input_manager_v3_interface, 1);
}
static void registry_remove(void* d, struct wl_registry* r, uint32_t n) {
    (void)d; (void)r; (void)n;
}
static const struct wl_registry_listener registry_listener = {
    registry_global, registry_remove
};

/* text-input events */
static void ti_enter(void* d, struct zwp_text_input_v3* t,
                     struct wl_surface* s) {
    (void)d; (void)s;
    printf("TI: enter\n");
    fflush(stdout);
    zwp_text_input_v3_enable(t);
    zwp_text_input_v3_set_cursor_rectangle(t, 40, 60, 2, 18);
    zwp_text_input_v3_commit(t);
}
static void ti_leave(void* d, struct zwp_text_input_v3* t,
                     struct wl_surface* s) {
    (void)d; (void)t; (void)s;
    printf("TI: leave\n");
    fflush(stdout);
}
static void ti_preedit(void* d, struct zwp_text_input_v3* t, const char* text,
                       int32_t cb, int32_t ce) {
    (void)d; (void)t;
    printf("TI: preedit '%s' cursor=%d..%d\n", text ? text : "", cb, ce);
    fflush(stdout);
}
static void ti_commit_string(void* d, struct zwp_text_input_v3* t,
                             const char* text) {
    (void)d; (void)t;
    printf("TI: commit_string '%s'\n", text ? text : "");
    fflush(stdout);
}
static void ti_delete(void* d, struct zwp_text_input_v3* t, uint32_t b,
                      uint32_t a) {
    (void)d; (void)t; (void)b; (void)a;
}
static void ti_done(void* d, struct zwp_text_input_v3* t, uint32_t serial) {
    (void)d; (void)t;
    printf("TI: done serial=%u\n", serial);
    fflush(stdout);
}
static const struct zwp_text_input_v3_listener ti_listener = {
    ti_enter, ti_leave, ti_preedit, ti_commit_string, ti_delete, ti_done
};

static void xdg_surface_configure(void* d, struct xdg_surface* xs,
                                  uint32_t serial) {
    (void)d;
    xdg_surface_ack_configure(xs, serial);
    configured = 1;
}
static const struct xdg_surface_listener xdg_surface_listener = {
    xdg_surface_configure
};
static void wm_ping(void* d, struct xdg_wm_base* b, uint32_t serial) {
    (void)d;
    xdg_wm_base_pong(b, serial);
}
static const struct xdg_wm_base_listener wm_listener = { wm_ping };
static void toplevel_configure(void* d, struct xdg_toplevel* t, int32_t w,
                               int32_t h, struct wl_array* s) {
    (void)d; (void)t; (void)w; (void)h; (void)s;
}
static void toplevel_close(void* d, struct xdg_toplevel* t) {
    (void)d; (void)t;
    exit(0);
}
static const struct xdg_toplevel_listener toplevel_listener = {
    toplevel_configure, toplevel_close
};

int main(void) {
    struct wl_display* display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "connect failed\n");
        return 1;
    }
    struct wl_registry* reg = wl_display_get_registry(display);
    wl_registry_add_listener(reg, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !wm_base || !ti_manager || !seat) {
        fprintf(stderr, "missing globals: comp=%p shm=%p wm=%p ti=%p seat=%p\n",
                (void*)compositor, (void*)shm, (void*)wm_base,
                (void*)ti_manager, (void*)seat);
        return 1;
    }
    printf("TI: globals bound\n");
    fflush(stdout);

    xdg_wm_base_add_listener(wm_base, &wm_listener, NULL);
    ti = zwp_text_input_manager_v3_get_text_input(ti_manager, seat);
    zwp_text_input_v3_add_listener(ti, &ti_listener, NULL);

    surface = wl_compositor_create_surface(compositor);
    struct xdg_surface* xs = xdg_wm_base_get_xdg_surface(wm_base, surface);
    xdg_surface_add_listener(xs, &xdg_surface_listener, NULL);
    struct xdg_toplevel* tl = xdg_surface_get_toplevel(xs);
    xdg_toplevel_add_listener(tl, &toplevel_listener, NULL);
    xdg_toplevel_set_title(tl, "TI Test");
    wl_surface_commit(surface);
    while (!configured) wl_display_dispatch(display);

    /* 300x200 XRGB shm buffer */
    int w = 300, h = 200, stride = w * 4, size = stride * h;
    int fd = memfd_create("ti", MFD_CLOEXEC);
    if (ftruncate(fd, size) < 0) return 1;
    uint32_t* pix = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    for (int i = 0; i < w * h; i++) pix[i] = 0xFF335577;
    struct wl_shm_pool* pool = wl_shm_create_pool(shm, fd, size);
    struct wl_buffer* buf =
        wl_shm_pool_create_buffer(pool, 0, w, h, stride, WL_SHM_FORMAT_XRGB8888);
    wl_surface_attach(surface, buf, 0, 0);
    wl_surface_commit(surface);
    printf("TI: mapped\n");
    fflush(stdout);

    while (wl_display_dispatch(display) != -1) {}
    return 0;
}
