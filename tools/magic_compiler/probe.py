"""Finite offline witnesses. Input physics and contact edges are supplied by the fixture."""

from copy import deepcopy
from heapq import heappop, heappush

from .rules import one, require


def conditions_met(step, observations):
    intervention = step.get("intervention")
    if intervention is None:
        guards = step["requires_all"]
    else:
        guards = intervention["basis"]["site_conditions"] + intervention["responsibility"]["conditions"]
        require(set(guards) == set(step["requires_all"]), step["id"], "干预与执行条件不一致")
    return all(observations.get(guard) is True for guard in guards)


def reserve_delivery(plan, held_seconds, supply, in_region=True, interrupted=False):
    require(held_seconds >= 0 and supply >= 0, "probe", "时间与可支付供给必须非负")
    steps = plan["schedule"]
    charge = one(
        [s for s in steps if s.get("kernel", {}).get("resource_kind") == "EU"], "probe", "缺少储备转移过程"
    )
    release = one(
        [s for s in steps if "magnitude_from" in s and charge["id"] in s["after"]], "probe", "缺少储备交付"
    )
    require(
        charge["when"] == "while_held" and release["when"] == "on_release",
        "probe",
        "该探针需要持咒和松手事件",
    )
    if "intervention" in release:
        scope = release["intervention"]["scope"]
        require(
            scope["kind"] == "in_region"
            and plan["spatial_bindings"].get(scope["ref"]) == plan["spatial"]["id"],
            release["id"],
            "域内观察必须绑定本次干预的局部空间",
        )
    transfer = charge["kernel"]
    balance = min(supply, held_seconds * transfer["rate_per_s"], transfer["max_amount"])
    charge_ready = conditions_met(
        charge, {"持续供给": supply > 0, "储备有余容": transfer["max_amount"] > 0}
    )
    release_ready = conditions_met(release, {"储备可用": balance > 0, "实际域内": in_region})
    if interrupted or not (charge_ready and release_ready):
        return {"status": "WITHHELD", "delivered": 0}
    op = deepcopy(release["kernel"])
    op["magnitude"] = min(op["magnitude"], balance * release["magnitude_from"]["per_unit"])
    return {"status": "DELIVERED", "delivered": op["magnitude"], "operation": op}


def phase_front(plan, scene, cut=None):
    step = one([s for s in plan["schedule"] if "traversal" in s], "probe", "没有可核对的传播过程")
    conditions = {
        "已有材料": bool(scene["liquid_parts"]),
        "储备可用": scene.get("reserve_available") is True,
        "主动释放": scene["at"] == "on_release",
        "强制中断": scene["at"] == "on_interrupt",
    }

    def enabled(s):
        return (
            s["when"] == scene["at"]
            and set(s["after"]) <= set(scene.get("completed", []))
            and conditions_met(s, conditions)
        )

    if not enabled(step):
        return {
            "status": "WITHHELD",
            "frozen": [],
            "operations": [s["operation"] for s in plan["schedule"] if enabled(s)],
        }
    if "intervention" in step:
        scope = step["intervention"]["scope"]
        require(
            scope == {"kind": "connected_material", "ref": step["material"]}
            and plan["spatial_bindings"].get(scope["ref"]) == plan["spatial"]["id"],
            step["id"],
            "传播范围必须绑定本次干预的同一材料",
        )
    op = step["kernel"]
    policy = op["propagation"]
    tr = step["traversal"]
    binding = step["origin_binding"]
    require(
        tr["domain"] == policy["domain"]
        and tr["connectivity_policy"] == policy["connectivity_policy"]
        and tr["read_at"] == "frontier_step"
        and binding["execution_ref"] == policy["origin_ref"],
        "probe",
        "传播策略不兼容",
    )
    parts = set(scene["liquid_parts"])
    origin = scene["origin_binding"].get(binding["lookup"])
    if origin not in parts:
        return {"status": "MISSING_BINDING", "frozen": [], "policy": policy["on_missing_origin"]}
    require(
        policy["attenuation"] == 0 and tr["vertex_state"] == "liquid", "probe", "本探针仅核对零衰减液态材料"
    )
    limit = min(policy["max_reach_m"], scene["observe_at_s"] * policy["speed_m_s"])
    # A shorter route may use more hops. Keep both dimensions until the frontier is settled.
    pending = [(0, 0, origin)]
    labels = {}
    edges = deepcopy(scene["edges"])
    require(all(e["length_m"] > 0 for e in edges), "probe", "边长必须为正")
    while pending:
        distance, hops, part = heappop(pending)
        if distance > limit or hops > policy["max_hops"]:
            continue
        if any(d <= distance and h <= hops for d, h in labels.get(part, [])):
            continue
        labels.setdefault(part, []).append((distance, hops))
        if cut and part == cut["before_departure_from"]:
            edges[cut["edge_index"]]["state"] = "broken"
        for edge in edges:
            if edge["kind"] != tr["edge_kind"] or edge["state"] != tr["edge_state"]:
                continue
            if part not in (edge["a"], edge["b"]):
                continue
            dest = edge["b"] if part == edge["a"] else edge["a"]
            if dest in parts:
                heappush(pending, (distance + edge["length_m"], hops + 1, dest))
    return {"status": "DELIVERED", "frozen": sorted(labels), "liquid": sorted(parts - labels.keys())}


def check_at_use(artifact, term, observations):
    """Test a specific use site without asserting that every phase is active at once."""
    require(term in artifact["evidence"], term, "未登记词项")
    missing = [key for key in artifact["evidence"][term]["at_use"] if observations.get(key) is not True]
    return {"status": "MISSING_BINDING" if missing else "BOUND", "missing": missing}
