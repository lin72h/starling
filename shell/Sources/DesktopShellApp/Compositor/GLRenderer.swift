// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(Linux)
import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - GL Constants (GLES2)
// ═══════════════════════════════════════════════════════════════════════════════

private let GL_FRAMEBUFFER: UInt32     = 0x8D40
private let GL_COLOR_ATTACHMENT0: UInt32 = 0x8CE0
private let GL_TEXTURE_2D: UInt32      = 0x0DE1
private let GL_RGBA: UInt32            = 0x1908
private let GL_UNSIGNED_BYTE: UInt32   = 0x1401
private let GL_COLOR_BUFFER_BIT: UInt32 = 0x4000
private let GL_SCISSOR_TEST: UInt32    = 0x0C11
private let GL_FRAMEBUFFER_BINDING: UInt32 = 0x8CA6
private let GL_RENDERBUFFER: UInt32   = 0x8D41
private let GL_STENCIL_ATTACHMENT: UInt32 = 0x8D20
private let GL_STENCIL_INDEX8: UInt32 = 0x8D48

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - GL Function Types
// ═══════════════════════════════════════════════════════════════════════════════

private typealias GLGenFramebuffersFunc   = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLBindFramebufferFunc   = @convention(c) (UInt32, UInt32) -> Void
private typealias GLFramebufferTexture2DFunc = @convention(c) (UInt32, UInt32, UInt32, UInt32, Int32) -> Void
private typealias GLDeleteFramebuffersFunc = @convention(c) (Int32, UnsafePointer<UInt32>?) -> Void
private typealias GLViewportFunc          = @convention(c) (Int32, Int32, Int32, Int32) -> Void
private typealias GLClearColorFunc        = @convention(c) (Float, Float, Float, Float) -> Void
private typealias GLClearFunc             = @convention(c) (UInt32) -> Void
private typealias GLScissorFunc           = @convention(c) (Int32, Int32, Int32, Int32) -> Void
private typealias GLEnableFunc            = @convention(c) (UInt32) -> Void
private typealias GLDisableFunc           = @convention(c) (UInt32) -> Void
private typealias GLFlushFunc             = @convention(c) () -> Void
private typealias GLGetIntegervFunc      = @convention(c) (UInt32, UnsafeMutablePointer<Int32>?) -> Void
private typealias GLGenRenderbuffersFunc = @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
private typealias GLBindRenderbufferFunc = @convention(c) (UInt32, UInt32) -> Void
private typealias GLRenderbufferStorageFunc = @convention(c) (UInt32, UInt32, Int32, Int32) -> Void
private typealias GLFramebufferRenderbufferFunc = @convention(c) (UInt32, UInt32, UInt32, UInt32) -> Void

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - GLRenderer
// ═══════════════════════════════════════════════════════════════════════════════

/// Renders the animated gradient + bouncing ball directly on the GPU using
/// GLES2 FBO + glScissor/glClear. Replaces the CPU-based SoftwareRenderer.
///
/// Animation state is advanced on the main thread (via `advanceAnimation`).
/// Rendering happens on the raster thread (via `renderToTexture`) where GL
/// context is current.
class GLRenderer {

    let width: Int
    let height: Int

    // Animation state (updated on main thread)
    private var frameCount: Int = 0
    private var ballX: Float = 100
    private var ballY: Float = 100
    private var ballDX: Float = 3.0
    private var ballDY: Float = 2.0
    private let ballRadius: Float = 25.0

    // GL state (initialized on raster thread)
    private var glInitialized = false
    private var fbo: UInt32 = 0

    // GL function pointers (scissor-based rendering, no shaders needed)
    private var _glGenFramebuffers: GLGenFramebuffersFunc!
    private var _glBindFramebuffer: GLBindFramebufferFunc!
    private var _glFramebufferTexture2D: GLFramebufferTexture2DFunc!
    private var _glDeleteFramebuffers: GLDeleteFramebuffersFunc!
    private var _glViewport: GLViewportFunc!
    private var _glClearColor: GLClearColorFunc!
    private var _glClear: GLClearFunc!
    private var _glScissor: GLScissorFunc!
    private var _glEnable: GLEnableFunc!
    private var _glDisable: GLDisableFunc!
    private var _glFlush: GLFlushFunc!
    private var _glGetIntegerv: GLGetIntegervFunc!
    private var _glGenRenderbuffers: GLGenRenderbuffersFunc!
    private var _glBindRenderbuffer: GLBindRenderbufferFunc!
    private var _glRenderbufferStorage: GLRenderbufferStorageFunc!
    private var _glFramebufferRenderbuffer: GLFramebufferRenderbufferFunc!

    /// GL proc address resolver (must be set before first render).
    var glProcAddressResolver: ((UnsafePointer<CChar>) -> UnsafeMutableRawPointer?)?

    /// Whether animation state has changed since last render.
    private(set) var dirty = true

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    deinit {
        if fbo != 0 {
            var f = fbo
            _glDeleteFramebuffers?(1, &f)
        }
    }

    // MARK: - Animation State (main thread)

    /// Advances the animation state. Called on the main thread from the
    /// vsync-driven tick. Marks the renderer as dirty.
    func advanceAnimation() {
        frameCount += 1
        let w = Float(width), h = Float(height)

        ballX += ballDX
        ballY += ballDY
        if ballX - ballRadius < 0 || ballX + ballRadius > w {
            ballDX = -ballDX
            ballX = max(ballRadius, min(w - ballRadius, ballX))
        }
        if ballY - ballRadius < 0 || ballY + ballRadius > h {
            ballDY = -ballDY
            ballY = max(ballRadius, min(h - ballRadius, ballY))
        }
        dirty = true
    }

