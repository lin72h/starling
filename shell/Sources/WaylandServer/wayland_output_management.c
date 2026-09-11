// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_output_management.c — zwlr_output_manager_v1 (v4), read-only
 *
 * The protocol wlr-randr, kanshi and way-displays use to list outputs and
 * to change them. Listing is served in full: every output as a head with
 * its mode, position, scale and names, re-sent when the arrangement
 * changes. Changing is not: the shell's display settings own the
 * arrangement, so apply and test answer `failed`, which those tools report
 * as the compositor refusing — honest, where `succeeded` with nothing
 * changed would not be.
 */

#include "wayland_server_internal.h"
#include "wlr-output-management-unstable-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void release_request(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct zwlr_output_head_v1_interface head_impl = { .release = release_request };
static const struct zwlr_output_mode_v1_interface mode_impl = { .release = release_request };

static void manager_send_head(struct WaylandOutputManager* m, int i) {
    struct WaylandServer* server = m->server;
    struct WaylandOutput* o = &server->outputs[i];
    struct wl_client* client = wl_resource_get_client(m->resource);
    uint32_t version = wl_resource_get_version(m->resource);
    int fresh = m->heads[i] == NULL;
    if (fresh) {
        m->heads[i] = wl_resource_create(client, &zwlr_output_head_v1_interface, version, 0);
        if (!m->heads[i]) return;
        wl_resource_set_implementation(m->heads[i], &head_impl, NULL, NULL);
        zwlr_output_manager_v1_send_head(m->resource, m->heads[i]);
        zwlr_output_head_v1_send_name(m->heads[i], o->name);
        char desc[96];
        snprintf(desc, sizeof(desc), "Starling %s", o->name);
        zwlr_output_head_v1_send_description(m->heads[i], desc);
        if (version >= ZWLR_OUTPUT_HEAD_V1_MAKE_SINCE_VERSION) {
            zwlr_output_head_v1_send_make(m->heads[i], "Starling");
            zwlr_output_head_v1_send_model(m->heads[i], o->name);
        }
    }
    /* One mode: the current one. A mode object is immutable, so a changed
     * mode is a new object and the old one is finished. */
    if (m->modes[i]) {
        zwlr_output_mode_v1_send_finished(m->modes[i]);
        wl_resource_destroy(m->modes[i]);
        m->modes[i] = NULL;
    }
    m->modes[i] = wl_resource_create(client, &zwlr_output_mode_v1_interface, version, 0);
    if (m->modes[i]) {
        wl_resource_set_implementation(m->modes[i], &mode_impl, NULL, NULL);
        zwlr_output_head_v1_send_mode(m->heads[i], m->modes[i]);
        zwlr_output_mode_v1_send_size(m->modes[i], o->physical_w, o->physical_h);
        zwlr_output_mode_v1_send_refresh(m->modes[i], o->refresh_mhz);
        zwlr_output_mode_v1_send_preferred(m->modes[i]);
    }
    /* The same ~96 dpi physical size wl_output reports. */
    int32_t denom = (o->scale > 0 ? o->scale : 1) * 96;
    zwlr_output_head_v1_send_physical_size(m->heads[i],
        (int32_t)((o->physical_w * 254L + denom * 5) / (denom * 10L)),
        (int32_t)((o->physical_h * 254L + denom * 5) / (denom * 10L)));
    zwlr_output_head_v1_send_enabled(m->heads[i], 1);
    if (m->modes[i]) zwlr_output_head_v1_send_current_mode(m->heads[i], m->modes[i]);
    zwlr_output_head_v1_send_position(m->heads[i], o->logical_x, o->logical_y);
    zwlr_output_head_v1_send_transform(m->heads[i], WL_OUTPUT_TRANSFORM_NORMAL);
    zwlr_output_head_v1_send_scale(m->heads[i], wl_fixed_from_int(o->scale > 0 ? o->scale : 1));
    if (version >= ZWLR_OUTPUT_HEAD_V1_ADAPTIVE_SYNC_SINCE_VERSION) {
        zwlr_output_head_v1_send_adaptive_sync(m->heads[i],
            ZWLR_OUTPUT_HEAD_V1_ADAPTIVE_SYNC_STATE_DISABLED);
    }
}

