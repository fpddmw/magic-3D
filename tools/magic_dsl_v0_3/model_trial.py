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
