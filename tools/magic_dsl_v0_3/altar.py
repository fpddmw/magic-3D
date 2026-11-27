"""Altar boundary. The generator is injected and is never called by a saved recipe."""

from copy import deepcopy

from .admission import Diagnostic, Recipe, check, index, operations, order, structure
from .schema import REG, TARIFF


def reading(recipe):
    """Render only facts admitted in the recipe. The candidate's prose is never displayed here."""
    q = recipe.quote
    labels = {
        "small": "小型",
        "medium": "中型",
        "large": "大型",
        "air": "气压场",
        "light": "光场",
        "heat": "热场",
        "electric": "电作用",
        "gravity": "局部重力",
        "water": "水体",
        "site": "现场参照",
        "reservoir": "实存储备",
        "cone": "锥体",
        "sphere": "球域",
        "sheet": "界面",
        "network": "连通网络",
        "mass": "实体",
        "caster": "施法者",
        "@caster": "施法者",
        "@reserve": "本次储备",
        "source": "来源位置",
        "autonomous": "契约自主维持",
        "slow_walk": "慢步",
        "rooted": "驻足",
        "free": "自由移动",
        "exclusive": "占用专注",
        "none": "无需专注",
        "cast": "施法开始时捕获",
        "enter": "进入时",
        "live": "持续读取",
        "active": "持续期间",
        "exit": "退出时",
        "repeat": "每次脉动",
        "uniform": "均匀分布",
        "linear_falloff": "随距离线性衰减",
        "self": "只及自身",
        "within_field": "限域内有效对象",
        "mechanical": "传力",
        "optical": "光学",
        "information": "信息",
        "arcane_supply": "奥术供给",
        "nature": "本性",
        "aether": "以太支撑",
        "linked": "实际供给连接有效",
        "contact": "实际接触",
        "sight": "视线穿过",
        "disturbance": "出现可观测扰动",
        "aim": "瞄准方向",
        "up": "世界向上",
        "aim_point": "瞄点",
        "target": "目标位置",
        "radial_in": "径向内收",
        "radial_out": "径向外推",
        "tangential": "绕世界上轴切向",
        "earth": "土石",
        "fire": "火",
        "mist": "雾",
        "down": "世界向下",
        "distance_weighted": "近处权重较高",
        "equal": "按分布权重平分",
        "release": "松手",
        "interrupt": "被打断",
        "timeout": "到期",
        "signal": "收到信号",
        "ready": "进入就绪",
        "reserve_ready": "已达到实付阈值",
        "reserve_low": "未达实付阈值",
    }

    def label(key):
        return labels.get(key, key)

    lines = [
        f"{recipe.data['name']}（{label(recipe.data['scale'])}）。建立时支付 {q['upfront_mana']:g} 魔力。按所有过程保守估算，每秒供给上限为 {q['mana_per_s']:g}。"
    ]
    for sid, s in recipe.subjects.items():
        src = s["source"]
        if s["kind"] == "WorldRef":
            lines.append(f"{sid} 读取现场的 {src['slot']}。")
            continue
        space = s["spatial"]
        g = space["geometry"]
        source = {"Manifest": "由施法者具现", "Borrow": "借自", "Derived": "承接同一份材料"}[
            src["kind"]
        ] + src.get("ref", "")
        angle = f"，半角 {g['half_angle_deg']}°" if "half_angle_deg" in g else ""
        ref = space["reference"]
        lines.append(
            f"{sid} 为{('纯奥术' if recipe.nature[sid] == 'aether' else label(recipe.nature[sid]))}，{source}。{label(g['shape'])}延伸 {g['extent_m']} 米{angle}，{label(space['distribution'])}，{label(space.get('scope', 'within_field'))}。参照取{label(ref['anchor'])}，{label(ref['bind'])}绑定。"
        )
        if s.get("medium") == "ambient_air":
            lines.append("交付时需要现场有空气。")
        if "initial_phase" in s:
            lines.append("开始时须有" + {"liquid": "液态", "solid": "固态"}[s["initial_phase"]] + "材料。")
    for rid, r in recipe.relations.items():
        lines.append(
            f"{rid} 从 {r['from']} 向 {r['to']} 建立{label(r['channel'])}关系，依据为{label(r['basis'])}，要求{label(r['validity'])}。"
        )
    for pid, node in recipe.nodes.items():
        c = recipe.contracts[node["contract"]]
        lines.append(
            f"{pid} 最长 {c['max_s']} 秒，由{label(c['controller'])}控制，{label(c['focus'])}，{label(c['mobility'])}。{label(c['provider'])}承担每秒 {q['rates'][pid]:g} 的供给。"
        )
        if "reserve" in c:
            reserve = c["reserve"]
            lines.append(
                f"足额供给 {reserve['full_charge_s']} 秒可蓄满，实际付到满额的 {100 * reserve['min_release_ratio']:.6g}% 即可交付。满蓄总冲量上限 {q['total_impulse_budget']:g}，所有有效对象共享。"
            )
        for phase, op in operations(node):
            details = []
            if "axis" in op:
                details.append(label(op["axis"]))
            if "allocation" in op:
                details.append(label(op["allocation"]))
            if "propagation" in op:
                prop = op["propagation"]
                details.append(
                    f"每秒 {prop['speed_m_s']} 米，最远 {prop['reach_m']} 米、最多 {prop['hops']} 跳，缺起点时停止"
                )
            if op["ability"] == "bear_load":
                details.append(
                    f"共同承载上限 {recipe.tariff['scale'][recipe.data['scale']] * recipe.tariff['world_units']['load_capacity']:g}，过载后破裂"
                )
            lines.append(
                f"{label(phase)}对 {label(op['target'])} {REG['abilities'][op['ability']]['readout']}"
                + ("（" + "，".join(details) + "）" if details else "")
                + "。"
            )
        if "repeat" in node:
            lines.append(f"每 {node['repeat']['interval_s']} 秒触发，最多 {node['repeat']['times']} 次。")
        for edge in node["on"]:
            condition = "" if edge["when"] == "always" else "且" + label(edge["when"])
            dest = "进入 " + "、".join(edge["to"]) if edge["to"] else "结束"
            lines.append(f"{label(edge['event'])}{condition}时{dest}。")
            for h in edge.get("handoff", []):
                lines.append(f"把 {h['handle']} 的存续责任交给 {h['to']}。")
    lines.append("施法者被打断时终止其尚未交付的作用，已发生的世界变化保留。")
    return lines


