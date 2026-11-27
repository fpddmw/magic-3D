"""Offline admission for the one executable recipe. No rune-to-spell inference."""

from copy import deepcopy
from functools import lru_cache
from graphlib import CycleError, TopologicalSorter
from math import ceil, radians, sin

from jsonschema import Draft202012Validator

from .schema import REG, SCHEMA, TARIFF, read


class Diagnostic(ValueError):
    def __init__(self, code, path, message):
        self.report = {"code": code, "path": path, "message": message}
        super().__init__(f"{path}: {message}")


def check(condition, path, message, code="INVALID_RECIPE"):
    if not condition:
        raise Diagnostic(code, path, message)


@lru_cache(None)
def validator(kind):
    schema = read(SCHEMA)
    return Draft202012Validator({"$defs": schema["$defs"], "$ref": "#/$defs/" + kind})


def structure(value, kind):
    err = next(validator(kind).iter_errors(value), None)
    if err:
        raise Diagnostic("INVALID_STRUCTURE", err.json_path, err.message)


def index(rows):
    table = {r["id"]: r for r in rows}
    check(len(table) == len(rows), "id", "登记 ID 重复")
    return table


def order(parents):
    try:
        return list(TopologicalSorter(parents).static_order())
    except CycleError as exc:
        raise Diagnostic("UNBOUNDED_GRAPH", "graph", "循环依赖；重复须声明上限") from exc


def operations(node):
    for phase in ("enter", "active", "repeat", "exit"):
        for op in node.get("repeat", {}).get("actions", []) if phase == "repeat" else node[phase]:
            yield phase, op


def spatial_units(s, tariff):
    g = s["spatial"]["geometry"]
    # extent and solid angle both contribute; topological detail cannot reduce price.
    angle = sin(radians(g["half_angle_deg"])) ** 2 if g["shape"] == "cone" else 1
    detail = sum(g.get(k, 0) for k in ("nodes", "edges", "quads", "bodies"))
    return tariff["geometry"][s["spatial"]["carrier"]] * (
        1 + tariff["unit_per_m"] * (g["extent_m"] * (1 + angle) + detail)
    )


def price(recipe, tariff=TARIFF):
    units = sum(spatial_units(s, tariff) for s in recipe["Subjects"] if "spatial" in s)
    factor = tariff["scale"][recipe["scale"]] * (1 + units)
    contracts = index(recipe["Contracts"])
    upfront = tariff["base"] + units + len(recipe["Relations"]) * tariff["relation"]
    rates = {}
    capacity = 0
    impulse_budget = 0
    sustain_total = 0
    for n in recipe["Processes"]["nodes"]:
        rate = 0
        contract = contracts[n["contract"]]
        for phase, op in operations(n):
            amount = tariff["work"][op["ability"]] * factor
            if phase == "active":
                rate += amount
                if op["ability"] == "charge":
                    seconds = contract["reserve"]["full_charge_s"]
                    capacity = amount * seconds
                    impulse_budget = factor * seconds * tariff["world_units"]["impulse_per_work_s"]
            else:
                upfront += amount * (n["repeat"]["times"] if phase == "repeat" else 1)
        rates[n["id"]] = rate
        sustain_total += rate * contract["max_s"]

    def upper(x):
        return ceil(x * 1000000) / 1000000

    return {
        "tariff_version": tariff["version"],
        "upfront_mana": upper(upfront),
        "mana_per_s": upper(sum(rates.values())),
        "rates": rates,
        "max_paid_mana": upper(upfront + sustain_total),
        "reserve_capacity": capacity,
        "total_impulse_budget": impulse_budget,
    }


