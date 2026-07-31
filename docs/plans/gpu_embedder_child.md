# GPU Embedder Child Process

## Context

The DMA-BUF cross-process compositing currently uses a **CPU rasterization pipeline** in the child:

```
Child (FlutterDemoApp):
  BuildOwner → PipelineOwner → Paint → PictureLayer
  → toImageSync (Skia CPU raster)
  → toByteData (RGBA bytes in RAM)
  → gbm_bo_map + memcpy (CPU copy to GPU memory)
  → signal parent via socket

Parent (DesktopShellApp):
  receive DMA-BUF fd → eglCreateImageKHR → GL texture (zero-copy)
```

This has **1 CPU copy** (child-side Skia CPU → GBM BO) plus a full CPU rasterization pass. The engine is started in `kSoftware` mode just to initialize Skia; the child manages its own widget tree manually via a separate BuildOwner/PipelineOwner (DmaBufRenderer).

## Goal

Replace the CPU pipeline with a **full GPU embedder**. The child runs the Flutter engine with `kOpenGL` renderer, Skia GPU renders directly into an offscreen FBO backed by a GBM buffer object (via EGLImage). The parent imports the same DMA-BUF fd for zero-copy GPU texture sharing.

```
Child (FlutterDemoApp):
  Flutter Engine (kOpenGL, Skia GPU)
  → renders to offscreen FBO
  → FBO color attachment = GL texture backed by GBM BO (via EGLImage)
  → glFinish() + signal parent via socket
  0 CPU copies, full GPU acceleration

Parent (DesktopShellApp):
  receive DMA-BUF fd → eglCreateImageKHR → GL texture (zero-copy, unchanged)
```

**Result: 0 CPU copies.** Skia GPU renders directly into shared GPU memory.

---

## Step 1: Add EGL/GL Helper Functions to DmaBufBridge

Add C helper functions for EGL context management and FBO creation. These wrap EGL/GL calls that are hard to use directly from Swift (function pointer loading, enum constants).

**Modify:** `flutter_swift/Sources/DmaBufBridge/include/DmaBufBridge.h`

Add declarations:
```c
// ─── EGL context management (headless, render node) ─────────────────────

/// Create an EGL display from a GBM device (GBM_MESA platform).
/// Returns EGLDisplay, or NULL on failure.
void* dmabuf_egl_create_display(struct gbm_device* gbm_dev);

/// Initialize EGL display. Returns 1 on success, 0 on failure.
int dmabuf_egl_initialize(void* egl_display);

/// Choose an EGL config suitable for offscreen Skia rendering.
/// Requires GLES2, stencil=8, RGBA8888. Returns config, or NULL.
void* dmabuf_egl_choose_config(void* egl_display);

/// Create an EGL context (GLES2). If share_context is non-NULL, resources
/// are shared (needed for resource context). Returns context, or NULL.
void* dmabuf_egl_create_context(void* egl_display, void* config,
                                void* share_context);

/// Make context current with no surface (surfaceless rendering).
int dmabuf_egl_make_current(void* egl_display, void* context);

/// Clear (unbind) the current context.
int dmabuf_egl_clear_current(void* egl_display);

/// Call eglGetProcAddress. Returns function pointer.
void* dmabuf_egl_get_proc_address(const char* name);

/// Call glFinish (ensure GPU commands complete).
void dmabuf_gl_finish(void);

// ─── Offscreen FBO backed by GBM BO ────────────────────────────────────

/// Create an offscreen FBO with:
///   - Color attachment: GL texture backed by GBM BO (via EGLImage from DMA-BUF fd)
///   - Stencil attachment: renderbuffer (GL_STENCIL_INDEX8)
/// Returns FBO name on success, 0 on failure.
/// |out_egl_image| receives the EGLImage handle (caller must destroy).
/// |out_color_tex| receives the GL texture name.
/// |out_stencil_rb| receives the stencil renderbuffer name.
uint32_t dmabuf_create_fbo(void* egl_display, int dma_fd,
                           int width, int height, int stride,
                           uint32_t fourcc,
                           void** out_egl_image,
                           uint32_t* out_color_tex,
                           uint32_t* out_stencil_rb);

/// Destroy FBO and associated GL/EGL resources.
void dmabuf_destroy_fbo(void* egl_display, uint32_t fbo,
                        void* egl_image, uint32_t color_tex,
                        uint32_t stencil_rb);
```

**Modify:** `flutter_swift/Sources/DmaBufBridge/dmabuf_helpers.c`

Implement all functions above. Key implementation details:

