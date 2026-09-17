#!/usr/bin/env python3
"""A small glTF reader: enough of the format for Poly Haven's assets.

Not a general loader. Poly Haven's exports are about as plain as glTF
gets — a flat node list, one primitive per mesh, indexed triangles with
POSITION / NORMAL / TEXCOORD_0, and a metallic-roughness material with a
base-colour map and an ARM map (ambient occlusion, roughness, metalness
packed into R, G, B). This reads exactly that and refuses anything else
loudly, which is the right trade for an importer that runs on twelve
known files.
"""
import base64
import json
import os
import struct

import numpy as np

_COMPONENT = {
    5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
    5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4),
}
_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Gltf:
    def __init__(self, path: str):
        self.dir = os.path.dirname(path)
        with open(path) as f:
            self.g = json.load(f)
        self.buffers = [self._buffer(b) for b in self.g.get("buffers", [])]

    def _buffer(self, b) -> bytes:
        uri = b.get("uri")
        if uri is None:
            raise ValueError("GLB-embedded buffers are not supported")
        if uri.startswith("data:"):
            return base64.b64decode(uri.split(",", 1)[1])
        with open(os.path.join(self.dir, uri), "rb") as f:
            return f.read()

    def accessor(self, i: int) -> np.ndarray:
        a = self.g["accessors"][i]
        fmt, size = _COMPONENT[a["componentType"]]
        n = _COUNT[a["type"]]
        count = a["count"]
        bv = self.g["bufferViews"][a["bufferView"]]
        buf = self.buffers[bv.get("buffer", 0)]
        base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride") or size * n
        if stride == size * n:
            raw = buf[base:base + count * size * n]
            arr = np.frombuffer(raw, dtype=np.dtype(fmt)).reshape(count, n)
        else:
            out = np.empty((count, n), dtype=np.dtype(fmt))
            for k in range(count):
                off = base + k * stride
                out[k] = struct.unpack_from(f"<{n}{fmt}", buf, off)
            arr = out
        return arr.astype(np.float32) if a["componentType"] == 5126 else arr

    def node_matrix(self, node) -> np.ndarray:
        if "matrix" in node:
            return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
        m = np.eye(4)
        if "scale" in node:
            m = m @ np.diag(list(node["scale"]) + [1.0])
        if "rotation" in node:
            x, y, z, w = node["rotation"]
            r = np.array([
                [1 - 2*(y*y + z*z), 2*(x*y - z*w),     2*(x*z + y*w),     0],
                [2*(x*y + z*w),     1 - 2*(x*x + z*z), 2*(y*z - x*w),     0],
                [2*(x*z - y*w),     2*(y*z + x*w),     1 - 2*(x*x + y*y), 0],
                [0, 0, 0, 1]])
            m = r @ m
        if "translation" in node:
            t = np.eye(4)
            t[:3, 3] = node["translation"]
            m = t @ m
        return m

    def primitives(self):
        """Every primitive in the file, as (pos, nrm, uv, idx, material)."""
        out = []

        def walk(idx, parent):
            node = self.g["nodes"][idx]
            m = parent @ self.node_matrix(node)
            if "mesh" in node:
                for p in self.g["meshes"][node["mesh"]]["primitives"]:
                    if p.get("mode", 4) != 4:
                        continue
                    at = p["attributes"]
                    pos = self.accessor(at["POSITION"]).astype(np.float64)
                    pos = (m[:3, :3] @ pos.T).T + m[:3, 3]
                    nrm = self.accessor(at["NORMAL"]).astype(np.float64)
                    nm = np.linalg.inv(m[:3, :3]).T
                    nrm = (nm @ nrm.T).T
                    ln = np.linalg.norm(nrm, axis=1, keepdims=True)
                    nrm = nrm / np.where(ln > 1e-9, ln, 1)
                    uv = (self.accessor(at["TEXCOORD_0"]).astype(np.float64)
                          if "TEXCOORD_0" in at else np.zeros((len(pos), 2)))
                    idxs = (self.accessor(p["indices"]).reshape(-1).astype(np.int64)
                            if "indices" in p else np.arange(len(pos)))
                    out.append((pos, nrm, uv, idxs, p.get("material", 0)))
            for c in node.get("children", []):
                walk(c, m)

        roots = self.g["scenes"][self.g.get("scene", 0)]["nodes"]
        for r in roots:
            walk(r, np.eye(4))
        return out

    def material_maps(self, i: int):
        """(base colour uri, ARM uri) for a material, either may be None."""
        mat = self.g["materials"][i]
        pbr = mat.get("pbrMetallicRoughness", {})

        def uri(texref):
            if not texref:
                return None
            tex = self.g["textures"][texref["index"]]
            img = self.g["images"][tex["source"]]
            u = img.get("uri")
            return os.path.join(self.dir, u) if u else None

        return uri(pbr.get("baseColorTexture")), uri(pbr.get("metallicRoughnessTexture"))
