// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * wayland_xdg_foreign.c — zxdg_exporter_v2 / zxdg_importer_v2
 *
 * One client exports a toplevel as an opaque handle string; another imports
 * the handle and names it the parent of its own toplevel. This is how a
 * portal's file dialog (a different process) is parented to the browser
 * window that asked for it, and how Flatpak apps' dialogs find their app.
 *
 * The shell does not stack transients yet, so set_parent_of records nothing
 * — the value today is that the export/import handshake succeeds instead of
 * the toolkit taking its "no parent" path, and that a handle whose toplevel
 * went is reported destroyed rather than left dangling.
 */

#include "wayland_server_internal.h"
#include "xdg-foreign-unstable-v2-protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void destroy_request(struct wl_client* c, struct wl_resource* r) {
    (void)c;
    wl_resource_destroy(r);
}

/* --- imported ------------------------------------------------------------- */

static void imported_set_parent_of(struct wl_client* c, struct wl_resource* r,
                                   struct wl_resource* surface) {
    (void)c;
    struct WaylandForeignImport* im = wl_resource_get_user_data(r);
    struct WaylandSurface* child = surface ? wl_resource_get_user_data(surface) : NULL;
    if (!im || !im->export_ || !im->export_->surface || !child) return;
    if (!child->xdg_toplevel) {
        wl_resource_post_error(r, ZXDG_IMPORTED_V2_ERROR_INVALID_SURFACE,
                               "set_parent_of needs an xdg_toplevel surface");
        return;
    }
    /* Recorded nowhere yet: see the file header. */
}

static const struct zxdg_imported_v2_interface imported_impl = {
    .destroy = destroy_request,
    .set_parent_of = imported_set_parent_of,
};

static void imported_resource_destroyed(struct wl_resource* r) {
    struct WaylandForeignImport* im = wl_resource_get_user_data(r);
    if (!im) return;
    if (im->export_) wl_list_remove(&im->link);
    free(im);
}

/* --- exported ------------------------------------------------------------- */

static const struct zxdg_exported_v2_interface exported_impl = {
    .destroy = destroy_request,
};

static void export_invalidate(struct WaylandForeignExport* ex) {
    struct WaylandForeignImport* im, *tmp;
    wl_list_for_each_safe(im, tmp, &ex->imports, link) {
        zxdg_imported_v2_send_destroyed(im->resource);
        wl_list_remove(&im->link);
        wl_list_init(&im->link);
        im->export_ = NULL;
    }
    ex->surface = NULL;
}

static void exported_resource_destroyed(struct wl_resource* r) {
    struct WaylandForeignExport* ex = wl_resource_get_user_data(r);
    if (!ex) return;
    export_invalidate(ex);
    wl_list_remove(&ex->link);
    free(ex);
}

static void exporter_export_toplevel(struct wl_client* client, struct wl_resource* resource,
                                     uint32_t id, struct wl_resource* surface) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandSurface* s = surface ? wl_resource_get_user_data(surface) : NULL;
    if (!s || !s->xdg_toplevel) {
        wl_resource_post_error(resource, ZXDG_EXPORTER_V2_ERROR_INVALID_SURFACE,
                               "export_toplevel needs an xdg_toplevel surface");
        return;
    }
    struct WaylandForeignExport* ex = calloc(1, sizeof(*ex));
    if (!ex) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &zxdg_exported_v2_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(ex);
        wl_client_post_no_memory(client);
        return;
    }
    ex->resource = r;
    ex->surface = s;
    wl_list_init(&ex->imports);
    snprintf(ex->handle, sizeof(ex->handle), "starling-foreign-%u-%u",
             s->id, ++server->next_foreign_export);
    wl_list_insert(&server->foreign_exports, &ex->link);
    wl_resource_set_implementation(r, &exported_impl, ex, exported_resource_destroyed);
    zxdg_exported_v2_send_handle(r, ex->handle);
}

static const struct zxdg_exporter_v2_interface exporter_impl = {
    .destroy = destroy_request,
    .export_toplevel = exporter_export_toplevel,
};

static void importer_import_toplevel(struct wl_client* client, struct wl_resource* resource,
                                     uint32_t id, const char* handle) {
    struct WaylandServer* server = wl_resource_get_user_data(resource);
    struct WaylandForeignImport* im = calloc(1, sizeof(*im));
    if (!im) {
        wl_client_post_no_memory(client);
        return;
    }
    struct wl_resource* r = wl_resource_create(client, &zxdg_imported_v2_interface,
                                               wl_resource_get_version(resource), id);
    if (!r) {
        free(im);
        wl_client_post_no_memory(client);
        return;
    }
    im->resource = r;
    wl_list_init(&im->link);
    struct WaylandForeignExport* ex;
    wl_list_for_each(ex, &server->foreign_exports, link) {
        if (ex->surface && handle && strcmp(ex->handle, handle) == 0) {
            im->export_ = ex;
            wl_list_insert(&ex->imports, &im->link);
            break;
        }
    }
    wl_resource_set_implementation(r, &imported_impl, im, imported_resource_destroyed);
    /* An unknown handle is answered, not ignored: the importer learns at
     * once that there is nothing to parent to. */
    if (!im->export_) zxdg_imported_v2_send_destroyed(r);
}

static const struct zxdg_importer_v2_interface importer_impl = {
    .destroy = destroy_request,
    .import_toplevel = importer_import_toplevel,
};

static void exporter_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client, &zxdg_exporter_v2_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &exporter_impl, data, NULL);
}

static void importer_bind(struct wl_client* client, void* data, uint32_t version, uint32_t id) {
    struct wl_resource* r = wl_resource_create(client, &zxdg_importer_v2_interface, version, id);
    if (!r) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(r, &importer_impl, data, NULL);
}

void wayland_xdg_foreign_init(struct WaylandServer* server) {
    wl_list_init(&server->foreign_exports);
    server->xdg_exporter_global = wl_global_create(server->display,
        &zxdg_exporter_v2_interface, 1, server, exporter_bind);
    server->xdg_importer_global = wl_global_create(server->display,
        &zxdg_importer_v2_interface, 1, server, importer_bind);
}

void wayland_xdg_foreign_surface_destroyed(struct WaylandServer* server,
                                           struct WaylandSurface* surface) {
    struct WaylandForeignExport* ex;
    wl_list_for_each(ex, &server->foreign_exports, link) {
        if (ex->surface == surface) export_invalidate(ex);
    }
}
