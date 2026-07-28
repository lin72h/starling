# DesktopShellApp — Testing & Integration

## Taskbar Icon Positions

Taskbar height is 48px. Icons are 44px wide. Start button (44px) + divider (1px) + icons (44px each): Settings, Files, Text Viewer, External App, Flutter App.

```
                  1280x800      1920x1080     4096x2160
Start button:     x~25 y~775   x~25 y~1055   x~25 y~2135
Settings icon:    x~67 y~775   x~67 y~1055   x~67 y~2135
Flutter App icon: x~243 y~775  x~243 y~1055  x~243 y~2135
```

## Testing DRM Mode (Sending Events & Screenshots)

In DRM mode there is no X11/Wayland, so you can't use `xdotool` or similar.

### Taking screenshots (drm_screenshot tool)

Standalone tool that captures the active DRM framebuffer by importing the scanout buffer's DMA-BUF fd via EGL. Works independently of the running app — no SIGUSR1 needed.

```bash
# Build (once)
cd flutter_swift/tools
make

# Prerequisites
sudo apt install libdrm-dev libgbm-dev libegl-dev libgles-dev

# Capture
sudo ./drm_screenshot /dev/dri/card1 /tmp/screenshot.ppm
convert /tmp/screenshot.ppm /tmp/screenshot.png  # ImageMagick
```

### Injecting mouse events (relative mouse via evdev)

Find the mouse device, then write relative evdev events. Requires `sudo`.

```bash
# Find the mouse device
for d in /dev/input/event*; do echo "$d: $(cat /sys/class/input/$(basename $d)/device/name 2>/dev/null)"; done
# Look for "USB Optical Mouse" or similar — e.g. /dev/input/event6
```

```python
#!/usr/bin/env python3
"""Click at a screen position using relative mouse moves via evdev."""
import struct, time, os

EV_SYN, EV_KEY, EV_REL = 0, 1, 2
SYN_REPORT, REL_X, REL_Y, BTN_LEFT = 0, 0, 1, 0x110
DEVICE = '/dev/input/event6'  # Adjust to your mouse device

def ev(etype, code, value):
    t = time.time()
    return struct.pack('llHHi', int(t), int((t % 1) * 1e6), etype, code, value)

def syn():
    return ev(EV_SYN, SYN_REPORT, 0)

fd = os.open(DEVICE, os.O_WRONLY)

# Move to bottom-left corner (large negative move to reset position)
os.write(fd, ev(EV_REL, REL_X, -3000))
os.write(fd, ev(EV_REL, REL_Y, 3000))
os.write(fd, syn())
time.sleep(0.1)

# Move to target (relative from 0,1080 for 1920x1080 display)
target_x, target_y = 20, 1058
os.write(fd, ev(EV_REL, REL_X, target_x))
os.write(fd, ev(EV_REL, REL_Y, -(1080 - target_y)))
os.write(fd, syn())
time.sleep(0.1)

# Click
os.write(fd, ev(EV_KEY, BTN_LEFT, 1))
os.write(fd, syn())
time.sleep(0.05)
os.write(fd, ev(EV_KEY, BTN_LEFT, 0))
os.write(fd, syn())

os.close(fd)
```

### Taking screenshots (SIGUSR1 — in-app, requires active frame)

Send `SIGUSR1` to the app process. The next `present()` call captures via `glReadPixels` and saves to `/tmp/drm_screenshot_N.ppm`. Only works if a frame is being rendered (e.g. during animation or after input). For idle screenshots, use `drm_screenshot` instead.

```bash
PID=$(pgrep -x DesktopShellApp | head -1)
sudo kill -USR1 $PID
sleep 2
convert /tmp/drm_screenshot_0.ppm /tmp/screenshot.png  # ImageMagick
```

### Measuring Text Sharpness

Use `flutter_swift/test_sharpness.py` to quantitatively compare text rendering quality:
```bash
# Analyze a screenshot region
python3 test_sharpness.py /tmp/screenshot.png 300x100+160+55

# Compare two screenshots (e.g. different DPI settings)
python3 test_sharpness.py /tmp/crop_a.png /tmp/crop_b.png
```

