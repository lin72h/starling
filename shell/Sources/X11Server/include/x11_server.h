#ifndef FLUTTER_X11_SERVER_H
#define FLUTTER_X11_SERVER_H

#include <stdint.h>
#include <sys/types.h>   /* pid_t — x11_server_window_pid */

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque server handle */
typedef struct X11Server X11Server;

/* --------------------------------------------------------------------------
 * Configuration
 * -------------------------------------------------------------------------- */

/* Window-manager requests an X client sends the WM (ICCCM/EWMH client
 * messages to the root, plus a raise via ConfigureWindow). The server has no
 * window policy of its own — the shell IS the window manager — so each is
 * forwarded through on_window_request and the shell answers with the same
 * operations its title bar buttons and dock use. The server's own state
 * bookkeeping (WM_STATE, _NET_WM_STATE, Map/UnmapNotify) is driven by the
 * shell pushing the RESULT back through x11_server_set_window_state, so a
 * request the shell declines leaves the client's view unchanged. */
typedef enum X11WindowRequest {
    X11_WIN_REQ_ACTIVATE = 1,   /* _NET_ACTIVE_WINDOW: unminimise, raise, focus */
    X11_WIN_REQ_RAISE,          /* XRaiseWindow (ConfigureWindow stack Above) */
    X11_WIN_REQ_MINIMIZE,       /* WM_CHANGE_STATE IconicState (XIconifyWindow) */
    X11_WIN_REQ_RESTORE,        /* XMapWindow on an iconified window */
    X11_WIN_REQ_MAXIMIZE,       /* _NET_WM_STATE add MAXIMIZED_HORZ/VERT */
    X11_WIN_REQ_UNMAXIMIZE,
    X11_WIN_REQ_FULLSCREEN,     /* _NET_WM_STATE add FULLSCREEN */
    X11_WIN_REQ_UNFULLSCREEN,
    X11_WIN_REQ_CLOSE,          /* _NET_CLOSE_WINDOW */
    X11_WIN_REQ_ABOVE,          /* _NET_WM_STATE_ABOVE set: keep above others */
    X11_WIN_REQ_UNABOVE,
} X11WindowRequest;

