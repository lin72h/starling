// Liquid-glass shader for the DesktopShell glass panels (dock and
// status-bar popups — each panel uses its own FragmentShader instance).
//
// Physically-based port of the refraction model from the "Liquid Glass for
// GNOME" project: a superellipse volume profile gives the panel real 3D
// thickness, a height-field gradient yields a 3D surface normal, and the
// view ray is bent through that normal with Snell's law. Lighting (Fresnel
// rim, Phong specular, sheen) rides the same normal.
//
// Runs as the outer filter of the dock's BackdropFilter compose chain, so
// uTexture is the already blurred + saturated backdrop. FlutterFragCoord()
// is full-screen logical px; uOrigin/uSize give the panel rect so we can
// build a panel-local SDF. Flutter compiles texture(s,X) to s.eval(s_size
// * X), and s_size is set to (1,1) from Swift, so texture() samples in raw
// logical-pixel space — identity is texture(uTexture, FlutterFragCoord()).
//
// Float uniforms (order must match the setFloat calls in Swift):
//   0,1 uSize          panel size, logical px
//   2,3 uOrigin        panel top-left, logical px (full-screen space)
//   4   uCornerRadius  rounded-rect corner radius, logical px
//   5,6 uTexture_size  (auto, appended after the declared floats) — (1,1)
// Sampler 0: uTexture — the backdrop being filtered.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uOrigin;
uniform float uCornerRadius;
uniform sampler2D uTexture;

out vec4 fragColor;

// ---- material constants ----
const float PROFILE_N    = 6.0;    // superellipse exponent (cross-section)
const float IOR          = 1.90;   // index of refraction
const float DISP_SCALE   = 4.4;    // refraction displacement, × peak depth
const float CHROMA_PX    = 2.4;    // chromatic aberration split, px
const float RIM_WIDTH    = 5.0;    // rim-light band width, px
const float RIM_INTEN    = 0.38;
const float RIM_POWER    = 5.0;
const float SPEC_INTEN   = 0.35;
const float SHININESS    = 40.0;
const float SHEEN_INTEN  = 0.05;   // kept low — sheen reads as milky wash
const float LIGHT_ANGLE  = 55.0;   // degrees, overhead-ish
const float IDLE_RIM     = 0.055;  // constant faint edge light (dark bg)
const float GRAIN_AMT    = 0.035;

// 2D signed distance to a rounded rectangle (negative inside).
float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

// Superellipse cross-section: h = (1-(1-t)^n)^(1/n), flat-ish in the
// middle, curving down toward the rim. t: 0 at edge -> 1 at center.
float profileHeight(float t) {
    float n = max(PROFILE_N, 1.01);
    float invT = clamp(1.0 - t, 0.0, 1.0);
    float inner = max(1.0 - pow(invT, n), 0.0);
    return pow(inner, 1.0 / n);
}

// Absolute glass height at a panel-local point.
float getHeight(vec2 p, vec2 b, float r, float zScale) {
    float d = sdRoundRect(p, b, r);
    if (d > 0.0) return 0.0;
    // Height builds up over the corner-radius band, then stays flat.
    float t = clamp(-d / max(r, 1.0), 0.0, 1.0);
    return profileHeight(t) * zScale;
}

// Height gradient via 4-tap finite differences.
vec2 heightGradient(vec2 p, vec2 b, float r, float zScale) {
    float e = 0.6;
    float hR = getHeight(p + vec2(e, 0.0), b, r, zScale);
    float hL = getHeight(p - vec2(e, 0.0), b, r, zScale);
    float hD = getHeight(p + vec2(0.0, e), b, r, zScale);
    float hU = getHeight(p - vec2(0.0, e), b, r, zScale);
    return vec2((hR - hL) / (2.0 * e), (hD - hU) / (2.0 * e));
}

