"""Seal admitted recipe bytes and their deterministic price for the game loader."""
import hashlib
import json
from .admission import Recipe
from .schema import DATA, read

def catalog():
    paths = sorted((DATA/"recipes").glob("*.json")) + sorted((DATA/"slice").glob("*.json"))
    paths += sorted((DATA/"trials").glob("*/admitted.json"))
    return [{"path":"res://data/magic_v0_3/"+p.relative_to(DATA).as_posix(),
             "sha256":hashlib.sha256(p.read_bytes()).hexdigest(), "quote":Recipe(read(p)).quote} for p in paths]

if __name__=="__main__":
    (DATA/"catalog.json").write_text(json.dumps(catalog(),ensure_ascii=False,indent=2)+"\n")
