#!/usr/bin/env python3
"""Make the voxel world: a blocky city for the desktop to stand in.

    voxel-world.py [--out <dir>] [--size 60] [--seed 3]

A street grid with blocky buildings — concrete and brick, windows lit
here and there, flat roofs with parapets — and a square in the middle
with a fountain, lamp posts and a few trees, where the open windows
stand. Every block face is a quad with a pixel-art tile from a small
atlas drawn here, sampled with NEAREST so the pixels stay pixels. One
glTF, one material, plus a gradient sky with a square sun for cmgen,
and world.json with the ground height so the viewer can walk on it.

Outputs: room.glb, room_ibl.ktx, room_skybox.ktx, world.json, atlas.png
(the renderer's names for any world).
"""
import argparse
import json
import os
import struct
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# ------------------------------------------------------------ the atlas

TILE = 16
# Tile index in a 4x4 atlas.
T_ASPHALT, T_ROADLINE, T_SIDEWALK, T_CONCRETE = 0, 1, 2, 3
T_WINDOW, T_WINDOW_LIT, T_BRICK, T_ROOF = 4, 5, 6, 7
T_PLAZA, T_GRASS_TOP, T_LOG_SIDE, T_LEAVES = 8, 9, 10, 11
T_LAMP, T_WATER, T_DARK, T_STONE = 12, 13, 14, 15


def noise_tile(rng, base, spread, dark=None, light=None):
    """A 16x16 tile of a base colour with per-pixel speckle."""
    t = np.zeros((TILE, TILE, 3), np.float32)
    t[:] = base
    t += rng.normal(0, spread, (TILE, TILE, 1))
    if dark is not None:
        m = rng.random((TILE, TILE)) < 0.12
        t[m] = dark
    if light is not None:
        m = rng.random((TILE, TILE)) < 0.08
        t[m] = light
    return np.clip(t, 0, 1)


def make_atlas(path, seed=1):
    rng = np.random.default_rng(seed)
    tiles = {}
    tiles[T_ASPHALT] = noise_tile(rng, (0.17, 0.17, 0.18), 0.02, (0.13, 0.13, 0.14), (0.22, 0.22, 0.23))
    line = noise_tile(rng, (0.17, 0.17, 0.18), 0.02)
    line[:, 7:9] = (0.85, 0.72, 0.2)
    tiles[T_ROADLINE] = line
    walk = noise_tile(rng, (0.64, 0.63, 0.6), 0.02)
    walk[0, :] = (0.5, 0.5, 0.48); walk[:, 0] = (0.5, 0.5, 0.48)
    tiles[T_SIDEWALK] = walk
    tiles[T_CONCRETE] = noise_tile(rng, (0.74, 0.72, 0.68), 0.025, (0.66, 0.64, 0.6))
    win = noise_tile(rng, (0.74, 0.72, 0.68), 0.02)
    win[2:14, 2:14] = (0.22, 0.3, 0.42)
    win[3:13, 3:8] = (0.28, 0.38, 0.52)
    win[2:14, 8] = (0.6, 0.6, 0.6)
    tiles[T_WINDOW] = win
    lit = win.copy()
    lit[2:14, 2:14] = (0.98, 0.86, 0.5)
    lit[3:13, 3:8] = (1.0, 0.92, 0.62)
    lit[2:14, 8] = (0.6, 0.6, 0.6)
    tiles[T_WINDOW_LIT] = lit
    brick = noise_tile(rng, (0.6, 0.28, 0.2), 0.03, (0.5, 0.22, 0.16))
    for y in range(TILE):
        if y % 4 == 0:
            brick[y] = (0.72, 0.68, 0.62)
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(TILE):
            if (x + off) % 8 == 0:
                brick[y, x] = (0.72, 0.68, 0.62)
    tiles[T_BRICK] = brick
    tiles[T_ROOF] = noise_tile(rng, (0.24, 0.23, 0.22), 0.03, (0.18, 0.17, 0.16), (0.32, 0.31, 0.3))
    plaza = noise_tile(rng, (0.58, 0.56, 0.52), 0.02)
    plaza[0, :] = (0.42, 0.4, 0.38); plaza[:, 0] = (0.42, 0.4, 0.38)
    plaza[8, :] = (0.42, 0.4, 0.38); plaza[:, 8] = (0.42, 0.4, 0.38)
    tiles[T_PLAZA] = plaza
    tiles[T_GRASS_TOP] = noise_tile(rng, (0.36, 0.62, 0.22), 0.04, (0.28, 0.5, 0.16), (0.46, 0.7, 0.3))
    log = noise_tile(rng, (0.4, 0.3, 0.18), 0.03)
    for x in range(0, TILE, 4):
        log[:, x] = (0.3, 0.22, 0.12)
    tiles[T_LOG_SIDE] = log
    tiles[T_LEAVES] = noise_tile(rng, (0.2, 0.48, 0.14), 0.05, (0.12, 0.34, 0.08), (0.3, 0.6, 0.22))
    tiles[T_LAMP] = noise_tile(rng, (1.0, 0.92, 0.6), 0.02)
    tiles[T_WATER] = noise_tile(rng, (0.2, 0.42, 0.85), 0.03, (0.16, 0.36, 0.78), (0.3, 0.52, 0.92))
    tiles[T_DARK] = noise_tile(rng, (0.12, 0.12, 0.14), 0.02)
    tiles[T_STONE] = noise_tile(rng, (0.5, 0.5, 0.5), 0.035, (0.4, 0.4, 0.42), (0.58, 0.58, 0.58))
    atlas = np.zeros((4 * TILE, 4 * TILE, 3), np.float32)
    for i, t in tiles.items():
        r, c = divmod(i, 4)
        atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = t
    Image.fromarray((atlas * 255).astype(np.uint8)).save(path)