def check_input(data):
    structure(data, "CompilationInput")
    graph = data["RuneGraph"]
    nodes = index(graph["nodes"])
    groups = index(graph["links"])
    refs = nodes.keys() | groups.keys()
    check(not (nodes.keys() & groups.keys()), "RuneGraph", "节点与组合 ID 冲突")
    order_map = {k: set() for k in refs}
    for k, g in groups.items():
        check(set(g["members"]) <= refs, k, "组合成员不存在")
        order_map[k].update(g["members"])
    ordering = {k: set() for k in nodes}
    leaves = {}
    for k in order(order_map):
        leaves[k] = {k} if k in nodes else set().union(*(leaves[m] for m in groups[k]["members"]))
    for g in groups.values():
        if g["kind"] == "发生接续":
            for left, right in zip(g["members"], g["members"][1:]):
                for dest in leaves[right]:
                    ordering[dest].update(leaves[left])
    order(ordering)
    caps = set(data["SupportedCapabilities"])
    for k, n in nodes.items():
        check(n["rune"] in data["PlayerKnowledge"], k, "玩家尚未掌握该符文")
        check(n["rune"] not in REG["deferred_runes"], k, "该符文尚未开放试构", "UNSUPPORTED_CAPABILITY")
    for a in data["SemanticAnchors"]:
        check(
            a["ref"] in refs and a["mechanism"] in caps,
            "SemanticAnchors",
            "锚点所指或能力不可用",
            "UNSUPPORTED_CAPABILITY",
        )
    return leaves


