// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * The compositor's protocol layer, tested without a GPU, a display or the
 * shell: the C server (shell/Sources/WaylandServer) is linked in and run on
 * its own thread, a libwayland client connects to it in this process, and
 * every protocol the shell relies on is driven end to end — the client makes
 * the requests, the server's callbacks (what the shell would receive) are
 * checked, the shell's answers are fed back through the public API, and the
 * events the client gets are checked.
 *
 * What it catches is the failure this codebase has had twice: a protocol that
 * is declared, generated and dispatched, and does nothing — because a
 * callback was never registered, a role never reached the commit path, or a
 * global's version drifted from what the module implements.
 *
 * Built by test/wayland/run.sh (client bindings from the system XML, server
 * sources straight from the tree), run by test/run.sh in the fast tier.
 */

#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wayland_server.h"

#include "xdg-shell-client-protocol.h"
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"
#include "ext-foreign-toplevel-list-v1-client-protocol.h"
#include "wlr-screencopy-unstable-v1-client-protocol.h"
#include "alpha-modifier-v1-client-protocol.h"
#include "xx-zones-v1-client-protocol.h"
#include "xdg-activation-v1-client-protocol.h"
#include "single-pixel-buffer-v1-client-protocol.h"
#include "ext-idle-notify-v1-client-protocol.h"
#include "keyboard-shortcuts-inhibit-unstable-v1-client-protocol.h"
#include "ext-data-control-v1-client-protocol.h"
#include "xdg-foreign-unstable-v2-client-protocol.h"
#include "ext-image-capture-source-v1-client-protocol.h"
#include "ext-image-copy-capture-v1-client-protocol.h"
#include "security-context-v1-client-protocol.h"
#include "wlr-output-management-unstable-v1-client-protocol.h"
#include "ext-session-lock-v1-client-protocol.h"
#include "ext-workspace-v1-client-protocol.h"
#include "ext-background-effect-v1-client-protocol.h"
#include "ext-transient-seat-v1-client-protocol.h"
#include "pointer-warp-v1-client-protocol.h"
#include "xdg-toplevel-drag-v1-client-protocol.h"
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"
#include "virtual-keyboard-unstable-v1-client-protocol.h"
#include "primary-selection-unstable-v1-client-protocol.h"
#include <xkbcommon/xkbcommon.h>
#include <sys/socket.h>
#include <sys/un.h>

static int failures = 0;
#define CHECK(cond, ...)                                          \
    do {                                                          \
        if (!(cond)) {                                            \
            printf("  FAIL %s:%d: ", __func__, __LINE__);         \
            printf(__VA_ARGS__);                                  \
            printf("\n");                                         \
            failures++;                                           \
        }                                                         \
    } while (0)

/* ------------------------------------------------------------------------ */
/* The server, on its own thread, with a task queue for the API calls the   */
/* shell would make from the event-loop thread.                             */
/* ------------------------------------------------------------------------ */

static WaylandServer* server;
static pthread_t server_thread;
static atomic_int server_stop;
static int task_pipe[2];
typedef void (*task_fn)(void*);
struct task { task_fn fn; void* arg; };

static void* server_main(void* arg) {
    (void)arg;
    int fd = wayland_server_get_fd(server);
    while (!atomic_load(&server_stop)) {
        struct pollfd p[2] = {
            { .fd = fd, .events = POLLIN },
            { .fd = task_pipe[0], .events = POLLIN },
        };
        wayland_server_flush_clients(server);
        int n = poll(p, 2, 20);
        if (n < 0 && errno != EINTR) break;
        if (p[1].revents & POLLIN) {
            struct task t;
            while (read(task_pipe[0], &t, sizeof(t)) == (ssize_t)sizeof(t)) {
                t.fn(t.arg);
            }
        }
        /* Dispatch even when poll timed out: the deferred input pipe and
         * timers live inside the server's own loop. */
        wayland_server_dispatch(server);
        wayland_server_flush_clients(server);
    }
    return NULL;
}

/* Run fn(arg) on the server thread and wait for it. */
static void on_server(task_fn fn, void* arg) {
    struct task t = { fn, arg };
    ssize_t w = write(task_pipe[1], &t, sizeof(t));
    (void)w;
    /* The queue is drained within one poll timeout; give it two. */
    struct timespec ts = { 0, 60 * 1000 * 1000 };
    nanosleep(&ts, NULL);
}

/* ------------------------------------------------------------------------ */
/* What the shell would hear                                                */
/* ------------------------------------------------------------------------ */

static pthread_mutex_t seen_mu = PTHREAD_MUTEX_INITIALIZER;
static struct {
    uint32_t new_toplevel_id;
    int new_toplevel_count;
    uint32_t last_request_surface;
    int last_request;
    int request_count;
    uint32_t layer_surface_id;
    WaylandLayerSurfaceInfo layer_info;
    int layer_count;
    int layer_destroy_count;
    uint32_t alpha_surface;
    double alpha;
    uint32_t shm_surface;
    int shm_w, shm_h;
    uint32_t shm_format;
    uint8_t shm_px[4];
    int shm_count;
    uint32_t screencopy_frame;
    int screencopy_w, screencopy_h, screencopy_x, screencopy_y;
    uint32_t position_surface;
    int32_t position_x, position_y;
    int position_count;
    uint32_t bell_surface;
    int bell_count;
    uint32_t inhibit_surface;
    int inhibited;
    int inhibit_count;
    int locked;
    int lock_count;
    char title[64];
    int shm_keep_alpha;
    uint32_t ws_id; int ws_request; char ws_name[64]; int ws_count;
    uint32_t blur_surface; int blur_count; int32_t blur_rect0[4]; int blur_events;
    int vp_count, vp_has_abs; double vp_ax, vp_ay, vp_dx, vp_dy; uint32_t vp_buttons; double vp_wheel_dy;
    int vk_count; uint32_t vk_evdev, vk_keysym; char vk_utf8[16]; int vk_pressed;
    uint32_t warp_surface; double warp_x, warp_y; int warp_count;
    uint32_t drag_icon; int drag_active; int drag_icon_count;
    uint32_t tdrag_surface; int32_t tdrag_x, tdrag_y; int tdrag_active; int tdrag_count;
    uint32_t outcfg_id; double outcfg_scale; int outcfg_count;
    uint32_t hints_surface; int32_t min_w, min_h, max_w, max_h; int hints_count;
    uint32_t popup_id; int popup_count;
    uint32_t sub_id, sub_top; int32_t sub_x, sub_y, sub_z; int sub_placed;
    uint32_t watch_shm_sid; int watch_shm_count;
    uint32_t sub_unmapped_id; int sub_unmapped;
    uint32_t parent_child, parent_parent; int parent_count;
} seen;

#define LOCKED(stmt) do { pthread_mutex_lock(&seen_mu); stmt; pthread_mutex_unlock(&seen_mu); } while (0)

static void cb_size_hints(void* ctx, uint32_t sid, int32_t min_w, int32_t min_h,
                          int32_t max_w, int32_t max_h) {
    (void)ctx;
    LOCKED(seen.hints_surface = sid; seen.min_w = min_w; seen.min_h = min_h;
           seen.max_w = max_w; seen.max_h = max_h; seen.hints_count++);
}
static void cb_new_popup(void* ctx, uint32_t sid, uint32_t parent, int x, int y, int w, int h) {
    (void)ctx; (void)parent; (void)x; (void)y; (void)w; (void)h;
    LOCKED(seen.popup_id = sid; seen.popup_count++);
}
static void cb_sub_placed(void* ctx, uint32_t sid, uint32_t top, int32_t x, int32_t y, int32_t z) {
    (void)ctx;
    LOCKED(seen.sub_id = sid; seen.sub_top = top; seen.sub_x = x; seen.sub_y = y; seen.sub_z = z;
           seen.sub_placed++);
}
static void cb_sub_unmapped(void* ctx, uint32_t sid) {
    (void)ctx;
    LOCKED(seen.sub_unmapped_id = sid; seen.sub_unmapped++);
}
static void cb_parent(void* ctx, uint32_t sid, uint32_t parent) {
    (void)ctx;
    LOCKED(seen.parent_child = sid; seen.parent_parent = parent; seen.parent_count++);
}
static void cb_new_toplevel(void* ctx, uint32_t sid, uint64_t client) {
    (void)ctx; (void)client;
    LOCKED(seen.new_toplevel_id = sid; seen.new_toplevel_count++);
}
static void cb_title(void* ctx, uint32_t sid, const char* title) {
    (void)ctx; (void)sid;
    LOCKED(snprintf(seen.title, sizeof(seen.title), "%s", title));
}
static void cb_request(void* ctx, uint32_t sid, int request) {
    (void)ctx;
    LOCKED(seen.last_request_surface = sid; seen.last_request = request; seen.request_count++);
}
static void cb_new_layer(void* ctx, uint32_t sid, const WaylandLayerSurfaceInfo* info) {
    (void)ctx;
    LOCKED(seen.layer_surface_id = sid; seen.layer_info = *info; seen.layer_count++);
}
static void cb_layer_changed(void* ctx, uint32_t sid, const WaylandLayerSurfaceInfo* info) {
    (void)ctx;
    LOCKED(seen.layer_surface_id = sid; seen.layer_info = *info; seen.layer_count++);
}
static void cb_layer_destroy(void* ctx, uint32_t sid) {
    (void)ctx; (void)sid;
    LOCKED(seen.layer_destroy_count++);
}
static void cb_alpha(void* ctx, uint32_t sid, double alpha) {
    (void)ctx;
    LOCKED(seen.alpha_surface = sid; seen.alpha = alpha);
}
static void cb_shm(void* ctx, uint32_t sid, const void* px, int w, int h, int stride,
                   uint32_t format, int first, int scale, int keep_alpha) {
    LOCKED(if (seen.watch_shm_sid && sid == seen.watch_shm_sid) seen.watch_shm_count++);
    (void)ctx; (void)stride; (void)first; (void)scale;
    LOCKED(seen.shm_surface = sid; seen.shm_w = w; seen.shm_h = h; seen.shm_format = format;
           memcpy(seen.shm_px, px, 4); seen.shm_count++; seen.shm_keep_alpha = keep_alpha);
}
static void cb_screencopy(void* ctx, uint32_t frame, int output, int32_t x, int32_t y,
                          int32_t w, int32_t h) {
    (void)ctx; (void)output;
    LOCKED(seen.screencopy_frame = frame; seen.screencopy_x = x; seen.screencopy_y = y;
           seen.screencopy_w = w; seen.screencopy_h = h);
}
static void cb_position(void* ctx, uint32_t sid, int output, int32_t x, int32_t y) {
    (void)ctx; (void)output;
    LOCKED(seen.position_surface = sid; seen.position_x = x; seen.position_y = y;
           seen.position_count++);
}
static void cb_bell(void* ctx, uint32_t sid) {
    (void)ctx;
    LOCKED(seen.bell_surface = sid; seen.bell_count++);
}
static void cb_inhibit(void* ctx, uint32_t sid, int inhibited) {
    (void)ctx;
    LOCKED(seen.inhibit_surface = sid; seen.inhibited = inhibited; seen.inhibit_count++);
}
static void cb_lock(void* ctx, int locked) {
    (void)ctx;
    LOCKED(seen.locked = locked; seen.lock_count++);
}
static void cb_workspace(void* ctx, uint32_t id, int request, const char* name) {
    (void)ctx;
    LOCKED(seen.ws_id = id; seen.ws_request = request;
           snprintf(seen.ws_name, sizeof(seen.ws_name), "%s", name ? name : ""); seen.ws_count++);
}
static void cb_blur(void* ctx, uint32_t sid, const int32_t* rects, int count) {
    (void)ctx;
    LOCKED(seen.blur_surface = sid; seen.blur_count = count;
           if (count > 0) memcpy(seen.blur_rect0, rects, sizeof(seen.blur_rect0));
           seen.blur_events++);
}
static void cb_vpointer(void* ctx, int output, int has_abs, double ax, double ay,
                        double dx, double dy, uint32_t buttons, double wdx, double wdy) {
    (void)ctx; (void)output; (void)wdx;
    LOCKED(seen.vp_count++; seen.vp_has_abs = has_abs; seen.vp_ax = ax; seen.vp_ay = ay;
           seen.vp_dx = dx; seen.vp_dy = dy; seen.vp_buttons = buttons; seen.vp_wheel_dy = wdy);
}
static void cb_vkey(void* ctx, uint32_t evdev, uint32_t keysym, const char* utf8, int pressed) {
    (void)ctx;
    LOCKED(seen.vk_count++; seen.vk_evdev = evdev; seen.vk_keysym = keysym;
           snprintf(seen.vk_utf8, sizeof(seen.vk_utf8), "%s", utf8 ? utf8 : ""); seen.vk_pressed = pressed);
}
static void cb_warp(void* ctx, uint32_t sid, double x, double y) {
    (void)ctx;
    LOCKED(seen.warp_surface = sid; seen.warp_x = x; seen.warp_y = y; seen.warp_count++);
}
static void cb_drag_icon(void* ctx, uint32_t sid, int active) {
    (void)ctx;
    LOCKED(seen.drag_icon = sid; seen.drag_active = active; seen.drag_icon_count++);
}
static void cb_tdrag(void* ctx, uint32_t sid, int32_t x, int32_t y, int active) {
    (void)ctx;
    LOCKED(seen.tdrag_surface = sid; seen.tdrag_x = x; seen.tdrag_y = y; seen.tdrag_active = active;
           seen.tdrag_count++);
}
static void cb_outcfg(void* ctx, uint32_t id, double scale) {
    (void)ctx;
    LOCKED(seen.outcfg_id = id; seen.outcfg_scale = scale; seen.outcfg_count++);
}

/* ------------------------------------------------------------------------ */
/* The client                                                               */
/* ------------------------------------------------------------------------ */

static struct wl_display* dpy;
static struct wl_compositor* compositor;
static struct wl_shm* shm;
static struct wl_seat* seat;
static struct wl_subcompositor* subcompositor;
static struct zwp_primary_selection_device_manager_v1* prim_mgr;

/* Proxies the server hands out through events (handles, heads, modes,
 * offers) that the tests read and never destroy: kept here and destroyed
 * at the end, so the leak detector's report is about the SERVER. */
static struct wl_proxy* trash[128];
static int ntrash;
#define TRASH(p) do { if (ntrash < 128) trash[ntrash++] = (struct wl_proxy*)(p); } while (0)
static struct wl_output* output;
static struct xdg_wm_base* wm_base;
static struct zwlr_layer_shell_v1* layer_shell;
static struct zwlr_foreign_toplevel_manager_v1* ftl_mgr;
static struct ext_foreign_toplevel_list_v1* ext_list;
static struct zwlr_screencopy_manager_v1* screencopy;
static struct wp_alpha_modifier_v1* alpha_mgr;
static struct xx_zone_manager_v1* zone_mgr;
static struct xdg_activation_v1* activation;
static struct wp_single_pixel_buffer_manager_v1* spb_mgr;
static struct ext_idle_notifier_v1* idle_notifier;
static struct zwp_keyboard_shortcuts_inhibit_manager_v1* inhibit_mgr;
static struct ext_data_control_manager_v1* edc_mgr;
static struct zxdg_exporter_v2* exporter;
static struct zxdg_importer_v2* importer;
static struct ext_output_image_capture_source_manager_v1* capsrc_mgr;
static struct ext_image_copy_capture_manager_v1* copycap_mgr;
static struct wp_security_context_manager_v1* secctx_mgr;
static struct zwlr_output_manager_v1* outmgr;
static struct ext_session_lock_manager_v1* lock_mgr;
static struct ext_background_effect_manager_v1* bgfx_mgr;
static struct ext_transient_seat_manager_v1* tseat_mgr;
static struct wp_pointer_warp_v1* warp;
static struct xdg_toplevel_drag_manager_v1* tdrag_mgr;
static struct zwlr_virtual_pointer_manager_v1* vptr_mgr;
static struct zwp_virtual_keyboard_manager_v1* vkbd_mgr;
static struct wl_data_device_manager* dd_mgr;
static struct wl_registry* registry;
static uint32_t outmgr_name, outmgr_version;
static uint32_t wsmgr_name;
static uint32_t seat_gname;   /* wl_seat's registry name, for a second bind */
static int globals_removed;

struct global_seen { char name[64]; uint32_t version; };
static struct global_seen globals[128];
static int nglobals;

