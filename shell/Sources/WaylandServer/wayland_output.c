// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_output.c — wl_output implementation (multi-output)
 *
 * Tells clients about the display arrangement: one wl_output global per
 * output of the virtual desktop, geometry in global logical coordinates,
 * plus wl_surface.enter/leave as toplevels move between outputs.
 */

#include "wayland_server_internal.h"
#include "fractional-scale-v1-protocol.h"
#include <stdio.h>
#include <string.h>

/* ========================================================================== */
/* wl_output                                                                  */
/* ========================================================================== */

static void surface_output_crossing(struct WaylandSurface* surface,
                                    struct WaylandOutput* output,
                                    int enter);

static void output_resource_destroy(struct wl_resource* resource) {
    wl_list_remove(wl_resource_get_link(resource));
}

static void output_release(struct wl_client* client,
                           struct wl_resource* resource) {
    (void)client;
    wl_resource_destroy(resource);
}

/*
 * wl_output requests (in protocol order):
 *   0  release  (since v3)
 */
static const struct wl_output_interface output_impl = {
    .release = output_release,
};

/* Send one output's full info burst to a bound resource. */
static void output_send_info(struct WaylandOutput* output,
                             struct wl_resource* resource) {
    uint32_t version = wl_resource_get_version(resource);

    /* Physical size in millimetres. We do not know the real panel size — the
     * DRM connector does (mmWidth/mmHeight) but that is not plumbed through
     * yet — and it is tempting to send 0x0 for "unknown". Do not: clients
     * divide by it to get a DPI. GDK then computes nonsense, which GTK3
     * survives with a warning ("GDK returned bogus values for the monitor
     * resolution, using 96 dpi") but GTK4 does not — it derives a scale from
     * it and trips `assertion 'scale >= 1' failed` inside the icon theme,
     * then dereferences the NULL paintable and dies. Chromium and Qt do not
     * care either way.
     *
     * So report the size a ~96 dpi panel of this mode and scale would have,
     * which is exactly the fallback GTK3 picks anyway. Replace this with the
     * connector's real mm once it is available. */
    int32_t denom = (output->scale > 0 ? output->scale : 1) * 96;
    int32_t mm_w = (int32_t)((output->physical_w * 254L + denom * 5) / (denom * 10L));
    int32_t mm_h = (int32_t)((output->physical_h * 254L + denom * 5) / (denom * 10L));
    if (mm_w <= 0) mm_w = 1;
    if (mm_h <= 0) mm_h = 1;

    wl_output_send_geometry(resource,
        output->logical_x, output->logical_y,  /* global compositor space */
        mm_w, mm_h,                            /* physical mm (derived) */
        WL_OUTPUT_SUBPIXEL_UNKNOWN,
        "Starling", output->name,              /* make, model */
        WL_OUTPUT_TRANSFORM_NORMAL);

    wl_output_send_mode(resource,
        WL_OUTPUT_MODE_CURRENT | WL_OUTPUT_MODE_PREFERRED,
        output->physical_w, output->physical_h, output->refresh_mhz);

    if (version >= 2) {
        wl_output_send_scale(resource, output->scale > 0 ? output->scale : 1);
    }
    if (version >= 4) {
        wl_output_send_name(resource, output->name);
    }
    if (version >= 2) {
        wl_output_send_done(resource);
    }
}

static void output_bind(struct wl_client* client, void* data,
                        uint32_t version, uint32_t id) {
    struct WaylandOutput* output = data;
    struct wl_resource* resource = wl_resource_create(client,
        &wl_output_interface, version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, &output_impl, output,
                                   output_resource_destroy);
    wl_list_insert(&output->resources, wl_resource_get_link(resource));
    output_send_info(output, resource);
}

void wayland_output_init(struct WaylandServer* server) {
    for (int i = 0; i < WAYLAND_MAX_OUTPUTS; i++) {
        server->outputs[i].server = server;
        server->outputs[i].index = i;
        server->outputs[i].global = NULL;
        wl_list_init(&server->outputs[i].resources);
    }
    /* Default single output from the create-time config; replaced by
     * wayland_server_set_outputs when the shell has a real arrangement. */
    struct WaylandOutput* primary = &server->outputs[0];
    primary->logical_x = 0;
    primary->logical_y = 0;
    primary->physical_w = server->config.display_width;
    primary->physical_h = server->config.display_height;
    primary->scale = server->config.scale > 0 ? server->config.scale : 1;
    primary->refresh_mhz = server->config.refresh_mhz;
    snprintf(primary->name, sizeof(primary->name), "primary");
    primary->global = wl_global_create(server->display, &wl_output_interface,
                                       4, primary, output_bind);
    server->output_count = 1;
}

