// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - DesktopWindow

/// A single desktop window with title bar chrome, content area, and resize handles.
/// Clicking anywhere in the window brings it to front.
class DesktopWindow: StatelessWidget {

    /// How thick the pane's edge reads, in logical pixels. A window is
    /// about 2.6 m of room per 1280 px, so two logical pixels is roughly
    /// four millimetres of glass — a pane, not a sheet of paper, and not
    /// a frame either.
    static let kPaneEdge = 2.0

    private func _buildContentArea(_ context: any BuildContext) -> Widget {
        guard let texId = windowInfo.textureId else {
            return windowInfo.appBuilder(context)
        }
        // No sourceRect needed — MAXIMIZED state tells Chrome to skip CSD
        // shadows, so the buffer matches the content area exactly (like
        // Hyprland). The texture stretches to fill the content area.
        var content: Widget
        if sceneContent {
            // The picture is the room renderer's, drawn in its scene at
            // this same place; this is only the surface the pointer
            // lands on. A ColoredBox hit-tests opaque at alpha 0 — a
            // trap elsewhere, exactly the point here.
            content = ColoredBox(color: Color(0x00000000), child: SizedBox(expand: ()))
        } else {
            content = TextureWidget(textureId: texId, filterQuality: contentFilterQuality)
        }
        if windowInfo.flipTextureY && !sceneContent {
            content = Transform(
                transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
                alignment: Alignment.center,
                child: content
            )
        }
        // Nested surfaces — an X11 subwindow reparented into this window
        // (VLC's video output) or a Wayland subsurface (a video, a hover
        // card) — composite INSIDE this window's content, at their offset in
        // the content area, in this window's own z-band, clipped to the
        // content so an oversized video surface (sized to the clip's native
        // resolution) does not spill past the frame. X11 places in physical
        // px, scaled by the shell DPI here; a subsurface arrives in logical.
        if !windowInfo.childSurfaces.isEmpty {
            let dpi = currentShellDpi
            var layers: [Widget] = [Positioned(left: 0, top: 0, right: 0, bottom: 0, child: content)]
            for cs in windowInfo.childSurfaces {
                var surf: Widget = TextureWidget(textureId: cs.textureId, filterQuality: contentFilterQuality)
                if cs.flipY {
                    surf = Transform(
                        transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
                        alignment: Alignment.center,
                        child: surf
                    )
                }
                let r = cs.logicalRect ?? Rect.fromLTWH(
                    Double(cs.offsetXPhys) / dpi, Double(cs.offsetYPhys) / dpi,
                    Double(cs.widthPhys) / dpi, Double(cs.heightPhys) / dpi)
                layers.append(Positioned(
                    left: r.left, top: r.top, width: r.width, height: r.height,
                    child: surf
                ))
            }
            content = ClipRect(child: Stack(children: layers))
        }
        // wp_alpha_modifier: the client's whole-surface opacity, applied
        // to the content only — the frame around it stays the shell's.
        if windowInfo.contentOpacity < 1.0 {
            content = Opacity(opacity: max(0.0, windowInfo.contentOpacity), child: content)
        }
        // ext_background_effect: frosted glass under the client's blur
        // region — the desktop behind the window, blurred, then the
        // (translucent) content over it. Oversized rects clip to the area.
        if !windowInfo.blurRects.isEmpty {
            var layers: [Widget] = []
            for r in windowInfo.blurRects {
                layers.append(Positioned(
                    left: r.left, top: r.top, width: r.width, height: r.height,
                    child: ClipRect(child: BackdropFilter(
                        filter: ShellPalette.frostFilter(blurSigma: 16, saturation: 1.0),
                        child: SizedBox(expand: ())))))
            }
            layers.append(Positioned(fill: (), child: content))
            content = Stack(fit: .expand, children: layers)
        }
        let texture = content
        guard let forward = windowInfo.onPointerEvent else {
            // No pointer forwarding (native Flutter content) — still listen
            // for hover so the cursor resets to the default arrow when the
            // mouse leaves a resize edge.
            return Listener(
                onPointerHover: { _ in DesktopCursor.setShape(.default) },
                behavior: .deferToChild,
                child: texture
            )
        }
        // Wrap with Listener to capture pointer events and forward to child process.
        // behavior: .opaque ensures hit-testing succeeds even though TextureWidget
        // (a LeafRenderObjectWidget) doesn't report hits by default.
        return Listener(
            onPointerDown: { event in
                forward(2, event.localPosition.dx, event.localPosition.dy,
                        Int64(event.buttons))
            },
            onPointerMove: { [self, windowInfo] event in
                // Client-initiated interactive move/resize (xdg_toplevel.move/
                // resize): the compositor owns the rest of this drag. Divert
                // motion into window move/resize; the client stops receiving
                // pointer events until release. Flutter routes the whole
                // gesture here because the pointer-down hit this Listener.
                if windowInfo.interactiveMoveActive || windowInfo.interactiveResizeEdge != nil {
                    let last = windowInfo.interactiveLastPos ?? event.position
                    let delta = Offset(event.position.dx - last.dx,
                                       event.position.dy - last.dy)
                    windowInfo.interactiveLastPos = event.position
                    if windowInfo.interactiveMoveActive {
                        onMove?(delta)
                    } else if let edge = windowInfo.interactiveResizeEdge {
                        onResize?(edge, delta)
                    }
                    return
                }
                forward(3, event.localPosition.dx, event.localPosition.dy,
                        Int64(event.buttons))
            },
            onPointerUp: { [windowInfo] event in
                // End of a client-initiated move/resize: clear the grab and,
                // for resize, force-send the final configure (same contract
                // as the shell's own resize handles).
                if windowInfo.interactiveMoveActive || windowInfo.interactiveResizeEdge != nil {
                    let wasResize = windowInfo.interactiveResizeEdge != nil
                    windowInfo.interactiveMoveActive = false
                    windowInfo.interactiveResizeEdge = nil
                    windowInfo.interactiveLastPos = nil
                    if wasResize, let target = windowInfo.targetRect {
                        let contentW = target.width
                        let contentH = target.height - DesktopTheme.kTitleBarHeight
                        if contentW > 0 && contentH > 0 {
                            windowInfo.onResizeComplete?(contentW, contentH)
                        }
                    }
                }
                forward(1, event.localPosition.dx, event.localPosition.dy, 0)
            },
            onPointerHover: { event in
                DesktopCursor.setShape(.default)
                forward(6, event.localPosition.dx, event.localPosition.dy, 0)
            },
            onPointerSignal: { [windowInfo] event in
                if let scroll = event as? PointerScrollEvent {
                    windowInfo.onScrollEvent?(
                        scroll.localPosition.dx,
                        scroll.localPosition.dy,
                        scroll.scrollDelta.dx,
                        scroll.scrollDelta.dy
                    )
                }
            },
            behavior: .opaque,
            child: texture
        )
    }