static void reg_global(void* data, struct wl_registry* r, uint32_t id,
                       const char* iface, uint32_t ver) {
    (void)data;
    if (nglobals < 128) {
        snprintf(globals[nglobals].name, 64, "%s", iface);
        globals[nglobals].version = ver;
        nglobals++;
    }
#define BIND(var, ifc, v) if (strcmp(iface, ifc##_interface.name) == 0 && !var) \
        var = wl_registry_bind(r, id, &ifc##_interface, (ver) < (v) ? (ver) : (v))
    BIND(compositor, wl_compositor, 6);
    BIND(shm, wl_shm, 2);
    BIND(seat, wl_seat, 9);
    BIND(subcompositor, wl_subcompositor, 1);
    BIND(prim_mgr, zwp_primary_selection_device_manager_v1, 1);
    BIND(output, wl_output, 4);
    BIND(wm_base, xdg_wm_base, 7);
    BIND(layer_shell, zwlr_layer_shell_v1, 5);
    BIND(ftl_mgr, zwlr_foreign_toplevel_manager_v1, 3);
    BIND(ext_list, ext_foreign_toplevel_list_v1, 1);
    BIND(screencopy, zwlr_screencopy_manager_v1, 3);
    BIND(alpha_mgr, wp_alpha_modifier_v1, 1);
    BIND(zone_mgr, xx_zone_manager_v1, 1);
    BIND(activation, xdg_activation_v1, 1);
    BIND(spb_mgr, wp_single_pixel_buffer_manager_v1, 1);
    BIND(idle_notifier, ext_idle_notifier_v1, 2);
    BIND(inhibit_mgr, zwp_keyboard_shortcuts_inhibit_manager_v1, 1);
    BIND(edc_mgr, ext_data_control_manager_v1, 1);
    BIND(exporter, zxdg_exporter_v2, 1);
    BIND(importer, zxdg_importer_v2, 1);
    BIND(capsrc_mgr, ext_output_image_capture_source_manager_v1, 1);
    BIND(copycap_mgr, ext_image_copy_capture_manager_v1, 1);
    BIND(secctx_mgr, wp_security_context_manager_v1, 1);
    BIND(lock_mgr, ext_session_lock_manager_v1, 1);
    BIND(bgfx_mgr, ext_background_effect_manager_v1, 1);
    BIND(tseat_mgr, ext_transient_seat_manager_v1, 1);
    BIND(warp, wp_pointer_warp_v1, 1);
    BIND(tdrag_mgr, xdg_toplevel_drag_manager_v1, 1);
    BIND(vptr_mgr, zwlr_virtual_pointer_manager_v1, 2);
    BIND(vkbd_mgr, zwp_virtual_keyboard_manager_v1, 1);
    BIND(dd_mgr, wl_data_device_manager, 3);
    if (strcmp(iface, ext_workspace_manager_v1_interface.name) == 0) wsmgr_name = id;
    if (strcmp(iface, wl_seat_interface.name) == 0 && !seat_gname) seat_gname = id;
    /* Bound later, listener first: its heads arrive the moment it binds. */
    if (strcmp(iface, zwlr_output_manager_v1_interface.name) == 0) {
        outmgr_name = id;
        outmgr_version = ver < 4 ? ver : 4;
    }
#undef BIND
}
static void reg_gone(void* d, struct wl_registry* r, uint32_t id) { (void)d; (void)r; (void)id; globals_removed++; }
static const struct wl_registry_listener reg_listener = { reg_global, reg_gone };

static uint32_t global_version(const char* name) {
    for (int i = 0; i < nglobals; i++)
        if (strcmp(globals[i].name, name) == 0) return globals[i].version;
    return 0;
}

/* Pump the client until `cond` (a pointer to an int) becomes non-zero or
 * `ms` pass. Returns the flag's final value. */
static int wait_for(volatile int* cond, int ms) {
    struct timespec start;
    clock_gettime(CLOCK_MONOTONIC, &start);
    while (!*cond) {
        wl_display_flush(dpy);
        struct pollfd p = { .fd = wl_display_get_fd(dpy), .events = POLLIN };
        while (wl_display_prepare_read(dpy) != 0) wl_display_dispatch_pending(dpy);
        if (poll(&p, 1, 10) > 0) wl_display_read_events(dpy); else wl_display_cancel_read(dpy);
        wl_display_dispatch_pending(dpy);
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        long spent = (now.tv_sec - start.tv_sec) * 1000 + (now.tv_nsec - start.tv_nsec) / 1000000;
        if (spent > ms) break;
    }
    return *cond;
}

static volatile int buffers_released;
static void buf_release(void* d, struct wl_buffer* b) { (void)d; (void)b; buffers_released++; }
static const struct wl_buffer_listener buf_listener = { buf_release };

/* An shm buffer of the given size, XRGB or ARGB. */
static struct wl_buffer* make_buffer(int w, int h, uint32_t format, void** px_out) {
    int fd = memfd_create("test", MFD_CLOEXEC);
    size_t size = (size_t)w * h * 4;
    if (ftruncate(fd, (off_t)size) != 0) return NULL;
    void* px = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    memset(px, 0x42, size);
    struct wl_shm_pool* pool = wl_shm_create_pool(shm, fd, (int32_t)size);
    struct wl_buffer* b = wl_shm_pool_create_buffer(pool, 0, w, h, w * 4, format);
    wl_buffer_add_listener(b, &buf_listener, NULL);
    wl_shm_pool_destroy(pool);
    close(fd);
    if (px_out) *px_out = px;
    return b;
}

static void wm_ping(void* d, struct xdg_wm_base* b, uint32_t serial) { (void)d; xdg_wm_base_pong(b, serial); }
static const struct xdg_wm_base_listener wm_listener = { wm_ping };

/* ---- tests ------------------------------------------------------------- */

static void test_globals(void) {
    struct { const char* name; uint32_t min; } want[] = {
        { "wl_compositor", 6 }, { "wl_shm", 2 }, { "wl_seat", 9 }, { "wl_output", 4 },
        { "wl_subcompositor", 1 }, { "wl_data_device_manager", 3 },
        { "xdg_wm_base", 7 }, { "zxdg_decoration_manager_v1", 1 },
        { "zxdg_output_manager_v1", 3 }, { "xdg_activation_v1", 1 },
        { "zwp_linux_dmabuf_v1", 4 }, { "wp_viewporter", 1 }, { "wp_presentation", 1 },
        { "wp_fractional_scale_manager_v1", 1 }, { "wp_cursor_shape_manager_v1", 1 },
        { "zwp_relative_pointer_manager_v1", 1 }, { "zwp_pointer_constraints_v1", 1 },
        { "zwp_text_input_manager_v3", 1 }, { "zwp_idle_inhibit_manager_v1", 1 },
        { "zwp_primary_selection_device_manager_v1", 1 },
        { "zwlr_data_control_manager_v1", 2 }, { "ext_data_control_manager_v1", 1 },
        { "zwlr_layer_shell_v1", 5 }, { "wp_alpha_modifier_v1", 1 },
        { "zwlr_foreign_toplevel_manager_v1", 3 }, { "ext_foreign_toplevel_list_v1", 1 },
        { "zwlr_screencopy_manager_v1", 3 }, { "xx_zone_manager_v1", 1 },
        { "wp_single_pixel_buffer_manager_v1", 1 }, { "wp_content_type_manager_v1", 1 },
        { "wp_tearing_control_manager_v1", 1 }, { "xdg_toplevel_tag_manager_v1", 1 },
        { "xdg_wm_dialog_v1", 1 }, { "xdg_system_bell_v1", 1 },
        { "xdg_toplevel_icon_manager_v1", 1 },
        { "zwp_keyboard_shortcuts_inhibit_manager_v1", 1 },
        { "zwp_pointer_gestures_v1", 3 }, { "zwp_tablet_manager_v2", 1 },
        { "ext_idle_notifier_v1", 2 },
        { "zxdg_exporter_v2", 1 }, { "zxdg_importer_v2", 1 },
        { "ext_output_image_capture_source_manager_v1", 1 },
        { "ext_image_copy_capture_manager_v1", 1 },
        { "wp_color_representation_manager_v1", 1 },
        { "wp_security_context_manager_v1", 1 },
        { "zwlr_output_manager_v1", 4 }, { "ext_session_lock_manager_v1", 1 },
    };
    for (size_t i = 0; i < sizeof(want) / sizeof(want[0]); i++) {
        uint32_t v = global_version(want[i].name);
        CHECK(v >= want[i].min, "%s: advertised v%u, want >= v%u", want[i].name, v, want[i].min);
    }
    CHECK(global_version("wl_seat") == 9, "two seats, both at v9");
}

/* xdg-shell: a toplevel maps, its configure carries the shell's state, a
 * client's unset_maximized reaches the shell and the answer comes back in
 * the next configure. Foreign-toplevel lists announce it with the state. */
static struct wl_surface* tl_surface;
static struct xdg_surface* tl_xdg;
static struct xdg_toplevel* tl_toplevel;
static volatile int tl_configured;
static unsigned tl_states;
static int tl_conf_w, tl_conf_h;

static void xs_configure(void* d, struct xdg_surface* s, uint32_t serial) {
    (void)d;
    xdg_surface_ack_configure(s, serial);
    tl_configured++;
}
static const struct xdg_surface_listener xs_listener = { xs_configure };
static void tl_configure(void* d, struct xdg_toplevel* t, int32_t w, int32_t h, struct wl_array* st) {
    (void)d; (void)t;
    tl_states = 0;
    uint32_t* s;
    wl_array_for_each(s, st) tl_states |= 1u << *s;
    tl_conf_w = w; tl_conf_h = h;
}
static void tl_close(void* d, struct xdg_toplevel* t) { (void)d; (void)t; }
static void tl_bounds(void* d, struct xdg_toplevel* t, int32_t w, int32_t h) { (void)d; (void)t; (void)w; (void)h; }
static volatile int tl_caps_seen;
static void tl_caps(void* d, struct xdg_toplevel* t, struct wl_array* c) { (void)d; (void)t; (void)c; tl_caps_seen = 1; }
static const struct xdg_toplevel_listener tl_listener = { tl_configure, tl_close, tl_bounds, tl_caps };

static struct { uint32_t sid; int w, h; } configure_arg;
static void task_configure(void* a) {
    (void)a;
    wayland_server_configure_toplevel(server, configure_arg.sid, configure_arg.w, configure_arg.h);
}
static struct { uint32_t sid; uint32_t states; } state_arg;
static void task_set_state(void* a) {
    (void)a;
    wayland_server_set_toplevel_state(server, state_arg.sid, state_arg.states);
}

/* foreign toplevel handle */
static struct zwlr_foreign_toplevel_handle_v1* ftl_handle;
static volatile int ftl_done;
static char ftl_title[64];
static unsigned ftl_state_bits;
static volatile int ftl_closed;
static void h_title(void* d, struct zwlr_foreign_toplevel_handle_v1* h, const char* t) { (void)d; (void)h; snprintf(ftl_title, 64, "%s", t); }
static void h_app_id(void* d, struct zwlr_foreign_toplevel_handle_v1* h, const char* a) { (void)d; (void)h; (void)a; }
static void h_out_enter(void* d, struct zwlr_foreign_toplevel_handle_v1* h, struct wl_output* o) { (void)d; (void)h; (void)o; }
static void h_out_leave(void* d, struct zwlr_foreign_toplevel_handle_v1* h, struct wl_output* o) { (void)d; (void)h; (void)o; }
static void h_state(void* d, struct zwlr_foreign_toplevel_handle_v1* h, struct wl_array* st) {
    (void)d; (void)h;
    ftl_state_bits = 0;
    uint32_t* s;
    wl_array_for_each(s, st) ftl_state_bits |= 1u << *s;
}
static void h_done(void* d, struct zwlr_foreign_toplevel_handle_v1* h) { (void)d; (void)h; ftl_done++; }
static void h_closed(void* d, struct zwlr_foreign_toplevel_handle_v1* h) { (void)d; (void)h; ftl_closed = 1; }
static void h_parent(void* d, struct zwlr_foreign_toplevel_handle_v1* h, struct zwlr_foreign_toplevel_handle_v1* p) { (void)d; (void)h; (void)p; }
static const struct zwlr_foreign_toplevel_handle_v1_listener h_listener = {
    h_title, h_app_id, h_out_enter, h_out_leave, h_state, h_done, h_closed, h_parent
};
static void m_toplevel(void* d, struct zwlr_foreign_toplevel_manager_v1* m, struct zwlr_foreign_toplevel_handle_v1* h) {
    (void)d; (void)m;
    ftl_handle = h;
    TRASH(h);
    zwlr_foreign_toplevel_handle_v1_add_listener(h, &h_listener, NULL);
}
static void m_finished(void* d, struct zwlr_foreign_toplevel_manager_v1* m) { (void)d; (void)m; }
static const struct zwlr_foreign_toplevel_manager_v1_listener m_listener = { m_toplevel, m_finished };

/* ext list */
static volatile int ext_done;
static char ext_identifier[64];
static char ext_title[64];
static void eh_closed(void* d, struct ext_foreign_toplevel_handle_v1* h) { (void)d; (void)h; }
static void eh_done(void* d, struct ext_foreign_toplevel_handle_v1* h) { (void)d; (void)h; ext_done++; }
static void eh_title(void* d, struct ext_foreign_toplevel_handle_v1* h, const char* t) { (void)d; (void)h; snprintf(ext_title, 64, "%s", t); }
static void eh_app_id(void* d, struct ext_foreign_toplevel_handle_v1* h, const char* a) { (void)d; (void)h; (void)a; }
static void eh_identifier(void* d, struct ext_foreign_toplevel_handle_v1* h, const char* id) { (void)d; (void)h; snprintf(ext_identifier, 64, "%s", id); }
static const struct ext_foreign_toplevel_handle_v1_listener eh_listener = { eh_closed, eh_done, eh_title, eh_app_id, eh_identifier };
static void el_toplevel(void* d, struct ext_foreign_toplevel_list_v1* l, struct ext_foreign_toplevel_handle_v1* h) {
    (void)d; (void)l;
    TRASH(h);
    ext_foreign_toplevel_handle_v1_add_listener(h, &eh_listener, NULL);
}
static void el_finished(void* d, struct ext_foreign_toplevel_list_v1* l) { (void)d; (void)l; }
static const struct ext_foreign_toplevel_list_v1_listener el_listener = { el_toplevel, el_finished };

static void test_toplevel_state_and_taskbars(void) {
    zwlr_foreign_toplevel_manager_v1_add_listener(ftl_mgr, &m_listener, NULL);
    ext_foreign_toplevel_list_v1_add_listener(ext_list, &el_listener, NULL);

    tl_surface = wl_compositor_create_surface(compositor);
    tl_xdg = xdg_wm_base_get_xdg_surface(wm_base, tl_surface);
    xdg_surface_add_listener(tl_xdg, &xs_listener, NULL);
    tl_toplevel = xdg_surface_get_toplevel(tl_xdg);
    xdg_toplevel_add_listener(tl_toplevel, &tl_listener, NULL);
    xdg_toplevel_set_title(tl_toplevel, "protocols-test");
    xdg_toplevel_set_app_id(tl_toplevel, "starling-test");
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);

    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.new_toplevel_count > 0); usleep(10000); }
    CHECK(got, "on_new_toplevel fired");
    CHECK(tl_caps_seen, "wm_capabilities sent to a v5+ client");
    CHECK(strcmp(seen.title, "protocols-test") == 0, "title reached the shell: %s", seen.title);
    uint32_t sid = seen.new_toplevel_id;

    /* The shell configures; the client sees MAXIMIZED (the shell's default). */
    configure_arg.sid = sid; configure_arg.w = 640; configure_arg.h = 480;
    tl_configured = 0;
    on_server(task_configure, NULL);
    CHECK(wait_for(&tl_configured, 500), "configure arrived");
    CHECK(tl_conf_w == 640 && tl_conf_h == 480, "configure size %dx%d", tl_conf_w, tl_conf_h);
    CHECK(tl_states & (1u << XDG_TOPLEVEL_STATE_MAXIMIZED), "initial configure says maximized");
    CHECK(tl_states & (1u << XDG_TOPLEVEL_STATE_ACTIVATED), "initial configure says activated");

    /* Map it: the taskbars hear of it with title and state. */
    ftl_done = 0; ext_done = 0;
    struct wl_buffer* b = make_buffer(640, 480, WL_SHM_FORMAT_XRGB8888, NULL);
    TRASH(b);
    wl_surface_attach(tl_surface, b, 0, 0);
    wl_surface_commit(tl_surface);
    CHECK(wait_for(&ftl_done, 500), "zwlr foreign toplevel handle announced");
    CHECK(strcmp(ftl_title, "protocols-test") == 0, "handle title %s", ftl_title);
    CHECK(ftl_state_bits & (1u << ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED), "handle state maximized");
    CHECK(wait_for(&ext_done, 500), "ext foreign toplevel handle announced");
    CHECK(strncmp(ext_identifier, "starling-", 9) == 0, "ext identifier %s", ext_identifier);
    CHECK(strcmp(ext_title, "protocols-test") == 0, "ext title %s", ext_title);

    /* The client asks to leave maximized; the request reaches the shell. */
    int before; LOCKED(before = seen.request_count);
    xdg_toplevel_unset_maximized(tl_toplevel);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.request_count > before); usleep(10000); }
    CHECK(got, "unset_maximized reached the shell");
    CHECK(seen.last_request == WAYLAND_TOPLEVEL_REQUEST_UNMAXIMIZE, "request %d", seen.last_request);
    CHECK(seen.last_request_surface == sid, "request names the surface");

    /* The shell grants it: a state-only configure and a handle state event. */
    state_arg.sid = sid; state_arg.states = WAYLAND_TOPLEVEL_ACTIVATED;
    tl_configured = 0; ftl_done = 0;
    on_server(task_set_state, NULL);
    CHECK(wait_for(&tl_configured, 500), "state-only configure arrived");
    CHECK(!(tl_states & (1u << XDG_TOPLEVEL_STATE_MAXIMIZED)), "configure no longer says maximized");
    CHECK(tl_conf_w == 640 && tl_conf_h == 480, "state-only configure repeats the size");
    CHECK(wait_for(&ftl_done, 500), "handle state re-sent");
    CHECK(!(ftl_state_bits & (1u << ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED)), "handle no longer maximized");
    CHECK(ftl_state_bits & (1u << ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED), "handle activated");

    /* A taskbar's request goes the same way. */
    LOCKED(before = seen.request_count);
    zwlr_foreign_toplevel_handle_v1_set_minimized(ftl_handle);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.request_count > before); usleep(10000); }
    CHECK(got && seen.last_request == WAYLAND_TOPLEVEL_REQUEST_MINIMIZE, "taskbar minimize reached the shell");
}

/* shm buffers come back the moment their pixels are copied, and whatever a
 * dying surface holds comes back too — a client's buffer pool must never
 * lose one to a popup that was shown once. */
