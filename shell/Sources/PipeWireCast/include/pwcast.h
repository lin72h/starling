// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// pwcast.h — PipeWire video-source stream for portal ScreenCast sessions.
//
// The producer half of org.freedesktop.portal.ScreenCast: publishes the
// shell's capture frames as a PipeWire "Video/Source" node that portal
// consumers (Chromium, OBS, gstreamer) connect to by the node id the
// portal's Start response carries. One stream per PwCast; the shell runs
// at most one ScreenCast session, so at most one of these exists.
//
// Frames are top-down RGBA, pushed from whatever thread delivers them
// (the engine's recorder writer thread) — push locks the stream's own
// loop, copies into a daemon-allocated buffer, and queues it. A consumer
// that has not finished negotiating, or has fallen behind, costs a
// dropped frame, never a stalled caller.

#ifndef PWCAST_H
#define PWCAST_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PwCast PwCast;

/// True when a PipeWire daemon socket is reachable (honours
/// PIPEWIRE_RUNTIME_DIR, then XDG_RUNTIME_DIR — the session launchers
/// point the former at the real user runtime dir, because the latter is
/// the shell's private dir).
int pwcast_available(void);

/// Create, connect, and negotiate a video-source stream of fixed size.
/// Blocks until the daemon has the node (a few ms) or ~3s on failure.
/// Returns NULL if the daemon is unreachable or negotiation fails.
PwCast *pwcast_start(uint32_t width, uint32_t height);

/// The stream's global node id — what the portal Start response reports.
/// Valid after pwcast_start returns non-NULL.
uint32_t pwcast_node_id(PwCast *c);

/// Push one top-down RGBA frame. Any thread. A frame whose dimensions
/// differ from the negotiated size is dropped (the engine freezes its
/// output size per session, so this only guards a torn-down session).
void pwcast_push_frame(PwCast *c, const uint8_t *rgba,
                       uint32_t width, uint32_t height);

/// Disconnect and free. Any thread except the stream's own loop.
void pwcast_stop(PwCast *c);

#ifdef __cplusplus
}
#endif

#endif  // PWCAST_H