- `dmabuf_egl_create_display`: Try `eglGetPlatformDisplayEXT(EGL_PLATFORM_GBM_MESA, ...)` first, fall back to `eglGetDisplay()`. Same pattern as `fl_drm_egl.cc:39-52`.
- `dmabuf_egl_choose_config`: Use `EGL_SURFACE_TYPE=0` (surfaceless — no window or pbuffer), `EGL_RENDERABLE_TYPE=EGL_OPENGL_ES2_BIT`, `EGL_STENCIL_SIZE=8`, RGBA 8888. If surfaceless config fails, try `EGL_SURFACE_TYPE=EGL_PBUFFER_BIT` as fallback.
- `dmabuf_egl_make_current`: `eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context)`.
- `dmabuf_create_fbo`:
  1. Import DMA-BUF fd as EGLImage via `eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, ...)` (reuse existing `dmabuf_import_egl_image` logic).
  2. `glGenTextures` → `glBindTexture(GL_TEXTURE_2D)` → `glEGLImageTargetTexture2DOES` to back texture with GBM BO.
  3. `glGenRenderbuffers` → `glBindRenderbuffer` → `glRenderbufferStorage(GL_STENCIL_INDEX8, w, h)`.
  4. `glGenFramebuffers` → `glBindFramebuffer` → `glFramebufferTexture2D(COLOR0)` → `glFramebufferRenderbuffer(STENCIL)`.
  5. `glCheckFramebufferStatus` must return `GL_FRAMEBUFFER_COMPLETE`.
  6. Unbind FBO, return FBO name.

---

## Step 2: Create `GpuDmaBufRenderer` (Replace DmaBufRenderer)

New file that replaces the manual BuildOwner/PipelineOwner pipeline with a full Flutter embedder running Skia GPU.

**Create:** `flutter_swift/Sources/FlutterDemoApp/GpuDmaBufRenderer.swift`

This is a self-contained class that:
1. Sets up EGL on the render node
2. Creates a GBM BO and offscreen FBO
3. Configures and runs a Flutter embedder with `kOpenGL`
4. Uses `runApp()` (Adapter-driven pipeline) for widget management
5. Signals the parent on each present

### Initialization

```swift
class GpuDmaBufRenderer {
    // EGL state
    private let renderFd: Int32
    private let gbmDevice: OpaquePointer
    private let gbmBo: OpaquePointer
    private let dmaFd: Int32
    private let stride: Int32

    // EGL context
    private let eglDisplay: OpaquePointer
    private let eglConfig: OpaquePointer
    private let mainContext: OpaquePointer
    private let resourceContext: OpaquePointer

    // FBO
    private let fboName: UInt32
    private let fboEglImage: OpaquePointer
    private let fboColorTex: UInt32
    private let fboStencilRb: UInt32

    // Socket to parent
    private let socketFd: Int32

    // Engine
    private(set) var engine: OpaquePointer?

    let width: Int
    let height: Int
}
```

**Init sequence:**

1. Open `/dev/dri/renderD128`, create GBM device.
2. Create GBM BO: `gbm_bo_create(dev, w, h, GBM_FORMAT_ABGR8888, GBM_BO_USE_LINEAR | GBM_BO_USE_RENDERING)`.
3. Get DMA-BUF fd: `gbm_bo_get_fd(bo)`, stride: `gbm_bo_get_stride(bo)`.
4. Create EGL display: `dmabuf_egl_create_display(gbmDevice)`.
5. Initialize EGL: `dmabuf_egl_initialize(eglDisplay)`.
6. Choose config: `dmabuf_egl_choose_config(eglDisplay)`.
7. Create main context: `dmabuf_egl_create_context(eglDisplay, config, nil)`.
8. Create resource context: `dmabuf_egl_create_context(eglDisplay, config, mainContext)`.
9. Make main context current: `dmabuf_egl_make_current(eglDisplay, mainContext)`.
10. Create FBO: `dmabuf_create_fbo(eglDisplay, dmaFd, w, h, stride, fourcc, ...)`.
11. Clear current: `dmabuf_egl_clear_current(eglDisplay)`.
12. Connect to parent socket, send DMA-BUF metadata + fd (same as current DmaBufRenderer).

**Failable init** — returns nil if any step fails, caller falls back to CPU DmaBufRenderer then ShmRenderer.

### Embedder Configuration

Configure `FlutterRendererConfig` with `kOpenGL`:

