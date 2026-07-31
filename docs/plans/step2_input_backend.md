# Step 2: Input Backend — Keyboard, Mouse, and Touch via libinput

## Prerequisites

```bash
# On the VM (ubuntu@<vm-host>):
sudo apt install libinput-dev libudev-dev libxkbcommon-dev

# Add user to input group (for /dev/input access without sudo):
sudo usermod -aG input ubuntu
# Re-login required
```

---

## Deliverables

Two new SPM targets:

1. **`InputBridgeHeaders`** — Clang module wrapping libinput, libudev, xkbcommon headers
2. **`InputBackend`** — Swift module: libinput event loop + xkbcommon key translation

---

## Part 1: InputBridgeHeaders (Clang Module)

### File: `Sources/InputBridgeHeaders/include/module.modulemap`

```
module InputBridgeHeaders [system] {
    header "input_shim.h"
    link "input"
    link "udev"
    link "xkbcommon"
    export *
}
```

### File: `Sources/InputBridgeHeaders/include/input_shim.h`

```c
#pragma once

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>

#include <libinput.h>
#include <libudev.h>
#include <xkbcommon/xkbcommon.h>

// --- C wrappers for variadic / macro functions ---

// open() is variadic
static inline int input_shim_open(const char *path, int flags) {
    return open(path, flags);
}

// errno is a macro
static inline int input_shim_errno(void) {
    return errno;
}

// poll() wrapper (Swift can call it directly, but this is cleaner)
static inline int input_shim_poll(struct pollfd *fds, int nfds, int timeout_ms) {
    return poll(fds, (nfds_t)nfds, timeout_ms);
}

// Linux input event codes (button constants that may be macros)
#include <linux/input-event-codes.h>
// BTN_LEFT, BTN_RIGHT, BTN_MIDDLE, KEY_A..KEY_Z, etc.
// These are simple #define integers — Swift CAN import them directly.
// But we include the header here so they're in the module.
```

### File: `Sources/InputBridgeHeaders/placeholder.c`

```c
// Required by SwiftPM for Clang targets
```

### Package.swift Addition

```swift
.target(
    name: "InputBridgeHeaders",
    path: "Sources/InputBridgeHeaders",
),
```

### Potential Pitfalls

1. **`libinput.h` includes `<libudev.h>`** — Make sure both are in the module, or udev types will be incomplete. Including both in the shim header handles this.

2. **`linux/input-event-codes.h`** — Contains `KEY_A` (30), `BTN_LEFT` (0x110), etc. These are simple integer `#define`s that Swift imports directly. Must include this header to get the constants.

3. **xkbcommon types** — `xkb_keycode_t`, `xkb_keysym_t` are `uint32_t` typedefs. Swift imports them as `UInt32`. No issues.

4. **`struct pollfd`** — Standard POSIX, Swift imports it fine. Fields: `fd`, `events` (`POLLIN`), `revents`.

---

## Part 2: InputBackend (Swift Module)

### File Structure

```
Sources/InputBackend/
├── InputManager.swift        — libinput context, device discovery, event dispatch
├── KeyboardHandler.swift     — xkbcommon state, key translation, modifier tracking
├── PointerState.swift        — Track absolute cursor position from relative deltas
└── InputEvent.swift          — Swift-native event types (before Flutter translation)
```

### InputEvent.swift — Swift Event Types

```swift
/// Keyboard event from libinput + xkbcommon.
struct KeyboardInputEvent {
    let timestamp: UInt64      // microseconds
    let scancode: UInt32       // Linux evdev scancode (KEY_A = 30)
    let keysym: UInt32         // xkbcommon keysym (XKB_KEY_a, XKB_KEY_Return, etc.)
    let utf8: String?          // text produced (e.g. "a", "A", nil for modifiers)
    let isPressed: Bool        // true = down, false = up
    let modifiers: ModifierState
}

/// Mouse/touchpad event.
struct PointerInputEvent {
    let timestamp: UInt64
    let x: Double              // absolute screen position
    let y: Double
    let dx: Double             // relative delta (for this event)
    let dy: Double
    let button: UInt32?        // BTN_LEFT, BTN_RIGHT, etc. (nil for motion)
    let isPressed: Bool?       // true = down, false = up (nil for motion)
    let scrollX: Double        // horizontal scroll
    let scrollY: Double        // vertical scroll
}

/// Touch event.
struct TouchInputEvent {
    let timestamp: UInt64
    let slot: Int32            // finger slot (-1 for single-touch devices)
    let x: Double              // absolute screen position
    let y: Double
    let phase: TouchPhase      // .began, .moved, .ended, .cancelled
}

enum TouchPhase {
    case began, moved, ended, cancelled
}

/// Modifier key state.
struct ModifierState {
    let shift: Bool
    let ctrl: Bool
    let alt: Bool
    let logo: Bool  // Super/Windows key
    let capsLock: Bool
    let numLock: Bool
}
```

