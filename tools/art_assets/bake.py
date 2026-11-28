"""Bake wrapped material data and the observatory's five mono mix stems."""

from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, distance_transform_edt
from scipy.signal import butter, sosfilt
from scipy.io.wavfile import write as write_wave

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "game/assets"
TEX = ASSETS / "textures/observatory"
SFX = ASSETS / "audio/observatory"
rng = np.random.default_rng(4183)


def save(name, value):
    Image.fromarray(np.uint8(np.clip(value, 0, 1) * 255 + 0.0)).save(TEX / name)


def wrap(height, axis):
    # Mirror only a narrow feathered band at the UV seam.
    h = np.swapaxes(height.copy(), 0, axis)
    width = max(4, len(h) // 32)
    w = (0.5 * (1 - np.linspace(0, 1, width)))[:, None]
    lo, hi = h[:width].copy(), h[-width:][::-1].copy()
    h[:width] = lo * (1 - w) + hi * w
    h[-width:] = (hi * (1 - w) + lo * w)[::-1]
    return np.swapaxes(h, 0, axis)


def bake_surface(name):
    size = (2048, 1024) if name == "lunar" else (768, 768)
    g = (
        np.asarray(
            Image.open(HERE / "sources" / (name + ".jpg")).convert("L").resize(size),
            float,
        )
        / 255
    )
    g = wrap(g, 1)
    if name != "lunar":
        g = wrap(g, 0)
    dx = (np.roll(g, -1, 1) - np.roll(g, 1, 1)) * 2.1
    dy = (np.roll(g, -1, 0) - np.roll(g, 1, 0)) * 2.1
    normal = np.stack((-dx, dy, np.ones_like(g)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    save(name + "_normal.png", normal * 0.5 + 0.5)
    if name == "lunar":
        save(
            "lunar_relief.png",
            np.stack(
                (
                    g,
                    gaussian_filter(g, 7, mode="wrap"),
                    np.clip(abs(g - gaussian_filter(g, 2)) * 4, 0, 1),
                ),
                axis=-1,
            ),
        )


def bake_field():
    def band(sigma):
        n = gaussian_filter(rng.normal(size=(512, 512)), sigma, mode="wrap")
        return (n - n.mean()) / n.std()

    f = band(28) * 0.52 + band(9) * 0.29 + band(2) * 0.12 + band(0.65) * 0.07
    dx = np.roll(f, 1, 0) - np.roll(f, -1, 0)
    dy = np.roll(f, -1, 1) - np.roll(f, 1, 1)
    seeds = np.ones(f.shape)
    seeds[rng.integers(0, 512, 200), rng.integers(0, 512, 200)] = 0
    cells = distance_transform_edt(np.tile(seeds, (3, 3)))[512:1024, 512:1024]
    save(
        "flow.png",
        np.stack((0.5 + 1.8 * dx, 0.5 + 1.8 * dy, 0.5 + 0.23 * f, cells / 40), axis=-1),
    )
    y, x = np.mgrid[-1:1:65j, -1:1:65j]
    r = np.hypot(x, y)
    glint = (
        np.exp(-28 * r * r)
        + 0.55 * np.exp(-42 * abs(x) - 7 * abs(y))
        + 0.22 * np.exp(-45 * abs(y) - 8 * abs(x))
    )
    save("glint.png", glint)
    save("falloff.png", np.exp(-4 * np.linspace(0, 1, 256))[None, :])


def sound():
    sr = 44100

    def time(length):
        return np.arange(round(length * sr)) / sr

    def air(t, cutoffs):
        return sosfilt(
            butter(3, cutoffs, btype="bandpass", fs=sr, output="sos"),
            rng.normal(size=len(t)),
        )

    def store(name, t, sig, attack, tail, level):
        envelope = (
            np.clip(t / attack, 0, 1) ** 1.4 * np.clip((t[-1] - t) / tail, 0, 1) ** 1.5
        )
        sig = sig * envelope
        write_wave(
            SFX / (name + ".wav"),
            sr,
            np.int16(sig / (np.max(abs(sig)) + 1e-6) * level * 32767),
        )

    t = time(4.0)
    partials = sum(
        np.sin(2 * np.pi * (f * t + 0.09 * np.sin(t * rate))) / (i + 1) ** 1.25
        for i, (f, rate) in enumerate(
            [
                (46.25, 0.83),
                (69.42, 1.1),
                (92.7, 0.61),
                (139.1, 0.94),
                (233.8, 0.48),
                (278.4, 0.85),
            ]
        )
    )
    store("foundation", t, partials + 0.18 * air(t, [32, 85]), 1.25, 0.7, 0.60)
    t = time(3.1)
    store(
        "breath",
        t,
        air(t, [140, 1700]) * (0.25 + 0.75 * np.sin(t * np.pi / t[-1]) ** 2),
        0.8,
        0.55,
        0.43,
    )
    t = time(2.3)
    metal = sum(
        np.cos(2 * np.pi * f * t) * np.exp(-t / a) * w
        for f, a, w in [
            (277, 1.4, 0.24),
            (415, 1.1, 0.34),
            (697, 0.83, 0.40),
            (1116, 0.50, 0.21),
            (1770, 0.3, 0.10),
        ]
    )
    store(
        "filigree",
        t,
        metal + 0.16 * air(t, [800, 3200]) * np.exp(-8 * t),
        0.014,
        0.3,
        0.47,
    )
    t = time(1.6)
    pressure = np.sin(2 * np.pi * (39 * t + 4.5 * (1 - np.exp(-9 * t)))) * np.exp(
        -3.7 * t
    )
    store(
        "release",
        t,
        pressure + 0.46 * air(t, [95, 2400]) * np.exp(-10 * t),
        0.007,
        0.28,
        0.77,
    )
    t = time(2.4)
    bells = sum(
        np.cos(2 * np.pi * f * t) * a * np.exp(-t / d)
        for f, a, d in [
            (82, 0.3, 0.48),
            (192, 0.28, 0.7),
            (292, 0.18, 1.1),
            (517, 0.13, 1.35),
            (712, 0.07, 0.99),
        ]
    )
    store(
        "stone_contact",
        t,
        bells + 0.63 * air(t, [200, 3800]) * np.exp(-19 * t),
        0.005,
        0.45,
        0.72,
    )


if __name__ == "__main__":
    TEX.mkdir(parents=True, exist_ok=True)
    SFX.mkdir(parents=True, exist_ok=True)
    for material in ["lunar", "etch", "crystal"]:
        bake_surface(material)
    bake_field()
    sound()
