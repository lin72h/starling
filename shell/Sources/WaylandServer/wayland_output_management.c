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

/* --- configurations ----------------------------------------------------------
 *
 * What the shell can change at runtime is the host output's scale; the
 * arrangement, modes and enablement come from the display hardware and the
 * shell's own settings. So a configuration is accepted when every head keeps
 * its mode, position and transform and at most the primary's scale differs:
 * that goes to the shell (on_output_config), which applies it through the
 * same path as its DPI setting and answers succeeded or failed. Anything
 * else fails at once. */

struct OutputConfig {
    struct WaylandServer* server;
    int unsupported;                 /* a change the shell cannot make */
    int configured;                  /* heads enabled or disabled so far */
    int have_scale;
    double scale;
};

struct OutputConfigHead {
    struct OutputConfig* config;
    int index;
};

static void config_head_set_mode(struct wl_client* c, struct wl_resource* r, struct wl_resource* m) {
    (void)c; (void)r; (void)m;
    /* One mode exists per head — the current one; asking for it changes nothing. */
}
static void config_head_custom_mode(struct wl_client* c, struct wl_resource* r,
                                    int32_t w, int32_t h, int32_t refresh) {
    (void)c;
    struct OutputConfigHead* ch = wl_resource_get_user_data(r);
    if (!ch || ch->index < 0) return;
    struct WaylandOutput* o = &ch->config->server->outputs[ch->index];
    if (w != o->physical_w || h != o->physical_h || (refresh && refresh != o->refresh_mhz))
        ch->config->unsupported = 1;
}
static void config_head_position(struct wl_client* c, struct wl_resource* r, int32_t x, int32_t y) {
    (void)c;
    struct OutputConfigHead* ch = wl_resource_get_user_data(r);
    if (!ch || ch->index < 0) return;
    struct WaylandOutput* o = &ch->config->server->outputs[ch->index];
    if (x != o->logical_x || y != o->logical_y) ch->config->unsupported = 1;
}
static void config_head_transform(struct wl_client* c, struct wl_resource* r, int32_t t) {
    (void)c;
    struct OutputConfigHead* ch = wl_resource_get_user_data(r);
    if (ch && t != WL_OUTPUT_TRANSFORM_NORMAL) ch->config->unsupported = 1;
}
static void config_head_scale(struct wl_client* c, struct wl_resource* r, wl_fixed_t s) {
    (void)c;
    struct OutputConfigHead* ch = wl_resource_get_user_data(r);
    if (!ch || ch->index < 0) return;
    double scale = wl_fixed_to_double(s);
    /* Always forwarded, even when it matches the advertised scale: the
     * shell's runtime density (its DPI slider) is not what wl_output says
     * — that is deliberately left alone for the clients' sake — so only
     * the shell knows whether this is a change. Applying is idempotent. */
    if (ch->index != 0 || scale < 1.0 || scale > 4.0) {
        ch->config->unsupported = 1;
        return;
    }
    ch->config->have_scale = 1;
    ch->config->scale = scale;
}
static void config_head_adaptive_sync(struct wl_client* c, struct wl_resource* r, uint32_t s) {
    (void)c;
    struct OutputConfigHead* ch = wl_resource_get_user_data(r);
    if (ch && s != ZWLR_OUTPUT_HEAD_V1_ADAPTIVE_SYNC_STATE_DISABLED) ch->config->unsupported = 1;
}

static const struct zwlr_output_configuration_head_v1_interface config_head_impl = {
    .set_mode = config_head_set_mode,
    .set_custom_mode = config_head_custom_mode,
    .set_position = config_head_position,
    .set_transform = config_head_transform,
    .set_scale = config_head_scale,
    .set_adaptive_sync = config_head_adaptive_sync,
};

static void config_head_resource_destroyed(struct wl_resource* r) {
    free(wl_resource_get_user_data(r));
}

/* Which output a head resource stands for. */
static int head_index_of(struct WaylandServer* server, struct wl_resource* head) {
    struct WaylandOutputManager* m;
    wl_list_for_each(m, &server->output_managers, link) {
        for (int i = 0; i < WAYLAND_MAX_OUTPUTS; i++) {
            if (head && m->heads[i] == head) return i;
        }
    }
    return -1;
}

static void config_enable_head(struct wl_client* client, struct wl_resource* resource,
                               uint32_t id, struct wl_resource* head) {
    struct OutputConfig* cfg = wl_resource_get_user_data(resource);
    struct OutputConfigHead* ch = calloc(1, sizeof(*ch));
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_output_configuration_head_v1_interface, wl_resource_get_version(resource), id);
    if (!r || !ch || !cfg) {
        free(ch);
        if (r) wl_resource_destroy(r);
        wl_client_post_no_memory(client);
        return;
    }
    ch->config = cfg;
    ch->index = head_index_of(cfg->server, head);
    if (ch->index < 0) cfg->unsupported = 1;
    cfg->configured++;
    wl_resource_set_implementation(r, &config_head_impl, ch, config_head_resource_destroyed);
}