### KeyboardHandler.swift — xkbcommon Integration

```swift
import InputBridgeHeaders

/// Manages xkbcommon keymap and state for key translation.
final class KeyboardHandler {
    private let xkbContext: OpaquePointer    // xkb_context*
    private let xkbKeymap: OpaquePointer     // xkb_keymap*
    private var xkbState: OpaquePointer      // xkb_state*

    init() throws { ... }

    /// Translate a libinput key event to our event type.
    func handleKey(event: OpaquePointer /* libinput_event_keyboard* */) -> KeyboardInputEvent { ... }

    /// Current modifier state.
    var modifiers: ModifierState { ... }

    deinit { /* xkb_state_unref, xkb_keymap_unref, xkb_context_unref */ }
}
```

**init:**
```swift
xkbContext = xkb_context_new(XKB_CONTEXT_NO_FLAGS)
// NULL rule_names → system defaults (US layout)
xkbKeymap = xkb_keymap_new_from_names(xkbContext, nil, XKB_KEYMAP_COMPILE_NO_FLAGS)
xkbState = xkb_state_new(xkbKeymap)
```

**handleKey:**
```swift
func handleKey(event: OpaquePointer) -> KeyboardInputEvent {
    let time = libinput_event_keyboard_get_time_usec(event)
    let scancode = libinput_event_keyboard_get_key(event)
    let pressed = libinput_event_keyboard_get_key_state(event) == LIBINPUT_KEY_STATE_PRESSED

    // CRITICAL: xkbcommon keycodes = evdev scancode + 8
    let xkbKey = scancode + 8

    // Get keysym BEFORE updating state (conventional)
    let keysym = xkb_state_key_get_one_sym(xkbState, xkbKey)

    // Get UTF-8 text
    var buf = [CChar](repeating: 0, count: 64)
    let len = xkb_state_key_get_utf8(xkbState, xkbKey, &buf, buf.count)
    let utf8 = len > 0 ? String(cString: buf) : nil

    // Update state AFTER getting keysym
    let direction: xkb_key_direction = pressed ? XKB_KEY_DOWN : XKB_KEY_UP
    xkb_state_update_key(xkbState, xkbKey, direction)

    return KeyboardInputEvent(
        timestamp: time,
        scancode: scancode,
        keysym: keysym,
        utf8: utf8,
        isPressed: pressed,
        modifiers: self.modifiers
    )
}
```

**modifiers property:**
```swift
var modifiers: ModifierState {
    ModifierState(
        shift: xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_SHIFT, XKB_STATE_MODS_EFFECTIVE) > 0,
        ctrl:  xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_CTRL, XKB_STATE_MODS_EFFECTIVE) > 0,
        alt:   xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_ALT, XKB_STATE_MODS_EFFECTIVE) > 0,
        logo:  xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_LOGO, XKB_STATE_MODS_EFFECTIVE) > 0,
        capsLock: xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_CAPS, XKB_STATE_MODS_EFFECTIVE) > 0,
        numLock:  xkb_state_mod_name_is_active(xkbState, XKB_MOD_NAME_NUM, XKB_STATE_MODS_EFFECTIVE) > 0,
    )
}
```

**Pitfall: `XKB_MOD_NAME_*` constants.** These are `#define` string literals (e.g. `#define XKB_MOD_NAME_SHIFT "Shift"`). Swift should import these as `String` constants. If not, define them in the shim header as `static const char*`.

**Pitfall: xkbcommon state update order.** Get keysym/text BEFORE `xkb_state_update_key()`. This way, pressing Shift then 'a' gives keysym 'A' (Shift was already in state from its own key event). If you update first, the key event for Shift itself would already include Shift in the state.

### PointerState.swift — Cursor Position Tracking

