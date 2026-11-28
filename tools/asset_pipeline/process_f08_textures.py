"""Bake ImageGen scans to linear data maps; run with Pillow and NumPy."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game/assets/vfx_source/F08_open_veil"
TEX = ROOT / "game/art_kit/families/F08_open_veil/textures"
EVIDENCE = ROOT / "docs/art_assets/evidence/F08"


def scan(name):
    image = Image.open(SRC / (name + "_source.png")).convert("L")
    return image.resize((1024, 1024), Image.Resampling.LANCZOS)


def unit(data, low, high):
    return np.clip((data.astype(float) - low) / (high - low), 0, 1)


def channel(a):
    return Image.fromarray(np.rint(a * 255).astype("uint8"))


def bake():
    TEX.mkdir(parents=True, exist_ok=True)
    flow = scan("flow")
    broad = np.asarray(flow.filter(ImageFilter.GaussianBlur(5)), dtype=float)
    dy, dx = np.gradient(broad)
    # Tangent field, encoded around neutral; blue preserves woven thread density.
    direction = np.stack((dy, -dx))
    direction /= np.sqrt(5.0 + np.sum(direction**2, axis=0))
    weave = unit(np.asarray(flow), *np.percentile(flow, [.8, 99.4]))
    Image.merge("RGB", (channel(.5 + .5*direction[0]), channel(.5 + .5*direction[1]),
                        channel(weave))).save(TEX / "veil_flow.png")
    erosion = np.asarray(scan("erosion").filter(ImageFilter.GaussianBlur(.6)))
    channel(unit(erosion, *np.percentile(erosion, [1, 99]))).save(TEX / "veil_erosion.png")
    crack = scan("crack").filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(.85))
    a = np.asarray(crack)
    y, x = np.mgrid[-1:1:1024j, -1:1:1024j]
    radius = np.hypot(x, y)
    # Preserve peripheral forks at light load and a bright core at the high threshold.
    strength = unit(a, 4, np.percentile(a[a > 10], 98))**.65
    mask = channel(strength * np.clip((1-radius) * 5, 0, 1))
    mask.save(TEX / "load_crack_mask.png")
    board = Image.new("RGB", (1056, 398), "#20242a")
    draw = ImageDraw.Draw(board)
    draw.text((12, 12), "F08   /   LOAD FRACTURE     |     MASK THRESHOLDS", fill="#e8dbc2", font_size=18)
    for i, threshold in enumerate((.25, .55, .8)):
        binary = np.asarray(mask) / 255 >= threshold
        thumb = channel(binary).resize((332, 300), Image.Resampling.BOX)
        board.paste(thumb, (12+348*i, 50))
        draw.text((14+i*348, 362), f"t = {threshold:.2f}     {binary.mean():.2%} coverage",
                  fill="#cfccc0", font_size=16)
    board.save(EVIDENCE / "load_crack_thresholds.png")


if __name__ == "__main__":
    bake()
