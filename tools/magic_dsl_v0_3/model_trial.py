"""Run an isolated, single-pass altar experiment with a JSON-in/text-out model adapter."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from .admission import Recipe, structure
from .altar import compile_at_altar, record_observations
from .schema import REG, SCHEMAS, read
from .simulate import Simulation


def experiment(inputs, expectation, generate, *, scene=None, repair=False):
    calls = []

    def candidate(data, diagnostic):
        schema = read(SCHEMAS[data["DSLVersion"]])
        geometry = schema["$defs"]["Spatial"]["properties"]["geometry"]["oneOf"]
        shapes = [variant["properties"]["shape"]["const"] for variant in geometry]
        capabilities = data["SupportedCapabilities"]
        registry = {
            **REG,
            "edition": data["DSLVersion"],
            "profile": data["CapabilityProfile"],
            "knowledge": data["WorldKnowledgeVersion"],
            "geometry": {shape: REG["geometry"][shape] for shape in shapes},
            "abilities": {a: REG["abilities"][a] for a in capabilities},
            "delivery": {a: REG["delivery"][a] for a in capabilities if a in REG["delivery"]},
        }
        prompt = {
            "task": "只返回一个 CompilationOutput JSON。所有声明 ID 唯一；作用须有来源、有效句柄与支付证明。禁止访问样例或仓库。",
            "input": data,
            "contract": (
                "构筑期只输出 JSON。不要调用工具。声明 ID 跨各段唯一。每个主体或关系在施力前"
                "由当前过程 enter/form 建立句柄，退出时撤去。Field 采用 Manifest 来源，"
                "medium 按 required_media 给出。独占控制、供给、最长时段由契约声明。"
                "持续力使用有限直柱域及三个有符号分量，其合成长度在 (0,1]。"
                "参照在 cast、enter 时捕获，或 live 时持续重取。Expression 可以为空。"
                "RuneContributions 须逐枚指向本配方内真实声明。请从输入的符文和锚点构思。"
                if data["DSLVersion"] == "0.3.1"
                else "按输入所列版本的机器契约生成。"
            ),
            "registry": registry,
            "response_schema": {"$ref": "#/$defs/CompilationOutput", "$defs": schema["$defs"]},
            "repair": diagnostic,
        }
        payload = json.dumps(prompt, ensure_ascii=False, separators=(",", ":"))
        calls.append(hashlib.sha256(payload.encode()).hexdigest())
        answer = generate(payload)
        try:
            return json.loads(answer)
        except json.JSONDecodeError:
            return answer

    accepted, record = compile_at_altar(inputs, candidate, prior_expectation=expectation, repair=repair)
    if accepted and scene:
        record_observations(record, Simulation(Recipe(accepted["MagicDSL"]), scene).run())
    structure(record, "TrainingRecord")
    return record, calls


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--expectation", required=True)
    parser.add_argument("--model", required=True, help="Adapter/model provenance")
    parser.add_argument("--scene", type=Path)
    parser.add_argument("--repair", action="store_true")
    parser.add_argument(
        "--adapter",
        nargs=argparse.REMAINDER,
        required=True,
        help="Executable and arguments. Reads prompt from stdin and writes the answer to stdout.",
    )
    args = parser.parse_args()
    if args.output.exists() or not args.adapter:
        parser.error("需要新的结果目录和模型适配命令")
    with TemporaryDirectory(prefix="magic-altar-") as workspace:

        def generate(prompt):
            return subprocess.run(
                args.adapter,
                input=prompt,
                text=True,
                capture_output=True,
                cwd=workspace,
                check=True,
                timeout=240,
            ).stdout

        record, calls = experiment(
            read(args.input),
            args.expectation,
            generate,
            scene=read(args.scene) if args.scene else None,
            repair=args.repair,
        )
    args.output.mkdir(parents=True)
    (args.output / "record.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    (args.output / "provenance.json").write_text(
        json.dumps({"model": args.model, "prompt_sha256": calls}, ensure_ascii=False, indent=2) + "\n"
    )
