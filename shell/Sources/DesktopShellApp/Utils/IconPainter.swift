// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - IconType

/// Simple geometric icon types for the desktop shell.
enum IconType {
    case apps       // 3x3 grid (start menu)
    case settings   // gear shape (settings app)
    case folder     // folder shape (file browser)
    case document   // document shape (text viewer)
    case close      // X mark (window close)
    case minimize   // horizontal line (window minimize)
    case maximize   // square outline (window maximize)
    case externalApp // monitor/screen shape (external app)
    case flutterApp  // diamond/crystal shape (flutter app)
    case chrome      // globe/compass shape (Chrome browser)
    case wifi        // WiFi signal bars
    case battery     // battery icon with charge level
    case vscode      // VS Code editor icon
    case terminal    // terminal/console icon
    case calculator  // calculator body with display + key grid
    case store       // App Store "A" built from three strokes in a circle
    case photos      // framed landscape: sun + mountains (image viewer)
    case video       // play triangle in a circle (video player)
    case activity    // ECG pulse line (task manager)
}

// MARK: - IconPainter

/// CustomPainter that draws simple geometric icons via Canvas API.
class IconPainter: CustomPainter {

    let iconType: IconType
    let color: Color

    init(_ iconType: IconType, color: Color = Color(0xFFFFFFFF)) {
        self.iconType = iconType
        self.color = color
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let paint = Paint()
        paint.color = color
        paint.style = .fill

        let w = size.width
        let h = size.height

        switch iconType {
        case .apps:
            paintAppsGrid(canvas, w, h, paint)
        case .settings:
            paintGear(canvas, w, h, paint)
        case .folder:
            paintFolder(canvas, w, h, paint)
        case .document:
            paintDocument(canvas, w, h, paint)
        case .close:
            paintClose(canvas, w, h, paint)
        case .minimize:
            paintMinimize(canvas, w, h, paint)
        case .maximize:
            paintMaximize(canvas, w, h, paint)
        case .externalApp:
            paintExternalApp(canvas, w, h, paint)
        case .flutterApp:
            paintFlutterApp(canvas, w, h, paint)
        case .chrome:
            paintChrome(canvas, w, h, paint)
        case .wifi:
            paintWifi(canvas, w, h, paint)
        case .battery:
            paintBattery(canvas, w, h, paint)
        case .vscode:
            paintVSCode(canvas, w, h, paint)
        case .terminal:
            paintTerminal(canvas, w, h, paint)
        case .calculator:
            paintCalculator(canvas, w, h, paint)
        case .store:
            paintStore(canvas, w, h, paint)
        case .photos:
            paintPhotos(canvas, w, h, paint)
        case .video:
            paintVideo(canvas, w, h, paint)
        case .activity:
            paintActivity(canvas, w, h, paint)
        }
    }

    /// ECG pulse line — Activity Monitor's read: flat, sharp up, sharp
    /// down, flat, one stroked polyline across the middle.
    private func paintActivity(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        paint.style = .stroke
        paint.strokeWidth = w * 0.085
        let midY = h * 0.52
        let line = Path()
        line.moveTo(w * 0.10, midY)
        line.lineTo(w * 0.34, midY)
        line.lineTo(w * 0.45, h * 0.22)
        line.lineTo(w * 0.58, h * 0.78)
        line.lineTo(w * 0.66, midY)
        line.lineTo(w * 0.90, midY)
        canvas.drawPath(line, paint)
        paint.style = .fill
    }

    // MARK: - Icon Shapes

    /// Play triangle in a circle outline — same construction as the App
    /// Store mark so the two circle-based glyphs read as siblings.
    private func paintVideo(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0

        paint.style = .stroke
        paint.strokeWidth = w * 0.07
        canvas.drawCircle(Offset(cx, cy), w * 0.42, paint)

        // Play triangle, nudged right for optical centering.
        paint.style = .fill
        let tri = Path()
        tri.moveTo(cx - w * 0.11, cy - h * 0.17)
        tri.lineTo(cx - w * 0.11, cy + h * 0.17)
        tri.lineTo(cx + w * 0.20, cy)
        tri.close()
        canvas.drawPath(tri, paint)
    }