```swift
/// Tracks absolute cursor position from relative mouse deltas.
/// libinput provides relative motion; we accumulate to absolute position.
final class PointerState {
    var x: Double = 0
    var y: Double = 0
    var screenWidth: Double
    var screenHeight: Double

    init(screenWidth: Double, screenHeight: Double) { ... }

    /// Update position from relative motion, clamping to screen bounds.
    func applyDelta(dx: Double, dy: Double) {
        x = max(0, min(screenWidth - 1, x + dx))
        y = max(0, min(screenHeight - 1, y + dy))
    }

    /// Set absolute position (for absolute devices like touchscreens).
    func setAbsolute(x: Double, y: Double) {
        self.x = max(0, min(screenWidth - 1, x))
        self.y = max(0, min(screenHeight - 1, y))
    }
}
```

**Pitfall: Initial cursor position.** Start at center of screen `(screenWidth/2, screenHeight/2)`, not `(0,0)`.

**Pitfall: VMware mouse.** VMware's `VirtualPS/2 VMware VMMouse` sends `POINTER_MOTION_ABSOLUTE` events (not relative). Must handle both relative and absolute pointer motion.

### InputManager.swift — Main Event Loop

```swift
import InputBridgeHeaders

/// Manages libinput context and dispatches events.
final class InputManager {
    private var libinput: OpaquePointer?  // struct libinput*
    private var udev: OpaquePointer?      // struct udev*
    let keyboard: KeyboardHandler
    let pointer: PointerState

    /// Callbacks for processed events.
    var onKeyboard: ((KeyboardInputEvent) -> Void)?
    var onPointer: ((PointerInputEvent) -> Void)?
    var onTouch: ((TouchInputEvent) -> Void)?

    /// File descriptor for polling (epoll/DispatchSource).
    var fd: Int32 { libinput_get_fd(libinput) }

    init(screenWidth: Double, screenHeight: Double) throws { ... }

    /// Process all pending events. Call when fd is readable.
    func dispatch() { ... }

    deinit { /* libinput_unref, udev_unref */ }
}
```

**init — libinput context creation:**

```swift
init(screenWidth: Double, screenHeight: Double) throws {
    keyboard = try KeyboardHandler()
    pointer = PointerState(screenWidth: screenWidth, screenHeight: screenHeight)

    udev = udev_new()
    guard udev != nil else { throw InputError.udevFailed }

    // The interface struct with C-compatible function pointers
    var interface = libinput_interface(
        open_restricted: { (path, flags, userData) -> Int32 in
            return input_shim_open(path, flags | O_CLOEXEC | O_NONBLOCK)
        },
        close_restricted: { (fd, userData) -> Void in
            close(fd)
        }
    )

    libinput = libinput_udev_create_context(&interface, nil, udev)
    guard libinput != nil else { throw InputError.libinputFailed }

    let result = libinput_udev_assign_seat(libinput, "seat0")
    guard result == 0 else { throw InputError.seatAssignFailed }
}
```

**Pitfall: `libinput_interface` lifetime.** The `interface` struct is passed by pointer. libinput stores the function pointers internally, so the local `var interface` can go out of scope after `libinput_udev_create_context` returns. The function pointers are copied into libinput's internal state. However, the `user_data` pointer (nil here) would need to be stable if used.

**Pitfall: `open_restricted` permissions.** The callback must open `/dev/input/eventN` devices. Without `input` group membership, this fails with EACCES. The callback should return the negative errno on failure (e.g. `return -13` for EACCES), not -1.

Correction: looking at the libinput API more carefully, `open_restricted` should return the fd on success, or a negative errno value on failure.

```c
// Correct error handling:
open_restricted: { (path, flags, userData) -> Int32 in
    let fd = input_shim_open(path, flags | O_CLOEXEC | O_NONBLOCK)
    if fd < 0 {
        return -input_shim_errno()
    }
    return fd
}
```

**dispatch — event processing:**

