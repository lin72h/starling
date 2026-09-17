#!/usr/bin/env python3
"""Bake the 3D desktop's room into one file the shell loads.

    room-import.py [--assets <dir>] [--out <dir>] [--preview <png>]

The room's SHELL — floor, walls, ceiling, the wall of windows — is
generated here. Its FURNITURE comes from Poly Haven's CC0 library
(`room-fetch.py`), because hand-modelled boxes read as polystyrene no
matter how well they are lit.

Everything is baked here rather than in the shell: the geometry is
flattened into one indexed mesh, the textures are packed into two
atlases, and the light — ambient occlusion and the daylight coming
through the windows — is computed against the real triangles and written
into the vertices. The shell then has nothing to do but upload it and
draw it, and this can be iterated on without rebuilding anything.

Outputs, checked in under shell/Resources/Room/:
    room.mesh          header, vertices, indices
    room-diffuse.png   base colour atlas
    room-arm.png       ambient occlusion / roughness / metalness atlas
"""
import argparse
import glob
import os
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from room_gltf import Gltf  # noqa: E402
import room_hdri  # noqa: E402

# ---------------------------------------------------------------- the room

WIDTH, HEIGHT, DEPTH = 8.0, 3.0, 10.0
HALF = WIDTH / 2
# Three tall windows in the z = 0 wall.
WINDOWS = [(-3.30, -1.90, 0.42, 2.62), (-0.70, 0.70, 0.42, 2.62),
           (1.90, 3.30, 0.42, 2.62)]
# Direction TO the sun. Overwritten from the sky: the room is lit by the
# same sun the view out of its windows is, which is the whole point of
# using a captured sky rather than numbers somebody tuned by eye.
SUN = np.array([-0.34, 0.56, -0.76])
SUN /= np.linalg.norm(SUN)
# Which way the room faces in the sky's world, in degrees. The sky is a
# real place with a real sun in it; this is how the windows are pointed
# to put that sun where the room wants it.
# Rolling the equirectangular columns adds to the sun's azimuth, measured
# as atan2(x, -z). meadow_2's sun sits at 36 deg; the room wants it near
# -23, coming in over the left-hand windows.
SKY_YAW = 301.0

# Materials the shader knows. 0 is "look it up in the atlas"; the rest are
# procedural, because a floor and a wall want to tile and an atlas cannot.
M_ATLAS, M_FLOOR, M_WALL, M_CEIL, M_SKY, M_PICTURE, M_JOINERY = 0, 1, 2, 3, 4, 5, 6

# What stands where: (asset, x, z, facing degrees, y, scale).
#
# Triangle budget is the reason some obvious choices are missing. Poly
# Haven's big potted plant is 176k triangles on its own — half the room —
# and a set of encyclopaedias is 67k. Both are beautiful up close and
# neither survives being looked at from across a room, so the small plant
# stands in, scaled up.
PLACEMENT = [
    ("Sofa_01",                  -0.35, 5.15, 180, 0.0, 1.0),
    ("ArmChair_01",              -2.55, 3.05,  55, 0.0, 1.0),
    ("ArmChair_01",               1.85, 3.05, -55, 0.0, 1.0),
    ("modern_coffee_table_02",   -0.35, 3.55,   0, 0.0, 1.0),
    ("brass_vase_01",            -0.35, 3.55,  20, 0.37, 0.55),
    ("side_table_01",             1.55, 5.45,   0, 0.0, 1.0),
    ("ClassicConsole_01",        -3.55, 6.60,  90, 0.0, 1.0),
    ("ceramic_vase_02",          -3.42, 7.05,   0, 0.95, 1.0),
    ("potted_plant_04",           3.25, 8.35,   0, 0.0, 3.4),
    ("potted_plant_04",           1.55, 5.45,  40, 0.45, 1.3),
    ("modern_ceiling_lamp_01",   -0.35, 4.30,   0, 2.05, 1.0),
]


# ------------------------------------------------------------- mesh buffers

class Mesh:
    def __init__(self):
        self.pos, self.nrm, self.uv, self.mat, self.idx = [], [], [], [], []
        self.n = 0

    def add(self, pos, nrm, uv, mat, idx):
        self.pos.append(np.asarray(pos, np.float64))
        self.nrm.append(np.asarray(nrm, np.float64))
        self.uv.append(np.asarray(uv, np.float64))
        self.mat.append(np.full(len(pos), mat, np.float32))
        self.idx.append(np.asarray(idx, np.int64) + self.n)
        self.n += len(pos)

    def finish(self):
        return (np.vstack(self.pos), np.vstack(self.nrm), np.vstack(self.uv),
                np.concatenate(self.mat), np.concatenate(self.idx))