```swift
rendererConfig.type = kOpenGL
rendererConfig.open_gl.struct_size = MemoryLayout<FlutterOpenGLRendererConfig>.size

rendererConfig.open_gl.make_current = { userData -> Bool in
    let r = extractRenderer(userData)
    return dmabuf_egl_make_current(r.eglDisplay, r.mainContext) != 0
}

rendererConfig.open_gl.clear_current = { userData -> Bool in
    let r = extractRenderer(userData)
    return dmabuf_egl_clear_current(r.eglDisplay) != 0
}

rendererConfig.open_gl.present = { userData -> Bool in
    let r = extractRenderer(userData)
    dmabuf_gl_finish()  // Ensure GPU is done before signaling parent
    var signal: UInt8 = 0x46  // 'F'
    _ = Glibc.write(r.socketFd, &signal, 1)
    return true
}

rendererConfig.open_gl.fbo_callback = { userData -> UInt32 in
    let r = extractRenderer(userData)
    return r.fboName  // Custom FBO backed by GBM BO
}

rendererConfig.open_gl.make_resource_current = { userData -> Bool in
    let r = extractRenderer(userData)
    return dmabuf_egl_make_current(r.eglDisplay, r.resourceContext) != 0
}

rendererConfig.open_gl.gl_proc_resolver = { _, name -> UnsafeMutableRawPointer? in
    guard let name = name else { return nil }
    return dmabuf_egl_get_proc_address(name)
}

rendererConfig.open_gl.fbo_reset_after_present = false  // Same FBO every frame
```

### Engine Initialization

Follow BlueScreenApp GLFW pattern:

1. Create runtime callbacks: `createRuntimeCallbacks()`.
2. Set up `FlutterProjectArgs` (assets_path, icu_data_path, command line args including `--enable-impeller=false`).
3. Set up `FlutterTaskRunnerDescription` + `FlutterCustomTaskRunners` (task queue with pthread-based thread check).
4. Call `FlutterEngineInitializeSwift(...)` with the OpenGL renderer config.
5. Call `FlutterEngineRunInitializedSwift(engine)`.
6. Send `FlutterWindowMetricsEvent` with the renderer's width/height.

### Widget Mounting

Use `runApp()` from Adapter.swift — the engine drives the frame loop:

```swift
func mountWidget(_ builder: () -> Widget) {
    runApp(builder())
}
```

This wires up `onBeginFrame`/`onDrawFrame` callbacks. The engine's vsync drives the build/layout/paint/composite pipeline, and Skia GPU rasterizes to the FBO automatically.

### Event Loop

Use the same pattern as BlueScreenApp GLFW mode, minus the GLFW event polling:

```swift
func run() {
    PlatformDispatcher.instance.scheduleFrame()
    // Drain engine tasks + spin Foundation.RunLoop
    while running {
        let (expired, nextNanos) = taskQueue.drainExpired()
        for (task, _) in expired {
            var t = task
            FlutterEngineRunTask(engine, &t)
        }
        Foundation.RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.001))
        // Sleep until next task deadline or 16ms max
        if let nextNanos = nextNanos {
            let now = FlutterEngineGetCurrentTime()
            if nextNanos > now {
                let wait = min(Double(nextNanos - now) / 1e9, 0.016)
                Thread.sleep(forTimeInterval: wait)
            }
        } else {
            Thread.sleep(forTimeInterval: 0.016)
        }
    }
}
```

### State Management

