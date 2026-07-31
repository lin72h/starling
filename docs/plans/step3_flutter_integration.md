# Step 3: BlueScreenApp Integration — Fullscreen Flutter App on DRM

## Prerequisites

- Step 1 complete (DRMBackend — display pipeline working)
- Step 2 complete (InputBackend — keyboard/mouse events working)

---

## Deliverables

Modify `BlueScreenApp` (Linux path) to:
1. Open DRM display and render Flutter frames to screen
2. Capture libinput events and feed them to the Flutter engine
3. Use an epoll-based event loop integrating DRM + libinput + engine frame scheduling

**Milestone: Run `BlueScreenApp` from a TTY and see the Fluent UI demo app fullscreen with working mouse + keyboard.**

---

## Part 1: Understanding the Current Linux Entry Point

The current code in `Sources/BlueScreenApp/main.swift` (Linux path, ~lines 967-1058):

```
1. runApp(FluentDemoApp())                           — build Swift widget tree
2. createRuntimeCallbacks()                          — wire engine→Swift callbacks
3. FlutterRendererConfig with kSoftware              — software renderer
   surface_present_callback = { ... return true }    — discards pixels
4. FlutterProjectArgs with ICU data + --enable-impeller=false
5. FlutterEngineInitializeSwift(...)                 — init engine
6. FlutterEngineRunInitializedSwift(engine)           — start engine
7. FlutterWindowMetricsEvent(1100, 700, 1.0)          — hardcoded size
8. PlatformDispatcher.instance.scheduleFrame()
9. RunLoop.main.run()                                 — blocking event loop
```

**What changes:**
- Step 3: Replace hardcoded 1100x700 with DRM mode dimensions
- Step 5: `surface_present_callback` now copies pixels to DRM dumb buffer + page flips
- Step 9: Replace `RunLoop.main.run()` with epoll loop watching DRM fd + libinput fd
- Add: input events → `FlutterEngineSendPointerEvent` / `FlutterEngineSendKeyEvent`

---

## Part 2: Wiring Surface Present to DRM

### The Callback

The software renderer calls `surface_present_callback` with:
- `allocation: UnsafeRawPointer` — pixel data (BGRA8888)
- `row_bytes: Int` — bytes per row
- `height: Int` — frame height

We copy this to the DRM back buffer and page flip.

```swift
// In BlueScreenApp setup:
var display: DRMDisplay!  // initialized before engine

rendererConfig.software.surface_present_callback = { (userData, allocation, rowBytes, height) -> Bool in
    guard let allocation = allocation else { return false }

    // Copy pixels to back buffer
    display.renderTarget.copyPixels(from: allocation, sourceRowBytes: Int(rowBytes), height: Int(height))

    // Page flip (non-blocking, async)
    do {
        try display.pageFlip()
    } catch {
        // If flip is still pending from last frame, skip this one
        // (frame dropping under load)
    }

    return true
}
```

**Pitfall: Callback captures.** The `surface_present_callback` is a C function pointer (`@convention(c)`), which cannot capture Swift variables. We need to pass `display` through the `user_data` void pointer.

**Solution:**
```swift
// Store display reference in user_data
let displayPtr = Unmanaged.passUnretained(display).toOpaque()

// In FlutterEngineInitializeSwift, pass displayPtr as user_data
FlutterEngineInitializeSwift(
    FLUTTER_ENGINE_VERSION, &rendererConfig, &args,
    displayPtr,  // ← user_data, passed to callbacks
    runtimeControllerPtr, &engine)

// In callback:
rendererConfig.software.surface_present_callback = { (userData, allocation, rowBytes, height) -> Bool in
    let display = Unmanaged<DRMDisplay>.fromOpaque(userData!).takeUnretainedValue()
    display.renderTarget.copyPixels(from: allocation!, sourceRowBytes: Int(rowBytes), height: Int(height))
    try? display.pageFlip()
    return true
}
```

**Pitfall: user_data conflict.** The same `user_data` pointer is shared by all embedder callbacks. If we need both `DRMDisplay` and `InputManager` accessible from callbacks, wrap them in a context struct:

