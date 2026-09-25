#!/usr/bin/env python3
"""Generates the app icon: layered translucent watercolor blooms on paper.

Procedural so it can be regenerated deterministically:
    python3 Scripts/make_icon.py [seed]
Writes Icon-1024.png plus every size listed in the asset catalog.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024
SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 7
rng = np.random.default_rng(SEED)
ICONSET = Path(__file__).resolve().parents[1] / "DriveAudioPlayer/Resources/Assets.xcassets/AppIcon.appiconset"


def value_noise(shape, cells, octaves=4, persistence=0.55):
    """Smooth multi-octave noise in [0, 1] via upsampled random grids."""
    out = np.zeros(shape, dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = cells * (2 ** o)
        grid = rng.random((n, n)).astype(np.float32)
        layer = np.asarray(Image.fromarray((grid * 255).astype(np.uint8)).resize(shape[::-1], Image.BICUBIC), dtype=np.float32) / 255
        out += layer * amp
        total += amp
        amp *= persistence
    return out / total


def bloom_mask(center, radius, wobble=0.28, softness=0.08, feather=3):
    """Irregular soft disc with watercolor-style darkened edge. Returns (fill, edge)."""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    dx, dy = xx - center[0], yy - center[1]
    dist = np.hypot(dx, dy)
    angle = np.arctan2(dy, dx)
    # Radius varies with angle (low-frequency wobble) and with position (noise).
    harmonics = sum(rng.uniform(0.3, 1.0) * np.cos(k * angle + rng.uniform(0, 2 * math.pi)) / k for k in range(1, 5))
    r = radius * (1 + wobble * harmonics / 2)
    r = r * (0.92 + 0.16 * value_noise((SIZE, SIZE), 6, octaves=3))
    edge_width = radius * softness
    fill = np.clip((r - dist) / edge_width, 0, 1)
    fill = fill ** 1.5
    # Pigment pools at the boundary: a thin band just inside the edge.
    band = np.exp(-((dist - (r - edge_width * 0.6)) ** 2) / (2 * (edge_width * 0.9) ** 2))
    edge = band * (fill > 0.02)
    # Uneven pigment density inside the wash.
    texture = 0.75 + 0.5 * value_noise((SIZE, SIZE), 5, octaves=4)
    fill = np.clip(fill * texture, 0, 1)
    fill = np.asarray(Image.fromarray((fill * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(feather)), dtype=np.float32) / 255
    return fill, edge


def paper():
    base = np.array([250, 247, 241], dtype=np.float32) / 255
    grain = value_noise((SIZE, SIZE), 64, octaves=2)
    fine = rng.normal(0, 0.012, (SIZE, SIZE)).astype(np.float32)
    shade = 1 - 0.035 * (grain - 0.5) + fine
    return np.clip(base[None, None, :] * shade[..., None], 0, 1)


def multiply(canvas, color, alpha):
    """Watercolor layering: pigment multiplies what is underneath."""
    color = np.asarray(color, dtype=np.float32) / 255
    layer = 1 - alpha[..., None] * (1 - color[None, None, :])
    return canvas * layer


def main():
    canvas = paper()
    # Palette: dusk indigo, deep teal, warm coral, ochre accent.
    # Light, transparent washes so overlaps mix into new hues instead of mud.
    blooms = [
        ((0.38, 0.42), 0.34, (96, 104, 190), 0.55),
        ((0.64, 0.60), 0.30, (64, 160, 162), 0.52),
        ((0.60, 0.28), 0.20, (240, 132, 116), 0.55),
        ((0.30, 0.70), 0.17, (236, 190, 92), 0.50),
    ]
    for (cx, cy), rad, color, strength in blooms:
        fill, edge = bloom_mask((cx * SIZE, cy * SIZE), rad * SIZE)
        canvas = multiply(canvas, color, fill * strength)
        # Pigment pools at the edge as it dries: a slightly deeper rim.
        dark = tuple(int(c * 0.8) for c in color)
        canvas = multiply(canvas, dark, edge * strength * 0.4)
    # A few loose spatters for hand-made feel.
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    for _ in range(26):
        cx, cy = rng.uniform(0.12, 0.88, 2) * SIZE
        r = rng.uniform(3, 14)
        color = blooms[rng.integers(len(blooms))][2]
        spot = np.clip((r - np.hypot(xx - cx, yy - cy)) / 1.5, 0, 1)
        canvas = multiply(canvas, color, spot * rng.uniform(0.35, 0.7))
    # Soft vignette so the composition sits inside the rounded icon shape.
    cx = cy = SIZE / 2
    d = np.hypot(xx - cx, yy - cy) / (SIZE * 0.72)
    canvas = canvas * (1 - 0.06 * np.clip(d, 0, 1) ** 2)[..., None]

    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(ICONSET / "Icon-1024.png", optimize=True)
    for entry in json.loads((ICONSET / "Contents.json").read_text())["images"]:
        if entry["filename"] == "Icon-1024.png":
            continue
        pts = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = int(round(pts * scale))
        img.resize((px, px), Image.LANCZOS).save(ICONSET / entry["filename"], optimize=True)
    print(f"wrote icons to {ICONSET} (seed {SEED})")


if __name__ == "__main__":
    main()
