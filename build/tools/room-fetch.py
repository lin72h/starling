#!/usr/bin/env python3
"""Fetch the 3D desktop room's furnishings from Poly Haven.

    room-fetch.py [--out <dir>] [--res 1k]

The 3D desktop stands in a modelled room (docs/plans/desktop-3d.md). Its
shell — floor, walls, ceiling, windows — is generated, but its FURNITURE
is not: hand-modelling a sofa out of axis-aligned boxes reads as
polystyrene however well it is lit, because a silhouette is the first
thing anyone sees and a box has the wrong one.

So the furniture comes from Poly Haven, whose entire library is CC0:
usable for any purpose including commercial, with no attribution
required (https://polyhaven.com/license — checked 2026-09-17). They are
credited anyway, in the room's README.

This downloads the source assets. `room-import.py` turns them into the
single binary the shell loads. Neither runs on a user's machine, and
neither is a build dependency: the imported room is checked in.
"""
import argparse
import json
import os
import sys
import urllib.request

API = "https://api.polyhaven.com"
# The API 403s a bare urllib request; it wants something that looks like a
# client rather than an anonymous library default.
UA = {"User-Agent": "starling-room-fetch/1.0 (+https://github.com/starling)"}

# What the room is furnished with, and why each one is here. Poly Haven
# ids; every one of them is CC0.
ASSETS = [
    "Sofa_01",                  # the long sofa facing the windows
    "ArmChair_01",              # a pair, turned in toward the middle
    "modern_coffee_table_02",   # low table on the rug
    "side_table_01",            # beside the sofa
    "ClassicConsole_01",        # against the long wall
    "potted_plant_01",          # the corner
    "potted_plant_04",          # by the windows
    "book_encyclopedia_set_01", # on the console
    "ceramic_vase_02",          # on the console
    "brass_vase_01",            # on the coffee table
    "modern_ceiling_lamp_01",   # over the seating
    "hanging_picture_frame_02", # the wallpaper hangs in this
]


# Surfaces for the room's own shell — floor, walls, ceiling — which the
# glTF export (room-glb.py) textures; the baked mesh paints them
# procedurally and does not use these. Also CC0.
TEXTURES = [
    "wood_floor",           # the floor: oak boards
    "white_plaster_02",     # walls and ceiling
]
TEXTURE_MAPS = ["Diffuse", "arm", "nor_gl"]


def fetch(url: str, path: str) -> int:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        return os.path.getsize(path)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        data = r.read()
        f.write(data)
    return len(data)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.expanduser("~/tmp/room-assets"))
    ap.add_argument("--res", default="1k",
                    help="texture resolution; 1k is plenty for furniture "
                         "seen across a room and keeps the package small")
    a = ap.parse_args()

    total = 0
    for tid in TEXTURES:
        try:
            req = urllib.request.Request(f"{API}/files/{tid}", headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                files = json.load(r)
        except Exception as e:
            print(f"{tid}: {e}", file=sys.stderr)
            return 1
        for m in TEXTURE_MAPS:
            node = files.get(m, {}).get(a.res, {}).get("jpg")
            if not node:
                print(f"{tid}: no {a.res} {m}", file=sys.stderr)
                continue
            url = node["url"]
            path = os.path.join(a.out, "textures", tid, os.path.basename(url))
            n = fetch(url, path)
            total += n
            print(f"  {tid:22s} {m:8s} {n/1e6:5.2f} MB")
    for aid in ASSETS:
        try:
            req = urllib.request.Request(f"{API}/files/{aid}", headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                files = json.load(r)
        except Exception as e:
            print(f"{aid}: {e}", file=sys.stderr)
            return 1
        node = files.get("gltf", {}).get(a.res, {}).get("gltf")
        if not node:
            print(f"{aid}: no {a.res} glTF", file=sys.stderr)
            return 1
        base = os.path.join(a.out, aid)
        n = fetch(node["url"], os.path.join(base, os.path.basename(node["url"])))
        for rel, info in (node.get("include") or {}).items():
            n += fetch(info["url"], os.path.join(base, rel))
        total += n
        print(f"{aid:28s} {n/1e6:6.2f} MB")
    print(f"{'total':28s} {total/1e6:6.2f} MB  -> {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
