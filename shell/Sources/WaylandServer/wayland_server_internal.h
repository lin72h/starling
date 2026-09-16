// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef WAYLAND_SERVER_INTERNAL_H
#define WAYLAND_SERVER_INTERNAL_H

#include <pthread.h>
#include <stdio.h>
#include <wayland-server.h>
#include "include/wayland_server.h"

/* Buffer type tag — first member of both DmaBufBuffer and ShmBuffer,
 * so surface_commit can distinguish them via a common pointer cast. */
enum WaylandBufferType {
    BUFFER_TYPE_DMABUF = 1,
    BUFFER_TYPE_SHM    = 2,
};

/* Positioner data — stores values set by the client for popup placement. */
struct WaylandPositioner {
    int32_t width, height;                // popup size
    int32_t anchor_x, anchor_y;          // anchor rect position
    int32_t anchor_w, anchor_h;          // anchor rect size
    uint32_t anchor;                      // anchor edge enum
    uint32_t gravity;                     // gravity enum
    int32_t offset_x, offset_y;          // additional offset
};

struct WaylandGeometry {
    int32_t x, y, width, height;
    int set;
};

struct WaylandSurface {
    struct wl_resource* resource;         // wl_surface
    struct wl_resource* xdg_surface;      // xdg_surface (if role assigned)
    struct wl_resource* xdg_toplevel;     // xdg_toplevel (if role assigned)
    struct wl_resource* xdg_popup;        // xdg_popup (if popup role)
    struct wl_resource* decoration;       // zxdg_toplevel_decoration_v1
    uint32_t id;                          // our surface_id for callbacks
    struct wl_list link;                  // in WaylandServer.surfaces
    struct WaylandServer* server;

    // Popup state
    uint32_t parent_surface_id;           // parent surface id (for popups)
    int32_t popup_x, popup_y;            // position relative to parent
    int32_t popup_w, popup_h;            // size from the positioner

    // Subsurface state (wl_subsurface). is_subsurface is set when this surface
    // is turned into a subsurface; subsurface_parent points at the parent
    // WaylandSurface. Used to route a subsurface's committed buffer to its
    // toplevel ancestor's window texture (e.g. Waydroid renders the Android
    // screen to a full-size dma-buf subsurface over a 1x1 dummy toplevel).
    int is_subsurface;
    struct WaylandSurface* subsurface_parent;
    int32_t subsurface_x, subsurface_y;   // position relative to parent
    // The wl_subsurface role object, tracked for exactly one reason: it
    // stores a raw pointer to this surface, and a client may legally destroy
    // the wl_surface while keeping the wl_subsurface alive. Recording it lets
    // surface_destroy_resource() null its user_data instead of leaving it
    // dangling (set_position then wrote through the freed surface).
    struct wl_resource* subsurface_resource;
    /* A subsurface the shell draws inside its toplevel's window: where it
     * was last placed (offset from the toplevel's surface origin, surface
     * coordinates) and whether the shell currently has it. */
    int32_t sub_placed_x, sub_placed_y;
    int sub_placed;

    /* xdg_popup.grab: a press outside the popup's tree dismisses it. */
    int popup_grabbed;

    /* xdg_toplevel.set_parent: the toplevel this one is a dialog for (its
     * surface id), 0 for none. Applied at once, as the request is. */
    uint32_t toplevel_parent_id;

    /* xdg_toplevel.set_min_size / set_max_size, double-buffered: the
     * pending pair lands on commit, and the shell hears the four together. */
    int32_t pending_min_w, pending_min_h, pending_max_w, pending_max_h;
    int size_hints_pending;
    int32_t min_w, min_h, max_w, max_h;

    // Double-buffered pending state (applied atomically on commit)
    struct {
        struct wl_resource* buffer;
        int buffer_set;
        int32_t damage_x, damage_y, damage_w, damage_h;
        int damage_set;
        struct wl_resource* frame_callback;
        int32_t buffer_scale;           // pending wl_surface.set_buffer_scale
        int buffer_scale_set;
    } pending;
    // Clears pending.buffer if the client destroys the attached wl_buffer
    // before committing it (attach → destroy → commit must not UAF).
    struct wl_listener pending_buffer_destroy_listener;

    // Current committed buffer scale (default 1)
    int32_t buffer_scale;

    // Current committed state
    struct wl_resource* committed_buffer;
    struct wl_listener committed_buffer_destroy_listener;
    /* The committed buffer was already handed back (wl_buffer.release):
     * an shm buffer is released the moment its pixels are copied out, so
     * the pointer is kept for bookkeeping but must not be released twice. */
    int committed_buffer_released;
    struct wl_resource* frame_callback;   // active frame callback waiting for done
    /* Frame-callback throttle (Murmuration): 0 = full rate. While set, the
     * armed callback is held across flips until interval_ms has elapsed
     * since the last done — the client idles between frames. */
    uint32_t frame_throttle_ms;
    uint32_t last_frame_done_ms;
    int first_commit_done;
    int had_role;   // sticky: set once this surface ever had an xdg toplevel/popup
                    // role, stays set after the role is destroyed so we keep
                    // releasing its buffers on unmap.

    /* Dimensions of the last buffer this surface committed for ITSELF (not one
     * routed up from a subsurface). Used to decide whether a subsurface's
     * buffer is the window's actual content — see the routing rule in
     * surface_commit(). Zero until the surface commits its own buffer. */
    int32_t own_buf_w, own_buf_h;

    // Toplevel metadata
    char title[256];
    char app_id[256];

    // Window geometry (from xdg_surface.set_window_geometry, in surface-local coords)
    // Double-buffered: pending is set by client, committed is applied on wl_surface.commit.
    struct WaylandGeometry pending_geometry;
    struct WaylandGeometry geometry;

    // Viewport destination (from wp_viewport.set_destination, surface-local coords)
    // When set, overrides buffer_size/buffer_scale for surface sizing.
    int32_t viewport_dst_width;    // 0 = not set (use buffer dimensions)
    int32_t viewport_dst_height;

    // Fractional scale (wp_fractional_scale_v1)
    struct wl_resource* fractional_scale_resource;

    // Configure tracking
    uint32_t pending_configure_serial;
    int initial_configure_sent;

    // Frame-done throttle timer (fires within wl_event_loop_dispatch)
    struct wl_event_source* frame_done_timer;

    // Outputs this mapped toplevel currently intersects (bit i = server
    // outputs[i]); wl_surface.enter/leave are sent on changes. 0 = unmapped.
    uint32_t outputs_mask;