    /// Framed landscape photo: rounded frame, sun, two mountains.
    private func paintPhotos(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let stroke = Paint()
        stroke.color = paint.color
        stroke.style = .stroke
        stroke.strokeWidth = max(1.5, w * 0.07)
        canvas.drawRRect(
            RRect(fromRectAndRadius: Rect.fromLTWH(w * 0.10, h * 0.16, w * 0.80, h * 0.68),
                  Radius(circular: w * 0.10)),
            stroke)

        paint.style = .fill
        canvas.drawCircle(Offset(w * 0.36, h * 0.38), w * 0.075, paint)

        let mountains = Path()
        mountains.moveTo(w * 0.18, h * 0.72)
        mountains.lineTo(w * 0.40, h * 0.46)
        mountains.lineTo(w * 0.54, h * 0.60)
        mountains.lineTo(w * 0.66, h * 0.48)
        mountains.lineTo(w * 0.82, h * 0.72)
        mountains.close()
        canvas.drawPath(mountains, paint)
    }

    /// 3x3 grid of small squares
    private func paintAppsGrid(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let margin = w * 0.15
        let gap = w * 0.1
        let cellSize = (w - 2 * margin - 2 * gap) / 3.0

        for row in 0..<3 {
            for col in 0..<3 {
                let x = margin + Double(col) * (cellSize + gap)
                let y = margin + Double(row) * (cellSize + gap)
                canvas.drawRRect(
                    RRect(
                        fromRectAndRadius: Rect.fromLTWH(x, y, cellSize, cellSize),
                        Radius(circular: 1.0)
                    ),
                    paint
                )
            }
        }
    }

    /// Solid gear icon with 8 teeth — all filled, no strokes
    private func paintGear(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0
        paint.style = .fill

        // 8 solid teeth radiating from center
        let toothW = w * 0.13
        let toothL = w * 0.20
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4.0
            canvas.save()
            canvas.translate(cx, cy)
            canvas.rotate(angle)
            canvas.drawRRect(
                RRect(fromRectAndRadius: Rect.fromLTWH(-toothW / 2, -w * 0.42, toothW, toothL),
                      Radius(circular: 2.0)),
                paint
            )
            canvas.restore()
        }