Metrics: Laplacian variance (sharp > 500, blurry < 100), edge gradient mean, high-frequency energy ratio.

### VMware DRM Mode Notes

- VMware SVGA II adapter (`vmwgfx` driver) supports up to 4096x2160 and 8 virtual connectors.
- The **preferred DRM mode** is set dynamically by VMware based on the X11 session resolution at the time lightdm was running. To get a specific preferred mode, set the X11 resolution via `xrandr` before stopping lightdm, or use `FLUTTER_DRM_MODE` to override.
- VMware does NOT offer 3840x2160 as a built-in mode. Available 4K mode is 4096x2160. Custom modes via `xrandr --newmode` are not accepted by the VMware SVGA driver.
- GBM scanout buffers (GPU-allocated) cannot be mapped via `DRM_IOCTL_MODE_MAP_DUMB`, so `/dev/fb0` and dumb buffer mapping do not capture the DRM output. Use SIGUSR1 screenshots (`glReadPixels`) or the `drm_screenshot` tool instead.
- `ffmpeg -f kmsgrab` does not work with VMware SVGA (no DMA-BUF export on scanout buffers).

### AMD GPU DRM Mode Notes

- AMD GPUs (`amdgpu` driver) typically use `/dev/dri/card1` (not `card0`). Set `FLUTTER_DRM_DEVICE=/dev/dri/card1`.
- HDMI output supports 3840x2160@30Hz and 1920x1080@60Hz. Use 1920x1080 for best performance — 4K causes slow frame rates with CPU-rendered child apps (Settings, etc.) due to `glTexImage2D` pixel upload bottleneck.
- EGL on AMD returns 10-bit color configs (R10G10B10A2) before 8-bit configs. The EGL init iterates configs to find R8G8B8 matching `GBM_FORMAT_XRGB8888`. Without this fix, `eglCreateWindowSurface` fails.
- `XDG_RUNTIME_DIR` must be set explicitly under `sudo` for Wayland server socket creation (e.g. `XDG_RUNTIME_DIR=/run/user/1000`).

## Testing Wayland Clients

DesktopShellApp runs a Wayland compositor server (listening on `wayland-0`). External Wayland clients can connect and be composited as windows.

**Prerequisites:**
```bash
sudo apt install weston
```

**Launch a DMA-BUF EGL client** (GPU zero-copy, recommended):
```bash
sudo WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 weston-simple-dmabuf-egl
```

**Launch a SHM client** (CPU pixel upload):
```bash
sudo WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 weston-flower
```

**Launch Google Chrome** (GPU DMA-BUF):
```bash
sudo WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 google-chrome --ozone-platform=wayland --no-sandbox --disable-gpu-sandbox
```
Add `--user-data-dir=/tmp/chrome_test` for a clean profile, or `--disable-gpu` to force software rendering (SHM path).

**Notes:**
- `weston-simple-egl` may fail on AMD with "failed to get driver name" — use `weston-simple-dmabuf-egl` instead.
- Clients must run as `sudo` since the Wayland socket is owned by root (DesktopShellApp runs as root for DRM master).
- Available test clients: `weston-flower`, `weston-simple-dmabuf-egl`, `weston-simple-shm`, `weston-editor`, `weston-terminal`, `weston-clickdot`, `weston-smoke`, `weston-resizor`, `weston-stacking`.

### Wayland Buffer Scale and Window Sizing

The Wayland compositor tracks per-surface `buffer_scale` (set by clients via `wl_surface.set_buffer_scale`). This is critical for HiDPI clients like Chrome.

**How it works:**
- The output advertises physical resolution + scale (e.g. 3840x2160 with scale=2 -> clients see 1920x1080 logical).
- `xdg_toplevel.configure(width, height)` sends dimensions in surface-local (logical) coordinates.
- HiDPI clients render buffers at `width*scale x height*scale` pixels and call `set_buffer_scale(scale)`.
- On commit, `wayland_compositor.c` applies the pending buffer_scale and passes it to the Swift callback.
- `WaylandIntegration.swift` divides buffer dimensions by the client's `buffer_scale` (NOT the global output scale) to get logical window size.
- Chrome with DPI=2 sends `set_buffer_scale(2)` and renders at 2x. Buffer 1264x820 -> logical 632x410.

