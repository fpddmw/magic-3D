"""Lathe an independent curling pressure lip and a torn ground-level dust skirt."""

from pathlib import Path
import numpy as np
from pilot_glb import Model

OUT = Path(__file__).resolve().parents[2] / "game/art_kit/families/F04_wave"
# Outside lip curls upward and back over the trailing lamina. Coordinates are radius and height.
SECTION = [
    (1.00, 0.010),
    (1.018, 0.055),
    (1.00, 0.133),
    (0.968, 0.173),
    (0.928, 0.162),
    (0.907, 0.123),
    (0.915, 0.089),
    (0.885, 0.059),
    (0.813, 0.034),
    (0.71, 0.019),
    (0.58, 0.010),
]


def main():
    model = Model()
    model.doc["materials"] = [{"doubleSided": True}]
    for skirt in (False, True):
        v = []
        uv = []
        uv2 = []
        color = []
        tri = []
        fold = []
        collapse = []
        profile = (
            [(1.055, 0.012), (1.01, 0.062), (0.94, 0.086), (0.84, 0.018)]
            if skirt
            else SECTION
        )
        for i in range(161):
            s = i / 160
            theta = 2 * np.pi * s
            wave = (
                np.sin(theta * 7 + 0.8) * 0.5
                + np.sin(theta * 13) * 0.3
                + np.sin(theta * 3) * 0.2
            )
            for j, (r, h) in enumerate(profile):
                t = j / (len(profile) - 1)
                radial = r + wave * (0.009 + 0.024 * t)
                y = h * (1 + 0.32 * wave)
                d = np.array([np.cos(theta), 0, np.sin(theta)])
                v.append(d * radial + [0, y, 0])
                fold.append(
                    d * (radial - 0.10 * (1 - t) ** 2) + [0, y * 0.22 + 0.025 * t, 0]
                )
                collapse.append(
                    d * (radial + 0.08 * wave * t)
                    + [0, y * 0.07 + 0.012 * np.sin(theta * 17) * t, 0]
                )
                uv.append([s, t])
                uv2.append([s, 1 - t])
                color.append([1, 1, 1, 1])
                if i and j:
                    b = len(v) - 1
                    a = b - len(profile)
                    tri.extend([(a - 1, b - 1, b), (a - 1, b, a)])
        model.mesh(
            "DustFoot" if skirt else "Breaker",
            v,
            tri,
            uv,
            targets={"compression": np.array(fold), "subsidence": np.array(collapse)},
            color=color,
            uv2=uv2,
        )
    model.save(OUT / "F04_wave.glb")


if __name__ == "__main__":
    main()