    let windowInfo: WindowInfo
    let isFocused: Bool
    /// In fullscreen mode, whether the title bar should be visible because
    /// the cursor is currently in the system status bar area. Ignored when
    /// the window is not fullscreen (title bar is always shown then).
    let isTopBarRevealed: Bool
    /// How the client's texture is sampled. `.low` (one bilinear tap) for a
    /// window drawn 1:1; `.medium` when it is drawn through a perspective
    /// pose and minified, where one tap aliases.
    let contentFilterQuality: FilterQuality
    let onBringToFront: (() -> Void)?
    let onMove: ((Offset) -> Void)?
    let onResize: ((ResizeEdge, Offset) -> Void)?
    let onMinimize: (() -> Void)?
    let onMaximize: (() -> Void)?
    let onClose: (() -> Void)?
    /// macOS-style: double-click on the title bar toggles maximized state.
    let onTitleBarDoubleTap: (() -> Void)?
    /// A scroll on the title bar (the 3D desktop's push/pull).
    let onDepthScroll: ((Double) -> Void)?
    /// The light this window floats in on the 3D desktop, nil in 2D and
    /// for the focused window (which stays pixel-exact by rule). It veils
    /// the pane toward the room's colour with distance, leans the glass
    /// toward the light actually behind it, and gives the pane a shadow
    /// so it reads as off the wall rather than painted on it.
    let roomLight: RoomLight?
    /// The client's picture is drawn by the room renderer, in its scene;
    /// the content area here is transparent and only takes the pointer.
    let sceneContent: Bool

