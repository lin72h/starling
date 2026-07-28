/*
 * ime_bridge.c — fcitx5 DBus input-method bridge (see ime_bridge.h).
 */
#define _GNU_SOURCE
#include "ime_bridge.h"

#include <errno.h>
#include <poll.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/syscall.h>
#include <systemd/sd-bus.h>
#include <time.h>
#include <unistd.h>

#define FCITX_SERVICE   "org.fcitx.Fcitx5"
#define FCITX_IM_PATH   "/org/freedesktop/portal/inputmethod"
#define FCITX_IM_IFACE  "org.fcitx.Fcitx.InputMethod1"
#define FCITX_IC_IFACE  "org.fcitx.Fcitx.InputContext1"

/* fcitx5 CapabilityFlag bits */
#define CAP_PREEDIT                (1ULL << 1)
#define CAP_FORMATTED_PREEDIT      (1ULL << 4)
#define CAP_CLIENT_SIDE_INPUT_PANEL (1ULL << 39)

/* Request kinds handed from callers to the loop thread. */
enum req_kind { REQ_NONE = 0, REQ_KEY, REQ_FOCUS_IN, REQ_FOCUS_OUT, REQ_RESET,
                REQ_CURSOR_RECT };

/* One queued request. Keys carry their payload so several can be in
 * flight; ProcessKeyEvent itself is issued asynchronously — the shell's
 * platform thread is the DRM event loop and must NEVER block here. */
struct ime_req {
    enum req_kind kind;
    uint32_t keysym, keycode, state, time_ms;
    int32_t release;
    uint64_t cookie;
    int32_t rx, ry, rw, rh;
};

struct ImeBridge {
    ImeBridgeCallbacks cbs;
    pthread_t thread;
    int running;            /* loop thread keeps going while set */
    int wake_fd;            /* eventfd: callers → loop thread */
    uid_t target_uid;       /* thread drops to this euid before connecting */

    sd_bus* bus;            /* owned by the loop thread */
    char ic_path[128];      /* input-context object path ("" = not ready) */

    /* Caller→loop request FIFO (guarded by mutex). */
    pthread_mutex_t mutex;
    struct ime_req pending[32];
    int pending_count;
};

/* Capsule threaded through the async ProcessKeyEvent reply. */
struct key_call {
    struct ImeBridge* bridge;
    uint64_t cookie;
};

static int on_key_reply(sd_bus_message* m, void* userdata,
                        sd_bus_error* ret_error) {
    (void)ret_error;
    struct key_call* call = userdata;
    int handled = 0;
    if (!sd_bus_message_is_method_error(m, NULL))
        sd_bus_message_read(m, "b", &handled);
    if (call->bridge->cbs.key_verdict)
        call->bridge->cbs.key_verdict(call->bridge->cbs.ctx, call->cookie,
                                      handled);
    free(call);
    return 0;
}

/* ── signal handlers (loop thread) ─────────────────────────────────────── */

static int on_commit_string(sd_bus_message* m, void* userdata,
                            sd_bus_error* ret_error) {
    (void)ret_error;
    struct ImeBridge* b = userdata;
    const char* text = NULL;
    if (sd_bus_message_read(m, "s", &text) >= 0 && text && b->cbs.commit_string)
        b->cbs.commit_string(b->cbs.ctx, text);
    return 0;
}

/* UpdateFormattedPreedit(a(si) segments, i cursor) — concatenate segments. */
static int on_preedit(sd_bus_message* m, void* userdata,
                      sd_bus_error* ret_error) {
    (void)ret_error;
    struct ImeBridge* b = userdata;
    char buf[1024] = "";
    size_t used = 0;
    int32_t cursor = 0;

    if (sd_bus_message_enter_container(m, 'a', "(si)") < 0) return 0;
    for (;;) {
        const char* seg = NULL;
        int32_t fmt = 0;
        int r = sd_bus_message_read(m, "(si)", &seg, &fmt);
        if (r <= 0) break;
        if (seg) {
            size_t len = strlen(seg);
            if (used + len < sizeof(buf) - 1) {
                memcpy(buf + used, seg, len);
                used += len;
                buf[used] = '\0';
            }
        }
    }
    sd_bus_message_exit_container(m);
    sd_bus_message_read(m, "i", &cursor);

    if (b->cbs.preedit)
        b->cbs.preedit(b->cbs.ctx, buf, cursor);
    return 0;
}

/* UpdateClientSideUI(a(si) preedit, i cursor, a(si) auxUp, a(si) auxDown,
 *                    a(ss) candidates, i index, i layout, b prev, b next) */
