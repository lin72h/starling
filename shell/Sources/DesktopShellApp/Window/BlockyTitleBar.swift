// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge
import Foundation

// MARK: - BlockyTitleBar

/// A window's title bar in a block world: planks from the world's own
/// frame tile, the title in white with the hard drop shadow of the
/// game's text, and three block buttons — red, gold, emerald — with a
/// one-texel outline and a bevel. The same contract as the style's
/// title bar (drag, double-click, depth scroll), so the window knows no
/// difference; it is the WORLD that asks for this look, not the style,
/// the way the world already supplies the frame the pane hangs in.
class BlockyTitleBar: StatefulWidget {

    let title: String
    let isFocused: Bool
    let isFullscreen: Bool
    /// The world's frame tile (pixel art, 16 texels), or nil for plain planks.
    let tile: FlutterSwiftBridge.Image?
    /// Paint nothing: the bar is drawn in the scene by the room renderer,
    /// where a brick in front of the window covers it; the widget stays
    /// for the pointer alone.
    let inScene: Bool
    /// Which block (0 close, 1 minimize, 2 maximize) the pointer is over,
    /// or nil — so the scene's copy can show the hover.
    let onHoverBlock: ((Int?) -> Void)?
    let onMove: ((Offset) -> Void)?
    let onMinimize: (() -> Void)?
    let onMaximize: (() -> Void)?
    let onClose: (() -> Void)?
    let onDoubleTap: (() -> Void)?
    let onDepthScroll: ((Double) -> Void)?

    init(
        title: String,
        isFocused: Bool,
        isFullscreen: Bool = false,
        tile: FlutterSwiftBridge.Image? = nil,
        inScene: Bool = false,
        onHoverBlock: ((Int?) -> Void)? = nil,
        onMove: ((Offset) -> Void)? = nil,
        onMinimize: (() -> Void)? = nil,
        onMaximize: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil,
        onDepthScroll: ((Double) -> Void)? = nil
    ) {
        self.title = title
        self.isFocused = isFocused
        self.isFullscreen = isFullscreen
        self.tile = tile
        self.inScene = inScene
        self.onHoverBlock = onHoverBlock
        self.onMove = onMove
        self.onMinimize = onMinimize
        self.onMaximize = onMaximize
        self.onClose = onClose
        self.onDoubleTap = onDoubleTap
        self.onDepthScroll = onDepthScroll
    }

    override func createState() -> State<StatefulWidget> {
        return _BlockyTitleBarState()
    }
}

// MARK: - _BlockyTitleBarState

class _BlockyTitleBarState: State<StatefulWidget> {

    private var lastPointerPos: Offset? = nil
    private var lastDownTime: TimeInterval = 0
    private static let kDoubleTapThreshold: TimeInterval = 0.4

    private var w: BlockyTitleBar { widget as! BlockyTitleBar }

    /// A block button's side, and the gap between them.
    static let kButton = 20.0
    static let kGap = 8.0
    static let kLead = 12.0

    // The blocks: redstone, gold, emerald — and stone when unfocused.
    static let closeFace = Color(0xFFD9473A)
    static let minimizeFace = Color(0xFFE6B422)
    static let maximizeFace = Color(0xFF3FB950)
    static let stoneFace = Color(0xFF8C8C8C)

    override func build(_ context: any BuildContext) -> Widget {
        let focused = w.isFocused
        let row = Row(
            children: [
                SizedBox(width: Self.kLead),
                _block(0, face: focused ? Self.closeFace : Self.stoneFace, glyph: .close, onTap: w.onClose),
                SizedBox(width: Self.kGap),
                _block(1, face: focused ? Self.minimizeFace : Self.stoneFace, glyph: .minimize, onTap: w.onMinimize),
                SizedBox(width: Self.kGap),
                _block(2, face: focused ? Self.maximizeFace : Self.stoneFace, glyph: .maximize, onTap: w.onMaximize),
                Expanded(child: w.inScene ? SizedBox(expand: ()) : Center(child: _shadowedTitle(focused: focused))),
                // Balance the buttons so the title is truly centred.
                SizedBox(width: Self.kLead + Self.kButton * 3 + Self.kGap * 2),
            ]
        )
        return Listener(
            onPointerDown: { [self] event in
                lastPointerPos = event.position
                let now = Date.timeIntervalSinceReferenceDate
                if now - lastDownTime < _BlockyTitleBarState.kDoubleTapThreshold {
                    w.onDoubleTap?()
                    lastDownTime = 0
                } else {
                    lastDownTime = now
                }
            },
            onPointerMove: { [self] event in
                guard let last = lastPointerPos else { return }
                let delta = Offset(event.position.dx - last.dx, event.position.dy - last.dy)
                lastPointerPos = event.position
                w.onMove?(delta)
            },
            onPointerUp: { [self] _ in
                lastPointerPos = nil
            },
            onPointerHover: { _ in
                DesktopCursor.setShape(.default)
            },
            onPointerSignal: { [self] event in
                if let scroll = event as? PointerScrollEvent {
                    w.onDepthScroll?(scroll.scrollDelta.dy)
                }
            },
            behavior: .opaque,
            child: SizedBox(
                height: DesktopTheme.kTitleBarHeight,
                child: w.inScene ? row : CustomPaint(
                    painter: _PlankPainter(tile: w.tile, focused: focused),
                    child: row
                )
            )
        )
    }

