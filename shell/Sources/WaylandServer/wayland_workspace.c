// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_workspace.c — ext_workspace_manager_v1
 *
 * The shell's spaces (its virtual desktops), for panels and switchers: one
 * group spanning every output, one workspace per user space, with its
 * name, position and whether it is the active one. A panel activates a
 * workspace, removes one, or asks for a new one; the requests wait for
 * commit and reach the shell as on_workspace_request, and the shell's own
 * bookkeeping comes back through wayland_server_set_workspaces, which
 * diffs it against the last push and tells every manager what changed.
 */

#include "wayland_server_internal.h"
#include "ext-workspace-v1-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static struct WaylandWorkspace* workspace_by_id(struct WaylandServer* server, uint32_t id) {
    struct WaylandWorkspace* ws;
    wl_list_for_each(ws, &server->workspaces, link) {
        if (ws->id == id) return ws;
    }
    return NULL;
}

/* --- handles ------------------------------------------------------------- */

static void handle_send_all(struct WaylandWorkspaceHandle* h, struct WaylandWorkspace* ws,
                            int initial) {
    struct wl_resource* r = h->resource;
    if (initial) {
        char id[32];
        snprintf(id, sizeof(id), "%u", ws->id);
        ext_workspace_handle_v1_send_id(r, id);
        ext_workspace_handle_v1_send_capabilities(r,
            EXT_WORKSPACE_HANDLE_V1_WORKSPACE_CAPABILITIES_ACTIVATE |
            EXT_WORKSPACE_HANDLE_V1_WORKSPACE_CAPABILITIES_REMOVE);
    }
    ext_workspace_handle_v1_send_name(r, ws->name);
    struct wl_array coords;
    wl_array_init(&coords);
    uint32_t* c = wl_array_add(&coords, sizeof(*c));
    *c = (uint32_t)ws->index;
    ext_workspace_handle_v1_send_coordinates(r, &coords);
    wl_array_release(&coords);
    ext_workspace_handle_v1_send_state(r,
        ws->active ? EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE : 0);
}

static void handle_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static void handle_activate(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandWorkspaceHandle* h = wl_resource_get_user_data(r);
    if (!h || h->removed || !h->manager) return;
    h->manager->pending_activate = h->workspace_id;
}

static void handle_deactivate(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandWorkspaceHandle* h = wl_resource_get_user_data(r);
    if (!h || h->removed || !h->manager) return;
    h->manager->pending_deactivate = h->workspace_id;
}

static void handle_assign(struct wl_client* c, struct wl_resource* r,
                          struct wl_resource* group) {
    (void)c; (void)r; (void)group;
    /* One group: every workspace is already in it. */
}

static void handle_remove(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandWorkspaceHandle* h = wl_resource_get_user_data(r);
    if (!h || h->removed || !h->manager) return;
    h->manager->pending_remove = h->workspace_id;
}

static const struct ext_workspace_handle_v1_interface handle_impl = {
    .destroy = handle_destroy,
    .activate = handle_activate,
    .deactivate = handle_deactivate,
    .assign = handle_assign,
    .remove = handle_remove,
};

static void handle_resource_destroyed(struct wl_resource* r) {
    struct WaylandWorkspaceHandle* h = wl_resource_get_user_data(r);
    if (!h) return;
    if (h->manager) wl_list_remove(&h->link);
    free(h);
}

static void manager_add_handle(struct WaylandWorkspaceManager* m, struct WaylandWorkspace* ws) {
    struct WaylandWorkspaceHandle* h = calloc(1, sizeof(*h));
    if (!h) return;
    struct wl_client* client = wl_resource_get_client(m->resource);
    struct wl_resource* r = wl_resource_create(client, &ext_workspace_handle_v1_interface,
                                               wl_resource_get_version(m->resource), 0);
    if (!r) {
        free(h);
        return;
    }
    h->resource = r;
    h->manager = m;
    h->workspace_id = ws->id;
    wl_list_insert(&m->handles, &h->link);
    wl_resource_set_implementation(r, &handle_impl, h, handle_resource_destroyed);
    ext_workspace_manager_v1_send_workspace(m->resource, r);
    handle_send_all(h, ws, 1);
    if (m->group) ext_workspace_group_handle_v1_send_workspace_enter(m->group, r);
}