static int on_client_side_ui(sd_bus_message* m, void* userdata,
                             sd_bus_error* ret_error) {
    (void)ret_error;
    struct ImeBridge* b = userdata;

    /* Preedit segments (also delivered here — use them so a plain
     * ClientSideInputPanel session needs no separate preedit signal). */
    char pre[1024] = "";
    size_t used = 0;
    if (sd_bus_message_enter_container(m, 'a', "(si)") < 0) return 0;
    for (;;) {
        const char* seg = NULL;
        int32_t fmt = 0;
        if (sd_bus_message_read(m, "(si)", &seg, &fmt) <= 0) break;
        if (seg) {
            size_t len = strlen(seg);
            if (used + len < sizeof(pre) - 1) {
                memcpy(pre + used, seg, len);
                used += len;
                pre[used] = '\0';
            }
        }
    }
    sd_bus_message_exit_container(m);
    int32_t cursor = 0;
    sd_bus_message_read(m, "i", &cursor);

    /* Skip auxUp / auxDown. */
    for (int i = 0; i < 2; i++) {
        if (sd_bus_message_enter_container(m, 'a', "(si)") >= 0) {
            const char* s;
            int32_t f;
            while (sd_bus_message_read(m, "(si)", &s, &f) > 0) {}
            sd_bus_message_exit_container(m);
        }
    }

    /* Candidates. */
    enum { MAX_CAND = 16 };
    char* labels[MAX_CAND];
    char* texts[MAX_CAND];
    int count = 0;
    if (sd_bus_message_enter_container(m, 'a', "(ss)") >= 0) {
        for (;;) {
            const char* label = NULL;
            const char* text = NULL;
            if (sd_bus_message_read(m, "(ss)", &label, &text) <= 0) break;
            if (count < MAX_CAND) {
                labels[count] = strdup(label ? label : "");
                texts[count] = strdup(text ? text : "");
                count++;
            }
        }
        sd_bus_message_exit_container(m);
    }
    int32_t highlighted = -1, layout = 0;
    int has_prev = 0, has_next = 0;
    sd_bus_message_read(m, "i", &highlighted);
    sd_bus_message_read(m, "i", &layout);
    sd_bus_message_read(m, "b", &has_prev);
    sd_bus_message_read(m, "b", &has_next);

    /* Only push preedit from here when it carries text or the composition
     * ended (no candidates either) — pinyin often sends its preedit via
     * UpdateFormattedPreedit and an empty field here, which must not
     * clobber it mid-composition. */
    if (b->cbs.preedit && (pre[0] != '\0' || count == 0))
        b->cbs.preedit(b->cbs.ctx, pre, cursor);
    if (b->cbs.candidates)
        b->cbs.candidates(b->cbs.ctx,
                          (const char* const*)labels,
                          (const char* const*)texts,
                          count, highlighted, has_prev, has_next);
    for (int i = 0; i < count; i++) {
        free(labels[i]);
        free(texts[i]);
    }
    return 0;
}

static int on_forward_key(sd_bus_message* m, void* userdata,
                          sd_bus_error* ret_error) {
    (void)ret_error;
    struct ImeBridge* b = userdata;
    uint32_t keysym = 0, state = 0;
    int is_release = 0;
    if (sd_bus_message_read(m, "uub", &keysym, &state, &is_release) >= 0
        && b->cbs.forward_key)
        b->cbs.forward_key(b->cbs.ctx, keysym, state, is_release);
    return 0;
}

/* ── connection bring-up (loop thread) ─────────────────────────────────── */

static int ime_connect(struct ImeBridge* b) {
    int r = sd_bus_open_user(&b->bus);
    if (r < 0) {
        fprintf(stderr, "[ImeBridge] sd_bus_open_user failed: %s\n",
                strerror(-r));
        return r;
    }

    sd_bus_error err = SD_BUS_ERROR_NULL;
    sd_bus_message* reply = NULL;
    r = sd_bus_call_method(b->bus, FCITX_SERVICE, FCITX_IM_PATH,
                           FCITX_IM_IFACE, "CreateInputContext", &err, &reply,
                           "a(ss)", 1, "program", "starling-shell");
    if (r < 0) {
        fprintf(stderr, "[ImeBridge] CreateInputContext failed: %s\n",
                err.message ? err.message : strerror(-r));
        sd_bus_error_free(&err);
        sd_bus_unref(b->bus);
        b->bus = NULL;
        return r;
    }
    const char* path = NULL;
    r = sd_bus_message_read(reply, "o", &path);
    if (r < 0 || !path) {
        sd_bus_message_unref(reply);
        sd_bus_unref(b->bus);
        b->bus = NULL;
        return r < 0 ? r : -EINVAL;
    }
    snprintf(b->ic_path, sizeof(b->ic_path), "%s", path);
    sd_bus_message_unref(reply);

    /* Signals from our input context. */
    struct {
        const char* name;
        sd_bus_message_handler_t handler;
    } sigs[] = {
        { "CommitString", on_commit_string },
        { "UpdateFormattedPreedit", on_preedit },
        { "UpdateClientSideUI", on_client_side_ui },
        { "ForwardKey", on_forward_key },
    };
    for (size_t i = 0; i < sizeof(sigs) / sizeof(sigs[0]); i++) {
        sd_bus_match_signal(b->bus, NULL, FCITX_SERVICE, b->ic_path,
                            FCITX_IC_IFACE, sigs[i].name, sigs[i].handler, b);
    }

    /* Client-side panel: the shell draws preedit + candidates itself. */
    uint64_t caps = CAP_PREEDIT | CAP_FORMATTED_PREEDIT
                  | CAP_CLIENT_SIDE_INPUT_PANEL;
    sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
                       "SetCapability", NULL, NULL, "t", caps);

    fprintf(stderr, "[ImeBridge] input context ready: %s\n", b->ic_path);
    return 0;
}

