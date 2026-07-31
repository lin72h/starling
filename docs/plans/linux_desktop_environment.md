# Linux Desktop Environment — DRM/KMS Flutter Embedder Plan

## Goal

Build a full Linux desktop environment using Flutter/Swift + Fluent UI, running directly on DRM/KMS (no X11/Wayland dependency). This plan covers Phase 1-3 of the roadmap from `desktop-environment.md`.

## Current State

**What exists:**
- `BlueScreenApp` Linux entry point — headless software renderer, no display output
- `FlutterEmbedderBridge` — Clang module wrapping `embedder.h` for Swift
- `SwiftRuntime` — all 18 engine→Swift callbacks wired (begin_frame, draw_frame, pointer events, etc.)
- Full Flutter widget/rendering framework in Swift
- Fluent UI component library (TreeView, NavigationView, TabView, MenuFlyout, etc.)
- `DesktopShellApp` (macOS) — reference for window management + cross-process compositing

**What's missing:**
- DRM/KMS display output
- GBM buffer allocation
- EGL/GL rendering context
- libinput for keyboard/mouse/touch
- Multi-process compositor (app → compositor buffer sharing)
- Desktop shell UI (taskbar, launcher, wallpaper)

## Dev Environment

- VMware VM, Ubuntu 25.04, kernel 6.14.0
- GPU: VMware SVGA II (`vmwgfx` driver)
- Verified working: GBM, dma-buf export/import, EGL with dma-buf extensions, DRM PRIME
- X11 running (we'll bypass it, go straight to DRM/KMS or run under X11 initially for convenience)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Desktop Shell Process                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐ │
│  │ Flutter/Swift │  │  Window Mgr  │  │   Compositor      │ │
│  │ Widget Tree   │  │  (tiling/    │  │   (EGL/GL comp    │ │
│  │ (Fluent UI)   │  │   floating)  │  │    of all layers) │ │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘ │
│         │                 │                    │             │
│         ▼                 ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              DRM/KMS Backend                            │ │
│  │  GBM device → EGL context → render → page flip          │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              libinput Backend                           │ │
│  │  /dev/input/event* → pointer/keyboard/touch events      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  IPC Server (Unix socket)                            │   │
│  │  App registers → sends dma-buf fd → receives input   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         ▲                                    ▲
         │ dma-buf fd (SCM_RIGHTS)            │ input events
         │                                    │
┌────────┴────────┐                  ┌────────┴────────┐
│  App Process 1  │                  │  App Process 2  │
│  (Flutter/Swift) │                  │  (any app)      │
│  GBM alloc →    │                  │  GBM alloc →    │
│  render → export│                  │  render → export│
└─────────────────┘                  └─────────────────┘
```

---

## Phase 1: DRM/KMS Flutter Embedder (Single Fullscreen App)

### Goal
Replace the headless software renderer with real DRM/KMS display output + libinput. A single Flutter/Swift app renders fullscreen.

### Strategy: Software Renderer + DRM Dumb Buffer (Simplest First)

Rather than jumping to EGL/GL immediately, start with the simplest path that gets pixels on screen:

1. Keep the existing software renderer (`kSoftware` in `FlutterRendererConfig`)
2. Engine renders to CPU pixel buffer (BGRA8888) via `surface_present_callback`
3. Copy pixels to a DRM dumb buffer
4. Page-flip the dumb buffer to the display via KMS

This is intentionally slow (CPU copy) but validates the entire DRM/KMS pipeline before adding GPU acceleration.

### 1.1 — DRM/KMS Backend Module

**New target: `Sources/DRMBackend/`**

```
Sources/DRMBackend/
├── DRMDevice.swift          — Open /dev/dri/card0, enumerate resources
├── DRMConnector.swift       — Find connected outputs, pick best mode
├── DRMMode.swift            — Mode (resolution, refresh rate) wrapper
├── DRMFramebuffer.swift     — Dumb buffer alloc, mmap, addFB, page flip
├── DRMCrtc.swift            — CRTC configuration
└── DRMDisplay.swift         — High-level: init display pipeline, double-buffer flip
```

**Key syscalls (all via Swift `ioctl`/`mmap`):**
```
open("/dev/dri/card0", O_RDWR)
ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, ...)      — enumerate CRTCs, connectors
ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, ...)       — get connector modes
ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, ...)        — allocate dumb buffer
ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, ...)           — get mmap offset
mmap(fd, offset, size)                             — map buffer to userspace
ioctl(fd, DRM_IOCTL_MODE_ADDFB, ...)              — register as framebuffer
ioctl(fd, DRM_IOCTL_MODE_SETCRTC, ...)            — initial mode set
ioctl(fd, DRM_IOCTL_MODE_PAGE_FLIP, ...)          — async page flip (vsync)
```

**C shim needed:** DRM ioctl structs are complex. Create a small C header (`DRMBridgeHeaders/`) that:
- Includes `<xf86drm.h>`, `<xf86drmMode.h>`, `<drm_fourcc.h>`
- Exposes them to Swift via a module map
- May wrap some ioctl calls as simple C functions if Swift struct layout is painful

**Double buffering:**
- Allocate 2 dumb buffers (front + back)
- Software renderer writes to back buffer
- Page flip swaps front/back on vsync
- Use `DRM_EVENT_FLIP_COMPLETE` via `read()` on DRM fd for vsync callback

### 1.2 — libinput Backend Module

**New target: `Sources/InputBackend/`**

```
Sources/InputBackend/
├── InputManager.swift       — Open libinput context, poll for events
├── PointerHandler.swift     — Mouse/touchpad → FlutterPointerEvent
├── KeyboardHandler.swift    — Keyboard → FlutterKeyEvent
└── TouchHandler.swift       — Touchscreen → FlutterPointerEvent (touch)
```

**C shim needed:** `InputBridgeHeaders/` wrapping `<libinput.h>`, `<libudev.h>`

**libinput flow:**
```
udev = udev_new()
li = libinput_udev_create_context(&interface, NULL, udev)
libinput_udev_assign_seat(li, "seat0")
fd = libinput_get_fd(li)