void wayland_server_set_outputs(struct WaylandServer* server,
                                const WaylandOutputDesc* outputs, int count) {
    if (!server || !outputs || count <= 0) return;
    if (count > WAYLAND_MAX_OUTPUTS) count = WAYLAND_MAX_OUTPUTS;

    /* Shrinking (monitor unplugged): surfaces still on a dying output leave
     * it first, then its global goes away (clients see global_remove; their
     * bound resources stay valid until released). */
    for (int i = count; i < server->output_count; i++) {
        struct WaylandOutput* out = &server->outputs[i];
        struct WaylandSurface* surface;
        wl_list_for_each(surface, &server->surfaces, link) {
            if (surface->resource && (surface->outputs_mask & (1u << i))) {
                surface_output_crossing(surface, out, 0);
                surface->outputs_mask &= ~(1u << i);
            }
        }
        if (out->global) {
            wl_global_destroy(out->global);
            out->global = NULL;
        }
        fprintf(stderr, "[wayland_output] output %d \"%s\" removed\n", i,
                out->name);
    }

    for (int i = 0; i < count; i++) {
        struct WaylandOutput* out = &server->outputs[i];
        const WaylandOutputDesc* desc = &outputs[i];
        int changed = out->logical_x != desc->logical_x ||
                      out->logical_y != desc->logical_y ||
                      out->physical_w != desc->physical_w ||
                      out->physical_h != desc->physical_h ||
                      out->scale != desc->scale ||
                      out->refresh_mhz != desc->refresh_mhz ||
                      strncmp(out->name, desc->name, sizeof(out->name)) != 0;
        out->logical_x = desc->logical_x;
        out->logical_y = desc->logical_y;
        out->physical_w = desc->physical_w;
        out->physical_h = desc->physical_h;
        out->scale = desc->scale > 0 ? desc->scale : 1;
        out->refresh_mhz = desc->refresh_mhz;
        snprintf(out->name, sizeof(out->name), "%s", desc->name);

        if (!out->global) {
            /* New output: clients learn of it via a registry global event. */
            out->global = wl_global_create(server->display,
                &wl_output_interface, 4, out, output_bind);
        } else if (changed) {
            /* Update existing bindings in place. */
            struct wl_resource* res;
            wl_resource_for_each(res, &out->resources) {
                output_send_info(out, res);
            }
        }
        fprintf(stderr,
                "[wayland_output] output %d \"%s\": %dx%d @%dx at (%d,%d) "
                "%d mHz\n",
                i, out->name, out->physical_w, out->physical_h, out->scale,
                out->logical_x, out->logical_y, out->refresh_mhz);
    }
    server->output_count = count;
}

/* ========================================================================== */
/* Surface enter/leave                                                        */
/* ========================================================================== */

/* Send wl_surface.enter/leave for one output to the surface's client. */
static void surface_output_crossing(struct WaylandSurface* surface,
                                    struct WaylandOutput* output,
                                    int enter) {
    struct wl_client* client = wl_resource_get_client(surface->resource);
    struct wl_resource* out;
    wl_resource_for_each(out, &output->resources) {
        if (wl_resource_get_client(out) == client) {
            if (enter) {
                wl_surface_send_enter(surface->resource, out);
            } else {
                wl_surface_send_leave(surface->resource, out);
            }
        }
    }
    fprintf(stderr, "[wayland_output] surface %u %s \"%s\"\n", surface->id,
            enter ? "entered" : "left", output->name);
}

/* Apply a new outputs bitmask to a surface, diffing against the current one. */
static void surface_apply_outputs_mask(struct WaylandServer* server,
                                       struct WaylandSurface* surface,
                                       uint32_t mask) {
    uint32_t valid = server->output_count >= 32
                         ? 0xFFFFFFFFu
                         : ((1u << server->output_count) - 1u);
    mask &= valid;
    uint32_t changed = mask ^ surface->outputs_mask;
    if (!changed) return;
    for (int i = 0; i < server->output_count; i++) {
        uint32_t bit = 1u << i;
        if (changed & bit) {
            surface_output_crossing(surface, &server->outputs[i],
                                    (mask & bit) != 0);
        }
    }
    surface->outputs_mask = mask;
}

/* Map: the surface appears on the primary until the shell places it. */
void wayland_output_send_enter(struct WaylandServer* server,
                               struct WaylandSurface* surface) {
    if (!server || !surface || !surface->resource) return;
    surface_apply_outputs_mask(server, surface, 1u << 0);
}

/* Unmap (role destroyed): the surface left every output. */
void wayland_output_send_leave(struct WaylandServer* server,
                               struct WaylandSurface* surface) {
    if (!server || !surface || !surface->resource) return;
    surface_apply_outputs_mask(server, surface, 0);
}

void wayland_server_surface_set_outputs(struct WaylandServer* server,
                                        uint32_t surface_id, uint32_t mask) {
    if (!server) return;
    struct WaylandSurface* surface =
        wayland_server_find_surface(server, surface_id);
    if (!surface || !surface->resource) return;
    /* Only mapped surfaces track outputs (mask 0 = unmapped/hidden). */
    if (surface->outputs_mask == 0 && mask != 0 && !surface->had_role) return;
    surface_apply_outputs_mask(server, surface, mask);
}

void wayland_server_update_scale(struct WaylandServer* server,
                                  int scale, uint32_t fractional_scale_120ths) {
    if (!server) return;
    /* Update config so new client connections get the new scale.
     * Don't broadcast to existing clients — apps like Chrome with
     * --force-device-scale-factor can't handle runtime scale changes. */
    server->config.scale = scale;
    server->fractional_scale_120ths = fractional_scale_120ths;
    if (server->output_count > 0) {
        server->outputs[0].scale = scale > 0 ? scale : 1;
    }
    fprintf(stderr, "[wayland_output] Updated config scale=%d fractional=%u/120\n",
            scale, fractional_scale_120ths);
}
