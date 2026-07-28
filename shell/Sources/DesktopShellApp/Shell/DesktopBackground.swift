// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - WallpaperPreset

/// Available wallpaper presets: a bundled still image plus four muted,
/// tonal gradients — the wallpaper is the neutral canvas the frosted
/// chrome and the (colorful) app tiles sit on, so everything stays
/// low-saturation and dark enough that white chrome text reads in both
/// shell themes.
enum WallpaperPreset: Int, CaseIterable {
    /// Bundled still image (macOS Tahoe dark waves), shown via the shell's
    /// GL wallpaper texture. Until the texture is ready — or on platforms
    /// without it — this paints the slate gradient as a stand-in.
    case still = 0    // the default
    case slate = 1    // cool blue-gray (matches the dark chrome)
    case dusk = 2     // muted indigo-plum
    case ocean = 3    // deep sea teal
    case ember = 4    // warm charcoal

    /// Three-stop base gradient, top → bottom.
    var baseColors: [Color] {
        switch self {
        case .still,
             .slate: return [Color(0xFF2C3444), Color(0xFF1C2230), Color(0xFF12161F)]
        case .dusk:  return [Color(0xFF342C4E), Color(0xFF221C38), Color(0xFF141021)]
        case .ocean: return [Color(0xFF173540), Color(0xFF10222E), Color(0xFF0B151E)]
        case .ember: return [Color(0xFF3C302B), Color(0xFF261E1C), Color(0xFF161111)]
        }
    }

    /// Tint of the soft diagonal light wash layered over the base.
    var sheenColor: Color {
        switch self {
        case .still,
             .slate: return Color(0x2687AEDC)
        case .dusk:  return Color(0x22A183C8)
        case .ocean: return Color(0x2264B8B0)
        case .ember: return Color(0x22D0946A)
        }
    }

    /// Dusk sweeps its light from the top-right so cycling presets doesn't
    /// read as "same picture, new tint".
    var sheenFromRight: Bool { self == .dusk }

    /// Cycle to the next preset.
    var next: WallpaperPreset {
        let all = WallpaperPreset.allCases
        let nextIndex = (rawValue + 1) % all.count
        return all[nextIndex]
    }
}

// MARK: - WallpaperPainter

/// Paints a wallpaper preset: a near-vertical three-stop base gradient, a
/// soft diagonal sheen for depth, and a slight darkening along the bottom
/// edge that seats the dock. Linear gradients only (the GLES backend has no
/// radial shader in the bridge).
class WallpaperPainter: CustomPainter {

    let preset: WallpaperPreset

    init(preset: WallpaperPreset = .slate) {
        self.preset = preset
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        let rect = Rect.fromLTWH(0, 0, size.width, size.height)

        // Base: slight tilt so large flat areas don't band as stripes.
        let base = Paint()
        base.shader = Gradient(
            linear: Offset(0, 0),
            to: Offset(size.width * 0.18, size.height),
            colors: preset.baseColors,
            colorStops: [0.0, 0.52, 1.0]
        )
        base.style = .fill
        canvas.drawRect(rect, base)

        // Sheen: one wide, low-alpha wash of light across the upper area.
        let sheenColor = preset.sheenColor
        let sheen = Paint()
        let from = preset.sheenFromRight ? Offset(size.width, 0) : Offset(0, 0)
        let to = preset.sheenFromRight
            ? Offset(size.width * 0.25, size.height * 0.85)
            : Offset(size.width * 0.75, size.height * 0.85)
        sheen.shader = Gradient(
            linear: from, to: to,
            colors: [sheenColor, sheenColor.withOpacity(0.0)],
            colorStops: [0.0, 0.62]
        )
        sheen.style = .fill
        canvas.drawRect(rect, sheen)

        // Grounding: gentle darkening toward the bottom edge.
        let ground = Paint()
        ground.shader = Gradient(
            linear: Offset(0, size.height * 0.72),
            to: Offset(0, size.height),
            colors: [Color(0x00000000), Color(0x2E000000)]
        )
        ground.style = .fill
        canvas.drawRect(rect, ground)
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        guard let old = oldDelegate as? WallpaperPainter else { return true }
        return old.preset != preset
    }
}

// MARK: - DesktopBackground

/// Full-screen wallpaper rendered via CustomPaint.
/// Passes right-click events to the parent for context menu handling.
class DesktopBackground: StatelessWidget {

    let preset: WallpaperPreset
    let onRightClick: ((Offset) -> Void)?

    init(preset: WallpaperPreset = .slate, onRightClick: ((Offset) -> Void)? = nil) {
        self.preset = preset
        self.onRightClick = onRightClick
    }

    override func build(_ context: any BuildContext) -> Widget {
        return Listener(
            onPointerDown: { [self] event in
                // Check for right-click (secondary button)
                if event.buttons & kSecondaryButton != 0 {
                    onRightClick?(event.position)
                }
            },
            behavior: .opaque,
            child: CustomPaint(
                painter: WallpaperPainter(preset: preset),
                child: SizedBox(expand: ())
            )
        )
    }
}