**Window resize on first commit:** `handleSurfaceCommit` must trigger `onWindowBufferResized` on the first commit (when `prevSize` is nil), not only on subsequent size changes. Without this, the window stays at `kDefaultWindowWidth x kDefaultWindowHeight` regardless of the client's actual buffer size, causing the texture to stretch to fill the wrong-sized window. Chrome's sign-in dialog renders a 1240x1240 square buffer — if the window isn't resized to match, the square content gets stretched into the default rectangular window.

**Key files:**
- `wayland_compositor.c`: `surface_set_buffer_scale()` stores pending scale, `surface_commit()` applies it and passes to callbacks.
- `wayland_server_internal.h`: `WaylandSurface.buffer_scale` (committed) and `pending.buffer_scale` fields.
- `wayland_server.h`: `wl_on_surface_commit` and `wl_on_shm_surface_commit` callbacks include `buffer_scale` parameter.
- `WaylandIntegration.swift`: `surfaceBufferScales` dict tracks per-surface scale, used in `handleSurfaceCommit`/`handleShmSurfaceCommit`.

### Wayland Keyboard Input Forwarding

Keyboard events are forwarded from the DRM shell to Wayland clients via the Flutter framework's key data system, using the same direct-callback pattern as pointer events.

**Data flow:**
1. libinput -> `FlDrmInput::HandleKeyboard` -> `FlutterEngineSendKeyEvent` (sends to engine)
2. Engine posts "flutter/keydata" platform message to UI task runner
3. `SwiftRuntimeController::DispatchPlatformMessage` intercepts "flutter/keydata" and calls `dispatch_key_data` callback directly (bypasses channelBuffers)
4. Swift `dispatchKeyData` -> `KeyData.fromPacket()` deserializes binary packet -> calls `pd.onKeyData`
5. `DesktopShell._setupWaylandCallbacks` sets `pd.onKeyData` to forward to focused Wayland window
6. `WaylandIntegration.sendKeyEvent` converts HID->evdev keycode and sends via `wayland_server_keyboard_key`

**Why direct callback (not channelBuffers):** In DRM mode, the engine's UI task runner is a separate thread (`io.flutter.ui`), not the main thread. `channelBuffers` is `@MainActor`-isolated, so calling it from the UI thread triggers `MainActor.assumeIsolated` -> `dispatch_assert_queue_fail` -> SIGILL crash. The direct callback pattern (same as `dispatch_pointer_data_packet`) avoids this by not going through channelBuffers at all.

**HID->evdev key code conversion:** The engine converts evdev->USB HID in `FlDrmInput::EvdevToHID`. Wayland clients expect evdev keycodes, so `WaylandIntegration.hidToEvdev()` reverses the mapping. Unmapped keys have `0x100000000` flag — strip it to get the original evdev code.

**Key files:**
- `swift_runtime_callbacks.h`: `dispatch_key_data` callback declaration (alongside `dispatch_pointer_data_packet`)
- `swift_runtime_controller.cc`: Intercepts "flutter/keydata" in `DispatchPlatformMessage`, calls `dispatch_key_data` directly
- `SwiftRuntimeCallbackTable.swift`: Wires `dispatch_key_data` C callback to `SwiftRuntimeDelegate.dispatchKeyData`
- `SwiftRuntimeDelegate.swift`: `dispatchKeyData()` calls `pd.onKeyData` with deserialized `KeyData`
- `Key.swift`: `KeyData.fromPacket()` deserializes binary key data packet
- `DesktopShell.swift`: `pd.onKeyData` handler forwards to focused Wayland window
- `WaylandIntegration.swift`: `sendKeyEvent()` with `hidToEvdev()` reverse mapping, auto keyboard_enter/leave on focus change

