// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Flutter
import FlutterSwiftBridge

// MARK: - ScreenSaverOverlay

/// Full-screen screensaver surface: the live desktop, dimmed behind a
/// breathing blur and (when the compiled shader is available) a slow liquid
/// warp, with a large thin clock floating on top. The widget is stateless —
/// the composed filter, fade progress, and clock strings all come from
/// `_DesktopShellState`, which rebuilds every frame while the screensaver
/// ticker runs. Any pointer event on the backdrop wakes the desktop; keys
/// are handled upstream in `routeKey`.
class ScreenSaverOverlay: StatelessWidget {

    /// Composed backdrop filter: warp shader ∘ breathing blur, or the plain
    /// blur fallback when the .iplr is missing. Already scaled by the fade.
    let filter: any ImageFilter
    /// Fade progress 0..1 — scales the scrim alpha and the clock opacity.
    /// (The blur/warp fade is baked into `filter`; an ancestor Opacity
    /// cannot attenuate what a BackdropFilter does to its backdrop.)
    let fadeT: Double
    let timeText: String
    let ampmText: String
    let dateText: String
    /// Aerial clip texture, once the first decoded frame has landed. It
    /// cross-fades in ON TOP of the warp (`aerialT`), so the saver opens on
    /// the live desktop and dissolves into the footage.
    let aerialTextureId: Int64?
    let aerialT: Double
    /// A deliberate wake: a click, or a scroll.
    let onWakeInput: () -> Void
    /// Pointer drift. NOT a wake on its own — a hand resting on a trackpad
    /// emits hover events a pixel at a time, and waking on those dismissed
    /// the screensaver the instant it appeared. The shell decides, from the
    /// distance travelled.
    let onPointerActivity: (Offset) -> Void

    init(
        filter: any ImageFilter,
        fadeT: Double,
        timeText: String,
        ampmText: String,
        dateText: String,
        aerialTextureId: Int64? = nil,
        aerialT: Double = 0,
        onWakeInput: @escaping () -> Void,
        onPointerActivity: @escaping (Offset) -> Void
    ) {
        self.filter = filter
        self.fadeT = fadeT
        self.timeText = timeText
        self.ampmText = ampmText
        self.dateText = dateText
        self.aerialTextureId = aerialTextureId
        self.aerialT = aerialT
        self.onWakeInput = onWakeInput
        self.onPointerActivity = onPointerActivity
    }

    /// Scrim colour at full fade — the launcher's dark-navy dim.
    private static let kScrimColor = 0x8C0B0B12

    override func build(_ context: any BuildContext) -> Widget {
        let scrimAlpha = Int(Double(Self.kScrimColor >> 24) * fadeT)
        let scrim = Color((scrimAlpha << 24) | (Self.kScrimColor & 0x00FFFFFF))

        var layers: [Widget] = [
            // Warped, blurred, dimmed view of the live desktop — also the
            // wake catcher for every pointer event.
            Listener(
                onPointerDown: { [self] _ in onWakeInput() },
                onPointerMove: { [self] event in onPointerActivity(event.position) },
                onPointerHover: { [self] event in onPointerActivity(event.position) },
                onPointerSignal: { [self] _ in onWakeInput() },
                behavior: .opaque,
                child: ClipRect(
                    child: BackdropFilter(
                        filter: filter,
                        child: ColoredBox(
                            color: scrim,
                            child: SizedBox(expand: ())
                        )
                    )
                )
            ),
        ]

        // Aerial footage, cross-fading over the warp. IgnorePointer so the
        // wake Listener underneath still sees every pointer event; the clip
        // is cover-cropped to the panel aspect, so it fills with no bars.
        if let texId = aerialTextureId, aerialT > 0 {
            layers.append(
                IgnorePointer(
                    child: Opacity(
                        opacity: min(1.0, aerialT) * fadeT,
                        child: TextureWidget(textureId: Int(texId), filterQuality: .medium)
                    )
                )
            )
        }

        layers.append(contentsOf: [
                // Clock, above the dimmed desktop; IgnorePointer so the
                // backdrop Listener sees every pointer event.
                IgnorePointer(
                    child: Opacity(
                        opacity: fadeT,
                        child: Align(
                            alignment: Alignment(0, -0.38),
                            child: Column(
                                mainAxisSize: .min,
                                children: [
                                    Row(
                                        mainAxisSize: .min,
                                        crossAxisAlignment: .end,
                                        children: [
                                            Text(
                                                timeText,
                                                style: TextStyle(
                                                    color: Color(0xF0FFFFFF),
                                                    fontSize: 96,
                                                    fontWeight: .w200
                                                )
                                            ),
                                            SizedBox(width: 12),
                                            Padding(
                                                padding: EdgeInsets(bottom: 16),
                                                child: Text(
                                                    ampmText,
                                                    style: TextStyle(
                                                        color: Color(0x99FFFFFF),
                                                        fontSize: 20,
                                                        fontWeight: .w300
                                                    )
                                                )
                                            ),
                                        ]
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                        dateText,
                                        style: TextStyle(
                                            color: Color(0x8CFFFFFF),
                                            fontSize: 17,
                                            fontWeight: .w300
                                        )
                                    ),
                                ]
                            )
                        )
                    )
                ),
        ])

        return Stack(fit: .expand, children: layers)
    }
}
