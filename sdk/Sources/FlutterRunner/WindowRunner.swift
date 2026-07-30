// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Flutter
import FlutterEmbedderBridge
import FlutterSwiftBridge
import GLFWBridge
import SwiftRuntime
import Foundation
import Glibc

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Windowed host
// ═══════════════════════════════════════════════════════════════════════════
//
// Runs a Swift Flutter app in a desktop window: GLFW for the window and input,
// OpenGL ES 2 through EGL for the surface, the embedder API for the engine.
// One binary covers X11 and Wayland — GLFW 3.4 selects the backend at runtime
// from the environment, so a Wayland session needs no separate build.
//
// This is the host that used to live inside a demo app's `main.swift`, which
// meant an app could not use it without copying ~600 lines. Everything
// app-specific is now in `WindowOptions`.

/// How the window comes up.
public struct WindowOptions: Sendable {
    public var title: String
    public var width: Int
    public var height: Int

    public init(title: String = "Flutter Swift", width: Int = 1100, height: Int = 700) {
        self.title = title
        self.width = width
        self.height = height
    }
}

/// Runs `app` in a desktop window and does not return.
///
/// Inside the Starling desktop this defers to `runApp`, which renders into the
/// shared DMA-BUF the shell composites — so the same executable is both a
/// standalone Linux app and a Starling app, decided by the environment the
/// shell sets rather than by a build flag.
public func runAppWindowed(_ app: Widget, options: WindowOptions = WindowOptions()) -> Never {
    if let socket = ProcessInfo.processInfo.environment["FLUTTER_DMABUF_SOCKET"],
       !socket.isEmpty {
        runApp(app)          // composited child of the shell; never returns
        exit(0)
    }

    guard let assets = FlutterAssets.locate() else {
        logError("""
            [FlutterRunner] cannot find flutter_assets and icudtl.dat.
            Looked in:
            \(FlutterAssets.lastSearch.map { "  \($0)" }.joined(separator: "\n"))
            Set FLUTTER_ASSETS_DIR and FLUTTER_ICU_DATA, or FLUTTER_ENGINE_OUT,
            or put both beside the executable.
            """)
        exit(1)
    }

    trace("start")
    guard glfwInit() != 0 else {
        logError("[FlutterRunner] glfwInit() failed — no X11 or Wayland display?")
        exit(1)
    }

    // OpenGL ES 2.0 via EGL. GLFW falls back to desktop GL if EGL context
    // creation fails.
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API)
    glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_EGL_CONTEXT_API)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)

    guard let mainWindow = glfwCreateWindow(
        Int32(options.width), Int32(options.height), options.title, nil, nil
    ) else {
        glfwTerminate()
        logError("[FlutterRunner] glfwCreateWindow() failed")
        exit(1)
    }

    // Invisible 1x1 window whose GL context is shared with the main one: the
    // engine's resource uploads run on it off the raster thread.
    glfwWindowHint(GLFW_VISIBLE, 0)
    let resourceWindow = glfwCreateWindow(1, 1, "", nil, mainWindow)
    glfwWindowHint(GLFW_VISIBLE, 1)

    trace("window created")
    let state = WindowState()
    state.window = mainWindow
    state.resourceWindow = resourceWindow
    let statePtr = Unmanaged.passRetained(state).toOpaque()
    glfwSetWindowUserPointer(mainWindow, statePtr)

    // Build the widget tree and the Shell→Framework callback table before the
    // engine starts, so the first frame has something to render.
    runApp(app)
    var callbacks = createRuntimeCallbacks()

    var rendererConfig = FlutterRendererConfig()
    rendererConfig.type = kOpenGL
    rendererConfig.open_gl.struct_size = MemoryLayout<FlutterOpenGLRendererConfig>.size
    rendererConfig.open_gl.make_current = { userData -> Bool in
        guard let userData else { return false }
        glfwMakeContextCurrent(windowState(userData).window)
        return true
    }
    rendererConfig.open_gl.clear_current = { _ -> Bool in
        glfwMakeContextCurrent(nil)
        return true
    }
    rendererConfig.open_gl.present = { userData -> Bool in
        guard let userData else { return false }
        let state = windowState(userData)
        trace("present #\(state.presentCount)")
        state.presentCount += 1
        glfwSwapBuffers(state.window)
        trace("swapBuffers returned")
        return true
    }
    rendererConfig.open_gl.fbo_callback = { _ -> UInt32 in 0 }  // on-screen
    rendererConfig.open_gl.make_resource_current = { userData -> Bool in
        guard let userData else { return false }
        glfwMakeContextCurrent(windowState(userData).resourceWindow)
        return true
    }
    rendererConfig.open_gl.gl_proc_resolver = { _, name -> UnsafeMutableRawPointer? in
        guard let name, let fn = glfwGetProcAddress(name) else { return nil }
        return unsafeBitCast(fn, to: UnsafeMutableRawPointer.self)
    }

    // The engine posts platform-thread tasks from arbitrary threads; they are
    // drained on this thread in the event loop below.
    var platformTaskRunner = FlutterTaskRunnerDescription()
    platformTaskRunner.struct_size = MemoryLayout<FlutterTaskRunnerDescription>.size
    platformTaskRunner.user_data = statePtr
    platformTaskRunner.runs_task_on_current_thread_callback = { userData -> Bool in
        guard let userData else { return false }
        return pthread_equal(pthread_self(), windowState(userData).mainThread) != 0
    }
    platformTaskRunner.post_task_callback = { task, targetTimeNanos, userData in
        guard let userData else { return }
        windowState(userData).taskQueue.enqueue(task, targetNanos: targetTimeNanos)
    }
    var taskRunners = FlutterCustomTaskRunners()
    taskRunners.struct_size = MemoryLayout<FlutterCustomTaskRunners>.size

    var args = FlutterProjectArgs()
    args.struct_size = MemoryLayout<FlutterProjectArgs>.size
    let assetsPath = strdup(assets.assets)!
    let icuPath = strdup(assets.icuData)!
    args.assets_path = UnsafePointer(assetsPath)
    args.icu_data_path = UnsafePointer(icuPath)

    // Skia's GL backend: Impeller is off for broader GPU compatibility, and
    // this path has to work on llvmpipe as well as real hardware.
    let argv0 = strdup(options.title)!
    let argv1 = strdup("--enable-impeller=false")!
    let argvBuf = UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: 3)
    argvBuf[0] = UnsafePointer(argv0)
    argvBuf[1] = UnsafePointer(argv1)
    argvBuf[2] = nil
    args.command_line_argc = 2
    args.command_line_argv = UnsafePointer(argvBuf.baseAddress!)

    var engine: OpaquePointer? = nil
    let initResult = withUnsafeMutablePointer(to: &callbacks) { cbPtr in
        withUnsafeMutablePointer(to: &platformTaskRunner) { taskRunnerPtr in
            taskRunners.platform_task_runner = UnsafePointer(taskRunnerPtr)
            return withUnsafeMutablePointer(to: &taskRunners) { taskRunnersPtr in
                args.custom_task_runners = UnsafePointer(taskRunnersPtr)
                return FlutterEngineInitializeSwift(
                    Int(FLUTTER_ENGINE_VERSION),
                    &rendererConfig,
                    &args,
                    statePtr,
                    UnsafeRawPointer(cbPtr),
                    &engine
                )
            }
        }
    }
    guard initResult == kSuccess, let engine else {
        glfwTerminate()
        logError("[FlutterRunner] FlutterEngineInitializeSwift failed")
        exit(1)
    }
    state.engine = engine

    trace("engine initialized")
    guard FlutterEngineRunInitializedSwift(engine) == kSuccess else {
        glfwTerminate()
        logError("[FlutterRunner] FlutterEngineRunInitializedSwift failed")
        exit(1)
    }

    glfwSetFramebufferSizeCallback(mainWindow, onFramebufferSize)
    glfwSetCursorPosCallback(mainWindow, onCursorPos)
    glfwSetCursorEnterCallback(mainWindow, onCursorEnter)
    glfwSetMouseButtonCallback(mainWindow, onMouseButton)
    glfwSetScrollCallback(mainWindow, onScroll)
    glfwSetKeyCallback(mainWindow, onKey)

    var widthPx: Int32 = 0, heightPx: Int32 = 0
    glfwGetFramebufferSize(mainWindow, &widthPx, &heightPx)
    onFramebufferSize(mainWindow, widthPx, heightPx)

    trace("engine running, first frame scheduled")
    PlatformDispatcher.instance.scheduleFrame()

    // Event loop. It replaces RunLoop.main.run() but must still spin the
    // Foundation run loop, or framework timers (animation, gesture recognisers)
    // never fire.
    while glfwWindowShouldClose(mainWindow) == 0 {
        let (expired, nextNanos) = state.taskQueue.drainExpired()
        for (task, _) in expired {
            var mutableTask = task
            FlutterEngineRunTask(engine, &mutableTask)
        }

        _ = Foundation.RunLoop.main.run(
            mode: .default, before: Date(timeIntervalSinceNow: 0.001))

        if let nextNanos {
            let now = FlutterEngineGetCurrentTime()
            if nextNanos > now {
                glfwWaitEventsTimeout(min(Double(nextNanos - now) / 1_000_000_000.0, 0.016))
            } else {
                glfwPollEvents()
            }
        } else {
            glfwWaitEventsTimeout(0.016)  // ~60 Hz
        }
    }

    FlutterEngineShutdown(engine)
    glfwDestroyWindow(mainWindow)
    if let resourceWindow { glfwDestroyWindow(resourceWindow) }
    glfwTerminate()
    Unmanaged<WindowState>.fromOpaque(statePtr).release()
    exit(0)
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - State
// ═══════════════════════════════════════════════════════════════════════════