static void config_disable_head(struct wl_client* c, struct wl_resource* r, struct wl_resource* head) {
    (void)c; (void)head;
    struct OutputConfig* cfg = wl_resource_get_user_data(r);
    if (cfg) {
        cfg->unsupported = 1;          /* outputs cannot be switched off here */
        cfg->configured++;
    }
}

static void config_apply(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct OutputConfig* cfg = wl_resource_get_user_data(r);
    if (!cfg) return;
    struct WaylandServer* server = cfg->server;
    if (cfg->unsupported || cfg->configured < server->output_count ||
        (cfg->have_scale && !server->cb.on_output_config)) {
        zwlr_output_configuration_v1_send_failed(r);
        return;
    }
    if (!cfg->have_scale) {
        zwlr_output_configuration_v1_send_succeeded(r);   /* nothing to change */
        return;
    }
    struct WaylandOutputConfig* pending = calloc(1, sizeof(*pending));
    if (!pending) {
        zwlr_output_configuration_v1_send_failed(r);
        return;
    }
    pending->resource = r;
    pending->id = ++server->next_output_config_id;
    wl_list_insert(&server->output_configs, &pending->link);
    server->cb.on_output_config(server->cb_ctx, pending->id, cfg->scale);
}

static void config_test(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct OutputConfig* cfg = wl_resource_get_user_data(r);
    if (!cfg || cfg->unsupported || cfg->configured < cfg->server->output_count ||
        (cfg->have_scale && !cfg->server->cb.on_output_config))
        zwlr_output_configuration_v1_send_failed(r);
    else
        zwlr_output_configuration_v1_send_succeeded(r);
}

static void config_resource_destroyed(struct wl_resource* r) {
    struct OutputConfig* cfg = wl_resource_get_user_data(r);
    if (!cfg) return;
    struct WaylandOutputConfig* p, *tmp;
    wl_list_for_each_safe(p, tmp, &cfg->server->output_configs, link) {
        if (p->resource == r) {
            wl_list_remove(&p->link);
            free(p);
        }
    }
    free(cfg);
}

static const struct zwlr_output_configuration_v1_interface config_impl = {
    .enable_head = config_enable_head,
    .disable_head = config_disable_head,
    .apply = config_apply,
    .test = config_test,
    .destroy = release_request,
};

void wayland_output_management_config_result(struct WaylandServer* server,
                                             uint32_t config_id, int ok) {
    struct WaylandOutputConfig* p, *tmp;
    wl_list_for_each_safe(p, tmp, &server->output_configs, link) {
        if (p->id != config_id) continue;
        if (ok) zwlr_output_configuration_v1_send_succeeded(p->resource);
        else zwlr_output_configuration_v1_send_failed(p->resource);
        wl_list_remove(&p->link);
        free(p);
    }
}

void wayland_server_output_config_result(WaylandServer* server, uint32_t config_id, int ok) {
    if (!server) return;
    WARN_IF_OFF_LOOP_THREAD(server, "output_config_result");
    wayland_output_management_config_result(server, config_id, ok);
}

/* --- manager ---------------------------------------------------------------- */

static void manager_create_configuration(struct wl_client* client, struct wl_resource* resource,
                                         uint32_t id, uint32_t serial) {
    (void)serial;
    struct WaylandOutputManager* m = wl_resource_get_user_data(resource);
    struct OutputConfig* cfg = calloc(1, sizeof(*cfg));
    struct wl_resource* r = wl_resource_create(client,
        &zwlr_output_configuration_v1_interface, wl_resource_get_version(resource), id);
    if (!r || !cfg || !m) {
        free(cfg);
        if (r) wl_resource_destroy(r);
        wl_client_post_no_memory(client);
        return;
    }
    cfg->server = m->server;
    wl_resource_set_implementation(r, &config_impl, cfg, config_resource_destroyed);
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
    wl_list_init(&server->output_configs);
    server->output_manager_global = wl_global_create(server->display,
        &zwlr_output_manager_v1_interface, 4, server, manager_bind);
}

void wayland_output_management_outputs_changed(struct WaylandServer* server) {
    struct WaylandOutputManager* m;
    wl_list_for_each(m, &server->output_managers, link) {
        if (!m->stopped) manager_send_all(m);
    }
}