// Poll loop (integrate with RunLoop or epoll):
while (libinput_dispatch(li) == 0) {
    event = libinput_get_event(li)
    switch (libinput_event_get_type(event)) {
        case LIBINPUT_EVENT_POINTER_MOTION: ...
        case LIBINPUT_EVENT_POINTER_BUTTON: ...
        case LIBINPUT_EVENT_KEYBOARD_KEY: ...
        case LIBINPUT_EVENT_TOUCH_DOWN/MOTION/UP: ...
    }
}
```

**Event translation:**
- `LIBINPUT_EVENT_POINTER_MOTION` → `FlutterPointerEvent` with `kMove`/`kHover`
- `LIBINPUT_EVENT_POINTER_BUTTON` → `FlutterPointerEvent` with `kDown`/`kUp`
- `LIBINPUT_EVENT_KEYBOARD_KEY` → `FlutterKeyEvent` with `kFlutterKeyEventTypeDown`/`kFlutterKeyEventTypeUp`
- Need keycode → logical key mapping (use xkbcommon for this)

**Additional C shim:** `<xkbcommon/xkbcommon.h>` for keycode → keysym → UTF-8 translation

### 1.3 — BlueScreenApp Integration

**Modify `Sources/BlueScreenApp/main.swift`** (Linux path):

```swift
// Before:
//   Software renderer → callback logs and returns
//   No input, no display

// After:
//   1. Initialize DRM display
//   2. Initialize libinput
//   3. Software renderer callback → memcpy to DRM dumb buffer → page flip
//   4. libinput events → FlutterEngineSendPointerEvent / FlutterEngineSendKeyEvent
//   5. Integrate both fd's into RunLoop (epoll-based)
```

**Event loop:** Replace `RunLoop.main.run()` with an epoll-based loop that watches:
- DRM fd (page flip completion events)
- libinput fd (input events)
- Engine task runner fd (if applicable — timer-based frame scheduling)

Or use `DispatchSource` on Linux (GCD is available via swift-corelibs-libdispatch):
```swift
let drmSource = DispatchSource.makeReadSource(fileDescriptor: drmFd, queue: .main)
let inputSource = DispatchSource.makeReadSource(fileDescriptor: libinputFd, queue: .main)
```

### 1.4 — Package.swift Changes

```swift
// New Clang module targets (Linux only):
.target(name: "DRMBridgeHeaders",
    path: "Sources/DRMBridgeHeaders",
    cSettings: [.headerSearchPath("include")]
),
.target(name: "InputBridgeHeaders",
    path: "Sources/InputBridgeHeaders",
    cSettings: [.headerSearchPath("include")]
),

