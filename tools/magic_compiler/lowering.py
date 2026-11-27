from copy import deepcopy

from .admission import admit, budget_floor
from .rules import load, one, require, validate


def projected(rules, table, value, process=None):
    proc = process or {}
    rows = [
        r
        for r in rules.projections[table]
        if r["match"] == value
        and ("operation" not in r or r["operation"] == proc.get("operation"))
        and ("effect" not in r or r["effect"] in proc.get("effects", []))
    ]
    require(rows, table, "语义已确定，缺少对应的执行投影", "UNSUPPORTED_LOWERING", required=value)
    return one(rows, table, "执行规则表有多个匹配")


def geometry(core, rules, profile):
    s = core["subjects"][0]
    concept = next(c["concept"] for c in core["concepts"] if c["id"] == s["concept_ref"])
    shape = s["spatial_intent"].copy()
    anchor = shape.pop("anchor")
    sp = dict(projected(rules, "space", shape)["emit"])
    ref = dict(projected(rules, "anchor", anchor)["emit"])
    if ref["spawn_anchor"] == "AUTO_SUPPORT_SURFACE":
        ref["auto_support_rule"] = {
            "max_count": 1,
            "max_distance_m": profile["extent_m"],
            "surface_filter": "SOLID_WORLD_SUPPORT",
        }
    binding = rules.projections["subjects"].get(concept)
    require(binding, s["id"], "概念缺少执行绑定", "UNSUPPORTED_LOWERING")
    if "field_channel" in binding:
        channel = binding["field_channel"]
        subject = {
            "id": s["id"],
            "kind": "FIELD",
            "field_channel": channel,
            "initial_intensity": profile["field_intensity"],
            "max_intensity": profile["reserve_capacity"],
            "inherit_world_law": True,
        }
        matrix = "field_x_carrier"
    else:
        channel, phase = binding["material_id"], binding["initial_phase"]
        subject = {
            "id": s["id"],
            "kind": "MATERIAL",
            "material_id": channel,
            "initial_phase": phase,
            "capacity_mu": profile["capacity_mu"],
            "initial_inventory_mu": 0 if s["source"] == "Borrow" else profile["capacity_mu"],
            "inherit_world_law": True,
        }
        matrix = "material_x_carrier"
    subject["art_overrides"] = {
        "tint_palette": {"primary_hex": "#FFFFFF", "accent_hex": "#FFFFFF", "emissive_boost": 0.0}
    }
    carrier = sp["carrier"]
    capability = rules.execution["capability_matrix"][matrix].get(channel + "|" + carrier)
    require(
        capability == "SUPPORTED",
        s["id"],
        "执行载体未获得完整准入",
        "UNSUPPORTED_LOWERING",
        capability=capability,
    )
    sp.update(
        id="space_" + s["id"],
        subject_id=s["id"],
        reference=ref,
        initial_extent_m=profile["extent_m"],
        node_budget=0,
        edge_budget=0,
        quad_budget=0,
        max_deflect_iterations_per_node=0,
    )
    if carrier == "PATH_GRAPH":
        sp.update(
            dimension="1D",
            node_budget=profile["path_nodes"],
            edge_budget=profile["path_edges"],
            per_segment_phase=True,
            distribution={
                "width_m": 0.1,
                "thickness_m": 0.1,
                "on_obstruction": "DEFORM_OR_TRUNCATE",
                "width_profile": {"curve": "CONSTANT", "domain": "PATH_U", "min_val": 1, "max_val": 1},
            },
        )
    elif carrier == "BODY":
        sp.update(
            dimension="3D",
            distribution={
                "cross_section": "SLAB" if shape["layout"] == "sheet" else "PRISM",
                "aspect_ratio": 2,
                "surface_roughness": 0.5,
            },
        )
    else:
        sp.update(dimension="3D", distribution={"radial_falloff": "BELL_CONCENTRATED", "boundary": "SOFT"})
    validate(subject, "magic_dsl_v0_2", "SubjectSpec")
    validate(sp, "magic_dsl_v0_2", "SpatialSpec")
    return subject, sp


