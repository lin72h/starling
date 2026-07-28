/*
 * ime_bridge.h — fcitx5 DBus input-method bridge for the desktop shell.
 *
 * Connects to the user session bus, creates a fcitx5 input context
 * (org.fcitx.Fcitx.InputContext1 via the portal object), and exposes a
 * synchronous ProcessKeyEvent plus callbacks for committed text, preedit,
 * and client-side candidate lists (fcitx's ClientSideInputPanel capability —
 * the shell draws the candidate window itself).
 *
 * Threading: the bridge runs its own event-loop thread that owns the sd-bus
 * connection. ime_bridge_process_key() may be called from any thread; it
 * hands the request to the loop thread and blocks (bounded) for the reply.
 * Callbacks fire on the loop thread — the Swift side marshals to the UI.
 */
#ifndef IME_BRIDGE_H
#define IME_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ImeBridge ImeBridge;

typedef struct ImeBridgeCallbacks {
    void* ctx;
    /* IME committed final text (UTF-8). */
    void (*commit_string)(void* ctx, const char* text);
    /* Preedit (composition-in-progress) text changed; cursor is a byte
     * offset into text. Empty text = composition ended. */
    void (*preedit)(void* ctx, const char* text, int32_t cursor);
    /* Candidate list changed. labels/texts are parallel arrays (UTF-8).
     * count == 0 hides the panel. highlighted is an index or -1. */
    void (*candidates)(void* ctx,
                       const char* const* labels,
                       const char* const* texts,
                       int32_t count,
                       int32_t highlighted,
                       int32_t has_prev,
                       int32_t has_next);
    /* IME asks the client to inject a key it did not consume. */
    void (*forward_key)(void* ctx, uint32_t keysym, uint32_t state,
                        int32_t is_release);
    /* Async ProcessKeyEvent verdict for the request posted with `cookie`.
     * handled == 0 → the caller must replay the key to the app. */
    void (*key_verdict)(void* ctx, uint64_t cookie, int32_t handled);
} ImeBridgeCallbacks;

/* Create the bridge and start its thread. When the shell runs as root,
 * target_uid is the login user's uid — the bridge thread drops its
 * effective uid to it before connecting (the user's dbus-broker rejects
 * cross-uid peers). Pass 0 to keep the current uid. Returns NULL on
 * allocation failure; DBus/fcitx availability is reported by
 * ime_bridge_ready(). */
ImeBridge* ime_bridge_create(const ImeBridgeCallbacks* callbacks,
                             uint32_t target_uid);

/* 1 once the input context is created and usable, 0 while connecting or
 * when fcitx5 is unavailable (the bridge keeps retrying every few seconds). */
int ime_bridge_ready(ImeBridge* bridge);

/* Feed one key — fully async; NEVER blocks (the shell's platform thread
 * is the DRM event loop). keysym is an X11 keysym, state an X11 modifier
 * mask (Shift=1<<0, Ctrl=1<<2, Alt=1<<3). The verdict arrives via the
 * key_verdict callback with the same cookie; unhandled keys must then be
 * replayed to the app by the caller. */
void ime_bridge_process_key_async(ImeBridge* bridge, uint32_t keysym,
                                  uint32_t keycode, uint32_t state,
                                  int32_t is_release, uint32_t time_ms,
                                  uint64_t cookie);

/* Focus / reset — async, safe from any thread. */
void ime_bridge_focus_in(ImeBridge* bridge);
void ime_bridge_focus_out(ImeBridge* bridge);
void ime_bridge_reset(ImeBridge* bridge);

/* Report the caret rect (screen logical coords) to fcitx — async. */
void ime_bridge_set_cursor_rect(ImeBridge* bridge, int32_t x, int32_t y,
                                int32_t w, int32_t h);

void ime_bridge_destroy(ImeBridge* bridge);

#ifdef __cplusplus
}
#endif

#endif /* IME_BRIDGE_H */
