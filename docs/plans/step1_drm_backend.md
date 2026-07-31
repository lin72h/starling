# Step 1: DRM/KMS Backend — Get Pixels on Screen

## Prerequisites

```bash
# On the VM (ubuntu@<vm-host>):
sudo apt install libdrm-dev
```

This provides `/usr/include/xf86drm.h`, `/usr/include/xf86drmMode.h`, and the `libdrm.so` symlink.

Kernel DRM headers are already at `/usr/include/drm/` (`drm.h`, `drm_mode.h`, `drm_fourcc.h`).

---

## Deliverables

Two new SPM targets:

1. **`DRMBridgeHeaders`** — Clang module wrapping libdrm + kernel DRM headers for Swift
2. **`DRMBackend`** — Swift module implementing DRM display pipeline

Plus a **standalone test binary** (`DRMTest`) that opens the display, draws a solid color, and page-flips.

---

## Part 1: DRMBridgeHeaders (Clang Module)

### File: `Sources/DRMBridgeHeaders/include/module.modulemap`

```
module DRMBridgeHeaders [system] {
    header "drm_shim.h"
    link "drm"
    export *
}
```

### File: `Sources/DRMBridgeHeaders/include/drm_shim.h`

Umbrella header + C wrappers for things Swift can't import directly:

```c
#pragma once

#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

// Kernel DRM headers
#include <drm.h>
#include <drm_mode.h>
#include <drm_fourcc.h>

// libdrm wrappers
#include <xf86drm.h>
#include <xf86drmMode.h>

// --- C wrappers for things Swift can't import ---

// open() is variadic — Swift blocks it
static inline int drm_shim_open(const char *path, int flags) {
    return open(path, flags);
}

// ioctl() is variadic — Swift blocks it
static inline int drm_shim_ioctl(int fd, unsigned long request, void *arg) {
    return ioctl(fd, request, arg);
}

// errno is a macro — Swift can't access it
static inline int drm_shim_errno(void) {
    return errno;
}

// MAP_FAILED is (void*)-1 — Swift can't evaluate
static inline int drm_shim_mmap_failed(void *ptr) {
    return ptr == MAP_FAILED ? 1 : 0;
}

// Page size
static inline long drm_shim_page_size(void) {
    return sysconf(_SC_PAGESIZE);
}

// --- DRM ioctl constants (complex macros, Swift can't import) ---

static inline unsigned long DRM_SHIM_IOCTL_MODE_GETRESOURCES(void) {
    return DRM_IOCTL_MODE_GETRESOURCES;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_GETCRTC(void) {
    return DRM_IOCTL_MODE_GETCRTC;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_SETCRTC(void) {
    return DRM_IOCTL_MODE_SETCRTC;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_GETENCODER(void) {
    return DRM_IOCTL_MODE_GETENCODER;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_GETCONNECTOR(void) {
    return DRM_IOCTL_MODE_GETCONNECTOR;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_CREATE_DUMB(void) {
    return DRM_IOCTL_MODE_CREATE_DUMB;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_MAP_DUMB(void) {
    return DRM_IOCTL_MODE_MAP_DUMB;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_DESTROY_DUMB(void) {
    return DRM_IOCTL_MODE_DESTROY_DUMB;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_ADDFB(void) {
    return DRM_IOCTL_MODE_ADDFB;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_ADDFB2(void) {
    return DRM_IOCTL_MODE_ADDFB2;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_RMFB(void) {
    return DRM_IOCTL_MODE_RMFB;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_PAGE_FLIP(void) {
    return DRM_IOCTL_MODE_PAGE_FLIP;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_CURSOR(void) {
    return DRM_IOCTL_MODE_CURSOR;
}
static inline unsigned long DRM_SHIM_IOCTL_MODE_CURSOR2(void) {
    return DRM_IOCTL_MODE_CURSOR2;
}
static inline unsigned long DRM_SHIM_IOCTL_GEM_CLOSE(void) {
    return DRM_IOCTL_GEM_CLOSE;
}
static inline unsigned long DRM_SHIM_IOCTL_SET_CLIENT_CAP(void) {
    return DRM_IOCTL_SET_CLIENT_CAP;
}
static inline unsigned long DRM_SHIM_IOCTL_GET_CAP(void) {
    return DRM_IOCTL_GET_CAP;
}

// --- Pixel format constants (fourcc macros, Swift can't import) ---

static inline uint32_t DRM_SHIM_FORMAT_XRGB8888(void) {
    return DRM_FORMAT_XRGB8888;
}
static inline uint32_t DRM_SHIM_FORMAT_ARGB8888(void) {
    return DRM_FORMAT_ARGB8888;
}
static inline uint32_t DRM_SHIM_FORMAT_XBGR8888(void) {
    return DRM_FORMAT_XBGR8888;
}
static inline uint32_t DRM_SHIM_FORMAT_ABGR8888(void) {
    return DRM_FORMAT_ABGR8888;
}
```

