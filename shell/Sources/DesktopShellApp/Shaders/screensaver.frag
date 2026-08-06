// Screensaver liquid-warp shader: a slow heat-haze drift over the live
// desktop while the screensaver overlay is up.
//
// Runs as the OUTER pass of the screensaver's BackdropFilter compose
// chain, so uTexture is the already blurred backdrop (the dim scrim is
// drawn above the filter, not inside this chain). FlutterFragCoord() is
// full-screen logical px. Flutter compiles texture(s, X) to
// s.eval(s_size * X), and s_size is set to (1,1) from Swift, so
// texture() samples in raw logical-pixel space.
//
// The displacement is two sine pairs with incommensurate frequencies
// plus a third term whose phase is fed by the first pair (a cheap
// domain warp) — it reads as haze, never as a scrolling grating. The
// warp is damped to zero over the outer band so it cannot sample
// off-screen, and the tap is clamped as a second guard.
//
// Float uniforms (order must match the setFloat calls in Swift):
//   0,1 uSize          full-screen size, logical px
//   2   uTime          seconds since activation
//   3   uIntensity     0..1 warp/vignette strength (the fade ramp)
//   4,5 uTexture_size  (auto, appended after the declared floats) — (1,1)
// Sampler 0: uTexture — the backdrop being filtered.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform sampler2D uTexture;

out vec4 fragColor;

const float AMP_PX    = 7.0;    // peak displacement, logical px
const float EDGE_PX   = 48.0;   // damping band at the screen edge, px
const float VIGNETTE  = 0.30;   // corner darkening at full intensity
const float GRAIN_AMT = 0.008;  // dither to stop banding in the dim blur

// Cheap per-pixel hash for dithering grain.
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
    vec2 p = FlutterFragCoord().xy;
    vec2 q = p / uSize;            // 0..1 — resolution-independent phases
    float t = uTime;

    // Angular speeds 0.11..0.26 rad/s: one full cycle every ~25-60 s.
    vec2 d;
    d.x = sin(q.y * 9.2 + t * 0.23)
        + 0.6 * sin((q.x + q.y) * 14.7 - t * 0.17);
    d.y = cos(q.x * 8.1 - t * 0.19)
        + 0.6 * cos((q.y - q.x) * 12.3 + t * 0.26);
    d  += 0.4 * vec2(sin(q.x * 5.3 + d.y * 1.7 + t * 0.11),
                     cos(q.y * 4.7 + d.x * 1.7 - t * 0.13));

    // |d| peaks at ~2, so scale by half the peak amplitude; damp toward
    // the screen edge, then clamp the tap as a belt-and-braces guard.
    float edge = smoothstep(0.0, EDGE_PX,
        min(min(p.x, p.y), min(uSize.x - p.x, uSize.y - p.y)));
    vec2 uv = p + d * (AMP_PX * 0.5) * uIntensity * edge;
    uv = clamp(uv, vec2(0.5), uSize - 0.5);

    vec4 col = texture(uTexture, uv);

    // Static radial vignette, scaled by intensity (the "breathing" lives
    // in the blur sigma, not here — one breath source reads calmer).
    vec2 r = (p - 0.5 * uSize) / (0.5 * uSize);
    col.rgb *= 1.0 - VIGNETTE * uIntensity * smoothstep(0.45, 1.25, length(r));

    col.rgb = clamp(col.rgb + (hash(p) - 0.5) * GRAIN_AMT, 0.0, 1.0);
    fragColor = col;
}
