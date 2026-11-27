import argparse
import json
import sys
from pathlib import Path

from .admission import admit
from .compiler import compile_input
from .rules import Diagnostic, Rules


def main():
    parser = argparse.ArgumentParser(description="Magic Core 阶段 B 离线编译与准入")
    parser.add_argument("command", choices=["compile", "check-spell", "check-intent"])
    parser.add_argument("file", nargs="?", default="-", help="JSON 文件，默认读取标准输入")
    args = parser.parse_args()
    try:
        raw = sys.stdin.read() if args.file == "-" else Path(args.file).read_text(encoding="utf-8")
        document = json.loads(raw, parse_constant=reject_constant, object_pairs_hook=unique_keys)
        if args.command == "compile":
            result = compile_input(document)
        else:
            floor = admit(document, Rules(), "intent" if args.command == "check-intent" else "spell")
            result = {"status": "VALID", "budget_floor": floor}
    except Diagnostic as exc:
        print(json.dumps(exc.report, ensure_ascii=False), file=sys.stderr)
        return 1
    except (OSError, ValueError) as exc:
        print(
            json.dumps({"status": "INVALID_INPUT", "message": str(exc)}, ensure_ascii=False),
            file=sys.stderr,
        )
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False))
    return 0


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("JSON 对象键重复：" + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("非有限数值 " + value)


if __name__ == "__main__":
    raise SystemExit(main())
