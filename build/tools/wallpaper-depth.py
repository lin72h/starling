#!/usr/bin/env python3
"""Write a depth map beside a wallpaper, for the 3D desktop's relief.

    wallpaper-depth.py <image> [-o <out.png>] [--model <dav2.onnx>] [--preview]

The 3D desktop's room is built out of the wallpaper (docs/plans/desktop-3d.md).
Tier 0 hangs the picture flat on the far wall; tier 1 gives that wall a
RELIEF, so the bridge towers stand in front of the sky and a window pushed
far enough back can go behind them. The relief comes from this file: an
8-bit grayscale PNG the same aspect as the picture, WHITE NEAREST, black
farthest, which the shell reads next to the image as `<name>.depth.png`.

Runs a monocular depth model (Depth Anything V2 Small, ONNX, CPU —
a few seconds for one image). This never runs inside the shell and is not
a dependency of the desktop: the bundled wallpapers' maps are generated
here and checked in, and a user's own wallpaper simply gets tier 0 if the
helper and its model are not installed.

Setup, on a machine that needs it:

    python3 -m venv ~/.cache/starling-depth
    ~/.cache/starling-depth/bin/pip install onnxruntime pillow numpy
    curl -L -o ~/.cache/starling-depth/dav2-small.onnx \\
      https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/main/onnx/model.onnx

then run this with that venv's python.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

DEFAULT_MODEL = os.path.expanduser("~/.cache/starling-depth/dav2-small.onnx")
# The model is a ViT with a patch size of 14 and was trained at 518.
INFER = 518
# ImageNet normalisation, which is what the model was trained with.
MEAN = np.array([0.485, 0.456, 0.406], np.float32)
STD = np.array([0.229, 0.224, 0.225], np.float32)


def infer(path: str, model: str) -> np.ndarray:
    """Relative inverse depth for one image, 0..1 with 1 NEAREST."""
    import onnxruntime as ort

    im = Image.open(path).convert("RGB")
    # Square-ish at the training size; the map is resized back at the end,
    # so the only thing the aspect change costs is a little accuracy.
    small = im.resize((INFER, INFER), Image.BICUBIC)
    x = (np.asarray(small, np.float32) / 255.0 - MEAN) / STD
    x = np.transpose(x, (2, 0, 1))[None]

    sess = ort.InferenceSession(model, providers=["CPUExecutionProvider"])
    out = sess.run(None, {sess.get_inputs()[0].name: x})[0]
    d = np.squeeze(out).astype(np.float32)
    # The model emits relative INVERSE depth: bigger is nearer. Normalise
    # per image — it has no absolute scale, and the shell only ever uses
    # the relief's shape, never its units.
    lo, hi = float(d.min()), float(d.max())
    d = (d - lo) / (hi - lo) if hi > lo else np.zeros_like(d)
    return np.asarray(
        Image.fromarray((d * 255).astype(np.uint8)).resize(im.size, Image.BICUBIC),
        np.float32,
    ) / 255.0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("-o", "--out", help="default: <image without extension>.depth.png")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--preview", action="store_true",
                    help="also write <out>.preview.png: the picture beside its relief")
    a = ap.parse_args()

    if not os.path.exists(a.model):
        print(f"no model at {a.model} — see this file's header for the two "
              f"commands that fetch it", file=sys.stderr)
        return 2
    out = a.out or os.path.splitext(a.image)[0] + ".depth.png"
    d = infer(a.image, a.model)
    Image.fromarray((d * 255).astype(np.uint8), "L").save(out, optimize=True)
    print(f"{out}  {d.shape[1]}x{d.shape[0]}  "
          f"{os.path.getsize(out) / 1024:.0f} KB")

    if a.preview:
        src = Image.open(a.image).convert("RGB")
        w = 640
        h = int(w * src.height / src.width)
        sheet = Image.new("RGB", (w, h * 2))
        sheet.paste(src.resize((w, h), Image.LANCZOS), (0, 0))
        sheet.paste(Image.fromarray((d * 255).astype(np.uint8), "L")
                    .resize((w, h), Image.LANCZOS).convert("RGB"), (0, h))
        p = os.path.splitext(out)[0] + ".preview.png"
        sheet.save(p)
        print(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