    /// The bar as a picture, for the scene: what `build` paints, drawn
    /// once into a canvas at `scale` pixels per logical pixel. `hovered`
    /// is the block the pointer is over, whose glyph shows.
    static func paint(_ canvas: any Canvas, width: Double, tile: FlutterSwiftBridge.Image?,
                      title: String, focused: Bool, hovered: Int?, scale: Double) {
        canvas.save()
        canvas.scale(scale, scale)
        let h = DesktopTheme.kTitleBarHeight
        _PlankPainter(tile: tile, focused: focused).paint(canvas, Size(width, h))
        let faces = [closeFace, minimizeFace, maximizeFace]
        let glyphs: [_BlockGlyph] = [.close, .minimize, .maximize]
        for i in 0..<3 {
            let x = kLead + Double(i) * (kButton + kGap)
            canvas.save()
            canvas.translate(x, (h - kButton) / 2)
            _BlockPainter(face: focused ? faces[i] : stoneFace, glyph: glyphs[i],
                          hovered: hovered == i, pressed: false).paint(canvas, Size(kButton, kButton))
            canvas.restore()
        }
        let ink = focused ? Color(0xFFFFFFFF) : Color(0xFFBDBDBD)
        for (dx, dy, c) in [(2.0, 2.0, Color(0xB0000000)), (0.0, 0.0, ink)] {
            let pb = NativeParagraphBuilder(ParagraphStyle(textAlign: .center, fontSize: 13, fontWeight: .w700))
            pb.pushStyle(TextStyle(color: c, fontWeight: .w700, fontSize: 13, letterSpacing: 0.5))
            pb.addText(title)
            let para = pb.build()
            para.layout(ParagraphConstraints(width: width))
            canvas.drawParagraph(para, Offset(dx, (h - 17) / 2 + dy))
        }
        canvas.restore()
    }

    /// The title, white over a hard one-texel-offset shadow: the game's
    /// text, which has no anti-aliasing to soften and reads on any block.
    private func _shadowedTitle(focused: Bool) -> Widget {
        let ink = focused ? Color(0xFFFFFFFF) : Color(0xFFBDBDBD)
        let shade = Color(0xB0000000)
        func text(_ c: Color) -> Widget {
            Text(w.title, style: TextStyle(color: c, fontSize: 13, fontWeight: .w700, letterSpacing: 0.5))
        }
        return Stack(
            children: [
                Padding(padding: EdgeInsets(left: 2, top: 2), child: text(shade)),
                Padding(padding: EdgeInsets(right: 2, bottom: 2), child: text(ink)),
            ]
        )
    }

    private func _block(_ index: Int, face: Color, glyph: _BlockGlyph, onTap: (() -> Void)?) -> Widget {
        let inScene = w.inScene, onHover = w.onHoverBlock
        return SizedBox(
            width: Self.kButton,
            height: Self.kButton,
            child: HoverButton(
                builder: { _, states in
                    inScene ? SizedBox(expand: ()) : CustomPaint(
                        painter: _BlockPainter(face: face, glyph: glyph,
                                               hovered: states.isHovered, pressed: states.isPressed),
                        child: SizedBox(expand: ())
                    )
                },
                onPressed: onTap,
                onPointerEnter: { _ in onHover?(index) },
                onPointerExit: { _ in onHover?(nil) }
            )
        )
    }
}

enum _BlockGlyph { case close, minimize, maximize }

/// A block seen face-on: a two-texel outline, a lit top-left bevel and a
/// shaded bottom-right one, a few darker texels for grain, and, when the
/// pointer is over it, its glyph in white. Pressed, the bevel flips and
/// the face darkens: pushed in.
class _BlockPainter: CustomPainter {
    let face: Color
    let glyph: _BlockGlyph
    let hovered: Bool
    let pressed: Bool