typedef struct X11ServerConfig {
    int      display_width;
    int      display_height;
    int      depth;             /* Color depth (default 24) */
    void*    userdata;

    /* Callbacks (all optional) */

    /* A new top-level window was mapped. */
    void (*on_window_mapped)(void* userdata, uint32_t window_id,
                              int x, int y, int width, int height);

    /* An override-redirect top-level was mapped: a menu, dropdown or tooltip.
     * These bypass the window manager by definition, so they get no title bar,
     * no dock entry and no placement of our own — they are drawn exactly where
     * the client asked, anchored to `parent_window_id` (the client's active
     * ordinary toplevel). Without this the window exists in the X server and is
     * never composited, so every menu in every X11 app is invisible.
     * x/y are device pixels RELATIVE TO parent_window_id's origin — the client
     * places menus in root space against where it thinks its toplevel is, which
     * is not where the shell composites it, so the difference is taken here. */
    void (*on_popup_mapped)(void* userdata, uint32_t window_id,
                             uint32_t parent_window_id,
                             int x, int y, int width, int height);

    /* An override-redirect top-level was unmapped or destroyed. */
    void (*on_popup_unmapped)(void* userdata, uint32_t window_id);

    /* A window was unmapped (hidden). */
    void (*on_window_unmapped)(void* userdata, uint32_t window_id);

    /* A window was destroyed. */
    void (*on_window_destroyed)(void* userdata, uint32_t window_id);

    /* A window was resized/moved. */
    void (*on_window_configured)(void* userdata, uint32_t window_id,
                                  int x, int y, int width, int height);

    /* DRI3: client presented a DMA-BUF for display.
     * fd:           DMA-BUF file descriptor.
     * width/height: Buffer dimensions in pixels.
     * stride:       Row stride in bytes.
     * fourcc:       DRM fourcc pixel format. */
    void (*on_present_buffer)(void* userdata, uint32_t window_id,
                               int fd, int width, int height,
                               int stride, uint32_t fourcc);

    /* Software present: the client drew into a window with core X (PutImage)
     * or MIT-SHM (ShmPutImage) rather than DRI3. This is how raster toolkits
     * paint — Qt's raster engine, GTK, xclock — so without it such clients map
     * a window and never show a pixel.
     *
     * pixels is RGBA8888, top-down, tightly packed (stride = width*4), and is
     * only valid for the duration of the call: upload it synchronously. */
    void (*on_present_image)(void* userdata, uint32_t window_id,
                              const uint8_t* pixels, int width, int height);

    /* Window title changed. */
    void (*on_title_changed)(void* userdata, uint32_t window_id,
                              const char* title);
    /* The window's WM_CLASS — the X11 spelling of a Wayland app_id. The class
     * name (instance if the class is empty) is what a .desktop entry's
     * StartupWMClass names, so the shell resolves it against the app catalog
     * exactly as it resolves xdg_toplevel.set_app_id, and the dock shows the
     * app's icon instead of nothing. Sent when the property is set and again
     * at map time (toolkits set it before mapping). */
    void (*on_app_id_changed)(void* userdata, uint32_t window_id,
                               const char* app_id);
    /* A window-manager request from a client (see X11WindowRequest). The
     * shell applies it with its own window operations; the server learns the
     * outcome from x11_server_set_window_state / _position. */
    void (*on_window_request)(void* userdata, uint32_t window_id, int request);
    /* The window's SHAPE bounding region was set (1) or removed (0). Pixels
     * outside the region are already delivered transparent; the shell drops
     * its own backdrop under such a window so what is behind shows through. */
    void (*on_window_shaped)(void* userdata, uint32_t window_id, int shaped);

    /* A native subwindow with its own GPU buffer was mapped inside a
     * top-level: a video output (VLC) reparented under the Qt video widget,
     * or any nested GLX/DRI3 child. The shell composites window_id's texture
     * INSIDE toplevel_window_id's content, at (x,y) device px relative to the
     * top-level's origin, in the window's own z-band — not a decorated window
     * on root, not an overlay above the chrome. Re-fired with a new offset or
     * size when the subwindow moves or resizes. window_id feeds the same
     * present callbacks as any window; the shell makes it a texture. */
    void (*on_child_surface_mapped)(void* userdata, uint32_t window_id,
                                     uint32_t toplevel_window_id,
                                     int x, int y, int width, int height);
    /* The subwindow was unmapped, destroyed, or reparented back to root. */
    void (*on_child_surface_unmapped)(void* userdata, uint32_t window_id);

    /* GetImage / screen capture: fill dst with the screen rect [x,y,w,h] as
     * X ZPixmap depth-32 BGRX, top-down (dst_len bytes, must be >= w*h*4).
     * Returns 1 on success, 0 if no frame is available yet. Optional — when
     * NULL, GetImage returns a black frame. */
    int (*capture_screen)(void* userdata, int x, int y, int width, int height,
                           uint8_t* dst, int dst_len);
    /* GetImage must answer with the screen as of the REQUEST: a client that
     * draws, syncs and grabs expects its drawing in the grab. The mirror
     * capture_screen reads is refreshed by presents, so the server parks the
     * request and calls this to arm a fresh capture; the shell calls
     * x11_server_complete_pending_captures once a frame presented after the
     * arm has been mirrored (or after a short deadline). Optional: when NULL,
     * GetImage answers at once from whatever the mirror holds. */
    int (*capture_arm)(void* userdata);
} X11ServerConfig;

/* --------------------------------------------------------------------------
 * Lifecycle
 * -------------------------------------------------------------------------- */

/* Create an X11 server listening on the given display number.
 * Creates /tmp/.X11-unix/X<display_num> socket.
 * Returns NULL on failure. */
X11Server* x11_server_create(int display_num, const X11ServerConfig* config);

/* Destroy the server and free all resources. */
void x11_server_destroy(X11Server* server);

/* --------------------------------------------------------------------------
 * Event loop
 * -------------------------------------------------------------------------- */

/* Return the listening socket fd for external polling. */
int x11_server_get_fd(X11Server* server);

/* Return all active fds (listen + client fds) for external polling.
 * Writes up to max_fds fds into the fds array. Returns the count. */
int x11_server_get_all_fds(X11Server* server, int* fds, int max_fds);

/* Set a callback that's called when a new client connects.
 * The callback receives the client's fd so it can be added to epoll. */
typedef void (*X11ClientConnectCallback)(int client_fd, void* userdata);
void x11_server_set_client_connect_callback(X11Server* server,
                                             X11ClientConnectCallback callback,
                                             void* userdata);

