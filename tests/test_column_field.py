"""v0.3.1 offline acceptance: one paid operation, three settings, a moving shared scene."""

import unittest
from copy import deepcopy
from math import hypot

from tools.magic_dsl_v0_3.admission import Diagnostic, Recipe
from tools.magic_dsl_v0_3.altar import accept, reading
from tools.magic_dsl_v0_3.field_comparison import STUDY, cases, comparison
from tools.magic_dsl_v0_3.schema import DATA, REG, read
from tools.magic_dsl_v0_3.simulate import Simulation


def active(data):
    return data["Processes"]["nodes"][0]["active"][0]


class ColumnField(unittest.TestCase):
    def setUp(self):
        self.recipe = read(STUDY / "recipe.json")
        self.scene = read(STUDY / "scene.json")

    def run_until(self, end):
        return Simulation(Recipe(self.recipe), {**self.scene, "until_s": end}).run()

    def assert_vector(self, actual, expected):
        for value, reference in zip(actual, expected, strict=True):
            self.assertAlmostEqual(value, reference, places=8)

    def test_single_edit_and_three_ledgers(self):
        seen = list(cases(self.recipe))
        for _, override, r in seen:
            restored = deepcopy(r.data)
            for key in override:
                active(restored)["field_vector"][key] = active(self.recipe)["field_vector"][key]
            self.assertEqual(restored, self.recipe)
            self.assertEqual(r.budgets, seen[0][2].budgets)
            readout = "\n".join(reading(r))
            self.assertIn("柱域半径 3 米、高 4 米", readout)
            self.assertIn("切向", readout)
            self.assertIn("共享最多 4 牛顿", readout)
        self.assertEqual([v for _, v, _ in seen], [{}, {"axial": 0}, {"tangential": -0.64}])
        budgets = seen[0][2].budgets
        self.assertEqual(budgets["physics"]["field_target_checks_per_step"], 16)
        self.assertEqual(budgets["physics"]["sustained_force_ceiling_n"], 4)
        self.assertEqual(budgets["render"], {"layers": 0, "tracks": 0})
        for dimension in ("radius_m", "height_m"):
            bigger = deepcopy(self.recipe)
            bigger["Subjects"][0]["spatial"]["geometry"][dimension] += 1
            self.assertGreater(Recipe(bigger).quote["mana_per_s"], budgets["mana"]["mana_per_s"])

    def test_field_samples_and_free_motion(self):
        report = comparison()
        self.assertEqual(report, read(DATA.parents[2] / "docs/v0.3.1/column_field_observations.json"))
        for baseline, flat, backwards in zip(*(v["samples"] for v in report.values()), strict=True):
            self.assertEqual(baseline["mana_spent"], flat["mana_spent"])
            self.assertEqual(baseline["mana_spent"], backwards["mana_spent"])
            self.assertLessEqual(baseline["sum_impulse_magnitudes_ns"], 4 * min(baseline["at_s"], 1))
            for probe in ("east", "west", "axis_probe"):
                for field in ("velocity_m_s", "position_m"):
                    x, y, z = baseline["probes"][probe][field]
                    self.assert_vector(backwards["probes"][probe][field], [x, y, -z])
                    self.assert_vector(
                        flat["probes"][probe][field], [x, 0 if field == "velocity_m_s" else 1, z]
                    )
            vx, vy, vz = baseline["probes"]["east"]["velocity_m_s"]
            self.assertLess(vx, 0)
            self.assertGreater(vy, 0)
            self.assertLess(vz, 0)
            self.assert_vector(baseline["probes"]["west"]["velocity_m_s"], [-vx, vy, -vz])
        for variant in report.values():
            mid, stop, coast = variant["samples"]
            self.assertEqual([p["status"] for p in (mid, stop, coast)], ["active", "finished", "finished"])
            self.assertEqual(stop["sum_impulse_magnitudes_ns"], coast["sum_impulse_magnitudes_ns"])
            self.assertEqual(stop["mana_spent"], coast["mana_spent"])
            for obj in self.scene["objects"]:
                k = obj["id"]
                v = stop["probes"][k]["velocity_m_s"]
                p = stop["probes"][k]["position_m"]
                self.assert_vector(coast["probes"][k]["velocity_m_s"], v)
                self.assert_vector(coast["probes"][k]["position_m"], [a + 0.5 * b for a, b in zip(p, v)])
                if k in ("outside", "above", "below", "occluded"):
                    self.assert_vector(v, [0, 0, 0])
                    self.assert_vector(p, obj["position"])

    def test_one_step_budget_mass_and_axis(self):
        dt = 1 / REG["offline_motion_hz"]
        self.scene["objects"][1]["mass"] = 2
        result = self.run_until(dt)
        east = result["objects"]["east"]["velocity"]
        west = result["objects"]["west"]["velocity"]
        # East/west each weigh 9/16, centre weighs 1. Norm of the non-axial direction at the centre is zero.
        impulse = 4 * dt * 9 / 34
        self.assert_vector(east, [impulse * v for v in [-0.48, 0.60, -0.64]])
        self.assert_vector(west, [-east[0] / 2, east[1] / 2, -east[2] / 2])
        self.assert_vector(result["objects"]["axis_probe"]["velocity"], [0, 4 * dt * 16 / 34 * 0.60, 0])
        self.assertAlmostEqual(
            result["delivered_impulse"],
            sum(o["mass"] * hypot(*o.get("velocity", [0, 0, 0])) for o in result["objects"].values()),
        )

    def test_both_spatial_profiles_and_cylinder_caps(self):
        dt = 1 / REG["offline_motion_hz"]
        space = self.recipe["Subjects"][0]["spatial"]
        self.scene["objects"] = [{"id": "high", "mass": 1, "position": [2.7, 3.6, 0]}]
        space["distribution"] = {"radial": "linear_falloff", "axial": "linear_falloff"}
        self.assertAlmostEqual(self.run_until(dt)["delivered_impulse"], 4 * dt * 0.1 * 0.1)
        space["distribution"] = "uniform"
        self.assertAlmostEqual(self.run_until(dt)["delivered_impulse"], 4 * dt)
        self.scene["objects"][0]["position"] = [3, 4, 0]
        self.assertAlmostEqual(self.run_until(dt)["delivered_impulse"], 4 * dt)
        self.scene["objects"][0]["position"] = [3.01, 4, 0]
        self.assertEqual(self.run_until(dt)["delivered_impulse"], 0)

    def test_semantic_rejections_and_version_fence(self):
        for key, value in [
            ("field_vector", {"radial": 0, "tangential": 0, "axial": 0}),
            ("field_vector", {"radial": 1, "tangential": 1, "axial": 0}),
            ("field_vector", {"radial": 0.4, "tangential": 0}),
            ("axis", "up"),
        ]:
            bad = deepcopy(self.recipe)
            active(bad)[key] = value
            with self.assertRaises(Diagnostic):
                Recipe(bad)
        for geometry in [
            {"shape": "column", "radius_m": 0, "height_m": 4},
            {"shape": "column", "radius_m": 3, "height_m": 31},
            {"shape": "sphere", "extent_m": 3},
        ]:
            bad = deepcopy(self.recipe)
            bad["Subjects"][0]["spatial"]["geometry"] = geometry
            with self.assertRaises(Diagnostic):
                Recipe(bad)
        wrong = deepcopy(self.recipe)
        wrong["Concepts"][0]["nature"] = "gravity"
        del wrong["Subjects"][0]["medium"]
        with self.assertRaises(Diagnostic):
            Recipe(wrong)
        with self.assertRaises(Diagnostic):
            Recipe({**self.recipe, "version": "0.3.0"})
        old_input = read(DATA / "fixtures/altar_input.json")
        candidate = read(DATA / "fixtures/altar_output.json")
        self.assertEqual(accept(old_input, candidate)["profile"], "offline-0.3.0")
        candidate["MagicDSL"]["version"] = "0.3.1"
        with self.assertRaises(Diagnostic):
            accept(old_input, candidate)

    def test_altar_checks_the_requested_lift(self):
        inputs = read(DATA / "fixtures/altar_input.json")
        inputs.update(
            DSLVersion="0.3.1",
            CapabilityProfile="offline-0.3.1",
            WorldKnowledgeVersion="world-0.3.1",
            RuneGraph={"nodes": [{"id": "air", "rune": "气"}], "links": []},
            SupportedCapabilities=["form", "sustain_force", "end"],
            PlayerKnowledge=["气"],
            SemanticAnchors=[
                {"ref": "air", "meaning": "上升气流", "mechanism": "sustain_force", "axis": "up"}
            ],
        )
        candidate = {
            "MagicDSL": self.recipe,
            "Interpretation": "持续上升的气流",
            "RuneContributions": [{"node": "air", "meaning": "气压作用", "refs": ["flow"]}],
            "AlternativeAnchors": [],
        }
        self.assertEqual(accept(inputs, candidate)["profile"], "offline-0.3.1")
        for axial in (0, -0.60):
            active(self.recipe)["field_vector"]["axial"] = axial
            with self.assertRaises(Diagnostic) as error:
                accept(inputs, candidate)
            self.assertEqual(error.exception.report["code"], "ANCHOR_MISMATCH")

    def test_supply_interrupt_and_no_air(self):
        self.scene["media"] = []
        missing = self.run_until(1)
        self.assertEqual(missing["delivered_impulse"], 0)
        self.assertIn("missing_binding", [e.get("reason") for e in missing["events"]])
        self.scene["media"] = ["ambient_air"]
        price = Recipe(self.recipe).quote
        self.scene["caster_mana"] = price["upfront_mana"] + 0.25 * price["mana_per_s"]
        limited = self.run_until(1)
        self.assertAlmostEqual(limited["mana_spent"], self.scene["caster_mana"])
        self.assertLessEqual(limited["delivered_impulse"], 4 * 0.25)
        self.scene["caster_mana"] = 100
        self.scene["events"] = [{"at": 0.25, "event": "interrupt"}]
        cut = self.run_until(1)
        self.assertAlmostEqual(limited["delivered_impulse"], cut["delivered_impulse"])
        self.assert_vector(limited["objects"]["east"]["position"], cut["objects"]["east"]["position"])
