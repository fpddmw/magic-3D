"""Validate each embedded five-facet contract and seal its deterministic quote."""
import json
from pathlib import Path

from tools.magic_dsl_v0_3.admission import Recipe

HERE = Path(__file__).resolve().parents[2] / "game/art_kit/families/F03_arc_blade/recipes"


def main():
    entries = []
    for path in sorted(HERE.glob("v*.json")):
        raw = path.read_bytes()
        trial = json.loads(raw)
        contract = Recipe(trial["contract"])
        law = trial["front"]
        assert 45 <= law["span_deg"] <= 160 and 0 < law["width_m"] <= 7
        assert 0 < law["range_m"] <= contract.subjects["field"]["spatial"]["geometry"]["extent_m"]
        entries.append(dict(file=path.name, admitted_contract=contract.data, quote=contract.quote))
    (HERE / "catalog.json").write_text(json.dumps(entries, indent=2) + "\n")


if __name__ == "__main__":
    main()