/* --- group ---------------------------------------------------------------- */

static void group_create_workspace(struct wl_client* c, struct wl_resource* r,
                                   const char* name) {
    (void)c;
    struct WaylandWorkspaceManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    snprintf(m->pending_create, sizeof(m->pending_create), "%s", name ? name : "");
    m->pending_create_set = 1;
}

static void group_destroy(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

static const struct ext_workspace_group_handle_v1_interface group_impl = {
    .create_workspace = group_create_workspace,
    .destroy = group_destroy,
};

static void group_resource_destroyed(struct wl_resource* r) {
    struct WaylandWorkspaceManager* m = wl_resource_get_user_data(r);
    if (m && m->group == r) m->group = NULL;
}

static void manager_send_group(struct WaylandWorkspaceManager* m) {
    struct wl_client* client = wl_resource_get_client(m->resource);
    struct wl_resource* g = wl_resource_create(client, &ext_workspace_group_handle_v1_interface,
                                               wl_resource_get_version(m->resource), 0);
    if (!g) return;
    m->group = g;
    wl_resource_set_implementation(g, &group_impl, m, group_resource_destroyed);
    ext_workspace_manager_v1_send_workspace_group(m->resource, g);
    ext_workspace_group_handle_v1_send_capabilities(g,
        EXT_WORKSPACE_GROUP_HANDLE_V1_GROUP_CAPABILITIES_CREATE_WORKSPACE);
    /* Every output the client has bound: the desktop is one group. */
    for (int i = 0; i < m->server->output_count; i++) {
        struct wl_resource* out;
        wl_resource_for_each(out, &m->server->outputs[i].resources) {
            if (wl_resource_get_client(out) == client)
                ext_workspace_group_handle_v1_send_output_enter(g, out);
        }
    }
}

/* --- manager -------------------------------------------------------------- */

static void manager_commit(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandWorkspaceManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    struct WaylandServer* server = m->server;
    if (server->cb.on_workspace_request) {
        if (m->pending_create_set)
            server->cb.on_workspace_request(server->cb_ctx, 0,
                WAYLAND_WORKSPACE_REQUEST_CREATE, m->pending_create);
        if (m->pending_remove)
            server->cb.on_workspace_request(server->cb_ctx, m->pending_remove,
                WAYLAND_WORKSPACE_REQUEST_REMOVE, "");
        if (m->pending_deactivate)
            server->cb.on_workspace_request(server->cb_ctx, m->pending_deactivate,
                WAYLAND_WORKSPACE_REQUEST_DEACTIVATE, "");
        if (m->pending_activate)
            server->cb.on_workspace_request(server->cb_ctx, m->pending_activate,
                WAYLAND_WORKSPACE_REQUEST_ACTIVATE, "");
    }
    m->pending_create_set = 0;
    m->pending_remove = 0;
    m->pending_deactivate = 0;
    m->pending_activate = 0;
}

static void manager_stop(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    struct WaylandWorkspaceManager* m = wl_resource_get_user_data(r);
    if (m) m->stopped = 1;
    ext_workspace_manager_v1_send_finished(r);
    wl_resource_destroy(r);
}

static const struct ext_workspace_manager_v1_interface manager_impl = {
    .commit = manager_commit,
    .stop = manager_stop,
};

static void manager_resource_destroyed(struct wl_resource* r) {
    struct WaylandWorkspaceManager* m = wl_resource_get_user_data(r);
    if (!m) return;
    struct WaylandWorkspaceHandle* h, *tmp;
    wl_list_for_each_safe(h, tmp, &m->handles, link) {
        wl_list_remove(&h->link);
        wl_list_init(&h->link);
        h->manager = NULL;
    }
    if (m->group) wl_resource_set_user_data(m->group, NULL);
    wl_list_remove(&m->link);
    free(m);
}

static void manager_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct WaylandServer* server = data;
    struct WaylandWorkspaceManager* m = calloc(1, sizeof(*m));
    if (!m) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &ext_workspace_manager_v1_interface,
                                               version, id);
    if (!r) {
        free(m);
        wl_client_post_no_memory(client);
        return;
    }
    m->resource = r;
    m->server = server;
    wl_list_init(&m->handles);
    wl_list_insert(&server->workspace_managers, &m->link);
    wl_resource_set_implementation(r, &manager_impl, m, manager_resource_destroyed);
    manager_send_group(m);
    struct WaylandWorkspace* ws;
    wl_list_for_each_reverse(ws, &server->workspaces, link) manager_add_handle(m, ws);
    ext_workspace_manager_v1_send_done(r);
}

