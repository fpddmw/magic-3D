"""Seal admitted recipe bytes and their deterministic price for the game loader."""

import hashlib
import json

from .admission import Recipe
from .schema import DATA, REG, read


def catalog():
    paths = sorted((DATA / "recipes").glob("*.json")) + sorted((DATA / "slice").glob("*.json"))
    paths += sorted((DATA / "trials").glob("*/admitted.json"))
    entries = []
    for p in paths:
        recipe = Recipe(read(p))
        if recipe.data["version"] != REG["game_edition"]:
            raise ValueError(f"{p.name}: 该 DSL 版本尚未接入游戏")
        entries.append(
            {
                "path": "res://data/magic_v0_3/" + p.relative_to(DATA).as_posix(),
                "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
                "quote": recipe.quote,
            }
        )
    return entries


if __name__ == "__main__":
    (DATA / "catalog.json").write_text(json.dumps(catalog(), ensure_ascii=False, indent=2) + "\n")