// New Swift targets (Linux only):
.target(name: "DRMBackend",
    dependencies: ["DRMBridgeHeaders"],
    linkerSettings: [.linkedLibrary("drm")]
),
.target(name: "InputBackend",
    dependencies: ["InputBridgeHeaders"],
    linkerSettings: [.linkedLibrary("input"), .linkedLibrary("udev"), .linkedLibrary("xkbcommon")]
),

// Update BlueScreenApp dependencies:
.executableTarget(name: "BlueScreenApp",
    dependencies: ["SwiftRuntime", "FlutterEmbedderBridge", "Flutter",
                   "DRMBackend", "InputBackend"],  // ← new
    ...
),
```

### 1.5 — Milestone Deliverable

Running `BlueScreenApp` from a TTY (Ctrl+Alt+F2, no X11):
- Takes over the display via DRM/KMS
- Renders the Fluent UI demo app fullscreen
- Keyboard and mouse input works
- Page flips on vsync (no tearing)
- Clean exit (restores previous CRTC state)

---

## Phase 1.5: GPU-Accelerated Rendering (EGL/GBM)

### Goal
Replace CPU dumb buffers with GPU-rendered GBM buffers. Engine renders directly to GPU memory.

### Strategy: Switch to OpenGL Renderer

Change `FlutterRendererConfig` from `kSoftware` to `kOpenGL`:

**New module: `Sources/EGLBackend/`**
```
Sources/EGLBackend/
├── EGLContext.swift          — GBM device → EGL display → EGL context
├── GBMSurface.swift          — GBM surface for scanout-capable buffers
├── EGLSwapChain.swift        — Lock/release front buffer, DRM page flip
└── GLRendererConfig.swift    — Build FlutterOpenGLRendererConfig callbacks
```

**C shim:** `EGLBridgeHeaders/` wrapping `<EGL/egl.h>`, `<EGL/eglext.h>`, `<gbm.h>`, `<GL/gl.h>`

**FlutterOpenGLRendererConfig callbacks:**
```
make_current       → eglMakeCurrent(display, surface, surface, context)
clear_current      → eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)
fbo_callback       → return 0 (default FBO — renders to GBM surface)
present            → eglSwapBuffers → gbm_surface_lock_front_buffer → DRM page flip
make_resource_current → secondary context for resource loading (optional)
gl_proc_resolver   → eglGetProcAddress
```

**GBM + DRM integration:**
```
gbm_device = gbm_create_device(drm_fd)
gbm_surface = gbm_surface_create(gbm_device, width, height, GBM_FORMAT_XRGB8888, GBM_BO_USE_SCANOUT | GBM_BO_USE_RENDERING)
egl_display = eglGetPlatformDisplay(EGL_PLATFORM_GBM_MESA, gbm_device, NULL)
egl_surface = eglCreateWindowSurface(egl_display, config, gbm_surface, NULL)

// After eglSwapBuffers:
bo = gbm_surface_lock_front_buffer(gbm_surface)
handle = gbm_bo_get_handle(bo).u32
drmModeAddFB(drm_fd, width, height, 24, 32, stride, handle, &fb_id)
drmModePageFlip(drm_fd, crtc_id, fb_id, DRM_MODE_PAGE_FLIP_EVENT, NULL)
// On flip complete: gbm_surface_release_buffer(gbm_surface, bo)
```

### Milestone Deliverable
Same as Phase 1 but GPU-accelerated. Noticeably smoother, lower CPU usage.

---

## Phase 2: Multi-Process Compositor

### Goal
The desktop shell becomes a compositor that can display multiple app windows, each running in its own process with its own Flutter/Swift instance.

### 2.1 — IPC Protocol

**New target: `Sources/CompositorProtocol/`**

Define a simple binary protocol over Unix domain sockets:

```
Message format: [u32 type][u32 length][payload...]

Client → Compositor:
  REGISTER        — New app, sends app_id, requested size
  BUFFER_COMMIT   — Sends dma-buf fd (via SCM_RIGHTS), size, format,
                    with damage rects
  RESIZE_ACK      — Acknowledges resize, sends new buffer
  CLOSE           — App closing

Compositor → Client:
  REGISTERED      — Confirms, assigns window_id, actual size
  RESIZE          — Compositor resized window, new dimensions
  INPUT_POINTER   — Pointer event (x, y, buttons, relative to window)
  INPUT_KEY       — Key event (keycode, state, modifiers)
  FOCUS           — Window gained/lost focus
  CLOSE_REQUEST   — User clicked X, app should save and close
