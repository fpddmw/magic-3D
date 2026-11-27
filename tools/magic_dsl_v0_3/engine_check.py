"""Run the headless hall as a failing test, including GDScript exceptions."""

import argparse
import json
import subprocess
from pathlib import Path

from .schema import DATA


def run(executable):
    game = DATA.parents[1]
    command = [executable, "--headless", "--path", str(game)]
    for args in (
        ["--editor", "--import"],
        ["--fixed-fps", "60", "--quit-after", "2400", "--", "--hall-test"],
    ):
        result = subprocess.run(command + args, capture_output=True, text=True, timeout=120, check=False)
        log = result.stdout + result.stderr
        if result.returncode or "ERROR:" in log or "instances leaked" in log:
            raise RuntimeError(log)
    records = [
        json.loads(row.removeprefix("HALL_RESULT "))
        for row in log.splitlines()
        if row.startswith("HALL_RESULT ")
    ]
    if (
        len(records) != 1
        or not records[0]["checks"].get("all_suites_completed")
        or not all(records[0]["checks"].values())
    ):
        raise RuntimeError(log)
    return records[0]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", nargs="?", default="godot")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = json.dumps(run(args.executable), indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(result + "\n")
    print(result)
