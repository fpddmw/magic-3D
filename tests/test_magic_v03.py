import json
import subprocess
import sys
import unittest
from copy import deepcopy
from unittest.mock import Mock

from jsonschema import Draft202012Validator

from tools.magic_dsl_v0_3.admission import Diagnostic, Recipe, structure
from tools.magic_dsl_v0_3.altar import (
    accept,
    check_input,
    compile_at_altar,
    reading,
    reanchor,
    record_observations,
)
from tools.magic_dsl_v0_3.schema import DATA, REG, SCHEMA, TARIFF, build, read
from tools.magic_dsl_v0_3.simulate import Simulation


def recipe(key):
    return read(DATA / "recipes" / (key + ".json"))


def fixture(key):
    return read(DATA / "fixtures" / (key + ".json"))


def run(r, scene):
    return Simulation(Recipe(r), scene).run()


class Acceptance(unittest.TestCase):
    def test_portable_schema_and_all_recipes(self):
        self.assertEqual(build(), read(SCHEMA))
        Draft202012Validator.check_schema(build())
        files = sorted((DATA / "recipes").glob("*.json"))
        self.assertEqual(len(files), 10)
        for path in files:
            r = Recipe(read(path))
            self.assertTrue(reading(r))
            self.assertGreater(r.quote["upfront_mana"], 0)
        self.assertEqual(
            {a["op"] for a in REG["abilities"].values()},
            {"Establish", "Drive", "Constrain", "Transform", "Transfer", "Couple", "Withdraw"},
        )
        self.assertEqual(len(REG["runes"]), 20)

    def test_wind_partial_and_finite_shared_delivery(self):
        r = recipe("pressure_wind")
        q = Recipe(r).quote
        scene = fixture("wind")
        for seconds, fraction in ((0.1, 0), (0.3, 0.2), (1, 2 / 3), (1.8, 1)):
            s = deepcopy(scene)
            s["events"][0]["at"] = seconds
            result = run(r, s)
            self.assertAlmostEqual(result["delivered_impulse"], q["total_impulse_budget"] * fraction)
            self.assertAlmostEqual(
                result["mana_spent"], q["upfront_mana"] + min(seconds, 1.5) * q["rates"]["charge"]
            )
            self.assertNotIn("velocity", result["objects"]["behind"])
            self.assertNotIn("velocity", result["objects"]["hidden"])
            if fraction:
                near, far = (result["objects"][k]["velocity"][2] for k in ("near", "far"))
                self.assertGreater(near, far)
                self.assertAlmostEqual(near + far, result["delivered_impulse"])
        scene["caster_mana"] = q["upfront_mana"] + q["reserve_capacity"] * 0.25
        result = run(r, scene)
        self.assertAlmostEqual(result["delivered_impulse"], q["total_impulse_budget"] * 0.25)
        self.assertAlmostEqual(result["caster_mana"], 0)

    def test_interrupt_timeout_and_reference_capture(self):
        r = recipe("pressure_wind")
        s = fixture("wind")
        q = Recipe(r).quote
        for events in (
            [{"at": 1, "event": "interrupt"}, {"at": 1, "event": "release"}],
            [{"at": 2.5, "event": "release"}],
        ):
            res = run(r, {**s, "until_s": 3, "events": events})
            self.assertEqual(res["delivered_impulse"], 0)
            self.assertFalse(any(c["track"]["cue"] == "impact" for c in res["expression"]))
        s["events"].insert(0, {"at": 0.5, "event": "aim", "vector": [0, 0, -1]})
        changed = run(r, s)
        self.assertLess(changed["objects"]["behind"]["velocity"][2], 0)
        self.assertNotIn("velocity", changed["objects"]["near"])
        r["Subjects"][0]["spatial"]["reference"]["bind"] = "cast"
        self.assertGreater(run(r, s)["objects"]["near"]["velocity"][2], 0)
        self.assertEqual(run(r, {**s, "caster_mana": 0})["mana_spent"], 0)
        self.assertAlmostEqual(changed["delivered_impulse"], q["total_impulse_budget"] * 2 / 3)

    def test_repricing_never_changes_authored_threshold_or_full_impulse(self):
        src = recipe("pressure_wind")
        q1 = Recipe(src)
        cfg = deepcopy(TARIFF)
        cfg["work"]["charge"] *= 2
        q2 = Recipe(src, cfg)
        self.assertEqual(q1.quote["total_impulse_budget"], q2.quote["total_impulse_budget"])
        self.assertEqual(q1.quote["reserve_capacity"] * 2, q2.quote["reserve_capacity"])
        self.assertEqual(
            Simulation(q1, fixture("wind")).run()["delivered_impulse"],
            Simulation(q2, fixture("wind")).run()["delivered_impulse"],
        )
        for key in ("extent_m", "half_angle_deg"):
            larger = deepcopy(src)
            larger["Subjects"][0]["spatial"]["geometry"][key] *= 1.5
            self.assertGreater(Recipe(larger).quote["upfront_mana"], q1.quote["upfront_mana"])

    def test_same_runes_same_visual_three_observations(self):
        s = fixture("hall")
        out = [run(recipe(a), s) for a in ("bear_load", "attenuate", "notify")]
        self.assertEqual(out[0]["objects"]["stone"]["supported_load"], 6)
        self.assertEqual(out[1]["objects"]["window"]["transmission"], 0.25)
        self.assertTrue(out[2]["objects"]["bell"]["disturbance_detected"])
        self.assertNotIn("supported_load", out[1]["objects"]["stone"])
        self.assertEqual(out[2]["events"][-1]["receiver"], "bell")
        self.assertEqual(out[0]["expression"], out[2]["expression"])
        s["objects"][0]["load"] = 11
        broken = run(recipe("bear_load"), s)
        self.assertTrue(any(e["event"] == "overload" for e in broken["events"]))
        self.assertNotIn("supported_load", broken["objects"]["stone"])
        s["objects"][2]["disturbance"] = False
        self.assertFalse(any(e["event"] == "effect" for e in run(recipe("notify"), s)["events"]))

    def test_water_front_live_edges_and_irreversible_state(self):
        r = recipe("water_front")
        s = fixture("stream")
        frozen = lambda out: {k for k, o in out["objects"].items() if o.get("phase") == "solid"}
        self.assertEqual(frozen(run(r, s)), {"root", "fork", "left", "bridge", "tip"})
        for at in (0, 0.5):
            s["events"] = [{"at": at, "event": "cut", "ref": "fork", "other": "bridge"}]
            self.assertEqual(frozen(run(r, s)), {"root", "fork", "left"})
        s["events"] = [{"at": 0.6, "event": "interrupt"}]
        self.assertEqual(frozen(run(r, s)), {"root", "fork"})
        s["slots"].clear()
        self.assertFalse(frozen(run(r, s)))
        s = fixture("stream")
        s["objects"][0]["phase"] = "solid"
        self.assertIn("missing_binding", [e.get("reason") for e in run(r, s)["events"]])

    def test_gravity_heat_electric_and_handoff(self):
        r = recipe("gravity")
        s = fixture("hall")
        up = run(r, s)["objects"]["stone"]["velocity"][1]
        r["Processes"]["nodes"][0]["active"][0]["axis"] = "down"
        self.assertEqual(run(r, s)["objects"]["stone"]["velocity"][1], -up)
        self.assertGreater(run(recipe("heat"), s)["objects"]["stone"]["temperature_delta"], 0)
        s = fixture("copper")
        res = run(recipe("electric"), s)
        self.assertEqual(sum(e["event"] == "effect" for e in res["events"]), 2)
        self.assertNotIn("charge", res["objects"]["loose"])
        s["events"] = [{"at": 0.8, "event": "cut", "ref": "chain", "other": "gate"}]
        cut = run(recipe("electric"), s)
        self.assertAlmostEqual(cut["objects"]["gate"]["charge"] * 2, res["objects"]["gate"]["charge"])
        r = recipe("hosted_light")
        s = fixture("lamp")
        full = run(r, s)
        self.assertAlmostEqual(full["objects"]["lens"]["mana"], 0)
        self.assertFalse(full["effects"])
        s["events"] = [{"at": 0.25, "event": "unlink", "ref": "lens"}]
        early = run(r, s)
        self.assertGreater(early["objects"]["lens"]["mana"], 0)
        self.assertFalse(early["effects"])
        self.assertLess(early["mana_spent"], full["mana_spent"])
        s["events"] = [{"at": 0.1, "event": "interrupt"}]
        s["until_s"] = 0.5
        self.assertGreater(run(r, s)["objects"]["stair"]["illumination"], 0)

    def test_phase_graph_parallel_join_and_ownership(self):
        r = recipe("heat")
        nodes = r["Processes"]["nodes"]

        def n(key, successors, join="any"):
            return {
                "id": key,
                "contract": "sustain",
                "join": join,
                "enter": [],
                "active": [],
                "exit": [],
                "on": [{"event": "ready", "when": "always", "to": successors}],
            }

        nodes.extend([n("left", ["work"]), n("right", ["work"]), n("fork", ["left", "right"])])
        r["Processes"]["entry"] = ["fork"]
        nodes[0]["join"] = "all"
        out = run(r, fixture("hall"))
        self.assertEqual(
            [e.get("process") for e in out["events"] if e["event"] == "enter"],
            ["fork", "left", "right", "work"],
        )
        nodes[0]["join"] = "any"
        with self.assertRaises(Diagnostic):
            Recipe(r)
        nodes[0]["join"] = "all"
        r["Contracts"][0]["focus"] = "exclusive"
        with self.assertRaises(Diagnostic):
            Recipe(r)
        h = recipe("hosted_light")
        del h["Processes"]["nodes"][0]["on"][0]["handoff"]
        with self.assertRaises(Diagnostic):
            Recipe(h)

    def test_forged_fields_scopes_and_limits(self):
        changes = [
            ("price", lambda r: r["Contracts"][0].update(capacity_mana=500)),
            ("script", lambda r: r["Processes"]["nodes"][0]["on"][0].update(when="eval(account)")),
            ("art", lambda r: r["Expression"][0].update(visual="invented")),
            ("handle", lambda r: r["Processes"]["nodes"][1]["enter"][1].update(target="unknown")),
            ("control", lambda r: r["Processes"]["nodes"][0]["on"][0].update(to=["charge"])),
            ("type", lambda r: r["Subjects"][0]["spatial"].update(carrier="Body")),
            ("size", lambda r: r["Subjects"][0]["spatial"]["geometry"].update(extent_m=100)),
            (
                "threshold",
                lambda r: r["Processes"]["nodes"][0].update(
                    on=[{"event": "release", "when": "always", "to": ["deliver"]}]
                ),
            ),
        ]
        for key, mutate in changes:
            r = recipe("pressure_wind")
            mutate(r)
            with self.subTest(key=key), self.assertRaises(Diagnostic):
                Recipe(r)
        r = recipe("bear_load")
        r["Relations"][0]["basis"] = "nature"
        with self.assertRaises(Diagnostic):
            Recipe(r)
        r = recipe("bear_load")
        r["Subjects"][0]["properties"][0]["via"] = "field"
        with self.assertRaises(Diagnostic):
            Recipe(r)

    def test_altar_single_pass_reanchor_and_record(self):
        data = fixture("altar_input")
        candidate = fixture("altar_output")
        generate = Mock(return_value=candidate)
        accepted, record = compile_at_altar(data, generate, prior_expectation="托住落石")
        self.assertEqual(generate.call_count, 1)
        self.assertEqual(accepted["MagicDSL"], recipe("bear_load"))
        self.assertEqual(len(accepted["alternatives"]), 2)
        record_observations(record, run(accepted["MagicDSL"], fixture("hall")))
        self.assertEqual(record["observations"][0]["world_object"], "stone")
        structure(record, "TrainingRecord")
        alternate = accepted["alternatives"][0]
        second = reanchor(data, alternate)
        with self.assertRaises(Diagnostic):
            accept(second, candidate)
        candidate["MagicDSL"] = recipe(alternate["mechanism"])
        candidate["AlternativeAnchors"] = []
        model = Mock(return_value=candidate)
        self.assertIsNotNone(compile_at_altar(second, model)[0])
        model.assert_called_once()
        candidate["Interpretation"] = "所有物体都被摧毁"
        self.assertNotIn(candidate["Interpretation"], " ".join(accept(second, candidate)["reading"]))

        co = fixture("altar_output")
        alt = {
            "ref": "guard",
            "mechanism": "bear_load",
            "meaning": "由场所接手维持承载",
            "supply": "linked_reserve",
        }
        co["AlternativeAnchors"] = [alt]
        self.assertEqual(accept(data, co)["alternatives"], [alt])
        with self.assertRaises(Diagnostic):
            accept(reanchor(data, alt), co)
        alt["supply"] = "caster"
        with self.assertRaises(Diagnostic):
            accept(data, co)

    def test_bad_candidates_repair_bound_and_capabilities(self):
        data = fixture("altar_input")
        co = fixture("altar_output")
        bad = {"nonsense": True}
        gen = Mock(side_effect=[bad, co])
        good, rec = compile_at_altar(data, gen, repair=True)
        self.assertIsNotNone(good)
        self.assertEqual(gen.call_count, 2)
        self.assertEqual(rec["corrected"], co)
        structure(rec, "TrainingRecord")
        gen = Mock(return_value=bad)
        self.assertIsNone(compile_at_altar(data, gen, repair=True)[0])
        self.assertEqual(gen.call_count, 2)
        data["SupportedCapabilities"].remove("bear_load")
        with self.assertRaises(Diagnostic):
            accept(data, co)
        for rune in ["时", "生"]:
            d = fixture("altar_input")
            d["RuneGraph"]["nodes"][0]["rune"] = rune
            d["PlayerKnowledge"].append(rune)
            with self.assertRaises(Diagnostic):
                check_input(d)
        d = fixture("altar_input")
        d["RuneGraph"]["links"][0]["members"][0] = "whole"
        with self.assertRaises(Diagnostic):
            check_input(d)
        d = fixture("altar_input")
        d["RuneGraph"]["links"][0]["kind"] = "发生接续"
        with self.assertRaises(Diagnostic):
            accept(d, co)

    def test_missing_medium_and_exhausted_caster(self):
        wind = recipe("pressure_wind")
        scene = fixture("wind")
        scene["media"] = []
        result = run(wind, scene)
        self.assertEqual(result["delivered_impulse"], 0)
        self.assertIn("missing_binding", [e.get("reason") for e in result["events"]])
        ward = recipe("bear_load")
        q = Recipe(ward).quote
        scene = fixture("hall")
        scene["caster_mana"] = q["upfront_mana"] + q["rates"]["work"] * scene["until_s"]
        result = run(ward, scene)
        self.assertEqual(result["status"], "finished")
        self.assertFalse(result["effects"])

    def test_alternative_deliveries_cannot_spend_one_reserve_twice(self):
        r = recipe("pressure_wind")
        charge, delivery = r["Processes"]["nodes"]
        other = deepcopy(delivery)
        other["id"] = "reverse"
        field = deepcopy(r["Subjects"][0])
        field["id"] = "other_field"
        r["Subjects"].append(field)
        for op in other["enter"] + other["exit"]:
            op["target"] = "other_field"
        other["enter"][1]["axis"] = "down"
        r["Processes"]["nodes"].append(other)
        charge["on"].append({"event": "signal", "when": "reserve_ready", "to": ["reverse"]})
        admitted = Recipe(r)
        scene = fixture("wind")
        scene["events"][0]["event"] = "signal"
        self.assertLess(Simulation(admitted, scene).run()["objects"]["near"]["velocity"][1], 0)
        charge["on"][0]["to"].append("reverse")
        with self.assertRaises(Diagnostic):
            Recipe(r)

    def test_accepted_recipe_and_rerun_are_isolated(self):
        raw = recipe("bear_load")
        verified = Recipe(raw)
        raw["Processes"]["nodes"][0]["active"].clear()
        sim = Simulation(verified, fixture("hall"))
        first = sim.run()
        first["objects"]["stone"]["supported_load"] = 0
        self.assertEqual(sim.run()["objects"]["stone"]["supported_load"], 6)

    def test_derived_body_keeps_real_material_after_release(self):
        r = recipe("ice_body")
        scene = fixture("stream")
        scene["events"] = [{"at": 0.1, "event": "release"}]
        v = run(r, scene)
        self.assertEqual(v["status"], "finished")
        self.assertEqual(v["objects"]["root"]["phase"], "solid")
        self.assertEqual(len(scene["objects"]), len(v["objects"]))
        self.assertEqual(v["objects"]["fork"]["phase"], "liquid")
        scene["objects"][0]["mass"] = 100
        self.assertEqual(run(r, scene)["objects"]["root"]["phase"], "liquid")
        r["Processes"]["nodes"][0]["exit"][0]["target"] = "field"
        with self.assertRaises(Diagnostic):
            Recipe(r)

    def test_cli(self):
        cmd = [sys.executable, "-m", "tools.magic_dsl_v0_3"]
        r = subprocess.run(
            cmd + ["simulate", str(DATA / "recipes/pressure_wind.json"), str(DATA / "fixtures/wind.json")],
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertGreater(json.loads(r.stdout)["delivered_impulse"], 0)
        r = subprocess.run(
            cmd + ["validate", str(DATA / "fixtures/altar_input.json")],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("path", json.loads(r.stderr))
