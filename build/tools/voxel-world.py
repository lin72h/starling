#!/usr/bin/env python3
"""Make the voxel world: a blocky city for the desktop to stand in.

    voxel-world.py [--out <dir>] [--size 96] [--seed 3]

A street grid with blocky buildings in several styles — concrete,
brick, painted plaster, sandstone, glass towers with setbacks — their
doors facing the square under awnings and shop signs, windows lit here
and there, roofs with parapets, water tanks and aerials; crosswalks and
lamp posts at the corners, street trees; and a square in the middle
with a low pool, lamps and trees, where the open windows stand. Every
block face is a quad with a pixel-art tile from an atlas drawn here,
sampled with NEAREST so the pixels stay pixels. One glTF, one material,
plus a gradient sky with a square sun for cmgen, and world.json with
the ground height so the viewer can walk on it, and the block tile the
window frames are made of.

Outputs: room.glb, room_ibl.ktx, room_skybox.ktx, world.json, atlas.png,
frame.png (the renderer's names for any world).
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
ATLAS = 8            # tiles per side
TILES = [
    "asphalt", "roadline", "sidewalk", "concrete", "window", "window_lit", "brick", "roof",
    "plaza", "grass", "log", "leaves", "lamp", "water", "dark", "stone",
    "crosswalk", "plaster_cream", "plaster_terra", "plaster_sage", "plaster_blue",
    "glass", "glass_lit", "steel", "door_top", "door_bottom", "shop",
    "awning_red", "awning_green", "awning_blue", "sign_red", "sign_blue", "sign_green",
    "sign_yellow", "sign_white", "sandstone", "sandstone_window", "flowers", "tank",
    "vent", "planks", "brick_window", "plaster_window", "cornice",
]
T = {name: i for i, name in enumerate(TILES)}
assert len(TILES) <= ATLAS * ATLAS


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


def window_tile(rng, wall, glass, glass_hi, frame=(0.6, 0.6, 0.6), sill=None):
    win = noise_tile(rng, wall, 0.02)
    win[2:14, 2:14] = glass
    win[3:13, 3:8] = glass_hi
    win[2:14, 8] = frame
    if sill is not None:
        win[14, 1:15] = sill
    return win


def sign_tile(rng, bg, ink):
    s = noise_tile(rng, bg, 0.01)
    s[0, :] = s[15, :] = s[:, 0] = s[:, 15] = np.array(bg) * 0.6
    # Lettering: two rows of short dark runs, the way text reads from
    # across a street.
    for row in (4, 5, 9, 10):
        x = 2
        while x < 14:
            n = int(rng.integers(1, 3))
            if rng.random() < 0.75:
                s[row, x:min(x + n, 14)] = ink
            x += n + 1
    return s


def awning_tile(rng, colour):
    a = np.zeros((TILE, TILE, 3), np.float32)
    for x in range(TILE):
        a[:, x] = colour if (x // 2) % 2 == 0 else (0.95, 0.95, 0.92)
    a[15, :] = np.array(colour) * 0.7
    return a


def planks_tile(rng, base=(0.58, 0.42, 0.25), seam=(0.34, 0.24, 0.13)):
    p = noise_tile(rng, base, 0.02, None, (0.66, 0.5, 0.31))
    for y in range(0, TILE, 4):
        p[y, :] = seam
        off = 0 if (y // 4) % 2 == 0 else 8
        p[y:y + 4, (off + 3) % 16] = seam
    return p


def make_tiles(seed=1):
    rng = np.random.default_rng(seed)
    t = {}
    grey_dark = (0.5, 0.5, 0.48)
    t["asphalt"] = noise_tile(rng, (0.17, 0.17, 0.18), 0.02, (0.13, 0.13, 0.14), (0.22, 0.22, 0.23))
    line = noise_tile(rng, (0.17, 0.17, 0.18), 0.02)
    line[:, 7:9] = (0.85, 0.72, 0.2)
    t["roadline"] = line
    cross = noise_tile(rng, (0.17, 0.17, 0.18), 0.02)
    for x in range(1, 16, 4):
        cross[:, x:x + 2] = (0.9, 0.9, 0.88)
    t["crosswalk"] = cross
    walk = noise_tile(rng, (0.64, 0.63, 0.6), 0.02)
    walk[0, :] = grey_dark; walk[:, 0] = grey_dark
    t["sidewalk"] = walk
    t["concrete"] = noise_tile(rng, (0.74, 0.72, 0.68), 0.025, (0.66, 0.64, 0.6))
    t["window"] = window_tile(rng, (0.74, 0.72, 0.68), (0.22, 0.3, 0.42), (0.28, 0.38, 0.52))
    t["window_lit"] = window_tile(rng, (0.74, 0.72, 0.68), (0.98, 0.86, 0.5), (1.0, 0.92, 0.62))
    brick = noise_tile(rng, (0.6, 0.28, 0.2), 0.03, (0.5, 0.22, 0.16))
    mortar = (0.72, 0.68, 0.62)
    for y in range(TILE):
        if y % 4 == 0:
            brick[y] = mortar
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(TILE):
            if (x + off) % 8 == 0:
                brick[y, x] = mortar
    t["brick"] = brick
    bw = brick.copy()
    bw[2:14, 2:14] = (0.2, 0.26, 0.36); bw[3:13, 3:8] = (0.26, 0.34, 0.46); bw[2:14, 8] = (0.85, 0.82, 0.78)
    bw[14, 1:15] = (0.8, 0.76, 0.7)
    t["brick_window"] = bw
    t["roof"] = noise_tile(rng, (0.24, 0.23, 0.22), 0.03, (0.18, 0.17, 0.16), (0.32, 0.31, 0.3))
    plaza = noise_tile(rng, (0.58, 0.56, 0.52), 0.02)
    for k in (0, 8):
        plaza[k, :] = (0.42, 0.4, 0.38); plaza[:, k] = (0.42, 0.4, 0.38)
    t["plaza"] = plaza
    t["grass"] = noise_tile(rng, (0.36, 0.62, 0.22), 0.04, (0.28, 0.5, 0.16), (0.46, 0.7, 0.3))
    flowers = t["grass"].copy()
    for _ in range(9):
        x, y = rng.integers(1, 15, 2)
        flowers[y, x] = [(0.9, 0.2, 0.2), (0.95, 0.85, 0.2), (0.95, 0.95, 0.95), (0.7, 0.3, 0.8)][int(rng.integers(0, 4))]
        flowers[y + 1, x] = (0.2, 0.42, 0.12)
    t["flowers"] = flowers
    log = noise_tile(rng, (0.4, 0.3, 0.18), 0.03)
    for x in range(0, TILE, 4):
        log[:, x] = (0.3, 0.22, 0.12)
    t["log"] = log
    t["leaves"] = noise_tile(rng, (0.2, 0.48, 0.14), 0.05, (0.12, 0.34, 0.08), (0.3, 0.6, 0.22))
    t["lamp"] = noise_tile(rng, (1.0, 0.92, 0.6), 0.02)
    t["water"] = noise_tile(rng, (0.2, 0.42, 0.85), 0.03, (0.16, 0.36, 0.78), (0.3, 0.52, 0.92))
    t["dark"] = noise_tile(rng, (0.12, 0.12, 0.14), 0.02)
    t["stone"] = noise_tile(rng, (0.5, 0.5, 0.5), 0.035, (0.4, 0.4, 0.42), (0.58, 0.58, 0.58))
    # Painted plaster in a few colours, with a tall window that suits it.
    for name, col in (("plaster_cream", (0.9, 0.84, 0.68)), ("plaster_terra", (0.78, 0.46, 0.32)),
                      ("plaster_sage", (0.62, 0.7, 0.56)), ("plaster_blue", (0.5, 0.64, 0.78))):
        t[name] = noise_tile(rng, col, 0.015, None, tuple(min(1, c * 1.08) for c in col))
    pw = noise_tile(rng, (0.9, 0.84, 0.68), 0.015)
    pw[1:15, 4:12] = (0.2, 0.28, 0.4); pw[2:14, 5:8] = (0.28, 0.38, 0.52); pw[1:15, 8] = (0.92, 0.92, 0.9)
    pw[1:15, 3] = pw[1:15, 12] = (0.96, 0.95, 0.92); pw[15, 2:14] = (0.7, 0.66, 0.55)
    t["plaster_window"] = pw
    # A glass curtain wall: dark panes in a light mullion grid.
    glass = noise_tile(rng, (0.16, 0.24, 0.34), 0.02, None, (0.26, 0.36, 0.48))
    glass[0, :] = (0.55, 0.57, 0.6); glass[:, 0] = (0.55, 0.57, 0.6); glass[8, :] = (0.45, 0.47, 0.5)
    t["glass"] = glass
    gl = glass.copy(); gl[1:8, 1:16] = (0.9, 0.84, 0.6); gl[9:16, 1:16] = (0.95, 0.9, 0.7)
    gl[8, :] = (0.45, 0.47, 0.5); gl[:, 0] = (0.55, 0.57, 0.6)
    t["glass_lit"] = gl
    steel = noise_tile(rng, (0.55, 0.57, 0.6), 0.02, (0.48, 0.5, 0.53))
    steel[0, :] = (0.4, 0.42, 0.45); steel[:, 0] = (0.4, 0.42, 0.45)
    t["steel"] = steel
    t["cornice"] = noise_tile(rng, (0.82, 0.8, 0.76), 0.015, (0.7, 0.68, 0.64))
    t["cornice"][6:8, :] = (0.62, 0.6, 0.56); t["cornice"][12:14, :] = (0.62, 0.6, 0.56)
    # A door, two blocks tall: a pane in the top half, panels and a knob below.
    wood = (0.45, 0.3, 0.16); jamb = (0.3, 0.2, 0.1)
    top = noise_tile(rng, wood, 0.015); top[:, 0:2] = jamb; top[:, 14:16] = jamb; top[0:2, :] = jamb
    top[4:10, 4:12] = (0.55, 0.7, 0.85); top[5:9, 5:8] = (0.7, 0.82, 0.92); top[4:10, 8] = jamb
    t["door_top"] = top
    bot = noise_tile(rng, wood, 0.015); bot[:, 0:2] = jamb; bot[:, 14:16] = jamb; bot[14:16, :] = jamb
    bot[3:11, 4:12] = (0.4, 0.26, 0.13); bot[4:10, 5:11] = wood; bot[6:8, 12] = (0.9, 0.75, 0.3)
    t["door_bottom"] = bot
    # A shopfront: a big pane with something warm lit inside.
    shop = noise_tile(rng, (0.2, 0.3, 0.42), 0.02)
    shop[0, :] = shop[15, :] = shop[:, 0] = shop[:, 15] = (0.25, 0.25, 0.27)
    shop[8:13, 3:13] = (0.62, 0.5, 0.34); shop[9:12, 4:12] = (0.85, 0.72, 0.45)
    for k in range(1, 6):
        shop[k, 12 - k] = (0.45, 0.58, 0.72)
    t["shop"] = shop
    for name, col in (("awning_red", (0.8, 0.18, 0.16)), ("awning_green", (0.16, 0.5, 0.3)),
                      ("awning_blue", (0.18, 0.32, 0.68))):
        t[name] = awning_tile(rng, col)
    for name, bg, ink in (("sign_red", (0.78, 0.16, 0.14), (0.98, 0.94, 0.8)),
                          ("sign_blue", (0.16, 0.3, 0.62), (0.96, 0.96, 0.9)),
                          ("sign_green", (0.14, 0.46, 0.3), (0.96, 0.94, 0.8)),
                          ("sign_yellow", (0.94, 0.78, 0.2), (0.2, 0.16, 0.1)),
                          ("sign_white", (0.94, 0.93, 0.9), (0.16, 0.16, 0.2))):
        t[name] = sign_tile(rng, bg, ink)
    sand = noise_tile(rng, (0.8, 0.72, 0.55), 0.02, (0.7, 0.62, 0.46))
    sand[0, :] = (0.66, 0.58, 0.42); sand[8, :] = (0.66, 0.58, 0.42)
    sand[0:8, 5] = (0.66, 0.58, 0.42); sand[8:16, 12] = (0.66, 0.58, 0.42)
    t["sandstone"] = sand
    sw = sand.copy(); sw[1:14, 3:13] = (0.22, 0.28, 0.36); sw[2:13, 4:8] = (0.3, 0.38, 0.48)
    sw[1, 3] = sw[1, 12] = (0.8, 0.72, 0.55); sw[1:14, 8] = (0.78, 0.7, 0.55); sw[14, 2:14] = (0.62, 0.54, 0.4)
    t["sandstone_window"] = sw
    tank = noise_tile(rng, (0.5, 0.52, 0.55), 0.02, (0.55, 0.35, 0.25))
    tank[3, :] = tank[12, :] = (0.36, 0.38, 0.4)
    t["tank"] = tank
    vent = noise_tile(rng, (0.4, 0.42, 0.44), 0.02)
    for y in range(2, 14, 3):
        vent[y, 1:15] = (0.24, 0.25, 0.27)
    t["vent"] = vent
    t["planks"] = planks_tile(rng)
    return t


def make_atlas(path, frame_path, seed=1):
    tiles = make_tiles(seed)
    atlas = np.zeros((ATLAS * TILE, ATLAS * TILE, 3), np.float32)
    for name, i in T.items():
        r, c = divmod(i, ATLAS)
        atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = tiles[name]
    Image.fromarray((atlas * 255).astype(np.uint8)).save(path)
    Image.fromarray((tiles["planks"] * 255).astype(np.uint8)).save(frame_path)


def tile_uv(i):
    """The UV rectangle of a tile, inset half a texel so nothing bleeds."""
    r, c = divmod(i, ATLAS)
    e = 0.5 / (ATLAS * TILE)
    return (c / ATLAS + e, r / ATLAS + e, (c + 1) / ATLAS - e, (r + 1) / ATLAS - e)


# ------------------------------------------------------------ the land

# Block kinds: name -> (top tile, side tile, bottom tile).
BLOCKS = [
    ("air", None),
    ("asphalt", ("asphalt", "asphalt", "asphalt")),
    ("roadline", ("roadline", "asphalt", "asphalt")),
    ("crosswalk", ("crosswalk", "asphalt", "asphalt")),
    ("sidewalk", ("sidewalk", "sidewalk", "sidewalk")),
    ("concrete", ("concrete", "concrete", "concrete")),
    ("window", ("concrete", "window", "concrete")),
    ("window_lit", ("concrete", "window_lit", "concrete")),
    ("brick", ("brick", "brick", "brick")),
    ("brick_window", ("brick", "brick_window", "brick")),
    ("brick_window_lit", ("brick", "window_lit", "brick")),
    ("roof", ("roof", "concrete", "concrete")),
    ("plaza", ("plaza", "plaza", "plaza")),
    ("grass", ("grass", "grass", "grass")),
    ("flowers", ("flowers", "grass", "grass")),
    ("log", ("log", "log", "log")),
    ("leaves", ("leaves", "leaves", "leaves")),
    ("lamp", ("lamp", "lamp", "lamp")),
    ("water", ("water", "water", "water")),
    ("dark", ("dark", "dark", "dark")),
    ("stone", ("stone", "stone", "stone")),
    ("plaster_cream", ("plaster_cream",) * 3),
    ("plaster_terra", ("plaster_terra",) * 3),
    ("plaster_sage", ("plaster_sage",) * 3),
    ("plaster_blue", ("plaster_blue",) * 3),
    ("plaster_window", ("plaster_cream", "plaster_window", "plaster_cream")),
    ("glass", ("steel", "glass", "steel")),
    ("glass_lit", ("steel", "glass_lit", "steel")),
    ("steel", ("steel", "steel", "steel")),
    ("cornice", ("cornice", "cornice", "cornice")),
    ("door_top", ("concrete", "door_top", "concrete")),
    ("door_bottom", ("concrete", "door_bottom", "concrete")),
    ("shop", ("concrete", "shop", "concrete")),
    ("awning_red", ("awning_red",) * 3),
    ("awning_green", ("awning_green",) * 3),
    ("awning_blue", ("awning_blue",) * 3),
    ("sign_red", ("sign_red",) * 3),
    ("sign_blue", ("sign_blue",) * 3),
    ("sign_green", ("sign_green",) * 3),
    ("sign_yellow", ("sign_yellow",) * 3),
    ("sign_white", ("sign_white",) * 3),
    ("sandstone", ("sandstone",) * 3),
    ("sandstone_window", ("sandstone", "sandstone_window", "sandstone")),
    ("sandstone_window_lit", ("sandstone", "window_lit", "sandstone")),
    ("tank", ("tank", "tank", "tank")),
    ("vent", ("vent", "vent", "vent")),
    ("planks", ("planks",) * 3),
]
B = {name: i for i, (name, _) in enumerate(BLOCKS)}
AIR, WATER = B["air"], B["water"]
# Face tiles as an array: [block][top, side, bottom] -> tile index.
FACE_TILES = np.zeros((len(BLOCKS), 3), np.int32)
for i, (name, faces) in enumerate(BLOCKS):
    if faces:
        FACE_TILES[i] = [T[f] for f in faces]
SOLID = np.array([i for i, (name, faces) in enumerate(BLOCKS) if faces and name != "water"])

CELL = 12        # a city block: 4 of street, then the lot
G = 4            # ground level: the surface block's y
POST_H = 7       # the post in the pool the app blocks spiral round, above the pool

# Building styles: the wall block, its window, its lit window, how the
# windows are laid out, and the roof parapet.
STYLES = {
    "concrete": dict(wall="concrete", win="window", lit="window_lit", rows=2, gap=1, top="concrete"),
    "brick": dict(wall="brick", win="brick_window", lit="brick_window_lit", rows=2, gap=2, top="cornice"),
    "plaster_cream": dict(wall="plaster_cream", win="plaster_window", lit="window_lit", rows=2, gap=2, top="cornice"),
    "plaster_terra": dict(wall="plaster_terra", win="plaster_window", lit="window_lit", rows=2, gap=2, top="cornice"),
    "plaster_sage": dict(wall="plaster_sage", win="plaster_window", lit="window_lit", rows=2, gap=2, top="cornice"),
    "plaster_blue": dict(wall="plaster_blue", win="plaster_window", lit="window_lit", rows=2, gap=2, top="cornice"),
    "sandstone": dict(wall="sandstone", win="sandstone_window", lit="sandstone_window_lit", rows=3, gap=2, top="sandstone"),
    "glass": dict(wall="glass", win="glass", lit="glass_lit", rows=1, gap=0, top="steel"),
}
AWNINGS = ("awning_red", "awning_green", "awning_blue")
SIGNS = ("sign_red", "sign_blue", "sign_green", "sign_yellow", "sign_white")


def plant_tree(blocks, rng, x, base, z):
    trunk = int(rng.integers(4, 6))
    blocks[x, base:base + trunk, z] = B["log"]
    for dy, r in ((trunk - 2, 2), (trunk - 1, 2), (trunk, 1), (trunk + 1, 0)):
        y = base + dy
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                if abs(dx) == r and abs(dz) == r and r == 2:
                    continue
                xx, zz = x + dx, z + dz
                if 0 <= xx < blocks.shape[0] and 0 <= zz < blocks.shape[2] and blocks[xx, y, zz] == AIR:
                    blocks[xx, y, zz] = B["leaves"]


def build_tier(blocks, rng, x0, z0, x1, z1, y0, h, style, facing, door, shop):
    """One tier of a building: walls with windows from y0 up h blocks,
    a parapeted roof on top. `facing` is the wall the door is on
    (+x, -x, +z, -z as a unit pair), `door` whether this tier has one."""
    st = STYLES[style]
    wall, win, lit, top = B[st["wall"]], B[st["win"]], B[st["lit"]], B[st["top"]]
    rows, gap = st["rows"], st["gap"]
    lit_p = 0.22
    for x in range(x0, x1):
        for z in range(z0, z1):
            edge = x in (x0, x1 - 1) or z in (z0, z1 - 1)
            corner = x in (x0, x1 - 1) and z in (z0, z1 - 1)
            along = (x - x0) if z in (z0, z1 - 1) else (z - z0)
            for y in range(y0, y0 + h):
                if not edge:
                    blocks[x, y, z] = B["dark"]
                    continue
                floor = y - y0
                is_wall = corner or floor % rows != 1 or (gap and along % (gap + 1) == 0)
                if style == "glass":
                    is_wall = corner or floor % 4 == 3
                blocks[x, y, z] = wall if is_wall else (lit if rng.random() < lit_p else win)
            blocks[x, y0 + h, z] = top if edge else B["roof"]
    fx, fz = facing
    if fx:
        wx = x1 - 1 if fx > 0 else x0
        wz = (z0 + z1) // 2
        span = [(wx, wz + k) for k in (-1, 0, 1)]
        out = [(wx + fx, wz + k) for k in (-1, 0, 1)]
    else:
        wz = z1 - 1 if fz > 0 else z0
        wx = (x0 + x1) // 2
        span = [(wx + k, wz) for k in (-1, 0, 1)]
        out = [(wx + k, wz + fz) for k in (-1, 0, 1)]
    if shop:
        # The ground floor is glass along the door's wall, corners aside.
        for x in range(x0, x1):
            for z in range(z0, z1):
                on_wall = (x == wx) if fx else (z == wz)
                corner = x in (x0, x1 - 1) and z in (z0, z1 - 1)
                if on_wall and not corner:
                    blocks[x, y0, z] = B["shop"]
                    blocks[x, y0 + 1, z] = B["shop"]
    if door:
        blocks[wx, y0, wz] = B["door_bottom"]
        blocks[wx, y0 + 1, wz] = B["door_top"]
        awning = B[AWNINGS[int(rng.integers(0, len(AWNINGS)))]]
        for (ax, az) in out:
            if 0 <= ax < blocks.shape[0] and 0 <= az < blocks.shape[2] and blocks[ax, y0 + 2, az] == AIR:
                blocks[ax, y0 + 2, az] = awning
        if h > 4:
            sign = B[SIGNS[int(rng.integers(0, len(SIGNS)))]]
            for (sx, sz) in span:
                blocks[sx, y0 + 3, sz] = sign


def build_city(size, seed, plaza_r=13):
    """The blocks, and the props too thin to be blocks: lamp posts and
    masts, as (kind, x, y, z, height) with x/z the column they stand in."""
    rng = np.random.default_rng(seed)
    height = 48
    blocks = np.zeros((size, height, size), np.uint8)        # x, y, z
    props = []
    c = size // 2
    blocks[:, :G, :] = B["stone"]
    for x in range(size):
        for z in range(size):
            d = max(abs(x - c), abs(z - c))
            cx, cz = x % CELL, z % CELL
            if d < plaza_r:
                blocks[x, G, z] = B["plaza"]
            elif cx < 4 and cz < 4:
                blocks[x, G, z] = B["asphalt"]
            elif cx < 4:
                if cz in (4, 11):
                    blocks[x, G, z] = B["crosswalk"]
                else:
                    blocks[x, G, z] = B["roadline"] if (cx == 2 and z % 2 == 0) else B["asphalt"]
            elif cz < 4:
                if cx in (4, 11):
                    blocks[x, G, z] = B["crosswalk"]
                else:
                    blocks[x, G, z] = B["roadline"] if (cz == 2 and x % 2 == 0) else B["asphalt"]
            else:
                blocks[x, G, z] = B["sidewalk"]
    # Buildings: one per lot, its footprint the lot less the pavement,
    # taller toward the middle, a few towers with setbacks.
    styles = list(STYLES)
    weights = np.array([3, 2.5, 1, 1, 1, 1, 1.5, 1.5]); weights /= weights.sum()
    lots = []
    for lx in range(0, size, CELL):
        for lz in range(0, size, CELL):
            x0, z0 = lx + 5, lz + 5
            x1, z1 = min(lx + 11, size), min(lz + 11, size)
            if x1 - x0 < 4 or z1 - z0 < 4:
                continue
            mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
            if max(abs(mx - c), abs(mz - c)) < plaza_r + 4:
                continue
            near = max(abs(mx - c), abs(mz - c)) / (size / 2)
            style = styles[int(rng.choice(len(styles), p=weights))]
            h = int(rng.integers(5, 10) + (1 - near) * rng.integers(4, 14))
            tower = near < 0.55 and rng.random() < 0.3
            if tower:
                style = "glass" if rng.random() < 0.5 else style
                h = int(rng.integers(16, 26))
            # The door faces the square: on the wall nearest the middle.
            dx, dz = c - mx, c - mz
            facing = (int(np.sign(dx)), 0) if abs(dx) > abs(dz) else (0, int(np.sign(dz)))
            lots.append((x0, z0, x1, z1, h, style, facing, tower))
    for x0, z0, x1, z1, h, style, facing, tower in lots:
        shop = style != "glass" and rng.random() < 0.55
        if tower and h > 14:
            h1 = int(h * 0.55)
            build_tier(blocks, rng, x0, z0, x1, z1, G + 1, h1, style, facing, True, shop)
            build_tier(blocks, rng, x0 + 1, z0 + 1, x1 - 1, z1 - 1, G + 1 + h1 + 1, h - h1 - 1, style, facing, False, False)
            top = G + 1 + h
            # An aerial on the tallest.
            props.append(("mast", (x0 + x1) // 2, top + 1, (z0 + z1) // 2, int(rng.integers(3, 6))))
        else:
            build_tier(blocks, rng, x0, z0, x1, z1, G + 1, h, style, facing, True, shop)
            top = G + 1 + h
            r = rng.random()
            if r < 0.35:
                # A water tank on legs.
                tx, tz = x0 + 1, z0 + 1
                blocks[tx:tx + 2, top + 1, tz:tz + 2] = B["log"]
                blocks[tx:tx + 2, top + 2:top + 4, tz:tz + 2] = B["tank"]
            elif r < 0.65:
                # An air handler.
                blocks[x1 - 3:x1 - 1, top + 1, z1 - 3:z1 - 1] = B["vent"]
    # A lamp post at every corner, a street tree on a few lots.
    for lx in range(0, size, CELL):
        for lz in range(0, size, CELL):
            for (px, pz) in ((lx + 4, lz + 4), (lx + 11, lz + 11)):
                if px >= size or pz >= size or max(abs(px - c), abs(pz - c)) < plaza_r + 2:
                    continue
                if blocks[px, G + 1, pz] != AIR:
                    continue
                props.append(("lamp", px, G + 1, pz, 3))
            tx, tz = (lx + 11, lz + 4) if rng.random() < 0.5 else (lx + 4, lz + 11)
            if tx < size and tz < size and max(abs(tx - c), abs(tz - c)) >= plaza_r + 2 \
                    and rng.random() < 0.15 and blocks[tx, G + 1, tz] == AIR:
                blocks[tx, G, tz] = B["grass"]
                plant_tree(blocks, rng, tx, G + 1, tz)
    # The square: a pool in the middle with a slim post rising out of it,
    # round which the desktop's apps stand as blocks in a rising spiral
    # (the shell's sculpture — the launcher); lamp posts; trees in beds
    # of flowers at the corners. The windows stand round the sculpture,
    # never straight behind it from the door.
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            r = max(abs(dx), abs(dz))
            if r == 3:
                blocks[c + dx, G + 1, c + dz] = B["concrete"]
            elif r <= 2:
                blocks[c + dx, G + 1, c + dz] = B["water"]
    blocks[c, G + 1:G + 1 + POST_H, c] = B["sandstone"]
    blocks[c, G + 1 + POST_H, c] = B["lamp"]
    for sx, sz in ((-9, -9), (9, -9), (-9, 9), (9, 9)):
        props.append(("lamp", c + sx, G + 1, c + sz, 3))
    for sx, sz in ((-12, -12), (12, -12), (-12, 12), (12, 12)):
        for dx in range(-1, 2):
            for dz in range(-1, 2):
                blocks[c + sx + dx, G, c + sz + dz] = B["flowers"] if (dx or dz) else B["grass"]
        plant_tree(blocks, rng, c + sx, G + 1, c + sz)
    return blocks, props


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


def shifted(a, d, fill):
    """`a` moved by -d, so out[x] = a[x + d]; `fill` past the edge."""
    out = np.full_like(a, fill)
    dx, dy, dz = d
    sx, sy, sz = a.shape
    src = (slice(max(dx, 0), sx + min(dx, 0)), slice(max(dy, 0), sy + min(dy, 0)), slice(max(dz, 0), sz + min(dz, 0)))
    dst = (slice(max(-dx, 0), sx + min(-dx, 0)), slice(max(-dy, 0), sy + min(-dy, 0)), slice(max(-dz, 0), sz + min(-dz, 0)))
    out[dst] = a[src]
    return out


def box_quads(x0, y0, z0, x1, y1, z1, tile, out):
    """An axis-aligned box's six faces, the tile stretched over each."""
    u0, v0, u1, v1 = tile_uv(tile)
    lo, hi = np.array([x0, y0, z0], np.float32), np.array([x1, y1, z1], np.float32)
    for _, corners, n, _ in FACES:
        quad = np.array([lo + (hi - lo) * np.array(cn, np.float32) for cn in corners], np.float32)
        out["pos"].append(quad)
        out["nrm"].append(np.tile(np.array(n, np.float32), (4, 1)))
        out["uv"].append(np.array([(u0, v1), (u1, v1), (u1, v0), (u0, v0)], np.float32))
        out["count"] += 1