```swift
func dispatch() {
    libinput_dispatch(libinput)

    while let event = libinput_get_event(libinput) {
        defer { libinput_event_destroy(event) }

        let type = libinput_event_get_type(event)
        switch type {
        case LIBINPUT_EVENT_KEYBOARD_KEY:
            let kbEvent = libinput_event_get_keyboard_event(event)!
            let processed = keyboard.handleKey(event: kbEvent)
            onKeyboard?(processed)

        case LIBINPUT_EVENT_POINTER_MOTION:
            let ptrEvent = libinput_event_get_pointer_event(event)!
            let dx = libinput_event_pointer_get_dx(ptrEvent)
            let dy = libinput_event_pointer_get_dy(ptrEvent)
            pointer.applyDelta(dx: dx, dy: dy)
            let time = libinput_event_pointer_get_time_usec(ptrEvent)
            onPointer?(PointerInputEvent(
                timestamp: time, x: pointer.x, y: pointer.y,
                dx: dx, dy: dy,
                button: nil, isPressed: nil,
                scrollX: 0, scrollY: 0
            ))

        case LIBINPUT_EVENT_POINTER_MOTION_ABSOLUTE:
            let ptrEvent = libinput_event_get_pointer_event(event)!
            let x = libinput_event_pointer_get_absolute_x_transformed(
                ptrEvent, UInt32(pointer.screenWidth))
            let y = libinput_event_pointer_get_absolute_y_transformed(
                ptrEvent, UInt32(pointer.screenHeight))
            let dx = x - pointer.x
            let dy = y - pointer.y
            pointer.setAbsolute(x: x, y: y)
            let time = libinput_event_pointer_get_time_usec(ptrEvent)
            onPointer?(PointerInputEvent(
                timestamp: time, x: pointer.x, y: pointer.y,
                dx: dx, dy: dy,
                button: nil, isPressed: nil,
                scrollX: 0, scrollY: 0
            ))

        case LIBINPUT_EVENT_POINTER_BUTTON:
            let ptrEvent = libinput_event_get_pointer_event(event)!
            let button = libinput_event_pointer_get_button(ptrEvent)
            let pressed = libinput_event_pointer_get_button_state(ptrEvent) == LIBINPUT_BUTTON_STATE_PRESSED
            let time = libinput_event_pointer_get_time_usec(ptrEvent)
            onPointer?(PointerInputEvent(
                timestamp: time, x: pointer.x, y: pointer.y,
                dx: 0, dy: 0,
                button: button, isPressed: pressed,
                scrollX: 0, scrollY: 0
            ))

        case LIBINPUT_EVENT_POINTER_SCROLL_WHEEL,
             LIBINPUT_EVENT_POINTER_SCROLL_FINGER,
             LIBINPUT_EVENT_POINTER_SCROLL_CONTINUOUS:
            let ptrEvent = libinput_event_get_pointer_event(event)!
            var scrollX: Double = 0
            var scrollY: Double = 0
            if libinput_event_pointer_has_axis(ptrEvent, LIBINPUT_POINTER_AXIS_SCROLL_HORIZONTAL) != 0 {
                scrollX = libinput_event_pointer_get_scroll_value(ptrEvent, LIBINPUT_POINTER_AXIS_SCROLL_HORIZONTAL)
            }
            if libinput_event_pointer_has_axis(ptrEvent, LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL) != 0 {
                scrollY = libinput_event_pointer_get_scroll_value(ptrEvent, LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL)
            }
            let time = libinput_event_pointer_get_time_usec(ptrEvent)
            onPointer?(PointerInputEvent(
                timestamp: time, x: pointer.x, y: pointer.y,
                dx: 0, dy: 0,
                button: nil, isPressed: nil,
                scrollX: scrollX, scrollY: scrollY
            ))

        case LIBINPUT_EVENT_TOUCH_DOWN:
            let touchEvent = libinput_event_get_touch_event(event)!
            let slot = libinput_event_touch_get_seat_slot(touchEvent)
            let x = libinput_event_touch_get_x_transformed(touchEvent, UInt32(pointer.screenWidth))
            let y = libinput_event_touch_get_y_transformed(touchEvent, UInt32(pointer.screenHeight))
            let time = libinput_event_touch_get_time_usec(touchEvent)
            onTouch?(TouchInputEvent(timestamp: time, slot: slot, x: x, y: y, phase: .began))

        case LIBINPUT_EVENT_TOUCH_MOTION:
            let touchEvent = libinput_event_get_touch_event(event)!
            let slot = libinput_event_touch_get_seat_slot(touchEvent)
            let x = libinput_event_touch_get_x_transformed(touchEvent, UInt32(pointer.screenWidth))
            let y = libinput_event_touch_get_y_transformed(touchEvent, UInt32(pointer.screenHeight))
            let time = libinput_event_touch_get_time_usec(touchEvent)
            onTouch?(TouchInputEvent(timestamp: time, slot: slot, x: x, y: y, phase: .moved))

        case LIBINPUT_EVENT_TOUCH_UP:
            let touchEvent = libinput_event_get_touch_event(event)!
            let slot = libinput_event_touch_get_seat_slot(touchEvent)
            let time = libinput_event_touch_get_time_usec(touchEvent)
            onTouch?(TouchInputEvent(timestamp: time, slot: slot, x: 0, y: 0, phase: .ended))

        case LIBINPUT_EVENT_TOUCH_CANCEL:
            let touchEvent = libinput_event_get_touch_event(event)!
            let slot = libinput_event_touch_get_seat_slot(touchEvent)
            let time = libinput_event_touch_get_time_usec(touchEvent)
            onTouch?(TouchInputEvent(timestamp: time, slot: slot, x: 0, y: 0, phase: .cancelled))

        case LIBINPUT_EVENT_DEVICE_ADDED:
            let dev = libinput_event_get_device(event)
            let name = String(cString: libinput_device_get_name(dev))
            print("[Input] Device added: \(name)")

        case LIBINPUT_EVENT_DEVICE_REMOVED:
            let dev = libinput_event_get_device(event)
            let name = String(cString: libinput_device_get_name(dev))
            print("[Input] Device removed: \(name)")

        default:
            break // Ignore gesture events etc for now
        }
    }
}
```