Use an `@unchecked Sendable` class (like BlueScreenApp's AppState) to hold mutable state shared across engine callback threads:

```swift
final class GpuRendererState: @unchecked Sendable {
    nonisolated(unsafe) var engine: OpaquePointer? = nil
    nonisolated(unsafe) var eglDisplay: OpaquePointer? = nil
    nonisolated(unsafe) var mainContext: OpaquePointer? = nil
    nonisolated(unsafe) var resourceContext: OpaquePointer? = nil
    nonisolated(unsafe) var fboName: UInt32 = 0
    nonisolated(unsafe) var socketFd: Int32 = -1
    nonisolated let taskQueue = FlutterTaskQueue()  // Reuse from BlueScreenApp
    nonisolated let mainThreadPthread = pthread_self()
}
```

The renderer callbacks extract this state from `userData` via `Unmanaged<GpuRendererState>`.

---

## Step 3: Add FlutterTaskQueue to FlutterDemoApp

The `FlutterTaskQueue` class (thread-safe task queue with `enqueue`/`drainExpired`) is currently defined inside BlueScreenApp's main.swift. It needs to be available to FlutterDemoApp.

**Option A (Recommended):** Copy the ~30-line `FlutterTaskQueue` class into `GpuDmaBufRenderer.swift`. It's small and self-contained.

**Option B:** Extract it to a shared module. Overkill for ~30 lines.

The class:
```swift
final class FlutterTaskQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [(FlutterTask, UInt64)] = []

    func enqueue(_ task: FlutterTask, targetNanos: UInt64) {
        lock.lock()
        tasks.append((task, targetNanos))
        lock.unlock()
    }

    func drainExpired() -> (expired: [(FlutterTask, UInt64)], nextDeadline: UInt64?) {
        let now = FlutterEngineGetCurrentTime()
        lock.lock()
        var expired: [(FlutterTask, UInt64)] = []
        var remaining: [(FlutterTask, UInt64)] = []
        for item in tasks {
            if item.1 <= now { expired.append(item) }
            else { remaining.append(item) }
        }
        tasks = remaining
        let next = remaining.min(by: { $0.1 < $1.1 })?.1
        lock.unlock()
        return (expired, next)
    }
}
```

---

## Step 4: Update main.swift Entry Point

**Modify:** `flutter_swift/Sources/FlutterDemoApp/main.swift`

Replace the current Linux entry point to try GPU embedder first:

```swift
// Try GPU DMA-BUF embedder first (zero-copy, Skia GPU)
// Then CPU DMA-BUF renderer (1 CPU copy, Skia CPU)
// Then SHM renderer (3 CPU copies, Skia CPU)

if let socketPath = ProcessInfo.processInfo.environment["FLUTTER_DMABUF_SOCKET"],
   !socketPath.isEmpty,
   access("/dev/dri/renderD128", R_OK | W_OK) == 0 {

    // Try GPU embedder (full engine with kOpenGL → FBO → GBM BO)
    if let gpu = GpuDmaBufRenderer(width: 640, height: 480, socketPath: socketPath) {
        print("[FlutterDemoApp] Using GPU embedder (zero-copy)")
        gpu.mountWidget {
            Directionality(textDirection: .ltr, child: FlutterDemoApp())
        }
        gpu.run()  // Blocks (event loop)
        // Not reached
    }

    // GPU failed — fall back to CPU DMA-BUF renderer
    // (need engine init for Skia CPU raster, same as current code)
    ...existing engine init code...
    if let renderer = DmaBufRenderer(width: 640, height: 480, socketPath: socketPath) {
        ...existing code...
    }
}

// Final fallback: SHM renderer
...existing SHM code...
```

Key difference: **GPU path doesn't need separate engine initialization.** The `GpuDmaBufRenderer` creates and runs the engine itself with `kOpenGL`. The CPU fallback paths still need the separate `kSoftware` engine init (existing code).

Restructure the Linux entry point into 3 tiers:
1. `GpuDmaBufRenderer` — self-contained, owns its own engine, calls `runApp()`, blocks in event loop.
2. `DmaBufRenderer` — needs external engine (kSoftware), manual pipeline, Timer-based.
3. `ShmRenderer` — needs external engine (kSoftware), manual pipeline, Timer-based.

The engine init code (FlutterEngineInitializeSwift with kSoftware) only runs for tiers 2-3.

---

## Step 5: Update Package.swift (if needed)

**Modify:** `flutter_swift/Package.swift`

Add `-lGLESv2` to FlutterDemoApp linker settings (needed for GL functions in the FBO creation helpers). Check if already linked transitively via DmaBufBridge.

Current DmaBufBridge target already links `-lgbm`, `-lEGL`, `-lGLESv2`. Since FlutterDemoApp depends on DmaBufBridge, these should propagate. If not, add explicitly:

```swift
"-lGLESv2",  // For glGenFramebuffers, glFramebufferTexture2D, etc.
```

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `flutter_swift/Sources/DmaBufBridge/include/DmaBufBridge.h` | Modify | Add EGL context + FBO helper declarations |
| `flutter_swift/Sources/DmaBufBridge/dmabuf_helpers.c` | Modify | Implement EGL context + FBO helpers |
| `flutter_swift/Sources/FlutterDemoApp/GpuDmaBufRenderer.swift` | Create | GPU embedder child (kOpenGL + FBO + GBM BO) |
| `flutter_swift/Sources/FlutterDemoApp/main.swift` | Modify | Add GPU tier, restructure fallback chain |
| `flutter_swift/Package.swift` | Modify | Add -lGLESv2 if needed |

---

## Verification

1. **Build:** `swift build --product FlutterDemoApp` — verify new C helpers and Swift code compile.
2. **GPU path test:** Launch DesktopShellApp in DRM mode → click "Flutter App" → verify child uses GPU embedder (check stderr for "[FlutterDemoApp] Using GPU embedder").
3. **Visual test:** Screenshot via `kill -USR1 <pid>` → verify Flutter App window renders correctly.
4. **Fallback test:** Remove `/dev/dri/renderD128` access → verify clean fallback to CPU DmaBufRenderer → ShmRenderer.
5. **Performance:** Compare frame times — GPU path should show lower CPU usage (no toImageSync/toByteData/memcpy).

---

## VMware SVGA3D Risks

| Risk | Mitigation |
|------|-----------|
| EGLImage as FBO color attachment fails | `dmabuf_create_fbo` returns 0 → fall back to CPU DmaBufRenderer |
| Surfaceless EGL context not supported | Try `EGL_PBUFFER_BIT` config with 1×1 pbuffer surface |
| Skia GPU initialization fails | Engine init returns `kInternalInconsistency` → fall back |
| GBM_BO_USE_RENDERING not supported | `gbm_bo_create` fails → fall back to CPU DmaBufRenderer |

All fallbacks are transparent — existing CPU DmaBufRenderer and ShmRenderer remain fully functional.