```swift
final class EmbedderContext {
    let display: DRMDisplay
    let input: InputManager
    let engine: FlutterEngine  // stored after init, needed for input→engine calls
}
```

Pass `Unmanaged.passUnretained(context).toOpaque()` as `user_data`.

### Frame Size Matching

The engine renders at the size set by `FlutterWindowMetricsEvent`. This must match the DRM mode:

```swift
var metrics = FlutterWindowMetricsEvent()
metrics.struct_size = MemoryLayout<FlutterWindowMetricsEvent>.size
metrics.width = Int(display.mode.hdisplay)     // e.g. 1280
metrics.height = Int(display.mode.vdisplay)    // e.g. 800
metrics.pixel_ratio = 1.0
metrics.view_id = 0
FlutterEngineSendWindowMetricsEvent(engine, &metrics)
```

**Pitfall: Pixel ratio.** DRM doesn't know about HiDPI. The physical size is available from `connector.mmWidth/mmHeight`. We could calculate DPI:
```swift
let dpi = Double(mode.hdisplay) / (Double(connector.mmWidth) / 25.4)
let pixelRatio = dpi / 96.0  // 96 DPI = 1.0 scale
```
But for VMware (virtual display), mmWidth/mmHeight may be inaccurate. Start with `pixel_ratio = 1.0`.

---

## Part 3: Input Event → Flutter Engine

### Pointer Events

Flutter's `FlutterPointerEvent` struct:
```c
typedef struct {
    size_t struct_size;
    FlutterPointerPhase phase;       // kDown, kMove, kUp, kAdd, kRemove, kHover, kPanZoomStart, ...
    size_t timestamp;                // microseconds
    double x;                        // logical pixels
    double y;
    int32_t device;                  // pointer device ID
    FlutterPointerSignalKind signal_kind;  // kNone, kScroll
    double scroll_delta_x;
    double scroll_delta_y;
    FlutterPointerDeviceKind device_kind;  // kMouse, kTouch, kStylus
    int64_t buttons;                 // bitmask: kFlutterPointerButtonMousePrimary, etc.
    int64_t pan_x, pan_y;            // for trackpad gestures
    double scale;                    // pinch zoom
    double rotation;                 // rotation gesture
    int64_t view_id;
} FlutterPointerEvent;
```

**Translation from our InputEvent:**

```swift
func sendPointerEvent(event: PointerInputEvent, engine: FlutterEngine) {
    var flutterEvent = FlutterPointerEvent()
    flutterEvent.struct_size = MemoryLayout<FlutterPointerEvent>.size
    flutterEvent.timestamp = Int(event.timestamp)
    flutterEvent.x = event.x
    flutterEvent.y = event.y
    flutterEvent.device = 0
    flutterEvent.device_kind = kFlutterPointerDeviceKindMouse
    flutterEvent.view_id = 0

    if let button = event.button {
        // Button press/release
        flutterEvent.phase = event.isPressed! ? kDown : kUp
        flutterEvent.buttons = buttonMask(for: button, pressed: event.isPressed!)
    } else if event.scrollX != 0 || event.scrollY != 0 {
        // Scroll
        flutterEvent.phase = kHover  // scroll is a signal, not a phase change
        flutterEvent.signal_kind = kFlutterPointerSignalKindScroll
        flutterEvent.scroll_delta_x = event.scrollX
        flutterEvent.scroll_delta_y = event.scrollY
    } else {
        // Motion
        flutterEvent.phase = isAnyButtonDown ? kMove : kHover
    }

    FlutterEngineSendPointerEvent(engine, &flutterEvent, 1)
}
```

**Pitfall: Pointer phase lifecycle.** Flutter requires a strict phase sequence:
1. First event for a device must be `kAdd`
2. When no buttons pressed: `kHover`
3. When button pressed: `kDown`
4. While button held: `kMove`
5. When button released: `kUp`
6. Back to `kHover`
7. When pointer leaves: `kRemove`

Must track whether we've sent `kAdd` for the device, and whether any button is currently down.

```swift
final class FlutterPointerState {
    var added: Bool = false
    var buttonsDown: Int64 = 0  // bitmask of currently held buttons

    var isAnyButtonDown: Bool { buttonsDown != 0 }
}
```

