"""Publish labelled Godot viewport captures. No compositing inside the images."""

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
STUDY = ROOT / "game/art_lab/reference_studies/celestial_descent.json"
CONDITIONS = ROOT / "game/art_lab/variations/review.json"


def font(size, title=False):
    candidates = (
        ["/System/Library/Fonts/Supplemental/Baskerville.ttc", "DejaVuSerif.ttf"]
        if title
        else ["/System/Library/Fonts/HelveticaNeue.ttc", "DejaVuSans.ttf"]
    )
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def plate(source, destination, title, subtitle, cells, columns, width):
    w = width
    h = round(w * 9 / 16)
    gap = 12
    edge = 27
    top = 92
    row = h + 45
    sheet = Image.new(
        "RGB",
        (
            edge * 2 + columns * w + (columns - 1) * gap,
            top + ((len(cells) + columns - 1) // columns) * row + 16,
        ),
        (18, 21, 24),
    )
    ink = ImageDraw.Draw(sheet)
    ink.text((edge, 12), title, font=font(41, True), fill="#e7decd")
    ink.text((edge, 61), subtitle, font=font(16), fill="#a9adaf")
    for i, (file, label) in enumerate(cells):
        x = edge + (i % columns) * (w + gap)
        y = top + (i // columns) * row
        with Image.open(source / (file + ".png")) as img:
            sheet.paste(
                img.convert("RGB").resize((w, h), Image.Resampling.LANCZOS), (x, y)
            )
        ink.text((x, y + h + 6), label, font=font(16), fill="#cbc6ba")
    sheet.save(destination)


def publish(source, dest):
    study = json.loads(STUDY.read_text())
    dest.mkdir(parents=True, exist_ok=True)
    phase_rows = [
        (f"phase_{i}_view_{j}", f"{t:.2f} s    {study['phases'][i]}  /  {view}")
        for i, t in enumerate(study["times"])
        for j, view in enumerate(study["cameras"])
    ]
    plate(
        source,
        dest / "contact-sheet.png",
        "Celestial descent",
        "Six instants in the same cast. Read each row from left to right.",
        phase_rows,
        3,
        510,
    )
    plate(
        source,
        dest / "layers.png",
        "At full formation",
        "Identical camera and time, 3.20 s. Each view isolates one contributor.",
        [
            (f"layer_{i}", name)
            for i, name in enumerate(
                [
                    "Opaque terrain",
                    "Optical thickness",
                    "Swept ribbons",
                    "Field-driven particles",
                ]
            )
        ],
        2,
        520,
    )
    cases = json.loads(CONDITIONS.read_text())
    plate(
        source,
        dest / "conditions.png",
        "Changes of viewpoint and state",
        "The two casts have independent phase and release state.",
        [(f"condition_{i}", c["name"]) for i, c in enumerate(cases)],
        2,
        520,
    )
    shutil.copyfile(source / "observations.json", dest / "observations.json")
    with Image.open(source / "phase_2_view_0.png") as hero:
        hero.convert("RGB").save(dest / "formation.jpg", quality=92)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    publish(args.source, args.destination)
