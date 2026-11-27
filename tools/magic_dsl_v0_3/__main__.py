import argparse
import json
import sys

from .admission import Diagnostic, Recipe, structure
from .altar import accept, check_input, compile_at_altar, reading, record_observations
from .schema import read
from .simulate import Simulation


def main():
    parser = argparse.ArgumentParser(description="Magic DSL v0.3 离线校验、计费、读解与推演")
    sub = parser.add_subparsers(dest="command", required=True)
    for k in ("validate", "price", "budgets", "read", "simulate", "accept", "input", "record", "trial"):
        cmd = sub.add_parser(k)
        cmd.add_argument("file")
        if k == "trial":
            cmd.add_argument("--scene")
            cmd.add_argument("--expectation")
        if k in ("simulate", "accept", "trial"):
            cmd.add_argument("second")
    args = parser.parse_args()
    try:
        data = read(args.file)
        if args.command == "accept":
            result = accept(data, read(args.second))
        elif args.command == "trial":
            supplied = read(args.second)
            accepted, result = compile_at_altar(
                data, lambda inputs, diagnostic: supplied, prior_expectation=args.expectation
            )
            if accepted and args.scene:
                observed = Simulation(Recipe(accepted["MagicDSL"]), read(args.scene)).run()
                record_observations(result, observed)
            structure(result, "TrainingRecord")
        elif args.command == "input":
            check_input(data)
            result = {"status": "valid"}
        elif args.command == "record":
            structure(data, "TrainingRecord")
            result = {"status": "valid"}
        else:
            recipe = Recipe(data)
            if args.command == "budgets":
                result = recipe.budgets
            elif args.command == "price":
                result = recipe.quote
            elif args.command == "read":
                result = reading(recipe)
            elif args.command == "simulate":
                result = Simulation(recipe, read(args.second)).run()
            else:
                result = {"status": "valid", "version": recipe.data["version"], "quote": recipe.quote}
        print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    except (OSError, ValueError) as exc:
        report = (
            exc.report
            if isinstance(exc, Diagnostic)
            else {"code": "INVALID_INPUT", "path": "$", "message": str(exc)}
        )
        print(json.dumps(report, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
