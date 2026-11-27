"""Replay the column study through the public recipe and simulation interfaces."""

import json
from copy import deepcopy

from .admission import Recipe
from .schema import DATA, read
from .simulate import Simulation

STUDY = DATA / "studies/column_field"


def cases(source):
    for name, override in (
        ("vortex", {}),
        ("without_lift", {"axial": 0}),
        (
            "reversed_spin",
            {"tangential": -source["Processes"]["nodes"][0]["active"][0]["field_vector"]["tangential"]},
        ),
    ):
        data = deepcopy(source)
        data["Processes"]["nodes"][0]["active"][0]["field_vector"].update(override)
        yield name, override, Recipe(data)


def comparison():
    scene = read(STUDY / "scene.json")
    release = scene["events"][0]["at"]
    report = {}
    for name, override, recipe in cases(read(STUDY / "recipe.json")):
        samples = []
        for end in (release / 2, release, scene["until_s"]):
            result = Simulation(recipe, {**scene, "until_s": end}).run()
            probes = {
                key: {
                    "position_m": [round(v, 9) for v in obj["position"]],
                    "velocity_m_s": [round(v, 9) for v in obj.get("velocity", [0, 0, 0])],
                }
                for key, obj in result["objects"].items()
            }
            samples.append(
                {
                    "at_s": end,
                    "status": result["status"],
                    "mana_spent": round(result["mana_spent"], 9),
                    "sum_impulse_magnitudes_ns": round(result["delivered_impulse"], 9),
                    "probes": probes,
                }
            )
        report[name] = {"field_vector_override": override, "budgets": recipe.budgets, "samples": samples}
    return report


if __name__ == "__main__":
    print(json.dumps(comparison(), ensure_ascii=False, indent=2, allow_nan=False))