void wayland_workspace_init(struct WaylandServer* server) {
    wl_list_init(&server->workspaces);
    wl_list_init(&server->workspace_managers);
    server->workspace_manager_global = wl_global_create(server->display,
        &ext_workspace_manager_v1_interface, 1, server, manager_bind);
}

/* --- the shell's push --------------------------------------------------------- */

void wayland_server_set_workspaces(WaylandServer* server,
                                   const WaylandWorkspaceDesc* list, int count) {
    if (!server) return;
    WARN_IF_OFF_LOOP_THREAD(server, "set_workspaces");

    /* Removed: anything no longer in the list. */
    struct WaylandWorkspace* ws, *tmp;
    wl_list_for_each_safe(ws, tmp, &server->workspaces, link) {
        int still = 0;
        for (int i = 0; i < count; i++) if (list[i].id == ws->id) still = 1;
        if (still) continue;
        struct WaylandWorkspaceManager* m;
        wl_list_for_each(m, &server->workspace_managers, link) {
            struct WaylandWorkspaceHandle* h;
            wl_list_for_each(h, &m->handles, link) {
                if (h->workspace_id == ws->id && !h->removed) {
                    if (m->group)
                        ext_workspace_group_handle_v1_send_workspace_leave(m->group, h->resource);
                    ext_workspace_handle_v1_send_removed(h->resource);
                    h->removed = 1;
                }
            }
        }
        wl_list_remove(&ws->link);
        free(ws);
    }

    /* Added or changed. */
    for (int i = 0; i < count; i++) {
        struct WaylandWorkspace* w = workspace_by_id(server, list[i].id);
        int fresh = w == NULL;
        if (fresh) {
            w = calloc(1, sizeof(*w));
            if (!w) continue;
            w->id = list[i].id;
            wl_list_insert(&server->workspaces, &w->link);
        }
        int changed = fresh || strcmp(w->name, list[i].name) != 0 ||
                      w->active != list[i].active || w->index != i;
        snprintf(w->name, sizeof(w->name), "%s", list[i].name);
        w->active = list[i].active;
        w->index = i;
        if (!changed) continue;
        struct WaylandWorkspaceManager* m;
        wl_list_for_each(m, &server->workspace_managers, link) {
            if (m->stopped) continue;
            if (fresh) {
                manager_add_handle(m, w);
            } else {
                struct WaylandWorkspaceHandle* h;
                wl_list_for_each(h, &m->handles, link) {
                    if (h->workspace_id == w->id && !h->removed) handle_send_all(h, w, 0);
                }
            }
        }
    }

    struct WaylandWorkspaceManager* m;
    wl_list_for_each(m, &server->workspace_managers, link) {
        if (!m->stopped) ext_workspace_manager_v1_send_done(m->resource);
    }
}

void wayland_workspace_fini(struct WaylandServer* server) {
    struct WaylandWorkspace* ws;
    struct WaylandWorkspace* tmp;
    wl_list_for_each_safe(ws, tmp, &server->workspaces, link) {
        wl_list_remove(&ws->link);
        free(ws);
    }
}