static void test_buffer_release(void) {
    struct wl_surface* ps = wl_compositor_create_surface(compositor);
    struct xdg_surface* pxs = xdg_wm_base_get_xdg_surface(wm_base, ps);
    struct xdg_positioner* pos = xdg_wm_base_create_positioner(wm_base);
    xdg_positioner_set_size(pos, 64, 32);
    xdg_positioner_set_anchor_rect(pos, 0, 0, 1, 1);
    struct xdg_popup* popup = xdg_surface_get_popup(pxs, tl_xdg, pos);
    wl_surface_commit(ps);
    wl_display_roundtrip(dpy);

    buffers_released = 0;
    struct wl_buffer* b = make_buffer(64, 32, WL_SHM_FORMAT_ARGB8888, NULL);
    wl_surface_attach(ps, b, 0, 0);
    wl_surface_commit(ps);
    CHECK(wait_for(&buffers_released, 500), "an shm buffer is released on the commit that copied it");

    /* Attached but never committed, then the surface goes: released too. */
    buffers_released = 0;
    struct wl_buffer* b2 = make_buffer(64, 32, WL_SHM_FORMAT_ARGB8888, NULL);
    wl_surface_attach(ps, b2, 0, 0);
    xdg_popup_destroy(popup);
    xdg_surface_destroy(pxs);
    wl_surface_destroy(ps);
    CHECK(wait_for(&buffers_released, 500), "a dying surface hands its attached buffer back");
    xdg_positioner_destroy(pos);
    wl_buffer_destroy(b);
    wl_buffer_destroy(b2);
}

/* xdg-activation: a minted token raises, an invented one does nothing. */
static char token_str[128];
static volatile int token_done_seen;
static void tok_done(void* d, struct xdg_activation_token_v1* t, const char* tok) {
    (void)d; (void)t;
    snprintf(token_str, sizeof(token_str), "%s", tok);
    token_done_seen = 1;
}
static const struct xdg_activation_token_v1_listener tok_listener = { tok_done };

static void test_activation(void) {
    struct xdg_activation_token_v1* tok = xdg_activation_v1_get_activation_token(activation);
    xdg_activation_token_v1_add_listener(tok, &tok_listener, NULL);
    xdg_activation_token_v1_set_surface(tok, tl_surface);
    xdg_activation_token_v1_commit(tok);
    CHECK(wait_for(&token_done_seen, 500), "token issued");
    xdg_activation_token_v1_destroy(tok);

    int before; LOCKED(before = seen.request_count);
    xdg_activation_v1_activate(activation, "not-a-token", tl_surface);
    wl_display_roundtrip(dpy);
    usleep(50000);
    int after; LOCKED(after = seen.request_count);
    CHECK(after == before, "an invented token is ignored");

    xdg_activation_v1_activate(activation, token_str, tl_surface);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.request_count > before); usleep(10000); }
    CHECK(got && seen.last_request == WAYLAND_TOPLEVEL_REQUEST_ACTIVATE, "minted token activates");

    LOCKED(before = seen.request_count);
    xdg_activation_v1_activate(activation, token_str, tl_surface);
    wl_display_roundtrip(dpy);
    usleep(50000);
    LOCKED(after = seen.request_count);
    CHECK(after == before, "a token is single-use");
}

/* layer shell: the initial commit is answered with a configure of the
 * anchored size, the shell hears the arrangement, the buffer follows. */
static volatile int ls_configured;
static uint32_t ls_w, ls_h;
static void ls_configure(void* d, struct zwlr_layer_surface_v1* ls, uint32_t serial, uint32_t w, uint32_t h) {
    (void)d;
    zwlr_layer_surface_v1_ack_configure(ls, serial);
    ls_w = w; ls_h = h;
    ls_configured++;
}
static void ls_closed(void* d, struct zwlr_layer_surface_v1* ls) { (void)d; (void)ls; }
static const struct zwlr_layer_surface_v1_listener ls_listener = { ls_configure, ls_closed };

static void test_layer_shell(void) {
    struct wl_surface* s = wl_compositor_create_surface(compositor);
    struct zwlr_layer_surface_v1* ls = zwlr_layer_shell_v1_get_layer_surface(
        layer_shell, s, output, ZWLR_LAYER_SHELL_V1_LAYER_TOP, "test-bar");
    zwlr_layer_surface_v1_add_listener(ls, &ls_listener, NULL);
    /* A bar across the top: stretch along x, 40 high, reserve its strip. */
    zwlr_layer_surface_v1_set_size(ls, 0, 40);
    zwlr_layer_surface_v1_set_anchor(ls, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                                         ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                         ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_margin(ls, 4, 8, 0, 8);
    zwlr_layer_surface_v1_set_exclusive_zone(ls, 40);
    zwlr_layer_surface_v1_set_keyboard_interactivity(ls, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_ON_DEMAND);
    wl_surface_commit(s);
    CHECK(wait_for(&ls_configured, 500), "layer surface configured on the initial commit");
    /* The server's default output is 1280x800 at scale 1 (see main). */
    CHECK(ls_w == 1280 - 16 && ls_h == 40, "configured %ux%u, want %dx40", ls_w, ls_h, 1280 - 16);

    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.layer_count > 0); usleep(10000); }
    CHECK(got, "shell heard of the layer surface");
    CHECK(seen.layer_info.layer == 2, "layer %u", seen.layer_info.layer);
    CHECK(seen.layer_info.exclusive_zone == 40 && seen.layer_info.exclusive_edge == ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP,
          "exclusive zone %d on edge %u", seen.layer_info.exclusive_zone, seen.layer_info.exclusive_edge);
    CHECK(seen.layer_info.keyboard_interactivity == 2, "keyboard interactivity %u", seen.layer_info.keyboard_interactivity);
    CHECK(strcmp(seen.layer_info.namespace_, "test-bar") == 0, "namespace %s", seen.layer_info.namespace_);

    /* The buffer reaches the shell through the ordinary shm path. */
    int shm_before; LOCKED(shm_before = seen.shm_count);
    struct wl_buffer* b = make_buffer((int)ls_w, (int)ls_h, WL_SHM_FORMAT_ARGB8888, NULL);
    TRASH(b);
    wl_surface_attach(s, b, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.shm_count > shm_before); usleep(10000); }
    CHECK(got && seen.shm_surface == seen.layer_surface_id, "layer buffer committed to the shell");
    CHECK(seen.shm_w == (int)ls_w && seen.shm_h == 40, "layer buffer %dx%d", seen.shm_w, seen.shm_h);

    /* A popup can be parented to it. */
    struct wl_surface* ps = wl_compositor_create_surface(compositor);
    struct xdg_surface* pxs = xdg_wm_base_get_xdg_surface(wm_base, ps);
    struct xdg_positioner* pos = xdg_wm_base_create_positioner(wm_base);
    xdg_positioner_set_size(pos, 50, 50);
    xdg_positioner_set_anchor_rect(pos, 0, 0, 1, 1);
    struct xdg_popup* popup = xdg_surface_get_popup(pxs, NULL, pos);
    zwlr_layer_surface_v1_get_popup(ls, popup);
    wl_surface_commit(ps);
    wl_display_roundtrip(dpy);
    xdg_popup_destroy(popup);
    xdg_positioner_destroy(pos);
    xdg_surface_destroy(pxs);
    wl_surface_destroy(ps);

    zwlr_layer_surface_v1_destroy(ls);
    wl_surface_destroy(s);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.layer_destroy_count > 0); usleep(10000); }
    CHECK(got, "shell heard the layer surface go");
}

/* alpha modifier: the multiplier lands on commit, as a fraction. */
static void test_alpha(void) {
    struct wp_alpha_modifier_surface_v1* a = wp_alpha_modifier_v1_get_surface(alpha_mgr, tl_surface);
    wp_alpha_modifier_surface_v1_set_multiplier(a, 0x80000000u);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.alpha_surface != 0); usleep(10000); }
    CHECK(got, "alpha reached the shell");
    CHECK(seen.alpha > 0.49 && seen.alpha < 0.51, "alpha %.3f, want 0.5", seen.alpha);
    wp_alpha_modifier_surface_v1_destroy(a);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.alpha > 0.99); usleep(10000); }
    CHECK(got, "destroying the modifier restores 1.0 (got %.3f)", seen.alpha);
}

/* zones: a zone describes the work area; a positioned item is reported. */
static volatile int zone_done;
static int32_t zone_w, zone_h;
static char zone_handle[64];
static void z_size(void* d, struct xx_zone_v1* z, int32_t w, int32_t h) { (void)d; (void)z; zone_w = w; zone_h = h; }
static void z_handle(void* d, struct xx_zone_v1* z, const char* h) { (void)d; (void)z; snprintf(zone_handle, 64, "%s", h); }
static void z_done(void* d, struct xx_zone_v1* z) { (void)d; (void)z; zone_done = 1; }
static volatile int item_entered;
static void z_blocked(void* d, struct xx_zone_v1* z, struct xx_zone_item_v1* i) { (void)d; (void)z; (void)i; }
static void z_entered(void* d, struct xx_zone_v1* z, struct xx_zone_item_v1* i) { (void)d; (void)z; (void)i; item_entered = 1; }
static void z_left(void* d, struct xx_zone_v1* z, struct xx_zone_item_v1* i) { (void)d; (void)z; (void)i; }
static const struct xx_zone_v1_listener z_listener = { z_size, z_handle, z_done, z_blocked, z_entered, z_left };
static volatile int item_positioned;
static int32_t item_x, item_y;
static int32_t frame_top;
static void i_frame(void* d, struct xx_zone_item_v1* i, int32_t t, int32_t b, int32_t l, int32_t r) { (void)d; (void)i; (void)b; (void)l; (void)r; frame_top = t; }
static void i_pos(void* d, struct xx_zone_item_v1* i, int32_t x, int32_t y) { (void)d; (void)i; item_x = x; item_y = y; item_positioned++; }
static volatile int item_failed;
static void i_failed(void* d, struct xx_zone_item_v1* i) { (void)d; (void)i; item_failed = 1; }
static void i_closed(void* d, struct xx_zone_item_v1* i) { (void)d; (void)i; }
static const struct xx_zone_item_v1_listener i_listener = { i_frame, i_pos, i_failed, i_closed };

static void task_work_area(void* a) {
    (void)a;
    wayland_server_set_frame_extents(server, 28, 0, 0, 0);
    wayland_server_set_work_area(server, 0, 0, 24, 1280, 776);
}
static struct { uint32_t sid; int32_t x, y; } pos_arg;
static void task_report_position(void* a) {
    (void)a;
    wayland_server_toplevel_position(server, pos_arg.sid, pos_arg.x, pos_arg.y);
}

static void test_zones(void) {
    on_server(task_work_area, NULL);
    struct xx_zone_v1* zone = xx_zone_manager_v1_get_zone(zone_mgr, output);
    xx_zone_v1_add_listener(zone, &z_listener, NULL);
    CHECK(wait_for(&zone_done, 500), "zone announced");
    CHECK(zone_w == 1280 && zone_h == 776, "zone is the work area: %dx%d", zone_w, zone_h);
    CHECK(zone_handle[0] != '\0', "zone has a handle");

    struct xx_zone_item_v1* item = xx_zone_manager_v1_get_zone_item(zone_mgr, tl_toplevel);
    xx_zone_item_v1_add_listener(item, &i_listener, NULL);
    /* Without a zone, a position fails at once. */
    xx_zone_item_v1_set_position(item, 5, 5);
    wl_surface_commit(tl_surface);
    CHECK(wait_for(&item_failed, 500), "position without a zone fails");

    xx_zone_v1_add_item(zone, item);
    wl_surface_commit(tl_surface);
    CHECK(wait_for(&item_entered, 500), "item entered the zone");
    CHECK(wait_for(&item_positioned, 500), "initial position reported");
    CHECK(frame_top == 28, "frame extents carry the title bar: top %d", frame_top);

    item_positioned = 0;
    xx_zone_item_v1_set_position(item, 100, 200);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.position_count > 0); usleep(10000); }
    CHECK(got, "position request reached the shell");
    CHECK(seen.position_x == 100 && seen.position_y == 200, "requested (%d,%d)", seen.position_x, seen.position_y);
    /* The shell placed it a little differently (clamped) and says so. */
    pos_arg.sid = seen.position_surface; pos_arg.x = 100; pos_arg.y = 190;
    on_server(task_report_position, NULL);
    CHECK(wait_for(&item_positioned, 500), "position answered");
    CHECK(item_x == 100 && item_y == 190, "client told (%d,%d)", item_x, item_y);

    xx_zone_item_v1_destroy(item);
    xx_zone_v1_destroy(zone);
    wl_display_roundtrip(dpy);
}

/* screencopy: buffer event, copy, the shell delivers, ready. */
static volatile int sc_buffer_seen, sc_ready, sc_failed;
static uint32_t sc_format, sc_w, sc_h, sc_stride;
static void sc_buffer(void* d, struct zwlr_screencopy_frame_v1* f, uint32_t fmt, uint32_t w, uint32_t h, uint32_t stride) {
    (void)d; (void)f; sc_format = fmt; sc_w = w; sc_h = h; sc_stride = stride; sc_buffer_seen = 1;
}
static void sc_flags(void* d, struct zwlr_screencopy_frame_v1* f, uint32_t fl) { (void)d; (void)f; (void)fl; }
static void sc_ready_cb(void* d, struct zwlr_screencopy_frame_v1* f, uint32_t a, uint32_t b, uint32_t c) { (void)d; (void)f; (void)a; (void)b; (void)c; sc_ready = 1; }
static void sc_failed_cb(void* d, struct zwlr_screencopy_frame_v1* f) { (void)d; (void)f; sc_failed = 1; }
static void sc_damage(void* d, struct zwlr_screencopy_frame_v1* f, uint32_t x, uint32_t y, uint32_t w, uint32_t h) { (void)d; (void)f; (void)x; (void)y; (void)w; (void)h; }
static void sc_dmabuf(void* d, struct zwlr_screencopy_frame_v1* f, uint32_t a, uint32_t b, uint32_t c) { (void)d; (void)f; (void)a; (void)b; (void)c; }
static volatile int sc_buffer_done;
static void sc_bdone(void* d, struct zwlr_screencopy_frame_v1* f) { (void)d; (void)f; sc_buffer_done = 1; }
static const struct zwlr_screencopy_frame_v1_listener sc_listener = {
    sc_buffer, sc_flags, sc_ready_cb, sc_failed_cb, sc_damage, sc_dmabuf, sc_bdone
};
static uint8_t* sc_pixels;
static void task_deliver(void* a) {
    (void)a;
    uint32_t frame; int w, h;
    LOCKED(frame = seen.screencopy_frame; w = seen.screencopy_w; h = seen.screencopy_h);
    sc_pixels = malloc((size_t)w * h * 4);
    for (int i = 0; i < w * h; i++) { sc_pixels[i * 4] = 1; sc_pixels[i * 4 + 1] = 2; sc_pixels[i * 4 + 2] = 3; sc_pixels[i * 4 + 3] = 0xff; }
    wayland_server_screencopy_deliver(server, frame, sc_pixels, w * 4, 0);
}

static void test_screencopy(void) {
    struct zwlr_screencopy_frame_v1* f = zwlr_screencopy_manager_v1_capture_output_region(
        screencopy, 0, output, 10, 20, 64, 32);
    zwlr_screencopy_frame_v1_add_listener(f, &sc_listener, NULL);
    CHECK(wait_for(&sc_buffer_seen, 500), "buffer event");
    CHECK(sc_format == WL_SHM_FORMAT_XRGB8888 && sc_w == 64 && sc_h == 32 && sc_stride == 256,
          "buffer %ux%u stride %u format %u", sc_w, sc_h, sc_stride, sc_format);
    CHECK(wait_for(&sc_buffer_done, 500), "buffer_done (v3)");
    void* px = NULL;
    struct wl_buffer* b = make_buffer((int)sc_w, (int)sc_h, WL_SHM_FORMAT_XRGB8888, &px);
    zwlr_screencopy_frame_v1_copy(f, b);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.screencopy_frame != 0); usleep(10000); }
    CHECK(got, "shell asked for the pixels");
    CHECK(seen.screencopy_x == 10 && seen.screencopy_y == 20 && seen.screencopy_w == 64 && seen.screencopy_h == 32,
          "region (%d,%d %dx%d)", seen.screencopy_x, seen.screencopy_y, seen.screencopy_w, seen.screencopy_h);
    on_server(task_deliver, NULL);
    CHECK(wait_for(&sc_ready, 500), "ready");
    CHECK(!sc_failed, "not failed");
    uint8_t* p = px;
    CHECK(p[0] == 1 && p[1] == 2 && p[2] == 3, "pixels landed in the client's buffer: %d %d %d", p[0], p[1], p[2]);
    CHECK(p[(size_t)31 * 256 + 63 * 4] == 1, "last pixel too");
    zwlr_screencopy_frame_v1_destroy(f);
    wl_buffer_destroy(b);
    free(sc_pixels);
}

/* single pixel buffer: a 1x1 ARGB shm buffer as far as the shell can tell. */
static void test_single_pixel(void) {
    int before; LOCKED(before = seen.shm_count);
    struct wl_buffer* b = wp_single_pixel_buffer_manager_v1_create_u32_rgba_buffer(
        spb_mgr, 0xffffffffu, 0, 0x80000000u, 0xffffffffu);
    wl_surface_attach(tl_surface, b, 0, 0);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.shm_count > before); usleep(10000); }
    CHECK(got, "single-pixel buffer committed to the shell");
    CHECK(seen.shm_w == 1 && seen.shm_h == 1, "%dx%d", seen.shm_w, seen.shm_h);
    CHECK(seen.shm_format == WL_SHM_FORMAT_ARGB8888, "format %u", seen.shm_format);
    CHECK(seen.shm_px[0] == 0x80 && seen.shm_px[1] == 0 && seen.shm_px[2] == 0xff && seen.shm_px[3] == 0xff,
          "B,G,R,A = %02x %02x %02x %02x", seen.shm_px[0], seen.shm_px[1], seen.shm_px[2], seen.shm_px[3]);
    wl_buffer_destroy(b);
}

/* idle notify: idled after the timeout, resumed on input. */
static volatile int idled, resumed;
static void n_idled(void* d, struct ext_idle_notification_v1* n) { (void)d; (void)n; idled = 1; }
static void n_resumed(void* d, struct ext_idle_notification_v1* n) { (void)d; (void)n; resumed = 1; }
static const struct ext_idle_notification_v1_listener n_listener = { n_idled, n_resumed };

