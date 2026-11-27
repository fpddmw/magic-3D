import unittest
from copy import deepcopy

from tools.magic_dsl_v0_3.admission import Diagnostic
from tools.magic_dsl_v0_3.aim_study import SCENE, observe
from tools.magic_dsl_v0_3.altar import accept
from tools.magic_dsl_v0_3.schema import DATA, read


class AimField(unittest.TestCase):
    def test_binding_is_the_only_edit_and_changes_the_recipient(self):
        fixed, follow = [read(DATA / f"slice/wind_{name}.json") for name in ("fixed", "follow")]
        control = deepcopy(fixed)
        control["Subjects"][0]["spatial"]["reference"]["bind"] = "live"
        self.assertEqual(control, follow)
        a, b = [observe(data, read(SCENE)) for data in (fixed, follow)]
        self.assertEqual(a[0], b[0])
        for run in (a, b):
            self.assertGreater(run[0]["probes"]["left"]["velocity_m_s"][1], 0)
            self.assertEqual(run[0]["probes"]["right"]["velocity_m_s"], [0] * 3)
            self.assertEqual(run[1]["probes"], run[2]["probes"])
            self.assertEqual(run[1]["mana_spent"], run[2]["mana_spent"])
        self.assertEqual(a[1]["mana_spent"], b[1]["mana_spent"])
        self.assertGreater(
            a[1]["probes"]["left"]["velocity_m_s"][1], a[0]["probes"]["left"]["velocity_m_s"][1]
        )
        self.assertEqual(a[1]["probes"]["right"], a[0]["probes"]["right"])
        self.assertEqual(b[1]["probes"]["left"], b[0]["probes"]["left"])
        self.assertGreater(b[1]["probes"]["right"]["velocity_m_s"][1], 0)
        inp = read(DATA / "fixtures/altar_input.json")
        inp.update(
            DSLVersion="0.3.1",
            WorldKnowledgeVersion="world-0.3.1",
            CapabilityProfile="offline-0.3.1",
            RuneGraph={"nodes": [{"id": "air", "rune": "气"}], "links": []},
            PlayerKnowledge=["气"],
            SupportedCapabilities=["form", "sustain_force", "end"],
            SemanticAnchors=[
                {
                    "ref": "air",
                    "meaning": "随瞄点",
                    "mechanism": "sustain_force",
                    "anchor": "aim_point",
                    "bind": "live",
                }
            ],
        )
        candidate = {
            "MagicDSL": follow,
            "Interpretation": "随瞄点",
            "RuneContributions": [{"node": "air", "meaning": "风场", "refs": ["flow"]}],
            "AlternativeAnchors": [],
        }
        accept(inp, candidate)
        with self.assertRaises(Diagnostic) as failure:
            accept(inp, {**candidate, "MagicDSL": fixed})
        self.assertEqual(failure.exception.report["code"], "ANCHOR_MISMATCH")