    init(face: Color, glyph: _BlockGlyph, hovered: Bool, pressed: Bool) {
        self.face = face; self.glyph = glyph; self.hovered = hovered; self.pressed = pressed
    }

    private func scaled(_ c: Color, _ k: Double) -> Color {
        Color(alpha: c.a, red: min(1, c.r * k), green: min(1, c.g * k), blue: min(1, c.b * k))
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let t = 2.0                                  // one texel
        let base = pressed ? scaled(face, 0.8) : (hovered ? scaled(face, 1.15) : face)
        let p = Paint()
        p.color = scaled(face, 0.38)
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p)
        p.color = base
        canvas.drawRect(Rect.fromLTWH(t, t, size.width - 2 * t, size.height - 2 * t), p)
        // Bevel.
        let light = scaled(base, 1.3), dark = scaled(base, 0.7)
        p.color = pressed ? dark : light
        canvas.drawRect(Rect.fromLTWH(t, t, size.width - 2 * t, t), p)
        canvas.drawRect(Rect.fromLTWH(t, t, t, size.height - 2 * t), p)
        p.color = pressed ? light : dark
        canvas.drawRect(Rect.fromLTWH(t, size.height - 2 * t, size.width - 2 * t, t), p)
        canvas.drawRect(Rect.fromLTWH(size.width - 2 * t, t, t, size.height - 2 * t), p)
        // Grain: a fixed sprinkle of darker texels.
        p.color = scaled(base, 0.88)
        for (gx, gy) in [(3, 5), (6, 2), (5, 7), (2, 3), (7, 4), (4, 4)] {
            canvas.drawRect(Rect.fromLTWH(Double(gx) * t, Double(gy) * t, t, t), p)
        }
        guard hovered || pressed else { return }
        // The glyph, in white texels.
        p.color = Color(0xFFFFFFFF)
        let n = Int(size.width / t)                  // texels across (10)
        switch glyph {
        case .close:
            for i in 3..<(n - 3) {
                canvas.drawRect(Rect.fromLTWH(Double(i) * t, Double(i) * t, t, t), p)
                canvas.drawRect(Rect.fromLTWH(Double(n - 1 - i) * t, Double(i) * t, t, t), p)
            }
        case .minimize:
            canvas.drawRect(Rect.fromLTWH(3 * t, Double(n / 2) * t, Double(n - 6) * t, t), p)
        case .maximize:
            let r = Rect.fromLTWH(3 * t, 3 * t, Double(n - 6) * t, Double(n - 6) * t)
            canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, t), p)
            canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - t, r.width, t), p)
            canvas.drawRect(Rect.fromLTWH(r.left, r.top, t, r.height), p)
            canvas.drawRect(Rect.fromLTWH(r.right - t, r.top, t, r.height), p)
        }
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _BlockPainter else { return true }
        return old.face != face || old.glyph != glyph || old.hovered != hovered || old.pressed != pressed
    }
}

/// The bar itself: the world's tile laid two screen pixels to a texel,
/// crisp, with a dark two-texel edge along the bottom; dimmed when the
/// window is not the one with the keyboard.
class _PlankPainter: CustomPainter {
    let tile: FlutterSwiftBridge.Image?
    let focused: Bool

    init(tile: FlutterSwiftBridge.Image?, focused: Bool) {
        self.tile = tile; self.focused = focused
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let t = 2.0
        canvas.save()
        canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height))
        let p = Paint()
        if let tile {
            p.filterQuality = .none
            let src = Rect.fromLTWH(0, 0, Double(tile.width), Double(tile.height))
            let step = Double(tile.width) * t
            var y = 0.0
            while y < size.height {
                var x = 0.0
                while x < size.width {
                    canvas.drawImageRect(tile, src, Rect.fromLTWH(x, y, step, step), p)
                    x += step
                }
                y += step
            }
        } else {
            p.color = Color(0xFF946B40)
            canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p)
            p.color = Color(0xFF5A3D20)
            var y = 0.0
            while y < size.height {
                canvas.drawRect(Rect.fromLTWH(0, y, size.width, t), p)
                y += 4 * t
            }
        }
        p.color = Color(0xFF2E2013)
        canvas.drawRect(Rect.fromLTWH(0, size.height - t, size.width, t), p)
        if !focused {
            p.color = Color(0x59000000)
            canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p)
        }
        canvas.restore()
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? _PlankPainter else { return true }
        return old.tile !== tile || old.focused != focused
    }
}