static void test_idle_notify(void) {
    struct ext_idle_notification_v1* n = ext_idle_notifier_v1_get_idle_notification(idle_notifier, 60, seat);
    ext_idle_notification_v1_add_listener(n, &n_listener, NULL);
    CHECK(wait_for(&idled, 1000), "idled after the timeout");
    /* Input on the human seat: the compositor's own delivery path. */
    uint32_t sid; LOCKED(sid = seen.new_toplevel_id);
    wayland_server_pointer_enter(server, sid, 1, 1);
    wayland_server_pointer_motion(server, sid, 1, 2, 2);
    CHECK(wait_for(&resumed, 1000), "resumed on input");
    ext_idle_notification_v1_destroy(n);
}

/* keyboard shortcuts inhibit: granted, reported, released. */
static volatile int inhibit_active;
static void in_active(void* d, struct zwp_keyboard_shortcuts_inhibitor_v1* i) { (void)d; (void)i; inhibit_active = 1; }
static void in_inactive(void* d, struct zwp_keyboard_shortcuts_inhibitor_v1* i) { (void)d; (void)i; }
static const struct zwp_keyboard_shortcuts_inhibitor_v1_listener in_listener = { in_active, in_inactive };

static void test_shortcuts_inhibit(void) {
    struct zwp_keyboard_shortcuts_inhibitor_v1* in =
        zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(inhibit_mgr, tl_surface, seat);
    zwp_keyboard_shortcuts_inhibitor_v1_add_listener(in, &in_listener, NULL);
    CHECK(wait_for(&inhibit_active, 500), "inhibitor active");
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.inhibit_count > 0 && seen.inhibited == 1); usleep(10000); }
    CHECK(got, "shell told the surface is inhibited");
    zwp_keyboard_shortcuts_inhibitor_v1_destroy(in);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.inhibit_count > 1 && seen.inhibited == 0); usleep(10000); }
    CHECK(got, "shell told the inhibitor is gone");
}

/* ext-data-control: a copy through the ext protocol is offered back. */
static volatile int edc_offered;
static char edc_mime[64];
static void eo_offer(void* d, struct ext_data_control_offer_v1* o, const char* mime) { (void)d; (void)o; snprintf(edc_mime, 64, "%s", mime); }
static const struct ext_data_control_offer_v1_listener eo_listener = { eo_offer };
static void ed_data_offer(void* d, struct ext_data_control_device_v1* dev, struct ext_data_control_offer_v1* o) {
    (void)d; (void)dev;
    TRASH(o);
    ext_data_control_offer_v1_add_listener(o, &eo_listener, NULL);
}
static void ed_selection(void* d, struct ext_data_control_device_v1* dev, struct ext_data_control_offer_v1* o) {
    (void)d; (void)dev;
    if (o) edc_offered = 1;
}
static void ed_finished(void* d, struct ext_data_control_device_v1* dev) { (void)d; (void)dev; }
static volatile int edc_primary_offered; static int edc_primary_null;
static void ed_primary(void* d, struct ext_data_control_device_v1* dev, struct ext_data_control_offer_v1* o) {
    (void)d; (void)dev;
    if (o) edc_primary_offered++; else edc_primary_null++;
}
static const struct ext_data_control_device_v1_listener ed_listener = { ed_data_offer, ed_selection, ed_finished, ed_primary };
static void es_send(void* d, struct ext_data_control_source_v1* s, const char* mime, int32_t fd) { (void)d; (void)s; (void)mime; close(fd); }
static void es_cancelled(void* d, struct ext_data_control_source_v1* s) { (void)d; (void)s; }
static const struct ext_data_control_source_v1_listener es_listener = { es_send, es_cancelled };

static void test_ext_data_control(void) {
    struct ext_data_control_device_v1* dev = ext_data_control_manager_v1_get_data_device(edc_mgr, seat);
    ext_data_control_device_v1_add_listener(dev, &ed_listener, NULL);
    struct ext_data_control_source_v1* src = ext_data_control_manager_v1_create_data_source(edc_mgr);
    ext_data_control_source_v1_add_listener(src, &es_listener, NULL);
    ext_data_control_source_v1_offer(src, "text/plain");
    ext_data_control_device_v1_set_selection(dev, src);
    CHECK(wait_for(&edc_offered, 500), "selection offered back through ext-data-control");
    CHECK(strcmp(edc_mime, "text/plain") == 0, "mime %s", edc_mime);
    ext_data_control_source_v1_destroy(src);
    ext_data_control_device_v1_destroy(dev);
}

/* xdg-foreign: an exported handle imports; an invented one is destroyed. */
static char foreign_handle[64];
static volatile int exported_seen, import_destroyed;
static void ex_handle(void* d, struct zxdg_exported_v2* e, const char* h) { (void)d; (void)e; snprintf(foreign_handle, 64, "%s", h); exported_seen = 1; }
static const struct zxdg_exported_v2_listener ex_listener = { ex_handle };
static void im_destroyed(void* d, struct zxdg_imported_v2* i) { (void)d; (void)i; import_destroyed++; }
static const struct zxdg_imported_v2_listener im_listener = { im_destroyed };

static void test_xdg_foreign(void) {
    struct zxdg_exported_v2* ex = zxdg_exporter_v2_export_toplevel(exporter, tl_surface);
    zxdg_exported_v2_add_listener(ex, &ex_listener, NULL);
    CHECK(wait_for(&exported_seen, 500), "handle issued");
    struct zxdg_imported_v2* bogus = zxdg_importer_v2_import_toplevel(importer, "nope");
    zxdg_imported_v2_add_listener(bogus, &im_listener, NULL);
    CHECK(wait_for(&import_destroyed, 500), "an unknown handle is answered with destroyed");
    import_destroyed = 0;
    struct zxdg_imported_v2* im = zxdg_importer_v2_import_toplevel(importer, foreign_handle);
    zxdg_imported_v2_add_listener(im, &im_listener, NULL);
    zxdg_imported_v2_set_parent_of(im, tl_surface);
    wl_display_roundtrip(dpy);
    usleep(50000);
    wl_display_roundtrip(dpy);
    CHECK(import_destroyed == 0, "a live handle imports");
    zxdg_exported_v2_destroy(ex);
    CHECK(wait_for(&import_destroyed, 500), "destroying the export destroys the import");
    zxdg_imported_v2_destroy(im);
    zxdg_imported_v2_destroy(bogus);
}

/* wlr-output-management: one head per output, with its mode; apply refused. */
static volatile int om_done;
static int om_heads;
static char om_head_name[64];
static int32_t om_mode_w, om_mode_h, om_pos_x, om_pos_y;
static void mode_size(void* d, struct zwlr_output_mode_v1* m, int32_t w, int32_t h) { (void)d; (void)m; om_mode_w = w; om_mode_h = h; }
static void mode_refresh(void* d, struct zwlr_output_mode_v1* m, int32_t r) { (void)d; (void)m; (void)r; }
static void mode_preferred(void* d, struct zwlr_output_mode_v1* m) { (void)d; (void)m; }
static void mode_finished(void* d, struct zwlr_output_mode_v1* m) { (void)d; (void)m; }
static const struct zwlr_output_mode_v1_listener mode_listener = { mode_size, mode_refresh, mode_preferred, mode_finished };
static void head_name(void* d, struct zwlr_output_head_v1* h, const char* n) { (void)d; (void)h; snprintf(om_head_name, 64, "%s", n); }
static void head_desc(void* d, struct zwlr_output_head_v1* h, const char* n) { (void)d; (void)h; (void)n; }
static void head_phys(void* d, struct zwlr_output_head_v1* h, int32_t w, int32_t hh) { (void)d; (void)h; (void)w; (void)hh; }
static void head_mode(void* d, struct zwlr_output_head_v1* h, struct zwlr_output_mode_v1* m) { (void)d; (void)h; TRASH(m); zwlr_output_mode_v1_add_listener(m, &mode_listener, NULL); }
static void head_enabled(void* d, struct zwlr_output_head_v1* h, int32_t e) { (void)d; (void)h; (void)e; }
static void head_current(void* d, struct zwlr_output_head_v1* h, struct zwlr_output_mode_v1* m) { (void)d; (void)h; (void)m; }
static void head_position(void* d, struct zwlr_output_head_v1* h, int32_t x, int32_t y) { (void)d; (void)h; om_pos_x = x; om_pos_y = y; }
static void head_transform(void* d, struct zwlr_output_head_v1* h, int32_t t) { (void)d; (void)h; (void)t; }
static void head_scale(void* d, struct zwlr_output_head_v1* h, wl_fixed_t s) { (void)d; (void)h; (void)s; }
static void head_finished(void* d, struct zwlr_output_head_v1* h) { (void)d; (void)h; }
static void head_make(void* d, struct zwlr_output_head_v1* h, const char* s) { (void)d; (void)h; (void)s; }
static void head_model(void* d, struct zwlr_output_head_v1* h, const char* s) { (void)d; (void)h; (void)s; }
static void head_serial(void* d, struct zwlr_output_head_v1* h, const char* s) { (void)d; (void)h; (void)s; }
static void head_adaptive(void* d, struct zwlr_output_head_v1* h, uint32_t s) { (void)d; (void)h; (void)s; }
static const struct zwlr_output_head_v1_listener head_listener = {
    head_name, head_desc, head_phys, head_mode, head_enabled, head_current, head_position,
    head_transform, head_scale, head_finished, head_make, head_model, head_serial, head_adaptive
};
static struct zwlr_output_head_v1* om_head_res;
static void om_head(void* d, struct zwlr_output_manager_v1* m, struct zwlr_output_head_v1* h) {
    (void)d; (void)m; om_heads++;
    om_head_res = h;
    TRASH(h);
    zwlr_output_head_v1_add_listener(h, &head_listener, NULL);
}
static void task_outcfg_ok(void* arg) {
    (void)arg;
    uint32_t id; LOCKED(id = seen.outcfg_id);
    wayland_server_output_config_result(server, id, 1);
}
static void om_done_cb(void* d, struct zwlr_output_manager_v1* m, uint32_t serial) { (void)d; (void)m; (void)serial; om_done = 1; }
static void om_finished(void* d, struct zwlr_output_manager_v1* m) { (void)d; (void)m; }
static const struct zwlr_output_manager_v1_listener om_listener = { om_head, om_done_cb, om_finished };
static volatile int cfg_failed, cfg_succeeded;
static void cfg_ok(void* d, struct zwlr_output_configuration_v1* c) { (void)d; (void)c; cfg_succeeded = 1; }
static void cfg_fail(void* d, struct zwlr_output_configuration_v1* c) { (void)d; (void)c; cfg_failed = 1; }
static void cfg_cancel(void* d, struct zwlr_output_configuration_v1* c) { (void)d; (void)c; }
static const struct zwlr_output_configuration_v1_listener cfg_listener = { cfg_ok, cfg_fail, cfg_cancel };

static void test_output_management(void) {
    outmgr = wl_registry_bind(registry, outmgr_name, &zwlr_output_manager_v1_interface,
                              outmgr_version);
    zwlr_output_manager_v1_add_listener(outmgr, &om_listener, NULL);
    CHECK(wait_for(&om_done, 500), "heads listed with done");
    CHECK(om_heads == 1, "%d heads for one output", om_heads);
    CHECK(strcmp(om_head_name, "primary") == 0, "head name %s", om_head_name);
    CHECK(om_mode_w == 1280 && om_mode_h == 800, "mode %dx%d", om_mode_w, om_mode_h);
    struct zwlr_output_configuration_v1* cfg = zwlr_output_manager_v1_create_configuration(outmgr, 1);
    zwlr_output_configuration_v1_add_listener(cfg, &cfg_listener, NULL);
    zwlr_output_configuration_v1_apply(cfg);
    CHECK(wait_for(&cfg_failed, 500), "an apply that leaves the head unconfigured fails");
    CHECK(!cfg_succeeded, "no succeeded");
    zwlr_output_configuration_v1_destroy(cfg);

    /* A different position: the shell cannot move a monitor. */
    cfg_failed = cfg_succeeded = 0;
    cfg = zwlr_output_manager_v1_create_configuration(outmgr, 1);
    zwlr_output_configuration_v1_add_listener(cfg, &cfg_listener, NULL);
    struct zwlr_output_configuration_head_v1* ch =
        zwlr_output_configuration_v1_enable_head(cfg, om_head_res);
    TRASH(ch);
    zwlr_output_configuration_head_v1_set_position(ch, 100, 0);
    zwlr_output_configuration_v1_test(cfg);
    CHECK(wait_for(&cfg_failed, 500), "moving the head fails the test");
    zwlr_output_configuration_v1_destroy(cfg);

    /* The same everything: nothing to do, succeeded. */
    cfg_failed = cfg_succeeded = 0;
    cfg = zwlr_output_manager_v1_create_configuration(outmgr, 1);
    zwlr_output_configuration_v1_add_listener(cfg, &cfg_listener, NULL);
    ch = zwlr_output_configuration_v1_enable_head(cfg, om_head_res);
    TRASH(ch);
    zwlr_output_configuration_head_v1_set_position(ch, om_pos_x, om_pos_y);
    zwlr_output_configuration_v1_apply(cfg);
    CHECK(wait_for(&cfg_succeeded, 500), "an unchanged configuration succeeds");
    CHECK(!cfg_failed, "and does not fail");
    zwlr_output_configuration_v1_destroy(cfg);

    /* A new scale on the host: the shell hears it and answers. */
    cfg_failed = cfg_succeeded = 0;
    int before; LOCKED(before = seen.outcfg_count);
    cfg = zwlr_output_manager_v1_create_configuration(outmgr, 1);
    zwlr_output_configuration_v1_add_listener(cfg, &cfg_listener, NULL);
    ch = zwlr_output_configuration_v1_enable_head(cfg, om_head_res);
    TRASH(ch);
    zwlr_output_configuration_head_v1_set_scale(ch, wl_fixed_from_double(1.5));
    zwlr_output_configuration_v1_apply(cfg);
    wl_display_flush(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.outcfg_count > before); usleep(10000); }
    CHECK(got, "the shell was asked for the new scale");
    CHECK(seen.outcfg_scale == 1.5, "scale %.2f", seen.outcfg_scale);
    CHECK(!cfg_succeeded && !cfg_failed, "no answer before the shell's");
    on_server(task_outcfg_ok, NULL);
    CHECK(wait_for(&cfg_succeeded, 500), "succeeded once the shell applied it");
    zwlr_output_configuration_v1_destroy(cfg);
}

/* ext-image-copy-capture: session constraints, a frame through the same
 * readback as wlr-screencopy. */
static volatile int icc_done, icc_ready, icc_failed;
static uint32_t icc_w, icc_h, icc_fmt_count;
static void icc_buffer_size(void* d, struct ext_image_copy_capture_session_v1* s, uint32_t w, uint32_t h) { (void)d; (void)s; icc_w = w; icc_h = h; }
static void icc_shm_format(void* d, struct ext_image_copy_capture_session_v1* s, uint32_t f) { (void)d; (void)s; (void)f; icc_fmt_count++; }
static void icc_dmabuf_device(void* d, struct ext_image_copy_capture_session_v1* s, struct wl_array* a) { (void)d; (void)s; (void)a; }
static void icc_dmabuf_format(void* d, struct ext_image_copy_capture_session_v1* s, uint32_t f, struct wl_array* a) { (void)d; (void)s; (void)f; (void)a; }
static void icc_session_done(void* d, struct ext_image_copy_capture_session_v1* s) { (void)d; (void)s; icc_done = 1; }
static void icc_stopped(void* d, struct ext_image_copy_capture_session_v1* s) { (void)d; (void)s; }
static const struct ext_image_copy_capture_session_v1_listener icc_session_listener = {
    icc_buffer_size, icc_shm_format, icc_dmabuf_device, icc_dmabuf_format, icc_session_done, icc_stopped
};
static void icf_transform(void* d, struct ext_image_copy_capture_frame_v1* f, uint32_t t) { (void)d; (void)f; (void)t; }
static void icf_damage(void* d, struct ext_image_copy_capture_frame_v1* f, int32_t x, int32_t y, int32_t w, int32_t h) { (void)d; (void)f; (void)x; (void)y; (void)w; (void)h; }
static void icf_ptime(void* d, struct ext_image_copy_capture_frame_v1* f, uint32_t a, uint32_t b, uint32_t c) { (void)d; (void)f; (void)a; (void)b; (void)c; }
static void icf_ready(void* d, struct ext_image_copy_capture_frame_v1* f) { (void)d; (void)f; icc_ready = 1; }
static void icf_failed(void* d, struct ext_image_copy_capture_frame_v1* f, uint32_t r) { (void)d; (void)f; (void)r; icc_failed = 1; }
static const struct ext_image_copy_capture_frame_v1_listener icf_listener = {
    icf_transform, icf_damage, icf_ptime, icf_ready, icf_failed
};

static void test_image_copy_capture(void) {
    struct ext_image_capture_source_v1* src =
        ext_output_image_capture_source_manager_v1_create_source(capsrc_mgr, output);
    struct ext_image_copy_capture_session_v1* ses =
        ext_image_copy_capture_manager_v1_create_session(copycap_mgr, src, 0);
    ext_image_copy_capture_session_v1_add_listener(ses, &icc_session_listener, NULL);
    CHECK(wait_for(&icc_done, 500), "session constraints announced");
    CHECK(icc_w == 1280 && icc_h == 800, "buffer size %ux%u", icc_w, icc_h);
    CHECK(icc_fmt_count == 2, "%u shm formats", icc_fmt_count);
    struct ext_image_copy_capture_frame_v1* f = ext_image_copy_capture_session_v1_create_frame(ses);
    ext_image_copy_capture_frame_v1_add_listener(f, &icf_listener, NULL);
    void* px = NULL;
    struct wl_buffer* b = make_buffer((int)icc_w, (int)icc_h, WL_SHM_FORMAT_XRGB8888, &px);
    ext_image_copy_capture_frame_v1_attach_buffer(f, b);
    ext_image_copy_capture_frame_v1_damage_buffer(f, 0, 0, (int32_t)icc_w, (int32_t)icc_h);
    LOCKED(seen.screencopy_frame = 0);
    ext_image_copy_capture_frame_v1_capture(f);
    wl_display_roundtrip(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.screencopy_frame != 0); usleep(10000); }
    CHECK(got, "the shell was asked for the pixels");
    CHECK(seen.screencopy_w == 1280 && seen.screencopy_h == 800, "whole output (%dx%d)", seen.screencopy_w, seen.screencopy_h);
    on_server(task_deliver, NULL);
    CHECK(wait_for(&icc_ready, 500), "ready");
    CHECK(!icc_failed, "not failed");
    uint8_t* p = px;
    CHECK(p[0] == 1 && p[1] == 2 && p[2] == 3, "pixels in the buffer");
    free(sc_pixels);
    ext_image_copy_capture_frame_v1_destroy(f);
    ext_image_copy_capture_session_v1_destroy(ses);
    ext_image_capture_source_v1_destroy(src);
    wl_buffer_destroy(b);
}