    /* Window state the SHELL owns (WAYLAND_TOPLEVEL_* bits, pushed through
     * wayland_server_set_toplevel_state). It is what every configure
     * carries, what foreign-toplevel handles report, and what a client's
     * own set_maximized/set_minimized requests are answered against. Fresh
     * toplevels start ACTIVATED|MAXIMIZED, the shell's default placement,
     * so the first configure needs no push. */
    uint32_t toplevel_states;
    /* The size of the last toplevel configure, so a state-only change
     * (maximize with no size change, focus) can re-send it. 0 = none yet. */
    int32_t last_conf_w, last_conf_h;
    /* Non-zero once the toplevel has committed its first buffer — the point
     * at which the foreign-toplevel lists announce it. */
    int mapped;

    /* zwlr_layer_surface_v1 role, NULL for everything else. */
    struct WaylandLayerSurface* layer;

    /* wp_alpha_modifier_surface_v1: the whole-surface opacity multiplier,
     * double-buffered like everything else on the surface. 1.0 = opaque. */
    double alpha, pending_alpha;
    int pending_alpha_set;
    struct wl_resource* alpha_resource;

    /* xx_zone_item_v1 wrapping this toplevel, NULL when none. */
    struct WaylandZoneItem* zone_item;

    /* Every zwlr_foreign_toplevel_handle_v1 / ext_foreign_toplevel_handle_v1
     * minted for this toplevel (WaylandForeignHandle.surface_link), and the
     * identifier ext_foreign_toplevel_list hands out for it. */
    struct wl_list foreign_handles;
    char foreign_identifier[40];

    /* A popup made with a NULL parent (xdg_surface.get_popup) whose parent
     * will arrive through zwlr_layer_surface_v1.get_popup: the shell is told
     * about it only once the parent is known, or at its first commit. */
    int popup_parent_pending;

    /* ext_background_effect: the region behind which the shell blurs,
     * double-buffered; count 0 = none. Rects are x,y,w,h, surface-local. */
    #define WAYLAND_MAX_REGION_RECTS 32
    int32_t blur_rects[WAYLAND_MAX_REGION_RECTS][4];
    int blur_count;
    int32_t pending_blur_rects[WAYLAND_MAX_REGION_RECTS][4];
    int pending_blur_count;
    int pending_blur_set;
    struct wl_resource* background_effect_resource;

    /* The icon of a drag-and-drop in progress (wl_data_device.start_drag):
     * a role of its own, drawn by the shell at the pointer. */
    int is_drag_icon;

    // The single output this surface's frame callbacks pace off (a straddler
    // intersects two panels with different refresh rates, and firing on both
    // over-paces the client). One bit; 0 = default to the primary, which is
    // always bit 0 (the shell advertises the primary first).
    uint32_t pace_mask;
};

struct DmaBufBuffer {
    enum WaylandBufferType type;          // = BUFFER_TYPE_DMABUF
    struct wl_resource* resource;         // wl_buffer
    int fd;                               // DMA-BUF file descriptor
    int32_t width, height;
    int32_t stride;
    uint32_t fourcc;
    uint64_t modifier;
};

struct ShmPool {
    int fd;                               // shm file descriptor
    void* data;                           // mmap'd pointer
    size_t size;                          // current pool size
    int refcount;                         // live buffer count + 1 (for the pool resource itself)
};

struct ShmBuffer {
    enum WaylandBufferType type;          // = BUFFER_TYPE_SHM
    struct wl_resource* resource;         // wl_buffer
    struct ShmPool* pool;
    int32_t offset;
    int32_t width, height;
    int32_t stride;
    uint32_t format;                      // wl_shm_format
};

/* wl_region: the rectangles added to it. Subtraction is rare enough in
 * practice (no client this desktop runs uses it) to be ignored. */
struct WaylandRegion {
    int32_t rects[WAYLAND_MAX_REGION_RECTS][4];
    int count;
};

/* A drag-and-drop in progress. */
struct WaylandDrag {
    int active;
    struct WaylandDataSource* source;    // NULL for a drag with no data
    struct wl_resource* source_resource;
    struct wl_client* client;            // the dragging client
    struct WaylandSurface* origin;
    struct WaylandSurface* icon;         // NULL when none
    struct WaylandSurface* focus;        // the surface under the pointer, or NULL
    struct wl_resource* focus_offer;     // the wl_data_offer minted for it
    uint32_t source_actions;             // wl_data_device_manager_dnd_action mask
    uint32_t offer_actions, offer_preferred;   // what the target asked for
    uint32_t chosen_action;
    int accepted;                        // the target accepted a mime
    double last_x, last_y;               // surface-local, on `focus`
    /* xdg_toplevel_drag_v1: the toplevel riding along, and its offset. */
    struct WaylandSurface* attached;
    int32_t attach_x, attach_y;
    struct wl_resource* toplevel_drag;
};

struct WaylandServer {
    struct wl_display* display;
    struct wl_event_loop* event_loop;

    // Globals
    struct wl_global* compositor_global;
    struct wl_global* dmabuf_global;
    struct wl_global* xdg_wm_base_global;
    struct wl_global* seat_global;
    struct wl_global* seat_agent_global;   // Murmuration: the agent seat
    struct WaylandSeatDesc { struct WaylandServer* server; int index; const char* name; } seat_descs[2];
    // Outputs (virtual desktop): outputs[0] defaults to the create-time
    // config; wayland_server_set_outputs installs the real arrangement.
    // Each bound wl_output resource's user_data is its struct WaylandOutput.
    #define WAYLAND_MAX_OUTPUTS 8
    struct WaylandOutput {
        struct WaylandServer* server;
        int index;
        int32_t logical_x, logical_y;    // global logical position
        int32_t physical_w, physical_h;  // current mode
        int32_t scale;                   // integer scale (>= 1)
        int32_t refresh_mhz;
        char name[32];
        struct wl_global* global;        // NULL = slot unused
        struct wl_list resources;        // bound wl_output resources
    } outputs[WAYLAND_MAX_OUTPUTS];
    int output_count;
    struct wl_global* shm_global;
    struct wl_global* decoration_manager_global;
    struct wl_global* subcompositor_global;
    struct wl_global* data_device_manager_global;
    struct wl_global* fractional_scale_global;
    struct wl_global* viewporter_global;
    struct wl_global* cursor_shape_manager_global;
    struct wl_global* pointer_constraints_global;
    struct wl_global* relative_pointer_manager_global;

    // Relative pointer resources (WaylandRelativePointerResource.link)
    struct wl_list relative_pointers;

