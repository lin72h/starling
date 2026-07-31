# DMA-BUF Cross-Process Compositing

## Context

The desktop shell currently composites child Flutter app windows using POSIX shared memory (`shm_open`/`mmap`). This results in **3 CPU copies per frame**:

```
Child: Skia CPU raster → memcpy → POSIX SHM segment
Parent: memcpy SHM → registry buffer → glTexImage2D → GPU texture
```

For a desktop environment compositor, we need zero-copy GPU buffer sharing via Linux DMA-BUF. The target architecture eliminates all parent-side copies:

```
Child: Skia CPU raster → memcpy → GBM buffer object (GPU memory)
Parent: receive DMA-BUF fd → eglCreateImage → GL texture (zero-copy)
```

This reduces the pipeline to **1 CPU copy** (child-side Skia→GBM BO) with **zero-copy on the parent side**.

---

## Step 1: Expose EGL Display from DRM Shell

Add `fl_drm_view_get_egl_display()` to the DRM shell's public C API so the parent can access the EGL display for DMA-BUF import.

**Modify:** `engine/src/flutter/shell/platform/linux_drm/fl_drm_view.h`
- Add declaration: `FL_DRM_EXPORT void* fl_drm_view_get_egl_display(FlDrmView* view);`

**Modify:** `engine/src/flutter/shell/platform/linux_drm/fl_drm_view.cc`
- Add implementation: `return view ? view->egl.display() : nullptr;`

No BUILD.gn or `drm_exports.lst` changes needed — the `fl_drm_view_*` wildcard already covers it.

---

## Step 2: Create `DmaBufBridge` Clang Module

New SPM target following the `FlutterDRMBridge`/`GLFWBridge` pattern. Wraps `<gbm.h>` for Swift import and provides C helper functions for SCM_RIGHTS fd passing (the `CMSG_*` macros cannot be imported into Swift directly).

**Create:** `flutter_swift/Sources/DmaBufBridge/include/module.modulemap`
```
module DmaBufBridge {
  header "DmaBufBridge.h"
  export *
}
```

**Create:** `flutter_swift/Sources/DmaBufBridge/include/DmaBufBridge.h`
- Include `<gbm.h>`, `<sys/socket.h>`, `<sys/un.h>`
- Declare helper functions:
  - `dmabuf_send_fd(int socket, int fd, const void* meta, size_t meta_len)` → send fd via SCM_RIGHTS
  - `dmabuf_recv_fd(int socket, void* meta, size_t meta_len)` → receive fd from SCM_RIGHTS
  - `dmabuf_check_egl_support(void* egl_display)` → query `EGL_EXT_image_dma_buf_import`
  - `dmabuf_import_egl_image(void* egl_display, int fd, int w, int h, int stride, uint32_t fourcc)` → create EGLImage
  - `dmabuf_bind_texture(void* egl_image)` → call `glEGLImageTargetTexture2DOES`
  - `dmabuf_destroy_egl_image(void* egl_display, void* egl_image)` → cleanup

**Create:** `flutter_swift/Sources/DmaBufBridge/dmabuf_helpers.c`
- Implement the above functions
- EGL functions loaded via `eglGetProcAddress` (no direct EGL link needed in child)
- SCM_RIGHTS implemented using `sendmsg`/`recvmsg` with `CMSG_FIRSTHDR`/`CMSG_DATA`

**Create:** `flutter_swift/Sources/DmaBufBridge/placeholder.c` (if needed for SPM)

---

## Step 3: Create `DmaBufRenderer` (Child Process)

New renderer replacing `ShmRenderer` for DMA-BUF mode. Same Flutter rendering pipeline (BuildOwner → PipelineOwner → Skia CPU raster), but writes pixels to a GBM buffer object instead of POSIX shared memory.

**Create:** `flutter_swift/Sources/FlutterDemoApp/DmaBufRenderer.swift`