## Testing X11 Clients

DesktopShellApp runs an X11 server on `:1` (via `X11Server/x11_server.c`). External X11 clients connect and are composited as windows. Supports hardware-accelerated OpenGL 4.6 via DRI3 direct rendering.

**Test basic connectivity:**
```bash
sudo DISPLAY=:1 xdpyinfo | head -10
sudo DISPLAY=:1 glxinfo | head -10
```

**Test GLX rendering (DRI3):**
```bash
sudo DISPLAY=:1 glxgears    # ~10K FPS on AMD Radeon 780M
sudo DISPLAY=:1 xclock       # Simple Xt widget rendering
```

**Launch Google Chrome (X11, Vulkan GPU rendering):**
```bash
sudo DISPLAY=:1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json \
    google-chrome --no-sandbox --disable-gpu-sandbox \
    --user-data-dir=/tmp/chrome_x11 \
    --no-first-run --no-default-browser-check \
    --disable-features=VaapiVideoDecoder,VaapiVideoEncoder \
    --use-angle=vulkan --force-device-scale-factor=2
```

**Notes:**
- Clients must run as `sudo` since the X11 socket is owned by root (DesktopShellApp runs as root for DRM master).
- Chrome needs `--no-sandbox --disable-gpu-sandbox` because the X11 socket is root-owned.
- Chrome opens many concurrent X11 connections — listen backlog must be >=32.
- Chrome sends >64KB during initial setup — `CLIENT_BUF_SIZE` must be >=256KB.

### X11 Server Implementation Notes

**Protocol opcode numbering:** GLX minor opcodes follow `/usr/include/GL/glxproto.h`. RandR minor opcodes follow `/usr/include/xcb/randr.h` (XCB numbering, NOT old Xlib numbering). Always verify against the system headers — Xlib and XCB use DIFFERENT numbering for the same operations.

**Critical GLX FBConfig attribute codes:**
- `0x8010` = `GLX_DRAWABLE_TYPE` (NOT RENDER_TYPE)
- `0x8011` = `GLX_RENDER_TYPE` (NOT CONFIG_CAVEAT)
- `0x8012` = `GLX_X_RENDERABLE` (NOT DRAWABLE_TYPE)
- Mesa DRI3 GLX does EXACT matching of depth/stencil values. Provide FBConfigs for D=0/S=0, D=16/S=0, D=24/S=0, D=24/S=8 to cover all driver configs.

**Event sequence numbers:** X11 events MUST carry the current `client->sequence` at bytes 2-3. Setting seq=0 breaks XCB reply interleaving, causing "fatal IO error 11 (EAGAIN)" for DRI3 clients.

**FD queue for SCM_RIGHTS:** DRI3 operations (PixmapFromBuffer + FenceFromFD) may batch multiple fds in a single `recvmsg`. Use a queue (`pending_fds[8]` + `pending_fd_count`) not a single `pending_fd`, or the DMA-BUF fd gets swapped with the fence fd.

**Swift callbacks in DRM mode:** Do NOT use `print()` inside C callback closures called from the DRM epoll thread — `stdout` may have no reader in DRM mode, causing `print()` to block forever and hang the event loop. Use `fputs(stderr, ...)` from C or avoid logging.

**EWMH properties:** The root window must have `_NET_SUPPORTED`, `_NET_WORKAREA`, `_NET_SUPPORTING_WM_CHECK`, `_NET_NUMBER_OF_DESKTOPS`, and `_NET_CURRENT_DESKTOP` properties set during server initialization. Chrome queries these to determine window manager support and display bounds.

## Nav Item Positions (BlueScreenApp, all expanders collapsed)

```
Home:               x=150, y~19
Basic Controls:     x=150, y~71   (expander)
Surfaces:           x=150, y~111  (expander)
Navigation:         x=150, y~151  (expander)
Popups:             x=150, y~191  (expander)
Pickers:            x=150, y~231
```

When an expander opens, each sub-item is ~40px tall and all items below shift down accordingly.