**Pitfall: `libinput_event_get_time_usec` availability.** This was added in libinput 1.19. Ubuntu 25.04 has 1.27.1 — fine. If we ever need to support older distros, fall back to `_get_time()` (milliseconds).

**Pitfall: Touch coordinate origin.** `libinput_event_touch_get_x/y()` return coordinates in device-specific units (mm). Must use `_get_x_transformed(event, screen_width)` to get screen-space coordinates.

**Pitfall: Swift enum comparison with C enums.** `LIBINPUT_EVENT_KEYBOARD_KEY` etc are imported as `libinput_event_type` enum cases. The `switch` should work with them directly, but if Swift imports them as `Int32` raw values, may need `.rawValue` comparison.

---

## Part 3: Testing

### Standalone Input Test

Add a test binary that prints events to stdout:

```swift
// Sources/InputTest/main.swift
import InputBackend

let input = try InputManager(screenWidth: 1280, screenHeight: 800)

input.onKeyboard = { event in
    let action = event.isPressed ? "pressed" : "released"
    print("[Key] \(action) scancode=\(event.scancode) keysym=\(event.keysym) text=\(event.utf8 ?? "none")")
}

input.onPointer = { event in
    if let button = event.button {
        let action = event.isPressed! ? "pressed" : "released"
        print("[Ptr] button \(button) \(action) at (\(event.x), \(event.y))")
    } else if event.scrollX != 0 || event.scrollY != 0 {
        print("[Ptr] scroll (\(event.scrollX), \(event.scrollY))")
    } else {
        print("[Ptr] move (\(event.x), \(event.y))")
    }
}

// Simple poll loop
var pfd = pollfd(fd: input.fd, events: Int16(POLLIN), revents: 0)
while true {
    let ret = input_shim_poll(&pfd, 1, -1)  // block until event
    if ret > 0 {
        input.dispatch()
    }
}
```

### Test on VM

```bash
# Build
swift build --product InputTest

# Run (needs input group or sudo)
sudo .build/debug/InputTest

# Move mouse, press keys — should print events
# Ctrl+C to exit
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Permission denied on /dev/input | Known | Low | `sudo` or add to `input` group |
| xkb_keymap_new_from_names returns NULL | Low | High | Check for NULL, fall back to hardcoded US layout |
| VMware sends MOTION_ABSOLUTE not MOTION | Known | Low | Handle both absolute and relative paths |
| `libinput_interface` function pointers in Swift 6 | Low | Medium | Verified working in test package |
| Missing `linux/input-event-codes.h` | Low | Low | Comes with linux-libc-dev (always installed) |
| `XKB_MOD_NAME_*` not importable as strings | Medium | Low | Define as `static const char*` in shim header |
| Event timestamp overflow | Very Low | Low | UInt64 microseconds won't overflow for centuries |