Initialization:
1. Open render node `/dev/dri/renderD128` (no root needed, unlike primary node)
2. `gbm_create_device(render_fd)`
3. `gbm_bo_create(device, w, h, GBM_FORMAT_ABGR8888, GBM_BO_USE_LINEAR | GBM_BO_USE_RENDERING)`
   - `GBM_FORMAT_ABGR8888` matches Skia's RGBA byte order
   - `GBM_BO_USE_LINEAR` ensures `gbm_bo_map` works and buffer is cross-context importable
4. `gbm_bo_get_fd(bo)` → DMA-BUF fd
5. `gbm_bo_get_stride(bo)` → stride (may differ from `width * 4`)
6. Connect to parent's Unix domain socket (path from `FLUTTER_DMABUF_SOCKET` env var)
7. Send initial metadata `{width, height, stride, format}` + fd via `dmabuf_send_fd()`

Per-frame rendering (same pipeline as `ShmRenderer.renderFrame()`):
1. Build dirty elements → layout → paint → extract PictureLayer
2. `picture.toImageSync()` → `image.toByteData(.rawRgba)` → RGBA bytes
3. `gbm_bo_map(bo, ...)` → get CPU-writable pointer
4. Copy RGBA bytes row-by-row (respecting stride) into mapped BO
5. `gbm_bo_unmap(bo, map_data)`
6. Send frame signal to parent via socket (small struct or single byte)

Fallback: If GBM BO creation fails (e.g., VMware driver limitation), fall back to existing `ShmRenderer`.

---

## Step 4: Update Parent-Side Process Manager

**Modify:** `flutter_swift/Sources/DesktopShellApp/Compositor/LinuxProcessAppManager.swift`

Before launching child:
1. Create Unix domain socket at `/tmp/flutter_dmabuf_<pid>.sock`
2. `bind` + `listen` on it
3. Set `FLUTTER_DMABUF_SOCKET` in child's environment
4. Launch child process (existing `Process()` code)

IPC handling (background thread):
1. `accept` connection from child on the socket
2. `dmabuf_recv_fd()` → extract DMA-BUF fd + metadata (width, height, stride, format)
3. Queue `PendingDmaBufLaunch` for `tick()` (same pattern as current `PendingLaunch`)
4. On subsequent frame signals: queue texture ID for `FlutterEngineMarkExternalTextureFrameAvailable`
   - No pixel copy needed — the GL texture already maps the GBM BO's GPU memory

In `tick()`:
- Call `textureRegistry.importDmaBuf(engine:id:fd:width:height:stride:format:)` instead of `textureRegistry.updatePixelData()`

Keep existing SHM path as fallback (if child sends `SURFACE:` on stdout instead of connecting to the socket).

---

## Step 5: Add DMA-BUF Import to Texture Registry

**Modify:** `flutter_swift/Sources/DesktopShellApp/Compositor/LinuxTextureRegistry.swift`

New EGL/GL function pointers (loaded via existing `glProcAddressResolver` pattern):
- `eglCreateImageKHR` (from `eglGetProcAddress`)
- `glEGLImageTargetTexture2DOES` (from `eglGetProcAddress`)
- `eglDestroyImageKHR`

New `TextureEntry` fields:
- `eglImage: OpaquePointer?` — the imported EGLImage (non-nil for DMA-BUF textures)
- `dmaFd: Int32 = -1` — kept open while image exists

New method:
```swift
func importDmaBuf(engine:, id:, fd:, width:, height:, stride:, format:)
```
- Stores fd and metadata in entry
- Marks dirty, calls `FlutterEngineMarkExternalTextureFrameAvailable`

In `populateTexture()` (raster thread), add DMA-BUF path before CPU upload path:
1. If `entry.dmaFd >= 0` and `entry.eglImage == nil`: create EGLImage via `dmabuf_import_egl_image()`
2. If GL texture not yet created: `glGenTextures`
3. `glBindTexture(GL_TEXTURE_2D, texName)` → `dmabuf_bind_texture(eglImage)` → done
4. For subsequent frames: texture already bound to the DMA-BUF — just return the existing GL texture name. The GPU reads the latest pixels from the GBM BO automatically (shared GPU memory).

EGL display access: Use `eglGetCurrentDisplay()` on the raster thread (GL context is always current when `populateTexture` is called). Works for both GLFW and DRM modes.