def grid_quad(mesh, a, b, c, n, mat, cols, rows, uv_unit=False, uv_scale=1.0):
    """A planar quad a->b across, a->c down, subdivided for the light bake."""
    a, b, c = np.array(a, float), np.array(b, float), np.array(c, float)
    su = np.linspace(0, 1, cols + 1)
    sv = np.linspace(0, 1, rows + 1)
    U, V = np.meshgrid(su, sv)
    P = (a[None, None, :] + (b - a)[None, None, :] * U[..., None]
         + (c - a)[None, None, :] * V[..., None]).reshape(-1, 3)
    if uv_unit:
        uv = np.stack([U.ravel(), V.ravel()], 1)
    else:
        uv = np.stack([U.ravel() * np.linalg.norm(b - a) * uv_scale,
                       V.ravel() * np.linalg.norm(c - a) * uv_scale], 1)
    nn = np.tile(np.array(n, float), (len(P), 1))
    w = cols + 1
    i0 = (np.arange(rows)[:, None] * w + np.arange(cols)[None, :]).ravel()
    idx = np.stack([i0, i0 + 1, i0 + w, i0 + 1, i0 + w + 1, i0 + w], 1).ravel()
    mesh.add(P, nn, uv, mat, idx)


def build_shell(mesh, aspect, tan_half):
    hw, h, d = HALF, HEIGHT, DEPTH
    grid_quad(mesh, (-hw, 0, 0), (hw, 0, 0), (-hw, 0, d), (0, 1, 0), M_FLOOR, 96, 120)
    grid_quad(mesh, (-hw, h, d), (hw, h, d), (-hw, h, 0), (0, -1, 0), M_CEIL, 32, 40)
    # Fine enough that the edge of a sun patch is a line and not a stair:
    # the light is baked per VERTEX, so a wall's subdivision is the
    # resolution of every shadow that falls on it.
    grid_quad(mesh, (-hw, 0, 0), (-hw, 0, d), (-hw, h, 0), (1, 0, 0), M_WALL, 100, 32)
    grid_quad(mesh, (hw, 0, d), (hw, 0, 0), (hw, h, d), (-1, 0, 0), M_WALL, 100, 32)
    grid_quad(mesh, (hw, 0, d), (-hw, 0, d), (hw, h, d), (0, 0, -1), M_WALL, 80, 32)

    xs = [-hw]
    for wl, wr, _, _ in WINDOWS:
        xs += [wl, wr]
    xs.append(hw)
    for i in range(0, len(xs) - 1, 2):                     # piers
        grid_quad(mesh, (xs[i], 0, 0), (xs[i + 1], 0, 0), (xs[i], h, 0),
                  (0, 0, 1), M_WALL, 16, 32)
    rv = 0.22
    for wl, wr, wb, wt in WINDOWS:
        grid_quad(mesh, (wl, 0, 0), (wr, 0, 0), (wl, wb, 0), (0, 0, 1), M_WALL, 8, 4)
        grid_quad(mesh, (wl, wt, 0), (wr, wt, 0), (wl, h, 0), (0, 0, 1), M_WALL, 8, 4)
        # Reveals: the wall has thickness, which is what makes a window
        # read as an opening rather than a sticker.
        grid_quad(mesh, (wl, wb, -rv), (wl, wb, 0), (wl, wt, -rv), (1, 0, 0), M_WALL, 2, 8)
        grid_quad(mesh, (wr, wb, 0), (wr, wb, -rv), (wr, wt, 0), (-1, 0, 0), M_WALL, 2, 8)
        grid_quad(mesh, (wl, wt, 0), (wr, wt, 0), (wl, wt, -rv), (0, -1, 0), M_WALL, 8, 2)
        grid_quad(mesh, (wl, wb, -rv), (wr, wb, -rv), (wl, wb, 0), (0, 1, 0), M_WALL, 8, 2)
        # A frame and one glazing bar.
        for x0, x1 in [(wl, wl + 0.05), (wr - 0.05, wr),
                       ((wl + wr) / 2 - 0.025, (wl + wr) / 2 + 0.025)]:
            box(mesh, (x0, wb, -rv), (x1, wt, -rv + 0.05), M_JOINERY, 2)
        box(mesh, (wl - 0.06, wb - 0.05, -rv - 0.03), (wr + 0.06, wb, 0.05),
            M_JOINERY, 2)

    # Outside: a quad far enough to read as scenery, painted by the shader.
    sd = 60.0
    sw = sd * tan_half * 2.6
    sh = sw / aspect
    grid_quad(mesh, (-sw, HEIGHT / 2 - sh, -sd), (sw, HEIGHT / 2 - sh, -sd),
              (-sw, HEIGHT / 2 + sh, -sd), (0, 0, 1), M_SKY, 1, 1, uv_unit=True)