/* security-context: a client through a sandbox's socket sees no privileged
 * global. */
static struct global_seen sb_globals[128];
static int sb_nglobals;
static void sb_global(void* d, struct wl_registry* r, uint32_t id, const char* iface, uint32_t ver) {
    (void)d; (void)r; (void)id;
    if (sb_nglobals < 128) {
        snprintf(sb_globals[sb_nglobals].name, 64, "%s", iface);
        sb_globals[sb_nglobals].version = ver;
        sb_nglobals++;
    }
}
static void sb_gone(void* d, struct wl_registry* r, uint32_t id) { (void)d; (void)r; (void)id; }
static const struct wl_registry_listener sb_listener = { sb_global, sb_gone };
static int sb_has(const char* name) {
    for (int i = 0; i < sb_nglobals; i++) if (strcmp(sb_globals[i].name, name) == 0) return 1;
    return 0;
}

static void test_security_context(void) {
    char path[200];
    snprintf(path, sizeof(path), "%s/sandbox-sock", getenv("XDG_RUNTIME_DIR"));
    int lfd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    struct sockaddr_un addr = { .sun_family = AF_UNIX };
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path);
    unlink(path);
    CHECK(bind(lfd, (struct sockaddr*)&addr, sizeof(addr)) == 0, "bind");
    CHECK(listen(lfd, 4) == 0, "listen");
    int close_fds[2];
    CHECK(pipe(close_fds) == 0, "pipe");

    struct wp_security_context_v1* ctx =
        wp_security_context_manager_v1_create_listener(secctx_mgr, lfd, close_fds[0]);
    wp_security_context_v1_set_sandbox_engine(ctx, "org.starling.test");
    wp_security_context_v1_set_app_id(ctx, "org.starling.SandboxedApp");
    wp_security_context_v1_commit(ctx);
    wp_security_context_v1_destroy(ctx);
    wl_display_roundtrip(dpy);
    /* Our copies: the compositor took the fds' ownership by value. */
    close(lfd);
    close(close_fds[0]);

    int cfd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    CHECK(connect(cfd, (struct sockaddr*)&addr, sizeof(addr)) == 0, "connect through the sandbox socket");
    struct wl_display* sb = wl_display_connect_to_fd(cfd);
    CHECK(sb != NULL, "sandboxed display connected");
    if (sb) {
        struct wl_registry* reg = wl_display_get_registry(sb);
        wl_registry_add_listener(reg, &sb_listener, NULL);
        wl_display_roundtrip(sb);
        CHECK(sb_nglobals > 10, "the sandboxed client sees globals (%d)", sb_nglobals);
        CHECK(sb_has("wl_compositor") && sb_has("xdg_wm_base"), "ordinary globals visible");
        CHECK(!sb_has("zwlr_screencopy_manager_v1"), "screencopy hidden from the sandbox");
        CHECK(!sb_has("ext_image_copy_capture_manager_v1"), "image copy capture hidden");
        CHECK(!sb_has("zwlr_layer_shell_v1"), "layer shell hidden");
        CHECK(!sb_has("zwlr_data_control_manager_v1") && !sb_has("ext_data_control_manager_v1"),
              "clipboard managers' protocols hidden");
        CHECK(!sb_has("wp_security_context_manager_v1"), "no nesting");
        wl_registry_destroy(reg);
        wl_display_disconnect(sb);
    }
    /* The sandbox exits: the socket stops accepting. */
    close(close_fds[1]);
    wl_display_roundtrip(dpy);
    usleep(80000);
    int cfd2 = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    int rc = connect(cfd2, (struct sockaddr*)&addr, sizeof(addr));
    /* The listening socket is closed compositor-side; a connect either fails
     * outright or is never accepted. Either is "not a client". */
    if (rc == 0) {
        struct wl_display* sb2 = wl_display_connect_to_fd(cfd2);
        int alive = sb2 && wl_display_roundtrip(sb2) >= 0;
        CHECK(!alive, "after close_fd, the socket takes no new clients");
        if (sb2) wl_display_disconnect(sb2); else close(cfd2);
    } else {
        close(cfd2);
    }
    unlink(path);
}

/* session lock: locked, a lock surface as an overlay layer surface, a
 * second locker refused, unlock. */
static volatile int lk_locked, lk_finished, lk_configured;
static uint32_t lk_w, lk_h;
static void lk_locked_cb(void* d, struct ext_session_lock_v1* l) { (void)d; (void)l; lk_locked = 1; }
static void lk_finished_cb(void* d, struct ext_session_lock_v1* l) { (void)d; (void)l; lk_finished = 1; }
static const struct ext_session_lock_v1_listener lk_listener = { lk_locked_cb, lk_finished_cb };
static void lks_configure(void* d, struct ext_session_lock_surface_v1* s, uint32_t serial, uint32_t w, uint32_t h) {
    (void)d; ext_session_lock_surface_v1_ack_configure(s, serial); lk_w = w; lk_h = h; lk_configured = 1;
}
static const struct ext_session_lock_surface_v1_listener lks_listener = { lks_configure };

static void test_session_lock(void) {
    struct ext_session_lock_v1* lock = ext_session_lock_manager_v1_lock(lock_mgr);
    ext_session_lock_v1_add_listener(lock, &lk_listener, NULL);
    CHECK(wait_for(&lk_locked, 500), "locked");
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.lock_count > 0 && seen.locked); usleep(10000); }
    CHECK(got, "shell told the session is locked");

    struct wl_surface* s = wl_compositor_create_surface(compositor);
    struct ext_session_lock_surface_v1* ls = ext_session_lock_v1_get_lock_surface(lock, s, output);
    ext_session_lock_surface_v1_add_listener(ls, &lks_listener, NULL);
    CHECK(wait_for(&lk_configured, 500), "lock surface configured");
    CHECK(lk_w == 1280 && lk_h == 800, "configured to the output: %ux%u", lk_w, lk_h);
    int layers_before; LOCKED(layers_before = seen.layer_count);
    struct wl_buffer* b = make_buffer((int)lk_w, (int)lk_h, WL_SHM_FORMAT_XRGB8888, NULL);
    wl_surface_attach(s, b, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.layer_count > layers_before); usleep(10000); }
    CHECK(got, "the lock surface reached the shell as a layer surface");
    CHECK(seen.layer_info.layer == 3 && seen.layer_info.keyboard_interactivity == 1 &&
          strcmp(seen.layer_info.namespace_, "session-lock") == 0,
          "overlay, exclusive keys, namespace %s", seen.layer_info.namespace_);
    CHECK(seen.layer_info.anchor == 15, "anchored to every edge (%u)", seen.layer_info.anchor);

    struct ext_session_lock_v1* second = ext_session_lock_manager_v1_lock(lock_mgr);
    ext_session_lock_v1_add_listener(second, &lk_listener, NULL);
    CHECK(wait_for(&lk_finished, 500), "a second locker is finished");
    ext_session_lock_v1_destroy(second);

    ext_session_lock_surface_v1_destroy(ls);
    wl_surface_destroy(s);
    ext_session_lock_v1_unlock_and_destroy(lock);
    wl_display_roundtrip(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.lock_count > 1 && !seen.locked); usleep(10000); }
    CHECK(got, "shell told the session is unlocked");
    wl_buffer_destroy(b);
}

/* ext-workspace: the shell's spaces, a panel's requests. */
static volatile int ws_done;
static int ws_handles, ws_removed, ws_group_enter;
static char ws_name0[64]; static uint32_t ws_state_last; static uint32_t ws_coord_last;
static struct ext_workspace_handle_v1* ws_handle[8];
static void wsh_id(void* d, struct ext_workspace_handle_v1* h, const char* id) { (void)d; (void)h; (void)id; }
static void wsh_name(void* d, struct ext_workspace_handle_v1* h, const char* n) { (void)d; if (h == ws_handle[0]) snprintf(ws_name0, 64, "%s", n); }
static void wsh_coords(void* d, struct ext_workspace_handle_v1* h, struct wl_array* a) { (void)d; (void)h; if (a->size >= 4) ws_coord_last = *(uint32_t*)a->data; }
static void wsh_state(void* d, struct ext_workspace_handle_v1* h, uint32_t s) { (void)d; (void)h; ws_state_last = s; }
static void wsh_caps(void* d, struct ext_workspace_handle_v1* h, uint32_t c) { (void)d; (void)h; (void)c; }
static void wsh_removed(void* d, struct ext_workspace_handle_v1* h) { (void)d; (void)h; ws_removed++; }
static const struct ext_workspace_handle_v1_listener wsh_listener = { wsh_id, wsh_name, wsh_coords, wsh_state, wsh_caps, wsh_removed };
static void wsg_caps(void* d, struct ext_workspace_group_handle_v1* g, uint32_t c) { (void)d; (void)g; (void)c; }
static void wsg_out_enter(void* d, struct ext_workspace_group_handle_v1* g, struct wl_output* o) { (void)d; (void)g; (void)o; }
static void wsg_out_leave(void* d, struct ext_workspace_group_handle_v1* g, struct wl_output* o) { (void)d; (void)g; (void)o; }
static void wsg_ws_enter(void* d, struct ext_workspace_group_handle_v1* g, struct ext_workspace_handle_v1* w) { (void)d; (void)g; (void)w; ws_group_enter++; }
static void wsg_ws_leave(void* d, struct ext_workspace_group_handle_v1* g, struct ext_workspace_handle_v1* w) { (void)d; (void)g; (void)w; }
static void wsg_removed(void* d, struct ext_workspace_group_handle_v1* g) { (void)d; (void)g; }
static const struct ext_workspace_group_handle_v1_listener wsg_listener = { wsg_caps, wsg_out_enter, wsg_out_leave, wsg_ws_enter, wsg_ws_leave, wsg_removed };
static struct ext_workspace_group_handle_v1* ws_group;
static void wsm_group(void* d, struct ext_workspace_manager_v1* m, struct ext_workspace_group_handle_v1* g) { (void)d; (void)m; ws_group = g; TRASH(g); ext_workspace_group_handle_v1_add_listener(g, &wsg_listener, NULL); }
static void wsm_workspace(void* d, struct ext_workspace_manager_v1* m, struct ext_workspace_handle_v1* w) {
    (void)d; (void)m;
    if (ws_handles < 8) ws_handle[ws_handles] = w;
    TRASH(w);
    ws_handles++;
    ext_workspace_handle_v1_add_listener(w, &wsh_listener, NULL);
}
static void wsm_done(void* d, struct ext_workspace_manager_v1* m) { (void)d; (void)m; ws_done = 1; }
static void wsm_finished(void* d, struct ext_workspace_manager_v1* m) { (void)d; (void)m; }
static const struct ext_workspace_manager_v1_listener wsm_listener = { wsm_group, wsm_workspace, wsm_done, wsm_finished };

static WaylandWorkspaceDesc ws_push[3];
static int ws_push_count;
static void task_push_workspaces(void* arg) { (void)arg; wayland_server_set_workspaces(server, ws_push, ws_push_count); }

static void test_workspaces(void) {
    ws_push[0] = (WaylandWorkspaceDesc){ .id = 1, .name = "Desktop 1", .active = 1 };
    ws_push[1] = (WaylandWorkspaceDesc){ .id = 2, .name = "Desktop 2", .active = 0 };
    ws_push_count = 2;
    on_server(task_push_workspaces, NULL);

    struct ext_workspace_manager_v1* wsm = wl_registry_bind(registry, wsmgr_name,
        &ext_workspace_manager_v1_interface, 1);
    TRASH(wsm);
    ext_workspace_manager_v1_add_listener(wsm, &wsm_listener, NULL);
    CHECK(wait_for(&ws_done, 500), "workspaces listed with done");
    CHECK(ws_group != NULL, "one group");
    CHECK(ws_handles == 2, "%d workspaces", ws_handles);
    CHECK(ws_group_enter == 2, "both in the group (%d)", ws_group_enter);
    CHECK(strcmp(ws_name0, "Desktop 1") == 0, "first is \"%s\"", ws_name0);

    /* A panel activates the second: the shell hears it on commit only. */
    int before; LOCKED(before = seen.ws_count);
    ext_workspace_handle_v1_activate(ws_handle[1]);
    wl_display_roundtrip(dpy);
    usleep(30000);
    int n; LOCKED(n = seen.ws_count);
    CHECK(n == before, "nothing before commit");
    ext_workspace_manager_v1_commit(wsm);
    wl_display_flush(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.ws_count > before); usleep(10000); }
    CHECK(got && seen.ws_request == WAYLAND_WORKSPACE_REQUEST_ACTIVATE && seen.ws_id == 2,
          "activate workspace 2 reached the shell (request %d id %u)", seen.ws_request, seen.ws_id);

    /* The shell switched: the second is active now, the first is not. */
    ws_push[0].active = 0; ws_push[1].active = 1;
    ws_done = 0;
    on_server(task_push_workspaces, NULL);
    CHECK(wait_for(&ws_done, 500), "state change came with done");
    CHECK(ws_state_last == EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE, "last state event: active (%u)", ws_state_last);

    /* A new one is asked for by name. */
    LOCKED(before = seen.ws_count);
    ext_workspace_group_handle_v1_create_workspace(ws_group, "Work");
    ext_workspace_manager_v1_commit(wsm);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.ws_count > before); usleep(10000); }
    CHECK(got && seen.ws_request == WAYLAND_WORKSPACE_REQUEST_CREATE && strcmp(seen.ws_name, "Work") == 0,
          "create \"%s\" reached the shell", seen.ws_name);

    /* The shell added it, then dropped the first. */
    ws_push[2] = (WaylandWorkspaceDesc){ .id = 3, .name = "Work", .active = 0 };
    ws_push_count = 3;
    ws_done = 0;
    on_server(task_push_workspaces, NULL);
    CHECK(wait_for(&ws_done, 500), "the third arrived");
    CHECK(ws_handles == 3, "%d workspaces", ws_handles);
    ws_push[0] = ws_push[1]; ws_push[1] = ws_push[2]; ws_push_count = 2;
    ws_done = 0;
    on_server(task_push_workspaces, NULL);
    CHECK(wait_for(&ws_done, 500), "the removal arrived");
    CHECK(ws_removed == 1, "one removed (%d)", ws_removed);
    CHECK(ws_coord_last == 1, "the survivor renumbered to position 1 (%u)", ws_coord_last);
    ext_workspace_manager_v1_stop(wsm);
    wl_display_roundtrip(dpy);
}

/* ext-background-effect: a blur region reaches the shell as rects, and the
 * surface keeps its alpha. */
static void test_background_effect(void) {
    struct ext_background_effect_surface_v1* fx =
        ext_background_effect_manager_v1_get_background_effect(bgfx_mgr, tl_surface);
    struct wl_region* region = wl_compositor_create_region(compositor);
    wl_region_add(region, 0, 0, 100, 50);
    wl_region_add(region, 10, 10, 20, 20);
    ext_background_effect_surface_v1_set_blur_region(fx, region);
    int before; LOCKED(before = seen.blur_events);
    wl_surface_commit(tl_surface);
    wl_display_flush(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.blur_events > before); usleep(10000); }
    CHECK(got, "the blur region reached the shell");
    CHECK(seen.blur_count == 2 && seen.blur_rect0[0] == 0 && seen.blur_rect0[1] == 0 &&
          seen.blur_rect0[2] == 100 && seen.blur_rect0[3] == 50,
          "%d rects, first %d,%d %dx%d", seen.blur_count, seen.blur_rect0[0], seen.blur_rect0[1],
          seen.blur_rect0[2], seen.blur_rect0[3]);
    /* An ARGB buffer on a blurred toplevel keeps its alpha. */
    int shm_before; LOCKED(shm_before = seen.shm_count);
    struct wl_buffer* b = make_buffer(4, 4, WL_SHM_FORMAT_ARGB8888, NULL);
    wl_surface_attach(tl_surface, b, 0, 0);
    wl_surface_commit(tl_surface);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.shm_count > shm_before); usleep(10000); }
    CHECK(got && seen.shm_keep_alpha == 1, "alpha kept on the blurred toplevel");
    /* No region: the blur goes. */
    ext_background_effect_surface_v1_set_blur_region(fx, NULL);
    LOCKED(before = seen.blur_events);
    wl_surface_commit(tl_surface);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.blur_events > before); usleep(10000); }
    CHECK(got && seen.blur_count == 0, "cleared");
    wl_region_destroy(region);
    ext_background_effect_surface_v1_destroy(fx);
    wl_display_roundtrip(dpy);
    wl_buffer_destroy(b);
}

/* ext-transient-seat: a seat of its own, gone with the object. */
static volatile int ts_ready, ts_denied; static uint32_t ts_global;
static void ts_ready_cb(void* d, struct ext_transient_seat_v1* s, uint32_t g) { (void)d; (void)s; ts_global = g; ts_ready = 1; }
static void ts_denied_cb(void* d, struct ext_transient_seat_v1* s) { (void)d; (void)s; ts_denied = 1; }
static const struct ext_transient_seat_v1_listener ts_listener = { ts_ready_cb, ts_denied_cb };
static char tseat_name[64]; static volatile int tseat_named;
static void tseat_caps(void* d, struct wl_seat* s, uint32_t c) { (void)d; (void)s; (void)c; }
static void tseat_name_cb(void* d, struct wl_seat* s, const char* n) { (void)d; (void)s; snprintf(tseat_name, 64, "%s", n); tseat_named = 1; }
static const struct wl_seat_listener tseat_listener = { tseat_caps, tseat_name_cb };

