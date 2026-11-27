"""Offline admission for frozen v0.2.2 documents; all numeric rates belong to the registry."""

from collections import defaultdict
from graphlib import CycleError, TopologicalSorter

from .rules import Diagnostic, require, validate


def operations(process):
    for phase in ("on_enter", "while_active", "on_exit"):
        for op in process[phase]:
            yield phase, op


def budget_floor(spell, rules, reserve_nodes):
    cost = rules.balance["budget_formula"]
    upfront, reserve, sustain = cost["upfront_base"], 0.0, 0.0
    subjects = {s["id"]: s for s in spell["subjects"]}
    relations = {r["id"]: r["channel"] for r in spell["relations"]}
    for s in subjects.values():
        if s["kind"] == "FIELD":
            upfront += (
                cost["field_base"]
                + cost["field_per_initial_intensity"] * s["initial_intensity"]
                + cost["field_per_max_intensity"] * s["max_intensity"]
            )
        elif s["kind"] == "MATERIAL":
            upfront += cost["material_base"] + cost["material_per_initial_mu"] * s["initial_inventory_mu"]
        else:
            upfront += cost["world_ref_base"]
    for sp in spell["spatial"]:
        family = {"PATH_GRAPH": "path", "BODY": "body", "SURFACE": "surface", "REGION": "region"}[
            sp["carrier"]
        ]
        upfront += cost[f"spatial_{family}_per_extent_m"] * sp["initial_extent_m"]
        if family == "path":
            upfront += (
                cost["spatial_path_per_node"] * sp["node_budget"]
                + cost["spatial_path_per_edge"] * sp["edge_budget"]
            )
        if family == "surface":
            upfront += cost["spatial_surface_per_quad"] * sp["quad_budget"]
    upfront += len(relations) * cost["relation_each"]
    focused = spell["contract"]["combat"]["control_focus"]["owner"] == "CASTER_FOCUS"
    for p in spell["process_graph"]["processes"]:
        deferred = p["id"] in reserve_nodes
        for phase, op in operations(p):
            tag = op["op"]
            fee = 0
            ongoing = phase == "while_active" and not deferred and focused
            if tag == "DRIVE":
                if op["mode"] == "IMPULSE":
                    fee = cost["impulse_per_magnitude"] * op["magnitude"]
                elif ongoing:
                    sustain += cost["continuous_drive_sustain_base"] + cost[
                        "continuous_drive_sustain_per_magnitude"
                    ] * abs(op["magnitude"])
            elif tag == "TRANSFER":
                fee = cost["transfer_upfront_per_max_amount"] * op["max_amount"]
                if ongoing:
                    sustain += cost["transfer_sustain_per_rate"] * op["rate_per_s"]
            elif tag == "CONSTRAIN":
                fee = cost["constrain_upfront_per_capacity_lu"] * op["capacity_lu"]
                if ongoing and op["provider_ref"] == "CASTER_MANA":
                    sustain += cost["constrain_sustain_per_capacity_lu"] * op["capacity_lu"]
            elif tag == "TRANSFORM":
                transform = op["transform_id"]
                if transform in ("PHASE_CHANGE", "STRUCTURAL_CRYSTALLIZE"):
                    fee = cost["transform_phase_change_per_capacity_mu"] * subjects[
                        op["target_subject_id"]
                    ].get("capacity_mu", 0)
                elif transform == "SUBDIVIDE":
                    fee = cost["transform_subdivide_per_output_body"] * op["max_output_bodies"]
                elif transform != "DISSIPATE":
                    fee = cost["transform_other_flat"]
            elif (
                tag == "COUPLE"
                and focused
                and not deferred
                and relations[op["relation_id"]] in ("DISTURBANCE_TO_PERCEPTION", "ENERGY_FEED")
            ):
                sustain += cost["couple_sustain_perception_or_feed"]
            if "propagation" in op:
                prop = op["propagation"]
                fee += cost["propagation_per_reach_m"] * prop["max_reach_m"] + cost[
                    "propagation_per_hop"
                ] * prop.get("max_hops", 0)
            if deferred:
                reserve += fee
            else:
                upfront += fee
    if reserve_nodes:
        reserve = max(reserve, cost["min_reserve_when_reserve_used"])
    return {
        key: round(value, 6)
        for key, value in zip(("upfront", "sustain", "reserve"), (upfront, sustain, reserve))
    }