    // MARK: - GL Rendering (raster thread)

    /// Renders the animation directly to the given GL texture using an FBO.
    /// Uses glScissor + glClear for all drawing (no shaders, no vertex state).
    /// Called from the raster thread inside populateTexture.
    ///
    /// IMPORTANT: This runs on the raster thread while Skia has its own FBO bound.
    /// We must save/restore the previous FBO binding so Skia's state isn't corrupted.
    /// The FBO also needs a stencil renderbuffer — without it, Skia's stencil
    /// attachment check fails for subsequent drawPath operations (e.g. diamond icon).
    func renderToTexture(_ textureName: UInt32) {
        if !glInitialized {
            loadGLFunctions()

            // Save Skia's FBO before any GL calls that change framebuffer binding.
            var savedFbo: Int32 = 0
            _glGetIntegerv(GL_FRAMEBUFFER_BINDING, &savedFbo)

            _glGenFramebuffers(1, &fbo)

            // Attach a stencil renderbuffer to our FBO.
            var rbo: UInt32 = 0
            _glGenRenderbuffers(1, &rbo)
            _glBindRenderbuffer(GL_RENDERBUFFER, rbo)
            _glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8,
                                   Int32(width), Int32(height))
            _glBindFramebuffer(GL_FRAMEBUFFER, fbo)
            _glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                       GL_RENDERBUFFER, rbo)
            // Restore Skia's FBO after init (don't bind 0).
            _glBindFramebuffer(GL_FRAMEBUFFER, UInt32(savedFbo))
            _glBindRenderbuffer(GL_RENDERBUFFER, 0)

            glInitialized = true
        }

        dirty = false

        // Save Skia's current FBO binding so we can restore it when done.
        var prevFbo: Int32 = 0
        _glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFbo)

        // Bind our FBO with texture attachment.
        _glBindFramebuffer(GL_FRAMEBUFFER, fbo)
        _glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                 GL_TEXTURE_2D, textureName, 0)
        _glViewport(0, 0, Int32(width), Int32(height))

        // Disable scissor for full-screen clear.
        _glDisable(GL_SCISSOR_TEST)

        // Animated gradient background via glClear.
        let phase = Float(frameCount) * 0.02
        let r = (sinf(phase) + 1.0) * 0.15 + 0.1
        let g = (sinf(phase + 2.0) + 1.0) * 0.15 + 0.05
        let b = (sinf(phase + 4.0) + 1.0) * 0.2 + 0.15
        _glClearColor(r, g, b, 1.0)
        _glClear(GL_COLOR_BUFFER_BIT)

        // Draw bouncing ball using scissor + clear.
        // FBO origin is bottom-left; our coordinate system is top-left.
        _glEnable(GL_SCISSOR_TEST)
        let br = Int32(ballRadius)
        let bx = Int32(ballX) - br
        let by = Int32(Float(height) - ballY) - br  // flip Y for FBO
        let bd = br * 2

        _glScissor(bx, by, bd, bd)
        _glClearColor(1.0, 0.85, 0.0, 1.0)
        _glClear(GL_COLOR_BUFFER_BIT)

        // Highlight on ball (small lighter square offset to upper-left).
        let hlSize: Int32 = br / 2
        let hlX = bx + br / 4
        let hlY = by + bd - br / 4 - hlSize  // upper-left in FBO coords
        _glScissor(hlX, hlY, hlSize, hlSize)
        _glClearColor(1.0, 0.95, 0.6, 1.0)
        _glClear(GL_COLOR_BUFFER_BIT)

        // Restore state.
        _glDisable(GL_SCISSOR_TEST)
        _glFlush()

        // Detach texture from our FBO and restore Skia's FBO binding.
        _glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                 GL_TEXTURE_2D, 0, 0)
        _glBindFramebuffer(GL_FRAMEBUFFER, UInt32(prevFbo))
    }

    // MARK: - GL Initialization

    private func loadGLFunctions() {
        func load<T>(_ name: String) -> T {
            guard let resolver = glProcAddressResolver else {
                fatalError("[GLRenderer] No GL proc address resolver set")
            }
            guard let fn = name.withCString({ resolver($0) }) else {
                fatalError("[GLRenderer] Failed to load GL function: \(name)")
            }
            return unsafeBitCast(fn, to: T.self)
        }

        _glGenFramebuffers       = load("glGenFramebuffers")
        _glBindFramebuffer       = load("glBindFramebuffer")
        _glFramebufferTexture2D  = load("glFramebufferTexture2D")
        _glDeleteFramebuffers    = load("glDeleteFramebuffers")
        _glViewport              = load("glViewport")
        _glClearColor            = load("glClearColor")
        _glClear                 = load("glClear")
        _glScissor               = load("glScissor")
        _glEnable                = load("glEnable")
        _glDisable               = load("glDisable")
        _glFlush                 = load("glFlush")
        _glGetIntegerv           = load("glGetIntegerv")
        _glGenRenderbuffers      = load("glGenRenderbuffers")
        _glBindRenderbuffer      = load("glBindRenderbuffer")
        _glRenderbufferStorage   = load("glRenderbufferStorage")
        _glFramebufferRenderbuffer = load("glFramebufferRenderbuffer")
    }
}

#endif