---

## Step 6: Update Child Entry Point

**Modify:** `flutter_swift/Sources/FlutterDemoApp/main.swift`

Add runtime detection:
```swift
if let socketPath = ProcessInfo.processInfo.environment["FLUTTER_DMABUF_SOCKET"],
   canCreateGbmDevice() {  // try opening /dev/dri/renderD128
    let renderer = DmaBufRenderer(width: w, height: h, socketPath: socketPath)
    // ... mount widget, start rendering
} else {
    let renderer = ShmRenderer(width: w, height: h)
    // ... existing SHM path
}
```

---

## Step 7: Update Package.swift

**Modify:** `flutter_swift/Package.swift`

In `#if os(Linux)` section:

1. Add `DmaBufBridge` target:
```swift
.target(
    name: "DmaBufBridge",
    cSettings: [
        .unsafeFlags(["-I/usr/include/libdrm"]),  // gbm.h needs drm.h
    ]
),
```

2. Add `DmaBufBridge` to `FlutterDemoApp` dependencies
3. Add `-lgbm` to `FlutterDemoApp` linker settings
4. Add `DmaBufBridge` to `DesktopShellApp` dependencies (for `dmabuf_import_egl_image` etc.)

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `engine/.../linux_drm/fl_drm_view.h` | Modify | Add `fl_drm_view_get_egl_display()` |
| `engine/.../linux_drm/fl_drm_view.cc` | Modify | Implement `fl_drm_view_get_egl_display()` |
| `flutter_swift/Sources/DmaBufBridge/include/module.modulemap` | Create | Clang module definition |
| `flutter_swift/Sources/DmaBufBridge/include/DmaBufBridge.h` | Create | GBM wrapper + SCM_RIGHTS + EGL import helpers |
| `flutter_swift/Sources/DmaBufBridge/dmabuf_helpers.c` | Create | C implementations |
| `flutter_swift/Sources/FlutterDemoApp/DmaBufRenderer.swift` | Create | GBM BO renderer (replaces ShmRenderer) |
| `flutter_swift/Sources/FlutterDemoApp/main.swift` | Modify | Auto-detect DMA-BUF vs SHM |
| `flutter_swift/Sources/DesktopShellApp/Compositor/LinuxTextureRegistry.swift` | Modify | EGLImage import from DMA-BUF fd |
| `flutter_swift/Sources/DesktopShellApp/Compositor/LinuxProcessAppManager.swift` | Modify | Unix socket IPC, fd receiving |
| `flutter_swift/Sources/DesktopShellApp/main.swift` | Modify | Socket creation, capability detection |
| `flutter_swift/Package.swift` | Modify | Add DmaBufBridge + deps + linker flags |

---

## Verification

1. **Build engine**: `cd engine/src && flutter/bin/et build` — verify `fl_drm_view_get_egl_display` in `libflutter_linux_drm.so`
2. **Build Swift**: `cd flutter_swift && swift build --product DesktopShellApp && swift build --product FlutterDemoApp`
3. **Runtime check**: Launch DesktopShellApp in DRM mode, verify child connects via Unix socket and sends DMA-BUF fd
4. **Visual check**: Screenshot via `kill -USR1 <pid>` — verify child app renders correctly as a texture
5. **Fallback test**: Set `FLUTTER_DMABUF_SOCKET=""` or remove render node access — verify clean fallback to SHM path
6. **Performance**: Compare frame times with SHM path — parent-side CPU usage should drop (no `glTexImage2D` upload)

---

## VMware SVGA3D Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `gbm_bo_create(GBM_BO_USE_LINEAR)` may fail | Fall back to ShmRenderer |
| `gbm_bo_map` may not work on vmwgfx | Fall back to ShmRenderer |
| `EGL_EXT_image_dma_buf_import` not advertised | `dmabuf_check_egl_support()` returns false → SHM fallback |
| DMA-BUF fd from render node not importable | Try import, catch failure, fall back to SHM |

All fallbacks are transparent — the existing SHM path remains fully functional.