static void test_transient_seat(void) {
    struct ext_transient_seat_v1* ts = ext_transient_seat_manager_v1_create(tseat_mgr);
    ext_transient_seat_v1_add_listener(ts, &ts_listener, NULL);
    CHECK(wait_for(&ts_ready, 500), "transient seat ready");
    CHECK(!ts_denied, "not denied");
    struct wl_seat* s = wl_registry_bind(registry, ts_global, &wl_seat_interface, 9);
    wl_seat_add_listener(s, &tseat_listener, NULL);
    CHECK(wait_for(&tseat_named, 500), "its wl_seat binds");
    CHECK(strncmp(tseat_name, "seat-transient-", 15) == 0, "named %s", tseat_name);
    int removed_before = globals_removed;
    wl_seat_release(s);
    ext_transient_seat_v1_destroy(ts);
    wl_display_roundtrip(dpy);
    wl_display_roundtrip(dpy);
    CHECK(globals_removed > removed_before, "its global went with it");
}

/* Virtual pointer and keyboard: frames and decoded keys reach the shell. */
static void test_virtual_input(void) {
    struct zwlr_virtual_pointer_v1* vp = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(vptr_mgr, seat);
    int before; LOCKED(before = seen.vp_count);
    zwlr_virtual_pointer_v1_motion_absolute(vp, 0, 640, 200, 1280, 800);
    zwlr_virtual_pointer_v1_button(vp, 0, 0x110, WL_POINTER_BUTTON_STATE_PRESSED);
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.vp_count > before); usleep(10000); }
    CHECK(got && seen.vp_has_abs && seen.vp_ax == 0.5 && seen.vp_ay == 0.25 && seen.vp_buttons == 1,
          "absolute frame: (%.2f, %.2f) buttons %u", seen.vp_ax, seen.vp_ay, seen.vp_buttons);
    LOCKED(before = seen.vp_count);
    zwlr_virtual_pointer_v1_motion(vp, 0, wl_fixed_from_int(10), wl_fixed_from_int(-5));
    zwlr_virtual_pointer_v1_axis_discrete(vp, 0, WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_int(10), 1);
    zwlr_virtual_pointer_v1_frame(vp);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.vp_count > before); usleep(10000); }
    CHECK(got && !seen.vp_has_abs && seen.vp_dx == 10 && seen.vp_dy == -5 && seen.vp_buttons == 1 &&
          seen.vp_wheel_dy == 20, "relative frame: (%.0f, %.0f) wheel %.0f, button held",
          seen.vp_dx, seen.vp_dy, seen.vp_wheel_dy);
    LOCKED(before = seen.vp_count);
    zwlr_virtual_pointer_v1_destroy(vp);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.vp_count > before); usleep(10000); }
    CHECK(got && seen.vp_buttons == 0, "a pointer dying with a button down releases it");

    struct zwp_virtual_keyboard_v1* vk = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(vkbd_mgr, seat);
    struct xkb_context* xctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_rule_names names = { .layout = "us" };
    struct xkb_keymap* km = xkb_keymap_new_from_names(xctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    CHECK(km != NULL, "a us keymap compiles here");
    if (km) {
        char* text = xkb_keymap_get_as_string(km, XKB_KEYMAP_FORMAT_TEXT_V1);
        size_t len = strlen(text) + 1;
        int fd = memfd_create("keymap", MFD_CLOEXEC);
        if (ftruncate(fd, (off_t)len) == 0) {
            void* m = mmap(NULL, len, PROT_WRITE, MAP_SHARED, fd, 0);
            memcpy(m, text, len);
            munmap(m, len);
        }
        zwp_virtual_keyboard_v1_keymap(vk, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, (uint32_t)len);
        close(fd);
        free(text);
        LOCKED(before = seen.vk_count);
        zwp_virtual_keyboard_v1_key(vk, 0, 30 /* KEY_A */, WL_KEYBOARD_KEY_STATE_PRESSED);
        wl_display_flush(dpy);
        got = 0;
        for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.vk_count > before); usleep(10000); }
        CHECK(got && seen.vk_evdev == 30 && seen.vk_keysym == XKB_KEY_a && strcmp(seen.vk_utf8, "a") == 0 &&
              seen.vk_pressed, "KEY_A decoded: keysym %x \"%s\"", seen.vk_keysym, seen.vk_utf8);
        zwp_virtual_keyboard_v1_key(vk, 0, 30, WL_KEYBOARD_KEY_STATE_RELEASED);
        xkb_mod_mask_t shift = 1u << xkb_keymap_mod_get_index(km, XKB_MOD_NAME_SHIFT);
        zwp_virtual_keyboard_v1_modifiers(vk, shift, 0, 0, 0);
        LOCKED(before = seen.vk_count);
        zwp_virtual_keyboard_v1_key(vk, 0, 30, WL_KEYBOARD_KEY_STATE_PRESSED);
        wl_display_flush(dpy);
        got = 0;
        for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.vk_count > before + 1); usleep(10000); }
        CHECK(got && seen.vk_keysym == XKB_KEY_A && strcmp(seen.vk_utf8, "A") == 0,
              "with shift: keysym %x \"%s\"", seen.vk_keysym, seen.vk_utf8);
        zwp_virtual_keyboard_v1_key(vk, 0, 30, WL_KEYBOARD_KEY_STATE_RELEASED);
        xkb_keymap_unref(km);
    }
    xkb_context_unref(xctx);
    zwp_virtual_keyboard_v1_destroy(vk);
    wl_display_roundtrip(dpy);
}

/* wp-pointer-warp: the request names the surface and the point. */
static void test_pointer_warp(void) {
    struct wl_pointer* ptr = wl_seat_get_pointer(seat);
    int before; LOCKED(before = seen.warp_count);
    wp_pointer_warp_v1_warp_pointer(warp, tl_surface, ptr, wl_fixed_from_double(10.5),
                                    wl_fixed_from_int(20), 0);
    wl_display_flush(dpy);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.warp_count > before); usleep(10000); }
    uint32_t sid; LOCKED(sid = seen.new_toplevel_id);
    CHECK(got && seen.warp_surface == sid && seen.warp_x == 10.5 && seen.warp_y == 20,
          "warp to (%.1f, %.1f) of surface %u", seen.warp_x, seen.warp_y, seen.warp_surface);
    wl_pointer_release(ptr);
}

/* Drag-and-drop with a toplevel riding along. The test client is both
 * ends: it starts the drag from its toplevel, and the same toplevel is the
 * target the compositor drops on. */
static volatile int dnd_entered, dnd_motion, dnd_dropped, dnd_left, dnd_offer_seen;
static volatile int src_target, src_drop_performed, src_finished, src_cancelled, src_send_count;
static uint32_t src_action, offer_action, offer_source_actions;
static char offer_mime[64];
static struct wl_data_offer* dnd_offer;
static void off_offer(void* d, struct wl_data_offer* o, const char* mime) { (void)d; (void)o; snprintf(offer_mime, 64, "%s", mime); }
static void off_source_actions(void* d, struct wl_data_offer* o, uint32_t a) { (void)d; (void)o; offer_source_actions = a; }
static void off_action(void* d, struct wl_data_offer* o, uint32_t a) { (void)d; (void)o; offer_action = a; }
static const struct wl_data_offer_listener off_listener = { off_offer, off_source_actions, off_action };
static void dd_data_offer(void* d, struct wl_data_device* dd, struct wl_data_offer* o) {
    (void)d; (void)dd; dnd_offer = o; dnd_offer_seen++;
    wl_data_offer_add_listener(o, &off_listener, NULL);
}
static void dd_enter(void* d, struct wl_data_device* dd, uint32_t serial, struct wl_surface* s,
                     wl_fixed_t x, wl_fixed_t y, struct wl_data_offer* o) {
    (void)d; (void)dd; (void)serial; (void)s; (void)x; (void)y; (void)o; dnd_entered++;
}
static void dd_leave(void* d, struct wl_data_device* dd) { (void)d; (void)dd; dnd_left++; }
static void dd_motion(void* d, struct wl_data_device* dd, uint32_t t, wl_fixed_t x, wl_fixed_t y) { (void)d; (void)dd; (void)t; (void)x; (void)y; dnd_motion++; }
static void dd_drop(void* d, struct wl_data_device* dd) { (void)d; (void)dd; dnd_dropped++; }
static void dd_selection(void* d, struct wl_data_device* dd, struct wl_data_offer* o) { (void)d; (void)dd; (void)o; }
static const struct wl_data_device_listener dd_listener = { dd_data_offer, dd_enter, dd_leave, dd_motion, dd_drop, dd_selection };
static void src_target_cb(void* d, struct wl_data_source* s, const char* mime) { (void)d; (void)s; src_target += mime != NULL; }
static void src_send(void* d, struct wl_data_source* s, const char* mime, int32_t fd) {
    (void)d; (void)s; (void)mime;
    ssize_t w = write(fd, "dragged", 7); (void)w;
    close(fd);
    src_send_count++;
}
static void src_cancelled_cb(void* d, struct wl_data_source* s) { (void)d; (void)s; src_cancelled++; }
static void src_drop_performed_cb(void* d, struct wl_data_source* s) { (void)d; (void)s; src_drop_performed++; }
static void src_finished_cb(void* d, struct wl_data_source* s) { (void)d; (void)s; src_finished++; }
static void src_action_cb(void* d, struct wl_data_source* s, uint32_t a) { (void)d; (void)s; src_action = a; }
static const struct wl_data_source_listener src_listener = {
    src_target_cb, src_send, src_cancelled_cb, src_drop_performed_cb, src_finished_cb, src_action_cb
};
static volatile int ptr_entered, ptr_left;
static void p_enter(void* d, struct wl_pointer* p, uint32_t s, struct wl_surface* sf, wl_fixed_t x, wl_fixed_t y) { (void)d; (void)p; (void)s; (void)sf; (void)x; (void)y; ptr_entered++; }
static void p_leave(void* d, struct wl_pointer* p, uint32_t s, struct wl_surface* sf) { (void)d; (void)p; (void)s; (void)sf; ptr_left++; }
static void p_motion(void* d, struct wl_pointer* p, uint32_t t, wl_fixed_t x, wl_fixed_t y) { (void)d; (void)p; (void)t; (void)x; (void)y; }
static void p_button(void* d, struct wl_pointer* p, uint32_t s, uint32_t t, uint32_t b, uint32_t st) { (void)d; (void)p; (void)s; (void)t; (void)b; (void)st; }
static void p_axis(void* d, struct wl_pointer* p, uint32_t t, uint32_t a, wl_fixed_t v) { (void)d; (void)p; (void)t; (void)a; (void)v; }
static void p_frame(void* d, struct wl_pointer* p) { (void)d; (void)p; }
static void p_axis_source(void* d, struct wl_pointer* p, uint32_t a) { (void)d; (void)p; (void)a; }
static void p_axis_stop(void* d, struct wl_pointer* p, uint32_t t, uint32_t a) { (void)d; (void)p; (void)t; (void)a; }
static void p_axis_discrete(void* d, struct wl_pointer* p, uint32_t a, int32_t v) { (void)d; (void)p; (void)a; (void)v; }
static void p_axis_value120(void* d, struct wl_pointer* p, uint32_t a, int32_t v) { (void)d; (void)p; (void)a; (void)v; }
static void p_axis_rel_dir(void* d, struct wl_pointer* p, uint32_t a, uint32_t v) { (void)d; (void)p; (void)a; (void)v; }
static const struct wl_pointer_listener p_listener = {
    p_enter, p_leave, p_motion, p_button, p_axis, p_frame, p_axis_source, p_axis_stop,
    p_axis_discrete, p_axis_value120, p_axis_rel_dir
};
static uint32_t dnd_tl_sid;
static void task_dnd_motion(void* arg) { (void)arg; wayland_server_pointer_motion(server, dnd_tl_sid, 1, 5, 6); }
static void task_dnd_release(void* arg) { (void)arg; wayland_server_pointer_button(server, dnd_tl_sid, 2, 0x110, 0); }
static void task_dnd_release_nowhere(void* arg) { (void)arg; wayland_server_pointer_global_release(server); }

static void test_dnd(void) {
    LOCKED(dnd_tl_sid = seen.new_toplevel_id);
    struct wl_pointer* ptr = wl_seat_get_pointer(seat);
    wl_pointer_add_listener(ptr, &p_listener, NULL);
    struct wl_data_device* dd = wl_data_device_manager_get_data_device(dd_mgr, seat);
    wl_data_device_add_listener(dd, &dd_listener, NULL);
    struct wl_data_source* src = wl_data_device_manager_create_data_source(dd_mgr);
    wl_data_source_add_listener(src, &src_listener, NULL);
    wl_data_source_offer(src, "text/plain");
    wl_data_source_set_actions(src, WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY |
                                    WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE);

    /* The toplevel rides along: attached before the drag starts. */
    struct xdg_toplevel_drag_v1* td = xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(tdrag_mgr, src);
    xdg_toplevel_drag_v1_attach(td, tl_toplevel, 5, 7);

    struct wl_surface* icon = wl_compositor_create_surface(compositor);
    int icon_before; LOCKED(icon_before = seen.drag_icon_count);
    int td_before; LOCKED(td_before = seen.tdrag_count);
    wl_data_device_start_drag(dd, src, tl_surface, icon, 0);
    CHECK(wait_for(&dnd_entered, 500), "the origin is entered as the first target");
    CHECK(dnd_offer_seen == 1 && strcmp(offer_mime, "text/plain") == 0, "with an offer of %s", offer_mime);
    CHECK(offer_source_actions == (WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY | WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE),
          "source actions %u", offer_source_actions);
    CHECK(ptr_left == 1, "wl_pointer left the origin for the drag (%d)", ptr_left);
    volatile int got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.drag_icon_count > icon_before); usleep(10000); }
    CHECK(got && seen.drag_active && seen.drag_icon != 0, "the shell got the icon surface %u", seen.drag_icon);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.tdrag_count > td_before); usleep(10000); }
    CHECK(got && seen.tdrag_active && seen.tdrag_surface == dnd_tl_sid && seen.tdrag_x == 5 && seen.tdrag_y == 7,
          "the toplevel follows at (%d, %d)", seen.tdrag_x, seen.tdrag_y);

    /* An icon buffer is a role of its own: it reaches the shell as a commit. */
    int shm_before; LOCKED(shm_before = seen.shm_count);
    struct wl_buffer* ib = make_buffer(8, 8, WL_SHM_FORMAT_ARGB8888, NULL);
    wl_surface_attach(icon, ib, 0, 0);
    wl_surface_commit(icon);
    wl_display_flush(dpy);
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = seen.shm_count > shm_before); usleep(10000); }
    CHECK(got && seen.shm_surface == seen.drag_icon && seen.shm_keep_alpha, "the icon's buffer composited with alpha");

    /* The target picks: copy of copy|move. */
    wl_data_offer_set_actions(dnd_offer, WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY,
                              WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY);
    wl_data_offer_accept(dnd_offer, 0, "text/plain");
    wl_display_roundtrip(dpy);
    CHECK(offer_action == WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY && src_action == offer_action,
          "both sides told the action (%u / %u)", offer_action, src_action);
    CHECK(src_target == 1, "the source heard target");

    on_server(task_dnd_motion, NULL);
    CHECK(wait_for(&dnd_motion, 500), "motion is data_device motion");
    on_server(task_dnd_release, NULL);
    CHECK(wait_for(&dnd_dropped, 500), "the release is the drop");
    CHECK(wait_for(&src_drop_performed, 500), "source heard dnd_drop_performed");
    got = 0;
    for (int i = 0; i < 50 && !got; i++) { LOCKED(got = !seen.drag_active && !seen.tdrag_active); usleep(10000); }
    CHECK(got, "the shell heard the drag and the toplevel drag end");
    CHECK(wait_for(&ptr_entered, 500), "wl_pointer is back on the surface under it");

    /* The data itself, then finish. */
    int fds[2];
    CHECK(pipe2(fds, O_CLOEXEC) == 0, "pipe");
    wl_data_offer_receive(dnd_offer, "text/plain", fds[1]);
    close(fds[1]);
    wl_display_flush(dpy);
    char buf[16] = "";
    got = 0;
    for (int i = 0; i < 50 && !got; i++) {
        wl_display_dispatch_pending(dpy); wl_display_flush(dpy);
        got = src_send_count > 0;
        if (!got) { wait_for(&src_send_count, 10); }
    }
    ssize_t n = read(fds[0], buf, sizeof(buf) - 1);
    close(fds[0]);
    CHECK(n == 7 && strcmp(buf, "dragged") == 0, "received \"%s\" from the source", buf);
    wl_data_offer_finish(dnd_offer);
    CHECK(wait_for(&src_finished, 500), "source heard dnd_finished");
    wl_data_offer_destroy(dnd_offer);
    xdg_toplevel_drag_v1_destroy(td);
    wl_data_source_destroy(src);
    wl_surface_destroy(icon);
    wl_display_roundtrip(dpy);
    wl_buffer_destroy(ib);

    /* A drag released over nothing is cancelled. */
    src = wl_data_device_manager_create_data_source(dd_mgr);
    wl_data_source_add_listener(src, &src_listener, NULL);
    wl_data_source_offer(src, "text/plain");
    wl_data_device_start_drag(dd, src, tl_surface, NULL, 0);
    wl_display_roundtrip(dpy);
    on_server(task_dnd_release_nowhere, NULL);
    CHECK(wait_for(&src_cancelled, 500), "released nowhere: cancelled");
    wl_data_source_destroy(src);
    wl_data_device_release(dd);
    wl_pointer_release(ptr);
    wl_display_roundtrip(dpy);
}