        // Solid body circle
        canvas.drawCircle(Offset(cx, cy), w * 0.28, paint)
    }

    /// Solid folder icon — filled tab + body
    private func paintFolder(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let m = w * 0.10
        paint.style = .fill

        // Folder tab
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m, h * 0.18, w * 0.48, h * 0.38),
                Radius(circular: 3.0)
            ),
            paint
        )

        // Folder body
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m, h * 0.32, w - m, h - m),
                Radius(circular: 3.0)
            ),
            paint
        )
    }

    /// iOS-style document / page shape (solid fill)
    private func paintDocument(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let m = w * 0.18

        // Page body (solid)
        paint.style = .fill
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m, h * 0.08, w - m, h * 0.92),
                Radius(circular: 3.0)
            ),
            paint
        )

        // Text lines cut out in translucent dark — reads on any tile hue.
        let lines = Paint()
        lines.color = Color(0x38000000)
        lines.style = .fill
        let left = m + w * 0.09
        let right = w - m - w * 0.09
        let lineH = h * 0.055
        for (i, frac) in [0.26, 0.42, 0.58].enumerated() {
            let lineRight = i == 2 ? left + (right - left) * 0.62 : right
            canvas.drawRRect(
                RRect(fromRectAndRadius:
                        Rect.fromLTRB(left, h * frac, lineRight, h * frac + lineH),
                      Radius(circular: lineH / 2)),
                lines
            )
        }
    }

    /// X close button
    private func paintClose(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        paint.style = .stroke
        paint.strokeWidth = 1.5
        let m = w * 0.28
        canvas.drawLine(Offset(m, m), Offset(w - m, h - m), paint)
        canvas.drawLine(Offset(w - m, m), Offset(m, h - m), paint)
    }

    /// Horizontal line for minimize
    private func paintMinimize(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        paint.style = .stroke
        paint.strokeWidth = 1.5
        let m = w * 0.28
        canvas.drawLine(Offset(m, h / 2.0), Offset(w - m, h / 2.0), paint)
    }

    /// Square outline for maximize
    private func paintMaximize(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        paint.style = .stroke
        paint.strokeWidth = 1.5
        let m = w * 0.28
        canvas.drawRect(Rect.fromLTRB(m, m, w - m, h - m), paint)
    }

    /// iOS-style monitor/screen shape for external app (solid fill)
    private func paintExternalApp(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let m = w * 0.1
        paint.style = .fill

        // Screen body (solid)
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m, m, w - m, h * 0.68),
                Radius(circular: 3.0)
            ),
            paint
        )

        // Stand
        canvas.drawRect(
            Rect.fromLTWH(w * 0.40, h * 0.68, w * 0.20, h * 0.12),
            paint
        )

        // Base
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(w * 0.22, h * 0.78, w * 0.78, h * 0.88),
                Radius(circular: 2.0)
            ),
            paint
        )
    }

    /// iOS-style diamond / crystal shape for Flutter app (solid fill).
    private func paintFlutterApp(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0

        // Solid diamond via rotated rounded rect
        paint.style = .fill
        canvas.save()
        canvas.translate(cx, cy)
        canvas.rotate(Double.pi / 4.0)
        let side = w * 0.32
        canvas.drawRRect(
            RRect(fromRectAndRadius: Rect.fromLTRB(-side, -side, side, side),
                  Radius(circular: 4.0)),
            paint
        )
        canvas.restore()
    }

    /// Generic browser mark: a globe. Deliberately NOT Chrome's disc — Starling
    /// ships no third-party artwork, and this glyph only appears when the app
    /// is not installed (when it is, the app registry supplies the real icon).
    private func paintChrome(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0
        let r = w * 0.38

        paint.style = .stroke
        paint.strokeWidth = max(1.5, w * 0.07)
        canvas.drawCircle(Offset(cx, cy), r, paint)

        // Equator, and two meridians drawn as ellipses narrowing to a line.
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint)
        for fraction in [0.42, 0.84] {
            let rx = r * fraction
            canvas.drawOval(
                Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: r * 2),
                paint)
        }
    }

    /// Generic code-editor mark: angle brackets around a caret, in the tile's
    /// own foreground colour. Deliberately NOT VS Code's ribbon — see above.
    private func paintVSCode(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0

        paint.style = .stroke
        paint.strokeWidth = max(1.5, w * 0.075)
        paint.strokeCap = .round

        // Left bracket  <
        let lx = w * 0.16, inset = w * 0.30
        canvas.drawLine(Offset(cx - inset, cy - h * 0.20), Offset(lx, cy), paint)
        canvas.drawLine(Offset(lx, cy), Offset(cx - inset, cy + h * 0.20), paint)

        // Right bracket  >
        let rx = w * 0.84
        canvas.drawLine(Offset(cx + inset, cy - h * 0.20), Offset(rx, cy), paint)
        canvas.drawLine(Offset(rx, cy), Offset(cx + inset, cy + h * 0.20), paint)

        // Slash between them
        canvas.drawLine(Offset(cx + w * 0.07, cy - h * 0.22),
                        Offset(cx - w * 0.07, cy + h * 0.22), paint)
    }

    /// Terminal/console icon: rounded rectangle with ">_" prompt
    private func paintTerminal(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let m = w * 0.08
        paint.style = .fill

        // Terminal window body
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m, h * 0.12, w - m, h * 0.88),
                Radius(circular: 4.0)
            ),
            paint
        )

        // Dark inner area (cut out)
        let innerPaint = Paint()
        innerPaint.color = Color(0xFF161A22)
        innerPaint.style = .fill
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(m + 2.5, h * 0.26, w - m - 2.5, h * 0.88 - 2.5),
                Radius(circular: 2.0)
            ),
            innerPaint
        )

        // ">" chevron prompt
        let promptPaint = Paint()
        promptPaint.color = Color(0xFF7FCB8B)  // sage green (palette family)
        promptPaint.style = .stroke
        promptPaint.strokeWidth = 2.0
        let chevronL = w * 0.22
        let chevronR = w * 0.38
        let chevronMid = h * 0.52
        let chevronHalf = h * 0.10
        canvas.drawLine(Offset(chevronL, chevronMid - chevronHalf), Offset(chevronR, chevronMid), promptPaint)
        canvas.drawLine(Offset(chevronL, chevronMid + chevronHalf), Offset(chevronR, chevronMid), promptPaint)

        // "_" cursor
        let cursorPaint = Paint()
        cursorPaint.color = Color(0xFFFFFFFF)
        cursorPaint.style = .fill
        canvas.drawRect(
            Rect.fromLTWH(w * 0.44, h * 0.56, w * 0.14, h * 0.04),
            cursorPaint
        )
    }

    /// Calculator icon: solid body with a display bar and a 3x3 key grid
    private func paintCalculator(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        paint.style = .fill

        // Body
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(w * 0.16, h * 0.08, w * 0.84, h * 0.92),
                Radius(circular: 4.0)
            ),
            paint
        )

        // Display bar + keys are cut out in a dark tone.
        let inner = Paint()
        inner.color = Color(0xFF3A3A3C)
        inner.style = .fill
        canvas.drawRRect(
            RRect(
                fromRectAndRadius: Rect.fromLTRB(w * 0.24, h * 0.15, w * 0.76, h * 0.32),
                Radius(circular: 1.5)
            ),
            inner
        )

        // 3x3 key grid
        let gridL = w * 0.24
        let gridT = h * 0.42
        let cell = (w * 0.76 - gridL - 2 * w * 0.05) / 3.0
        let gap = w * 0.05
        for row in 0..<3 {
            for col in 0..<3 {
                let x = gridL + Double(col) * (cell + gap)
                let y = gridT + Double(row) * (cell + gap)
                canvas.drawRRect(
                    RRect(
                        fromRectAndRadius: Rect.fromLTWH(x, y, cell, cell),
                        Radius(circular: 1.0)
                    ),
                    inner
                )
            }
        }
    }

    /// WiFi signal icon: three concentric arcs
    private func paintWifi(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let bottom = h * 0.82

        // Small dot at bottom center
        paint.style = .fill
        canvas.drawCircle(Offset(cx, bottom), w * 0.06, paint)

        // Concentric arcs (from inner to outer)
        paint.style = .stroke
        paint.strokeWidth = 1.8
        let radii: [Double] = [0.22, 0.36, 0.50]
        for r in radii {
            let radius = w * r
            let rect = Rect.fromCenter(center: Offset(cx, bottom), width: radius * 2, height: radius * 2)
            // Draw arc from -135° to -45° (top-facing quarter)
            canvas.drawArc(rect, -Double.pi * 0.75, Double.pi * 0.5, false, paint)
        }
    }

    /// Battery icon: rounded rectangle with charge level fill
    private func paintBattery(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let bodyL = w * 0.08
        let bodyR = w * 0.82
        let bodyT = h * 0.25
        let bodyB = h * 0.75
        let r = 2.5

        // Battery outline
        paint.style = .stroke
        paint.strokeWidth = 1.6
        canvas.drawRRect(
            RRect(fromRectAndRadius: Rect.fromLTRB(bodyL, bodyT, bodyR, bodyB), Radius(circular: r)),
            paint
        )

        // Positive terminal nub on right
        paint.style = .fill
        canvas.drawRRect(
            RRect(fromRectAndRadius: Rect.fromLTRB(bodyR, h * 0.38, w * 0.92, h * 0.62), Radius(circular: 1.5)),
            paint
        )

        // Charge level fill (~84%)
        let inset = 2.5
        let fillWidth = (bodyR - bodyL - inset * 2) * 0.84
        canvas.drawRRect(
            RRect(fromRectAndRadius: Rect.fromLTRB(bodyL + inset, bodyT + inset, bodyL + inset + fillWidth, bodyB - inset), Radius(circular: 1.0)),
            paint
        )
    }

    /// App Store mark: an "A" built from three rounded strokes (two legs
    /// crossing at the apex + a bar), inside a circle outline.
    private func paintStore(_ canvas: any Canvas, _ w: Double, _ h: Double, _ paint: Paint) {
        let cx = w / 2.0
        let cy = h / 2.0

        // Circle outline
        paint.style = .stroke
        paint.strokeWidth = w * 0.07
        canvas.drawCircle(Offset(cx, cy), w * 0.42, paint)

        // The "A" strokes: rounded bars, drawn as rotated rounded rects.
        paint.style = .fill
        let strokeW = w * 0.085
        let legLen = h * 0.42
        let legTilt = 0.36  // radians off vertical

        for tilt in [legTilt, -legTilt] {
            canvas.save()
            canvas.translate(cx, cy + h * 0.06)
            canvas.rotate(tilt)
            canvas.drawRRect(
                RRect(fromRectAndRadius:
                        Rect.fromLTWH(-strokeW / 2, -legLen / 2, strokeW, legLen),
                      Radius(circular: strokeW / 2)),
                paint
            )
            canvas.restore()
        }

        // Crossbar
        canvas.drawRRect(
            RRect(fromRectAndRadius:
                    Rect.fromLTWH(cx - w * 0.14, cy + h * 0.10, w * 0.28, strokeW),
                  Radius(circular: strokeW / 2)),
            paint
        )
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? IconPainter else { return true }
        return old.iconType != iconType || old.color != color
    }
}

// Equatable on IconType for shouldRepaint
extension IconType: Equatable {}
