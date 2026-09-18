#!/usr/bin/env python3
"""Export the 3D desktop's room as a glTF binary, for Filament.

    room-glb.py [--assets <dir>] [--out <dir>] [--hdri <file>]

Same room as room-import.py — the same generated shell (floor, walls,
ceiling, the wall of windows) and the same CC0 furniture in the same
places — but as an ordinary glTF the Filament renderer loads directly,
with the furniture's own textures (base colour, ARM, normal map) instead
of an atlas, and NO baked light: Filament lights it live from the sky.

Also writes the sky the renderer wants, as two Radiance files for cmgen:
    sky-full.hdr     the sky as it is, for the view out of the windows
    sky-nosun.hdr    the sky with its sun removed, for the ambient light
                     (the sun is a separate light that casts shadows, and
                     leaving it in the ambient counts it twice)
and room.json, with the sun's direction and colour in the room's world.

Outputs:
    room.glb, sky-full.hdr, sky-nosun.hdr, room.json
"""
import argparse
import glob
import importlib.util
import json
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from room_gltf import Gltf  # noqa: E402
import room_hdri  # noqa: E402


def load_importer():
    """room-import.py has a hyphen in its name; import it by path."""
    spec = importlib.util.spec_from_file_location(
        "room_import", os.path.join(HERE, "room-import.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# ------------------------------------------------------------------ GLB

class Glb:
    """A minimal glTF 2.0 binary writer: one buffer, embedded images."""

    def __init__(self):
        self.bin = bytearray()
        self.j = {
            "asset": {"version": "2.0", "generator": "starling room-glb.py"},
            "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
            "materials": [], "textures": [], "images": [],
            "samplers": [{"magFilter": 9729, "minFilter": 9987,
                          "wrapS": 10497, "wrapT": 10497}],
            "accessors": [], "bufferViews": [], "buffers": [],
        }
        self.image_cache = {}

    def view(self, data: bytes, target=None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            bv["target"] = target
        self.j["bufferViews"].append(bv)
        return len(self.j["bufferViews"]) - 1

    def accessor(self, arr, ctype, atype, target, minmax=False) -> int:
        arr = np.ascontiguousarray(arr)
        bv = self.view(arr.tobytes(), target)
        acc = {"bufferView": bv, "componentType": ctype,
               "count": int(arr.shape[0]), "type": atype}
        if minmax:
            acc["min"] = [float(x) for x in arr.min(axis=0)]
            acc["max"] = [float(x) for x in arr.max(axis=0)]
        self.j["accessors"].append(acc)
        return len(self.j["accessors"]) - 1

    def texture(self, path) -> int:
        if path in self.image_cache:
            return self.image_cache[path]
        with open(path, "rb") as f:
            data = f.read()
        mime = ("image/jpeg" if path.lower().endswith((".jpg", ".jpeg"))
                else "image/png")
        bv = self.view(data)
        self.j["images"].append({"bufferView": bv, "mimeType": mime,
                                 "name": os.path.basename(path)})
        self.j["textures"].append({"sampler": 0,
                                   "source": len(self.j["images"]) - 1})
        t = len(self.j["textures"]) - 1
        self.image_cache[path] = t
        return t

    def material(self, m) -> int:
        self.j["materials"].append(m)
        return len(self.j["materials"]) - 1

    def primitive(self, pos, nrm, uv, idx, material):
        attrs = {
            "POSITION": self.accessor(pos.astype(np.float32), 5126, "VEC3", 34962, True),
            "NORMAL": self.accessor(nrm.astype(np.float32), 5126, "VEC3", 34962),
        }
        if uv is not None:
            attrs["TEXCOORD_0"] = self.accessor(uv.astype(np.float32), 5126, "VEC2", 34962)
        return {"attributes": attrs,
                "indices": self.accessor(idx.astype(np.uint32), 5125, "SCALAR", 34963),
                "material": material, "mode": 4}

    def mesh(self, prims, name) -> int:
        self.j["meshes"].append({"primitives": prims, "name": name})
        return len(self.j["meshes"]) - 1

    def node(self, mesh, name, translation=None, rotation=None, scale=None) -> int:
        n = {"mesh": mesh, "name": name}
        if translation is not None:
            n["translation"] = [float(x) for x in translation]
        if rotation is not None:
            n["rotation"] = [float(x) for x in rotation]
        if scale is not None:
            n["scale"] = [float(x) for x in scale]
        self.j["nodes"].append(n)
        i = len(self.j["nodes"]) - 1
        self.j["scenes"][0]["nodes"].append(i)
        return i

    def write(self, path):
        self.j["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(self.j, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        while len(self.bin) % 4:
            self.bin.append(0)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


# ---------------------------------------------------------------- the room

# What the shell's surfaces are made of, until they get real textures:
# (base colour, roughness). The floor is the oak the shader paints.
SHELL_MATERIALS = {
    "floor":   ((0.47, 0.335, 0.205), 0.55),
    "wall":    ((0.80, 0.77, 0.72), 0.90),
    "ceiling": ((0.93, 0.93, 0.91), 0.95),
    "joinery": ((0.95, 0.95, 0.93), 0.35),
}
# The Poly Haven texture set for each, with its tile size in metres
# (room-fetch.py downloads them). The shell's texture coordinates are in
# metres, so the tile size is a division. Missing files: flat colour.
# (texture id, tile size in metres, brightening). Poly Haven's "white"
# plaster photographs mid-grey (sRGB 142, linear 0.27) and its occlusion
# map takes another third off; a painted room wall is nearer 0.6.
SHELL_TEXTURES = {
    "floor":   ("wood_floor", 2.4, 1.15),
    "wall":    ("white_plaster_02", 3.0, 1.7),
    "ceiling": ("white_plaster_02", 3.0, 1.7),
}


def brightened(path, factor, out_dir):
    """The diffuse map scaled in linear light, re-encoded beside the export."""
    if abs(factor - 1.0) < 1e-3:
        return path
    from PIL import Image
    out = os.path.join(out_dir, f"{os.path.splitext(os.path.basename(path))[0]}_x{factor:.2f}.jpg")
    if not os.path.exists(out):
        img = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
        lin = np.power(img, 2.2) * factor
        srgb = np.power(np.clip(lin, 0, 1), 1 / 2.2) * 255.0
        Image.fromarray(srgb.astype(np.uint8)).save(out, quality=92)
    return out


def shell_texture_material(glb, name, textures_dir):
    """The textured version of a shell material, or None without files."""
    if name not in SHELL_TEXTURES:
        return None
    tid, _, factor = SHELL_TEXTURES[name]
    d = os.path.join(textures_dir, tid)
    maps = {}
    for key, suffix in (("diff", "_diff_"), ("arm", "_arm_"), ("nor", "_nor_gl_")):
        found = glob.glob(os.path.join(d, f"{tid}{suffix}*.jpg"))
        if found:
            path = brightened(found[0], factor, textures_dir) if key == "diff" else found[0]
            maps[key] = glb.texture(path)
    if "diff" not in maps:
        return None
    m = {"name": name,
         "pbrMetallicRoughness": {"baseColorTexture": {"index": maps["diff"]},
                                  "metallicFactor": 0.0, "roughnessFactor": 1.0}}
    if "arm" in maps:
        m["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": maps["arm"]}
        m["pbrMetallicRoughness"]["metallicFactor"] = 1.0
        # A tiled map's occlusion is fine grain, not the room's; keep it light.
        m["occlusionTexture"] = {"index": maps["arm"], "strength": 0.5}
    if "nor" in maps:
        m["normalTexture"] = {"index": maps["nor"]}
    return glb.material(m)


def export_shell(glb, ri, aspect, fov, textures_dir):
    mesh = ri.Mesh()
    ri.build_shell(mesh, aspect, np.tan(np.radians(fov) / 2))
    pos, nrm, uv, mat, idx = mesh.finish()
    tris = idx.reshape(-1, 3)
    prims = []
    for name, mid in (("floor", ri.M_FLOOR), ("wall", ri.M_WALL),
                      ("ceiling", ri.M_CEIL), ("joinery", ri.M_JOINERY)):
        keep = mat[tris[:, 0]] == mid
        if not keep.any():
            continue
        used = np.unique(tris[keep])
        remap = np.full(len(pos), -1, np.int64)
        remap[used] = np.arange(len(used))
        colour, rough = SHELL_MATERIALS[name]
        m = shell_texture_material(glb, name, textures_dir)
        # Texture coordinates are metres; tile them.
        uv_scale = 1.0 / SHELL_TEXTURES[name][1] if m is not None else 1.0
        # The generated quads were never culled by the old renderer, so
        # their winding is arbitrary; Filament culls back faces. Turn any
        # triangle whose winding disagrees with its vertex normal.
        t = tris[keep].copy()
        e1 = pos[t[:, 1]] - pos[t[:, 0]]
        e2 = pos[t[:, 2]] - pos[t[:, 0]]
        facing = (np.cross(e1, e2) * nrm[t[:, 0]]).sum(axis=1)
        flip = facing < 0
        t[flip, 1], t[flip, 2] = t[flip, 2], t[flip, 1]
        if m is None:
            m = glb.material({
                "name": name,
                "pbrMetallicRoughness": {
                    "baseColorFactor": [*colour, 1.0],
                    "metallicFactor": 0.0, "roughnessFactor": rough},
            })
        prims.append(glb.primitive(pos[used], nrm[used], uv[used] * uv_scale,
                                   remap[t].ravel(), m))
    glb.node(glb.mesh(prims, "shell"), "shell")
    return len(pos), len(tris)


def furniture_material(glb, g, mat_index, cache):
    key = (id(g), mat_index)
    if key in cache:
        return cache[key]
    src = g.g["materials"][mat_index]
    pbr = src.get("pbrMetallicRoughness", {})

    def tex(ref):
        if not ref:
            return None
        img = g.g["images"][g.g["textures"][ref["index"]]["source"]]
        return glb.texture(os.path.join(g.dir, img["uri"]))

    m = {"name": src.get("name", "furniture"),
         "doubleSided": bool(src.get("doubleSided", False)),
         "pbrMetallicRoughness": {"metallicFactor": 1.0, "roughnessFactor": 1.0}}
    diff = tex(pbr.get("baseColorTexture"))
    arm = tex(pbr.get("metallicRoughnessTexture"))
    nor = tex(src.get("normalTexture"))
    if diff is not None:
        m["pbrMetallicRoughness"]["baseColorTexture"] = {"index": diff}
    if arm is not None:
        # Poly Haven's ARM map is glTF's packing exactly: occlusion in R,
        # roughness in G, metalness in B — one texture, two slots.
        m["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": arm}
        m["occlusionTexture"] = {"index": arm}
    else:
        m["pbrMetallicRoughness"]["metallicFactor"] = 0.0
        m["pbrMetallicRoughness"]["roughnessFactor"] = 0.7
    if nor is not None:
        m["normalTexture"] = {"index": nor}
    cache[key] = glb.material(m)
    return cache[key]


# The room as Filament shows it differs from the bake in one placement:
# the big plant stands in front of the right wall's first pane slot, so a
# window hung there is partly behind it — the occlusion a real scene
# gives for nothing, on show. The bake keeps its arrangement (it does not
# hang windows) until it is retired.
PLACEMENT_OVERRIDES = {
    # (x, z, scale): a floor plant taller than eye level, or from the door
    # its top projects below the pane's bottom edge and nothing overlaps.
    ("potted_plant_04", 3.25, 8.35): (3.3, 2.5, 5.5),
}


def export_furniture(glb, ri, assets_dir):
    meshes, gltfs, mats = {}, {}, {}
    verts = tris = 0
    for name, x, z, deg, y, sc in ri.PLACEMENT:
        x, z, sc = PLACEMENT_OVERRIDES.get((name, x, z), (x, z, sc))
        if name not in meshes:
            found = glob.glob(os.path.join(assets_dir, name, "*.gltf"))
            if not found:
                print(f"  missing {name}, skipped", file=sys.stderr)
                meshes[name] = None
                continue
            g = Gltf(found[0])
            gltfs[name] = g
            prims = []
            for pos, nrm, uv, idx, mat in g.primitives():
                prims.append(glb.primitive(pos, nrm, uv, idx,
                                           furniture_material(glb, g, mat, mats)))
                verts += len(pos)
                tris += len(idx) // 3
            meshes[name] = glb.mesh(prims, name)
        if meshes[name] is None:
            continue
        a = np.radians(deg) / 2
        glb.node(meshes[name], f"{name}@{x},{z}",
                 translation=(x, y, z),
                 rotation=(0.0, np.sin(a), 0.0, np.cos(a)),   # about +Y
                 scale=(sc, sc, sc))
    return verts, tris


# ------------------------------------------------------------------ the sky

def write_hdr(path, img):
    """A flat (unencoded) Radiance RGBE file."""
    h, w, _ = img.shape
    m = img.max(axis=2)
    f, e = np.frexp(m)
    live = m > 1e-32
    scale = np.where(live, f * 256.0 / np.maximum(m, 1e-32), 0.0)
    rgbe = np.zeros((h, w, 4), np.uint8)
    rgbe[..., :3] = np.clip(img * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(live, e + 128, 0).astype(np.uint8)
    # A scanline starting 2,2 would be read as a run-length header.
    first = rgbe[:, 0, :]
    both = (first[:, 0] == 2) & (first[:, 1] == 2)
    rgbe[both, 0, 0] = 3
    with open(path, "wb") as fo:
        fo.write(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n")
        fo.write(f"-Y {h} +X {w}\n".encode())
        fo.write(rgbe.tobytes())


def export_sky(out, hdri, yaw_deg):
    img = room_hdri.read_hdr(hdri)
    shift = int(round((yaw_deg / 360.0) * img.shape[1])) % img.shape[1]
    img = np.roll(img, shift, axis=1)
    sun_dir, sun_col = room_hdri.find_sun(img)
    # cmgen reads an equirectangular column u as the direction
    # (sin, ., +cos) where room_hdri reads it as (sin, ., -cos): the two
    # conventions are mirror images. Mirror the columns and turn them
    # half a circle, and cmgen puts every pixel of sky in the direction
    # the sun above was found in — so the sun light and the sun in the
    # skybox agree without a second convention anywhere.
    img = np.roll(img[:, ::-1], img.shape[1] // 2, axis=1)
    write_hdr(os.path.join(out, "sky-full.hdr"), img)

    # The LIGHT is not the whole sky. Filament lights every surface from
    # the whole sphere, so a ceiling would take the meadow's green from
    # below and the walls the sky's blue from all sides. In a room the
    # lower half of what any surface sees is the FLOOR: paint the ground
    # half of the light with the floor's colour times what falls on it —
    # the sky's mean radiance, and the sun's share that lands on the
    # floor. (The view through the windows keeps the real meadow.)
    light = room_hdri.without_sun(img)
    h = light.shape[0]
    upper = light[: h // 2].mean(axis=(0, 1))
    floor = np.array(SHELL_MATERIALS["floor"][0])
    bounce = floor * (upper + 0.3 * np.asarray(sun_col) * max(sun_dir[1], 0.0) / np.pi)
    v = (np.arange(h) + 0.5) / h
    blend = np.clip((v - 0.48) / 0.06, 0, 1)[:, None, None]      # soft horizon
    light = light * (1 - blend) + bounce[None, None, :] * blend
    write_hdr(os.path.join(out, "sky-nosun.hdr"), light.astype(np.float32))
    return sun_dir, sun_col


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", default=os.path.expanduser("~/tmp/room-assets"))
    ap.add_argument("--out", default=os.path.expanduser("~/tmp/filament/room"))
    ap.add_argument("--hdri", default=os.path.expanduser("~/tmp/hdri-meadow_2.hdr"))
    ap.add_argument("--aspect", type=float, default=1.6)
    ap.add_argument("--fov", type=float, default=70.0)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ri = load_importer()

    glb = Glb()
    sv, st = export_shell(glb, ri, a.aspect, a.fov, os.path.join(a.assets, "textures"))
    fv, ft = export_furniture(glb, ri, a.assets)
    glb.write(os.path.join(a.out, "room.glb"))
    print(f"  shell {sv} vertices / {st} triangles, furniture {fv} / {ft}")

    sun_dir, sun_col = export_sky(a.out, a.hdri, ri.SKY_YAW)
    with open(os.path.join(a.out, "room.json"), "w") as f:
        json.dump({
            "sun_dir": [float(x) for x in sun_dir],
            "sun_colour": [float(x) for x in sun_col],
            "sky_yaw": ri.SKY_YAW,
            "room": {"width": ri.WIDTH, "height": ri.HEIGHT, "depth": ri.DEPTH},
        }, f, indent=1)
    print(f"  sun {np.round(sun_dir, 3)} colour {np.round(sun_col, 2)}")
    for n in ("room.glb", "sky-full.hdr", "sky-nosun.hdr", "room.json"):
        print(f"  {n:16s} {os.path.getsize(os.path.join(a.out, n))/1e6:6.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