def tile_uv(i):
    """The UV rectangle of a tile, inset half a texel so nothing bleeds."""
    r, c = divmod(i, 4)
    e = 0.5 / (4 * TILE)
    return (c / 4 + e, r / 4 + e, (c + 1) / 4 - e, (r + 1) / 4 - e)


# ------------------------------------------------------------ the land

(AIR, ASPHALT, ROADLINE, SIDEWALK, CONCRETE, WINDOW, WINDOW_LIT, BRICK, ROOF,
 PLAZA, GRASS, LOG, LEAVES, LAMP, WATER, DARK, STONE) = range(17)
SOLID = {ASPHALT, ROADLINE, SIDEWALK, CONCRETE, WINDOW, WINDOW_LIT, BRICK, ROOF,
         PLAZA, GRASS, LOG, LEAVES, LAMP, DARK, STONE}

# Which tile each face of each block wears: (top, side, bottom).
FACE_TILES = {
    ASPHALT: (T_ASPHALT, T_ASPHALT, T_ASPHALT),
    ROADLINE: (T_ROADLINE, T_ASPHALT, T_ASPHALT),
    SIDEWALK: (T_SIDEWALK, T_SIDEWALK, T_SIDEWALK),
    CONCRETE: (T_CONCRETE, T_CONCRETE, T_CONCRETE),
    WINDOW: (T_CONCRETE, T_WINDOW, T_CONCRETE),
    WINDOW_LIT: (T_CONCRETE, T_WINDOW_LIT, T_CONCRETE),
    BRICK: (T_BRICK, T_BRICK, T_BRICK),
    ROOF: (T_ROOF, T_CONCRETE, T_CONCRETE),
    PLAZA: (T_PLAZA, T_PLAZA, T_PLAZA),
    GRASS: (T_GRASS_TOP, T_GRASS_TOP, T_GRASS_TOP),
    LOG: (T_LOG_SIDE, T_LOG_SIDE, T_LOG_SIDE),
    LEAVES: (T_LEAVES, T_LEAVES, T_LEAVES),
    LAMP: (T_LAMP, T_LAMP, T_LAMP),
    WATER: (T_WATER, T_WATER, T_WATER),
    DARK: (T_DARK, T_DARK, T_DARK),
    STONE: (T_STONE, T_STONE, T_STONE),
}

CELL = 12        # a city block: 4 of street, then the lot
G = 4            # ground level: the surface block's y


