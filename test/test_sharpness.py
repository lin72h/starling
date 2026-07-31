#!/usr/bin/env python3
"""Measure text sharpness from DRM screenshots.

Usage:
    python3 test_sharpness.py /tmp/screenshot.png [crop_region]
    python3 test_sharpness.py /tmp/a.png /tmp/b.png   # compare two

Crop region: WxH+X+Y (e.g. 300x50+160+60)

Metrics:
  - Laplacian variance: higher = sharper (blurry < 100, sharp > 300)
  - Edge gradient mean: higher = crisper edges
  - High-freq energy: ratio of high-frequency content
"""

import sys
import subprocess
import struct
import math
import os

def load_png_as_gray(path, crop=None):
    """Load PNG, optionally crop, convert to grayscale numpy-free."""
    if crop:
        tmp = "/tmp/_sharpness_crop.ppm"
        subprocess.run(["convert", path, "-crop", crop, "+repage",
                       "-colorspace", "Gray", "-depth", "8",
                       f"pgm:{tmp}"], check=True)
        path = tmp
    else:
        tmp = "/tmp/_sharpness_gray.ppm"
        subprocess.run(["convert", path, "-colorspace", "Gray", "-depth", "8",
                       f"pgm:{tmp}"], check=True)
        path = tmp

    with open(path, "rb") as f:
        # Read PGM (P5)
        magic = f.readline().strip()
        assert magic == b"P5", f"Expected P5, got {magic}"
        # Skip comments
        line = f.readline()
        while line.startswith(b"#"):
            line = f.readline()
        w, h = map(int, line.split())
        maxval = int(f.readline().strip())
        data = f.read(w * h)

    pixels = list(data)
    return pixels, w, h


def laplacian_variance(pixels, w, h):
    """Variance of the Laplacian (sharpness metric)."""
    lap = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            # 3x3 Laplacian kernel: [0,1,0; 1,-4,1; 0,1,0]
            val = (pixels[(y-1)*w + x] +
                   pixels[(y+1)*w + x] +
                   pixels[y*w + (x-1)] +
                   pixels[y*w + (x+1)] -
                   4 * pixels[y*w + x])
            lap.append(val)

    if not lap:
        return 0.0
    mean = sum(lap) / len(lap)
    variance = sum((v - mean) ** 2 for v in lap) / len(lap)
    return variance


def edge_gradient(pixels, w, h):
    """Mean absolute gradient (Sobel-like)."""
    grads = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            gx = abs(pixels[y*w + (x+1)] - pixels[y*w + (x-1)])
            gy = abs(pixels[(y+1)*w + x] - pixels[(y-1)*w + x])
            grads.append(math.sqrt(gx*gx + gy*gy))

    if not grads:
        return 0.0
    return sum(grads) / len(grads)


def high_freq_energy(pixels, w, h):
    """Ratio of high-frequency content via difference from blurred."""
    # Simple box blur (3x3)
    blurred = [0] * len(pixels)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            s = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    s += pixels[(y+dy)*w + (x+dx)]
            blurred[y*w + x] = s // 9

    # High-freq = original - blurred
    hf_energy = 0.0
    total_energy = 0.0
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            i = y * w + x
            diff = pixels[i] - blurred[i]
            hf_energy += diff * diff
            total_energy += pixels[i] * pixels[i]

    if total_energy == 0:
        return 0.0
    return hf_energy / total_energy


def analyze(path, crop=None):
    """Analyze sharpness of an image."""
    pixels, w, h = load_png_as_gray(path, crop)
    lap_var = laplacian_variance(pixels, w, h)
    edge_grad = edge_gradient(pixels, w, h)
    hf = high_freq_energy(pixels, w, h)

    print(f"  Image: {path}" + (f" crop={crop}" if crop else ""))
    print(f"  Size:  {w}x{h}")
    print(f"  Laplacian variance: {lap_var:>10.1f}  (higher = sharper, blurry<100, sharp>500)")
    print(f"  Edge gradient mean: {edge_grad:>10.2f}  (higher = crisper edges)")
    print(f"  High-freq energy:   {hf:>10.4f}  (higher = more detail)")
    print()
    return lap_var, edge_grad, hf


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    files = []
    crop = None
    for arg in sys.argv[1:]:
        if "+" in arg and "x" in arg.split("+")[0]:
            crop = arg
        elif os.path.exists(arg):
            files.append(arg)
        else:
            print(f"Unknown arg or file not found: {arg}")
            sys.exit(1)

    results = []
    for f in files:
        print(f"--- {os.path.basename(f)} ---")
        r = analyze(f, crop)
        results.append((f, r))

    if len(results) == 2:
        print("=== Comparison ===")
        (f1, (l1, e1, h1)), (f2, (l2, e2, h2)) = results
        print(f"  Laplacian: {os.path.basename(f1)}={l1:.0f} vs {os.path.basename(f2)}={l2:.0f}"
              f"  ({'+' if l1 > l2 else ''}{(l1-l2)/max(l2,1)*100:.0f}%)")
        print(f"  Gradient:  {os.path.basename(f1)}={e1:.1f} vs {os.path.basename(f2)}={e2:.1f}"
              f"  ({'+' if e1 > e2 else ''}{(e1-e2)/max(e2,1)*100:.0f}%)")
        winner = os.path.basename(f1) if l1 > l2 else os.path.basename(f2)
        print(f"  Sharper: {winner}")


if __name__ == "__main__":
    main()