    struct wl_global* primary_selection_manager_global;
    struct wl_global* text_input_manager_global;
    // Bound zwp_text_input_v3 resources (TextInputV3.link) + the surface
    // holding keyboard focus for text-input enter/leave routing.
    struct wl_list text_inputs;
    struct WaylandSurface* ti_focus;
    struct wl_global* idle_inhibit_manager_global;
    // Live zwp_idle_inhibitor_v1 resources. Nonzero = some client is
    // playing video (or otherwise asked to stay awake); the shell's idle
    // timer reads it through wayland_server_idle_inhibited().
    int idle_inhibitors;
    struct wl_global* xdg_output_manager_global;
    struct wl_global* xdg_activation_global;
    struct wl_global* presentation_global;

    /* --- The protocols wmbench and the wlroots ecosystem probe for ------- */
    struct wl_global* layer_shell_global;
    struct wl_list layer_surfaces;           // WaylandLayerSurface.link
    struct wl_global* alpha_modifier_global;
    struct wl_global* foreign_toplevel_manager_global;   // zwlr
    struct wl_global* ext_foreign_toplevel_list_global;  // ext
    struct wl_list foreign_managers;         // WaylandForeignManager.link
    struct wl_global* screencopy_manager_global;
    struct wl_list screencopy_frames;        // WaylandScreencopyFrame.link
    uint32_t next_screencopy_id;
    struct wl_global* zone_manager_global;
    struct wl_list zones;                    // WaylandZone.link
    struct wl_list zone_items;               // WaylandZoneItem.link
    uint32_t next_zone_handle;
    /* The frame the shell draws around a toplevel (its title bar), in
     * logical pixels; what xx_zone_item_v1.frame_extents reports. */
    int32_t frame_top, frame_bottom, frame_left, frame_right;
    /* Per-output work area (the output less any reserved strips), in global
     * logical coordinates. Zones are cut from it. Zero size = the whole
     * output. Pushed by the shell through wayland_server_set_work_area. */
    struct { int32_t x, y, w, h; } work_area[8 /* WAYLAND_MAX_OUTPUTS */];
    /* Activation tokens this compositor issued and has not yet seen used:
     * xdg_activation_v1.activate is honoured for these only. */
    char issued_tokens[32][48];
    int issued_token_next;
    /* --- Small ones ------------------------------------------------------ */
    struct wl_global* single_pixel_buffer_global;
    struct wl_global* content_type_global;
    struct wl_global* tearing_control_global;
    struct wl_global* toplevel_tag_global;
    struct wl_global* xdg_dialog_global;
    struct wl_global* system_bell_global;
    struct wl_global* toplevel_icon_global;
    struct wl_global* shortcuts_inhibit_global;
    struct wl_list shortcuts_inhibitors;     // WaylandShortcutsInhibitor.link
    struct wl_global* pointer_gestures_global;
    struct wl_global* tablet_manager_global;
    struct wl_global* ext_data_control_manager_global;
    struct wl_list ext_data_control_devices; // same discipline as data_control_devices
    struct wl_global* idle_notifier_global;
    struct wl_list idle_notifications;       // WaylandIdleNotification.link
    /* ext-image-copy-capture: sources name an output, sessions capture it. */
    struct wl_global* image_capture_source_manager_global;
    struct wl_global* image_copy_capture_manager_global;
    struct wl_list image_copy_sessions;      // WaylandImageCopySession.link
    struct wl_global* xdg_exporter_global;
    struct wl_global* xdg_importer_global;
    struct wl_list foreign_exports;          // WaylandForeignExport.link
    uint32_t next_foreign_export;
    struct wl_global* color_representation_global;
    struct wl_global* security_context_global;
    struct wl_list security_contexts;        // WaylandSecurityContext.link
    struct wl_list sandboxed_clients;        // WaylandSandboxedClient.link
    struct wl_global* output_manager_global;
    struct wl_list output_managers;          // WaylandOutputManager.link
    uint32_t output_config_serial;
    /* ext-workspace: the shell's spaces, as pushed, and every manager. */
    struct wl_global* workspace_manager_global;
    struct wl_list workspaces;               // WaylandWorkspace.link
    /* xdg_popup grabs in force (popups with popup_grabbed set). */
    int popup_grab_count;
    struct wl_list workspace_managers;       // WaylandWorkspaceManager.link
    struct wl_global* background_effect_global;
    struct wl_global* transient_seat_manager_global;
    struct wl_list transient_seats;          // WaylandTransientSeat.link
    struct wl_global* virtual_pointer_manager_global;
    struct wl_global* virtual_keyboard_manager_global;
    struct wl_global* pointer_warp_global;
    struct wl_global* toplevel_drag_manager_global;
    struct WaylandDrag drag;
    /* wlr-output-management apply: the configuration awaiting the shell. */
    uint32_t next_output_config_id;
    struct wl_list output_configs;           // WaylandOutputConfig.link
    struct wl_global* session_lock_manager_global;
    /* The ext_session_lock_v1 holding the session, NULL when unlocked. A
     * locker that dies leaves the session locked (the protocol's rule);
     * the next lock request takes over. */
    struct wl_resource* session_lock;
    int session_locked;
    /* CLOCK_MONOTONIC ms of the last input event the compositor delivered,
     * which is what ext-idle-notify measures idleness from. */
    uint32_t last_input_ms;

    // Presentation feedback objects (WaylandPresentationFeedback.link)
    struct wl_list presentation_feedbacks;
    uint32_t presentation_seq;

    // Clipboard — unified selection shared across BOTH the focus-based
    // wl_data_device protocol and the focus-free zwlr_data_control protocol,
    // so a copy in any client is pasteable in any other regardless of which
    // protocol set it (Chrome uses wl_data_device; wl-clipboard / the
    // Waydroid clipboard bridge use data-control). `owner` is the current
    // source object (a WaylandDataSource* or WaylandDataControlSource*);
    // `send`/`cancel` dispatch to whichever protocol owns it; `serial` is
    // bumped on every change so an offer minted for an old selection is
    // rejected (EOF) instead of using a stale/freed source.
    struct WaylandClipboard {
        void* owner;                 // NULL = empty selection
        uint64_t serial;             // bumped each set; offers carry it
        char** mimes;                // -> owner's mime array (valid while owner alive)
        int mime_count;
        void (*send)(void* owner, const char* mime, int32_t fd);
        void (*cancel)(void* owner); // notify a displaced owner it lost the selection
    } clipboard;
    struct wl_global* data_control_manager_global;
    // All bound wl_data_device resources (WaylandDataDevice.link, defined in
    // wayland_data_device.c), one per get_data_device call. Entries unlink
    // themselves in their resource destructor — never store a bare
    // wl_data_device pointer here.
    struct wl_list data_device_resources;
    /* The primary selection (zwp_primary_selection_v1, middle-click paste):
     * its own owner, serial and devices, the same shape as `clipboard`. */
    struct WaylandClipboard primary;
    struct wl_list primary_device_resources;  // PrimaryDevice.link
    // All bound zwlr_data_control_device_v1 resources (same discipline).
    struct wl_list data_control_devices;