// Cheap per-pixel hash for dithering grain.
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 center    = uOrigin + uSize * 0.5;
    vec2 local_pos = fragCoord - center;
    vec2 box_size  = uSize * 0.5;
    float r = max(uCornerRadius, 1.0);

    float d = sdRoundRect(local_pos, box_size, r);

    // Superellipse volume -> height field -> 3D surface normal.
    float zScale = r * 0.9;                       // glass peak thickness
    vec2 gradH = heightGradient(local_pos, box_size, r, zScale);
    vec3 normal = normalize(vec3(-gradH.x, -gradH.y, 1.0));

    // Snell's-law refraction of the view ray through the surface.
    vec3 viewDir = vec3(0.0, 0.0, -1.0);
    vec3 refracted = refract(viewDir, normal, 1.0 / max(IOR, 1.001));
    vec2 disp = vec2(0.0);
    if (length(refracted) > 1e-4) {
        float safe_z = max(-refracted.z, 0.15);   // guard total-internal
        disp = (refracted.xy / safe_z) * (zScale * DISP_SCALE);
    }
    // Damp refraction at the very boundary (avoids jagged artifacts) and
    // zero it outside the shape.
    float edgeDampen = smoothstep(0.0, 3.0, -d);
    disp *= edgeDampen;

    // Refracted backdrop sample + chromatic aberration along the
    // displacement direction (R and B split, G centered).
    vec2 dir = (length(disp) > 1e-5) ? normalize(disp) : vec2(0.0);
    vec2 caVec = dir * CHROMA_PX * edgeDampen;
    vec2 baseUv = fragCoord + disp;
    float rC = texture(uTexture, baseUv + caVec).r;
    vec4  gC = texture(uTexture, baseUv);
    float bC = texture(uTexture, baseUv - caVec).b;
    vec3 col = vec3(rC, gC.g, bC);

    // De-mud. A Gaussian blur averages complementary colors in RGB — red
    // and green at a boundary blend to dark olive. Restore the lost value
    // back toward full brightness, scaled by chroma so gray/dark
    // backdrops are left untouched.
    float mx = max(max(col.r, col.g), col.b);
    float mn = min(min(col.r, col.g), col.b);
    float vb = mix(1.0, 1.0 / max(mx, 0.25),
                   0.3 * smoothstep(0.15, 0.5, mx - mn));
    col = min(col * vb, vec3(1.0));

    // ---- lighting from the 3D normal ----
    float lr = radians(LIGHT_ANGLE);
    vec3 lightDir = normalize(vec3(cos(lr), sin(lr), 0.42));
    vec3 eye = vec3(0.0, 0.0, 1.0);
    // Thin band hugging the rim, where the surface curves most.
    float edgeBand = smoothstep(RIM_WIDTH, 0.0, abs(d));

    // Fresnel rim light — brightest where the surface faces away from eye.
    float rimF = pow(1.0 - max(dot(normal, eye), 0.0), RIM_POWER);
    float rim = mix(pow(edgeBand, 0.85), rimF, 0.55) * edgeBand * RIM_INTEN;

    // Phong specular off the curved surface.
    vec3 refl = reflect(-lightDir, normal);
    float spec = pow(max(dot(refl, eye), 0.0), SHININESS)
               * SPEC_INTEN * clamp(edgeBand + 0.5, 0.0, 1.0);

    // Surface sheen — curves facing the light brighten gently.
    float sheen = pow(max(dot(normal, lightDir), 0.0), 1.7) * SHEEN_INTEN;

    // Constant faint edge light so the panel stays visible on a dark bg.
    float idle = edgeBand * IDLE_RIM;

    // Screen blend the lighting so highlights never blow out.
    vec3 addedLight = vec3(rim + spec + idle + sheen);
    col = col + addedLight - col * addedLight;

    // Frosted grain / dithering.
    col = clamp(col + (hash(fragCoord) - 0.5) * GRAIN_AMT, 0.0, 1.0);

    fragColor = vec4(col, gC.a);
}
