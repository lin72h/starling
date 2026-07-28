# X11 Chrome Resize Fix — Implementation Plan

## Status: WORKING (2026-03-27)

Chrome resize works: window frame follows mouse, Chrome renders at new size during drag,
no GPU crashes. The key breakthrough was fixing Chrome's GPU process stability via
vblank-driven Present events.

## What Real Xorg Does (from DebugPresent trace with xfwm4)

Per frame during drag:
```
q  → PresentPixmap queued for next vblank
e  → vblank fires
c  → present_copy_region() — GPU copies pixmap content to screen
i  → present_pixmap_idle() — sends IdleNotify + triggers shm_fence
d  → CompleteNotify sent to client
```

Key: **events at vblank cadence**. Chrome receives IdleNotify + CompleteNotify at the
display refresh rate, not immediately. Chrome's ANGLE/Vulkan frame pacing depends on this.

## What Was Broken (and Why)

### Problem 1: Chrome GPU process crash (exit_code=512, 30s watchdog)

**Root cause chain:**
1. Our server sent IdleNotify + CompleteNotify **immediately** in the PresentPixmap handler
2. Chrome presented ~20 frames in a 1-second burst, then went idle
3. Chrome's GPU thread sent X11 requests (GetSelectionOwner) between frames
4. After the burst, our server's dispatch loop stopped — no wakeup pipe signals
5. Chrome's 8 bytes of pending requests sat unread in our server's recv buffer
6. Chrome's `xcb_wait_for_reply()` blocked waiting for our reply
7. This prevented Chrome's xcb reader thread from becoming available
8. Chrome's WSI swapchain thread (`xcb_wait_for_special_event`) blocked in `poll()`
   on the X11 socket — no reader thread to process incoming data
9. Chrome's GPU compositor thread polled an internal eventfd at 16ms (software vsync
   fallback) — the eventfd was never signaled because Present events were never delivered
10. After 30 seconds, Chrome's GPU watchdog killed the process

**Key diagnostic:** `ss -xp` showed 768 bytes in Chrome's Send-Q (outgoing requests
stuck because our server wasn't reading them), and `gdb` showed the "WSI swapchain e"
thread stuck in `xcb_wait_for_special_event() → poll()`.

**Comparison with real Xorg:** On real Xorg, Chrome's GPU thread enters `ppoll(NULL
timeout)` — fully blocked, zero syscalls during idle. On our server, it busy-polled
at 16ms. Real Xorg continuously processes client requests via its main event loop;
our server only dispatched during wakeup pipe events.

### Problem 2: vblank timer never fired

The X11 server created a `timerfd` for vblank but never armed it or registered it
with the DRM epoll. `x11_server_get_vblank_timer_fd()` existed but nobody called it.

### Problem 3: Window frame frozen during drag

The original `resizeWindow()` only updated `targetRect` (visual frozen until Chrome
responds). With Chrome's GPU process crashing, Chrome never responded, so the window
appeared completely frozen.

## The Fix (What Was Actually Implemented)

### 1. Vblank timer (`x11_server.cc` + `X11Integration.swift`)

- `x11_server_arm_vblank_timer()`: arms timerfd at 16ms (~60fps)
- Registered with DRM epoll in `X11Integration.start()`
- On every tick:
  1. `x11_server_dispatch()` — reads and processes ALL pending client requests
  2. `x11_server_vblank_tick()` — triggers shm_fences + sends Present events
  3. `flushPendingTextureMarks()` — marks dirty textures from dispatched PresentPixmaps

The dispatch on every tick is **critical**. Without it, Chrome's xcb reader deadlocks
because our server never reads Chrome's inter-frame requests.

### 2. Vblank-deferred Present events (`x11_server.cc`)

**PresentPixmap handler:** removed immediate IdleNotify + CompleteNotify. Events are
now deferred to the next vblank tick, matching real Xorg's timing.

**vblank_tick:** for each window with a front buffer that hasn't been idled yet
(`front_idle_sent == 0`):
- Sends IdleNotify (32 bytes) to the presenting client's active registration
- Sends CompleteNotify (40 bytes, length=2) with UST/MSC timestamps
- Sets `front_idle_sent = 1` (send once per present, not every tick)

**front_eid fix:** the PresentPixmap handler now selects the **last active**
registration (non-zero mask) instead of the first. Chrome unregisters old eids
(mask=0) when its GPU process restarts. Using a stale eid causes libxcb to misroute
events to the main queue instead of the special event queue.

### 3. ConfigureWindow support (`x11_server.cc`)

Added resize handling to the existing ConfigureWindow (opcode 12) handler. When
width or height changes, calls `send_resize_events()` which sends ConfigureNotify +
Expose to the window owner. This enables `xdotool windowsize` and programmatic resize.

### 4. Option A resize (`WindowManager.swift` + `DesktopShell.swift`)

**resizeWindow():** updates `win.rect` immediately (frame follows mouse) AND stores
in `targetRect` + `resizeDragEdge` for tracking.

**onWindowBufferResized:** three states:
- During drag (`resizeDragEdge != nil`): suppress rect update from Chrome's buffer,
  just schedule a frame for texture repaint
- Drag ended but Chrome hasn't matched (`targetRect != nil`): update rect to Chrome's
  actual rendered size, clear targetRect when matched
- Normal (no drag): update rect if size changed

**onResizeComplete:** sends final ConfigureNotify on drag end.

### 5. GPU copy helper (`dmabuf_helpers.c`)

`dmabuf_gpu_copy_texture()` — glBlitFramebuffer from src texture to dst texture.
Not currently wired into the Present flow (zero-copy EGLImage bind is used instead)
but available for future copy-before-idle if Chrome buffer reuse races occur.

## Architecture: Event Flow

```
Chrome GPU process                    Our X11 Server                  DRM epoll
─────────────────                    ──────────────                  ─────────
PresentPixmap(pixmap, serial) ──────► on_present_buffer callback
                                      stores fd, marks texture dirty
                                      sets front_idle_sent = 0
                                      (NO events sent here)
                                                                     vblank_tick (16ms):