    // Surface list
    struct wl_list surfaces;              // WaylandSurface.link
    uint32_t next_surface_id;

    // Input resources — one per wl_client that called get_pointer/get_keyboard.
    // Chrome opens many connections; we must send events to the right client.
    struct wl_list pointer_resources;  // WaylandInputResource.link
    struct wl_list keyboard_resources; // WaylandInputResource.link

    // Deferred pointer event queue (sent from Flutter thread, drained in dispatch).
    // `lock` guards queue/count/capacity: the enqueue side runs on the Flutter
    // UI thread while the drain runs on the Wayland event-loop thread — the
    // pipe is only a wakeup, not a fence.
    struct {
        pthread_mutex_t lock;
        int pipe_fd[2];                   // pipe for wakeup
        struct wl_event_source* source;   // event loop source for pipe read end
        struct WaylandPointerEvent* queue;
        int count;
        int capacity;
    } deferred_input;

    // Configuration (display parameters only)
    WaylandServerConfig config;
    uint32_t fractional_scale_120ths;  // 0 = derive from config.scale

    // Event-loop thread identity, recorded on the first dispatch. Public
    // entry points that send protocol events directly (configure, flush, …)
    // are only safe on this thread; WARN_IF_OFF_LOOP_THREAD flags misuse.
    pthread_t loop_thread;
    int loop_thread_set;

    // Set once the first real page-flip notification arrives
    // (wayland_server_on_present). While set, the per-surface frame-done
    // timer is only a stall fallback (100ms) — flips drive frame pacing.
    int saw_flip;

    // Callbacks (registered individually via wayland_server_on_* functions)
    // All share a single context pointer for simplicity.
    void* cb_ctx;
    struct {
        void (*on_new_toplevel)(void* ctx, uint32_t surface_id, uint64_t client_id);
        void (*on_title_changed)(void* ctx, uint32_t surface_id, const char* title);
        void (*on_app_id_changed)(void* ctx, uint32_t surface_id, const char* app_id);
        void (*on_toplevel_destroy)(void* ctx, uint32_t surface_id);
        /* A client connection went away. client_id is the same opaque value
         * on_new_toplevel reported — and the ONLY point at which it stops
         * being meaningful, because it is the wl_client pointer: once freed,
         * the allocator can hand the same address to the next client that
         * connects. Anything the shell keyed on it must be dropped here. */
        void (*on_client_destroy)(void* ctx, uint64_t client_id);
        void (*on_surface_commit)(void* ctx, uint32_t surface_id,
                                   int fd, int w, int h, int stride,
                                   uint32_t fourcc, uint64_t modifier,
                                   int first_commit, int buffer_scale);
        void (*on_shm_surface_commit)(void* ctx, uint32_t surface_id,
                                       const void* pixel_data,
                                       int w, int h, int stride,
                                       uint32_t format, int first_commit,
                                       int buffer_scale, int keep_alpha);
        /* xdg_toplevel min/max size hints, in surface coordinates, 0 =
         * unset. Applied on commit; the shell clamps its resizes to them. */
        /* xdg_popup.reposition answered: the popup's new place and size
         * relative to its parent, to take effect with its next frame. */
        void (*on_popup_repositioned)(void* ctx, uint32_t surface_id,
                                      int x, int y, int w, int h);
        /* xdg_toplevel.set_parent: `parent_id` is the parent toplevel's
         * surface id, 0 when cleared. A dialog is placed over its parent,
         * stays above it and does not open maximized. */
        void (*on_toplevel_parent)(void* ctx, uint32_t surface_id, uint32_t parent_id);
        void (*on_toplevel_size_hints)(void* ctx, uint32_t surface_id,
                                       int32_t min_w, int32_t min_h,
                                       int32_t max_w, int32_t max_h);
        /* A subsurface of a toplevel window has content of its own to draw
         * inside that window, at (x, y) from the toplevel's surface origin
         * (surface coordinates). Fired before the subsurface's first buffer
         * arrives through on_surface_commit / on_shm_surface_commit under
         * its own id, and again whenever the offset moves. */
        void (*on_subsurface_placed)(void* ctx, uint32_t surface_id,
                                     uint32_t toplevel_id, int32_t x, int32_t y);
        /* The subsurface has nothing to draw any more (null buffer, role or
         * surface gone, or its content became the window's own). */
        void (*on_subsurface_unmapped)(void* ctx, uint32_t surface_id);
        // Client-initiated interactive move/resize (xdg_toplevel.move /
        // xdg_toplevel.resize during a pointer grab — e.g. dragging Chrome's
        // tab strip or a CSD titlebar). The shell takes over the drag.
        void (*on_move_request)(void* ctx, uint32_t surface_id);
        void (*on_interactive_resize_request)(void* ctx, uint32_t surface_id,
                                              uint32_t edges);
        void (*on_new_popup)(void* ctx, uint32_t surface_id,
                              uint32_t parent_surface_id,
                              int x, int y, int w, int h);
        void (*on_popup_destroy)(void* ctx, uint32_t surface_id);
        void (*on_window_geometry)(void* ctx, uint32_t surface_id,
                                    int x, int y, int w, int h);
        void (*on_cursor_shape)(void* ctx, uint32_t shape);
        void (*on_fullscreen_request)(void* ctx, uint32_t surface_id);
        void (*on_unfullscreen_request)(void* ctx, uint32_t surface_id);
        // Text-input-v3 state on the focused surface: fires when a client
        // enables/disables IME input or updates its cursor rectangle
        // (surface-local logical coords).
        void (*on_text_input_state)(void* ctx, uint32_t surface_id,
                                    int enabled, int32_t x, int32_t y,
                                    int32_t w, int32_t h);
        /* A client asked for a window-state change the shell owns: its own
         * xdg_toplevel.set_maximized/set_minimized, a taskbar's
         * foreign-toplevel request, an xdg_activation.activate. */
        void (*on_toplevel_request)(void* ctx, uint32_t surface_id,
                                    int request);
        /* Layer shell: a surface took the role and committed for the first
         * time (the shell creates its texture here), its arrangement
         * changed, or it went away. */
        void (*on_new_layer_surface)(void* ctx, uint32_t surface_id,
                                     const WaylandLayerSurfaceInfo* info);
        void (*on_layer_surface_changed)(void* ctx, uint32_t surface_id,
                                         const WaylandLayerSurfaceInfo* info);
        void (*on_layer_surface_destroy)(void* ctx, uint32_t surface_id);
        /* wp_alpha_modifier: the surface's opacity multiplier changed. */
        void (*on_surface_alpha)(void* ctx, uint32_t surface_id, double alpha);
        /* wlr-screencopy: a client wants the presented pixels of output
         * `output_index`, region (x,y,w,h) in device pixels; the shell
         * answers with wayland_server_screencopy_deliver/fail. */
        void (*on_screencopy_request)(void* ctx, uint32_t frame_id,
                                      int output_index, int32_t x, int32_t y,
                                      int32_t w, int32_t h);
        /* xx-zones: a client asked for its toplevel to sit at (x,y) of the
         * work area of output `output_index`; the shell moves the window and
         * reports back through wayland_server_toplevel_position. */
        void (*on_toplevel_position_request)(void* ctx, uint32_t surface_id,
                                             int output_index,
                                             int32_t x, int32_t y);
        /* xdg_system_bell: ring for `surface_id` (0 = no surface). */
        void (*on_system_bell)(void* ctx, uint32_t surface_id);
        /* A keyboard-shortcuts inhibitor for the surface was granted (1) or
         * went away (0). */
        void (*on_shortcuts_inhibit)(void* ctx, uint32_t surface_id, int inhibited);
        /* ext-session-lock: the session locked (1) or unlocked (0). While
         * locked the shell shows nothing but lock surfaces (which arrive as
         * overlay layer surfaces named "session-lock") and black. */
        void (*on_session_lock)(void* ctx, int locked);
        /* ext-workspace: a client asked to activate/deactivate/remove a
         * space (by id) or create one (name). */
        void (*on_workspace_request)(void* ctx, uint32_t workspace_id, int request,
                                     const char* name);
        /* ext-background-effect: blur behind these surface-local rects. */
        void (*on_surface_blur)(void* ctx, uint32_t surface_id,
                                const int32_t* rects, int count);
        /* Virtual input: a frame of pointer state, and one key. */
        void (*on_virtual_pointer)(void* ctx, int output_index, int has_abs,
                                   double ax, double ay, double dx, double dy,
                                   uint32_t buttons, double wheel_dx, double wheel_dy);
        void (*on_virtual_key)(void* ctx, uint32_t evdev_key, uint32_t keysym,
                               const char* utf8, int pressed);
        /* wp_pointer_warp: put the pointer at (x, y) of the surface. */
        void (*on_pointer_warp)(void* ctx, uint32_t surface_id, double x, double y);
        /* Drag-and-drop: the icon to draw at the pointer (0 = none), and a
         * toplevel riding along (active 0 = let go). */
        void (*on_drag_icon)(void* ctx, uint32_t surface_id, int active);  // active: a drag is on
        void (*on_toplevel_drag)(void* ctx, uint32_t surface_id, int32_t x_off,
                                 int32_t y_off, int active);
        /* wlr-output-management apply: the host output's scale. */
        void (*on_output_config)(void* ctx, uint32_t config_id, double host_scale);
    } cb;

