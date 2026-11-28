"""Bake carved cathedral rubble and two broken oak joinery pieces, with embedded PBR."""

import json
from pathlib import Path
import tempfile
import wave

import numpy as np
from PIL import Image, ImageFilter
from pilot_glb import Model

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/art_kit/hosts/H01"
ATLAS = ROOT / "game/assets/vfx_source/H01_rubble/masonry_oak_atlas.png"
# Half-extents in metres; mass is a separate Jolt fixture property.
ASSETS = [
    ("shale_fan", "岩片扇", 0, (0.64, 0.16, 0.43), 8),
    ("veined_flint", "裂脉燧石", 0, (0.43, 0.32, 0.34), 13),
    ("limestone_spall", "灰岩崩片", 1, (0.60, 0.26, 0.36), 15),
    ("granite_erratic", "花岗岩角砾", 2, (0.47, 0.42, 0.46), 28),
    ("voussoir", "拱券楔石", 1, (0.48, 0.29, 0.38), 24),
    ("sill_fragment", "滴水线断梁", 2, (0.82, 0.20, 0.28), 27),
    ("cornice", "檐口残块", 1, (0.55, 0.27, 0.35), 25),
    ("fluted_drum", "断槽柱鼓", 2, (0.43, 0.40, 0.43), 32),
    ("leaf_capital", "叶纹柱头", 1, (0.48, 0.33, 0.48), 30),
    ("scarf_beam", "斜接断木梁", 3, (0.96, 0.19, 0.15), 9),
    ("tenon_rail", "榫接梁头", 3, (0.76, 0.17, 0.21), 7),
]


