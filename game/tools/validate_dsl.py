#!/usr/bin/env python3
"""
Magic DSL v0.2.1 4-Stage Offline Validator & Self-Test Suite.

Zero external dependencies (Python 3 stdlib only).
Stages:
  1. Structure Validation (Draft 2020-12 JSON Schema enforcement)
  2. Semantic Reference & Process Graph Validation
  3. Capability Matrix & Limited-Condition Contract Validation
  4. Independent Budget Floor & ArtKit Registry Verification (ignores forged compiler_status)

Usage:
  python3 game/tools/validate_dsl.py --self-test
  python3 game/tools/validate_dsl.py game/data/spells/case1_water_weave_freeze.json
  python3 game/tools/validate_dsl.py --intent game/data/intents/sample_intent_water_weave_freeze.json --spell game/data/spells/case1_water_weave_freeze.json
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Any


ROOT_DIR = pathlib.Path(__file__).resolve().parents[1]
SCHEMA_DIR = ROOT_DIR / "data" / "schema"
SPELLS_DIR = ROOT_DIR / "data" / "spells"
INTENTS_DIR = ROOT_DIR / "data" / "intents"

DSL_SCHEMA_PATH = SCHEMA_DIR / "magic_dsl_v0_2.schema.json"
INTENT_SCHEMA_PATH = SCHEMA_DIR / "semantic_intent_v0_2.schema.json"

VALID_CASTER_REFS = {
    "CASTER:BODY",
    "CASTER:HAND",
    "CASTER:MANA",
    "CASTER:RESERVE",
}
VALID_TARGET_REFS = {
    "TARGET:ANCHOR",
    "TARGET:SURFACE",
    "TARGET:ACTOR",
}
VALID_ENV_REFS = {
    "ENV:WATER",
    "ENV:MOISTURE",
    "ENV:STONE",
    "ENV:HEAT",
    "ENV:CONDUCTOR",
}

# Mirrors game/scripts/dsl/magic_capability_matrix.gd (v0.2.1)
MATERIAL_CARRIER_MATRIX: dict[tuple[str, str], str] = {
    ("WATER", "BODY"): "SUPPORTED",
    ("WATER", "PATH_GRAPH"): "SUPPORTED",
    ("WATER", "SURFACE"): "PLANNED",
    ("WATER", "REGION"): "LIMITED",
    ("ICE", "BODY"): "SUPPORTED",
    ("ICE", "PATH_GRAPH"): "LIMITED",
    ("ICE", "SURFACE"): "SUPPORTED",
    ("ICE", "REGION"): "PLANNED",
    ("FOG", "BODY"): "PLANNED",
    ("FOG", "PATH_GRAPH"): "LIMITED",
    ("FOG", "SURFACE"): "PLANNED",
    ("FOG", "REGION"): "SUPPORTED",
    ("LIGHTNING_PLASMA", "BODY"): "PLANNED",
    ("LIGHTNING_PLASMA", "PATH_GRAPH"): "SUPPORTED",
    ("LIGHTNING_PLASMA", "SURFACE"): "PLANNED",
    ("LIGHTNING_PLASMA", "REGION"): "LIMITED",
    ("FLAME", "BODY"): "LIMITED",
    ("FLAME", "PATH_GRAPH"): "PLANNED",
    ("FLAME", "SURFACE"): "PLANNED",
    ("FLAME", "REGION"): "LIMITED",
    ("STONE", "BODY"): "SUPPORTED",
    ("STONE", "PATH_GRAPH"): "PLANNED",
    ("STONE", "SURFACE"): "LIMITED",
    ("STONE", "REGION"): "PLANNED",
    ("METAL", "BODY"): "SUPPORTED",
    ("METAL", "PATH_GRAPH"): "PLANNED",
    ("METAL", "SURFACE"): "LIMITED",
    ("METAL", "REGION"): "PLANNED",
    ("ASH", "REGION"): "LIMITED",
    ("VITAL_SPORE", "REGION"): "PLANNED",
}

FIELD_CARRIER_MATRIX: dict[tuple[str, str], str] = {
    ("GRAVITY", "REGION"): "SUPPORTED",
    ("HEAT_EXTRACTION", "REGION"): "SUPPORTED",
    ("HEAT_INJECTION", "REGION"): "SUPPORTED",
    ("LIGHT_EMISSION", "REGION"): "SUPPORTED",
    ("LIGHT_ATTENUATION", "REGION"): "SUPPORTED",
    ("WIND_FORCE", "REGION"): "SUPPORTED",
    ("ELECTRIC_POTENTIAL", "REGION"): "SUPPORTED",
    ("ELECTRIC_POTENTIAL", "PATH_GRAPH"): "LIMITED",
    ("SPATIAL_BARRIER", "SURFACE"): "SUPPORTED",
    ("SPATIAL_BARRIER", "REGION"): "PLANNED",
    ("LOCAL_TIME_RATE", "REGION"): "PLANNED",
    ("VITAL_FLUX", "REGION"): "PLANNED",
}

ARTKIT_REGISTRY = {
    "contour_module": {
        "SCULPTED_CORE",
        "FACETED_PRISM",
        "CONTINUOUS_RIBBON",
        "BRANCH_TENDRIL",
        "PLANAR_SIGIL",
        "VOLUMETRIC_MIST",
        "FIELD_AURA_RING",
    },
    "surface_modules": {
        "REFRACTIVE_LIQUID",
        "CRYSTALLINE_ICE",
        "ROUGH_STONE",
        "CONDUCTIVE_ARC",
        "GRAVITY_DISTORTION",
        "LIGHT_ABSORB_VOID",
        "THERMAL_FROST",
        "THERMAL_EMBER",
        "RUNIC_BARRIER_GLASS",
    },
    "secondary_modules": {
        "VELOCITY_FOAM",
        "STRESS_CRACKS",
        "FROST_CREEP_DECAL",
        "CRATER_DECAL",
        "SCORCH_DECAL",
        "FLOATING_DUST",
        "ARC_SPARKS",
        "SONAR_RIPPLES",
    },
    "drone_module": {
        "NONE",
        "CRYSTALLINE_HUM",
        "SUB_VOID_RUMBLE",
        "ARC_CRACKLE_HUM",
        "HOLLOW_WIND",
        "RESONANT_CHORD",
    },
    "impact_module": {
        "NONE",
        "ICE_LOCK_CRACK",
        "TECTONIC_SLAM",
        "THUNDER_CRACK",
        "HARMONIC_DEFLECT",
        "FROST_SHATTER",
        "ETHER_PING",
    },
    "sustain_loop_module": {
        "NONE",
        "TENSE_WATER_STRAIN",
        "SILENT_PRESSURE_HUM",
        "SOFT_MIST_AMBIENCE",
        "BARRIER_STRAIN_CHIME",
        "ARC_HOLD_BUZZ",
    },
}


@dataclass
class ValidationIssue:
    stage: str
    path: str
    message: str


def _resolve_ref(root_schema: dict[str, Any], ref: str) -> dict[str, Any]:
    if not ref.startswith("#/"):
        raise ValueError(f"Unsupported external schema $ref: {ref}")
    node: Any = root_schema
    for part in ref[2:].split("/"):
        node = node[part]
    return node


def _is_json_number(val: Any) -> bool:
    return isinstance(val, (int, float)) and not isinstance(val, bool)


def validate_json_schema(
    instance: Any,
    schema: dict[str, Any],
    root_schema: dict[str, Any],
    path: str = "$",
) -> list[ValidationIssue]:
    """Minimal strict Draft 2020-12 JSON Schema validator using stdlib only."""
    errors: list[ValidationIssue] = []

    if "$ref" in schema:
        target = _resolve_ref(root_schema, schema["$ref"])
        errors.extend(validate_json_schema(instance, target, root_schema, path))
        return errors

    if "const" in schema:
        if instance != schema["const"] or (isinstance(instance, bool) != isinstance(schema["const"], bool)):
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"expected const {schema['const']!r}, got {instance!r}"))
            return errors

    if "enum" in schema:
        matched = any(
            instance == opt and (isinstance(instance, bool) == isinstance(opt, bool))
            for opt in schema["enum"]
        )
        if not matched:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"value {instance!r} not in enum {schema['enum']!r}"))
            return errors

    if "type" in schema:
        expected_type = schema["type"]
        ok = True
        if expected_type == "object":
            ok = isinstance(instance, dict)
        elif expected_type == "array":
            ok = isinstance(instance, list)
        elif expected_type == "string":
            ok = isinstance(instance, str)
        elif expected_type == "integer":
            ok = isinstance(instance, int) and not isinstance(instance, bool)
        elif expected_type == "number":
            ok = _is_json_number(instance)
        elif expected_type == "boolean":
            ok = isinstance(instance, bool)
        if not ok:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"expected type {expected_type}, got {type(instance).__name__}"))
            return errors

    if "oneOf" in schema:
        sub_matches = 0
        sub_errors: list[list[ValidationIssue]] = []
        for candidate in schema["oneOf"]:
            res = validate_json_schema(instance, candidate, root_schema, path)
            if not res:
                sub_matches += 1
            else:
                sub_errors.append(res)
        if sub_matches != 1:
            detail = "; ".join(e[0].message for e in sub_errors if e) if sub_matches == 0 else "matched multiple variants"
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"oneOf check failed ({sub_matches} matches): {detail}"))
            return errors

    if "not" in schema:
        if not validate_json_schema(instance, schema["not"], root_schema, path):
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, "must not match disallowed subschema"))

    if "if" in schema:
        cond_ok = not validate_json_schema(instance, schema["if"], root_schema, path)
        if cond_ok and "then" in schema:
            errors.extend(validate_json_schema(instance, schema["then"], root_schema, path))
        elif not cond_ok and "else" in schema:
            errors.extend(validate_json_schema(instance, schema["else"], root_schema, path))

    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"string shorter than {schema['minLength']}"))
        if "maxLength" in schema and len(instance) > schema["maxLength"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"string longer than {schema['maxLength']}"))
        if "pattern" in schema and re.fullmatch(schema["pattern"], instance) is None:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"string {instance!r} does not match pattern {schema['pattern']}"))

    if _is_json_number(instance):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"{instance} < minimum {schema['minimum']}"))
        if "exclusiveMinimum" in schema and instance <= schema["exclusiveMinimum"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"{instance} <= exclusiveMinimum {schema['exclusiveMinimum']}"))
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"{instance} > maximum {schema['maximum']}"))

    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"array length {len(instance)} < minItems {schema['minItems']}"))
        if "maxItems" in schema and len(instance) > schema["maxItems"]:
            errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"array length {len(instance)} > maxItems {schema['maxItems']}"))
        if "items" in schema:
            for idx, item in enumerate(instance):
                errors.extend(validate_json_schema(item, schema["items"], root_schema, f"{path}[{idx}]"))

    if isinstance(instance, dict):
        props = schema.get("properties", {})
        for req in schema.get("required", []):
            if req not in instance:
                errors.append(ValidationIssue("STAGE_1_STRUCTURE", path, f"missing required property '{req}'"))
        if schema.get("additionalProperties") is False:
            for key in instance:
                if key not in props:
                    errors.append(ValidationIssue("STAGE_1_STRUCTURE", f"{path}.{key}", f"unexpected additional property '{key}'"))
        for key, prop_schema in props.items():
            if key in instance:
                errors.extend(validate_json_schema(instance[key], prop_schema, root_schema, f"{path}.{key}"))

    return errors


def _validate_ref_string(ref: str, subject_ids: set[str], path: str, issues: list[ValidationIssue], allow_env: bool = False) -> None:
    if ref in VALID_CASTER_REFS or ref in VALID_TARGET_REFS:
        return
    if allow_env and ref in VALID_ENV_REFS:
        return
    if ref.startswith("SUBJECT:") or ref.startswith("WORLD_REF:"):
        sid = ref.split(":", 1)[1]
        if sid not in subject_ids:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", path, f"reference '{ref}' points to nonexistent subject '{sid}'"))
        return
    issues.append(ValidationIssue("STAGE_2_SEMANTIC", path, f"unrecognized reference string '{ref}'"))


def _all_ops_in_doc(doc: dict[str, Any]) -> list[tuple[str, str, dict[str, Any]]]:
    out: list[tuple[str, str, dict[str, Any]]] = []
    for p in doc["process_graph"]["processes"]:
        pid = p["id"]
        for phase in ("on_enter", "while_active", "on_exit"):
            for idx, op in enumerate(p[phase]):
                out.append((f"process_graph.{pid}.{phase}[{idx}]", phase, op))
    return out


def validate_spell_semantic(doc: dict[str, Any]) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []

    subjects: dict[str, dict[str, Any]] = {}
    for idx, subj in enumerate(doc["subjects"]):
        sid = subj["id"]
        if sid in subjects:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"subjects[{idx}].id", f"duplicate subject id '{sid}'"))
        subjects[sid] = subj

        if subj["kind"] == "MATERIAL":
            if subj["initial_inventory_mu"] > subj["capacity_mu"]:
                issues.append(
                    ValidationIssue(
                        "STAGE_2_SEMANTIC",
                        f"subjects[{idx}].initial_inventory_mu",
                        f"initial_inventory_mu ({subj['initial_inventory_mu']}) exceeds capacity_mu ({subj['capacity_mu']})",
                    )
                )
        elif subj["kind"] == "FIELD":
            if subj["initial_intensity"] > subj["max_intensity"]:
                issues.append(
                    ValidationIssue(
                        "STAGE_2_SEMANTIC",
                        f"subjects[{idx}].initial_intensity",
                        f"initial_intensity ({subj['initial_intensity']}) exceeds max_intensity ({subj['max_intensity']})",
                    )
                )

    spatial_ids: set[str] = set()
    for idx, sp in enumerate(doc["spatial"]):
        spid = sp["id"]
        if spid in spatial_ids:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"spatial[{idx}].id", f"duplicate spatial id '{spid}'"))
        spatial_ids.add(spid)
        if sp["subject_id"] not in subjects:
            issues.append(
                ValidationIssue("STAGE_2_SEMANTIC", f"spatial[{idx}].subject_id", f"unknown subject_id '{sp['subject_id']}'")
            )
        ref = sp["reference"]
        anchor = ref["spawn_anchor"]
        if anchor in ("SUBJECT_ORIGIN", "WORLD_REF"):
            ssid = ref.get("spawn_subject_id")
            if not ssid or ssid not in subjects:
                issues.append(
                    ValidationIssue(
                        "STAGE_2_SEMANTIC",
                        f"spatial[{idx}].reference.spawn_subject_id",
                        f"spawn_anchor '{anchor}' requires valid spawn_subject_id",
                    )
                )
            elif anchor == "WORLD_REF" and subjects[ssid]["kind"] != "WORLD_REF":
                issues.append(
                    ValidationIssue(
                        "STAGE_2_SEMANTIC",
                        f"spatial[{idx}].reference.spawn_subject_id",
                        f"spawn_anchor WORLD_REF requires '{ssid}' to have kind WORLD_REF",
                    )
                )
        if anchor == "AUTO_SUPPORT_SURFACE" and "auto_support_rule" not in ref:
            issues.append(
                ValidationIssue(
                    "STAGE_2_SEMANTIC",
                    f"spatial[{idx}].reference.auto_support_rule",
                    "AUTO_SUPPORT_SURFACE requires auto_support_rule",
                )
            )
        if sp["carrier"] == "PATH_GRAPH" and sp["edge_budget"] < sp["node_budget"] - 1:
            issues.append(
                ValidationIssue(
                    "STAGE_2_SEMANTIC",
                    f"spatial[{idx}].edge_budget",
                    "PATH_GRAPH edge_budget should be >= node_budget - 1 for connected topology",
                )
            )

    relations: dict[str, dict[str, Any]] = {}
    for idx, rel in enumerate(doc["relations"]):
        rid = rel["id"]
        if rid in relations:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"relations[{idx}].id", f"duplicate relation id '{rid}'"))
        relations[rid] = rel
        _validate_ref_string(rel["source_ref"], set(subjects), f"relations[{idx}].source_ref", issues)
        _validate_ref_string(rel["target_ref"], set(subjects), f"relations[{idx}].target_ref", issues)
        if rel["kind"] == "SPATIAL_ATTACH" and "attach_mode" not in rel:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"relations[{idx}].attach_mode", "SPATIAL_ATTACH requires attach_mode"))
        if rel["kind"] == "FUNCTIONAL_COUPLE" and "signal_granularity" not in rel:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"relations[{idx}].signal_granularity", "FUNCTIONAL_COUPLE requires signal_granularity"))

    pg = doc["process_graph"]
    proc_map: dict[str, dict[str, Any]] = {}
    for idx, proc in enumerate(pg["processes"]):
        pid = proc["id"]
        if pid in proc_map:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"process_graph.processes[{idx}].id", f"duplicate process id '{pid}'"))
        proc_map[pid] = proc

    for entry_id in pg["entry_processes"]:
        if entry_id not in proc_map:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", "process_graph.entry_processes", f"unknown entry process '{entry_id}'"))

    # Collect handles & validate ops
    declared_handles: set[str] = set()
    for p in pg["processes"]:
        for phase in ("on_enter", "while_active", "on_exit"):
            for op in p[phase]:
                if "handle_id" in op:
                    declared_handles.add(op["handle_id"])

    provider_cfg = doc["contract"]["combat"]["provider"]
    energy_source = provider_cfg["energy_source"]

    for ppath, phase, op in _all_ops_in_doc(doc):
        kind = op["op"]
        if kind == "ESTABLISH":
            if phase != "on_enter":
                issues.append(
                    ValidationIssue("STAGE_2_SEMANTIC", ppath, f"ESTABLISH is only permitted in on_enter, found in {phase}")
                )
            tkind = op["target_kind"]
            tid = op["target_id"]
            if tkind == "SUBJECT" and tid not in subjects:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, f"ESTABLISH targets unknown subject '{tid}'"))
            elif tkind == "RELATION" and tid not in relations:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, f"ESTABLISH targets unknown relation '{tid}'"))
        elif kind == "COUPLE":
            if op["relation_id"] not in relations:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, f"COUPLE targets unknown relation '{op['relation_id']}'"))
        elif kind in ("DRIVE", "CONSTRAIN", "TRANSFORM", "TRANSFER"):
            tsid = op["target_subject_id"]
            if tsid not in subjects:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, f"{kind} targets unknown subject '{tsid}'"))
            if kind == "DRIVE":
                if "direction" in op and op["direction"]["mode"] == "RADIAL":
                    _validate_ref_string(op["direction"]["center_ref"], set(subjects), f"{ppath}.direction.center_ref", issues)
                if "target_ref" in op:
                    _validate_ref_string(op["target_ref"], set(subjects), f"{ppath}.target_ref", issues)
            if kind == "CONSTRAIN" and "anchor_ref" in op:
                _validate_ref_string(op["anchor_ref"], set(subjects), f"{ppath}.anchor_ref", issues)
            if kind == "TRANSFER":
                _validate_ref_string(op["source_ref"], set(subjects), f"{ppath}.source_ref", issues, allow_env=True)
            if kind == "TRANSFORM" and op["transform_id"] == "PHASE_CHANGE" and "target_phase" not in op:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, "PHASE_CHANGE requires target_phase"))
            if kind == "TRANSFORM" and op["transform_id"] == "PROPAGATE" and "propagation" not in op:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, "PROPAGATE requires propagation configuration"))
        elif kind == "WITHDRAW":
            if op["target_scope"] == "HANDLE":
                hid = op.get("target_id")
                if not hid or hid not in declared_handles:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", ppath, f"WITHDRAW(HANDLE) targets unknown handle '{hid}'"))

    # Transitions & Reachability
    for p in pg["processes"]:
        pid = p["id"]
        for tidx, tr in enumerate(p["transitions"]):
            tpath = f"process_graph.{pid}.transitions[{tidx}]"
            filt = tr["event_source_filter"]
            if filt["scope"] == "SUBJECT":
                sid = filt.get("subject_id")
                if not sid or sid not in subjects:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"{tpath}.event_source_filter", f"filter points to unknown subject '{sid}'"))
            for npid in tr["next_process_ids"]:
                if npid not in proc_map:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"{tpath}.next_process_ids", f"transition targets unknown process '{npid}'"))
            if tr["action"] in ("STOP_SELF_START_NEXT", "KEEP_SELF_START_NEXT", "HANDOFF_TO_RESERVE") and not tr["next_process_ids"]:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"{tpath}.next_process_ids", f"action '{tr['action']}' requires at least one next_process_ids target"))
            for hh in tr["handoff_handles"]:
                if hh not in declared_handles:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"{tpath}.handoff_handles", f"handoff_handles references unknown handle '{hh}'"))
            if tr["action"] == "HANDOFF_TO_RESERVE":
                if not tr["handoff_handles"]:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"{tpath}.handoff_handles", "HANDOFF_TO_RESERVE requires explicit handoff_handles"))
                if energy_source not in ("POST_RELEASE_RESERVE", "VESSEL_RESERVE"):
                    issues.append(
                        ValidationIssue(
                            "STAGE_2_SEMANTIC",
                            tpath,
                            f"HANDOFF_TO_RESERVE requires provider.energy_source in (POST_RELEASE_RESERVE, VESSEL_RESERVE), got {energy_source}",
                        )
                    )

    # BFS reachability from entry_processes
    visited: set[str] = set()
    queue = [eid for eid in pg["entry_processes"] if eid in proc_map]
    while queue:
        cur = queue.pop(0)
        if cur in visited:
            continue
        visited.add(cur)
        for tr in proc_map[cur]["transitions"]:
            for nxt in tr["next_process_ids"]:
                if nxt in proc_map and nxt not in visited:
                    queue.append(nxt)
    for pid in proc_map:
        if pid not in visited:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"process_graph.{pid}", f"unreachable orphan process '{pid}'"))

    return issues


def validate_capability_and_limited_conditions(doc: dict[str, Any]) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    subjects = {s["id"]: s for s in doc["subjects"]}

    for idx, sp in enumerate(doc["spatial"]):
        subj = subjects.get(sp["subject_id"])
        if not subj:
            continue
        carrier = sp["carrier"]
        if subj["kind"] == "MATERIAL":
            key = (subj["material_id"], carrier)
            tier = MATERIAL_CARRIER_MATRIX.get(key, "UNSUPPORTED")
            if tier not in ("SUPPORTED", "LIMITED"):
                issues.append(
                    ValidationIssue("STAGE_3_CAPABILITY", f"spatial[{idx}]", f"material+carrier {key} has capability status '{tier}'")
                )
            # Explicit Limited-condition guard for Ice Path -> compound rigid body
            if subj["material_id"] == "ICE" and carrier == "PATH_GRAPH" and sp["node_budget"] > 16:
                issues.append(
                    ValidationIssue("STAGE_3_CAPABILITY", f"spatial[{idx}]", "ICE+PATH_GRAPH limited condition requires node_budget <= 16")
                )
        elif subj["kind"] == "FIELD":
            key = (subj["field_channel"], carrier)
            tier = FIELD_CARRIER_MATRIX.get(key, "UNSUPPORTED")
            if tier not in ("SUPPORTED", "LIMITED"):
                issues.append(
                    ValidationIssue("STAGE_3_CAPABILITY", f"spatial[{idx}]", f"field+carrier {key} has capability status '{tier}'")
                )
            if subj["field_channel"] == "SPATIAL_BARRIER":
                if carrier != "SURFACE" or "barrier_policy" not in subj:
                    issues.append(
                        ValidationIssue("STAGE_3_CAPABILITY", f"spatial[{idx}]", "SPATIAL_BARRIER LIMITED contract requires SURFACE carrier and barrier_policy")
                    )

    # Check TRANSFORM limited conditions
    for ppath, _, op in _all_ops_in_doc(doc):
        if op["op"] == "TRANSFORM":
            subj = subjects.get(op["target_subject_id"])
            if not subj:
                continue
            if op["transform_id"] == "PHASE_CHANGE" and subj.get("material_id") == "WATER" and op.get("target_phase") == "SOLID":
                # Weave(Freeze) limited condition: must explicitly bound compound output bodies <= 16
                mob = op.get("max_output_bodies")
                if mob is None or mob > 16:
                    issues.append(
                        ValidationIssue("STAGE_3_CAPABILITY", ppath, "Water->Ice freeze requires bounded max_output_bodies (1..16)")
                    )
            if op["transform_id"] == "PROPAGATE":
                prop = op.get("propagation", {})
                if prop.get("max_hops", 0) > 12:
                    issues.append(
                        ValidationIssue("STAGE_3_CAPABILITY", ppath, "PROPAGATE max_hops exceeds capability cap (12)")
                    )

    return issues


def compute_independent_budget(doc: dict[str, Any]) -> dict[str, float | int]:
    """Independent deterministic budget calculation (mirrors magic_dsl_document.gd & docs/02)."""
    min_upfront = 2.0
    emissive_lights = 0

    for subj in doc["subjects"]:
        if subj["kind"] == "MATERIAL":
            min_upfront += 3.0 + float(subj["initial_inventory_mu"]) * 1.25
        elif subj["kind"] == "FIELD":
            min_upfront += 6.0 + float(subj["initial_intensity"]) * 0.20
        elif subj["kind"] == "WORLD_REF":
            min_upfront += 2.0

        vm = subj.get("visual_modules")
        if vm and float(vm["tint_palette"]["emissive_boost"]) > 0.25:
            emissive_lights += 1
        elif subj["kind"] == "FIELD" and subj["field_channel"] == "LIGHT_EMISSION":
            emissive_lights += 1

    peak_bodies = 0
    peak_nodes = 0
    peak_quads = 0
    for sp in doc["spatial"]:
        c = sp["carrier"]
        if c == "BODY":
            min_upfront += 1.5
            peak_bodies += 1
        elif c == "PATH_GRAPH":
            min_upfront += sp["node_budget"] * 0.25 + sp["edge_budget"] * 0.15
            peak_nodes += int(sp["node_budget"])
        elif c == "SURFACE":
            min_upfront += sp["quad_budget"] * 0.15
            peak_quads += int(sp["quad_budget"])
        elif c == "REGION":
            min_upfront += sp["initial_extent_m"] * 0.50

    min_upfront += len(doc["relations"]) * 1.5

    min_sustain = 0.0
    requires_reserve = False
    controller = doc["contract"]["combat"]["controller"]
    rel_map = {r["id"]: r for r in doc["relations"]}

    for p in doc["process_graph"]["processes"]:
        for op in p["while_active"]:
            kind = op["op"]
            if kind == "DRIVE" and controller == "CASTER_FOCUS":
                min_sustain += 1.2
            elif kind == "TRANSFER":
                min_sustain += 0.5
            elif kind == "CONSTRAIN":
                pref = op["provider_ref"]
                if pref == "CASTER_MANA":
                    min_sustain += max(0.5, float(op["capacity_lu"]) * 0.02)
                elif pref in ("POST_RELEASE_RESERVE", "VESSEL_RESERVE"):
                    requires_reserve = True
        for phase in ("on_enter", "on_exit"):
            for op in p[phase]:
                if op["op"] == "TRANSFORM":
                    if "max_output_bodies" in op:
                        peak_bodies += int(op["max_output_bodies"])
                elif op["op"] == "COUPLE" and controller == "CASTER_FOCUS":
                    rel = rel_map.get(op["relation_id"], {})
                    if rel.get("channel") in ("DISTURBANCE_TO_PERCEPTION", "ENERGY_FEED"):
                        min_sustain += 1.2
                elif op["op"] == "TRANSFER" and op["source_ref"] == "CASTER:RESERVE":
                    requires_reserve = True
        for tr in p["transitions"]:
            if tr["action"] == "HANDOFF_TO_RESERVE":
                requires_reserve = True

    return {
        "min_upfront_mana": round(min_upfront, 4),
        "min_sustain_mana_per_s": round(min_sustain, 4),
        "min_reserve_mana": 4.0 if requires_reserve else 0.0,
        "computed_peak_bodies": peak_bodies,
        "computed_peak_nodes": peak_nodes,
        "computed_peak_quads": peak_quads,
        "computed_point_lights": min(3, emissive_lights),
    }


def validate_budget_and_artkit(doc: dict[str, Any]) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    # Intentionally DO NOT trust doc["budget"]["compiler_status"] == "VALID"
    budget = doc["budget"]
    provider = doc["contract"]["combat"]["provider"]
    calc = compute_independent_budget(doc)

    if budget["derived_upfront_mana"] + 1e-6 < calc["min_upfront_mana"]:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_upfront_mana",
                f"derived_upfront_mana ({budget['derived_upfront_mana']}) is below deterministic floor ({calc['min_upfront_mana']})",
            )
        )
    if budget["derived_upfront_mana"] > provider["max_upfront_mana"]:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_upfront_mana",
                f"derived_upfront_mana ({budget['derived_upfront_mana']}) exceeds contract max_upfront_mana ({provider['max_upfront_mana']})",
            )
        )
    if budget["derived_sustain_mana_per_s"] + 1e-6 < calc["min_sustain_mana_per_s"]:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_sustain_mana_per_s",
                f"derived_sustain_mana_per_s ({budget['derived_sustain_mana_per_s']}) is below floor ({calc['min_sustain_mana_per_s']})",
            )
        )
    if budget["derived_sustain_mana_per_s"] > provider["max_sustain_mana_per_s"]:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_sustain_mana_per_s",
                "derived_sustain_mana_per_s exceeds contract max_sustain_mana_per_s",
            )
        )
    if abs(budget["derived_reserve_mana"] - provider["post_release_reserve_mana"]) > 1e-3:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_reserve_mana",
                "derived_reserve_mana must equal contract.combat.provider.post_release_reserve_mana",
            )
        )
    if budget["derived_reserve_mana"] + 1e-6 < calc["min_reserve_mana"]:
        issues.append(
            ValidationIssue(
                "STAGE_4_BUDGET_ARTKIT",
                "budget.derived_reserve_mana",
                f"reserve-backed spell requires at least {calc['min_reserve_mana']} reserve mana",
            )
        )

    if calc["computed_peak_bodies"] > 16 or budget["peak_dynamic_bodies"] < calc["computed_peak_bodies"]:
        issues.append(
            ValidationIssue("STAGE_4_BUDGET_ARTKIT", "budget.peak_dynamic_bodies", "peak_dynamic_bodies inconsistent or exceeds 16")
        )
    if calc["computed_peak_nodes"] > 16 or budget["peak_path_nodes"] < calc["computed_peak_nodes"]:
        issues.append(
            ValidationIssue("STAGE_4_BUDGET_ARTKIT", "budget.peak_path_nodes", "peak_path_nodes inconsistent or exceeds 16")
        )
    if calc["computed_peak_quads"] > 64 or budget["peak_surface_quads"] < calc["computed_peak_quads"]:
        issues.append(
            ValidationIssue("STAGE_4_BUDGET_ARTKIT", "budget.peak_surface_quads", "peak_surface_quads inconsistent or exceeds 64")
        )
    if budget["peak_point_lights"] < calc["computed_point_lights"] or budget["peak_point_lights"] > 3:
        issues.append(
            ValidationIssue("STAGE_4_BUDGET_ARTKIT", "budget.peak_point_lights", "peak_point_lights inconsistent with emissive subjects or exceeds 3")
        )

    # ArtKit module registry verification
    for idx, subj in enumerate(doc["subjects"]):
        vm = subj.get("visual_modules")
        if not vm:
            continue
        if vm["contour_module"] not in ARTKIT_REGISTRY["contour_module"]:
            issues.append(ValidationIssue("STAGE_4_BUDGET_ARTKIT", f"subjects[{idx}].visual_modules.contour_module", f"unregistered ArtKit contour module '{vm['contour_module']}'"))
        for s_mod in vm["surface_modules"]:
            if s_mod not in ARTKIT_REGISTRY["surface_modules"]:
                issues.append(ValidationIssue("STAGE_4_BUDGET_ARTKIT", f"subjects[{idx}].visual_modules.surface_modules", f"unregistered ArtKit surface module '{s_mod}'"))
        for sec_mod in vm["secondary_modules"]:
            if sec_mod not in ARTKIT_REGISTRY["secondary_modules"]:
                issues.append(ValidationIssue("STAGE_4_BUDGET_ARTKIT", f"subjects[{idx}].visual_modules.secondary_modules", f"unregistered ArtKit secondary module '{sec_mod}'"))

    ap = doc["expression"]["audio_profile"]
    for key in ("drone_module", "impact_module", "sustain_loop_module"):
        if ap[key] not in ARTKIT_REGISTRY[key]:
            issues.append(ValidationIssue("STAGE_4_BUDGET_ARTKIT", f"expression.audio_profile.{key}", f"unregistered audio module '{ap[key]}'"))

    return issues


def validate_spell_document(doc: dict[str, Any], dsl_schema: dict[str, Any]) -> list[ValidationIssue]:
    s1 = validate_json_schema(doc, dsl_schema, dsl_schema)
    if s1:
        return s1
    s2 = validate_spell_semantic(doc)
    if s2:
        return s2
    s3 = validate_capability_and_limited_conditions(doc)
    if s3:
        return s3
    return validate_budget_and_artkit(doc)


def validate_semantic_intent(
    intent_doc: dict[str, Any],
    intent_schema: dict[str, Any],
    compiled_doc: dict[str, Any] | None = None,
) -> list[ValidationIssue]:
    s1 = validate_json_schema(intent_doc, intent_schema, intent_schema)
    if s1:
        return s1
    issues: list[ValidationIssue] = []
    clause_ids: set[str] = set()
    for idx, cl in enumerate(intent_doc["clauses"]):
        cid = cl["clause_id"]
        if cid in clause_ids:
            issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"clauses[{idx}].clause_id", f"duplicate clause_id '{cid}'"))
        clause_ids.add(cid)

    for idx, cl in enumerate(intent_doc["clauses"]):
        if cl["clause_role"] == "INVERT_OR_REDIRECT" or cl["semantic_polarity"] == "INVERTED":
            target_cid = cl.get("scope_target_clause_id")
            if target_cid and target_cid not in clause_ids:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"clauses[{idx}].scope_target_clause_id", f"unknown scope_target_clause_id '{target_cid}'"))

    compiled_ids: set[str] = set()
    if compiled_doc is not None:
        compiled_ids.update(s["id"] for s in compiled_doc.get("subjects", []))
        compiled_ids.update(s["id"] for s in compiled_doc.get("spatial", []))
        compiled_ids.update(r["id"] for r in compiled_doc.get("relations", []))
        compiled_ids.update(p["id"] for p in compiled_doc.get("process_graph", {}).get("processes", []))

    for idx, rc in enumerate(intent_doc["rune_contributions"]):
        for cid in rc["target_clause_ids"]:
            if cid not in clause_ids:
                issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"rune_contributions[{idx}].target_clause_ids", f"unknown clause_id '{cid}'"))
        if compiled_doc is not None:
            for bid in rc["bound_ids"]:
                if bid not in compiled_ids:
                    issues.append(ValidationIssue("STAGE_2_SEMANTIC", f"rune_contributions[{idx}].bound_ids", f"bound_id '{bid}' not found in compiled spell"))
    return issues


def build_negative_tests(base_doc: dict[str, Any], case2_doc: dict[str, Any], case4_doc: dict[str, Any]) -> list[tuple[str, dict[str, Any], str]]:
    tests: list[tuple[str, dict[str, Any], str]] = []

    # 1. material_subject_missing_material_and_phase
    d1 = copy.deepcopy(base_doc)
    del d1["subjects"][0]["material_id"]
    del d1["subjects"][0]["initial_phase"]
    tests.append(("material_subject_missing_material_and_phase", d1, "STAGE_1_STRUCTURE"))

    # 2. region_carrier_using_path_generator
    d2 = copy.deepcopy(case4_doc)
    d2["spatial"][0]["generator"] = "BRANCH_WEB"
    tests.append(("region_carrier_using_path_generator", d2, "STAGE_1_STRUCTURE"))

    # 3. op_targeting_nonexistent_subject
    d3 = copy.deepcopy(base_doc)
    d3["process_graph"]["processes"][0]["while_active"][1]["target_subject_id"] = "s_ghost_water"
    tests.append(("op_targeting_nonexistent_subject", d3, "STAGE_2_SEMANTIC"))

    # 4. transition_to_nonexistent_process
    d4 = copy.deepcopy(case2_doc)
    d4["process_graph"]["processes"][0]["transitions"][0]["next_process_ids"] = ["p_void_missing"]
    tests.append(("transition_to_nonexistent_process", d4, "STAGE_2_SEMANTIC"))

    # 5. duplicate_subject_ids
    d5 = copy.deepcopy(base_doc)
    d5["subjects"][1]["id"] = "s_water"
    tests.append(("duplicate_subject_ids", d5, "STAGE_2_SEMANTIC"))

    # 6. unregistered_override_field
    d6 = copy.deepcopy(base_doc)
    d6["subjects"][0]["overrides"] = {"density": 9999.0}
    tests.append(("unregistered_override_field", d6, "STAGE_1_STRUCTURE"))

    # 7. forged_zero_mana_budget (plus check Stage 4 with forged nonzero sub-floor budget!)
    d7 = copy.deepcopy(base_doc)
    d7["budget"]["compiler_status"] = "VALID"
    d7["budget"]["derived_upfront_mana"] = 0.0
    tests.append(("forged_zero_mana_budget", d7, "STAGE_1_STRUCTURE"))

    # 8. nonexistent_art_module
    d8 = copy.deepcopy(base_doc)
    d8["subjects"][0]["visual_modules"]["contour_module"] = "MYTHIC_GALAXY_DRAGON"
    tests.append(("nonexistent_art_module", d8, "STAGE_1_STRUCTURE"))

    # 9. impulse_channel_in_target_drive_mode
    d9 = copy.deepcopy(case2_doc)
    d9["process_graph"]["processes"][1]["on_enter"][0]["mode"] = "TARGET"
    tests.append(("impulse_channel_in_target_drive_mode", d9, "STAGE_1_STRUCTURE"))

    # 10. inventory_exceeds_capacity
    d10 = copy.deepcopy(base_doc)
    d10["subjects"][0]["initial_inventory_mu"] = 99.0
    tests.append(("inventory_exceeds_capacity", d10, "STAGE_2_SEMANTIC"))

    # 11. establish_in_while_active
    d11 = copy.deepcopy(base_doc)
    d11["process_graph"]["processes"][0]["while_active"].append(
        {"op": "ESTABLISH", "target_kind": "SUBJECT", "target_id": "f_freeze", "handle_id": "h_bad"}
    )
    tests.append(("establish_in_while_active", d11, "STAGE_2_SEMANTIC"))

    # 12. unreachable_orphan_process
    d12 = copy.deepcopy(case2_doc)
    d12["process_graph"]["processes"].append(
        {
            "id": "p_orphan",
            "role": "CLEANUP_DISSIPATE",
            "on_enter": [],
            "while_active": [],
            "on_exit": [],
            "max_duration_s": 0.5,
            "transitions": [],
        }
    )
    tests.append(("unreachable_orphan_process", d12, "STAGE_2_SEMANTIC"))

    return tests


def run_self_test() -> int:
    dsl_schema = json.loads(DSL_SCHEMA_PATH.read_text(encoding="utf-8"))
    intent_schema = json.loads(INTENT_SCHEMA_PATH.read_text(encoding="utf-8"))

    spell_files = sorted(SPELLS_DIR.glob("*.json"))
    print(f"[Magic DSL v0.2.1 Self-Test] Found {len(spell_files)} spell JSON files.")
    failed = False
    loaded_spells: dict[str, dict[str, Any]] = {}

    for sf in spell_files:
        doc = json.loads(sf.read_text(encoding="utf-8"))
        loaded_spells[sf.name] = doc
        issues = validate_spell_document(doc, dsl_schema)
        if issues:
            failed = True
            print(f"  FAIL (expected PASS): {sf.name}")
            for iss in issues:
                print(f"    - [{iss.stage}] {iss.path}: {iss.message}")
        else:
            calc = compute_independent_budget(doc)
            print(f"  PASS: {sf.name} (upfront={doc['budget']['derived_upfront_mana']}>={calc['min_upfront_mana']}, sustain={doc['budget']['derived_sustain_mana_per_s']}>={calc['min_sustain_mana_per_s']}, reserve={doc['budget']['derived_reserve_mana']})")

    # Verify sample SemanticIntent + binding traceability
    sample_intent_path = INTENTS_DIR / "sample_intent_water_weave_freeze.json"
    intent_doc = json.loads(sample_intent_path.read_text(encoding="utf-8"))
    intent_issues = validate_semantic_intent(intent_doc, intent_schema, loaded_spells["case1_water_weave_freeze.json"])
    if intent_issues:
        failed = True
        print("  FAIL (expected PASS): sample_intent_water_weave_freeze.json")
        for iss in intent_issues:
            print(f"    - [{iss.stage}] {iss.path}: {iss.message}")
    else:
        print("  PASS: sample_intent_water_weave_freeze.json + trace against case1_water_weave_freeze.json")

    # Run 12 negative tests
    neg_tests = build_negative_tests(
        loaded_spells["case1_water_weave_freeze.json"],
        loaded_spells["case2_gravity_collapse.json"],
        loaded_spells["case4_fog_disturbance_sense.json"],
    )
    print(f"[Magic DSL v0.2.1 Self-Test] Running {len(neg_tests)} negative tests (all must REJECT):")
    for name, bad_doc, expected_stage in neg_tests:
        issues = validate_spell_document(bad_doc, dsl_schema)
        if not issues:
            failed = True
            print(f"  FAIL (expected REJECT): {name}")
        elif issues[0].stage != expected_stage:
            failed = True
            print(f"  FAIL (wrong stage {issues[0].stage} != {expected_stage}): {name} -> {issues[0].message}")
        else:
            print(f"  REJECTED [{issues[0].stage}]: {name} ({issues[0].message})")

    # Extra Stage 4 verification proving underpriced nonzero mana cannot bypass Stage 4 even with compiler_status == VALID
    underpriced = copy.deepcopy(loaded_spells["case1_water_weave_freeze.json"])
    underpriced["budget"]["derived_upfront_mana"] = 1.0
    up_issues = validate_spell_document(underpriced, dsl_schema)
    if not up_issues or up_issues[0].stage != "STAGE_4_BUDGET_ARTKIT":
        failed = True
        print("  FAIL: underpriced nonzero mana bypassed STAGE_4_BUDGET_ARTKIT!")
    else:
        print(f"  REJECTED [{up_issues[0].stage}]: underpriced_nonzero_mana_with_forged_valid ({up_issues[0].message})")

    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Magic DSL v0.2.1 4-stage offline validator")
    parser.add_argument("spell_files", nargs="*", help="CompiledSpellDSL JSON files to validate")
    parser.add_argument("--self-test", action="store_true", help="Run 7 valid spells + SemanticIntent + 12 negative tests")
    parser.add_argument("--intent", help="SemanticIntent JSON file to validate")
    parser.add_argument("--spell", help="Optional CompiledSpellDSL JSON file for bound_ids traceability")
    args = parser.parse_args()

    if args.self_test:
        return run_self_test()

    if args.intent:
        intent_schema = json.loads(INTENT_SCHEMA_PATH.read_text(encoding="utf-8"))
        intent_doc = json.loads(pathlib.Path(args.intent).read_text(encoding="utf-8"))
        compiled_doc = json.loads(pathlib.Path(args.spell).read_text(encoding="utf-8")) if args.spell else None
        issues = validate_semantic_intent(intent_doc, intent_schema, compiled_doc)
        if issues:
            for iss in issues:
                print(f"[{iss.stage}] {iss.path}: {iss.message}", file=sys.stderr)
            return 1
        print(f"VALID intent: {args.intent}")
        return 0

    if not args.spell_files:
        parser.print_help()
        return 2

    dsl_schema = json.loads(DSL_SCHEMA_PATH.read_text(encoding="utf-8"))
    exit_code = 0
    for sf in args.spell_files:
        doc = json.loads(pathlib.Path(sf).read_text(encoding="utf-8"))
        issues = validate_spell_document(doc, dsl_schema)
        if issues:
            exit_code = 1
            print(f"INVALID {sf}:")
            for iss in issues:
                print(f"  - [{iss.stage}] {iss.path}: {iss.message}")
        else:
            print(f"VALID {sf}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