def accept(data, candidate):
    refs = check_input(data)
    structure(candidate, "CompilationOutput")
    recipe = Recipe(candidate["MagicDSL"])
    capabilities = set(data["SupportedCapabilities"])
    ops = {p: list(operations(n)) for p, n in recipe.nodes.items()}
    used = {op["ability"] for rows in ops.values() for _, op in rows}
    check(used <= capabilities, "MagicDSL", "超出本次构筑允许的能力", "UNSUPPORTED_CAPABILITY")
    nodes = index(data["RuneGraph"]["nodes"])
    rows = candidate["RuneContributions"]
    contrib = {r["node"]: set(r["refs"]) for r in rows}
    check(
        len(rows) == len(contrib) and contrib.keys() == nodes.keys(),
        "RuneContributions",
        "须逐枚解释全部符文",
    )
    local = (
        recipe.nodes.keys()
        | recipe.subjects.keys()
        | recipe.relations.keys()
        | index(recipe.data["Concepts"]).keys()
        | recipe.contracts.keys()
    )
    check(all(r <= local for r in contrib.values()), "RuneContributions", "贡献引用悬空")
    groups = index(data["RuneGraph"]["links"])

    def targets(ref):
        return set().union(*(contrib[node] for node in refs[ref]))

    def realized(anchor):
        evidence = targets(anchor["ref"])
        for pid, actions in ops.items():
            contract = recipe.contracts[recipe.nodes[pid]["contract"]]
            supply = "caster" if contract["provider"] == "@caster" else "linked_reserve"
            for phase, op in actions:
                if not (pid in evidence or op["target"] in evidence):
                    continue
                actual = {
                    "mechanism": op["ability"],
                    "phase": phase,
                    "controller": contract["controller"],
                    "supply": supply,
                }
                sid = recipe.relations.get(op["target"], {}).get("from", op["target"])
                spatial = recipe.subjects.get(sid, {}).get("spatial", {})
                actual.update(axis=op.get("axis"), anchor=spatial.get("reference", {}).get("anchor"))
                if all(anchor.get(k, v) == v for k, v in actual.items()):
                    return True
        return False

    def conflicts(anchor):
        if "axis" not in anchor:
            return False
        opposition = {"up": "down", "down": "up", "radial_in": "radial_out", "radial_out": "radial_in"}
        opposite = opposition.get(anchor["axis"])
        if opposite is None:
            return False
        support = targets(anchor["ref"])
        for pid, actions in ops.items():
            for phase, op in actions:
                if pid not in support and op["target"] not in support:
                    continue
                if phase != anchor.get("phase", phase) or op["ability"] != anchor["mechanism"]:
                    continue
                if op.get("axis") == opposite:
                    return True
        return False

    for anchor in data["SemanticAnchors"]:
        check(not conflicts(anchor), "SemanticAnchors", "补全在同一锚定范围引入相反方向", "ANCHOR_MISMATCH")
        check(
            not (set(anchor.get("exclude", [])) & used),
            "SemanticAnchors",
            "补全引入玩家排除的机制",
            "ANCHOR_MISMATCH",
        )
        check(realized(anchor), "SemanticAnchors", "配方未兑现所锚定局部的作用或责任", "ANCHOR_MISMATCH")
    for group in groups.values():
        if group["kind"] == "发生接续":
            for left, right in zip(group["members"], group["members"][1:]):
                # Only explicit process witnesses prove an ordering in the authored graph.
                before = targets(left) & recipe.nodes.keys()
                after = targets(right) & recipe.nodes.keys()
                check(
                    before and after and all(before <= recipe.guaranteed_before[p] for p in after),
                    group["id"],
                    "接续的符文须指向有因果先后的具体过程",
                    "ANCHOR_MISMATCH",
                )
    spaces = [s["spatial"] for s in recipe.subjects.values() if "spatial" in s]
    target = data["CastingContext"]["target"]
    if target == "self":
        check(
            all(s.get("scope") == "self" for s in spaces),
            "CastingContext",
            "自身意向须显式限定实际作用对象",
        )
    if target == "aim":
        check(
            any(
                s["geometry"]["shape"] == "cone" or s["reference"]["anchor"] in ("aim_point", "target")
                for s in spaces
            )
            or any(op.get("axis") == "aim" for rows in ops.values() for _, op in rows),
            "CastingContext",
            "缺少瞄准参照",
        )
    timing = data["CastingContext"]["timing"]
    if timing == "charge":
        check(recipe.charge_node is not None, "CastingContext", "要求蓄力")
    if timing == "instant":
        check(
            any(
                phase == "enter" and op["ability"] not in ("form", "end")
                for p in recipe.data["Processes"]["entry"]
                for phase, op in ops[p]
            ),
            "CastingContext",
            "即时意向须在进入时交付",
        )
    if timing == "remain":
        check(
            any(c["controller"] == "autonomous" for c in recipe.contracts.values())
            or bool(used & {"freeze", "solidify", "warm", "conduct"}),
            "CastingContext",
            "留存意向缺少自主责任或实际留存变化",
        )
    alternatives = set()
    for a in candidate["AlternativeAnchors"]:
        pair = tuple(a.get(k) for k in ("ref", "mechanism", "phase", "controller", "supply"))
        check(
            a["ref"] in refs
            and a["mechanism"] in capabilities
            and a.get("phase", REG["abilities"][a["mechanism"]]["phases"][0])
            in REG["abilities"][a["mechanism"]]["phases"]
            and not realized(a)
            and pair not in alternatives,
            "AlternativeAnchors",
            "备选须有可支持的不同作用",
        )
        alternatives.add(pair)
    return {
        "MagicDSL": deepcopy(recipe.data),
        "reading": reading(recipe),
        "quote": recipe.quote,
        "alternatives": deepcopy(candidate["AlternativeAnchors"]),
        "knowledge_version": REG["knowledge"],
        "profile": REG["profile"],
    }