/* ── request execution (loop thread) ───────────────────────────────────── */

static void ime_execute(struct ImeBridge* b, const struct ime_req* req) {
    enum req_kind kind = req->kind;
    if (!b->bus || !b->ic_path[0]) {
        /* Not connected: answer key requests "unhandled" so the caller
         * replays the key to the app instead of eating it. */
        if (kind == REQ_KEY && b->cbs.key_verdict)
            b->cbs.key_verdict(b->cbs.ctx, req->cookie, 0);
        return;
    }
    switch (kind) {
    case REQ_KEY: {
        struct key_call* call = malloc(sizeof(*call));
        if (!call) return;
        call->bridge = b;
        call->cookie = req->cookie;
        int r = sd_bus_call_method_async(
            b->bus, NULL, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
            "ProcessKeyEvent", on_key_reply, call, "uuubu",
            req->keysym, req->keycode, req->state, req->release,
            req->time_ms);
        if (r < 0) {
            if (b->cbs.key_verdict)
                b->cbs.key_verdict(b->cbs.ctx, req->cookie, 0);
            free(call);
        }
        break;
    }
    case REQ_FOCUS_IN:
        sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
                           "FocusIn", NULL, NULL, "");
        /* The shell owns the enable toggle (Ctrl+Space never reaches
         * fcitx), so activate the composing engine explicitly — a fresh
         * context starts on the passthrough keyboard layout. */
        {
            const char* engine = getenv("STARLING_IME_ENGINE");
            if (!engine || !engine[0]) engine = "pinyin";
            sd_bus_call_method(b->bus, FCITX_SERVICE, "/controller",
                               "org.fcitx.Fcitx.Controller1", "SetCurrentIM",
                               NULL, NULL, "s", engine);
        }
        break;
    case REQ_FOCUS_OUT:
        sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
                           "FocusOut", NULL, NULL, "");
        break;
    case REQ_RESET:
        sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
                           "Reset", NULL, NULL, "");
        break;
    case REQ_CURSOR_RECT:
        sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path, FCITX_IC_IFACE,
                           "SetCursorRect", NULL, NULL, "iiii",
                           req->rx, req->ry, req->rw, req->rh);
        break;
    default:
        break;
    }
}