### File: `Sources/DRMBridgeHeaders/placeholder.c`

```c
// Required by SwiftPM for Clang targets
```

### Package.swift Addition

```swift
.target(
    name: "DRMBridgeHeaders",
    path: "Sources/DRMBridgeHeaders",
    cSettings: [
        .unsafeFlags(["-I/usr/include/drm"]),   // kernel drm headers
    ]
),
```

### Potential Pitfalls

1. **Header search order** — `/usr/include/drm/drm.h` vs `/usr/include/libdrm/drm.h`. The `-dev` package may install both. Use `-I/usr/include/drm` to get the kernel headers, which is what `xf86drm.h` expects (it does `#include <drm.h>`).

2. **`__u32` / `__u64` types** — These are defined in `<linux/types.h>` which is pulled in by `drm.h`. Swift imports them as `UInt32` / `UInt64`. Verified working.

3. **Struct padding** — DRM kernel structs have explicit padding fields and `__attribute__((packed))` is not used. Swift should import them with correct layout. Verify with `MemoryLayout<drm_mode_create_dumb>.size == 32`.

---

## Part 2: DRMBackend (Swift Module)

### File Structure

```
Sources/DRMBackend/
├── DRMDevice.swift          — Open DRM device, query capabilities
├── DRMConnector.swift       — Enumerate connectors, find connected one, pick mode
├── DRMFramebuffer.swift     — Dumb buffer: create, mmap, addFB, destroy
├── DRMDisplay.swift         — High-level: init pipeline, double-buffer page flip
└── DRMEventHandler.swift    — Handle page flip completion events
```

### DRMDevice.swift

```swift
import DRMBridgeHeaders

/// Wraps an open DRM device file descriptor.
final class DRMDevice {
    let fd: Int32

    init(path: String = "/dev/dri/card0") throws { ... }

    /// Get mode resources (CRTCs, connectors, encoders).
    func getResources() throws -> OpaquePointer /* drmModeResPtr */ { ... }

    /// Check capability (e.g. DRM_CAP_DUMB_BUFFER).
    func getCap(_ cap: UInt64) throws -> UInt64 { ... }

    deinit { close(fd) }
}
```

**Key calls:**
- `drm_shim_open("/dev/dri/card0", O_RDWR | O_CLOEXEC)` → fd
- `drmGetCap(fd, cap, &value)` → verify dumb buffer support
- `drmModeGetResources(fd)` → enumerate hardware

**Pitfall: Permissions.** `/dev/dri/card0` is typically `root:video` mode `0660`. The user must be in the `video` group, or run as root, or use logind's session device API. For development, `sudo` or `usermod -aG video ubuntu`.

**Pitfall: DRM master.** When X11 is running, it holds DRM master. `drmModeSetCrtc()` will fail with EACCES unless we either:
- Run from a VT where X isn't active (`sudo chvt 2`)
- Or use `drmSetMaster()` (requires root)
- Or stop X first

For now: **test from a bare TTY** (ssh in, `sudo chvt 2`, then run).

### DRMConnector.swift

```swift
/// Wraps a DRM connector and its available modes.
struct DRMConnectorInfo {
    let connectorId: UInt32
    let encoderId: UInt32
    let modes: [drmModeModeInfo]
    let connected: Bool
    let physicalWidth: UInt32   // mm
    let physicalHeight: UInt32  // mm
}

/// Find the first connected connector and its preferred mode.
func findConnectedConnector(device: DRMDevice) throws -> (DRMConnectorInfo, drmModeModeInfo) { ... }
```

**Key calls:**
- `drmModeGetConnector(fd, connectorId)` → connector info + modes array
- Check `connector.pointee.connection == DRM_MODE_CONNECTED`
- Find mode with `DRM_MODE_TYPE_PREFERRED` flag, or first mode as fallback
- `drmModeGetEncoder(fd, encoderId)` → get `crtc_id`
- `drmModeFreeConnector()` / `drmModeFreeEncoder()` — must free

**Pitfall: Encoder → CRTC mapping.** The connector's `encoder_id` might be 0 (no encoder attached). Must fall back to iterating `connector.encoders[]` and checking `possible_crtcs` bitmask against available CRTCs.

