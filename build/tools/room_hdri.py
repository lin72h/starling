#!/usr/bin/env python3
"""Read a Radiance .hdr sky, and get lighting out of it.

Poly Haven's HDRIs are equirectangular Radiance files: a short text
header, a resolution line, then RGBE scanlines, usually run-length
encoded. That is little enough format to read directly, which beats
adding an image library to a tool that opens one file.

What comes out is what the room needs:

  * `sh9`  — the sky's diffuse irradiance as nine spherical-harmonic
    coefficients per channel. Twenty-seven numbers that reproduce how a
    whole sky lights a surface facing any direction, which is what
    replaces a hand-tuned "ambient" with something true.
  * `sun`  — the direction, colour and strength of the brightest thing
    in the sky, so the room's shadows are cast by the sky's own sun
    rather than by a guess.
  * `to_gamma` — the sky itself packed into an ordinary 8-bit RGB PNG,
    square-rooted so eight bits carry a range a photograph would need
    twelve for. NOT with a multiplier in the alpha channel, which is the
    obvious trick and does not survive the trip: the shell decodes PNGs
    through the engine's image codec, which returns PREMULTIPLIED RGBA,
    so anything stored in alpha has already been multiplied into the
    colour by the time it arrives, and multiplying by it again turns the
    sky black.
"""
import numpy as np


def read_hdr(path: str) -> np.ndarray:
    """Linear RGB radiance, shape (h, w, 3)."""
    with open(path, "rb") as f:
        data = f.read()
    # Header: lines until a blank one, then "-Y <h> +X <w>".
    pos = 0
    while True:
        end = data.index(b"\n", pos)
        line = data[pos:end]
        pos = end + 1
        if line.strip() == b"":
            break
    end = data.index(b"\n", pos)
    dims = data[pos:end].split()
    pos = end + 1
    if dims[0] != b"-Y" or dims[2] != b"+X":
        raise ValueError(f"unexpected HDR orientation {dims!r}")
    h, w = int(dims[1]), int(dims[3])

    rgbe = np.zeros((h, w, 4), np.uint8)
    buf = np.frombuffer(data, np.uint8)
    for y in range(h):
        if (pos + 4 <= len(buf) and buf[pos] == 2 and buf[pos + 1] == 2
                and (int(buf[pos + 2]) << 8 | int(buf[pos + 3])) == w):
            pos += 4
            for c in range(4):                  # new RLE: each channel apart
                x = 0
                while x < w:
                    n = int(buf[pos]); pos += 1
                    if n > 128:                 # a run
                        rgbe[y, x:x + n - 128, c] = buf[pos]
                        pos += 1
                        x += n - 128
                    else:                       # a literal span
                        rgbe[y, x:x + n, c] = buf[pos:pos + n]
                        pos += n
                        x += n
        else:                                   # flat scanline
            rgbe[y] = buf[pos:pos + w * 4].reshape(w, 4)
            pos += w * 4

    e = rgbe[..., 3].astype(np.int32)
    scale = np.where(e == 0, 0.0, np.ldexp(1.0, e - 136)).astype(np.float32)
    return rgbe[..., :3].astype(np.float32) * scale[..., None]


def directions(h: int, w: int):
    """The world direction each pixel of an equirectangular map looks at,
    and the solid angle it covers. +Y is up; u = 0 faces -Z."""
    v = (np.arange(h) + 0.5) / h
    u = (np.arange(w) + 0.5) / w
    theta = v * np.pi                       # 0 at the zenith
    phi = (u - 0.5) * 2 * np.pi
    st, ct = np.sin(theta), np.cos(theta)
    d = np.stack([
        np.outer(st, np.sin(phi)),
        np.repeat(ct[:, None], w, axis=1),
        np.outer(-st, np.cos(phi)),
    ], axis=-1)
    solid = (np.pi / h) * (2 * np.pi / w) * st[:, None]
    return d, np.repeat(solid, w, axis=1)


def sh9(img: np.ndarray):
    """Project the sky onto nine spherical harmonics, per channel.

    These are irradiance coefficients: evaluated for a surface normal
    they give what that surface receives from the whole sky. Nine of
    them is the standard truncation, and for a sky it is very nearly
    exact — the error only shows on a mirror, and nothing here is one.
    """
    h, w, _ = img.shape
    d, solid = directions(h, w)
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    basis = [
        0.282095 * np.ones_like(x),
        0.488603 * y, 0.488603 * z, 0.488603 * x,
        1.092548 * x * y, 1.092548 * y * z,
        0.315392 * (3 * z * z - 1),
        1.092548 * x * z,
        0.546274 * (x * x - y * y),
    ]
    return np.array([[float((img[..., c] * b * solid).sum()) for c in range(3)]
                     for b in basis])


def find_sun(img: np.ndarray):
    """The brightest direction in the sky, and what it is worth.

    The sun is a handful of very bright pixels; everything else in the
    sky is orders of magnitude dimmer. Taking the brightest region's
    centroid and the radiance it carries gives a direction and a colour
    for the one light that casts shadows.
    """
    h, w, _ = img.shape
    d, solid = directions(h, w)
    lum = img @ np.array([0.2126, 0.7152, 0.0722])
    # Everything within a stop or two of the peak is "the sun".
    mask = lum > max(lum.max() * 0.25, np.percentile(lum, 99.995))
    if not mask.any():
        mask = lum >= lum.max()
    weight = (lum * mask)[..., None]
    direction = (d * weight * solid[..., None]).sum(axis=(0, 1))
    direction /= max(np.linalg.norm(direction), 1e-9)
    # Its irradiance on a surface facing it, which is what a shadow
    # term should be multiplied by.
    colour = (img * mask[..., None] * solid[..., None]).sum(axis=(0, 1))
    return direction, colour


def without_sun(img: np.ndarray) -> np.ndarray:
    """The sky with its sun taken out and the hole filled by its
    surroundings, so the harmonics describe the ambient only."""
    lum = img @ np.array([0.2126, 0.7152, 0.0722])
    mask = lum > max(lum.max() * 0.25, np.percentile(lum, 99.995))
    if not mask.any():
        return img
    out = img.copy()
    # A sky near the sun is bright but not thousands of times bright; the
    # 99th percentile of the rest of it is a fair stand-in.
    fill = np.percentile(img[~mask].reshape(-1, 3), 99, axis=0)
    out[mask] = fill
    return out


def to_gamma(img: np.ndarray, max_range: float = 12.0):
    """Pack HDR into 8-bit RGB, square-rooted. The decoder squares it and
    multiplies by the range. The sun clips, which is what a camera
    pointed at a sky does too."""
    c = np.sqrt(np.clip(img / max_range, 0, 1))
    return (c * 255 + 0.5).astype(np.uint8)