    // Socket
    char socket_name[64];
    // A second listening socket in the real per-user runtime dir
    // (/run/user/<uid>), so AppArmor-confined snaps — which may reach the
    // compositor only at the standard @{run}/user/@{uid}/ path — can connect.
    // Empty when not exposed. Unlinked on destroy.
    char extra_socket_path[108];
};

/* Double-buffered zwlr_layer_surface_v1 state. */
struct WaylandLayerState {
    uint32_t layer;              // zwlr_layer_shell_v1_layer
    uint32_t anchor;             // zwlr_layer_surface_v1_anchor bitfield
    int32_t exclusive_zone;      // >0 reserve, 0 none, <0 ignore others'
    int32_t margin_top, margin_right, margin_bottom, margin_left;
    uint32_t keyboard_interactivity;
    uint32_t desired_w, desired_h;   // 0 = stretch along the anchored axis
    uint32_t exclusive_edge;     // 0 = derived from the anchor
};

struct WaylandLayerSurface {
    struct wl_resource* resource;        // zwlr_layer_surface_v1, or NULL for
                                         // a surface another role lent here
                                         // (a session-lock surface)
    struct WaylandSurface* surface;      // NULL once the wl_surface died
    struct WaylandServer* server;
    int output_index;                    // resolved at creation (0 = ours to pick)
    char namespace_[64];
    struct WaylandLayerState pending, current;
    int configured;                      // the initial configure went out
    int announced;                       // the shell has been told (on_new)
    WaylandLayerSurfaceInfo last_info;   // what the shell last heard
    struct wl_list link;                 // server->layer_surfaces
};

/* One taskbar's view of the toplevels (zwlr_foreign_toplevel_manager_v1 or
 * ext_foreign_toplevel_list_v1 — `ext` tells which). */
struct WaylandForeignManager {
    struct wl_resource* resource;
    struct WaylandServer* server;
    int ext;                             // 0 = zwlr, 1 = ext list
    int stopped;                         // stop requested: no new handles
    struct wl_list handles;              // WaylandForeignHandle.link
    struct wl_list link;                 // server->foreign_managers
};

struct WaylandForeignHandle {
    struct wl_resource* resource;
    struct WaylandForeignManager* manager;
    struct WaylandSurface* surface;      // NULL once closed
    struct wl_list link;                 // manager->handles
    struct wl_list surface_link;         // surface->foreign_handles
};

/* A pending capture frame — a zwlr_screencopy_frame_v1, or (ext = 1) an
 * ext_image_copy_capture_frame_v1; both end in the same shell readback. */
struct WaylandScreencopyFrame {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint32_t id;                         // what the shell answers with
    int output_index;
    int32_t x, y, w, h;                  // device pixels on that output
    int overlay_cursor;
    int with_damage;
    struct wl_resource* buffer;          // the client's wl_buffer, once copy()
    struct wl_listener buffer_destroy;
    int requested;                       // handed to the shell
    int ext;                             // which protocol's frame this is
    struct WaylandImageCopySession* session;   // ext: the session it belongs to
    struct wl_list link;                 // server->screencopy_frames
};

/* ext_image_copy_capture_session_v1 over an output source. */
struct WaylandImageCopySession {
    struct wl_resource* resource;
    struct WaylandServer* server;
    int output_index;
    int32_t sent_w, sent_h;              // the buffer_size last announced
    struct WaylandScreencopyFrame* frame;   // the one frame in flight, or NULL
    int stopped;
    struct wl_list link;                 // server->image_copy_sessions
};