GetSelectionOwner ──────────────────► x11_server_dispatch()          ◄── timerfd fires
  (blocked in xcb_wait_for_reply)     processes request, sends reply
                                      x11_server_vblank_tick():
  xcb reader wakes up ◄──────────────  sends IdleNotify (32 bytes)
  routes to special event queue        sends CompleteNotify (40 bytes)
  signals eventfd                      triggers shm_fences
                                      flushPendingTextureMarks()
GPU compositor thread wakes ◄──────── eventfd signaled
  submits next frame
```

## Remaining Issues

### Initial GPU process crashes (2 crashes on startup)

Chrome's first and second GPU processes crash during startup. The third one stabilizes.
This is a timing issue: the first PresentSelectInput registration + PresentPixmap +
vblank event delivery race. The eid might not be correctly set for the first vblank
tick. Not blocking — Chrome auto-recovers.

### GPU copy-before-idle (not yet wired)

The `dmabuf_gpu_copy_texture()` helper exists but isn't used in `populateTexture()`.
Currently we bind Chrome's EGLImage directly to the compositor texture (zero-copy).
If Chrome recycles a buffer before our next `populateTexture`, it could overwrite our
texture. In practice this doesn't happen because Chrome uses 3-4 buffers and the
timing works out, but for correctness the GPU copy should be wired in.

The earlier attempt to wire it caused issues because `onBufferCopied` was called from
the raster thread (populateTexture runs there) but X11 server operations must happen
on the epoll thread. A thread-safe queue was implemented but reverted. The correct
approach: queue the release and drain it in `dispatchEvents()`.

## Testing

1. Build: `cd flutter_swift && swift build --product DesktopShellApp`
2. Run: `sudo FLUTTER_DRM_DPI=2 XDG_RUNTIME_DIR=/run/user/1000 FLUTTER_DRM_DEVICE=/dev/dri/card1 FLUTTER_DRM_CONNECTOR=HDMI-A-1 LD_LIBRARY_PATH=../engine/src/out/host_debug .build/debug/DesktopShellApp --drm`
3. Launch Chrome: `sudo DISPLAY=:1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json google-chrome --no-sandbox --disable-gpu-sandbox --user-data-dir=/tmp/chrome_x11 --no-first-run --no-default-browser-check --disable-features=VaapiVideoDecoder,VaapiVideoEncoder --use-angle=vulkan --force-device-scale-factor=2`
4. Drag-resize Chrome's window border
5. Verify: Chrome renders at new size, window frame follows mouse, no GPU crashes after initial startup
