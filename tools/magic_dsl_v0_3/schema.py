"""Build the portable Draft 2020-12 contract from the same vocabulary used for admission."""

import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[2] / "game/data/magic_v0_3"
SCHEMAS = {"0.3.0": DATA / "magic_dsl_v0_3.schema.json", "0.3.1": DATA / "magic_dsl_v0_3_1.schema.json"}


def read(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"JSON 重复键 {key}")
            result[key] = value
        return result

    def reject(value):
        raise ValueError(f"非有限数值 {value}")

    return json.loads(Path(path).read_text(), object_pairs_hook=unique, parse_constant=reject)


REG = read(DATA / "registry.json")
TARIFF = read(DATA / "tariff.json")
SCHEMA = SCHEMAS[REG["edition"]]


def build():
    def obj(fields, optional=()):
        return {
            "type": "object",
            "properties": fields,
            "required": [k for k in fields if k not in optional],
            "additionalProperties": False,
        }

    def enum(*items):
        return {"enum": list(items)}

    def ref(name):
        return {"$ref": "#/$defs/" + name}

    def arr(item, maximum, minimum=0):
        return {"type": "array", "items": item, "minItems": minimum, "maxItems": maximum}

    def num(lo, hi):
        return {"type": "number", "minimum": lo, "maximum": hi}

    def pos(hi):
        return {"type": "number", "exclusiveMinimum": 0, "maximum": hi}

    def integer(lo, hi):
        return {"type": "integer", "minimum": lo, "maximum": hi}

    ident = {"type": "string", "pattern": "^[a-z][a-z0-9_]{0,39}$"}
    name = {"type": "string", "minLength": 1, "maxLength": 180}
    ids = lambda n: {**arr(ident, n), "uniqueItems": True}
    lim = REG["limits"]
    d = {}
    d["FieldVector"] = obj({k: num(-1, 1) for k in ("radial", "tangential", "axial")})
    d["Propagation"] = obj(
        {
            "origin": enum("bound_source"),
            "via": enum("live_material"),
            "speed_m_s": pos(30),
            "reach_m": pos(30),
            "hops": integer(1, lim["hops"]),
            "attenuation": num(0, 1),
            "missing": enum("stop"),
        }
    )
    shapes = {
        "column": {"radius_m": pos(lim["extent_m"]), "height_m": pos(lim["extent_m"])},
        "cone": {"extent_m": pos(30), "half_angle_deg": pos(89)},
        "sphere": {"extent_m": pos(30)},
        "sheet": {"extent_m": pos(30), "quads": integer(1, 64)},
        "network": {"extent_m": pos(30), "nodes": integer(1, 16), "edges": integer(1, 24)},
        "mass": {"extent_m": pos(30), "bodies": integer(1, 16)},
    }
    d["Spatial"] = obj(
        {
            "carrier": enum(*set_order(REG["geometry"].values())),
            "geometry": {"oneOf": [obj({"shape": {"const": s}, **params}) for s, params in shapes.items()]},
            "reference": obj(
                {
                    "anchor": enum("caster", "source", "aim_point", "target"),
                    "bind": enum("cast", "enter", "live"),
                }
            ),
            "distribution": {
                "oneOf": [
                    enum("uniform", "linear_falloff"),
                    obj({k: enum(*v) for k, v in REG["column_profiles"].items()}),
                ]
            },
            "scope": enum("within_field", "self"),
        },
        ["scope"],
    )
    source = {
        "oneOf": [
            obj({"kind": enum("Manifest")}),
            obj({"kind": enum("Reference"), "slot": ident}),
            obj({"kind": enum("Borrow", "Derived"), "ref": ident}),
        ]
    }
    d["Subject"] = obj(
        {
            "id": ident,
            "kind": enum("Material", "Field", "WorldRef"),
            "concept": ident,
            "source": source,
            "spatial": ref("Spatial"),
            "medium": enum(*REG["required_media"].values()),
            "initial_phase": enum("liquid", "solid"),
            "properties": arr(obj({"aspect": enum(*REG["properties"]), "via": ident}), 8),
        },
        ["spatial", "initial_phase", "properties", "medium"],
    )
    d["Relation"] = obj(
        {
            "id": ident,
            "from": ident,
            "to": ident,
            "channel": enum(*REG["channels"]),
            "basis": enum("aether", "nature"),
            "validity": enum(*[v["validity"] for v in REG["channels"].values()]),
        }
    )
    d["Operation"] = {
        "oneOf": [
            obj(
                {
                    "op": {"const": spec["op"]},
                    "ability": {"const": ability},
                    "target": {"anyOf": [ident, {"const": "@reserve"}]},
                    **{
                        key: enum(*v) if isinstance(v, list) else ref(v)
                        for key, v in spec["parameters"].items()
                    },
                }
            )
            for ability, spec in REG["abilities"].items()
        ]
    }
    ops = arr(ref("Operation"), 16)
    d["Contract"] = obj(
        {
            "id": ident,
            "controller": enum("caster", "autonomous"),
            "mobility": enum("slow_walk", "free", "rooted"),
            "focus": enum("exclusive", "none"),
            "provider": {"anyOf": [ident, {"const": "@caster"}]},
            "supply_link": ident,
            "max_s": pos(30),
            "reserve": obj({"full_charge_s": pos(30), "min_release_ratio": pos(1)}),
        },
        ["reserve", "supply_link"],
    )
    d["Edge"] = obj(
        {
            "event": enum("release", "interrupt", "timeout", "contact", "signal", "ready"),
            "when": enum("always", "reserve_ready", "reserve_low"),
            "to": ids(4),
            "handoff": arr(obj({"handle": ident, "to": ident}), 12),
        },
        ["handoff"],
    )
    d["Process"] = obj(
        {
            "id": ident,
            "contract": ident,
            "join": enum("all", "any"),
            "enter": ops,
            "active": ops,
            "on": arr(ref("Edge"), 12),
            "exit": ops,
            "repeat": obj(
                {"times": integer(1, 8), "interval_s": pos(30), "actions": {**ops, "minItems": 1}}
            ),
        },
        ["repeat"],
    )
    art = REG["art"]
    d["Track"] = obj(
        {
            "process": ident,
            "cue": enum("enter", "active", "impact", "exit"),
            "bind": enum("constant", "fill_ratio", "geometry", "actual_impact"),
            "subject": ident,
            **{k: enum(*v) for k, v in art.items()},
        },
        ["subject", *art],
    )
    d["Recipe"] = obj(
        {
            "version": {"const": REG["edition"]},
            "name": name,
            "scale": enum(*TARIFF["scale"]),
            "Concepts": arr(obj({"id": ident, "nature": enum(*REG["natures"])}), 8, 1),
            "Subjects": arr(ref("Subject"), lim["subjects"], 1),
            "Relations": arr(ref("Relation"), lim["relations"]),
            "Processes": obj(
                {"entry": {**ids(4), "minItems": 1}, "nodes": arr(ref("Process"), lim["nodes"], 1)}
            ),
            "Contracts": arr(ref("Contract"), 8, 1),
            "Expression": arr(ref("Track"), 32),
        }
    )
    # Node identifiers support repeated glyphs, shared subgroups and explicit order.
    d["RuneGraph"] = obj(
        {
            "nodes": arr(obj({"id": ident, "rune": enum(*REG["runes"])}), 32, 1),
            "links": arr(
                obj(
                    {
                        "id": ident,
                        "kind": enum("共同组织", "局部关联", "发生接续"),
                        "members": {**ids(16), "minItems": 2},
                    }
                ),
                32,
            ),
        }
    )
    mechanisms = [k for k in REG["abilities"] if k not in ("form", "end", "charge")]
    d["Anchor"] = obj(
        {
            "ref": ident,
            "meaning": name,
            "mechanism": enum(*mechanisms),
            "axis": enum(*REG["abilities"]["impulse"]["parameters"]["axis"]),
            "anchor": enum("target", "caster", "source", "aim_point"),
            "bind": d["Spatial"]["properties"]["reference"]["properties"]["bind"],
            "exclude": {**arr(enum(*mechanisms), 8), "uniqueItems": True},
            "phase": enum("enter", "active", "repeat"),
            "controller": enum("caster", "autonomous"),
            "supply": enum("caster", "linked_reserve"),
        },
        ["phase", "controller", "supply", "axis", "anchor", "bind", "exclude"],
    )
    d["CompilationInput"] = obj(
        {
            "RuneGraph": ref("RuneGraph"),
            "SemanticAnchors": arr(ref("Anchor"), 16),
            "CastingContext": obj(
                {
                    "target": enum("self", "aim", "world"),
                    "timing": enum("open", "instant", "charge", "remain"),
                }
            ),
            "PlayerKnowledge": {**arr(enum(*REG["runes"]), 20), "uniqueItems": True},
            "WorldKnowledgeVersion": {"const": REG["knowledge"]},
            "DSLVersion": {"const": REG["edition"]},
            "CapabilityProfile": {"const": REG["profile"]},
            "SupportedCapabilities": {**arr(enum(*REG["abilities"]), 32), "uniqueItems": True},
            "ArtisticStyle": enum("ruined_city"),
        }
    )
    d["CompilationOutput"] = obj(
        {
            "Interpretation": name,
            "RuneContributions": arr(
                obj({"node": ident, "meaning": name, "refs": {**ids(12), "minItems": 1}}), 32, 1
            ),
            "MagicDSL": ref("Recipe"),
            "AlternativeAnchors": arr(ref("Anchor"), 2),
        }
    )
    d["Diagnostic"] = obj({"code": name, "path": {"type": "string"}, "message": {"type": "string"}})
    d["TrainingRecord"] = obj(
        {
            "input": ref("CompilationInput"),
            "candidate": {},
            "diagnostics": arr(ref("Diagnostic"), 32),
            "corrected": {"anyOf": [ref("CompilationOutput"), {"type": "null"}]},
            "observation_source": {"const": REG["profile"]},
            "observations": arr(
                obj(
                    {
                        "ability": enum(*REG["abilities"]),
                        "world_object": ident,
                        "value": {"type": ["number", "string", "boolean"]},
                        "at_s": num(0, 30),
                    }
                ),
                262144,
            ),
            "prior_expectation": {"type": ["string", "null"]},
            "preference": enum("accepted", "reanchored", "rejected", None),
            "tariff_version": name,
        }
    )
    vec = arr(num(-10000, 10000), 3, 3)
    d["WorldObject"] = obj(
        {
            "id": ident,
            "position": vec,
            "mass": pos(10000),
            "load": num(0, 10000),
            "contact": {"type": "boolean"},
            "occluded": {"type": "boolean"},
            "sight": {"type": "boolean"},
            "disturbance": {"type": "boolean"},
            "conductive": {"type": "boolean"},
            "phase": enum("liquid", "solid"),
            "mana": num(0, 10000),
            "linked": {"type": "boolean"},
            "transmission": num(0, 1),
            "thermal_path": enum("contact", "medium", "radiation", "insulated"),
        },
        [
            "load",
            "contact",
            "occluded",
            "sight",
            "disturbance",
            "conductive",
            "phase",
            "mana",
            "linked",
            "thermal_path",
            "transmission",
        ],
    )
    d["Scene"] = obj(
        {
            "caster_mana": num(0, 10000),
            "media": {**arr(enum(*REG["required_media"].values()), 8), "uniqueItems": True},
            "position": vec,
            "aim": vec,
            "aim_point": vec,
            "until_s": num(0, 30),
            "objects": arr(ref("WorldObject"), 16),
            "slots": {
                "type": "object",
                "propertyNames": ident,
                "additionalProperties": ident,
                "maxProperties": 16,
            },
            "edges": arr(
                obj(
                    {
                        "a": ident,
                        "b": ident,
                        "kind": enum("material", "electric"),
                        "intact": {"type": "boolean"},
                        "length_m": pos(30),
                    }
                ),
                24,
            ),
            "events": arr(
                obj(
                    {
                        "at": num(0, 30),
                        "event": enum(
                            "release",
                            "interrupt",
                            "contact",
                            "signal",
                            "cut",
                            "unlink",
                            "aim",
                            "move",
                            "aim_point",
                        ),
                        "ref": ident,
                        "other": ident,
                        "vector": vec,
                    },
                    ["ref", "other", "vector"],
                ),
                64,
            ),
        },
        ["media", "aim_point"],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:city-fates:magic-dsl:" + REG["edition"],
        "$ref": "#/$defs/Recipe",
        "$defs": d,
    }


def set_order(values):
    return list(dict.fromkeys(values))


if __name__ == "__main__":
    SCHEMA.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