**Algorithm for finding a valid CRTC:**
```
1. If connector.encoder_id != 0:
   a. encoder = getEncoder(connector.encoder_id)
   b. If encoder.crtc_id != 0 and that CRTC isn't used by another connector → use it
2. Else, for each encoder_id in connector.encoders:
   a. encoder = getEncoder(encoder_id)
   b. For each bit i in encoder.possible_crtcs:
      - crtc_id = resources.crtcs[i]
      - If not already in use → use it
```

On VMware this is simple (1:1 mapping), but the code should handle the general case.

### DRMFramebuffer.swift

```swift
/// A dumb buffer backed by a DRM GEM object, mmapped for CPU write access.
final class DRMFramebuffer {
    let device: DRMDevice
    let width: UInt32
    let height: UInt32
    let pitch: UInt32     // bytes per row (may be > width * 4 due to alignment)
    let size: UInt64
    let handle: UInt32    // GEM handle
    let fbId: UInt32      // DRM framebuffer ID
    let mapped: UnsafeMutableRawPointer  // mmap'd pointer

    init(device: DRMDevice, width: UInt32, height: UInt32) throws { ... }

    /// Copy pixel data from a software-rendered frame into this buffer.
    func copyPixels(from source: UnsafeRawPointer, sourceRowBytes: Int, height: Int) { ... }

    deinit { /* munmap, drmModeRmFB, destroy dumb */ }
}
```

**Creation sequence (5 steps):**

```
1. ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &createDumb)
   - Input: width, height, bpp=32, flags=0
   - Output: handle, pitch, size

2. drmModeAddFB(fd, width, height, 24, 32, pitch, handle, &fbId)
   - Registers the dumb buffer as a framebuffer
   - depth=24 (no alpha in scanout), bpp=32

3. ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mapDumb)
   - Input: handle
   - Output: offset (fake mmap offset)

4. mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset)
   - Maps the buffer to userspace
   - Check drm_shim_mmap_failed(ptr) != 0

5. Store handle, fbId, mapped pointer
```

**Destruction sequence (3 steps):**
```
1. munmap(mapped, Int(size))
2. drmModeRmFB(fd, fbId)
3. ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroyDumb)  // frees GEM handle
```

**copyPixels:** `memcpy` row-by-row if `sourceRowBytes != pitch`, or single `memcpy` if they match.

**Pitfall: Pitch alignment.** The driver may return a pitch larger than `width * 4` (e.g. 64-byte aligned). Must handle this in `copyPixels` — copy row by row with different source and destination strides.

**Pitfall: Pixel format.** Skia software renderer outputs BGRA8888 (`kN32_SkColorType` on little-endian = `kBGRA_8888`). DRM_FORMAT_XRGB8888 on little-endian stores bytes as B, G, R, X. So BGRA from Skia maps to XRGB in DRM (the alpha byte is ignored for scanout). **No swizzle needed.**

### DRMDisplay.swift

```swift
/// High-level display pipeline: double-buffered page flipping.
final class DRMDisplay {
    let device: DRMDevice
    let connectorId: UInt32
    let crtcId: UInt32
    let mode: drmModeModeInfo
    let savedCrtc: OpaquePointer?  // drmModeCrtcPtr, for restore on exit

    var frontBuffer: DRMFramebuffer
    var backBuffer: DRMFramebuffer
    var flipPending: Bool = false

    init(device: DRMDevice) throws { ... }

    /// Set initial mode (must call once before flipping).
    func setMode() throws { ... }

    /// Swap back buffer to front via async page flip.
    func pageFlip() throws { ... }

    /// Restore original CRTC state on exit.
    func restore() { ... }

    /// The back buffer to write the next frame into.
    var renderTarget: DRMFramebuffer { backBuffer }
}
```

**init:**
```
1. findConnectedConnector() → connectorInfo, mode
2. Find valid CRTC (see algorithm above)
3. savedCrtc = drmModeGetCrtc(fd, crtcId)  // save for restore
4. Create 2x DRMFramebuffer(width: mode.hdisplay, height: mode.vdisplay)
```

**setMode:**
```
drmModeSetCrtc(fd, crtcId, frontBuffer.fbId, 0, 0, &connectorId, 1, &mode)
```

**pageFlip:**
```
1. If flipPending, skip (or wait for completion)
2. drmModePageFlip(fd, crtcId, backBuffer.fbId, DRM_MODE_PAGE_FLIP_EVENT, userDataPtr)
3. swap(frontBuffer, backBuffer)
4. flipPending = true
```

**Pitfall: Blocking on page flip.** After calling `drmModePageFlip`, we must wait for the `DRM_EVENT_FLIP_COMPLETE` event before flipping again. If we call `drmModePageFlip` while one is pending, it returns `EBUSY`. The event is delivered by `read()` on the DRM fd.

