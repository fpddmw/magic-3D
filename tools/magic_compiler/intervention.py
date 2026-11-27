"""Resolve a local intervention against world permission and the graph's actual evidence."""

from .rules import Diagnostic, require


def bind_target(builder, node, permission, target, process):
    subjects = {s["id"]: s for s in builder.core["subjects"]}
    relation_ids = {r["id"] for r in builder.core["relations"]}
    require(target in subjects.keys() | relation_ids, node, "干预对象尚未建立")
    facet = permission["facet"]
    target_kind = "subject" if target in subjects else "relation"
    obj = {"kind": target_kind, "ref": target, "facet": facet}
    scope = permission["scope"]
    scope_ref = target
    if scope == "account":
        obj = {"kind": "account", "ref": "@reserve", "facet": facet}
        scope_ref = "@reserve"
    elif scope == "reachable_source":
        source = subjects.get(target)
        require(source and source["source"] == "Borrow", node, "借用须绑定既有来源")
        scope_ref = source["source_ref"]
    elif scope == "connected_material":
        propagation = process.get("propagation", {})
        require(propagation.get("material") == builder.ref, node, "相变须限于同一份连通材料")
        scope_ref = propagation["material"]
    elif scope in ("in_region", "subject_space"):
        scope_ref = builder.ref
    return obj, {"kind": scope, "ref": scope_ref}


def certify(builder, node, action, target, after, process):
    resolution = builder.r
    rules = resolution.rules
    recipe = rules.construction["interventions"][action]
    permission_id = recipe["permission"]
    permission = rules.world["intervention_permissions"].get(permission_id)
    require(
        permission and permission["effects"] == process["effects"],
        node,
        "世界未许可此项实际作用",
        permission=permission_id,
    )

    visible = resolution.ancestors[node] | {node}
    needed = set(permission["meaning_all"])
    proof = {
        addr: needed.intersection(term["grant"])
        for addr, term in resolution.terms.items()
        if term["node"] in visible
    }
    terms = [addr for addr, found in proof.items() if found]
    missing = needed - set().union(*proof.values())
    require(not missing, node, "干预缺少词义依据", permission=permission_id, missing=sorted(missing))

    obj, scope = bind_target(builder, node, permission, target, process)

    costs = rules.construction["responsibility_conditions"]
    tenure = recipe["funding"]
    funding_guards = rules.construction["funding_conditions"].get(tenure, [])
    guards = list(dict.fromkeys(process["requires_all"] + funding_guards))
    require(set(guards) <= set(rules.world["condition_ids"]), node, "干预使用了未登记的条件")
    site = [c for c in guards if c not in costs]
    responsibility = {
        "tenure": tenure,
        "conditions": [c for c in guards if c in costs],
        "on_end": "preserve_realized",
    }
    explicit = "medium_for_arcane" in needed
    if tenure in ("ending", "inherited"):
        prior = {p["id"]: p["intervention"] for p in builder.core["processes"]}
        require(after and all(p in prior for p in after), node, "缺少已建立的前置作用")
        responsibility["from_processes"] = list(after)
        if tenure == "ending":
            for parent in after:
                basis = prior[parent]["basis"]
                terms.extend(basis["terms"])
                explicit |= basis["medium"] == "explicit"
            # A release can name an independently established relation on the same subject.
            terms.extend(
                addr
                for addr, t in resolution.terms.items()
                if t["node"] == node or (t["node"] in visible and target in builder.outputs[t["node"]])
            )
    else:
        responsibility["source"] = {"mode": "active", "provider_ref": "@caster"}
        if tenure == "prepaid":
            responsibility["account_ref"] = "@reserve"
    require(terms, node, "干预缺少可追溯的构筑依据")
    result = {
        "mode": permission["mode"],
        "target": obj,
        "scope": scope,
        "basis": {
            "permission": permission_id,
            "terms": list(dict.fromkeys(terms)),
            "medium": "explicit" if explicit else "implicit",
            "site_conditions": site,
        },
        "responsibility": responsibility,
    }
    claim = resolution.intervention_claims.get(process.get("intent_ref"), {})
    check_declaration(claim, result, node, resolution, visible)
    return result


def check_declaration(claim, result, node, resolution, visible):
    if claim.get("target", {}).get("kind") == "active_magic":
        require(
            any(
                "medium_for_arcane" in t["grant"] and t["node"] in visible
                for t in resolution.terms.values()
            ),
            node,
            "干涉已有魔法需要显式以太依据",
        )
        raise Diagnostic("UNSUPPORTED_COMPOSITION", node, "跨实例对象与干预权限尚无构造绑定")
    for key, value in claim.items():
        actual = result["basis"]["permission"] if key == "permission" else result[key]
        if key == "responsibility":
            # Conjunctive guards and predecessor sets have no editorial ordering.
            for field in ("conditions", "from_processes"):
                if field in value and field in actual:
                    value = {**value, field: sorted(value[field])}
                    actual = {**actual, field: sorted(actual[field])}
        require(
            value == actual,
            node,
            "干预声明与构筑可证明的内容不符",
            field=key,
        )