static void manager_send_all(struct WaylandOutputManager* m) {
    struct WaylandServer* server = m->server;
    for (int i = 0; i < WAYLAND_MAX_OUTPUTS; i++) {
        if (i < server->output_count && server->outputs[i].global) {
            manager_send_head(m, i);
        } else if (m->heads[i]) {
            if (m->modes[i]) {
                zwlr_output_mode_v1_send_finished(m->modes[i]);
                wl_resource_destroy(m->modes[i]);
                m->modes[i] = NULL;
            }
            zwlr_output_head_v1_send_finished(m->heads[i]);
            wl_resource_destroy(m->heads[i]);
            m->heads[i] = NULL;
        }
    }
    zwlr_output_manager_v1_send_done(m->resource, ++server->output_config_serial);
}

/* --- configurations: accepted, then refused ------------------------------- */

static void config_head_noop_mode(struct wl_client* c, struct wl_resource* r, struct wl_resource* m) {
    (void)c; (void)r; (void)m;
}
static void config_head_custom_mode(struct wl_client* c, struct wl_resource* r,
                                    int32_t w, int32_t h, int32_t refresh) {
    (void)c; (void)r; (void)w; (void)h; (void)refresh;
}
static void config_head_position(struct wl_client* c, struct wl_resource* r, int32_t x, int32_t y) {
    (void)c; (void)r; (void)x; (void)y;
}
static void config_head_transform(struct wl_client* c, struct wl_resource* r, int32_t t) {
    (void)c; (void)r; (void)t;
}
static void config_head_scale(struct wl_client* c, struct wl_resource* r, wl_fixed_t s) {
    (void)c; (void)r; (void)s;
}
static void config_head_adaptive_sync(struct wl_client* c, struct wl_resource* r, uint32_t s) {
    (void)c; (void)r; (void)s;
}

static const struct zwlr_output_configuration_head_v1_interface config_head_impl = {
    .set_mode = config_head_noop_mode,
    .set_custom_mode = config_head_custom_mode,
    .set_position = config_head_position,
    .set_transform = config_head_transform,
    .set_scale = config_head_scale,
    .set_adaptive_sync = config_head_adaptive_sync,
};

static void config_enable_head(struct wl_client* client, struct wl_resource* resource,
                               uint32_t id, struct wl_resource* head) {
    (void)head;
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_output_configuration_head_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &config_head_impl, NULL, NULL);
}

static void config_disable_head(struct wl_client* c, struct wl_resource* r, struct wl_resource* head) {
    (void)c; (void)r; (void)head;
}

static void config_apply(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    zwlr_output_configuration_v1_send_failed(r);
}

static void config_test(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    zwlr_output_configuration_v1_send_failed(r);
}

static const struct zwlr_output_configuration_v1_interface config_impl = {
    .enable_head = config_enable_head,
    .disable_head = config_disable_head,
    .apply = config_apply,
    .test = config_test,
    .destroy = release_request,
};

/* --- manager ---------------------------------------------------------------- */

static void manager_create_configuration(struct wl_client* client, struct wl_resource* resource,
                                         uint32_t id, uint32_t serial) {
    (void)serial;
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_output_configuration_v1_interface, wl_resource_get_version(resource), id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &config_impl, NULL, NULL);
}

static void manager_stop(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandOutputManager* m = wl_resource_get_user_data(r);
    if (m) m->stopped = 1;
    zwlr_output_manager_v1_send_finished(r);
}

static const struct zwlr_output_manager_v1_interface manager_impl = {
    .create_configuration = manager_create_configuration,
    .stop = manager_stop,
};

static void manager_resource_destroyed(struct wl_resource* r) {
    struct WaylandOutputManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    wl_list_remove(&m->link);
    free(m);
}

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct WaylandServer* server = data;
    struct WaylandOutputManager* m = calloc(1, sizeof(*m));
    if (!m) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &zwlr_output_manager_v1_interface,
                                               version, id);
    if (!r) {
        free(m);
        wl_client_post_no_memory(client);
        return;
    }
    m->resource = r;
    m->server = server;
    wl_list_insert(&server->output_managers, &m->link);
    wl_resource_set_implementation(r, &manager_impl, m, manager_resource_destroyed);
    manager_send_all(m);
}

void wayland_output_management_init(struct WaylandServer* server) {
    wl_list_init(&server->output_managers);
    server->output_manager_global = wl_global_create(server->display,
        &zwlr_output_manager_v1_interface, 4, server, manager_bind);
}

void wayland_output_management_outputs_changed(struct WaylandServer* server) {
    struct WaylandOutputManager* m;
    wl_list_for_each(m, &server->output_managers, link) {
        if (!m->stopped) manager_send_all(m);
    }
}