**Button mask translation:**
```swift
func buttonMask(for linuxButton: UInt32) -> Int64 {
    switch linuxButton {
    case UInt32(BTN_LEFT):   return kFlutterPointerButtonMousePrimary    // 1
    case UInt32(BTN_RIGHT):  return kFlutterPointerButtonMouseSecondary  // 2
    case UInt32(BTN_MIDDLE): return kFlutterPointerButtonMouseMiddle     // 4
    default: return 0
    }
}
```

**Pitfall: `buttons` field semantics.** The `buttons` field is a **bitmask of currently pressed buttons**, not the button that caused this event. Must accumulate: `buttonsDown |= mask` on press, `buttonsDown &= ~mask` on release, and set `flutterEvent.buttons = buttonsDown` on every event.

### Keyboard Events

Flutter's `FlutterKeyEvent` struct:
```c
typedef struct {
    size_t struct_size;
    double timestamp;                 // seconds (float!)
    FlutterKeyEventType type;         // kFlutterKeyEventTypeDown, kFlutterKeyEventTypeUp, kFlutterKeyEventTypeRepeat
    uint64_t physical;                // USB HID usage code
    uint64_t logical;                 // Flutter logical key
    const char* character;            // UTF-8 text (NULL for non-printable)
    bool synthesized;
    FlutterKeyEventDeviceType device_type;
} FlutterKeyEvent;
```

**Translation complexity:** Flutter uses its own logical key and physical key ID spaces, not evdev scancodes. We need mapping tables.

**Physical key mapping:** Flutter physical keys are based on USB HID usage codes. Linux evdev scancodes map to these with a lookup table. The mapping is defined in Flutter's source at `keyboard_maps.g.dart`. We need a subset:

```swift
/// Evdev scancode → Flutter physical key (USB HID page 0x07 usage codes).
/// Flutter physical keys are 0x00070000 | hid_usage.
let evdevToFlutterPhysical: [UInt32: UInt64] = [
    30: 0x00070004,  // KEY_A → USB A
    48: 0x00070005,  // KEY_B → USB B
    // ... full table needed, ~200 entries
    // Or: use the evdev→HID mapping from linux/input.h
]
```

**Logical key mapping:** Flutter logical keys incorporate the character. For simple ASCII:
```swift
// For printable characters: use the Unicode code point | 0x00000000
// For special keys: use Flutter's predefined logical key constants
```

**Simplification for now:** Use xkbcommon keysyms as logical keys with a prefix. This won't be 100% Flutter-compatible but will work for basic interaction. Proper mapping can be added later.

```swift
func sendKeyEvent(event: KeyboardInputEvent, engine: FlutterEngine) {
    var flutterEvent = FlutterKeyEvent()
    flutterEvent.struct_size = MemoryLayout<FlutterKeyEvent>.size
    flutterEvent.timestamp = Double(event.timestamp) / 1_000_000.0  // microseconds → seconds
    flutterEvent.type = event.isPressed ? kFlutterKeyEventTypeDown : kFlutterKeyEventTypeUp
    flutterEvent.physical = evdevToFlutterPhysical[event.scancode] ?? UInt64(event.scancode)
    flutterEvent.logical = UInt64(event.keysym)  // simplified
    flutterEvent.synthesized = false

    // Character (only for key down with printable text)
    if event.isPressed, let utf8 = event.utf8 {
        utf8.withCString { cstr in
            flutterEvent.character = cstr
            FlutterEngineSendKeyEvent(engine, &flutterEvent, nil, nil)
        }
    } else {
        flutterEvent.character = nil
        FlutterEngineSendKeyEvent(engine, &flutterEvent, nil, nil)
    }
}
```

**Pitfall: `character` pointer lifetime.** The `character` pointer must be valid until `FlutterEngineSendKeyEvent` returns. Using `withCString` ensures this.

**Pitfall: Key repeat.** libinput sends repeated `LIBINPUT_KEY_STATE_PRESSED` events for held keys. Check `libinput_event_keyboard_get_seat_key_count()` — if > 1, it's a repeat. Send as `kFlutterKeyEventTypeRepeat`.

---

## Part 4: Event Loop

### Replace RunLoop with epoll