/* The packer: B,G,R,A rows with a stride -> tight R,G,B,A, alpha forced or kept. */
static void test_pack_rgba(void) {
    uint8_t src[2 * 12] = {
        /* row 0: two pixels + 4 bytes of stride padding */
        0x11, 0x22, 0x33, 0x44,  0x55, 0x66, 0x77, 0x00,  0xEE, 0xEE, 0xEE, 0xEE,
        /* row 1 */
        0xAA, 0xBB, 0xCC, 0x80,  0x01, 0x02, 0x03, 0x10,  0xEE, 0xEE, 0xEE, 0xEE,
    };
    uint8_t dst[16];
    wayland_shm_pack_rgba(dst, src, 2, 2, 12, 0);
    CHECK(dst[0] == 0x33 && dst[1] == 0x22 && dst[2] == 0x11 && dst[3] == 0xFF,
          "pixel 0 forced opaque: %02x %02x %02x %02x", dst[0], dst[1], dst[2], dst[3]);
    CHECK(dst[4] == 0x77 && dst[5] == 0x66 && dst[6] == 0x55 && dst[7] == 0xFF, "pixel 1");
    CHECK(dst[8] == 0xCC && dst[9] == 0xBB && dst[10] == 0xAA && dst[11] == 0xFF, "row 1 skipped the padding");
    wayland_shm_pack_rgba(dst, src, 2, 2, 12, 1);
    CHECK(dst[3] == 0x44 && dst[7] == 0x00 && dst[11] == 0x80 && dst[15] == 0x10, "alpha kept");
}

/* The toplevel goes: the taskbars hear closed. */
/* xdg_toplevel min/max size hints: double-buffered, the four reach the
 * shell together on commit, and only when they changed. */
static void test_size_hints(void) {
    int before; LOCKED(before = seen.hints_count);
    xdg_toplevel_set_min_size(tl_toplevel, 320, 240);
    xdg_toplevel_set_max_size(tl_toplevel, 1600, 1200);
    wl_display_roundtrip(dpy);
    int n; LOCKED(n = seen.hints_count);
    CHECK(n == before, "size hints wait for the commit");
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    LOCKED(n = seen.hints_count);
    CHECK(n == before + 1, "size hints reached the shell on commit (%d)", n - before);
    CHECK(seen.hints_surface == seen.new_toplevel_id, "for the toplevel");
    CHECK(seen.min_w == 320 && seen.min_h == 240 && seen.max_w == 1600 && seen.max_h == 1200,
          "hints %dx%d..%dx%d", seen.min_w, seen.min_h, seen.max_w, seen.max_h);
    xdg_toplevel_set_min_size(tl_toplevel, 320, 240);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    LOCKED(n = seen.hints_count);
    CHECK(n == before + 1, "unchanged hints are not repeated");
    xdg_toplevel_set_max_size(tl_toplevel, 0, 0);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    CHECK(seen.max_w == 0 && seen.max_h == 0 && seen.min_w == 320, "max cleared, min kept");
}

/* xdg_popup.grab: a press inside the popup's tree leaves it; a press on
 * the parent window, or on nothing (the desktop), dismisses it with
 * popup_done — a nested pair topmost first. */
static int pu_done_order[8], pu_done_n;
static volatile int pu_conf_n; static int32_t pu_conf_x, pu_conf_y, pu_conf_w, pu_conf_h;
static volatile int pu_repos_n; static uint32_t pu_repos_token;
static void pu_configure(void* d, struct xdg_popup* p, int32_t x, int32_t y, int32_t w, int32_t h) {
    (void)d; (void)p;
    pu_conf_x = x; pu_conf_y = y; pu_conf_w = w; pu_conf_h = h; pu_conf_n++;
}
static void pu_done(void* d, struct xdg_popup* p) {
    (void)p;
    if (pu_done_n < 8) pu_done_order[pu_done_n] = (int)(intptr_t)d;
    pu_done_n++;
}
static void pu_repositioned(void* d, struct xdg_popup* p, uint32_t token) { (void)d; (void)p; pu_repos_token = token; pu_repos_n++; }
static const struct xdg_popup_listener pu_listener = { pu_configure, pu_done, pu_repositioned };

static uint32_t press_sid;
static void task_press(void* arg) {
    (void)arg;
    wayland_server_pointer_button(server, press_sid, 1, 0x110, 1);
    wayland_server_pointer_button(server, press_sid, 2, 0x110, 0);
}
static void task_press_outside(void* arg) { (void)arg; wayland_server_pointer_pressed_outside(server); }

struct test_popup { struct wl_surface* s; struct xdg_surface* xs; struct xdg_popup* p; uint32_t sid; };
static struct test_popup make_grabbed_popup(struct xdg_surface* parent, int tag) {
    struct test_popup tp;
    tp.s = wl_compositor_create_surface(compositor);
    tp.xs = xdg_wm_base_get_xdg_surface(wm_base, tp.s);
    xdg_surface_add_listener(tp.xs, &xs_listener, NULL);
    struct xdg_positioner* pos = xdg_wm_base_create_positioner(wm_base);
    xdg_positioner_set_size(pos, 100, 80);
    xdg_positioner_set_anchor_rect(pos, 10, 10, 1, 1);
    tp.p = xdg_surface_get_popup(tp.xs, parent, pos);
    xdg_popup_add_listener(tp.p, &pu_listener, (void*)(intptr_t)tag);
    xdg_popup_grab(tp.p, seat, 0);
    xdg_positioner_destroy(pos);
    int before; LOCKED(before = seen.popup_count);
    wl_surface_commit(tp.s);
    wl_display_roundtrip(dpy);
    int after; LOCKED(after = seen.popup_count);
    CHECK(after == before + 1, "popup announced to the shell");
    tp.sid = seen.popup_id;
    return tp;
}
static void destroy_test_popup(struct test_popup* tp) {
    xdg_popup_destroy(tp->p);
    xdg_surface_destroy(tp->xs);
    wl_surface_destroy(tp->s);
    wl_display_roundtrip(dpy);
}
static int wait_done(int n, int ms) {
    struct timespec start; clock_gettime(CLOCK_MONOTONIC, &start);
    while (pu_done_n < n) {
        wl_display_roundtrip(dpy);
        struct timespec now; clock_gettime(CLOCK_MONOTONIC, &now);
        long spent = (now.tv_sec - start.tv_sec) * 1000 + (now.tv_nsec - start.tv_nsec) / 1000000;
        if (spent > ms) break;
        usleep(5000);
    }
    return pu_done_n >= n;
}

static void test_popup_grab(void) {
    uint32_t tl_sid = seen.new_toplevel_id;

    /* Inside: the press goes to the popup, which stays. */
    pu_done_n = 0;
    struct test_popup a = make_grabbed_popup(tl_xdg, 1);
    press_sid = a.sid;
    on_server(task_press, NULL);
    CHECK(!wait_done(1, 150), "a press inside the grabbed popup does not dismiss it");
    /* On the parent window: dismissed. */
    press_sid = tl_sid;
    on_server(task_press, NULL);
    CHECK(wait_done(1, 500), "a press on the parent window sends popup_done");
    destroy_test_popup(&a);

    /* On nothing at all (the desktop, the dock): dismissed. */
    pu_done_n = 0;
    struct test_popup b = make_grabbed_popup(tl_xdg, 2);
    on_server(task_press_outside, NULL);
    CHECK(wait_done(1, 500), "a press outside every client surface sends popup_done");
    destroy_test_popup(&b);

    /* Nested: a submenu over its menu. A press on the menu keeps both (the
     * client closes its own submenu); a press on the window drops both,
     * the submenu first. */
    pu_done_n = 0;
    struct test_popup m = make_grabbed_popup(tl_xdg, 3);
    struct test_popup sub = make_grabbed_popup(m.xs, 4);
    press_sid = m.sid;
    on_server(task_press, NULL);
    CHECK(!wait_done(1, 150), "a press on the menu under a grabbed submenu dismisses nothing");
    press_sid = tl_sid;
    on_server(task_press, NULL);
    CHECK(wait_done(2, 500), "a press on the window dismisses the whole tree (%d)", pu_done_n);
    CHECK(pu_done_order[0] == 4 && pu_done_order[1] == 3, "submenu first, then the menu (%d, %d)",
          pu_done_order[0], pu_done_order[1]);
    destroy_test_popup(&sub);
    destroy_test_popup(&m);

    /* Reposition: a new positioner is answered with repositioned(token)
     * and a configure at the new place and size, and the shell hears it.
     * GTK4 does this right after the first configure and waits for it. */
    struct test_popup r = make_grabbed_popup(tl_xdg, 6);
    int conf_before = pu_conf_n, repos_before = pu_repos_n;
    struct xdg_positioner* np = xdg_wm_base_create_positioner(wm_base);
    xdg_positioner_set_size(np, 164, 248);
    xdg_positioner_set_anchor_rect(np, 800, 430, 1, 1);
    xdg_positioner_set_anchor(np, XDG_POSITIONER_ANCHOR_BOTTOM_LEFT);
    xdg_positioner_set_gravity(np, XDG_POSITIONER_GRAVITY_BOTTOM_RIGHT);
    xdg_popup_reposition(r.p, np, 77);
    xdg_positioner_destroy(np);
    wl_display_roundtrip(dpy);
    CHECK(pu_repos_n == repos_before + 1 && pu_repos_token == 77, "repositioned(77) came back (%d, %u)",
          pu_repos_n - repos_before, pu_repos_token);
    CHECK(pu_conf_n == conf_before + 1, "followed by a configure (%d)", pu_conf_n - conf_before);
    CHECK(pu_conf_w == 164 && pu_conf_h == 248, "at the new size %dx%d", pu_conf_w, pu_conf_h);
    CHECK(pu_conf_x == 800 && pu_conf_y == 431, "at the new place %d,%d", pu_conf_x, pu_conf_y);
    destroy_test_popup(&r);

    /* No grab: an outside press is nobody's business. */
    pu_done_n = 0;
    struct test_popup c;
    c.s = wl_compositor_create_surface(compositor);
    c.xs = xdg_wm_base_get_xdg_surface(wm_base, c.s);
    xdg_surface_add_listener(c.xs, &xs_listener, NULL);
    struct xdg_positioner* pos = xdg_wm_base_create_positioner(wm_base);
    xdg_positioner_set_size(pos, 100, 80);
    xdg_positioner_set_anchor_rect(pos, 10, 10, 1, 1);
    c.p = xdg_surface_get_popup(c.xs, tl_xdg, pos);
    xdg_popup_add_listener(c.p, &pu_listener, (void*)(intptr_t)5);
    xdg_positioner_destroy(pos);
    wl_surface_commit(c.s);
    wl_display_roundtrip(dpy);
    on_server(task_press_outside, NULL);
    press_sid = tl_sid;
    on_server(task_press, NULL);
    CHECK(!wait_done(1, 150), "an ungrabbed popup (a tooltip) is left alone");
    destroy_test_popup(&c);
}

/* wl_subsurface: a small subsurface of the window is placed for the shell
 * to draw inside it, its buffer arriving under its own id with alpha kept;
 * moving it re-places it; a buffer the size of the window's own is the
 * window's content and routes up; a null buffer unmaps it. */
