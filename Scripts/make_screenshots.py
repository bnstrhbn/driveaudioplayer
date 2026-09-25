#!/usr/bin/env python3
"""Frames raw iPhone screenshots for the App Store listing.

    python3 Scripts/make_screenshots.py Marketing/raw Marketing/screenshots

Each raw PNG is matched to a caption by filename prefix (see CAPTIONS). Output
is 1320x2868 (6.9") and 1290x2796 (6.5"), on a dark watercolor background
with the app's palette, headline above a device-framed screenshot.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# filename prefix -> (headline, subhead)
CAPTIONS = {
    "01": ("Your Drive,\nas playlists", "Mixes, demos and rehearsals — straight from Google Drive"),
    "02": ("Note the moment\nyou hear it", "Playback pauses, you type, it resumes — pinned to the second"),
    "03": ("Every note,\nready to share", "Export a track or a whole folder as clean, timestamped text"),
    "04": ("Control it from\nthe Lock Screen", "Scrub, skip and jump ±15s — CarPlay and headphones too"),
    "05": ("Take it offline", "Download a folder, or let Wi‑Fi caching do it for you"),
    "06": ("Shared with you,\nnewest first", "See who shared each track and when"),
}
SIZES = {"6.9": (1320, 2868), "6.5": (1290, 2796)}
PALETTE = [(96, 104, 190), (64, 160, 162), (240, 132, 116), (236, 190, 92)]
BG = (16, 20, 28)
FONT = "/System/Library/Fonts/Avenir Next.ttc"
rng = np.random.default_rng(3)


def font(size, weight="bold"):
    """Picks a face from the .ttc by name; the index order varies between macOS versions."""
    wanted = {"bold": ["Heavy", "Bold", "Demi Bold"], "medium": ["Medium", "Regular"]}[weight]
    faces = {}
    for index in range(16):
        try:
            faces[ImageFont.truetype(FONT, size, index=index).getname()[1]] = index
        except OSError:
            break
    for name in wanted:
        if name in faces:
            return ImageFont.truetype(FONT, size, index=faces[name])
    return ImageFont.load_default()


def background(size, seed):
    w, h = size
    canvas = np.tile(np.array(BG, dtype=np.float32) / 255, (h, w, 1))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    local = np.random.default_rng(seed)
    # Two large soft blooms in the palette, screened onto the dark ground.
    for (cx, cy, r, color, a) in [
        (local.uniform(0.1, 0.4), local.uniform(0.05, 0.3), 0.8, PALETTE[seed % 4], 0.42),
        (local.uniform(0.6, 0.95), local.uniform(0.55, 0.9), 0.75, PALETTE[(seed + 1) % 4], 0.36),
        (local.uniform(0.3, 0.7), local.uniform(0.35, 0.65), 0.4, PALETTE[(seed + 2) % 4], 0.14),
    ]:
        d = np.hypot((xx - cx * w) / (r * w), (yy - cy * h) / (r * w))
        wobble = 1 + 0.12 * np.sin(6 * np.arctan2(yy - cy * h, xx - cx * w) + seed)
        alpha = np.clip(1 - d / wobble, 0, 1) ** 1.8 * a
        col = np.array(color, dtype=np.float32) / 255
        canvas = 1 - (1 - canvas) * (1 - alpha[..., None] * col[None, None, :])
    grain = local.normal(0, 0.012, (h, w, 1)).astype(np.float32)
    img = Image.fromarray((np.clip(canvas + grain, 0, 1) * 255).astype(np.uint8), "RGB")
    return img.filter(ImageFilter.GaussianBlur(1.2))


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def frame_screenshot(shot, target_width):
    """Device-style frame: rounded screen inside a slim dark bezel with a soft shadow."""
    scale = target_width / shot.width
    screen = shot.convert("RGB").resize((target_width, int(shot.height * scale)), Image.LANCZOS)
    corner = int(target_width * 0.13)
    bezel = int(target_width * 0.022)
    frame_size = (screen.width + 2 * bezel, screen.height + 2 * bezel)
    frame = Image.new("RGBA", frame_size, (0, 0, 0, 0))
    body = Image.new("RGBA", frame_size, (22, 22, 26, 255))
    body.putalpha(rounded_mask(frame_size, corner + bezel))
    frame.alpha_composite(body)
    # Hairline highlight on the bezel edge.
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame_size[0] - 1, frame_size[1] - 1), radius=corner + bezel, outline=(255, 255, 255, 60), width=3)
    screen_rgba = screen.convert("RGBA")
    screen_rgba.putalpha(rounded_mask(screen.size, corner))
    frame.alpha_composite(screen_rgba, (bezel, bezel))
    return frame


def draw_text(canvas, headline, subhead, width):
    draw = ImageDraw.Draw(canvas)
    margin = int(width * 0.075)
    head = font(int(width * 0.088), "bold")
    sub = font(int(width * 0.036), "medium")
    y = int(canvas.height * 0.055)
    for line in headline.split("\n"):
        draw.text((margin, y), line, font=head, fill=(255, 255, 255))
        y += int(head.size * 1.08)
    y += int(width * 0.02)
    # Wrap subhead to the content width.
    words, line, lines = subhead.split(), "", []
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=sub) > width - 2 * margin and line:
            lines.append(line); line = word
        else:
            line = trial
    lines.append(line)
    for l in lines:
        draw.text((margin, y), l, font=sub, fill=(255, 255, 255, 190))
        y += int(sub.size * 1.35)
    return y


def compose(shot, headline, subhead, size, seed):
    w, h = size
    canvas = background(size, seed).convert("RGBA")
    text_bottom = draw_text(canvas, headline, subhead, w)
    frame = frame_screenshot(shot, int(w * 0.84))
    x = (w - frame.width) // 2
    y = max(text_bottom + int(w * 0.06), int(h * 0.30))
    shadow = Image.new("RGBA", (frame.width + 160, frame.height + 160), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((80, 110, frame.width + 80, frame.height + 80), radius=int(frame.width * 0.15), fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    canvas.alpha_composite(shadow, (x - 80, y - 80))
    canvas.alpha_composite(frame, (x, y))
    return canvas.convert("RGB")


def main(raw_dir, out_dir):
    raw = sorted(Path(raw_dir).glob("*.png"))
    if not raw:
        sys.exit(f"no PNGs in {raw_dir}")
    for label, size in SIZES.items():
        target = Path(out_dir) / label
        target.mkdir(parents=True, exist_ok=True)
        for i, path in enumerate(raw):
            key = path.stem[:2]
            headline, subhead = CAPTIONS.get(key, (path.stem.replace("-", " ").title(), ""))
            image = compose(Image.open(path), headline, subhead, size, i)
            image.save(target / f"{path.stem}.png", optimize=True)
            print(f"{label}: {path.name} -> {headline.replace(chr(10), ' ')}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