The main loop needs to watch:
1. **DRM fd** — page flip completion events (readable after flip)
2. **libinput fd** — input events (readable when input available)
3. **Timer** — for frame scheduling (engine requests frames at 60Hz)

**Option A: epoll (lowest-level, most control)**

```swift
import Glibc  // for epoll_create1, epoll_ctl, epoll_wait

let epollFd = epoll_create1(0)

// Add DRM fd
var drmEv = epoll_event(events: UInt32(EPOLLIN), data: epoll_data_t(fd: display.device.fd))
epoll_ctl(epollFd, EPOLL_CTL_ADD, display.device.fd, &drmEv)

// Add libinput fd
var inputEv = epoll_event(events: UInt32(EPOLLIN), data: epoll_data_t(fd: input.fd))
epoll_ctl(epollFd, EPOLL_CTL_ADD, input.fd, &inputEv)

// Main loop
var events = [epoll_event](repeating: epoll_event(), count: 4)
var running = true

while running {
    let n = epoll_wait(epollFd, &events, Int32(events.count), 16)  // 16ms timeout ≈ 60fps
    for i in 0..<Int(n) {
        let fd = events[i].data.fd
        if fd == display.device.fd {
            DRMEventHandler.handleEvents(device: display.device) {
                display.flipPending = false
            }
        } else if fd == input.fd {
            input.dispatch()
        }
    }

    // If no flip pending and frame was scheduled, schedule next frame
    if !display.flipPending {
        PlatformDispatcher.instance.scheduleFrame()
    }
}
```

**Option B: DispatchSource (GCD, higher-level)**

```swift
import Dispatch

let drmSource = DispatchSource.makeReadSource(fileDescriptor: display.device.fd, queue: .main)
drmSource.setEventHandler {
    DRMEventHandler.handleEvents(device: display.device) {
        display.flipPending = false
    }
}
drmSource.resume()

let inputSource = DispatchSource.makeReadSource(fileDescriptor: input.fd, queue: .main)
inputSource.setEventHandler {
    input.dispatch()
}
inputSource.resume()

dispatchMain()  // never returns
```

**Recommendation:** Start with **Option A (epoll)** because:
- More explicit control over frame timing
- No dependency on libdispatch behavior on Linux
- The engine's frame scheduling needs careful integration
- Can always switch to GCD later

**Pitfall: epoll on Linux in Swift.** The `epoll_event` struct has a union `data` field. Swift may not import the union correctly. May need a C wrapper:
```c
static inline void epoll_shim_set_fd(struct epoll_event *ev, int fd) {
    ev->data.fd = fd;
}
static inline int epoll_shim_get_fd(struct epoll_event *ev) {
    return ev->data.fd;
}
```

If `epoll_event` import is problematic, add these to the DRM shim header and use them from Swift.

**Pitfall: Frame scheduling.** The engine calls `PlatformDispatcher.scheduleFrame()` which triggers a timer. When the timer fires, the engine calls `beginFrame` → `drawFrame` → software render → `surface_present_callback`. The timing between the engine's frame request and our page flip needs to be coordinated to avoid tearing or dropped frames.

Simple approach: after page flip completes (DRM event), call `scheduleFrame()` to request the next frame. This gives a natural vsync-locked frame rate.

### Signal Handling

Clean exit on Ctrl+C (SIGINT) from SSH:

```swift
signal(SIGINT) { _ in
    running = false
}
// After loop exits:
display.restore()  // restore original CRTC
```

**Pitfall: `signal()` callback is @convention(c).** Cannot capture `running` directly. Use a global variable or `sigaction` with a flag.

---

## Part 5: Package.swift Changes

```swift
// Update BlueScreenApp (Linux) dependencies:
.executableTarget(
    name: "BlueScreenApp",
    dependencies: [
        "SwiftRuntime",
        "FlutterEmbedderBridge",
        "Flutter",
        "DRMBackend",      // ← new
        "InputBackend",    // ← new
    ],
    linkerSettings: [
        .unsafeFlags([
            "-L", engineOutPath,
            "-lflutter_engine",
            "-lswift_bridge",
            "-Xlinker", "--allow-shlib-undefined",
            "-Xlinker", "--export-dynamic",
        ])
    ]
),
```