def kernel(p, subject, rules, profile):
    target = subject["id"]
    guards = {}
    if p.get("profile"):
        row = projected(rules, "profile", p["profile"], p)
        op = {**row["emit"], "target_subject_id": target}
        if op["op"] == "TRANSFER":
            op.update(
                source_ref="CASTER:MANA",
                resource_kind="EU",
                rate_per_s=profile["charge_rate"],
                max_amount=profile["reserve_capacity"],
                on_insufficient_source="CLAMP_TO_AVAILABLE",
            )
            definition = "OpTransfer"
        else:
            op.update(projected(rules, "delivery", p["profile"], p)["emit"])
            op.update(
                direction=projected(rules, "direction", p["direction"])["emit"],
                magnitude=profile["reserve_capacity"] * profile["impulse_per_unit"],
            )
            guards["magnitude_from"] = {
                "account": "stored_action",
                "per_unit": profile["impulse_per_unit"],
                "consume": True,
            }
            definition = "OpDriveImpulse"
    elif "propagation" in p:
        policy = dict(p["propagation"])
        material = policy.pop("material")
        row = projected(rules, "propagation", policy, p)
        op = deepcopy(row["emit"])
        op["target_subject_id"] = target
        op["propagation"].update(profile["propagation"])
        guards.update(
            material=material,
            origin_binding=row["origin_binding"],
            traversal=rules.projections["traversal"],
        )
        definition = "OpTransform"
    elif p["effects"] == ["归属转移"]:
        op = {
            "op": "TRANSFER",
            "source_ref": "ENV:" + subject["material_id"],
            "target_subject_id": target,
            "rate_per_s": 1,
            "max_amount": subject["capacity_mu"],
            "resource_kind": "MU",
            "on_insufficient_source": "CLAMP_TO_AVAILABLE",
        }
        definition = "OpTransfer"
    elif p["effects"] == ["调整当前组织"]:
        op = {
            "op": "DRIVE",
            "target_subject_id": target,
            "channel": "EXTENT",
            "mode": "TARGET",
            "magnitude": profile["extent_m"],
            "profile": "CONSTANT",
            "target_ref": "TARGET:ANCHOR",
            "handle_id": "h_" + p["id"],
        }
        guards["control_ref"] = "@caster"
        definition = "OpDriveContinuous"
    elif p["operation"] == "Withdraw" and p["target"] == target:
        op = {
            "op": "WITHDRAW",
            "target_scope": "SUBJECT_SUPPORTS",
            "target_id": target,
            "mode": "NATURAL_RELEASE",
        }
        definition = "OpWithdraw"
    elif p["operation"] == "Establish" and p["target"] == target:
        op = {"op": "ESTABLISH", "target_kind": "SUBJECT", "target_id": target, "handle_id": "h_" + p["id"]}
        definition = "OpEstablish"
    else:
        return {}, {"unmapped_effects": p["effects"]}
    validate(op, "magic_dsl_v0_2", definition)
    return op, guards


def transition(event, dest):
    return {
        "on_event": event,
        "event_source_filter": {"scope": "SELF_PROCESS" if event == "ON_TIMEOUT" else "CAST_INSTANCE"},
        "next_process_ids": [dest] if dest else [],
        "handoff_handles": [],
        "action": "STOP_SELF_START_NEXT" if dest else "STOP_SELF_ONLY",
    }


def field_document(subject, spatial, schedule, rules, profile):
    """A sustained homogeneous field can use the unextended legacy event language directly."""
    start, end = schedule
    processes = []
    for step, role, events in (
        (start, "CARRIER_EXECUTION", ["ON_INPUT_RELEASE", "ON_INTERRUPT", "ON_TIMEOUT"]),
        (end, "CLEANUP_DISSIPATE", ["ON_TIMEOUT"]),
    ):
        processes.append(
            {
                "id": step["id"],
                "role": role,
                "on_enter": [step["kernel"]],
                "while_active": [],
                "on_exit": [],
                "max_duration_s": 1.0,
                "transitions": [transition(ev, end["id"] if step is start else None) for ev in events],
            }
        )
    processes[0]["while_active"] = [
        {
            "op": "DRIVE",
            "target_subject_id": subject["id"],
            "channel": "INTENSITY",
            "mode": "TARGET",
            "magnitude": subject["initial_intensity"],
            "profile": "CONSTANT",
        }
    ]
    provider = {
        "energy_source": "CASTER_MANA",
        "post_release_reserve_mana": 0,
        "max_upfront_mana": 1,
        "max_sustain_mana_per_s": 0,
    }
    doc = {
        "schema_version": rules.versions["execution"],
        "spell_id": "field_" + subject["field_channel"].lower(),
        "display_name": subject["field_channel"],
        "description": "阶段 B 有限域离线标尺",
        "source_intent_ref": "semantic_graph",
        "subjects": [subject],
        "spatial": [spatial],
        "relations": [],
        "process_graph": {"entry_processes": [start["id"]], "processes": processes},
        "contract": {
            "timing": {"windup_s": 0, "full_charge_s": 0, "recovery_s": 0, "max_active_duration_s": 1},
            "combat": {
                "formation_mode": "SUSTAINED_CHANNEL",
                "min_deliverable_progress": 0,
                "caster_mobility": "SLOW_WALK",
                "targeting": "POINT",
                "range_m": 1,
                "release_policy": {"on_valid_release": "DISSIPATE", "on_under_threshold_release": "NONE"},
                "interruption_policy": {
                    "on_interrupt": "ABORT_AND_DROP",
                    "dodge_behavior": "TRIGGER_INTERRUPT",
                    "interruption_priority": "INTERRUPT_ALWAYS_WINS",
                },
                "control_focus": {"owner": "CASTER_FOCUS", "exclusive_focus_slot": True},
                "provider": provider,
            },
        },
        "expression": {
            "caster_cue": {"pose_tag": "NONE", "cast_focus_ms": 0},
            "omen_profile": {
                "sky_darken": 0,
                "ambient_fog_tint_strength": 0,
                "environment_resonates": False,
                "omitted_during_instant_cast": False,
            },
            "audio_profile": {
                "drone_module": "NONE",
                "impact_module": "NONE",
                "sustain_loop_module": "NONE",
                "pre_delivery_silence_ms": 0,
            },
            "aftermath_profile": {"light_decay_s": 0, "leave_world_scars": False, "hitstop_local_ms": 0},
            "camera_impulse_level": 0,
        },
    }
    floor = budget_floor(doc, rules, set())
    provider["max_upfront_mana"] = floor["upfront"]
    provider["max_sustain_mana_per_s"] = floor["sustain"]
    doc["budget"] = {
        "compiler_status": "VALID",
        "peak_dynamic_bodies": 0,
        "peak_path_nodes": 0,
        "peak_surface_quads": 0,
        "peak_point_lights": 0,
        "derived_upfront_mana": floor["upfront"],
        "derived_sustain_mana_per_s": floor["sustain"],
        "derived_reserve_mana": 0,
        "estimated_tick_cost_us": profile["field_tick_estimate_us"],
    }
    admit(doc, rules)
    return doc


