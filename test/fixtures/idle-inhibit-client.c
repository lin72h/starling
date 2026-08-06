// Minimal zwp_idle_inhibit_manager_v1 client: bind the manager, make a
// surface, create ONE inhibitor, then sit there until killed. Stands in for
// Chrome playing a video. Killing it with SIGKILL exercises the
// client-disconnect path that the inhibitor count's resource destructor
// exists for.
//
// Built on the fly by test/functional.py (wayland-scanner + cc); there is no
// checked-in binary. `printf("inhibitor held")` is the handshake the test
// waits on — the inhibitor exists only after the roundtrip above it.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "idle-inhibit-unstable-v1-client-protocol.h"

static struct wl_compositor *compositor;
static struct zwp_idle_inhibit_manager_v1 *manager;

static void handle_global(void *data, struct wl_registry *reg, uint32_t name,
                          const char *iface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(iface, "wl_compositor")) {
        compositor = wl_registry_bind(reg, name, &wl_compositor_interface, 1);
    } else if (!strcmp(iface, "zwp_idle_inhibit_manager_v1")) {
        manager = wl_registry_bind(reg, name,
                                   &zwp_idle_inhibit_manager_v1_interface, 1);
    }
}
static void handle_global_remove(void *d, struct wl_registry *r, uint32_t n) {
    (void)d; (void)r; (void)n;
}
static const struct wl_registry_listener registry_listener = {
    handle_global, handle_global_remove,
};

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "no display\n"); return 1; }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!compositor) { fprintf(stderr, "no wl_compositor\n"); return 2; }
    if (!manager) { fprintf(stderr, "NO zwp_idle_inhibit_manager_v1\n"); return 3; }

    struct wl_surface *surface = wl_compositor_create_surface(compositor);
    struct zwp_idle_inhibitor_v1 *inhibitor =
        zwp_idle_inhibit_manager_v1_create_inhibitor(manager, surface);
    wl_display_roundtrip(display);
    if (!inhibitor) { fprintf(stderr, "create_inhibitor failed\n"); return 4; }

    printf("inhibitor held\n");
    fflush(stdout);
    while (wl_display_dispatch(display) != -1) { }
    return 0;
}
