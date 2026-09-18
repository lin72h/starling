#!/usr/bin/env python3
"""Make the orrery world: a star field the desktop floats in.

    orrery-world.py [--out <dir>] [--cmgen <path>]

The orrery has no ground and no walls — open apps are planets round a
sun, their windows moons — so its world is only a sky. The sky is made
here rather than photographed: stars on a black sphere with a faint
band across it, plus a dim blue glow so the night side of a planet is
not nothing. Written as a Radiance .hdr and baked by cmgen into the two
cubemaps the renderer wants, the same as the room's meadow.

Outputs: world.json, room_ibl.ktx, room_skybox.ktx (names the renderer
expects for any world).
"""
import argparse
import json
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def write_hdr(path, img):
    h, w, _ = img.shape
    m = img.max(axis=2)
    f, e = np.frexp(m)
    live = m > 1e-32
    scale = np.where(live, f * 256.0 / np.maximum(m, 1e-32), 0.0)
    rgbe = np.zeros((h, w, 4), np.uint8)
    rgbe[..., :3] = np.clip(img * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(live, e + 128, 0).astype(np.uint8)
    first = rgbe[:, 0, :]
    both = (first[:, 0] == 2) & (first[:, 1] == 2)
    rgbe[both, 0, 0] = 3
    with open(path, "wb") as fo:
        fo.write(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n")
        fo.write(f"-Y {h} +X {w}\n".encode())
        fo.write(rgbe.tobytes())


def star_field(w=2048, h=1024, seed=7):
    """Radiance in the units the room's sky uses (a clear sky is ~1)."""
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 3), np.float32)
    v = (np.arange(h) + 0.5) / h
    u = (np.arange(w) + 0.5) / w
    lat = (0.5 - v) * np.pi                      # +up
    # A faint band, tilted, for depth; and a dim blue everywhere.
    band = np.exp(-((lat[:, None] + 0.35 * np.sin(u[None, :] * 2 * np.pi)) / 0.22) ** 2)
    img += np.array([0.010, 0.014, 0.030], np.float32)
    img += band[..., None] * np.array([0.035, 0.030, 0.045], np.float32)
    # Stars: many faint, few bright; brighter ones a little bigger.
    n = 9000
    su = rng.random(n); sv = rng.random(n)
    # Uniform on the sphere: v from arccos, not uniform in v.
    sv = np.arccos(1 - 2 * sv) / np.pi
    mag = rng.pareto(2.2, n) + 1.0                # 1.. heavy tail
    warm = rng.random(n)
    for x, y, m, k in zip((su * w).astype(int), (sv * h).astype(int), mag, warm):
        r = 1 if m < 2.5 else (2 if m < 6 else 3)
        col = np.array([1.0, 0.92, 0.82]) if k < 0.3 else (
            np.array([0.85, 0.9, 1.0]) if k < 0.8 else np.array([1.0, 0.85, 0.7]))
        val = min(m, 30.0) * 0.35 * col
        y0, y1 = max(0, y - r), min(h, y + r + 1)
        x0, x1 = max(0, x - r), min(w, x + r + 1)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        fall = np.exp(-((yy - y) ** 2 + (xx - x) ** 2) / (0.6 * r * r + 0.3))
        img[y0:y1, x0:x1] += fall[..., None] * val
    return img


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.expanduser("~/tmp/filament/orrery"))
    ap.add_argument("--cmgen", default=os.path.expanduser("~/dev/filament/gles/bin/cmgen"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    sky = star_field()
    hdr = os.path.join(a.out, "stars.hdr")
    write_hdr(hdr, sky)
    for sub, size in (("ibl", 64), ("sky", 1024)):
        d = os.path.join(a.out, sub)
        subprocess.run([a.cmgen, "--quiet", "--format=ktx", f"--size={size}",
                        f"--deploy={d}", hdr], check=True)
    # cmgen names its outputs after the DEPLOY directory, not the input.
    os.replace(os.path.join(a.out, "ibl", "ibl_ibl.ktx"), os.path.join(a.out, "room_ibl.ktx"))
    os.replace(os.path.join(a.out, "sky", "sky_skybox.ktx"), os.path.join(a.out, "room_skybox.ktx"))
    world = {
        "kind": "orrery",
        # Night exposure: f/2, 1/30 s, ISO 1600.
        "exposure": [2.0, 1.0 / 30.0, 1600.0],
        "ibl_intensity": 1.0,
        # The sun at the hub lights the planets: a point light, candela.
        "point_light": {"position": [0.0, 0.6, 0.0], "candela": 260.0,
                        "colour": [1.0, 0.93, 0.8]},
        "hub": [0.0, 0.6, 0.0],
        "sun_radius": 0.32,
        "planet_orbit": 2.2,
        "planet_radius": 0.22,
        "moon_orbit": 0.62,
        "moon_scale": 0.12,
        "camera_home": {"radius": 5.2, "height": 0.0},
    }
    with open(os.path.join(a.out, "world.json"), "w") as f:
        json.dump(world, f, indent=1)
    for n in ("stars.hdr", "room_ibl.ktx", "room_skybox.ktx", "world.json"):
        print(f"  {n:18s} {os.path.getsize(os.path.join(a.out, n))/1e6:6.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