def plan_cost(subject, spatial, schedule, relations, rules):
    # Price the emitted kernels at their compiled ceilings. Unbound effects have no price yet.
    processes = []
    reserve = set()
    complete = True
    for step in schedule:
        op = step.get("kernel")
        if not op:
            complete = False
            continue
        p = {"id": step["id"], "on_enter": [], "while_active": [], "on_exit": []}
        phase = "while_active" if step["when"] in ("while_held", "while_supplied") else "on_enter"
        p[phase].append(op)
        processes.append(p)
        if "储备可用" in step["requires_all"]:
            reserve.add(step["id"])
    priced = {
        "subjects": [subject],
        "spatial": [spatial],
        "relations": relations,
        "process_graph": {"processes": processes},
        "contract": {"combat": {"control_focus": {"owner": "CASTER_FOCUS"}}},
    }
    floor = budget_floor(priced, rules, reserve)
    limits = rules.execution["hard_limits"]
    for key, limit in (
        ("upfront", "max_upfront_mana"),
        ("sustain", "max_sustain_mana_per_s"),
        ("reserve", "max_reserve_mana"),
    ):
        require(
            floor[key] <= limits[limit],
            "budget",
            "已绑定的能力成本超出上限",
            "BUDGET_EXCEEDED",
            floor=floor,
        )
    return {"floor": floor, "all_operations_priced": complete}


def lower(core, rules):
    profile = load("balance/offline_profile.json")
    subject, spatial = geometry(core, rules, profile)
    schedule = []
    gaps = []
    for proc in core["processes"]:
        op, bindings = kernel(proc, subject, rules, profile)
        step = {
            k: proc[k] for k in ("id", "after", "target", "when", "requires_all", "operation", "effects")
        }
        if "intervention" in proc:
            step["intervention"] = deepcopy(proc["intervention"])
        if op:
            step["kernel"] = op
        step.update(bindings)
        if "unmapped_effects" in bindings or "magnitude_from" in bindings:
            gaps.append(
                {
                    "process": proc["id"],
                    "reason": "运行期余额绑定"
                    if "magnitude_from" in bindings
                    else "缺少完整的执行操作绑定",
                }
            )
        schedule.append(step)
    impacts = rules.projections["expression_for_effect"]
    profiles = {r["id"]: r for r in load("art/expression_profiles.json")["profiles"]}
    expressions = [
        {"process": p["id"], "profile": profiles[impacts[e]]}
        for p in schedule
        for e in p["effects"]
        if e in impacts
    ]
    result = {
        "subject": subject,
        "spatial": spatial,
        "schedule": schedule,
        "control": core["contract"],
        "expression": expressions,
        "balance_profile": profile["id"],
        "remaining_bindings": gaps,
        "relations": core["relations"],
        "budget": plan_cost(subject, spatial, schedule, core["relations"], rules),
    }
    if not rules.legacy:
        result["spatial_bindings"] = {core["subjects"][0]["intent_ref"]: spatial["id"]}
    # A valid operand alone does not prove that the entire event graph is faithfully representable.
    if (
        subject["kind"] == "FIELD"
        and [s["operation"] for s in schedule] == ["Establish", "Withdraw"]
        and not gaps
        and schedule[1]["target"] == subject["id"]
    ):
        result["compiled_spell"] = field_document(subject, spatial, schedule, rules, profile)
        result["status"] = "COMPILED_SPELL"
    else:
        result["status"] = "GUARDED_PLAN"
    return result