def box(mesh, lo, hi, mat, n=2):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    grid_quad(mesh, (x0, y1, z0), (x1, y1, z0), (x0, y1, z1), (0, 1, 0), mat, n, n)
    grid_quad(mesh, (x0, y0, z1), (x1, y0, z1), (x0, y0, z0), (0, -1, 0), mat, n, n)
    grid_quad(mesh, (x0, y0, z1), (x0, y1, z1), (x0, y0, z0), (-1, 0, 0), mat, n, n)
    grid_quad(mesh, (x1, y0, z0), (x1, y1, z0), (x1, y0, z1), (1, 0, 0), mat, n, n)
    grid_quad(mesh, (x0, y0, z0), (x1, y0, z0), (x0, y1, z0), (0, 0, -1), mat, n, n)
    grid_quad(mesh, (x1, y0, z1), (x0, y0, z1), (x1, y1, z1), (0, 0, 1), mat, n, n)


# ------------------------------------------------------------ the textures

class Atlas:
    """A fixed grid of 1k tiles. Poly Haven's maps are all 1024², which
    makes packing a lookup rather than a problem."""

    def __init__(self, tile=512, cols=4, rows=4):
        self.tile, self.cols, self.rows = tile, cols, rows
        self.slots = {}
        self.diffuse = Image.new("RGB", (tile * cols, tile * rows), (128, 128, 128))
        self.arm = Image.new("RGB", (tile * cols, tile * rows), (255, 200, 0))

    def slot(self, diff_path, arm_path):
        key = diff_path or arm_path
        if key in self.slots:
            return self.slots[key]
        i = len(self.slots)
        if i >= self.cols * self.rows:
            raise RuntimeError("atlas full — add rows")
        x, y = (i % self.cols) * self.tile, (i // self.cols) * self.tile
        for path, dst in ((diff_path, self.diffuse), (arm_path, self.arm)):
            if path and os.path.exists(path):
                im = Image.open(path).convert("RGB")
                if im.size != (self.tile, self.tile):
                    im = im.resize((self.tile, self.tile), Image.LANCZOS)
                dst.paste(im, (x, y))
        self.slots[key] = i
        return i

    def remap(self, uv, slot):
        """UVs into the tile. Poly Haven furniture is laid out inside the
        unit square, so a wrap is a safe way to handle the strays."""
        c, r = slot % self.cols, slot // self.cols
        u = np.clip(uv[:, 0] % 1.0, 0.001, 0.999)
        v = np.clip(uv[:, 1] % 1.0, 0.001, 0.999)
        return np.stack([(c + u) / self.cols, (r + v) / self.rows], 1)


# --------------------------------------------------------------- the light

class Occupancy:
    """A voxel grid of everything solid, for tracing the bake against. A
    grid beats a proper acceleration structure here: the room is a box,
    the cells are 5 cm, and a march is a handful of array lookups."""

    def __init__(self, tris, cell=0.05):
        self.cell = cell
        self.lo = np.array([-HALF - 0.4, -0.4, -0.4])
        self.hi = np.array([HALF + 0.4, HEIGHT + 0.4, DEPTH + 0.4])
        self.dim = np.ceil((self.hi - self.lo) / cell).astype(int)
        self.grid = np.zeros(self.dim, dtype=bool)
        # Rasterise each triangle's bounding box. Fatter than the
        # triangle, but at 5 cm that is the width of a sofa's seam.
        lo = np.floor((tris.min(axis=1) - self.lo) / cell).astype(int)
        hi = np.ceil((tris.max(axis=1) - self.lo) / cell).astype(int)
        lo = np.clip(lo, 0, self.dim - 1)
        hi = np.clip(hi, 0, self.dim)
        for a, b in zip(lo, hi):
            self.grid[a[0]:b[0], a[1]:b[1], a[2]:b[2]] = True

    def occluded(self, origins, dirs, dist, steps=28):
        """True where the ray hits something within `dist`."""
        hit = np.zeros(len(origins), bool)
        t = np.full(len(origins), self.cell * 2.5)
        step = np.maximum(dist - t, 0) / steps
        for _ in range(steps):
            p = origins + dirs * t[:, None]
            c = np.floor((p - self.lo) / self.cell).astype(int)
            ok = np.all((c >= 0) & (c < self.dim), axis=1)
            cc = np.clip(c, 0, self.dim - 1)
            hit |= ok & self.grid[cc[:, 0], cc[:, 1], cc[:, 2]]
            t = t + step
        return hit


def load_sky(path, out, yaw_deg):
    """Read the sky, turn it to face the room, and get its light out.

    Returns the nine spherical-harmonic coefficients that reproduce how
    this sky lights a surface facing any direction, and the sun's
    direction and colour. Both go into the mesh file, so the shell never
    sees an HDR pixel.
    """
    img = room_hdri.read_hdr(path)
    # Rotate about the vertical by rolling the equirectangular columns —
    # which is all a yaw is in this projection.
    shift = int(round((yaw_deg / 360.0) * img.shape[1])) % img.shape[1]
    img = np.roll(img, shift, axis=1)

    sun_dir, sun_col = room_hdri.find_sun(img)
    # The harmonics are the sky WITHOUT its sun. The sun is added back as
    # a directional light that casts shadows, and leaving it in both
    # places counts it twice — which reads as a room whose ambient is
    # three times too bright and whose shadows therefore have to be
    # crushed to compensate.
    sh = room_hdri.sh9(room_hdri.without_sun(img))
    Image.fromarray(room_hdri.to_gamma(img, max_range=SKY_RANGE)).save(
        os.path.join(out, "room-sky.png"), optimize=True)
    return sh, sun_dir, sun_col


# How much of the sky's range the packed texture keeps. The sun itself is
# thousands of times brighter than the sky around it and no 8-bit
# encoding holds that; what matters is that the sky and the clouds keep
# their relationship and the sun stays the brightest thing in the frame.
SKY_RANGE = 9.0


def bake_light(pos, nrm, occ):
    """Ambient occlusion and daylight, per vertex, against the real room.

    AO is the fraction of a cosine-weighted hemisphere that escapes — the
    thing that puts furniture ON the floor rather than hovering over it.
    Daylight is one ray toward the sun: it has to clear the furniture AND
    leave through a window opening, which is what shapes the patches the
    windows throw and leaves nothing at all behind the sofa.
    """
    n = len(pos)
    eps = nrm * 0.02
    origin = pos + eps

    # --- ambient occlusion -------------------------------------------
    rng = np.random.default_rng(7)
    # Enough rays that the result is smooth. Fourteen looked fine on a
    # graph and looked like dirt on a wall: ambient occlusion baked per
    # vertex shows its noise as blotches the size of the mesh's cells.
    rays = 64
    open_frac = np.zeros(n)
    for k in range(rays):
        # Cosine-weighted about the normal, via a random tangent frame.
        u1, u2 = rng.random(n), rng.random(n)
        r, th = np.sqrt(u1), 2 * np.pi * u2
        local = np.stack([r * np.cos(th), r * np.sin(th), np.sqrt(1 - u1)], 1)
        helper = np.tile(np.array([0.0, 0.0, 1.0]), (n, 1))
        flip = np.abs(nrm[:, 2]) > 0.9
        helper[flip] = np.array([1.0, 0.0, 0.0])
        t1 = np.cross(helper, nrm)
        t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-9)
        t2 = np.cross(nrm, t1)
        d = (t1 * local[:, 0:1] + t2 * local[:, 1:2] + nrm * local[:, 2:3])
        open_frac += ~occ.occluded(origin, d, np.full(n, 1.6))
    ao = open_frac / rays
    # Never black: a room is full of light that has bounced more than once,
    # and an AO of zero in a corner reads as a hole rather than a corner.
    ao = 0.28 + 0.72 * ao

    # --- daylight ------------------------------------------------------
    facing = nrm @ SUN
    sun = np.clip(facing, 0, None)
    # Where does the ray leave the window plane?
    with np.errstate(divide="ignore", invalid="ignore"):
        k = pos[:, 2] / (-SUN[2])
    hx = pos[:, 0] + SUN[0] * k
    hy = pos[:, 1] + SUN[1] * k
    soft = 0.19
    through = np.zeros(n)
    for wl, wr, wb, wt in WINDOWS:
        band = (np.clip((hx - wl) / soft, 0, 1) * np.clip((wr - hx) / soft, 0, 1)
                * np.clip((hy - wb) / soft, 0, 1) * np.clip((wt - hy) / soft, 0, 1))
        through = np.maximum(through, band)
    sun *= through * (k > 0.02)
    live = sun > 0.002
    if live.any():
        d = np.tile(SUN, (int(live.sum()), 1))
        blocked = occ.occluded(pos[live] + eps[live], d, k[live], steps=40)
        s = sun[live]
        s[blocked] = 0.0
        sun[live] = s
    return ao, sun