static void* ime_thread(void* arg) {
    struct ImeBridge* b = arg;
    time_t last_connect_try = 0;

    /* The user's dbus-broker rejects cross-uid peers, so when the shell
     * runs as root (DRM master) this THREAD drops its effective uid to the
     * login user before connecting. Raw syscall on purpose: glibc's
     * setresuid() broadcasts to every thread in the process. Same pattern
     * as PortalService. */
    if (b->target_uid != 0 && geteuid() != b->target_uid) {
        if (syscall(SYS_setresuid, (uid_t)-1, b->target_uid, (uid_t)-1) < 0)
            fprintf(stderr, "[ImeBridge] thread seteuid(%u): %s\n",
                    (unsigned)b->target_uid, strerror(errno));
    }

    while (b->running) {
        /* (Re)connect with a 5 s backoff — fcitx5 may start after the shell. */
        if (!b->bus) {
            time_t now = time(NULL);
            if (now - last_connect_try >= 5) {
                last_connect_try = now;
                ime_connect(b);
            }
        }

        struct pollfd fds[2];
        int nfds = 0;
        fds[nfds].fd = b->wake_fd;
        fds[nfds].events = POLLIN;
        nfds++;
        uint64_t bus_usec = UINT64_MAX;
        if (b->bus) {
            fds[nfds].fd = sd_bus_get_fd(b->bus);
            fds[nfds].events = (short)sd_bus_get_events(b->bus);
            nfds++;
            sd_bus_get_timeout(b->bus, &bus_usec);
        }
        int timeout_ms = 1000;
        if (bus_usec != UINT64_MAX) {
            uint64_t ms = bus_usec / 1000;
            if (ms < (uint64_t)timeout_ms) timeout_ms = (int)ms;
        }
        poll(fds, (nfds_t)nfds, timeout_ms);

        if (fds[0].revents & POLLIN) {
            uint64_t drain;
            (void)!read(b->wake_fd, &drain, sizeof(drain));
            for (;;) {
                struct ime_req req;
                pthread_mutex_lock(&b->mutex);
                if (b->pending_count == 0) {
                    pthread_mutex_unlock(&b->mutex);
                    break;
                }
                req = b->pending[0];
                b->pending_count--;
                memmove(&b->pending[0], &b->pending[1],
                        (size_t)b->pending_count * sizeof(b->pending[0]));
                pthread_mutex_unlock(&b->mutex);
                ime_execute(b, &req);
            }
        }

        if (b->bus) {
            int r;
            do {
                r = sd_bus_process(b->bus, NULL);
            } while (r > 0);
            if (r < 0) {
                fprintf(stderr,
                        "[ImeBridge] bus error: %s — reconnecting\n",
                        strerror(-r));
                sd_bus_unref(b->bus);
                b->bus = NULL;
                b->ic_path[0] = '\0';
            }
        }
    }

    if (b->bus) {
        if (b->ic_path[0])
            sd_bus_call_method(b->bus, FCITX_SERVICE, b->ic_path,
                               FCITX_IC_IFACE, "DestroyIC", NULL, NULL, "");
        sd_bus_unref(b->bus);
        b->bus = NULL;
    }
    return NULL;
}

/* ── caller-side request plumbing ──────────────────────────────────────── */

static void ime_post(struct ImeBridge* b, const struct ime_req* req) {
    pthread_mutex_lock(&b->mutex);
    if (b->pending_count < (int)(sizeof(b->pending) / sizeof(b->pending[0])))
        b->pending[b->pending_count++] = *req;
    pthread_mutex_unlock(&b->mutex);
    uint64_t one = 1;
    (void)!write(b->wake_fd, &one, sizeof(one));
}

static void ime_post_kind(struct ImeBridge* b, enum req_kind kind) {
    struct ime_req req = {0};
    req.kind = kind;
    ime_post(b, &req);
}

void ime_bridge_process_key_async(ImeBridge* b, uint32_t keysym,
                                  uint32_t keycode, uint32_t state,
                                  int32_t is_release, uint32_t time_ms,
                                  uint64_t cookie) {
    if (!b) return;
    struct ime_req req = {0};
    req.kind = REQ_KEY;
    req.keysym = keysym;
    req.keycode = keycode;
    req.state = state;
    req.release = is_release;
    req.time_ms = time_ms;
    req.cookie = cookie;
    ime_post(b, &req);
}

void ime_bridge_focus_in(ImeBridge* b)  { if (b) ime_post_kind(b, REQ_FOCUS_IN); }
void ime_bridge_focus_out(ImeBridge* b) { if (b) ime_post_kind(b, REQ_FOCUS_OUT); }
void ime_bridge_reset(ImeBridge* b)     { if (b) ime_post_kind(b, REQ_RESET); }

void ime_bridge_set_cursor_rect(ImeBridge* b, int32_t x, int32_t y,
                                int32_t w, int32_t h) {
    if (!b) return;
    struct ime_req req = {0};
    req.kind = REQ_CURSOR_RECT;
    req.rx = x;
    req.ry = y;
    req.rw = w;
    req.rh = h;
    ime_post(b, &req);
}

int ime_bridge_ready(ImeBridge* b) {
    return b && b->ic_path[0] != '\0';
}

ImeBridge* ime_bridge_create(const ImeBridgeCallbacks* callbacks,
                             uint32_t target_uid) {
    struct ImeBridge* b = calloc(1, sizeof(*b));
    if (!b) return NULL;
    b->cbs = *callbacks;
    b->target_uid = (uid_t)target_uid;
    b->running = 1;
    b->wake_fd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    pthread_mutex_init(&b->mutex, NULL);
    if (pthread_create(&b->thread, NULL, ime_thread, b) != 0) {
        close(b->wake_fd);
        free(b);
        return NULL;
    }
    return b;
}

void ime_bridge_destroy(ImeBridge* b) {
    if (!b) return;
    b->running = 0;
    uint64_t one = 1;
    (void)!write(b->wake_fd, &one, sizeof(one));
    pthread_join(b->thread, NULL);
    close(b->wake_fd);
    pthread_mutex_destroy(&b->mutex);
    free(b);
}