/// State shared between GLFW callbacks and the embedder, reached through
/// GLFW's per-window user pointer and the embedder's `user_data`.
///
/// Deliberately not @MainActor: engine callbacks arrive on the io and raster
/// threads. Access is hand-synchronised — GLFW callbacks on the main thread,
/// the task queue under its own lock.
final class WindowState: @unchecked Sendable {
    nonisolated(unsafe) var window: OpaquePointer? = nil
    nonisolated(unsafe) var resourceWindow: OpaquePointer? = nil
    nonisolated(unsafe) var engine: OpaquePointer? = nil

    nonisolated(unsafe) var pixelsPerScreenCoord: Double = 1.0

    // Pointer state machine, mirroring flutter_glfw.cc
    nonisolated(unsafe) var pointerAdded = false
    nonisolated(unsafe) var pointerDown = false
    nonisolated(unsafe) var buttons: Int64 = 0

    nonisolated(unsafe) var presentCount = 0

    nonisolated let taskQueue = RunnerTaskQueue()
    nonisolated let mainThread = pthread_self()
}

private func windowState(_ ptr: UnsafeMutableRawPointer) -> WindowState {
    Unmanaged<WindowState>.fromOpaque(ptr).takeUnretainedValue()
}

private func windowState(ofWindow window: OpaquePointer?) -> WindowState? {
    guard let window, let ptr = glfwGetWindowUserPointer(window) else { return nil }
    return Unmanaged<WindowState>.fromOpaque(ptr).takeUnretainedValue()
}