def mesh_props(props, origin, out):
    """Lamp posts (a thin log with a glowing block on top) and masts."""
    ox, oz = origin
    for kind, x, y, z, h in props:
        cx, cz = x + ox + 0.5, z + oz + 0.5
        if kind == "lamp":
            box_quads(cx - 0.1, y, cz - 0.1, cx + 0.1, y + h, cz + 0.1, T["log"], out)
            box_quads(cx - 0.25, y + h, cz - 0.25, cx + 0.25, y + h + 0.5, cz + 0.25, T["lamp"], out)
        elif kind == "mast":
            box_quads(cx - 0.08, y, cz - 0.08, cx + 0.08, y + h, cz + 0.08, T["dark"], out)
            box_quads(cx - 0.3, y + h - 0.6, cz - 0.05, cx + 0.3, y + h - 0.5, cz + 0.05, T["dark"], out)


def mesh_blocks(blocks, origin, props=()):
    """Every block face with air (or, for the water's bed, water) beyond
    it, as quads — one pass of array arithmetic per face direction."""
    ox, oz = origin
    solid = np.isin(blocks, SOLID)
    pos, nrm, uv = [], [], []
    count = 0
    uvs = np.array([tile_uv(i) for i in range(ATLAS * ATLAS)], np.float32)   # u0 v0 u1 v1
    for d, corners, n, which in FACES:
        nb = shifted(blocks, d, AIR)
        nsolid = shifted(solid, d, False)
        visible = np.where(blocks == WATER, nb == AIR, (blocks != AIR) & ~nsolid)
        cells = np.argwhere(visible)
        if not len(cells):
            continue
        tiles = FACE_TILES[blocks[visible], which]
        u0, v0, u1, v1 = uvs[tiles].T
        base = cells.astype(np.float32) + np.array([ox, 0, oz], np.float32)
        quad = np.stack([base + np.array(cn, np.float32) for cn in corners], axis=1)   # (n, 4, 3)
        pos.append(quad.reshape(-1, 3))
        nrm.append(np.tile(np.array(n, np.float32), (len(cells) * 4, 1)))
        # v runs down the image in glTF (top-left origin).
        uv.append(np.stack([np.stack([u0, v1], 1), np.stack([u1, v1], 1),
                            np.stack([u1, v0], 1), np.stack([u0, v0], 1)], axis=1).reshape(-1, 2))
        count += len(cells)
    extra = {"pos": [], "nrm": [], "uv": [], "count": 0}
    mesh_props(props, origin, extra)
    if extra["count"]:
        pos.append(np.concatenate(extra["pos"])); nrm.append(np.concatenate(extra["nrm"]))
        uv.append(np.concatenate(extra["uv"])); count += extra["count"]
    pos = np.concatenate(pos); nrm = np.concatenate(nrm); uv = np.concatenate(uv).astype(np.float32)
    b = np.arange(count, dtype=np.uint32)[:, None] * 4
    idx = (b + np.array([0, 1, 2, 0, 2, 3], np.uint32)).reshape(-1)
    return pos, nrm, uv, idx


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


