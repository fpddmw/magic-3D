import json
from functools import lru_cache
from pathlib import Path

from jsonschema import Draft202012Validator

DATA = Path(__file__).resolve().parents[2] / "game/data"


class Diagnostic(ValueError):
    def __init__(self, status, at, message, **details):
        super().__init__(message)
        self.report = dict(status=status, at=at, message=message, **details)


def require(condition, at, message, status="INVALID_MEANING", **details):
    if not condition:
        raise Diagnostic(status, at, message, **details)


def one(rows, at, message):
    rows = list(rows)
    require(rows, at, message)
    require(len(rows) == 1, at, message, "AMBIGUOUS", candidates=rows)
    return rows[0]


def load(path):
    return json.loads((DATA / path).read_text(encoding="utf-8"))


@lru_cache(None)
def validator(filename, definition=None):
    schema = load("schema/" + filename + ".schema.json")
    if definition:
        schema = {"$defs": schema["$defs"], "$ref": "#/$defs/" + definition}
    return Draft202012Validator(schema)


def validate(value, filename, definition=None, status="INVALID_STRUCTURE"):
    error = next(validator(filename, definition).iter_errors(value), None)
    if error:
        raise Diagnostic(status, error.json_path, error.message)


class Rules:
    def __init__(self, core_version=None):
        self.basis = load("core/matching_basis.json")
        self.world = load("core/world.json")
        lexicon = load("core/meanings.json")
        composition = load("core/composition_rules.json")
        lowering = load("lowering/semantic_bindings.json")
        self.execution = load("lowering/execution_rules.json")
        self.balance = load("balance/resource_budget.json")
        self.construction = load("core/construction.json")
        self.projections = lowering["projections"]
        self.normal = composition["intent_normalization"]
        self.forms = {r["form"]: r["id"] for r in composition["rules"]}
        self.aspects = {r["id"]: r for r in self.world["aspects"]}
        self.senses = {}
        for entry in lexicon["senses"]:
            self.senses.setdefault(entry["word"], []).append(entry)
        self.versions = {
            "core": self.world["core_version"],
            "semantics": lexicon["semantic_rules_version"],
            "execution": self.execution["execution_version"],
            "artkit": load("art/artkit_registry.json")["artkit_version"],
        }
        require(
            self.versions["core"] == lowering["source_core_version"] == self.construction["core_version"]
            and self.versions["semantics"]
            == composition["semantic_rules_version"]
            == self.basis["semantic_rules_version"]
            and self.versions["execution"]
            == lowering["execution_version"]
            == self.balance["execution_version"],
            "versions",
            "规则表版本不一致",
            "VERSION_MISMATCH",
        )
        require(
            core_version in (None, self.versions["core"], "0.1.1"),
            "versions",
            "未安装指定 Core 版本",
            "VERSION_MISMATCH",
        )
        self.legacy = core_version == "0.1.1"
        if self.legacy:
            # Previous construction is identical before the intervention certification pass.
            self.versions["core"] = core_version
        self.construction_version = "0.1.0" if self.legacy else self.construction["construction_version"]