    init(
        windowInfo: WindowInfo,
        isFocused: Bool,
        isTopBarRevealed: Bool = false,
        contentFilterQuality: FilterQuality = .low,
        onBringToFront: (() -> Void)? = nil,
        onMove: ((Offset) -> Void)? = nil,
        onResize: ((ResizeEdge, Offset) -> Void)? = nil,
        onMinimize: (() -> Void)? = nil,
        onMaximize: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onTitleBarDoubleTap: (() -> Void)? = nil,
        onDepthScroll: ((Double) -> Void)? = nil,
        roomLight: RoomLight? = nil,
        sceneContent: Bool = false
    ) {
        self.windowInfo = windowInfo
        self.isFocused = isFocused
        self.isTopBarRevealed = isTopBarRevealed
        self.contentFilterQuality = contentFilterQuality
        self.onBringToFront = onBringToFront
        self.onMove = onMove
        self.onResize = onResize
        self.onMinimize = onMinimize
        self.onMaximize = onMaximize
        self.onClose = onClose
        self.onTitleBarDoubleTap = onTitleBarDoubleTap
        self.onDepthScroll = onDepthScroll
        self.roomLight = roomLight
        self.sceneContent = sceneContent
    }

    /// The glass tint, leaned toward the light behind the window when the
    /// room is open — Mica's idea resolved per window instead of once for
    /// the whole desktop.
    private var glassTint: Color {
        let base = shellTheme.windowGlassTint
        guard let light = roomLight else { return base }
        let k = _DesktopShellState.k3DGlassRoomMix
        return Color(alpha: base.a,
                     red: base.r + (light.color.r - base.r) * k,
                     green: base.g + (light.color.g - base.g) * k,
                     blue: base.b + (light.color.b - base.b) * k)
    }