def material(m, folder, idx):
    atlas = Image.open(ATLAS).convert("RGB")
    w, h = atlas.size
    x = idx % 2 * w // 2
    y = idx // 2 * h // 2
    im = atlas.crop((x + 4, y + 4, x + w // 2 - 4, y + h // 2 - 4)).resize(
        (512, 512), Image.Resampling.LANCZOS
    )
    im.save(folder / "color.jpg", quality=92)
    lum = np.asarray(im.convert("L").filter(ImageFilter.GaussianBlur(0.7)), float) / 255
    dy, dx = np.gradient(lum)
    norm = np.stack([-dx * 3.2, dy * 3.2, np.ones_like(dx)], axis=-1)
    norm /= np.linalg.norm(norm, axis=-1, keepdims=True)
    Image.fromarray(np.uint8((norm * 0.5 + 0.5) * 255)).save(
        folder / "normal.jpg", quality=94
    )
    orm = np.stack(
        [
            np.ones_like(lum),
            np.clip(0.81 + 0.14 * (0.5 - lum), 0, 1),
            np.zeros_like(lum),
        ],
        axis=-1,
    )
    Image.fromarray(np.uint8(orm * 255)).save(folder / "roughness.jpg", quality=90)
    m.doc["materials"] = [
        {
            "name": [
                "Laminated shale",
                "Weathered limestone",
                "Ash granite",
                "Split oak",
            ][idx],
            "pbrMetallicRoughness": {
                "baseColorTexture": m.texture(folder / "color.jpg"),
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
                "metallicRoughnessTexture": m.texture(folder / "roughness.jpg"),
            },
            "normalTexture": dict(m.texture(folder / "normal.jpg"), scale=0.66),
        }
    ]


def profile_point(k, theta, t):
    c, s = np.cos(theta), np.sin(theta)
    jag = (
        0.54 * np.sin(3 * theta + k)
        + 0.29 * np.cos(7 * theta + 1.1 * k)
        + 0.17 * np.sin(13 * theta)
    )
    if k < 4:
        lat = (t - 0.5) * np.pi
        d = np.array([np.cos(lat) * c, np.sin(lat), np.cos(lat) * s])
        # Intersect several differently oriented cleavage planes, then striate the exposed faces.
        planes = np.array(
            [
                [0.79, 0.48, 0.37],
                [-0.70, 0.51, 0.49],
                [0.21, 0.89, -0.40],
                [0.39, -0.78, 0.49],
                [-0.67, -0.24, -0.69],
            ]
        )
        planes = np.roll(planes, k, axis=0)
        radial = min(
            1.16,
            min(
                (0.67 + 0.12 * np.sin(n + 2 * k)) / max(0.001, d @ plane)
                for n, plane in enumerate(planes)
            ),
        )
        grain = 0.019 * np.sin(11 * lat + 2.2 * c + k) + 0.012 * np.sin(
            29 * lat + 4 * s
        )
        xyz = d * (radial + grain + jag * 0.033 * np.cos(lat))
        xyz[0] += 0.22 * xyz[1]
        xyz[2] += 0.12 * xyz[0] ** 2
        return xyz
    exponent = 0.24 if k not in [7, 8] else 1.0
    x = np.sign(c) * abs(c) ** exponent
    z = np.sign(s) * abs(s) ** exponent
    edge = min(1.0, max(0.0, min(t, 1 - t) / 0.12))
    if k in (7, 8):
        if k == 7:
            radius = np.interp(
                t,
                [0, 0.045, 0.10, 0.17, 0.22, 0.76, 0.83, 0.90, 1],
                [0.83, 0.98, 0.98, 0.90, 0.85, 0.81, 0.92, 0.91, 0.77],
            )
            radius -= 0.085 * (0.5 + 0.5 * np.cos(16 * theta)) ** 2 * min(1.0, edge * 2)
        else:
            radius = np.interp(
                t,
                [0, 0.09, 0.15, 0.21, 0.28, 0.68, 0.78, 0.85, 0.94, 1],
                [0.64, 0.75, 0.73, 0.69, 0.74, 0.96, 0.91, 1.0, 1.0, 0.89],
            )
            # Alternating lancet leaves and a milled bead course.
            leaf = (0.5 + 0.5 * np.cos(9 * theta + 2.4 * t)) ** 2
            radius += 0.17 * leaf * np.sin(np.pi * t) ** 2 + 0.035 * np.cos(
                31 * theta
            ) * np.exp(-(((t - 0.80) / 0.05) ** 2))
        top = (0.14 * jag - 0.38 * max(0.0, c - 0.18)) * t**4
        return np.array([x * radius, 2 * t - 1 + top, z * radius])
    if k >= 9:
        # The longitudinal axis is X. Saw shoulder and projecting tenon are part of the silhouette.
        section = (
            np.interp(
                t,
                [0, 0.04, 0.80, 0.84, 0.85, 0.96, 1],
                [0.91, 1, 0.98, 0.95, 0.52, 0.48, 0.41],
            )
            if k == 10
            else 0.93 + 0.07 * edge
        )
        splinter = (
            0.08 * np.sin(17 * theta) + 0.05 * np.sin(29 * theta) + 0.10 * c
        ) * (t**8)
        scarf = -0.27 * max(0.0, s) * t**4 if k == 9 else -0.11 * max(0.0, c) * t**6
        return np.array(
            [
                2 * t - 1 + splinter + scarf,
                x * section,
                z * section * (0.95 + 0.04 * np.sin(3 * theta + 4 * t)),
            ]
        )
    radius = 0.89 + 0.11 * edge
    if k == 4:
        radius *= 0.72 + 0.28 * t
    if k == 5:
        radius *= np.interp(
            t,
            [0, 0.21, 0.29, 0.37, 0.49, 0.55, 0.82, 1],
            [0.86, 0.85, 1, 0.94, 0.86, 1, 1, 0.91],
        )
    if k == 6:
        radius *= np.interp(
            t,
            [0, 0.09, 0.18, 0.27, 0.42, 0.61, 0.74, 0.81, 0.90, 1],
            [0.68, 0.79, 0.76, 0.80, 0.94, 0.88, 1, 0.96, 1, 0.99],
        )
    bite = 0.14 * max(0.0, np.cos(theta - 0.55)) ** 9 * (t**4)
    return np.array(
        [x * (radius - bite), 2 * t - 1 + 0.08 * jag * t**3, z * (radius - bite)]
    )


def build_shape(k, extent):
    n = 112 if k in [7, 8] else 80
    levels = 42 if k >= 4 else 31
    verts = []
    uv = []
    tri = []
    colors = []
    for i in range(n + 1):
        theta = 2 * np.pi * i / n
        for j in range(levels + 1):
            t = j / levels
            v = profile_point(k, theta, t) * extent
            verts.append(v)
            uv.append(
                ([t, i / n] if k >= 9 else [i / n * (2 if k in [7, 8] else 1), 1 - t])
            )
            patina = 0.77 + 0.18 * t + 0.055 * np.cos(theta * 3 + t * 9)
            colors.append([patina, patina * 0.99, patina * 0.95, 1])
            idx = len(verts) - 1
            if i and j:
                a = idx - levels - 1
                tri.extend([(a - 1, idx, a), (a - 1, idx - 1, idx)])
    if k >= 4:
        for j in [0, levels]:
            ring = np.array([verts[i * (levels + 1) + j] for i in range(n)])
            center = ring.mean(axis=0)
            base = len(verts)
            verts.append(center)
            uv.append([0.5, 0.5])
            colors.append([0.91, 0.89, 0.84, 1])
            # Separate fracture cap with cartesian UVs and shallow angular relief.
            for v in ring:
                verts.append(v)
                uv.append(
                    [
                        0.5 + 0.46 * v[2] / extent[2],
                        0.5 + 0.46 * v[1 if k >= 9 else 0] / extent[1 if k >= 9 else 0],
                    ]
                )
                colors.append([0.96, 0.94, 0.89, 1])
            for i in range(n):
                tri.append((base, base + 1 + i, base + 1 + (i + 1) % n))
    v = np.array(verts)
    tri = np.array(tri)
    # Orient each convex/star-shaped shell away from its core, including both caps.
    a, b, c = v[tri[:, 0]], v[tri[:, 1]], v[tri[:, 2]]
    flip = (np.cross(b - a, c - a) * (a + b + c)).sum(axis=1) < 0
    tri[flip] = tri[flip][:, [0, 2, 1]]
    return v, tri, uv, colors


def sound(name, wood):
    sr = 44100
    t = np.arange(int(sr * 1.22)) / sr
    rng = np.random.default_rng(491 + wood)
    impulses = np.zeros(len(t))
    for when in np.r_[
        rng.uniform(0.015, 0.79, 170 if not wood else 63), 0.83, 0.88, 0.92
    ]:
        impulses[int(when * sr)] += rng.uniform(0.14, 1.0) * (
            1.7 if when > 0.8 else 0.65
        )
    grain = rng.normal(0, 1, len(t))
    envelope = np.convolve(impulses, np.exp(-np.arange(620) / 106), "full")[: len(t)]
    rub = envelope * np.convolve(grain, np.ones(9) / 9, "same")
    for hz in [131, 283, 601, 1151] if wood else [77, 184, 341, 727, 1923]:
        kernel = np.sin(2 * np.pi * hz * t[:5600]) * np.exp(
            -t[:5600] * (20 if wood else 38)
        )
        rub += np.convolve(impulses, kernel, "full")[: len(t)] * 0.20
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, sr, 0, "NONE", "not compressed"))
        f.writeframes(np.int16(rub / max(abs(rub)) * 0.72 * 32767).tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = []
    with tempfile.TemporaryDirectory() as tmp:
        for k, (name, label, idx, extent, mass) in enumerate(ASSETS):
            m = Model()
            material(m, Path(tmp), idx)
            v, tri, uv, col = build_shape(k, np.array(extent))
            m.mesh(name, v, tri, uv, color=col)
            m.save(OUT / "models" / (name + ".glb"))
            catalog.append(
                dict(
                    id=name,
                    label=label,
                    medium="timber" if k >= 9 else "stone",
                    mass_kg=mass,
                )
            )
    (OUT / "hosts.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    )
    sound("S09_stone_drag", False)
    sound("oak_strain", True)


if __name__ == "__main__":
    main()