/* zxdg_exported_v2: a toplevel another client may name as a parent. */
struct WaylandForeignExport {
    struct wl_resource* resource;
    struct WaylandSurface* surface;      // NULL once the toplevel went
    char handle[48];
    struct wl_list imports;              // WaylandForeignImport.link
    struct wl_list link;                 // server->foreign_exports
};

struct WaylandForeignImport {
    struct wl_resource* resource;
    struct WaylandForeignExport* export_; // NULL once destroyed/invalid
    struct wl_list link;                 // export_->imports
};

/* wp_security_context_v1: a sandbox's listening socket, adopted. */
struct WaylandSecurityContext {
    struct wl_resource* resource;
    struct WaylandServer* server;
    int listen_fd, close_fd;
    char sandbox_engine[64], app_id[128], instance_id[64];
    int committed;
    struct wl_event_source* listen_source;
    struct wl_event_source* close_source;
    struct wl_list link;                 // server->security_contexts
};

/* A client that came in through a security context: its identity, and the
 * reason wl_global_set_filter hides the privileged globals from it. */
struct WaylandSandboxedClient {
    struct wl_client* client;
    struct wl_listener destroy;
    char sandbox_engine[64], app_id[128], instance_id[64];
    struct wl_list link;                 // server->sandboxed_clients
};

/* One of the shell's spaces, as ext-workspace shows it. */
struct WaylandWorkspace {
    uint32_t id;
    char name[64];
    int active;
    int index;
    struct wl_list link;                 // server->workspaces
};

struct WaylandWorkspaceHandle {
    struct wl_resource* resource;
    struct WaylandWorkspaceManager* manager;
    uint32_t workspace_id;
    int removed;
    struct wl_list link;                 // manager->handles
};

struct WaylandWorkspaceManager {
    struct wl_resource* resource;
    struct wl_resource* group;
    struct WaylandServer* server;
    int stopped;
    struct wl_list handles;              // WaylandWorkspaceHandle.link
    /* Requests wait for commit. */
    uint32_t pending_activate, pending_deactivate, pending_remove;
    char pending_create[64];
    int pending_create_set;
    struct wl_list link;                 // server->workspace_managers
};

struct WaylandTransientSeat {
    struct wl_resource* resource;
    struct wl_global* global;
    struct WaylandSeatDesc desc;
    char name[32];
    struct wl_list link;                 // server->transient_seats
};

/* An applied wlr-output-management configuration awaiting the shell. */
struct WaylandOutputConfig {
    struct wl_resource* resource;
    uint32_t id;
    struct wl_list link;                 // server->output_configs
};

/* zwlr_output_manager_v1: one bind, with a head resource per output. */
struct WaylandOutputManager {
    struct wl_resource* resource;
    struct WaylandServer* server;
    int stopped;
    struct wl_resource* heads[8 /* WAYLAND_MAX_OUTPUTS */];
    struct wl_resource* modes[8];
    struct wl_list link;                 // server->output_managers
};

/* xx_zone_v1: a client's view of one output's work area. */
struct WaylandZone {
    struct wl_resource* resource;
    struct WaylandServer* server;
    int output_index;
    char handle[32];
    struct wl_list link;                 // server->zones
};

/* xx_zone_item_v1 wrapping a toplevel. */
struct WaylandZoneItem {
    struct wl_resource* resource;
    struct WaylandServer* server;
    struct WaylandSurface* surface;      // NULL once the toplevel died (inert)
    struct WaylandZone* zone;            // current membership
    struct WaylandZone* pending_zone;    // add_item, applied on commit
    int pending_zone_set;
    int pending_remove;                  // remove_item, applied on commit
    int32_t pending_x, pending_y;
    int pending_pos_set;
    int32_t last_x, last_y;              // last position event sent
    int have_last;
    int awaiting_position;               // a set_position awaits the shell
    struct wl_list link;                 // server->zone_items
};

struct WaylandShortcutsInhibitor {
    struct wl_resource* resource;
    struct WaylandSurface* surface;
    struct wl_list link;
};

struct WaylandIdleNotification {
    struct wl_resource* resource;
    struct WaylandServer* server;
    uint32_t timeout_ms;
    int ignore_inhibitors;               // get_input_idle_notification (v2)
    int idle;                            // `idle` sent, `resumed` owed
    struct wl_event_source* timer;
    struct wl_list link;
};

// Presentation feedback (one per wp_presentation.feedback request)
struct WaylandPresentationFeedback {
    struct wl_resource* resource;
    uint32_t surface_id;
    struct wl_list link;  // in WaylandServer.presentation_feedbacks
};

// Per-client relative pointer resource
struct WaylandRelativePointerResource {
    struct wl_resource* resource;
    struct wl_list link;  // in WaylandServer.relative_pointers
};

// Per-client input resource (pointer or keyboard)
struct WaylandInputResource {
    struct wl_resource* resource;
    struct wl_list link;  // in WaylandServer.pointer_resources or keyboard_resources
    int seat;             // which wl_seat global this resource was bound from
};

// Deferred input event types
enum WaylandInputEventType {
    WL_PTR_ENTER = 1,
    WL_PTR_LEAVE = 2,
    WL_PTR_MOTION = 3,
    WL_PTR_BUTTON = 4,
    WL_KB_ENTER = 5,
    WL_KB_LEAVE = 6,
    WL_KB_KEY = 7,
    WL_KB_MODIFIERS = 8,
    WL_PTR_AXIS = 9,
    /* Not input: dma-buf modifier demotion marshalled from the raster
     * thread (EGL import failure) onto the loop thread, where the
     * linux-dmabuf feedback re-send is safe. Rides this queue because it
     * is the one cross-thread → loop-thread mechanism (see the
     * WARN_IF_OFF_LOOP_THREAD note below). fourcc in `button`,
     * modifier in `modifier`. */
    WL_DMABUF_DEMOTE = 10,
};

struct WaylandPointerEvent {
    enum WaylandInputEventType type;
    /* 0 = the human seat, 1 = the agent seat (Murmuration). Delivered only
     * to wl_pointer/wl_keyboard resources bound from the matching seat. */
    int seat;
    uint32_t surface_id;
    uint32_t time_ms;
    double x, y;
    uint32_t button;
    uint32_t state;
    // Keyboard modifier fields (used by WL_KB_KEY and WL_KB_MODIFIERS)
    uint32_t mods_depressed;
    uint32_t mods_latched;
    uint32_t mods_locked;
    uint32_t group;
    // DRM format modifier (used by WL_DMABUF_DEMOTE; fourcc rides in button)
    uint64_t modifier;
};

