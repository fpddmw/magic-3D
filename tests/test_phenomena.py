import unittest
from copy import deepcopy

from tools.magic_dsl_v0_3.admission import Diagnostic, Recipe, structure
from tools.magic_dsl_v0_3.altar import accept
from tools.magic_dsl_v0_3.catalog import catalog
from tools.magic_dsl_v0_3.schema import DATA, read
from tools.magic_dsl_v0_3.simulate import Simulation
from tools.magic_dsl_v0_3.world import World


def sample(folder, name):
    return read(DATA / folder / (name + ".json"))


def run(recipe, scene):
    return Simulation(Recipe(recipe), scene).run()


class PhenomenaTests(unittest.TestCase):
    def test_channel_witnesses(self):
        scene = sample("fixtures", "hall")
        stone = scene["objects"][0]
        stone.update(occluded=True, thermal_path="contact")
        self.assertGreater(run(sample("recipes", "gravity"), scene)["objects"]["stone"]["velocity"][1], 0)
        self.assertGreater(
            run(sample("recipes", "heat"), scene)["objects"]["stone"]["temperature_delta"], 0
        )
        stone["thermal_path"] = "insulated"
        self.assertNotIn("temperature_delta", run(sample("recipes", "heat"), scene)["objects"]["stone"])
        beam = sample("recipes", "hosted_light")["Subjects"][0]["spatial"]
        world = World(scene)
        self.assertNotIn("stone", world.affected(beam, (world.origin, world.aim), "pressure"))
        self.assertNotIn("stone", world.affected(beam, (world.origin, world.aim), "optical"))
        stone["transmission"] = 0.2
        self.assertEqual(World(scene).affected(beam, (world.origin, world.aim), "optical")["stone"][1], 0.2)

    def test_interfaces_and_anchors(self):
        r = sample("recipes", "bear_load")
        r["Concepts"][0]["nature"] = "aether"
        Recipe(r)
        scene = sample("fixtures", "hall")
        scene["slots"]["target"] = "bell"
        for anchor, expected in [("target", [0, 0, 4]), ("aim_point", [1, 1, 2])]:
            scene["aim_point"] = [1, 1, 2]
            r["Subjects"][0]["spatial"]["reference"]["anchor"] = anchor
            self.assertEqual(World(scene).capture(Recipe(r), "field")[0], expected)
        del scene["aim_point"]
        self.assertTrue(any(e.get("reason") == "missing_binding" for e in run(r, scene)["events"]))

    def test_axes_and_material_handoff(self):
        for axis, expected in [
            ("radial_in", [-1, 0, 0]),
            ("radial_out", [1, 0, 0]),
            ("tangential", [0, 0, -1]),
        ]:
            self.assertEqual(World.axis(axis, [0, 0, 0], [0, 0, 1], [2, 0, 0]), expected)
        base = sample("slice", "cast_stone")
        n = base["Processes"]["nodes"][0]
        n["active"].append({"op": "Transform", "ability": "grow", "target": "stone"})
        n["enter"].append({"op": "Transform", "ability": "fracture", "target": "stone"})
        scene = sample("fixtures", "wind")
        result = run(base, scene)
        obj = result["objects"]["manifest_stone"]
        self.assertGreater(obj["velocity"][2], 0)
        self.assertGreater(obj["growth"], 0)
        self.assertEqual(obj["fragments"], 3)
        self.assertTrue(any(e["event"] == "handoff_world" for e in result["events"]))

    def test_reverse_phase(self):
        r = sample("recipes", "ice_body")
        n = r["Processes"]["nodes"][0]
        n["enter"] = n["enter"][:2]
        n["enter"][1]["ability"] = "melt"
        n["exit"][0]["target"] = "field"
        r["Subjects"] = r["Subjects"][:2]
        r["Subjects"][0]["initial_phase"] = "solid"
        r["Expression"] = []
        scene = sample("fixtures", "stream")
        scene["objects"][0]["phase"] = "solid"
        result = run(r, scene)
        self.assertEqual(result["objects"]["root"]["phase"], "liquid")

    def test_art_and_ledgers(self):
        r = sample("slice", "cast_stone")
        b = Recipe(r).budgets
        self.assertEqual(b["physics"]["bodies"], 1)
        self.assertGreater(b["render"]["layers"], 1)
        duplicate = deepcopy(r)
        duplicate["Expression"] *= 2
        with self.assertRaises(Diagnostic):
            Recipe(duplicate)
        r["Expression"] = []
        clean = Recipe(r).budgets
        self.assertEqual(clean["mana"], b["mana"])
        self.assertEqual(clean["physics"], b["physics"])
        self.assertEqual(0, clean["render"]["layers"])

    def test_sealed_catalog_and_model_records(self):
        self.assertEqual(catalog(), read(DATA / "catalog.json"))
        for path in sorted((DATA / "trials").glob("*/record.json")):
            record = read(path)
            structure(record, "TrainingRecord")
            if (path.parent / "admitted.json").exists():
                candidate = record["corrected"] or record["candidate"]
                self.assertEqual(
                    accept(record["input"], candidate)["MagicDSL"], read(path.parent / "admitted.json")
                )
                bad = deepcopy(record["input"])
                bad["SemanticAnchors"][0]["exclude"] = [bad["SemanticAnchors"][0]["mechanism"]]
                with self.assertRaises(Diagnostic):
                    accept(bad, candidate)

    def test_real_warning_window_and_direction_conflict(self):
        r = sample("recipes", "pressure_wind")
        wait = r["Processes"]["nodes"][0]
        r["Expression"].append(
            {"process": wait["id"], "cue": "active", "bind": "constant", "director": "pre_delivery_silence"}
        )
        with self.assertRaises(Diagnostic):
            Recipe(r)
        # An existing paid preparation can expire into delivery without delaying user input.
        from copy import deepcopy

        timer = deepcopy(wait)
        timer.update(
            id="windup",
            contract="prepare",
            active=[],
            on=[{"event": "timeout", "when": "always", "to": ["deliver"]}],
        )
        wait["on"][0]["to"] = ["windup"]
        r["Processes"]["nodes"].append(timer)
        r["Contracts"].append(dict(r["Contracts"][1], id="prepare", max_s=0.15))
        r["Expression"][-1]["process"] = "windup"
        Recipe(r)
        trial = sample("trials/early", "record")
        forged = deepcopy(trial["candidate"])
        actions = forged["MagicDSL"]["Processes"]["nodes"][0]["active"]
        actions.append({**actions[0], "axis": "down"})
        with self.assertRaises(Diagnostic):
            accept(trial["input"], forged)

    def test_real_adapter_single_pass_and_bounded_repair(self):
        import json

        from tools.magic_dsl_v0_3.model_trial import experiment

        trial = sample("trials/transfer", "record")
        replies = iter([trial["candidate"], trial["corrected"]])
        result, hashes = experiment(
            trial["input"], trial["prior_expectation"], lambda _: json.dumps(next(replies)), repair=True
        )
        self.assertEqual(len(hashes), 2)
        self.assertEqual(result["corrected"], trial["corrected"])
        self.assertEqual(result["diagnostics"], trial["diagnostics"])
        self.assertIsNone(result["preference"])