def place_furniture(mesh, atlas, assets_dir):
    tris_for_occ = []
    for name, x, z, deg, y, sc in PLACEMENT:
        found = glob.glob(os.path.join(assets_dir, name, "*.gltf"))
        if not found:
            print(f"  missing {name}, skipped", file=sys.stderr)
            continue
        g = Gltf(found[0])
        a = np.radians(deg)
        rot = np.array([[np.cos(a), 0, np.sin(a)],
                        [0, 1, 0],
                        [-np.sin(a), 0, np.cos(a)]]) * sc
        for pos, nrm, uv, idx, mat in g.primitives():
            diff, arm = g.material_maps(mat)
            slot = atlas.slot(diff, arm)
            P = (rot @ pos.T).T + np.array([x, y, z])
            N = (rot @ nrm.T).T
            mesh.add(P, N, atlas.remap(uv, slot), M_ATLAS, idx)
            tris_for_occ.append(P[idx].reshape(-1, 3, 3))
    return tris_for_occ


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", default=os.path.expanduser("~/tmp/room-assets"))
    ap.add_argument("--out", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..",
        "shell", "Resources", "Room"))
    ap.add_argument("--aspect", type=float, default=1.6)
    ap.add_argument("--fov", type=float, default=70.0)
    ap.add_argument("--hdri", default=os.path.expanduser("~/tmp/hdri-meadow_2.hdr"),
                    help="the sky the room is lit by and looks out on")
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)

    global SUN
    sh, sun_dir, sun_col = load_sky(a.hdri, out, SKY_YAW)
    SUN = sun_dir
    print(f"  sky: sun {np.round(sun_dir, 3)} "
          f"({np.degrees(np.arcsin(sun_dir[1])):.0f}deg up), "
          f"colour {np.round(sun_col, 2)}, sh0 {np.round(sh[0], 3)}")
    if sun_dir[2] > -0.05:
        print("  ! the sun is not on the window side; turn SKY_YAW",
              file=sys.stderr)

    mesh, atlas = Mesh(), Atlas()
    tan_half = np.tan(np.radians(a.fov) / 2)
    build_shell(mesh, a.aspect, tan_half)
    shell_verts = mesh.n
    furniture_tris = place_furniture(mesh, atlas, a.assets)

    pos, nrm, uv, mat, idx = mesh.finish()
    print(f"  {mesh.n} vertices, {len(idx)//3} triangles "
          f"({shell_verts} shell, {mesh.n - shell_verts} furniture)")

    # Everything solid, for the bake to trace against: the furniture and
    # the room's own surfaces, but NOT the sky quad, which is scenery.
    solid = mat != M_SKY
    solid_idx = idx.reshape(-1, 3)
    keep = solid[solid_idx].all(axis=1)
    occ = Occupancy(pos[solid_idx[keep]])
    print(f"  occupancy grid {tuple(occ.dim)}, {occ.grid.sum()/1e3:.0f}k solid cells")

    ao, sun = bake_light(pos, nrm, occ)
    # The sky is not lit by the room.
    sky = mat == M_SKY
    ao[sky], sun[sky] = 1.0, 0.0
    print(f"  light baked: ao {ao.min():.2f}-{ao.max():.2f}, "
          f"{(sun > 0.01).sum()/len(sun)*100:.0f}% of vertices see daylight")

    verts = np.concatenate([pos, nrm, uv, ao[:, None], sun[:, None],
                            mat[:, None]], axis=1).astype(np.float32)
    with open(os.path.join(out, "room.mesh"), "wb") as f:
        f.write(b"STARROOM")
        # Version 2 carries the sky's light after the header: nine SH
        # coefficients, then the sun's direction and colour.
        f.write(struct.pack("<IIII", 2, len(verts), len(idx), 11))
        f.write(np.asarray(sh, np.float32).tobytes())
        f.write(np.asarray(sun_dir, np.float32).tobytes())
        f.write(np.asarray(sun_col, np.float32).tobytes())
        f.write(struct.pack("<f", SKY_RANGE))
        f.write(verts.tobytes())
        f.write(idx.astype(np.uint32).tobytes())
    atlas.diffuse.save(os.path.join(out, "room-diffuse.png"), optimize=True)
    atlas.arm.save(os.path.join(out, "room-arm.png"), optimize=True)
    for n2 in ("room.mesh", "room-diffuse.png", "room-arm.png", "room-sky.png"):
        print(f"  {n2:20s} {os.path.getsize(os.path.join(out, n2))/1e6:6.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