// Forward declaration for clipboard
struct WaylandDataSource;

// Module init functions (called by wayland_server_create)
void wayland_compositor_init(struct WaylandServer* server);
void wayland_dmabuf_init(struct WaylandServer* server);
/* Loop-thread only (reached via the deferred queue, WL_DMABUF_DEMOTE):
 * drop a modifier from the linux-dmabuf advertisement and re-send v4
 * feedback to every live feedback object so clients re-allocate. */
void wayland_dmabuf_demote_on_loop_thread(struct WaylandServer* server,
                                          uint32_t fourcc, uint64_t modifier);
void wayland_xdg_shell_init(struct WaylandServer* server);
void wayland_seat_init(struct WaylandServer* server);
void wayland_output_init(struct WaylandServer* server);
void wayland_output_send_enter(struct WaylandServer* server,
                               struct WaylandSurface* surface);
void wayland_output_send_leave(struct WaylandServer* server,
                               struct WaylandSurface* surface);
void wayland_shm_init(struct WaylandServer* server);
void wayland_decoration_init(struct WaylandServer* server);
void wayland_subcompositor_init(struct WaylandServer* server);
void wayland_data_device_init(struct WaylandServer* server);
void wayland_data_control_init(struct WaylandServer* server);
/* Unified clipboard: replace the current selection (owner NULL clears it),
 * notify the displaced owner, and broadcast the new offer to every bound
 * wl_data_device AND zwlr_data_control_device. Called by both protocols'
 * set_selection handlers. */
void wayland_clipboard_set(struct WaylandServer* server, void* owner,
                           char** mimes, int mime_count,
                           void (*send)(void* owner, const char* mime, int32_t fd),
                           void (*cancel)(void* owner));
/* Re-send the current selection to all bound devices of each protocol
 * (implemented in the respective file). */
void wayland_data_device_broadcast_selection(struct WaylandServer* server);
void wayland_data_control_broadcast_selection(struct WaylandServer* server);
/* Offer the current selection to a client that is starting to interact with a
 * surface, if it has not already been told about this selection. Without it a
 * client never sees a selection that predates it. Called from the pointer- and
 * keyboard-enter paths; cheap (serial-guarded) and a no-op when empty. */
void wayland_data_device_offer_on_interaction(struct WaylandServer* server,
                                              struct WaylandSurface* surface);
void wayland_fractional_scale_init(struct WaylandServer* server);
void wayland_viewporter_init(struct WaylandServer* server);
void wayland_cursor_shape_init(struct WaylandServer* server);
void wayland_pointer_constraints_init(struct WaylandServer* server);
void wayland_relative_pointer_init(struct WaylandServer* server);
void wayland_primary_selection_init(struct WaylandServer* server);
/* A client's pointer or keyboard entered a surface: hand its primary-
 * selection devices the current selection if they have not had it. */
void wayland_primary_selection_offer_on_interaction(struct WaylandServer* server,
                                                    struct WaylandSurface* surface);
void wayland_text_input_init(struct WaylandServer* server);
void wayland_text_input_focus_enter(struct WaylandServer* server,
                                    struct WaylandSurface* surface);
void wayland_text_input_focus_leave(struct WaylandServer* server,
                                    struct WaylandSurface* surface);
void wayland_text_input_surface_destroyed(struct WaylandServer* server,
                                          struct WaylandSurface* surface);
void wayland_idle_inhibit_init(struct WaylandServer* server);
void wayland_xdg_output_init(struct WaylandServer* server);
void wayland_xdg_activation_init(struct WaylandServer* server);
void wayland_presentation_init(struct WaylandServer* server);
/* An activation token minted by xdg_activation_v1; the foreign-toplevel
 * and activation paths both end in the shell's on_toplevel_request. */
void wayland_xdg_activation_issue_token(struct WaylandServer* server,
                                        char* out, size_t out_len);
int wayland_xdg_activation_consume_token(struct WaylandServer* server,
                                         const char* token);

/* Send a toplevel configure carrying the surface's current state bits
 * (ACTIVATED always — see wayland_xdg_shell.c). w/h = 0 repeats the last
 * configured size. */
/* A configure of 0x0 — "pick your own size" — with the current states.
 * For a dialog, which the shell does not open maximized. */
void wayland_xdg_shell_configure_natural(struct WaylandServer* server,
                                         struct WaylandSurface* surface);
void wayland_xdg_shell_configure(struct WaylandServer* server,
                                 struct WaylandSurface* surface,
                                 int32_t w, int32_t h);
/* The shell answered a client's request (or changed a window itself):
 * record the bits, re-configure if a configure-visible bit changed, and
 * tell every foreign-toplevel handle. */
void wayland_xdg_shell_set_states(struct WaylandServer* server,
                                  struct WaylandSurface* surface,
                                  uint32_t states);

void wayland_layer_shell_init(struct WaylandServer* server);
/* Called from surface_commit before the buffer is handed to the shell:
 * applies the double-buffered layer state and sends the configure the
 * client is waiting for. */
void wayland_layer_shell_commit(struct WaylandServer* server,
                                struct WaylandSurface* surface);
void wayland_layer_shell_surface_destroyed(struct WaylandServer* server,
                                           struct WaylandSurface* surface);
/* An output left the desktop: layer surfaces on it are closed. */
void wayland_layer_shell_output_removed(struct WaylandServer* server,
                                        int output_index);
/* Another role (session lock) borrowing the layer machinery: the surface is
 * placed like a layer surface with this arrangement, announced to the shell
 * through the layer callbacks, and configured by its own protocol. */
struct WaylandLayerSurface* wayland_layer_shell_adopt(struct WaylandServer* server,
                                                      struct WaylandSurface* surface,
                                                      int output_index, uint32_t layer,
                                                      uint32_t anchor,
                                                      uint32_t keyboard_interactivity,
                                                      const char* namespace_);
void wayland_layer_shell_release(struct WaylandLayerSurface* ls);

void wayland_session_lock_init(struct WaylandServer* server);
void wayland_workspace_init(struct WaylandServer* server);
void wayland_background_effect_init(struct WaylandServer* server);
void wayland_background_effect_commit(struct WaylandServer* server,
                                      struct WaylandSurface* surface);
void wayland_transient_seat_init(struct WaylandServer* server);
/* A wl_seat global aliasing the human seat under another name (transient
 * seats); the desc must outlive the global. */
struct wl_global* wayland_seat_create_global(struct WaylandServer* server,
                                             struct WaylandSeatDesc* desc);
