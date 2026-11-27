import json
import unittest
from copy import deepcopy

from tools.magic_compiler.admission import admit
from tools.magic_compiler.compiler import compile_graph, compile_input
from tools.magic_compiler.probe import phase_front, reserve_delivery
from tools.magic_compiler.resolve import Resolution
from tools.magic_compiler.rules import DATA, Diagnostic, Rules, load


def patched(original, patches):
    doc = deepcopy(original)
    for patch in patches:
        parent = doc
        keys = patch["path"].strip("/").split("/")
        for key in keys[:-1]:
            parent = parent[int(key) if isinstance(parent, list) else key]
        key = keys[-1]
        if key == "-":
            parent.append(deepcopy(patch["value"]))
        elif patch["op"] == "remove":
            del parent[int(key) if isinstance(parent, list) else key]
        else:
            parent[int(key) if isinstance(parent, list) else key] = deepcopy(patch["value"])
    return doc


class Acceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules = Rules()
        cls.cases = {
            c["id"]: c
            for family in ("law", "water")
            for c in load("examples/" + family + "_core_cases.json")
        }
        cls.pair = load("tests/semantic/paired_projections.json")

    def compile(self, graph):
        return compile_graph(deepcopy(graph), self.rules)

    def test_01_gravity(self):
        fixture = self.pair["gravity"]
        base = self.cases[fixture["base_case"]]
        results = []
        for v in fixture["variants"]:
            node = patched(
                {"graph": base["graph"]},
                [{"op": "replace", "path": fixture["only_variant_input"], "value": v["input"]}],
            )
            result = self.compile(node["graph"])
            core = result["core"]
            self.assertEqual(core["subjects"][0]["spatial_intent"], fixture["common"]["space"])
            self.assertEqual(core["obligations"], base["core"]["obligations"])
            charge, burst, abort = core["processes"]
            self.assertEqual(charge["effects"], fixture["common"]["accrual"]["effects"])
            self.assertEqual(burst["direction"], v["core_direction"])
            self.assertEqual(burst["after"], [charge["id"]])
            self.assertEqual(abort["when"], "on_interrupt")
            plan = result["execution"]
            delivered = reserve_delivery(plan, 1, 4)
            op = delivered["operation"]
            self.assertEqual(op["direction"], v["execution_direction"])
            for k, value in fixture["common"]["execution"].items():
                self.assertEqual((op | plan["spatial"])[k], value)
            self.assertEqual(reserve_delivery(plan, 0.25, 4)["delivered"], 0.25)
            self.assertEqual(reserve_delivery(plan, 4, 0.5)["delivered"], 0.5)
            self.assertEqual(reserve_delivery(plan, 30, 30)["delivered"], 4)
            for args in [(1, 0), (0, 4), (1, 4, False), (1, 4, True, True)]:
                self.assertEqual(reserve_delivery(plan, *args)["delivered"], 0)
            results.append(result)
        down, up = results
        self.assertEqual(
            patched(
                down,
                [
                    {"op": "replace", "path": "/core/processes/1/direction/axis", "value": "up"},
                    {"op": "replace", "path": "/execution/schedule/1/kernel/direction/axis", "value": "UP"},
                ],
            ),
            up,
        )

    def test_02_water(self):
        fixture = self.pair["water"]
        case = self.cases[fixture["base_case"]]
        compiled = self.compile(case["graph"])
        core = compiled["core"]
        self.assertEqual(core["subjects"][0]["spatial_intent"], fixture["common"]["space"])
        freeze = next(p for p in core["processes"] if "propagation" in p)
        self.assertEqual({k: freeze[k] for k in fixture["common"]["freeze"]}, fixture["common"]["freeze"])
        plan = compiled["execution"]
        kernel = next(s["kernel"] for s in plan["schedule"] if "traversal" in s)
        for k, v in fixture["common"]["execution"].items():
            self.assertEqual((plan["spatial"] | kernel["propagation"])[k], v)
        self.assertTrue(fixture["scene"]["test_budget"].items() <= kernel["propagation"].items())
        for v in fixture["variants"]:
            scene = patched(
                {"scene": fixture["scene"]},
                [{"op": "replace", "path": fixture["only_variant_input"], "value": v["input"]}],
            )["scene"]
            self.assertEqual(self.compile(case["graph"]), compiled)
            result = phase_front(plan, scene)
            self.assertEqual(result["frozen"], sorted(v["frozen"]))
            self.assertEqual(result["liquid"], sorted(v["liquid"]))
        for changed in ({"completed": []}, {"reserve_available": False}):
            self.assertEqual(phase_front(plan, fixture["scene"] | changed)["frozen"], [])
        for edge in fixture["edge_cases"]:
            scene = deepcopy(fixture["scene"])
            if edge["change"] == "remove_origin":
                scene["origin_binding"].clear()
            if edge["change"] == "interrupt_before_release":
                scene["at"] = "on_interrupt"
            result = phase_front(plan, scene, edge if "edge_index" in edge else None)
            self.assertEqual(result["frozen"], sorted(edge["frozen"]))
            if "expected_status" in edge:
                self.assertEqual(result["status"], edge["expected_status"])
                self.assertEqual(result["policy"], "ABORT_NO_COST")
            if "expected_operation" in edge:
                self.assertIn(edge["expected_operation"], result["operations"])

    def test_03_unseen_strand(self):
        doc = load("tests/semantic/heldout_strand.json")
        result = compile_input(doc)
        plan = result["execution"]
        self.assertEqual(plan["spatial"]["generator"], "LINE_SEGMENT")
        self.assertEqual(result["core"]["subjects"][0]["source"], "Borrow")
        self.assertEqual({r["id"] for r in result["core"]["relations"]}, {"lift", "support"})
        self.assertEqual(
            {p["id"] for p in plan["schedule"]}, {"take", "weave", "freeze", "stop_lift", "drop_lift"}
        )
        scene = {
            "at": "on_release",
            "origin_binding": {"support_contact": "start"},
            "completed": ["take", "weave"],
            "reserve_available": True,
            "liquid_parts": ["start", "middle", "end", "puddle"],
            "observe_at_s": 2,
            "edges": [
                {
                    "a": "start",
                    "b": "middle",
                    "kind": "material_continuity",
                    "state": "intact",
                    "length_m": 1,
                },
                {
                    "a": "middle",
                    "b": "end",
                    "kind": "material_continuity",
                    "state": "intact",
                    "length_m": 1,
                },
                {"a": "end", "b": "puddle", "kind": "geometric_contact", "state": "intact", "length_m": 1},
            ],
        }
        self.assertEqual(phase_front(plan, scene)["frozen"], ["end", "middle", "start"])
        scene["edges"][1]["state"] = "broken"
        self.assertEqual(phase_front(plan, scene)["frozen"], ["middle", "start"])
        reordered = deepcopy(doc)
        reordered["graph"].reverse()
        for node in reordered["graph"]:
            node["scope"] = "此段说明不参与编译"
        self.assertEqual(compile_input(reordered), result)

    def test_reference_cores_and_traces(self):
        for case in self.cases.values():
            with self.subTest(case=case["id"]):
                if case["id"] in ("M017", "M020"):
                    with self.assertRaises(Diagnostic) as ctx:
                        self.compile(case["graph"])
                    self.assertEqual(ctx.exception.report["status"], "UNSUPPORTED_MEANING")
                    continue
                # Each hand-authored oracle specifies the edition of its expected Core.
                result = compile_input({"versions": case["versions"], "graph": case["graph"]})
                actual = result["core"]
                expected = case["core"]
                # Compare identities via the objects they represent. Display IDs and prose are editorial.
                rename = {"subject": expected["subjects"][0]["id"]}
                for c in actual["concepts"]:
                    rename[c["id"]] = next(
                        x["id"] for x in expected["concepts"] if x["concept"] == c["concept"]
                    )
                for r in actual["relations"]:
                    matches = [
                        x
                        for x in expected["relations"]
                        if [x["from"], x["to"], x["channel"]]
                        == [rename.get(r["from"], r["from"]), rename.get(r["to"], r["to"]), r["channel"]]
                    ]
                    rename[r["id"]] = next(
                        x["id"] for x in matches if len(matches) == 1 or x["id"] == r["id"]
                    )
                for p in actual["processes"]:
                    candidates = [
                        x
                        for x in expected["processes"]
                        if (x["operation"], x["when"], x["effects"], x["target"])
                        == (p["operation"], p["when"], p["effects"], rename.get(p["target"], p["target"]))
                    ]
                    self.assertEqual(len(candidates), 1, p)
                    rename[p["id"]] = candidates[0]["id"]
                self.assertEqual(
                    [len(actual[k]) for k in ("concepts", "subjects", "relations", "processes")],
                    [len(expected[k]) for k in ("concepts", "subjects", "relations", "processes")],
                )
                for p in actual["processes"]:
                    want = next(x for x in expected["processes"] if x["id"] == rename[p["id"]])
                    self.assertEqual([rename[a] for a in p["after"]], want["after"])
                    for k in ("requires_all", "intent_ref", "direction", "propagation", "profile"):
                        self.assertEqual(p.get(k), want.get(k), (p["id"], k))
                for k in ("formation", "owner", "control", "supply"):
                    self.assertEqual(actual["contract"][k], expected["contract"][k])
                self.assertEqual(actual["obligations"], expected["obligations"])
                for a, e in zip(actual["subjects"], expected["subjects"]):
                    for k in ("source", "source_ref", "spatial_intent", "intent_ref"):
                        self.assertEqual(a[k], e[k])
                    self.assertEqual(rename[a["concept_ref"]], e["concept_ref"])
                expected_trace = {s["node"]: s for s in case["trace"]}
                for step in result["trace"]:
                    want = expected_trace[step["node"]]
                    self.assertEqual(step["senses"], want["senses"])
                    self.assertEqual(step["rule_id"], want["rule_id"])
                    self.assertEqual({rename[o] for o in step["outputs"]}, set(want["outputs"]))

    def test_first_batch(self):
        covered = set()
        for case in self.cases.values():
            if case["id"] not in ("M017", "M020"):
                res = Resolution(case["graph"], self.rules)
                covered.update(t["sense"] for t in res.terms.values())
        for w in load("tests/semantic/operand_witnesses.json")["witnesses"]:
            with self.subTest(word=w["word"], result=w["expected_status"]):
                graph = []
                for j, term in enumerate(w.get("prior", []) + [w], 1):
                    node = {
                        "id": f"n{j}",
                        "inputs": [n["id"] for n in graph],
                        "scope": "对象",
                        "form": "构成",
                        "words": [term["word"]],
                        "operands": [{k: term[k] for k in ("type", "reads")}],
                    }
                    if "aspect_ref" in term:
                        node["aspect_ref"] = term["aspect_ref"]
                    graph.append(node)
                if w["expected_status"] != "VALID":
                    with self.assertRaises(Diagnostic) as ctx:
                        Resolution(graph, self.rules)
                    self.assertEqual(ctx.exception.report["status"], w["expected_status"])
                    self.assertEqual(set(ctx.exception.report.get("candidates", [])), set(w["expected"]))
                else:
                    resolved = Resolution(graph, self.rules).terms[f"n{len(graph)}:0"]
                    self.assertEqual([resolved["sense"]], w["expected"])
                    self.assertFalse(set(w.get("forbid_grants", [])).intersection(resolved["grant"]))
                    self.assertTrue(set(w.get("defer", [])) <= set(resolved["at_use"]))
                    covered.add(resolved["sense"])
        # Some licensed words first appear in a later, currently unimplemented whole construction.
        for case in self.cases.values():
            for j, node in enumerate(case["graph"]):
                try:
                    prefix = Resolution(case["graph"][: j + 1], self.rules)
                except Diagnostic:
                    break
                covered.update(t["sense"] for t in prefix.terms.values())
        trigger = Resolution(
            [
                {
                    "id": "n1",
                    "form": "阶段",
                    "scope": "已付费载荷受压交付",
                    "inputs": [],
                    "words": ["回应"],
                    "operands": [{"type": "Relation", "reads": ["reference.pressure", "contract.payload"]}],
                }
            ],
            self.rules,
        )
        covered.add(trigger.terms["n1:0"]["sense"])
        vocabulary = {s["id"] for senses in self.rules.senses.values() for s in senses if "match" in s}
        self.assertEqual(covered, vocabulary)

    def test_legacy_regression(self):
        for path in (DATA / "spells").glob("*.json"):
            with self.subTest(path=path.name):
                admit(load(path), self.rules)
        admit(load("intents/sample_intent_water_weave_freeze.json"), self.rules, "intent")
        patches = load("tests/execution_mutations.json")
        vectors = load("tests/validator_negative_vectors.json")["vectors"]
        self.assertEqual(set(patches), {v["id"] for v in vectors})
        for v in vectors:
            with self.subTest(vector=v["id"]):
                sample = load(v["base_file"].removeprefix("game/data/"))
                changed = patched(sample, patches[v["id"]])
                with self.assertRaises(Diagnostic) as ctx:
                    admit(changed, self.rules, v["target_kind"])
                self.assertEqual(ctx.exception.report["status"], v["expected_stage"])

    def test_reference_scope_and_failures(self):
        base = self.cases["L05"]["graph"]
        for patch in [
            [{"op": "replace", "path": "/1/id", "value": "n1"}],
            [{"op": "replace", "path": "/0/inputs", "value": ["n3"]}],
            [{"op": "replace", "path": "/1/inputs", "value": ["n12"]}],
            [{"op": "replace", "path": "/2/operands/0/reads", "value": ["contract.reserve"]}],
            [{"op": "replace", "path": "/2/aspect_ref", "value": "fire.heat"}],
            [{"op": "replace", "path": "/2/form", "value": "构成"}],
            [{"op": "replace", "path": "/1/intents/0/ref", "value": "v1"}],
            [{"op": "replace", "path": "/2/inputs", "value": ["n1"]}],
            [{"op": "remove", "path": "/1/operands"}],
        ]:
            with self.subTest(patch=patch), self.assertRaises(Diagnostic):
                self.compile(patched(base, patch))
        water = self.cases["M009"]["graph"]
        for key in ("contract.reserve", "contract.sustain"):
            graph = deepcopy(water)
            for node in graph:
                for term in node["operands"]:
                    if key in term.get("reads", []):
                        term["reads"].remove(key)
            with self.subTest(key=key), self.assertRaises(Diagnostic):
                self.compile(graph)
        for patch in [
            [{"op": "replace", "path": "/4/operands/0/subject", "value": "v9"}],
            [{"op": "replace", "path": "/4/intents/0/material", "value": "v2"}],
        ]:
            with self.assertRaises(Diagnostic):
                self.compile(patched(water, patch))
        graph = deepcopy(self.cases["L01"]["graph"])
        graph[1].pop("aspect_ref")
        graph[1]["operands"][1]["reads"].remove("aspect.fire.visibility")
        with self.assertRaises(Diagnostic) as err:
            self.compile(graph)
        self.assertEqual(err.exception.report["status"], "AMBIGUOUS")
        self.assertEqual(set(err.exception.report["candidates"]), {"fire.heat", "fire.visibility"})
        for doc in [self.cases["L05"], {"versions": {"core": "latest"}, "graph": base}]:
            with self.assertRaises(Diagnostic):
                compile_input(doc)

    def test_semantic_vectors(self):
        from tools.magic_compiler.probe import check_at_use

        vectors = {v["id"]: v for v in load("tests/semantic/meaning_vectors.json")["vectors"]}

        def evidence(*nodes):
            graph = []
            for index, (words, operands) in enumerate(nodes, 1):
                graph.append(
                    {
                        "id": f"n{index}",
                        "scope": "词义验证",
                        "form": "共同限定",
                        "inputs": [n["id"] for n in graph],
                        "words": words,
                        "operands": [{"type": k, "reads": v} for k, v in operands],
                    }
                )
            return Resolution(graph, self.rules).terms

        def senses(terms):
            return {v["sense"] for v in terms.values()}

        for key in ("S01", "S04", "S06", "S07", "S11", "S12", "S19"):
            v = vectors[key]
            result = self.compile(self.cases[v["base"]]["graph"])
            self.assertTrue(set(v["candidate_senses"]) <= senses(result["evidence"]), key)
            if key == "S01":
                self.assertIn(
                    "真实扰动",
                    next(p for p in result["core"]["processes"] if p["when"] == "on_signal")[
                        "requires_all"
                    ],
                )
            if key in ("S06", "S07", "S11"):
                self.assertIn(
                    result["execution"]["subject"]["field_channel"],
                    {"S06": {"HEAT_EXTRACTION"}, "S07": {"LIGHT_EMISSION"}, "S11": {"LIGHT_ATTENUATION"}}[
                        key
                    ],
                )
            if key == "S12":
                term = next(a for a, t in result["evidence"].items() if t["sense"] == "牵引.拉动")
                observations = {
                    "actual_contact": True,
                    "connected_material": True,
                    "supply_available": True,
                }
                self.assertEqual(check_at_use(result, term, observations)["status"], "BOUND")
                observations["actual_contact"] = False
                self.assertEqual(check_at_use(result, term, observations)["missing"], ["actual_contact"])
            if key == "S19":
                scene = dict(self.pair["water"]["scene"], at="on_interrupt")
                self.assertEqual(phase_front(result["execution"], scene)["frozen"], [])
        joined = evidence((["联结"], [("Relation", ["reference.feed"])]))
        self.assertEqual(senses(joined), set(vectors["S02"]["candidate_senses"]))
        cold = (["水", "凝固"], [("Concept", ["concept.water"]), ("Concept", ["n1:0"])])
        extended = (["延展"], [("Entity", ["n1:1", "reference.axis"])])
        woven = evidence(cold, extended, (["交织"], [("Entity", ["n2:0", "choice.strands"])]))
        self.assertTrue(set(vectors["S03"]["candidate_senses"]) <= senses(woven))
        self.assertIn("contact_weld", woven["n3:0"]["exclude"])  # S08
        self.assertFalse(any("solidified" in t["grant"] for t in woven.values()))
        solid = evidence(
            cold, (["凝聚", "延展"], [("Entity", ["n1:1"]), ("Entity", ["n1:1", "reference.axis"])])
        )
        self.assertTrue(set(vectors["S05"]["candidate_senses"]) <= senses(solid))
        self.assertFalse(any("propulsion" in t["grant"] for t in solid.values()))
        for word, op in [
            ("穿透", ("Process", ["contract.drive", "choice.boundary"])),
            ("凝聚", ("Process", ["concept.gravity", "contract.sustain"])),
        ]:
            with self.assertRaises(Diagnostic) as err:
                evidence(([word], [op]))
            self.assertEqual(err.exception.report["status"], "INVALID_MEANING")  # S09, S13
        # S10 explicitly enumerates the two missing aspect choices in the scope regression above.
        dark = self.compile(self.cases["L02"]["graph"])
        self.assertIn("spontaneous_reset", dark["evidence"]["n3:0"]["exclude"])  # S14
        direction = load("tests/semantic/operand_witnesses.json")["witnesses"][2]
        reversed_direction = evidence((["重力"], [("Concept", ["concept.gravity"])]))
        self.assertIn("directional_law", reversed_direction["n1:0"]["grant"])
        candidates = self.rules.senses[direction["word"]]
        self.assertIn(
            "history_rewrite", next(s for s in candidates if s["id"] == "反转.方向")["match"]["exclude"]
        )  # S15
        rope = self.compile(self.cases["M003"]["graph"])
        self.assertEqual(
            check_at_use(rope, "n2:0", {"source_reachable": True}),
            {"status": "MISSING_BINDING", "missing": ["source_nonempty"]},
        )  # S17
        fog = self.compile(self.cases["M014"]["graph"])
        self.assertFalse(any(r["channel"] == "信息" for r in fog["core"]["relations"]))  # S18
        self.assertFalse(any("signal_route" in t["grant"] for t in fog["evidence"].values()))

    def test_admission_preserves_meaning(self):
        from copy import copy

        profile = copy(self.rules)
        profile.execution = deepcopy(self.rules.execution)
        profile.execution["capability_matrix"]["field_x_carrier"]["GRAVITY|REGION"] = "PLANNED"
        refused = compile_graph(self.cases["L05"]["graph"], profile)
        self.assertEqual(refused["execution"]["status"], "UNSUPPORTED_LOWERING")
        self.assertEqual(refused["core"], self.compile(self.cases["L05"]["graph"])["core"])
        profile.execution["capability_matrix"]["field_x_carrier"]["GRAVITY|REGION"] = "SUPPORTED"
        profile.execution["hard_limits"]["max_upfront_mana"] = 0.1
        self.assertEqual(
            compile_graph(self.cases["L05"]["graph"], profile)["execution"]["status"], "BUDGET_EXCEEDED"
        )

    def test_layout_cannot_erase_an_upstream_meaning(self):
        graph = deepcopy(self.cases["M009"]["graph"])
        graph[2]["intents"][0]["space"]["organization"] = "continuous_strand"
        with self.assertRaises(Diagnostic) as ctx:
            self.compile(graph)
        self.assertEqual(ctx.exception.report.get("fact"), "interlaced")

    def test_cli(self):
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        args = [sys.executable, "-m", "tools.magic_compiler"]
        heldout = DATA / "tests/semantic/heldout_strand.json"
        run = subprocess.run(args + ["compile", str(heldout)], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(run.stdout), compile_input(json.loads(heldout.read_text())))
        run = subprocess.run(
            args + ["compile"],
            input=json.dumps(self.cases["L03"]["graph"]),
            capture_output=True,
            text=True,
            check=True,
        )
        compiled = json.loads(run.stdout)["execution"]["compiled_spell"]
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / "program.json"
            file.write_text(json.dumps(compiled))
            accept = subprocess.run(
                args + ["check-spell", str(file)], capture_output=True, text=True, check=True
            )
            self.assertEqual(json.loads(accept.stdout)["status"], "VALID")
        for invalid in ['{"graph":[],"graph":[]}', "[NaN]", json.dumps(self.cases["L05"])]:
            run = subprocess.run(
                args + ["compile"], input=invalid, capture_output=True, text=True, check=False
            )
            self.assertNotEqual(run.returncode, 0)
            self.assertFalse(run.stdout)
            self.assertIn("status", json.loads(run.stderr))

    def test_version_replay_and_isolation(self):
        graph = self.cases["L05"]["graph"]
        first = self.compile(graph)
        expected = deepcopy(first)
        first["core"]["processes"][1]["effects"].clear()
        first["execution"]["schedule"][1]["kernel"]["direction"].clear()
        self.assertEqual(self.compile(graph), expected)
        self.assertEqual(compile_input({"graph": graph, "versions": first["versions"]}), expected)
        with self.assertRaises(Diagnostic):
            compile_input({"graph": graph, "versions": dict(first["versions"], construction="99.0")})