class Recipe:
    def __init__(self, data, tariff=TARIFF):
        data, tariff = deepcopy(data), deepcopy(tariff)
        structure(data, "Recipe")
        self.data = data
        self.tariff = tariff
        self.subjects = index(data["Subjects"])
        self.relations = index(data["Relations"])
        self.contracts = index(data["Contracts"])
        self.nodes = index(data["Processes"]["nodes"])
        concepts = index(data["Concepts"])
        ids = (
            list(concepts)
            + list(self.subjects)
            + list(self.relations)
            + list(self.contracts)
            + list(self.nodes)
        )
        check(len(ids) == len(set(ids)), "id", "所有声明共用本配方的 ID 空间")
        self.nature = {}
        quota = {k: 0 for k in ("bodies", "edges", "nodes", "quads")}
        for sid, s in self.subjects.items():
            check(s["concept"] in concepts, sid, "概念引用未登记")
            nature = concepts[s["concept"]]["nature"]
            self.nature[sid] = nature
            check(s.get("medium") == REG["required_media"].get(nature), sid, "主体缺少对应现场媒介")
            allowed = REG["natures"][nature]
            kind = s["source"]["kind"]
            check(s["kind"] == allowed[0], sid, "主体种类与本性不符")
            if s["kind"] == "WorldRef":
                check(kind == "Reference" and "spatial" not in s, sid, "世界引用须绑定实际槽位")
                continue
            check("spatial" in s, sid, "缺少空间")
            sp = s["spatial"]
            g = sp["geometry"]
            check(
                REG["geometry"][g["shape"]] == sp["carrier"] and sp["carrier"] in allowed,
                sid,
                "本性、几何、载体组合未获支持",
                "UNSUPPORTED_CAPABILITY",
            )
            check(
                kind in (("Borrow", "Derived") if nature == "water" else ("Manifest",)),
                sid,
                "当前材料/场的来源尚无有限绑定",
                "UNSUPPORTED_CAPABILITY",
            )
            if kind == "Borrow":
                src = self.subjects.get(s["source"]["ref"], {})
                check(src.get("kind") == "WorldRef", sid, "借用需要真实来源引用")
            if kind == "Derived":
                parent = self.subjects.get(s["source"]["ref"], {})
                check(
                    parent.get("source", {}).get("kind") == "Borrow"
                    and parent["concept"] == s["concept"]
                    and parent["spatial"] == sp
                    and sp["carrier"] == "Body",
                    sid,
                    "派生须承接同一份借入材料与空间",
                )
            check(
                sp["reference"]["anchor"] != "source" or kind in ("Borrow", "Derived"),
                sid,
                "源参照须有实际来源",
            )
            for k in quota:
                quota[k] += g.get(k, 0)
        limits = REG["limits"]
        for k, cap in (
            ("bodies", limits["bodies"]),
            ("edges", limits["path_edges"]),
            ("nodes", limits["path_nodes"]),
            ("quads", limits["surface_quads"]),
        ):
            check(quota[k] <= cap, k, "构筑总几何配额超限", "OVER_BUDGET")
        for rid, r in self.relations.items():
            sig = REG["channels"][r["channel"]]
            check(
                all(set(REG["interfaces"].get(self.nature.get(r[k]), [])) & set(sig[k]) for k in ("from","to")),
                rid,
                "关系端点本性与通道不符",
            )
            check(
                r["basis"] == sig["basis"] and r["validity"] == sig["validity"],
                rid,
                "关系缺少对应的成立依据或有效条件",
            )
        for sid, s in self.subjects.items():
            for prop in s.get("properties", []):
                rel = self.relations.get(prop["via"], {})
                sig = REG["properties"][prop["aspect"]]
                check(
                    rel.get("from") == sid
                    and rel.get("channel") == sig["channel"]
                    and any(
                        op["ability"] == sig["ability"] and op["target"] == prop["via"]
                        for n in self.nodes.values()
                        for _, op in operations(n)
                    ),
                    sid,
                    "额外性质缺少实际关系与对应过程",
                )
            if "initial_phase" in s:
                check(
                    s["kind"] == "Material" and s["source"]["kind"] in ("Borrow", "Derived"),
                    sid,
                    "初始材料相态须在来源上核实",
                )
        for cid, c in self.contracts.items():
            if c["provider"] == "@caster":
                check("supply_link" not in c, cid, "施法者账户直接供给")
            else:
                link = self.relations.get(c.get("supply_link"), {})
                check(
                    link.get("channel") == "arcane_supply" and link["from"] == c["provider"],
                    cid,
                    "供给须来自有效端点和供给关系",
                )
            check(
                c["focus"] != "exclusive" or c["controller"] == "caster", cid, "自主作用不能占用施法者专注"
            )
        check(
            set(self.contracts) == {n["contract"] for n in self.nodes.values()},
            "Contracts",
            "每份契约须绑定实际过程",
        )
        self.check_graph()
        self.quote = price(data, tariff)
        for k, cap in (
            ("upfront_mana", "mana_upfront"),
            ("mana_per_s", "mana_per_s"),
            ("reserve_capacity", "reserve"),
        ):
            check(self.quote[k] <= REG["limits"][cap], k, "确定性计费超出硬顶", "OVER_BUDGET")
        kit = REG["artkit"]
        tracks = data["Expression"]
        self.budgets = {
            "mana": self.quote,
            "physics": quota,
            "render": {"tracks": len(tracks), "layers": sum(sum(k in tr for k in REG["art"] if k != "focus") for tr in tracks)},
        }
        check(len(tracks) <= kit["max_tracks"] and self.budgets["render"]["layers"] <= kit["max_layers"], "Expression", "演出预算超限", "OVER_BUDGET")
        primaries = set()
        for tr in tracks:
            if "material" in tr:
                carrier = self.subjects.get(tr.get("subject"), {}).get("spatial", {}).get("carrier")
                check(carrier in kit["adapters"][tr["material"]], "Expression", "材质需要已登记的载体适配")
            if tr.get("focus") == "primary":
                slot = (tr["process"],tr["cue"])
                check(slot not in primaries,"Expression","同一过程事件出现两个主视觉")
                primaries.add(slot)
            pid = tr["process"]
            check(pid in self.nodes and any(k in tr for k in REG["art"] if k != "focus"), pid, "演出缺少过程或媒介模块")
            if tr["cue"] == "impact":
                check(
                    any(op["ability"] in ("impulse", "bear_load") for _, op in operations(self.nodes[pid])),
                    pid,
                    "命中提示缺少可交付的力学作用",
                )
            check(tr["bind"] != "fill_ratio" or self.charge_node is not None, pid, "缺少实际储备")
            check((tr["bind"] == "actual_impact") == (tr["cue"] == "impact"), pid, "命中提示须绑定真实交付")
            check(
                ("subject" in tr) == (tr["bind"] == "geometry")
                and ("subject" not in tr or "spatial" in self.subjects.get(tr["subject"], {})),
                pid,
                "几何轨道须绑定实际空间主体",
            )
        check(
            sum(
                t.get("visual") in ("ember_haze", "electric_arc", "imprint", "motes")
                for t in data["Expression"]
            )
            <= REG["limits"]["point_lights"],
            "Expression",
            "发光轨道配额超限",
            "OVER_BUDGET",
        )

    def check_graph(self):
        parents = {p: set() for p in self.nodes}
        entry = set(self.data["Processes"]["entry"])
        charge = []
        self.charge_node = None
        for pid, n in self.nodes.items():
            check(n["contract"] in self.contracts, pid, "局部契约不存在")
            c = self.contracts[n["contract"]]
            if "repeat" in n:
                rep = n["repeat"]
                check(rep["times"] * rep["interval_s"] <= c["max_s"], pid, "重复超出过程寿命")
            for phase, op in operations(n):
                sig = REG["abilities"][op["ability"]]
                t = op["target"]
                check(phase in sig["phases"], pid, "能力不支持该执行时机")
                if op["ability"] == "charge":
                    check(
                        t == "@reserve" and "reserve" in c and len(n["active"]) == 1,
                        pid,
                        "蓄积须有独占的有限储备",
                    )
                    check(c["reserve"]["full_charge_s"] <= c["max_s"], pid, "满蓄超过契约寿命")
                    charge.append(pid)
                else:
                    typ = self.relations.get(t, {}).get("channel", self.nature.get(t))
                    handle = (
                        t in self.relations or t in self.subjects and self.subjects[t]["kind"] != "WorldRef"
                    )
                    check(
                        handle and ("handle" in sig["targets"] or typ in sig["targets"] or set(REG["interfaces"].get(typ, [])) & set(sig["targets"])),
                        pid,
                        "操作目标与能力签名不符",
                    )
                    if op["ability"] in ("project","grow","fracture","handoff_world","solidify","melt"):
                        check(
                            self.subjects[t]["spatial"]["carrier"] == "Body",
                            pid,
                            "整体原位相变需单份材料实体",
                        )
                    if op["ability"] == "freeze":
                        check(
                            self.subjects[t]["spatial"]["carrier"] == "PathGraph",
                            pid,
                            "传播需要实际材料网络",
                        )
            if "reserve" in c:
                check(pid in charge, pid, "预付储备须绑定实际积蓄过程")
            if c["provider"] != "@caster":
                endpoint = self.relations[c["supply_link"]]["to"]
                check(
                    all(
                        op["target"] == endpoint
                        or self.relations.get(op["target"], {}).get("from") == endpoint
                        for _, op in operations(n)
                    ),
                    pid,
                    "供给关系只能支撑其绑定的作用",
                )
            events = {}
            for edge in n["on"]:
                for dest in edge["to"]:
                    check(dest in parents, pid, "后继不存在")
                    parents[dest].add(pid)
                guards = events.setdefault(edge["event"], set())
                check(edge["when"] not in guards, pid, "相同事件有歧义分支")
                guards.add(edge["when"])
                hs = edge.get("handoff", [])
                check(
                    len(hs) == len({h["handle"] for h in hs}) and all(h["to"] in edge["to"] for h in hs),
                    pid,
                    "每个句柄只能交给一个实际后继",
                )
                check(edge["event"] != "interrupt" or not edge["to"], pid, "打断只允许终止尚未交付的作用")
            check(
                all(len(v) == 1 or v == {"reserve_ready", "reserve_low"} for v in events.values()),
                pid,
                "条件分支重叠",
            )
        check(len(charge) <= 1, "@reserve", "一个施法实例只能有一个蓄积责任人")
        self.charge_node = charge[0] if charge else None
        seq = order(parents)
        check(entry == {p for p in seq if not parents[p]}, "Processes.entry", "入口必须恰好覆盖所有根过程")
        incoming = {p: [] for p in seq}
        formed = set()
        longest = {}
        ancestors = {}
        proven = {p: [] for p in seq}
        self.guaranteed_before = {}
        check(
            any(
                op["ability"] not in ("form", "end", "charge")
                for n in self.nodes.values()
                for _, op in operations(n)
            ),
            "Processes",
            "配方缺少可交付的世界作用",
        )
        for p in seq:
            n = self.nodes[p]
            c = self.contracts[n["contract"]]
            ancestors[p] = set(parents[p]).union(*(ancestors[q] for q in parents[p]))
            prior_sets = [self.guaranteed_before[q] | {q} for q in parents[p]]
            self.guaranteed_before[p] = (
                (set.union(*prior_sets) if n["join"] == "all" else set.intersection(*prior_sets))
                if prior_sets
                else set()
            )
            longest[p] = c["max_s"] + max((longest[q] for q in parents[p]), default=0)
            check(longest[p] <= 30, p, "过程链超过施法总时限")
            # An any-join must have the same linear inputs on every possible path.
            grouped = {}
            for parent, passed in incoming[p]:
                check(
                    parent not in grouped or grouped[parent] == passed,
                    p,
                    "同一前置过程在不同路径上交接内容不一致",
                )
                grouped[parent] = passed
            sets = list(grouped.values())
            if n["join"] == "any":
                ready = bool(proven[p]) and all(v for _, v in proven[p])
            else:
                ready = any(all(v for par, v in proven[p] if par == q) for q in parents[p])
            if n["join"] == "any":
                check(not sets or all(x == sets[0] for x in sets), p, "替代分支交接的句柄不一致")
            holds = set().union(*sets)
            for phase, op in operations(n):
                a, t = op["ability"], op["target"]
                if a == "form":
                    check(t not in formed, p, "句柄须有唯一建立点")
                    source = self.subjects.get(t, {}).get("source", {})
                    if source.get("kind") == "Derived":
                        parent = source["ref"]
                        check(parent in holds, p, "派生时须拥有原材料句柄")
                        check(
                            not any(
                                parent in (self.relations[h]["from"], self.relations[h]["to"])
                                for h in holds & self.relations.keys()
                            ),
                            p,
                            "材料仍有未交接的关系",
                        )
                        holds.remove(parent)
                    formed.add(t)
                    holds.add(t)
                elif a != "charge":
                    check(t in holds, p, "操作使用了未取得或已撤去的句柄")
                if t in self.relations:
                    for end in ("from", "to"):
                        sid = self.relations[t][end]
                        check(
                            self.subjects[sid]["kind"] == "WorldRef" or sid in holds,
                            p,
                            "关系端点缺少有效句柄",
                        )
                if a in ("end","handoff_world"):
                    holds.remove(t)
                if a == "impulse":
                    check(
                        self.charge_node in ancestors[p] and ready, p, "冲量需有上游已付储备及释放阈值证明"
                    )
            for edge in n["on"]:
                if edge["when"] != "always":
                    check(self.charge_node in ancestors[p] | {p}, p, "储备条件缺少蓄积过程")
                for dest in edge["to"]:
                    passed = {h["handle"] for h in edge.get("handoff", []) if h["to"] == dest}
                    check(passed <= holds, p, "交接未持有的句柄")
                    for t in passed & self.relations.keys():
                        check(
                            all(
                                self.subjects[self.relations[t][k]]["kind"] == "WorldRef"
                                or self.relations[t][k] in passed
                                for k in ("from", "to")
                            ),
                            p,
                            "交接关系时须一并交接实际端点",
                        )
                    incoming[dest].append((p, passed))
                    proven[dest].append((p, ready or edge["when"] == "reserve_ready"))
            # Remaining local handles are closed by the contract on every exit.
        self.parents = parents
        self.check_schedules()

    def check_schedules(self):
        # Enumerate finite control configurations, including alternative paths through a join.
        entry = frozenset(self.data["Processes"]["entry"])
        spends = {
            p: sum(op["ability"] == "impulse" for _, op in operations(n)) for p, n in self.nodes.items()
        }
        pending = [(entry, frozenset(), frozenset())]
        seen = set()
        reached = set()
        while pending:
            state = pending.pop()
            if state in seen:
                continue
            seen.add(state)
            active, done, signals = state
            reached.update(active)
            check(
                sum(spends[p] for p in active | done) <= 1,
                "@reserve",
                "同一条执行路径不能重复支取已交付的储备",
            )
            check(len(seen) <= 4096, "Processes", "控制组合超出静态分析上限", "OVER_BUDGET")
            check(
                sum(self.contracts[self.nodes[p]["contract"]]["focus"] == "exclusive" for p in active) <= 1,
                "Processes",
                "并行过程重复占用专注",
            )
            for p in active:
                for targets in {tuple(e["to"]) for e in self.nodes[p]["on"]} | {()}:
                    live = set(active) - {p}
                    sent = signals | {(p, t) for t in targets}
                    for t in targets:
                        if self.nodes[t]["join"] == "all" and not all(
                            (q, t) in sent for q in self.parents[t]
                        ):
                            continue
                        check(t not in live | done, p, "后继可能重复激活，请使用汇合")
                        live.add(t)
                    pending.append((frozenset(live), done | {p}, sent))
        check(reached == self.nodes.keys(), "Processes", "无法满足汇合或到达过程")