/// Engine tasks posted from arbitrary threads, drained on the main thread.
final class RunnerTaskQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [(task: FlutterTask, targetNanos: UInt64)] = []

    func enqueue(_ task: FlutterTask, targetNanos: UInt64) {
        lock.lock()
        tasks.append((task, targetNanos))
        lock.unlock()
        glfwPostEmptyEvent()   // wake the event loop so it can drain this
    }

    /// (tasks whose deadline has passed, the next deadline still pending).
    func drainExpired() -> (expired: [(FlutterTask, UInt64)], nextNanos: UInt64?) {
        let now = FlutterEngineGetCurrentTime()
        lock.lock()
        defer { lock.unlock() }
        var expired: [(FlutterTask, UInt64)] = []
        var remaining: [(task: FlutterTask, targetNanos: UInt64)] = []
        for entry in tasks {
            if entry.targetNanos <= now {
                expired.append((entry.task, entry.targetNanos))
            } else {
                remaining.append(entry)
            }
        }
        tasks = remaining
        return (expired, remaining.map(\.targetNanos).min())
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Input
// ═══════════════════════════════════════════════════════════════════════════

/// Sends a pointer event, synthesising the kAdd the engine requires before it
/// will accept anything else for a device.
func sendPointerEvent(
    _ state: WindowState,
    phase: FlutterPointerPhase,
    x: Double,
    y: Double,
    signalKind: FlutterPointerSignalKind = kFlutterPointerSignalKindNone,
    scrollDeltaX: Double = 0,
    scrollDeltaY: Double = 0,
    buttons: Int64 = 0
) {
    guard let engine = state.engine else { return }

    if !state.pointerAdded && phase != kAdd {
        sendPointerEvent(state, phase: kAdd, x: x, y: y)
    }
    if state.pointerAdded && phase == kAdd { return }

    var event = FlutterPointerEvent()
    event.struct_size = MemoryLayout<FlutterPointerEvent>.size
    event.phase = phase
    event.timestamp = Int(FlutterEngineGetCurrentTime() / 1000)  // ns → µs
    event.x = x * state.pixelsPerScreenCoord
    event.y = y * state.pixelsPerScreenCoord
    event.device = 0
    event.signal_kind = signalKind
    event.scroll_delta_x = scrollDeltaX
    event.scroll_delta_y = scrollDeltaY
    event.device_kind = kFlutterPointerDeviceKindMouse
    event.buttons = buttons
    event.view_id = 0
    FlutterEngineSendPointerEvent(engine, &event, 1)

    switch phase {
    case kAdd:    state.pointerAdded = true
    case kRemove: state.pointerAdded = false
    case kDown:   state.pointerDown = true
    case kUp:     state.pointerDown = false
    default: break
    }
}

/// The phase implied by the current button state (flutter_glfw.cc's machine).
func pointerPhaseForButtonState(_ state: WindowState) -> FlutterPointerPhase {
    if state.buttons == 0 {
        return state.pointerDown ? kUp : kHover
    }
    return state.pointerDown ? kMove : kDown
}

// GLFW hands these to C, so they must be non-capturing.

let onFramebufferSize: @convention(c) (OpaquePointer?, Int32, Int32) -> Void = {
    window, widthPx, heightPx in
    guard let state = windowState(ofWindow: window), let engine = state.engine else { return }
    var widthScreen: Int32 = 0
    glfwGetWindowSize(window, &widthScreen, nil)
    state.pixelsPerScreenCoord = widthScreen > 0
        ? Double(widthPx) / Double(widthScreen) : 1.0

    var metrics = FlutterWindowMetricsEvent()
    metrics.struct_size = MemoryLayout<FlutterWindowMetricsEvent>.size
    metrics.width = Int(widthPx)
    metrics.height = Int(heightPx)
    metrics.pixel_ratio = state.pixelsPerScreenCoord
    metrics.view_id = 0
    FlutterEngineSendWindowMetricsEvent(engine, &metrics)
}

let onCursorPos: @convention(c) (OpaquePointer?, Double, Double) -> Void = { window, x, y in
    guard let state = windowState(ofWindow: window) else { return }
    sendPointerEvent(state, phase: pointerPhaseForButtonState(state),
                     x: x, y: y, buttons: state.buttons)
}

let onCursorEnter: @convention(c) (OpaquePointer?, Int32) -> Void = { window, entered in
    guard let state = windowState(ofWindow: window) else { return }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    sendPointerEvent(state, phase: entered != 0 ? kAdd : kRemove, x: x, y: y)
}

let onMouseButton: @convention(c) (OpaquePointer?, Int32, Int32, Int32) -> Void = {
    window, key, action, _ in
    guard let state = windowState(ofWindow: window) else { return }
    let button: Int64
    switch key {
    case GLFW_MOUSE_BUTTON_LEFT:   button = Int64(kFlutterPointerButtonMousePrimary.rawValue)
    case GLFW_MOUSE_BUTTON_RIGHT:  button = Int64(kFlutterPointerButtonMouseSecondary.rawValue)
    case GLFW_MOUSE_BUTTON_MIDDLE: button = Int64(kFlutterPointerButtonMouseMiddle.rawValue)
    default: return
    }
    if action == GLFW_PRESS {
        state.buttons |= button
    } else {
        state.buttons &= ~button
    }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    sendPointerEvent(state, phase: pointerPhaseForButtonState(state),
                     x: x, y: y, buttons: state.buttons)
}

let onScroll: @convention(c) (OpaquePointer?, Double, Double) -> Void = {
    window, deltaX, deltaY in
    guard let state = windowState(ofWindow: window) else { return }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    let multiplier = 20.0   // matches flutter_glfw.cc
    sendPointerEvent(
        state, phase: pointerPhaseForButtonState(state), x: x, y: y,
        signalKind: kFlutterPointerSignalKindScroll,
        scrollDeltaX: deltaX * multiplier,
        scrollDeltaY: -deltaY * multiplier,
        buttons: state.buttons
    )
}

let onKey: @convention(c) (OpaquePointer?, Int32, Int32, Int32, Int32) -> Void = {
    window, key, _, action, _ in
    guard let state = windowState(ofWindow: window), let engine = state.engine else { return }
    let type: FlutterKeyEventType
    switch action {
    case GLFW_PRESS:   type = kFlutterKeyEventTypeDown
    case GLFW_REPEAT:  type = kFlutterKeyEventTypeRepeat
    case GLFW_RELEASE: type = kFlutterKeyEventTypeUp
    default: return
    }

    let physical = glfwKeyToHID(Int(key))
    var event = FlutterKeyEvent()
    event.struct_size = MemoryLayout<FlutterKeyEvent>.size
    event.timestamp = Double(FlutterEngineGetCurrentTime()) / 1000.0
    event.type = type
    event.physical = physical
    event.logical = physical     // simplified: no layout mapping yet
    event.character = nil
    event.synthesized = false
    event.device_type = kFlutterKeyEventDeviceTypeKeyboard
    FlutterEngineSendKeyEvent(engine, &event, nil, nil)
}

/// GLFW key code → USB HID usage page 0x07. Covers A-Z, 0-9, arrows,
/// modifiers and the common editing keys; anything else goes through with a
/// flag bit so it is inert rather than colliding with a real usage.
func glfwKeyToHID(_ key: Int) -> UInt64 {
    switch key {
    case 65...90: return UInt64(key - 65 + 0x04)   // A-Z (ASCII 65-90)
    case 48:      return 0x27                       // 0
    case 49...57: return UInt64(key - 49 + 0x1E)   // 1-9
    case 262: return 0x4F   // Right
    case 263: return 0x50   // Left
    case 264: return 0x51   // Down
    case 265: return 0x52   // Up
    case 256: return 0x29   // Escape
    case 257: return 0x28   // Enter
    case 258: return 0x2B   // Tab
    case 259: return 0x2A   // Backspace
    case 32:  return 0x2C   // Space
    case 340: return 0xE1   // Left Shift
    case 341: return 0xE0   // Left Control
    case 342: return 0xE2   // Left Alt
    case 344: return 0xE5   // Right Shift
    case 345: return 0xE4   // Right Control
    case 346: return 0xE6   // Right Alt
    default:  return UInt64(key) | 0x00100000000
    }
}

/// Startup milestones, when FLUTTER_RUNNER_TRACE is set. A host that shows
/// nothing for a while gives no way to tell a slow first frame from a hang.
private nonisolated(unsafe) let traceStart = DispatchTime.now().uptimeNanoseconds
private nonisolated(unsafe) let traceEnabled =
    !(ProcessInfo.processInfo.environment["FLUTTER_RUNNER_TRACE"] ?? "").isEmpty

func trace(_ message: String) {
    guard traceEnabled else { return }
    // Read the epoch BEFORE sampling the clock. `traceStart` is a global, so
    // it initialises lazily on first access — inside this very expression if
    // written inline, which samples it *after* `now` and makes the UInt64
    // subtraction underflow. That traps as an illegal instruction with no
    // message at all, so a tracing knob meant to explain a slow startup
    // instead kills the process before it prints a line.
    let start = traceStart
    let now = DispatchTime.now().uptimeNanoseconds
    let tenths = (now > start ? now - start : 0) / 100_000
    // Plain interpolation, not String(format:): swift-corelibs-foundation
    // traps on a `%@` whose argument is a Swift String.
    FileHandle.standardError.write(Data(
        "[FlutterRunner] \(tenths / 10).\(tenths % 10) ms  \(message)\n".utf8))
}

/// stderr, not print: stdout is block-buffered through a pipe, and a host that
/// dies during startup should still say why.
func logError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
#endif