```

**dma-buf sharing (the core mechanism):**
```
// Client side:
gbm_bo = gbm_bo_create(gbm_device, w, h, GBM_FORMAT_ARGB8888, GBM_BO_USE_RENDERING)
dmabuf_fd = gbm_bo_get_fd(gbm_bo)
sendmsg(socket_fd, &msg, 0)  // msg contains SCM_RIGHTS with dmabuf_fd

// Compositor side:
recvmsg(socket_fd, &msg, 0)  // extracts dmabuf_fd from SCM_RIGHTS
EGLImage image = eglCreateImage(display, EGL_NO_CONTEXT,
    EGL_LINUX_DMA_BUF_EXT, NULL, attribs)  // attribs include fd, stride, format
glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, image)  // bind as GL texture
// Now compositor can render this texture in its scene
```

### 2.2 — Compositor Core

**New target: `Sources/Compositor/`**

```
Sources/Compositor/
├── CompositorServer.swift    — Unix socket server, accept clients
├── WindowState.swift         — Per-window: position, size, z-order, focus, dma-buf texture
├── SceneGraph.swift          — Ordered list of windows + decorations
├── GLCompositor.swift        — EGL context that composites all window textures
│                               onto a single fullscreen surface → DRM page flip
├── InputRouter.swift         — Route libinput events to focused window via IPC
└── CursorRenderer.swift      — Hardware cursor via DRM_IOCTL_MODE_CURSOR, or software cursor
```

**Compositing loop (each vsync):**
```
1. For each window (back to front):
   a. Bind window's dma-buf texture
   b. Draw textured quad at window's position/size
   c. Draw window decoration (title bar, borders) if not CSD
2. Draw cursor
3. eglSwapBuffers → page flip
```

### 2.3 — App Client Library

**New target: `Sources/CompositorClient/`**

Library that apps link against instead of raw DRM/EGL:

```
Sources/CompositorClient/
├── ClientConnection.swift    — Connect to compositor socket, send/receive messages
├── ClientSurface.swift       — GBM buffer allocation, dma-buf export, double buffering
├── ClientInputReceiver.swift — Receive input events from compositor, translate to Flutter events
└── FlutterClientEmbedder.swift — Wires Flutter engine to compositor client
                                  (replaces DRM backend with compositor client)
```

**App lifecycle:**
```swift
let client = CompositorClient()
client.connect("/run/flutter-compositor.sock")
client.register(appId: "file-manager", requestedSize: Size(800, 600))

// Flutter engine uses client's GBM buffer as render target
// On each frame: render → client.commitBuffer(dmabufFd, damage)
// Input arrives via client socket → FlutterEngineSendPointerEvent/KeyEvent
```

### Milestone Deliverable
Desktop shell process composites 2+ Flutter/Swift app windows. Each app is a separate process. Mouse clicks route to the correct window. Windows can be moved/resized.

---

## Phase 3: Desktop Shell UI

### Goal
Build the actual desktop shell UI using Fluent UI components.

### 3.1 — Shell Components

These are Flutter/Swift widgets rendered by the compositor's own Flutter instance:

```
Sources/DesktopShell/
├── ShellApp.swift            — Root widget, manages shell layout
├── Taskbar/
│   ├── TaskbarWidget.swift   — Bottom bar with start button, running apps, system tray
│   ├── StartMenu.swift       — App launcher grid (reads .desktop files)
│   ├── TaskbarButton.swift   — Per-app button with icon + label
│   └── SystemTray.swift      — Clock, network, volume, battery indicators
├── Desktop/
│   ├── DesktopWidget.swift   — Wallpaper + desktop icons
│   └── DesktopIcon.swift     — Clickable icon that launches apps
├── WindowChrome/
│   ├── TitleBar.swift        — Window title bar (rendered by compositor over each window)
│   ├── ResizeHandle.swift    — Drag-to-resize edges/corners
│   └── WindowShadow.swift    — Drop shadow behind windows
├── Notifications/
│   └── NotificationCenter.swift — Toast notifications (using InfoBar)
└── Settings/
    └── DisplaySettings.swift — Resolution, refresh rate, multi-monitor