def admit(spell, rules, kind="spell"):
    stage1, stage2, stage3, stage4 = (
        "STAGE_1_STRUCTURE",
        "STAGE_2_SEMANTIC",
        "STAGE_3_CAPABILITY",
        "STAGE_4_BUDGET_ARTKIT",
    )
    if kind == "intent":
        validate(spell, "semantic_intent_v0_2", status=stage1)
        return
    validate(spell, "magic_dsl_v0_2", status=stage1)
    declared = set()

    def ids(rows):
        values = {r["id"] for r in rows}
        require(len(values) == len(rows) and not declared & values, "id", "标识重复", stage2)
        declared.update(values)
        return values

    subjects = {s["id"]: s for s in spell["subjects"]}
    ids(spell["subjects"])
    for s in subjects.values():
        if s["kind"] == "MATERIAL":
            require(
                s["initial_phase"] in rules.execution["material_valid_initial_phases"][s["material_id"]],
                s["id"],
                "相态不适用",
                stage1,
            )
            require(s["initial_inventory_mu"] <= s["capacity_mu"], s["id"], "库存超出容量", stage2)
    relations = ids(spell["relations"])
    ids(spell["spatial"])
    spatial_for = set()
    matrix = rules.execution["capability_matrix"]
    for sp in spell["spatial"]:
        require(sp["subject_id"] in subjects, sp["id"], "空间主体不存在", stage2)
        s = subjects[sp["subject_id"]]
        kind_key = "material_x_carrier" if s["kind"] == "MATERIAL" else "field_x_carrier"
        material = s.get("material_id", s.get("field_channel", ""))
        permission = matrix[kind_key].get(material + "|" + sp["carrier"])
        require(permission in ("SUPPORTED", "LIMITED"), sp["id"], "能力矩阵未准入", stage3)
        limited = matrix["limited_conditions"]
        if material == "ICE" and sp["carrier"] == "PATH_GRAPH":
            require(
                sp["node_budget"] <= limited["ICE_PATH_GRAPH_MAX_NODES"],
                sp["id"],
                "冰路径超过许可节点数",
                stage3,
            )
        if material == "SPATIAL_BARRIER":
            require(
                sp["carrier"] == limited["SPATIAL_BARRIER_REQUIRED_CARRIER"],
                sp["id"],
                "空间屏障载体不适用",
                stage3,
            )
        if "spawn_subject_id" in sp["reference"]:
            require(sp["reference"]["spawn_subject_id"] in subjects, sp["id"], "生成参照主体不存在", stage2)
        spatial_for.add(s["id"])
    for r in spell["relations"]:
        for ref in (r["source_ref"], r["target_ref"]):
            if ref.startswith("SUBJECT:"):
                require(ref[8:] in subjects, r["id"], "端点不存在", stage2)
    graph = spell["process_graph"]
    proc_ids = ids(graph["processes"])
    entries = set(graph["entry_processes"])
    require(entries <= proc_ids, "entry_processes", "入口不存在", stage2)
    processes = {p["id"]: p for p in graph["processes"]}
    parents = {k: set() for k in processes}
    handles = set()
    for key, p in processes.items():
        for _, op in operations(p):
            if "target_subject_id" in op:
                require(op["target_subject_id"] in subjects, key, "目标主体不存在", stage2)
            if "relation_id" in op:
                require(op["relation_id"] in relations, key, "关系不存在", stage2)
            for ref in (
                op.get("source_ref", ""),
                op.get("target_ref", ""),
                op.get("anchor_ref", ""),
                op.get("direction", {}).get("center_ref", ""),
                op.get("propagation", {}).get("origin_ref", ""),
            ):
                if ref.startswith("SUBJECT:"):
                    require(ref[8:] in subjects, key, "操作引用的主体不存在", stage2)
            if op["op"] == "WITHDRAW" and op["target_scope"] == "SUBJECT_SUPPORTS":
                require(op.get("target_id") in subjects, key, "撤除支持的主体不存在", stage2)
            if op["op"] == "ESTABLISH":
                subject = op["target_kind"] == "SUBJECT"
                target = op["target_id"]
                require(target in (subjects if subject else relations), key, "创建目标不存在", stage2)
                if (
                    subject
                    and subjects[target]["kind"]
                    in rules.execution["process_graph_rules"]["require_spatial_for_subject_kinds"]
                ):
                    require(target in spatial_for, key, "创建主体缺少空间", stage2)
            if "handle_id" in op:
                h = op["handle_id"]
                require(h not in handles and h not in declared, key, "重复句柄", stage2)
                handles.add(h)
        for tr in p["transitions"]:
            children = set(tr["next_process_ids"])
            require(children <= proc_ids, key, "转移目标不存在", stage2)
            require(
                len(children) == len(tr["next_process_ids"])
                and len(set(tr["handoff_handles"])) == len(tr["handoff_handles"]),
                key,
                "转移或交接有重复项",
                stage2,
            )
            if tr["event_source_filter"]["scope"] == "SUBJECT":
                require(
                    tr["event_source_filter"].get("subject_id") in subjects,
                    key,
                    "事件来源主体不存在",
                    stage2,
                )
            require(not tr["handoff_handles"] or len(children) == 1, key, "线性句柄不能广播", stage2)
            for child in children:
                parents[child].add(key)
    try:
        order = list(TopologicalSorter(parents).static_order())
    except CycleError as exc:
        raise Diagnostic(stage2, "process_graph", "执行图含环") from exc
    incoming = defaultdict(list)
    reserve = set()
    for key in order:
        if key in entries:
            incoming[key].append(set())
        require(incoming[key], key, "不可达的执行过程", stage2)
        owned = set.intersection(*incoming[key])
        for _, op in operations(processes[key]):
            if "handle_id" in op:
                owned.add(op["handle_id"])
            if op["op"] == "WITHDRAW" and op["target_scope"] == "HANDLE":
                require(op.get("target_id") in owned, key, "撤除未持有的句柄", stage2)
                owned.remove(op["target_id"])
        for tr in processes[key]["transitions"]:
            handoff = set(tr["handoff_handles"])
            require(handoff <= owned, key, "交接未持有的句柄", stage2)
            for child in tr["next_process_ids"]:
                incoming[child].append(handoff)
                if tr["action"] == "HANDOFF_TO_RESERVE" or key in reserve:
                    reserve.add(child)
    floor = budget_floor(spell, rules, reserve)
    budget = spell["budget"]
    provider = spell["contract"]["combat"]["provider"]
    for key, field, cap in (
        ("upfront", "derived_upfront_mana", "max_upfront_mana"),
        ("sustain", "derived_sustain_mana_per_s", "max_sustain_mana_per_s"),
        ("reserve", "derived_reserve_mana", "post_release_reserve_mana"),
    ):
        require(
            floor[key] <= budget[field] + 1e-6 and budget[field] <= provider[cap] + 1e-6,
            "budget." + field,
            "能力费用或供给上限不符",
            stage4,
            minimum=floor[key],
            declared=budget[field],
        )
    return floor