def reanchor(data, anchor):
    updated = deepcopy(data)
    updated["SemanticAnchors"] = [a for a in updated["SemanticAnchors"] if a["ref"] != anchor["ref"]] + [
        deepcopy(anchor)
    ]
    check_input(updated)
    return updated


def compile_at_altar(data, generate, *, prior_expectation=None, repair=False):
    """One generation normally; one diagnostic repair is possible when explicitly enabled."""
    check_input(data)
    raw = generate(deepcopy(data), None)
    record = {
        "input": deepcopy(data),
        "candidate": deepcopy(raw),
        "corrected": None,
        "diagnostics": [],
        "observations": [],
        "observation_source": "offline-0.3.0",
        "preference": None,
        "prior_expectation": prior_expectation,
        "tariff_version": TARIFF["version"],
    }
    try:
        accepted = accept(data, raw)
    except Diagnostic as exc:
        record["diagnostics"].append(exc.report)
        if not repair:
            return None, record
        corrected = generate(deepcopy(data), {"candidate": deepcopy(raw), "diagnostic": exc.report})
        try:
            accepted = accept(data, corrected)
        except Diagnostic as second:
            record["diagnostics"].append(second.report)
            return None, record
        record["corrected"] = corrected
    return accepted, record


def record_observations(record, result):
    for event in result["events"]:
        if event["event"] == "effect":
            for key, value in event["objects"].items():
                record["observations"].append(
                    {"ability": event["ability"], "world_object": key, "value": value, "at_s": event["at"]}
                )
    structure(record, "TrainingRecord")
    return record