---

## Part 6: Full Startup Sequence

```
1. Initialize DRM display
   └── Open /dev/dri/card0
   └── Find connector, mode, CRTC
   └── Create 2 dumb buffers
   └── Set CRTC mode (display goes to front buffer — initially black)

2. Initialize libinput
   └── Create udev context
   └── Create libinput context with open_restricted callback
   └── Assign seat0
   └── Initialize xkbcommon keymap + state

3. Create EmbedderContext (display + input + engine placeholder)

4. Build Flutter widget tree
   └── runApp(FluentDemoApp())

5. Create runtime callbacks
   └── createRuntimeCallbacks()

6. Configure software renderer
   └── surface_present_callback → copy to DRM back buffer → page flip

7. Configure FlutterProjectArgs
   └── assets_path, icu_data_path
   └── --enable-impeller=false

8. FlutterEngineInitializeSwift(... user_data: contextPtr ...)

9. FlutterEngineRunInitializedSwift(engine)

10. Store engine in EmbedderContext

11. Send initial FlutterWindowMetricsEvent (mode.hdisplay × mode.vdisplay)

12. Wire input callbacks:
    └── input.onPointer = { sendPointerEvent($0, engine) }
    └── input.onKeyboard = { sendKeyEvent($0, engine) }

13. Schedule first frame
    └── PlatformDispatcher.instance.scheduleFrame()

14. Enter epoll loop (DRM fd + libinput fd)
    └── On DRM readable: handle page flip → schedule next frame
    └── On libinput readable: dispatch → send events to engine
    └── On SIGINT: break

15. Cleanup
    └── display.restore()
    └── close epoll fd
```

---

## Testing Plan

### On the VM:

```bash
# 1. Build
cd flutter_swift
swift build --product BlueScreenApp

# 2. Switch to VT2 (from SSH session)
sudo chvt 2

# 3. Run
sudo LD_LIBRARY_PATH=../engine/src/out/host_debug .build/debug/BlueScreenApp

# Expected: Fluent UI demo app fills the screen
# Move mouse → cursor movement reflected in Flutter
# Click buttons → Flutter responds
# Press keys → text input works
# Ctrl+C from SSH → clean exit, VT restored

# 4. Switch back to X11
sudo chvt 1
```

### What to Verify

| Feature | How to Test | Expected |
|---------|------------|----------|
| Display output | Run from VT, look at screen | Fluent UI app visible |
| Correct resolution | Compare with `xrandr` output | Matches DRM mode (1280x800 on VM) |
| No tearing | Drag a window/scroll content | Smooth, no horizontal tear |
| Mouse movement | Move mouse | Cursor tracking (Flutter hover) |
| Mouse click | Click a Fluent UI button | Button responds (visual feedback) |
| Keyboard | Press keys | Text input in any text field |
| Frame rate | Visual smoothness | Reasonably smooth (~30fps minimum with software renderer) |
| Clean exit | Ctrl+C from SSH | Display restored to previous state |
| Error handling | Unplug monitor (N/A on VM) | Graceful error, not crash |

### Performance Expectations (VMware Software Renderer)

- Software rendering in VMware: CPU-bound, expect 15-30 FPS at 1280x800
- The memcpy to dumb buffer adds overhead: ~3ms for 1280x800x4 bytes (4MB)
- Page flip itself is fast (just a pointer swap in the driver)
- This is acceptable for validation; GPU acceleration (Step 4) will fix performance

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| DRM master conflict with X11 | Known | High | Must test from VT, not under X11 |
| Software renderer too slow | Medium | Medium | Acceptable for validation; GPU in Step 4 |
| Flutter pointer phase errors | Medium | Medium | Careful state tracking (added/down/hover) |
| epoll_event union in Swift | Medium | Low | C wrapper functions in shim header |
| Frame scheduling race | Medium | Medium | Lock frame request to vsync (flip complete) |
| signal() callback limitations | Known | Low | Use global flag variable |
| Key mapping incomplete | Known | Low | Start with basic ASCII + modifiers, expand later |
| user_data conflicts | Known | Low | Use EmbedderContext wrapper class |
