from copy import deepcopy

from .construct import Builder
from .lowering import lower
from .resolve import Resolution
from .rules import Diagnostic, Rules, require


def compile_graph(graph, rules=None):
    rules = rules or Rules()
    resolution = Resolution(graph, rules)
    core, trace = Builder(resolution).build()
    try:
        execution = lower(core, rules)
    except Diagnostic as exc:
        if exc.report["status"] not in ("UNSUPPORTED_LOWERING", "BUDGET_EXCEEDED"):
            raise
        execution = exc.report
    return deepcopy(
        {
            "versions": {**rules.versions, "construction": rules.construction_version},
            "core": core,
            "trace": trace,
            "evidence": resolution.terms,
            "execution": execution,
        }
    )


def compile_input(document):
    if isinstance(document, dict):
        require(
            set(document) == {"versions", "graph"},
            "$",
            "输入包仅接受 graph 和 versions",
            "INVALID_STRUCTURE",
        )
        pins = document["versions"]
        require(isinstance(pins, dict), "versions", "版本必须为对象", "VERSION_MISMATCH")
        rules = Rules(pins.get("core"))
        require(
            document["versions"]
            in (
                rules.versions,
                {**rules.versions, "construction": rules.construction_version},
            ),
            "versions",
            "未安装指定规则版本",
            "VERSION_MISMATCH",
        )
        return compile_graph(document["graph"], rules)
    return compile_graph(document)