```

### 3.2 — D-Bus Integration

**New target: `Sources/DBusClient/`**

Minimal D-Bus client for system service communication:
- **NetworkManager** — WiFi/Ethernet status for system tray
- **PipeWire/PulseAudio** — Volume control
- **UPower** — Battery status (laptop)
- **logind** — Session management, screen lock
- **Notifications** — `org.freedesktop.Notifications` daemon

Can use raw Unix socket + D-Bus wire protocol, or link `libdbus-1`.

### 3.3 — XDG Compliance

- Read `.desktop` files from `/usr/share/applications/` for app launcher
- Follow XDG base directory spec for config/data paths
- MIME type associations for file manager
- Autostart entries from `~/.config/autostart/`

### Milestone Deliverable
A functional desktop with taskbar, app launcher, window decorations, and system tray indicators. Can launch Flutter/Swift apps and manage their windows.

---

## Implementation Order

```
Step 1:  DRMBridgeHeaders + DRMBackend        — get pixels on screen
Step 2:  InputBridgeHeaders + InputBackend     — get input working
Step 3:  BlueScreenApp integration             — fullscreen Flutter app on DRM
Step 4:  EGLBridgeHeaders + EGLBackend         — GPU acceleration
Step 5:  CompositorProtocol                    — IPC message definitions
Step 6:  Compositor + CompositorClient         — multi-window compositing
Step 7:  DesktopShell widgets                  — taskbar, launcher, window chrome
Step 8:  DBusClient                            — system service integration
```

### Detailed Sub-Plans

| Step | Plan File | Status |
|------|-----------|--------|
| Step 1 | [step1_drm_backend.md](step1_drm_backend.md) | Planned |
| Step 2 | [step2_input_backend.md](step2_input_backend.md) | Planned |
| Step 3 | [step3_flutter_integration.md](step3_flutter_integration.md) | Planned |
| Step 4 | step4_egl_gpu.md | Not yet planned |
| Step 5 | step5_compositor_protocol.md | Not yet planned |
| Step 6 | step6_compositor.md | Not yet planned |
| Step 7 | step7_desktop_shell.md | Not yet planned |
| Step 8 | step8_dbus.md | Not yet planned |

## Development Approach

### VMware Considerations
- Start with **software renderer + dumb buffers** (Phase 1) — guaranteed to work on vmwgfx
- Test DRM/KMS from TTY initially (`sudo chvt 2` then run app)
- Can also test under X11 using a secondary DRM render node if available
- GPU path (Phase 1.5) should work since GBM + EGL verified working on the VM

### Testing Without Leaving X11
For convenience during development, consider an intermediate step:
- Use `DISPLAY=:0` with a simple X11 window instead of DRM for rapid iteration
- Factor out the "display output" interface so DRM vs X11 is swappable
- Keep DRM as the target, but X11 as a development convenience backend

### Key Libraries to Install on VM
```bash
sudo apt install libdrm-dev libgbm-dev libegl-dev libgl-dev \
    libinput-dev libudev-dev libxkbcommon-dev \
    mesa-utils vulkan-tools libinput-tools
```

## Design Decisions (Resolved)

1. **Server-side decorations (SSD) first.** Compositor draws title bars, borders, shadows. Gives consistent Fluent UI look across all windows. CSD support added later when Wayland compat layer arrives (Phase 6). Precedent: macOS DesktopShellApp already renders window chrome server-side.

2. **Floating WM first, with snap-to-edge.** Matches Fluent UI / Windows aesthetic. Simpler hit-testing (z-ordered rectangles). Tiling zones (PowerToys FancyZones style — drag to edge snaps half/quarter) added later as an enhancement.

3. **Well-known socket path for app discovery.** Compositor listens on `$XDG_RUNTIME_DIR/flutter-compositor.sock` (same convention as Wayland's `$WAYLAND_DISPLAY`). Apps auto-discover on connect. Shell Start Menu launches apps via `Process()` (Swift Foundation). Launcher daemon deferred to later for .desktop parsing, single-instance enforcement, sandboxing.

4. **Hardware cursor, software fallback.** Hardware cursor via `DRM_IOCTL_MODE_CURSOR` + `drmModeMoveCursor()` — moves at scanout speed, not frame rate. 64x64 sufficient for standard cursors. Software fallback for animated cursors, oversized cursors, or when hardware plane unavailable.

5. **Single output first, abstraction-ready.** `DRMDisplay` models one output (connector + CRTC + framebuffer) as a class — trivial to instantiate multiple later. Compositor scene graph uses absolute coordinates from day one (no 0,0 origin assumption). Multi-monitor compositing deferred to Phase 2+.
