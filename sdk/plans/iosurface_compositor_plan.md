# Cross-Process IOSurface Compositor

## Context

The `OffscreenFlutterApp` renders a Flutter widget tree in-process by manually running build/layout/paint, rasterizing to a CVPixelBuffer, and compositing as a FlutterTexture. The user wants `FlutterDemoApp` to be a **real standalone process** whose output is displayed inside the DesktopShell's window manager.

The solution: the child process renders to an **IOSurface** (Apple's cross-process shared GPU memory), sends the surface ID to the parent via stdout, and the parent wraps it as a FlutterTexture — zero-copy.

## Data Flow

```
Child Process (FlutterDemoApp)              Parent Process (DesktopShellApp)
──────────────────────────────              ────────────────────────────────
FlutterEngine (headless, for Skia)
Widget tree → build/layout/paint
PictureLayer → toImageSync → toByteData
RGBA→BGRA swizzle → IOSurface write

stdout: "SURFACE:12345:640:480\n" ───────► Process.standardOutput pipe
                                            IOSurfaceLookup(12345) → IOSurface
stdout: "F\n" (each frame)       ───────► CVPixelBufferCreateWithIOSurface
                                            engine.textureFrameAvailable()
                                            TextureWidget in DesktopWindow
```

## Files to Create

### 1. `Sources/FlutterDemoApp/IOSurfaceRenderer.swift` (new)

Variant of `OffscreenFlutterApp` that writes to an IOSurface + stdout IPC.

- Reuse the same pattern from `OffscreenFlutterApp.swift` (BuildOwner, PipelineOwner, RenderView, findPictureLayer, RGBA→BGRA swizzle)
- Create IOSurface with `.width/.height/.bytesPerElement/.bytesPerRow/.pixelFormat/.allocSize` properties, BGRA format
- Write pixels to `surface.baseAddress` inside `surface.lock()`/`surface.unlock()`
- First frame: print `SURFACE:<IOSurfaceGetID>:<width>:<height>\n` to stdout
- Subsequent frames: print `F\n` to stdout
- Use **Foundation Timer on main thread** (not DispatchQueue) for the render loop — avoids thread-safety issues since FlutterDemoApp's animation Timer also fires on main thread via setState

### 2. `Sources/DesktopShellApp/Compositor/ProcessAppManager.swift` (new)

Parent-side manager that launches child processes and bridges IOSurface to FlutterTexture.

**ProcessAppManager class:**
- `launchApp(executableName:, onReady: (Int64) -> Void, onTerminated: () -> Void)` — finds executable next to current binary, creates Pipe for stdout, starts Process, reads stdout asynchronously
- Parse `SURFACE:<id>:<w>:<h>` line → `IOSurfaceLookup(id)` → create `IOSurfaceTexture` → `engine.register(texture)` → call `onReady(textureId)` on main thread
- Parse `F` lines → `engine.textureFrameAvailable(textureId)` on main thread
- `destroyApp(textureId:)` — terminate process, unregister texture
- Track entries in `apps: [Int64: ProcessAppEntry]`

**IOSurfaceTexture class** (in same file):
- Conforms to `FlutterTexture`
- Init: `CVPixelBufferCreateWithIOSurface(surface)` — zero-copy wrapper
- `copyPixelBuffer()` → returns `Unmanaged.passRetained(pixelBuffer)` (same CVPixelBuffer each time, backed by shared IOSurface memory)

## Files to Modify

### 3. `Sources/FlutterDemoApp/main.swift` (rewrite)

Convert from windowed app to headless IOSurface producer:
- `app.setActivationPolicy(.accessory)` — no dock icon
- `setbuf(stdout, nil)` — disable stdout buffering
- Start FlutterEngine headless (for Skia init)
- Create FlutterViewController (for implicit view creation)
- Create hidden 1x1 borderless NSWindow for the VC (satisfies NSView requirements)
- Do NOT call `runApp()` — IOSurfaceRenderer has its own render pipeline
- Create `IOSurfaceRenderer(width: 640, height: 480)`
- Mount widget: `Directionality(textDirection: .ltr, child: FlutterDemoApp())`
- Start renderer at 30fps
- `app.run()` for the event loop

### 4. `Sources/DesktopShellApp/main.swift` (edit)

Add global: `nonisolated(unsafe) var processAppManager: ProcessAppManager? = nil`
Initialize after engine starts: `processAppManager = ProcessAppManager(engine: engine)`

### 5. `Sources/DesktopShellApp/Shell/DesktopShell.swift` (edit)

Replace the `case "flutterapp":` block to use ProcessAppManager:
- Call `processAppManager.launchApp(executableName: "FlutterDemoApp", ...)`
- In `onReady` callback: `setState { windowManager.addWindow(textureId: Int(texId), ...) }`
- In `onWindowClose`: `processAppManager.destroyApp(textureId:)`
- Remove the `_launchExternalProcess` method and `launchedProcesses` dict (no longer needed)

### 6. `Package.swift` (edit)

Add `-framework IOSurface` to linkerSettings for both `FlutterDemoApp` and `DesktopShellApp` targets.

## Key API References

| API | Purpose |
|-----|---------|
| `IOSurface(properties:)` | Create shared GPU memory buffer |
| `IOSurfaceGetID(surface)` → `UInt32` | Get globally-unique surface ID |
| `IOSurfaceLookup(id)` → `IOSurface?` | Cross-process lookup by ID (deprecated but works on macOS 14) |
| `surface.lock(options:seed:)` / `.unlock()` | Synchronize writes |
| `surface.baseAddress` | Raw pixel pointer |
| `CVPixelBufferCreateWithIOSurface()` | Zero-copy CVPixelBuffer wrapper around IOSurface |

## Verification

1. `swift build --product FlutterDemoApp && swift build --product DesktopShellApp` — both compile
2. Run `FlutterDemoApp` standalone — should print `SURFACE:...` to stdout and `F` lines, no window appears
3. Run `DesktopShellApp` → click "Flutter App" in start menu → child process launches, IOSurface is shared, animated demo appears in a compositor window
4. Close the window → child process terminates