def plant_tree(blocks, rng, x, base, z):
    trunk = int(rng.integers(4, 6))
    blocks[x, base:base + trunk, z] = LOG
    for dy, r in ((trunk - 2, 2), (trunk - 1, 2), (trunk, 1), (trunk + 1, 0)):
        y = base + dy
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                if abs(dx) == r and abs(dz) == r and r == 2:
                    continue
                if blocks[x + dx, y, z + dz] == AIR:
                    blocks[x + dx, y, z + dz] = LEAVES


def build_city(size, seed, plaza_r=13):
    rng = np.random.default_rng(seed)
    height = 40
    blocks = np.zeros((size, height, size), np.uint8)        # x, y, z
    c = size // 2
    blocks[:, :G, :] = STONE
    for x in range(size):
        for z in range(size):
            d = max(abs(x - c), abs(z - c))
            cx, cz = x % CELL, z % CELL
            if d < plaza_r:
                blocks[x, G, z] = PLAZA
            elif cx < 4 or cz < 4:
                lane = (cx == 2 and cz >= 4 and (z % 2 == 0)) or (cz == 2 and cx >= 4 and (x % 2 == 0))
                blocks[x, G, z] = ROADLINE if lane else ASPHALT
            elif cx in (4, 11) or cz in (4, 11):
                blocks[x, G, z] = SIDEWALK
            else:
                blocks[x, G, z] = SIDEWALK
    # Buildings: one per lot, its footprint the lot less the pavement.
    lots = []
    for lx in range(0, size, CELL):
        for lz in range(0, size, CELL):
            x0, z0 = lx + 5, lz + 5
            x1, z1 = min(lx + 11, size), min(lz + 11, size)
            if x1 - x0 < 4 or z1 - z0 < 4:
                continue
            # Skip the plaza and anything that would cut into it.
            if max(abs((x0 + x1) / 2 - c), abs((z0 + z1) / 2 - c)) < plaza_r + 4:
                continue
            near = max(abs((x0 + x1) / 2 - c), abs((z0 + z1) / 2 - c)) / (size / 2)
            h = int(rng.integers(5, 10) + (1 - near) * rng.integers(4, 14))
            style = BRICK if rng.random() < 0.3 else CONCRETE
            lots.append((x0, z0, x1, z1, h, style))
    for x0, z0, x1, z1, h, style in lots:
        for x in range(x0, x1):
            for z in range(z0, z1):
                edge = x in (x0, x1 - 1) or z in (z0, z1 - 1)
                corner = x in (x0, x1 - 1) and z in (z0, z1 - 1)
                for y in range(G + 1, G + 1 + h):
                    if not edge:
                        blocks[x, y, z] = DARK
                    elif corner or style == BRICK and (y - G) % 3 == 0 or (y - G) % 2 == 0:
                        blocks[x, y, z] = style
                    else:
                        blocks[x, y, z] = WINDOW_LIT if rng.random() < 0.25 else WINDOW
                blocks[x, G + 1 + h, z] = CONCRETE if edge else ROOF
    # The square: a low pool in the middle (nothing tall, so the windows
    # across the square are in view from the door), lamp posts, trees.
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            r = max(abs(dx), abs(dz))
            if r == 3:
                blocks[c + dx, G + 1, c + dz] = CONCRETE
            elif r <= 2:
                blocks[c + dx, G + 1, c + dz] = WATER
    blocks[c, G + 1, c] = LAMP
    for sx, sz in ((-9, -9), (9, -9), (-9, 9), (9, 9)):
        blocks[c + sx, G + 1:G + 4, c + sz] = LOG
        blocks[c + sx, G + 4, c + sz] = LAMP
    for sx, sz in ((-12, -12), (12, -12), (-12, 12), (12, 12)):
        for dx in range(-1, 2):
            for dz in range(-1, 2):
                blocks[c + sx + dx, G, c + sz + dz] = GRASS
        plant_tree(blocks, rng, c + sx, G + 1, c + sz)
    return blocks


# ------------------------------------------------------------ the mesh