static void test_subsurface(void) {
    uint32_t tl_sid = seen.new_toplevel_id;
    /* The window has real content again (the blur test left it a 4x4
     * frame, against which any subsurface looks like the whole window). */
    struct wl_buffer* frame = make_buffer(640, 480, WL_SHM_FORMAT_XRGB8888, NULL);
    TRASH(frame);
    wl_surface_attach(tl_surface, frame, 0, 0);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    int placed0, unmapped0, shm0;
    LOCKED(placed0 = seen.sub_placed; unmapped0 = seen.sub_unmapped; shm0 = seen.shm_count);

    struct wl_surface* s = wl_compositor_create_surface(compositor);
    struct wl_subsurface* ss = wl_subcompositor_get_subsurface(subcompositor, s, tl_surface);
    wl_subsurface_set_desync(ss);   /* synchronized is the default; tested below */
    wl_subsurface_set_position(ss, 40, 30);
    struct wl_buffer* small = make_buffer(200, 100, WL_SHM_FORMAT_ARGB8888, NULL);
    wl_surface_attach(s, small, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    int placed, shm; LOCKED(placed = seen.sub_placed; shm = seen.shm_count);
    CHECK(placed == placed0 + 1, "the subsurface was placed (%d)", placed - placed0);
    CHECK(seen.sub_top == tl_sid, "under the toplevel's window");
    CHECK(seen.sub_x == 40 && seen.sub_y == 30, "at its offset (%d,%d)", seen.sub_x, seen.sub_y);
    CHECK(shm == shm0 + 1, "its buffer reached the shell (%d)", shm - shm0);
    CHECK(seen.shm_surface == seen.sub_id, "under the subsurface's own id");
    CHECK(seen.shm_w == 200 && seen.shm_h == 100, "at its own size %dx%d", seen.shm_w, seen.shm_h);
    CHECK(seen.shm_keep_alpha, "with its alpha kept (a hover card is see-through)");

    /* A frame at the same place: no new placement. */
    wl_surface_attach(s, small, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    LOCKED(placed = seen.sub_placed);
    CHECK(placed == placed0 + 1, "a plain frame does not re-place it");

    /* Moved. */
    wl_subsurface_set_position(ss, 50, 60);
    wl_surface_attach(s, small, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    LOCKED(placed = seen.sub_placed);
    CHECK(placed == placed0 + 2 && seen.sub_x == 50 && seen.sub_y == 60,
          "moving it re-places it (%d at %d,%d)", placed - placed0, seen.sub_x, seen.sub_y);

    /* The window's content (Waydroid's full-size subsurface over a dummy
     * toplevel): routes up to the window, and the child is unmapped. */
    struct wl_buffer* big = make_buffer(2000, 1500, WL_SHM_FORMAT_XRGB8888, NULL);
    wl_surface_attach(s, big, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    int unmapped; LOCKED(unmapped = seen.sub_unmapped);
    CHECK(unmapped == unmapped0 + 1, "a full-size buffer unmaps the child (%d)", unmapped - unmapped0);
    CHECK(seen.shm_surface == tl_sid && seen.shm_w == 2000, "and is the window's content");

    /* Small again: placed anew; then a null buffer unmaps it. */
    wl_surface_attach(s, small, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    LOCKED(placed = seen.sub_placed);
    CHECK(placed == placed0 + 3, "a small buffer places it again");
    wl_surface_attach(s, NULL, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    LOCKED(unmapped = seen.sub_unmapped);
    CHECK(unmapped == unmapped0 + 2 && seen.sub_unmapped_id == seen.sub_id,
          "a null buffer unmaps it (%d)", unmapped - unmapped0);

    /* Placed once more (desynchronized, as these were), then stacking: a
     * second subsurface arrives on top; place_below puts it under. */
    wl_surface_attach(s, small, 0, 0);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    CHECK(seen.sub_z == 0, "the first subsurface ranks 0 (%d)", seen.sub_z);
    struct wl_surface* s2 = wl_compositor_create_surface(compositor);
    struct wl_subsurface* ss2 = wl_subcompositor_get_subsurface(subcompositor, s2, tl_surface);
    wl_subsurface_set_desync(ss2);
    wl_subsurface_set_position(ss2, 10, 10);
    wl_surface_attach(s2, small, 0, 0);
    wl_surface_commit(s2);
    wl_display_roundtrip(dpy);
    uint32_t s2_sid = seen.sub_id;
    CHECK(seen.sub_z == 1, "a new subsurface ranks above its sibling (%d)", seen.sub_z);
    LOCKED(placed = seen.sub_placed);
    wl_subsurface_place_below(ss2, s);
    wl_display_roundtrip(dpy);
    int placed2; LOCKED(placed2 = seen.sub_placed);
    CHECK(placed2 == placed + 2, "both were re-placed with their new ranks (%d)", placed2 - placed);
    CHECK(seen.sub_id != s2_sid && seen.sub_z == 1, "the first is now on top (%u at %d)", seen.sub_id, seen.sub_z);

    /* Synchronized mode: a commit waits for the parent's. */
    LOCKED(seen.watch_shm_sid = s2_sid; seen.watch_shm_count = 0);
    wl_subsurface_set_sync(ss2);
    wl_surface_attach(s2, small, 0, 0);
    wl_surface_commit(s2);
    wl_display_roundtrip(dpy);
    int wc; LOCKED(wc = seen.watch_shm_count);
    CHECK(wc == 0, "a synchronized subsurface's commit is held (%d)", wc);
    wl_surface_commit(tl_surface);
    wl_display_roundtrip(dpy);
    LOCKED(wc = seen.watch_shm_count);
    CHECK(wc == 1, "and applied when the parent commits (%d)", wc);
    /* Leaving sync mode applies what was waiting. */
    wl_surface_attach(s2, small, 0, 0);
    wl_surface_commit(s2);
    wl_display_roundtrip(dpy);
    LOCKED(wc = seen.watch_shm_count);
    CHECK(wc == 1, "held again (%d)", wc);
    wl_subsurface_set_desync(ss2);
    wl_display_roundtrip(dpy);
    LOCKED(wc = seen.watch_shm_count);
    CHECK(wc == 2, "set_desync applies it (%d)", wc);
    LOCKED(seen.watch_shm_sid = 0);
    wl_subsurface_destroy(ss2);
    wl_surface_destroy(s2);
    wl_display_roundtrip(dpy);

    /* The role and the surface go: unmapped once. */
    LOCKED(unmapped = seen.sub_unmapped);
    unmapped0 = unmapped - 2;
    wl_subsurface_destroy(ss);
    wl_surface_destroy(s);
    wl_display_roundtrip(dpy);
    LOCKED(unmapped = seen.sub_unmapped);
    CHECK(unmapped == unmapped0 + 3, "destroying it unmaps it, once (%d)", unmapped - unmapped0);
    wl_buffer_destroy(small);
    wl_buffer_destroy(big);
}

/* xdg_toplevel.set_parent: the shell hears which window a dialog belongs
 * to, as the request arrives, and hears it cleared. */
static void test_toplevel_parent(void) {
    uint32_t tl_sid = seen.new_toplevel_id;
    int before; LOCKED(before = seen.parent_count);
    struct wl_surface* s = wl_compositor_create_surface(compositor);
    struct xdg_surface* xs = xdg_wm_base_get_xdg_surface(wm_base, s);
    xdg_surface_add_listener(xs, &xs_listener, NULL);
    struct xdg_toplevel* t = xdg_surface_get_toplevel(xs);
    xdg_toplevel_add_listener(t, &tl_listener, NULL);
    xdg_toplevel_set_parent(t, tl_toplevel);
    wl_surface_commit(s);
    wl_display_roundtrip(dpy);
    uint32_t dlg_sid = seen.new_toplevel_id;
    int n; LOCKED(n = seen.parent_count);
    CHECK(n == before + 1, "the parent reached the shell (%d)", n - before);
    CHECK(seen.parent_child == dlg_sid && seen.parent_parent == tl_sid,
          "dialog %u for window %u (got %u for %u)", dlg_sid, tl_sid,
          seen.parent_child, seen.parent_parent);
    xdg_toplevel_set_parent(t, tl_toplevel);
    wl_display_roundtrip(dpy);
    LOCKED(n = seen.parent_count);
    CHECK(n == before + 1, "the same parent again is not repeated");
    xdg_toplevel_set_parent(t, NULL);
    wl_display_roundtrip(dpy);
    LOCKED(n = seen.parent_count);
    CHECK(n == before + 2 && seen.parent_parent == 0, "cleared (%d, parent %u)", n - before,
          seen.parent_parent);
    xdg_toplevel_destroy(t);
    xdg_surface_destroy(xs);
    wl_surface_destroy(s);
    wl_display_roundtrip(dpy);
    LOCKED(seen.new_toplevel_id = tl_sid);
}

/* zwp_primary_selection: a selection set on one device reaches every
 * device, its data comes through on receive, a device bound later hears
 * of it when the pointer enters a surface (never at get_device), a new
 * source displaces the old with cancelled, and the owner going empties it. */
static volatile int ps_offered;
static char ps_mime[64];
static struct zwp_primary_selection_offer_v1* ps_offer;
static void pso_offer(void* d, struct zwp_primary_selection_offer_v1* o, const char* mime) {
    (void)d; (void)o; snprintf(ps_mime, sizeof(ps_mime), "%s", mime);
}
static const struct zwp_primary_selection_offer_v1_listener pso_listener = { pso_offer };
static void psd_data_offer(void* d, struct zwp_primary_selection_device_v1* dev,
                           struct zwp_primary_selection_offer_v1* o) {
    (void)d; (void)dev;
    TRASH(o);
    zwp_primary_selection_offer_v1_add_listener(o, &pso_listener, NULL);
}
static void psd_selection(void* d, struct zwp_primary_selection_device_v1* dev,
                          struct zwp_primary_selection_offer_v1* o) {
    (void)d; (void)dev; ps_offer = o; ps_offered++;
}
static const struct zwp_primary_selection_device_v1_listener psd_listener = { psd_data_offer, psd_selection };
static volatile int pss_sent, pss_cancelled;
static void pss_send(void* d, struct zwp_primary_selection_source_v1* s, const char* mime, int32_t fd) {
    (void)d; (void)s; (void)mime;
    ssize_t w = write(fd, "hello", 5); (void)w;
    close(fd);
    pss_sent++;
}
static void pss_cancel(void* d, struct zwp_primary_selection_source_v1* s) { (void)d; (void)s; pss_cancelled++; }
static const struct zwp_primary_selection_source_v1_listener pss_listener = { pss_send, pss_cancel };
static uint32_t enter_sid;
static void task_enter(void* arg) { (void)arg; wayland_server_pointer_enter(server, enter_sid, 5, 5); }

static void test_primary_selection(void) {
    if (!prim_mgr) { CHECK(0, "no zwp_primary_selection_device_manager_v1"); return; }
    struct zwp_primary_selection_device_v1* d1 =
        zwp_primary_selection_device_manager_v1_get_device(prim_mgr, seat);
    zwp_primary_selection_device_v1_add_listener(d1, &psd_listener, NULL);
    struct zwp_primary_selection_device_v1* d2 =
        zwp_primary_selection_device_manager_v1_get_device(prim_mgr, seat);
    zwp_primary_selection_device_v1_add_listener(d2, &psd_listener, NULL);
    wl_display_roundtrip(dpy);
    CHECK(ps_offered == 0, "no selection event at get_device (Qt6 init crashes on one)");

    struct zwp_primary_selection_source_v1* src =
        zwp_primary_selection_device_manager_v1_create_source(prim_mgr);
    zwp_primary_selection_source_v1_add_listener(src, &pss_listener, NULL);
    zwp_primary_selection_source_v1_offer(src, "text/plain");
    zwp_primary_selection_device_v1_set_selection(d1, src, 0);
    wl_display_roundtrip(dpy);
    CHECK(ps_offered == 2, "both devices were handed the selection (%d)", ps_offered);
    CHECK(strcmp(ps_mime, "text/plain") == 0, "with its mime type (%s)", ps_mime);
    CHECK(ps_offer != NULL, "as an offer");
    if (ps_offer) {
        int fds[2];
        CHECK(pipe2(fds, O_CLOEXEC) == 0, "pipe");
        zwp_primary_selection_offer_v1_receive(ps_offer, "text/plain", fds[1]);
        close(fds[1]);
        wl_display_flush(dpy);
        CHECK(wait_for(&pss_sent, 500), "the source was asked to send");
        char buf[16] = {0};
        ssize_t n = read(fds[0], buf, sizeof(buf) - 1);
        close(fds[0]);
        CHECK(n == 5 && strcmp(buf, "hello") == 0, "and the data came through (%zd: %s)", n, buf);
    }

    /* A device bound after the copy: told when the pointer enters. */
    ps_offered = 0;
    struct zwp_primary_selection_device_v1* d3 =
        zwp_primary_selection_device_manager_v1_get_device(prim_mgr, seat);
    zwp_primary_selection_device_v1_add_listener(d3, &psd_listener, NULL);
    wl_display_roundtrip(dpy);
    CHECK(ps_offered == 0, "a late device is not told at get_device");
    enter_sid = seen.new_toplevel_id;
    on_server(task_enter, NULL);
    CHECK(wait_for(&ps_offered, 500), "a late device hears of the selection when the pointer enters");
    CHECK(ps_offered == 1, "once (%d), the others already had it", ps_offered);

    /* A new source displaces the old one. */
    struct zwp_primary_selection_source_v1* src2 =
        zwp_primary_selection_device_manager_v1_create_source(prim_mgr);
    zwp_primary_selection_source_v1_add_listener(src2, &pss_listener, NULL);
    zwp_primary_selection_source_v1_offer(src2, "text/plain");
    ps_offered = 0;
    zwp_primary_selection_device_v1_set_selection(d2, src2, 0);
    wl_display_roundtrip(dpy);
    CHECK(pss_cancelled == 1, "the displaced source was cancelled (%d)", pss_cancelled);
    CHECK(ps_offered == 3, "every device got the new one (%d)", ps_offered);

    /* The owner goes: the selection empties. */
    ps_offered = 0; ps_offer = (void*)(intptr_t)1;
    zwp_primary_selection_source_v1_destroy(src2);
    wl_display_roundtrip(dpy);
    CHECK(ps_offered == 3 && ps_offer == NULL, "destroying the owner empties it (%d, %p)",
          ps_offered, (void*)ps_offer);

    zwp_primary_selection_source_v1_destroy(src);
    zwp_primary_selection_device_v1_destroy(d1);
    zwp_primary_selection_device_v1_destroy(d2);
    zwp_primary_selection_device_v1_destroy(d3);
    wl_display_roundtrip(dpy);
}

/* A client that binds wl_seat at version 1 (weston's demos do) has no
 * listener for wl_pointer.frame (v5); a compositor that sends it anyway
 * aborts the client — libwayland cannot dispatch it. Here the abort would
 * be this process's, so the run dies rather than reports. */
static volatile int v1_buttons;
static void v1p_enter(void* d, struct wl_pointer* p, uint32_t s, struct wl_surface* sf, wl_fixed_t x, wl_fixed_t y) { (void)d; (void)p; (void)s; (void)sf; (void)x; (void)y; }
static void v1p_leave(void* d, struct wl_pointer* p, uint32_t s, struct wl_surface* sf) { (void)d; (void)p; (void)s; (void)sf; }
static void v1p_motion(void* d, struct wl_pointer* p, uint32_t t, wl_fixed_t x, wl_fixed_t y) { (void)d; (void)p; (void)t; (void)x; (void)y; }
static void v1p_button(void* d, struct wl_pointer* p, uint32_t s, uint32_t t, uint32_t b, uint32_t st) { (void)d; (void)p; (void)s; (void)t; (void)b; (void)st; v1_buttons++; }
static void v1p_axis(void* d, struct wl_pointer* p, uint32_t t, uint32_t a, wl_fixed_t v) { (void)d; (void)p; (void)t; (void)a; (void)v; }
static const struct wl_pointer_listener v1p_listener = {
    .enter = v1p_enter, .leave = v1p_leave, .motion = v1p_motion,
    .button = v1p_button, .axis = v1p_axis,
    /* .frame and later stay NULL, as they are for a v1 client */
};
static void task_motion_and_press(void* arg) {
    (void)arg;
    wayland_server_pointer_motion(server, press_sid, 3, 7, 7);
    wayland_server_pointer_button(server, press_sid, 4, 0x110, 1);
    wayland_server_pointer_button(server, press_sid, 5, 0x110, 0);
    wayland_server_pointer_leave(server, press_sid);
}
/* The primary selection through the clipboard managers' protocol: a
 * selection made natively reaches an ext-data-control device, and one set
 * through it reaches a native device — `wl-paste --primary` and the mouse
 * agree. */
static void test_primary_via_data_control(void) {
    if (!edc_mgr || !prim_mgr) { CHECK(0, "managers missing"); return; }
    struct ext_data_control_device_v1* dev =
        ext_data_control_manager_v1_get_data_device(edc_mgr, seat);
    ext_data_control_device_v1_add_listener(dev, &ed_listener, NULL);
    wl_display_roundtrip(dpy);
    CHECK(edc_primary_null >= 1, "an empty primary is announced at get_data_device (%d)", edc_primary_null);

    struct zwp_primary_selection_device_v1* pd =
        zwp_primary_selection_device_manager_v1_get_device(prim_mgr, seat);
    zwp_primary_selection_device_v1_add_listener(pd, &psd_listener, NULL);
    struct zwp_primary_selection_source_v1* src =
        zwp_primary_selection_device_manager_v1_create_source(prim_mgr);
    zwp_primary_selection_source_v1_add_listener(src, &pss_listener, NULL);
    zwp_primary_selection_source_v1_offer(src, "text/plain");
    edc_primary_offered = 0;
    zwp_primary_selection_device_v1_set_selection(pd, src, 0);
    wl_display_roundtrip(dpy);
    CHECK(edc_primary_offered == 1, "a native primary selection reaches the data-control device (%d)",
          edc_primary_offered);
    CHECK(strcmp(edc_mime, "text/plain") == 0, "with its mime type (%s)", edc_mime);

    struct ext_data_control_source_v1* esrc = ext_data_control_manager_v1_create_data_source(edc_mgr);
    ext_data_control_source_v1_add_listener(esrc, &es_listener, NULL);
    ext_data_control_source_v1_offer(esrc, "text/x-from-manager");
    ps_offered = 0;
    ext_data_control_device_v1_set_primary_selection(dev, esrc);
    wl_display_roundtrip(dpy);
    CHECK(ps_offered == 1, "a primary set through data-control reaches the native device (%d)", ps_offered);
    CHECK(strcmp(ps_mime, "text/x-from-manager") == 0, "with its mime type (%s)", ps_mime);
    ext_data_control_source_v1_destroy(esrc);
    zwp_primary_selection_source_v1_destroy(src);
    zwp_primary_selection_device_v1_destroy(pd);
    ext_data_control_device_v1_destroy(dev);
    wl_display_roundtrip(dpy);
}

static void test_seat_v1_pointer(void) {
    struct wl_seat* seat1 = wl_registry_bind(registry, seat_gname, &wl_seat_interface, 1);
    struct wl_pointer* ptr = wl_seat_get_pointer(seat1);
    wl_pointer_add_listener(ptr, &v1p_listener, NULL);
    wl_display_roundtrip(dpy);
    press_sid = seen.new_toplevel_id;
    enter_sid = press_sid;
    on_server(task_enter, NULL);
    on_server(task_motion_and_press, NULL);
    CHECK(wait_for(&v1_buttons, 500), "a v1 pointer gets its button events, and lives");
    CHECK(v1_buttons == 2, "press and release (%d)", v1_buttons);
    wl_pointer_destroy(ptr);
    wl_seat_destroy(seat1);
    wl_display_roundtrip(dpy);
}

static void test_unmap(void) {
    ftl_closed = 0;
    xdg_toplevel_destroy(tl_toplevel);
    xdg_surface_destroy(tl_xdg);
    wl_surface_destroy(tl_surface);
    CHECK(wait_for(&ftl_closed, 500), "handle closed when the toplevel went");
}

int main(void) {
    /* The verdict must survive a sanitizer abort at exit. */
    setvbuf(stdout, NULL, _IONBF, 0);
    char dir[] = "/tmp/starling-wl-test.XXXXXX";
    if (!mkdtemp(dir)) { perror("mkdtemp"); return 2; }
    setenv("XDG_RUNTIME_DIR", dir, 1);
    if (pipe2(task_pipe, O_NONBLOCK | O_CLOEXEC) != 0) { perror("pipe"); return 2; }

    WaylandServerConfig cfg = { .display_width = 1280, .display_height = 800,
                                .refresh_mhz = 60000, .scale = 1 };
    server = wayland_server_create(&cfg);
    if (!server) { printf("  FAIL: server did not start\n"); return 1; }
    wayland_server_on_new_toplevel(server, cb_new_toplevel, NULL);
    wayland_server_on_title_changed(server, cb_title, NULL);
    wayland_server_on_toplevel_request(server, cb_request, NULL);
    wayland_server_on_new_layer_surface(server, cb_new_layer, NULL);
    wayland_server_on_layer_surface_changed(server, cb_layer_changed, NULL);
    wayland_server_on_layer_surface_destroy(server, cb_layer_destroy, NULL);
    wayland_server_on_surface_alpha(server, cb_alpha, NULL);
    wayland_server_on_shm_surface_commit(server, cb_shm, NULL);
    wayland_server_on_screencopy_request(server, cb_screencopy, NULL);
    wayland_server_on_toplevel_position_request(server, cb_position, NULL);
    wayland_server_on_system_bell(server, cb_bell, NULL);
    wayland_server_on_shortcuts_inhibit(server, cb_inhibit, NULL);
    wayland_server_on_session_lock(server, cb_lock, NULL);
    wayland_server_on_workspace_request(server, cb_workspace, NULL);
    wayland_server_on_surface_blur(server, cb_blur, NULL);
    wayland_server_on_virtual_pointer(server, cb_vpointer, NULL);
    wayland_server_on_virtual_key(server, cb_vkey, NULL);
    wayland_server_on_pointer_warp(server, cb_warp, NULL);
    wayland_server_on_drag_icon(server, cb_drag_icon, NULL);
    wayland_server_on_toplevel_drag(server, cb_tdrag, NULL);
    wayland_server_on_output_config(server, cb_outcfg, NULL);
    wayland_server_on_toplevel_size_hints(server, cb_size_hints, NULL);
    wayland_server_on_toplevel_parent(server, cb_parent, NULL);
    wayland_server_on_new_popup(server, cb_new_popup, NULL);
    wayland_server_on_subsurface_placed(server, cb_sub_placed, NULL);
    wayland_server_on_subsurface_unmapped(server, cb_sub_unmapped, NULL);
    pthread_create(&server_thread, NULL, server_main, NULL);

    dpy = wl_display_connect(wayland_server_get_socket_name(server));
    if (!dpy) { printf("  FAIL: client could not connect\n"); return 1; }
    registry = wl_display_get_registry(dpy);
    wl_registry_add_listener(registry, &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    wl_display_roundtrip(dpy);
    if (wm_base) xdg_wm_base_add_listener(wm_base, &wm_listener, NULL);

    test_globals();
    test_pack_rgba();
    if (compositor && shm && wm_base && output && seat) {
        test_toplevel_state_and_taskbars();
        test_activation();
        test_buffer_release();
        test_layer_shell();
        test_alpha();
        test_zones();
        test_screencopy();
        test_single_pixel();
        test_idle_notify();
        test_shortcuts_inhibit();
        test_ext_data_control();
        test_xdg_foreign();
        test_output_management();
        test_workspaces();
        test_background_effect();
        test_transient_seat();
        test_virtual_input();
        test_pointer_warp();
        test_dnd();
        test_image_copy_capture();
        test_security_context();
        test_session_lock();
        test_size_hints();
        test_popup_grab();
        test_subsurface();
        test_toplevel_parent();
        test_primary_selection();
        test_primary_via_data_control();
        test_seat_v1_pointer();
        test_unmap();
    } else {
        CHECK(0, "core globals missing; protocol tests skipped");
    }

    for (int i = ntrash - 1; i >= 0; i--) wl_proxy_destroy(trash[i]);
    wl_display_disconnect(dpy);
    atomic_store(&server_stop, 1);
    pthread_join(server_thread, NULL);
    wayland_server_destroy(server);

    /* the socket + lock the server left behind */
    char cmd[300];
    snprintf(cmd, sizeof(cmd), "rm -rf %s", dir);
    if (system(cmd) != 0) { /* not the test's concern */ }

    if (failures) {
        printf("%d wayland protocol checks FAILED\n", failures);
        return 1;
    }
    printf("all wayland protocol checks passed\n");
    return 0;
}
