from collections import defaultdict

from .intervention import certify
from .rules import one, require, validate


class Builder:
    """Attach each action to a licensed term, its subject and an earlier cause."""

    def __init__(self, resolution):
        self.r = resolution
        self.core = {k: [] for k in ("concepts", "subjects", "relations", "processes")}
        self.core["obligations"] = resolution.obligations
        self.outputs = defaultdict(list)
        self.used = set()
        self.reused = set()
        self.bound_intents = set()
        self.by_fact = defaultdict(list)
        for addr, term in self.r.terms.items():
            if "reuse" not in term:
                for fact in term["grant"]:
                    self.by_fact[fact].append(addr)
        spaces = [(ref, node, f) for ref, (node, f) in resolution.intents.items() if "spatial_intent" in f]
        require(spaces, "graph", "缺少施法主体的空间选择", "UNSUPPORTED_COMPOSITION")
        self.ref, self.shape_node, fields = one(spaces, "graph", "首批构造要求能唯一确定作用主体")
        self.space = fields["spatial_intent"]
        self.bound_intents.add(self.ref)
        self.actions = self.r.rules.construction["actions"]
        self.held = False
        self.prepaid = False
        self.ongoing = False

    def use(self, fact, relative=None, upstream=True):
        addr = one(self.by_fact[fact], fact, "作用主体或语义依据不能唯一确定")
        node = self.r.terms[addr]["node"]
        if relative:
            before, after = (node, relative) if upstream else (relative, node)
            require(before == after or before in self.r.ancestors[after], addr, "缺少作用域依赖")
        self.used.add(addr)
        return node

    def choice(self, node, key, value=None):
        ref, fields = one(
            [
                (h, f)
                for h, (n, f) in self.r.intents.items()
                if n == node and key in f and (value is None or f[key] == value)
            ],
            node,
            "缺少可绑定的过程选择",
        )
        self.bound_intents.add(ref)
        return {"intent_ref": ref, **fields}

    def evidence(self, node, *facts):
        available = set()
        for term in self.r.terms.values():
            if term["node"] == node:
                available.update(term["facts"])
        require(
            set(facts) <= available, node, "缺少本阶段的显式契约", missing=sorted(set(facts) - available)
        )

    def add(self, kind, node, ident, **fields):
        self.core[kind].append({"id": ident, **fields})
        self.outputs[node].append(ident)
        return ident

    def concept(self, node, ident, concept):
        return self.add("concepts", node, ident, concept=concept)

    def subject(self, node, concept, borrow=False):
        return self.add(
            "subjects",
            node,
            "subject",
            concept_ref=concept,
            source="Borrow" if borrow else "Manifest",
            source_ref="@source" if borrow else "@caster",
            binding="从可达来源取材" if borrow else "由施法者提供形成投入",
            intent_ref=self.ref,
            spatial_intent=self.space,
        )

    def relation(self, node, ident, source, target, channel, condition):
        return self.add(
            "relations",
            node,
            ident,
            **{"from": source, "to": target, "channel": channel, "condition": condition},
        )

    def action(self, node, ident, rule, target, after=(), choice=None):
        fields = dict(self.actions[rule])
        if choice:
            for k in ("operation", "effects", "when"):
                require(choice.get(k, fields[k]) == fields[k], node, "构造过程与所选事件或效果冲突：" + k)
            fields.update(choice)
        if not self.r.rules.legacy:
            intervention = certify(self, node, rule, target, after, fields)
            fields["intervention"] = intervention
            fields["requires_all"] = list(
                dict.fromkeys(fields["requires_all"] + intervention["responsibility"]["conditions"])
            )
        return self.add(
            "processes",
            node,
            ident,
            **fields,
            target=target,
            after=list(after),
            condition="、".join(fields["requires_all"]),
            result="、".join(fields["effects"]),
        )

    def gravity(self):
        node = self.use("gravity", self.shape_node)
        self.use("space", self.shape_node)
        law = self.concept(node, "law", "重力")
        field = self.subject(self.shape_node, law)
        load = self.relation(self.shape_node, "load", field, "@target", "力学", "目标当前在作用域内")
        charge = self.use("stored_action", self.shape_node, False)
        delivery = self.use("brief_delivery", charge, False)
        self.action(charge, "charge", "accrue", field, choice=self.choice(charge, "profile", "over_time"))
        delivery_choice = self.choice(delivery, "profile", "short_impulse")
        require("direction" in delivery_choice, delivery, "定向交付须选择方向")
        self.action(delivery, "deliver", "impulse", load, ["charge"], delivery_choice)
        self.action(charge, "abort", "interrupt", field, ["charge"])
        self.held = self.prepaid = True

    def borrowed_path(self):
        shape = self.shape_node
        source = self.use("water", shape)
        take = self.use("borrowed_material", shape)
        self.use("continuous_course", shape)
        medium = self.concept(source, "water", "水")
        path = self.subject(take, medium, borrow=True)
        self.action(take, "take", "take", path)
        for fact in ("interlaced", "convergence"):
            if self.by_fact[fact]:
                self.use(fact, shape)
        if self.space["anchor"] == "support_contact":
            self.relation(shape, "support", path, "@support", "结构", "现场支点有效")
        shaping = any("direct_control" in t["facts"] for t in self.r.terms.values() if t["node"] == shape)
        base = "take"
        if shaping:
            self.evidence(shape, "direct_control", "finite_supply")
            self.relation(shape, "lift", "@caster", path, "力学", "专注与供给均有效")
            base = self.action(shape, "weave", "guide", path, [base])
        pull = None
        if self.by_fact["pull"]:
            pull = self.use("pull", shape, False)
            self.relation(pull, "pull", path, "@target", "力学", "实际接触且路径连续")
            if not shaping:
                self.action(pull, "traction", "pull", "pull", [base])
        freeze = None
        if self.by_fact["solidified"]:
            freeze = self.use("solidified", shape, False)
            self.evidence(freeze, "reservoir")
            selection = self.choice(freeze, "propagation")
            self.action(freeze, "freeze", "freeze", path, [base], selection)
            if pull:
                require(
                    pull in self.r.ancestors[freeze] or pull == freeze,
                    freeze,
                    "释放不能撤去独立分支上未建立的牵引",
                )
            self.prepaid = True
            for target, active in (("lift", shaping), ("pull", pull is not None)):
                if active:
                    self.action(freeze, "stop_" + target, "stop_after_phase", target, ["freeze"])
        if self.by_fact["constraint"]:
            require(freeze, shape, "冻后追加约束需要前置相变")
            bind = self.use("constraint", freeze, False)
            self.evidence(bind, "finite_supply")
            self.relation(bind, "bind", path, "@target", "力学", "接触和额外供给有效")
            self.action(bind, "hold", "bind", "bind", ["freeze"])
            self.action(bind, "stop", "unfunded", "bind", ["hold"])
        interrupt_node = shape
        for node, record in self.r.nodes.items():
            for index, op in enumerate(record["operands"]):
                if "reuse" in op and "pull" in self.r.terms[op["reuse"]]["grant"]:
                    self.reused.add(f"{node}:{index}")
                    if record.get("intents"):
                        interrupt_node = node
                        self.action(
                            node,
                            "fall",
                            "interrupt",
                            "pull",
                            [base],
                            self.choice(node, "operation", "Withdraw"),
                        )
                    else:
                        self.action(node, "drop", "release", "pull", [base])
        if shaping:
            # A held material support is released even when no active pull was selected.
            self.action(interrupt_node, "drop_lift", "interrupt", "lift", [base])
        self.held = True

    def field(self):
        fire = self.use("fire", self.shape_node)
        self.concept(fire, "fire", "火")
        at = self.use("independent_aspect", self.shape_node)
        self.use("medium_for_arcane", at)
        aspect = self.r.rules.aspects[self.r.nodes[at]["aspect_ref"]]
        active = self.concept(at, "isolated", aspect["result"])
        name = aspect["result"]
        for inverse in ("heat_extraction", "attenuation"):
            if self.by_fact[inverse]:
                node = self.use(inverse, at, False)
                require(
                    self.r.nodes[node].get("aspect_ref") == aspect["id"]
                    and node in self.r.ancestors[self.shape_node],
                    node,
                    "反转与独立性质的通道必须相同",
                )
                name = aspect["inverse"]
                active = self.concept(node, "inverted", name)
        node = self.use("sustain", self.shape_node)
        field = self.subject(node, active)
        route = self.r.rules.construction["property_fields"][name]
        self.relation(node, "channel", field, "@target", route["channel"], "目标处于实际作用范围")
        self.action(node, "establish", route["action"], field)
        self.action(node, "end", "release", field, ["establish"])
        self.ongoing = True

    def mist(self):
        shape = self.shape_node
        node = self.use("dispersed_content", shape)
        self.use("air", node)
        self.use("water", node)
        self.use("coverage", shape)
        subject = self.subject(shape, self.concept(node, "mist", "雾"))
        self.relation(shape, "sight", subject, "@observer", "光学", "视线穿过实际雾滴")
        self.action(shape, "spread", "spread", subject)
        if self.by_fact["signal_route"]:
            link = self.use("signal_route", shape, False)
            self.use("medium_for_arcane", link)
            self.evidence(link, "finite_supply")
            self.relation(link, "signal", subject, "@caster", "信息", "媒介与接收端有效")
            self.action(link, "listen", "listen", "signal", ["spread"])
            report = self.use("signal_feedback", link, False)
            self.action(report, "report", "report", "signal", ["listen"])
            end = self.reuse_node("signal_route")
            self.action(end, "close", "release", "signal", ["listen"])
            self.held = True
        else:
            end = self.reuse_node("coverage")
            self.action(end, "decay", "complete", subject, ["spread"])

    def reuse_node(self, fact):
        addr = one(
            [a for a, t in self.r.terms.items() if "reuse" in t and fact in t["grant"]],
            fact,
            "缺少结束阶段的共享引用",
        )
        self.reused.add(addr)
        return self.r.terms[addr]["node"]

    def solid(self):
        shape = self.shape_node
        node = self.use("ice", shape)
        self.use("water", node)
        subject = self.subject(shape, self.concept(node, "ice", "冰"))
        if self.space["layout"] == "sheet":
            require(self.space["anchor"] == "support_contact", shape, "支撑厚片需要有效支点参照")
            self.use("coverage", shape)
            self.use("continuous_course", shape)
            self.relation(shape, "root", subject, "@support", "结构", "冰根接触可承载的支点")
            self.action(shape, "grow", "grow", subject, choice=self.choice(shape, "direction"))
            self.action(self.reuse_node("continuous_course"), "rest", "complete", subject, ["grow"])
        else:
            self.use("compact", shape)
            self.action(shape, "form", "solid", subject)
            if self.by_fact["propulsion"]:
                launch = self.use("propulsion", shape, False)
                self.evidence(launch, "reservoir")
                self.prepaid = True
                self.relation(launch, "thrust", "@caster", subject, "力学", "已支付沿选定方向的推动")
                self.action(launch, "launch", "launch", subject, ["form"], self.choice(launch, "direction"))
                if self.by_fact["penetration"]:
                    enter = self.use("penetration", launch, False)
                    self.action(enter, "enter", "enter", subject, ["launch"])

    def build(self):
        # Only one material/field owner is currently representable by these construction rules.
        scope = self.r.ancestors[self.shape_node] | {self.shape_node}
        emitters = {
            "gravity": self.gravity,
            "borrowed_material": self.borrowed_path,
            "independent_aspect": self.field,
            "dispersed_content": self.mist,
            "ice": self.solid,
        }
        available = [
            key for key in emitters if any(self.r.terms[a]["node"] in scope for a in self.by_fact[key])
        ]
        require(available, self.shape_node, "当前主体缺少已实现的构造规则", "UNSUPPORTED_COMPOSITION")
        key = one(available, self.shape_node, "多种主体解释")
        for fact, required in self.r.rules.construction["spatial_preserves"].items():
            if any(self.r.terms[a]["node"] in scope for a in self.by_fact[fact]):
                require(
                    all(self.space.get(k) == v for k, v in required.items()),
                    self.shape_node,
                    "空间选择与既有词义冲突",
                    fact=fact,
                    required=required,
                )
        supports = {
            "gravity": "region",
            "borrowed_material": "path",
            "independent_aspect": "region",
            "dispersed_content": "region",
            "ice": "solid",
        }
        require(
            self.space["support"] == supports[key],
            self.shape_node,
            "该主体的空间构造尚未接入",
            "UNSUPPORTED_COMPOSITION",
        )
        for node, n in self.r.nodes.items():
            if n["form"] == "构成":
                require(
                    all(op.get("type") in ("Concept", "Aspect") for op in n["operands"]),
                    node,
                    "概念构成不能直接生成现场过程",
                )
            if n["form"] == "共享引用":
                require(n["inputs"], node, "共享引用需要既有对象")
            for intent in n.get("intents", []):
                if "event" in intent:
                    require(n["form"] in ("阶段", "接续"), node, "现场事件需要阶段或接续作用域")
        emitters[key]()
        for addr, t in self.r.terms.items():
            require(
                addr in self.used or addr in self.reused,
                addr,
                "义项已匹配，整体构造缺少它的交付规则",
                "UNSUPPORTED_COMPOSITION",
                sense=t["sense"],
            )
        require(
            self.bound_intents == self.r.intents.keys(),
            "intents",
            "有未消费的空间或过程选择",
            "UNSUPPORTED_COMPOSITION",
        )
        supply = ["持续"] if self.ongoing else ["即时"]
        if self.held:
            supply = ["持续"] if self.prepaid else ["即时", "持续"]
        if self.prepaid:
            supply.append("预付")
        controlled = self.held or self.ongoing

        def outcomes(event, fallback):
            acts = [p for p in self.core["processes"] if p["when"] == event]
            return "、".join(p["target"] + " " + p["result"] for p in acts) or fallback

        self.core["contract"] = {
            "formation": "持续塑造" if self.held else "一次成形",
            "control": "引导" if controlled else "预定",
            "supply": supply,
            "owner": "施法者" if controlled else "独立现象",
            "on_release": outcomes("on_release", "结束主动控制，已成变化留存"),
            "on_interrupt": outcomes("on_interrupt", "撤去未交付的主动作用，已成变化留存"),
        }
        trace = []
        for node, n in self.r.nodes.items():
            terms = [self.r.terms[f"{node}:{j}"] for j in range(len(n["words"]))]
            outputs = list(self.outputs[node])
            require(outputs, node, "该节点没有可追溯的产物", "UNSUPPORTED_COMPOSITION")
            trace.append(
                {
                    "node": node,
                    "senses": [t["sense"] for t in terms],
                    "outputs": outputs,
                    "because": "；".join(t["sense"] + " ← " + ", ".join(t["reads"]) for t in terms),
                    "rule_id": self.r.rules.forms[n["form"]],
                }
            )
        validate(self.core, "magic_core", "LegacyMagicCore" if self.r.rules.legacy else "MagicCore")
        validate(trace, "magic_core", "CompileTrace")
        return self.core, trace