void wayland_virtual_input_init(struct WaylandServer* server);
void wayland_pointer_warp_init(struct WaylandServer* server);
void wayland_toplevel_drag_init(struct WaylandServer* server);
/* Drag-and-drop, in the data-device module: pointer events are routed here
 * while a drag is active (returns 1 when consumed). */
int wayland_dnd_pointer_event(struct WaylandServer* server,
                              const struct WaylandPointerEvent* ev,
                              struct WaylandSurface* surface);
void wayland_dnd_surface_destroyed(struct WaylandServer* server,
                                   struct WaylandSurface* surface);
void wayland_dnd_end(struct WaylandServer* server, int dropped);
/* wlr-output-management: the shell's answer to an applied configuration. */
void wayland_output_management_config_result(struct WaylandServer* server,
                                             uint32_t config_id, int ok);

void wayland_alpha_modifier_init(struct WaylandServer* server);
void wayland_alpha_modifier_commit(struct WaylandServer* server,
                                   struct WaylandSurface* surface);

void wayland_foreign_toplevel_init(struct WaylandServer* server);
/* The toplevel committed its first buffer / lost its role. */
void wayland_foreign_toplevel_map(struct WaylandServer* server,
                                  struct WaylandSurface* surface);
void wayland_foreign_toplevel_unmap(struct WaylandServer* server,
                                    struct WaylandSurface* surface);
void wayland_foreign_toplevel_title(struct WaylandSurface* surface);
void wayland_foreign_toplevel_app_id(struct WaylandSurface* surface);
void wayland_foreign_toplevel_state(struct WaylandSurface* surface);
void wayland_foreign_toplevel_output(struct WaylandSurface* surface,
                                     struct WaylandOutput* output, int enter);

void wayland_screencopy_init(struct WaylandServer* server);

void wayland_zones_init(struct WaylandServer* server);
/* Applies pending zone membership + position on commit. */
void wayland_zones_commit(struct WaylandServer* server,
                          struct WaylandSurface* surface);
void wayland_zones_surface_destroyed(struct WaylandServer* server,
                                     struct WaylandSurface* surface);
/* The work area of an output changed: every zone on it re-sends size. */
void wayland_zones_work_area_changed(struct WaylandServer* server,
                                     int output_index);

void wayland_single_pixel_buffer_init(struct WaylandServer* server);
void wayland_misc_protocols_init(struct WaylandServer* server);
void wayland_shortcuts_inhibit_init(struct WaylandServer* server);
void wayland_shortcuts_inhibit_surface_destroyed(struct WaylandServer* server,
                                                 struct WaylandSurface* surface);
void wayland_pointer_gestures_init(struct WaylandServer* server);
void wayland_tablet_init(struct WaylandServer* server);
void wayland_ext_data_control_init(struct WaylandServer* server);
void wayland_ext_data_control_broadcast_selection(struct WaylandServer* server);
void wayland_idle_notify_init(struct WaylandServer* server);
/* Input reached a client: idle timers restart. Loop thread. */
void wayland_idle_notify_activity(struct WaylandServer* server);
/* ext-image-copy-capture lives beside wlr-screencopy (same readback). */
void wayland_image_copy_capture_init(struct WaylandServer* server);
void wayland_xdg_foreign_init(struct WaylandServer* server);
void wayland_xdg_foreign_surface_destroyed(struct WaylandServer* server,
                                           struct WaylandSurface* surface);
void wayland_color_representation_init(struct WaylandServer* server);
void wayland_security_context_init(struct WaylandServer* server);
/* Non-NULL when the client came in through a security context. */
struct WaylandSandboxedClient* wayland_client_sandbox(struct WaylandServer* server,
                                                      struct wl_client* client);
void wayland_output_management_init(struct WaylandServer* server);
/* The output set changed: every manager hears the new heads + done. */
void wayland_output_management_outputs_changed(struct WaylandServer* server);

/* Output resource -> its index in server->outputs, -1 if not one of ours. */
int wayland_output_index_of(struct WaylandServer* server,
                            struct wl_resource* output_resource);
/* The seat index a wl_seat resource was bound from (0 human, 1 agent),
 * -1 if not one of ours. */
int wayland_seat_index_of(struct wl_resource* seat_resource);
/* A wl_buffer's dimensions + the ShmBuffer behind it (NULL if not shm). */
struct ShmBuffer* wayland_shm_buffer_from_resource(struct wl_resource* buffer);

// Warn (once per call site) when a loop-thread-only function runs on another
// thread. libwayland-server send/marshal paths are not thread-safe; calling
// them off the event-loop thread corrupts the client connection. This is a
// diagnostic, not a fix — route new cross-thread work through the deferred
// input queue or the Swift command queue instead.
#define WARN_IF_OFF_LOOP_THREAD(server, what)                                 \
    do {                                                                      \
        if ((server)->loop_thread_set &&                                      \
            !pthread_equal(pthread_self(), (server)->loop_thread)) {          \
            static int warned_;                                               \
            if (!warned_) {                                                   \
                warned_ = 1;                                                  \
                fprintf(stderr, "[WaylandServer] WARNING: %s called off the " \
                        "event-loop thread (unsafe)\n", what);                \
            }                                                                 \
        }                                                                     \
    } while (0)

// Helpers
uint32_t wayland_server_next_serial(struct WaylandServer* server);
struct WaylandSurface* wayland_server_find_surface(struct WaylandServer* server, uint32_t surface_id);

/* xdg_popup grabs (wayland_xdg_shell.c). `contains`: the surface is a popup
 * inside a grabbed popup's tree (itself grabbed, or under one). A press on
 * anything else while a grab is in force dismisses every grabbed popup,
 * topmost first (popup_done), which is what the spec asks of the compositor. */
int wayland_popup_grab_contains(struct WaylandServer* server, struct WaylandSurface* surface);
void wayland_popup_grab_dismiss_all(struct WaylandServer* server);

/* Server teardown for the per-server lists that no client resource owns. */
void wayland_security_context_fini(struct WaylandServer* server);
void wayland_workspace_fini(struct WaylandServer* server);

// Send `discarded` to (and destroy) all pending wp_presentation feedback
// objects for a surface — called when the surface is destroyed so feedbacks
// don't linger until client disconnect.
void wayland_server_presentation_discard(struct WaylandServer* server,
                                         uint32_t surface_id);

// Answer pending wp_presentation feedbacks paced by the flipping output
// (surface pace_mask; 0 = primary = bit 0) with a real scanout timestamp +
// that output's refresh period (flip-driven path). Event-loop thread only.
void wayland_server_presentation_present_all(struct WaylandServer* server,
                                             uint64_t flip_time_ns,
                                             uint32_t refresh_ns,
                                             uint32_t flip_output_mask);

#endif
