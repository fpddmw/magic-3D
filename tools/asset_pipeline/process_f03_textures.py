"""Bake the three F03 luminance maps and inspectable binary erosion gates (Pillow, NumPy)."""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/vfx_source/F03_arc_blade"
OUT = ROOT / "game/art_kit/families/F03_arc_blade/textures"
PROOF = ROOT / "docs/art_assets/evidence/F03"


def luminance(name, size, floor):
    image = Image.open(SOURCE / (name + ".png")).convert("L").resize(size, Image.Resampling.LANCZOS)
    data = np.asarray(image, dtype=float)
    ceiling = np.percentile(data[data > floor], 99.8)
    return np.clip((data - floor) / (ceiling - floor), 0, 1)


def save(path, values):
    Image.fromarray(np.uint8(np.clip(values, 0, 1) * 255 + .5)).save(path)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PROOF.mkdir(parents=True, exist_ok=True)
    flow = luminance("energy_flow", (2048, 1024), 4)
    y, x = np.mgrid[0:1:1024j, 0:1:2048j]
    # Unpack the source's compressed wisps across the width of the sheet.
    src_y = np.interp(y[:, 0], [0, .10, .50, .88, 1], [.07, .14, .25, .46, .78])
    flow = flow[np.rint(src_y * 1023).astype(int)]
    ridge = .068 + .008 * np.sin(19*x) + .004 * np.sin(67*x + .5)
    flow = np.maximum(flow ** .78, np.exp(-((y-ridge)/.006)**2) * (.82 + .18*np.sin(14*x)**2))
    flow *= smooth(np.minimum(x, 1-x)/.094) * smooth((1-y)/.14)
    save(OUT / "energy_flow.png", flow)
    erosion = luminance("erosion_mask", (1024, 1024), 5)
    y = np.linspace(0, 1, 1024)[:, None]
    erosion = np.clip(erosion * (.86 + .14*(1-y)) + .09*(1-y)**2, 0, 1)
    save(OUT / "erosion_mask.png", erosion)
    for gate in [.25, .55, .80]:
        remaining = erosion > gate
        save(PROOF / f"erosion_{gate:.2f}.png", remaining)
        print(f"{gate:.2f} surviving top/middle/bottom",
              [round(float(section.mean()), 3) for section in np.split(remaining, [256, 614])])
    sparks = luminance("accent_sparks", (1024, 1024), 7)
    axis = np.arange(1024) % 512
    margin = smooth((np.minimum(axis, 511-axis)-32)/32)
    save(OUT / "accent_sparks.png", sparks**.75 * margin * margin[:, None])


if __name__ == "__main__":
    main()
