from graphlib import CycleError, TopologicalSorter

from .rules import Diagnostic, one, require, validate


def ordered(graph):
    nodes = {n["id"]: n for n in graph}
    require(len(nodes) == len(graph), "graph", "重复节点")
    for n in graph:
        require(set(n["inputs"]) <= nodes.keys(), n["id"], "输入引用不存在")
    sorter = TopologicalSorter({k: n["inputs"] for k, n in nodes.items()})
    try:
        sorter.prepare()
    except CycleError as exc:
        raise Diagnostic("INVALID_MEANING", "graph", "循环依赖", cycle=exc.args[1]) from exc
    while sorter.is_active():
        batch = sorted(sorter.get_ready(), key=lambda k: int(k[1:]))
        for k in batch:
            yield nodes[k]
        sorter.done(*batch)


class Resolution:
    def __init__(self, graph, rules):
        validate(graph, "magic_core", "SemanticGraph")
        self.rules = rules
        self.nodes = {}
        self.ancestors = {}
        self.terms = {}
        self.intents = {}
        self.intervention_claims = {}
        self.obligations = []
        for n in ordered(graph):
            key = n["id"]
            self.nodes[key] = n
            prior = set(n["inputs"])
            for parent in n["inputs"]:
                prior.update(self.ancestors[parent])
            self.ancestors[key] = prior
            require("operands" in n and len(n["words"]) == len(n["operands"]), key, "每个词须有对应操作数")
            if "aspect_ref" in n:
                require(n["aspect_ref"] in rules.aspects, key, "未登记性质")
            local = set()
            for index, (word, operand) in enumerate(zip(n["words"], n["operands"])):
                at = f"{key}:{index}"
                term = self.term(n, word, operand, at)
                self.terms[at] = term
                local.update(term["facts"])
                local.update(term["grant"])
                if term["at_use"] and "reuse" not in operand:
                    self.obligations.append({"term": at, "at_use": term["at_use"]})
            if "aspect_ref" in n:
                aspect = n["aspect_ref"]
                permission = rules.basis["aspect_permissions"].get(aspect)
                owners = (
                    permission["owner_evidence_any"]
                    if permission
                    else rules.construction["aspect_scope_facts"].get(aspect, [])
                )
                require(owners, key, "该性质的作用域尚未实现", "UNSUPPORTED_MEANING")
                require(
                    any(
                        t["node"] in prior | {key} and set(owners).intersection(t["grant"])
                        for t in self.terms.values()
                    ),
                    key,
                    "性质引用与依赖链中的本体不符",
                )
            for choice in n.get("intents", []):
                for row in rules.basis["contract_derivations"]:
                    if matches(row["requires_selection"], choice) and set(row["all"]) <= local:
                        term = one(
                            (
                                t
                                for t in self.terms.values()
                                if t["node"] == key and row["output_requires"] in t["grant"]
                            ),
                            key,
                            "储备所属过程不明",
                        )
                        term["grant"] = sorted(set(term["grant"]) | set(row["grant"]))
                        term["derivations"].append(row["id"])
                handle = choice["ref"]
                require(handle not in self.intents, key, "重复的构筑内引用 " + handle)
                if "intervention" in choice:
                    require(not rules.legacy, key, "干预声明需要 Core 0.1.2", "VERSION_MISMATCH")
                    self.intervention_claims[handle] = choice["intervention"]
                self.intents[handle] = (key, self.normalize(n, choice, local))

    def ref(self, at, node):
        require(
            at in self.terms and self.terms[at]["node"] in self.ancestors[node] | {node},
            node,
            "词项不可达或尚未成立：" + at,
        )
        return self.terms[at]

    def term(self, n, word, operand, at):
        key = n["id"]
        if "reuse" in operand:
            prior = self.ref(operand["reuse"], key)
            require(prior["word"] == word, at, "共享引用的词不一致")
            return {
                **prior,
                "node": key,
                "reads": [operand["reuse"]],
                "facts": [],
                "grant": list(prior["grant"]),
                "derivations": [],
                "reuse": operand["reuse"],
            }
        if "subject" in operand:
            handle = operand["subject"]
            require(
                handle in self.intents
                and self.intents[handle][0] in self.ancestors[key]
                and "spatial_intent" in self.intents[handle][1],
                at,
                "主体引用未绑定或不可达",
            )
        facts = set()
        for src in operand["reads"]:
            if ":" in src:
                facts.update(self.ref(src, key)["grant"])
                continue
            sources = self.rules.basis["sources"]
            require(src in sources, at, "未登记事实来源 " + src)
            if src.startswith("aspect."):
                aspect = src[7:]
                owners = self.rules.basis["aspect_permissions"][aspect]["owner_evidence_any"]
                available = self.ancestors[key] | {key}
                require(
                    aspect == n.get("aspect_ref")
                    and any(
                        t["node"] in available and set(owners).intersection(t["grant"])
                        for t in self.terms.values()
                    ),
                    at,
                    "性质缺少本体或作用域依据",
                )
            facts.update(sources[src]["facts"])
        entries = self.rules.senses.get(word)
        require(entries, at, "未知符文 " + word)
        supported = [s for s in entries if "match" in s]
        require(supported, at, "该词仍只有描述性义项：" + word, "UNSUPPORTED_MEANING")
        candidates = [s for s in supported if operand["type"] in s["object_types"]]
        eligible = [s for s in candidates if set(s["match"]["all"]) <= facts]
        if not eligible:
            if operand["type"] == "Aspect" and not n.get("aspect_ref"):
                visible = [t for t in self.terms.values() if t["node"] in self.ancestors[key] | {key}]
                options = [
                    a
                    for a, p in self.rules.basis["aspect_permissions"].items()
                    if any(set(p["owner_evidence_any"]) & set(t["grant"]) for t in visible)
                    and any(
                        set(s["match"]["all"])
                        <= facts | set(self.rules.basis["sources"]["aspect." + a]["facts"])
                        for s in candidates
                    )
                ]
                if len(options) > 1:
                    raise Diagnostic("AMBIGUOUS", at, "请选择作用的性质", candidates=options)
            raise Diagnostic(
                "INVALID_MEANING",
                at,
                "对象或前提不满足",
                word=word,
                missing={s["id"]: sorted(set(s["match"]["all"]) - facts) for s in candidates},
            )
        sid = one([s["id"] for s in eligible], at, "多个合法义项")
        return dict(
            node=key,
            word=word,
            sense=sid,
            reads=operand["reads"],
            facts=sorted(facts),
            derivations=[],
            **{k: list(v) for k, v in eligible[0]["match"].items()},
        )

    def normalize(self, node, intent, facts):
        at = node["id"]
        norm = self.rules.normal
        fields = {}
        for key in ("space", "direction", "profile", "event", "propagate"):
            if key not in intent:
                continue
            value = intent[key]
            choice = value["organization"] if key == "space" else value
            table = {"direction": "directions", "propagate": "propagation"}.get(key, key)
            row = one(
                (
                    r
                    for r in norm[table]
                    if r["choice"] == choice
                    and set(r.get("all", [])) <= facts
                    and ("requires_any" not in r or set(r["requires_any"]) & facts)
                ),
                at,
                "选择缺少依据：" + key,
            )
            if key == "space":
                fields["spatial_intent"] = {**row["value"], "anchor": value["anchor"]}
            elif key == "propagate":
                link = row["material_binding"]
                material = intent[link["intent_ref"]]
                producer = self.intents.get(material)
                require(
                    producer
                    and producer[0] in self.ancestors[at]
                    and matches(row["material_requires"], producer[1].get("spatial_intent", {})),
                    at,
                    "传播材料的空间条件不成立",
                )
                origins = [
                    op.get(link["operand_ref"])
                    for j, op in enumerate(node["operands"])
                    if link["operand_grant"] in self.terms[f"{at}:{j}"]["grant"]
                ]
                require(origins == [material], at, "传播必须引用相变所作用的同份材料")
                fields["propagation"] = {**row["value"], "material": material}
            else:
                fields["when" if key == "event" else key] = row.get("value", choice)
        if any(k in intent for k in ("profile", "propagate", "action")):
            rule = one(
                (r for r in norm["process"] if matches(r["when"], intent) and set(r["all"]) <= facts),
                at,
                "缺少过程授权",
            )
            fields.update(rule["core"])
        return fields


def matches(pattern, actual):
    return all(actual.get(k) == v for k, v in pattern.items())