    override func build(_ context: any BuildContext) -> Widget {
        let isFullscreen = windowInfo.isFullscreen
        let cornerRadius = isFullscreen ? 0.0 : DesktopTheme.kWindowCornerRadius
        let borderColor = isFullscreen ? Color(0x00000000)
            : (isFocused ? shellTheme.windowBorderFocused : shellTheme.windowBorderUnfocused)

        // Traffic lights on the left, or a caption trio on the right: which
        // one is the active style's business, not this window's.
        let titleBar = shellStyle.makeTitleBar(TitleBarParams(
            title: windowInfo.title,
            isFocused: isFocused,
            isMaximized: windowInfo.isMaximized,
            isFullscreen: isFullscreen,
            onMove: onMove,
            onMinimize: onMinimize,
            onMaximize: onMaximize,
            onClose: onClose,
            onDoubleTap: onTitleBarDoubleTap,
            onDepthScroll: onDepthScroll
        ))

        let windowBody: Widget
        if isFullscreen {
            // Fullscreen: content fills the whole window. The title bar
            // overlays at the top only while the shell is revealing the
            // system status bar (cursor in the top edge of the screen).
            //
            // The backing is the OPAQUE version of the window material.
            // Windowed content sits on the liquid-glass backdrop below;
            // fullscreen rightly skips that blur (nothing meaningful to
            // frost), but skipping the backing entirely let every
            // translucent app surface composite straight onto the
            // wallpaper — a fullscreen window looked like a ghost of
            // itself. macOS resolves fullscreen materials against an
            // opaque base; do the same with the glass tint at full alpha.
            let tint = shellTheme.windowGlassTint
            let opaqueBase = Color(
                alpha: 1.0, red: tint.r, green: tint.g, blue: tint.b)
            var bodyChildren: [Widget] = [
                Positioned(
                    fill: (),
                    child: ColoredBox(
                        color: opaqueBase, child: SizedBox(expand: ()))
                ),
                Positioned(
                    fill: (),
                    child: ClipRect(child: _buildContentArea(context))
                )
            ]
            if isTopBarRevealed {
                bodyChildren.append(
                    Positioned(
                        left: 0, top: 0, right: 0,
                        height: DesktopTheme.kTitleBarHeight,
                        child: titleBar
                    )
                )
            }
            windowBody = Stack(children: bodyChildren)
        } else {
            // Non-fullscreen window: title bar always visible above content.
            windowBody = Column(
                children: [
                    titleBar,
                    Expanded(child: ClipRect(child: _buildContentArea(context))),
                ]
            )
        }

        var stackChildren: [Widget] = []

        // Liquid-glass backdrop: frost whatever sits behind the window
        // (wallpaper, other windows) inside the rounded clip. The title bar
        // and any translucency the app leaves in its buffer show it
        // through; opaque content simply covers it. Skipped in fullscreen —
        // content is edge-to-edge and the blur would be pure cost. A SHAPED
        // X11 window gets none either: its cut-away parts must show what is
        // behind, not a frosted tint of it.
        if !isFullscreen && !windowInfo.isShaped {
            let frost = IgnorePointer(
                child: ClipRect(
                    child: BackdropFilter(
                        filter: ShellPalette.frostFilter(blurSigma: 18),
                        child: ColoredBox(
                            color: glassTint,
                            child: SizedBox(expand: ())
                        )
                    )
                )
            )
            // With the picture drawn in the room's scene, the frost stays
            // under the title bar only: over the content it would veil the
            // pane the renderer put there.
            stackChildren.append(sceneContent
                ? Positioned(left: 0, top: 0, right: 0,
                             height: DesktopTheme.kTitleBarHeight, child: frost)
                : Positioned(fill: (), child: frost))
        }
        stackChildren.append(windowBody)

        // Border overlay (skip in fullscreen, and around a shaped window)
        if !isFullscreen && !windowInfo.isShaped {
            stackChildren.append(
                Positioned(
                    fill: (),
                    child: IgnorePointer(
                        child: _WindowBorder(color: borderColor, cornerRadius: cornerRadius)
                    )
                )
            )
        }

        // The pane's edge. A window in the room is a slab of glass a few
        // millimetres thick, and the edge is the only thing that says so:
        // a quad with no edge is infinitely thin and reads as a decal
        // stuck over the view, however well it is placed and lit. Each of
        // the four sides is lit by the same sky as the room, so the side
        // turned toward the windows comes up bright and the side turned
        // away stays dark — which is what the eye reads as thickness.
        //
        // Appended BEFORE the haze so a distant pane's edge is veiled
        // along with the rest of it, and wrapped in IgnorePointer for the
        // same reason the haze is: a ColoredBox hit-tests opaque even at
        // alpha 0 and would eat every click meant for the client.
        if let light = roomLight, !isFullscreen {
            let w = Self.kPaneEdge
            // Kept clear of the rounded corners, where a straight strip
            // would cut the curve.
            let inset = cornerRadius
            func strip(_ c: Color, left: Double? = nil, top: Double? = nil,
                       right: Double? = nil, bottom: Double? = nil,
                       width: Double? = nil, height: Double? = nil) -> Widget {
                Positioned(
                    left: left, top: top, right: right, bottom: bottom,
                    width: width, height: height,
                    child: IgnorePointer(
                        child: ColoredBox(color: c, child: SizedBox(expand: ()))
                    )
                )
            }
            stackChildren.append(
                strip(light.edgeTop, left: inset, top: 0, right: inset, height: w))
            stackChildren.append(
                strip(light.edgeBottom, left: inset, right: inset, bottom: 0, height: w))
            stackChildren.append(
                strip(light.edgeLeft, left: 0, top: inset, bottom: inset, width: w))
            stackChildren.append(
                strip(light.edgeRight, top: inset, right: 0, bottom: inset, width: w))
        }

        // Aerial perspective: a window further into the room is veiled
        // toward the colour of the room behind it. It is the one depth cue
        // that works on a flat screen with one eye and a still head, which
        // is why painters have used it for six centuries and visionOS
        // recedes its background windows the same way. Over the whole pane,
        // chrome and border included, so the window recedes as one object.
        // IgnorePointer because a ColoredBox hit-tests opaque even at alpha
        // 0 and would eat every click meant for the client.
        if let light = roomLight, light.haze > 0, !isFullscreen {
            stackChildren.append(
                Positioned(
                    fill: (),
                    child: IgnorePointer(
                        child: ColoredBox(
                            color: Color(alpha: light.haze,
                                         red: light.color.r,
                                         green: light.color.g,
                                         blue: light.color.b),
                            child: SizedBox(expand: ())
                        )
                    )
                )
            )
        }

        // Resize handles are always rendered — including fullscreen/maximized,
        // since dragging an edge implicitly demotes the window to a free state
        // (handled in WindowManager.resizeWindow).
        stackChildren.append(
            Positioned(
                fill: (),
                child: WindowResizeHandles(
                    windowWidth: windowInfo.rect.width,
                    windowHeight: windowInfo.rect.height,
                    onResize: onResize,
                    onResizeDragStart: { [windowInfo] in
                        windowInfo.targetRect = windowInfo.rect
                    },
                    onResizeDragEnd: { [windowInfo] in
                        if let target = windowInfo.targetRect {
                            let contentW = target.width
                            let contentH = target.height - DesktopTheme.kTitleBarHeight
                            if contentW > 0 && contentH > 0 {
                                windowInfo.onResizeComplete?(contentW, contentH)
                            }
                        }
                    }
                )
            )
        )

        var pane: Widget = ClipRRect(
            borderRadius: BorderRadius.all(Radius(circular: cornerRadius)),
            child: Stack(children: stackChildren)
        )
        // A shadow, only in the room. It is a SCREEN-space drop shadow, not
        // a cast one, and that is deliberate: a real shadow thrown onto the
        // wall behind a floating window projects SMALLER than the window
        // itself (the wall is further from the eye), so the window hides it
        // completely — measured, see the plan's Phase 2a. What reads as
        // "this floats in front of that" is the UI convention, drawn
        // outside the clip so it spills onto the room and onto the windows
        // below. In 2D there is no shadow at all and nothing here runs, so
        // the flat desktop is untouched.
        if let light = roomLight, light.separation > 0, !isFullscreen {
            let s = light.separation
            pane = DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius(circular: cornerRadius)),
                    boxShadow: [
                        BoxShadow(color: Color(alpha: 0.42 * s, red: 0, green: 0, blue: 0),
                                  offset: Offset(0, 16 * s),
                                  blurRadius: 44 * s),
                    ]
                ),
                child: pane
            )
        }
        return Listener(
            onPointerDown: { [self] _ in
                onBringToFront?()
            },
            behavior: .deferToChild,
            child: pane
        )
    }
}

// MARK: - _WindowBorder

/// Paints a thin border around the window using CustomPainter.
private class _WindowBorder: StatelessWidget {

    let color: Color
    let cornerRadius: Double

    init(color: Color, cornerRadius: Double = DesktopTheme.kWindowCornerRadius) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    override func build(_ context: any BuildContext) -> Widget {
        return CustomPaint(
            painter: _WindowBorderPainter(color: color, cornerRadius: cornerRadius),
            child: SizedBox(expand: ())
        )
    }
}

private class _WindowBorderPainter: CustomPainter {
    let color: Color
    let cornerRadius: Double

    init(color: Color, cornerRadius: Double) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let paint = Paint()
        paint.color = color
        paint.style = .stroke
        paint.strokeWidth = 1.0

        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
                Radius(circular: cornerRadius)
            ),
            paint
        )
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _WindowBorderPainter else { return true }
        return old.color != color || old.cornerRadius != cornerRadius
    }
}