def sky(w=1024, h=512, sun_dir=(0.55, 0.75, 0.45), with_sun=True):
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
    ap.add_argument("--size", type=int, default=96)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--cmgen", default=os.path.expanduser("~/dev/filament/gles/bin/cmgen"))
    ap.add_argument("--no-sky", action="store_true", help="keep the sky already there (faster)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    atlas = os.path.join(a.out, "atlas.png")
    make_atlas(atlas, os.path.join(a.out, "frame.png"), a.seed)
    blocks, props = build_city(a.size, a.seed)
    origin = (-a.size // 2, -a.size // 2)          # the square at x = z = 0
    pos, nrm, uv, idx = mesh_blocks(blocks, origin, props)
    write_glb(os.path.join(a.out, "room.glb"), pos, nrm, uv, idx, atlas)
    plaza_h = G
    print(f"  {a.size}x{a.size} columns, ground at y={G}, {len(idx)//3} triangles")

    sun_dir = (0.55, 0.75, 0.45)
    if not a.no_sky:
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
        "camera_home": {"radius": 10.5, "height": 0.0, "dolly": 6.0},
        # The windows' frames are blocks of this world: a plank tile,
        # one per `block` metres, a `margin` wide and `depth` deep.
        "pane_frame": {"texture": "frame.png", "block": 0.25, "margin": 0.25, "depth": 0.25},
        # The sculpture: the launcher's app blocks spiral round this axis at
        # this radius, from the water's top up.
        "sculpture": {"x": 0.0, "z": 0.0, "radius": 2.0, "base": float(G + 2)},
    }
    with open(os.path.join(a.out, "world.json"), "w") as f:
        json.dump(world, f)
    for n in ("room.glb", "room_ibl.ktx", "room_skybox.ktx", "world.json", "atlas.png", "frame.png"):
        print(f"  {n:18s} {os.path.getsize(os.path.join(a.out, n))/1e6:6.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
