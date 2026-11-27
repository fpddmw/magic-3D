"""Sample a catalog recipe at the two aim positions, release, and coast."""

import argparse
import json
from pathlib import Path

from .admission import Recipe
from .schema import DATA, read
from .simulate import Simulation

SCENE = DATA / "studies/aim_field/scene.json"


def observe(data, scene):
    recipe = Recipe(data)
    samples = []
    for at in [event["at"] for event in scene["events"]] + [scene["until_s"]]:
        result = Simulation(recipe, {**scene, "until_s": at}).run()
        samples.append(
            {
                "at_s": at,
                "mana_spent": round(result["mana_spent"], 8),
                "status": result["status"],
                "probes": {
                    key: {
                        "velocity_m_s": [round(v, 8) for v in obj.get("velocity", [0, 0, 0])],
                        "temperature_delta": round(obj.get("temperature_delta", 0), 8),
                    }
                    for key, obj in result["objects"].items()
                },
            }
        )
    return samples


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recipes", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps({p.stem: observe(read(p), read(SCENE)) for p in args.recipes}, indent=2))