FACES = [
    # (dx, dy, dz) neighbour, corners (4, CCW from outside), normal, which tile
    ((0, 1, 0), [(0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)], (0, 1, 0), 0),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], (0, -1, 0), 2),
    ((1, 0, 0), [(1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1)], (1, 0, 0), 1),
    ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)], (-1, 0, 0), 1),
    ((0, 0, 1), [(1, 0, 1), (0, 0, 1), (0, 1, 1), (1, 1, 1)], (0, 0, 1), 1),
    ((0, 0, -1), [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], (0, 0, -1), 1),
]


def mesh_blocks(blocks, origin):
    sx, sy, sz = blocks.shape
    pos, nrm, uv, idx = [], [], [], []
    ox, oz = origin
    solid = np.isin(blocks, list(SOLID))
    for x in range(sx):
        for y in range(sy):
            for z in range(sz):
                b = blocks[x, y, z]
                if b == AIR:
                    continue
                for (dx, dy, dz), corners, n, which in FACES:
                    nx, ny, nz = x + dx, y + dy, z + dz
                    inside = 0 <= nx < sx and 0 <= ny < sy and 0 <= nz < sz
                    nb = blocks[nx, ny, nz] if inside else AIR
                    if b == WATER:
                        if nb != AIR:
                            continue
                    elif inside and solid[nx, ny, nz]:
                        continue
                    elif nb == WATER and b != WATER and dy != 1:
                        # Under water: the sides of the bed show through the water.
                        pass
                    t = FACE_TILES[b][which]
                    u0, v0, u1, v1 = tile_uv(t)
                    base = len(pos)
                    for i, (cx, cy, cz) in enumerate(corners):
                        pos.append((x + cx + ox, y + cy, z + cz + oz))
                        nrm.append(n)
                    # v runs down the image in glTF (top-left origin).
                    uv += [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
                    idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    return (np.array(pos, np.float32), np.array(nrm, np.float32),
            np.array(uv, np.float32), np.array(idx, np.uint32))


def write_glb(path, pos, nrm, uv, idx, atlas_path):
    with open(atlas_path, "rb") as f:
        png = f.read()
    bin_ = bytearray()
    views = []

    def view(data, target=None):
        while len(bin_) % 4:
            bin_.append(0)
        off = len(bin_)
        bin_.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    accessors = [
        {"bufferView": view(pos.tobytes(), 34962), "componentType": 5126, "count": len(pos), "type": "VEC3",
         "min": [float(v) for v in pos.min(axis=0)], "max": [float(v) for v in pos.max(axis=0)]},
        {"bufferView": view(nrm.tobytes(), 34962), "componentType": 5126, "count": len(nrm), "type": "VEC3"},
        {"bufferView": view(uv.tobytes(), 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"},
        {"bufferView": view(idx.tobytes(), 34963), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
    ]
    img_view = view(png)
    j = {
        "asset": {"version": "2.0", "generator": "starling voxel-world.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "land"}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                    "indices": 3, "material": 0, "mode": 4}]}],
        # NEAREST both ways: the pixels are the point.
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"bufferView": img_view, "mimeType": "image/png"}],
        "textures": [{"sampler": 0, "source": 0}],
        "materials": [{"name": "blocks", "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}],
    }
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    while len(bin_) % 4:
        bin_.append(0)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(bin_), 0x004E4942)); f.write(bin_)


# ------------------------------------------------------------- the sky

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


def sky(w=1024, h=512, sun_dir=(0.45, 0.62, -0.64), with_sun=True):
    """A clear blocky-world sky: blue above, pale at the horizon, a warm
    ground below (for the bounce light), and a SQUARE sun. Directions in
    cmgen's convention: u = (atan2(x, z) / pi + 1) / 2, v down from +y."""
    v = (np.arange(h) + 0.5) / h
    u = (np.arange(w) + 0.5) / w
    lat = (0.5 - v) * np.pi
    phi = (u * 2 - 1) * np.pi
    img = np.zeros((h, w, 3), np.float32)
    up = np.clip(np.sin(lat), 0, 1)[:, None]
    zenith = np.array([0.1, 0.28, 0.85]); horizon = np.array([0.5, 0.68, 0.95])
    skyc = horizon[None, None, :] * (1 - up[..., None] ** 0.6) + zenith[None, None, :] * up[..., None] ** 0.6
    ground = np.array([0.42, 0.5, 0.3])
    below = (lat < 0)[:, None, None]
    img = np.where(below, ground[None, None, :] * 0.9, skyc * 1.2)
    img = np.broadcast_to(img, (h, w, 3)).copy()
    if with_sun:
        # The sun as a square patch of directions, Minecraft-style.
        sd = np.array(sun_dir) / np.linalg.norm(sun_dir)
        dx = np.cos(lat)[:, None] * np.sin(phi)[None, :]
        dy = np.sin(lat)[:, None] * np.ones_like(phi)[None, :]
        dz = np.cos(lat)[:, None] * np.cos(phi)[None, :]
        dirs = np.stack([dx, dy, dz], -1)
        # A square: the max of the two tangent-plane offsets.
        t1 = np.cross(sd, [0, 1, 0]); t1 /= np.linalg.norm(t1)
        t2 = np.cross(sd, t1)
        a = np.abs(dirs @ t1); b = np.abs(dirs @ t2)
        front = dirs @ sd > 0
        sun = front & (np.maximum(a, b) < 0.045)
        img[sun] = (60.0, 55.0, 42.0)
    return img.astype(np.float32)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.expanduser("~/tmp/filament/voxel"))
    ap.add_argument("--size", type=int, default=60)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--cmgen", default=os.path.expanduser("~/dev/filament/gles/bin/cmgen"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    atlas = os.path.join(a.out, "atlas.png")
    make_atlas(atlas, a.seed)
    blocks = build_city(a.size, a.seed)
    origin = (-a.size // 2, -a.size // 2)          # the square at x = z = 0
    pos, nrm, uv, idx = mesh_blocks(blocks, origin)
    write_glb(os.path.join(a.out, "room.glb"), pos, nrm, uv, idx, atlas)
    plaza_h = G
    print(f"  {a.size}x{a.size} columns, ground at y={G}, {len(idx)//3} triangles")

    sun_dir = (0.45, 0.62, -0.64)
    write_hdr(os.path.join(a.out, "sky-full.hdr"), sky(sun_dir=sun_dir, with_sun=True))
    write_hdr(os.path.join(a.out, "sky-nosun.hdr"), sky(sun_dir=sun_dir, with_sun=False))
    for sub, src, size in (("ibl", "sky-nosun.hdr", 64), ("sky", "sky-full.hdr", 512)):
        subprocess.run([a.cmgen, "--quiet", "--format=ktx", f"--size={size}",
                        f"--deploy={os.path.join(a.out, sub)}", os.path.join(a.out, src)], check=True)
    os.replace(os.path.join(a.out, "ibl", "ibl_ibl.ktx"), os.path.join(a.out, "room_ibl.ktx"))
    os.replace(os.path.join(a.out, "sky", "sky_skybox.ktx"), os.path.join(a.out, "room_skybox.ktx"))

    # Where feet go: the ground is level, and buildings are not climbed.
    surface = np.full((a.size, a.size), G + 1, int)
    world = {
        "kind": "voxel",
        "exposure": [16.0, 1.0 / 125.0, 100.0],
        "ibl_intensity": 22000.0,
        "sun": {"dir": list(sun_dir), "colour": [1.0, 0.96, 0.9], "lux": 90000.0},
        "hub": [0.0, float(plaza_h + 1), 0.0],
        "eye_height": 1.62,
        "ring_radius": 7.5,
        "heightmap": {"origin": [origin[0], origin[1]], "size": [a.size, a.size],
                      "heights": surface.T.reshape(-1).tolist()},   # [x][z] order
        "camera_home": {"radius": 10.5, "height": 0.0},
    }
    with open(os.path.join(a.out, "world.json"), "w") as f:
        json.dump(world, f)
    for n in ("room.glb", "room_ibl.ktx", "room_skybox.ktx", "world.json", "atlas.png"):
        print(f"  {n:18s} {os.path.getsize(os.path.join(a.out, n))/1e6:6.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
