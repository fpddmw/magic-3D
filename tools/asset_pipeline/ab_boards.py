"""Assemble labelled contact sheets exclusively from Godot readbacks or decoded film frames."""

from pathlib import Path
import io
import json
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PROOF = ROOT / "docs/art_assets/evidence"
FONT = "/System/Library/Fonts/Helvetica.ttc"


def board(cells, columns, path, width=415):
    h = int(width * 9 / 16)
    image = Image.new(
        "RGB",
        (columns * width, ((len(cells) + columns - 1) // columns) * (h + 30)),
        "#202226",
    )
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype(FONT, 16)
    except OSError:
        font = ImageFont.load_default()
    for i, (label, pic) in enumerate(cells):
        x, y = i % columns * width, i // columns * (h + 30)
        image.paste(
            pic.convert("RGB").resize((width, h), Image.Resampling.LANCZOS), (x, y)
        )
        draw.text((x + 9, y + h + 5), label, font=font, fill="#e1e3e6")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def plates(family):
    src = ROOT / ".local/ab/view" / family
    out = PROOF / family
    labels = [
        "Clay / front",
        "Clay / side",
        "Clay / back",
        "P01  Cold silver",
        "P04  Refraction",
        "P15  Pressure",
    ]
    board(
        [(l, Image.open(src / f"mode_{i}.png")) for i, l in enumerate(labels)],
        3,
        out / f"{family.lower()}_viewer_modes.png",
    )
    states = (
        ["01 Edge draw", "02 Gather", "03 Sweep", "04 Travel", "05 Erode", "06 Retract"]
        if family == "F03"
        else ["01 Compress", "02 Overturn", "05 Settle"]
    )
    cells = [
        (f"{s}  {pct}%  {part}", Image.open(src / f"s{i}_{j}_{part}.png"))
        for i, s in enumerate(states)
        for j, pct in enumerate([25, 55, 85])
        for part in ["before", "after"]
    ]
    board(cells, 6, out / f"{family.lower()}_interrupt_check.png", 300)


def still(video, time):
    ff = shutil.which("ffmpeg") or next(
        (ROOT / ".local/art_lab/venv").rglob("ffmpeg-macos*")
    )
    data = subprocess.check_output(
        [
            str(ff),
            "-loglevel",
            "error",
            "-ss",
            str(time),
            "-i",
            str(video),
            "-frames:v",
            "1",
            "-vf",
            "scale=720:-2",
            "-f",
            "image2pipe",
            "-vcodec",
            "png",
            "-",
        ]
    )
    return Image.open(io.BytesIO(data))


def film_board(folder, name, takes):
    cells = [
        (
            f"{video.upper()}   {t:.2f}s   {label}",
            still(PROOF / folder / (video + ".mp4"), t),
        )
        for video, beats in takes.items()
        for t, label in beats
    ]
    board(cells, 4, PROOF / folder / name, 460)


def host_plates():
    src = ROOT / ".local/ab/view/H01"
    manifest = json.loads((ROOT / "game/art_kit/hosts/H01/hosts.json").read_text())
    board(
        [
            (
                row["id"].replace("_", " ").title() + f"  |  {row['mass_kg']} kg",
                Image.open(src / f"host_{i:02d}.png"),
            )
            for i, row in enumerate(manifest)
        ],
        4,
        PROOF / "B/h01_host_catalog.png",
        450,
    )
    poses = [
        (82, "01  Pickup / X03"),
        (187, "02  Arc slots"),
        (285, "Ring / turn"),
        (383, "Two tiers"),
        (452, "Dispatch / vacant slots"),
        (503, "03  Handoff / fall"),
        (552, "Landing"),
        (625, "World retains bodies"),
    ]
    board(
        [(label, Image.open(src / f"live_{i:03d}.png")) for i, label in poses],
        4,
        PROOF / "B/f10_studio.png",
        420,
    )


if __name__ == "__main__":
    if sys.argv[1] == "arc-film":
        film_board(
            "F03",
            "keyframes.jpg",
            {
                "v1": [
                    (0.90, "Draw"),
                    (1.12, "Flight"),
                    (1.40, "Pier"),
                    (4.73, "Empty / erosion"),
                ],
                "v2": [
                    (1.95, "Load"),
                    (3.10, "Apex"),
                    (3.54, "Cleave"),
                    (4.92, "Erosion"),
                ],
                "v3": [
                    (1.40, "Gather"),
                    (2.40, "Refraction"),
                    (3.98, "Advance"),
                    (4.68, "Recoil"),
                ],
            },
        )
    elif sys.argv[1] == "a4-film":
        film_board(
            "F04",
            "a4_keyframes.jpg",
            {
                "a4": [
                    (1.72, "Compression"),
                    (3.41, "Apex"),
                    (3.98, "Paid front / rubble"),
                    (4.58, "X07 / thrown hosts"),
                ]
            },
        )
    elif sys.argv[1] == "host-studio":
        host_plates()
    elif sys.argv[1] == "host-film":
        for take in ("b1_stone", "b1_timber", "b1_32"):
            film_board(
                "B",
                take + "_keyframes.jpg",
                {
                    take: [
                        (0.80, "Rest"),
                        (1.61, "Staggered lift"),
                        (3.08, "Crown arc"),
                        (4.69, "Turning ring"),
                        (6.32, "Tiered slots"),
                        (7.78, "Dispatch"),
                        (8.55, "Interrupted / falling"),
                        (10.74, "After landing"),
                    ]
                },
            )
    else:
        plates(sys.argv[1])