/* Set the epoll fd for automatic client fd registration.
 * When set, new client fds are added to this epoll automatically. */
void x11_server_set_epoll_fd(X11Server* server, int epoll_fd);

/* Accept new connections and process pending client data. */
void x11_server_dispatch(X11Server* server);

/* Return non-zero if there are active client connections. */
int x11_server_has_clients(X11Server* server);

/* --------------------------------------------------------------------------
 * Input — send events to X11 clients
 * -------------------------------------------------------------------------- */

/* Set focus to a window (sends FocusIn/FocusOut events). */
void x11_server_set_focus(X11Server* server, uint32_t window_id);

/* Where the shell composites the window's CONTENT, root-absolute device px.
 * A real WM reparents a client into a frame and the client's root position is
 * wherever the frame put it; here the shell draws the frame, so it tells the
 * server where the content landed and the server answers TranslateCoordinates
 * / GetGeometry with that and sends ConfigureNotify. Size is NOT taken from
 * here (it goes through x11_server_configure_window, which runs the full
 * resize flow); only x/y move. */
void x11_server_set_window_position(X11Server* server, uint32_t window_id,
                                    int x, int y);

/* Answer every parked GetImage from the mirror (see capture_arm). */
void x11_server_complete_pending_captures(X11Server* server);

/* The window's WM state as the shell has applied it. Updates WM_STATE and
 * _NET_WM_STATE (PropertyNotify), and on a minimise/restore transition sends
 * the ICCCM UnmapNotify/MapNotify a client waits on. */
void x11_server_set_window_state(X11Server* server, uint32_t window_id,
                                 int minimized, int maximized, int fullscreen);

/* Send pointer motion to the focused window. */
void x11_server_pointer_motion(X11Server* server, int x, int y);

/* Send pointer button press/release.
 * button: X11 button number (1=left, 2=middle, 3=right).
 * x, y: coordinates relative to the window. */
void x11_server_pointer_button(X11Server* server, uint32_t button,
                                int pressed, int x, int y);

/* Send key press/release (evdev keycode). */
void x11_server_key_event(X11Server* server, uint32_t keycode, int pressed);

/* Ask a window to close (WM_DELETE_WINDOW). Advisory — clients may ignore it,
 * so a caller that must see the app go away follows up with
 * x11_server_window_pid() and a signal. */
void x11_server_close_window(X11Server* server, uint32_t window_id);

/* pid of the client owning a window, from peer credentials. 0 if unknown. */
pid_t x11_server_window_pid(X11Server* server, uint32_t window_id);

/* Send EnterNotify to a window. */
void x11_server_enter_notify(X11Server* server, uint32_t window_id,
                              int x, int y);

/* Send LeaveNotify to a window. */
void x11_server_leave_notify(X11Server* server, uint32_t window_id,
                              int x, int y);

/* --------------------------------------------------------------------------
 * Window management — compositor → X11 client
 * -------------------------------------------------------------------------- */

/* Send ConfigureNotify to resize a window. */
void x11_server_configure_window(X11Server* server, uint32_t window_id,
                                  int width, int height);

/* Send buffer release (PresentIdleNotify) so client can reuse the pixmap. */
void x11_server_release_buffer(X11Server* server, uint32_t window_id);

/* --------------------------------------------------------------------------
 * Timer fds — for external epoll integration
 * -------------------------------------------------------------------------- */

/* Return the resize debounce timer fd. */
int x11_server_get_resize_timer_fd(X11Server* server);

/* Flush a pending resize (called when resize timer fires). */
void x11_server_flush_resize(X11Server* server);

/* Return the VBlank timer fd (~60Hz pacing). */
int x11_server_get_vblank_timer_fd(X11Server* server);

/* Arm the VBlank timer at ~60fps (16ms interval). */
void x11_server_arm_vblank_timer(X11Server* server);
/// Stops it again. The timer only has work while a client is connected;
/// left armed it is the desktop's largest idle cost (see the note in
/// x11_update_vblank_timer).
void x11_server_disarm_vblank_timer(X11Server* server);

/// Clients connected right now. The shell uses this to decide whether a
/// screen-capture check is worth making at all.
int x11_server_client_count(X11Server* server);

/* Process VBlank tick — send queued PresentComplete/IdleNotify events. */
void x11_server_vblank_tick(X11Server* server);

#ifdef __cplusplus
}
#endif

#endif /* FLUTTER_X11_SERVER_H */