**Pitfall: VT switching.** If the user switches to another VT while we're running, we lose DRM master. Should handle `SIGUSR1`/`SIGUSR2` or use logind's session API. For now: just exit cleanly.

### DRMEventHandler.swift

```swift
/// Handles DRM events (page flip completion).
struct DRMEventHandler {
    /// Process pending DRM events. Call when DRM fd is readable.
    static func handleEvents(device: DRMDevice, onFlipComplete: () -> Void) { ... }
}
```

**Implementation:**
```swift
var evctx = drmEventContext()
evctx.version = DRM_EVENT_CONTEXT_VERSION  // = 4
evctx.page_flip_handler2 = { fd, sequence, tvSec, tvUsec, crtcId, userData in
    // Signal flip complete
}
drmHandleEvent(device.fd, &evctx)
```

**Pitfall: `page_flip_handler2` C function pointer.** This is a `@convention(c)` function pointer. It cannot capture Swift context. Must use the `userData` `void*` parameter to pass a reference to the `DRMDisplay` (or a flag pointer).

**Strategy:** Pass `Unmanaged.passUnretained(display).toOpaque()` as the user data in `drmModePageFlip`, recover it in the callback:
```swift
let display = Unmanaged<DRMDisplay>.fromOpaque(userData!).takeUnretainedValue()
display.flipPending = false
```

---

## Part 3: DRMTest (Standalone Test Binary)

### File: `Sources/DRMTest/main.swift`

A minimal test that:
1. Opens DRM device
2. Finds connected connector + mode
3. Creates 2 dumb buffers
4. Sets CRTC mode
5. Fills first buffer with solid blue, page flips
6. Waits 1 second
7. Fills second buffer with solid red, page flips
8. Waits 1 second
9. Restores original CRTC, cleans up

This validates the entire DRM pipeline before integrating with Flutter.

### Package.swift Addition

```swift
.executableTarget(
    name: "DRMTest",
    dependencies: ["DRMBackend"]
),
```

---

## Part 4: Package.swift (Full Changes)

```swift
// Add to Linux-only targets:

// Clang module for DRM headers
.target(
    name: "DRMBridgeHeaders",
    path: "Sources/DRMBridgeHeaders",
    cSettings: [
        .unsafeFlags(["-I/usr/include/drm"]),
    ]
),

// Swift DRM backend
.target(
    name: "DRMBackend",
    dependencies: ["DRMBridgeHeaders"],
    linkerSettings: [
        .unsafeFlags(["-ldrm"]),
    ]
),

// Test binary
.executableTarget(
    name: "DRMTest",
    dependencies: ["DRMBackend"],
),
```

---

## Testing Plan

### On the VM:

```bash
# 1. Install dependencies
sudo apt install libdrm-dev

# 2. Add user to video group (for /dev/dri access)
sudo usermod -aG video ubuntu
# Re-login or: newgrp video

# 3. Build
cd flutter_swift
swift build --product DRMTest

# 4. Run from a TTY (not under X11)
# From SSH: switch the VM to VT2
sudo chvt 2
# Then run:
sudo .build/debug/DRMTest
# Should see blue screen for 1 sec, then red screen for 1 sec, then restore

# 5. Switch back to X11
sudo chvt 1
```

### Expected Issues & How to Verify

| Check | Command | Expected |
|-------|---------|----------|
| libdrm-dev installed | `dpkg -l libdrm-dev` | Installed |
| DRM device accessible | `ls -la /dev/dri/card0` | `crw-rw----+ root video` |
| User in video group | `groups ubuntu` | Contains `video` |
| Dumb buffer cap | Run DRMTest | Prints "dumb buffer: supported" |
| Connector found | Run DRMTest | Prints "Virtual-1: connected, 1280x800@60Hz" |
| Struct sizes correct | Print `MemoryLayout<drm_mode_create_dumb>.size` | 32 |
| mmap works | Run DRMTest | No "mmap failed" error |
| Mode set works | Run from VT | Display changes color |
| Page flip works | Run from VT | Display flips between colors |
| Restore works | After DRMTest exits | Previous display (X11 or VT) restored |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Swift struct layout mismatch with C | Low | High | Verify `MemoryLayout` sizes at init |
| vmwgfx quirks with page flip | Low | Medium | Fall back to `drmModeSetCrtc` (blocking) |
| DRM master conflict with X11 | Known | Medium | Test from VT, document requirement |
| Permission denied on /dev/dri | Known | Low | `sudo` or add to video group |
| C function pointer callbacks in Swift 6 | Low | Medium | Already verified working in test package |
| `libdrm-dev` missing headers | Known | Low | `sudo apt install libdrm-dev` |
