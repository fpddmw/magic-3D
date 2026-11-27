import unittest
from copy import deepcopy

from tools.magic_compiler.compiler import compile_graph, compile_input
from tools.magic_compiler.probe import conditions_met, phase_front, reserve_delivery
from tools.magic_compiler.rules import Diagnostic, Rules, load, validate


class AetherInterventions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules = Rules()
        cls.cases = {
            c["id"]: c
            for family in ("law", "water")
            for c in load("examples/" + family + "_core_cases.json")
        }
        cls.vectors = load("tests/semantic/aether_interventions.json")["cases"]

    def declared(self, vector, claim):
        graph = deepcopy(self.cases[vector["case"]]["graph"])
        choice = next(i for n in graph for i in n.get("intents", []) if i["ref"] == vector["intent_ref"])
        choice["intervention"] = claim
        return graph

    def test_authored_and_inferred_agree(self):
        for v in self.vectors:
            raw = compile_graph(self.cases[v["case"]]["graph"])
            graph = self.declared(v, v["intervention"])
            self.assertEqual(compile_graph(graph), raw)
            p = next(p for p in raw["core"]["processes"] if p["id"] == v["process"])
            self.assertEqual(
                p["intervention"]["basis"],
                {
                    "permission": v["intervention"]["permission"],
                    "medium": "implicit",
                    "terms": v["terms"],
                    "site_conditions": v["site_conditions"],
                },
            )
            self.assertTrue(all(addr in raw["evidence"] for addr in v["terms"]))

        gravity = self.cases["L05"]["graph"]
        compiled = compile_graph(gravity)
        charge = deepcopy(compiled["core"]["processes"][0]["intervention"]["responsibility"])
        charge["conditions"].reverse()
        declared = self.declared({"case": "L05", "intent_ref": "v2"}, {"responsibility": charge})
        self.assertEqual(compile_graph(declared), compiled)

    def test_permissions_and_meaning_are_independent(self):
        v = self.vectors[0]
        for mutation in ("remove_permission", "new_meaning_required"):
            rules = Rules()
            perms = rules.world["intervention_permissions"]
            if mutation == "remove_permission":
                del perms["gravity.local_acceleration"]
            else:
                perms["gravity.local_acceleration"]["meaning_all"].append("medium_for_arcane")
            with self.subTest(mutation=mutation), self.assertRaises(Diagnostic) as err:
                compile_graph(self.declared(v, v["intervention"]), rules)
            self.assertEqual(err.exception.report["status"], "INVALID_MEANING")
            self.assertEqual(err.exception.report["permission"], "gravity.local_acceleration")

    def test_overclaims_and_unbound_sources(self):
        v = self.vectors[0]
        expected = v["intervention"]
        source = expected["responsibility"]
        for claim in [
            {"permission": "world.rewrite"},
            {"target": {"kind": "subject", "ref": "other", "facet": "content"}},
            {"mode": "赋予"},
            {"scope": {"kind": "in_region", "ref": "v9"}},
            {"responsibility": dict(source, conditions=[])},
            {
                "responsibility": dict(
                    source, source={"mode": "hosted", "provider_ref": "@vessel", "reserve_ref": "lamp"}
                )
            },
            {
                "responsibility": dict(
                    source, source={"mode": "external", "provider_ref": "@source", "relation_ref": "line"}
                )
            },
        ]:
            with self.subTest(claim=claim), self.assertRaises(Diagnostic) as err:
                compile_graph(self.declared(v, claim))
            self.assertEqual(err.exception.report["status"], "INVALID_MEANING")
        for claim in [
            {"scope": {"kind": "world", "ref": "v1"}},
            {"responsibility": dict(source, source={"mode": "active", "provider_ref": "以太"})},
            {
                "target": {
                    "kind": "active_magic",
                    "instance_ref": "@target",
                    "member_ref": "law",
                    "facet": "world_axiom",
                }
            },
        ]:
            with self.subTest(claim=claim), self.assertRaises(Diagnostic) as err:
                compile_graph(self.declared(v, claim))
            self.assertEqual(err.exception.report["status"], "INVALID_STRUCTURE")

    def test_existing_magic_requires_explicit_medium_and_a_bound_instance(self):
        v = self.vectors[0]
        for facet in self.rules.world["aether"]["active_magic_facets"]:
            claim = {
                "target": {
                    "kind": "active_magic",
                    "instance_ref": "@target",
                    "member_ref": "lift",
                    "facet": facet,
                }
            }
            graph = self.declared(v, claim)
            with self.assertRaises(Diagnostic) as err:
                compile_graph(graph)
            self.assertEqual(err.exception.report["status"], "INVALID_MEANING")
            self.assertIn("显式以太", err.exception.report["message"])
            graph[0]["words"].append("以太")
            graph[0]["operands"].append({"type": "Concept", "reads": ["concept.aether"]})
            with self.assertRaises(Diagnostic) as err:
                compile_graph(graph)
            self.assertEqual(err.exception.report["status"], "UNSUPPORTED_COMPOSITION")

    def test_observations_bind_to_the_intervened_space(self):
        gravity = compile_graph(self.cases["L05"]["graph"])["execution"]
        water = compile_graph(self.cases["M009"]["graph"])["execution"]
        scene = load("tests/semantic/paired_projections.json")["water"]["scene"]
        for plan in (gravity, water):
            plan["spatial_bindings"].clear()
        with self.assertRaises(Diagnostic):
            reserve_delivery(gravity, 1, 4)
        with self.assertRaises(Diagnostic):
            phase_front(water, scene)

    def test_water_accounts_and_ending(self):
        plan = compile_graph(self.cases["M009"]["graph"])["execution"]
        steps = {p["id"]: p for p in plan["schedule"]}
        take = steps["take"]
        self.assertEqual(take["intervention"]["scope"], {"kind": "reachable_source", "ref": "@source"})
        ready = {"来源可达": True, "来源有量": True, "施法投入可用": True}
        self.assertTrue(conditions_met(take, ready))
        for condition in ready:
            self.assertFalse(conditions_met(take, ready | {condition: False}))
        self.assertEqual(steps["freeze"]["intervention"]["responsibility"]["tenure"], "prepaid")
        hold = steps["hold"]
        self.assertEqual(hold["intervention"]["responsibility"]["tenure"], "active")
        self.assertFalse(conditions_met(hold, {"当前接触": True, "持续供给": False}))
        self.assertTrue(conditions_met(hold, {"当前接触": True, "持续供给": True}))
        stop = steps["stop"]["intervention"]
        self.assertEqual(stop["target"]["ref"], "bind")
        self.assertEqual(stop["responsibility"]["from_processes"], ["hold"])
        self.assertEqual(stop["responsibility"]["on_end"], "preserve_realized")

    def test_all_processes_and_versioned_replay(self):
        modes = set()
        self.assertEqual(
            [a["id"] for a in self.rules.world["axioms"] if a["id"].startswith("E")],
            [f"E{i}" for i in range(1, 8)],
        )
        for case in self.cases.values():
            with self.subTest(case=case["id"]):
                legacy = {"versions": case["versions"], "graph": case["graph"]}
                if case["id"] in ("M017", "M020"):
                    for doc in (legacy, case["graph"]):
                        with self.assertRaises(Diagnostic) as err:
                            compile_input(doc)
                        self.assertEqual(err.exception.report["status"], "UNSUPPORTED_MEANING")
                    continue
                current, prior = compile_input(case["graph"]), compile_input(legacy)
                self.assertEqual(prior["versions"]["construction"], "0.1.0")
                self.assertEqual(current["versions"]["construction"], "0.1.1")
                self.assertEqual(current["trace"], prior["trace"])
                self.assertEqual(current["execution"]["status"], prior["execution"]["status"])
                old_core = deepcopy(current["core"])
                for p, step in zip(old_core["processes"], current["execution"]["schedule"], strict=True):
                    i = p.pop("intervention")
                    self.assertEqual(i, step["intervention"])
                    self.assertEqual(
                        set(p["requires_all"]),
                        set(i["basis"]["site_conditions"] + i["responsibility"]["conditions"]),
                    )
                    modes.add(i["mode"])
                    self.assertTrue(set(i["basis"]["terms"]) <= current["evidence"].keys())
                    if p["effects"] == ["归属转移"]:
                        p["requires_all"].remove("施法投入可用")
                        p["condition"] = "、".join(p["requires_all"])
                    if p["effects"] in (["建立信息通路"], ["增强显明"], ["传递实际信号"]):
                        self.assertEqual(i["basis"]["medium"], "explicit")
                    if p["effects"] == ["建立有限分布"]:
                        self.assertEqual(i["basis"]["medium"], "implicit")
                self.assertEqual(old_core, prior["core"])
                with self.assertRaises(Diagnostic):
                    validate(old_core, "magic_core", "MagicCore")
                validate(prior["core"], "magic_core", "LegacyMagicCore")
        self.assertEqual(modes, {"具现", "调动", "重构", "赋予", "干涉"})
        v = self.vectors[0]
        case = self.cases[v["case"]]
        with self.assertRaises(Diagnostic) as err:
            compile_input({"versions": case["versions"], "graph": self.declared(v, v["intervention"])})
        self.assertEqual(err.exception.report["status"], "VERSION_MISMATCH")
